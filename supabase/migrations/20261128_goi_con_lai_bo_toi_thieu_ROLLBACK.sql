-- Hoàn tác 20261128_goi_con_lai_bo_toi_thieu.sql: qn_tinh_gio_tinh_tien_v3 về nguyên văn bản đợt 7 (20261128_goi_gio.sql).
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
