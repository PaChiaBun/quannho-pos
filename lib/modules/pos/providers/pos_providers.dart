import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/database/app_database.dart';
import '../repository/pos_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// POS REPOSITORY PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final posRepositoryProvider = Provider<PosRepository>((ref) {
  return PosRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appEventBusProvider),
    ref.watch(productRepositoryProvider),
    ref.watch(customerRepositoryProvider),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// CART STATE — Riverpod Notifier quản lý giỏ hàng
// ─────────────────────────────────────────────────────────────────────────────
class CartState {
  final List<CartLine> lines;
  final String? customerId;
  final String? customerName;
  final double loyaltyPtsAvailable; // điểm khách đang có
  final double loyaltyPtsUsed;      // điểm dùng cho đơn này
  final double discount;
  final String paymentMethod;       // 'cash' | 'transfer' | 'card'
  final bool isProcessing;

  const CartState({
    this.lines = const [],
    this.customerId,
    this.customerName,
    this.loyaltyPtsAvailable = 0,
    this.loyaltyPtsUsed = 0,
    this.discount = 0,
    this.paymentMethod = 'cash',
    this.isProcessing = false,
  });

  // ── Computed properties ───────────────────────────────────────────────────
  double get subtotal => lines.fold(0, (s, l) => s + l.subtotal);
  double get total =>
      (subtotal - discount - loyaltyPtsUsed).clamp(0, double.infinity);
  int get itemCount => lines.fold(0, (s, l) => s + l.quantity.toInt());
  bool get isEmpty => lines.isEmpty;

  CartState copyWith({
    List<CartLine>? lines,
    String? Function()? customerId,
    String? Function()? customerName,
    double? loyaltyPtsAvailable,
    double? loyaltyPtsUsed,
    double? discount,
    String? paymentMethod,
    bool? isProcessing,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        customerId: customerId != null ? customerId() : this.customerId,
        customerName:
            customerName != null ? customerName() : this.customerName,
        loyaltyPtsAvailable:
            loyaltyPtsAvailable ?? this.loyaltyPtsAvailable,
        loyaltyPtsUsed: loyaltyPtsUsed ?? this.loyaltyPtsUsed,
        discount: discount ?? this.discount,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        isProcessing: isProcessing ?? this.isProcessing,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CART NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────
class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  // ── Product actions ───────────────────────────────────────────────────────

  /// Thêm sản phẩm từ DB vào giỏ
  void addProduct(CoreProduct product, {double qty = 1}) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.productId == product.id);

    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + qty);
    } else {
      // Cảnh báo hết hàng nhưng vẫn cho thêm (theo rule)
      lines.add(CartLine(
        productId: product.id,
        productName: product.name,
        quantity: qty,
        unitPrice: product.sellPrice,
        costPrice: product.costPrice,
      ));
    }
    state = state.copyWith(lines: lines);
  }

  void increaseQty(String productId) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.productId == productId);
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity + 1);
      state = state.copyWith(lines: lines);
    }
  }

  void decreaseQty(String productId) {
    final lines = List<CartLine>.from(state.lines);
    final idx = lines.indexWhere((l) => l.productId == productId);
    if (idx < 0) return;

    if (lines[idx].quantity > 1) {
      lines[idx] = lines[idx].copyWith(quantity: lines[idx].quantity - 1);
    } else {
      lines.removeAt(idx);
    }
    state = state.copyWith(lines: lines);
  }

  void removeLine(String productId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.productId != productId).toList(),
    );
  }

  void clearCart() => state = const CartState();

  // ── Customer ──────────────────────────────────────────────────────────────

  void setCustomer(String id, String name, double loyaltyPts) {
    state = state.copyWith(
      customerId: () => id,
      customerName: () => name,
      loyaltyPtsAvailable: loyaltyPts,
      loyaltyPtsUsed: 0,
    );
  }

  void clearCustomer() {
    state = state.copyWith(
      customerId: () => null,
      customerName: () => null,
      loyaltyPtsAvailable: 0,
      loyaltyPtsUsed: 0,
    );
  }

  void setLoyaltyPtsUsed(double pts) {
    final capped = pts.clamp(0.0, state.loyaltyPtsAvailable);
    state = state.copyWith(loyaltyPtsUsed: capped);
  }

  // ── Payment ───────────────────────────────────────────────────────────────

  void setPaymentMethod(String method) =>
      state = state.copyWith(paymentMethod: method);

  void setDiscount(double amount) =>
      state = state.copyWith(discount: amount.clamp(0, state.subtotal));

  // ── Checkout ──────────────────────────────────────────────────────────────

  /// Trả về orderId nếu thành công, throw nếu lỗi
  Future<String> checkout(PosRepository repo, {double loyaltyRate = 10000}) async {
    if (state.lines.isEmpty) throw Exception('Giỏ hàng trống');

    state = state.copyWith(isProcessing: true);
    try {
      final orderId = await repo.completeSale(
        lines: state.lines,
        paymentMethod: state.paymentMethod,
        customerId: state.customerId,
        customerName: state.customerName,
        discount: state.discount,
        loyaltyPtsUsed: state.loyaltyPtsUsed,
        loyaltyRate: loyaltyRate,
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
final todayOrdersProvider = StreamProvider<List<PosOrder>>((ref) {
  return ref.watch(posRepositoryProvider).watchTodayOrders();
});

/// Stats của ngày hôm nay
final todayStatsProvider = FutureProvider<PosStats>((ref) async {
  // Invalidate mỗi khi có đơn hàng mới
  ref.watch(todayOrdersProvider);
  return ref.read(posRepositoryProvider).getTodayStats();
});
