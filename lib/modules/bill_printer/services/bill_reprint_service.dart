import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_providers.dart';
import '../../../core/repositories/bill_history_repository.dart';
import '../../../core/utils/app_logger.dart';
import '../providers/printer_settings_provider.dart';
import '../screens/bill_preview_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// IN LẠI BILL CŨ — chỉ in phần hoá đơn thu ngân (không in lại phiếu bếp/tem),
// số đơn kèm "BẢN IN LẠI", giờ in là giờ thanh toán gốc. Mỗi lần in ghi
// app_logs `reprint_bill` (critical) để Chủ quán kiểm ai in, bill nào.
// ─────────────────────────────────────────────────────────────────────────────

enum ReprintOutcome { printed, notConfigured, failed }

/// Dựng BillData in lại từ dữ liệu gốc (thuần, để test).
BillData buildReprintBill(
  ReprintSource src, {
  required String shopName,
  String? shopPhone,
  String? shopAddress,
  String? footer,
}) => BillData(
  shopName: shopName,
  shopPhone: (shopPhone ?? '').isEmpty ? null : shopPhone,
  shopAddress: (shopAddress ?? '').isEmpty ? null : shopAddress,
  footer: (footer ?? '').isEmpty ? null : footer,
  orderNumber: src.reprintOrderNumber,
  createdAt: src.paidAt,
  tableName: src.tableName,
  items: [
    for (final l in src.lines)
      BillItem(name: l.name, qty: l.qty, price: l.unitPrice),
    if (src.surcharge > 0)
      BillItem(name: 'Phí dịch vụ / Ship', qty: 1, price: src.surcharge),
  ],
  subtotal: src.subtotal,
  discount: src.discount,
  total: src.total,
  paymentMethod: src.paymentMethod,
  type: BillType.receipt,
);

class BillReprintService {
  final Ref _ref;
  BillReprintService(this._ref);

  Future<ReprintOutcome> reprint(BillHistoryEntry entry) async {
    final src = await _ref
        .read(billHistoryRepositoryProvider)
        .loadSource(entry.referenceId);
    final s = _ref.read(settingsRepositoryProvider);
    final bill = buildReprintBill(
      src,
      shopName: await s.shopName,
      shopPhone: await s.shopPhone,
      shopAddress: await s.shopAddress,
      footer: await s.billFooter,
    );
    ReprintOutcome outcome;
    try {
      final res = await StationPrinterDispatcher.printBill(
        bill,
        _ref.read(printerSettingsProvider),
        onlyReceipt: true,
      );
      final st = res.stationResults['cashier']?.status;
      outcome = res.isStationSuccess('cashier')
          ? ReprintOutcome.printed
          : st == StationPrintStatus.notConfigured
          ? ReprintOutcome.notConfigured
          : ReprintOutcome.failed;
    } catch (e, stack) {
      // Lỗi máy in vẫn phải có dòng nhật ký "đã thử in lại".
      AppLogger.error('bill_reprint', 'In lại bill lỗi: $e', e, stack);
      outcome = ReprintOutcome.failed;
    }
    // Ghi sau khi in để nhật ký phân biệt in được / chưa cài máy in / lỗi.
    AppLogger.action(
      'reprint_bill',
      'In lại bill cũ',
      table: src.tableName,
      orderId: entry.referenceId,
      total: src.total,
      result: outcome.name,
      extra: {
        'order_number': src.orderNumber,
        'paid_at': src.paidAt.toIso8601String(),
        'source': 'report_invoice_tab',
      },
      critical: true,
    );
    return outcome;
  }
}

final billReprintServiceProvider = Provider<BillReprintService>(
  (ref) => BillReprintService(ref),
);
