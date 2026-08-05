-- ═══════════════════════════════════════════════════════════════════════════
-- FULL STAGING SCHEMA PREFLIGHT VALIDATION SCRIPT (POS QR SECURITY MODULE)
-- File: supabase/staging_schema_preflight_pos_qr.sql
-- Mode: READ-ONLY METADATA AUDIT FUNCTION (SECURITY INVOKER)
-- Note: Function creation is DDL; execution is read-only metadata verification.
--
-- AVAILABLE:
-- SELECT public.verify_staging_preflight('PRE');
--
-- DISABLED:
-- SELECT public.verify_staging_preflight('POST');
-- POST remains disabled until Architecture v3 migrations are created,
-- statically reviewed and approved.
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.verify_staging_preflight(p_mode text)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_mode text := UPPER(TRIM(p_mode));
  v_missing text := '';
  v_env_marker record;
  v_digest_test bytea;
BEGIN
  -- -------------------------------------------------------------------------
  -- STEP 0: STRICT MODE CONTROL
  -- -------------------------------------------------------------------------
  IF v_mode = 'POST' THEN
    RAISE EXCEPTION 'POST PREFLIGHT DISABLED: Architecture v3 migrations are PLANNED_NOT_CREATED and POST expectations are not approved.';
  END IF;

  IF v_mode <> 'PRE' THEN
    RAISE EXCEPTION 'Preflight Failed: Invalid mode "%". Only PRE is currently available.', p_mode;
  END IF;

  RAISE NOTICE '[PREFLIGHT] Starting POS QR Staging Preflight Audit in PRE mode...';

  -- -------------------------------------------------------------------------
  -- STEP 1: INDEPENDENT STAGING ENVIRONMENT MARKER SAFETY GUARD
  -- Must check: exactly 1 row, environment = 'staging', project_identifier IS NOT NULL and NOT empty.
  -- -------------------------------------------------------------------------
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables 
    WHERE table_schema = 'public' AND table_name = 'environment_guard'
  ) THEN
    RAISE EXCEPTION 'PREFLIGHT SAFETY ABORT: Missing table "environment_guard". Please execute "CREATE TABLE environment_guard (environment text PRIMARY KEY, project_identifier text NOT NULL, created_at timestamptz DEFAULT now()); INSERT INTO environment_guard (environment, project_identifier) VALUES (''staging'', ''qn_staging_project_v1'');" on Staging DB first.';
  END IF;

  IF (SELECT COUNT(*) FROM public.environment_guard) <> 1 THEN
    RAISE EXCEPTION 'PREFLIGHT SAFETY ABORT: Table "environment_guard" must contain EXACTLY ONE row.';
  END IF;

  SELECT environment, project_identifier INTO v_env_marker 
  FROM public.environment_guard 
  LIMIT 1;

  IF v_env_marker.environment IS NULL OR LOWER(v_env_marker.environment) <> 'staging' THEN
    RAISE EXCEPTION 'PREFLIGHT SAFETY ABORT: Invalid environment marker "%". Expected "staging". DO NOT RUN ON PRODUCTION!', COALESCE(v_env_marker.environment, 'NULL');
  END IF;

  IF v_env_marker.project_identifier IS NULL OR TRIM(v_env_marker.project_identifier) = '' THEN
    RAISE EXCEPTION 'PREFLIGHT SAFETY ABORT: project_identifier in "environment_guard" must not be null or empty.';
  END IF;

  -- -------------------------------------------------------------------------
  -- STEP 2: VERIFY EXTENSION & CRYPTO FUNCTIONALITY
  -- -------------------------------------------------------------------------
  IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') THEN
    v_missing := v_missing || 'Extension: pgcrypto; ';
  END IF;

  BEGIN
    v_digest_test := digest('preflight_test'::bytea, 'sha256');
    IF v_digest_test IS NULL THEN
      v_missing := v_missing || 'Crypto Function: digest() returned NULL; ';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    v_missing := v_missing || 'Crypto Function: digest() execution failed; ';
  END;

  -- -------------------------------------------------------------------------
  -- STEP 3: BASELINE TABLES & COLUMNS CHECK (PRE MODE ONLY)
  -- -------------------------------------------------------------------------
  -- stores table & store_code column
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'stores') THEN
    v_missing := v_missing || 'Table: stores; ';
  ELSE
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'stores' AND column_name = 'store_code') THEN
      v_missing := v_missing || 'Column: stores.store_code; ';
    END IF;
  END IF;

  -- user_accounts table & display_name, password_hash columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'user_accounts') THEN
    v_missing := v_missing || 'Table: user_accounts; ';
  ELSE
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_accounts' AND column_name = 'display_name') THEN
      v_missing := v_missing || 'Column: user_accounts.display_name; ';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'user_accounts' AND column_name = 'password_hash') THEN
      v_missing := v_missing || 'Column: user_accounts.password_hash; ';
    END IF;
  END IF;

  -- store_members table
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'store_members') THEN
    v_missing := v_missing || 'Table: store_members; ';
  END IF;

  -- staff_members table & pin_hash, is_active columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'staff_members') THEN
    v_missing := v_missing || 'Table: staff_members; ';
  ELSE
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'staff_members' AND column_name = 'pin_hash') THEN
      v_missing := v_missing || 'Column: staff_members.pin_hash; ';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'staff_members' AND column_name = 'is_active') THEN
      v_missing := v_missing || 'Column: staff_members.is_active; ';
    END IF;
  END IF;

  -- products table
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'products') THEN
    v_missing := v_missing || 'Table: products; ';
  END IF;

  -- ban_zones & ban_dining_tables
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ban_zones') THEN
    v_missing := v_missing || 'Table: ban_zones; ';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'ban_dining_tables') THEN
    v_missing := v_missing || 'Table: ban_dining_tables; ';
  END IF;

  IF v_missing <> '' THEN
    RAISE EXCEPTION 'PREFLIGHT ABORT [PRE Mode]: Missing Baseline Objects -> %', v_missing;
  END IF;

  -- -------------------------------------------------------------------------
  -- STEP 4: PRE MODE TERMINATION
  -- -------------------------------------------------------------------------
  RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════';
  RAISE NOTICE '[PREFLIGHT PASSED: PRE MODE] Staging environment marker & baseline schema verified!';
  RAISE NOTICE '═══════════════════════════════════════════════════════════════════════════';
  RETURN;
END;
$$;

-- Restrict execution permissions: ONLY database owner / admin executing via SQL Editor
REVOKE ALL ON FUNCTION public.verify_staging_preflight(text) FROM PUBLIC, anon, authenticated;

/* 
-- ═══════════════════════════════════════════════════════════════════════════
-- NON-EXECUTABLE SPECIFICATION DRAFT: FUTURE POST MODE PREFLIGHT CHECKLIST
-- (This block is disabled until Architecture v3 migrations are approved & created)
-- ═══════════════════════════════════════════════════════════════════════════
-- Expected POSTChecks when activated:
-- 1. Verify tables: to_regclass('public.pos_device_sessions'), to_regclass('public.qr_channels'), to_regclass('public.qr_requests'), to_regclass('public.store_pairing_codes'), to_regclass('public.pos_auth_attempts')
-- 2. Verify columns: pos_device_sessions(token_hash bytea NOT NULL, expires_at, revoked_at, last_used_at), qr_requests(idempotency_key)
-- 3. Verify FKs: pos_device_sessions(store_id)->stores(id), pos_device_sessions(device_id)->devices(id), pos_device_sessions(staff_id)->staff_members(id)
-- 4. Verify RPC signatures:
--    Customer: get_qr_menu(text), submit_qr_order(text,jsonb,text,text), get_qr_request_status(text)
--    POS Token: issue_pos_device_session(text,text,text), get_pending_qr_requests(text,text), claim_qr_request(uuid,text), reject_qr_request(uuid,text,text), confirm_qr_request(uuid,text), send_to_kitchen_qr(uuid,text)
-- 5. Verify security: SECURITY DEFINER on RPCs, search_path = public, anon direct INSERT/UPDATE/DELETE denied on qr_* tables
*/
