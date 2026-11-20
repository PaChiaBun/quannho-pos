import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/main.dart';
import 'package:quannho_pos/screens/splash_screen.dart';

// Mở web tại /pos/#/home (F5, khôi phục tab, dấu trang): trước đây Flutter dựng cả Splash lẫn
// MainShell, Trang chủ đọc dữ liệu bằng khoá công khai ~5 giây trước khi có vé đăng nhập.
void main() {
  testWidgets('mở thẳng #/home: bắt đầu từ màn khôi phục vé, chưa dựng Trang chủ', (tester) async {
    final binding = tester.binding;
    binding.platformDispatcher.defaultRouteNameTestValue = '/home';
    addTearDown(binding.platformDispatcher.clearDefaultRouteNameTestValue);

    await tester.pumpWidget(const ProviderScope(child: QuanNhoPOSApp()));
    await tester.pump();

    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(MainShell, skipOffstage: false), findsNothing);

    // Chạy hết bộ hẹn giờ của Splash để không dispose cây widget khi còn timer
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 11));
  });

  group('routeNeedsSessionRestore', () {
    test('màn nội bộ phải qua khôi phục vé', () {
      for (final r in ['/home', '/home/', '/store_picker', '/auth', '/onboarding', '/qr_order']) {
        expect(routeNeedsSessionRestore(r), isTrue, reason: r);
      }
    });

    test('link khách có mã giữ nguyên: khách không có phiên đăng nhập', () {
      expect(routeNeedsSessionRestore('/qr_order?code=ABC_123'), isFalse);
      expect(routeNeedsSessionRestore('/goi-mon?code=ABC'), isFalse);
      expect(routeNeedsSessionRestore('/goi-mon/'), isFalse);
    });

    test('mã sai ở /qr_order là màn nhân viên, vẫn qua khôi phục vé', () {
      expect(routeNeedsSessionRestore('/qr_order?code=a b'), isTrue);
      expect(routeNeedsSessionRestore('/qr_order?code='), isTrue);
    });

    test('khởi động thường và đường lạ không đổi', () {
      expect(routeNeedsSessionRestore('/'), isFalse);
      expect(routeNeedsSessionRestore('/khong-co'), isFalse);
    });
  });
}
