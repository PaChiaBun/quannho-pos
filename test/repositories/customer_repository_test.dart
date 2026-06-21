// test/repositories/customer_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho CoreCustomerRepository
// ⚠️ TODO: Migrate sang integration tests với Supabase
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/core_customer_repository.dart';

void main() {
  group('CoreCustomerRepository (Supabase)', () {
    test('SKIP — cần integration test với Supabase thật', () {
      // TODO: Viết integration tests dùng Supabase test environment
      // repo.create(name, phone) — Supabase insert
      // repo.getById(id) — Supabase select
      // repo.update(id, Map<String, dynamic>) — Supabase update
      // repo.softDelete(id) — Supabase update is_deleted = true
      // repo.watchAll() — Supabase stream
      expect(true, isTrue); // placeholder
    }, skip: 'Drift in-memory DB không còn được hỗ trợ sau khi migrate sang Supabase');
  });

  group('CustomerModel', () {
    test('fromMap xử lý đúng kiểu dữ liệu', () {
      final map = {
        'id': 'cust-123',
        'store_id': 'store-abc',
        'name': 'Nguyễn Văn A',
        'phone': '0901234567',
        'email': null,
        'address': null,
        'loyalty_pts': 100.0,
        'total_spent': 500000.0,
        'visit_count': 5,
        'birthday': null,
        'notes': null,
        'is_deleted': false,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': null,
      };

      final customer = CustomerModel.fromMap(map);
      expect(customer.id, equals('cust-123'));
      expect(customer.name, equals('Nguyễn Văn A'));
      expect(customer.phone, equals('0901234567'));
      expect(customer.loyaltyPts, equals(100.0));
      expect(customer.totalSpent, equals(500000.0));
      expect(customer.isDeleted, isFalse);
    });

    test('fromMap xử lý nullable phone và email', () {
      final map = {
        'id': 'cust-456',
        'store_id': 'store-abc',
        'name': 'Trần Thị B',
        'phone': null,
        'email': null,
        'address': null,
        'loyalty_pts': 0,
        'total_spent': 0,
        'visit_count': 0,
        'birthday': null,
        'notes': null,
        'is_deleted': false,
        'created_at': null,
        'updated_at': null,
      };

      final customer = CustomerModel.fromMap(map);
      expect(customer.phone, isNull);
      expect(customer.email, isNull);
    });
  });
}
