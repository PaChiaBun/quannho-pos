import 'package:drift/drift.dart';
import '../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD REPOSITORY — Tổng hợp data realtime cho Dashboard header
// Đọc từ: pos_orders, core_customers
// ─────────────────────────────────────────────────────────────────────────────
class DashboardRepository {
  final AppDatabase _db;
  DashboardRepository(this._db);

  // ── Today's revenue stream —————————————————————————————————————————
  Stream<DashboardStats> watchTodayStats() {
    // Time range: hôm nay 00:00 → 23:59
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;
    final end   = start + const Duration(hours: 23, minutes: 59, seconds: 59).inMilliseconds;

    return (_db.select(_db.posOrders)
          ..where((o) =>
              o.status.equals('completed') &
              o.createdAt.isBiggerOrEqualValue(start) &
              o.createdAt.isSmallerOrEqualValue(end)))
        .watch()
        .map((orders) {
          final revenue  = orders.fold<double>(0, (s, o) => s + o.totalAmount);
          final orderCnt = orders.length;
          final customerSet = orders
              .where((o) => o.customerId != null)
              .map((o) => o.customerId!)
              .toSet();

          return DashboardStats(
            todayRevenue:       revenue,
            todayOrders:        orderCnt,
            todayCustomers:     customerSet.length,
            avgOrderValue:      orderCnt > 0 ? revenue / orderCnt : 0,
          );
        });
  }

  // ── Top selling products today ────────────────────────────────────────────
  Future<List<TopProduct>> getTopProductsToday({int limit = 5}) async {
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch;

    // Get all order IDs today
    final todayOrders = await (_db.select(_db.posOrders)
          ..where((o) =>
              o.status.equals('completed') &
              o.createdAt.isBiggerOrEqualValue(start)))
        .get();

    if (todayOrders.isEmpty) return [];

    final orderIds = todayOrders.map((o) => o.id).toList();

    // Get items for those orders
    final items = await (_db.select(_db.posOrderItems)
          ..where((i) => i.orderId.isIn(orderIds)))
        .get();

    // Aggregate by product
    final map = <String, _ProductAgg>{};
    for (final item in items) {
      final agg = map[item.productId] ??= _ProductAgg(item.productName);
      agg.qty     += item.quantity;
      agg.revenue += item.subtotal;
    }

    return map.entries
        .map((e) => TopProduct(
              productId:   e.key,
              productName: e.value.name,
              totalQty:    e.value.qty,
              totalRevenue: e.value.revenue,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue))
      ..length = limit.clamp(0, map.length);
  }

  // ── Revenue chart data (last 7 days) ──────────────────────────────────────
  Future<List<DailyRevenue>> getLast7DaysRevenue() async {
    final now  = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final result = <DailyRevenue>[];
    for (final day in days) {
      final start = day.millisecondsSinceEpoch;
      final end   = start + const Duration(hours: 23, minutes: 59, seconds: 59).inMilliseconds;

      final orders = await (_db.select(_db.posOrders)
            ..where((o) =>
                o.status.equals('completed') &
                o.createdAt.isBiggerOrEqualValue(start) &
                o.createdAt.isSmallerOrEqualValue(end)))
          .get();

      result.add(DailyRevenue(
        date:    day,
        revenue: orders.fold<double>(0, (s, o) => s + o.totalAmount),
        orders:  orders.length,
      ));
    }
    return result;
  }
}

class _ProductAgg {
  final String name;
  double qty = 0;
  double revenue = 0;
  _ProductAgg(this.name);
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────
class DashboardStats {
  final double todayRevenue;
  final int    todayOrders;
  final int    todayCustomers;
  final double avgOrderValue;

  const DashboardStats({
    required this.todayRevenue,
    required this.todayOrders,
    required this.todayCustomers,
    required this.avgOrderValue,
  });

  static const empty = DashboardStats(
    todayRevenue: 0, todayOrders: 0,
    todayCustomers: 0, avgOrderValue: 0,
  );
}

class TopProduct {
  final String productId;
  final String productName;
  final double totalQty;
  final double totalRevenue;

  const TopProduct({
    required this.productId,
    required this.productName,
    required this.totalQty,
    required this.totalRevenue,
  });
}

class DailyRevenue {
  final DateTime date;
  final double   revenue;
  final int      orders;
  const DailyRevenue({required this.date, required this.revenue, required this.orders});
}
