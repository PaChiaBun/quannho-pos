import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase C Quick PIN & RPC Wiring Logic Tests', () {
    test('1. updateQuickPin rejects PINs that are not 6 digits', () async {
      expect(await UserAuthService.updateQuickPin('12345'), isFalse);
      expect(await UserAuthService.updateQuickPin('1234567'), isFalse);
      expect(await UserAuthService.updateQuickPin('abcdef'), isFalse);
      expect(await UserAuthService.updateQuickPin(''), isFalse);
    });

    test(
      '2. verifyManagerQuickPin rejects non-6-digit PIN before calling backend',
      () async {
        expect(
          await UserAuthService.verifyManagerQuickPin('store-1', '123'),
          isNull,
        );
        expect(
          await UserAuthService.verifyManagerQuickPin('store-1', 'abc123'),
          isNull,
        );
        expect(
          await UserAuthService.verifyManagerQuickPin('store-1', ''),
          isNull,
        );
      },
    );

    test(
      '3. createStore rejects empty store name before database call',
      () async {
        final res = await UserAuthService.createStore(
          userId: 'user-1',
          storeName: '   ',
        );
        expect(res.isSuccess, isFalse);
        expect(res.errorMessage, contains('Vui lòng nhập tên quán'));
      },
    );

    test(
      '4. joinStoreByCode rejects empty store code before database call',
      () async {
        final res = await UserAuthService.joinStoreByCode(
          userId: 'user-1',
          storeCode: '   ',
        );
        expect(res.isSuccess, isFalse);
        expect(res.errorMessage, contains('Vui lòng nhập mã quán'));
      },
    );

    test(
      '5. createStore preflight rejects missing onboarding before DB',
      () async {
        final res = await UserAuthService.createStore(
          userId: 'user-1',
          storeName: 'Quán thử nghiệm',
          jwtService: ConfiguredNoOnboardingService(),
        );
        expect(res.isSuccess, isFalse);
        expect(res.errorCode, 'ONBOARDING_TOKEN_REQUIRED');
      },
    );

    test(
      '6. joinStore preflight rejects missing onboarding before DB',
      () async {
        final res = await UserAuthService.joinStoreByCode(
          userId: 'user-1',
          storeCode: 'QN-TEST',
          jwtService: ConfiguredNoOnboardingService(),
        );
        expect(res.isSuccess, isFalse);
        expect(res.errorCode, 'ONBOARDING_TOKEN_REQUIRED');
      },
    );

    test('7. credential and membership RPCs have no legacy fallback', () async {
      final userAuth = await File(
        'lib/core/services/user_auth_service.dart',
      ).readAsString();
      final storeAuth = await File(
        'lib/core/services/store_auth_service.dart',
      ).readAsString();

      expect(userAuth, isNot(contains("select('quick_pin')")));
      expect(userAuth, isNot(contains("update({'quick_pin'")));
      expect(
        userAuth,
        isNot(contains("select('id, name, phone, role, pin_hash')")),
      );
      expect(userAuth, isNot(contains('RPC fallback')));
      expect(storeAuth, isNot(contains("'device_role': deviceRole")));
      expect(storeAuth, isNot(contains('Legacy Fallback')));
    });
  });
}

class ConfiguredNoOnboardingService extends PosJwtAuthService {
  @override
  bool get isConfigured => true;

  @override
  String? activeOnboardingJwtFor(String userId) => null;
}
