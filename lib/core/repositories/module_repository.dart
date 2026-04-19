import 'package:drift/drift.dart';
import '../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE CONTROLLER REPOSITORY — Quản lý bật/tắt Lego modules
// ─────────────────────────────────────────────────────────────────────────────
class ModuleRepository {
  final AppDatabase _db;

  ModuleRepository(this._db);

  // ── Streams ───────────────────────────────────────────────────────────────

  /// Tất cả modules, sorted by position
  Stream<List<ModuleConfig>> watchAll() {
    return (_db.select(_db.moduleConfigs)
          ..orderBy([(m) => OrderingTerm.asc(m.position)]))
        .watch();
  }

  /// Chỉ modules đang active
  Stream<List<ModuleConfig>> watchActive() {
    return (_db.select(_db.moduleConfigs)
          ..where((m) => m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.position)]))
        .watch();
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  Future<List<ModuleConfig>> getAll() {
    return (_db.select(_db.moduleConfigs)
          ..orderBy([(m) => OrderingTerm.asc(m.position)]))
        .get();
  }

  Future<bool> isActive(String moduleId) async {
    final config = await (_db.select(_db.moduleConfigs)
          ..where((m) => m.id.equals(moduleId)))
        .getSingleOrNull();
    return config?.isActive ?? false;
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Tắt module — chỉ set is_active = false, KHÔNG xóa data
  Future<void> deactivate(String moduleId) async {
    await (_db.update(_db.moduleConfigs)
          ..where((m) => m.id.equals(moduleId)))
        .write(ModuleConfigsCompanion(
      isActive: const Value(false),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Bật module lại
  Future<void> activate(String moduleId) async {
    await (_db.update(_db.moduleConfigs)
          ..where((m) => m.id.equals(moduleId)))
        .write(ModuleConfigsCompanion(
      isActive: const Value(true),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Cập nhật thứ tự kéo thả
  Future<void> updatePositions(List<String> orderedIds) async {
    await _db.transaction(() async {
      for (int i = 0; i < orderedIds.length; i++) {
        await (_db.update(_db.moduleConfigs)
              ..where((m) => m.id.equals(orderedIds[i])))
            .write(ModuleConfigsCompanion(
          position: Value(i),
          updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        ));
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP SETTINGS REPOSITORY — Key-value cài đặt
// ─────────────────────────────────────────────────────────────────────────────
class AppSettingsRepository {
  final AppDatabase _db;

  AppSettingsRepository(this._db);

  Future<String?> get(String key) async {
    final row = await (_db.select(_db.appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String value) async {
    await _db.into(_db.appSettings).insertOnConflictUpdate(
        AppSettingsCompanion(key: Value(key), value: Value(value)));
  }

  Future<String> getOrDefault(String key, String defaultValue) async {
    return (await get(key)) ?? defaultValue;
  }

  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final val = await get(key);
    return val == 'true' ? true : (val == 'false' ? false : defaultValue);
  }

  Future<double> getDouble(String key, {double defaultValue = 0}) async {
    final val = await get(key);
    return double.tryParse(val ?? '') ?? defaultValue;
  }

  // ── Convenience getters ───────────────────────────────────────────────────
  Future<String> get shopName => getOrDefault('shop_name', 'Quán Nhỏ');
  Future<bool> get receiptEnabled => getBool('receipt_enabled');
  Future<double> get taxRate => getDouble('tax_rate');
  Future<double> get loyaltyRate =>
      getDouble('loyalty_rate', defaultValue: 10000);
}
