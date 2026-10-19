-- ═══════════════════════════════════════════════════════════════════════════
-- PREFLIGHT SCHEMA AUDIT SCRIPT FOR PHASE 2A AI BUM (FINAL V4)
-- Status: READ-ONLY DRAFT FOR REVIEW ONLY
-- Strictly READ-ONLY SELECT queries using information_schema & pg_catalog.
-- NO DDL, NO DML, NO MUTATIONS, NO DO BLOCKS, NO SECRETS, NO GRANTS/REVOKES.
--
-- LƯU Ý BẮT BUỘC: 
-- Chưa được thiết kế migration/RPC cho tới khi script preflight này được
-- chạy trực tiếp trên môi trường Staging và kết quả thực tế được đưa lại để review.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Audit ACL trực tiếp trên schema public (phát hiện chính xác quyền PUBLIC và các roles)
SELECT
  n.nspname AS schema_name,
  CASE
    WHEN acl.grantee = 0 THEN 'PUBLIC'
    ELSE pg_catalog.pg_get_userbyid(acl.grantee)
  END AS grantee,
  acl.privilege_type,
  acl.is_grantable
FROM pg_catalog.pg_namespace n
CROSS JOIN LATERAL pg_catalog.aclexplode(
  COALESCE(
    n.nspacl,
    pg_catalog.acldefault('n', n.nspowner)
  )
) AS acl
WHERE n.nspname = 'public'
ORDER BY grantee, privilege_type;

-- 2. Kiểm tra tồn tại các bảng/cột nghiệp vụ mở rộng
SELECT 
  table_schema,
  table_name,
  column_name,
  data_type,
  udt_name,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'stores', 'user_accounts', 'store_members', 'staff_members',
    'orders', 'order_items', 'products', 'app_settings',
    'finance_records', 'finance_categories', 'staff_shifts', 'staff_profiles',
    'ops_daily_logs', 'ops_task_templates', 'materials',
    'recipes', 'production_orders', 'stock_movements', 'stock_movements_sync'
  )
ORDER BY table_name, ordinal_position;

-- 3. Phát hiện các cột quan trọng và ứng viên (Candidates)
SELECT 
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND (
    (table_name = 'orders' AND column_name IN ('total', 'status', 'created_at', 'final_amount', 'paid_amount'))
    OR (table_name = 'order_items' AND column_name IN ('qty', 'unit_price', 'quantity', 'price', 'total_price'))
    OR (table_name = 'finance_records' AND column_name IN ('recorded_at', 'created_at', 'amount', 'type', 'category_id'))
    OR (table_name = 'staff_shifts' AND column_name IN ('user_id', 'clock_in', 'clock_out', 'staff_id', 'status'))
    OR (table_name = 'ops_daily_logs' AND column_name IN ('template_id', 'log_date', 'staff_id', 'staff_name', 'status'))
    OR (table_name = 'store_members' AND column_name IN ('is_owner', 'role', 'actions', 'permissions', 'user_id', 'store_id'))
    OR (table_name = 'staff_members' AND column_name IN ('user_id', 'is_active', 'actions', 'modules', 'role'))
    OR (table_name = 'stores' AND column_name IN ('is_active', 'status', 'store_code'))
  )
ORDER BY table_name, column_name;

-- 4. Thống kê trạng thái đơn hàng (READ-ONLY Count, NO PII, NO Raw Customer Data)
SELECT 
  status, 
  COUNT(*) AS total_orders
FROM public.orders
GROUP BY status;

-- 5. Audit Constraints qua pg_catalog.pg_constraint & pg_get_constraintdef (tránh trùng tên giữa các bảng)
SELECT
  conrelid::regclass::text AS table_name,
  conname AS constraint_name,
  contype AS constraint_type,
  pg_catalog.pg_get_constraintdef(oid) AS constraint_definition
FROM pg_catalog.pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND conrelid::regclass::text IN (
    'stores', 'user_accounts', 'store_members', 'staff_members',
    'orders', 'order_items', 'products', 'app_settings',
    'finance_records', 'finance_categories', 'staff_shifts', 'staff_profiles',
    'ops_daily_logs', 'ops_task_templates', 'materials',
    'recipes', 'production_orders', 'stock_movements', 'stock_movements_sync'
  )
ORDER BY table_name, constraint_name;

-- 6. Audit Indexes
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'stores', 'user_accounts', 'store_members', 'staff_members',
    'orders', 'order_items', 'products', 'app_settings',
    'finance_records', 'finance_categories', 'staff_shifts', 'staff_profiles',
    'ops_daily_logs', 'ops_task_templates', 'materials',
    'recipes', 'production_orders', 'stock_movements', 'stock_movements_sync'
  )
ORDER BY tablename, indexname;

-- 7. Audit RLS & Force RLS Status
SELECT 
  c.relname AS table_name,
  c.relrowsecurity AS rls_enabled,
  c.relforcerowsecurity AS force_rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
  AND c.relname IN (
    'stores', 'user_accounts', 'store_members', 'staff_members',
    'orders', 'order_items', 'products', 'app_settings',
    'finance_records', 'finance_categories', 'staff_shifts', 'staff_profiles',
    'ops_daily_logs', 'ops_task_templates', 'materials',
    'recipes', 'production_orders', 'stock_movements', 'stock_movements_sync'
  )
ORDER BY c.relname;

-- 8. Audit Active RLS Policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY tablename, policyname;

-- 9. Audit Table Privileges (dùng information_schema.table_privileges không bỏ sót PUBLIC)
SELECT 
  table_name, 
  grantee, 
  privilege_type 
FROM information_schema.table_privileges 
WHERE table_schema = 'public'
  AND UPPER(grantee) IN ('ANON', 'AUTHENTICATED', 'PUBLIC', 'SERVICE_ROLE')
ORDER BY table_name, grantee, privilege_type;

-- 10. Audit Function Owner (dùng pg_roles r.oid = p.proowner), SECURITY DEFINER & search_path
SELECT 
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_catalog.pg_get_function_identity_arguments(p.oid) AS function_signature,
  r.rolname AS function_owner,
  p.prosecdef AS is_security_definer,
  p.proconfig AS search_path_config
FROM pg_catalog.pg_proc p
JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
JOIN pg_catalog.pg_roles r ON r.oid = p.proowner
WHERE n.nspname = 'public'
ORDER BY p.proname;

-- 11. Audit Routine EXECUTE Grants (bổ sung specific_name phân biệt function overload)
SELECT 
  routine_name,
  specific_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND UPPER(grantee) IN ('ANON', 'AUTHENTICATED', 'PUBLIC', 'SERVICE_ROLE')
ORDER BY routine_name, specific_name, grantee;

-- 12. Tra cứu chính xác Timezone keys trong app_settings (KHÔNG dùng LIKE '%time%')
SELECT 
  store_id, 
  key, 
  value
FROM public.app_settings
WHERE key IN ('timezone', 'store_timezone', 'time_zone');
