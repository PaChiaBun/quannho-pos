// lib/core/services/app_heartbeat_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Nhịp app (ke-hoach-admin-tang-truong-dot2.md): máy nào, nền tảng nào, bản nào đang mở app mỗi ngày.
// Chỉ gửi mã máy ngẫu nhiên + nền tảng + phiên bản; không gửi tên, số điện thoại.
// Mọi lỗi bỏ qua im lặng: không bao giờ được chặn bán hàng hay làm chậm màn hình.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../utils/app_logger.dart';

typedef HeartbeatRpc =
    Future<dynamic> Function(String fn, Map<String, dynamic> params);

/// Nguồn khách trong ô "Biết Quán Nhỏ từ đâu?" (mã khớp CHECK của stores.signup_source).
const Map<String, String> kSignupSources = {
  'friend': 'Bạn bè giới thiệu',
  'facebook': 'Facebook',
  'google': 'Google',
  'sales': 'Nhân viên bán hàng',
  'other': 'Khác',
};

class AppHeartbeat {
  /// Chỉ dùng cho test: thay lời gọi máy chủ.
  @visibleForTesting
  static HeartbeatRpc? rpcOverride;

  /// Chỉ dùng cho test: phiên bản và ngày.
  @visibleForTesting
  static (String, int)? versionOverride;
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  // Nhịp bị từ chối hoặc mất mạng: 10 phút sau mới thử lại, web có thể báo "trở lại" mỗi lần đổi tab.
  static const Duration _retryAfter = Duration(minutes: 10);

  static String? _sentKey;
  static String? _sendingKey;
  static DateTime? _failedAt;
  static String? _failedKey;
  static _HeartbeatLifecycle? _lifecycle;

  @visibleForTesting
  static void resetForTest() {
    _sentKey = null;
    _sendingKey = null;
    _failedAt = null;
    _failedKey = null;
    rpcOverride = null;
    versionOverride = null;
    now = DateTime.now;
  }

  static Future<dynamic> _rpc(String fn, Map<String, dynamic> params) {
    final override = rpcOverride;
    if (override != null) return override(fn, params);
    return Supabase.instance.client.rpc(fn, params: params);
  }

  /// Báo nhịp: mỗi quán mỗi ngày 1 lần trong một lần chạy app. Gửi lỗi thì lần sau thử lại.
  static Future<void> ping(String? storeId) async {
    if (storeId == null || storeId.isEmpty) return;
    final t = now();
    final key = '$storeId|${t.year}-${t.month}-${t.day}';
    if (key == _sentKey || key == _sendingKey) return;
    final failedAt = _failedAt;
    if (key == _failedKey && failedAt != null && t.difference(failedAt) < _retryAfter) return;
    _sendingKey = key;
    try {
      final (version, build) = await _version();
      final res = await _rpc('app_heartbeat_v1', {
        'p_store': storeId,
        'p_device': await _deviceId(),
        'p_platform': platformLabel(),
        'p_version': version,
        'p_build': build,
      });
      if (res is Map && res['ok'] == true) {
        _sentKey = key;
        _failedKey = null;
      } else {
        _failedKey = key;
        _failedAt = t;
      }
    } catch (_) {
      // cố ý bỏ qua: nhịp chỉ là số thống kê
      _failedKey = key;
      _failedAt = t;
    } finally {
      if (_sendingKey == key) _sendingKey = null;
    }
  }

  /// App trở lại từ nền thì báo lại; máy để mở nhiều ngày (Sunmi, Windows ở quầy) không có sự kiện đó
  /// nên có thêm nhịp mỗi giờ. ping đã tự chống gửi trùng trong ngày.
  static void attachLifecycle() {
    if (_lifecycle != null) return;
    _lifecycle = _HeartbeatLifecycle();
    WidgetsBinding.instance.addObserver(_lifecycle!);
    Timer.periodic(const Duration(hours: 1), (_) {
      unawaited(ping(AppLogger.sessionStoreId));
    });
  }

  static Future<(String, int)> _version() async {
    final o = versionOverride;
    if (o != null) return o;
    final info = await PackageInfo.fromPlatform();
    // version.json của web có thể thiếu; chuỗi rỗng sẽ bị máy chủ từ chối và mất nhịp
    return (info.version.isEmpty ? 'unknown' : info.version, int.tryParse(info.buildNumber) ?? 0);
  }

  // Cùng khoá 'device_id' với máy in (_getDeviceId), nên một máy chỉ có một mã.
  static Future<String> _deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('device_id');
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    AppLogger.setDeviceId(id);
    return id;
  }

  static String platformLabel({bool? isWeb, TargetPlatform? platform}) {
    if (isWeb ?? kIsWeb) return 'web';
    return switch (platform ?? defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      // Máy chủ từ chối nền tảng lạ; Fuchsia không có bản phát hành
      TargetPlatform.fuchsia => 'linux',
    };
  }

  /// Ghi nguồn khách sau khi tạo quán. Lỗi bỏ qua: không được làm hỏng việc tạo quán.
  static Future<void> saveSignupSource(String storeId, String? source) async {
    if (source == null) return;
    try {
      await _rpc('store_signup_source_set_v1', {
        'p_store': storeId,
        'p_source': source,
      });
    } catch (_) {}
  }
}

class _HeartbeatLifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(AppHeartbeat.ping(AppLogger.sessionStoreId));
    }
  }
}
