import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/user_auth_service.dart';
import '../utils/app_logger.dart';

import '../services/staff_sync_service.dart';
import 'permission_provider.dart';
import '../../modules/bill_printer/providers/printer_settings_provider.dart';

bool shouldRouteToStorePickerOnSessionChange(
  SessionData? previous,
  SessionData? next,
) => previous?.storeId != null && next != null && next.storeId == null;

// ── Session state ─────────────────────────────────────────────────────────────
class _SessionNotifier extends Notifier<SessionData?> {
  StaffSyncService? _syncService;

  @override
  SessionData? build() => null;

  void _setupSyncService(SessionData? session) {
    _syncService?.stop();
    _syncService = null;

    if (session != null &&
        !session.isOwner &&
        session.storeId != null &&
        session.storeId!.isNotEmpty) {
      _syncService = StaffSyncService(
        storeId: session.storeId!,
        currentUserId: session.userId,
        currentRole: session.role,
        onRoleChanged: (newRole) {
          if (state != null && state!.userId == session.userId) {
            final updatedMembership = StoreMembership(
              storeId: state!.storeId ?? '',
              storeName: state!.storeName ?? '',
              storeCode: state!.storeCode ?? '',
              role: newRole,
              isOwner: false,
            );
            updateStore(updatedMembership);
            ref.invalidate(userActionPermsProvider);
          }
        },
        onPermsChanged: () {
          ref.invalidate(userActionPermsProvider);
        },
        onRemoved: () {
          if (state?.storeId != null) {
            unawaited(_handleRemoved());
          }
        },
      );
      _syncService?.start();
    }
  }

  Future<void> _handleRemoved() async {
    if (state?.storeId == null) return;
    AppLogger.info('auth', 'Realtime trigger: thu hoi store context.');
    await clearStoreContext();
  }

  void setSession(SessionData? session) {
    state = session;
    AppLogger.updateSession(
      storeId: session?.storeId,
      staffName: session?.displayName,
    );
    try {
      final client = Supabase.instance.client;
      if (session != null) {
        client.rest.headers['x-user-id'] = session.userId;
      } else {
        client.rest.headers.remove('x-user-id');
      }
      if (session != null && session.storeId != null) {
        client.rest.headers['x-store-id'] = session.storeId!;
      } else {
        client.rest.headers.remove('x-store-id');
      }
    } catch (_) {}

    _setupSyncService(session);
    if (session != null &&
        session.storeId != null &&
        session.storeId!.isNotEmpty) {
      try {
        ref.read(printerSettingsProvider);
      } catch (_) {}
    }
  }

  void updateStore(StoreMembership membership) async {
    if (state == null) return;
    state = SessionData(
      userId: state!.userId,
      phone: state!.phone,
      displayName: state!.displayName,
      storeId: membership.storeId,
      storeName: membership.storeName,
      storeCode: membership.storeCode,
      role: membership.role,
      isOwner: membership.isOwner,
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
      if (state != null) {
        Supabase.instance.client.rest.headers['x-user-id'] = state!.userId;
      }
    } catch (_) {}

    _setupSyncService(state);
  }

  Future<void> clearStoreContext() async {
    _syncService?.stop();
    _syncService = null;

    final storeIdBeforeClear = state?.storeId ?? '';

    // Release active print-server ownership before auth prefs are cleared.
    try {
      final notifier = ref.read(printerSettingsProvider.notifier);
      await notifier.prepareForStoreLogout(storeIdBeforeClear);
    } catch (_) {}

    // Persistent clear in SharedPreferences
    await UserAuthService.clearStoreContext();

    if (state != null) {
      state = SessionData(
        userId: state!.userId,
        phone: state!.phone,
        displayName: state!.displayName,
        storeId: null,
        storeName: null,
        storeCode: null,
        role: '',
        isOwner: false,
      );
    } else {
      state = null;
    }

    AppLogger.updateSession(storeId: null, staffName: state?.displayName);
    try {
      Supabase.instance.client.rest.headers.remove('x-store-id');
    } catch (_) {}
  }

  Future<void> clear() async {
    _syncService?.stop();
    _syncService = null;

    final storeIdBeforeClear = state?.storeId ?? '';
    try {
      final notifier = ref.read(printerSettingsProvider.notifier);
      await notifier.prepareForStoreLogout(storeIdBeforeClear);
    } catch (_) {}

    await UserAuthService.logout();
    state = null;
    AppLogger.updateSession(storeId: null, staffName: null);
    try {
      Supabase.instance.client.rest.headers.remove('x-user-id');
      Supabase.instance.client.rest.headers.remove('x-store-id');
    } catch (_) {}
  }
}

final sessionProvider = NotifierProvider<_SessionNotifier, SessionData?>(
  _SessionNotifier.new,
);

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
