// test/core/jwt_gate_http_client_test.dart
// Chốt chặn JWT (kế hoạch JWT Pha 2): chưa có JWT thì giữ yêu cầu, có JWT mới gửi.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quannho_pos/core/services/jwt_gate_http_client.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';

const anon = 'anon.key.value';

void main() {
  late List<http.BaseRequest> sent;
  late JwtGateHttpClient gate;

  setUp(() {
    PosJwtAuthService.waitingForRefresh = false;
    PosJwtAuthService.currentAccessToken = null;
    sent = [];
    gate = JwtGateHttpClient(
      anonKey: anon,
      maxWait: const Duration(milliseconds: 200),
      inner: MockClient((req) async {
        sent.add(req);
        return http.Response('[]', 200);
      }),
    );
  });

  tearDown(() {
    PosJwtAuthService.waitingForRefresh = false;
    PosJwtAuthService.currentAccessToken = null;
  });

  Future<http.Response> get() => gate.get(
    Uri.parse('https://x.test/rest/v1/stores'),
    headers: {'apikey': anon, 'Authorization': 'Bearer $anon'},
  );

  test('1. không chờ JWT: đi thẳng, giữ nguyên header', () async {
    PosJwtAuthService.currentAccessToken = 'jwt.cu';
    await get();
    expect(sent.single.headers['Authorization'], 'Bearer $anon',
        reason: 'ngoài lúc chờ không tự đổi header');
  });

  test('2. đang chờ: giữ yêu cầu, có JWT thì gửi kèm JWT mới (apikey vẫn là anon)', () async {
    PosJwtAuthService.waitingForRefresh = true;
    final f = get();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(sent, isEmpty, reason: 'chưa có JWT thì chưa gửi');
    PosJwtAuthService.currentAccessToken = 'jwt.moi';
    PosJwtAuthService.waitingForRefresh = false;
    final res = await f;
    expect(res.statusCode, 200);
    expect(sent.single.headers['authorization'], 'Bearer jwt.moi');
    expect(sent.single.headers['apikey'], anon);
  });

  test('3. chờ quá lâu: báo lỗi mạng, KHÔNG gửi bằng anon', () async {
    PosJwtAuthService.waitingForRefresh = true;
    await expectLater(get(), throwsA(isA<http.ClientException>()));
    expect(sent, isEmpty);
  });

  test('4. nhiều yêu cầu cùng chờ đều được nhả một lượt', () async {
    PosJwtAuthService.waitingForRefresh = true;
    final all = Future.wait([get(), get(), get()]);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    PosJwtAuthService.currentAccessToken = 'jwt.moi';
    PosJwtAuthService.waitingForRefresh = false;
    await all;
    expect(sent.length, 3);
    expect(sent.every((r) => r.headers['Authorization'] == 'Bearer jwt.moi'), isTrue);
  });

  test('5. đăng xuất lúc đang chờ: nhả ra, gửi bằng anon (không có JWT)', () async {
    PosJwtAuthService.waitingForRefresh = true;
    final f = get();
    await Future<void>.delayed(const Duration(milliseconds: 30));
    PosJwtAuthService.waitingForRefresh = false; // logout
    await f;
    expect(sent.single.headers['Authorization'], 'Bearer $anon');
  });

  test('6. yêu cầu đã mang JWT khác (không phải anon) thì không bị đổi', () async {
    PosJwtAuthService.waitingForRefresh = true;
    final f = gate.get(
      Uri.parse('https://x.test/rest/v1/stores'),
      headers: {'apikey': anon, 'Authorization': 'Bearer jwt.onboarding'},
    );
    PosJwtAuthService.currentAccessToken = 'jwt.moi';
    PosJwtAuthService.waitingForRefresh = false;
    await f;
    expect(sent.single.headers['Authorization'], 'Bearer jwt.onboarding');
  });

  test('7. Supabase được khởi tạo kèm chốt chặn', () {
    // đọc nguyên văn: tránh ai đó gỡ httpClient khi sửa supabase_service.dart
    expect(
      RegExp(r'httpClient:\s*JwtGateHttpClient\(').hasMatch(
        File('lib/core/services/supabase_service.dart').readAsStringSync(),
      ),
      isTrue,
    );
  });

  group('vé bị từ chối → xin vé mới, gửi lại 1 lần', () {
    late List<String> recovered;
    late int calls;
    JwtGateHttpClient gateWith(http.Response Function(int n) respond,
        {String? fresh = 'jwt.moi'}) {
      recovered = [];
      calls = 0;
      return JwtGateHttpClient(
        anonKey: anon,
        recover: (t) async {
          recovered.add(t);
          return fresh;
        },
        inner: MockClient((req) async {
          sent.add(req);
          return respond(calls++);
        }),
      );
    }

    final rejected = http.Response('{"code":"PGRST301","message":"JWSInvalidSignature"}', 401);

    Future<http.Response> post(JwtGateHttpClient g, String auth) => g.post(
      Uri.parse('https://x.test/rest/v1/rpc/f'),
      headers: {'apikey': anon, 'Authorization': 'Bearer $auth'},
      body: '{"a":1}',
    );

    test('8. 401 PGRST301 với vé phiên: xin vé mới, gửi lại cùng body', () async {
      PosJwtAuthService.currentAccessToken = 'jwt.cu';
      final g = gateWith((n) => n == 0 ? rejected : http.Response('ok', 200));
      final res = await post(g, 'jwt.cu');
      expect(res.statusCode, 200);
      expect(recovered, ['jwt.cu']);
      expect(sent.length, 2);
      expect(sent.last.headers['Authorization'], 'Bearer jwt.moi');
      expect((sent.last as http.Request).body, '{"a":1}');
    });

    test('9. không xin được vé: trả nguyên lỗi 401, không gửi lại', () async {
      PosJwtAuthService.currentAccessToken = 'jwt.cu';
      final g = gateWith((_) => rejected, fresh: null);
      final res = await post(g, 'jwt.cu');
      expect(res.statusCode, 401);
      expect(res.body, contains('PGRST301'));
      expect(sent.length, 1);
    });

    test('10. 401 khác (không phải lỗi vé) hoặc yêu cầu anon: không đụng', () async {
      PosJwtAuthService.currentAccessToken = 'jwt.cu';
      final g = gateWith((_) => http.Response('{"code":"42501"}', 401));
      expect((await post(g, 'jwt.cu')).statusCode, 401);
      final g2 = gateWith((_) => rejected);
      expect((await post(g2, anon)).statusCode, 401);
      expect(recovered, isEmpty);
    });

    test('11. vẫn bị từ chối sau khi gửi lại: không lặp', () async {
      PosJwtAuthService.currentAccessToken = 'jwt.cu';
      final g = gateWith((_) => rejected);
      expect((await post(g, 'jwt.cu')).statusCode, 401);
      expect(sent.length, 2);
      expect(recovered.length, 1);
    });
  });
}
