// Phiếu bếp A 7 của KAY (06/11/2026) có 5 món nhưng giấy cụt ở món 3: máy in hệ thống Windows
// nhận chiều cao trang vô hạn. Driver thật không chạy được trong flutter test nên chỉ khoá phép tính.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';

void main() {
  const roll = PdfPageFormat(
    80 * PdfPageFormat.mm,
    double.infinity,
    marginAll: 5 * PdfPageFormat.mm,
  );
  PdfPageFormat fit(double h) =>
      StationPrinterDispatcher.rollFormatForPage(roll, h);

  test('phiếu dài: báo đúng chiều cao thật, giữ bề ngang và lề', () {
    final f = fit(900);
    expect(f.height, 900);
    expect(f.width, roll.width);
    expect(f.marginTop, roll.marginTop);
  });

  test('phiếu ngắn hơn bề ngang: không để trang thành khổ ngang', () {
    final f = fit(100);
    expect(f.height, roll.width);
    expect(f.width > f.height, isFalse);
  });

  test('phiếu cực dài: không vượt giới hạn chiều dài giấy của Windows', () {
    final f = fit(100000);
    // Lệnh in Windows tính chiều dài bằng 0,1 mm trong số 16 bit (tối đa 32.767).
    expect((f.height * 254 / 72).round(), lessThanOrEqualTo(32767));
  });

  test('không đo được hoặc khổ đã có chiều cao: giữ nguyên', () {
    expect(fit(0).height, double.infinity);
    expect(
      StationPrinterDispatcher.rollFormatForPage(PdfPageFormat.a4, 900).height,
      PdfPageFormat.a4.height,
    );
  });

  test('máy in hệ thống đi qua bước đo trang trước khi in', () {
    final src = File(
      'lib/modules/bill_printer/screens/bill_preview_screen.dart',
    ).readAsStringSync();
    expect(src, contains('format: await _fitRollToPdf(bytes, finalFormat)'));
  });
}
