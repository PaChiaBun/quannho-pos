import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/staff_password_repository.dart';
import 'package:quannho_pos/screens/staff_password_dialog.dart';

// Hỗ trợ chủ quán H3 (30/10): Chủ quán tự gõ mật khẩu mới cho nhân viên.
void main() {
  Future<bool?> open(WidgetTester tester, StaffPasswordRepository repo) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showStaffPasswordDialog(ctx, storeId: 's1', userId: 'u1', staffName: 'Lan', repository: repo);
            },
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('gõ đúng 2 lần → gửi đúng tham số, đóng hộp, trả true', (tester) async {
    Map<String, dynamic>? sent;
    var result = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showStaffPasswordDialog(ctx, storeId: 's1', userId: 'u1', staffName: 'Lan',
                  repository: StaffPasswordRepository(rpcOverride: (fn, p) async {
                    expect(fn, 'store_staff_set_password_v1');
                    sent = p;
                    return {'ok': true};
                  }));
            },
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt lại mật khẩu — Lan'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('staff_pw_new')), 'MatKhau123');
    await tester.enterText(find.byKey(const Key('staff_pw_confirm')), 'MatKhau123');
    await tester.tap(find.byKey(const Key('staff_pw_save')));
    await tester.pumpAndSettle();
    expect(sent, {'p_store': 's1', 'p_user': 'u1', 'p_new_password': 'MatKhau123'});
    expect(result, isTrue);
    expect(find.byKey(const Key('staff_pw_save')), findsNothing);
  });

  testWidgets('kiểm tại máy: quá ngắn, khoảng trắng đầu/cuối, 2 lần khác nhau → không gửi', (tester) async {
    var calls = 0;
    await open(tester, StaffPasswordRepository(rpcOverride: (fn, p) async {
      calls++;
      return {'ok': true};
    }));
    Future<String?> tryPw(String a, String b) async {
      await tester.enterText(find.byKey(const Key('staff_pw_new')), a);
      await tester.enterText(find.byKey(const Key('staff_pw_confirm')), b);
      await tester.tap(find.byKey(const Key('staff_pw_save')));
      await tester.pumpAndSettle();
      final e = find.byKey(const Key('staff_pw_error'));
      return e.evaluate().isEmpty ? null : (tester.widget<Text>(e).data);
    }
    expect(await tryPw('ngan', 'ngan'), 'Mật khẩu phải từ 8 đến 72 ký tự.');
    expect(await tryPw(' MatKhau123', ' MatKhau123'), 'Mật khẩu không được có khoảng trắng ở đầu hoặc cuối.');
    expect(await tryPw('MatKhau123', 'MatKhau124'), 'Hai lần nhập mật khẩu không giống nhau.');
    expect(calls, 0);
  });

  testWidgets('máy chủ từ chối → báo câu dễ hiểu, hộp vẫn mở để sửa', (tester) async {
    await open(tester, StaffPasswordRepository(rpcOverride: (fn, p) async => {'ok': false, 'error': 'OTHER_STORES'}));
    await tester.enterText(find.byKey(const Key('staff_pw_new')), 'MatKhau123');
    await tester.enterText(find.byKey(const Key('staff_pw_confirm')), 'MatKhau123');
    await tester.tap(find.byKey(const Key('staff_pw_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('còn làm ở quán khác'), findsOneWidget);
    expect(find.byKey(const Key('staff_pw_save')), findsOneWidget);
  });

  test('mọi mã lỗi máy chủ đều có câu tiếng Việt; lỗi mạng → NETWORK', () async {
    for (final c in ['OWNER_ONLY', 'SELF', 'NOT_MEMBER', 'TARGET_OWNER', 'OTHER_STORES', 'NOT_ACTIVE', 'FORBIDDEN', 'BAD_PASSWORD',
                     'TOO_MANY', 'NETWORK']) {
      expect(staffPasswordErrorText(c).contains(c), isFalse, reason: c);
    }
    final off = StaffPasswordRepository(rpcOverride: (fn, p) async => throw Exception('x'));
    expect(await off.setPassword(storeId: 's', userId: 'u', newPassword: 'MatKhau123'), 'NETWORK');
  });

  test('màn Nhân viên: nút "Đặt lại mật khẩu" chỉ nằm trong khối Chủ quán (isCallerOwner)', () {
    final src = File('lib/screens/nhan_vien_screen.dart').readAsStringSync();
    final i = src.indexOf("key: const Key('staff_reset_password')");
    expect(i, greaterThan(0));
    final guard = src.lastIndexOf('if (isCallerOwner) ...[', i);
    expect(guard, greaterThan(0));
    expect(i - guard, lessThan(2000), reason: 'nút phải nằm ngay trong khối if (isCallerOwner)');
    final j = src.indexOf("key: const Key('staff_rename')");
    expect(j > guard && j < i, isTrue, reason: 'nút Đổi tên cũng nằm trong khối Chủ quán');
    expect(src.substring(guard + 'if (isCallerOwner) ...['.length, i).contains('if ('), isFalse,
        reason: 'không có điều kiện khác chen giữa');
  });

  test('màn Khôi phục mật khẩu không còn hứa Quản lý đặt lại được / hỗ trợ 24/7', () {
    final src = File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(src.contains('Chủ quán hoặc Quản lý truy cập vào mục Nhân Viên'), isFalse);
    expect(src.contains('24/7'), isFalse);
    expect(src.contains('Chủ quán vào mục Nhân viên → chọn tên bạn → bấm "Đặt lại mật khẩu"'), isTrue);
  });
}
