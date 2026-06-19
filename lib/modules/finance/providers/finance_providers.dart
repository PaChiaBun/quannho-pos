import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
<<<<<<< HEAD
import '../repository/finance_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY PROVIDER — dùng từ app_providers.dart
// ─────────────────────────────────────────────────────────────────────────────
// financeRepositoryProvider đã khai báo trong app_providers.dart — re-export
export '../../../core/providers/app_providers.dart' show financeRepositoryProvider;
=======
import '../../../core/database/app_database.dart';
import '../repository/finance_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY PROVIDER
// ─────────────────────────────────────────────────────────────────────────────
final financeRepositoryProvider = Provider<FinanceRepository>((ref) {
  return FinanceRepository(
    ref.watch(appDatabaseProvider),
    ref.watch(appEventBusProvider),
  );
});
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

// ─────────────────────────────────────────────────────────────────────────────
// PERIOD STATE — Chọn kỳ xem báo cáo
// ─────────────────────────────────────────────────────────────────────────────
class PeriodNotifier extends Notifier<DateRange> {
  @override
  DateRange build() => DateRange.today();

  void setToday()     => state = DateRange.today();
  void setThisWeek()  => state = DateRange.thisWeek();
  void setThisMonth() => state = DateRange.thisMonth();
}

final periodProvider = NotifierProvider<PeriodNotifier, DateRange>(
  PeriodNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// RECORDS PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Tất cả records trong kỳ đang chọn (reactive khi period thay đổi)
final financeRecordsProvider =
<<<<<<< HEAD
    StreamProvider<List<FinanceRecordModel>>((ref) {
=======
    StreamProvider<List<FinanceRecord>>((ref) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  final range = ref.watch(periodProvider);
  return ref.watch(financeRepositoryProvider).watchRecords(
    from: range.from,
    to:   range.to,
  );
});

<<<<<<< HEAD
/// Finance stats của kỳ đang chọn
final financeStatsProvider = FutureProvider<FinanceStats>((ref) async {
  final range = ref.watch(periodProvider);
  ref.watch(financeRecordsProvider); // depend để auto-refresh
  return ref.read(financeRepositoryProvider).getStats(range);
});

/// Finance stats luôn là hôm nay — dùng cho header
final todayFinanceStatsProvider = FutureProvider<FinanceStats>((ref) async {
  ref.watch(financeRecordsProvider);
  return ref.read(financeRepositoryProvider).getStats(DateRange.today());
});

/// Danh mục theo loại — Future-based (ít thay đổi)
final incomeCategoriesProvider =
    FutureProvider<List<FinanceCategoryModel>>((ref) {
  return ref.watch(financeRepositoryProvider).getCategories(type: 'income');
});

final expenseCategoriesProvider =
    FutureProvider<List<FinanceCategoryModel>>((ref) {
  return ref.watch(financeRepositoryProvider).getCategories(type: 'expense');
});

// ─────────────────────────────────────────────────────────────────────────────
// TYPE FILTER
=======
/// Records gần đây nhất — 100 records
final recentFinanceRecordsProvider =
    StreamProvider<List<FinanceRecord>>((ref) {
  return ref.watch(financeRepositoryProvider).watchRecentRecords();
});

/// Finance stats của kỳ đang chọn
final financeStatsProvider = FutureProvider<FinanceStats>((ref) async {
  final range = ref.watch(periodProvider);
  // Depend vào records stream để auto-refresh khi có record mới
  ref.watch(financeRecordsProvider);
  return ref.read(financeRepositoryProvider).getStats(range);
});

/// Danh mục thu
final incomeCategoriesProvider =
    StreamProvider<List<FinanceCategory>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCategories(type: 'income');
});

/// Danh mục chi
final expenseCategoriesProvider =
    StreamProvider<List<FinanceCategory>>((ref) {
  return ref.watch(financeRepositoryProvider).watchCategories(type: 'expense');
});

// ─────────────────────────────────────────────────────────────────────────────
// TYPE FILTER — Lọc income/expense/all trong danh sách
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
// ─────────────────────────────────────────────────────────────────────────────
class FinanceFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null; // null = tất cả

  void showAll()     => state = null;
  void showIncome()  => state = 'income';
  void showExpense() => state = 'expense';
}

final financeFilterProvider =
    NotifierProvider<FinanceFilterNotifier, String?>(
  FinanceFilterNotifier.new,
);

/// Filtered records (period + type filter)
final filteredRecordsProvider =
<<<<<<< HEAD
    Provider<AsyncValue<List<FinanceRecordModel>>>((ref) {
=======
    Provider<AsyncValue<List<FinanceRecord>>>((ref) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  final filter  = ref.watch(financeFilterProvider);
  final records = ref.watch(financeRecordsProvider);
  return records.whenData((list) => filter == null
      ? list
      : list.where((r) => r.type == filter).toList());
});
