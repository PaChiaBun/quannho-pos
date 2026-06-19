import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';
<<<<<<< HEAD
import 'session_provider.dart';
=======
import 'app_providers.dart';
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
<<<<<<< HEAD
  return DashboardRepository();
});

/// Stats hôm nay — refresh khi session thay đổi hoặc bị invalidate từ ngoài
final todayStatsProvider = StreamProvider<DashboardStats>((ref) async* {
  ref.watch(sessionProvider); // bắt buộc refresh khi storeId có
  yield await ref.read(dashboardRepositoryProvider).getTodayStats();
=======
  return DashboardRepository(ref.watch(appDatabaseProvider));
});

/// Stats hôm nay — stream realtime
final todayStatsProvider = StreamProvider<DashboardStats>((ref) {
  return ref.watch(dashboardRepositoryProvider).watchTodayStats();
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
});

/// Top sản phẩm hôm nay
final topProductsTodayProvider = FutureProvider<List<TopProduct>>((ref) {
  // Tự refresh khi có đơn mới
  ref.watch(todayStatsProvider);
  return ref.read(dashboardRepositoryProvider).getTopProductsToday();
});

/// Doanh thu 7 ngày gần nhất
final last7DaysRevenueProvider = FutureProvider<List<DailyRevenue>>((ref) {
  ref.watch(todayStatsProvider);
  return ref.read(dashboardRepositoryProvider).getLast7DaysRevenue();
});
<<<<<<< HEAD

/// Thống kê huỷ bàn/huỷ món hôm nay — refresh khi session hoặc todayStats thay đổi
final todayVoidStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  ref.watch(sessionProvider);
  ref.watch(todayStatsProvider); // Tự động làm mới khi stats hôm nay cập nhật
  return ref.read(dashboardRepositoryProvider).getTodayVoidStats();
});

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
