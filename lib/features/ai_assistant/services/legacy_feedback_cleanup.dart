// lib/features/ai_assistant/services/legacy_feedback_cleanup.dart
// ─────────────────────────────────────────────────────────────────────────────
// Đường phản hồi cũ của Boom (máy chủ thử nghiệm BunServer, "ghép nối thiết bị") đã gỡ 24/10/2026.
// Máy đã dùng bản cũ có thể còn phiên ghép nối + cặp khoá thiết bị trong kho bảo mật → xoá khi đăng xuất.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const kLegacyBoomFeedbackKeys = [
  'boom_feedback_session_token',
  'boom_feedback_ed25519_private_key',
  'boom_feedback_ed25519_public_key',
  // tên trước khi đổi Bum → Boom (23/10/2026)
  'bum_feedback_session_token',
  'bum_feedback_ed25519_private_key',
  'bum_feedback_ed25519_public_key',
];

/// Xoá dữ liệu còn sót của đường phản hồi cũ. Không bao giờ ném lỗi (không chặn đăng xuất).
Future<void> clearLegacyBoomFeedbackKeys({
  FlutterSecureStorage? storage,
}) async {
  final s = storage ?? const FlutterSecureStorage();
  for (final key in kLegacyBoomFeedbackKeys) {
    try {
      await s.delete(key: key);
    } catch (_) {
      // Lỗi plugin kho bảo mật trên web không được làm gián đoạn đăng xuất của thu ngân.
    }
  }
}
