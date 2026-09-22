// test/core/user_auth_service_pos_jwt_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Flutter Unit & Wiring Security Tests for UserAuthService & POS JWT Lifecycle
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';
import 'package:quannho_pos/screens/auth_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    UserAuthService.rpcOverride = null;
    UserAuthService.jwtServiceOverride = null;
  });

  tearDown(() {
    UserAuthService.rpcOverride = null;
    UserAuthService.jwtServiceOverride = null;
  });

  group('UserAuthService POS JWT Lifecycle & Wiring Tests', () {
    test(
      '1. Login fails closed when POS JWT request fails (session NOT saved)',
      () async {
        SharedPreferences.setMockInitialValues({});

        final result = await UserAuthService.login(
          phone: '0900000000', // Unknown test phone
          password: 'wrong_password',
        );

        expect(result.isSuccess, false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_user_id'), isNull);
        expect(prefs.getString('auth_store_id'), isNull);
      },
    );

    test(
      '2. restoreSessionOnStartup keeps valid local session when POS JWT is disabled',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_user_id': 'user-123',
          'auth_store_id': 'store-456',
        });

        final disabledService = DisabledPosJwtService();
        final restored = await UserAuthService.restoreSessionOnStartup(
          jwtService: disabledService,
        );
        expect(restored, true);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_store_id'), 'store-456');
        expect(disabledService.applyCount, 0);
        expect(disabledService.clearCount, 0);
      },
    );

    test(
      '3. Concurrent selectStore executions allow only ONE active execution',
      () async {
        SharedPreferences.setMockInitialValues({});

        final membership = StoreMembership(
          storeId: 'store-1',
          storeName: 'Store 1',
          storeCode: 'ST1',
          role: 'owner',
          isOwner: true,
        );

        final futures = Future.wait([
          UserAuthService.selectStore(membership, password: 'test_pass'),
          UserAuthService.selectStore(membership, password: 'test_pass'),
          UserAuthService.selectStore(membership, password: 'test_pass'),
        ]);

        final results = await futures;
        final successCount = results.where((r) => r == true).length;
        expect(successCount, lessThanOrEqualTo(1));
      },
    );

    test(
      '4. Snapshot rollback restores old token and prefs when requestPosJwt fails but old auth apply succeeds',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_user_id': 'user-1',
          'auth_user_phone': '0900000000',
          'auth_store_id': 'old-store-id',
          'auth_store_name': 'Old Store',
          'auth_role': 'owner',
        });

        final mockJwtService = MockPosJwtService(
          storedToken: 'valid-old-token',
          mockRequestResult: {'success': false, 'error': 'INVALID_PASSWORD'},
          mockApplyResult: true,
        );

        final newMembership = StoreMembership(
          storeId: 'new-store-id',
          storeName: 'New Store',
          storeCode: 'NEW',
          role: 'cashier',
          isOwner: false,
        );

        final switchResult = await UserAuthService.selectStore(
          newMembership,
          phone: '0900000000',
          password: 'wrong_password',
          jwtService: mockJwtService,
        );

        expect(switchResult, false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_store_id'), 'old-store-id');
        expect(prefs.getString('auth_store_name'), 'Old Store');
      },
    );

    test(
      '5. UserAuthService.logout clears token and removes all auth prefs',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_user_id': 'user-1',
          'auth_user_phone': '0900000000',
          'auth_store_id': 'store-1',
          'store_id': 'store-1',
        });

        await UserAuthService.logout();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_user_id'), isNull);
        expect(prefs.getString('auth_store_id'), isNull);
        expect(prefs.getString('store_id'), isNull);
      },
    );

    test(
      '6. Snapshot rollback fails-closed (clears prefs & token) when restoring old auth fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_user_id': 'user-1',
          'auth_user_phone': '0900000000',
          'auth_store_id': 'old-store-id',
          'auth_store_name': 'Old Store',
        });

        final mockJwtService = MockPosJwtService(
          storedToken: 'corrupted-old-token',
          mockRequestResult: {'success': false, 'error': 'SERVER_ERROR'},
          mockApplyResult: false, // Old auth restore fails!
        );

        final newMembership = StoreMembership(
          storeId: 'new-store-id',
          storeName: 'New Store',
          storeCode: 'NEW',
          role: 'cashier',
          isOwner: false,
        );

        final switchResult = await UserAuthService.selectStore(
          newMembership,
          phone: '0900000000',
          password: 'pass',
          jwtService: mockJwtService,
        );

        expect(switchResult, false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_store_id'), isNull);
        expect(prefs.getString('auth_store_name'), isNull);
      },
    );

    test(
      '7. restoreSessionOnStartup returns false when applyAuthToSupabase fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'auth_user_id': 'user-123',
          'auth_store_id': 's1',
          'store_id': 's1',
        });

        final service = PosJwtAuthService(
          backendUrl: 'https://auth.example.com',
          authApplier: (token) async {
            throw Exception('REST setAuth failed');
          },
        );

        final restored = await UserAuthService.restoreSessionOnStartup(
          jwtService: service,
        );

        expect(restored, false);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('auth_store_id'), isNull);
      },
    );

    test(
      '10. Register preflight fails closed when POS JWT is unconfigured without touching DB',
      () async {
        final disabledService = DisabledPosJwtService();
        final result = await UserAuthService.register(
          phone: '0901234567',
          password: 'valid_password_123',
          displayName: 'Test Staff',
          jwtService: disabledService,
        );

        expect(result.isSuccess, false);
        expect(result.errorCode, 'POS_JWT_NOT_CONFIGURED');
      },
    );

    test(
      '11. JoinStoreByCode validates QN-XXXX format strictly',
      () async {
        final mockJwt = MockPosJwtService();
        // Rejects QN-A, QN-ABCDE, QN-@#$%, 123456, ABCD
        for (final badCode in ['QN-A', 'QN-ABCDE', 'QN-@#\$%', '123456', 'ABCD']) {
          final res = await UserAuthService.joinStoreByCode(
            storeCode: badCode,
            userId: 'user-123',
            jwtService: mockJwt,
          );
          expect(res.isSuccess, false, reason: 'Failed for $badCode');
          expect(res.errorCode, 'INVALID_STORE_CODE_FORMAT', reason: 'Failed for $badCode');
        }

        final resEmpty = await UserAuthService.joinStoreByCode(
          storeCode: '',
          userId: 'user-123',
          jwtService: mockJwt,
        );
        expect(resEmpty.isSuccess, false);
        expect(resEmpty.errorCode, 'STORE_CODE_REQUIRED');

        // Accepts QN-AB12
        UserAuthService.rpcOverride = (fn, {params}) async {
          if (fn == 'join_store_by_code_v4') {
            return {
              'success': true,
              'store_id': 'store-123',
              'store_code': 'QN-AB12',
              'store_name': 'Quán Nhỏ Test',
              'role': 'waiter',
              'is_owner': false,
            };
          }
          return {'success': false};
        };
        final successMockJwt = MockPosJwtService(
          mockExchangeResult: {'success': true, 'token': 'jwt-store-123'},
          mockOnboardingResult: {'success': true, 'token': 'onb-token'},
        );
        final resValid = await UserAuthService.joinStoreByCode(
          storeCode: 'QN-AB12',
          userId: 'user-123',
          onboardingJwt: 'valid-token',
          jwtService: successMockJwt,
        );
        expect(resValid.isSuccess, true);
        expect(resValid.storeCode, 'QN-AB12');
        expect(resValid.membership?.role, 'waiter');
      },
    );

    test('12. JoinStoreByCode uses direct error_code from RPC without guessing', () async {
      UserAuthService.rpcOverride = (fn, {params}) async {
        return {
          'success': false,
          'error_code': 'STORE_NOT_FOUND',
          'message': 'Cửa hàng không tồn tại trong hệ thống',
        };
      };
      final mockJwt = MockPosJwtService(
        mockOnboardingResult: {'success': true, 'token': 'onb-token'},
      );
      final res = await UserAuthService.joinStoreByCode(
        storeCode: 'QN-AB12',
        userId: 'user-123',
        onboardingJwt: 'valid-token',
        jwtService: mockJwt,
      );
      expect(res.isSuccess, false);
      expect(res.errorCode, 'STORE_NOT_FOUND');
    });

    test('13. Register transaction boundary: returns ACCOUNT_CREATED_LOGIN_REQUIRED when RPC succeeds but onboarding fails', () async {
      UserAuthService.rpcOverride = (fn, {params}) async {
        if (fn == 'register_user_account_v4') {
          return {
            'success': true,
            'user_id': 'staff-user-1',
            'phone': '+84901234567',
            'display_name': 'Staff One',
          };
        }
        return {'success': false};
      };

      final mockJwt = MockPosJwtService(
        mockOnboardingResult: {'success': false, 'error': 'UPSTREAM_GATEWAY_TIMEOUT'},
      );

      final res = await UserAuthService.register(
        phone: '0901234567',
        password: 'password123',
        displayName: 'Staff One',
        jwtService: mockJwt,
      );

      expect(res.isSuccess, false);
      expect(res.errorCode, 'ACCOUNT_CREATED_LOGIN_REQUIRED');
      expect(res.errorMessage, contains('Tài khoản đã được tạo thành công!'));
    });

    test('14. Register uses direct error_code from RPC', () async {
      UserAuthService.rpcOverride = (fn, {params}) async {
        return {
          'success': false,
          'error_code': 'PHONE_ALREADY_EXISTS',
          'message': 'Số điện thoại này đã được đăng ký tài khoản.',
        };
      };

      final mockJwt = MockPosJwtService();
      final res = await UserAuthService.register(
        phone: '0901234567',
        password: 'password123',
        displayName: 'Staff One',
        jwtService: mockJwt,
      );

      expect(res.isSuccess, false);
      expect(res.errorCode, 'PHONE_ALREADY_EXISTS');
    });

    testWidgets(
      '15. AuthScreen switches to Login tab and pre-fills phone on ACCOUNT_CREATED_LOGIN_REQUIRED',
      (tester) async {
        UserAuthService.rpcOverride = (fn, {params}) async {
          if (fn == 'register_user_account_v4') {
            return {
              'success': true,
              'user_id': 'staff-user-1',
              'phone': '+84901234567',
              'display_name': 'Staff One',
            };
          }
          return {'success': false};
        };
        UserAuthService.jwtServiceOverride = MockPosJwtService(
          mockOnboardingResult: {'success': false, 'error': 'SERVER_ERROR'},
        );

        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: AuthScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Register tab
        await tester.tap(find.text('Đăng ký'));
        await tester.pumpAndSettle();

        // Fill registration form
        final textFields = find.byType(TextField);
        expect(textFields, findsNWidgets(4));

        await tester.enterText(textFields.at(0), 'Staff One');
        await tester.enterText(textFields.at(1), '0901234567');
        await tester.enterText(textFields.at(2), 'password123');
        await tester.enterText(textFields.at(3), 'password123');
        await tester.pumpAndSettle();

        // Ensure "Tạo tài khoản" button is scrolled into view and tap
        await tester.ensureVisible(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tạo tài khoản'));
        await tester.pumpAndSettle();

        // Should switch back to Login tab (which has 2 TextFields)
        expect(find.byType(TextField), findsNWidgets(2));
        final loginPhoneField = tester.widget<TextField>(find.byType(TextField).first);
        expect(loginPhoneField.controller?.text, '0901234567');

        // SnackBar should be displayed
        expect(
          find.text('Tài khoản đã được tạo thành công! Vui lòng đăng nhập để tiếp tục nhập mã quán.'),
          findsOneWidget,
        );
      },
    );

    test('16. CreateStore applies onboarding JWT, calls create_store_with_owner_v4, and exchanges for owner POS JWT', () async {
      UserAuthService.rpcOverride = (fn, {params}) async {
        if (fn == 'create_store_with_owner_v4') {
          return {
            'success': true,
            'store_id': 'store-new-owner-1',
            'store_code': 'QN-NW01',
            'store_name': 'Quán Nhỏ Tân Phú',
            'role': 'owner',
            'is_owner': true,
          };
        }
        return {'success': false};
      };

      final mockJwt = MockPosJwtService(
        mockOnboardingResult: {'success': true, 'token': 'onb-token-123'},
        mockExchangeResult: {
          'success': true,
          'pos_jwt': 'pos-owner-jwt-456',
          'store_id': 'store-new-owner-1',
          'role': 'owner',
        },
      );

      final res = await UserAuthService.createStore(
        userId: 'user-owner-1',
        storeName: 'Quán Nhỏ Tân Phú',
        onboardingJwt: 'onb-token-123',
        jwtService: mockJwt,
      );

      expect(res.isSuccess, true);
      expect(res.storeId, 'store-new-owner-1');
      expect(res.storeCode, 'QN-NW01');
      expect(res.membership?.role, 'owner');
      expect(res.membership?.isOwner, true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_store_id'), 'store-new-owner-1');
      expect(prefs.getString('auth_store_code'), 'QN-NW01');
      expect(prefs.getString('auth_role'), 'owner');
    });

    test('17. CreateStore fails closed when onboarding token is expired or missing', () async {
      final mockJwt = MockPosJwtService(
        mockOnboardingResult: {'success': false, 'error': 'TOKEN_EXPIRED'},
      );

      final res = await UserAuthService.createStore(
        userId: 'user-owner-1',
        storeName: 'Quán Nhỏ Mới',
        jwtService: mockJwt,
      );

      expect(res.isSuccess, false);
      expect(res.errorCode, 'ONBOARDING_TOKEN_REQUIRED');
      expect(res.errorMessage, contains('Phiên đăng ký đã hết hạn'));
    });

    test('18. CreateStore validates empty store name and propagates INVALID_STORE_NAME', () async {
      final mockJwt = MockPosJwtService(
        mockOnboardingResult: {'success': true, 'token': 'onb-token-123'},
      );

      final res = await UserAuthService.createStore(
        userId: 'user-owner-1',
        storeName: '   ',
        jwtService: mockJwt,
      );

      expect(res.isSuccess, false);
      expect(res.errorCode, 'INVALID_STORE_NAME');
      expect(res.errorMessage, contains('Vui lòng nhập tên quán'));
    });

    test('19. CreateStore handles RPC gateway failure with GATEWAY_UNAVAILABLE', () async {
      UserAuthService.rpcOverride = (fn, {params}) async {
        return 'not-a-map'; // corrupt response
      };

      final mockJwt = MockPosJwtService(
        mockOnboardingResult: {'success': true, 'token': 'onb-token-123'},
      );

      final res = await UserAuthService.createStore(
        userId: 'user-owner-1',
        storeName: 'Quán Nhỏ Test',
        jwtService: mockJwt,
      );

      expect(res.isSuccess, false);
      expect(res.errorCode, 'GATEWAY_UNAVAILABLE');
    });

    test('20. JoinStoreByCode and CreateStore fail-closed when RPC returns empty or null store_id', () async {
      final mockJwt = MockPosJwtService(
        mockOnboardingResult: {'success': true, 'token': 'onb-token-123'},
      );

      UserAuthService.rpcOverride = (fn, {params}) async {
        return {'success': true, 'store_id': null, 'store_code': 'QN-AB12'};
      };

      final joinRes = await UserAuthService.joinStoreByCode(
        userId: 'user-1',
        storeCode: 'QN-AB12',
        jwtService: mockJwt,
      );
      expect(joinRes.isSuccess, false);
      expect(joinRes.errorCode, 'INVALID_STORE_ID');

      final createRes = await UserAuthService.createStore(
        userId: 'user-1',
        storeName: 'Quán Test',
        jwtService: mockJwt,
      );
      expect(createRes.isSuccess, false);
      expect(createRes.errorCode, 'INVALID_STORE_ID');
    });
  });
}

class MockPosJwtService extends PosJwtAuthService {
  final Map<String, dynamic> mockRequestResult;
  final Map<String, dynamic> mockOnboardingResult;
  final Map<String, dynamic> mockExchangeResult;
  final bool mockApplyResult;
  final String? storedToken;

  MockPosJwtService({
    this.mockRequestResult = const {'success': false, 'error': 'AUTH_FAILED'},
    this.mockOnboardingResult = const {'success': false, 'error': 'AUTH_FAILED'},
    this.mockExchangeResult = const {'success': false, 'error': 'AUTH_FAILED'},
    this.mockApplyResult = true,
    this.storedToken,
  }) : super(authApplier: (token) async {});

  @override
  Future<String?> getStoredPosJwt() async => storedToken;

  @override
  bool get isConfigured => true;

  @override
  Future<Map<String, dynamic>> requestPosJwt({
    required String phone,
    required String password,
    required String storeId,
    String endpointPath = '/api/auth/pos-jwt',
    Duration timeoutDuration = const Duration(seconds: 10),
  }) async => mockRequestResult;

  @override
  Future<Map<String, dynamic>> requestOnboardingJwt({
    required String phone,
    required String password,
    String endpointPath = '/api/auth/onboarding-jwt',
    Duration timeoutDuration = const Duration(seconds: 10),
  }) async => mockOnboardingResult;

  @override
  Future<Map<String, dynamic>> exchangeStoreJwt({
    required String onboardingJwt,
    required String storeId,
    String endpointPath = '/api/auth/exchange-store-jwt',
    Duration timeoutDuration = const Duration(seconds: 10),
  }) async => mockExchangeResult;

  @override
  Future<void> storeOnboardingJwt(String token) async {}

  @override
  Future<void> clearOnboardingJwt() async {}

  @override
  String? activeOnboardingJwtFor(String userId) =>
      mockOnboardingResult['success'] == true ? 'mock-onboarding-token' : null;

  @override
  Future<String?> getStoredOnboardingJwtFor(String userId) async =>
      activeOnboardingJwtFor(userId);

  @override
  Future<bool> applyAuthToSupabase(
    String? token, {
    String? expectedStoreId,
    bool allowOnboardingToken = false,
  }) async {
    if (!mockApplyResult) return false;
    if (token != null && token.trim().isEmpty) return false;
    return true;
  }
}

class DisabledPosJwtService extends PosJwtAuthService {
  int applyCount = 0;
  int clearCount = 0;

  @override
  bool get isConfigured => false;

  @override
  Future<void> clearPosJwt() async {
    clearCount++;
  }

  @override
  Future<bool> applyAuthToSupabase(
    String? token, {
    String? expectedStoreId,
    bool allowOnboardingToken = false,
  }) async {
    applyCount++;
    return true;
  }
}
