import 'dart:async';
import 'package:flutter/foundation.dart'; // debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/repositories/core_product_repository.dart';
import '../../../core/repositories/core_customer_repository.dart';
import '../../../core/utils/app_logger.dart';
import '../../kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart';
import '../models/coupon_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// POS REPOSITORY — 100% Supabase
// Không dùng Drift. Ghi orders + order_items lên Supabase.
// ─────────────────────────────────────────────────────────────────────────────
class PosRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final CoreProductRepository _productRepo;
  final CoreCustomerRepository _customerRepo;
  final KhoProRepository _khoProRepo;  // inject qua DI — không tạo thủ công nữa
  final _uuid = const Uuid();

  PosRepository(this._productRepo, this._customerRepo, this._khoProRepo);

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Streams ───────────────────────────────────────────────────────────────

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

  Stream<List<OrderModel>> watchTodayOrders() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day) // ‼️ FIX: DateTime(y,m,d) thay copyWith — tránh sai DST
        .toUtc().toIso8601String();
    final endOfDay   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();

    yield* _robustStream(
      'orders', 'store_id', storeId,
      (rows) => rows
        .where((r) =>
            r['status'] == 'completed' &&
            (r['created_at'] as String).compareTo(startOfDay) >= 0 &&
            (r['created_at'] as String).compareTo(endOfDay) < 0) // ‼️ FIX: thêm upper bound
        .map(OrderModel.fromMap)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt))
    );
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  Future<OrderModel?> getOrderById(String id) async {
    final row = await _sb.from('orders').select().eq('id', id).maybeSingle();
    return row != null ? OrderModel.fromMap(row) : null;
  }

  Future<List<OrderItemModel>> getOrderItems(String orderId) async {
    final rows = await _sb
        .from('order_items')
        .select()
        .eq('order_id', orderId);
    return rows.map(OrderItemModel.fromMap).toList();
  }

  // ── Complete Sale ─────────────────────────────────────────────────────────

  Future<String> completeSale({
    required List<CartLine> lines,
    required String paymentMethod,
    String? customerId,
    String? customerName,
    double discount = 0,
    double loyaltyPtsUsed = 0,
    double loyaltyRate = 10000,
    String? note,
    String? sourceType,
    String? sourceId,
    String? staffId,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    assert(lines.isNotEmpty, 'Cart phải có ít nhất 1 món');

    final orderId     = _uuid.v4();
    final orderNumber = await _generateOrderNumber(storeId);
    final now         = DateTime.now().toUtc().toIso8601String();

    final subtotal    = lines.fold<double>(0, (s, l) => s + l.subtotal);
    final totalAmount = (subtotal - discount - loyaltyPtsUsed).clamp(0.0, double.infinity);
    final ptsEarned   = (totalAmount / loyaltyRate).floorToDouble();

    // Tìm staff_members.id trực tiếp hoặc đồng bộ từ store_members
    String? memberRecordId;
    if (staffId != null && staffId.isNotEmpty) {
      try {
        final staffRow = await _sb
            .from('staff_members')
            .select('id')
            .eq('id', staffId)
            .maybeSingle();

        if (staffRow != null) {
          memberRecordId = staffRow['id'] as String?;
        } else {
          final memberRow = await _sb
              .from('store_members')
              .select('id, role, user_accounts(display_name, phone)')
              .eq('store_id', storeId)
              .eq('user_id', staffId)
              .maybeSingle();

          if (memberRow != null) {
            memberRecordId = memberRow['id'] as String?;
            final userAcc = memberRow['user_accounts'] as Map<String, dynamic>?;
            final displayName = userAcc?['display_name'] as String? ?? 'Thu ngân';
            final phone = userAcc?['phone'] as String?;
            final role = memberRow['role'] as String? ?? 'cashier';

            if (memberRecordId != null) {
              await _sb.from('staff_members').upsert({
                'id': memberRecordId,
                'store_id': storeId,
                'name': displayName,
                'role': role,
                'phone': phone,
                'is_active': true,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('[PosRepository] Sync staff_members record failed: $e');
      }
    }

    // 1. Ghi order — map cả cột gốc schema lẫn cột mở rộng
    await _sb.from('orders').insert({
      'id':                 orderId,
      'store_id':           storeId,
      'order_number':       orderNumber,
      'customer_id':        customerId,
      'customer_name':      customerName,
      'subtotal':           subtotal,
      'discount':           discount,
      'tax':                0,
      'total':              totalAmount,      // cột gốc schema
      'total_amount':       totalAmount,      // cột mở rộng
      'payment_method':     paymentMethod,
      'loyalty_pts_earned': ptsEarned,
      'loyalty_pts_used':   loyaltyPtsUsed,
      'status':             'completed',
      'source_type':        sourceType ?? 'pos',
      'source_id':          sourceId,
      'staff_id':           memberRecordId,
      'note':               note,
      'receipt_printed':    false,
      'created_at':         now,
    });

    AppLogger.logUserAction(
      tag: 'checkout',
      action: 'Thanh toán & tạo đơn hàng #$orderNumber (${totalAmount.toInt()}đ)',
      details: {
        'order_id': orderId,
        'order_number': orderNumber,
        'total': totalAmount,
        'payment_method': paymentMethod,
        'item_count': lines.length,
      },
    );

    // 2. Ghi order_items — map đúng tên cột schema
    final itemRows = lines.map((l) => {
      'id':           _uuid.v4(),
      'store_id':     storeId,
      'order_id':     orderId,
      'product_id':   l.productId,
      'name':         l.productName,  // NOT NULL trong schema gốc
      'product_name': l.productName,  // cột mở rộng
      'qty':          l.quantity.toInt(), // cột gốc
      'quantity':     l.quantity,     // cột mở rộng
      'unit_price':   l.unitPrice,
      'cost_price':   l.costPrice,
      'subtotal':     l.subtotal,
    }).toList();
    await _sb.from('order_items').insert(itemRows);

    // 3 + 3b. Cross-module: Trừ kho — phân biệt sản phẩm CÓ/KHÔNG có công thức
    Map<String, RecipeModel> recipeByPosId = {};
    try {
      final allRecipes = await _khoProRepo.fetchRecipes();
      recipeByPosId = {
        for (final r in allRecipes)
          if (r.posProductId != null) r.posProductId!: r,
      };
    } catch (e) { debugPrint('[POS] ❌ fetchRecipes err: $e'); }

    for (final l in lines) {
      final recipe = recipeByPosId[l.productId];
      if (recipe != null && recipe.ingredients.isNotEmpty) {
        // Sản phẩm CÓ công thức → deductIngredients trừ NL + ghi COGS
        try {
          await _khoProRepo.deductIngredients(
            recipe:      recipe,
            quantity:    l.quantity,
            reason:      'sale',
            note:        'POS bán "${l.productName}" × ${l.quantity.toStringAsFixed(0)} (Đơn $orderNumber)',
            referenceId: orderId,
          );
        } catch (e) { debugPrint('[POS] ❌ deductIngredients err: $e'); }
      } else {
        // Sản phẩm KHÔNG có công thức → trừ stock thô
        try {
          await _productRepo.updateStockQty(l.productId, -l.quantity);
          await _sb.from('stock_movements').insert({
            'id':           _uuid.v4(),
            'store_id':     storeId,
            'product_id':   l.productId,
            'delta':        double.parse((-l.quantity).toStringAsFixed(3)),
            'reason':       'sale',
            'reference_id': orderId,
            'note':         'Bán hàng #$orderNumber',
            'created_at':   now,
          });
        } catch (e) { debugPrint('[POS] ❌ stock err: $e'); }
      }
    }

    // 4. Cross-module: Ghi finance_record (nếu Finance module bật)
    // ‼️ Idempotent: check reference_id trước insert — tránh duplicate nếu retry
    try {
      final existIncome = await _sb
          .from('finance_records')
          .select('id')
          .eq('store_id', storeId)
          .eq('reference_id', orderId)
          .eq('type', 'income')
          .eq('is_auto', true)
          .maybeSingle();
      if (existIncome == null) {
        final fundType = (paymentMethod == 'transfer' || paymentMethod == 'card') ? 'bank' : 'cash';
        await _sb.from('finance_records').insert({
          'id':           _uuid.v4(),
          'store_id':     storeId,
          'type':         'income',
          'amount':       totalAmount,
          'description':  'Bán hàng #$orderNumber',
          'reference_id': orderId,
          'is_auto':      true,
          'recorded_at':  now,
          'fund_type':    fundType,
        });
      }
    } catch (e) {
      debugPrint('[POS] ⚠️ finance_record insert failed: $e');
    }

    // 5. Cross-module: Cập nhật loyalty khách hàng — silent fail
    if (customerId != null) {
      try {
        await _customerRepo.recordPurchase(
          customerId,
          amount:     totalAmount,
          ptsEarned:  ptsEarned,
          ptsUsed:    loyaltyPtsUsed,
        );
        // ‼️ Idempotent: upsert theo order_id — tránh duplicate loyalty pts nếu retry
        final existLoyalty = await _sb
            .from('loyalty_transactions')
            .select('id')
            .eq('order_id', orderId)
            .maybeSingle();
        if (existLoyalty == null) {
          await _sb.from('loyalty_transactions').insert({
            'id':          _uuid.v4(),
            'store_id':    storeId,
            'customer_id': customerId,
            'order_id':    orderId,
            'pts_earned':  ptsEarned,
            'pts_used':    loyaltyPtsUsed,
            'note':        'Mua hàng #$orderNumber',
            'created_at':  now,
          });
        }
      } catch (_) {} // Loyalty module không bật — bỏ qua
    }

    return orderId;
  }

  /// Hủy đơn
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    // ‼️ FIX Bug #28: idempotency guard — kiểm tra order chưa bị cancelled
    // Tránh double-reversal nếu cancelOrder được gọi 2 lần (retry/bug)
    final existing = await _sb
        .from('orders')
        .select('status')
        .eq('id', orderId)
        .maybeSingle();
    if (existing == null) return; // order không tồn tại
    if (existing['status'] == 'cancelled') {
      debugPrint('[POS] cancelOrder: đơn $orderId đã cancelled, bỏ qua');
      return;
    }

    await _sb.from('orders').update({
      'status': 'cancelled',
    }).eq('id', orderId);

    // Hoàn lại tồn kho — phân biệt sản phẩm có/không có công thức
    final storeId = await _storeId();
    if (storeId == null) return;
    final now   = DateTime.now().toUtc().toIso8601String();
    final items = await getOrderItems(orderId);

    // Lấy map recipe theo posProductId (silent fail nếu Kho CN chưa bật)
    Map<String, RecipeModel> recipeByPosId = {};
    try {
      final allRecipes = await _khoProRepo.fetchRecipes();
      recipeByPosId = {
        for (final r in allRecipes)
          if (r.posProductId != null) r.posProductId!: r,
      };
    } catch (_) {}

    for (final item in items) {
      final recipe = recipeByPosId[item.productId];

      if (recipe != null && recipe.ingredients.isNotEmpty) {
        // ‼️ FIX: Sản phẩm có công thức — hoàn lại từng nguyên liệu
        try {
          // Lấy đơn vị sản phẩm để quy đổi
          final ingIds = recipe.ingredients
              .where((i) => i.ingredientId != null)
              .map((i) => i.ingredientId!)
              .toList();
          final unitRows = ingIds.isEmpty ? [] : await _sb
              .from('products')
              .select('id, unit')
              .inFilter('id', ingIds);
          final unitMap = <String, String>{
            for (final r in (unitRows as List))
              (r as Map<String, dynamic>)['id'] as String:
              r['unit'] as String? ?? 'gram',
          };

          for (final ing in recipe.ingredients) {
            if (ing.ingredientId == null) continue;
            final prodUnit   = unitMap[ing.ingredientId] ?? ing.unit;
            final actualUsed = ing.actualQuantity * item.quantity;
            final stockDelta = _khoProRepo.convertToProductUnit(actualUsed, ing.unit, prodUnit);

            // Cộng lại tồn kho
            await _productRepo.updateStockQty(ing.ingredientId!, stockDelta);
            // Ghi stock_movement hoàn kho
            await _sb.from('stock_movements').insert({
              'id':           _uuid.v4(),
              'store_id':     storeId,
              'product_id':   ing.ingredientId,
              'delta':        double.parse(stockDelta.toStringAsFixed(3)),
              'reason':       'cancel_reversal',
              'reference_id': orderId,
              'note':         'Hoàn kho hủy đơn: ${recipe.name} × ${item.quantity.toStringAsFixed(0)} phần',
              'created_at':   now,
            });
          }
        } catch (e) {
          debugPrint('[POS] cancelOrder deduct-reversal error: $e');
        }
      } else {
        // Sản phẩm không có công thức — hoàn tồn kho thô
        await _productRepo.updateStockQty(item.productId, item.quantity);
        try {
          await _sb.from('stock_movements').insert({
            'id':           _uuid.v4(),
            'store_id':     storeId,
            'product_id':   item.productId,
            'delta':        double.parse(item.quantity.toStringAsFixed(3)),
            'reason':       'cancel_reversal',
            'reference_id': orderId,
            'note':         'Hoàn kho hủy đơn: ${item.productName}',
            'created_at':   now,
          });
        } catch (_) {}
      }
    }

    // ‼️ FIX: Hoàn lại loyalty points — trước đây hủy đơn không trừ pts đã cộng
    try {
      final orderRow = await _sb.from('orders')
          .select('customer_id, total_amount, loyalty_pts_earned, loyalty_pts_used')
          .eq('id', orderId)
          .maybeSingle();
      final customerId = orderRow?['customer_id'] as String?;
      if (customerId != null) {
        final ptsEarned = (orderRow?['loyalty_pts_earned'] as num?)?.toDouble() ?? 0;
        final ptsUsed   = (orderRow?['loyalty_pts_used']   as num?)?.toDouble() ?? 0;
        final totalAmt  = (orderRow?['total_amount']       as num?)?.toDouble() ?? 0;
        final customer  = await _sb.from('customers')
            .select('loyalty_pts, total_spent, visit_count')
            .eq('id', customerId)
            .maybeSingle();
        if (customer != null) {
          final curPts   = (customer['loyalty_pts']  as num?)?.toDouble() ?? 0;
          final curSpent = (customer['total_spent']  as num?)?.toDouble() ?? 0;
          final curVisit = (customer['visit_count']  as num?)?.toInt()    ?? 0;
          await _sb.from('customers').update({
            // Trừ điểm đã cộng + hoàn điểm đã xài (vì đơn bị hủy)
            'loyalty_pts': (curPts - ptsEarned + ptsUsed).clamp(0, double.infinity),
            'total_spent': (curSpent - totalAmt).clamp(0, double.infinity),
            'visit_count': (curVisit - 1).clamp(0, 999999),
            'updated_at':  now,
          }).eq('id', customerId);
          // Ghi loyalty_transaction hoàn điểm
          if (ptsEarned > 0 || ptsUsed > 0) {
            await _sb.from('loyalty_transactions').insert({
              'id':          _uuid.v4(),
              'store_id':    storeId,
              'customer_id': customerId,
              'order_id':    orderId,
              'pts_earned':  -ptsEarned, // âm = hoàn lại
              'pts_used':    -ptsUsed,   // âm = trả lại điểm đã xài
              'note':        'Hoàn điểm hủy đơn',
              'created_at':  now,
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[POS] cancelOrder loyalty-reversal error: $e');
    }

    // ‼️ FIX Bug #41: Snapshot COGS records TRƯỚC khi insert expense hoàn thu
    // Tránh: query expense sau insert → match chính cái expense "Hoàn thu" vừa tạo
    List cogsSnapshot = [];
    try {
      cogsSnapshot = await _sb.from('finance_records')
          .select('amount')
          .eq('store_id', storeId)
          .eq('reference_id', orderId)
          .eq('type', 'expense')
          .eq('is_auto', true);
    } catch (_) {}

    // Hoàn lại finance_record thu nhập (insert sau khi đã snapshot COGS)
    try {
      final orderRow = await _sb.from('orders')
          .select('total_amount, order_number')
          .eq('id', orderId)
          .maybeSingle();
      final totalAmt = (orderRow?['total_amount'] as num?)?.toDouble() ?? 0;
      final orderNum = orderRow?['order_number'] as String? ?? orderId;
      if (totalAmt > 0) {
        await _sb.from('finance_records').insert({
          'id':           _uuid.v4(),
          'store_id':     storeId,
          'type':         'expense',     // dùng expense để void income
          'amount':       totalAmt,
          'description':  'Hoàn thu hủy đơn $orderNum',
          'reference_id': orderId,
          'is_auto':      true,
          'recorded_at':  now,
        });
      }
    } catch (e) {
      debugPrint('[POS] cancelOrder finance-reversal error: $e');
    }

    // Hoàn COGS từ snapshot (không bị nhiễm bởi expense "Hoàn thu" vừa insert)
    try {
      for (final rec in cogsSnapshot) {
        final cogsAmt = (rec['amount'] as num?)?.toDouble() ?? 0;
        if (cogsAmt <= 0) continue;
        await _sb.from('finance_records').insert({
          'id':           _uuid.v4(),
          'store_id':     storeId,
          'type':         'income',    // income để void COGS expense
          'amount':       cogsAmt,
          'description':  'Hoàn COGS hủy đơn',
          'reference_id': orderId,
          'is_auto':      true,
          'recorded_at':  now,
        });
      }
    } catch (e) {
      debugPrint('[POS] cancelOrder COGS-reversal error: $e');
    }
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<PosStats> getTodayStats() async {
    final storeId = await _storeId();
    if (storeId == null) return PosStats.empty;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day)
        .toUtc()
        .toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day + 1) // exclusive midnight thứ hai
        .toUtc()
        .toIso8601String();

    final orders = await _sb
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', startOfDay)
        .lt('created_at', endOfDay); // ‼️ FIX: thêm lt upper bound — trước đây không có ghép vào ngày mai

    final revenue = orders.fold<double>(0, (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0));
    final uniqueCustomers = orders
        .where((o) => o['customer_id'] != null)
        .map((o) => o['customer_id'] as String)
        .toSet()
        .length;

    // Tính cost từ order_items
    double costTotal = 0;
    if (orders.isNotEmpty) {
      final orderIds = orders.map((o) => o['id'] as String).toList();
      final items = await _sb.from('order_items').select().inFilter('order_id', orderIds);
      costTotal = items.fold<double>(
          0, (s, i) => s + ((i['cost_price'] as num?)?.toDouble() ?? 0) * ((i['quantity'] as num?)?.toDouble() ?? 0));
    }

    return PosStats(
      orderCount:     orders.length,
      revenue:        revenue,
      profit:         revenue - costTotal,
      avgOrderValue:  orders.isEmpty ? 0 : revenue / orders.length,
      customerCount:  uniqueCustomers,
    );
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<String> _generateOrderNumber(String storeId) async {
    final now    = DateTime.now();
    final prefix = 'QN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    // ‼️ FIX Bug #24: thêm lt(endOfDay) exclusive upper bound
    // Trước đây không có upper bound → count bị lệch nếu server UTC khác timezone local
    final endOfDay   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();

    final count = await _sb
        .from('orders')
        .select('id')
        .eq('store_id', storeId)
        .gte('created_at', startOfDay)
        .lt('created_at', endOfDay) // exclusive upper — tránh đếm nhầm ngày
        .count(CountOption.exact);

    return '$prefix-${((count.count) + 1).toString().padLeft(3, '0')}';
  }

  // ── Coupons (Vouchers & Giảm giá) ──────────────────────────────────────────
  Future<List<CouponModel>> getCoupons() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    try {
      final rows = await _sb
          .from('coupons')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      return rows.map((r) => CouponModel.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[PosRepository] getCoupons error: $e');
      return [];
    }
  }

  Future<void> upsertCoupon(CouponModel coupon) async {
    try {
      await _sb.from('coupons').upsert(coupon.toMap());
    } catch (e) {
      debugPrint('[PosRepository] upsertCoupon error: $e');
      rethrow;
    }
  }

  Future<void> deleteCoupon(String couponId) async {
    try {
      await _sb.from('coupons').delete().eq('id', couponId);
    } catch (e) {
      debugPrint('[PosRepository] deleteCoupon error: $e');
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class CartLine {
  final String lineId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final String? note;
  final String stationCode;

  CartLine({
    String? lineId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    this.note,
    this.stationCode = 'bep_nong',
  }) : lineId = lineId ?? const Uuid().v4();

  double get subtotal => quantity * unitPrice;

  CartLine copyWith({double? quantity, String? Function()? note}) => CartLine(
        lineId:      lineId,
        productId:   productId,
        productName: productName,
        quantity:    quantity ?? this.quantity,
        unitPrice:   unitPrice,
        costPrice:   costPrice,
        note:        note != null ? note() : this.note,
        stationCode: stationCode,
      );
}

class OrderModel {
  final String id;
  final String storeId;
  final String orderNumber;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double discount;
  final double totalAmount;
  final String paymentMethod;
  final double loyaltyPtsEarned;
  final double loyaltyPtsUsed;
  final String status;
  final String? note;
  final String createdAt;

  const OrderModel({
    required this.id,
    required this.storeId,
    required this.orderNumber,
    this.customerId,
    this.customerName,
    required this.subtotal,
    required this.discount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.loyaltyPtsEarned,
    required this.loyaltyPtsUsed,
    required this.status,
    this.note,
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> m) => OrderModel(
        id:                m['id'] as String,
        storeId:           m['store_id'] as String? ?? '',
        orderNumber:       m['order_number'] as String? ?? '',
        customerId:        m['customer_id'] as String?,
        customerName:      m['customer_name'] as String?,
        subtotal:          (m['subtotal'] as num?)?.toDouble() ?? 0,
        discount:          (m['discount'] as num?)?.toDouble() ?? 0,
        totalAmount:       (m['total_amount'] as num?)?.toDouble() ?? 0,
        paymentMethod:     m['payment_method'] as String? ?? 'cash',
        loyaltyPtsEarned:  (m['loyalty_pts_earned'] as num?)?.toDouble() ?? 0,
        loyaltyPtsUsed:    (m['loyalty_pts_used'] as num?)?.toDouble() ?? 0,
        status:            m['status'] as String? ?? 'completed',
        note:              m['note'] as String?,
        createdAt:         m['created_at'] as String? ?? '',
      );
}

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double subtotal;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.subtotal,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> m) => OrderItemModel(
        id:          m['id'] as String,
        orderId:     m['order_id'] as String,
        productId:   m['product_id'] as String? ?? '',
        // Fallback: product_name (extended col) → name (legacy NOT NULL col)
        productName: m['product_name'] as String? ?? m['name'] as String? ?? '',
        // Fallback: quantity (extended col) → qty (legacy col) — tránh cancelOrder hoàn kho 0
        quantity:    (m['quantity'] as num?)?.toDouble()
                  ?? (m['qty'] as num?)?.toDouble()
                  ?? 0,
        unitPrice:   (m['unit_price'] as num?)?.toDouble() ?? 0,
        costPrice:   (m['cost_price'] as num?)?.toDouble() ?? 0,
        subtotal:    (m['subtotal'] as num?)?.toDouble() ?? 0,
      );

}

class PosStats {
  final int orderCount;
  final double revenue;
  final double profit;
  final double avgOrderValue;
  final int customerCount;

  const PosStats({
    required this.orderCount,
    required this.revenue,
    required this.profit,
    required this.avgOrderValue,
    required this.customerCount,
  });

  static const empty = PosStats(
    orderCount: 0, revenue: 0, profit: 0, avgOrderValue: 0, customerCount: 0,
  );
}
