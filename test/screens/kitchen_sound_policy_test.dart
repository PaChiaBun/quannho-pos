import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/screens/kitchen_screen.dart';

void main() {
  group('Kitchen sound role policy', () {
    test('chỉ vai trò Bếp được phát âm thanh Phiếu Bếp', () {
      expect(shouldPlayKitchenSoundsForRole('kitchen'), isTrue);
      expect(shouldPlayKitchenSoundsForRole('Bếp'), isTrue);
      expect(shouldPlayKitchenSoundsForRole('Bếp nóng'), isTrue);

      expect(shouldPlayKitchenSoundsForRole('cashier'), isFalse);
      expect(shouldPlayKitchenSoundsForRole('Thu ngân'), isFalse);
      expect(shouldPlayKitchenSoundsForRole('Phục vụ'), isFalse);
      expect(shouldPlayKitchenSoundsForRole('Quản lý'), isFalse);
      expect(shouldPlayKitchenSoundsForRole('owner'), isFalse);
      expect(shouldPlayKitchenSoundsForRole(null), isFalse);
    });
  });
}
