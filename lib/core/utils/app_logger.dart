import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLogger {
  static String? _storeId;
  static String? _staffName;
  static String? _deviceId;

  /// Cập nhật thông tin phiên làm việc hiện tại
  static void updateSession({String? storeId, String? staffName}) {
    _storeId = storeId;
    _staffName = staffName;
  }

  /// Thiết lập Device ID để định danh thiết bị ghi log
  static void setDeviceId(String deviceId) {
    _deviceId = deviceId;
  }

  /// Ghi vết thao tác người dùng (Chủ quán, Quản lý, Nhân viên) trên tất cả các module.
  /// `critical: true` -> gửi lên máy chủ gần như ngay (hủy bàn, thanh toán, PIN...).
  static void logUserAction({
    required String tag,
    required String action,
    Map<String, dynamic>? details,
    String level = 'INFO',
    bool critical = false,
  }) {
    final detailsStr = details != null && details.isNotEmpty
        ? jsonEncode(details)
        : null;
    final lvl = (level == 'WARNING' || level == 'ERROR') ? level : 'INFO';
    debugPrint('[$lvl] [$tag] $action');
    _writeLocal(lvl, tag, action, detailsStr);
    _enqueueCloud(
      lvl,
      tag,
      action,
      detailsStr,
      immediate: critical || lvl == 'ERROR',
    );
  }

  /// Ghi một HÀNH ĐỘNG nghiệp vụ theo chuẩn trường để sau này tra cứu (tag = 'action').
  /// Không bao giờ truyền PIN/mật khẩu vào đây.
  static void action(
    String code,
    String label, {
    String? table,
    String? sessionId,
    String? orderId,
    int? lines,
    double? total,
    String? approver,
    String? result,
    String? reason,
    Map<String, dynamic>? extra,
    bool critical = false,
    String level = 'INFO',
  }) {
    final d = <String, dynamic>{
      'act': code,
      if (table != null) 'table': table,
      if (sessionId != null) 'session': sessionId,
      if (orderId != null) 'order': orderId,
      if (lines != null) 'lines': lines,
      if (total != null) 'total': total.round(),
      if (approver != null) 'approver': approver,
      if (result != null) 'result': result,
      if (reason != null) 'reason': reason,
      if (_staffName != null) 'staff': _staffName,
      if (_deviceId != null) 'device': _deviceId,
      ...?extra,
    };
    final parts = <String>[
      label,
      if (table != null) table,
      if (lines != null) '$lines dòng',
      if (total != null) '${total.round()}đ',
      if (approver != null) 'duyệt: $approver',
      if (reason != null) 'lý do: $reason',
      if (result != null) result,
    ];
    logUserAction(
      tag: 'action',
      action: parts.join(' · '),
      details: d,
      level: level,
      critical: critical,
    );
  }

  /// Ghi log gỡ lỗi (chỉ lưu cục bộ, không gửi lên Cloud để tránh spam)
  static void debug(String tag, String message) {
    final logMsg = '[$tag] $message';
    debugPrint('[DEBUG] $logMsg');
    _writeLocal('DEBUG', tag, message, null);
  }

  /// Ghi log thông tin hoạt động thường (lưu cục bộ + gửi lên Cloud)
  static void info(String tag, String message) {
    final logMsg = '[$tag] $message';
    debugPrint('[INFO] $logMsg');
    _writeLocal('INFO', tag, message, null);
    _enqueueCloud('INFO', tag, message, null);
  }

  /// Ghi log cảnh báo (lưu cục bộ + gửi lên Cloud)
  static void warning(String tag, String message) {
    final logMsg = '[$tag] $message';
    debugPrint('[WARN] $logMsg');
    _writeLocal('WARNING', tag, message, null);
    _enqueueCloud('WARNING', tag, message, null);
  }

  /// Ghi log lỗi nghiêm trọng (lưu cục bộ + gửi lên Cloud kèm StackTrace)
  static void error(
    String tag,
    String message, [
    dynamic error,
    StackTrace? stackTrace,
  ]) {
    final detailsStr = '${error != null ? "$error\n" : ""}${stackTrace ?? ""}';
    final logMsg =
        '[$tag] $message ${detailsStr.isNotEmpty ? "\nDetails: $detailsStr" : ""}';
    debugPrint('[ERROR] $logMsg');
    _writeLocal('ERROR', tag, message, detailsStr.isEmpty ? null : detailsStr);
    _enqueueCloud(
      'ERROR',
      tag,
      message,
      detailsStr.isEmpty ? null : detailsStr,
      immediate: true,
    );
  }

  /// Ghi log ra file cục bộ app_logs.txt (Cơ chế xoay vòng 5MB)
  static Future<void> _writeLocal(
    String level,
    String tag,
    String message,
    String? details,
  ) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_logs.txt');

      // Kiểm tra xoay vòng log nếu vượt quá 5MB
      if (await file.exists()) {
        final length = await file.length();
        if (length > 5 * 1024 * 1024) {
          final oldFile = File('${directory.path}/app_logs_old.txt');
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
          await file.rename(oldFile.path);
        }
      }

      final timestamp = DateTime.now().toLocal().toString();
      final staff = _staffName ?? 'System';
      final devId = _deviceId ?? 'Unknown';
      final logLine =
          '[$timestamp] [$level] [$devId] [$staff] [$tag] $message${details != null ? "\n--> DETAILS: $details" : ""}\n';
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  // ── GOM LÔ GỬI LÊN MÁY CHỦ ────────────────────────────────────────────────
  // Thay vì 1 request/dòng, log được xếp hàng (và ghi tạm ra đĩa để không mất khi
  // thoát đột ngột) rồi gửi một lần bằng 1 request nhiều dòng khi:
  //   • đủ [flushMaxLines] dòng, hoặc
  //   • đã [flushInterval] kể từ dòng đầu chưa gửi, hoặc
  //   • kết thúc một phiên hành động (đóng bàn/ca/đăng xuất/app xuống nền: gọi [flushNow]), hoặc
  //   • sự kiện quan trọng/lỗi (gửi ngay).
  // Mỗi dòng mang sẵn thời điểm thật (created_at) và quán/nhân viên/thiết bị lúc xảy ra.
  static const int flushMaxLines = 60;
  static const Duration flushInterval = Duration(seconds: 180);
  static const int maxQueue = 2000;
  static const int _chunkSize = 200;
  static final List<Map<String, dynamic>> _queue = [];
  static Timer? _timer;
  static bool _flushing = false;
  static bool _flushAgain = false;
  static bool _persist = true;
  static _LifecycleFlusher? _lifecycle;

  /// Không tạo Timer khi chạy `flutter test` (Timer còn treo làm hỏng widget test). Test
  /// riêng của gom lô bật lại bằng [resetForTest].
  static bool _timersEnabled = kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST');

  /// Chỉ dùng cho test: thay hàm gửi thật và tắt ghi đĩa.
  @visibleForTesting
  static Future<void> Function(String storeId, List<Map<String, dynamic>> rows)?
  senderOverride;

  @visibleForTesting
  static void resetForTest({bool persist = false, bool timers = true}) {
    _timersEnabled = timers;
    _queue.clear();
    _timer?.cancel();
    _timer = null;
    _flushing = false;
    _flushAgain = false;
    _persist = persist;
    senderOverride = null;
    _storeId = null;
    _staffName = null;
    _deviceId = null;
  }

  @visibleForTesting
  static int get pendingCount => _queue.length;

  /// Gọi khi kết thúc một phiên hành động (đóng bàn, đóng ca, đăng xuất...).
  static Future<void> flushNow() => _flush();

  /// Tự gửi khi app xuống nền/thoát. Gọi một lần trong main().
  static void attachLifecycle() {
    if (_lifecycle != null) return;
    _lifecycle = _LifecycleFlusher();
    WidgetsBinding.instance.addObserver(_lifecycle!);
  }

  static void _enqueueCloud(
    String level,
    String tag,
    String message,
    String? details, {
    bool immediate = false,
  }) {
    final storeId = _storeId;
    if (storeId == null || storeId.isEmpty) return;
    final row = <String, dynamic>{
      'store_id': storeId,
      'device_id': _deviceId ?? 'Unknown',
      'staff_name': _staffName ?? 'System',
      'level': level,
      'tag': tag,
      'message': message,
      'details': details,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    _queue.add(row);
    if (_queue.length > maxQueue)
      _queue.removeRange(0, _queue.length - maxQueue);
    _persistAppend(row);
    if (immediate || _queue.length >= flushMaxLines) {
      unawaited(_flush());
    } else {
      if (_timersEnabled) {
        _timer ??= Timer(flushInterval, () {
          _timer = null;
          unawaited(_flush());
        });
      }
    }
  }

  static Future<void> _defaultSender(
    String storeId,
    List<Map<String, dynamic>> rows,
  ) async {
    // Đảm bảo x-store-id tồn tại trong Header REST
    Supabase.instance.client.rest.headers['x-store-id'] = storeId;
    await Supabase.instance.client.from('app_logs').insert(rows);
  }

  static Future<void> _flush() async {
    if (_flushing) {
      _flushAgain = true;
      return;
    }
    if (_queue.isEmpty) return;
    _flushing = true;
    _timer?.cancel();
    _timer = null;
    try {
      do {
        _flushAgain = false;
        // Bỏ dòng quá cũ (>24h) để một lô hỏng không chặn hàng chờ mãi mãi.
        final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 24));
        _queue.removeWhere((q) {
          final t = DateTime.tryParse('${q['created_at']}');
          return t != null && t.isBefore(cutoff);
        });
        final snapshot = List<Map<String, dynamic>>.of(_queue);
        // Gom theo quán nhưng giữ thứ tự; mỗi request tối đa [_chunkSize] dòng.
        final byStore = <String, List<Map<String, dynamic>>>{};
        for (final r in snapshot) {
          (byStore[r['store_id'] as String] ??= []).add(r);
        }
        var anyFailed = false;
        for (final entry in byStore.entries) {
          try {
            for (var i = 0; i < entry.value.length; i += _chunkSize) {
              final end = (i + _chunkSize).clamp(0, entry.value.length);
              final chunk = entry.value.sublist(i, end);
              await (senderOverride ?? _defaultSender)(entry.key, chunk);
              _queue.removeWhere((q) => chunk.any((c) => identical(c, q)));
            }
          } catch (_) {
            // Quán này lỗi (mạng/quyền) thì vẫn gửi tiếp quán khác.
            anyFailed = true;
          }
        }
        await _persistRewrite();
        if (anyFailed) throw StateError('một phần log chưa gửi được');
      } while (_flushAgain && _queue.isNotEmpty);
    } catch (_) {
      // Mạng/máy chủ lỗi: giữ nguyên hàng chờ, thử lại sau một chu kỳ.
      if (_timersEnabled) {
        _timer ??= Timer(flushInterval, () {
          _timer = null;
          unawaited(_flush());
        });
      }
    } finally {
      _flushing = false;
    }
  }

  static Future<File?> _pendingFile() async {
    if (!_persist || kIsWeb) return null;
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/app_logs_pending.jsonl');
    } catch (_) {
      return null;
    }
  }

  static void _persistAppend(Map<String, dynamic> row) {
    if (!_persist || kIsWeb) return;
    unawaited(() async {
      try {
        final f = await _pendingFile();
        await f?.writeAsString('${jsonEncode(row)}\n', mode: FileMode.append);
      } catch (_) {}
    }());
  }

  static Future<void> _persistRewrite() async {
    try {
      final f = await _pendingFile();
      if (f == null) return;
      if (_queue.isEmpty) {
        if (await f.exists()) await f.delete();
      } else {
        await f.writeAsString(_queue.map((r) => '${jsonEncode(r)}\n').join());
      }
    } catch (_) {}
  }

  /// Nạp lại log chưa gửi từ lần chạy trước (app tắt đột ngột/mất mạng). Gọi trong main().
  static Future<void> restorePending() async {
    try {
      final f = await _pendingFile();
      if (f == null || !await f.exists()) return;
      final restored = <Map<String, dynamic>>[];
      for (final line in await f.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          restored.add(Map<String, dynamic>.from(jsonDecode(line) as Map));
        } catch (_) {}
      }
      if (restored.isEmpty) return;
      _queue.insertAll(0, restored);
      if (_queue.length > maxQueue)
        _queue.removeRange(0, _queue.length - maxQueue);
      if (_timersEnabled) {
        _timer ??= Timer(const Duration(seconds: 20), () {
          _timer = null;
          unawaited(_flush());
        });
      }
    } catch (_) {}
  }

  /// Hàm tiện ích đọc toàn bộ log cục bộ
  static Future<String> readLocalLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_logs.txt');
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (_) {}
    return 'Chưa có dữ liệu nhật ký.';
  }

  /// Hàm tiện ích xóa sạch log cục bộ
  static Future<void> clearLocalLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/app_logs.txt');
      if (await file.exists()) {
        await file.delete();
      }
      final oldFile = File('${directory.path}/app_logs_old.txt');
      if (await oldFile.exists()) {
        await oldFile.delete();
      }
    } catch (_) {}
  }
}

class _LifecycleFlusher with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      unawaited(AppLogger.flushNow());
    }
  }
}
