import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../services/store_auth_service.dart';

export '../models/product_model.dart';


// ─────────────────────────────────────────────────────────────────────────────
// CORE PRODUCT REPOSITORY — 100% Supabase
// Không dùng Drift. Mọi thao tác đều ghi thẳng lên Supabase.
// ─────────────────────────────────────────────────────────────────────────────
class CoreProductRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  static SupabaseClient get _client => _sb;
  static CoreProductRepository? _instance;
  static CoreProductRepository get instance => _instance ??= CoreProductRepository._internal();

  CoreProductRepository._internal();
  factory CoreProductRepository() => instance;

  final _uuid = const Uuid();
  static final Map<String, List<ProductModel>> _productsCacheByStore = {};

  static final StreamController<String> _changeNotifier =
      StreamController<String>.broadcast();

  /// Stream lắng nghe các sự kiện thay đổi sản phẩm theo storeId
  static Stream<String> get changeStream => _changeNotifier.stream;

  /// Phát tín hiệu cho các stream lắng nghe khi có thay đổi dữ liệu
  static void notifyDataChanged(String storeId) {
    if (!_changeNotifier.isClosed) {
      _changeNotifier.add(storeId);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    final id = info['store_id'];
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

    // Khi quay lại POS/Kho, hiển thị cache RAM ngay thay vì nháy loading.
    final cachedProducts = _productsCacheByStore[storeId];
    if (cachedProducts != null) {
      yield cachedProducts;
    }

    Future<List<ProductModel>?> fetchAndCache() async {
      try {
        final products = await _fetchAll(storeId);
        if (!sameProductSnapshot(_productsCacheByStore[storeId], products)) {
          _productsCacheByStore[storeId] = products;
          return products;
        }
      } catch (e) {
        debugPrint('[CoreProductRepo] fetch error: $e');
      }
      return null;
    }

    final initial = await fetchAndCache();
    if (initial != null) {
      yield initial;
    } else if (_productsCacheByStore[storeId] == null) {
      yield [];
    }

    // Kết hợp kiểm tra định kỳ 15s và thông báo sự kiện tức thì
    final controller = StreamController<List<ProductModel>>();
    Timer? timer;
    StreamSubscription? sub;

    void checkUpdate() async {
      final updated = await fetchAndCache();
      if (updated != null && !controller.isClosed) {
        controller.add(updated);
      }
    }

    timer = Timer.periodic(const Duration(seconds: 15), (_) => checkUpdate());
    sub = _changeNotifier.stream.listen((changedStoreId) {
      if (changedStoreId == storeId) {
        checkUpdate();
      }
    });

    controller.onCancel = () {
      timer?.cancel();
      sub?.cancel();
      controller.close();
    };

    yield* controller.stream;
  }

  @visibleForTesting
  static bool sameProductSnapshot(
    List<ProductModel>? previous,
    List<ProductModel> next,
  ) {
    if (previous == null || previous.length != next.length) return false;
    for (var i = 0; i < next.length; i++) {
      final a = previous[i];
      final b = next[i];
      if (a.id != b.id ||
          a.storeId != b.storeId ||
          a.name != b.name ||
          a.sku != b.sku ||
          a.category != b.category ||
          a.unit != b.unit ||
          a.productType != b.productType ||
          a.stockQty != b.stockQty ||
          a.minStock != b.minStock ||
          a.sellPrice != b.sellPrice ||
          a.costPrice != b.costPrice ||
          a.costPriceLatest != b.costPriceLatest ||
          a.imageUrl != b.imageUrl ||
          a.stationCode != b.stationCode ||
          a.isAvailable != b.isAvailable ||
          a.isActive != b.isActive ||
          a.isDeleted != b.isDeleted ||
          a.isTopping != b.isTopping ||
          a.toppingUnit != b.toppingUnit) {
        return false;
      }
    }
    return true;
  }


  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<List<ProductModel>> _fetchAll(String storeId) async {
    if (storeId.isNotEmpty) {
      _sb.rest.headers['x-store-id'] = storeId;
    }
    final rows = await _sb
        .from('products')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false)
        .order('name');
    return rows.map(ProductModel.fromMap).toList();
  }

  Future<ProductModel?> getById(String id) async {
    final storeId = await _storeId();
    if (storeId != null && storeId.isNotEmpty) {
      _sb.rest.headers['x-store-id'] = storeId;
    }
    final query = _sb.from('products').select().eq('id', id);
    final row = storeId != null && storeId.isNotEmpty
        ? await query.eq('store_id', storeId).maybeSingle()
        : await query.maybeSingle();
    return row != null ? ProductModel.fromMap(row) : null;
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
    String? imageUrl,
    String? stationCode,
    bool isAvailable = true,
    bool isTopping = false,
    String? toppingUnit,
  }) async {
    final storeId = await _storeId();
    if (storeId == null || storeId.isEmpty) throw Exception('Chưa chọn quán');

    _sb.rest.headers['x-store-id'] = storeId;

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
    notifyDataChanged(storeId);
    return id;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    final storeId = await _storeId();
    if (storeId != null && storeId.isNotEmpty) {
      _sb.rest.headers['x-store-id'] = storeId;
    }
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final updatePayload = {
      ...data,
      'updated_at': nowMs,
    };
    if (storeId != null && storeId.isNotEmpty) {
      await _sb.from('products').update(updatePayload).eq('store_id', storeId).eq('id', id);
    } else {
      await _sb.from('products').update(updatePayload).eq('id', id);
    }
    if (storeId != null) {
      notifyDataChanged(storeId);
    }
  }

  /// Chỉ cập nhật tồn kho (delta: + nhập / - xuất)
  /// ‼️ Race condition known issue: read-then-write không atomic.
  /// Giải pháp triệt để cần Postgres RPC `increment_stock(id, delta)`.
  /// Hiện tại: clamp bảo vệ khỏi âm để giảm thiểu hậu quả race condition.
  Future<void> updateStockQty(String id, double delta) async {
    final storeId = await _storeId();
    if (storeId != null && storeId.isNotEmpty) {
      _sb.rest.headers['x-store-id'] = storeId;
    }
    final product = await getById(id);
    if (product == null) return;
    // FIX Bug #40: giữ 3 chữ số thập phân; clamp(-9999999, 9999999) tránh overflow
    // stock âm có thể xảy ra khi race condition — cần Postgres RPC để fix triệt để
    final newQty = double.parse(
        (product.stockQty + delta).clamp(-9999999.0, 9999999.0).toStringAsFixed(3));
    final updatePayload = {
      'stock_qty':  newQty,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch, // bigint
    };
    if (storeId != null && storeId.isNotEmpty) {
      await _sb.from('products').update(updatePayload).eq('store_id', storeId).eq('id', id);
    } else {
      await _sb.from('products').update(updatePayload).eq('id', id);
    }
    if (storeId != null) {
      notifyDataChanged(storeId);
    }
  }

  /// Soft delete — KHÔNG xóa thật
  Future<void> softDelete(String id) async {
    final storeId = await _storeId();
    if (storeId != null && storeId.isNotEmpty) {
      _sb.rest.headers['x-store-id'] = storeId;
    }
    await update(id, {'is_deleted': true, 'is_active': false});
    if (storeId != null) {
      if (_productsCacheByStore.containsKey(storeId)) {
        _productsCacheByStore[storeId] = _productsCacheByStore[storeId]!
            .where((p) => p.id != id)
            .toList();
      }
      notifyDataChanged(storeId);
    }
  }

  /// Xóa hàng loạt (Soft Delete) — cập nhật is_deleted=true, is_active=false
  Future<void> batchSoftDelete(List<String> ids) async {
    if (ids.isEmpty) return;
    final storeId = await _storeId();
    if (storeId == null || storeId.isEmpty) throw Exception('Chưa chọn quán');

    _sb.rest.headers['x-store-id'] = storeId;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;

    bool rpcSuccess = false;
    try {
      final res = await _sb.rpc(
        'batch_soft_delete_products_v1',
        params: {
          'p_store_id': storeId,
          'p_product_ids': ids,
        },
      );
      if (res is Map && res['success'] == true) {
        rpcSuccess = true;
      }
    } catch (e) {
      debugPrint('[CoreProductRepo] RPC batch_soft_delete_products_v1 fallback: $e');
    }

    if (!rpcSuccess) {
      // Chunking fail-safe: chia nhỏ tối đa 15 món/lần để không bao giờ làm tràn URL PostgREST
      const chunkSize = 15;
      for (var i = 0; i < ids.length; i += chunkSize) {
        final chunk = ids.sublist(
          i,
          (i + chunkSize > ids.length) ? ids.length : i + chunkSize,
        );
        await _sb.from('products').update({
          'is_deleted': true,
          'is_active': false,
          'updated_at': nowMs,
        }).eq('store_id', storeId).inFilter('id', chunk);
      }
    }

    if (_productsCacheByStore.containsKey(storeId)) {
      final idSet = ids.toSet();
      _productsCacheByStore[storeId] = _productsCacheByStore[storeId]!
          .where((p) => !idSet.contains(p.id))
          .toList();
    }
    notifyDataChanged(storeId);
  }

  /// Cập nhật trạng thái kinh doanh hàng loạt (Đang bán / Tạm ngưng bán)
  Future<void> batchUpdateAvailability(
    String storeId,
    List<String> ids,
    bool isAvailable,
  ) async {
    if (ids.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (storeId.isNotEmpty) {
      _client.rest.headers['x-store-id'] = storeId;
    }

    // Chunking 15 món/lần chống tràn URL
    const chunkSize = 15;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        (i + chunkSize > ids.length) ? ids.length : i + chunkSize,
      );
      await _client.from('products').update({
        'is_available': isAvailable,
        'updated_at': nowMs,
      }).eq('store_id', storeId).inFilter('id', chunk);
    }

    if (_productsCacheByStore.containsKey(storeId)) {
      final idSet = ids.toSet();
      _productsCacheByStore[storeId] = _productsCacheByStore[storeId]!
          .map((p) => idSet.contains(p.id)
              ? p.copyWith(isAvailable: isAvailable, updatedAt: nowMs)
              : p)
          .toList();
    }

    notifyDataChanged(storeId);
  }

  /// Chuyển đổi danh mục hàng loạt cho các món đã chọn
  Future<void> batchUpdateCategory(
    String storeId,
    List<String> ids,
    String newCategory,
  ) async {
    if (ids.isEmpty) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (storeId.isNotEmpty) {
      _client.rest.headers['x-store-id'] = storeId;
    }

    // Chunking 15 món/lần chống tràn URL
    const chunkSize = 15;
    for (var i = 0; i < ids.length; i += chunkSize) {
      final chunk = ids.sublist(
        i,
        (i + chunkSize > ids.length) ? ids.length : i + chunkSize,
      );
      await _client.from('products').update({
        'category': newCategory,
        'updated_at': nowMs,
      }).eq('store_id', storeId).inFilter('id', chunk);
    }

    if (_productsCacheByStore.containsKey(storeId)) {
      final idSet = ids.toSet();
      _productsCacheByStore[storeId] = _productsCacheByStore[storeId]!
          .map((p) => idSet.contains(p.id)
              ? p.copyWith(category: newCategory, updatedAt: nowMs)
              : p)
          .toList();
    }

    notifyDataChanged(storeId);
  }

  @visibleForTesting
  void setCacheForTesting(String storeId, List<ProductModel> products) {
    _productsCacheByStore[storeId] = products;
  }

  @visibleForTesting
  List<ProductModel>? getCacheForTesting(String storeId) {
    return _productsCacheByStore[storeId];
  }

  Future<List<ProductModel>> searchByName(String query) async {
    final storeId = await _storeId();
    if (storeId == null || storeId.isEmpty) return [];
    _sb.rest.headers['x-store-id'] = storeId;
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
