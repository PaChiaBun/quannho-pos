-- ============================================================================
-- TEST: Đổi tên an toàn (20261031_doi_ten_an_toan.sql). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._dt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._dt_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;
CREATE OR REPLACE FUNCTION public._dt_claims(p_user uuid, p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'exp', now_s + 3600)::text
    WHEN 'anon' THEN '{"role":"anon"}'
    ELSE '' END, true);
  PERFORM set_config('request.headers', CASE WHEN p_kind = 'anon' THEN json_build_object('x-user-id', p_user)::text ELSE '{}' END, true);
END
$f$;
-- đọc tên trong staff_members bỏ qua RLS (bài test chạy dưới vai trò app)
CREATE OR REPLACE FUNCTION public._dt_sm(p uuid) RETURNS text LANGUAGE sql SECURITY DEFINER AS $f$
  SELECT name FROM public.staff_members WHERE id = p
$f$;
GRANT EXECUTE ON FUNCTION public._dt_ok(boolean, text), public._dt_try(text), public._dt_claims(uuid, text), public._dt_sm(uuid) TO authenticated, anon;

DO $test$
DECLARE
  O uuid := gen_random_uuid(); O2 uuid := gen_random_uuid(); M uuid := gen_random_uuid();
  N uuid := gen_random_uuid(); X uuid := gen_random_uuid(); V uuid := gen_random_uuid();
  S1 uuid := gen_random_uuid(); S3 uuid := gen_random_uuid();
  r jsonb; t text; i int;
BEGIN
  RAISE NOTICE '>>> DOI TEN AN TOAN: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (O,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ O'),
    (O2, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ O2'),
    (M,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Quản lý M'),
    (N,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Nhân viên N'),
    (X,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Nhân viên X'),
    (V,  '+84' || (900000000 + (random()*99999999)::int), 'x', 'Người mới V');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan) VALUES
    (S1, 'T' || substr(S1::text, 1, 7), 'Quán T1', O, 'trial', 'free'),
    (S3, 'U' || substr(S3::text, 1, 7), 'Quán U3', O2, 'trial', 'free');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES
    (O, S1, 'owner', true), (O2, S3, 'owner', true), (M, S1, 'manager', false), (N, S1, 'cashier', false),
    (X, S1, 'cashier', false), (X, S3, 'cashier', false), (V, S1, 'cashier', false);
  INSERT INTO public.pos_refresh_tokens (family_id, user_id, store_id, token_hash, expires_at)
  VALUES (gen_random_uuid(), N, S1, md5(random()::text) || md5(random()::text), now() + interval '20 days');
  INSERT INTO public.staff_members (id, store_id, name, role) VALUES
    (O, S1, 'Chủ O', 'owner'), (N, S1, 'Nhân viên N', 'cashier'), (V, S1, 'Người mới V', 'cashier');

  -- ── Tự đổi tên ──
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._dt_claims(O, 'pos');
  r := public.update_my_display_name_v4('  Chủ   Quán   Giang  ');
  PERFORM public._dt_ok((r->>'success')::boolean AND r->>'display_name' = 'Chủ Quán Giang', '1 chủ quán tự đổi tên (gộp khoảng trắng thừa)');
  PERFORM public._dt_ok(public.update_my_display_name_v4('A')->>'error_code' = 'INVALID_NAME', '2 tên 1 ký tự bị từ chối');
  PERFORM public._dt_ok(public.update_my_display_name_v4(repeat('a', 51))->>'error_code' = 'INVALID_NAME', '3 tên quá 50 ký tự bị từ chối');
  r := public.update_my_display_name_v4(E'Lan\n\tAnh');
  PERFORM public._dt_ok(r->>'display_name' = 'Lan Anh', '4 bỏ ký tự xuống dòng / tab');
  PERFORM public._dt_ok(public.update_my_display_name_v4(E'\u200B\u200B\u200B')->>'error_code' = 'INVALID_NAME', '4b tên toàn ký tự vô hình bị từ chối');
  PERFORM public._dt_ok(public.update_my_display_name_v4(E'\u202ELan\u200B Anh')->>'display_name' = 'Lan Anh', '4c bỏ ký tự đảo chiều / vô hình');
  PERFORM public._dt_ok(public.update_my_display_name_v4(E'Lan Anh\u0300')->>'display_name' = normalize(E'Lan Anh\u0300', NFC), '4d chuẩn hoá chữ tổ hợp (NFD → NFC)');
  PERFORM public.update_my_display_name_v4('Lan Anh');
  PERFORM public._dt_ok(public._dt_sm(O) = 'Lan Anh', '4e tự đổi tên → danh sách nhân viên (staff_members) cũng đổi');
  PERFORM public._dt_claims(N, 'pos');
  PERFORM public._dt_ok((public.update_my_display_name_v4('Nhân viên Na')->>'success')::boolean, '5 nhân viên cũng tự đổi tên được');
  FOR i IN 1..9 LOOP PERFORM public.update_my_display_name_v4('Tên lần ' || i); END LOOP;  -- N dùng đủ 10 lượt
  PERFORM public._dt_ok(public.update_my_display_name_v4('Tên lần 11')->>'error_code' = 'TOO_MANY', '6 quá 10 lần / giờ bị chặn');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._dt_claims(O, 'anon');
  t := public._dt_try($q$SELECT public.update_my_display_name_v4('Đã bị hack')$q$);
  PERFORM public._dt_ok(t LIKE 'err:%', '7 CHƯA đăng nhập + header x-user-id của người khác → KHÔNG đổi được (lỗ của bản 15/10)');
  t := public._dt_try(format('UPDATE public.user_accounts SET display_name = %L WHERE id = %L', 'Hack bảng', O));
  PERFORM public._dt_ok(t = 'err:42501', '7b CHƯA đăng nhập + x-user-id sửa thẳng bảng user_accounts → bị từ chối quyền');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._dt_claims(O, 'pos');
  t := public._dt_try(format('UPDATE public.user_accounts SET display_name = %L WHERE id = %L', 'Sửa thẳng', O));
  PERFORM public._dt_ok(t = 'err:42501', '7c đã đăng nhập cũng không sửa thẳng bảng (chỉ qua hàm có kiểm + nhật ký)');
  EXECUTE 'RESET ROLE';
  PERFORM public._dt_ok((SELECT display_name FROM public.user_accounts WHERE id = O) = 'Lan Anh', '8 tên chủ quán không bị đổi bởi lần thử trên');

  -- ── Chủ quán đổi tên nhân viên ──
  UPDATE public.user_accounts SET display_name = 'Nhân viên N' WHERE id = N;
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._dt_claims(M, 'pos');
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, N, 'Tên mới')->>'error' = 'OWNER_ONLY', '9 quản lý KHÔNG đổi tên nhân viên được');
  PERFORM public._dt_claims(O, 'pos');
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, O, 'Tên mới')->>'error' = 'SELF', '10 tự đổi tên mình phải dùng Cài đặt');
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, O2, 'Tên mới')->>'error' = 'NOT_MEMBER', '11 người không thuộc quán');
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, X, 'Tên mới')->>'error' = 'OTHER_STORES', '12 nhân viên còn làm quán người khác → không đổi');
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, V, 'Tên mới')->>'error' = 'NOT_ACTIVE', '13 người chưa từng tự đăng nhập vào quán → không đổi');
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, N, ' ')->>'error' = 'BAD_NAME', '14 tên trống');
  r := public.store_staff_set_name_v1(S1, N, 'Lan Thu Ngân');
  PERFORM public._dt_ok((r->>'ok')::boolean AND r->>'display_name' = 'Lan Thu Ngân', '15 chủ quán đổi tên nhân viên');
  PERFORM public._dt_ok(public._dt_sm(N) = 'Lan Thu Ngân', '15b danh sách nhân viên (staff_members) hiện tên mới');
  -- PATCH thẳng staff_members (PostgREST): quản lý sửa tên nhân viên, nhân viên sửa tên trong hồ sơ của mình → giữ theo tên tài khoản
  PERFORM public._dt_claims(M, 'pos');
  PERFORM set_config('request.headers', json_build_object('x-store-id', S1)::text, true);
  UPDATE public.staff_members SET name = 'Tên giả do quản lý' WHERE id = N;
  GET DIAGNOSTICS i = ROW_COUNT;
  PERFORM public._dt_ok(i = 1, '15c0 lệnh sửa của quản lý thật sự chạm 1 dòng (không bị RLS lọc mất)');
  PERFORM public._dt_ok(public._dt_sm(N) = 'Lan Thu Ngân', '15c quản lý KHÔNG sửa tay được tên nhân viên trong staff_members');
  PERFORM public._dt_claims(N, 'pos');
  PERFORM set_config('request.headers', json_build_object('x-store-id', S1)::text, true);
  t := public._dt_try(format('UPDATE public.staff_members SET name = %L WHERE id = %L', 'Chủ giả mạo', O));
  PERFORM public._dt_ok(t LIKE 'err:%' AND public._dt_sm(O) = 'Lan Anh', '15d thu ngân không sửa được hồ sơ chủ quán');
  UPDATE public.staff_members SET name = 'Chủ quán' WHERE id = N;
  GET DIAGNOSTICS i = ROW_COUNT;
  PERFORM public._dt_ok(i = 1, '15e0 lệnh sửa hồ sơ của chính nhân viên chạm 1 dòng');
  PERFORM public._dt_ok(public._dt_sm(N) = 'Lan Thu Ngân', '15e nhân viên sửa tên trong hồ sơ mình → vẫn theo tên tài khoản');
  PERFORM public._dt_claims(O, 'pos');
  PERFORM public._dt_claims(O2, 'pos');
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, N, 'Hack')->>'error' = 'OWNER_ONLY', '16 chủ quán khác không đổi được');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._dt_claims(O, 'anon');
  t := public._dt_try(format('SELECT public.store_staff_set_name_v1(%L, %L, %L)', S1, N, 'Anon hack'));
  PERFORM public._dt_ok(t LIKE 'err:%', '17 anon + header x-user-id của chủ quán → bị chặn');
  EXECUTE 'RESET ROLE';
  PERFORM public._dt_ok((SELECT display_name FROM public.user_accounts WHERE id = N) = 'Lan Thu Ngân', '18 tên nhân viên đúng tên chủ quán đặt');
  PERFORM public._dt_ok((SELECT count(*) = 1 AND bool_and(actor_user = O AND reason = 'Chủ quán đổi tên: Nhân viên N → Lan Thu Ngân')
                           FROM public.support_actions WHERE target_user = N AND action = 'owner_set_name'),
                        '19 nhật ký ghi chủ quán đổi tên cũ → mới');
  PERFORM public._dt_ok((SELECT bool_or(e->>'admin' = 'Lan Thu Ngân (tự đổi)') AND bool_or(e->>'admin' = 'Lan Anh (chủ quán)')
                           FROM jsonb_array_elements(public.qn_admin_account_json(N)->'support') e),
                        '20 /admin: dòng tự đổi tên ghi "(tự đổi)", dòng chủ quán đổi ghi "(chủ quán)"');

  -- Giới hạn: đổi tên không ăn vào lượt đặt mật khẩu H3; đổi tên tối đa 30 / giờ
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._dt_claims(O, 'pos');
  FOR i IN 1..29 LOOP PERFORM public.store_staff_set_name_v1(S1, N, 'Tên NV ' || i); END LOOP;
  PERFORM public._dt_ok(public.store_staff_set_name_v1(S1, N, 'Tên NV 31')->>'error' = 'TOO_MANY', '21 chủ quán đổi tên quá 30 lần / giờ bị chặn');
  PERFORM public._dt_ok((public.store_staff_set_password_v1(S1, N, 'matkhau-moi-123')->>'ok')::boolean, '22 vẫn đặt lại mật khẩu được (H3 chỉ đếm lượt đặt mật khẩu)');
  EXECUTE 'RESET ROLE';

  RAISE NOTICE '>>> DOI TEN AN TOAN: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
