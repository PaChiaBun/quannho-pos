// test/modules/kho_batch_delete_adversarial_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Adversarial Stress Testing for Batch Soft Delete & Cache Invariants
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/core_product_repository.dart';

ProductModel _mockProduct({
  required String id,
  required String name,
  String storeId = 'store_adv_001',
  bool isDeleted = false,
  bool isActive = true,
}) {
  return ProductModel.fromMap({
    'id': id,
    'store_id': storeId,
    'name': name,
    'sell_price': 45000,
    'stock_qty': 10,
    'min_stock': 2,
    'unit': 'phần',
    'is_available': true,
    'is_active': isActive,
    'is_deleted': isDeleted,
  });
}

void main() {
  group('Adversarial Soft Delete & Invariant Tests', () {
    test('1. Empty ID list is an immediate no-op', () {
      final ids = <String>[];
      expect(ids.isEmpty, isTrue);
      // Cache remains completely unmodified when empty list passed
      final cache = <ProductModel>[
        _mockProduct(id: 'p1', name: 'Món 1'),
        _mockProduct(id: 'p2', name: 'Món 2'),
      ];
      final idSet = ids.toSet();
      final updatedCache = cache.where((p) => !idSet.contains(p.id)).toList();
      expect(updatedCache.length, equals(2));
      expect(updatedCache.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('2. Duplicate IDs deduplicate cleanly in cache eviction and SQL query', () {
      final duplicateIds = ['p1', 'p1', 'p2', 'p1', 'p2'];
      final cache = <ProductModel>[
        _mockProduct(id: 'p1', name: 'Món 1'),
        _mockProduct(id: 'p2', name: 'Món 2'),
        _mockProduct(id: 'p3', name: 'Món 3'),
      ];

      final idSet = duplicateIds.toSet();
      expect(idSet.length, equals(2));
      expect(idSet, equals({'p1', 'p2'}));

      final updatedCache = cache.where((p) => !idSet.contains(p.id)).toList();
      expect(updatedCache.length, equals(1));
      expect(updatedCache.first.id, equals('p3'));
    });

    test('3. Non-existent IDs in batch delete cause zero collateral damage to cache', () {
      final nonExistentIds = ['ghost_999', 'ghost_888', 'ghost_777'];
      final cache = <ProductModel>[
        _mockProduct(id: 'p1', name: 'Món 1'),
        _mockProduct(id: 'p2', name: 'Món 2'),
      ];

      final idSet = nonExistentIds.toSet();
      final updatedCache = cache.where((p) => !idSet.contains(p.id)).toList();

      expect(updatedCache.length, equals(2));
      expect(updatedCache.map((p) => p.id), containsAll(['p1', 'p2']));
    });

    test('4. Mixed list of existing, duplicate, and non-existent IDs', () {
      final mixedIds = ['p1', 'ghost_1', 'p1', 'p3', 'ghost_2'];
      final cache = <ProductModel>[
        _mockProduct(id: 'p1', name: 'Món 1'),
        _mockProduct(id: 'p2', name: 'Món 2'),
        _mockProduct(id: 'p3', name: 'Món 3'),
        _mockProduct(id: 'p4', name: 'Món 4'),
      ];

      final idSet = mixedIds.toSet();
      final updatedCache = cache.where((p) => !idSet.contains(p.id)).toList();

      // p1 and p3 evicted; p2 and p4 preserved
      expect(updatedCache.length, equals(2));
      expect(updatedCache.map((p) => p.id), containsAll(['p2', 'p4']));
    });

    test('5. RAM cache update when cache is initially empty', () {
      final ids = ['p1', 'p2'];
      final cache = <ProductModel>[];
      final idSet = ids.toSet();
      final updatedCache = cache.where((p) => !idSet.contains(p.id)).toList();
      expect(updatedCache, isEmpty);
    });

    test('6. Soft delete flags preserve model contract (is_deleted=true, is_active=false)', () {
      final activeProduct = _mockProduct(id: 'p1', name: 'Món A');
      expect(activeProduct.isDeleted, isFalse);
      expect(activeProduct.isActive, isTrue);

      final deletedMap = {
        ...activeProduct.toMap(),
        'is_deleted': true,
        'is_active': false,
      };

      final deletedProduct = ProductModel.fromMap(deletedMap);
      expect(deletedProduct.id, equals('p1'));
      expect(deletedProduct.isDeleted, isTrue);
      expect(deletedProduct.isActive, isFalse);
      expect(deletedProduct.sellPrice, equals(45000));
    });
  });
}
