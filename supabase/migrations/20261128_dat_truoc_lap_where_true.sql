-- ============================================================================
-- 20261128_dat_truoc_lap_where_true.sql — sửa nóng đợt 3 (lịch cố định), áp ngay sau 20261128_dat_truoc_lich_co_dinh.sql
-- Máy chủ chạy PostgREST với safeupdate: câu DELETE không có WHERE bị chặn ("DELETE requires a WHERE clause", 21000).
-- ban_dat_truoc_lap_v1 xoá bảng tạm _qn_buoi bằng "DELETE FROM _qn_buoi;" → app đặt lặp luôn lỗi. Test SQL chạy bằng
-- psql (không có safeupdate) nên không bắt được. Sửa duy nhất dòng đó thành "WHERE true"; còn lại nguyên văn.
-- Hoàn tác: chạy lại hàm trong 20261128_dat_truoc_lich_co_dinh.sql bản commit 0cc4764 (không cần: bản cũ hỏng).
-- ============================================================================
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
  DELETE FROM _qn_buoi WHERE true;   -- PostgREST bật safeupdate: DELETE phải có WHERE (lỗi 21000 lúc app gọi 28/11)
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
