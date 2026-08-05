BEGIN;

-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION ROLLBACK: rollback_qr_architecture_v3.sql
-- Module: Architecture v3 Symmetrical Teardown Script
-- Status: UNVERIFIED (Full Metadata Preflight Validation BEFORE any Teardown)
-- Note: NO CASCADE statements used. Wrapped in single transaction block.
-- ═══════════════════════════════════════════════════════════════════════════

-- STEP 1: METADATA PREFLIGHT VALIDATION (MUST RUN FIRST BEFORE ANY DROP)
DO $$
DECLARE
  v_cols text[] := ARRAY[
    'claimed_by_user_account_id',
    'claimed_by_staff_id',
    'claimed_at',
    'confirmed_at',
    'sent_kitchen_at',
    'reject_reason',
    'idempotency_key'
  ];
  v_col text;
  v_meta_val jsonb;
  v_tables text[] := ARRAY[
    'pos_store_bootstrap_state',
    'pos_device_sessions',
    'store_pairing_codes',
    'pos_auth_attempts',
    'qr_audit_logs'
  ];
  v_tbl text;
BEGIN
  -- Validate metadata table exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'qr_v3_migration_metadata'
  ) THEN
    RAISE EXCEPTION 'ROLLBACK PREFLIGHT FAILED: Table qr_v3_migration_metadata missing. Manual review required.';
  END IF;

  -- Validate tracking columns metadata
  FOREACH v_col IN ARRAY v_cols LOOP
    SELECT value INTO v_meta_val
    FROM public.qr_v3_migration_metadata
    WHERE key = 'column_' || v_col || '_existed';

    IF NOT FOUND OR jsonb_typeof(v_meta_val->'existed') <> 'boolean' THEN
      RAISE EXCEPTION 'ROLLBACK PREFLIGHT FAILED: Metadata key "column_%_existed" missing or invalid.', v_col;
    END IF;
  END LOOP;

  -- Validate V3 constraint metadata
  SELECT value INTO v_meta_val
  FROM public.qr_v3_migration_metadata
  WHERE key = 'v3_chk_status_existed_before';

  IF NOT FOUND OR jsonb_typeof(v_meta_val->'existed') <> 'boolean' THEN
    RAISE EXCEPTION 'ROLLBACK PREFLIGHT FAILED: Metadata key "v3_chk_status_existed_before" missing or invalid.';
  END IF;

  -- Validate V3 index metadata
  SELECT value INTO v_meta_val
  FROM public.qr_v3_migration_metadata
  WHERE key = 'v3_idx_channel_idempotency_existed_before';

  IF NOT FOUND OR jsonb_typeof(v_meta_val->'existed') <> 'boolean' THEN
    RAISE EXCEPTION 'ROLLBACK PREFLIGHT FAILED: Metadata key "v3_idx_channel_idempotency_existed_before" missing or invalid.';
  END IF;

  -- Validate V2 index metadata
  SELECT value INTO v_meta_val
  FROM public.qr_v3_migration_metadata
  WHERE key = 'legacy_v2_idempotency_index_existed';

  IF NOT FOUND OR jsonb_typeof(v_meta_val->'existed') <> 'boolean' THEN
    RAISE EXCEPTION 'ROLLBACK PREFLIGHT FAILED: Metadata key "legacy_v2_idempotency_index_existed" missing or invalid.';
  END IF;

  -- Validate composite type metadata
  SELECT value INTO v_meta_val
  FROM public.qr_v3_migration_metadata
  WHERE key = 'v3_type_pos_session_info_existed_before';

  IF NOT FOUND OR jsonb_typeof(v_meta_val->'existed') <> 'boolean' THEN
    RAISE EXCEPTION 'ROLLBACK PREFLIGHT FAILED: Metadata key "v3_type_pos_session_info_existed_before" missing or invalid.';
  END IF;

  -- Validate V3 isolated tables metadata
  FOREACH v_tbl IN ARRAY v_tables LOOP
    SELECT value INTO v_meta_val
    FROM public.qr_v3_migration_metadata
    WHERE key = 'v3_table_' || v_tbl || '_existed_before';

    IF NOT FOUND OR jsonb_typeof(v_meta_val->'existed') <> 'boolean' THEN
      RAISE EXCEPTION 'ROLLBACK PREFLIGHT FAILED: Metadata key "v3_table_%_existed_before" missing or invalid.', v_tbl;
    END IF;
  END LOOP;
END $$;

-- STEP 2: DROP V3 RPC FUNCTIONS
DROP FUNCTION IF EXISTS public.send_to_kitchen_qr_v3(uuid, text);
DROP FUNCTION IF EXISTS public.confirm_qr_request_v3(uuid, text);
DROP FUNCTION IF EXISTS public.reject_qr_request_v3(uuid, text, text);
DROP FUNCTION IF EXISTS public.claim_qr_request_v3(uuid, text);
DROP FUNCTION IF EXISTS public.get_pending_qr_requests_v3(text, text);
DROP FUNCTION IF EXISTS public.revoke_pos_device_session_v3(text);
DROP FUNCTION IF EXISTS public.issue_pos_device_session_v3(text, text, text, uuid);
DROP FUNCTION IF EXISTS public.pair_pos_device_v3(text, text, text, text);
DROP FUNCTION IF EXISTS public.generate_pos_pairing_code_v3(text);
DROP FUNCTION IF EXISTS public.bootstrap_first_pos_device_v3(text, text, text);
DROP FUNCTION IF EXISTS public.verify_pos_token_internal(text);
DROP FUNCTION IF EXISTS public.get_qr_request_status_v3(text);
DROP FUNCTION IF EXISTS public.submit_qr_order_v3(text, jsonb, text, text);
DROP FUNCTION IF EXISTS public.get_qr_menu_v3(text);
DROP FUNCTION IF EXISTS public.check_pos_staff_action_permission(uuid, uuid, uuid, text);

-- STEP 3: DROP V3 CONSTRAINTS & INDEXES (V3 Index dropped BEFORE Column idempotency_key!)
DO $$
DECLARE
  v_meta_val jsonb;
BEGIN
  -- Drop V3 status constraint if created by migration
  SELECT value INTO v_meta_val FROM public.qr_v3_migration_metadata WHERE key = 'v3_chk_status_existed_before';
  IF NOT (v_meta_val->>'existed')::boolean THEN
    ALTER TABLE IF EXISTS public.qr_requests DROP CONSTRAINT IF EXISTS chk_qr_requests_status_v3;
  END IF;

  -- Drop V3 channel idempotency index if created by migration
  SELECT value INTO v_meta_val FROM public.qr_v3_migration_metadata WHERE key = 'v3_idx_channel_idempotency_existed_before';
  IF NOT (v_meta_val->>'existed')::boolean THEN
    DROP INDEX IF EXISTS public.idx_qr_requests_channel_idempotency;
  END IF;
END $$;

-- STEP 4: RESTORE LEGACY V2 IDEMPOTENCY INDEX
DO $$
DECLARE
  v_meta_val jsonb;
BEGIN
  SELECT value INTO v_meta_val FROM public.qr_v3_migration_metadata WHERE key = 'legacy_v2_idempotency_index_existed';
  IF (v_meta_val->>'existed')::boolean THEN
    CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_requests_idempotency_unique 
      ON public.qr_requests(store_id, idempotency_key) 
      WHERE idempotency_key IS NOT NULL;
  END IF;
END $$;

-- STEP 5: DROP V3 ADDED COLUMNS (ONLY AFTER V3 Index is dropped & V2 Index restored)
DO $$
DECLARE
  v_cols text[] := ARRAY[
    'claimed_by_user_account_id',
    'claimed_by_staff_id',
    'claimed_at',
    'confirmed_at',
    'sent_kitchen_at',
    'reject_reason',
    'idempotency_key'
  ];
  v_col text;
  v_meta_val jsonb;
BEGIN
  FOREACH v_col IN ARRAY v_cols LOOP
    SELECT value INTO v_meta_val FROM public.qr_v3_migration_metadata WHERE key = 'column_' || v_col || '_existed';
    IF NOT (v_meta_val->>'existed')::boolean THEN
      EXECUTE 'ALTER TABLE public.qr_requests DROP COLUMN IF EXISTS ' || quote_ident(v_col);
    END IF;
  END LOOP;
END $$;

-- STEP 6: DROP V3 ISOLATED TABLES & COMPOSITE TYPE
DO $$
DECLARE
  v_tables text[] := ARRAY[
    'pos_store_bootstrap_state',
    'pos_device_sessions',
    'store_pairing_codes',
    'pos_auth_attempts',
    'qr_audit_logs'
  ];
  v_tbl text;
  v_meta_val jsonb;
BEGIN
  FOREACH v_tbl IN ARRAY v_tables LOOP
    SELECT value INTO v_meta_val FROM public.qr_v3_migration_metadata WHERE key = 'v3_table_' || v_tbl || '_existed_before';
    IF NOT (v_meta_val->>'existed')::boolean THEN
      EXECUTE 'DROP TABLE IF EXISTS public.' || quote_ident(v_tbl);
    END IF;
  END LOOP;

  SELECT value INTO v_meta_val FROM public.qr_v3_migration_metadata WHERE key = 'v3_type_pos_session_info_existed_before';
  IF NOT (v_meta_val->>'existed')::boolean THEN
    DROP TYPE IF EXISTS public.pos_session_info;
  END IF;
END $$;

-- STEP 7: DROP METADATA TABLE AT THE VERY END
DROP TABLE IF EXISTS public.qr_v3_migration_metadata;

COMMIT;
