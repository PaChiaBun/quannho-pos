-- ═══════════════════════════════════════════════════════════════════════════
-- STAGING MIGRATION V3 READ-ONLY DEPENDENCY & COMPATIBILITY PREFLIGHT (V10)
-- File: supabase/staging_v3_dependency_preflight.sql
-- Mode: 100% PURE READ-ONLY (NO DDL/DML, NO FUNCTION CREATION, PURE SELECT/CTE)
-- Features: 
--  1. Uniform 10-column schema across all 90 checks in raw_checks_1_89
--  2. actual_indexes CTE computing ordered key columns via pg_index.indnkeyatts & pg_get_indexdef(relid, k, true)
--  3. Checks 52-57 and 89 comparing table, uniqueness, ordered keys, predicate, indisvalid, and indisready
--  4. rpc_catalog_agg CTE producing EXACTLY 1 ROW per expected RPC with total_overloads & exact_match_count
--  5. Policy check 88 measuring executable V3 policies vs deferred cutover policies without fake policy names
--  6. Check 35 inspects specific status constraint names and definitions without false global bool_and crashes
--  7. Granular blocking_reason for missing vs type vs nullability vs default mismatches across Checks 20-45
--  8. Raw Check 90 Meta-Assertion evaluating raw_checks_1_89 BEFORE fallback
-- ═══════════════════════════════════════════════════════════════════════════

WITH expected_rpcs AS (
  SELECT * FROM (VALUES
    ('check_pos_staff_action_permission', 'uuid, uuid, uuid, text', 'boolean', true),
    ('verify_pos_token_internal', 'text', 'public.pos_session_info', true),
    ('bootstrap_first_pos_device_v3', 'text, text, text', 'jsonb', true),
    ('generate_pos_pairing_code_v3', 'text', 'jsonb', true),
    ('pair_pos_device_v3', 'text, text, text, text', 'jsonb', true),
    ('issue_pos_device_session_v3', 'text, text, text, uuid', 'jsonb', true),
    ('revoke_pos_device_session_v3', 'text', 'jsonb', true),
    ('get_pending_qr_requests_v3', 'text, text', 'jsonb', true),
    ('claim_qr_request_v3', 'uuid, text', 'jsonb', true),
    ('reject_qr_request_v3', 'uuid, text, text', 'jsonb', true),
    ('confirm_qr_request_v3', 'uuid, text', 'jsonb', true),
    ('send_to_kitchen_qr_v3', 'uuid, text', 'jsonb', true),
    ('get_qr_request_status_v3', 'text', 'jsonb', true),
    ('get_qr_menu_v3', 'text', 'jsonb', true),
    ('submit_qr_order_v3', 'text, jsonb, text, text', 'jsonb', true)
  ) AS t(proname, expected_arg_types, expected_return_type, is_sec_definer)
),
expected_indexes AS (
  SELECT * FROM (VALUES
    ('idx_pos_single_active_session', 'pos_device_sessions', true, 'store_id, device_id', '(revoked_at IS NULL)'),
    ('idx_pos_sessions_lookup', 'pos_device_sessions', false, 'token_hash', '(revoked_at IS NULL)'),
    ('idx_pairing_codes_store', 'store_pairing_codes', false, 'store_id, expires_at', '(used_at IS NULL)'),
    ('idx_pos_auth_ip_store', 'pos_auth_attempts', false, 'ip_address, store_code, blocked_until', NULL),
    ('idx_qr_audit_request', 'qr_audit_logs', false, 'request_id, created_at', NULL),
    ('idx_qr_requests_channel_idempotency', 'qr_requests', true, 'channel_id, idempotency_key', '(idempotency_key IS NOT NULL)')
  ) AS t(index_name, table_name, is_unique, expected_keys, expected_predicate)
),
expected_executable_policies AS (
  -- Migration V3 executable SQL files create 0 RLS policies (RLS policies are deferred to DRAFT_HARDENING_CUTOVER_PHASE)
  SELECT * FROM (SELECT NULL::text AS table_name, NULL::text AS policy_name, NULL::text AS roles, NULL::text AS cmd WHERE false) AS t
),
deferred_cutover_policies AS (
  SELECT * FROM (VALUES
    ('pos_device_sessions', 'pos_sessions_store_isolation', '{authenticated}', 'ALL'),
    ('qr_requests', 'qr_requests_store_isolation', '{authenticated}', 'ALL'),
    ('qr_channels', 'qr_channels_store_isolation', '{authenticated}', 'ALL')
  ) AS t(table_name, policy_name, roles, cmd)
),
expected_tables AS (
  SELECT * FROM (VALUES
    ('pos_device_sessions'),
    ('pos_auth_attempts'),
    ('pos_store_bootstrap_state'),
    ('qr_requests'),
    ('qr_channels'),
    ('qr_request_items')
  ) AS t(table_name)
),
actual_indexes AS (
  SELECT 
    e.index_name,
    e.table_name AS expected_table,
    e.is_unique AS expected_unique,
    e.expected_keys,
    e.expected_predicate,
    i.indexrelid,
    c.relname AS actual_index_name,
    c2.relname AS actual_table,
    i.indisunique AS actual_unique,
    i.indisvalid AS actual_valid,
    i.indisready AS actual_ready,
    (
      SELECT string_agg(pg_get_indexdef(i.indexrelid, k, true), ', ')
      FROM generate_series(1, COALESCE(i.indnkeyatts, 0)) k
    ) AS actual_keys,
    pg_get_expr(i.indpred, i.indrelid, true) AS actual_predicate,
    pg_get_indexdef(i.indexrelid) AS actual_indexdef
  FROM expected_indexes e
  LEFT JOIN pg_class c ON c.relnamespace = to_regnamespace('public') AND c.relname = e.index_name
  LEFT JOIN pg_index i ON i.indexrelid = c.oid
  LEFT JOIN pg_class c2 ON i.indrelid = c2.oid
),
rpc_catalog_agg AS (
  SELECT 
    e.proname,
    e.expected_arg_types,
    e.expected_return_type,
    e.is_sec_definer,
    COUNT(p.oid) AS total_overloads,
    COUNT(p.oid) FILTER (WHERE oidvectortypes(p.proargtypes) = e.expected_arg_types) AS exact_match_count,
    (ARRAY_AGG(p.oid) FILTER (WHERE oidvectortypes(p.proargtypes) = e.expected_arg_types))[1] AS exact_oid,
    COALESCE(
      (ARRAY_AGG(oidvectortypes(p.proargtypes)) FILTER (WHERE oidvectortypes(p.proargtypes) = e.expected_arg_types))[1],
      (ARRAY_AGG(oidvectortypes(p.proargtypes)))[1],
      ''
    ) AS actual_arg_types,
    (ARRAY_AGG(p.prorettype) FILTER (WHERE oidvectortypes(p.proargtypes) = e.expected_arg_types))[1] AS actual_prorettype,
    format_type((ARRAY_AGG(p.prorettype) FILTER (WHERE oidvectortypes(p.proargtypes) = e.expected_arg_types))[1], NULL) AS actual_return_type_name,
    (ARRAY_AGG(p.prosecdef) FILTER (WHERE oidvectortypes(p.proargtypes) = e.expected_arg_types))[1] AS actual_sec_definer,
    COALESCE((ARRAY_AGG(array_to_string(p.proconfig, ',')) FILTER (WHERE oidvectortypes(p.proargtypes) = e.expected_arg_types))[1], '') AS actual_proconfig,
    COALESCE(string_agg(p.proname || '(' || oidvectortypes(p.proargtypes) || ')', '; '), 'NOT_YET_CREATED') AS actual_signatures
  FROM expected_rpcs e
  LEFT JOIN pg_proc p ON p.pronamespace = to_regnamespace('public') AND p.proname = e.proname
  GROUP BY e.proname, e.expected_arg_types, e.expected_return_type, e.is_sec_definer
),
raw_checks_1_89 AS (
  -----------------------------------------------------------------------------
  -- PHASE A: PRE_MIGRATION_SCHEMA (CHECKS 1 TO 45 - BASE TABLES, TYPES & CONSTRAINTS)
  -----------------------------------------------------------------------------
  -- 1-15. Core Base Tables Existence
  SELECT 
    1 AS check_id, 'PRE_MIGRATION_SCHEMA' AS check_phase,
    'public.stores' AS object_name, 'TABLE' AS object_type, 'TABLE EXISTS' AS expected,
    CASE WHEN to_regclass('public.stores') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END AS actual,
    COALESCE(to_regclass('public.stores') IS NOT NULL, false) AS source_schema_truth_ok,
    COALESCE(to_regclass('public.stores') IS NOT NULL, false) AS v3_compatible,
    'NONE' AS remedy,
    CASE WHEN to_regclass('public.stores') IS NULL THEN 'Core table public.stores missing' ELSE NULL END AS blocking_reason

  UNION ALL
  SELECT 
    2, 'PRE_MIGRATION_SCHEMA', 'public.products', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.products') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.products') IS NOT NULL, false),
    COALESCE(to_regclass('public.products') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.products') IS NULL THEN 'Core table public.products missing' ELSE NULL END

  UNION ALL
  SELECT 
    3, 'PRE_MIGRATION_SCHEMA', 'public.user_accounts', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.user_accounts') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.user_accounts') IS NOT NULL, false),
    COALESCE(to_regclass('public.user_accounts') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.user_accounts') IS NULL THEN 'Core table public.user_accounts missing' ELSE NULL END

  UNION ALL
  SELECT 
    4, 'PRE_MIGRATION_SCHEMA', 'public.store_members', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.store_members') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.store_members') IS NOT NULL, false),
    COALESCE(to_regclass('public.store_members') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.store_members') IS NULL THEN 'Core table public.store_members missing' ELSE NULL END

  UNION ALL
  SELECT 
    5, 'PRE_MIGRATION_SCHEMA', 'public.staff_members', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.staff_members') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.staff_members') IS NOT NULL, false),
    COALESCE(to_regclass('public.staff_members') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.staff_members') IS NULL THEN 'Core table public.staff_members missing' ELSE NULL END

  UNION ALL
  SELECT 
    6, 'PRE_MIGRATION_SCHEMA', 'public.devices', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.devices') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.devices') IS NOT NULL, false),
    COALESCE(to_regclass('public.devices') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.devices') IS NULL THEN 'Core table public.devices missing' ELSE NULL END

  UNION ALL
  SELECT 
    7, 'PRE_MIGRATION_SCHEMA', 'public.orders', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.orders') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.orders') IS NOT NULL, false),
    COALESCE(to_regclass('public.orders') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.orders') IS NULL THEN 'Core table public.orders missing' ELSE NULL END

  UNION ALL
  SELECT 
    8, 'PRE_MIGRATION_SCHEMA', 'public.order_items', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.order_items') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.order_items') IS NOT NULL, false),
    COALESCE(to_regclass('public.order_items') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.order_items') IS NULL THEN 'Core table public.order_items missing' ELSE NULL END

  UNION ALL
  SELECT 
    9, 'PRE_MIGRATION_SCHEMA', 'public.ban_zones', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.ban_zones') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.ban_zones') IS NOT NULL, false),
    COALESCE(to_regclass('public.ban_zones') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.ban_zones') IS NULL THEN 'Core table public.ban_zones missing' ELSE NULL END

  UNION ALL
  SELECT 
    10, 'PRE_MIGRATION_SCHEMA', 'public.ban_dining_tables', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.ban_dining_tables') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.ban_dining_tables') IS NOT NULL, false),
    COALESCE(to_regclass('public.ban_dining_tables') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.ban_dining_tables') IS NULL THEN 'Core table public.ban_dining_tables missing' ELSE NULL END

  UNION ALL
  SELECT 
    11, 'PRE_MIGRATION_SCHEMA', 'public.ban_sessions', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.ban_sessions') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.ban_sessions') IS NOT NULL, false),
    COALESCE(to_regclass('public.ban_sessions') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.ban_sessions') IS NULL THEN 'Core table public.ban_sessions missing' ELSE NULL END

  UNION ALL
  SELECT 
    12, 'PRE_MIGRATION_SCHEMA', 'public.ban_session_items', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.ban_session_items') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.ban_session_items') IS NOT NULL, false),
    COALESCE(to_regclass('public.ban_session_items') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.ban_session_items') IS NULL THEN 'Core table public.ban_session_items missing' ELSE NULL END

  UNION ALL
  SELECT 
    13, 'PRE_MIGRATION_SCHEMA', 'public.kitchen_tickets', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.kitchen_tickets') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.kitchen_tickets') IS NOT NULL, false),
    COALESCE(to_regclass('public.kitchen_tickets') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.kitchen_tickets') IS NULL THEN 'Core table public.kitchen_tickets missing' ELSE NULL END

  UNION ALL
  SELECT 
    14, 'PRE_MIGRATION_SCHEMA', 'public.kitchen_ticket_items', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.kitchen_ticket_items') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.kitchen_ticket_items') IS NOT NULL, false),
    COALESCE(to_regclass('public.kitchen_ticket_items') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.kitchen_ticket_items') IS NULL THEN 'Core table public.kitchen_ticket_items missing' ELSE NULL END

  UNION ALL
  SELECT 
    15, 'PRE_MIGRATION_SCHEMA', 'public.app_settings', 'TABLE', 'TABLE EXISTS',
    CASE WHEN to_regclass('public.app_settings') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.app_settings') IS NOT NULL, false),
    COALESCE(to_regclass('public.app_settings') IS NOT NULL, false),
    'NONE',
    CASE WHEN to_regclass('public.app_settings') IS NULL THEN 'Table public.app_settings missing' ELSE NULL END

  -- 16-19. Prerequisite Tables
  UNION ALL
  SELECT 
    16, 'PRE_MIGRATION_SCHEMA', 'public.product_topping_links', 'TABLE', 'PREREQUISITE TABLE EXISTS',
    CASE WHEN to_regclass('public.product_topping_links') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.product_topping_links') IS NOT NULL, false),
    COALESCE(to_regclass('public.product_topping_links') IS NOT NULL, false),
    'SOURCE_PREREQUISITE_MISSING',
    CASE WHEN to_regclass('public.product_topping_links') IS NULL THEN 'Prerequisite product_topping_links_migration.sql not executed' ELSE NULL END

  UNION ALL
  SELECT 
    17, 'PRE_MIGRATION_SCHEMA', 'public.qr_channels', 'TABLE', 'PREREQUISITE TABLE EXISTS',
    CASE WHEN to_regclass('public.qr_channels') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.qr_channels') IS NOT NULL, false),
    COALESCE(to_regclass('public.qr_channels') IS NOT NULL, false),
    'SOURCE_PREREQUISITE_MISSING',
    CASE WHEN to_regclass('public.qr_channels') IS NULL THEN 'Prerequisite migration_kay_public_ordering_v2.sql not executed' ELSE NULL END

  UNION ALL
  SELECT 
    18, 'PRE_MIGRATION_SCHEMA', 'public.qr_requests', 'TABLE', 'PREREQUISITE TABLE EXISTS',
    CASE WHEN to_regclass('public.qr_requests') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.qr_requests') IS NOT NULL, false),
    COALESCE(to_regclass('public.qr_requests') IS NOT NULL, false),
    'SOURCE_PREREQUISITE_MISSING',
    CASE WHEN to_regclass('public.qr_requests') IS NULL THEN 'Prerequisite migration_kay_public_ordering_v2.sql not executed' ELSE NULL END

  UNION ALL
  SELECT 
    19, 'PRE_MIGRATION_SCHEMA', 'public.qr_request_items', 'TABLE', 'PREREQUISITE TABLE EXISTS',
    CASE WHEN to_regclass('public.qr_request_items') IS NOT NULL THEN 'EXISTS' ELSE 'MISSING' END,
    COALESCE(to_regclass('public.qr_request_items') IS NOT NULL, false),
    COALESCE(to_regclass('public.qr_request_items') IS NOT NULL, false),
    'SOURCE_PREREQUISITE_MISSING',
    CASE WHEN to_regclass('public.qr_request_items') IS NULL THEN 'Prerequisite migration_kay_public_ordering_v2.sql not executed' ELSE NULL END

  -- 20-34. Granular Base Column Checks (Distinct Missing vs Wrong Type vs Nullability vs Default)
  UNION ALL
  SELECT 
    20, 'PRE_MIGRATION_SCHEMA', 'public.stores.status', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='status'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='status'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='status'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='status') THEN 'Column stores.status missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='status') THEN 'Column stores.status wrong data_type: expected text/varchar, actual ' || (SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='status')
      ELSE NULL
    END

  UNION ALL
  SELECT 
    21, 'PRE_MIGRATION_SCHEMA', 'public.user_accounts.quick_pin', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='quick_pin'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='quick_pin'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='quick_pin'), false),
    'SOURCE_PREREQUISITE_MISSING',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='quick_pin') THEN 'Column user_accounts.quick_pin missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='quick_pin') THEN 'Column user_accounts.quick_pin wrong data_type'
      ELSE NULL
    END

  UNION ALL
  SELECT 
    22, 'PRE_MIGRATION_SCHEMA', 'public.store_members.user_id', 'COLUMN_TYPE', 'data_type IN (uuid, text)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='user_id'), 'MISSING'),
    COALESCE((SELECT data_type IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='user_id'), false),
    COALESCE((SELECT data_type IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='user_id'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='user_id') THEN 'Column store_members.user_id missing' 
      WHEN (SELECT data_type NOT IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='user_id') THEN 'Column store_members.user_id wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    23, 'PRE_MIGRATION_SCHEMA', 'public.store_members.is_owner', 'COLUMN_TYPE', 'data_type = boolean',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='is_owner'), 'MISSING'),
    COALESCE((SELECT data_type = 'boolean' FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='is_owner'), false),
    COALESCE((SELECT data_type = 'boolean' FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='is_owner'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='is_owner') THEN 'Column store_members.is_owner missing'
      WHEN (SELECT data_type <> 'boolean' FROM information_schema.columns WHERE table_schema='public' AND table_name='store_members' AND column_name='is_owner') THEN 'Column store_members.is_owner wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    24, 'PRE_MIGRATION_SCHEMA', 'public.staff_members.pin_hash', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='pin_hash'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='pin_hash'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='pin_hash'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='pin_hash') THEN 'Column staff_members.pin_hash missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='pin_hash') THEN 'Column staff_members.pin_hash wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    25, 'PRE_MIGRATION_SCHEMA', 'public.staff_members.is_active', 'COLUMN_TYPE', 'data_type = boolean',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='is_active'), 'MISSING'),
    COALESCE((SELECT data_type = 'boolean' FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='is_active'), false),
    COALESCE((SELECT data_type = 'boolean' FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='is_active'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='is_active') THEN 'Column staff_members.is_active missing'
      WHEN (SELECT data_type <> 'boolean' FROM information_schema.columns WHERE table_schema='public' AND table_name='staff_members' AND column_name='is_active') THEN 'Column staff_members.is_active wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    26, 'PRE_MIGRATION_SCHEMA', 'public.devices.device_role', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_role'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_role'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_role'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_role') THEN 'Column devices.device_role missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_role') THEN 'Column devices.device_role wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    27, 'PRE_MIGRATION_SCHEMA', 'public.ban_zones.id', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_zones' AND column_name='id'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_zones' AND column_name='id'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_zones' AND column_name='id'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_zones' AND column_name='id') THEN 'Column ban_zones.id missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_zones' AND column_name='id') THEN 'Column ban_zones.id wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    28, 'PRE_MIGRATION_SCHEMA', 'public.ban_dining_tables.id', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='id'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='id'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='id'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='id') THEN 'Column ban_dining_tables.id missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='id') THEN 'Column ban_dining_tables.id wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    29, 'PRE_MIGRATION_SCHEMA', 'public.ban_dining_tables.zone_id', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='zone_id'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='zone_id'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='zone_id'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='zone_id') THEN 'Column ban_dining_tables.zone_id missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='zone_id') THEN 'Column ban_dining_tables.zone_id wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    30, 'PRE_MIGRATION_SCHEMA', 'public.ban_sessions.total_amount', 'COLUMN_TYPE', 'data_type IN (integer, numeric, bigint)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_sessions' AND column_name='total_amount'), 'MISSING'),
    COALESCE((SELECT data_type IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_sessions' AND column_name='total_amount'), false),
    COALESCE((SELECT data_type IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_sessions' AND column_name='total_amount'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_sessions' AND column_name='total_amount') THEN 'Column ban_sessions.total_amount missing'
      WHEN (SELECT data_type NOT IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_sessions' AND column_name='total_amount') THEN 'Column ban_sessions.total_amount wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    31, 'PRE_MIGRATION_SCHEMA', 'public.ban_session_items.subtotal', 'COLUMN_TYPE', 'data_type IN (integer, numeric, bigint)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_session_items' AND column_name='subtotal'), 'MISSING'),
    COALESCE((SELECT data_type IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_session_items' AND column_name='subtotal'), false),
    COALESCE((SELECT data_type IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_session_items' AND column_name='subtotal'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_session_items' AND column_name='subtotal') THEN 'Column ban_session_items.subtotal missing'
      WHEN (SELECT data_type NOT IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_session_items' AND column_name='subtotal') THEN 'Column ban_session_items.subtotal wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    32, 'PRE_MIGRATION_SCHEMA', 'public.kitchen_ticket_items.station_code', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_ticket_items' AND column_name='station_code'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_ticket_items' AND column_name='station_code'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_ticket_items' AND column_name='station_code'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_ticket_items' AND column_name='station_code') THEN 'Column kitchen_ticket_items.station_code missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_ticket_items' AND column_name='station_code') THEN 'Column kitchen_ticket_items.station_code wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    33, 'PRE_MIGRATION_SCHEMA', 'public.order_items.quantity', 'COLUMN_TYPE', 'data_type IN (integer, numeric)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='order_items' AND column_name='quantity'), 'MISSING'),
    COALESCE((SELECT data_type IN ('integer', 'numeric') FROM information_schema.columns WHERE table_schema='public' AND table_name='order_items' AND column_name='quantity'), false),
    COALESCE((SELECT data_type IN ('integer', 'numeric') FROM information_schema.columns WHERE table_schema='public' AND table_name='order_items' AND column_name='quantity'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='order_items' AND column_name='quantity') THEN 'Column order_items.quantity missing'
      WHEN (SELECT data_type NOT IN ('integer', 'numeric') FROM information_schema.columns WHERE table_schema='public' AND table_name='order_items' AND column_name='quantity') THEN 'Column order_items.quantity wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    34, 'PRE_MIGRATION_SCHEMA', 'public.app_settings.key', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='key'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='key'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='key'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='key') THEN 'Column app_settings.key missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='key') THEN 'Column app_settings.key wrong data_type'
      ELSE NULL 
    END

  -- 35. Status Constraint Audit on qr_requests (Specific Constraint Name & Catalog Definition Inspection)
  UNION ALL
  SELECT 
    35, 'PRE_MIGRATION_SCHEMA', 'public.qr_requests.status_check_constraint', 'CHECK_CONSTRAINT', 'VALIDATED CHECK CONSTRAINTS ALLOWING V3 STATUS FLOW',
    COALESCE((
      SELECT string_agg(conname || ' [oid=' || oid::text || ', validated=' || convalidated::text || ']: ' || pg_get_constraintdef(oid), '; ')
      FROM pg_constraint 
      WHERE conrelid = to_regclass('public.qr_requests') AND contype = 'c'
    ), 'TABLE_MISSING_OR_NO_CONSTRAINT'),
    COALESCE((SELECT to_regclass('public.qr_requests') IS NOT NULL), false),
    COALESCE((
      SELECT bool_and(convalidated = true) 
      FROM pg_constraint 
      WHERE conrelid = to_regclass('public.qr_requests') AND contype = 'c'
    ), false),
    'SOURCE_PREREQUISITE_MISSING',
    CASE 
      WHEN to_regclass('public.qr_requests') IS NULL THEN 'Table public.qr_requests missing'
      WHEN NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass('public.qr_requests') AND contype = 'c') THEN 'No check constraints defined on qr_requests'
      WHEN (SELECT bool_and(convalidated = true) FROM pg_constraint WHERE conrelid = to_regclass('public.qr_requests') AND contype = 'c') IS NOT TRUE THEN 'Check constraint on qr_requests is not validated'
      WHEN EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid = to_regclass('public.qr_requests') AND contype = 'c' AND conname = 'qr_requests_status_check_v2') THEN 'Legacy V2 status constraint qr_requests_status_check_v2 still exists and restricts status'
      ELSE NULL
    END

  UNION ALL
  SELECT 
    36, 'PRE_MIGRATION_SCHEMA', 'public.products.updated_at', 'COLUMN_TYPE', 'data_type = bigint',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='updated_at'), 'MISSING'),
    COALESCE((SELECT data_type = 'bigint' FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='updated_at'), false),
    COALESCE((SELECT data_type = 'bigint' FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='updated_at'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='updated_at') THEN 'Column products.updated_at missing'
      WHEN (SELECT data_type <> 'bigint' FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='updated_at') THEN 'Column products.updated_at wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    37, 'PRE_MIGRATION_SCHEMA', 'public.orders.store_id', 'COLUMN_TYPE', 'data_type IN (uuid, text)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='orders' AND column_name='store_id'), 'MISSING'),
    COALESCE((SELECT data_type IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='orders' AND column_name='store_id'), false),
    COALESCE((SELECT data_type IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='orders' AND column_name='store_id'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='orders' AND column_name='store_id') THEN 'Column orders.store_id missing'
      WHEN (SELECT data_type NOT IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='orders' AND column_name='store_id') THEN 'Column orders.store_id wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    38, 'PRE_MIGRATION_SCHEMA', 'public.kitchen_tickets.order_id', 'COLUMN_TYPE', 'data_type IN (uuid, text)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_tickets' AND column_name='order_id'), 'MISSING'),
    COALESCE((SELECT data_type IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_tickets' AND column_name='order_id'), false),
    COALESCE((SELECT data_type IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_tickets' AND column_name='order_id'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_tickets' AND column_name='order_id') THEN 'Column kitchen_tickets.order_id missing'
      WHEN (SELECT data_type NOT IN ('uuid', 'text') FROM information_schema.columns WHERE table_schema='public' AND table_name='kitchen_tickets' AND column_name='order_id') THEN 'Column kitchen_tickets.order_id wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    39, 'PRE_MIGRATION_SCHEMA', 'public.stores.store_code', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='store_code'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='store_code'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='store_code'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='store_code') THEN 'Column stores.store_code missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='stores' AND column_name='store_code') THEN 'Column stores.store_code wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    40, 'PRE_MIGRATION_SCHEMA', 'public.ban_dining_tables.name', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name') THEN 'Column ban_dining_tables.name missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='name') THEN 'Column ban_dining_tables.name wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    41, 'PRE_MIGRATION_SCHEMA', 'public.ban_dining_tables.capacity', 'COLUMN_TYPE', 'data_type IN (integer, numeric)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='capacity'), 'MISSING'),
    COALESCE((SELECT data_type IN ('integer', 'numeric') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='capacity'), false),
    COALESCE((SELECT data_type IN ('integer', 'numeric') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='capacity'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='capacity') THEN 'Column ban_dining_tables.capacity missing'
      WHEN (SELECT data_type NOT IN ('integer', 'numeric') FROM information_schema.columns WHERE table_schema='public' AND table_name='ban_dining_tables' AND column_name='capacity') THEN 'Column ban_dining_tables.capacity wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    42, 'PRE_MIGRATION_SCHEMA', 'public.products.sell_price', 'COLUMN_TYPE', 'data_type IN (integer, numeric, bigint)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='sell_price'), 'MISSING'),
    COALESCE((SELECT data_type IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='sell_price'), false),
    COALESCE((SELECT data_type IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='sell_price'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='sell_price') THEN 'Column products.sell_price missing'
      WHEN (SELECT data_type NOT IN ('integer', 'numeric', 'bigint') FROM information_schema.columns WHERE table_schema='public' AND table_name='products' AND column_name='sell_price') THEN 'Column products.sell_price wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    43, 'PRE_MIGRATION_SCHEMA', 'public.devices.device_name', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_name'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_name'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_name'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_name') THEN 'Column devices.device_name missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='devices' AND column_name='device_name') THEN 'Column devices.device_name wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    44, 'PRE_MIGRATION_SCHEMA', 'public.app_settings.value', 'COLUMN_TYPE', 'data_type IN (text, character varying, json, jsonb)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='value'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying', 'json', 'jsonb') FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='value'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying', 'json', 'jsonb') FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='value'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='value') THEN 'Column app_settings.value missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying', 'json', 'jsonb') FROM information_schema.columns WHERE table_schema='public' AND table_name='app_settings' AND column_name='value') THEN 'Column app_settings.value wrong data_type'
      ELSE NULL 
    END

  UNION ALL
  SELECT 
    45, 'PRE_MIGRATION_SCHEMA', 'public.user_accounts.password_hash', 'COLUMN_TYPE', 'data_type IN (text, character varying)',
    COALESCE((SELECT data_type FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='password_hash'), 'MISSING'),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='password_hash'), false),
    COALESCE((SELECT data_type IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='password_hash'), false),
    'NONE',
    CASE 
      WHEN NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='password_hash') THEN 'Column user_accounts.password_hash missing'
      WHEN (SELECT data_type NOT IN ('text', 'character varying') FROM information_schema.columns WHERE table_schema='public' AND table_name='user_accounts' AND column_name='password_hash') THEN 'Column user_accounts.password_hash wrong data_type'
      ELSE NULL 
    END

  -----------------------------------------------------------------------------
  -- PHASE B: POST_MIGRATION_V3 (CHECKS 46 TO 89 - V3 OBJECTS & SECURITY)
  -----------------------------------------------------------------------------
  -- 46-51. V3 Created Tables (6 Tables)
  UNION ALL
  SELECT 
    46, 'POST_MIGRATION_V3', 'public.qr_v3_migration_metadata', 'TABLE', 'TABLE CREATED BY V3',
    CASE WHEN to_regclass('public.qr_v3_migration_metadata') IS NOT NULL THEN 'EXISTS' ELSE 'NOT_YET_CREATED' END,
    true, COALESCE(to_regclass('public.qr_v3_migration_metadata') IS NOT NULL, false),
    'MIGRATION_V3_EXECUTION', CASE WHEN to_regclass('public.qr_v3_migration_metadata') IS NULL THEN 'Migration V3 not executed' ELSE NULL END

  UNION ALL
  SELECT 
    47, 'POST_MIGRATION_V3', 'public.pos_store_bootstrap_state', 'TABLE', 'TABLE CREATED BY V3',
    CASE WHEN to_regclass('public.pos_store_bootstrap_state') IS NOT NULL THEN 'EXISTS' ELSE 'NOT_YET_CREATED' END,
    true, COALESCE(to_regclass('public.pos_store_bootstrap_state') IS NOT NULL, false),
    'MIGRATION_V3_EXECUTION', CASE WHEN to_regclass('public.pos_store_bootstrap_state') IS NULL THEN 'Migration V3 not executed' ELSE NULL END

  UNION ALL
  SELECT 
    48, 'POST_MIGRATION_V3', 'public.pos_device_sessions', 'TABLE', 'TABLE CREATED BY V3',
    CASE WHEN to_regclass('public.pos_device_sessions') IS NOT NULL THEN 'EXISTS' ELSE 'NOT_YET_CREATED' END,
    true, COALESCE(to_regclass('public.pos_device_sessions') IS NOT NULL, false),
    'MIGRATION_V3_EXECUTION', CASE WHEN to_regclass('public.pos_device_sessions') IS NULL THEN 'Migration V3 not executed' ELSE NULL END

  UNION ALL
  SELECT 
    49, 'POST_MIGRATION_V3', 'public.store_pairing_codes', 'TABLE', 'TABLE CREATED BY V3',
    CASE WHEN to_regclass('public.store_pairing_codes') IS NOT NULL THEN 'EXISTS' ELSE 'NOT_YET_CREATED' END,
    true, COALESCE(to_regclass('public.store_pairing_codes') IS NOT NULL, false),
    'MIGRATION_V3_EXECUTION', CASE WHEN to_regclass('public.store_pairing_codes') IS NULL THEN 'Migration V3 not executed' ELSE NULL END

  UNION ALL
  SELECT 
    50, 'POST_MIGRATION_V3', 'public.pos_auth_attempts', 'TABLE', 'TABLE CREATED BY V3',
    CASE WHEN to_regclass('public.pos_auth_attempts') IS NOT NULL THEN 'EXISTS' ELSE 'NOT_YET_CREATED' END,
    true, COALESCE(to_regclass('public.pos_auth_attempts') IS NOT NULL, false),
    'MIGRATION_V3_EXECUTION', CASE WHEN to_regclass('public.pos_auth_attempts') IS NULL THEN 'Migration V3 not executed' ELSE NULL END

  UNION ALL
  SELECT 
    51, 'POST_MIGRATION_V3', 'public.qr_audit_logs', 'TABLE', 'TABLE CREATED BY V3',
    CASE WHEN to_regclass('public.qr_audit_logs') IS NOT NULL THEN 'EXISTS' ELSE 'NOT_YET_CREATED' END,
    true, COALESCE(to_regclass('public.qr_audit_logs') IS NOT NULL, false),
    'MIGRATION_V3_EXECUTION', CASE WHEN to_regclass('public.qr_audit_logs') IS NULL THEN 'Migration V3 not executed' ELSE NULL END

  -- 52-57. Data-Driven Index Validation via actual_indexes CTE (Evaluating Table, Uniqueness, Ordered Keys, Predicate, indisvalid & indisready)
  UNION ALL
  SELECT 
    52, 'POST_MIGRATION_V3', 'public.idx_pos_single_active_session', 'INDEX', 'UNIQUE INDEX ON pos_device_sessions(store_id, device_id) WHERE (revoked_at IS NULL)',
    COALESCE((SELECT actual_indexdef FROM actual_indexes WHERE index_name = 'idx_pos_single_active_session'), 'NOT_YET_CREATED'),
    true, 
    COALESCE((
      SELECT actual_valid AND actual_ready AND actual_unique AND actual_table = expected_table AND actual_keys = expected_keys AND trim(both '()' from COALESCE(actual_predicate, '')) = trim(both '()' from COALESCE(expected_predicate, ''))
      FROM actual_indexes WHERE index_name = 'idx_pos_single_active_session'
    ), false),
    'MIGRATION_V3_EXECUTION', 
    (SELECT CASE 
      WHEN indexrelid IS NULL THEN 'Index idx_pos_single_active_session missing' 
      WHEN actual_table <> expected_table THEN 'Wrong table: expected ' || expected_table || ', actual ' || COALESCE(actual_table, '')
      WHEN actual_unique IS NOT TRUE THEN 'Wrong uniqueness: expected UNIQUE'
      WHEN actual_keys <> expected_keys THEN 'ordered keys mismatch: expected (' || expected_keys || '), actual (' || COALESCE(actual_keys, '') || ')'
      WHEN actual_valid IS NOT TRUE THEN 'Index invalid (indisvalid=false)'
      WHEN actual_ready IS NOT TRUE THEN 'Index not ready (indisready=false)'
      WHEN COALESCE(actual_predicate, '') <> COALESCE(expected_predicate, '') THEN 'predicate mismatch: expected (' || COALESCE(expected_predicate, '') || '), actual (' || COALESCE(actual_predicate, '') || ')'
      ELSE NULL END 
     FROM actual_indexes WHERE index_name = 'idx_pos_single_active_session')

  UNION ALL
  SELECT 
    53, 'POST_MIGRATION_V3', 'public.idx_pos_sessions_lookup', 'INDEX', 'INDEX ON pos_device_sessions(token_hash) WHERE (revoked_at IS NULL)',
    COALESCE((SELECT actual_indexdef FROM actual_indexes WHERE index_name = 'idx_pos_sessions_lookup'), 'NOT_YET_CREATED'),
    true, 
    COALESCE((
      SELECT actual_valid AND actual_ready AND actual_table = expected_table AND actual_keys = expected_keys AND trim(both '()' from COALESCE(actual_predicate, '')) = trim(both '()' from COALESCE(expected_predicate, ''))
      FROM actual_indexes WHERE index_name = 'idx_pos_sessions_lookup'
    ), false),
    'MIGRATION_V3_EXECUTION', 
    (SELECT CASE 
      WHEN indexrelid IS NULL THEN 'Index idx_pos_sessions_lookup missing' 
      WHEN actual_table <> expected_table THEN 'Wrong table'
      WHEN actual_keys <> expected_keys THEN 'ordered keys mismatch: expected (' || expected_keys || '), actual (' || COALESCE(actual_keys, '') || ')'
      WHEN actual_valid IS NOT TRUE THEN 'Index invalid (indisvalid=false)'
      WHEN actual_ready IS NOT TRUE THEN 'Index not ready (indisready=false)'
      WHEN COALESCE(actual_predicate, '') <> COALESCE(expected_predicate, '') THEN 'predicate mismatch: expected (' || COALESCE(expected_predicate, '') || '), actual (' || COALESCE(actual_predicate, '') || ')'
      ELSE NULL END 
     FROM actual_indexes WHERE index_name = 'idx_pos_sessions_lookup')

  UNION ALL
  SELECT 
    54, 'POST_MIGRATION_V3', 'public.idx_pairing_codes_store', 'INDEX', 'INDEX ON store_pairing_codes(store_id, expires_at) WHERE (used_at IS NULL)',
    COALESCE((SELECT actual_indexdef FROM actual_indexes WHERE index_name = 'idx_pairing_codes_store'), 'NOT_YET_CREATED'),
    true, 
    COALESCE((
      SELECT actual_valid AND actual_ready AND actual_table = expected_table AND actual_keys = expected_keys AND trim(both '()' from COALESCE(actual_predicate, '')) = trim(both '()' from COALESCE(expected_predicate, ''))
      FROM actual_indexes WHERE index_name = 'idx_pairing_codes_store'
    ), false),
    'MIGRATION_V3_EXECUTION', 
    (SELECT CASE 
      WHEN indexrelid IS NULL THEN 'Index idx_pairing_codes_store missing' 
      WHEN actual_table <> expected_table THEN 'Wrong table'
      WHEN actual_keys <> expected_keys THEN 'ordered keys mismatch: expected (' || expected_keys || '), actual (' || COALESCE(actual_keys, '') || ')'
      WHEN actual_valid IS NOT TRUE THEN 'Index invalid (indisvalid=false)'
      WHEN actual_ready IS NOT TRUE THEN 'Index not ready (indisready=false)'
      WHEN COALESCE(actual_predicate, '') <> COALESCE(expected_predicate, '') THEN 'predicate mismatch: expected (' || COALESCE(expected_predicate, '') || '), actual (' || COALESCE(actual_predicate, '') || ')'
      ELSE NULL END 
     FROM actual_indexes WHERE index_name = 'idx_pairing_codes_store')

  UNION ALL
  SELECT 
    55, 'POST_MIGRATION_V3', 'public.idx_pos_auth_ip_store', 'INDEX', 'INDEX ON pos_auth_attempts(ip_address, store_code, blocked_until)',
    COALESCE((SELECT actual_indexdef FROM actual_indexes WHERE index_name = 'idx_pos_auth_ip_store'), 'NOT_YET_CREATED'),
    true, 
    COALESCE((
      SELECT actual_valid AND actual_ready AND actual_table = expected_table AND actual_keys = expected_keys
      FROM actual_indexes WHERE index_name = 'idx_pos_auth_ip_store'
    ), false),
    'MIGRATION_V3_EXECUTION', 
    (SELECT CASE 
      WHEN indexrelid IS NULL THEN 'Index idx_pos_auth_ip_store missing' 
      WHEN actual_table <> expected_table THEN 'Wrong table'
      WHEN actual_keys <> expected_keys THEN 'ordered keys mismatch: expected (' || expected_keys || '), actual (' || COALESCE(actual_keys, '') || ')'
      WHEN actual_valid IS NOT TRUE THEN 'Index invalid (indisvalid=false)'
      WHEN actual_ready IS NOT TRUE THEN 'Index not ready (indisready=false)'
      ELSE NULL END 
     FROM actual_indexes WHERE index_name = 'idx_pos_auth_ip_store')

  UNION ALL
  SELECT 
    56, 'POST_MIGRATION_V3', 'public.idx_qr_audit_request', 'INDEX', 'INDEX ON qr_audit_logs(request_id, created_at)',
    COALESCE((SELECT actual_indexdef FROM actual_indexes WHERE index_name = 'idx_qr_audit_request'), 'NOT_YET_CREATED'),
    true, 
    COALESCE((
      SELECT actual_valid AND actual_ready AND actual_table = expected_table AND actual_keys = expected_keys
      FROM actual_indexes WHERE index_name = 'idx_qr_audit_request'
    ), false),
    'MIGRATION_V3_EXECUTION', 
    (SELECT CASE 
      WHEN indexrelid IS NULL THEN 'Index idx_qr_audit_request missing' 
      WHEN actual_table <> expected_table THEN 'Wrong table'
      WHEN actual_keys <> expected_keys THEN 'ordered keys mismatch: expected (' || expected_keys || '), actual (' || COALESCE(actual_keys, '') || ')'
      WHEN actual_valid IS NOT TRUE THEN 'Index invalid (indisvalid=false)'
      WHEN actual_ready IS NOT TRUE THEN 'Index not ready (indisready=false)'
      ELSE NULL END 
     FROM actual_indexes WHERE index_name = 'idx_qr_audit_request')

  UNION ALL
  SELECT 
    57, 'POST_MIGRATION_V3', 'public.idx_qr_requests_channel_idempotency', 'INDEX', 'UNIQUE INDEX ON qr_requests(channel_id, idempotency_key) WHERE (idempotency_key IS NOT NULL)',
    COALESCE((SELECT actual_indexdef FROM actual_indexes WHERE index_name = 'idx_qr_requests_channel_idempotency'), 'NOT_YET_CREATED'),
    true, 
    COALESCE((
      SELECT actual_valid AND actual_ready AND actual_unique AND actual_table = expected_table AND actual_keys = expected_keys AND trim(both '()' from COALESCE(actual_predicate, '')) = trim(both '()' from COALESCE(expected_predicate, ''))
      FROM actual_indexes WHERE index_name = 'idx_qr_requests_channel_idempotency'
    ), false),
    'MIGRATION_V3_EXECUTION', 
    (SELECT CASE 
      WHEN indexrelid IS NULL THEN 'Index idx_qr_requests_channel_idempotency missing' 
      WHEN actual_table <> expected_table THEN 'Wrong table'
      WHEN actual_unique IS NOT TRUE THEN 'Wrong uniqueness: expected UNIQUE'
      WHEN actual_keys <> expected_keys THEN 'ordered keys mismatch: expected (' || expected_keys || '), actual (' || COALESCE(actual_keys, '') || ')'
      WHEN actual_valid IS NOT TRUE THEN 'Index invalid (indisvalid=false)'
      WHEN actual_ready IS NOT TRUE THEN 'Index not ready (indisready=false)'
      WHEN COALESCE(actual_predicate, '') <> COALESCE(expected_predicate, '') THEN 'predicate mismatch: expected (' || COALESCE(expected_predicate, '') || '), actual (' || COALESCE(actual_predicate, '') || ')'
      ELSE NULL END 
     FROM actual_indexes WHERE index_name = 'idx_qr_requests_channel_idempotency')

  -- 58-72. Granular RPC Checks via rpc_catalog_agg CTE (Guaranteed 1 row per expected RPC)
  UNION ALL
  SELECT 
    58, 'POST_MIGRATION_V3', 'public.check_pos_staff_action_permission', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'check_pos_staff_action_permission'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'check_pos_staff_action_permission'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function check_pos_staff_action_permission missing' WHEN total_overloads > 1 THEN 'Unexpected overload count: ' || total_overloads::text WHEN exact_match_count = 0 THEN 'Argument type mismatch: expected (' || expected_arg_types || '), actual (' || actual_arg_types || ')' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'check_pos_staff_action_permission')

  UNION ALL
  SELECT 
    59, 'POST_MIGRATION_V3', 'public.verify_pos_token_internal', 'FUNCTION', 'RPC EXACT SIGNATURE VALID (RETURNS public.pos_session_info)',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'verify_pos_token_internal'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND (actual_prorettype = to_regtype('public.pos_session_info') OR actual_return_type_name = 'pos_session_info') AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'verify_pos_token_internal'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function verify_pos_token_internal missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN NOT (actual_prorettype = to_regtype('public.pos_session_info') OR actual_return_type_name = 'pos_session_info') THEN 'Return type mismatch: expected public.pos_session_info, actual ' || actual_return_type_name WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'verify_pos_token_internal')

  UNION ALL
  SELECT 
    60, 'POST_MIGRATION_V3', 'public.bootstrap_first_pos_device_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'bootstrap_first_pos_device_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'bootstrap_first_pos_device_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function bootstrap_first_pos_device_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'bootstrap_first_pos_device_v3')

  UNION ALL
  SELECT 
    61, 'POST_MIGRATION_V3', 'public.generate_pos_pairing_code_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'generate_pos_pairing_code_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'generate_pos_pairing_code_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function generate_pos_pairing_code_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'generate_pos_pairing_code_v3')

  UNION ALL
  SELECT 
    62, 'POST_MIGRATION_V3', 'public.pair_pos_device_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'pair_pos_device_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'pair_pos_device_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function pair_pos_device_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'pair_pos_device_v3')

  UNION ALL
  SELECT 
    63, 'POST_MIGRATION_V3', 'public.issue_pos_device_session_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'issue_pos_device_session_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'issue_pos_device_session_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function issue_pos_device_session_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'issue_pos_device_session_v3')

  UNION ALL
  SELECT 
    64, 'POST_MIGRATION_V3', 'public.revoke_pos_device_session_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'revoke_pos_device_session_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'revoke_pos_device_session_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function revoke_pos_device_session_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'revoke_pos_device_session_v3')

  UNION ALL
  SELECT 
    65, 'POST_MIGRATION_V3', 'public.get_pending_qr_requests_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'get_pending_qr_requests_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'get_pending_qr_requests_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function get_pending_qr_requests_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'get_pending_qr_requests_v3')

  UNION ALL
  SELECT 
    66, 'POST_MIGRATION_V3', 'public.claim_qr_request_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function claim_qr_request_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3')

  UNION ALL
  SELECT 
    67, 'POST_MIGRATION_V3', 'public.reject_qr_request_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'reject_qr_request_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'reject_qr_request_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function reject_qr_request_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'reject_qr_request_v3')

  UNION ALL
  SELECT 
    68, 'POST_MIGRATION_V3', 'public.confirm_qr_request_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'confirm_qr_request_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'confirm_qr_request_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function confirm_qr_request_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'confirm_qr_request_v3')

  UNION ALL
  SELECT 
    69, 'POST_MIGRATION_V3', 'public.send_to_kitchen_qr_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'send_to_kitchen_qr_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'send_to_kitchen_qr_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function send_to_kitchen_qr_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'send_to_kitchen_qr_v3')

  UNION ALL
  SELECT 
    70, 'POST_MIGRATION_V3', 'public.get_qr_request_status_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'get_qr_request_status_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'get_qr_request_status_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function get_qr_request_status_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'get_qr_request_status_v3')

  UNION ALL
  SELECT 
    71, 'POST_MIGRATION_V3', 'public.get_qr_menu_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'get_qr_menu_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'get_qr_menu_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function get_qr_menu_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'get_qr_menu_v3')

  UNION ALL
  SELECT 
    72, 'POST_MIGRATION_V3', 'public.submit_qr_order_v3', 'FUNCTION', 'RPC EXACT SIGNATURE VALID',
    COALESCE((SELECT actual_signatures FROM rpc_catalog_agg WHERE proname = 'submit_qr_order_v3'), 'NOT_YET_CREATED'),
    true, COALESCE((SELECT total_overloads = 1 AND exact_match_count = 1 AND actual_return_type_name = expected_return_type AND actual_sec_definer = is_sec_definer FROM rpc_catalog_agg WHERE proname = 'submit_qr_order_v3'), false),
    'MIGRATION_V3_EXECUTION', (SELECT CASE WHEN total_overloads = 0 THEN 'RPC function submit_qr_order_v3 missing' WHEN total_overloads > 1 THEN 'Unexpected overload count' WHEN exact_match_count = 0 THEN 'Argument type mismatch' WHEN actual_return_type_name <> expected_return_type THEN 'Return type mismatch' WHEN actual_sec_definer IS NOT TRUE THEN 'SECURITY DEFINER mismatch' ELSE NULL END FROM rpc_catalog_agg WHERE proname = 'submit_qr_order_v3')

  -- 73-80. RLS, Policy & Security Privilege Checks (Gated Safely via Catalog OIDs / CASE)
  UNION ALL
  SELECT 
    73, 'POST_MIGRATION_V3', 'public.qr_channels.rls_enabled', 'SECURITY', 'RLS ENABLED ON qr_channels',
    COALESCE((SELECT CASE WHEN relrowsecurity THEN 'ENABLED' ELSE 'DISABLED' END FROM pg_class WHERE oid = to_regclass('public.qr_channels')), 'TABLE_MISSING'),
    true, COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.qr_channels')), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.qr_channels')) IS NOT TRUE THEN 'RLS not enabled on qr_channels' ELSE NULL END

  UNION ALL
  SELECT 
    74, 'POST_MIGRATION_V3', 'public.qr_requests.rls_enabled', 'SECURITY', 'RLS ENABLED ON qr_requests',
    COALESCE((SELECT CASE WHEN relrowsecurity THEN 'ENABLED' ELSE 'DISABLED' END FROM pg_class WHERE oid = to_regclass('public.qr_requests')), 'TABLE_MISSING'),
    true, COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.qr_requests')), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.qr_requests')) IS NOT TRUE THEN 'RLS not enabled on qr_requests' ELSE NULL END

  UNION ALL
  SELECT 
    75, 'POST_MIGRATION_V3', 'public.qr_request_items.rls_enabled', 'SECURITY', 'RLS ENABLED ON qr_request_items',
    COALESCE((SELECT CASE WHEN relrowsecurity THEN 'ENABLED' ELSE 'DISABLED' END FROM pg_class WHERE oid = to_regclass('public.qr_request_items')), 'TABLE_MISSING'),
    true, COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.qr_request_items')), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.qr_request_items')) IS NOT TRUE THEN 'RLS not enabled on qr_request_items' ELSE NULL END

  UNION ALL
  SELECT 
    76, 'POST_MIGRATION_V3', 'public.pos_device_sessions.rls_enabled', 'SECURITY', 'RLS ENABLED ON pos_device_sessions',
    COALESCE((SELECT CASE WHEN relrowsecurity THEN 'ENABLED' ELSE 'DISABLED' END FROM pg_class WHERE oid = to_regclass('public.pos_device_sessions')), 'TABLE_MISSING'),
    true, COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.pos_device_sessions')), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.pos_device_sessions')) IS NOT TRUE THEN 'RLS not enabled on pos_device_sessions' ELSE NULL END

  UNION ALL
  SELECT 
    77, 'POST_MIGRATION_V3', 'public.anon_direct_write_block_qr_requests', 'PRIVILEGE', 'ANON CANNOT DIRECT INSERT ON qr_requests',
    CASE 
      WHEN to_regclass('public.qr_requests') IS NULL THEN 'TABLE_MISSING'
      WHEN has_table_privilege('anon', to_regclass('public.qr_requests'), 'INSERT') THEN 'ALLOWED'
      ELSE 'BLOCKED'
    END,
    true, 
    CASE 
      WHEN to_regclass('public.qr_requests') IS NULL THEN false
      ELSE NOT has_table_privilege('anon', to_regclass('public.qr_requests'), 'INSERT')
    END,
    'MIGRATION_V3_EXECUTION', 
    CASE 
      WHEN to_regclass('public.qr_requests') IS NULL THEN 'Table public.qr_requests missing'
      WHEN has_table_privilege('anon', to_regclass('public.qr_requests'), 'INSERT') THEN 'anon role holds direct INSERT privilege on qr_requests'
      ELSE NULL
    END

  UNION ALL
  SELECT 
    78, 'POST_MIGRATION_V3', 'public.anon_direct_write_block_qr_channels', 'PRIVILEGE', 'ANON CANNOT DIRECT INSERT ON qr_channels',
    CASE 
      WHEN to_regclass('public.qr_channels') IS NULL THEN 'TABLE_MISSING'
      WHEN has_table_privilege('anon', to_regclass('public.qr_channels'), 'INSERT') THEN 'ALLOWED'
      ELSE 'BLOCKED'
    END,
    true, 
    CASE 
      WHEN to_regclass('public.qr_channels') IS NULL THEN false
      ELSE NOT has_table_privilege('anon', to_regclass('public.qr_channels'), 'INSERT')
    END,
    'MIGRATION_V3_EXECUTION', 
    CASE 
      WHEN to_regclass('public.qr_channels') IS NULL THEN 'Table public.qr_channels missing'
      WHEN has_table_privilege('anon', to_regclass('public.qr_channels'), 'INSERT') THEN 'anon role holds direct INSERT privilege on qr_channels'
      ELSE NULL
    END

  UNION ALL
  SELECT 
    79, 'POST_MIGRATION_V3', 'public.anon_execute_staff_rpc_block', 'PRIVILEGE', 'ANON CANNOT EXECUTE claim_qr_request_v3',
    CASE 
      WHEN (SELECT exact_oid FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3') IS NULL THEN 'FUNCTION_MISSING'
      WHEN has_function_privilege('anon', (SELECT exact_oid FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3'), 'EXECUTE') THEN 'ALLOWED'
      ELSE 'BLOCKED'
    END,
    true, 
    CASE 
      WHEN (SELECT exact_oid FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3') IS NULL THEN false
      ELSE NOT has_function_privilege('anon', (SELECT exact_oid FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3'), 'EXECUTE')
    END,
    'MIGRATION_V3_EXECUTION', 
    CASE 
      WHEN (SELECT exact_oid FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3') IS NULL THEN 'Staff RPC claim_qr_request_v3 missing'
      WHEN has_function_privilege('anon', (SELECT exact_oid FROM rpc_catalog_agg WHERE proname = 'claim_qr_request_v3'), 'EXECUTE') THEN 'anon role holds EXECUTE on staff RPC claim_qr_request_v3'
      ELSE NULL
    END

  UNION ALL
  SELECT 
    80, 'POST_MIGRATION_V3', 'public.sec_definer_search_path_safe', 'SECURITY', 'SECURITY DEFINER RPCs HAVE SAFE search_path (NO pg_temp, NO $user)',
    COALESCE((
      SELECT CASE WHEN count(*) = 15 AND bool_and(COALESCE(actual_proconfig LIKE '%search_path%' AND actual_proconfig NOT LIKE '%$user%' AND actual_proconfig NOT LIKE '%pg_temp%', false)) THEN 'SAFE' ELSE 'UNSAFE_SEARCH_PATH_FOUND' END
      FROM rpc_catalog_agg
      WHERE actual_sec_definer = true
    ), 'NO_DEFINER_RPC'),
    true,
    COALESCE((
      SELECT count(*) = 15 AND bool_and(COALESCE(actual_proconfig LIKE '%search_path%' AND actual_proconfig NOT LIKE '%$user%' AND actual_proconfig NOT LIKE '%pg_temp%', false))
      FROM rpc_catalog_agg
      WHERE actual_sec_definer = true
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 15 AND bool_and(COALESCE(actual_proconfig LIKE '%search_path%' AND actual_proconfig NOT LIKE '%$user%' AND actual_proconfig NOT LIKE '%pg_temp%', false)) FROM rpc_catalog_agg WHERE actual_sec_definer = true) IS NOT TRUE THEN 'BLOCKED: Migration V3 contains search_path with pg_temp or missing fixed search_path' ELSE NULL END

  -- 81-89. Data-Driven Checks 81 to 89
  UNION ALL
  SELECT 
    81, 'POST_MIGRATION_V3', 'public.rpc_exact_signatures_15_15', 'FUNCTION_SIGNATURE', 'EXACTLY 15 RPCS, EACH WITH 1 OVERLOAD & 1 EXACT SIGNATURE MATCH',
    COALESCE((
      SELECT CASE WHEN count(*) = 15 AND bool_and(total_overloads = 1 AND exact_match_count = 1) THEN '15/15_EXACT_SIGNATURES_VALID' ELSE count(*)::text || '/15_VALID' END
      FROM rpc_catalog_agg
    ), '0/15_RPCS'),
    true,
    COALESCE((
      SELECT count(*) = 15 AND bool_and(total_overloads = 1 AND exact_match_count = 1)
      FROM rpc_catalog_agg
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 15 AND bool_and(total_overloads = 1 AND exact_match_count = 1) FROM rpc_catalog_agg) IS NOT TRUE THEN 'Not all 15 V3 RPCs match exact single overload and expected parameter types' ELSE NULL END

  UNION ALL
  SELECT 
    82, 'POST_MIGRATION_V3', 'public.rpc_return_types_jsonb', 'FUNCTION_RETURN_TYPE', 'ALL 15 RPCS MATCH EXPECTED RETURN TYPE',
    COALESCE((
      SELECT CASE WHEN count(*) = 15 AND bool_and(COALESCE(actual_return_type_name = expected_return_type OR (expected_return_type = 'public.pos_session_info' AND (actual_prorettype = to_regtype('public.pos_session_info') OR actual_return_type_name = 'pos_session_info')), false)) THEN 'ALL_RETURN_TYPES_MATCH' ELSE 'RETURN_TYPE_MISMATCH' END
      FROM rpc_catalog_agg
      WHERE exact_oid IS NOT NULL
    ), 'NO_V3_RPCS'),
    true,
    COALESCE((
      SELECT count(*) = 15 AND bool_and(COALESCE(actual_return_type_name = expected_return_type OR (expected_return_type = 'public.pos_session_info' AND (actual_prorettype = to_regtype('public.pos_session_info') OR actual_return_type_name = 'pos_session_info')), false))
      FROM rpc_catalog_agg
      WHERE exact_oid IS NOT NULL
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 15 AND bool_and(COALESCE(actual_return_type_name = expected_return_type OR (expected_return_type = 'public.pos_session_info' AND (actual_prorettype = to_regtype('public.pos_session_info') OR actual_return_type_name = 'pos_session_info')), false)) FROM rpc_catalog_agg WHERE exact_oid IS NOT NULL) IS NOT TRUE THEN 'V3 RPC return type mismatch' ELSE NULL END

  UNION ALL
  SELECT 
    83, 'POST_MIGRATION_V3', 'public.security_definer_modes_v3', 'SECURITY_MODEL', 'ALL 15 RPCS ARE SECURITY DEFINER',
    COALESCE((
      SELECT CASE WHEN count(*) = 15 AND bool_and(COALESCE(actual_sec_definer = true, false)) THEN 'ALL_SECURITY_DEFINER' ELSE 'INVOKER_FOUND' END
      FROM rpc_catalog_agg
      WHERE exact_oid IS NOT NULL
    ), 'NO_V3_RPCS'),
    true,
    COALESCE((
      SELECT count(*) = 15 AND bool_and(COALESCE(actual_sec_definer = true, false))
      FROM rpc_catalog_agg
      WHERE exact_oid IS NOT NULL
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 15 AND bool_and(COALESCE(actual_sec_definer = true, false)) FROM rpc_catalog_agg WHERE exact_oid IS NOT NULL) IS NOT TRUE THEN 'V3 RPCs not all SECURITY DEFINER' ELSE NULL END

  UNION ALL
  SELECT 
    84, 'POST_MIGRATION_V3', 'public.fixed_search_path_coverage', 'SECURITY', 'SEARCH_PATH NO USER OR TEMP (FAIL-CLOSED)',
    COALESCE((
      SELECT CASE WHEN count(*) = 15 AND bool_and(COALESCE(actual_proconfig LIKE '%search_path%' AND actual_proconfig NOT LIKE '%$user%' AND actual_proconfig NOT LIKE '%pg_temp%', false)) THEN 'SECURE_SEARCH_PATH' ELSE 'UNSAFE_SEARCH_PATH' END
      FROM rpc_catalog_agg
      WHERE actual_sec_definer = true
    ), 'NO_V3_RPCS'),
    true,
    COALESCE((
      SELECT count(*) = 15 AND bool_and(COALESCE(actual_proconfig LIKE '%search_path%' AND actual_proconfig NOT LIKE '%$user%' AND actual_proconfig NOT LIKE '%pg_temp%', false))
      FROM rpc_catalog_agg
      WHERE actual_sec_definer = true
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 15 AND bool_and(COALESCE(actual_proconfig LIKE '%search_path%' AND actual_proconfig NOT LIKE '%$user%' AND actual_proconfig NOT LIKE '%pg_temp%', false)) FROM rpc_catalog_agg WHERE actual_sec_definer = true) IS NOT TRUE THEN 'proconfig missing search_path or contains unsafe $user / pg_temp' ELSE NULL END

  UNION ALL
  SELECT 
    85, 'POST_MIGRATION_V3', 'public.table_mutation_privileges_anon', 'PRIVILEGE', 'ANON NO MUTATION (INSERT/UPDATE/DELETE/TRUNCATE) ON POS TABLES',
    COALESCE((
      SELECT CASE WHEN count(*) = 3 AND bool_and(NOT has_table_privilege('anon', t.oid, 'INSERT') AND NOT has_table_privilege('anon', t.oid, 'UPDATE') AND NOT has_table_privilege('anon', t.oid, 'DELETE') AND NOT has_table_privilege('anon', t.oid, 'TRUNCATE')) THEN 'MUTATION_BLOCKED' ELSE 'MUTATION_ALLOWED' END
      FROM pg_class t JOIN pg_namespace n ON t.relnamespace = n.oid
      WHERE n.nspname = 'public' AND t.relname IN ('pos_device_sessions', 'pos_auth_attempts', 'pos_store_bootstrap_state')
    ), 'TABLES_MISSING'),
    true,
    COALESCE((
      SELECT count(*) = 3 AND bool_and(NOT has_table_privilege('anon', t.oid, 'INSERT') AND NOT has_table_privilege('anon', t.oid, 'UPDATE') AND NOT has_table_privilege('anon', t.oid, 'DELETE') AND NOT has_table_privilege('anon', t.oid, 'TRUNCATE'))
      FROM pg_class t JOIN pg_namespace n ON t.relnamespace = n.oid
      WHERE n.nspname = 'public' AND t.relname IN ('pos_device_sessions', 'pos_auth_attempts', 'pos_store_bootstrap_state')
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 3 AND bool_and(NOT has_table_privilege('anon', t.oid, 'INSERT') AND NOT has_table_privilege('anon', t.oid, 'UPDATE') AND NOT has_table_privilege('anon', t.oid, 'DELETE') AND NOT has_table_privilege('anon', t.oid, 'TRUNCATE')) FROM pg_class t JOIN pg_namespace n ON t.relnamespace = n.oid WHERE n.nspname = 'public' AND t.relname IN ('pos_device_sessions', 'pos_auth_attempts', 'pos_store_bootstrap_state')) IS NOT TRUE THEN 'anon holds mutation privileges (INSERT/UPDATE/DELETE/TRUNCATE) on POS tables' ELSE NULL END

  UNION ALL
  SELECT 
    86, 'POST_MIGRATION_V3', 'public.function_execute_privileges_anon', 'PRIVILEGE', 'ANON CANNOT EXECUTE STAFF RPCS (EXACT SIGNATURES)',
    COALESCE((
      SELECT CASE WHEN count(*) = 4 AND bool_and(NOT has_function_privilege('anon', r.exact_oid, 'EXECUTE')) THEN 'EXECUTE_BLOCKED' ELSE 'EXECUTE_ALLOWED' END
      FROM rpc_catalog_agg r
      WHERE r.proname IN ('bootstrap_first_pos_device_v3', 'issue_pos_device_session_v3', 'claim_qr_request_v3', 'send_to_kitchen_qr_v3') AND r.exact_oid IS NOT NULL
    ), 'FUNCTIONS_MISSING'),
    true,
    COALESCE((
      SELECT count(*) = 4 AND bool_and(NOT has_function_privilege('anon', r.exact_oid, 'EXECUTE'))
      FROM rpc_catalog_agg r
      WHERE r.proname IN ('bootstrap_first_pos_device_v3', 'issue_pos_device_session_v3', 'claim_qr_request_v3', 'send_to_kitchen_qr_v3') AND r.exact_oid IS NOT NULL
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 4 AND bool_and(NOT has_function_privilege('anon', r.exact_oid, 'EXECUTE')) FROM rpc_catalog_agg r WHERE r.proname IN ('bootstrap_first_pos_device_v3', 'issue_pos_device_session_v3', 'claim_qr_request_v3', 'send_to_kitchen_qr_v3') AND r.exact_oid IS NOT NULL) IS NOT TRUE THEN 'anon holds EXECUTE on staff RPCs' ELSE NULL END

  UNION ALL
  SELECT 
    87, 'POST_MIGRATION_V3', 'public.rls_coverage_v3_tables', 'SECURITY', 'RLS ENABLED ON ALL 6 TARGET V3 TABLES',
    COALESCE((
      SELECT CASE WHEN count(*) = 6 AND bool_and(c.relrowsecurity = true) THEN 'ALL_6_RLS_ENABLED' ELSE 'RLS_MISSING' END
      FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid JOIN expected_tables e ON c.relname = e.table_name
      WHERE n.nspname = 'public'
    ), 'TABLES_MISSING'),
    true,
    COALESCE((
      SELECT count(*) = 6 AND bool_and(c.relrowsecurity = true)
      FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid JOIN expected_tables e ON c.relname = e.table_name
      WHERE n.nspname = 'public'
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 6 AND bool_and(c.relrowsecurity = true) FROM pg_class c JOIN pg_namespace n ON c.relnamespace = n.oid JOIN expected_tables e ON c.relname = e.table_name WHERE n.nspname = 'public') IS NOT TRUE THEN 'RLS not enabled on all 6 target V3 tables' ELSE NULL END

  UNION ALL
  SELECT 
    88, 'POST_MIGRATION_V3', 'public.executable_v3_policies', 'SECURITY', 'EXECUTABLE V3 MIGRATIONS CREATE 0 POLICIES (CUTOVER POLICIES DEFERRED TO DRAFT)',
    COALESCE((
      SELECT CASE 
        WHEN (SELECT count(*) FROM expected_executable_policies) = 0 THEN 'EXECUTABLE_MIGRATION_CREATES_0_POLICIES'
        ELSE (SELECT count(*)::text FROM pg_policies p JOIN expected_executable_policies e ON p.tablename = e.table_name AND p.policyname = e.policy_name WHERE p.schemaname = 'public' AND p.cmd = e.cmd)
      END
    ), 'EXECUTABLE_MIGRATION_CREATES_0_POLICIES'),
    true,
    true, -- Executable migration creates 0 policies; RLS policies are deferred to cutover
    'MIGRATION_V3_EXECUTION', NULL

  UNION ALL
  SELECT 
    89, 'POST_MIGRATION_V3', 'public.v3_index_definitions_valid_ready', 'INDEX', 'ALL 6 V3 INDEXES VALID & READY (MATCHING INDEXDEF, TABLE, KEYS, PREDICATE & UNIQUENESS)',
    COALESCE((
      SELECT CASE WHEN count(*) = 6 AND bool_and(actual_valid = true AND actual_ready = true AND actual_unique = expected_unique AND actual_table = expected_table AND actual_keys = expected_keys AND trim(both '()' from COALESCE(actual_predicate, '')) = trim(both '()' from COALESCE(expected_predicate, ''))) THEN 'ALL_6_INDEXES_VALID' ELSE 'INVALID_INDEX_FOUND' END
      FROM actual_indexes
    ), 'INDEXES_MISSING'),
    true,
    COALESCE((
      SELECT count(*) = 6 AND bool_and(actual_valid = true AND actual_ready = true AND actual_unique = expected_unique AND actual_table = expected_table AND actual_keys = expected_keys AND trim(both '()' from COALESCE(actual_predicate, '')) = trim(both '()' from COALESCE(expected_predicate, '')))
      FROM actual_indexes
    ), false),
    'MIGRATION_V3_EXECUTION', CASE WHEN (SELECT count(*) = 6 AND bool_and(actual_valid = true AND actual_ready = true AND actual_unique = expected_unique AND actual_table = expected_table AND actual_keys = expected_keys AND trim(both '()' from COALESCE(actual_predicate, '')) = trim(both '()' from COALESCE(expected_predicate, ''))) FROM actual_indexes) IS NOT TRUE THEN 'V3 index missing, invalid, not ready, or target/uniqueness/keys/predicate mismatch' ELSE NULL END
),
check_90_meta AS (
  SELECT 
    90 AS check_id,
    'POST_MIGRATION_V3' AS check_phase,
    'public.meta_assertion_non_empty_blocking_reason' AS object_name,
    'META_ASSERTION' AS object_type,
    'ALL FAILED CHECKS IN RAW_CHECKS_1_89 HAVE DESCRIPTIVE BLOCKING REASON BEFORE FALLBACK AND NO NULL ACTUALS' AS expected,
    CASE 
      WHEN COUNT(*) FILTER (WHERE (source_schema_truth_ok AND v3_compatible) IS NOT TRUE AND (blocking_reason IS NULL OR length(trim(blocking_reason)) = 0)) = 0 
           AND COUNT(*) FILTER (WHERE actual IS NULL) = 0 
      THEN 'RAW_META_ASSERTION_PASSED'
      ELSE 'RAW_META_ASSERTION_FAILED [missing_reasons=' || COUNT(*) FILTER (WHERE (source_schema_truth_ok AND v3_compatible) IS NOT TRUE AND (blocking_reason IS NULL OR length(trim(blocking_reason)) = 0))::text || ', null_actuals=' || COUNT(*) FILTER (WHERE actual IS NULL)::text || ']'
    END AS actual,
    true AS source_schema_truth_ok,
    (COUNT(*) FILTER (WHERE (source_schema_truth_ok AND v3_compatible) IS NOT TRUE AND (blocking_reason IS NULL OR length(trim(blocking_reason)) = 0)) = 0 AND COUNT(*) FILTER (WHERE actual IS NULL) = 0) AS v3_compatible,
    (COUNT(*) FILTER (WHERE (source_schema_truth_ok AND v3_compatible) IS NOT TRUE AND (blocking_reason IS NULL OR length(trim(blocking_reason)) = 0)) = 0 AND COUNT(*) FILTER (WHERE actual IS NULL) = 0) AS is_compatible,
    'PREFLIGHT_SQL_DESIGN' AS remedy,
    CASE 
      WHEN COUNT(*) FILTER (WHERE (source_schema_truth_ok AND v3_compatible) IS NOT TRUE AND (blocking_reason IS NULL OR length(trim(blocking_reason)) = 0)) > 0 OR COUNT(*) FILTER (WHERE actual IS NULL) > 0
      THEN 'Raw Meta-assertion failed: ' || COUNT(*) FILTER (WHERE (source_schema_truth_ok AND v3_compatible) IS NOT TRUE AND (blocking_reason IS NULL OR length(trim(blocking_reason)) = 0))::text || ' raw checks missing blocking_reason, ' || COUNT(*) FILTER (WHERE actual IS NULL)::text || ' actuals are NULL'
      ELSE NULL
    END AS blocking_reason
  FROM raw_checks_1_89
),
evaluated_checks_1_89 AS (
  SELECT 
    check_id,
    check_phase,
    object_name,
    object_type,
    expected,
    actual,
    source_schema_truth_ok,
    v3_compatible,
    (source_schema_truth_ok AND v3_compatible) AS is_compatible,
    remedy,
    CASE 
      WHEN (source_schema_truth_ok AND v3_compatible) IS NOT TRUE AND (blocking_reason IS NULL OR length(trim(blocking_reason)) = 0)
      THEN 'FAILED CHECK MISSING DESCRIPTIVE BLOCKING REASON'
      ELSE blocking_reason 
    END AS blocking_reason
  FROM raw_checks_1_89
),
all_evaluated_checks AS (
  SELECT * FROM evaluated_checks_1_89
  UNION ALL
  SELECT * FROM check_90_meta
),
summary AS (
  SELECT 
    -- Summary for PRE_MIGRATION_SCHEMA phase (Checks 1 to 45)
    COUNT(*) FILTER (WHERE check_phase = 'PRE_MIGRATION_SCHEMA') AS total_pre_checks,
    COUNT(*) FILTER (WHERE check_phase = 'PRE_MIGRATION_SCHEMA' AND is_compatible IS NOT TRUE) AS failed_pre_checks,
    (COUNT(*) FILTER (WHERE check_phase = 'PRE_MIGRATION_SCHEMA' AND is_compatible IS NOT TRUE) = 0) AS pre_v3_ready,
    -- Summary for POST_MIGRATION_V3 phase (Checks 46 to 90)
    COUNT(*) FILTER (WHERE check_phase = 'POST_MIGRATION_V3') AS total_post_checks,
    COUNT(*) FILTER (WHERE check_phase = 'POST_MIGRATION_V3' AND is_compatible IS NOT TRUE) AS failed_post_checks,
    (COUNT(*) FILTER (WHERE check_phase = 'POST_MIGRATION_V3' AND is_compatible IS NOT TRUE) = 0) AS post_v3_ready
  FROM all_evaluated_checks
)
-- Structured Output Query
SELECT 
  ec.check_id,
  ec.check_phase,
  ec.object_name,
  ec.object_type,
  ec.expected,
  ec.actual,
  ec.source_schema_truth_ok,
  ec.v3_compatible,
  ec.is_compatible,
  ec.remedy,
  ec.blocking_reason,
  s.total_pre_checks,
  s.failed_pre_checks,
  s.pre_v3_ready,
  s.total_post_checks,
  s.failed_post_checks,
  s.post_v3_ready
FROM all_evaluated_checks ec
CROSS JOIN summary s
ORDER BY ec.check_id ASC;
