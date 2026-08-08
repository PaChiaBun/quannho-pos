import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const QuanNhoPOSApp());
    expect(find.byType(QuanNhoPOSApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
