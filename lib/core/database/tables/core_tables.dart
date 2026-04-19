import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE CONFIGS — Lego "on/off" switch cho từng module
// ─────────────────────────────────────────────────────────────────────────────
class ModuleConfigs extends Table {
  TextColumn get id => text()(); // 'pos','kho','finance','report','loyalty'
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// CORE PRODUCTS — Sản phẩm/nguyên liệu dùng chung
// ─────────────────────────────────────────────────────────────────────────────
class CoreProducts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get category => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('phần'))();
  // 'finished' = thành phẩm, 'ingredient' = nguyên liệu
  TextColumn get productType =>
      text().withDefault(const Constant('finished'))();
  RealColumn get stockQty => real().withDefault(const Constant(0))();
  RealColumn get minStock => real().withDefault(const Constant(0))();
  RealColumn get sellPrice => real().withDefault(const Constant(0))();
  RealColumn get costPrice => real().withDefault(const Constant(0))();
  TextColumn get imagePath => text().nullable()();
  BoolColumn get isAvailable => boolean().withDefault(const Constant(true))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get version => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// CORE CUSTOMERS — Khách hàng thân thiết
// ─────────────────────────────────────────────────────────────────────────────
class CoreCustomers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  IntColumn get birthday => integer().nullable()();
  RealColumn get loyaltyPts => real().withDefault(const Constant(0))();
  RealColumn get totalSpent => real().withDefault(const Constant(0))();
  IntColumn get visitCount => integer().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().nullable()();
  IntColumn get updatedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// APP SETTINGS — Key-value store cho cài đặt
// ─────────────────────────────────────────────────────────────────────────────
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ─────────────────────────────────────────────────────────────────────────────
// EVENTS LOG — Append-only event journal
// ─────────────────────────────────────────────────────────────────────────────
class EventsLog extends Table {
  TextColumn get id => text()();
  TextColumn get eventType => text()();
  TextColumn get sourceModule => text()();
  TextColumn get payload => text()(); // JSON
  IntColumn get createdAt => integer()();
  TextColumn get idempotencyKey => text().nullable().unique()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING EVENTS — Hàng đợi khi module tắt
// ─────────────────────────────────────────────────────────────────────────────
class PendingEvents extends Table {
  TextColumn get id => text()();
  TextColumn get eventId =>
      text().references(EventsLog, #id, onDelete: KeyAction.cascade)();
  TextColumn get targetModule => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  IntColumn get processedAt => integer().nullable()();
  TextColumn get errorMsg => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
