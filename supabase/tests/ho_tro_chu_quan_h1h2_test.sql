-- ============================================================================
-- TEST: Hỗ trợ chủ quán H1 + H2 (20261029_ho_tro_chu_quan_h1h2.sql). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._ht_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._ht_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;
CREATE OR REPLACE FUNCTION public._ht_claims(p_user uuid, p_kind text)
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
GRANT EXECUTE ON FUNCTION public._ht_ok(boolean, text), public._ht_try(text), public._ht_claims(uuid, text) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); C uuid := gen_random_uuid(); S1 uuid := gen_random_uuid();
  v_phone text := '09' || lpad(((random() * 99999999)::int)::text, 8, '0');
  r jsonb; t text; n int; v_pw text; v_rep uuid;
BEGIN
  RAISE NOTICE '>>> HO TRO H1H2: BẮT ĐẦU <<<';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_ht_' || substr(A::text, 1, 6), '$2a$x', 'QT Hỗ trợ', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name, quick_pin) VALUES
    (B, v_phone, extensions.crypt('MatKhauCu123', extensions.gen_salt('bf', 4)), 'Chủ HT', '1234'),
    (C, '+84' || (900000000 + (random()*99999999)::int), 'abcdef0123456789', 'Người khác (mật khẩu kiểu cũ)', NULL);
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan) VALUES (S1, 'H' || substr(S1::text, 1, 7), 'Quán HT', B, 'trial', 'free');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (B, S1, 'owner', true);
  INSERT INTO public.pos_refresh_tokens (family_id, user_id, store_id, token_hash, expires_at)
  VALUES (gen_random_uuid(), B, S1, md5(random()::text) || md5(random()::text), now() + interval '20 days'),
         (gen_random_uuid(), C, S1, md5(random()::text) || md5(random()::text), now() + interval '20 days');

  -- ── H1: gửi phản hồi như app ──
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._ht_claims(B, 'pos');
  t := public._ht_try(format($q$INSERT INTO public.bug_reports (user_id, store_id, description, device_info, screen_name, status,
                               verified_user, admin_note) VALUES (%L, %L, %L, '{"app_version":"1.0.5","os":"android"}'::jsonb,
                               'Settings > Gửi phản hồi', 'done', %L, 'tự ghi')$q$,
                             B::text, S1::text, 'Tôi quên mật khẩu đăng nhập, nhờ cấp lại', C));
  PERFORM public._ht_ok(t = 'ok', '1 app gửi phản hồi được (đúng cột app đang gửi)');
  t := public._ht_try(format($q$INSERT INTO public.bug_reports (user_id, store_id, description) VALUES ('', %L, 'Lỗi in bill')$q$, gen_random_uuid()));
  PERFORM public._ht_ok(t = 'ok', '2 gửi kèm mã quán không thuộc mình vẫn nhận (quán bị bỏ)');
  t := public._ht_try('SELECT count(*) FROM public.bug_reports');
  PERFORM public._ht_ok(t LIKE 'err:%', '3 người gửi KHÔNG đọc được bảng phản hồi');
  t := public._ht_try($q$INSERT INTO public.bug_reports (description) VALUES ('   ')$q$);
  PERFORM public._ht_ok(t LIKE 'err:%', '4 nội dung trống bị từ chối');
  FOR n IN 1..8 LOOP PERFORM public._ht_try($q$INSERT INTO public.bug_reports (description) VALUES ('spam')$q$); END LOOP;
  t := public._ht_try($q$INSERT INTO public.bug_reports (description) VALUES ('spam lần 11')$q$);
  PERFORM public._ht_ok(t LIKE 'err:%', '5 quá 10 phản hồi / giờ bị chặn');
  PERFORM public._ht_claims(gen_random_uuid(), 'pos');
  t := public._ht_try($q$INSERT INTO public.bug_reports (description) VALUES ('vé có sub lạ')$q$);
  PERFORM public._ht_ok(t LIKE 'err:%', '5b vé có mã người không tồn tại → không gửi được');
  PERFORM public._ht_claims(B, 'pos');
  t := public._ht_try(format('SELECT public.admin_support_list_v1(%L, %L, 50, 0)', 'all', 'all'));
  PERFORM public._ht_ok(t LIKE 'err:%', '6 người đăng nhập quán không gọi được hàm quản trị');
  t := public._ht_try(format('SELECT public.admin_account_reset_password_v1(%L, %L, %L::jsonb, NULL)', B, 'thử phá', '{"callback":true,"store_info":true,"secret":true}'));
  PERFORM public._ht_ok(t LIKE 'err:%', '7 người đăng nhập quán không cấp được mật khẩu tạm');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._ht_claims(B, 'anon');
  t := public._ht_try($q$INSERT INTO public.bug_reports (description) VALUES ('anon')$q$);
  PERFORM public._ht_ok(t LIKE 'err:%', '8 chưa đăng nhập (anon + header x-user-id) không gửi được');
  EXECUTE 'RESET ROLE';
  PERFORM public._ht_ok((SELECT status = 'open' AND kind = 'forgot_password' AND verified_user = B AND verified_store = S1
                                AND admin_note IS NULL FROM public.bug_reports WHERE description LIKE 'Tôi quên mật khẩu%'),
                        '9 máy chủ ép trạng thái mở, đóng dấu đúng người / quán thật, tự nhận loại "quên mật khẩu"');
  PERFORM public._ht_ok((SELECT verified_store IS NULL FROM public.bug_reports WHERE description = 'Lỗi in bill'), '10 quán không thuộc người gửi → không gắn');

  -- ── Quản trị ──
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._ht_claims(A, 'admin');
  r := public.admin_support_list_v1('open', 'forgot_password', 50, 0);
  PERFORM public._ht_ok((r->>'total')::int >= 1 AND r->'rows'->0->>'user_name' = 'Chủ HT' AND r->'rows'->0->>'store_name' = 'Quán HT'
                        AND r->'rows'->0->>'app_version' = '1.0.5', '11 quản trị thấy yêu cầu quên mật khẩu kèm người / quán / phiên bản app');
  v_rep := (r->'rows'->0->>'id')::uuid;
  PERFORM public._ht_ok((public.admin_support_update_v1(v_rep, 'in_progress', 'Đang gọi lại')->>'ok')::boolean, '12 chuyển "đang xử lý" + ghi chú');
  PERFORM public._ht_ok(public.admin_support_update_v1(v_rep, 'xyz', NULL)->>'error' = 'BAD_STATUS', '13 trạng thái lạ');
  t := public._ht_try('SELECT count(*) FROM public.bug_reports');
  PERFORM public._ht_ok(t LIKE 'err:%', '14 vé quản trị cũng không đọc thẳng bảng');

  PERFORM public._ht_ok(public.admin_account_search_v1('ab')->>'error' = 'QUERY_TOO_SHORT', '15 từ khoá quá ngắn');
  r := public.admin_account_search_v1('+84' || right(v_phone, 9));
  PERFORM public._ht_ok(jsonb_array_length(r->'rows') = 1 AND r->'rows'->0->>'name' = 'Chủ HT'
                        AND (r->'rows'->0->>'has_quick_pin')::boolean AND r->'rows'->0->>'password_kind' = 'bcrypt'
                        AND r->'rows'->0->'stores'->0->>'name' = 'Quán HT' AND NOT (r->'rows'->0 ? 'password_hash')
                        AND NOT (r->'rows'->0 ? 'quick_pin'),
                        '16 tra theo SĐT dạng +84 ra đúng người (0…); không lộ mật khẩu / PIN');
  r := public.admin_account_search_v1('Chủ HT');
  PERFORM public._ht_ok(jsonb_array_length(r->'rows') >= 1, '17 tra theo tên');

  r := public.admin_account_reset_password_v1(B, 'Chủ gọi hotline', '{"callback":true,"store_info":true}'::jsonb, v_rep);
  PERFORM public._ht_ok(r->>'error' = 'CHECKS_REQUIRED', '18 thiếu 1 bước xác minh → từ chối');
  r := public.admin_account_reset_password_v1(B, 'abc', '{"callback":true,"store_info":true,"secret":true}'::jsonb, v_rep);
  PERFORM public._ht_ok(r->>'error' = 'REASON_REQUIRED', '19 lý do quá ngắn');
  r := public.admin_account_reset_password_v1(B, 'Chủ gọi hotline quên mật khẩu', '{"callback":true,"store_info":true,"secret":true}'::jsonb, v_rep);
  v_pw := r->>'temp_password';
  PERFORM public._ht_ok((r->>'ok')::boolean AND v_pw ~ '^[A-HJ-KM-NP-Z2-9]{10}$', '20 cấp mật khẩu tạm 10 ký tự dễ đọc');
  EXECUTE 'RESET ROLE';
  PERFORM public._ht_ok((SELECT public.verify_password_hash_v4(phone, v_pw, password_hash) AND NOT public.verify_password_hash_v4(phone, 'MatKhauCu123', password_hash)
                           AND password_hash LIKE '$2a$%' AND password_hash NOT LIKE '%' || v_pw || '%'
                         FROM public.user_accounts WHERE id = B),
                        '21 đăng nhập được bằng mật khẩu tạm, mật khẩu cũ hết dùng; lưu bcrypt, không lưu nguyên văn');
  PERFORM public._ht_ok((SELECT count(*) FROM public.pos_refresh_tokens WHERE user_id = B AND revoked_at IS NULL) = 0,
                        '22 cấp mật khẩu tạm → thu hồi vé làm mới của người đó');
  PERFORM public._ht_ok((SELECT count(*) = 1 AND bool_and(admin_id = A AND report_id = v_rep AND checks ? 'secret')
                           FROM public.support_actions WHERE target_user = B AND action = 'temp_password'),
                        '23 nhật ký hỗ trợ ghi đủ (người làm, phản hồi liên quan, các bước xác minh)');
  PERFORM public._ht_ok(NOT EXISTS (SELECT 1 FROM public.support_actions WHERE reason LIKE '%' || v_pw || '%' OR checks::text LIKE '%' || v_pw || '%'),
                        '24 mật khẩu tạm không nằm trong nhật ký');
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._ht_claims(A, 'admin');
  PERFORM public._ht_ok((public.admin_account_clear_pin_v1(B, 'Quên PIN nhanh')->>'ok')::boolean, '25 xoá PIN nhanh');
  r := public.admin_account_detail_v1(B);
  PERFORM public._ht_ok(NOT (r->'account'->>'has_quick_pin')::boolean AND jsonb_array_length(r->'account'->'support') = 2
                        AND r->'account'->'support'->0->>'admin' = 'QT Hỗ trợ', '26 chi tiết tài khoản: hết PIN, 2 dòng lịch sử hỗ trợ');
  PERFORM public._ht_ok(public.admin_account_clear_pin_v1(gen_random_uuid(), 'không có ai')->>'error' = 'NOT_FOUND', '27 tài khoản không tồn tại');
  r := public.admin_account_reset_password_v1(C, 'Nhân viên quên mật khẩu', '{"callback":true,"store_info":true,"secret":true}'::jsonb, NULL);
  EXECUTE 'RESET ROLE';
  PERFORM public._ht_ok((r->>'ok')::boolean AND (SELECT count(*) FROM public.pos_refresh_tokens WHERE user_id = C AND revoked_at IS NULL) = 0
                        AND (SELECT public.verify_password_hash_v4(phone, r->>'temp_password', password_hash) FROM public.user_accounts WHERE id = C),
                        '28 tài khoản mật khẩu kiểu cũ: cấp mật khẩu tạm vẫn thu hồi vé làm mới + đăng nhập được');

  RAISE NOTICE '>>> HO TRO H1H2: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
