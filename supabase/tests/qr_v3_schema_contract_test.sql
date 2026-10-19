-- SQL Test Suite 1: Schema Contract, Manifest Signature Audit & Helper Behavioral Tests
-- File: supabase/tests/qr_v3_schema_contract_test.sql

BEGIN;

DO $$
DECLARE
  v_store_id    uuid := gen_random_uuid();
  v_user_id     uuid := gen_random_uuid();
  v_staff_id    uuid := gen_random_uuid();

  v_table_cnt   integer;
  v_passed_cnt  integer := 0;
  v_overload_cnt integer;
  v_hash_res    text;
  v_perm_res    boolean;
  v_manifest_rec RECORD;
  v_proc_rec    RECORD;
BEGIN
  -- 1. Structural Checks: 9 New Tables
  SELECT COUNT(*) INTO v_table_cnt
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name IN ('qr_channels', 'qr_requests', 'qr_request_items', 'qr_audit_logs', 'product_topping_links', 'pos_device_sessions', 'pos_store_bootstrap_state', 'store_pairing_codes', 'pos_auth_attempts');

  IF v_table_cnt <> 9 THEN
    RAISE EXCEPTION 'TEST_FAIL: Expected 9 QR tables, found %', v_table_cnt;
  END IF;

  -- 2. Section 1 Exact Postflight Manifest Audit Table for all 26 routines (No 'public' pseudo-role in has_function_privilege, aclexplode check for PUBLIC grantee 0)
  FOR v_manifest_rec IN
    SELECT * FROM (VALUES
      ('get_qr_menu_v3', 'p_channel_code text', true, 'rpc'),
      ('submit_qr_order_v3', 'p_channel_code text, p_items jsonb, p_note text, p_idempotency_key text, p_tracking_token text', true, 'rpc'),
      ('get_qr_request_status_v3', 'p_tracking_token text', true, 'rpc'),
      ('bootstrap_first_pos_device_v3', 'p_store_code text, p_credential text, p_device_name text', true, 'rpc'),
      ('generate_pos_pairing_code_v3', 'p_raw_token text, p_device_role text', true, 'rpc'),
      ('pair_pos_device_v3', 'p_store_code text, p_pairing_code text, p_device_name text, p_device_role text', true, 'rpc'),
      ('issue_pos_device_session_v3', 'p_store_code text, p_auth_mode text, p_principal_id uuid, p_credential text, p_device_id uuid', true, 'rpc'),
      ('revoke_pos_device_session_v3', 'p_raw_token text', true, 'rpc'),
      ('admin_revoke_device_session_v3', 'p_raw_token text, p_target_session_id uuid', true, 'rpc'),
      ('list_pos_device_sessions_v3', 'p_raw_token text', true, 'rpc'),
      ('get_pending_qr_requests_v3', 'p_raw_token text, p_status text, p_limit integer, p_before timestamp with time zone', true, 'rpc'),
      ('claim_qr_request_v3', 'p_request_id uuid, p_raw_token text', true, 'rpc'),
      ('confirm_qr_request_v3', 'p_request_id uuid, p_raw_token text', true, 'rpc'),
      ('reject_qr_request_v3', 'p_request_id uuid, p_raw_token text, p_reject_reason text', true, 'rpc'),
      ('send_to_kitchen_qr_v3', 'p_request_id uuid, p_raw_token text', true, 'rpc'),
      ('list_qr_channels_v3', 'p_raw_token text', true, 'rpc'),
      ('upsert_qr_channel_v3', 'p_raw_token text, p_type text, p_table_id text, p_name text', true, 'rpc'),
      ('rotate_qr_channel_v3', 'p_raw_token text, p_channel_id uuid', true, 'rpc'),
      ('set_qr_channel_active_v3', 'p_raw_token text, p_channel_id uuid, p_is_active boolean', true, 'rpc'),
      ('get_qr_settings_v3', 'p_raw_token text', true, 'rpc'),
      ('save_qr_settings_v3', 'p_raw_token text, p_settings jsonb', true, 'rpc'),
      ('cleanup_expired_qr_requests_v3', '', true, 'service_role'),
      ('cleanup_pos_auth_attempts_v3', '', true, 'service_role'),
      -- Internal Helpers
      ('hash_pos_credential_v3', 'p_phone text, p_credential text', false, 'internal'),
      ('verify_pos_token_internal', 'p_raw_token text', true, 'internal'),
      ('check_pos_staff_action_permission', 'p_store_id uuid, p_staff_id uuid, p_user_account_id uuid, p_action_key text', true, 'internal')
    ) AS m(func_name, identity_args, exp_secdef, category)
  LOOP
    -- Overload Check: Check if any unexpected overload exists outside the manifest
    SELECT COUNT(*) INTO v_overload_cnt
    FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = v_manifest_rec.func_name;

    IF v_overload_cnt <> 1 THEN
      RAISE EXCEPTION 'TEST_FAIL: Routine public.% has unexpected overload count: % (expected 1)', v_manifest_rec.func_name, v_overload_cnt;
    END IF;

    -- Query catalog for exact match including aclexplode check for PUBLIC (grantee 0)
    SELECT p.oid, p.prosecdef, p.proconfig, pg_get_userbyid(p.proowner) AS owner_name,
      EXISTS (
        SELECT 1 FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) a
        WHERE a.grantee = 0 AND a.privilege_type = 'EXECUTE'
      ) AS has_public_acl
    INTO v_proc_rec
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = v_manifest_rec.func_name
      AND pg_get_function_identity_arguments(p.oid) = v_manifest_rec.identity_args;

    IF v_proc_rec.oid IS NULL THEN
      RAISE EXCEPTION 'TEST_FAIL: Routine public.%(%) is missing or signature mismatched', v_manifest_rec.func_name, v_manifest_rec.identity_args;
    END IF;

    IF v_proc_rec.owner_name <> 'postgres' THEN
      RAISE EXCEPTION 'TEST_FAIL: Routine public.% owner is %, expected postgres', v_manifest_rec.func_name, v_proc_rec.owner_name;
    END IF;

    IF v_manifest_rec.exp_secdef THEN
      IF v_proc_rec.prosecdef IS NOT TRUE THEN
        RAISE EXCEPTION 'TEST_FAIL: Routine public.% expected prosecdef=true', v_manifest_rec.func_name;
      END IF;
      IF v_proc_rec.proconfig IS NULL OR NOT (v_proc_rec.proconfig::text LIKE '%search_path=public, pg_temp%') THEN
        RAISE EXCEPTION 'TEST_FAIL: Routine public.% missing fixed search_path', v_manifest_rec.func_name;
      END IF;
    ELSE
      IF v_proc_rec.prosecdef IS TRUE THEN
        RAISE EXCEPTION 'TEST_FAIL: Routine public.% expected prosecdef=false', v_manifest_rec.func_name;
      END IF;
    END IF;

    -- Section 1: PUBLIC EXECUTE ACL MUST BE FALSE FOR ALL 26 ROUTINES
    IF v_proc_rec.has_public_acl IS TRUE THEN
      RAISE EXCEPTION 'TEST_FAIL: Routine public.% has PUBLIC EXECUTE ACL in proacl', v_manifest_rec.func_name;
    END IF;

    -- Verify Execution Privilege Category using exact roles (no pseudo-role 'public')
    IF v_manifest_rec.category IN ('internal', 'service_role') THEN
      IF has_function_privilege('anon', v_proc_rec.oid, 'EXECUTE') OR
         has_function_privilege('authenticated', v_proc_rec.oid, 'EXECUTE') THEN
        RAISE EXCEPTION 'TEST_FAIL: Routine public.% is executable by anon or authenticated', v_manifest_rec.func_name;
      END IF;
    END IF;

    IF v_manifest_rec.category = 'service_role' THEN
      IF NOT has_function_privilege('service_role', v_proc_rec.oid, 'EXECUTE') THEN
        RAISE EXCEPTION 'TEST_FAIL: Maintenance RPC public.% is not executable by service_role', v_manifest_rec.func_name;
      END IF;
    ELSIF v_manifest_rec.category = 'rpc' THEN
      IF NOT (has_function_privilege('anon', v_proc_rec.oid, 'EXECUTE') AND has_function_privilege('authenticated', v_proc_rec.oid, 'EXECUTE')) THEN
        RAISE EXCEPTION 'TEST_FAIL: Public RPC public.% is missing EXECUTE grant for anon or authenticated', v_manifest_rec.func_name;
      END IF;
    END IF;

    v_passed_cnt := v_passed_cnt + 1;
  END LOOP;

  IF v_passed_cnt <> 26 THEN
    RAISE EXCEPTION 'TEST_FAIL: Expected 26 manifest routines, checked %', v_passed_cnt;
  END IF;

  -- 3. Behavioral Test: hash_pos_credential_v3 (Valid & STRICT NULL handling)
  v_hash_res := public.hash_pos_credential_v3('0901234567', '123456');
  IF v_hash_res IS NULL OR v_hash_res !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'TEST_FAIL: hash_pos_credential_v3 produced invalid hash format: %', v_hash_res;
  END IF;

  IF public.hash_pos_credential_v3(NULL, '123456') IS NOT NULL THEN
    RAISE EXCEPTION 'TEST_FAIL: hash_pos_credential_v3 did not return NULL for NULL phone';
  END IF;

  -- Insert Fixture Data
  INSERT INTO public.stores(id, store_code, name) VALUES (v_store_id, 'TESTSTORE1', 'Store Test 1');
  INSERT INTO public.user_accounts(id, phone, password_hash, quick_pin) VALUES (v_user_id, '0901234567', v_hash_res, v_hash_res);
  INSERT INTO public.store_members(user_id, store_id, role, is_owner) VALUES (v_user_id, v_store_id, 'owner', true);
  INSERT INTO public.staff_members(id, store_id, name, role, pin_hash, is_active) VALUES (v_staff_id, v_store_id, 'NV Test', 'waiter', encode(digest(convert_to('123456', 'UTF8'), 'sha256'), 'hex'), true);

  -- 4. Behavioral Test: check_pos_staff_action_permission
  -- Owner override test
  v_perm_res := public.check_pos_staff_action_permission(v_store_id, NULL, v_user_id, 'qr_order.manage_settings');
  IF v_perm_res IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: Owner permission check failed (expected true, got false)';
  END IF;

  -- Unknown action key fail-closed test
  v_perm_res := public.check_pos_staff_action_permission(v_store_id, NULL, v_user_id, 'invalid.action_key');
  IF v_perm_res IS NOT FALSE THEN
    RAISE EXCEPTION 'TEST_FAIL: Invalid action key did not fail closed (expected false, got true)';
  END IF;

  -- Non-manager waiter without app_settings test (must fail-closed false)
  v_perm_res := public.check_pos_staff_action_permission(v_store_id, v_staff_id, NULL, 'qr_order.claim');
  IF v_perm_res IS NOT FALSE THEN
    RAISE EXCEPTION 'TEST_FAIL: Non-manager without setting did not fail closed (expected false, got true)';
  END IF;

  -- Grant app_settings for waiter
  INSERT INTO public.app_settings(store_id, key, value) VALUES (v_store_id, 'action_perms_waiter', '["qr_order.view_pending", "qr_order.claim"]');

  v_perm_res := public.check_pos_staff_action_permission(v_store_id, v_staff_id, NULL, 'qr_order.claim');
  IF v_perm_res IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: Granted waiter permission check failed (expected true, got false)';
  END IF;

  RAISE NOTICE 'TEST_BEHAVIORAL_PASS: Schema contract, exact manifest signature audit, overload & privilege checks executed clean';
END $$;

ROLLBACK;
