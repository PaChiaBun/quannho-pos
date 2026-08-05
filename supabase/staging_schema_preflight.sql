-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS & KAY RESTAURANT — STAGING SCHEMA PREFLIGHT CHECK (READ-ONLY)
-- File: supabase/staging_schema_preflight.sql
-- Note: READ-ONLY script inspecting information_schema on Staging.
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Inspect Table Existence & Column Data Types
SELECT 
  table_name, 
  column_name, 
  data_type, 
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'stores', 
    'products', 
    'product_topping_links', 
    'ban_zones', 
    'ban_dining_tables', 
    'store_members'
  )
ORDER BY table_name, ordinal_position;

-- 2. Inspect Primary Key Data Types
SELECT
  tc.table_name,
  kc.column_name,
  c.data_type
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kc 
  ON tc.constraint_name = kc.constraint_name AND tc.table_schema = kc.table_schema
JOIN information_schema.columns c
  ON kc.table_schema = c.table_schema AND kc.table_name = c.table_name AND kc.column_name = c.column_name
WHERE tc.constraint_type = 'PRIMARY KEY'
  AND tc.table_schema = 'public'
  AND tc.table_name IN (
    'stores', 
    'products', 
    'product_topping_links', 
    'ban_zones', 
    'ban_dining_tables', 
    'store_members'
  );

-- 3. Safety Check: Verify 0 Production Records Exist on Staging
SELECT 'stores' AS target, count(*) AS row_count FROM stores WHERE id = '79fd45e9-14c3-4dd2-81ba-aa288a45b472';
