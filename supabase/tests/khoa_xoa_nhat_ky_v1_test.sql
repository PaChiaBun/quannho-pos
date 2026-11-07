-- ============================================================================
-- TEST: Khoá xoá/sửa nhật ký kiểm toán (20261022_khoa_xoa_nhat_ky_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._kl_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
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

CREATE OR REPLACE FUNCTION public._kl_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._kl_try(p_sql text)
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
  A uuid := gen_random_uuid();
  S uuid := gen_random_uuid();
  L_ACT uuid := gen_random_uuid();   -- log nghiệp vụ
  L_PAY uuid := gen_random_uuid();   -- log nghiệp vụ viết hoa
  L_PRN uuid := gen_random_uuid();   -- log kỹ thuật
  L_SYS uuid := gen_random_uuid();   -- log kỹ thuật
  v text;
  n int;
BEGIN
  RAISE NOTICE '>>> KHOÁ XOÁ NHẬT KÝ v1: BẮT ĐẦU <<<';
  PERFORM public._kl_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
    VALUES (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Quan ly A');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES (S, 'T' || substr(S::text, 1, 7), 'Quan log', A);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S, 'owner', true);
  INSERT INTO public.app_logs (id, store_id, level, tag, message, created_at) VALUES
    (L_ACT, S, 'INFO', 'action', 'In lại bill', now()),
    (L_PAY, S, 'INFO', 'PAYROLL_STAFF_CONFIRM', 'Xác nhận lương', now()),
    (L_PRN, S, 'ERROR', 'printer', 'Máy in lỗi', now()),
    (L_SYS, S, 'INFO', 'system', 'Khởi động', now());

  PERFORM public._kl_as('authenticated', A, S);
  PERFORM public._kl_ok((SELECT count(*) FROM public.app_logs WHERE id IN (L_ACT, L_PAY, L_PRN, L_SYS)) = 4,
    'T0 client thấy 4 log thử');

  -- T1: xoá log nghiệp vụ bị chặn
  v := public._kl_try(format($q$DELETE FROM public.app_logs WHERE id = %L$q$, L_ACT));
  PERFORM public._kl_ok(v = 'err:42501', 'T1 không xoá được log action (' || v || ')');
  v := public._kl_try(format($q$DELETE FROM public.app_logs WHERE id = %L$q$, L_PAY));
  PERFORM public._kl_ok(v = 'err:42501', 'T1b không xoá được log viết hoa PAYROLL_STAFF_CONFIRM (' || v || ')');

  -- T2: lô lẫn nghiệp vụ + kỹ thuật (kiểu app cũ) → cả lô bị từ chối, không mất gì
  v := public._kl_try(format($q$DELETE FROM public.app_logs WHERE id IN (%L, %L)$q$, L_ACT, L_PRN));
  PERFORM public._kl_as('admin');
  SELECT count(*) INTO n FROM public.app_logs WHERE id IN (L_ACT, L_PRN);
  PERFORM public._kl_ok(v = 'err:42501' AND n = 2, 'T2 lô lẫn bị từ chối nguyên lô (' || v || ')');

  -- T3: xoá log kỹ thuật được (kiểu app mới)
  PERFORM public._kl_as('authenticated', A, S);
  v := public._kl_try(format($q$DELETE FROM public.app_logs WHERE id IN (%L, %L)$q$, L_PRN, L_SYS));
  PERFORM public._kl_ok(v = 'ok:2', 'T3 xoá log kỹ thuật được (' || v || ')');

  -- T4: sửa log bị chặn (cả nghiệp vụ)
  v := public._kl_try(format($q$UPDATE public.app_logs SET message = 'sửa' WHERE id = %L$q$, L_ACT));
  PERFORM public._kl_ok(v = 'err:42501', 'T4 không sửa được nội dung log (' || v || ')');

  -- T5: anon cũng bị chặn
  PERFORM public._kl_as('anon', A, S);
  v := public._kl_try(format($q$DELETE FROM public.app_logs WHERE id = %L$q$, L_ACT));
  PERFORM public._kl_as('admin');
  PERFORM public._kl_ok(EXISTS (SELECT 1 FROM public.app_logs WHERE id = L_ACT), 'T5 anon không xoá được log action (' || v || ')');

  -- T6: vẫn ghi log mới được (insert không bị ảnh hưởng)
  PERFORM public._kl_as('authenticated', A, S);
  v := public._kl_try(format($q$INSERT INTO public.app_logs (store_id, level, tag, message) VALUES (%L, 'INFO', 'action', 'log mới')$q$, S));
  PERFORM public._kl_ok(v = 'ok:1', 'T6 app vẫn ghi log mới (' || v || ')');

  -- T7: vai trò quản trị (lịch xoá log máy chủ) không bị chặn
  PERFORM public._kl_as('admin');
  v := public._kl_try(format($q$DELETE FROM public.app_logs WHERE id = %L$q$, L_ACT));
  PERFORM public._kl_ok(v = 'ok:1', 'T7 quản trị vẫn xoá được (' || v || ')');

  RAISE NOTICE '>>> KHOÁ XOÁ NHẬT KÝ v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
