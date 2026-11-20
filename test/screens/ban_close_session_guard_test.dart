import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Phiên bàn chỉ được kết thúc qua thanh toán (settle_ban_session_v5), huỷ bàn có
// lý do + duyệt quản lý + audit (runCancelSteps) hoặc gộp bàn. Nút "X" ở cột
// "Đang phục vụ" từng đóng phiên không thu tiền (22/10/2026) — chặn tái phát.
void main() {
  final repo = File(
    'lib/core/repositories/ban_repository.dart',
  ).readAsStringSync();
  final screen = File('lib/screens/ban_screen.dart').readAsStringSync();

  test('BanRepository không còn hàm đóng phiên không thanh toán', () {
    expect(repo, isNot(contains('Future<void> closeSession(')));
  });

  test('Màn Bàn không gọi đóng phiên trực tiếp qua repository', () {
    expect(screen, isNot(contains('repo.closeSession(')));
    expect(screen, isNot(contains('_confirmClose(')));
    expect(screen, isNot(contains("'Đóng session'")));
  });

  test('Chỉ gộp bàn được đặt status=closed ở client', () {
    final closedWrites = RegExp(
      r"'status':\s*'closed'",
    ).allMatches(repo).length;
    expect(
      closedWrites,
      1,
      reason: 'chỉ mergeSession đóng phiên nguồn sau khi chuyển món',
    );
    expect(RegExp(r"'status':\s*'closed'").hasMatch(screen), isFalse);
  });
}
