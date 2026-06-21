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
            final newRole  = payload['newRole'] as String?;
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
              debugPrint('[StaffSync] Perms changed (broadcast) for role: $role');
              onPermsChanged?.call();
            }
          },
        )
        ..onBroadcast(
          event: 'staff_removed',
          callback: (payload) {
            final targetId = payload['userId'] as String?;
            if (targetId == currentUserId) {
              debugPrint('[StaffSync] Removed from store');
              onRemoved?.call();
            }
          },
        );
      await _channel!.subscribe();

      // ── 2. Postgres Realtime — watch store_roles table trực tiếp ─────────
      // Đây là nguồn tin cậy hơn broadcast: khi chủ lưu modules, DB thay đổi
      // → staff nhận event ngay lập tức, không phụ thuộc broadcast
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
              // Kiểm tra đây là role của mình
              final updatedRole = (payload.newRecord['name'] as String?)
                  ?.trim()
                  .toLowerCase();
              final myRole = currentRole.trim().toLowerCase();
              debugPrint('[StaffSync] store_roles updated: $updatedRole (mine: $myRole)');
              if (updatedRole == null || updatedRole == myRole) {
                onPermsChanged?.call();
              }
            },
          );
      await _rolesChannel!.subscribe();
      debugPrint('[StaffSync] Subscribed to $channelName + store_roles realtime');
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
      debugPrint('[StaffSync] Broadcast role_changed → $targetUserId: $newRole');
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
    _channel = null;
    _rolesChannel = null;
    debugPrint('[StaffSync] Unsubscribed');
  }
}
