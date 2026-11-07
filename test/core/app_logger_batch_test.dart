import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/app_logger.dart';

void main() {
  late List<(String, List<Map<String, dynamic>>)> sent;

  group('Lỗi văng', () {
    late List<List<Map<String, dynamic>>> got;
    setUp(() {
      AppLogger.resetForTest();
      got = [];
      AppLogger.senderOverride = (_, rows) async => got.add(List.of(rows));
      AppLogger.updateSession(storeId: 's1', staffName: 'Như');
    });
    List<Map<String, dynamic>> all() => got.expand((r) => r).toList();

    test('ghi mức ERROR, nhãn uncaught, cắt độ dài', () async {
      AppLogger.uncaught(Exception('x' * 500), StackTrace.fromString('a' * 5000));
      await AppLogger.flushNow();
      final row = all().single;
      expect(row['level'], 'ERROR');
      expect(row['tag'], 'uncaught');
      expect((row['message'] as String).length, 300);
      expect((row['details'] as String).length, lessThanOrEqualTo(3001));
    });

    test('cùng lỗi tối đa 1 dòng mỗi phút; lỗi khác vẫn ghi', () async {
      var now = DateTime(2026, 11, 5, 9);
      AppLogger.uncaughtNow = () => now;
      AppLogger.uncaught(Exception('A'), null);
      AppLogger.uncaught(Exception('A'), null);
      AppLogger.uncaught(Exception('B'), null);
      now = now.add(const Duration(seconds: 59));
      AppLogger.uncaught(Exception('A'), null);
      await Future<void>.delayed(const Duration(milliseconds: 20));  // lỗi gửi ngay, chờ các lượt gửi xong
      await AppLogger.flushNow();
      expect(all(), hasLength(2));
      now = now.add(const Duration(seconds: 2));
      AppLogger.uncaught(Exception('A'), null);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await AppLogger.flushNow();
      expect(all(), hasLength(3));
    });

    test('lỗi đổi nội dung mỗi lần: gộp theo phần chữ, không ngập', () async {
      for (var i = 0; i < 500; i++) {
        AppLogger.uncaught(Exception('ClientException id=$i'), null);
      }
      await AppLogger.flushNow();
      expect(all(), hasLength(1));
    });

    test('mọi lỗi tối đa 30 dòng mỗi phút', () async {
      var now = DateTime(2026, 11, 5, 9);
      AppLogger.uncaughtNow = () => now;
      const letters = 'abcdefghijklmnopqrstuvwxyz';
      String name(int i) => '${letters[i % 26]}${letters[(i ~/ 26) % 26]}';
      for (var i = 0; i < 200; i++) {
        AppLogger.uncaught(Exception(name(i)), null);
      }
      await AppLogger.flushNow();
      expect(all(), hasLength(30));
      now = now.add(const Duration(minutes: 1, seconds: 1));
      AppLogger.uncaught(Exception('lỗi mới'), null);
      await AppLogger.flushNow();
      expect(all(), hasLength(31));
    });

    test('che dữ liệu khách trong chữ lỗi', () {
      expect(AppLogger.sanitizeErrorText('Failed uri=https://a.vn/rest/customers?phone=eq.0901234567&x=1 end'),
          'Failed uri=https://a.vn/rest/customers?… end');
      expect(AppLogger.sanitizeErrorText('khách 0901234567 gọi'), 'khách *** gọi');
      expect(AppLogger.sanitizeErrorText('Failing row contains (1, Lan, 090)'), 'Failing row contains (…)');
      expect(AppLogger.sanitizeErrorText('Đơn 12345 lỗi'), 'Đơn 12345 lỗi');
    });

    test('bộ bắt lỗi giữ xử lý mặc định, không nuốt lỗi', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final original = FlutterError.onError;
      var previousCalled = 0;
      FlutterError.onError = (_) => previousCalled++;
      AppLogger.attachUncaughtHandlers();
      FlutterError.onError!(FlutterErrorDetails(exception: Exception('vẽ lỗi')));
      final handled = AppLogger.onPlatformError(Exception('bất đồng bộ'), StackTrace.empty);
      FlutterError.onError = original;
      expect(previousCalled, 1);
      expect(handled, isFalse);
      await AppLogger.flushNow();
      expect(all().map((r) => r['tag']).toSet(), {'uncaught'});
      expect(all(), hasLength(2));
    });

    test('không ném lỗi dù đối tượng lỗi tự hỏng', () {
      expect(() => AppLogger.uncaught(_BadError(), null), returnsNormally);
    });
  });

  setUp(() {
    AppLogger.resetForTest();
    sent = [];
    AppLogger.senderOverride = (storeId, rows) async {
      sent.add((storeId, List.of(rows)));
    };
    AppLogger.updateSession(storeId: 's1', staffName: 'Như');
    AppLogger.setDeviceId('dev1');
  });

  test(
    'chưa đủ 60 dòng thì chưa gửi; dòng thứ 60 gửi MỘT request 60 dòng',
    () async {
      for (var i = 0; i < 59; i++) {
        AppLogger.info('t', 'm$i');
      }
      await Future<void>.delayed(Duration.zero);
      expect(sent, isEmpty);
      AppLogger.info('t', 'm59');
      await Future<void>.delayed(Duration.zero);
      expect(sent.length, 1);
      expect(sent.single.$2.length, 60);
      expect(AppLogger.pendingCount, 0);
    },
  );

  test('sau 180 giây kể từ dòng đầu thì tự gửi', () {
    fakeAsync((async) {
      AppLogger.info('t', 'a');
      AppLogger.info('t', 'b');
      async.elapse(const Duration(seconds: 179));
      expect(sent, isEmpty);
      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(sent.length, 1);
      expect(sent.single.$2.map((r) => r['message']), ['a', 'b']);
    });
  });

  test('sự kiện quan trọng và lỗi gửi ngay', () async {
    AppLogger.action('cancel_table', 'Hủy bàn', table: 'B 1', critical: true);
    await Future<void>.delayed(Duration.zero);
    expect(sent.length, 1);
    AppLogger.error('t', 'hỏng');
    await Future<void>.delayed(Duration.zero);
    expect(sent.length, 2);
  });

  test('flushNow gửi phần còn lại; hàng trống không gọi máy chủ', () async {
    await AppLogger.flushNow();
    expect(sent, isEmpty);
    AppLogger.info('t', 'x');
    await AppLogger.flushNow();
    expect(sent.length, 1);
  });

  test('gửi lỗi thì giữ hàng chờ, giữ thứ tự, lần sau gửi bù đủ', () async {
    var fail = true;
    AppLogger.senderOverride = (storeId, rows) async {
      if (fail) throw Exception('mất mạng');
      sent.add((storeId, List.of(rows)));
    };
    AppLogger.info('t', 'một');
    AppLogger.info('t', 'hai');
    await AppLogger.flushNow();
    expect(sent, isEmpty);
    expect(AppLogger.pendingCount, 2);
    fail = false;
    AppLogger.info('t', 'ba');
    await AppLogger.flushNow();
    expect(sent.single.$2.map((r) => r['message']), ['một', 'hai', 'ba']);
    expect(AppLogger.pendingCount, 0);
  });

  test(
    'mỗi dòng mang sẵn quán/nhân viên/thiết bị/giờ thật lúc xảy ra',
    () async {
      AppLogger.info('t', 'a');
      AppLogger.updateSession(storeId: 's2', staffName: 'Khác');
      AppLogger.info('t', 'b');
      await AppLogger.flushNow();
      expect(sent.length, 2, reason: 'hai quán -> hai request');
      final a = sent.firstWhere((e) => e.$1 == 's1').$2.single;
      final b = sent.firstWhere((e) => e.$1 == 's2').$2.single;
      expect(a['staff_name'], 'Như');
      expect(b['staff_name'], 'Khác');
      expect(a['device_id'], 'dev1');
      expect(DateTime.tryParse(a['created_at'] as String), isNotNull);
    },
  );

  test('hàng chờ có giới hạn, bỏ dòng cũ nhất', () async {
    AppLogger.senderOverride = (storeId, rows) async => throw Exception('x');
    for (var i = 0; i < AppLogger.maxQueue + 50; i++) {
      AppLogger.debug('t', 'ignored');
      AppLogger.info('t', 'n$i');
    }
    expect(AppLogger.pendingCount, AppLogger.maxQueue);
  });

  test('logUserAction chỉ tạo MỘT dòng (không còn ghi đôi)', () async {
    AppLogger.logUserAction(
      tag: 'system',
      action: 'Mở module [/table]',
      details: {'route': '/table'},
    );
    await AppLogger.flushNow();
    expect(sent.single.$2.length, 1);
  });

  test('action() ghi trường chuẩn, không có PIN/mật khẩu', () async {
    AppLogger.action(
      'cancel_table',
      'Hủy bàn',
      table: 'B 1',
      sessionId: 'sess-1',
      lines: 1,
      total: 59000,
      approver: 'Bùi Thanh Lâm',
      reason: 'Khách đổi ý',
      result: 'ok',
    );
    await AppLogger.flushNow();
    final row = sent.single.$2.single;
    expect(row['tag'], 'action');
    expect(row['message'], contains('Hủy bàn'));
    expect(row['message'], contains('B 1'));
    final d = jsonDecode(row['details'] as String) as Map<String, dynamic>;
    expect(d['act'], 'cancel_table');
    expect(d['session'], 'sess-1');
    expect(d['total'], 59000);
    expect(d['approver'], 'Bùi Thanh Lâm');
    expect(d['staff'], 'Như');
    expect(d['device'], 'dev1');
    expect(
      d.keys.any(
        (k) =>
            k.toLowerCase().contains('pin') ||
            k.toLowerCase().contains('password'),
      ),
      isFalse,
    );
  });
}

class _BadError {
  @override
  String toString() => throw StateError('hỏng');
}
