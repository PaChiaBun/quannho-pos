import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/store_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// OPS REPOSITORY — Nhật Ký Vận Hành
// 100% Supabase, log riêng từng nhân viên
// ─────────────────────────────────────────────────────────────────────────────
class OpsRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'];
  }

  // ── Store Roles (để bind template) ────────────────────────────────────────

  Future<List<OpsRoleModel>> getStoreRoles() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final rows = await _sb
        .from('store_roles')
        .select('id, name, color, icon')
        .eq('store_id', storeId)
        .order('name');
    return rows.map(OpsRoleModel.fromMap).toList();
  }

  // ── Templates ──────────────────────────────────────────────────────────────

  Stream<T> _robustStream<T>(
    String table,
    String columnFilter,
    String valueFilter,
    T Function(List<Map<String, dynamic>>) mapper,
  ) async* {
    Future<T> fetch() async {
      final rows = await _sb.from(table).select().eq(columnFilter, valueFilter);
      return mapper(rows);
    }

    // Initial fetch
    try {
      yield await fetch();
    } catch (e) {
      print('[RobustStream] Initial fetch err on $table: $e');
    }

    // Realtime connection with fallback to polling on async errors (e.g. RealtimeSubscribeException)
    while (true) {
      try {
        final stream = _sb.from(table).stream(primaryKey: ['id']).eq(columnFilter, valueFilter);
        await for (final rows in stream) {
          yield mapper(rows);
        }
      } catch (e) {
        print('[RobustStream] Realtime err on $table: $e. Falling back to poll 10s.');
        
        // Polling âm thầm 10 giây (chia làm 2 lần 5s) trước khi thử kết nối lại Realtime
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
        
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
      }
    }
  }

  /// Stream tất cả templates (active) — kèm join tên role (manager view)
  Stream<List<OpsTaskTemplateModel>> watchTemplates() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    final roles = await getStoreRoles();
    final roleMap = {for (final r in roles) r.id: r};

    yield* _robustStream(
      'ops_task_templates', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['is_active'] == true)
          .map((r) => OpsTaskTemplateModel.fromMap(r, roleMap))
          .toList()
        ..sort((a, b) {
          final roleCompare = (a.roleName ?? 'zzz').compareTo(b.roleName ?? 'zzz');
          if (roleCompare != 0) return roleCompare;
          return a.sortOrder.compareTo(b.sortOrder);
        })
    );
  }

  /// Stream tất cả templates không lọc role — dùng cho nhân viên (filter client-side)
  Stream<List<OpsTaskTemplateModel>> watchAllTemplates() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    final roles = await getStoreRoles();
    final roleMap = {for (final r in roles) r.id: r};

    yield* _robustStream(
      'ops_task_templates', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['is_active'] == true)
          .map((r) => OpsTaskTemplateModel.fromMap(r, roleMap))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))
    );
  }

  /// Templates dành cho 1 role cụ thể (và templates không gán role nào)
  Stream<List<OpsTaskTemplateModel>> watchTemplatesForRole(String? storeRoleId) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    final roles = await getStoreRoles();
    final roleMap = {for (final r in roles) r.id: r};

    yield* _robustStream(
      'ops_task_templates', 'store_id', storeId,
      (rows) => rows
          .where((r) =>
              r['is_active'] == true &&
              (r['store_role_id'] == null ||
               r['store_role_id'] == storeRoleId))
          .map((r) => OpsTaskTemplateModel.fromMap(r, roleMap))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))
    );
  }

  Future<void> upsertTemplate(OpsTaskTemplateModel t) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('ops_task_templates').upsert({
      'id':                 t.id,
      'store_id':           storeId,
      'store_role_id':      t.storeRoleId,
      'title':              t.title,
      'description':        t.description,
      'target_time':        t.targetTime,
      'sort_order':         t.sortOrder,
      'is_active':          true,
      'shift_config_id':    t.shiftConfigId,
      'assigned_staff_ids': t.assignedStaffIds,
      'priority':           t.priority,
      'active_days':        t.activeDays,
      'requires_photo':     t.requiresPhoto,
    }, onConflict: 'id');
  }

  Future<void> deleteTemplate(String id) async {
    await _sb.from('ops_task_templates').update({'is_active': false}).eq('id', id);
  }

  Future<void> deleteAllTemplates() async {
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('ops_task_templates').update({'is_active': false}).eq('store_id', storeId);
  }

  // ── Daily Logs ─────────────────────────────────────────────────────────────

  /// Stream logs hôm nay của 1 nhân viên cụ thể
  Stream<List<OpsDailyLogModel>> watchMyLogsToday({
    required String staffId,
  }) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    final today = _todayStr();

    yield* _robustStream(
      'ops_daily_logs', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['staff_id'] == staffId && r['log_date'] == today)
          .map(OpsDailyLogModel.fromMap)
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt))
    );
  }

  /// Đảm bảo nhân viên có log cho mỗi template hôm nay (auto-create nếu chưa có)
  Future<void> ensureMyLogsToday({
    required String staffId,
    required String staffName,
    required List<OpsTaskTemplateModel> templates,
  }) async {
    final storeId = await _storeId();
    if (storeId == null || templates.isEmpty) return;
    final today = _todayStr();

    // Lấy log đã có hôm nay của nhân viên này
    final existing = await _sb
        .from('ops_daily_logs')
        .select('template_id')
        .eq('store_id', storeId)
        .eq('staff_id', staffId)
        .eq('log_date', today);
    final existingIds = existing.map((r) => r['template_id'] as String).toSet();

    // Tạo log cho template chưa có
    final missing = templates.where((t) => !existingIds.contains(t.id)).toList();
    if (missing.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final rows = missing.map((t) => {
      'id':          _uuid.v4(),
      'store_id':    storeId,
      'template_id': t.id,
      'log_date':    today,
      'staff_id':    staffId,
      'staff_name':  staffName,
      'status':      'pending',
      'created_at':  now,
    }).toList();

    await _sb.from('ops_daily_logs').upsert(rows, onConflict: 'template_id,log_date,staff_id', ignoreDuplicates: true);
  }

  /// Nhân viên tick hoàn thành
  Future<void> completeTask({required String logId, String? notes, String? proofPhotoUrl}) async {
    await _sb.from('ops_daily_logs').update({
      'status':           'completed',
      'completed_at':     DateTime.now().toUtc().toIso8601String(),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (proofPhotoUrl != null) 'proof_photo_url': proofPhotoUrl,
    }).eq('id', logId);
  }

  /// Upload ảnh bằng chứng lên Supabase Storage
  /// Upload ảnh bằng chứng:
  ///   Primary  → Google Drive (subfolder ops_proofs/yyyy-MM)
  ///   Fallback → Supabase Storage (ops_proofs/{store}/{YYYY-MM-DD}/)
  ///   Cleanup  → Supabase tự xóa sau 30 ngày, Drive lưu vĩnh viễn
  Future<String?> uploadProofPhoto({
    required String logId,
    required String storeId,
    required String filePath,   // đường dẫn lôcal từ XFile.path
    required String extension,
  }) async {
    final now = DateTime.now();
    final dateStr   = now.toIso8601String().substring(0, 10);        // 2026-05-17
    final monthStr  = now.toIso8601String().substring(0, 7);         // 2026-05
    final fileName  = 'ops_proof_${dateStr}_$logId.$extension';
    final subFolder = 'ops_proofs/$monthStr';                        // Drive subfolder

    // 1. Google Drive (primary) — same service account as chấm công
    try {
      final driveResult = await DriveService.uploadPhoto(
        storeId:   storeId,
        photoFile: File(filePath),
        fileName:  fileName,
        subFolder: subFolder,
      );
      if (driveResult != null) {
        return driveResult.viewLink;  // ✓ Drive thành công
      }
    } catch (_) {} // Drive chưa cấu hình → fallback

    // 2. Supabase Storage (fallback)
    try {
      final bytes = await File(filePath).readAsBytes();
      final path = 'ops_proofs/$storeId/$dateStr/$logId.$extension';
      await _sb.storage.from('ops-photos').uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'),
      );
      return _sb.storage.from('ops-photos').getPublicUrl(path);
    } catch (e) {
      return null;
    }
  }

  /// Xóa ảnh ops cũ hơn [retentionDays] ngày — gọi 1 lần/ngày khi manager mở app
  Future<void> cleanupOldProofPhotos({int retentionDays = 90}) async {
    try {
      final storeId = await _storeId();
      if (storeId == null) return;
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
      // Liệt kê tất cả sub-folder theo ngày trong store folder
      final folders = await _sb.storage.from('ops-photos')
          .list(path: 'ops_proofs/$storeId');
      for (final folder in folders) {
        // Folder name = YYYY-MM-DD
        final folderDate = DateTime.tryParse(folder.name);
        if (folderDate == null) continue;
        if (folderDate.isBefore(cutoff)) {
          // Xóa tất cả file trong folder cũ
          final files = await _sb.storage.from('ops-photos')
              .list(path: 'ops_proofs/$storeId/${folder.name}');
          if (files.isNotEmpty) {
            final paths = files.map((f) =>
                'ops_proofs/$storeId/${folder.name}/${f.name}').toList();
            await _sb.storage.from('ops-photos').remove(paths);
          }
        }
      }
    } catch (_) {} // silent — cleanup là best-effort
  }

  /// Manager đánh dấu missed (hết giờ)
  Future<void> markMissed(String logId) async {
    await _sb.from('ops_daily_logs').update({'status': 'missed'}).eq('id', logId);
  }

  // ── Shift Handover ─────────────────────────────────────────────────────

  /// Tạo bàn giao ca
  Future<void> createHandover(OpsShiftHandoverModel h) async {
    await _sb.from('ops_shift_handovers').insert({
      'id':              h.id,
      'store_id':        h.storeId,
      'from_shift_id':   h.fromShiftId,
      'handover_date':   h.handoverDate,
      'created_by':      h.createdBy,
      'created_by_name': h.createdByName,
      'issues':          h.issues,
      'notes':           h.notes,
      'pending_tasks':   h.pendingTasks,
    });
  }

  /// Lấy bàn giao ca mới nhất hôm nay
  Future<OpsShiftHandoverModel?> getLatestHandoverToday() async {
    final storeId = await _storeId();
    if (storeId == null) return null;
    final today = _todayStr();
    final rows = await _sb
        .from('ops_shift_handovers')
        .select()
        .eq('store_id', storeId)
        .eq('handover_date', today)
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return OpsShiftHandoverModel.fromMap(rows.first);
  }

  // ── Report ──────────────────────────────────────────────────────────────────

  /// Stream Realtime toàn bộ logs hôm nay — dùng cho Manager Dashboard
  Stream<List<OpsDailyLogModel>> watchTodayAllLogs() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    final today = _todayStr();
    yield* _robustStream(
      'ops_daily_logs', 'store_id', storeId,
      (rows) => rows
          .where((r) => r['log_date'] == today)
          .map(OpsDailyLogModel.fromMap)
          .toList()
    );
  }

  /// Báo cáo ngày — tổng hợp theo nhân viên + template
  Future<OpsReportData> getReport({String? dateStr}) async {
    final storeId = await _storeId();
    if (storeId == null) return OpsReportData.empty;
    final date = dateStr ?? _todayStr();

    final logs = await _sb
        .from('ops_daily_logs')
        .select()
        .eq('store_id', storeId)
        .eq('log_date', date);

    final templates = await _sb
        .from('ops_task_templates')
        .select('id, title, store_role_id')
        .eq('store_id', storeId)
        .eq('is_active', true);
    final templateMap = {for (final t in templates) t['id'] as String: t};

    final roles = await getStoreRoles();
    final roleMap = {for (final r in roles) r.id: r.name};

    return OpsReportData.fromLogs(logs.map(OpsDailyLogModel.fromMap).toList(), templateMap, roleMap);
  }

  // ── Seed KAY Standard ────────────────────────────────────────────────────

  /// Nạp "Bộ Tiêu Chuẩn KAY" vào store hiện tại
  Future<int> seedKayStandard() async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    // Map tên role → UUID
    final roles = await getStoreRoles();
    final roleByName = {for (final r in roles) r.name.toLowerCase(): r.id};

    String? roleId(String name) => roleByName[name.toLowerCase()];

    final now = DateTime.now().toUtc().toIso8601String();
    final seeds = _kKaySeeds.asMap().entries.map((e) => {
      'id':            _uuid.v4(),
      'store_id':      storeId,
      'store_role_id': roleId(e.value.$1),  // null nếu chưa có role này
      'title':         e.value.$2,
      'description':   e.value.$3,
      'target_time':   e.value.$4,
      'sort_order':    e.key,
      'is_active':     true,
      'created_at':    now,
    }).toList();

    await _sb.from('ops_task_templates').insert(seeds);
    return seeds.length;
  }

  /// Nạp chỉ các task thuộc [role] cụ thể
  Future<int> seedKayByRole(String role) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    final roles    = await getStoreRoles();
    final roleByName = {for (final r in roles) r.name.toLowerCase(): r.id};
    final now      = DateTime.now().toUtc().toIso8601String();

    final filtered = _kKaySeeds.where((s) => s.$1.toLowerCase() == role.toLowerCase()).toList();
    if (filtered.isEmpty) return 0;

    final seeds = filtered.asMap().entries.map((e) => {
      'id':            _uuid.v4(),
      'store_id':      storeId,
      'store_role_id': roleByName[e.value.$1.toLowerCase()],
      'title':         e.value.$2,
      'description':   e.value.$3,
      'target_time':   e.value.$4,
      'sort_order':    e.key,
      'is_active':     true,
      'created_at':    now,
    }).toList();

    await _sb.from('ops_task_templates').insert(seeds);
    return seeds.length;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SEED DATA — Bộ Tiêu Chuẩn (35 đầu việc)
// (tên role, tên công việc, mô tả, giờ mục tiêu)
// ─────────────────────────────────────────────────────────────────────────────
const _kKaySeeds = <(String, String, String, String?)>[

  // ── TẠP VỤ (8 việc) ──────────────────────────────────────────────────────
  ('Tạp vụ', 'Vệ sinh toilet + kiểm tra vật tư WC',
      'Xịt tẩy bồn cầu, lau lavabo, thay túi rác. Kiểm tra: giấy vệ sinh ≥ 2 cuộn/buồng, xà phòng rửa tay ≥ 1/3 bình, nước khử mùi còn đủ. Chụp ảnh kết quả gửi nhóm nếu quản lý yêu cầu.', '08:30'),
  ('Tạp vụ', 'Lau sàn toàn bộ quán trước giờ mở cửa',
      'Dùng cây lau 2 xô: xô nước tẩy → xô nước sạch. Lau theo thứ tự: khu bếp → quầy bar → khu khách. Kiểm tra sàn khô ráo, không đọng nước trơn trượt trước 09:00.', '08:45'),
  ('Tạp vụ', 'Lau kính cửa chính + mặt tiền quán',
      'Phun xịt kính chuyên dụng, lau bằng khăn microfiber. Kiểm tra không còn vết tay, vết nước. Lau biển hiệu, gương trang trí, cửa kính từ trong ra ngoài.', '09:00'),
  ('Tạp vụ', 'Kiểm tra + vệ sinh toilet lần 2 (giữa ca)',
      'Sau 11h-13h cao điểm: lau bồn cầu, lavabo, bổ sung giấy/xà phòng. Đặc biệt chú ý sàn nhà vệ sinh không ẩm, mùi hôi. Báo ngay nếu bồn cầu nghẹt hoặc vòi nước hỏng.', '13:00'),
  ('Tạp vụ', 'Lau bàn ghế + sàn khu khách sau cao điểm trưa',
      'Gom khăn giấy, tăm, rác vương vãi trên sàn. Lau khô bàn ghế, không để nước đọng. Xịt khử trùng mặt bàn sau khi khách rời. Thời gian hoàn thành: trong vòng 15 phút sau 13h.', '13:15'),
  ('Tạp vụ', 'Vệ sinh toilet lần 3 + kiểm tra cuối chiều',
      'Vệ sinh đầy đủ như lần 1. Đổ rác nếu túi đầy ≥ 2/3. Bổ sung vật tư cho ca tối. Đảm bảo không mùi hôi trước 18h khi lượng khách chiều bắt đầu đông.', '17:00'),
  ('Tạp vụ', 'Gom + đổ rác toàn quán',
      'Thu gom rác từ: tất cả thùng rác khu khách, bếp, bar, WC. Buộc chặt túi, thay túi rác mới. Đưa rác ra đúng điểm tập kết theo quy định địa phương. Không để rác qua đêm trong quán.', 'Cuối ca'),
  ('Tạp vụ', 'Tổng vệ sinh cuối ca + bàn giao ca',
      'Quét + lau ướt toàn bộ sàn. Lau bụi quầy thu ngân, kệ, cửa kính. Xếp ghế lên bàn (nếu quy định). Kiểm tra lần cuối toilet. Báo cáo trực tiếp hoặc nhắn tin cho quản lý ca tiếp theo nếu có hỏng hóc.', 'Cuối ca'),

  // ── THU NGÂN (6 việc) ────────────────────────────────────────────────────
  ('Thu ngân', 'Bật POS + kiểm tra thiết bị đầu ca',
      'Bật máy tính tiền, đợi khởi động hoàn toàn. Kiểm tra kết nối mạng (ping thử). In 1 phiếu test xem giấy rõ. Kiểm tra máy quét mã vạch, máy cà thẻ. Báo ngay kỹ thuật nếu lỗi - không tự xử lý.', '08:45'),
  ('Thu ngân', 'Kiểm đếm quỹ đầu ca + ký nhận',
      'Đếm từng mệnh giá tiền mặt. Ghi vào sổ quỹ: tổng số, từng loại mệnh giá. Ký tên + ghi giờ. Nếu chênh lệch so với ca trước > 20,000đ phải báo ngay quản lý trước khi nhận ca.', '09:00'),
  ('Thu ngân', 'Kiểm tra giấy in nhiệt + vật tư POS',
      'Mở máy in, kéo giấy ra kiểm tra còn đủ dùng ít nhất 4 tiếng. Dự trữ ≥ 2 cuộn giấy nhiệt trong ngăn kéo. Kiểm tra mực (nếu dùng máy in mực). Báo cáo kho nếu sắp hết.', '09:00'),
  ('Thu ngân', 'Đối chiếu tiền mặt giữa ca',
      'Đếm tiền thực tế trong ngăn kéo. So sánh với tổng doanh thu tiền mặt trên POS tính từ đầu ca. Ghi chú bất kỳ chênh lệch. Nếu thiếu > 50,000đ báo ngay quản lý, không chờ cuối ca.', '14:00'),
  ('Thu ngân', 'Chốt ca + lập phiếu bàn giao',
      'Đếm toàn bộ tiền mặt. In báo cáo ca từ POS. So sánh thực tế với hệ thống. Điền phiếu chốt ca: tổng doanh thu, tiền mặt, chuyển khoản, chênh lệch (nếu có), lý do. Ký tên, ghi giờ.', 'Cuối ca'),
  ('Thu ngân', 'Niêm phong tiền + gửi báo cáo quản lý',
      'Cho tiền vào phong bì/túi zip, dán nhãn ghi: ngày, ca, tên nhân viên, tổng số. Giao cho quản lý hoặc bỏ vào két an toàn theo quy trình. Chụp ảnh màn hình tổng kết POS gửi group chat.', 'Cuối ca'),

  // ── PHỤC VỤ (7 việc) ─────────────────────────────────────────────────────
  ('Phục vụ', 'Setup bàn ghế chuẩn trước giờ mở',
      'Sắp xếp bàn ghế đúng sơ đồ. Mỗi bàn cần đủ: menu sạch không rách, tăm trong hộp đậy nắp, khăn giấy đủ, lọ gia vị sạch (nếu có). Kiểm tra ghế không lung lay. Hoàn thành trước 09:00.', '08:45'),
  ('Phục vụ', 'Kiểm tra + lấy dụng cụ ăn uống sạch',
      'Lấy chén/ly/đũa/muỗng từ máy rửa bát. Kiểm tra từng cái: không vết dầu, không mùi, không chip vỡ. Xếp lên kệ đúng vị trí theo loại. Đủ lượng cho ít nhất 2 lần lật full bàn trong ca.', '09:00'),
  ('Phục vụ', 'Bật điều hòa + kiểm tra nhiệt độ phòng',
      'Bật điều hòa trước 30 phút giờ mở cửa. Cài 25°C hoặc theo quy định quán. Kiểm tra tất cả điều hòa hoạt động, không chảy nước, không mùi lạ. Báo kỹ thuật ngay nếu hỏng.', '08:30'),
  ('Phục vụ', 'Chuẩn bị nước đón khách',
      'Chuẩn bị đủ bình nước lọc/đá cho tất cả bàn. Kiểm tra ly nước sạch, không mùi. Khăn lạnh (nếu có): cuộn đều, đặt hộp sạch. Mỗi nhân viên phụ trách khu vực mình, không để khách ngồi quá 2 phút chưa có nước.', '09:00'),
  ('Phục vụ', 'Lau bàn + gom đồ dơ sau giờ cao điểm',
      'Sau sóng khách 11h-13h: ưu tiên dọn bàn trống trong vòng 3 phút. Lau mặt bàn bằng khăn ẩm sạch (khăn riêng mỗi bàn hoặc xịt khử trùng trước khi lau). Gom đồ dơ về quầy rửa ngay.', '13:15'),
  ('Phục vụ', 'Kiểm tra + báo cáo cơ sở vật chất',
      'Cuối mỗi ca đi kiểm tra toàn bộ khu phục vụ: ghi danh sách bàn ghế hỏng, đồ dùng thiếu/hư hỏng (ly vỡ, đũa thiếu, menu rách...). Báo cụ thể cho quản lý: số lượng, vị trí, tình trạng.', '17:00'),
  ('Phục vụ', 'Sắp xếp + vệ sinh khu phục vụ cuối ca',
      'Xịt khử khuẩn và lau toàn bộ mặt bàn. Sắp ghế ngay ngắn. Thu gom toàn bộ menu, khăn giấy thừa. Tắt điều hòa khu vực không dùng. Bàn giao tình trạng cho ca sau qua tin nhắn hoặc trực tiếp.', 'Cuối ca'),

  // ── BẾP (8 việc) ─────────────────────────────────────────────────────────
  ('Bếp', 'Kiểm tra nhiệt độ tủ lạnh + tủ đông',
      'Đọc nhiệt kế: tủ lạnh phải 0-4°C, tủ đông -18°C trở xuống. Ghi vào log kiểm tra nhiệt độ (bắt buộc). Nếu lệch > 2°C: kiểm tra cửa tủ đóng chưa, báo kỹ thuật ngay nếu máy nén có vấn đề. Không dùng thực phẩm trong tủ hỏng.', '08:30'),
  ('Bếp', 'Kiểm tra date + sơ chế nguyên liệu đầu ca',
      'Kiểm tra tất cả nguyên liệu trong tủ: loại bỏ hàng hết date hoặc có dấu hiệu hỏng (mùi lạ, nhớt, đổi màu). Sơ chế theo thực đơn ngày: rửa, thái, ướp đúng khối lượng cần. Ghi list nguyên liệu thiếu báo quản lý trước 09:30.', '09:00'),
  ('Bếp', 'Vệ sinh bàn bếp + kiểm tra dụng cụ',
      'Lau sạch toàn bộ bề mặt bàn bếp inox bằng khăn ẩm + dung dịch khử trùng thực phẩm. Kiểm tra dao: sắc, sạch, không gỉ, có đúng vị trí. Thớt: riêng thịt sống / rau củ / thực phẩm chín - không dùng lẫn.', '08:45'),
  ('Bếp', 'Kiểm tra gas + an toàn thiết bị bếp',
      'Mở van gas từng bếp, ngửi kiểm tra rò (mùi hắc). Test lửa: ngọn lửa xanh đều là bình thường, vàng đỏ báo kỹ thuật. Kiểm tra máy hút mùi hoạt động. Không bật thiết bị nếu nghi ngờ rò gas - mở cửa thông khí, báo ngay.', '09:00'),
  ('Bếp', 'Bổ sung nguyên liệu sắp hết trong ca',
      'Kiểm tra lượng tồn các nguyên liệu chính lúc 13h-14h. Ưu tiên bổ sung: protein (thịt/hải sản), rau củ tươi, gia vị thường dùng. Lấy từ kho theo phiếu xuất. Báo mua gấp nếu không đủ tồn cho ca tối.', '13:30'),
  ('Bếp', 'Chụp ảnh tủ lạnh + báo tồn kho cuối ngày',
      'Trước 17h30: chụp ảnh toàn bộ tủ lạnh/đông (mở cửa, chụp rõ từng ngăn). Ghi danh sách hàng cần đặt kèm số lượng cụ thể. Gửi vào nhóm quản lý kèm ảnh. Quản lý xác nhận đặt hàng trong ngày để có hàng sáng hôm sau.', '17:30'),
  ('Bếp', 'Bảo quản nguyên liệu thừa đúng quy trình',
      'Tất cả nguyên liệu chưa dùng hết: đậy kín bằng màng bọc thực phẩm hoặc hộp có nắp. Dán nhãn ghi: tên nguyên liệu, ngày chế biến, ngày hết hạn. Sắp xếp theo FIFO (cũ trước - mới sau). Không để thực phẩm chín gần thực phẩm sống.', 'Cuối ca'),
  ('Bếp', 'Vệ sinh bếp + đóng cửa an toàn',
      'Tắt tất cả bếp, lò. Khóa van gas chính (van tổng). Vệ sinh: bề mặt bếp, máy hút mùi (lau lưới lọc), bàn inox, sàn bếp. Đổ dầu ăn thừa đúng nơi quy định. Kiểm tra lần cuối: không còn đồ ăn để ngoài, van gas đóng, tắt đèn bếp.', 'Cuối ca'),

  // ── BẢO VỆ (6 việc) ──────────────────────────────────────────────────────
  ('Bảo vệ', 'Kiểm tra camera + hệ thống an ninh đầu ca',
      'Xem live camera tất cả góc; kiểm tra đèn báo hoạt động; báo ngay nếu camera mất tín hiệu', '09:00'),
  ('Bảo vệ', 'Mở cửa + kiểm tra biển bảng bên ngoài',
      'Mở cửa chính theo giờ; kiểm tra biển "Mở cửa/Đóng cửa"; dọn lối vào sạch sẽ', '09:00'),
  ('Bảo vệ', 'Kiểm tra khu vực đỗ xe + lối đi',
      'Đảm bảo khu đỗ xe ngăn nắp, không cản lối thoát hiểm; hướng dẫn khách nếu cần', '09:30'),
  ('Bảo vệ', 'Tuần tra định kỳ quán + khu vực ngoài',
      'Đi tuần toàn bộ quán, kiểm tra cửa hậu, toilet, khu bếp; ghi nhận bất thường', '15:00'),
  ('Bảo vệ', 'Kiểm tra PCCC + thiết bị an toàn',
      'Kiểm tra bình cứu hoả còn đủ áp; cầu dao điện hoạt động; đèn EXIT + lối thoát hiểm thông thoáng', 'Cuối ca'),
  ('Bảo vệ', 'Khóa cửa + kiểm tra toàn bộ quán cuối ca',
      'Đi kiểm tra tắt đèn, điều hòa; khóa cửa chính/phụ/hậu; báo cáo ca bằng tin nhắn cho quản lý', 'Cuối ca'),

  // ── BAR / PHA CHẾ (6 việc) ───────────────────────────────────────────────
  ('Bar / Pha chế', 'Vệ sinh máy pha cà phê + thiết bị đầu ca',
      'Tráng nước nóng group head, backflush; lau vòi hơi, khay chứa; kiểm tra áp suất máy', '09:00'),
  ('Bar / Pha chế', 'Kiểm tra nguyên liệu bar đầu ca',
      'Kiểm tra cà phê, sữa, syrup, đá, trà; ghi list thiếu; lấy bổ sung từ kho', '09:00'),
  ('Bar / Pha chế', 'Setup quầy bar + sắp xếp dụng cụ',
      'Sắp xếp ly/cốc theo kích cỡ; tamper, pitcher, khăn lau đúng vị trí; đủ dụng cụ cho ca', '09:30'),
  ('Bar / Pha chế', 'Kiểm tra tủ đá + nhiệt độ tủ lạnh bar',
      'Đảm bảo tủ đá đủ; nhiệt độ tủ lạnh bar 2-6°C; bổ sung sữa/nguyên liệu lạnh kịp thời', '13:00'),
  ('Bar / Pha chế', 'Ghi nhận & báo nguyên liệu sắp hết',
      'Kiểm tra mức tồn cà phê, sữa, syrup; báo quản lý hoặc đặt hàng trước khi hết ca', '17:00'),
  ('Bar / Pha chế', 'Vệ sinh toàn bộ quầy bar + thiết bị cuối ca',
      'Vệ sinh máy espresso, máy xay, steam wand; lau quầy inox; đổ bã cà phê; bọc thực phẩm', 'Cuối ca'),

  // ── QUẢN LÝ CA (5 việc) ──────────────────────────────────────────────────
  ('Quản lý ca', 'Kiểm tra nhân sự + phân công đầu ca',
      'Điểm danh nhân viên; phân công vị trí; nhắc nhở đồng phục, tác phong trước giờ mở cửa', '09:00'),
  ('Quản lý ca', 'Kiểm tra toàn bộ khu vực trước giờ mở cửa',
      'Đi kiểm tra bàn ghế, vệ sinh, âm thanh/ánh sáng; confirm ready với từng bộ phận', '09:00'),
  ('Quản lý ca', 'Theo dõi hiệu suất + xử lý sự cố trong ca',
      'Quan sát chất lượng phục vụ; giải quyết khiếu nại khách; nhắc nhở nhân viên kịp thời', '12:00'),
  ('Quản lý ca', 'Kiểm tra doanh thu giữa ca + điều phối nhân lực',
      'Xem báo cáo POS giữa ca; điều chỉnh nhân lực theo tình hình thực tế quán', '14:00'),
  ('Quản lý ca', 'Tổng kết ca + bàn giao cho ca sau',
      'Ghi nhật ký ca (sự cố, thiếu hàng, phản hồi khách); bàn giao tồn quỹ, công việc còn lại', 'Cuối ca'),

  // ── LỄ TÂN (4 việc) ──────────────────────────────────────────────────────
  ('Lễ tân', 'Chuẩn bị khu vực đón khách + sơ đồ bàn đầu ca',
      'Kiểm tra bàn reserved; in/cập nhật sơ đồ bàn; đặt biển "Đã đặt" đúng vị trí', '09:00'),
  ('Lễ tân', 'Xác nhận đặt bàn + gọi nhắc khách',
      'Gọi điện/nhắn tin xác nhận tất cả đặt bàn trong ngày; ghi chú yêu cầu đặc biệt', '10:00'),
  ('Lễ tân', 'Quản lý danh sách chờ + phân bàn giờ cao điểm',
      'Giữ danh sách chờ; dự đoán thời gian chờ; thông báo kịp thời cho khách; phân bàn đúng nhóm', '12:00'),
  ('Lễ tân', 'Tổng hợp lượt đặt bàn + gửi báo cáo cuối ca',
      'Ghi số lượt đặt, khách walk-in, khách no-show; gửi tổng hợp cho quản lý để chuẩn bị ca sau', 'Cuối ca'),

  // ── PHỤ BẾP (4 việc) ─────────────────────────────────────────────────────
  ('Phụ bếp', 'Sơ chế rau củ + thái thịt theo yêu cầu đầu ca',
      'Rửa sạch, cắt gọt rau củ; thái thịt đúng quy cách; phân loại + đặt vào hộp đúng vị trí bếp', '09:00'),
  ('Phụ bếp', 'Rửa + sắp xếp dụng cụ nhà bếp sau giờ cao điểm',
      'Rửa nồi/chảo/dao/thớt sau sóng khách 12h; sắp xếp đúng vị trí; kiểm tra đủ dụng cụ cho ca chiều', '13:30'),
  ('Phụ bếp', 'Bổ sung nguyên liệu sơ chế cho bếp chính',
      'Theo dõi tốc độ tiêu thụ; sơ chế bổ sung kịp thời không để bếp chính phải chờ', '15:00'),
  ('Phụ bếp', 'Dọn dẹp khu sơ chế + vệ sinh dao thớt cuối ca',
      'Vệ sinh bàn sơ chế, máy thái, thớt (ngâm nước nóng + muối); bọc nguyên liệu thừa vào tủ lạnh', 'Cuối ca'),

  // ── RỬA BÁT / STEWARD (3 việc) ───────────────────────────────────────────
  ('Rửa bát', 'Kiểm tra máy rửa bát + châm hóa chất đầu ca',
      'Kiểm tra máy rửa bát hoạt động; châm muối, nước xả bát; test chạy 1 mẻ trước giờ mở cửa', '09:00'),
  ('Rửa bát', 'Rửa + phân loại chén/ly/dụng cụ liên tục trong ca',
      'Ưu tiên chén/ly để phục vụ kịp; phân loại đúng loại; xếp lên máy/rửa tay đúng quy trình', null),
  ('Rửa bát', 'Sắp xếp chén/ly sạch lên kệ + báo thiếu dụng cụ',
      'Xếp đúng vị trí kệ để phục vụ lấy nhanh; báo quản lý ngay nếu thiếu ly/chén vỡ/mất', null),

  // ── SHIPPER / GIAO HÀNG (4 việc) ─────────────────────────────────────────
  ('Shipper', 'Kiểm tra xe + điện thoại giao hàng đầu ca',
      'Kiểm tra xe đủ xăng, đèn, phanh; điện thoại đủ pin, app đã online; túi giữ nhiệt sạch sẵn', '09:00'),
  ('Shipper', 'Đóng gói đơn + kiểm tra trước khi giao',
      'Đếm đủ món theo order; kiểm tra không rò/đổ; dán niêm phong; confirm địa chỉ với bếp', null),
  ('Shipper', 'Cập nhật trạng thái đơn trên app sau mỗi giao',
      'Bấm "Đã lấy hàng" / "Đã giao" đúng thời điểm; liên hệ khách ngay nếu không tìm được địa chỉ', null),
  ('Shipper', 'Báo cáo số đơn + nộp tiền COD cuối ca',
      'Đếm tổng đơn giao thành công/thất bại; nộp tiền mặt COD kèm phiếu giao cho thu ngân', 'Cuối ca'),

  // ── THỦ KHO (4 việc) ─────────────────────────────────────────────────────
  ('Thủ kho', 'Kiểm tra hàng nhập + đối chiếu hóa đơn',
      'Đếm số lượng hàng về; đối chiếu hóa đơn nhà cung cấp; báo ngay nếu thiếu/hỏng/sai hàng', '09:00'),
  ('Thủ kho', 'Sắp xếp hàng vào kho theo FIFO + dán nhãn date',
      'Hàng mới đặt sau hàng cũ; dán nhãn ngày nhập; phân loại đúng khu (khô/lạnh/đông)', '10:00'),
  ('Thủ kho', 'Kiểm tra hạn sử dụng hàng tồn định kỳ',
      'Kiểm tra toàn bộ kho; loại bỏ hàng hết date; báo quản lý hàng gần hết để ưu tiên dùng', '14:00'),
  ('Thủ kho', 'Cập nhật số liệu tồn kho + gửi báo cáo cuối ca',
      'Cập nhật xuất/nhập kho trong ngày vào hệ thống hoặc sổ sách; gửi báo cáo tồn cuối ngày', 'Cuối ca'),

  // ── NHÂN VIÊN TAKEAWAY (4 việc) ───────────────────────────────────────────
  ('Takeaway', 'Setup quầy takeaway + chuẩn bị bao bì đầu ca',
      'Sắp xếp túi giấy, hộp, muỗng/đũa dùng 1 lần; kiểm tra máy in bill; bật app nhận đơn online', '09:00'),
  ('Takeaway', 'Đóng gói đơn take-away đúng quy trình',
      'Đóng gói theo checklist; kiểm tra đủ món, topping, nước chấm; dán nhãn tên/SĐT khách', null),
  ('Takeaway', 'Xử lý đơn GrabFood/ShopeeFood + in ticket kịp thời',
      'Accept đơn trong 30 giây; in ticket truyền bếp ngay; theo dõi thời gian chuẩn bị để không trễ', null),
  ('Takeaway', 'Vệ sinh quầy takeaway + kiểm kê bao bì cuối ca',
      'Lau sạch quầy; đếm tồn túi/hộp/dụng cụ; báo đặt thêm nếu sắp hết; tắt app online đúng giờ', 'Cuối ca'),

  // ── CHẠY BÀN / FOOD RUNNER (3 việc) ──────────────────────────────────────
  ('Chạy bàn', 'Lấy món từ bếp + xác nhận đúng bàn trước khi mang',
      'Đọc kỹ ticket; confirm tên món với bếp; kiểm tra trình bày đẹp, đủ; mang ra đúng bàn, báo tên món', null),
  ('Chạy bàn', 'Thu dọn đĩa/cốc sau khi khách dùng xong',
      'Quan sát bàn; hỏi khách dùng xong chưa trước khi dọn; thu gọn nhẹ nhàng không gây ồn', null),
  ('Chạy bàn', 'Bổ sung nước/đá/khăn giấy + hỗ trợ phục vụ',
      'Chủ động châm nước khi khách vơi; bổ sung khăn giấy; hỗ trợ phục vụ khi cao điểm', null),

  // ── DỌN BÀN / BUSBOY (3 việc) ────────────────────────────────────────────
  ('Dọn bàn', 'Thu dọn bàn nhanh sau khi khách rời + reset bàn',
      'Thu đồ bẩn ngay sau khách rời; lau bàn bằng khăn sạch; sắp ghế/dụng cụ đúng chuẩn trong 3 phút', null),
  ('Dọn bàn', 'Phân loại rác thực phẩm + vận chuyển đồ bẩn về bếp',
      'Đổ thức ăn thừa vào thùng rác thực phẩm; xếp chén/ly vào khay gọn; vận chuyển về khu rửa bát', null),
  ('Dọn bàn', 'Kiểm tra & bổ sung dụng cụ bàn sau mỗi ca cao điểm',
      'Sau 13h và 20h kiểm tra toàn bộ bàn: đủ tăm, giấy, lọ gia vị; thay khăn giấy cạn', null),

  // ── TRƯỞNG NHÓM PHỤC VỤ (4 việc) ────────────────────────────────────────
  ('Trưởng nhóm', 'Họp briefing nhóm phục vụ + phân công khu vực',
      'Thông báo menu đặc biệt, sự kiện ngày; phân khu vực bàn cho từng nhân viên rõ ràng', '09:00'),
  ('Trưởng nhóm', 'Kiểm tra tác phong + đồng phục nhân viên đầu ca',
      'Kiểm tra đồng phục sạch, đúng quy định; nhắc nhở cách chào hỏi, giao tiếp với khách', '09:00'),
  ('Trưởng nhóm', 'Hỗ trợ bàn VIP + giải quyết phàn nàn của khách',
      'Đứng ở vị trí quan sát; tiếp nhận khiếu nại; xử lý tại chỗ trong thẩm quyền; báo cáo sự cố lên', '12:00'),
  ('Trưởng nhóm', 'Đánh giá hiệu suất phục vụ + ghi nhận xuất sắc/nhắc nhở',
      'Ghi nhận nhân viên phục vụ tốt trong ca; nhắc nhở kịp thời không đúng; báo cáo tóm tắt cho quản lý', 'Cuối ca'),

  // ── NHÂN VIÊN ĐẶT BÀN / TỔNG ĐÀI (3 việc) ───────────────────────────────
  ('Đặt bàn', 'Nhận + xác nhận đặt bàn qua điện thoại/app/Zalo',
      'Ghi đủ thông tin: tên, SĐT, giờ, số người, yêu cầu đặc biệt; đọc lại để khách xác nhận', null),
  ('Đặt bàn', 'Nhắc lịch đặt bàn cho khách trước 1-2 tiếng',
      'Gọi điện hoặc nhắn Zalo nhắc khách; xác nhận lại có đến không; điều chỉnh bàn nếu cần', null),
  ('Đặt bàn', 'Cập nhật sơ đồ bàn + thông báo bộ phận liên quan',
      'Cập nhật trạng thái bàn reserved/confirmed/cancelled; thông báo lễ tân và bếp các đặt bàn đặc biệt', null),

  // ── NHÂN VIÊN CONTENT / TRUYỀN THÔNG (3 việc) ────────────────────────────
  ('Content', 'Chụp ảnh/quay video món + không gian quán',
      'Chụp 3-5 ảnh đẹp hoặc 1 video reel mỗi ngày; chỉnh sáng/màu cơ bản; đặt tên file có ngày', '10:00'),
  ('Content', 'Đăng story + post theo lịch nội dung hàng ngày',
      'Lên story Instagram/Facebook đúng khung giờ vàng (11h-12h, 17h-19h); viết caption kèm hashtag', '11:00'),
  ('Content', 'Reply comment/inbox + báo cáo tương tác cuối ngày',
      'Trả lời tất cả comment/tin nhắn trong 2 tiếng; screenshot báo cáo reach, like, inbox gửi quản lý', 'Cuối ca'),

  // ── KỸ THUẬT / BẢO TRÌ (3 việc) ─────────────────────────────────────────
  ('Kỹ thuật', 'Kiểm tra thiết bị điện lạnh + báo sự cố đầu ca',
      'Kiểm tra máy lạnh, tủ mát, máy nước nóng, hệ thống chiếu sáng; ghi log; báo ngay nếu hỏng', '09:00'),
  ('Kỹ thuật', 'Bảo dưỡng định kỳ theo lịch (máy lọc nước, máy lạnh...)',
      'Thực hiện bảo dưỡng theo lịch tháng/quý; thay filter lọc nước; vệ sinh dàn lạnh; ghi sổ bảo trì', null),
  ('Kỹ thuật', 'Ghi log thiết bị hỏng + phối hợp sửa chữa',
      'Ghi chính xác hiện tượng hỏng, thời gian phát hiện; liên hệ thợ sửa; theo dõi tiến độ; báo cáo hoàn thành', null),
];

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class OpsRoleModel {
  final String id;
  final String name;
  final String? color;
  final String? icon;

  const OpsRoleModel({required this.id, required this.name, this.color, this.icon});

  factory OpsRoleModel.fromMap(Map<String, dynamic> m) => OpsRoleModel(
    id:    m['id'] as String,
    name:  m['name'] as String,
    color: m['color'] as String?,
    icon:  m['icon'] as String?,
  );
}

class OpsTaskTemplateModel {
  final String id;
  final String storeId;
  final String? storeRoleId;
  final String? roleName;           // joined từ store_roles
  final String title;
  final String? description;
  final String? targetTime;
  final int sortOrder;
  final bool isActive;
  final String? shiftConfigId;      // gắn ca làm việc (null = tất cả ca)
  final List<String> assignedStaffIds; // assign cá nhân ([] = theo role)
  final String priority;              // critical | high | normal | low
  final List<int>? activeDays;        // [1-7]=T2-CN, null = mọi ngày
  final bool requiresPhoto;           // bằng chứng ảnh bắt buộc

  const OpsTaskTemplateModel({
    required this.id,
    required this.storeId,
    this.storeRoleId,
    this.roleName,
    required this.title,
    this.description,
    this.targetTime,
    this.sortOrder = 0,
    this.isActive = true,
    this.shiftConfigId,
    this.assignedStaffIds = const [],
    this.priority = 'normal',
    this.activeDays,
    this.requiresPhoto = false,
  });

  factory OpsTaskTemplateModel.fromMap(
    Map<String, dynamic> m,
    Map<String, OpsRoleModel> roleMap,
  ) {
    final roleId = m['store_role_id'] as String?;
    // Parse assigned_staff_ids từ JSONB (có thể là List hoặc null)
    List<String> staffIds = [];
    try {
      final raw = m['assigned_staff_ids'];
      if (raw is List) staffIds = raw.cast<String>();
    } catch (_) {}
    return OpsTaskTemplateModel(
      id:               m['id'] as String,
      storeId:          m['store_id'] as String,
      storeRoleId:      roleId,
      roleName:         roleId != null ? roleMap[roleId]?.name : null,
      title:            m['title'] as String,
      description:      m['description'] as String?,
      targetTime:       m['target_time'] as String?,
      sortOrder:        (m['sort_order'] as num?)?.toInt() ?? 0,
      isActive:         m['is_active'] as bool? ?? true,
      shiftConfigId:    m['shift_config_id'] as String?,
      assignedStaffIds: staffIds,
      priority:         m['priority'] as String? ?? 'normal',
      activeDays:       (m['active_days'] as List?)?.cast<int>(),
      requiresPhoto:    m['requires_photo'] as bool? ?? false,
    );
  }

  OpsTaskTemplateModel copyWith({
    String? id, String? storeRoleId, String? roleName,
    String? title, String? description, String? targetTime,
    int? sortOrder, String? shiftConfigId, List<String>? assignedStaffIds,
    String? priority, List<int>? activeDays, bool? requiresPhoto,
  }) {
    return OpsTaskTemplateModel(
      id:               id ?? this.id,
      storeId:          storeId,
      storeRoleId:      storeRoleId ?? this.storeRoleId,
      roleName:         roleName ?? this.roleName,
      title:            title ?? this.title,
      description:      description ?? this.description,
      targetTime:       targetTime ?? this.targetTime,
      sortOrder:        sortOrder ?? this.sortOrder,
      isActive:         isActive,
      shiftConfigId:    shiftConfigId ?? this.shiftConfigId,
      assignedStaffIds: assignedStaffIds ?? this.assignedStaffIds,
      priority:         priority ?? this.priority,
      activeDays:       activeDays ?? this.activeDays,
      requiresPhoto:    requiresPhoto ?? this.requiresPhoto,
    );
  }
}

class OpsDailyLogModel {
  final String id;
  final String storeId;
  final String templateId;
  final String logDate;
  final String? staffId;
  final String? staffName;
  final String status;        // pending | completed | missed
  final String? completedAt;
  final String? notes;
  final String? proofPhotoUrl;  // URL ảnh bằng chứng
  final String createdAt;

  const OpsDailyLogModel({
    required this.id,
    required this.storeId,
    required this.templateId,
    required this.logDate,
    this.staffId,
    this.staffName,
    required this.status,
    this.completedAt,
    this.notes,
    this.proofPhotoUrl,
    required this.createdAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isMissed    => status == 'missed';
  bool get isPending   => status == 'pending';

  factory OpsDailyLogModel.fromMap(Map<String, dynamic> m) => OpsDailyLogModel(
    id:            m['id'] as String,
    storeId:       m['store_id'] as String,
    templateId:    m['template_id'] as String,
    logDate:       m['log_date'] as String? ?? '',
    staffId:       m['staff_id'] as String?,
    staffName:     m['staff_name'] as String?,
    status:        m['status'] as String? ?? 'pending',
    completedAt:   m['completed_at'] as String?,
    notes:         m['notes'] as String?,
    proofPhotoUrl: m['proof_photo_url'] as String?,
    createdAt:     m['created_at'] as String? ?? '',
  );
}

// ───────────────────────────────────────────────────────────────────────────────
// SHIFT HANDOVER MODEL
// ───────────────────────────────────────────────────────────────────────────────

class OpsShiftHandoverModel {
  final String id;
  final String storeId;
  final String? fromShiftId;
  final String? toShiftId;
  final String handoverDate;
  final String createdBy;
  final String createdByName;
  final String? issues;
  final String? notes;
  final List<String> pendingTasks;
  final String createdAt;

  const OpsShiftHandoverModel({
    required this.id,
    required this.storeId,
    this.fromShiftId,
    this.toShiftId,
    required this.handoverDate,
    required this.createdBy,
    required this.createdByName,
    this.issues,
    this.notes,
    this.pendingTasks = const [],
    required this.createdAt,
  });

  factory OpsShiftHandoverModel.fromMap(Map<String, dynamic> m) => OpsShiftHandoverModel(
    id:            m['id'] as String,
    storeId:       m['store_id'] as String,
    fromShiftId:   m['from_shift_id'] as String?,
    toShiftId:     m['to_shift_id'] as String?,
    handoverDate:  m['handover_date'] as String? ?? '',
    createdBy:     m['created_by'] as String,
    createdByName: m['created_by_name'] as String? ?? '',
    issues:        m['issues'] as String?,
    notes:         m['notes'] as String?,
    pendingTasks:  (m['pending_tasks'] as List?)?.cast<String>() ?? [],
    createdAt:     m['created_at'] as String? ?? '',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REPORT DATA
// ─────────────────────────────────────────────────────────────────────────────

class OpsReportData {
  final int total;
  final int completed;
  final int missed;
  final int pending;
  final List<OpsStaffReport> byStaff;
  final List<OpsRoleReport> byRole;

  const OpsReportData({
    required this.total,
    required this.completed,
    required this.missed,
    required this.pending,
    required this.byStaff,
    required this.byRole,
  });

  double get completionPct => total == 0 ? 0 : completed / total;

  static const empty = OpsReportData(
    total: 0, completed: 0, missed: 0, pending: 0, byStaff: [], byRole: [],
  );

  factory OpsReportData.fromLogs(
    List<OpsDailyLogModel> logs,
    Map<String, dynamic> templateMap,
    Map<String, String> roleMap,
  ) {
    if (logs.isEmpty) return empty;

    // Group by staff
    final staffMap = <String, OpsStaffReport>{};
    // Group by role
    final roleReports = <String, OpsRoleReport>{};

    for (final log in logs) {
      // Staff grouping
      final staffKey = log.staffId ?? 'unknown';
      staffMap.putIfAbsent(staffKey, () => OpsStaffReport(
        staffId: log.staffId,
        staffName: log.staffName ?? 'Không rõ',
        logs: [],
      )).logs.add(log);

      // Role grouping
      final template = templateMap[log.templateId];
      final roleId = template?['store_role_id'] as String?;
      final roleName = roleId != null ? (roleMap[roleId] ?? 'Khác') : 'Tất cả';
      roleReports.putIfAbsent(roleName, () => OpsRoleReport(
        roleName: roleName,
        logs: [],
      )).logs.add(log);
    }

    return OpsReportData(
      total:     logs.length,
      completed: logs.where((l) => l.isCompleted).length,
      missed:    logs.where((l) => l.isMissed).length,
      pending:   logs.where((l) => l.isPending).length,
      byStaff:   staffMap.values.toList()..sort((a,b) => b.completionPct.compareTo(a.completionPct)),
      byRole:    roleReports.values.toList()..sort((a,b) => a.roleName.compareTo(b.roleName)),
    );
  }
}

class OpsStaffReport {
  final String? staffId;
  final String staffName;
  final List<OpsDailyLogModel> logs;

  OpsStaffReport({required this.staffId, required this.staffName, required this.logs});

  int get total     => logs.length;
  int get completed => logs.where((l) => l.isCompleted).length;
  int get missed    => logs.where((l) => l.isMissed).length;
  int get pending   => logs.where((l) => l.isPending).length;
  double get completionPct => total == 0 ? 0 : completed / total;
}

class OpsRoleReport {
  final String roleName;
  final List<OpsDailyLogModel> logs;

  OpsRoleReport({required this.roleName, required this.logs});

  int get total     => logs.length;
  int get completed => logs.where((l) => l.isCompleted).length;
  int get missed    => logs.where((l) => l.isMissed).length;
  double get completionPct => total == 0 ? 0 : completed / total;
}
