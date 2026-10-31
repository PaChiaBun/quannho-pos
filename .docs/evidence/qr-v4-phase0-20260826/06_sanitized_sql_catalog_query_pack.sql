-- =============================================================================
-- Phase 0C Sanitized PostgreSQL Catalog Query Pack
-- Version: 20260827.03
-- Target: Supabase SQL Editor / Trusted Direct Read-Only SQL Connection
-- Repository-safe intent: returns catalog metadata only and never queries
-- application rows. Expression bodies can contain literals in PostgreSQL, so
-- this pack deliberately suppresses runtime config, CHECK/policy expressions,
-- defaults, partial-index definitions and trigger bodies. Review exact bodies
-- only inside the trusted SQL environment; never commit the raw forms.
-- =============================================================================

-- Query 1: Migration History from Supabase Schema Migrations
SELECT version, name
FROM supabase_migrations.schema_migrations
WHERE version::text LIKE '20260731%'
   OR version::text LIKE '20260814%'
   OR version::text LIKE '20260826%'
ORDER BY version;

-- Query 2: Check presence of QR V3, QR V4, Core & Settlement relations in pg_class
SELECT n.nspname AS schema_name,
       c.relname AS table_name,
       c.relkind AS object_type,
       c.relrowsecurity AS rls_enabled,
       c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname IN (
    'qr_channels', 'qr_requests', 'qr_request_items', 'qr_audit_logs',
    'qr_handoff_tokens', 'pos_device_sessions', 'pos_store_bootstrap_state',
    'store_pairing_codes', 'pos_auth_attempts', 'product_topping_links',
    'ban_session_orders', 'payment_settlements', 'payment_settlement_orders',
    'ban_dining_tables', 'ban_sessions', 'ban_session_items',
    'orders', 'order_items', 'kitchen_tickets', 'kitchen_ticket_items',
    'finance_records', 'stock_movements', 'products', 'staff_members',
    'store_members', 'user_accounts', 'app_settings', 'stores'
  )
ORDER BY c.relname;

-- Query 3: Routine Catalog (Signatures, Security Definer status, search_path config)
SELECT p.proname AS routine_name,
       pg_get_function_identity_arguments(p.oid) AS identity_arguments,
       p.prosecdef AS is_security_definer,
       p.proconfig IS NOT NULL AS has_runtime_configuration,
       COALESCE(array_to_string(p.proconfig, ','), '') LIKE '%search_path=%'
         AS has_explicit_search_path,
       pg_get_userbyid(p.proowner) AS routine_owner
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
    p.proname LIKE '%qr%v3%'
    OR p.proname LIKE '%qr%v4%'
    OR p.proname IN ('verify_user_login_v4', 'register_user_account_v4', 'change_user_password_v4')
  )
ORDER BY p.proname, identity_arguments;

-- Query 4: Core Columns & Data Types (Information Schema Metadata Only)
SELECT table_name, ordinal_position, column_name, data_type, udt_name,
       is_nullable,
       CASE
         WHEN column_default IS NULL THEN 'NONE'
         WHEN column_default ~* '^nextval[(]' THEN 'SEQUENCE'
         WHEN column_default ~* '(gen_random_uuid|uuid_generate)' THEN 'UUID_GENERATOR'
         WHEN column_default ~* '^(true|false)(::boolean)?$' THEN 'BOOLEAN_LITERAL'
         WHEN column_default ~* '^(now[(][)]|CURRENT_TIMESTAMP)' THEN 'TIMESTAMP_GENERATOR'
         WHEN column_default ~* '^[+-]?[0-9]+([.][0-9]+)?(::[a-z0-9_ ]+)?$' THEN 'NUMERIC_LITERAL'
         ELSE 'PRESENT_REVIEW_IN_TRUSTED_ENV'
       END AS default_class
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'ban_dining_tables', 'ban_sessions', 'ban_session_items',
    'orders', 'order_items', 'kitchen_tickets', 'kitchen_ticket_items',
    'finance_records', 'stock_movements', 'products', 'product_topping_links',
    'staff_members', 'store_members', 'user_accounts', 'app_settings', 'stores',
    'ban_session_orders', 'payment_settlements', 'payment_settlement_orders'
  )
ORDER BY table_name, ordinal_position;

-- Query 5: Table Constraints (PK, FK, CHECK, UNIQUE)
SELECT format('%I.%I', n.nspname, c.relname) AS table_name,
       con.conname AS constraint_name,
       con.contype AS constraint_type,
       CASE
         WHEN con.contype = 'c' THEN 'CHECK_EXPRESSION_REVIEW_IN_TRUSTED_ENV'
         ELSE pg_get_constraintdef(con.oid)
       END AS sanitized_constraint_definition
FROM pg_constraint con
JOIN pg_class c ON c.oid = con.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND con.contype IN ('p', 'f', 'u', 'c')
  AND c.relname IN (
    'qr_channels', 'qr_requests', 'qr_request_items', 'qr_handoff_tokens',
    'ban_session_orders', 'payment_settlements', 'payment_settlement_orders',
    'ban_dining_tables', 'ban_sessions', 'ban_session_items', 'orders',
    'order_items', 'kitchen_tickets', 'kitchen_ticket_items',
    'finance_records', 'stock_movements', 'products',
    'product_topping_links', 'staff_members', 'store_members',
    'user_accounts', 'app_settings', 'stores'
  )
ORDER BY table_name, constraint_name;

-- Query 6: Row Level Security Policies
SELECT schemaname, tablename, policyname, roles, cmd,
       qual IS NOT NULL AS has_using_expression,
       with_check IS NOT NULL AS has_with_check_expression
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'qr_channels', 'qr_requests', 'qr_request_items', 'qr_handoff_tokens',
    'ban_session_orders', 'payment_settlements', 'payment_settlement_orders',
    'ban_dining_tables', 'ban_sessions', 'ban_session_items', 'orders',
    'order_items', 'kitchen_tickets', 'kitchen_ticket_items',
    'finance_records', 'stock_movements', 'products',
    'product_topping_links', 'staff_members', 'store_members',
    'user_accounts', 'app_settings', 'stores'
  )
ORDER BY tablename, policyname;

-- Query 7: Table & Column Grants for user_accounts, store_members, staff_members
SELECT table_name, grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name IN ('user_accounts', 'store_members', 'staff_members')
ORDER BY table_name, grantee, privilege_type;

SELECT table_name, column_name, grantee, privilege_type
FROM information_schema.column_privileges
WHERE table_schema = 'public'
  AND table_name = 'user_accounts'
ORDER BY column_name, grantee, privilege_type;

-- Query 8: Indexes and non-internal triggers on affected relations
SELECT schemaname, tablename, indexname,
       indexdef LIKE 'CREATE UNIQUE INDEX%' AS is_unique,
       indexdef ~* ' WHERE ' AS is_partial,
       'DEFINITION_REVIEW_IN_TRUSTED_ENV' AS definition_status
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN (
    'qr_channels', 'qr_requests', 'qr_request_items', 'qr_handoff_tokens',
    'ban_session_orders', 'payment_settlements', 'payment_settlement_orders',
    'ban_dining_tables', 'ban_sessions', 'ban_session_items', 'orders',
    'order_items', 'kitchen_tickets', 'kitchen_ticket_items',
    'finance_records', 'stock_movements', 'products',
    'product_topping_links', 'staff_members', 'store_members',
    'user_accounts', 'stores'
  )
ORDER BY tablename, indexname;

SELECT event_object_table AS table_name, trigger_name, event_manipulation,
       action_timing, action_orientation,
       'BODY_REVIEW_IN_TRUSTED_ENV' AS action_statement_status
FROM information_schema.triggers
WHERE trigger_schema = 'public'
  AND event_object_table IN (
    'qr_channels', 'qr_requests', 'qr_request_items', 'qr_handoff_tokens',
    'ban_session_orders', 'payment_settlements', 'payment_settlement_orders',
    'ban_sessions', 'ban_session_items', 'orders', 'order_items',
    'kitchen_tickets', 'kitchen_ticket_items', 'finance_records',
    'stock_movements', 'user_accounts', 'store_members', 'staff_members'
  )
ORDER BY table_name, trigger_name, event_manipulation;

-- Query 9: Routine execute ACLs (metadata only)
SELECT routine_name, specific_name, grantee, privilege_type
FROM information_schema.routine_privileges
WHERE specific_schema = 'public'
  AND (
    routine_name LIKE '%qr%v3%'
    OR routine_name LIKE '%qr%v4%'
    OR routine_name IN (
      'verify_user_login_v4', 'register_user_account_v4',
      'change_user_password_v4'
    )
  )
ORDER BY routine_name, specific_name, grantee, privilege_type;
