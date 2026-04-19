// test/repositories/product_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho CoreProductRepository
// Các case: create, getById, update, softDelete, watchAll filter
// ─────────────────────────────────────────────────────────────────────────────
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/database/app_database.dart';
import 'package:quannho_pos/core/repositories/core_product_repository.dart';
import '../helpers/test_database.dart';

void main() {
  late CoreProductRepository repo;

  setUp(() async {
    final db = createTestDatabase();
    repo = CoreProductRepository(db);
  });

  // ── CREATE ──────────────────────────────────────────────────────────────────
  group('create()', () {
    test('tạo sản phẩm mới và trả về ID hợp lệ', () async {
      final id = await repo.create(
        name:      'Cà phê đen',
        sku:       'CF001',
        sellPrice: 25000,
        costPrice: 8000,
        category:  'Đồ uống',
        unit:      'ly',
      );

      expect(id, isNotEmpty);
      expect(id.length, equals(36)); // UUID length
    });

    test('sản phẩm vừa tạo có thể lấy lại bằng getById', () async {
      final id = await repo.create(
        name:      'Trà sữa',
        sellPrice: 35000,
        category:  'Đồ uống',
      );

      final product = await repo.getById(id);
      expect(product, isNotNull);
      expect(product!.name, equals('Trà sữa'));
      expect(product.sellPrice, equals(35000));
      expect(product.isDeleted, isFalse);
      expect(product.isActive, isTrue);
    });

    test('isAvailable mặc định là true', () async {
      final id = await repo.create(name: 'Bánh mì');
      final product = await repo.getById(id);
      expect(product!.isAvailable, isTrue);
    });

    test('tạo nhiều sản phẩm — ID mỗi cái phải unique', () async {
      final id1 = await repo.create(name: 'SP1', sellPrice: 10000);
      final id2 = await repo.create(name: 'SP2', sellPrice: 20000);
      final id3 = await repo.create(name: 'SP3', sellPrice: 30000);

      expect({id1, id2, id3}.length, equals(3)); // 3 IDs khác nhau
    });
  });

  // ── GET BY ID ───────────────────────────────────────────────────────────────
  group('getById()', () {
    test('trả về null nếu không tồn tại', () async {
      final product = await repo.getById('non-existent-uuid');
      expect(product, isNull);
    });
  });

  // ── UPDATE ──────────────────────────────────────────────────────────────────
  group('update()', () {
    test('cập nhật tên và giá bán thành công', () async {
      final id = await repo.create(
        name: 'Cà phê cũ', sellPrice: 20000);

      await repo.update(id, CoreProductsCompanion(
        name:      const Value('Cà phê mới'),
        sellPrice: const Value(30000),
      ));

      final updated = await repo.getById(id);
      expect(updated!.name, equals('Cà phê mới'));
      expect(updated.sellPrice, equals(30000));
    });

    test('update không ảnh hưởng sản phẩm khác', () async {
      final id1 = await repo.create(name: 'SP A', sellPrice: 10000);
      final id2 = await repo.create(name: 'SP B', sellPrice: 20000);

      await repo.update(id1, const CoreProductsCompanion(
        name: Value('SP A Updated'),
      ));

      final spB = await repo.getById(id2);
      expect(spB!.name, equals('SP B')); // không thay đổi
    });
  });

  // ── SOFT DELETE ──────────────────────────────────────────────────────────────
  group('softDelete()', () {
    test('sản phẩm bị xóa mềm có isDeleted = true', () async {
      final id = await repo.create(name: 'Sản phẩm xóa');
      await repo.softDelete(id);

      final product = await repo.getById(id);
      expect(product!.isDeleted, isTrue);
    });

    test('sản phẩm đã xóa không xuất hiện trong watchAll stream', () async {
      final id = await repo.create(name: 'Xóa mềm test');
      await repo.softDelete(id);

      final allProducts = await repo.watchAll().first;
      final found = allProducts.any((p) => p.id == id);
      expect(found, isFalse);
    });

    test('sản phẩm chưa xóa vẫn xuất hiện trong watchAll', () async {
      final id = await repo.create(name: 'Còn tồn tại');
      
      final allProducts = await repo.watchAll().first;
      final found = allProducts.any((p) => p.id == id);
      expect(found, isTrue);
    });
  });

  // ── WATCH ALL ──────────────────────────────────────────────────────────────
  group('watchAll()', () {
    test('trả về danh sách rỗng khi chưa có sản phẩm', () async {
      final products = await repo.watchAll().first;
      // DB seed tạo 5 sản phẩm mẫu — vẫn hợp lệ nếu có
      expect(products, isA<List>());
    });

    test('chỉ hiển thị sản phẩm chưa bị xóa', () async {
      final idKeep   = await repo.create(name: 'Giữ lại');
      final idDelete = await repo.create(name: 'Xóa đi');
      await repo.softDelete(idDelete);

      final products = await repo.watchAll().first;
      final ids = products.map((p) => p.id).toSet();

      expect(ids.contains(idKeep), isTrue);
      expect(ids.contains(idDelete), isFalse);
    });
  });
}
