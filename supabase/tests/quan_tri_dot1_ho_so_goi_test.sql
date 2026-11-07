-- ============================================================================
-- TEST: Trang quản trị đợt 1 — hồ sơ quán, gói / hạn dùng thử, thao tác, khoá quán
-- (20261027_quan_tri_dot1_ho_so_goi.sql). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._d1_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._d1_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;
-- kind: admin | pos (người đăng nhập quán, kèm x-store-id) | none
CREATE OR REPLACE FUNCTION public._d1_claims(p_user uuid, p_kind text, p_store uuid DEFAULT NULL)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'store_id', p_store, 'exp', now_s + 3600)::text
    ELSE '' END, true);
  PERFORM set_config('request.headers', CASE WHEN p_store IS NULL THEN '{}' ELSE json_build_object('x-store-id', p_store)::text END, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._d1_ok(boolean, text), public._d1_try(text), public._d1_claims(uuid, text, uuid)
  TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A  uuid := gen_random_uuid();   -- tài khoản quản trị
  B  uuid := gen_random_uuid();   -- chủ quán
  C  uuid := gen_random_uuid();   -- thu ngân
  X  uuid := gen_random_uuid();   -- người ngoài
  S1 uuid := gen_random_uuid();   -- quán hết dùng thử
  S2 uuid := gen_random_uuid();   -- quán mới (tạo bằng INSERT thẳng như app)
  r jsonb; t text; n int; v_note bigint;
BEGIN
  RAISE NOTICE '>>> QUAN TRI DOT 1: BẮT ĐẦU <<<';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_dot1_' || substr(A::text, 1, 6), '$2a$x', 'QT Đợt 1', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (B, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ D1'),
    (C, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Thu ngân D1'),
    (X, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Người ngoài');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at)
  VALUES (S1, 'D' || substr(S1::text, 1, 7), 'Quán D1', B, 'trial', 'free', now() - interval '10 days');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (B, S1, 'owner', true), (C, S1, 'cashier', false);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at) VALUES
    (gen_random_uuid(), S1, 50000, 'completed', now() - interval '1 day'),
    (gen_random_uuid(), S1, 70000, 'completed', now() - interval '20 days'),
    (gen_random_uuid(), S1, 99000, 'cancelled', now());
  INSERT INTO public.app_logs (store_id, device_id, staff_name, level, tag, message, created_at) VALUES
    (S1, 'may-1', 'Lan', 'INFO', 'order', 'ok', now() - interval '2 hours'),
    (S1, 'may-1', 'Lan', 'ERROR', 'checkout', 'Lỗi <b>in</b>', now() - interval '1 hour'),
    (S1, 'may-2', 'Minh', 'INFO', 'order', 'ok', now() - interval '3 days'),
    (S1, 'Unknown', NULL, 'INFO', 'system', 'x', now());
  INSERT INTO public.pos_refresh_tokens (family_id, user_id, store_id, token_hash, expires_at, client_label, client_ip)
  VALUES (gen_random_uuid(), C, S1, md5(random()::text) || md5(random()::text), now() + interval '20 days', 'web', '1.2.3.4');

  -- ── Chốt cột gói ────────────────────────────────────────────────────────────────────────────────
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._d1_claims(C, 'pos', S1);
  t := public._d1_try(format('UPDATE public.stores SET plan = %L WHERE id = %L', 'pro', S1));
  PERFORM public._d1_ok(t = 'err:42501', '1 thu ngân KHÔNG tự đổi gói được (trước đây được)');
  t := public._d1_try(format('UPDATE public.stores SET trial_ends_at = now() + interval ''1 year'' WHERE id = %L', S1));
  PERFORM public._d1_ok(t = 'err:42501', '2 không tự kéo dài hạn dùng thử');
  t := public._d1_try(format('UPDATE public.stores SET status = %L WHERE id = %L', 'active', S1));
  PERFORM public._d1_ok(t = 'err:42501', '3 không tự đổi trạng thái');
  t := public._d1_try(format('UPDATE public.stores SET last_active_at = now() WHERE id = %L', S1));
  PERFORM public._d1_ok(t = 'ok', '4 app vẫn cập nhật last_active_at bình thường');
  t := public._d1_try(format('UPDATE public.stores SET owner_user_id = %L WHERE id = %L', C, S1));
  PERFORM public._d1_ok(t = 'err:42501', '4b thu ngân KHÔNG tự đặt mình làm chủ quán được (QC)');
  t := public._d1_try(format('UPDATE public.stores SET store_code = %L WHERE id = %L', 'HACK1', S1));
  PERFORM public._d1_ok(t = 'err:42501', '4c không tự đổi mã quán');
  t := public._d1_try(format('UPDATE public.stores SET name = %L WHERE id = %L', 'Quán D1', S1));
  PERFORM public._d1_ok(t = 'ok', '4d vẫn đổi tên quán được');
  PERFORM public._d1_claims(B, 'pos', NULL);
  t := public._d1_try(format('INSERT INTO public.stores (id, store_code, name, owner_user_id, plan, status, trial_ends_at) '
                             'VALUES (%L, %L, %L, %L, %L, %L, now() + interval ''5 years'')',
                             S2, 'E' || substr(S2::text, 1, 7), 'Quán mới', B, 'pro', 'active'));
  PERFORM public._d1_ok(t = 'ok', '5 chủ quán vẫn tạo quán bằng INSERT thẳng');
  EXECUTE 'RESET ROLE';
  PERFORM public._d1_ok((SELECT plan = 'free' AND status = 'trial' AND trial_ends_at < now() + interval '15 days'
                           FROM public.stores WHERE id = S2), '6 quán tạo thẳng bị ép free / trial / 14 ngày');

  -- ── App hỏi gói ─────────────────────────────────────────────────────────────────────────────────
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._d1_claims(B, 'pos', S1);
  r := public.store_plan_status_v1(S1);
  PERFORM public._d1_ok((r->>'ok')::boolean AND r->>'notice' = 'trial_expired' AND (r->>'is_owner')::boolean
                        AND NOT (r->>'locked')::boolean, '7 chủ quán thấy "hết dùng thử"');
  PERFORM public._d1_claims(C, 'pos', S1);
  r := public.store_plan_status_v1(S1);
  PERFORM public._d1_ok((r->>'ok')::boolean AND NOT (r->>'is_owner')::boolean, '8 thu ngân đọc được, không phải chủ');
  PERFORM public._d1_claims(X, 'pos', S1);
  PERFORM public._d1_ok(public.store_plan_status_v1(S1)->>'error' = 'FORBIDDEN', '9 người ngoài quán → từ chối');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  PERFORM set_config('request.headers', json_build_object('x-user-id', B, 'x-store-id', S1)::text, true);
  t := public._d1_try(format('SELECT public.store_plan_status_v1(%L)', S1));
  PERFORM public._d1_ok(t LIKE 'err:%', '9b anon + header x-user-id KHÔNG hỏi được trạng thái quán (QC)');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  -- ── Chủ quán tự gia hạn 30 ngày (quán S2: dùng thử 14 ngày) ─────────────────────────────────────
  PERFORM public._d1_claims(B, 'pos', S2);
  r := public.store_plan_status_v1(S2);
  PERFORM public._d1_ok(NOT (r->>'can_self_extend')::boolean, '9c còn 14 ngày → chưa hiện nút tự gia hạn');
  PERFORM public._d1_ok(public.store_self_extend_trial_v1(S2)->>'error' = 'NOT_DUE', '9d còn 14 ngày → không tự gia hạn (không cộng dồn)');
  EXECUTE 'RESET ROLE';
  UPDATE public.stores SET trial_ends_at = now() - interval '5 days' WHERE id = S2;
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (C, S2, 'cashier', false);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._d1_claims(C, 'pos', S2);
  PERFORM public._d1_ok(NOT (public.store_plan_status_v1(S2)->>'can_self_extend')::boolean, '9e thu ngân không thấy nút');
  PERFORM public._d1_ok(public.store_self_extend_trial_v1(S2)->>'error' = 'OWNER_ONLY', '9f thu ngân không tự gia hạn được');
  PERFORM public._d1_claims(B, 'pos', S2);
  PERFORM public._d1_ok((public.store_plan_status_v1(S2)->>'can_self_extend')::boolean, '9g hết hạn → chủ quán thấy nút');
  r := public.store_self_extend_trial_v1(S2);
  PERFORM public._d1_ok((r->>'ok')::boolean AND (r->>'trial_ends_at')::timestamptz BETWEEN now() + interval '29 days' AND now() + interval '31 days',
                        '9h chủ quán tự gia hạn: hết hạn 5 ngày → tính 30 ngày từ hôm nay');
  PERFORM public._d1_ok(public.store_self_extend_trial_v1(S2)->>'error' = 'NOT_DUE', '9i bấm lần 2 ngay → không cộng dồn');
  r := public.store_plan_status_v1(S2);
  PERFORM public._d1_ok(r->>'notice' IS NULL AND NOT (r->>'can_self_extend')::boolean, '9j gia hạn xong → hết dải nhắc');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM set_config('request.jwt.claims', '{"role":"anon"}', true);
  t := public._d1_try(format('SELECT public.store_self_extend_trial_v1(%L)', S2));
  PERFORM public._d1_ok(t LIKE 'err:%', '9k anon không gọi được hàm tự gia hạn');
  EXECUTE 'RESET ROLE';
  PERFORM public._d1_ok((SELECT count(*) = 1 AND bool_and(admin_id = B) FROM public.admin_store_actions
                          WHERE store_id = S2 AND action = 'self_extend'), '9l ghi nhật ký 1 lượt tự gia hạn, đúng người');
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._d1_claims(X, 'pos', S1);
  t := public._d1_try(format('SELECT public.admin_store_detail_v1(%L)', S1));
  PERFORM public._d1_ok(t LIKE 'err:%', '10 người đăng nhập quán không gọi được hàm quản trị');
  t := public._d1_try('SELECT count(*) FROM public.admin_store_notes');
  PERFORM public._d1_ok(t LIKE 'err:%', '11 không đọc được sổ chăm sóc');
  EXECUTE 'RESET ROLE';

  -- ── Hàm quản trị ────────────────────────────────────────────────────────────────────────────────
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._d1_claims(B, 'admin');
  PERFORM public._d1_ok(public.admin_store_detail_v1(S1)->>'error' = 'FORBIDDEN', '12 vé quản trị mang id chủ quán → từ chối');
  PERFORM public._d1_claims(A, 'admin');
  r := public.admin_store_detail_v1(S1);
  PERFORM public._d1_ok((r->>'ok')::boolean AND r->'owner'->>'name' = 'Chủ D1' AND (r->'sales'->>'orders_30d')::int = 2
                        AND (r->'sales'->>'revenue_30d')::numeric = 120000 AND (r->'sales'->>'orders_7d')::int = 1,
                        '13 hồ sơ: chủ + doanh số 7/30 ngày (bỏ đơn huỷ)');
  PERFORM public._d1_ok(jsonb_array_length(r->'devices') = 2 AND (r->>'errors_14d')::int = 1
                        AND r->'errors'->0->>'message' = 'Lỗi <b>in</b>' AND jsonb_array_length(r->'sales_by_day') = 30
                        AND jsonb_array_length(r->'accounts') = 2 AND (r->'sessions'->>'active')::int = 1
                        AND (r->'sessions'->'recent'->0->>'live')::boolean,
                        '14 hồ sơ: 2 thiết bị (bỏ Unknown), lỗi nguyên văn, 30 ngày, 2 tài khoản, 1 phiên');
  PERFORM public._d1_ok(public.admin_store_detail_v1(gen_random_uuid())->>'error' = 'NOT_FOUND', '15 quán không có');
  r := public.admin_store_detail_v1(S2);
  PERFORM public._d1_ok(r->'actions'->0->>'action' = 'self_extend' AND r->'actions'->0->>'author' = 'Chủ D1',
                        '15b hồ sơ quán hiện lượt chủ quán tự gia hạn');

  r := public.admin_store_extend_trial_v1(S1, 0, NULL);
  PERFORM public._d1_ok(r->>'error' = 'BAD_DAYS', '16 gia hạn 0 ngày bị từ chối');
  r := public.admin_store_extend_trial_v1(S1, 30, 'Khách xin thêm');
  PERFORM public._d1_ok((r->>'ok')::boolean AND (r->'store'->>'trial_ends_at')::timestamptz > now() + interval '29 days'
                        AND (r->'store'->>'trial_ends_at')::timestamptz < now() + interval '31 days',
                        '17 hết hạn từ 10 ngày trước + 30 ngày → tính từ hôm nay');

  r := public.admin_store_set_plan_v1(S1, 'pro', now() - interval '1 day', NULL, NULL);
  PERFORM public._d1_ok(r->>'error' = 'BAD_ENDS_AT', '18 hạn Pro trong quá khứ bị từ chối');
  r := public.admin_store_set_plan_v1(S1, 'gold', NULL, NULL, NULL);
  PERFORM public._d1_ok(r->>'error' = 'BAD_PLAN', '19 gói lạ bị từ chối');
  r := public.admin_store_set_plan_v1(S1, 'pro', now() + interval '5 days', 300000, 'CK tháng 11');
  PERFORM public._d1_ok((r->>'ok')::boolean AND r->'store'->>'plan' = 'pro' AND r->'store'->>'status' = 'active',
                        '20 lên Pro, thu 300.000đ');
  r := public.admin_store_extend_trial_v1(S1, 7, NULL);
  PERFORM public._d1_ok(r->>'error' = 'PLAN_NOT_TRIAL', '21 quán Pro không gia hạn dùng thử');

  r := public.admin_store_set_locked_v1(S1, true, '');
  PERFORM public._d1_ok(r->>'error' = 'REASON_REQUIRED', '22 khoá phải có lý do');
  r := public.admin_store_set_locked_v1(S1, true, 'Quán spam');
  PERFORM public._d1_ok((r->>'ok')::boolean AND r->'store'->>'status' = 'locked', '23 khoá quán');
  r := public.admin_store_set_locked_v1(S1, true, 'lần 2');
  PERFORM public._d1_ok(r->>'error' = 'NO_CHANGE', '24 khoá lần 2 → không đổi');
  r := public.admin_store_set_plan_v1(S1, 'free', NULL, NULL, 'hạ gói');
  PERFORM public._d1_ok(r->'store'->>'status' = 'locked' AND r->'store'->>'plan' = 'free', '25 đổi gói khi đang khoá → vẫn khoá');
  r := public.admin_store_set_plan_v1(S1, 'pro', NULL, NULL, NULL);
  PERFORM public._d1_ok(r->'store'->>'plan_ends_at' IS NULL, '26 Pro không thời hạn');
  EXECUTE 'RESET ROLE';

  -- ── Quán bị khoá: dữ liệu theo quán bị chặn ─────────────────────────────────────────────────────
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._d1_claims(B, 'pos', S1);
  PERFORM public._d1_ok(public.current_store_id() IS NULL, '27 quán khoá → current_store_id() = NULL');
  r := public.store_plan_status_v1(S1);
  PERFORM public._d1_ok((r->>'ok')::boolean AND (r->>'locked')::boolean AND r->>'notice' IS NULL,
                        '28 app vẫn hỏi được trạng thái khi bị khoá');
  PERFORM public._d1_ok(NOT public.qn_is_member(S1), '28b quán khoá → qn_is_member = false (chặn 4 hàm báo cáo)');
  PERFORM public._d1_ok((SELECT count(*) FROM public.stores WHERE id = S1) = 1
                        AND (SELECT count(*) FROM public.store_members WHERE store_id = S1) >= 1,
                        '28e quán khoá vẫn đọc được tên quán + thành viên (app không "mất quán")');
  t := public._d1_try(format('UPDATE public.stores SET name = %L WHERE id = %L', 'Đổi khi khoá', S1));
  PERFORM public._d1_ok(t = 'ok' AND (SELECT name FROM public.stores WHERE id = S1) <> 'Đổi khi khoá', '28f quán khoá không sửa được dòng quán');
  t := public._d1_try(format('SELECT * FROM public.verify_staff_qr_membership_v4(%L, true, false)', S1));
  PERFORM public._d1_ok(t = 'err:42501', '28c quán khoá → cổng bán hàng / quyết toán chặn (complete_pos_sale_v1…)');
  t := public._d1_try(format('SELECT public.get_report_stats_for_range_v1(%L, now() - interval ''30 days'', now())', S1));
  PERFORM public._d1_ok(t LIKE 'err:%' OR NOT (public.get_report_stats_for_range_v1(S1, now() - interval '30 days', now())::text LIKE '%120000%'),
                        '28d quán khoá → báo cáo không trả doanh số');
  PERFORM public._d1_claims(B, 'pos', S2);
  PERFORM public._d1_ok(public.current_store_id() = S2 AND public.qn_is_member(S2), '29 quán khác của cùng chủ không bị ảnh hưởng');
  EXECUTE 'RESET ROLE';
  PERFORM public._d1_ok((SELECT count(*) FROM public.pos_refresh_tokens WHERE store_id = S1 AND revoked_at IS NULL) = 1,
                        '30 khoá KHÔNG thu hồi phiên (đăng nhập vẫn được để thấy màn khoá)');

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._d1_claims(A, 'admin');
  r := public.admin_store_set_locked_v1(S1, false, NULL);
  PERFORM public._d1_ok((r->>'ok')::boolean AND r->'store'->>'status' = 'active', '31 mở khoá Pro → active');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._d1_claims(B, 'pos', S1);
  PERFORM public._d1_ok(public.current_store_id() = S1 AND public.qn_is_member(S1), '32 mở khoá → dữ liệu quán dùng lại được');
  t := public._d1_try(format('SELECT * FROM public.verify_staff_qr_membership_v4(%L, true, false)', S1));
  PERFORM public._d1_ok(t = 'ok', '32b mở khoá → bán hàng lại được');
  EXECUTE 'RESET ROLE';

  -- ── Sổ chăm sóc, cài đặt, danh sách ─────────────────────────────────────────────────────────────
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._d1_claims(A, 'admin');
  PERFORM public._d1_ok(public.admin_store_note_add_v1(S2, '   ', NULL)->>'error' = 'BAD_BODY', '33 ghi chú rỗng bị từ chối');
  r := public.admin_store_note_add_v1(S2, 'Gọi hỏi cài máy in', (now() AT TIME ZONE 'Asia/Ho_Chi_Minh')::date);
  PERFORM public._d1_ok((r->>'ok')::boolean, '34 thêm ghi chú hẹn gọi hôm nay');
  v_note := (r->>'id')::bigint;
  r := public.admin_plan_list_v1('follow_up', NULL, true, 50, 0);
  PERFORM public._d1_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r->'rows') e WHERE (e->>'id')::uuid = S2)
                        AND NOT (r->'rows'->0 ? 'rn'), '35 quán S2 vào danh sách "cần gọi"');
  PERFORM public._d1_ok((public.admin_store_note_done_v1(v_note, true)->>'ok')::boolean, '36 đánh dấu đã gọi');
  EXECUTE 'RESET ROLE';
  PERFORM public._d1_ok((SELECT done_by = A FROM public.admin_store_notes WHERE id = v_note), '36b ghi ai đánh dấu đã gọi');
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._d1_claims(A, 'admin');
  r := public.admin_plan_list_v1('follow_up', NULL, true, 50, 0);
  PERFORM public._d1_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r->'rows') e WHERE (e->>'id')::uuid = S2),
                        '37 đã gọi → ra khỏi danh sách');
  PERFORM public._d1_ok(public.admin_plan_list_v1('xyz', NULL, true, 50, 0)->>'error' = 'BAD_FILTER', '38 bộ lọc lạ');
  r := public.admin_plan_list_v1('pro', 'Quán D1', true, 50, 0);
  PERFORM public._d1_ok((r->>'total')::int = 1 AND r->'rows'->0->>'owner_name' = 'Chủ D1', '39 lọc Pro + tìm tên');
  PERFORM public._d1_ok(public.admin_platform_setting_set_v1('other', 'x')->>'error' = 'BAD_KEY', '40 khoá cài đặt lạ');
  PERFORM public._d1_ok((public.admin_platform_setting_set_v1('plan_contact', 'Zalo 0900 000 000')->>'ok')::boolean, '41 đặt câu liên hệ');
  r := public.admin_plan_overview_v1(true);
  PERFORM public._d1_ok((r->>'ok')::boolean AND r->>'contact' = 'Zalo 0900 000 000' AND (r->>'revenue_vnd_30d')::bigint >= 300000,
                        '42 tổng quan gói: câu liên hệ + tiền thu');
  r := public.admin_store_detail_v1(S1);
  SELECT count(*) INTO n FROM jsonb_array_elements(r->'actions');
  PERFORM public._d1_ok(n = 6 AND r->'actions'->0->>'author' = 'QT Đợt 1', '43 nhật ký đủ 6 thao tác thành công, có người làm');
  r := public.admin_store_list_v1('all', 'Quán D1', true, 10, 0);
  PERFORM public._d1_ok((r->'rows'->0->>'devices')::int = 2, '44 danh sách quán: đếm thiết bị thật từ nhật ký');
  t := public._d1_try('SELECT count(*) FROM public.admin_store_actions');
  PERFORM public._d1_ok(t LIKE 'err:%', '45 vé quản trị cũng không đọc thẳng bảng nhật ký');
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._d1_claims(B, 'pos', S1);
  PERFORM public._d1_ok(public.store_plan_status_v1(S1)->>'contact' = 'Zalo 0900 000 000', '46 app nhận câu liên hệ');
  EXECUTE 'RESET ROLE';

  RAISE NOTICE '>>> QUAN TRI DOT 1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
