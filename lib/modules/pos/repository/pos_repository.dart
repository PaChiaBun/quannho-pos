import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/event_bus/app_event_bus.dart';
import '../../../core/event_bus/app_events.dart';
import '../../../core/repositories/core_product_repository.dart';
import '../../../core/repositories/core_customer_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// POS REPOSITORY
// Module POS ONLY reads/writes bảng pos_* và emit events
// ─────────────────────────────────────────────────────────────────────────────
class PosRepository {
  final AppDatabase _db;
  final AppEventBus _eventBus;
  final CoreProductRepository _productRepo;
  final CoreCustomerRepository _customerRepo;
  final _uuid = const Uuid();

  PosRepository(
      this._db, this._eventBus, this._productRepo, this._customerRepo);

  // ── Orders ────────────────────────────────────────────────────────────────

  /// Lấy danh sách đơn hàng hôm nay
  Stream<List<PosOrder>> watchTodayOrders() {
    final startOfDay = DateTime.now().copyWith(
      hour: 0, minute: 0, second: 0, millisecond: 0,
    ).millisecondsSinceEpoch;

    return (_db.select(_db.posOrders)
          ..where((o) =>
              o.createdAt.isBiggerOrEqualValue(startOfDay) &
              o.status.equals('completed'))
          ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]))
        .watch();
  }

  Future<PosOrder?> getOrderById(String id) {
    return (_db.select(_db.posOrders)
          ..where((o) => o.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<PosOrderItem>> getOrderItems(String orderId) {
    return (_db.select(_db.posOrderItems)
          ..where((i) => i.orderId.equals(orderId)))
        .get();
  }

  // ── Complete sale ─────────────────────────────────────────────────────────

  /// Hoàn tất giao dịch — ghi DB + emit SaleCompletedEvent
  Future<String> completeSale({
    required List<CartLine> lines,
    required String paymentMethod,
    String? customerId,
    String? customerName,
    double discount = 0,
    double loyaltyPtsUsed = 0,
    double loyaltyRate = 10000, // 10k = 1 điểm
  }) async {
    assert(lines.isNotEmpty, 'Cart must not be empty');

    final orderId = _uuid.v4();
    final eventId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Tính tiền
    final subtotal = lines.fold<double>(0, (s, l) => s + l.subtotal);
    final totalAmount =
        (subtotal - discount - loyaltyPtsUsed).clamp(0.0, double.infinity);
    final loyaltyPtsEarned = (totalAmount / loyaltyRate).floorToDouble();

    // Tạo order number: QN-YYYYMMDD-XXX
    final orderNumber = await _generateOrderNumber();

    await _db.transaction(() async {
      // 1. Ghi pos_orders
      await _db.into(_db.posOrders).insert(PosOrdersCompanion(
            id: Value(orderId),
            orderNumber: Value(orderNumber),
            customerId: Value(customerId),
            customerName: Value(customerName),
            subtotal: Value(subtotal),
            discount: Value(discount),
            tax: const Value(0),
            totalAmount: Value(totalAmount.toDouble()),
            paymentMethod: Value(paymentMethod),
            loyaltyPtsEarned: Value(loyaltyPtsEarned),
            loyaltyPtsUsed: Value(loyaltyPtsUsed),
            status: const Value('completed'),
            receiptPrinted: const Value(false),
            createdAt: Value(now),
          ));

      // 2. Ghi pos_order_items
      for (final line in lines) {
        await _db.into(_db.posOrderItems).insert(PosOrderItemsCompanion(
              id: Value(_uuid.v4()),
              orderId: Value(orderId),
              productId: Value(line.productId),
              productName: Value(line.productName),
              quantity: Value(line.quantity),
              unitPrice: Value(line.unitPrice),
              costPrice: Value(line.costPrice),
              subtotal: Value(line.subtotal),
            ));
      }

      // 3. Ghi event_log + emit
      final saleItems = lines
          .map((l) => SaleItem(
                productId: l.productId,
                productName: l.productName,
                quantity: l.quantity,
                unitPrice: l.unitPrice,
                costPrice: l.costPrice,
                subtotal: l.subtotal,
              ))
          .toList();

      await _eventBus.emit(
        SaleCompletedEvent(
          id: eventId,
          createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          orderId: orderId,
          orderNumber: orderNumber,
          items: saleItems,
          total: totalAmount.toDouble(),
          subtotal: subtotal,
          customerId: customerId,
          paymentMethod: paymentMethod,
          loyaltyPtsEarned: loyaltyPtsEarned,
          loyaltyPtsUsed: loyaltyPtsUsed,
        ),
        targetModules: const ['kho', 'finance', 'loyalty'],
      );
    });

    // 4. Cập nhật stock (cached value trong core_products)
    for (final line in lines) {
      await _productRepo.updateStockQty(line.productId, -line.quantity);
    }

    // 5. Cập nhật loyalty points + total spent của khách
    if (customerId != null) {
      await _customerRepo.recordPurchase(
        customerId,
        amount: totalAmount.toDouble(),
        ptsEarned: loyaltyPtsEarned,
        ptsUsed: loyaltyPtsUsed,
      );
    }

    return orderId;
  }

  /// Hủy đơn hàng
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.transaction(() async {
      // Cập nhật status
      await (_db.update(_db.posOrders)
            ..where((o) => o.id.equals(orderId)))
          .write(const PosOrdersCompanion(status: Value('cancelled')));

      // Phát event
      await _eventBus.emit(
        SaleCancelledEvent(
          id: _uuid.v4(),
          createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          orderId: orderId,
          reason: reason,
        ),
        targetModules: const ['kho', 'finance'],
      );
    });

    // Hoàn lại stock
    final items = await getOrderItems(orderId);
    for (final item in items) {
      await _productRepo.updateStockQty(item.productId, item.quantity);
    }
  }

  // ── Today stats ───────────────────────────────────────────────────────────

  Future<PosStats> getTodayStats() async {
    final startOfDay = DateTime.now()
        .copyWith(hour: 0, minute: 0, second: 0, millisecond: 0)
        .millisecondsSinceEpoch;

    final orders = await (_db.select(_db.posOrders)
          ..where((o) =>
              o.createdAt.isBiggerOrEqualValue(startOfDay) &
              o.status.equals('completed')))
        .get();

    final revenue = orders.fold<double>(0, (s, o) => s + o.totalAmount);
    final costTotal = await _calcCostTotal(startOfDay);

    return PosStats(
      orderCount: orders.length,
      revenue: revenue,
      profit: revenue - costTotal,
      avgOrderValue:
          orders.isEmpty ? 0 : revenue / orders.length,
      customerCount: orders
          .where((o) => o.customerId != null)
          .map((o) => o.customerId!)
          .toSet()
          .length,
    );
  }

  Future<double> _calcCostTotal(int sinceTimestamp) async {
    final orderIds = await (_db.select(_db.posOrders)
          ..where((o) =>
              o.createdAt.isBiggerOrEqualValue(sinceTimestamp) &
              o.status.equals('completed')))
        .map((o) => o.id)
        .get();

    if (orderIds.isEmpty) return 0;

    final items = await (_db.select(_db.posOrderItems)
          ..where((i) => i.orderId.isIn(orderIds)))
        .get();

    return items.fold<double>(
        0, (s, i) => s + (i.costPrice * i.quantity));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _generateOrderNumber() async {
    final now = DateTime.now();
    final prefix =
        'QN-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

    final todayStart = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;

    final count = await (_db.select(_db.posOrders)
          ..where((o) => o.createdAt.isBiggerOrEqualValue(todayStart)))
        .get()
        .then((list) => list.length);

    return '$prefix-${(count + 1).toString().padLeft(3, '0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

/// 1 dòng trong giỏ hàng
class CartLine {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;

  const CartLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
  });

  double get subtotal => quantity * unitPrice;

  CartLine copyWith({double? quantity}) => CartLine(
        productId: productId,
        productName: productName,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice,
        costPrice: costPrice,
      );
}

/// Thống kê POS trong ngày
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
    orderCount: 0,
    revenue: 0,
    profit: 0,
    avgOrderValue: 0,
    customerCount: 0,
  );
}
