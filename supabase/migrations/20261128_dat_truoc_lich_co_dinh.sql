-- ============================================================================
-- 20261128_dat_truoc_lich_co_dinh.sql — đợt 3 lộ trình tính giờ (.docs/ke-hoach-lich-co-dinh.md)
-- Lịch cố định: đặt lặp hàng tuần (khách quen thuê sân "T3, T5 18–20 giờ cả tháng").
--
--   ban_dat_truoc.chuoi_id        các buổi của một lịch cố định cùng mã (null = lượt lẻ)
--   ban_dat_truoc_lap_v1          sinh + ghi cả chuỗi trong một giao dịch, kiểm trùng mọi buổi
--   ban_dat_truoc_huy_chuoi_v1    huỷ các buổi còn chờ khách của chuỗi từ một mốc
-- Sửa / huỷ / nhận từng buổi vẫn qua các hàm của 20261124_ban_dat_truoc_v1.sql (buổi giữ chuoi_id).
-- Hoàn tác: 20261128_dat_truoc_lich_co_dinh_ROLLBACK.sql. Test: supabase/tests/dat_truoc_lich_co_dinh_test.sql
-- ============================================================================

DO $pf$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace AND proname = 'ban_dat_truoc_luu_v1') THEN
    RAISE EXCEPTION 'PREFLIGHT dat_truoc_lich_co_dinh: chưa áp 20261124_ban_dat_truoc_v1.sql';
  END IF;
  RAISE NOTICE 'PREFLIGHT dat_truoc_lich_co_dinh: OK';
END
$pf$;

ALTER TABLE public.ban_dat_truoc ADD COLUMN IF NOT EXISTS chuoi_id uuid;
CREATE INDEX IF NOT EXISTS ban_dat_truoc_chuoi_idx ON public.ban_dat_truoc (chuoi_id) WHERE chuoi_id IS NOT NULL;

-- ── Đặt lặp hàng tuần ────────────────────────────────────────────────────────────────────────
-- p_gio_tu: giờ bắt đầu của buổi đầu (lấy NGÀY bắt đầu và GIỜ ĐỒNG HỒ Việt Nam cho mọi buổi).
-- p_thu: 1 = T2 … 7 = CN. p_den_ngay: ngày cuối (tính cả ngày đó). Buổi đã qua bỏ, không báo.
-- Có buổi trùng mà p_bo_qua_trung = false: KHÔNG ghi gì, trả error_code TRUNG_GIO + 'trung' (danh sách buổi).
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_lap_v1(
  p_store_id uuid, p_table_id text, p_ten_khach text, p_sdt text,
  p_gio_tu timestamptz, p_phut integer, p_thu integer[], p_den_ngay date,
  p_ghi_chu text DEFAULT NULL, p_tien_coc numeric DEFAULT 0, p_bo_qua_trung boolean DEFAULT false)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  TZ constant text := 'Asia/Ho_Chi_Minh';
  v_staff record; v_trung jsonb := '[]'::jsonb; v_ghi jsonb := '[]'::jsonb; v_b record;
  v_ten text := NULLIF(trim(COALESCE(p_ten_khach, '')), '');
  v_sdt text := NULLIF(regexp_replace(COALESCE(p_sdt, ''), '[^0-9+]', '', 'g'), '');
  v_ngay_dau date; v_gio time; v_chuoi uuid := gen_random_uuid(); v_nguoi text; v_so int := 0; v_bo int := 0;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);

  IF v_ten IS NULL OR p_table_id IS NULL OR p_gio_tu IS NULL OR p_phut IS NULL OR p_den_ngay IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Thiếu tên khách, bàn hoặc giờ đặt');
  END IF;
  IF length(v_ten) > 80 OR length(COALESCE(v_sdt, '')) > 20 OR length(COALESCE(p_ghi_chu, '')) > 300
     OR COALESCE(p_tien_coc, 0) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Tên, số điện thoại, ghi chú hoặc tiền cọc không hợp lệ');
  END IF;
  IF p_phut < 15 OR p_phut > 1440 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_TIME', 'message', 'Mỗi buổi từ 15 phút tới 24 giờ');
  END IF;
  IF COALESCE(cardinality(p_thu), 0) < 1 OR NOT (p_thu <@ ARRAY[1,2,3,4,5,6,7]) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Chọn ít nhất một thứ trong tuần');
  END IF;
  v_ngay_dau := (p_gio_tu AT TIME ZONE TZ)::date;
  v_gio := (p_gio_tu AT TIME ZONE TZ)::time;
  IF p_den_ngay < v_ngay_dau OR p_den_ngay > v_ngay_dau + 366 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_TIME', 'message', 'Ngày kết thúc phải sau ngày bắt đầu, tối đa một năm');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.ban_dining_tables
                 WHERE id = p_table_id AND store_id = p_store_id AND COALESCE(is_active, true)) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_STATE', 'message', 'Không tìm thấy bàn');
  END IF;

  PERFORM pg_advisory_xact_lock(hashtext('ban_dat_truoc'), hashtext(p_table_id));

  CREATE TEMP TABLE IF NOT EXISTS _qn_buoi (tu timestamptz, den timestamptz) ON COMMIT DROP;
  DELETE FROM _qn_buoi;
  INSERT INTO _qn_buoi
  SELECT (d::date + v_gio) AT TIME ZONE TZ, ((d::date + v_gio) AT TIME ZONE TZ) + make_interval(mins => p_phut)
  FROM generate_series(v_ngay_dau, p_den_ngay, interval '1 day') d
  WHERE extract(isodow FROM d)::int = ANY (p_thu)
    AND ((d::date + v_gio) AT TIME ZONE TZ) + make_interval(mins => p_phut) > now();

  IF (SELECT count(*) FROM _qn_buoi) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_TIME', 'message', 'Không có buổi nào trong khoảng ngày đã chọn');
  END IF;
  IF (SELECT count(*) FROM _qn_buoi) > 120 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Tối đa 120 buổi một lần đặt');
  END IF;

  FOR v_b IN
    SELECT b.tu, b.den, t.ten_khach AS trung_ten, t.gio_tu AS trung_tu, t.gio_den AS trung_den
    FROM _qn_buoi b
    LEFT JOIN LATERAL (
      SELECT ten_khach, gio_tu, gio_den FROM public.ban_dat_truoc x
      WHERE x.store_id = p_store_id AND x.table_id = p_table_id AND x.trang_thai IN ('da_dat', 'da_nhan')
        AND x.gio_tu < b.den AND x.gio_den > b.tu
      ORDER BY x.gio_tu LIMIT 1) t ON true
    ORDER BY b.tu
  LOOP
    IF v_b.trung_ten IS NOT NULL THEN
      v_trung := v_trung || jsonb_build_object('tu', v_b.tu, 'den', v_b.den, 'ten_khach', v_b.trung_ten,
                                               'trung_tu', v_b.trung_tu, 'trung_den', v_b.trung_den);
    ELSE
      v_ghi := v_ghi || jsonb_build_object('tu', v_b.tu, 'den', v_b.den);
    END IF;
  END LOOP;

  IF jsonb_array_length(v_trung) > 0 AND NOT COALESCE(p_bo_qua_trung, false) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'TRUNG_GIO',
      'message', jsonb_array_length(v_trung) || ' buổi trùng giờ với lượt đặt khác', 'trung', v_trung,
      'so_buoi_ghi_duoc', jsonb_array_length(v_ghi));
  END IF;
  IF jsonb_array_length(v_ghi) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'TRUNG_GIO',
      'message', 'Mọi buổi đều trùng giờ với lượt đặt khác', 'trung', v_trung, 'so_buoi_ghi_duoc', 0);
  END IF;

  v_nguoi := public.qn_dat_truoc_ten_nguoi_v1(p_store_id, v_staff.member_user_id);
  INSERT INTO public.ban_dat_truoc
    (store_id, table_id, ten_khach, sdt, gio_tu, gio_den, ghi_chu, tien_coc, nguoi_tao, nguoi_tao_ten, chuoi_id)
  SELECT p_store_id, p_table_id, v_ten, v_sdt, (e->>'tu')::timestamptz, (e->>'den')::timestamptz,
         NULLIF(trim(COALESCE(p_ghi_chu, '')), ''), COALESCE(p_tien_coc, 0), v_staff.member_user_id, v_nguoi, v_chuoi
  FROM jsonb_array_elements(v_ghi) e;
  GET DIAGNOSTICS v_so = ROW_COUNT;
  v_bo := jsonb_array_length(v_trung);

  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object(
    'chuoi_id', v_chuoi, 'so_buoi', v_so, 'bo_qua', v_bo, 'trung', v_trung));
END
$f$;

-- ── Huỷ các buổi còn chờ khách của chuỗi từ một mốc ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.ban_dat_truoc_huy_chuoi_v1(p_store_id uuid, p_chuoi_id uuid, p_tu timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE v_staff record; v_so int;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_checkout => true);
  IF p_chuoi_id IS NULL OR p_tu IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Thiếu lịch cố định');
  END IF;
  UPDATE public.ban_dat_truoc
     SET trang_thai = 'huy', updated_at = now()
   WHERE store_id = p_store_id AND chuoi_id = p_chuoi_id AND trang_thai = 'da_dat' AND gio_tu >= p_tu;
  GET DIAGNOSTICS v_so = ROW_COUNT;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('so_buoi_huy', v_so));
END
$f$;

REVOKE ALL ON FUNCTION public.ban_dat_truoc_lap_v1(uuid, text, text, text, timestamptz, integer, integer[], date, text, numeric, boolean) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ban_dat_truoc_huy_chuoi_v1(uuid, uuid, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_lap_v1(uuid, text, text, text, timestamptz, integer, integer[], date, text, numeric, boolean) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.ban_dat_truoc_huy_chuoi_v1(uuid, uuid, timestamptz) TO anon, authenticated, service_role;
