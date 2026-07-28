import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  /// Ghi vết thao tác người dùng (Chủ quán, Quản lý, Nhân viên) trên tất cả các module
  static void logUserAction({
    required String tag,
    required String action,
    Map<String, dynamic>? details,
    String level = 'INFO',
  }) {
    final detailsStr = details != null && details.isNotEmpty ? jsonEncode(details) : null;
    if (level == 'WARNING') {
      warning(tag, action);
      if (detailsStr != null) _writeCloud('WARNING', tag, action, detailsStr);
    } else if (level == 'ERROR') {
      error(tag, action, detailsStr);
    } else {
      info(tag, action);
      if (detailsStr != null) _writeCloud('INFO', tag, action, detailsStr);
    }
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
    _writeCloud('INFO', tag, message, null);
  }

  /// Ghi log cảnh báo (lưu cục bộ + gửi lên Cloud)
  static void warning(String tag, String message) {
    final logMsg = '[$tag] $message';
    debugPrint('[WARN] $logMsg');
    _writeLocal('WARNING', tag, message, null);
    _writeCloud('WARNING', tag, message, null);
  }

  /// Ghi log lỗi nghiêm trọng (lưu cục bộ + gửi lên Cloud kèm StackTrace)
  static void error(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    final detailsStr = '${error != null ? "$error\n" : ""}${stackTrace ?? ""}';
    final logMsg = '[$tag] $message ${detailsStr.isNotEmpty ? "\nDetails: $detailsStr" : ""}';
    debugPrint('[ERROR] $logMsg');
    _writeLocal('ERROR', tag, message, detailsStr.isEmpty ? null : detailsStr);
    _writeCloud('ERROR', tag, message, detailsStr.isEmpty ? null : detailsStr);
  }

  /// Ghi log ra file cục bộ app_logs.txt (Cơ chế xoay vòng 5MB)
  static Future<void> _writeLocal(String level, String tag, String message, String? details) async {
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
      final logLine = '[$timestamp] [$level] [$devId] [$staff] [$tag] $message${details != null ? "\n--> DETAILS: $details" : ""}\n';
      await file.writeAsString(logLine, mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// Đồng bộ log lên bảng app_logs của Supabase
  static Future<void> _writeCloud(String level, String tag, String message, String? details) async {
    final storeId = _storeId;
    if (storeId == null || storeId.isEmpty) return;

    try {
      // Đảm bảo x-store-id tồn tại trong Header REST
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;

      await Supabase.instance.client.from('app_logs').insert({
        'store_id': storeId,
        'device_id': _deviceId ?? 'Unknown',
        'staff_name': _staffName ?? 'System',
        'level': level,
        'tag': tag,
        'message': message,
        'details': details,
      });
    } catch (_) {
      // Bỏ qua lỗi kết nối mạng / Supabase khi ghi log đám mây
    }
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
