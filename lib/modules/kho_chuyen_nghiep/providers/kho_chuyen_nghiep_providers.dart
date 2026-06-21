import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../repository/kho_chuyen_nghiep_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS — Kho Hàng Chuyên Nghiệp
// Tất cả dùng FutureProvider.autoDispose + ref.invalidate() để đồng bộ
// ─────────────────────────────────────────────────────────────────────────────

final khoProRepositoryProvider = Provider<KhoProRepository>((ref) {
  final productRepo = ref.watch(productRepositoryProvider);
  return KhoProRepository(productRepo);
});

final recipesProvider = FutureProvider.autoDispose<List<RecipeModel>>((ref) {
  return ref.read(khoProRepositoryProvider).fetchRecipes();
});

final productionOrdersProvider =
    FutureProvider.autoDispose<List<ProductionOrderModel>>((ref) {
  return ref.read(khoProRepositoryProvider).fetchProductionOrders();
});

/// Notifier giữ ngày đang chọn trong ProductionOrderScreen
class _ProductionDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DateTime.now();

  void setDate(DateTime date) => state = date;
}

/// Provider ngày — dùng NotifierProvider (Riverpod v3, không có StateProvider)
final productionSelectedDateProvider =
    NotifierProvider<_ProductionDateNotifier, DateTime>(
  _ProductionDateNotifier.new,
);

/// Provider fetch lệnh SX theo ngày đang chọn — KHÔNG autoDispose
/// để giữ state khi user navigate ra ngoài rồi quay lại
final productionOrdersByDateProvider =
    FutureProvider<List<ProductionOrderModel>>((ref) {
  final date = ref.watch(productionSelectedDateProvider);
  return ref.read(khoProRepositoryProvider).fetchProductionOrders(date: date);
});

/// Alias giữ tương thích với các nơi đã dùng todayProductionOrdersProvider
final todayProductionOrdersProvider =
    FutureProvider.autoDispose<List<ProductionOrderModel>>((ref) {
  return ref.read(khoProRepositoryProvider)
      .fetchProductionOrders(date: DateTime.now());
});

/// Map posProductId → sell_price — dùng cho tính margin công thức
final sellPriceMapProvider =
    FutureProvider.autoDispose<Map<String, double>>((ref) async {
  final recipes = await ref.watch(recipesProvider.future);
  final ids = recipes
      .where((r) => r.posProductId?.isNotEmpty == true)
      .map((r) => r.posProductId!)
      .toList();
  return ref.read(khoProRepositoryProvider).fetchSellPriceMap(ids);
});

/// Production logs theo khoảng ngày (family provider)
final productionLogsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, ({DateTime? from, DateTime? to, String? orderId})>(
  (ref, args) {
    return ref.read(khoProRepositoryProvider).fetchProductionLogs(
      orderId: args.orderId,
      from:    args.from,
      to:      args.to,
    );
  },
);

/// Danh sách phiên kiểm kê
final stockCountsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(khoProRepositoryProvider).fetchStockCounts();
});
