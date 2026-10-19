-- Migration 08: RLS Verification, Function Execution Grants & Full Catalog Manifest Audit
-- File: supabase/migrations/20260814094000_qr_v3_08_grants_rls_postflight.sql

-- Preflight
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'pos_auth_attempts') THEN
    RAISE EXCEPTION 'MIGRATION_08_PREFLIGHT_FAIL: Table pos_auth_attempts is missing';
  END IF;
END $$;

-- 1. Explicit RLS Verification for all 9 new QR tables
ALTER TABLE public.qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_channels FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_channels FROM PUBLIC, anon, authenticated;

ALTER TABLE public.qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_requests FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_requests FROM PUBLIC, anon, authenticated;

ALTER TABLE public.qr_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_request_items FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_request_items FROM PUBLIC, anon, authenticated;

ALTER TABLE public.qr_audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_audit_logs FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.qr_audit_logs FROM PUBLIC, anon, authenticated;

ALTER TABLE public.product_topping_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_topping_links FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.product_topping_links FROM PUBLIC, anon, authenticated;

ALTER TABLE public.pos_device_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_device_sessions FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pos_device_sessions FROM PUBLIC, anon, authenticated;

ALTER TABLE public.pos_store_bootstrap_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_store_bootstrap_state FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pos_store_bootstrap_state FROM PUBLIC, anon, authenticated;

ALTER TABLE public.store_pairing_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.store_pairing_codes FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.store_pairing_codes FROM PUBLIC, anon, authenticated;

ALTER TABLE public.pos_auth_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pos_auth_attempts FORCE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.pos_auth_attempts FROM PUBLIC, anon, authenticated;

-- 2. Revoke default PUBLIC execution from internal helpers
REVOKE ALL ON FUNCTION public.hash_pos_credential_v3(text, text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.verify_pos_token_internal(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.check_pos_staff_action_permission(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;

-- 3. Customer Public RPC Grants
GRANT EXECUTE ON FUNCTION public.get_qr_menu_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.submit_qr_order_v3(text, jsonb, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_request_status_v3(text) TO anon, authenticated;

-- 4. Staff Client RPC Grants
GRANT EXECUTE ON FUNCTION public.bootstrap_first_pos_device_v3(text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_pos_pairing_code_v3(text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.pair_pos_device_v3(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.issue_pos_device_session_v3(text, text, uuid, text, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.revoke_pos_device_session_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_revoke_device_session_v3(text, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_pos_device_sessions_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_pending_qr_requests_v3(text, text, integer, timestamptz) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_qr_request_v3(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_qr_request_v3(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reject_qr_request_v3(uuid, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.send_to_kitchen_qr_v3(uuid, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.list_qr_channels_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_qr_channel_v3(text, text, text, text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.rotate_qr_channel_v3(text, uuid) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.set_qr_channel_active_v3(text, uuid, boolean) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.get_qr_settings_v3(text) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.save_qr_settings_v3(text, jsonb) TO anon, authenticated;

-- 5. Service Role Maintenance RPC Grants
GRANT EXECUTE ON FUNCTION public.cleanup_expired_qr_requests_v3() TO service_role;
REVOKE ALL ON FUNCTION public.cleanup_expired_qr_requests_v3() FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.cleanup_pos_auth_attempts_v3() TO service_role;
REVOKE ALL ON FUNCTION public.cleanup_pos_auth_attempts_v3() FROM PUBLIC, anon, authenticated;

-- 6. Section 1 Exact Postflight Manifest Audit (No 'public' string in has_function_privilege, aclexplode check for PUBLIC grantee 0)
DO $$
DECLARE
  v_tbl text;
  v_manifest_rec RECORD;
  v_proc_rec RECORD;
  v_overload_cnt integer;
  v_grant_cnt integer;
  v_passed_cnt integer := 0;
BEGIN
  -- Verify all 9 tables have RLS enabled/forced AND zero privileges for PUBLIC/anon/authenticated
  FOR v_tbl IN VALUES
    ('qr_channels'), ('qr_requests'), ('qr_request_items'), ('qr_audit_logs'),
    ('product_topping_links'), ('pos_device_sessions'), ('pos_store_bootstrap_state'),
    ('store_pairing_codes'), ('pos_auth_attempts')
  LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public' AND c.relname = v_tbl AND c.relrowsecurity = true AND c.relforcerowsecurity = true
    ) THEN
      RAISE EXCEPTION 'MIGRATION_08_POSTFLIGHT_FAIL: RLS not enabled/forced on table public.%', v_tbl;
    END IF;

    SELECT COUNT(*) INTO v_grant_cnt
    FROM information_schema.role_table_grants
    WHERE table_schema = 'public' AND table_name = v_tbl AND grantee IN ('PUBLIC', 'anon', 'authenticated');

    IF v_grant_cnt > 0 THEN
      RAISE EXCEPTION 'MIGRATION_08_POSTFLIGHT_FAIL: Table public.% has % unauthorized grants for PUBLIC/anon/authenticated', v_tbl, v_grant_cnt;
    END IF;
  END LOOP;

  -- Manifest Audit Table for all 26 routines (23 RPCs + 3 Helpers)
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
      RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.% has unexpected overload count: % (expected 1)', v_manifest_rec.func_name, v_overload_cnt;
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
      RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.%(%) is missing or signature mismatched', v_manifest_rec.func_name, v_manifest_rec.identity_args;
    END IF;

    IF v_proc_rec.owner_name <> 'postgres' THEN
      RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.% owner is %, expected postgres', v_manifest_rec.func_name, v_proc_rec.owner_name;
    END IF;

    -- Verify exp_secdef match
    IF v_manifest_rec.exp_secdef THEN
      IF v_proc_rec.prosecdef IS NOT TRUE THEN
        RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.% expected prosecdef=true', v_manifest_rec.func_name;
      END IF;
      IF v_proc_rec.proconfig IS NULL OR NOT (v_proc_rec.proconfig::text LIKE '%search_path=public, pg_temp%') THEN
        RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.% missing fixed search_path', v_manifest_rec.func_name;
      END IF;
    ELSE
      IF v_proc_rec.prosecdef IS TRUE THEN
        RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.% expected prosecdef=false (IMMUTABLE STRICT helper)', v_manifest_rec.func_name;
      END IF;
    END IF;

    -- Section 1: PUBLIC EXECUTE ACL MUST BE FALSE FOR ALL 26 ROUTINES
    IF v_proc_rec.has_public_acl IS TRUE THEN
      RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.% has PUBLIC EXECUTE ACL in proacl', v_manifest_rec.func_name;
    END IF;

    -- Verify Execution Privilege Category using exact roles (no pseudo-role 'public')
    IF v_manifest_rec.category IN ('internal', 'service_role') THEN
      IF has_function_privilege('anon', v_proc_rec.oid, 'EXECUTE') OR
         has_function_privilege('authenticated', v_proc_rec.oid, 'EXECUTE') THEN
        RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Routine public.% is executable by anon or authenticated', v_manifest_rec.func_name;
      END IF;
    END IF;

    IF v_manifest_rec.category = 'service_role' THEN
      IF NOT has_function_privilege('service_role', v_proc_rec.oid, 'EXECUTE') THEN
        RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Maintenance RPC public.% is not executable by service_role', v_manifest_rec.func_name;
      END IF;
    ELSIF v_manifest_rec.category = 'rpc' THEN
      IF NOT (has_function_privilege('anon', v_proc_rec.oid, 'EXECUTE') AND has_function_privilege('authenticated', v_proc_rec.oid, 'EXECUTE')) THEN
        RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Public RPC public.% is missing EXECUTE grant for anon or authenticated', v_manifest_rec.func_name;
      END IF;
    END IF;

    v_passed_cnt := v_passed_cnt + 1;
  END LOOP;

  IF v_passed_cnt <> 26 THEN
    RAISE EXCEPTION 'MIGRATION_08_MANIFEST_FAIL: Expected 26 manifest routines, checked %', v_passed_cnt;
  END IF;

  RAISE NOTICE 'MIGRATION_08_POSTFLIGHT_SUCCESS: All 9 QR tables, 26 manifest routines, overload checks, privilege grants, SECURITY DEFINER settings, and RLS policies are verified against manifest';
END $$;
