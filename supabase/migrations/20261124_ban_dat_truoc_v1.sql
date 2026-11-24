-- ============================================================================
-- ĐẶT TRƯỚC (đặt sân / bàn / phòng hẹn giờ) v1 — 24/11/2026, giai đoạn 3 của .docs/ke-hoach-ban-tinh-gio.md
-- Cần 20261123_ban_tinh_gio_v1.sql đã áp.
--
-- Bảng mới ban_dat_truoc: mỗi dòng một lượt đặt (bàn, tên khách, số điện thoại, giờ từ – đến).
--   • App KHÔNG ghi thẳng: chỉ đọc (vai authenticated, đúng quán). Ghi qua 4 hàm dưới.
--   • Không cho hai lượt còn hiệu lực ('da_dat', 'da_nhan') trùng giờ trên cùng một bàn: mỗi lần ghi
--     khoá theo bàn rồi kiểm (không cần thêm extension btree_gist).
--   • Số điện thoại khách là dữ liệu cá nhân: vai anon không đọc được bảng này; Boom không đọc.
--
-- Hàm app gọi (đều kiểm verify_staff_qr_membership_v4, quyền thanh toán):
--   ban_dat_truoc_luu_v1          tạo / sửa lượt đặt (chỉ sửa khi còn 'da_dat')
--   ban_dat_truoc_doi_trang_thai_v1  'huy' | 'khong_den' (từ 'da_dat')
--   ban_dat_truoc_nhan_v1         khách đến: gắn lượt đặt với phiên bàn đang mở của đúng bàn đó
--   ban_dat_truoc_da_nhac_v1      đánh dấu quán đã gọi nhắc khách (hộp nhắc trước 30 phút)
--
-- Tính tiền lượt đặt (Chủ Quán duyệt mặc định 23/11): theo KHUNG ĐÃ ĐẶT.
--   • Đến trễ vẫn tính từ giờ đặt: lúc nhận, mốc giờ của phiên lùi về giờ đặt nếu giờ đặt sớm hơn.
--   • Về sớm vẫn tính tới hết khung; chơi lố thì tính tới lúc chốt (theo phút).
--   • Chỉ áp cho lần chốt lúc tính tiền, khi phiên còn ở đúng bàn đã đặt. Chuyển bàn giữa chừng thì đoạn
--     ở bàn cũ tính tới lúc chuyển (không kéo tới hết khung, tránh tính trùng với đoạn ở bàn mới).
--
-- Kèm sửa tên dòng tiền giờ: giờ ra in = giờ vào + số phút tính tiền (trước in giờ ra thật, bỏ giây, nên có
-- dòng "16:59–16:59 (1p)").
-- Hoàn tác: 20261124_ban_dat_truoc_v1_ROLLBACK.sql. Test: supabase/tests/ban_dat_truoc_v1_test.sql
-- ============================================================================

DO $pf$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'ban_chot_gio_v1')
     OR NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'ban_sessions' AND column_name = 'gio_bat_dau') THEN
    RAISE EXCEPTION 'PREFLIGHT ban_dat_truoc_v1: chưa áp 20261123_ban_tinh_gio_v1.sql';
  END IF;
  RAISE NOTICE 'PREFLIGHT ban_dat_truoc_v1: OK';
END
$pf$;

CREATE TABLE IF NOT EXISTS public.ban_dat_truoc (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  table_id      text NOT NULL,
  ten_khach     text NOT NULL,
  sdt           text,
  gio_tu        timestamptz NOT NULL,
  gio_den       timestamptz NOT NULL,
  ghi_chu       text,
  tien_coc      numeric NOT NULL DEFAULT 0,          -- chỉ để nhân viên biết; KHÔNG vào Thu Chi, không tự trừ hoá đơn
  trang_thai    text NOT NULL DEFAULT 'da_dat',
  session_id    uuid,                                -- phiên bàn đã gắn khi nhận
  nhac_luc      timestamptz,                         -- quán đã gọi nhắc khách lúc nào
  nhac_boi      text,
  nguoi_tao     uuid,
  nguoi_tao_ten text,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT ban_dat_truoc_gio_hop_le CHECK (gio_den > gio_tu AND gio_den <= gio_tu + interval '24 hours'),
  CONSTRAINT ban_dat_truoc_trang_thai CHECK (trang_thai IN ('da_dat', 'da_nhan', 'huy', 'khong_den')),
  CONSTRAINT ban_dat_truoc_tien_coc CHECK (tien_coc >= 0)
);
CREATE INDEX IF NOT EXISTS ban_dat_truoc_store_gio_idx ON public.ban_dat_truoc (store_id, gio_tu);
CREATE INDEX IF NOT EXISTS ban_dat_truoc_session_idx ON public.ban_dat_truoc (session_id) WHERE session_id IS NOT NULL;

ALTER TABLE public.ban_dat_truoc ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ban_dat_truoc_doc ON public.ban_dat_truoc;
CREATE POLICY ban_dat_truoc_doc ON public.ban_dat_truoc
  FOR SELECT TO authenticated USING (store_id = (SELECT public.current_store_id()));
REVOKE ALL ON public.ban_dat_truoc FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ban_dat_truoc TO authenticated, service_role;

DO $rt$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables
                     WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'ban_dat_truoc') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.ban_dat_truoc;
  END IF;
END
$rt$;

-- ── Tên người đang gọi (để ghi "ai đặt", "ai nhắc") ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qn_dat_truoc_ten_nguoi_v1(p_store uuid, p_user uuid)
RETURNS text LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO 'public', 'pg_temp' AS $f$
  SELECT COALESCE(
    (SELECT NULLIF(trim(display_name), '') FROM public.user_accounts WHERE id = p_user),
    (SELECT NULLIF(trim(name), '') FROM public.staff_members WHERE id = p_user AND store_id = p_store),
    'Nhân viên')
$f$;
REVOKE ALL ON FUNCTION public.qn_dat_truoc_ten_nguoi_v1(uuid, uuid) FROM PUBLIC, anon, authenticated;

-- ── Tạo / sửa lượt đặt ───────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_luu_v1(
  p_store_id uuid, p_id uuid, p_table_id text, p_ten_khach text, p_sdt text,
  p_gio_tu timestamptz, p_gio_den timestamptz, p_ghi_chu text DEFAULT NULL, p_tien_coc numeric DEFAULT 0)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_staff record; v_cu record; v_trung record; v_row public.ban_dat_truoc%ROWTYPE;
  v_ten text := NULLIF(trim(COALESCE(p_ten_khach, '')), '');
  v_sdt text := NULLIF(regexp_replace(COALESCE(p_sdt, ''), '[^0-9+]', '', 'g'), '');
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  IF v_ten IS NULL OR p_table_id IS NULL OR p_gio_tu IS NULL OR p_gio_den IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Thiếu tên khách, bàn hoặc giờ đặt');
  END IF;
  IF length(v_ten) > 80 OR length(COALESCE(v_sdt, '')) > 20 OR length(COALESCE(p_ghi_chu, '')) > 300 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Tên, số điện thoại hoặc ghi chú quá dài');
  END IF;
  IF p_gio_den <= p_gio_tu OR p_gio_den > p_gio_tu + interval '24 hours' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_TIME', 'message', 'Giờ kết thúc phải sau giờ bắt đầu, tối đa 24 giờ');
  END IF;
  IF p_gio_den <= now() THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_TIME', 'message', 'Khung giờ này đã qua');
  END IF;
  IF COALESCE(p_tien_coc, 0) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Tiền cọc không hợp lệ');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ban_dining_tables
                 WHERE id = p_table_id AND store_id = p_store_id AND COALESCE(is_active, true)) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy bàn');
  END IF;

  -- Hai máy đặt cùng một bàn cùng lúc: xếp hàng theo bàn rồi mới kiểm trùng giờ.
  PERFORM pg_advisory_xact_lock(hashtext('ban_dat_truoc'), hashtext(p_table_id));

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_cu FROM public.ban_dat_truoc WHERE id = p_id AND store_id = p_store_id FOR UPDATE;
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy lượt đặt');
    END IF;
    IF v_cu.trang_thai <> 'da_dat' THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Lượt đặt này không còn sửa được');
    END IF;
  END IF;

  SELECT ten_khach, gio_tu, gio_den INTO v_trung FROM public.ban_dat_truoc
  WHERE store_id = p_store_id AND table_id = p_table_id
    AND trang_thai IN ('da_dat', 'da_nhan')
    AND id IS DISTINCT FROM p_id
    AND gio_tu < p_gio_den AND gio_den > p_gio_tu
  ORDER BY gio_tu LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'TRUNG_GIO',
      'message', 'Trùng giờ với lượt đặt của ' || v_trung.ten_khach || ' ('
        || to_char(v_trung.gio_tu AT TIME ZONE 'Asia/Ho_Chi_Minh', 'HH24:MI') || '–'
        || to_char(v_trung.gio_den AT TIME ZONE 'Asia/Ho_Chi_Minh', 'HH24:MI') || ')');
  END IF;

  IF p_id IS NULL THEN
    INSERT INTO public.ban_dat_truoc
      (store_id, table_id, ten_khach, sdt, gio_tu, gio_den, ghi_chu, tien_coc, nguoi_tao, nguoi_tao_ten)
    VALUES
      (p_store_id, p_table_id, v_ten, v_sdt, p_gio_tu, p_gio_den, NULLIF(trim(COALESCE(p_ghi_chu, '')), ''),
       COALESCE(p_tien_coc, 0), v_staff.member_user_id,
       public.qn_dat_truoc_ten_nguoi_v1(p_store_id, v_staff.member_user_id))
    RETURNING * INTO v_row;
  ELSE
    UPDATE public.ban_dat_truoc
       SET table_id = p_table_id, ten_khach = v_ten, sdt = v_sdt, gio_tu = p_gio_tu, gio_den = p_gio_den,
           ghi_chu = NULLIF(trim(COALESCE(p_ghi_chu, '')), ''), tien_coc = COALESCE(p_tien_coc, 0),
           -- đổi giờ thì nhắc lại từ đầu
           nhac_luc = CASE WHEN gio_tu = p_gio_tu THEN nhac_luc END,
           nhac_boi = CASE WHEN gio_tu = p_gio_tu THEN nhac_boi END,
           updated_at = now()
     WHERE id = p_id
    RETURNING * INTO v_row;
  END IF;
  RETURN jsonb_build_object('success', true, 'data', to_jsonb(v_row));
END
$f$;

-- ── Huỷ / khách không đến ──────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_doi_trang_thai_v1(p_store_id uuid, p_id uuid, p_trang_thai text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_b record;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  IF p_trang_thai NOT IN ('huy', 'khong_den') THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Trạng thái không hợp lệ');
  END IF;
  SELECT * INTO v_b FROM public.ban_dat_truoc WHERE id = p_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy lượt đặt');
  END IF;
  IF v_b.trang_thai = p_trang_thai THEN
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('id', p_id, 'trang_thai', p_trang_thai));
  END IF;
  IF v_b.trang_thai <> 'da_dat' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Lượt đặt này không còn huỷ được');
  END IF;
  UPDATE public.ban_dat_truoc SET trang_thai = p_trang_thai, updated_at = now() WHERE id = p_id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('id', p_id, 'trang_thai', p_trang_thai));
END
$f$;

-- ── Khách đến: gắn lượt đặt với phiên bàn đang mở ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_nhan_v1(p_store_id uuid, p_id uuid, p_session_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_b record; v_s record;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  SELECT * INTO v_b FROM public.ban_dat_truoc WHERE id = p_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy lượt đặt');
  END IF;
  IF v_b.trang_thai = 'da_nhan' AND v_b.session_id = p_session_id THEN   -- bấm lại: không làm gì thêm
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('id', p_id, 'session_id', p_session_id, 'lap_lai', true));
  END IF;
  IF v_b.trang_thai <> 'da_dat' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Lượt đặt này không còn nhận được');
  END IF;
  SELECT * INTO v_s FROM public.ban_sessions WHERE id = p_session_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND OR v_s.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_NOT_OPEN', 'message', 'Bàn chưa mở');
  END IF;
  IF v_s.table_id::text <> v_b.table_id THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Phiên bàn không phải của bàn đã đặt');
  END IF;
  IF EXISTS (SELECT 1 FROM public.ban_dat_truoc
             WHERE session_id = p_session_id AND trang_thai = 'da_nhan' AND id <> p_id) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Bàn này đã nhận một lượt đặt khác');
  END IF;

  UPDATE public.ban_dat_truoc SET trang_thai = 'da_nhan', session_id = p_session_id, updated_at = now() WHERE id = p_id;
  -- Đến trễ vẫn tính từ giờ đặt: lùi mốc giờ của phiên về giờ đặt.
  IF v_s.gio_bat_dau IS NOT NULL AND v_b.gio_tu < v_s.gio_bat_dau THEN
    UPDATE public.ban_sessions SET gio_bat_dau = v_b.gio_tu WHERE id = p_session_id;
  END IF;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('id', p_id, 'session_id', p_session_id, 'lap_lai', false));
END
$f$;

-- ── Đã gọi nhắc khách ─────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_da_nhac_v1(p_store_id uuid, p_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_staff record; v_b record;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  SELECT * INTO v_b FROM public.ban_dat_truoc WHERE id = p_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy lượt đặt');
  END IF;
  IF v_b.nhac_luc IS NULL THEN   -- người bấm đầu tiên được ghi; người sau không ghi đè
    UPDATE public.ban_dat_truoc
       SET nhac_luc = now(), nhac_boi = public.qn_dat_truoc_ten_nguoi_v1(p_store_id, v_staff.member_user_id),
           updated_at = now()
     WHERE id = p_id
    RETURNING * INTO v_b;
  END IF;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('id', p_id, 'nhac_luc', v_b.nhac_luc, 'nhac_boi', v_b.nhac_boi));
END
$f$;

-- ── Ghi dòng tiền giờ: thêm tính theo khung đã đặt + sửa giờ ra in trên tên dòng ───────────────────────
-- (thay qn_tinh_gio_ghi_dong_v1(uuid, uuid) của 20261123 bằng bản có tham số p_du_khung)
DROP FUNCTION IF EXISTS public.qn_tinh_gio_ghi_dong_v1(uuid, uuid);
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_ghi_dong_v1(p_store uuid, p_session uuid, p_du_khung boolean DEFAULT true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_s record; v_t record; v_p record; v_line record;
  v_den timestamptz; v_khung_den timestamptz; v_phut integer; v_tien numeric; v_ten text; v_id uuid; v_tong numeric;
  TZ constant text := 'Asia/Ho_Chi_Minh';
BEGIN
  SELECT * INTO v_s FROM public.ban_sessions WHERE id = p_session AND store_id = p_store;
  IF NOT FOUND OR v_s.status <> 'open' THEN RAISE EXCEPTION 'TINH_GIO: phiên bàn không mở'; END IF;
  IF v_s.gio_bat_dau IS NULL THEN RETURN jsonb_build_object('tinh_gio', false); END IF;

  SELECT * INTO v_t FROM public.ban_dining_tables WHERE id = v_s.table_id::text AND store_id = p_store;
  IF NOT FOUND OR v_t.gia_gio_product_id IS NULL THEN
    RAISE EXCEPTION 'TINH_GIO_BAN_MAT_GIA: bàn đang tính giờ nhưng không còn giá giờ';
  END IF;
  -- món đã xoá mềm vẫn tính (không chặn quán thu tiền bàn đang chơi)
  SELECT id, name, sell_price INTO v_p FROM public.products
  WHERE id = v_t.gia_gio_product_id AND store_id = p_store;
  IF NOT FOUND THEN RAISE EXCEPTION 'TINH_GIO_MON_SAI: không thấy món giá giờ của bàn'; END IF;

  SELECT * INTO v_line FROM public.ban_session_items
  WHERE session_id = p_session AND store_id = p_store AND gio_tu = v_s.gio_bat_dau
  ORDER BY added_at LIMIT 1;
  IF FOUND AND v_line.kitchen_status = 'huy' THEN   -- Quản lý đã bỏ tiền giờ: không ghi lại
    RETURN jsonb_build_object('tinh_gio', true, 'da_huy', true, 'item_id', v_line.id,
      'gio_tu', v_line.gio_tu, 'gio_den', v_line.gio_den, 'thanh_tien', 0);
  END IF;

  v_den := clock_timestamp();
  -- Lượt đặt trước: tính tới hết khung đã đặt dù khách về sớm (chỉ khi phiên còn ở đúng bàn đã đặt).
  IF p_du_khung THEN
    SELECT max(gio_den) INTO v_khung_den FROM public.ban_dat_truoc
    WHERE store_id = p_store AND session_id = p_session AND trang_thai = 'da_nhan'
      AND table_id = v_s.table_id::text;
    IF v_khung_den IS NOT NULL AND v_khung_den > v_den THEN v_den := v_khung_den; END IF;
  END IF;
  v_phut := GREATEST(1, ceil(extract(epoch FROM (v_den - v_s.gio_bat_dau)) / 60.0))::integer;
  v_tien := ceil(v_phut * GREATEST(COALESCE(v_p.sell_price, 0), 0) / 60.0 / 1000.0) * 1000;
  -- giờ ra in = giờ vào + số phút tính tiền, để dòng không ghi "16:59–16:59 (1p)"
  v_ten  := v_p.name || ' · ' || COALESCE(NULLIF(trim(v_t.label), ''), v_t.name)
            || ' · ' || to_char(v_s.gio_bat_dau AT TIME ZONE TZ, 'HH24:MI')
            || '–' || to_char((v_s.gio_bat_dau + make_interval(mins => v_phut)) AT TIME ZONE TZ, 'HH24:MI')
            || ' (' || CASE WHEN v_phut >= 60 THEN (v_phut / 60) || 'g' || lpad((v_phut % 60)::text, 2, '0')
                            ELSE v_phut || 'p' END || ')';

  IF v_line.id IS NOT NULL THEN
    UPDATE public.ban_session_items
       SET product_id = v_p.id, product_name = v_ten, quantity = 1,
           unit_price = v_tien, price = v_tien::bigint, subtotal = v_tien, gio_den = v_den
     WHERE id = v_line.id;
    v_id := v_line.id;
  ELSE
    v_id := gen_random_uuid();
    INSERT INTO public.ban_session_items
      (id, store_id, session_id, product_id, product_name, unit_price, price, quantity, subtotal,
       added_by, kitchen_status, added_at, gio_tu, gio_den)
    VALUES
      (v_id, p_store, p_session, v_p.id, v_ten, v_tien, v_tien::bigint, 1, v_tien,
       'Tính giờ', 'xong', clock_timestamp(), v_s.gio_bat_dau, v_den);
  END IF;

  SELECT COALESCE(sum(subtotal), 0) INTO v_tong FROM public.ban_session_items
  WHERE session_id = p_session AND store_id = p_store AND COALESCE(kitchen_status, '') <> 'huy';
  UPDATE public.ban_sessions SET total_amount = v_tong WHERE id = p_session;

  RETURN jsonb_build_object('tinh_gio', true, 'da_huy', false, 'item_id', v_id,
    'gio_tu', v_s.gio_bat_dau, 'gio_den', v_den, 'so_phut', v_phut,
    'gia_gio', COALESCE(v_p.sell_price, 0), 'thanh_tien', v_tien, 'ten', v_ten, 'tong_ban', v_tong,
    'theo_khung_dat', v_khung_den IS NOT NULL AND v_den = v_khung_den);
END
$f$;
REVOKE ALL ON FUNCTION public.qn_tinh_gio_ghi_dong_v1(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;

-- ban_chot_gio_v1 gọi qn_tinh_gio_ghi_dong_v1(quán, phiên) → tự nhận bản mới với p_du_khung = true.
-- Chuyển / gộp bàn: đoạn ở bàn cũ chỉ tính tới lúc chuyển → gọi với p_du_khung = false.
CREATE OR REPLACE FUNCTION public.ban_chuyen_ban_tinh_gio_v1(p_session_id uuid, p_store_id uuid, p_table_dich text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_s record; v_t record; v_dich_id uuid; v_d record; v_chot jsonb; v_kieu text; v_tong numeric;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  IF p_table_dich IS NULL OR p_table_dich !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Bàn đích không hợp lệ');
  END IF;
  SELECT * INTO v_t FROM public.ban_dining_tables WHERE id = p_table_dich AND store_id = p_store_id;
  IF NOT FOUND OR COALESCE(v_t.is_active, true) = false THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy bàn đích');
  END IF;

  -- Khoá cả hai phiên theo thứ tự id (cùng thứ tự với guard_ban_item_financial_change_v5) để không khoá chéo.
  SELECT id INTO v_dich_id FROM public.ban_sessions
  WHERE store_id = p_store_id AND table_id = p_table_dich::uuid AND status = 'open';
  PERFORM 1 FROM public.ban_sessions
  WHERE store_id = p_store_id AND id IN (p_session_id, v_dich_id) ORDER BY id FOR UPDATE;

  SELECT * INTO v_s FROM public.ban_sessions WHERE id = p_session_id AND store_id = p_store_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;
  IF v_s.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_NOT_OPEN', 'message', 'Phiên bàn không còn mở');
  END IF;
  IF v_s.table_id::text = p_table_dich THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Bàn đích trùng bàn hiện tại');
  END IF;
  SELECT * INTO v_d FROM public.ban_sessions
  WHERE store_id = p_store_id AND table_id = p_table_dich::uuid AND status = 'open';
  IF v_d.id IS DISTINCT FROM v_dich_id THEN   -- bàn đích vừa đổi trạng thái giữa lúc đọc và lúc khoá
    RETURN jsonb_build_object('success', false, 'error_code', 'RETRY', 'message', 'Bàn đích vừa thay đổi, hãy thử lại');
  END IF;

  IF v_s.gio_bat_dau IS NOT NULL THEN
    v_chot := public.qn_tinh_gio_ghi_dong_v1(p_store_id, p_session_id, false);
  END IF;

  IF v_d.id IS NULL THEN
    v_kieu := 'chuyen';
    UPDATE public.ban_sessions
       SET table_id = p_table_dich::uuid,
           gio_bat_dau = CASE WHEN v_t.gia_gio_product_id IS NOT NULL THEN clock_timestamp() END
     WHERE id = p_session_id;
  ELSE
    v_kieu := 'gop';
    UPDATE public.ban_session_items SET session_id = v_d.id
    WHERE session_id = p_session_id AND store_id = p_store_id;
    UPDATE public.ban_sessions
       SET status = 'closed', closed_at = now(), total_amount = 0, gio_bat_dau = NULL
     WHERE id = p_session_id;
    SELECT COALESCE(sum(subtotal), 0) INTO v_tong FROM public.ban_session_items
    WHERE session_id = v_d.id AND store_id = p_store_id AND COALESCE(kitchen_status, '') <> 'huy';
    UPDATE public.ban_sessions SET total_amount = v_tong WHERE id = v_d.id;
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'kieu', v_kieu, 'session_id', CASE WHEN v_kieu = 'gop' THEN v_d.id ELSE p_session_id END,
    'chot', v_chot));
END
$f$;

GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_luu_v1(uuid, uuid, text, text, text, timestamptz, timestamptz, text, numeric) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_doi_trang_thai_v1(uuid, uuid, text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_nhan_v1(uuid, uuid, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_da_nhac_v1(uuid, uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_chuyen_ban_tinh_gio_v1(uuid, uuid, text) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

DO $done$ BEGIN RAISE NOTICE 'PATCH ban_dat_truoc_v1: xong'; END $done$;
