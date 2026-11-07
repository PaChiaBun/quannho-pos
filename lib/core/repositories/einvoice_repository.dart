import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/store_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// E-INVOICE REPOSITORY — công tắc hóa đơn điện tử theo quán + báo cáo hóa đơn
// Ghi công tắc chỉ qua RPC `set_einvoice_enabled_v1` (Chủ quán, có audit).
// Tắt/bật KHÔNG đổi việc ghi bill/doanh thu; chỉ quyết định bill có được đưa vào hàng đợi phát hành.
// ─────────────────────────────────────────────────────────────────────────────

class EinvoiceReport {
  final bool enabled;
  final double issuedAmount;
  final int issuedCount;
  final double pendingAmount;
  final int pendingCount;
  final double problemAmount;
  final int problemCount;
  final double cancelledAmount;
  final int cancelledCount;

  const EinvoiceReport({
    this.enabled = false,
    this.issuedAmount = 0,
    this.issuedCount = 0,
    this.pendingAmount = 0,
    this.pendingCount = 0,
    this.problemAmount = 0,
    this.problemCount = 0,
    this.cancelledAmount = 0,
    this.cancelledCount = 0,
  });

  static const empty = EinvoiceReport();

  factory EinvoiceReport.fromJson(Map<dynamic, dynamic> j) {
    double d(String k) => (j[k] as num?)?.toDouble() ?? 0;
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return EinvoiceReport(
      enabled: j['enabled'] == true,
      issuedAmount: d('issued_amount'),
      issuedCount: i('issued_count'),
      pendingAmount: d('pending_amount'),
      pendingCount: i('pending_count'),
      problemAmount: d('problem_amount'),
      problemCount: i('problem_count'),
      cancelledAmount: d('cancelled_amount'),
      cancelledCount: i('cancelled_count'),
    );
  }

  /// Doanh thu của kỳ nhưng chưa có hóa đơn đã phát hành. Chỉ để đối chiếu, không dùng để sửa số liệu.
  double uninvoicedFrom(double totalRevenue) {
    final v = totalRevenue - issuedAmount;
    return v < 0 ? 0 : v;
  }
}

class EinvoiceProblemDoc {
  final String id;
  final String status;
  final double totalAmount;
  final DateTime invoiceDate;
  final String? errorCode;

  const EinvoiceProblemDoc({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.invoiceDate,
    this.errorCode,
  });

  factory EinvoiceProblemDoc.fromJson(Map<String, dynamic> j) =>
      EinvoiceProblemDoc(
        id: j['id'] as String,
        status: j['status'] as String? ?? 'failed',
        totalAmount: (j['total_amount'] as num?)?.toDouble() ?? 0,
        invoiceDate:
            DateTime.tryParse(j['invoice_date'] as String? ?? '')?.toLocal() ??
            DateTime.now(),
        errorCode: j['error_code'] as String?,
      );
}

class EinvoiceRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    final sid = info['store_id'];
    return (sid != null && sid.isNotEmpty) ? sid : null;
  }

  /// Mặc định TẮT khi chưa cấu hình hoặc khi đọc lỗi (an toàn: không tự phát hành).
  Future<bool> isEnabled() async {
    try {
      final storeId = await _storeId();
      if (storeId == null) return false;
      final row = await _sb
          .from('einvoice_store_config')
          .select('enabled')
          .eq('store_id', storeId)
          .maybeSingle();
      return row?['enabled'] == true;
    } catch (e) {
      debugPrint('[EinvoiceRepository] isEnabled error: $e');
      return false;
    }
  }

  /// Trả về null nếu thành công, ngược lại là mã lỗi (OWNER_ONLY, UNAUTHENTICATED, ...).
  Future<String?> setEnabled(bool enabled) async {
    try {
      final res = await _sb.rpc(
        'set_einvoice_enabled_v1',
        params: {'p_enabled': enabled},
      );
      if (res is Map && res['success'] == true) return null;
      return (res is Map ? res['error'] as String? : null) ?? 'UNKNOWN';
    } catch (e) {
      debugPrint('[EinvoiceRepository] setEnabled error: $e');
      return 'NETWORK_OR_SERVER';
    }
  }

  /// Khoảng [from, to) theo epoch millis, cùng quy ước với ReportPeriod.rangeFor.
  Future<EinvoiceReport> getReport(int fromMs, int toMs) async {
    try {
      final res = await _sb.rpc(
        'einvoice_report_v1',
        params: {
          'p_from': DateTime.fromMillisecondsSinceEpoch(
            fromMs,
          ).toUtc().toIso8601String(),
          'p_to': DateTime.fromMillisecondsSinceEpoch(
            toMs,
          ).toUtc().toIso8601String(),
        },
      );
      if (res is Map) return EinvoiceReport.fromJson(res);
      return EinvoiceReport.empty;
    } catch (e) {
      debugPrint('[EinvoiceRepository] getReport error: $e');
      rethrow;
    }
  }

  /// Hóa đơn lỗi hoặc bị từ chối cấp mã trong kỳ, để xử lý lại.
  Future<List<EinvoiceProblemDoc>> getProblemDocs(
    int fromMs,
    int toMs, {
    int limit = 50,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return const [];
    final rows = await _sb
        .from('einvoice_documents')
        .select('id,status,total_amount,invoice_date,error_code')
        .eq('store_id', storeId)
        .inFilter('status', ['rejected', 'failed'])
        .gte(
          'invoice_date',
          DateTime.fromMillisecondsSinceEpoch(fromMs).toUtc().toIso8601String(),
        )
        .lt(
          'invoice_date',
          DateTime.fromMillisecondsSinceEpoch(toMs).toUtc().toIso8601String(),
        )
        .order('invoice_date', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => EinvoiceProblemDoc.fromJson(r as Map<String, dynamic>))
        .toList();
  }
}
