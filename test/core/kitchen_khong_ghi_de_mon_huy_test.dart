import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// viec-can-sua #4: bếp đồng bộ trạng thái về món tại bàn không được ghi đè món đã huỷ;
// không còn đường huỷ phiếu không qua duyệt.
void main() {
  final src = File(
    'lib/core/repositories/kitchen_repository.dart',
  ).readAsStringSync();

  test(
    'Mọi lần bếp ghi kitchen_status vào ban_session_items đều bỏ qua món đã huỷ',
    () {
      final writes = RegExp(
        r"from\('ban_session_items'\)\s*\.update\(\{'kitchen_status'[^;]*;",
      ).allMatches(src).map((m) => m.group(0)!).toList();
      expect(writes, hasLength(3));
      for (final w in writes) {
        expect(w, contains(".neq('kitchen_status', 'huy')"), reason: w);
      }
    },
  );

  test('Bếp không còn hàm huỷ phiếu không duyệt', () {
    expect(src, isNot(contains('Future<void> cancelTicket(')));
  });
}
