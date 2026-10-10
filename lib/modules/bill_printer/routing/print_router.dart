// lib/modules/bill_printer/routing/print_router.dart
// Bộ định tuyến thuần: (PrintSetup, loại phiếu, ngữ cảnh) -> danh sách máy in cần in.

import 'print_setup.dart';

/// Ngữ cảnh của một lệnh in.
class PrintContext {
  final PrintServiceType? serviceType;
  final String? zoneId;
  final String? sourceDeviceId;

  const PrintContext({this.serviceType, this.zoneId, this.sourceDeviceId});
}

/// Một đích in đã được giải quyết.
class ResolvedPrint {
  final PrinterEntry printer;
  final int copies;
  final String? templateKey;
  final String ruleId;
  final bool usedFallback;

  const ResolvedPrint({
    required this.printer,
    required this.copies,
    required this.templateKey,
    required this.ruleId,
    this.usedFallback = false,
  });
}

class PrintRouter {
  const PrintRouter._();

  static bool _matches(PrintRule r, PrintJobType job, PrintContext ctx) {
    if (!r.enabled || r.jobType != job) return false;
    if (r.serviceTypes.isNotEmpty &&
        (ctx.serviceType == null || !r.serviceTypes.contains(ctx.serviceType))) {
      return false;
    }
    if (r.zoneIds.isNotEmpty &&
        (ctx.zoneId == null || !r.zoneIds.contains(ctx.zoneId))) {
      return false;
    }
    if (r.sourceDeviceIds.isNotEmpty &&
        (ctx.sourceDeviceId == null ||
            !r.sourceDeviceIds.contains(ctx.sourceDeviceId))) {
      return false;
    }
    return true;
  }

  /// Số điều kiện đang đặt: luật cụ thể hơn thắng khi cùng priority.
  static int _specificity(PrintRule r) =>
      (r.serviceTypes.isNotEmpty ? 1 : 0) +
      (r.zoneIds.isNotEmpty ? 1 : 0) +
      (r.sourceDeviceIds.isNotEmpty ? 1 : 0);

  /// Luật khớp đầu tiên (priority nhỏ trước, cùng priority thì luật cụ thể hơn trước,
  /// cuối cùng theo thứ tự khai báo) thắng.
  ///
  /// [supportedKinds]: các loại máy in thiết bị hiện tại in được. Luật mà mọi máy in
  /// đích đều thuộc loại KHÔNG hỗ trợ (vd Sunmi khi chưa có driver) sẽ bị BỎ QUA và
  /// chuyển sang luật khớp kế tiếp, để phiếu vẫn in được qua đường khác thay vì mất.
  /// Máy in bị TẮT thì khác: luật vẫn thắng (không in, hoặc dùng máy dự phòng).
  static List<ResolvedPrint> resolve(
    PrintSetup setup,
    PrintJobType job,
    PrintContext ctx, {
    Set<PrinterKind>? supportedKinds,
  }) {
    final indexed = <MapEntry<int, PrintRule>>[];
    for (var i = 0; i < setup.rules.length; i++) {
      final r = setup.rules[i];
      if (_matches(r, job, ctx)) indexed.add(MapEntry(i, r));
    }
    if (indexed.isEmpty) return const [];
    indexed.sort((a, b) {
      final p = a.value.priority.compareTo(b.value.priority);
      if (p != 0) return p;
      final s = _specificity(b.value).compareTo(_specificity(a.value));
      if (s != 0) return s;
      return a.key.compareTo(b.key);
    });

    // Máy in gắn vào một thiết bị cụ thể (ownerDeviceId) chỉ dùng được trên thiết bị đó.
    bool supported(PrinterEntry p) {
      if (p.ownerDeviceId != null &&
          p.ownerDeviceId!.isNotEmpty &&
          ctx.sourceDeviceId != null &&
          p.ownerDeviceId != ctx.sourceDeviceId) {
        return false;
      }
      return supportedKinds == null || supportedKinds.contains(p.kind);
    }

    for (final entry in indexed) {
      final rule = entry.value;
      final out = <ResolvedPrint>[];
      var unsupportedTargets = 0;
      for (final t in rule.targets) {
        final p = setup.printerById(t.printerId);
        if (p == null || !p.enabled) continue;
        if (!supported(p)) {
          unsupportedTargets++;
          continue;
        }
        out.add(ResolvedPrint(
          printer: p,
          copies: t.copies,
          templateKey: t.templateKey,
          ruleId: rule.id,
        ));
      }
      if (out.isEmpty && rule.fallbackPrinterId != null) {
        final fb = setup.printerById(rule.fallbackPrinterId!);
        if (fb != null && fb.enabled && supported(fb)) {
          out.add(ResolvedPrint(
            printer: fb,
            copies: 1,
            templateKey:
                rule.targets.isNotEmpty ? rule.targets.first.templateKey : null,
            ruleId: rule.id,
            usedFallback: true,
          ));
        }
      }
      if (out.isNotEmpty) return out;
      // Luật chỉ trỏ tới máy in thiết bị này chưa in được -> thử luật kế tiếp.
      if (unsupportedTargets > 0) continue;
      return const [];
    }
    return const [];
  }
}
