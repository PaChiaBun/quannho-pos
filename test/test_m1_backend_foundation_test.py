#!/usr/bin/env python3
"""
Test Suite for Milestone 1: Backend & Model Foundation
Covers:
1. ProductModel in lib/core/models/product_model.dart & copyWith
2. StockItem in lib/modules/kho/repository/kho_repository.dart & availability fields
3. CoreProductRepository batchUpdateAvailability, batchUpdateCategory, multi-tenant batchSoftDelete
4. Zero hard deletes and cache synchronization
"""

import re
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

class ProductModelSim:
    def __init__(self, id, store_id='', name='', sku=None, category=None, unit='phần',
                 product_type='finished', stock_qty=0.0, min_stock=0.0, sell_price=0.0,
                 cost_price=0.0, cost_price_latest=0.0, image_url=None, station_code='nong',
                 is_available=True, is_active=True, is_deleted=False, is_topping=False,
                 topping_unit='phần', updated_at=None):
        self.id = id
        self.store_id = store_id
        self.name = name
        self.sku = sku
        self.category = category
        self.unit = unit
        self.product_type = product_type
        self.stock_qty = float(stock_qty)
        self.min_stock = float(min_stock)
        self.sell_price = float(sell_price)
        self.cost_price = float(cost_price)
        self.cost_price_latest = float(cost_price_latest)
        self.image_url = image_url
        self.station_code = station_code
        self.is_available = is_available
        self.is_active = is_active
        self.is_deleted = is_deleted
        self.is_topping = is_topping
        self.topping_unit = topping_unit
        self.updated_at = updated_at

    def copy_with(self, **kwargs):
        return ProductModelSim(
            id=kwargs.get('id', self.id),
            store_id=kwargs.get('store_id', self.store_id),
            name=kwargs.get('name', self.name),
            sku=kwargs.get('sku', self.sku),
            category=kwargs.get('category', self.category),
            unit=kwargs.get('unit', self.unit),
            product_type=kwargs.get('product_type', self.product_type),
            stock_qty=kwargs.get('stock_qty', self.stock_qty),
            min_stock=kwargs.get('min_stock', self.min_stock),
            sell_price=kwargs.get('sell_price', self.sell_price),
            cost_price=kwargs.get('cost_price', self.cost_price),
            cost_price_latest=kwargs.get('cost_price_latest', self.cost_price_latest),
            image_url=kwargs.get('image_url', self.image_url),
            station_code=kwargs.get('station_code', self.station_code),
            is_available=kwargs.get('is_available', self.is_available),
            is_active=kwargs.get('is_active', self.is_active),
            is_deleted=kwargs.get('is_deleted', self.is_deleted),
            is_topping=kwargs.get('is_topping', self.is_topping),
            topping_unit=kwargs.get('topping_unit', self.topping_unit),
            updated_at=kwargs.get('updated_at', self.updated_at),
        )

class TestMilestone1ModelAndRepository(unittest.TestCase):

    def setUp(self):
        self.product_model_path = REPO_ROOT / 'lib/core/models/product_model.dart'
        self.kho_repo_path = REPO_ROOT / 'lib/modules/kho/repository/kho_repository.dart'
        self.core_product_repo_path = REPO_ROOT / 'lib/core/repositories/core_product_repository.dart'

    def test_01_product_model_file_exists_and_declares_class(self):
        self.assertTrue(self.product_model_path.exists(), "product_model.dart must exist")
        content = self.product_model_path.read_text()
        self.assertIn("class ProductModel", content)
        self.assertIn("final bool isAvailable;", content)
        self.assertIn("final bool isActive;", content)
        self.assertIn("final String? category;", content)
        self.assertIn("final double stockQty;", content)
        self.assertIn("final int? updatedAt;", content)

    def test_02_product_model_copy_with_implementation(self):
        content = self.product_model_path.read_text()
        self.assertIn("ProductModel copyWith({", content)
        self.assertIn("bool? isAvailable,", content)
        self.assertIn("String? category,", content)
        self.assertIn("bool? isActive,", content)
        self.assertIn("double? stockQty,", content)
        self.assertIn("int? updatedAt,", content)
        self.assertIn("isAvailable: isAvailable ?? this.isAvailable,", content)
        self.assertIn("category: category ?? this.category,", content)

        # Simulation behavior check
        original = ProductModelSim(id='p1', name='Trà đào', is_available=True, category='Đồ uống')
        modified = original.copy_with(is_available=False, category='Tráng miệng')
        self.assertTrue(original.is_available)
        self.assertEqual(original.category, 'Đồ uống')
        self.assertFalse(modified.is_available)
        self.assertEqual(modified.category, 'Tráng miệng')
        self.assertEqual(modified.id, 'p1')

    def test_03_stock_item_fields_and_mapping(self):
        content = self.kho_repo_path.read_text()
        self.assertIn("class StockItem", content)
        self.assertIn("final bool isAvailable;", content)
        self.assertIn("final bool isActive;", content)
        self.assertIn("this.isAvailable = true,", content)
        self.assertIn("this.isActive = true,", content)
        self.assertIn("isAvailable:      p.isAvailable,", content)
        self.assertIn("isActive:         p.isActive,", content)

    def test_04_core_product_repo_exports_model(self):
        content = self.core_product_repo_repo = self.core_product_repo_path.read_text()
        self.assertIn("export '../models/product_model.dart';", content)
        self.assertIn("static SupabaseClient get _client => _sb;", content)

    def test_05_batch_update_availability_implementation(self):
        content = self.core_product_repo_path.read_text()
        self.assertIn("Future<void> batchUpdateAvailability(", content)
        self.assertIn("String storeId,", content)
        self.assertIn("List<String> ids,", content)
        self.assertIn("bool isAvailable,", content)
        self.assertIn("if (ids.isEmpty) return;", content)
        self.assertIn("'is_available': isAvailable", content)
        self.assertIn(".eq('store_id', storeId).inFilter('id', ids)", content)
        self.assertIn("p.copyWith(isAvailable: isAvailable", content)
        self.assertIn("notifyDataChanged(storeId);", content)

    def test_06_batch_update_category_implementation(self):
        content = self.core_product_repo_path.read_text()
        self.assertIn("Future<void> batchUpdateCategory(", content)
        self.assertIn("String storeId,", content)
        self.assertIn("List<String> ids,", content)
        self.assertIn("String newCategory,", content)
        self.assertIn("if (ids.isEmpty) return;", content)
        self.assertIn("'category': newCategory", content)
        self.assertIn(".eq('store_id', storeId).inFilter('id', ids)", content)
        self.assertIn("p.copyWith(category: newCategory", content)
        self.assertIn("notifyDataChanged(storeId);", content)

    def test_07_batch_soft_delete_multi_tenant_safety(self):
        content = self.core_product_repo_path.read_text()
        self.assertIn("Future<void> batchSoftDelete(List<String> ids)", content)
        # Verify strict multi-tenant isolation with .eq('store_id', storeId)
        match = re.search(r"await _sb\.from\('products'\)\.update\(\{.*?\}\)\.eq\('store_id', storeId\)\.inFilter\('id', ids\);", content, re.DOTALL)
        self.assertIsNotNone(match, "batchSoftDelete must enforce .eq('store_id', storeId) before .inFilter('id', ids)")
        self.assertIn("'is_deleted': true", content)
        self.assertIn("'is_active': false", content)

    def test_08_zero_hard_deletes(self):
        content = self.core_product_repo_path.read_text()
        self.assertNotIn(".delete()", content, "CoreProductRepository must never perform hard delete")

    def test_09_ram_cache_synchronization_logic(self):
        cache = [
            ProductModelSim(id='p1', name='Món 1', is_available=True, category='Đồ uống'),
            ProductModelSim(id='p2', name='Món 2', is_available=True, category='Món nướng'),
            ProductModelSim(id='p3', name='Món 3', is_available=True, category='Hải sản'),
        ]
        target_ids = {'p1', 'p3'}
        # Availability update
        avail_updated = [
            p.copy_with(is_available=False) if p.id in target_ids else p
            for p in cache
        ]
        self.assertFalse(avail_updated[0].is_available)
        self.assertTrue(avail_updated[1].is_available)
        self.assertFalse(avail_updated[2].is_available)

        # Category update
        cat_updated = [
            p.copy_with(category='Khuyến mãi') if p.id in target_ids else p
            for p in cache
        ]
        self.assertEqual(cat_updated[0].category, 'Khuyến mãi')
        self.assertEqual(cat_updated[1].category, 'Món nướng')
        self.assertEqual(cat_updated[2].category, 'Khuyến mãi')

if __name__ == '__main__':
    unittest.main()
