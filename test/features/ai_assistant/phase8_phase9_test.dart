// test/features/ai_assistant/phase8_phase9_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Test Suite cho Phase 8 (Dataset & QLoRA Config) & Phase 9 (Shadow Test Feature Flag)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/dataset/dataset_qlora_config.dart';

void main() {
  group('Phase 8 & Phase 9 Verification Tests', () {
    test('Kiểm tra tỷ lệ phân bổ Dataset V1 đủ 100%', () {
      final totalShare =
          DatasetDistribution.moduleHelpShare +
          DatasetDistribution.classificationToolsShare +
          DatasetDistribution.posAnalysisShare +
          DatasetDistribution.privacyPermissionsShare +
          DatasetDistribution.missingDataShare +
          DatasetDistribution.bumPersonaShare;

      expect(totalShare, closeTo(1.0, 0.001));
      expect(DatasetDistribution.goldSetSize, greaterThanOrEqualTo(500));
    });

    test('Feature Flag Shadow Test Quán Kay chỉ bật cho Owner Quán Kay', () {
      final isKayOwnerEnabled = ShadowTestFeatureFlag.isBumEnabledForStore(
        storeId: '00000000-0000-0000-0000-000000009999',
        userRole: 'owner',
        isOwner: true,
      );

      final isOtherStoreEnabled = ShadowTestFeatureFlag.isBumEnabledForStore(
        storeId: 'other_store_123',
        userRole: 'owner',
        isOwner: true,
      );

      final isStaffEnabled = ShadowTestFeatureFlag.isBumEnabledForStore(
        storeId: '00000000-0000-0000-0000-000000009999',
        userRole: 'cashier',
        isOwner: false,
      );

      expect(isKayOwnerEnabled, isTrue);
      expect(isOtherStoreEnabled, isFalse);
      expect(isStaffEnabled, isFalse);
    });
  });
}
