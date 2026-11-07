-- ============================================================================
-- TEST: mật khẩu tạm bắt đổi + hết hạn 24 giờ (20261103_mat_khau_tam_bat_doi.sql). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._mk_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._mk_admin(p_user uuid)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin',
    'iat', now_s, 'exp', now_s + 3600)::text, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._mk_ok(boolean, text), public._mk_admin(uuid) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); U uuid := gen_random_uuid();
  ph text := '09' || lpad((random() * 99999999)::int::text, 8, '0');
  r jsonb; tmp text; ok_checks jsonb := '{"callback": true, "store_info": true, "secret": true}';
BEGIN
  RAISE NOTICE '>>> MAT KHAU TAM: BẮT ĐẦU <<<';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_mk_' || substr(A::text, 1, 6), '$2a$x', 'QT Mật khẩu', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
  VALUES (U, ph, crypt('matkhaucu123', gen_salt('bf', 4)), 'Chủ MK');

  -- 1. quản trị cấp mật khẩu tạm → hạn 24 giờ
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._mk_admin(A);
  r := public.admin_account_reset_password_v1(U, 'chủ quán gọi hotline quên mật khẩu', ok_checks, NULL);
  EXECUTE 'RESET ROLE';
  tmp := r->>'temp_password';
  PERFORM public._mk_ok((r->>'ok')::boolean AND length(tmp) = 10 AND r ? 'expires_at', '1 cấp mật khẩu tạm, trả hạn dùng');
  PERFORM public._mk_ok((SELECT temp_password_expires_at BETWEEN now() + interval '23 hours 59 minutes' AND now() + interval '24 hours 1 minute'
                           FROM public.user_accounts WHERE id = U), '2 hạn = 24 giờ');

  -- 3. đăng nhập bằng mật khẩu tạm (vai anon như app) → không cấp phiên, bắt đổi
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.verify_user_login_v4(ph, tmp, NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok((r->>'success')::boolean = false AND r->>'error_code' = 'MUST_CHANGE_PASSWORD' AND (r->>'status')::int = 403
                        AND NOT r ? 'user_id' AND NOT r ? 'stores', '3 mật khẩu tạm đúng → MUST_CHANGE_PASSWORD, không trả user_id / quán');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.verify_user_login_v4(ph, 'matkhaucu123', NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'INVALID_CREDENTIALS', '4 mật khẩu cũ hết dùng');

  -- 5. đổi mật khẩu tạm: các trường hợp từ chối
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, 'SAIMATKHAU', 'matkhaumoi123');
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'INVALID_CREDENTIALS', '5 mật khẩu tạm sai → từ chối');
  PERFORM public._mk_ok((SELECT count(*) FROM public.pos_auth_attempts_v4
                          WHERE phone_hash = digest(convert_to(public.normalize_phone_digits_v4(ph), 'utf8'), 'sha256')
                            AND is_success = false) = 2, '6 lần sai được đếm chung bộ đếm đăng nhập (4 + 5)');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, tmp, 'ngan');
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'INVALID_PASSWORD_LENGTH', '7 mật khẩu mới < 8 ký tự → từ chối');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, tmp, repeat('a', 73));
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'INVALID_PASSWORD_LENGTH', '7b mật khẩu mới > 72 ký tự → từ chối');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, tmp, tmp);
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'SAME_AS_TEMP', '8 mật khẩu mới trùng mật khẩu tạm → từ chối');

  -- 9. hết hạn
  UPDATE public.user_accounts SET temp_password_expires_at = now() - interval '1 minute' WHERE id = U;
  PERFORM public._mk_ok((SELECT temp_password_expires_at IS NOT NULL FROM public.user_accounts WHERE id = U), '9a chỉ đổi hạn → cờ giữ nguyên');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.verify_user_login_v4(ph, tmp, NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'TEMP_PASSWORD_EXPIRED', '9 quá 24 giờ → đăng nhập báo hết hạn');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, tmp, 'matkhaumoi123');
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'TEMP_PASSWORD_EXPIRED', '10 quá 24 giờ → không đổi được');
  UPDATE public.user_accounts SET temp_password_expires_at = now() + interval '1 hour' WHERE id = U;

  -- 11. đổi thành công
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, tmp, 'matkhaumoi123');
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok((r->>'success')::boolean, '11 đổi mật khẩu tạm thành công');
  PERFORM public._mk_ok((SELECT temp_password_expires_at IS NULL FROM public.user_accounts WHERE id = U), '12 cờ mật khẩu tạm đã xoá');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.verify_user_login_v4(ph, 'matkhaumoi123', NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok((r->>'success')::boolean AND (r->>'user_id')::uuid = U, '13 đăng nhập bằng mật khẩu mới → được');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.verify_user_login_v4(ph, tmp, NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'INVALID_CREDENTIALS', '14 mật khẩu tạm hết dùng');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, 'matkhaumoi123', 'matkhaukhac123');
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'NOT_TEMP_PASSWORD', '15 không phải mật khẩu tạm → không dùng đường này đổi được');

  -- 16. mật khẩu đổi bằng đường khác (chủ quán đặt cho nhân viên, tự đổi) → cờ tự xoá
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._mk_admin(A);
  tmp := public.admin_account_reset_password_v1(U, 'cấp lại lần nữa để thử', ok_checks, NULL)->>'temp_password';
  EXECUTE 'RESET ROLE';
  UPDATE public.user_accounts SET password_hash = crypt('chuquandat123', gen_salt('bf', 4)) WHERE id = U;
  PERFORM public._mk_ok((SELECT temp_password_expires_at IS NULL FROM public.user_accounts WHERE id = U), '16 đổi mật khẩu đường khác → cờ tự xoá');

  -- 17. dò mật khẩu tạm: 5 lần sai → khoá 5 phút (cả đăng nhập lẫn đổi mật khẩu tạm)
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._mk_admin(A);
  tmp := public.admin_account_reset_password_v1(U, 'cấp lại lần ba để thử', ok_checks, NULL)->>'temp_password';
  EXECUTE 'RESET ROLE';
  FOR i IN 1..5 LOOP
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM public.change_temp_password_v1(ph, 'DOMATKHAU' || i, 'matkhaumoi123');
    EXECUTE 'RESET ROLE';
  END LOOP;
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.change_temp_password_v1(ph, tmp, 'matkhaumoi123');
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'RATE_LIMIT_EXCEEDED', '17 dò 5 lần → đổi mật khẩu tạm bị khoá 5 phút');
  EXECUTE 'SET LOCAL ROLE anon';
  r := public.verify_user_login_v4(ph, tmp, NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._mk_ok(r->>'error_code' = 'RATE_LIMIT_EXCEEDED', '18 … và đăng nhập cũng bị khoá (chung bộ đếm)');

  -- 19. quyền
  PERFORM public._mk_ok(NOT has_column_privilege('anon', 'public.user_accounts', 'temp_password_expires_at', 'SELECT')
    AND NOT has_column_privilege('authenticated', 'public.user_accounts', 'temp_password_expires_at', 'SELECT')
    AND NOT has_column_privilege('authenticated', 'public.user_accounts', 'temp_password_expires_at', 'UPDATE'),
    '19 app không đọc / sửa được cột hạn mật khẩu tạm');
  PERFORM public._mk_ok(NOT has_function_privilege('anon', 'public.admin_account_reset_password_v1(uuid,text,jsonb,uuid)', 'execute')
    AND NOT has_function_privilege('authenticated', 'public.admin_account_reset_password_v1(uuid,text,jsonb,uuid)', 'execute'),
    '20 chỉ vé quản trị cấp được mật khẩu tạm');

  RAISE NOTICE '>>> MAT KHAU TAM: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
