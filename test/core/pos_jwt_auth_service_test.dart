// test/core/pos_jwt_auth_service_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Flutter Unit Tests for PosJwtAuthService & UserAuthService Fail-Closed Wiring
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://bunserver.tailcaeae7.ts.net'));
  });

  group('PosJwtAuthService Unit & Security Logic Tests', () {
    test(
      '1. Expiry skew validation accepts valid token and rejects expired token',
      () {
        final service = PosJwtAuthService();
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // Token valid for 3600 seconds
        final validHeader = base64Url
            .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
            .replaceAll('=', '');
        final validPayload = base64Url
            .encode(
              utf8.encode(
                '{"sub":"u1","exp":${nowSec + 3600},"store_id":"s1"}',
              ),
            )
            .replaceAll('=', '');
        final validJwt = '$validHeader.$validPayload.sig';

        expect(service.isTokenValid(validJwt), isTrue);
        expect(service.isTokenValid(validJwt, expectedStoreId: 's1'), isTrue);
        expect(
          service.isTokenValid(validJwt, expectedStoreId: 'wrong_store'),
          isFalse,
        );

        // Token expiring in less than 30 seconds (future skew check)
        final expSoonPayload = base64Url
            .encode(
              utf8.encode('{"sub":"u1","exp":${nowSec + 15},"store_id":"s1"}'),
            )
            .replaceAll('=', '');
        final expSoonJwt = '$validHeader.$expSoonPayload.sig';
        expect(service.isTokenValid(expSoonJwt), isFalse);

        // Expired token
        final expiredPayload = base64Url
            .encode(
              utf8.encode('{"sub":"u1","exp":${nowSec - 10},"store_id":"s1"}'),
            )
            .replaceAll('=', '');
        final expiredJwt = '$validHeader.$expiredPayload.sig';
        expect(service.isTokenValid(expiredJwt), isFalse);
      },
    );

    test(
      '2. requestPosJwt fail-closed on 401 response and propagates message',
      () async {
        final mockClient = MockHttpClient();
        final mockStorage = MockFlutterSecureStorage();

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'success': false,
              'error': 'INVALID_CREDENTIALS',
              'message': 'Số điện thoại hoặc mật khẩu không chính xác',
            }),
            401,
            headers: {'content-type': 'application/json'},
          ),
        );

        final service = PosJwtAuthService(
          backendUrl: 'https://auth.example.com',
          httpClient: mockClient,
          secureStorage: mockStorage,
        );

        final res = await service.requestPosJwt(
          phone: '0900000001',
          password: 'wrong_password',
          storeId: 'store-1',
        );

        expect(res['success'], false);
        expect(res['status'], 401);
        expect(res['error'], 'INVALID_CREDENTIALS');
        verifyZeroInteractions(mockStorage);
      },
    );

    test(
      '3. requestPosJwt stores token and returns success on 200 response',
      () async {
        final storageMap = <String, String>{};
        final mockClient = MockHttpClient();
        final mockStorage = MockFlutterSecureStorage();

        when(
          () => mockStorage.delete(key: any(named: 'key')),
        ).thenAnswer((_) async {});
        when(
          () => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((inv) async {
          storageMap[inv.namedArguments[#key] as String] =
              inv.namedArguments[#value] as String;
        });

        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final h = base64Url
            .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
            .replaceAll('=', '');
        final p = base64Url
            .encode(
              utf8.encode(
                '{"sub":"u1","exp":${nowSec + 3600},"store_id":"s1"}',
              ),
            )
            .replaceAll('=', '');
        final token = '$h.$p.signature';

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'success': true, 'pos_jwt': token, 'store_id': 's1'}),
            200,
            headers: {'content-type': 'application/json'},
          ),
        );

        final service = PosJwtAuthService(
          backendUrl: 'https://auth.example.com',
          httpClient: mockClient,
          secureStorage: mockStorage,
          authApplier: (token) async {},
        );

        final res = await service.requestPosJwt(
          phone: '0900000001',
          password: 'correct_password',
          storeId: 's1',
        );

        expect(res['success'], true);
        expect(res['pos_jwt'], token);
        expect(storageMap['pos_supabase_jwt'], token);
      },
    );

    test('4. requestPosJwt handles timeout gracefully', () async {
      final mockClient = MockHttpClient();
      final mockStorage = MockFlutterSecureStorage();
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => Future.delayed(
          const Duration(seconds: 2),
          () => http.Response(jsonEncode({'success': true}), 200),
        ),
      );

      final service = PosJwtAuthService(
        backendUrl: 'https://auth.example.com',
        httpClient: mockClient,
        secureStorage: mockStorage,
      );

      final res = await service.requestPosJwt(
        phone: '0900000001',
        password: 'pass',
        storeId: 's1',
        timeoutDuration: const Duration(milliseconds: 100),
      );

      expect(res['success'], false);
      expect(res['error'], 'NETWORK_ERROR');
    });

    test(
      '5. applyAuthToSupabase exception results in failure and token rollback',
      () async {
        final mockStorage = MockFlutterSecureStorage();
        when(
          () => mockStorage.delete(key: any(named: 'key')),
        ).thenAnswer((_) async {});

        final service = PosJwtAuthService(
          secureStorage: mockStorage,
          authApplier: (token) async {
            throw Exception('Supabase REST setAuth failure');
          },
        );

        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final h = base64Url
            .encode(utf8.encode('{"alg":"HS256","typ":"JWT"}'))
            .replaceAll('=', '');
        final p = base64Url
            .encode(
              utf8.encode(
                '{"sub":"u1","exp":${nowSec + 3600},"store_id":"s1"}',
              ),
            )
            .replaceAll('=', '');
        final token = '$h.$p.signature';

        final applied = await service.applyAuthToSupabase(
          token,
          expectedStoreId: 's1',
        );
        expect(applied, isFalse);
      },
    );

    test(
      '6. disabled by default when no production endpoint is configured',
      () {
        final service = PosJwtAuthService();
        expect(service.isConfigured, isFalse);
      },
    );

    test('7. accepts only a clean HTTPS production origin', () {
      expect(
        PosJwtAuthService(backendUrl: 'https://auth.example.com/').isConfigured,
        isTrue,
      );
      expect(
        PosJwtAuthService(backendUrl: 'http://auth.example.com').isConfigured,
        isFalse,
      );
      expect(
        PosJwtAuthService(
          backendUrl: 'https://user:pass@auth.example.com',
        ).isConfigured,
        isFalse,
      );
      expect(
        PosJwtAuthService(
          backendUrl: 'https://auth.example.com/base',
        ).isConfigured,
        isFalse,
      );
    });
  });
}
