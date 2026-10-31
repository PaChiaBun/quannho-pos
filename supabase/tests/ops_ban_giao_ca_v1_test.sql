-- ============================================================================
-- TEST: Bàn giao ca v1 (20261023_ops_ban_giao_ca_v1.sql) — chạy kiểu app thật (anon + header).
-- CHỈ CHẠY TRÊN DB đã áp migration. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._hg_app(p_uid uuid, p_store uuid)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.jwt.claim.sub', '', true);
  PERFORM set_config('request.jwt.claims', '', true);
  PERFORM set_config('request.headers',
    json_build_object('x-store-id', p_store::text, 'x-user-id', p_uid::text)::text, true);
END
$f$;

CREATE OR REPLACE FUNCTION public._hg_admin()
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.headers', '', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._hg_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._hg_try(p_sql text)
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

CREATE OR REPLACE FUNCTION public._hg_count(p_store uuid)
RETURNS integer LANGUAGE sql AS $f$
  SELECT count(*)::int FROM public.ops_shift_handovers WHERE store_id = p_store
$f$;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- chủ quán S
  W  uuid := gen_random_uuid();   -- phục vụ quán S
  X  uuid := gen_random_uuid();   -- chủ quán S2 (quán khác)
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  H  uuid := gen_random_uuid();
  t  text;
  r  record;
BEGIN
  RAISE NOTICE '>>> BÀN GIAO CA v1: BẮT ĐẦU <<<';
  PERFORM public._hg_admin();
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W'),
    (X, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu X');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S,  'H' || substr(S::text, 1, 7),  'Quan HG',  A),
    (S2, 'H' || substr(S2::text, 1, 7), 'Quan HG2', X);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (W, S, 'waiter', false), (X, S2, 'owner', true);

  -- 1. Nhân viên lưu được bàn giao (đúng payload app gửi); người tạo bị đóng dấu theo người gọi
  PERFORM public._hg_app(W, S);
  t := public._hg_try(format($q$INSERT INTO public.ops_shift_handovers
        (id, store_id, from_shift_id, handover_date, created_by, created_by_name, issues, notes, pending_tasks, created_at)
        VALUES (%L, %L, NULL, '2026-10-23', %L, 'Chủ quán', 'May pha hong', 'Ban 5 dat 3pm', '["a","b"]'::jsonb,
                now() - interval '3 days')$q$, H, S, A));
  PERFORM public._hg_ok(t = 'ok:1', '1 nhân viên lưu được bàn giao (' || t || ')');
  PERFORM public._hg_admin();
  SELECT created_by, created_by_name, created_at, pending_tasks INTO r FROM public.ops_shift_handovers WHERE id = H;
  PERFORM public._hg_ok(r.created_by = W::text, '1b người tạo là người gọi, không khai thay chủ quán được');
  PERFORM public._hg_ok(r.created_by_name = 'Phuc vu W', '1d tên hiển thị lấy từ tài khoản, không giả "Chủ quán" được (' || r.created_by_name || ')');
  PERFORM public._hg_ok(r.created_at > now() - interval '1 minute', '1e giờ tạo theo máy chủ, không lùi ngày được');
  PERFORM public._hg_ok(jsonb_array_length(r.pending_tasks) = 2, '1c lưu đủ danh sách việc chưa xong');

  -- 2. Cùng quán đọc được
  PERFORM public._hg_app(A, S);
  PERFORM public._hg_ok(public._hg_count(S) = 1, '2 chủ quán đọc được bàn giao của quán mình');

  -- 3. Quán khác không đọc / không ghi được
  PERFORM public._hg_app(X, S2);
  PERFORM public._hg_ok(public._hg_count(S) = 0, '3 quán khác không thấy bàn giao');
  t := public._hg_try(format($q$INSERT INTO public.ops_shift_handovers (store_id, created_by_name) VALUES (%L, 'gia')$q$, S));
  PERFORM public._hg_ok(t = 'err:42501', '3b quán khác không ghi vào quán S (' || t || ')');

  -- 4. Người ngoài quán khai header quán S
  PERFORM public._hg_app(X, S);
  PERFORM public._hg_ok(public._hg_count(S) = 0, '4a người ngoài khai header quán S không đọc được');
  t := public._hg_try(format($q$INSERT INTO public.ops_shift_handovers (store_id, created_by_name) VALUES (%L, 'gia')$q$, S));
  PERFORM public._hg_ok(t = 'err:42501', '4 người ngoài quán không ghi được (' || t || ')');

  -- 5. Biên bản không sửa / xoá được từ app
  PERFORM public._hg_app(A, S);
  t := public._hg_try(format($q$UPDATE public.ops_shift_handovers SET notes = 'sua' WHERE id = %L$q$, H));
  PERFORM public._hg_ok(t = 'err:42501', '5 không sửa được bàn giao (' || t || ')');
  t := public._hg_try(format($q$DELETE FROM public.ops_shift_handovers WHERE id = %L$q$, H));
  PERFORM public._hg_ok(t = 'err:42501', '5b không xoá được bàn giao (' || t || ')');

  -- 4c. Không header nào
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.headers', '', true);
  PERFORM public._hg_ok(public._hg_count(S) = 0, '4c không đăng nhập không đọc được');
  t := public._hg_try(format($q$INSERT INTO public.ops_shift_handovers (store_id) VALUES (%L)$q$, S));
  PERFORM public._hg_ok(t = 'err:42501', '4d không đăng nhập không ghi được (' || t || ')');

  -- 6. Giới hạn độ dài
  PERFORM public._hg_app(A, S);
  t := public._hg_try(format($q$INSERT INTO public.ops_shift_handovers (store_id, notes) VALUES (%L, repeat('x', 2001))$q$, S));
  PERFORM public._hg_ok(t = 'err:23514', '6 ghi chú quá 2000 ký tự bị chặn (' || t || ')');

  PERFORM public._hg_admin();
  RAISE NOTICE '>>> BÀN GIAO CA v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
