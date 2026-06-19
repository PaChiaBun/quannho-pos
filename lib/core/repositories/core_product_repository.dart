<<<<<<< HEAD
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/store_auth_service.dart';


// ─────────────────────────────────────────────────────────────────────────────
// CORE PRODUCT REPOSITORY — 100% Supabase
// Không dùng Drift. Mọi thao tác đều ghi thẳng lên Supabase.
// ─────────────────────────────────────────────────────────────────────────────
class CoreProductRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    final id = info['store_id'] as String?;
    assert(() { debugPrint('[CoreProductRepo] _storeId() → $id'); return true; }());
    return id;
  }

  // ── Streams / Reactive ────────────────────────────────────────────────────

  /// Tất cả sản phẩm chưa xóa (dùng cho Kho, quản lý sản phẩm)
  Stream<List<ProductModel>> watchAll() async* {
    final storeId = await _storeId();
    if (storeId == null) {
      assert(() { debugPrint('[CoreProductRepo] watchAll → storeId null, yield []'); return true; }());
      yield []; return;
    }

    final initial = await _fetchAll(storeId);
    assert(() { debugPrint('[CoreProductRepo] watchAll → ${initial.length} items'); return true; }());
    yield initial;

    // Bắt lỗi stream bất đồng bộ (như RealtimeSubscribeException) bằng vòng lặp await for + try-catch
    final realtimeStream = _sb
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('store_id', storeId)
        .map((rows) => rows
            .where((r) => r['is_deleted'] != true)
            .map(ProductModel.fromMap)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name)));

    try {
      await for (final products in realtimeStream) {
        yield products;
      }
    } catch (e) {
      assert(() { debugPrint('[CoreProductRepo] watchAll → Realtime lỗi ($e), fallback polling 10s'); return true; }());
      // Fallback: Tự động chuyển sang chế độ Polling âm thầm mà không gây lỗi giao diện
      while (true) {
        await Future.delayed(const Duration(seconds: 10));
        try {
          yield await _fetchAll(storeId);
        } catch (_) {
          // Tiếp tục vòng lặp nếu lỗi mạng tạm thời
        }
      }
    }
  }


  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<List<ProductModel>> _fetchAll(String storeId) async {
    final rows = await _sb
        .from('products')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false)
        .order('name');
    return rows.map(ProductModel.fromMap).toList();
  }

  Future<ProductModel?> getById(String id) async {
    final row = await _sb
        .from('products')
        .select()
        .eq('id', id)
        .maybeSingle();
    return row != null ? ProductModel.fromMap(row) : null;
=======
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
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
    String? imageUrl,
    String? stationCode,
    bool isAvailable = true,
    bool isTopping = false,
    String? toppingUnit,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    final id  = _uuid.v4();
    final now     = DateTime.now().toUtc();
    final nowIso  = now.toIso8601String();
    final nowMs   = now.millisecondsSinceEpoch;
    await _sb.from('products').insert({
      'id':           id,
      'store_id':     storeId,
      'name':         name,
      'sku':          sku,
      'category':     category,
      'unit':         unit,
      'product_type': productType,
      'stock_qty':    stockQty.round(),
      'min_stock':    minStock.round(),
      'sell_price':   sellPrice.round(),
      'cost_price':   costPrice.round(),
      'image_url':    imageUrl,
      'station_code': stationCode ?? 'nong',
      'is_available': isAvailable,
      'is_active':    true,
      'is_deleted':   false,
      'is_topping':   isTopping,
      if (isTopping && toppingUnit != null) 'topping_unit': toppingUnit,
      'created_at':   nowIso,
      'updated_at':   nowMs,
    });
    return id;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _sb.from('products').update({
      ...data,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch, // bigint
    }).eq('id', id);
  }

  /// Chỉ cập nhật tồn kho (delta: + nhập / - xuất)
  /// ‼️ Race condition known issue: read-then-write không atomic.
  /// Giải pháp triệt để cần Postgres RPC `increment_stock(id, delta)`.
  /// Hiện tại: clamp bảo vệ khỏi âm để giảm thiểu hậu quả race condition.
  Future<void> updateStockQty(String id, double delta) async {
    final product = await getById(id);
    if (product == null) return;
    // FIX Bug #40: giữ 3 chữ số thập phân; clamp(-9999999, 9999999) tránh overflow
    // stock âm có thể xảy ra khi race condition — cần Postgres RPC để fix triệt để
    final newQty = double.parse(
        (product.stockQty + delta).clamp(-9999999.0, 9999999.0).toStringAsFixed(3));
    await _sb.from('products').update({
      'stock_qty':  newQty,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch, // bigint
    }).eq('id', id);
  }

  /// Soft delete — KHÔNG xóa thật
  Future<void> softDelete(String id) async {
    await update(id, {'is_deleted': true, 'is_active': false});
  }

  Future<List<ProductModel>> searchByName(String query) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final rows = await _sb
        .from('products')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false)
        .ilike('name', '%$query%')
        .limit(20);
    return rows.map(ProductModel.fromMap).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final String? sku;
  final String? category;
  final String unit;
  final String productType;
  final double stockQty;
  final double minStock;
  final double sellPrice;
  final double costPrice;
  final double costPriceLatest; // ‼️ FIX: giá nhập mới nhất (từ purchase_orders)
  final String? imageUrl;
  final String stationCode;
  final bool isAvailable;
  final bool isActive;
  final bool isDeleted;
  final bool isTopping;    // true = đây là topping (bán riêng + gắn vào món)
  final String toppingUnit; // đơn vị khi chọn topping: "viên", "phần", "ml"...

  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.sku,
    this.category,
    required this.unit,
    required this.productType,
    required this.stockQty,
    required this.minStock,
    required this.sellPrice,
    required this.costPrice,
    this.costPriceLatest = 0,
    this.imageUrl,
    required this.stationCode,
    required this.isAvailable,
    required this.isActive,
    required this.isDeleted,
    this.isTopping = false,
    this.toppingUnit = 'phần',
  });

  factory ProductModel.fromMap(Map<String, dynamic> m) => ProductModel(
        id:               m['id'] as String,
        storeId:          m['store_id'] as String? ?? '',
        name:             m['name'] as String,
        sku:              m['sku'] as String?,
        category:         m['category'] as String?,
        unit:             m['unit'] as String? ?? 'phần',
        productType:      m['product_type'] as String? ?? 'finished',
        stockQty:         (m['stock_qty'] as num?)?.toDouble() ?? 0,
        minStock:         (m['min_stock'] as num?)?.toDouble() ?? 0,
        sellPrice:        (m['sell_price'] as num?)?.toDouble() ?? 0,
        costPrice:        (m['cost_price'] as num?)?.toDouble() ?? 0,
        costPriceLatest:  (m['cost_price_latest'] as num?)?.toDouble() ?? 0,
        imageUrl:         m['image_url'] as String?,
        stationCode:      m['station_code'] as String? ?? 'nong',
        isAvailable:      m['is_available'] as bool? ?? true,
        isActive:         m['is_active'] as bool? ?? true,
        isDeleted:        m['is_deleted'] as bool? ?? false,
        isTopping:        m['is_topping'] as bool? ?? false,
        toppingUnit:      m['topping_unit'] as String? ?? 'phần',
      );

  Map<String, dynamic> toMap() => {
        'id': id, 'store_id': storeId, 'name': name, 'sku': sku,
        'category': category, 'unit': unit, 'product_type': productType,
        'stock_qty': stockQty, 'min_stock': minStock,
        'sell_price': sellPrice, 'cost_price': costPrice,
        'image_url': imageUrl, 'station_code': stationCode,
        'is_available': isAvailable, 'is_active': isActive, 'is_deleted': isDeleted,
        'is_topping': isTopping, 'topping_unit': toppingUnit,
      };
}
=======
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
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
