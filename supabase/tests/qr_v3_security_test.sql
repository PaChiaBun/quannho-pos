-- SQL Test Suite 2: RLS Isolation, Effective Table Privilege Audit & Behavioral Query Denial Tests
-- File: supabase/tests/qr_v3_security_test.sql

BEGIN;

DO $$
DECLARE
  v_store_1   uuid := gen_random_uuid();
  v_store_2   uuid := gen_random_uuid();
  v_user_1    uuid := gen_random_uuid();
  v_dev_1     uuid := gen_random_uuid();
  v_chan_1    uuid := gen_random_uuid();
  v_chan_code text := 'tbl_' || encode(gen_random_bytes(16), 'hex');
  v_tbl_id    uuid := gen_random_uuid();
  v_prod_id   uuid := gen_random_uuid();

  v_hash      text;
  v_res       jsonb;
  v_denied    boolean;
  v_tbl       text;
BEGIN
  -- Insert Fixture Data
  INSERT INTO public.stores(id, store_code, name) VALUES (v_store_1, 'SECSTORE1', 'Security Store 1');
  INSERT INTO public.stores(id, store_code, name) VALUES (v_store_2, 'SECSTORE2', 'Security Store 2');

  v_hash := public.hash_pos_credential_v3('0909999888', '123456');
  INSERT INTO public.user_accounts(id, phone, password_hash, quick_pin) VALUES (v_user_1, '0909999888', v_hash, v_hash);
  INSERT INTO public.store_members(user_id, store_id, role, is_owner) VALUES (v_user_1, v_store_1, 'owner', true);
  INSERT INTO public.devices(id, store_id, device_name, device_role) VALUES (v_dev_1, v_store_1, 'POS Sec 1', 'manager');

  INSERT INTO public.ban_dining_tables(id, store_id, name) VALUES (v_tbl_id::text, v_store_1, 'Bàn Sec 1');
  INSERT INTO public.qr_channels(id, store_id, type, table_id, channel_code, name, is_active) VALUES (v_chan_1, v_store_1, 'table', v_tbl_id::text, v_chan_code, 'Bàn Sec 1', true);
  INSERT INTO public.app_settings(store_id, key, value) VALUES (v_store_1, 'qr_order_settings', '{"is_table_enabled": true, "is_counter_enabled": true}');

  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, station_code)
  VALUES (v_prod_id, v_store_1, 'Bò Né Sec', 100000.00, true, true, false, 'nong');

  -- Test 1: Customer RPC get_qr_menu_v3 works under current role
  v_res := public.get_qr_menu_v3(v_chan_code);
  IF (v_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: get_qr_menu_v3 failed for valid active channel: %', v_res;
  END IF;

  -- Test 2: Section 2 Effective Table Privilege Audit for anon on all 9 QR tables (SELECT, INSERT, UPDATE, DELETE)
  FOR v_tbl IN VALUES
    ('qr_channels'), ('qr_requests'), ('qr_request_items'), ('qr_audit_logs'),
    ('product_topping_links'), ('pos_device_sessions'), ('pos_store_bootstrap_state'),
    ('store_pairing_codes'), ('pos_auth_attempts')
  LOOP
    IF has_table_privilege('anon', format('%I.%I', 'public', v_tbl), 'SELECT') OR
       has_table_privilege('anon', format('%I.%I', 'public', v_tbl), 'INSERT') OR
       has_table_privilege('anon', format('%I.%I', 'public', v_tbl), 'UPDATE') OR
       has_table_privilege('anon', format('%I.%I', 'public', v_tbl), 'DELETE') THEN
      RAISE EXCEPTION 'TEST_FAIL: Table public.% has unauthorized privilege for role anon', v_tbl;
    END IF;
  END LOOP;

  -- Test 3: Section 2 Behavioral Query Denial under SET LOCAL ROLE anon
  SET LOCAL ROLE anon;

  FOR v_tbl IN VALUES
    ('qr_channels'), ('qr_requests'), ('qr_request_items'), ('qr_audit_logs'),
    ('product_topping_links'), ('pos_device_sessions'), ('pos_store_bootstrap_state'),
    ('store_pairing_codes'), ('pos_auth_attempts')
  LOOP
    v_denied := false;
    BEGIN
      EXECUTE format('SELECT 1 FROM public.%I LIMIT 1', v_tbl);
    EXCEPTION WHEN insufficient_privilege THEN
      v_denied := true;
    END;

    IF NOT v_denied THEN
      RAISE EXCEPTION 'TEST_FAIL: Behavioral SELECT on public.% not denied for anon', v_tbl;
    END IF;
  END LOOP;

  -- Test 4: Verify execution of internal helpers and maintenance routines is DENIED for anon
  v_denied := false;
  BEGIN PERFORM public.hash_pos_credential_v3('0901234567', '123456'); EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'TEST_FAIL: Internal helper hash_pos_credential_v3 not denied for anon'; END IF;

  v_denied := false;
  BEGIN PERFORM * FROM public.verify_pos_token_internal('0000000000000000000000000000000000000000000000000000000000000000'); EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'TEST_FAIL: Internal helper verify_pos_token_internal not denied for anon'; END IF;

  v_denied := false;
  BEGIN PERFORM public.check_pos_staff_action_permission(v_store_1, NULL, v_user_1, 'qr_order.claim'); EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'TEST_FAIL: Internal helper check_pos_staff_action_permission not denied for anon'; END IF;

  v_denied := false;
  BEGIN PERFORM public.cleanup_expired_qr_requests_v3(); EXCEPTION WHEN insufficient_privilege THEN v_denied := true; END;
  IF NOT v_denied THEN RAISE EXCEPTION 'TEST_FAIL: Maintenance RPC cleanup_expired_qr_requests_v3 not denied for anon'; END IF;

  RESET ROLE;

  RAISE NOTICE 'TEST_BEHAVIORAL_PASS: Effective 4-operation table privilege audit & behavioral query denials executed clean';
END $$;

ROLLBACK;
