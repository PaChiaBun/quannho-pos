import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quannho_pos/modules/qr_order/models/qr_order_model.dart';
import 'package:quannho_pos/modules/qr_order/screens/tabs/table_shared_poster_tab.dart';
import 'package:quannho_pos/modules/qr_order/widgets/qr_order_review_sheet.dart';
import 'package:quannho_pos/modules/qr_order/widgets/qr_scanner_dialog.dart';

void main() {
  testWidgets('QrScannerDialog switches to manual input and enters token', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: QrScannerDialog())),
      ),
    );

    // Verify title
    expect(find.text('QUÉT QR BÀN GIAO'), findsOneWidget);
    expect(find.text('Tiếp Nhận Đơn Khách Gọi'), findsOneWidget);

    // Switch to manual mode
    await tester.tap(find.text('Nhập Mã Tay'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Nhận Đơn'), findsOneWidget);

    // Enter manual code
    await tester.enterText(find.byType(TextField), 'QRN_A1B2C3D4E5F60718');
    await tester.pump();

    expect(find.text('QRN_A1B2C3D4E5F60718'), findsOneWidget);
  });

  testWidgets('TableSharedPosterTab renders real QrImageView widget', (
    WidgetTester tester,
  ) async {
    final channel = QrChannelModel(
      id: 'ch_1',
      storeId: 'store_1',
      type: 'TABLE_SHARED',
      channelCode: 'TBL_TEST123',
      name: 'QR Bàn Chung',
      isActive: true,
      paymentMode: 'PAY_BEFORE_KITCHEN',
      createdAt: DateTime(2026, 8, 27),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TableSharedPosterTab(
            tableSharedChannel: channel,
            tableSharedUrl:
                'https://quannho.lpm.vn/pos/goi-mon/?code=TBL_TEST123',
            activeBaseUrl: 'https://quannho.lpm.vn/pos',
            storeName: 'Quán Nhỏ Test',
            testOpenDomain: (_) async {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify real QrImageView is present
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('TBL_TEST123'), findsOneWidget);
    expect(find.text('QUÁN NHỎ TEST'), findsOneWidget);
  });

  testWidgets(
    'QrOrderReviewSheet for TABLE_SHARED renders table selector and items',
    (WidgetTester tester) async {
      final mockRequest = QrRequestModel(
        id: 'req_tbl_01',
        storeId: 'store_test',
        channelId: 'ch_test',
        type: 'TABLE_SHARED',
        tableHint: 'Bàn 03',
        trackingToken: 'TRK_001',
        status: 'claimed',
        paymentStatus: 'unpaid',
        totalAmount: 70000,
        version: 1,
        createdAt: DateTime(2026, 8, 27),
        items: [
          const QrRequestItemModel(
            id: 'it_1',
            requestId: 'req_tbl_01',
            productId: 'p_1',
            productName: 'Cà Phê Sữa Đá',
            unitPrice: 35000,
            quantity: 2,
            subtotal: 70000,
            note: 'Nhiều sữa',
            modifiersJson: [
              {'name': 'Trân Châu', 'quantity': 1},
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QrOrderReviewSheet(
                request: mockRequest,
                onApproved: () {},
                onRejected: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify header and items
      expect(find.text('DUYỆT ĐƠN GỌI MÓN TẠI BÀN'), findsOneWidget);
      expect(find.text('Cà Phê Sữa Đá'), findsOneWidget);
      expect(find.text('Ghi chú: Nhiều sữa'), findsOneWidget);
      expect(find.text('+ Trân Châu (x1)'), findsOneWidget);
      expect(find.text('CẦN XÁC NHẬN BÀN'), findsOneWidget);

      // Increase item quantity
      final addBtn = find.byIcon(Icons.add_circle_outline_rounded);
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pump();

      expect(find.text('3'), findsOneWidget); // Qty became 3
      expect(find.text('* Đã chỉnh sửa món'), findsOneWidget);
    },
  );

  testWidgets(
    'QrOrderReviewSheet for COUNTER_TAKEAWAY enforces payment gating',
    (WidgetTester tester) async {
      final unpaidCounterReq = QrRequestModel(
        id: 'req_ctr_01',
        storeId: 'store_test',
        channelId: 'ch_test',
        type: 'COUNTER_TAKEAWAY',
        pickupCode: '#Q02',
        trackingToken: 'TRK_002',
        status: 'claimed',
        paymentStatus: 'unpaid',
        totalAmount: 45000,
        version: 1,
        createdAt: DateTime(2026, 8, 27),
        items: [
          const QrRequestItemModel(
            id: 'it_2',
            requestId: 'req_ctr_01',
            productId: 'p_2',
            productName: 'Trà Chanh Giã Tay',
            unitPrice: 45000,
            quantity: 1,
            subtotal: 45000,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QrOrderReviewSheet(
                request: unpaidCounterReq,
                onApproved: () {},
                onRejected: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify Counter badge & pickup code
      expect(find.text('DUYỆT ĐƠN MANG ĐI TẠI QUẦY'), findsOneWidget);
      expect(find.text('CHƯA THANH TOÁN'), findsOneWidget);
      expect(find.text('XÁC NHẬN ĐÃ THU TIỀN MẶT'), findsOneWidget);
      expect(find.text('CẦN THANH TOÁN TRƯỚC'), findsOneWidget);

      // Verify kitchen send button is disabled when unpaid
      final kitchenBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'CẦN THANH TOÁN TRƯỚC'),
      );
      expect(kitchenBtn.onPressed, isNull);
    },
  );

  testWidgets(
    'QrOrderReviewSheet keeps CASHIER_CONFIRM blocked until payment is confirmed',
    (WidgetTester tester) async {
      final cashierConfirmReq = QrRequestModel(
        id: 'req_ctr_02',
        storeId: 'store_test',
        channelId: 'ch_test',
        type: 'COUNTER_TAKEAWAY',
        pickupCode: '#Q05',
        trackingToken: 'TRK_005',
        status: 'claimed',
        paymentStatus: 'unpaid',
        paymentMode: 'CASHIER_CONFIRM',
        totalAmount: 55000,
        version: 1,
        createdAt: DateTime(2026, 8, 27),
        items: [
          const QrRequestItemModel(
            id: 'it_5',
            requestId: 'req_ctr_02',
            productId: 'p_5',
            productName: 'Bánh Mì Nướng Muối Ớt',
            unitPrice: 55000,
            quantity: 1,
            subtotal: 55000,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: QrOrderReviewSheet(
                request: cashierConfirmReq,
                onApproved: () {},
                onRejected: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // CASHIER_CONFIRM changes who confirms payment, never the pay-before-kitchen gate.
      expect(find.text('CẦN THANH TOÁN TRƯỚC'), findsOneWidget);
      final kitchenBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'CẦN THANH TOÁN TRƯỚC'),
      );
      expect(kitchenBtn.onPressed, isNull);
    },
  );
}
