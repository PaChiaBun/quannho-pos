-- SQL Test Suite 3: QR State Machine, Claimant Guard, Fail-Closed Settings & Canonical Idempotency Behavioral Tests
-- File: supabase/tests/qr_v3_state_machine_test.sql

BEGIN;

DO $$
DECLARE
  v_store_id    uuid := gen_random_uuid();
  v_user_1      uuid := gen_random_uuid();
  v_user_2      uuid := gen_random_uuid();
  v_dev_1       uuid := gen_random_uuid();
  v_dev_2       uuid := gen_random_uuid();
  v_tbl_id      uuid := gen_random_uuid();
  v_chan_id     uuid := gen_random_uuid();
  v_chan_code   text := 'tbl_' || encode(gen_random_bytes(16), 'hex');

  v_prod_1      uuid := gen_random_uuid();
  v_prod_2      uuid := gen_random_uuid();
  v_top_a       uuid := gen_random_uuid();
  v_top_b       uuid := gen_random_uuid();

  v_token_1     text;
  v_token_2     text;
  v_hash_1      text;
  v_hash_2      text;

  v_submit_res  jsonb;
  v_retry_res   jsonb;
  v_set_res     jsonb;
  v_settings_data jsonb;
  v_req_id_1    uuid;
  v_req_id_2    uuid;
  v_claim_res   jsonb;
  v_conf_res    jsonb;
  v_rej_res     jsonb;
  v_exp_res     jsonb;
  v_token_raw   text := encode(gen_random_bytes(32), 'hex');
  v_status      text;
  v_err_thrown  boolean := false;
BEGIN
  -- Insert Fixture Data
  INSERT INTO public.stores(id, store_code, name) VALUES (v_store_id, 'STATESTORE1', 'State Store 1');

  v_hash_1 := public.hash_pos_credential_v3('0911111111', '111111');
  INSERT INTO public.user_accounts(id, phone, password_hash, quick_pin) VALUES (v_user_1, '0911111111', v_hash_1, v_hash_1);
  INSERT INTO public.store_members(user_id, store_id, role, is_owner) VALUES (v_user_1, v_store_id, 'owner', true);
  INSERT INTO public.devices(id, store_id, device_name, device_role) VALUES (v_dev_1, v_store_id, 'POS State 1', 'manager');

  v_hash_2 := public.hash_pos_credential_v3('0922222222', '222222');
  INSERT INTO public.user_accounts(id, phone, password_hash, quick_pin) VALUES (v_user_2, '0922222222', v_hash_2, v_hash_2);
  INSERT INTO public.store_members(user_id, store_id, role, is_owner) VALUES (v_user_2, v_store_id, 'owner', true);
  INSERT INTO public.devices(id, store_id, device_name, device_role) VALUES (v_dev_2, v_store_id, 'POS State 2', 'manager');

  INSERT INTO public.ban_dining_tables(id, store_id, name) VALUES (v_tbl_id::text, v_store_id, 'Bàn State 1');
  INSERT INTO public.qr_channels(id, store_id, type, table_id, channel_code, name, is_active) VALUES (v_chan_id, v_store_id, 'table', v_tbl_id::text, v_chan_code, 'Bàn State 1', true);
  INSERT INTO public.app_settings(store_id, key, value) VALUES (v_store_id, 'qr_order_settings', '{"is_table_enabled": true, "is_counter_enabled": true}');

  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, station_code) VALUES (v_prod_1, v_store_id, 'Cơm Chiên 1', 50000.00, true, true, false, 'nong');
  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, station_code) VALUES (v_prod_2, v_store_id, 'Lẩu Nấm 2', 150000.00, true, true, false, 'nong');

  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, is_topping, station_code) VALUES (v_top_a, v_store_id, 'Topping A', 10000.00, true, true, false, true, 'nong');
  INSERT INTO public.products(id, store_id, name, sell_price, is_active, is_available, is_deleted, is_topping, station_code) VALUES (v_top_b, v_store_id, 'Topping B', 15000.00, true, true, false, true, 'nong');

  INSERT INTO public.product_topping_links(product_id, topping_id) VALUES (v_prod_1, v_top_a);
  INSERT INTO public.product_topping_links(product_id, topping_id) VALUES (v_prod_1, v_top_b);

  -- Issue Staff Tokens
  v_submit_res := public.issue_pos_device_session_v3('STATESTORE1', 'owner_password', v_user_1, '111111', v_dev_1);
  v_token_1 := v_submit_res -> 'data' ->> 'session_token';

  v_submit_res := public.issue_pos_device_session_v3('STATESTORE1', 'owner_password', v_user_2, '222222', v_dev_2);
  v_token_2 := v_submit_res -> 'data' ->> 'session_token';

  -- =========================================================================
  -- SECTION 3 & 4: FAIL-CLOSED SETTINGS & PARTIAL OBJECT MERGE ASSERTION
  -- =========================================================================

  -- Section 3 Test: Store a partial object (only 1 key: is_table_enabled) and verify get_qr_settings_v3 merges defaults & returns exact 5 canonical keys
  UPDATE public.app_settings SET value = '{"is_table_enabled": true}' WHERE store_id = v_store_id AND key = 'qr_order_settings';
  v_set_res := public.get_qr_settings_v3(v_token_1);
  IF (v_set_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: get_qr_settings_v3 failed on partial object: %', v_set_res;
  END IF;

  v_settings_data := v_set_res -> 'data' -> 'settings';
  IF NOT (v_settings_data ? 'is_table_enabled' AND
          v_settings_data ? 'is_counter_enabled' AND
          v_settings_data ? 'auto_claim' AND
          v_settings_data ? 'sound_enabled' AND
          v_settings_data ? 'public_domain') THEN
    RAISE EXCEPTION 'TEST_FAIL: get_qr_settings_v3 did not return all 5 canonical keys for partial object: %', v_settings_data;
  END IF;

  IF (v_settings_data ->> 'is_table_enabled')::boolean IS NOT TRUE OR
     (v_settings_data ->> 'is_counter_enabled')::boolean IS NOT FALSE OR
     (v_settings_data ->> 'sound_enabled')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: get_qr_settings_v3 default values on partial object mismatched: %', v_settings_data;
  END IF;

  -- Save invalid unknown key -> QR_SETTINGS_INVALID
  v_set_res := public.save_qr_settings_v3(v_token_1, '{"is_table_enabled": true, "unknown_key_xyz": 123}'::jsonb);
  IF (v_set_res ->> 'error_code') <> 'QR_SETTINGS_INVALID' THEN
    RAISE EXCEPTION 'TEST_FAIL: save_qr_settings_v3 with unknown key did not return QR_SETTINGS_INVALID (got %)', v_set_res;
  END IF;

  -- Save wrong boolean type -> QR_SETTINGS_INVALID
  v_set_res := public.save_qr_settings_v3(v_token_1, '{"is_table_enabled": "not_a_boolean"}'::jsonb);
  IF (v_set_res ->> 'error_code') <> 'QR_SETTINGS_INVALID' THEN
    RAISE EXCEPTION 'TEST_FAIL: save_qr_settings_v3 with string boolean did not return QR_SETTINGS_INVALID (got %)', v_set_res;
  END IF;

  -- Save bad public_domain (http instead of https) -> QR_SETTINGS_INVALID
  v_set_res := public.save_qr_settings_v3(v_token_1, '{"public_domain": "http://insecure.com"}'::jsonb);
  IF (v_set_res ->> 'error_code') <> 'QR_SETTINGS_INVALID' THEN
    RAISE EXCEPTION 'TEST_FAIL: save_qr_settings_v3 with non-HTTPS domain did not return QR_SETTINGS_INVALID (got %)', v_set_res;
  END IF;

  -- Verify get_qr_menu_v3 fails closed when stored settings in DB are corrupted (non-object)
  UPDATE public.app_settings SET value = '"corrupted_string_value"' WHERE store_id = v_store_id AND key = 'qr_order_settings';
  v_set_res := public.get_qr_menu_v3(v_chan_code);
  IF (v_set_res ->> 'error_code') <> 'QR_SETTINGS_INVALID' THEN
    RAISE EXCEPTION 'TEST_FAIL: get_qr_menu_v3 on corrupted string setting did not fail closed with QR_SETTINGS_INVALID (got %)', v_set_res;
  END IF;

  -- Restore valid settings
  UPDATE public.app_settings SET value = '{"is_table_enabled": true, "is_counter_enabled": true}' WHERE store_id = v_store_id AND key = 'qr_order_settings';

  -- =========================================================================
  -- SECTION C: CANONICAL IDEMPOTENCY & UNRELATED UNIQUE VIOLATION RETHROW TESTS
  -- =========================================================================

  -- Initial valid submit (Toppings B then A)
  v_submit_res := public.submit_qr_order_v3(
    v_chan_code,
    jsonb_build_array(
      jsonb_build_object('product_id', v_prod_2, 'quantity', 1),
      jsonb_build_object('product_id', v_prod_1, 'quantity', 1, 'modifiers', jsonb_build_array(v_top_b, v_top_a))
    ),
    ' Note trimmed ', 'idem_canon_1', v_token_raw
  );
  IF (v_submit_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: Initial submit_qr_order_v3 failed: %', v_submit_res;
  END IF;
  v_req_id_1 := (v_submit_res -> 'data' ->> 'request_id')::uuid;

  -- Unrelated unique_violation during insert (e.g. tracking token collision with existing request) MUST be RAISED
  BEGIN
    PERFORM public.submit_qr_order_v3(
      v_chan_code,
      jsonb_build_array(jsonb_build_object('product_id', v_prod_1, 'quantity', 1)),
      'Unique collision test', 'idem_new_key_123', v_token_raw -- Same tracking token hash as request 1
    );
  EXCEPTION WHEN unique_violation THEN
    v_err_thrown := true;
  END;

  IF NOT v_err_thrown THEN
    RAISE EXCEPTION 'TEST_FAIL: Unrelated unique_violation on tracking_token_hash was not rethrown to caller!';
  END IF;

  -- =========================================================================
  -- STATE MACHINE & CLAIMANT GUARD TESTS
  -- =========================================================================

  -- Step 1: Staff 1 Claims Order
  v_claim_res := public.claim_qr_request_v3(v_req_id_1, v_token_1);
  IF (v_claim_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: claim_qr_request_v3 failed: %', v_claim_res;
  END IF;

  -- Step 2: Staff 2 Tries to Confirm (Must fail with CLAIMANT_MISMATCH)
  v_conf_res := public.confirm_qr_request_v3(v_req_id_1, v_token_2);
  IF (v_conf_res ->> 'error_code') <> 'CLAIMANT_MISMATCH' THEN
    RAISE EXCEPTION 'TEST_FAIL: Claimant mismatch not enforced (expected CLAIMANT_MISMATCH, got %)', v_conf_res;
  END IF;

  -- Step 3: Staff 1 Confirms Order
  v_conf_res := public.confirm_qr_request_v3(v_req_id_1, v_token_1);
  IF (v_conf_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: confirm_qr_request_v3 failed for claimant: %', v_conf_res;
  END IF;

  -- Step 4: Reject Order with reason
  v_rej_res := public.reject_qr_request_v3(v_req_id_1, v_token_1, 'Hết nguyên liệu chiên');
  IF (v_rej_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: reject_qr_request_v3 failed with reason: %', v_rej_res;
  END IF;

  -- Step 5: Test 30-min Maintenance Expiry
  v_submit_res := public.submit_qr_order_v3(
    v_chan_code,
    jsonb_build_array(jsonb_build_object('product_id', v_prod_2, 'quantity', 1)),
    '',
    'idempotency_expiry_1',
    encode(gen_random_bytes(32), 'hex')
  );
  v_req_id_2 := (v_submit_res -> 'data' ->> 'request_id')::uuid;

  UPDATE public.qr_requests SET created_at = now() - INTERVAL '31 minutes' WHERE id = v_req_id_2;

  v_exp_res := public.cleanup_expired_qr_requests_v3();
  IF (v_exp_res -> 'data' ->> 'expired_count')::integer < 1 THEN
    RAISE EXCEPTION 'TEST_FAIL: cleanup_expired_qr_requests_v3 did not expire 31-min old request';
  END IF;

  SELECT status INTO v_status FROM public.qr_requests WHERE id = v_req_id_2;
  IF v_status <> 'expired' THEN
    RAISE EXCEPTION 'TEST_FAIL: Request status expected expired, got %', v_status;
  END IF;

  RAISE NOTICE 'TEST_BEHAVIORAL_PASS: State machine, partial settings default merge & unrelated unique_violation rethrow executed clean';
END $$;

ROLLBACK;
