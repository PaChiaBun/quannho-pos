import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../event_bus/app_events.dart';
import '../../modules/finance/repository/finance_repository.dart';
import '../../modules/loyalty/repository/loyalty_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EVENT BRIDGE — Lắng nghe events từ EventBus, dispatch sang các module
//
// Luồng chính:
//   SaleCompletedEvent
//     → Finance: ghi income record (auto)
//     → Loyalty: cộng điểm cho khách hàng
//
// Bridge được khởi động 1 lần khi app start, tồn tại suốt lifetime app.
// ─────────────────────────────────────────────────────────────────────────────
class EventBridgeService {
  final FinanceRepository _financeRepo;
  final LoyaltyRepository _loyaltyRepo;
  final Ref _ref;

  final List<StreamSubscription> _subs = [];

  EventBridgeService(this._financeRepo, this._loyaltyRepo, this._ref);

  /// Bắt đầu lắng nghe — gọi 1 lần sau khi ProviderScope sẵn sàng
  void start() {
    final bus = _ref.read(appEventBusProvider);

    // ── SaleCompletedEvent ────────────────────────────────────────────────
    _subs.add(bus.on<SaleCompletedEvent>().listen(_onSaleCompleted));

    // (Có thể thêm listener cho StockAdjustedEvent, LowStockAlertEvent...)
  }

  Future<void> _onSaleCompleted(SaleCompletedEvent event) async {
    // 1. Finance: ghi thu nhập tự động
    try {
      await _financeRepo.recordFromSale(
        orderId:    event.orderId,
        amount:     event.total,
        categoryId: 'ban_hang', // category ID seed sẵn
      );
    } catch (e) {
      // Không để lỗi finance ảnh hưởng loyalty
      // ignore: avoid_print
      print('[Bridge] Finance record error: $e');
    }

    // 2. Loyalty: cộng điểm nếu có customerId và có điểm
    if (event.customerId != null && event.loyaltyPtsEarned > 0) {
      try {
        await _loyaltyRepo.earnPoints(
          customerId: event.customerId!,
          pts:        event.loyaltyPtsEarned,
          orderId:    event.orderId,
          note:       'Bán hàng #${event.orderNumber}',
        );
      } catch (e) {
        // ignore: avoid_print
        print('[Bridge] Loyalty earn error: $e');
      }
    }
  }

  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER — Singleton bridge
// ─────────────────────────────────────────────────────────────────────────────
final eventBridgeProvider = Provider<EventBridgeService>((ref) {
  final financeRepo = FinanceRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appEventBusProvider),
  );
  final loyaltyRepo = LoyaltyRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appEventBusProvider),
  );

  final bridge = EventBridgeService(financeRepo, loyaltyRepo, ref);
  bridge.start();
  ref.onDispose(bridge.dispose);
  return bridge;
});
