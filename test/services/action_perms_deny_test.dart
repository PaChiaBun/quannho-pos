import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/staff_service.dart';

// "Hành động nhạy cảm": tắt công tắc phải bỏ được cả quyền suy từ module.
void main() {
  test('Mặc định: Phục vụ có Bán hàng KHÔNG có huỷ đơn / sửa giá', () {
    for (final role in ['Phục vụ', 'waiter', 'Chạy bàn']) {
      final derived = StaffService.deriveActionPermsFromModules([
        'pos',
      ], roleName: role);
      expect(derived, isNot(contains('pos.cancel_bill')), reason: role);
      expect(derived, isNot(contains('pos.edit_price')), reason: role);
      expect(
        derived,
        containsAll(['pos.checkout', 'pos.apply_discount', 'pos.view_history']),
      );
    }
  });

  test('Vai trò khác có Bán hàng vẫn đủ quyền pos như cũ', () {
    for (final role in ['Thu ngân', 'Nhân viên', 'barista']) {
      final derived = StaffService.deriveActionPermsFromModules([
        'pos',
      ], roleName: role);
      expect(
        derived,
        containsAll(['pos.cancel_bill', 'pos.edit_price']),
        reason: role,
      );
    }
  });

  test('Chủ quán bật thêm huỷ đơn cho Phục vụ thì có lại quyền', () {
    final derived = StaffService.deriveActionPermsFromModules([
      'pos',
    ], roleName: 'Phục vụ');
    final enabled = {...derived, 'pos.cancel_bill'};
    final denied = StaffService.computeDeniedActions(
      derived: derived,
      enabled: enabled,
    );
    final effective = StaffService.applyActionDeny(
      enabled.union(derived),
      denied,
    );
    expect(effective, contains('pos.cancel_bill'));
    expect(effective, isNot(contains('pos.edit_price')));
  });

  test(
    'Thu ngân có Bán hàng: tắt huỷ đơn / sửa giá thì mất đúng 2 quyền đó',
    () {
      final derived = StaffService.deriveActionPermsFromModules([
        'pos',
      ], roleName: 'Thu ngân');
      final enabled = derived.difference({'pos.cancel_bill', 'pos.edit_price'});
      final denied = StaffService.computeDeniedActions(
        derived: derived,
        enabled: enabled,
      );
      expect(denied, {'pos.cancel_bill', 'pos.edit_price'});
      final effective = StaffService.applyActionDeny(derived, denied);
      expect(effective, isNot(contains('pos.cancel_bill')));
      expect(effective, containsAll(['pos.checkout', 'pos.apply_discount']));
    },
  );

  test('Không tắt gì thì giữ nguyên quyền', () {
    final derived = StaffService.deriveActionPermsFromModules([
      'kho',
    ], roleName: 'Kho');
    final denied = StaffService.computeDeniedActions(
      derived: derived,
      enabled: derived,
    );
    expect(denied, isEmpty);
    expect(StaffService.applyActionDeny(derived, denied), derived);
  });

  test(
    'Danh sách tắt lưu ở khoá riêng, không đè mảng action_perms máy chủ đọc',
    () {
      expect(
        StaffService.deniedActionsKey('Phục vụ'),
        'action_perms_deny_Phục vụ',
      );
    },
  );

  test('Mọi nhánh trả quyền thực tế đều trừ danh sách tắt', () {
    final src = File('lib/core/services/staff_service.dart').readAsStringSync();
    final start = src.indexOf(
      'static Future<List<String>> getEffectiveActionPermissions(',
    );
    final body = src.substring(
      start,
      src.indexOf('static String deniedActionsKey', start),
    );
    expect('applyActionDeny('.allMatches(body).length, 3);
    expect(body, contains('roleSettingKeys('));
    expect(
      RegExp(r'return (merged|derivedPerms)\.toList\(\)').hasMatch(body),
      isFalse,
    );
  });

  test(
    'Cài đặt lưu theo tên vai trò của quán được ưu tiên cho tài khoản mang mã vai trò',
    () {
      // Tài khoản role "waiter", quán đặt tên "Phục vụ" → đọc "Phục vụ" trước cài đặt cũ "waiter".
      expect(
        StaffService.roleSettingKeys('waiter', ['Thu ngân', 'Phục vụ', 'Bếp']),
        ['Phục vụ', 'waiter'],
      );
      expect(StaffService.roleSettingKeys('cashier', ['Thu ngân', 'Phục vụ']), [
        'Thu ngân',
        'cashier',
      ]);
      // Vai trò tuỳ chỉnh: tên của quán (khác hoa thường) đứng trước mã.
      expect(
        StaffService.roleSettingKeys('Kế Toán', ['Kế toán', 'Thu ngân']).first,
        'Kế toán',
      );
      expect(
        StaffService.roleSettingKeys('Kế Toán', ['Kế toán', 'Thu ngân']),
        contains('Kế Toán'),
      );
    },
  );

  test(
    'Công tắc chưa được app kiểm tra phải có ghi chú, và thật sự chưa được kiểm tra',
    () {
      final files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.endsWith('.dart') &&
                !f.path.endsWith('staff_service.dart'),
          );
      final src = files.map((f) => f.readAsStringSync()).join('\n');
      for (final k in [
        'pos.edit_price',
        'pos.apply_discount',
        'finance.view_all',
      ]) {
        expect(kActionLimitNotes.containsKey(k), isTrue, reason: k);
        // Khi có code kiểm tra quyền này, xoá ghi chú tương ứng rồi sửa test.
        expect(
          src.contains("'$k'"),
          isFalse,
          reason: '$k đã được kiểm tra — xoá ghi chú',
        );
      }
    },
  );

  test(
    'Xoá vai trò không bao giờ chuyển nhân viên sang Chủ quán / Quản lý',
    () {
      expect(
        StoreRoleService.pickFallbackRole(['Quản lý', 'Nhân viên', 'Bếp']),
        'Nhân viên',
      );
      expect(
        StoreRoleService.pickFallbackRole(['Quản lý', 'Chủ quán']),
        isNull,
      );
      expect(StoreRoleService.pickFallbackRole([]), isNull);
    },
  );
}
