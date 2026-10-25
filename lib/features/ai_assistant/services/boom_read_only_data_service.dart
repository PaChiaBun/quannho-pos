import 'package:supabase_flutter/supabase_flutter.dart';

/// Cổng dữ liệu kinh doanh dành riêng cho AI Boom.
///
/// File này cố ý chỉ sử dụng `select()`. AI Boom không có API ghi, không gọi
/// RPC nghiệp vụ và không nhận các trường nhạy cảm như PIN, số điện thoại hay
/// ghi chú đơn hàng.
class BoomReadOnlyDataService {
  BoomReadOnlyDataService(this._db);

  final SupabaseClient _db;

  void _validateStoreId(String storeId) {
    if (storeId.trim().isEmpty) {
      // Test cách ly quán (boom_store_isolation_test) tìm nguyên dòng throw dưới đây.
      // dart format off
      throw ArgumentError.value(storeId, 'storeId', 'Store ID must not be empty');
      // dart format on
    }
  }

  /// Doanh thu đơn hoàn thành trong [period] (giờ trên máy) + cùng kỳ trước đó để so sánh.
  /// Đọc theo trang 1.000 dòng (máy chủ trả tối đa 1.000 dòng / lần — tháng của quán đông có vài nghìn đơn).
  Future<BoomRevenueSummary> getRevenueSummary(
    String storeId,
    BoomPeriod period, {
    DateTime? now,
  }) async {
    _validateStoreId(storeId);
    final r = boomPeriodRange(period, now ?? DateTime.now());
    final both = await Future.wait([
      _completedOrders(
        storeId,
        r.start,
        r.end,
        'total_amount,total,created_at',
      ),
      _completedOrders(storeId, r.prevStart, r.prevEnd, 'total_amount,total'),
    ]);
    final current = both[0];
    final previous = both[1];
    // Doanh thu theo giờ / thứ (giờ máy) — tư vấn "buổi chiều đẩy món nào", "thứ 2 vắng" (chấm cố vấn 24/10)
    final byHour = List<double>.filled(24, 0);
    final byWeekday = List<double>.filled(7, 0);
    for (final row in current) {
      final at = DateTime.tryParse(
        '${row['created_at']}',
      )?.toUtc().add(const Duration(hours: 7));
      if (at == null) continue;
      byHour[at.hour] += _amount(row);
      byWeekday[at.weekday - 1] += _amount(row);
    }
    return BoomRevenueSummary(
      byHour: byHour,
      byWeekday: byWeekday,
      range: r,
      revenue: current.fold(0.0, (sum, row) => sum + _amount(row)),
      orderCount: current.length,
      previousRevenue: previous.fold(0.0, (sum, row) => sum + _amount(row)),
      previousOrderCount: previous.length,
    );
  }

  Future<List<Map<String, dynamic>>> _orderItems(List<String> ids) async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0; from < _maxRows; from += _pageSize) {
      final page = await _db
          .from('order_items')
          .select(
            'id,order_id,product_id,product_name,name,quantity,qty,subtotal,unit_price,cost_price',
          )
          .inFilter('order_id', ids)
          .order('id')
          .range(from, from + _pageSize - 1);
      out.addAll(page);
      if (page.length < _pageSize) break;
    }
    return out;
  }

  static const _pageSize = 1000;
  static const _maxRows = 100000;

  Future<List<Map<String, dynamic>>> _completedOrders(
    String storeId,
    DateTime start,
    DateTime end,
    String columns,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (var from = 0; from < _maxRows; from += _pageSize) {
      final page = await _db
          .from('orders')
          .select(columns)
          .eq('store_id', storeId)
          .eq('status', 'completed')
          .gte('created_at', start.toUtc().toIso8601String())
          .lt('created_at', end.toUtc().toIso8601String())
          .order('created_at')
          .order('id')
          .range(from, from + _pageSize - 1);
      out.addAll(page);
      if (page.length < _pageSize) break;
    }
    return out;
  }

  Future<BoomTodaySummary> getTodaySummary(String storeId) async {
    _validateStoreId(storeId);
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

    return BoomTodaySummary(
      revenue: todayRevenue,
      orderCount: todayOrders,
      averageOrderValue: todayOrders == 0 ? 0 : todayRevenue / todayOrders,
      yesterdayRevenue: yesterdayRevenue,
    );
  }

  Future<BoomProductPerformance> getProductPerformance(
    String storeId, {
    int limit = 3,
    BoomPeriod period = BoomPeriod.today,
    DateTime? now,
  }) async {
    _validateStoreId(storeId);
    final range = boomPeriodRange(period, now ?? DateTime.now());
    final orders = await _completedOrders(
      storeId,
      range.start,
      range.end,
      'id,created_at',
    );
    final orderIds = orders.map((row) => row['id'] as String).toList();
    // Khung giờ của từng đơn (giờ máy): sáng 5–11h, trưa 11–14h, chiều 14–17h, tối 17–5h
    final bandOf = <String, int>{};
    for (final row in orders) {
      // Giờ Việt Nam cố định (máy để múi giờ khác / UTC vẫn đúng khung giờ)
      final at = DateTime.tryParse(
        '${row['created_at']}',
      )?.toUtc().add(const Duration(hours: 7));
      if (at == null) continue;
      final h = at.hour;
      bandOf[row['id'] as String] = h >= 5 && h < 11
          ? 0
          : h >= 11 && h < 14
          ? 1
          : h >= 14 && h < 17
          ? 2
          : 3;
    }
    final bandQty = List.generate(4, (_) => <String, double>{});

    final sold = <String, _ProductAccumulator>{};
    // Món của đơn: mỗi lần 100 đơn, 5 lần chạy song song (tháng vài nghìn đơn trên web không chờ lâu); mỗi lần
    // đọc theo trang 1.000 dòng phòng đơn nhiều món.
    const chunkSize = 100;
    final chunks = [
      for (var o = 0; o < orderIds.length; o += chunkSize)
        orderIds.sublist(o, (o + chunkSize).clamp(0, orderIds.length)),
    ];
    final allItems = <Map<String, dynamic>>[];
    for (var g = 0; g < chunks.length; g += 5) {
      final pages = await Future.wait(chunks.skip(g).take(5).map(_orderItems));
      for (final p in pages) {
        allItems.addAll(p);
      }
    }
    {
      final items = allItems;
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
        final unitCost = (item['cost_price'] as num?)?.toDouble() ?? 0;
        if (unitCost > 0) {
          accumulator.cost += unitCost * quantity;
          accumulator.costQty += quantity;
        }
        final band = bandOf[item['order_id']];
        if (band != null) {
          bandQty[band][id] = (bandQty[band][id] ?? 0) + quantity;
        }
      }
    }

    // Chỉ món bán (bỏ nguyên liệu); kèm nhóm + giá bán để so món trong cùng nhóm (Chủ Quán 24/10: Boom đem
    // món chính so với đồ uống / topping, xếp nguyên liệu "0 phần" vào món bán chậm).
    final activeProducts = await _db
        .from('products')
        .select(
          'id,name,category,sell_price,cost_price,cost_price_latest,is_topping,is_raw_material',
        )
        .eq('store_id', storeId)
        .eq('is_active', true)
        .eq('is_deleted', false);

    final all = activeProducts
        .where((product) => product['is_raw_material'] != true)
        .map((product) {
          final id = product['id'] as String;
          final current = sold[id];
          final category = (product['category'] as String?)?.trim();
          return BoomProductMetric(
            name: (product['name'] as String?) ?? current?.name ?? 'Sản phẩm',
            quantity: current?.quantity ?? 0,
            revenue: current?.revenue ?? 0,
            category: product['is_topping'] == true
                ? 'Topping'
                : (category == null || category.isEmpty ? 'Khác' : category),
            price: (product['sell_price'] as num?)?.toDouble() ?? 0,
            // Giá vốn / phần: theo dòng đơn (lúc bán) nếu có, không thì giá vốn trên món
            unitCost: current != null && current.costQty > 0
                ? current.cost / current.costQty
                : (((product['cost_price_latest'] as num?)?.toDouble() ?? 0) > 0
                      ? (product['cost_price_latest'] as num).toDouble()
                      : ((product['cost_price'] as num?)?.toDouble() ?? 0)),
          );
        })
        .toList();

    final names = {
      for (final product in activeProducts)
        // Khung giờ: bỏ nguyên liệu + topping (trân châu… luôn đứng đầu, không phải món để đẩy)
        if (product['is_raw_material'] != true && product['is_topping'] != true)
          product['id'] as String: (product['name'] as String?) ?? 'Sản phẩm',
    };
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

    return BoomProductPerformance(
      top: top.take(limit).toList(),
      slow: slow.take(limit).toList(),
      all: all,
      byBand: [
        for (final b in bandQty)
          (b.entries.where((e) => names.containsKey(e.key)).toList()
                ..sort((a, x) => x.value.compareTo(a.value)))
              .take(3)
              .map((e) => (name: names[e.key]!, qty: e.value))
              .toList(),
      ],
      completedOrderCount: orderIds.length,
    );
  }

  Future<List<BoomStockAlert>> getLowStock(String storeId) async {
    _validateStoreId(storeId);
    final rows = await _db
        .from('products')
        .select('name,stock_qty,min_stock')
        .eq('store_id', storeId)
        .eq('is_active', true)
        .eq('is_deleted', false);

    final alerts =
        rows
            .map(
              (row) => BoomStockAlert(
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

  Future<BoomShiftSummary> getStaffOnShift(String storeId) async {
    _validateStoreId(storeId);
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
    if (userIds.isEmpty) return const BoomShiftSummary(count: 0, names: []);

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
    return BoomShiftSummary(count: userIds.length, names: names);
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

/// Khoảng thời gian Boom trả số liệu (theo câu hỏi: "hôm nay", "tháng này"…).
enum BoomPeriod { today, yesterday, thisWeek, lastWeek, thisMonth, lastMonth }

BoomPeriod boomPeriodFrom(String? timeRange) => switch (timeRange) {
  'yesterday' => BoomPeriod.yesterday,
  'this_week' => BoomPeriod.thisWeek,
  'last_week' => BoomPeriod.lastWeek,
  'this_month' => BoomPeriod.thisMonth,
  'last_month' => BoomPeriod.lastMonth,
  _ => BoomPeriod.today,
};

class BoomPeriodRange {
  const BoomPeriodRange({
    required this.start,
    required this.end,
    required this.prevStart,
    required this.prevEnd,
    required this.label,
    required this.prevLabel,
  });

  final DateTime start, end, prevStart, prevEnd;

  /// "Hôm nay", "Tháng này (1/10–24/10)"…
  final String label;

  /// "cùng giờ hôm qua", "cùng kỳ tháng trước (1/9–24/9)"…
  final String prevLabel;
}

String _dm(DateTime d) => '${d.day}/${d.month}';

/// Khoảng đang hỏi + cùng kỳ trước (giờ trên máy). Kỳ đang chạy (hôm nay / tuần này / tháng này) so với
/// cùng độ dài kỳ trước tính tới cùng thời điểm; kỳ đã xong so với nguyên kỳ trước đó.
BoomPeriodRange boomPeriodRange(BoomPeriod p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (p) {
    case BoomPeriod.today:
      final y = today.subtract(const Duration(days: 1));
      return BoomPeriodRange(
        start: today,
        end: now,
        prevStart: y,
        prevEnd: y.add(now.difference(today)),
        label: 'Hôm nay',
        prevLabel: 'cùng giờ hôm qua',
      );
    case BoomPeriod.yesterday:
      final y = today.subtract(const Duration(days: 1));
      final b = today.subtract(const Duration(days: 2));
      return BoomPeriodRange(
        start: y,
        end: today,
        prevStart: b,
        prevEnd: y,
        label: 'Hôm qua (${_dm(y)})',
        prevLabel: 'hôm kia (${_dm(b)})',
      );
    case BoomPeriod.thisWeek:
    case BoomPeriod.lastWeek:
      final monday = today.subtract(Duration(days: today.weekday - 1));
      if (p == BoomPeriod.thisWeek) {
        final lastMonday = monday.subtract(const Duration(days: 7));
        return BoomPeriodRange(
          start: monday,
          end: now,
          prevStart: lastMonday,
          prevEnd: lastMonday.add(now.difference(monday)),
          label: 'Tuần này (từ thứ Hai ${_dm(monday)})',
          prevLabel: 'cùng kỳ tuần trước',
        );
      }
      final lastMonday = monday.subtract(const Duration(days: 7));
      final before = monday.subtract(const Duration(days: 14));
      return BoomPeriodRange(
        start: lastMonday,
        end: monday,
        prevStart: before,
        prevEnd: lastMonday,
        label:
            'Tuần trước (${_dm(lastMonday)}–${_dm(monday.subtract(const Duration(days: 1)))})',
        prevLabel: 'tuần trước nữa',
      );
    case BoomPeriod.thisMonth:
      final first = DateTime(now.year, now.month);
      final prevFirst = DateTime(now.year, now.month - 1);
      var prevEnd = prevFirst.add(now.difference(first));
      if (prevEnd.isAfter(first)) {
        prevEnd = first; // 31/3 so với tháng 2 ngắn hơn
      }
      return BoomPeriodRange(
        start: first,
        end: now,
        prevStart: prevFirst,
        prevEnd: prevEnd,
        label: 'Tháng này (${_dm(first)}–${_dm(now)})',
        prevLabel:
            'cùng kỳ tháng trước (${_dm(prevFirst)}–${_dm(prevEnd.subtract(const Duration(seconds: 1)))})',
      );
    case BoomPeriod.lastMonth:
      final first = DateTime(now.year, now.month);
      final prevFirst = DateTime(now.year, now.month - 1);
      final before = DateTime(now.year, now.month - 2);
      return BoomPeriodRange(
        start: prevFirst,
        end: first,
        prevStart: before,
        prevEnd: prevFirst,
        label: 'Tháng trước (tháng ${prevFirst.month})',
        prevLabel: 'tháng ${before.month}',
      );
  }
}

class BoomRevenueSummary {
  const BoomRevenueSummary({
    required this.range,
    required this.revenue,
    required this.orderCount,
    required this.previousRevenue,
    required this.previousOrderCount,
    this.byHour = const [],
    this.byWeekday = const [],
  });

  final BoomPeriodRange range;

  /// Doanh thu kỳ này theo giờ (0–23) và theo thứ (Thứ 2 … Chủ nhật).
  final List<double> byHour;
  final List<double> byWeekday;
  final double revenue;
  final int orderCount;
  final double previousRevenue;
  final int previousOrderCount;

  double get averageOrderValue => orderCount == 0 ? 0 : revenue / orderCount;

  double? get changePercent => previousRevenue <= 0
      ? null
      : ((revenue - previousRevenue) / previousRevenue) * 100;
}

class BoomTodaySummary {
  const BoomTodaySummary({
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

class BoomProductPerformance {
  const BoomProductPerformance({
    required this.top,
    required this.slow,
    this.all = const [],
    this.byBand = const [],
    required this.completedOrderCount,
  });

  /// Món bán chạy nhất (tối đa 3) theo khung giờ: sáng 5–11h, trưa 11–14h, chiều 14–17h, tối 17h trở đi.
  final List<List<({String name, double qty})>> byBand;

  final List<BoomProductMetric> top;
  final List<BoomProductMetric> slow;

  /// Mọi món đang bán (không gồm nguyên liệu) — để tư vấn theo nhóm.
  final List<BoomProductMetric> all;
  final int completedOrderCount;
}

class BoomProductMetric {
  const BoomProductMetric({
    required this.name,
    required this.quantity,
    required this.revenue,
    this.category = 'Khác',
    this.price = 0,
    this.unitCost = 0,
  });

  /// Giá vốn một phần (0 = quán chưa nhập giá vốn).
  final double unitCost;

  final String name;
  final double quantity;
  final double revenue;

  /// Nhóm món của quán ("Đồ ăn", "Đồ uống"…); topping → "Topping"; chưa xếp nhóm → "Khác".
  final String category;

  /// Giá bán hiện tại.
  final double price;
}

class BoomStockAlert {
  const BoomStockAlert({
    required this.name,
    required this.stockQuantity,
    required this.minimumStock,
  });

  final String name;
  final double stockQuantity;
  final double minimumStock;
}

class BoomShiftSummary {
  const BoomShiftSummary({required this.count, required this.names});

  final int count;
  final List<String> names;
}

class _ProductAccumulator {
  _ProductAccumulator(this.name);

  final String name;
  double quantity = 0;
  double revenue = 0;
  double cost = 0;
  double costQty = 0;
}
