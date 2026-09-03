-- Runtime test against a schema-only clone of the current production database.
-- Every fixture and side effect is rolled back.

BEGIN;

DO $$
DECLARE
  v_store_id uuid := gen_random_uuid();
  v_user_id uuid := gen_random_uuid();
  v_membership_id uuid := gen_random_uuid();
  v_table_uuid uuid := gen_random_uuid();
  v_product_id uuid := gen_random_uuid();
  v_session_id uuid := gen_random_uuid();
  v_result jsonb;
  v_replay jsonb;
  v_key text := 'production-schema-double-click';
BEGIN
  INSERT INTO public.user_accounts(id, phone, password_hash, display_name)
  VALUES (v_user_id, '+84900000000', crypt('gate-only-password', gen_salt('bf')), 'Gate Cashier');

  INSERT INTO public.stores(id, store_code, name, owner_user_id)
  VALUES (v_store_id, 'GATE' || substr(replace(v_store_id::text, '-', ''), 1, 8),
          'Settlement V5 Production Schema Gate', v_user_id);

  INSERT INTO public.store_members(id, user_id, store_id, role, is_owner)
  VALUES (v_membership_id, v_user_id, v_store_id, 'owner', true);

  INSERT INTO public.app_settings(store_id, key, value)
  VALUES
    (v_store_id, 'loyalty_rate', '10000'),
    (v_store_id, 'loyalty_redeem_rate', '1000'),
    (v_store_id, 'stamp_threshold', '10');

  INSERT INTO public.ban_zones(id, store_id, name, created_at)
  VALUES ('gate-zone', v_store_id, 'Gate Zone',
          extract(epoch FROM clock_timestamp())::bigint * 1000);

  INSERT INTO public.ban_dining_tables(
    id, store_id, zone_id, name, capacity, pos_x, pos_y, shape,
    table_width, table_height, sort_order, is_active, created_at, label
  ) VALUES (
    v_table_uuid::text, v_store_id, 'gate-zone', 'A10 Gate', 4, 100, 100,
    'rect', 90, 65, 0, true,
    extract(epoch FROM clock_timestamp())::bigint * 1000, 'A10 Gate'
  );

  INSERT INTO public.products(id, store_id, name, sell_price, cost_price_latest, stock_qty)
  VALUES (v_product_id, v_store_id, 'Gate Product', 106000, 50000, 10);

  INSERT INTO public.ban_sessions(id, store_id, table_id, status, waiter_id, total_amount)
  VALUES (v_session_id, v_store_id, v_table_uuid, 'open', v_user_id::text, 106000);

  INSERT INTO public.ban_session_items(
    store_id, session_id, product_id, product_name, unit_price, quantity,
    subtotal, kitchen_status, modifiers_json
  ) VALUES (
    v_store_id, v_session_id, v_product_id, 'Gate Product', 106000, 1,
    106000, 'da_gui', '[]'
  );

  PERFORM set_config('request.jwt.claim.sub', v_user_id::text, true);

  v_result := public.settle_ban_session_v5(
    v_session_id, v_store_id, 'cash', v_key, NULL, 0, 0, NULL, 0
  );
  IF v_result->>'success' <> 'true'
     OR v_result->'data'->>'is_replay' <> 'false'
     OR (v_result->'data'->>'total_amount')::numeric <> 106000 THEN
    RAISE EXCEPTION 'PRODUCTION_SCHEMA_TEST_FAIL: first settlement: %', v_result;
  END IF;

  v_replay := public.settle_ban_session_v5(
    v_session_id, v_store_id, 'cash', v_key, NULL, 0, 0, NULL, 0
  );
  IF v_replay->>'success' <> 'true'
     OR v_replay->'data'->>'is_replay' <> 'true' THEN
    RAISE EXCEPTION 'PRODUCTION_SCHEMA_TEST_FAIL: replay: %', v_replay;
  END IF;

  IF (SELECT count(*) FROM public.payment_settlements WHERE session_id = v_session_id) <> 1
     OR (SELECT count(*) FROM public.ban_session_orders WHERE session_id = v_session_id) <> 1
     OR (SELECT count(*) FROM public.orders WHERE source_id = v_session_id::text) <> 1
     OR (SELECT count(*) FROM public.finance_records
         WHERE reference_id = (v_result->'data'->>'settlement_id')::uuid) <> 1
     OR (SELECT count(*) FROM public.stock_movements
         WHERE reference_id = (v_result->'data'->>'settlement_id')::uuid) <> 1 THEN
    RAISE EXCEPTION 'PRODUCTION_SCHEMA_TEST_FAIL: duplicate or missing side effect';
  END IF;

  IF (SELECT status FROM public.ban_sessions WHERE id = v_session_id) <> 'closed' THEN
    RAISE EXCEPTION 'PRODUCTION_SCHEMA_TEST_FAIL: session not closed';
  END IF;

  IF (SELECT count(*) FROM public.staff_members WHERE id = v_user_id AND store_id = v_store_id) <> 1
     OR (SELECT count(*) FROM public.staff_members WHERE id = v_membership_id AND store_id = v_store_id) <> 0 THEN
    RAISE EXCEPTION 'PRODUCTION_SCHEMA_TEST_FAIL: cashier identity mapping is not canonical';
  END IF;

  RAISE NOTICE 'SETTLEMENT_V5_PRODUCTION_SCHEMA_TEST_PASS';
END;
$$;

ROLLBACK;
