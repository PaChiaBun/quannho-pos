// Bộ ca gói giờ (đợt 7) dùng chung với supabase/tests/goi_gio_test.sql: app tính tạm phải ra đúng số máy chủ chốt.
// 30/11/2026 là Thứ Hai. Giá gốc 60.000; gói 120 phút = 100.000.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart' show BanSessionModel;
import 'package:quannho_pos/modules/tinh_gio/goi_gio_ui.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio.dart';

void main() {
  final vao = DateTime(2026, 11, 30, 14);
  double t(int phut, {int? goi = 120, double? gia = 100000, GiaGioCaiDat c = GiaGioCaiDat.macDinh, DateTime? luc}) =>
      tinhGioTien(vao: luc ?? vao, phutChoi: phut, giaGoc: 60000, caiDat: c, goiPhut: goi, goiGia: gia).thanhTien;

  test('G1–G3 về sớm đủ gói, lố tính thêm', () {
    final g1 = tinhGioTien(vao: vao, phutChoi: 90, giaGoc: 60000, goiPhut: 120, goiGia: 100000);
    expect([g1.thanhTien, g1.soPhutTinh, g1.doan.length], [100000, 120, 0]);
    expect(t(120), 100000);
    final g3 = tinhGioTien(vao: vao, phutChoi: 137, giaGoc: 60000, goiPhut: 120, goiGia: 100000);
    expect(g3.thanhTien, 117000);
    expect([g3.doan.single.phut, g3.doan.single.tu], [17, DateTime(2026, 11, 30, 16)]);
  });

  test('G4, G5 gói + làm tròn block', () {
    expect(t(137, c: const GiaGioCaiDat(block: 30)), 130000);
    expect(t(123, c: const GiaGioCaiDat(block: 30, anHan: 5)), 100000);
  });

  test('G6 gói + khung giá: phần lố theo khung', () {
    const c = GiaGioCaiDat(khung: [KhungGia(thu: {1, 2, 3, 4, 5, 6, 7}, tuPhut: 17 * 60, denPhut: 23 * 60, gia: 80000)]);
    expect(t(150, c: c, luc: DateTime(2026, 11, 30, 16)), 140000);
  });

  test('G7, G8 phần gói còn lại sau chuyển bàn (giá 0)', () {
    expect(t(30, goi: 50, gia: 0), 0);
    expect(t(70, goi: 50, gia: 0), 20000);
  });

  test('G9 tối thiểu dài hơn gói thì tối thiểu thắng', () {
    expect(t(90, c: const GiaGioCaiDat(toiThieu: 180)), 160000);
    expect(t(200, goi: 80, gia: 0, c: const GiaGioCaiDat(toiThieu: 180)), 120000); // G13b
    // G9b: phần gói còn lại (giá 0) thay tối thiểu: còn 50 phút, tối thiểu 180, chơi 30 → 0 đ (trước 28/11: 130.000)
    expect(t(30, goi: 50, gia: 0, c: const GiaGioCaiDat(toiThieu: 180)), 0);
    expect(t(70, goi: 50, gia: 0, c: const GiaGioCaiDat(toiThieu: 180)), 20000);
  });

  test('G10 hồi quy: không gói = như trước đợt 7', () {
    final r = Random(7);
    const c = GiaGioCaiDat(block: 15, anHan: 3, khung: [KhungGia(thu: {6, 7}, tuPhut: 0, denPhut: 0, gia: 90000)]);
    for (var i = 0; i < 2000; i++) {
      final phut = 1 + r.nextInt(3000);
      final v = DateTime(2026, 11, 1).add(Duration(seconds: r.nextInt(86400 * 60)));
      final khongGoi = tinhGioTien(vao: v, phutChoi: phut, giaGoc: 60000, caiDat: c);
      for (final (g, gia) in [(null, null), (0, 0.0), (0, 50000.0)]) {
        final k = tinhGioTien(vao: v, phutChoi: phut, giaGoc: 60000, caiDat: c, goiPhut: g, goiGia: gia);
        expect([k.thanhTien, k.soPhutTinh, k.doan.length], [khongGoi.thanhTien, khongGoi.soPhutTinh, khongGoi.doan.length]);
      }
    }
  });

  test('nhắc gói: 10 phút cuối nhắc sắp hết, hết gói nhắc hết, không nhắc lại', () {
    BanSessionModel phien(int? goi) => BanSessionModel(
        id: 's1', tableId: 't1', storeId: 'st', status: 'open', openedAt: 0, totalAmount: 0, guestCount: 1,
        gioBatDau: vao.millisecondsSinceEpoch, goiPhut: goi, goiGia: 50000);
    final daHien = <String>{};
    expect(goiCanNhac([phien(60)], vao.add(const Duration(minutes: 49)), daHien), isNull);
    final sap = goiCanNhac([phien(60)], vao.add(const Duration(minutes: 51)), daHien)!;
    expect([sap.daHet, sap.het], [false, vao.add(const Duration(hours: 1))]);
    daHien.add('${sap.khoa}|sap');
    expect(goiCanNhac([phien(60)], vao.add(const Duration(minutes: 55)), daHien), isNull, reason: 'đã nhắc sắp hết');
    final het = goiCanNhac([phien(60)], vao.add(const Duration(minutes: 61)), daHien)!;
    expect(het.daHet, isTrue);
    daHien.add('${het.khoa}|het');
    expect(goiCanNhac([phien(60)], vao.add(const Duration(minutes: 70)), daHien), isNull, reason: 'đã nhắc hết');
    expect(goiCanNhac([phien(60)], vao.add(const Duration(minutes: 95)), <String>{}), isNull, reason: 'quá 30 phút sau hết gói');
    expect(goiCanNhac([phien(null)], vao.add(const Duration(minutes: 55)), <String>{}), isNull, reason: 'không gói');
  });

  test('chữ còn / lố gói', () {
    expect(goiNganChu(120, vao, vao.add(const Duration(minutes: 95))), "gói còn 25'");
    expect(goiNganChu(120, vao, vao.add(const Duration(minutes: 128))), "hết gói, lố 8'");
    expect(goiNganChu(null, vao, vao), isNull);
    expect(goiCuaPhienChu(120, 100000), 'Gói 2 giờ 100.000 đ');
    expect(goiCuaPhienChu(80, 0), 'Phần còn của gói 1 giờ 20 phút');
  });
}
