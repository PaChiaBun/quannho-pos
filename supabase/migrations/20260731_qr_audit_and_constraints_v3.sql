-- ═══════════════════════════════════════════════════════════════════════════
-- MIGRATION: 20260731_qr_audit_and_constraints_v3.sql
-- Module: Architecture v3 Constraints & Audit Indexing
-- Status: DRAFT_CREATED_NOT_EXECUTED (Draft SQL for Staging review only)
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Immutable Pre-state Recording for Indexes & Constraints BEFORE Alteration
DO $$
DECLARE
  v_idx_rec record;
  v_idx_v2_exists boolean := false;
  v_idx_v3_exists boolean := false;
  v_chk_v3_exists boolean := false;
BEGIN
  -- A. Inspect pg_indexes for legacy V2 index idx_qr_requests_idempotency_unique
  SELECT indexdef INTO v_idx_rec
  FROM pg_indexes
  WHERE schemaname = 'public' 
    AND tablename  = 'qr_requests' 
    AND indexname  = 'idx_qr_requests_idempotency_unique';

  IF FOUND THEN
    IF v_idx_rec.indexdef LIKE '%UNIQUE INDEX%' 
       AND v_idx_rec.indexdef LIKE '%(store_id, idempotency_key)%' 
       AND v_idx_rec.indexdef LIKE '%WHERE%idempotency_key IS NOT NULL%' THEN
      v_idx_v2_exists := true;
    ELSE
      RAISE EXCEPTION 'V3 Migration Error: Index idx_qr_requests_idempotency_unique exists but definition does not match expected V2 schema: %', v_idx_rec.indexdef;
    END IF;
  END IF;

  -- IMMUTABLE PRE-state recording for V2 index (DO NOTHING on conflict)
  INSERT INTO public.qr_v3_migration_metadata (key, value, recorded_at)
  VALUES ('legacy_v2_idempotency_index_existed', jsonb_build_object('existed', v_idx_v2_exists), now())
  ON CONFLICT (key) DO NOTHING;

  -- Drop legacy V2 index ONLY AFTER PRE-state metadata is recorded
  IF v_idx_v2_exists THEN
    DROP INDEX IF EXISTS public.idx_qr_requests_idempotency_unique;
  END IF;

  -- B. Inspect if V3 index already existed prior to migration
  SELECT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE schemaname = 'public' AND tablename = 'qr_requests' AND indexname = 'idx_qr_requests_channel_idempotency'
  ) INTO v_idx_v3_exists;

  INSERT INTO public.qr_v3_migration_metadata (key, value, recorded_at)
  VALUES ('v3_idx_channel_idempotency_existed_before', jsonb_build_object('existed', v_idx_v3_exists), now())
  ON CONFLICT (key) DO NOTHING;

  -- C. Inspect if V3 status constraint already existed prior to migration (Exact schema, table, constraint join)
  SELECT EXISTS (
    SELECT 1 
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' 
      AND t.relname = 'qr_requests' 
      AND c.conname = 'chk_qr_requests_status_v3'
  ) INTO v_chk_v3_exists;

  INSERT INTO public.qr_v3_migration_metadata (key, value, recorded_at)
  VALUES ('v3_chk_status_existed_before', jsonb_build_object('existed', v_chk_v3_exists), now())
  ON CONFLICT (key) DO NOTHING;
END $$;

-- 2. Create V3 Idempotency Index scoped BY (channel_id, idempotency_key)
CREATE UNIQUE INDEX IF NOT EXISTS idx_qr_requests_channel_idempotency 
  ON public.qr_requests(channel_id, idempotency_key) 
  WHERE idempotency_key IS NOT NULL;

-- 3. Status CHECK constraint with NOT VALID for legacy safe execution
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_constraint c
    JOIN pg_class t ON t.oid = c.conrelid
    JOIN pg_namespace n ON n.oid = t.relnamespace
    WHERE n.nspname = 'public' AND t.relname = 'qr_requests' AND c.conname = 'chk_qr_requests_status_v3'
  ) THEN
    ALTER TABLE public.qr_requests 
      ADD CONSTRAINT chk_qr_requests_status_v3 
      CHECK (status IN ('pending_staff', 'processing', 'confirmed', 'sent_kitchen', 'rejected', 'expired'))
      NOT VALID;
  END IF;
END $$;

-- 4. LEGACY COMPATIBILITY HARDENING BLOCK (DO NOT EXECUTE UNTIL FULL CLIENT CUTOVER TO V3)
-- Note: Direct REVOKE / RLS locking on qr_channels/qr_requests is DEFERRED to cutover phase
-- so legacy Flutter client direct queries continue operating without interruption.
/*
DRAFT_HARDENING_CUTOVER_PHASE:
REVOKE INSERT, UPDATE, DELETE ON TABLE public.qr_channels FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.qr_requests FROM anon;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.qr_request_items FROM anon;

ALTER TABLE public.qr_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_channels ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_request_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Deny Anon Direct Insert V3" ON public.qr_requests FOR INSERT TO anon WITH CHECK (false);
CREATE POLICY "Deny Anon Direct Update V3" ON public.qr_requests FOR UPDATE TO anon USING (false);
CREATE POLICY "Deny Anon Direct Delete V3" ON public.qr_requests FOR DELETE TO anon USING (false);
*/
