-- ============================================================================
-- SQL INTEGRATION TEST SUITE: SETTLEMENT V5 & ATOMIC DAILY COUNTER
-- File: supabase/tests/settle_v5_concurrency_test.sql
-- Mục đích: Kiểm thử tích hợp logic tuần tự và ràng buộc dữ liệu của Settlement V5
-- ============================================================================

BEGIN;

CREATE FUNCTION pg_temp.reject_test_finance() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF current_setting('qn.inject_finance_failure', true) = 'on' THEN
    RAISE EXCEPTION 'INJECTED_FINANCE_FAILURE';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER test_reject_finance BEFORE INSERT ON public.finance_records
FOR EACH ROW EXECUTE FUNCTION pg_temp.reject_test_finance();

DO $$
DECLARE
  v_store_id uuid := gen_random_uuid();
  v_other_store_id uuid := gen_random_uuid();
  v_cashier_uid uuid := gen_random_uuid();
  v_waiter_uid uuid := gen_random_uuid();
  v_customer_id uuid := gen_random_uuid();

  v_cashier_sm_id uuid := gen_random_uuid();
  v_waiter_sm_id uuid := gen_random_uuid();

  v_table_id uuid := gen_random_uuid();
  v_prod_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_session_item_id uuid := gen_random_uuid();

  v_coupon_valid_id uuid := gen_random_uuid();
  v_coupon_dis_id uuid := gen_random_uuid();
  v_coupon_exp_id uuid := gen_random_uuid();
  v_coupon_fut_id uuid := gen_random_uuid();
  v_coupon_min_id uuid := gen_random_uuid();

  v_num1 text;
  v_num2 text;
  v_reconcile_res jsonb;
  v_reconcile_conflict_res jsonb;
  v_settle_res jsonb;
  v_replay_res jsonb;
  v_conflict_res jsonb;
  v_closed_res jsonb;

  v_pos_res jsonb;
  v_pos_replay_res jsonb;
  v_pos_conflict_res jsonb;
  v_pos_fail_qty jsonb;
  v_pos_fail_pts jsonb;
  v_pos_coupon_fail jsonb;
  v_pos_coupon_succ jsonb;

  -- 7 Snapshot counts
  v_cnt_orders_before integer;
  v_cnt_items_before integer;
  v_cnt_finance_before integer;
  v_cnt_stock_before integer;
  v_cnt_loyalty_before integer;
  v_cnt_coupons_before integer;
  v_cnt_idemp_before integer;

  v_cnt_orders_after integer;
  v_cnt_items_after integer;
  v_cnt_finance_after integer;
  v_cnt_stock_after integer;
  v_cnt_loyalty_after integer;
  v_cnt_coupons_after integer;
  v_cnt_idemp_after integer;

  v_has_coupons_table boolean;
  v_wallet_result jsonb;
  v_wallet_order_id uuid;
  v_wallet_before jsonb;
  v_wallet_after jsonb;
  v_qr_order_id uuid;
  v_qr_item_id uuid;
BEGIN
  RAISE NOTICE '>>> BẮT ĐẦU TEST SUITE SETTLEMENT V5 & DAILY COUNTER <<<';

  -- 1. SETUP FIXTURES
  INSERT INTO public.stores (id, name, created_at)
  VALUES
    (v_store_id, 'Quán Nhỏ Test Settle V5', now()),
    (v_other_store_id, 'Quán Nhỏ Test Store B', now());

  INSERT INTO public.user_accounts (id, phone, display_name)
  VALUES
    (v_cashier_uid, '0988000001', 'Thu Ngân Thư'),
    (v_waiter_uid, '0988000002', 'Phục Vụ Phương');

  INSERT INTO public.store_members (id, store_id, user_id, role, created_at)
  VALUES
    (v_cashier_sm_id, v_store_id, v_cashier_uid, 'cashier', now()),
    (v_waiter_sm_id, v_store_id, v_waiter_uid, 'waiter', now());

  INSERT INTO public.app_settings (id, store_id, key, value)
  VALUES
    (gen_random_uuid(), v_store_id, 'action_perms_cashier', '["pos.checkout"]'),
    (gen_random_uuid(), v_store_id, 'loyalty_rate', '10000'),
    (gen_random_uuid(), v_store_id, 'loyalty_redeem_rate', '1000'),
    (gen_random_uuid(), v_store_id, 'stamp_threshold', '10');

  INSERT INTO public.customers (id, store_id, name, phone, loyalty_pts, total_spent)
  VALUES
    (v_customer_id, v_store_id, 'Khách Hàng Test', '0912345678', 10, 50000);

  INSERT INTO public.ban_dining_tables (id, store_id, label, is_active, status)
  VALUES
    (v_table_id, v_store_id, 'Bàn C03', true, 'occupied');

  INSERT INTO public.products (id, store_id, name, sell_price, cost_price_latest, stock_qty)
  VALUES
    (v_prod_id, v_store_id, 'Cà phê sữa', 30000, 15000, 100);

  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupons'
  ) INTO v_has_coupons_table;

  IF v_has_coupons_table THEN
    INSERT INTO public.coupons (id, store_id, code, is_active, start_date, end_date, discount_type, value, min_order_amount, max_discount_amount)
    VALUES
      (v_coupon_valid_id, v_store_id, 'TEST10', true, now() - interval '1 day', now() + interval '30 days', 'percent', 10, 20000, 50000),
      (v_coupon_dis_id, v_store_id, 'TESTDIS', false, now() - interval '1 day', now() + interval '30 days', 'percent', 10, 0, 50000),
      (v_coupon_exp_id, v_store_id, 'TESTEXP', true, now() - interval '30 days', now() - interval '1 day', 'percent', 10, 0, 50000),
      (v_coupon_fut_id, v_store_id, 'TESTFUT', true, now() + interval '1 day', now() + interval '30 days', 'percent', 10, 0, 50000),
      (v_coupon_min_id, v_store_id, 'TESTMIN', true, now() - interval '1 day', now() + interval '30 days', 'percent', 10, 500000, 50000);
  END IF;

  -- Mock JWT context as cashier
  PERFORM set_config('request.jwt.claim.sub', v_cashier_uid::text, true);

  -- 2. TEST DAILY ORDER COUNTER (SEQUENTIAL)
  v_num1 := public.generate_daily_order_number_v1(v_store_id, 'QN');
  v_num2 := public.generate_daily_order_number_v1(v_store_id, 'QN');

  ASSERT v_num1 LIKE 'QN-%-001', 'ERROR: First order number must end with 001, got: ' || v_num1;
  ASSERT v_num2 LIKE 'QN-%-002', 'ERROR: Second order number must end with 002, got: ' || v_num2;
  RAISE NOTICE '✓ PASS: generate_daily_order_number_v1 incremented sequentially: %, %', v_num1, v_num2;

  -- 3. CREATE BAN SESSION & ITEMS
  INSERT INTO public.ban_sessions (id, store_id, table_id, status, waiter_id, opened_at)
  VALUES (v_session_id, v_store_id, v_table_id, 'open', v_waiter_sm_id, now());

  INSERT INTO public.ban_session_items (id, store_id, session_id, product_id, product_name, quantity, unit_price, subtotal)
  VALUES (v_session_item_id, v_store_id, v_session_id, v_prod_id, 'Cà phê sữa', 2, 30000, 60000);

  -- 4. TEST RECONCILE ON OPEN SESSION
  v_reconcile_res := public.reconcile_ban_settlement_v1(v_store_id, v_session_id);
  ASSERT (v_reconcile_res->>'is_settled')::boolean = false, 'ERROR: Reconcile on open session must return is_settled = false';
  RAISE NOTICE '✓ PASS: reconcile_ban_settlement_v1 correctly identified unsettled session';

  -- 5. TEST SETTLE_BAN_SESSION_V5 (FIRST ATTEMPT)
  v_settle_res := public.settle_ban_session_v5(
    p_session_id => v_session_id,
    p_store_id => v_store_id,
    p_payment_method => 'cash',
    p_idempotency_key => 'test-idemp-001',
    p_customer_id => v_customer_id,
    p_points_used => 0,
    p_discount => 0
  );

  ASSERT (v_settle_res->>'success')::boolean = true, 'ERROR: Settle V5 failed: ' || v_settle_res::text;
  ASSERT (v_settle_res->'data'->>'is_replay')::boolean = false, 'ERROR: First settle must not be replay';
  ASSERT (v_settle_res->'data'->>'total_amount')::numeric = 60000, 'ERROR: Total amount mismatch';
  RAISE NOTICE '✓ PASS: settle_ban_session_v5 committed successfully';

  -- 6. ASSERT DATABASE STATE AFTER SETTLE
  ASSERT (SELECT count(*) FROM public.finance_records WHERE reference_id = (v_settle_res->'data'->>'settlement_id')::uuid AND is_auto = true) = 1;
  ASSERT (SELECT count(*) FROM public.payment_settlements WHERE session_id = v_session_id) = 1;
  ASSERT (SELECT count(*) FROM public.ban_session_orders WHERE session_id = v_session_id) = 1;
  ASSERT (SELECT count(*) FROM public.stock_movements WHERE reference_id = (v_settle_res->'data'->>'settlement_id')::uuid) = 1;
  RAISE NOTICE '✓ PASS: Database assertions passed (1 finance, 1 settlement, 1 order, 1 stock movement)';

  -- 7. TEST REPLAY WITH SAME IDEMPOTENCY KEY (ZERO SIDE EFFECTS)
  v_replay_res := public.settle_ban_session_v5(
    p_session_id => v_session_id,
    p_store_id => v_store_id,
    p_payment_method => 'cash',
    p_idempotency_key => 'test-idemp-001',
    p_customer_id => v_customer_id,
    p_points_used => 0,
    p_discount => 0
  );

  ASSERT (v_replay_res->>'success')::boolean = true, 'ERROR: Replay failed';
  ASSERT (v_replay_res->'data'->>'is_replay')::boolean = true, 'ERROR: Replay must have is_replay = true';
  ASSERT (SELECT count(*) FROM public.finance_records WHERE reference_id = (v_settle_res->'data'->>'settlement_id')::uuid AND is_auto = true) = 1;
  RAISE NOTICE '✓ PASS: Replay returned successfully with zero duplicate side effects';

  -- 8. TEST RECONCILE ON SETTLED SESSION WITH MATCHING & MISMATCHING IDEMPOTENCY KEY
  v_reconcile_res := public.reconcile_ban_settlement_v1(v_store_id, v_session_id, 'test-idemp-001');
  ASSERT (v_reconcile_res->>'is_settled')::boolean = true, 'ERROR: Reconcile must return is_settled = true';

  v_reconcile_conflict_res := public.reconcile_ban_settlement_v1(v_store_id, v_session_id, 'diff-idemp-key-xyz');
  ASSERT (v_reconcile_conflict_res->>'success')::boolean = false, 'ERROR: Reconcile with mismatch key must fail';
  RAISE NOTICE '✓ PASS: reconcile_ban_settlement_v1 validated consistency between session_id and idempotency_key';

  -- 9. TEST IDEMPOTENCY CONFLICT (SAME KEY, DIFFERENT PAYMENT METHOD)
  v_conflict_res := public.settle_ban_session_v5(
    p_session_id => v_session_id,
    p_store_id => v_store_id,
    p_payment_method => 'transfer',
    p_idempotency_key => 'test-idemp-001'
  );
  ASSERT (v_conflict_res->>'success')::boolean = false, 'ERROR: Conflict test should fail';
  ASSERT v_conflict_res->>'error_code' = 'IDEMPOTENCY_CONFLICT', 'ERROR: Expected IDEMPOTENCY_CONFLICT';
  RAISE NOTICE '✓ PASS: IDEMPOTENCY_CONFLICT correctly raised on changed intent';

  -- 10. TEST CLOSED SESSION GUARD (DIFFERENT KEY ON CLOSED SESSION)
  v_closed_res := public.settle_ban_session_v5(
    p_session_id => v_session_id,
    p_store_id => v_store_id,
    p_payment_method => 'cash',
    p_idempotency_key => 'test-idemp-002'
  );
  ASSERT (v_closed_res->>'success')::boolean = false, 'ERROR: Settle on closed session should fail';
  ASSERT v_closed_res->>'error_code' IN ('SESSION_ALREADY_SETTLED', 'SESSION_NOT_OPEN'), 'ERROR: Expected SESSION_ALREADY_SETTLED';
  RAISE NOTICE '✓ PASS: Closed session guard correctly prevented double settlement';

  -- 11. TEST COMPLETE_POS_SALE_V1 (ATOMIC QUICK SALE FAIL-CLOSED)
  -- 11.1. Negative quantity must fail
  v_pos_fail_qty := public.complete_pos_sale_v1(
    p_store_id => v_store_id,
    p_idempotency_key => 'pos-fail-qty-01',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', -1))
  );
  ASSERT (v_pos_fail_qty->>'success')::boolean = false;
  ASSERT v_pos_fail_qty->>'error_code' = 'INVALID_QUANTITY';

  -- 11.2. Negative points must fail
  v_pos_fail_pts := public.complete_pos_sale_v1(
    p_store_id => v_store_id,
    p_idempotency_key => 'pos-fail-pts-01',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_customer_id => v_customer_id,
    p_loyalty_pts_used => -5
  );
  ASSERT (v_pos_fail_pts->>'success')::boolean = false;
  ASSERT v_pos_fail_pts->>'error_code' = 'INVALID_POINTS';

  -- 11.3. Coupon Tests on Available Schema & Unavailable Schema
  IF v_has_coupons_table THEN
    -- Disabled coupon
    v_pos_coupon_fail := public.complete_pos_sale_v1(
      p_store_id => v_store_id,
      p_idempotency_key => 'pos-fail-coup-dis',
      p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
      p_coupon_code => 'TESTDIS'
    );
    ASSERT (v_pos_coupon_fail->>'success')::boolean = false;
    ASSERT v_pos_coupon_fail->>'error_code' = 'COUPON_DISABLED';

    -- Expired coupon
    v_pos_coupon_fail := public.complete_pos_sale_v1(
      p_store_id => v_store_id,
      p_idempotency_key => 'pos-fail-coup-exp',
      p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
      p_coupon_code => 'TESTEXP'
    );
    ASSERT (v_pos_coupon_fail->>'success')::boolean = false;
    ASSERT v_pos_coupon_fail->>'error_code' = 'COUPON_EXPIRED';

    -- Min order not met
    v_pos_coupon_fail := public.complete_pos_sale_v1(
      p_store_id => v_store_id,
      p_idempotency_key => 'pos-fail-coup-min',
      p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
      p_coupon_code => 'TESTMIN'
    );
    ASSERT (v_pos_coupon_fail->>'success')::boolean = false;
    ASSERT v_pos_coupon_fail->>'error_code' = 'COUPON_MIN_ORDER_NOT_MET';

    -- Valid coupon with matching quote
    v_pos_coupon_succ := public.complete_pos_sale_v1(
      p_store_id => v_store_id,
      p_idempotency_key => 'pos-succ-coup-01',
      p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
      p_coupon_code => 'TEST10',
      p_discount => 3000 -- 10% of 30,000
    );
    ASSERT (v_pos_coupon_succ->>'success')::boolean = true;
    ASSERT (SELECT count(*) FROM public.pos_coupon_redemptions WHERE coupon_code = 'TEST10') = 1;
    RAISE NOTICE '✓ PASS: Branch A (Schema with coupons) passed 100%%';
  ELSE
    -- When coupons table does not exist, passing coupon_code must fail with COUPON_SCHEMA_UNAVAILABLE
    v_pos_coupon_fail := public.complete_pos_sale_v1(
      p_store_id => v_store_id,
      p_idempotency_key => 'pos-fail-coup-noschema',
      p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
      p_coupon_code => 'TESTCODE'
    );
    ASSERT (v_pos_coupon_fail->>'success')::boolean = false;
    ASSERT v_pos_coupon_fail->>'error_code' = 'COUPON_SCHEMA_UNAVAILABLE';
    RAISE NOTICE '✓ PASS: COUPON_SCHEMA_UNAVAILABLE correctly returned when coupons table is absent';
  END IF;

  -- 11.4. Valid POS Sale and Snapshot Replay
  v_pos_res := public.complete_pos_sale_v1(
    p_store_id => v_store_id,
    p_idempotency_key => 'pos-idemp-001',
    p_lines => jsonb_build_array(
      jsonb_build_object('product_id', v_prod_id, 'quantity', 1)
    ),
    p_payment_method => 'cash'
  );
  ASSERT (v_pos_res->>'success')::boolean = true;
  ASSERT (v_pos_res->'data'->>'is_replay')::boolean = false;

  -- Take snapshot across 7 tables
  SELECT count(*) INTO v_cnt_orders_before FROM public.orders WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_items_before FROM public.order_items WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_finance_before FROM public.finance_records WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_stock_before FROM public.stock_movements WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_loyalty_before FROM public.loyalty_transactions WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_coupons_before FROM public.pos_coupon_redemptions WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_idemp_before FROM public.pos_idempotency_operations WHERE store_id = v_store_id;

  -- Execute Replay
  v_pos_replay_res := public.complete_pos_sale_v1(
    p_store_id => v_store_id,
    p_idempotency_key => 'pos-idemp-001',
    p_lines => jsonb_build_array(
      jsonb_build_object('product_id', v_prod_id, 'quantity', 1)
    ),
    p_payment_method => 'cash'
  );
  ASSERT (v_pos_replay_res->>'success')::boolean = true;
  ASSERT (v_pos_replay_res->'data'->>'is_replay')::boolean = true;

  -- Take snapshot after replay
  SELECT count(*) INTO v_cnt_orders_after FROM public.orders WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_items_after FROM public.order_items WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_finance_after FROM public.finance_records WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_stock_after FROM public.stock_movements WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_loyalty_after FROM public.loyalty_transactions WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_coupons_after FROM public.pos_coupon_redemptions WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_idemp_after FROM public.pos_idempotency_operations WHERE store_id = v_store_id;

  ASSERT v_cnt_orders_before = v_cnt_orders_after, 'ERROR: orders count increased during replay';
  ASSERT v_cnt_items_before = v_cnt_items_after, 'ERROR: order_items count increased during replay';
  ASSERT v_cnt_finance_before = v_cnt_finance_after, 'ERROR: finance_records count increased during replay';
  ASSERT v_cnt_stock_before = v_cnt_stock_after, 'ERROR: stock_movements count increased during replay';
  ASSERT v_cnt_loyalty_before = v_cnt_loyalty_after, 'ERROR: loyalty_transactions count increased during replay';
  ASSERT v_cnt_coupons_before = v_cnt_coupons_after, 'ERROR: pos_coupon_redemptions count increased during replay';
  ASSERT v_cnt_idemp_before = v_cnt_idemp_after, 'ERROR: pos_idempotency_operations count increased during replay';

  RAISE NOTICE '✓ PASS: 7-table snapshot assertion passed (0 new rows during POS replay)';

  -- 11.5. POS Conflict
  v_pos_conflict_res := public.complete_pos_sale_v1(
    p_store_id => v_store_id,
    p_idempotency_key => 'pos-idemp-001',
    p_lines => jsonb_build_array(
      jsonb_build_object('product_id', v_prod_id, 'quantity', 3)
    ),
    p_payment_method => 'cash'
  );
  ASSERT (v_pos_conflict_res->>'success')::boolean = false;
  ASSERT v_pos_conflict_res->>'error_code' = 'IDEMPOTENCY_CONFLICT';
  RAISE NOTICE '✓ PASS: complete_pos_sale_v1 correctly detected cart change for same key';

  RAISE NOTICE '>>> KIỂM THỬ TÍCH HỢP TUẦN TỰ SETTLEMENT V5 ĐÃ HOÀN TẤT <<<';

  -- Wallet is part of the same commit, never a post-commit client mutation.
  UPDATE public.customers SET real_balance = 100000, bonus_balance = 10000,
    bonus_cap_pct = 15, bonus_expires_at = now() + interval '1 day'
  WHERE id = v_customer_id;
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'wallet-1',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'wallet', p_customer_id => v_customer_id, p_expected_total => 30000);
  ASSERT (v_wallet_result->>'success')::boolean, v_wallet_result::text;
  ASSERT (v_wallet_result->'data'->>'wallet_real_used')::numeric = 25500;
  ASSERT (v_wallet_result->'data'->>'wallet_bonus_used')::numeric = 4500;
  v_wallet_order_id := (v_wallet_result->'data'->>'order_id')::uuid;
  ASSERT (SELECT real_balance = 74500 AND bonus_balance = 5500 FROM public.customers WHERE id = v_customer_id);
  ASSERT (SELECT count(*) = 2 AND sum(amount) = 30000 FROM public.balance_transactions WHERE order_id = v_wallet_order_id);
  ASSERT (SELECT count(*) = 1 FROM public.finance_records WHERE reference_id = v_wallet_order_id AND fund_type = 'wallet' AND amount = 30000);
  SELECT jsonb_build_object('customer', to_jsonb(c),
    'wallet', (SELECT jsonb_agg(to_jsonb(b) ORDER BY b.id) FROM public.balance_transactions b WHERE b.customer_id = v_customer_id),
    'orders', (SELECT count(*) FROM public.orders WHERE store_id = v_store_id),
    'finance', (SELECT count(*) FROM public.finance_records WHERE store_id = v_store_id),
    'stock', (SELECT count(*) FROM public.stock_movements WHERE store_id = v_store_id),
    'loyalty', (SELECT count(*) FROM public.loyalty_transactions WHERE store_id = v_store_id))
    INTO v_wallet_before FROM public.customers c WHERE c.id = v_customer_id;
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'wallet-1',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'wallet', p_customer_id => v_customer_id, p_expected_total => 30000);
  ASSERT (v_wallet_result->'data'->>'is_replay')::boolean;
  ASSERT (v_wallet_result->'data'->>'wallet_real_used')::numeric = 25500;
  SELECT jsonb_build_object('customer', to_jsonb(c),
    'wallet', (SELECT jsonb_agg(to_jsonb(b) ORDER BY b.id) FROM public.balance_transactions b WHERE b.customer_id = v_customer_id),
    'orders', (SELECT count(*) FROM public.orders WHERE store_id = v_store_id),
    'finance', (SELECT count(*) FROM public.finance_records WHERE store_id = v_store_id),
    'stock', (SELECT count(*) FROM public.stock_movements WHERE store_id = v_store_id),
    'loyalty', (SELECT count(*) FROM public.loyalty_transactions WHERE store_id = v_store_id))
    INTO v_wallet_after FROM public.customers c WHERE c.id = v_customer_id;
  ASSERT v_wallet_before = v_wallet_after, 'Wallet replay changed database state';

  UPDATE public.customers SET real_balance = 30000, bonus_balance = 10000,
    bonus_expires_at = now() - interval '1 day' WHERE id = v_customer_id;
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'wallet-expired',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'wallet', p_customer_id => v_customer_id);
  ASSERT (v_wallet_result->>'success')::boolean, v_wallet_result::text;
  ASSERT (v_wallet_result->'data'->>'wallet_bonus_used')::numeric = 0;
  ASSERT (SELECT real_balance = 0 AND bonus_balance = 10000 FROM public.customers WHERE id = v_customer_id);
  SELECT count(*) INTO v_cnt_orders_before FROM public.orders WHERE store_id = v_store_id;
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'wallet-insufficient',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'wallet', p_customer_id => v_customer_id);
  ASSERT v_wallet_result->>'error_code' = 'INSUFFICIENT_WALLET', v_wallet_result::text;
  ASSERT NOT EXISTS (SELECT 1 FROM public.pos_idempotency_operations WHERE idempotency_key = 'wallet-insufficient' AND store_id = v_store_id);
  ASSERT (SELECT count(*) = v_cnt_orders_before FROM public.orders WHERE store_id = v_store_id);
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'quote-changed',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'cash', p_expected_total => 1);
  ASSERT v_wallet_result->>'error_code' = 'FINANCIAL_QUOTE_CHANGED';
  ASSERT (SELECT count(*) = v_cnt_orders_before FROM public.orders WHERE store_id = v_store_id);
  RAISE NOTICE 'PASS: wallet atomic debit, replay snapshot, expiry, insufficient balance and expected quote';
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'wallet-no-customer',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'wallet');
  ASSERT v_wallet_result->>'error_code' = 'CUSTOMER_REQUIRED';
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'wallet-points',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'wallet', p_customer_id => v_customer_id, p_loyalty_pts_used => 1);
  ASSERT v_wallet_result->>'error_code' = 'INVALID_POINTS';
  UPDATE public.customers SET store_id = v_other_store_id WHERE id = v_customer_id;
  v_wallet_result := public.complete_pos_sale_v1(
    p_store_id => v_store_id, p_idempotency_key => 'wallet-cross-store',
    p_lines => jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
    p_payment_method => 'wallet', p_customer_id => v_customer_id);
  ASSERT v_wallet_result->>'error_code' = 'CUSTOMER_NOT_FOUND';
  UPDATE public.customers SET store_id = v_store_id WHERE id = v_customer_id;
  ASSERT (SELECT count(*) = v_cnt_orders_before FROM public.orders WHERE store_id = v_store_id);
  -- Regression: cancelled quantities remain for audit but are never charged.
  v_session_id := gen_random_uuid();
  INSERT INTO public.ban_sessions(id, store_id, table_id) VALUES(v_session_id, v_store_id, v_table_id);
  INSERT INTO public.ban_session_items(store_id, session_id, product_id, product_name, quantity, unit_price, subtotal, kitchen_status)
  VALUES(v_store_id, v_session_id, v_prod_id, 'Live', 1, 30000, 30000, 'da_gui'),
        (v_store_id, v_session_id, v_prod_id, 'Cancelled', 4, 30000, 120000, 'huy');
  v_pos_res := public.settle_ban_session_v5(v_session_id, v_store_id, 'cash', 'cancelled-items');
  ASSERT (v_pos_res->>'success')::boolean, v_pos_res::text;
  ASSERT (v_pos_res->'data'->>'total_amount')::numeric = 30000;
  ASSERT (SELECT sum(delta) = -1 FROM public.stock_movements WHERE reference_id = (v_pos_res->'data'->>'settlement_id')::uuid);

  -- Legitimate repeated wallet top-ups must not hit checkout uniqueness.
  INSERT INTO public.finance_records(store_id, reference_id, type, is_auto, amount)
  VALUES(v_store_id, v_customer_id, 'income', true, 100000),
        (v_store_id, v_customer_id, 'income', true, 100000);
  ASSERT (SELECT count(*) = 2 FROM public.finance_records WHERE reference_id = v_customer_id AND checkout_reference_id IS NULL);
  BEGIN
    INSERT INTO public.finance_records(store_id, reference_id, type, is_auto, amount)
    VALUES(v_store_id, (v_pos_res->'data'->>'settlement_id')::uuid, 'income', true, 30000);
    RAISE EXCEPTION 'Expected checkout unique violation';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  -- Manual discount is authorized server-side and audited exactly once.
  v_pos_res := public.complete_pos_sale_v1(v_store_id, 'manual-denied',
    jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)), p_discount => 5000);
  ASSERT v_pos_res->>'error_code' = 'DISCOUNT_PERMISSION_DENIED', v_pos_res::text;
  UPDATE public.app_settings SET value = '["pos.checkout","pos.apply_discount"]'
  WHERE store_id = v_store_id AND key = 'action_perms_cashier';
  v_pos_res := public.complete_pos_sale_v1(v_store_id, 'manual-allowed',
    jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)), p_discount => 5000, p_expected_total => 25000);
  ASSERT (v_pos_res->>'success')::boolean, v_pos_res::text;
  ASSERT (v_pos_res->'data'->>'total_amount')::numeric = 25000;
  v_pos_replay_res := public.complete_pos_sale_v1(v_store_id, 'manual-allowed',
    jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)), p_discount => 5000, p_expected_total => 25000.0);
  ASSERT (v_pos_replay_res->'data'->>'is_replay')::boolean, v_pos_replay_res::text;
  ASSERT (SELECT count(*) = 1 FROM public.qr_audit_logs WHERE store_id = v_store_id AND action = 'pos_manual_discount');
  v_pos_replay_res := public.reconcile_pos_sale_v1(v_store_id, 'manual-allowed');
  ASSERT v_pos_replay_res->'data'->>'order_id' = v_pos_res->'data'->>'order_id';
  v_pos_replay_res := public.reconcile_pos_sale_v1(v_store_id, 'not-committed');
  ASSERT v_pos_replay_res->>'error_code' = 'RESULT_NOT_FOUND';
  v_pos_replay_res := public.complete_pos_sale_v1(v_store_id, 'stale-item-price',
    jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1, 'expected_unit_price', 1)));
  ASSERT v_pos_replay_res->>'error_code' = 'FINANCIAL_QUOTE_CHANGED';

  -- Paid POS batches close atomically and cannot be paid a second time in Ban.
  v_session_id := gen_random_uuid();
  INSERT INTO public.ban_sessions(id, store_id, table_id) VALUES(v_session_id, v_store_id, v_table_id);
  INSERT INTO public.ban_session_items(store_id, session_id, product_id, product_name, quantity, unit_price, subtotal)
  VALUES(v_store_id, v_session_id, v_prod_id, 'Kitchen', 1, 30000, 30000);
  v_pos_res := public.complete_pos_sale_v1(v_store_id, 'pos-kitchen',
    jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)), p_kitchen_session_ids => ARRAY[v_session_id]);
  ASSERT (v_pos_res->>'success')::boolean, v_pos_res::text;
  ASSERT (SELECT status = 'closed' FROM public.ban_sessions WHERE id = v_session_id);
  -- KDS progress is allowed after payment, financial edits are not.
  UPDATE public.ban_session_items SET kitchen_status = 'da_xong' WHERE session_id = v_session_id;
  BEGIN
    UPDATE public.ban_session_items SET quantity = 2 WHERE session_id = v_session_id;
    RAISE EXCEPTION 'Expected item guard';
  EXCEPTION WHEN OTHERS THEN ASSERT SQLERRM LIKE 'SESSION_NOT_OPEN:%', SQLERRM; END;
  v_pos_replay_res := public.complete_pos_sale_v1(v_store_id, 'pos-kitchen',
    jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)), p_kitchen_session_ids => ARRAY[v_session_id]);
  ASSERT (v_pos_replay_res->'data'->>'is_replay')::boolean, v_pos_replay_res::text;
  v_pos_res := public.settle_ban_session_v5(v_session_id, v_store_id, 'cash', 'ban-after-pos');
  ASSERT v_pos_res->>'error_code' = 'SESSION_NOT_OPEN', v_pos_res::text;

  -- A finance failure rolls back wallet, order, stock and batch closure together.
  UPDATE public.customers SET real_balance = 100000, bonus_balance = 0 WHERE id = v_customer_id;
  v_session_id := gen_random_uuid();
  INSERT INTO public.ban_sessions(id, store_id, table_id) VALUES(v_session_id, v_store_id, v_table_id);
  SELECT to_jsonb(c) INTO v_wallet_before FROM public.customers c WHERE id = v_customer_id;
  SELECT count(*) INTO v_cnt_orders_before FROM public.orders WHERE store_id = v_store_id;
  SELECT count(*) INTO v_cnt_stock_before FROM public.stock_movements WHERE store_id = v_store_id;
  PERFORM set_config('qn.inject_finance_failure', 'on', true);
  BEGIN
    PERFORM public.complete_pos_sale_v1(v_store_id, 'rollback-all',
      jsonb_build_array(jsonb_build_object('product_id', v_prod_id, 'quantity', 1)),
      p_payment_method => 'wallet', p_customer_id => v_customer_id, p_kitchen_session_ids => ARRAY[v_session_id]);
    RAISE EXCEPTION 'Expected injection did not happen';
  EXCEPTION WHEN OTHERS THEN
    ASSERT SQLERRM = 'INJECTED_FINANCE_FAILURE', SQLERRM;
  END;
  PERFORM set_config('qn.inject_finance_failure', 'off', true);
  SELECT to_jsonb(c) INTO v_wallet_after FROM public.customers c WHERE id = v_customer_id;
  ASSERT v_wallet_before = v_wallet_after;
  ASSERT (SELECT count(*) = v_cnt_orders_before FROM public.orders WHERE store_id = v_store_id);
  ASSERT (SELECT count(*) = v_cnt_stock_before FROM public.stock_movements WHERE store_id = v_store_id);
  ASSERT (SELECT status = 'open' FROM public.ban_sessions WHERE id = v_session_id);
  ASSERT NOT EXISTS(SELECT 1 FROM public.pos_idempotency_operations WHERE store_id = v_store_id AND idempotency_key = 'rollback-all');
  RAISE NOTICE 'PASS: cancelled items, repeat top-ups, checkout uniqueness, manual discount authorization/audit, atomic kitchen closure, injected rollback';
  -- Mixed canonical QR/manual orders: cancelled QR lines charge/deduct zero,
  -- order-level totals/points must sum to the one settlement (not multiplied).
  v_session_id := gen_random_uuid();
  INSERT INTO public.ban_sessions(id,store_id,table_id) VALUES(v_session_id,v_store_id,v_table_id);
  FOR i IN 1..2 LOOP
    v_qr_order_id := gen_random_uuid(); v_qr_item_id := gen_random_uuid(); v_session_item_id := gen_random_uuid();
    INSERT INTO public.orders(id,store_id,order_number,status,subtotal,total,total_amount)
    VALUES(v_qr_order_id,v_store_id,public.generate_daily_order_number_v1(v_store_id),'pending',30000,30000,30000);
    INSERT INTO public.order_items(id,store_id,order_id,product_id,name,product_name,quantity,qty,unit_price,subtotal)
    VALUES(v_qr_item_id,v_store_id,v_qr_order_id,v_prod_id,'QR','QR',1,1,30000,30000);
    INSERT INTO public.ban_session_items(id,store_id,session_id,product_id,product_name,quantity,unit_price,subtotal,kitchen_status)
    VALUES(v_session_item_id,v_store_id,v_session_id,v_prod_id,'QR',1,30000,30000,CASE WHEN i=2 THEN 'huy' ELSE 'da_gui' END);
    INSERT INTO public.ban_session_orders(store_id,session_id,order_id) VALUES(v_store_id,v_session_id,v_qr_order_id);
    INSERT INTO public.ban_session_order_items(store_id,session_id,session_item_id,order_id,order_item_id)
    VALUES(v_store_id,v_session_id,v_session_item_id,v_qr_order_id,v_qr_item_id);
  END LOOP;
  INSERT INTO public.ban_session_items(store_id,session_id,product_id,product_name,quantity,unit_price,subtotal)
  VALUES(v_store_id,v_session_id,v_prod_id,'Manual',2,30000,60000);
  v_pos_res := public.settle_ban_session_v5(v_session_id,v_store_id,'cash','mixed-orders',v_customer_id,3,3000);
  ASSERT (v_pos_res->>'success')::boolean, v_pos_res::text;
  ASSERT (v_pos_res->'data'->>'total_amount')::numeric = 87000;
  ASSERT (SELECT sum(o.total_amount)=87000 AND sum(o.loyalty_pts_used)=3
    FROM public.orders o JOIN public.ban_session_orders bso ON o.id=bso.order_id WHERE bso.session_id=v_session_id);
  ASSERT (SELECT sum(delta)=-3 FROM public.stock_movements WHERE reference_id=(v_pos_res->'data'->>'settlement_id')::uuid);
  RAISE NOTICE 'PASS: mixed QR/manual/cancelled canonical orders reconcile to one settlement';
  UPDATE public.daily_order_counters SET last_seq = 999 WHERE store_id = v_store_id AND prefix = 'QN';
  v_num1 := public.generate_daily_order_number_v1(v_store_id, 'QN');
  ASSERT v_num1 LIKE '%-1000', v_num1;
END $$;

ROLLBACK;
