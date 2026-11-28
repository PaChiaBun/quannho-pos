-- ============================================================================
-- 20261128_goi_gio.sql — đợt 7 lộ trình tính giờ (.docs/ke-hoach-goi-gio.md)
-- Gói giờ: quán đặt sẵn gói theo từng bàn ("2 giờ = 100.000"), nhân viên chọn gói cho bàn đang chơi.
-- PHẢI ÁP SAU 20261128_gia_gio_ngay_le.sql (đợt 6; tự kiểm, thiếu thì dừng).
--
--   ban_goi_gio                  gói của bàn: so_phut 15–720, gia, thu_tu; tối đa 6 gói / bàn
--   ban_sessions.goi_phut/goi_gia gói của ĐOẠN đang tính, chép giá lúc chọn; app không sửa thẳng (trigger giữ)
--   qn_tinh_gio_tinh_tien_v3     như v2 + gói: về sớm tính đủ gói, lố tính thêm theo khung giá / ngày lễ
--   qn_tinh_gio_tinh_tien_v2     thành vỏ gọi v3 không gói
--   qn_tinh_gio_ghi_dong_v1      (thay) dùng gói của phiên; tên dòng ghi gói
--   ban_chuyen_ban_tinh_gio_v1   (thay) chuyển bàn mang phần gói còn lại (giá 0) sang bàn mới
--   ban_goi_gio_luu_v1           app lưu gói cho một hoặc nhiều bàn (Chủ quán / Quản lý)
--   ban_chon_goi_gio_v1          chọn gói (quyền thu tiền); đổi / bỏ gói đã chọn (Chủ quán / Quản lý)
--
-- Phiên không có gói: tính đúng như đợt 6 (test hồi quy).
-- Hoàn tác: 20261128_goi_gio_ROLLBACK.sql. Test: supabase/tests/goi_gio_test.sql
-- ============================================================================

DO $pf$
BEGIN
  IF to_regclass('public.ban_ngay_le') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT goi_gio: chưa áp 20261128_gia_gio_ngay_le.sql (đợt 6)';
  END IF;
  RAISE NOTICE 'PREFLIGHT goi_gio: OK';
END
$pf$;

CREATE TABLE IF NOT EXISTS public.ban_goi_gio (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id  uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  table_id  text NOT NULL REFERENCES public.ban_dining_tables(id) ON DELETE CASCADE,
  so_phut   smallint NOT NULL,
  gia       numeric(12, 0) NOT NULL,
  thu_tu    smallint NOT NULL DEFAULT 0,
  CONSTRAINT ban_goi_gio_phut CHECK (so_phut BETWEEN 15 AND 720),
  CONSTRAINT ban_goi_gio_gia CHECK (gia BETWEEN 0 AND 100000000),
  CONSTRAINT ban_goi_gio_trung UNIQUE (table_id, so_phut)
);
CREATE INDEX IF NOT EXISTS ban_goi_gio_store_idx ON public.ban_goi_gio (store_id);
ALTER TABLE public.ban_goi_gio ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ban_goi_gio_doc ON public.ban_goi_gio;
CREATE POLICY ban_goi_gio_doc ON public.ban_goi_gio
  FOR SELECT TO authenticated USING (store_id = (SELECT public.current_store_id()));
REVOKE ALL ON public.ban_goi_gio FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ban_goi_gio TO authenticated, service_role;

ALTER TABLE public.ban_sessions ADD COLUMN IF NOT EXISTS goi_phut smallint;
ALTER TABLE public.ban_sessions ADD COLUMN IF NOT EXISTS goi_gia numeric(12, 0);
COMMENT ON COLUMN public.ban_sessions.goi_phut IS 'Gói giờ của đoạn đang tính (phút). NULL = không gói. Máy chủ đặt (ban_chon_goi_gio_v1)';
COMMENT ON COLUMN public.ban_sessions.goi_gia IS 'Giá gói chép lúc chọn; 0 = phần gói còn lại sau chuyển bàn (đã tính ở bàn cũ)';

-- App (anon / authenticated) không tự đặt / sửa gói: lặng lẽ giữ giá trị cũ, upsert của app cũ không vỡ.
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_goi_khoa_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'public', 'pg_temp' AS $f$
BEGIN
  IF current_user IN ('anon', 'authenticated') THEN
    IF TG_OP = 'INSERT' THEN
      NEW.goi_phut := NULL; NEW.goi_gia := NULL;
    ELSE
      NEW.goi_phut := OLD.goi_phut; NEW.goi_gia := OLD.goi_gia;
    END IF;
  END IF;
  RETURN NEW;
END
$f$;
DROP TRIGGER IF EXISTS qn_tinh_gio_goi_khoa ON public.ban_sessions;
CREATE TRIGGER qn_tinh_gio_goi_khoa BEFORE INSERT OR UPDATE ON public.ban_sessions
  FOR EACH ROW EXECUTE FUNCTION public.qn_tinh_gio_goi_khoa_v1();

-- ── Tính tiền giờ có gói (một chỗ duy nhất; app chép đúng từng bước trong lib/modules/tinh_gio/gia_gio.dart) ──
-- Như v2 (đợt 1 + ngày lễ đợt 6), thêm gói: p_goi_phut > 0 thì số phút tính = max(làm tròn, gói phút) (về sớm tính
-- đủ gói); tiền = giá gói + ceil(Σ giá từng phút từ phút thứ p_goi_phut / 60 / 1000) × 1000 (phần lố theo khung giá,
-- ngày lễ). doan chỉ gồm phần lố. Không gói (0 / NULL) = đúng v2.
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_tinh_tien_v3(
  p_table text, p_gia_goc numeric, p_vao timestamptz, p_phut_choi integer, p_goi_phut integer, p_goi_gia numeric)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  TZ constant text := 'Asia/Ho_Chi_Minh';
  v_block int := 1; v_toi_thieu int := 0; v_an_han int := 0;
  v_choi int := GREATEST(1, COALESCE(p_phut_choi, 1));
  v_tinh int; v_q int; v_r int;
  v_goc numeric := GREATEST(COALESCE(p_gia_goc, 0), 0);
  k_tu time[]; k_den time[]; k_gia numeric[]; k_n int;
  v_thu_mang text[]; k_le boolean[];
  v_le date[]; v_co_le boolean := false; v_le_nay boolean; v_le_truoc boolean;
  i int; j int; v_luc timestamp; v_d int; v_d_truoc int; v_s time; v_gia numeric; v_khop boolean; v_xong boolean;
  v_doan jsonb := '[]'::jsonb; v_doan_tu timestamptz; v_doan_phut int := 0; v_doan_gia numeric;
  v_tong numeric := 0;
  v_goi int := GREATEST(COALESCE(p_goi_phut, 0), 0);
  v_goi_gia numeric := CASE WHEN COALESCE(p_goi_phut, 0) > 0 THEN GREATEST(COALESCE(p_goi_gia, 0), 0) ELSE 0 END;
BEGIN
  SELECT block_phut, toi_thieu_phut, an_han_phut INTO v_block, v_toi_thieu, v_an_han
  FROM public.ban_gia_gio_cau_hinh WHERE table_id = p_table;
  v_block := COALESCE(v_block, 1); v_toi_thieu := COALESCE(v_toi_thieu, 0); v_an_han := COALESCE(v_an_han, 0);

  -- 1) làm tròn: quá bội số block không quá ân hạn thì giữ bội số đó, còn lại lên block kế; rồi tối thiểu
  v_q := v_choi / v_block; v_r := v_choi % v_block;
  v_tinh := CASE WHEN v_r = 0 THEN v_choi
                 WHEN v_q > 0 AND v_r <= v_an_han THEN v_q * v_block
                 ELSE (v_q + 1) * v_block END;
  v_tinh := GREATEST(v_tinh, v_toi_thieu, v_goi);   -- có gói: về sớm vẫn tính đủ gói

  -- 2) các khung của bàn, theo thứ tự (khung đứng trên thắng; khung Lễ thắng vào ngày lễ)
  SELECT array_agg(array_to_string(thu, ',') ORDER BY thu_tu, id), array_agg(tu ORDER BY thu_tu, id),
         array_agg(den ORDER BY thu_tu, id), array_agg(gia ORDER BY thu_tu, id),
         array_agg(8 = ANY (thu) ORDER BY thu_tu, id)
    INTO v_thu_mang, k_tu, k_den, k_gia, k_le
  FROM public.ban_gia_gio_khung WHERE table_id = p_table;
  k_n := COALESCE(array_length(k_tu, 1), 0);

  -- ngày lễ của quán trong khoảng chơi (thêm hôm trước cho phần qua đêm); chỉ đọc khi bàn có khung Lễ
  IF k_n > 0 AND true = ANY (k_le) THEN
    SELECT array_agg(l.ngay) INTO v_le
    FROM public.ban_ngay_le l JOIN public.ban_dining_tables t ON t.store_id = l.store_id AND t.id = p_table
    WHERE l.ngay BETWEEN (p_vao AT TIME ZONE TZ)::date - 1
                     AND ((p_vao + make_interval(mins => v_tinh)) AT TIME ZONE TZ)::date;
    v_co_le := v_le IS NOT NULL;
  END IF;

  -- 3) từng phút lấy giá của khung chứa thời điểm bắt đầu phút đó (giờ VN); gộp phút liền nhau cùng giá
  FOR i IN v_goi .. v_tinh - 1 LOOP   -- phút trong gói đã gồm trong giá gói
    v_gia := v_goc;
    IF k_n > 0 THEN
      v_luc := (p_vao + make_interval(mins => i)) AT TIME ZONE TZ;
      v_d := extract(isodow FROM v_luc)::int;
      v_d_truoc := CASE WHEN v_d = 1 THEN 7 ELSE v_d - 1 END;
      v_s := v_luc::time;
      v_xong := false;
      IF v_co_le THEN
        v_le_nay := v_luc::date = ANY (v_le);
        v_le_truoc := (v_luc::date - 1) = ANY (v_le);
        IF v_le_nay OR v_le_truoc THEN
          FOR j IN 1 .. k_n LOOP
            CONTINUE WHEN NOT k_le[j];
            v_khop := CASE
              WHEN k_tu[j] = k_den[j] THEN v_le_nay
              WHEN k_tu[j] < k_den[j] THEN v_le_nay AND v_s >= k_tu[j] AND v_s < k_den[j]
              ELSE (v_le_nay AND v_s >= k_tu[j]) OR (v_le_truoc AND v_s < k_den[j]) END;
            IF v_khop THEN v_gia := k_gia[j]; v_xong := true; EXIT; END IF;
          END LOOP;
        END IF;
      END IF;
      IF NOT v_xong THEN
        FOR j IN 1 .. k_n LOOP
          v_khop := CASE
            WHEN k_tu[j] = k_den[j] THEN v_d::text = ANY (string_to_array(v_thu_mang[j], ','))
            WHEN k_tu[j] < k_den[j] THEN v_d::text = ANY (string_to_array(v_thu_mang[j], ','))
                                         AND v_s >= k_tu[j] AND v_s < k_den[j]
            ELSE (v_d::text = ANY (string_to_array(v_thu_mang[j], ',')) AND v_s >= k_tu[j])
              OR (v_d_truoc::text = ANY (string_to_array(v_thu_mang[j], ',')) AND v_s < k_den[j]) END;
          IF v_khop THEN v_gia := k_gia[j]; EXIT; END IF;
        END LOOP;
      END IF;
    END IF;
    IF v_doan_phut > 0 AND v_gia = v_doan_gia THEN
      v_doan_phut := v_doan_phut + 1;
    ELSE
      IF v_doan_phut > 0 THEN
        v_doan := v_doan || jsonb_build_object('tu', v_doan_tu, 'phut', v_doan_phut, 'gia', v_doan_gia);
      END IF;
      v_doan_tu := p_vao + make_interval(mins => i); v_doan_phut := 1; v_doan_gia := v_gia;
    END IF;
    v_tong := v_tong + v_gia;
  END LOOP;
  IF v_doan_phut > 0 THEN
    v_doan := v_doan || jsonb_build_object('tu', v_doan_tu, 'phut', v_doan_phut, 'gia', v_doan_gia);
  END IF;

  RETURN jsonb_build_object('so_phut_choi', v_choi, 'so_phut_tinh', v_tinh,
    'thanh_tien', v_goi_gia + ceil(v_tong / 60.0 / 1000.0) * 1000, 'doan', v_doan,
    'goi_phut', v_goi, 'goi_gia', v_goi_gia);
END
$f$;
REVOKE ALL ON FUNCTION public.qn_tinh_gio_tinh_tien_v3(text, numeric, timestamptz, integer, integer, numeric) FROM PUBLIC, anon, authenticated;

-- v2 (đợt 1 + 6) thành vỏ: không gói. Hàm cũ gọi v2 vẫn ra đúng số như trước.
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_tinh_tien_v2(
  p_table text, p_gia_goc numeric, p_vao timestamptz, p_phut_choi integer)
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog', 'pg_temp' AS $f$
  SELECT public.qn_tinh_gio_tinh_tien_v3(p_table, p_gia_goc, p_vao, p_phut_choi, 0, 0)
$f$;
REVOKE ALL ON FUNCTION public.qn_tinh_gio_tinh_tien_v2(text, numeric, timestamptz, integer) FROM PUBLIC, anon, authenticated;

-- ── (thay) Ghi dòng tiền giờ: thêm gói của phiên (đợt 7). Còn lại nguyên văn đợt 1 ─────────────────
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_ghi_dong_v1(p_store uuid, p_session uuid, p_du_khung boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp'
AS $function$
DECLARE
  v_s record; v_t record; v_p record; v_line record;
  v_den timestamptz; v_khung_den timestamptz; v_phut integer; v_tien numeric; v_ten text; v_id uuid; v_tong numeric;
  v_ra timestamptz; v_fmt text;
  v_tinh jsonb; v_phut_tinh integer; v_chi_tiet text; v_so_doan integer;
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
  -- 28/11: khung giá + làm tròn của bàn (không cài gì = công thức cũ, đúng từng đồng)
  -- 28/11 đợt 7: gói của đoạn đang tính (chép giá lúc chọn); không gói = như v2
  v_tinh := public.qn_tinh_gio_tinh_tien_v3(v_t.id, v_p.sell_price, v_s.gio_bat_dau, v_phut, v_s.goi_phut, v_s.goi_gia);
  v_tien := (v_tinh->>'thanh_tien')::numeric;
  v_phut_tinh := (v_tinh->>'so_phut_tinh')::integer;
  -- giờ ra in = giờ vào + số phút tính tiền. Một giá: "Giờ chơi · Bàn 3 · 14:05 – 15:35 · 1 giờ 30 phút × 60.000 đ/giờ".
  -- Nhiều giá: "… · 2 giờ 30 phút (30 phút × 50.000 + 2 giờ × 70.000 đ/giờ)". Làm tròn khác số phút chơi:
  -- "… · chơi 47 phút, tính 1 giờ × 60.000 đ/giờ".
  v_ra := v_s.gio_bat_dau + make_interval(mins => v_phut_tinh);
  v_fmt := CASE WHEN (v_s.gio_bat_dau AT TIME ZONE TZ)::date = (v_ra AT TIME ZONE TZ)::date
                THEN 'HH24:MI' ELSE 'DD/MM HH24:MI' END;
  SELECT string_agg(public.qn_tinh_gio_thoi_luong_v1((d->>'phut')::int) || ' × '
                    || public.qn_tinh_gio_tien_chu_v1((d->>'gia')::numeric), ' + ' ORDER BY ord),
         count(*)
    INTO v_chi_tiet, v_so_doan
  FROM jsonb_array_elements(v_tinh->'doan') WITH ORDINALITY AS x(d, ord);
  v_ten  := 'Giờ chơi · ' || COALESCE(NULLIF(trim(v_t.label), ''), v_t.name)
            || ' · ' || to_char(v_s.gio_bat_dau AT TIME ZONE TZ, v_fmt)
            || ' – ' || to_char(v_ra AT TIME ZONE TZ, v_fmt)
            || ' · ' || CASE WHEN v_phut_tinh <> v_phut
                             THEN 'chơi ' || public.qn_tinh_gio_thoi_luong_v1(v_phut) || ', tính '
                             ELSE '' END
            || public.qn_tinh_gio_thoi_luong_v1(v_phut_tinh)
            || CASE WHEN v_so_doan > 1 THEN ' (' || v_chi_tiet || ' đ/giờ)'
                    ELSE ' × ' || public.qn_tinh_gio_tien_chu_v1(
                           COALESCE((v_tinh->'doan'->0->>'gia')::numeric, v_p.sell_price)) || ' đ/giờ' END;
  -- Gói: "… · chơi 2 giờ 17 phút · gói 2 giờ 100.000 đ + 30 phút × 60.000 đ/giờ" (trong gói thì không có phần "+").
  -- Phần gói còn lại sau chuyển bàn (giá 0): "… · chơi 30 phút · phần còn của gói 50 phút".
  IF COALESCE(v_s.goi_phut, 0) > 0 THEN
    v_ten  := 'Giờ chơi · ' || COALESCE(NULLIF(trim(v_t.label), ''), v_t.name)
              || ' · ' || to_char(v_s.gio_bat_dau AT TIME ZONE TZ, v_fmt)
              || ' – ' || to_char(v_ra AT TIME ZONE TZ, v_fmt)
              || ' · chơi ' || public.qn_tinh_gio_thoi_luong_v1(v_phut) || ' · '
              || CASE WHEN COALESCE(v_s.goi_gia, 0) > 0
                      THEN 'gói ' || public.qn_tinh_gio_thoi_luong_v1(v_s.goi_phut) || ' '
                           || public.qn_tinh_gio_tien_chu_v1(v_s.goi_gia) || ' đ'
                      ELSE 'phần còn của gói ' || public.qn_tinh_gio_thoi_luong_v1(v_s.goi_phut) END
              || CASE WHEN v_so_doan = 0 THEN ''
                      WHEN v_so_doan = 1 THEN ' + ' || v_chi_tiet || ' đ/giờ'
                      ELSE ' + (' || v_chi_tiet || ' đ/giờ)' END;
  END IF;

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
    'gio_tu', v_s.gio_bat_dau, 'gio_den', v_den, 'so_phut', v_phut_tinh, 'so_phut_choi', v_phut,
    'doan', v_tinh->'doan', 'goi_phut', v_s.goi_phut, 'goi_gia', v_s.goi_gia,
    'gia_gio', COALESCE(v_p.sell_price, 0), 'thanh_tien', v_tien, 'ten', v_ten, 'tong_ban', v_tong,
    'theo_khung_dat', v_khung_den IS NOT NULL AND v_den = v_khung_den);
END
$function$
;

REVOKE ALL ON FUNCTION public.qn_tinh_gio_ghi_dong_v1(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;

-- ── (thay) Chuyển / gộp bàn tính giờ: mang phần gói còn lại sang bàn mới (đợt 7). Còn lại nguyên văn production 28/11 ──
CREATE OR REPLACE FUNCTION public.ban_chuyen_ban_tinh_gio_v1(p_session_id uuid, p_store_id uuid, p_table_dich text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp'
AS $function$
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
           gio_bat_dau = CASE WHEN v_t.gia_gio_product_id IS NOT NULL THEN clock_timestamp() END,
           -- đợt 7: đoạn bàn cũ đã chốt đủ giá gói; bàn mới nhận phần gói còn lại (giá 0), hết thì tính như thường
           goi_phut = CASE WHEN v_t.gia_gio_product_id IS NOT NULL AND COALESCE(v_s.goi_phut, 0) > 0
                             AND (v_chot->>'so_phut_choi')::int < v_s.goi_phut
                           THEN v_s.goi_phut - (v_chot->>'so_phut_choi')::int END,
           goi_gia = CASE WHEN v_t.gia_gio_product_id IS NOT NULL AND COALESCE(v_s.goi_phut, 0) > 0
                            AND (v_chot->>'so_phut_choi')::int < v_s.goi_phut
                          THEN 0 END
     WHERE id = p_session_id;
  ELSE
    v_kieu := 'gop';
    UPDATE public.ban_session_items SET session_id = v_d.id
    WHERE session_id = p_session_id AND store_id = p_store_id;
    UPDATE public.ban_sessions
       SET status = 'closed', closed_at = now(), total_amount = 0, gio_bat_dau = NULL, goi_phut = NULL, goi_gia = NULL
     WHERE id = p_session_id;
    SELECT COALESCE(sum(subtotal), 0) INTO v_tong FROM public.ban_session_items
    WHERE session_id = v_d.id AND store_id = p_store_id AND COALESCE(kitchen_status, '') <> 'huy';
    UPDATE public.ban_sessions SET total_amount = v_tong WHERE id = v_d.id;
  END IF;

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'kieu', v_kieu, 'session_id', CASE WHEN v_kieu = 'gop' THEN v_d.id ELSE p_session_id END,
    'chot', v_chot));
END
$function$
;


-- ── App lưu gói cho một hoặc nhiều bàn ("Cả khu") ──────────────────────────────────────────────
-- p_goi: [{"so_phut":120,"gia":100000}, …] theo thứ tự hiển thị. Mảng rỗng = bỏ hết gói. Khách đang chơi giữ gói đã chọn.
CREATE OR REPLACE FUNCTION public.ban_goi_gio_luu_v1(p_store_id uuid, p_table_ids text[], p_goi jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_staff record; v_k jsonb; v_phut int; v_gia numeric; v_n int; v_da int[] := '{}';
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_manage => true);

  v_n := COALESCE(cardinality(p_table_ids), 0);
  IF v_n < 1 OR v_n > 200 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Chưa chọn bàn');
  END IF;
  IF (SELECT count(DISTINCT id) FROM public.ban_dining_tables
      WHERE store_id = p_store_id AND id = ANY (p_table_ids) AND COALESCE(is_active, true))
     <> (SELECT count(DISTINCT x) FROM unnest(p_table_ids) x) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy bàn');
  END IF;
  IF p_goi IS NULL OR jsonb_typeof(p_goi) <> 'array' OR jsonb_array_length(p_goi) > 6 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Tối đa 6 gói mỗi bàn');
  END IF;
  FOR v_k IN SELECT * FROM jsonb_array_elements(p_goi) LOOP
    BEGIN
      v_phut := (v_k->>'so_phut')::int; v_gia := (v_k->>'gia')::numeric;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Gói không hợp lệ');
    END;
    IF v_phut IS NULL OR v_phut NOT BETWEEN 15 AND 720 OR v_gia IS NULL OR v_gia < 0 OR v_gia > 100000000
       OR v_gia <> round(v_gia) THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD',
        'message', 'Gói phải từ 15 phút tới 12 giờ, giá từ 0 đ');
    END IF;
    IF v_phut = ANY (v_da) THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Hai gói trùng số giờ');
    END IF;
    v_da := v_da || v_phut;
  END LOOP;

  DELETE FROM public.ban_goi_gio WHERE store_id = p_store_id AND table_id = ANY (p_table_ids);
  INSERT INTO public.ban_goi_gio (store_id, table_id, so_phut, gia, thu_tu)
  SELECT p_store_id, b.x, (k.v->>'so_phut')::int, (k.v->>'gia')::numeric, k.ord - 1
  FROM (SELECT DISTINCT x FROM unnest(p_table_ids) x) b
  CROSS JOIN jsonb_array_elements(p_goi) WITH ORDINALITY AS k(v, ord);
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('so_ban', v_n, 'so_goi', jsonb_array_length(p_goi)));
END
$f$;
REVOKE ALL ON FUNCTION public.ban_goi_gio_luu_v1(uuid, text[], jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ban_goi_gio_luu_v1(uuid, text[], jsonb) TO anon, authenticated, service_role;

-- ── Chọn / đổi / bỏ gói cho bàn đang chơi ───────────────────────────────────────────────────────
-- p_goi_id NULL = bỏ gói. Chọn lần đầu: quyền thu tiền. Đổi / bỏ gói đã có: Chủ quán / Quản lý.
CREATE OR REPLACE FUNCTION public.ban_chon_goi_gio_v1(p_store_id uuid, p_session_id uuid, p_goi_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_s record; v_g record;
BEGIN
  PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  SELECT * INTO v_s FROM public.ban_sessions WHERE id = p_session_id AND store_id = p_store_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy phiên bàn');
  END IF;
  IF v_s.status <> 'open' THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'SESSION_NOT_OPEN', 'message', 'Phiên bàn không còn mở');
  END IF;
  IF v_s.gio_bat_dau IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Bàn này không tính giờ');
  END IF;
  IF v_s.goi_phut IS NOT NULL THEN   -- đổi / bỏ gói đã chọn: đụng tiền khách đã thoả thuận
    PERFORM public.verify_staff_qr_membership_v4(p_store_id, p_require_manage => true);
  END IF;

  IF p_goi_id IS NULL THEN
    UPDATE public.ban_sessions SET goi_phut = NULL, goi_gia = NULL WHERE id = p_session_id;
    RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('goi_phut', NULL, 'goi_gia', NULL));
  END IF;
  SELECT * INTO v_g FROM public.ban_goi_gio
  WHERE id = p_goi_id AND store_id = p_store_id AND table_id = v_s.table_id::text;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Gói không còn ở bàn này');
  END IF;
  UPDATE public.ban_sessions SET goi_phut = v_g.so_phut, goi_gia = v_g.gia WHERE id = p_session_id;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('goi_phut', v_g.so_phut, 'goi_gia', v_g.gia));
END
$f$;
REVOKE ALL ON FUNCTION public.ban_chon_goi_gio_v1(uuid, uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ban_chon_goi_gio_v1(uuid, uuid, uuid) TO anon, authenticated, service_role;
