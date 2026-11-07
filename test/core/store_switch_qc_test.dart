import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/staff_service.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';

void main() {
  group('QC Check — Direct Permissions & Store Membership', () {
    test('1. Canonical role mapping helper works', () {
      expect(StaffService.canonicalRole('owner'), equals('owner'));
      expect(StaffService.canonicalRole('Chủ quán'), equals('owner'));
      expect(StaffService.canonicalRole('manager'), equals('manager'));
      expect(StaffService.canonicalRole('Quản lý'), equals('manager'));
      expect(StaffService.canonicalRole('cashier'), equals('cashier'));
      expect(StaffService.canonicalRole('Thu ngân'), equals('cashier'));
      expect(StaffService.canonicalRole('waiter'), equals('waiter'));
      expect(StaffService.canonicalRole('Phục vụ'), equals('waiter'));
    });

    test('2. CreateStoreResult carries membership object on success', () {
      const membership = StoreMembership(
        storeId: 'store-123',
        storeName: 'KAY-Rạch Giá',
        storeCode: 'QN-4EJP',
        role: 'Barista',
        isOwner: false,
      );

      final result = CreateStoreResult.success(
        storeId: 'store-123',
        storeCode: 'QN-4EJP',
        membership: membership,
      );

      expect(result.isSuccess, isTrue);
      expect(result.storeId, equals('store-123'));
      expect(result.storeCode, equals('QN-4EJP'));
      expect(result.membership, isNotNull);
      expect(result.membership!.storeName, equals('KAY-Rạch Giá'));
      expect(result.membership!.role, equals('Barista'));
      expect(result.membership!.isOwner, isFalse);
    });

    test('3. StoreMembership properties integrity', () {
      const m = StoreMembership(
        storeId: 's-99',
        storeName: 'Quán Nhỏ POS Test',
        storeCode: 'QN-TEST',
        role: 'cashier',
        isOwner: false,
      );

      expect(m.storeId, equals('s-99'));
      expect(m.storeName, equals('Quán Nhỏ POS Test'));
      expect(m.storeCode, equals('QN-TEST'));
      expect(m.role, equals('cashier'));
      expect(m.isOwner, isFalse);
    });
  });
}
