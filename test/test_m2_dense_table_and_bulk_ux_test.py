#!/usr/bin/env python3
"""
Test Suite: Milestone 2 — InventoryScreen Dense Data Table & Bulk UX Redesign
Verifies all 5 Scope & Task requirements for Milestone 2:
1. 100% Full-Width Layout (removal of _InventoryRightPanel & 280px sidebar)
2. Dense Data Table Layout (8 columns, itemExtent: 50.0, min-width 820px horizontal scroll, row tap navigation)
3. Sticky Top Bar & Anti-Overlap UX (elimination of bottom floating bar, docked sticky top bar, bulk actions)
4. Single Row Actions via 3-dots Menu (PopupMenuButton with edit, receive, adjust, history, delete)
5. Hierarchy Guard & Permissions (_canManageBulk, _canDeleteItems, _canEditItems, zero hard delete)
"""

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
INV_SCREEN_PATH = REPO_ROOT / 'lib/screens/inventory_screen.dart'
CORE_REPO_PATH = REPO_ROOT / 'lib/core/repositories/core_product_repository.dart'


class TestM2FullWidthLayout(unittest.TestCase):
    """Task 1: 100% Full-Width Layout (Remove Right Sidebar)"""

    def setUp(self):
        self.code = INV_SCREEN_PATH.read_text(encoding='utf-8')

    def test_no_right_sidebar_row_in_build(self):
        # Must not have Row with Expanded(flex: 3) and 280px sidebar
        self.assertNotIn("Expanded(flex: 3, child: mainBody)", self.code)
        self.assertNotIn("width: 280", self.code)
        self.assertNotIn("_InventoryRightPanel", self.code)

    def test_main_body_occupies_full_width(self):
        # Scaffold body must directly be mainBody
        match = re.search(r"return\s+Scaffold\(\s*backgroundColor:\s*_kBg,\s*body:\s*mainBody,\s*\);", self.code)
        self.assertIsNotNone(match, "Scaffold body must be mainBody directly without split LayoutBuilder")


class TestM2DenseDataTableLayout(unittest.TestCase):
    """Task 2: Dense Data Table Layout (8 Columns, itemExtent: 50.0, responsive horizontal scroll)"""

    def setUp(self):
        self.code = INV_SCREEN_PATH.read_text(encoding='utf-8')

    def test_item_extent_50_fixed_height(self):
        # Verify ListView.builder uses itemExtent: 50.0 for dense performance
        self.assertIn("itemExtent: 50.0", self.code)

    def test_dual_axis_responsive_scroll(self):
        # Table must use horizontal SingleChildScrollView with min-width ~820px
        self.assertIn("scrollDirection: Axis.horizontal", self.code)
        self.assertIn("math.max(820.0,", self.code)

    def test_table_header_8_columns(self):
        # Verify 8 header columns
        # Col 1: Checkbox (44px) - Master "Chọn tất cả" checkbox
        self.assertIn("width: 44", self.code)
        # Col 2: Ảnh/Icon (48px)
        self.assertIn("width: 48", self.code)
        # Col 3: Tên món & SKU (Expanded / Flex)
        self.assertIn("Tên món & SKU", self.code)
        # Col 4: Danh mục (110px)
        self.assertIn("width: 110", self.code)
        self.assertIn("'Danh mục'", self.code)
        # Col 5: Tồn kho & Min stock (110px)
        self.assertIn("'Tồn kho & Min'", self.code)
        # Col 6: Giá bán (110px)
        self.assertIn("'Giá bán'", self.code)
        # Col 7: Trạng thái kinh doanh (120px)
        self.assertIn("width: 120", self.code)
        self.assertIn("'Trạng thái'", self.code)
        # Col 8: Thao tác (46px)
        self.assertIn("width: 46", self.code)

    def test_table_row_components(self):
        # Col 1: Checkbox
        self.assertIn("Checkbox(", self.code)
        # Col 2: Product thumbnail 32x32
        self.assertIn("width: 32", self.code)
        self.assertIn("height: 32", self.code)
        # Col 3: Product name and SKU
        self.assertIn("item.name", self.code)
        self.assertIn("item.sku", self.code)
        # Col 4: Category
        self.assertIn("item.category", self.code)
        # Col 5: Stock quantity & minStock color coding
        self.assertIn("item.stockQty", self.code)
        self.assertIn("item.minStock", self.code)
        # Col 6: Formatted price
        self.assertIn("fmtMoney(item.sellPrice)", self.code)
        # Col 7: Business status badge ("Đang bán" vs "Tạm ngưng bán")
        self.assertIn("'Đang bán'", self.code)
        self.assertIn("'Tạm ngưng bán'", self.code)
        self.assertIn("item.isAvailable && item.isActive", self.code)
        # Col 8: 3-dots popup menu
        self.assertIn("PopupMenuButton<String>", self.code)

    def test_whole_row_tap_opens_edit(self):
        # Tapping row InkWell must trigger onRowTap
        self.assertIn("InkWell(\n        onTap: onRowTap,", self.code)


class TestM2StickyTopBarAndAntiOverlap(unittest.TestCase):
    """Task 3: Sticky Top Bar & Anti-Overlap UX"""

    def setUp(self):
        self.code = INV_SCREEN_PATH.read_text(encoding='utf-8')

    def test_bottom_floating_bar_removed(self):
        # Must not contain bottom Positioned floating bar
        self.assertNotIn("_buildMultiSelectActionBar()", self.code)
        # Must not have bottom padding 90 hack
        self.assertNotIn("isMultiSelect ? 90 : 24", self.code)
        self.assertNotIn("isMultiSelect ? 90 : 80", self.code)

    def test_sticky_top_bar_docked_above_table(self):
        # Sticky Top Bar rendered when selectedIds.isNotEmpty && canManageBulk
        self.assertIn("if (selectedIds.isNotEmpty && canManageBulk)", self.code)
        self.assertIn("_buildStickyTopBar(context, categories)", self.code)

    def test_sticky_top_bar_actions(self):
        # 1. Hủy chọn button with count
        self.assertIn("Hủy chọn", self.code)
        self.assertIn("Đã chọn: $count món", self.code)
        # 2. Bật bán button
        self.assertIn("'Bật bán'", self.code)
        self.assertIn("onBatchAvailability(true)", self.code)
        # 3. Tắt bán button
        self.assertIn("'Tắt bán'", self.code)
        self.assertIn("onBatchAvailability(false)", self.code)
        # 4. Đổi danh mục button
        self.assertIn("'Đổi danh mục'", self.code)
        self.assertIn("onBatchCategory(categories)", self.code)
        # 5. Xóa (X) món button
        self.assertIn("Xóa ($count) món", self.code)
        self.assertIn("onBatchDelete", self.code)

    def test_batch_action_handlers_implementation(self):
        # batchUpdateAvailability called with storeId, ids, boolean
        self.assertIn("CoreProductRepository.instance.batchUpdateAvailability", self.code)
        # batchUpdateCategory called with storeId, ids, newCategory
        self.assertIn("CoreProductRepository.instance.batchUpdateCategory", self.code)
        # batchSoftDelete called
        self.assertIn("batchSoftDelete(idsToDelete)", self.code)


class TestM2SingleRowActionsMenu(unittest.TestCase):
    """Task 4: Single Row Actions via 3-dots Menu (⋮)"""

    def setUp(self):
        self.code = INV_SCREEN_PATH.read_text(encoding='utf-8')

    def test_3_dots_popup_menu_options(self):
        # Check all required menu items
        self.assertIn("value: 'edit'", self.code)
        self.assertIn("'Sửa thông tin món'", self.code)
        self.assertIn("value: 'receive'", self.code)
        self.assertIn("'Nhập kho'", self.code)
        self.assertIn("value: 'adjust'", self.code)
        self.assertIn("'Điều chỉnh tồn kho'", self.code)
        self.assertIn("value: 'history'", self.code)
        self.assertIn("'Lịch sử xuất nhập'", self.code)
        self.assertIn("value: 'delete'", self.code)
        self.assertIn("'Xóa món'", self.code)

    def test_single_delete_guarded_by_permission(self):
        self.assertIn("if (canDeleteItems) ...[", self.code)
        self.assertIn("value: 'delete'", self.code)


class TestM2HierarchyGuardAndIntegrity(unittest.TestCase):
    """Task 5: Hierarchy Guard & Permissions"""

    def setUp(self):
        self.code = INV_SCREEN_PATH.read_text(encoding='utf-8')

    def test_can_manage_bulk_getter(self):
        match = re.search(r"bool get _canManageBulk\s*\{([^}]+)\}", self.code)
        self.assertIsNotNone(match, "_canManageBulk getter must exist")
        body = match.group(1)
        self.assertIn("session.isOwner || r == 'owner' || r == 'manager' || hasDeletePerm || hasEditPerm", body)

    def test_can_delete_items_getter(self):
        match = re.search(r"bool get _canDeleteItems\s*\{([^}]+)\}", self.code)
        self.assertIsNotNone(match, "_canDeleteItems getter must exist")
        body = match.group(1)
        self.assertIn("session.isOwner || r == 'owner' || r == 'manager' || hasDeletePerm", body)

    def test_zero_hard_delete_in_inventory_screen(self):
        # Must never call hard delete .delete() on product repository
        self.assertNotIn("productRepositoryProvider).delete(", self.code)
        self.assertNotIn("CoreProductRepository.instance.delete(", self.code)

    def test_batch_delete_early_guard(self):
        match = re.search(r"Future<void> _confirmBatchDelete\(\)\s*async\s*\{([^}]+)\}", self.code)
        self.assertIsNotNone(match)
        body = match.group(1)
        self.assertTrue(body.strip().startswith("if (!_canDeleteItems) return;"))


if __name__ == '__main__':
    unittest.main(verbosity=2)
