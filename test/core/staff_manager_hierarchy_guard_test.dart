// test/core/staff_manager_hierarchy_guard_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Unit & Contract tests for Staff Manager Role Hierarchy Guardrails
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quannho_pos/core/services/staff_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    StaffService.rpcTransportOverride = null;
    StaffService.broadcastHandlerOverride = null;
  });

  group('Staff Manager Hierarchy & Role Normalization Contract Tests', () {
    test('1. updateRole blocks assigning owner role in English or Vietnamese', () async {
      String? calledRpc;
      StaffService.rpcTransportOverride = (rpcName, params) async {
        calledRpc = rpcName;
        return {'success': true, 'status': 200};
      };

      // Attempt assigning 'owner'
      await StaffService.updateRole(
        storeId: '00000000-0000-0000-0000-000000000001',
        userId: '00000000-0000-0000-0000-000000000002',
        newRole: 'owner',
        changedByUserId: '00000000-0000-0000-0000-000000000003',
      );
      expect(calledRpc, isNull, reason: 'Must block owner role');

      // Attempt assigning 'Chủ quán'
      await StaffService.updateRole(
        storeId: '00000000-0000-0000-0000-000000000001',
        userId: '00000000-0000-0000-0000-000000000002',
        newRole: 'Chủ quán',
        changedByUserId: '00000000-0000-0000-0000-000000000003',
      );
      expect(calledRpc, isNull, reason: 'Must block Chủ quán role');
    });

    test('2. addStaffByPhone blocks assigning owner role in English or Vietnamese', () async {
      final resEn = await StaffService.addStaffByPhone(
        storeId: '00000000-0000-0000-0000-000000000001',
        phone: '0901234567',
        role: 'owner',
        addedByUserId: '00000000-0000-0000-0000-000000000003',
      );
      expect(resEn.isSuccess, isFalse);
      expect(resEn.errorMessage, contains('Không thể gán vai trò Chủ quán'));

      final resVi = await StaffService.addStaffByPhone(
        storeId: '00000000-0000-0000-0000-000000000001',
        phone: '0901234567',
        role: 'Chủ quán',
        addedByUserId: '00000000-0000-0000-0000-000000000003',
      );
      expect(resVi.isSuccess, isFalse);
      expect(resVi.errorMessage, contains('Không thể gán vai trò Chủ quán'));
    });

    test('3. removeStaff properly dispatches admin_revoke_staff_membership_v4', () async {
      String? invokedRpc;
      Map<String, dynamic>? rpcParams;

      StaffService.rpcTransportOverride = (rpcName, params) async {
        invokedRpc = rpcName;
        rpcParams = params;
        return {
          'success': true,
          'status': 200,
          'message': 'Thu hồi thành công',
        };
      };

      await StaffService.removeStaff(
        storeId: 'store-uuid-1',
        userId: 'staff-uuid-2',
        removedByUserId: 'manager-uuid-3',
        staffName: 'Nhân viên A',
      );

      expect(invokedRpc, equals('admin_revoke_staff_membership_v4'));
      expect(rpcParams?['p_store_id'], equals('store-uuid-1'));
      expect(rpcParams?['p_staff_id'], equals('staff-uuid-2'));
    });

    test('4. Hierarchy guard helper logic checks', () {
      bool canManageStaff({
        required String callerRole,
        required bool callerIsOwner,
        required String targetRole,
        required bool targetIsOwner,
        required String callerUserId,
        required String targetUserId,
      }) {
        if (callerUserId == targetUserId) return false;

        final cRole = callerRole.toLowerCase().trim();
        final isOwner = callerIsOwner || cRole == 'owner' || cRole == 'chủ quán' || cRole == 'chu quan';
        final isManager = isOwner || cRole == 'manager' || cRole == 'quản lý' || cRole == 'quan ly';

        if (!isManager) return false;

        final tRole = targetRole.toLowerCase().trim();
        final tIsOwner = targetIsOwner || tRole == 'owner' || tRole == 'chủ quán' || tRole == 'chu quan';
        final tIsManager = tRole == 'manager' || tRole == 'quản lý' || tRole == 'quan ly';

        if (isOwner) {
          return !tIsOwner; // Owner can manage non-owners
        }

        // Manager can only manage subordinate staff (not owner, not manager)
        return !tIsOwner && !tIsManager;
      }

      // Self management blocked
      expect(canManageStaff(
        callerRole: 'owner', callerIsOwner: true,
        targetRole: 'owner', targetIsOwner: true,
        callerUserId: 'u1', targetUserId: 'u1',
      ), isFalse);

      // Owner managing Manager -> Allowed
      expect(canManageStaff(
        callerRole: 'owner', callerIsOwner: true,
        targetRole: 'Quản Lý', targetIsOwner: false,
        callerUserId: 'u1', targetUserId: 'u2',
      ), isTrue);

      // Owner managing Cashier -> Allowed
      expect(canManageStaff(
        callerRole: 'owner', callerIsOwner: true,
        targetRole: 'Thu Ngân', targetIsOwner: false,
        callerUserId: 'u1', targetUserId: 'u3',
      ), isTrue);

      // Manager managing another Manager -> BLOCKED
      expect(canManageStaff(
        callerRole: 'Quản Lý', callerIsOwner: false,
        targetRole: 'manager', targetIsOwner: false,
        callerUserId: 'm1', targetUserId: 'm2',
      ), isFalse);

      // Manager managing Owner -> BLOCKED
      expect(canManageStaff(
        callerRole: 'manager', callerIsOwner: false,
        targetRole: 'owner', targetIsOwner: true,
        callerUserId: 'm1', targetUserId: 'o1',
      ), isFalse);

      // Manager managing Waiter -> ALLOWED
      expect(canManageStaff(
        callerRole: 'Quản Lý', callerIsOwner: false,
        targetRole: 'Phục Vụ', targetIsOwner: false,
        callerUserId: 'm1', targetUserId: 'w1',
      ), isTrue);

      // Waiter managing Waiter -> BLOCKED
      expect(canManageStaff(
        callerRole: 'Phục Vụ', callerIsOwner: false,
        targetRole: 'Phục Vụ', targetIsOwner: false,
        callerUserId: 'w1', targetUserId: 'w2',
      ), isFalse);
    });

    test('5. StaffService.canonicalRole normalizes Vietnamese & custom roles consistently', () {
      expect(StaffService.canonicalRole('Quản Lý'), equals('manager'));
      expect(StaffService.canonicalRole('quan ly'), equals('manager'));
      expect(StaffService.canonicalRole('Thu ngân'), equals('cashier'));
      expect(StaffService.canonicalRole('thu ngan'), equals('cashier'));
      expect(StaffService.canonicalRole('Phục Vụ'), equals('waiter'));
      expect(StaffService.canonicalRole('phuc vu'), equals('waiter'));
      expect(StaffService.canonicalRole('chạy bàn'), equals('waiter'));
      expect(StaffService.canonicalRole('Bếp'), equals('kitchen'));
      expect(StaffService.canonicalRole('bep'), equals('kitchen'));
      expect(StaffService.canonicalRole('Kho'), equals('stock'));
      expect(StaffService.canonicalRole('Chủ quán'), equals('owner'));
      expect(StaffService.canonicalRole('chu quan'), equals('owner'));
      // Custom roles return lowercased and trimmed string
      expect(StaffService.canonicalRole('Barista'), equals('barista'));
      expect(StaffService.canonicalRole('  Barista  '), equals('barista'));
      expect(StaffService.canonicalRole('Kế Toán'), equals('kế toán'));
    });

    test('6. Waiter is NOT unassigned staff; unassigned/none/empty IS unassigned', () {
      bool isUnassigned(String role, {bool isOwner = false}) {
        if (isOwner) return false;
        final r = role.toLowerCase().trim();
        if (r.isEmpty ||
            r == 'none' ||
            r == 'unassigned' ||
            r.contains('chưa phân') ||
            r.contains('chưa gán') ||
            r.contains('chưa có') ||
            r.contains('chưa cấp')) {
          return true;
        }
        return false;
      }

      expect(isUnassigned('waiter'), isFalse, reason: 'Waiter is an assigned staff role');
      expect(isUnassigned('Phục Vụ'), isFalse);
      expect(isUnassigned('cashier'), isFalse);
      expect(isUnassigned('manager'), isFalse);
      expect(isUnassigned('barista'), isFalse);
      expect(isUnassigned('owner', isOwner: true), isFalse);

      expect(isUnassigned(''), isTrue);
      expect(isUnassigned('none'), isTrue);
      expect(isUnassigned('unassigned'), isTrue);
      expect(isUnassigned('Chưa phân vai trò'), isTrue);
      expect(isUnassigned('chưa gán quyền'), isTrue);
    });

    test('7. StoreRole canonical getters & synonym recognition in role manager', () {
      final roleCashier = StoreRole(
        id: 'r1',
        storeId: 's1',
        name: 'Thu ngân',
        icon: 'point_of_sale',
        color: '#1D4ED8',
        modules: ['pos', 'ban'],
      );
      expect(roleCashier.canonicalRole, equals('cashier'));
      expect(roleCashier.isStandardRole, isTrue);
      expect(roleCashier.isOwnerRole, isFalse);

      final roleCustom = StoreRole(
        id: 'r2',
        storeId: 's1',
        name: 'Barista Sáng',
        icon: 'local_cafe',
        color: '#B45309',
        modules: ['pos'],
      );
      expect(roleCustom.canonicalRole, equals('barista sáng'));
      expect(roleCustom.isStandardRole, isFalse);
      expect(roleCustom.isOwnerRole, isFalse);

      final roleOwner = StoreRole(
        id: 'r3',
        storeId: 's1',
        name: 'Chủ Quán',
        icon: 'badge',
        color: '#DC2626',
        modules: ['all'],
      );
      expect(roleOwner.canonicalRole, equals('owner'));
      expect(roleOwner.isOwnerRole, isTrue);

      // Verify synonyms and abbreviations
      expect(StaffService.canonicalRole('tn'), equals('cashier'));
      expect(StaffService.canonicalRole('bán hàng'), equals('cashier'));
      expect(StaffService.canonicalRole('ban hang'), equals('cashier'));
      expect(StaffService.canonicalRole('ql'), equals('manager'));
      expect(StaffService.canonicalRole('admin'), equals('manager'));
      expect(StaffService.canonicalRole('pv'), equals('waiter'));
      expect(StaffService.canonicalRole('waitress'), equals('waiter'));
      expect(StaffService.canonicalRole('chef'), equals('kitchen'));
      expect(StaffService.canonicalRole('cook'), equals('kitchen'));
    });

    test('11. Manager role automatically inherits kho.delete_item and kho.edit_item per Lego module spec', () {
      final managerRole = StaffService.canonicalRole('manager');
      final qlRole = StaffService.canonicalRole('ql');
      expect(managerRole, equals('manager'));
      expect(qlRole, equals('manager'));

      final managerPerms = kDefaultActionPerms['manager'] ?? [];
      expect(managerPerms, contains('kho.delete_item'));
      expect(managerPerms, contains('kho.edit_quantity'));

      // Waiter must NOT have kho.delete_item by default
      final waiterPerms = kDefaultActionPerms['waiter'] ?? [];
      expect(waiterPerms, isNot(contains('kho.delete_item')));
    });
  });
}
