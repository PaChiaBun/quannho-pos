-- =============================================================================
-- Migration: 20260906_fix_finance_records_rls_for_reports.sql
-- Mục tiêu: Cấp quyền SELECT và tạo RLS Policy cho finance_records
-- Quy chuẩn: qn.md mục 2.5 (Quy chuẩn RLS & SELECT cho Thống kê / Báo cáo)
-- =============================================================================

GRANT SELECT ON public.finance_records TO anon, authenticated, service_role;

DROP POLICY IF EXISTS finance_records_select_all ON public.finance_records;
CREATE POLICY finance_records_select_all ON public.finance_records
  FOR SELECT TO public USING (true);
