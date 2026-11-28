-- ============================================================================
-- 20261128_gia_gio_ngay_le.sql — đợt 6 lộ trình tính giờ (.docs/ke-hoach-ngay-le-gia-gio.md)
-- Ngày lễ trong bảng giá giờ. PHẢI ÁP SAU 20261128_gia_gio_khung_block.sql (đợt 1; tự kiểm, thiếu thì dừng).
--
--   ban_ngay_le             danh sách ngày lễ CỦA QUÁN (dùng chung mọi bàn), quán tự thêm
--   ban_gia_gio_khung.thu   nhận thêm 8 = Ngày lễ (khung Lễ)
--   qn_tinh_gio_tinh_tien_v2 (thay)  ngày lễ: khung Lễ LUÔN THẮNG (xét trước, theo thứ tự); giờ không có khung Lễ
--                           thì như ngày thường. Ngày của khung = ngày khung BẮT ĐẦU (như đợt 1).
--   ban_gia_gio_luu_v1 (thay)  nhận thứ 1–8
--   ban_ngay_le_luu_v1      app thêm / xoá ngày lễ (Chủ quán / Quản lý)
--
-- Quán không có ngày lễ hoặc bàn không có khung Lễ: tính y như đợt 1 (test hồi quy).
-- Hoàn tác: 20261128_gia_gio_ngay_le_ROLLBACK.sql. Test: supabase/tests/gia_gio_ngay_le_test.sql
-- ============================================================================

DO $pf$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE pronamespace = 'public'::regnamespace
                 AND proname = 'qn_tinh_gio_tinh_tien_v2') OR to_regclass('public.ban_gia_gio_khung') IS NULL THEN
    RAISE EXCEPTION 'PREFLIGHT gia_gio_ngay_le: chưa áp 20261128_gia_gio_khung_block.sql (đợt 1)';
  END IF;
  RAISE NOTICE 'PREFLIGHT gia_gio_ngay_le: OK';
END
$pf$;

CREATE TABLE IF NOT EXISTS public.ban_ngay_le (
  store_id    uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  ngay        date NOT NULL,
  ten         text NOT NULL DEFAULT '',
  created_at  timestamptz NOT NULL DEFAULT now(),
  created_by  uuid,
  PRIMARY KEY (store_id, ngay),
  CONSTRAINT ban_ngay_le_ten CHECK (char_length(ten) <= 40)
);
ALTER TABLE public.ban_ngay_le ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS ban_ngay_le_doc ON public.ban_ngay_le;
CREATE POLICY ban_ngay_le_doc ON public.ban_ngay_le
  FOR SELECT TO authenticated USING (store_id = (SELECT public.current_store_id()));
REVOKE ALL ON public.ban_ngay_le FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.ban_ngay_le TO authenticated, service_role;

ALTER TABLE public.ban_gia_gio_khung DROP CONSTRAINT IF EXISTS ban_gia_gio_khung_thu;
ALTER TABLE public.ban_gia_gio_khung ADD CONSTRAINT ban_gia_gio_khung_thu
  CHECK (cardinality(thu) BETWEEN 1 AND 8 AND thu <@ ARRAY[1,2,3,4,5,6,7,8]::smallint[]);

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

-- ── App thêm / xoá ngày lễ của quán ───────────────────────────────────────────────────────────
-- p_them: [{"ngay":"2027-04-30","ten":"30/4"}, …] (trùng ngày thì đổi tên); p_xoa: các ngày bỏ. Một giao dịch.
CREATE OR REPLACE FUNCTION public.ban_ngay_le_luu_v1(p_store_id uuid, p_them jsonb, p_xoa date[])
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'public', 'extensions', 'pg_catalog', 'pg_temp' AS $f$
DECLARE
  v_staff record; v_k jsonb; v_ngay date; v_ten text; v_hom_nay date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  v_so int;
BEGIN
  SELECT * INTO v_staff FROM public.verify_staff_qr_membership_v4(p_store_id, p_require_manage => true);

  IF p_them IS NULL OR jsonb_typeof(p_them) <> 'array' OR jsonb_array_length(p_them) > 60
     OR COALESCE(cardinality(p_xoa), 0) > 500 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Mỗi lần thêm tối đa 60 ngày');
  END IF;
  FOR v_k IN SELECT * FROM jsonb_array_elements(p_them) LOOP
    BEGIN
      v_ngay := (v_k->>'ngay')::date; v_ten := COALESCE(trim(v_k->>'ten'), '');
    EXCEPTION WHEN OTHERS THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Ngày không hợp lệ');
    END;
    IF v_ngay IS NULL OR v_ngay < v_hom_nay - 7 OR v_ngay > v_hom_nay + 1096 THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD',
        'message', 'Chỉ thêm được ngày lễ từ tuần trước tới 3 năm tới');
    END IF;
    IF char_length(v_ten) > 40 THEN
      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAYLOAD', 'message', 'Tên ngày lễ tối đa 40 chữ');
    END IF;
  END LOOP;

  DELETE FROM public.ban_ngay_le WHERE store_id = p_store_id AND ngay = ANY (COALESCE(p_xoa, '{}'::date[]));
  INSERT INTO public.ban_ngay_le (store_id, ngay, ten, created_by)
  SELECT DISTINCT ON ((k->>'ngay')::date) p_store_id, (k->>'ngay')::date, COALESCE(trim(k->>'ten'), ''), v_staff.member_user_id
  FROM jsonb_array_elements(p_them) k
  ON CONFLICT (store_id, ngay) DO UPDATE SET ten = EXCLUDED.ten;

  SELECT count(*) INTO v_so FROM public.ban_ngay_le WHERE store_id = p_store_id;
  IF v_so > 500 THEN
    RAISE EXCEPTION 'NGAY_LE_QUA_NHIEU: quán đã có quá 500 ngày lễ';
  END IF;
  RETURN jsonb_build_object('success', true, 'data', jsonb_build_object('so_ngay', v_so));
END
$f$;
REVOKE ALL ON FUNCTION public.ban_ngay_le_luu_v1(uuid, jsonb, date[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ban_ngay_le_luu_v1(uuid, jsonb, date[]) TO anon, authenticated, service_role;

-- ── (thay) App lưu khung giá + làm tròn cho một hoặc nhiều bàn ("Cả khu") ─────────────────────────────
-- 28/11 đợt 6: thứ nhận thêm 8 = Ngày lễ. Còn lại nguyên văn đợt 1.
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
    IF cardinality(v_thu) < 1 OR NOT v_thu <@ ARRAY[1,2,3,4,5,6,7,8]::smallint[] OR v_tu IS NULL OR v_den IS NULL
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
