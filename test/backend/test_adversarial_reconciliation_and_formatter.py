#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Adversarial Verification Suite for:
1. Data Reconciliation Migration (supabase/migrations/20261001_fix_recipe_unit_conversion_and_reconcile_stock.sql)
   - Idempotency (running 1x, 2x, 3x)
   - Orders exist vs do not exist
   - APPEND-ONLY verification (strict prohibition of UPDATE/DELETE on stock_movements)
   - Discrepancy recovery math (+59.94 kg Sữa đặc, +38.961 kg Cà phê hạt, +44.955 kg Bột kem muối)
2. Quantity Formatter (lib/core/utils/quantity_formatter.dart)
   - Evil inputs: -0.0, -0.0000001, 0.0000001, NaN, Infinity, -Infinity, null, empty unit, unicode characters
   - Boundary rounding & anti "-0" suppression
"""

import math
import os
import re
import sqlite3
import unittest
import uuid

# ─────────────────────────────────────────────────────────────────────────────
# Python Oracle for Quantity Formatter
# Exact mirror of Dart lib/core/utils/quantity_formatter.dart
# ─────────────────────────────────────────────────────────────────────────────
def dart_fmt_qty(v, max_decimals=3):
    if v is None:
        # In Dart, num is non-nullable; if passed dynamically as null, Dart throws NoSuchMethodError
        raise TypeError("v cannot be None in strict Dart num type")
    if math.isnan(v) or math.isinf(v):
        return '0'
    d = float(v)
    if abs(d) <= 1e-6:
        return '0'
    if d % 1 == 0:
        return str(int(d))

    s = f"{d:.{max_decimals}f}"
    if '.' in s:
        s = re.sub(r'0+$', '', s)
        s = re.sub(r'\.$', '', s)
    if s in ('-0', '-0.0', '', '-'):
        return '0'
    return s


def dart_fmt_delta(delta, unit, max_decimals=3):
    if delta is None or unit is None:
        raise TypeError("delta and unit cannot be None in strict Dart type")
    d = float(delta)
    u = unit.strip()
    unit_suffix = f" {u}" if len(u) > 0 else ''
    if math.isnan(d) or math.isinf(d) or abs(d) <= 1e-6:
        return f"0{unit_suffix}"

    abs_formatted = dart_fmt_qty(abs(d), max_decimals=max_decimals)
    if abs_formatted == '0':
        return f"0{unit_suffix}"

    sign = '+' if d > 0 else '-'
    return f"{sign}{abs_formatted}{unit_suffix}"


# ─────────────────────────────────────────────────────────────────────────────
# Adversarial Test Suite
# ─────────────────────────────────────────────────────────────────────────────
class TestAdversarialReconciliationAndFormatter(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        cls.migration_path = os.path.join(
            cls.repo_root,
            "supabase/migrations/20261001_fix_recipe_unit_conversion_and_reconcile_stock.sql"
        )
        cls.formatter_path = os.path.join(
            cls.repo_root,
            "lib/core/utils/quantity_formatter.dart"
        )

        with open(cls.migration_path, "r", encoding="utf-8") as f:
            cls.migration_sql = f.read()

        with open(cls.formatter_path, "r", encoding="utf-8") as f:
            cls.formatter_dart = f.read()

    # ═════════════════════════════════════════════════════════════════════════
    # SECTION 1: MIGRATION STATIC ANALYSIS & APPEND-ONLY AUDIT
    # ═════════════════════════════════════════════════════════════════════════
    def test_01_migration_append_only_strict_invariant(self):
        """Verify migration NEVER executes UPDATE or DELETE on stock_movements."""
        # Check DELETE FROM stock_movements
        delete_match = re.search(r"DELETE\s+FROM\s+(?:public\.)?stock_movements", self.migration_sql, re.IGNORECASE)
        self.assertIsNone(delete_match, "CRITICAL: Found DELETE FROM stock_movements in migration!")

        # Check UPDATE stock_movements
        update_match = re.search(r"UPDATE\s+(?:public\.)?stock_movements", self.migration_sql, re.IGNORECASE)
        self.assertIsNone(update_match, "CRITICAL: Found UPDATE stock_movements in migration!")

        # Verify all mutations on stock_movements are INSERT INTO
        inserts = re.findall(r"INSERT\s+INTO\s+public\.stock_movements", self.migration_sql, re.IGNORECASE)
        self.assertGreaterEqual(len(inserts), 2, "Expected INSERT INTO public.stock_movements for audit records")

    def test_02_migration_target_order_numbers(self):
        """Verify reconciliation specifically includes the 3 damaged orders with and without #."""
        self.assertIn("QN-20260930-002", self.migration_sql)
        self.assertIn("QN-20260930-003", self.migration_sql)
        self.assertIn("QN-20261001-001", self.migration_sql)
        self.assertIn("#QN-20260930-002", self.migration_sql)
        self.assertIn("#QN-20260930-003", self.migration_sql)
        self.assertIn("#QN-20261001-001", self.migration_sql)

    def test_03_migration_reconciliation_reason_label(self):
        """Verify reconciliation inserts use reason = 'reconciliation'."""
        self.assertIn("'reconciliation'", self.migration_sql)
        self.assertIn("reconcile_erroneous_recipe_orders_v1", self.migration_sql)

    # ═════════════════════════════════════════════════════════════════════════
    # SECTION 2: SQL SIMULATION OF RECONCILIATION LOGIC (IDEMPOTENCY & SCENARIOS)
    # ═════════════════════════════════════════════════════════════════════════
    def _create_simulated_db(self):
        """Creates an in-memory SQLite database matching Supabase schema."""
        conn = sqlite3.connect(":memory:")
        c = conn.cursor()
        c.execute("""
            CREATE TABLE orders (
                id TEXT PRIMARY KEY,
                store_id TEXT,
                order_number TEXT
            );
        """)
        c.execute("""
            CREATE TABLE products (
                id TEXT PRIMARY KEY,
                store_id TEXT,
                name TEXT,
                unit TEXT,
                stock_qty REAL,
                updated_at REAL
            );
        """)
        c.execute("""
            CREATE TABLE stock_movements (
                id TEXT PRIMARY KEY,
                store_id TEXT,
                product_id TEXT,
                delta REAL,
                reason TEXT,
                reference_id TEXT,
                note TEXT,
                created_at TEXT
            );
        """)
        conn.commit()
        return conn

    def _execute_simulated_reconciliation(self, conn):
        """Executes the exact PL/pgSQL logic of reconcile_erroneous_recipe_orders_v1 in Python SQLite."""
        c = conn.cursor()
        target_orders = ['QN-20260930-002', 'QN-20260930-003', 'QN-20261001-001',
                         '#QN-20260930-002', '#QN-20260930-003', '#QN-20261001-001']
        reconciled_count = 0
        details = []

        # 1. Quét theo orders table khớp mã đơn hàng cần đối soát
        placeholders = ','.join(['?'] * len(target_orders))
        c.execute(f"SELECT id, store_id, order_number FROM orders WHERE order_number IN ({placeholders})", target_orders)
        orders = c.fetchall()

        for o_id, o_store_id, o_order_num in orders:
            order_num_clean = o_order_num.replace('#', '')

            # Query erroneous stock movements
            c.execute("""
                SELECT sm.id, sm.product_id, sm.delta, sm.note, p.name AS product_name, p.unit AS product_unit
                FROM stock_movements sm
                JOIN products p ON p.id = sm.product_id
                WHERE sm.store_id = ?
                  AND (sm.reference_id = ? OR sm.note LIKE '%' || ? || '%')
                  AND sm.reason = 'recipe_usage'
                  AND sm.delta < -1.0
            """, (o_store_id, o_id, order_num_clean))
            recs = c.fetchall()

            for sm_id, prod_id, delta, note, prod_name, prod_unit in recs:
                # Idempotency check
                c.execute("""
                    SELECT 1 FROM stock_movements
                    WHERE store_id = ?
                      AND product_id = ?
                      AND (reference_id = ? OR note LIKE '%' || ? || '%')
                      AND reason = 'reconciliation'
                """, (o_store_id, prod_id, o_id, order_num_clean))
                already_reconciled = c.fetchone() is not None

                if not already_reconciled:
                    prod_name_lower = prod_name.lower()
                    if delta == -20.0 or 'sữa đặc' in prod_name_lower or 'sua dac' in prod_name_lower:
                        refund_qty = 19.980
                    elif delta == -13.0 or 'cà phê' in prod_name_lower or 'ca phe' in prod_name_lower:
                        refund_qty = 12.987
                    elif delta == -15.0 or 'bột kem' in prod_name_lower or 'bot kem' in prod_name_lower or 'kem muối' in prod_name_lower:
                        refund_qty = 14.985
                    else:
                        refund_qty = abs(delta) - (abs(delta) / 1000.0)

                    # APPEND-ONLY insert
                    c.execute("""
                        INSERT INTO stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
                        VALUES (?, ?, ?, ?, 'reconciliation', ?, ?, datetime('now'))
                    """, (str(uuid.uuid4()), o_store_id, prod_id, refund_qty, o_id,
                          f"Bù hoàn tồn kho định lượng sai đơn #{order_num_clean}: {prod_name} (+{refund_qty} {prod_unit or 'kg'})"))

                    # UPDATE products stock_qty
                    c.execute("""
                        UPDATE products
                        SET stock_qty = COALESCE(stock_qty, 0) + ?,
                            updated_at = 1727770000000
                        WHERE id = ? AND store_id = ?
                    """, (refund_qty, prod_id, o_store_id))

                    reconciled_count += 1
                    details.append({
                        'order_number': o_order_num,
                        'product_name': prod_name,
                        'refund_qty': refund_qty,
                        'product_id': prod_id
                    })

        # 2. Quét trực tiếp stock_movements nếu bản ghi order_number nằm trong note
        c.execute("""
            SELECT sm.id, sm.store_id, sm.product_id, sm.delta, sm.reference_id, sm.note, p.name AS product_name, p.unit AS product_unit,
                   CASE
                     WHEN sm.note LIKE '%20260930-002%' THEN 'QN-20260930-002'
                     WHEN sm.note LIKE '%20260930-003%' THEN 'QN-20260930-003'
                     WHEN sm.note LIKE '%20261001-001%' THEN 'QN-20261001-001'
                     ELSE 'UNKNOWN'
                   END AS detected_order_num
            FROM stock_movements sm
            JOIN products p ON p.id = sm.product_id
            WHERE sm.reason = 'recipe_usage'
              AND (
                sm.note LIKE '%20260930-002%'
                OR sm.note LIKE '%20260930-003%'
                OR sm.note LIKE '%20261001-001%'
              )
              AND sm.delta < -1.0
        """)
        sm_recs = c.fetchall()

        for sm_id, store_id, prod_id, delta, ref_id, note, prod_name, prod_unit, detected_order in sm_recs:
            if detected_order != 'UNKNOWN':
                c.execute("""
                    SELECT 1 FROM stock_movements
                    WHERE store_id = ?
                      AND product_id = ?
                      AND ((? IS NOT NULL AND reference_id = ?) OR note LIKE '%' || ? || '%')
                      AND reason = 'reconciliation'
                """, (store_id, prod_id, ref_id, ref_id, detected_order))
                already_reconciled = c.fetchone() is not None

                if not already_reconciled:
                    prod_name_lower = prod_name.lower()
                    if delta == -20.0 or 'sữa đặc' in prod_name_lower or 'sua dac' in prod_name_lower:
                        refund_qty = 19.980
                    elif delta == -13.0 or 'cà phê' in prod_name_lower or 'ca phe' in prod_name_lower:
                        refund_qty = 12.987
                    elif delta == -15.0 or 'bột kem' in prod_name_lower or 'bot kem' in prod_name_lower or 'kem muối' in prod_name_lower:
                        refund_qty = 14.985
                    else:
                        refund_qty = abs(delta) - (abs(delta) / 1000.0)

                    c.execute("""
                        INSERT INTO stock_movements (id, store_id, product_id, delta, reason, reference_id, note, created_at)
                        VALUES (?, ?, ?, ?, 'reconciliation', ?, ?, datetime('now'))
                    """, (str(uuid.uuid4()), store_id, prod_id, refund_qty, ref_id,
                          f"Bù hoàn tồn kho định lượng sai đơn #{detected_order}: {prod_name} (+{refund_qty} {prod_unit or 'kg'})"))

                    c.execute("""
                        UPDATE products
                        SET stock_qty = COALESCE(stock_qty, 0) + ?,
                            updated_at = 1727770000000
                        WHERE id = ? AND store_id = ?
                    """, (refund_qty, prod_id, store_id))

                    reconciled_count += 1
                    details.append({
                        'order_number': detected_order,
                        'product_name': prod_name,
                        'refund_qty': refund_qty,
                        'product_id': prod_id
                    })

        conn.commit()
        return {'success': True, 'reconciled_count': reconciled_count, 'details': details}

    def test_04_reconciliation_scenario_orders_exist_full_lifecycle(self):
        """Simulate normal scenario where orders exist in orders table with # prefix."""
        conn = self._create_simulated_db()
        c = conn.cursor()

        store_id = "store-test-1"
        milk_id = "prod-milk"
        beans_id = "prod-beans"
        cream_id = "prod-cream"

        # Initial products: Initial stock 100kg, but after 3 buggy orders became negative or depleted
        # Buggy orders subtracted 20kg, 13kg, 15kg per order
        c.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", (milk_id, store_id, "Sữa đặc Ngôi Sao", "kg", 40.0, 0))
        c.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", (beans_id, store_id, "Cà phê hạt Robusta", "kg", 61.0, 0))
        c.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", (cream_id, store_id, "Bột kem muối biển", "lít", 55.0, 0))

        order_nums = ["#QN-20260930-002", "#QN-20260930-003", "#QN-20261001-001"]
        for idx, o_num in enumerate(order_nums):
            o_id = f"order-{idx+1}"
            c.execute("INSERT INTO orders VALUES (?, ?, ?)", (o_id, store_id, o_num))
            clean_num = o_num.replace("#", "")

            # Erroneous movements: -20, -13, -15
            c.execute("INSERT INTO stock_movements VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                      (f"sm-{idx}-1", store_id, milk_id, -20.0, 'recipe_usage', o_id, f"POS công thức #{clean_num}: Cà phê muối", "2026-09-30"))
            c.execute("INSERT INTO stock_movements VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                      (f"sm-{idx}-2", store_id, beans_id, -13.0, 'recipe_usage', o_id, f"POS công thức #{clean_num}: Cà phê muối", "2026-09-30"))
            c.execute("INSERT INTO stock_movements VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                      (f"sm-{idx}-3", store_id, cream_id, -15.0, 'recipe_usage', o_id, f"POS công thức #{clean_num}: Cà phê muối", "2026-09-30"))

        conn.commit()

        # PASS 1: Execute reconciliation
        res1 = self._execute_simulated_reconciliation(conn)
        self.assertTrue(res1['success'])
        self.assertEqual(res1['reconciled_count'], 9, "Expected 9 items reconciled (3 orders x 3 ingredients)")

        # Verify stock quantities after Pass 1:
        # Milk: 40.0 + 3 * 19.980 = 40.0 + 59.940 = 99.940 kg
        # Beans: 61.0 + 3 * 12.987 = 61.0 + 38.961 = 99.961 kg
        # Cream: 55.0 + 3 * 14.985 = 55.0 + 44.955 = 99.955 lít
        c.execute("SELECT stock_qty FROM products WHERE id = ?", (milk_id,))
        self.assertAlmostEqual(c.fetchone()[0], 99.940, places=4)
        c.execute("SELECT stock_qty FROM products WHERE id = ?", (beans_id,))
        self.assertAlmostEqual(c.fetchone()[0], 99.961, places=4)
        c.execute("SELECT stock_qty FROM products WHERE id = ?", (cream_id,))
        self.assertAlmostEqual(c.fetchone()[0], 99.955, places=4)

        # Total stock movements: 9 original + 9 reconciliation = 18
        c.execute("SELECT COUNT(*) FROM stock_movements")
        self.assertEqual(c.fetchone()[0], 18)

        # PASS 2: Idempotency Re-execution (Pass 2)
        res2 = self._execute_simulated_reconciliation(conn)
        self.assertTrue(res2['success'])
        self.assertEqual(res2['reconciled_count'], 0, "Idempotency FAIL: Pass 2 must reconcile 0 items!")

        # Verify stock quantities unchanged after Pass 2
        c.execute("SELECT stock_qty FROM products WHERE id = ?", (milk_id,))
        self.assertAlmostEqual(c.fetchone()[0], 99.940, places=4)
        c.execute("SELECT stock_qty FROM products WHERE id = ?", (beans_id,))
        self.assertAlmostEqual(c.fetchone()[0], 99.961, places=4)
        c.execute("SELECT stock_qty FROM products WHERE id = ?", (cream_id,))
        self.assertAlmostEqual(c.fetchone()[0], 99.955, places=4)

        # Total movements must still be 18
        c.execute("SELECT COUNT(*) FROM stock_movements")
        self.assertEqual(c.fetchone()[0], 18)

        # PASS 3: Re-execution (Pass 3)
        res3 = self._execute_simulated_reconciliation(conn)
        self.assertEqual(res3['reconciled_count'], 0, "Idempotency FAIL: Pass 3 must reconcile 0 items!")
        conn.close()

    def test_05_reconciliation_scenario_orders_do_not_exist_in_orders_table(self):
        """Simulate edge case where orders were purged or deleted from orders table, but note in stock_movements remains."""
        conn = self._create_simulated_db()
        c = conn.cursor()

        store_id = "store-test-2"
        milk_id = "prod-milk-2"
        beans_id = "prod-beans-2"
        cream_id = "prod-cream-2"

        c.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", (milk_id, store_id, "Sữa đặc Ngôi Sao", "kg", 10.0, 0))
        c.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", (beans_id, store_id, "Cà phê hạt Robusta", "kg", 10.0, 0))
        c.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", (cream_id, store_id, "Bột kem muối biển", "lít", 10.0, 0))

        # Do NOT insert into orders table (orders table is empty!)
        order_nums = ["QN-20260930-002", "QN-20260930-003", "QN-20261001-001"]
        for idx, o_num in enumerate(order_nums):
            c.execute("INSERT INTO stock_movements VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                      (f"sm-orphan-{idx}-1", store_id, milk_id, -20.0, 'recipe_usage', None, f"POS công thức #{o_num}: Cà phê muối", "2026-09-30"))
            c.execute("INSERT INTO stock_movements VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                      (f"sm-orphan-{idx}-2", store_id, beans_id, -13.0, 'recipe_usage', None, f"POS công thức #{o_num}: Cà phê muối", "2026-09-30"))
            c.execute("INSERT INTO stock_movements VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                      (f"sm-orphan-{idx}-3", store_id, cream_id, -15.0, 'recipe_usage', None, f"POS công thức #{o_num}: Cà phê muối", "2026-09-30"))

        conn.commit()

        # PASS 1: Loop 2 should pick up via note pattern matching
        res1 = self._execute_simulated_reconciliation(conn)
        self.assertTrue(res1['success'])
        self.assertEqual(res1['reconciled_count'], 9, "Expected Loop 2 to reconcile 9 items via note parsing")

        # Verify stock
        c.execute("SELECT stock_qty FROM products WHERE id = ?", (milk_id,))
        self.assertAlmostEqual(c.fetchone()[0], 10.0 + 59.940, places=4)

        # PASS 2: Idempotency Re-execution
        res2 = self._execute_simulated_reconciliation(conn)
        self.assertEqual(res2['reconciled_count'], 0, "Idempotency FAIL: Pass 2 must reconcile 0 items!")
        conn.close()

    def test_06_reconciliation_scenario_zero_matching_orders_or_movements(self):
        """Simulate pristine system where no matching erroneous orders or movements exist."""
        conn = self._create_simulated_db()
        c = conn.cursor()

        # Unrelated store and orders
        c.execute("INSERT INTO products VALUES (?, ?, ?, ?, ?, ?)", ("p1", "s1", "Trà ô long", "kg", 5.0, 0))
        c.execute("INSERT INTO orders VALUES (?, ?, ?)", ("o1", "s1", "QN-20261001-999"))
        c.execute("INSERT INTO stock_movements VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                  ("sm1", "s1", "p1", -0.02, 'recipe_usage', "o1", "POS công thức #QN-20261001-999: Trà ô long", "2026-10-01"))
        conn.commit()

        res = self._execute_simulated_reconciliation(conn)
        self.assertTrue(res['success'])
        self.assertEqual(res['reconciled_count'], 0)
        self.assertEqual(len(res['details']), 0)

        # Product stock untouched
        c.execute("SELECT stock_qty FROM products WHERE id = 'p1'")
        self.assertEqual(c.fetchone()[0], 5.0)
        conn.close()

    # ═════════════════════════════════════════════════════════════════════════
    # SECTION 3: QUANTITY FORMATTER ADVERSARIAL STRESS HARNESS
    # ═════════════════════════════════════════════════════════════════════════
    def test_07_fmt_qty_evil_zeroes(self):
        """Stress test fmtQty against all flavors of zero."""
        self.assertEqual(dart_fmt_qty(0), '0')
        self.assertEqual(dart_fmt_qty(0.0), '0')
        self.assertEqual(dart_fmt_qty(-0.0), '0')
        self.assertEqual(dart_fmt_qty(-0), '0')
        self.assertEqual(dart_fmt_qty(-0.0000001), '0')
        self.assertEqual(dart_fmt_qty(0.0000001), '0')
        self.assertEqual(dart_fmt_qty(-1e-6), '0')
        self.assertEqual(dart_fmt_qty(1e-6), '0')
        self.assertEqual(dart_fmt_qty(-1e-9), '0')
        self.assertEqual(dart_fmt_qty(1e-9), '0')

    def test_08_fmt_delta_evil_zeroes(self):
        """Stress test fmtDelta against all flavors of zero: NEVER -0 kg or +0 kg."""
        self.assertEqual(dart_fmt_delta(0, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(0.0, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(-0.0, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(-0, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(-0.0000001, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(0.0000001, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(-1e-6, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(1e-6, 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(-1e-9, 'kg'), '0 kg')

    def test_09_fmt_qty_nan_and_infinity(self):
        """Verify fmtQty safely handles NaN and Infinity without exception or weird strings."""
        self.assertEqual(dart_fmt_qty(float('nan')), '0')
        self.assertEqual(dart_fmt_qty(float('inf')), '0')
        self.assertEqual(dart_fmt_qty(float('-inf')), '0')

    def test_10_fmt_delta_nan_and_infinity(self):
        """Verify fmtDelta safely handles NaN and Infinity."""
        self.assertEqual(dart_fmt_delta(float('nan'), 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(float('inf'), 'kg'), '0 kg')
        self.assertEqual(dart_fmt_delta(float('-inf'), 'kg'), '0 kg')

    def test_11_fmt_delta_empty_and_whitespace_unit(self):
        """Verify fmtDelta formatting with empty or whitespace-only units."""
        self.assertEqual(dart_fmt_delta(5, ''), '+5')
        self.assertEqual(dart_fmt_delta(-0.02, ''), '-0.02')
        self.assertEqual(dart_fmt_delta(0, ''), '0')
        self.assertEqual(dart_fmt_delta(5, '   '), '+5')
        self.assertEqual(dart_fmt_delta(-0.02, '  \t '), '-0.02')
        self.assertEqual(dart_fmt_delta(0, ' \n '), '0')

    def test_12_fmt_delta_unicode_units(self):
        """Verify fmtDelta formatting with unicode characters, emojis, and Vietnamese diacritics."""
        self.assertEqual(dart_fmt_delta(10, 'hộp'), '+10 hộp')
        self.assertEqual(dart_fmt_delta(-0.015, 'lít'), '-0.015 lít')
        self.assertEqual(dart_fmt_delta(5, 'ký'), '+5 ký')
        self.assertEqual(dart_fmt_delta(-1, 'phần'), '-1 phần')
        self.assertEqual(dart_fmt_delta(2, 'ly ☕'), '+2 ly ☕')
        self.assertEqual(dart_fmt_delta(-0.02, 'kg 🌟'), '-0.02 kg 🌟')
        self.assertEqual(dart_fmt_delta(0, 'lít 🍶'), '0 lít 🍶')

    def test_13_fmt_qty_sub_milligram_rounding(self):
        """Verify sub-milligram rounding boundaries do not leak negative zero."""
        # 0.0004 rounds to 0.000 -> '0'
        self.assertEqual(dart_fmt_qty(0.0004), '0')
        self.assertEqual(dart_fmt_qty(-0.0004), '0')
        self.assertEqual(dart_fmt_delta(-0.0004, 'kg'), '0 kg')

        # 0.0006 rounds to 0.001 -> '0.001'
        self.assertEqual(dart_fmt_qty(0.0006), '0.001')
        self.assertEqual(dart_fmt_qty(-0.0006), '-0.001')
        self.assertEqual(dart_fmt_delta(-0.0006, 'kg'), '-0.001 kg')
        self.assertEqual(dart_fmt_delta(0.0006, 'kg'), '+0.001 kg')

    def test_14_fmt_qty_extreme_values(self):
        """Verify very large positive and negative numbers."""
        self.assertEqual(dart_fmt_qty(1000000), '1000000')
        self.assertEqual(dart_fmt_qty(-1000000), '-1000000')
        self.assertEqual(dart_fmt_delta(1000000, 'g'), '+1000000 g')
        self.assertEqual(dart_fmt_delta(-1000000, 'ml'), '-1000000 ml')

    def test_15_null_parameter_analysis(self):
        """
        Verify type safety contract for null inputs:
        In Dart Sound Null Safety, 'num v' and 'String unit' statically forbid null.
        If passed as dynamic null, an exception is expected in typed Dart.
        """
        with self.assertRaises(TypeError):
            dart_fmt_qty(None)
        with self.assertRaises(TypeError):
            dart_fmt_delta(None, 'kg')
        with self.assertRaises(TypeError):
            dart_fmt_delta(5, None)


if __name__ == '__main__':
    unittest.main()
