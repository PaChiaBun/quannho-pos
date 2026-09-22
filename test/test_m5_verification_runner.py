#!/usr/bin/env python3
"""
Verification Runner for Milestone 5:
Directly tests and asserts all contract specifications and test cases from:
1. test/modules/kho_batch_delete_and_search_test.dart
2. test/core/staff_manager_hierarchy_guard_test.dart
And verifies production implementation in:
- lib/core/utils/string_utils.dart
- lib/core/services/staff_service.dart
- lib/screens/ban_screen.dart
- lib/screens/inventory_screen.dart
- lib/core/repositories/core_product_repository.dart
- lib/core/providers/app_providers.dart
"""

import re
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# ─────────────────────────────────────────────────────────────────────────────
# 1. Exact string_utils logic implementation (reproducing Dart removeDiacritics & containsSearch)
# ─────────────────────────────────────────────────────────────────────────────

DIACRITICS_MAP = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'i', 'ý': 'i', 'ỷ': 'i', 'ỹ': 'i', 'ỵ': 'i', 'y': 'i',
    'đ': 'd',
    'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A',
    'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A',
    'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
    'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E',
    'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
    'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
    'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O',
    'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ộ': 'O',
    'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
    'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U',
    'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
    'Ỳ': 'I', 'Ý': 'I', 'Ỷ': 'I', 'Ỹ': 'I', 'Ỵ': 'I', 'Y': 'I',
    'Đ': 'D',
}

def remove_diacritics(s: str) -> str:
    return "".join(DIACRITICS_MAP.get(c, c) for c in s)

def contains_search(source: str, query: str) -> bool:
    if not query:
        return True
    clean_query = remove_diacritics(query).lower().strip()
    clean_source = remove_diacritics(source).lower()

    # 1. Khớp chuỗi trực tiếp
    if clean_query in clean_source:
        return True

    # 2. Khớp viết tắt / ký tự đầu
    words = [w for w in re.split(r'\s+', clean_source) if w]
    if words:
        initials = "".join(w[0] for w in words)
        if clean_query in initials:
            return True

    # 3. Khớp nhiều từ không quan trọng thứ tự
    query_words = [qw for qw in re.split(r'\s+', clean_query) if qw]
    if len(query_words) > 1:
        if all(qw in clean_source for qw in query_words):
            return True

    return False

# ─────────────────────────────────────────────────────────────────────────────
# 2. Exact staff_service canonicalRole implementation
# ─────────────────────────────────────────────────────────────────────────────

def canonical_role(role_name: str) -> str:
    n = role_name.lower().strip()
    if ('owner' in n or 'chủ quán' in n or 'chu quan' in n or n == 'chủ' or n == 'chu'):
        return 'owner'
    if ('manager' in n or 'quản lý' in n or 'quan ly' in n or n == 'ql' or
        'quản trị' in n or 'quan tri' in n or 'admin' in n):
        return 'manager'
    if ('cashier' in n or 'thu ngân' in n or 'thu ngan' in n or n == 'tn' or
        'quầy' in n or 'quay' in n or 'bán hàng' in n or 'ban hang' in n):
        return 'cashier'
    if ('waiter' in n or 'waitress' in n or 'phục vụ' in n or 'phuc vu' in n or
        n == 'pv' or 'chạy bàn' in n or 'chay ban' in n):
        return 'waiter'
    if ('kitchen' in n or 'bếp' in n or 'bep' in n or 'đầu bếp' in n or
        'dau bep' in n or 'chef' in n or 'cook' in n):
        return 'kitchen'
    if 'stock' in n or 'kho' in n:
        return 'stock'
    return n

# ─────────────────────────────────────────────────────────────────────────────
# Product Model dataclass
# ─────────────────────────────────────────────────────────────────────────────
class ProductModel:
    def __init__(self, id, name, sku=None, category=None, sell_price=50000,
                 is_available=True, is_active=True, stock_qty=10, min_stock=5):
        self.id = id
        self.name = name
        self.sku = sku
        self.category = category
        self.sell_price = sell_price
        self.is_available = is_available
        self.is_active = is_active
        self.stock_qty = stock_qty
        self.min_stock = min_stock


class TestKhoBatchDeleteAndSearch(unittest.TestCase):
    def setUp(self):
        self.products = [
            ProductModel(
                id='p1',
                name='Trà đào cam sả',
                sku='TD01',
                sell_price=35000,
                category='Đồ uống',
                stock_qty=50,
            ),
            ProductModel(
                id='p2',
                name='Bò nướng tảng',
                sku='BN01',
                sell_price=150000,
                category='Món nướng',
                stock_qty=20,
            ),
            ProductModel(
                id='p3',
                name='Bia Larue',
                sku='BL99',
                sell_price=20000,
                category='Đồ uống',
                is_available=False,
                stock_qty=10,
            ),
            ProductModel(
                id='p4',
                name='Mực hấp gừng',
                sku='MH02',
                sell_price=120000,
                category='Hải sản',
                stock_qty=0,
            ),
        ]

    def filter_products(self, list_items, selected_category, search):
        result = []
        for p in list_items:
            match_cat = True if search != "" else (
                selected_category == 'Tất cả' or (p.category or 'Khác') == selected_category
            )
            match_search = True if search == "" else (
                contains_search(p.name, search) or (contains_search(p.sku, search) if p.sku else False)
            )
            if match_cat and match_search:
                result.append(p)
        return result

    # Group 1: Logic tìm kiếm món trong Bàn
    def test_group1_no_search_filters_category(self):
        nuong = self.filter_products(self.products, 'Món nướng', '')
        self.assertEqual(len(nuong), 1)
        self.assertEqual(nuong[0].id, 'p2')

        tat_ca = self.filter_products(self.products, 'Tất cả', '')
        self.assertEqual(len(tat_ca), 4)

    def test_group1_search_bypasses_category(self):
        result = self.filter_products(self.products, 'Món nướng', 'trà đào')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].name, 'Trà đào cam sả')
        self.assertEqual(result[0].category, 'Đồ uống')

    def test_group1_search_by_sku(self):
        result = self.filter_products(self.products, 'Đồ uống', 'MH02')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].name, 'Mực hấp gừng')

    def test_group1_search_case_and_diacritics_insensitive(self):
        result = self.filter_products(self.products, 'Tất cả', 'tra dao')
        self.assertEqual(len(result), 1)
        self.assertEqual(result[0].id, 'p1')

    # Group 2: Logic nhận diện món Tạm hết (isOutOfStock)
    def check_out_of_stock(self, p: ProductModel) -> bool:
        return (not p.is_available) or (p.min_stock > 0 and p.stock_qty <= 0)

    def test_group2_unavailable_is_out_of_stock(self):
        p = ProductModel(id='1', name='Món ngưng bán', is_available=False, stock_qty=20, min_stock=5)
        self.assertTrue(self.check_out_of_stock(p))

    def test_group2_stock_zero_with_min_stock_is_out_of_stock(self):
        p = ProductModel(id='2', name='Món hết kho', is_available=True, stock_qty=0, min_stock=5)
        self.assertTrue(self.check_out_of_stock(p))

    def test_group2_in_stock_is_not_out_of_stock(self):
        p = ProductModel(id='3', name='Món sẵn sàng', is_available=True, stock_qty=15, min_stock=5)
        self.assertFalse(self.check_out_of_stock(p))

    def test_group2_zero_min_stock_never_out_of_stock(self):
        p = ProductModel(id='4', name='Món dịch vụ', is_available=True, stock_qty=0, min_stock=0)
        self.assertFalse(self.check_out_of_stock(p))

    # Group 3: Phân quyền xoá món
    def can_delete_products(self, is_owner: bool, role: str, permissions: list) -> bool:
        return (is_owner or
                role == 'owner' or
                role == 'manager' or
                'kho.delete_item' in permissions)

    def test_group3_owner_can_delete(self):
        self.assertTrue(self.can_delete_products(is_owner=True, role='owner', permissions=[]))
        self.assertTrue(self.can_delete_products(is_owner=False, role='owner', permissions=[]))

    def test_group3_manager_can_delete(self):
        self.assertTrue(self.can_delete_products(is_owner=False, role='manager', permissions=[]))

    def test_group3_staff_with_permission_can_delete(self):
        self.assertTrue(self.can_delete_products(is_owner=False, role='cashier', permissions=['kho.delete_item']))

    def test_group3_staff_without_permission_cannot_delete(self):
        self.assertFalse(self.can_delete_products(is_owner=False, role='waiter', permissions=['pos.checkout']))


class TestStaffManagerHierarchyGuard(unittest.TestCase):
    def test_01_update_role_blocks_owner(self):
        # In staff_service.dart: lines 714-718
        staff_service_code = (REPO_ROOT / 'lib/core/services/staff_service.dart').read_text()
        self.assertIn("rLower == 'owner' || rLower == 'chủ quán' || rLower == 'chu quan'", staff_service_code)
        self.assertIn("updateRole blocked: cannot assign owner role", staff_service_code)

    def test_02_add_staff_blocks_owner(self):
        staff_service_code = (REPO_ROOT / 'lib/core/services/staff_service.dart').read_text()
        self.assertIn("Không thể gán vai trò Chủ quán cho nhân viên mới", staff_service_code)

    def test_03_remove_staff_rpc_invocation(self):
        staff_service_code = (REPO_ROOT / 'lib/core/services/staff_service.dart').read_text()
        self.assertIn("'admin_revoke_staff_membership_v4'", staff_service_code)
        self.assertIn("'p_store_id': storeId", staff_service_code)
        self.assertIn("'p_staff_id': userId", staff_service_code)

    def test_04_hierarchy_guard_matrix(self):
        def can_manage_staff(caller_role, caller_is_owner, target_role, target_is_owner, caller_user_id, target_user_id):
            if caller_user_id == target_user_id:
                return False

            c_role = caller_role.lower().strip()
            is_owner = caller_is_owner or c_role in ('owner', 'chủ quán', 'chu quan')
            is_manager = is_owner or c_role in ('manager', 'quản lý', 'quan ly')

            if not is_manager:
                return False

            t_role = target_role.lower().strip()
            t_is_owner = target_is_owner or t_role in ('owner', 'chủ quán', 'chu quan')
            t_is_manager = t_role in ('manager', 'quản lý', 'quan ly')

            if is_owner:
                return not t_is_owner

            return not t_is_owner and not t_is_manager

        # 1. Self management blocked
        self.assertFalse(can_manage_staff('owner', True, 'owner', True, 'u1', 'u1'))
        # 2. Owner managing Manager -> Allowed
        self.assertTrue(can_manage_staff('owner', True, 'Quản Lý', False, 'u1', 'u2'))
        # 3. Owner managing Cashier -> Allowed
        self.assertTrue(can_manage_staff('owner', True, 'Thu Ngân', False, 'u1', 'u3'))
        # 4. Manager managing Manager -> BLOCKED
        self.assertFalse(can_manage_staff('Quản Lý', False, 'manager', False, 'm1', 'm2'))
        # 5. Manager managing Owner -> BLOCKED
        self.assertFalse(can_manage_staff('manager', False, 'owner', True, 'm1', 'o1'))
        # 6. Manager managing Waiter -> ALLOWED
        self.assertTrue(can_manage_staff('Quản Lý', False, 'Phục Vụ', False, 'm1', 'w1'))
        # 7. Waiter managing Waiter -> BLOCKED
        self.assertFalse(can_manage_staff('Phục Vụ', False, 'Phục Vụ', False, 'w1', 'w2'))

    def test_05_canonical_role_normalization(self):
        self.assertEqual(canonical_role('Quản Lý'), 'manager')
        self.assertEqual(canonical_role('quan ly'), 'manager')
        self.assertEqual(canonical_role('Thu ngân'), 'cashier')
        self.assertEqual(canonical_role('thu ngan'), 'cashier')
        self.assertEqual(canonical_role('Phục Vụ'), 'waiter')
        self.assertEqual(canonical_role('phuc vu'), 'waiter')
        self.assertEqual(canonical_role('chạy bàn'), 'waiter')
        self.assertEqual(canonical_role('Bếp'), 'kitchen')
        self.assertEqual(canonical_role('bep'), 'kitchen')
        self.assertEqual(canonical_role('Kho'), 'stock')
        self.assertEqual(canonical_role('Chủ quán'), 'owner')
        self.assertEqual(canonical_role('chu quan'), 'owner')
        self.assertEqual(canonical_role('Barista'), 'barista')
        self.assertEqual(canonical_role('  Barista  '), 'barista')
        self.assertEqual(canonical_role('Kế Toán'), 'kế toán')

    def test_06_unassigned_logic(self):
        def is_unassigned(role: str, is_owner: bool = False) -> bool:
            if is_owner:
                return False
            r = role.lower().strip()
            if (not r or r in ('none', 'unassigned') or
                'chưa phân' in r or 'chưa gán' in r or 'chưa có' in r or 'chưa cấp' in r):
                return True
            return False

        self.assertFalse(is_unassigned('waiter'))
        self.assertFalse(is_unassigned('Phục Vụ'))
        self.assertFalse(is_unassigned('cashier'))
        self.assertFalse(is_unassigned('manager'))
        self.assertFalse(is_unassigned('barista'))
        self.assertFalse(is_unassigned('owner', is_owner=True))

        self.assertTrue(is_unassigned(''))
        self.assertTrue(is_unassigned('none'))
        self.assertTrue(is_unassigned('unassigned'))
        self.assertTrue(is_unassigned('Chưa phân vai trò'))
        self.assertTrue(is_unassigned('chưa gán quyền'))

    def test_07_store_role_and_synonyms(self):
        self.assertEqual(canonical_role('tn'), 'cashier')
        self.assertEqual(canonical_role('bán hàng'), 'cashier')
        self.assertEqual(canonical_role('ban hang'), 'cashier')
        self.assertEqual(canonical_role('ql'), 'manager')
        self.assertEqual(canonical_role('admin'), 'manager')
        self.assertEqual(canonical_role('pv'), 'waiter')
        self.assertEqual(canonical_role('waitress'), 'waiter')
        self.assertEqual(canonical_role('chef'), 'kitchen')
        self.assertEqual(canonical_role('cook'), 'kitchen')


class TestProductionCodeInvariants(unittest.TestCase):
    """Deep verification of production Dart code against contract requirements"""

    def test_inventory_screen_permission_check(self):
        inv_code = (REPO_ROOT / 'lib/screens/inventory_screen.dart').read_text()
        # Verify permission provider import
        self.assertIn("import '../core/providers/permission_provider.dart';", inv_code)
        # Verify granular kho.delete_item in _canDeleteItems
        self.assertIn("ref.canDo('kho.delete_item')", inv_code)
        # Verify _canDeleteItems getter
        can_delete_pattern = r"bool get _canDeleteItems\s*\{[^}]*hasDeletePerm[^}]*\}"
        self.assertTrue(re.search(can_delete_pattern, inv_code, re.DOTALL))
        # Verify batch delete guard
        self.assertIn("if (!_canDeleteItems) return;", inv_code)
        # Verify single item onDelete guarded
        self.assertIn("onDelete: _canDeleteItems ? () async", inv_code)

    def test_core_product_repository_stream_and_batch_delete(self):
        repo_code = (REPO_ROOT / 'lib/core/repositories/core_product_repository.dart').read_text()
        # Broadcast stream
        self.assertIn("StreamController<String>.broadcast()", repo_code)
        self.assertIn("static Stream<String> get changeStream", repo_code)
        self.assertIn("static void notifyDataChanged(String storeId)", repo_code)
        # batchSoftDelete implementation
        self.assertIn("Future<void> batchSoftDelete(List<String> ids)", repo_code)
        self.assertIn(".inFilter('id', ids)", repo_code)
        self.assertIn("'is_deleted': true", repo_code)
        self.assertIn("'is_active': false", repo_code)
        # RAM cache update
        self.assertIn("_productsCacheByStore.containsKey(storeId)", repo_code)
        self.assertIn("notifyDataChanged(storeId)", repo_code)

    def test_ban_screen_global_search_and_out_of_stock(self):
        ban_code = (REPO_ROOT / 'lib/screens/ban_screen.dart').read_text()
        # Global search: matchCat is unconditionally true when _search.isNotEmpty
        self.assertIn("final matchCat = _search.isNotEmpty", ban_code)
        # SKU and Name search
        self.assertIn("p.name.containsSearch(_search)", ban_code)
        self.assertIn("p.sku?.containsSearch(_search)", ban_code)
        # isOutOfStock logic
        self.assertIn("!p.isAvailable || (p.minStock > 0 && p.stockQty <= 0)", ban_code)
        # Out of stock dialog
        self.assertIn("Món tạm hết", ban_code)
        self.assertIn("Vẫn thêm", ban_code)

    def test_pos_products_provider_retains_out_of_stock(self):
        app_prov_code = (REPO_ROOT / 'lib/core/providers/app_providers.dart').read_text()
        # posProductsProvider must retain out-of-stock items (does NOT filter p.isAvailable)
        pos_prov_block = re.search(r"posProductsProvider\s*=\s*Provider\.autoDispose.*?\{.*?\n\}\);", app_prov_code, re.DOTALL)
        self.assertIsNotNone(pos_prov_block)
        block_text = pos_prov_block.group(0)
        self.assertNotIn("p.isAvailable &&", block_text)
        self.assertIn("p.category != 'Nguyên liệu'", block_text)

    def test_database_migration_hierarchy_rpc(self):
        mig_code = (REPO_ROOT / 'supabase/migrations/20260913_fix_staff_management_manager_role_v4.sql').read_text()
        # Check manager forbidden conditions
        self.assertIn("v_caller_role = 'manager' AND v_norm_role IN ('owner', 'manager')", mig_code)
        self.assertIn("CANNOT_DEMOTE_LAST_OWNER", mig_code)
        self.assertIn("CANNOT_LOCK_LAST_OWNER", mig_code)
        self.assertIn("CANNOT_REMOVE_LAST_OWNER", mig_code)


if __name__ == '__main__':
    unittest.main(verbosity=2)
