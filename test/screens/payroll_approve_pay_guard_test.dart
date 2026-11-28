import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinhluong/repository/tinhluong_repository.dart';

// Duyệt kỳ chỉ Chủ quán, trả lương Chủ quán/Quản lý — app ẩn nút cho khớp máy chủ
// (guard_payroll_periods_v1 / guard_payroll_records_v1) và báo lỗi dễ hiểu.
void main() {
  final src = File(
    'lib/modules/tinhluong/screens/period_detail_screen.dart',
  ).readAsStringSync();

  test('Nút "Duyệt kỳ" chỉ dành cho Chủ quán', () {
    expect(src, contains('final canApprovePeriod = canApprove && isOwner;'));
    expect(src, isNot(contains("status == 'pending_review' && canApprove)")));
  });

  test('Nút "Trả lương" chỉ Chủ quán/Quản lý và chỉ khi phiếu chưa trả', () {
    expect(
      src,
      contains(
        "canApprove && (isOwner || roleCode == 'manager' || roleCode == 'admin')",
      ),
    );
    expect(src, contains("canPay && rec.paymentStatus == 'pending'"));
    expect(src, contains("r.paymentStatus == 'pending' &&"));
  });

  test('Lỗi máy chủ đổi thành câu dễ hiểu', () {
    expect(
      TinhLuongRepository.friendlyError(Exception('PAYROLL_OWNER_ONLY: x')),
      'Chỉ Chủ quán được duyệt / chốt kỳ lương.',
    );
    expect(
      TinhLuongRepository.friendlyError(Exception('PAYROLL_PAY_DENIED: x')),
      'Chỉ Chủ quán hoặc Quản lý được trả lương.',
    );
    expect(
      TinhLuongRepository.friendlyError(Exception('mất mạng')),
      'Có lỗi xảy ra, vui lòng thử lại.',
    );
  });

  test('Xác nhận đã nhận lương không nuốt lỗi', () {
    final repo = File(
      'lib/modules/tinhluong/repository/tinhluong_repository.dart',
    ).readAsStringSync();
    final start = repo.indexOf('static Future<void> confirmStaffPaid(');
    final body = repo.substring(
      start,
      repo.indexOf('static String friendlyError', start),
    );
    // Cập nhật trạng thái nằm ngoài try → lỗi máy chủ đi thẳng lên màn hình.
    final update = body.indexOf(".update({'payment_status': 'paid'})");
    final firstTry = body.indexOf('try {');
    expect(update, greaterThan(0));
    expect(update, lessThan(firstTry));
  });
}
