import 'package:drift/drift.dart';
import 'core_tables.dart';

// ─────────────────────────────────────────────────────────────────────────────
// POS ORDERS — Đơn hàng
// ─────────────────────────────────────────────────────────────────────────────
class PosOrders extends Table {
  TextColumn get id => text()();
  TextColumn get orderNumber => text().unique()(); // "QN-20260419-001"
  TextColumn get customerId =>
      text().nullable().references(CoreCustomers, #id)();
  TextColumn get customerName => text().nullable()(); // snapshot
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get totalAmount => real()();
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('cash'))(); // cash/transfer/card
  RealColumn get loyaltyPtsEarned =>
      real().withDefault(const Constant(0))();
  RealColumn get loyaltyPtsUsed => real().withDefault(const Constant(0))();
  // completed / cancelled / refunded
  TextColumn get status =>
      text().withDefault(const Constant('completed'))();
  TextColumn get note => text().nullable()();
  BoolColumn get receiptPrinted =>
      boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// POS ORDER ITEMS — Chi tiết món trong đơn
// ─────────────────────────────────────────────────────────────────────────────
class PosOrderItems extends Table {
  TextColumn get id => text()();
  TextColumn get orderId =>
      text().references(PosOrders, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text()();
  TextColumn get productName => text()(); // SNAPSHOT
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()(); // SNAPSHOT giá lúc bán
  RealColumn get costPrice => real()(); // SNAPSHOT giá vốn
  RealColumn get subtotal => real()();

  @override
  Set<Column> get primaryKey => {id};
}
