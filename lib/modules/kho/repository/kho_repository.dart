import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/event_bus/app_event_bus.dart';
import '../../../core/event_bus/app_events.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KHO REPOSITORY — Tuân thủ schema thực tế
// KhoStockMovements: id, productId, delta (+nhập/-xuất), reason, referenceId,
//                    eventId, note, createdAt
// CoreProducts: isDeleted (không có trackStock/deletedAt)
// ─────────────────────────────────────────────────────────────────────────────
class KhoRepository {
  final AppDatabase _db;
  final AppEventBus _bus;
  final _uuid = const Uuid();

  KhoRepository(this._db, this._bus);

  // ── Stock movements ───────────────────────────────────────────────────────

  /// Lịch sử biến động của 1 sản phẩm (delta = +nhập / -xuất)
  Stream<List<KhoStockMovement>> watchMovements(String productId) {
    return (_db.select(_db.khoStockMovements)
          ..where((m) => m.productId.equals(productId))
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)]))
        .watch();
  }

  /// Tất cả biến động gần đây
  Stream<List<KhoStockMovement>> watchRecentMovements({int limit = 50}) {
    return (_db.select(_db.khoStockMovements)
          ..orderBy([(m) => OrderingTerm.desc(m.createdAt)])
          ..limit(limit))
        .watch();
  }

  // ── Nhập hàng ─────────────────────────────────────────────────────────────

  /// Nhập kho — delta dương (append-only)
  Future<void> receiveStock({
    required String productId,
    required String productName,
    required double quantity,
    required double unitCost,
    String? supplierId,
    String? supplierName,
    String? reference,   // số phiếu
    String? note,
  }) async {
    assert(quantity > 0);
    final eventId = _uuid.v4();
    final now     = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // 1. Ghi movement (append-only, delta dương = nhập)
      await _db.into(_db.khoStockMovements).insert(
        KhoStockMovementsCompanion(
          id:          Value(_uuid.v4()),
          productId:   Value(productId),
          delta:       Value(quantity),       // + nhập
          reason:      const Value('purchase'),
          referenceId: Value(reference),
          note:        Value(supplierName != null
              ? '${supplierName}${note != null ? ' — $note' : ''}'
              : note),
          createdAt:   Value(now),
        ),
      );

      // 2. Cập nhật stockQty
      await _db.customUpdate(
        'UPDATE core_products SET stock_qty = stock_qty + ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withReal(quantity),
          Variable.withInt(now),
          Variable.withString(productId),
        ],
        updates: {_db.coreProducts},
      );

      // 3. Emit event
      final newLevel = await _getCurrentStock(productId);
      await _bus.emit(
        StockAdjustedEvent(
          id:        eventId,
          createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          productId: productId,
          delta:     quantity,
          reason:    'purchase',
        ),
        targetModules: const ['pos', 'finance'],
      );
    });
  }

  /// Điều chỉnh kho thủ công (delta âm = xuất)
  Future<void> adjustStock({
    required String productId,
    required String productName,
    required double quantity,   // âm = xuất, dương = thêm
    required String reason,     // 'adjust','waste','damage','transfer'
    String? note,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      await _db.into(_db.khoStockMovements).insert(
        KhoStockMovementsCompanion(
          id:        Value(_uuid.v4()),
          productId: Value(productId),
          delta:     Value(quantity),   // có thể âm
          reason:    Value(reason),
          note:      Value(note),
          createdAt: Value(now),
        ),
      );

      await _db.customUpdate(
        'UPDATE core_products SET stock_qty = stock_qty + ?, updated_at = ? WHERE id = ?',
        variables: [
          Variable.withReal(quantity),
          Variable.withInt(now),
          Variable.withString(productId),
        ],
        updates: {_db.coreProducts},
      );
    });
  }

  Future<double> _getCurrentStock(String productId) async {
    final r = await (_db.select(_db.coreProducts)
          ..where((p) => p.id.equals(productId)))
        .getSingleOrNull();
    return r?.stockQty ?? 0;
  }

  // ── Products (Kho view) ───────────────────────────────────────────────────

  Stream<List<StockItem>> watchAllStock() {
    return (_db.select(_db.coreProducts)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch()
        .map((rows) => rows.map(StockItem.fromProduct).toList());
  }

  Stream<List<StockItem>> watchLowStock() {
    return (_db.select(_db.coreProducts)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.stockQty)]))
        .watch()
        .map((rows) => rows
            .where((p) => p.minStock > 0 && p.stockQty <= p.minStock)
            .map(StockItem.fromProduct)
            .toList());
  }

  Stream<List<StockItem>> watchOutOfStock() {
    return (_db.select(_db.coreProducts)
          ..where((p) => p.isDeleted.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.name)]))
        .watch()
        .map((rows) => rows
            .where((p) => p.stockQty <= 0)
            .map(StockItem.fromProduct)
            .toList());
  }

  // ── Suppliers ─────────────────────────────────────────────────────────────

  Stream<List<KhoSupplier>> watchSuppliers() {
    return (_db.select(_db.khoSuppliers)
          ..where((s) => s.isDeleted.equals(false))
          ..orderBy([(s) => OrderingTerm.asc(s.name)]))
        .watch();
  }

  Future<String> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? note,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.khoSuppliers).insert(KhoSuppliersCompanion(
          id:      Value(id),
          name:    Value(name),
          phone:   Value(phone),
          address: Value(address),
          note:    Value(note),
        ));
    return id;
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<KhoStats> getStats() async {
    final products = await (_db.select(_db.coreProducts)
          ..where((p) => p.isDeleted.equals(false)))
        .get();

    final lowStockItems =
        products.where((p) => p.minStock > 0 && p.stockQty <= p.minStock).length;
    final outOfStock = products.where((p) => p.stockQty <= 0).length;
    final totalValue = products.fold<double>(
      0, (s, p) => s + (p.stockQty * p.costPrice));

    // Nhập kho trong ngày (delta dương)
    final todayStart = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;

    final todayIn = await (_db.select(_db.khoStockMovements)
          ..where((m) =>
              m.createdAt.isBiggerOrEqualValue(todayStart) &
              m.reason.equals('purchase')))
        .get();

    final todayInQty = todayIn.fold<double>(0, (s, m) => s + m.delta);

    return KhoStats(
      totalItems:      products.length,
      lowStockItems:   lowStockItems,
      outOfStockItems: outOfStock,
      totalValue:      totalValue,
      todayInQty:      todayInQty,
      todayInCost:     0, // cần purchase_orders để tính chính xác
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class StockItem {
  final String id;
  final String name;
  final String unit;
  final String? sku;
  final String? category;
  final double stockQty;
  final double minStock;
  final double costPrice;
  final double sellPrice;

  const StockItem({
    required this.id,
    required this.name,
    required this.unit,
    this.sku,
    this.category,
    required this.stockQty,
    required this.minStock,
    required this.costPrice,
    required this.sellPrice,
  });

  factory StockItem.fromProduct(CoreProduct p) => StockItem(
        id:        p.id,
        name:      p.name,
        unit:      p.unit,
        sku:       p.sku,
        category:  p.category,
        stockQty:  p.stockQty,
        minStock:  p.minStock,
        costPrice: p.costPrice,
        sellPrice: p.sellPrice,
      );

  StockStatus get status {
    if (stockQty <= 0) return StockStatus.outOfStock;
    if (minStock > 0 && stockQty <= minStock) return StockStatus.low;
    return StockStatus.ok;
  }

  double get stockValue => stockQty * costPrice;
}

enum StockStatus { ok, low, outOfStock, notTracked }

class KhoStats {
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;
  final double totalValue;
  final double todayInQty;
  final double todayInCost;

  const KhoStats({
    required this.totalItems,
    required this.lowStockItems,
    required this.outOfStockItems,
    required this.totalValue,
    required this.todayInQty,
    required this.todayInCost,
  });

  static const empty = KhoStats(
    totalItems: 0, lowStockItems: 0, outOfStockItems: 0,
    totalValue: 0, todayInQty: 0, todayInCost: 0,
  );
}
