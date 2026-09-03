import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/dashboard_repository.dart';
import 'session_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

/// Stats hôm nay — refresh khi session thay đổi hoặc bị invalidate từ ngoài
final todayStatsProvider = StreamProvider.autoDispose<DashboardStats>((ref) {
  ref.watch(sessionProvider); // bắt buộc refresh khi storeId có
  return ref.read(dashboardRepositoryProvider).watchTodayStats();
});

/// Top sản phẩm hôm nay
final topProductsTodayProvider = FutureProvider.autoDispose<List<TopProduct>>((ref) {
  // Tự refresh khi có đơn mới
  ref.watch(todayStatsProvider);
  return ref.read(dashboardRepositoryProvider).getTopProductsToday();
});

/// Doanh thu 7 ngày gần nhất
final last7DaysRevenueProvider = FutureProvider.autoDispose<List<DailyRevenue>>((ref) {
  ref.watch(todayStatsProvider);
  return ref.read(dashboardRepositoryProvider).getLast7DaysRevenue();
});

/// Thống kê huỷ bàn/huỷ món hôm nay — refresh khi session hoặc todayStats thay đổi
final todayVoidStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  ref.watch(sessionProvider);
  ref.watch(todayStatsProvider); // Tự động làm mới khi stats hôm nay cập nhật
  return ref.read(dashboardRepositoryProvider).getTodayVoidStats();
});

