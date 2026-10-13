import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quannho_pos/modules/qr_order/screens/tabs/qr_channel_card.dart';

void main() {
  testWidgets('QrChannelCard renders QR only when active and url valid', (
    WidgetTester tester,
  ) async {
    Widget card({required bool active, String? url}) => MaterialApp(
      home: Scaffold(
        body: QrChannelCard(
          title: 'Tại bàn',
          description: 'mô tả',
          icon: Icons.table_restaurant_rounded,
          channelExists: true,
          isActive: active,
          busy: false,
          url: url,
          unavailableReason: 'lý do',
          onToggle: (_) {},
          onCopy: () {},
          onOpen: () {},
          onPrint: () {},
        ),
      ),
    );

    await tester.pumpWidget(
      card(
        active: true,
        url: 'https://quannho.lpm.vn/pos/goi-mon/?code=TBL_TEST123',
      ),
    );
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.pumpWidget(card(active: false, url: null));
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('lý do'), findsOneWidget);
  });
}
