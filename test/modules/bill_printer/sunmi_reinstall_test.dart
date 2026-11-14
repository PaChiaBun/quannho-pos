// Cài lại app trên Sunmi -> mã máy đổi; bill vẫn phải tự in ra máy in tích hợp (28/10/2026, Bò Đen).
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/drivers/sunmi_builtin_driver.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';

import 'receipt_claim_test.dart' show setupWithDeviceRule, state;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('sunmi_printer_plus');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    SunmiBuiltinDriver.hasBuiltinPrinter = false;
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('luật "máy này in bill" sau khi cài lại app', () {
    test('Sunmi mang mã mới vẫn nhận luật in ra máy in tích hợp', () {
      SunmiBuiltinDriver.hasBuiltinPrinter = true;
      final s = state('ma-moi', setupWithDeviceRule('ma-cu'));
      expect(s.deviceHasBillRule, isTrue);
      expect(s.deviceOwnsBillPrinting, isTrue);
    });

    test('máy không có máy in tích hợp (điện thoại, Windows) không nhận luật của Sunmi', () {
      final s = state('dien-thoai', setupWithDeviceRule('ma-cu'));
      expect(s.deviceHasBillRule, isFalse);
      expect(s.deviceOwnsBillPrinting, isFalse);
    });

    test('luật gắn mã máy nhưng in ra máy LAN vẫn chỉ áp cho đúng máy đó', () {
      SunmiBuiltinDriver.hasBuiltinPrinter = true;
      final setup = PrintSetup(
        printers: const [
          PrinterEntry(id: 'lan', name: 'LAN', kind: PrinterKind.lan, address: '192.168.1.50'),
        ],
        rules: [
          PrintRule(
            id: '${kDeviceBillRulePrefix}abcd1234_receipt',
            name: 'LAN',
            jobType: PrintJobType.receipt,
            sourceDeviceIds: const {'ma-cu'},
            targets: const [PrintTarget(printerId: 'lan')],
          ),
        ],
      );
      expect(state('ma-moi', setup).deviceHasBillRule, isFalse);
      expect(state('ma-cu', setup).deviceHasBillRule, isTrue);
    });
  });

  group('dò máy in tích hợp lúc mở app', () {
    test('dịch vụ in kết nối chậm: dò lại tới khi thấy máy in', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method != 'getStatus') return null;
        calls++;
        if (calls < 3) throw PlatformException(code: 'NOT_READY'); // chưa kết nối xong
        return 'READY';
      });
      await SunmiBuiltinDriver.detect(gap: Duration.zero);
      expect(SunmiBuiltinDriver.hasBuiltinPrinter, isTrue);
      expect(calls, 3);
    });

    test('máy không phải Sunmi: dừng sau số lần thử, không treo, không báo có máy in', () async {
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        throw PlatformException(code: 'NO_SERVICE');
      });
      await SunmiBuiltinDriver.detect(tries: 4, gap: Duration.zero);
      expect(SunmiBuiltinDriver.hasBuiltinPrinter, isFalse);
      expect(calls, 4);
    });
  });
}
