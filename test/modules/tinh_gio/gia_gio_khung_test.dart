// Bộ ca dùng chung với supabase/tests/gia_gio_khung_block_test.sql: app tính tạm phải ra đúng số máy chủ chốt.
// Giờ dựng bằng DateTime giờ máy (coi là giờ Việt Nam như app). 30/11/2026 là Thứ Hai.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio.dart';

KhungGia k(Set<int> thu, String tu, String den, double gia) {
  int p(String s) => int.parse(s.split(':')[0]) * 60 + int.parse(s.split(':')[1]);
  return KhungGia(thu: thu, tuPhut: p(tu), denPhut: p(den), gia: gia);
}

const moiNgay = {1, 2, 3, 4, 5, 6, 7};

void main() {
  TienGio t(GiaGioCaiDat c, DateTime vao, int phut, [double goc = 60000]) =>
      tinhGioTien(vao: vao, phutChoi: phut, giaGoc: goc, caiDat: c);

  group('không cài gì = công thức cũ', () {
    test('C1, C2', () {
      final a = t(GiaGioCaiDat.macDinh, DateTime(2026, 11, 30, 14, 5), 90);
      expect([a.thanhTien, a.soPhutTinh, a.doan.length], [90000, 90, 1]);
      expect(t(GiaGioCaiDat.macDinh, DateTime(2026, 11, 30, 14, 5), 45).thanhTien, 45000);
    });
    test('hồi quy 2.000 lượt ngẫu nhiên khớp tinhGioThanhTien và công thức cũ', () {
      final r = Random(28);
      const gia = [60000.0, 35000.0, 12345.67, 0.0, 150000.0, 1000.0, 99999.0];
      for (var i = 0; i < 2000; i++) {
        final phut = 1 + r.nextInt(3000);
        final g = gia[r.nextInt(gia.length)];
        final vao = DateTime(2026, 11, 1).add(Duration(seconds: r.nextInt(86400 * 60)));
        final cu = (phut * g * 100).round(); // số nguyên phần trăm đồng, như numeric ở máy chủ
        final ky = ((cu + 6000000 - 1) ~/ 6000000) * 1000.0;
        expect(t(GiaGioCaiDat.macDinh, vao, phut, g).thanhTien, cu <= 0 ? 0 : ky, reason: '$phut × $g');
        expect(tinhGioThanhTien(phut, g), t(GiaGioCaiDat.macDinh, vao, phut, g).thanhTien);
      }
    });
  });

  group('khung giá', () {
    final toi = GiaGioCaiDat(khung: [k(moiNgay, '17:00', '00:00', 80000)]);
    test('C3 vắt khung 16:30–17:30', () {
      final a = t(toi, DateTime(2026, 11, 30, 16, 30), 60);
      expect(a.thanhTien, 70000);
      expect(a.doan.map((d) => [d.phut, d.gia]), [
        [30, 60000],
        [30, 80000],
      ]);
    });
    test('C15 có giây: 16:59:30 giá gốc, 17:00:30 giá khung', () {
      final a = t(toi, DateTime(2026, 11, 30, 16, 59, 30), 2);
      expect(a.thanhTien, 3000);
      expect(a.doan.first.gia, 60000);
    });
    test('C4 qua đêm 22:00–02:00', () {
      final dem = GiaGioCaiDat(khung: [k(moiNgay, '22:00', '02:00', 90000)]);
      expect(t(dem, DateTime(2026, 11, 30, 23), 120).thanhTien, 180000);
      expect(t(dem, DateTime(2026, 12, 1, 1, 30), 60).thanhTien, 75000);
    });
    test('C5 khung cả ngày T7, CN', () {
      final cuoiTuan = GiaGioCaiDat(khung: [k({6, 7}, '00:00', '00:00', 100000)]);
      expect(t(cuoiTuan, DateTime(2026, 12, 4, 23, 30), 60).thanhTien, 80000);
      expect(t(cuoiTuan, DateTime(2026, 11, 30, 10), 60).thanhTien, 60000);
    });
    test('C14 khung đứng trên thắng', () {
      final chong = GiaGioCaiDat(khung: [k(moiNgay, '18:00', '20:00', 90000), k(moiNgay, '17:00', '00:00', 80000)]);
      expect(t(chong, DateTime(2026, 11, 30, 18), 60).thanhTien, 90000);
      expect(t(chong, DateTime(2026, 11, 30, 17, 30), 60).thanhTien, 85000);
    });
    test('C13 giá 0', () {
      expect(t(toi, DateTime(2026, 11, 30, 10), 60, 0).thanhTien, 0);
    });
  });

  group('làm tròn', () {
    test('C6–C10', () {
      expect(tinhGioLamTron(47, const GiaGioCaiDat(block: 30)), 60);
      expect(tinhGioLamTron(3, const GiaGioCaiDat(block: 30)), 30);
      expect(tinhGioLamTron(33, const GiaGioCaiDat(block: 30, anHan: 5)), 30);
      expect(tinhGioLamTron(36, const GiaGioCaiDat(block: 30, anHan: 5)), 60);
      expect(tinhGioLamTron(4, const GiaGioCaiDat(block: 30, anHan: 5)), 30);
      expect(tinhGioLamTron(20, const GiaGioCaiDat(toiThieu: 60)), 60);
      expect(tinhGioLamTron(75, const GiaGioCaiDat(toiThieu: 60)), 75);
      expect(tinhGioLamTron(120, const GiaGioCaiDat(block: 30)), 120);
      expect(t(const GiaGioCaiDat(block: 30), DateTime(2026, 11, 30, 14), 47).thanhTien, 60000);
    });
    test('C11 khung + block: 16:50 chơi 25 phút', () {
      final c = GiaGioCaiDat(block: 30, khung: [k(moiNgay, '17:00', '00:00', 80000)]);
      final a = t(c, DateTime(2026, 11, 30, 16, 50), 25);
      expect([a.soPhutTinh, a.thanhTien], [30, 37000]);
    });
  });

  test('tạm tính bàn dùng cài đặt khung', () {
    final vao = DateTime(2026, 11, 30, 16, 30);
    final r = tinhGioTamTinhBan(
      gioBatDauMs: vao.millisecondsSinceEpoch,
      giaMotGio: 60000,
      mon: const [],
      luc: vao.add(const Duration(minutes: 60)),
      caiDat: GiaGioCaiDat(khung: [k(moiNgay, '17:00', '00:00', 80000)]),
    );
    expect([r.tienGio, r.soPhut, r.soPhutTinh], [70000, 60, 60]);
  });

  test('chữ hiển thị khung', () {
    expect(k({1, 2, 3, 4, 5}, '17:00', '23:00', 1).thuChu, 'T2–T6');
    expect(k({6, 7}, '00:00', '00:00', 1).thuChu, 'T7, CN');
    expect(k(moiNgay, '00:00', '00:00', 1).gioChu, 'Cả ngày');
    expect(k(moiNgay, '22:00', '02:00', 1).gioChu, '22:00 – 02:00');
    expect(KhungGia.tuDong({'thu': [6, 7], 'tu': '17:00:00', 'den': '23:00:00', 'gia': 90000})!.toJson(),
        {'thu': [6, 7], 'tu': '17:00', 'den': '23:00', 'gia': 90000});
  });
}
