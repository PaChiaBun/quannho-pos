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
    channel
        .onBroadcast(
          event: 'checkout_completed',
          callback: (payload) async {
            final stats = await getTodayStats();
            if (!controller.isClosed) controller.add(stats);
          },
        )
        .subscribe();

    controller.onCancel = () {
      channel.unsubscribe();
    };

    return controller.stream;
  }

  static double _asDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  static int _asInt(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  Future<DashboardStats> getTodayStats() async {
    final now = DateTime.now();
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).toUtc().toIso8601String();

    return _getStatsForRange(startOfDay, endOfDay);
  }

  /// Lấy tổng hợp huỷ món / huỷ bàn hôm nay
  Future<Map<String, dynamic>> getTodayVoidStats() async {
    final storeId = await _storeId();
    if (storeId == null) return {'amount': 0.0, 'count': 0};

    final now = DateTime.now();
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).toUtc().toIso8601String();

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

      return {'amount': totalAmount, 'count': logs.length};
    } catch (e) {
      return {'amount': 0.0, 'count': 0};
    }
  }

  // ── Top products hôm nay ──────────────────────────────────────────────────

  Future<List<TopProduct>> getTopProductsToday({int limit = 5}) async {
    final now = DateTime.now();
    final startOfDay = DateTime(
      now.year,
      now.month,
      now.day,
    ).toUtc().toIso8601String();
    // ‼️ FIX Bug #20: dùng midnight ngày kế (exclusive) thay vì DateTime.now().toUtc()
    // Trước đây bỏ sót đơn phát sinh sau lần query đến hết ngày
    final endOfDay = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).toUtc().toIso8601String();
    return getTopProductsForRange(startOfDay, endOfDay, limit: limit);
  }

  Future<List<TopProduct>> getTopProductsForRange(
    String from,
    String to, {
    int limit = 10,
    String? category, // ‼️ FIX: thêm category filter
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    // Ưu tiên gọi RPC JOIN trực tiếp trên database (tránh N+1 và vượt ngưỡng 1000 đơn)
    try {
      final res = await _sb.rpc('get_top_products_for_range_v1', params: {
        'p_store_id': storeId,
        'p_from': from,
        'p_to': to,
        'p_category': (category != null && category.trim().isNotEmpty)
            ? category.trim()
            : null,
        'p_limit': limit,
      });

      if (res is List) {
        return res
            .whereType<Map>()
            .map((m) {
              return TopProduct(
                productId: (m['product_id'] ?? '').toString(),
                productName: (m['product_name'] ?? '').toString(),
                totalQty: _asDouble(m['total_qty']),
                totalRevenue: _asDouble(m['total_revenue']),
              );
            })
            .where((p) => p.productId.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint(
        '[DashboardRepository] get_top_products_for_range_v1 rpc error, falling back: $e',
      );
    }

    final orders = await _sb
        .from('orders')
        .select('id')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', from)
        .lt(
          'created_at',
          to,
        ); // ‼️ FIX: lt (exclusive) — caller truyền midnight ngày kế

    if (orders.isEmpty) return [];
    final orderIds = orders
        .map((o) => (o['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    // Batch orderIds in parallel chunks of 100 to prevent Postgrest URI limits and speed up fetch
    final List<Map<String, dynamic>> items = [];
    const chunkSize = 100;
    final futures = <Future<List<Map<String, dynamic>>>>[];
    for (int i = 0; i < orderIds.length; i += chunkSize) {
      final chunk = orderIds.sublist(
        i,
        (i + chunkSize).clamp(0, orderIds.length),
      );
      futures.add(
        _sb
            .from('order_items')
            .select('product_id, product_name, name, quantity, qty, subtotal')
            .inFilter('order_id', chunk),
      );
    }
    final results = await Future.wait(futures);
    for (final res in results) {
      items.addAll(res);
    }

    final map = <String, _ProductAgg>{};
    for (final item in items) {
      final productId = (item['product_id'] ?? '').toString();
      if (productId.isEmpty) continue;
      final agg = map[productId] ??= _ProductAgg(
        item['product_name'] as String? ?? item['name'] as String? ?? '',
      );
      // Fallback: quantity (extended col) → qty (legacy col)
      agg.qty +=
          (item['quantity'] as num?)?.toDouble() ??
          (item['qty'] as num?)?.toDouble() ??
          0;
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
        catMap[(p['id'] ?? '').toString()] = (p['category'] as String?) ?? '';
      }
    }

    var entries = map.entries.toList();
    if (category != null) {
      entries = entries.where((e) => catMap[e.key] == category).toList();
    }

    // ‼️ FIX Bug #35: ..take(limit) là Iterable không gán lại — limit vô hiệu
    // Fix: build → sort → sublist để đảm bảo limit đúng
    final sorted =
        entries
            .map(
              (e) => TopProduct(
                productId: e.key,
                productName: e.value.name,
                totalQty: e.value.qty,
                totalRevenue: e.value.revenue,
              ),
            )
            .toList()
          ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));
    return sorted.length > limit ? sorted.sublist(0, limit) : sorted;
  }

  // ── Compat methods — nhận int (ms) thay vì String ISO ────────────────────

  /// Report screen dùng int (millisecondsSinceEpoch) → chuyển sang ISO
  Future<DashboardStats> getStatsForRange(int from, int to) {
    if (to <= from) return Future.value(DashboardStats.empty);
    final f = DateTime.fromMillisecondsSinceEpoch(
      from,
    ).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();
    return _getStatsForRange(f, t);
  }

  Future<DashboardStats> _getStatsForRange(String from, String to) async {
    final storeId = await _storeId();
    if (storeId == null) return DashboardStats.empty;

    // Ưu tiên gọi RPC tổng hợp trực tiếp trên PostgreSQL (vượt ngưỡng 1000 đơn)
    try {
      final res = await _sb.rpc('get_report_stats_for_range_v1', params: {
        'p_store_id': storeId,
        'p_from': from,
        'p_to': to,
      });

      if (res is Map) {
        final data = Map<String, dynamic>.from(res);
        final totalOrders = _asInt(data['total_orders']);
        final totalRevenue = _asDouble(data['total_revenue']);
        final totalCustomers = _asInt(data['total_customers']);
        final avgOrderValue = data['avg_order_value'] != null
            ? _asDouble(data['avg_order_value'])
            : (totalOrders > 0 ? totalRevenue / totalOrders : 0.0);
        final cashRevenue = _asDouble(data['cash_revenue']);
        final transferRevenue = _asDouble(data['transfer_revenue']);
        final cardRevenue = _asDouble(data['card_revenue']);

        final cashierRevenue = <String, double>{};
        if (data['cashier_revenue'] is Map) {
          (data['cashier_revenue'] as Map).forEach((k, v) {
            cashierRevenue[k.toString()] = _asDouble(v);
          });
        }

        final cashierDetails = <String, CashierDetail>{};
        if (data['cashier_details'] is Map) {
          (data['cashier_details'] as Map).forEach((k, v) {
            if (v is Map) {
              cashierDetails[k.toString()] = CashierDetail(
                cash: _asDouble(v['cash']),
                transfer: _asDouble(v['transfer']),
                card: _asDouble(v['card']),
                total: _asDouble(v['total']),
              );
            }
          });
        }

        final waiterOrders = <String, int>{};
        if (data['waiter_orders'] is Map) {
          (data['waiter_orders'] as Map).forEach((k, v) {
            waiterOrders[k.toString()] = _asInt(v);
          });
        }

        return DashboardStats(
          todayRevenue: totalRevenue,
          todayOrders: totalOrders,
          todayCustomers: totalCustomers,
          avgOrderValue: avgOrderValue,
          cashRevenue: cashRevenue,
          transferRevenue: transferRevenue,
          cardRevenue: cardRevenue,
          cashierRevenue: cashierRevenue,
          waiterOrders: waiterOrders,
          cashierDetails: cashierDetails,
        );
      }
    } catch (e) {
      debugPrint(
        '[DashboardRepository] get_report_stats_for_range_v1 rpc error, falling back: $e',
      );
    }

    // Fallback tầng 2: Query và aggregate client-side khi RPC chưa có trên DB
    final orders = await _sb
        .from('orders')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', from)
        .lt(
          'created_at',
          to,
        ); // ‼️ FIX: lt (exclusive) — nhất quán với finance_repository
    final payments = await _loadCanonicalPayments(storeId, from, to);
    return _aggregateStats(orders, payments);
  }

  Future<List<Map<String, dynamic>>> _loadCanonicalPayments(
    String storeId,
    String from,
    String to,
  ) async {
    try {
      final financeRows = await _sb
          .from('finance_records')
          .select('amount, reference_id, fund_type')
          .eq('store_id', storeId)
          .eq('type', 'income')
          .eq('is_auto', true)
          .gte('recorded_at', from)
          .lt('recorded_at', to);
      final refs = financeRows
          .map((row) => row['reference_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (refs.isNotEmpty) {
        final settlements = await _sb
            .from('payment_settlements')
            .select('id, payment_method, cashier_staff_id')
            .eq('store_id', storeId)
            .eq('status', 'completed')
            .gte('created_at', from)
            .lt('created_at', to);
        final orders = await _sb
            .from('orders')
            .select('id, payment_method, staff_id')
            .eq('store_id', storeId)
            .eq('status', 'completed')
            .gte('created_at', from)
            .lt('created_at', to);
        final metadata = <String, Map<String, dynamic>>{
          for (final row in settlements)
            row['id'] as String: {
              'payment_method': row['payment_method'],
              'staff_id': row['cashier_staff_id'],
            },
          for (final row in orders)
            row['id'] as String: {
              'payment_method': row['payment_method'],
              'staff_id': row['staff_id'],
            },
        };

        // Bổ sung chunking 50 cho các refs chưa có trong dải ngày (phòng ngừa boundary lệch)
        final missingRefs = refs.where((r) => !metadata.containsKey(r)).toList();
        if (missingRefs.isNotEmpty) {
          const chunkSize = 50;
          for (int i = 0; i < missingRefs.length; i += chunkSize) {
            final chunk = missingRefs.sublist(
              i,
              (i + chunkSize).clamp(0, missingRefs.length),
            );
            try {
              final sChunk = await _sb
                  .from('payment_settlements')
                  .select('id, payment_method, cashier_staff_id')
                  .eq('store_id', storeId)
                  .inFilter('id', chunk);
              for (final row in sChunk) {
                metadata[row['id'] as String] = {
                  'payment_method': row['payment_method'],
                  'staff_id': row['cashier_staff_id'],
                };
              }
              final oChunk = await _sb
                  .from('orders')
                  .select('id, payment_method, staff_id')
                  .eq('store_id', storeId)
                  .inFilter('id', chunk);
              for (final row in oChunk) {
                metadata[row['id'] as String] = {
                  'payment_method': row['payment_method'],
                  'staff_id': row['staff_id'],
                };
              }
            } catch (_) {}
          }
        }

        final result = [
          for (final row in financeRows)
            if (metadata.containsKey(row['reference_id']))
              {...row, ...metadata[row['reference_id']]!},
        ];
        if (result.isNotEmpty) return result;
      }
    } catch (e) {
      debugPrint('[DashboardRepository] _loadCanonicalPayments finance error: $e');
    }

    // Fallback tầng 2: Query trực tiếp từ payment_settlements
    try {
      final settlements = await _sb
          .from('payment_settlements')
          .select('id, total_amount, payment_method, cashier_staff_id')
          .eq('store_id', storeId)
          .eq('status', 'completed')
          .gte('created_at', from)
          .lt('created_at', to);
      if (settlements.isNotEmpty) {
        return [
          for (final s in settlements)
            {
              'amount': s['total_amount'],
              'reference_id': s['id'],
              'fund_type': s['payment_method'] == 'cash' ? 'cash' : 'bank',
              'payment_method': s['payment_method'],
              'staff_id': s['cashier_staff_id'],
            },
        ];
      }
    } catch (e) {
      debugPrint('[DashboardRepository] _loadCanonicalPayments settlements fallback error: $e');
    }

    return const [];
  }

  Future<DashboardStats> _aggregateStats(
    List<dynamic> orders,
    List<Map<String, dynamic>> payments,
  ) async {
    // Fallback tầng 3: Nếu payments rỗng nhưng orders có dữ liệu -> tổng hợp từ orders
    final effectivePayments = List<Map<String, dynamic>>.from(payments);
    if (effectivePayments.isEmpty && orders.isNotEmpty) {
      for (final o in orders) {
        final amount = (o['total_amount'] as num?)?.toDouble() ??
            (o['total'] as num?)?.toDouble() ??
            0.0;
        final pm = o['payment_method'] as String? ?? 'cash';
        effectivePayments.add({
          'amount': amount,
          'reference_id': o['id'],
          'fund_type': pm == 'cash' ? 'cash' : 'bank',
          'payment_method': pm,
          'staff_id': o['staff_id'],
        });
      }
    }

    final revenue = effectivePayments.fold<double>(
      0,
      (sum, row) => sum + ((row['amount'] as num?)?.toDouble() ?? 0),
    );
    final orderCnt = orders.length;
    final customerSet = orders
        .where((o) =>
            o['customer_id'] != null &&
            (o['customer_id'] as String).trim().isNotEmpty)
        .map((o) => (o['customer_id'] as String).trim())
        .toSet();

    double cashRevenue = 0;
    double transferRevenue = 0;
    double cardRevenue = 0;
    final staffRevenuesRaw = <String, double>{};
    final staffDetailsRaw = <String, Map<String, double>>{};
    final waiterCountsRaw = <String, int>{};

    for (final payment in effectivePayments) {
      final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
      final rawMethod =
          payment['payment_method'] as String? ??
          (payment['fund_type'] == 'bank'
              ? 'transfer'
              : payment['fund_type'] as String? ?? 'cash');
      final String method;
      if (rawMethod == 'cash') {
        method = 'cash';
        cashRevenue += amount;
      } else if (rawMethod == 'card') {
        method = 'card';
        cardRevenue += amount;
      } else if (rawMethod == 'wallet') {
        method = 'wallet';
      } else {
        method = 'transfer';
        transferRevenue += amount;
      }

      final staffId = (payment['staff_id'] as String?)?.isNotEmpty == true
          ? payment['staff_id'] as String
          : 'unassigned';
      staffRevenuesRaw[staffId] = (staffRevenuesRaw[staffId] ?? 0) + amount;

      final details = staffDetailsRaw[staffId] ??= {
        'cash': 0,
        'transfer': 0,
        'card': 0,
        'total': 0,
      };
      details[method] = (details[method] ?? 0) + amount;
      details['total'] = (details['total'] ?? 0) + amount;
    }

    // Order chỉ dùng cho customer count, số order/món và nhân viên phục vụ.
    for (final o in orders) {
      final waiterId = o['waiter_id'] as String?;
      if (waiterId != null && waiterId.isNotEmpty) {
        waiterCountsRaw[waiterId] = (waiterCountsRaw[waiterId] ?? 0) + 1;
      }
    }

    final cashierRevenue = <String, double>{};
    final cashierDetails = <String, CashierDetail>{};

    if (staffRevenuesRaw.isNotEmpty) {
      try {
        final staffIds = staffRevenuesRaw.keys
            .where((id) => id != 'unassigned')
            .toList();
        final nameMap = <String, String>{'unassigned': 'Không rõ thu ngân'};

        if (staffIds.isNotEmpty) {
          final memberRows = await _sb
              .from('staff_members')
              .select('id, name')
              .inFilter('id', staffIds);

          for (final r in memberRows) {
            final id = r['id'] as String;
            nameMap[id] = (r['name'] as String?) ?? 'Chưa rõ';
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
          final name = staffId == 'unassigned'
              ? 'Không rõ thu ngân'
              : 'NV-${staffId.substring(0, 4)}';
          cashierRevenue[name] = val;
        });
        staffDetailsRaw.forEach((staffId, details) {
          final name = staffId == 'unassigned'
              ? 'Không rõ thu ngân'
              : 'NV-${staffId.substring(0, 4)}';
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
            .from('staff_members')
            .select('id, name')
            .inFilter('id', waiterIds);

        final nameMap = <String, String>{};
        for (final r in memberRows) {
          final id = r['id'] as String;
          nameMap[id] = (r['name'] as String?) ?? 'Chưa rõ';
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
    if (to <= from) return [];
    final storeId = await _storeId();
    if (storeId == null) return [];
    final f = DateTime.fromMillisecondsSinceEpoch(
      from,
    ).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();

    final dayMap = <String, _DayAgg>{};
    bool rpcSuccess = false;

    // Ưu tiên gọi RPC gom nhóm trực tiếp từ database (tránh giới hạn 1000 dòng PostgREST)
    try {
      final res = await _sb.rpc('get_daily_revenue_for_range_v1', params: {
        'p_store_id': storeId,
        'p_from': f,
        'p_to': t,
        'p_tz': 'Asia/Ho_Chi_Minh',
      });

      if (res is List) {
        for (final item in res) {
          if (item is! Map) continue;
          final dateStr =
              (item['report_date'] ?? item['date'])?.toString() ?? '';
          if (dateStr.isEmpty) continue;
          final dt = DateTime.tryParse(dateStr);
          if (dt == null) continue;
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          final agg = dayMap[key] ??= _DayAgg(dt);
          agg.revenue = _asDouble(item['total_revenue'] ?? item['revenue']);
          agg.orders = _asInt(item['total_orders'] ?? item['orders']);
          agg.cashRevenue = _asDouble(item['cash_revenue']);
          agg.transferRevenue = _asDouble(item['transfer_revenue']);
          agg.discount = _asDouble(item['total_discount'] ?? item['discount']);
        }
        rpcSuccess = true;
      }
    } catch (e) {
      debugPrint(
        '[DashboardRepository] get_daily_revenue_for_range_v1 rpc error, falling back: $e',
      );
    }

    if (!rpcSuccess) {
      // Fallback tầng 2: Query và gom nhóm client-side
      try {
        final orders = await _sb
            .from('orders')
            .select('created_at, total_amount, total, payment_method, discount')
            .eq('store_id', storeId)
            .eq('status', 'completed')
            .gte('created_at', f)
            .lt('created_at', t); // ‼️ FIX: lt (exclusive)
        for (final o in orders) {
          final dt =
              DateTime.tryParse(o['created_at'] as String? ?? '')?.toLocal();
          if (dt == null) continue;
          final key =
              '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
          final agg = dayMap[key] ??= _DayAgg(dt);

          final amount = _asDouble(o['total_amount'] ?? o['total']);
          final disc = _asDouble(o['discount']);
          final method = (o['payment_method'] as String? ?? 'cash').trim().toLowerCase();

          agg.revenue += amount;
          agg.orders++;
          agg.discount += disc;
          if (method == 'cash') {
            agg.cashRevenue += amount;
          } else if (method != 'wallet') {
            agg.transferRevenue += amount;
          }
        }
      } catch (e) {
        debugPrint('[DashboardRepository] getDailyRevenue fallback error: $e');
      }
    }

    // Fill tất cả ngày trong kỳ (kể cả những ngày 0đ)
    final startDate = DateTime.fromMillisecondsSinceEpoch(from);
    final endDate = DateTime.fromMillisecondsSinceEpoch(to);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    // Nếu endDate có thành phần giờ/phút/giây (ví dụ 23:59:59), thì ngày đó là ngày kết thúc bao gồm (inclusive).
    // Nếu endDate là đúng 00:00:00, nó đã là mốc chặn trên exclusive.
    final bool isExactMidnight = endDate.hour == 0 &&
        endDate.minute == 0 &&
        endDate.second == 0 &&
        endDate.millisecond == 0 &&
        endDate.microsecond == 0;
    final endDay = isExactMidnight
        ? DateTime(endDate.year, endDate.month, endDate.day)
        : DateTime(endDate.year, endDate.month, endDate.day + 1);

    if (!endDay.isAfter(startDay)) {
      return [];
    }

    final dayCount =
        ((endDay.millisecondsSinceEpoch - startDay.millisecondsSinceEpoch) /
                (24 * 3600 * 1000))
            .round();

    return List.generate(dayCount > 0 ? dayCount : 1, (i) {
      final day = DateTime(startDay.year, startDay.month, startDay.day + i);
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
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
    if (to <= from) return [];
    final storeId = await _storeId();
    if (storeId == null) return [];
    final f = DateTime.fromMillisecondsSinceEpoch(
      from,
    ).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();

    // Ưu tiên gọi RPC lấy danh mục trực tiếp từ database (loại bỏ N+1 query lặp và 1000 limit)
    try {
      final res = await _sb.rpc('get_sold_categories_for_range_v1', params: {
        'p_store_id': storeId,
        'p_from': f,
        'p_to': t,
      });

      if (res is List) {
        return res
            .map((row) => (row is Map ? row['category'] : row)?.toString() ?? '')
            .where((c) => c.trim().isNotEmpty)
            .toSet()
            .toList()
          ..sort();
      }
    } catch (e) {
      debugPrint(
        '[DashboardRepository] get_sold_categories_for_range_v1 rpc error, falling back: $e',
      );
    }

    final orders = await _sb
        .from('orders')
        .select('id')
        .eq('store_id', storeId)
        .eq('status', 'completed')
        .gte('created_at', f)
        .lt('created_at', t); // ‼️ FIX: lt (exclusive)
    if (orders.isEmpty) return [];
    final orderIds = orders
        .map((o) => (o['id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toList();

    final List<Map<String, dynamic>> items = [];
    const chunkSize = 100;
    final futures = <Future<List<Map<String, dynamic>>>>[];
    for (int i = 0; i < orderIds.length; i += chunkSize) {
      final chunk = orderIds.sublist(
        i,
        (i + chunkSize).clamp(0, orderIds.length),
      );
      futures.add(
        _sb
            .from('order_items')
            .select('product_id')
            .inFilter('order_id', chunk),
      );
    }
    final results = await Future.wait(futures);
    for (final res in results) {
      items.addAll(res);
    }

    final productIds = items
        .map((i) => (i['product_id'] ?? '').toString())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (productIds.isEmpty) return [];
    final products = await _sb
        .from('products')
        .select('category')
        .inFilter('id', productIds);
    return products
        .map((p) => (p['category'] ?? '').toString())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }

  // Thêm category filter cho getTopProductsForRange compat
  Future<List<TopProduct>> getTopProductsForRangeCompat(
    int from,
    int to, {
    String? category,
    int limit = 10,
  }) async {
    if (to <= from) return [];
    final f = DateTime.fromMillisecondsSinceEpoch(
      from,
    ).toUtc().toIso8601String();
    final t = DateTime.fromMillisecondsSinceEpoch(to).toUtc().toIso8601String();
    // ‼️ FIX: truyền category xuống getTopProductsForRange — trước đây bị drop silently
    return getTopProductsForRange(f, t, category: category, limit: limit);
  }

  // ── Doanh thu 7 ngày gần nhất ────────────────────────────────────────────

  Future<List<DailyRevenue>> getLast7DaysRevenue() async {
    final now = DateTime.now();
    final fromDate = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final toDate = DateTime(
      now.year,
      now.month,
      now.day + 1,
    );
    return getDailyRevenue(
      fromDate.millisecondsSinceEpoch,
      toDate.millisecondsSinceEpoch,
    );
  }

  // ── Hourly revenue hôm nay ────────────────────────────────────────────────

  Future<List<HourlyRevenue>> getHourlyRevenue(DateTime date) async {
    try {
      final storeId = await _storeId();
      if (storeId == null) return _emptyHourly();

      final startOfDay = DateTime(
        date.year,
        date.month,
        date.day,
      ).toUtc().toIso8601String();
      // Dùng midnight ngày kế (exclusive) — 23:59:59 bỏ sót 23:59:59.001 – 23:59:59.999
      final endOfDay = DateTime(
        date.year,
        date.month,
        date.day + 1,
      ).toUtc().toIso8601String();

      final orders = await _sb
          .from('orders')
          .select('created_at, total_amount')
          .eq('store_id', storeId)
          .eq('status', 'completed')
          .gte('created_at', startOfDay)
          .lt('created_at', endOfDay); // exclusive upper — nhất quán với finance

      final hourMap = <int, _HourAgg>{};
      for (final o in orders) {
        final dt = DateTime.tryParse(o['created_at'] as String? ?? '')?.toLocal();
        if (dt == null) continue;
        final agg = hourMap[dt.hour] ??= _HourAgg();
        agg.revenue += (o['total_amount'] as num?)?.toDouble() ?? 0;
        agg.orders++;
      }
      return List.generate(24, (h) {
        final agg = hourMap[h] ?? _HourAgg();
        return HourlyRevenue(hour: h, revenue: agg.revenue, orders: agg.orders);
      });
    } catch (e) {
      debugPrint('[DashboardRepository] getHourlyRevenue error: $e');
      return _emptyHourly();
    }
  }

  List<HourlyRevenue> _emptyHourly() =>
      List.generate(24, (h) => HourlyRevenue(hour: h, revenue: 0, orders: 0));
}

// ── Private helpers ────────────────────────────────────────────────────────────
class _ProductAgg {
  final String name;
  double qty = 0;
  double revenue = 0;
  _ProductAgg(this.name);
}

class _DayAgg {
  DateTime date;
  double revenue = 0;
  int orders = 0;
  double cashRevenue = 0;
  double transferRevenue = 0;
  double discount = 0;
  _DayAgg(this.date);
}

class _HourAgg {
  double revenue = 0;
  int orders = 0;
}

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
  final int todayOrders;
  final int todayCustomers;
  final double avgOrderValue;
  final double cashRevenue;
  final double transferRevenue;
  final double cardRevenue;
  final Map<String, double> cashierRevenue;
  final Map<String, int> waiterOrders;
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
    todayRevenue: 0,
    todayOrders: 0,
    todayCustomers: 0,
    avgOrderValue: 0,
    cashRevenue: 0,
    transferRevenue: 0,
    cardRevenue: 0,
    cashierRevenue: {},
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
    required this.productId,
    required this.productName,
    required this.totalQty,
    required this.totalRevenue,
  });
}

class DailyRevenue {
  final DateTime date;
  final double revenue;
  final int orders;
  final double cashRevenue;
  final double transferRevenue;
  final double discount;

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
  final int hour;
  final double revenue;
  final int orders;
  const HourlyRevenue({
    required this.hour,
    required this.revenue,
    required this.orders,
  });
}
