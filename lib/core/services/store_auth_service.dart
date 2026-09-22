// lib/core/services/store_auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Store Auth Service — Xác thực thiết bị vào quán qua store_code
// Mỗi thiết bị lưu: store_id, store_code, device_id vào SharedPreferences
// ─────────────────────────────────────────────────────────────────────────────
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Keys lưu vào SharedPreferences
const _kStoreId = 'store_id';
const _kStoreCode = 'store_code';
const _kStoreName = 'store_name';
const _kDeviceId = 'device_id';
const _kDeviceRole = 'device_role'; // 'owner' | 'waiter' | 'cashier' | ...

// Keys legacy dùng bởi UserAuthService (chủ quán login flow)
// Fallback để StoreAuthService tương thích cả 2 flow
const _kAuthStoreId = 'auth_store_id';
const _kAuthStoreCode = 'auth_store_code';
const _kAuthStoreName = 'auth_store_name';
const _kAuthRole = 'auth_role';

class StoreAuthService {
  static SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CHECK — Thiết bị đã đăng ký quán chưa?
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> isStoreRegistered() async {
    final prefs = await SharedPreferences.getInstance();
    // Đọc từ cả 2 key (StoreAuthService và UserAuthService)
    final storeId =
        prefs.getString(_kStoreId) ?? prefs.getString(_kAuthStoreId);
    return storeId != null && storeId.isNotEmpty;
  }

  static Future<Map<String, String?>> getStoreInfo() async {
    final prefs = await SharedPreferences.getInstance();
    // Prioritize active user session store key ('auth_store_id') over legacy device-based key ('store_id')
    final storeId =
        prefs.getString(_kAuthStoreId) ?? prefs.getString(_kStoreId);
    final storeCode =
        prefs.getString(_kAuthStoreCode) ?? prefs.getString(_kStoreCode);
    final storeName =
        prefs.getString(_kAuthStoreName) ?? prefs.getString(_kStoreName);
    final role = prefs.getString(_kAuthRole) ?? prefs.getString(_kDeviceRole);
    return {
      'store_id': storeId,
      'store_code': storeCode,
      'store_name': storeName,
      'device_id': prefs.getString(_kDeviceId),
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
    required String deviceName, // VD: "Máy phục vụ 1"
    required String deviceRole, // waiter / cashier / kitchen / manager
  }) async {
    // Legacy onboarding allowed a client to choose its own privileged role and
    // insert directly into `devices`. Keep this path fail-closed until a
    // catalog-compatible, server-authorized pairing RPC is available.
    return JoinStoreResult.error(
      'Luồng kết nối thiết bị cũ đã được khóa để bảo mật. '
      'Nhân viên cần đăng nhập tài khoản hiện hành rồi nhập mã quán.',
    );
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
      final rpcRes = await client.rpc(
        'create_store_with_owner_v4',
        params: {'p_store_name': storeName.trim()},
      );
      if (rpcRes is! Map) {
        return CreateStoreResult.error(
          'Dịch vụ tạo quán an toàn chưa sẵn sàng.',
        );
      }
      if (rpcRes['success'] != true) {
        return CreateStoreResult.error(
          rpcRes['message'] as String? ?? 'Không thể tạo quán.',
        );
      }
      final storeId = rpcRes['store_id'] as String;
      final storeCode = rpcRes['store_code'] as String;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kStoreId, storeId);
      await prefs.setString(_kStoreCode, storeCode);
      await prefs.setString(_kStoreName, storeName.trim());
      await prefs.setString(_kDeviceRole, 'owner');
      await seedDefaults(client, storeId);
      return CreateStoreResult.success(storeId: storeId, storeCode: storeCode);
    } on PostgrestException catch (e) {
      return CreateStoreResult.error('Lỗi: ${e.message}');
    } catch (e) {
      return CreateStoreResult.error('Lỗi không xác định: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEED DEFAULTS — Public: cũng gọi từ UserAuthService.createStore()
  // ─────────────────────────────────────────────────────────────────────────
  static Future<void> seedDefaults(
    SupabaseClient client,
    String storeId,
  ) async {
    try {
      // 1. finance_categories mặc định
      final cats = [
        // Thu
        {
          'name': 'Doanh thu bán hàng',
          'type': 'income',
          'icon': '🛒',
          'is_system': true,
        },
        {
          'name': 'Thu khác',
          'type': 'income',
          'icon': '💰',
          'is_system': false,
        },
        // Chi
        {
          'name': 'Nhập hàng',
          'type': 'expense',
          'icon': '📦',
          'is_system': true,
        },
        {
          'name': 'Điện - Nước',
          'type': 'expense',
          'icon': '💡',
          'is_system': false,
        },
        {
          'name': 'Thuê mặt bằng',
          'type': 'expense',
          'icon': '🏠',
          'is_system': false,
        },
        {
          'name': 'Lương nhân viên',
          'type': 'expense',
          'icon': '👷',
          'is_system': false,
        },
        {
          'name': 'Marketing',
          'type': 'expense',
          'icon': '📣',
          'is_system': false,
        },
        {
          'name': 'Chi khác',
          'type': 'expense',
          'icon': '💸',
          'is_system': false,
        },
      ];
      for (final cat in cats) {
        await client.from('finance_categories').insert({
          ...cat,
          'store_id': storeId,
        });
      }
    } catch (_) {}

    try {
      // 2. app_settings mặc định
      final defaults = {
        'loyalty_rate': '10000', // 10.000đ = 1 điểm
        'receipt_enabled': 'false',
        'tax_rate': '0',
      };
      for (final entry in defaults.entries) {
        await client.from('app_settings').upsert({
          'store_id': storeId,
          'key': entry.key,
          'value': entry.value,
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
        await client.from('store_roles').insert({...role, 'store_id': storeId});
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
      await client
          .from('stores')
          .update({'last_active_at': DateTime.now().toIso8601String()})
          .eq('id', storeId);
      if (deviceId != null) {
        await client
            .from('devices')
            .update({'last_seen': DateTime.now().toIso8601String()})
            .eq('id', deviceId);
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
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT TYPES
// ─────────────────────────────────────────────────────────────────────────────
class JoinStoreResult {
  final bool isSuccess;
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
    storeId: storeId,
    storeName: storeName,
    deviceId: deviceId,
  );

  factory JoinStoreResult.error(String message) =>
      JoinStoreResult._(isSuccess: false, errorMessage: message);
}

class CreateStoreResult {
  final bool isSuccess;
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
    storeId: storeId,
    storeCode: storeCode,
  );

  factory CreateStoreResult.error(String message) =>
      CreateStoreResult._(isSuccess: false, errorMessage: message);
}
