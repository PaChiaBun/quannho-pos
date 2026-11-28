-- ============================================================================
-- SQL INTEGRATION TEST SUITE: QR Order V4 (Quán Nhỏ POS)
-- Execution Target: Disposable Staging Database (PostgreSQL / Supabase)
-- Rules: Real RPC calls, Financial Engine Verification, Atomic Idempotency
-- ============================================================================

BEGIN;

DO $$
DECLARE
  v_store_id uuid := gen_random_uuid();
  v_other_store_id uuid := gen_random_uuid();
  v_owner_uid uuid := gen_random_uuid();
  v_manager_uid uuid := gen_random_uuid();
  v_cashier_uid uuid := gen_random_uuid();
  v_waiter_uid uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();

  v_owner_sm_id uuid := gen_random_uuid();
  v_manager_sm_id uuid := gen_random_uuid();
  v_cashier_sm_id uuid := gen_random_uuid();
  v_waiter_sm_id uuid := gen_random_uuid();

  v_table_id uuid := gen_random_uuid();
  v_table2_id uuid := gen_random_uuid();
  v_prod_food_id uuid := gen_random_uuid();
  v_prod_drink_id uuid := gen_random_uuid();
  v_prod_water_id uuid := gen_random_uuid();
  v_topping_pearl_id uuid := gen_random_uuid();

  v_chan_res jsonb;
  v_table_code text;
  v_counter_code text;

  v_submit_res jsonb;
  v_req1_id uuid;
  v_req2_id uuid;
  v_req_counter1_id uuid;
  v_req_counter2_id uuid;

  v_kitchen1_res jsonb;
  v_kitchen2_res jsonb;
  v_kitchen_conflict_res jsonb;
  v_settle_res jsonb;
  v_settle_replay_res jsonb;
  v_settle_conflict_res jsonb;
  v_pay1_res jsonb;
  v_pay_conflict_res jsonb;

  v_order_count integer;
  v_finance_count integer;
  v_manual_item_id uuid;
  v_session_id uuid;
  v_session2_id uuid;
  v_cust record;
  v_fin record;
BEGIN
  RAISE NOTICE '>>> BẮT ĐẦU CHẠY BỘ KIỂM THỬ TÍCH HỢP QR ORDER V4 (STAGING) <<<';

  -- ── 1. SETUP FIXTURES ───────────────────────────────────────────────────────
  INSERT INTO public.stores (id, name, created_at)
  VALUES
    (v_store_id, 'Quán Nhỏ Test Store A', now()),
    (v_other_store_id, 'Quán Nhỏ Test Store B', now());

  INSERT INTO public.user_accounts (id, phone, display_name)
  VALUES
    (v_owner_uid, '0900000001', 'Chủ Quán Owner'),
    (v_manager_uid, '0900000002', 'Quản Lý Manager'),
    (v_cashier_uid, '0900000003', 'Thu Ngân Cashier'),
    (v_waiter_uid, '0900000004', 'Phục Vụ Waiter');

  INSERT INTO public.store_members (id, store_id, user_id, role, created_at)
  VALUES
    (v_owner_sm_id, v_store_id, v_owner_uid, 'owner', now()),
    (v_manager_sm_id, v_store_id, v_manager_uid, 'manager', now()),
    (v_cashier_sm_id, v_store_id, v_cashier_uid, 'cashier', now()),
    (v_waiter_sm_id, v_store_id, v_waiter_uid, 'waiter', now());

  INSERT INTO public.app_settings (id, store_id, key, value)
  VALUES
    (gen_random_uuid(), v_store_id, 'action_perms_cashier', '["pos.checkout"]'),
    (gen_random_uuid(), v_store_id, 'loyalty_rate', '10000'),
    (gen_random_uuid(), v_store_id, 'loyalty_redeem_rate', '1000'),
    (gen_random_uuid(), v_store_id, 'stamp_threshold', '10');

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupons') THEN
    INSERT INTO public.coupons (id, store_id, code, discount_type, value, min_order_amount, is_active, created_at)
    VALUES (gen_random_uuid(), v_store_id, 'VOUCHER20K', 'fixed', 18000, 50000, true, now());
  END IF;

  INSERT INTO public.customers (id, store_id, name, phone, loyalty_pts, total_spent, visit_count, stamp_count, stamp_total)
  VALUES
    (v_customer_id, v_store_id, 'Khách Hàng Test', '0912345678', 5, 100000, 2, 2, 2);

  INSERT INTO public.ban_dining_tables (id, store_id, label, is_active)
  VALUES
    (v_table_id, v_store_id, 'Bàn 01', true),
    (v_table2_id, v_store_id, 'Bàn 02', true);

  INSERT INTO public.products (id, store_id, name, category, sell_price, cost_price_latest, stock_qty, is_topping, is_active, is_deleted)
  VALUES
    (v_prod_food_id, v_store_id, 'Cơm Chiên Hải Sản', 'Món Chính', 65000, 30000, 50, false, true, false),
    (v_prod_drink_id, v_store_id, 'Trà Sữa Oolong', 'Đồ uống', 35000, 12000, 100, false, true, false),
    (v_prod_water_id, v_store_id, 'Nước Suối', 'Đồ uống', 15000, 5000, 100, false, true, false),
    (v_topping_pearl_id, v_store_id, 'Trân Châu Trắng', 'Topping', 10000, 3000, 200, true, true, false);

  -- Link topping Trân Châu Trắng với Trà Sữa Oolong
  INSERT INTO public.product_topping_links (store_id, product_id, topping_id, created_at)
  VALUES (v_store_id, v_prod_drink_id, v_topping_pearl_id, now());


  -- ── 2. TEST PRIVILEGES & SECURITY GRANTS ─────────────────────────────────────
  ASSERT has_function_privilege('anon', 'public.get_qr_channel_info_v4(text)', 'EXECUTE'),
    'ERROR: anon must have EXECUTE on get_qr_channel_info_v4';
  ASSERT has_function_privilege('anon', 'public.submit_qr_order_v4(text, jsonb, text, text, text)', 'EXECUTE'),
    'ERROR: anon must have EXECUTE on submit_qr_order_v4';

  ASSERT NOT has_function_privilege('anon', 'public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text)', 'EXECUTE'),
    'ERROR: anon MUST NOT have EXECUTE on send_qr_order_to_kitchen_v4';
  ASSERT NOT has_function_privilege('public', 'public.send_qr_order_to_kitchen_v4(uuid, uuid, text, text)', 'EXECUTE'),
    'ERROR: public MUST NOT have EXECUTE on send_qr_order_to_kitchen_v4';

  ASSERT NOT has_function_privilege('anon', 'public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric)', 'EXECUTE'),
    'ERROR: anon MUST NOT have EXECUTE on settle_ban_session_v4';
  ASSERT NOT has_function_privilege('public', 'public.settle_ban_session_v4(uuid, uuid, text, text, uuid, integer, numeric, text, numeric)', 'EXECUTE'),
    'ERROR: public MUST NOT have EXECUTE on settle_ban_session_v4';

  RAISE NOTICE '✓ Test 1: Function Privileges & Least Privilege Security Grants PASS';


  -- ── 3. TEST CHANNEL CREATION ─────────────────────────────────────────────────
  PERFORM set_config('request.jwt.claim.sub', v_owner_uid::text, true);

  v_chan_res := public.manage_qr_channel_v4(v_store_id, 'TABLE_SHARED', true, 'PAY_BEFORE_KITCHEN');
  ASSERT (v_chan_res->>'success')::boolean = true, 'ERROR: manage_qr_channel_v4 table failed';
  v_table_code := v_chan_res->'data'->>'channel_code';

  v_chan_res := public.manage_qr_channel_v4(v_store_id, 'COUNTER_TAKEAWAY', true, 'PAY_BEFORE_KITCHEN');
  ASSERT (v_chan_res->>'success')::boolean = true, 'ERROR: manage_qr_channel_v4 counter failed';
  v_counter_code := v_chan_res->'data'->>'channel_code';

  RAISE NOTICE '✓ Test 2: Channel Creation & Unique Codes PASS';


  -- ── 4. TEST SUBMIT QR ORDERS (TABLE_SHARED) ──────────────────────────────────
  PERFORM set_config('request.jwt.claim.sub', '', true);

  -- Đơn QR 1: Trà Sữa (35k) + Trân Châu (10k) x 2 = 90k
  v_submit_res := public.submit_qr_order_v4(
    v_table_code,
    jsonb_build_array(
      jsonb_build_object(
        'product_id', v_prod_drink_id,
        'quantity', 2,
        'modifiers_json', jsonb_build_array(jsonb_build_object('id', v_topping_pearl_id, 'quantity', 1))
      )
    ),
    'B01',
    'idemp-table-01',
    '1111111111111111111111111111111111111111111111111111111111111111'
  );
  ASSERT (v_submit_res->>'success')::boolean = true, 'ERROR: Order 1 submit failed';
  v_req1_id := (v_submit_res->'data'->>'request_id')::uuid;

  -- Đơn QR 2: Cơm Chiên (65k) x 1 = 65k
  v_submit_res := public.submit_qr_order_v4(
    v_table_code,
    jsonb_build_array(
      jsonb_build_object('product_id', v_prod_food_id, 'quantity', 1)
    ),
    'B01',
    'idemp-table-02',
    '2222222222222222222222222222222222222222222222222222222222222222'
  );
  ASSERT (v_submit_res->>'success')::boolean = true, 'ERROR: Order 2 submit failed';
  v_req2_id := (v_submit_res->'data'->>'request_id')::uuid;

  RAISE NOTICE '✓ Test 3: Submit QR Orders PASS';


  -- ── 5. TEST SEND TO KITCHEN WITH ATOMIC IDEMPOTENCY ──────────────────────────
  PERFORM set_config('request.jwt.claim.sub', v_waiter_uid::text, true);

  PERFORM public.assign_qr_order_table_v4(v_req1_id, v_table_id, v_store_id);
  v_kitchen1_res := public.send_qr_order_to_kitchen_v4(v_req1_id, v_store_id, 'k-idemp-01', 'Ghi chú đơn 1');
  ASSERT (v_kitchen1_res->>'success')::boolean = true, 'ERROR: Send to kitchen failed';
  v_session_id := (v_kitchen1_res->'data'->>'session_id')::uuid;

  -- 5.1. Replay cùng key -> Trả kết quả cũ, is_replay = true
  v_kitchen1_res := public.send_qr_order_to_kitchen_v4(v_req1_id, v_store_id, 'k-idemp-01', 'Ghi chú đơn 1');
  ASSERT (v_kitchen1_res->>'success')::boolean = true, 'ERROR: Kitchen replay must succeed';
  ASSERT (v_kitchen1_res->'data'->>'is_replay')::boolean = true, 'ERROR: is_replay must be true';

  -- 5.2. Cùng key dùng cho request khác -> IDEMPOTENCY_CONFLICT
  PERFORM public.assign_qr_order_table_v4(v_req2_id, v_table_id, v_store_id);
  v_kitchen_conflict_res := public.send_qr_order_to_kitchen_v4(v_req2_id, v_store_id, 'k-idemp-01', 'Ghi chú đơn 2');
  ASSERT (v_kitchen_conflict_res->>'success')::boolean = false, 'ERROR: Kitchen conflict MUST fail';
  ASSERT (v_kitchen_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT', 'ERROR: Expected IDEMPOTENCY_CONFLICT';

  -- Gửi bếp Đơn QR 2 với key riêng
  v_kitchen2_res := public.send_qr_order_to_kitchen_v4(v_req2_id, v_store_id, 'k-idemp-02', 'Ghi chú đơn 2');
  ASSERT (v_kitchen2_res->>'success')::boolean = true, 'ERROR: Send order 2 failed';

  RAISE NOTICE '✓ Test 4: Send To Kitchen Idempotency & Conflict Guard PASS';


  -- ── 6. TEST BÀN HỖN HỢP VÀ TÍNH TOÁN TÀI CHÍNH AUTHORITATIVE TRÊN SERVER ─────
  -- Thêm 1 món Nước Suối (15k) trực tiếp vào ban_session_items
  v_manual_item_id := gen_random_uuid();
  INSERT INTO public.ban_session_items (
    id, store_id, session_id, product_id, product_name, unit_price, price,
    quantity, subtotal, kitchen_status, added_at, note, modifiers_json
  ) VALUES (
    v_manual_item_id, v_store_id, v_session_id, v_prod_water_id, 'Nước Suối',
    15000, 15000, 1, 15000, 'da_gui', now(), 'Khách gọi thêm', '[]'
  );

  PERFORM set_config('request.jwt.claim.sub', v_cashier_uid::text, true);

  -- Quyết toán bàn hỗn hợp với discount = 20k, surcharge = 5k, points_used = 2
  -- Raw Subtotal: 90k (QR1) + 65k (QR2) + 15k (Manual) = 170,000đ
  -- Final Total = 170k - 20k (discount) + 5k (surcharge) = 155,000đ
  -- Points earned = floor(155000 / 10000) = 15 points
  v_settle_res := public.settle_ban_session_v4(
    v_session_id,
    v_store_id,
    'cash',
    'settle-idemp-01',
    v_customer_id,
    2,      -- points_used
    20000,  -- discount
    'VOUCHER20K', -- coupon_code
    5000    -- surcharge
  );

  ASSERT (v_settle_res->>'success')::boolean = true, 'ERROR: Settle mixed table failed';
  ASSERT (v_settle_res->'data'->>'subtotal')::numeric = 170000, 'ERROR: Subtotal must be 170,000đ';
  ASSERT (v_settle_res->'data'->>'discount')::numeric = 20000, 'ERROR: Discount must be 20,000đ';
  ASSERT (v_settle_res->'data'->>'surcharge')::numeric = 5000, 'ERROR: Surcharge must be 5,000đ';
  ASSERT (v_settle_res->'data'->>'total_amount')::numeric = 155000, 'ERROR: Total amount must be exactly 155,000đ';
  ASSERT (v_settle_res->'data'->>'pts_earned')::numeric = 15, 'ERROR: Points earned must be 15';

  -- Replay check: gọi lại cùng key -> trả đúng dữ liệu cũ, không duplicate
  v_settle_replay_res := public.settle_ban_session_v4(
    v_session_id, v_store_id, 'cash', 'settle-idemp-01', v_customer_id, 2, 20000, 'VOUCHER20K', 5000
  );
  ASSERT (v_settle_replay_res->>'success')::boolean = true, 'ERROR: Replay settlement failed';
  ASSERT (v_settle_replay_res->'data'->>'is_replay')::boolean = true, 'ERROR: is_replay must be true';
  ASSERT (v_settle_replay_res->'data'->>'total_amount')::numeric = 155000, 'ERROR: Replay total amount mismatch';

  -- Kiểm tra 3 canonical orders trong session (2 qr_table + 1 ban_manual)
  SELECT count(*) INTO v_order_count FROM public.ban_session_orders WHERE session_id = v_session_id;
  ASSERT v_order_count = 3, 'ERROR: Exactly 3 canonical orders must exist for mixed table';

  -- Kiểm tra tất cả 3 order đều status = 'completed'
  SELECT count(*) INTO v_order_count
  FROM public.orders o
  JOIN public.ban_session_orders bso ON bso.order_id = o.id
  WHERE bso.session_id = v_session_id AND o.status = 'completed';
  ASSERT v_order_count = 3, 'ERROR: All 3 orders must be marked completed';

  -- Kiểm tra đúng 1 bản ghi sổ quỹ finance_records với số tiền đúng 155,000đ
  SELECT count(*), sum(amount) INTO v_finance_count, v_fin.amount FROM public.finance_records WHERE store_id = v_store_id AND type = 'income';
  ASSERT v_finance_count = 1, 'ERROR: Exactly 1 finance record must be created for settlement';
  ASSERT v_fin.amount = 155000, 'ERROR: Finance record amount must be 155,000đ';

  -- Kiểm tra khách hàng: điểm tích luỹ = 5 (cũ) + 15 (earned) - 2 (used) = 18 điểm
  SELECT loyalty_pts, total_spent, visit_count INTO v_cust FROM public.customers WHERE id = v_customer_id;
  ASSERT v_cust.loyalty_pts = 18, 'ERROR: Customer loyalty points must be 18';
  ASSERT v_cust.visit_count = 3, 'ERROR: Customer visit count must be 3';

  RAISE NOTICE '✓ Test 5: Financial Engine, Authoritative Server Total, Mixed Table & Customer Points PASS';


  -- ── 7. TEST FAIL-CLOSED FINANCIAL VALIDATION & ERROR CODES ─────────────────
  DECLARE
    v_fc_res jsonb;
    v_sess_fail_id uuid := gen_random_uuid();
    v_sess_valid_id uuid := gen_random_uuid();
    v_coupon_redempt_count integer;
    v_b_settle integer;
    v_b_fin integer;
    v_b_stock integer;
    v_b_loyalty integer;
    v_b_redempt integer;
    v_b_orders integer;
    v_b_items integer;
    v_b_bso integer;
    v_b_bsoi integer;
    v_a_settle integer;
    v_a_fin integer;
    v_a_stock integer;
    v_a_loyalty integer;
    v_a_redempt integer;
    v_a_orders integer;
    v_a_items integer;
    v_a_bso integer;
    v_a_bsoi integer;
  BEGIN
    INSERT INTO public.ban_sessions (id, store_id, table_id, status, opened_at, total_amount, guest_count)
    VALUES (v_sess_fail_id, v_store_id, v_table2_id, 'open', now(), 65000, 1);

    INSERT INTO public.ban_session_items (id, store_id, session_id, product_id, product_name, unit_price, price, quantity, subtotal, kitchen_status, added_at)
    VALUES (gen_random_uuid(), v_store_id, v_sess_fail_id, v_prod_food_id, 'Cơm Chiên', 65000, 65000, 1, 65000, 'da_gui', now());

    -- Snapshot counts before failure attempts for zero side-effect verification
    SELECT count(*) INTO v_b_settle FROM public.payment_settlements WHERE store_id = v_store_id;
    SELECT count(*) INTO v_b_fin FROM public.finance_records WHERE store_id = v_store_id;
    SELECT count(*) INTO v_b_stock FROM public.stock_movements WHERE store_id = v_store_id;
    SELECT count(*) INTO v_b_loyalty FROM public.loyalty_transactions WHERE store_id = v_store_id;
    SELECT count(*) INTO v_b_redempt FROM public.qr_coupon_redemptions WHERE store_id = v_store_id;
    SELECT count(*) INTO v_b_orders FROM public.orders WHERE store_id = v_store_id;
    SELECT count(*) INTO v_b_items FROM public.order_items oi JOIN public.orders o ON o.id = oi.order_id WHERE o.store_id = v_store_id;
    SELECT count(*) INTO v_b_bso FROM public.ban_session_orders WHERE store_id = v_store_id;
    SELECT count(*) INTO v_b_bsoi FROM public.ban_session_order_items WHERE store_id = v_store_id;

    -- 7.1. Points âm -> INVALID_POINTS
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-01', v_customer_id, -5);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_POINTS', 'ERROR: Expected INVALID_POINTS for negative points';

    -- 7.2. Points > 0 nhưng không truyền customer_id -> CUSTOMER_REQUIRED
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-02', NULL, 5);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'CUSTOMER_REQUIRED', 'ERROR: Expected CUSTOMER_REQUIRED when customer is null';

    -- 7.3. Customer không thuộc store -> CUSTOMER_NOT_FOUND or PERMISSION_DENIED
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_other_store_id, 'cash', 'fc-key-03', v_customer_id, 2);
    ASSERT (v_fc_res->>'success')::boolean = false, 'ERROR: Other store customer MUST fail';

    -- 7.4. Điểm vượt quá số dư (Khách có 18 điểm, yêu cầu 100 điểm) -> INSUFFICIENT_POINTS
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-04', v_customer_id, 100);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INSUFFICIENT_POINTS', 'ERROR: Expected INSUFFICIENT_POINTS';

    -- 7.5. Thiếu loyalty_redeem_rate khi dùng điểm -> INVALID_LOYALTY_CONFIG
    DELETE FROM public.app_settings WHERE store_id = v_store_id AND key = 'loyalty_redeem_rate';
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-04a', v_customer_id, 2);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_LOYALTY_CONFIG', 'ERROR: Expected INVALID_LOYALTY_CONFIG for missing rate';

    -- 7.6. Rate không phải số -> INVALID_LOYALTY_CONFIG
    INSERT INTO public.app_settings (id, store_id, key, value) VALUES (gen_random_uuid(), v_store_id, 'loyalty_redeem_rate', 'not_a_number');
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-04b', v_customer_id, 2);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_LOYALTY_CONFIG', 'ERROR: Expected INVALID_LOYALTY_CONFIG for non-numeric rate';

    -- 7.7. Rate bằng 0 hoặc âm -> INVALID_LOYALTY_CONFIG
    UPDATE public.app_settings SET value = '0' WHERE store_id = v_store_id AND key = 'loyalty_redeem_rate';
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-04c', v_customer_id, 2);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_LOYALTY_CONFIG', 'ERROR: Expected INVALID_LOYALTY_CONFIG for 0 rate';

    UPDATE public.app_settings SET value = '-5000' WHERE store_id = v_store_id AND key = 'loyalty_redeem_rate';
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-04d', v_customer_id, 2);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_LOYALTY_CONFIG', 'ERROR: Expected INVALID_LOYALTY_CONFIG for negative rate';

    -- Khôi phục rate hợp lệ cho các test tiếp theo
    UPDATE public.app_settings SET value = '10000' WHERE store_id = v_store_id AND key = 'loyalty_redeem_rate';

    -- 7.8. Coupon không tồn tại -> COUPON_NOT_FOUND
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05', NULL, 0, 0, 'NONEXISTENT_COUPON');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'COUPON_NOT_FOUND', 'ERROR: Expected COUPON_NOT_FOUND';

    -- Tạo các coupons đặc biệt để kiểm tra lifecycle & validation
    INSERT INTO public.coupons (id, store_id, code, discount_type, value, is_active)
    VALUES (gen_random_uuid(), v_store_id, 'INACTIVE_CP', 'fixed', 10000, false);

    INSERT INTO public.coupons (id, store_id, code, discount_type, value, is_active, start_date)
    VALUES (gen_random_uuid(), v_store_id, 'FUTURE_CP', 'fixed', 10000, true, now() + interval '10 days');

    INSERT INTO public.coupons (id, store_id, code, discount_type, value, is_active, end_date)
    VALUES (gen_random_uuid(), v_store_id, 'EXPIRED_CP', 'fixed', 10000, true, now() - interval '10 days');

    INSERT INTO public.coupons (id, store_id, code, discount_type, value, min_order_amount, is_active)
    VALUES (gen_random_uuid(), v_store_id, 'MIN_ORDER_CP', 'fixed', 10000, 1000000, true);

    INSERT INTO public.coupons (id, store_id, code, discount_type, value, is_active)
    VALUES (gen_random_uuid(), v_store_id, 'PCT_OVER_CP', 'percent', 150, true);

    INSERT INTO public.coupons (id, store_id, code, discount_type, value, is_active)
    VALUES (gen_random_uuid(), v_store_id, 'FIXED_ZERO_CP', 'fixed', 0, true);

    INSERT INTO public.coupons (id, store_id, code, discount_type, value, is_active)
    VALUES (gen_random_uuid(), v_store_id, 'UNSUPPORTED_TYPE_CP', 'crypto_discount', 10000, true);

    -- 7.9. Coupon inactive -> COUPON_DISABLED
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05a', NULL, 0, 0, 'INACTIVE_CP');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'COUPON_DISABLED', 'ERROR: Expected COUPON_DISABLED';

    -- 7.10. Coupon start date tương lai -> COUPON_NOT_STARTED
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05b', NULL, 0, 0, 'FUTURE_CP');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'COUPON_NOT_STARTED', 'ERROR: Expected COUPON_NOT_STARTED';

    -- 7.11. Coupon end date quá khứ -> COUPON_EXPIRED
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05c', NULL, 0, 0, 'EXPIRED_CP');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'COUPON_EXPIRED', 'ERROR: Expected COUPON_EXPIRED';

    -- 7.12. Subtotal dưới min order -> COUPON_MIN_ORDER_NOT_MET
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05d', NULL, 0, 0, 'MIN_ORDER_CP');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'COUPON_MIN_ORDER_NOT_MET', 'ERROR: Expected COUPON_MIN_ORDER_NOT_MET';

    -- 7.13. Coupon percent > 100 -> INVALID_COUPON_VALUE
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05e', NULL, 0, 0, 'PCT_OVER_CP');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_COUPON_VALUE', 'ERROR: Expected INVALID_COUPON_VALUE';

    -- 7.14. Coupon fixed <= 0 -> INVALID_COUPON_VALUE
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05f', NULL, 0, 0, 'FIXED_ZERO_CP');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_COUPON_VALUE', 'ERROR: Expected INVALID_COUPON_VALUE for zero fixed';

    -- 7.15. Coupon type không hỗ trợ -> INVALID_COUPON_TYPE
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-05g', NULL, 0, 0, 'UNSUPPORTED_TYPE_CP');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_COUPON_TYPE', 'ERROR: Expected INVALID_COUPON_TYPE';

    -- 7.16. Phụ phí âm -> INVALID_SURCHARGE
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-06', NULL, 0, 0, NULL, -1000);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_SURCHARGE', 'ERROR: Expected INVALID_SURCHARGE';

    -- 7.17. Phương thức thanh toán không hợp lệ -> INVALID_PAYMENT_METHOD
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'bitcoin', 'fc-key-07');
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'INVALID_PAYMENT_METHOD', 'ERROR: Expected INVALID_PAYMENT_METHOD';

    -- 7.18. Client truyền sai discount (Expected quote mismatch) -> FINANCIAL_QUOTE_CHANGED
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-08', NULL, 0, 50000, 'VOUCHER20K', 0);
    ASSERT (v_fc_res->>'success')::boolean = false AND (v_fc_res->>'error_code') = 'FINANCIAL_QUOTE_CHANGED', 'ERROR: Expected FINANCIAL_QUOTE_CHANGED';
    ASSERT (v_fc_res->'data'->>'authoritative_discount')::numeric = 18000, 'ERROR: Authoritative discount must be 18,000đ';

    -- Zero side-effect assertion sau toàn bộ 18 lần failure attempts
    SELECT count(*) INTO v_a_settle FROM public.payment_settlements WHERE store_id = v_store_id;
    SELECT count(*) INTO v_a_fin FROM public.finance_records WHERE store_id = v_store_id;
    SELECT count(*) INTO v_a_stock FROM public.stock_movements WHERE store_id = v_store_id;
    SELECT count(*) INTO v_a_loyalty FROM public.loyalty_transactions WHERE store_id = v_store_id;
    SELECT count(*) INTO v_a_redempt FROM public.qr_coupon_redemptions WHERE store_id = v_store_id;
    SELECT count(*) INTO v_a_orders FROM public.orders WHERE store_id = v_store_id;
    SELECT count(*) INTO v_a_items FROM public.order_items oi JOIN public.orders o ON o.id = oi.order_id WHERE o.store_id = v_store_id;
    SELECT count(*) INTO v_a_bso FROM public.ban_session_orders WHERE store_id = v_store_id;
    SELECT count(*) INTO v_a_bsoi FROM public.ban_session_order_items WHERE store_id = v_store_id;

    ASSERT v_a_settle = v_b_settle, 'ERROR: Failure attempts MUST NOT increase payment_settlements';
    ASSERT v_a_fin = v_b_fin, 'ERROR: Failure attempts MUST NOT increase finance_records';
    ASSERT v_a_stock = v_b_stock, 'ERROR: Failure attempts MUST NOT increase stock_movements';
    ASSERT v_a_loyalty = v_b_loyalty, 'ERROR: Failure attempts MUST NOT increase loyalty_transactions';
    ASSERT v_a_redempt = v_b_redempt, 'ERROR: Failure attempts MUST NOT increase qr_coupon_redemptions';
    ASSERT v_a_orders = v_b_orders, 'ERROR: Failure attempts MUST NOT increase orders';
    ASSERT v_a_items = v_b_items, 'ERROR: Failure attempts MUST NOT increase order_items';
    ASSERT v_a_bso = v_b_bso, 'ERROR: Failure attempts MUST NOT increase ban_session_orders';
    ASSERT v_a_bsoi = v_b_bsoi, 'ERROR: Failure attempts MUST NOT increase ban_session_order_items';

    -- 7.19. Thanh toán hợp lệ với Coupon -> Phải tạo đúng 1 bản ghi qr_coupon_redemptions
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-09', NULL, 0, 18000, 'VOUCHER20K', 0);
    ASSERT (v_fc_res->>'success')::boolean = true, 'ERROR: Valid coupon settlement must succeed';

    SELECT count(*) INTO v_coupon_redempt_count FROM public.qr_coupon_redemptions WHERE session_id = v_sess_fail_id;
    ASSERT v_coupon_redempt_count = 1, 'ERROR: Exactly 1 coupon redemption record must be created';

    -- 7.20. Replay cùng key & fingerprint -> is_replay = true, KHÔNG tạo redemption lần hai
    v_fc_res := public.settle_ban_session_v4(v_sess_fail_id, v_store_id, 'cash', 'fc-key-09', NULL, 0, 18000, 'VOUCHER20K', 0);
    ASSERT (v_fc_res->>'success')::boolean = true AND (v_fc_res->'data'->>'is_replay')::boolean = true, 'ERROR: Replay must succeed';

    SELECT count(*) INTO v_coupon_redempt_count FROM public.qr_coupon_redemptions WHERE session_id = v_sess_fail_id;
    ASSERT v_coupon_redempt_count = 1, 'ERROR: Replay MUST NOT duplicate coupon redemption record';
  END;

  RAISE NOTICE '✓ Test 7: Fail-Closed Loyalty, Coupon Lifecycle, Value Validation & Redemption Replay PASS';


  -- ── 8. TEST COUNTER PAYMENT CONFLICT & SETTLEMENT CONFLICT ───────────────────
  PERFORM set_config('request.jwt.claim.sub', '', true);
  v_submit_res := public.submit_qr_order_v4(
    v_counter_code,
    jsonb_build_array(jsonb_build_object('product_id', v_prod_food_id, 'quantity', 1)),
    NULL, 'idemp-ctr-01', '4444444444444444444444444444444444444444444444444444444444444444'
  );
  v_req_counter1_id := (v_submit_res->'data'->>'request_id')::uuid;

  v_submit_res := public.submit_qr_order_v4(
    v_counter_code,
    jsonb_build_array(jsonb_build_object('product_id', v_prod_drink_id, 'quantity', 1)),
    NULL, 'idemp-ctr-02', '5555555555555555555555555555555555555555555555555555555555555555'
  );
  v_req_counter2_id := (v_submit_res->'data'->>'request_id')::uuid;

  -- Thanh toán đơn counter 1 thành công
  PERFORM set_config('request.jwt.claim.sub', v_cashier_uid::text, true);
  v_pay1_res := public.mark_qr_order_paid_v4(v_req_counter1_id, v_store_id, 'cash', 'pay-shared-key-01');
  ASSERT (v_pay1_res->>'success')::boolean = true, 'ERROR: Payment 1 failed';

  -- Dùng cùng key `pay-shared-key-01` cho đơn counter 2 -> Báo lỗi IDEMPOTENCY_CONFLICT
  v_pay_conflict_res := public.mark_qr_order_paid_v4(v_req_counter2_id, v_store_id, 'cash', 'pay-shared-key-01');
  ASSERT (v_pay_conflict_res->>'success')::boolean = false, 'ERROR: Reusing payment key for different request MUST fail';
  ASSERT (v_pay_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT', 'ERROR: Expected IDEMPOTENCY_CONFLICT for payment';

  -- Settlement conflict test: Tạo session 2
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, opened_at, total_amount, guest_count)
  VALUES (gen_random_uuid(), v_store_id, v_table2_id, 'open', now(), 50000, 1)
  RETURNING id INTO v_session2_id;

  INSERT INTO public.ban_session_items (
    id, store_id, session_id, product_id, product_name, unit_price, price, quantity, subtotal, kitchen_status, added_at
  ) VALUES (
    gen_random_uuid(), v_store_id, v_session2_id, v_prod_food_id, 'Cơm Chiên', 50000, 50000, 1, 50000, 'da_gui', now()
  );

  -- ── 9. TEST FINGERPRINT CONFLICTS (SAME KEY + CHANGED INTENT PARAMETERS) ────
  -- v_session_id đã được settle thành công với:
  -- key: 'settle-idemp-01', pay: 'cash', cust: v_customer_id, pts: 2, coupon: 'VOUCHER20K', sur: 5000, disc: 20000
  DECLARE
    v_fp_conflict_res jsonb;
    v_settle_count_before integer;
    v_settle_count_after integer;
  BEGIN
    SELECT count(*) INTO v_settle_count_before FROM public.payment_settlements WHERE store_id = v_store_id;

    -- 9.1. Same key + khác payment method -> IDEMPOTENCY_CONFLICT
    v_fp_conflict_res := public.settle_ban_session_v4(
      v_session_id, v_store_id, 'transfer', 'settle-idemp-01', v_customer_id, 2, 20000, 'VOUCHER20K', 5000
    );
    ASSERT (v_fp_conflict_res->>'success')::boolean = false AND (v_fp_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT',
      'ERROR: Expected IDEMPOTENCY_CONFLICT for different payment method';

    -- 9.2. Same key + khác customer -> IDEMPOTENCY_CONFLICT
    v_fp_conflict_res := public.settle_ban_session_v4(
      v_session_id, v_store_id, 'cash', 'settle-idemp-01', NULL, 0, 20000, 'VOUCHER20K', 5000
    );
    ASSERT (v_fp_conflict_res->>'success')::boolean = false AND (v_fp_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT',
      'ERROR: Expected IDEMPOTENCY_CONFLICT for different customer';

    -- 9.3. Same key + khác points used -> IDEMPOTENCY_CONFLICT
    v_fp_conflict_res := public.settle_ban_session_v4(
      v_session_id, v_store_id, 'cash', 'settle-idemp-01', v_customer_id, 3, 20000, 'VOUCHER20K', 5000
    );
    ASSERT (v_fp_conflict_res->>'success')::boolean = false AND (v_fp_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT',
      'ERROR: Expected IDEMPOTENCY_CONFLICT for different points used';

    -- 9.4. Same key + khác coupon -> IDEMPOTENCY_CONFLICT
    v_fp_conflict_res := public.settle_ban_session_v4(
      v_session_id, v_store_id, 'cash', 'settle-idemp-01', v_customer_id, 2, 20000, 'OTHER_COUPON', 5000
    );
    ASSERT (v_fp_conflict_res->>'success')::boolean = false AND (v_fp_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT',
      'ERROR: Expected IDEMPOTENCY_CONFLICT for different coupon';

    -- 9.5. Same key + khác surcharge -> IDEMPOTENCY_CONFLICT
    v_fp_conflict_res := public.settle_ban_session_v4(
      v_session_id, v_store_id, 'cash', 'settle-idemp-01', v_customer_id, 2, 20000, 'VOUCHER20K', 10000
    );
    ASSERT (v_fp_conflict_res->>'success')::boolean = false AND (v_fp_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT',
      'ERROR: Expected IDEMPOTENCY_CONFLICT for different surcharge';

    -- 9.6. Same key + khác expected discount -> IDEMPOTENCY_CONFLICT
    v_fp_conflict_res := public.settle_ban_session_v4(
      v_session_id, v_store_id, 'cash', 'settle-idemp-01', v_customer_id, 2, 15000, 'VOUCHER20K', 5000
    );
    ASSERT (v_fp_conflict_res->>'success')::boolean = false AND (v_fp_conflict_res->>'error_code') = 'IDEMPOTENCY_CONFLICT',
      'ERROR: Expected IDEMPOTENCY_CONFLICT for different expected discount';

    -- Zero-Orphan check: Số lượng settlements không tăng sau 6 lần conflict
    SELECT count(*) INTO v_settle_count_after FROM public.payment_settlements WHERE store_id = v_store_id;
    ASSERT v_settle_count_before = v_settle_count_after, 'ERROR: Conflict attempts MUST NOT create any settlement records';
  END;

  RAISE NOTICE '✓ Test 9: Strict Request Fingerprint Conflicts & Zero-Side-Effect Guards PASS';

  RAISE NOTICE '================================================================';
  RAISE NOTICE '>>> TẤT CẢ CÁC BÀI TEST SQL INTEGRATION ĐÃ PASS HOÀN TOÀN <<<';
  RAISE NOTICE '================================================================';

END $$;

ROLLBACK;
