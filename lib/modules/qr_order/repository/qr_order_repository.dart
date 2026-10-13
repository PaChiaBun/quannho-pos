import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';

/// Kết quả fetch pipeline đơn QR phục vụ UI và Stream
class QrFetchResult {
  final bool isSuccess;
  final String? errorCode;
  final String? errorMessage;
  final List<QrRequestModel> requests;

  /// Fetch lỗi: `requests` là danh sách cũ (có thể đã lỗi thời).
  bool get isStale => !isSuccess;

  const QrFetchResult({
    required this.isSuccess,
    this.errorCode,
    this.errorMessage,
    required this.requests,
  });

  factory QrFetchResult.success(List<QrRequestModel> requests) {
    return QrFetchResult(isSuccess: true, requests: requests);
  }

  factory QrFetchResult.error(
    String code,
    String message, {
    List<QrRequestModel>? previous,
  }) {
    return QrFetchResult(
      isSuccess: false,
      errorCode: code,
      errorMessage: message,
      requests: previous ?? const [],
    );
  }
}

/// Repository quản lý QR Order V4 (Không phụ thuộc POS device pairing, cô lập store_id)
class QrOrderRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'];
  }

  // ── Settings ─────────────────────────────────────────────────────────────────
  Future<QrOrderSettingsModel> getSettings() async {
    final storeId = await _storeId();
    if (storeId == null) return const QrOrderSettingsModel();
    try {
      final row = await _sb
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', 'qr_order_settings')
          .maybeSingle();
      if (row == null || row['value'] == null) {
        return const QrOrderSettingsModel();
      }

      final map = jsonDecode(row['value'] as String);
      return QrOrderSettingsModel.fromMap(map);
    } catch (e) {
      debugPrint('[QrOrderRepo] getSettings error: $e');
      return const QrOrderSettingsModel();
    }
  }

  /// Lưu cấu hình. Trả `true` khi ghi thành công, `false` khi lỗi thật
  /// (không có quán hoặc server từ chối) để UI báo đúng.
  Future<bool> saveSettings(QrOrderSettingsModel settings) async {
    final storeId = await _storeId();
    if (storeId == null) return false;
    try {
      await _sb.from('app_settings').upsert({
        'id': _uuid.v4(),
        'store_id': storeId,
        'key': 'qr_order_settings',
        'value': jsonEncode(settings.toMap()),
      }, onConflict: 'store_id,key');
      return true;
    } catch (e) {
      debugPrint('[QrOrderRepo] saveSettings error: $e');
      return false;
    }
  }

  // ── Helper gọi RPC thống nhất ────────────────────────────────────────────────
  static const String _networkMsg =
      'Mất kết nối. Vui lòng kiểm tra mạng rồi thử lại.';
  static const String _schemaOutdatedMsg =
      'Máy chủ chưa được cập nhật tính năng QR gọi món. Vui lòng báo quản lý kỹ thuật.';

  /// Hàm/bảng QR chưa có trên server (chưa áp migration) khác với mất mạng.
  static bool _isServerSchemaMissing(Object e) {
    if (e is PostgrestException) {
      const codes = {'PGRST202', 'PGRST205', '42883', '42P01'};
      return codes.contains(e.code);
    }
    return false;
  }

  Future<QrRpcResponse<T>> _rpc<T>(
    String fn,
    Map<String, dynamic> params,
    T Function(Map<String, dynamic> data) parse, {
    required String failMessage,
    String failCode = QrErrorCode.rpcError,
  }) async {
    try {
      final res = await _sb.rpc(fn, params: params);
      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => parse(
            data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{},
          ),
        );
      }
      return QrRpcResponse.error(failCode, failMessage);
    } catch (e) {
      // Chi tiết kỹ thuật chỉ ghi log, không đưa lên UI người dùng.
      debugPrint('[QrOrderRepo] $fn error: $e');
      if (_isServerSchemaMissing(e)) {
        return QrRpcResponse.error(
          QrErrorCode.serverSchemaOutdated,
          _schemaOutdatedMsg,
        );
      }
      return QrRpcResponse.error(QrErrorCode.networkError, _networkMsg);
    }
  }

  // ── Channel Management (RPC manage_qr_channel_v4) ──────────────────────────
  Future<QrRpcResponse<QrChannelModel>> manageQrChannel({
    required String storeId,
    required String type,
    required bool isActive,
    String paymentMode = 'CASHIER_CONFIRM',
  }) {
    return _rpc(
      'manage_qr_channel_v4',
      {
        'p_store_id': storeId,
        'p_type': type,
        'p_is_active': isActive,
        'p_payment_mode': paymentMode,
      },
      QrChannelModel.fromMap,
      failMessage: 'Cấu hình kênh QR thất bại',
    );
  }

  /// Reads channel state without mutating it. Opening the QR module must never
  /// re-enable a channel that the owner intentionally disabled.
  Future<QrChannelModel?> getChannelByType({
    required String storeId,
    required String type,
  }) async {
    try {
      final row = await _sb
          .from('qr_channels')
          .select()
          .eq('store_id', storeId)
          .eq('type', type)
          .maybeSingle();
      if (row == null) return null;
      return QrChannelModel.fromMap(Map<String, dynamic>.from(row));
    } catch (e) {
      debugPrint('[QrOrderRepo] getChannelByType error: $e');
      return null;
    }
  }

  // ── Public RPC ───────────────────────────────────────────────────────────────
  Future<QrRpcResponse<QrChannelModel>> fetchChannelInfo(String channelCode) {
    return _rpc(
      'get_qr_channel_info_v4',
      {'p_channel_code': channelCode},
      QrChannelModel.fromMap,
      failMessage: 'Mã QR không hợp lệ',
      failCode: QrErrorCode.invalidQr,
    );
  }

  Future<QrRpcResponse<Map<String, dynamic>>> fetchQrMenu(String channelCode) {
    return _rpc(
      'get_qr_menu_v4',
      {'p_channel_code': channelCode},
      (d) => d,
      failMessage: 'Lỗi tải menu',
    );
  }

  /// Khách gửi đơn. TABLE bắt buộc [tableId]; COUNTER bỏ qua.
  Future<QrRpcResponse<Map<String, dynamic>>> submitQrOrder({
    required String channelCode,
    required List<Map<String, dynamic>> items,
    String? tableId,
    String? idempotencyKey,
    String? payloadHash,
  }) {
    return _rpc(
      'submit_qr_order_v4',
      {
        'p_channel_code': channelCode,
        'p_items': items,
        'p_table_id': tableId,
        'p_idempotency_key': idempotencyKey,
        'p_payload_hash': payloadHash,
      },
      (d) => d,
      failMessage: 'Gửi đơn thất bại',
    );
  }

  Future<QrRpcResponse<QrRequestModel>> checkRequestStatus(
    String trackingToken,
  ) {
    return _rpc(
      'get_qr_request_status_v4',
      {'p_tracking_token': trackingToken},
      QrRequestModel.fromMap,
      failMessage: 'Không tìm thấy đơn hàng',
      failCode: QrErrorCode.invalidState,
    );
  }

  // ── Staff RPC ────────────────────────────────────────────────────────────────
  /// Nhận đơn từ hàng chờ (submitted → claimed). Gọi lại bởi chính người nhận
  /// vẫn trả chi tiết đơn.
  Future<QrRpcResponse<QrRequestModel>> claimRequest({
    required String requestId,
    required String storeId,
  }) {
    return _rpc(
      'claim_qr_request_v4',
      {'p_request_id': requestId, 'p_store_id': storeId},
      QrRequestModel.fromMap,
      failMessage: 'Tiếp nhận đơn thất bại',
    );
  }

  Future<QrRpcResponse<QrRequestModel>> getRequestDetail({
    required String requestId,
    required String storeId,
  }) {
    return _rpc(
      'get_qr_request_detail_v4',
      {'p_request_id': requestId, 'p_store_id': storeId},
      QrRequestModel.fromMap,
      failMessage: 'Không lấy được chi tiết đơn',
    );
  }

  Future<QrRpcResponse<Map<String, dynamic>>> updateOrderItems({
    required String requestId,
    required String storeId,
    required int expectedVersion,
    required List<Map<String, dynamic>> items,
  }) {
    return _rpc(
      'update_qr_order_items_v4',
      {
        'p_request_id': requestId,
        'p_store_id': storeId,
        'p_expected_version': expectedVersion,
        'p_items': items,
      },
      (d) => d,
      failMessage: 'Cập nhật món thất bại',
    );
  }

  /// Đổi bàn khi đơn đang `claimed`.
  Future<QrRpcResponse<Map<String, dynamic>>> setOrderTable({
    required String requestId,
    required String storeId,
    required String tableId,
  }) {
    return _rpc(
      'set_qr_order_table_v4',
      {'p_request_id': requestId, 'p_store_id': storeId, 'p_table_id': tableId},
      (d) => d,
      failMessage: 'Đổi bàn thất bại',
    );
  }

  /// TABLE: duyệt và gửi bếp trong một giao dịch.
  Future<QrRpcResponse<Map<String, dynamic>>> approveAndSendTable({
    required String requestId,
    required String storeId,
    required int version,
  }) {
    return _rpc(
      'approve_and_send_table_v4',
      {'p_request_id': requestId, 'p_store_id': storeId, 'p_version': version},
      (d) => d,
      failMessage: 'Duyệt đơn thất bại',
    );
  }

  /// COUNTER: thu tiền và gửi bếp trong một giao dịch (cần quyền thu tiền).
  Future<QrRpcResponse<Map<String, dynamic>>> payAndSendCounter({
    required String requestId,
    required String storeId,
    required int version,
    required String paymentMethod,
  }) {
    return _rpc(
      'pay_and_send_counter_v4',
      {
        'p_request_id': requestId,
        'p_store_id': storeId,
        'p_version': version,
        'p_payment_method': paymentMethod,
      },
      (d) => d,
      failMessage: 'Thu tiền và gửi bếp thất bại',
    );
  }

  Future<QrRpcResponse<Map<String, dynamic>>> settleBanSession({
    required String sessionId,
    required String storeId,
    String paymentMethod = 'cash',
    required String idempotencyKey,
    String? customerId,
    int pointsUsed = 0,
    double discount = 0,
    String? couponCode,
    double surcharge = 0,
  }) {
    return _rpc(
      'settle_ban_session_v5',
      {
        'p_session_id': sessionId,
        'p_store_id': storeId,
        'p_payment_method': paymentMethod,
        'p_idempotency_key': idempotencyKey,
        'p_customer_id': customerId,
        'p_points_used': pointsUsed,
        'p_discount': discount,
        'p_coupon_code': couponCode,
        'p_surcharge': surcharge,
      },
      (d) => d,
      failMessage: 'Quyết toán phiên bàn thất bại',
    );
  }

  Future<QrRpcResponse<Map<String, dynamic>>> cancelOrder({
    required String requestId,
    required String storeId,
    String? reason,
  }) {
    return _rpc(
      'cancel_qr_order_v4',
      {'p_request_id': requestId, 'p_store_id': storeId, 'p_reason': reason},
      (d) => d,
      failMessage: 'Từ chối đơn thất bại',
    );
  }

  // ── Hàng chờ chung (TABLE + COUNTER), cô lập theo store_id ───────────────────
  Map<String, String> _tableNames = const {};
  DateTime? _tableNamesAt;

  Future<Map<String, String>> _loadTableNames(String storeId) async {
    final at = _tableNamesAt;
    if (at != null && DateTime.now().difference(at).inMinutes < 2) {
      return _tableNames;
    }
    try {
      final rows = await _sb
          .from('ban_dining_tables')
          .select('id,name')
          .eq('store_id', storeId);
      _tableNames = {
        for (final r in rows as List)
          if (r is Map && r['id'] != null)
            r['id'].toString(): (r['name'] ?? '').toString(),
      };
      _tableNamesAt = DateTime.now();
    } catch (e) {
      debugPrint('[QrOrderRepo] loadTableNames error: $e');
    }
    return _tableNames;
  }

  Future<QrFetchResult> fetchActiveRequestsPipeline({
    required String storeId,
    List<QrRequestModel>? previousRequests,
  }) async {
    if (storeId.isEmpty) {
      return QrFetchResult.success(const []);
    }

    try {
      final rows = await _sb
          .from('qr_requests')
          .select(
            'id,store_id,channel_id,type,status,payment_status,table_id,'
            'pickup_code,total_amount,version,claimed_by,created_at,'
            'expires_at,items:qr_request_items(id,request_id,product_id,'
            'product_name,unit_price,quantity,subtotal,modifiers_json,note)',
          )
          .eq('store_id', storeId)
          .inFilter('status', [QrStatus.submitted, QrStatus.claimed])
          .order('created_at', ascending: true);

      final names = await _loadTableNames(storeId);
      final requests = (rows as List).map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        final tid = map['table_id']?.toString();
        if (tid != null && names[tid] != null) {
          map['table_name'] = names[tid];
        }
        return QrRequestModel.fromMap(map);
      }).toList();

      return QrFetchResult.success(requests);
    } catch (e) {
      debugPrint('[QrOrderRepo] fetchActiveRequestsPipeline error: $e');
      final missing = _isServerSchemaMissing(e);
      return QrFetchResult.error(
        missing ? QrErrorCode.serverSchemaOutdated : QrErrorCode.networkError,
        missing ? _schemaOutdatedMsg : _networkMsg,
        previous: previousRequests,
      );
    }
  }
}
