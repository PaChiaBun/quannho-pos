// Kiểm luồng bán quán demo (03/11/2026, máy ảo, bản 24): topping món bàn và đơn QR ghi đúng tổng (L8),
// danh sách topping tải lại mỗi lần mở (L6), thu tiền mặt ở quầy có tiền thối (L5) + nút tiền nhanh
// sáng đúng ô đã chọn (L3), lỗi in bill quầy có nút "In lại" thật (L1), phiếu "Xong" đếm đúng món (L2),
// hai nút Thu tiền ở bàn luôn ở đáy (L4). Trừ kho topping món bàn (L7) kiểm ở
// supabase/tests/topping_ban_tru_kho_v1_test.sql.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/repositories/bill_history_repository.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';
import 'package:quannho_pos/core/widgets/cash_received_panel.dart';
import 'package:quannho_pos/core/widgets/order_detail_dialog.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';
import 'package:quannho_pos/modules/pos/screens/checkout_sheet.dart';
import 'package:quannho_pos/screens/ban_screen.dart' show productToppingLinksProvider;

Map<String, Object> _ban(int qty) => {'type': 'topping', 'name': 'Trân châu', 'qty': qty};
// Dạng QR thật (qr_price_items_v4 dựng lại): không có "type"
Map<String, Object> _qr(int each) => {'id': 'tc', 'name': 'Trân châu', 'price': 5000, 'quantity': each};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('L8 — topping ghi tổng của dòng, đọc cả món bàn (qty) lẫn đơn QR (quantity)', () {
    test('số tổng như máy chủ trừ kho', () {
      expect(toppingTotal(_ban(1), 2), 1); // 2 ly + 1 trân châu cả dòng
      expect(toppingTotal(_qr(1), 2), 2); // QR: mỗi ly 1
      expect(toppingTotal({'name': 'Ít đá'}, 3), 3);
    });

    test('chữ dưới tên món', () {
      expect(billItemExtras([_ban(1)], lineQty: 2), ['Trân châu x1']); // trước như mỗi ly đều có
      expect(billItemExtras([_qr(1)], lineQty: 2), ['Trân châu']); // mỗi ly 1
      expect(billItemExtras([_qr(2)]), ['Trân châu x2']); // trước mất "x2"
      expect(billItemExtras([_ban(3)], lineQty: 1.0), ['Trân châu x3']);
      expect(noteWithExtras('Ít đá', [_ban(1)], lineQty: 2), '+ Trân châu x1\nÍt đá');
    });

    test('dòng có số topping riêng không gộp, dòng mỗi phần 1 vẫn gộp', () {
      final counted = <String, dynamic>{
        'name': 'Trà', 'unit_price': 45000, 'quantity': 1, 'subtotal': 45000,
        'modifiers_json': [_ban(2)],
      };
      final each = <String, dynamic>{
        'name': 'Trà', 'unit_price': 40000, 'quantity': 1, 'subtotal': 40000,
        'modifiers_json': [_ban(1)],
      };
      // Gộp thành "Trà x2 + Trân châu x2" là đọc sai (thật 4 phần).
      expect(mergeBillLines([counted, counted]).length, 2);
      final merged = mergeBillLines([each, each]).single;
      expect(merged.qty, 2);
      expect(merged.extras, ['Trân châu']);
      final reprint = mergeReprintLines(<Map<String, dynamic>>[
        {'product_name': 'Trà', 'quantity': 1, 'unit_price': 45000, 'modifiers_json': [_ban(2)]},
        {'product_name': 'Trà', 'quantity': 1, 'unit_price': 45000, 'modifiers_json': [_ban(2)]},
      ]);
      expect(reprint.length, 2);
    });

    test('Phiếu bếp đọc tổng topping — đơn QR hết "xnull"', () {
      final src = File('lib/screens/kitchen_screen.dart').readAsStringSync();
      expect(src, isNot(contains(r"x${m['qty']}")));
      expect(src, contains('toppingTotal(m, item.quantity)'));
      expect(src, contains('kitchenToppingLabel(m, i.quantity)'));
    });
  });

  test('L6 — topping của món tải lại mỗi lần mở Tùy chọn', () {
    expect(productToppingLinksProvider.isAutoDispose, isTrue);
  });

  testWidgets('L3 + L5 — tiền khách đưa: nút sáng theo số đã chọn, tính tiền thối', (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);
    // Nền màu đè lên Material như bảng thanh toán quầy (máy ảo: nút tiền nhanh mất nền, ô đã chọn biến mất).
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Container(
          color: const Color(0xFFFFF8F0),
          child: CashReceivedPanel(controller: ctrl, total: 125000),
        ),
      ),
    ));
    final inkLayer = tester.widget<Material>(
      find.ancestor(of: find.text('200.000 đ'), matching: find.byType(Material)).first,
    );
    expect(inkLayer.type, MaterialType.transparency); // nền nút vẽ trên lớp riêng, không bị nền che
    Color? bg(String label) => (tester
            .widget<Ink>(find.ancestor(of: find.text(label), matching: find.byType(Ink)))
            .decoration as BoxDecoration)
        .color;

    await tester.tap(find.text('200.000 đ'));
    await tester.pump();
    expect(ctrl.text, '200000');
    expect(find.text('TIỀN THỐI LẠI:'), findsOneWidget);
    expect(find.text('75.000 đ'), findsOneWidget);
    expect(bg('200.000 đ'), const Color(0xFFFF6B35));
    expect(bg('125.000 đ'), Colors.white); // trước vẫn sáng ô "đúng tiền"

    ctrl.text = '100000';
    await tester.pump();
    expect(find.text('Còn thiếu:'), findsOneWidget);
    expect(find.text('25.000 đ'), findsOneWidget);

    // Quầy dùng chung khối này khi chọn Tiền mặt (trước chỉ màn Bàn có).
    final sheet = File('lib/modules/pos/screens/checkout_sheet.dart').readAsStringSync();
    expect(sheet, contains("if (_selectedPayment == 'cash') ...["));
    expect(sheet, contains('CashReceivedPanel('));
  });

  testWidgets('L1 — in bill quầy lỗi: "In lại" in lại thật, lỗi tiếp thì báo lại', (tester) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) {
          messenger = ScaffoldMessenger.of(c);
          return const SizedBox();
        }),
      ),
    ));
    final statuses = [StationPrintStatus.failed, StationPrintStatus.success];
    var calls = 0;
    Future<PrintDispatchResult> reprint() async => PrintDispatchResult({
          'cashier': StationPrintResult(stationCode: 'cashier', status: statuses[calls++]),
        });

    warnBillNotPrinted(messenger, reprint);
    await tester.pumpAndSettle();
    expect(find.textContaining('bấm "In lại"'), findsOneWidget); // trước bảo bấm "In hoá đơn" không có

    await tester.tap(find.text('In lại'));
    await tester.pumpAndSettle();
    expect(calls, 1);
    expect(find.textContaining('bấm "In lại"'), findsOneWidget); // vẫn lỗi → báo lại

    await tester.tap(find.text('In lại'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Đã in lại bill.'), findsOneWidget);
  });

  test('L2 — phiếu "Xong" đếm số món của phiếu, không ghi "0 món"', () {
    final src = File('lib/screens/kitchen_screen.dart').readAsStringSync();
    expect(src, contains('final itemCount = waiting > 0 ? waiting : items.where((i) => !i.cancelled).length;'));
    expect(src, contains(r"'$itemCount món'"));
  });

  test('L4 — hai nút Thu tiền ở bàn nằm ngoài vùng cuộn', () {
    final src = File('lib/screens/ban_screen.dart').readAsStringSync();
    final i = src.indexOf('Chỉ phần giữa cuộn, hai nút Hủy bỏ / Xác nhận luôn ở đáy');
    expect(i, greaterThan(0));
    final body = src.substring(i, src.indexOf('void _selectVoucher()', i));
    expect(body, contains('Flexible(\n                child: SingleChildScrollView('));
    expect(RegExp(r'_buildActionButtons\(zoneColor\)').allMatches(body).length, 1);
    expect(body.indexOf('_buildActionButtons(zoneColor)'), greaterThan(body.lastIndexOf('const SizedBox(height: 16),')));
  });

  test('Kho › Cấu hình Topping ghi giá có dấu chấm ("+5.000 đ")', () {
    final src = File('lib/screens/inventory_screen.dart').readAsStringSync();
    expect(src, contains(r"'+${fmtVnd(price)} / $unit'"));
  });
}
