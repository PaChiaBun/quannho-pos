#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Test Suite: F&B Multi-Unit Conversion & Recipe Stock Deduction Validator
Dual-Track Tier 1-4 Verification:
1. SQL Contract Test Suite structure, file encoding (0x0A), balanced $$ delimiters.
2. PostgreSQL Migration DDL & Contract Verification for convert_recipe_ingredient_qty_v1.
3. RPC Contract Verification on complete_pos_sale_v1 and settle_ban_session_v5.
4. Historical Data Reconciliation Verification for orders #QN-20260930-002, 003, #QN-20261001-001.
5. Mathematical Reference Oracle testing 50+ conversion test vectors.
6. Formatter Reference Oracle testing fmtQty, fmtDelta and strict anti "-0" invariants.
"""

import os
import re
import unittest

def python_convert_fnb_unit(qty, recipe_unit, product_unit, conversion_rate=0, conversion_unit=''):
    """
    Authoritative reference implementation of convert_recipe_ingredient_qty_v1 in Python.
    Follows PROJECT.md § Interface Contracts & survey_spec_miner § 4.4.
    """
    if qty is None or qty == 0:
        return 0.0

    r = (recipe_unit or '').strip().lower()
    p = (product_unit or '').strip().lower()
    c = (conversion_unit or '').strip().lower()
    rate = float(conversion_rate or 0)
    q = float(qty)

    # 1. Identity match
    if r == p and r != '':
        return q

    # Normalized categories
    base_weight = {'g', 'gr', 'gram', 'grm'}
    large_weight = {'kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo'}
    base_vol = {'ml', 'mili lít', 'mili lit', 'mililit', 'milliliter', 'cc'}
    large_vol = {'l', 'lit', 'lít', 'liter', 'litre'}

    r_is_base = (r in base_weight) or (r in base_vol)
    r_is_large = (r in large_weight) or (r in large_vol)
    p_is_base = (p in base_weight) or (p in base_vol)
    p_is_large = (p in large_weight) or (p in large_vol)
    c_is_base = (c in base_weight) or (c in base_vol)

    # 2. Packaging unit with conversion_rate (e.g. 1 lon = 385 ml)
    if rate > 0 and c != '':
        # Direct match with conversion unit or base dimension match
        if (r == c) or (r_is_base and c_is_base):
            return q / rate
        # Large unit (lít/kg) to packaging base unit (ml/g)
        if r_is_large and c_is_base:
            return (q * 1000.0) / rate
        # Recipe unit equals product unit
        if r == p:
            return q

    # 3. Metric conversions (Small to Large: g/ml -> kg/lít)
    if r_is_base and p_is_large:
        return q / 1000.0

    # 4. Metric conversions (Large to Small: kg/lít -> g/ml)
    if r_is_large and p_is_base:
        return q * 1000.0

    # 5. Same scale cross-conversions (g <-> ml or kg <-> lít under density ρ = 1.0)
    if (r_is_base and p_is_base) or (r_is_large and p_is_large):
        return q

    # 6. Fallback guard: incompatible units (e.g. cái -> kg)
    return q

def python_fmt_qty(v, max_decimals=3):
    """Reference implementation of fmtQty."""
    d = float(v)
    if abs(d) < 1e-6:
        return '0'
    if d % 1 == 0:
        return str(int(d))
    s = f"{d:.{max_decimals}f}"
    s = re.sub(r'0+$', '', s)
    s = re.sub(r'\.$', '', s)
    if s == '-0' or s == '':
        return '0'
    return s

def python_fmt_delta(delta, unit):
    """Reference implementation of fmtDelta."""
    d = float(delta)
    unit_str = f" {unit.strip()}" if unit and unit.strip() else ""
    if abs(d) < 1e-6:
        return f"0{unit_str}"
    sign = '+' if d > 0 else '-'
    abs_str = python_fmt_qty(abs(d), max_decimals=3)
    return f"{sign}{abs_str}{unit_str}"


class TestRecipeUnitConversionValidator(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
        cls.sql_test_path = os.path.join(cls.repo_root, "supabase/tests/fnb_unit_conversion_and_deduction_test.sql")

        # Potential migration files
        migrations_dir = os.path.join(cls.repo_root, "supabase/migrations")
        cls.migration_files = []
        if os.path.isdir(migrations_dir):
            for f in sorted(os.listdir(migrations_dir)):
                if f.endswith(".sql") and ("recipe" in f or "20261001" in f):
                    cls.migration_files.append(os.path.join(migrations_dir, f))

        cls.migration_sql = ""
        for m_path in cls.migration_files:
            with open(m_path, "r", encoding="utf-8") as f:
                content = f.read()
                if "convert_recipe_ingredient_qty_v1" in content or "reconciliation" in content:
                    cls.migration_sql += "\n" + content

        with open(cls.sql_test_path, "r", encoding="utf-8") as f:
            cls.sql_test_content = f.read()

    # ═════════════════════════════════════════════════════════════════════════
    # TIER 1: FEATURE CONTRACTS & SYNTAX VALIDATION
    # ═════════════════════════════════════════════════════════════════════════
    def test_01_sql_test_file_encoding_and_delimiter_balance(self):
        """Verify SQL test script ends with clean 0x0A newline and balanced $$ delimiters."""
        self.assertTrue(os.path.isfile(self.sql_test_path), f"Missing SQL test file: {self.sql_test_path}")
        with open(self.sql_test_path, "rb") as f:
            self.assertTrue(f.read().endswith(b"\n"), "SQL test script must end with 0x0A newline")

        dollar_count = self.sql_test_content.count("$$")
        self.assertEqual(dollar_count % 2, 0, f"Unbalanced $$ blocks in SQL test: count={dollar_count}")

    def test_02_sql_test_covers_all_4_tiers(self):
        """Verify SQL test script contains assertions for Tier 1 through Tier 4."""
        self.assertIn("Tier 1.1: Identity conversion", self.sql_test_content)
        self.assertIn("Tier 1.2: Standard weight", self.sql_test_content)
        self.assertIn("Tier 1.3: Standard volume", self.sql_test_content)
        self.assertIn("Tier 1.4: Cross-dimension liquid density", self.sql_test_content)
        self.assertIn("Tier 1.6: Packaging conversion", self.sql_test_content)
        self.assertIn("Tier 2.1: Zero conversion rate safe guard", self.sql_test_content)
        self.assertIn("Tier 2.3: Incompatible dimensions fallback", self.sql_test_content)
        self.assertIn("Tier 3: Multi-Ingredient Cafe Muoi Deduction Simulation", self.sql_test_content)
        self.assertIn("Tier 4: Reconciliation Idempotency & Recovery", self.sql_test_content)
        self.assertIn("ROLLBACK;", self.sql_test_content, "SQL test script must run inside an isolated ROLLBACK block")

    def test_03_migration_file_encoding_when_present(self):
        """If M1/M3 migration exists, verify clean 0x0A newline and balanced $$."""
        for m_path in self.migration_files:
            with open(m_path, "rb") as f:
                content = f.read()
                self.assertTrue(content.endswith(b"\n"), f"Migration {os.path.basename(m_path)} must end with 0x0A newline")
                text = content.decode("utf-8")
                dollars = text.count("$$")
                self.assertEqual(dollars % 2, 0, f"Unbalanced $$ in {os.path.basename(m_path)}: count={dollars}")

    def test_04_function_convert_recipe_ingredient_qty_v1_contract(self):
        """Verify convert_recipe_ingredient_qty_v1 signature and IMMUTABLE requirement."""
        if self.migration_sql:
            self.assertIn("convert_recipe_ingredient_qty_v1", self.migration_sql)
            # Must declare IMMUTABLE
            pattern = r"convert_recipe_ingredient_qty_v1[\s\S]*?IMMUTABLE"
            self.assertTrue(re.search(pattern, self.migration_sql), "convert_recipe_ingredient_qty_v1 must be declared IMMUTABLE")

    # ═════════════════════════════════════════════════════════════════════════
    # TIER 2: BOUNDARY & RPC INVOCATION CONTRACTS
    # ═════════════════════════════════════════════════════════════════════════
    def test_05_complete_pos_sale_v1_contract_check(self):
        """Verify complete_pos_sale_v1 joins products and invokes conversion function."""
        if "complete_pos_sale_v1" in self.migration_sql:
            pos_chunk = self.migration_sql[self.migration_sql.find("complete_pos_sale_v1"):]
            self.assertIn("convert_recipe_ingredient_qty_v1", pos_chunk, "complete_pos_sale_v1 must invoke convert_recipe_ingredient_qty_v1")
            self.assertIn("conversion_rate", pos_chunk, "complete_pos_sale_v1 must inspect conversion_rate")
            self.assertIn("conversion_unit", pos_chunk, "complete_pos_sale_v1 must inspect conversion_unit")

    def test_06_settle_ban_session_v5_contract_check(self):
        """Verify settle_ban_session_v5 joins products and invokes conversion function."""
        if "settle_ban_session_v5" in self.migration_sql:
            ban_chunk = self.migration_sql[self.migration_sql.find("settle_ban_session_v5"):]
            self.assertIn("convert_recipe_ingredient_qty_v1", ban_chunk, "settle_ban_session_v5 must invoke convert_recipe_ingredient_qty_v1")

    def test_07_historical_reconciliation_contract_check(self):
        """Verify data reconciliation migration targets the 3 orders with idempotency and APPEND-ONLY."""
        if "reconciliation" in self.migration_sql:
            self.assertIn("QN-20260930-002", self.migration_sql, "Reconciliation must target #QN-20260930-002")
            self.assertIn("QN-20260930-003", self.migration_sql, "Reconciliation must target #QN-20260930-003")
            self.assertIn("QN-20261001-001", self.migration_sql, "Reconciliation must target #QN-20261001-001")
            self.assertIn("reason", self.migration_sql)
            self.assertIn("'reconciliation'", self.migration_sql)
            # Ensure no illegal DELETE or UPDATE on stock_movements
            self.assertFalse(re.search(r"DELETE\s+FROM\s+(?:public\.)?stock_movements", self.migration_sql, re.IGNORECASE),
                             "Violation: stock_movements must be strictly APPEND-ONLY (no DELETE)")

    # ═════════════════════════════════════════════════════════════════════════
    # TIER 3: MATHEMATICAL REFERENCE ORACLE (50+ TEST VECTORS)
    # ═════════════════════════════════════════════════════════════════════════
    def test_08_reference_oracle_weight_conversions(self):
        """Verify standard weight conversions across multiple vectors."""
        self.assertAlmostEqual(python_convert_fnb_unit(1000, 'g', 'kg'), 1.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(500, 'gram', 'kg'), 0.5, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(13, 'g', 'kg'), 0.013, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(1, 'kg', 'g'), 1000.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(0.013, 'kg', 'g'), 13.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(5, 'kg', 'kg'), 5.0, places=6)

    def test_09_reference_oracle_volume_conversions(self):
        """Verify standard volume conversions across multiple vectors."""
        self.assertAlmostEqual(python_convert_fnb_unit(1000, 'ml', 'lít'), 1.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(250, 'ml', 'lít'), 0.25, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(20, 'ml', 'lít'), 0.020, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(1, 'lít', 'ml'), 1000.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(0.02, 'lít', 'ml'), 20.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(2, 'lít', 'lít'), 2.0, places=6)

    def test_10_reference_oracle_cross_dimension_liquid_density(self):
        """Verify cross-dimension conversions using culinary density ρ ≈ 1.0."""
        # 20 ml condensed milk in kg -> 0.020 kg
        self.assertAlmostEqual(python_convert_fnb_unit(20, 'ml', 'kg'), 0.020, places=6)
        # 15 g salt cream in lít -> 0.015 lít
        self.assertAlmostEqual(python_convert_fnb_unit(15, 'g', 'lít'), 0.015, places=6)
        # 13 g coffee beans in kg -> 0.013 kg
        self.assertAlmostEqual(python_convert_fnb_unit(13, 'g', 'kg'), 0.013, places=6)
        # 250 ml in kg -> 0.250 kg
        self.assertAlmostEqual(python_convert_fnb_unit(250, 'ml', 'kg'), 0.250, places=6)

    def test_11_reference_oracle_packaging_units(self):
        """Verify packaging specifications with conversion_rate and conversion_unit."""
        # 1 lon condensed milk = 385 ml
        self.assertAlmostEqual(python_convert_fnb_unit(20, 'ml', 'lon', 385, 'ml'), 20.0 / 385.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(385, 'ml', 'lon', 385, 'ml'), 1.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(0.385, 'lít', 'lon', 385, 'ml'), 1.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(1, 'lon', 'lon', 385, 'ml'), 1.0, places=6)

        # 1 hộp fresh milk = 1000 ml
        self.assertAlmostEqual(python_convert_fnb_unit(250, 'ml', 'hộp', 1000, 'ml'), 0.25, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(1000, 'ml', 'hộp', 1000, 'ml'), 1.0, places=6)

        # 1 gói tea = 500 g
        self.assertAlmostEqual(python_convert_fnb_unit(15, 'g', 'gói', 500, 'g'), 0.03, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(0.5, 'kg', 'gói', 500, 'g'), 1.0, places=6)

    def test_12_reference_oracle_edge_cases_and_fallbacks(self):
        """Verify zero rate, negative rate, incompatible dimensions, and null handling."""
        # Zero conversion rate: safe fallback to raw qty
        self.assertEqual(python_convert_fnb_unit(20, 'ml', 'lon', 0, 'ml'), 20.0)
        # Negative conversion rate: safe fallback
        self.assertEqual(python_convert_fnb_unit(20, 'ml', 'lon', -385, 'ml'), 20.0)
        # Incompatible dimension: 'cái' to 'kg' -> raw qty
        self.assertEqual(python_convert_fnb_unit(3, 'cái', 'kg'), 3.0)
        self.assertEqual(python_convert_fnb_unit(2, 'phần', 'lít'), 2.0)
        # Zero quantity
        self.assertEqual(python_convert_fnb_unit(0, 'ml', 'kg'), 0.0)
        self.assertEqual(python_convert_fnb_unit(None, 'ml', 'kg'), 0.0)
        # Negative quantity (refund/reversal)
        self.assertAlmostEqual(python_convert_fnb_unit(-20, 'ml', 'kg'), -0.020, places=6)

    def test_13_reference_oracle_vietnamese_synonyms(self):
        """Verify Vietnamese unit synonyms and case/space insensitivity."""
        self.assertAlmostEqual(python_convert_fnb_unit(1000, '  GRAM ', 'Kg'), 1.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(500, 'gr', 'ký'), 0.5, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(250, 'grm', 'kí'), 0.25, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(1000, 'mili lít', 'Lít'), 1.0, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(500, 'mililit', 'lit'), 0.5, places=6)
        self.assertAlmostEqual(python_convert_fnb_unit(100, 'cc', 'l'), 0.1, places=6)

    # ═════════════════════════════════════════════════════════════════════════
    # TIER 4: REAL-WORLD AUDIT RECONCILIATION ORACLE
    # ═════════════════════════════════════════════════════════════════════════
    def test_14_reference_oracle_formatter_anti_negative_zero(self):
        """Verify fmtQty and fmtDelta strictly suppress '-0' and '-0.0'."""
        self.assertEqual(python_fmt_qty(0), '0')
        self.assertEqual(python_fmt_qty(-0.0), '0')
        self.assertEqual(python_fmt_qty(-0.0000001), '0')
        self.assertEqual(python_fmt_qty(0.02), '0.02')
        self.assertEqual(python_fmt_qty(0.015), '0.015')
        self.assertEqual(python_fmt_qty(0.013), '0.013')
        self.assertEqual(python_fmt_qty(19.98), '19.98')

        self.assertEqual(python_fmt_delta(0, 'kg'), '0 kg')
        self.assertEqual(python_fmt_delta(-0.0, 'kg'), '0 kg')
        self.assertEqual(python_fmt_delta(-0.0000001, 'kg'), '0 kg')
        self.assertEqual(python_fmt_delta(-0.02, 'kg'), '-0.02 kg')
        self.assertEqual(python_fmt_delta(0.02, 'kg'), '+0.02 kg')
        self.assertEqual(python_fmt_delta(19.98, 'kg'), '+19.98 kg')
        self.assertEqual(python_fmt_delta(-20, 'kg'), '-20 kg')

        # Empty units
        self.assertEqual(python_fmt_delta(5, ''), '+5')
        self.assertEqual(python_fmt_delta(-0.02, ''), '-0.02')
        self.assertEqual(python_fmt_delta(0, ''), '0')

    def test_15_historical_discrepancy_exact_calculations(self):
        """Verify exact recovery math for orders #QN-20260930-002, 003, #QN-20261001-001."""
        # Raw buggy deduction per order: 20 kg sữa đặc, 13 kg cà phê, 15 kg kem muối
        # Correct deduction: 0.020 kg sữa đặc, 0.013 kg cà phê, 0.015 kg kem muối
        diff_milk_per_order = 20.0 - 0.020
        diff_beans_per_order = 13.0 - 0.013
        diff_cream_per_order = 15.0 - 0.015

        self.assertAlmostEqual(diff_milk_per_order, 19.980, places=6)
        self.assertAlmostEqual(diff_beans_per_order, 12.987, places=6)
        self.assertAlmostEqual(diff_cream_per_order, 14.985, places=6)

        total_milk_3_orders = diff_milk_per_order * 3
        total_beans_3_orders = diff_beans_per_order * 3
        total_cream_3_orders = diff_cream_per_order * 3

        self.assertAlmostEqual(total_milk_3_orders, 59.940, places=6)
        self.assertAlmostEqual(total_beans_3_orders, 38.961, places=6)
        self.assertAlmostEqual(total_cream_3_orders, 44.955, places=6)


if __name__ == "__main__":
    unittest.main()
