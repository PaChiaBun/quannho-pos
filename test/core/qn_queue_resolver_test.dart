import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/utils/qn_queue_resolver.dart';

void main() {
  const queues = [
    QnQueue('QN-KAY-Rach-Gia-ThuNgan', 'QN;paper=80'),
    QnQueue('QN-KAY-Rach-Gia-Bar', 'QN;paper=58'),
  ];

  StationPrintersState base({PrinterConfig? cashier, PrinterConfig? bepBar, PrinterConfig? bepNong}) =>
      StationPrintersState(
        cashier: cashier ?? const PrinterConfig(name: 'IN BILL Ne', type: 'system', enabled: true),
        bepNong: bepNong ?? const PrinterConfig(name: '', type: 'system', enabled: false),
        bepBar: bepBar ?? const PrinterConfig(name: '', type: 'system', enabled: false),
        barLabel: const PrinterConfig(name: '', type: 'system', enabled: false),
      );

  test('pick: theo hậu tố vai trò', () {
    expect(QnQueueResolver.pick(queues, 'ThuNgan')!.name, 'QN-KAY-Rach-Gia-ThuNgan');
    expect(QnQueueResolver.pick(queues, 'Bep'), isNull);
    expect(QnQueueResolver.pick(const [QnQueue('QN-Tem', '')], 'Tem')!.name, 'QN-Tem');
  });

  test('máy in hệ thống đang dùng và trạm tắt được thay bằng máy QN-…', () {
    final r = QnQueueResolver.applyTo(base(), queues);
    expect(r.cashier.name, 'QN-KAY-Rach-Gia-ThuNgan');
    expect(r.cashier.paperMm, 70.0);
    expect(r.bepBar.name, 'QN-KAY-Rach-Gia-Bar');
    expect(r.bepBar.enabled, isTrue);
    expect(r.bepBar.paperMm, 48.0); // giấy 58mm
    expect(r.bepNong.enabled, isFalse); // không có máy QN-…-Bep => giữ nguyên
  });

  test('trạm đang trỏ máy in mạng hoặc Sunmi thì giữ nguyên', () {
    final r = QnQueueResolver.applyTo(
        base(
          cashier: const PrinterConfig(name: '192.168.1.240', type: 'network', enabled: true),
          bepBar: const PrinterConfig(name: 'x', type: 'sunmi', enabled: true),
        ),
        queues);
    expect(r.cashier.name, '192.168.1.240');
    expect(r.bepBar.type, 'sunmi');
  });

  test('không có máy QN-… thì không đổi gì', () {
    final s = base();
    expect(identical(QnQueueResolver.applyTo(s, const []), s), isTrue);
  });
}
