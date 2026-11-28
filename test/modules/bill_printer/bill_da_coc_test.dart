// QC 28/11: bàn có cọc (ví khách) — bill in "CÒN PHẢI TRẢ" và mã QR lấy số còn phải trả, không lấy cả tổng.
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';

void main() {
  BillData bill(double tong, double vi) => BillData(
        shopName: 'Q',
        orderNumber: 'TẠM TÍNH',
        createdAt: DateTime(2026, 11, 28),
        items: const [],
        subtotal: tong,
        total: tong,
        daTruVi: vi,
      );

  test('còn phải trả = tổng − phần ví, không âm', () {
    expect(bill(83000, 50000).conPhaiTra, 33000);
    expect(bill(83000, 0).conPhaiTra, 83000);
    expect(bill(30000, 50000).conPhaiTra, 0);
  });
}
