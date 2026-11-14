import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';

PrintSetup setupWithDeviceRule(String deviceId, {bool enabled = true, bool noTarget = false, bool dual = false}) =>
    PrintSetup(
      printers: const [
        PrinterEntry(id: 'v3', name: 'V3', kind: PrinterKind.sunmiBuiltin),
      ],
      rules: [
        PrintRule(
          id: '${kDeviceBillRulePrefix}abcd1234${dual ? kDeviceBillDualMarker : '_'}receipt',
          name: 'V3',
          jobType: PrintJobType.receipt,
          sourceDeviceIds: {deviceId},
          targets: noTarget ? const [] : const [PrintTarget(printerId: 'v3')],
          enabled: enabled,
        ),
      ],
    );

StationPrintersState state(String device, PrintSetup setup) => StationPrintersState(
      cashier: const PrinterConfig(name: '', type: 'system', enabled: false),
      bepNong: const PrinterConfig(name: '', type: 'system', enabled: false),
      bepBar: const PrinterConfig(name: '', type: 'system', enabled: false),
      barLabel: const PrinterConfig(name: '', type: 'system', enabled: false),
      currentDeviceId: device,
      printSetup: setup,
    );

void main() {
  group('deviceOwnsBillPrinting', () {
    test('đúng thiết bị có luật riêng', () {
      expect(state('d1', setupWithDeviceRule('d1')).deviceOwnsBillPrinting, isTrue);
    });
    test('thiết bị khác không bị ảnh hưởng (máy Windows không tự giành bill)', () {
      final s = state('win', setupWithDeviceRule('d1'));
      expect(s.deviceOwnsBillPrinting, isFalse);
      expect(s.anyDeviceBillRule, isTrue);
    });
    test('luật tắt hoặc không có đích -> không tính', () {
      expect(state('d1', setupWithDeviceRule('d1', enabled: false)).deviceOwnsBillPrinting, isFalse);
      expect(state('d1', setupWithDeviceRule('d1', noTarget: true)).deviceOwnsBillPrinting, isFalse);
    });
    test('quán chưa có luật nào (KAY hiện tại) -> hành vi cũ, máy chủ không chờ/giành', () {
      final s = state('win', const PrintSetup());
      expect(s.deviceOwnsBillPrinting, isFalse);
      expect(s.anyDeviceBillRule, isFalse);
    });
  });

  group('chế độ song song (bill ra cả hai máy)', () {
    test('máy có luật song song tự in nhưng KHÔNG giành quyền và máy chủ KHÔNG nhường', () {
      final s = state('d1', setupWithDeviceRule('d1', dual: true));
      expect(s.deviceHasBillRule, isTrue);
      expect(s.deviceOwnsBillPrinting, isFalse);
      expect(s.anyDeviceBillRule, isFalse);
    });
    test('chế độ độc quyền: tự in + giành quyền + máy chủ nhường', () {
      final s = state('d1', setupWithDeviceRule('d1'));
      expect(s.deviceHasBillRule, isTrue);
      expect(s.deviceOwnsBillPrinting, isTrue);
      expect(s.anyDeviceBillRule, isTrue);
    });
    test('máy khác không bị ảnh hưởng', () {
      final s = state('win', setupWithDeviceRule('d1', dual: true));
      expect(s.deviceHasBillRule, isFalse);
    });
  });

  group('shouldAutoPrintReceiptLocally', () {
    bool f({required bool central, required bool owner, required bool fallback, required bool own}) =>
        shouldAutoPrintReceiptLocally(
          isWeb: false,
          centralRoutingEnabled: central,
          hasPrintServerOwner: owner,
          allowPrintServerFallback: fallback,
          deviceOwnsBill: own,
        );
    test('quán dùng máy chủ in: máy thường không in, máy có luật riêng (V3) thì in', () {
      expect(f(central: true, owner: true, fallback: false, own: false), isFalse);
      expect(f(central: true, owner: true, fallback: false, own: true), isTrue);
    });
    test('không dùng máy chủ in: in tại máy như cũ', () {
      expect(f(central: false, owner: false, fallback: false, own: false), isTrue);
    });
    test('web không bao giờ in', () {
      expect(
        shouldAutoPrintReceiptLocally(
          isWeb: true,
          centralRoutingEnabled: true,
          hasPrintServerOwner: true,
          allowPrintServerFallback: false,
          deviceOwnsBill: true,
        ),
        isFalse,
      );
    });
  });
}
