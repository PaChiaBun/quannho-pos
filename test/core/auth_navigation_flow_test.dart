import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/providers/session_provider.dart';
import 'package:quannho_pos/core/services/pos_jwt_auth_service.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/screens/auth_screen.dart';
import 'package:quannho_pos/screens/store_picker_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MembershipRepository implements UserAuthRepository {
  _MembershipRepository(this.memberships);

  final List<Map<String, dynamic>> memberships;

  @override
  Future<List<Map<String, dynamic>>> queryStoreMembers(String userId) async =>
      memberships.where((row) => row['user_id'] == userId).toList();

  @override
  Future<List<Map<String, dynamic>>> queryStoresByOwner(String userId) async =>
      const [];

  @override
  Future<Map<String, dynamic>?> queryStoreById(String storeId) async => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalRepository = UserAuthService.authRepository;

  const store = StoreMembership(
    storeId: 'store-1',
    storeName: 'KAY',
    storeCode: 'QN-KAY',
    role: 'owner',
    isOwner: true,
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    UserAuthService.authRepository = originalRepository;
  });

  test('single-store login goes directly to home', () {
    final result = AuthResult.success(
      userId: 'user-1',
      phone: '+84900000000',
      displayName: 'Owner',
      stores: const [store],
      selectedStore: store,
    );

    expect(routeAfterSuccessfulLogin(result), '/home');
  });

  test('multi-store login opens store picker', () {
    const secondStore = StoreMembership(
      storeId: 'store-2',
      storeName: 'KAY 2',
      storeCode: 'QN-KA2',
      role: 'manager',
      isOwner: false,
    );
    final result = AuthResult.success(
      userId: 'user-1',
      phone: '+84900000000',
      displayName: 'Owner',
      stores: const [store, secondStore],
    );

    expect(routeAfterSuccessfulLogin(result), '/store_picker');
  });

  test('full logout does not route to store picker', () {
    const previous = SessionData(
      userId: 'user-1',
      phone: '+84900000000',
      displayName: 'Owner',
      storeId: 'store-1',
      role: 'owner',
      isOwner: true,
    );

    expect(shouldRouteToStorePickerOnSessionChange(previous, null), false);
  });

  test('store revocation still routes authenticated user to picker', () {
    const previous = SessionData(
      userId: 'user-1',
      phone: '+84900000000',
      displayName: 'Owner',
      storeId: 'store-1',
      role: 'owner',
      isOwner: true,
    );
    const revoked = SessionData(
      userId: 'user-1',
      phone: '+84900000000',
      displayName: 'Owner',
      role: '',
      isOwner: false,
    );

    expect(shouldRouteToStorePickerOnSessionChange(previous, revoked), true);
  });

  test(
    'post-login selection revalidates authoritative Supabase membership',
    () async {
      SharedPreferences.setMockInitialValues({
        'auth_user_id': 'user-1',
        'auth_user_phone': '+84900000000',
        'auth_user_name': 'Owner',
      });
      UserAuthService.authRepository = _MembershipRepository([
        {
          'user_id': 'user-1',
          'store_id': 'store-1',
          'role': 'cashier',
          'is_owner': false,
          'stores': {
            'id': 'store-1',
            'name': 'Tên chuẩn Supabase',
            'store_code': 'QN-DB',
          },
        },
      ]);

      final selected = await UserAuthService.selectStoreAfterLogin(
        store,
        jwtService: _DisabledPosJwtService(),
      );

      expect(selected?.storeName, 'Tên chuẩn Supabase');
      expect(selected?.role, 'cashier');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_store_id'), 'store-1');
      expect(prefs.getString('auth_store_name'), 'Tên chuẩn Supabase');
      expect(prefs.getString('auth_role'), 'cashier');
    },
  );

  test('post-login selection fails closed when membership is absent', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user_id': 'user-1',
      'auth_user_phone': '+84900000000',
    });
    UserAuthService.authRepository = _MembershipRepository(const []);

    final selected = await UserAuthService.selectStoreAfterLogin(
      store,
      jwtService: _DisabledPosJwtService(),
    );

    expect(selected, isNull);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_store_id'), isNull);
  });

  test('concurrent post-login selections activate at most one store', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user_id': 'user-1',
      'auth_user_phone': '+84900000000',
    });
    UserAuthService.authRepository = _MembershipRepository([
      {
        'user_id': 'user-1',
        'store_id': 'store-1',
        'role': 'owner',
        'is_owner': true,
        'stores': {'id': 'store-1', 'name': 'KAY', 'store_code': 'QN-KAY'},
      },
    ]);

    final results = await Future.wait([
      UserAuthService.selectStoreAfterLogin(
        store,
        jwtService: _DisabledPosJwtService(),
      ),
      UserAuthService.selectStoreAfterLogin(
        store,
        jwtService: _DisabledPosJwtService(),
      ),
    ]);

    expect(results.whereType<StoreMembership>(), hasLength(1));
  });

  testWidgets('fresh multi-store selection does not ask for password again', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'auth_user_id': 'user-1',
      'auth_user_phone': '+84900000000',
      'auth_user_name': 'Owner',
    });
    UserAuthService.authRepository = _MembershipRepository([
      {
        'user_id': 'user-1',
        'store_id': 'store-1',
        'role': 'owner',
        'is_owner': true,
        'stores': {'id': 'store-1', 'name': 'KAY', 'store_code': 'QN-KAY'},
      },
    ]);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .setSession(
          const SessionData(
            userId: 'user-1',
            phone: '+84900000000',
            displayName: 'Owner',
            role: '',
            isOwner: false,
          ),
        );

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          navigatorKey: navigatorKey,
          home: const SizedBox(),
          routes: {
            '/home': (_) => const Scaffold(body: Text('HOME_SCREEN')),
            '/store_picker': (_) => const StorePickerScreen(),
          },
        ),
      ),
    );

    navigatorKey.currentState!.pushNamed(
      '/store_picker',
      arguments: {
        'stores': const [store],
        storePickerPostLoginKey: true,
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('KAY'));
    await tester.pumpAndSettle();

    expect(find.text('HOME_SCREEN'), findsOneWidget);
    expect(find.textContaining('Xác thực chọn'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}

class _DisabledPosJwtService extends PosJwtAuthService {
  @override
  bool get isConfigured => false;
}
