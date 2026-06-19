// lib/core/services/store_auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Store Auth Service — Xác thực thiết bị vào quán qua store_code
// Mỗi thiết bị lưu: store_id, store_code, device_id vào SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Keys lưu vào SharedPreferences
const _kStoreId    = 'store_id';
const _kStoreCode  = 'store_code';
const _kStoreName  = 'store_name';
const _kDeviceId   = 'device_id';
const _kDeviceRole = 'device_role'; // 'owner' | 'waiter' | 'cashier' | ...

// Keys legacy dùng bởi UserAuthService (chủ quán login flow)
// Fallback để StoreAuthService tương thích cả 2 flow
const _kAuthStoreId   = 'auth_store_id';
const _kAuthStoreCode = 'auth_store_code';
const _kAuthStoreName = 'auth_store_name';
const _kAuthRole      = 'auth_role';

class StoreAuthService {
  static SupabaseClient? get _client {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHECK — Thiết bị đã đăng ký quán chưa?
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> isStoreRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    // Đọc từ cả 2 key (StoreAuthService và UserAuthService)
    final storeId = prefs.getString(_kStoreId) ?? prefs.getString(_kAuthStoreId);
    return storeId != null && storeId.isNotEmpty;
  }

  /// Lấy thông tin quán đã đăng ký
  static Future<Map<String, String?>> getStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    // Fallback: đọc từ UserAuthService keys nếu StoreAuthService keys null
    // UserAuthService dùng 'auth_store_id', StoreAuthService dùng 'store_id'
    final storeId   = prefs.getString(_kStoreId)   ?? prefs.getString(_kAuthStoreId);
    final storeCode = prefs.getString(_kStoreCode) ?? prefs.getString(_kAuthStoreCode);
    final storeName = prefs.getString(_kStoreName) ?? prefs.getString(_kAuthStoreName);
    final role      = prefs.getString(_kDeviceRole) ?? prefs.getString(_kAuthRole);
    return {
      'store_id':    storeId,
      'store_code':  storeCode,
      'store_name':  storeName,
      'device_id':   prefs.getString(_kDeviceId),
      'device_role': role,
    };
  }

  /// Lấy role của thiết bị này ('owner' / 'waiter' / ...)
  static Future<String> getDeviceRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDeviceRole) ?? 'waiter';
  }

  /// Thiết bị này có phải chủ quán không?
  static Future<bool> isOwner() async {
    return (await getDeviceRole()) == 'owner';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // JOIN — Nhân viên nhập mã quán → xác thực → lưu local
  // ─────────────────────────────────────────────────────────────────────────
  static Future<JoinStoreResult> joinStore({
    required String storeCode,
    required String deviceName,  // VD: "Máy phục vụ 1"
    required String deviceRole,  // waiter / cashier / kitchen / manager
  }) async {
    final client = _client;
    if (client == null) {
      return JoinStoreResult.error('Không kết nối được Supabase. Kiểm tra URL và anon key.');
    }

    final code = storeCode.trim().toUpperCase();
    if (code.isEmpty) {
      return JoinStoreResult.error('Vui lòng nhập mã quán.');
    }

    try {
      // 1. Tìm store theo store_code
      final storeRes = await client
          .from('stores')
          .select('id, name, status')
          .eq('store_code', code)
          .maybeSingle();

      if (storeRes == null) {
        return JoinStoreResult.error('Mã quán "$code" không tồn tại.\nKiểm tra lại hoặc liên hệ chủ quán.');
      }

      final status = storeRes['status'] as String;
      if (status == 'suspended' || status == 'deleted') {
        return JoinStoreResult.error('Quán này đã bị khoá. Liên hệ hỗ trợ.');
      }

      final storeId   = storeRes['id']   as String;
      final storeName = storeRes['name'] as String;

      // 2. Đăng ký thiết bị này vào store
      final deviceRes = await client
          .from('devices')
          .insert({
            'store_id':    storeId,
            'device_name': deviceName,
            'device_role': deviceRole,
          })
          .select('id')
          .single();

      final deviceId = deviceRes['id'] as String;

      // 3. Lưu vào SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStoreId,    storeId);
      await prefs.setString(_kStoreCode,  code);
      await prefs.setString(_kStoreName,  storeName);
      await prefs.setString(_kDeviceId,   deviceId);
      await prefs.setString(_kDeviceRole, deviceRole); // lưu role để check offline

      // 4. Cập nhật last_active_at của store
      await client.from('stores').update({
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', storeId);

      return JoinStoreResult.success(
        storeId:   storeId,
        storeName: storeName,
        deviceId:  deviceId,
      );
    } on PostgrestException catch (e) {
      return JoinStoreResult.error('Lỗi kết nối: ${e.message}');
    } catch (e) {
      return JoinStoreResult.error('Lỗi không xác định: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CREATE — Tạo quán mới (lần đầu setup — chủ quán)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<CreateStoreResult> createStore({
    required String storeName,
  }) async {
    final client = _client;
    if (client == null) {
      return CreateStoreResult.error('Không kết nối được Supabase.');
    }

    try {
      // Tạo mã quán ngẫu nhiên VD: QN-A3F7
      final code = _generateStoreCode();

      final res = await client
          .from('stores')
          .insert({
            'store_code': code,
            'name':       storeName.trim(),
            'status':     'trial',
          })
          .select('id, store_code')
          .single();

      final storeId   = res['id']         as String;
      final storeCode = res['store_code'] as String;

      // Đăng ký thiết bị này là máy chủ (owner)
      final deviceRes = await client
          .from('devices')
          .insert({
            'store_id':    storeId,
            'device_name': 'Máy chủ quán',
            'device_role': 'owner',
          })
          .select('id')
          .single();

      final deviceId = deviceRes['id'] as String;

      // Lưu local
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStoreId,    storeId);
      await prefs.setString(_kStoreCode,  storeCode);
      await prefs.setString(_kStoreName,  storeName.trim());
      await prefs.setString(_kDeviceId,   deviceId);
      await prefs.setString(_kDeviceRole, 'owner'); // chủ quán luôn là owner

      // Seed dữ liệu mặc định — silent fail, không block tạo quán
      await seedDefaults(client, storeId);

      return CreateStoreResult.success(
        storeId:   storeId,
        storeCode: storeCode,
      );
    } on PostgrestException catch (e) {
      return CreateStoreResult.error('Lỗi: ${e.message}');
    } catch (e) {
      return CreateStoreResult.error('Lỗi không xác định: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEED DEFAULTS — Public: cũng gọi từ UserAuthService.createStore()
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> seedDefaults(SupabaseClient client, String storeId) async {
    try {
      // 1. finance_categories mặc định
      final cats = [
        // Thu
        {'name': 'Doanh thu bán hàng', 'type': 'income',  'icon': '🛒', 'is_system': true},
        {'name': 'Thu khác',            'type': 'income',  'icon': '💰', 'is_system': false},
        // Chi
        {'name': 'Nhập hàng',          'type': 'expense', 'icon': '📦', 'is_system': true},
        {'name': 'Điện - Nước',        'type': 'expense', 'icon': '💡', 'is_system': false},
        {'name': 'Thuê mặt bằng',      'type': 'expense', 'icon': '🏠', 'is_system': false},
        {'name': 'Lương nhân viên',     'type': 'expense', 'icon': '👷', 'is_system': false},
        {'name': 'Marketing',           'type': 'expense', 'icon': '📣', 'is_system': false},
        {'name': 'Chi khác',            'type': 'expense', 'icon': '💸', 'is_system': false},
      ];
      for (final cat in cats) {
        await client.from('finance_categories').insert({
          ...cat, 'store_id': storeId,
        });
      }
    } catch (_) {}

    try {
      // 2. app_settings mặc định
      final defaults = {
        'loyalty_rate': '10000',   // 10.000đ = 1 điểm
        'receipt_enabled': 'false',
        'tax_rate': '0',
      };
      for (final entry in defaults.entries) {
        await client.from('app_settings').upsert({
          'store_id': storeId,
          'key':      entry.key,
          'value':    entry.value,
        }, onConflict: 'store_id,key');
      }
    } catch (_) {}

    try {
      // 3. store_roles mặc định
      final roles = [
        {
          'name': 'Thu ngân',
          'icon': 'point_of_sale',
          'color': '#1E40AF',
          'modules': '["pos","ban","report"]',
        },
        {
          'name': 'Nhân viên',
          'icon': 'person',
          'color': '#065F46',
          'modules': '["ban"]',
        },
        {
          'name': 'Bếp',
          'icon': 'kitchen',
          'color': '#92400E',
          'modules': '["kitchen","ban"]',
        },
      ];
      for (final role in roles) {
        await client.from('store_roles').insert({
          ...role, 'store_id': storeId,
        });
      }
    } catch (_) {}
  }


  // ─────────────────────────────────────────────────────────────────────────
  // PING — Cập nhật last_active khi app mở
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> pingActive() async {
    final client = _client;
    if (client == null) return;
    final prefs = await SharedPreferences.getInstance();
    final storeId = prefs.getString(_kStoreId);
    final deviceId = prefs.getString(_kDeviceId);
    if (storeId == null) return;
    try {
      await client.from('stores').update({
        'last_active_at': DateTime.now().toIso8601String(),
      }).eq('id', storeId);
      if (deviceId != null) {
        await client.from('devices').update({
          'last_seen': DateTime.now().toIso8601String(),
        }).eq('id', deviceId);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RESET — Xoá đăng ký thiết bị (reset máy)
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> resetDevice() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStoreId);
    await prefs.remove(_kStoreCode);
    await prefs.remove(_kStoreName);
    await prefs.remove(_kDeviceId);
    await prefs.remove(_kDeviceRole);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — Tạo mã quán ngẫu nhiên VD: QN-A3F7
  // ─────────────────────────────────────────────────────────────────────────
  static String _generateStoreCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // loại I, O, 0, 1 tránh nhầm
    final rng = Random.secure();
    final suffix = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'QN-$suffix';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT TYPES
// ─────────────────────────────────────────────────────────────────────────────
class JoinStoreResult {
  final bool   isSuccess;
  final String? storeId;
  final String? storeName;
  final String? deviceId;
  final String? errorMessage;

  const JoinStoreResult._({
    required this.isSuccess,
    this.storeId,
    this.storeName,
    this.deviceId,
    this.errorMessage,
  });

  factory JoinStoreResult.success({
    required String storeId,
    required String storeName,
    required String deviceId,
  }) => JoinStoreResult._(
    isSuccess: true,
    storeId:   storeId,
    storeName: storeName,
    deviceId:  deviceId,
  );

  factory JoinStoreResult.error(String message) =>
      JoinStoreResult._(isSuccess: false, errorMessage: message);
}

class CreateStoreResult {
  final bool   isSuccess;
  final String? storeId;
  final String? storeCode;
  final String? errorMessage;

  const CreateStoreResult._({
    required this.isSuccess,
    this.storeId,
    this.storeCode,
    this.errorMessage,
  });

  factory CreateStoreResult.success({
    required String storeId,
    required String storeCode,
  }) => CreateStoreResult._(
    isSuccess: true,
    storeId:   storeId,
    storeCode: storeCode,
  );

  factory CreateStoreResult.error(String message) =>
      CreateStoreResult._(isSuccess: false, errorMessage: message);
}
