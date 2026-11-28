// Bộ ca ngày lễ (đợt 6) dùng chung với supabase/tests/gia_gio_ngay_le_test.sql: app tính tạm phải ra đúng số
// máy chủ chốt. 30/04/2027 là Thứ Sáu; 03/05/2027 là Thứ Hai. Giá gốc 60.000.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio.dart';

KhungGia k(Set<int> thu, String tu, String den, double gia) {
  int p(String s) => int.parse(s.split(':')[0]) * 60 + int.parse(s.split(':')[1]);
  return KhungGia(thu: thu, tuPhut: p(tu), denPhut: p(den), gia: gia);
}

const le = {kThuNgayLe};
final ngayLe = {20270430, 20270501};

void main() {
  double t(GiaGioCaiDat c, DateTime vao, int phut) =>
      tinhGioTien(vao: vao, phutChoi: phut, giaGoc: 60000, caiDat: c).thanhTien;

  test('L8 khung Lễ nhưng quán chưa có ngày lễ: giá gốc', () {
    final c = GiaGioCaiDat(khung: [k(le, '00:00', '00:00', 100000)]);
    expect(t(c, DateTime(2027, 4, 30, 18), 60), 60000);
  });

  test('L1, L2 khung Lễ đứng dưới vẫn thắng vào ngày lễ', () {
    final c = GiaGioCaiDat(
      khung: [k({1, 2, 3, 4, 5}, '17:00', '23:00', 70000), k(le, '00:00', '00:00', 100000)],
      ngayLe: ngayLe,
    );
    expect(t(c, DateTime(2027, 4, 30, 18), 60), 100000);
    expect(t(c, DateTime(2027, 5, 3, 18), 60), 70000);
    expect(tinhGioKhungLuc(DateTime(2027, 4, 30, 18), c)!.coNgayLe, isTrue);
  });

  test('L3, L4 giờ không có khung Lễ thì như ngày thường', () {
    final c = GiaGioCaiDat(
      khung: [k({1, 2, 3, 4, 5}, '17:00', '23:00', 70000), k(le, '08:00', '12:00', 90000)],
      ngayLe: ngayLe,
    );
    expect(t(c, DateTime(2027, 4, 30, 11, 30), 60), 75000);
    expect(t(c, DateTime(2027, 4, 30, 17, 30), 60), 70000);
  });

  test('L5–L7 khung Lễ qua đêm tính theo ngày bắt đầu', () {
    final c = GiaGioCaiDat(khung: [k(le, '22:00', '02:00', 120000)], ngayLe: ngayLe);
    expect(t(c, DateTime(2027, 4, 30, 23), 120), 240000);
    expect(t(c, DateTime(2027, 4, 29, 23), 60), 60000);
    final chi15 = c.copyWith(ngayLe: {20270501});
    expect(t(chi15, DateTime(2027, 4, 30, 23, 30), 60), 60000);
    expect(t(chi15, DateTime(2027, 5, 1, 23, 30), 60), 120000);
  });

  test('qua tháng: phần qua đêm sau 30/4 → 1/5 lấy đúng hôm trước', () {
    final c = GiaGioCaiDat(khung: [k(le, '22:00', '02:00', 120000)], ngayLe: {20270430});
    expect(tinhGioKhungLuc(DateTime(2027, 5, 1, 1), c), isNotNull);
    expect(tinhGioKhungLuc(DateTime(2027, 5, 1, 3), c), isNull);
  });

  test('L9 hồi quy: bàn không khung, quán có ngày lễ → công thức cũ', () {
    final r = Random(6);
    final c = GiaGioCaiDat(ngayLe: ngayLe);
    for (var i = 0; i < 2000; i++) {
      final phut = 1 + r.nextInt(3000);
      final vao = DateTime(2027, 4, 25).add(Duration(seconds: r.nextInt(86400 * 10)));
      expect(t(c, vao, phut), ((phut * 6000000 + 6000000 - 1) ~/ 6000000) * 1000.0);
    }
  });

  test('chữ ngày của khung', () {
    expect(thuChuCua(le), 'Ngày lễ');
    expect(thuChuCua({6, 7, 8}), 'T7, CN, ngày lễ');
    expect(thuChuCua({1, 2, 3, 4, 5, 6, 7, 8}), 'Mọi ngày, ngày lễ');
    expect(thuChuCua({5, 6, 7, 8}), 'T6–CN, ngày lễ');
  });
}
