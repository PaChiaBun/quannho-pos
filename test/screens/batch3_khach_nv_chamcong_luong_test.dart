import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/staff_service.dart' show ShiftRecord;
import 'package:quannho_pos/screens/chamcong_screen.dart' show shiftHasOvertime;

ShiftRecord shift(int minutes, {bool open = false}) {
  final start = DateTime(2026, 10, 23, 8);
  return ShiftRecord(
    id: 's',
    userId: 'u',
    userName: 'A',
    clockIn: start,
    clockOut: open ? null : start.add(Duration(minutes: minutes)),
    source: 'mobile',
    note: '',
  );
}

void main() {
  group('Chấm công dùng đúng ngưỡng OT như Lương', () {
    test('Ngưỡng 8 giờ: 8h00 chưa OT, 8h01 là OT', () {
      expect(shiftHasOvertime(shift(480), 8), isFalse);
      expect(shiftHasOvertime(shift(481), 8), isTrue);
    });
    test(
      'Ngưỡng 6 giờ: ca 7 giờ là OT (trước đây màn Chấm công bỏ qua vì < 8h)',
      () {
        expect(shiftHasOvertime(shift(420), 6), isTrue);
      },
    );
    test('Ca đang mở không tính OT', () {
      expect(shiftHasOvertime(shift(0, open: true), 1), isFalse);
    });
    test('Khớp công thức của Lương (calculateSingleShiftEarnings)', () {
      final s = File(
        'lib/modules/tinhluong/repository/tinhluong_repository.dart',
      ).readAsStringSync();
      expect(s, contains('final overtimeHours = totalHours > otThreshold'));
      final cc = File('lib/screens/chamcong_screen.dart').readAsStringSync();
      expect(cc, isNot(contains('shift.duration.inHours >= 8')));
    });
  });

  test('Tab Ví có lối nạp cho khách chưa có ví', () {
    final src = File('lib/screens/loyalty_screen.dart').readAsStringSync();
    expect(src, contains("'Nạp ví cho khách'"));
    expect(src, contains('_pickCustomerForTopUp(customers)'));
  });

  test('Công tắc Máy chủ in và Thanh toán hiện đúng module', () {
    final src = File('lib/screens/nhan_vien_screen.dart').readAsStringSync();
    expect(
      src,
      contains(
        "(modulePrefix == 'printer' && allowedModules.contains('bill_printer'))",
      ),
    );
    expect(
      src,
      contains("(key == 'pos.checkout' && allowedModules.contains('ban'))"),
    );
  });

  test('Lương: lọc Chờ xác nhận, nhãn, chốt kỳ đã trả', () {
    final src = File(
      'lib/modules/tinhluong/screens/period_detail_screen.dart',
    ).readAsStringSync();
    expect(src, contains("'Chờ xác nhận'"));
    expect(src, contains("'⏳ Chờ NV xác nhận'"));
    expect(src, contains("updatePeriodStatus(widget.period.id, 'paid')"));
    expect(src, contains("withPay.every((r) => r.paymentStatus == 'paid')"));
  });
}
