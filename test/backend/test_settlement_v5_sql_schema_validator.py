#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Unit Test & Static SQL Schema Validator for Settlement V5 & Atomic POS Sale
Validates:
1. File encoding, clean endings (0x0A), balanced $$ blocks.
2. DDL Table definitions: daily_order_counters, pos_idempotency_operations, pos_coupon_redemptions with conditional FK.
3. Preflight Fail-Safe & Partial Unique Index trên finance_records.
4. Function signatures, SECURITY DEFINER, search_path, and fail-closed validation.
5. REVOKE / GRANT permission matrix.
6. SQL Integration Test Suite coverage (7-table snapshots & coupon absence/presence branches).
7. Python 50-worker test harness structure.
"""

import os
import re
import unittest

class TestSettlementV5SchemaValidator(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        cls.migration_path = os.path.join(cls.repo_root, "supabase/migrations/20260902_atomic_settlement_v5.sql")
        cls.sql_test_path = os.path.join(cls.repo_root, "supabase/tests/settle_v5_concurrency_test.sql")
        cls.py_test_path = os.path.join(cls.repo_root, "test/backend/test_settlement_v5_concurrency_real_pg.py")

        with open(cls.migration_path, "r", encoding="utf-8") as f:
            cls.migration_sql = f.read()

        with open(cls.sql_test_path, "r", encoding="utf-8") as f:
            cls.sql_test = f.read()

        with open(cls.py_test_path, "r", encoding="utf-8") as f:
            cls.py_test = f.read()

    def test_01_file_endings_and_delimiter_balance(self):
        """Verify files end with newline byte and have balanced $$ blocks"""
        with open(self.migration_path, "rb") as f:
            self.assertTrue(f.read().endswith(b"\n"), "Migration file must end with 0x0A newline")

        with open(self.sql_test_path, "rb") as f:
            self.assertTrue(f.read().endswith(b"\n"), "SQL test file must end with 0x0A newline")

        m_dollars = self.migration_sql.count("$$")
        self.assertEqual(m_dollars % 2, 0, f"Unbalanced $$ in migration: {m_dollars}")

        t_dollars = self.sql_test.count("$$")
        self.assertEqual(t_dollars % 2, 0, f"Unbalanced $$ in SQL test: {t_dollars}")

    def test_02_table_definitions(self):
        """Verify DDL for daily_order_counters, pos_idempotency_operations, and pos_coupon_redemptions"""
        self.assertIn("CREATE TABLE IF NOT EXISTS public.daily_order_counters", self.migration_sql)
        self.assertIn("PRIMARY KEY (store_id, business_date, prefix)", self.migration_sql)

        self.assertIn("CREATE TABLE IF NOT EXISTS public.pos_idempotency_operations", self.migration_sql)
        self.assertIn("CONSTRAINT uq_pos_idemp_key UNIQUE (store_id, idempotency_key)", self.migration_sql)

        self.assertIn("CREATE TABLE IF NOT EXISTS public.pos_coupon_redemptions", self.migration_sql)
        self.assertIn("CONSTRAINT uq_pos_coupon_redemption_order UNIQUE (store_id, order_id)", self.migration_sql)
        self.assertIn("fk_pos_coupon_redemptions_coupons", self.migration_sql)

    def test_03_preflight_failsafe_and_partial_unique_index(self):
        """Verify preflight duplicate check and partial unique index on finance_records"""
        self.assertIn("PREFLIGHT_FAIL: Found % duplicate auto-income records in finance_records", self.migration_sql)
        self.assertIn("CREATE UNIQUE INDEX IF NOT EXISTS uq_finance_auto_settlement_income", self.migration_sql)
        self.assertIn("ON public.finance_records (store_id, checkout_reference_id)", self.migration_sql)
        self.assertIn("WHERE checkout_reference_id IS NOT NULL", self.migration_sql)
        self.assertIn("CREATE TRIGGER classify_checkout_income_v1", self.migration_sql)

    def test_04_function_security_and_search_path(self):
        """Verify SECURITY DEFINER and SET search_path = pg_catalog, public on all functions"""
        funcs = [
            "generate_daily_order_number_v1",
            "reconcile_ban_settlement_v1",
            "settle_ban_session_v5",
            "complete_pos_sale_v1",
        ]
        for f in funcs:
            self.assertIn(f"FUNCTION public.{f}", self.migration_sql, f"Missing function {f}")
            pattern = rf"FUNCTION public\.{f}[\s\S]*?SECURITY DEFINER[\s\S]*?SET search_path = pg_catalog, public"
            self.assertTrue(re.search(pattern, self.migration_sql), f"Function {f} must have SECURITY DEFINER and search_path set")

    def test_05_reconcile_ban_settlement_mismatch_guard(self):
        """Verify reconcile_ban_settlement_v1 checks for cross-session/key mismatch"""
        self.assertIn("IDEMPOTENCY_CONFLICT", self.migration_sql)
        self.assertIn("Idempotency key này thuộc về một phiên bàn khác", self.migration_sql)
        self.assertIn("Phiên bàn đã được thanh toán dưới một idempotency key khác", self.migration_sql)

    def test_06_complete_pos_sale_fail_closed_logic(self):
        """Verify complete_pos_sale_v1 has strict validation, coupon check, and pos_coupon_redemptions"""
        self.assertIn("INVALID_QUANTITY", self.migration_sql)
        self.assertIn("INVALID_POINTS", self.migration_sql)
        self.assertIn("COUPON_NOT_FOUND", self.migration_sql)
        self.assertIn("COUPON_DISABLED", self.migration_sql)
        self.assertIn("COUPON_EXPIRED", self.migration_sql)
        self.assertIn("COUPON_NOT_STARTED", self.migration_sql)
        self.assertIn("COUPON_MIN_ORDER_NOT_MET", self.migration_sql)
        self.assertIn("FINANCIAL_QUOTE_CHANGED", self.migration_sql)
        self.assertIn("INSERT INTO public.pos_coupon_redemptions", self.migration_sql)
        self.assertIn("v_clean_source_type", self.migration_sql)
        self.assertIn("'recipe_usage'", self.migration_sql)
        self.assertIn("cashier_staff_id", self.migration_sql)
        self.assertIn("v_staff_member_id, 'completed'", self.migration_sql)

    def test_07_grants_and_revokes(self):
        """Verify strict REVOKE and authenticated-only grants"""
        self.assertIn("REVOKE ALL ON public.daily_order_counters FROM PUBLIC, anon, authenticated;", self.migration_sql)
        self.assertIn("REVOKE ALL ON public.pos_idempotency_operations FROM PUBLIC, anon, authenticated;", self.migration_sql)
        self.assertIn("REVOKE ALL ON public.pos_coupon_redemptions FROM PUBLIC, anon, authenticated;", self.migration_sql)
        self.assertIn("GRANT EXECUTE ON FUNCTION public.settle_ban_session_v5", self.migration_sql)
        self.assertIn("GRANT EXECUTE ON FUNCTION public.complete_pos_sale_v1", self.migration_sql)

    def test_08_sql_test_suite_covers_7_table_snapshots(self):
        """Verify SQL integration test suite validates all 7 tables upon replay and covers both coupon branches"""
        self.assertIn("v_cnt_orders_before", self.sql_test)
        self.assertIn("v_cnt_items_before", self.sql_test)
        self.assertIn("v_cnt_finance_before", self.sql_test)
        self.assertIn("v_cnt_stock_before", self.sql_test)
        self.assertIn("v_cnt_loyalty_before", self.sql_test)
        self.assertIn("v_cnt_coupons_before", self.sql_test)
        self.assertIn("v_cnt_idemp_before", self.sql_test)
        self.assertIn("COUPON_SCHEMA_UNAVAILABLE", self.sql_test)

    def test_09_py_test_harness_has_barrier_and_50_workers(self):
        """Verify Python concurrency harness utilizes Barrier(50) and continuous sequence verification"""
        self.assertIn("threading.Barrier(50)", self.py_test)
        self.assertIn("max_workers=50", self.py_test)
        self.assertIn("expected_range = list(range(seqs[0], seqs[0] + 50))", self.py_test)
        self.assertIn("pos_coupon_redemptions", self.py_test)

if __name__ == "__main__":
    unittest.main()
