-- ============================================================================
-- TEST: Hỗ trợ H3 — chủ quán đặt mật khẩu nhân viên (20261030_ho_tro_h3_chu_quan_dat_mat_khau.sql). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._h3_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._h3_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;
CREATE OR REPLACE FUNCTION public._h3_claims(p_user uuid, p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'exp', now_s + 3600)::text
    WHEN 'anon' THEN '{"role":"anon"}'
    ELSE '' END, true);
  PERFORM set_config('request.headers', CASE WHEN p_kind = 'anon' THEN json_build_object('x-user-id', p_user)::text ELSE '{}' END, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._h3_ok(boolean, text), public._h3_try(text), public._h3_claims(uuid, text) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid();   -- quản trị
  O uuid := gen_random_uuid();   -- chủ quán S1, S2
  O2 uuid := gen_random_uuid();  -- chủ quán S3 (người khác)
  M uuid := gen_random_uuid();   -- quản lý S1
  N uuid := gen_random_uuid();   -- nhân viên chỉ làm S1 + S2 (đều của O)
  X uuid := gen_random_uuid();   -- nhân viên làm S1 và S3 (quán của O2)
  V uuid := gen_random_uuid();   -- nạn nhân: chưa thuộc quán nào, bị kẻ gian (chủ S4) thêm vào quán của kẻ gian
  K uuid := gen_random_uuid();   -- kẻ gian, chủ S4
  S4 uuid := gen_random_uuid();
  S1 uuid := gen_random_uuid(); S2 uuid := gen_random_uuid(); S3 uuid := gen_random_uuid();
  r jsonb; t text;
  ph text := '09' || lpad(((random() * 99999999)::int)::text, 8, '0');
BEGIN
  RAISE NOTICE '>>> HO TRO H3: BẮT ĐẦU <<<';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_h3_' || substr(A::text, 1, 6), '$2a$x', 'QT H3', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (O,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ O'),
    (O2, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ O2'),
    (M,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Quản lý M'),
    (N,  ph, extensions.crypt('MatKhauCu1', extensions.gen_salt('bf', 4)), 'Nhân viên N'),
    (X,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Nhân viên X'),
    (V,  '+84' || (900000000 + (random()*99999999)::int), extensions.crypt('MatKhauNanNhan1', extensions.gen_salt('bf', 4)), 'Nạn nhân V'),
    (K,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Kẻ gian K');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan) VALUES
    (S1, 'A' || substr(S1::text, 1, 7), 'Quán S1', O, 'trial', 'free'),
    (S2, 'B' || substr(S2::text, 1, 7), 'Quán S2', O, 'trial', 'free'),
    (S3, 'C' || substr(S3::text, 1, 7), 'Quán S3', O2, 'trial', 'free'),
    (S4, 'D' || substr(S4::text, 1, 7), 'Quán kẻ gian', K, 'trial', 'free');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (O, S1, 'owner', true), (O, S2, 'owner', true), (O2, S3, 'owner', true),
    (M, S1, 'manager', false), (N, S1, 'cashier', false), (N, S2, 'cashier', false),
    (X, S1, 'cashier', false), (X, S3, 'cashier', false),
    (K, S4, 'owner', true), (V, S4, 'cashier', false);   -- như admin_create_staff_member_v4 thêm SĐT nạn nhân
  INSERT INTO public.pos_refresh_tokens (family_id, user_id, store_id, token_hash, expires_at)
  VALUES (gen_random_uuid(), N, S1, md5(random()::text) || md5(random()::text), now() + interval '20 days');

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._h3_claims(M, 'pos');
  t := public._h3_try(format('UPDATE public.store_members SET is_owner = true WHERE store_id = %L AND user_id = %L', S1, M));
  PERFORM public._h3_ok(t = 'err:42501', '0a quản lý KHÔNG tự đặt cờ chủ quán cho mình (lỗ cũ)');
  t := public._h3_try(format('UPDATE public.store_members SET role = %L WHERE store_id = %L AND user_id = %L', 'owner', S1, M));
  PERFORM public._h3_ok(t = 'err:42501', '0b quản lý KHÔNG tự đổi vai trò thành owner');
  t := public._h3_try(format('INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (%L, %L, %L, true)', O2, S1, 'cashier'));
  PERFORM public._h3_ok(t = 'err:42501', '0c quản lý KHÔNG thêm người khác làm chủ quán');
  t := public._h3_try(format('UPDATE public.store_members SET role = %L WHERE store_id = %L AND user_id = %L', 'waiter', S1, N));
  PERFORM public._h3_ok(t = 'ok', '0d quản lý vẫn đổi vai trò thường cho nhân viên');
  t := public._h3_try(format('UPDATE public.store_members SET user_id = %L WHERE store_id = %L AND user_id = %L', M, S1, N));
  PERFORM public._h3_ok(t = 'err:42501', '0e không đổi được người của dòng thành viên');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, N, 'MatKhauMoi1')->>'error' = 'OWNER_ONLY', '1 quản lý KHÔNG đặt được mật khẩu nhân viên');
  PERFORM public._h3_claims(O, 'pos');
  t := public._h3_try(format('UPDATE public.store_members SET role = %L WHERE store_id = %L AND user_id = %L', 'cashier', S1, N));
  PERFORM public._h3_ok(t = 'ok', '0f chủ quán (đứng tên) vẫn sửa thành viên bình thường');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, O, 'MatKhauMoi1')->>'error' = 'SELF', '2 không tự đặt cho chính mình ở đây');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, O2, 'MatKhauMoi1')->>'error' = 'NOT_MEMBER', '3 người không thuộc quán');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, X, 'MatKhauMoi1')->>'error' = 'OTHER_STORES',
                        '4 nhân viên còn làm ở quán người khác → không đổi được (nhờ hỗ trợ)');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, N, 'ngan')->>'error' = 'BAD_PASSWORD', '5 mật khẩu dưới 8 ký tự');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, N, repeat('a', 73))->>'error' = 'BAD_PASSWORD', '6 mật khẩu quá 72 ký tự');
  r := public.store_staff_set_password_v1(S1, N, 'MatKhauMoi1');
  PERFORM public._h3_ok((r->>'ok')::boolean, '7 chủ quán đặt mật khẩu mới cho nhân viên chỉ làm ở các quán của mình');
  PERFORM public._h3_claims(O2, 'pos');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, N, 'HackHack1')->>'error' = 'OWNER_ONLY', '8 chủ quán khác không đổi được');
  PERFORM public._h3_claims(N, 'pos');
  PERFORM public._h3_ok(public.store_staff_set_password_v1(S1, M, 'HackHack1')->>'error' = 'OWNER_ONLY', '9 nhân viên không đổi được của người khác');
  t := public._h3_try('SELECT count(*) FROM public.support_actions');
  PERFORM public._h3_ok(t LIKE 'err:%', '10 không đọc thẳng nhật ký hỗ trợ');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._h3_claims(O, 'anon');
  t := public._h3_try(format('SELECT public.store_staff_set_password_v1(%L, %L, %L)', S1, N, 'AnonHack1'));
  PERFORM public._h3_ok(t LIKE 'err:%', '11 anon + header x-user-id của chủ quán → bị chặn');
  EXECUTE 'RESET ROLE';

  PERFORM public._h3_ok((SELECT public.verify_password_hash_v4(phone, 'MatKhauMoi1', password_hash)
                                AND NOT public.verify_password_hash_v4(phone, 'MatKhauCu1', password_hash)
                                AND password_hash LIKE '$2a$%' FROM public.user_accounts WHERE id = N),
                        '12 nhân viên đăng nhập bằng mật khẩu mới; mật khẩu cũ hết dùng; lưu bcrypt');
  PERFORM public._h3_ok((SELECT count(*) FROM public.pos_refresh_tokens WHERE user_id = N AND revoked_at IS NULL) = 0,
                        '13 thu hồi vé làm mới của nhân viên');
  PERFORM public._h3_ok((SELECT count(*) = 1 AND bool_and(actor_user = O AND admin_id IS NULL AND reason NOT LIKE '%MatKhauMoi1%')
                           FROM public.support_actions WHERE target_user = N AND action = 'owner_set_password'),
                        '14 nhật ký ghi chủ quán làm, không lưu mật khẩu');

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._h3_claims(A, 'admin');
  r := public.admin_account_detail_v1(N);
  PERFORM public._h3_ok(r->'account'->'support'->0->>'admin' = 'Chủ O (chủ quán)', '15 trang hỗ trợ hiện "Chủ O (chủ quán)" trong lịch sử');
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._h3_claims(K, 'pos');
  r := public.store_staff_set_password_v1(S4, V, 'KeGian12345');
  PERFORM public._h3_ok(r->>'error' = 'NOT_ACTIVE', '16 CHẶN CHIẾM TÀI KHOẢN: thêm SĐT người lạ vào quán mình rồi đặt mật khẩu → từ chối');
  EXECUTE 'RESET ROLE';
  PERFORM public._h3_ok((SELECT public.verify_password_hash_v4(phone, 'MatKhauNanNhan1', password_hash) FROM public.user_accounts WHERE id = V),
                        '17 mật khẩu của nạn nhân không đổi');

  RAISE NOTICE '>>> HO TRO H3: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
