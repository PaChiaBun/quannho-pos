// test/repositories/settings_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho AppSettingsRepository
// ⚠️ TODO: Migrate sang integration tests với Supabase
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/module_repository.dart';

void main() {
  group('AppSettingsRepository (Supabase)', () {
    test('SKIP — cần integration test với Supabase thật', () {
      // TODO: Viết integration tests dùng Supabase test environment
      // AppSettingsRepository.get(key) — đọc từ Supabase store_settings
      // AppSettingsRepository.set(key, value) — upsert vào Supabase
      // AppSettingsRepository.shopName — getter shortcut
      // AppSettingsRepository.loyaltyRate — parse double
      expect(true, isTrue); // placeholder
    }, skip: 'Drift in-memory DB không còn được hỗ trợ sau khi migrate sang Supabase');
  });

  group('AttendanceConfig Data Model', () {
    test('AttendanceConfig default values and helpers', () {
      const config = AttendanceConfig();
      expect(config.lat, isNull);
      expect(config.lng, isNull);
      expect(config.radius, 200.0);
      expect(config.hasLocation, isFalse);

      const filled = AttendanceConfig(
        lat: 10.776889,
        lng: 106.700806,
        address: 'Quán Nhỏ',
        radius: 150.0,
      );
      expect(filled.hasLocation, isTrue);
      expect(filled.toMap()['radius'], 150.0);
    });

    test('AppSettingsRepository constructor with explicit storeId', () {
      final repo = AppSettingsRepository('custom_store_id');
      expect(repo, isNotNull);
    });
  });

  group('General', () {
    test('true is true', () {
      expect(true, isTrue);
    });
  });
}
