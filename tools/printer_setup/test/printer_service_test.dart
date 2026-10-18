import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qn_printer_setup/printer_service.dart';
import 'package:qn_printer_setup/ps_runner.dart';

void main() {
  test('encodePowerShell là base64 UTF-16LE', () {
    expect(base64.decode(encodePowerShell('Aé')), [0x41, 0, 0xE9, 0]);
  });

  test('parseJsonList: mảng, đối tượng đơn và rác', () {
    expect(parseJsonList('[{"a":1},{"a":2}]').length, 2);
    expect(parseJsonList('{"a":1}').single['a'], 1);
    expect(parseJsonList('không phải json'), isEmpty);
  });

  test('subnetPrefixes: bỏ loopback/link-local, gộp trùng', () {
    expect(
      subnetPrefixes(['127.0.0.1', '169.254.1.5', '192.168.1.10', '192.168.1.11', '10.0.5.2']),
      ['10.0.5', '192.168.1'],
    );
  });

  test('vendorFromInstanceId đọc VID', () {
    expect(vendorFromInstanceId(r'USB\VID_04B8&PID_0E15\5&1'), 'Epson');
    expect(vendorFromInstanceId(r'USB\VID_FFFF&PID_0001\x'), '');
  });

  test('tên máy in chuẩn', () {
    expect(PrinterRole.values.map((r) => r.queueName),
        ['QN-ThuNgan', 'QN-Bep', 'QN-Bar', 'QN-Tem']);
  });

  test('tờ nhận diện: chỉ ASCII, bắt đầu khởi tạo, kết thúc cắt giấy', () {
    final b = PrinterService.identifySlip(PrinterRole.thuNgan);
    expect(b.take(2), [0x1B, 0x40]);
    expect(b.skip(b.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    expect(b.skip(2).take(b.length - 6).every((c) => c < 128), isTrue);
  });

  test('bỏ dấu tiếng Việt cho tờ in', () {
    expect(PrinterService.asciiForTest('THU NGÂN ĐỒ'), 'THU NGAN DO');
  });
}
