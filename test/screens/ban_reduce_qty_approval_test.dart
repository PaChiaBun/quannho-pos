import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Giảm số lượng món đã gửi bếp phải qua Quản lý duyệt như huỷ món; nhật ký ghi đúng người duyệt.
void main() {
  final src = File('lib/screens/ban_screen.dart').readAsStringSync();
  final start = src.indexOf('Future<void> _updateItemQty(');
  final body = src.substring(
    start,
    src.indexOf('} // end _updateItemQty', start),
  );
  final reduce = body.substring(body.indexOf('// ─── Giảm qty từng phần'));

  test('Giảm món đã gửi bếp hỏi duyệt Quản lý trước khi ghi', () {
    final approvalAt = reduce.indexOf('_verifyManagerApproval()');
    final writeAt = reduce.indexOf(".from('ban_session_items')");
    expect(approvalAt, greaterThan(0));
    expect(writeAt, greaterThan(approvalAt));
    expect(reduce, contains('if (reduceApproval == null) return;'));
  });

  test('Nhật ký giảm món ghi người duyệt thật, không phải người bấm', () {
    expect(reduce, contains("approvedByUserId: reduceApproval['id']"));
    expect(reduce, isNot(contains('approvedByUserId: session?.userId')));
  });

  test('Huỷ món bếp chưa làm (chỉ đã gửi) không trừ kho hao hụt', () {
    // Công tắc hao hụt chỉ hiện khi đang làm/xong; mặc định phải theo đúng điều kiện đó.
    expect('bool deductAsLoss = showWastageOption;'.allMatches(src).length, 2);
    expect(src.contains('bool deductAsLoss = true;'), isFalse);
  });
}
