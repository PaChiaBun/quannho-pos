// lib/core/services/auto_update_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// @deprecated: Tích hợp vào AppUpdateManager
// Giữ lại lớp này để tương thích ngược, chuyển tiếp 100% cuộc gọi sang AppUpdateManager
// Loại bỏ hoàn toàn phụ thuộc GitHub API.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'app_update_manager.dart';

class AutoUpdateService {
  /// Kiểm tra xem có bản cập nhật mới hay không
  /// Chuyển tiếp sang [AppUpdateManager.checkAndPromptUpdate]
  @Deprecated('Use AppUpdateManager.checkAndPromptUpdate instead')
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool showNoUpdateDialog = false,
  }) async {
    await AppUpdateManager.checkAndPromptUpdate(
      context,
      silent: !showNoUpdateDialog,
    );
  }
}
