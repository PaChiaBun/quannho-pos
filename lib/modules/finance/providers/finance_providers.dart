import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../repository/finance_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY PROVIDER — dùng từ app_providers.dart
// ─────────────────────────────────────────────────────────────────────────────
// financeRepositoryProvider đã khai báo trong app_providers.dart — re-export
export '../../../core/providers/app_providers.dart' show financeRepositoryProvider;

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
// SELECTED FUND STATE — Chọn Quỹ xem báo cáo ('cash' hoặc 'bank')
// ─────────────────────────────────────────────────────────────────────────────
class FundNotifier extends Notifier<String> {
  @override
  String build() => 'all'; // mặc định là xem tất cả

  void setAll()  => state = 'all';
  void setCash() => state = 'cash';
  void setBank() => state = 'bank';
  void setFund(String val) => state = val;
}

final selectedFundProvider = NotifierProvider<FundNotifier, String>(
  FundNotifier.new,
);

// ─────────────────────────────────────────────────────────────────────────────
// RECORDS PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Tất cả records trong kỳ đang chọn (reactive khi period thay đổi và fund thay đổi)
final financeRecordsProvider =
    StreamProvider<List<FinanceRecordModel>>((ref) {
  final range = ref.watch(periodProvider);
  final fund  = ref.watch(selectedFundProvider);
  return ref.watch(financeRepositoryProvider).watchRecords(
    from: range.from,
    to:   range.to,
    fundType: fund == 'all' ? null : fund,
  );
});

/// Finance stats của kỳ đang chọn
final financeStatsProvider = FutureProvider<FinanceStats>((ref) async {
  final range = ref.watch(periodProvider);
  final fund  = ref.watch(selectedFundProvider);
  ref.watch(financeRecordsProvider); // depend để auto-refresh
  return ref.read(financeRepositoryProvider).getStats(range, fundType: fund == 'all' ? null : fund);
});

/// Finance stats luôn là hôm nay — dùng cho header
final todayFinanceStatsProvider = FutureProvider<FinanceStats>((ref) async {
  final fund  = ref.watch(selectedFundProvider);
  ref.watch(financeRecordsProvider);
  return ref.read(financeRepositoryProvider).getStats(DateRange.today(), fundType: fund == 'all' ? null : fund);
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
    Provider<AsyncValue<List<FinanceRecordModel>>>((ref) {
  final filter  = ref.watch(financeFilterProvider);
  final records = ref.watch(financeRecordsProvider);
  return records.whenData((list) => filter == null
      ? list
      : list.where((r) => r.type == filter).toList());
});
