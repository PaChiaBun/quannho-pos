# test/backend/test_staff_management_role_v4_sql.py
# ─────────────────────────────────────────────────────────────────────────────
# Invariant and SQL structural tests for staff role hierarchy and normalization
# ─────────────────────────────────────────────────────────────────────────────
import os
import re
import unittest

def py_normalize_role_code_v4(role: str) -> str:
    """Exact python simulation of public.normalize_role_code_v4 in Postgres."""
    if not role:
        return ""
    clean = role.strip().lower()
    if clean in ('owner', 'chu quan', 'chủ quán', 'chủ'):
        return 'owner'
    elif clean in ('manager', 'quan ly', 'quản lý'):
        return 'manager'
    elif clean in ('cashier', 'thu ngan', 'thu ngân'):
        return 'cashier'
    elif clean in ('waiter', 'phuc vu', 'phục vụ'):
        return 'waiter'
    elif clean in ('kitchen', 'chef', 'bep', 'bếp', 'đầu bếp', 'dau bep'):
        return 'kitchen'
    elif clean in ('stock', 'kho'):
        return 'stock'
    return clean


class TestStaffManagementRoleV4Sql(unittest.TestCase):
    def setUp(self):
        self.sql_path = os.path.abspath(os.path.join(
            os.path.dirname(__file__),
            '../../supabase/migrations/20260913_fix_staff_management_manager_role_v4.sql'
        ))
        self.assertTrue(os.path.exists(self.sql_path), f"Migration file not found: {self.sql_path}")
        with open(self.sql_path, 'r', encoding='utf-8') as f:
            self.sql_content = f.read()

    def test_python_normalization_simulation(self):
        # Manager variations
        self.assertEqual(py_normalize_role_code_v4('Quản Lý'), 'manager')
        self.assertEqual(py_normalize_role_code_v4('quản lý'), 'manager')
        self.assertEqual(py_normalize_role_code_v4('quan ly'), 'manager')
        self.assertEqual(py_normalize_role_code_v4('manager'), 'manager')
        self.assertEqual(py_normalize_role_code_v4(' MANAGER '), 'manager')

        # Owner variations
        self.assertEqual(py_normalize_role_code_v4('Chủ quán'), 'owner')
        self.assertEqual(py_normalize_role_code_v4('chu quan'), 'owner')
        self.assertEqual(py_normalize_role_code_v4('owner'), 'owner')

        # Subordinate variations
        self.assertEqual(py_normalize_role_code_v4('Thu Ngân'), 'cashier')
        self.assertEqual(py_normalize_role_code_v4('Phục Vụ'), 'waiter')
        self.assertEqual(py_normalize_role_code_v4('Đầu Bếp'), 'kitchen')
        self.assertEqual(py_normalize_role_code_v4('Bếp'), 'kitchen')
        self.assertEqual(py_normalize_role_code_v4('Kho'), 'stock')

    def test_sql_migration_structural_integrity(self):
        # 1. normalize_role_code_v4 exists
        self.assertIn("CREATE OR REPLACE FUNCTION public.normalize_role_code_v4", self.sql_content)
        self.assertIn("IMMUTABLE", self.sql_content)

        # 2. Existing data updates
        self.assertIn("UPDATE public.store_members", self.sql_content)
        self.assertIn("UPDATE public.staff_members", self.sql_content)

        # 3. admin_create_staff_member_v4 guardrails
        self.assertIn("CREATE OR REPLACE FUNCTION public.admin_create_staff_member_v4", self.sql_content)
        self.assertIn("public.normalize_role_code_v4", self.sql_content)
        self.assertIn("Quản lý không có quyền tạo thêm Quản lý hoặc Chủ quán", self.sql_content)

        # 4. admin_update_staff_role_v4 guardrails
        self.assertIn("CREATE OR REPLACE FUNCTION public.admin_update_staff_role_v4", self.sql_content)
        self.assertIn("Quản lý không được sửa Chủ quán hoặc Quản lý khác", self.sql_content)
        self.assertIn("Quản lý không được nâng quyền người khác thành Quản lý hoặc Chủ quán", self.sql_content)

        # 5. admin_set_staff_status_v4 guardrails
        self.assertIn("CREATE OR REPLACE FUNCTION public.admin_set_staff_status_v4", self.sql_content)
        self.assertIn("Quản lý không được khóa Chủ quán hoặc Quản lý khác", self.sql_content)

        # 6. admin_revoke_staff_membership_v4 guardrails
        self.assertIn("CREATE OR REPLACE FUNCTION public.admin_revoke_staff_membership_v4", self.sql_content)
        self.assertIn("Quản lý không được xóa Chủ quán hoặc Quản lý khác", self.sql_content)

        # 7. join_store_by_code_v4 normalization
        self.assertIn("CREATE OR REPLACE FUNCTION public.join_store_by_code_v4", self.sql_content)

        # 8. Grants
        for func_name in (
            "normalize_role_code_v4",
            "admin_create_staff_member_v4",
            "admin_update_staff_role_v4",
            "admin_set_staff_status_v4",
            "admin_revoke_staff_membership_v4",
            "join_store_by_code_v4",
        ):
            self.assertIn(f"GRANT EXECUTE ON FUNCTION public.{func_name}", self.sql_content)

if __name__ == '__main__':
    unittest.main()
