-- ============================================================================
-- HOÀN TÁC 20261124_ban_dat_truoc_v1.sql
-- ⚠ Xoá bảng ban_dat_truoc nên MẤT mọi lượt đặt trước. Phiên bàn đã nhận từ lượt đặt giữ nguyên, nhưng
--   lần chốt giờ sau sẽ tính theo giờ thực tế (không còn kéo tới hết khung đã đặt).
-- Trả qn_tinh_gio_ghi_dong_v1 và ban_chuyen_ban_tinh_gio_v1 về NGUYÊN VĂN bản 20261123_ban_tinh_gio_v1.sql
-- (hai khối dưới được cắt từ chính tệp đó).
-- ============================================================================
DO $pf$
DECLARE n integer;
BEGIN
  SELECT count(*) INTO n FROM public.ban_dat_truoc WHERE trang_thai = 'da_dat' AND gio_den > now();
  RAISE NOTICE 'ROLLBACK ban_dat_truoc_v1: % lượt đặt sắp tới sẽ bị xoá', n;
END
$pf$;

DROP FUNCTION IF EXISTS public.ban_dat_truoc_da_nhac_v1(uuid, uuid);
DROP FUNCTION IF EXISTS public.ban_dat_truoc_nhan_v1(uuid, uuid, uuid);
DROP FUNCTION IF EXISTS public.ban_dat_truoc_doi_trang_thai_v1(uuid, uuid, text);
DROP FUNCTION IF EXISTS public.ban_dat_truoc_luu_v1(uuid, uuid, text, text, text, timestamptz, timestamptz, text, numeric);
DROP FUNCTION IF EXISTS public.qn_dat_truoc_ten_nguoi_v1(uuid, uuid);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_ghi_dong_v1(uuid, uuid, boolean);

-- ── Ghi dòng tiền giờ của đoạn đang chạy (nội bộ: người gọi đã kiểm quyền và khoá phiên) ─────────────
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_ghi_dong_v1(p_store uuid, p_session uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_s record; v_t record; v_p record; v_line record;
  v_den timestamptz; v_phut integer; v_tien numeric; v_ten text; v_id uuid; v_tong numeric;
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

  v_den  := clock_timestamp();
  v_phut := GREATEST(1, ceil(extract(epoch FROM (v_den - v_s.gio_bat_dau)) / 60.0))::integer;
  v_tien := ceil(v_phut * GREATEST(COALESCE(v_p.sell_price, 0), 0) / 60.0 / 1000.0) * 1000;
  v_ten  := v_p.name || ' · ' || COALESCE(NULLIF(trim(v_t.label), ''), v_t.name)
            || ' · ' || to_char(v_s.gio_bat_dau AT TIME ZONE TZ, 'HH24:MI')
            || '–' || to_char(v_den AT TIME ZONE TZ, 'HH24:MI')
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
       'Tính giờ', 'xong', v_den, v_s.gio_bat_dau, v_den);
  END IF;

  SELECT COALESCE(sum(subtotal), 0) INTO v_tong FROM public.ban_session_items
  WHERE session_id = p_session AND store_id = p_store AND COALESCE(kitchen_status, '') <> 'huy';
  UPDATE public.ban_sessions SET total_amount = v_tong WHERE id = p_session;

  RETURN jsonb_build_object('tinh_gio', true, 'da_huy', false, 'item_id', v_id,
    'gio_tu', v_s.gio_bat_dau, 'gio_den', v_den, 'so_phut', v_phut,
    'gia_gio', COALESCE(v_p.sell_price, 0), 'thanh_tien', v_tien, 'ten', v_ten, 'tong_ban', v_tong);
END
$f$;
REVOKE ALL ON FUNCTION public.qn_tinh_gio_ghi_dong_v1(uuid, uuid) FROM PUBLIC, anon, authenticated;


-- ── App gọi: chuyển bàn / gộp bàn khi có tính giờ ───────────────────────────────────────────────
-- Bàn đích trống: chuyển. Bàn đích đang có khách: gộp (dời hết món sang phiên đích, đóng phiên nguồn).
-- Giờ ở bàn cũ được chốt thành một dòng theo giá bàn cũ trước khi dời.
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
    v_chot := public.qn_tinh_gio_ghi_dong_v1(p_store_id, p_session_id);
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


GRANT EXECUTE ON FUNCTION public.ban_chuyen_ban_tinh_gio_v1(uuid, uuid, text) TO anon, authenticated, service_role;

DO $rt$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication_tables
             WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'ban_dat_truoc') THEN
    ALTER PUBLICATION supabase_realtime DROP TABLE public.ban_dat_truoc;
  END IF;
END
$rt$;
DROP TABLE IF EXISTS public.ban_dat_truoc;

NOTIFY pgrst, 'reload schema';

DO $done$ BEGIN RAISE NOTICE 'ROLLBACK ban_dat_truoc_v1: xong'; END $done$;
