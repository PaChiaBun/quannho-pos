-- ============================================================================
-- 20261128_gia_gio_khung_block.sql — đợt 1 lộ trình tính giờ (.docs/ke-hoach-gia-gio-khung-block.md)
-- Giá theo khung giờ / thứ và làm tròn theo block, tối thiểu, ân hạn — cài RIÊNG TỪNG BÀN.
--
--   ban_gia_gio_cau_hinh   một dòng mỗi bàn: block_phut (1,5,10,15,20,30,60), toi_thieu_phut, an_han_phut
--   ban_gia_gio_khung      các khung giá của bàn: thứ (1 = T2 … 7 = CN, theo ngày khung BẮT ĐẦU), từ – đến
--                          (giờ VN; đến < từ = qua đêm; từ = đến = cả ngày), giá một giờ, thứ tự (khung trên thắng)
--   qn_tinh_gio_tinh_tien_v2  MỘT chỗ tính tiền: làm tròn số phút rồi tách theo khung từng phút,
--                          tiền = ceil(Σ phút × giá / 60 / 1000) × 1000
--   qn_tinh_gio_ghi_dong_v1  (thay) dùng hàm trên; tên dòng ghi chi tiết khi có nhiều giá / làm tròn
--   ban_gia_gio_luu_v1      app lưu cài đặt cho một hoặc nhiều bàn (Chủ quán / Quản lý; bàn đang chạy giờ thì từ chối)
--
-- Bàn KHÔNG cài gì (không dòng cấu hình, không khung): tính đúng từng đồng như công thức cũ (test hồi quy).
-- App đọc thẳng hai bảng (đúng quán) để tính tạm; không ghi thẳng.
-- Hoàn tác: 20261128_gia_gio_khung_block_ROLLBACK.sql. Test: supabase/tests/gia_gio_khung_block_test.sql
-- ============================================================================

DO $pf$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                 AND proname = 'qn_tinh_gio_ghi_dong_v1'
                 AND pg_get_function_identity_arguments(oid) = 'p_store uuid, p_session uuid, p_du_khung boolean') THEN
    RAISE EXCEPTION 'PREFLIGHT gia_gio_khung_block: chưa áp 20261124_ban_dat_truoc_v1.sql';
  END IF;
  RAISE NOTICE 'PREFLIGHT gia_gio_khung_block: OK';
END
$pf$;

CREATE TABLE IF NOT EXISTS public.ban_gia_gio_cau_hinh (
  table_id        text PRIMARY KEY REFERENCES public.ban_dining_tables(id) ON DELETE CASCADE,
  store_id        uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  block_phut      smallint NOT NULL DEFAULT 1,
  toi_thieu_phut  smallint NOT NULL DEFAULT 0,
  an_han_phut     smallint NOT NULL DEFAULT 0,
  updated_at      timestamptz NOT NULL DEFAULT now(),
  updated_by      uuid,
  CONSTRAINT ban_gia_gio_block CHECK (block_phut IN (1, 5, 10, 15, 20, 30, 60)),
  CONSTRAINT ban_gia_gio_toi_thieu CHECK (toi_thieu_phut BETWEEN 0 AND 600),
  CONSTRAINT ban_gia_gio_an_han CHECK (an_han_phut >= 0 AND (an_han_phut = 0 OR an_han_phut < block_phut))
);
CREATE INDEX IF NOT EXISTS ban_gia_gio_cau_hinh_store_idx ON public.ban_gia_gio_cau_hinh (store_id);

CREATE TABLE IF NOT EXISTS public.ban_gia_gio_khung (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id  uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  table_id  text NOT NULL REFERENCES public.ban_dining_tables(id) ON DELETE CASCADE,
  thu       smallint[] NOT NULL,
  tu        time NOT NULL,
  den       time NOT NULL,
  gia       numeric(12, 0) NOT NULL,
  thu_tu    smallint NOT NULL DEFAULT 0,
  CONSTRAINT ban_gia_gio_khung_thu CHECK (cardinality(thu) BETWEEN 1 AND 7 AND thu <@ ARRAY[1,2,3,4,5,6,7]::smallint[]),
  CONSTRAINT ban_gia_gio_khung_gia CHECK (gia BETWEEN 0 AND 100000000)
);
CREATE INDEX IF NOT EXISTS ban_gia_gio_khung_ban_idx ON public.ban_gia_gio_khung (table_id, thu_tu);
CREATE INDEX IF NOT EXISTS ban_gia_gio_khung_store_idx ON public.ban_gia_gio_khung (store_id);

ALTER TABLE public.ban_gia_gio_cau_hinh ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ban_gia_gio_khung ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ban_gia_gio_cau_hinh_doc ON public.ban_gia_gio_cau_hinh;
CREATE POLICY ban_gia_gio_cau_hinh_doc ON public.ban_gia_gio_cau_hinh
  FOR SELECT TO authenticated USING (store_id = (SELECT public.current_store_id()));
DROP POLICY IF EXISTS ban_gia_gio_khung_doc ON public.ban_gia_gio_khung;
CREATE POLICY ban_gia_gio_khung_doc ON public.ban_gia_gio_khung
  FOR SELECT TO authenticated USING (store_id = (SELECT public.current_store_id()));
REVOKE ALL ON public.ban_gia_gio_cau_hinh, public.ban_gia_gio_khung FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ban_gia_gio_cau_hinh, public.ban_gia_gio_khung TO authenticated, service_role;

-- ── Chữ cho tên dòng ──────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_thoi_luong_v1(p_phut integer)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'pg_catalog' AS $f$
  SELECT CASE WHEN p_phut < 60 THEN p_phut || ' phút'
              WHEN p_phut % 60 = 0 THEN (p_phut / 60) || ' giờ'
              ELSE (p_phut / 60) || ' giờ ' || (p_phut % 60) || ' phút' END
$f$;

CREATE OR REPLACE FUNCTION public.qn_tinh_gio_tien_chu_v1(p_tien numeric)
RETURNS text LANGUAGE sql IMMUTABLE SET search_path TO 'pg_catalog' AS $f$
  SELECT replace(to_char(round(GREATEST(COALESCE(p_tien, 0), 0)), 'FM999,999,999,990'), ',', '.')
$f$;

-- ── Tính tiền giờ (một chỗ duy nhất; app chép đúng từng bước trong lib/modules/tinh_gio/tinh_gio.dart) ──
-- p_phut_choi đã gồm phần kéo tới hết khung đặt trước (như ghi_dong làm). Trả:
--   so_phut_choi, so_phut_tinh, thanh_tien, doan: [{tu, phut, gia}] (đoạn liền nhau cùng giá, tu = giờ bắt đầu đoạn)
CREATE OR REPLACE FUNCTION public.qn_tinh_gio_tinh_tien_v2(
  p_table text, p_gia_goc numeric, p_vao timestamptz, p_phut_choi integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO 'public', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  TZ constant text := 'Asia/Ho_Chi_Minh';
  v_block int := 1; v_toi_thieu int := 0; v_an_han int := 0;
  v_choi int := GREATEST(1, COALESCE(p_phut_choi, 1));
  v_tinh int; v_q int; v_r int;
  v_goc numeric := GREATEST(COALESCE(p_gia_goc, 0), 0);
  k_tu time[]; k_den time[]; k_gia numeric[]; k_n int;
  v_thu_mang text[];
  i int; j int; v_luc timestamp; v_d int; v_d_truoc int; v_s time; v_gia numeric; v_khop boolean;
  v_doan jsonb := '[]'::jsonb; v_doan_tu timestamptz; v_doan_phut int := 0; v_doan_gia numeric;
  v_tong numeric := 0;
BEGIN
  SELECT block_phut, toi_thieu_phut, an_han_phut INTO v_block, v_toi_thieu, v_an_han
  FROM public.ban_gia_gio_cau_hinh WHERE table_id = p_table;
  v_block := COALESCE(v_block, 1); v_toi_thieu := COALESCE(v_toi_thieu, 0); v_an_han := COALESCE(v_an_han, 0);

  -- 1) làm tròn: quá bội số block không quá ân hạn thì giữ bội số đó, còn lại lên block kế; rồi tối thiểu
  v_q := v_choi / v_block; v_r := v_choi % v_block;
  v_tinh := CASE WHEN v_r = 0 THEN v_choi
                 WHEN v_q > 0 AND v_r <= v_an_han THEN v_q * v_block
                 ELSE (v_q + 1) * v_block END;
  v_tinh := GREATEST(v_tinh, v_toi_thieu);

  -- 2) các khung của bàn, theo thứ tự (khung đứng trên thắng)
  SELECT array_agg(array_to_string(thu, ',') ORDER BY thu_tu, id), array_agg(tu ORDER BY thu_tu, id),
         array_agg(den ORDER BY thu_tu, id), array_agg(gia ORDER BY thu_tu, id)
    INTO v_thu_mang, k_tu, k_den, k_gia
  FROM public.ban_gia_gio_khung WHERE table_id = p_table;
  k_n := COALESCE(array_length(k_tu, 1), 0);

  -- 3) từng phút lấy giá của khung chứa thời điểm bắt đầu phút đó (giờ VN); gộp phút liền nhau cùng giá
  FOR i IN 0 .. v_tinh - 1 LOOP
    v_gia := v_goc;
    IF k_n > 0 THEN
      v_luc := (p_vao + make_interval(mins => i)) AT TIME ZONE TZ;
      v_d := extract(isodow FROM v_luc)::int;
      v_d_truoc := CASE WHEN v_d = 1 THEN 7 ELSE v_d - 1 END;
      v_s := v_luc::time;
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
    'thanh_tien', ceil(v_tong / 60.0 / 1000.0) * 1000, 'doan', v_doan);
END
$f$;
REVOKE ALL ON FUNCTION public.qn_tinh_gio_tinh_tien_v2(text, numeric, timestamptz, integer) FROM PUBLIC, anon, authenticated;

-- ── Ghi dòng tiền giờ: dùng hàm tính chung ─────────────────────────────────────────────────────
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
  v_tinh := public.qn_tinh_gio_tinh_tien_v2(v_t.id, v_p.sell_price, v_s.gio_bat_dau, v_phut);
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
    'doan', v_tinh->'doan',
    'gia_gio', COALESCE(v_p.sell_price, 0), 'thanh_tien', v_tien, 'ten', v_ten, 'tong_ban', v_tong,
    'theo_khung_dat', v_khung_den IS NOT NULL AND v_den = v_khung_den);
END
$function$
;

REVOKE ALL ON FUNCTION public.qn_tinh_gio_ghi_dong_v1(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;

-- ── App lưu khung giá + làm tròn cho một hoặc nhiều bàn ("Cả khu") ─────────────────────────────
-- p_khung: [{"thu":[1,2,3,4,5],"tu":"17:00","den":"23:00","gia":70000}, …] theo thứ tự (khung trên thắng).
-- Mảng rỗng + block 1 + tối thiểu 0 + ân hạn 0 = xoá cài đặt (bàn tính như cũ).
CREATE OR REPLACE FUNCTION public.ban_gia_gio_luu_v1(
  p_store_id uuid, p_table_ids text[], p_block integer, p_toi_thieu integer, p_an_han integer, p_khung jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_staff record; v_k jsonb; v_thu smallint[]; v_tu time; v_den time; v_gia numeric; v_n int; v_ban text;
  v_mac_dinh boolean;
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
  IF COALESCE(p_block, 0) NOT IN (1, 5, 10, 15, 20, 30, 60)
     OR COALESCE(p_toi_thieu, -1) NOT BETWEEN 0 AND 600
     OR COALESCE(p_an_han, -1) < 0 OR (p_an_han > 0 AND p_an_han >= p_block) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Cách làm tròn không hợp lệ');
  END IF;
  IF p_khung IS NULL OR jsonb_typeof(p_khung) <> 'array' OR jsonb_array_length(p_khung) > 12 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Tối đa 12 khung giá');
  END IF;
  FOR v_k IN SELECT * FROM jsonb_array_elements(p_khung) LOOP
    BEGIN
      v_thu := ARRAY(SELECT DISTINCT x::smallint FROM jsonb_array_elements_text(v_k->'thu') x ORDER BY 1);
      v_tu := (v_k->>'tu')::time; v_den := (v_k->>'den')::time; v_gia := (v_k->>'gia')::numeric;
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Khung giá không hợp lệ');
    END;
    IF cardinality(v_thu) < 1 OR NOT v_thu <@ ARRAY[1,2,3,4,5,6,7]::smallint[] OR v_tu IS NULL OR v_den IS NULL
       OR v_gia IS NULL OR v_gia < 0 OR v_gia > 100000000 OR v_gia <> round(v_gia) THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Khung giá không hợp lệ');
    END IF;
  END LOOP;

  -- Bàn đang chạy giờ: đổi giá giữa chừng dễ cãi nhau với khách (như đổi món giá giờ).
  SELECT t.label INTO v_ban FROM public.ban_sessions s JOIN public.ban_dining_tables t ON t.id = s.table_id::text
  WHERE s.store_id = p_store_id AND s.status = 'open' AND s.gio_bat_dau IS NOT NULL
    AND s.table_id::text = ANY (p_table_ids) LIMIT 1;
  IF FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'TINH_GIO_BAN_DANG_CHAY',
      'message', COALESCE(v_ban, 'Bàn') || ' đang có khách tính giờ, tính tiền xong mới đổi giá được');
  END IF;

  v_mac_dinh := p_block = 1 AND p_toi_thieu = 0 AND p_an_han = 0 AND jsonb_array_length(p_khung) = 0;
  DELETE FROM public.ban_gia_gio_khung WHERE store_id = p_store_id AND table_id = ANY (p_table_ids);
  IF v_mac_dinh THEN
    DELETE FROM public.ban_gia_gio_cau_hinh WHERE store_id = p_store_id AND table_id = ANY (p_table_ids);
  ELSE
    INSERT INTO public.ban_gia_gio_cau_hinh (table_id, store_id, block_phut, toi_thieu_phut, an_han_phut, updated_at, updated_by)
    SELECT DISTINCT x, p_store_id, p_block, p_toi_thieu, p_an_han, now(), v_staff.member_user_id FROM unnest(p_table_ids) x
    ON CONFLICT (table_id) DO UPDATE SET block_phut = EXCLUDED.block_phut, toi_thieu_phut = EXCLUDED.toi_thieu_phut,
      an_han_phut = EXCLUDED.an_han_phut, updated_at = now(), updated_by = EXCLUDED.updated_by;
    INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu)
    SELECT p_store_id, b.x,
           ARRAY(SELECT DISTINCT y::smallint FROM jsonb_array_elements_text(k.v->'thu') y ORDER BY 1),
           (k.v->>'tu')::time, (k.v->>'den')::time, (k.v->>'gia')::numeric, k.ord - 1
    FROM (SELECT DISTINCT x FROM unnest(p_table_ids) x) b
    CROSS JOIN jsonb_array_elements(p_khung) WITH ORDINALITY AS k(v, ord);
  END IF;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('so_ban', v_n, 'mac_dinh', v_mac_dinh));
END
$f$;
REVOKE ALL ON FUNCTION public.ban_gia_gio_luu_v1(uuid, text[], integer, integer, integer, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ban_gia_gio_luu_v1(uuid, text[], integer, integer, integer, jsonb) TO anon, authenticated, service_role;
