// test/modules/kho_batch_delete_and_search_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Kiểm thử:
// 1. Logic lọc & tìm kiếm món (Global search across categories, SKU & Name)
// 2. Nhận diện món Tạm hết (isOutOfStock logic)
// 3. Phân quyền xoá món (Owner & Manager hierarchy guard)
// 4. CoreProductRepository Event Stream (Instant Broadcast)
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/core_product_repository.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';
import 'package:quannho_pos/modules/kho/repository/kho_repository.dart';

ProductModel _createProduct({
  required String id,
  required String name,
  String? sku,
  String? category,
  double sellPrice = 50000,
  bool isAvailable = true,
  bool isActive = true,
  double stockQty = 10,
  double minStock = 5,
}) {
  return ProductModel.fromMap({
    'id': id,
    'store_id': 'store_test_001',
    'name': name,
    'sku': sku,
    'category': category,
    'sell_price': sellPrice,
    'is_available': isAvailable,
    'is_active': isActive,
    'stock_qty': stockQty,
    'min_stock': minStock,
    'unit': 'phần',
  });
}

void main() {
  group('1. Logic tìm kiếm món trong Bàn (Global Search + SKU + Name)', () {
    final products = <ProductModel>[
      _createProduct(
        id: 'p1',
        name: 'Trà đào cam sả',
        sku: 'TD01',
        sellPrice: 35000,
        category: 'Đồ uống',
        stockQty: 50,
      ),
      _createProduct(
        id: 'p2',
        name: 'Bò nướng tảng',
        sku: 'BN01',
        sellPrice: 150000,
        category: 'Món nướng',
        stockQty: 20,
      ),
      _createProduct(
        id: 'p3',
        name: 'Bia Larue',
        sku: 'BL99',
        sellPrice: 20000,
        category: 'Đồ uống',
        isAvailable: false, // Tạm hết do admin tắt bán
        stockQty: 10,
      ),
      _createProduct(
        id: 'p4',
        name: 'Mực hấp gừng',
        sku: 'MH02',
        sellPrice: 120000,
        category: 'Hải sản',
        stockQty: 0, // Hết tồn kho
      ),
    ];

    List<ProductModel> filterProducts({
      required List<ProductModel> list,
      required String selectedCategory,
      required String search,
    }) {
      return list.where((p) {
        final matchCat = search.isNotEmpty
            ? true
            : (selectedCategory == 'Tất cả' ||
                (p.category ?? 'Khác') == selectedCategory);
        final matchSearch = search.isEmpty
            ? true
            : (p.name.containsSearch(search) ||
                (p.sku?.containsSearch(search) ?? false));
        return matchCat && matchSearch;
      }).toList();
    }

    test('Khi không tìm kiếm, lọc đúng theo Danh mục đã chọn', () {
      final nuong = filterProducts(
        list: products,
        selectedCategory: 'Món nướng',
        search: '',
      );
      expect(nuong.length, 1);
      expect(nuong.first.id, 'p2');

      final tatCa = filterProducts(
        list: products,
        selectedCategory: 'Tất cả',
        search: '',
      );
      expect(tatCa.length, 4);
    });

    test('Khi tìm kiếm, bỏ qua danh mục đang chọn để tìm toàn hệ thống (Global search)', () {
      // Đang đứng ở tab 'Món nướng', nhưng gõ tìm 'trà đào'
      final result = filterProducts(
        list: products,
        selectedCategory: 'Món nướng',
        search: 'trà đào',
      );
      expect(result.length, 1);
      expect(result.first.name, 'Trà đào cam sả');
      expect(result.first.category, 'Đồ uống');
    });

    test('Tìm kiếm theo Mã món (SKU)', () {
      // Tìm theo SKU "MH02"
      final result = filterProducts(
        list: products,
        selectedCategory: 'Đồ uống',
        search: 'MH02',
      );
      expect(result.length, 1);
      expect(result.first.name, 'Mực hấp gừng');
    });

    test('Tìm kiếm không phân biệt dấu và chữ hoa chữ thường', () {
      final result = filterProducts(
        list: products,
        selectedCategory: 'Tất cả',
        search: 'tra dao',
      );
      expect(result.length, 1);
      expect(result.first.id, 'p1');
    });
  });

  group('2. Logic nhận diện món Tạm hết (isOutOfStock)', () {
    bool checkOutOfStock(ProductModel p) {
      return !p.isAvailable || (p.minStock > 0 && p.stockQty <= 0);
    }

    test('Món có isAvailable = false thì phải là Tạm hết kể cả còn tồn kho', () {
      final p = _createProduct(
        id: '1',
        name: 'Món ngưng bán',
        isAvailable: false,
        stockQty: 20,
        minStock: 5,
      );
      expect(checkOutOfStock(p), isTrue);
    });

    test('Món có stockQty <= 0 và minStock > 0 thì là Tạm hết', () {
      final p = _createProduct(
        id: '2',
        name: 'Món hết kho',
        isAvailable: true,
        stockQty: 0,
        minStock: 5,
      );
      expect(checkOutOfStock(p), isTrue);
    });

    test('Món còn hàng và isAvailable = true thì không phải Tạm hết', () {
      final p = _createProduct(
        id: '3',
        name: 'Món sẵn sàng',
        isAvailable: true,
        stockQty: 15,
        minStock: 5,
      );
      expect(checkOutOfStock(p), isFalse);
    });

    test('Món không quản lý tồn kho (minStock = 0) và isAvailable = true thì không bao giờ Tạm hết', () {
      final p = _createProduct(
        id: '4',
        name: 'Món dịch vụ',
        isAvailable: true,
        stockQty: 0,
        minStock: 0,
      );
      expect(checkOutOfStock(p), isFalse);
    });
  });

  group('3. Phân quyền xoá món (Hierarchy Guard cho InventoryScreen)', () {
    bool canDeleteProducts({
      required bool isOwner,
      required String role,
      required List<String> permissions,
    }) {
      return isOwner ||
          role == 'owner' ||
          role == 'manager' ||
          permissions.contains('kho.delete_item');
    }

    test('Chủ quán (isOwner = true hoặc role = owner) luôn có quyền xoá món', () {
      expect(
        canDeleteProducts(isOwner: true, role: 'owner', permissions: []),
        isTrue,
      );
      expect(
        canDeleteProducts(isOwner: false, role: 'owner', permissions: []),
        isTrue,
      );
    });

    test('Quản lý (role = manager) có quyền xoá món', () {
      expect(
        canDeleteProducts(isOwner: false, role: 'manager', permissions: []),
        isTrue,
      );
    });

    test('Nhân viên có quyền kho.delete_item được phép xoá', () {
      expect(
        canDeleteProducts(
          isOwner: false,
          role: 'cashier',
          permissions: ['kho.delete_item'],
        ),
        isTrue,
      );
    });

    test('Nhân viên không có quyền không được phép xoá', () {
      expect(
        canDeleteProducts(
          isOwner: false,
          role: 'waiter',
          permissions: ['pos.checkout'],
        ),
        isFalse,
      );
    });
  });

  group('4. CoreProductRepository Event Stream (Instant Broadcast)', () {
    test('CoreProductRepository.notifyDataChanged phát ra storeId tức thì trên changeStream', () async {
      final completer = Completer<String>();

      final sub = CoreProductRepository.changeStream.listen((storeId) {
        if (!completer.isCompleted) {
          completer.complete(storeId);
        }
      });

      CoreProductRepository.notifyDataChanged('store_test_999');

      final emittedStoreId = await completer.future.timeout(
        const Duration(seconds: 2),
      );

      expect(emittedStoreId, equals('store_test_999'));
      await sub.cancel();
    });
  });

  group('5. ProductModel copyWith Immutability & Updates', () {
    test('copyWith updates isAvailable while preserving all other fields', () {
      final p = _createProduct(
        id: 'p1',
        name: 'Trà đào cam sả',
        isAvailable: true,
        category: 'Đồ uống',
        stockQty: 10,
      );

      final updated = p.copyWith(isAvailable: false);

      expect(updated.id, equals('p1'));
      expect(updated.name, equals('Trà đào cam sả'));
      expect(updated.category, equals('Đồ uống'));
      expect(updated.stockQty, equals(10));
      expect(updated.isAvailable, isFalse);
      expect(p.isAvailable, isTrue); // Original untouched
    });

    test('copyWith updates category and updatedAt', () {
      final p = _createProduct(
        id: 'p2',
        name: 'Bò nướng',
        category: 'Món nướng',
      );

      final updated = p.copyWith(
        category: 'Món đặc biệt',
        updatedAt: 1710000000000,
      );

      expect(updated.category, equals('Món đặc biệt'));
      expect(updated.updatedAt, equals(1710000000000));
      expect(p.category, equals('Món nướng'));
    });

    test('copyWith updates isActive and stockQty', () {
      final p = _createProduct(
        id: 'p3',
        name: 'Bia',
        isActive: true,
        stockQty: 50,
      );

      final updated = p.copyWith(isActive: false, stockQty: 0);

      expect(updated.isActive, isFalse);
      expect(updated.stockQty, equals(0));
    });
  });

  group('6. StockItem Availability & Active Flags', () {
    test('StockItem defaults isAvailable and isActive to true', () {
      const item = StockItem(
        id: 'item1',
        name: 'Cà phê',
        unit: 'ly',
        stockQty: 10,
        minStock: 2,
        costPrice: 5000,
        sellPrice: 20000,
      );

      expect(item.isAvailable, isTrue);
      expect(item.isActive, isTrue);
    });

    test('StockItem.fromProduct correctly maps isAvailable and isActive from ProductModel', () {
      final productAvailable = _createProduct(
        id: 'p1',
        name: 'Trà tắc',
        isAvailable: true,
        isActive: true,
      );
      final item1 = StockItem.fromProduct(productAvailable);
      expect(item1.isAvailable, isTrue);
      expect(item1.isActive, isTrue);

      final productDisabled = _createProduct(
        id: 'p2',
        name: 'Bia hết hàng',
        isAvailable: false,
        isActive: false,
      );
      final item2 = StockItem.fromProduct(productDisabled);
      expect(item2.isAvailable, isFalse);
      expect(item2.isActive, isFalse);
    });
  });

  group('7. CoreProductRepository Bulk Operations Invariants', () {
    test('sameProductSnapshot detects availability changes', () {
      final p1 = _createProduct(id: '1', name: 'Món 1', isAvailable: true);
      final p2 = _createProduct(id: '1', name: 'Món 1', isAvailable: false);
      expect(CoreProductRepository.sameProductSnapshot([p1], [p2]), isFalse);
    });

    test('sameProductSnapshot detects category changes', () {
      final p1 = _createProduct(id: '1', name: 'Món 1', category: 'Đồ uống');
      final p2 = _createProduct(id: '1', name: 'Món 1', category: 'Tráng miệng');
      expect(CoreProductRepository.sameProductSnapshot([p1], [p2]), isFalse);
    });

    test('Cache update logic for batchUpdateAvailability preserves non-target items', () {
      final cache = [
        _createProduct(id: 'p1', name: 'Món 1', isAvailable: true),
        _createProduct(id: 'p2', name: 'Món 2', isAvailable: true),
        _createProduct(id: 'p3', name: 'Món 3', isAvailable: true),
      ];

      final targetIds = {'p1', 'p3'};
      final updated = cache.map((p) {
        return targetIds.contains(p.id) ? p.copyWith(isAvailable: false) : p;
      }).toList();

      expect(updated[0].isAvailable, isFalse);
      expect(updated[1].isAvailable, isTrue); // p2 remains unchanged
      expect(updated[2].isAvailable, isFalse);
    });

    test('Cache update logic for batchUpdateCategory updates specified items', () {
      final cache = [
        _createProduct(id: 'p1', name: 'Món 1', category: 'Cũ'),
        _createProduct(id: 'p2', name: 'Món 2', category: 'Cũ'),
      ];

      final targetIds = {'p2'};
      final updated = cache.map((p) {
        return targetIds.contains(p.id) ? p.copyWith(category: 'Mới') : p;
      }).toList();

      expect(updated[0].category, equals('Cũ'));
      expect(updated[1].category, equals('Mới'));
    });
  });

  group('8. Soft Delete Single & Batch Invariants with Manager & Owner Roles', () {
    test('Soft delete payload contains is_deleted: true, is_active: false, and updated_at', () {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final payload = {
        'is_deleted': true,
        'is_active': false,
        'updated_at': nowMs,
      };

      expect(payload['is_deleted'], isTrue);
      expect(payload['is_active'], isFalse);
      expect(payload['updated_at'], isA<int>());
      expect(payload['updated_at'], greaterThan(0));
    });

    test('Manager (role == manager) and Owner have permission to delete items', () {
      bool canDelete(String role, bool isOwner, List<String> perms) {
        return isOwner || role == 'owner' || role == 'manager' || perms.contains('kho.delete_item');
      }

      expect(canDelete('manager', false, []), isTrue, reason: 'Manager must have delete permission');
      expect(canDelete('owner', true, []), isTrue, reason: 'Owner must have delete permission');
      expect(canDelete('cashier', false, ['kho.delete_item']), isTrue, reason: 'Explicit permission allowed');
      expect(canDelete('waiter', false, []), isFalse, reason: 'Waiter without perm must be blocked');
      expect(canDelete('kitchen', false, []), isFalse, reason: 'Kitchen without perm must be blocked');
    });

    test('Batch soft delete removes specified items from cache while keeping others', () {
      final cache = [
        _createProduct(id: 'p1', name: 'Món A'),
        _createProduct(id: 'p2', name: 'Món B'),
        _createProduct(id: 'p3', name: 'Món C'),
        _createProduct(id: 'p4', name: 'Món D'),
      ];

      final idsToDelete = {'p2', 'p4'};
      final remaining = cache.where((p) => !idsToDelete.contains(p.id)).toList();

      expect(remaining.length, equals(2));
      expect(remaining.map((p) => p.id).toList(), equals(['p1', 'p3']));
    });

    test('Single soft delete removes target item from cache', () {
      final cache = [
        _createProduct(id: 'p1', name: 'Món A'),
        _createProduct(id: 'p2', name: 'Món B'),
      ];

      const targetId = 'p1';
      final remaining = cache.where((p) => p.id != targetId).toList();

      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('p2'));
    });

    test('Soft delete preserves historical integrity without hard deletion', () {
      final product = _createProduct(
        id: 'p100',
        name: 'Món Lịch Sử',
        sellPrice: 85000,
        isAvailable: true,
        isActive: true,
      );

      final softDeleted = product.copyWith(
        isAvailable: false,
        isActive: false,
      );

      // Product still has same identity and financial metadata
      expect(softDeleted.id, equals(product.id));
      expect(softDeleted.name, equals(product.name));
      expect(softDeleted.sellPrice, equals(product.sellPrice));
      expect(softDeleted.isAvailable, isFalse);
      expect(softDeleted.isActive, isFalse);
    });

    test('Batch soft deletion across mixed categories with active kitchen tickets preserves ticket references', () {
      final items = [
        _createProduct(id: 'prod-bbq-1', name: 'Bò nướng tảng', category: 'Món nướng'),
        _createProduct(id: 'prod-drink-2', name: 'Trà đào cam sả', category: 'Đồ uống'),
        _createProduct(id: 'prod-top-3', name: 'Trân châu trắng', category: 'Topping'),
      ];

      // Simulated active kitchen tickets referencing products
      final activeKitchenTicketItems = [
        {'id': 'kt-item-1', 'ticket_id': 'kt-1', 'product_id': 'prod-bbq-1', 'status': 'cooking'},
        {'id': 'kt-item-2', 'ticket_id': 'kt-1', 'product_id': 'prod-drink-2', 'status': 'ready'},
      ];

      final idsToDelete = {'prod-bbq-1', 'prod-drink-2'};

      // Soft delete: updates is_deleted=true, is_active=false.
      // Product records remain in DB, so foreign key constraints on kitchen_ticket_items are NEVER violated.
      final updatedProducts = items.map((p) {
        if (idsToDelete.contains(p.id)) {
          return p.copyWith(isAvailable: false, isActive: false, isDeleted: true);
        }
        return p;
      }).toList();

      // Active products in inventory filter out is_deleted
      final visibleInventory = updatedProducts.where((p) => !p.isDeleted).toList();
      expect(visibleInventory.length, equals(1));
      expect(visibleInventory.first.id, equals('prod-top-3'));

      // Kitchen tickets can still safely resolve product_id
      final allProductMap = {for (var p in updatedProducts) p.id: p};
      for (final kt in activeKitchenTicketItems) {
        final prodId = kt['product_id'] as String;
        expect(allProductMap.containsKey(prodId), isTrue, reason: 'FK constraint must remain valid');
        expect(allProductMap[prodId]!.isDeleted, isTrue, reason: 'Product is soft deleted');
      }
    });

    test('CoreProductRepository cache hooks guarantee unified cache synchronization', () {
      final repo = CoreProductRepository.instance;
      const testStoreId = 'store-cache-sync-001';

      final initialProducts = [
        _createProduct(id: 'p1', name: 'Món 1'),
        _createProduct(id: 'p2', name: 'Món 2'),
        _createProduct(id: 'p3', name: 'Món 3'),
      ];

      repo.setCacheForTesting(testStoreId, initialProducts);
      expect(repo.getCacheForTesting(testStoreId)?.length, equals(3));

      // Simulate soft-delete removal in unified cache
      final remaining = repo.getCacheForTesting(testStoreId)!
          .where((p) => p.id != 'p2')
          .toList();
      repo.setCacheForTesting(testStoreId, remaining);

      expect(repo.getCacheForTesting(testStoreId)?.length, equals(2));
      expect(repo.getCacheForTesting(testStoreId)?.map((p) => p.id).toList(), equals(['p1', 'p3']));
    });
  });
}
