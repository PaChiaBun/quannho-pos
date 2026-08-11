// lib/core/services/pos_jwt_auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// POS JWT Auth Service — Managing Server-Signed PostgREST JWTs for POS RLS Guard
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const String _kPosJwtStorageKey = 'pos_supabase_jwt';

typedef SupabaseAuthApplier = Future<void> Function(String? token);

class PosJwtAuthService {
  final String backendUrl;
  final http.Client httpClient;
  final FlutterSecureStorage secureStorage;
  final SupabaseAuthApplier? authApplier;

  PosJwtAuthService({
    String? backendUrl,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
    SupabaseAuthApplier? authApplier,
  }) : backendUrl = backendUrl ?? 'https://bunserver.tailcaeae7.ts.net',
       httpClient = httpClient ?? http.Client(),
       secureStorage = secureStorage ?? const FlutterSecureStorage(),
       authApplier = authApplier;

  /// Retrieve cached POS JWT from secure storage
  Future<String?> getStoredPosJwt() async {
    try {
      final token = await secureStorage.read(key: _kPosJwtStorageKey);
      if (token != null && isTokenValid(token)) {
        return token;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Store POS JWT token in secure storage
  Future<void> storePosJwt(String token) async {
    await secureStorage.write(key: _kPosJwtStorageKey, value: token);
  }

  /// Clear stored POS JWT token from secure storage
  Future<void> clearPosJwt() async {
    await secureStorage.delete(key: _kPosJwtStorageKey);
  }

  /// Decode JWT and verify 'exp' claim has at least 30 seconds remaining and store_id matches
  bool isTokenValid(String token, {String? expectedStoreId}) {
    if (token.trim().isEmpty) return false;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payloadB64 = base64Url.normalize(parts[1]);
      final payloadJson =
          jsonDecode(utf8.decode(base64Url.decode(payloadB64)))
              as Map<String, dynamic>;
      final exp = payloadJson['exp'] as int?;
      if (exp == null) return false;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      // Must have at least 30 seconds remaining (future skew check)
      if (exp <= (nowSec + 30)) return false;

      if (expectedStoreId != null && expectedStoreId.trim().isNotEmpty) {
        final tokenStoreId = (payloadJson['store_id'] as String?)?.trim();
        if (tokenStoreId != expectedStoreId.trim()) return false;
      }

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Apply token to Supabase REST and Realtime clients atomically (Fail-Closed)
  Future<bool> applyAuthToSupabase(
    String? token, {
    String? expectedStoreId,
  }) async {
    if (token != null &&
        !isTokenValid(token, expectedStoreId: expectedStoreId)) {
      return false;
    }

    try {
      if (authApplier != null) {
        await authApplier!(token);
        return true;
      }

      final client = Supabase.instance.client;
      if (token != null) {
        client.rest.setAuth(token);
        await client.realtime.setAuth(token);
      } else {
        client.rest.setAuth(null);
        await client.realtime.setAuth(null);
      }
      return true;
    } catch (_) {
      // FAIL-CLOSED: Any exception applying auth returns false
      return false;
    }
  }

  /// Request a short-lived server-signed POS JWT from backend
  Future<Map<String, dynamic>> requestPosJwt({
    required String phone,
    required String password,
    required String storeId,
    String endpointPath = '/api/auth/pos-jwt',
    Duration timeoutDuration = const Duration(seconds: 10),
  }) async {
    if (phone.trim().isEmpty ||
        password.trim().isEmpty ||
        storeId.trim().isEmpty) {
      return {
        'success': false,
        'status': 400,
        'error': 'INVALID_CREDENTIALS',
        'message': 'Số điện thoại, mật khẩu và cửa hàng là bắt buộc',
      };
    }

    final payload = {
      'phone': phone.trim(),
      'password': password.trim(),
      'store_id': storeId.trim(),
    };

    try {
      final response = await httpClient
          .post(
            Uri.parse('$backendUrl$endpointPath'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeoutDuration);

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          'success': false,
          'status': response.statusCode,
          'error': 'INVALID_CONTENT_TYPE',
          'message': 'Server response is not JSON',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true &&
          data['pos_jwt'] != null) {
        final token = data['pos_jwt'] as String;

        // Transactional apply & storage with rollback compensation
        try {
          await storePosJwt(token);
          final applied = await applyAuthToSupabase(
            token,
            expectedStoreId: storeId,
          );
          if (!applied && token.isNotEmpty) {
            // Apply failed -> Rollback token
            await clearPosJwt();
            await applyAuthToSupabase(null);
            return {
              'success': false,
              'status': 500,
              'error': 'AUTH_APPLICATION_FAILED',
              'message': 'Không thể áp dụng phiên xác thực cửa hàng',
            };
          }
        } catch (_) {
          await clearPosJwt();
          await applyAuthToSupabase(null);
          return {
            'success': false,
            'status': 500,
            'error': 'AUTH_APPLICATION_FAILED',
            'message': 'Lỗi cài đặt phiên làm việc an toàn',
          };
        }

        return data;
      } else {
        return {
          'success': false,
          'status': response.statusCode,
          'error': data['error'] ?? 'INVALID_CREDENTIALS',
          'message': data['message'] ?? 'Xác thực tài khoản thất bại',
        };
      }
    } catch (_) {
      await clearPosJwt();
      await applyAuthToSupabase(null);
      return {
        'success': false,
        'status': 500,
        'error': 'NETWORK_ERROR',
        'message': 'Kết nối máy chủ xác thực bị gián đoạn',
      };
    }
  }
}
