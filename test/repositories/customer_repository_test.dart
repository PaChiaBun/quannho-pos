// test/repositories/customer_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho CoreCustomerRepository
// Các case: create, getById, update, softDelete, watchAll
// ─────────────────────────────────────────────────────────────────────────────
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/database/app_database.dart';
import 'package:quannho_pos/core/repositories/core_customer_repository.dart';
import '../helpers/test_database.dart';

void main() {
  late CoreCustomerRepository repo;
  late AppDatabase db;

  setUp(() async {
    db   = createTestDatabase();
    repo = CoreCustomerRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── CREATE ──────────────────────────────────────────────────────────────────
  group('create()', () {
    test('tạo khách hàng mới trả về ID', () async {
      final id = await repo.create(
        name:  'Nguyễn Văn A',
        phone: '0901234567',
      );
      expect(id, isNotEmpty);
      expect(id.length, equals(36));
    });

    test('khách hàng mới có loyaltyPts = 0', () async {
      final id       = await repo.create(name: 'Trần Thị B');
      final customer = await repo.getById(id);
      expect(customer!.loyaltyPts, equals(0));
      expect(customer.totalSpent,  equals(0));
    });

    test('customerName được lưu đúng', () async {
      final id       = await repo.create(name: 'Lê Văn C', phone: '0988888888');
      final customer = await repo.getById(id);
      expect(customer!.name,  equals('Lê Văn C'));
      expect(customer.phone, equals('0988888888'));
    });

    test('isDeleted mặc định = false', () async {
      final id       = await repo.create(name: 'Khách D');
      final customer = await repo.getById(id);
      expect(customer!.isDeleted, isFalse);
    });
  });

  // ── GET BY ID ───────────────────────────────────────────────────────────────
  group('getById()', () {
    test('trả về null cho ID không tồn tại', () async {
      final c = await repo.getById('invalid-id-xxx');
      expect(c, isNull);
    });
  });

  // ── UPDATE ──────────────────────────────────────────────────────────────────
  group('update()', () {
    test('cập nhật tên và số điện thoại', () async {
      final id = await repo.create(name: 'Tên cũ', phone: '0900000000');

      await repo.update(id, CoreCustomersCompanion(
        name:  const Value('Tên mới'),
        phone: const Value('0911111111'),
      ));

      final updated = await repo.getById(id);
      expect(updated!.name,  equals('Tên mới'));
      expect(updated.phone, equals('0911111111'));
    });
  });

  // ── SOFT DELETE ──────────────────────────────────────────────────────────────
  group('softDelete()', () {
    test('đặt isDeleted = true', () async {
      final id = await repo.create(name: 'Xóa tôi');
      await repo.softDelete(id);

      final customer = await repo.getById(id);
      expect(customer!.isDeleted, isTrue);
    });

    test('khách bị xóa không xuất hiện trong watchAll', () async {
      final id = await repo.create(name: 'Biến mất');
      await repo.softDelete(id);

      final all = await repo.watchAll().first;
      expect(all.any((c) => c.id == id), isFalse);
    });
  });

  // ── WATCH ALL ──────────────────────────────────────────────────────────────
  group('watchAll()', () {
    test('trả về danh sách chưa bị xóa', () async {
      final id1 = await repo.create(name: 'Khách 1');
      final id2 = await repo.create(name: 'Khách 2');
      final id3 = await repo.create(name: 'Khách 3');
      await repo.softDelete(id3);

      final all  = await repo.watchAll().first;
      final ids  = all.map((c) => c.id).toSet();

      expect(ids.contains(id1), isTrue);
      expect(ids.contains(id2), isTrue);
      expect(ids.contains(id3), isFalse); // đã xóa
    });
  });
}
