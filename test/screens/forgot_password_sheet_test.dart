import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/screens/auth_screen.dart';
import 'package:quannho_pos/screens/forgot_password_sheet.dart';

// Mật khẩu tạm bắt đổi + "Quên mật khẩu?" ở màn đăng nhập (26/10).
void main() {
  test('kiểm mật khẩu mới trên máy: ≥ 8 ký tự, nhập lại khớp, khác mật khẩu tạm', () {
    expect(newPasswordError('ngan', 'ngan', 'TAM1234567'), contains('8 đến 72'));
    expect(newPasswordError('a' * 73, 'a' * 73, 'TAM1234567'), contains('8 đến 72'));
    expect(newPasswordError('matkhau123', 'matkhau124', 'TAM1234567'), contains('không khớp'));
    expect(newPasswordError('TAM1234567', 'TAM1234567', 'TAM1234567'), contains('khác mật khẩu tạm'));
    expect(newPasswordError('matkhau123', 'matkhau123', 'TAM1234567'), isNull);
  });

  test('mật khẩu tạm hết hạn → hiện đúng câu máy chủ; sai mật khẩu → chỉ nút Quên mật khẩu', () {
    expect(loginErrorMessage('TEMP_PASSWORD_EXPIRED', 'Mật khẩu tạm đã hết hạn (quá 24 giờ).'), 'Mật khẩu tạm đã hết hạn (quá 24 giờ).');
    expect(loginErrorMessage('INVALID_CREDENTIALS', null), contains('Quên mật khẩu?'));
  });

  Future<String?> openDialog(WidgetTester tester, Future<Map<String, dynamic>> Function(String) submit) async {
    String? result = 'chưa đóng';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await showTempPasswordChangeDialog(ctx, tempPassword: 'TAM1234567', submit: submit),
          child: const Text('mở'),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('hộp đặt mật khẩu mới: kiểm trên máy trước, gửi đúng mật khẩu, đóng trả mật khẩu mới', (tester) async {
    final sent = <String>[];
    String? result = 'chưa đóng';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await showTempPasswordChangeDialog(ctx, tempPassword: 'TAM1234567', submit: (pw) async {
            sent.add(pw);
            return {'success': true, 'message': 'ok'};
          }),
          child: const Text('mở'),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('temp_new_pw')), 'matkhau123');
    await tester.enterText(find.byKey(const ValueKey('temp_new_pw2')), 'khac123456');
    await tester.tap(find.byKey(const ValueKey('temp_save')));
    await tester.pumpAndSettle();
    expect(find.text('Hai lần nhập mật khẩu mới không khớp'), findsOneWidget);
    expect(sent, isEmpty);

    await tester.enterText(find.byKey(const ValueKey('temp_new_pw2')), 'matkhau123');
    await tester.tap(find.byKey(const ValueKey('temp_save')));
    await tester.pumpAndSettle();
    expect(sent, ['matkhau123']);
    expect(find.text('Đặt mật khẩu mới'), findsNothing);
    expect(result, 'matkhau123');
  });

  testWidgets('máy chủ từ chối → hiện câu máy chủ, hộp vẫn mở; "Để sau" đóng không trả mật khẩu', (tester) async {
    await openDialog(tester, (pw) async => {'success': false, 'message': 'Mật khẩu tạm đã hết hạn (quá 24 giờ).'});
    await tester.enterText(find.byKey(const ValueKey('temp_new_pw')), 'matkhau123');
    await tester.enterText(find.byKey(const ValueKey('temp_new_pw2')), 'matkhau123');
    await tester.tap(find.byKey(const ValueKey('temp_save')));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu tạm đã hết hạn (quá 24 giờ).'), findsOneWidget);
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(find.text('Đặt mật khẩu mới'), findsNothing);
  });

  testWidgets('bảng Quên mật khẩu: chỉ nhân viên nhờ chủ quán, chủ quán gọi Hotline, có nút gọi', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => TextButton(onPressed: () => showForgotPasswordSheet(ctx), child: const Text('mở')),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Quên mật khẩu?'), findsOneWidget);
    expect(find.textContaining('Đặt lại mật khẩu'), findsOneWidget);
    expect(find.textContaining('24 giờ'), findsOneWidget);
    expect(find.text('Gọi Hotline $kHotlineDisplay'), findsOneWidget);
  });
}
