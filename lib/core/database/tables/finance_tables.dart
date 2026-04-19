import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE CATEGORIES — Danh mục thu chi
// ─────────────────────────────────────────────────────────────────────────────
class FinanceCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // 'Bán hàng','Nhập hàng','Lương'...
  TextColumn get type => text()(); // 'income' | 'expense'
  TextColumn get icon => text().nullable()();
  TextColumn get color => text().nullable()();
  // 1 = hệ thống tạo (không xóa được)
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE RECORDS — Bản ghi thu chi
// ─────────────────────────────────────────────────────────────────────────────
class FinanceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'income' | 'expense'
  RealColumn get amount => real()();
  TextColumn get categoryId =>
      text().nullable().references(FinanceCategories, #id)();
  TextColumn get description => text().nullable()();
  TextColumn get referenceId => text().nullable()(); // order_id / purchase_id
  TextColumn get eventId => text().nullable()();
  // 1=auto từ POS/Kho, 0=nhập tay
  BoolColumn get isAuto => boolean().withDefault(const Constant(false))();
  IntColumn get recordedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
