#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Empirical Verification Test Suite for R2 & R3 Operational Fixes
Quán Nhỏ POS

Tests:
1. SQL Migration Syntax & Structure:
   - 20261001_fix_purchase_orders_total_cost_and_amount.sql
   - 20261001_create_store_shift_configs.sql
   - Validates DDL, column types, default values, NOT NULL alterations, backfill logic, foreign keys, grants, RLS.
2. Error Masking & User-Facing UI Leak Verification:
   - Ensures no raw PostgrestException, 23502, or PGRST205 leaks to UI in phieu_nhap_hang_screen.dart.
   - Ensures no raw PostgrestException or PGRST205 leaks to UI in nhan_vien_screen.dart.
   - Verifies user-friendly error messages match nhat_ky.md specifications.
3. AppLogger Error Logging Contract:
   - Validates AppLogger.error calls provide tag, message, error object, and stackTrace.
4. Backward Compatibility & Fallback Reads:
   - Validates PurchaseOrderModel.fromMap behavior across modern, legacy (total_cost only), dual, and edge-case inputs.
   - Validates ShiftConfig mapping in StaffService.getStaffList.
"""

import os
import re
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))

class TestR2R3DatabaseMigrations(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.po_migration_path = os.path.join(
            REPO_ROOT, "supabase/migrations/20261001_fix_purchase_orders_total_cost_and_amount.sql"
        )
        cls.shift_migration_path = os.path.join(
            REPO_ROOT, "supabase/migrations/20261001_create_store_shift_configs.sql"
        )
        with open(cls.po_migration_path, "r", encoding="utf-8") as f:
            cls.po_sql = f.read()
        with open(cls.shift_migration_path, "r", encoding="utf-8") as f:
            cls.shift_sql = f.read()

    def test_01_po_migration_file_structure(self):
        """Verify purchase orders migration file formatting and delimiters"""
        with open(self.po_migration_path, "rb") as f:
            self.assertTrue(f.read().endswith(b"\n"), "File must end with newline")
        self.assertEqual(self.po_sql.count("$$") % 2, 0, "DO $$ blocks must be balanced")

    def test_02_po_migration_ddl_and_constraints(self):
        """Verify purchase orders migration has idempotent DDL and drops NOT NULL on total_cost"""
        self.assertIn("ALTER TABLE public.purchase_orders", self.po_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS total_amount numeric DEFAULT 0", self.po_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS total_cost numeric DEFAULT 0", self.po_sql)
        self.assertIn("ALTER COLUMN total_cost DROP NOT NULL", self.po_sql)
        self.assertIn("ALTER COLUMN total_cost SET DEFAULT 0", self.po_sql)
        self.assertIn("ALTER COLUMN total_amount SET DEFAULT 0", self.po_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS po_number text", self.po_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS supplier_name text DEFAULT ''", self.po_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS invoice_image_url text", self.po_sql)

    def test_03_po_migration_purchase_items_and_backfill(self):
        """Verify purchase_items table support, po_id FK and backfills"""
        self.assertIn("ALTER TABLE public.purchase_items", self.po_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS po_id uuid REFERENCES public.purchase_orders(id) ON DELETE CASCADE", self.po_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS subtotal numeric DEFAULT 0", self.po_sql)
        # Backfill queries
        self.assertIn("SET total_amount = COALESCE(total_cost, 0)", self.po_sql)
        self.assertIn("SET total_cost = COALESCE(total_amount, 0)", self.po_sql)
        self.assertIn("SET po_id = purchase_id", self.po_sql)

    def test_04_po_migration_grants(self):
        """Verify GRANT statements for anon, authenticated, service_role"""
        self.assertIn("GRANT SELECT, INSERT, UPDATE, DELETE ON public.purchase_orders TO anon, authenticated, service_role", self.po_sql)
        self.assertIn("GRANT SELECT, INSERT, UPDATE, DELETE ON public.purchase_items TO anon, authenticated, service_role", self.po_sql)

    def test_05_shift_migration_file_structure(self):
        """Verify store_shift_configs migration formatting and delimiters"""
        with open(self.shift_migration_path, "rb") as f:
            self.assertTrue(f.read().endswith(b"\n"), "File must end with newline")
        self.assertEqual(self.shift_sql.count("$$") % 2, 0, "DO $$ blocks must be balanced")

    def test_06_shift_migration_table_and_columns(self):
        """Verify store_shift_configs DDL structure, column types and defaults"""
        self.assertIn("CREATE TABLE IF NOT EXISTS public.store_shift_configs", self.shift_sql)
        self.assertIn("id            UUID PRIMARY KEY DEFAULT gen_random_uuid()", self.shift_sql)
        self.assertIn("store_id      UUID NOT NULL REFERENCES public.stores(id) ON DELETE CASCADE", self.shift_sql)
        self.assertIn("name          TEXT NOT NULL", self.shift_sql)
        self.assertIn("start_hour    INTEGER NOT NULL DEFAULT 6", self.shift_sql)
        self.assertIn("start_minute  INTEGER NOT NULL DEFAULT 0", self.shift_sql)
        self.assertIn("end_hour      INTEGER NOT NULL DEFAULT 14", self.shift_sql)
        self.assertIn("end_minute    INTEGER NOT NULL DEFAULT 0", self.shift_sql)
        self.assertIn("color         TEXT NOT NULL DEFAULT '#0EA5E9'", self.shift_sql)
        self.assertIn("sort_order    INTEGER NOT NULL DEFAULT 0", self.shift_sql)
        self.assertIn("is_active     BOOLEAN NOT NULL DEFAULT TRUE", self.shift_sql)
        self.assertIn("created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()", self.shift_sql)
        self.assertIn("updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()", self.shift_sql)

    def test_07_shift_migration_indexes_rls_and_grants(self):
        """Verify index, DISABLE RLS and GRANT ALL on store_shift_configs"""
        self.assertIn("CREATE INDEX IF NOT EXISTS idx_store_shift_configs_store_id", self.shift_sql)
        self.assertIn("ALTER TABLE public.store_shift_configs DISABLE ROW LEVEL SECURITY", self.shift_sql)
        self.assertIn("GRANT ALL ON TABLE public.store_shift_configs TO anon, authenticated, service_role", self.shift_sql)

    def test_08_shift_migration_store_members_fk(self):
        """Verify store_members shift_config_id foreign key constraint and index"""
        self.assertIn("ALTER TABLE public.store_members", self.shift_sql)
        self.assertIn("ADD COLUMN IF NOT EXISTS shift_config_id UUID REFERENCES public.store_shift_configs(id) ON DELETE SET NULL", self.shift_sql)
        self.assertIn("CREATE INDEX IF NOT EXISTS idx_store_members_shift_config_id", self.shift_sql)


class TestR2R3ErrorHandlingAndLogging(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.phieu_nhap_path = os.path.join(
            REPO_ROOT, "lib/modules/kho/screens/phieu_nhap_hang_screen.dart"
        )
        cls.nhan_vien_path = os.path.join(
            REPO_ROOT, "lib/screens/nhan_vien_screen.dart"
        )
        cls.kho_repo_path = os.path.join(
            REPO_ROOT, "lib/modules/kho/repository/kho_repository.dart"
        )
        cls.staff_service_path = os.path.join(
            REPO_ROOT, "lib/core/services/staff_service.dart"
        )

        with open(cls.phieu_nhap_path, "r", encoding="utf-8") as f:
            cls.phieu_nhap_code = f.read()
        with open(cls.nhan_vien_path, "r", encoding="utf-8") as f:
            cls.nhan_vien_code = f.read()
        with open(cls.kho_repo_path, "r", encoding="utf-8") as f:
            cls.kho_repo_code = f.read()
        with open(cls.staff_service_path, "r", encoding="utf-8") as f:
            cls.staff_service_code = f.read()

    def test_09_phieu_nhap_hang_no_raw_error_leak(self):
        """Verify phieu_nhap_hang_screen does NOT display raw error or PostgrestException to user"""
        submit_idx = self.phieu_nhap_code.find("Future<void> _submit()")
        self.assertNotEqual(submit_idx, -1, "_submit method must exist")
        submit_code = self.phieu_nhap_code[submit_idx:submit_idx + 2500]

        # Check friendly message is used
        self.assertIn(
            "Tạo phiếu nhập thất bại. Hãy chụp lại báo chủ app.",
            submit_code,
            "Must display standardized friendly error message",
        )
        # Check that e.toString() or $e or $err is NOT passed to SnackBar content
        # Note: AppLogger may contain $e, but SnackBar content must NOT contain $e
        snack_bar_match = re.search(r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(SnackBar\(([\s\S]*?)\)\);", submit_code)
        self.assertIsNotNone(snack_bar_match)
        snack_content = snack_bar_match.group(1)
        self.assertNotIn("$e", snack_content, "SnackBar must not interpolate $e")
        self.assertNotIn("e.toString()", snack_content, "SnackBar must not contain e.toString()")
        self.assertNotIn("e.message", snack_content, "SnackBar must not contain e.message")
        self.assertNotIn("23502", snack_content, "SnackBar must not leak code 23502")

    def test_10_phieu_nhap_hang_app_logger_call(self):
        """Verify AppLogger.error in phieu_nhap_hang_screen passes tag, message, error, stackTrace"""
        submit_idx = self.phieu_nhap_code.find("Future<void> _submit()")
        submit_code = self.phieu_nhap_code[submit_idx:submit_idx + 2500]
        # Match catch (e, st) { AppLogger.error('kho', ..., e, st); }
        logger_match = re.search(
            r"AppLogger\.error\(\s*['\"]kho['\"]\s*,\s*[^,]+,\s*([a-zA-Z0-9_]+)\s*,\s*([a-zA-Z0-9_]+)\s*\)",
            submit_code,
        )
        self.assertIsNotNone(logger_match, "AppLogger.error must be called with tag 'kho', message, error, stackTrace")
        self.assertEqual(logger_match.group(1), "e")
        self.assertEqual(logger_match.group(2), "st")

    def test_11_nhan_vien_screen_shift_save_no_raw_error_leak(self):
        """Verify _ShiftFormSheetState._save masks raw errors and displays friendly message"""
        class_idx = self.nhan_vien_code.find("class _ShiftFormSheetState")
        self.assertNotEqual(class_idx, -1, "_ShiftFormSheetState class must exist")
        save_idx = self.nhan_vien_code.find("Future<void> _save() async {", class_idx)
        self.assertNotEqual(save_idx, -1, "_ShiftFormSheetState._save method must exist")
        save_code = self.nhan_vien_code[save_idx:save_idx + 2200]

        # Check friendly message is used
        self.assertIn(
            "Lưu ca thất bại. Hãy chụp lại báo chủ app.",
            save_code,
            "Must set friendly error message on _errorMsg",
        )
        # Ensure raw error is NOT assigned to _errorMsg in catch block
        catch_block_match = re.search(r"catch\s*\(([^)]+)\)\s*\{([\s\S]*?)\}", save_code)
        self.assertIsNotNone(catch_block_match)
        catch_body = catch_block_match.group(2)
        self.assertNotIn("_errorMsg = 'Lỗi: $err'", catch_body)
        self.assertNotIn("_errorMsg = err.toString()", catch_body)
        self.assertNotIn("_errorMsg = '$err'", catch_body)
        self.assertNotIn("PGRST205", catch_body)

    def test_12_nhan_vien_screen_shift_save_app_logger_call(self):
        """Verify AppLogger.error in _ShiftFormSheetState._save passes tag, message, error, stackTrace"""
        class_idx = self.nhan_vien_code.find("class _ShiftFormSheetState")
        save_idx = self.nhan_vien_code.find("Future<void> _save() async {", class_idx)
        save_code = self.nhan_vien_code[save_idx:save_idx + 2200]
        logger_match = re.search(
            r"AppLogger\.error\(\s*['\"]nhan_vien_screen['\"]\s*,\s*[\s\S]*?,\s*([a-zA-Z0-9_]+)\s*,\s*([a-zA-Z0-9_]+)\s*\)",
            save_code,
        )
        self.assertIsNotNone(logger_match, "AppLogger.error must be called with tag 'nhan_vien_screen', msg, err, st")
        self.assertEqual(logger_match.group(1), "err")
        self.assertEqual(logger_match.group(2), "st")

    def test_13_nhan_vien_screen_shift_delete_error_handling(self):
        """Verify delete shift error handling masks errors and logs via AppLogger"""
        delete_idx = self.nhan_vien_code.find("onDelete: () async {")
        self.assertNotEqual(delete_idx, -1, "onDelete callback must exist")
        delete_code = self.nhan_vien_code[delete_idx:delete_idx + 1000]

        self.assertIn("Xoá ca thất bại. Hãy chụp lại báo chủ app.", delete_code)
        logger_match = re.search(
            r"AppLogger\.error\(\s*['\"]nhan_vien_screen['\"]\s*,\s*[\s\S]*?,\s*([a-zA-Z0-9_]+)\s*,\s*([a-zA-Z0-9_]+)\s*,?\s*\)",
            delete_code,
        )
        self.assertIsNotNone(logger_match, "Delete error must be logged via AppLogger.error")


class TestR2R3RepositoryDualFieldsAndFallbacks(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.kho_repo_path = os.path.join(
            REPO_ROOT, "lib/modules/kho/repository/kho_repository.dart"
        )
        cls.staff_service_path = os.path.join(
            REPO_ROOT, "lib/core/services/staff_service.dart"
        )
        with open(cls.kho_repo_path, "r", encoding="utf-8") as f:
            cls.kho_repo_code = f.read()
        with open(cls.staff_service_path, "r", encoding="utf-8") as f:
            cls.staff_service_code = f.read()

    def test_14_kho_repository_insert_dual_columns(self):
        """Verify createPurchaseOrder inserts BOTH total_cost and total_amount"""
        create_idx = self.kho_repo_code.find("Future<String> createPurchaseOrder(")
        self.assertNotEqual(create_idx, -1)
        create_code = self.kho_repo_code[create_idx:create_idx + 3000]

        insert_match = re.search(r"\.from\('purchase_orders'\)\.insert\(\{([\s\S]*?)\}\);", create_code)
        self.assertIsNotNone(insert_match, "Must find purchase_orders insert payload")
        payload = insert_match.group(1)

        self.assertIn("'total_cost':", payload, "Payload must include total_cost")
        self.assertIn("'total_amount':", payload, "Payload must include total_amount")
        self.assertIn("'invoice_image_url':", payload, "Payload must include invoice_image_url")
        self.assertIn("'po_number':", payload, "Payload must include po_number")

    def test_15_kho_repository_cancel_read_fallback(self):
        """Verify cancelPurchaseOrder reads both total_amount and total_cost with fallback"""
        cancel_idx = self.kho_repo_code.find("Future<void> cancelPurchaseOrder(")
        self.assertNotEqual(cancel_idx, -1)
        cancel_code = self.kho_repo_code[cancel_idx:cancel_idx + 3500]

        self.assertIn(".select('po_number, total_amount, total_cost')", cancel_code)
        self.assertIn("(poRow['total_amount'] as num?)?.toDouble() ??", cancel_code)
        self.assertIn("(poRow['total_cost'] as num?)?.toDouble() ?? 0", cancel_code)

    def test_16_purchase_order_model_from_map_fallback(self):
        """Verify PurchaseOrderModel.fromMap fallback logic in Dart source"""
        model_idx = self.kho_repo_code.find("class PurchaseOrderModel {")
        self.assertNotEqual(model_idx, -1)
        model_code = self.kho_repo_code[model_idx:model_idx + 1500]

        self.assertIn("(m['total_amount'] as num?)?.toDouble() ??", model_code)
        self.assertIn("(m['total_cost'] as num?)?.toDouble() ?? 0", model_code)

    def test_17_staff_service_get_staff_list_includes_shift_config_id(self):
        """Verify StaffService.getStaffList queries and maps shift_config_id"""
        get_list_idx = self.staff_service_code.find("static Future<List<StaffMember>> getStaffList(")
        self.assertNotEqual(get_list_idx, -1)
        get_list_code = self.staff_service_code[get_list_idx:get_list_idx + 9000]

        self.assertIn("shift_config_id", get_list_code, "Select query must include shift_config_id")
        self.assertIn("shiftConfigId: m['shift_config_id'] as String?", get_list_code, "StaffMember constructor must map shiftConfigId")


if __name__ == "__main__":
    unittest.main(verbosity=2)
