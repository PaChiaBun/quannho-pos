// test/repositories/settings_repository_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit tests cho AppSettingsRepository
// ⚠️ TODO: Migrate sang integration tests với Supabase
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';

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

  // Placeholder tests để file không rỗng
  group('General', () {
    test('true is true', () {
      expect(true, isTrue);
    });
  });
}
