// Bò Đen 29/10/2026: lướt tay cuộn danh sách qua nút + / thẻ món tự cộng món (nút dùng onTapDown).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nút thêm món ở Bàn và Bán hàng không thêm món lúc vừa chạm xuống', () {
    final addOnTouchDown = RegExp(
      r'onTapDown:[\s\S]{0,80}?(_addItemWithCheck|onTapWithDetails|_addToCart)',
    );
    for (final f in ['lib/screens/ban_screen.dart', 'lib/screens/pos_screen.dart']) {
      expect(addOnTouchDown.hasMatch(File(f).readAsStringSync()), isFalse, reason: f);
    }
  });

  testWidgets('onTapUp: lướt cuộn qua nút không tính, chạm rồi nhấc mới tính', (tester) async {
    var added = 0;
    await tester.pumpWidget(MaterialApp(
      home: ListView(children: [
        for (var i = 0; i < 30; i++)
          GestureDetector(
            onTapUp: (_) => added++,
            child: SizedBox(height: 60, child: Text('Món $i')),
          ),
      ]),
    ));
    await tester.drag(find.text('Món 2'), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(added, 0);

    await tester.tap(find.text('Món 5'));
    expect(added, 1);
  });
}
