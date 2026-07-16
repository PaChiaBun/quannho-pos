import 'dart:async';
import 'package:flutter/foundation.dart';
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

  Stream<DashboardStats> watchTodayStats() {
    final controller = StreamController<DashboardStats>();
    
    // Fetch ban đầu
    getTodayStats().then((stats) {
      if (!controller.isClosed) controller.add(stats);
    });

    // Lắng nghe sự kiện Broadcast gọn nhẹ tự phát giữa các thiết bị (không dùng Supabase DB Realtime)
    final channel = _sb.channel('store_broadcast');
    channel.onBroadcast(
      event: 'checkout_completed',
      callback: (payload) async {
        final stats = await getTodayStats();
        if (!controller.isClosed) controller.add(stats);
      },
    ).subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  Future<DashboardStats> getTodayStats() async {
    final storeId = await _storeId();
    if (storeId == null) return DashboardStats.empty;

    final now        = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final endOfDay   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();

    final orders = await _sb
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', startOfDay)
        .lt('created_at', endOfDay);

    return _aggregateStats(orders);
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
    return _aggregateStats(orders);
  }

  Future<DashboardStats> _aggregateStats(List<dynamic> orders) async {
    final revenue = orders.fold<double>(0, (s, o) => s + ((o['total_amount'] as num?)?.toDouble() ?? 0));
    final orderCnt = orders.length;
    final customerSet = orders.where((o) => o['customer_id'] != null).map((o) => o['customer_id'] as String).toSet();

    double cashRevenue = 0;
    double transferRevenue = 0;
    double cardRevenue = 0;
    final staffRevenuesRaw = <String, double>{};
    final staffDetailsRaw = <String, Map<String, double>>{};
    final waiterCountsRaw = <String, int>{};

    for (final o in orders) {
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      final rawMethod = o['payment_method'] as String? ?? 'cash';
      final String method;
      if (rawMethod == 'cash') {
        method = 'cash';
        cashRevenue += amount;
      } else if (rawMethod == 'card') {
        method = 'card';
        cardRevenue += amount;
      } else {
        method = 'transfer';
        transferRevenue += amount;
      }

      final staffId = (o['staff_id'] as String?)?.isNotEmpty == true ? o['staff_id'] as String : 'unassigned';
      staffRevenuesRaw[staffId] = (staffRevenuesRaw[staffId] ?? 0) + amount;
      
      final details = staffDetailsRaw[staffId] ??= {'cash': 0, 'transfer': 0, 'card': 0, 'total': 0};
      details[method] = (details[method] ?? 0) + amount;
      details['total'] = (details['total'] ?? 0) + amount;

      // Đọc waiter_id từ orders (phục vụ bàn)
      final waiterId = o['waiter_id'] as String?;
      if (waiterId != null && waiterId.isNotEmpty) {
        waiterCountsRaw[waiterId] = (waiterCountsRaw[waiterId] ?? 0) + 1;
      }
    }

    final cashierRevenue = <String, double>{};
    final cashierDetails = <String, CashierDetail>{};

    if (staffRevenuesRaw.isNotEmpty) {
      try {
        final staffIds = staffRevenuesRaw.keys.where((id) => id != 'unassigned').toList();
        final nameMap = <String, String>{'unassigned': 'Không rõ thu ngân'};
        
        if (staffIds.isNotEmpty) {
          final memberRows = await _sb
              .from('store_members')
              .select('id, user_accounts(display_name)')
              .inFilter('id', staffIds);
          
          for (final r in memberRows) {
            final id = r['id'] as String;
            final userAcc = r['user_accounts'] as Map<String, dynamic>?;
            nameMap[id] = userAcc?['display_name'] as String? ?? 'Chưa rõ';
          }
        }

        staffRevenuesRaw.forEach((staffId, val) {
          final name = nameMap[staffId] ?? 'Nhân viên ẩn';
          cashierRevenue[name] = (cashierRevenue[name] ?? 0) + val;
        });

        staffDetailsRaw.forEach((staffId, details) {
          final name = nameMap[staffId] ?? 'Nhân viên ẩn';
          final existing = cashierDetails[name] ?? const CashierDetail();
          cashierDetails[name] = CashierDetail(
            cash: existing.cash + (details['cash'] ?? 0),
            transfer: existing.transfer + (details['transfer'] ?? 0),
            card: existing.card + (details['card'] ?? 0),
            total: existing.total + (details['total'] ?? 0),
          );
        });
      } catch (e) {
        debugPrint('[DashboardRepository] Error mapping cashier names: $e');
        staffRevenuesRaw.forEach((staffId, val) {
          final name = staffId == 'unassigned' ? 'Không rõ thu ngân' : 'NV-${staffId.substring(0, 4)}';
          cashierRevenue[name] = val;
        });
        staffDetailsRaw.forEach((staffId, details) {
          final name = staffId == 'unassigned' ? 'Không rõ thu ngân' : 'NV-${staffId.substring(0, 4)}';
          cashierDetails[name] = CashierDetail(
            cash: details['cash'] ?? 0,
            transfer: details['transfer'] ?? 0,
            card: details['card'] ?? 0,
            total: details['total'] ?? 0,
          );
        });
      }
    }

    final waiterOrders = <String, int>{};
    if (waiterCountsRaw.isNotEmpty) {
      try {
        final waiterIds = waiterCountsRaw.keys.toList();
        final memberRows = await _sb
            .from('store_members')
            .select('id, user_accounts(display_name)')
            .inFilter('id', waiterIds);
        
        final nameMap = <String, String>{};
        for (final r in memberRows) {
          final id = r['id'] as String;
          final userAcc = r['user_accounts'] as Map<String, dynamic>?;
          nameMap[id] = userAcc?['display_name'] as String? ?? 'Chưa rõ';
        }

        waiterCountsRaw.forEach((waiterId, val) {
          final name = nameMap[waiterId] ?? 'Nhân viên ẩn';
          waiterOrders[name] = (waiterOrders[name] ?? 0) + val;
        });
      } catch (e) {
        debugPrint('[DashboardRepository] Error mapping waiter names: $e');
        waiterCountsRaw.forEach((waiterId, val) {
          waiterOrders['NV-${waiterId.substring(0, 4)}'] = val;
        });
      }
    }

    return DashboardStats(
      todayRevenue: revenue,
      todayOrders: orderCnt,
      todayCustomers: customerSet.length,
      avgOrderValue: orderCnt > 0 ? revenue / orderCnt : 0,
      cashRevenue: cashRevenue,
      transferRevenue: transferRevenue,
      cardRevenue: cardRevenue,
      cashierRevenue: cashierRevenue,
      waiterOrders: waiterOrders,
      cashierDetails: cashierDetails,
    );
  }

  Future<List<DailyRevenue>> getDailyRevenue(int from, int to) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final f = DateTime.fromMillisecondsSinceEpoch(from).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();
    final orders = await _sb
        .from('orders')
        .select('created_at, total_amount, payment_method, discount')
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
      
      final amount = (o['total_amount'] as num?)?.toDouble() ?? 0;
      final disc = (o['discount'] as num?)?.toDouble() ?? 0;
      final method = o['payment_method'] as String? ?? 'cash';
      
      agg.revenue += amount;
      agg.orders++;
      agg.discount += disc;
      if (method == 'cash') {
        agg.cashRevenue += amount;
      } else {
        agg.transferRevenue += amount;
      }
    }
    // Fill tất cả ngày trong kỳ
    final startDate = DateTime.fromMillisecondsSinceEpoch(from);
    final endDate   = DateTime.fromMillisecondsSinceEpoch(to);
    final dayCount  = endDate.difference(startDate).inDays;
    return List.generate(dayCount, (i) {
      final day = DateTime(startDate.year, startDate.month, startDate.day + i);
      final key = '${day.year}-${day.month.toString().padLeft(2,'0')}-${day.day.toString().padLeft(2,'0')}';
      final agg = dayMap[key];
      return DailyRevenue(
        date: day,
        revenue: agg?.revenue ?? 0,
        orders: agg?.orders ?? 0,
        cashRevenue: agg?.cashRevenue ?? 0,
        transferRevenue: agg?.transferRevenue ?? 0,
        discount: agg?.discount ?? 0,
      );
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
class _DayAgg {
  DateTime date;
  double revenue = 0;
  int orders = 0;
  double cashRevenue = 0;
  double transferRevenue = 0;
  double discount = 0;
  _DayAgg(this.date);
}
class _HourAgg { double revenue = 0; int orders = 0; }

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────
class CashierDetail {
  final double cash;
  final double transfer;
  final double card;
  final double total;

  const CashierDetail({
    this.cash = 0,
    this.transfer = 0,
    this.card = 0,
    this.total = 0,
  });
}

class DashboardStats {
  final double todayRevenue;
  final int    todayOrders;
  final int    todayCustomers;
  final double avgOrderValue;
  final double cashRevenue;
  final double transferRevenue;
  final double cardRevenue;
  final Map<String, double> cashierRevenue;
  final Map<String, int>    waiterOrders;
  final Map<String, CashierDetail> cashierDetails;

  const DashboardStats({
    required this.todayRevenue,
    required this.todayOrders,
    required this.todayCustomers,
    required this.avgOrderValue,
    this.cashRevenue = 0,
    this.transferRevenue = 0,
    this.cardRevenue = 0,
    this.cashierRevenue = const {},
    this.waiterOrders = const {},
    this.cashierDetails = const {},
  });

  static const empty = DashboardStats(
    todayRevenue: 0, todayOrders: 0, todayCustomers: 0, avgOrderValue: 0,
    cashRevenue: 0, transferRevenue: 0, cardRevenue: 0, cashierRevenue: {},
    waiterOrders: {},
    cashierDetails: {},
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
  final double   cashRevenue;
  final double   transferRevenue;
  final double   discount;

  const DailyRevenue({
    required this.date,
    required this.revenue,
    required this.orders,
    this.cashRevenue = 0,
    this.transferRevenue = 0,
    this.discount = 0,
  });
}

class HourlyRevenue {
  final int    hour;
  final double revenue;
  final int    orders;
  const HourlyRevenue({required this.hour, required this.revenue, required this.orders});
}
