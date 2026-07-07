import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/repositories/module_repository.dart';
import '../../../core/repositories/core_product_repository.dart';
import '../../../core/providers/session_provider.dart';
import '../repository/pos_repository.dart';

// posRepositoryProvider đã khai báo trong app_providers.dart
export '../../../core/providers/app_providers.dart' show posRepositoryProvider;

// ─────────────────────────────────────────────────────────────────────────────
// CART STATE — Riverpod Notifier quản lý giỏ hàng
// ─────────────────────────────────────────────────────────────────────────────
class CartState {
  final List<CartLine> lines;
  final Set<String> sentLineIds; // lineIds đã gửi bếp — ẩn -/+
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

  // ── Wallet fields ─────────────────────────────────────────────────────────
  final double walletRealAvailable;   // ví thật (tiền thật)
  final double walletBonusAvailable;  // ví bonus
  final int    walletBonusCapPct;     // % tối đa dùng bonus/bill
  final DateTime? walletBonusExpiresAt;

  const CartState({
    this.lines = const [],
    this.sentLineIds = const {},
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
    double? walletRealAvailable,
    double? walletBonusAvailable,
    int? walletBonusCapPct,
    DateTime? Function()? walletBonusExpiresAt,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        sentLineIds: sentLineIds ?? this.sentLineIds,
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
    state = state.copyWith(lines: lines);
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
    state = state.copyWith(lines: lines);
  }

  void increaseQty(String lineId) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.lineId == lineId);
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + 1);
      state = state.copyWith(lines: lines);
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
    state = state.copyWith(lines: lines);
  }

  /// Giảm qty theo productId (dùng cho product card trong grid)
  void decreaseQtyByProductId(String productId) {
    final idx = state.lines.indexWhere((l) => l.productId == productId);
    if (idx >= 0) decreaseQty(state.lines[idx].lineId);
  }

  void removeLine(String lineId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.lineId != lineId).toList(),
    );
  }

  /// Đánh dấu các line đã gửi bếp — Ẩn nút -/+ cho các line này
  void markLinesSent(List<String> lineIds) {
    state = state.copyWith(
      sentLineIds: {...state.sentLineIds, ...lineIds},
    );
  }

  void setItemNote(String lineId, String? note) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.lineId == lineId);
    if (idx < 0) return;
    lines[idx] = lines[idx].copyWith(note: () => note?.isEmpty == true ? null : note);
    state = state.copyWith(lines: lines);
  }

  void setOrderNote(String? note) {
    state = state.copyWith(orderNote: () => note?.isEmpty == true ? null : note);
  }

  void clearCart() => state = const CartState();

  // ── Customer ──────────────────────────────────────────────────────────────

  void setCustomer(String id, String name, double loyaltyPts, {
    double walletReal = 0,
    double walletBonus = 0,
    int bonusCapPct = 15,
    DateTime? bonusExpiresAt,
  }) {
    state = state.copyWith(
      customerId: () => id,
      customerName: () => name,
      loyaltyPtsAvailable: loyaltyPts,
      loyaltyPtsUsed: 0,
      walletRealAvailable: walletReal,
      walletBonusAvailable: walletBonus,
      walletBonusCapPct: bonusCapPct,
      walletBonusExpiresAt: () => bonusExpiresAt,
    );
  }

  void clearCustomer() {
    state = state.copyWith(
      customerId: () => null,
      customerName: () => null,
      loyaltyPtsAvailable: 0,
      loyaltyPtsUsed: 0,
      walletRealAvailable: 0,
      walletBonusAvailable: 0,
      walletBonusCapPct: 15,
      walletBonusExpiresAt: () => null,
    );
  }

  void setTable(String id, String name) {
    state = state.copyWith(
      tableId: () => id,
      tableName: () => name,
    );
  }

  void clearTable() {
    state = state.copyWith(
      tableId: () => null,
      tableName: () => null,
    );
  }

  void setLoyaltyPtsUsed(double pts) {
    // ‼️ FIX: cap = min(available, subtotal-discount) — tránh dùng pts > giá trị đơn
    final maxByBalance = state.loyaltyPtsAvailable;
    final maxByOrder   = (state.subtotal - state.discount).clamp(0.0, double.infinity);
    final capped = pts.clamp(0.0, maxByBalance < maxByOrder ? maxByBalance : maxByOrder);
    state = state.copyWith(loyaltyPtsUsed: capped);
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);

  void setDiscount(double amount) =>
      state = state.copyWith(discount: amount.clamp(0, state.subtotal));

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
        note: state.orderNote,
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
final todayOrdersProvider = StreamProvider<List<OrderModel>>((ref) {
  return ref.watch(posRepositoryProvider).watchTodayOrders();
});

/// Stats POS của ngày hôm nay — KHÔNG dùng tên todayStatsProvider để tránh
/// xung đột với dashboard_providers.dart (DashboardStats khác PosStats)
final posTodayStatsProvider = FutureProvider<PosStats>((ref) async {
  // Invalidate mỗi khi có đơn hàng mới
  ref.watch(todayOrdersProvider);
  return ref.read(posRepositoryProvider).getTodayStats();
});
