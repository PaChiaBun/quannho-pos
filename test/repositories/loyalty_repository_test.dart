// test/repositories/loyalty_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho LoyaltyRepository
// ⚠️ TODO: Migrate sang integration tests với Supabase
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/loyalty/repository/loyalty_repository.dart';

void main() {
  group('LoyaltyRepository (Supabase)', () {
    test('SKIP — cần integration test với Supabase thật', () {
      expect(true, isTrue); // placeholder
    }, skip: 'Drift in-memory DB không còn được hỗ trợ sau khi migrate sang Supabase');
  });

  group('LoyaltyRewardModel', () {
    test('fromMap xử lý đúng kiểu dữ liệu', () {
      final map = {
        'id': 'reward-123',
        'store_id': 'store-abc',
        'name': 'Cà phê miễn phí',
        'description': 'Đổi 1 ly cà phê',
        'pts_required': 50,
        'discount_amount': null,
        'is_active': true,
      };

      final reward = LoyaltyRewardModel.fromMap(map);
      expect(reward.id, equals('reward-123'));
      expect(reward.name, equals('Cà phê miễn phí'));
      expect(reward.ptsRequired, equals(50.0));
      expect(reward.discountAmount, isNull);
    });

    test('fromMap với discount_amount', () {
      final map = {
        'id': 'reward-456',
        'store_id': 'store',
        'name': 'Giảm giá',
        'description': null,
        'pts_required': 100,
        'discount_amount': 20000,
        'is_active': true,
      };

      final reward = LoyaltyRewardModel.fromMap(map);
      expect(reward.discountAmount, equals(20000.0));
    });
  });

  group('LoyaltyStats', () {
    test('empty trả về 0 cho tất cả field', () {
      const stats = LoyaltyStats.empty;
      expect(stats.totalCustomers, equals(0));
      expect(stats.totalPtsEarned, equals(0));
      expect(stats.totalPtsRedeemed, equals(0));
      expect(stats.totalActivePts, equals(0));
      expect(stats.customersWithPts, equals(0));
    });

    test('constructor lưu đúng giá trị', () {
      const stats = LoyaltyStats(
        totalCustomers: 10,
        customersWithPts: 5,
        totalActivePts: 500,
        totalPtsEarned: 1000,
        totalPtsRedeemed: 500,
      );
      expect(stats.totalCustomers, equals(10));
      expect(stats.customersWithPts, equals(5));
      expect(stats.totalActivePts, equals(500));
    });
  });

  group('LoyaltyCustomerModel', () {
    test('fromMap xử lý đúng', () {
      final map = {
        'id': 'cust-1',
        'name': 'Nguyễn A',
        'phone': '0900000000',
        'loyalty_pts': 150.0,
        'total_spent': 750000.0,
        'visit_count': 3,
      };
      final c = LoyaltyCustomerModel.fromMap(map);
      expect(c.loyaltyPts, equals(150.0));
      expect(c.visitCount, equals(3));
    });
  });
}
