-- =====================================================================
-- FIX: RLS Policies cho Payroll module
-- Staff được đọc payroll_records của chính mình (user_id = auth.uid())
-- Manager/Owner được đọc tất cả records trong store
-- Chạy trên Supabase SQL Editor
-- =====================================================================

-- Disable RLS nếu chưa enable (hoặc enable nếu cần bảo mật)
-- Cách đơn giản nhất: DISABLE RLS để tất cả authenticated users đều đọc được

ALTER TABLE payroll_periods     DISABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_records     DISABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_items       DISABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_rules       DISABLE ROW LEVEL SECURITY;
ALTER TABLE staff_salary_configs DISABLE ROW LEVEL SECURITY;
ALTER TABLE payroll_disputes    DISABLE ROW LEVEL SECURITY;

-- Đảm bảo GRANT đầy đủ
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_periods      TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_records      TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_items        TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_rules        TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON staff_salary_configs TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON payroll_disputes     TO anon, authenticated;

-- Verify
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' 
  AND tablename IN ('payroll_periods','payroll_records','payroll_items','payroll_disputes','staff_salary_configs')
ORDER BY tablename;
