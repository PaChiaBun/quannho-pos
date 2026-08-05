import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/services/pos_device_token_service.dart';
import '../models/qr_order_model.dart';

/// Class chứa kết quả fetch danh sách đơn QR phân biệt rõ lỗi với danh sách rỗng
class QrFetchResult {
  final bool isSuccess;
  final String?
  errorCode; // 'NO_POS_TOKEN' | 'NETWORK_ERROR' | 'RPC_ERROR' | null
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

/// Repository quản lý QR Gọi Món (Architecture V3)
class QrOrderRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();
  final _rnd = Random.secure();

  String _generateEntropyToken(String prefix) {
    final values = List<int>.generate(8, (i) => _rnd.nextInt(256));
    final hex = values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${prefix}_$hex'.toUpperCase();
  }

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
      debugPrint('[QrOrderRepo] Save settings error: $e');
    }
  }

  // ── Channels Management (High Entropy Tokens) ──────────────────────────────
  Future<QrChannelModel?> ensureChannelForTable({
    required String storeId,
    required String tableId,
    required String tableName,
  }) async {
    try {
      final existing = await _sb
          .from('qr_channels')
          .select()
          .eq('store_id', storeId)
          .eq('table_id', tableId)
          .eq('type', 'table')
          .maybeSingle();

      if (existing != null) {
        return QrChannelModel.fromMap(existing);
      }

      final channelCode = _generateEntropyToken('TBL');
      final id = _uuid.v4();
      final row = {
        'id': id,
        'store_id': storeId,
        'type': 'table',
        'table_id': tableId,
        'channel_code': channelCode,
        'name': tableName,
        'is_active': true,
      };

      await _sb.from('qr_channels').insert(row);
      return QrChannelModel.fromMap(row);
    } catch (e) {
      debugPrint('[QrOrderRepo] ensureChannelForTable DB error: $e');
      return null;
    }
  }

  Future<QrChannelModel?> ensureCounterChannel({
    required String storeId,
  }) async {
    try {
      final existing = await _sb
          .from('qr_channels')
          .select()
          .eq('store_id', storeId)
          .eq('type', 'counter')
          .maybeSingle();

      if (existing != null) {
        return QrChannelModel.fromMap(existing);
      }

      final channelCode = _generateEntropyToken('CTR');
      final id = _uuid.v4();
      final row = {
        'id': id,
        'store_id': storeId,
        'type': 'counter',
        'table_id': null,
        'channel_code': channelCode,
        'name': 'Quầy Thu Ngân',
        'is_active': true,
      };

      await _sb.from('qr_channels').insert(row);
      return QrChannelModel.fromMap(row);
    } catch (e) {
      debugPrint('[QrOrderRepo] ensureCounterChannel DB error: $e');
      return null;
    }
  }

  // ── Customer Public Menu (RPC `get_qr_menu_v3`) ──────────────────────────────
  Future<Map<String, dynamic>> fetchQrMenu(String channelCode) async {
    try {
      final res = await _sb.rpc(
        'get_qr_menu_v3',
        params: {'p_channel_code': channelCode},
      );
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Lỗi tải menu'
            : 'Lỗi tải menu',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Không thể kết nối đến hệ thống menu: $e',
      };
    }
  }

  // ── Customer Submit Order (RPC `submit_qr_order_v3`) ─────────────────────────
  Future<Map<String, dynamic>> submitQrOrder({
    required String channelCode,
    required List<Map<String, dynamic>> items,
    String? note,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey ?? _uuid.v4();
      final res = await _sb.rpc(
        'submit_qr_order_v3',
        params: {
          'p_channel_code': channelCode,
          'p_items': items,
          'p_note': note ?? '',
          'p_idempotency_key': key,
        },
      );

      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Gửi đơn thất bại'
            : 'Gửi đơn thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi gửi đơn hàng: $e'};
    }
  }

  // ── Customer Order Status Check (RPC `get_qr_request_status_v3`) ─────────────
  Future<Map<String, dynamic>> checkRequestStatus(String trackingToken) async {
    try {
      final res = await _sb.rpc(
        'get_qr_request_status_v3',
        params: {'p_tracking_token': trackingToken},
      );
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}

    return {'success': false, 'message': 'Không tìm thấy trạng thái đơn hàng'};
  }

  // ── Staff RPC 1: Fetch Active Requests Pipeline (RPC `get_pending_qr_requests_v3`) ──
  // Hàng đợi phục hồi: gom 3 trạng thái pending_staff, processing, confirmed
  // Phân biệt rõ lỗi token, lỗi mạng, lỗi RPC thay vì nuốt lỗi thành danh sách rỗng
  Future<QrFetchResult> fetchActiveRequestsPipeline({
    List<QrRequestModel>? previousRequests,
  }) async {
    final rawToken = await PosDeviceTokenService.getRawToken();
    if (rawToken == null) {
      return QrFetchResult.error(
        'NO_POS_TOKEN',
        'POS Device Session token không tồn tại hoặc đã hết hạn. Vui lòng xác thực lại thiết bị.',
        previous: previousRequests,
      );
    }

    try {
      final combined = <QrRequestModel>[];
      final seenIds = <String>{};

      // Gọi fetch các trạng thái nằm trong hàng đợi active: pending_staff, processing, confirmed
      for (final status in ['pending_staff', 'processing', 'confirmed']) {
        final res = await _sb.rpc(
          'get_pending_qr_requests_v3',
          params: {'p_raw_token': rawToken, 'p_filter_status': status},
        );

        if (res is List) {
          for (final item in res) {
            final model = QrRequestModel.fromMap(item as Map<String, dynamic>);
            if (!seenIds.contains(model.id)) {
              seenIds.add(model.id);
              combined.add(model);
            }
          }
        }
      }

      return QrFetchResult.success(combined);
    } on PostgrestException catch (e) {
      return QrFetchResult.error(
        'RPC_ERROR',
        'Lỗi từ backend database (RPC): ${e.message}',
        previous: previousRequests,
      );
    } catch (e) {
      return QrFetchResult.error(
        'NETWORK_ERROR',
        'Lỗi kết nối mạng hoặc server: $e',
        previous: previousRequests,
      );
    }
  }

  // ── Staff RPC 2: Claim Request (RPC `claim_qr_request_v3`) ───────────────────
  Future<Map<String, dynamic>> claimRequestV3(String requestId) async {
    final rawToken = await PosDeviceTokenService.getRawToken();
    if (rawToken == null) {
      return {
        'success': false,
        'error_code': 'NO_POS_TOKEN',
        'message': 'POS session token không tồn tại hoặc đã hết hạn.',
      };
    }

    try {
      final res = await _sb.rpc(
        'claim_qr_request_v3',
        params: {'p_request_id': requestId, 'p_raw_token': rawToken},
      );

      if (res is Map &&
          (res['status'] == 'processing' || res['success'] == true)) {
        return {'success': true, 'status': 'processing'};
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Claim thất bại'
            : 'Claim thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi claim đơn: $e'};
    }
  }

  // ── Staff RPC 3: Confirm Request (RPC `confirm_qr_request_v3`) ───────────────
  Future<Map<String, dynamic>> confirmRequestV3(String requestId) async {
    final rawToken = await PosDeviceTokenService.getRawToken();
    if (rawToken == null) {
      return {
        'success': false,
        'error_code': 'NO_POS_TOKEN',
        'message': 'POS session token không tồn tại hoặc đã hết hạn.',
      };
    }

    try {
      final res = await _sb.rpc(
        'confirm_qr_request_v3',
        params: {'p_request_id': requestId, 'p_raw_token': rawToken},
      );

      if (res is Map &&
          (res['status'] == 'confirmed' || res['success'] == true)) {
        return {'success': true, 'status': 'confirmed'};
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Xác nhận đơn thất bại'
            : 'Xác nhận đơn thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi xác nhận đơn: $e'};
    }
  }

  // ── Staff RPC 4: Send To Kitchen (RPC `send_to_kitchen_qr_v3`) ───────────────
  Future<Map<String, dynamic>> sendToKitchenV3(String requestId) async {
    final rawToken = await PosDeviceTokenService.getRawToken();
    if (rawToken == null) {
      return {
        'success': false,
        'error_code': 'NO_POS_TOKEN',
        'message': 'POS session token không tồn tại hoặc đã hết hạn.',
      };
    }

    try {
      final res = await _sb.rpc(
        'send_to_kitchen_qr_v3',
        params: {'p_request_id': requestId, 'p_raw_token': rawToken},
      );

      if (res is Map &&
          (res['status'] == 'sent_kitchen' || res['success'] == true)) {
        return {'success': true, 'status': 'sent_kitchen'};
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Gửi bếp thất bại'
            : 'Gửi bếp thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi gửi bếp: $e'};
    }
  }

  // ── Staff RPC 5: Reject Request (RPC `reject_qr_request_v3`) ─────────────────
  Future<Map<String, dynamic>> rejectRequestV3(
    String requestId, {
    String reason = 'Từ chối bởi nhân viên',
  }) async {
    final rawToken = await PosDeviceTokenService.getRawToken();
    if (rawToken == null) {
      return {
        'success': false,
        'error_code': 'NO_POS_TOKEN',
        'message': 'POS session token không tồn tại hoặc đã hết hạn.',
      };
    }

    try {
      final res = await _sb.rpc(
        'reject_qr_request_v3',
        params: {
          'p_request_id': requestId,
          'p_raw_token': rawToken,
          'p_reject_reason': reason,
        },
      );

      if (res is Map &&
          (res['status'] == 'rejected' || res['success'] == true)) {
        return {'success': true, 'status': 'rejected'};
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Từ chối đơn thất bại'
            : 'Từ chối đơn thất bại',
      };
    } catch (e) {
      return {'success': false, 'message': 'Lỗi từ chối đơn: $e'};
    }
  }
}
