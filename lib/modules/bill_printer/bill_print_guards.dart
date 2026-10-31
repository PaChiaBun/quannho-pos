import 'dart:async';

import 'package:flutter/foundation.dart';

/// Trạng thái in bill thanh toán của máy này.
enum BillPrintStatus { pending, printed, overdue }

/// Canh bill vừa thanh toán: nếu chưa xác nhận in xong sau [timeout] thì chuyển sang
/// `overdue` để màn hình báo cho thu ngân và đưa nút "In lại bill".
class BillPrintWatchdog {
  BillPrintWatchdog({
    this.timeout = const Duration(seconds: 30),
    this.onOverdue,
  });

  final Duration timeout;
  final VoidCallback? onOverdue;
  final ValueNotifier<BillPrintStatus> status = ValueNotifier(
    BillPrintStatus.pending,
  );
  Timer? _timer;
  bool _disposed = false;

  void start() {
    _timer?.cancel();
    _timer = Timer(timeout, () {
      if (_disposed || status.value != BillPrintStatus.pending) return;
      status.value = BillPrintStatus.overdue;
      onOverdue?.call();
    });
  }

  /// Đã in (hoặc máy khác đã in) -> hủy cảnh báo; từ `overdue` cũng về `printed` sau khi in lại.
  void markPrinted() {
    _timer?.cancel();
    if (!_disposed) status.value = BillPrintStatus.printed;
  }

  /// Lần báo `overdue` gần nhất là vì máy chưa cài máy in bill (in lại cũng không ra).
  bool notConfigured = false;

  /// In (hoặc in lại) thất bại ngay: báo quá hạn tức thì (không chờ hết chu kỳ).
  void markOverdue({bool notConfigured = false}) {
    _timer?.cancel();
    this.notConfigured = notConfigured;
    if (!_disposed) status.value = BillPrintStatus.overdue;
  }

  /// In lại đang chạy: về `pending` và canh lại một chu kỳ.
  void restart() {
    if (_disposed) return;
    notConfigured = false;
    status.value = BillPrintStatus.pending;
    start();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    status.dispose();
  }
}

/// Chặn bấm nút in liên tục (từng có 15 lệnh tạm tính trong 22 giây khi giấy chưa ra).
class PrintClickGuard {
  PrintClickGuard({this.cooldown = const Duration(seconds: 8)});

  final Duration cooldown;
  bool _busy = false;
  DateTime? _lastFinished;

  /// true = được phép in; false = đang in hoặc vừa in xong chưa đủ [cooldown].
  bool tryStart([DateTime? now]) {
    final t = now ?? DateTime.now();
    if (_busy) return false;
    final last = _lastFinished;
    if (last != null && t.difference(last) < cooldown) return false;
    _busy = true;
    return true;
  }

  void finish([DateTime? now]) {
    _busy = false;
    _lastFinished = now ?? DateTime.now();
  }
}
