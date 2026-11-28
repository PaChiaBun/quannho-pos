-- Hoàn tác 20261128_gia_gio_khung_block.sql: qn_tinh_gio_ghi_dong_v1 NGUYÊN VĂN bản production lấy 28/11
-- (bản 20261127_tinh_gio_ten_dong.sql), bỏ hàm và hai bảng mới (mất cài đặt khung giá / làm tròn của các bàn).
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
  -- giờ ra in = giờ vào + số phút tính tiền, để dòng không ghi "16:59–16:59 (1p)".
  -- 27/11: "Giờ chơi · Bàn 3 · 14:05 – 15:35 · 1 giờ 30 phút × 60.000 đ/giờ". Tên cũ bắt đầu bằng tên món
  -- giá giờ ("Tiền giờ 60.000 đ · …"), đặt cạnh số tiền thật dễ đọc nhầm là phải trả 60.000.
  v_ra := v_s.gio_bat_dau + make_interval(mins => v_phut);
  v_fmt := CASE WHEN (v_s.gio_bat_dau AT TIME ZONE TZ)::date = (v_ra AT TIME ZONE TZ)::date
                THEN 'HH24:MI' ELSE 'DD/MM HH24:MI' END;
  v_ten  := 'Giờ chơi · ' || COALESCE(NULLIF(trim(v_t.label), ''), v_t.name)
            || ' · ' || to_char(v_s.gio_bat_dau AT TIME ZONE TZ, v_fmt)
            || ' – ' || to_char(v_ra AT TIME ZONE TZ, v_fmt)
            || ' · ' || CASE WHEN v_phut < 60 THEN v_phut || ' phút'
                             WHEN v_phut % 60 = 0 THEN (v_phut / 60) || ' giờ'
                             ELSE (v_phut / 60) || ' giờ ' || (v_phut % 60) || ' phút' END
            || ' × ' || replace(to_char(round(GREATEST(COALESCE(v_p.sell_price, 0), 0)), 'FM999,999,999,990'), ',', '.')
            || ' đ/giờ';

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
$function$
;

REVOKE ALL ON FUNCTION public.qn_tinh_gio_ghi_dong_v1(uuid, uuid, boolean) FROM PUBLIC, anon, authenticated;
DROP FUNCTION IF EXISTS public.ban_gia_gio_luu_v1(uuid, text[], integer, integer, integer, jsonb);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_tinh_tien_v2(text, numeric, timestamptz, integer);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_thoi_luong_v1(integer);
DROP FUNCTION IF EXISTS public.qn_tinh_gio_tien_chu_v1(numeric);
DROP TABLE IF EXISTS public.ban_gia_gio_khung;
DROP TABLE IF EXISTS public.ban_gia_gio_cau_hinh;
