import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service quản lý POS Device Token Session (QR Architecture V3)
/// Token chỉ được lưu trong FlutterSecureStorage.
/// Tuyệt đối KHÔNG ghi token, PIN hoặc credential vào log!
class PosDeviceTokenService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _kRawTokenKey = 'pos_v3_raw_token';
  static const _kDeviceIdKey = 'pos_v3_device_id';
  static const _kExpiresAtKey = 'pos_v3_expires_at';
  static const _kStoreCodeKey = 'pos_v3_store_code';

  static SupabaseClient get _sb => Supabase.instance.client;

  /// Đọc token hiện tại từ secure storage. Trả về null nếu chưa có hoặc đã hết hạn.
  static Future<String?> getRawToken() async {
    try {
      final token = await _storage.read(key: _kRawTokenKey);
      if (token == null || token.trim().isEmpty) return null;

      final expiresAtStr = await _storage.read(key: _kExpiresAtKey);
      if (expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
          // Token đã hết hạn -> Xóa token
          await clearTokenSession();
          return null;
        }
      }
      return token.trim();
    } catch (e) {
      debugPrint('[PosDeviceTokenService] Error reading token: $e');
      return null;
    }
  }

  /// Đọc Device ID đã được cấp
  static Future<String?> getDeviceId() async {
    try {
      return await _storage.read(key: _kDeviceIdKey);
    } catch (_) {
      return null;
    }
  }

  /// Đọc Store Code đã lưu
  static Future<String?> getStoreCode() async {
    try {
      return await _storage.read(key: _kStoreCodeKey);
    } catch (_) {
      return null;
    }
  }

  /// Kiểm tra chi tiết trạng thái session hiện tại:
  /// - 'not_activated': Chưa kích hoạt / Chưa ghép thiết bị
  /// - 'active': Đang hoạt động hợp lệ
  /// - 'expired': Session token đã hết hạn
  /// - 'auth_error': Lỗi xác thực
  static Future<String> getDeviceSessionStatus() async {
    try {
      final rawToken = await _storage.read(key: _kRawTokenKey);
      final deviceId = await _storage.read(key: _kDeviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        return 'not_activated';
      }

      if (rawToken == null || rawToken.isEmpty) {
        return 'expired';
      }

      final expiresAtStr = await _storage.read(key: _kExpiresAtKey);
      if (expiresAtStr != null) {
        final expiresAt = DateTime.tryParse(expiresAtStr);
        if (expiresAt != null && DateTime.now().toUtc().isAfter(expiresAt)) {
          return 'expired';
        }
      }

      return 'active';
    } catch (e) {
      return 'auth_error';
    }
  }

  /// Lưu token session mới vào secure storage.
  /// Thăng hoa ngoại lệ nếu SecureStorage lưu thất bại để không báo kích hoạt thành công giả!
  static Future<void> saveTokenSession({
    required String rawToken,
    required String deviceId,
    String? expiresAt,
    String? storeCode,
  }) async {
    await _storage.write(key: _kRawTokenKey, value: rawToken.trim());
    await _storage.write(key: _kDeviceIdKey, value: deviceId.trim());
    if (expiresAt != null) {
      await _storage.write(key: _kExpiresAtKey, value: expiresAt);
    }
    if (storeCode != null) {
      await _storage.write(key: _kStoreCodeKey, value: storeCode.trim());
    }
  }

  /// Xóa sạch thông tin session token khi logout/revoke hoặc token hết hạn
  static Future<void> clearTokenSession() async {
    try {
      await _storage.delete(key: _kRawTokenKey);
      await _storage.delete(key: _kExpiresAtKey);
    } catch (e) {
      debugPrint('[PosDeviceTokenService] Error clearing token: $e');
    }
  }

  /// Cấp mới POS Device Session bằng RPC `issue_pos_device_session_v3`
  static Future<Map<String, dynamic>> issueSession({
    required String storeCode,
    required String authMode,
    required String credential,
    required String deviceId,
  }) async {
    try {
      final res = await _sb.rpc(
        'issue_pos_device_session_v3',
        params: {
          'p_store_code': storeCode.trim().toUpperCase(),
          'p_auth_mode': authMode,
          'p_credential': credential.trim(),
          'p_device_id': deviceId.trim(),
        },
      );

      if (res is Map && res['success'] == true) {
        final token = res['session_token'] as String?;
        final expiresAt = res['expires_at'] as String?;
        if (token == null || token.trim().isEmpty) {
          return {
            'success': false,
            'error_code': 'INVALID_RPC_RESPONSE',
            'message':
                'Phản hồi RPC không hợp lệ: Thiếu session_token trong dữ liệu trả về',
          };
        }
        try {
          await saveTokenSession(
            rawToken: token,
            deviceId: deviceId,
            expiresAt: expiresAt,
            storeCode: storeCode,
          );
        } catch (e) {
          return {
            'success': false,
            'error_code': 'STORAGE_FAILED',
            'message': 'Lỗi lưu trữ SecureStorage: $e',
          };
        }
        return Map<String, dynamic>.from(res);
      }

      return {
        'success': false,
        'error_code': res is Map
            ? res['error_code'] ?? 'AUTH_FAILED'
            : 'AUTH_FAILED',
        'message': res is Map
            ? res['message'] ?? 'Xác thực thất bại'
            : 'Xác thực thất bại',
      };
    } catch (e) {
      return {
        'success': false,
        'error_code': 'EXCEPTION',
        'message': 'Lỗi xác thực POS device: $e',
      };
    }
  }

  /// Bootstrap thiết bị đầu tiên của quán bằng RPC `bootstrap_first_pos_device_v3`
  static Future<Map<String, dynamic>> bootstrapFirstDevice({
    required String storeCode,
    required String credential,
    String deviceName = 'POS Main Device',
  }) async {
    try {
      final res = await _sb.rpc(
        'bootstrap_first_pos_device_v3',
        params: {
          'p_store_code': storeCode.trim().toUpperCase(),
          'p_credential': credential.trim(),
          'p_device_name': deviceName.trim(),
        },
      );

      if (res is Map && res['success'] == true) {
        final token = res['session_token'] as String?;
        final deviceId = res['device_id'] as String?;
        final expiresAt = res['expires_at'] as String?;
        if (token == null ||
            token.trim().isEmpty ||
            deviceId == null ||
            deviceId.trim().isEmpty) {
          return {
            'success': false,
            'error_code': 'INVALID_RPC_RESPONSE',
            'message':
                'Phản hồi RPC không hợp lệ: Thiếu session_token hoặc device_id',
          };
        }
        try {
          await saveTokenSession(
            rawToken: token,
            deviceId: deviceId,
            expiresAt: expiresAt,
            storeCode: storeCode,
          );
        } catch (e) {
          return {
            'success': false,
            'error_code': 'STORAGE_FAILED',
            'message': 'Lỗi lưu trữ SecureStorage: $e',
          };
        }
        return Map<String, dynamic>.from(res);
      }

      return {
        'success': false,
        'error_code': res is Map
            ? res['error_code'] ?? 'BOOTSTRAP_FAILED'
            : 'BOOTSTRAP_FAILED',
        'message': res is Map
            ? res['message'] ?? 'Bootstrap thất bại'
            : 'Bootstrap thất bại',
      };
    } catch (e) {
      return {
        'success': false,
        'error_code': 'EXCEPTION',
        'message': 'Lỗi bootstrap POS device: $e',
      };
    }
  }

  /// Ghép nối thiết bị mới bằng mã pairing code qua RPC `pair_pos_device_v3`
  static Future<Map<String, dynamic>> pairDevice({
    required String storeCode,
    required String pairingCode,
    required String deviceName,
    String deviceRole = 'staff',
  }) async {
    try {
      final res = await _sb.rpc(
        'pair_pos_device_v3',
        params: {
          'p_store_code': storeCode.trim().toUpperCase(),
          'p_pairing_code': pairingCode.trim(),
          'p_device_name': deviceName.trim(),
          'p_device_role': deviceRole,
        },
      );

      if (res is Map && res['success'] == true) {
        final deviceId = res['device_id'] as String?;
        if (deviceId == null || deviceId.trim().isEmpty) {
          return {
            'success': false,
            'error_code': 'INVALID_RPC_RESPONSE',
            'message': 'Phản hồi RPC không hợp lệ: Thiếu device_id',
          };
        }
        try {
          await _storage.write(key: _kDeviceIdKey, value: deviceId);
          await _storage.write(key: _kStoreCodeKey, value: storeCode);
        } catch (e) {
          return {
            'success': false,
            'error_code': 'STORAGE_FAILED',
            'message': 'Lỗi lưu trữ SecureStorage: $e',
          };
        }
        return Map<String, dynamic>.from(res);
      }

      return {
        'success': false,
        'error_code': res is Map
            ? res['error_code'] ?? 'PAIRING_FAILED'
            : 'PAIRING_FAILED',
        'message': res is Map
            ? res['message'] ?? 'Ghép nối thiết bị thất bại'
            : 'Ghép nối thiết bị thất bại',
      };
    } catch (e) {
      return {
        'success': false,
        'error_code': 'EXCEPTION',
        'message': 'Lỗi ghép nối thiết bị: $e',
      };
    }
  }

  /// Thu hồi token session hiện tại bằng RPC `revoke_pos_device_session_v3`
  static Future<bool> revokeSession() async {
    final token = await getRawToken();
    if (token == null) {
      await clearTokenSession();
      return true;
    }

    try {
      final res = await _sb.rpc(
        'revoke_pos_device_session_v3',
        params: {'p_raw_token': token},
      );
      await clearTokenSession();
      if (res is Map && res['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      await clearTokenSession();
      return false;
    }
  }
}
