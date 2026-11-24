import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart';
import 'package:flutter/material.dart';
import 'package:quannho_pos/modules/tinh_gio/loai_hinh.dart';
import 'package:quannho_pos/modules/tinh_gio/nganh_icon.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio_widgets.dart';
import 'package:quannho_pos/shared/widgets/module_tile.dart';

// Các số dưới đây trùng với supabase/tests/ban_tinh_gio_v1_test.sql (T5, T7, T9, T12):
// app tạm tính phải ra đúng số máy chủ chốt.
void main() {
  final t0 = DateTime.utc(2026, 11, 23, 6, 0, 0);

  group('số phút tính tiền', () {
    test('làm tròn lên theo phút, tối thiểu 1', () {
      expect(tinhGioSoPhut(t0, t0), 1);
      expect(tinhGioSoPhut(t0, t0.add(const Duration(seconds: 1))), 1);
      expect(tinhGioSoPhut(t0, t0.add(const Duration(minutes: 1))), 1);
      expect(tinhGioSoPhut(t0, t0.add(const Duration(minutes: 1, milliseconds: 1))), 2);
      expect(tinhGioSoPhut(t0, t0.add(const Duration(minutes: 89, seconds: 30))), 90);
      expect(tinhGioSoPhut(t0, t0.add(const Duration(minutes: 60, seconds: 30))), 61);
    });
    test('giờ ra trước giờ vào (đồng hồ máy lệch) vẫn ra 1', () {
      expect(tinhGioSoPhut(t0, t0.subtract(const Duration(minutes: 5))), 1);
    });
  });

  group('tiền giờ', () {
    test('khớp các ca của test máy chủ', () {
      expect(tinhGioThanhTien(90, 60000), 90000); // T5
      expect(tinhGioThanhTien(61, 70000), 72000); // T7: 71.166,7 → 72.000
      expect(tinhGioThanhTien(30, 60000), 30000); // T9
      expect(tinhGioThanhTien(30, 70000), 35000); // T12
      expect(tinhGioThanhTien(60, 60000), 60000); // T14
    });
    test('làm tròn lên 1.000đ, giá 0 hoặc âm ra 0', () {
      expect(tinhGioThanhTien(1, 60000), 1000);
      expect(tinhGioThanhTien(1, 55000), 1000); // 916,7 → 1.000
      expect(tinhGioThanhTien(7, 55000), 7000); // 6.416,7 → 7.000
      expect(tinhGioThanhTien(45, 0), 0);
      expect(tinhGioThanhTien(45, -5000), 0);
    });
  });

  test('thời lượng và đồng hồ', () {
    expect(tinhGioThoiLuong(45), '45p');
    expect(tinhGioThoiLuong(60), '1g00');
    expect(tinhGioThoiLuong(61), '1g01');
    expect(tinhGioThoiLuong(90), '1g30');
    expect(tinhGioDongHo(t0, t0.add(const Duration(minutes: 65, seconds: 59))), '1:05');
    expect(tinhGioDongHo(t0, t0.subtract(const Duration(minutes: 3))), '0:00');
  });

  test('nhận ra lỗi máy chủ đòi chốt giờ', () {
    expect(laLoiCanChotGio('PostgrestException(message: CHUA_CHOT_GIO: bàn tính giờ chưa chốt giờ…)'), isTrue);
    expect(laLoiCanChotGio({'message': 'CHOT_GIO_QUA_CU: giờ đã chốt quá 15 phút'}), isTrue);
    expect(laLoiCanChotGio('SESSION_NOT_OPEN'), isFalse);
    expect(laLoiCanChotGio(null), isFalse);
  });

  test('khi nào phải chuyển bàn bằng hàm máy chủ', () {
    expect(canChuyenBangMayChu(phienDangTinhGio: false, banDichTinhGio: false), isFalse);
    expect(canChuyenBangMayChu(phienDangTinhGio: true, banDichTinhGio: false), isTrue);
    expect(canChuyenBangMayChu(phienDangTinhGio: false, banDichTinhGio: true), isTrue);
  });

  test('huỷ bàn tính giờ: quá 5 phút và chưa chốt thì phải chốt trước', () {
    final luc = t0.add(const Duration(minutes: 10));
    expect(huyBanCanChotTruoc(gioBatDau: null, daCoDongGioCuaDoan: false, luc: luc), isFalse);
    expect(huyBanCanChotTruoc(gioBatDau: t0, daCoDongGioCuaDoan: false, luc: luc), isTrue);
    expect(huyBanCanChotTruoc(gioBatDau: t0, daCoDongGioCuaDoan: true, luc: luc), isFalse);
    expect(
      huyBanCanChotTruoc(gioBatDau: t0, daCoDongGioCuaDoan: false, luc: t0.add(const Duration(minutes: 4))),
      isFalse,
    );
  });

  group('tạm tính trên thẻ bàn', () {
    final moc = t0.millisecondsSinceEpoch;
    BanSessionItemModel mon(String id, double gia, {String tt = 'da_gui', int? gioTu}) => BanSessionItemModel(
          id: id, sessionId: 'p', productId: 'x', productName: id, price: gia, quantity: 1,
          addedAt: 0, kitchenStatus: tt, gioTu: gioTu, gioDen: gioTu,
        );
    final luc = t0.add(const Duration(minutes: 89, seconds: 30));

    test('chưa chốt: món + tiền giờ tính tới lúc xem', () {
      final r = tinhGioTamTinhBan(
          gioBatDauMs: moc, giaMotGio: 60000, luc: luc,
          mon: [mon('nuoc', 10000), mon('huy', 99000, tt: 'huy')]);
      expect((r.soPhut, r.tienGio, r.tong, r.daHuy), (90, 90000.0, 100000.0, false));
    });
    test('đã chốt trước đó 30.000: thay bằng số tạm tính, không cộng hai lần', () {
      final r = tinhGioTamTinhBan(
          gioBatDauMs: moc, giaMotGio: 60000, luc: luc,
          mon: [mon('nuoc', 10000), mon('gio', 30000, tt: 'xong', gioTu: moc)]);
      expect((r.tienGio, r.tong), (90000.0, 100000.0));
    });
    test('đoạn ở bàn cũ (mốc khác) là tiền đã khoá, cộng nguyên', () {
      final r = tinhGioTamTinhBan(
          gioBatDauMs: moc, giaMotGio: 70000, luc: t0.add(const Duration(minutes: 30)),
          mon: [mon('gio cu', 90000, tt: 'xong', gioTu: moc - 5400000)]);
      expect((r.tienGio, r.tong), (35000.0, 125000.0));
    });
    test('Quản lý đã huỷ dòng tiền giờ của đoạn này: tiền giờ 0', () {
      final r = tinhGioTamTinhBan(
          gioBatDauMs: moc, giaMotGio: 60000, luc: luc,
          mon: [mon('nuoc', 10000), mon('gio', 90000, tt: 'huy', gioTu: moc)]);
      expect((r.tienGio, r.tong, r.daHuy), (0.0, 10000.0, true));
    });
    test('khách đặt trước về sớm: tạm tính tới hết khung, như máy chủ (59 phút × 25.000 = 25.000)', () {
      final vao = DateTime(2026, 11, 24, 13, 1, 38);
      final r = tinhGioTamTinhBan(
          gioBatDauMs: vao.millisecondsSinceEpoch, giaMotGio: 25000, mon: const [],
          luc: vao.add(const Duration(minutes: 1)), khungDatDen: DateTime(2026, 11, 24, 14));
      expect((r.soPhut, r.tienGio, r.theoKhungDat), (59, 25000.0, true));
    });
    test('khách đặt trước chơi lố: hết khung thì tính theo giờ thực', () {
      final r = tinhGioTamTinhBan(
          gioBatDauMs: moc, giaMotGio: 60000, mon: const [], luc: luc,
          khungDatDen: t0.add(const Duration(minutes: 60)));
      expect((r.soPhut, r.tienGio, r.theoKhungDat), (90, 90000.0, false));
    });
    test('chưa tải được giá: giữ số đã chốt gần nhất', () {
      final r = tinhGioTamTinhBan(
          gioBatDauMs: moc, giaMotGio: null, luc: luc,
          mon: [mon('gio', 30000, tt: 'xong', gioTu: moc)]);
      expect((r.tienGio, r.tong), (30000.0, 30000.0));
    });
  });

  group('đọc ba cột mới', () {
    test('bàn, phiên, món có tính giờ', () {
      final ban = BanTableModel.fromMap({
        'id': 'b1', 'zone_id': 'z', 'store_id': 's', 'name': 'Bi da 1',
        'gia_gio_product_id': 'p-gio',
      });
      expect(ban.tinhGio, isTrue);
      expect(ban.giaGioProductId, 'p-gio');

      final phien = BanSessionModel.fromMap({
        'id': 'p1', 'table_id': 'b1', 'store_id': 's',
        'opened_at': '2026-11-23T06:00:00+00:00',
        'gio_bat_dau': '2026-11-23T06:00:21.039024+00:00',
      });
      expect(phien.gioBatDau, DateTime.utc(2026, 11, 23, 6, 0, 21, 39).millisecondsSinceEpoch);

      final dong = BanSessionItemModel.fromMap({
        'id': 'i1', 'session_id': 'p1', 'product_id': 'p-gio',
        'product_name': 'Giờ bàn lỗ · Bi da 1 · 13:00–14:30 (1g30)',
        'unit_price': 90000, 'quantity': 1, 'kitchen_status': 'xong',
        'added_at': '2026-11-23T07:30:00+00:00',
        'gio_tu': '2026-11-23T06:00:21+00:00', 'gio_den': '2026-11-23T07:30:00+00:00',
      });
      expect(dong.laTienGio, isTrue);
      expect(dong.subtotal, 90000);
      expect(dong.copyWith(note: 'x').laTienGio, isTrue, reason: 'copyWith không làm mất dấu dòng tiền giờ');
    });

    test('dữ liệu cũ không có cột mới vẫn đọc được', () {
      expect(BanTableModel.fromMap({'id': 'b', 'name': 'Bàn 1'}).tinhGio, isFalse);
      expect(BanSessionModel.fromMap({'id': 'p', 'opened_at': 0}).gioBatDau, isNull);
      expect(BanSessionItemModel.fromMap({'id': 'i', 'added_at': 0}).laTienGio, isFalse);
    });
  });

  group('loại hình', () {
    test('mã không trùng nhau, mã khu vực nằm ngoài vùng MaterialIcons', () {
      expect(kLoaiHinh.map((l) => l.id).toSet().length, kLoaiHinh.length);
      expect(kLoaiHinh.map((l) => l.maKhuVuc).toSet().length, kLoaiHinh.length);
      for (final l in kLoaiHinh) {
        expect(l.maKhuVuc > 0xF8FF, isTrue, reason: '${l.id} trùng vùng mã MaterialIcons');
        expect(l.icon != null && l.hinh != null, isFalse, reason: '${l.id} không được có hai nguồn hình');
        expect(l.nhieuLoai, l.id == 'khac', reason: 'chỉ mục mặc định dùng cụm bốn hình');
        expect(loaiHinhTheoMaKhuVuc(l.maKhuVuc), same(l));
      }
    });
    test('mã lạ hoặc chưa chọn → mục chung "Nhiều loại"', () {
      expect(loaiHinhTheoId(null).id, 'khac');
      expect(loaiHinhTheoId('golf').id, 'khac');
      expect(loaiHinhTheoId('bi_da').ten, 'Bi da');
      expect(loaiHinhTheoMaKhuVuc(0xe318), isNull, reason: 'mã MaterialIcons cũ không phải hình ngành');
    });
    test('ô module theo loại hình: đổi tên + hình, giữ màu và đường dẫn', () {
      final goc = kModuleConfigs[kTinhGioModuleId]!;
      final biDa = tinhGioTileData(goc, loaiHinhTheoId('bi_da'));
      expect((biDa.id, biDa.title, biDa.route, biDa.baseColor), (goc.id, 'Bi da', goc.route, goc.baseColor));
      expect(biDa.bieuTuong(size: 24, color: Colors.white), isA<NganhIcon>());
      final karaoke = tinhGioTileData(goc, loaiHinhTheoId('karaoke'));
      expect(karaoke.bieuTuong(size: 24, color: Colors.white), isA<Icon>());
      expect(goc.title, kTenModuleTinhGio);
      expect(goc.bieuTuong(size: 24, color: Colors.white), isA<NganhCumIcon>(), reason: 'ô mặc định là cụm bốn hình');
      final nhieu = tinhGioTileData(goc, loaiHinhTheoId('khac'));
      expect(identical(nhieu, goc), isTrue, reason: 'quán nhiều loại hình giữ nguyên ô gốc');
      expect(loaiHinhTheoId(null).nhan, 'Nhiều loại');
      expect(kModuleConfigs['pos']!.bieuTuong(size: 24, color: Colors.white), isA<Icon>(), reason: 'ô khác vẫn vẽ bằng Icon');
    });
  });
}
