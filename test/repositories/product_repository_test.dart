// test/repositories/product_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho CoreProductRepository
// ⚠️ TODO: Các test này cần integration test với Supabase
// Các tests dưới đây đã được skip vì repository đã migrate sang Supabase
// và không còn hỗ trợ Drift in-memory DB nữa.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/core_product_repository.dart';

void main() {
  group('CoreProductRepository (Supabase)', () {
    test('SKIP — cần integration test với Supabase thật', () {
      // TODO: Viết integration tests dùng Supabase test environment
      // CoreProductRepository.create() — cần storeId từ Supabase
      // CoreProductRepository.update(id, Map<String, dynamic>)
      // CoreProductRepository.softDelete(id)
      // CoreProductRepository.watchAll() — Supabase stream
      expect(true, isTrue); // placeholder
    }, skip: 'Drift in-memory DB không còn được hỗ trợ sau khi migrate sang Supabase');
  });

  group('ProductModel', () {
    test('fromMap xử lý đúng kiểu dữ liệu', () {
      final map = {
        'id': 'test-id-123',
        'store_id': 'store-abc',
        'name': 'Cà phê đen',
        'sell_price': 25000.0,
        'cost_price': 8000.0,
        'category': 'Đồ uống',
        'unit': 'ly',
        'is_active': true,
        'is_deleted': false,
        'is_available': true,
        'stock_qty': 100.0,
        'image_url': null,
        'sku': 'CF001',
        'description': null,
        'min_stock': 5.0,
        'stock_status': 'ok',
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': null,
      };

      final product = ProductModel.fromMap(map);

      expect(product.id, equals('test-id-123'));
      expect(product.name, equals('Cà phê đen'));
      expect(product.sellPrice, equals(25000.0));
      expect(product.costPrice, equals(8000.0));
      expect(product.isActive, isTrue);
      expect(product.isDeleted, isFalse);
      expect(product.isAvailable, isTrue);
      expect(product.category, equals('Đồ uống'));
    });

    test('fromMap xử lý nullable fields', () {
      final map = {
        'id': 'test-id',
        'store_id': 'store',
        'name': 'Test',
        'sell_price': 10000,
        'cost_price': 5000,
        'category': null,
        'unit': null,
        'is_active': true,
        'is_deleted': false,
        'is_available': true,
        'stock_qty': 0,
        'image_url': null,
        'sku': null,
        'description': null,
        'min_stock': 0,
        'stock_status': 'ok',
        'created_at': null,
        'updated_at': null,
      };

      final product = ProductModel.fromMap(map);
      expect(product.id, equals('test-id'));
      expect(product.imageUrl, isNull);
      expect(product.sku, isNull);
    });
  });
}
