// lib/modules/bill_printer/utils/qn_queue_resolver.dart
// Tự dùng các máy in "QN-<Tên quán>-<Vai trò>" do công cụ "Cài máy in" tạo trên máy Windows này:
// chủ quán không phải chọn lại máy in trong POS. Chỉ thay cho trạm đang dùng máy in hệ thống
// (hoặc đang tắt); trạm đã trỏ tới máy in mạng/Sunmi vẫn giữ nguyên.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import '../providers/printer_settings_provider.dart';

class QnQueue {
  final String name;
  final String comment;
  const QnQueue(this.name, this.comment);

  /// Khổ giấy ghi ở ghi chú máy in ("QN;paper=58"); mặc định 80mm.
  double get paperMm => RegExp(r'paper=58').hasMatch(comment) ? 48.0 : 70.0;
}

class QnQueueResolver {
  const QnQueueResolver._();

  static const stationRoles = {
    'cashier': 'ThuNgan',
    'bepNong': 'Bep',
    'bepBar': 'Bar',
    'barLabel': 'Tem',
  };

  static List<QnQueue>? _cache;
  static DateTime? _cacheAt;

  /// Chọn máy in có tên QN-…-VaiTrò (hoặc QN-VaiTrò); nhiều máy thì lấy tên đứng đầu theo thứ tự chữ.
  static QnQueue? pick(List<QnQueue> queues, String roleCode) {
    final m = queues
        .where((q) => q.name == 'QN-$roleCode' || (q.name.startsWith('QN-') && q.name.endsWith('-$roleCode')))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return m.isEmpty ? null : m.first;
  }

  /// Trạm được phép thay bằng máy in QN-… khi đang dùng máy in hệ thống hoặc đang tắt.
  static bool canOverride(PrinterConfig c) => !c.enabled || c.type == 'system';

  static Future<List<QnQueue>> _installed() async {
    final now = DateTime.now();
    if (_cache != null && _cacheAt != null && now.difference(_cacheAt!) < const Duration(seconds: 30)) {
      return _cache!;
    }
    try {
      final all = await Printing.listPrinters();
      _cache = [
        for (final p in all)
          if (p.name.startsWith('QN-')) QnQueue(p.name, p.comment ?? '')
      ];
    } catch (_) {
      _cache = const [];
    }
    _cacheAt = now;
    return _cache!;
  }

  /// Phần thuần để test: trả cấu hình mới cho từng trạm dựa trên danh sách máy in QN đã cài.
  static StationPrintersState applyTo(StationPrintersState s, List<QnQueue> queues) {
    if (queues.isEmpty) return s;
    PrinterConfig swap(PrinterConfig c, String role) {
      final q = pick(queues, role);
      if (q == null || !canOverride(c)) return c;
      return PrinterConfig(
        name: q.name,
        type: 'system',
        enabled: true,
        paperMm: q.paperMm,
        darkness: c.darkness,
        softBold: false,
      );
    }

    return s.copyWith(
      cashier: swap(s.cashier, stationRoles['cashier']!),
      bepNong: swap(s.bepNong, stationRoles['bepNong']!),
      bepBar: swap(s.bepBar, stationRoles['bepBar']!),
      barLabel: swap(s.barLabel, stationRoles['barLabel']!),
    );
  }

  /// Chỉ chạy trên Windows; nơi khác trả nguyên cấu hình.
  static Future<StationPrintersState> apply(StationPrintersState s) async {
    if (kIsWeb || !Platform.isWindows) return s;
    return applyTo(s, await _installed());
  }
}
