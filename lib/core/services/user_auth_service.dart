// lib/core/services/user_auth_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// User Auth Service — Đăng ký / Đăng nhập bằng SĐT + Mật khẩu
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:crypto/crypto.dart';
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

// ── Salt cố định (không cần đổi trừ khi có breach) ───────────────────────────
const _kSalt = 'qn_pos_2024_salt';

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
      final existing = await db
          .from('user_accounts')
          .select('id')
          .eq('phone', normalizedPhone)
          .maybeSingle();
      if (existing != null) {
        return AuthResult.error(
          'Số điện thoại này đã được đăng ký.\nVui lòng đăng nhập.',
        );
      }

      // Tạo tài khoản
      final res = await db
          .from('user_accounts')
          .insert({
            'phone': normalizedPhone,
            'password_hash': _hashPassword(normalizedPhone, password),
            'display_name': displayName.trim(),
          })
          .select('id, phone, display_name')
          .single();

      final userId = res['id'] as String;

      // Lưu session tạm (chưa có store)
      await _saveSession(
        userId: userId,
        phone: normalizedPhone,
        name: displayName.trim(),
      );

      return AuthResult.success(
        userId: userId,
        phone: normalizedPhone,
        displayName: displayName.trim(),
        stores: [],
      );
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        return AuthResult.error(
          'Số điện thoại đã tồn tại. Vui lòng đăng nhập.',
        );
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
    PosJwtAuthService? jwtService,
  }) async {
    final normalizedPhone = _normalizePhone(phone);

    // ── FALLBACK CHO GOOGLE PLAY & APP STORE REVIEW ─────────────────────────────
    // Cho phép các tài khoản test đăng nhập offline ngay cả khi không có internet
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
    if (isReviewerPhone && (password == '112233' || password.isNotEmpty)) {
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
      // 1. Chuẩn bị các biến thể SĐT (09xxx, +849xxx, 849xxx, raw)
      final rawPhone = phone.trim().replaceAll(RegExp(r'\s|-|\(|\)'), '');
      final cleanDigits = rawPhone.replaceAll(RegExp(r'\D'), '');
      final phoneVariants = <String>{
        normalizedPhone,
        rawPhone,
        if (cleanDigits.length >= 9) ...[
          '0${cleanDigits.substring(cleanDigits.length - 9)}',
          '+84${cleanDigits.substring(cleanDigits.length - 9)}',
          '84${cleanDigits.substring(cleanDigits.length - 9)}',
        ],
      }.toList();

      // 2. Tìm tài khoản trong user_accounts theo danh sách biến thể SĐT
      Map<String, dynamic>? userRes;
      for (final p in phoneVariants) {
        final res = await db
            .from('user_accounts')
            .select('id, phone, display_name, password_hash')
            .eq('phone', p)
            .limit(1)
            .maybeSingle();
        if (res != null) {
          userRes = res;
          break;
        }
      }

      // 3. Fallback: Nếu không thấy trong user_accounts → tìm trong staff_members (bảng nhân viên chuẩn mới)
      if (userRes == null) {
        // Ưu tiên 3A: Gọi RPC lookup_staff_by_phone để bypass RLS ở màn hình Login
        try {
          final rpcRes = await db.rpc(
            'lookup_staff_by_phone',
            params: {'phone_input': normalizedPhone},
          );
          if (rpcRes != null && rpcRes is List && rpcRes.isNotEmpty) {
            final first = Map<String, dynamic>.from(rpcRes.first as Map);
            final staffId = first['id'] as String;
            final staffName = (first['name'] as String?) ?? 'Nhân viên';
            final staffRole = (first['role'] as String?) ?? 'cashier';
            final storeId = first['store_id'] as String;
            final dbPhone = (first['phone'] as String?) ?? normalizedPhone;

            final pwdHash = _hashPassword(dbPhone, password);
            try {
              await db.from('user_accounts').upsert({
                'id': staffId,
                'phone': dbPhone,
                'display_name': staffName,
                'password_hash': pwdHash,
              });

              await StoreMembershipWriter.upsertMembership(
                db,
                userId: staffId,
                storeId: storeId,
                role: staffRole,
                isOwner: staffRole.toLowerCase() == 'owner',
              );
            } catch (e) {
              debugPrint(
                '[UserAuthService.login] RPC auto-provision error: $e',
              );
            }

            userRes = {
              'id': staffId,
              'phone': dbPhone,
              'display_name': staffName,
              'password_hash': pwdHash,
            };
          }
        } catch (e) {
          debugPrint(
            '[UserAuthService.login] RPC lookup_staff_by_phone error: $e',
          );
        }

        // Ưu tiên 3B: Tra cứu trực tiếp từ staff_members theo phoneVariants
        if (userRes == null) {
          for (final p in phoneVariants) {
            final staffRow = await db
                .from('staff_members')
                .select('id, store_id, name, role, phone')
                .eq('phone', p)
                .limit(1)
                .maybeSingle();

            if (staffRow != null) {
              final staffId = staffRow['id'] as String;
              final staffName = (staffRow['name'] as String?) ?? 'Nhân viên';
              final staffRole = (staffRow['role'] as String?) ?? 'cashier';
              final storeId = staffRow['store_id'] as String;
              final dbPhone = (staffRow['phone'] as String?) ?? normalizedPhone;

              // Auto-provision tài khoản user_accounts & store_members tương ứng
              final pwdHash = _hashPassword(dbPhone, password);
              try {
                await db.from('user_accounts').upsert({
                  'id': staffId,
                  'phone': dbPhone,
                  'display_name': staffName,
                  'password_hash': pwdHash,
                });

                await StoreMembershipWriter.upsertMembership(
                  db,
                  userId: staffId,
                  storeId: storeId,
                  role: staffRole,
                  isOwner: staffRole.toLowerCase() == 'owner',
                );
              } catch (e) {
                debugPrint(
                  '[UserAuthService.login] Direct auto-provision error: $e',
                );
              }

              userRes = {
                'id': staffId,
                'phone': dbPhone,
                'display_name': staffName,
                'password_hash': pwdHash,
              };
              break;
            }
          }
        }
      }

      if (userRes == null) {
        return AuthResult.error('Số điện thoại chưa được đăng ký.');
      }

      final userId = userRes['id'] as String;
      final displayName = userRes['display_name'] as String;
      final storedPhone = userRes['phone'] as String? ?? normalizedPhone;
      final storedHash = userRes['password_hash'] as String?;

      // 4. Kiểm tra mật khẩu (hỗ trợ kiểm tra theo mọi biến thể SĐT chuẩn hoá & raw)
      final p0 = cleanDigits.length >= 9
          ? '0${cleanDigits.substring(cleanDigits.length - 9)}'
          : rawPhone;
      final p84 = cleanDigits.length >= 9
          ? '+84${cleanDigits.substring(cleanDigits.length - 9)}'
          : normalizedPhone;

      final expectedHashNorm = _hashPassword(normalizedPhone, password);
      final expectedHashRaw = _hashPassword(rawPhone, password);
      final expectedHashDb = _hashPassword(storedPhone, password);
      final expectedHashP0 = _hashPassword(p0, password);
      final expectedHashP84 = _hashPassword(p84, password);

      final isPasswordCorrect =
          (storedHash == expectedHashNorm) ||
          (storedHash == expectedHashRaw) ||
          (storedHash == expectedHashDb) ||
          (storedHash == expectedHashP0) ||
          (storedHash == expectedHashP84) ||
          (storedHash == password);

      if (!isPasswordCorrect) {
        return AuthResult.error('Mật khẩu không đúng.');
      }

      // Cập nhật chuẩn hoá password_hash nếu vừa khớp qua biến thể cũ
      if (storedHash != expectedHashNorm) {
        try {
          await db
              .from('user_accounts')
              .update({
                'password_hash': expectedHashNorm,
                'phone': normalizedPhone,
              })
              .eq('id', userId);
        } catch (_) {}
      }

      // 5. Lấy danh sách quán từ store_members
      final memberships = await db
          .from('store_members')
          .select('role, is_owner, store_id, stores(id, name, store_code)')
          .eq('user_id', userId);

      List<StoreMembership> stores = [];
      for (final m in memberships) {
        Map<String, dynamic>? store = m['stores'] as Map<String, dynamic>?;
        final storeId = m['store_id'] as String?;

        if (store == null && storeId != null) {
          try {
            store = await db
                .from('stores')
                .select('id, name, store_code')
                .eq('id', storeId)
                .maybeSingle();
          } catch (_) {}
        }

        if (store != null) {
          stores.add(
            StoreMembership(
              storeId: store['id'] as String,
              storeName: (store['name'] as String?) ?? 'Quán Nhỏ',
              storeCode: (store['store_code'] as String?) ?? '',
              role: (m['role'] as String?) ?? 'cashier',
              isOwner: (m['is_owner'] as bool?) ?? false,
            ),
          );
        }
      }

      // 6. Fallback: Nếu store_members rỗng → kiểm tra từ staff_members
      if (stores.isEmpty) {
        final staffRows = await db
            .from('staff_members')
            .select('role, store_id, stores(id, name, store_code)')
            .eq('id', userId);

        for (final s in staffRows) {
          Map<String, dynamic>? store = s['stores'] as Map<String, dynamic>?;
          final storeId = s['store_id'] as String?;

          // Nếu FK embedding bị null → tra cứu trực tiếp từ bảng stores theo store_id
          if (store == null && storeId != null) {
            try {
              store = await db
                  .from('stores')
                  .select('id, name, store_code')
                  .eq('id', storeId)
                  .maybeSingle();
            } catch (_) {}
          }

          if (store != null) {
            final role = (s['role'] as String?) ?? 'cashier';
            final isOwner = role.toLowerCase() == 'owner';
            final m = StoreMembership(
              storeId: store['id'] as String,
              storeName: (store['name'] as String?) ?? 'Quán Nhỏ',
              storeCode: (store['store_code'] as String?) ?? '',
              role: role,
              isOwner: isOwner,
            );
            stores.add(m);

            // Đồng bộ sang store_members để đảm bảo nhất quán
            try {
              await StoreMembershipWriter.upsertMembership(
                db,
                userId: userId,
                storeId: m.storeId,
                role: role,
                isOwner: isOwner,
              );
            } catch (_) {}
          }
        }
      }

      // Nếu chỉ có 1 quán: POS JWT chỉ bắt buộc khi endpoint production
      // được cấu hình rõ bằng POS_JWT_AUTH_URL. Bản build bình thường tiếp tục
      // dùng phiên Supabase hiện hữu và không phụ thuộc BunServer/Tailscale.
      if (stores.length == 1) {
        final storeId = stores.first.storeId;
        final posJwtService = jwtService ?? PosJwtAuthService();
        if (posJwtService.isConfigured) {
          final jwtRes = await posJwtService.requestPosJwt(
            phone: normalizedPhone,
            password: password,
            storeId: storeId,
          );
          if (jwtRes['success'] != true) {
            await posJwtService.clearPosJwt();
            await posJwtService.applyAuthToSupabase(null);
            return AuthResult.error(
              jwtRes['message'] as String? ??
                  'Cấp token xác thực cửa hàng thất bại.',
            );
          }
        }

        await _saveFullSession(
          userId: userId,
          phone: normalizedPhone,
          name: displayName,
          membership: stores.first,
        );

        final feedbackService = FeedbackService();
        // AI Bum là dịch vụ bổ sung: chạy nền và không được chặn đăng nhập POS.
        unawaited(
          feedbackService.exchangeSessionWithPassword(
            phone: normalizedPhone,
            password: password,
            storeId: storeId,
          ),
        );
      } else {
        // Nhiều quán hoặc 0 quán → lưu session cơ bản
        await _saveSession(
          userId: userId,
          phone: normalizedPhone,
          name: displayName,
        );
      }

      return AuthResult.success(
        userId: userId,
        phone: normalizedPhone,
        displayName: displayName,
        stores: stores,
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
    required String userId,
    required String storeCode,
  }) async {
    final code = storeCode.trim().toUpperCase();
    if (code.isEmpty) {
      return CreateStoreResult.error('Vui lòng nhập mã quán.');
    }

    try {
      final storeRes = await authRepository.queryStoreByCode(code);
      if (storeRes == null || storeRes.isEmpty) {
        return CreateStoreResult.error(
          'Mã quán "$code" không tồn tại.\nVui lòng kiểm tra lại hoặc hỏi chủ quán.',
        );
      }

      final status = storeRes['status'] as String?;
      if (status == 'suspended' || status == 'deleted') {
        return CreateStoreResult.error(
          'Quán này đã bị khóa hoặc ngừng hoạt động.',
        );
      }

      final storeId = storeRes['id'] as String;
      final storeName = storeRes['name'] as String;

      // 2. Kiểm tra xem user đã là thành viên trong store_members chưa
      final existing = await authRepository.queryStoreMember(storeId, userId);

      if (existing != null) {
        // ĐÃ LÀ THÀNH VIÊN HỢP LỆ: Đọc membership hiện có, chuyển session ngay và trả success
        final role = (existing['role'] as String?) ?? 'cashier';
        final isOwner = (existing['is_owner'] as bool?) ?? false;
        final membership = StoreMembership(
          storeId: storeId,
          storeName: storeName,
          storeCode: code,
          role: role,
          isOwner: isOwner,
        );
        final prefs = await SharedPreferences.getInstance();
        await _applyMembershipToPrefs(prefs, membership);
        return CreateStoreResult.success(
          storeId: storeId,
          storeCode: code,
          membership: membership,
        );
      }

      // 3. Kiểm tra xem Quản lý đã thêm nhân viên này trước đó trong staff_members chưa để lấy vai trò chính xác
      String assignedRole = 'waiter';
      try {
        final staffRow = await authRepository.queryStaffMember(storeId, userId);
        if (staffRow != null && staffRow['role'] != null) {
          assignedRole = staffRow['role'] as String;
        }
      } catch (_) {}

      // 4. Thêm bản ghi mới vào store_members
      await membershipWriter.upsert(
        storeId: storeId,
        userId: userId,
        role: assignedRole,
        isOwner: false,
      );

      // 5. Kiểm tra trước khi sync sang staff_members: Nếu staff_members với id=userId đã thuộc quán khác -> BỎ QUA không upsert đè
      try {
        final existingStaff = await authRepository.queryStaffMemberSimple(
          userId,
        );

        final currentStaffStoreId = existingStaff?['store_id'] as String?;
        if (currentStaffStoreId == null || currentStaffStoreId == storeId) {
          final userAcc = await authRepository.queryUserAccount(userId);
          await authRepository.upsertStaffMember({
            'id': userId,
            'store_id': storeId,
            'name': userAcc?['display_name'] ?? 'Nhân viên mới',
            'phone': userAcc?['phone'] ?? '',
            'role': assignedRole,
            'is_active': true,
          });
        } else {
          debugPrint(
            '[joinStoreByCode] Khách thuộc đa quán: Bỏ qua upsert staff_members để không làm đè store_id của quán 1.',
          );
        }
      } catch (e) {
        debugPrint('[joinStoreByCode] staff_members sync check error: $e');
      }

      // 6. Tự động lưu và kích hoạt phiên làm việc (Session) mới cho quán này ngay lập tức
      final membership = StoreMembership(
        storeId: storeId,
        storeName: storeName,
        storeCode: code,
        role: assignedRole,
        isOwner: false,
      );
      final prefs = await SharedPreferences.getInstance();
      await _applyMembershipToPrefs(prefs, membership);

      return CreateStoreResult.success(
        storeId: storeId,
        storeCode: code,
        membership: membership,
      );
    } catch (e) {
      return CreateStoreResult.error('Lỗi: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TẠO QUÁN MỚI (chủ quán tạo quán mới)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<CreateStoreResult> createStore({
    required String userId,
    required String storeName,
  }) async {
    if (storeName.trim().isEmpty) {
      return CreateStoreResult.error('Vui lòng nhập tên quán.');
    }

    try {
      final code = _generateCode();

      final storeRes = await authRepository.insertStore({
        'store_code': code,
        'name': storeName.trim(),
        'status': 'trial',
        'owner_user_id': userId,
      });

      final storeId = storeRes['id'] as String;
      final storeCode = storeRes['store_code'] as String;
      final name = storeRes['name'] as String;

      await membershipWriter.upsert(
        storeId: storeId,
        userId: userId,
        role: 'owner',
        isOwner: true,
      );

      final membership = StoreMembership(
        storeId: storeId,
        storeName: name,
        storeCode: storeCode,
        role: 'owner',
        isOwner: true,
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await _applyMembershipToPrefs(prefs, membership);
      } catch (_) {}

      final db = _db;
      if (db != null) {
        try {
          await StoreAuthService.seedDefaults(db, storeId);
        } catch (_) {}
      }

      return CreateStoreResult.success(
        storeId: storeId,
        storeCode: storeCode,
        membership: membership,
      );
    } catch (e) {
      return CreateStoreResult.error('Lỗi: $e');
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
      await PosJwtAuthService().clearPosJwt();
      await PosJwtAuthService().applyAuthToSupabase(null);
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

  static String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final suffix = List.generate(
      4,
      (_) => chars[rng.nextInt(chars.length)],
    ).join();
    return 'QN-$suffix';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUỐC PIN DUYỆT NHANH (QUẢN LÝ / CHỦ QUÁN)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Cập nhật mã PIN duyệt nhanh 6 số cho tài khoản hiện tại
  static Future<bool> updateQuickPin(String pin) async {
    final db = _db;
    if (db == null) return false;
    final session = await getCurrentSession();
    if (session == null) return false;
    try {
      final hash = _hashPassword(session.phone, pin);
      await db
          .from('user_accounts')
          .update({'quick_pin': hash})
          .eq('id', session.userId);
      return true;
    } catch (e) {
      debugPrint('[UserAuthService] updateQuickPin error: $e');
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

    if (newPassword.length < 6) {
      return {
        'success': false,
        'message': 'Mật khẩu mới phải từ 6 ký tự trở lên',
      };
    }

    try {
      final userRes = await db
          .from('user_accounts')
          .select('password_hash, phone')
          .eq('id', session.userId)
          .maybeSingle();

      if (userRes == null) {
        return {
          'success': false,
          'message': 'Không tìm thấy thông tin tài khoản',
        };
      }

      final storedHash = userRes['password_hash'] as String?;
      final phone = userRes['phone'] as String? ?? session.phone;
      final expectedOldHash = _hashPassword(phone, oldPassword);

      if (storedHash != expectedOldHash && storedHash != oldPassword) {
        return {
          'success': false,
          'message': 'Mật khẩu hiện tại không chính xác',
        };
      }

      final newHash = _hashPassword(phone, newPassword);
      await db
          .from('user_accounts')
          .update({'password_hash': newHash})
          .eq('id', session.userId);

      return {'success': true, 'message': 'Đổi mật khẩu thành công'};
    } catch (e) {
      debugPrint('[UserAuthService] changePassword error: $e');
      return {'success': false, 'message': 'Lỗi cập nhật: $e'};
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
          .select(
            'role, is_owner, user_accounts(id, phone, display_name, quick_pin)',
          )
          .eq('store_id', storeId);

      for (final m in members) {
        final role = m['role'] as String? ?? '';
        final isOwner = m['is_owner'] as bool? ?? false;
        final user = m['user_accounts'] as Map<String, dynamic>?;
        if (user == null) continue;

        final rLower = role.toLowerCase().trim();
        final isCanonicalManager =
            rLower.contains('owner') ||
            rLower.contains('chủ') ||
            rLower.contains('manager') ||
            rLower.contains('quản lý');
        if (isCanonicalManager || isOwner) {
          final phone = user['phone'] as String? ?? '';
          final storedHash = user['quick_pin'] as String?;
          if (storedHash == null || storedHash.isEmpty) continue;

          final normPhone = _normalizePhone(phone);
          final inputHash1 = _hashPassword(phone, pin);
          final inputHash2 = _hashPassword(normPhone, pin);

          if (storedHash == inputHash1 || storedHash == inputHash2) {
            return {
              'id': user['id'] as String,
              'name': user['display_name'] as String? ?? 'Quản lý',
            };
          }
        }
      }

      // Fallback: Tra cứu quản lý trực tiếp từ staff_members
      try {
        final staffRows = await db
            .from('staff_members')
            .select('id, name, phone, role, pin_hash')
            .eq('store_id', storeId);

        for (final s in staffRows) {
          final role = s['role'] as String? ?? '';
          final rLower = role.toLowerCase().trim();
          final isManager =
              rLower.contains('owner') ||
              rLower.contains('chủ') ||
              rLower.contains('manager') ||
              rLower.contains('quản lý');
          if (!isManager) continue;

          final phone = s['phone'] as String? ?? '';
          final storedPinHash = s['pin_hash'] as String?;
          final id = s['id'] as String;

          // Tra cứu quick_pin trong user_accounts nếu pin_hash ở staff_members rỗng
          String? storedHash = storedPinHash;
          if (storedHash == null || storedHash.isEmpty) {
            final u = await db
                .from('user_accounts')
                .select('quick_pin')
                .eq('id', id)
                .maybeSingle();
            storedHash = u?['quick_pin'] as String?;
          }

          if (storedHash == null || storedHash.isEmpty) continue;

          final normPhone = _normalizePhone(phone);
          final inputHash1 = _hashPassword(phone, pin);
          final inputHash2 = _hashPassword(normPhone, pin);

          if (storedHash == inputHash1 || storedHash == inputHash2) {
            return {'id': id, 'name': (s['name'] as String?) ?? 'Quản lý'};
          }
        }
      } catch (_) {}

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

  const CreateStoreResult._({
    required this.isSuccess,
    this.storeId,
    this.storeCode,
    this.membership,
    this.errorMessage,
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

  factory CreateStoreResult.error(String msg) =>
      CreateStoreResult._(isSuccess: false, errorMessage: msg);
}
