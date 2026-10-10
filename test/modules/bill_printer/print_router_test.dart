import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/routing/legacy_print_setup.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_router.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';

PrinterEntry p(String id, {bool enabled = true, PrinterKind kind = PrinterKind.system}) =>
    PrinterEntry(id: id, name: id, kind: kind, enabled: enabled);

void main() {
  group('PrintRouter', () {
    test('không có luật khớp -> rỗng', () {
      final s = PrintSetup(printers: [p('a')], rules: const []);
      expect(PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext()), isEmpty);
    });

    test('luật khớp loại phiếu, trả đúng máy in và số bản', () {
      final s = PrintSetup(printers: [p('a')], rules: [
        const PrintRule(id: 'r', name: 'r', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'a', copies: 2)]),
      ]);
      final r = PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext());
      expect(r.single.printer.id, 'a');
      expect(r.single.copies, 2);
      expect(PrintRouter.resolve(s, PrintJobType.kitchenHot, const PrintContext()), isEmpty);
    });

    test('luật theo thiết bị nguồn thắng luật chung cùng priority (V3 in tại máy)', () {
      final s = PrintSetup(printers: [p('win'), p('v3', kind: PrinterKind.sunmiBuiltin)], rules: [
        const PrintRule(id: 'all', name: 'all', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'win')]),
        const PrintRule(id: 'v3', name: 'v3', jobType: PrintJobType.receipt,
            sourceDeviceIds: {'dev-v3'}, targets: [PrintTarget(printerId: 'v3')]),
      ]);
      expect(PrintRouter.resolve(s, PrintJobType.receipt,
          const PrintContext(sourceDeviceId: 'dev-v3')).single.printer.id, 'v3');
      expect(PrintRouter.resolve(s, PrintJobType.receipt,
          const PrintContext(sourceDeviceId: 'dev-win')).single.printer.id, 'win');
      expect(PrintRouter.resolve(s, PrintJobType.receipt,
          const PrintContext()).single.printer.id, 'win');
    });

    test('điều kiện hình thức phục vụ', () {
      final s = PrintSetup(printers: [p('a'), p('b')], rules: [
        const PrintRule(id: 'take', name: 'take', jobType: PrintJobType.kitchenHot,
            serviceTypes: {PrintServiceType.takeaway}, targets: [PrintTarget(printerId: 'b')]),
        const PrintRule(id: 'def', name: 'def', jobType: PrintJobType.kitchenHot,
            targets: [PrintTarget(printerId: 'a')]),
      ]);
      expect(PrintRouter.resolve(s, PrintJobType.kitchenHot,
          const PrintContext(serviceType: PrintServiceType.takeaway)).single.printer.id, 'b');
      expect(PrintRouter.resolve(s, PrintJobType.kitchenHot,
          const PrintContext(serviceType: PrintServiceType.dineIn)).single.printer.id, 'a');
    });

    test('priority nhỏ thắng', () {
      final s = PrintSetup(printers: [p('a'), p('b')], rules: [
        const PrintRule(id: '1', name: '1', jobType: PrintJobType.receipt, priority: 50,
            targets: [PrintTarget(printerId: 'a')]),
        const PrintRule(id: '2', name: '2', jobType: PrintJobType.receipt, priority: 10,
            targets: [PrintTarget(printerId: 'b')]),
      ]);
      expect(PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext()).single.printer.id, 'b');
    });

    test('máy in tắt -> dùng máy dự phòng', () {
      final s = PrintSetup(printers: [p('a', enabled: false), p('fb')], rules: [
        const PrintRule(id: 'r', name: 'r', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'a')], fallbackPrinterId: 'fb'),
      ]);
      final r = PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext());
      expect(r.single.printer.id, 'fb');
      expect(r.single.usedFallback, isTrue);
    });

    test('luật trỏ máy in loại chưa hỗ trợ -> bỏ qua, dùng luật kế tiếp', () {
      final s = PrintSetup(printers: [p('win'), p('v3', kind: PrinterKind.sunmiBuiltin)], rules: [
        const PrintRule(id: 'v3', name: 'v3', jobType: PrintJobType.receipt,
            sourceDeviceIds: {'d'}, targets: [PrintTarget(printerId: 'v3')]),
        const PrintRule(id: 'all', name: 'all', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'win')]),
      ]);
      const ctx = PrintContext(sourceDeviceId: 'd');
      // hỗ trợ Sunmi -> luật V3 thắng
      expect(PrintRouter.resolve(s, PrintJobType.receipt, ctx,
          supportedKinds: PrinterKind.values.toSet()).single.printer.id, 'v3');
      // chưa hỗ trợ -> rơi sang luật chung
      expect(PrintRouter.resolve(s, PrintJobType.receipt, ctx,
          supportedKinds: {PrinterKind.system, PrinterKind.lan}).single.printer.id, 'win');
    });

    test('luật chỉ có máy in chưa hỗ trợ và không còn luật nào khác -> không in', () {
      final s = PrintSetup(printers: [p('v3', kind: PrinterKind.sunmiBuiltin)], rules: [
        const PrintRule(id: 'v3', name: 'v3', jobType: PrintJobType.receipt,
            targets: [PrintTarget(printerId: 'v3')]),
      ]);
      expect(PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext(),
          supportedKinds: {PrinterKind.system}), isEmpty);
    });

    test('máy in bị TẮT khác máy in chưa hỗ trợ: luật vẫn thắng, không rơi sang luật khác', () {
      final s = PrintSetup(printers: [p('off', enabled: false), p('win')], rules: [
        const PrintRule(id: 'a', name: 'a', jobType: PrintJobType.receipt, priority: 1,
            targets: [PrintTarget(printerId: 'off')]),
        const PrintRule(id: 'b', name: 'b', jobType: PrintJobType.receipt, priority: 2,
            targets: [PrintTarget(printerId: 'win')]),
      ]);
      expect(PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext(),
          supportedKinds: {PrinterKind.system}), isEmpty);
    });

    test('máy in gắn thiết bị khác (ownerDeviceId) không dùng được trên thiết bị này', () {
      final s = PrintSetup(printers: [
        const PrinterEntry(id: 'v3', name: 'v3', kind: PrinterKind.sunmiBuiltin, ownerDeviceId: 'dev-v3'),
        p('win'),
      ], rules: [
        const PrintRule(id: 'a', name: 'a', jobType: PrintJobType.receipt, priority: 1,
            targets: [PrintTarget(printerId: 'v3')]),
        const PrintRule(id: 'b', name: 'b', jobType: PrintJobType.receipt, priority: 2,
            targets: [PrintTarget(printerId: 'win')]),
      ]);
      final all = PrinterKind.values.toSet();
      expect(PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext(sourceDeviceId: 'dev-v3'),
          supportedKinds: all).single.printer.id, 'v3');
      expect(PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext(sourceDeviceId: 'dev-win'),
          supportedKinds: all).single.printer.id, 'win');
    });

    test('luật tắt bị bỏ qua; một máy in nhận nhiều luật (nhiều trạm)', () {
      final s = PrintSetup(printers: [p('a')], rules: [
        const PrintRule(id: 'off', name: 'off', jobType: PrintJobType.kitchenHot, enabled: false,
            targets: [PrintTarget(printerId: 'a')]),
        const PrintRule(id: 'hot', name: 'hot', jobType: PrintJobType.kitchenHot,
            targets: [PrintTarget(printerId: 'a')]),
        const PrintRule(id: 'bar', name: 'bar', jobType: PrintJobType.kitchenBar,
            targets: [PrintTarget(printerId: 'a')]),
      ]);
      expect(PrintRouter.resolve(s, PrintJobType.kitchenHot, const PrintContext()).single.ruleId, 'hot');
      expect(PrintRouter.resolve(s, PrintJobType.kitchenBar, const PrintContext()).single.ruleId, 'bar');
    });
  });

  group('PrintSetup JSON', () {
    test('khứ hồi giữ nguyên dữ liệu và chặn số bản ngoài 1..9', () {
      final s = PrintSetup(printers: [
        const PrinterEntry(id: 'a', name: 'A', kind: PrinterKind.lan, address: '192.168.1.5',
            port: 9100, paper: PaperWidth.mm50, hasCashDrawer: true),
      ], rules: [
        const PrintRule(id: 'r', name: 'r', jobType: PrintJobType.receipt,
            serviceTypes: {PrintServiceType.qr}, zoneIds: {'z1'}, sourceDeviceIds: {'d'},
            targets: [PrintTarget(printerId: 'a', copies: 2, templateKey: 't')],
            fallbackPrinterId: 'a', priority: 7),
      ]);
      final back = PrintSetup.fromJson(s.toJson());
      expect(back.printers.single.paper, PaperWidth.mm50);
      expect(back.printers.single.address, '192.168.1.5');
      expect(back.rules.single.serviceTypes, {PrintServiceType.qr});
      expect(back.rules.single.targets.single.templateKey, 't');
      expect(back.rules.single.priority, 7);
      final clamped = PrintTarget.fromJson({'printerId': 'a', 'copies': 99});
      expect(clamped.copies, 9);
      expect(PrintSetup.fromJson({'printers': 'bad'}).isEmpty, isTrue);
    });
  });

  group('legacyToPrintSetup (quán đang chạy không phải đổi gì)', () {
    final setup = legacyToPrintSetup(
      cashier: const LegacyStation(name: 'IN BILL Ne', type: 'system', enabled: true),
      bepNong: const LegacyStation(name: 'IN BEP', type: 'system', enabled: true),
      bepBar: const LegacyStation(name: 'IN BAR', type: 'system', enabled: true),
      barLabel: const LegacyStation(name: '', type: 'system', enabled: false),
    );
    test('mỗi loại phiếu ra đúng máy in cũ', () {
      String addr(PrintJobType j) =>
          PrintRouter.resolve(setup, j, const PrintContext()).single.printer.address;
      expect(addr(PrintJobType.receipt), 'IN BILL Ne');
      expect(addr(PrintJobType.provisional), 'IN BILL Ne');
      expect(addr(PrintJobType.kitchenHot), 'IN BEP');
      expect(addr(PrintJobType.kitchenBar), 'IN BAR');
    });
    test('chỉ dựng trạm đã cấu hình; quán chưa cấu hình gì -> rỗng', () {
      expect(setup.printers.map((e) => e.id), ['legacy_cashier', 'legacy_bepNong', 'legacy_bepBar']);
      const none = LegacyStation(name: '', type: 'system');
      expect(legacyHasAnyStation(cashier: none, bepNong: none, bepBar: none, barLabel: none), isFalse);
      expect(legacyToPrintSetup(cashier: none, bepNong: none, bepBar: none, barLabel: none).isEmpty, isTrue);
      expect(legacyHasAnyStation(
        cashier: const LegacyStation(name: '', type: 'system', enabled: true),
        bepNong: none, bepBar: none, barLabel: none), isTrue);
    });
    test('tem bar đang tắt -> không in', () {
      expect(PrintRouter.resolve(setup, PrintJobType.label, const PrintContext()), isEmpty);
    });
    test('loại network trở thành lan', () {
      final s = legacyToPrintSetup(
        cashier: const LegacyStation(name: '192.168.1.240', type: 'network', enabled: true),
        bepNong: const LegacyStation(name: '', type: 'system'),
        bepBar: const LegacyStation(name: '', type: 'system'),
        barLabel: const LegacyStation(name: '', type: 'system'),
      );
      expect(PrintRouter.resolve(s, PrintJobType.receipt, const PrintContext()).single.printer.kind,
          PrinterKind.lan);
    });
  });
}
