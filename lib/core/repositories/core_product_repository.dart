import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CORE PRODUCT REPOSITORY
// Chỉ module core được đọc/ghi bảng core_products
// ─────────────────────────────────────────────────────────────────────────────
class CoreProductRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CoreProductRepository(this._db);

  // ── Reactive streams ──────────────────────────────────────────────────────

  /// Tất cả sản phẩm chưa xóa, sorted by name
  Stream<List<CoreProduct>> watchAll() {
    return (_db.select(_db.coreProducts)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  /// Chỉ sản phẩm đang active và available (dùng cho POS)
  Stream<List<CoreProduct>> watchAvailableForPos() {
    return (_db.select(_db.coreProducts)
          ..where((p) =>
              p.isDeleted.equals(false) &
              p.isActive.equals(true) &
              p.isAvailable.equals(true))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch();
  }

  /// Sản phẩm có tồn kho thấp hơn min_stock
  Stream<List<CoreProduct>> watchLowStock() {
    return (_db.select(_db.coreProducts)
          ..where((p) =>
              p.isDeleted.equals(false) &
              p.minStock.isBiggerThanValue(0) &
              CustomExpression<bool>(
                  'stock_qty <= min_stock')))
        .watch();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<CoreProduct?> getById(String id) {
    return (_db.select(_db.coreProducts)
          ..where((p) => p.id.equals(id)))
        .getSingleOrNull();
  }

  Future<String> create({
    required String name,
    String? sku,
    String? category,
    String unit = 'phần',
    String productType = 'finished',
    double stockQty = 0,
    double minStock = 0,
    double sellPrice = 0,
    double costPrice = 0,
    String? imagePath,
    bool isAvailable = true,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.coreProducts).insert(CoreProductsCompanion(
          id: Value(id),
          name: Value(name),
          sku: Value(sku),
          category: Value(category),
          unit: Value(unit),
          productType: Value(productType),
          stockQty: Value(stockQty),
          minStock: Value(minStock),
          sellPrice: Value(sellPrice),
          costPrice: Value(costPrice),
          imagePath: Value(imagePath),
          isAvailable: Value(isAvailable),
          isActive: const Value(true),
          isDeleted: const Value(false),
          version: const Value(0),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
    return id;
  }

  Future<void> update(String id, CoreProductsCompanion companion) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.coreProducts)..where((p) => p.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(now)));
  }

  /// Cập nhật tồn kho cached (sau khi kho_stock_movements ghi xong)
  Future<void> updateStockQty(String id, double delta) async {
    final product = await getById(id);
    if (product == null) return;
    final newQty = product.stockQty + delta;
    await update(
        id,
        CoreProductsCompanion(
          stockQty: Value(newQty),
          version: Value(product.version + 1),
        ));
  }

  /// Soft delete — KHÔNG bao giờ DELETE thật
  Future<void> softDelete(String id) async {
    await update(
        id,
        const CoreProductsCompanion(
          isDeleted: Value(true),
          isActive: Value(false),
        ));
  }

  Future<List<CoreProduct>> searchByName(String query) {
    return (_db.select(_db.coreProducts)
          ..where((p) =>
              p.isDeleted.equals(false) &
              p.name.like('%$query%'))
          ..limit(20))
        .get();
  }
}
