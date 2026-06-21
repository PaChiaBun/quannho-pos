import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/ops_repository.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/staff_service.dart' show ShiftConfig, ShiftConfigService;

// ─────────────────────────────────────────────────────────────────────────────
// OPS PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

final opsRepositoryProvider = Provider<OpsRepository>((ref) => OpsRepository());

/// Stream tất cả templates (manager view)
final opsTemplatesProvider = StreamProvider.autoDispose<List<OpsTaskTemplateModel>>((ref) {
  return ref.watch(opsRepositoryProvider).watchTemplates();
});

/// Danh sách ca làm việc của quán
final opsShiftConfigsProvider = FutureProvider.autoDispose<List<ShiftConfig>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session?.storeId == null) return [];
  return ShiftConfigService.getShifts(session!.storeId!);
});

/// Templates dành cho nhân viên hiện tại — lọc theo role + ca + assign cá nhân
final opsMyTemplatesProvider = StreamProvider.autoDispose<List<OpsTaskTemplateModel>>((ref) async* {
  final repo    = ref.watch(opsRepositoryProvider);
  final session = ref.watch(sessionProvider);
  if (session == null) { yield []; return; }

  // 1. Tìm store_role_id theo tên role (case-insensitive)
  final roles  = await repo.getStoreRoles();
  final myRole = roles.where((r) =>
    r.name.trim().toLowerCase() == session.role.trim().toLowerCase()
  ).firstOrNull;

  // 2. Load shift configs để detect ca hiện tại
  final shifts = await ShiftConfigService.getShifts(session.storeId ?? '');
  final now    = DateTime.now();
  final currentShiftId = _detectCurrentShift(shifts, now);

  // 3. Stream templates, filter client-side
  yield* repo.watchTemplates().map((templates) => templates.where((t) {
    // Ưu tiên 1: assign cá nhân → luôn hiện
    if (t.assignedStaffIds.contains(session.userId)) return true;

    // Ưu tiên 2: match role
    final matchRole = t.storeRoleId == null ||
        (myRole != null && t.storeRoleId == myRole.id);
    if (!matchRole) return false;

    // Ưu tiên 3: check ca — nếu task có gắn ca thì chỉ hiện khi đúng ca
    if (t.shiftConfigId != null) {
      if (t.shiftConfigId != currentShiftId) return false;
    }

    // Ưu tiên 4: check ngày trong tuần
    if (t.activeDays != null && t.activeDays!.isNotEmpty) {
      final todayWeekday = now.weekday; // 1=T2 ... 7=CN
      if (!t.activeDays!.contains(todayWeekday)) return false;
    }

    return true;
  }).toList());
});

/// Detect ca làm việc hiện tại
String? _detectCurrentShift(List<ShiftConfig> shifts, DateTime now) {
  for (final s in shifts) {
    if (s.isCurrentShift(now)) return s.id;
  }
  return null;
}

/// Stream log hôm nay của nhân viên đang đăng nhập
final opsMyLogsProvider = StreamProvider.autoDispose<List<OpsDailyLogModel>>((ref) {
  final repo    = ref.watch(opsRepositoryProvider);
  final session = ref.watch(sessionProvider);
  if (session == null) return const Stream.empty();

  return repo.watchMyLogsToday(staffId: session.userId);
});

/// Store roles (cho dropdown chọn role khi tạo template)
final opsStoreRolesProvider = FutureProvider.autoDispose<List<OpsRoleModel>>((ref) {
  return ref.watch(opsRepositoryProvider).getStoreRoles();
});

/// Báo cáo ngày (manager)
final opsReportProvider = FutureProvider.autoDispose.family<OpsReportData, String?>((ref, dateStr) {
  return ref.watch(opsRepositoryProvider).getReport(dateStr: dateStr);
});

/// Stream Realtime toàn bộ logs hôm nay — dùng cho Manager Dashboard
final opsLiveTodayLogsProvider = StreamProvider.autoDispose<List<OpsDailyLogModel>>((ref) {
  return ref.watch(opsRepositoryProvider).watchTodayAllLogs();
});
