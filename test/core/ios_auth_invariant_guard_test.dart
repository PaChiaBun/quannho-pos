// test/core/ios_auth_invariant_guard_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Tier 3: Invariant Guardrail & Security Verification Test
// Verifies Apple Review Guideline 3.1.1 (Business Management / Zero Registration)
// Strict invariant: On iOS (defaultTargetPlatform == TargetPlatform.iOS),
// no registration forms, tabs, or buttons are rendered in AuthScreen or StorePickerScreen.
// Non-iOS platforms (Android, Windows) must continue to permit registration.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/screens/auth_screen.dart';
import 'package:quannho_pos/screens/store_picker_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Apple Guideline 3.1.1 Invariant Guardrail - AuthScreen', () {
    testWidgets(
      'iOS AuthScreen renders single login mode with Guideline 3.1.1 notice and ZERO register tab',
      (tester) async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(
                home: AuthScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Invariant: Notice text for staff/manager login must be visible on iOS
          expect(
            find.text('Đăng nhập tài khoản nhân viên / quản lý đã được cấp bởi cửa hàng của bạn.'),
            findsOneWidget,
            reason: 'iOS must display the B2B staff notice clarifying external account provisioning',
          );

          // 2. Invariant: "Đăng ký" tab must NOT be rendered on iOS
          expect(
            find.text('Đăng ký'),
            findsNothing,
            reason: 'Apple Guideline 3.1.1 violation: "Đăng ký" tab found on iOS platform',
          );

          // 3. Invariant: Register form fields must NOT exist
          expect(find.text('Tên của bạn'), findsNothing);
          expect(find.text('Xác nhận mật khẩu'), findsNothing);
          expect(find.text('Tạo tài khoản'), findsNothing);

          // 4. Invariant: Login form fields must be present and functional
          expect(find.text('Số điện thoại'), findsOneWidget);
          expect(find.text('Mật khẩu'), findsOneWidget);
          expect(find.text('Đăng nhập'), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'Android AuthScreen permits both login and register tabs and displays register form',
      (tester) async {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(
                home: AuthScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // 1. Android must NOT show the iOS-only restricted notice
          expect(
            find.text('Đăng nhập tài khoản nhân viên / quản lý đã được cấp bởi cửa hàng của bạn.'),
            findsNothing,
          );

          // 2. Android must show both tabs: "Đăng nhập" and "Đăng ký"
          expect(find.text('Đăng nhập'), findsWidgets);
          expect(find.text('Đăng ký'), findsOneWidget);

          // 3. Initially on Login tab: register fields not visible
          expect(find.text('Tên của bạn'), findsNothing);

          // 4. Switch to Register tab
          await tester.tap(find.text('Đăng ký'));
          await tester.pumpAndSettle();

          // 5. Register fields must now be visible on Android
          expect(find.text('Tên của bạn'), findsOneWidget);
          expect(find.text('Xác nhận mật khẩu'), findsOneWidget);
          expect(find.text('Tạo tài khoản'), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'Windows AuthScreen permits registration tabs similar to Android',
      (tester) async {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        try {
          await tester.pumpWidget(
            const ProviderScope(
              child: MaterialApp(
                home: AuthScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Đăng ký'), findsOneWidget);
          expect(
            find.text('Đăng nhập tài khoản nhân viên / quản lý đã được cấp bởi cửa hàng của bạn.'),
            findsNothing,
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });

  group('Apple Guideline 3.1.1 Invariant Guardrail - StorePickerScreen', () {
    testWidgets(
      'iOS StorePickerScreen renders ONLY "Kết nối quán" and strictly omits "Tạo quán mới"',
      (tester) async {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          await tester.pumpWidget(
            MaterialApp(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  settings: const RouteSettings(
                    name: '/store_picker',
                    arguments: {'stores': <StoreMembership>[]},
                  ),
                  builder: (_) => const ProviderScope(
                    child: StorePickerScreen(),
                  ),
                );
              },
            ),
          );
          await tester.pumpAndSettle();

          // 1. "Kết nối quán" button must be present on iOS
          expect(find.text('Kết nối quán'), findsOneWidget);

          // 2. Invariant: "Tạo quán mới" must strictly NOT be present on iOS
          expect(
            find.text('Tạo quán mới'),
            findsNothing,
            reason: 'Apple Guideline 3.1.1 violation: "Tạo quán mới" action exposed on iOS',
          );
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'Android StorePickerScreen renders BOTH "Kết nối quán" and "Tạo quán mới"',
      (tester) async {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        try {
          await tester.pumpWidget(
            MaterialApp(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  settings: const RouteSettings(
                    name: '/store_picker',
                    arguments: {'stores': <StoreMembership>[]},
                  ),
                  builder: (_) => const ProviderScope(
                    child: StorePickerScreen(),
                  ),
                );
              },
            ),
          );
          await tester.pumpAndSettle();

          // Android permits both actions
          expect(find.text('Kết nối quán'), findsOneWidget);
          expect(find.text('Tạo quán mới'), findsOneWidget);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );

    testWidgets(
      'iOS StorePickerScreen with existing stores still prohibits "Tạo quán mới"',
      (tester) async {
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        try {
          const dummyStore = StoreMembership(
            storeId: 'store-test-123',
            storeName: 'Quán Nhỏ Demo',
            storeCode: 'QN-DEMO',
            role: 'cashier',
            isOwner: false,
          );

          await tester.pumpWidget(
            MaterialApp(
              onGenerateRoute: (settings) {
                return MaterialPageRoute(
                  settings: const RouteSettings(
                    name: '/store_picker',
                    arguments: {
                      'stores': [dummyStore],
                    },
                  ),
                  builder: (_) => const ProviderScope(
                    child: StorePickerScreen(),
                  ),
                );
              },
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Quán Nhỏ Demo'), findsOneWidget);
          expect(find.text('Kết nối quán'), findsOneWidget);
          expect(find.text('Tạo quán mới'), findsNothing);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      },
    );
  });
}
