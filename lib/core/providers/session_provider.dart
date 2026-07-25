import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_auth_service.dart';
import '../utils/app_logger.dart';

import '../services/staff_sync_service.dart';
import 'permission_provider.dart';

// ── Session state ─────────────────────────────────────────────────────────────
class _SessionNotifier extends Notifier<SessionData?> {
  StaffSyncService? _syncService;

  @override
  SessionData? build() => null;

  void _setupSyncService(SessionData? session) {
    _syncService?.stop();
    _syncService = null;

    if (session != null && !session.isOwner && session.storeId != null && session.storeId!.isNotEmpty) {
      _syncService = StaffSyncService(
        storeId: session.storeId!,
        currentUserId: session.userId,
        currentRole: session.role,
        onRoleChanged: (newRole) {
          if (state != null && state!.userId == session.userId) {
            final updatedMembership = StoreMembership(
              storeId:   state!.storeId ?? '',
              storeName: state!.storeName ?? '',
              storeCode: state!.storeCode ?? '',
              role:      newRole,
              isOwner:   false,
            );
            updateStore(updatedMembership);
            ref.invalidate(userActionPermsProvider);
          }
        },
        onPermsChanged: () {
          ref.invalidate(userActionPermsProvider);
        },
        onRemoved: () {
          clear();
        },
      );
      _syncService?.start();
    }
  }

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

    _setupSyncService(session);
  }

  void updateStore(StoreMembership membership) async {
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

    // Save to SharedPreferences so that repositories get the updated store ID
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_store_id', membership.storeId);
      await prefs.setString('auth_store_code', membership.storeCode);
      await prefs.setString('auth_store_name', membership.storeName);
      await prefs.setString('auth_role', membership.role);
    } catch (e) {
      print('Error saving store info to SharedPreferences: $e');
    }

    AppLogger.updateSession(
      storeId: membership.storeId,
      staffName: state?.displayName,
    );
    try {
      Supabase.instance.client.rest.headers['x-store-id'] = membership.storeId;
    } catch (_) {}

    _setupSyncService(state);
  }

  void clear() {
    _syncService?.stop();
    _syncService = null;
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
