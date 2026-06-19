import 'package:drift/drift.dart';
import 'core_tables.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY TRANSACTIONS — Lịch sử điểm thưởng
// ─────────────────────────────────────────────────────────────────────────────
class LoyaltyTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get customerId =>
      text().references(CoreCustomers, #id)();
  TextColumn get orderId => text().nullable()();
  RealColumn get ptsEarned => real().withDefault(const Constant(0))();
  RealColumn get ptsUsed => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY REWARDS — Phần thưởng đổi điểm
// ─────────────────────────────────────────────────────────────────────────────
class LoyaltyRewards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // "Giảm 10k khi đủ 100 điểm"
  RealColumn get ptsRequired => real()();
  RealColumn get discountAmount => real().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
