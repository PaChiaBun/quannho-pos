// test/helpers/test_database.dart
// ─────────────────────────────────────────────────────────────────────────────
<<<<<<< HEAD
// ⚠️ DEPRECATED — không còn dùng sau khi migrate sang Supabase
// File này được giữ lại để tham khảo nhưng không được import từ test nào.
// Khi viết integration tests mới, dùng Supabase test client.
// ─────────────────────────────────────────────────────────────────────────────
=======
// Test helper — tạo AppDatabase in-memory (không dùng file)
// Dùng NativeDatabase.memory() của Drift
// ─────────────────────────────────────────────────────────────────────────────
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:quannho_pos/core/database/app_database.dart';

/// Tạo DB in-memory cho unit tests — tự seed dữ liệu ban đầu
AppDatabase createTestDatabase() {
  return AppDatabase.forTesting(NativeDatabase.memory());
}
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
