// Báo cáo › Hóa đơn và Thu Chi (03/11/2026, đo trên Sunmi Bò Đen): chạm bill chờ 1–2 giây mới hiện, chạm 3 lần
// mở chồng 3 bảng; bill bàn 13 có 4 dòng "Trà Tắc x1", không hiện topping, ghi chú "bàn bàn 13".
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/repositories/bill_history_repository.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';
import 'package:quannho_pos/core/widgets/order_detail_dialog.dart';
import 'package:quannho_pos/modules/bill_printer/services/bill_reprint_service.dart';
import 'package:quannho_pos/modules/pos/repository/pos_repository.dart';

const _topping = '[{"name":"Trân châu","type":"topping","qty":1,"price":5000}]';

final _items = [
  for (var i = 0; i < 3; i++)
    {'name': 'Trà Tắc Cửu Long', 'quantity': 1, 'unit_price': 25000, 'subtotal': 25000},
  {
    'name': 'Trà Tắc Cửu Long',
    'quantity': 1,
    'unit_price': 30000,
    'subtotal': 30000,
    'modifiers_json': _topping,
  },
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(debugResetOrderDetails);

  group('K3 — dòng món dễ đọc', () {
    test('gộp món giống hệt, tách món khác giá / topping', () {
      final lines = mergeBillLines(_items);
      expect(lines.length, 2);
      expect((lines[0].qty, lines[0].subtotal), (3, 75000));
      expect(lines[0].extras, isEmpty);
      expect((lines[1].qty, lines[1].subtotal), (1, 30000));
      expect(lines[1].extras, ['Trân châu']);
    });

    test('đọc topping từ chuỗi JSON hoặc danh sách; dòng không ghi thành tiền thì tính lại', () {
      expect(billItemExtras('[{"name":"Trân châu","type":"topping","qty":2}]'), ['Trân châu x2']);
      expect(billItemExtras([{'name': 'Ít đá', 'type': 'option'}]), ['Ít đá']);
      expect(billItemExtras('không phải JSON'), isEmpty);
      expect(mergeBillLines([{'name': 'Tàu Hũ', 'qty': 2, 'unit_price': 7000}]).single.subtotal, 14000);
    });

    test('ghi chú không lặp chữ "bàn"', () {
      expect(tidyRepeatedTableWord('Món thanh toán tại bàn bàn 13'), 'Món thanh toán tại bàn 13');
      expect(tidyRepeatedTableWord('Món thanh toán tại bàn Bàn 7'), 'Món thanh toán tại Bàn 7');
      expect(tidyRepeatedTableWord('Món thanh toán tại bàn MV 1'), 'Món thanh toán tại bàn MV 1');
    });
  });

  group('In bill có topping (hoá đơn in lại, bill bàn, phiếu bếp, Đơn gần đây)', () {
    test('bill in lại: gộp món giống hệt, giữ topping, bỏ dòng số lượng 0', () {
      final lines = mergeReprintLines([
        ..._items,
        {'name': 'Tàu Hũ', 'qty': 0, 'unit_price': 7000}, // món QR huỷ lúc thanh toán
      ]);
      expect([for (final l in lines) (l.name, l.qty, l.unitPrice)], [
        ('Trà Tắc Cửu Long', 3, 25000.0),
        ('Trà Tắc Cửu Long', 1, 30000.0),
      ]);
      expect(lines[1].extras, ['Trân châu']);

      final bill = buildReprintBill(
        ReprintSource(
          orderNumber: 'QN-20261102-030',
          paidAt: DateTime(2026, 11, 2, 23, 32),
          lines: lines,
          subtotal: 105000,
          total: 105000,
        ),
        shopName: 'Bò Đen',
      );
      expect(bill.items[1].extras, ['Trân châu']); // in dưới tên món: "+ Trân châu"
    });

    test('phiếu bếp in giấy: dòng topping đứng đầu ghi chú', () {
      expect(noteWithExtras('Ít đá', _topping), '+ Trân châu\nÍt đá');
      expect(noteWithExtras(null, _topping), '+ Trân châu');
      expect(noteWithExtras(' ', null), isNull);
    });

    test('Đơn gần đây đọc topping của món', () {
      final item = OrderItemModel.fromMap({
        'id': 'i1',
        'order_id': 'o1',
        'name': 'Trà Tắc Cửu Long',
        'qty': 1,
        'unit_price': 30000,
        'subtotal': 30000,
        'modifiers_json': _topping,
      });
      expect(item.extras, ['Trân châu']);
    });
  });

  testWidgets('K1 + K2 — chạm là mở bảng ngay kèm "Đang tải món…", chạm thêm không mở chồng, không đóng nhầm',
      (tester) async {
    final load = Completer<OrderDetail?>();
    debugSeedOrderDetail('o1', load.future);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: TextButton(
              onPressed: () => showOrderDetailDialog(ctx, 'QN-1', orderId: 'o1',
                  previewTitle: 'Thanh toán bàn 13', previewTotal: 105000),
              child: const Text('Mở bill'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Mở bill'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Đang tải món…'), findsOneWidget); // trước: chưa có gì cho tới khi tải xong
    expect(find.text('Thanh toán bàn 13'), findsOneWidget);

    // Gọi mở lần nữa trong lúc đang mở (trước: mỗi lần chạm thêm một bảng) + chạm đôi rơi ra nền tối.
    unawaited(showOrderDetailDialog(tester.element(find.text('Mở bill')), 'QN-1', orderId: 'o1'));
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AlertDialog), findsOneWidget);

    load.complete(OrderDetail(
      order: {
        'order_number': 'QN-20261102-030',
        'created_at': '2026-11-02T16:32:00Z',
        'subtotal': 105000,
        'total': 105000,
        'payment_method': 'cash',
        'note': 'Món thanh toán tại bàn bàn 13',
      },
      lines: mergeBillLines(_items),
      cashierName: 'Thiên Thanh',
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('x3'), findsOneWidget);
    expect(find.text('+ Trân châu'), findsOneWidget);
    expect(find.text('Ghi chú: Món thanh toán tại bàn 13'), findsOneWidget);

    // Đã ổn định: chạm ra nền tối thì đóng như thường, mở lại được.
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Mở bill'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
