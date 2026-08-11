import 'package:supabase_flutter/supabase_flutter.dart';

/// Cổng dữ liệu kinh doanh dành riêng cho AI Bum.
///
/// File này cố ý chỉ sử dụng `select()`. AI Bum không có API ghi, không gọi
/// RPC nghiệp vụ và không nhận các trường nhạy cảm như PIN, số điện thoại hay
/// ghi chú đơn hàng.
class BumReadOnlyDataService {
  BumReadOnlyDataService(this._db);

  final SupabaseClient _db;

  Future<BumTodaySummary> getTodaySummary(String storeId) async {
    final range = _todayRange();
    final yesterdayStart = range.start.subtract(const Duration(days: 1));
    final rows = await _db
        .from('orders')
        .select('total_amount,total,created_at')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', yesterdayStart.toIso8601String())
        .lt('created_at', range.end.toIso8601String());

    var todayRevenue = 0.0;
    var yesterdayRevenue = 0.0;
    var todayOrders = 0;
    for (final row in rows) {
      final createdAt = DateTime.tryParse(row['created_at'] as String? ?? '');
      if (createdAt == null) continue;
      final amount = _amount(row);
      if (!createdAt.isBefore(range.start)) {
        todayRevenue += amount;
        todayOrders++;
      } else {
        yesterdayRevenue += amount;
      }
    }

    return BumTodaySummary(
      revenue: todayRevenue,
      orderCount: todayOrders,
      averageOrderValue: todayOrders == 0 ? 0 : todayRevenue / todayOrders,
      yesterdayRevenue: yesterdayRevenue,
    );
  }

  Future<BumProductPerformance> getProductPerformance(
    String storeId, {
    int limit = 3,
  }) async {
    final range = _todayRange();
    final orders = await _db
        .from('orders')
        .select('id')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', range.start.toIso8601String())
        .lt('created_at', range.end.toIso8601String());
    final orderIds = orders.map((row) => row['id'] as String).toList();

    final sold = <String, _ProductAccumulator>{};
    const chunkSize = 100;
    for (var offset = 0; offset < orderIds.length; offset += chunkSize) {
      final end = (offset + chunkSize).clamp(0, orderIds.length);
      final items = await _db
          .from('order_items')
          .select(
            'product_id,product_name,name,quantity,qty,subtotal,unit_price',
          )
          .inFilter('order_id', orderIds.sublist(offset, end));
      for (final item in items) {
        final id = item['product_id'] as String?;
        if (id == null || id.isEmpty) continue;
        final quantity =
            (item['quantity'] as num?)?.toDouble() ??
            (item['qty'] as num?)?.toDouble() ??
            0;
        final revenue =
            (item['subtotal'] as num?)?.toDouble() ??
            quantity * ((item['unit_price'] as num?)?.toDouble() ?? 0);
        final accumulator = sold[id] ??= _ProductAccumulator(
          (item['product_name'] as String?) ??
              (item['name'] as String?) ??
              'Sản phẩm',
        );
        accumulator.quantity += quantity;
        accumulator.revenue += revenue;
      }
    }

    final activeProducts = await _db
        .from('products')
        .select('id,name')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .eq('is_deleted', false);

    final all = activeProducts.map((product) {
      final id = product['id'] as String;
      final current = sold[id];
      return BumProductMetric(
        name: (product['name'] as String?) ?? current?.name ?? 'Sản phẩm',
        quantity: current?.quantity ?? 0,
        revenue: current?.revenue ?? 0,
      );
    }).toList();

    final top = [...all]
      ..sort((a, b) {
        final byRevenue = b.revenue.compareTo(a.revenue);
        return byRevenue != 0 ? byRevenue : b.quantity.compareTo(a.quantity);
      });
    final slow = [...all]
      ..sort((a, b) {
        final byQuantity = a.quantity.compareTo(b.quantity);
        return byQuantity != 0 ? byQuantity : a.revenue.compareTo(b.revenue);
      });

    return BumProductPerformance(
      top: top.take(limit).toList(),
      slow: slow.take(limit).toList(),
      completedOrderCount: orderIds.length,
    );
  }

  Future<List<BumStockAlert>> getLowStock(String storeId) async {
    final rows = await _db
        .from('products')
        .select('name,stock_qty,min_stock')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .eq('is_deleted', false);

    final alerts =
        rows
            .map(
              (row) => BumStockAlert(
                name: (row['name'] as String?) ?? 'Sản phẩm',
                stockQuantity: (row['stock_qty'] as num?)?.toDouble() ?? 0,
                minimumStock: (row['min_stock'] as num?)?.toDouble() ?? 0,
              ),
            )
            .where((item) => item.stockQuantity <= item.minimumStock)
            .toList()
          ..sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));
    return alerts;
  }

  Future<BumShiftSummary> getStaffOnShift(String storeId) async {
    final range = _todayRange();
    final shifts = await _db
        .from('staff_shifts')
        .select('user_id,clock_in')
        .eq('store_id', storeId)
        .gte('clock_in', range.start.toIso8601String())
        .lt('clock_in', range.end.toIso8601String())
        .isFilter('clock_out', null);
    final userIds = shifts
        .map((row) => row['user_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    if (userIds.isEmpty) return const BumShiftSummary(count: 0, names: []);

    final users = await _db
        .from('user_accounts')
        .select('id,display_name')
        .inFilter('id', userIds);
    final names =
        users
            .map((row) => row['display_name'] as String?)
            .whereType<String>()
            .where((name) => name.trim().isNotEmpty)
            .toList()
          ..sort();
    return BumShiftSummary(count: userIds.length, names: names);
  }

  ({DateTime start, DateTime end}) _todayRange() {
    final now = DateTime.now();
    return (
      start: DateTime(now.year, now.month, now.day).toUtc(),
      end: DateTime(now.year, now.month, now.day + 1).toUtc(),
    );
  }

  double _amount(Map<String, dynamic> row) =>
      (row['total_amount'] as num?)?.toDouble() ??
      (row['total'] as num?)?.toDouble() ??
      0;
}

class BumTodaySummary {
  const BumTodaySummary({
    required this.revenue,
    required this.orderCount,
    required this.averageOrderValue,
    required this.yesterdayRevenue,
  });

  final double revenue;
  final int orderCount;
  final double averageOrderValue;
  final double yesterdayRevenue;

  double? get changePercent => yesterdayRevenue <= 0
      ? null
      : ((revenue - yesterdayRevenue) / yesterdayRevenue) * 100;
}

class BumProductPerformance {
  const BumProductPerformance({
    required this.top,
    required this.slow,
    required this.completedOrderCount,
  });

  final List<BumProductMetric> top;
  final List<BumProductMetric> slow;
  final int completedOrderCount;
}

class BumProductMetric {
  const BumProductMetric({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final double quantity;
  final double revenue;
}

class BumStockAlert {
  const BumStockAlert({
    required this.name,
    required this.stockQuantity,
    required this.minimumStock,
  });

  final String name;
  final double stockQuantity;
  final double minimumStock;
}

class BumShiftSummary {
  const BumShiftSummary({required this.count, required this.names});

  final int count;
  final List<String> names;
}

class _ProductAccumulator {
  _ProductAccumulator(this.name);

  final String name;
  double quantity = 0;
  double revenue = 0;
}
