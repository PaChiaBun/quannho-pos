import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/store_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class DashboardRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Today stats (Supabase query) ──────────────────────────────────────────

  Stream<DashboardStats> watchTodayStats() async* {
    // Supabase stream không hỗ trợ realtime query phức tạp —
    // poll mỗi 30 giây hoặc invalidate từ ngoài khi có đơn mới
    yield await getTodayStats();
  }

  Future<DashboardStats> getTodayStats() async {
    final storeId = await _storeId();
    if (storeId == null) return DashboardStats.empty;

    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String(); // ‼️ FIX: dùng DateTime(y,m,d) thay copyWith — tránh sai DST
    final endOfDay   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String(); // ‼️ FIX: thêm exclusive upper bound

    final orders = await _sb
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', startOfDay)
        .lt('created_at', endOfDay); // ‼️ FIX: lt (exclusive) thay vì không có upper bound

    final revenue     = orders.fold<double>(0, (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0));
    final orderCnt    = orders.length;
    final customerSet = orders
        .where((o) => o['customer_id'] != null)
        .map((o) => o['customer_id'] as String)
        .toSet();

    return DashboardStats(
      todayRevenue:   revenue,
      todayOrders:    orderCnt,
      todayCustomers: customerSet.length,
      avgOrderValue:  orderCnt > 0 ? revenue / orderCnt : 0,
    );
  }

  /// Lấy tổng hợp huỷ món / huỷ bàn hôm nay
  Future<Map<String, dynamic>> getTodayVoidStats() async {
    final storeId = await _storeId();
    if (storeId == null) return {'amount': 0.0, 'count': 0};

    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final endOfDay   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();

    try {
      final logs = await _sb
          .from('void_audit_logs')
          .select('amount')
          .eq('store_id', storeId)
          .gte('created_at', startOfDay)
          .lt('created_at', endOfDay);

      double totalAmount = 0;
      for (final log in logs) {
        totalAmount += (log['amount'] as num?)?.toDouble() ?? 0;
      }

      return {
        'amount': totalAmount,
        'count': logs.length,
      };
    } catch (e) {
      return {'amount': 0.0, 'count': 0};
    }
  }

  // ── Top products hôm nay ──────────────────────────────────────────────────

  Future<List<TopProduct>> getTopProductsToday({int limit = 5}) async {
    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    // ‼️ FIX Bug #20: dùng midnight ngày kế (exclusive) thay vì DateTime.now().toUtc()
    // Trước đây bỏ sót đơn phát sinh sau lần query đến hết ngày
    final endOfDay   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
    return getTopProductsForRange(startOfDay, endOfDay, limit: limit);
  }

  Future<List<TopProduct>> getTopProductsForRange(
    String from, String to, {
    int limit = 10,
    String? category, // ‼️ FIX: thêm category filter
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    final orders = await _sb
        .from('orders')
        .select('id')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', from)
        .lt('created_at', to); // ‼️ FIX: lt (exclusive) — caller truyền midnight ngày kế

    final orderIds = orders.map((o) => o['id'] as String).toList();
    final items    = await _sb.from('order_items').select().inFilter('order_id', orderIds);

    final map = <String, _ProductAgg>{};
    for (final item in items) {
      final productId = item['product_id'] as String? ?? '';
      final agg = map[productId] ??= _ProductAgg(item['product_name'] as String? ?? item['name'] as String? ?? '');
      // Fallback: quantity (extended col) → qty (legacy col)
      agg.qty     += (item['quantity'] as num?)?.toDouble()
                  ?? (item['qty'] as num?)?.toDouble() ?? 0;
      agg.revenue += (item['subtotal'] as num?)?.toDouble() ?? 0;
    }

    // ‼️ FIX: filter theo category nếu được chỉ định
    // Fetch category map 1 lần (tránh N+1 query)
    Map<String, String> catMap = {};
    if (category != null && map.isNotEmpty) {
      final productIds = map.keys.toList();
      final prodRows = await _sb
          .from('products')
          .select('id, category')
          .inFilter('id', productIds);
      for (final p in prodRows) {
        catMap[p['id'] as String] = (p['category'] as String?) ?? '';
      }
    }

    var entries = map.entries.toList();
    if (category != null) {
      entries = entries.where((e) => catMap[e.key] == category).toList();
    }

    // ‼️ FIX Bug #35: ..take(limit) là Iterable không gán lại — limit vô hiệu
    // Fix: build → sort → sublist để đảm bảo limit đúng
    final sorted = entries
        .map((e) => TopProduct(
              productId:    e.key,
              productName:  e.value.name,
              totalQty:     e.value.qty,
              totalRevenue: e.value.revenue,
            ))
        .toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return sorted.length > limit ? sorted.sublist(0, limit) : sorted;
  }



  // ── Compat methods — nhận int (ms) thay vì String ISO ────────────────────

  /// Report screen dùng int (millisecondsSinceEpoch) → chuyển sang ISO
  Future<DashboardStats> getStatsForRange(int from, int to) {
    final f = DateTime.fromMillisecondsSinceEpoch(from).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();
    return _getStatsForRange(f, t);
  }

  Future<DashboardStats> _getStatsForRange(String from, String to) async {
    final storeId = await _storeId();
    if (storeId == null) return DashboardStats.empty;
    final orders = await _sb
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', from)
        .lt('created_at', to); // ‼️ FIX: lt (exclusive) — nhất quán với finance_repository
    final revenue     = orders.fold<double>(0, (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0));
    final orderCnt    = orders.length;
    final customerSet = orders.where((o) => o['customer_id'] != null).map((o) => o['customer_id'] as String).toSet();
    return DashboardStats(
      todayRevenue: revenue, todayOrders: orderCnt,
      todayCustomers: customerSet.length,
      avgOrderValue: orderCnt > 0 ? revenue / orderCnt : 0,
    );
  }

  Future<List<DailyRevenue>> getDailyRevenue(int from, int to) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final f = DateTime.fromMillisecondsSinceEpoch(from).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();
    final orders = await _sb
        .from('orders')
        .select('created_at, total_amount')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', f)
        .lt('created_at', t); // ‼️ FIX: lt (exclusive)
    final dayMap = <String, _DayAgg>{};
    for (final o in orders) {
      final dt = DateTime.tryParse(o['created_at'] as String? ?? '')?.toLocal();
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
      final agg = dayMap[key] ??= _DayAgg(dt);
      agg.revenue += (o['total_amount'] as num?)?.toDouble() ?? 0;
      agg.orders++;
    }
    // Fill tất cả ngày trong kỳ
    final startDate = DateTime.fromMillisecondsSinceEpoch(from);
    final endDate   = DateTime.fromMillisecondsSinceEpoch(to);
    // ‼️ FIX: to là exclusive (midnight ngày kế) → không +1
    // VD: tuần = Mon 00:00 → Sun+1 00:00 → diff = 7 ngày → đúng 7 cột
    final dayCount  = endDate.difference(startDate).inDays;
    return List.generate(dayCount, (i) {
      final day = DateTime(startDate.year, startDate.month, startDate.day + i);
      final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      final agg = dayMap[key];
      return DailyRevenue(date: day, revenue: agg?.revenue ?? 0, orders: agg?.orders ?? 0);
    });
  }

  Stream<List<HourlyRevenue>> watchHourlyRevenue(DateTime date) async* {
    // Supabase không hỗ trợ streaming phức tạp → poll 1 lần + dùng Realtime để invalidate
    yield await getHourlyRevenue(date);
  }

  Future<List<String>> getProductCategoriesSold(int from, int to) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final f = DateTime.fromMillisecondsSinceEpoch(from).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();
    final orders = await _sb
        .from('orders')
        .select('id')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', f)
        .lt('created_at', t); // ‼️ FIX: lt (exclusive)
    if (orders.isEmpty) return [];
    final orderIds = orders.map((o) => o['id'] as String).toList();
    final items = await _sb.from('order_items').select('product_id').inFilter('order_id', orderIds);
    final productIds = items.map((i) => i['product_id'] as String).toSet().toList();
    if (productIds.isEmpty) return [];
    final products = await _sb.from('products').select('category').inFilter('id', productIds);
    return products.map((p) => p['category'] as String? ?? '').where((c) => c.isNotEmpty).toSet().toList()..sort();
  }

  // Thêm category filter cho getTopProductsForRange compat
  Future<List<TopProduct>> getTopProductsForRangeCompat(
    int from, int to, {String? category, int limit = 10}) async {
    final f = DateTime.fromMillisecondsSinceEpoch(from).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();
    // ‼️ FIX: truyền category xuống getTopProductsForRange — trước đây bị drop silently
    return getTopProductsForRange(f, t, category: category, limit: limit);
  }

  // ── Doanh thu 7 ngày gần nhất ────────────────────────────────────────────

  Future<List<DailyRevenue>> getLast7DaysRevenue() async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    final now  = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 6))
        .toUtc()
        .toIso8601String();
    // ‼️ FIX Bug #36: thêm upper bound exclusive — trước đây không có .lt() →
    // đơn future-dated hoặc clock skew bị tính vào doanh thu 7 ngày
    final to   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();

    final orders = await _sb
        .from('orders')
        .select('created_at, total_amount')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', from)
        .lt('created_at', to); // ‼️ FIX Bug #36: upper bound exclusive

    // Group by date
    final dayMap = <String, _DayAgg>{};
    for (final o in orders) {
      final dt  = DateTime.tryParse(o['created_at'] as String? ?? '')?.toLocal();
      if (dt == null) continue;
      final key = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      final agg = dayMap[key] ??= _DayAgg(dt);
      agg.revenue += (o['total_amount'] as num?)?.toDouble() ?? 0;
      agg.orders++;
    }

    // 7 ngày đủ
    final result = <DailyRevenue>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final agg = dayMap[key];
      result.add(DailyRevenue(
        date:    day,
        revenue: agg?.revenue ?? 0,
        orders:  agg?.orders  ?? 0,
      ));
    }
    return result;
  }

  // ── Hourly revenue hôm nay ────────────────────────────────────────────────

  Future<List<HourlyRevenue>> getHourlyRevenue(DateTime date) async {
    final storeId = await _storeId();
    if (storeId == null) return _emptyHourly();

    final startOfDay = DateTime(date.year, date.month, date.day).toUtc().toIso8601String();
    // Dùng midnight ngày kế (exclusive) — 23:59:59 bỏ sót 23:59:59.001 – 23:59:59.999
    final endOfDay   = DateTime(date.year, date.month, date.day + 1).toUtc().toIso8601String();

    final orders = await _sb
        .from('orders')
        .select('created_at, total_amount')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', startOfDay)
        .lt('created_at', endOfDay);  // exclusive upper — nhất quán với finance


    final hourMap = <int, _HourAgg>{};
    for (final o in orders) {
      final dt  = DateTime.tryParse(o['created_at'] as String? ?? '')?.toLocal();
      if (dt == null) continue;
      final agg = hourMap[dt.hour] ??= _HourAgg();
      agg.revenue += (o['total_amount'] as num?)?.toDouble() ?? 0;
      agg.orders++;
    }
    return List.generate(24, (h) {
      final agg = hourMap[h] ?? _HourAgg();
      return HourlyRevenue(hour: h, revenue: agg.revenue, orders: agg.orders);
    });
  }

  List<HourlyRevenue> _emptyHourly() =>
      List.generate(24, (h) => HourlyRevenue(hour: h, revenue: 0, orders: 0));
}

// ── Private helpers ────────────────────────────────────────────────────────────
class _ProductAgg { final String name; double qty = 0; double revenue = 0; _ProductAgg(this.name); }
class _DayAgg { DateTime date; double revenue = 0; int orders = 0; _DayAgg(this.date); }
class _HourAgg { double revenue = 0; int orders = 0; }

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
    todayRevenue: 0, todayOrders: 0, todayCustomers: 0, avgOrderValue: 0,
  );
}

class TopProduct {
  final String productId;
  final String productName;
  final double totalQty;
  final double totalRevenue;

  const TopProduct({
    required this.productId, required this.productName,
    required this.totalQty, required this.totalRevenue,
  });
}

class DailyRevenue {
  final DateTime date;
  final double   revenue;
  final int      orders;
  const DailyRevenue({required this.date, required this.revenue, required this.orders});
}

class HourlyRevenue {
  final int    hour;
  final double revenue;
  final int    orders;
  const HourlyRevenue({required this.hour, required this.revenue, required this.orders});
}
