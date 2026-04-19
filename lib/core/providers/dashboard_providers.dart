import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';
import 'app_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(appDatabaseProvider));
});

/// Stats hôm nay — stream realtime
final todayStatsProvider = StreamProvider<DashboardStats>((ref) {
  return ref.watch(dashboardRepositoryProvider).watchTodayStats();
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
