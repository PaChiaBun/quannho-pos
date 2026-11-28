#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ADVERSARIAL STRESS TEST SUITE: F&B Unit Conversion & PostgreSQL RPCs
Author: challenger_1 (Adversarial Challenger Subagent)
Scope:
1. Mathematical Oracle Edge-Case Stress Testing (convert_recipe_ingredient_qty_v1)
   - Zero quantity, None/NULL quantity
   - Negative quantity (returns/refunds preservation)
   - Zero and negative conversion rates (division-by-zero defense)
   - Empty, whitespace, None conversion units
   - Incompatible dimension fallback
   - Case insensitivity, whitespace padding, Vietnamese accents & aliases
   - Micro-quantities (1e-5 to 1e-9) and astronomical quantities (1e9 to 1e12)
   - Packaging specifications and bidirectional round-trip precision
2. SQL Migration & RPC Structural Analysis
   - IMMUTABLE attribute verification
   - complete_pos_sale_v1 & settle_ban_session_v5:
     * Products without recipes (direct sale deduction)
     * Zero, NULL, or negative yield factors (safe clamping to 1.0)
     * Multiple line items iteration
     * Modifiers / toppings recipe & non-recipe branching
   - Historical Reconciliation idempotency & append-only verification
3. In-Memory SQLite Behavioral Simulation
   - End-to-end POS sale stock deduction simulation
   - Multi-ingredient recipe deduction simulation
   - Zero yield factor defense
   - Multiple line items and duplicate item lines
   - Real-world historical over-deduction reconciliation & idempotency
4. Quantity & Delta Formatter Invariants
   - Absolute elimination of "-0", "-0.0", "-0 kg"
"""

import os
import re
import sqlite3
import unittest
from decimal import Decimal, getcontext

# Set high decimal precision for micro/astronomical tests
getcontext().prec = 38

def convert_recipe_ingredient_qty_v1(qty, recipe_unit, product_unit, conversion_rate=0, conversion_unit=''):
    """
    Python mirror of public.convert_recipe_ingredient_qty_v1 in PostgreSQL.
    Follows exact logic in supabase/migrations/20261001_fix_recipe_unit_conversion_and_reconcile_stock.sql
    """
    if qty is None:
        return 0.0
    try:
        v_qty = float(qty)
    except (ValueError, TypeError):
        return 0.0

    if v_qty == 0.0:
        return 0.0

    v_r = (recipe_unit or '').strip().lower()
    v_p = (product_unit or '').strip().lower()
    v_c = (conversion_unit or '').strip().lower()
    try:
        v_rate = float(conversion_rate or 0)
    except (ValueError, TypeError):
        v_rate = 0.0

    # Vietnamese unit synonyms & normalization
    base_weight = {'g', 'gr', 'gram', 'gam', 'grm'}
    large_weight = {'kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo'}
    base_vol = {'ml', 'mililit', 'mililít', 'mili lit', 'mili lít', 'milliliter', 'cc'}
    large_vol = {'l', 'lit', 'lít', 'liter', 'litre'}

    if v_r in base_weight: v_r = 'g'
    if v_p in base_weight: v_p = 'g'
    if v_c in base_weight: v_c = 'g'

    if v_r in large_weight: v_r = 'kg'
    if v_p in large_weight: v_p = 'kg'
    if v_c in large_weight: v_c = 'kg'

    if v_r in base_vol: v_r = 'ml'
    if v_p in base_vol: v_p = 'ml'
    if v_c in base_vol: v_c = 'ml'

    if v_r in large_vol: v_r = 'lít'
    if v_p in large_vol: v_p = 'lít'
    if v_c in large_vol: v_c = 'lít'

    # 1. Identity match
    if v_r == v_p and v_r != '':
        return v_qty

    v_r_is_base = v_r in ('g', 'ml')
    v_r_is_large = v_r in ('kg', 'lít')
    v_p_is_base = v_p in ('g', 'ml')
    v_p_is_large = v_p in ('kg', 'lít')
    v_c_is_base = v_c in ('g', 'ml')
    v_c_is_large = v_c in ('kg', 'lít')

    # 2. Packaging specifications
    if v_rate > 0 and v_c != '':
        if v_r == v_p:
            return v_qty
        if (v_r == v_c) or (v_r_is_base and v_c_is_base):
            return v_qty / v_rate
        if v_r_is_large and v_c_is_base:
            return (v_qty * 1000.0) / v_rate
        if v_r_is_base and v_c_is_large:
            return (v_qty / 1000.0) / v_rate

    # 3. Metric conversions
    if v_r_is_base and v_p_is_large:
        return v_qty / 1000.0
    if v_r_is_large and v_p_is_base:
        return v_qty * 1000.0
    if (v_r_is_base and v_p_is_base) or (v_r_is_large and v_p_is_large):
        return v_qty

    # 4. Fallback guard
    return v_qty


def fmt_qty(v, max_decimals=3):
    """Reference implementation of fmtQty."""
    try:
        d = float(v)
    except (ValueError, TypeError):
        return '0'
    if abs(d) <= 1e-6:
        return '0'
    if d % 1 == 0:
        return str(int(d))
    s = f"{d:.{max_decimals}f}"
    if '.' in s:
        s = re.sub(r'0+$', '', s)
        s = re.sub(r'\.$', '', s)
    if s in ('-0', '-0.0', '-0.00', '', '-'):
        return '0'
    return s


def fmt_delta(delta, unit, max_decimals=3):
    """Reference implementation of fmtDelta."""
    try:
        d = float(delta)
    except (ValueError, TypeError):
        d = 0.0
    u = (unit or '').strip()
    suffix = f" {u}" if u else ""
    if abs(d) <= 1e-6:
        return f"0{suffix}"
    sign = '+' if d > 0 else '-'
    abs_str = fmt_qty(abs(d), max_decimals=max_decimals)
    if abs_str == '0':
        return f"0{suffix}"
    return f"{sign}{abs_str}{suffix}"


class TestAdversarialUnitConversionMath(unittest.TestCase):
    """Empirical adversarial challenge against convert_recipe_ingredient_qty_v1 mathematical edge cases"""

    def test_01_zero_and_none_quantities(self):
        """Zero quantity, None, and 0.0 must cleanly return 0.0 without errors"""
        self.assertEqual(convert_recipe_ingredient_qty_v1(0, 'ml', 'kg'), 0.0)
        self.assertEqual(convert_recipe_ingredient_qty_v1(0.0, 'g', 'kg'), 0.0)
        self.assertEqual(convert_recipe_ingredient_qty_v1('0', 'ml', 'lon', 385, 'ml'), 0.0)
        self.assertEqual(convert_recipe_ingredient_qty_v1(None, 'ml', 'kg'), 0.0)
        self.assertEqual(convert_recipe_ingredient_qty_v1('', 'ml', 'kg'), 0.0)

    def test_02_negative_quantities_preservation(self):
        """Negative quantity inputs (refunds, voids, return to stock) must preserve negative sign accurately"""
        # Milk: -20 ml -> -0.020 kg
        res = convert_recipe_ingredient_qty_v1(-20.0, 'ml', 'kg')
        self.assertAlmostEqual(res, -0.020, places=6)

        # Beans: -13 g -> -0.013 kg
        res = convert_recipe_ingredient_qty_v1(-13.0, 'g', 'kg')
        self.assertAlmostEqual(res, -0.013, places=6)

        # Cream: -15 g -> -0.015 lít
        res = convert_recipe_ingredient_qty_v1(-15.0, 'g', 'lít')
        self.assertAlmostEqual(res, -0.015, places=6)

        # Cans: -385 ml -> -1.0 lon
        res = convert_recipe_ingredient_qty_v1(-385.0, 'ml', 'lon', 385, 'ml')
        self.assertAlmostEqual(res, -1.0, places=6)

        # Cans fractional: -20 ml -> -20/385 lon
        res = convert_recipe_ingredient_qty_v1(-20.0, 'ml', 'lon', 385, 'ml')
        self.assertAlmostEqual(res, -20.0 / 385.0, places=6)

        # Large to base: -2.5 kg -> -2500 g
        res = convert_recipe_ingredient_qty_v1(-2.5, 'kg', 'g')
        self.assertAlmostEqual(res, -2500.0, places=6)

    def test_03_zero_and_negative_conversion_rates(self):
        """Zero or negative conversion rate must NOT trigger ZeroDivisionError and must gracefully fall back"""
        # conversion_rate = 0 -> fallback to raw qty
        res_zero = convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', 0, 'ml')
        self.assertEqual(res_zero, 20.0)

        # conversion_rate = -385 -> fallback to raw qty
        res_neg = convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', -385, 'ml')
        self.assertEqual(res_neg, 20.0)

        # conversion_rate = None -> fallback to raw qty
        res_none = convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', None, 'ml')
        self.assertEqual(res_none, 20.0)

        # Empty conversion_unit with positive rate -> fallback to raw qty
        res_empty_unit = convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', 385, '')
        self.assertEqual(res_empty_unit, 20.0)

    def test_04_incompatible_dimensions_fallback(self):
        """Incompatible dimensions (discrete vs continuous, count vs weight) must return raw quantity"""
        # cái -> kg
        self.assertEqual(convert_recipe_ingredient_qty_v1(3.0, 'cái', 'kg'), 3.0)
        # phần -> lít
        self.assertEqual(convert_recipe_ingredient_qty_v1(1.0, 'phần', 'lít'), 1.0)
        # quả -> g
        self.assertEqual(convert_recipe_ingredient_qty_v1(2.0, 'quả', 'g'), 2.0)
        # lon -> kg (without conversion rate)
        self.assertEqual(convert_recipe_ingredient_qty_v1(1.0, 'lon', 'kg'), 1.0)

    def test_05_casing_whitespace_and_vietnamese_aliases(self):
        """Case insensitivity, leading/trailing whitespace, and Vietnamese diacritics must normalize properly"""
        vectors = [
            (1000.0, "  GRAM  ", "  kG  ", 1.0),
            (500.0, "  gr  ", "  Ký  ", 0.5),
            (250.0, "  grm  ", "  kí  ", 0.25),
            (1.0, "  ki  ", "  g  ", 1000.0),
            (2.0, "  KILOGRAM  ", "  gam  ", 2000.0),
            (1000.0, "  mili lít  ", "  Lít  ", 1.0),
            (500.0, "  mililit  ", "  lit  ", 0.5),
            (250.0, "  mili lit  ", "  liter  ", 0.25),
            (100.0, "  cc  ", "  l  ", 0.1),
            (1.0, "  litre  ", "  ml  ", 1000.0),
            (20.0, "  ML  ", "  KG  ", 0.020),
            (15.0, "  G  ", "  LÍT  ", 0.015),
        ]
        for qty, r_unit, p_unit, expected in vectors:
            with self.subTest(qty=qty, r=r_unit, p=p_unit):
                res = convert_recipe_ingredient_qty_v1(qty, r_unit, p_unit)
                self.assertAlmostEqual(res, expected, places=5,
                                      msg=f"Failed conversion for {qty} '{r_unit}' -> '{p_unit}'")

    def test_06_micro_quantities(self):
        """Micro quantities (0.00005, 1e-6, 1e-8) must not suffer catastrophic underflow"""
        # 0.00005 kg into g -> 0.05 g
        res = convert_recipe_ingredient_qty_v1(0.00005, 'kg', 'g')
        self.assertAlmostEqual(res, 0.05, places=8)

        # 0.00005 g into kg -> 0.00000005 kg (5e-8)
        res = convert_recipe_ingredient_qty_v1(0.00005, 'g', 'kg')
        self.assertAlmostEqual(res, 0.00000005, places=10)

        # 1e-6 ml into lít -> 1e-9 lít
        res = convert_recipe_ingredient_qty_v1(1e-6, 'ml', 'lít')
        self.assertAlmostEqual(res, 1e-9, places=12)

    def test_07_astronomical_quantities(self):
        """Astronomical quantities (1e8, 1e9) must scale linearly without overflow or NaN"""
        # 1,000,000,000 g into kg -> 1,000,000 kg
        res = convert_recipe_ingredient_qty_v1(1e9, 'g', 'kg')
        self.assertAlmostEqual(res, 1e6, places=4)

        # 50,000,000 ml into lon (rate=385, unit='ml') -> 50,000,000 / 385
        res = convert_recipe_ingredient_qty_v1(5e7, 'ml', 'lon', 385, 'ml')
        self.assertAlmostEqual(res, 5e7 / 385.0, places=4)

    def test_08_packaging_conversions_edge_cases(self):
        """Packaging specifications must correctly convert across different dimension hierarchies"""
        # Base to packaging (20 ml -> 20/385 lon)
        res = convert_recipe_ingredient_qty_v1(20.0, 'ml', 'lon', 385, 'ml')
        self.assertAlmostEqual(res, 20.0 / 385.0, places=6)

        # Large to packaging base (0.385 lít -> 1.0 lon of 385 ml)
        res = convert_recipe_ingredient_qty_v1(0.385, 'lít', 'lon', 385, 'ml')
        self.assertAlmostEqual(res, 1.0, places=6)

        # Base to large packaging (1500 g -> 1.5 bao of 1 kg)
        res = convert_recipe_ingredient_qty_v1(1500.0, 'g', 'bao', 1.0, 'kg')
        self.assertAlmostEqual(res, 1.5, places=6)

        # Custom unit packaging: 5 cái -> 0.5 hộp of 10 cái
        res = convert_recipe_ingredient_qty_v1(5.0, 'cái', 'hộp', 10, 'cái')
        self.assertAlmostEqual(res, 0.5, places=6)

        # Identity when recipe unit matches product unit regardless of conversion rate
        res = convert_recipe_ingredient_qty_v1(2.0, 'lon', 'lon', 385, 'ml')
        self.assertEqual(res, 2.0)


class TestAdversarialRpcSqlAnalysis(unittest.TestCase):
    """Static and semantic audit of SQL migration and PostgreSQL RPC contracts"""

    @classmethod
    def setUpClass(cls):
        cls.repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        cls.migration_path = os.path.join(
            cls.repo_root,
            "supabase/migrations/20261001_fix_recipe_unit_conversion_and_reconcile_stock.sql"
        )
        cls.assertTrue(os.path.isfile(cls.migration_path), f"Missing migration file: {cls.migration_path}")
        with open(cls.migration_path, "r", encoding="utf-8") as f:
            cls.migration_content = f.read()

    def test_01_migration_file_hygiene(self):
        """Migration file must have valid 0x0A newline, balanced $$ blocks, and begin/commit transaction"""
        with open(self.migration_path, "rb") as f:
            raw = f.read()
            self.assertTrue(raw.endswith(b"\n"), "Migration file must end with standard 0x0A newline")

        dollar_count = self.migration_content.count("$$")
        self.assertEqual(dollar_count % 2, 0, f"Unbalanced $$ blocks: {dollar_count}")
        self.assertIn("BEGIN;", self.migration_content)
        self.assertIn("COMMIT;", self.migration_content)

    def test_02_convert_recipe_ingredient_qty_v1_signature(self):
        """convert_recipe_ingredient_qty_v1 must be declared IMMUTABLE and accept 5 parameters"""
        func_match = re.search(
            r"CREATE OR REPLACE FUNCTION public\.convert_recipe_ingredient_qty_v1\s*\(([\s\S]*?)\)[\s\S]*?RETURNS numeric[\s\S]*?IMMUTABLE",
            self.migration_content
        )
        self.assertIsNotNone(func_match, "convert_recipe_ingredient_qty_v1 must exist, return numeric, and be IMMUTABLE")
        params = func_match.group(1)
        self.assertIn("p_qty numeric", params)
        self.assertIn("p_recipe_unit text", params)
        self.assertIn("p_product_unit text", params)
        self.assertIn("p_conversion_rate numeric", params)
        self.assertIn("p_conversion_unit text", params)

    def test_03_complete_pos_sale_v1_non_recipe_and_yield_factor(self):
        """complete_pos_sale_v1 must handle retail items (no recipe) and safely guard yield_factor <= 0"""
        pos_chunk = self.migration_content[self.migration_content.find("FUNCTION public.complete_pos_sale_v1"):]
        pos_chunk = pos_chunk[:pos_chunk.find("CREATE OR REPLACE FUNCTION public.settle_ban_session_v5")]

        # 1. Check table existence verification
        self.assertIn("information_schema.tables", pos_chunk)
        self.assertIn("recipes", pos_chunk)
        self.assertIn("recipe_ingredients", pos_chunk)

        # 2. Check retail items branch (v_has_recipe = false)
        self.assertIn("INSERT INTO public.stock_movements", pos_chunk)
        self.assertIn("'sale'", pos_chunk, "Retail products without recipe must insert stock_movements with reason='sale'")
        self.assertIn("-v_qty", pos_chunk, "Retail products must deduct -v_qty")

        # 3. Check yield factor safe division
        yield_guard = re.search(
            r"v_rec_ing\.quantity\s*/\s*CASE\s+WHEN\s+v_rec_ing\.yield_factor\s+IS\s+NULL\s+OR\s+v_rec_ing\.yield_factor\s*<=\s*0\s+THEN\s+1\.0\s+ELSE\s+v_rec_ing\.yield_factor\s+END",
            pos_chunk
        )
        self.assertIsNotNone(yield_guard, "complete_pos_sale_v1 must guard against zero or negative yield factor")

        # 4. Check convert_recipe_ingredient_qty_v1 invocation
        self.assertIn("public.convert_recipe_ingredient_qty_v1(", pos_chunk)
        self.assertIn("'recipe_usage'", pos_chunk)

    def test_04_settle_ban_session_v5_branching(self):
        """settle_ban_session_v5 must handle dishes & toppings with and without recipes"""
        settle_chunk = self.migration_content[self.migration_content.find("FUNCTION public.settle_ban_session_v5"):]

        # Dish without recipe
        self.assertIn("-v_item.quantity", settle_chunk)
        self.assertIn("'Bán hàng bàn '", settle_chunk)

        # Dish with recipe
        self.assertIn("v_actual_ing_qty := public.convert_recipe_ingredient_qty_v1(", settle_chunk)
        self.assertIn("'Xuất kho công thức bàn '", settle_chunk)

        # Topping / Modifier handling
        self.assertIn("v_item.modifiers_json", settle_chunk)
        self.assertIn("'Xuất kho topping công thức bàn '", settle_chunk)
        self.assertIn("'Bán topping bàn '", settle_chunk)

    def test_05_reconciliation_append_only_and_idempotent(self):
        """Reconciliation migration must be strictly APPEND-ONLY (no DELETE) and idempotent"""
        rec_chunk = self.migration_content[self.migration_content.find("reconcile_erroneous_recipe_orders_v1"):]

        # APPEND-ONLY check: No DELETE or UPDATE on old stock movements
        self.assertFalse(
            re.search(r"DELETE\s+FROM\s+(?:public\.)?stock_movements", self.migration_content, re.IGNORECASE),
            "Violation: stock_movements must be strictly APPEND-ONLY (found DELETE)"
        )

        # Target order numbers
        self.assertIn("QN-20260930-002", rec_chunk)
        self.assertIn("QN-20260930-003", rec_chunk)
        self.assertIn("QN-20261001-001", rec_chunk)

        # Idempotency guard check
        self.assertIn("v_already_reconciled", rec_chunk)
        self.assertIn("reason = 'reconciliation'", rec_chunk)

        # Specific refund constants
        self.assertIn("19.980", rec_chunk, "Sữa đặc refund must be 19.980 kg")
        self.assertIn("12.987", rec_chunk, "Cà phê hạt refund must be 12.987 kg")
        self.assertIn("14.985", rec_chunk, "Bột kem muối refund must be 14.985 kg")


class TestAdversarialDatabaseSimulation(unittest.TestCase):
    """In-memory SQLite simulation of PostgreSQL tables and stock deduction behavior"""

    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.cursor = self.conn.cursor()
        self._init_schema()

    def tearDown(self):
        self.conn.close()

    def _init_schema(self):
        self.cursor.executescript("""
            CREATE TABLE products (
                id TEXT PRIMARY KEY,
                store_id TEXT NOT NULL,
                name TEXT NOT NULL,
                unit TEXT NOT NULL,
                stock_qty REAL DEFAULT 0,
                conversion_rate REAL DEFAULT 0,
                conversion_unit TEXT DEFAULT '',
                sell_price REAL DEFAULT 0,
                is_active INTEGER DEFAULT 1,
                is_deleted INTEGER DEFAULT 0
            );

            CREATE TABLE recipes (
                id TEXT PRIMARY KEY,
                store_id TEXT NOT NULL,
                name TEXT NOT NULL,
                pos_product_id TEXT NOT NULL,
                serving_size REAL DEFAULT 1,
                is_active INTEGER DEFAULT 1,
                is_deleted INTEGER DEFAULT 0
            );

            CREATE TABLE recipe_ingredients (
                id TEXT PRIMARY KEY,
                recipe_id TEXT NOT NULL,
                ingredient_id TEXT NOT NULL,
                quantity REAL NOT NULL,
                unit TEXT NOT NULL,
                yield_factor REAL DEFAULT 1.0
            );

            CREATE TABLE stock_movements (
                id TEXT PRIMARY KEY,
                store_id TEXT NOT NULL,
                product_id TEXT NOT NULL,
                delta REAL NOT NULL,
                reason TEXT NOT NULL,
                reference_id TEXT,
                note TEXT,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE orders (
                id TEXT PRIMARY KEY,
                store_id TEXT NOT NULL,
                order_number TEXT NOT NULL
            );
        """)

    def _simulate_pos_sale(self, store_id, order_id, order_number, lines):
        """Simulate the stock deduction loop of complete_pos_sale_v1"""
        for line in lines:
            prod_id = line['product_id']
            qty = float(line['quantity'])

            # Check if product has an active recipe
            self.cursor.execute("""
                SELECT r.id FROM recipes r
                JOIN recipe_ingredients ri ON ri.recipe_id = r.id
                WHERE r.pos_product_id = ? AND r.is_deleted = 0
                LIMIT 1
            """, (prod_id,))
            recipe_row = self.cursor.fetchone()

            if recipe_row:
                # Deduct ingredients
                self.cursor.execute("""
                    SELECT ri.ingredient_id, ri.quantity, ri.yield_factor, ri.unit,
                           p.unit, p.conversion_rate, p.conversion_unit, p.name
                    FROM recipe_ingredients ri
                    LEFT JOIN products p ON p.id = ri.ingredient_id AND p.store_id = ?
                    WHERE ri.recipe_id = ?
                """, (store_id, recipe_row[0]))
                ingredients = self.cursor.fetchall()

                for ing in ingredients:
                    ing_id, ri_qty, y_factor, r_unit, p_unit, conv_rate, conv_unit, p_name = ing
                    effective_yield = 1.0 if (y_factor is None or y_factor <= 0) else y_factor
                    gross_qty = (ri_qty / effective_yield) * qty
                    actual_qty = convert_recipe_ingredient_qty_v1(
                        gross_qty, r_unit, p_unit, conv_rate, conv_unit
                    )

                    # Insert stock movement
                    self.cursor.execute("""
                        INSERT INTO stock_movements (id, store_id, product_id, delta, reason, reference_id, note)
                        VALUES (?, ?, ?, ?, 'recipe_usage', ?, ?)
                    """, (f"mov-{prod_id}-{ing_id}", store_id, ing_id, -actual_qty, order_id, f"POS công thức #{order_number}: {p_name}"))

                    # Update product stock
                    self.cursor.execute("""
                        UPDATE products SET stock_qty = stock_qty - ? WHERE id = ? AND store_id = ?
                    """, (actual_qty, ing_id, store_id))
            else:
                # Retail item without recipe
                self.cursor.execute("""
                    INSERT INTO stock_movements (id, store_id, product_id, delta, reason, reference_id, note)
                    VALUES (?, ?, ?, ?, 'sale', ?, ?)
                """, (f"mov-{prod_id}-sale", store_id, prod_id, -qty, order_id, f"POS bán hàng #{order_number}"))

                self.cursor.execute("""
                    UPDATE products SET stock_qty = stock_qty - ? WHERE id = ? AND store_id = ?
                """, (qty, prod_id, store_id))

    def test_01_retail_product_without_recipe(self):
        """Retail product without recipe must decrease stock by exact sold quantity with reason='sale'"""
        store_id = "store-1"
        self.cursor.execute("""
            INSERT INTO products (id, store_id, name, unit, stock_qty)
            VALUES ('prod-coke', 'store-1', 'Coca Cola', 'lon', 50.0)
        """)

        self._simulate_pos_sale(store_id, "ord-1", "QN-001", [
            {'product_id': 'prod-coke', 'quantity': 3}
        ])

        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'prod-coke'")
        stock = self.cursor.fetchone()[0]
        self.assertEqual(stock, 47.0)

        self.cursor.execute("SELECT delta, reason FROM stock_movements WHERE product_id = 'prod-coke'")
        mov = self.cursor.fetchone()
        self.assertEqual(mov[0], -3.0)
        self.assertEqual(mov[1], 'sale')

    def test_02_cafe_muoi_multi_unit_recipe_deduction(self):
        """Cafe Muoi sale must deduct 0.020 kg Milk, 0.013 kg Beans, 0.015 lít Cream"""
        store_id = "store-1"
        # Create ingredients
        self.cursor.execute("INSERT INTO products VALUES ('ing-milk', 'store-1', 'Sữa đặc', 'kg', 10.0, 0, '', 0, 1, 0)")
        self.cursor.execute("INSERT INTO products VALUES ('ing-beans', 'store-1', 'Cà phê hạt', 'kg', 5.0, 0, '', 0, 1, 0)")
        self.cursor.execute("INSERT INTO products VALUES ('ing-cream', 'store-1', 'Bột kem muối', 'lít', 2.0, 0, '', 0, 1, 0)")
        # Create POS product
        self.cursor.execute("INSERT INTO products VALUES ('pos-cafe', 'store-1', 'Cà phê muối', 'ly', 0, 0, '', 35000, 1, 0)")

        # Create recipe
        self.cursor.execute("INSERT INTO recipes VALUES ('rec-cafe', 'store-1', 'Công thức Cafe Muối', 'pos-cafe', 1, 1, 0)")
        self.cursor.execute("INSERT INTO recipe_ingredients VALUES ('ri-1', 'rec-cafe', 'ing-milk', 20.0, 'ml', 1.0)")
        self.cursor.execute("INSERT INTO recipe_ingredients VALUES ('ri-2', 'rec-cafe', 'ing-beans', 13.0, 'g', 1.0)")
        self.cursor.execute("INSERT INTO recipe_ingredients VALUES ('ri-3', 'rec-cafe', 'ing-cream', 15.0, 'g', 1.0)")

        # Sell 1 cup
        self._simulate_pos_sale(store_id, "ord-100", "QN-100", [
            {'product_id': 'pos-cafe', 'quantity': 1}
        ])

        # Verify stock
        self.cursor.execute("SELECT id, stock_qty FROM products WHERE id LIKE 'ing-%' ORDER BY id")
        stocks = dict(self.cursor.fetchall())
        self.assertAlmostEqual(stocks['ing-milk'], 9.980, places=4)
        self.assertAlmostEqual(stocks['ing-beans'], 4.987, places=4)
        self.assertAlmostEqual(stocks['ing-cream'], 1.985, places=4)

    def test_03_zero_and_negative_yield_factor_defense(self):
        """Zero or negative yield factor in recipe must clamp to 1.0 without crashing or inflating deduction"""
        store_id = "store-1"
        self.cursor.execute("INSERT INTO products VALUES ('ing-tea', 'store-1', 'Trà đen', 'kg', 10.0, 0, '', 0, 1, 0)")
        self.cursor.execute("INSERT INTO products VALUES ('pos-tea', 'store-1', 'Trà đá', 'ly', 0, 0, '', 10000, 1, 0)")
        self.cursor.execute("INSERT INTO recipes VALUES ('rec-tea', 'store-1', 'Công thức Trà', 'pos-tea', 1, 1, 0)")

        # yield_factor = 0 (adversarial case)
        self.cursor.execute("INSERT INTO recipe_ingredients VALUES ('ri-tea', 'rec-tea', 'ing-tea', 10.0, 'g', 0.0)")

        # Sell 1 cup -> 10 g / 1.0 = 10 g -> 0.010 kg deducted
        self._simulate_pos_sale(store_id, "ord-tea", "QN-TEA", [
            {'product_id': 'pos-tea', 'quantity': 1}
        ])

        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'ing-tea'")
        stock = self.cursor.fetchone()[0]
        self.assertAlmostEqual(stock, 9.990, places=4)

    def test_04_multiple_lines_mixed_with_and_without_recipe(self):
        """Order containing multiple items (recipe items + retail items) must deduct all accurately"""
        store_id = "store-1"
        self.cursor.execute("INSERT INTO products VALUES ('ing-milk', 'store-1', 'Sữa đặc', 'kg', 10.0, 0, '', 0, 1, 0)")
        self.cursor.execute("INSERT INTO products VALUES ('pos-cafe', 'store-1', 'Cà phê muối', 'ly', 0, 0, '', 35000, 1, 0)")
        self.cursor.execute("INSERT INTO products VALUES ('prod-snack', 'store-1', 'Snack khoai tây', 'gói', 20.0, 0, '', 15000, 1, 0)")

        self.cursor.execute("INSERT INTO recipes VALUES ('rec-cafe', 'store-1', 'CT Cafe', 'pos-cafe', 1, 1, 0)")
        self.cursor.execute("INSERT INTO recipe_ingredients VALUES ('ri-milk', 'rec-cafe', 'ing-milk', 20.0, 'ml', 1.0)")

        # Cart: 2 cups of Cafe Muoi (Line 1) + 3 Snack bags (Line 2)
        self._simulate_pos_sale(store_id, "ord-mix", "QN-MIX", [
            {'product_id': 'pos-cafe', 'quantity': 2},
            {'product_id': 'prod-snack', 'quantity': 3},
        ])

        # Sữa đặc: 10.0 - (2 * 0.020) = 9.960 kg
        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'ing-milk'")
        self.assertAlmostEqual(self.cursor.fetchone()[0], 9.960, places=4)

        # Snack: 20.0 - 3 = 17.0 gói
        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'prod-snack'")
        self.assertEqual(self.cursor.fetchone()[0], 17.0)

    def test_05_reconciliation_simulation_and_idempotency(self):
        """Simulate over-deducted historical orders, execute reconciliation, verify idempotency on second pass"""
        store_id = "store-1"
        self.cursor.execute("INSERT INTO products VALUES ('ing-milk', 'store-1', 'Sữa đặc', 'kg', 50.0, 0, '', 0, 1, 0)")
        self.cursor.execute("INSERT INTO products VALUES ('ing-beans', 'store-1', 'Cà phê hạt', 'kg', 50.0, 0, '', 0, 1, 0)")
        self.cursor.execute("INSERT INTO products VALUES ('ing-cream', 'store-1', 'Bột kem muối', 'lít', 50.0, 0, '', 0, 1, 0)")

        # Create historical corrupted records for orders 002, 003, 001 (deducted 20, 13, 15 instead of 0.02, 0.013, 0.015)
        corrupted_orders = ['QN-20260930-002', 'QN-20260930-003', 'QN-20261001-001']
        for ord_num in corrupted_orders:
            ord_id = f"ord-{ord_num}"
            self.cursor.execute("INSERT INTO orders VALUES (?, ?, ?)", (ord_id, store_id, f"#{ord_num}"))
            # Sữa đặc over-deducted -20 kg
            self.cursor.execute("INSERT INTO stock_movements VALUES (?, ?, 'ing-milk', -20.0, 'recipe_usage', ?, ?, CURRENT_TIMESTAMP)",
                                (f"sm-{ord_num}-milk", store_id, ord_id, f"POS công thức #{ord_num}: Cà phê muối"))
            # Cà phê over-deducted -13 kg
            self.cursor.execute("INSERT INTO stock_movements VALUES (?, ?, 'ing-beans', -13.0, 'recipe_usage', ?, ?, CURRENT_TIMESTAMP)",
                                (f"sm-{ord_num}-beans", store_id, ord_id, f"POS công thức #{ord_num}: Cà phê muối"))
            # Bột kem over-deducted -15 kg
            self.cursor.execute("INSERT INTO stock_movements VALUES (?, ?, 'ing-cream', -15.0, 'recipe_usage', ?, ?, CURRENT_TIMESTAMP)",
                                (f"sm-{ord_num}-cream", store_id, ord_id, f"POS công thức #{ord_num}: Cà phê muối"))

        # Deplete stocks by 3 x (20, 13, 15)
        self.cursor.execute("UPDATE products SET stock_qty = stock_qty - 60.0 WHERE id = 'ing-milk'")  # 50 - 60 = -10
        self.cursor.execute("UPDATE products SET stock_qty = stock_qty - 39.0 WHERE id = 'ing-beans'") # 50 - 39 = 11
        self.cursor.execute("UPDATE products SET stock_qty = stock_qty - 45.0 WHERE id = 'ing-cream'") # 50 - 45 = 5

        # Reconciliation Function implementation in Python
        def run_reconciliation():
            reconciled = 0
            for ord_n in corrupted_orders:
                clean_n = ord_n
                self.cursor.execute("""
                    SELECT sm.id, sm.product_id, sm.delta, sm.reference_id, p.name
                    FROM stock_movements sm
                    JOIN products p ON p.id = sm.product_id
                    WHERE sm.store_id = ? AND sm.reason = 'recipe_usage'
                      AND sm.note LIKE ? AND sm.delta < -1.0
                """, (store_id, f"%{clean_n}%"))
                rows = self.cursor.fetchall()
                for row in rows:
                    sm_id, p_id, delta, ref_id, p_name = row
                    # Idempotency check
                    self.cursor.execute("""
                        SELECT 1 FROM stock_movements
                        WHERE store_id = ? AND product_id = ?
                          AND (reference_id = ? OR note LIKE ?)
                          AND reason = 'reconciliation'
                    """, (store_id, p_id, ref_id, f"%{clean_n}%"))
                    if not self.cursor.fetchone():
                        if delta == -20.0:
                            refund = 19.980
                        elif delta == -13.0:
                            refund = 12.987
                        elif delta == -15.0:
                            refund = 14.985
                        else:
                            refund = abs(delta) - (abs(delta) / 1000.0)

                        self.cursor.execute("""
                            INSERT INTO stock_movements (id, store_id, product_id, delta, reason, reference_id, note)
                            VALUES (?, ?, ?, ?, 'reconciliation', ?, ?)
                        """, (f"rec-{sm_id}", store_id, p_id, refund, ref_id, f"Bù hoàn #{clean_n}: {p_name} (+{refund})"))
                        self.cursor.execute("UPDATE products SET stock_qty = stock_qty + ? WHERE id = ?", (refund, p_id))
                        reconciled += 1
            return reconciled

        # Pass 1: Run reconciliation
        count_pass1 = run_reconciliation()
        self.assertEqual(count_pass1, 9, "Pass 1 must reconcile exactly 9 line movements (3 items x 3 orders)")

        # Verify restored stock:
        # Milk: -10 + (3 * 19.980) = -10 + 59.940 = 49.940 (original 50 - 3 * 0.020)
        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'ing-milk'")
        self.assertAlmostEqual(self.cursor.fetchone()[0], 49.940, places=4)

        # Beans: 11 + (3 * 12.987) = 11 + 38.961 = 49.961 (original 50 - 3 * 0.013)
        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'ing-beans'")
        self.assertAlmostEqual(self.cursor.fetchone()[0], 49.961, places=4)

        # Cream: 5 + (3 * 14.985) = 5 + 44.955 = 49.955 (original 50 - 3 * 0.015)
        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'ing-cream'")
        self.assertAlmostEqual(self.cursor.fetchone()[0], 49.955, places=4)

        # Pass 2: Re-run reconciliation (Idempotency Recheck)
        count_pass2 = run_reconciliation()
        self.assertEqual(count_pass2, 0, "Pass 2 must reconcile 0 movements (Idempotent invariant)")

        # Stock must NOT change
        self.cursor.execute("SELECT stock_qty FROM products WHERE id = 'ing-milk'")
        self.assertAlmostEqual(self.cursor.fetchone()[0], 49.940, places=4)


class TestAdversarialFormatterAndDartInvariants(unittest.TestCase):
    """Stress-testing fmtQty and fmtDelta formatting invariants to guarantee absolute anti '-0' behavior"""

    def test_01_fmt_qty_anti_zero_invariants(self):
        """fmtQty must never produce '-0', '-0.0', or trailing zero decimals"""
        test_cases = [
            (0, "0"),
            (0.0, "0"),
            (-0.0, "0"),
            (-0, "0"),
            (0.0000001, "0"),
            (-0.0000001, "0"),
            (5, "5"),
            (5.0, "5"),
            (-5, "-5"),
            (0.02, "0.02"),
            (-0.02, "-0.02"),
            (0.015, "0.015"),
            (-0.015, "-0.015"),
            (4.985, "4.985"),
            (4.980, "4.98"),
            (50.000, "50"),
        ]
        for val, expected in test_cases:
            with self.subTest(val=val):
                res = fmt_qty(val)
                self.assertEqual(res, expected, f"fmt_qty({val}) returned '{res}', expected '{expected}'")

    def test_02_fmt_delta_anti_zero_invariants(self):
        """fmtDelta must never produce '-0 kg' or '-0.0 kg'"""
        test_cases = [
            (0, "kg", "0 kg"),
            (0.0, "kg", "0 kg"),
            (-0.0, "kg", "0 kg"),
            (0.0000001, "kg", "0 kg"),
            (-0.0000001, "kg", "0 kg"),
            (0.02, "kg", "+0.02 kg"),
            (-0.02, "kg", "-0.02 kg"),
            (0.013, "kg", "+0.013 kg"),
            (-0.013, "kg", "-0.013 kg"),
            (-20, "kg", "-20 kg"),
            (19.980, "kg", "+19.98 kg"),
            (5, "", "+5"),
            (-5, "", "-5"),
            (0, "", "0"),
        ]
        for delta, unit, expected in test_cases:
            with self.subTest(delta=delta, unit=unit):
                res = fmt_delta(delta, unit)
                self.assertEqual(res, expected, f"fmt_delta({delta}, '{unit}') returned '{res}', expected '{expected}'")


if __name__ == '__main__':
    unittest.main()
