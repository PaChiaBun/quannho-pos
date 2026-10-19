import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/screens/auth_screen.dart';

void main() {
  group('loginErrorMessage', () {
    test('sai mật khẩu / không có tài khoản => nói rõ sai SĐT hoặc mật khẩu', () {
      for (final code in ['INVALID_CREDENTIALS', 'WRONG_PASSWORD', 'USER_NOT_FOUND']) {
        final m = loginErrorMessage(code, 'bất kỳ');
        expect(m, contains('Sai số điện thoại hoặc mật khẩu'), reason: code);
        expect(m, isNot(contains('chụp lại')), reason: code);
      }
    });

    test('quá nhiều lần thử / máy chủ bận => hiện đúng câu server đã giải thích', () {
      expect(
        loginErrorMessage('RATE_LIMIT_EXCEEDED', 'Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút.'),
        'Quá nhiều lần thử thất bại. Vui lòng thử lại sau 5 phút.',
      );
      expect(
        loginErrorMessage('SERVER_BUSY', 'Máy chủ đang bận, vui lòng thử đăng nhập lại sau vài giây.'),
        'Máy chủ đang bận, vui lòng thử đăng nhập lại sau vài giây.',
      );
    });

    test('lỗi lạ hoặc thiếu câu giải thích => câu chung báo chủ app', () {
      expect(loginErrorMessage('SOMETHING_ELSE', 'x'), contains('chụp lại báo chủ app'));
      expect(loginErrorMessage(null, null), contains('chụp lại báo chủ app'));
      expect(loginErrorMessage('SERVER_BUSY', ''), contains('chụp lại báo chủ app'));
    });
  });
}
