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

  Future<void> saveSettings(QrOrderSettingsModel settings) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    try {
      await _sb.from('app_settings').upsert({
        'id': _uuid.v4(),
        'store_id': storeId,
        'key': 'qr_order_settings',
        'value': jsonEncode(settings.toMap()),
      }, onConflict: 'store_id,key');
    } catch (e) {
      debugPrint('[QrOrderRepo] saveSettings error: $e');
    }
  }

  // ── Channel Management (RPC manage_qr_channel_v4) ──────────────────────────
  Future<QrRpcResponse<QrChannelModel>> manageQrChannel({
    required String storeId,
    required String type,
    required bool isActive,
    String paymentMode = 'CASHIER_CONFIRM',
  }) async {
    try {
      final res = await _sb.rpc(
        'manage_qr_channel_v4',
        params: {
          'p_store_id': storeId,
          'p_type': type,
          'p_is_active': isActive,
          'p_payment_mode': paymentMode,
        },
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => QrChannelModel.fromMap(data as Map<String, dynamic>),
        );
      }
      return QrRpcResponse.error(
        QrErrorCode.rpcError,
        'Cấu hình kênh QR thất bại',
      );
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối cấu hình kênh: $e',
      );
    }
  }

  Future<QrChannelModel?> ensureTableSharedChannel({
    required String storeId,
  }) async {
    final res = await manageQrChannel(
      storeId: storeId,
      type: 'TABLE_SHARED',
      isActive: true,
      paymentMode: 'PAY_BEFORE_KITCHEN',
    );
    return res.data;
  }

  Future<QrChannelModel?> ensureCounterChannel({
    required String storeId,
    String paymentMode = 'CASHIER_CONFIRM',
  }) async {
    final res = await manageQrChannel(
      storeId: storeId,
      type: 'COUNTER_TAKEAWAY',
      isActive: true,
      paymentMode: paymentMode,
    );
    return res.data;
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

  // ── Public RPC 1: Channel Info ───────────────────────────────────────────────
  Future<QrRpcResponse<QrChannelModel>> fetchChannelInfo(
    String channelCode,
  ) async {
    try {
      final res = await _sb.rpc(
        'get_qr_channel_info_v4',
        params: {'p_channel_code': channelCode},
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => QrChannelModel.fromMap(data as Map<String, dynamic>),
        );
      }
      return QrRpcResponse.error(QrErrorCode.invalidQr, 'Mã QR không hợp lệ');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối máy chủ: $e',
      );
    }
  }

  // ── Public RPC 2: Fetch Menu ─────────────────────────────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> fetchQrMenu(
    String channelCode,
  ) async {
    try {
      final res = await _sb.rpc(
        'get_qr_menu_v4',
        params: {'p_channel_code': channelCode},
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Lỗi tải menu');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối tải menu: $e',
      );
    }
  }

  // ── Public RPC 3: Customer Submit Order ──────────────────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> submitQrOrder({
    required String channelCode,
    required List<Map<String, dynamic>> items,
    String? tableHint,
    String? idempotencyKey,
    String? payloadHash,
  }) async {
    try {
      final res = await _sb.rpc(
        'submit_qr_order_v4',
        params: {
          'p_channel_code': channelCode,
          'p_items': items,
          'p_table_hint': tableHint,
          'p_idempotency_key': idempotencyKey,
          'p_payload_hash': payloadHash,
        },
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Gửi đơn thất bại');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi gửi đơn hàng: $e',
      );
    }
  }

  // ── Public RPC 4: Customer Status Tracking ──────────────────────────────────
  Future<QrRpcResponse<QrRequestModel>> checkRequestStatus(
    String trackingToken,
  ) async {
    try {
      final res = await _sb.rpc(
        'get_qr_request_status_v4',
        params: {'p_tracking_token': trackingToken},
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => QrRequestModel.fromMap(data as Map<String, dynamic>),
        );
      }
      return QrRpcResponse.error(
        QrErrorCode.invalidState,
        'Không tìm thấy đơn hàng',
      );
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kiểm tra trạng thái đơn: $e',
      );
    }
  }

  // ── Public RPC 5: Customer Regenerate Handoff Token ──────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> regenerateHandoffToken(
    String trackingToken,
  ) async {
    try {
      final res = await _sb.rpc(
        'regenerate_handoff_token_v4',
        params: {'p_tracking_token': trackingToken},
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Lỗi tạo lại mã QR');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối tạo lại mã QR: $e',
      );
    }
  }

  // ── Staff RPC 6: Atomic Claim Handoff Token ──────────────────────────────────
  Future<QrRpcResponse<QrRequestModel>> claimHandoffToken({
    required String rawHandoffToken,
    required String storeId,
  }) async {
    try {
      final res = await _sb.rpc(
        'claim_qr_handoff_v4',
        params: {'p_token': rawHandoffToken, 'p_store_id': storeId},
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) =>
              QrRequestModel.fromMap(Map<String, dynamic>.from(data as Map)),
        );
      }
      return QrRpcResponse.error(
        QrErrorCode.rpcError,
        'Tiếp nhận đơn thất bại',
      );
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối tiếp nhận đơn: $e',
      );
    }
  }

  // ── Staff RPC 7: Get Request Detail ──────────────────────────────────────────
  Future<QrRpcResponse<QrRequestModel>> getRequestDetail({
    required String requestId,
    required String storeId,
  }) async {
    try {
      final res = await _sb.rpc(
        'get_qr_request_detail_v4',
        params: {'p_request_id': requestId, 'p_store_id': storeId},
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => QrRequestModel.fromMap(data as Map<String, dynamic>),
        );
      }
      return QrRpcResponse.error(
        QrErrorCode.rpcError,
        'Không lấy được chi tiết đơn',
      );
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối lấy chi tiết đơn: $e',
      );
    }
  }

  // ── Staff RPC 8: Update Order Items (Optimistic Lock) ────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> updateOrderItems({
    required String requestId,
    required String storeId,
    required int expectedVersion,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      final res = await _sb.rpc(
        'update_qr_order_items_v4',
        params: {
          'p_request_id': requestId,
          'p_store_id': storeId,
          'p_expected_version': expectedVersion,
          'p_items': items,
        },
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Cập nhật món thất bại');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối cập nhật món: $e',
      );
    }
  }

  // ── Staff RPC 9: Assign Table ────────────────────────────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> assignTable({
    required String requestId,
    required String tableId,
    required String storeId,
  }) async {
    try {
      final res = await _sb.rpc(
        'assign_qr_order_table_v4',
        params: {
          'p_request_id': requestId,
          'p_table_id': tableId,
          'p_store_id': storeId,
        },
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Gán bàn thất bại');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối gán bàn: $e',
      );
    }
  }

  // ── Staff RPC 10: Mark Order Paid (Counter) ──────────────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> markOrderPaid({
    required String requestId,
    required String storeId,
    String paymentMethod = 'cash',
    String? idempotencyKey,
  }) async {
    try {
      final res = await _sb.rpc(
        'mark_qr_order_paid_v4',
        params: {
          'p_request_id': requestId,
          'p_store_id': storeId,
          'p_payment_method': paymentMethod,
          'p_idempotency_key': idempotencyKey,
        },
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Thanh toán thất bại');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối thanh toán: $e',
      );
    }
  }

  // ── Staff RPC 11: Send To Kitchen ────────────────────────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> sendToKitchen({
    required String requestId,
    required String storeId,
    required String idempotencyKey,
    String? orderNote,
  }) async {
    try {
      final res = await _sb.rpc(
        'send_qr_order_to_kitchen_v4',
        params: {
          'p_request_id': requestId,
          'p_store_id': storeId,
          'p_idempotency_key': idempotencyKey,
          'p_order_note': orderNote,
        },
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Gửi bếp thất bại');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối gửi bếp: $e',
      );
    }
  }

  // ── Staff RPC 12: Settle Ban Session ─────────────────────────────────────────
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
  }) async {
    try {
      final res = await _sb.rpc(
        'settle_ban_session_v5',
        params: {
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
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(
        QrErrorCode.rpcError,
        'Quyết toán phiên bàn thất bại',
      );
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối quyết toán bàn: $e',
      );
    }
  }

  // ── Staff RPC 12: Cancel Order ───────────────────────────────────────────────
  Future<QrRpcResponse<Map<String, dynamic>>> cancelOrder({
    required String requestId,
    required String storeId,
    String? reason,
  }) async {
    try {
      final res = await _sb.rpc(
        'cancel_qr_order_v4',
        params: {
          'p_request_id': requestId,
          'p_store_id': storeId,
          'p_reason': reason,
        },
      );

      if (res is Map) {
        return QrRpcResponse.fromMap(
          Map<String, dynamic>.from(res),
          (data) => Map<String, dynamic>.from(data as Map),
        );
      }
      return QrRpcResponse.error(QrErrorCode.rpcError, 'Hủy đơn thất bại');
    } catch (e) {
      return QrRpcResponse.error(
        QrErrorCode.networkError,
        'Lỗi kết nối hủy đơn: $e',
      );
    }
  }

  // ── Pipeline Stream (Isolated by Store ID) ───────────────────────────────────
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
            '*, items:qr_request_items(*), table:ban_dining_tables(label), channel:qr_channels(payment_mode)',
          )
          .eq('store_id', storeId)
          .inFilter('status', [
            'customer_submitted',
            'claimed',
            'staff_review',
            'awaiting_payment',
            'ready_for_kitchen',
          ])
          .order('created_at', ascending: false);

      final requests = (rows as List).map((r) {
        final map = Map<String, dynamic>.from(r as Map);
        if (map['table'] != null && map['table']['label'] != null) {
          map['assigned_table_name'] = map['table']['label'];
        }
        if (map['channel'] != null && map['channel']['payment_mode'] != null) {
          map['payment_mode'] = map['channel']['payment_mode'];
        }
        return QrRequestModel.fromMap(map);
      }).toList();

      return QrFetchResult.success(requests);
    } catch (e) {
      debugPrint('[QrOrderRepo] fetchActiveRequestsPipeline error: $e');
      return QrFetchResult.error(
        QrErrorCode.networkError,
        'Lỗi kết nối danh sách đơn: $e',
        previous: previousRequests,
      );
    }
  }
}
