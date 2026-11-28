// Lịch đặt dạng lưới (đợt 2): vị trí khối theo giờ, cắt qua nửa đêm, ô trống làm tròn nửa giờ.
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc.dart';
import 'package:quannho_pos/modules/tinh_gio/lich_luoi.dart';

DatTruoc dat(DateTime tu, DateTime den, {String tt = 'da_dat'}) => DatTruoc(
      id: 'x',
      tableId: 'b',
      tenKhach: 'Khách',
      gioTu: tu,
      gioDen: den,
      trangThai: tt,
      createdAt: DateTime(2030, 11, 29),
    );

void main() {
  final ngay = DateTime(2030, 11, 30);

  test('giờ đầu lưới: 6 giờ, sớm hơn nếu có lượt sớm hơn', () {
    expect(lichGioDau(ngay, [dat(DateTime(2030, 11, 30, 17), DateTime(2030, 11, 30, 18))]), 6);
    expect(lichGioDau(ngay, [dat(DateTime(2030, 11, 30, 4, 30), DateTime(2030, 11, 30, 6))]), 4);
  });

  test('vị trí khối: 17:00–18:30 bắt đầu ở 11 giờ sau 06:00', () {
    final v = lichViTriKhoi(dat(DateTime(2030, 11, 30, 17), DateTime(2030, 11, 30, 18, 30)), ngay, 6)!;
    expect(v.top, 11 * kLichPxGio);
    expect(v.cao, 1.5 * kLichPxGio);
    expect(v.quaDem, isFalse);
  });

  test('qua nửa đêm: cắt ở 24:00, đánh dấu hôm sau; khối ngắn vẫn cao tối thiểu 24', () {
    final v = lichViTriKhoi(dat(DateTime(2030, 11, 30, 23), DateTime(2030, 12, 1, 1)), ngay, 6)!;
    expect(v.cao, kLichPxGio);
    expect(v.quaDem, isTrue);
    expect(lichViTriKhoi(dat(DateTime(2030, 11, 30, 9), DateTime(2030, 11, 30, 9, 10)), ngay, 6)!.cao, 24);
    expect(lichViTriKhoi(dat(DateTime(2030, 12, 1, 9), DateTime(2030, 12, 1, 10)), ngay, 6), isNull);
  });

  test('ô trống làm tròn xuống nửa giờ', () {
    expect(lichGioCuaO(ngay, 6, 0), DateTime(2030, 11, 30, 6));
    expect(lichGioCuaO(ngay, 6, 11 * kLichPxGio + 20), DateTime(2030, 11, 30, 17));
    expect(lichGioCuaO(ngay, 6, 11 * kLichPxGio + 40), DateTime(2030, 11, 30, 17, 30));
  });
}
