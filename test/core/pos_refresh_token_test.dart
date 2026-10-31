// test/core/pos_refresh_token_test.dart
// Bước 1+2 kế hoạch token: access 12h + refresh token xoay vòng.
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHttpClient extends Mock implements http.Client {}

class MemoryStorage extends Mock implements FlutterSecureStorage {
  final Map<String, String> data = {};
}

String jwt({String store = 's1', int ttl = 43200, String sub = 'u1'}) {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  return '${enc({'alg': 'HS256', 'typ': 'JWT'})}.${enc({
    'sub': sub,
    'role': 'authenticated',
    'iss': 'supabase',
    'aud': 'authenticated',
    'iat': now,
    'nbf': now,
    'exp': now + ttl,
    'jti': 'j${now}_$ttl$store',
    'store_id': store,
  })}.sig';
}

http.Response jsonResp(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://example.test'));
  });

  late MockHttpClient client;
  late MemoryStorage storage;
  late List<String?> applied;
  late PosJwtAuthService service;
  late List<Map<String, dynamic>> sentBodies;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PosJwtAuthService.clientLabelOverride = 'test 1.0.5+99';
    PosJwtAuthService.waitingForRefresh = false;
    client = MockHttpClient();
    storage = MemoryStorage();
    applied = [];
    sentBodies = [];
    when(
      () => storage.read(key: any(named: 'key')),
    ).thenAnswer((i) async => storage.data[i.namedArguments[#key] as String]);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((i) async {
      final k = i.namedArguments[#key] as String;
      final v = i.namedArguments[#value] as String?;
      if (v == null) {
        storage.data.remove(k);
      } else {
        storage.data[k] = v;
      }
    });
    when(
      () => storage.delete(key: any(named: 'key')),
    ).thenAnswer((i) async => storage.data.remove(i.namedArguments[#key]));
    service = PosJwtAuthService(
      backendUrl: 'https://quannho.example.test',
      httpClient: client,
      secureStorage: storage,
      authApplier: (t) async => applied.add(t),
    );
  });

  void stubPost(http.Response Function(String path) responder) {
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer((i) async {
      final uri = i.positionalArguments.first as Uri;
      sentBodies.add(
        jsonDecode(i.namedArguments[#body] as String) as Map<String, dynamic>,
      );
      return responder(uri.path);
    });
  }

  test('1. login asks for refresh and stores refresh token, hides it from caller', () async {
    stubPost(
      (_) => jsonResp(200, {
        'success': true,
        'pos_jwt': jwt(),
        'refresh_token': 'qnr_first_token_value_abcdef',
        'store_id': 's1',
        'role': 'cashier',
      }),
    );
    final res = await service.requestPosJwt(
      phone: '0900',
      password: 'pw',
      storeId: 's1',
    );
    expect(res['success'], isTrue);
    expect(res.containsKey('refresh_token'), isFalse);
    expect(sentBodies.single['supports_refresh'], isTrue);
    expect(sentBodies.single['client_label'], 'test 1.0.5+99');
    expect(await service.getStoredRefreshToken(), 'qnr_first_token_value_abcdef');
  });

  test('2. legacy gateway (no refresh_token) clears any stale refresh token', () async {
    await service.storeRefreshToken('qnr_old_stale_token_value_x');
    stubPost(
      (_) => jsonResp(200, {'success': true, 'pos_jwt': jwt(), 'store_id': 's1'}),
    );
    await service.requestPosJwt(phone: '0900', password: 'pw', storeId: 's1');
    expect(await service.getStoredRefreshToken(), isNull);
  });

  test('3. refresh rotates both tokens and applies the new access token', () async {
    await service.storeRefreshToken('qnr_rotate_me_token_value_1');
    final newAccess = jwt(ttl: 43200);
    stubPost(
      (_) => jsonResp(200, {
        'success': true,
        'pos_jwt': newAccess,
        'refresh_token': 'qnr_rotated_token_value_2xx',
        'store_id': 's1',
      }),
    );
    final out = await service.refreshPosJwt(expectedStoreId: 's1');
    expect(out, PosRefreshOutcome.refreshed);
    expect(sentBodies.single['refresh_token'], 'qnr_rotate_me_token_value_1');
    expect(await service.getStoredRefreshToken(), 'qnr_rotated_token_value_2xx');
    expect(await service.getStoredPosJwt(), newAccess);
    expect(applied.last, newAccess);
  });

  test('4. 401 from gateway => rejected and refresh token wiped', () async {
    await service.storeRefreshToken('qnr_revoked_token_value_123');
    stubPost(
      (_) => jsonResp(401, {'success': false, 'error': 'REFRESH_REVOKED'}),
    );
    expect(
      await service.refreshPosJwt(expectedStoreId: 's1'),
      PosRefreshOutcome.rejected,
    );
    expect(await service.getStoredRefreshToken(), isNull);
  });

  test('5. network failure => offline, refresh token kept', () async {
    await service.storeRefreshToken('qnr_keep_me_offline_value_1');
    when(
      () => client.post(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenThrow(Exception('no network'));
    expect(
      await service.refreshPosJwt(expectedStoreId: 's1'),
      PosRefreshOutcome.offline,
    );
    expect(await service.getStoredRefreshToken(), 'qnr_keep_me_offline_value_1');
  });

  test('6. concurrent refresh calls share one network request', () async {
    await service.storeRefreshToken('qnr_single_flight_value_123');
    stubPost(
      (_) => jsonResp(200, {
        'success': true,
        'pos_jwt': jwt(),
        'refresh_token': 'qnr_single_flight_next_456',
      }),
    );
    final results = await Future.wait([
      service.refreshPosJwt(expectedStoreId: 's1'),
      service.refreshPosJwt(expectedStoreId: 's1'),
      service.refreshPosJwt(expectedStoreId: 's1'),
    ]);
    expect(results.toSet(), {PosRefreshOutcome.refreshed});
    expect(sentBodies.length, 1);
  });

  test('7. token for another store is refused and refresh dropped', () async {
    await service.storeRefreshToken('qnr_other_store_value_12345');
    stubPost(
      (_) => jsonResp(200, {
        'success': true,
        'pos_jwt': jwt(store: 's2'),
        'refresh_token': 'qnr_other_store_next_67890',
      }),
    );
    expect(
      await service.refreshPosJwt(expectedStoreId: 's1'),
      PosRefreshOutcome.noRefreshToken,
    );
    expect(await service.getStoredRefreshToken(), isNull);
    expect(applied, isEmpty);
  });

  test('8. ensureFreshPosJwt skips network when token has > 2h left', () async {
    await service.storePosJwt(jwt(ttl: 6 * 3600));
    stubPost((_) => jsonResp(500, {}));
    expect(await service.ensureFreshPosJwt(expectedStoreId: 's1'), isTrue);
    expect(sentBodies, isEmpty);
  });

  test('9. ensureFreshPosJwt refreshes when < 2h left; false when revoked', () async {
    await service.storePosJwt(jwt(ttl: 1800));
    await service.storeRefreshToken('qnr_almost_expired_value_1');
    stubPost((_) => jsonResp(403, {'success': false}));
    expect(await service.ensureFreshPosJwt(expectedStoreId: 's1'), isFalse);
    expect(sentBodies.length, 1);
  });

  test('10. legacy 30-day session without refresh token keeps working', () async {
    await service.storePosJwt(jwt(ttl: 600));
    stubPost((_) => jsonResp(500, {}));
    expect(await service.ensureFreshPosJwt(expectedStoreId: 's1'), isTrue);
    expect(sentBodies, isEmpty); // no refresh token => no call
  });

  test('11. logout revokes on server and clears locally', () async {
    await service.storeRefreshToken('qnr_logout_token_value_1234');
    stubPost((path) => jsonResp(200, {'success': true, 'revoked': 1}));
    await service.revokeRefreshToken();
    expect(sentBodies.single['refresh_token'], 'qnr_logout_token_value_1234');
    expect(await service.getStoredRefreshToken(), isNull);
  });

  test('12. clearPosJwt also clears refresh token', () async {
    await service.storeRefreshToken('qnr_cleared_with_access_123');
    await service.clearPosJwt();
    expect(await service.getStoredRefreshToken(), isNull);
  });

  // ── Kế hoạch JWT Pha 2: mở app lúc mất mạng ──
  test('13. offline retry: waits, then recovers JWT, clears flag, notifies once', () async {
    await service.storeRefreshToken('qnr_offline_retry_token_1234');
    var online = false;
    stubPost((_) {
      if (!online) throw http.ClientException('no network');
      return jsonResp(200, {
        'success': true,
        'pos_jwt': jwt(),
        'refresh_token': 'qnr_offline_retry_token_5678',
      });
    });
    final before = PosJwtAuthService.jwtRecovered.value;
    service.startOfflineRetry(
      expectedStoreId: 's1',
      every: const Duration(milliseconds: 20),
    );
    expect(PosJwtAuthService.waitingForRefresh, isTrue);
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(PosJwtAuthService.waitingForRefresh, isTrue);
    expect(applied, isEmpty);
    online = true;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(PosJwtAuthService.waitingForRefresh, isFalse);
    expect(applied.single, isNotNull);
    expect(PosJwtAuthService.jwtRecovered.value, before + 1);
    final calls = sentBodies.length;
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(sentBodies.length, calls, reason: 'dừng thử lại sau khi có JWT');
  });

  test('14. offline retry: server rejects refresh => onSessionRevoked, stops', () async {
    await service.storeRefreshToken('qnr_offline_rejected_token_1');
    stubPost((_) => jsonResp(401, {'success': false}));
    var revoked = 0;
    service.startAutoRefresh(
      currentStoreId: () => 's1',
      onSessionRevoked: () => revoked++,
    );
    service.startOfflineRetry(
      expectedStoreId: 's1',
      every: const Duration(milliseconds: 20),
    );
    await Future<void>.delayed(const Duration(milliseconds: 90));
    PosJwtAuthService.stopAutoRefresh();
    expect(revoked, 1);
    expect(sentBodies.length, 1);
    expect(PosJwtAuthService.waitingForRefresh, isTrue,
        reason: 'chưa có JWT, vẫn không kiểm thành viên bằng anon');
  });

  test('15. offline retry gives up after maxTries without throwing', () async {
    await service.storeRefreshToken('qnr_offline_giveup_token_12');
    stubPost((_) => throw http.ClientException('no network'));
    service.startOfflineRetry(
      expectedStoreId: 's1',
      every: const Duration(milliseconds: 10),
      maxTries: 3,
    );
    await Future<void>.delayed(const Duration(milliseconds: 120));
    expect(sentBodies.length, 3);
    PosJwtAuthService.stopAutoRefresh();
  });

  test('16. anon (token null) does not clear the waiting flag', () async {
    PosJwtAuthService.waitingForRefresh = true;
    await service.applyAuthToSupabase(null);
    expect(PosJwtAuthService.waitingForRefresh, isTrue);
    PosJwtAuthService.waitingForRefresh = false;
  });

  group('vé bị API từ chối (đổi khoá ký)', () {
    setUp(() => PosJwtAuthService.resetRecoverCooldown());
    tearDown(() {
      PosJwtAuthService.stopAutoRefresh();
      PosJwtAuthService.currentAccessToken = null;
    });

    test('17. xin vé mới bằng refresh token, trả vé mới', () async {
      final old = jwt(ttl: 2592000);
      PosJwtAuthService.currentAccessToken = old;
      await service.storeRefreshToken('qnr_recover_token_value_001');
      final fresh = jwt(ttl: 2592001);
      stubPost((_) => jsonResp(200, {
            'success': true,
            'pos_jwt': fresh,
            'refresh_token': 'qnr_recover_token_value_002',
            'store_id': 's1',
          }));
      expect(await service.recoverRejectedJwt(old), fresh);
      expect(sentBodies.single['refresh_token'], 'qnr_recover_token_value_001');
      expect(applied.last, fresh);
    });

    test('18. yêu cầu khác đã có vé mới: dùng luôn, không gọi máy chủ', () async {
      PosJwtAuthService.currentAccessToken = 've.moi.roi';
      stubPost((_) => jsonResp(500, {}));
      expect(await service.recoverRejectedJwt('ve.cu.bi.tu.choi'), 've.moi.roi');
      expect(sentBodies, isEmpty);
    });

    test('19. refresh token bị từ chối → về đăng nhập; lần sau trong 30 giây không gọi lại', () async {
      final old = jwt();
      PosJwtAuthService.currentAccessToken = old;
      await service.storeRefreshToken('qnr_recover_rejected_value1');
      stubPost((_) => jsonResp(401, {'success': false}));
      var revoked = 0;
      service.startAutoRefresh(
        currentStoreId: () => 's1',
        onSessionRevoked: () => revoked++,
      );
      expect(await service.recoverRejectedJwt(old), isNull);
      expect(revoked, 1);
      expect(await service.recoverRejectedJwt(old), isNull);
      expect(sentBodies.length, 1, reason: 'đang nghỉ 30 giây');
    });

    test('20. mất mạng: trả null, không đá về đăng nhập', () async {
      final old = jwt();
      PosJwtAuthService.currentAccessToken = old;
      await service.storeRefreshToken('qnr_recover_offline_value_1');
      stubPost((_) => throw http.ClientException('no network'));
      var revoked = 0;
      service.startAutoRefresh(
        currentStoreId: () => 's1',
        onSessionRevoked: () => revoked++,
      );
      expect(await service.recoverRejectedJwt(old), isNull);
      expect(revoked, 0);
    });
  });
}
