import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/store_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE REPOSITORY — Supabase app_settings là nguồn sự thật duy nhất
// Key: 'module_config_v2'  Value: JSON ordered list of active module IDs
// ─────────────────────────────────────────────────────────────────────────────

// ─── Danh sách tất cả modules — ID phải khớp với kModuleConfigs ───────────
const _kAllModules = [
  ModuleConfig(id: 'pos',           label: 'Bán hàng',          icon: '🛒', position: 0,  isActive: true),
  ModuleConfig(id: 'table',         label: 'Quản lý Bàn',        icon: '🪑', position: 1,  isActive: false),
  ModuleConfig(id: 'kitchen',       label: 'Bếp',                icon: '🔥', position: 2,  isActive: false),
  ModuleConfig(id: 'bill_printer',  label: 'In Hoá Đơn',         icon: '🖨️', position: 3,  isActive: false),
  ModuleConfig(id: 'kho',           label: 'Kho hàng',           icon: '📦', position: 4,  isActive: false),
  ModuleConfig(id: 'kho_pro',       label: 'Kho Chuyên Nghiệp',  icon: '🍽️', position: 5,  isActive: false),
  ModuleConfig(id: 'finance',       label: 'Thu Chi',            icon: '💰', position: 6,  isActive: false),
  ModuleConfig(id: 'loyalty',       label: 'Khách hàng',         icon: '🏆', position: 7,  isActive: false),
  ModuleConfig(id: 'staff',         label: 'Nhân viên',          icon: '👥', position: 8,  isActive: false),
  ModuleConfig(id: 'report',        label: 'Báo cáo',            icon: '📊', position: 9,  isActive: false),
  ModuleConfig(id: 'chamcong',      label: 'Chấm công',          icon: '🖐️', position: 10, isActive: true),
  ModuleConfig(id: 'tinhluong',     label: 'Tính Lương',         icon: '💵', position: 11, isActive: true),
  ModuleConfig(id: 'kay_ops',       label: 'Vận Hành',           icon: '📋', position: 12, isActive: false),
];

// Key mới — tránh xung đột với legacy SharedPrefs key cũ
const _kSupabaseKey  = 'module_config_v2';
const _kLegacyPrefsKey = 'module_configs_v1'; // key cũ để migrate

class ModuleRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Đọc danh sách module ID đang active (có thứ tự) từ Supabase ──────────
  Future<List<String>?> _fetchActiveIds(String storeId) async {
    try {
      final row = await _sb
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', _kSupabaseKey)
          .maybeSingle();
      final raw = row?['value'] as String?;
      if (raw == null) return null;
      return (jsonDecode(raw) as List).cast<String>();
    } catch (e) {
      debugPrint('[ModuleRepo] _fetchActiveIds error: $e');
      return null;
    }
  }

  // ── Ghi danh sách module ID vào Supabase ──────────────────────────────────
  Future<void> _saveActiveIds(String storeId, List<String> ids) async {
    try {
      await _sb.from('app_settings').upsert({
        'id':       _uuid.v4(),
        'store_id': storeId,
        'key':      _kSupabaseKey,
        'value':    jsonEncode(ids),
      }, onConflict: 'store_id,key');
    } catch (e) {
      debugPrint('[ModuleRepo] _saveActiveIds error: $e');
    }
  }

  // ── Lấy toàn bộ modules (active state từ Supabase) ────────────────────────
  Future<List<ModuleConfig>> getAll() async {
    final storeId = await _storeId();
    if (storeId == null) return List.from(_kAllModules);

    var activeIds = await _fetchActiveIds(storeId);

    if (activeIds == null) {
      // ── Lần đầu: kiểm tra SharedPreferences cũ để migrate ──────────────
      activeIds = await _migrateFromSharedPrefs();
      // Lưu lên Supabase ngay
      await _saveActiveIds(storeId, activeIds);
      // Xóa key cũ
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kLegacyPrefsKey);
    }

    // ‼️ FIX: Merge module mới có isActive=true mà DB chưa biết
    // (tránh module bị ẩn khi dev thêm module mới với default isActive=true)
    final activeSet = activeIds.toSet();
    bool needsUpdate = false;
    for (final m in _kAllModules) {
      if (m.isActive && !activeSet.contains(m.id)) {
        activeIds.add(m.id);
        needsUpdate = true;
      }
    }
    if (needsUpdate) {
      await _saveActiveIds(storeId, activeIds);
    }

    // Build danh sách đầy đủ: active + thứ tự theo activeIds
    final activeSetFinal = activeIds.toSet();
    final byId = { for (final m in _kAllModules) m.id: m };
    final result = <ModuleConfig>[];

    // Thêm modules active theo đúng thứ tự
    for (int i = 0; i < activeIds.length; i++) {
      final id = activeIds[i];
      final m = byId[id];
      if (m != null) result.add(m.copyWith(isActive: true, position: i));
    }

    // Thêm modules inactive vào cuối (để Picker biết chúng tồn tại)
    for (final m in _kAllModules) {
      if (!activeSetFinal.contains(m.id)) {
        result.add(m.copyWith(isActive: false, position: 100 + m.position));
      }
    }

    return result;
  }

  // ── Migrate từ SharedPreferences ─────────────────────────────────────────
  Future<List<String>> _migrateFromSharedPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLegacyPrefsKey);
      if (raw != null) {
        final saved = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
        final ids = saved
            .where((m) => m['is_active'] == true)
            .map((m) => m['id'] as String)
            .toList();
        if (ids.isNotEmpty) {
          debugPrint('[ModuleRepo] Migrated ${ids.length} active modules from SharedPrefs');
          return ids;
        }
      }
    } catch (_) {}
    // Default: chỉ bật POS
    return ['pos'];
  }

  Stream<List<ModuleConfig>> watchAll() async* {
    yield await getAll();
  }

  Stream<List<ModuleConfig>> watchActive() async* {
    yield (await getAll()).where((m) => m.isActive).toList();
  }

  Future<bool> isActive(String moduleId) async {
    final all = await getAll();
    return all.firstWhere((m) => m.id == moduleId,
        orElse: () => ModuleConfig(id: moduleId, label: '', icon: '', position: 99, isActive: false)
    ).isActive;
  }

  // ── Bật / Tắt module ──────────────────────────────────────────────────────
  Future<void> activate(String moduleId) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    final all = await getAll();
    final activeIds = all.where((m) => m.isActive).map((m) => m.id).toList();
    if (!activeIds.contains(moduleId)) activeIds.add(moduleId);
    await _saveActiveIds(storeId, activeIds);
  }

  Future<void> deactivate(String moduleId) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    final all = await getAll();
    final activeIds = all
        .where((m) => m.isActive && m.id != moduleId)
        .map((m) => m.id)
        .toList();
    await _saveActiveIds(storeId, activeIds);
  }

  // ── Cập nhật thứ tự (drag & drop) ────────────────────────────────────────
  Future<void> updatePositions(List<String> orderedIds) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    // orderedIds = danh sách ID active theo thứ tự mới
    await _saveActiveIds(storeId, orderedIds);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP SETTINGS REPOSITORY — Supabase app_settings (key-value per store)
// ─────────────────────────────────────────────────────────────────────────────
class AppSettingsRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  Future<String?> get(String key) async {
    final storeId = await _storeId();
    if (storeId == null) return null;
    final row = await _sb
        .from('app_settings')
        .select('value')
        .eq('store_id', storeId)
        .eq('key', key)
        .maybeSingle();
    return row?['value'] as String?;
  }

  Future<void> set(String key, String value) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('app_settings').upsert({
      'id':       _uuid.v4(),
      'store_id': storeId,
      'key':      key,
      'value':    value,
    }, onConflict: 'store_id,key');
  }

  Future<String>  getOrDefault(String key, String defaultValue) async =>
      (await get(key)) ?? defaultValue;

  Future<bool>    getBool(String key, {bool defaultValue = false}) async {
    final val = await get(key);
    return val == 'true' ? true : (val == 'false' ? false : defaultValue);
  }

  Future<double>  getDouble(String key, {double defaultValue = 0}) async {
    final val = await get(key);
    return double.tryParse(val ?? '') ?? defaultValue;
  }

  Future<String>  get shopName       => getOrDefault('shop_name', 'Quán Nhỏ');
  Future<String>  get shopPhone      => getOrDefault('shop_phone', '');
  Future<String>  get shopAddress    => getOrDefault('shop_address', '');
  Future<String>  get billFooter     => getOrDefault('bill_footer', 'Cảm ơn quý khách!');
  Future<bool>    get receiptEnabled => getBool('receipt_enabled');
  Future<double>  get taxRate        => getDouble('tax_rate');
  Future<double>  get loyaltyRate    => getDouble('loyalty_rate', defaultValue: 10000);
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS
// ─────────────────────────────────────────────────────────────────────────────
class ModuleConfig {
  final String id;
  final String label;
  final String icon;
  final int position;
  final bool isActive;

  const ModuleConfig({
    required this.id,
    required this.label,
    required this.icon,
    required this.position,
    required this.isActive,
  });

  ModuleConfig copyWith({bool? isActive, int? position}) => ModuleConfig(
        id:       id,
        label:    label,
        icon:     icon,
        position: position ?? this.position,
        isActive: isActive ?? this.isActive,
      );
}
