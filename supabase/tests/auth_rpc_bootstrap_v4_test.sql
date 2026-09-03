-- Auth RPC Bootstrap V4 integration test.
-- Run only on a disposable or isolated staging database after the matching
-- migration has been applied. All fixtures are rolled back.
BEGIN;

DO $$
DECLARE
  v_phone text := '+849' || lpad((floor(random() * 100000000))::bigint::text, 8, '0');
  v_phone_staff text := '+849' || lpad((floor(random() * 100000000))::bigint::text, 8, '0');
  v_register jsonb;
  v_register_staff jsonb;
  v_login jsonb;
  v_user_id uuid;
  v_staff_id uuid;
  v_store_res jsonb;
  v_store_id uuid;
  v_store_code text;
  v_join_res jsonb;
  v_pin_res jsonb;
  v_has_pin jsonb;
  v_verify_pin jsonb;
  v_hash text;
  v_attempt integer;
  v_proc record;

  -- Device pairing vars
  v_pair_res jsonb;
  v_pairing_code text;
  v_claim_res jsonb;
  v_claim_replay jsonb;
  v_sessions_res jsonb;
  v_dev_session_id uuid;

  -- Staff administration vars
  v_create_staff_res jsonb;
  v_new_staff_id uuid;
  v_update_role_res jsonb;
  v_self_escalate_res jsonb;
  v_lock_staff_res jsonb;
  v_revoke_staff_res jsonb;
  v_demote_owner_res jsonb;
BEGIN
  -- 1. Verify Security Definer, fixed search_path and no PUBLIC execution.
  SELECT p.prosecdef, p.proconfig,
         EXISTS (
           SELECT 1
           FROM aclexplode(COALESCE(p.proacl, acldefault('f', p.proowner))) acl
           WHERE acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
         ) AS public_execute
  INTO v_proc
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'verify_user_login_v4'
    AND pg_get_function_identity_arguments(p.oid) =
        'p_phone text, p_password text, p_store_id uuid';

  IF v_proc.prosecdef IS DISTINCT FROM true
     OR v_proc.proconfig IS NULL
     OR v_proc.proconfig::text NOT LIKE '%search_path=public, pg_temp%'
     OR v_proc.public_execute IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'TEST_FAIL: verify_user_login_v4 security contract invalid';
  END IF;

  -- 3. Register Owner User
  v_register := public.register_user_account_v4(v_phone, 'Correct-Horse-42', 'Auth Test Owner');
  IF (v_register->>'success')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: secure registration failed: %', v_register;
  END IF;
  v_user_id := (v_register->>'user_id')::uuid;

  SELECT password_hash INTO v_hash
  FROM public.user_accounts WHERE id = v_user_id;
  IF v_hash NOT LIKE '$2%' OR v_hash LIKE '%Correct-Horse-42%' THEN
    RAISE EXCEPTION 'TEST_FAIL: registration did not store a bcrypt hash';
  END IF;

  -- 4. Create Store Atomically as Owner (via RPC simulating authenticated context)
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  v_store_res := public.create_store_with_owner_v4('Quán Test Tự Động', 'TEST-AUTO');
  IF (v_store_res->>'success')::boolean IS DISTINCT FROM true
     OR (v_store_res->>'role') <> 'owner'
     OR (v_store_res->>'is_owner')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: create_store_with_owner_v4 failed: %', v_store_res;
  END IF;
  v_store_id := (v_store_res->>'store_id')::uuid;
  v_store_code := v_store_res->>'store_code';

  -- 5. Set & Check Quick PIN
  v_pin_res := public.set_user_quick_pin_v4('123456');
  IF (v_pin_res->>'success')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: set_user_quick_pin_v4 failed: %', v_pin_res;
  END IF;

  v_has_pin := public.has_user_quick_pin_v4();
  IF (v_has_pin->>'has_quick_pin')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: has_user_quick_pin_v4 returned false after setting pin: %', v_has_pin;
  END IF;

  -- 6. Register Staff User & Join Store
  v_register_staff := public.register_user_account_v4(v_phone_staff, 'Staff-Pass-99', 'Auth Test Staff');
  v_staff_id := (v_register_staff->>'user_id')::uuid;

  -- Set staff context
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_staff_id::text, 'role', 'authenticated')::text, true);

  v_join_res := public.join_store_by_code_v4(v_store_code);
  IF (v_join_res->>'success')::boolean IS DISTINCT FROM true
     OR (v_join_res->>'role') <> 'waiter'
     OR (v_join_res->>'is_owner')::boolean IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'TEST_FAIL: join_store_by_code_v4 failed: %', v_join_res;
  END IF;

  -- 7. Staff verifies Manager Quick PIN
  v_verify_pin := public.verify_manager_quick_pin_v4(v_store_id, '123456');
  IF (v_verify_pin->>'success')::boolean IS DISTINCT FROM true
     OR (v_verify_pin->>'manager_id')::uuid <> v_user_id THEN
    RAISE EXCEPTION 'TEST_FAIL: verify_manager_quick_pin_v4 failed: %', v_verify_pin;
  END IF;

  -- 8. Login & Rate Limiting Verification
  v_login := public.verify_user_login_v4(v_phone, 'Correct-Horse-42', v_store_id);
  IF (v_login->>'success')::boolean IS DISTINCT FROM true
     OR v_login->>'selected_role' <> 'owner' THEN
    RAISE EXCEPTION 'TEST_FAIL: correct login/membership failed: %', v_login;
  END IF;

  FOR v_attempt IN 1..5 LOOP
    v_login := public.verify_user_login_v4(v_phone, 'wrong-password', v_store_id);
    IF v_login->>'error_code' <> 'INVALID_CREDENTIALS' THEN
      RAISE EXCEPTION 'TEST_FAIL: failure % was not generic: %', v_attempt, v_login;
    END IF;
  END LOOP;
  v_login := public.verify_user_login_v4(v_phone, 'wrong-password', v_store_id);
  IF v_login->>'error_code' <> 'RATE_LIMIT_EXCEEDED' THEN
    RAISE EXCEPTION 'TEST_FAIL: sixth failure was not rate-limited: %', v_login;
  END IF;

  /* 9. Legacy POS device exploration only; intentionally excluded from the
     production auth migration because V3 owns incompatible table contracts.
  -- Switch context back to Owner
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  v_pair_res := public.create_device_pairing_code_v4(v_store_id, 'kitchen', 'Máy Bếp Trung Tâm', 900);
  IF (v_pair_res->>'success')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: create_device_pairing_code_v4 failed: %', v_pair_res;
  END IF;
  v_pairing_code := v_pair_res->>'pairing_code';

  -- Anonymous / Device claims code
  PERFORM set_config('request.jwt.claims', NULL, true);
  v_claim_res := public.claim_device_pairing_code_v4(v_pairing_code, 'device-mac-kitchen-01', 'Bếp Nóng');
  IF (v_claim_res->>'success')::boolean IS DISTINCT FROM true
     OR v_claim_res->>'role' <> 'kitchen'
     OR (v_claim_res->>'store_id')::uuid <> v_store_id THEN
    RAISE EXCEPTION 'TEST_FAIL: claim_device_pairing_code_v4 failed: %', v_claim_res;
  END IF;

  -- Replay must be rejected
  v_claim_replay := public.claim_device_pairing_code_v4(v_pairing_code, 'device-mac-kitchen-02', 'Bếp Lạnh');
  IF (v_claim_replay->>'success')::boolean IS NOT DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: replay claim of used pairing code succeeded unexpectedly';
  END IF;
  */

  -- 10. Staff Membership Administration Verification
  -- Switch back to Owner
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);

  v_create_staff_res := public.admin_create_staff_member_v4(
    v_store_id,
    'Nguyễn Văn Thu Ngân',
    v_phone_staff,
    'cashier'
  );
  IF (v_create_staff_res->>'success')::boolean IS DISTINCT FROM true
     OR v_create_staff_res->>'role' <> 'cashier' THEN
    RAISE EXCEPTION 'TEST_FAIL: admin_create_staff_member_v4 failed: %', v_create_staff_res;
  END IF;
  v_new_staff_id := (v_create_staff_res->>'staff_id')::uuid;

  -- Update role to kitchen
  v_update_role_res := public.admin_update_staff_role_v4(v_store_id, v_new_staff_id, 'kitchen');
  IF (v_update_role_res->>'success')::boolean IS DISTINCT FROM true
     OR v_update_role_res->>'role' <> 'kitchen' THEN
    RAISE EXCEPTION 'TEST_FAIL: admin_update_staff_role_v4 failed: %', v_update_role_res;
  END IF;

  -- Staff tries to self-escalate role -> Must be rejected
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_new_staff_id::text, 'role', 'authenticated')::text, true);
  v_self_escalate_res := public.admin_update_staff_role_v4(v_store_id, v_new_staff_id, 'owner');
  IF (v_self_escalate_res->>'success')::boolean IS NOT DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: staff was able to self-escalate role';
  END IF;

  -- Owner tries to demote themselves when they are the only owner -> Must be rejected
  PERFORM set_config('request.jwt.claims', json_build_object('sub', v_user_id::text, 'role', 'authenticated')::text, true);
  v_demote_owner_res := public.admin_update_staff_role_v4(v_store_id, v_user_id, 'waiter');
  IF (v_demote_owner_res->>'success')::boolean IS NOT DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: owner self-demotion was allowed when single owner';
  END IF;

  -- Lock and Revoke staff
  v_lock_staff_res := public.admin_set_staff_status_v4(v_store_id, v_new_staff_id, false);
  IF (v_lock_staff_res->>'success')::boolean IS DISTINCT FROM true
     OR (v_lock_staff_res->>'is_active')::boolean IS NOT DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: admin_set_staff_status_v4 failed: %', v_lock_staff_res;
  END IF;

  v_revoke_staff_res := public.admin_revoke_staff_membership_v4(v_store_id, v_new_staff_id);
  IF (v_revoke_staff_res->>'success')::boolean IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'TEST_FAIL: admin_revoke_staff_membership_v4 failed: %', v_revoke_staff_res;
  END IF;

  RAISE NOTICE 'AUTH_RPC_BOOTSTRAP_V4_TEST_PASS';
END $$;

ROLLBACK;
