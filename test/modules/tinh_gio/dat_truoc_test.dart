import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc.dart';

void main() {
  final t = DateTime(2026, 11, 24, 18, 0); // giờ đặt 18:00
  DatTruoc dat(
    String id, {
    String ban = 'b1',
    DateTime? tu,
    int phut = 60,
    String tt = 'da_dat',
    DateTime? nhac,
    DateTime? tao,
  }) =>
      DatTruoc(
        id: id,
        tableId: ban,
        tenKhach: 'Khách $id',
        gioTu: tu ?? t,
        gioDen: (tu ?? t).add(Duration(minutes: phut)),
        trangThai: tt,
        nhacLuc: nhac,
        createdAt: tao ?? t.subtract(const Duration(days: 1)),
      );

  group('nhắc trước 30 phút', () {
    test('chỉ nhắc trong 30 phút trước giờ đặt', () {
      final ds = [dat('a')];
      expect(datTruocCanNhac(ds, t.subtract(const Duration(minutes: 31))), isEmpty, reason: 'còn 31 phút: chưa nhắc');
      expect(datTruocCanNhac(ds, t.subtract(const Duration(minutes: 30))).single.id, 'a', reason: 'đúng 30 phút: nhắc');
      expect(datTruocCanNhac(ds, t.subtract(const Duration(minutes: 1))).single.id, 'a');
      expect(datTruocCanNhac(ds, t), isEmpty, reason: 'tới giờ rồi: thôi nhắc');
    });
    test('không nhắc lượt đã nhắc, đã huỷ, khách không đến, khách đã đến', () {
      final luc = t.subtract(const Duration(minutes: 10));
      expect(datTruocCanNhac([dat('a', nhac: luc)], luc), isEmpty);
      for (final tt in ['huy', 'khong_den', 'da_nhan']) {
        expect(datTruocCanNhac([dat('a', tt: tt)], luc), isEmpty, reason: tt);
      }
    });
    test('lượt vừa đặt khi còn dưới 30 phút thì không nhắc', () {
      final luc = t.subtract(const Duration(minutes: 10));
      expect(datTruocCanNhac([dat('a', tao: t.subtract(const Duration(minutes: 20)))], luc), isEmpty);
      expect(datTruocCanNhac([dat('a', tao: t.subtract(const Duration(minutes: 45)))], luc).single.id, 'a');
    });
    test('nhiều lượt: lượt sớm hơn lên trước', () {
      final luc = t.subtract(const Duration(minutes: 5));
      final ra = datTruocCanNhac([dat('muon', tu: t.add(const Duration(minutes: 20))), dat('som')], luc);
      expect(ra.map((d) => d.id), ['som', 'muon']);
    });
  });

  group('lượt kế tiếp của bàn', () {
    test('lấy lượt đang chờ khách sớm nhất mà khung giờ chưa hết', () {
      final ds = [
        dat('toi', tu: t.add(const Duration(hours: 2))),
        dat('gan'),
        dat('ban khac', ban: 'b2', tu: t.subtract(const Duration(hours: 1))),
        dat('da huy', tu: t.subtract(const Duration(minutes: 30)), tt: 'huy'),
        dat('het khung', tu: t.subtract(const Duration(hours: 3))),
      ];
      expect(luotDatKeTiep(ds, 'b1', t.subtract(const Duration(hours: 1)))!.id, 'gan');
      expect(luotDatKeTiep(ds, 'b1', t.add(const Duration(minutes: 30)))!.id, 'gan', reason: 'đang trong khung vẫn tính');
      expect(luotDatKeTiep(ds, 'b1', t.add(const Duration(minutes: 61)))!.id, 'toi');
      expect(luotDatKeTiep(ds, 'b3', t), isNull);
    });
  });

  group('báo trùng giờ ở app', () {
    final ds = [dat('a'), dat('huy', tu: t.add(const Duration(hours: 2)), tt: 'huy')];
    test('chồng một phần là trùng; sát giờ thì không', () {
      expect(luotDatTrung(ds, 'b1', t.add(const Duration(minutes: 30)), t.add(const Duration(minutes: 90)))!.id, 'a');
      expect(luotDatTrung(ds, 'b1', t.add(const Duration(hours: 1)), t.add(const Duration(hours: 2))), isNull);
      expect(luotDatTrung(ds, 'b1', t.subtract(const Duration(hours: 1)), t), isNull);
    });
    test('bàn khác, lượt đã huỷ, và chính lượt đang sửa thì bỏ qua', () {
      expect(luotDatTrung(ds, 'b2', t, t.add(const Duration(hours: 1))), isNull);
      expect(luotDatTrung(ds, 'b1', t.add(const Duration(hours: 2)), t.add(const Duration(hours: 3))), isNull);
      expect(luotDatTrung(ds, 'b1', t, t.add(const Duration(hours: 1)), boQuaId: 'a'), isNull);
    });
  });

  test('đọc dòng từ máy chủ, đổi sang giờ của máy', () {
    final d = DatTruoc.fromMap({
      'id': 'x', 'table_id': 'b1', 'ten_khach': 'Anh Nam', 'sdt': '0901234567',
      'gio_tu': '2026-11-25T11:00:00+00:00', 'gio_den': '2026-11-25T12:00:00+00:00',
      'tien_coc': 50000, 'trang_thai': 'da_dat', 'nhac_luc': null,
      'nguoi_tao_ten': 'Phuc vu B', 'created_at': '2026-11-24T05:00:00+00:00',
    });
    expect(d.gioTu.isUtc, isFalse);
    expect(d.gioTu.toUtc(), DateTime.utc(2026, 11, 25, 11));
    expect(d.gioDen.difference(d.gioTu), const Duration(hours: 1));
    expect((d.choKhach, d.conHieuLuc, d.tienCoc, d.nhacLuc), (true, true, 50000.0, null));
    expect(gioPhut(DateTime(2026, 1, 1, 7, 5)), '07:05');
  });
}
