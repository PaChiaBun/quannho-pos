-- ============================================================================
-- TEST: Trang quản trị v2 — tài khoản quản trị riêng (20261026_trang_quan_tri_v2_tai_khoan.sql). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._q2_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._q2_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;
CREATE OR REPLACE FUNCTION public._q2_claims(p_sub uuid, p_role text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', p_sub, 'role', p_role, 'token_use', 'admin',
    'iat', now_s, 'exp', now_s + 3600)::text, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._q2_ok(boolean, text), public._q2_try(text), public._q2_claims(uuid, text)
  TO authenticated, anon, qn_admin, service_role;

DO $test$
DECLARE r jsonb; t text; aid uuid; U uuid := gen_random_uuid();
BEGIN
  RAISE NOTICE '>>> TRANG QUAN TRI v2: BẮT ĐẦU <<<';
  PERFORM public._q2_ok(to_regclass('public.platform_admins') IS NULL, '1 bảng quản trị bằng tài khoản quán (GIANG) đã gỡ khỏi việc kiểm quyền');

  r := public.admin_account_set_password_v1('pachiabun', 'ngan', 'Chủ Quán');
  PERFORM public._q2_ok(r->>'error' = 'PASSWORD_TOO_SHORT', '2 mật khẩu dưới 10 ký tự bị từ chối');
  r := public.admin_account_set_password_v1('Bad Name!', 'MatKhauDai123', NULL);
  PERFORM public._q2_ok(r->>'error' = 'BAD_USERNAME', '3 tên đăng nhập lạ bị từ chối');
  r := public.admin_account_set_password_v1('PachiaBun', 'MatKhauDai123', 'Chủ Quán');
  PERFORM public._q2_ok((r->>'ok')::boolean AND r->>'username' = 'pachiabun', '4 đặt mật khẩu (tên viết thường)');
  PERFORM public._q2_ok((SELECT password_hash LIKE '$2%' AND password_hash NOT LIKE '%MatKhauDai%' FROM public.platform_admin_accounts
                          WHERE username = 'pachiabun'), '5 mật khẩu lưu dạng băm bcrypt, không lưu chữ thật');

  EXECUTE 'SET LOCAL ROLE service_role';
  r := public.admin_account_login_v1('pachiabun', 'MatKhauDai123');
  PERFORM public._q2_ok((r->>'ok')::boolean AND r->>'name' = 'Chủ Quán', '6 đăng nhập đúng');
  aid := (r->>'id')::uuid;
  PERFORM public._q2_ok(NOT (public.admin_account_login_v1('pachiabun', 'sai-mat-khau')->>'ok')::boolean, '7 sai mật khẩu');
  PERFORM public._q2_ok(NOT (public.admin_account_login_v1('khongco', 'MatKhauDai123')->>'ok')::boolean, '8 tên không có');
  PERFORM public._q2_ok(public.admin_account_login_v1('khongco', 'x') = public.admin_account_login_v1('pachiabun', 'x'),
                        '9 sai tên và sai mật khẩu trả cùng một kết quả');
  PERFORM public._q2_ok(public.admin_is_platform_admin_v1(aid) AND NOT public.admin_is_platform_admin_v1(U), '10 hỏi quản trị theo id tài khoản quản trị');
  t := public._q2_try($q$SELECT public.admin_account_set_password_v1('x1x', 'MatKhauDai123', NULL)$q$);
  PERFORM public._q2_ok(t LIKE 'err:%', '11 service_role (API) KHÔNG đặt được mật khẩu');
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE authenticated';
  t := public._q2_try($q$SELECT public.admin_account_login_v1('pachiabun', 'MatKhauDai123')$q$);
  PERFORM public._q2_ok(t LIKE 'err:%', '12 người đăng nhập thường không gọi được hàm đăng nhập quản trị');
  t := public._q2_try('SELECT count(*) FROM public.platform_admin_accounts');
  PERFORM public._q2_ok(t LIKE 'err:%', '13 không đọc được bảng tài khoản quản trị');
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._q2_claims(aid, 'qn_admin');
  r := public.admin_whoami_v1();
  PERFORM public._q2_ok((r->>'ok')::boolean AND r->>'name' = 'Chủ Quán', '14 vé quản trị của tài khoản riêng → vào được');
  t := public._q2_try('SELECT count(*) FROM public.platform_admin_accounts');
  PERFORM public._q2_ok(t LIKE 'err:%', '15 vé quản trị cũng không đọc thẳng được bảng tài khoản');
  PERFORM public._q2_claims(U, 'qn_admin');
  PERFORM public._q2_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '16 vé quản trị mang id tài khoản quán (vd GIANG) → từ chối');
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', aid, 'role', 'qn_admin', 'token_use', 'admin',
    'iat', extract(epoch FROM now())::bigint - 120, 'exp', extract(epoch FROM now())::bigint + 3600)::text, true);
  PERFORM public._q2_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '16b vé cấp TRƯỚC lần đổi mật khẩu → hết hiệu lực');
  EXECUTE 'RESET ROLE';

  UPDATE public.platform_admin_accounts SET disabled = true WHERE id = aid;
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._q2_claims(aid, 'qn_admin');
  PERFORM public._q2_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '17 tài khoản bị khoá → vé cũ hết dùng được');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE service_role';
  PERFORM public._q2_ok(NOT (public.admin_account_login_v1('pachiabun', 'MatKhauDai123')->>'ok')::boolean, '18 tài khoản bị khoá không đăng nhập được');
  EXECUTE 'RESET ROLE';

  RAISE NOTICE '>>> TRANG QUAN TRI v2: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
