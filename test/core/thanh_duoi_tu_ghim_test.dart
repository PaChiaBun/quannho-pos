// Thanh dưới tự ghim (01/11/2026): vai trò ít mục không còn lặp nút Trang chủ.
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';

void main() {
  test('vai trò ít mục (Bảo vệ): lấp bằng mục được phép khác, không lặp Trang chủ', () {
    // Chỉ Chấm công (10) đang bật; Vận Hành (13) luôn được phép dù module tắt.
    expect(padNavSlots([0, 10, 6], {0, 6, 10}, {0, 6, 10, 13}), [0, 10, 6, 13]);
  });

  test('đủ 4 mục đang bật thì giữ nguyên thứ tự đã ghim', () {
    expect(padNavSlots([0, 1, 7, 8], {0, 1, 6, 7, 8}, {0, 1, 6, 7, 8, 13}), [0, 1, 7, 8]);
  });

  test('hết mục mới lặp mục đầu', () {
    expect(padNavSlots([0], {0}), [0, 0, 0, 0]);
  });
}
