import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';

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
    return info['store_id'] as String?;
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
      if (row == null || row['value'] == null) return const QrOrderSettingsModel();
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
      // Return null on DB error - no fake link objects!
      return null;
    }
  }

  Future<QrChannelModel?> ensureCounterChannel({required String storeId}) async {
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

  // ── Customer Public Menu (RPC `get_qr_menu`) ────────────────────────────────
  Future<Map<String, dynamic>> fetchQrMenu(String channelCode) async {
    try {
      final res = await _sb.rpc('get_qr_menu', params: {'p_channel_code': channelCode});
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Lỗi tải menu'
            : 'Hệ thống QR Gọi Món chưa được cấu hình trên Supabase (chưa chạy migration SQL).'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Hệ thống QR Gọi Món chưa được cấu hình trên Supabase (chưa chạy migration SQL).'
      };
    }
  }

  // ── Customer Submit Order (RPC `submit_qr_order`) ─────────────────────────────
  Future<Map<String, dynamic>> submitQrOrder({
    required String channelCode,
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    try {
      final res = await _sb.rpc('submit_qr_order', params: {
        'p_channel_code': channelCode,
        'p_items': items,
        'p_note': note,
      });

      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
      return {
        'success': false,
        'message': res is Map
            ? res['message'] ?? 'Gửi đơn thất bại'
            : 'Hệ thống QR Gọi Món chưa được cấu hình trên Supabase (chưa chạy migration SQL).'
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Hệ thống QR Gọi Món chưa được cấu hình trên Supabase (chưa chạy migration SQL).'
      };
    }
  }

  // ── Staff Atomic Claim (Claim Request before Processing) ────────────────────
  Future<bool> claimRequest(String requestId) async {
    try {
      final res = await _sb.rpc('claim_qr_request', params: {'p_request_id': requestId});
      if (res is Map && res['success'] == true) {
        return true;
      }
    } catch (_) {}

    // Atomic SQL fallback update
    try {
      final rows = await _sb
          .from('qr_requests')
          .update({'status': 'processing', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', requestId)
          .eq('status', 'pending_staff')
          .select('id');
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── Watch Pending Requests (Realtime Stream / Continuous Poll) ─────────────
  Stream<List<QrRequestModel>> watchPendingRequests(String storeId, {String? type}) async* {
    while (true) {
      try {
        var query = _sb
            .from('qr_requests')
            .select('*, items:qr_request_items(*)')
            .eq('store_id', storeId)
            .eq('status', 'pending_staff');

        if (type != null) {
          query = query.eq('type', type);
        }

        final rows = await query.order('created_at', ascending: false);
        final list = rows
            .map((r) => QrRequestModel.fromMap(r as Map<String, dynamic>))
            .toList();

        yield list;
      } catch (e) {
        yield [];
      }

      // Poll every 3 seconds
      await Future.delayed(const Duration(seconds: 3));
    }
  }

  // ── Update Request Status ─────────────────────────────────────────────────
  Future<void> updateRequestStatus(String requestId, String status) async {
    await _sb.from('qr_requests').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', requestId);
  }

  // ── Customer Order Status Check ──────────────────────────────────────────────
  Future<Map<String, dynamic>> checkRequestStatus(String trackingToken) async {
    try {
      final res = await _sb.rpc('get_qr_request_status', params: {'p_tracking_token': trackingToken});
      if (res is Map && res['success'] == true) {
        return Map<String, dynamic>.from(res);
      }
    } catch (_) {}

    return {'success': false, 'message': 'Không tìm thấy trạng thái'};
  }
}
