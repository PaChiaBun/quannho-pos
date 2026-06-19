import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
<<<<<<< HEAD
import '../repository/kho_repository.dart';

// khoRepositoryProvider đã khai báo trong app_providers.dart
export '../../../core/providers/app_providers.dart' show khoRepositoryProvider;
=======
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
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

// ─────────────────────────────────────────────────────────────────────────────
// STREAM PROVIDERS — Reactive data
// ─────────────────────────────────────────────────────────────────────────────

<<<<<<< HEAD
=======
/// Tất cả hàng tồn kho
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
final allStockProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchAllStock();
});

<<<<<<< HEAD
=======
/// Sắp hết hàng
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
final lowStockKhoProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchLowStock();
});

<<<<<<< HEAD
=======
/// Hết hàng
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
final outOfStockProvider = StreamProvider<List<StockItem>>((ref) {
  return ref.watch(khoRepositoryProvider).watchOutOfStock();
});

<<<<<<< HEAD
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

=======
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
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
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
<<<<<<< HEAD
        query:       query ?? this.query,
        category:    category != null ? category() : this.category,
        statusFilter: statusFilter != null ? statusFilter() : this.statusFilter,
=======
        query: query ?? this.query,
        category: category != null ? category() : this.category,
        statusFilter:
            statusFilter != null ? statusFilter() : this.statusFilter,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
      );

  List<StockItem> apply(List<StockItem> items) {
    return items.where((item) {
      final matchQ = query.isEmpty ||
          item.name.toLowerCase().contains(query.toLowerCase()) ||
          (item.sku?.toLowerCase().contains(query.toLowerCase()) ?? false);
<<<<<<< HEAD
      final matchCat    = category == null || (item.category ?? '') == category;
      final matchStatus = statusFilter == null || item.status == statusFilter;
=======
      final matchCat =
          category == null || (item.category ?? '') == category;
      final matchStatus =
          statusFilter == null || item.status == statusFilter;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
      return matchQ && matchCat && matchStatus;
    }).toList();
  }
}

class StockFilterNotifier extends Notifier<StockFilterState> {
  @override
  StockFilterState build() => const StockFilterState();

<<<<<<< HEAD
  void setQuery(String q)    => state = state.copyWith(query: q);
  void setCategory(String? c) => state = state.copyWith(category: () => c);
  void setStatus(StockStatus? s) => state = state.copyWith(statusFilter: () => s);
=======
  void setQuery(String q) => state = state.copyWith(query: q);
  void setCategory(String? c) =>
      state = state.copyWith(category: () => c);
  void setStatus(StockStatus? s) =>
      state = state.copyWith(statusFilter: () => s);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  void clear() => state = const StockFilterState();
}

final stockFilterProvider =
    NotifierProvider<StockFilterNotifier, StockFilterState>(
  StockFilterNotifier.new,
);

<<<<<<< HEAD
final filteredStockProvider = Provider<AsyncValue<List<StockItem>>>((ref) {
  final filter   = ref.watch(stockFilterProvider);
=======
/// Filtered stock list
final filteredStockProvider = Provider<AsyncValue<List<StockItem>>>((ref) {
  final filter = ref.watch(stockFilterProvider);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  final allAsync = ref.watch(allStockProvider);
  return allAsync.whenData((items) => filter.apply(items));
});
