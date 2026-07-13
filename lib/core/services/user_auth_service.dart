// lib/core/services/user_auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// User Auth Service — Đăng ký / Đăng nhập bằng SĐT + Mật khẩu
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'store_auth_service.dart' show StoreAuthService;
import '../utils/app_logger.dart';

// ── Session keys ──────────────────────────────────────────────────────────────
const _kUserId      = 'auth_user_id';
const _kUserPhone   = 'auth_user_phone';
const _kUserName    = 'auth_user_name';
const _kStoreId     = 'auth_store_id';
const _kStoreName   = 'auth_store_name';
const _kStoreCode   = 'auth_store_code';
const _kRole        = 'auth_role';
const _kIsOwner     = 'auth_is_owner';

// ── Salt cố định (không cần đổi trừ khi có breach) ───────────────────────────
const _kSalt = 'qn_pos_2024_salt';

class UserAuthService {
  static SupabaseClient? get _db {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  // ── Hash password ───────────────────────────────────────────────────────────
  static String _hashPassword(String phone, String password) {
    final input = '$phone:$password:$_kSalt';
    return sha256.convert(utf8.encode(input)).toString();
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
  }) async {
    final db = _db;
    if (db == null) return AuthResult.error('Không kết nối được server.');

    final normalizedPhone = _normalizePhone(phone);
    if (normalizedPhone.isEmpty || normalizedPhone.length < 8) {
      return AuthResult.error('Số điện thoại không hợp lệ.');
    }
    if (password.length < 6) {
      return AuthResult.error('Mật khẩu phải từ 6 ký tự trở lên.');
    }
    if (displayName.trim().isEmpty) {
      return AuthResult.error('Vui lòng nhập tên của bạn.');
    }

    try {
      // Kiểm tra SĐT đã tồn tại chưa
      final existing = await db.from('user_accounts')
          .select('id').eq('phone', normalizedPhone).maybeSingle();
      if (existing != null) {
        return AuthResult.error('Số điện thoại này đã được đăng ký.\nVui lòng đăng nhập.');
      }

      // Tạo tài khoản
      final res = await db.from('user_accounts').insert({
        'phone':         normalizedPhone,
        'password_hash': _hashPassword(normalizedPhone, password),
        'display_name':  displayName.trim(),
      }).select('id, phone, display_name').single();

      final userId = res['id'] as String;

      // Lưu session tạm (chưa có store)
      await _saveSession(
        userId: userId,
        phone:  normalizedPhone,
        name:   displayName.trim(),
      );

      return AuthResult.success(
        userId:      userId,
        phone:       normalizedPhone,
        displayName: displayName.trim(),
        stores:      [],
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return AuthResult.error('Số điện thoại đã tồn tại. Vui lòng đăng nhập.');
      }
      return AuthResult.error('Lỗi: ${e.message}');
    } catch (e) {
      return AuthResult.error('Lỗi không xác định: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ĐĂNG NHẬP
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<AuthResult> login({
    required String phone,
    required String password,
  }) async {
    final normalizedPhone = _normalizePhone(phone);

    // ── FALLBACK CHO GOOGLE PLAY REVIEW ────────────────────────────────────────
    // Cho phép các tài khoản test đăng nhập offline ngay cả khi không có internet
    final isReviewerPhone = (normalizedPhone == '+849999996666' || normalizedPhone == '9999996666');
    if (isReviewerPhone && password == '112233') {
      final userId = '99999966-6666-6666-6666-999999666666';
      final displayName = 'Quản Nhỏ POS';
      final store = StoreMembership(
        storeId: '00000000-0000-0000-0000-000000009999',
        storeName: 'Quán Nhỏ POS',
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
      await prefs.setString('store_id', '00000000-0000-0000-0000-000000009999');
      await prefs.setString('store_code', 'DEMO99');
      await prefs.setString('store_name', 'Quán Nhỏ POS');
      await prefs.setString('device_role', 'owner');
      return AuthResult.success(
        userId: userId,
        phone: normalizedPhone,
        displayName: displayName,
        stores: [store],
        selectedStore: store,
      );
    }


    final db = _db;
    if (db == null) return AuthResult.error('Không kết nối được server.');


    try {
      // Tìm tài khoản
      final userRes = await db.from('user_accounts')
          .select('id, phone, display_name, password_hash')
          .eq('phone', normalizedPhone)
          .maybeSingle();

      if (userRes == null) {
        return AuthResult.error('Số điện thoại chưa được đăng ký.');
      }

      // Kiểm tra mật khẩu
      final expectedHash = _hashPassword(normalizedPhone, password);
      if (userRes['password_hash'] != expectedHash) {
        return AuthResult.error('Mật khẩu không đúng.');
      }

      final userId      = userRes['id']           as String;
      final displayName = userRes['display_name'] as String;

      // Lấy danh sách quán
      final memberships = await db.from('store_members')
          .select('role, is_owner, store_id, stores(id, name, store_code)')
          .eq('user_id', userId);

      final stores = memberships.map<StoreMembership>((m) {
        final store = m['stores'] as Map<String, dynamic>;
        return StoreMembership(
          storeId:   store['id']         as String,
          storeName: store['name']       as String,
          storeCode: store['store_code'] as String,
          role:      m['role']           as String,
          isOwner:   m['is_owner']       as bool,
        );
      }).toList();

      // Nếu chỉ có 1 quán → tự động chọn
      if (stores.length == 1) {
        await _saveFullSession(
          userId: userId, phone: normalizedPhone, name: displayName,
          membership: stores.first,
        );
      } else {
        // Nhiều quán hoặc 0 quán → lưu session cơ bản
        await _saveSession(userId: userId, phone: normalizedPhone, name: displayName);
      }

      AppLogger.info('auth', 'Dang nhap he thong thanh cong.');

      return AuthResult.success(
        userId:      userId,
        phone:       normalizedPhone,
        displayName: displayName,
        stores:      stores,
        selectedStore: stores.length == 1 ? stores.first : null,
      );
    } on PostgrestException catch (e) {
      return AuthResult.error('Lỗi kết nối: ${e.message}');
    } catch (e) {
      return AuthResult.error('Lỗi không xác định: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // KIỂM TRA MEMBERSHIP — Gọi khi staff chưa có quán (được thêm sau khi đăng ký)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<StoreMembership?> fetchStoreMembership(String userId) async {
    final db = _db;
    if (db == null) return null;
    try {
      final memberships = await db
          .from('store_members')
          .select('role, is_owner, store_id, stores(id, name, store_code)')
          .eq('user_id', userId);

      if (memberships.isEmpty) return null;

      final m     = memberships.first;
      final store = m['stores'] as Map<String, dynamic>;
      return StoreMembership(
        storeId:   store['id']         as String,
        storeName: store['name']       as String,
        storeCode: store['store_code'] as String,
        role:      m['role']           as String,
        isOwner:   m['is_owner']       as bool,
      );
    } catch (e) {
      debugPrint('[UserAuthService] fetchStoreMembership error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TẠO QUÁN (sau khi đã đăng nhập / đăng ký)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<CreateStoreResult> createStore({
    required String userId,
    required String storeName,
  }) async {
    final db = _db;
    if (db == null) return CreateStoreResult.error('Không kết nối được server.');
    if (storeName.trim().isEmpty) {
      return CreateStoreResult.error('Vui lòng nhập tên quán.');
    }

    try {
      final code = _generateCode();

      // Tạo store
      final storeRes = await db.from('stores').insert({
        'store_code':    code,
        'name':          storeName.trim(),
        'status':        'trial',
        'owner_user_id': userId,
      }).select('id, store_code, name').single();

      final storeId   = storeRes['id']         as String;
      final storeCode = storeRes['store_code'] as String;
      final name      = storeRes['name']       as String;

      // Thêm user là owner của quán
      await db.from('store_members').insert({
        'user_id':  userId,
        'store_id': storeId,
        'role':     'owner',
        'is_owner': true,
      });

      // Lưu session
      final membership = StoreMembership(
        storeId: storeId, storeName: name,
        storeCode: storeCode, role: 'owner', isOwner: true,
      );
      final prefs = await SharedPreferences.getInstance();
      await _applyMembershipToPrefs(prefs, membership);

      // Seed dữ liệu mặc định (finance_categories, app_settings, store_roles)
      await StoreAuthService.seedDefaults(db, storeId);

      return CreateStoreResult.success(storeId: storeId, storeCode: storeCode);
    } on PostgrestException catch (e) {
      return CreateStoreResult.error('Lỗi: ${e.message}');
    } catch (e) {
      return CreateStoreResult.error('Lỗi: $e');
    }
  }

  static Future<CreateStoreResult> joinStoreByCode({
    required String userId,
    required String storeCode,
  }) async {
    final db = _db;
    if (db == null) return CreateStoreResult.error('Không kết nối được server.');
    final code = storeCode.trim().toUpperCase();
    if (code.isEmpty) {
      return CreateStoreResult.error('Vui lòng nhập mã quán.');
    }

    try {
      // 1. Tìm store theo storeCode
      final storeRes = await db
          .from('stores')
          .select('id, name, status, store_code')
          .eq('store_code', code)
          .maybeSingle();

      if (storeRes == null) {
        return CreateStoreResult.error('Mã quán "$code" không tồn tại.\nVui lòng kiểm tra lại hoặc hỏi chủ quán.');
      }

      final status = storeRes['status'] as String?;
      if (status == 'suspended' || status == 'deleted') {
        return CreateStoreResult.error('Quán này đã bị khóa hoặc ngừng hoạt động.');
      }

      final storeId = storeRes['id'] as String;
      final storeName = storeRes['name'] as String;

      // 2. Kiểm tra xem user đã là thành viên chưa
      final existing = await db
          .from('store_members')
          .select('id')
          .eq('store_id', storeId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return CreateStoreResult.error('Bạn đã là thành viên của quán này rồi.');
      }

      // 3. Thêm vào store_members với role mặc định là 'waiter' (Phục vụ)
      await db.from('store_members').insert({
        'user_id': userId,
        'store_id': storeId,
        'role': 'waiter',
        'is_owner': false,
      });

      // 4. Lưu session cho quán này
      final membership = StoreMembership(
        storeId: storeId,
        storeName: storeName,
        storeCode: code,
        role: 'waiter',
        isOwner: false,
      );
      final prefs = await SharedPreferences.getInstance();
      await _applyMembershipToPrefs(prefs, membership);

      return CreateStoreResult.success(storeId: storeId, storeCode: code);
    } on PostgrestException catch (e) {
      return CreateStoreResult.error('Lỗi database: ${e.message}');
    } catch (e) {
      return CreateStoreResult.error('Lỗi: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CHỌN QUÁN (khi có nhiều quán)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> selectStore(StoreMembership membership) async {
    final prefs = await SharedPreferences.getInstance();
    await _applyMembershipToPrefs(prefs, membership);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SESSION
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<SessionData?> getCurrentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_kUserId);
    if (userId == null) return null;
    return SessionData(
      userId:      userId,
      phone:       prefs.getString(_kUserPhone)  ?? '',
      displayName: prefs.getString(_kUserName)   ?? '',
      storeId:     prefs.getString(_kStoreId),
      storeName:   prefs.getString(_kStoreName),
      storeCode:   prefs.getString(_kStoreCode),
      role:        prefs.getString(_kRole)        ?? '',
      isOwner:     prefs.getBool(_kIsOwner)       ?? false,
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
    await prefs.remove('device_id');
    await prefs.remove('device_role');
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  static Future<void> _saveSession({
    required String userId,
    required String phone,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId,    userId);
    await prefs.setString(_kUserPhone, phone);
    await prefs.setString(_kUserName,  name);
  }

  static Future<void> _saveFullSession({
    required String userId,
    required String phone,
    required String name,
    required StoreMembership membership,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId,    userId);
    await prefs.setString(_kUserPhone, phone);
    await prefs.setString(_kUserName,  name);
    await _applyMembershipToPrefs(prefs, membership);
  }

  static Future<void> _applyMembershipToPrefs(
    SharedPreferences prefs, StoreMembership m) async {
    await prefs.setString(_kStoreId,   m.storeId);
    await prefs.setString(_kStoreName, m.storeName);
    await prefs.setString(_kStoreCode, m.storeCode);
    await prefs.setString(_kRole,      m.role);
    await prefs.setBool(_kIsOwner,     m.isOwner);
  }

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final suffix = List.generate(4, (_) => chars[rng.nextInt(chars.length)]).join();
    return 'QN-$suffix';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUỐC PIN DUYỆT NHANH (QUẢN LÝ / CHỦ QUÁN)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Cập nhật mã PIN duyệt nhanh 4 số cho tài khoản hiện tại
  static Future<bool> updateQuickPin(String pin) async {
    final db = _db;
    if (db == null) return false;
    final session = await getCurrentSession();
    if (session == null) return false;
    try {
      final hash = _hashPassword(session.phone, pin);
      await db.from('user_accounts').update({
        'quick_pin': hash,
      }).eq('id', session.userId);
      return true;
    } catch (e) {
      debugPrint('[UserAuthService] updateQuickPin error: $e');
      return false;
    }
  }

  /// Kiểm tra tài khoản hiện tại đã thiết lập mã PIN duyệt nhanh chưa
  static Future<bool> hasQuickPin() async {
    final db = _db;
    if (db == null) return false;
    final session = await getCurrentSession();
    if (session == null) return false;
    try {
      final res = await db
          .from('user_accounts')
          .select('quick_pin')
          .eq('id', session.userId)
          .maybeSingle();
      if (res == null) return false;
      final qp = res['quick_pin'] as String?;
      return qp != null && qp.isNotEmpty;
    } catch (e) {
      debugPrint('[UserAuthService] hasQuickPin error: $e');
      return false;
    }
  }


  /// Xác thực mã PIN của Quản lý / Chủ quán cho store hiện tại
  /// Trả về Map chứa 'id' và 'name' của Quản lý nếu đúng, hoặc null nếu sai
  static Future<Map<String, String>?> verifyManagerQuickPin(
    String storeId,
    String pin,
  ) async {
    final db = _db;
    if (db == null) return null;
    try {
      final members = await db
          .from('store_members')
          .select('role, is_owner, user_accounts(id, phone, display_name, quick_pin)')
          .eq('store_id', storeId);

      for (final m in members) {
        final role = m['role'] as String? ?? '';
        final isOwner = m['is_owner'] as bool? ?? false;
        final user = m['user_accounts'] as Map<String, dynamic>?;
        if (user == null) continue;

        final rLower = role.toLowerCase().trim();
        final isCanonicalManager = rLower.contains('owner') || rLower.contains('chủ') || rLower.contains('manager') || rLower.contains('quản lý');
        if (isCanonicalManager || isOwner) {
          final phone = user['phone'] as String? ?? '';
          final storedHash = user['quick_pin'] as String?;
          if (storedHash == null || storedHash.isEmpty) continue;

          final inputHash = _hashPassword(phone, pin);
          if (storedHash == inputHash) {
            return {
              'id': user['id'] as String,
              'name': user['display_name'] as String? ?? 'Quản lý',
            };
          }
        }
      }
      return null;
    } catch (e) {
      debugPrint('[UserAuthService] verifyManagerQuickPin error: $e');
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
  final bool   isOwner;

  const StoreMembership({
    required this.storeId,
    required this.storeName,
    required this.storeCode,
    required this.role,
    required this.isOwner,
  });
}

class SessionData {
  final String  userId;
  final String  phone;
  final String  displayName;
  final String? storeId;
  final String? storeName;
  final String? storeCode;
  final String  role;
  final bool    isOwner;

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
  final bool             isSuccess;
  final String?          userId;
  final String?          phone;
  final String?          displayName;
  final List<StoreMembership> stores;
  final StoreMembership? selectedStore;
  final String?          errorMessage;

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
    isSuccess: true, userId: userId, phone: phone,
    displayName: displayName, stores: stores, selectedStore: selectedStore,
  );

  factory AuthResult.error(String message) =>
      AuthResult._(isSuccess: false, errorMessage: message);
}

class CreateStoreResult {
  final bool    isSuccess;
  final String? storeId;
  final String? storeCode;
  final String? errorMessage;

  const CreateStoreResult._({required this.isSuccess, this.storeId, this.storeCode, this.errorMessage});

  factory CreateStoreResult.success({required String storeId, required String storeCode}) =>
      CreateStoreResult._(isSuccess: true, storeId: storeId, storeCode: storeCode);

  factory CreateStoreResult.error(String msg) =>
      CreateStoreResult._(isSuccess: false, errorMessage: msg);
}
