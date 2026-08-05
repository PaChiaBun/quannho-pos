-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260731_create_qr_staff_rpc_v3.sql
-- Module: Architecture v3 Token-Verified POS Staff RPCs
-- Status: DRAFT_CREATED_NOT_EXECUTED (Draft SQL for Staging review only)
-- ═══════════════════════════════════════════════════════════════════════════

-- Internal session verification function returning typed composite pos_session_info
CREATE OR REPLACE FUNCTION public.verify_pos_token_internal(p_raw_token text)
RETURNS public.pos_session_info
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_hash    bytea;
  v_session record;
  v_result  public.pos_session_info;
BEGIN
  IF p_raw_token IS NULL OR TRIM(p_raw_token) = '' THEN
    RAISE EXCEPTION 'POS Auth Error: Token cannot be empty.';
  END IF;

  v_hash := digest(TRIM(p_raw_token)::bytea, 'sha256');

  SELECT id, store_id, device_id, principal_type, user_account_id, staff_id, expires_at, revoked_at
  INTO v_session
  FROM public.pos_device_sessions
  WHERE token_hash = v_hash
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'POS Auth Error: Invalid session token.';
  END IF;

  IF v_session.revoked_at IS NOT NULL THEN
    RAISE EXCEPTION 'POS Auth Error: Session token has been revoked.';
  END IF;

  IF v_session.expires_at <= now() THEN
    RAISE EXCEPTION 'POS Auth Error: Session token has expired.';
  END IF;

  -- Touch last_used_at timestamp
  UPDATE public.pos_device_sessions 
  SET last_used_at = now() 
  WHERE id = v_session.id;

  v_result.session_id      := v_session.id;
  v_result.store_id        := v_session.store_id;
  v_result.device_id       := v_session.device_id;
  v_result.principal_type  := v_session.principal_type;
  v_result.user_account_id := v_session.user_account_id;
  v_result.staff_id        := v_session.staff_id;

  RETURN v_result;
END;
$$;

-- Restrict internal verifier execution permissions strictly
REVOKE ALL ON FUNCTION public.verify_pos_token_internal(text) FROM PUBLIC, anon, authenticated;

-- 1. bootstrap_first_pos_device_v3(p_store_code text, p_credential text, p_device_name text)
-- Owner Credentials Validated FIRST, Persistent Bootstrap State Check SECOND, Atomic Device/Session/State Creation
CREATE OR REPLACE FUNCTION public.bootstrap_first_pos_device_v3(
  p_store_code  text,
  p_credential  text,
  p_device_name text DEFAULT 'POS Main Device'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_store           record;
  v_owner_acc       record;
  v_new_device_id   uuid;
  v_raw_token       text;
  v_token_hash      bytea;
  v_expires_at      timestamptz;
  v_phone_raw       text;
  v_phone_clean     text;
  v_phone_norm      text;
  v_hash_raw        text;
  v_hash_norm       text;
  v_store_code_norm text;
  v_ip              inet;
  v_ip_text         text;
  v_owner_id        uuid := NULL;
  v_salt            text := 'qn_pos_2024_salt';
BEGIN
  v_store_code_norm := UPPER(TRIM(p_store_code));
  v_ip := inet_client_addr();
  v_ip_text := COALESCE(host(v_ip), '0.0.0.0');

  -- Rate limit check
  IF EXISTS (
    SELECT 1 FROM public.pos_auth_attempts 
    WHERE ip_address = v_ip_text::inet AND store_code = v_store_code_norm AND blocked_until > now()
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'RATE_LIMITED', 'message', 'Too many failed attempts. Temporarily blocked for 15 minutes.');
  END IF;

  SELECT id, store_code INTO v_store
  FROM public.stores
  WHERE store_code = v_store_code_norm
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.pos_auth_attempts (ip_address, store_code, attempt_count, first_attempt_at)
    VALUES (v_ip_text::inet, v_store_code_norm, 1, now())
    ON CONFLICT (ip_address, store_code) DO UPDATE
    SET attempt_count = pos_auth_attempts.attempt_count + 1,
        blocked_until = CASE WHEN pos_auth_attempts.attempt_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END;

    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CREDENTIAL', 'message', 'Invalid credentials or store code.');
  END IF;

  -- Transaction advisory lock per store to prevent concurrent bootstrap race conditions
  PERFORM pg_advisory_xact_lock(hashtext('bootstrap:' || v_store.id::text));

  -- STEP 1: Authenticate store owner credentials FIRST (sm.is_owner IS TRUE)
  FOR v_owner_acc IN 
    SELECT u.id, u.phone, u.quick_pin 
    FROM public.user_accounts u
    JOIN public.store_members sm ON sm.user_id = u.id
    WHERE sm.store_id = v_store.id AND sm.is_owner IS TRUE AND u.quick_pin IS NOT NULL
  LOOP
    v_phone_raw   := TRIM(v_owner_acc.phone);
    v_phone_clean := regexp_replace(v_phone_raw, '[\s\-\(\)]', '', 'g');
    IF v_phone_clean LIKE '0%' THEN
      v_phone_norm := '+84' || substring(v_phone_clean FROM 2);
    ELSE
      v_phone_norm := v_phone_clean;
    END IF;

    v_hash_raw  := encode(digest((v_phone_clean || ':' || TRIM(p_credential) || ':' || v_salt)::bytea, 'sha256'), 'hex');
    v_hash_norm := encode(digest((v_phone_norm || ':' || TRIM(p_credential) || ':' || v_salt)::bytea, 'sha256'), 'hex');

    IF v_owner_acc.quick_pin = v_hash_raw OR v_owner_acc.quick_pin = v_hash_norm THEN
      v_owner_id := v_owner_acc.id;
      EXIT;
    END IF;
  END LOOP;

  IF v_owner_id IS NULL THEN
    INSERT INTO public.pos_auth_attempts (ip_address, store_code, attempt_count, first_attempt_at)
    VALUES (v_ip_text::inet, v_store_code_norm, 1, now())
    ON CONFLICT (ip_address, store_code) DO UPDATE
    SET attempt_count = pos_auth_attempts.attempt_count + 1,
        blocked_until = CASE WHEN pos_auth_attempts.attempt_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END;

    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CREDENTIAL', 'message', 'Invalid credentials or store code.');
  END IF;

  -- STEP 2: AFTER owner authentication succeeds, check persistent bootstrap state table
  IF EXISTS (
    SELECT 1 FROM public.pos_store_bootstrap_state 
    WHERE store_id = v_store.id
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'ALREADY_BOOTSTRAPPED', 'message', 'Store is already bootstrapped. Please use pairing flow.');
  END IF;

  -- Success: Clear rate limit counter
  DELETE FROM public.pos_auth_attempts WHERE ip_address = v_ip_text::inet AND store_code = v_store_code_norm;

  -- STEP 3: Create initial POS device, active session, and persistent bootstrap state in SAME transaction
  v_new_device_id := gen_random_uuid();
  INSERT INTO public.devices (
    id, store_id, device_name, device_role, created_at
  ) VALUES (
    v_new_device_id, v_store.id, TRIM(COALESCE(p_device_name, 'POS Main Device')), 'manager', now()
  );

  v_raw_token  := encode(gen_random_bytes(32), 'hex');
  v_token_hash := digest(v_raw_token::bytea, 'sha256');
  v_expires_at := now() + interval '8 hours';

  INSERT INTO public.pos_device_sessions (
    store_id, device_id, principal_type, user_account_id, token_hash, ip_address, created_at, expires_at
  ) VALUES (
    v_store.id, v_new_device_id, 'user_account', v_owner_id, v_token_hash, v_ip, now(), v_expires_at
  );

  INSERT INTO public.pos_store_bootstrap_state (
    store_id, bootstrapped_at, bootstrapped_by, initial_device_id
  ) VALUES (
    v_store.id, now(), v_owner_id, v_new_device_id
  );

  -- Audit log
  INSERT INTO public.qr_audit_logs (
    store_id, actor_type, actor_id, action, payload
  ) VALUES (
    v_store.id, 'staff', v_owner_id, 'bootstrap_first_pos_device_v3', jsonb_build_object('device_id', v_new_device_id)
  );

  RETURN jsonb_build_object(
    'success', true,
    'session_token', v_raw_token,
    'expires_at', v_expires_at,
    'store_id', v_store.id,
    'device_id', v_new_device_id,
    'user_account_id', v_owner_id
  );
END;
$$;

-- 2. generate_pos_pairing_code_v3(p_raw_token text)
CREATE OR REPLACE FUNCTION public.generate_pos_pairing_code_v3(p_raw_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_session    public.pos_session_info;
  v_has_perm   boolean;
  v_raw_code   text;
  v_code_hash  bytea;
  v_expires_at timestamptz;
  v_rnd_bytes  bytea;
  v_rnd_val    bigint;
BEGIN
  v_session  := public.verify_pos_token_internal(p_raw_token);
  v_has_perm := public.check_pos_staff_action_permission(
    v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.manage_settings'
  );

  IF NOT v_has_perm THEN
    RAISE EXCEPTION 'POS Permission Error: Action "qr_order.manage_settings" denied.';
  END IF;

  -- Generate secure random 6-digit code with bigint casting to prevent overflow
  v_rnd_bytes := gen_random_bytes(4);
  v_rnd_val   := (get_byte(v_rnd_bytes, 0)::bigint * 16777216) + (get_byte(v_rnd_bytes, 1)::bigint * 65536) + (get_byte(v_rnd_bytes, 2)::bigint * 256) + get_byte(v_rnd_bytes, 3)::bigint;
  v_raw_code  := lpad(((v_rnd_val % 900000) + 100000)::text, 6, '0');
  v_code_hash  := digest(v_raw_code::bytea, 'sha256');
  v_expires_at := now() + interval '5 minutes';

  -- Invalidate existing unused pairing codes for store
  UPDATE public.store_pairing_codes
  SET used_at = now()
  WHERE store_id = v_session.store_id AND used_at IS NULL;

  -- Insert pairing code hash
  INSERT INTO public.store_pairing_codes (
    store_id, code_hash, created_by, created_at, expires_at
  ) VALUES (
    v_session.store_id, v_code_hash, COALESCE(v_session.user_account_id, v_session.staff_id), now(), v_expires_at
  );

  -- Audit log (NO raw code logged)
  INSERT INTO public.qr_audit_logs (
    store_id, actor_type, actor_id, action, payload
  ) VALUES (
    v_session.store_id, 'staff', COALESCE(v_session.staff_id, v_session.user_account_id), 'generate_pos_pairing_code_v3', jsonb_build_object('expires_at', v_expires_at)
  );

  RETURN jsonb_build_object(
    'pairing_code', v_raw_code,
    'expires_at', v_expires_at
  );
END;
$$;

-- 3. pair_pos_device_v3(p_store_code text, p_pairing_code text, p_device_name text, p_device_role text)
CREATE OR REPLACE FUNCTION public.pair_pos_device_v3(
  p_store_code   text,
  p_pairing_code text,
  p_device_name  text,
  p_device_role  text DEFAULT 'staff'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_store           record;
  v_pairing_rec     record;
  v_code_hash       bytea;
  v_new_device_id   uuid;
  v_store_code_norm text;
  v_role_clean      text;
  v_name_clean      text;
  v_ip              inet;
  v_ip_text         text;
  -- Restricted client pairing roles (Clients cannot self-promote to owner/manager)
  v_allowed_roles   text[] := ARRAY['cashier', 'waiter', 'kitchen', 'staff'];
BEGIN
  v_store_code_norm := UPPER(TRIM(p_store_code));
  v_role_clean      := LOWER(TRIM(COALESCE(p_device_role, 'staff')));
  v_name_clean      := TRIM(COALESCE(p_device_name, 'POS Device'));
  v_ip              := inet_client_addr();
  v_ip_text         := COALESCE(host(v_ip), '0.0.0.0');

  -- Rate limit check
  IF EXISTS (
    SELECT 1 FROM public.pos_auth_attempts 
    WHERE ip_address = v_ip_text::inet AND store_code = v_store_code_norm AND blocked_until > now()
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'RATE_LIMITED', 'message', 'Too many failed attempts. Temporarily blocked for 15 minutes.');
  END IF;

  IF NOT (v_role_clean = ANY(v_allowed_roles)) OR char_length(v_name_clean) < 1 OR char_length(v_name_clean) > 100 THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAIRING_CODE', 'message', 'Invalid store code or pairing code.');
  END IF;

  SELECT id, store_code INTO v_store
  FROM public.stores
  WHERE store_code = v_store_code_norm
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.pos_auth_attempts (ip_address, store_code, attempt_count, first_attempt_at)
    VALUES (v_ip_text::inet, v_store_code_norm, 1, now())
    ON CONFLICT (ip_address, store_code) DO UPDATE
    SET attempt_count = pos_auth_attempts.attempt_count + 1,
        blocked_until = CASE WHEN pos_auth_attempts.attempt_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END;

    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAIRING_CODE', 'message', 'Invalid store code or pairing code.');
  END IF;

  v_code_hash := digest(TRIM(p_pairing_code)::bytea, 'sha256');

  SELECT id, store_id, created_by INTO v_pairing_rec
  FROM public.store_pairing_codes
  WHERE store_id = v_store.id 
    AND code_hash = v_code_hash 
    AND expires_at > now() 
    AND used_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    INSERT INTO public.pos_auth_attempts (ip_address, store_code, attempt_count, first_attempt_at)
    VALUES (v_ip_text::inet, v_store_code_norm, 1, now())
    ON CONFLICT (ip_address, store_code) DO UPDATE
    SET attempt_count = pos_auth_attempts.attempt_count + 1,
        blocked_until = CASE WHEN pos_auth_attempts.attempt_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END;

    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_PAIRING_CODE', 'message', 'Invalid store code or pairing code.');
  END IF;

  -- Success: Clear failed rate limit attempts
  DELETE FROM public.pos_auth_attempts WHERE ip_address = v_ip_text::inet AND store_code = v_store_code_norm;

  -- Create new device row matching real schema (id, store_id, device_name, device_role, created_at)
  v_new_device_id := gen_random_uuid();
  INSERT INTO public.devices (
    id, store_id, device_name, device_role, created_at
  ) VALUES (
    v_new_device_id, v_store.id, v_name_clean, v_role_clean, now()
  );

  -- Mark pairing code as used in same transaction
  UPDATE public.store_pairing_codes
  SET used_at = now()
  WHERE id = v_pairing_rec.id;

  RETURN jsonb_build_object(
    'success', true,
    'device_id', v_new_device_id,
    'device_name', v_name_clean,
    'store_id', v_store.id
  );
END;
$$;

-- 4. issue_pos_device_session_v3(p_store_code text, p_auth_mode text, p_credential text, p_device_id uuid)
CREATE OR REPLACE FUNCTION public.issue_pos_device_session_v3(
  p_store_code text,
  p_auth_mode  text,
  p_credential text,
  p_device_id  uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_store            record;
  v_staff            record;
  v_device           record;
  v_user_acc         record;
  v_raw_token        text;
  v_token_hash       bytea;
  v_expires_at       timestamptz;
  v_pin_hash         text;
  v_phone_raw        text;
  v_phone_clean      text;
  v_phone_norm       text;
  v_hash_raw         text;
  v_hash_norm        text;
  v_ip               inet;
  v_ip_text          text;
  v_store_code_norm  text;
  v_principal_type   text;
  v_user_account_id  uuid := NULL;
  v_staff_id         uuid := NULL;
  v_matched          boolean := false;
  v_salt             text := 'qn_pos_2024_salt';
BEGIN
  v_store_code_norm := UPPER(TRIM(p_store_code));
  v_ip := inet_client_addr();
  v_ip_text := COALESCE(host(v_ip), '0.0.0.0');

  -- Rate Limit Check
  IF EXISTS (
    SELECT 1 FROM public.pos_auth_attempts 
    WHERE ip_address = v_ip_text::inet AND store_code = v_store_code_norm AND blocked_until > now()
  ) THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'RATE_LIMITED', 'message', 'Too many failed attempts. Temporarily blocked for 15 minutes.');
  END IF;

  -- Validate store
  SELECT id, store_code, name INTO v_store
  FROM public.stores
  WHERE store_code = v_store_code_norm
  LIMIT 1;

  IF NOT FOUND THEN
    INSERT INTO public.pos_auth_attempts (ip_address, store_code, attempt_count, first_attempt_at)
    VALUES (v_ip_text::inet, v_store_code_norm, 1, now())
    ON CONFLICT (ip_address, store_code) DO UPDATE
    SET attempt_count = pos_auth_attempts.attempt_count + 1,
        blocked_until = CASE WHEN pos_auth_attempts.attempt_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END;

    RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CREDENTIAL', 'message', 'Invalid credentials or store code.');
  END IF;

  -- Mandatory check: p_device_id MUST exist in devices for store
  IF p_device_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'DEVICE_ID_REQUIRED', 'message', 'Device ID is required.');
  END IF;

  SELECT id INTO v_device
  FROM public.devices
  WHERE id = p_device_id AND store_id = v_store.id
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error_code', 'DEVICE_NOT_REGISTERED', 'message', 'Device is not registered for this store.');
  END IF;

  -- Authenticate Credentials
  IF LOWER(TRIM(p_auth_mode)) = 'staff_pin' THEN
    v_pin_hash := encode(digest(TRIM(p_credential)::bytea, 'sha256'), 'hex');

    SELECT id, store_id, name, role, is_active INTO v_staff
    FROM public.staff_members
    WHERE store_id = v_store.id AND pin_hash = v_pin_hash AND is_active = true
    LIMIT 1;

    IF NOT FOUND THEN
      INSERT INTO public.pos_auth_attempts (ip_address, store_code, attempt_count, first_attempt_at)
      VALUES (v_ip_text::inet, v_store_code_norm, 1, now())
      ON CONFLICT (ip_address, store_code) DO UPDATE
      SET attempt_count = pos_auth_attempts.attempt_count + 1,
          blocked_until = CASE WHEN pos_auth_attempts.attempt_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END;

      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CREDENTIAL', 'message', 'Invalid PIN or inactive staff profile.');
    END IF;

    v_principal_type := 'staff_member';
    v_staff_id       := v_staff.id;

  ELSIF LOWER(TRIM(p_auth_mode)) = 'manager_quick_pin' THEN
    -- Iterate ONLY through candidate manager/owner accounts for store
    FOR v_user_acc IN 
      SELECT u.id, u.phone, u.quick_pin 
      FROM public.user_accounts u
      JOIN public.store_members sm ON sm.user_id = u.id
      WHERE sm.store_id = v_store.id AND (sm.is_owner IS TRUE OR sm.role IN ('owner', 'manager')) AND u.quick_pin IS NOT NULL
    LOOP
      v_phone_raw   := TRIM(v_user_acc.phone);
      v_phone_clean := regexp_replace(v_phone_raw, '[\s\-\(\)]', '', 'g');
      IF v_phone_clean LIKE '0%' THEN
        v_phone_norm := '+84' || substring(v_phone_clean FROM 2);
      ELSE
        v_phone_norm := v_phone_clean;
      END IF;

      v_hash_raw  := encode(digest((v_phone_clean || ':' || TRIM(p_credential) || ':' || v_salt)::bytea, 'sha256'), 'hex');
      v_hash_norm := encode(digest((v_phone_norm || ':' || TRIM(p_credential) || ':' || v_salt)::bytea, 'sha256'), 'hex');

      IF v_user_acc.quick_pin = v_hash_raw OR v_user_acc.quick_pin = v_hash_norm THEN
        v_user_account_id := v_user_acc.id;
        v_matched         := true;
        EXIT;
      END IF;
    END LOOP;

    IF NOT v_matched OR v_user_account_id IS NULL THEN
      INSERT INTO public.pos_auth_attempts (ip_address, store_code, attempt_count, first_attempt_at)
      VALUES (v_ip_text::inet, v_store_code_norm, 1, now())
      ON CONFLICT (ip_address, store_code) DO UPDATE
      SET attempt_count = pos_auth_attempts.attempt_count + 1,
          blocked_until = CASE WHEN pos_auth_attempts.attempt_count + 1 >= 5 THEN now() + interval '15 minutes' ELSE NULL END;

      RETURN jsonb_build_object('success', false, 'error_code', 'INVALID_CREDENTIAL', 'message', 'Invalid manager credentials.');
    END IF;

    v_principal_type := 'user_account';

  ELSE
    RETURN jsonb_build_object('success', false, 'error_code', 'UNSUPPORTED_AUTH_MODE', 'message', 'Unsupported auth mode.');
  END IF;

  -- Success: Clear failed rate limit attempts
  DELETE FROM public.pos_auth_attempts 
  WHERE ip_address = v_ip_text::inet AND store_code = v_store_code_norm;

  -- Generate 256-bit opaque random session token
  v_raw_token  := encode(gen_random_bytes(32), 'hex');
  v_token_hash := digest(v_raw_token::bytea, 'sha256');
  v_expires_at := now() + interval '8 hours';

  -- Revoke existing active sessions for store/device pair
  UPDATE public.pos_device_sessions 
  SET revoked_at = now() 
  WHERE store_id = v_store.id AND device_id = v_device.id AND revoked_at IS NULL;

  -- Insert active session
  INSERT INTO public.pos_device_sessions (
    store_id, device_id, principal_type, user_account_id, staff_id, token_hash, ip_address, created_at, expires_at
  ) VALUES (
    v_store.id, v_device.id, v_principal_type, v_user_account_id, v_staff_id, v_token_hash, v_ip, now(), v_expires_at
  );

  -- Audit log (NO raw credentials or hashes logged)
  INSERT INTO public.qr_audit_logs (
    store_id, actor_type, actor_id, action, payload
  ) VALUES (
    v_store.id, 'staff', COALESCE(v_staff_id, v_user_account_id), 'issue_pos_session_v3', jsonb_build_object('device_id', v_device.id)
  );

  RETURN jsonb_build_object(
    'success', true,
    'session_token', v_raw_token,
    'expires_at', v_expires_at,
    'store_id', v_store.id,
    'device_id', v_device.id,
    'user_account_id', v_user_account_id,
    'staff_id', v_staff_id
  );
END;
$$;

-- 5. revoke_pos_device_session_v3(p_raw_token text)
CREATE OR REPLACE FUNCTION public.revoke_pos_device_session_v3(p_raw_token text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_session public.pos_session_info;
BEGIN
  v_session := public.verify_pos_token_internal(p_raw_token);

  UPDATE public.pos_device_sessions
  SET revoked_at = now()
  WHERE id = v_session.session_id;

  INSERT INTO public.qr_audit_logs (
    store_id, actor_type, actor_id, action
  ) VALUES (
    v_session.store_id, 'staff', COALESCE(v_session.staff_id, v_session.user_account_id), 'revoke_pos_session_v3'
  );

  RETURN jsonb_build_object('success', true, 'status', 'revoked', 'session_id', v_session.session_id);
END;
$$;

-- 6. get_pending_qr_requests_v3(p_raw_token text, p_filter_status text)
CREATE OR REPLACE FUNCTION public.get_pending_qr_requests_v3(
  p_raw_token     text,
  p_filter_status text DEFAULT 'pending_staff'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_session  public.pos_session_info;
  v_has_perm boolean;
  v_requests jsonb;
BEGIN
  v_session  := public.verify_pos_token_internal(p_raw_token);
  v_has_perm := public.check_pos_staff_action_permission(
    v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.view_pending'
  );

  IF NOT v_has_perm THEN
    RAISE EXCEPTION 'POS Permission Error: Action "qr_order.view_pending" denied.';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', r.id,
      'store_id', r.store_id,
      'channel_id', r.channel_id,
      'table_id', r.table_id,
      'type', r.type,
      'status', r.status,
      'total_amount', r.total_amount,
      'note', r.note,
      'claimed_by_user_account_id', r.claimed_by_user_account_id,
      'claimed_by_staff_id', r.claimed_by_staff_id,
      'created_at', r.created_at,
      'items', (
        SELECT COALESCE(jsonb_agg(
          jsonb_build_object(
            'id', ri.id,
            'product_id', ri.product_id,
            'product_name', ri.product_name,
            'unit_price', ri.unit_price,
            'quantity', ri.quantity,
            'modifiers_json', ri.modifiers_json,
            'note', ri.note
          )
        ), '[]'::jsonb)
        FROM public.qr_request_items ri WHERE ri.request_id = r.id
      )
    ) ORDER BY r.created_at DESC
  ), '[]'::jsonb)
  INTO v_requests
  FROM public.qr_requests r
  WHERE r.store_id = v_session.store_id
    AND r.status = COALESCE(NULLIF(TRIM(p_filter_status), ''), 'pending_staff');

  RETURN v_requests;
END;
$$;

-- 7. claim_qr_request_v3(p_request_id uuid, p_raw_token text)
CREATE OR REPLACE FUNCTION public.claim_qr_request_v3(
  p_request_id uuid,
  p_raw_token  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_session  public.pos_session_info;
  v_has_perm boolean;
  v_req      record;
BEGIN
  v_session  := public.verify_pos_token_internal(p_raw_token);
  v_has_perm := public.check_pos_staff_action_permission(
    v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.claim'
  );

  IF NOT v_has_perm THEN
    RAISE EXCEPTION 'POS Permission Error: Action "qr_order.claim" denied.';
  END IF;

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = v_session.store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QR Error: Request ID "%" not found in store.', p_request_id;
  END IF;

  IF v_req.status <> 'pending_staff' THEN
    RAISE EXCEPTION 'QR Transition Error: Cannot claim request in status "%". Expected "pending_staff".', v_req.status;
  END IF;

  UPDATE public.qr_requests
  SET status = 'processing',
      claimed_by_user_account_id = v_session.user_account_id,
      claimed_by_staff_id = v_session.staff_id,
      claimed_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, actor_type, actor_id, action, from_status, to_status
  ) VALUES (
    v_session.store_id, p_request_id, 'staff', COALESCE(v_session.staff_id, v_session.user_account_id), 'claim_qr_request_v3', 'pending_staff', 'processing'
  );

  RETURN jsonb_build_object('request_id', p_request_id, 'status', 'processing', 'claimed_at', now());
END;
$$;

-- 8. reject_qr_request_v3(p_request_id uuid, p_raw_token text, p_reject_reason text)
CREATE OR REPLACE FUNCTION public.reject_qr_request_v3(
  p_request_id    uuid,
  p_raw_token     text,
  p_reject_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_session     public.pos_session_info;
  v_has_perm    boolean;
  v_is_claimant boolean := false;
  v_req         record;
BEGIN
  v_session  := public.verify_pos_token_internal(p_raw_token);
  v_has_perm := public.check_pos_staff_action_permission(
    v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.reject'
  );

  IF NOT v_has_perm THEN
    RAISE EXCEPTION 'POS Permission Error: Action "qr_order.reject" denied.';
  END IF;

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = v_session.store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QR Error: Request ID "%" not found.', p_request_id;
  END IF;

  IF v_req.status NOT IN ('pending_staff', 'processing') THEN
    RAISE EXCEPTION 'QR Transition Error: Cannot reject request in status "%".', v_req.status;
  END IF;

  -- Check claimant matching (staff_id or user_account_id) OR manager takeover
  IF v_session.staff_id IS NOT NULL AND v_req.claimed_by_staff_id = v_session.staff_id THEN
    v_is_claimant := true;
  ELSIF v_session.user_account_id IS NOT NULL AND v_req.claimed_by_user_account_id = v_session.user_account_id THEN
    v_is_claimant := true;
  END IF;

  IF NOT v_is_claimant AND (v_req.claimed_by_staff_id IS NOT NULL OR v_req.claimed_by_user_account_id IS NOT NULL) THEN
    IF NOT public.check_pos_staff_action_permission(v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.manage_settings') THEN
      RAISE EXCEPTION 'QR Takeover Error: Request claimed by another staff member.';
    END IF;
  END IF;

  UPDATE public.qr_requests
  SET status = 'rejected',
      reject_reason = TRIM(COALESCE(p_reject_reason, 'Rejected by staff'))
  WHERE id = p_request_id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, actor_type, actor_id, action, from_status, to_status, payload
  ) VALUES (
    v_session.store_id, p_request_id, 'staff', COALESCE(v_session.staff_id, v_session.user_account_id), 'reject_qr_request_v3', v_req.status, 'rejected', jsonb_build_object('reason', p_reject_reason)
  );

  RETURN jsonb_build_object('request_id', p_request_id, 'status', 'rejected');
END;
$$;

-- 9. confirm_qr_request_v3(p_request_id uuid, p_raw_token text)
CREATE OR REPLACE FUNCTION public.confirm_qr_request_v3(
  p_request_id uuid,
  p_raw_token  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_session     public.pos_session_info;
  v_has_perm    boolean;
  v_is_claimant boolean := false;
  v_req         record;
BEGIN
  v_session  := public.verify_pos_token_internal(p_raw_token);
  v_has_perm := public.check_pos_staff_action_permission(
    v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.confirm'
  );

  IF NOT v_has_perm THEN
    RAISE EXCEPTION 'POS Permission Error: Action "qr_order.confirm" denied.';
  END IF;

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = v_session.store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QR Error: Request ID "%" not found.', p_request_id;
  END IF;

  IF v_req.status <> 'processing' THEN
    RAISE EXCEPTION 'QR Transition Error: Cannot confirm request in status "%". Expected "processing".', v_req.status;
  END IF;

  -- Check claimant matching (staff_id or user_account_id) OR manager takeover
  IF v_session.staff_id IS NOT NULL AND v_req.claimed_by_staff_id = v_session.staff_id THEN
    v_is_claimant := true;
  ELSIF v_session.user_account_id IS NOT NULL AND v_req.claimed_by_user_account_id = v_session.user_account_id THEN
    v_is_claimant := true;
  END IF;

  IF NOT v_is_claimant AND (v_req.claimed_by_staff_id IS NOT NULL OR v_req.claimed_by_user_account_id IS NOT NULL) THEN
    IF NOT public.check_pos_staff_action_permission(v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.manage_settings') THEN
      RAISE EXCEPTION 'QR Takeover Error: Request claimed by another staff member.';
    END IF;
  END IF;

  UPDATE public.qr_requests
  SET status = 'confirmed',
      confirmed_at = now()
  WHERE id = p_request_id;

  INSERT INTO public.qr_audit_logs (
    store_id, request_id, actor_type, actor_id, action, from_status, to_status
  ) VALUES (
    v_session.store_id, p_request_id, 'staff', COALESCE(v_session.staff_id, v_session.user_account_id), 'confirm_qr_request_v3', 'processing', 'confirmed'
  );

  RETURN jsonb_build_object('request_id', p_request_id, 'status', 'confirmed', 'confirmed_at', now());
END;
$$;

-- 10. send_to_kitchen_qr_v3(p_request_id uuid, p_raw_token text)
-- Single Atomic Transaction: Strict Fail-Closed Topping Re-validation, Strict Type-based Table/Counter Branching, Multi-Store Takeaway Table Isolation, and session_item_id trỏ đúng kitchen_ticket_item
CREATE OR REPLACE FUNCTION public.send_to_kitchen_qr_v3(
  p_request_id uuid,
  p_raw_token  text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_session            public.pos_session_info;
  v_has_perm           boolean;
  v_is_claimant        boolean := false;
  v_req                record;
  v_item_rec           record;
  v_prod_rec           record;
  v_top_rec            record;
  v_table_rec          record;
  v_topping_elem       jsonb;
  v_topping_id         uuid;
  v_top_qty            int;
  v_new_order_id       uuid;
  v_ticket_id          uuid;
  v_ban_session_id     uuid;
  v_session_item_id    uuid;
  v_table_uuid         uuid := NULL;
  v_table_label        text := '';
  v_zone_label         text := '';
  v_recalculated_total numeric := 0;
  v_item_unit_total    numeric;
  v_line_total         numeric;
  v_seen_toppings      uuid[];
  v_round              int := 1;
  v_items_count        int := 0;
  v_created_session_item_ids uuid[] := ARRAY[]::uuid[];
  -- Deterministic Multi-Store Takeaway Table & Zone UUID generation
  v_takeaway_zone_id  uuid;
  v_takeaway_table_id uuid;
BEGIN
  v_session  := public.verify_pos_token_internal(p_raw_token);
  v_has_perm := public.check_pos_staff_action_permission(
    v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.send_kitchen'
  );

  IF NOT v_has_perm THEN
    RAISE EXCEPTION 'POS Permission Error: Action "qr_order.send_kitchen" denied.';
  END IF;

  SELECT * INTO v_req
  FROM public.qr_requests
  WHERE id = p_request_id AND store_id = v_session.store_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'QR Error: Request ID "%" not found.', p_request_id;
  END IF;

  IF v_req.status <> 'confirmed' THEN
    RAISE EXCEPTION 'QR Transition Error: Cannot send to kitchen from status "%". Expected "confirmed".', v_req.status;
  END IF;

  -- Check claimant / takeover
  IF v_session.staff_id IS NOT NULL AND v_req.claimed_by_staff_id = v_session.staff_id THEN
    v_is_claimant := true;
  ELSIF v_session.user_account_id IS NOT NULL AND v_req.claimed_by_user_account_id = v_session.user_account_id THEN
    v_is_claimant := true;
  END IF;

  IF NOT v_is_claimant AND (v_req.claimed_by_staff_id IS NOT NULL OR v_req.claimed_by_user_account_id IS NOT NULL) THEN
    IF NOT public.check_pos_staff_action_permission(v_session.store_id, v_session.user_account_id, v_session.staff_id, 'qr_order.manage_settings') THEN
      RAISE EXCEPTION 'QR Takeover Error: Request claimed by another staff member.';
    END IF;
  END IF;

  SELECT COUNT(*) INTO v_items_count FROM public.qr_request_items WHERE request_id = p_request_id;
  IF v_items_count = 0 THEN
    RAISE EXCEPTION 'QR Error: Request has no items in qr_request_items.';
  END IF;

  -- Step A: Re-validate main product & toppings prices & availability in transaction (NO FAIL-OPEN!)
  FOR v_item_rec IN SELECT * FROM public.qr_request_items WHERE request_id = p_request_id LOOP
    SELECT id, name, sell_price, is_available, is_active, is_deleted, is_topping
    INTO v_prod_rec
    FROM public.products
    WHERE id = v_item_rec.product_id AND store_id = v_session.store_id;

    IF NOT FOUND OR v_prod_rec.is_available IS FALSE OR v_prod_rec.is_active IS FALSE OR v_prod_rec.is_deleted IS TRUE THEN
      RAISE EXCEPTION 'QR Kitchen Error: Product "%" is unavailable for kitchen dispatch.', v_item_rec.product_name;
    END IF;

    v_item_unit_total := v_prod_rec.sell_price;
    v_seen_toppings   := ARRAY[]::uuid[];

    -- Fail-closed re-validation of toppings inside modifiers_json
    IF v_item_rec.modifiers_json IS NOT NULL AND TRIM(v_item_rec.modifiers_json) <> '' AND v_item_rec.modifiers_json <> '[]' THEN
      FOR v_topping_elem IN SELECT * FROM jsonb_array_elements(v_item_rec.modifiers_json::jsonb)
      LOOP
        v_topping_id := (v_topping_elem->>'topping_id')::uuid;
        v_top_qty    := COALESCE((v_topping_elem->>'quantity')::int, 1);

        IF v_topping_id = ANY(v_seen_toppings) THEN
          RAISE EXCEPTION 'QR Kitchen Error: Duplicate topping ID "%" in dispatch payload.', v_topping_id;
        END IF;
        v_seen_toppings := array_append(v_seen_toppings, v_topping_id);

        -- Check link in product_topping_links
        IF NOT EXISTS (
          SELECT 1 FROM public.product_topping_links 
          WHERE product_id = v_item_rec.product_id AND topping_id = v_topping_id
        ) THEN
          RAISE EXCEPTION 'QR Kitchen Error: Topping ID "%" is not valid for product "%".', v_topping_id, v_item_rec.product_name;
        END IF;

        SELECT id, name, sell_price, is_available, is_active, is_deleted, is_topping
        INTO v_top_rec
        FROM public.products
        WHERE id = v_topping_id AND store_id = v_session.store_id;

        IF NOT FOUND OR v_top_rec.is_topping IS NOT TRUE OR v_top_rec.is_available IS FALSE OR v_top_rec.is_active IS FALSE OR v_top_rec.is_deleted IS TRUE THEN
          RAISE EXCEPTION 'QR Kitchen Error: Topping "%" is unavailable for kitchen dispatch.', COALESCE(v_top_rec.name, v_topping_id::text);
        END IF;

        v_item_unit_total := v_item_unit_total + (v_top_rec.sell_price * v_top_qty);
      END LOOP;
    END IF;

    -- Check if computed unit total matches stored unit price
    IF v_item_unit_total <> v_item_rec.unit_price THEN
      RAISE EXCEPTION 'QR Price Change Error: Item "%" price changed from % to %. Staff re-confirmation required.', v_item_rec.product_name, v_item_rec.unit_price, v_item_unit_total;
    END IF;

    v_line_total         := v_item_unit_total * v_item_rec.quantity;
    v_recalculated_total := v_recalculated_total + v_line_total;
  END LOOP;

  -- Step B: Strict Branching for Counter vs Table QR Orders
  IF v_req.type = 'counter' THEN
    -- Generate deterministic takeaway zone & table UUID per store to prevent cross-store primary key conflicts
    v_takeaway_zone_id  := (substr(encode(digest(('takeaway_zone:'  || v_session.store_id::text)::bytea, 'sha256'), 'hex'), 1, 32))::uuid;
    v_takeaway_table_id := (substr(encode(digest(('takeaway_table:' || v_session.store_id::text)::bytea, 'sha256'), 'hex'), 1, 32))::uuid;

    -- Ensure Takeaway Zone & Table exist specifically for THIS store
    INSERT INTO public.ban_zones (id, store_id, name, is_active)
    VALUES (v_takeaway_zone_id, v_session.store_id, 'Mang đi', true)
    ON CONFLICT (id) DO NOTHING;

    INSERT INTO public.ban_dining_tables (id, store_id, zone_id, label, seats, is_active)
    VALUES (v_takeaway_table_id, v_session.store_id, v_takeaway_zone_id, 'Mang đi', 4, true)
    ON CONFLICT (id) DO NOTHING;

    v_table_uuid  := v_takeaway_table_id;
    v_table_label := 'Mang đi (' || COALESCE(v_req.pickup_code, 'Q01') || ')';
    v_zone_label  := 'Mang đi';

  ELSIF v_req.type = 'table' THEN
    -- Table QR: table_id MUST NOT be NULL or empty
    IF v_req.table_id IS NULL OR TRIM(v_req.table_id) = '' THEN
      RAISE EXCEPTION 'QR Error: Table QR request must specify a valid table_id.';
    END IF;

    BEGIN
      v_table_uuid := v_req.table_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      RAISE EXCEPTION 'QR Error: Invalid table UUID format "%" for Table QR order.', v_req.table_id;
    END;

    SELECT t.id, t.label, t.is_active, t.zone_id, z.name AS zone_name
    INTO v_table_rec
    FROM public.ban_dining_tables t
    LEFT JOIN public.ban_zones z ON z.id = t.zone_id
    WHERE t.id = v_table_uuid AND t.store_id = v_session.store_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'QR Error: Dining table ID "%" not found in store.', v_table_uuid;
    END IF;

    IF v_table_rec.is_active IS FALSE THEN
      RAISE EXCEPTION 'QR Error: Dining table "%" is inactive.', v_table_rec.label;
    END IF;

    v_table_label := COALESCE(v_table_rec.label, 'Bàn');
    v_zone_label  := COALESCE(v_table_rec.zone_name, 'Khu vực');

  ELSE
    RAISE EXCEPTION 'QR Error: Unsupported request type "%". Expected "table" or "counter".', v_req.type;
  END IF;

  -- Step C: Create Order (matching REAL schema)
  v_new_order_id := gen_random_uuid();
  INSERT INTO public.orders (
    id, store_id, device_id, staff_id, source_type, source_id, total, status, note, created_at, updated_at
  ) VALUES (
    v_new_order_id, v_session.store_id, v_session.device_id, v_session.staff_id, 'qr_order', v_table_uuid::text, v_recalculated_total, 'open', v_req.note, now(), now()
  );

  -- Step D: Create Order Items
  FOR v_item_rec IN SELECT * FROM public.qr_request_items WHERE request_id = p_request_id LOOP
    INSERT INTO public.order_items (
      id, store_id, order_id, product_id, name, qty, unit_price, note, kitchen_status
    ) VALUES (
      gen_random_uuid(), v_session.store_id, v_new_order_id, v_item_rec.product_id, v_item_rec.product_name, v_item_rec.quantity, v_item_rec.unit_price, v_item_rec.note, 'pending'
    );
  END LOOP;

  -- Step E: Handle ban_sessions (status='open')
  SELECT id INTO v_ban_session_id
  FROM public.ban_sessions
  WHERE store_id = v_session.store_id AND table_id = v_table_uuid AND status = 'open'
  LIMIT 1;

  IF NOT FOUND THEN
    v_ban_session_id := gen_random_uuid();
    INSERT INTO public.ban_sessions (
      id, store_id, table_id, status, guest_count, total_amount, staff_id, pos_order_id, note, opened_at
    ) VALUES (
      v_ban_session_id, v_session.store_id, v_table_uuid, 'open', 1, v_recalculated_total, v_session.staff_id, v_new_order_id, v_req.note, now()
    );
  ELSE
    UPDATE public.ban_sessions
    SET total_amount = COALESCE(total_amount, 0) + v_recalculated_total
    WHERE id = v_ban_session_id;
  END IF;

  -- Calculate ticket round dynamically
  SELECT COALESCE(MAX(round), 0) + 1 INTO v_round
  FROM public.kitchen_tickets
  WHERE session_id = v_ban_session_id;

  -- Step F: Create Kitchen Ticket
  v_ticket_id := gen_random_uuid();
  INSERT INTO public.kitchen_tickets (
    id, store_id, order_id, table_id, session_id, table_label, zone_label, round, status, sent_at
  ) VALUES (
    v_ticket_id, v_session.store_id, v_new_order_id, v_table_uuid, v_ban_session_id, v_table_label, v_zone_label, v_round, 'cho', now()
  );

  -- Step G: Loop through items and create ban_session_item AND corresponding kitchen_ticket_item in SAME LOOP
  FOR v_item_rec IN SELECT * FROM public.qr_request_items WHERE request_id = p_request_id LOOP
    v_session_item_id := gen_random_uuid();
    v_created_session_item_ids := array_append(v_created_session_item_ids, v_session_item_id);

    v_line_total := v_item_rec.unit_price * v_item_rec.quantity;

    -- Insert ban_session_item (unit_price = item_unit_total including toppings)
    INSERT INTO public.ban_session_items (
      id, store_id, session_id, product_id, product_name, unit_price, quantity, subtotal, note, added_by, kitchen_status, added_at
    ) VALUES (
      v_session_item_id, v_session.store_id, v_ban_session_id, v_item_rec.product_id, v_item_rec.product_name, v_item_rec.unit_price, v_item_rec.quantity, v_line_total, v_item_rec.note, 'qr_order', 'chua_gui', now()
    );

    -- Insert kitchen_ticket_item matching canonical schema (filling both legacy & v3 columns, station_code='nong')
    INSERT INTO public.kitchen_ticket_items (
      id, store_id, ticket_id, session_item_id, product_id, name, product_name, qty, quantity, status, kitchen_note, free_note, modifiers_json, station_code, done
    ) VALUES (
      gen_random_uuid(), v_session.store_id, v_ticket_id, v_session_item_id, v_item_rec.product_id, v_item_rec.product_name, v_item_rec.product_name, v_item_rec.quantity, v_item_rec.quantity, 'cho', v_item_rec.note, v_item_rec.note, COALESCE(v_item_rec.modifiers_json, '[]'), 'nong', false
    );
  END LOOP;

  -- Step H: Update newly created ban_session_items to 'da_gui' AFTER kitchen ticket items succeed
  UPDATE public.ban_session_items
  SET kitchen_status = 'da_gui'
  WHERE id = ANY(v_created_session_item_ids);

  -- Step I: Transition qr_requests status to sent_kitchen
  UPDATE public.qr_requests
  SET status = 'sent_kitchen',
      sent_kitchen_at = now()
  WHERE id = p_request_id;

  -- Step J: Audit Log
  INSERT INTO public.qr_audit_logs (
    store_id, request_id, actor_type, actor_id, action, from_status, to_status, payload
  ) VALUES (
    v_session.store_id, p_request_id, 'staff', COALESCE(v_session.staff_id, v_session.user_account_id), 'send_to_kitchen_qr_v3', 'confirmed', 'sent_kitchen',
    jsonb_build_object('order_id', v_new_order_id, 'kitchen_ticket_id', v_ticket_id, 'total', v_recalculated_total)
  );

  RETURN jsonb_build_object(
    'request_id', p_request_id,
    'status', 'sent_kitchen',
    'order_id', v_new_order_id,
    'kitchen_ticket_id', v_ticket_id,
    'total_amount', v_recalculated_total,
    'sent_kitchen_at', now()
  );
END;
$$;

-- Revoke & Grant EXECUTE privileges to anon role
REVOKE ALL ON FUNCTION public.bootstrap_first_pos_device_v3(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.generate_pos_pairing_code_v3(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.pair_pos_device_v3(text, text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.issue_pos_device_session_v3(text, text, text, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.revoke_pos_device_session_v3(text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.get_pending_qr_requests_v3(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.claim_qr_request_v3(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.reject_qr_request_v3(uuid, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.confirm_qr_request_v3(uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.send_to_kitchen_qr_v3(uuid, text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.bootstrap_first_pos_device_v3(text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_pos_pairing_code_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pair_pos_device_v3(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.issue_pos_device_session_v3(text, text, text, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_pos_device_session_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_qr_requests_v3(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_qr_request_v3(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reject_qr_request_v3(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_qr_request_v3(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_to_kitchen_qr_v3(uuid, text) TO anon, authenticated;
