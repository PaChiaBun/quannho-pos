import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';

BillData bill(String no) => BillData(
      shopName: 'KAY',
      orderNumber: no,
      createdAt: DateTime(2026, 10, 8),
      items: const [],
      subtotal: 0,
      total: 0,
    );

StationPrintersState legacy({PrintSetup? setup, String device = ''}) =>
    StationPrintersState(
      cashier: const PrinterConfig(name: 'IN BILL Ne', type: 'system', enabled: true),
      bepNong: const PrinterConfig(name: 'IN BEP', type: 'system', enabled: true),
      bepBar: const PrinterConfig(name: 'IN BAR', type: 'system', enabled: true),
      barLabel: const PrinterConfig(name: '', type: 'system', enabled: false),
      currentDeviceId: device,
      printSetup: setup ?? const PrintSetup(),
    );

void main() {
  // Mặc định giả lập máy Windows (không có máy in tích hợp Sunmi).
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.windows);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('chưa có thiết lập mới -> giữ nguyên cấu hình 4 trạm cũ', () {
    final s = legacy();
    final out = StationPrinterDispatcher.applyPrintSetup(s, bill('A1'));
    expect(identical(out, s), isTrue);
  });

  test('có thiết lập: bill thu ngân theo luật thiết bị nguồn, bếp/bar theo luật chung', () {
    const setup = PrintSetup(printers: [
      PrinterEntry(id: 'win', name: 'Bill quầy', kind: PrinterKind.system, address: 'IN BILL Ne'),
      PrinterEntry(id: 'lan', name: 'Bếp LAN', kind: PrinterKind.lan, address: '192.168.1.242'),
      PrinterEntry(id: 'v3', name: 'V3', kind: PrinterKind.sunmiBuiltin),
    ], rules: [
      PrintRule(id: 'r1', name: 'bill', jobType: PrintJobType.receipt,
          targets: [PrintTarget(printerId: 'win')]),
      PrintRule(id: 'r2', name: 'bill v3', jobType: PrintJobType.receipt,
          sourceDeviceIds: {'dev-v3'}, targets: [PrintTarget(printerId: 'v3')]),
      PrintRule(id: 'r3', name: 'bếp', jobType: PrintJobType.kitchenHot,
          targets: [PrintTarget(printerId: 'lan')]),
    ]);

    final onWin = StationPrinterDispatcher.applyPrintSetup(
        legacy(setup: setup, device: 'dev-win'), bill('A1'));
    expect(onWin.cashier.name, 'IN BILL Ne');
    expect(onWin.cashier.enabled, isTrue);
    expect(onWin.bepNong.type, 'network');
    expect(onWin.bepNong.name, '192.168.1.242');
    // không có luật cho bar/tem -> tắt (không in nhầm theo trạm cũ)
    expect(onWin.bepBar.enabled, isFalse);
    expect(onWin.barLabel.enabled, isFalse);

    // máy V3: luật Sunmi chưa có driver -> BỎ QUA, chuyển luật kế tiếp: bill vẫn in
    // qua máy in của quán (không mất bill, không in trùng)
    final onV3 = StationPrinterDispatcher.applyPrintSetup(
        legacy(setup: setup, device: 'dev-v3'), bill('A1'));
    expect(onV3.cashier.enabled, isTrue);
    expect(onV3.cashier.name, 'IN BILL Ne');
  });

  test('phiếu tạm tính dùng luật provisional', () {
    const setup = PrintSetup(printers: [
      PrinterEntry(id: 'a', name: 'A', kind: PrinterKind.system, address: 'PRN-A'),
      PrinterEntry(id: 'b', name: 'B', kind: PrinterKind.system, address: 'PRN-B'),
    ], rules: [
      PrintRule(id: 'r1', name: 'bill', jobType: PrintJobType.receipt,
          targets: [PrintTarget(printerId: 'a')]),
      PrintRule(id: 'r2', name: 'tạm tính', jobType: PrintJobType.provisional,
          targets: [PrintTarget(printerId: 'b')]),
    ]);
    expect(StationPrinterDispatcher.applyPrintSetup(legacy(setup: setup), bill('TẠM TÍNH')).cashier.name, 'PRN-B');
    expect(StationPrinterDispatcher.applyPrintSetup(legacy(setup: setup), bill('QN-001')).cashier.name, 'PRN-A');
  });

  group('các nơi đọc cấu hình trạm cũ phải đi qua luật in', () {
    const setup = PrintSetup(printers: [
      PrinterEntry(id: 'a', name: 'A', kind: PrinterKind.system, address: 'PRN-A'),
      PrinterEntry(id: 'off', name: 'Off', kind: PrinterKind.system, address: 'X', enabled: false),
      PrinterEntry(id: 'v3', name: 'V3', kind: PrinterKind.sunmiBuiltin),
    ], rules: [
      PrintRule(id: 'r', name: 'bill', jobType: PrintJobType.receipt,
          targets: [PrintTarget(printerId: 'a')]),
    ]);

    test('effectiveSettings: trạm cũ bị thay hoàn toàn', () {
      final eff = StationPrinterDispatcher.effectiveSettings(legacy(setup: setup));
      expect(eff.cashier.name, 'PRN-A');
      // trạm cũ IN BEP đang bật nhưng không có luật bếp -> tắt
      expect(eff.bepNong.enabled, isFalse);
    });

    test('hasAnyEnabledPrinter theo luật; Sunmi/máy tắt không tính', () {
      expect(legacy().hasAnyEnabledPrinter, isTrue); // cách cũ
      expect(legacy(setup: setup).hasAnyEnabledPrinter, isTrue);
      const onlyOff = PrintSetup(printers: [
        PrinterEntry(id: 'off', name: 'Off', kind: PrinterKind.system, enabled: false),
        PrinterEntry(id: 'v3', name: 'V3', kind: PrinterKind.sunmiBuiltin),
      ], rules: [
        PrintRule(id: 'r1', name: 'r1', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'off')]),
        PrintRule(id: 'r2', name: 'r2', jobType: PrintJobType.kitchenHot,
            targets: [PrintTarget(printerId: 'v3')]),
      ]);
      expect(legacy(setup: onlyOff).hasAnyEnabledPrinter, isFalse);
    });

    test('máy in báo cáo: luật báo cáo, không có thì máy in hóa đơn, cách cũ giữ nguyên', () {
      expect(StationPrinterDispatcher.reportPrinterConfig(legacy()).name, 'IN BILL Ne');
      expect(StationPrinterDispatcher.reportPrinterConfig(legacy(setup: setup)).name, 'PRN-A');
      const withReport = PrintSetup(printers: [
        PrinterEntry(id: 'a', name: 'A', kind: PrinterKind.system, address: 'PRN-A'),
        PrinterEntry(id: 'rep', name: 'Rep', kind: PrinterKind.system, address: 'PRN-REP'),
      ], rules: [
        PrintRule(id: 'r', name: 'bill', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'a')]),
        PrintRule(id: 'rr', name: 'rep', jobType: PrintJobType.report,
            targets: [PrintTarget(printerId: 'rep')]),
      ]);
      expect(StationPrinterDispatcher.reportPrinterConfig(legacy(setup: withReport)).name, 'PRN-REP');
    });
  });

  group('hình thức phục vụ suy từ tên bàn', () {
    BillData at(String? table) => BillData(
          shopName: 'K', orderNumber: 'A1', createdAt: DateTime(2026, 10, 8),
          tableName: table, items: const [], subtotal: 0, total: 0,
        );
    test('serviceTypeOfBill', () {
      expect(StationPrinterDispatcher.serviceTypeOfBill(at(null)), PrintServiceType.takeaway);
      expect(StationPrinterDispatcher.serviceTypeOfBill(at('Mang Về 3')), PrintServiceType.takeaway);
      expect(StationPrinterDispatcher.serviceTypeOfBill(at('A 06')), PrintServiceType.dineIn);
      expect(StationPrinterDispatcher.serviceTypeOfBill(at('Giao hàng 1')), PrintServiceType.delivery);
    });
    test('luật Mang đi khớp bill mang đi, không khớp bill tại bàn', () {
      const setup = PrintSetup(printers: [
        PrinterEntry(id: 'a', name: 'A', kind: PrinterKind.system, address: 'PRN-A'),
        PrinterEntry(id: 'b', name: 'B', kind: PrinterKind.system, address: 'PRN-B'),
      ], rules: [
        PrintRule(id: 'take', name: 't', jobType: PrintJobType.receipt,
            serviceTypes: {PrintServiceType.takeaway}, targets: [PrintTarget(printerId: 'b')]),
        PrintRule(id: 'def', name: 'd', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'a')]),
      ]);
      expect(StationPrinterDispatcher.applyPrintSetup(legacy(setup: setup), at('Mang Về 4')).cashier.name, 'PRN-B');
      expect(StationPrinterDispatcher.applyPrintSetup(legacy(setup: setup), at('B 02')).cashier.name, 'PRN-A');
    });
  });

  test('trên thiết bị Android (Sunmi) luật máy in tích hợp được dùng: loại sunmi', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const setup = PrintSetup(printers: [
      PrinterEntry(id: 'win', name: 'Bill quầy', kind: PrinterKind.system, address: 'IN BILL Ne'),
      PrinterEntry(id: 'v3', name: 'V3 tích hợp', kind: PrinterKind.sunmiBuiltin, ownerDeviceId: 'dev-v3'),
    ], rules: [
      PrintRule(id: 'r1', name: 'bill', jobType: PrintJobType.receipt,
          targets: [PrintTarget(printerId: 'win')]),
      PrintRule(id: 'r2', name: 'bill v3', jobType: PrintJobType.receipt,
          sourceDeviceIds: {'dev-v3'}, targets: [PrintTarget(printerId: 'v3')]),
    ]);
    final onV3 = StationPrinterDispatcher.applyPrintSetup(
        legacy(setup: setup, device: 'dev-v3'), bill('A1'));
    expect(onV3.cashier.type, 'sunmi');
    expect(onV3.cashier.enabled, isTrue);
    // máy in gắn với thiết bị khác: thiết bị này không được dùng dù là Android
    final onOther = StationPrinterDispatcher.applyPrintSetup(
        legacy(setup: setup, device: 'dev-other'), bill('A1'));
    expect(onOther.cashier.type, 'system');
    expect(onOther.cashier.name, 'IN BILL Ne');
  });
}
