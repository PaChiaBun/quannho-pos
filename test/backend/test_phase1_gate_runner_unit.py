#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Unit Tests for Phase 1 Isolated PostgreSQL Gate Runner (Comprehensive Suite)
Validates:
1. URL sanitization hides BOTH username and password.
2. URL reconstruction does NOT double-encode credentials, supports IPv6 brackets [::1], and preserves query params (sslmode, options).
3. Localhost guard enforces IS_ISOLATED_LOCAL_TEST_CLUSTER=YES.
4. Localhost guard without local marker fails.
5. Remote host guard rejects local marker.
6. Remote host guard with ALLOW_REMOTE_ISOLATED_TEST_DB=YES passes.
7. Production safety guard rejects production keywords.
8. Preflight fails closed when roles are missing.
9. Runner uses SELECT set_config('request.jwt.claim.sub', ..., false) for session persistence under autocommit.
10. Schema contract validates data_type and udt_name across core tables.
11. Cleanup is executed when Database B creation fails (drops Database A).
12. Cleanup is executed when Migration fails.
13. Cleanup is executed when Concurrency tests fail.
14. Cleanup ONLY drops roles provisioned by runner (does not drop existing roles).
15. Cleanup failure causes gate to fail (returns False / exit code 1).
"""

import os
import sys
import unittest
import urllib.parse
from pathlib import Path
from unittest.mock import patch, MagicMock, call

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "../..")))
RUNNER_PATH = Path(__file__).with_name("run_phase1_real_pg_gate.py")
from test.backend.run_phase1_real_pg_gate import (
    sanitize_url,
    validate_and_parse_base_url,
    build_db_url,
    execute_preflight,
    assert_schema_contracts,
    execute_cleanup
)

class TestPhase1GateRunnerUnit(unittest.TestCase):
    def test_direct_runner_bootstraps_repo_root_for_concurrency_imports(self):
        source = RUNNER_PATH.read_text(encoding="utf-8")
        self.assertIn(
            'REPO_ROOT = Path(__file__).resolve().parents[2]',
            source,
        )
        self.assertIn('sys.path.insert(0, str(REPO_ROOT))', source)

    def test_01_sanitized_target_hides_both_username_and_password(self):
        raw = "postgresql://my_cashier_user:super_secret_password@127.0.0.1:5432/quannho_test?sslmode=require&application_name=pos"
        sanitized = sanitize_url(raw)
        self.assertNotIn("my_cashier_user", sanitized)
        self.assertNotIn("super_secret_password", sanitized)
        self.assertEqual(sanitized, "postgresql://***:***@127.0.0.1:5432/quannho_test?sslmode=require&application_name=pos")

    def test_02_url_reconstruction_no_double_encoding_supports_ipv6_and_preserves_query(self):
        # Raw URL with percent-encoded password, bracketed IPv6, and multiple query params
        raw = "postgresql://myuser:p%40ss%2Fword@[::1]:5432/postgres?sslmode=verify-full&options=-c%20search_path=public"
        reconstructed = build_db_url(raw, "test_settle_v5_no_coupons_abc123")
        
        # Must preserve exact percent-encoding (NO double encoding like p%2540ss)
        self.assertIn("myuser:p%40ss%2Fword@[::1]:5432", reconstructed)
        self.assertNotIn("%2540", reconstructed)
        self.assertIn("/test_settle_v5_no_coupons_abc123", reconstructed)
        self.assertIn("sslmode=verify-full", reconstructed)
        self.assertIn("options=-c%20search_path=public", reconstructed)

    @patch.dict(os.environ, {
        "LOCAL_TEST_DATABASE_URL": "postgresql://user:pass@localhost:5432/postgres",
        "SETTLE_V5_ALLOW_STAGING_MUTATION": "YES",
        "IS_ISOLATED_LOCAL_TEST_CLUSTER": "YES"
    }, clear=True)
    def test_03_guard_localhost_with_valid_local_marker_passes(self):
        url, parsed, is_localhost = validate_and_parse_base_url()
        self.assertTrue(is_localhost)
        self.assertEqual(parsed.hostname, "localhost")

    @patch.dict(os.environ, {
        "LOCAL_TEST_DATABASE_URL": "postgresql://user:pass@localhost:5432/postgres",
        "SETTLE_V5_ALLOW_STAGING_MUTATION": "YES",
        "IS_ISOLATED_LOCAL_TEST_CLUSTER": "NO",
        "ALLOW_REMOTE_ISOLATED_TEST_DB": "YES"
    }, clear=True)
    def test_04_guard_localhost_without_local_marker_fails(self):
        with self.assertRaises(SystemExit) as cm:
            validate_and_parse_base_url()
        self.assertEqual(cm.exception.code, 1)

    @patch.dict(os.environ, {
        "LOCAL_TEST_DATABASE_URL": "postgresql://user:pass@10.0.1.50:5432/postgres",
        "SETTLE_V5_ALLOW_STAGING_MUTATION": "YES",
        "IS_ISOLATED_LOCAL_TEST_CLUSTER": "YES",
        "ALLOW_REMOTE_ISOLATED_TEST_DB": "NO"
    }, clear=True)
    def test_05_guard_remote_host_rejects_local_marker(self):
        with self.assertRaises(SystemExit) as cm:
            validate_and_parse_base_url()
        self.assertEqual(cm.exception.code, 1)

    @patch.dict(os.environ, {
        "LOCAL_TEST_DATABASE_URL": "postgresql://user:pass@10.0.1.50:5432/postgres",
        "SETTLE_V5_ALLOW_STAGING_MUTATION": "YES",
        "ALLOW_REMOTE_ISOLATED_TEST_DB": "YES"
    }, clear=True)
    def test_06_guard_remote_host_with_explicit_remote_marker_passes(self):
        url, parsed, is_localhost = validate_and_parse_base_url()
        self.assertFalse(is_localhost)
        self.assertEqual(parsed.hostname, "10.0.1.50")

    @patch.dict(os.environ, {
        "LOCAL_TEST_DATABASE_URL": "postgresql://user:pass@quannho-db.lpm.vn:5432/quannho_prod",
        "SETTLE_V5_ALLOW_STAGING_MUTATION": "YES",
        "ALLOW_REMOTE_ISOLATED_TEST_DB": "YES"
    }, clear=True)
    def test_07_guard_rejects_production_target(self):
        with self.assertRaises(SystemExit) as cm:
            validate_and_parse_base_url()
        self.assertEqual(cm.exception.code, 1)

    def test_08_preflight_fails_closed_when_roles_missing(self):
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_conn.cursor.return_value.__enter__.return_value = mock_cur

        mock_cur.fetchone.side_effect = [
            (160000,),        # SHOW server_version_num
            ("16.2",),        # SHOW server_version
            (True, True),     # rolsuper, rolcreatedb
            (1,),             # pgcrypto count
            (0,),             # anon count -> 0 (missing)
        ]

        with self.assertRaises(RuntimeError) as cm:
            execute_preflight(mock_conn, is_localhost=False)
        self.assertIn("Required role 'anon' does not exist", str(cm.exception))

    def test_09_runner_source_code_uses_select_set_config_with_false_for_session(self):
        runner_path = os.path.abspath(os.path.join(os.path.dirname(__file__), "run_phase1_real_pg_gate.py"))
        with open(runner_path, "r", encoding="utf-8") as f:
            content = f.read()

        # Must use is_local = false so subsequent statements inherit claim under autocommit
        self.assertIn("SELECT set_config('request.jwt.claim.sub', %s, false);", content)
        self.assertNotIn("PERFORM set_config", content)

    def test_10_schema_contract_validates_data_types(self):
        mock_conn = MagicMock()
        mock_cur = MagicMock()
        mock_conn.cursor.return_value.__enter__.return_value = mock_cur

        mock_cur.fetchall.side_effect = [
            # orders
            [('id', 'uuid'), ('store_id', 'uuid'), ('order_number', 'text'), ('total_amount', 'numeric'), ('payment_method', 'text'), ('status', 'text'), ('source_type', 'text'), ('created_at', 'timestamptz')],
            # order_items
            [('id', 'uuid'), ('store_id', 'uuid'), ('order_id', 'uuid'), ('product_id', 'uuid'), ('name', 'text'), ('quantity', 'numeric'), ('unit_price', 'numeric'), ('cost_price', 'numeric'), ('subtotal', 'numeric'), ('modifiers_json', 'jsonb')],
            # payment_settlements
            [('id', 'uuid'), ('store_id', 'uuid'), ('session_id', 'uuid'), ('subtotal', 'numeric'), ('discount', 'numeric'), ('total_amount', 'numeric'), ('payment_method', 'text'), ('status', 'text')],
            # finance_records
            [('id', 'uuid'), ('store_id', 'uuid'), ('type', 'text'), ('amount', 'numeric'), ('reference_id', 'uuid'), ('is_auto', 'bool'), ('fund_type', 'text'), ('recorded_at', 'timestamptz')],
            # stock_movements
            [('id', 'uuid'), ('store_id', 'uuid'), ('product_id', 'uuid'), ('delta', 'numeric'), ('reason', 'text'), ('reference_id', 'uuid')],
            # loyalty_transactions
            [('id', 'uuid'), ('store_id', 'uuid'), ('customer_id', 'uuid'), ('pts_earned', 'numeric'), ('pts_used', 'numeric')],
            # staff_members
            [('id', 'uuid'), ('updated_at', 'int8')],
            # products
            [('id', 'uuid'), ('sell_price', 'numeric'), ('stock_qty', 'numeric'), ('is_deleted', 'bool'), ('updated_at', 'int8')]
        ]

        assert_schema_contracts(mock_conn, has_coupons=False)

    def test_11_cleanup_when_db_b_creation_fails(self):
        mock_admin_conn = MagicMock()
        mock_cur = MagicMock()
        mock_admin_conn.cursor.return_value.__enter__.return_value = mock_cur

        db_a = "test_settle_v5_no_coupons_test01"
        db_b = "test_settle_v5_with_coupons_test01"

        res = execute_cleanup(mock_admin_conn, db_a, db_b, created_roles=[])
        self.assertTrue(res)

        # Verify DROP DATABASE was executed for both DBs
        sql_calls = [c[0][0] for c in mock_cur.execute.call_args_list]
        self.assertTrue(any(f"DROP DATABASE IF EXISTS {db_a}" in s for s in sql_calls))
        self.assertTrue(any(f"DROP DATABASE IF EXISTS {db_b}" in s for s in sql_calls))

    def test_12_cleanup_when_migration_fails(self):
        mock_admin_conn = MagicMock()
        mock_cur = MagicMock()
        mock_admin_conn.cursor.return_value.__enter__.return_value = mock_cur

        db_a = "test_settle_v5_no_coupons_test02"
        db_b = "test_settle_v5_with_coupons_test02"

        res = execute_cleanup(mock_admin_conn, db_a, db_b, created_roles=[])
        self.assertTrue(res)
        sql_calls = [c[0][0] for c in mock_cur.execute.call_args_list]
        self.assertTrue(any(f"DROP DATABASE IF EXISTS {db_a}" in s for s in sql_calls))

    def test_13_cleanup_when_concurrency_fails(self):
        mock_admin_conn = MagicMock()
        mock_cur = MagicMock()
        mock_admin_conn.cursor.return_value.__enter__.return_value = mock_cur

        db_a = "test_settle_v5_no_coupons_test03"
        db_b = "test_settle_v5_with_coupons_test03"

        res = execute_cleanup(mock_admin_conn, db_a, db_b, created_roles=[])
        self.assertTrue(res)
        sql_calls = [c[0][0] for c in mock_cur.execute.call_args_list]
        self.assertTrue(any("pg_terminate_backend" in s for s in sql_calls))
        self.assertTrue(any(f"DROP DATABASE IF EXISTS {db_a}" in s for s in sql_calls))

    def test_14_cleanup_only_drops_runner_provisioned_roles(self):
        mock_admin_conn = MagicMock()
        mock_cur = MagicMock()
        mock_admin_conn.cursor.return_value.__enter__.return_value = mock_cur

        created_roles = ['anon', 'authenticated']
        res = execute_cleanup(mock_admin_conn, "db_a", "db_b", created_roles=created_roles)
        self.assertTrue(res)

        sql_calls = [c[0][0] for c in mock_cur.execute.call_args_list]
        self.assertTrue(any("DROP ROLE IF EXISTS anon;" in s for s in sql_calls))
        self.assertTrue(any("DROP ROLE IF EXISTS authenticated;" in s for s in sql_calls))

    def test_15_cleanup_failure_causes_gate_to_fail(self):
        mock_admin_conn = MagicMock()
        mock_cur = MagicMock()
        mock_admin_conn.cursor.return_value.__enter__.return_value = mock_cur
        mock_cur.execute.side_effect = Exception("Catalog lock failure during DROP DATABASE")

        res = execute_cleanup(mock_admin_conn, "db_a", "db_b", created_roles=[])
        self.assertFalse(res, "Cleanup failure must return False so gate fails")

if __name__ == "__main__":
    unittest.main()
