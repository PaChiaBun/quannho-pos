#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Autonomous Isolated PostgreSQL Gate Runner for Settlement V5 & Concurrency (Hardened V3)
Features:
1. Strict Safety & Sanitization:
   - Sanitized target hides BOTH username and password (postgresql://***:***@host:port/dbname).
   - Strict Marker Enforcement:
     * Localhost (localhost, 127.0.0.1, ::1, host.docker.internal) REQUIRES IS_ISOLATED_LOCAL_TEST_CLUSTER=YES.
     * Remote host REQUIRES ALLOW_REMOTE_ISOLATED_TEST_DB=YES (Local marker CANNOT authorize remote host).
   - Rejects production keywords (prod, production, quannho-db.lpm.vn).
   - URL replacement uses netloc path replacement to prevent double-encoding and preserve IPv6 brackets and query params.
2. Preflight Verification:
   - Server version check (PostgreSQL >= 14.0).
   - CREATE DATABASE privilege (rolsuper / rolcreatedb).
   - pgcrypto extension availability.
   - Fail-closed role check: Fails if anon/authenticated missing unless AUTO_PROVISION_LOCAL_TEST_ROLES=YES on localhost.
   - Tracks provisioned roles and cleans them up in finally block.
3. Schema Contract Assertions:
   - Validates column existence AND data_type / udt_name (uuid, numeric, timestamptz, int8, bool, text).
4. Database A Execution (Schema WITHOUT public.coupons):
   - Creates isolated database: test_settle_v5_no_coupons_<uuid>
   - Applies canonical baseline without coupons
   - Validates schema contract
   - Applies migration 20260902_atomic_settlement_v5.sql
   - Executes settle_v5_concurrency_test.sql (COUPON_SCHEMA_UNAVAILABLE verified)
   - Executes 50-worker concurrency test harness
5. Future Coupon Migration Idempotency & Detailed FK Verification (on Database A):
   - Creates public.coupons table
   - Executes dynamic DO attach block Run 1 and Run 2
   - Queries pg_constraint for:
     * Exactly 1 constraint fk_pos_coupon_redemptions_coupons
     * conrelid = public.pos_coupon_redemptions
     * confrelid = public.coupons
     * confdeltype = 'n' (ON DELETE SET NULL)
   - Inserts valid coupon and calls complete_pos_sale_v1 via SELECT set_config(..., false)
   - Asserts exactly 1 pos_coupon_redemptions record
   - Executes replay and asserts 0 new rows
6. Database B Execution (Schema WITH public.coupons):
   - Creates isolated database: test_settle_v5_with_coupons_<uuid>
   - Applies canonical baseline WITH public.coupons
   - Validates schema contract
   - Applies migration 20260902_atomic_settlement_v5.sql (Conditional FK automatically attached)
   - Executes settle_v5_concurrency_test.sql (Full coupon test suite)
   - Executes 50-worker concurrency test harness
7. Guaranteed Cleanup in finally block:
   - Terminates connections & drops test databases.
   - Cleans up ONLY runner-provisioned test roles.
   - Fails gate if cleanup fails.
"""

import os
import sys
import json
import uuid
import time
import urllib.parse
import unittest
import threading
from pathlib import Path

# Runner được gọi trực tiếp bằng đường dẫn file từ repo root. Khi đó Python chỉ
# thêm test/backend vào sys.path, nên import `test.backend...` sẽ thất bại đúng
# lúc bắt đầu concurrency gate. Gắn repo root theo vị trí file, không phụ thuộc
# current working directory hay PYTHONPATH của máy chạy.
REPO_ROOT = Path(__file__).resolve().parents[2]
if str(REPO_ROOT) not in sys.path:
    sys.path.insert(0, str(REPO_ROOT))

BASE_CANONICAL_SCHEMA_SQL = """
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS public.stores (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone text,
  display_name text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.store_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.user_accounts(id) ON DELETE CASCADE,
  role text NOT NULL DEFAULT 'staff',
  is_owner boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.staff_members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  role text NOT NULL,
  phone text,
  is_active boolean NOT NULL DEFAULT true,
  updated_at bigint NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.app_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  key text NOT NULL,
  value text NOT NULL
);

CREATE TABLE IF NOT EXISTS public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  phone text,
  loyalty_pts integer NOT NULL DEFAULT 0,
  real_balance double precision NOT NULL DEFAULT 0,
  bonus_balance double precision NOT NULL DEFAULT 0,
  bonus_cap_pct integer NOT NULL DEFAULT 15,
  bonus_expires_at timestamptz,
  total_spent numeric NOT NULL DEFAULT 0,
  visit_count integer NOT NULL DEFAULT 0,
  stamp_count integer NOT NULL DEFAULT 0,
  stamp_total integer NOT NULL DEFAULT 0,
  is_deleted boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.balance_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id),
  customer_id uuid NOT NULL REFERENCES public.customers(id),
  order_id uuid,
  type text NOT NULL,
  amount double precision NOT NULL DEFAULT 0,
  balance_after double precision NOT NULL DEFAULT 0,
  bonus_after double precision NOT NULL DEFAULT 0,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ban_dining_tables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  label text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  status text NOT NULL DEFAULT 'empty'
);

CREATE TABLE IF NOT EXISTS public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  name text NOT NULL,
  sell_price numeric NOT NULL DEFAULT 0,
  cost_price_latest numeric NOT NULL DEFAULT 0,
  stock_qty numeric NOT NULL DEFAULT 0,
  is_deleted boolean NOT NULL DEFAULT false,
  updated_at bigint NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.ban_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  table_id uuid REFERENCES public.ban_dining_tables(id) ON DELETE SET NULL,
  waiter_id uuid REFERENCES public.store_members(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'open',
  total_amount numeric NOT NULL DEFAULT 0,
  opened_at timestamptz NOT NULL DEFAULT now(),
  closed_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.ban_session_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  product_name text NOT NULL,
  quantity numeric NOT NULL DEFAULT 1,
  unit_price numeric NOT NULL DEFAULT 0,
  subtotal numeric NOT NULL DEFAULT 0,
  modifiers_json text,
  kitchen_status text DEFAULT 'chua_gui'
);

CREATE TABLE IF NOT EXISTS public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  order_number text NOT NULL,
  subtotal numeric NOT NULL DEFAULT 0,
  discount numeric NOT NULL DEFAULT 0,
  tax numeric NOT NULL DEFAULT 0,
  total numeric NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL DEFAULT 'cash',
  status text NOT NULL DEFAULT 'completed',
  source_type text NOT NULL DEFAULT 'ban_manual',
  source_id text,
  staff_id uuid,
  waiter_id uuid,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  loyalty_pts_earned integer NOT NULL DEFAULT 0,
  loyalty_pts_used integer NOT NULL DEFAULT 0,
  receipt_printed boolean NOT NULL DEFAULT false,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  name text NOT NULL,
  product_name text NOT NULL,
  qty numeric NOT NULL DEFAULT 1,
  quantity numeric NOT NULL DEFAULT 1,
  unit_price numeric NOT NULL DEFAULT 0,
  cost_price numeric NOT NULL DEFAULT 0,
  subtotal numeric NOT NULL DEFAULT 0,
  modifiers_json jsonb DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS public.payment_settlements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  idempotency_key text,
  request_fingerprint text,
  subtotal numeric NOT NULL DEFAULT 0,
  discount numeric NOT NULL DEFAULT 0,
  points_discount numeric NOT NULL DEFAULT 0,
  coupon_discount numeric NOT NULL DEFAULT 0,
  surcharge numeric NOT NULL DEFAULT 0,
  total_amount numeric NOT NULL DEFAULT 0,
  payment_method text NOT NULL DEFAULT 'cash',
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  points_used integer NOT NULL DEFAULT 0,
  coupon_code text,
  status text NOT NULL DEFAULT 'completed',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ban_session_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  qr_request_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.ban_session_order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid NOT NULL REFERENCES public.ban_sessions(id) ON DELETE CASCADE,
  session_item_id uuid NOT NULL REFERENCES public.ban_session_items(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  order_item_id uuid NOT NULL REFERENCES public.order_items(id) ON DELETE CASCADE,
  source_type text NOT NULL DEFAULT 'ban_manual',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.finance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  type text NOT NULL DEFAULT 'income',
  amount numeric NOT NULL DEFAULT 0,
  description text,
  reference_id uuid,
  is_auto boolean NOT NULL DEFAULT true,
  fund_type text NOT NULL DEFAULT 'cash',
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.stock_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  delta numeric NOT NULL DEFAULT 0,
  reason text NOT NULL DEFAULT 'sale',
  reference_id uuid,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.loyalty_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  order_id uuid,
  pts_earned numeric NOT NULL DEFAULT 0,
  pts_used numeric NOT NULL DEFAULT 0,
  note text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.qr_coupon_redemptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  session_id uuid REFERENCES public.ban_sessions(id) ON DELETE SET NULL,
  settlement_id uuid REFERENCES public.payment_settlements(id) ON DELETE SET NULL,
  coupon_id uuid,
  coupon_code text,
  discount_amount numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.qr_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  request_id uuid,
  action text NOT NULL,
  actor_user_id uuid,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.verify_staff_qr_membership_v4(
  p_store_id uuid,
  p_require_checkout boolean DEFAULT false
)
RETURNS TABLE (
  member_user_id uuid,
  store_member_id uuid,
  member_role text
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public
AS $$
DECLARE
  v_uid uuid;
  v_member record;
BEGIN
  v_uid := NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: User not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT sm.id, sm.role INTO v_member
  FROM public.store_members sm
  WHERE sm.store_id = p_store_id AND sm.user_id = v_uid
  LIMIT 1;

  IF v_member IS NULL THEN
    RAISE EXCEPTION 'PERMISSION_DENIED: User is not a member of store' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY SELECT v_uid, v_member.id, v_member.role;
END;
$$;
"""

# Exercise the real membership/checkout authorization, not a permissive mock.
_v4_source = (Path(__file__).resolve().parents[2] / 'supabase/migrations/20260827_qr_order_v4.sql').read_text()
_helper_start = _v4_source.index('CREATE OR REPLACE FUNCTION public.verify_staff_qr_membership_v4(')
_helper_end = _v4_source.index('$$;', _helper_start) + 3
BASE_CANONICAL_SCHEMA_SQL = BASE_CANONICAL_SCHEMA_SQL.split('CREATE OR REPLACE FUNCTION public.verify_staff_qr_membership_v4(')[0] + """
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;
""" + _v4_source[_helper_start:_helper_end]

COUPONS_TABLE_SQL = """
CREATE TABLE IF NOT EXISTS public.coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE,
  code text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  start_date timestamptz,
  end_date timestamptz,
  discount_type text NOT NULL,
  value numeric NOT NULL,
  min_order_amount numeric DEFAULT 0,
  max_discount_amount numeric DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
"""

def sanitize_url(raw_url):
    parsed = urllib.parse.urlsplit(raw_url)
    host = parsed.hostname or ""
    if ":" in host and not host.startswith("["):
        host_str = f"[{host}]"
    else:
        host_str = host
    port = f":{parsed.port}" if parsed.port else ""
    dbname = (parsed.path.lstrip("/") or "postgres").lower()
    query = f"?{parsed.query}" if parsed.query else ""
    return f"postgresql://***:***@{host_str}{port}/{dbname}{query}"

def build_db_url(raw_base_url, new_dbname):
    parsed = urllib.parse.urlsplit(raw_base_url)
    new_path = f"/{new_dbname}"
    return urllib.parse.urlunsplit((parsed.scheme, parsed.netloc, new_path, parsed.query, parsed.fragment))

def validate_and_parse_base_url():
    base_url = os.environ.get("LOCAL_TEST_DATABASE_URL") or os.environ.get("STAGING_DATABASE_URL")
    allow_mutation = os.environ.get("SETTLE_V5_ALLOW_STAGING_MUTATION", "").strip().upper()
    is_local_cluster = os.environ.get("IS_ISOLATED_LOCAL_TEST_CLUSTER", "").strip().upper()
    allow_remote_test = os.environ.get("ALLOW_REMOTE_ISOLATED_TEST_DB", "").strip().upper()

    if not base_url or allow_mutation != "YES":
        print("BLOCKED_RUNTIME_GATE: Test Database URL not configured or mutation not allowed.")
        print("Required environment variables:")
        print("  export LOCAL_TEST_DATABASE_URL=\"postgresql://user:pass@host:port/postgres\"")
        print("  export SETTLE_V5_ALLOW_STAGING_MUTATION=YES")
        print("  export IS_ISOLATED_LOCAL_TEST_CLUSTER=YES (for localhost) OR ALLOW_REMOTE_ISOLATED_TEST_DB=YES (for remote)")
        sys.exit(2)

    parsed = urllib.parse.urlsplit(base_url)
    host = (parsed.hostname or "").lower()
    dbname = (parsed.path.lstrip("/") or "postgres").lower()

    # Production safety guard
    if any(k in host or k in dbname for k in ["prod", "production", "quannho-db.lpm.vn"]):
        print(f"FATAL: Target database appears to be PRODUCTION! Aborting.")
        sys.exit(1)

    is_localhost = host in ["localhost", "127.0.0.1", "::1", "host.docker.internal"]
    if is_localhost:
        if is_local_cluster != "YES":
            print("FATAL: Target host is localhost but IS_ISOLATED_LOCAL_TEST_CLUSTER=YES is not set.")
            sys.exit(1)
    else:
        if allow_remote_test != "YES":
            print("FATAL: Target host is REMOTE. Requires ALLOW_REMOTE_ISOLATED_TEST_DB=YES (IS_ISOLATED_LOCAL_TEST_CLUSTER cannot authorize remote host).")
            sys.exit(1)

    sanitized = sanitize_url(base_url)
    print(f"[Phase 1 Isolated Gate] Maintenance Target: {sanitized}")

    return base_url, parsed, is_localhost

def execute_preflight(conn, is_localhost):
    print("\n[Preflight] Checking PostgreSQL server capabilities and roles...")
    created_roles = []
    auto_prov = os.environ.get("AUTO_PROVISION_LOCAL_TEST_ROLES", "").strip().upper() == "YES"

    with conn.cursor() as cur:
        # 1. Version check
        cur.execute("SHOW server_version_num;")
        ver_num = int(cur.fetchone()[0])
        if ver_num < 140000:
            raise RuntimeError(f"PostgreSQL server version too old: {ver_num}. Requires >= 14.0")
        cur.execute("SHOW server_version;")
        print(f"  ✓ PostgreSQL version: {cur.fetchone()[0]}")

        # 2. CREATE DATABASE privilege check
        cur.execute("SELECT rolsuper, rolcreatedb FROM pg_roles WHERE rolname = current_user;")
        row = cur.fetchone()
        if not row or (not row[0] and not row[1]):
            raise RuntimeError("Current role does not have CREATE DATABASE privilege!")
        print("  ✓ CREATE DATABASE privilege confirmed")

        # 3. pgcrypto extension check
        cur.execute("SELECT count(*) FROM pg_available_extensions WHERE name = 'pgcrypto';")
        if cur.fetchone()[0] == 0:
            raise RuntimeError("pgcrypto extension is not available in PostgreSQL cluster!")
        print("  ✓ pgcrypto extension available")

        # 4. Role existence & fail-closed check
        for role in ['anon', 'authenticated']:
            cur.execute(f"SELECT count(*) FROM pg_roles WHERE rolname = '{role}';")
            if cur.fetchone()[0] == 0:
                if is_localhost and auto_prov:
                    cur.execute(f"CREATE ROLE {role} NOLOGIN;")
                    created_roles.append(role)
                    print(f"  ✓ Provisioned test role on local cluster: {role}")
                else:
                    raise RuntimeError(f"Required role '{role}' does not exist on target cluster! (Fail-closed)")
            else:
                print(f"  ✓ Confirmed role exists: {role}")

    return created_roles

def assert_schema_contracts(conn, has_coupons=False):
    print("  [Contract] Asserting schema contracts for columns and data types...")
    type_contracts = {
        'orders': {
            'id': ['uuid'], 'store_id': ['uuid'], 'order_number': ['text', 'varchar'],
            'total_amount': ['numeric'], 'payment_method': ['text', 'varchar'],
            'status': ['text', 'varchar'], 'source_type': ['text', 'varchar'],
            'created_at': ['timestamptz', 'timestamp']
        },
        'order_items': {
            'id': ['uuid'], 'store_id': ['uuid'], 'order_id': ['uuid'], 'product_id': ['uuid'],
            'name': ['text', 'varchar'], 'quantity': ['numeric'], 'unit_price': ['numeric'],
            'cost_price': ['numeric'], 'subtotal': ['numeric'], 'modifiers_json': ['jsonb', 'text']
        },
        'payment_settlements': {
            'id': ['uuid'], 'store_id': ['uuid'], 'session_id': ['uuid'],
            'subtotal': ['numeric'], 'discount': ['numeric'], 'total_amount': ['numeric'],
            'payment_method': ['text', 'varchar'], 'status': ['text', 'varchar']
        },
        'finance_records': {
            'id': ['uuid'], 'store_id': ['uuid'], 'type': ['text', 'varchar'],
            'amount': ['numeric'], 'reference_id': ['uuid'], 'is_auto': ['bool'],
            'fund_type': ['text', 'varchar'], 'recorded_at': ['timestamptz', 'timestamp']
        },
        'stock_movements': {
            'id': ['uuid'], 'store_id': ['uuid'], 'product_id': ['uuid'],
            'delta': ['numeric'], 'reason': ['text', 'varchar'], 'reference_id': ['uuid']
        },
        'loyalty_transactions': {
            'id': ['uuid'], 'store_id': ['uuid'], 'customer_id': ['uuid'],
            'pts_earned': ['numeric', 'int4', 'int8'], 'pts_used': ['numeric', 'int4', 'int8']
        },
        'staff_members': {
            'id': ['uuid'], 'updated_at': ['int8', 'int4']
        },
        'products': {
            'id': ['uuid'], 'sell_price': ['numeric'], 'stock_qty': ['numeric'],
            'is_deleted': ['bool'], 'updated_at': ['int8', 'int4']
        }
    }
    if has_coupons:
        type_contracts['coupons'] = {
            'id': ['uuid'], 'store_id': ['uuid'], 'code': ['text', 'varchar'],
            'is_active': ['bool'], 'value': ['numeric']
        }

    with conn.cursor() as cur:
        for table, col_map in type_contracts.items():
            cur.execute(f"SELECT column_name, udt_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = '{table}';")
            actual = {r[0]: r[1] for r in cur.fetchall()}
            for col, allowed_types in col_map.items():
                if col not in actual:
                    raise RuntimeError(f"Contract failure: Column {table}.{col} does not exist!")
                if actual[col] not in allowed_types:
                    raise RuntimeError(f"Contract failure: Column {table}.{col} has udt_name '{actual[col]}', expected one of {allowed_types}!")
    print("  ✓ Schema contracts and data types validated successfully")

def execute_cleanup(admin_conn, db_name_a, db_name_b, created_roles):
    cleanup_success = True
    try:
        with admin_conn.cursor() as cur:
            cur.execute(f"""
                SELECT pg_terminate_backend(pid) 
                FROM pg_stat_activity 
                WHERE datname IN ('{db_name_a}', '{db_name_b}') AND pid <> pg_backend_pid();
            """)
            if db_name_a:
                cur.execute(f"DROP DATABASE IF EXISTS {db_name_a};")
            if db_name_b:
                cur.execute(f"DROP DATABASE IF EXISTS {db_name_b};")
            for role in created_roles:
                cur.execute(f"DROP ROLE IF EXISTS {role};")
                print(f"  ✓ Cleaned up provisioned test role: {role}")
        print("✓ Successfully terminated backends, dropped isolated test databases, and cleaned up test roles")
    except Exception as e:
        print(f"FATAL: Cleanup failed: {e}")
        cleanup_success = False
    return cleanup_success

def main():
    base_url, parsed, is_localhost = validate_and_parse_base_url()
    try:
        import psycopg2
        import psycopg2.extras
    except ImportError:
        print("BLOCKED_RUNTIME_GATE: psycopg2 module not available in current python environment.")
        sys.exit(2)

    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
    migration_path = os.path.join(repo_root, "supabase/migrations/20260902_atomic_settlement_v5.sql")
    sql_test_path = os.path.join(repo_root, "supabase/tests/settle_v5_concurrency_test.sql")

    with open(migration_path, "r", encoding="utf-8") as f: migration_sql = f.read()
    with open(sql_test_path, "r", encoding="utf-8") as f: test_sql = f.read()

    run_id = uuid.uuid4().hex[:8]
    db_name_a = f"test_settle_v5_no_coupons_{run_id}"
    db_name_b = f"test_settle_v5_with_coupons_{run_id}"

    db_url_a = build_db_url(base_url, db_name_a)
    db_url_b = build_db_url(base_url, db_name_b)

    admin_conn = psycopg2.connect(base_url)
    admin_conn.autocommit = True

    gate_passed = False
    cleanup_success = False
    created_roles = []

    try:
        # Preflight
        created_roles = execute_preflight(admin_conn, is_localhost)

        print(f"\nCreating isolated test databases: {db_name_a} and {db_name_b}...")
        with admin_conn.cursor() as cur:
            cur.execute(f"CREATE DATABASE {db_name_a};")
            cur.execute(f"CREATE DATABASE {db_name_b};")
        print("✓ Created 2 dedicated isolated PostgreSQL databases")

        # ─────────────────────────────────────────────────────────────────────
        # 1. DATABASE A: Schema WITHOUT public.coupons
        # ─────────────────────────────────────────────────────────────────────
        print(f"\n--- [BASELINE 1] Database A: {db_name_a} (WITHOUT public.coupons) ---")
        conn_a = psycopg2.connect(db_url_a)
        conn_a.autocommit = True
        with conn_a.cursor() as cur:
            cur.execute(BASE_CANONICAL_SCHEMA_SQL)
            print("  ✓ Applied canonical base schema (no coupons)")
            assert_schema_contracts(conn_a, has_coupons=False)
            cur.execute(migration_sql)
            print("  ✓ Applied migration 20260902_atomic_settlement_v5.sql")
            cur.execute(test_sql)
            print("  ✓ Executed SQL integration test suite (COUPON_SCHEMA_UNAVAILABLE verified)")
        conn_a.close()

        # Run Concurrency test on DB A
        os.environ["STAGING_DATABASE_URL"] = db_url_a
        os.environ["SETTLE_V5_ALLOW_STAGING_MUTATION"] = "YES"
        from test.backend.test_settlement_v5_concurrency_real_pg import TestSettlementV5RealPostgresConcurrency
        loader = unittest.TestLoader()
        suite_a = loader.loadTestsFromTestCase(TestSettlementV5RealPostgresConcurrency)
        runner_a = unittest.TextTestRunner(verbosity=2)
        res_a = runner_a.run(suite_a)
        if not res_a.wasSuccessful() or res_a.testsRun == 0:
            raise RuntimeError(f"Concurrency tests failed on Database A: {res_a}")
        print("  ✓ 50-worker concurrency tests passed on Database A (Continuous sequences, Idempotency replay, Snapshot 7 tables)")

        # ─────────────────────────────────────────────────────────────────────
        # 2. FUTURE COUPON MIGRATION TEST (on Database A)
        # ─────────────────────────────────────────────────────────────────────
        print(f"\n--- [FUTURE MIGRATION TEST] Idempotent FK attach when public.coupons created later ---")
        conn_a = psycopg2.connect(db_url_a)
        conn_a.autocommit = True
        with conn_a.cursor() as cur:
            cur.execute(COUPONS_TABLE_SQL)
            print("  ✓ Created public.coupons table on Database A")

            attach_fk_sql = """
            DO $$
            BEGIN
              IF EXISTS (
                SELECT 1 FROM information_schema.tables 
                WHERE table_schema = 'public' AND table_name = 'coupons'
              ) AND NOT EXISTS (
                SELECT 1 FROM information_schema.table_constraints 
                WHERE constraint_schema = 'public' 
                  AND table_name = 'pos_coupon_redemptions' 
                  AND constraint_name = 'fk_pos_coupon_redemptions_coupons'
              ) THEN
                ALTER TABLE public.pos_coupon_redemptions
                ADD CONSTRAINT fk_pos_coupon_redemptions_coupons
                FOREIGN KEY (coupon_id) REFERENCES public.coupons(id) ON DELETE SET NULL;
              END IF;
            END $$;
            """
            # Run 1
            cur.execute(attach_fk_sql)
            print("  ✓ Run 1: Attached fk_pos_coupon_redemptions_coupons")
            # Run 2 (Idempotency)
            cur.execute(attach_fk_sql)
            print("  ✓ Run 2: Idempotent re-run succeeded with zero error")

            # Validate in pg_constraint catalog
            cur.execute("""
                SELECT conname, confdeltype 
                FROM pg_constraint 
                WHERE conrelid = 'public.pos_coupon_redemptions'::regclass 
                  AND confrelid = 'public.coupons'::regclass;
            """)
            fk_rows = cur.fetchall()
            if len(fk_rows) != 1:
                raise RuntimeError(f"Expected exactly 1 FK from pos_coupon_redemptions to coupons, found: {len(fk_rows)}")
            if fk_rows[0][0] != 'fk_pos_coupon_redemptions_coupons':
                raise RuntimeError(f"FK name mismatch: {fk_rows[0][0]}")
            if fk_rows[0][1] != 'n':
                raise RuntimeError(f"Expected ON DELETE SET NULL ('n'), found: {fk_rows[0][1]}")
            print("  ✓ Confirmed in pg_catalog: Exactly 1 FK pointing to public.coupons with ON DELETE SET NULL ('n')")

            # Insert valid coupon and test redemption
            store_id = str(uuid.uuid4())
            user_id = str(uuid.uuid4())
            prod_id = str(uuid.uuid4())
            cur.execute("INSERT INTO public.stores (id, name) VALUES (%s, %s);", (store_id, 'Test Store Future FK'))
            cur.execute("INSERT INTO public.user_accounts (id, phone, display_name) VALUES (%s, %s, %s);", (user_id, '0988999999', 'Cashier Future'))
            cur.execute("INSERT INTO public.store_members (id, store_id, user_id, role) VALUES (%s, %s, %s, %s);", (str(uuid.uuid4()), store_id, user_id, 'cashier'))
            cur.execute("INSERT INTO public.app_settings (id, store_id, key, value) VALUES (%s, %s, %s, %s);", (str(uuid.uuid4()), store_id, 'action_perms_cashier', '["pos.checkout"]'))
            cur.execute("INSERT INTO public.products (id, store_id, name, sell_price, cost_price_latest, stock_qty) VALUES (%s, %s, %s, %s, %s, %s);", (prod_id, store_id, 'Món Ăn', 50000, 20000, 100))
            cur.execute("""
                INSERT INTO public.coupons (id, store_id, code, is_active, start_date, end_date, discount_type, value, min_order_amount, max_discount_amount)
                VALUES (%s, %s, %s, true, now() - interval '1 day', now() + interval '30 days', 'percent', 10, 0, 50000);
            """, (str(uuid.uuid4()), store_id, 'FUTURE10'))

            # Set session-level JWT claim (is_local=false) so subsequent RPC inherits claim under autocommit
            cur.execute("SELECT set_config('request.jwt.claim.sub', %s, false);", (user_id,))
            cur.execute("""
                SELECT public.complete_pos_sale_v1(
                    p_store_id => %s::uuid,
                    p_idempotency_key => %s,
                    p_lines => jsonb_build_array(jsonb_build_object('product_id', %s::uuid, 'quantity', 1)),
                    p_payment_method => 'cash',
                    p_coupon_code => %s,
                    p_discount => 5000
                );
            """, (store_id, 'pos-future-coup-01', prod_id, 'FUTURE10'))
            sale_res = cur.fetchone()[0]
            if not sale_res.get('success'):
                raise RuntimeError(f"Future coupon complete_pos_sale_v1 failed: {sale_res}")

            cur.execute("SELECT count(*) FROM public.pos_coupon_redemptions WHERE store_id = %s AND coupon_code = 'FUTURE10';", (store_id,))
            if cur.fetchone()[0] != 1:
                raise RuntimeError("Expected exactly 1 pos_coupon_redemptions record after sale with coupon!")
            print("  ✓ Executed complete_pos_sale_v1 with newly attached coupon FK -> Exactly 1 redemption recorded")

            # Replay
            cur.execute("""
                SELECT public.complete_pos_sale_v1(
                    p_store_id => %s::uuid,
                    p_idempotency_key => %s,
                    p_lines => jsonb_build_array(jsonb_build_object('product_id', %s::uuid, 'quantity', 1)),
                    p_payment_method => 'cash',
                    p_coupon_code => %s,
                    p_discount => 5000
                );
            """, (store_id, 'pos-future-coup-01', prod_id, 'FUTURE10'))
            replay_res = cur.fetchone()[0]
            if not replay_res.get('success') or not replay_res.get('data', {}).get('is_replay'):
                raise RuntimeError(f"Future coupon replay failed: {replay_res}")

            cur.execute("SELECT count(*) FROM public.pos_coupon_redemptions WHERE store_id = %s AND coupon_code = 'FUTURE10';", (store_id,))
            if cur.fetchone()[0] != 1:
                raise RuntimeError("Coupon redemption count increased during replay!")
            print("  ✓ Replay returned is_replay=true with 0 new redemption records")
        conn_a.close()

        # ─────────────────────────────────────────────────────────────────────
        # 3. DATABASE B: Schema WITH public.coupons
        # ─────────────────────────────────────────────────────────────────────
        print(f"\n--- [BASELINE 2] Database B: {db_name_b} (WITH public.coupons) ---")
        conn_b = psycopg2.connect(db_url_b)
        conn_b.autocommit = True
        with conn_b.cursor() as cur:
            cur.execute(BASE_CANONICAL_SCHEMA_SQL)
            cur.execute(COUPONS_TABLE_SQL)
            print("  ✓ Applied canonical base schema WITH public.coupons")
            assert_schema_contracts(conn_b, has_coupons=True)
            cur.execute(migration_sql)
            print("  ✓ Applied migration 20260902_atomic_settlement_v5.sql (Conditional FK automatically attached)")
            cur.execute(test_sql)
            print("  ✓ Executed SQL integration test suite (Active/Disabled/Expired/Min-Order/Valid coupon verified)")
        conn_b.close()

        # Run Concurrency test on DB B
        os.environ["STAGING_DATABASE_URL"] = db_url_b
        suite_b = loader.loadTestsFromTestCase(TestSettlementV5RealPostgresConcurrency)
        runner_b = unittest.TextTestRunner(verbosity=2)
        res_b = runner_b.run(suite_b)
        if not res_b.wasSuccessful() or res_b.testsRun == 0:
            raise RuntimeError(f"Concurrency tests failed on Database B: {res_b}")
        print("  ✓ 50-worker concurrency tests passed on Database B")

        gate_passed = True

    finally:
        print("\nExecuting guaranteed cleanup...")
        cleanup_success = execute_cleanup(admin_conn, db_name_a, db_name_b, created_roles)
        admin_conn.close()

    if not gate_passed or not cleanup_success:
        print("\n❌ PHASE 1 POSTGRESQL GATE FAILED")
        sys.exit(1)

    print("\n=======================================================")
    print("✅ PHASE 1 POSTGRESQL RUNTIME GATE PASSED COMPLETELY")
    print(f"Executed on 2 Isolated Databases: {db_name_a} & {db_name_b}")
    print("Preflight: PASSED")
    print("Schema Contracts: PASSED")
    print("Baseline 1 (No Coupons): PASSED")
    print("Future FK Idempotency: PASSED")
    print("Baseline 2 (With Coupons): PASSED")
    print("Concurrency 50 Workers: PASSED")
    print("Cleanup: PASSED")
    print("=======================================================\n")

if __name__ == "__main__":
    main()
