import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/store_auth_service.dart';
import '../utils/string_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BILL HISTORY — tra cứu bill đã thanh toán + dựng lại dữ liệu để in lại.
// Mỗi lần thu tiền tạo ĐÚNG 1 finance_records tự động có checkout_reference_id
// (POS → orders.id, Bàn → payment_settlements.id), nên đó là danh sách bill chuẩn.
// Chỉ đọc; không ghi DB.
// ─────────────────────────────────────────────────────────────────────────────

/// Dòng ghi trên bill in lại, cạnh số đơn.
/// Số bill tối đa tải về mỗi lần tra cứu (mới nhất trước) — chỉ để chặn kỳ quá dài.
/// Tải theo trang 1.000 dòng (giới hạn mỗi lần của máy chủ), nên quán đông xem cả tháng vẫn đủ.
const kBillLookupLimit = 20000;
const _kBillPage = 1000;

const kReprintMarker = 'BẢN IN LẠI';

class BillHistoryEntry {
  final String financeId;
  final String referenceId;
  final String description;
  final double amount;
  final DateTime recordedAt;

  BillHistoryEntry({
    required this.financeId,
    required this.referenceId,
    required this.description,
    required this.amount,
    required this.recordedAt,
  }) : searchKey = description.toLowerCase().toUnsigned();

  /// Mô tả đã hạ chữ + bỏ dấu, tính một lần — ô tìm kiếm không phải xử lý lại
  /// cả danh sách (tới 20.000 bill) mỗi lần gõ phím.
  final String searchKey;

  factory BillHistoryEntry.fromRow(Map<String, dynamic> r) => BillHistoryEntry(
    financeId: r['id'] as String,
    referenceId: r['checkout_reference_id'] as String,
    description: (r['description'] as String?)?.trim() ?? '',
    amount: (r['amount'] as num?)?.toDouble() ?? 0,
    recordedAt: DateTime.parse(r['recorded_at'] as String).toLocal(),
  );

  /// Số đơn QN-… nếu mô tả có (bill bán quầy), null với bill bàn.
  String? get orderNumber =>
      RegExp(r'QN-\d{8}-\d+').firstMatch(description)?.group(0);
}

/// Lọc theo ô tìm kiếm: khớp mô tả (số đơn, tên bàn; không phân biệt dấu) hoặc số tiền.
List<BillHistoryEntry> filterBills(List<BillHistoryEntry> bills, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return bills;
  // Chỉ so số tiền khi ô tìm kiếm toàn số (vd "128.000"); "bàn 3" không được khớp mọi bill có số 3.
  final isAmount = RegExp(r'^[0-9.,\s]+(đ|d|k)?$').hasMatch(q);
  final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  final unsignedQ = q.toUnsigned();
  return bills.where((b) {
    if (b.searchKey.contains(unsignedQ)) {
      return true;
    }
    return isAmount &&
        digits.isNotEmpty &&
        b.amount.round().toString().contains(digits);
  }).toList();
}

class ReprintLine {
  final String name;
  final int qty;
  final double unitPrice;
  const ReprintLine(this.name, this.qty, this.unitPrice);
}

/// Dữ liệu gốc của một bill đã thanh toán (đọc từ DB).
class ReprintSource {
  final String orderNumber;
  final DateTime paidAt;
  final String? tableName;
  final List<ReprintLine> lines;
  final double subtotal;
  final double surcharge;
  final double total;
  final String? paymentMethod;

  const ReprintSource({
    required this.orderNumber,
    required this.paidAt,
    this.tableName,
    required this.lines,
    required this.subtotal,
    this.surcharge = 0,
    required this.total,
    this.paymentMethod,
  });

  /// Giảm giá suy ra từ tổng máy chủ để bill in lại luôn khớp số đã thu.
  double get discount {
    final d = subtotal + surcharge - total;
    return d > 0 ? d : 0;
  }

  String get reprintOrderNumber => '$orderNumber · $kReprintMarker';
}

class BillHistoryRepository {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<String> _storeId() async {
    final id = (await StoreAuthService.getStoreInfo())['store_id'];
    if (id == null || id.isEmpty) throw StateError('Chưa xác định cửa hàng');
    return id;
  }

  /// Bill trong [fromMs, toMs), mới nhất trước, tối đa [limit].
  Future<List<BillHistoryEntry>> listBills(
    int fromMs,
    int toMs, {
    int limit = kBillLookupLimit,
  }) async {
    final storeId = await _storeId();
    final out = <BillHistoryEntry>[];
    final seen =
        <String>{}; // bill mới vào giữa lúc tải làm lệch trang → bỏ dòng trùng
    for (var offset = 0; offset < limit; offset += _kBillPage) {
      final end =
          (offset + _kBillPage < limit ? offset + _kBillPage : limit) - 1;
      final rows = await _sb
          .from('finance_records')
          .select('id, checkout_reference_id, description, amount, recorded_at')
          .eq('store_id', storeId)
          .eq('type', 'income')
          .eq('is_auto', true)
          .not('checkout_reference_id', 'is', null)
          .gte(
            'recorded_at',
            DateTime.fromMillisecondsSinceEpoch(
              fromMs,
            ).toUtc().toIso8601String(),
          )
          .lt(
            'recorded_at',
            DateTime.fromMillisecondsSinceEpoch(toMs).toUtc().toIso8601String(),
          )
          .order('recorded_at', ascending: false)
          .order(
            'id',
            ascending: false,
          ) // thứ tự cố định để trang sau không trùng/sót
          .range(offset, end);
      out.addAll(
        rows
            .where((r) => seen.add(r['id'] as String))
            .map((r) => BillHistoryEntry.fromRow(Map<String, dynamic>.from(r))),
      );
      if (rows.length < end - offset + 1) break;
    }
    return out;
  }

  /// Dựng lại bill từ [referenceId]: thử đơn bán quầy trước, sau đó lần thanh toán bàn.
  Future<ReprintSource> loadSource(String referenceId) async {
    final storeId = await _storeId();

    final order = await _sb
        .from('orders')
        .select(
          'id, order_number, created_at, subtotal, total_amount, total, payment_method',
        )
        .eq('store_id', storeId)
        .eq('id', referenceId)
        .maybeSingle();
    if (order != null) {
      final lines = await _lines(storeId, [referenceId]);
      return ReprintSource(
        orderNumber:
            order['order_number'] as String? ?? referenceId.substring(0, 8),
        paidAt: DateTime.parse(order['created_at'] as String).toLocal(),
        lines: lines,
        subtotal: _num(order['subtotal']) ?? _sumLines(lines),
        total: _num(order['total_amount']) ?? _num(order['total']) ?? 0,
        paymentMethod: order['payment_method'] as String?,
      );
    }

    final st = await _sb
        .from('payment_settlements')
        .select(
          'id, session_id, subtotal, surcharge, total_amount, payment_method, created_at',
        )
        .eq('store_id', storeId)
        .eq('id', referenceId)
        .maybeSingle();
    if (st == null) throw StateError('Không tìm thấy bill này');

    final sessionId = st['session_id'] as String?;
    var orderIds = <String>[];
    var orderNumbers = <String>[];
    String? tableName;
    if (sessionId != null) {
      final links = await _sb
          .from('ban_session_orders')
          .select('order_id')
          .eq('store_id', storeId)
          .eq('session_id', sessionId);
      orderIds = links
          .map((r) => r['order_id'] as String?)
          .whereType<String>()
          .toList();
      if (orderIds.isNotEmpty) {
        final orders = await _sb
            .from('orders')
            .select('order_number')
            .eq('store_id', storeId)
            .inFilter('id', orderIds)
            .order('created_at');
        orderNumbers = orders
            .map((r) => r['order_number'] as String?)
            .whereType<String>()
            .toList();
      }
      final session = await _sb
          .from('ban_sessions')
          .select('table_id')
          .eq('store_id', storeId)
          .eq('id', sessionId)
          .maybeSingle();
      final tableId = session?['table_id'] as String?;
      if (tableId != null) {
        final table = await _sb
            .from('ban_dining_tables')
            .select('label, name')
            .eq('store_id', storeId)
            .eq('id', tableId)
            .maybeSingle();
        tableName = (table?['label'] as String?) ?? (table?['name'] as String?);
      }
    }
    final lines = orderIds.isEmpty
        ? const <ReprintLine>[]
        : await _lines(storeId, orderIds);
    return ReprintSource(
      orderNumber: orderNumbers.isEmpty
          ? referenceId.substring(0, 8).toUpperCase()
          : orderNumbers.join(' + '),
      paidAt: DateTime.parse(st['created_at'] as String).toLocal(),
      tableName: tableName,
      lines: lines,
      subtotal: _num(st['subtotal']) ?? _sumLines(lines),
      surcharge: _num(st['surcharge']) ?? 0,
      total: _num(st['total_amount']) ?? 0,
      paymentMethod: st['payment_method'] as String?,
    );
  }

  Future<List<ReprintLine>> _lines(
    String storeId,
    List<String> orderIds,
  ) async {
    final rows = await _sb
        .from('order_items')
        .select('name, product_name, qty, quantity, unit_price')
        .eq('store_id', storeId)
        .inFilter('order_id', orderIds);
    return rows
        .map((r) {
          final name =
              (r['product_name'] as String?) ?? (r['name'] as String?) ?? 'Món';
          final qty = (_num(r['quantity']) ?? _num(r['qty']) ?? 1).round();
          return ReprintLine(name, qty, _num(r['unit_price']) ?? 0);
        })
        // Món QR bị huỷ lúc thanh toán còn dòng số lượng 0 — không in.
        .where((l) => l.qty > 0)
        .toList();
  }

  static double? _num(Object? v) => (v as num?)?.toDouble();
  static double _sumLines(List<ReprintLine> l) =>
      l.fold(0, (s, x) => s + x.qty * x.unitPrice);
}

final billHistoryRepositoryProvider = Provider<BillHistoryRepository>(
  (ref) => BillHistoryRepository(),
);
