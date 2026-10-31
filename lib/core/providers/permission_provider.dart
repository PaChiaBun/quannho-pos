// lib/core/providers/permission_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Action-Level Permission Provider
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/staff_service.dart';
import 'session_provider.dart';

// ── Provider: tập hợp actions mà user hiện tại được phép làm ─────────────────
final userActionPermsProvider = FutureProvider<Set<String>>((ref) async {
  final session = ref.watch(sessionProvider);

  if (session == null) {
    return <String>{};
  }

  // Owner luôn có toàn quyền — không cần query
  if (session.isOwner) {
    return Set<String>.from(kAllActions);
  }

  final storeId = session.storeId;
  final userId = session.userId;

  if (storeId == null || storeId.isEmpty || userId.isEmpty) {
    return <String>{};
  }

  final perms = await StaffService.getEffectiveActionPermissions(
    storeId: storeId,
    userId: userId,
    isOwner: session.isOwner,
  );
  return Set<String>.from(perms);
});

// ── Helper: dùng trong ConsumerWidget để check nhanh ─────────────────────────
extension PermissionRef on WidgetRef {
  /// Trả về true nếu user hiện tại có quyền thực hiện [action].
  bool canDo(String action) {
    final async = watch(userActionPermsProvider);
    return async.when(
      data: (perms) => perms.contains(action),
      loading: () => false, // fail-closed
      error: (err, stack) => false, // fail-closed
    );
  }

  /// Trả về true nếu không có quyền (hoặc đang loading/lỗi -> fail-closed chặn).
  bool isBlocked(String action) {
    final async = watch(userActionPermsProvider);
    return async.maybeWhen(
      data: (perms) => !perms.contains(action),
      loading: () => true, // fail-closed
      error: (err, stack) => true, // fail-closed
      orElse: () => true, // fail-closed
    );
  }
}
