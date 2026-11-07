// Bò Đen 28/10/2026: đóng màn "Thanh toán thành công" bằng nút quay lại làm bản ghi chờ đối soát
// kẹt lại, lần thanh toán sau bị chặn bằng "Thanh toán chưa đối soát".
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/modules/pos/screens/checkout_sheet.dart').readAsStringSync();

  test('vừa nhận kết quả thanh toán là gỡ bản ghi chờ, không đợi bấm "Đơn mới"', () {
    final ack = src.indexOf('posRepo.acknowledgeSale(saleResult)');
    final shown = src.indexOf('_saleResult = saleResult;');
    expect(ack, isNot(-1));
    expect(shown, isNot(-1));
    // Cùng khối `if (mounted)` hiện màn thành công, ngay trước khi gán kết quả.
    expect(shown - ack, inInclusiveRange(0, 800));
    expect(src.substring(ack, shown), contains('setState'));
  });

  test('nút "Đơn mới" vẫn gỡ bản ghi (gọi lại an toàn)', () {
    expect(src, contains('.acknowledgeSale(_saleResult!)'));
  });
}
