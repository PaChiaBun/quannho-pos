import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/app_logger.dart';

void main() {
  late List<(String, List<Map<String, dynamic>>)> sent;

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
