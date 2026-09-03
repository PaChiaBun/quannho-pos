// lib/core/services/user_auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// User Auth Service — Đăng ký / Đăng nhập bằng SĐT + Mật khẩu
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'store_auth_service.dart' show StoreAuthService;
import '../utils/app_logger.dart';
import 'pos_jwt_auth_service.dart';
import '../../features/ai_assistant/services/feedback_service.dart';

// ── Session keys ──────────────────────────────────────────────────────────────
const _kUserId = 'auth_user_id';
const _kUserPhone = 'auth_user_phone';
const _kUserName = 'auth_user_name';
const _kStoreId = 'auth_store_id';
const _kStoreName = 'auth_store_name';
const _kStoreCode = 'auth_store_code';
const _kRole = 'auth_role';
const _kIsOwner = 'auth_is_owner';

// ── Reviewer Account Compile Gate ─────────────────────────────────────────────
const bool kEnableReviewerAccount = bool.fromEnvironment(
  'ENABLE_REVIEWER_ACCOUNT',
  defaultValue: false,
);

class UserAuthException implements Exception {
  final String message;
  const UserAuthException(this.message);

  @override
  String toString() => 'UserAuthException: $message';
}

abstract class StoreMembershipRepository {
  Future<void> upsertMembership(Map<String, dynamic> payload);
  Future<List<Map<String, dynamic>>> fetchUserMemberships(String userId);
}

class SupabaseStoreMembershipRepository implements StoreMembershipRepository {
  final SupabaseClient? _client;

  SupabaseStoreMembershipRepository({SupabaseClient? client})
    : _client = client;

  SupabaseClient get client => _client ?? Supabase.instance.client;

  @override
  Future<void> upsertMembership(Map<String, dynamic> payload) async {
    try {
      await client
          .from('store_members')
          .upsert(payload, onConflict: 'user_id,store_id');
    } catch (_) {
      final userId = payload['user_id'] as String;
      final storeId = payload['store_id'] as String;
      final existing = await client
          .from('store_members')
          .select('id')
          .eq('user_id', userId)
          .eq('store_id', storeId)
          .maybeSingle();

      if (existing != null) {
        await client
            .from('store_members')
            .update(payload)
            .eq('id', existing['id'] as String);
      } else {
        await client.from('store_members').insert(payload);
      }
    }
  }

  @override
  Future<List<Map<String, dynamic>>> fetchUserMemberships(String userId) async {
    final List<dynamic> res = await client
        .from('store_members')
        .select()
        .eq('user_id', userId);
    return res.cast<Map<String, dynamic>>();
  }
}

/// Service/Repository chịu trách nhiệm tạo và cập nhật store_members an toàn đa quán.
class StoreMembershipWriter {
  final StoreMembershipRepository repository;

  StoreMembershipWriter({StoreMembershipRepository? repository})
    : repository = repository ?? SupabaseStoreMembershipRepository();

  /// Thêm hoặc cập nhật membership trong `store_members` mà KHÔNG dùng 'id': userId.
  /// Omit `id` để Supabase tự sinh UUID duy nhất cho từng membership của từng quán.
  static Future<void> upsertMembership(
    SupabaseClient db, {
    required String userId,
    required String storeId,
    required String role,
    bool isOwner = false,
    String? modules,
    String? actions,
  }) async {
    final writer = StoreMembershipWriter(
      repository: SupabaseStoreMembershipRepository(client: db),
    );
    await writer.upsert(
      userId: userId,
      storeId: storeId,
      role: role,
      isOwner: isOwner,
      modules: modules,
      actions: actions,
    );
  }

  Future<void> upsert({
    required String userId,
    required String storeId,
    required String role,
    bool isOwner = false,
    String? modules,
    String? actions,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'store_id': storeId,
      'role': role,
      'is_owner': isOwner,
    };
    if (modules != null) payload['modules'] = modules;
    if (actions != null) payload['actions'] = actions;

    await repository.upsertMembership(payload);
  }
}

abstract class UserAuthRepository {
  Future<List<Map<String, dynamic>>> queryStaffMembers(String userId);
  Future<List<Map<String, dynamic>>> queryStoreMembers(String userId);
  Future<Map<String, dynamic>?> queryStoreById(String storeId);
  Future<Map<String, dynamic>?> queryStoreByCode(String storeCode);
  Future<Map<String, dynamic>> insertStore(Map<String, dynamic> storePayload);
  Future<void> upsertStoreMember(Map<String, dynamic> memberPayload);
  Future<List<Map<String, dynamic>>> queryStoresByOwner(String userId) async =>
      [];

  Future<Map<String, dynamic>?> queryStoreMember(
    String storeId,
    String userId,
  ) async => null;
  Future<Map<String, dynamic>?> queryStaffMember(
    String storeId,
    String userId,
  ) async => null;
  Future<Map<String, dynamic>?> queryStaffMemberSimple(String userId) async =>
      null;
  Future<Map<String, dynamic>?> queryUserAccount(String userId) async => null;
  Future<void> upsertStaffMember(Map<String, dynamic> payload) async {}
}

class SupabaseUserAuthRepository implements UserAuthRepository {
  final SupabaseClient? client;
  SupabaseUserAuthRepository({this.client});

  SupabaseClient get _db => client ?? Supabase.instance.client;

  @override
  Future<List<Map<String, dynamic>>> queryStaffMembers(String userId) async {
    final res = await _db
        .from('staff_members')
        .select('role, store_id, stores(id, name, store_code)')
        .eq('id', userId);
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<List<Map<String, dynamic>>> queryStoreMembers(String userId) async {
    final res = await _db
        .from('store_members')
        .select('role, is_owner, store_id, stores(id, name, store_code)')
        .eq('user_id', userId);
    return List<Map<String, dynamic>>.from(res);
  }

  @override
  Future<List<Map<String, dynamic>>> queryStoresByOwner(String userId) async {
    try {
      final res = await _db
          .from('stores')
          .select('id, name, store_code')
          .eq('owner_user_id', userId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('[queryStoresByOwner] error: $e');
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> queryStoreById(String storeId) async {
    final res = await _db
        .from('stores')
        .select('id, name, store_code, owner_user_id')
        .eq('id', storeId)
        .maybeSingle();
    return res;
  }

  @override
  Future<Map<String, dynamic>?> queryStoreByCode(String storeCode) async {
    final res = await _db
        .from('stores')
        .select('id, name, status, store_code')
        .eq('store_code', storeCode)
        .maybeSingle();
    return res;
  }

  @override
  Future<Map<String, dynamic>> insertStore(
    Map<String, dynamic> storePayload,
  ) async {
    final res = await _db
        .from('stores')
        .insert(storePayload)
        .select('id, store_code, name')
        .single();
    return res;
  }

  @override
  Future<void> upsertStoreMember(Map<String, dynamic> memberPayload) async {
    await _db
        .from('store_members')
        .upsert(memberPayload, onConflict: 'user_id,store_id');
  }

  @override
  Future<Map<String, dynamic>?> queryStoreMember(
    String storeId,
    String userId,
  ) async {
    return await _db
        .from('store_members')
        .select('role, is_owner')
        .eq('store_id', storeId)
        .eq('user_id', userId)
        .maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> queryStaffMember(
    String storeId,
    String userId,
  ) async {
    return await _db
        .from('staff_members')
        .select('role')
        .eq('store_id', storeId)
        .eq('id', userId)
        .maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> queryStaffMemberSimple(String userId) async {
    return await _db
        .from('staff_members')
        .select('store_id')
        .eq('id', userId)
        .maybeSingle();
  }

  @override
  Future<Map<String, dynamic>?> queryUserAccount(String userId) async {
    return await _db
        .from('user_accounts')
        .select('display_name, phone')
        .eq('id', userId)
        .maybeSingle();
  }

  @override
  Future<void> upsertStaffMember(Map<String, dynamic> payload) async {
    await _db.from('staff_members').upsert(payload);
  }
}

class UserAuthService {
  static UserAuthRepository authRepository = SupabaseUserAuthRepository();
  static StoreMembershipWriter membershipWriter = StoreMembershipWriter();

  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── FORMAT phone → chuẩn hoá ────────────────────────────────────────────────
  static String _normalizePhone(String phone) {
    var p = phone.trim().replaceAll(RegExp(r'\s|-|\(|\)'), '');
    if (p.startsWith('0')) p = '+84${p.substring(1)}';
    return p;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ĐĂNG KÝ
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<AuthResult> register({
    required String phone,
    required String password,
    required String displayName,
    PosJwtAuthService? jwtService,
  }) async {
    final posJwtService = jwtService ?? PosJwtAuthService();
    posJwtService.clearActiveOnboardingJwt();
    final db = _db;
    if (db == null) return AuthResult.error('Không kết nối được server.');

    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isEmpty || normalizedPhone.length < 8) {
      return AuthResult.error('Số điện thoại không hợp lệ.');
    }
    if (password.length < 8) {
      return AuthResult.error('Mật khẩu phải từ 8 ký tự trở lên.');
    }
    if (displayName.trim().isEmpty) {
      return AuthResult.error('Vui lòng nhập tên của bạn.');
    }

    try {
      final rpcRes = await db.rpc(
        'register_user_account_v4',
        params: {
          'p_phone': normalizedPhone,
          'p_password': password,
          'p_display_name': displayName.trim(),
        },
      );
      if (rpcRes is! Map) {
        return AuthResult.error(
          'Dịch vụ đăng ký an toàn chưa sẵn sàng. Vui lòng thử lại sau.',
        );
      }

      final map = Map<String, dynamic>.from(rpcRes);
      if (map['success'] != true) {
        return AuthResult.error(
          map['message'] as String? ?? 'Đăng ký tài khoản không thành công.',
        );
      }

      final userId = map['user_id'] as String;
      final phoneStr = (map['phone'] as String?) ?? normalizedPhone;
      final nameStr = (map['display_name'] as String?) ?? displayName.trim();

      if (!posJwtService.isConfigured) {
        return AuthResult.error(
          'Tài khoản đã được tạo nhưng máy chủ phiên an toàn chưa được cấu hình. '
          'Vui lòng đăng nhập lại sau khi hệ thống sẵn sàng.',
        );
      }
      final onbRes = await posJwtService.requestOnboardingJwt(
        phone: normalizedPhone,
        password: password,
      );
      if (onbRes['success'] != true ||
          posJwtService.activeOnboardingJwtFor(userId) == null) {
        return AuthResult.error(
          onbRes['message'] as String? ??
              'Tài khoản đã được tạo nhưng không thể mở phiên an toàn. '
                  'Vui lòng đăng nhập lại.',
        );
      }

      await _saveSession(userId: userId, phone: phoneStr, name: nameStr);
      return AuthResult.success(
        userId: userId,
        phone: phoneStr,
        displayName: nameStr,
        stores: [],
      );
    } catch (e) {
      debugPrint('[UserAuthService.register] secure RPC unavailable: $e');
      return AuthResult.error(
        'Dịch vụ đăng ký an toàn chưa sẵn sàng. Vui lòng thử lại sau.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ĐĂNG NHẬP
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<AuthResult> login({
    required String phone,
    required String password,
    PosJwtAuthService? jwtService,
  }) async {
    final normalizedPhone = _normalizePhone(phone);
    final posJwtService = jwtService ?? PosJwtAuthService();
    posJwtService.clearActiveOnboardingJwt();

    // ── FALLBACK CHO GOOGLE PLAY & APP STORE REVIEW (COMPILE-GATED) ─────────────
    // Chỉ kích hoạt khi build chủ động với --dart-define=ENABLE_REVIEWER_ACCOUNT=true.
    // Debug mode đơn thuần không được tự mở một owner session.
    if (kEnableReviewerAccount) {
      final rawP = phone.trim().replaceAll(RegExp(r'\s|-|\(|\)'), '');
      final isReviewerPhone =
          (normalizedPhone.contains('9999') &&
              normalizedPhone.endsWith('6666')) ||
          (rawP.contains('9999') && rawP.endsWith('6666')) ||
          normalizedPhone == '+84999996666' ||
          normalizedPhone == '+849999996666' ||
          rawP == '0999996666' ||
          rawP == '09999996666' ||
          rawP == '999996666' ||
          rawP == '9999996666';
      if (isReviewerPhone && password == '112233') {
        final userId = '99999966-6666-6666-6666-999999666666';
        final displayName = 'Quán Nhỏ POS (Demo)';
        final store = StoreMembership(
          storeId: '00000000-0000-0000-0000-000000009999',
          storeName: 'Quán Nhỏ POS (Demo)',
          storeCode: 'DEMO99',
          role: 'owner',
          isOwner: true,
        );
        await _saveFullSession(
          userId: userId,
          phone: normalizedPhone,
          name: displayName,
          membership: store,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'store_id',
          '00000000-0000-0000-0000-000000009999',
        );
        await prefs.setString('store_code', 'DEMO99');
        await prefs.setString('store_name', 'Quán Nhỏ POS (Demo)');
        await prefs.setString('device_role', 'owner');
        return AuthResult.success(
          userId: userId,
          phone: normalizedPhone,
          displayName: displayName,
          stores: [store],
          selectedStore: store,
        );
      }
    }

    final db = _db;
    if (db == null) return AuthResult.error('Không kết nối được server.');

    try {
      final rpcRes = await db.rpc(
        'verify_user_login_v4',
        params: {'p_phone': normalizedPhone, 'p_password': password},
      );
      if (rpcRes is! Map) {
        return AuthResult.error(
          'Dịch vụ đăng nhập an toàn chưa sẵn sàng. Vui lòng thử lại sau.',
        );
      }

      final map = Map<String, dynamic>.from(rpcRes);
      if (map['success'] != true) {
        return AuthResult.error(
          map['message'] as String? ??
              'Số điện thoại hoặc mật khẩu không chính xác.',
        );
      }

      final userId = map['user_id'] as String;
      final displayName = (map['display_name'] as String?) ?? 'Người dùng';
      final phoneStr = (map['phone'] as String?) ?? normalizedPhone;
      final storesRaw = map['stores'] as List<dynamic>? ?? [];
      final stores = <StoreMembership>[
        for (final value in storesRaw)
          if (value is Map)
            StoreMembership(
              storeId: value['store_id'] as String,
              storeName: (value['store_name'] as String?) ?? 'Quán Nhỏ',
              storeCode: (value['store_code'] as String?) ?? '',
              role: (value['role'] as String?) ?? 'cashier',
              isOwner: (value['is_owner'] as bool?) ?? false,
            ),
      ];
      final selectedStore = stores.length == 1 ? stores.first : null;

      if (stores.isEmpty) {
        if (!posJwtService.isConfigured) {
          return AuthResult.error(
            'Máy chủ phiên an toàn chưa được cấu hình. Vui lòng thử lại sau.',
          );
        }
        final onbRes = await posJwtService.requestOnboardingJwt(
          phone: normalizedPhone,
          password: password,
        );
        if (onbRes['success'] != true ||
            posJwtService.activeOnboardingJwtFor(userId) == null) {
          return AuthResult.error(
            onbRes['message'] as String? ??
                'Không thể mở phiên an toàn. Vui lòng đăng nhập lại.',
          );
        }
      }

      if (selectedStore != null && posJwtService.isConfigured) {
        final jwtRes = await posJwtService.requestPosJwt(
          phone: normalizedPhone,
          password: password,
          storeId: selectedStore.storeId,
        );
        if (jwtRes['success'] != true) {
          await posJwtService.clearPosJwt();
          await posJwtService.applyAuthToSupabase(null);
          return AuthResult.error(
            jwtRes['message'] as String? ?? 'Xác thực phiên làm việc thất bại.',
          );
        }
      }

      if (selectedStore != null) {
        await _saveFullSession(
          userId: userId,
          phone: phoneStr,
          name: displayName,
          membership: selectedStore,
        );
      } else {
        await _saveSession(userId: userId, phone: phoneStr, name: displayName);
      }
      return AuthResult.success(
        userId: userId,
        phone: phoneStr,
        displayName: displayName,
        stores: stores,
        selectedStore: selectedStore,
      );
    } catch (e) {
      debugPrint('[UserAuthService.login] secure RPC unavailable: $e');
      return AuthResult.error(
        'Dịch vụ đăng nhập an toàn chưa sẵn sàng. Vui lòng thử lại sau.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KIỂM TRA MEMBERSHIP — Gọi khi staff chưa có quán (được thêm sau khi đăng ký)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<StoreMembership?> fetchStoreMembership(String userId) async {
    final stores = await getUserStores(userId);
    return stores.isNotEmpty ? stores.first : null;
  }

  /// Lấy danh sách tất cả các quán mà tài khoản tham gia.
  /// ‼️ NGUỒN SỰ THẬT DUY NHẤT (Single Source of Truth): store_members
  static Future<List<StoreMembership>> getUserStores(String userId) async {
    List<StoreMembership> list = [];

    try {
      final memberships = await authRepository.queryStoreMembers(userId);

      for (final m in memberships) {
        Map<String, dynamic>? store = m['stores'] as Map<String, dynamic>?;
        final storeId = m['store_id'] as String?;

        if (store == null && storeId != null) {
          try {
            store = await authRepository.queryStoreById(storeId);
          } catch (_) {}
        }

        if (store != null) {
          final sId = store['id'] as String;
          if (!list.any((x) => x.storeId == sId)) {
            list.add(
              StoreMembership(
                storeId: sId,
                storeName: (store['name'] as String?) ?? 'Quán Nhỏ',
                storeCode: (store['store_code'] as String?) ?? '',
                role: (m['role'] as String?) ?? 'cashier',
                isOwner: (m['is_owner'] as bool?) ?? false,
              ),
            );
          }
        }
      }

      // Bổ sung: Tra cứu thêm từ bảng stores nếu user là owner (owner_user_id / owner_id)
      try {
        final ownedStores = await authRepository.queryStoresByOwner(userId);
        for (final store in ownedStores) {
          final sId = store['id'] as String;
          if (!list.any((x) => x.storeId == sId)) {
            list.add(
              StoreMembership(
                storeId: sId,
                storeName: (store['name'] as String?) ?? 'Quán Nhỏ',
                storeCode: (store['store_code'] as String?) ?? '',
                role: 'owner',
                isOwner: true,
              ),
            );
          }
        }
      } catch (_) {}

      return list;
    } catch (e) {
      debugPrint('[getUserStores] Query store_members error: $e');
      throw UserAuthException('Cơ sở dữ liệu lỗi khi tải danh sách quán: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // XOÁ STORE CONTEXT BỀN VỮNG (Persistent Store Context Revocation)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> clearStoreContext() async {
    AppLogger.info('auth', 'Thu hoi store context khoi thiet bi.');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStoreId);
    await prefs.remove(_kStoreName);
    await prefs.remove(_kStoreCode);
    await prefs.remove(_kRole);
    await prefs.remove(_kIsOwner);

    // Xoá cả các key legacy dùng bởi StoreAuthService & repository cũ
    await prefs.remove('store_id');
    await prefs.remove('store_name');
    await prefs.remove('store_code');
    await prefs.remove('device_role');

    try {
      final db = _db;
      if (db != null) {
        db.rest.headers.remove('x-store-id');
      }
    } catch (_) {}
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KIỂM TRA MEMBERSHIP CHỦ ĐỘNG (Proactive Server Membership Validation)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<({bool isActive, bool isOffline})> validateActiveMembership({
    required String userId,
    required String storeId,
    Duration emptyConfirmationDelay = const Duration(milliseconds: 500),
    Duration serverQueryTimeout = const Duration(seconds: 6),
  }) async {
    if (userId.isEmpty || storeId.isEmpty) {
      return (isActive: false, isOffline: false);
    }
    try {
      if (await _hasActiveMembershipOnServer(
        userId: userId,
        storeId: storeId,
      ).timeout(serverQueryTimeout)) {
        return (isActive: true, isOffline: false);
      }

      // Không thu hồi store context chỉ vì một lần đọc rỗng. Ngay sau deploy,
      // resume hoặc reconnect, PostgREST có thể trả kết quả rỗng tạm thời dù
      // membership vẫn tồn tại. Lần đọc thứ hai là xác nhận bắt buộc trước khi
      // caller được phép xoá session local.
      if (emptyConfirmationDelay > Duration.zero) {
        await Future<void>.delayed(emptyConfirmationDelay);
      }
      if (await _hasActiveMembershipOnServer(
        userId: userId,
        storeId: storeId,
      ).timeout(serverQueryTimeout)) {
        return (isActive: true, isOffline: false);
      }

      return (isActive: false, isOffline: false);
    } catch (e) {
      debugPrint('[UserAuthService.validateActiveMembership] error: $e');
      // Khi gặp lỗi mạng/timeout: bảo lưu session local, không tự logout nhầm
      return (isActive: true, isOffline: true);
    }
  }

  static Future<bool> _hasActiveMembershipOnServer({
    required String userId,
    required String storeId,
  }) async {
    final member = await authRepository.queryStoreMember(storeId, userId);
    if (member != null) return true;

    // Chủ quán có thể được xác định trực tiếp từ stores ngay cả khi chưa có
    // row tương ứng trong store_members.
    final store = await authRepository.queryStoreById(storeId);
    return store != null &&
        (store['owner_user_id'] == userId || store['owner_id'] == userId);
  }

  /// Nhân viên gia nhập quán bằng mã storeCode (QN-XXXX)
  static Future<CreateStoreResult> joinStoreByCode({
    required String storeCode,
    required String userId,
    String? onboardingJwt,
    PosJwtAuthService? jwtService,
  }) async {
    final code = storeCode.trim().toUpperCase();
    if (code.isEmpty) {
      return CreateStoreResult.error('Vui lòng nhập mã quán.');
    }

    final posJwtService = jwtService ?? PosJwtAuthService();
    if (!posJwtService.isConfigured) {
      return CreateStoreResult.error(
        'Máy chủ phiên an toàn chưa được cấu hình.',
        errorCode: 'POS_JWT_NOT_CONFIGURED',
      );
    }
    if (onboardingJwt != null) {
      posJwtService.setActiveOnboardingJwt(onboardingJwt);
    }
    final effectiveOnboardingJwt = posJwtService.activeOnboardingJwtFor(userId);
    if (effectiveOnboardingJwt == null) {
      return CreateStoreResult.error(
        'Phiên đăng ký đã hết hạn. Vui lòng đăng nhập lại để tham gia quán.',
        errorCode: 'ONBOARDING_TOKEN_REQUIRED',
      );
    }

    final db = _db;
    if (db == null) {
      return CreateStoreResult.error('Không kết nối được server.');
    }
    try {
      final rpcRes = await db.rpc(
        'join_store_by_code_v4',
        params: {'p_store_code': code},
      );
      if (rpcRes is! Map) {
        return CreateStoreResult.error(
          'Dịch vụ tham gia quán an toàn chưa sẵn sàng.',
        );
      }
      if (rpcRes['success'] != true) {
        return CreateStoreResult.error(
          rpcRes['message'] as String? ?? 'Không thể tham gia quán.',
        );
      }
      final storeId = rpcRes['store_id'] as String;
      final storeCodeResult = rpcRes['store_code'] as String? ?? code;
      final membership = StoreMembership(
        storeId: storeId,
        storeName: rpcRes['store_name'] as String? ?? 'Quán Nhỏ',
        storeCode: storeCodeResult,
        role: rpcRes['role'] as String? ?? 'waiter',
        isOwner: rpcRes['is_owner'] as bool? ?? false,
      );

      final exchangeRes = await posJwtService.exchangeStoreJwt(
        onboardingJwt: effectiveOnboardingJwt,
        storeId: storeId,
      );

      if (exchangeRes['success'] != true) {
        return CreateStoreResult.error(
          exchangeRes['message'] as String? ??
              'Không thể đổi phiên làm việc cho quán.',
          errorCode: exchangeRes['error'] as String? ?? 'EXCHANGE_FAILED',
          storeId: storeId,
          storeCode: storeCodeResult,
          membership: membership,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await _applyMembershipToPrefs(prefs, membership);
      return CreateStoreResult.success(
        storeId: storeId,
        storeCode: storeCodeResult,
        membership: membership,
      );
    } catch (e) {
      debugPrint('[UserAuthService] join_store_by_code_v4 unavailable: $e');
      return CreateStoreResult.error(
        'Dịch vụ tham gia quán an toàn chưa sẵn sàng.',
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TẠO QUÁN MỚI (chủ quán tạo quán mới)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<CreateStoreResult> createStore({
    required String userId,
    required String storeName,
    String? onboardingJwt,
    PosJwtAuthService? jwtService,
  }) async {
    final cleanName = storeName.trim();
    if (cleanName.isEmpty) {
      return CreateStoreResult.error('Vui lòng nhập tên quán.');
    }

    final posJwtService = jwtService ?? PosJwtAuthService();
    if (!posJwtService.isConfigured) {
      return CreateStoreResult.error(
        'Máy chủ phiên an toàn chưa được cấu hình.',
        errorCode: 'POS_JWT_NOT_CONFIGURED',
      );
    }
    if (onboardingJwt != null) {
      posJwtService.setActiveOnboardingJwt(onboardingJwt);
    }
    final effectiveOnboardingJwt = posJwtService.activeOnboardingJwtFor(userId);
    if (effectiveOnboardingJwt == null) {
      return CreateStoreResult.error(
        'Phiên đăng ký đã hết hạn. Vui lòng đăng nhập lại để tạo quán.',
        errorCode: 'ONBOARDING_TOKEN_REQUIRED',
      );
    }

    final db = _db;
    if (db == null) {
      return CreateStoreResult.error('Không kết nối được server.');
    }
    try {
      final rpcRes = await db.rpc(
        'create_store_with_owner_v4',
        params: {'p_store_name': cleanName},
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
      final storeCodeResult = rpcRes['store_code'] as String;
      final membership = StoreMembership(
        storeId: storeId,
        storeName: rpcRes['store_name'] as String? ?? cleanName,
        storeCode: storeCodeResult,
        role: 'owner',
        isOwner: true,
      );

      final exchangeRes = await posJwtService.exchangeStoreJwt(
        onboardingJwt: effectiveOnboardingJwt,
        storeId: storeId,
      );

      if (exchangeRes['success'] != true) {
        return CreateStoreResult.error(
          exchangeRes['message'] as String? ??
              'Không thể đổi phiên làm việc cho quán mới.',
          errorCode: exchangeRes['error'] as String? ?? 'EXCHANGE_FAILED',
          storeId: storeId,
          storeCode: storeCodeResult,
          membership: membership,
        );
      }

      final prefs = await SharedPreferences.getInstance();
      await _applyMembershipToPrefs(prefs, membership);
      await StoreAuthService.seedDefaults(db, storeId);
      return CreateStoreResult.success(
        storeId: storeId,
        storeCode: storeCodeResult,
        membership: membership,
      );
    } catch (e) {
      debugPrint(
        '[UserAuthService] create_store_with_owner_v4 unavailable: $e',
      );
      return CreateStoreResult.error('Dịch vụ tạo quán an toàn chưa sẵn sàng.');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHỌN QUÁN (Password Verification + Optional POS JWT + Atomic Rollback)
  // ═══════════════════════════════════════════════════════════════════════════
  static bool _isStoreSwitching = false;

  static Future<bool> selectStore(
    StoreMembership membership, {
    required String password,
    String? phone,
    PosJwtAuthService? jwtService,
  }) async {
    if (_isStoreSwitching) return false;
    if (password.trim().isEmpty) return false;

    _isStoreSwitching = true;

    String? originalStoreId;
    String? originalStoreName;
    String? originalStoreCode;
    String? originalRole;
    bool? originalIsOwner;
    String? originalToken;
    final posJwtService = jwtService ?? PosJwtAuthService();

    try {
      final prefs = await SharedPreferences.getInstance();
      final effectivePhone = (phone ?? prefs.getString(_kUserPhone) ?? '')
          .trim();
      if (effectivePhone.isEmpty) return false;

      originalStoreId = prefs.getString(_kStoreId);
      originalStoreName = prefs.getString(_kStoreName);
      originalStoreCode = prefs.getString(_kStoreCode);
      originalRole = prefs.getString(_kRole);
      originalIsOwner = prefs.getBool(_kIsOwner);
      if (posJwtService.isConfigured) {
        originalToken = await posJwtService.getStoredPosJwt();

        final jwtRes = await posJwtService.requestPosJwt(
          phone: effectivePhone,
          password: password.trim(),
          storeId: membership.storeId,
        );

        if (jwtRes['success'] != true) {
          await _rollbackSnapshot(
            posJwtService: posJwtService,
            prefs: prefs,
            token: originalToken,
            storeId: originalStoreId,
            storeName: originalStoreName,
            storeCode: originalStoreCode,
            role: originalRole,
            isOwner: originalIsOwner,
          );
          return false;
        }
      } else {
        // Không có POS JWT endpoint: xác minh lại mật khẩu qua luồng Supabase
        // chuẩn trước khi đổi quán, không bỏ qua bước xác thực người dùng.
        final authResult = await login(
          phone: effectivePhone,
          password: password.trim(),
          jwtService: posJwtService,
        );
        final hasMembership = authResult.stores.any(
          (store) => store.storeId == membership.storeId,
        );
        if (!authResult.isSuccess || !hasMembership) {
          await _restoreLegacySnapshot(
            prefs: prefs,
            storeId: originalStoreId,
            storeName: originalStoreName,
            storeCode: originalStoreCode,
            role: originalRole,
            isOwner: originalIsOwner,
          );
          return false;
        }
      }

      await _applyMembershipToPrefs(prefs, membership);
      return true;
    } catch (_) {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (posJwtService.isConfigured) {
          await _rollbackSnapshot(
            posJwtService: posJwtService,
            prefs: prefs,
            token: originalToken,
            storeId: originalStoreId,
            storeName: originalStoreName,
            storeCode: originalStoreCode,
            role: originalRole,
            isOwner: originalIsOwner,
          );
        } else {
          await _restoreLegacySnapshot(
            prefs: prefs,
            storeId: originalStoreId,
            storeName: originalStoreName,
            storeCode: originalStoreCode,
            role: originalRole,
            isOwner: originalIsOwner,
          );
        }
      } catch (_) {}
      return false;
    } finally {
      _isStoreSwitching = false;
    }
  }

  /// Kích hoạt quán ngay sau một lần đăng nhập thành công.
  ///
  /// Luồng này không nhận hoặc lưu lại mật khẩu. Thay vào đó, nó đọc lại danh
  /// sách membership từ Supabase và chỉ áp dụng đúng bản ghi authoritative của
  /// user đang đăng nhập. Đổi quán từ bên trong app vẫn phải dùng [selectStore]
  /// để xác minh lại mật khẩu và giữ nguyên cơ chế rollback fail-closed.
  static Future<StoreMembership?> selectStoreAfterLogin(
    StoreMembership requestedMembership, {
    PosJwtAuthService? jwtService,
  }) async {
    if (_isStoreSwitching) return null;

    final posJwtService = jwtService ?? PosJwtAuthService();

    // POS JWT là token theo từng store. Khi endpoint này được bật, không được
    // bỏ qua bước cấp token bằng mật khẩu cho store đích.
    if (posJwtService.isConfigured) return null;

    _isStoreSwitching = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString(_kUserId);
      if (userId == null || userId.isEmpty) return null;

      // Chỉ dành cho trạng thái vừa đăng nhập nhưng chưa có store active.
      final activeStoreId = prefs.getString(_kStoreId);
      if (activeStoreId != null && activeStoreId.isNotEmpty) return null;

      final authoritativeStores = await getUserStores(userId);
      StoreMembership? authoritativeMembership;
      for (final store in authoritativeStores) {
        if (store.storeId == requestedMembership.storeId) {
          authoritativeMembership = store;
          break;
        }
      }
      if (authoritativeMembership == null) return null;

      await _applyMembershipToPrefs(prefs, authoritativeMembership);
      return authoritativeMembership;
    } catch (e) {
      debugPrint('[selectStoreAfterLogin] membership verification failed: $e');
      return null;
    } finally {
      _isStoreSwitching = false;
    }
  }

  static Future<void> _restoreLegacySnapshot({
    required SharedPreferences prefs,
    required String? storeId,
    required String? storeName,
    required String? storeCode,
    required String? role,
    required bool? isOwner,
  }) async {
    if (storeId != null) {
      await prefs.setString(_kStoreId, storeId);
    } else {
      await prefs.remove(_kStoreId);
    }
    if (storeName != null) {
      await prefs.setString(_kStoreName, storeName);
    } else {
      await prefs.remove(_kStoreName);
    }
    if (storeCode != null) {
      await prefs.setString(_kStoreCode, storeCode);
    } else {
      await prefs.remove(_kStoreCode);
    }
    if (role != null) {
      await prefs.setString(_kRole, role);
    } else {
      await prefs.remove(_kRole);
    }
    if (isOwner != null) {
      await prefs.setBool(_kIsOwner, isOwner);
    } else {
      await prefs.remove(_kIsOwner);
    }
  }

  static Future<void> _rollbackSnapshot({
    required PosJwtAuthService posJwtService,
    required SharedPreferences prefs,
    required String? token,
    required String? storeId,
    required String? storeName,
    required String? storeCode,
    required String? role,
    required bool? isOwner,
  }) async {
    bool restored = false;
    if (token != null && storeId != null) {
      try {
        await posJwtService.storePosJwt(token);
        restored = await posJwtService.applyAuthToSupabase(
          token,
          expectedStoreId: storeId,
        );
      } catch (_) {
        restored = false;
      }
    }

    if (restored) {
      if (storeId != null) await prefs.setString(_kStoreId, storeId);
      if (storeName != null) await prefs.setString(_kStoreName, storeName);
      if (storeCode != null) await prefs.setString(_kStoreCode, storeCode);
      if (role != null) await prefs.setString(_kRole, role);
      if (isOwner != null) await prefs.setBool(_kIsOwner, isOwner);
    } else {
      await posJwtService.clearPosJwt();
      await posJwtService.applyAuthToSupabase(null);
      await prefs.remove(_kStoreId);
      await prefs.remove(_kStoreName);
      await prefs.remove(_kStoreCode);
      await prefs.remove(_kRole);
      await prefs.remove(_kIsOwner);
    }
  }

  static Future<void> updateSameStoreRoleInPrefs(
    StoreMembership membership,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final currentStoreId = prefs.getString(_kStoreId);
    if (currentStoreId == membership.storeId) {
      await prefs.setString(_kRole, membership.role);
      await prefs.setBool(_kIsOwner, membership.isOwner);
    }
  }

  static Future<bool> restoreSessionOnStartup({
    PosJwtAuthService? jwtService,
  }) async {
    final posJwtService = jwtService ?? PosJwtAuthService();
    final session = await getCurrentSession();

    if (!posJwtService.isConfigured) {
      // POS JWT bị tắt: không đụng flutter_secure_storage. Một số Flutter Web
      // release không đăng ký plugin này và sẽ ném MissingPluginException,
      // khiến splash đứng vĩnh viễn trước khi app kịp điều hướng.
      if (session == null) return false;
      if (session.storeId != null && session.storeId!.isNotEmpty) return true;

      // Bản deploy trước có thể đã xoá nhầm store context sau một lần validate
      // rỗng. Nếu server vẫn xác nhận đúng một membership, tự phục hồi toàn bộ
      // auth_store_* và legacy store_* để người dùng không bị kẹt ở CTA tạo quán.
      try {
        final stores = await getUserStores(
          session.userId,
        ).timeout(const Duration(seconds: 8));
        if (stores.length != 1) return false;
        await _saveFullSession(
          userId: session.userId,
          phone: session.phone,
          name: session.displayName,
          membership: stores.single,
        );
        return true;
      } catch (e) {
        debugPrint('[restoreSessionOnStartup] recover store context error: $e');
        return false;
      }
    }

    if (session == null || session.storeId == null) {
      await posJwtService.applyAuthToSupabase(null);
      return false;
    }

    final token = await posJwtService.getStoredPosJwt();
    if (token != null &&
        posJwtService.isTokenValid(token, expectedStoreId: session.storeId)) {
      final applied = await posJwtService.applyAuthToSupabase(
        token,
        expectedStoreId: session.storeId,
      );
      if (applied) {
        return true;
      }
    }

    await posJwtService.clearPosJwt();
    await posJwtService.applyAuthToSupabase(null);
    await clearStoreContext();
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSION
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<SessionData?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId);
    if (userId == null) return null;
    return SessionData(
      userId: userId,
      phone: prefs.getString(_kUserPhone) ?? '',
      displayName: prefs.getString(_kUserName) ?? '',
      storeId: prefs.getString(_kStoreId),
      storeName: prefs.getString(_kStoreName),
      storeCode: prefs.getString(_kStoreCode),
      role: prefs.getString(_kRole) ?? '',
      isOwner: prefs.getBool(_kIsOwner) ?? false,
    );
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserId) != null;
  }

  static Future<void> logout() async {
    AppLogger.info('auth', 'Dang xuat khoi he thong.');
    final prefs = await SharedPreferences.getInstance();
    // UserAuth keys
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserPhone);
    await prefs.remove(_kUserName);
    await prefs.remove(_kStoreId);
    await prefs.remove(_kStoreName);
    await prefs.remove(_kStoreCode);
    await prefs.remove(_kRole);
    await prefs.remove(_kIsOwner);
    // ‼️ FIX Bug #42: xoá cả StoreAuthService prefs để tránh repositories
    // vẫn resolve storeId cũ sau khi logout (inconsistent state)
    await prefs.remove('store_id');
    await prefs.remove('store_code');
    await prefs.remove('store_name');
    await prefs.remove('device_role');

    // Clear POS PostgREST JWT and Supabase REST/Realtime auth
    try {
      final posJwtService = PosJwtAuthService();
      posJwtService.clearActiveOnboardingJwt();
      await posJwtService.clearPosJwt();
      await posJwtService.applyAuthToSupabase(null);
      await FeedbackService().clearSessionToken();
    } catch (e) {
      debugPrint('[UserAuthService] Logout auth cleanup notice: $e');
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  static Future<void> _saveSession({
    required String userId,
    required String phone,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserPhone, phone);
    await prefs.setString(_kUserName, name);
    // Session cơ bản chỉ được dùng khi chưa chọn quán. Xóa store context cũ để
    // không vô tình mang store/role của tài khoản hoặc lần đăng nhập trước sang.
    await prefs.remove(_kStoreId);
    await prefs.remove(_kStoreName);
    await prefs.remove(_kStoreCode);
    await prefs.remove(_kRole);
    await prefs.remove(_kIsOwner);
    await prefs.remove('store_id');
    await prefs.remove('store_name');
    await prefs.remove('store_code');
    await prefs.remove('device_role');
  }

  static Future<void> _saveFullSession({
    required String userId,
    required String phone,
    required String name,
    required StoreMembership membership,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, userId);
    await prefs.setString(_kUserPhone, phone);
    await prefs.setString(_kUserName, name);
    await _applyMembershipToPrefs(prefs, membership);
  }

  static Future<void> _applyMembershipToPrefs(
    SharedPreferences prefs,
    StoreMembership m,
  ) async {
    await prefs.setString(_kStoreId, m.storeId);
    await prefs.setString(_kStoreName, m.storeName);
    await prefs.setString(_kStoreCode, m.storeCode);
    await prefs.setString(_kRole, m.role);
    await prefs.setBool(_kIsOwner, m.isOwner);

    // Đồng bộ sang các key legacy (dùng bởi StoreAuthService & các repository cũ)
    await prefs.setString('store_id', m.storeId);
    await prefs.setString('store_name', m.storeName);
    await prefs.setString('store_code', m.storeCode);
    await prefs.setString('device_role', m.role);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUỐC PIN DUYỆT NHANH (QUẢN LÝ / CHỦ QUÁN)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cập nhật mã PIN duyệt nhanh 6 số cho tài khoản hiện tại
  static Future<bool> updateQuickPin(String pin) async {
    final cleanPin = pin.trim();
    if (cleanPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      return false;
    }
    final db = _db;
    if (db == null) return false;
    try {
      final rpcRes = await db.rpc(
        'set_user_quick_pin_v4',
        params: {'p_pin': cleanPin},
      );
      if (rpcRes is Map && rpcRes['success'] == true) {
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[UserAuthService] set_user_quick_pin_v4 unavailable: $e');
      return false;
    }
  }

  /// Đổi mật khẩu tài khoản hiện tại
  static Future<Map<String, dynamic>> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final db = _db;
    if (db == null) {
      return {'success': false, 'message': 'Lỗi kết nối cơ sở dữ liệu'};
    }
    final session = await getCurrentSession();
    if (session == null) return {'success': false, 'message': 'Chưa đăng nhập'};

    if (newPassword.length < 8) {
      return {
        'success': false,
        'message': 'Mật khẩu mới phải từ 8 ký tự trở lên',
      };
    }

    try {
      final rpcRes = await db.rpc(
        'change_user_password_v4',
        params: {'p_old_password': oldPassword, 'p_new_password': newPassword},
      );
      if (rpcRes is! Map) {
        return {
          'success': false,
          'message': 'Dịch vụ đổi mật khẩu an toàn chưa sẵn sàng',
        };
      }
      final map = Map<String, dynamic>.from(rpcRes);
      return {
        'success': map['success'] == true,
        'message':
            map['message'] as String? ??
            (map['success'] == true
                ? 'Đổi mật khẩu thành công'
                : 'Đổi mật khẩu thất bại'),
      };
    } catch (e) {
      debugPrint('[UserAuthService] changePassword error: $e');
      return {
        'success': false,
        'message': 'Dịch vụ đổi mật khẩu an toàn chưa sẵn sàng',
      };
    }
  }

  /// Kiểm tra tài khoản hiện tại đã thiết lập mã PIN duyệt nhanh chưa
  static Future<bool> hasQuickPin() async {
    final db = _db;
    if (db == null) return false;
    try {
      final rpcRes = await db.rpc('has_user_quick_pin_v4');
      if (rpcRes is Map && rpcRes['success'] == true) {
        return rpcRes['has_quick_pin'] == true;
      }
      return false;
    } catch (e) {
      debugPrint('[UserAuthService] has_user_quick_pin_v4 unavailable: $e');
      return false;
    }
  }

  /// Xác thực mã PIN của Quản lý / Chủ quán cho store hiện tại
  /// Trả về Map chứa 'id' và 'name' của Quản lý nếu đúng, hoặc null nếu sai
  static Future<Map<String, String>?> verifyManagerQuickPin(
    String storeId,
    String pin,
  ) async {
    final cleanPin = pin.trim();
    if (cleanPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(cleanPin)) {
      return null;
    }
    final db = _db;
    if (db == null) return null;

    try {
      final rpcRes = await db.rpc(
        'verify_manager_quick_pin_v4',
        params: {'p_store_id': storeId, 'p_pin': cleanPin},
      );
      if (rpcRes is Map && rpcRes['success'] == true) {
        final managerId = rpcRes['manager_id'] as String?;
        final managerName = rpcRes['manager_name'] as String? ?? 'Quản lý';
        if (managerId != null && managerId.isNotEmpty) {
          return {'id': managerId, 'name': managerName};
        }
      }
      return null;
    } catch (e) {
      debugPrint(
        '[UserAuthService] verify_manager_quick_pin_v4 unavailable: $e',
      );
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────
class StoreMembership {
  final String storeId;
  final String storeName;
  final String storeCode;
  final String role;
  final bool isOwner;

  const StoreMembership({
    required this.storeId,
    required this.storeName,
    required this.storeCode,
    required this.role,
    required this.isOwner,
  });
}

class SessionData {
  final String userId;
  final String phone;
  final String displayName;
  final String? storeId;
  final String? storeName;
  final String? storeCode;
  final String role;
  final bool isOwner;

  bool get hasStore => storeId != null;

  const SessionData({
    required this.userId,
    required this.phone,
    required this.displayName,
    this.storeId,
    this.storeName,
    this.storeCode,
    required this.role,
    required this.isOwner,
  });
}

class AuthResult {
  final bool isSuccess;
  final String? userId;
  final String? phone;
  final String? displayName;
  final List<StoreMembership> stores;
  final StoreMembership? selectedStore;
  final String? errorMessage;

  const AuthResult._({
    required this.isSuccess,
    this.userId,
    this.phone,
    this.displayName,
    this.stores = const [],
    this.selectedStore,
    this.errorMessage,
  });

  factory AuthResult.success({
    required String userId,
    required String phone,
    required String displayName,
    required List<StoreMembership> stores,
    StoreMembership? selectedStore,
  }) => AuthResult._(
    isSuccess: true,
    userId: userId,
    phone: phone,
    displayName: displayName,
    stores: stores,
    selectedStore: selectedStore,
  );

  factory AuthResult.error(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}

class CreateStoreResult {
  final bool isSuccess;
  final String? storeId;
  final String? storeCode;
  final StoreMembership? membership;
  final String? errorMessage;
  final String? errorCode;

  const CreateStoreResult._({
    required this.isSuccess,
    this.storeId,
    this.storeCode,
    this.membership,
    this.errorMessage,
    this.errorCode,
  });

  factory CreateStoreResult.success({
    required String storeId,
    required String storeCode,
    StoreMembership? membership,
  }) => CreateStoreResult._(
    isSuccess: true,
    storeId: storeId,
    storeCode: storeCode,
    membership: membership,
  );

  factory CreateStoreResult.error(
    String msg, {
    String? errorCode,
    String? storeId,
    String? storeCode,
    StoreMembership? membership,
  }) => CreateStoreResult._(
    isSuccess: false,
    errorMessage: msg,
    errorCode: errorCode,
    storeId: storeId,
    storeCode: storeCode,
    membership: membership,
  );
}
