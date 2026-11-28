-- ============================================================================
-- TEST: /admin theo dõi tăng trưởng (20261105_admin_tang_truong_v1.sql). Kết thúc ROLLBACK.
-- Chạy được trên dữ liệu thật: so số liệu TRƯỚC / SAU khi thêm dữ liệu thử.
-- ============================================================================
BEGIN;

CREATE OR REPLACE FUNCTION public._tt_ok(p_cond boolean, p_msg text)
RETURNS void LANGUAGE plpgsql AS $f$
BEGIN
  IF p_cond IS NOT TRUE THEN RAISE EXCEPTION '❌ FAIL: %', p_msg; END IF;
  RAISE NOTICE '✅ PASS: %', p_msg;
END
$f$;
CREATE OR REPLACE FUNCTION public._tt_claims(p_user uuid, p_kind text, p_iat_ago int DEFAULT 0)
RETURNS void LANGUAGE plpgsql AS $f$
DECLARE now_s bigint := extract(epoch FROM now())::bigint;
BEGIN
  PERFORM set_config('request.jwt.claims', CASE p_kind
    WHEN 'admin' THEN jsonb_build_object('sub', p_user, 'role', 'qn_admin', 'token_use', 'admin', 'iat', now_s - p_iat_ago, 'exp', now_s + 3600)::text
    WHEN 'pos' THEN jsonb_build_object('sub', p_user, 'role', 'authenticated', 'exp', now_s + 3600)::text
    ELSE '' END, true);
END
$f$;
-- Số trong JSON (NULL → NULL), gọn cho các phép so
CREATE OR REPLACE FUNCTION public._tt_n(j jsonb, VARIADIC p text[]) RETURNS numeric LANGUAGE sql IMMUTABLE AS $f$ SELECT (j #>> p)::numeric $f$;
-- Dòng lứa quán của một tháng
CREATE OR REPLACE FUNCTION public._tt_coh(j jsonb, p_month date) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $f$
  SELECT e FROM jsonb_array_elements(j->'cohorts') e WHERE (e->>'month')::date = p_month $f$;
GRANT EXECUTE ON FUNCTION public._tt_ok(boolean, text), public._tt_claims(uuid, text, int) TO authenticated, anon, qn_admin;

DO $test$
DECLARE
  A uuid := gen_random_uuid();                      -- tài khoản quản trị
  OW1 uuid := gen_random_uuid(); OW2 uuid := gen_random_uuid(); OW3 uuid := gen_random_uuid();
  OW4 uuid := gen_random_uuid(); OW5 uuid := gen_random_uuid(); OW6 uuid := gen_random_uuid();
  -- Tiền
  P_ORDER uuid := gen_random_uuid();   -- trả qua đơn thu phí 499.000 đ / 6 tháng
  P_TWICE uuid := gen_random_uuid();   -- trả 2 lần: chỉ tính lần gần nhất
  P_SHORT uuid := gen_random_uuid();   -- chuyển thiếu: tính số thực nhận
  P_MANUAL uuid := gen_random_uuid();  -- đổi gói tay có tiền, gia hạn sớm
  P_GIFT uuid := gen_random_uuid();    -- Pro tặng, tiền NULL
  P_ZERO uuid := gen_random_uuid();    -- Pro tặng, tiền 0
  P_LIFE uuid := gen_random_uuid();    -- Pro không thời hạn, có tiền
  P_LAPSED uuid := gen_random_uuid();  -- Pro hết hạn
  P_LOCKED uuid := gen_random_uuid();  -- Pro còn hạn nhưng đang khoá
  P_REGIFT uuid := gen_random_uuid();  -- từng trả, về free, rồi được tặng lại: không tính là trả tiền
  P_TEST uuid := gen_random_uuid();    -- quán thử có trả tiền
  P_GIFTAFTER uuid := gen_random_uuid(); -- trả 3 tháng rồi được tặng thêm: còn tính là trả phí tới hết phần đã trả
  P_GIFTOLD uuid := gen_random_uuid();   -- phần đã trả đã hết, đang chạy bằng phần tặng: không còn là trả phí
  P_LIFE2 uuid := gen_random_uuid();     -- trả trọn đời rồi bị đặt hạn: không có kỳ để chia, không được thành MRR 1 tháng
  P_SAMEDATE uuid := gen_random_uuid();  -- ghi thêm tiền mà giữ nguyên ngày hết hạn (QC mục 3C)
  P_SHORTEXT uuid := gen_random_uuid();  -- còn 60 ngày, thu 3 tháng, gõ hạn hôm nay + 90 (QC mục 3H)
  P_LOCKLAP uuid := gen_random_uuid();   -- từng trả, hết hạn, đang khoá
  P_GIFTLAP uuid := gen_random_uuid();   -- được tặng, hết hạn, chưa từng trả
  P_PAYGIFT uuid := gen_random_uuid();   -- đơn thu phí đã hết phần trả, đang chạy bằng phần tặng
  P_OLDRENEW uuid := gen_random_uuid();  -- trả tiếp đã lâu, ngoài 30 ngày
  T_LOCK uuid := gen_random_uuid(); T_EXP uuid := gen_random_uuid();  -- không tính vào "hết dùng thử trong 30 ngày"
  -- Lứa quán
  C_FULL uuid := gen_random_uuid();    -- 70 ngày tuổi: đủ mọi bước
  C_40 uuid := gen_random_uuid();      -- 40 ngày tuổi: chưa tính giữ chân 60 ngày
  C_CXL uuid := gen_random_uuid();     -- chỉ có đơn huỷ
  C_EDGE uuid := gen_random_uuid();    -- 00:30 giờ VN ngày đầu tháng = tháng trước theo UTC
  C_LATE uuid := gen_random_uuid();    -- 70 ngày tuổi, 20 đơn ở ngày 35: không có đơn đầu, không đạt 30 ngày đầu, có giữ chân
  C_D10 uuid := gen_random_uuid();     -- 70 ngày tuổi, 1 đơn ở ngày 10: không thuộc bước nào
  C_D65 uuid := gen_random_uuid();     -- 70 ngày tuổi, 1 đơn ở ngày 65: quá cửa sổ giữ chân
  C_Y15 uuid := gen_random_uuid();     -- 15 ngày tuổi, 25 đơn: đủ tuổi bước 7 ngày, chưa đủ tuổi 30 ngày
  C_Y3 uuid := gen_random_uuid();      -- 3 ngày tuổi, 25 đơn: chưa đủ tuổi bước nào
  C_BEFORE uuid := gen_random_uuid();  -- đơn có ngày trước ngày tạo quán: không tính
  -- Từng cặp sát mốc tuổi, thường cùng tháng: quán đủ tuổi làm mẫu số > 0 nên quán non tuổi có đơn mới lộ ra nếu bị tính nhầm
  C_A8 uuid := gen_random_uuid(); C_A6 uuid := gen_random_uuid();
  C_A31 uuid := gen_random_uuid(); C_A29 uuid := gen_random_uuid();
  C_A61 uuid := gen_random_uuid(); C_A59 uuid := gen_random_uuid();
  -- Danh sách
  L1 uuid := gen_random_uuid(); L2 uuid := gen_random_uuid(); L3 uuid := gen_random_uuid();
  v_vn_now timestamp := now() AT TIME ZONE 'Asia/Ho_Chi_Minh';
  v_m_edge date := (date_trunc('month', v_vn_now) - interval '5 months')::date;  -- xa các quán 40 / 70 ngày tuổi
  v_m_full date; v_m_40 date;
  v_edge_ts timestamptz;
  v_ord uuid; v_oldest timestamptz;
  r0 jsonb; r1 jsonb; r2 jsonb; l jsonb; t text; v_all_ids text[]; v_pages text[] := '{}'; v_i int;
BEGIN
  RAISE NOTICE '>>> ADMIN TANG TRUONG: BẮT ĐẦU <<<';
  v_edge_ts := (v_m_edge::timestamp + interval '30 minutes') AT TIME ZONE 'Asia/Ho_Chi_Minh';
  v_m_full := date_trunc('month', (now() - interval '70 days') AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;
  v_m_40 := date_trunc('month', (now() - interval '40 days') AT TIME ZONE 'Asia/Ho_Chi_Minh')::date;

  INSERT INTO public.platform_admin_accounts (id, username, password_hash, display_name, updated_at)
  VALUES (A, 'qt_tt_' || substr(A::text, 1, 6), '$2a$x', 'QT Tăng trưởng', now() - interval '1 hour');
  INSERT INTO public.user_accounts (id, phone, password_hash, display_name)
  SELECT u, '+84' || (900000000 + (random() * 99999999)::int), 'x', 'Chủ TT ' || n
    FROM unnest(ARRAY[OW1, OW2, OW3, OW4, OW5, OW6], ARRAY['một', 'hai', 'ba', 'bốn', 'năm', 'sáu']) AS x(u, n);

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  r0 := public.admin_growth_v1(false);
  EXECUTE 'RESET ROLE';
  PERFORM public._tt_ok((r0->>'ok')::boolean, '1 vé quản trị gọi được admin_growth_v1');
  PERFORM public._tt_ok(jsonb_array_length(r0->'cohorts') = 12
                        AND (r0->'cohorts'->11->>'month')::date = date_trunc('month', v_vn_now)::date,
                        '2 đủ 12 tháng, tháng cuối là tháng hiện tại giờ VN');
  PERFORM public._tt_ok(_tt_n(r0, 'thresholds', 'real_use_7d') = 20 AND _tt_n(r0, 'thresholds', 'real_use_30d') = 20,
                        '3 trả ngưỡng dùng thật để trang không chép số');

  -- ===== TIỀN =====
  -- Lùi created_at 20 phút: production có trigger chống spam qn_rate_limit_signup (từ 15 quán / 10 phút là chặn)
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, plan_ends_at, trial_ends_at, created_at)
  SELECT id, 'T' || substr(id::text, 1, 7), nm, ow, st, pl, ends, now() + interval '100 days', now() - interval '20 minutes'
    FROM (VALUES
      (P_ORDER, 'TT Trả đơn', OW1, 'trial', 'free', NULL::timestamptz),
      (P_TWICE, 'TT Trả hai lần', OW1, 'trial', 'free', NULL),
      (P_SHORT, 'TT Trả thiếu', OW1, 'trial', 'free', NULL),
      (P_MANUAL, 'TT Trả tay', OW2, 'active', 'pro', now() + interval '60 days'),
      (P_GIFT, 'TT Tặng', OW2, 'active', 'free', NULL),
      (P_ZERO, 'TT Tặng 0 đ', OW2, 'active', 'free', NULL),
      (P_LIFE, 'TT Trọn đời', OW3, 'active', 'free', NULL),
      (P_LAPSED, 'TT Hết hạn', OW3, 'active', 'pro', now() - interval '3 days'),
      (P_LOCKED, 'TT Bị khoá', OW3, 'locked', 'pro', now() + interval '60 days'),
      (P_REGIFT, 'TT Tặng lại', OW4, 'active', 'free', NULL),
      (P_TEST, 'TT Quán thử trả', OW4, 'trial', 'free', NULL),
      (P_GIFTAFTER, 'TT Trả rồi tặng', NULL, 'active', 'free', NULL),
      (P_GIFTOLD, 'TT Hết phần đã trả', NULL, 'active', 'pro', now() + interval '300 days'),
      (P_LIFE2, 'TT Trọn đời đặt hạn', NULL, 'active', 'free', NULL),
      (P_SAMEDATE, 'TT Ghi tiền giữ ngày', NULL, 'active', 'free', NULL),
      (P_SHORTEXT, 'TT Nhập ngày gần', NULL, 'active', 'pro', now() + interval '60 days'),
      (P_LOCKLAP, 'TT Khoá hết hạn', NULL, 'locked', 'pro', now() - interval '3 days'),
      (P_GIFTLAP, 'TT Tặng hết hạn', NULL, 'active', 'pro', now() - interval '3 days'),
      (P_PAYGIFT, 'TT Đơn hết rồi tặng', NULL, 'active', 'pro', now() + interval '300 days'),
      (P_OLDRENEW, 'TT Trả tiếp cũ', NULL, 'trial', 'free', NULL)
    ) v(id, nm, ow, st, pl, ends);
  INSERT INTO public.admin_test_stores (store_id, marked_by) VALUES (P_TEST, A);

  -- Trả qua đúng hàm thật qn_billing_apply_order (service_role), giá gói thật + 6 tháng
  INSERT INTO public.billing_orders (id, code, store_id, plan_code, plan_name, months, amount_vnd, created_by)
  SELECT v_id, 'QN' || code, st, (SELECT code FROM public.billing_plans LIMIT 1), 'Gói thử', mo, amt, OW1
    FROM (VALUES (gen_random_uuid(), 'TTAAA2', P_ORDER, 6, 499000::bigint),
                 (gen_random_uuid(), 'TTAAA3', P_TWICE, 1, 99000),
                 (gen_random_uuid(), 'TTAAA4', P_SHORT, 12, 899000),
                 (gen_random_uuid(), 'TTAAA5', P_TEST, 1, 7000000)) x(v_id, code, st, mo, amt);
  EXECUTE 'SET LOCAL ROLE service_role';
  FOR v_ord, t IN SELECT id, store_id::text FROM public.billing_orders WHERE store_id IN (P_ORDER, P_TWICE, P_SHORT, P_TEST) LOOP
    IF t = P_SHORT::text THEN
      PERFORM public._tt_ok((public.qn_billing_apply_order(v_ord, OW1, 'admin', 600000, 'Đã thoả thuận')->>'ok')::boolean, '4a trả thiếu có ghi chú được nhận');
    ELSE
      PERFORM public._tt_ok((public.qn_billing_apply_order(v_ord, OW1, 'admin', (SELECT amount_vnd FROM public.billing_orders WHERE id = v_ord), NULL)->>'ok')::boolean, '4b trả đúng tiền');
    END IF;
  END LOOP;
  EXECUTE 'RESET ROLE';
  -- Quán trả 2 lần: lần cũ 1 tháng 99.000 lùi 40 ngày (lần trả đầu), rồi lần mới 12 tháng 899.000
  UPDATE public.admin_store_actions SET created_at = now() - interval '40 days' WHERE store_id = P_TWICE;
  UPDATE public.billing_orders SET paid_at = now() - interval '40 days' WHERE store_id = P_TWICE;
  INSERT INTO public.billing_orders (id, code, store_id, plan_code, plan_name, months, amount_vnd, created_by)
  VALUES (gen_random_uuid(), 'QNTTAAA6', P_TWICE, (SELECT code FROM public.billing_plans LIMIT 1), 'Gói năm', 12, 899000, OW1)
  RETURNING id INTO v_ord;
  EXECUTE 'SET LOCAL ROLE service_role';
  PERFORM public.qn_billing_apply_order(v_ord, OW1, 'admin', 899000, NULL);
  EXECUTE 'RESET ROLE';

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  -- Đổi gói tay KHÔNG có số tháng: không đoán, chỉ đếm riêng (QC 2 vòng: đoán kiểu nào cũng sai gấp nhiều lần)
  PERFORM public.admin_store_set_plan_v1(P_MANUAL, 'pro', now() + interval '150 days', 300000, 'Tiền mặt');
  PERFORM public.admin_store_set_plan_v1(P_GIFT, 'pro', now() + interval '30 days', NULL, 'Tặng');
  PERFORM public.admin_store_set_plan_v1(P_ZERO, 'pro', now() + interval '30 days', 0, 'Tặng');
  PERFORM public.admin_store_set_plan_v1(P_LIFE, 'pro', NULL, 5000000, 'Trọn đời');
  PERFORM public.admin_store_set_plan_v1(P_GIFTAFTER, 'pro', now() + interval '90 days', 300000, 'Trả 3 tháng');
  PERFORM public.admin_store_set_plan_v1(P_GIFTAFTER, 'pro', now() + interval '800 days', 0, 'Tặng thêm');
  PERFORM public.admin_store_set_plan_v1(P_LIFE2, 'pro', NULL, 5000000, 'Trọn đời');
  PERFORM public.admin_store_set_plan_v1(P_LIFE2, 'pro', now() + interval '365 days', NULL, 'Đặt lại hạn');
  PERFORM public.admin_store_set_plan_v1(P_SHORTEXT, 'pro', now() + interval '90 days', 300000, 'Thu 3 tháng, gõ hạn gần');
  PERFORM public.admin_store_set_plan_v1(P_SAMEDATE, 'pro', now() + interval '365 days', 450000, 'Đợt 1');
  EXECUTE 'RESET ROLE';
  UPDATE public.admin_store_actions SET created_at = now() - interval '10 days' WHERE store_id = P_SAMEDATE;
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  PERFORM public.admin_store_set_plan_v1(P_SAMEDATE, 'pro', now() + interval '365 days', 450000, 'Đợt 2, giữ nguyên ngày');
  -- Từng trả rồi về free rồi được tặng
  PERFORM public.admin_store_set_plan_v1(P_REGIFT, 'pro', now() + interval '30 days', 200000, 'Trả');
  EXECUTE 'RESET ROLE';
  UPDATE public.admin_store_actions SET created_at = now() - interval '50 days' WHERE store_id = P_REGIFT;
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  PERFORM public.admin_store_set_plan_v1(P_REGIFT, 'free', NULL, NULL, 'Về free');
  EXECUTE 'RESET ROLE';
  UPDATE public.admin_store_actions SET created_at = now() - interval '45 days' WHERE store_id = P_REGIFT AND after->>'plan' = 'free';
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  PERFORM public.admin_store_set_plan_v1(P_REGIFT, 'pro', now() + interval '30 days', NULL, 'Tặng lại');
  EXECUTE 'RESET ROLE';
  -- Tiền cho quán khoá / hết hạn: phải không vào MRR (đã có tiền)
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, amount_vnd, created_at)
  SELECT id, A, 'set_plan', jsonb_build_object('plan', 'free'),
         jsonb_build_object('plan', 'pro', 'plan_ends_at', now() + interval '60 days'), 999000, now() - interval '90 days'
    FROM unnest(ARRAY[P_LAPSED, P_LOCKED, P_LOCKLAP]) id;
  -- Phần đã trả hết từ lâu; trả tiếp đã lâu
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, amount_vnd, created_at) VALUES
    (P_GIFTOLD, A, 'set_plan', jsonb_build_object('plan', 'free'), jsonb_build_object('plan', 'pro', 'plan_ends_at', now() - interval '100 days'), 200000, now() - interval '200 days'),
    (P_OLDRENEW, A, 'set_plan', jsonb_build_object('plan', 'free'), jsonb_build_object('plan', 'pro', 'plan_ends_at', now() - interval '50 days'), 100000, now() - interval '80 days'),
    (P_OLDRENEW, A, 'set_plan', jsonb_build_object('plan', 'pro', 'plan_ends_at', now() - interval '50 days'), jsonb_build_object('plan', 'pro', 'plan_ends_at', now() - interval '20 days'), 100000, now() - interval '40 days');
  -- Phụ thu tay giữ nguyên hạn trên quán đang trả qua đơn: không thay khoản đơn
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, amount_vnd)
  SELECT id, A, 'set_plan', public.qn_store_plan_snapshot(s), public.qn_store_plan_snapshot(s), 50000 FROM public.stores s WHERE id = P_ORDER;
  -- Đơn thu phí đã hết phần trả từ lâu, sau đó được tặng
  INSERT INTO public.billing_orders (id, code, store_id, plan_code, plan_name, months, amount_vnd, status, paid_at, paid_amount_vnd, created_by, created_at)
  VALUES (gen_random_uuid(), 'QNTTAAA8', P_PAYGIFT, (SELECT code FROM public.billing_plans LIMIT 1), 'Đơn cũ', 3, 99000, 'paid', now() - interval '200 days', 99000, OW1, now() - interval '200 days');
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, amount_vnd, created_at)
  VALUES (P_PAYGIFT, A, 'payment', jsonb_build_object('plan', 'free'), jsonb_build_object('plan', 'pro', 'plan_ends_at', now() - interval '100 days'), 99000, now() - interval '200 days');
  -- Đơn cũ đã trả, cùng số tiền, 12 tháng: phải nối đúng đơn theo thời điểm, không phải theo số tiền
  INSERT INTO public.billing_orders (id, code, store_id, plan_code, plan_name, months, amount_vnd, status, paid_at, paid_amount_vnd, created_by)
  VALUES (gen_random_uuid(), 'QNTTAAA9', P_ORDER, (SELECT code FROM public.billing_plans LIMIT 1), 'Đơn cũ cùng tiền', 12, 499000, 'paid', now() - interval '300 days', 499000, OW1);
  -- Đơn đã huỷ trùng thời điểm và số tiền với đơn đã trả của P_ORDER, 12 tháng: không được nối nhầm
  INSERT INTO public.billing_orders (id, code, store_id, plan_code, plan_name, months, amount_vnd, status, paid_at, paid_amount_vnd, created_by)
  VALUES (gen_random_uuid(), 'QNTTAAA7', P_ORDER, (SELECT code FROM public.billing_plans LIMIT 1), 'Đơn huỷ', 12, 499000, 'cancelled', now(), 499000, OW1);
  -- Tự gia hạn miễn phí
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after)
  VALUES (P_ORDER, OW1, 'self_extend', '{}'::jsonb, '{}'::jsonb), (P_ORDER, OW1, 'self_extend', '{}'::jsonb, '{}'::jsonb);
  INSERT INTO public.admin_store_actions (store_id, admin_id, action, before, after, created_at)
  VALUES (P_ORDER, OW1, 'self_extend', '{}'::jsonb, '{}'::jsonb, now() - interval '40 days');
  -- Sắp hết dùng thử trong 30 ngày
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at, created_at)
  VALUES (L1, 'L' || substr(L1::text, 1, 7), 'TT Danh sách B', OW5, 'trial', 'free', now() + interval '20 days', now() - interval '20 minutes'),
         (L2, 'L' || substr(L2::text, 1, 7), 'TT Danh sách A', OW5, 'trial', 'free', now() + interval '200 days', now() - interval '20 minutes'),
         (L3, 'L' || substr(L3::text, 1, 7), 'TT Danh sách C', NULL, 'trial', 'free', now() + interval '200 days', now() - interval '20 minutes'),
         (T_LOCK, 'T' || substr(T_LOCK::text, 1, 7), 'TT Khoá sắp hết thử', NULL, 'locked', 'free', now() + interval '10 days', now() - interval '20 minutes'),
         (T_EXP, 'T' || substr(T_EXP::text, 1, 7), 'TT Đã hết thử', NULL, 'trial', 'free', now() - interval '1 day', now() - interval '20 minutes');
  INSERT INTO public.store_members (user_id, store_id, role, is_owner) VALUES (OW6, L3, 'owner', true);

  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  r1 := public.admin_growth_v1(false);
  r2 := public.admin_growth_v1(true);
  EXECUTE 'RESET ROLE';

  -- MRR CHỈ từ đơn thu phí: 83.167 (499k/6) + 74.917 (899k/12, không phải 99k) + 50.000 (600k thực nhận/12). Khoản ghi tay không đoán.
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'mrr_vnd') - _tt_n(r0, 'money', 'mrr_vnd') = 83167 + 74917 + 50000,
                        '5 MRR: đơn chia đúng tháng, trả 2 lần lấy lần mới, trả thiếu lấy số thực nhận, phụ thu tay không làm đổi; ghi tay, khoá, hết hạn, tặng, trọn đời không tính');
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'paying_stores') - _tt_n(r0, 'money', 'paying_stores') = 3, '6 đúng 3 quán trả qua đơn');
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'manual_paid_stores') - _tt_n(r0, 'money', 'manual_paid_stores') = 6,
                        '6b 6 quán có tiền ghi tay chưa tính vào MRR: trả tay, trả rồi tặng, giữ ngày, hạn gần, hết phần đã trả, trọn đời bị đặt hạn');
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'comp_stores') - _tt_n(r0, 'money', 'comp_stores') = 4,
                        '7 quán tặng: tiền NULL, 0 đ, về free rồi tặng lại, đơn đã hết phần trả rồi được tặng');
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'lifetime_stores') - _tt_n(r0, 'money', 'lifetime_stores') = 1, '8 Pro không thời hạn đếm riêng, không vào MRR');
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'pro_lapsed') - _tt_n(r0, 'money', 'pro_lapsed') = 1,
                        '9 quán từng trả đã hết hạn: quán khoá hết hạn và quán tặng hết hạn không tính');
  -- Thu 30 ngày: 499k + 899k + 600k + tay 300k + 5.000k + 300k + 5.000k + 450k×2 + 300k + phụ thu 50k (99k×2, 200k, 100k×2, 999k×3 là tiền cũ; quán thử bị loại)
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'cash_30d_vnd') - _tt_n(r0, 'money', 'cash_30d_vnd') = 13848000,
                        '10 tiền thực thu 30 ngày, không tính khoản cũ và quán thử');
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  t := public.admin_plan_overview_v1(false)->>'revenue_vnd_30d';
  EXECUTE 'RESET ROLE';
  PERFORM public._tt_ok(t::numeric = _tt_n(r1, 'money', 'cash_30d_vnd'), '11 tiền thực thu khớp "thu 30 ngày" ở tab Gói');
  -- Lần đầu: ORDER, SHORT, MANUAL, LIFE, GIFTAFTER, LIFE2, SAMEDATE, SHORTEXT
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'first_paid_30d') - _tt_n(r0, 'money', 'first_paid_30d') = 8, '12 số quán trả lần đầu trong 30 ngày');
  -- Trả tiếp: chỉ P_TWICE. Ghi thêm tiền giữ nguyên ngày không phải gia hạn; trả tiếp 40 ngày trước ngoài cửa sổ
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'renewed_30d') - _tt_n(r0, 'money', 'renewed_30d') = 1, '13 số quán trả tiếp trong 30 ngày');
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'self_extend_30d') - _tt_n(r0, 'money', 'self_extend_30d') = 2, '14 số lần tự gia hạn miễn phí, không tính lần 40 ngày trước');
  PERFORM public._tt_ok(_tt_n(r1, 'money', 'trial_ending_30d') - _tt_n(r0, 'money', 'trial_ending_30d') = 1,
                        '15 chỉ quán free hết hạn trong 30 ngày tới; quán 200 ngày nữa, quán khoá, quán đã hết hạn không tính');
  PERFORM public._tt_ok(_tt_n(r2, 'money', 'mrr_vnd') - _tt_n(r1, 'money', 'mrr_vnd') = 7000000
                        AND _tt_n(r2, 'money', 'paying_stores') - _tt_n(r1, 'money', 'paying_stores') = 1,
                        '16 bật "Tính cả quán thử" thì cộng thêm quán thử');

  -- ===== KHÁCH (CHỦ QUÁN) =====
  -- OW1..OW5 + OW6 (quán chỉ có thành viên is_owner) = 6 khách mới; OW4 chỉ còn P_REGIFT vì P_TEST là quán thử
  PERFORM public._tt_ok(_tt_n(r1, 'usage', 'customers') - _tt_n(r0, 'usage', 'customers') = 6,
                        '17 chủ nhiều quán đếm 1 khách; quán thiếu chủ trên quán vẫn đếm qua thành viên chủ');
  -- OW1 (3 quán), OW2 (3), OW3 (3), OW5 (2) có từ 2 quán; OW4 chỉ 1 quán vì quán thử bị loại
  PERFORM public._tt_ok(_tt_n(r1, 'usage', 'multi_store_customers') - _tt_n(r0, 'usage', 'multi_store_customers') = 4,
                        '18 đếm chủ có từ 2 quán, không tính quán thử');
  PERFORM public._tt_ok(_tt_n(r2, 'usage', 'multi_store_customers') - _tt_n(r1, 'usage', 'multi_store_customers') = 1,
                        '18b bật quán thử thì chủ đó có đủ 2 quán');

  -- ===== LỨA QUÁN =====
  r0 := NULL;
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  r0 := public.admin_growth_v1(false);
  EXECUTE 'RESET ROLE';
  -- Đáp án tính riêng từ danh sách quán thử, so TỪNG tháng, TỪNG cột (thời điểm tạo, có món, đơn 7 ngày đầu, 20 đơn 30 ngày đầu, giữ chân)
  CREATE TEMP TABLE _tt_fx ON COMMIT DROP AS
    SELECT * FROM (VALUES
      (C_FULL,   OW5,        now() - interval '70 days', true,  true,  true,  true),
      (C_40,     OW6,        now() - interval '40 days', false, false, false, false),  -- đơn ngày 35 nhưng chưa đủ 60 ngày tuổi
      (C_CXL,    OW6,        now() - interval '70 days', false, false, false, false),  -- món đã xoá, đơn đã huỷ
      (C_EDGE,   OW6,        v_edge_ts,                  false, false, false, false),
      (C_LATE,   NULL::uuid, now() - interval '70 days', false, false, false, true),
      (C_D10,    NULL,       now() - interval '70 days', false, false, false, false),
      (C_D65,    NULL,       now() - interval '70 days', false, false, false, false),
      (C_Y15,    NULL,       now() - interval '15 days', false, true,  false, false),
      (C_Y3,     NULL,       now() - interval '3 days',  false, false, false, false),
      (C_BEFORE, NULL,       now() - interval '70 days', false, false, false, false),
      (C_A8,     NULL,       now() - interval '8 days',  false, false, false, false),
      (C_A6,     NULL,       now() - interval '6 days',  false, false, false, false),  -- có đơn hôm qua, chưa đủ 7 ngày tuổi
      (C_A31,    NULL,       now() - interval '31 days', false, false, false, false),
      (C_A29,    NULL,       now() - interval '29 days', false, true,  false, false),  -- 25 đơn, chưa đủ 30 ngày tuổi
      (C_A61,    NULL,       now() - interval '61 days', false, false, false, false),
      (C_A59,    NULL,       now() - interval '59 days', false, false, false, false)   -- có đơn ngày 35, chưa đủ 60 ngày tuổi
    ) v(id, ow, ts, menu, f7, r30, r60);
  INSERT INTO public.stores (id, store_code, name, owner_user_id, status, plan, trial_ends_at, created_at)
  SELECT id, 'C' || substr(id::text, 1, 7), 'TT Lứa ' || substr(id::text, 1, 4), ow, 'trial', 'free', now(), ts FROM _tt_fx;
  INSERT INTO public.products (id, store_id, name) VALUES (gen_random_uuid(), C_FULL, 'Cà phê thử');
  INSERT INTO public.products (id, store_id, name, is_deleted) VALUES (gen_random_uuid(), C_CXL, 'Món đã xoá', true);
  -- C_FULL: 20 đơn trong ngày đầu + 1 đơn ngày 45
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), C_FULL, 1000, 'completed', now() - interval '69 days' + (i || ' hours')::interval FROM generate_series(1, 20) i;
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), C_LATE, 1000, 'completed', now() - interval '35 days' FROM generate_series(1, 20);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), x, 1000, 'completed', now() - interval '10 days' FROM generate_series(1, 25), unnest(ARRAY[C_Y15]) x;
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), C_Y3, 1000, 'completed', now() - interval '1 day' FROM generate_series(1, 25);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), C_A29, 1000, 'completed', now() - interval '28 days' FROM generate_series(1, 25);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at) VALUES
    (gen_random_uuid(), C_A6, 1000, 'completed', now() - interval '1 day'),
    (gen_random_uuid(), C_A59, 1000, 'completed', now() - interval '24 days'),
    (gen_random_uuid(), C_FULL, 1000, 'completed', now() - interval '25 days'),
    (gen_random_uuid(), C_40, 1000, 'completed', now() - interval '5 days'),
    (gen_random_uuid(), C_CXL, 1000, 'cancelled', now() - interval '69 days'),
    (gen_random_uuid(), C_D10, 1000, 'completed', now() - interval '60 days'),
    (gen_random_uuid(), C_D65, 1000, 'completed', now() - interval '5 days'),
    (gen_random_uuid(), C_BEFORE, 1000, 'completed', now() - interval '100 days');
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  r1 := public.admin_growth_v1(false);
  EXECUTE 'RESET ROLE';

  SELECT string_agg(format('%s %s: được %s, đáp án %s', a.month, k.col, k.got, k.want), '; ') INTO t
    FROM (SELECT (e->>'month')::date AS month, e AS now_row FROM jsonb_array_elements(r1->'cohorts') e) a
    JOIN (SELECT (e->>'month')::date AS month, e AS old_row FROM jsonb_array_elements(r0->'cohorts') e) b USING (month)
    CROSS JOIN LATERAL (
      SELECT count(*) AS created,
             count(*) FILTER (WHERE menu) AS has_menu,
             count(*) FILTER (WHERE ts <= now() - interval '7 days') AS m7,
             count(*) FILTER (WHERE ts <= now() - interval '7 days' AND f7) AS f7,
             count(*) FILTER (WHERE ts <= now() - interval '30 days') AS m30,
             count(*) FILTER (WHERE ts <= now() - interval '30 days' AND r30) AS r30,
             count(*) FILTER (WHERE ts <= now() - interval '60 days') AS m60,
             count(*) FILTER (WHERE ts <= now() - interval '60 days' AND r60) AS r60
        FROM _tt_fx WHERE date_trunc('month', ts AT TIME ZONE 'Asia/Ho_Chi_Minh')::date = a.month) x
    CROSS JOIN LATERAL (VALUES
      ('created', x.created), ('has_menu', x.has_menu), ('mature_7d', x.m7), ('first_order_7d', x.f7),
      ('mature_30d', x.m30), ('real_use_30d', x.r30), ('mature_60d', x.m60), ('retained_60d', x.r60)) w(col, want)
    CROSS JOIN LATERAL (SELECT w.col, w.want,
      COALESCE((a.now_row->>w.col)::numeric, 0) - COALESCE((b.old_row->>w.col)::numeric, 0) AS got) k
   WHERE k.got <> k.want;
  PERFORM public._tt_ok(t IS NULL, '19 lứa quán đúng từng tháng, từng cột (tuổi quán, cửa sổ ngày, đơn huỷ, món đã xoá, đơn trước ngày tạo, biên giờ VN): ' || COALESCE(t, 'khớp'));
  PERFORM public._tt_ok(_tt_n(_tt_coh(r1, v_m_edge), 'created') - _tt_n(_tt_coh(r0, v_m_edge), 'created') = 1
                        AND _tt_n(_tt_coh(r1, (v_m_edge - interval '1 month')::date), 'created')
                            = _tt_n(_tt_coh(r0, (v_m_edge - interval '1 month')::date), 'created'),
                        '20 quán tạo 00:30 giờ VN ngày đầu tháng thuộc tháng đó, không thuộc tháng trước');
  PERFORM public._tt_ok(_tt_n(_tt_coh(r1, date_trunc('month', v_vn_now)::date), 'mature_60d') = 0
                        AND _tt_coh(r1, date_trunc('month', v_vn_now)::date)->'retained_60d' = 'null'::jsonb,
                        '21 tháng này chưa quán nào đủ tuổi: trả null, không phải 0');
  -- ===== DÙNG THẬT =====
  r0 := r1;
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), L1, 1000, 'completed', now() - interval '1 day' FROM generate_series(1, 20);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), L2, 1000, 'completed', now() - interval '1 day' FROM generate_series(1, 19);
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), L2, 1000, 'completed', now() - interval '30 days' FROM generate_series(1, 5);  -- ngoài 7 ngày
  INSERT INTO public.orders (id, store_id, total_amount, status, created_at)
  SELECT gen_random_uuid(), L3, 1000, 'cancelled', now() - interval '1 day' FROM generate_series(1, 30);
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  r1 := public.admin_growth_v1(false);
  EXECUTE 'RESET ROLE';
  PERFORM public._tt_ok(_tt_n(r1, 'usage', 'real_use_7d') - _tt_n(r0, 'usage', 'real_use_7d') = 1,
                        '28 dùng thật: đủ 20 đơn mới tính; 19 đơn cộng 5 đơn cũ không tính; đơn huỷ không tính');

  -- ===== DANH SÁCH V2 =====
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  l := public.admin_store_list_v2('all', 'TT Danh sách', false, 50, 0, 'orders_7d', 'asc');
  PERFORM public._tt_ok(l->'rows'->0->>'id' = L3::text AND l->'rows'->2->>'id' = L1::text, '29 sắp tăng dần theo đơn 7 ngày');
  l := public.admin_store_list_v2('all', 'TT Danh sách', false, 50, 0, 'name', 'desc');
  PERFORM public._tt_ok(l->'rows'->0->>'id' = L3::text AND l->'rows'->2->>'id' = L2::text, '30 sắp theo tên giảm dần');
  l := public.admin_store_list_v2('all', 'TT Danh sách', false, 50, 0, 'last_order_at', 'desc');
  PERFORM public._tt_ok(l->'rows'->2->>'id' = L3::text, '30b sắp đơn gần nhất giảm dần: quán chưa có đơn xuống cuối');
  l := public.admin_store_list_v2('all', 'TT Danh sách', false, 50, 0, 'last_order_at', 'asc');
  PERFORM public._tt_ok(l->'rows'->2->>'id' = L3::text, '30c sắp đơn gần nhất tăng dần: quán chưa có đơn vẫn xuống cuối');
  -- Sắp trên TOÀN BỘ danh sách: đáp án tính bằng quyền quản trị database, vì qn_admin không đọc được bảng
  EXECUTE 'RESET ROLE';
  SELECT s.id::text INTO t FROM (
    SELECT st.id, st.created_at, (SELECT count(*) FROM public.orders o WHERE o.store_id = st.id AND o.status = 'completed'
                                   AND o.created_at > now() - interval '7 days') n
      FROM public.stores st WHERE NOT EXISTS (SELECT 1 FROM public.admin_test_stores x WHERE x.store_id = st.id)) s
   ORDER BY s.n DESC, s.created_at DESC, s.id LIMIT 1;
  SELECT min(st.created_at) INTO v_oldest FROM public.stores st
   WHERE NOT EXISTS (SELECT 1 FROM public.admin_test_stores x WHERE x.store_id = st.id);
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin');
  l := public.admin_store_list_v2('all', NULL, false, 3, 0, 'orders_7d', 'desc');
  PERFORM public._tt_ok(l->'rows'->0->>'id' = t, '31 sắp giảm dần lấy đúng quán đứng đầu toàn bộ');
  l := public.admin_store_list_v2('all', NULL, false, 3, 0, 'created_at', 'asc');
  PERFORM public._tt_ok((l->'rows'->0->>'created_at')::timestamptz = v_oldest,
                        '32 "ngày tạo cũ → mới" lấy đúng quán cũ nhất toàn bộ, không chỉ trong trang');
  -- Phân trang không trùng, không sót
  v_i := 0;
  LOOP
    l := public.admin_store_list_v2('all', 'TT ', false, 4, v_i, 'orders_7d', 'desc');
    EXIT WHEN jsonb_array_length(l->'rows') = 0;
    v_pages := v_pages || ARRAY(SELECT e->>'id' FROM jsonb_array_elements(l->'rows') e);
    v_i := v_i + 4;
  END LOOP;
  PERFORM public._tt_ok(cardinality(v_pages) = (l->>'total')::int
                        AND (SELECT count(DISTINCT x) FROM unnest(v_pages) x) = (l->>'total')::int,
                        '33 phân trang đủ, không trùng dù nhiều quán cùng số đơn');
  l := public.admin_store_list_v2('all', NULL, false, 50, 2147483640);
  PERFORM public._tt_ok((l->>'ok')::boolean AND jsonb_array_length(l->'rows') = 0, '33b trang rất xa không lỗi tràn số');
  l := public.admin_store_list_v2('all', 'TT Danh sách', false, 50, 0, 'bad; DROP TABLE stores', 'desc');
  PERFORM public._tt_ok(l->>'error' = 'BAD_SORT', '34 cột sắp xếp lạ bị từ chối');
  l := public.admin_store_list_v2('all', 'TT Danh sách', false, 50, 0, 'name', 'sideways');
  PERFORM public._tt_ok(l->>'error' = 'BAD_SORT', '35 chiều sắp xếp lạ bị từ chối');
  -- Chủ quán
  l := public.admin_store_list_v2('all', 'TT Danh sách', false, 50, 0, 'name', 'asc');
  PERFORM public._tt_ok((SELECT (e->>'owner_store_count')::int FROM jsonb_array_elements(l->'rows') e WHERE e->>'id' = L1::text) >= 2
                        AND (SELECT e->>'owner_name' FROM jsonb_array_elements(l->'rows') e WHERE e->>'id' = L3::text) = 'Chủ TT sáu'
                        AND (SELECT e->>'owner_user_id' FROM jsonb_array_elements(l->'rows') e WHERE e->>'id' = L3::text) = OW6::text,
                        '36 có số quán của chủ; quán thiếu chủ trên quán lấy thành viên chủ');
  l := public.admin_store_list_v2('all', 'Chủ TT năm', false, 50, 0);
  PERFORM public._tt_ok((l->>'total')::int >= 2, '37 ô tìm kiếm tìm được theo tên chủ');
  l := public.admin_store_list_v2('all', NULL, false, 50, 0, 'name', 'asc', OW5);
  PERFORM public._tt_ok(NOT EXISTS (SELECT 1 FROM jsonb_array_elements(l->'rows') e WHERE e->>'owner_user_id' <> OW5::text)
                        AND (l->>'total')::int = 3, '38 lọc đúng các quán của một chủ');
  l := public.admin_store_list_v2('all', NULL, false, 50, 0, 'name', 'asc', OW4);
  PERFORM public._tt_ok((l->>'total')::int = 1 AND (l->'rows'->0->>'owner_store_count')::int = 1, '39 quán thử không tính vào số quán của chủ');
  l := public.admin_store_list_v2('all', NULL, true, 50, 0, 'name', 'asc', OW4);
  PERFORM public._tt_ok((l->>'total')::int = 2 AND (l->'rows'->0->>'owner_store_count')::int = 2, '39b bật quán thử thì tính');
  l := public.admin_store_list_v2('test', NULL, false, 50, 0);
  PERFORM public._tt_ok(EXISTS (SELECT 1 FROM jsonb_array_elements(l->'rows') e WHERE e->>'id' = P_TEST::text), '40 bộ lọc Quán thử vẫn chạy');
  EXECUTE 'RESET ROLE';

  -- ===== QUYỀN =====
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public._tt_claims(OW1, 'pos');
  BEGIN PERFORM public.admin_growth_v1(false); t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._tt_ok(t = 'denied', '41 vé quán không gọi được admin_growth_v1');
  BEGIN PERFORM public.admin_store_list_v2('all'); t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._tt_ok(t = 'denied', '42 vé quán không gọi được admin_store_list_v2');
  EXECUTE 'RESET ROLE';
  EXECUTE 'SET LOCAL ROLE anon';
  PERFORM public._tt_claims(NULL, '');
  BEGIN PERFORM public.admin_growth_v1(false); t := 'ok'; EXCEPTION WHEN insufficient_privilege THEN t := 'denied'; END;
  PERFORM public._tt_ok(t = 'denied', '43 khoá công khai không gọi được');
  EXECUTE 'RESET ROLE';
  -- Vé cấp trước lần đổi mật khẩu / không phải quản trị → FORBIDDEN dù có vai trò qn_admin
  EXECUTE 'SET LOCAL ROLE qn_admin';
  PERFORM public._tt_claims(A, 'admin', 7200);
  PERFORM public._tt_ok(public.admin_growth_v1(false)->>'error' = 'FORBIDDEN', '44 vé quản trị đã thu hồi bị chặn (growth)');
  PERFORM public._tt_ok(public.admin_store_list_v2('all')->>'error' = 'FORBIDDEN', '45 vé quản trị đã thu hồi bị chặn (list)');
  EXECUTE 'RESET ROLE';
  PERFORM public._tt_ok(NOT has_function_privilege('anon', 'public.admin_growth_v1(boolean)', 'execute')
                        AND NOT has_function_privilege('authenticated', 'public.admin_growth_v1(boolean)', 'execute')
                        AND NOT has_function_privilege('service_role', 'public.admin_growth_v1(boolean)', 'execute'),
                        '46 chỉ qn_admin có quyền (growth)');
  PERFORM public._tt_ok(NOT has_function_privilege('anon', 'public.admin_store_list_v2(text,text,boolean,int,int,text,text,uuid)', 'execute')
                        AND NOT has_function_privilege('authenticated', 'public.admin_store_list_v2(text,text,boolean,int,int,text,text,uuid)', 'execute')
                        AND NOT has_function_privilege('service_role', 'public.admin_store_list_v2(text,text,boolean,int,int,text,text,uuid)', 'execute'),
                        '46b chỉ qn_admin có quyền (list)');
  PERFORM public._tt_ok((SELECT provolatile = 's' FROM pg_proc WHERE oid = 'public.admin_growth_v1(boolean)'::regprocedure)
                        AND (SELECT provolatile = 's' FROM pg_proc WHERE proname = 'admin_store_list_v2' AND pronamespace = 'public'::regnamespace),
                        '47 hai hàm là STABLE: Postgres chặn mọi lệnh ghi bên trong');
  PERFORM public._tt_ok(to_regproc('public.admin_store_list_v1') IS NOT NULL, '48 giữ admin_store_list_v1 cho trang cũ khi hoàn tác');

  RAISE NOTICE '>>> ADMIN TANG TRUONG: TẤT CẢ PASS <<<';
END
$test$;

ROLLBACK;
