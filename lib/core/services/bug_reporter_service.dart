// lib/core/services/bug_reporter_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bug Reporter — Upload bug report + screenshot lên Supabase
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BugReporterService {
  /// Upload screenshot lên Supabase Storage → trả về public URL
  static Future<String?> uploadScreenshot(File imageFile) async {
    try {
      final client = Supabase.instance.client;
      final bytes = await imageFile.readAsBytes();
      final fileName = 'bug_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'reports/$fileName';

      await client.storage
          .from('bug-screenshots')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ));

      final url = client.storage
          .from('bug-screenshots')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      debugPrint('[BugReporter] Upload error: $e');
      return null;
    }
  }

  /// Upload screenshot từ bytes (dùng khi chụp từ image_picker trả về bytes)
  static Future<String?> uploadScreenshotBytes(Uint8List bytes) async {
    try {
      final client = Supabase.instance.client;
      final fileName = 'bug_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'reports/$fileName';

      await client.storage
          .from('bug-screenshots')
          .uploadBinary(path, bytes, fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ));

      final url = client.storage
          .from('bug-screenshots')
          .getPublicUrl(path);

      return url;
    } catch (e) {
      debugPrint('[BugReporter] Upload bytes error: $e');
      return null;
    }
  }

  /// Gửi bug report lên Supabase
  static Future<bool> submitReport({
    required String description,
    String? screenshotUrl,
    String? userId,
    String? storeId,
    String? screenName,
    Map<String, dynamic>? customLogs,
  }) async {
    try {
      final client = Supabase.instance.client;
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = await _getDeviceInfo(packageInfo, storeId: storeId, userId: userId, customLogs: customLogs);

      await client.from('bug_reports').insert({
        'user_id': userId ?? '',
        'store_id': storeId ?? '',
        'description': description,
        'screenshot_url': screenshotUrl,
        'device_info': deviceInfo,
        'screen_name': screenName ?? 'Settings > Gửi phản hồi',
        'status': 'open',
      });

      return true;
    } catch (e) {
      debugPrint('[BugReporter] Submit error: $e');
      return false;
    }
  }

  /// Thu thập thông tin thiết bị & Nhật ký dấu vết kỹ thuật (System Diagnostic Trace)
  static Future<Map<String, dynamic>> _getDeviceInfo(
    PackageInfo packageInfo, {
    String? storeId,
    String? userId,
    Map<String, dynamic>? customLogs,
  }) async {
    final now = DateTime.now();
    final info = <String, dynamic>{
      'app_version': packageInfo.version,
      'build_number': packageInfo.buildNumber,
      'app_name': packageInfo.appName,
      'reported_at': now.toIso8601String(),
      'store_id': storeId ?? 'unknown',
      'user_id': userId ?? 'unknown',
      'system_logs': {
        'timestamp': now.millisecondsSinceEpoch,
        'formatted_time': now.toLocal().toString(),
        'session_active': userId != null && userId.isNotEmpty,
        'store_linked': storeId != null && storeId.isNotEmpty,
        'trace_id': 'TRACE-${now.millisecondsSinceEpoch}',
        if (customLogs != null) ...customLogs,
      },
    };

    try {
      if (kIsWeb) {
        info['os'] = 'web';
        info['os_version'] = 'Browser PWA / Web Client';
        info['locale'] = 'vi-VN';
      } else {
        info['os'] = Platform.operatingSystem;
        info['os_version'] = Platform.operatingSystemVersion;
        info['locale'] = Platform.localeName;
      }
    } catch (_) {}

    return info;
  }
}
