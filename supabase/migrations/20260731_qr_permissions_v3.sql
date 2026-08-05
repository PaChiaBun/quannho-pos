-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260731_qr_permissions_v3.sql
-- Module: Architecture v3 Action Permission Resolver Helper
-- Status: DRAFT_CREATED_NOT_EXECUTED (Draft SQL for Staging review only)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.check_pos_staff_action_permission(
  p_store_id        uuid,
  p_user_account_id uuid,
  p_staff_id        uuid,
  p_action_key      text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_catalog
AS $$
DECLARE
  v_sm_rec       record;
  v_st_rec       record;
  v_sm_json      jsonb;
  v_st_json      jsonb;
  v_is_owner     boolean := false;
  v_is_active    boolean := false;
  v_actions_json jsonb;
  v_raw_actions  text;
  v_allowed_keys text[] := ARRAY[
    'qr_order.view_pending',
    'qr_order.claim',
    'qr_order.reject',
    'qr_order.confirm',
    'qr_order.send_kitchen',
    'qr_order.manage_channels',
    'qr_order.print_qr',
    'qr_order.manage_settings'
  ];
BEGIN
  -- 0. Allowlist check
  IF p_action_key IS NULL OR NOT (p_action_key = ANY(v_allowed_keys)) THEN
    RETURN false; -- Invalid/unsupported action key: fail-closed
  END IF;

  -- 1. MANAGER/OWNER ACCOUNT: Check store_members using user_account_id
  IF p_user_account_id IS NOT NULL THEN
    SELECT * INTO v_sm_rec
    FROM public.store_members
    WHERE store_id = p_store_id AND user_id = p_user_account_id
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN false; -- No store membership found for user_account_id: fail-closed
    END IF;

    v_sm_json  := to_jsonb(v_sm_rec);
    v_is_owner := COALESCE((v_sm_json->>'is_owner')::boolean, false);

    -- Owner Override ONLY AFTER verified store membership existence
    IF v_is_owner THEN
      RETURN true;
    END IF;

    -- Inspect store_members.actions if present (handles JSONB or TEXT JSON)
    IF v_sm_json ? 'actions' AND v_sm_json->'actions' IS NOT NULL THEN
      BEGIN
        IF jsonb_typeof(v_sm_json->'actions') = 'array' THEN
          v_actions_json := v_sm_json->'actions';
        ELSIF jsonb_typeof(v_sm_json->'actions') = 'string' THEN
          v_raw_actions := v_sm_json->>'actions';
          v_actions_json := v_raw_actions::jsonb;
        END IF;

        IF v_actions_json IS NOT NULL AND jsonb_typeof(v_actions_json) = 'array' THEN
          IF v_actions_json @> jsonb_build_array(p_action_key) THEN
            RETURN true;
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        NULL; -- Malformed JSON: fail-closed
      END;
    END IF;
  END IF;

  -- 2. OPERATIONAL STAFF: Check staff_members using staff_id
  IF p_staff_id IS NOT NULL THEN
    SELECT * INTO v_st_rec
    FROM public.staff_members
    WHERE id = p_staff_id AND store_id = p_store_id
    LIMIT 1;

    IF NOT FOUND THEN
      RETURN false; -- No staff profile found: fail-closed
    END IF;

    v_st_json   := to_jsonb(v_st_rec);
    v_is_active := COALESCE((v_st_json->>'is_active')::boolean, false);

    IF NOT v_is_active THEN
      RETURN false; -- Inactive/locked staff member: fail-closed
    END IF;

    -- Inspect staff_members.actions if present (handles JSONB or TEXT JSON)
    IF v_st_json ? 'actions' AND v_st_json->'actions' IS NOT NULL THEN
      BEGIN
        IF jsonb_typeof(v_st_json->'actions') = 'array' THEN
          v_actions_json := v_st_json->'actions';
        ELSIF jsonb_typeof(v_st_json->'actions') = 'string' THEN
          v_raw_actions := v_st_json->>'actions';
          v_actions_json := v_raw_actions::jsonb;
        END IF;

        IF v_actions_json IS NOT NULL AND jsonb_typeof(v_actions_json) = 'array' THEN
          IF v_actions_json @> jsonb_build_array(p_action_key) THEN
            RETURN true;
          END IF;
        END IF;
      EXCEPTION WHEN OTHERS THEN
        NULL; -- Malformed JSON: fail-closed
      END;
    END IF;
  END IF;

  -- 3. Default Fail-Closed
  RETURN false;
END;
$$;

-- Restrict execution permissions
REVOKE ALL ON FUNCTION public.check_pos_staff_action_permission(uuid, uuid, uuid, text) FROM PUBLIC, anon, authenticated;
