-- ============================================================================
-- TEST HỒI QUY: 4 RPC báo cáo *_for_range_v1 phải kiểm quyền thành viên quán
-- (get_report_stats / get_daily_revenue / get_top_products / get_sold_categories)
-- Khóa chặn do FIX05a (20261007_fix05a_khoa_bang_khong_realtime.sql) – test này chống lùi.
-- Từ 20261026_va_quyen_bep_bao_cao_v1.sql: anon KHÔNG còn quyền gọi 4 RPC này (kể cả kèm x-user-id
-- thật — header tự khai giả được); app cũ chạy anon tự tính từ bảng (dashboard_repository.dart).
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._bcq_as(p_role text, p_sub uuid DEFAULT NULL, p_hdr_uid uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN EXECUTE format('SET LOCAL ROLE %I', p_role); END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_sub::text, ''), true);
  -- anon của PostgREST luôn có claims {"role":"anon"} (không NULL); authenticated có thêm sub
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_sub IS NULL THEN json_build_object('role', p_role)::text
         ELSE json_build_object('sub', p_sub::text, 'role', p_role)::text END, true);
  PERFORM set_config('request.headers',
    CASE WHEN p_hdr_uid IS NULL THEN '{}' ELSE json_build_object('x-user-id', p_hdr_uid::text)::text END, true);
END $f$;

CREATE OR REPLACE FUNCTION public._bcq_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END $f$;

-- Gọi 1 trong 4 RPC; trả 'denied' nếu bị 42501, 'ok:<số dòng/giá trị>' nếu qua
CREATE OR REPLACE FUNCTION public._bcq_call(p_fn int, p_store uuid)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE v_from timestamptz := '2026-10-01 00:00+07'; v_to timestamptz := '2026-10-08 00:00+07'; n int; j jsonb;
BEGIN
  IF p_fn = 1 THEN j := public.get_report_stats_for_range_v1(p_store, v_from, v_to); RETURN 'ok:' || COALESCE(j->>'total_revenue', j->>'totalRevenue', '?');
  ELSIF p_fn = 2 THEN SELECT count(*) INTO n FROM public.get_daily_revenue_for_range_v1(p_store, v_from, v_to); RETURN 'ok:' || n;
  ELSIF p_fn = 3 THEN SELECT count(*) INTO n FROM public.get_top_products_for_range_v1(p_store, v_from, v_to, NULL, 20); RETURN 'ok:' || n;
  ELSE SELECT count(*) INTO n FROM public.get_sold_categories_for_range_v1(p_store, v_from, v_to); RETURN 'ok:' || n;
  END IF;
EXCEPTION WHEN insufficient_privilege THEN RETURN 'denied';
END $f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid();  -- chủ S1
  B uuid := gen_random_uuid();  -- chủ S3 (người ngoài với S1)
  M uuid := gen_random_uuid();  -- nhân viên S1
  S1 uuid := gen_random_uuid();
  S3 uuid := gen_random_uuid();
  fn int;
  r text;
  names text[] := ARRAY['get_report_stats','get_daily_revenue','get_top_products','get_sold_categories'];
BEGIN
  RAISE NOTICE '>>> BÁO CÁO RPC QUYỀN: BẮT ĐẦU <<<';
  PERFORM public._bcq_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (B, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Chu B'),
    (M, '+84' || (700000000 + (random()*99999999)::int), 'x', 'NV M');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S1, 'T' || substr(S1::text, 1, 7), 'Quan 1', A),
    (S3, 'T' || substr(S3::text, 1, 7), 'Quan 3', B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S1, 'owner', true), (B, S3, 'owner', true), (M, S1, 'waiter', false);
  INSERT INTO public.orders (id, store_id, status, total_amount, total, payment_method, discount, created_at) VALUES
    (gen_random_uuid(), S1, 'completed', 100000, 100000, 'cash', 0, '2026-10-02 10:00+07');

  FOR fn IN 1..4 LOOP
    -- T1 anon không header: bị chặn
    PERFORM public._bcq_as('anon');
    PERFORM public._bcq_ok(public._bcq_call(fn, S1) = 'denied', names[fn] || ': anon không header bị chặn');
    -- T2 anon + x-user-id của NGƯỜI NGOÀI quán: bị chặn
    PERFORM public._bcq_as('anon', NULL, B);
    PERFORM public._bcq_ok(public._bcq_call(fn, S1) = 'denied', names[fn] || ': anon + x-user-id người ngoài bị chặn');
    -- T3 anon + x-user-id không phải uuid / uuid lạ: bị chặn
    PERFORM public._bcq_as('anon', NULL, gen_random_uuid());
    PERFORM public._bcq_ok(public._bcq_call(fn, S1) = 'denied', names[fn] || ': anon + x-user-id lạ bị chặn');
    -- T4 anon + x-user-id của chủ/nhân viên quán mình: bị chặn (vá 26/10, trước đây xem được)
    PERFORM public._bcq_as('anon', NULL, A);
    r := public._bcq_call(fn, S1);
    PERFORM public._bcq_ok(r = 'denied', names[fn] || ': anon + x-user-id chủ quán bị chặn (' || r || ')');
    PERFORM public._bcq_as('anon', NULL, M);
    PERFORM public._bcq_ok(public._bcq_call(fn, S1) = 'denied', names[fn] || ': anon + x-user-id nhân viên bị chặn');
    -- T5 …nhưng không xem được quán khác của mình không thuộc về
    PERFORM public._bcq_as('anon', NULL, A);
    PERFORM public._bcq_ok(public._bcq_call(fn, S3) = 'denied', names[fn] || ': chủ S1 không xem được S3 (anon)');
    -- T6 authenticated (JWT) thành viên: xem được; người ngoài: bị chặn
    PERFORM public._bcq_as('authenticated', A);
    PERFORM public._bcq_ok(public._bcq_call(fn, S1) LIKE 'ok:%', names[fn] || ': authenticated chủ quán xem được');
    PERFORM public._bcq_as('authenticated', B);
    PERFORM public._bcq_ok(public._bcq_call(fn, S1) = 'denied', names[fn] || ': authenticated người ngoài bị chặn');
    -- T7 authenticated không mạo danh bằng header x-user-id (JWT thắng)
    PERFORM public._bcq_as('authenticated', B, A);
    PERFORM public._bcq_ok(public._bcq_call(fn, S1) = 'denied', names[fn] || ': authenticated B + header x-user-id=A vẫn bị chặn');
    -- T8 store_id NULL / không tồn tại
    PERFORM public._bcq_as('anon', NULL, A);
    PERFORM public._bcq_ok(public._bcq_call(fn, gen_random_uuid()) = 'denied', names[fn] || ': store_id không tồn tại bị chặn');
  END LOOP;

  PERFORM public._bcq_as('admin');
  RAISE NOTICE '>>> BÁO CÁO RPC QUYỀN: TẤT CẢ ĐẠT <<<';
END
$test$;

ROLLBACK;
