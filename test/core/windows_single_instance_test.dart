// Mở app Windows lần hai = hai máy chủ in cùng nhận phiếu -> mỗi phiếu bếp in đôi
// (KAY-Rạch Giá 04/11/2026). main.cpp không chạy được trong flutter test nên khoá bằng mã nguồn.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('windows/runner/main.cpp').readAsStringSync();
  final win32 = File('windows/runner/win32_window.cpp').readAsStringSync();

  test('kiểm tra bản đang chạy trước khi tạo cửa sổ và máy chủ in', () {
    final check = src.indexOf('if (IsAnotherInstanceRunning())');
    expect(check, greaterThan(-1));
    expect(check, lessThan(src.indexOf('FlutterWindow window(project)')));
    expect(src, contains('return EXIT_SUCCESS;'));
  });

  test('tìm đúng cửa sổ của app: lớp và tiêu đề khớp lúc tạo', () {
    expect(win32, contains('L"FLUTTER_RUNNER_WIN32_WINDOW"'));
    expect(src, contains('window.Create(L"quannho_pos"'));
    expect(
      src,
      contains('FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"quannho_pos")'),
    );
  });

  test('main.cpp chỉ có ký tự ASCII (MSVC /WX báo C4819 làm hỏng build)', () {
    expect(src.codeUnits.where((c) => c > 127), isEmpty);
  });
}
