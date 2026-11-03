import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/store_auth_service.dart';
import '../utils/server_time.dart';
import '../utils/string_utils.dart';

const _kNavy = Color(0xFF1C2151);
const _kInk = Color(0xFF1A1207);
const _kMuted = Color(0xFF9E9085);
const _kBg = Color(0xFFFFF8F0);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFC62828);

String _fmtVnd(double amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return '${formatter.format(amount)} đ';
}

String _formatPayMethod(String? method) {
  if (method == null || method.isEmpty) return 'Không rõ';
  switch (method.toLowerCase()) {
    case 'cash':
      return 'Tiền mặt';
    case 'transfer':
      return 'Chuyển khoản';
    case 'card':
      return 'Thẻ POS';
    default:
      return method;
  }
}

/// Helper trích xuất mã đơn hàng QN-... từ mô tả giao dịch
String? extractOrderNumber(String? text) {
  if (text == null || text.isEmpty) return null;
  final regExp = RegExp(r'QN-\d{8}-\d+');
  final match = regExp.firstMatch(text);
  if (match != null) {
    return match.group(0);
  }
  if (text.startsWith('QN-')) {
    return text.trim();
  }
  return null;
}

/// Một dòng món trên bill. Bàn gọi từng ly nên một bill có thể có 4 dòng "Trà Tắc x1" — dòng cùng tên, giá,
/// topping, ghi chú được gộp lại ([mergeBillLines]).
class BillLine {
  final String name;
  final double qty;
  final double subtotal;
  final List<String> extras; // topping / tuỳ chọn
  final String? note;
  const BillLine(this.name, this.qty, this.subtotal, this.extras, this.note);
}

/// Gộp các dòng món giống hệt (tên, đơn giá, topping, ghi chú) — số lượng và thành tiền cộng dồn.
List<BillLine> mergeBillLines(List<Map<String, dynamic>> items) {
  final merged = <String, BillLine>{}; // giữ thứ tự gọi món
  for (final it in items) {
    final name = '${it['name'] ?? it['product_name'] ?? ''}';
    final qty =
        (it['quantity'] as num?)?.toDouble() ?? (it['qty'] as num?)?.toDouble() ?? 1;
    final unit = (it['unit_price'] as num?)?.toDouble() ?? 0;
    // Dòng QR cũ không ghi subtotal: tính lại thay vì hiện 0 đ.
    final sub = (it['subtotal'] as num?)?.toDouble() ?? unit * qty;
    final extras = billItemExtras(it['modifiers_json']);
    final rawNote = (it['note'] as String?)?.trim();
    final note = rawNote == null || rawNote.isEmpty ? null : rawNote;
    final key = '$name¦$unit¦${extras.join('|')}¦${note ?? ''}';
    final prev = merged[key];
    merged[key] = prev == null
        ? BillLine(name, qty, sub, extras, note)
        : BillLine(name, prev.qty + qty, prev.subtotal + sub, extras, note);
  }
  return merged.values.toList();
}

/// Chi tiết một bill đã tải xong.
class OrderDetail {
  final Map<String, dynamic> order; // bill bàn: đơn đầu + số liệu thanh toán của cả bàn
  final List<BillLine> lines;
  final String? cashierName;
  final String? waiterName;
  final String? staffName; // tên dò thêm khi đơn không ghi thu ngân
  const OrderDetail({
    required this.order,
    required this.lines,
    this.cashierName,
    this.waiterName,
    this.staffName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// TẢI CHI TIẾT BILL — theo lô, các lần hỏi chạy song song. Trước đây mỗi lần chạm hỏi máy chủ nối tiếp
// 6–20 lần (đơn, món, rồi dò tên người qua 4 bảng cho từng mã) → 1–2 giây trên Sunmi (đo 03/11/2026).
// ─────────────────────────────────────────────────────────────────────────────

// Bill đã thanh toán không đổi nữa nên giữ được; giới hạn số bill để không phình bộ nhớ.
final _cache = <String, Future<OrderDetail?>>{}; // giữ thứ tự thêm → bỏ bill cũ nhất trước
const _kCacheMax = 300;

class _Person {
  final String? staff, member, account;
  const _Person(this.staff, this.member, this.account);
}

// Tên nhân viên ít đổi: tra một lần cho cả danh sách, dùng lại cho các bill sau.
final _people = <String, _Person>{};

const _kPersonKeys = ['waiter_id', 'staff_id', 'created_by', 'cashier_id', 'user_id'];

void _remember(String id, Future<OrderDetail?> f) {
  _cache.remove(id);
  _cache[id] = f;
  while (_cache.length > _kCacheMax) {
    _cache.remove(_cache.keys.first);
  }
  // Lỗi mạng: bỏ khỏi bộ nhớ để lần mở sau tải lại.
  f.catchError((Object _) {
    if (identical(_cache[id], f)) _cache.remove(id);
    return null;
  });
}

Future<void> _lookupPeople(SupabaseClient sb, Set<String> ids) async {
  final need = [for (final id in ids) if (!_people.containsKey(id)) id];
  if (need.isEmpty) return;
  final inList = need.join(',');
  Future<List<Map<String, dynamic>>> safe(Future<List<Map<String, dynamic>>> q) =>
      q.catchError((Object _) => <Map<String, dynamic>>[]);
  final r = await Future.wait([
    safe(sb.from('staff_members').select('id, name').inFilter('id', need)),
    safe(sb
        .from('store_members')
        .select('id, user_id, display_name, user_accounts(display_name)')
        .or('id.in.($inList),user_id.in.($inList)')),
    safe(sb.from('user_accounts').select('id, display_name').inFilter('id', need)),
  ]);
  String? clean(Object? v) {
    final s = (v as String?)?.trim();
    return s == null || s.isEmpty ? null : s;
  }

  final staff = {for (final s in r[0]) '${s['id']}': clean(s['name'])};
  final memberById = <String, String?>{};
  final memberByUser = <String, String?>{};
  for (final m in r[1]) {
    final acc = m['user_accounts'] as Map<String, dynamic>?;
    final name = clean(acc?['display_name']) ?? clean(m['display_name']);
    memberById['${m['id']}'] = name;
    if (m['user_id'] != null) memberByUser['${m['user_id']}'] = name;
  }
  final account = {for (final a in r[2]) '${a['id']}': clean(a['display_name'])};
  for (final id in need) {
    _people[id] = _Person(staff[id], memberById[id] ?? memberByUser[id], account[id]);
  }
}

/// [ids] là mã đơn (`orders.id`, bán quầy) hoặc mã thanh toán (`payment_settlements.id`, bill bàn).
Future<Map<String, OrderDetail>> _loadMany(List<String> ids) async {
  final sb = Supabase.instance.client;
  final storeInfo = await StoreAuthService.getStoreInfo();
  final storeId = storeInfo['store_id'] as String?;
  if (storeId == null) throw Exception('Chưa xác định cửa hàng');

  // Lượt 1: đơn bán quầy và bill bàn cùng lúc.
  final first = await Future.wait([
    sb.from('orders').select('*').eq('store_id', storeId).inFilter('id', ids),
    sb.from('payment_settlements').select('*').eq('store_id', storeId).inFilter('id', ids),
  ]);
  final orderById = {
    for (final o in first[0]) o['id'] as String: Map<String, dynamic>.from(o),
  };
  final settlements = {
    for (final s in first[1])
      if (!orderById.containsKey(s['id'])) s['id'] as String: Map<String, dynamic>.from(s),
  };

  // Lượt 2 (bill bàn): các đơn của phiên bàn.
  final sessionOrders = <String, List<String>>{};
  if (settlements.isNotEmpty) {
    final links = await sb
        .from('ban_session_orders')
        .select('session_id, order_id')
        .inFilter('session_id', [
          for (final s in settlements.values)
            if (s['session_id'] != null) s['session_id'] as String,
        ]);
    for (final l in links) {
      final oid = l['order_id'] as String?;
      if (oid != null) (sessionOrders[l['session_id'] as String] ??= []).add(oid);
    }
  }
  final linked = {for (final v in sessionOrders.values) ...v}..removeAll(orderById.keys);

  // Lượt 3: đơn của bill bàn + món của mọi đơn.
  final allOrderIds = {...orderById.keys, ...linked}.toList();
  final third = await Future.wait([
    linked.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : sb.from('orders').select('*').eq('store_id', storeId).inFilter('id', linked.toList()),
    allOrderIds.isEmpty
        ? Future.value(<Map<String, dynamic>>[])
        : sb
              .from('order_items')
              .select('order_id, name, qty, quantity, unit_price, subtotal, modifiers_json, note')
              .inFilter('order_id', allOrderIds),
  ]);
  for (final o in third[0]) {
    orderById[o['id'] as String] = Map<String, dynamic>.from(o);
  }
  final itemsByOrder = <String, List<Map<String, dynamic>>>{};
  for (final it in third[1]) {
    (itemsByOrder[it['order_id'] as String] ??= []).add(Map<String, dynamic>.from(it));
  }

  final built = <String, (Map<String, dynamic>, List<String>)>{};
  for (final id in ids) {
    final direct = orderById[id];
    if (direct != null) {
      built[id] = (direct, [id]);
      continue;
    }
    final s = settlements[id];
    final oids = [
      for (final oid in sessionOrders[s?['session_id']] ?? const <String>[])
        if (orderById.containsKey(oid)) oid,
    ];
    if (s == null || oids.isEmpty) continue;
    final order = Map<String, dynamic>.from(orderById[oids.first]!);
    order['order_number'] = [
      for (final oid in oids) orderById[oid]!['order_number'] as String?,
    ].whereType<String>().join(' + ');
    order['subtotal'] = s['subtotal'];
    order['discount'] = s['discount'];
    order['total'] = s['total_amount'];
    order['total_amount'] = s['total_amount'];
    order['payment_method'] = s['payment_method'];
    order['customer_id'] = s['customer_id'];
    order['staff_id'] = s['cashier_staff_id'] ?? order['staff_id'];
    order['created_at'] = s['created_at'];
    built[id] = (order, oids);
  }

  // Lượt 4: tên người của mọi bill trong lô (3 bảng cùng lúc, bỏ qua mã đã tra).
  await _lookupPeople(sb, {
    for (final b in built.values)
      for (final k in _kPersonKeys)
        if ('${b.$1[k] ?? ''}'.trim().isNotEmpty) '${b.$1[k]}'.trim(),
  });
  String? employee(Object? id) {
    final p = _people['${id ?? ''}'.trim()];
    return p?.staff ?? p?.member;
  }

  final out = <String, OrderDetail>{};
  built.forEach((id, b) {
    final (order, oids) = b;
    String? staffName;
    for (final k in ['waiter_name', 'staff_name', 'created_by_name', 'cashier_name']) {
      final v = (order[k] as String?)?.trim();
      if (v != null && v.isNotEmpty) {
        staffName = v;
        break;
      }
    }
    if (staffName == null) {
      for (final k in _kPersonKeys) {
        final p = _people['${order[k] ?? ''}'.trim()];
        staffName = p?.member ?? p?.staff ?? p?.account;
        if (staffName != null) break;
      }
    }
    out[id] = OrderDetail(
      order: order,
      lines: mergeBillLines([for (final oid in oids) ...?itemsByOrder[oid]]),
      cashierName: employee(order['staff_id']),
      waiterName: employee(order['waiter_id']),
      staffName: staffName,
    );
  });
  return out;
}

Future<OrderDetail?> _loadByNumber(String orderNumber) async {
  final storeInfo = await StoreAuthService.getStoreInfo();
  final storeId = storeInfo['store_id'] as String?;
  if (storeId == null) throw Exception('Chưa xác định cửa hàng');
  final rows = await Supabase.instance.client
      .from('orders')
      .select('id')
      .eq('store_id', storeId)
      .eq('order_number', orderNumber)
      .limit(1);
  if (rows.isEmpty) return null;
  final id = rows.first['id'] as String;
  return (await _loadMany([id]))[id];
}

Future<OrderDetail?> _detailFor(String orderNumber, String? orderId) {
  if (orderId == null || orderId.isEmpty) return _loadByNumber(orderNumber);
  final hit = _cache[orderId];
  if (hit != null) return hit;
  final f = _loadMany([orderId]).then((m) => m[orderId]);
  _remember(orderId, f);
  return f;
}

/// Tải sẵn chi tiết các bill đang hiện trong danh sách (Báo cáo › Hóa đơn, Thu Chi): vài lượt hỏi cho cả
/// danh sách, chạm vào là hiện ngay. Lỗi mạng thì thôi — chạm sẽ tải lại.
void prefetchOrderDetails(Iterable<String> ids) {
  final need = {
    for (final id in ids)
      if (id.isNotEmpty && !_cache.containsKey(id)) id,
  }.toList();
  for (var i = 0; i < need.length; i += 40) {
    final chunk = need.sublist(i, math.min(i + 40, need.length));
    final batch = _loadMany(chunk);
    for (final id in chunk) {
      _remember(id, batch.then((m) => m[id]));
    }
  }
}

@visibleForTesting
void debugSeedOrderDetail(String id, Future<OrderDetail?> detail) => _cache[id] = detail;

@visibleForTesting
void debugResetOrderDetails() {
  _cache.clear();
  _people.clear();
  _opening = false;
}

// Một bảng chi tiết mỗi lúc: chạm liên tục trong lúc tải từng mở chồng 3 bảng (đo 03/11/2026).
bool _opening = false;

/// [orderId] là khóa canonical ưu tiên. [orderNumber] chỉ còn là fallback cho các màn báo cáo lịch sử chưa
/// có reference_id. Bảng mở ngay (hiện trước [previewTitle], giờ, tổng tiền của dòng vừa chạm) rồi mới tải
/// món — trước đây chờ tải xong mới mở, không báo gì.
Future<void> showOrderDetailDialog(
  BuildContext context,
  String orderNumber, {
  String? orderId,
  String? previewTitle,
  DateTime? previewTime,
  double? previewTotal,
}) async {
  if (_opening) return;
  _opening = true;
  try {
    final detail = _detailFor(orderNumber, orderId);
    await showDialog<void>(
      context: context,
      builder: (ctx) => _OrderDetailDialog(
        detail: detail,
        orderNumber: orderNumber,
        previewTitle: previewTitle,
        previewTime: previewTime,
        previewTotal: previewTotal,
      ),
    );
  } finally {
    _opening = false;
  }
}

class _OrderDetailDialog extends StatefulWidget {
  final Future<OrderDetail?> detail;
  final String orderNumber;
  final String? previewTitle;
  final DateTime? previewTime;
  final double? previewTotal;

  const _OrderDetailDialog({
    required this.detail,
    required this.orderNumber,
    this.previewTitle,
    this.previewTime,
    this.previewTotal,
  });

  @override
  State<_OrderDetailDialog> createState() => _OrderDetailDialogState();
}

class _OrderDetailDialogState extends State<_OrderDetailDialog> {
  // Bảng mở ngay khi chạm: lần chạm thứ hai của một cú chạm đôi rơi vào nền tối ngoài bảng và đóng luôn bảng.
  // 0,4 giây đầu không cho đóng bằng nền / nút quay lại (nút X vẫn đóng).
  bool _settled = false;
  Timer? _settle;

  String get orderNumber => widget.orderNumber;
  String? get previewTitle => widget.previewTitle;
  DateTime? get previewTime => widget.previewTime;
  double? get previewTotal => widget.previewTotal;

  @override
  void initState() {
    super.initState();
    _settle = Timer(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _settled = true);
    });
  }

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isDesktop = screenWidth >= 600;

    return PopScope(
      canPop: _settled,
      child: _dialog(context, isDesktop: isDesktop, screenHeight: screenHeight),
    );
  }

  Widget _dialog(BuildContext context, {required bool isDesktop, required double screenHeight}) {
    return AlertDialog(
      backgroundColor: _kBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 24 : 16,
        vertical: isDesktop ? 36 : 24,
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Chi tiết đơn hàng',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: isDesktop ? 18 : 16,
              color: _kNavy,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: isDesktop ? 520 : 400,
          maxHeight: screenHeight * 0.85,
        ),
        child: FutureBuilder<OrderDetail?>(
          future: widget.detail,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return _loading();
            }
            if (snap.hasError) {
              return _message('Chưa tải được chi tiết bill. Kiểm tra mạng rồi mở lại.');
            }
            final d = snap.data;
            if (d == null) return _message('Không tìm thấy đơn hàng "$orderNumber"');
            return _content(d, isDesktop: isDesktop, screenHeight: screenHeight);
          },
        ),
      ),
    );
  }

  Widget _loading() {
    final sub = [
      if (previewTime != null) DateFormat('HH:mm · dd/MM').format(previewTime!),
      if (previewTotal != null) _fmtVnd(previewTotal!),
    ].join('  ·  ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (previewTitle != null && previewTitle!.isNotEmpty)
          Text(
            previewTitle!,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: _kNavy,
            ),
          ),
        if (sub.isNotEmpty)
          Text(sub, style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kMuted)),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text('Đang tải món…', style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kMuted)),
          ],
        ),
      ],
    );
  }

  Widget _message(String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kRed, fontWeight: FontWeight.w600),
  );

  Widget _infoRow(String label, String value, {Color color = _kInk, FontWeight weight = FontWeight.w500, double size = 12, int? maxLines}) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              color: _kMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              maxLines: maxLines,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: size,
                color: color,
                fontWeight: weight,
              ),
            ),
          ),
        ],
      );

  Widget _content(OrderDetail d, {required bool isDesktop, required double screenHeight}) {
    final order = d.order;
    final note = (order['note'] as String?)?.trim();
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Info Box
          Container(
            padding: EdgeInsets.all(isDesktop ? 16 : 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E2DA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow(
                  'Số đơn:',
                  '${order['order_number'] ?? orderNumber}',
                  color: _kNavy,
                  weight: FontWeight.w900,
                  size: 13,
                ),
                const SizedBox(height: 6),
                _infoRow(
                  'Thời gian:',
                  DateFormat('dd/MM/yyyy HH:mm').format(
                    parseServerTime(order['created_at'] as String?) ?? DateTime.now(),
                  ),
                ),
                const SizedBox(height: 6),
                _infoRow(
                  'Thu ngân thanh toán:',
                  d.cashierName ?? d.staffName ?? 'Chưa ghi nhận',
                  color: _kNavy,
                  weight: FontWeight.w700,
                  maxLines: 2,
                ),
                if (d.waiterName != null && d.waiterName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow('Nhân viên phục vụ:', d.waiterName!, color: _kNavy, weight: FontWeight.w700),
                ],
                if (order['customer_name'] != null &&
                    (order['customer_name'] as String).isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _infoRow('Khách hàng:', order['customer_name'] as String),
                ],
                const SizedBox(height: 6),
                _infoRow('Hình thức:', _formatPayMethod(order['payment_method'] as String?)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Danh sách món:',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: _kNavy,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: isDesktop ? screenHeight * 0.45 : screenHeight * 0.3,
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  for (final line in d.lines)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF2ECE4), width: 0.5),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  line.name,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _kInk,
                                  ),
                                ),
                                // Topping / ghi chú món: trước không hiện, dòng 30.000 đ không rõ vì sao.
                                if (line.extras.isNotEmpty)
                                  Text(
                                    '+ ${line.extras.join(', ')}',
                                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kMuted),
                                  ),
                                if (line.note != null)
                                  Text(
                                    line.note!,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: _kMuted,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'x${line.qty == line.qty.roundToDouble() ? line.qty.toStringAsFixed(0) : line.qty}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _kNavy,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _fmtVnd(line.subtotal),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: _kNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tạm tính:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kMuted)),
              Text(
                _fmtVnd((order['subtotal'] as num?)?.toDouble() ?? 0),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _kInk,
                ),
              ),
            ],
          ),
          if (order['discount'] != null && (order['discount'] as num).toDouble() > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Giảm giá:', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kRed)),
                Text(
                  '-${_fmtVnd((order['discount'] as num).toDouble())}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _kRed,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 20, color: Color(0xFFE8E2DA)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tổng thanh toán:',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _kNavy,
                ),
              ),
              Text(
                _fmtVnd((order['total'] as num?)?.toDouble() ?? 0),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: _kGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE8E2DA)),
            ),
            width: double.infinity,
            child: Text(
              note != null && note.isNotEmpty
                  ? 'Ghi chú: ${tidyRepeatedTableWord(note)}'
                  : 'Ghi chú: Không có ghi chú',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: _kMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
