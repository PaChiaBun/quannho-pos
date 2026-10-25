import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/staff_service.dart'
    show StaffService, kDefaultPerms;
import '../../../core/utils/paged_query.dart';
import 'boom_read_only_data_service.dart' show BoomPeriodRange;

/// Cổng CHỈ ĐỌC số liệu các module cho AI Boom (Chủ Quán 25/10: "cho Boom đọc và không cho thêm số liệu vào").
///
/// File này cố ý chỉ dùng `select()` — không ghi, không gọi RPC (test `boom_read_only_guard_test` quét cả file).
/// Không đọc số điện thoại, email, ghi chú, ảnh / GPS chấm công. Quyền xem kiểm ở [boomModuleAccess] (máy chủ
/// chỉ chặn theo quán, không theo vai trò — nhân viên thường vẫn đọc được bảng tiền qua API).
enum BoomModule { finance, kho, nhanSu, khach, khuyenMai }

/// Tên hiển thị trong câu trả lời / câu từ chối.
const kBoomModuleNames = {
  BoomModule.finance: 'Thu Chi',
  BoomModule.kho: 'Kho hàng',
  BoomModule.nhanSu: 'Chấm công / Lương',
  BoomModule.khach: 'Khách hàng',
  BoomModule.khuyenMai: 'Khuyến mãi',
};

/// Module bật mặc định khi quán chưa lưu cấu hình (như `_kAllModules` của ModuleRepository).
const kBoomDefaultActiveModules = {'pos', 'report', 'finance', 'kho'};

/// Quyền của người hỏi ở quán đang mở — đọc lại từ máy chủ mỗi lần (không tin vai trò lưu trên máy).
class BoomPerms {
  const BoomPerms({
    required this.isOwner,
    required this.canonicalRole,
    required this.modules,
    required this.active,
  });
  final bool isOwner;
  final String canonicalRole;
  final List<String> modules;
  final Set<String> active;
  bool get boss => isOwner || canonicalRole == 'owner';
  bool get manager => boss || canonicalRole == 'manager';
  bool on(String id) => active.contains(id);
  bool has(String id) => boss || modules.contains(id);
  bool can(String id) => on(id) && has(id);
}

/// Quyền xem từng module — giống app: chủ quán xem hết; còn lại theo danh sách module của vai trò và module đang bật.
/// Nhân sự: chủ / quản lý xem cả quán; người khác chỉ xem giờ làm của CHÍNH mình ('self'). Kho: nhân viên không thấy
/// tiền ('no_cost').
String? boomModuleAccess(BoomModule m, BoomPerms p) {
  switch (m) {
    case BoomModule.finance:
      return p.can('finance') ? 'all' : null;
    case BoomModule.kho:
      return p.can('kho') || p.can('kho_pro')
          ? (p.manager ? 'all' : 'no_cost')
          : null;
    case BoomModule.nhanSu:
      if (p.manager && (p.on('chamcong') || p.on('tinhluong'))) return 'all';
      return p.can('chamcong') || p.can('tinhluong') ? 'self' : null;
    case BoomModule.khach:
      return p.can('loyalty') || (p.manager && p.on('loyalty')) ? 'all' : null;
    case BoomModule.khuyenMai:
      return p.can('loyalty') ||
              p.can('report') ||
              (p.manager && (p.on('loyalty') || p.on('report')))
          ? 'all'
          : null;
  }
}

/// Số bán hàng (doanh thu, món bán chạy) — như màn Báo cáo.
bool boomCanSeeSales(BoomPerms p) => p.manager || p.can('report');

/// Hàng sắp hết — như màn Kho.
bool boomCanSeeStock(BoomPerms p) => p.can('kho') || p.can('kho_pro');

/// Ai đang trong ca — chủ / quản lý (nhân viên thường chỉ xem ca của mình ở màn Chấm công).
bool boomCanSeeShifts(BoomPerms p) => p.manager;

/// Đọc danh sách module như `StaffService._parseModules`: mảng JSON, chuỗi JSON, hoặc "[ban,kitchen]" / "ban,kitchen".
List<String> boomParseModules(Object? v) {
  if (v == null) return const [];
  if (v is List) return [for (final x in v) '$x'];
  final str = '$v'.trim();
  if (str.isEmpty) return const [];
  try {
    final d = jsonDecode(str);
    if (d is List) return [for (final x in d) '$x'];
  } catch (_) {}
  return str
      .replaceAll(RegExp(r'''[\[\]"']'''), '')
      .split(',')
      .map((x) => x.trim())
      .where((x) => x.isNotEmpty)
      .toList();
}

/// Quyết định quyền từ dữ liệu đã đọc — CÙNG thứ tự với app (`StaffService.getModulePermissions`): vai trò của quán
/// (danh sách rỗng = chưa đặt, đi tiếp) → gán riêng từng người → cài đặt cũ `perm_<vai trò>` → mặc định theo loại vai trò.
/// [member] null (không còn là thành viên) → ném lỗi.
BoomPerms resolveBoomPerms({
  required Map<String, dynamic>? member,
  required List<Map<String, dynamic>> settings,
  required List<Map<String, dynamic>> roles,
  required Map<String, dynamic>? staff,
}) {
  if (member == null) throw StateError('NOT_MEMBER');
  final role = '${member['role'] ?? ''}'.trim();
  final canonical = StaffService.canonicalRole(role);
  final isOwner = member['is_owner'] == true || canonical == 'owner';
  // Vai trò trống → không quyền gì (như getEffectiveActionPermissions), không khớp nhầm vai trò tên trống
  if (role.isEmpty && !isOwner) throw StateError('NO_ROLE');
  String? setting(String k) {
    for (final r in settings) {
      if (r['key'] == k && r['value'] != null) return '${r['value']}';
    }
    return null;
  }

  final cfg = setting('module_config_v2');
  final active = cfg == null
      ? kBoomDefaultActiveModules
      : boomParseModules(cfg).toSet();
  List<String>? mods;
  if (!isOwner) {
    for (final pass in [0, 1, 2]) {
      for (final r in roles) {
        final n = '${r['name'] ?? ''}'.trim();
        final hit = switch (pass) {
          0 => n == role,
          1 => n.toLowerCase() == role.toLowerCase(),
          _ => StaffService.canonicalRole(n) == canonical,
        };
        final m = hit ? boomParseModules(r['modules']) : const <String>[];
        if (m.isNotEmpty) {
          mods = m;
          break;
        }
      }
      if (mods != null) break;
    }
    if (mods == null) {
      final own = boomParseModules(staff?['modules']);
      if (own.isNotEmpty) mods = own;
    }
    if (mods == null) {
      for (final k in ['perm_$role', 'perm_$canonical']) {
        final m = boomParseModules(setting(k));
        if (m.isNotEmpty) {
          mods = m;
          break;
        }
      }
    }
    mods ??= List<String>.from(kDefaultPerms[canonical] ?? const []);
  }
  return BoomPerms(
    isOwner: isOwner,
    canonicalRole: canonical,
    modules: mods ?? const [],
    active: active,
  );
}

class BoomModuleDataService {
  BoomModuleDataService(this._db);

  final SupabaseClient _db;

  String _iso(DateTime d) => d.toUtc().toIso8601String();

  /// Quyền của [userId] ở [storeId], đọc CHẶT (lỗi → ném lỗi, nơi gọi coi là không có quyền):
  /// vai trò từ `store_members` (không tin vai trò lưu trên máy); module theo đúng thứ tự của app
  /// (`StaffService.getModulePermissions`, xem [resolveBoomPerms]) nhưng KHÔNG nuốt lỗi; module đang bật đọc
  /// `app_settings` (KHÔNG dùng ModuleRepository.getAll — hàm đó có thể ghi cấu hình lần đầu).
  Future<BoomPerms> perms(String storeId, String userId) async {
    final member = await _db
        .from('store_members')
        .select('role,is_owner')
        .eq('store_id', storeId)
        .eq('user_id', userId)
        .maybeSingle();
    final role = '${member?['role'] ?? ''}'.trim();
    final canonical = StaffService.canonicalRole(role);
    final res = await Future.wait<dynamic>([
      _db
          .from('app_settings')
          .select('key,value')
          .eq('store_id', storeId)
          .inFilter('key', [
            'module_config_v2',
            'perm_$role',
            'perm_$canonical',
          ]),
      _db.from('store_roles').select('name,modules').eq('store_id', storeId),
      // Gán riêng từng người: đọc lỗi → bỏ qua như app (không làm hỏng cả quyền của chủ quán)
      _db
          .from('staff_members')
          .select('modules')
          .eq('store_id', storeId)
          .eq('id', userId)
          .maybeSingle()
          .then<Map<String, dynamic>?>((r) => r, onError: (_) => null),
    ]);
    return resolveBoomPerms(
      member: member,
      settings: (res[0] as List).cast<Map<String, dynamic>>(),
      roles: (res[1] as List).cast<Map<String, dynamic>>(),
      staff: res[2] as Map<String, dynamic>?,
    );
  }

  // ── Thu Chi ────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> finance(
    String storeId,
    BoomPeriodRange r,
  ) async {
    Future<List<Map<String, dynamic>>> rows(
      DateTime a,
      DateTime b,
    ) => fetchAllPages(
      (o, e) => _db
          .from('finance_records')
          .select('id,type,amount,category_id,fund_type,is_auto')
          .eq('store_id', storeId)
          .gte('recorded_at', _iso(a))
          .lt('recorded_at', _iso(b))
          // Quỹ ví khách không phải tiền vào quán (đã ghi thu lúc nạp) — như sổ Thu Chi
          .or('fund_type.is.null,fund_type.neq.wallet')
          .order('id')
          .range(o, e),
    );
    final res = await Future.wait([
      rows(r.start, r.end),
      rows(r.prevStart, r.prevEnd),
      _db.from('finance_categories').select('id,name').eq('store_id', storeId),
    ]);
    return boomFinanceFacts(
      rows: res[0],
      prevRows: res[1],
      categories: res[2],
      period: r.label,
      prevPeriod: r.prevLabel,
    );
  }

  // ── Kho ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> kho(
    String storeId,
    BoomPeriodRange r, {
    required bool withCost,
  }) async {
    final res = await Future.wait([
      fetchAllPages(
        (o, e) => _db
            .from('products')
            .select(
              'id,name,unit,product_type,stock_qty,min_stock,cost_price,cost_price_latest,is_active',
            )
            .eq('store_id', storeId)
            .not('is_deleted', 'is', true)
            .order('id')
            .range(o, e),
      ),
      fetchAllPages(
        (o, e) => _db
            .from('purchase_orders')
            .select('id,supplier_name,status,total_cost,total_amount')
            .eq('store_id', storeId)
            .gte('created_at', _iso(r.start))
            .lt('created_at', _iso(r.end))
            .order('id')
            .range(o, e),
      ),
      fetchAllPages(
        (o, e) => _db
            .from('stock_movements')
            .select('id,product_id,delta,reason')
            .eq('store_id', storeId)
            .inFilter('reason', kBoomWasteReasons.toList())
            .gte('created_at', _iso(r.start))
            .lt('created_at', _iso(r.end))
            .order('id')
            .range(o, e),
      ),
    ]);
    return boomKhoFacts(
      products: res[0],
      purchases: res[1],
      waste: res[2],
      period: r.label,
      withCost: withCost,
    );
  }

  // ── Chấm công / Lương ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> nhanSu(
    String storeId,
    BoomPeriodRange r, {
    String? onlyUserId,
  }) async {
    final shifts = await fetchAllPages((o, e) {
      var q = _db
          .from('staff_shifts')
          .select('id,user_id,clock_in,clock_out')
          .eq('store_id', storeId)
          .gte('clock_in', _iso(r.start))
          .lt('clock_in', _iso(r.end));
      if (onlyUserId != null) q = q.eq('user_id', onlyUserId);
      return q.order('id').range(o, e);
    });
    final ids = {
      for (final s in shifts)
        if (s['user_id'] is String) s['user_id'] as String,
    };
    // Tên như màn Chấm công (staff_members.name); user_accounts không mở quyền đọc cho app
    final users = ids.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _db
              .from('staff_members')
              .select('id,name')
              .eq('store_id', storeId)
              .inFilter('id', ids.toList());
    // Kỳ lương gần nhất (chỉ chủ / quản lý)
    final periods = onlyUserId != null
        ? const <Map<String, dynamic>>[]
        : await _db
              .from('payroll_periods')
              .select('name,status,total_amount,from_date,to_date')
              .eq('store_id', storeId)
              .order('from_date', ascending: false)
              .limit(2);
    return boomNhanSuFacts(
      shifts: shifts,
      users: users,
      payroll: periods,
      period: r.label,
      now: DateTime.now(),
      self: onlyUserId != null,
    );
  }

  // ── Khách hàng ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> khach(String storeId, BoomPeriodRange r) async {
    PostgrestFilterBuilder<List<Map<String, dynamic>>> base() => _db
        .from('customers')
        .select('id')
        .eq('store_id', storeId)
        .not('is_deleted', 'is', true);
    final res = await Future.wait<dynamic>([
      base().count(CountOption.exact),
      base()
          .gte('created_at', _iso(r.start))
          .lt('created_at', _iso(r.end))
          .count(CountOption.exact),
      base().gte('visit_count', 2).count(CountOption.exact),
      _db
          .from('customers')
          .select('name,total_spent,visit_count')
          .eq('store_id', storeId)
          .not('is_deleted', 'is', true)
          .order('total_spent', ascending: false)
          .limit(5),
      fetchAllPages(
        (o, e) => _db
            .from('customers')
            .select('id,real_balance,bonus_balance')
            .eq('store_id', storeId)
            .not('is_deleted', 'is', true)
            .or('real_balance.gt.0,bonus_balance.gt.0')
            .order('id')
            .range(o, e),
      ),
      base().gt('loyalty_pts', 0).count(CountOption.exact),
    ]);
    return boomKhachFacts(
      total: (res[0] as PostgrestResponse).count,
      newInPeriod: (res[1] as PostgrestResponse).count,
      returning: (res[2] as PostgrestResponse).count,
      top: (res[3] as List).cast<Map<String, dynamic>>(),
      wallets: res[4] as List<Map<String, dynamic>>,
      withPoints: (res[5] as PostgrestResponse).count,
      period: r.label,
    );
  }

  // ── Khuyến mãi ─────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> khuyenMai(
    String storeId,
    BoomPeriodRange r,
  ) async {
    final res = await Future.wait([
      _db
          .from('coupons')
          .select(
            'code,discount_type,value,min_order_amount,max_discount_amount,is_active,start_date,end_date',
          )
          .eq('store_id', storeId)
          .limit(200),
      // Lượt dùng mã: bảng thanh toán (pos_coupon_redemptions không mở quyền đọc cho app)
      fetchAllPages(
        (o, e) => _db
            .from('payment_settlements')
            .select('id,coupon_code,coupon_discount')
            .eq('store_id', storeId)
            .eq('status', 'completed')
            .not('coupon_code', 'is', null)
            .gte('created_at', _iso(r.start))
            .lt('created_at', _iso(r.end))
            .order('id')
            .range(o, e),
      ),
      fetchAllPages(
        (o, e) => _db
            .from('orders')
            .select('id,discount,total_amount,total')
            .eq('store_id', storeId)
            .eq('status', 'completed')
            .gte('created_at', _iso(r.start))
            .lt('created_at', _iso(r.end))
            .order('id')
            .range(o, e),
      ),
    ]);
    return boomKhuyenMaiFacts(
      coupons: res[0],
      redemptions: res[1],
      orders: res[2],
      period: r.label,
      now: DateTime.now(),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Tính số (thuần, test được) — mỗi khối gọn, chỉ số tổng + vài dòng đầu, không có thông tin cá nhân.
// ═════════════════════════════════════════════════════════════════════════════

const kBoomWasteReasons = {'waste', 'expired', 'damaged', 'spill', 'loss'};

double _n(Object? v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
double _r(double v) => (v * 100).roundToDouble() / 100;

Map<String, dynamic> boomFinanceFacts({
  required List<Map<String, dynamic>> rows,
  required List<Map<String, dynamic>> prevRows,
  required List<Map<String, dynamic>> categories,
  required String period,
  required String prevPeriod,
}) {
  final cat = {for (final c in categories) c['id']: '${c['name'] ?? ''}'};
  double income = 0, expense = 0, autoIncome = 0;
  final byIn = <String, double>{}, byOut = <String, double>{};
  final fund = <String, double>{};
  for (final x in rows) {
    final a = _n(x['amount']);
    final name = (cat[x['category_id']] ?? '').trim();
    final key = name.isEmpty ? 'Khác' : name;
    if (x['type'] == 'income') {
      income += a;
      if (x['is_auto'] == true) autoIncome += a;
      byIn[key] = (byIn[key] ?? 0) + a;
    } else if (x['type'] == 'expense') {
      expense += a;
      byOut[key] = (byOut[key] ?? 0) + a;
      final f = x['fund_type'] == 'bank' ? 'bank' : 'cash';
      fund[f] = (fund[f] ?? 0) + a;
    }
  }
  double pi = 0, pe = 0;
  final prevOut = <String, double>{};
  for (final x in prevRows) {
    if (x['type'] == 'income') pi += _n(x['amount']);
    if (x['type'] == 'expense') {
      pe += _n(x['amount']);
      final name = (cat[x['category_id']] ?? '').trim();
      final key = name.isEmpty ? 'Khác' : name;
      prevOut[key] = (prevOut[key] ?? 0) + _n(x['amount']);
    }
  }
  List<Map<String, dynamic>> top(
    Map<String, double> m,
    int k, [
    Map<String, double>? prev,
  ]) => [
    for (final e
        in (m.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .take(k))
      {
        'name': e.key,
        'amount': _r(e.value),
        // cùng khoản kỳ trước (câu "chi phí tăng do đâu")
        if (prev != null) 'prev': _r(prev[e.key] ?? 0),
      },
  ];
  return {
    'period': period,
    'prev_period': prevPeriod,
    'income': _r(income),
    'expense': _r(expense),
    'auto_income': _r(autoIncome),
    'prev_income': _r(pi),
    'prev_expense': _r(pe),
    'count': rows.length,
    'top_expense': top(byOut, 6, prevOut),
    'top_income': top(byIn, 4),
    'expense_cash': _r(fund['cash'] ?? 0),
    'expense_bank': _r(fund['bank'] ?? 0),
  };
}

Map<String, dynamic> boomKhoFacts({
  required List<Map<String, dynamic>> products,
  required List<Map<String, dynamic>> purchases,
  required List<Map<String, dynamic>> waste,
  required String period,
  required bool withCost,
}) {
  // Chỉ hàng có theo dõi tồn (nguyên liệu / hàng bán có min_stock hoặc có số tồn); bỏ combo, hàng ngừng bán
  final tracked = [
    for (final p in products)
      if (p['product_type'] != 'combo' && p['is_active'] != false) p,
  ];
  double value = 0;
  final low = <Map<String, dynamic>>[];
  var out = 0;
  for (final p in tracked) {
    final q = _n(p['stock_qty']), min = _n(p['min_stock']);
    final cost = _n(p['cost_price_latest']) > 0
        ? _n(p['cost_price_latest'])
        : _n(p['cost_price']);
    if (q > 0) value += q * cost;
    if (min > 0 && q <= min) {
      if (q <= 0) out++;
      low.add({
        'name': '${p['name'] ?? ''}',
        'qty': _r(q),
        'min': _r(min),
        'unit': '${p['unit'] ?? ''}',
      });
    }
  }
  low.sort((a, b) => (a['qty'] as double).compareTo(b['qty'] as double));
  final names = {for (final p in products) p['id']: '${p['name'] ?? ''}'};
  final units = {for (final p in products) p['id']: '${p['unit'] ?? ''}'};
  final costs = {
    for (final p in products)
      p['id']: _n(p['cost_price_latest']) > 0
          ? _n(p['cost_price_latest'])
          : _n(p['cost_price']),
  };
  final lossQty = <Object?, double>{};
  for (final m in waste) {
    final d = _n(m['delta']);
    if (d < 0) lossQty[m['product_id']] = (lossQty[m['product_id']] ?? 0) - d;
  }
  final losses =
      lossQty.entries
          .map(
            (e) => {
              'name': names[e.key] ?? '(món đã xoá)',
              'qty': _r(e.value),
              'unit': units[e.key] ?? '',
              if (withCost) 'value': _r(e.value * (costs[e.key] ?? 0)),
            },
          )
          .toList()
        ..sort(
          (a, b) => withCost
              ? (b['value'] as double).compareTo(a['value'] as double)
              : (b['qty'] as double).compareTo(a['qty'] as double),
        );
  final done = [
    for (final po in purchases)
      if (po['status'] != 'cancelled') po,
  ];
  final bySup = <String, double>{};
  double buy = 0;
  for (final po in done) {
    final a = _n(po['total_cost']) > 0
        ? _n(po['total_cost'])
        : _n(po['total_amount']);
    buy += a;
    final s = '${po['supplier_name'] ?? ''}'.trim();
    final k = s.isEmpty ? 'Không ghi nhà cung cấp' : s;
    bySup[k] = (bySup[k] ?? 0) + a;
  }
  return {
    'period': period,
    'items': tracked.length,
    if (withCost) 'stock_value': _r(value),
    'low_count': low.length,
    'out_count': out,
    'low': low.take(8).toList(),
    'imports': done.length,
    if (withCost) 'import_total': _r(buy),
    if (withCost)
      'top_suppliers': [
        for (final e
            in (bySup.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .take(3))
          {'name': e.key, 'amount': _r(e.value)},
      ],
    'losses': losses.take(5).toList(),
  };
}

Map<String, dynamic> boomNhanSuFacts({
  required List<Map<String, dynamic>> shifts,
  required List<Map<String, dynamic>> users,
  required List<Map<String, dynamic>> payroll,
  required String period,
  required DateTime now,
  required bool self,
}) {
  final name = {for (final u in users) u['id']: '${u['name'] ?? ''}'.trim()};
  final hours = <Object?, double>{};
  final count = <Object?, int>{};
  var open = 0, forgot = 0;
  for (final s in shifts) {
    final a = DateTime.tryParse('${s['clock_in']}');
    if (a == null) continue;
    final b = DateTime.tryParse('${s['clock_out'] ?? ''}');
    count[s['user_id']] = (count[s['user_id']] ?? 0) + 1;
    if (b == null) {
      // Chưa chấm ra: quá 16 giờ coi là quên chấm ra (không cộng giờ)
      if (now.difference(a).inHours >= 16) {
        forgot++;
      } else {
        open++;
      }
      continue;
    }
    final h = b.difference(a).inMinutes / 60;
    if (h > 0 && h < 24) hours[s['user_id']] = (hours[s['user_id']] ?? 0) + h;
  }
  final staff =
      count.keys
          .map(
            (u) => {
              'name': (name[u] ?? '').isEmpty ? 'Nhân viên' : name[u],
              'shifts': count[u],
              'hours': _r(hours[u] ?? 0),
            },
          )
          .toList()
        ..sort(
          (a, b) => (b['hours'] as double).compareTo(a['hours'] as double),
        );
  return {
    'period': period,
    'self': self,
    'staff_count': staff.length,
    'total_hours': _r(hours.values.fold(0.0, (a, b) => a + b)),
    'shifts': shifts.length,
    'open_now': open,
    'forgot_clock_out': forgot,
    'staff': staff.take(12).toList(),
    if (payroll.isNotEmpty)
      'payroll': [
        for (final p in payroll)
          {
            'name': '${p['name'] ?? ''}',
            'status': '${p['status'] ?? ''}',
            'total': _r(_n(p['total_amount'])),
            'from': '${p['from_date'] ?? ''}',
            'to': '${p['to_date'] ?? ''}',
          },
      ],
  };
}

Map<String, dynamic> boomKhachFacts({
  required int total,
  required int newInPeriod,
  required int returning,
  required List<Map<String, dynamic>> top,
  required List<Map<String, dynamic>> wallets,
  required int withPoints,
  required String period,
}) {
  double real = 0, bonus = 0;
  for (final w in wallets) {
    real += _n(w['real_balance']);
    bonus += _n(w['bonus_balance']);
  }
  return {
    'period': period,
    'total': total,
    'new': newInPeriod,
    'returning': returning,
    'with_points': withPoints,
    'wallet_customers': wallets.length,
    'wallet_real': _r(real),
    'wallet_bonus': _r(bonus),
    'top': [
      for (final c in top)
        if (_n(c['total_spent']) > 0)
          {
            // Chỉ tên (không số điện thoại); tên dài cắt bớt
            'name': '${c['name'] ?? 'Khách'}'.trim().characters60,
            'spent': _r(_n(c['total_spent'])),
            'visits': _n(c['visit_count']).round(),
          },
    ],
  };
}

Map<String, dynamic> boomKhuyenMaiFacts({
  required List<Map<String, dynamic>> coupons,
  required List<Map<String, dynamic>> redemptions,
  required List<Map<String, dynamic>> orders,
  required String period,
  required DateTime now,
}) {
  bool live(Map<String, dynamic> c) {
    if (c['is_active'] == false) return false;
    final end = DateTime.tryParse('${c['end_date'] ?? ''}');
    final start = DateTime.tryParse('${c['start_date'] ?? ''}');
    return (end == null || !end.isBefore(now)) &&
        (start == null || !start.isAfter(now));
  }

  final used = <String, ({int n, double d})>{};
  for (final r in redemptions) {
    final code = '${r['coupon_code'] ?? ''}'.trim().toUpperCase();
    if (code.isEmpty) continue;
    final u = used[code] ?? (n: 0, d: 0.0);
    used[code] = (
      n: u.n + 1,
      d: u.d + _n(r['coupon_discount'] ?? r['discount_amount']),
    );
  }
  double disc = 0, revenue = 0;
  var withDisc = 0;
  for (final o in orders) {
    final d = _n(o['discount']);
    revenue += _n(o['total_amount'] ?? o['total']);
    if (d > 0) {
      disc += d;
      withDisc++;
    }
  }
  return {
    'period': period,
    'active': [
      for (final c in coupons.where(live).take(8))
        {
          'code': '${c['code'] ?? ''}',
          'type': c['discount_type'] == 'percent' ? 'percent' : 'fixed',
          'value': _n(c['value']),
          if (_n(c['min_order_amount']) > 0)
            'min_order': _n(c['min_order_amount']),
          if (_n(c['max_discount_amount']) > 0)
            'max_discount': _n(c['max_discount_amount']),
          // ngày hết hạn theo giờ máy (tối giờ VN không lùi về hôm trước)
          if (DateTime.tryParse('${c['end_date'] ?? ''}') case final d?)
            'end':
                '${d.toLocal().year}-${'${d.toLocal().month}'.padLeft(2, '0')}-${'${d.toLocal().day}'.padLeft(2, '0')}',
        },
    ],
    'active_count': coupons.where(live).length,
    'used': [
      for (final e
          in (used.entries.toList()
                ..sort((a, b) => b.value.n.compareTo(a.value.n)))
              .take(8))
        {'code': e.key, 'times': e.value.n, 'discount': _r(e.value.d)},
    ],
    // Lượt dùng từng mã chỉ đọc được ở bán tại bàn (bán tại quầy ghi vào bảng app chưa được đọc)
    'used_scope': 'ban',
    'orders': orders.length,
    'orders_with_discount': withDisc,
    'discount_total': _r(disc),
    'revenue': _r(revenue),
  };
}

extension on String {
  String get characters60 => length > 60 ? substring(0, 60) : this;
}

/// GPT lỗi / chưa bật → vẫn hiện vài số chính đã đọc (ngắn gọn, đúng quyền đã kiểm).
String boomModulesText(Map<String, dynamic> m, String Function(num) vnd) {
  final lines = <String>[];
  final f = m['finance'] as Map?;
  if (f != null) {
    lines.add(
      'Thu Chi ${f['period']}: thu ${vnd(f['income'] as num)}, chi ${vnd(f['expense'] as num)}, '
      'còn lại ${vnd((f['income'] as num) - (f['expense'] as num))}.',
    );
  }
  final k = m['kho'] as Map?;
  if (k != null) {
    lines.add(
      'Kho: ${k['low_count']} mặt hàng dưới mức tối thiểu (${k['out_count']} đã hết), ${k['imports']} phiếu nhập trong kỳ.',
    );
  }
  final n = m['nhan_su'] as Map?;
  if (n != null) {
    lines.add(
      'Chấm công ${n['period']}: ${n['shifts']} ca, tổng ${n['total_hours']} giờ.',
    );
  }
  final c = m['khach'] as Map?;
  if (c != null) {
    lines.add(
      'Khách hàng: ${c['total']} khách, ${c['new']} khách mới trong kỳ, ${c['returning']} khách quay lại từ 2 lần.',
    );
  }
  final p = m['khuyen_mai'] as Map?;
  if (p != null) {
    lines.add(
      'Khuyến mãi: ${p['active_count']} mã đang chạy, giảm giá ${vnd(p['discount_total'] as num)} '
      'trên ${p['orders_with_discount']}/${p['orders']} đơn.',
    );
  }
  return lines.join('\n');
}
