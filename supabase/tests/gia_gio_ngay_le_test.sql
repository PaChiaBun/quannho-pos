-- ============================================================================
-- TEST: 20261128_gia_gio_ngay_le.sql — ngày lễ trong bảng giá giờ. Một giao dịch, kết thúc ROLLBACK.
-- Bộ ca (kế hoạch .docs/ke-hoach-ngay-le-gia-gio.md) dùng chung với test Dart test/modules/tinh_gio/gia_gio_ngay_le_test.dart.
-- 30/04/2027 là Thứ Sáu; 03/05/2027 là Thứ Hai. Giá gốc 60.000.
-- ============================================================================
BEGIN;
-- Như PostgREST trên máy chủ thật: UPDATE / DELETE không có WHERE bị chặn (bài học 28/11, lịch cố định).
LOAD 'safeupdate';

CREATE OR REPLACE FUNCTION public._nl_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}'
         ELSE json_build_object('sub', p_uid::text, 'role', p_role, 'store_id', p_store::text)::text END, true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', COALESCE(p_store::text, ''), 'x-user-id', COALESCE(p_uid::text, ''))::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._nl_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._nl_rpc(p_sql text)
RETURNS jsonb LANGUAGE plpgsql AS $f$
DECLARE j jsonb;
BEGIN
  EXECUTE p_sql INTO j;
  RETURN j;
EXCEPTION WHEN OTHERS THEN
  RETURN jsonb_build_object('raised', SQLSTATE, 'msg', SQLERRM);
END
$f$;
GRANT EXECUTE ON FUNCTION public._nl_rpc(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public._nl_tien(p_ban text, p_vao timestamptz, p_phut int, p_goc numeric DEFAULT 60000)
RETURNS numeric LANGUAGE sql AS $f$ SELECT (public.qn_tinh_gio_tinh_tien_v2(p_ban, p_goc, p_vao, p_phut)->>'thanh_tien')::numeric $f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); S uuid := gen_random_uuid(); S2 uuid := gen_random_uuid();
  Z text := gen_random_uuid()::text;
  T0 text := gen_random_uuid()::text; T1 text := gen_random_uuid()::text; T2 text := gen_random_uuid()::text;
  T3 text := gen_random_uuid()::text;
  PG uuid := gen_random_uuid();
  j jsonb; i int; v_phut int; v_vao timestamptz; v_sai int := 0;
  v_hom_nay date := (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
BEGIN
  RAISE NOTICE '>>> NGÀY LỄ TRONG GIÁ GIỜ: BẮT ĐẦU <<<';
  PERFORM public._nl_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*33000000)::int), 'x', 'Chu A'),
    (B, '+84' || (933000001 + (random()*33000000)::int), 'x', 'Phuc vu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, created_at) VALUES
    (S, 'T' || substr(S::text, 1, 7), 'Quan test ngay le', A, now() - interval '1 day'),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan khac', A, now() - interval '1 day');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true), (B, S, 'waiter', false);
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu karaoke');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (T0, S, Z, 'Phong 0'), (T1, S, Z, 'Phong 1'), (T2, S, Z, 'Phong 2'), (T3, S, Z, 'Phong 3');
  INSERT INTO public.products (id, store_id, name, sell_price, cost_price, unit, is_available, is_active, category) VALUES
    (PG, S, 'Giờ hát 60.000 đ/giờ', 60000, 0, 'giờ', true, true, 'Tiền giờ');
  UPDATE public.ban_dining_tables SET gia_gio_product_id = PG WHERE id IN (T0, T1, T2, T3);

  -- L8: chỉ khung Lễ, quán chưa có ngày lễ → giá gốc
  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T0, '{8}', '00:00', '00:00', 100000, 0);
  PERFORM public._nl_ok(public._nl_tien(T0, '2027-04-30 18:00+07', 60) = 60000, 'L8 khung Lễ nhưng quán chưa có ngày lễ: giá gốc');

  INSERT INTO public.ban_ngay_le (store_id, ngay, ten) VALUES (S, '2027-04-30', '30/4'), (S, '2027-05-01', '1/5'),
    (S2, '2027-05-03', 'quán khác');

  -- L1, L2: Lễ cả ngày đứng DƯỚI khung thường vẫn thắng vào ngày lễ
  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T1, '{1,2,3,4,5}', '17:00', '23:00', 70000, 0),
    (S, T1, '{8}', '00:00', '00:00', 100000, 1);
  PERFORM public._nl_ok(public._nl_tien(T1, '2027-04-30 18:00+07', 60) = 100000, 'L1 ngày lễ: khung Lễ (đứng dưới) thắng = 100.000');
  PERFORM public._nl_ok(public._nl_tien(T1, '2027-05-03 18:00+07', 60) = 70000,
    'L2 ngày thường (Thứ Hai): khung T2–T6 = 70.000; ngày lễ của quán khác không ảnh hưởng');

  -- L3, L4: khung Lễ chỉ buổi sáng; giờ khác ngày lễ tính như ngày thường
  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T2, '{1,2,3,4,5}', '17:00', '23:00', 70000, 0),
    (S, T2, '{8}', '08:00', '12:00', 90000, 1);
  PERFORM public._nl_ok(public._nl_tien(T2, '2027-04-30 11:30+07', 60) = 75000, 'L3 30 × 90.000 + 30 × 60.000 = 75.000');
  PERFORM public._nl_ok(public._nl_tien(T2, '2027-04-30 17:30+07', 60) = 70000, 'L4 giờ không có khung Lễ: như ngày thường');

  -- L5, L6, L7: khung Lễ qua đêm tính theo ngày bắt đầu
  INSERT INTO public.ban_gia_gio_khung (store_id, table_id, thu, tu, den, gia, thu_tu) VALUES
    (S, T3, '{8}', '22:00', '02:00', 120000, 0);
  PERFORM public._nl_ok(public._nl_tien(T3, '2027-04-30 23:00+07', 120) = 240000, 'L5 Lễ 22–02 qua đêm 30/4 → 1/5: 240.000');
  PERFORM public._nl_ok(public._nl_tien(T3, '2027-04-29 23:00+07', 60) = 60000, 'L6 29/4 không lễ: giá gốc');
  DELETE FROM public.ban_ngay_le WHERE store_id = S AND ngay = '2027-04-30';
  PERFORM public._nl_ok(public._nl_tien(T3, '2027-04-30 23:30+07', 60) = 60000,
    'L7 chỉ 1/5 là lễ: 00:00–00:30 ngày 1/5 là phần qua đêm của 30/4 → giá gốc');
  PERFORM public._nl_ok(public._nl_tien(T3, '2027-05-01 23:30+07', 60) = 120000, 'L7b 1/5 23:30 → 2/5 00:30 trong khung Lễ');
  INSERT INTO public.ban_ngay_le (store_id, ngay, ten) VALUES (S, '2027-04-30', '30/4');

  -- L9: bàn không khung, quán có ngày lễ → công thức cũ
  FOR i IN 1 .. 2000 LOOP
    v_phut := 1 + floor(random() * 3000)::int;
    v_vao := '2027-04-25 00:00+07'::timestamptz + make_interval(secs => floor(random() * 86400 * 10));
    IF public._nl_tien(T0 || 'x', v_vao, v_phut) <> ceil(v_phut * 60000 / 60.0 / 1000.0) * 1000 THEN
      v_sai := v_sai + 1;
    END IF;
  END LOOP;
  PERFORM public._nl_ok(v_sai = 0, 'L9 HỒI QUY 2.000 lượt quanh ngày lễ, bàn không khung: khớp công thức cũ (sai ' || v_sai || ')');

  -- ── Lưu qua hàm app ────────────────────────────────────────────────────────────────────────
  PERFORM public._nl_as('authenticated', A, S);
  j := public._nl_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 1, 0, 0,
        '[{"thu":[6,7,8],"tu":"17:00","den":"23:00","gia":110000}]'::jsonb)$q$, S, T0));
  PERFORM public._nl_ok((j->>'success')::boolean, 'L10 lưu khung có Ngày lễ (thứ 8) — ' || j::text);
  j := public._nl_rpc(format($q$SELECT public.ban_gia_gio_luu_v1(%L, ARRAY[%L], 1, 0, 0,
        '[{"thu":[9],"tu":"17:00","den":"23:00","gia":1}]'::jsonb)$q$, S, T0));
  PERFORM public._nl_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L10b thứ 9 bị từ chối');

  PERFORM public._nl_as('authenticated', B, S);
  j := public._nl_rpc(format($q$SELECT public.ban_ngay_le_luu_v1(%L, '[{"ngay":"%s","ten":"x"}]'::jsonb, '{}')$q$, S, v_hom_nay + 10));
  PERFORM public._nl_ok(j->>'raised' = '42501', 'L11 phục vụ không sửa được ngày lễ — ' || j::text);

  PERFORM public._nl_as('authenticated', A, S);
  j := public._nl_rpc(format($q$SELECT public.ban_ngay_le_luu_v1(%L,
        '[{"ngay":"%s","ten":" Tết "},{"ngay":"%s","ten":"Tết"},{"ngay":"2027-04-30","ten":"Giải phóng"}]'::jsonb,
        ARRAY['2027-05-01']::date[])$q$, S, v_hom_nay + 10, v_hom_nay + 11));
  PERFORM public._nl_as('admin');
  PERFORM public._nl_ok((j->>'success')::boolean
    AND (SELECT count(*) FROM public.ban_ngay_le WHERE store_id = S) = 3
    AND (SELECT ten FROM public.ban_ngay_le WHERE store_id = S AND ngay = '2027-04-30') = 'Giải phóng'
    AND (SELECT ten FROM public.ban_ngay_le WHERE store_id = S AND ngay = v_hom_nay + 10) = 'Tết'
    AND NOT EXISTS (SELECT 1 FROM public.ban_ngay_le WHERE store_id = S AND ngay = '2027-05-01')
    AND (SELECT count(*) FROM public.ban_ngay_le WHERE store_id = S2) = 1,
    'L12 thêm 2 ngày, đổi tên 30/4, xoá 1/5; quán khác giữ nguyên — ' || j::text);
  PERFORM public._nl_as('authenticated', A, S);
  j := public._nl_rpc(format($q$SELECT public.ban_ngay_le_luu_v1(%L, '[{"ngay":"%s"}]'::jsonb, '{}')$q$, S, v_hom_nay + 1200));
  PERFORM public._nl_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L12b ngày quá 3 năm tới bị từ chối');
  j := public._nl_rpc(format($q$SELECT public.ban_ngay_le_luu_v1(%L, '[{"ngay":"30/04"}]'::jsonb, '{}')$q$, S));
  PERFORM public._nl_ok(j->>'error_code' = 'INVALID_PAYLOAD', 'L12c ngày sai định dạng bị từ chối');
  PERFORM public._nl_as('admin');

  RAISE NOTICE '>>> NGÀY LỄ TRONG GIÁ GIỜ: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
