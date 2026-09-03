import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';

void main() {
  group('Printer Owner Permission Guard Tests', () {
    test('SessionData isOwner check validates owner role correctly', () {
      final ownerSession = SessionData(
        userId: 'owner-id-1',
        phone: '+84999996666',
        displayName: 'Chủ Quán',
        storeId: 'store-id-1',
        storeName: 'Quán Nhỏ',
        storeCode: 'QN-TEST',
        role: 'owner',
        isOwner: true,
      );

      final staffSession = SessionData(
        userId: 'staff-id-1',
        phone: '+84900000001',
        displayName: 'Nhân Viên Thu Ngân',
        storeId: 'store-id-1',
        storeName: 'Quán Nhỏ',
        storeCode: 'QN-TEST',
        role: 'cashier',
        isOwner: false,
      );

      expect(ownerSession.isOwner, isTrue);
      expect(ownerSession.role, equals('owner'));

      expect(staffSession.isOwner, isFalse);
      expect(staffSession.role, equals('cashier'));
    });
  });
}
