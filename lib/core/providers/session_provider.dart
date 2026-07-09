// lib/core/providers/session_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Session Provider — Quản lý trạng thái đăng nhập toàn app
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_auth_service.dart';
import '../utils/app_logger.dart';

// ── Session state ─────────────────────────────────────────────────────────────
class _SessionNotifier extends Notifier<SessionData?> {
  @override
  SessionData? build() => null;

  void setSession(SessionData? session) {
    state = session;
    AppLogger.updateSession(
      storeId: session?.storeId,
      staffName: session?.displayName,
    );
    try {
      final client = Supabase.instance.client;
      if (session != null && session.storeId != null) {
        client.rest.headers['x-store-id'] = session.storeId!;
      } else {
        client.rest.headers.remove('x-store-id');
      }
    } catch (_) {}
  }

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
    AppLogger.updateSession(
      storeId: membership.storeId,
      staffName: state?.displayName,
    );
    try {
      Supabase.instance.client.rest.headers['x-store-id'] = membership.storeId;
    } catch (_) {}
  }

  void clear() {
    state = null;
    AppLogger.updateSession(storeId: null, staffName: null);
    try {
      Supabase.instance.client.rest.headers.remove('x-store-id');
    } catch (_) {}
  }
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
