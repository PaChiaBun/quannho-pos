import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/repositories/module_repository.dart';
import '../../../core/repositories/core_product_repository.dart';
import '../../../core/providers/session_provider.dart';
import '../repository/pos_repository.dart';
import '../models/coupon_model.dart';

// posRepositoryProvider đã khai báo trong app_providers.dart
export '../../../core/providers/app_providers.dart' show posRepositoryProvider;

// ─────────────────────────────────────────────────────────────────────────────
// CART STATE — Riverpod Notifier quản lý giỏ hàng
// ─────────────────────────────────────────────────────────────────────────────
class CartState {
  final List<CartLine> lines;
  final Set<String> sentLineIds; // lineIds đã gửi bếp — ẩn -/+
  final Set<String> kitchenSessionIds; // ban_sessions đã tạo cho đơn POS
  final String? customerId;
  final String? customerName;
  final String? tableId;             // Bàn gán vào đơn
  final String? tableName;
  final String? orderNote;          // Ghi chú cả đơn
  final double loyaltyPtsAvailable; // điểm khách đang có
  final double loyaltyPtsUsed;      // điểm dùng cho đơn này
  final double discount;
  final String paymentMethod;       // 'cash' | 'transfer' | 'card' | 'wallet'
  final bool isProcessing;
  final CouponModel? appliedCoupon;
  final double manualDiscount;

  // ── Wallet fields ─────────────────────────────────────────────────────────
  final double walletRealAvailable;   // ví thật (tiền thật)
  final double walletBonusAvailable;  // ví bonus
  final int    walletBonusCapPct;     // % tối đa dùng bonus/bill
  final DateTime? walletBonusExpiresAt;

  const CartState({
    this.lines = const [],
    this.sentLineIds = const {},
    this.kitchenSessionIds = const {},
    this.customerId,
    this.customerName,
    this.tableId,
    this.tableName,
    this.orderNote,
    this.loyaltyPtsAvailable = 0,
    this.loyaltyPtsUsed = 0,
    this.discount = 0,
    this.paymentMethod = 'cash',
    this.isProcessing = false,
    this.appliedCoupon,
    this.manualDiscount = 0,
    this.walletRealAvailable = 0,
    this.walletBonusAvailable = 0,
    this.walletBonusCapPct = 15,
    this.walletBonusExpiresAt,
  });

  bool get hasWallet => walletRealAvailable > 0 || walletBonusAvailable > 0;
  double get walletTotal => walletRealAvailable + walletBonusAvailable;

  // ── Computed properties ───────────────────────────────────────────────────
  double get subtotal => lines.fold(0, (s, l) => s + l.subtotal);
  double get total =>
      (subtotal - discount - loyaltyPtsUsed).clamp(0, double.infinity);
  int get itemCount => lines.fold(0, (s, l) => s + l.quantity.toInt());
  bool get isEmpty => lines.isEmpty;
  bool isLineSent(String lineId) => sentLineIds.contains(lineId);

  CartState copyWith({
    List<CartLine>? lines,
    Set<String>? sentLineIds,
    Set<String>? kitchenSessionIds,
    String? Function()? customerId,
    String? Function()? customerName,
    String? Function()? tableId,
    String? Function()? tableName,
    String? Function()? orderNote,
    double? loyaltyPtsAvailable,
    double? loyaltyPtsUsed,
    double? discount,
    String? paymentMethod,
    bool? isProcessing,
    CouponModel? Function()? appliedCoupon,
    double? manualDiscount,
    double? walletRealAvailable,
    double? walletBonusAvailable,
    int? walletBonusCapPct,
    DateTime? Function()? walletBonusExpiresAt,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        sentLineIds: sentLineIds ?? this.sentLineIds,
        kitchenSessionIds: kitchenSessionIds ?? this.kitchenSessionIds,
        customerId: customerId != null ? customerId() : this.customerId,
        customerName:
            customerName != null ? customerName() : this.customerName,
        tableId: tableId != null ? tableId() : this.tableId,
        tableName: tableName != null ? tableName() : this.tableName,
        orderNote: orderNote != null ? orderNote() : this.orderNote,
        loyaltyPtsAvailable:
            loyaltyPtsAvailable ?? this.loyaltyPtsAvailable,
        loyaltyPtsUsed: loyaltyPtsUsed ?? this.loyaltyPtsUsed,
        discount: discount ?? this.discount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        isProcessing: isProcessing ?? this.isProcessing,
        appliedCoupon: appliedCoupon != null ? appliedCoupon() : this.appliedCoupon,
        manualDiscount: manualDiscount ?? this.manualDiscount,
        walletRealAvailable: walletRealAvailable ?? this.walletRealAvailable,
        walletBonusAvailable: walletBonusAvailable ?? this.walletBonusAvailable,
        walletBonusCapPct: walletBonusCapPct ?? this.walletBonusCapPct,
        walletBonusExpiresAt: walletBonusExpiresAt != null
            ? walletBonusExpiresAt() : this.walletBonusExpiresAt,
      );
} // end CartState

// ─────────────────────────────────────────────────────────────────────────────
// CART NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  // Helper to recalculate discount and update state
  void _recalculate() {
    double computedDiscount = state.manualDiscount;
    if (state.appliedCoupon != null) {
      final coupon = state.appliedCoupon!;
      if (coupon.discountType == 'percent') {
        double d = (state.subtotal * coupon.value / 100);
        if (coupon.maxDiscountAmount != null) {
          d = d.clamp(0.0, coupon.maxDiscountAmount!);
        }
        computedDiscount = d;
      } else {
        computedDiscount = coupon.value;
      }
    }
    computedDiscount = computedDiscount.clamp(0.0, state.subtotal);

    // Also recalculate loyaltyPtsUsed to make sure it doesn't exceed subtotal - discount
    final maxPts = state.loyaltyPtsAvailable;
    final maxByOrder = (state.subtotal - computedDiscount).clamp(0.0, double.infinity);
    final cappedPts = state.loyaltyPtsUsed.clamp(0.0, maxPts < maxByOrder ? maxPts : maxByOrder);

    state = state.copyWith(
      discount: computedDiscount,
      loyaltyPtsUsed: cappedPts,
    );
  }

  void _updateState(CartState newState) {
    state = newState;
    _recalculate();
  }

  // ── Product actions ─────────────────────────────────────────────────────

  /// Thêm sản phẩm thường — merge cùng productId nếu chưa có ghi chú riêng
  void addProduct(ProductModel product, {double qty = 1}) {
    final lines = List<CartLine>.from(state.lines);
    // Chỉ merge vào dòng không có ghi chú
    final idx = lines.indexWhere(
        (l) => l.productId == product.id && (l.note == null || l.note!.isEmpty));

    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + qty);
    } else {
      lines.add(CartLine(
        productId: product.id,
        productName: product.name,
        quantity: qty,
        unitPrice: product.sellPrice,
        costPrice: product.costPrice,
        stationCode: product.stationCode,
      ));
    }
    _updateState(state.copyWith(lines: lines));
  }

  /// Thêm sản phẩm với ghi chú riêng — luôn tạo CartLine mới
  void addProductWithNote(ProductModel product, {required double qty, String? note}) {
    final lines = List<CartLine>.from(state.lines);
    lines.add(CartLine(
      productId: product.id,
      productName: product.name,
      quantity: qty,
      unitPrice: product.sellPrice,
      costPrice: product.costPrice,
      note: note?.isEmpty == true ? null : note,
      stationCode: product.stationCode,
    ));
    _updateState(state.copyWith(lines: lines));
  }

  void increaseQty(String lineId) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.lineId == lineId);
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + 1);
      _updateState(state.copyWith(lines: lines));
    }
  }

  void decreaseQty(String lineId) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.lineId == lineId);
    if (idx < 0) return;

    if (lines[idx].quantity > 1) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity - 1);
    } else {
      lines.removeAt(idx);
    }
    _updateState(state.copyWith(lines: lines));
  }

  /// Giảm qty theo productId (dùng cho product card trong grid)
  void decreaseQtyByProductId(String productId) {
    final idx = state.lines.indexWhere((l) => l.productId == productId);
    if (idx >= 0) decreaseQty(state.lines[idx].lineId);
  }

  void removeLine(String lineId) {
    _updateState(state.copyWith(
      lines: state.lines.where((l) => l.lineId != lineId).toList(),
    ));
  }

  /// Đánh dấu các line đã gửi bếp — Ẩn nút -/+ cho các line này
  void markLinesSent(List<String> lineIds) {
    _updateState(state.copyWith(
      sentLineIds: {...state.sentLineIds, ...lineIds},
    ));
  }

  /// Giữ phiên bếp cùng với giỏ hàng để không mất khi đổi module.
  void addKitchenSession(String sessionId) {
    _updateState(state.copyWith(
      kitchenSessionIds: {...state.kitchenSessionIds, sessionId},
    ));
  }

  void setItemNote(String lineId, String? note) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.lineId == lineId);
    if (idx < 0) return;
    lines[idx] = lines[idx].copyWith(note: () => note?.isEmpty == true ? null : note);
    _updateState(state.copyWith(lines: lines));
  }

  void setOrderNote(String? note) {
    _updateState(state.copyWith(orderNote: () => note?.isEmpty == true ? null : note));
  }

  void clearCart() => state = const CartState();

  // ── Customer ──────────────────────────────────────────────────────────────

  void setCustomer(String id, String name, double loyaltyPts, {
    double walletReal = 0,
    double walletBonus = 0,
    int bonusCapPct = 15,
    DateTime? bonusExpiresAt,
  }) {
    _updateState(state.copyWith(
      customerId: () => id,
      customerName: () => name,
      loyaltyPtsAvailable: loyaltyPts,
      loyaltyPtsUsed: 0,
      walletRealAvailable: walletReal,
      walletBonusAvailable: walletBonus,
      walletBonusCapPct: bonusCapPct,
      walletBonusExpiresAt: () => bonusExpiresAt,
    ));
  }

  void clearCustomer() {
    _updateState(state.copyWith(
      customerId: () => null,
      customerName: () => null,
      loyaltyPtsAvailable: 0,
      loyaltyPtsUsed: 0,
      walletRealAvailable: 0,
      walletBonusAvailable: 0,
      walletBonusCapPct: 15,
      walletBonusExpiresAt: () => null,
    ));
  }

  void setTable(String id, String name) {
    _updateState(state.copyWith(
      tableId: () => id,
      tableName: () => name,
    ));
  }

  void clearTable() {
    _updateState(state.copyWith(
      tableId: () => null,
      tableName: () => null,
    ));
  }

  void setLoyaltyPtsUsed(double pts) {
    // ‼️ FIX: cap = min(available, subtotal-discount) — tránh dùng pts > giá trị đơn
    final maxByBalance = state.loyaltyPtsAvailable;
    final maxByOrder   = (state.subtotal - state.discount).clamp(0.0, double.infinity);
    final capped = pts.clamp(0.0, maxByBalance < maxByOrder ? maxByBalance : maxByOrder);
    _updateState(state.copyWith(loyaltyPtsUsed: capped));
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  void setPaymentMethod(String method) =>
      _updateState(state.copyWith(paymentMethod: method));

  void setDiscount(double amount) {
    _updateState(state.copyWith(
      manualDiscount: amount.clamp(0, state.subtotal),
      appliedCoupon: () => null, // clear coupon when manually setting discount
    ));
  }

  void applyCoupon(CouponModel? coupon) {
    if (coupon == null) {
      removeCoupon();
      return;
    }
    _updateState(state.copyWith(
      appliedCoupon: () => coupon,
      manualDiscount: 0, // override manual discount when coupon is applied
    ));
  }

  void removeCoupon() {
    _updateState(state.copyWith(
      appliedCoupon: () => null,
    ));
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  /// Trả về orderId nếu thành công, throw nếu lỗi
  Future<String> checkout(
    PosRepository repo, {
    double loyaltyRate = 10000,
    ModuleRepository? moduleRepo,
  }) async {
    if (state.lines.isEmpty) throw Exception('Giỏ hàng trống');

    state = state.copyWith(isProcessing: true);
    final lines = List<CartLine>.from(state.lines); // snapshot trước khi clear
    try {
      final session = ref.read(sessionProvider);
      final orderId = await repo.completeSale(
        lines: lines,
        paymentMethod: state.paymentMethod,
        customerId: state.customerId,
        customerName: state.customerName,
        discount: state.discount,
        loyaltyPtsUsed: state.loyaltyPtsUsed,
        loyaltyRate: loyaltyRate,
        note: state.appliedCoupon != null
            ? ((state.orderNote ?? '').isEmpty
                ? '[Voucher: ${state.appliedCoupon!.code}]'
                : '${state.orderNote} | [Voucher: ${state.appliedCoupon!.code}]')
            : state.orderNote,
        sourceType: state.tableId != null ? 'ban' : 'pos',
        sourceId: state.tableId,
        staffId: session?.userId,
      );
      state = const CartState(); // clear sau khi thành công
      return orderId;
    } catch (e) {
      state = state.copyWith(isProcessing: false);
      rethrow;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final cartProvider = NotifierProvider<CartNotifier, CartState>(
  CartNotifier.new,
);

/// Số lượng item trong giỏ — dùng cho badge
final cartItemCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).itemCount;
});

/// Đơn hàng hôm nay (reactive)
final todayOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  return ref.watch(posRepositoryProvider).watchTodayOrders();
});

/// Stats POS của ngày hôm nay — KHÔNG dùng tên todayStatsProvider để tránh
/// xung đột với dashboard_providers.dart (DashboardStats khác PosStats)
final posTodayStatsProvider = FutureProvider.autoDispose<PosStats>((ref) async {
  // Invalidate mỗi khi có đơn hàng mới
  ref.watch(todayOrdersProvider);
  return ref.read(posRepositoryProvider).getTodayStats();
});
