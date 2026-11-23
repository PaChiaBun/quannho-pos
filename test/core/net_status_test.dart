// test/core/net_status_test.dart
// Dải "Đang mất mạng" (23/11/2026): nhận biết mất mạng từ chính yêu cầu app gửi đi.
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quannho_pos/core/services/jwt_gate_http_client.dart';
import 'package:quannho_pos/core/services/net_status.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';
import 'package:quannho_pos/core/widgets/net_status_banner.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final data = File('test/fonts/PlusJakartaSans-SemiBold.ttf').readAsBytesSync();
    await (FontLoader('PlusJakartaSans_600')..addFont(Future.value(ByteData.view(data.buffer)))).load();
  });

  setUp(() {
    NetStatus.reset();
    PosJwtAuthService.waitingForRefresh = false;
    PosJwtAuthService.currentAccessToken = null;
  });
  tearDown(NetStatus.reset);

  test('một yêu cầu hỏng chưa báo mất mạng; hỏi lại vẫn hỏng mới báo', () {
    fakeAsync((async) {
      var up = false;
      var probes = 0;
      NetStatus.probe = () async {
        probes++;
        if (!up) throw const SocketException('mat mang');
        return true;
      };

      NetStatus.requestFailed();
      NetStatus.requestFailed(); // hỏng dồn dập chỉ hỏi lại một lượt
      expect(NetStatus.offline.value, isFalse);
      async.elapse(const Duration(seconds: 3));
      expect(probes, 1);
      expect(NetStatus.offline.value, isTrue);

      // Vẫn mất mạng: hỏi lại mỗi 10 giây, không tự tắt.
      async.elapse(const Duration(seconds: 10));
      expect(probes, 2);
      expect(NetStatus.offline.value, isTrue);

      // Có mạng lại: lượt hỏi kế tiếp tắt dải và thôi hỏi.
      up = true;
      async.elapse(const Duration(seconds: 10));
      expect(NetStatus.offline.value, isFalse);
      async.elapse(const Duration(minutes: 1));
      expect(probes, 3);
    });
  });

  test('rớt thoáng qua: hỏi lại thông thì không bật dải', () {
    fakeAsync((async) {
      NetStatus.probe = () async => true;
      NetStatus.requestFailed();
      async.elapse(const Duration(seconds: 3));
      expect(NetStatus.offline.value, isFalse);
    });
  });

  test('đang mất mạng mà một yêu cầu thành công thì tắt dải ngay', () {
    fakeAsync((async) {
      NetStatus.probe = () async => false;
      NetStatus.requestFailed();
      async.elapse(const Duration(seconds: 3));
      expect(NetStatus.offline.value, isTrue);
      NetStatus.requestOk();
      expect(NetStatus.offline.value, isFalse);
      async.elapse(const Duration(minutes: 1));
      expect(NetStatus.offline.value, isFalse, reason: 'đã thôi hỏi lại');
    });
  });

  test('chốt JWT báo hỏng / thông; lượt hỏi lại không đi qua chốt', () async {
    var up = false;
    final sent = <http.BaseRequest>[];
    final gate = JwtGateHttpClient(
      anonKey: 'anon',
      probeUrl: Uri.parse('https://x.test/supabase/rest/v1/'),
      inner: MockClient((req) async {
        sent.add(req);
        if (!up) throw const SocketException('mat mang');
        return http.Response('', 401); // máy chủ có trả lời là còn mạng
      }),
    );
    NetStatus.confirmAfter = const Duration(milliseconds: 20);
    NetStatus.probeEvery = const Duration(milliseconds: 20);

    await expectLater(
      gate.get(Uri.parse('https://x.test/supabase/rest/v1/products')),
      throwsA(isA<SocketException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(NetStatus.offline.value, isTrue);
    expect(sent.last.method, 'HEAD');
    expect(sent.last.headers['apikey'], 'anon');

    up = true;
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(NetStatus.offline.value, isFalse);
  });

  testWidgets('dải hiện khi mất mạng và không dựng lại màn bên dưới', (tester) async {
    var inits = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => NetStatusBanner(child: child!),
      home: _Probe(onInit: () => inits++),
    ));
    expect(find.text(NetStatusBanner.text), findsNothing);

    NetStatus.offline.value = true;
    await tester.pump();
    expect(find.text(NetStatusBanner.text), findsOneWidget);
    expect(inits, 1, reason: 'bật dải không được làm mất chồng màn đang mở');

    NetStatus.offline.value = false;
    await tester.pump();
    expect(find.text(NetStatusBanner.text), findsNothing);
    expect(inits, 1);
  });

  test('màn Bán hàng: mất mạng thì không mời thêm sản phẩm đầu tiên', () {
    final src = File('lib/screens/pos_screen.dart').readAsStringSync();
    final start = src.indexOf('Widget _buildEmptyProducts() {');
    final body = src.substring(start, src.indexOf('Widget _buildEmptyProductsOnline()', start));
    expect(body, contains('NetStatus.offline'));
    expect(body, contains('Chưa tải được thực đơn'));
    expect(body, isNot(contains('Thêm sản phẩm mới')));
  });
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Text('màn'));
}
