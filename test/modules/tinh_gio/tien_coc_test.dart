// Tiền cọc = ví khách (đợt 4): phần trả bằng ví ở màn thu tiền phải khớp settle_ban_session_v6
// (supabase/tests/tien_coc_vi_khach_test.sql): min(tổng, cọc + trả thêm, số dư ví thật).
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc.dart';

void main() {
  test('cọc 200.000, bàn 480.000: trừ 200.000, khách trả thêm 280.000', () {
    expect(tienTraBangVi(tong: 480000, coc: 200000, soDu: 200000), 200000);
  });

  test('bàn ít hơn cọc: chỉ trừ bằng tổng', () {
    expect(tienTraBangVi(tong: 150000, coc: 200000, soDu: 200000), 150000);
  });

  test('ví đã bị trừ bớt (số dư thấp hơn cọc): trừ theo số dư', () {
    expect(tienTraBangVi(tong: 480000, coc: 200000, soDu: 120000), 120000);
    expect(tienTraBangVi(tong: 480000, coc: 200000, soDu: -5000), 0);
  });

  test('trả thêm bằng ví: tối đa tổng và số dư', () {
    expect(tienTraBangVi(tong: 480000, coc: 200000, traThem: 480000, soDu: 300000), 300000);
    expect(tienTraBangVi(tong: 480000, coc: 0, traThem: 1000000000, soDu: 900000), 480000);
    expect(tienTraBangVi(tong: 0, coc: 200000, soDu: 200000), 0);
  });

  test('đọc cột cọc từ máy chủ; chỉ "da_thu" là cọc còn chờ trừ', () {
    DatTruoc doc(String? tt) => DatTruoc.fromMap({
          'id': 'a',
          'table_id': 't',
          'ten_khach': 'Anh Nam',
          'gio_tu': '2030-12-03T11:00:00Z',
          'gio_den': '2030-12-03T13:00:00Z',
          'trang_thai': 'da_dat',
          'tien_coc': 200000,
          'customer_id': 'k1',
          'coc_trang_thai': tt,
          'coc_quy': 'bank',
        });
    final d = doc('da_thu');
    expect((d.customerId, d.cocQuy, d.coCocCho), ('k1', 'bank', true));
    for (final tt in [null, 'da_tru', 'trong_vi', 'quan_giu', 'da_hoan']) {
      expect(doc(tt).coCocCho, isFalse, reason: '$tt');
    }
  });
}
