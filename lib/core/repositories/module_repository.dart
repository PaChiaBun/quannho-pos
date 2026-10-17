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
  ModuleConfig(id: 'report',        label: 'Báo cáo',            icon: '📊', position: 1,  isActive: true),
  ModuleConfig(id: 'finance',       label: 'Thu Chi',            icon: '💰', position: 2,  isActive: true),
  ModuleConfig(id: 'kho',           label: 'Kho hàng',           icon: '📦', position: 3,  isActive: true),
  ModuleConfig(id: 'table',         label: 'Quản lý Bàn',        icon: '🪑', position: 4,  isActive: false),
  ModuleConfig(id: 'kitchen',       label: 'Bếp',                icon: '🔥', position: 5,  isActive: false),
  ModuleConfig(id: 'bill_printer',  label: 'In Hoá Đơn',         icon: '🖨️', position: 6,  isActive: false),
  ModuleConfig(id: 'kho_pro',       label: 'Kho Chuyên Nghiệp',  icon: '🍽️', position: 7,  isActive: false),
  ModuleConfig(id: 'loyalty',       label: 'Khách hàng',         icon: '🏆', position: 8,  isActive: false),
  ModuleConfig(id: 'staff',         label: 'Nhân viên',          icon: '👥', position: 9,  isActive: false),
  ModuleConfig(id: 'chamcong',      label: 'Chấm công',          icon: '🖐️', position: 10, isActive: false),
  ModuleConfig(id: 'tinhluong',     label: 'Lương',              icon: '💵', position: 11, isActive: false),
  ModuleConfig(id: 'kay_ops',       label: 'Vận Hành',           icon: '📋', position: 12, isActive: false),
  ModuleConfig(id: 'log_viewer',    label: 'Nhật Ký Log',        icon: '📝', position: 13, isActive: false),
  ModuleConfig(id: 'qr_order',      label: 'QR Gọi Món',         icon: '📱', position: 14, isActive: false),
  ModuleConfig(id: 'chain',         label: 'Báo cáo chuỗi',      icon: '🏬', position: 15, isActive: false),
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
    // Default: chỉ bật các module mặc định ban đầu
    return _kAllModules.where((m) => m.isActive).map((m) => m.id).toList();
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
    var activeIds = await _fetchActiveIds(storeId);
    if (activeIds == null) {
      final all = await getAll();
      activeIds = all.where((m) => m.isActive).map((m) => m.id).toList();
    }
    if (!activeIds.contains(moduleId)) {
      activeIds.add(moduleId);
      await _saveActiveIds(storeId, activeIds);
    }
  }

  Future<void> deactivate(String moduleId) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    var activeIds = await _fetchActiveIds(storeId);
    if (activeIds == null) {
      final all = await getAll();
      activeIds = all.where((m) => m.isActive).map((m) => m.id).toList();
    }
    if (activeIds.contains(moduleId)) {
      activeIds.remove(moduleId);
      await _saveActiveIds(storeId, activeIds);
    }
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
  final String? _storeIdOverride;

  AppSettingsRepository([this._storeIdOverride]);

  Future<String?> _storeId() async {
    if (_storeIdOverride != null && _storeIdOverride!.isNotEmpty) {
      return _storeIdOverride;
    }
    final info = await StoreAuthService.getStoreInfo();
    final sid = info['store_id'];
    if (sid != null && sid.isNotEmpty) return sid;
    try {
      final headerStoreId = _sb.rest.headers['x-store-id'];
      if (headerStoreId != null && headerStoreId.isNotEmpty) {
        return headerStoreId;
      }
    } catch (_) {}
    return null;
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
    if (val == null) return defaultValue;
    return double.tryParse(val.replaceAll(',', '.')) ?? defaultValue;
  }

  Future<String>  get shopName       => getOrDefault('shop_name', 'Quán Nhỏ');
  Future<String>  get shopPhone      => getOrDefault('shop_phone', '');
  Future<String>  get shopAddress    => getOrDefault('shop_address', '');
  Future<String>  get billFooter     => getOrDefault('bill_footer', 'Cảm ơn quý khách!');
  Future<bool>    get receiptEnabled => getBool('receipt_enabled');
  Future<double>  get taxRate        => getDouble('tax_rate');
  Future<double>  get loyaltyRate    => getDouble('loyalty_rate', defaultValue: 10000);

  // Cấu hình định vị chấm công
  Future<double?> get attendanceLat async {
    final val = await get('attendance_latitude');
    if (val == null) return null;
    final d = double.tryParse(val.replaceAll(',', '.'));
    return (d != null && d.isFinite && d >= -90 && d <= 90) ? d : null;
  }
  Future<double?> get attendanceLng async {
    final val = await get('attendance_longitude');
    if (val == null) return null;
    final d = double.tryParse(val.replaceAll(',', '.'));
    return (d != null && d.isFinite && d >= -180 && d <= 180) ? d : null;
  }
  Future<String?> get attendanceAddress => get('attendance_address');
  Future<double>  get attendanceRadius async {
    final r = await getDouble('attendance_radius', defaultValue: 200.0);
    return (r.isFinite && r > 0) ? r : 200.0;
  }

  /// Lấy toàn bộ cấu hình định vị của quán trong 1 query tối ưu
  Future<AttendanceConfig> getAttendanceConfig() async {
    final storeId = await _storeId();
    if (storeId == null || storeId.isEmpty) return const AttendanceConfig();
    try {
      final rows = await _sb
          .from('app_settings')
          .select('key, value')
          .eq('store_id', storeId)
          .inFilter('key', [
            'attendance_latitude',
            'attendance_longitude',
            'attendance_address',
            'attendance_radius',
          ]);
      double? lat;
      double? lng;
      String? address;
      double radius = 200.0;
      for (final r in rows as List) {
        final k = r['key'] as String?;
        final v = r['value'] as String?;
        if (v == null) continue;
        if (k == 'attendance_latitude') {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null && parsed.isFinite && parsed >= -90 && parsed <= 90) {
            lat = parsed;
          }
        }
        if (k == 'attendance_longitude') {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null && parsed.isFinite && parsed >= -180 && parsed <= 180) {
            lng = parsed;
          }
        }
        if (k == 'attendance_address') address = v;
        if (k == 'attendance_radius') {
          final parsed = double.tryParse(v.replaceAll(',', '.'));
          if (parsed != null && parsed.isFinite && parsed > 0) {
            radius = parsed;
          }
        }
      }
      return AttendanceConfig(lat: lat, lng: lng, address: address, radius: radius);
    } catch (e) {
      debugPrint('[AppSettingsRepository] getAttendanceConfig error: $e');
      try {
        final lat = await attendanceLat;
        final lng = await attendanceLng;
        final address = await attendanceAddress;
        final radius = await attendanceRadius;
        return AttendanceConfig(lat: lat, lng: lng, address: address, radius: radius);
      } catch (_) {
        return const AttendanceConfig();
      }
    }
  }

  /// Lưu cấu hình định vị đồng bộ lên bảng `app_settings` theo `store_id`
  Future<void> saveAttendanceConfig({
    required double lat,
    required double lng,
    required String address,
    required double radius,
  }) async {
    final storeId = await _storeId();
    if (storeId == null || storeId.isEmpty) {
      throw Exception('Không xác định được mã cửa hàng (store_id) để lưu cấu hình.');
    }
    if (!lat.isFinite || lat < -90 || lat > 90) {
      throw ArgumentError('Vĩ độ không hợp lệ (-90 đến 90): $lat');
    }
    if (!lng.isFinite || lng < -180 || lng > 180) {
      throw ArgumentError('Kinh độ không hợp lệ (-180 đến 180): $lng');
    }
    if (!radius.isFinite || radius <= 0) {
      throw ArgumentError('Bán kính cho phép phải là số lớn hơn 0 mét: $radius');
    }
    final items = [
      {
        'id': _uuid.v4(),
        'store_id': storeId,
        'key': 'attendance_latitude',
        'value': lat.toString(),
      },
      {
        'id': _uuid.v4(),
        'store_id': storeId,
        'key': 'attendance_longitude',
        'value': lng.toString(),
      },
      {
        'id': _uuid.v4(),
        'store_id': storeId,
        'key': 'attendance_address',
        'value': address,
      },
      {
        'id': _uuid.v4(),
        'store_id': storeId,
        'key': 'attendance_radius',
        'value': radius.toString(),
      },
    ];
    await _sb.from('app_settings').upsert(items, onConflict: 'store_id,key');
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASS: ATTENDANCE CONFIG
// ─────────────────────────────────────────────────────────────────────────────
class AttendanceConfig {
  final double? lat;
  final double? lng;
  final String? address;
  final double radius;

  const AttendanceConfig({
    this.lat,
    this.lng,
    this.address,
    this.radius = 200.0,
  });

  bool get hasLocation =>
      lat != null && lat!.isFinite && lng != null && lng!.isFinite;

  Map<String, dynamic> toMap() => {
    'lat': lat,
    'lng': lng,
    'address': address,
    'radius': radius,
  };
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
