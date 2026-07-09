import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/repositories/core_product_repository.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KHO REPOSITORY — 100% Supabase
// stock_movements: APPEND-ONLY — không UPDATE/DELETE
// ─────────────────────────────────────────────────────────────────────────────
class KhoRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final CoreProductRepository _productRepo;
  final _uuid = const Uuid();

  KhoRepository(this._productRepo);

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Stock view (từ products) ──────────────────────────────────────────────

  Stream<List<StockItem>> watchAllStock() async* {
    yield* _productRepo.watchAll().map((products) =>
        products.map(StockItem.fromProduct).toList());
  }

  Stream<List<StockItem>> watchLowStock() async* {
    yield* _productRepo.watchAll().map((products) => products
        .where((p) => p.minStock > 0 && p.stockQty <= p.minStock)
        .map(StockItem.fromProduct)
        .toList());
  }

  Stream<List<StockItem>> watchOutOfStock() async* {
    yield* _productRepo.watchAll().map((products) => products
        .where((p) => p.stockQty <= 0)
        .map(StockItem.fromProduct)
        .toList());
  }

  // ── Stock movements ───────────────────────────────────────────────────────

  Stream<T> _robustStream<T>(
    String table,
    String columnFilter,
    String valueFilter,
    T Function(List<Map<String, dynamic>>) mapper,
  ) async* {
    Future<T> fetch() async {
      final rows = await _sb.from(table).select().eq(columnFilter, valueFilter);
      return mapper(rows);
    }

    // Initial fetch
    try {
      yield await fetch();
    } catch (e) {
      print('[RobustStream] Initial fetch err on $table: $e');
    }

    // Realtime connection with fallback to polling on async errors (e.g. RealtimeSubscribeException)
    while (true) {
      try {
        final stream = _sb.from(table).stream(primaryKey: ['id']).eq(columnFilter, valueFilter);
        await for (final rows in stream) {
          yield mapper(rows);
        }
      } catch (e) {
        print('[RobustStream] Realtime err on $table: $e. Falling back to poll 10s.');
        
        // Polling âm thầm 10 giây (chia làm 2 lần 5s) trước khi thử kết nối lại Realtime
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
        
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
      }
    }
  }

  Stream<List<StockMovementModel>> watchMovements(String productId) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    yield* _robustStream(
      'stock_movements', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['product_id'] == productId)
          .map(StockMovementModel.fromMap)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt))
    );
  }

  Stream<List<StockMovementModel>> watchRecentMovements({int limit = 50}) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    yield* _robustStream(
      'stock_movements', 'store_id', storeId,
      (rows) {
        final sorted = rows.map(StockMovementModel.fromMap).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return sorted.take(limit).toList();
      }
    );
  }

  // ── Nhập hàng ─────────────────────────────────────────────────────────────

  Future<void> receiveStock({
    required String productId,
    required String productName,
    required double quantity,
    required double unitCost,
    String? supplierId,
    String? supplierName,
    String? reference,
    String? note,
  }) async {
    assert(quantity > 0);
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final now        = DateTime.now().toUtc().toIso8601String();
    final movementId = _uuid.v4(); // dùng chung cho stock_movement + finance_record

    // 1. Ghi stock_movement (APPEND-ONLY) — delta là numeric(12,3)
    await _sb.from('stock_movements').insert({
      'id':           movementId,
      'store_id':     storeId,
      'product_id':   productId,
      'delta':        double.parse(quantity.toStringAsFixed(3)),
      'reason':       'purchase',
      'note':         supplierName != null
          ? '$supplierName${note != null ? ' — $note' : ''}'
          : note,
      'created_at':   now,
    });

    // 2. Cập nhật stock_qty trên products
    await _productRepo.updateStockQty(productId, quantity);

    // Cập nhật cost_price_latest — ‼️ bắt buộc để COGS tính đúng
    if (unitCost > 0) {
      try {
        await _sb.from('products').update({
          'cost_price_latest': unitCost,
        }).eq('id', productId);
      } catch (e) {
        debugPrint('[Kho] ⚠️ cost_price_latest update failed for $productId: $e');
      }
    }

    // 3. Ghi finance_record tự động (expense: nhập hàng) — reference_id → movementId
    // ‼️ FIX Bug #39: wrap silent fail — trước đây không có try/catch → lỗi schema block toàn bộ nhập hàng
    try {
      await _sb.from('finance_records').insert({
        'id':           _uuid.v4(),
        'store_id':     storeId,
        'type':         'expense',
        'amount':       quantity * unitCost,
        'description':  'Nhập hàng: $productName',
        'reference_id': movementId,  // ← audit trail: trace về stock_movement
        'is_auto':      true,
        'recorded_at':  now,
        'fund_type':    'cash',
      });
    } catch (e) {
      debugPrint('[Kho] ⚠️ receiveStock finance_record failed: $e');
    }
    AppLogger.info('kho', 'Nhap kho nhanh san pham $productName - So luong: $quantity.');
  } // end receiveStock

  /// Điều chỉnh kho thủ công
  Future<void> adjustStock({

    required String productId,
    required double quantity,
    required String reason,
    String? note,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final now = DateTime.now().toUtc().toIso8601String();

    await _sb.from('stock_movements').insert({
      'id':         _uuid.v4(),
      'store_id':   storeId,
      'product_id': productId,
      'delta':      double.parse(quantity.toStringAsFixed(3)),
      'reason':     reason,
      'note':       note,
      'created_at': now,
    });

    await _productRepo.updateStockQty(productId, quantity);

    try {
      final prod = await _productRepo.getById(productId);
      final prodName = prod?.name ?? productId;
      AppLogger.info('kho', 'Dieu chinh ton kho san pham $prodName. Ly do: $reason. Thay doi: $quantity.');
    } catch (_) {}
  }

  // ── Suppliers ─────────────────────────────────────────────────────────────

  Stream<List<SupplierModel>> watchSuppliers() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    yield* _robustStream(
      'suppliers', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['is_deleted'] != true)
          .map(SupplierModel.fromMap)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name))
    );
  }

  Future<List<SupplierModel>> fetchSuppliers() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final rows = await _sb
        .from('suppliers')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false)
        .order('name');
    return rows.map(SupplierModel.fromMap).toList();
  }

  Future<String> addSupplier({
    required String name,
    String? phone,
    String? address,
    String? note,
    String? contactPerson,
    String? email,
    String? category,
    String? paymentTerms,
    String? bankAccount,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final id = _uuid.v4();
    await _sb.from('suppliers').insert({
      'id': id, 'store_id': storeId,
      'name': name, 'phone': phone,
      'address': address, 'note': note,
      'contact_person': contactPerson,
      'email': email,
      'category': category,
      'payment_terms': paymentTerms,
      'bank_account': bankAccount,
    });
    return id;
  }

  Future<void> updateSupplier(String id, {
    required String name,
    String? phone,
    String? address,
    String? note,
    String? contactPerson,
    String? email,
    String? category,
    String? paymentTerms,
    String? bankAccount,
  }) async {
    await _sb.from('suppliers').update({
      'name': name, 'phone': phone,
      'address': address, 'note': note,
      'contact_person': contactPerson,
      'email': email,
      'category': category,
      'payment_terms': paymentTerms,
      'bank_account': bankAccount,
    }).eq('id', id);
  }

  Future<void> deleteSupplier(String id) async {
    await _sb.from('suppliers').update({'is_deleted': true}).eq('id', id);
  }

  // ── Purchase Orders ───────────────────────────────────────────────────────

  Stream<List<PurchaseOrderModel>> watchPurchaseOrders() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    yield* _robustStream(
      'purchase_orders', 'store_id', storeId,
      (rows) => rows,
    ).asyncMap((rows) async {
          if (rows.isEmpty) return <PurchaseOrderModel>[];

          // Sort theo ngày giảm dần
          rows.sort((a, b) =>
              (b['created_at'] as String).compareTo(a['created_at'] as String));

          // Fetch items của tất cả PO trong 1 query
          final poIds = rows.map((r) => r['id'] as String).toList();
          final itemRows = await _sb
              .from('purchase_items')
              .select()
              .inFilter('po_id', poIds);

          // Group items theo po_id
          final itemsByPo = <String, List<PurchaseItemModel>>{};
          for (final row in itemRows) {
            final r = row as Map<String, dynamic>;
            final poId = r['po_id'] as String? ?? '';
            itemsByPo.putIfAbsent(poId, () => []).add(PurchaseItemModel.fromMap(r));
          }

          // Build models kèm items
          return rows.map((row) {
            final id = row['id'] as String;
            return PurchaseOrderModel.fromMap({...row, '__items': itemsByPo[id] ?? []});
          }).toList();
        });
  }

  Future<List<PurchaseOrderModel>> fetchPurchaseOrders() async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    final poRows = await _sb
        .from('purchase_orders')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false);

    if (poRows.isEmpty) return [];

    final poIds = poRows.map((r) => r['id'] as String).toList();
    final itemRows = await _sb
        .from('purchase_items')
        .select()
        .inFilter('po_id', poIds);

    final itemsByPo = <String, List<PurchaseItemModel>>{};
    for (final r in itemRows) {
      final poId = r['po_id'] as String? ?? '';
      itemsByPo.putIfAbsent(poId, () => []).add(PurchaseItemModel.fromMap(r));
    }

    return poRows.map((r) {
      final id = r['id'] as String;
      return PurchaseOrderModel.fromMap({...r, '__items': itemsByPo[id] ?? []});
    }).toList();
  }

  Future<List<PurchaseItemModel>> getPurchaseItems(String poId) async {
    final rows = await _sb
        .from('purchase_items')
        .select()
        .eq('po_id', poId);
    return rows.map(PurchaseItemModel.fromMap).toList();
  }

  /// Fetch PO tươi từ DB theo ID (dùng khi cần dữ liệu mới nhất, tránh timing của stream)
  Future<PurchaseOrderModel?> fetchPurchaseOrderById(String poId) async {
    try {
      final row = await _sb
          .from('purchase_orders')
          .select()
          .eq('id', poId)
          .maybeSingle();
      if (row == null) return null;
      final items = await getPurchaseItems(poId);
      return PurchaseOrderModel.fromMap({...row, '__items': items});
    } catch (e) {
      debugPrint('[KhoRepo] fetchPurchaseOrderById error: $e');
      return null;
    }
  }

  /// Trả về URL ảnh hoá đơn cuối cùng (sau upload nếu có)
  Future<String?> updatePurchaseOrderInfo(
    String poId, {
    String? note,
    String? supplierName,
    String? supplierId,
    String? newInvoiceImagePath,
    String? existingInvoiceImageUrl,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    String? invoiceImageUrl = existingInvoiceImageUrl;

    // Upload ảnh mới nếu có — KHÔNG catch silently để UI biết lỗi
    if (newInvoiceImagePath != null) {
      final bytes = await File(newInvoiceImagePath).readAsBytes();
      final rawExt = newInvoiceImagePath.split('.').last.split('?').first.toLowerCase();
      final ext    = ['jpeg', 'png', 'webp'].contains(rawExt) ? rawExt : 'jpeg';
      final mimeType = ext == 'png'  ? 'image/png'
                     : ext == 'webp' ? 'image/webp' : 'image/jpeg';
      final path = 'purchase-invoices/$storeId/$poId-edit.$ext';
      await _sb.storage.from('invoices').uploadBinary(
          path, bytes,
          fileOptions: FileOptions(contentType: mimeType, upsert: true));
      final publicUrl = _sb.storage.from('invoices').getPublicUrl(path);
      // cache-buster để Image.network tải lại ảnh mới
      invoiceImageUrl = '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[KhoRepo] ✅ Invoice image uploaded: $path');
    }

    await _sb.from('purchase_orders').update({
      'note':               note,
      'supplier_name':      supplierName ?? '',
      'supplier_id':        supplierId,
      'invoice_image_url':  invoiceImageUrl,
    }).eq('id', poId);

    return invoiceImageUrl;
  }

  /// Tạo phiếu nhập hàng đầy đủ:
  /// 1. purchase_orders + purchase_items
  /// 2. stock_movements cho từng sản phẩm
  /// 3. Cập nhật products.stock_qty
  /// 4. Một finance_record cho tổng phiếu
  Future<String> createPurchaseOrder({
    required List<PurchaseOrderLine> lines,
    String? supplierId,
    String? supplierName,
    String? note,
    DateTime? importDate,
    String? invoiceImagePath,
    String fundType = 'cash',
  }) async {
    assert(lines.isNotEmpty);
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    final poId    = _uuid.v4();
    final dateRef = importDate ?? DateTime.now();
    final dateStr = DateFormat('yyMMdd').format(dateRef);
    final poNumber = 'PO-$dateStr-${poId.substring(0, 4).toUpperCase()}';
    final total   = lines.fold<double>(0, (s, l) => s + l.quantity * l.unitCost);
    final importAt = dateRef.toUtc().toIso8601String();

    // Upload ảnh hoá đơn nếu có
    String? invoiceImageUrl;
    if (invoiceImagePath != null) {
      try {
        final bytes = await File(invoiceImagePath).readAsBytes();
        final rawExt = invoiceImagePath.split('.').last.split('?').first.toLowerCase();
        // Chuẩn hoá extension và MIME type
        final ext      = ['jpeg','png','webp'].contains(rawExt) ? rawExt : 'jpeg';
        final mimeType = ext == 'png' ? 'image/png'
                       : ext == 'webp' ? 'image/webp'
                       : 'image/jpeg'; // jpg, jpeg, heic đều dùng image/jpeg
        final path     = 'purchase-invoices/$storeId/$poId.$ext';
        debugPrint('[KhoRepo] Uploading invoice: $path ($mimeType, ${bytes.length} bytes)');
        await _sb.storage.from('invoices').uploadBinary(
            path, bytes,
            fileOptions: FileOptions(contentType: mimeType, upsert: true));
        invoiceImageUrl = _sb.storage.from('invoices').getPublicUrl(path);
        debugPrint('[KhoRepo] Invoice URL: $invoiceImageUrl');
      } catch (e) {
        debugPrint('[KhoRepo] ⚠️ Invoice upload failed: $e');
      }
    }

    // 1. Tạo purchase_order
    await _sb.from('purchase_orders').insert({
      'id':                 poId,
      'store_id':           storeId,
      'po_number':          poNumber,
      'supplier_id':        supplierId,
      'supplier_name':      supplierName ?? '',
      'status':             'received',
      'total_amount':       total,
      'note':               note,
      'invoice_image_url':  invoiceImageUrl,    // ← fix: đã bị bỏ sót
      'created_at':         importAt,
    });

    // 2. Tạo purchase_items + stock_movements + cập nhật stock
    for (final line in lines) {
      // purchase_item
      await _sb.from('purchase_items').insert({
        'id':           _uuid.v4(),
        'po_id':        poId,
        'product_id':   line.productId,
        'product_name': line.productName,
        'quantity':     line.quantity,
        'unit_cost':    line.unitCost,
        'subtotal':     line.quantity * line.unitCost,
      });

      // stock_movement (APPEND-ONLY) — delta là numeric(12,3)
      await _sb.from('stock_movements').insert({
        'id':         _uuid.v4(),
        'store_id':   storeId,
        'product_id': line.productId,
        'delta':      double.parse(line.quantity.toStringAsFixed(3)),
        'reason':     'purchase',
        'note':       'Phiếu $poNumber',
        'created_at': importAt,
      });

      // Lấy thông tin sản phẩm hiện tại để tính giá vốn bình quân tức thời
      final product = await _productRepo.getById(line.productId);
      double newCost = line.unitCost;
      if (product != null) {
        final oldQty = product.stockQty;
        final oldCost = product.costPrice > 0 ? product.costPrice : product.costPriceLatest;
        if (oldQty > 0) {
          newCost = ((oldQty * oldCost) + (line.quantity * line.unitCost)) / (oldQty + line.quantity);
        }
      }

      // Cập nhật stock_qty
      await _productRepo.updateStockQty(line.productId, line.quantity);

      // Cập nhật cost_price (bình quân mới) và cost_price_latest (giá nhập gần nhất)
      if (line.unitCost > 0) {
        try {
          await _sb.from('products').update({
            'cost_price':        double.parse(newCost.toStringAsFixed(2)),
            'cost_price_latest': line.unitCost,
          }).eq('id', line.productId);
        } catch (e) {
          debugPrint('[Kho] ⚠️ cost_price update failed for ${line.productId}: $e');
        }
      }
    }

    // 3. Finance record (1 phiếu cho cả PO) — silent fail nếu Finance module tắt
    try {
      await _sb.from('finance_records').insert({
        'id':          _uuid.v4(),
        'store_id':    storeId,
        'type':        'expense',
        'amount':      total,
        'description': 'Nhập hàng $poNumber${supplierName != null ? ' — $supplierName' : ''}',
        'reference_id': poId,
        'is_auto':     true,
        'recorded_at': importAt,
        'fund_type':   fundType,
      });
    } catch (e) {
      debugPrint('[Kho] ⚠️ PO finance_record insert failed: $e');
    }

    return poId;
  }

  /// Huỷ phiếu nhập: hoàn kho + đánh dấu cancelled + ghi finance + notification
  Future<void> cancelPurchaseOrder(String poId, {
    String? cancelReason,
    String? cancelledBy,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    // ‼️ FIX Bug #43: idempotency guard — tránh double-cancel hoàn kho 2 lần
    // Nếu PO đã cancelled: hoàn kho 2 lần → stock âm + 2 finance income records
    final poStatus = await _sb.from('purchase_orders')
        .select('status')
        .eq('id', poId)
        .maybeSingle();
    if (poStatus == null) throw Exception('Phiếu nhập không tồn tại');
    if (poStatus['status'] == 'cancelled') {
      debugPrint('[Kho] cancelPurchaseOrder: PO $poId đã cancelled, bỏ qua');
      return;
    }

    // 1. Load items của PO
    final items = await getPurchaseItems(poId);
    if (items.isEmpty) throw Exception('Không tìm thấy sản phẩm trong phiếu');


    // 2. Kiểm tra stock không bị âm
    for (final item in items) {
      if (item.productId.isEmpty) continue;
      final rows = await _sb
          .from('products')
          .select('stock_qty, name')
          .eq('id', item.productId)
          .maybeSingle();
      if (rows == null) continue;
      final currentStock = (rows['stock_qty'] as num?)?.toDouble() ?? 0;
      if (currentStock - item.quantity < 0) {
        throw Exception(
            '"${item.productName}" chỉ còn ${currentStock.toStringAsFixed(0)} '
            '— không đủ để hoàn kho ${item.quantity.toStringAsFixed(0)}');
      }
    }

    final now = DateTime.now().toUtc().toIso8601String();

    // 3. Load PO
    final poRow = await _sb
        .from('purchase_orders')
        .select('po_number, total_amount')
        .eq('id', poId)
        .single();
    final poNumber    = poRow['po_number'] as String? ?? poId;
    final totalAmount = (poRow['total_amount'] as num?)?.toDouble() ?? 0;

    // 4. Hoàn kho
    for (final item in items) {
      if (item.productId.isEmpty) continue;
      final noteText = cancelReason != null
          ? 'Huỷ phiếu $poNumber — Lý do: $cancelReason'
          : 'Huỷ phiếu $poNumber';
      await _sb.from('stock_movements').insert({
        'id':         _uuid.v4(),
        'store_id':   storeId,
        'product_id': item.productId,
        'delta':      double.parse((-item.quantity).toStringAsFixed(3)),
        'reason':     'cancel_purchase',
        'note':       noteText,
        'created_at': now,
      });
      await _productRepo.updateStockQty(item.productId, -item.quantity);
    }

    // 5. Update PO status + lưu lý do huỷ
    await _sb
        .from('purchase_orders')
        .update({
          'status': 'cancelled',
          if (cancelReason != null) 'cancel_reason': cancelReason,
          if (cancelledBy != null)  'cancelled_by':  cancelledBy,
          'cancelled_at': now,
        })
        .eq('id', poId);

    // 6. Finance hoàn tiền (silent fail)
    try {
      String fundType = 'cash';
      try {
        final origFinance = await _sb
            .from('finance_records')
            .select('fund_type')
            .eq('store_id', storeId)
            .eq('reference_id', poId)
            .eq('type', 'expense')
            .maybeSingle();
        if (origFinance != null) {
          fundType = origFinance['fund_type'] as String? ?? 'cash';
        }
      } catch (_) {}

      await _sb.from('finance_records').insert({
        'id':           _uuid.v4(),
        'store_id':     storeId,
        'type':         'income',
        'amount':       totalAmount,
        'description':  'Huỷ nhập hàng $poNumber${cancelReason != null ? ' — $cancelReason' : ''}',
        'reference_id': poId,
        'is_auto':      true,
        'recorded_at':  now,
        'fund_type':    fundType,
      });
    } catch (e) {
      debugPrint('[Kho] ⚠️ cancel finance_record insert failed: $e');
    }

    // 7. Ghi notification cho chủ quán (silent fail)
    try {
      final actor = cancelledBy ?? 'Hệ thống';
      final body  = cancelReason != null
          ? '$actor đã huỷ phiếu $poNumber. Lý do: $cancelReason'
          : '$actor đã huỷ phiếu $poNumber';
      await _sb.from('notifications').insert({
        'id':         _uuid.v4(),
        'store_id':   storeId,
        'type':       'po_cancelled',
        'title':      'Phiếu nhập bị huỷ',
        'body':       body,
        'reference_id': poId,
        'is_read':    false,
        'created_at': now,
      });
    } catch (_) {}
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<KhoStats> getStats() async {
    final storeId = await _storeId();
    if (storeId == null) return KhoStats.empty;

    final rows = await _sb
        .from('products')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false);

    final products = rows.map(ProductModel.fromMap).toList();
    final lowStock  = products.where((p) => p.minStock > 0 && p.stockQty <= p.minStock).length;
    final outOfStock = products.where((p) => p.stockQty <= 0).length;
    final totalValue = products.fold<double>(0, (s, p) {
      // ‼️ FIX: dùng costPriceLatest nếu > 0, fallback về costPrice
      final effectiveCost = p.costPriceLatest > 0 ? p.costPriceLatest : p.costPrice;
      return s + p.stockQty * effectiveCost;
    });

    // ‼️ FIX Bug #23: dùng DateTime(y,m,d) thay .copyWith() — tránh lệch giờ DST
    // cũng thêm lt (exclusive upper bound) — nhất quán với toàn hệ thống
    final now2       = DateTime.now();
    final startOfDay = DateTime(now2.year, now2.month, now2.day).toUtc().toIso8601String();
    final endOfDay   = DateTime(now2.year, now2.month, now2.day + 1).toUtc().toIso8601String();
    final todayIn = await _sb
        .from('stock_movements')
        .select()
        .eq('store_id', storeId)
        .eq('reason', 'purchase')
        .gte('created_at', startOfDay)
        .lt('created_at', endOfDay); // exclusive upper — nhất quán với finance
    // ‼️ FIX: tính todayInCost thực bằng cách join cost_price_latest
    final todayInQty = todayIn.fold<double>(0, (s, m) => s + ((m['delta'] as num?)?.toDouble() ?? 0));
    double todayInCost = 0;
    if (todayIn.isNotEmpty) {
      final productIds = todayIn
          .map((m) => m['product_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (productIds.isNotEmpty) {
        final costRows = await _sb
            .from('products')
            .select('id, cost_price_latest, cost_price')
            .eq('store_id', storeId)
            .inFilter('id', productIds);
        final costMap = <String, double>{};
        for (final r in (costRows as List)) {
          final id = r['id'] as String;
          final latest = (r['cost_price_latest'] as num?)?.toDouble() ?? 0;
          final base   = (r['cost_price'] as num?)?.toDouble() ?? 0;
          costMap[id]  = latest > 0 ? latest : base;
        }
        for (final m in todayIn) {
          final pid  = m['product_id'] as String? ?? '';
          final delta = (m['delta'] as num?)?.toDouble() ?? 0;
          todayInCost += delta * (costMap[pid] ?? 0);
        }
      }
    }

    return KhoStats(
      totalItems:      products.length,
      lowStockItems:   lowStock,
      outOfStockItems: outOfStock,
      totalValue:      totalValue,
      todayInQty:      todayInQty,
      todayInCost:     todayInCost,
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
  final String? imageUrl;
  final double stockQty;
  final double minStock;
  final double costPrice;
  final double costPriceLatest;
  final double sellPrice;
  final String productType;
  final bool isTopping;
  final String toppingUnit;
  final String stationCode;

  const StockItem({
    required this.id,
    required this.name,
    required this.unit,
    this.sku,
    this.category,
    this.imageUrl,
    required this.stockQty,
    required this.minStock,
    required this.costPrice,
    this.costPriceLatest = 0,
    required this.sellPrice,
    this.productType = 'finished',
    this.isTopping = false,
    this.toppingUnit = 'phần',
    this.stationCode = 'bep_nong',
  });

  factory StockItem.fromProduct(ProductModel p) => StockItem(
        id:               p.id,
        name:             p.name,
        unit:             p.unit,
        sku:              p.sku,
        category:         p.category,
        imageUrl:         p.imageUrl,
        stockQty:         p.stockQty,
        minStock:         p.minStock,
        costPrice:        p.costPrice,
        costPriceLatest:  p.costPriceLatest,
        sellPrice:        p.sellPrice,
        productType:      p.productType,
        isTopping:        p.isTopping,
        toppingUnit:      p.toppingUnit,
        stationCode:      p.stationCode,
      );

  StockStatus get status {
    if (stockQty <= 0) return StockStatus.outOfStock;
    if (minStock <= 0) return StockStatus.untracked;
    if (stockQty <= minStock) return StockStatus.low;
    return StockStatus.ok;
  }

  double get stockValue {
    final effectiveCost = costPriceLatest > 0 ? costPriceLatest : costPrice;
    return stockQty * effectiveCost;
  }

}

enum StockStatus { ok, low, outOfStock, untracked }

class StockMovementModel {
  final String id;
  final String productId;
  final double delta;
  final String reason;
  final String? note;
  final String createdAt;

  const StockMovementModel({
    required this.id,
    required this.productId,
    required this.delta,
    required this.reason,
    this.note,
    required this.createdAt,
  });

  factory StockMovementModel.fromMap(Map<String, dynamic> m) =>
      StockMovementModel(
        id:        m['id'] as String,
        productId: m['product_id'] as String? ?? '',
        // ‼️ FIX Bug #46: null-safe cast — delta NULL crash khi schema migration
        delta:     (m['delta'] as num?)?.toDouble() ?? 0,
        reason:    m['reason'] as String? ?? '',
        note:      m['note'] as String?,
        createdAt: m['created_at'] as String? ?? '',
      );
}

class SupplierModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final String? contactPerson;
  final String? email;
  final String? category;
  final String? paymentTerms;
  final String? bankAccount;

  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.note,
    this.contactPerson,
    this.email,
    this.category,
    this.paymentTerms,
    this.bankAccount,
  });

  factory SupplierModel.fromMap(Map<String, dynamic> m) => SupplierModel(
    id:            m['id'] as String,
    name:          m['name'] as String,
    phone:         m['phone'] as String?,
    address:       m['address'] as String?,
    note:          m['note'] as String?,
    contactPerson: m['contact_person'] as String?,
    email:         m['email'] as String?,
    category:      m['category'] as String?,
    paymentTerms:  m['payment_terms'] as String?,
    bankAccount:   m['bank_account'] as String?,
  );
}

class PurchaseOrderLine {
  final String productId;
  final String productName;
  final String unit;
  final double quantity;
  final double unitCost;

  const PurchaseOrderLine({
    required this.productId,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.unitCost,
  });

  double get subtotal => quantity * unitCost;
}

class PurchaseOrderModel {
  final String id;
  final String poNumber;
  final String? supplierId;
  final String? supplierName;
  final String status;
  final double totalAmount;
  final String? note;
  final String createdAt;
  final String? invoiceImageUrl;
  final List<PurchaseItemModel> items;

  const PurchaseOrderModel({
    required this.id,
    required this.poNumber,
    this.supplierId,
    this.supplierName,
    required this.status,
    required this.totalAmount,
    this.note,
    required this.createdAt,
    this.invoiceImageUrl,
    this.items = const [],
  });

  factory PurchaseOrderModel.fromMap(Map<String, dynamic> m) {
    // Items pre-assembled by fetchPurchaseOrders() under '__items' key
    final prebuiltItems = m['__items'] as List<PurchaseItemModel>?;
    return PurchaseOrderModel(
      id:              m['id'] as String,
      poNumber:        m['po_number'] as String? ?? '',
      supplierId:      m['supplier_id'] as String?,
      supplierName:    m['supplier_name'] as String?,
      status:          m['status'] as String? ?? 'received',
      totalAmount:     (m['total_amount'] as num?)?.toDouble() ?? 0,
      note:            m['note'] as String?,
      createdAt:       m['created_at'] as String? ?? '',
      invoiceImageUrl: m['invoice_image_url'] as String?,
      items: prebuiltItems ?? [],
    );
  }
}

class PurchaseItemModel {
  final String id;
  final String productId;
  final String productName;
  final double quantity;
  final double unitCost;
  final double subtotal;

  const PurchaseItemModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.subtotal,
  });

  factory PurchaseItemModel.fromMap(Map<String, dynamic> m) =>
      PurchaseItemModel(
        id:          m['id'] as String,
        productId:   m['product_id'] as String? ?? '',
        productName: m['product_name'] as String? ?? '',
        quantity:    (m['quantity'] as num?)?.toDouble() ?? 0,
        unitCost:    (m['unit_cost'] as num?)?.toDouble() ?? 0,
        subtotal:    (m['subtotal'] as num?)?.toDouble() ?? 0,
      );
}

class KhoStats {
  final int totalItems;
  final int lowStockItems;
  final int outOfStockItems;
  final double totalValue;
  final double todayInQty;
  final double todayInCost;

  const KhoStats({
    required this.totalItems, required this.lowStockItems,
    required this.outOfStockItems, required this.totalValue,
    required this.todayInQty, required this.todayInCost,
  });

  static const empty = KhoStats(
    totalItems: 0, lowStockItems: 0, outOfStockItems: 0,
    totalValue: 0, todayInQty: 0, todayInCost: 0,
  );
}
