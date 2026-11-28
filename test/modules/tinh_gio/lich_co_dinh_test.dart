// Lịch cố định (đợt 3): app đếm buổi trước khi gửi, khớp ban_dat_truoc_lap_v1
// (supabase/tests/dat_truoc_lich_co_dinh_test.sql). 02/12/2030 là Thứ Hai.
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc.dart';

void main() {
  final bayGio = DateTime(2030, 11, 30, 10);

  test('L1–L3: T3, T5 từ 03/12 tới 26/12 lúc 18:00 = 8 buổi, tính cả ngày cuối', () {
    final b = cacBuoiLap(DateTime(2030, 12, 3, 18), {2, 4}, DateTime(2030, 12, 26), 120, bayGio);
    expect(b.length, 8);
    expect(b.every((d) => (d.weekday == 2 || d.weekday == 4) && d.hour == 18 && d.minute == 0), isTrue);
    expect(b.last, DateTime(2030, 12, 26, 18));
  });

  test('bỏ buổi đã kết thúc; buổi đang diễn ra vẫn tính', () {
    final b = cacBuoiLap(DateTime(2030, 12, 3, 18), {2}, DateTime(2030, 12, 17), 120, DateTime(2030, 12, 10, 19));
    expect(b, [DateTime(2030, 12, 10, 18), DateTime(2030, 12, 17, 18)]);
  });

  test('không chọn thứ / ngày cuối trước ngày đầu: không có buổi', () {
    expect(cacBuoiLap(DateTime(2030, 12, 3, 18), {}, DateTime(2030, 12, 26), 60, bayGio), isEmpty);
    expect(cacBuoiLap(DateTime(2030, 12, 3, 18), {2}, DateTime(2030, 12, 1), 60, bayGio), isEmpty);
  });

  test('cả tuần trong 5 tháng vượt 120 buổi', () {
    expect(cacBuoiLap(DateTime(2031, 2, 1, 8), {1, 2, 3, 4, 5, 6, 7}, DateTime(2031, 7, 1), 60, bayGio).length,
        greaterThan(120));
  });

  test('đọc chuoi_id từ máy chủ', () {
    final d = DatTruoc.fromMap({
      'id': 'a',
      'table_id': 't',
      'ten_khach': 'K',
      'gio_tu': '2030-12-03T11:00:00Z',
      'gio_den': '2030-12-03T13:00:00Z',
      'trang_thai': 'da_dat',
      'chuoi_id': 'c1',
    });
    expect(d.chuoiId, 'c1');
  });
}
