// lib/core/services/staff_sync_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Staff Sync Service — Real-time thông báo khi role/permission thay đổi
// Pattern: broadcast trên channel "staff_sync_{storeId}"
//
// Events:
//   role_changed    → {userId, newRole}    → staff refresh session
//   perms_changed   → {role}               → staff reload permissions
//   staff_removed   → {userId}             → staff bị kick, đăng xuất
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_auth_service.dart';

class StaffSyncService {
  final String storeId;
  final String currentUserId;
  final String currentRole;

  /// Callback khi role của user này bị đổi
  final void Function(String newRole)? onRoleChanged;

  /// Callback khi quyền của role này bị đổi
  final void Function()? onPermsChanged;

  /// Callback khi user này bị xoá khỏi quán
  final void Function()? onRemoved;

  RealtimeChannel? _channel;

  StaffSyncService({
    required this.storeId,
    required this.currentUserId,
    required this.currentRole,
    this.onRoleChanged,
    this.onPermsChanged,
    this.onRemoved,
  });

  // ── Khởi động lắng nghe ───────────────────────────────────────────────────
  RealtimeChannel? _rolesChannel; // channel riêng cho store_roles changes
  RealtimeChannel? _membersChannel; // channel cho store_members DELETE events

  Future<void> start() async {
    try {
      final db = Supabase.instance.client;
      final channelName = 'staff_sync_$storeId';

      // ── 1. Broadcast channel (role_changed, staff_removed) ────────────────
      _channel = db.channel(channelName)
        ..onBroadcast(
          event: 'role_changed',
          callback: (payload) {
            final targetId = payload['userId'] as String?;
            final newRole = payload['newRole'] as String?;
            if (targetId == currentUserId && newRole != null) {
              debugPrint('[StaffSync] Role changed → $newRole');
              onRoleChanged?.call(newRole);
            }
          },
        )
        ..onBroadcast(
          event: 'perms_changed',
          callback: (payload) {
            final role = payload['role'] as String?;
            if (role == null || role == currentRole) {
              debugPrint(
                '[StaffSync] Perms changed (broadcast) for role: $role',
              );
              onPermsChanged?.call();
            }
          },
        )
        ..onBroadcast(
          event: 'staff_removed',
          callback: (payload) {
            final targetId = payload['userId'] as String?;
            if (targetId == currentUserId) {
              debugPrint('[StaffSync] Removed from store (broadcast)');
              onRemoved?.call();
            }
          },
        );
      await _channel!.subscribe();

      // ── 2. Postgres Realtime — watch store_roles table trực tiếp ─────────
      _rolesChannel = db
          .channel('store_roles_changes_$storeId')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'store_roles',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            ),
            callback: (payload) {
              final updatedRole = (payload.newRecord['name'] as String?)
                  ?.trim()
                  .toLowerCase();
              final myRole = currentRole.trim().toLowerCase();
              debugPrint(
                '[StaffSync] store_roles updated: $updatedRole (mine: $myRole)',
              );
              if (updatedRole == null || updatedRole == myRole) {
                onPermsChanged?.call();
              }
            },
          );
      await _rolesChannel!.subscribe();

      // ── 3. Postgres Realtime — watch store_members DELETE trực tiếp ───────
      // Nguồn tin cậy DB Realtime: khi record store_members của user bị xoá
      _membersChannel = db
          .channel('store_members_changes_${storeId}_$currentUserId')
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'store_members',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            ),
            callback: (payload) async {
              final deletedStoreId = payload.oldRecord['store_id'] as String?;
              final deletedUserId =
                  payload.oldRecord['user_id'] as String? ??
                  payload.oldRecord['id'] as String?;
              debugPrint(
                '[StaffSync] store_members DELETE event: deletedStoreId=$deletedStoreId, deletedUserId=$deletedUserId, mine=$currentUserId',
              );

              if (deletedUserId != null && deletedUserId.isNotEmpty) {
                if (deletedUserId == currentUserId &&
                    (deletedStoreId == null || deletedStoreId == storeId)) {
                  debugPrint(
                    '[StaffSync] Target user match -> triggering onRemoved',
                  );
                  onRemoved?.call();
                } else {
                  debugPrint(
                    '[StaffSync] DELETE event targeting another user ($deletedUserId != $currentUserId) -> ignoring',
                  );
                }
              } else {
                // If oldRecord is empty (e.g. before REPLICA IDENTITY FULL), validate with server authoritatively
                debugPrint(
                  '[StaffSync] oldRecord empty/missing userId -> validating membership with server authoritatively',
                );
                try {
                  final val = await UserAuthService.validateActiveMembership(
                    userId: currentUserId,
                    storeId: storeId,
                  );
                  if (!val.isActive && !val.isOffline) {
                    onRemoved?.call();
                  }
                } catch (e) {
                  debugPrint('[StaffSync] Authoritative validation error: $e');
                }
              }
            },
          );
      await _membersChannel!.subscribe();

      debugPrint(
        '[StaffSync] Subscribed to $channelName + store_roles + store_members realtime',
      );
    } catch (e) {
      debugPrint('[StaffSync] start error: $e');
    }
  }

  // ── Gửi broadcast role_changed (gọi từ manager sau updateRole) ───────────
  static Future<void> broadcastRoleChanged({
    required String storeId,
    required String targetUserId,
    required String newRole,
  }) async {
    try {
      final db = Supabase.instance.client;
      // ‼️ FIX: subscribe trước khi send — Supabase drop message từ channel chưa subscribe
      final ch = db.channel('staff_sync_sender_${storeId}_role');
      await ch.subscribe();
      await ch.sendBroadcastMessage(
        event: 'role_changed',
        payload: {'userId': targetUserId, 'newRole': newRole},
      );
      await ch.unsubscribe();
      debugPrint(
        '[StaffSync] Broadcast role_changed → $targetUserId: $newRole',
      );
    } catch (e) {
      debugPrint('[StaffSync] broadcastRoleChanged error: $e');
    }
  }

  // ── Gửi broadcast perms_changed (gọi sau setModulePermissions) ───────────
  static Future<void> broadcastPermsChanged({
    required String storeId,
    required String role,
  }) async {
    try {
      final db = Supabase.instance.client;
      final ch = db.channel('staff_sync_sender_${storeId}_perms');
      await ch.subscribe();
      await ch.sendBroadcastMessage(
        event: 'perms_changed',
        payload: {'role': role},
      );
      await ch.unsubscribe();
      debugPrint('[StaffSync] Broadcast perms_changed → role: $role');
    } catch (e) {
      debugPrint('[StaffSync] broadcastPermsChanged error: $e');
    }
  }

  // ── Gửi broadcast staff_removed ──────────────────────────────────────────
  static Future<void> broadcastStaffRemoved({
    required String storeId,
    required String targetUserId,
  }) async {
    try {
      final db = Supabase.instance.client;
      final ch = db.channel('staff_sync_sender_${storeId}_remove');
      await ch.subscribe();
      await ch.sendBroadcastMessage(
        event: 'staff_removed',
        payload: {'userId': targetUserId},
      );
      await ch.unsubscribe();
    } catch (e) {
      debugPrint('[StaffSync] broadcastStaffRemoved error: $e');
    }
  }

  // ── Dừng lắng nghe ────────────────────────────────────────────────────────
  Future<void> stop() async {
    await _channel?.unsubscribe();
    await _rolesChannel?.unsubscribe();
    await _membersChannel?.unsubscribe();
    _channel = null;
    _rolesChannel = null;
    _membersChannel = null;
    debugPrint('[StaffSync] Unsubscribed');
  }
}
