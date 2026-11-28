import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/vietqr_service.dart';
import 'package:quannho_pos/core/utils/vietqr.dart';

void main() {
  test('QR in trên bill: có số tiền + mã đơn, hoặc tĩnh không số tiền', () {
    final p = buildVietQrPayload(
      bin: '970422',
      accountNo: '0123456789',
      amount: 150000,
      content: 'QN1A2B3C Ban 5',
    );
    expect(p, contains('010212'));
    expect(p, contains('5406150000'));
    expect(p, contains('QN1A2B3C Ban 5'));
    final s = buildVietQrPayload(bin: '970422', accountNo: '0123456789');
    expect(s, contains('010211'));
    expect(s, isNot(contains('5406')));
    expect(s.substring(s.length - 4), vietQrCrc16(s.substring(0, s.length - 4)));
  });

  test('mã đơn lấy 6 ký tự đầu của phiên bàn', () {
    expect(
      VietQrService.transferCode('1a2b3c4d-0000-0000-0000-000000000000'),
      'QN1A2B3C',
    );
    expect(VietQrService.transferCode(''), '');
  });

  test('nội dung CK không dấu, tối đa 25 ký tự', () {
    expect(VietQrService.transferContent('QN1A2B3C', 'Bàn 5'), 'QN1A2B3C Ban 5');
    expect(VietQrService.transferContent('', 'Đường #2'), 'Duong 2');
    final long = VietQrService.transferContent('QN1A2B3C', 'Sân vườn phía sau bếp');
    expect(long.length, lessThanOrEqualTo(25));
    expect(long, startsWith('QN1A2B3C San vuon'));
  });
}
