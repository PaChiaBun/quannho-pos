// lib/core/services/pos_jwt_auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// POS JWT Auth Service — Managing Server-Signed PostgREST JWTs for POS RLS Guard
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

const String _kPosJwtStorageKey = 'pos_supabase_jwt';
const String _kPosOnboardingJwtStorageKey = 'pos_supabase_onboarding_jwt';
const String _kConfiguredPosJwtBackendUrl = String.fromEnvironment(
  'POS_JWT_AUTH_URL',
  defaultValue: '',
);

typedef SupabaseAuthApplier = Future<void> Function(String? token);

class PosJwtAuthService {
  final String _backendUrl;
  final http.Client httpClient;
  final FlutterSecureStorage secureStorage;
  final SupabaseAuthApplier? authApplier;

  PosJwtAuthService({
    String? backendUrl,
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
    this.authApplier,
  }) : _backendUrl = (backendUrl ?? _kConfiguredPosJwtBackendUrl)
           .trim()
           .replaceFirst(RegExp(r'/+$'), ''),
       httpClient = httpClient ?? http.Client(),
       secureStorage = secureStorage ?? const FlutterSecureStorage();

  static String? _activeOnboardingJwt;
  static String? _activeOnboardingSubject;

  /// Trả token onboarding chỉ khi token còn hợp lệ và thuộc đúng tài khoản.
  String? activeOnboardingJwtFor(String userId) {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;
    final token = _activeOnboardingJwt;
    if (token == null ||
        _activeOnboardingSubject != cleanUserId ||
        !isOnboardingTokenValid(token)) {
      clearActiveOnboardingJwt();
      return null;
    }
    return token;
  }

  /// Lấy Onboarding JWT từ RAM hoặc SharedPreferences fallback nếu hợp lệ.
  Future<String?> getStoredOnboardingJwtFor(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) return null;
    final active = activeOnboardingJwtFor(cleanUserId);
    if (active != null) return active;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_kPosOnboardingJwtStorageKey);
      if (token != null) {
        if (!isOnboardingTokenValid(token)) {
          // Token đã hết hạn: dọn sạch khỏi storage
          await prefs.remove(_kPosOnboardingJwtStorageKey);
        } else if (_readTokenSubject(token) == cleanUserId) {
          _activeOnboardingJwt = token;
          _activeOnboardingSubject = cleanUserId;
          return token;
        }
      }
    } catch (_) {}
    return null;
  }

  void setActiveOnboardingJwt(String? token) {
    if (token != null && isOnboardingTokenValid(token)) {
      _activeOnboardingJwt = token;
      _activeOnboardingSubject = _readTokenSubject(token);
    } else {
      clearActiveOnboardingJwt();
    }
  }

  Future<void> storeOnboardingJwt(String token) async {
    if (isOnboardingTokenValid(token)) {
      setActiveOnboardingJwt(token);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPosOnboardingJwtStorageKey, token);
      } catch (_) {}
    } else {
      await clearOnboardingJwt();
    }
  }

  void clearActiveOnboardingJwt() {
    _activeOnboardingJwt = null;
    _activeOnboardingSubject = null;
  }

  Future<void> clearOnboardingJwt() async {
    clearActiveOnboardingJwt();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPosOnboardingJwtStorageKey);
    } catch (_) {}
  }

  /// POS JWT chỉ được bật khi bản build khai báo một endpoint production.
  /// Không để hoạt động cốt lõi của POS phụ thuộc ngầm vào BunServer/Tailscale.
  bool get isConfigured {
    final uri = Uri.tryParse(_backendUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        uri.path.isEmpty;
  }

  /// Retrieve cached POS JWT from secure storage, falling back to SharedPreferences if needed (e.g. Flutter Web)
  Future<String?> getStoredPosJwt() async {
    try {
      var token = await secureStorage.read(key: _kPosJwtStorageKey);
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        token = prefs.getString(_kPosJwtStorageKey);
      }
      if (token != null && isTokenValid(token)) {
        return token;
      }
      return null;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString(_kPosJwtStorageKey);
        if (token != null && isTokenValid(token)) {
          return token;
        }
      } catch (_) {}
      return null;
    }
  }

  /// Store POS JWT token in secure storage and SharedPreferences fallback
  Future<void> storePosJwt(String token) async {
    await secureStorage.write(key: _kPosJwtStorageKey, value: token);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPosJwtStorageKey, token);
    } catch (_) {}
  }

  /// Clear stored POS JWT token from secure storage and SharedPreferences fallback
  Future<void> clearPosJwt() async {
    try {
      await secureStorage.delete(key: _kPosJwtStorageKey);
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPosJwtStorageKey);
    } catch (_) {}
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

      final sub = (payloadJson['sub'] as String?)?.trim() ?? '';
      final jti = (payloadJson['jti'] as String?)?.trim() ?? '';
      final tokenStoreId = (payloadJson['store_id'] as String?)?.trim() ?? '';
      final role = (payloadJson['role'] as String?)?.trim();
      final issuer = (payloadJson['iss'] as String?)?.trim();
      final audience = payloadJson['aud'];
      final issuedAt = payloadJson['iat'] as int?;
      final notBefore = payloadJson['nbf'] as int?;
      final hasAuthenticatedAudience =
          audience == 'authenticated' ||
          (audience is List && audience.contains('authenticated'));
      if (sub.isEmpty ||
          jti.isEmpty ||
          tokenStoreId.isEmpty ||
          role != 'authenticated' ||
          issuer != 'supabase' ||
          !hasAuthenticatedAudience ||
          issuedAt == null ||
          issuedAt > nowSec + 30 ||
          exp <= issuedAt ||
          (notBefore != null && notBefore > nowSec + 30)) {
        return false;
      }

      if (expectedStoreId != null && expectedStoreId.trim().isNotEmpty) {
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
    bool allowOnboardingToken = false,
  }) async {
    if (token != null) {
      final isValid =
          isTokenValid(token, expectedStoreId: expectedStoreId) ||
          (allowOnboardingToken && isOnboardingTokenValid(token));
      if (!isValid) {
        return false;
      }
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
        client.rest.setAuth(SupabaseService.supabaseAnonKey);
        await client.realtime.setAuth(SupabaseService.supabaseAnonKey);
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
    if (!isConfigured) {
      return {
        'success': false,
        'status': 503,
        'error': 'POS_JWT_NOT_CONFIGURED',
        'message': 'Máy chủ POS JWT chưa được cấu hình cho bản phát hành này',
      };
    }

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
            Uri.parse('$_backendUrl$endpointPath'),
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

        if (!isTokenValid(token, expectedStoreId: storeId)) {
          await clearPosJwt();
          await applyAuthToSupabase(null);
          return {
            'success': false,
            'status': 502,
            'error': 'INVALID_TOKEN_RESPONSE',
            'message': 'Máy chủ trả về phiên cửa hàng không hợp lệ',
          };
        }

        // Transactional apply & storage with rollback compensation
        try {
          await storePosJwt(token);
          final applied = await applyAuthToSupabase(
            token,
            expectedStoreId: storeId,
          );
          if (!applied) {
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

  /// Chỉ kiểm tra cấu trúc/claims của Onboarding JWT ở phía client.
  ///
  /// Chữ ký chỉ được xác minh bởi gateway/PostgREST. Không dùng hàm này như
  /// một quyết định cấp quyền độc lập.
  bool isOnboardingTokenValid(String token) {
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
      if (exp <= (nowSec + 30)) return false;

      final sub = (payloadJson['sub'] as String?)?.trim() ?? '';
      final jti = (payloadJson['jti'] as String?)?.trim() ?? '';
      final tokenUse = (payloadJson['token_use'] as String?)?.trim();
      final role = (payloadJson['role'] as String?)?.trim();
      final issuer = (payloadJson['iss'] as String?)?.trim();
      final audience = payloadJson['aud'];
      final issuedAt = payloadJson['iat'] as int?;
      final notBefore = payloadJson['nbf'] as int?;
      final hasAuthenticatedAudience =
          audience == 'authenticated' ||
          (audience is List && audience.contains('authenticated'));

      return sub.isNotEmpty &&
          jti.isNotEmpty &&
          tokenUse == 'onboarding' &&
          role == 'authenticated' &&
          issuer == 'supabase' &&
          hasAuthenticatedAudience &&
          issuedAt != null &&
          issuedAt <= nowSec + 30 &&
          exp > issuedAt &&
          exp - issuedAt <= 600 &&
          (notBefore == null || notBefore <= nowSec + 30) &&
          payloadJson['store_id'] == null;
    } catch (_) {
      return false;
    }
  }

  String? _readTokenSubject(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload =
          jsonDecode(
                utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
              )
              as Map<String, dynamic>;
      final subject = (payload['sub'] as String?)?.trim();
      return subject == null || subject.isEmpty ? null : subject;
    } catch (_) {
      return null;
    }
  }

  /// Request a short-lived Onboarding JWT for users without a store
  Future<Map<String, dynamic>> requestOnboardingJwt({
    required String phone,
    required String password,
    String endpointPath = '/api/auth/onboarding-jwt',
    Duration timeoutDuration = const Duration(seconds: 10),
  }) async {
    await clearOnboardingJwt();
    if (!isConfigured) {
      return {
        'success': false,
        'status': 503,
        'error': 'POS_JWT_NOT_CONFIGURED',
        'message': 'Máy chủ POS JWT chưa được cấu hình cho bản phát hành này',
      };
    }

    if (phone.trim().isEmpty || password.trim().isEmpty) {
      return {
        'success': false,
        'status': 400,
        'error': 'INVALID_CREDENTIALS',
        'message': 'Số điện thoại và mật khẩu là bắt buộc',
      };
    }

    try {
      final response = await httpClient
          .post(
            Uri.parse('$_backendUrl$endpointPath'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone': phone.trim(),
              'password': password.trim(),
            }),
          )
          .timeout(timeoutDuration);

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        await clearOnboardingJwt();
        await applyAuthToSupabase(null);
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
          data['onboarding_jwt'] != null) {
        final token = data['onboarding_jwt'] as String;
        if (isOnboardingTokenValid(token)) {
          final applied = await applyAuthToSupabase(
            token,
            allowOnboardingToken: true,
          );
          if (!applied) {
            await clearOnboardingJwt();
            await applyAuthToSupabase(null);
            return {
              'success': false,
              'status': 500,
              'error': 'AUTH_APPLICATION_FAILED',
              'message': 'Không thể áp dụng phiên xác thực onboarding',
            };
          }
          await storeOnboardingJwt(token);
          return data;
        }
      }
      await clearOnboardingJwt();
      await applyAuthToSupabase(null);
      return {
        'success': false,
        'status': response.statusCode,
        'error': data['error'] ?? 'ONBOARDING_AUTH_FAILED',
        'message': data['message'] ?? 'Xác thực onboarding thất bại',
      };
    } catch (_) {
      await clearOnboardingJwt();
      await applyAuthToSupabase(null);
      return {
        'success': false,
        'status': 500,
        'error': 'NETWORK_ERROR',
        'message': 'Kết nối máy chủ xác thực bị gián đoạn',
      };
    }
  }

  /// Exchange an Onboarding JWT for a store-scoped POS JWT
  Future<Map<String, dynamic>> exchangeStoreJwt({
    required String onboardingJwt,
    required String storeId,
    String endpointPath = '/api/auth/exchange-store-jwt',
    Duration timeoutDuration = const Duration(seconds: 10),
  }) async {
    if (!isConfigured) {
      return {
        'success': false,
        'status': 503,
        'error': 'POS_JWT_NOT_CONFIGURED',
        'message': 'Máy chủ POS JWT chưa được cấu hình',
      };
    }

    if (onboardingJwt.trim().isEmpty || storeId.trim().isEmpty) {
      return {
        'success': false,
        'status': 400,
        'error': 'MISSING_PARAMETERS',
        'message': 'Token onboarding và mã cửa hàng là bắt buộc',
      };
    }

    try {
      final response = await httpClient
          .post(
            Uri.parse('$_backendUrl$endpointPath'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${onboardingJwt.trim()}',
            },
            body: jsonEncode({'store_id': storeId.trim()}),
          )
          .timeout(timeoutDuration);

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        await clearPosJwt();
        await applyAuthToSupabase(null);
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
        if (!isTokenValid(token, expectedStoreId: storeId)) {
          await clearOnboardingJwt();
          await clearPosJwt();
          await applyAuthToSupabase(null);
          return {
            'success': false,
            'status': 502,
            'error': 'INVALID_TOKEN_RESPONSE',
            'message': 'Máy chủ trả về phiên cửa hàng không hợp lệ',
          };
        }
        bool applied;
        try {
          await storePosJwt(token);
          applied = await applyAuthToSupabase(token, expectedStoreId: storeId);
        } catch (_) {
          await clearOnboardingJwt();
          await clearPosJwt();
          await applyAuthToSupabase(null);
          return {
            'success': false,
            'status': 500,
            'error': 'AUTH_APPLICATION_FAILED',
            'message': 'Không thể lưu hoặc áp dụng phiên cửa hàng',
          };
        }
        if (!applied) {
          await clearOnboardingJwt();
          await clearPosJwt();
          await applyAuthToSupabase(null);
          return {
            'success': false,
            'status': 500,
            'error': 'AUTH_APPLICATION_FAILED',
            'message': 'Không thể áp dụng phiên xác thực cửa hàng',
          };
        }
        await clearOnboardingJwt();
        return data;
      }
      final errorCode = data['error'] as String?;
      if (response.statusCode == 401 || response.statusCode == 403) {
        await clearOnboardingJwt();
      }
      await clearPosJwt();
      await applyAuthToSupabase(null);
      return {
        'success': false,
        'status': response.statusCode,
        'error': errorCode ?? 'EXCHANGE_FAILED',
        'message': data['message'] ?? 'Đổi phiên cửa hàng thất bại',
      };
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
