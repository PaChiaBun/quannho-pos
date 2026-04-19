// ─────────────────────────────────────────────────────────────────────────────
// BASE EVENT — Tất cả events kế thừa class này
// ─────────────────────────────────────────────────────────────────────────────
abstract class AppEvent {
  final String id;
  final DateTime createdAt;

  const AppEvent({required this.id, required this.createdAt});

  String get eventType;
  String get sourceModule;
  Map<String, dynamic> toJson();
}

// ─────────────────────────────────────────────────────────────────────────────
// POS EVENTS — Sự kiện từ module POS
// ─────────────────────────────────────────────────────────────────────────────
class SaleCompletedEvent extends AppEvent {
  final String orderId;
  final String orderNumber;
  final List<SaleItem> items;
  final double total;
  final double subtotal;
  final String? customerId;
  final String paymentMethod;
  final double loyaltyPtsEarned;
  final double loyaltyPtsUsed;

  const SaleCompletedEvent({
    required super.id,
    required super.createdAt,
    required this.orderId,
    required this.orderNumber,
    required this.items,
    required this.total,
    required this.subtotal,
    this.customerId,
    required this.paymentMethod,
    this.loyaltyPtsEarned = 0,
    this.loyaltyPtsUsed = 0,
  });

  @override
  String get eventType => 'sale_completed';

  @override
  String get sourceModule => 'pos';

  @override
  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'orderNumber': orderNumber,
        'items': items.map((e) => e.toJson()).toList(),
        'total': total,
        'subtotal': subtotal,
        'customerId': customerId,
        'paymentMethod': paymentMethod,
        'loyaltyPtsEarned': loyaltyPtsEarned,
        'loyaltyPtsUsed': loyaltyPtsUsed,
      };
}

class SaleCancelledEvent extends AppEvent {
  final String orderId;
  final String? reason;

  const SaleCancelledEvent({
    required super.id,
    required super.createdAt,
    required this.orderId,
    this.reason,
  });

  @override
  String get eventType => 'sale_cancelled';

  @override
  String get sourceModule => 'pos';

  @override
  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'reason': reason,
      };
}

class SaleRefundedEvent extends AppEvent {
  final String orderId;
  final String? reason;

  const SaleRefundedEvent({
    required super.id,
    required super.createdAt,
    required this.orderId,
    this.reason,
  });

  @override
  String get eventType => 'sale_refunded';

  @override
  String get sourceModule => 'pos';

  @override
  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'reason': reason,
      };
}

/// Item trong SaleCompletedEvent
class SaleItem {
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double subtotal;

  const SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.subtotal,
  });

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'costPrice': costPrice,
        'subtotal': subtotal,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// KHO EVENTS — Sự kiện từ module Kho
// ─────────────────────────────────────────────────────────────────────────────
class StockAdjustedEvent extends AppEvent {
  final String productId;
  final double delta;
  final String reason;

  const StockAdjustedEvent({
    required super.id,
    required super.createdAt,
    required this.productId,
    required this.delta,
    required this.reason,
  });

  @override
  String get eventType => 'stock_adjusted';

  @override
  String get sourceModule => 'kho';

  @override
  Map<String, dynamic> toJson() => {
        'productId': productId,
        'delta': delta,
        'reason': reason,
      };
}

class LowStockAlertEvent extends AppEvent {
  final String productId;
  final double currentQty;
  final double minQty;

  const LowStockAlertEvent({
    required super.id,
    required super.createdAt,
    required this.productId,
    required this.currentQty,
    required this.minQty,
  });

  @override
  String get eventType => 'low_stock_alert';

  @override
  String get sourceModule => 'kho';

  @override
  Map<String, dynamic> toJson() => {
        'productId': productId,
        'currentQty': currentQty,
        'minQty': minQty,
      };
}

class PurchaseReceivedEvent extends AppEvent {
  final String purchaseId;
  final List<Map<String, dynamic>> items;

  const PurchaseReceivedEvent({
    required super.id,
    required super.createdAt,
    required this.purchaseId,
    required this.items,
  });

  @override
  String get eventType => 'purchase_received';

  @override
  String get sourceModule => 'kho';

  @override
  Map<String, dynamic> toJson() => {
        'purchaseId': purchaseId,
        'items': items,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE EVENTS — Sự kiện từ module Finance
// ─────────────────────────────────────────────────────────────────────────────
class IncomeRecordedEvent extends AppEvent {
  final String recordId;
  final double amount;
  final String category;

  const IncomeRecordedEvent({
    required super.id,
    required super.createdAt,
    required this.recordId,
    required this.amount,
    required this.category,
  });

  @override
  String get eventType => 'income_recorded';

  @override
  String get sourceModule => 'finance';

  @override
  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'amount': amount,
        'category': category,
      };
}

class ExpenseRecordedEvent extends AppEvent {
  final String recordId;
  final double amount;
  final String category;

  const ExpenseRecordedEvent({
    required super.id,
    required super.createdAt,
    required this.recordId,
    required this.amount,
    required this.category,
  });

  @override
  String get eventType => 'expense_recorded';

  @override
  String get sourceModule => 'finance';

  @override
  Map<String, dynamic> toJson() => {
        'recordId': recordId,
        'amount': amount,
        'category': category,
      };
}

// ─────────────────────────────────────────────────────────────────────────────
// LOYALTY EVENTS — Sự kiện từ module Loyalty
// ─────────────────────────────────────────────────────────────────────────────
class PointsEarnedEvent extends AppEvent {
  final String customerId;
  final double pts;
  final String orderId;

  const PointsEarnedEvent({
    required super.id,
    required super.createdAt,
    required this.customerId,
    required this.pts,
    required this.orderId,
  });

  @override
  String get eventType => 'points_earned';

  @override
  String get sourceModule => 'loyalty';

  @override
  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'pts': pts,
        'orderId': orderId,
      };
}

class PointsRedeemedEvent extends AppEvent {
  final String customerId;
  final double pts;
  final String orderId;

  const PointsRedeemedEvent({
    required super.id,
    required super.createdAt,
    required this.customerId,
    required this.pts,
    required this.orderId,
  });

  @override
  String get eventType => 'points_redeemed';

  @override
  String get sourceModule => 'loyalty';

  @override
  Map<String, dynamic> toJson() => {
        'customerId': customerId,
        'pts': pts,
        'orderId': orderId,
      };
}
