// Báo cáo tính giờ (đợt 5): chia phút theo giờ, tổng hợp theo bàn / ngày, ghép dữ liệu máy chủ.
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinh_gio/bao_cao_tinh_gio.dart';

void main() {
  test('chia phút vào từng giờ: 18:40–20:10 = 20 + 60 + 10', () {
    final g = List<double>.filled(24, 0);
    chiaPhutTheoGio(DateTime(2030, 12, 3, 18, 40), DateTime(2030, 12, 3, 20, 10), g);
    expect([g[18], g[19], g[20]], [20, 60, 10]);
    expect(g.reduce((a, b) => a + b), 90);
  });

  test('vắt qua nửa đêm: 23:30–00:45 = 30 vào giờ 23, 45 vào giờ 0', () {
    final g = List<double>.filled(24, 0);
    chiaPhutTheoGio(DateTime(2030, 12, 3, 23, 30), DateTime(2030, 12, 4, 0, 45), g);
    expect([g[23], g[0]], [30, 45]);
  });

  test('tổng hợp: lượt, phút, tiền theo bàn, theo ngày, tỉ lệ giờ', () {
    final ds = [
      LuotChoi(
        tableId: 'a',
        thanhToanLuc: DateTime(2030, 12, 3, 20, 10),
        doan: [DoanGio(DateTime(2030, 12, 3, 18), DateTime(2030, 12, 3, 20))],
        tienGio: 120000,
        tienMon: 40000,
      ),
      LuotChoi(
        tableId: 'a',
        thanhToanLuc: DateTime(2030, 12, 4, 19),
        doan: [DoanGio(DateTime(2030, 12, 4, 18), DateTime(2030, 12, 4, 19))],
        tienGio: 60000,
        tienMon: 0,
      ),
      LuotChoi(
        tableId: 'b',
        thanhToanLuc: DateTime(2030, 12, 4, 19),
        doan: [DoanGio(DateTime(2030, 12, 4, 18), DateTime(2030, 12, 4, 18, 30))],
        tienGio: 30000,
        tienMon: 30000,
      ),
    ];
    final t = tongHopTinhGio(ds, soNgay: 2, soBan: 2);
    expect((t.luot, t.phut, t.tienGio, t.tienMon), (3, 210.0, 210000.0, 70000.0));
    expect(t.theoBan['a']!.luot, 2);
    expect(t.theoBan['a']!.phut, 180);
    expect(t.theoNgay[DateTime(2030, 12, 4)], (gio: 90000.0, mon: 30000.0));
    // giờ 18: 60 + 60 + 30 = 150 phút / (60 × 2 ngày × 2 bàn) = 62,5%
    expect(t.tiLeGio(18), closeTo(0.625, 1e-9));
    expect(t.tiLeTienGio, closeTo(210 / 280, 1e-9));
  });

  test('ghép phiên + dòng: dòng có gio_tu là tiền giờ, còn lại là món', () {
    final l = ghepLuotChoi([
      {'id': 's1', 'table_id': 't1', 'closed_at': '2030-12-03T13:00:00Z'},
      {'id': 's2', 'table_id': 't2', 'closed_at': '2030-12-03T14:00:00Z'},
    ], [
      {'session_id': 's1', 'subtotal': 50000, 'gio_tu': '2030-12-03T11:00:00Z', 'gio_den': '2030-12-03T12:00:00Z'},
      {'session_id': 's1', 'subtotal': 25000, 'gio_tu': null, 'gio_den': null},
      {'session_id': 's1', 'subtotal': 10000, 'gio_tu': '2030-12-03T12:10:00Z', 'gio_den': '2030-12-03T12:30:00Z'},
    ]);
    expect(l.length, 2);
    expect((l[0].tienGio, l[0].tienMon, l[0].phut), (60000.0, 25000.0, 80.0));
    expect((l[1].tienGio, l[1].tienMon, l[1].phut), (0.0, 0.0, 0.0));
  });

  test('số ngày của khoảng tính cả hai đầu', () {
    expect(soNgayCua((tu: DateTime(2030, 12, 1), den: DateTime(2030, 12, 7))), 7);
    expect(soNgayCua((tu: DateTime(2030, 12, 7), den: DateTime(2030, 12, 7, 15))), 1);
  });

  test('khoangTuKy: kỳ của tab Doanh thu → ngày đầu – ngày cuối, cắt ở hôm nay', () {
    final nay = DateTime(2026, 11, 28, 20);
    ms(DateTime d) => d.millisecondsSinceEpoch;
    // Hôm nay
    var k = khoangTuKy(ms(DateTime(2026, 11, 28)), ms(DateTime(2026, 11, 29)), homNay: nay);
    expect([k.tu, k.den], [DateTime(2026, 11, 28), DateTime(2026, 11, 28)]);
    // Tuần này (T2 23/11 – CN 29/11): cắt ở hôm nay 28/11
    k = khoangTuKy(ms(DateTime(2026, 11, 23)), ms(DateTime(2026, 11, 30)), homNay: nay);
    expect([k.tu, k.den, soNgayCua(k)], [DateTime(2026, 11, 23), DateTime(2026, 11, 28), 6]);
    // Tháng trước: đủ tháng
    k = khoangTuKy(ms(DateTime(2026, 10, 1)), ms(DateTime(2026, 11, 1)), homNay: nay);
    expect([k.tu, k.den, soNgayCua(k)], [DateTime(2026, 10, 1), DateTime(2026, 10, 31), 31]);
  });
}
