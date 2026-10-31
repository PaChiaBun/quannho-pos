// Quán chưa cài máy in mà máy là Sunmi: bill tự in ra máy in liền thân (1/11/2026).
// Thu tiền mà lệnh in lỗi ngay: báo ngay, không chờ 30 giây; chưa cài máy in thì nói rõ.

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/bill_print_guards.dart';
import 'package:quannho_pos/modules/bill_printer/drivers/sunmi_builtin_driver.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';

const _off = PrinterConfig(name: '', type: 'system');

/// Mặc định của quán mới: trạm thu ngân bật nhưng chưa chọn máy in.
StationPrintersState _state({
  PrinterConfig cashier = const PrinterConfig(name: '', type: 'system', enabled: true),
  PrintSetup printSetup = const PrintSetup(),
}) =>
    StationPrintersState(
      cashier: cashier,
      bepNong: _off,
      bepBar: _off,
      barLabel: _off,
      printSetup: printSetup,
    );

void main() {
  tearDown(() => SunmiBuiltinDriver.hasBuiltinPrinter = false);

  test('Sunmi, quán chưa chọn máy in bill: bill ra máy in liền thân, bếp vẫn không in', () {
    SunmiBuiltinDriver.hasBuiltinPrinter = true;
    final eff = StationPrinterDispatcher.effectiveSettings(_state());
    expect(eff.cashier.type, 'sunmi');
    expect(eff.cashier.enabled, isTrue);
    expect(eff.bepNong.enabled, isFalse);
    expect(StationPrinterDispatcher.reportPrinterConfig(_state()).type, 'sunmi');
  });

  test('không phải Sunmi, tắt trạm thu ngân, đã chọn máy hoặc dùng Luật in: giữ nguyên', () {
    expect(StationPrinterDispatcher.effectiveSettings(_state()).cashier.type, 'system');

    SunmiBuiltinDriver.hasBuiltinPrinter = true;
    expect(StationPrinterDispatcher.usesBuiltinBillFallback(_state(cashier: _off)), isFalse);
    final chose = _state(cashier: const PrinterConfig(name: 'XP-80C', type: 'system', enabled: true));
    expect(StationPrinterDispatcher.effectiveSettings(chose).cashier.name, 'XP-80C');
    final rules = _state(
      printSetup: const PrintSetup(
        printers: [PrinterEntry(id: 'p1', name: 'Bếp', kind: PrinterKind.lan, address: '192.168.1.50')],
      ),
    );
    expect(StationPrinterDispatcher.usesBuiltinBillFallback(rules), isFalse);
  });

  test('in lỗi ngay: báo chưa in tức thì, nhớ lý do "chưa cài máy in"', () {
    final w = BillPrintWatchdog()..start();
    w.markOverdue(notConfigured: true);
    expect(w.status.value, BillPrintStatus.overdue);
    expect(w.notConfigured, isTrue);
    w.restart();
    expect(w.notConfigured, isFalse);
    w.markOverdue();
    expect(w.status.value, BillPrintStatus.overdue);
    w.dispose();
  });
}
