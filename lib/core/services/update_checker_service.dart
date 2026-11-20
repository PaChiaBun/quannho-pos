// lib/core/services/update_checker_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// @deprecated: Tích hợp vào AppUpdateManager
// Giữ lại lớp này để tương thích ngược, chuyển tiếp 100% cuộc gọi sang AppUpdateManager
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'app_update_manager.dart';

class UpdateCheckerService {
  /// Gọi 1 lần sau khi MainShell hiển thị
  /// Chuyển tiếp sang [AppUpdateManager.checkAndPromptUpdate]
  @Deprecated('Use AppUpdateManager.checkAndPromptUpdate instead')
  static Future<void> checkForUpdate(BuildContext context) async {
    await AppUpdateManager.checkAndPromptUpdate(context, silent: true);
  }
}
