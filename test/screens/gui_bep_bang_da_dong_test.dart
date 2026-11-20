// KAY 16/11 (bàn C 2): bảng bàn đóng giữa lúc gửi bếp → `ref` ném "Using ref when a widget is ... unmounted",
// món không tới bếp, nhân viên phải bấm lại. Gửi bếp không được phụ thuộc bảng bàn còn mở hay không.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final screen = File('lib/screens/ban_screen.dart').readAsStringSync();
  String between(String from, String to) {
    final a = screen.indexOf(from);
    expect(a, isNot(-1), reason: 'không thấy $from');
    return screen.substring(a, screen.indexOf(to, a));
  }

  test('gửi bếp lấy kho provider ngay lúc bấm, trước mọi lệnh chờ', () {
    final send = between('Future<void> _sendToKitchen(', 'Future<void> _sendToKitchenImpl(');
    final capture = send.indexOf('ProviderScope.containerOf(context, listen: false)');
    expect(capture, isNot(-1));
    expect(capture, lessThan(send.indexOf('await ')));
    expect(send, contains('_sendToKitchenImpl(updatedItems, container)'));
  });

  test('phần gửi bếp không dùng ref của bảng bàn (bảng đóng thì ref ném lỗi)', () {
    final impl = between('Future<void> _sendToKitchenImpl(', 'Future<void> _autoPrintTicket({');
    expect(RegExp(r'\bref\.').hasMatch(impl), isFalse);
  });

  test('lưu ghi chú món xong chỉ làm mới khi bảng bàn còn mở', () {
    final note = between('Future<void> _updateItemNote(', '// ── Gửi bếp');
    expect(note, contains('if (mounted) ref.invalidate('));
  });
}
