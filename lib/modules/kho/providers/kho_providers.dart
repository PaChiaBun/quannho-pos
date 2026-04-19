import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/database/app_database.dart';
import '../repository/kho_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KHO REPOSITORY PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final khoRepositoryProvider = Provider<KhoRepository>((ref) {
  return KhoRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appEventBusProvider),
  );
});

// ─────────────────────────────────────────────────────────────────────────────
// STREAM PROVIDERS — Reactive data
// ─────────────────────────────────────────────────────────────────────────────

/// Tất cả hàng tồn kho
final allStockProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchAllStock();
});

/// Sắp hết hàng
final lowStockKhoProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchLowStock();
});

/// Hết hàng
final outOfStockProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchOutOfStock();
});

/// Lịch sử biến động gần đây
final recentMovementsProvider =
    StreamProvider<List<KhoStockMovement>>((ref) {
  return ref.watch(khoRepositoryProvider).watchRecentMovements();
});

/// Lịch sử của 1 sản phẩm cụ thể
final productMovementsProvider =
    StreamProvider.family<List<KhoStockMovement>, String>((ref, productId) {
  return ref.watch(khoRepositoryProvider).watchMovements(productId);
});

/// Suppliers list
final suppliersProvider = StreamProvider<List<KhoSupplier>>((ref) {
  return ref.watch(khoRepositoryProvider).watchSuppliers();
});

/// Kho stats — invalidate khi stock thay đổi
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
        query: query ?? this.query,
        category: category != null ? category() : this.category,
        statusFilter:
            statusFilter != null ? statusFilter() : this.statusFilter,
      );

  List<StockItem> apply(List<StockItem> items) {
    return items.where((item) {
      final matchQ = query.isEmpty ||
          item.name.toLowerCase().contains(query.toLowerCase()) ||
          (item.sku?.toLowerCase().contains(query.toLowerCase()) ?? false);
      final matchCat =
          category == null || (item.category ?? '') == category;
      final matchStatus =
          statusFilter == null || item.status == statusFilter;
      return matchQ && matchCat && matchStatus;
    }).toList();
  }
}

class StockFilterNotifier extends Notifier<StockFilterState> {
  @override
  StockFilterState build() => const StockFilterState();

  void setQuery(String q) => state = state.copyWith(query: q);
  void setCategory(String? c) =>
      state = state.copyWith(category: () => c);
  void setStatus(StockStatus? s) =>
      state = state.copyWith(statusFilter: () => s);
  void clear() => state = const StockFilterState();
}

final stockFilterProvider =
    NotifierProvider<StockFilterNotifier, StockFilterState>(
  StockFilterNotifier.new,
);

/// Filtered stock list
final filteredStockProvider = Provider<AsyncValue<List<StockItem>>>((ref) {
  final filter = ref.watch(stockFilterProvider);
  final allAsync = ref.watch(allStockProvider);
  return allAsync.whenData((items) => filter.apply(items));
});
