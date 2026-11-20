-- ============================================================================
-- TEST: Xoá thu/chi an toàn (20261022_xoa_thu_chi_an_toan_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._tc_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  IF p_role IN ('anon', 'authenticated') THEN
    EXECUTE format('SET LOCAL ROLE %I', p_role);
  END IF;
  PERFORM set_config('request.jwt.claim.sub', COALESCE(p_uid::text, ''), true);
  PERFORM set_config('request.jwt.claims',
    CASE WHEN p_uid IS NULL THEN '{}'
         ELSE json_build_object('sub', p_uid::text, 'role', p_role, 'store_id', p_store::text)::text END, true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', COALESCE(p_store::text, ''), 'x-user-id', COALESCE(p_uid::text, ''))::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._tc_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._tc_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
DECLARE n integer;
BEGIN
  EXECUTE p_sql;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN 'ok:' || n;
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- chủ quán
  M  uuid := gen_random_uuid();   -- quản lý
  W  uuid := gen_random_uuid();   -- phục vụ
  B  uuid := gen_random_uuid();   -- chủ quán khác
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  R_MAN  uuid := gen_random_uuid();  -- phiếu chi nhập tay
  R_MAN2 uuid := gen_random_uuid();  -- phiếu thu nhập tay
  R_AUTO uuid := gen_random_uuid();  -- thu tự động (thanh toán)
  R_S2   uuid := gen_random_uuid();  -- phiếu của quán khác
  v  jsonb;
  t  text;
  n  int;
BEGIN
  RAISE NOTICE '>>> XOÁ THU CHI AN TOÀN v1: BẮT ĐẦU <<<';
  PERFORM public._tc_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (M, '+84' || (600000000 + (random()*99999999)::int), 'x', 'Quan ly M'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W'),
    (B, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S,  'T' || substr(S::text, 1, 7),  'Quan thu chi', A),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan khac',    B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (M, S, 'manager', false), (W, S, 'waiter', false), (B, S2, 'owner', true);
  INSERT INTO public.finance_records (id, store_id, type, amount, description, is_auto, fund_type) VALUES
    (R_MAN,  S,  'expense', 50000,  'Mua đá',        false, 'cash'),
    (R_MAN2, S,  'income',  20000,  'Thu khác',      false, 'cash'),
    (R_AUTO, S,  'income',  120000, 'Thanh toán bàn', true, 'cash'),
    (R_S2,   S2, 'expense', 10000,  'Quán khác',     false, 'cash');

  -- T1: app xoá thẳng (kiểu app cũ) bị chặn, dòng còn nguyên
  PERFORM public._tc_as('authenticated', A, S);
  t := public._tc_try(format($q$DELETE FROM public.finance_records WHERE id = %L$q$, R_MAN));
  PERFORM public._tc_as('admin');
  PERFORM public._tc_ok(t = 'err:42501' AND EXISTS (SELECT 1 FROM public.finance_records WHERE id = R_MAN),
    'T1 chủ quán xoá thẳng bị chặn, dòng còn (' || t || ')');

  -- T2: app sửa thẳng số tiền (kể cả dòng tự động) bị chặn
  PERFORM public._tc_as('authenticated', A, S);
  t := public._tc_try(format($q$UPDATE public.finance_records SET amount = 1 WHERE id = %L$q$, R_AUTO));
  PERFORM public._tc_ok(t = 'err:42501', 'T2 sửa thẳng thu chi bị chặn (' || t || ')');

  -- T3: app vẫn ghi phiếu mới được
  t := public._tc_try(format($q$INSERT INTO public.finance_records (store_id, type, amount, is_auto, fund_type) VALUES (%L, 'expense', 1000, false, 'cash')$q$, S));
  PERFORM public._tc_ok(t = 'ok:1', 'T3 vẫn ghi phiếu thu chi mới (' || t || ')');

  -- T4: phục vụ gọi RPC → PERMISSION_DENIED
  PERFORM public._tc_as('authenticated', W, S);
  v := public.delete_manual_finance_record_v1(S, R_MAN, 'Nhập nhầm');
  PERFORM public._tc_ok(v->>'error_code' = 'PERMISSION_DENIED', 'T4 phục vụ không xoá được (' || COALESCE(v->>'error_code', '?') || ')');

  -- T5: thiếu lý do → REASON_REQUIRED
  PERFORM public._tc_as('authenticated', A, S);
  v := public.delete_manual_finance_record_v1(S, R_MAN, '  ');
  PERFORM public._tc_ok(v->>'error_code' = 'REASON_REQUIRED', 'T5 bắt buộc lý do');

  -- T6: dòng tự động → AUTO_RECORD, không xoá
  v := public.delete_manual_finance_record_v1(S, R_AUTO, 'Thử xoá doanh thu');
  PERFORM public._tc_as('admin');
  PERFORM public._tc_ok(v->>'error_code' = 'AUTO_RECORD' AND EXISTS (SELECT 1 FROM public.finance_records WHERE id = R_AUTO),
    'T6 không xoá được dòng tự động từ thanh toán');

  -- T7: phiếu của quán khác → NOT_FOUND, không xoá
  PERFORM public._tc_as('authenticated', A, S);
  v := public.delete_manual_finance_record_v1(S, R_S2, 'Xoá hộ quán khác');
  PERFORM public._tc_as('admin');
  PERFORM public._tc_ok(v->>'error_code' = 'NOT_FOUND' AND EXISTS (SELECT 1 FROM public.finance_records WHERE id = R_S2),
    'T7 không xoá được phiếu quán khác');

  -- T8: chủ quán xoá phiếu nhập tay → xoá + lưu vết đủ
  PERFORM public._tc_as('authenticated', A, S);
  v := public.delete_manual_finance_record_v1(S, R_MAN, 'Nhập nhầm số');
  PERFORM public._tc_as('admin');
  SELECT count(*) INTO n FROM public.finance_record_deletions
   WHERE record_id = R_MAN AND store_id = S AND actor_user_id = A AND reason = 'Nhập nhầm số'
     AND (record->>'amount')::numeric = 50000 AND record->>'description' = 'Mua đá';
  PERFORM public._tc_ok((v->>'success')::boolean AND NOT (v#>>'{data,already_deleted}')::boolean
    AND NOT EXISTS (SELECT 1 FROM public.finance_records WHERE id = R_MAN) AND n = 1,
    'T8 chủ quán xoá được, lưu vết người xoá + lý do + nguyên dòng');

  -- T9: bấm lại (mạng chập chờn) → already_deleted, không thêm vết
  PERFORM public._tc_as('authenticated', A, S);
  v := public.delete_manual_finance_record_v1(S, R_MAN, 'Nhập nhầm số');
  PERFORM public._tc_as('admin');
  SELECT count(*) INTO n FROM public.finance_record_deletions WHERE record_id = R_MAN;
  PERFORM public._tc_ok((v->>'success')::boolean AND (v#>>'{data,already_deleted}')::boolean AND n = 1,
    'T9 gọi lại sau khi đã xoá → already_deleted, vết vẫn 1 dòng');

  -- T10: quản lý xoá được
  PERFORM public._tc_as('authenticated', M, S);
  v := public.delete_manual_finance_record_v1(S, R_MAN2, 'Khách trả lại');
  PERFORM public._tc_ok((v->>'success')::boolean, 'T10 quản lý xoá được (' || left(v::text, 80) || ')');

  -- T11: client đọc được vết của quán mình, không sửa/xoá được vết
  PERFORM public._tc_as('authenticated', A, S);
  SELECT count(*) INTO n FROM public.finance_record_deletions WHERE store_id = S;
  PERFORM public._tc_ok(n = 2, 'T11 chủ quán đọc được 2 dòng vết xoá');
  t := public._tc_try(format($q$DELETE FROM public.finance_record_deletions WHERE record_id = %L$q$, R_MAN));
  PERFORM public._tc_ok(t LIKE 'err:%', 'T11b không xoá được vết (' || t || ')');
  t := public._tc_try(format($q$INSERT INTO public.finance_record_deletions (store_id, record_id, record, reason) VALUES (%L, gen_random_uuid(), '{}', 'giả')$q$, S));
  PERFORM public._tc_ok(t LIKE 'err:%', 'T11c không tự thêm vết giả (' || t || ')');

  -- T12: quán khác không đọc được vết của quán này
  PERFORM public._tc_as('authenticated', B, S2);
  SELECT count(*) INTO n FROM public.finance_record_deletions WHERE store_id = S;
  PERFORM public._tc_ok(n = 0, 'T12 quán khác không thấy vết xoá');

  -- T13: anon cũng không xoá thẳng được
  PERFORM public._tc_as('anon', A, S);
  t := public._tc_try(format($q$DELETE FROM public.finance_records WHERE id = %L$q$, R_AUTO));
  PERFORM public._tc_as('admin');
  PERFORM public._tc_ok(EXISTS (SELECT 1 FROM public.finance_records WHERE id = R_AUTO), 'T13 anon không xoá được (' || t || ')');

  -- T14: quản trị (máy chủ) không bị chặn
  t := public._tc_try(format($q$UPDATE public.finance_records SET description = 'sửa bởi quản trị' WHERE id = %L$q$, R_AUTO));
  PERFORM public._tc_ok(t = 'ok:1', 'T14 quản trị vẫn sửa được (' || t || ')');

  RAISE NOTICE '>>> XOÁ THU CHI AN TOÀN v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
