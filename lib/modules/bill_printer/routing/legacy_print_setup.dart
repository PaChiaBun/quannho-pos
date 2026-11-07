// lib/modules/bill_printer/routing/legacy_print_setup.dart
// Chuyển cấu hình 4 trạm cũ (cashier/bepNong/bepBar/barLabel) sang PrintSetup mới
// để quán đang chạy KHÔNG phải cấu hình lại: kết quả định tuyến giống hệt cách cũ.

import 'print_setup.dart';

/// Một trạm in cũ (tên/IP, loại 'system'|'network', bật/tắt).
class LegacyStation {
  final String name;
  final String type;
  final bool enabled;
  const LegacyStation({required this.name, required this.type, this.enabled = false});
}

PrinterEntry _toPrinter(String id, String label, LegacyStation s, PaperWidth paper) =>
    PrinterEntry(
      id: id,
      name: label,
      kind: s.type == 'network' ? PrinterKind.lan : PrinterKind.system,
      address: s.name,
      paper: paper,
      enabled: s.enabled,
    );

/// Trạm cũ "có cấu hình" khi đang bật hoặc đã chọn tên/IP máy in.
bool legacyStationConfigured(LegacyStation s) => s.enabled || s.name.trim().isNotEmpty;

/// Quán đã có ít nhất một trạm cũ được cấu hình (mới có gì để dựng sang mô hình mới).
bool legacyHasAnyStation({
  required LegacyStation cashier,
  required LegacyStation bepNong,
  required LegacyStation bepBar,
  required LegacyStation barLabel,
}) => [cashier, bepNong, bepBar, barLabel].any(legacyStationConfigured);

/// Chỉ dựng các trạm đã cấu hình; trạm chưa dùng thì bỏ qua (cùng kết quả: không in).
PrintSetup legacyToPrintSetup({
  required LegacyStation cashier,
  required LegacyStation bepNong,
  required LegacyStation bepBar,
  required LegacyStation barLabel,
  PaperWidth cashierPaper = PaperWidth.mm80,
  PaperWidth kitchenPaper = PaperWidth.mm80,
}) {
  final printers = <PrinterEntry>[];
  final rules = <PrintRule>[];

  void add(
    String printerId,
    String label,
    LegacyStation st,
    PaperWidth paper,
    List<(String, String, PrintJobType)> jobs,
  ) {
    if (!legacyStationConfigured(st)) return;
    printers.add(_toPrinter(printerId, label, st, paper));
    for (final j in jobs) {
      rules.add(PrintRule(
        id: j.$1,
        name: j.$2,
        jobType: j.$3,
        targets: [PrintTarget(printerId: printerId)],
      ));
    }
  }

  add('legacy_cashier', 'Máy in thu ngân', cashier, cashierPaper, const [
    ('legacy_r_receipt', 'Hóa đơn thanh toán', PrintJobType.receipt),
    ('legacy_r_prov', 'Phiếu tạm tính', PrintJobType.provisional),
  ]);
  add('legacy_bepNong', 'Máy in bếp nóng', bepNong, kitchenPaper, const [
    ('legacy_r_hot', 'Phiếu bếp nóng', PrintJobType.kitchenHot),
  ]);
  add('legacy_bepBar', 'Máy in bếp bar', bepBar, kitchenPaper, const [
    ('legacy_r_bar', 'Phiếu bếp bar', PrintJobType.kitchenBar),
  ]);
  add('legacy_barLabel', 'Máy in tem bar', barLabel, kitchenPaper, const [
    ('legacy_r_label', 'Tem bar', PrintJobType.label),
  ]);
  return PrintSetup(printers: printers, rules: rules);
}
