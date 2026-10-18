import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:qn_printer_setup/app_log.dart';
import 'package:qn_printer_setup/auto_setup.dart';
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

  group('assignRoles (cài một lần bấm)', () {
    DetectedPrinter usb(String port) => DetectedPrinter(
        kind: DetectedKind.usb, title: 't', detail: 'd', usbPort: port);
    DetectedPrinter lan(String ip) =>
        DetectedPrinter(kind: DetectedKind.lan, title: 't', detail: 'd', ip: ip);

    test('một máy duy nhất = Thu ngân', () {
      final r = assignRoles([lan('192.168.1.240')], const []);
      expect(r.single.role, PrinterRole.thuNgan);
    });

    test('USB trước rồi LAN theo IP: Thu ngân, Bếp, Bar', () {
      final r = assignRoles(
          [lan('192.168.1.242'), usb('USB001'), lan('192.168.1.9')], const []);
      expect(r.map((a) => a.role), [PrinterRole.thuNgan, PrinterRole.bep, PrinterRole.bar]);
      expect(r[0].device.usbPort, 'USB001');
      expect(r[1].device.ip, '192.168.1.9'); // IP nhỏ hơn (so số, không so chuỗi)
    });

    test('chạy lại giữ nguyên vai trò đã có trên cùng cổng', () {
      final existing = [const InstalledQueue('QN-KAY-Bar', 'd', 'IP_192.168.1.9', 'QN;paper=58')];
      final r = assignRoles([usb('USB001'), lan('192.168.1.9')], existing);
      final lanA = r.firstWhere((a) => a.device.ip == '192.168.1.9');
      expect(lanA.role, PrinterRole.bar);
      expect(lanA.paperMm, 58);
      expect(r.firstWhere((a) => a.device.usbPort == 'USB001').role, PrinterRole.thuNgan);
    });

    test('nhiều máy hơn vai trò: bỏ máy dư', () {
      final r = assignRoles([for (var i = 1; i <= 6; i++) lan('10.0.0.$i')], const []);
      expect(r.length, 4);
    });

    test('đổi vai trò sang vai trò đang có máy khác = hoán đổi', () {
      final r = assignRoles([usb('USB001'), lan('192.168.1.5')], const []);
      changeRole(r, r[1], PrinterRole.thuNgan);
      expect(r.firstWhere((a) => a.device.ip == '192.168.1.5').role, PrinterRole.thuNgan);
      expect(r.firstWhere((a) => a.device.usbPort == 'USB001').role, PrinterRole.bep);
    });
  });
}
