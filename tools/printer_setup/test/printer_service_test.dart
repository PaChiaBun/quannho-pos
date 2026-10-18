import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qn_printer_setup/app_log.dart';
import 'package:qn_printer_setup/printer_service.dart';
import 'package:qn_printer_setup/store_settings.dart';
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

  test('tên máy in kèm tên quán', () {
    expect(PrinterRole.values.map((r) => r.queueName('KAY - Rạch Giá')),
        ['QN-KAY-Rach-Gia-ThuNgan', 'QN-KAY-Rach-Gia-Bep', 'QN-KAY-Rach-Gia-Bar', 'QN-KAY-Rach-Gia-Tem']);
    expect(PrinterRole.thuNgan.queueName(''), 'QN-ThuNgan');
    expect(storeSlug('Quán Nhỏ  Bà Tư!!'), 'Quan-Nho-Ba-Tu');
    expect(storeSlug('x' * 60).length, 24);
  });

  test('InstalledQueue.role nhận vai trò từ hậu tố', () {
    expect(const InstalledQueue('QN-KAY-Rach-Gia-Bar', 'd', 'p').role, PrinterRole.bar);
    expect(const InstalledQueue('QN-ThuNgan', 'd', 'p').role, PrinterRole.thuNgan);
    expect(const InstalledQueue('QN-KAY-Khac', 'd', 'p').role, isNull);
  });

  test('tờ nhận diện: chỉ ASCII, bắt đầu khởi tạo, kết thúc cắt giấy', () {
    final b = PrinterService.identifySlip(PrinterRole.thuNgan, 'QN-KAY-ThuNgan');
    expect(b.take(2), [0x1B, 0x40]);
    expect(b.skip(b.length - 4), [0x1D, 0x56, 0x42, 0x00]);
    expect(b.skip(2).take(b.length - 6).every((c) => c < 128), isTrue);
  });

  test('bỏ dấu tiếng Việt cho tờ in', () {
    expect(PrinterService.asciiForTest('THU NGÂN ĐỒ'), 'THU NGAN DO');
  });

  test('AppLog.format: có mức, giờ, và cắt bớt dòng quá dài', () {
    final a = AppLog.format('INFO', 'xin chào');
    expect(a, matches(RegExp(r'^\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{3}\] \[INFO\] xin chào$')));
    final long = AppLog.format('LỖI', 'x' * 9000);
    expect(long.length, lessThan(4200));
    expect(long, contains('cắt'));
  });
}
