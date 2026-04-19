import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/event_bus/app_event_bus.dart';
import '../../../core/event_bus/app_events.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY REPOSITORY
// LoyaltyTransactions: id, customerId, orderId, ptsEarned, ptsUsed,
//                       note, createdAt
// CoreCustomers: loyaltyPts (cache)
// ─────────────────────────────────────────────────────────────────────────────
class LoyaltyRepository {
  final AppDatabase _db;
  final AppEventBus _bus;
  final _uuid = const Uuid();

  LoyaltyRepository(this._db, this._bus);

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Lịch sử điểm của 1 khách hàng
  Stream<List<LoyaltyTransaction>> watchTransactions(String customerId) {
    return (_db.select(_db.loyaltyTransactions)
          ..where((t) => t.customerId.equals(customerId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  /// Khách hàng có điểm thưởng cao nhất
  Stream<List<CoreCustomer>> watchTopCustomers({int limit = 20}) {
    return (_db.select(_db.coreCustomers)
          ..where((c) => c.isDeleted.equals(false) & c.loyaltyPts.isBiggerThanValue(0))
          ..orderBy([(c) => OrderingTerm.desc(c.loyaltyPts)])
          ..limit(limit))
        .watch();
  }

  /// Tất cả khách hàng (có thể lọc theo điểm)
  Stream<List<CoreCustomer>> watchCustomers({bool withPoints = false}) {
    return (_db.select(_db.coreCustomers)
          ..where((c) => c.isDeleted.equals(false) &
              (withPoints ? c.loyaltyPts.isBiggerThanValue(0) : const Constant(true)))
          ..orderBy([(c) => OrderingTerm.desc(c.totalSpent)]))
        .watch();
  }

  // ── Rewards ───────────────────────────────────────────────────────────────

  Stream<List<LoyaltyReward>> watchRewards() {
    return (_db.select(_db.loyaltyRewards)
          ..where((r) => r.isActive.equals(true))
          ..orderBy([(r) => OrderingTerm.asc(r.ptsRequired)]))
        .watch();
  }

  Future<void> createReward({
    required String name,
    required double ptsRequired,
    double? discountAmount,
  }) async {
    await _db.into(_db.loyaltyRewards).insert(
      LoyaltyRewardsCompanion(
        id:             Value(_uuid.v4()),
        name:           Value(name),
        ptsRequired:    Value(ptsRequired),
        discountAmount: Value(discountAmount),
        isActive:       const Value(true),
      ),
    );
  }

  Future<void> deleteReward(String id) async {
    await (_db.update(_db.loyaltyRewards)
          ..where((r) => r.id.equals(id)))
        .write(const LoyaltyRewardsCompanion(isActive: Value(false)));
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  /// Cộng điểm sau khi bán (gọi từ SaleCompletedEvent)
  Future<void> earnPoints({
    required String customerId,
    required double pts,
    required String orderId,
    String? note,
  }) async {
    if (pts <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // 1. Ghi lịch sử
      await _db.into(_db.loyaltyTransactions).insert(
        LoyaltyTransactionsCompanion(
          id:         Value(_uuid.v4()),
          customerId: Value(customerId),
          orderId:    Value(orderId),
          ptsEarned:  Value(pts),
          ptsUsed:    Value(0),
          note:       Value(note ?? 'Mua hàng'),
          createdAt:  Value(now),
        ),
      );

      // 2. Cập nhật cache loyalty_pts
      await _db.customUpdate(
        'UPDATE core_customers SET loyalty_pts = loyalty_pts + ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withReal(pts),
          Variable.withInt(now),
          Variable.withString(customerId),
        ],
        updates: {_db.coreCustomers},
      );
    });

    // Emit event
    await _bus.emit(
      PointsEarnedEvent(
        id:         _uuid.v4(),
        createdAt:  DateTime.fromMillisecondsSinceEpoch(now),
        customerId: customerId,
        pts:        pts,
        orderId:    orderId,
      ),
      targetModules: const [],
    );
  }

  /// Trừ điểm khi đổi quà / dùng điểm
  Future<void> redeemPoints({
    required String customerId,
    required double pts,
    String? orderId,
    String? note,
  }) async {
    if (pts <= 0) return;
    final now = DateTime.now().millisecondsSinceEpoch;

    // Kiểm tra số dư đủ không
    final customer = await (_db.select(_db.coreCustomers)
          ..where((c) => c.id.equals(customerId)))
        .getSingleOrNull();
    if (customer == null || customer.loyaltyPts < pts) {
      throw Exception('Không đủ điểm thưởng');
    }

    await _db.transaction(() async {
      await _db.into(_db.loyaltyTransactions).insert(
        LoyaltyTransactionsCompanion(
          id:         Value(_uuid.v4()),
          customerId: Value(customerId),
          orderId:    Value(orderId),
          ptsEarned:  Value(0),
          ptsUsed:    Value(pts),
          note:       Value(note ?? 'Đổi điểm'),
          createdAt:  Value(now),
        ),
      );

      await _db.customUpdate(
        'UPDATE core_customers SET loyalty_pts = loyalty_pts - ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withReal(pts),
          Variable.withInt(now),
          Variable.withString(customerId),
        ],
        updates: {_db.coreCustomers},
      );
    });

    await _bus.emit(
      PointsRedeemedEvent(
        id:         _uuid.v4(),
        createdAt:  DateTime.fromMillisecondsSinceEpoch(now),
        customerId: customerId,
        pts:        pts,
        orderId:    orderId ?? '',
      ),
      targetModules: const [],
    );
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<LoyaltyStats> getStats() async {
    final customers = await (_db.select(_db.coreCustomers)
          ..where((c) => c.isDeleted.equals(false)))
        .get();

    final totalPts = customers.fold<double>(
        0, (s, c) => s + c.loyaltyPts);
    final withPts  = customers.where((c) => c.loyaltyPts > 0).length;

    final txs = await _db.select(_db.loyaltyTransactions).get();
    final totalEarned  = txs.fold<double>(0, (s, t) => s + t.ptsEarned);
    final totalRedeemed = txs.fold<double>(0, (s, t) => s + t.ptsUsed);

    return LoyaltyStats(
      totalCustomers:    customers.length,
      customersWithPts:  withPts,
      totalActivePts:    totalPts,
      totalPtsEarned:    totalEarned,
      totalPtsRedeemed:  totalRedeemed,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────
class LoyaltyStats {
  final int totalCustomers;
  final int customersWithPts;
  final double totalActivePts;
  final double totalPtsEarned;
  final double totalPtsRedeemed;

  const LoyaltyStats({
    required this.totalCustomers,
    required this.customersWithPts,
    required this.totalActivePts,
    required this.totalPtsEarned,
    required this.totalPtsRedeemed,
  });

  static const empty = LoyaltyStats(
    totalCustomers: 0, customersWithPts: 0,
    totalActivePts: 0, totalPtsEarned: 0, totalPtsRedeemed: 0,
  );
}
