import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CỔNG THU PHÍ (đợt A) — Chủ quán xem gói, tạo đơn thanh toán, hỏi trạng thái đơn
// (migration 20261028_cong_thu_phi_dot_a.sql). Giá, mã chuyển khoản, số tiền luôn do máy chủ quyết.
// Chỉ gọi từ màn chạy ở nơi được thu phí (billingAllowedHere()).
// ─────────────────────────────────────────────────────────────────────────────

class BillingException implements Exception {
  final String code;
  const BillingException(this.code);

  String get message => switch (code) {
    'OWNER_ONLY' => 'Chỉ Chủ quán mới quản lý được gói.',
    'BANK_NOT_SET' => 'Quán Nhỏ chưa mở thanh toán. Vui lòng quay lại sau.',
    'BAD_PLAN' => 'Gói này hiện không còn bán.',
    'TOO_MANY' => 'Bạn đã tạo quá nhiều đơn trong 1 giờ. Vui lòng thử lại sau.',
    'NOT_FOUND' => 'Không tìm thấy đơn thanh toán.',
    'NETWORK' => 'Không kết nối được máy chủ. Vui lòng kiểm tra mạng.',
    _ => 'Có lỗi xảy ra ($code). Vui lòng thử lại.',
  };

  @override
  String toString() => 'BillingException($code)';
}

DateTime? _dt(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
int _i(Object? v) => (v as num?)?.toInt() ?? 0;

class BillingPlan {
  final String code;
  final String name;
  final int months;
  final int priceVnd;
  const BillingPlan({required this.code, required this.name, required this.months, required this.priceVnd});

  factory BillingPlan.fromMap(Map<String, dynamic> m) => BillingPlan(
    code: m['code'] as String? ?? '',
    name: m['name'] as String? ?? '',
    months: _i(m['months']),
    priceVnd: _i(m['price_vnd']),
  );

  int get pricePerMonth => months > 0 ? (priceVnd / months).round() : priceVnd;
}

class BillingBank {
  final String bin;
  final String bankName;
  final String accountNo;
  final String accountName;
  const BillingBank({required this.bin, required this.bankName, required this.accountNo, required this.accountName});

  static BillingBank? fromMap(Object? m) {
    if (m is! Map) return null;
    final bin = m['bin'], no = m['account_no'];
    if (bin is! String || no is! String) return null;
    return BillingBank(
      bin: bin,
      bankName: m['bank_name'] as String? ?? '',
      accountNo: no,
      accountName: m['account_name'] as String? ?? '',
    );
  }
}

class BillingOrder {
  final String id;
  final String code;
  final String planName;
  final int months;
  final int amountVnd;
  final String status; // pending | paid | cancelled | expired
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final DateTime? paidAt;
  const BillingOrder({
    required this.id,
    required this.code,
    required this.planName,
    required this.months,
    required this.amountVnd,
    required this.status,
    this.createdAt,
    this.expiresAt,
    this.paidAt,
  });

  factory BillingOrder.fromMap(Map<String, dynamic> m) => BillingOrder(
    id: m['id'] as String? ?? '',
    code: m['code'] as String? ?? '',
    planName: m['plan_name'] as String? ?? '',
    months: _i(m['months']),
    amountVnd: _i(m['amount_vnd']),
    status: m['status'] as String? ?? 'pending',
    createdAt: _dt(m['created_at']),
    expiresAt: _dt(m['expires_at']),
    paidAt: _dt(m['paid_at']),
  );

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
}

class BillingInfo {
  final String storeName;
  final String plan;
  final String status;
  final DateTime? trialEndsAt;
  final DateTime? planEndsAt;
  final List<BillingPlan> plans;
  final BillingBank? bank;
  final BillingOrder? pending;
  final List<BillingOrder> history;
  const BillingInfo({
    required this.storeName,
    required this.plan,
    required this.status,
    this.trialEndsAt,
    this.planEndsAt,
    required this.plans,
    this.bank,
    this.pending,
    required this.history,
  });

  factory BillingInfo.fromMap(Map<String, dynamic> m) {
    final st = Map<String, dynamic>.from(m['store'] as Map? ?? const {});
    List<Map<String, dynamic>> list(Object? v) =>
        v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
    return BillingInfo(
      storeName: st['name'] as String? ?? '',
      plan: st['plan'] as String? ?? 'free',
      status: st['status'] as String? ?? 'trial',
      trialEndsAt: _dt(st['trial_ends_at']),
      planEndsAt: _dt(st['plan_ends_at']),
      plans: list(m['plans']).map(BillingPlan.fromMap).toList(),
      bank: BillingBank.fromMap(m['bank']),
      pending: m['pending'] is Map ? BillingOrder.fromMap(Map<String, dynamic>.from(m['pending'] as Map)) : null,
      history: list(m['history']).map(BillingOrder.fromMap).toList(),
    );
  }

  bool get isPro => plan == 'pro';
}

class BillingRepository {
  final SupabaseClient? client;
  final Future<dynamic> Function(String fn, Map<String, dynamic> params)? rpcOverride;
  const BillingRepository({this.client, this.rpcOverride});

  Future<Map<String, dynamic>> _call(String fn, Map<String, dynamic> params) async {
    dynamic res;
    try {
      res = rpcOverride != null
          ? await rpcOverride!(fn, params)
          : await (client ?? Supabase.instance.client).rpc(fn, params: params);
    } catch (_) {
      throw const BillingException('NETWORK');
    }
    if (res is! Map) throw const BillingException('ERROR');
    final m = Map<String, dynamic>.from(res);
    if (m['ok'] != true) throw BillingException(m['error'] as String? ?? 'ERROR');
    return m;
  }

  Future<BillingInfo> info(String storeId) async =>
      BillingInfo.fromMap(await _call('billing_info_v1', {'p_store': storeId}));

  Future<BillingOrder> createOrder(String storeId, String planCode) async {
    final m = await _call('billing_create_order_v1', {'p_store': storeId, 'p_plan': planCode});
    return BillingOrder.fromMap(Map<String, dynamic>.from(m['order'] as Map));
  }

  Future<BillingOrder> orderStatus(String orderId) async {
    final m = await _call('billing_order_status_v1', {'p_order': orderId});
    return BillingOrder.fromMap(Map<String, dynamic>.from(m['order'] as Map));
  }
}
