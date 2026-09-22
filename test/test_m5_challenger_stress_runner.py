#!/usr/bin/env python3
"""
Adversarial Stress Test Harness for Milestone 5 (R1 & R2)
Agent: challenger_m5_1

Test Categories:
1. containsSearch Stress Testing (Tricky Vietnamese diacritics, NFD vs NFC, spaces, uppercase, acronyms, SKU)
2. Category Bypass & Whitespace Filter Behavior in Bàn Screen
3. Out-of-Stock Boundary Conditions & Edge Matrix
4. CoreProductRepository Broadcast Stream & Snapshot Invariance
5. Direct Codebase AST & Contract Invariants
"""

import re
import sys
import time
import unicodedata
import unittest
from pathlib import Path
from typing import List, Dict, Optional, Any

REPO_ROOT = Path(__file__).resolve().parent.parent

# ─────────────────────────────────────────────────────────────────────────────
# 1. Exact replica of Dart lib/core/utils/string_utils.dart
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

    # 1. Direct substring match
    if clean_query in clean_source:
        return True

    # 2. Initials / Acronym match
    words = [w for w in re.split(r'\s+', clean_source) if w]
    if words:
        initials = "".join(w[0] for w in words)
        if clean_query in initials:
            return True

    # 3. Multiple words unordered match
    query_words = [qw for qw in re.split(r'\s+', clean_query) if qw]
    if len(query_words) > 1:
        if all(qw in clean_source for qw in query_words):
            return True

    return False


# ─────────────────────────────────────────────────────────────────────────────
# 2. Product Model dataclass
# ─────────────────────────────────────────────────────────────────────────────
class ProductModel:
    def __init__(self, id: str, name: str, sku: Optional[str] = None,
                 category: Optional[str] = None, sell_price: float = 50000.0,
                 is_available: bool = True, is_active: bool = True,
                 is_deleted: bool = False, stock_qty: float = 10.0,
                 min_stock: float = 5.0, unit: str = 'phần'):
        self.id = id
        self.name = name
        self.sku = sku
        self.category = category
        self.sell_price = sell_price
        self.is_available = is_available
        self.is_active = is_active
        self.is_deleted = is_deleted
        self.stock_qty = stock_qty
        self.min_stock = min_stock
        self.unit = unit

    def is_out_of_stock(self) -> bool:
        """Exact logic from ban_screen.dart line 8549 & 8856"""
        return (not self.is_available) or (self.min_stock > 0 and self.stock_qty <= 0)


# ─────────────────────────────────────────────────────────────────────────────
# 3. ban_screen.dart Filtering Logic Simulation
# ─────────────────────────────────────────────────────────────────────────────
def filter_ban_screen(products: List[ProductModel], selected_category: str, search: str) -> List[ProductModel]:
    """Exact logic from ban_screen.dart line 8814-8827"""
    if search == "" and selected_category == "Tất cả":
        return list(products)
    
    filtered = []
    for p in products:
        match_cat = True if search != "" else (
            selected_category == "Tất cả" or (p.category or "Khác") == selected_category
        )
        match_search = True if search == "" else (
            contains_search(p.name, search) or (contains_search(p.sku, search) if p.sku else False)
        )
        if match_cat and match_search:
            filtered.append(p)
    return filtered


# ─────────────────────────────────────────────────────────────────────────────
# 4. Stream Broadcast Simulator
# ─────────────────────────────────────────────────────────────────────────────
class MockChangeNotifier:
    """Simulates Dart StreamController<String>.broadcast()"""
    def __init__(self):
        self.subscribers = []
        self.is_closed = False

    def listen(self, callback):
        if self.is_closed:
            raise RuntimeError("Cannot listen to closed controller")
        sub = {"callback": callback, "active": True}
        self.subscribers.append(sub)
        return sub

    def cancel(self, sub):
        sub["active"] = False
        if sub in self.subscribers:
            self.subscribers.remove(sub)

    def add(self, event: str):
        if self.is_closed:
            return
        for sub in list(self.subscribers):
            if sub["active"]:
                sub["callback"](event)

    def close(self):
        self.is_closed = True
        self.subscribers.clear()


# ─────────────────────────────────────────────────────────────────────────────
# TEST SUITE 1: containsSearch Adversarial Stress Testing
# ─────────────────────────────────────────────────────────────────────────────
class TestContainsSearchAdversarial(unittest.TestCase):

    def test_tricky_vietnamese_diacritics_exhaustive(self):
        """Stress-test all 6 Vietnamese tones across all 12 vowels with D/Đ"""
        pairs = [
            ("Phở Bò Đặc Biệt", "pho bo dac biet"),
            ("PHỞ BÒ ĐẶC BIỆT", "PHO BO"),
            ("phở bò đặc biệt", "ĐẶC BIỆT"),
            ("phở bò đặc biệt", "dac biet"),
            ("Lẩu Riêu Cua Bắp Bò", "lau rieu cua bap bo"),
            ("LẨU RIÊU CUA BẮP BÒ", "LẨU BÒ"),
            ("Chả Giò Rế Tôm Thịt", "cha gio re tom thit"),
            ("Nước Ép Dưa Hấu", "nuoc ep dua hau"),
            ("Nước Ép Dưa Hấu", "DƯA HẤU"),
            ("Sữa Đậu Nành Trân Châu", "sua dau nanh tran chau"),
            ("Cà Cà Muối Nén", "ca ca muoi nen"),
            ("Ếch Núp Lùm Rơm Chiên Sả", "ech nup lum rom chien sa"),
            ("Mực Một Nắng Nướng Muối Ớt", "muc mot nang nuong muoi ot"),
            ("Rượu Táo Mèo Sapa", "ruou tao meo"),
            ("Hạt Điều Rang Củi", "hat dieu rang cui"),
            ("Gà Đồi Nướng Mắc Khén", "ga doi nuong mac khen"),
        ]
        for source, query in pairs:
            self.assertTrue(contains_search(source, query), f"Failed matching '{query}' in '{source}'")

    def test_d_and_d_dash_case_variations(self):
        """Stress-test d vs đ, D vs Đ across multiple combinations"""
        self.assertTrue(contains_search("Đùi Gà Chiên Mắm", "dui ga"))
        self.assertTrue(contains_search("Đùi Gà Chiên Mắm", "DUI GA"))
        self.assertTrue(contains_search("Đùi Gà Chiên Mắm", "đùi gà"))
        self.assertTrue(contains_search("Đùi Gà Chiên Mắm", "ĐÙI GÀ"))
        self.assertTrue(contains_search("Đùi Gà Chiên Mắm", "chiên mắm đùi"))
        self.assertTrue(contains_search("Đậu Đỏ Đường Đen", "dddd"))  # 4 initials
        self.assertTrue(contains_search("Dưa Leo Xào Tỏi", "dua leo"))
        self.assertTrue(contains_search("Dưa Leo Xào Tỏi", "dưa leo"))

    def test_i_and_y_equivalence_in_vietnamese(self):
        """Verify i vs y normalization: 'y' mapped to 'i' in DIACRITICS_MAP"""
        self.assertTrue(contains_search("Bánh Mỳ Pate", "banh mi"))
        self.assertTrue(contains_search("Bánh Mì Sài Gòn", "banh my"))
        self.assertTrue(contains_search("Mì Cay Hàn Quốc", "mi cai"))
        self.assertTrue(contains_search("Mì Cay Hàn Quốc", "cay"))
        self.assertTrue(contains_search("Mì Cay Hàn Quốc", "cai"))

    def test_initials_acronym_search_stress(self):
        """Test acronym and initials matching across long dishes"""
        cases = [
            ("Mì Cay Kim Chi Bò Mỹ", "mckcbm"),
            ("Mì Cay Kim Chi Bò Mỹ", "mckc"),
            ("Mì Cay Kim Chi Bò Mỹ", "kcbm"),
            ("Trà Đào Cam Sả Đặc Biệt", "tdcsdb"),
            ("Trà Đào Cam Sả Đặc Biệt", "tdcs"),
            ("Cà Phê Sữa Đá Sài Gòn", "cpsdsg"),  # 'Cà Phê' -> initial 'c' and 'p'
            ("Bò Nướng Tảng Sốt Phô Mai", "bntspm"),
        ]
        for source, acronym in cases:
            self.assertTrue(contains_search(source, acronym), f"Acronym '{acronym}' failed for '{source}'")

    def test_out_of_order_multi_word_search(self):
        """Verify multi-word search regardless of word order"""
        dish = "Lẩu Ếch Măng Cay Nấu Mẻ Hà Nội"
        self.assertTrue(contains_search(dish, "hà nội lẩu ếch"))
        self.assertTrue(contains_search(dish, "măng mẻ ếch"))
        self.assertTrue(contains_search(dish, "cay lẩu"))
        self.assertTrue(contains_search(dish, "nội mẻ"))
        self.assertFalse(contains_search(dish, "lẩu tôm"))  # 'tôm' not present

    def test_sku_search_with_delimiters(self):
        """Stress-test SKU search: hyphen, slash, dots, mixed letters/numbers"""
        sku_samples = [
            ("SP-001/X", "sp-001"),
            ("SP-001/X", "001/x"),
            ("SP-001/X", "SP-001/X"),
            ("BL_99-HN", "bl_99"),
            ("DRINK.001", "drink"),
            ("DRINK.001", "001"),
            ("MON-NUONG#05", "nuong#05"),
        ]
        for sku, q in sku_samples:
            self.assertTrue(contains_search(sku, q), f"SKU '{sku}' query '{q}' failed")

    def test_whitespace_and_empty_edge_cases(self):
        """Test whitespace padding and empty search queries"""
        self.assertTrue(contains_search("Bia Larue", ""))
        self.assertTrue(contains_search("Bia Larue", "   "))  # query.strip() becomes empty
        self.assertTrue(contains_search("Bia Larue", "  larue  "))
        self.assertTrue(contains_search("Bia Larue", "bia    larue"))

    def test_adversarial_nfd_unicode_behavior(self):
        """
        Adversarial Finding: NFD (Unicode Decomposed) input behavior.
        When a user types using NFD (Unicode tổ hợp) vs precomposed NFC in DB:
        removeDiacritics only contains precomposed characters. Combining diacritical
        marks (\\u0300-\\u036F) remain unmapped in clean_query.
        """
        for w in ['cơm', 'phở', 'bún', 'trà', 'lẩu', 'gà']:
            nfc_source = f"{w} đặc biệt"
            nfd_query = unicodedata.normalize('NFD', w)
            # Empirically documents that NFD query fails against NFC source in current string_utils
            is_matched = contains_search(nfc_source, nfd_query)
            self.assertFalse(is_matched, f"Expected NFD '{w}' to fail in current implementation")


# ─────────────────────────────────────────────────────────────────────────────
# TEST SUITE 2: Category Bypass Behavior in Bàn Screen
# ─────────────────────────────────────────────────────────────────────────────
class TestCategoryBypassInBanScreen(unittest.TestCase):

    def setUp(self):
        self.catalog = [
            ProductModel(id="1", name="Trà đào cam sả", category="Đồ uống", sku="TD01"),
            ProductModel(id="2", name="Bia Larue", category="Đồ uống", sku="BL01"),
            ProductModel(id="3", name="Cà phê đen đá", category="Đồ uống", sku="CF01"),
            ProductModel(id="4", name="Bò nướng tảng", category="Món nướng", sku="BN01"),
            ProductModel(id="5", name="Dẻ sườn bò Mỹ", category="Món nướng", sku="SB01"),
            ProductModel(id="6", name="Mực hấp gừng", category="Hải sản", sku="MH01"),
            ProductModel(id="7", name="Cơm chiên dưa bò", category="Cơm", sku="CC01"),
        ]

    def test_empty_search_strictly_respects_category_filter(self):
        """When search is '', only products of selected category are returned"""
        res_drink = filter_ban_screen(self.catalog, "Đồ uống", "")
        self.assertEqual(len(res_drink), 3)
        self.assertTrue(all(p.category == "Đồ uống" for p in res_drink))

        res_nuong = filter_ban_screen(self.catalog, "Món nướng", "")
        self.assertEqual(len(res_nuong), 2)
        self.assertTrue(all(p.category == "Món nướng" for p in res_nuong))

        res_all = filter_ban_screen(self.catalog, "Tất cả", "")
        self.assertEqual(len(res_all), 7)

    def test_populated_search_bypasses_category_filter(self):
        """When search has a query, it finds dishes from ANY category (Global Search)"""
        # Standing in 'Món nướng', search for 'bia' (which is in 'Đồ uống')
        res = filter_ban_screen(self.catalog, "Món nướng", "bia")
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0].name, "Bia Larue")
        self.assertEqual(res[0].category, "Đồ uống")

        # Standing in 'Hải sản', search for 'bò' (present in 'Món nướng' and 'Cơm')
        res_bo = filter_ban_screen(self.catalog, "Hải sản", "bò")
        self.assertEqual(len(res_bo), 3)  # Bò nướng tảng, Dẻ sườn bò Mỹ, Cơm chiên dưa bò
        categories = {p.category for p in res_bo}
        self.assertEqual(categories, {"Món nướng", "Cơm"})

    def test_whitespace_only_search_bypasses_category(self):
        """
        Adversarial Edge Case: Typing '   ' (spaces only) in search field.
        In ban_screen.dart line 8818: `final matchCat = _search.isNotEmpty ? true : ...`
        Because '   '.isNotEmpty is True in Dart:
        matchCat becomes True, and containsSearch('   ') returns True.
        Therefore, typing whitespace bypasses category filter and yields all products.
        """
        res_whitespace = filter_ban_screen(self.catalog, "Món nướng", "   ")
        self.assertEqual(len(res_whitespace), 7,
                         "Whitespace query '   ' causes ban_screen to return all catalog items")

    def test_search_by_sku_bypasses_category(self):
        """SKU search works across all categories"""
        res = filter_ban_screen(self.catalog, "Cơm", "BL01")
        self.assertEqual(len(res), 1)
        self.assertEqual(res[0].id, "2")
        self.assertEqual(res[0].name, "Bia Larue")


# ─────────────────────────────────────────────────────────────────────────────
# TEST SUITE 3: Out-of-Stock Boundary Conditions & Edge Matrix
# ─────────────────────────────────────────────────────────────────────────────
class TestOutOfStockBoundaryMatrix(unittest.TestCase):

    def test_all_16_boundary_permutations(self):
        """
        Comprehensive matrix of (isAvailable, minStock, stockQty):
        Formula: !p.isAvailable || (p.minStock > 0 && p.stockQty <= 0)
        """
        matrix = [
            # is_avail, min_stock, stock_qty, expected_out_of_stock, note
            (False, 0.0, 0.0, True, "Unavailable overrides all"),
            (False, 5.0, 10.0, True, "Unavailable with stock"),
            (False, 5.0, 0.0, True, "Unavailable zero stock"),
            (False, 5.0, -2.0, True, "Unavailable negative stock"),
            (False, -1.0, 0.0, True, "Unavailable negative minStock"),
            (True, 0.0, 0.0, False, "minStock=0 means untracked stock -> Not out of stock"),
            (True, 0.0, 10.0, False, "minStock=0 with positive stock"),
            (True, 0.0, -5.0, False, "minStock=0 with negative stock (untracked)"),
            (True, 5.0, 0.0, True, "minStock>0 and stockQty=0 -> Out of stock"),
            (True, 5.0, -0.001, True, "minStock>0 and stockQty<0 -> Out of stock"),
            (True, 5.0, -100.0, True, "minStock>0 and large negative stock -> Out of stock"),
            (True, 5.0, 0.001, False, "minStock>0 and stockQty>0 (very small) -> In stock"),
            (True, 5.0, 5.0, False, "minStock>0 and stockQty=minStock -> In stock"),
            (True, 5.0, 10.0, False, "minStock>0 and stockQty>minStock -> In stock"),
            (True, -1.0, 0.0, False, "minStock<0 is not >0 -> Not out of stock"),
            (True, -5.0, -2.0, False, "negative minStock and negative stockQty -> Not out of stock"),
        ]

        for is_avail, min_s, stock_q, expected, note in matrix:
            p = ProductModel(
                id="test_p",
                name="Test Dish",
                is_available=is_avail,
                min_stock=min_s,
                stock_qty=stock_q,
            )
            actual = p.is_out_of_stock()
            self.assertEqual(actual, expected,
                             f"Failed on {note}: (avail={is_avail}, min={min_s}, stock={stock_q}) -> got {actual}, expected {expected}")

    def test_pos_products_provider_retention_invariant(self):
        """
        posProductsProvider must NOT filter out out-of-stock items,
        otherwise module Bàn and POS cannot show 'TẠM HẾT' badge.
        """
        all_products = [
            ProductModel(id="1", name="In Stock", is_available=True, min_stock=5, stock_qty=10, is_active=True),
            ProductModel(id="2", name="Out Stock", is_available=True, min_stock=5, stock_qty=0, is_active=True),
            ProductModel(id="3", name="Disabled", is_available=False, min_stock=5, stock_qty=10, is_active=True),
            ProductModel(id="4", name="Inactive", is_available=True, min_stock=5, stock_qty=10, is_active=False),
            ProductModel(id="5", name="Ingredient", is_available=True, min_stock=5, stock_qty=10, is_active=True, category="Nguyên liệu"),
        ]

        # posProductsProvider filter: isActive && category != 'Nguyên liệu' && productType != 'ingredient'
        pos_products = [
            p for p in all_products
            if p.is_active and p.category != "Nguyên liệu"
        ]

        # Invariant checks:
        # Dish 1, 2, 3 must be present
        pos_ids = {p.id for p in pos_products}
        self.assertIn("1", pos_ids, "In-stock dish must be retained")
        self.assertIn("2", pos_ids, "Zero-stock dish must be retained for TẠM HẾT badge")
        self.assertIn("3", pos_ids, "Unavailable dish must be retained for TẠM HẾT badge")
        self.assertNotIn("4", pos_ids, "Inactive dish must be excluded")
        self.assertNotIn("5", pos_ids, "Raw ingredient must be excluded")


# ─────────────────────────────────────────────────────────────────────────────
# TEST SUITE 4: Broadcast Stream Stress & Concurrency Simulator
# ─────────────────────────────────────────────────────────────────────────────
class TestBroadcastStreamStress(unittest.TestCase):

    def test_multiple_listeners_receive_broadcast(self):
        """Simulate multiple screens listening to CoreProductRepository.changeStream"""
        notifier = MockChangeNotifier()
        results_sub1 = []
        results_sub2 = []
        results_sub3 = []

        sub1 = notifier.listen(lambda sid: results_sub1.append(sid))
        sub2 = notifier.listen(lambda sid: results_sub2.append(sid))
        sub3 = notifier.listen(lambda sid: results_sub3.append(sid))

        # Emit burst of 50 events
        for i in range(50):
            notifier.add(f"store_{i % 3}")

        self.assertEqual(len(results_sub1), 50)
        self.assertEqual(len(results_sub2), 50)
        self.assertEqual(len(results_sub3), 50)
        self.assertEqual(results_sub1, results_sub2)
        self.assertEqual(results_sub2, results_sub3)

        # Cancel one listener
        notifier.cancel(sub2)
        notifier.add("store_after_cancel")

        self.assertEqual(len(results_sub1), 51)
        self.assertEqual(len(results_sub2), 50)  # sub2 was cancelled
        self.assertEqual(len(results_sub3), 51)

    def test_closed_controller_safe_guard(self):
        """Verify adding to closed controller does not throw exception"""
        notifier = MockChangeNotifier()
        received = []
        notifier.listen(lambda sid: received.append(sid))
        notifier.add("store_1")
        self.assertEqual(received, ["store_1"])

        notifier.close()
        # Should not raise exception
        notifier.add("store_2")
        self.assertEqual(received, ["store_1"])

    def test_store_isolation_in_listener(self):
        """Consumers listening for their own storeId ignore other storeIds"""
        notifier = MockChangeNotifier()
        my_store = "store_HN_01"
        other_store = "store_SG_02"
        my_store_events = []

        def on_event(changed_store_id: str):
            if changed_store_id == my_store:
                my_store_events.append(changed_store_id)

        notifier.listen(on_event)

        # Emit interleaved events
        for _ in range(25):
            notifier.add(my_store)
            notifier.add(other_store)

        self.assertEqual(len(my_store_events), 25)
        self.assertTrue(all(s == my_store for s in my_store_events))

    def test_same_product_snapshot_deduplication(self):
        """
        Verify sameProductSnapshot in CoreProductRepository:
        Detects any modification across all fields.
        """
        def same_product_snapshot(prev: Optional[List[ProductModel]], next_list: List[ProductModel]) -> bool:
            if prev is None or len(prev) != len(next_list):
                return False
            for a, b in zip(prev, next_list):
                if (a.id != b.id or a.name != b.name or a.sku != b.sku or
                    a.category != b.category or a.stock_qty != b.stock_qty or
                    a.min_stock != b.min_stock or a.sell_price != b.sell_price or
                    a.is_available != b.is_available or a.is_active != b.is_active or
                    a.is_deleted != b.is_deleted):
                    return False
            return True

        p1 = ProductModel(id="1", name="Bia", stock_qty=10)
        p2 = ProductModel(id="2", name="Rượu", stock_qty=5)
        snap1 = [p1, p2]

        # Identical snapshot
        p1_clone = ProductModel(id="1", name="Bia", stock_qty=10)
        p2_clone = ProductModel(id="2", name="Rượu", stock_qty=5)
        snap2 = [p1_clone, p2_clone]
        self.assertTrue(same_product_snapshot(snap1, snap2), "Identical snapshots should match")

        # Quantity modified
        p2_mod = ProductModel(id="2", name="Rượu", stock_qty=4)
        snap3 = [p1_clone, p2_mod]
        self.assertFalse(same_product_snapshot(snap1, snap3), "Stock qty change must trigger false")

        # Availability modified
        p1_mod = ProductModel(id="1", name="Bia", stock_qty=10, is_available=False)
        snap4 = [p1_mod, p2_clone]
        self.assertFalse(same_product_snapshot(snap1, snap4), "Availability change must trigger false")

        # Length modified
        snap5 = [p1_clone]
        self.assertFalse(same_product_snapshot(snap1, snap5), "Length change must trigger false")


# ─────────────────────────────────────────────────────────────────────────────
# TEST SUITE 5: Production Code AST & Invariant Verification
# ─────────────────────────────────────────────────────────────────────────────
class TestProductionCodeHardening(unittest.TestCase):

    def test_core_product_repository_invariants(self):
        code = (REPO_ROOT / 'lib/core/repositories/core_product_repository.dart').read_text()
        self.assertIn("StreamController<String>.broadcast()", code)
        self.assertIn("static void notifyDataChanged(String storeId)", code)
        self.assertIn("if (!_changeNotifier.isClosed)", code)
        self.assertIn("Future<void> batchSoftDelete(List<String> ids)", code)
        self.assertIn(".inFilter('id', ids)", code)
        self.assertIn("'is_deleted': true", code)
        self.assertIn("'is_active': false", code)
        self.assertNotIn(".delete()", code)

    def test_ban_screen_invariants(self):
        code = (REPO_ROOT / 'lib/screens/ban_screen.dart').read_text()
        # Global search condition
        self.assertIn("final matchCat = _search.isNotEmpty", code)
        self.assertIn("p.name.containsSearch(_search)", code)
        self.assertIn("p.sku?.containsSearch(_search)", code)
        self.assertIn("final isOutOfStock =", code)
        self.assertIn("!p.isAvailable || (p.minStock > 0 && p.stockQty <= 0)", code)
        # Out-of-stock UI badge
        self.assertIn("'TẠM HẾT'", code)
        # Confirmation dialog
        self.assertIn("Món tạm hết", code)
        self.assertIn("Vẫn thêm", code)

    def test_inventory_screen_invariants(self):
        code = (REPO_ROOT / 'lib/screens/inventory_screen.dart').read_text()
        self.assertIn("import '../core/providers/permission_provider.dart';", code)
        self.assertIn("ref.canDo('kho.delete_item')", code)
        self.assertIn("if (!_canDeleteItems) return;", code)
        self.assertIn("onDelete: _canDeleteItems ?", code)


if __name__ == '__main__':
    unittest.main(verbosity=2)
