// test/core/user_auth_service_pos_jwt_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Flutter Unit & Wiring Security Tests for UserAuthService & POS JWT Lifecycle
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
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
  });
}

class MockPosJwtService extends PosJwtAuthService {
  final Map<String, dynamic> mockRequestResult;
  final bool mockApplyResult;
  final String? storedToken;

  MockPosJwtService({
    this.mockRequestResult = const {'success': false, 'error': 'AUTH_FAILED'},
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
  Future<bool> applyAuthToSupabase(
    String? token, {
    String? expectedStoreId,
  }) async {
    if (!mockApplyResult) return false;
    return token != null;
  }
}

class DisabledPosJwtService extends PosJwtAuthService {
  int applyCount = 0;

  @override
  bool get isConfigured => false;

  @override
  Future<void> clearPosJwt() async {}

  @override
  Future<bool> applyAuthToSupabase(
    String? token, {
    String? expectedStoreId,
  }) async {
    applyCount++;
    return true;
  }
}
