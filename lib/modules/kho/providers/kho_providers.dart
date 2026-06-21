import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../repository/kho_repository.dart';

// khoRepositoryProvider đã khai báo trong app_providers.dart
export '../../../core/providers/app_providers.dart' show khoRepositoryProvider;

// ─────────────────────────────────────────────────────────────────────────────
// STREAM PROVIDERS — Reactive data
// ─────────────────────────────────────────────────────────────────────────────

final allStockProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchAllStock();
});

final lowStockKhoProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchLowStock();
});

final outOfStockProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchOutOfStock();
});

final recentMovementsProvider =
    StreamProvider<List<StockMovementModel>>((ref) {
  return ref.watch(khoRepositoryProvider).watchRecentMovements();
});

final productMovementsProvider =
    StreamProvider.family<List<StockMovementModel>, String>((ref, productId) {
  return ref.watch(khoRepositoryProvider).watchMovements(productId);
});

final suppliersProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) {
  return ref.read(khoRepositoryProvider).fetchSuppliers();
});

final purchaseOrdersProvider = StreamProvider<List<PurchaseOrderModel>>((ref) {
  return ref.watch(khoRepositoryProvider).watchPurchaseOrders();
});

final khoStatsProvider = FutureProvider<KhoStats>((ref) async {
  ref.watch(allStockProvider); // depend để auto-refresh
  return ref.read(khoRepositoryProvider).getStats();
});

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH FILTER STATE
// ─────────────────────────────────────────────────────────────────────────────
class StockFilterState {
  final String query;
  final String? category;
  final StockStatus? statusFilter;

  const StockFilterState({
    this.query = '',
    this.category,
    this.statusFilter,
  });

  StockFilterState copyWith({
    String? query,
    String? Function()? category,
    StockStatus? Function()? statusFilter,
  }) =>
      StockFilterState(
        query:       query ?? this.query,
        category:    category != null ? category() : this.category,
        statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
      );

  List<StockItem> apply(List<StockItem> items) {
    return items.where((item) {
      final matchQ = query.isEmpty ||
          item.name.toLowerCase().contains(query.toLowerCase()) ||
          (item.sku?.toLowerCase().contains(query.toLowerCase()) ?? false);
      final matchCat    = category == null || (item.category ?? '') == category;
      final matchStatus = statusFilter == null || item.status == statusFilter;
      return matchQ && matchCat && matchStatus;
    }).toList();
  }
}

class StockFilterNotifier extends Notifier<StockFilterState> {
  @override
  StockFilterState build() => const StockFilterState();

  void setQuery(String q)    => state = state.copyWith(query: q);
  void setCategory(String? c) => state = state.copyWith(category: () => c);
  void setStatus(StockStatus? s) => state = state.copyWith(statusFilter: () => s);
  void clear() => state = const StockFilterState();
}

final stockFilterProvider =
    NotifierProvider<StockFilterNotifier, StockFilterState>(
  StockFilterNotifier.new,
);

final filteredStockProvider = Provider<AsyncValue<List<StockItem>>>((ref) {
  final filter   = ref.watch(stockFilterProvider);
  final allAsync = ref.watch(allStockProvider);
  return allAsync.whenData((items) => filter.apply(items));
});
