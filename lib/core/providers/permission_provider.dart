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

  // Owner luôn có toàn quyền — không cần query
  if (session == null || session.isOwner) {
    return Set<String>.from(kAllActions);
  }

  final storeId = session.storeId;
  final role    = session.role;

  if (storeId == null || storeId.isEmpty || role.isEmpty) {
    return <String>{};
  }

  return StaffService.getActionPermissions(storeId, role);
});

// ── Helper: dùng trong ConsumerWidget để check nhanh ─────────────────────────
extension PermissionRef on WidgetRef {
  /// Trả về true nếu user hiện tại có quyền thực hiện [action].
  /// Fallback về true (permissive) khi chưa load xong — tránh block UI.
  bool canDo(String action) {
    final async = watch(userActionPermsProvider);
    return async.when(
      data:    (perms) => perms.contains(action),
      loading: ()      => true,  // optimistic — tránh flash UI
      error:   (_, __) => true,  // fallback permissive khi lỗi
    );
  }

  /// Trả về true nếu đã load xong VÀ không có quyền.
  bool isBlocked(String action) {
    final async = watch(userActionPermsProvider);
    return async.maybeWhen(
      data: (perms) => !perms.contains(action),
      orElse: () => false,
    );
  }
}
