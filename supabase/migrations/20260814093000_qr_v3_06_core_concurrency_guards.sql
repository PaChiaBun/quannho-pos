-- Migration 06: Core Concurrency Guards & Unique Database Indexes
-- File: supabase/migrations/20260814093000_qr_v3_06_core_concurrency_guards.sql

-- Preflight: Verify zero existing duplicate open sessions or duplicate ticket rounds
DO $$
DECLARE
  v_dup_sessions integer;
  v_dup_rounds   integer;
BEGIN
  SELECT COUNT(*) INTO v_dup_sessions
  FROM (
    SELECT store_id, table_id FROM public.ban_sessions
    WHERE status = 'open' AND table_id IS NOT NULL
    GROUP BY store_id, table_id HAVING COUNT(*) > 1
  ) t;

  IF v_dup_sessions > 0 THEN
    RAISE EXCEPTION 'MIGRATION_06_PREFLIGHT_FAIL: % duplicate open session groups exist in ban_sessions', v_dup_sessions;
  END IF;

  SELECT COUNT(*) INTO v_dup_rounds
  FROM (
    SELECT session_id, round FROM public.kitchen_tickets
    WHERE session_id IS NOT NULL
    GROUP BY session_id, round HAVING COUNT(*) > 1
  ) t;

  IF v_dup_rounds > 0 THEN
    RAISE EXCEPTION 'MIGRATION_06_PREFLIGHT_FAIL: % duplicate ticket round groups exist in kitchen_tickets', v_dup_rounds;
  END IF;
END $$;

-- 1. Unique partial index: 1 open session per table per store
CREATE UNIQUE INDEX idx_ban_sessions_one_open_per_table
ON public.ban_sessions (store_id, table_id)
WHERE status = 'open' AND table_id IS NOT NULL;

-- 2. Unique constraint: session_id + round on kitchen_tickets
ALTER TABLE public.kitchen_tickets
  ADD CONSTRAINT uq_kitchen_tickets_session_round UNIQUE (session_id, round);

-- 3. Unique partial index: 1 POS order per QR request
CREATE UNIQUE INDEX idx_orders_one_per_qr_request
ON public.orders (store_id, source_id)
WHERE source_type = 'qr_order';

-- Postflight Integrity Verification
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'ban_sessions' AND indexname = 'idx_ban_sessions_one_open_per_table') THEN
    RAISE EXCEPTION 'MIGRATION_06_POSTFLIGHT_FAIL: Index idx_ban_sessions_one_open_per_table missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.table_constraints WHERE constraint_schema = 'public' AND constraint_name = 'uq_kitchen_tickets_session_round') THEN
    RAISE EXCEPTION 'MIGRATION_06_POSTFLIGHT_FAIL: Constraint uq_kitchen_tickets_session_round missing';
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE schemaname = 'public' AND tablename = 'orders' AND indexname = 'idx_orders_one_per_qr_request') THEN
    RAISE EXCEPTION 'MIGRATION_06_POSTFLIGHT_FAIL: Index idx_orders_one_per_qr_request missing';
  END IF;
END $$;
