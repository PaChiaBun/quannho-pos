// test/core/onboarding_jwt_exchange_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests for Zero-Store Onboarding JWT and Store Exchange in Flutter
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    PosJwtAuthService().clearActiveOnboardingJwt();
  });

  String createTestJwt({
    required String sub,
    required String tokenUse,
    String? storeId,
    int ttl = 600,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'sub': sub,
      'role': 'authenticated',
      'aud': 'authenticated',
      'iss': 'supabase',
      'iat': now,
      'nbf': now,
      'exp': now + ttl,
      'jti': 'test_jti_${DateTime.now().microsecondsSinceEpoch}',
      'token_use': tokenUse,
      'store_id': ?storeId,
    };
    final hB64 = base64Url
        .encode(utf8.encode(jsonEncode(header)))
        .replaceAll('=', '');
    final pB64 = base64Url
        .encode(utf8.encode(jsonEncode(payload)))
        .replaceAll('=', '');
    return '$hB64.$pB64.dummy_signature';
  }

  group('Onboarding JWT & Exchange Tests', () {
    test(
      '1. isOnboardingTokenValid validates structural onboarding claims',
      () {
        final service = PosJwtAuthService(backendUrl: 'https://quannho.lpm.vn');
        final validToken = createTestJwt(
          sub: 'user-123',
          tokenUse: 'onboarding',
        );
        expect(service.isOnboardingTokenValid(validToken), isTrue);
      },
    );

    test('2. isOnboardingTokenValid rejects token with wrong token_use', () {
      final service = PosJwtAuthService(backendUrl: 'https://quannho.lpm.vn');
      final invalidToken = createTestJwt(sub: 'user-123', tokenUse: 'access');
      expect(service.isOnboardingTokenValid(invalidToken), isFalse);
    });

    test('3. isOnboardingTokenValid rejects expired onboarding token', () {
      final service = PosJwtAuthService(backendUrl: 'https://quannho.lpm.vn');
      final expiredToken = createTestJwt(
        sub: 'user-123',
        tokenUse: 'onboarding',
        ttl: -10,
      );
      expect(service.isOnboardingTokenValid(expiredToken), isFalse);
    });

    test(
      '4. requestOnboardingJwt handles successful server response',
      () async {
        final mockToken = createTestJwt(
          sub: 'user-new-456',
          tokenUse: 'onboarding',
        );
        final client = MockClient((request) async {
          if (request.url.path == '/api/auth/onboarding-jwt') {
            return http.Response(
              jsonEncode({
                'success': true,
                'status': 200,
                'onboarding_jwt': mockToken,
                'user_id': 'user-new-456',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        String? appliedToken;
        final service = PosJwtAuthService(
          backendUrl: 'https://quannho.lpm.vn',
          httpClient: client,
          authApplier: (token) async {
            appliedToken = token;
          },
        );

        final result = await service.requestOnboardingJwt(
          phone: '0912345678',
          password: 'SecurePassword123',
        );

        expect(result['success'], isTrue);
        expect(result['onboarding_jwt'], equals(mockToken));
        expect(appliedToken, equals(mockToken));
      },
    );

    test(
      '5. exchangeStoreJwt requests store-scoped POS JWT and applies it',
      () async {
        final onbToken = createTestJwt(
          sub: 'user-new-456',
          tokenUse: 'onboarding',
        );
        final posToken = createTestJwt(
          sub: 'user-new-456',
          tokenUse: 'access',
          storeId: 'store-abc-123',
        );

        final client = MockClient((request) async {
          if (request.url.path == '/api/auth/exchange-store-jwt') {
            final authHeader =
                request.headers['authorization'] ??
                request.headers['Authorization'];
            expect(authHeader, equals('Bearer $onbToken'));
            return http.Response(
              jsonEncode({
                'success': true,
                'status': 200,
                'pos_jwt': posToken,
                'store_id': 'store-abc-123',
                'role': 'owner',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('Not Found', 404);
        });

        String? appliedToken;
        final service = PosJwtAuthService(
          backendUrl: 'https://quannho.lpm.vn',
          httpClient: client,
          authApplier: (token) async {
            appliedToken = token;
          },
        );

        final result = await service.exchangeStoreJwt(
          onboardingJwt: onbToken,
          storeId: 'store-abc-123',
        );

        expect(result['success'], isTrue);
        expect(result['pos_jwt'], equals(posToken));
        expect(appliedToken, equals(posToken));
      },
    );

    test('6. exchangeStoreJwt rolls back on error', () async {
      final onbToken = createTestJwt(
        sub: 'user-new-456',
        tokenUse: 'onboarding',
      );

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'status': 403,
            'error': 'STORE_MEMBERSHIP_FORBIDDEN',
            'message': 'Không có quyền truy cập quán',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      String? appliedToken = 'initial_token';
      final service = PosJwtAuthService(
        backendUrl: 'https://quannho.lpm.vn',
        httpClient: client,
        authApplier: (token) async {
          appliedToken = token;
        },
      );

      final result = await service.exchangeStoreJwt(
        onboardingJwt: onbToken,
        storeId: 'store-forbidden',
      );

      expect(result['success'], isFalse);
      expect(result['status'], equals(403));
      expect(appliedToken, isNull); // Rolled back
    });

    test('7. onboarding token is scoped to the exact account subject', () {
      final service = PosJwtAuthService(backendUrl: 'https://quannho.lpm.vn');
      expect(service.activeOnboardingJwtFor('u1'), isNull);

      final validToken = createTestJwt(sub: 'u1', tokenUse: 'onboarding');
      service.setActiveOnboardingJwt(validToken);
      expect(service.activeOnboardingJwtFor('u1'), equals(validToken));
      expect(service.activeOnboardingJwtFor('another-user'), isNull);
      expect(service.activeOnboardingJwtFor('u1'), isNull);
    });

    test(
      '8. clearing POS JWT does not destroy retryable onboarding state',
      () async {
        final service = PosJwtAuthService(backendUrl: 'https://quannho.lpm.vn');
        final validToken = createTestJwt(sub: 'u1', tokenUse: 'onboarding');
        service.setActiveOnboardingJwt(validToken);

        await service.clearPosJwt();
        expect(service.activeOnboardingJwtFor('u1'), equals(validToken));
        service.clearActiveOnboardingJwt();
        expect(service.activeOnboardingJwtFor('u1'), isNull);
      },
    );

    test('9. exchange fails closed when secure storage write fails', () async {
      final onbToken = createTestJwt(sub: 'u1', tokenUse: 'onboarding');
      final posToken = createTestJwt(
        sub: 'u1',
        tokenUse: 'access',
        storeId: 'store-1',
      );
      final service = PosJwtAuthService(
        backendUrl: 'https://quannho.lpm.vn',
        secureStorage: ThrowingSecureStorage(),
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({'success': true, 'pos_jwt': posToken}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        authApplier: (_) async {},
      );
      service.setActiveOnboardingJwt(onbToken);

      final result = await service.exchangeStoreJwt(
        onboardingJwt: onbToken,
        storeId: 'store-1',
      );

      expect(result['success'], isFalse);
      expect(result['error'], 'AUTH_APPLICATION_FAILED');
      expect(service.activeOnboardingJwtFor('u1'), isNull);
    });

    test('10. retryable exchange failure preserves onboarding state', () async {
      final onbToken = createTestJwt(sub: 'u1', tokenUse: 'onboarding');
      final service = PosJwtAuthService(
        backendUrl: 'https://quannho.lpm.vn',
        httpClient: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': 'REPLAY_STORE_UNAVAILABLE',
              'message': 'Staging replay store unavailable',
            }),
            503,
            headers: {'content-type': 'application/json'},
          ),
        ),
        authApplier: (_) async {},
      );
      service.setActiveOnboardingJwt(onbToken);

      final result = await service.exchangeStoreJwt(
        onboardingJwt: onbToken,
        storeId: 'store-1',
      );

      expect(result['success'], isFalse);
      expect(result['status'], 503);
      expect(service.activeOnboardingJwtFor('u1'), equals(onbToken));
    });
  });
}

class ThrowingSecureStorage extends FlutterSecureStorage {
  @override
  Future<void> write({
    required String key,
    required String? value,
    dynamic iOptions,
    dynamic aOptions,
    dynamic lOptions,
    dynamic webOptions,
    dynamic mOptions,
    dynamic wOptions,
  }) async {
    throw StateError('secure storage unavailable');
  }
}
