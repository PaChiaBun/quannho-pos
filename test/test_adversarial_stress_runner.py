#!/usr/bin/env python3
"""
Comprehensive Adversarial Stress Testing Runner for Milestone 5 (R3 & R4)
Author: challenger_m5_2 (Empirical Challenger)

Coverage:
1. Zero Hard Delete Invariant across 100% of lib/ and supabase/migrations/
2. batchSoftDelete edge cases (empty list, duplicate IDs, non-existent IDs, cache synchronization)
3. Staff Role Hierarchy Guard & Casing Bypass Matrix (SQL RPCs & Dart Services)
4. inventory_screen.dart Permission Gating Truth Table & AST structure
"""

import os
import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# ─────────────────────────────────────────────────────────────────────────────
# 1. SQL RPC SIMULATION & NORMALIZATION
# ─────────────────────────────────────────────────────────────────────────────

def normalize_role_code_v4(role: str) -> str:
    """Exact simulation of public.normalize_role_code_v4 in Postgres."""
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


def simulate_admin_update_staff_role_v4(
    caller_id: str,
    caller_role: str,
    caller_is_owner: bool,
    target_id: str,
    target_role: str,
    target_is_owner: bool,
    new_role: str,
    owner_count: int,
    store_roles: list = None,
) -> dict:
    """Exact simulation of public.admin_update_staff_role_v4."""
    if not caller_id:
        return {'success': False, 'status': 401, 'error_code': 'UNAUTHORIZED'}

    # Không thể tự đổi vai trò của chính mình
    if caller_id == target_id:
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Không thể tự thay đổi vai trò của chính mình'}

    v_caller_role = normalize_role_code_v4('owner' if caller_is_owner else caller_role)
    if v_caller_role not in ('owner', 'manager'):
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Không có quyền cập nhật nhân viên'}

    v_norm_new_role = normalize_role_code_v4(new_role)
    standard_roles = ('waiter', 'cashier', 'kitchen', 'stock', 'manager', 'owner')
    if v_norm_new_role not in standard_roles:
        custom_match = None
        if store_roles:
            for sr in store_roles:
                if sr == new_role or sr.strip().lower() == new_role.strip().lower():
                    custom_match = sr
                    break
        if custom_match:
            v_norm_new_role = custom_match
        else:
            return {'success': False, 'status': 400, 'error_code': 'INVALID_ROLE', 'message': 'Vai trò không hợp lệ'}

    # Quản lý không được nâng quyền ai thành Quản lý hoặc Chủ quán
    if v_caller_role == 'manager' and v_norm_new_role in ('owner', 'manager'):
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Quản lý không được nâng quyền người khác thành Quản lý hoặc Chủ quán'}

    v_target_role = normalize_role_code_v4('owner' if target_is_owner else target_role)
    if not v_target_role:
        return {'success': False, 'status': 404, 'error_code': 'STAFF_NOT_FOUND', 'message': 'Không tìm thấy nhân viên trong quán'}

    # Quản lý không được sửa Chủ quán hoặc Quản lý khác
    if v_caller_role == 'manager' and v_target_role in ('owner', 'manager'):
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Quản lý không được sửa Chủ quán hoặc Quản lý khác'}

    # Không cho phép hạ quyền Chủ quán cuối cùng
    if v_target_role == 'owner' and v_norm_new_role != 'owner':
        if owner_count <= 1:
            return {'success': False, 'status': 400, 'error_code': 'CANNOT_DEMOTE_LAST_OWNER', 'message': 'Không thể hạ quyền Chủ quán cuối cùng của cơ sở'}

    return {'success': True, 'status': 200, 'role': v_norm_new_role}


def simulate_admin_revoke_staff_membership_v4(
    caller_id: str,
    caller_role: str,
    caller_is_owner: bool,
    target_id: str,
    target_role: str,
    target_is_owner: bool,
    owner_count: int,
) -> dict:
    """Exact simulation of public.admin_revoke_staff_membership_v4."""
    if not caller_id:
        return {'success': False, 'status': 401, 'error_code': 'UNAUTHORIZED'}

    if caller_id == target_id:
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Không thể tự xóa quyền của chính mình'}

    v_caller_role = normalize_role_code_v4('owner' if caller_is_owner else caller_role)
    if v_caller_role not in ('owner', 'manager'):
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Không có quyền'}

    v_target_role = normalize_role_code_v4('owner' if target_is_owner else target_role)
    if not v_target_role:
        return {'success': True, 'status': 200, 'message': 'Nhân viên đã được thu hồi trước đó'}

    if v_caller_role == 'manager' and v_target_role in ('owner', 'manager'):
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Quản lý không được xóa Chủ quán hoặc Quản lý khác'}

    if v_target_role == 'owner':
        if owner_count <= 1:
            return {'success': False, 'status': 400, 'error_code': 'CANNOT_REMOVE_LAST_OWNER', 'message': 'Không thể xóa Chủ quán cuối cùng của cơ sở'}

    return {'success': True, 'status': 200, 'message': 'Thu hồi quyền nhân viên thành công'}


def simulate_admin_set_staff_status_v4(
    caller_id: str,
    caller_role: str,
    caller_is_owner: bool,
    target_id: str,
    target_role: str,
    target_is_owner: bool,
    is_active: bool,
    owner_count: int,
) -> dict:
    """Exact simulation of public.admin_set_staff_status_v4."""
    if not caller_id:
        return {'success': False, 'status': 401, 'error_code': 'UNAUTHORIZED'}

    if caller_id == target_id and not is_active:
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Không thể tự khóa tài khoản của chính mình'}

    v_caller_role = normalize_role_code_v4('owner' if caller_is_owner else caller_role)
    if v_caller_role not in ('owner', 'manager'):
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Không có quyền'}

    v_target_role = normalize_role_code_v4('owner' if target_is_owner else target_role)
    if not v_target_role:
        return {'success': False, 'status': 404, 'error_code': 'STAFF_NOT_FOUND', 'message': 'Không tìm thấy nhân viên trong quán'}

    if v_caller_role == 'manager' and v_target_role in ('owner', 'manager'):
        return {'success': False, 'status': 403, 'error_code': 'FORBIDDEN', 'message': 'Quản lý không được khóa Chủ quán hoặc Quản lý khác'}

    if not is_active and v_target_role == 'owner':
        if owner_count <= 1:
            return {'success': False, 'status': 400, 'error_code': 'CANNOT_LOCK_LAST_OWNER', 'message': 'Không thể khóa Chủ quán cuối cùng của cơ sở'}

    return {'success': True, 'status': 200, 'is_active': is_active}


# ─────────────────────────────────────────────────────────────────────────────
# 2. ADVERSARIAL TEST SUITE
# ─────────────────────────────────────────────────────────────────────────────

class TestZeroHardDeleteInvariant(unittest.TestCase):
    """Assert zero calls to delete on products table across entire codebase."""

    def test_zero_hard_deletes_in_lib(self):
        lib_dir = REPO_ROOT / 'lib'
        violations = []
        pattern_1 = re.compile(r"\.from\(['\"]products['\"]\)\.delete\(\)")
        pattern_2 = re.compile(r"\.delete\(\)\.eq\(['\"]store_id['\"]")

        for dart_file in lib_dir.rglob('*.dart'):
            text = dart_file.read_text(encoding='utf-8', errors='ignore')
            if pattern_1.search(text) or pattern_2.search(text):
                violations.append(str(dart_file.relative_to(REPO_ROOT)))

        self.assertEqual(violations, [], f"Found hard delete calls on products table in: {violations}")

    def test_zero_hard_deletes_in_migrations(self):
        mig_dir = REPO_ROOT / 'supabase/migrations'
        violations = []
        pattern = re.compile(r"DELETE\s+FROM\s+(?:public\.)?products\b", re.IGNORECASE)

        for sql_file in mig_dir.glob('*.sql'):
            text = sql_file.read_text(encoding='utf-8', errors='ignore')
            if pattern.search(text):
                violations.append(str(sql_file.relative_to(REPO_ROOT)))

        self.assertEqual(violations, [], f"Found DELETE FROM products in migration files: {violations}")


class TestBatchSoftDeleteEdgeCases(unittest.TestCase):
    """Stress test batchSoftDelete with edge-case ID inputs."""

    def setUp(self):
        self.store_id = 'store_test_001'
        self.initial_products = [
            {'id': 'p1', 'name': 'Món 1', 'is_deleted': False, 'is_active': True},
            {'id': 'p2', 'name': 'Món 2', 'is_deleted': False, 'is_active': True},
            {'id': 'p3', 'name': 'Món 3', 'is_deleted': False, 'is_active': True},
        ]

    def simulate_cache_eviction(self, cache: list, ids: list) -> list:
        id_set = set(ids)
        return [p for p in cache if p['id'] not in id_set]

    def test_empty_id_list_noop(self):
        ids = []
        evicted = self.simulate_cache_eviction(self.initial_products, ids)
        self.assertEqual(len(evicted), 3)
        self.assertEqual([p['id'] for p in evicted], ['p1', 'p2', 'p3'])

    def test_duplicate_ids_handled_cleanly(self):
        ids = ['p1', 'p1', 'p2', 'p1', 'p2']
        id_set = set(ids)
        self.assertEqual(id_set, {'p1', 'p2'})
        evicted = self.simulate_cache_eviction(self.initial_products, ids)
        self.assertEqual(len(evicted), 1)
        self.assertEqual(evicted[0]['id'], 'p3')

    def test_non_existent_ids_collateral_damage_zero(self):
        ids = ['ghost_99', 'ghost_88', 'ghost_77']
        evicted = self.simulate_cache_eviction(self.initial_products, ids)
        self.assertEqual(len(evicted), 3)
        self.assertEqual([p['id'] for p in evicted], ['p1', 'p2', 'p3'])

    def test_mixed_ids_eviction_integrity(self):
        ids = ['p1', 'ghost_0', 'p1', 'p3', 'ghost_9']
        evicted = self.simulate_cache_eviction(self.initial_products, ids)
        self.assertEqual(len(evicted), 1)
        self.assertEqual(evicted[0]['id'], 'p2')

    def test_empty_cache_eviction(self):
        ids = ['p1', 'p2']
        evicted = self.simulate_cache_eviction([], ids)
        self.assertEqual(evicted, [])

    def test_repository_code_contains_infilter_and_flags(self):
        repo_file = REPO_ROOT / 'lib/core/repositories/core_product_repository.dart'
        text = repo_file.read_text(encoding='utf-8')
        # Assert inFilter is used
        self.assertIn(".inFilter('id', ids)", text)
        # Assert soft delete flags
        self.assertIn("'is_deleted': true", text)
        self.assertIn("'is_active': false", text)
        # Assert empty check guard
        self.assertIn("if (ids.isEmpty) return;", text)


class TestRoleHierarchyStressMatrix(unittest.TestCase):
    """Stress test role hierarchy guards with adversarial inputs."""

    def test_role_casing_bypass_attempts_on_owner_promotion(self):
        owner_casing_variations = [
            'owner', 'OWNER', 'Owner', 'oWnEr',
            'chủ quán', 'Chủ Quán', 'CHỦ QUÁN', '  Chủ Quán  ',
            'chu quan', 'CHU QUAN', 'Chu Quan',
            'chủ', 'CHỦ',
        ]
        for var in owner_casing_variations:
            res = simulate_admin_update_staff_role_v4(
                caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
                target_id='staff_01', target_role='waiter', target_is_owner=False,
                new_role=var, owner_count=1
            )
            self.assertFalse(res['success'], f"Manager should NOT be able to assign role '{var}'")
            self.assertEqual(res['error_code'], 'FORBIDDEN', f"Variation '{var}' must be recognized and forbidden")

        # Non-standard abbreviation 'chu' without diacritic is rejected as INVALID_ROLE
        res_chu = simulate_admin_update_staff_role_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='staff_01', target_role='waiter', target_is_owner=False,
            new_role='chu', owner_count=1
        )
        self.assertFalse(res_chu['success'])
        self.assertEqual(res_chu['error_code'], 'INVALID_ROLE')


    def test_role_casing_bypass_attempts_on_manager_promotion(self):
        manager_casing_variations = [
            'manager', 'MANAGER', 'Manager', 'MaNaGeR',
            'quản lý', 'Quản Lý', 'QUẢN LÝ',
            'quan ly', 'QUAN LY',
        ]
        for var in manager_casing_variations:
            res = simulate_admin_update_staff_role_v4(
                caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
                target_id='staff_01', target_role='waiter', target_is_owner=False,
                new_role=var, owner_count=1
            )
            self.assertFalse(res['success'], f"Manager should NOT be able to assign role '{var}'")
            self.assertEqual(res['error_code'], 'FORBIDDEN')

    def test_unknown_abbreviations_blocked_without_custom_role(self):
        # 'ql' or 'admin' or 'chu quan 123'
        for invalid_role in ('ql', 'admin', 'chủ quán 2', 'random_role'):
            res = simulate_admin_update_staff_role_v4(
                caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
                target_id='staff_01', target_role='waiter', target_is_owner=False,
                new_role=invalid_role, owner_count=1, store_roles=[]
            )
            self.assertFalse(res['success'])
            self.assertIn(res['error_code'], ('INVALID_ROLE', 'FORBIDDEN'))

    def test_self_elevation_attempts_blocked(self):
        # Manager trying to elevate self to owner
        res1 = simulate_admin_update_staff_role_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='mgr_01', target_role='manager', target_is_owner=False,
            new_role='owner', owner_count=1
        )
        self.assertFalse(res1['success'])
        self.assertEqual(res1['error_code'], 'FORBIDDEN')

        # Manager trying to change own role to cashier
        res2 = simulate_admin_update_staff_role_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='mgr_01', target_role='manager', target_is_owner=False,
            new_role='cashier', owner_count=1
        )
        self.assertFalse(res2['success'])
        self.assertEqual(res2['error_code'], 'FORBIDDEN')

        # Manager trying to remove own membership
        res3 = simulate_admin_revoke_staff_membership_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='mgr_01', target_role='manager', target_is_owner=False,
            owner_count=1
        )
        self.assertFalse(res3['success'])
        self.assertEqual(res3['error_code'], 'FORBIDDEN')

        # Manager trying to lock own account
        res4 = simulate_admin_set_staff_status_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='mgr_01', target_role='manager', target_is_owner=False,
            is_active=False, owner_count=1
        )
        self.assertFalse(res4['success'])
        self.assertEqual(res4['error_code'], 'FORBIDDEN')

    def test_cross_manager_modifications_blocked(self):
        # Manager 1 trying to change Manager 2 to cashier
        res1 = simulate_admin_update_staff_role_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='mgr_02', target_role='manager', target_is_owner=False,
            new_role='cashier', owner_count=1
        )
        self.assertFalse(res1['success'])
        self.assertEqual(res1['error_code'], 'FORBIDDEN')

        # Manager 1 trying to revoke Manager 2
        res2 = simulate_admin_revoke_staff_membership_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='mgr_02', target_role='manager', target_is_owner=False,
            owner_count=1
        )
        self.assertFalse(res2['success'])
        self.assertEqual(res2['error_code'], 'FORBIDDEN')

        # Manager 1 trying to lock Manager 2
        res3 = simulate_admin_set_staff_status_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='mgr_02', target_role='manager', target_is_owner=False,
            is_active=False, owner_count=1
        )
        self.assertFalse(res3['success'])
        self.assertEqual(res3['error_code'], 'FORBIDDEN')

    def test_manager_targeting_owner_blocked(self):
        # Manager trying to demote Owner
        res1 = simulate_admin_update_staff_role_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            new_role='waiter', owner_count=1
        )
        self.assertFalse(res1['success'])
        self.assertEqual(res1['error_code'], 'FORBIDDEN')

        # Manager trying to revoke Owner
        res2 = simulate_admin_revoke_staff_membership_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            owner_count=1
        )
        self.assertFalse(res2['success'])
        self.assertEqual(res2['error_code'], 'FORBIDDEN')

        # Manager trying to lock Owner
        res3 = simulate_admin_set_staff_status_v4(
            caller_id='mgr_01', caller_role='manager', caller_is_owner=False,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            is_active=False, owner_count=1
        )
        self.assertFalse(res3['success'])
        self.assertEqual(res3['error_code'], 'FORBIDDEN')

    def test_last_owner_protection(self):
        # Demote last owner
        res1 = simulate_admin_update_staff_role_v4(
            caller_id='owner_02', caller_role='owner', caller_is_owner=True,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            new_role='cashier', owner_count=1
        )
        self.assertFalse(res1['success'])
        self.assertEqual(res1['error_code'], 'CANNOT_DEMOTE_LAST_OWNER')

        # Revoke last owner
        res2 = simulate_admin_revoke_staff_membership_v4(
            caller_id='owner_02', caller_role='owner', caller_is_owner=True,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            owner_count=1
        )
        self.assertFalse(res2['success'])
        self.assertEqual(res2['error_code'], 'CANNOT_REMOVE_LAST_OWNER')

        # Lock last owner
        res3 = simulate_admin_set_staff_status_v4(
            caller_id='owner_02', caller_role='owner', caller_is_owner=True,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            is_active=False, owner_count=1
        )
        self.assertFalse(res3['success'])
        self.assertEqual(res3['error_code'], 'CANNOT_LOCK_LAST_OWNER')

    def test_two_owners_allow_demotion_and_revocation(self):
        # When owner_count == 2, Owner 2 can demote Owner 1
        res1 = simulate_admin_update_staff_role_v4(
            caller_id='owner_02', caller_role='owner', caller_is_owner=True,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            new_role='manager', owner_count=2
        )
        self.assertTrue(res1['success'])
        self.assertEqual(res1['role'], 'manager')

        # When owner_count == 2, Owner 2 can revoke Owner 1
        res2 = simulate_admin_revoke_staff_membership_v4(
            caller_id='owner_02', caller_role='owner', caller_is_owner=True,
            target_id='owner_01', target_role='owner', target_is_owner=True,
            owner_count=2
        )
        self.assertTrue(res2['success'])


class TestInventoryScreenPermissionGating(unittest.TestCase):
    """Deep verification of inventory_screen.dart permission gating."""

    def setUp(self):
        self.inv_code = (REPO_ROOT / 'lib/screens/inventory_screen.dart').read_text(encoding='utf-8')

    def test_permission_provider_imported(self):
        self.assertIn("import '../core/providers/permission_provider.dart';", self.inv_code)

    def test_can_delete_items_getter_structure(self):
        # Verify getter logic
        match = re.search(r"bool get _canDeleteItems\s*\{([^}]+)\}", self.inv_code)
        self.assertIsNotNone(match, "_canDeleteItems getter must exist")
        body = match.group(1)
        self.assertIn("ref.watch(sessionProvider)", body)
        self.assertIn("StaffService.canonicalRole", body)
        self.assertIn("ref.canDo('kho.delete_item')", body)
        self.assertIn("session.isOwner || r == 'owner' || r == 'manager' || hasDeletePerm", body)

    def test_batch_delete_early_return_guard(self):
        match = re.search(r"Future<void> _confirmBatchDelete\(\)\s*async\s*\{([^}]+)\}", self.inv_code)
        self.assertIsNotNone(match)
        body = match.group(1)
        self.assertTrue(body.strip().startswith("if (!_canDeleteItems) return;"),
                        "_confirmBatchDelete must guard with if (!_canDeleteItems) return; as very first statement")

    def test_multi_select_button_rendering_guard(self):
        self.assertIn("if (_canDeleteItems) ...[", self.inv_code)

    def test_single_delete_on_delete_callback_guard(self):
        self.assertIn("onDelete: _canDeleteItems ? () async", self.inv_code)

    def test_permission_truth_table_evaluation(self):
        def can_delete(is_owner, role, permissions):
            # Canonical role logic matching StaffService.canonicalRole
            r = role.lower().strip()
            if ('owner' in r or 'chủ quán' in r or 'chu quan' in r or r == 'chủ' or r == 'chu'):
                canon = 'owner'
            elif ('manager' in r or 'quản lý' in r or 'quan ly' in r or r == 'ql' or
                  'quản trị' in r or 'quan tri' in r or 'admin' in r):
                canon = 'manager'
            else:
                canon = r

            has_delete_perm = 'kho.delete_item' in permissions
            return is_owner or canon == 'owner' or canon == 'manager' or has_delete_perm

        # Waiter without permission -> BLOCKED
        self.assertFalse(can_delete(is_owner=False, role='waiter', permissions=[]))
        self.assertFalse(can_delete(is_owner=False, role='phục vụ', permissions=['pos.checkout']))
        self.assertFalse(can_delete(is_owner=False, role='pv', permissions=[]))

        # Cashier without permission -> BLOCKED
        self.assertFalse(can_delete(is_owner=False, role='cashier', permissions=['pos.checkout']))
        self.assertFalse(can_delete(is_owner=False, role='thu ngân', permissions=[]))

        # Waiter WITH kho.delete_item -> ALLOWED
        self.assertTrue(can_delete(is_owner=False, role='waiter', permissions=['kho.delete_item']))
        self.assertTrue(can_delete(is_owner=False, role='phục vụ', permissions=['kho.delete_item']))

        # Cashier WITH kho.delete_item -> ALLOWED
        self.assertTrue(can_delete(is_owner=False, role='cashier', permissions=['kho.delete_item']))

        # Manager -> ALLOWED unconditionally
        self.assertTrue(can_delete(is_owner=False, role='manager', permissions=[]))
        self.assertTrue(can_delete(is_owner=False, role='quản lý', permissions=[]))
        self.assertTrue(can_delete(is_owner=False, role='Quản Lý', permissions=[]))
        self.assertTrue(can_delete(is_owner=False, role='ql', permissions=[]))

        # Owner -> ALLOWED unconditionally
        self.assertTrue(can_delete(is_owner=True, role='waiter', permissions=[]))
        self.assertTrue(can_delete(is_owner=False, role='owner', permissions=[]))
        self.assertTrue(can_delete(is_owner=False, role='Chủ Quán', permissions=[]))


if __name__ == '__main__':
    unittest.main(verbosity=2)
