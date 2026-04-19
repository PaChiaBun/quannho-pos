// test/repositories/loyalty_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho LoyaltyRepository
// Các case: earnPoints, redeemPoints, createReward, deleteReward
// ─────────────────────────────────────────────────────────────────────────────
import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quannho_pos/core/database/app_database.dart';
import 'package:quannho_pos/core/event_bus/app_event_bus.dart';
import 'package:quannho_pos/core/event_bus/app_events.dart';
import 'package:quannho_pos/modules/loyalty/repository/loyalty_repository.dart';
import 'package:uuid/uuid.dart';
import '../helpers/test_database.dart';

// ── Mock EventBus (không cần test event bus thật) ───────────────────────────
class MockEventBus extends Mock implements AppEventBus {}
class _FakeAppEvent extends Fake implements AppEvent {}

void main() {
  late AppDatabase db;
  late LoyaltyRepository repo;
  late MockEventBus mockBus;
  late String customerId;

  setUpAll(() {
    registerFallbackValue(_FakeAppEvent());
  });

  setUp(() async {
    db      = createTestDatabase();
    mockBus = MockEventBus();
    repo    = LoyaltyRepository(db, mockBus);

    // Mock emit để tránh side effects
    when(() => mockBus.emit(any(), targetModules: any(named: 'targetModules')))
        .thenAnswer((_) async {});

    // Tạo khách hàng test
    customerId = const Uuid().v4();
    final now  = DateTime.now().millisecondsSinceEpoch;
    await db.into(db.coreCustomers).insert(CoreCustomersCompanion(
      id:         Value(customerId),
      name:       const Value('Khách Test'),
      loyaltyPts: const Value(0),
      totalSpent: const Value(0),
      isDeleted:  const Value(false),
      createdAt:  Value(now),
      updatedAt:  Value(now),
    ));
  });

  tearDown(() async {
    await db.close();
  });

  // ── EARN POINTS ─────────────────────────────────────────────────────────────
  group('earnPoints()', () {
    test('cộng điểm cho khách hàng', () async {
      await repo.earnPoints(
        customerId: customerId,
        pts:        50,
        orderId:    'order-001',
      );

      final customer = await (db.select(db.coreCustomers)
            ..where((c) => c.id.equals(customerId)))
          .getSingleOrNull();
      expect(customer!.loyaltyPts, equals(50));
    });

    test('cộng điểm nhiều lần — tích lũy đúng', () async {
      await repo.earnPoints(customerId: customerId, pts: 30, orderId: 'o1');
      await repo.earnPoints(customerId: customerId, pts: 20, orderId: 'o2');
      await repo.earnPoints(customerId: customerId, pts: 50, orderId: 'o3');

      final customer = await (db.select(db.coreCustomers)
            ..where((c) => c.id.equals(customerId)))
          .getSingleOrNull();
      expect(customer!.loyaltyPts, equals(100));
    });

    test('pts <= 0 — không ghi gì cả', () async {
      await repo.earnPoints(customerId: customerId, pts: 0, orderId: 'o-zero');

      final txs = await db.select(db.loyaltyTransactions).get();
      expect(txs.where((t) => t.customerId == customerId), isEmpty);
    });

    test('ghi lịch sử giao dịch sau earn', () async {
      await repo.earnPoints(
        customerId: customerId, pts: 25, orderId: 'order-hist');

      final txs = await (db.select(db.loyaltyTransactions)
            ..where((t) => t.customerId.equals(customerId)))
          .get();
      expect(txs.length, equals(1));
      expect(txs.first.ptsEarned, equals(25));
      expect(txs.first.orderId, equals('order-hist'));
    });

    test('emit PointsEarnedEvent sau khi cộng điểm', () async {
      await repo.earnPoints(customerId: customerId, pts: 10, orderId: 'o');
      verify(() => mockBus.emit(any(), targetModules: any(named: 'targetModules')))
          .called(1);
    });
  });

  // ── REDEEM POINTS ────────────────────────────────────────────────────────────
  group('redeemPoints()', () {
    setUp(() async {
      // Cộng sẵn 100 điểm để test redeem
      await repo.earnPoints(customerId: customerId, pts: 100, orderId: 'setup');
    });

    test('trừ điểm thành công khi đủ số dư', () async {
      await repo.redeemPoints(customerId: customerId, pts: 30);

      final customer = await (db.select(db.coreCustomers)
            ..where((c) => c.id.equals(customerId)))
          .getSingleOrNull();
      expect(customer!.loyaltyPts, equals(70)); // 100 - 30
    });

    test('throw exception khi không đủ điểm', () async {
      expect(
        () => repo.redeemPoints(customerId: customerId, pts: 200),
        throwsException,
      );
    });

    test('throw exception khi số dư = 0', () async {
      await repo.redeemPoints(customerId: customerId, pts: 100); // dùng hết

      expect(
        () => repo.redeemPoints(customerId: customerId, pts: 1),
        throwsException,
      );
    });

    test('ghi lịch sử ptsUsed chính xác', () async {
      await repo.redeemPoints(
        customerId: customerId, pts: 40, note: 'Đổi quà');

      final txs = await (db.select(db.loyaltyTransactions)
            ..where((t) =>
                t.customerId.equals(customerId) &
                t.ptsUsed.isBiggerThanValue(0)))
          .get();
      expect(txs.first.ptsUsed, equals(40));
      expect(txs.first.note, equals('Đổi quà'));
    });
  });

  // ── CREATE REWARD ────────────────────────────────────────────────────────────
  group('createReward()', () {
    test('tạo phần thưởng mới', () async {
      await repo.createReward(name: 'Cà phê miễn phí', ptsRequired: 50);

      final rewards = await repo.watchRewards().first;
      expect(rewards.length, equals(1));
      expect(rewards.first.name, equals('Cà phê miễn phí'));
      expect(rewards.first.ptsRequired, equals(50));
      expect(rewards.first.isActive, isTrue);
    });

    test('tạo nhiều phần thưởng — sắp xếp theo ptsRequired tăng dần', () async {
      await repo.createReward(name: 'Quà lớn',   ptsRequired: 200);
      await repo.createReward(name: 'Quà nhỏ',   ptsRequired: 30);
      await repo.createReward(name: 'Quà trung',  ptsRequired: 100);

      final rewards = await repo.watchRewards().first;
      expect(rewards[0].ptsRequired, equals(30));
      expect(rewards[1].ptsRequired, equals(100));
      expect(rewards[2].ptsRequired, equals(200));
    });
  });

  // ── DELETE REWARD ────────────────────────────────────────────────────────────
  group('deleteReward()', () {
    test('xóa (deactivate) phần thưởng — không còn xuất hiện', () async {
      await repo.createReward(name: 'Xóa tôi', ptsRequired: 50);
      final rewards = await repo.watchRewards().first;
      final id = rewards.first.id;

      await repo.deleteReward(id);

      final after = await repo.watchRewards().first;
      expect(after.where((r) => r.id == id), isEmpty);
    });
  });

  // ── GET STATS ────────────────────────────────────────────────────────────────
  group('getStats()', () {
    test('stats rỗng khi chưa có giao dịch', () async {
      final stats = await repo.getStats();
      expect(stats.totalCustomers, greaterThanOrEqualTo(1)); // có khách test
      expect(stats.totalPtsEarned, equals(0));
      expect(stats.totalPtsRedeemed, equals(0));
    });

    test('stats tính đúng sau earn và redeem', () async {
      await repo.earnPoints(customerId: customerId, pts: 80, orderId: 'o1');
      await repo.redeemPoints(customerId: customerId, pts: 20);

      final stats = await repo.getStats();
      expect(stats.totalPtsEarned,    equals(80));
      expect(stats.totalPtsRedeemed,  equals(20));
      expect(stats.totalActivePts,    equals(60)); // 80 - 20
    });
  });
}
