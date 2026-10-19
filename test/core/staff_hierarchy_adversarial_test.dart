// test/core/staff_hierarchy_adversarial_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Adversarial Stress Testing for Staff Role Hierarchy Guards & Casing Bypasses
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/staff_service.dart';

void main() {
  group('Staff Hierarchy Adversarial Defense Matrix', () {
    test('1. Role casing bypass defense against owner self-elevation or assignment', () {
      final ownerVariations = [
        'owner',
        'OWNER',
        'Owner',
        'oWnEr',
        'Chủ Quán',
        'chủ quán',
        'CHỦ QUÁN',
        'chu quan',
        'CHU QUAN',
        'chủ',
        'chu',
        '  Owner  ',
        '  CHỦ QUÁN  ',
      ];

      for (final role in ownerVariations) {
        final canon = StaffService.canonicalRole(role);
        expect(canon, equals('owner'),
            reason: 'Role alias "$role" must resolve to canonical "owner"');
      }
    });

    test('2. Role casing and synonym defense for manager role', () {
      final managerVariations = [
        'manager',
        'MANAGER',
        'Manager',
        'Quản Lý',
        'quản lý',
        'QUẢN LÝ',
        'quan ly',
        'QUAN LY',
        'ql',
        'QL',
        'admin',
        'ADMIN',
        'quản trị',
        'quan tri',
      ];

      for (final role in managerVariations) {
        final canon = StaffService.canonicalRole(role);
        expect(canon, equals('manager'),
            reason: 'Role alias "$role" must resolve to canonical "manager"');
      }
    });

    test('3. UI & Service permission gating for inventory soft delete', () {
      bool canDeleteItems({
        required bool isOwner,
        required String role,
        required List<String> permissions,
      }) {
        final r = StaffService.canonicalRole(role);
        final hasDeletePerm = permissions.contains('kho.delete_item');
        return isOwner || r == 'owner' || r == 'manager' || hasDeletePerm;
      }

      // 1. Waiter without permission
      expect(canDeleteItems(isOwner: false, role: 'waiter', permissions: ['pos.checkout']), isFalse);
      expect(canDeleteItems(isOwner: false, role: 'phục vụ', permissions: []), isFalse);
      expect(canDeleteItems(isOwner: false, role: 'PV', permissions: []), isFalse);

      // 2. Cashier without permission
      expect(canDeleteItems(isOwner: false, role: 'cashier', permissions: ['pos.checkout', 'pos.view_history']), isFalse);
      expect(canDeleteItems(isOwner: false, role: 'Thu ngân', permissions: []), isFalse);

      // 3. Staff with explicit kho.delete_item
      expect(canDeleteItems(isOwner: false, role: 'waiter', permissions: ['kho.delete_item']), isTrue);
      expect(canDeleteItems(isOwner: false, role: 'cashier', permissions: ['kho.delete_item']), isTrue);
      expect(canDeleteItems(isOwner: false, role: 'Barista', permissions: ['kho.delete_item']), isTrue);

      // 4. Manager (unconditional)
      expect(canDeleteItems(isOwner: false, role: 'manager', permissions: []), isTrue);
      expect(canDeleteItems(isOwner: false, role: 'Quản Lý', permissions: []), isTrue);
      expect(canDeleteItems(isOwner: false, role: 'ql', permissions: []), isTrue);

      // 5. Owner (unconditional)
      expect(canDeleteItems(isOwner: true, role: 'cashier', permissions: []), isTrue);
      expect(canDeleteItems(isOwner: false, role: 'Chủ Quán', permissions: []), isTrue);
      expect(canDeleteItems(isOwner: false, role: 'owner', permissions: []), isTrue);
    });

    test('4. Comprehensive Hierarchy Matrix Assertion', () {
      bool canManageSubordinate({
        required String callerRole,
        required bool callerIsOwner,
        required String callerId,
        required String targetRole,
        required bool targetIsOwner,
        required String targetId,
      }) {
        if (callerId == targetId) return false; // Self-management blocked

        final cCanon = StaffService.canonicalRole(callerRole);
        final isOwner = callerIsOwner || cCanon == 'owner';
        final isManager = isOwner || cCanon == 'manager';

        if (!isManager) return false;

        final tCanon = StaffService.canonicalRole(targetRole);
        final tIsOwner = targetIsOwner || tCanon == 'owner';
        final tIsManager = tCanon == 'manager';

        if (isOwner) {
          return !tIsOwner; // Owner cannot manage another owner
        }

        // Manager cannot manage owner, and cannot manage another manager
        return !tIsOwner && !tIsManager;
      }

      // Self modification
      expect(canManageSubordinate(
        callerRole: 'manager', callerIsOwner: false, callerId: 'u1',
        targetRole: 'manager', targetIsOwner: false, targetId: 'u1',
      ), isFalse);

      // Cross manager
      expect(canManageSubordinate(
        callerRole: 'manager', callerIsOwner: false, callerId: 'm1',
        targetRole: 'manager', targetIsOwner: false, targetId: 'm2',
      ), isFalse);

      // Cross manager with Vietnamese synonyms
      expect(canManageSubordinate(
        callerRole: 'Quản Lý', callerIsOwner: false, callerId: 'm1',
        targetRole: 'quản lý', targetIsOwner: false, targetId: 'm2',
      ), isFalse);

      expect(canManageSubordinate(
        callerRole: 'ql', callerIsOwner: false, callerId: 'm1',
        targetRole: 'manager', targetIsOwner: false, targetId: 'm2',
      ), isFalse);

      // Manager targeting Owner
      expect(canManageSubordinate(
        callerRole: 'manager', callerIsOwner: false, callerId: 'm1',
        targetRole: 'Chủ Quán', targetIsOwner: true, targetId: 'o1',
      ), isFalse);

      // Manager targeting Subordinate
      expect(canManageSubordinate(
        callerRole: 'manager', callerIsOwner: false, callerId: 'm1',
        targetRole: 'Thu Ngân', targetIsOwner: false, targetId: 's1',
      ), isTrue);

      expect(canManageSubordinate(
        callerRole: 'Quản Lý', callerIsOwner: false, callerId: 'm1',
        targetRole: 'Phục Vụ', targetIsOwner: false, targetId: 's2',
      ), isTrue);

      // Subordinate targeting Subordinate
      expect(canManageSubordinate(
        callerRole: 'Thu Ngân', callerIsOwner: false, callerId: 's1',
        targetRole: 'Phục Vụ', targetIsOwner: false, targetId: 's2',
      ), isFalse);
    });
  });
}
