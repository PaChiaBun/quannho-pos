// QC 04/11/2026 (người kiểm độc lập; Chủ Quán "Sửa hết theo ⭐"): topping đơn QR thật không có "type" (Q2),
// dòng bàn có topping ghi số tổng không gộp / không +/− (Q1, Q3), phiếu bếp máy chủ in ghi đúng số (Q4),
// "In lại" in thẳng (Q5), chi tiết bill bỏ dòng 0 ly (Q8). Phần máy chủ (Q2, Q6) kiểm ở
// supabase/tests/topping_bao_cao_v1_test.sql và topping_ban_tru_kho_v1_test.sql.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';
import 'package:quannho_pos/core/widgets/order_detail_dialog.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';
import 'package:quannho_pos/modules/pos/screens/checkout_sheet.dart';

const _ban = {'type': 'topping', 'id': 'tc', 'name': 'Trân châu', 'price': 5000, 'qty': 1};
const _qr = {'id': 'tc', 'name': 'Trân châu', 'price': 5000, 'quantity': 1}; // dạng QR thật
const _opt = {'id': 'opt', 'name': 'Ít đá', 'price_adjust': 0}; // tuỳ chọn hương vị

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('Q2 — nhận topping QR (không có "type"); tuỳ chọn hương vị không phải topping', () {
    expect(isToppingModifier(_qr), isTrue);
    expect(isToppingModifier(_ban), isTrue);
    expect(isToppingModifier(_opt), isFalse);
    expect(billItemExtras([_qr], lineQty: 1), ['Trân châu']);
    expect(billItemExtras([{..._qr, 'quantity': 2}], lineQty: 1), ['Trân châu x2']); // trước mất "x2"
    expect(toppingSales([_qr, _opt], 2).map((t) => (t.qty, t.revenue)), [(2, 10000)]);
  });

  test('Q1 + Q3 — chỉ dòng bàn ghi số topping tổng mới bị khoá gộp và +/−', () {
    expect(hasLineTotalToppings([_ban]), isTrue);
    expect(hasLineTotalToppings('[{"type":"topping","id":"tc","qty":1}]'), isTrue);
    expect(hasLineTotalToppings([_qr]), isFalse); // QR ghi mỗi phần: +/− và gộp vẫn đúng tiền
    expect(hasLineTotalToppings([_opt]), isFalse);
    expect(hasLineTotalToppings('hỏng'), isFalse);
    expect(hasLineTotalToppings(null), isFalse);
    // Gộp lượt gọi (kho bàn), nút +/− và khoá gộp dòng in bill đều dùng nó
    final repo = File('lib/core/repositories/ban_repository.dart').readAsStringSync();
    expect(repo, contains('!hasLineTotalToppings(modifiersJson)'));
    final ban = File('lib/screens/ban_screen.dart').readAsStringSync();
    expect(ban, contains('if (newQty > 0 && hasLineTotalToppings(item.modifiersJson))'));
    expect(RegExp(r'groupKey\(').allMatches(ban).length, 3); // khai báo + 2 chỗ dùng: khoá tính một nơi
  });

  test('Q4 — dòng topping phiếu bếp in giấy ghi tổng khi không đúng 1 mỗi phần', () {
    expect(kitchenToppingLabel(_ban, 2), '+Trân châu ×1'); // 2 ly + 1 trân châu (trước "+Trân châu")
    expect(kitchenToppingLabel(_ban, 1), '+Trân châu');
    expect(kitchenToppingLabel(_qr, 2), '+Trân châu'); // QR mỗi ly 1
    expect(kitchenToppingLabel({..._qr, 'quantity': 2}, 1), '+Trân châu ×2');
    expect(kitchenToppingLabel(_opt, 1), isNull);
    final printer = File('lib/modules/bill_printer/providers/printer_settings_provider.dart').readAsStringSync();
    expect(printer, contains('kitchenToppingLabel(m, qty)'));
  });

  test('Q8 — chi tiết bill bỏ dòng 0 ly (món QR huỷ lúc thanh toán)', () {
    final lines = mergeBillLines([
      <String, dynamic>{'name': 'Trà', 'quantity': 1, 'unit_price': 40000, 'subtotal': 40000, 'modifiers_json': [_ban]},
      <String, dynamic>{'name': 'Trà', 'quantity': 0, 'unit_price': 40000, 'subtotal': 0, 'modifiers_json': [_ban]},
    ]);
    expect(lines.single.qty, 1); // trước thêm dòng "Trà x0 + Trân châu x1"
  });

  testWidgets('Q5 — "In lại": chưa cài máy in thì chỉ dẫn, bỏ qua thì im lặng', (tester) async {
    late ScaffoldMessengerState messenger;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (c) {
          messenger = ScaffoldMessenger.of(c);
          return const SizedBox();
        }),
      ),
    ));
    Future<PrintDispatchResult> res(StationPrintStatus st) async => PrintDispatchResult({
          'cashier': StationPrintResult(stationCode: 'cashier', status: st),
        });

    warnBillNotPrinted(messenger, () => res(StationPrintStatus.notConfigured));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa được cài máy in'), findsOneWidget);
    expect(find.textContaining('bấm "In lại"'), findsNothing);

    messenger.clearSnackBars();
    await tester.pumpAndSettle();
    warnBillNotPrinted(messenger, () => res(StationPrintStatus.skippedNoItems));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In lại'));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing); // không báo "thất bại" lặp lại

    // Nút "In lại" in thẳng như "In hoá đơn" — không qua đường giành quyền in đã chặn sau lần đầu
    final sheet = File('lib/modules/pos/screens/checkout_sheet.dart').readAsStringSync();
    expect(sheet, contains('() => StationPrinterDispatcher.printBill(bill, settings, onlyReceipt: true)'));
  });
}
