import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart';
import 'package:quannho_pos/core/repositories/module_repository.dart';
import 'package:quannho_pos/core/utils/kitchen_unsent.dart';
import 'package:quannho_pos/core/utils/stale_lock.dart';

String _jwt(Map<String, dynamic> payload) {
  String enc(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return 'Bearer ${enc({'alg': 'HS256'})}.${enc(payload)}.sig';
}

BanSessionItemModel _item(String status, DateTime addedAt) =>
    BanSessionItemModel(
      id: addedAt.microsecondsSinceEpoch.toString() + status,
      sessionId: 's',
      productId: 'p',
      productName: 'Món',
      price: 1000,
      quantity: 1,
      addedAt: addedAt.millisecondsSinceEpoch,
      kitchenStatus: status,
    );

void main() {
  group('không ghi đè cấu hình module khi đọc lỗi/anon', () {
    test('có dòng cấu hình -> dùng bản máy chủ', () {
      expect(
        decideModuleBootstrap(
          fetchOk: true,
          rowFound: true,
          authenticated: false,
        ),
        ModuleBootstrap.useRemote,
      );
    });
    test('anon (đăng xuất/đổi ca) đọc ra rỗng -> KHÔNG ghi mặc định', () {
      expect(
        decideModuleBootstrap(
          fetchOk: true,
          rowFound: false,
          authenticated: false,
        ),
        ModuleBootstrap.useDefaultsNoSave,
      );
    });
    test('đọc lỗi mạng -> KHÔNG ghi mặc định', () {
      expect(
        decideModuleBootstrap(
          fetchOk: false,
          rowFound: false,
          authenticated: true,
        ),
        ModuleBootstrap.useDefaultsNoSave,
      );
    });
    test(
      'lần đầu thật (đọc ok, chưa có dòng, đã đăng nhập JWT) -> được ghi',
      () {
        expect(
          decideModuleBootstrap(
            fetchOk: true,
            rowFound: false,
            authenticated: true,
          ),
          ModuleBootstrap.migrateAndSave,
        );
      },
    );
  });

  group('jwtIsAuthenticated', () {
    final now = DateTime.utc(2026, 10, 19, 6);
    final future =
        now.add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    final past =
        now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
    test('role authenticated còn hạn -> true', () {
      expect(
        jwtIsAuthenticated(
          _jwt({'role': 'authenticated', 'exp': future}),
          now: now,
        ),
        isTrue,
      );
    });
    test('anon / hết hạn / rỗng / rác -> false', () {
      expect(
        jwtIsAuthenticated(_jwt({'role': 'anon', 'exp': future}), now: now),
        isFalse,
      );
      expect(
        jwtIsAuthenticated(
          _jwt({'role': 'authenticated', 'exp': past}),
          now: now,
        ),
        isFalse,
      );
      expect(jwtIsAuthenticated(null, now: now), isFalse);
      expect(jwtIsAuthenticated('Bearer abc', now: now), isFalse);
    });
  });

  group('StaleLock', () {
    test('đang giữ thì không lấy được; giữ quá hạn thì tự mở và báo', () {
      final lock = StaleLock(maxHold: const Duration(seconds: 45));
      final t0 = DateTime(2026, 10, 19, 6);
      expect(lock.tryAcquire(t0), isTrue);
      expect(lock.tryAcquire(t0.add(const Duration(seconds: 10))), isFalse);
      Duration? stale;
      expect(
        lock.tryAcquire(
          t0.add(const Duration(seconds: 50)),
          onStale: (d) => stale = d,
        ),
        isTrue,
      );
      expect(stale, const Duration(seconds: 50));
    });
    test('release mở khóa ngay', () {
      final lock = StaleLock();
      final t0 = DateTime(2026, 10, 19, 6);
      lock.tryAcquire(t0);
      lock.release();
      expect(lock.tryAcquire(t0.add(const Duration(seconds: 1))), isTrue);
    });
  });

  group('món chưa gửi bếp quá 3 phút', () {
    final now = DateTime(2026, 10, 19, 6, 30);
    test('chỉ tính món chua_gui đã quá 3 phút', () {
      final items = [
        _item('chua_gui', now.subtract(const Duration(minutes: 4))), // quá hạn
        _item('chua_gui', now.subtract(const Duration(minutes: 2))), // chưa
        _item('da_gui', now.subtract(const Duration(minutes: 30))), // đã gửi
        _item('huy', now.subtract(const Duration(minutes: 30))),
      ];
      expect(overdueUnsentItems(items, now).length, 1);
    });
    test('đúng 3 phút vẫn cảnh báo, 179 giây thì chưa', () {
      expect(
        overdueUnsentItems([
          _item('chua_gui', now.subtract(const Duration(minutes: 3))),
        ], now).length,
        1,
      );
      expect(
        overdueUnsentItems([
          _item('chua_gui', now.subtract(const Duration(seconds: 179))),
        ], now).length,
        0,
      );
    });
  });

  test(
    'kitchenStep: quá hạn thì ném KitchenStepTimeout nêu đúng tên bước',
    () async {
      Object? err;
      try {
        await kitchenStep(
          'tạo phiếu bếp',
          Future<void>.delayed(const Duration(seconds: 5)),
          timeout: const Duration(milliseconds: 50),
        );
      } catch (e) {
        err = e;
      }
      expect(err, isA<KitchenStepTimeout>());
      expect((err as KitchenStepTimeout).step, 'tạo phiếu bếp');
    },
  );

  group('mergeModuleOrder: Xong chỉ sắp xếp, không làm mất module', () {
    const server = ['pos', 'report', 'kitchen', 'table', 'bill_printer'];
    test('màn hình thiếu module (chỉ 4 mặc định) -> máy chủ vẫn giữ đủ', () {
      final merged = mergeModuleOrder(server, [
        'pos',
        'report',
        'finance',
        'kho',
      ]);
      expect(merged.toSet(), server.toSet());
      expect(merged.first, 'pos');
      expect(merged[1], 'report');
    });
    test('đổi thứ tự được áp dụng', () {
      expect(
        mergeModuleOrder(server, [
          'table',
          'kitchen',
          'pos',
          'report',
          'bill_printer',
        ]),
        ['table', 'kitchen', 'pos', 'report', 'bill_printer'],
      );
    });
    test('id không còn trên máy chủ bị bỏ, không trùng lặp', () {
      expect(mergeModuleOrder(['pos', 'kho'], ['kho', 'cu', 'kho', 'pos']), [
        'kho',
        'pos',
      ]);
    });
  });
}
