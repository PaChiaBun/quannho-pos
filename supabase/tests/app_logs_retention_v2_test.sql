-- ============================================================================
-- TEST: lịch dọn log v2 (20261023_app_logs_retention_v2.sql). Kết thúc ROLLBACK.
-- Lưu ý: hàm dọn chạy trên TOÀN bảng — trong test thì ROLLBACK nên không mất gì.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._rt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._rt_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE || ':' || SQLERRM;
END
$f$;

DO $test$
DECLARE
  A uuid := gen_random_uuid();
  S uuid := gen_random_uuid();
  t text;
  r record;
  keep text[];
BEGIN
  RAISE NOTICE '>>> DỌN LOG v2: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
    VALUES (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu RT');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES (S, 'R' || substr(S::text, 1, 7), 'Quan RT', A);
  INSERT INTO public.app_logs (store_id, tag, message, created_at) VALUES
    (S, 'printer',   'tech_old',      now() - interval '40 days'),
    (S, 'printer',   'tech_new',      now() - interval '10 days'),
    (S, NULL,        'null_old',      now() - interval '40 days'),
    (S, 'kitchen',   'kitchen_old',   now() - interval '40 days'),
    (S, 'finance',   'finance_40',    now() - interval '40 days'),
    (S, 'Finance',   'finance_case',  now() - interval '40 days'),
    (S, 'payroll',   'payroll_40',    now() - interval '40 days'),
    (S, 'kho',       'kho_40',        now() - interval '40 days'),
    (S, 'settings',  'settings_40',   now() - interval '40 days'),
    (S, 'staff',     'staff_40',      now() - interval '40 days'),
    (S, 'inventory', 'inventory_40',  now() - interval '40 days'),
    (S, 'action',    'action_400',    now() - interval '400 days'),
    (S, 'finance',   'finance_400',   now() - interval '400 days'),
    (S, 'checkout',  'checkout_200',  now() - interval '200 days'),
    (S, 'printer',   'no_date',       NULL);

  -- 1. Chặn tham số nguy hiểm
  t := public._rt_try('SELECT public.qn_app_logs_purge(3, 365, 5000)');
  PERFORM public._rt_ok(t LIKE 'err:%RETENTION_TOO_SHORT%', '1 không cho giữ log kỹ thuật < 7 ngày');
  t := public._rt_try('SELECT public.qn_app_logs_purge(30, 30, 5000)');
  PERFORM public._rt_ok(t LIKE 'err:%RETENTION_TOO_SHORT%', '1b không cho giữ log nghiệp vụ < 90 ngày');
  t := public._rt_try('SELECT public.qn_app_logs_purge(30, 365, 10)');
  PERFORM public._rt_ok(t LIKE 'err:%BATCH_OUT_OF_RANGE%', '1c lô xoá ngoài khoảng bị chặn');

  -- 2. App (anon / authenticated) không gọi được
  PERFORM public._rt_ok(NOT has_function_privilege('anon', 'public.qn_app_logs_purge(integer,integer,integer)', 'execute'), '2 anon không gọi được hàm dọn');
  PERFORM public._rt_ok(NOT has_function_privilege('authenticated', 'public.qn_app_logs_purge(integer,integer,integer)', 'execute'), '2b authenticated không gọi được hàm dọn');

  -- 3. Chạy dọn (batch nhỏ để thử vòng lặp nhiều lô)
  SELECT * INTO r FROM public.qn_app_logs_purge(30, 365, 100);
  RAISE NOTICE 'Đã dọn: kỹ thuật %, nghiệp vụ %', r.tech_deleted, r.audit_deleted;

  SELECT array_agg(message ORDER BY message) INTO keep FROM public.app_logs WHERE store_id = S;
  RAISE NOTICE 'Còn lại: %', keep;
  PERFORM public._rt_ok(NOT 'tech_old'    = ANY(keep), '3 log máy in > 30 ngày bị dọn');
  PERFORM public._rt_ok(NOT 'null_old'    = ANY(keep), '3b log không tag > 30 ngày bị dọn');
  PERFORM public._rt_ok(NOT 'kitchen_old' = ANY(keep), '3c log bếp > 30 ngày bị dọn');
  PERFORM public._rt_ok('tech_new' = ANY(keep), '3d log máy in 10 ngày còn giữ');
  PERFORM public._rt_ok(keep @> ARRAY['finance_40','finance_case','payroll_40','kho_40','settings_40','staff_40','inventory_40'],
    '3e Thu Chi / Lương / Kho / Cài đặt / Nhân viên 40 ngày còn giữ (v1 sẽ xoá nhầm)');
  PERFORM public._rt_ok('checkout_200' = ANY(keep), '3f log thanh toán 200 ngày còn giữ');
  PERFORM public._rt_ok(NOT 'action_400' = ANY(keep) AND NOT 'finance_400' = ANY(keep), '3g log nghiệp vụ > 365 ngày bị dọn');
  PERFORM public._rt_ok('no_date' = ANY(keep), '3h log thiếu ngày không bị đụng');

  RAISE NOTICE '>>> DỌN LOG v2: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
