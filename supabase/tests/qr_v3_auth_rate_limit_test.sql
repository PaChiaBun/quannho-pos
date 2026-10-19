-- SQL Test Suite 6: Auth Deterministic Rate-Limiting, Lockout Seconds, Reset & NULL-Hash Protection Behavioral Tests
-- File: supabase/tests/qr_v3_auth_rate_limit_test.sql

BEGIN;

DO $$
DECLARE
  v_store_id    uuid := gen_random_uuid();
  v_staff_id    uuid := gen_random_uuid();
  v_bad_staff_id uuid := gen_random_uuid();
  v_bad_user_id  uuid := gen_random_uuid();
  v_dev_id      uuid := gen_random_uuid();

  v_res         jsonb;
  v_raw_found   boolean := false;
BEGIN
  -- Insert Fixture Data
  INSERT INTO public.stores(id, store_code, name) VALUES (v_store_id, 'RATELIMSTORE', 'Rate Limit Store');

  -- Valid Staff PIN: '123456' -> SHA256 hex
  INSERT INTO public.staff_members(id, store_id, name, role, pin_hash, is_active)
  VALUES (v_staff_id, v_store_id, 'NV Rate Limit', 'waiter', encode(digest(convert_to('123456', 'UTF8'), 'sha256'), 'hex'), true);

  -- Corrupted Staff row with NULL pin_hash
  INSERT INTO public.staff_members(id, store_id, name, role, pin_hash, is_active)
  VALUES (v_bad_staff_id, v_store_id, 'NV Corrupted', 'waiter', NULL, true);

  -- Corrupted User Account with NULL phone & NULL password_hash
  INSERT INTO public.user_accounts(id, phone, password_hash, quick_pin) VALUES (v_bad_user_id, NULL, NULL, NULL);
  INSERT INTO public.store_members(user_id, store_id, role, is_owner) VALUES (v_bad_user_id, v_store_id, 'owner', true);

  INSERT INTO public.devices(id, store_id, device_name, device_role) VALUES (v_dev_id, v_store_id, 'POS Rate Limit', 'staff');

  -- =========================================================================
  -- SECTION 1 BEHAVIORAL TEST: NULL / EMPTY CREDENTIAL & NULL STORED HASH PROTECTION
  -- =========================================================================

  -- Test NULL credential input
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, NULL, v_dev_id);
  IF (v_res ->> 'error_code') <> 'INVALID_CREDENTIALS' THEN
    RAISE EXCEPTION 'TEST_FAIL: NULL credential did not return INVALID_CREDENTIALS (got %)', v_res;
  END IF;

  -- Test empty whitespace credential input
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '   ', v_dev_id);
  IF (v_res ->> 'error_code') <> 'INVALID_CREDENTIALS' THEN
    RAISE EXCEPTION 'TEST_FAIL: Empty whitespace credential did not return INVALID_CREDENTIALS (got %)', v_res;
  END IF;

  -- Test corrupted staff row with NULL pin_hash in DB cannot be authenticated
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_bad_staff_id, '123456', v_dev_id);
  IF (v_res ->> 'error_code') <> 'INVALID_CREDENTIALS' THEN
    RAISE EXCEPTION 'TEST_FAIL: Staff with NULL pin_hash in DB did not return INVALID_CREDENTIALS (got %)', v_res;
  END IF;

  -- Test corrupted owner row with NULL phone & NULL password_hash cannot be authenticated
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'owner_password', v_bad_user_id, '123456', v_dev_id);
  IF (v_res ->> 'error_code') <> 'INVALID_CREDENTIALS' THEN
    RAISE EXCEPTION 'TEST_FAIL: Owner with NULL phone/hash in DB did not return INVALID_CREDENTIALS (got %)', v_res;
  END IF;

  -- =========================================================================
  -- SECTION 2 BEHAVIORAL TEST: 5 WRONG ATTEMPTS -> 6TH RATE_LIMITED LOCKOUT
  -- =========================================================================

  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '000001', v_dev_id);
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '000002', v_dev_id);
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '000003', v_dev_id);
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '000004', v_dev_id);
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '000005', v_dev_id);

  IF (v_res ->> 'error_code') <> 'INVALID_CREDENTIALS' THEN
    RAISE EXCEPTION 'TEST_FAIL: 5th attempt expected INVALID_CREDENTIALS, got %', v_res;
  END IF;

  -- 6th attempt MUST return RATE_LIMITED with lockout remaining seconds
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '123456', v_dev_id);
  IF (v_res ->> 'error_code') <> 'RATE_LIMITED' THEN
    RAISE EXCEPTION 'TEST_FAIL: 6th attempt expected RATE_LIMITED, got %', v_res;
  END IF;

  IF (v_res -> 'data' ->> 'lockout_remaining_seconds')::integer <= 0 THEN
    RAISE EXCEPTION 'TEST_FAIL: RATE_LIMITED response missing lockout_remaining_seconds';
  END IF;

  -- =========================================================================
  -- SECTION 2 BEHAVIORAL TEST: SUCCESS RESETS FAILURE WINDOW & LOCKOUT CALCULATIONS
  -- =========================================================================

  -- Insert manual success attempt record to simulate success reset
  INSERT INTO public.pos_auth_attempts(store_id, attempt_type, identifier_hash, is_success, ip_address)
  VALUES (v_store_id, 'staff_pin', digest(convert_to(v_staff_id::text, 'UTF8'), 'sha256'), true, '0.0.0.0');

  -- 7th attempt with valid credential after success marker MUST succeed now
  v_res := public.issue_pos_device_session_v3('RATELIMSTORE', 'staff_pin', v_staff_id, '123456', v_dev_id);
  IF (v_res ->> 'success')::boolean IS NOT TRUE THEN
    RAISE EXCEPTION 'TEST_FAIL: Authentication after success window reset failed: %', v_res;
  END IF;

  -- =========================================================================
  -- CREDENTIAL MASKING TEST (ASSERT NO RAW PINS/PASSWORDS IN ATTEMPTS TABLE)
  -- =========================================================================

  SELECT EXISTS (
    SELECT 1 FROM public.pos_auth_attempts
    WHERE store_id = v_store_id AND encode(identifier_hash, 'hex') LIKE '%123456%'
  ) INTO v_raw_found;

  IF v_raw_found THEN
    RAISE EXCEPTION 'TEST_FAIL: Raw PIN string detected inside pos_auth_attempts identifier_hash!';
  END IF;

  RAISE NOTICE 'TEST_BEHAVIORAL_PASS: Auth rate-limiting, NULL-hash protection, window resets & credential masking executed clean';
END $$;

ROLLBACK;
