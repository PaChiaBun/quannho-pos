-- ============================================================================
-- TEST: Cổng thu phí đợt A (20261028_cong_thu_phi_dot_a.sql). Kết thúc ROLLBACK.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._ca_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._ca_try(p_sql text)
RETURNS text LANGUAGE plpgsql AS $f$
BEGIN
  EXECUTE p_sql;
  RETURN 'ok';
EXCEPTION WHEN OTHERS THEN
  RETURN 'err:' || SQLSTATE;
END
$f$;
CREATE OR REPLACE FUNCTION public._ca_claims(p_user uuid, p_kind text)
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
GRANT EXECUTE ON FUNCTION public._ca_ok(boolean, text), public._ca_try(text), public._ca_claims(uuid, text) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid(); B uuid := gen_random_uuid(); C uuid := gen_random_uuid();
  S1 uuid := gen_random_uuid(); S2 uuid := gen_random_uuid();
  r jsonb; t text; o1 uuid; o2 uuid; n int; v_ends timestamptz;
BEGIN
  RAISE NOTICE '>>> CONG THU PHI DOT A: BẮT ĐẦU <<<';
  DELETE FROM public.platform_settings WHERE key = 'billing_bank';
  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_ca_' || substr(A::text, 1, 6), '$2a$x', 'QT Thu phí', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name) VALUES
    (B, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Chủ CA'),
    (C, '+84' || (900000000 + (random()*99999999)::int), 'x', 'Thu ngân CA');
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at) VALUES
    (S1, 'C' || substr(S1::text, 1, 7), 'Quán CA', B, 'trial', 'free', now() + interval '2 days'),
    (S2, 'K' || substr(S2::text, 1, 7), 'Quán khác', C, 'trial', 'free', now() + interval '2 days');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (B, S1, 'owner', true), (C, S1, 'cashier', false);

  PERFORM public._ca_ok((SELECT count(*) FROM public.billing_plans WHERE code IN ('pro_1m','pro_6m','pro_12m')
                           AND price_vnd IN (99000, 499000, 899000)) = 3, '1 bảng giá 99k / 499k / 899k');

  -- ── Chủ quán ──
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._ca_claims(B, 'pos');
  r := public.billing_info_v1(S1);
  PERFORM public._ca_ok((r->>'ok')::boolean AND jsonb_array_length(r->'plans') = 3 AND r->'bank' = 'null'::jsonb,
                        '2 chủ quán xem bảng giá; chưa có tài khoản nhận tiền');
  PERFORM public._ca_ok(public.billing_create_order_v1(S1, 'pro_1m')->>'error' = 'BANK_NOT_SET', '3 chưa có tài khoản → chưa tạo đơn');
  PERFORM public._ca_claims(C, 'pos');
  PERFORM public._ca_ok(public.billing_info_v1(S1)->>'error' = 'OWNER_ONLY', '4 thu ngân không xem màn thanh toán');
  PERFORM public._ca_ok(public.billing_create_order_v1(S1, 'pro_1m')->>'error' = 'OWNER_ONLY', '5 thu ngân không tạo đơn');
  t := public._ca_try('SELECT count(*) FROM public.billing_orders');
  PERFORM public._ca_ok(t LIKE 'err:%', '6 không đọc thẳng bảng đơn');
  t := public._ca_try(format('SELECT public.qn_billing_apply_order(%L, %L, %L, 99000, NULL)', gen_random_uuid(), C, 'admin'));
  PERFORM public._ca_ok(t LIKE 'err:%', '7 người đăng nhập quán KHÔNG gọi được hàm gia hạn theo đơn');
  t := public._ca_try(format('SELECT public.admin_billing_mark_paid_v1(%L, 99000, NULL)', gen_random_uuid()));
  PERFORM public._ca_ok(t LIKE 'err:%', '8 không gọi được hàm xác nhận của quản trị');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._ca_claims(B, 'anon');
  t := public._ca_try(format('SELECT public.billing_info_v1(%L)', S1));
  PERFORM public._ca_ok(t LIKE 'err:%', '9 anon + header x-user-id của chủ → bị chặn');
  EXECUTE 'RESET ROLE';

  -- ── Quản trị đặt tài khoản ──
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._ca_claims(A, 'admin');
  PERFORM public._ca_ok(public.admin_billing_set_bank_v1('97043', 'Vietcombank', '0123456789', 'CONG TY')->>'error' = 'BAD_BIN', '10 BIN sai');
  PERFORM public._ca_ok(public.admin_billing_set_bank_v1('970436', 'Vietcombank', '01234x', 'CONG TY')->>'error' = 'BAD_ACCOUNT_NO', '11 số TK sai');
  PERFORM public._ca_ok(public.admin_billing_set_bank_v1('970436', 'Vietcombank', '0123456789', 'Công ty có dấu')->>'error' = 'BAD_ACCOUNT_NAME', '12 tên TK có dấu bị từ chối');
  r := public.admin_billing_set_bank_v1('970436', 'Vietcombank', '0123456789', 'cong ty tnhh quan nho');
  PERFORM public._ca_ok((r->>'ok')::boolean AND r->'bank'->>'account_name' = 'CONG TY TNHH QUAN NHO', '13 lưu tài khoản (tên tự IN HOA)');
  PERFORM public._ca_ok(public.admin_billing_set_plan_v1('pro_1m', 500, true)->>'error' = 'BAD_PRICE', '14 giá quá thấp bị từ chối');
  EXECUTE 'RESET ROLE';

  -- ── Chủ quán tạo đơn ──
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._ca_claims(B, 'pos');
  PERFORM public._ca_ok(public.billing_create_order_v1(S1, 'pro_99m')->>'error' = 'BAD_PLAN', '15 gói lạ');
  r := public.billing_create_order_v1(S1, 'pro_6m');
  o1 := (r->'order'->>'id')::uuid;
  PERFORM public._ca_ok((r->>'ok')::boolean AND r->'order'->>'code' ~ '^QN[A-Z2-9]{6}$' AND (r->'order'->>'amount_vnd')::bigint = 499000
                        AND r->'order'->>'status' = 'pending', '16 tạo đơn Pro 6 tháng 499.000đ, mã QNxxxxxx');
  r := public.billing_create_order_v1(S1, 'pro_1m');
  o2 := (r->'order'->>'id')::uuid;
  PERFORM public._ca_ok(public.billing_order_status_v1(o1)->'order'->>'status' = 'cancelled', '17 tạo đơn mới → đơn chờ cũ bị huỷ');
  r := public.billing_info_v1(S1);
  PERFORM public._ca_ok((r->'pending'->>'id')::uuid = o2 AND r->'bank'->>'bin' = '970436', '18 màn thanh toán thấy đơn chờ + tài khoản');
  PERFORM public._ca_claims(C, 'pos');
  PERFORM public._ca_ok(public.billing_order_status_v1(o2)->>'error' = 'NOT_FOUND', '19 thu ngân không xem đơn');
  EXECUTE 'RESET ROLE';

  -- giá đổi khi đơn đang chờ → đơn giữ giá cũ
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._ca_claims(A, 'admin');
  PERFORM public._ca_ok((public.admin_billing_set_plan_v1('pro_1m', 129000, true)->>'ok')::boolean, '20 đổi giá gói tháng');
  r := public.admin_billing_overview_v1('pending', NULL, 50, 0);
  PERFORM public._ca_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(r->'rows') e WHERE (e->>'id')::uuid = o2
                                 AND (e->>'amount_vnd')::bigint = 99000 AND e->>'store_name' = 'Quán CA'),
                        '21 đơn đang chờ giữ giá lúc tạo; quản trị thấy đơn chờ');
  PERFORM public._ca_ok(public.admin_billing_mark_paid_v1(o2, 50000, NULL)->>'error' = 'AMOUNT_SHORT', '22 thiếu tiền mà không ghi lý do → từ chối');
  PERFORM public._ca_ok(public.admin_billing_mark_paid_v1(o2, 0, NULL)->>'error' = 'BAD_AMOUNT', '23 số tiền 0 bị từ chối');
  r := public.admin_billing_mark_paid_v1(o2, 99000, 'CK Vietcombank');
  v_ends := (r->>'plan_ends_at')::timestamptz;
  PERFORM public._ca_ok((r->>'ok')::boolean AND v_ends BETWEEN now() + interval '2 days' + interval '27 days'
                                                   AND now() + interval '2 days' + interval '32 days',
                        '24 xác nhận đã nhận tiền → Pro thêm 1 tháng NỐI TIẾP sau 2 ngày dùng thử còn lại');
  r := public.admin_billing_mark_paid_v1(o1, 499000, 'Khách CK trước khi đổi gói');
  PERFORM public._ca_ok((r->>'ok')::boolean AND (r->>'plan_ends_at')::timestamptz BETWEEN v_ends + interval '180 days' AND v_ends + interval '186 days',
                        '24b đơn ĐÃ HUỶ nhưng tiền đã vào → vẫn xác nhận được, cộng nối tiếp 6 tháng');
  v_ends := (r->>'plan_ends_at')::timestamptz;
  PERFORM public._ca_ok(public.admin_billing_mark_paid_v1(o2, 99000, NULL)->>'error' = 'ALREADY_PAID', '25 bấm xác nhận lần 2 → không cộng thêm');
  EXECUTE 'RESET ROLE';
  PERFORM public._ca_ok((SELECT plan = 'pro' AND status = 'active' FROM public.stores WHERE id = S1), '26 quán thành Pro, đang dùng');
  PERFORM public._ca_ok((SELECT count(*) = 2 AND bool_and(admin_id = A AND note LIKE 'Đơn QN%')
                           FROM public.admin_store_actions WHERE store_id = S1 AND action = 'payment'), '27 nhật ký 2 dòng thu tiền');

  -- gia hạn tiếp khi Pro còn hạn → cộng nối tiếp
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._ca_claims(B, 'pos');
  o1 := (public.billing_create_order_v1(S1, 'pro_12m')->'order'->>'id')::uuid;
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._ca_claims(A, 'admin');
  r := public.admin_billing_mark_paid_v1(o1, 899000, NULL);
  PERFORM public._ca_ok((r->>'plan_ends_at')::timestamptz BETWEEN v_ends + interval '364 days' AND v_ends + interval '367 days',
                        '28 trả gói năm khi Pro còn hạn → cộng nối tiếp sau hạn cũ');
  r := public.admin_billing_overview_v1('paid', 'Quán CA', 50, 0);
  PERFORM public._ca_ok((r->>'total')::int = 3 AND (r->>'paid_30d_vnd')::bigint >= 1497000, '29 danh sách đã trả + tổng 30 ngày');
  PERFORM public._ca_ok(public.admin_billing_cancel_order_v1(o1)->>'error' = 'NOT_PENDING', '30 không huỷ được đơn đã trả');
  EXECUTE 'RESET ROLE';

  -- quán đang khoá: trả tiền vẫn gia hạn nhưng giữ khoá
  UPDATE public.stores SET status = 'locked' WHERE id = S1;
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._ca_claims(B, 'pos');
  o2 := (public.billing_create_order_v1(S1, 'pro_1m')->'order'->>'id')::uuid;
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._ca_claims(A, 'admin');
  PERFORM public.admin_billing_mark_paid_v1(o2, 129000, NULL);
  r := public.admin_billing_mark_paid_v1(o2, 129000, NULL);
  PERFORM public._ca_ok(r->>'error' = 'ALREADY_PAID', '30b đơn đã trả bấm lại → không cộng');
  EXECUTE 'RESET ROLE';
  PERFORM public._ca_ok((SELECT status = 'locked' FROM public.stores WHERE id = S1), '31 quán đang khoá trả tiền → vẫn khoá (mở tay)');

  -- giới hạn 10 đơn / giờ
  UPDATE public.stores SET status = 'active' WHERE id = S1;
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._ca_claims(B, 'pos');
  FOR n IN 1..10 LOOP r := public.billing_create_order_v1(S1, 'pro_1m'); END LOOP;
  PERFORM public._ca_ok(r->>'error' = 'TOO_MANY', '32 quá 10 đơn / giờ bị chặn');
  EXECUTE 'RESET ROLE';
  PERFORM public._ca_ok((SELECT count(*) FROM public.billing_orders WHERE store_id = S1 AND status = 'pending') = 1,
                        '33 luôn chỉ 1 đơn đang chờ mỗi quán');

  RAISE NOTICE '>>> CONG THU PHI DOT A: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
