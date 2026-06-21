// lib/core/providers/session_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Session Provider — Quản lý trạng thái đăng nhập toàn app
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/user_auth_service.dart';

// ── Session state ─────────────────────────────────────────────────────────────
class _SessionNotifier extends Notifier<SessionData?> {
  @override
  SessionData? build() => null;

  void setSession(SessionData? session) => state = session;

  void updateStore(StoreMembership membership) {
    if (state == null) return;
    state = SessionData(
      userId:      state!.userId,
      phone:       state!.phone,
      displayName: state!.displayName,
      storeId:     membership.storeId,
      storeName:   membership.storeName,
      storeCode:   membership.storeCode,
      role:        membership.role,
      isOwner:     membership.isOwner,
    );
  }

  void clear() => state = null;
}

final sessionProvider =
    NotifierProvider<_SessionNotifier, SessionData?>(_SessionNotifier.new);

// ── Convenience selectors ─────────────────────────────────────────────────────

/// Role của user hiện tại (dùng để filter tab)
final currentRoleProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider)?.role;
});

/// Có đăng nhập chưa?
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider) != null;
});

/// Có quán chưa?
final hasStoreProvider = Provider<bool>((ref) {
  return ref.watch(sessionProvider)?.hasStore ?? false;
});
