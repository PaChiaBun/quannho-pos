import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/app_heartbeat_service.dart';
import 'package:quannho_pos/core/widgets/create_store_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<(String, Map<String, dynamic>)> calls;
  late dynamic reply;

  setUp(() {
    SharedPreferences.setMockInitialValues({'device_id': 'may-1'});
    AppHeartbeat.resetForTest();
    AppHeartbeat.versionOverride = ('1.0.7', 25);
    AppHeartbeat.now = () => DateTime(2026, 11, 5, 9);
    calls = [];
    reply = {'ok': true};
    AppHeartbeat.rpcOverride = (fn, params) async {
      calls.add((fn, params));
      if (reply is Exception) throw reply as Exception;
      return reply;
    };
  });
  tearDown(AppHeartbeat.resetForTest);

  test('gửi đúng mã máy, nền tảng, phiên bản; không có tên hay số điện thoại', () async {
    await AppHeartbeat.ping('s1');
    expect(calls.single.$1, 'app_heartbeat_v1');
    final p = calls.single.$2;
    expect(p.keys.toSet(), {'p_store', 'p_device', 'p_platform', 'p_version', 'p_build'});
    expect(p['p_store'], 's1');
    expect(p['p_device'], 'may-1');
    expect(p['p_version'], '1.0.7');
    expect(p['p_build'], 25);
  });

  test('chưa vào quán thì không gửi', () async {
    await AppHeartbeat.ping(null);
    await AppHeartbeat.ping('');
    expect(calls, isEmpty);
  });

  test('cùng quán cùng ngày chỉ gửi 1 lần; qua ngày hoặc đổi quán thì gửi lại', () async {
    await AppHeartbeat.ping('s1');
    await AppHeartbeat.ping('s1');
    expect(calls, hasLength(1));
    await AppHeartbeat.ping('s2');
    expect(calls, hasLength(2));
    AppHeartbeat.now = () => DateTime(2026, 11, 6, 0, 1);
    await AppHeartbeat.ping('s2');
    expect(calls, hasLength(3));
  });

  test('hai lần gọi cùng lúc chỉ gửi 1 lần', () async {
    final gate = Completer<void>();
    AppHeartbeat.rpcOverride = (fn, params) async {
      calls.add((fn, params));
      await gate.future;
      return {'ok': true};
    };
    final a = AppHeartbeat.ping('s1');
    final b = AppHeartbeat.ping('s1');
    gate.complete();
    await Future.wait([a, b]);
    expect(calls, hasLength(1));
  });

  test('lỗi mạng không ném lỗi và lần sau gửi lại', () async {
    reply = Exception('mất mạng');
    await expectLater(AppHeartbeat.ping('s1'), completes);
    reply = {'ok': true};
    await AppHeartbeat.ping('s1');
    expect(calls, hasLength(1), reason: 'chưa tới 10 phút thì chưa thử lại');
    AppHeartbeat.now = () => DateTime(2026, 11, 5, 9, 11);
    await AppHeartbeat.ping('s1');
    expect(calls, hasLength(2));
  });

  test('máy chủ từ chối thì lần sau gửi lại', () async {
    reply = {'ok': false, 'error': 'FORBIDDEN'};
    await AppHeartbeat.ping('s1');
    await AppHeartbeat.ping('s1');
    expect(calls, hasLength(1), reason: 'không gửi lại liên tục khi bị từ chối');
    reply = {'ok': true};
    AppHeartbeat.now = () => DateTime(2026, 11, 5, 9, 11);
    await AppHeartbeat.ping('s1');
    expect(calls, hasLength(2));
  });

  test('máy chưa có mã thì tạo một mã và giữ nguyên', () async {
    SharedPreferences.setMockInitialValues({});
    await AppHeartbeat.ping('s1');
    await AppHeartbeat.ping('s2');
    final first = calls[0].$2['p_device'] as String;
    expect(first, isNotEmpty);
    expect(calls[1].$2['p_device'], first);
    expect((await SharedPreferences.getInstance()).getString('device_id'), first);
  });

  test('nhãn nền tảng khớp danh sách máy chủ cho phép', () {
    const allowed = {'web', 'android', 'ios', 'windows', 'macos', 'linux'};
    expect(AppHeartbeat.platformLabel(isWeb: true), 'web');
    for (final p in TargetPlatform.values) {
      expect(allowed, contains(AppHeartbeat.platformLabel(isWeb: false, platform: p)));
    }
    expect(AppHeartbeat.platformLabel(isWeb: false, platform: TargetPlatform.iOS), 'ios');
  });

  test('nguồn khách: không chọn thì không gửi; lỗi không ném ra', () async {
    await AppHeartbeat.saveSignupSource('s1', null);
    expect(calls, isEmpty);
    await AppHeartbeat.saveSignupSource('s1', 'friend');
    expect(calls.single.$1, 'store_signup_source_set_v1');
    expect(calls.single.$2, {'p_store': 's1', 'p_source': 'friend'});
    reply = Exception('lỗi');
    await expectLater(AppHeartbeat.saveSignupSource('s1', 'google'), completes);
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1200));
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () => showCreateStoreSheet(context, ref),
        child: const Text('Mở'),
      ),
    ))));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('form tạo quán có ô nguồn khách, không bắt buộc, đủ lựa chọn', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    await openSheet(tester);
    expect(find.text('Biết Quán Nhỏ từ đâu? (không bắt buộc)'), findsOneWidget);
    await tester.tap(find.text('Biết Quán Nhỏ từ đâu? (không bắt buộc)'));
    await tester.pumpAndSettle();
    for (final label in kSignupSources.values) {
      expect(find.text(label), findsWidgets);
    }
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('màn nhỏ có bàn phím: không tràn, cuộn tới được nút tạo quán', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Consumer(
      builder: (context, ref, _) => TextButton(
        onPressed: () => showCreateStoreSheet(context, ref),
        child: const Text('Mở'),
      ),
    ))));
    await tester.tap(find.text('Mở'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final button = find.byType(ElevatedButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(button).dy, lessThanOrEqualTo(360));
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('iOS không có form tạo quán nên không có ô nguồn khách', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await openSheet(tester);
    expect(find.text('Biết Quán Nhỏ từ đâu? (không bắt buộc)'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
    await tester.binding.setSurfaceSize(null);
  });
}
