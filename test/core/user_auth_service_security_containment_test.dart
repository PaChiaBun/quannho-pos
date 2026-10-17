import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase S0 Auth Security Containment Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('1. Compile Gate: kEnableReviewerAccount default is false', () {
      expect(kEnableReviewerAccount, isFalse);
    });

    test(
      '2. Reviewer account is disabled unless explicitly compiled in',
      () async {
        final res = await UserAuthService.login(
          phone: '0999996666',
          password: '112233',
        );

        expect(res.isSuccess, isFalse);
        expect(await UserAuthService.getCurrentSession(), isNull);
      },
    );

    test('3. Client source never reads or writes password_hash', () async {
      final source = await File(
        'lib/core/services/user_auth_service.dart',
      ).readAsString();

      expect(source, isNot(contains('password_hash')));
      expect(source, isNot(contains('lookup_staff_by_phone')));
      expect(source, isNot(contains('attempting fallback')));
    });

    test(
      '4. Generic error messages on unauthenticated or missing account',
      () async {
        final res = await UserAuthService.login(
          phone: '0912345678',
          password: 'wrong_password_123',
        );

        expect(res.isSuccess, isFalse);
        expect(res.errorMessage, isNotNull);
        expect(
          res.errorMessage,
          anyOf(
            contains('Số điện thoại hoặc mật khẩu không chính xác'),
            contains('Không kết nối được server'),
          ),
        );
      },
    );

    test('5. UserAuthService clears all store tokens on logout', () async {
      await UserAuthService.logout();
      final session = await UserAuthService.getCurrentSession();
      expect(session, isNull);
    });
  });
}
