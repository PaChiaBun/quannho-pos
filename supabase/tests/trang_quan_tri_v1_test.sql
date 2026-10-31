-- ============================================================================
-- TEST: Trang quản trị v1 (20261026_trang_quan_tri_v1.sql). Kết thúc ROLLBACK.
-- Vé giả lập bằng request.jwt.claims; gọi như người đăng nhập (ROLE authenticated).
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._qt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;

CREATE OR REPLACE FUNCTION public._qt_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;

-- đặt vé: kind = admin | pos | none | expired
CREATE OR REPLACE FUNCTION public._qt_claims(p_user uuid, p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'expired' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s - 100, 'exp', now_s - 10)::text
    WHEN 'long' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 86400)::text
    WHEN 'auth_admin' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'store_id', gen_random_uuid(), 'exp', now_s + 3600)::text
    ELSE '' END, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._qt_ok(boolean, text), public._qt_try(text), public._qt_claims(uuid, text) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid();   -- quản trị
  B uuid := gen_random_uuid();   -- chủ quán thường
  S1 uuid := gen_random_uuid();  -- quán đang bán
  S2 uuid := gen_random_uuid();  -- quán chưa bán
  r jsonb; q uuid; t text; row1 jsonb;
BEGIN
  RAISE NOTICE '>>> TRANG QUAN TRI v1: BẮT ĐẦU <<<';
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (A, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Admin QT'),
    (B, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chu QT');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status) VALUES
    (S1, 'Q' || substr(S1::text, 1, 7), 'Quan QT Ban', B, 'trial'),
    (S2, 'Q' || substr(S2::text, 1, 7), 'Quan QT Moi', B, 'trial');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (B, S1, 'owner', true), (B, S2, 'owner', true);
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (A, S1, 'manager', false);
  INSERT INTO public.products (id, store_id, name, product_type, is_active, is_deleted) VALUES
    (gen_random_uuid(), S1, 'Ca phe', 'finished', true, false),
    (gen_random_uuid(), S1, 'Tra', 'finished', true, false),
    (gen_random_uuid(), S1, 'Mon xoa', 'finished', true, true),
    (gen_random_uuid(), S1, 'Sua', 'ingredient', true, false);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at) VALUES
    (gen_random_uuid(), S1, 50000, 'completed', now() - interval '1 day'),
    (gen_random_uuid(), S1, 70000, 'completed', now() - interval '2 days'),
    (gen_random_uuid(), S1, 10000, 'cancelled', now());
  INSERT INTO public.platform_admins (user_id, note) VALUES (A, 'test');

  -- Ghi lịch sử (service_role)
  EXECUTE 'SET LOCAL ROLE service_role';
  r := public.boom_qa_full_write_v1(NULL, S1, B, 'gpt', 'huong_dan_gpt', 'cách huỷ món', 'Bấm Huỷ món…', ARRAY['quan-ly-ban#a']);
  PERFORM public._qt_ok((r->>'ok')::boolean, '1 hàm boom-chat ghi được lịch sử nguyên văn');
  q := (r->>'id')::uuid;
  r := public.boom_qa_full_write_v1(NULL, S1, B, 'app', 'revenue_summary', 'doanh thu hôm nay', 'Hôm nay 120.000đ', NULL);
  PERFORM public._qt_ok((r->>'ok')::boolean, '2 ghi câu app tự trả (số liệu nguyên văn)');
  r := public.boom_qa_full_write_v1(NULL, S1, B, 'app', 'app:boom_khong_quyen', 'thu chi tháng này', 'Bé Boom chưa xem được…', NULL);
  r := public.boom_qa_full_write_v1(NULL, S1, B, 'xxx', NULL, 'x', 'y', NULL);
  PERFORM public._qt_ok(r->>'status' = 'bad_request', '3 nguồn lạ bị từ chối');
  PERFORM public._qt_ok(public.admin_is_platform_admin_v1(A) AND NOT public.admin_is_platform_admin_v1(B), '4 cổng đăng nhập hỏi đúng ai là quản trị');
  EXECUTE 'RESET ROLE';

  -- Người đăng nhập thường không đọc được bảng khoá
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._qt_claims(B, 'pos');
  t := public._qt_try('SELECT count(*) FROM public.boom_qa_full');
  PERFORM public._qt_ok(t LIKE 'err:%', '5 chủ quán KHÔNG đọc thẳng được boom_qa_full (' || t || ')');
  t := public._qt_try('SELECT count(*) FROM public.platform_admins');
  PERFORM public._qt_ok(t LIKE 'err:%', '6 KHÔNG đọc được danh sách quản trị');
  t := public._qt_try($q$SELECT public.boom_qa_full_write_v1(NULL, '$q$ || S1 || $q$', NULL, 'app', NULL, 'x', 'y', NULL)$q$);
  PERFORM public._qt_ok(t LIKE 'err:%', '7 người đăng nhập KHÔNG tự ghi được lịch sử');
  t := public._qt_try('SELECT public.admin_store_list_v1()');
  PERFORM public._qt_ok(t LIKE 'err:%', '8 người đăng nhập thường (authenticated) KHÔNG gọi được hàm quản trị');
  PERFORM public._qt_claims(A, 'auth_admin');
  t := public._qt_try('SELECT public.admin_whoami_v1()');
  PERFORM public._qt_ok(t LIKE 'err:%', '8b vé có token_use admin nhưng vai trò authenticated → không gọi được');
  EXECUTE 'RESET ROLE';

  -- Vai trò qn_admin: không đọc bảng nào; vé sai / hết hạn / quá dài / không vé → từ chối
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._qt_claims(A, 'admin');
  t := public._qt_try('SELECT count(*) FROM public.stores');
  PERFORM public._qt_ok(t LIKE 'err:%', '8c vé quản trị KHÔNG đọc thẳng được bảng quán (không dùng như phiên đăng nhập)');
  t := public._qt_try('SELECT count(*) FROM public.orders');
  PERFORM public._qt_ok(t LIKE 'err:%', '8d vé quản trị KHÔNG đọc được đơn hàng');
  PERFORM public._qt_claims(A, 'pos');
  PERFORM public._qt_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '9 quản trị dùng vé BÁN HÀNG → bị từ chối');
  PERFORM public._qt_claims(A, 'expired');
  PERFORM public._qt_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '10 vé quản trị HẾT HẠN → bị từ chối');
  PERFORM public._qt_claims(A, 'long');
  PERFORM public._qt_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '10b vé quản trị sống quá 4 giờ → bị từ chối');
  PERFORM public._qt_claims(B, 'admin');
  PERFORM public._qt_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '11 vé quản trị nhưng KHÔNG có trong platform_admins → từ chối');
  PERFORM public._qt_claims(A, 'none');
  PERFORM set_config('request.headers', jsonb_build_object('x-user-id', A)::text, true);
  PERFORM public._qt_ok(public.admin_whoami_v1()->>'error' = 'FORBIDDEN', '12 không vé, chỉ header x-user-id → từ chối');

  -- Vé quản trị hợp lệ
  PERFORM public._qt_claims(A, 'admin');
  r := public.admin_whoami_v1();
  PERFORM public._qt_ok((r->>'ok')::boolean AND r->>'name' = 'Admin QT', '13 vé quản trị → vào được');
  r := public.admin_store_list_v1('all', 'QT', false, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 2, '14 danh sách quán tìm theo tên');
  SELECT x INTO row1 FROM jsonb_array_elements(r->'rows') x WHERE x->>'id' = S1::text;
  PERFORM public._qt_ok((row1->>'orders_7d')::int = 2 AND (row1->>'menu_items')::int = 2
                        AND (row1->>'staff_owner')::int = 1 AND (row1->>'staff_manager')::int = 1,
                        '15 số đơn 7 ngày (bỏ đơn huỷ), số món menu (bỏ nguyên liệu / món xoá), số nhân viên');
  PERFORM public._qt_ok(NOT (row1 ? 'revenue') AND NOT (row1 ? 'total_amount'), '16 KHÔNG trả doanh thu');
  r := public.admin_store_list_v1('active', 'QT', false, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 1, '17 lọc đang dùng tích cực');
  r := public.admin_store_list_v1('never', 'QT', false, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 1, '18 lọc chưa bán đơn nào');
  r := public.admin_set_test_store_v1(S2, true);
  r := public.admin_store_list_v1('all', 'QT', false, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 1, '19 quán thử bị loại khỏi danh sách');
  r := public.admin_store_list_v1('test', 'QT', false, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 1, '20 xem riêng quán thử');
  r := public.admin_store_overview_v1(false);
  PERFORM public._qt_ok((r->>'ok')::boolean AND (r->>'test_stores')::int >= 1 AND jsonb_array_length(r->'new_by_day') = 60
                        AND jsonb_array_length(r->'active_by_week') = 12, '21 tổng quan có số đếm + 60 ngày + 12 tuần');
  PERFORM public._qt_ok(public.admin_store_list_v1('bad')->>'error' = 'BAD_FILTER', '22 bộ lọc lạ bị từ chối');

  -- Boom
  r := public.admin_boom_turns_v1(S1, NULL, NULL, 'all', NULL, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 3, '23 thấy 3 lượt của quán');
  r := public.admin_boom_turns_v1(S1, NULL, NULL, 'refused', NULL, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 1, '23b lọc Từ chối bắt cả câu app tự trả (nhãn app:)');
  r := public.admin_boom_turn_v1(q);
  PERFORM public._qt_ok(r->'turn'->>'answer' = 'Bấm Huỷ món…' AND r->'turn'->>'store_name' = 'Quan QT Ban', '24 xem nguyên văn một lượt');
  r := public.admin_boom_review_v1(q, 'sai', 'Bịa nút', true);
  PERFORM public._qt_ok((r->>'ok')::boolean, '25 chấm Sai + cần dạy lại');
  r := public.admin_boom_review_v1(q, 'dung', NULL, false);
  r := public.admin_boom_turn_v1(q);
  PERFORM public._qt_ok(r->'review'->>'verdict' = 'dung' AND NOT (r->'review'->>'needs_teaching')::boolean, '26 chấm lại ghi đè');
  PERFORM public._qt_ok(public.admin_boom_review_v1(q, 'meh', NULL, false)->>'error' = 'BAD_VERDICT', '27 điểm lạ bị từ chối');
  r := public.admin_boom_turns_v1(S1, NULL, NULL, 'unreviewed', NULL, 50, 0);
  PERFORM public._qt_ok((r->>'total')::int = 2, '28 lọc lượt chưa chấm');
  r := public.admin_boom_stats_v1(7);
  PERFORM public._qt_ok((r->>'ok')::boolean AND (r->>'turns')::int >= 2, '29 số đếm Boom');
  r := public.admin_boom_knowledge_v1();
  PERFORM public._qt_ok((r->>'ok')::boolean AND jsonb_array_length(r->'changelog') >= 13, '30 những gì đã dạy + nhật ký dạy nhập sẵn');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._qt_claims(B, 'pos');
  t := public._qt_try($q$SELECT public.admin_boom_turn_v1('$q$ || q || $q$')$q$);
  PERFORM public._qt_ok(t LIKE 'err:%', '31 chủ quán KHÔNG xem được lượt qua hàm quản trị');
  t := public._qt_try($q$SELECT public.admin_boom_review_v1('$q$ || q || $q$', 'sai', 'x', true)$q$);
  PERFORM public._qt_ok(t LIKE 'err:%', '32 chủ quán KHÔNG chấm được');
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE anon';
  t := public._qt_try('SELECT public.admin_whoami_v1()');
  PERFORM public._qt_ok(t LIKE 'err:%', '33 khách vãng lai (anon) không gọi được hàm quản trị');
  EXECUTE 'RESET ROLE';

  RAISE NOTICE '>>> TRANG QUAN TRI v1: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
