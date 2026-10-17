import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAIN REPOSITORY — chuỗi cửa hàng của Chủ quán + báo cáo tổng hợp.
// Mọi ghi/đọc đi qua RPC (migration 20261017_chuoi_cua_hang_v1.sql); server kiểm quyền Chủ quán.
// Báo cáo chuỗi chỉ là lớp đọc tổng hợp: dữ liệu vận hành vẫn tách theo store_id.
// ─────────────────────────────────────────────────────────────────────────────

class ChainException implements Exception {
  final String code;
  const ChainException(this.code);

  /// Câu thông báo tiếng Việt cho mã lỗi server.
  String get message => switch (code) {
    'UNAUTHENTICATED' => 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
    'OWNER_ONLY' => 'Chỉ Chủ quán mới tạo được chuỗi.',
    'STORE_OWNER_ONLY' => 'Bạn không phải Chủ của cửa hàng này.',
    'CHAIN_NOT_FOUND' => 'Không tìm thấy chuỗi hoặc bạn không phải chủ chuỗi.',
    'STORE_ALREADY_IN_CHAIN' => 'Cửa hàng này đã thuộc một chuỗi khác.',
    'STORE_NOT_IN_CHAIN' => 'Cửa hàng này không còn trong chuỗi.',
    'DUPLICATE_NAME' => 'Bạn đã có chuỗi trùng tên này.',
    'INVALID_NAME' => 'Tên chuỗi phải từ 1 đến 80 ký tự.',
    'TOO_MANY_CHAINS' => 'Đã đạt số chuỗi tối đa.',
    'CHAIN_FULL' => 'Chuỗi đã đạt số cửa hàng tối đa.',
    'INVALID_RANGE' => 'Khoảng thời gian không hợp lệ.',
    _ => 'Có lỗi xảy ra ($code). Vui lòng thử lại.',
  };

  @override
  String toString() => 'ChainException($code)';
}

double _d(Object? v) => (v as num?)?.toDouble() ?? 0;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class ChainStoreRef {
  final String storeId;
  final String name;
  final String storeCode;
  const ChainStoreRef({required this.storeId, required this.name, required this.storeCode});

  factory ChainStoreRef.fromJson(Map<dynamic, dynamic> j) => ChainStoreRef(
    storeId: j['store_id'] as String,
    name: j['name'] as String? ?? '',
    storeCode: j['store_code'] as String? ?? '',
  );
}

class StoreChain {
  final String id;
  final String name;
  final List<ChainStoreRef> stores;
  const StoreChain({required this.id, required this.name, required this.stores});

  factory StoreChain.fromJson(Map<dynamic, dynamic> j) => StoreChain(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    stores: [
      for (final s in (j['stores'] as List? ?? const [])) ChainStoreRef.fromJson(s as Map),
    ],
  );
}

class OwnedStore {
  final String storeId;
  final String name;
  final String storeCode;
  final String? chainId;
  const OwnedStore({required this.storeId, required this.name, required this.storeCode, this.chainId});

  factory OwnedStore.fromJson(Map<dynamic, dynamic> j) => OwnedStore(
    storeId: j['store_id'] as String,
    name: j['name'] as String? ?? '',
    storeCode: j['store_code'] as String? ?? '',
    chainId: j['chain_id'] as String?,
  );
}

class MyChains {
  final List<StoreChain> chains;
  final List<OwnedStore> ownedStores;
  const MyChains({this.chains = const [], this.ownedStores = const []});

  /// Chủ quán chỉ cần thấy mục chuỗi khi có ít nhất 2 cửa hàng hoặc đã có chuỗi.
  bool get worthShowing => chains.isNotEmpty || ownedStores.length >= 2;

  factory MyChains.fromJson(Map<dynamic, dynamic> j) => MyChains(
    chains: [for (final c in (j['chains'] as List? ?? const [])) StoreChain.fromJson(c as Map)],
    ownedStores: [for (final s in (j['owned_stores'] as List? ?? const [])) OwnedStore.fromJson(s as Map)],
  );
}

double? _dn(Object? v) => v is num ? v.toDouble() : null;
int? _in(Object? v) => v is num ? v.toInt() : null;

class StoreMetrics {
  final String storeId;
  final String name;
  final String storeCode;
  final int orders;
  final double revenue;
  final double avgOrderValue;
  final double cashRevenue;
  final double transferRevenue;
  final double cardRevenue;
  final double discount;

  // ── Trường mới (migration 20261018). null = máy chủ chưa gửi → "không rõ", tuyệt đối KHÔNG coi là 0. ──
  /// Doanh thu trước giảm giá (= doanh thu + giảm giá).
  final double? grossRevenue;
  final double? walletRevenue;
  final int? voidCount;
  final double? voidAmount;

  /// Đơn hoàn tất đầu tiên của quán (toàn thời gian). null + [firstOrderKnown] = quán CHƯA TỪNG có đơn.
  final DateTime? firstOrderAt;
  final bool firstOrderKnown;

  const StoreMetrics({
    required this.storeId,
    required this.name,
    this.storeCode = '',
    this.orders = 0,
    this.revenue = 0,
    this.avgOrderValue = 0,
    this.cashRevenue = 0,
    this.transferRevenue = 0,
    this.cardRevenue = 0,
    this.discount = 0,
    this.grossRevenue,
    this.walletRevenue,
    this.voidCount,
    this.voidAmount,
    this.firstOrderAt,
    this.firstOrderKnown = false,
  });

  factory StoreMetrics.fromJson(Map<dynamic, dynamic> j) => StoreMetrics(
    storeId: j['store_id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    storeCode: j['store_code'] as String? ?? '',
    orders: _i(j['orders']),
    revenue: _d(j['revenue']),
    avgOrderValue: _d(j['avg_order_value']),
    cashRevenue: _d(j['cash_revenue']),
    transferRevenue: _d(j['transfer_revenue']),
    cardRevenue: _d(j['card_revenue']),
    discount: _d(j['discount']),
    grossRevenue: _dn(j['gross_revenue']),
    walletRevenue: _dn(j['wallet_revenue']),
    voidCount: _in(j['void_count']),
    voidAmount: _dn(j['void_amount']),
    firstOrderKnown: j.containsKey('first_order_at'),
    firstOrderAt: DateTime.tryParse(j['first_order_at'] as String? ?? '')?.toLocal(),
  );
}

class ChainDailyPoint {
  final String date; // yyyy-MM-dd theo múi giờ báo cáo
  final String storeId;
  final int orders;
  final double revenue;
  const ChainDailyPoint({required this.date, required this.storeId, required this.orders, required this.revenue});

  factory ChainDailyPoint.fromJson(Map<dynamic, dynamic> j) => ChainDailyPoint(
    date: j['date'] as String? ?? '',
    storeId: j['store_id'] as String? ?? '',
    orders: _i(j['orders']),
    revenue: _d(j['revenue']),
  );
}

class ChainReport {
  final String chainId;
  final String chainName;
  final List<StoreMetrics> stores;
  final StoreMetrics totals;
  final int storeCount;
  final List<ChainDailyPoint> daily;
  final List<ChainStoreRef> excluded;

  const ChainReport({
    required this.chainId,
    required this.chainName,
    required this.stores,
    required this.totals,
    required this.storeCount,
    required this.daily,
    required this.excluded,
  });

  factory ChainReport.fromJson(Map<dynamic, dynamic> j) {
    final chain = (j['chain'] as Map?) ?? const {};
    final totals = (j['totals'] as Map?) ?? const {};
    return ChainReport(
      chainId: chain['id'] as String? ?? '',
      chainName: chain['name'] as String? ?? '',
      stores: [for (final s in (j['stores'] as List? ?? const [])) StoreMetrics.fromJson(s as Map)],
      totals: StoreMetrics.fromJson({...totals, 'name': 'Tổng'}),
      storeCount: _i(totals['store_count']),
      daily: [for (final p in (j['daily'] as List? ?? const [])) ChainDailyPoint.fromJson(p as Map)],
      excluded: [for (final s in (j['excluded_stores'] as List? ?? const [])) ChainStoreRef.fromJson(s as Map)],
    );
  }

  /// Tổng doanh thu theo ngày (gộp các cửa hàng), tăng dần theo ngày.
  List<MapEntry<String, double>> get dailyTotals {
    final m = <String, double>{};
    for (final p in daily) {
      m[p.date] = (m[p.date] ?? 0) + p.revenue;
    }
    final keys = m.keys.toList()..sort();
    return [for (final k in keys) MapEntry(k, m[k]!)];
  }
}

class ChainRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  /// Dùng trong test để không cần Supabase thật.
  static Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpcOverride;

  Future<Map<dynamic, dynamic>> _call(String fn, Map<String, dynamic> params) async {
    final res = rpcOverride != null ? await rpcOverride!(fn, params) : await _sb.rpc(fn, params: params);
    if (res is! Map) throw const ChainException('GATEWAY_UNAVAILABLE');
    if (res['success'] != true) {
      throw ChainException((res['error'] as String?) ?? 'UNKNOWN');
    }
    return res;
  }

  Future<MyChains> listMine() async => MyChains.fromJson(await _call('list_my_chains_v1', {}));

  Future<String> createChain(String name) async {
    final r = await _call('create_store_chain_v1', {'p_name': name});
    return r['chain_id'] as String;
  }

  Future<void> addStore(String chainId, String storeId) =>
      _call('add_store_to_chain_v1', {'p_chain': chainId, 'p_store': storeId});

  Future<void> removeStore(String chainId, String storeId) =>
      _call('remove_store_from_chain_v1', {'p_chain': chainId, 'p_store': storeId});

  /// [from, to) tính theo giờ máy; gửi UTC ISO-8601.
  Future<ChainReport> report(String chainId, DateTime from, DateTime to) async {
    final r = await _call('get_chain_report_v1', {
      'p_chain': chainId,
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });
    return ChainReport.fromJson(r);
  }
}
