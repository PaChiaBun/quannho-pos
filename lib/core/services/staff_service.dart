// lib/core/services/staff_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Staff Service — Quản lý nhân viên qua Supabase
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart' show Color;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'staff_sync_service.dart';

// ── Module IDs (khớp với module system) ───────────────────────────────────────
const kAllModules = ['pos', 'kho', 'kho_pro', 'ban', 'kitchen', 'finance', 'report', 'loyalty', 'staff', 'chamcong', 'tinhluong', 'kay_ops'];

// Quyền mặc định mỗi role (module-level)
const kDefaultPerms = {
  'owner':   ['pos', 'kho', 'kho_pro', 'ban', 'kitchen', 'finance', 'report', 'loyalty', 'staff', 'chamcong', 'tinhluong', 'kay_ops'],
  'manager': ['pos', 'kho', 'kho_pro', 'ban', 'kitchen', 'finance', 'report', 'tinhluong', 'kay_ops'],
  'cashier': ['pos', 'ban', 'kay_ops'],
  'waiter':  ['ban', 'kitchen', 'kay_ops'],
  'kitchen': ['kitchen', 'kay_ops'],
  'stock':   ['kho', 'kho_pro', 'kay_ops'],
};

// ── Action-level permissions ──────────────────────────────────────────────────
// Key pattern: '{module}.{action}'
const kAllActions = [
  'pos.cancel_bill',      // Huỷ đơn hàng đã tạo
  'pos.apply_discount',   // Áp dụng giảm giá thủ công
  'pos.edit_price',       // Sửa giá bán tại quầy
  'pos.view_history',     // Xem lịch sử đơn toàn quán
  'kho.edit_quantity',    // Sửa số lượng tồn kho
  'kho.delete_item',      // Xoá sản phẩm khỏi kho
  'finance.view_all',     // Xem toàn bộ thu chi
  'report.view',          // Xem báo cáo doanh thu
];

// Label hiển thị trên UI — key → (tiêu đề, mô tả, module group)
const kActionMeta = <String, (String, String, String)>{
  'pos.cancel_bill':    ('Huỷ đơn hàng',         'Cho phép huỷ bill đã tạo', 'POS'),
  'pos.apply_discount': ('Áp dụng giảm giá',      'Giảm giá thủ công trên bill', 'POS'),
  'pos.edit_price':     ('Sửa giá bán',            'Đổi giá sản phẩm lúc tính tiền', 'POS'),
  'pos.view_history':   ('Xem lịch sử đơn',        'Xem toàn bộ đơn hàng cũ', 'POS'),
  'kho.edit_quantity':  ('Sửa số lượng tồn',       'Chỉnh tồn kho thủ công', 'Kho'),
  'kho.delete_item':    ('Xoá sản phẩm kho',       'Xoá vĩnh viễn khỏi kho', 'Kho'),
  'finance.view_all':   ('Xem toàn bộ thu chi',    'Xem doanh thu & chi phí', 'Thu Chi'),
  'report.view':        ('Xem báo cáo doanh thu',  'Xem KPI, thống kê', 'Báo Cáo'),
};

// Quyền action mặc định mỗi role (restrictive by default — owner luôn có tất cả)
const kDefaultActionPerms = <String, List<String>>{
  'owner':   ['pos.cancel_bill', 'pos.apply_discount', 'pos.edit_price', 'pos.view_history', 'kho.edit_quantity', 'kho.delete_item', 'finance.view_all', 'report.view'],
  'manager': ['pos.cancel_bill', 'pos.apply_discount', 'pos.view_history', 'kho.edit_quantity', 'finance.view_all', 'report.view'],
  'cashier': ['pos.apply_discount', 'pos.view_history'],
  'waiter':  <String>[],
  'kitchen': <String>[],
  'stock':   ['kho.edit_quantity'],
};

class StaffService {
  static SupabaseClient? get _db {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DANH SÁCH NHÂN VIÊN
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<StaffMember>> getStaffList(String storeId) async {
    final db = _db;
    if (db == null) return [];
    try {
      // 1. Lấy store_members + user_accounts
      final members = await db
          .from('store_members')
          .select('role, is_owner, user_id, shift_config_id, user_accounts(id, phone, display_name)')
          .eq('store_id', storeId);

      if (members.isEmpty) return [];

      final userIds = members.map((m) => m['user_id'] as String).toList();

      // 2. Lấy staff_profiles
      final profiles = await db
          .from('staff_profiles')
          .select('user_id, hourly_rate, base_salary, job_desc, start_date')
          .eq('store_id', storeId)
          .inFilter('user_id', userIds);

      final profileMap = { for (var p in profiles) p['user_id'] as String: p };

      // 3. Lấy ca đang mở (chưa clock_out)
      final activeShifts = await db
          .from('staff_shifts')
          .select('user_id')
          .eq('store_id', storeId)
          .isFilter('clock_out', null);

      final activeIds = { for (var s in activeShifts) s['user_id'] as String };

      // 4. Ghép kết quả
      // ‼️ FIX: null-safe cast — user_accounts có thể null nếu account bị xoá (orphan FK)
      final result = <StaffMember>[];
      for (final m in members) {
        final user = m['user_accounts'] as Map<String, dynamic>?;
        if (user == null) continue; // skip orphan member
        final userId  = user['id'] as String? ?? (m['user_id'] as String);
        final profile = profileMap[userId];
        result.add(StaffMember(
          userId:     userId,
          name:       user['display_name'] as String? ?? '',
          phone:      user['phone']        as String? ?? '',
          role:       m['role']            as String? ?? 'cashier',
          isOwner:    m['is_owner']        as bool?   ?? false,
          hourlyRate: (profile?['hourly_rate'] as num?)?.toDouble() ?? 0,
          baseSalary: (profile?['base_salary'] as num?)?.toDouble() ?? 0,
          jobDesc:    profile?['job_desc']  as String? ?? '',
          startDate:  profile?['start_date'] as String?,
          isClockedIn:   activeIds.contains(userId),
          shiftConfigId: m['shift_config_id'] as String?,
        ));
      }
      return result;
    } catch (e) {
      debugPrint('[StaffService] getStaffList error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // THÊM NHÂN VIÊN bằng SĐT
  // ══════════════════════════════════════════════════════════════════════════
  static Future<AddStaffResult> addStaffByPhone({
    required String storeId,
    required String phone,
    required String role,
    required String addedByUserId,
  }) async {
    final db = _db;
    if (db == null) return AddStaffResult.error('Không kết nối được server.');

    // ‼️ FIX Bug #31: ngăn gán role 'owner' qua API — bảo vệ defense-in-depth
    if (role.toLowerCase() == 'owner') {
      return AddStaffResult.error('Không thể gán vai trò Chủ quán cho nhân viên mới.');
    }


    // Chuẩn hoá SĐT — xử lý 3 dạng: 0xxx, 84xxx, +84xxx
    var p = phone.trim().replaceAll(RegExp(r'\s|-|\(|\)'), '');
    if (p.startsWith('0')) {
      p = '+84${p.substring(1)}';
    } else if (p.startsWith('84') && !p.startsWith('+84')) {
      // ‼️ FIX: nhập '84XXXXXXXXX' → '+84XXXXXXXXX'
      p = '+$p';
    }

    try {
      // Tìm user theo SĐT
      final userRes = await db
          .from('user_accounts')
          .select('id, display_name, phone')
          .eq('phone', p)
          .maybeSingle();

      if (userRes == null) {
        return AddStaffResult.error('Không tìm thấy tài khoản với số $phone.\nNhân viên cần tự đăng ký tài khoản trước.');
      }

      final userId   = userRes['id']           as String;
      final userName = userRes['display_name'] as String;

      // Kiểm tra đã là thành viên chưa
      final existing = await db
          .from('store_members')
          .select('id')
          .eq('store_id', storeId)
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        return AddStaffResult.error('$userName đã là thành viên của quán này.');
      }

      // Thêm vào store_members
      await db.from('store_members').insert({
        'user_id':  userId,
        'store_id': storeId,
        'role':     role,
        'is_owner': false,
      });

      // Tạo profile mặc định
      await db.from('staff_profiles').upsert({
        'user_id':  userId,
        'store_id': storeId,
        'job_desc': _defaultJobDesc(role),
        'start_date': DateTime.now().toIso8601String().split('T').first,
      }, onConflict: 'user_id,store_id');

      // Ghi log
      await _logPermChange(
        storeId:    storeId,
        byUser:     addedByUserId,
        targetUser: userId,
        action:     'add_staff',
        detail:     {'role': role, 'name': userName},
      );

      return AddStaffResult.success(userId: userId, userName: userName);
    } on PostgrestException catch (e) {
      debugPrint('[StaffService] addStaff PostgrestException: ${e.message} | code: ${e.code} | details: ${e.details}');
      return AddStaffResult.error('Lỗi: ${e.message}');
    } catch (e) {
      debugPrint('[StaffService] addStaff error: $e');
      return AddStaffResult.error('Lỗi: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // XOÁ NHÂN VIÊN
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> removeStaff({
    required String storeId,
    required String userId,
    required String removedByUserId,
    String staffName = '',
  }) async {
    final db = _db;
    if (db == null) return;
    await db.from('store_members')
        .delete()
        .eq('store_id', storeId)
        .eq('user_id', userId);
    await _logPermChange(
      storeId: storeId, byUser: removedByUserId, targetUser: userId,
      action: 'remove_staff', detail: {'name': staffName},
    );
    // Real-time: notify bị kick
    unawaited(StaffSyncService.broadcastStaffRemoved(
      storeId: storeId, targetUserId: userId));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ĐỔI ROLE
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> updateRole({
    required String storeId,
    required String userId,
    required String newRole,
    required String changedByUserId,
    String oldRole = '',
  }) async {
    final db = _db;
    if (db == null) return;
    // ‼️ FIX Bug #32: guard service layer — không bao giờ đấy NV thường lên role 'owner'
    if (newRole.toLowerCase() == 'owner') {
      debugPrint('[StaffService] updateRole blocked: cannot assign owner role');
      return;
    }
    await db.from('store_members')
        .update({'role': newRole})
        .eq('store_id', storeId)
        .eq('user_id', userId);
    await _logPermChange(
      storeId: storeId, byUser: changedByUserId, targetUser: userId,
      action: 'role_change', detail: {'old': oldRole, 'new': newRole},
    );
    // Real-time: notify nhân viên bị đổi role
    unawaited(StaffSyncService.broadcastRoleChanged(
      storeId: storeId, targetUserId: userId, newRole: newRole));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CẬP NHẬT HỒ SƠ
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> updateProfile({
    required String storeId,
    required String userId,
    double? hourlyRate,
    double? baseSalary,
    String? jobDesc,
    // ‼️ FIX: thêm startDate — trước đây UI đã có date picker nhưng service không nhận field này
    String? startDate,
  }) async {
    final db = _db;
    if (db == null) return;
    final data = <String, dynamic>{
      'user_id': userId, 'store_id': storeId,
    };
    if (hourlyRate != null) data['hourly_rate'] = hourlyRate;
    if (baseSalary != null) data['base_salary'] = baseSalary;
    if (jobDesc    != null) data['job_desc']     = jobDesc;
    if (startDate  != null) data['start_date']   = startDate;
    await db.from('staff_profiles')
        .upsert(data, onConflict: 'user_id,store_id');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CHẤM CÔNG
  // ══════════════════════════════════════════════════════════════════════════
  static Future<String?> clockIn(
    String userId,
    String storeId, {
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? driveFileId,
  }) async {
    final db = _db;
    if (db == null) return null;
    // Kiểm tra đã có ca mở chưa
    final open = await db.from('staff_shifts')
        .select('id')
        .eq('user_id', userId)
        .eq('store_id', storeId)
        .isFilter('clock_out', null)
        .maybeSingle();
    if (open != null) return open['id'] as String;
    final data = <String, dynamic>{
      'user_id':  userId,
      'store_id': storeId,
      'source':   'manual',
    };
    if (photoUrl    != null) data['photo_url']     = photoUrl;
    if (latitude    != null) data['latitude']      = latitude;
    if (longitude   != null) data['longitude']     = longitude;
    if (address     != null) data['address']       = address;
    if (driveFileId != null) data['drive_file_id'] = driveFileId;
    final res = await db.from('staff_shifts').insert(data).select('id').single();
    return res['id'] as String;
  }

  static Future<void> clockOut(
    String shiftId, {
    String? photoUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? driveFileId,
  }) async {
    final db = _db;
    if (db == null) return;
    final data = <String, dynamic>{
      'clock_out': DateTime.now().toUtc().toIso8601String(),
    };
    if (photoUrl    != null) data['photo_url_out']     = photoUrl;
    if (latitude    != null) data['latitude_out']      = latitude;
    if (longitude   != null) data['longitude_out']     = longitude;
    if (address     != null) data['address_out']       = address;
    if (driveFileId != null) data['drive_file_id_out'] = driveFileId;
    await db.from('staff_shifts').update(data).eq('id', shiftId);
  }

  // ── Manager: Sửa giờ vào/ra ca ──────────────────────────────────────────
  static Future<void> updateShift(
    String shiftId, {
    DateTime? clockIn,
    DateTime? clockOut,
  }) async {
    final db = _db;
    if (db == null) return;
    final data = <String, dynamic>{};
    if (clockIn  != null) data['clock_in']  = clockIn.toUtc().toIso8601String();
    if (clockOut != null) data['clock_out'] = clockOut.toUtc().toIso8601String();
    if (data.isEmpty) return;
    await db.from('staff_shifts').update(data).eq('id', shiftId);
  }

  static Future<String?> getOpenShiftId(String userId, String storeId) async {
    final db = _db;
    if (db == null) return null;
    final res = await db.from('staff_shifts')
        .select('id')
        .eq('user_id', userId)
        .eq('store_id', storeId)
        .isFilter('clock_out', null)
        .maybeSingle();
    return res?['id'] as String?;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LỊCH SỬ CHẤM CÔNG
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<ShiftRecord>> getShifts({
    required String storeId,
    String? userId,
    int limit = 50,
  }) async {
    final db = _db;
    if (db == null) return [];
    try {
      const sel = 'id, user_id, clock_in, clock_out, photo_url, address, latitude, longitude, drive_file_id';
      final List<dynamic> rows;
      if (userId != null) {
        rows = await db.from('staff_shifts')
            .select(sel)
            .eq('store_id', storeId)
            .eq('user_id', userId)
            .order('clock_in', ascending: false)
            .limit(limit);
      } else {
        rows = await db.from('staff_shifts')
            .select(sel)
            .eq('store_id', storeId)
            .order('clock_in', ascending: false)
            .limit(limit);
      }
      if (rows.isEmpty) return [];

      // Lấy tên nhân viên riêng (không dùng PostgREST join vì không có FK)
      final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
      final Map<String, String> nameMap = {};
      try {
        final users = await db.from('user_accounts')
            .select('id, display_name')
            .inFilter('id', userIds);
        for (final u in users) {
          nameMap[u['id'] as String] = u['display_name'] as String? ?? '';
        }
      } catch (_) {} // tên không bắt buộc

      return rows.map<ShiftRecord>((r) {
        return ShiftRecord(
          id:          r['id']       as String,
          userId:      r['user_id']  as String,
          userName:    nameMap[r['user_id'] as String] ?? '',
          // ‼️ FIX: parse UTC rồi convert sang local — tránh lệch ngày khi so sánh hôm nay
          clockIn:     DateTime.parse(r['clock_in'] as String).toLocal(),
          clockOut:    r['clock_out'] != null
              ? DateTime.parse(r['clock_out'] as String).toLocal() : null,
          source:      'manual',
          note:        '',
          photoUrl:    r['photo_url']    as String?,
          address:     r['address']      as String?,
          latitude:    (r['latitude']    as num?)?.toDouble(),
          longitude:   (r['longitude']   as num?)?.toDouble(),
          driveFileId: r['drive_file_id'] as String?,
        );
      }).toList();
    } catch (e, st) {
      // ignore: avoid_print
      debugPrint('[StaffService.getShifts] ERROR: $e\n$st');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // THỐNG KÊ THEO THÁNG
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<ShiftRecord>> getShiftsForMonth({
    required String storeId,
    String? userId,
    required int year,
    required int month,
  }) async {
    final db = _db;
    if (db == null) return [];
    try {
      final from = DateTime(year, month, 1).toUtc().toIso8601String();
      // ‼️ FIX Bug #30: explicit rollover — máy chủ Dart đúng nhưng explicit rõ ràng hơn
      final nextMonth = month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
      final to = nextMonth.toUtc().toIso8601String();
      final List<dynamic> rows;
      if (userId != null) {
        rows = await db.from('staff_shifts')
            // ‼️ FIX Bug #23: bỏ join user_accounts(display_name) thừa — đã query riêng bên dưới
            .select('id, user_id, clock_in, clock_out, source')
            .eq('store_id', storeId)
            .eq('user_id', userId)
            .gte('clock_in', from)
            .lt('clock_in', to)
            .order('clock_in', ascending: false);
      } else {
        rows = await db.from('staff_shifts')
            .select('id, user_id, clock_in, clock_out, source')
            .eq('store_id', storeId)
            .gte('clock_in', from)
            .lt('clock_in', to)
            .order('clock_in', ascending: false);
      }
      if (rows.isEmpty) return [];
      final userIds2 = rows.map((r) => r['user_id'] as String).toSet().toList();
      final Map<String, String> nm = {};
      try {
        final users = await db.from('user_accounts').select('id, display_name').inFilter('id', userIds2);
        for (final u in users) { nm[u['id'] as String] = u['display_name'] as String? ?? ''; }
      } catch (_) {}
      return rows.map<ShiftRecord>((r) {
        return ShiftRecord(
          id:       r['id']      as String,
          userId:   r['user_id'] as String,
          userName: nm[r['user_id'] as String] ?? '',
          // ‼️ FIX: parse UTC → toLocal, đồng bộ với getShifts()
          clockIn:  DateTime.parse(r['clock_in']  as String).toLocal(),
          clockOut: r['clock_out'] != null
              ? DateTime.parse(r['clock_out'] as String).toLocal() : null,
          source:   'manual',
          note:     '',
        );
      }).toList();
    } catch (e) { return []; }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PHÂN QUYỀN MODULE
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<String>> getModulePermissions(String storeId, String role) async {
    final db = _db;
    if (db == null) return List<String>.from(kDefaultPerms[role] ?? []);
    try {
      // 1. ƯU TIÊN: đọc từ store_roles.modules (hệ thống role động mới)
      final roleRow = await db.from('store_roles')
          .select('modules')
          .eq('store_id', storeId)
          .eq('name', role)
          .maybeSingle();
      if (roleRow != null && roleRow['modules'] != null) {
        final raw = roleRow['modules'];
        final mods = raw is List ? raw : (jsonDecode(raw as String) as List);
        return mods.cast<String>();
      }

      // 2. Fallback: app_settings perm_role (hệ thống cũ)
      final res = await db.from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', 'perm_$role')
          .maybeSingle();
      if (res != null) {
        final decoded = jsonDecode(res['value'] as String) as List;
        return decoded.cast<String>();
      }

      // 3. Fallback cuối: kDefaultPerms (hardcoded)
      return List<String>.from(kDefaultPerms[role] ?? []);
    } catch (e) {
      debugPrint('[StaffService] getModulePermissions error: $e');
      return List<String>.from(kDefaultPerms[role] ?? []);
    }
  }

  static Future<void> setModulePermissions({
    required String storeId,
    required String role,
    required List<String> modules,
    required String changedByUserId,
  }) async {
    final db = _db;
    if (db == null) return;

    // ‼️ BUG FIX: Trước đây ghi vào app_settings (hệ thống cũ) — nay ghi vào store_roles.modules
    // Chẹy 2 việc: (1) update store_roles.modules, (2) upsert app_settings làm backup
    try {
      // 1. Cập nhật store_roles.modules (nguồn chính xác — getModulePermissions đọc từ đây)
      await db.from('store_roles')
          .update({'modules': jsonEncode(modules)})
          .eq('store_id', storeId)
          .eq('name', role);
    } catch (e) {
      debugPrint('[StaffService] setModulePermissions store_roles update error: $e');
    }
    try {
      // 2. Backup vào app_settings (tương thích ngược — có thể bỏ sau này)
      await db.from('app_settings').upsert({
        'store_id': storeId,
        'key':      'perm_$role',
        'value':    jsonEncode(modules),
      }, onConflict: 'store_id,key');
    } catch (_) {} // silent — đây chỉ là backup

    await _logPermChange(
      storeId: storeId, byUser: changedByUserId,
      action: 'perm_change',
      detail: {'role': role, 'modules': modules},
    );
    // Real-time: notify tất cả nhân viên có role này
    unawaited(StaffSyncService.broadcastPermsChanged(
      storeId: storeId, role: role));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PHÂN QUYỀN HÀNH ĐỘNG (Action-level) — lưu vào app_settings
  // ══════════════════════════════════════════════════════════════════════════

  /// Lấy danh sách action được phép của một role.
  /// Fallback: kDefaultActionPerms nếu chưa cấu hình.
  static Future<Set<String>> getActionPermissions(String storeId, String role) async {
    // Owner luôn có toàn quyền — không cần query DB
    if (role == 'owner') {
      return Set<String>.from(kAllActions);
    }
    final db = _db;
    if (db == null) {
      return guessDefaultPermsForRole(role); // offline fallback
    }
    try {
      final res = await db.from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', 'action_perms_$role')
          .maybeSingle();
      if (res != null) {
        final decoded = jsonDecode(res['value'] as String) as List;
        return decoded.cast<String>().toSet();
      }
    } catch (e) {
      debugPrint('[StaffService] getActionPermissions error: $e');
    }
    // Fallback: guess từ tên vai trò (tiếng Việt) thay vì canonical key
    return guessDefaultPermsForRole(role);
  }

  /// Đoán action permissions mặc định từ tên vai trò tiếng Việt phổ biến.
  /// Dùng khi role mới được tạo — auto-seed để NV có quyền hành động hợp lý ngay.
  static Set<String> guessDefaultPermsForRole(String roleName) {
    final n = roleName.toLowerCase().trim();
    // Thu ngân / Cashier
    if (n.contains('thu ngân') || n.contains('cashier') || n.contains('quầy')) {
      return Set<String>.from(kDefaultActionPerms['cashier'] ?? []);
    }
    // Quản lý / Manager
    if (n.contains('quản lý') || n.contains('manager') ||
        n.contains('trưởng') || n.contains('giám sát')) {
      return Set<String>.from(kDefaultActionPerms['manager'] ?? []);
    }
    // Kho / Stock
    if (n.contains('kho') || n.contains('stock') || n.contains('tồn kho')) {
      return Set<String>.from(kDefaultActionPerms['stock'] ?? []);
    }
    // Bếp / Kitchen
    if (n.contains('bếp') || n.contains('kitchen') ||
        n.contains('đầu bếp') || n.contains('nấu')) {
      return Set<String>.from(kDefaultActionPerms['kitchen'] ?? []);
    }
    // Mặc định: không có quyền đặc biệt (phục vụ, bảo vệ, giao hàng...)
    return <String>{};
  }

  /// Lưu danh sách action permissions cho một role.
  /// [changedByUserId] mặc định là 'system' khi auto-seed lúc tạo role.
  static Future<void> setActionPermissions({
    required String storeId,
    required String role,
    required Set<String> actions,
    String changedByUserId = 'system',
  }) async {
    final db = _db;
    if (db == null || role == 'owner') return; // owner không thể bị giới hạn

    try {
      await db.from('app_settings').upsert({
        'store_id': storeId,
        'key':      'action_perms_$role',
        'value':    jsonEncode(actions.toList()),
      }, onConflict: 'store_id,key');
    } catch (e) {
      debugPrint('[StaffService] setActionPermissions error: $e');
    }

    await _logPermChange(
      storeId: storeId, byUser: changedByUserId,
      action: 'action_perm_change',
      detail: {'role': role, 'actions': actions.toList()},
    );
    // Real-time sync
    unawaited(StaffSyncService.broadcastPermsChanged(
      storeId: storeId, role: role));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LỊCH SỬ QUYỀN
  // ══════════════════════════════════════════════════════════════════════════
  static Future<List<PermLog>> getPermLogs(String storeId) async {
    final db = _db;
    if (db == null) return [];
    try {
      final rows = await db.from('staff_perm_logs')
          .select('id, action, detail, created_at, by_user, target_user, user_accounts!by_user(display_name)')
          .eq('store_id', storeId)
          .order('created_at', ascending: false)
          .limit(30);
      return rows.map<PermLog>((r) {
        final byUser = r['user_accounts'] as Map<String, dynamic>?;
        return PermLog(
          id:        r['id']         as String,
          action:    r['action']     as String? ?? '',
          detail:    r['detail']     as String? ?? '{}',
          createdAt: DateTime.parse(r['created_at'] as String),
          byUserName: byUser?['display_name'] as String? ?? '',
        );
      }).toList();
    } catch (_) { return []; }
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  static Future<void> _logPermChange({
    required String storeId,
    required String byUser,
    String? targetUser,
    required String action,
    required Map<String, dynamic> detail,
  }) async {
    try {
      await _db?.from('staff_perm_logs').insert({
        'store_id':    storeId,
        'by_user':     byUser,
        'target_user': targetUser,
        'action':      action,
        'detail':      jsonEncode(detail),
      });
    } catch (_) {}
  }

  static String _defaultJobDesc(String role) {
    switch (role) {
      case 'manager': return 'Quản lý quán, hỗ trợ chủ quán điều hành và xử lý vấn đề phát sinh.';
      case 'cashier': return 'Tiếp nhận đơn hàng, thanh toán và chăm sóc khách hàng tại quầy.';
      case 'waiter':  return 'Phục vụ tại bàn, ghi nhận order và mang đồ uống/thức ăn cho khách.';
      case 'kitchen': return 'Chuẩn bị và chế biến đồ uống/thức ăn theo phiếu bếp.';
      case 'stock':   return 'Quản lý tồn kho, nhập hàng và kiểm tra nguyên liệu.';
      default: return '';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STORE ROLES CRUD
// ─────────────────────────────────────────────────────────────────────────────
extension StoreRolesService on StaffService {
  // placeholder — see static methods below
}

class StoreRoleService {
  static SupabaseClient? get _db {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  // ── Lấy danh sách role của quán ──────────────────────────────────────────
  static Future<List<StoreRole>> getRoles(String storeId) async {
    final db = _db;
    if (db == null) return [];
    try {
      final rows = await db
          .from('store_roles')
          .select()
          .eq('store_id', storeId)
          .order('sort_order')
          .order('created_at');
      return rows.map<StoreRole>((r) => StoreRole.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[StoreRoleService] getRoles error: $e');
      return [];
    }
  }

  // ── Tạo role mới ─────────────────────────────────────────────────────────
  static Future<StoreRole?> createRole({
    required String storeId,
    required String name,
    required String icon,
    required String color,
    required List<String> modules,
  }) async {
    final db = _db;
    if (db == null) return null;
    try {
      final res = await db.from('store_roles').insert({
        'store_id': storeId,
        'name':     name.trim(),
        'icon':     icon,
        'color':    color,
        'modules':  jsonEncode(modules),
      }).select().single();
      final role = StoreRole.fromMap(res);

      // 🔑 Auto-seed action permissions với defaults phù hợp tên vai trò.
      // Đảm bảo NV được gán role này có quyền hành động hợp lý ngay khi tạo,
      // không cần chủ quán phải vào Phân quyền → Hành động nhạy cảm → Lưu thủ công.
      unawaited(StaffService.setActionPermissions(
        storeId: storeId,
        role:    role.name,
        actions: StaffService.guessDefaultPermsForRole(role.name),
      ));

      return role;
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw Exception('Tên vai trò "$name" đã tồn tại');
      rethrow;
    }
  }

  // ── Cập nhật role ────────────────────────────────────────────────────────
  static Future<void> updateRole({
    required String roleId,
    String? name,
    String? icon,
    String? color,
    List<String>? modules,
  }) async {
    final db = _db;
    if (db == null) return;
    final data = <String, dynamic>{};
    if (name    != null) data['name']    = name.trim();
    if (icon    != null) data['icon']    = icon;
    if (color   != null) data['color']   = color;
    if (modules != null) data['modules'] = jsonEncode(modules);
    if (data.isEmpty) return;
    await db.from('store_roles').update(data).eq('id', roleId);
  }

  // ── Xoá role — tự động reassign NV sang role đầu tiên còn lại ───────────
  static Future<void> deleteRole({
    required String roleId,
    required String storeId,
    required String roleName,
  }) async {
    final db = _db;
    if (db == null) return;

    // Tìm role thay thế (role đầu tiên không phải role đang xoá)
    final others = await db
        .from('store_roles')
        .select('name')
        .eq('store_id', storeId)
        .neq('id', roleId)
        .order('sort_order')
        .limit(1);

    final fallbackRole = others.isNotEmpty
        ? others.first['name'] as String
        : 'member'; // mặc định nếu không còn role nào

    // Reassign tất cả NV đang dùng role này
    await db
        .from('store_members')
        .update({'role': fallbackRole})
        .eq('store_id', storeId)
        .eq('role', roleName);

    // Xoá role
    await db.from('store_roles').delete().eq('id', roleId);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────
class StaffMember {
  final String  userId;
  final String  name;
  final String  phone;
  final String  role;
  final bool    isOwner;
  final double  hourlyRate;
  final double  baseSalary;
  final String  jobDesc;
  final String? startDate;
  final bool    isClockedIn;
  final String? shiftConfigId; // Ca làm việc được assign

  const StaffMember({
    required this.userId,
    required this.name,
    required this.phone,
    required this.role,
    required this.isOwner,
    required this.hourlyRate,
    required this.baseSalary,
    required this.jobDesc,
    this.startDate,
    required this.isClockedIn,
    this.shiftConfigId,
  });
}

class ShiftRecord {
  final String    id;
  final String    userId;
  final String    userName;
  final DateTime  clockIn;
  final DateTime? clockOut;
  final String    source;
  final String    note;
  final String?   photoUrl;   // ảnh vào ca
  final double?   latitude;
  final double?   longitude;
  final String?   address;    // địa chỉ văn bản
  final String?   driveFileId;

  Duration get duration {
    final raw = (clockOut ?? DateTime.now()).difference(clockIn);
    // ‼️ FIX: guard âm khi server time lệch local — duration không bao giờ < 0
    return raw.isNegative ? Duration.zero : raw;
  }

  String get durationStr {
    final h = duration.inHours;
    final m = duration.inMinutes % 60;
    return h > 0 ? '${h}h${m.toString().padLeft(2, '0')}' : '${m}p';
  }

  bool get isOpen => clockOut == null;

  const ShiftRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.clockIn,
    this.clockOut,
    required this.source,
    required this.note,
    this.photoUrl,
    this.latitude,
    this.longitude,
    this.address,
    this.driveFileId,
  });
}

class AddStaffResult {
  final bool    isSuccess;
  final String? userId;
  final String? userName;
  final String? errorMessage;

  const AddStaffResult._({required this.isSuccess, this.userId, this.userName, this.errorMessage});
  factory AddStaffResult.success({required String userId, required String userName}) =>
      AddStaffResult._(isSuccess: true, userId: userId, userName: userName);
  factory AddStaffResult.error(String msg) =>
      AddStaffResult._(isSuccess: false, errorMessage: msg);
}

class PermLog {
  final String   id;
  final String   action;
  final String   detail;
  final DateTime createdAt;
  final String   byUserName;

  const PermLog({
    required this.id,
    required this.action,
    required this.detail,
    required this.createdAt,
    required this.byUserName,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// StoreRole — vai trò tùy chỉnh của quán
// ─────────────────────────────────────────────────────────────────────────────
class StoreRole {
  final String       id;
  final String       storeId;
  final String       name;
  final String       icon;     // tên Material icon
  final String       color;    // hex string '#RRGGBB'
  final List<String> modules;  // ['pos','ban',...]

  const StoreRole({
    required this.id,
    required this.storeId,
    required this.name,
    required this.icon,
    required this.color,
    required this.modules,
  });

  factory StoreRole.fromMap(Map<String, dynamic> m) {
    List<String> mods = [];
    try {
      final raw = m['modules'];
      if (raw is String && raw.isNotEmpty) {
        mods = (jsonDecode(raw) as List).cast<String>();
      }
    } catch (_) {}
    return StoreRole(
      id:      m['id']       as String,
      storeId: m['store_id'] as String,
      name:    m['name']     as String,
      icon:    m['icon']     as String? ?? 'badge',
      color:   m['color']    as String? ?? '#1C2151',
      modules: mods,
    );
  }

  /// Chuyển hex '#RRGGBB' → Color
  Color get colorValue {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return const Color(0xFF1C2151);
    }
  }

  StoreRole copyWith({
    String? name, String? icon, String? color, List<String>? modules,
  }) => StoreRole(
    id: id, storeId: storeId,
    name:    name    ?? this.name,
    icon:    icon    ?? this.icon,
    color:   color   ?? this.color,
    modules: modules ?? this.modules,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIFT CONFIG — Ca làm việc theo giờ
// ─────────────────────────────────────────────────────────────────────────────
class ShiftConfig {
  final String id;
  final String storeId;
  final String name;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String color;
  final int sortOrder;
  final bool isActive;

  const ShiftConfig({
    required this.id,
    required this.storeId,
    required this.name,
    required this.startHour,
    this.startMinute = 0,
    required this.endHour,
    this.endMinute = 0,
    this.color = '#1C2151',
    this.sortOrder = 0,
    this.isActive = true,
  });

  factory ShiftConfig.fromMap(Map<String, dynamic> m) => ShiftConfig(
    id:          m['id']            as String,
    storeId:     m['store_id']      as String,
    name:        m['name']          as String,
    startHour:   (m['start_hour']   as num).toInt(),
    startMinute: (m['start_minute'] as num?)?.toInt() ?? 0,
    endHour:     (m['end_hour']     as num).toInt(),
    endMinute:   (m['end_minute']   as num?)?.toInt() ?? 0,
    color:       m['color']         as String? ?? '#1C2151',
    sortOrder:   (m['sort_order']   as num?)?.toInt() ?? 0,
    isActive:    m['is_active']     as bool? ?? true,
  );

  /// Label giờ VD: "06:00 – 14:00"
  String get timeLabel {
    final s = '${startHour.toString().padLeft(2,'0')}:${startMinute.toString().padLeft(2,'0')}';
    final e = '${endHour.toString().padLeft(2,'0')}:${endMinute.toString().padLeft(2,'0')}';
    return '$s – $e';
  }

  Color get colorValue {
    try {
      final hex = color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) { return const Color(0xFF1C2151); }
  }

  /// Kiểm tra giờ hiện tại có thuộc ca này không
  bool isCurrentShift(DateTime now) {
    final nowMins   = now.hour * 60 + now.minute;
    final startMins = startHour * 60 + startMinute;
    final endMins   = endHour   * 60 + endMinute;
    if (startMins < endMins) {
      return nowMins >= startMins && nowMins < endMins;   // Ca bình thường
    } else {
      return nowMins >= startMins || nowMins < endMins;   // Ca qua đêm
    }
  }

  ShiftConfig copyWith({
    String? name, int? startHour, int? startMinute,
    int? endHour, int? endMinute, String? color, int? sortOrder,
  }) => ShiftConfig(
    id: id, storeId: storeId,
    name:        name        ?? this.name,
    startHour:   startHour   ?? this.startHour,
    startMinute: startMinute ?? this.startMinute,
    endHour:     endHour     ?? this.endHour,
    endMinute:   endMinute   ?? this.endMinute,
    color:       color       ?? this.color,
    sortOrder:   sortOrder   ?? this.sortOrder,
    isActive:    isActive,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIFT CONFIG SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class ShiftConfigService {
  static SupabaseClient? get _db {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  static const _kDefault = [
    (n: 'Ca sáng',  sh: 6,  sm: 0, eh: 14, em: 0, c: '#0EA5E9', o: 0),
    (n: 'Ca chiều', sh: 14, sm: 0, eh: 22, em: 0, c: '#F59E0B', o: 1),
    (n: 'Ca tối',   sh: 22, sm: 0, eh: 6,  em: 0, c: '#8B5CF6', o: 2),
  ];

  /// Lấy danh sách ca — tự seed mặc định nếu chưa có
  static Future<List<ShiftConfig>> getShifts(String storeId) async {
    final db = _db;
    if (db == null || storeId.isEmpty) return [];
    try {
      final rows = await db
          .from('store_shift_configs')
          .select()
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('sort_order');
      if (rows.isEmpty) {
        await _seed(db, storeId);
        final seeded = await db
            .from('store_shift_configs')
            .select()
            .eq('store_id', storeId)
            .eq('is_active', true)
            .order('sort_order');
        return seeded.map<ShiftConfig>(ShiftConfig.fromMap).toList();
      }
      return rows.map<ShiftConfig>(ShiftConfig.fromMap).toList();
    } catch (e) {
      debugPrint('[ShiftConfigService] getShifts: $e');
      return [];
    }
  }

  static Future<void> _seed(SupabaseClient db, String storeId) async {
    try {
      await db.from('store_shift_configs').insert(
        _kDefault.map((s) => {
          'store_id': storeId, 'name': s.n,
          'start_hour': s.sh, 'start_minute': s.sm,
          'end_hour': s.eh,   'end_minute': s.em,
          'color': s.c, 'sort_order': s.o, 'is_active': true,
        }).toList(),
      );
    } catch (e) { debugPrint('[ShiftConfigService] seed: $e'); }
  }

  static Future<ShiftConfig?> createShift({
    required String storeId, required String name,
    required int startHour, required int startMinute,
    required int endHour,   required int endMinute,
    required String color,  int sortOrder = 99,
  }) async {
    final db = _db;
    if (db == null) throw Exception('DB chưa khởi tạo');
    final res = await db.from('store_shift_configs').insert({
      'store_id': storeId, 'name': name.trim(),
      'start_hour': startHour, 'start_minute': startMinute,
      'end_hour': endHour,     'end_minute': endMinute,
      'color': color, 'sort_order': sortOrder, 'is_active': true,
    }).select().single();
    return ShiftConfig.fromMap(res);
  }

  static Future<void> updateShift({
    required String shiftId,
    String? name, int? startHour, int? startMinute,
    int? endHour, int? endMinute, String? color,
  }) async {
    final db = _db;
    if (db == null) return;
    final d = <String, dynamic>{};
    if (name        != null) d['name']         = name.trim();
    if (startHour   != null) d['start_hour']   = startHour;
    if (startMinute != null) d['start_minute'] = startMinute;
    if (endHour     != null) d['end_hour']     = endHour;
    if (endMinute   != null) d['end_minute']   = endMinute;
    if (color       != null) d['color']        = color;
    if (d.isEmpty) return;
    await db.from('store_shift_configs').update(d).eq('id', shiftId);
  }

  static Future<void> deleteShift(String shiftId) async =>
      (await _db?.from('store_shift_configs')
          .update({'is_active': false}).eq('id', shiftId));

  /// Assign 1 ca cho 1 nhân viên (1 nhân viên chỉ thuộc 1 ca)
  static Future<void> assignShiftToStaff({
    required String storeId,
    required String userId,
    String? shiftConfigId,
  }) async {
    final db = _db;
    if (db == null) return;
    await db
        .from('store_members')
        .update({'shift_config_id': shiftConfigId})
        .eq('store_id', storeId)
        .eq('user_id', userId);
  }
}

