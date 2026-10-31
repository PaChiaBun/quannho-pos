-- ============================================================================
-- TEST: Củng cố P0 v2 (20261022_cung_co_p0_v2.sql)
-- Chạy theo ĐÚNG cách app gọi trên production: vai anon + header x-store-id / x-user-id
-- (app không đăng nhập Supabase). CHỈ CHẠY TRÊN DB đã áp migration. Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

-- Giả lập app: anon, không JWT, danh tính qua header.
CREATE OR REPLACE FUNCTION public._v2_app(p_uid uuid, p_store uuid)
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

CREATE OR REPLACE FUNCTION public._v2_admin()
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE 'RESET ROLE';
  PERFORM set_config('request.headers', '', true);
END
$f$;

CREATE OR REPLACE FUNCTION public._v2_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._v2_try(p_sql text)
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
  M  uuid := gen_random_uuid();   -- quản lý đang làm
  MX uuid := gen_random_uuid();   -- quản lý đã nghỉ (đã gỡ khỏi store_members, còn hồ sơ staff_members)
  W  uuid := gen_random_uuid();   -- phục vụ
  B  uuid := gen_random_uuid();   -- chủ quán khác
  S  uuid := gen_random_uuid();
  S2 uuid := gen_random_uuid();
  Z  uuid := gen_random_uuid();
  T1 uuid := gen_random_uuid();
  T2 uuid := gen_random_uuid();
  T3 uuid := gen_random_uuid();
  PC uuid := gen_random_uuid();   -- phiên đã thanh toán
  PX uuid := gen_random_uuid();   -- phiên đã huỷ
  PO uuid := gen_random_uuid();   -- phiên đang mở, rỗng
  P  uuid := gen_random_uuid();   -- kỳ lương
  RW uuid := gen_random_uuid();   -- phiếu lương của W
  RM uuid := gen_random_uuid();   -- phiếu lương của M
  LK uuid := gen_random_uuid();   -- log kho
  LP uuid := gen_random_uuid();   -- log máy in
  t  text;
  n  int;
BEGIN
  RAISE NOTICE '>>> CỦNG CỐ P0 v2: BẮT ĐẦU <<<';
  PERFORM public._v2_admin();
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (M,  '+84' || (600000000 + (random()*99999999)::int), 'x', 'Quan ly M'),
    (MX, '+84' || (500000000 + (random()*99999999)::int), 'x', 'Quan ly nghi'),
    (W,  '+84' || (800000000 + (random()*99999999)::int), 'x', 'Phuc vu W'),
    (B,  '+84' || (700000000 + (random()*99999999)::int), 'x', 'Chu B');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES
    (S,  'T' || substr(S::text, 1, 7),  'Quan v2', A),
    (S2, 'T' || substr(S2::text, 1, 7), 'Quan khac v2', B);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (M, S, 'manager', false), (W, S, 'waiter', false), (B, S2, 'owner', true);
  INSERT INTO public.staff_members (id, store_id, name, role) VALUES (MX, S, 'Quan ly nghi', 'manager');
  INSERT INTO public.ban_zones (id, store_id, name) VALUES (Z, S, 'Khu v2');
  INSERT INTO public.ban_dining_tables (id, store_id, zone_id, name) VALUES
    (T1::text, S, Z, 'Ban 1'), (T2::text, S, Z, 'Ban 2'), (T3::text, S, Z, 'Ban 3');
  INSERT INTO public.ban_sessions (id, store_id, table_id, status) VALUES
    (PC, S, T1, 'closed'), (PX, S, T2, 'cancelled'), (PO, S, T3, 'open');
  INSERT INTO public.payroll_periods (id, store_id, name, from_date, to_date, status)
    VALUES (P, S, 'Ky v2', '2026-10-01', '2026-10-31', 'pending_review');
  INSERT INTO public.payroll_records (id, store_id, period_id, user_id, staff_name, net_pay) VALUES
    (RW, S, P, W, 'W', 5000000), (RM, S, P, M, 'M', 7000000);
  INSERT INTO public.app_logs (id, store_id, level, tag, message, created_at) VALUES
    (LK, S, 'INFO', 'kho', 'Sửa tồn kho', now()),
    (LP, S, 'ERROR', 'printer', 'Máy in lỗi', now());

  -- V0: danh tính qua header hoạt động (app thấy dữ liệu quán mình)
  PERFORM public._v2_app(A, S);
  SELECT count(*) INTO n FROM public.ban_sessions WHERE id IN (PC, PX, PO);
  PERFORM public._v2_ok(n = 3, 'V0 app (anon + header) thấy 3 phiên thử');

  -- V1: app không xoá được phiên đã thanh toán / đã huỷ / đang mở rỗng (kể cả chủ quán)
  t := public._v2_try(format($q$DELETE FROM public.ban_sessions WHERE id = %L$q$, PC));
  PERFORM public._v2_ok(t = 'err:42501', 'V1 không xoá phiên đã thanh toán (' || t || ')');
  t := public._v2_try(format($q$DELETE FROM public.ban_sessions WHERE id = %L$q$, PX));
  PERFORM public._v2_ok(t = 'err:42501', 'V1b không xoá phiên đã huỷ (' || t || ')');
  t := public._v2_try(format($q$DELETE FROM public.ban_sessions WHERE id = %L$q$, PO));
  PERFORM public._v2_ok(t = 'err:42501', 'V1c không xoá phiên đang mở (' || t || ')');
  -- V1d: huỷ bàn vẫn chạy như cũ (không ảnh hưởng)
  t := public._v2_try(format($q$UPDATE public.ban_sessions SET status = 'cancelled' WHERE id = %L$q$, PO));
  PERFORM public._v2_ok(t = 'ok:1', 'V1d huỷ bàn vẫn chạy (' || t || ')');

  -- V2: phục vụ (header thật của mình) không duyệt kỳ được — đi tới đúng chốt máy chủ
  PERFORM public._v2_app(W, S);
  t := public._v2_try(format($q$UPDATE public.payroll_periods SET status = 'approved' WHERE id = %L$q$, P));
  PERFORM public._v2_ok(t = 'err:42501', 'V2 phục vụ không duyệt được kỳ (' || t || ')');

  -- V3: chủ quán duyệt; quản lý đang làm trả lương được
  PERFORM public._v2_app(A, S);
  t := public._v2_try(format($q$UPDATE public.payroll_periods SET status = 'approved', locked_at = now() WHERE id = %L$q$, P));
  PERFORM public._v2_ok(t = 'ok:1', 'V3 chủ quán duyệt kỳ (' || t || ')');
  PERFORM public._v2_app(M, S);
  t := public._v2_try(format($q$UPDATE public.payroll_records SET payment_status = 'pending_staff_confirm', payment_method = 'cash', paid_at = now() WHERE id = %L$q$, RW));
  PERFORM public._v2_ok(t = 'ok:1', 'V3b quản lý đang làm trả lương (' || t || ')');

  -- V4: quản lý đã nghỉ (chỉ còn hồ sơ staff_members) không trả lương được
  PERFORM public._v2_app(MX, S);
  PERFORM public._v2_ok(NOT (SELECT a.is_manager FROM public.payroll_actor_v1(S) a),
    'V4 quản lý đã nghỉ không còn quyền Quản lý ở chốt lương');

  -- V5: nhân viên W (header của mình) xác nhận đã nhận lương
  PERFORM public._v2_app(W, S);
  t := public._v2_try(format($q$UPDATE public.payroll_records SET payment_status = 'paid' WHERE id = %L$q$, RW));
  PERFORM public._v2_ok(t = 'ok:1', 'V5 nhân viên tự xác nhận đã nhận (' || t || ')');

  -- V6: app (anon) đọc được vết xoá thu chi của quán mình, quán khác thì không
  PERFORM public._v2_admin();
  INSERT INTO public.finance_record_deletions (store_id, record_id, record, reason, actor_user_id, actor_role)
    VALUES (S, gen_random_uuid(), '{}', 'thử', A, 'owner');
  PERFORM public._v2_app(A, S);
  SELECT count(*) INTO n FROM public.finance_record_deletions WHERE store_id = S;
  PERFORM public._v2_ok(n = 1, 'V6 app đọc được vết xoá quán mình');
  PERFORM public._v2_app(B, S2);
  SELECT count(*) INTO n FROM public.finance_record_deletions WHERE store_id = S;
  PERFORM public._v2_ok(n = 0, 'V6b quán khác không thấy');

  -- V7: log kho được bảo vệ, log máy in vẫn xoá được
  PERFORM public._v2_app(A, S);
  t := public._v2_try(format($q$DELETE FROM public.app_logs WHERE id = %L$q$, LK));
  PERFORM public._v2_ok(t = 'err:42501', 'V7 không xoá log kho (' || t || ')');
  t := public._v2_try(format($q$DELETE FROM public.app_logs WHERE id = %L$q$, LP));
  PERFORM public._v2_ok(t = 'ok:1', 'V7b vẫn xoá log máy in (' || t || ')');

  -- V8: quản trị không bị chặn
  PERFORM public._v2_admin();
  t := public._v2_try(format($q$DELETE FROM public.ban_sessions WHERE id = %L$q$, PC));
  PERFORM public._v2_ok(t = 'ok:1', 'V8 quản trị vẫn xoá được phiên (' || t || ')');

  -- GHI NHẬN (không phải lỗi của migration này): giả header chủ quán là duyệt được.
  PERFORM public._v2_admin();
  UPDATE public.payroll_periods SET status = 'pending_review' WHERE id = P;
  PERFORM public._v2_app(A, S);  -- bất kỳ ai gửi x-user-id = id chủ quán
  t := public._v2_try(format($q$UPDATE public.payroll_periods SET name = name WHERE id = %L$q$, P));
  RAISE NOTICE 'ℹ GHI NHẬN: danh tính lấy từ header x-user-id — ai biết id chủ quán có thể giả danh. Cần đăng nhập thật (JWT).';

  RAISE NOTICE '>>> CỦNG CỐ P0 v2: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
