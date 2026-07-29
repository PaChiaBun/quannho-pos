import 'package:flutter_test/flutter_test.dart';
import '../../../lib/core/services/staff_service.dart';

void main() {
  group('StaffService.parseActionPermissions', () {
    test('nên parse đúng từ mảng List<String> hợp lệ', () {
      final input = ['pos.cancel_bill', 'tinhluong.view_all'];
      final result = StaffService.parseActionPermissions(input);
      expect(result, ['pos.cancel_bill', 'tinhluong.view_all']);
    });

    test('nên parse đúng từ JSON string mảng hợp lệ', () {
      final input = '["pos.cancel_bill", "tinhluong.view_all"]';
      final result = StaffService.parseActionPermissions(input);
      expect(result, ['pos.cancel_bill', 'tinhluong.view_all']);
    });

    test('nên lọc bỏ các action không nằm trong kAllActions', () {
      final input = ['pos.cancel_bill', 'unknown.action', 'tinhluong.manage_config'];
      final result = StaffService.parseActionPermissions(input);
      expect(result, ['pos.cancel_bill', 'tinhluong.manage_config']);
    });

    test('nên fail-closed (trả về rỗng) khi input là null', () {
      final result = StaffService.parseActionPermissions(null);
      expect(result, isEmpty);
    });

    test('nên fail-closed khi override mảng rỗng [] rõ ràng', () {
      final result = StaffService.parseActionPermissions([]);
      expect(result, isEmpty);
    });

    test('nên fail-closed khi chuỗi JSON bị malformed', () {
      final input = '["pos.cancel_bill", '; // Lỗi cú pháp JSON
      final result = StaffService.parseActionPermissions(input);
      expect(result, isEmpty);
    });

    test('nên fail-closed khi JSON parse ra không phải là mảng', () {
      final input = '{"action": "pos.cancel_bill"}';
      final result = StaffService.parseActionPermissions(input);
      expect(result, isEmpty);
    });

    test('nên fail-closed khi input không phải String hoặc List', () {
      final input = 123;
      final result = StaffService.parseActionPermissions(input);
      expect(result, isEmpty);
    });

    test('nên loại bỏ các phần tử không phải String trong mảng', () {
      final input = ['pos.cancel_bill', 123, null, 'tinhluong.view_all'];
      final result = StaffService.parseActionPermissions(input);
      expect(result, ['pos.cancel_bill', 'tinhluong.view_all']);
    });
  });
}
