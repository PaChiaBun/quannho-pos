-- =============================================================================
-- Migration: 20260906_fix_report_and_roles_rls.sql
-- Mục tiêu: Cấp quyền SELECT và RLS Policy cho finance_records, store_roles, staff_shifts
-- Quy chuẩn: qn.md mục 2.43 (Lego Modules SSOT) & mục 2.5 (Quy chuẩn RLS & SELECT cho Thống kê / Báo cáo)
-- =============================================================================

-- 1. Báo cáo tài chính (finance_records)
GRANT SELECT ON public.finance_records TO anon, authenticated, service_role;
DROP POLICY IF EXISTS finance_records_select_all ON public.finance_records;
CREATE POLICY finance_records_select_all ON public.finance_records
  FOR SELECT TO public USING (true);

-- 2. Phân quyền vai trò Lego Modules (store_roles)
GRANT SELECT ON public.store_roles TO anon, authenticated, service_role;
DROP POLICY IF EXISTS store_roles_select_all ON public.store_roles;
CREATE POLICY store_roles_select_all ON public.store_roles
  FOR SELECT TO public USING (true);

-- 3. Chấm công vào ca làm việc (staff_shifts)
GRANT SELECT ON public.staff_shifts TO anon, authenticated, service_role;
DROP POLICY IF EXISTS staff_shifts_select_all ON public.staff_shifts;
CREATE POLICY staff_shifts_select_all ON public.staff_shifts
  FOR SELECT TO public USING (true);
