// lib/modules/tinhluong/repository/shift_template_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Ca Cố Định — Shift Template Repository
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Models ──────────────────────────────────────────────────────────────────

class ShiftTemplate {
  final String id;
  final String storeId;
  final String name;          // "Ca sáng"
  final String startTime;     // "06:00"
  final String endTime;       // "14:00"
  final String color;         // "#F59E0B"
  final int lateGraceMinutes; // cho phép trễ tối đa X phút
  final bool isActive;
  final int sortOrder;

  const ShiftTemplate({
    required this.id,
    required this.storeId,
    required this.name,
    required this.startTime,
    required this.endTime,
    required this.color,
    required this.lateGraceMinutes,
    required this.isActive,
    required this.sortOrder,
  });

  factory ShiftTemplate.fromMap(Map<String, dynamic> m) => ShiftTemplate(
        id:                m['id']    as String,
        storeId:           m['store_id'] as String,
        name:              m['name']  as String,
        startTime:         (m['start_time'] as String).substring(0, 5), // "06:00"
        endTime:           (m['end_time']   as String).substring(0, 5),
        color:             m['color'] as String? ?? '#1C2151',
        lateGraceMinutes:  m['late_grace_minutes'] as int? ?? 15,
        isActive:          m['is_active'] as bool? ?? true,
        sortOrder:         m['sort_order'] as int? ?? 0,
      );

  /// Giờ bắt đầu dưới dạng TimeOfDay-compatible (HH, mm)
  int get startHour   => int.parse(startTime.split(':')[0]);
  int get startMinute => int.parse(startTime.split(':')[1]);
  int get endHour     => int.parse(endTime.split(':')[0]);
  int get endMinute   => int.parse(endTime.split(':')[1]);

  /// Tổng số phút ca làm (có thể qua đêm)
  int get durationMinutes {
    final start = startHour * 60 + startMinute;
    var   end   = endHour   * 60 + endMinute;
    if (end <= start) end += 24 * 60; // qua nửa đêm
    return end - start;
  }

  String get durationStr {
    final h = durationMinutes ~/ 60;
    final m = durationMinutes % 60;
    return m > 0 ? '${h}h${m}p' : '${h}h';
  }
}

class ShiftAssignment {
  final String         id;
  final String         storeId;
  final String         userId;
  final String         userName;
  final String         templateId;
  final ShiftTemplate? template;
  final DateTime       assignedDate;
  final String?        note;

  const ShiftAssignment({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.userName,
    required this.templateId,
    this.template,
    required this.assignedDate,
    this.note,
  });

  factory ShiftAssignment.fromMap(
      Map<String, dynamic> m, {
      Map<String, ShiftTemplate>? templateMap,
      Map<String, String>? nameMap,
  }) {
    final tid = m['template_id'] as String;
    return ShiftAssignment(
      id:           m['id']       as String,
      storeId:      m['store_id'] as String,
      userId:       m['user_id']  as String,
      userName:     nameMap?[m['user_id'] as String] ?? '',
      templateId:   tid,
      template:     templateMap?[tid],
      assignedDate: DateTime.parse(m['assigned_date'] as String),
      note:         m['note'] as String?,
    );
  }
}

/// Kết quả phát hiện đi muộn
class LateDetectionResult {
  final bool   isLate;
  final int    lateMinutes;     // số phút muộn (0 nếu không muộn)
  final String? templateId;    // ca được phân công
  final String? assignmentId;  // id phân công

  const LateDetectionResult({
    required this.isLate,
    required this.lateMinutes,
    this.templateId,
    this.assignmentId,
  });

  static const LateDetectionResult noShift = LateDetectionResult(
    isLate: false, lateMinutes: 0);
}

// ─── Repository ──────────────────────────────────────────────────────────────

class ShiftTemplateRepository {
  static SupabaseClient? get _db {
    try { return Supabase.instance.client; } catch (_) { return null; }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHIFT TEMPLATES CRUD
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<ShiftTemplate>> getTemplates(String storeId) async {
    final db = _db;
    if (db == null) return [];
    try {
      final rows = await db
          .from('shift_templates')
          .select()
          .eq('store_id', storeId)
          .eq('is_active', true)
          .order('sort_order')
          .order('created_at');
      return rows.map<ShiftTemplate>((r) => ShiftTemplate.fromMap(r)).toList();
    } catch (e) {
      debugPrint('[ShiftTemplateRepository] getTemplates error: $e');
      return [];
    }
  }

  static Future<ShiftTemplate?> createTemplate({
    required String storeId,
    required String name,
    required String startTime,  // "06:00"
    required String endTime,    // "14:00"
    String  color              = '#1C2151',
    int     lateGraceMinutes   = 15,
    int     sortOrder          = 0,
  }) async {
    final db = _db;
    if (db == null) return null;
    try {
      final res = await db.from('shift_templates').insert({
        'store_id':            storeId,
        'name':                name.trim(),
        'start_time':          startTime,
        'end_time':            endTime,
        'color':               color,
        'late_grace_minutes':  lateGraceMinutes,
        'sort_order':          sortOrder,
      }).select().single();
      return ShiftTemplate.fromMap(res);
    } catch (e) {
      debugPrint('[ShiftTemplateRepository] createTemplate error: $e');
      return null;
    }
  }

  static Future<void> updateTemplate(String id, {
    String? name,
    String? startTime,
    String? endTime,
    String? color,
    int?    lateGraceMinutes,
    int?    sortOrder,
    bool?   isActive,
  }) async {
    final db = _db;
    if (db == null) return;
    final data = <String, dynamic>{};
    if (name             != null) data['name']               = name.trim();
    if (startTime        != null) data['start_time']         = startTime;
    if (endTime          != null) data['end_time']           = endTime;
    if (color            != null) data['color']              = color;
    if (lateGraceMinutes != null) data['late_grace_minutes'] = lateGraceMinutes;
    if (sortOrder        != null) data['sort_order']         = sortOrder;
    if (isActive         != null) data['is_active']          = isActive;
    if (data.isEmpty) return;
    await db.from('shift_templates').update(data).eq('id', id);
  }

  static Future<void> deleteTemplate(String id) async {
    final db = _db;
    if (db == null) return;
    // Soft delete — set is_active = false
    await db.from('shift_templates')
        .update({'is_active': false}).eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHIFT ASSIGNMENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lấy phân công ca theo ngày (hoặc khoảng ngày)
  static Future<List<ShiftAssignment>> getAssignments({
    required String storeId,
    DateTime? date,
    DateTime? fromDate,
    DateTime? toDate,
    String?   userId,
  }) async {
    final db = _db;
    if (db == null) return [];
    try {
      // 1. Lấy templates để map
      final templates = await getTemplates(storeId);
      final templateMap = {for (final t in templates) t.id: t};

      // 2. Query assignments
      var query = db.from('shift_assignments')
          .select('*')
          .eq('store_id', storeId);

      if (date != null) {
        final d = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
        query = query.eq('assigned_date', d);
      } else {
        if (fromDate != null) {
          query = query.gte('assigned_date', fromDate.toIso8601String().split('T').first);
        }
        if (toDate != null) {
          query = query.lte('assigned_date', toDate.toIso8601String().split('T').first);
        }
      }
      if (userId != null) query = query.eq('user_id', userId);

      final rows = await (query as PostgrestFilterBuilder).order('assigned_date').order('created_at');

      // 3. Lấy tên NV
      if (rows.isEmpty) return [];
      final userIds = rows.map((r) => r['user_id'] as String).toSet().toList();
      final Map<String, String> nameMap = {};
      try {
        final users = await db.from('user_accounts')
            .select('id, display_name')
            .inFilter('id', userIds);
        for (final u in users) {
          nameMap[u['id'] as String] = u['display_name'] as String? ?? '';
        }
      } catch (_) {}

      return rows.map<ShiftAssignment>((r) => ShiftAssignment.fromMap(
        r, templateMap: templateMap, nameMap: nameMap)).toList();
    } catch (e) {
      debugPrint('[ShiftTemplateRepository] getAssignments error: $e');
      return [];
    }
  }

  /// Phân công ca cho nhân viên
  static Future<bool> assignShift({
    required String storeId,
    required String userId,
    required String templateId,
    required DateTime date,
    String? note,
    String? createdBy,
  }) async {
    final db = _db;
    if (db == null) return false;
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
      await db.from('shift_assignments').upsert({
        'store_id':      storeId,
        'user_id':       userId,
        'template_id':   templateId,
        'assigned_date': dateStr,
        'note':          note,
        'created_by':    createdBy,
      }, onConflict: 'store_id,user_id,assigned_date');
      return true;
    } catch (e) {
      debugPrint('[ShiftTemplateRepository] assignShift error: $e');
      return false;
    }
  }

  static Future<void> deleteAssignment(String id) async {
    final db = _db;
    if (db == null) return;
    await db.from('shift_assignments').delete().eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LATE DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Phát hiện đi muộn khi NV clock-in
  /// So giờ clock-in thực tế với ca được phân công hôm đó
  static Future<LateDetectionResult> detectLateArrival({
    required String   storeId,
    required String   userId,
    required DateTime clockInTime, // giờ local
  }) async {
    final db = _db;
    if (db == null) return LateDetectionResult.noShift;
    try {
      final today = DateTime(clockInTime.year, clockInTime.month, clockInTime.day);
      final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';

      // Tìm ca được phân công hôm nay
      final row = await db
          .from('shift_assignments')
          .select('id, template_id')
          .eq('store_id', storeId)
          .eq('user_id', userId)
          .eq('assigned_date', dateStr)
          .maybeSingle();

      if (row == null) return LateDetectionResult.noShift; // không phân công → không tính muộn

      final templateId = row['template_id'] as String;
      final assignId   = row['id'] as String;

      // Lấy template
      final tRow = await db
          .from('shift_templates')
          .select('start_time, late_grace_minutes')
          .eq('id', templateId)
          .maybeSingle();
      if (tRow == null) return LateDetectionResult.noShift;

      final startParts      = (tRow['start_time'] as String).split(':');
      final shiftStartHour  = int.parse(startParts[0]);
      final shiftStartMin   = int.parse(startParts[1]);
      final graceMinutes    = tRow['late_grace_minutes'] as int? ?? 15;

      // Tính deadline = giờ bắt đầu ca + grace
      final deadline = DateTime(today.year, today.month, today.day,
          shiftStartHour, shiftStartMin)
          .add(Duration(minutes: graceMinutes));

      if (clockInTime.isBefore(deadline) || clockInTime.isAtSameMomentAs(deadline)) {
        // Đúng giờ hoặc trong grace period
        return LateDetectionResult(
          isLate: false, lateMinutes: 0,
          templateId: templateId, assignmentId: assignId);
      }

      final lateMinutes = clockInTime.difference(deadline).inMinutes;
      return LateDetectionResult(
        isLate: true, lateMinutes: lateMinutes,
        templateId: templateId, assignmentId: assignId);
    } catch (e) {
      debugPrint('[ShiftTemplateRepository] detectLateArrival error: $e');
      return LateDetectionResult.noShift;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SEED DỮ LIỆU MẪU (gọi khi tạo quán mới)
  // ═══════════════════════════════════════════════════════════════════════════
  static Future<void> seedDefaultTemplates(String storeId) async {
    final existing = await getTemplates(storeId);
    if (existing.isNotEmpty) return; // đã có rồi, không seed lại

    final defaults = [
      ('Ca sáng',  '06:00', '14:00', '#F59E0B', 1),
      ('Ca chiều', '14:00', '22:00', '#3B82F6', 2),
      ('Ca tối',   '17:00', '23:00', '#8B5CF6', 3),
    ];
    for (final (name, start, end, color, order) in defaults) {
      await createTemplate(
        storeId: storeId, name: name,
        startTime: start, endTime: end,
        color: color, sortOrder: order,
      );
    }
  }
}
