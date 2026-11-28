import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: QuanNhoPOSApp()));
    expect(find.byType(QuanNhoPOSApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    // Splash có timeout fail-closed 10 giây cho bước khôi phục auth. Cho fake
    // clock chạy hết timeout để test không dispose cây widget khi timer còn mở.
    await tester.pump(const Duration(seconds: 11));
  });
}
