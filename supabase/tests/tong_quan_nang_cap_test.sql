-- ============================================================================
-- TEST: Nâng cấp Tổng quan /admin (20261101_tong_quan_nang_cap.sql). Kết thúc ROLLBACK.
-- Chạy được trên dữ liệu thật: so số liệu TRƯỚC / SAU khi thêm dữ liệu thử.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._tq_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._tq_claims(p_user uuid, p_kind text)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'exp', now_s + 3600)::text
    ELSE '' END, true);
END
$f$;
GRANT EXECUTE ON FUNCTION public._tq_ok(boolean, text), public._tq_claims(uuid, text) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); B2 uuid := gen_random_uuid();  -- 2 chủ: tối đa 5 quán / ngày / người
  S_TOP uuid := gen_random_uuid();   -- bán nhiều, còn bán tuần này
  S_DROP uuid := gen_random_uuid();  -- bán 20 ngày trước, tuần này 0 đơn → đang bỏ dùng
  S_TEST uuid := gen_random_uuid();  -- đã đánh dấu thử, có đơn → không tính
  S_N1 uuid := gen_random_uuid(); S_N2 uuid := gen_random_uuid(); S_N3 uuid := gen_random_uuid(); S_OK uuid := gen_random_uuid();
  S_TRIAL uuid := gen_random_uuid();
  S_J2 uuid := gen_random_uuid();    -- tên vô nghĩa nhưng đã bán → không gợi ý
  S_NOOWN uuid := gen_random_uuid(); -- bỏ dùng, đang khoá, không ghi chủ trên quán (chủ là thành viên is_owner)
  v_y date := public.qn_vn_day(now()) - 1;
  r0 jsonb; r1 jsonb; r2 jsonb; t text;
BEGIN
  RAISE NOTICE '>>> TONG QUAN NANG CAP: BẮT ĐẦU <<<';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_tq_' || substr(A::text, 1, 6), '$2a$x', 'QT Tổng quan', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
  VALUES (B, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ TQ'),
         (B2, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ TQ 2');

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tq_claims(A, 'admin');
  r0 := public.admin_overview_extra_v1(false);
  EXECUTE 'RESET ROLE';
  PERFORM public._tq_ok((r0->>'ok')::boolean, '1 vé quản trị gọi được');

  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at) VALUES
    (S_TOP,  'Q' || substr(S_TOP::text, 1, 7),  'Quán TQ Bán Nhiều', B, 'trial', 'free', now() + interval '20 days'),
    (S_DROP, 'Q' || substr(S_DROP::text, 1, 7), 'Quán TQ Bỏ Dùng', B, 'trial', 'free', now() + interval '20 days'),
    (S_TEST, 'Q' || substr(S_TEST::text, 1, 7), 'Quán TQ Đã Đánh Dấu', B, 'trial', 'free', now() + interval '20 days'),
    (S_N1,   'Q' || substr(S_N1::text, 1, 7),   'tao TEST thử', B2, 'trial', 'free', now() + interval '20 days'),
    (S_N2,   'Q' || substr(S_N2::text, 1, 7),   'hghhhh', B2, 'trial', 'free', now() + interval '20 days'),
    (S_N3,   'Q' || substr(S_N3::text, 1, 7),   '123', B2, 'trial', 'free', now() + interval '20 days'),
    (S_OK,   'Q' || substr(S_OK::text, 1, 7),   'Cơm Tấm Cô Ba', B2, 'trial', 'free', now() + interval '20 days'),
    (S_TRIAL,'Q' || substr(S_TRIAL::text, 1, 7),'Quán TQ Sắp Hết Thử', B, 'trial', 'free', now() + interval '2 days');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at) VALUES
    (S_J2, 'Q' || substr(S_J2::text, 1, 7), 'zzz', NULL, 'trial', 'free', now() + interval '20 days'),
    (S_NOOWN, 'Q' || substr(S_NOOWN::text, 1, 7), 'Quán TQ Không Ghi Chủ', NULL, 'locked', 'free', now() + interval '20 days');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (B2, S_NOOWN, 'owner', true);
  INSERT INTO public.admin_test_stores (store_id, marked_by) VALUES (S_TEST, A);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at) VALUES
    (gen_random_uuid(), S_TOP, 9000000000, 'completed', now() - interval '1 hour'),
    (gen_random_uuid(), S_TOP, 1000000, 'completed', now() - interval '10 days'),
    (gen_random_uuid(), S_TOP, 5000, 'cancelled', now()),
    (gen_random_uuid(), S_DROP, 8000000000, 'completed', now() - interval '20 days'),
    (gen_random_uuid(), S_DROP, 2000000, 'completed', now() - interval '40 days'),
    (gen_random_uuid(), S_TEST, 7000000000, 'completed', now() - interval '1 hour'),
    (gen_random_uuid(), S_J2, 1000, 'completed', now() - interval '50 days'),
    (gen_random_uuid(), S_NOOWN, 3000000000, 'completed', now() - interval '12 days'),
    -- 23:30 giờ VN hôm qua (= 16:30 UTC) → phải rơi vào cột "hôm qua", không phải hôm nay
    (gen_random_uuid(), S_TOP, 123, 'completed', ((v_y::text || ' 23:30')::timestamp AT TIME ZONE 'Asia/Ho_Chi_Minh'));

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tq_claims(A, 'admin');
  r1 := public.admin_overview_extra_v1(false);
  r2 := public.admin_overview_extra_v1(true);
  EXECUTE 'RESET ROLE';

  -- Doanh số
  PERFORM public._tq_ok((r1#>>'{sales,orders_7d}')::bigint - (r0#>>'{sales,orders_7d}')::bigint = 2
                        AND (r1#>>'{sales,revenue_7d}')::numeric - (r0#>>'{sales,revenue_7d}')::numeric = 9000000123,
                        '2 đơn + doanh thu 7 ngày: chỉ đơn hoàn thành, không tính đơn huỷ, không tính quán thử');
  PERFORM public._tq_ok((r1#>>'{sales,orders_30d}')::bigint - (r0#>>'{sales,orders_30d}')::bigint = 5
                        AND (r1#>>'{sales,revenue_30d}')::numeric - (r0#>>'{sales,revenue_30d}')::numeric = 20001000123,
                        '3 đơn + doanh thu 30 ngày');
  PERFORM public._tq_ok((r1#>>'{sales,orders_prev7}')::bigint - (r0#>>'{sales,orders_prev7}')::bigint = 2
                        AND (r1#>>'{sales,orders_prev30}')::bigint - (r0#>>'{sales,orders_prev30}')::bigint = 2,
                        '4 kỳ trước (8–14 ngày, 31–60 ngày) để so sánh');
  PERFORM public._tq_ok((r2#>>'{sales,revenue_7d}')::numeric - (r1#>>'{sales,revenue_7d}')::numeric = 7000000000,
                        '5 bật "Tính cả quán thử" thì cộng thêm quán thử');
  PERFORM public._tq_ok(jsonb_array_length(r1#>'{sales,by_day}') = 30
                        AND (r1#>'{sales,by_day}'->29->>'day')::date = public.qn_vn_day(now()),
                        '6 biểu đồ doanh thu đủ 30 ngày, ngày cuối là hôm nay (giờ VN)');
  PERFORM public._tq_ok((SELECT (e->>'revenue')::numeric FROM jsonb_array_elements(r1#>'{sales,by_day}') e WHERE (e->>'day')::date = v_y)
                        - (SELECT (e->>'revenue')::numeric FROM jsonb_array_elements(r0#>'{sales,by_day}') e WHERE (e->>'day')::date = v_y) = 123,
                        '6b đơn 23:30 giờ VN hôm qua nằm đúng cột hôm qua');
  PERFORM public._tq_ok(r1#>'{sales,top}'->0->>'id' = S_TOP::text AND (r1#>'{sales,top}'->0->>'orders')::int = 3
                        AND jsonb_array_length(r1#>'{sales,top}') <= 5,
                        '7 quán bán nhiều nhất đứng đầu, tối đa 5 quán');
  PERFORM public._tq_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{sales,top}') e WHERE e->>'id' = S_TEST::text),
                        '8 quán thử không lọt vào bảng xếp hạng');

  -- Quán đang bỏ dùng
  PERFORM public._tq_ok((r1#>>'{dropping,total}')::int - (r0#>>'{dropping,total}')::int = 2, '9 đếm thêm đúng 2 quán đang bỏ dùng');
  PERFORM public._tq_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{dropping,rows}') e WHERE e->>'id' = S_NOOWN::text
                                AND e->>'owner_name' = 'Chủ TQ 2' AND (e->>'locked')::boolean),
                        '9b quán không ghi chủ trên quán vẫn có tên chủ (thành viên chủ), có cờ đang khoá');
  PERFORM public._tq_ok(r1#>'{dropping,rows}'->0->>'id' = S_DROP::text
                        AND r1#>'{dropping,rows}'->0->>'owner_name' = 'Chủ TQ'
                        AND r1#>'{dropping,rows}'->0->>'owner_phone' IS NOT NULL
                        AND (r1#>'{dropping,rows}'->0->>'orders_30d')::int = 1,
                        '10 quán bỏ dùng có tên chủ + SĐT + số đơn 30 ngày (bán nhiều nhất lên đầu)');
  PERFORM public._tq_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r1#>'{dropping,rows}') e WHERE e->>'id' IN (S_TOP::text, S_N1::text)),
                        '11 quán còn bán tuần này / chưa từng bán không bị tính là bỏ dùng');

  -- Việc hôm nay
  PERFORM public._tq_ok((r1#>>'{todo,trial_ending}')::int - (r0#>>'{todo,trial_ending}')::int = 1, '12 đếm quán sắp hết dùng thử');
  PERFORM public._tq_ok(r1->'todo' ?& ARRAY['trial_expired', 'pro_ending', 'pro_expired', 'follow_ups_due', 'support_open',
                                             'support_in_progress', 'billing_pending'], '13 đủ các loại việc hôm nay');

  -- Gợi ý quán thử
  PERFORM public._tq_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'test_suggest') e WHERE e->>'id' = S_N1::text AND e->>'reason' = 'name_test'),
                        '14 tên có "test" → gợi ý');
  PERFORM public._tq_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'test_suggest') e WHERE e->>'id' = S_N2::text AND e->>'reason' = 'name_junk')
                        AND EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'test_suggest') e WHERE e->>'id' = S_N3::text AND e->>'reason' = 'name_junk'),
                        '15 tên vô nghĩa (hghhhh, 123) chưa bán đơn nào → gợi ý');
  PERFORM public._tq_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(r1->'test_suggest') e WHERE e->>'id' IN (S_OK::text, S_TEST::text, S_TOP::text, S_J2::text)),
                        '16 tên thật / quán đã đánh dấu thử / tên vô nghĩa nhưng đã bán → không gợi ý');

  -- Quyền
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._tq_claims(B, 'pos');
  BEGIN
    PERFORM public.admin_overview_extra_v1(false);
    t := 'ok';
  EXCEPTION WHEN OTHERS THEN t := SQLSTATE;
  END;
  EXECUTE 'RESET ROLE';
  PERFORM public._tq_ok(t = '42501', '17 chủ quán (vé app) không gọi được');
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tq_claims(B, 'admin');  -- vé quản trị giả (sub không phải tài khoản quản trị)
  r2 := public.admin_overview_extra_v1(false);
  EXECUTE 'RESET ROLE';
  PERFORM public._tq_ok(r2->>'error' = 'FORBIDDEN', '18 vé quản trị giả → FORBIDDEN');

  RAISE NOTICE '>>> TONG QUAN NANG CAP: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
