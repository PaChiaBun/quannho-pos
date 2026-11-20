-- ============================================================================
-- TEST: Khoá duyệt & trả lương (20261022_khoa_duyet_tra_luong_v1.sql)
-- CHỈ CHẠY TRÊN DB STAGING/DISPOSABLE đã áp migration. Một transaction, kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._tl_as(p_role text, p_uid uuid DEFAULT NULL, p_store uuid DEFAULT NULL)
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

CREATE OR REPLACE FUNCTION public._tl_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._tl_try(p_sql text)
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
  W  uuid := gen_random_uuid();   -- nhân viên (có phiếu lương)
  K  uuid := gen_random_uuid();   -- kế toán (vai trò tuỳ chỉnh, có module lương)
  S  uuid := gen_random_uuid();
  P  uuid := gen_random_uuid();   -- kỳ lương
  RW uuid := gen_random_uuid();   -- phiếu của W
  RK uuid := gen_random_uuid();   -- phiếu của K
  t  text;
BEGIN
  RAISE NOTICE '>>> KHOÁ DUYỆT & TRẢ LƯƠNG v1: BẮT ĐẦU <<<';
  PERFORM public._tl_as('admin');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu A'),
    (M, '+84' || (600000000 + (random()*99999999)::int), 'x', 'Quan ly M'),
    (W, '+84' || (800000000 + (random()*99999999)::int), 'x', 'Nhan vien W'),
    (K, '+84' || (700000000 + (random()*99999999)::int), 'x', 'Ke toan K');
  INSERT INTO public.stores (id, store_code, name, owner_user_id) VALUES (S, 'T' || substr(S::text, 1, 7), 'Quan luong', A);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (A, S, 'owner', true), (M, S, 'manager', false), (W, S, 'waiter', false), (K, S, 'Kế Toán', false);

  -- T1: kế toán (có module lương) tạo kỳ nháp + phiếu, tính lại được
  PERFORM public._tl_as('authenticated', K, S);
  t := public._tl_try(format($q$INSERT INTO public.payroll_periods (id, store_id, name, from_date, to_date, status) VALUES (%L, %L, 'Kỳ 10', '2026-10-01', '2026-10-31', 'draft')$q$, P, S));
  PERFORM public._tl_ok(t = 'ok:1', 'T1 tạo kỳ nháp (' || t || ')');
  t := public._tl_try(format($q$INSERT INTO public.payroll_records (id, store_id, period_id, user_id, staff_name, net_pay) VALUES (%L, %L, %L, %L, 'W', 5000000), (%L, %L, %L, %L, 'K', 6000000)$q$, RW, S, P, W, RK, S, P, K));
  PERFORM public._tl_ok(t = 'ok:2', 'T1b thêm phiếu lương khi kỳ nháp (' || t || ')');
  t := public._tl_try(format($q$UPDATE public.payroll_records SET net_pay = 5100000 WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'ok:1', 'T1c sửa số tiền khi kỳ nháp (' || t || ')');

  -- T2: trả lương khi kỳ chưa duyệt bị chặn (kể cả chủ quán)
  PERFORM public._tl_as('authenticated', A, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'pending_staff_confirm', payment_method = 'cash', paid_at = now() WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'err:42501', 'T2 chưa duyệt thì chưa trả lương (' || t || ')');

  -- T3: gửi duyệt — kế toán làm được
  PERFORM public._tl_as('authenticated', K, S);
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'pending_review' WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'ok:1', 'T3 gửi duyệt (' || t || ')');

  -- T4: kế toán / quản lý duyệt kỳ bị chặn
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'approved', locked_at = now() WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'err:42501', 'T4 kế toán không duyệt được kỳ (' || t || ')');
  PERFORM public._tl_as('authenticated', M, S);
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'approved', locked_at = now() WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'err:42501', 'T4b quản lý không duyệt được kỳ (' || t || ')');

  -- T5: chủ quán duyệt kỳ
  PERFORM public._tl_as('authenticated', A, S);
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'approved', locked_at = now() WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'ok:1', 'T5 chủ quán duyệt kỳ (' || t || ')');

  -- T6: kỳ đã duyệt — sửa tiền / thêm / xoá phiếu / sửa kỳ / xoá kỳ đều bị chặn (kể cả chủ quán)
  t := public._tl_try(format($q$UPDATE public.payroll_records SET net_pay = 9999999 WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'err:42501', 'T6 không sửa số tiền sau duyệt (' || t || ')');
  t := public._tl_try(format($q$INSERT INTO public.payroll_records (store_id, period_id, user_id, staff_name, net_pay) VALUES (%L, %L, %L, 'Ma', 1)$q$, S, P, M));
  PERFORM public._tl_ok(t = 'err:42501', 'T6b không thêm phiếu sau duyệt (' || t || ')');
  t := public._tl_try(format($q$DELETE FROM public.payroll_records WHERE id = %L$q$, RK));
  PERFORM public._tl_ok(t = 'err:42501', 'T6c không xoá phiếu sau duyệt (' || t || ')');
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET total_amount = 1 WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'err:42501', 'T6d không sửa kỳ sau duyệt (' || t || ')');
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'draft' WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'err:42501', 'T6e không mở lại kỳ đã duyệt (' || t || ')');
  t := public._tl_try(format($q$DELETE FROM public.payroll_periods WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'err:42501', 'T6f không xoá kỳ đã duyệt (' || t || ')');

  -- T7: kế toán / nhân viên trả lương bị chặn
  PERFORM public._tl_as('authenticated', K, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'pending_staff_confirm', payment_method = 'cash', paid_at = now() WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'err:42501', 'T7 kế toán không trả lương được (' || t || ')');
  PERFORM public._tl_as('authenticated', W, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'paid' WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'err:42501', 'T7b nhân viên không tự đánh dấu đã trả (' || t || ')');

  -- T8: quản lý trả lương cho W
  PERFORM public._tl_as('authenticated', M, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'pending_staff_confirm', payment_method = 'cash', paid_at = now() WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'ok:1', 'T8 quản lý trả lương (' || t || ')');

  -- T9: người khác xác nhận hộ bị chặn; đúng W xác nhận được
  PERFORM public._tl_as('authenticated', K, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'paid' WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'err:42501', 'T9 người khác không xác nhận hộ (' || t || ')');
  PERFORM public._tl_as('authenticated', M, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'paid' WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'err:42501', 'T9b quản lý không xác nhận hộ (' || t || ')');
  PERFORM public._tl_as('authenticated', W, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'paid' WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'ok:1', 'T9c nhân viên W xác nhận đã nhận (' || t || ')');

  -- T10: đã paid — quản lý không đổi lại được; chủ quán được (sửa nhầm)
  PERFORM public._tl_as('authenticated', M, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'pending' WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'err:42501', 'T10 quản lý không đảo trạng thái đã nhận (' || t || ')');
  PERFORM public._tl_as('authenticated', A, S);
  t := public._tl_try(format($q$UPDATE public.payroll_records SET payment_status = 'pending_staff_confirm' WHERE id = %L$q$, RW));
  PERFORM public._tl_ok(t = 'ok:1', 'T10b chủ quán sửa trạng thái được (' || t || ')');

  -- T11: chốt kỳ đã trả — quản lý không được, chủ quán được; sau đó vẫn khoá
  PERFORM public._tl_as('authenticated', M, S);
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'paid', paid_at = now() WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'err:42501', 'T11 quản lý không chốt đã trả kỳ (' || t || ')');
  PERFORM public._tl_as('authenticated', A, S);
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'paid', paid_at = now() WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'ok:1', 'T11b chủ quán chốt đã trả kỳ (' || t || ')');
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET name = 'Đổi tên' WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t = 'err:42501', 'T11c kỳ đã trả vẫn khoá (' || t || ')');

  -- T12: tạo kỳ đã duyệt sẵn — chỉ chủ quán
  PERFORM public._tl_as('authenticated', M, S);
  t := public._tl_try(format($q$INSERT INTO public.payroll_periods (store_id, name, from_date, to_date, status) VALUES (%L, 'Kỳ lậu', '2026-11-01', '2026-11-30', 'approved')$q$, S));
  PERFORM public._tl_ok(t = 'err:42501', 'T12 quản lý không tạo kỳ đã duyệt sẵn (' || t || ')');

  -- T13: anon không có danh tính → không duyệt được
  PERFORM public._tl_as('anon');
  t := public._tl_try(format($q$UPDATE public.payroll_periods SET status = 'approved' WHERE id = %L$q$, P));
  PERFORM public._tl_ok(t <> 'ok:1', 'T13 không danh tính không duyệt được (' || t || ')');

  -- T14: quản trị (máy chủ) không bị chặn
  PERFORM public._tl_as('admin');
  t := public._tl_try(format($q$UPDATE public.payroll_records SET note = 'quản trị' WHERE id = %L$q$, RK));
  PERFORM public._tl_ok(t = 'ok:1', 'T14 quản trị vẫn sửa được (' || t || ')');

  RAISE NOTICE '>>> KHOÁ DUYỆT & TRẢ LƯƠNG v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
