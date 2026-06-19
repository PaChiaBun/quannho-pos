-- =====================================================================
-- OPS: Disable RLS — phù hợp với custom auth (không dùng Supabase JWT)
-- Bảo mật được xử lý ở tầng Flutter (isManager check) + store_id filter
-- Chạy trong Supabase SQL Editor
-- =====================================================================

-- Xoá các policy đã tạo (nếu có)
DROP POLICY IF EXISTS "tmpl_select_all_members" ON public.ops_task_templates;
DROP POLICY IF EXISTS "tmpl_write_manager_only"  ON public.ops_task_templates;
DROP POLICY IF EXISTS "log_select_manager"        ON public.ops_daily_logs;
DROP POLICY IF EXISTS "log_select_own"            ON public.ops_daily_logs;
DROP POLICY IF EXISTS "log_insert_own"            ON public.ops_daily_logs;
DROP POLICY IF EXISTS "log_update_own"            ON public.ops_daily_logs;
DROP POLICY IF EXISTS "log_write_manager"         ON public.ops_daily_logs;

-- Tắt RLS (đồng bộ với pattern toàn app)
ALTER TABLE public.ops_task_templates DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.ops_daily_logs     DISABLE ROW LEVEL SECURITY;

-- Đảm bảo GRANT đủ quyền
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ops_task_templates TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.ops_daily_logs     TO anon, authenticated;

-- Xác nhận
SELECT schemaname, tablename, rowsecurity
FROM pg_tables
WHERE tablename IN ('ops_task_templates', 'ops_daily_logs');
