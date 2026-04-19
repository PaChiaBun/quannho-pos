import 'package:drift/drift.dart';
import 'core_tables.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KHO STOCK MOVEMENTS — Lịch sử xuất/nhập — APPEND ONLY, nguồn sự thật
// ─────────────────────────────────────────────────────────────────────────────
class KhoStockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(CoreProducts, #id)();
  RealColumn get delta => real()(); // + nhập, - xuất
  // 'sale','purchase','return','adjust','damage','recipe'
  TextColumn get reason => text()();
  TextColumn get referenceId => text().nullable()(); // order_id / purchase_id
  TextColumn get eventId => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer()(); // KHÔNG UPDATE, KHÔNG DELETE

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// KHO RECIPES — Công thức món ăn
// ─────────────────────────────────────────────────────────────────────────────
class KhoRecipes extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(CoreProducts, #id)(); // món thành phẩm
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get note => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// KHO RECIPE ITEMS — Nguyên liệu trong công thức
// ─────────────────────────────────────────────────────────────────────────────
class KhoRecipeItems extends Table {
  TextColumn get id => text()();
  TextColumn get recipeId =>
      text().references(KhoRecipes, #id, onDelete: KeyAction.cascade)();
  TextColumn get ingredientId =>
      text().references(CoreProducts, #id)(); // nguyên liệu
  RealColumn get quantity => real()(); // số lượng dùng cho 1 phần
  TextColumn get unit => text()(); // 'gram','ml','cái'

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// KHO SUPPLIERS — Nhà cung cấp
// ─────────────────────────────────────────────────────────────────────────────
class KhoSuppliers extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get note => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// KHO PURCHASE ORDERS — Đơn nhập hàng
// ─────────────────────────────────────────────────────────────────────────────
class KhoPurchaseOrders extends Table {
  TextColumn get id => text()();
  TextColumn get supplierId =>
      text().nullable().references(KhoSuppliers, #id)();
  RealColumn get totalCost => real()();
  TextColumn get status =>
      text().withDefault(const Constant('received'))();
  TextColumn get note => text().nullable()();
  IntColumn get createdAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// KHO PURCHASE ITEMS — Chi tiết đơn nhập
// ─────────────────────────────────────────────────────────────────────────────
class KhoPurchaseItems extends Table {
  TextColumn get id => text()();
  TextColumn get purchaseId =>
      text().references(KhoPurchaseOrders, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text().nullable()();
  TextColumn get productName => text().nullable()(); // SNAPSHOT
  RealColumn get quantity => real()();
  RealColumn get unitCost => real()();

  @override
  Set<Column> get primaryKey => {id};
}
