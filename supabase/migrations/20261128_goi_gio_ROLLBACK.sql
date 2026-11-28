-- Hoàn tác 20261128_goi_gio.sql: qn_tinh_gio_tinh_tien_v2 về NGUYÊN VĂN bản đợt 6, qn_tinh_gio_ghi_dong_v1 về bản
-- đợt 1, ban_chuyen_ban_tinh_gio_v1 về bản production 28/11; bỏ v3, hàm gói, trigger, hai cột và bảng gói.
-- Bàn đang chơi có gói sẽ tính lại theo phút như thường.
DROP TRIGGER IF EXISTS qn_tinh_gio_goi_khoa ON public.ban_sessions;
DROP FUNCTION IF EXISTS public.qn_tinh_gio_goi_khoa_v1();

-- ── Tính tiền giờ (một chỗ duy nhất; app chép đúng từng bước trong lib/modules/tinh_gio/gia_gio.dart) ──
-- Như đợt 1, thêm: mỗi phút, nếu ngày đó (hoặc hôm trước, cho phần qua đêm) là ngày lễ của quán thì xét các khung
-- Lễ (thu có 8) TRƯỚC theo thứ tự; không khung Lễ nào chứa phút đó thì xét theo thứ như cũ.
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
  v_thu_mang text[]; k_le boolean[];
  v_le date[]; v_co_le boolean := false; v_le_nay boolean; v_le_truoc boolean;
  i int; j int; v_luc timestamp; v_d int; v_d_truoc int; v_s time; v_gia numeric; v_khop boolean; v_xong boolean;
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
  FOR i IN 0 .. v_tinh - 1 LOOP
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
$function$
;

DROP FUNCTION IF EXISTS public.qn_tinh_gio_tinh_tien_v3(text, numeric, timestamptz, integer, integer, numeric);
DROP FUNCTION IF EXISTS public.ban_goi_gio_luu_v1(uuid, text[], jsonb);
DROP FUNCTION IF EXISTS public.ban_chon_goi_gio_v1(uuid, uuid, uuid);
ALTER TABLE public.ban_sessions DROP COLUMN IF EXISTS goi_phut;
ALTER TABLE public.ban_sessions DROP COLUMN IF EXISTS goi_gia;
DROP TABLE IF EXISTS public.ban_goi_gio;
