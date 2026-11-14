import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/staff_password_repository.dart';
import 'package:quannho_pos/screens/staff_name_dialog.dart';

// Đổi tên an toàn (31/10): Chủ quán đổi tên nhân viên; ai cũng tự đổi tên trong Cài đặt.
void main() {
  Future<void> open(WidgetTester tester, StaffPasswordRepository repo, void Function(String?) onResult) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: TextButton(
            onPressed: () async => onResult(await showStaffNameDialog(ctx, storeId: 's1', userId: 'u1', currentName: 'Lan', repository: repo)),
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
  }

  testWidgets('đổi tên: gộp khoảng trắng, gửi đúng tham số, trả tên mới', (tester) async {
    Map<String, dynamic>? sent;
    String? result;
    await open(tester, StaffPasswordRepository(rpcOverride: (fn, p) async {
      expect(fn, 'store_staff_set_name_v1');
      sent = p;
      return {'ok': true};
    }), (r) => result = r);
    expect(find.text('Lan'), findsOneWidget); // điền sẵn tên cũ
    await tester.enterText(find.byKey(const Key('staff_name_input')), '  Lan   Thu Ngân ');
    await tester.tap(find.byKey(const Key('staff_name_save')));
    await tester.pumpAndSettle();
    expect(sent, {'p_store': 's1', 'p_user': 'u1', 'p_name': 'Lan Thu Ngân'});
    expect(result, 'Lan Thu Ngân');
  });

  testWidgets('tên quá ngắn → báo tại máy, không gửi; không đổi gì → đóng, không gửi', (tester) async {
    var calls = 0;
    String? result = 'chưa';
    await open(tester, StaffPasswordRepository(rpcOverride: (fn, p) async {
      calls++;
      return {'ok': true};
    }), (r) => result = r);
    await tester.enterText(find.byKey(const Key('staff_name_input')), 'A');
    await tester.tap(find.byKey(const Key('staff_name_save')));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.byKey(const Key('staff_name_error'))).data, 'Tên phải từ 2 đến 50 ký tự.');
    await tester.enterText(find.byKey(const Key('staff_name_input')), 'Lan');
    await tester.tap(find.byKey(const Key('staff_name_save')));
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(result, isNull);
  });

  testWidgets('đếm độ dài theo ký tự như máy chủ: 25 emoji (50 đơn vị UTF-16 + chữ) vẫn gửi được', (tester) async {
    var calls = 0;
    await open(tester, StaffPasswordRepository(rpcOverride: (fn, p) async {
      calls++;
      return {'ok': true};
    }), (_) {});
    await tester.enterText(find.byKey(const Key('staff_name_input')), 'Lan ${'😀' * 25}');
    await tester.tap(find.byKey(const Key('staff_name_save')));
    await tester.pumpAndSettle();
    expect(calls, 1);
  });

  testWidgets('máy chủ từ chối (người chưa đăng nhập vào quán) → câu dễ hiểu, hộp vẫn mở', (tester) async {
    await open(tester, StaffPasswordRepository(rpcOverride: (fn, p) async => {'ok': false, 'error': 'NOT_ACTIVE'}), (_) {});
    await tester.enterText(find.byKey(const Key('staff_name_input')), 'Tên mới');
    await tester.tap(find.byKey(const Key('staff_name_save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa từng tự đăng nhập'), findsOneWidget);
    expect(find.byKey(const Key('staff_name_save')), findsOneWidget);
  });

  test('mọi mã lỗi đổi tên có câu tiếng Việt', () {
    for (final c in ['BAD_NAME', 'OWNER_ONLY', 'SELF', 'TARGET_OWNER', 'OTHER_STORES', 'NOT_ACTIVE', 'NOT_MEMBER', 'TOO_MANY',
                     'FORBIDDEN', 'NETWORK']) {
      expect(staffNameErrorText(c).contains(c), isFalse, reason: c);
    }
  });

  test('app tự đổi tên gọi đúng hàm update_my_display_name_v4 (máy chủ mới giữ tên hàm này)', () {
    final src = File('lib/core/services/user_auth_service.dart').readAsStringSync();
    expect(src.contains("'update_my_display_name_v4'"), isTrue);
    final mig = File('supabase/migrations/20261031_doi_ten_an_toan.sql').readAsStringSync();
    expect(mig.contains('FUNCTION public.update_my_display_name_v4(p_display_name text)'), isTrue);
    expect(mig.contains("'display_name', v_name"), isTrue);
  });
}
