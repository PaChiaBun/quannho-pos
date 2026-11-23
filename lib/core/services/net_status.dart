// lib/core/services/net_status.dart
// ─────────────────────────────────────────────────────────────────────────────
// Có tới được máy chủ hay không, suy ra từ chính các yêu cầu app gửi đi
// ([JwtGateHttpClient] báo vào đây) — không thêm thư viện dò mạng.
// Một yêu cầu hỏng chưa chắc là mất mạng: chờ [confirmAfter] rồi gọi [probe] hỏi lại,
// hỏng tiếp mới bật [offline]. Sau đó hỏi lại mỗi [probeEvery] tới khi thông.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';

import 'package:flutter/foundation.dart';

class NetStatus {
  /// true = đang không tới được máy chủ (dải "Đang mất mạng" nghe biến này).
  static final ValueNotifier<bool> offline = ValueNotifier<bool>(false);

  /// Hỏi thử máy chủ: true (hoặc không ném lỗi) = tới được. Chưa gắn thì không bao giờ báo mất mạng.
  static Future<bool> Function()? probe;

  static Duration confirmAfter = const Duration(seconds: 2);
  static Duration probeEvery = const Duration(seconds: 10);
  static Timer? _timer;

  static void requestOk() {
    _timer?.cancel();
    _timer = null;
    offline.value = false;
  }

  static void requestFailed() {
    if (_timer != null || probe == null) return; // đang hỏi lại rồi
    _timer = Timer(confirmAfter, _check);
  }

  static Future<void> _check() async {
    final mine = _timer;
    bool ok;
    try {
      ok = await probe!();
    } catch (_) {
      ok = false;
    }
    if (!identical(_timer, mine)) return; // trong lúc hỏi đã có yêu cầu khác thành công
    if (ok) {
      requestOk();
      return;
    }
    offline.value = true;
    _timer = Timer(probeEvery, _check);
  }

  @visibleForTesting
  static void reset() {
    _timer?.cancel();
    _timer = null;
    probe = null;
    offline.value = false;
    confirmAfter = const Duration(seconds: 2);
    probeEvery = const Duration(seconds: 10);
  }
}
