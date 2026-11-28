import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/thermal_printer_service.dart';

void main() {
  test('encodePowerShell: base64 của UTF-16LE (PowerShell -EncodedCommand)', () {
    final b = base64.decode(ThermalPrinterService.encodePowerShell('Aé1'));
    expect(b, [0x41, 0x00, 0xE9, 0x00, 0x31, 0x00]);
  });

  test('openCashDrawerWindows: không phải Windows thì trả false, không ném lỗi', () async {
    expect(await ThermalPrinterService.openCashDrawerWindows(printerName: 'x'), isFalse);
  });
}
