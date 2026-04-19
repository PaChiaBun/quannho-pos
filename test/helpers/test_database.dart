// test/helpers/test_database.dart
// ─────────────────────────────────────────────────────────────────────────────
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
