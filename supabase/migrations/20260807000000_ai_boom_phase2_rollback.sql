-- =============================================================================
-- AI BOOM PILOT PHASE 2: ROLLBACK SCRIPT
-- Date: 2026-08-07
-- File: supabase/migrations/20260807000000_ai_boom_phase2_rollback.sql
-- =============================================================================

BEGIN;

-- Drop RPCs
DROP FUNCTION IF EXISTS public.get_store_context_for_boom(UUID);
DROP FUNCTION IF EXISTS public.get_pending_operations_tasks(UUID);
DROP FUNCTION IF EXISTS public.get_staff_on_shift(UUID);
DROP FUNCTION IF EXISTS public.get_finance_summary(UUID, INT, INT);
DROP FUNCTION IF EXISTS public.get_stock_forecast_inputs(UUID);
DROP FUNCTION IF EXISTS public.get_low_stock_items(UUID);
DROP FUNCTION IF EXISTS public.get_slow_products(UUID, INT);
DROP FUNCTION IF EXISTS public.get_top_products(UUID, INT);
DROP FUNCTION IF EXISTS public.compare_sales_periods(UUID, TEXT);
DROP FUNCTION IF EXISTS public.get_today_sales_summary(UUID);

-- Drop AI Boom Tables
DROP TABLE IF EXISTS public.boom_memories CASCADE;
DROP TABLE IF EXISTS public.boom_feedback CASCADE;
DROP TABLE IF EXISTS public.boom_messages CASCADE;
DROP TABLE IF EXISTS public.boom_conversations CASCADE;

COMMIT;
