// lib/features/ai_assistant/dataset/dataset_qlora_config.dart
// ─────────────────────────────────────────────────────────────────────────────
// Phase 8 & 9 — Dataset Distribution, QLoRA Config & Shadow Test Feature Flag
// ─────────────────────────────────────────────────────────────────────────────

class DatasetDistribution {
  static const double moduleHelpShare = 0.30;
  static const double classificationToolsShare = 0.25;
  static const double posAnalysisShare = 0.20;
  static const double privacyPermissionsShare = 0.10;
  static const double missingDataShare = 0.10;
  static const double bumPersonaShare = 0.05;

  static const int targetDatasetSizeV1 = 5000;
  static const int goldSetSize = 600;
}

class QloraConfig {
  static const String baseModel = 'Qwen/Qwen2.5-3B-Instruct';
  static const int r = 16;
  static const int loraAlpha = 32;
  static const double loraDropout = 0.05;
  static const String targetModules = 'q_proj,k_proj,v_proj,o_proj';
  static const String hardwareTarget =
      'MacBook Pro M3 Pro 18GB (MLX) / RTX 2060 6GB';
}

class ShadowTestFeatureFlag {
  // Bật Feature Flag duy nhất cho Quán Kay và Owner tài khoản chỉ định
  static bool isBumEnabledForStore({
    required String storeId,
    required String userRole,
    required bool isOwner,
  }) {
    // Phase 9 Rollout: Chỉ bật cho Quán Kay và vị trí Chủ quán / Quản lý
    if (storeId.isEmpty) return false;

    // Đảm bảo fail-closed: Chỉ cho phép Owner/Manager thử nghiệm Shadow Mode tại Quán Kay
    final isKayStore =
        storeId.contains('kay') ||
        storeId == '00000000-0000-0000-0000-000000009999';
    return isKayStore &&
        (isOwner ||
            userRole.toLowerCase() == 'owner' ||
            userRole.toLowerCase() == 'manager');
  }
}
