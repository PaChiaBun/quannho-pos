// Bàn tính giờ (bi da, karaoke, sân): phép tính dùng chung ở app.
// Số THẬT do máy chủ chốt (ban_chot_gio_v1, migration 20261123_ban_tinh_gio_v1.sql). Các hàm dưới đây
// phải ra cùng kết quả với máy chủ để tiền tạm tính trên thẻ bàn khớp dòng tiền giờ lúc tính tiền.
import '../../core/repositories/ban_repository.dart' show BanSessionItemModel, BanTableModel, BanZoneModel;
import 'gia_gio.dart';
import 'loai_hinh.dart' show loaiHinhTheoMaKhuVuc;

export 'gia_gio.dart';

/// Mã module ở Trang chủ.
const kTinhGioModuleId = 'tinh_gio';

/// Máy chủ từ chối đóng bàn khi giờ đã chốt cũ hơn mốc này.
const kTinhGioChotHetHan = Duration(minutes: 15);

/// Bàn tính giờ mở quá mốc này thì phải chốt giờ trước khi huỷ bàn.
const kTinhGioHuyKhongCanChot = Duration(minutes: 5);

/// Số phút tính tiền: làm tròn lên, tối thiểu 1.
int tinhGioSoPhut(DateTime tu, DateTime den) {
  final giay = den.difference(tu).inMicroseconds / Duration.microsecondsPerSecond;
  final phut = (giay / 60).ceil();
  return phut < 1 ? 1 : phut;
}

/// Tiền giờ một giá: theo phút, làm tròn lên 1.000đ (tính bằng số nguyên như máy chủ, không lệch số thực).
double tinhGioThanhTien(int soPhut, double giaMotGio) {
  final gia = giaMotGio < 0 ? 0.0 : giaMotGio;
  return tienTuTongXu(soPhut * (gia * 100).round());
}

/// "1g30", "45p" — giống tên dòng tiền giờ máy chủ ghi.
String tinhGioThoiLuong(int soPhut) => soPhut >= 60
    ? '${soPhut ~/ 60}g${(soPhut % 60).toString().padLeft(2, '0')}'
    : '${soPhut}p';

/// Đồng hồ trên thẻ bàn: "1:05" (giờ:phút) — không hiện giây để thẻ không nhảy liên tục.
String tinhGioDongHo(DateTime tu, DateTime luc) {
  final d = luc.difference(tu);
  final phut = d.isNegative ? 0 : d.inMinutes;
  return '${phut ~/ 60}:${(phut % 60).toString().padLeft(2, '0')}';
}

/// "1 giờ 30 phút", "45 phút", "2 giờ" — chữ đầy đủ cho khối Giờ chơi, không viết tắt "1g30".
String tinhGioThoiLuongDai(int soPhut) {
  final g = soPhut ~/ 60, p = soPhut % 60;
  if (g == 0) return '$p phút';
  return p == 0 ? '$g giờ' : '$g giờ $p phút';
}

/// Giờ vào: "13:07"; khác ngày với [luc] thì kèm ngày "26/11 13:07" (bàn quên đóng qua đêm).
String tinhGioGioVao(DateTime vao, DateTime luc) {
  String h2(int n) => n.toString().padLeft(2, '0');
  final gio = '${h2(vao.hour)}:${h2(vao.minute)}';
  final cungNgay = vao.year == luc.year && vao.month == luc.month && vao.day == luc.day;
  return cungNgay ? gio : '${h2(vao.day)}/${h2(vao.month)} $gio';
}

/// Bàn chạy quá mốc này thì thẻ và khối Giờ chơi báo đỏ (26/11 Demo A 1 bị quên 24 giờ, 1,46 triệu).
const kTinhGioCanhBaoLau = Duration(hours: 6);

/// Máy chủ văng hai lỗi này khi thanh toán / đóng bàn tính giờ mà chưa chốt (hoặc chốt quá cũ).
/// App bắt, gọi chốt giờ lại rồi cho thu ngân xem lại tổng.
/// Khu dành cho bàn tính giờ: mang biểu tượng ngành (bi da, sân, phòng hát…).
bool laKhuTinhGio(BanZoneModel k) => loaiHinhTheoMaKhuVuc(k.iconCode) != null;

/// Các bàn hiện ở màn "Các hoạt động tính giờ": bàn đã có giá giờ, cộng mọi bàn của khu ngành
/// (kể cả bàn mới chưa đặt giá, để Chủ quán thấy mà đặt).
List<BanTableModel> locBanTinhGio(List<BanTableModel> ban, List<BanZoneModel> khu) {
  final khuNganh = {for (final k in khu) if (laKhuTinhGio(k)) k.id};
  return ban.where((b) => b.tinhGio || khuNganh.contains(b.zoneId)).toList();
}

/// Các khu hiện ở màn đó: khu ngành và khu đang có bàn tính giờ.
List<BanZoneModel> locKhuTinhGio(List<BanZoneModel> khu, List<BanTableModel> ban) {
  final coBan = {for (final b in ban) if (b.tinhGio) b.zoneId};
  return khu.where((k) => laKhuTinhGio(k) || coBan.contains(k.id)).toList();
}

/// Danh mục của các món giá giờ app tự tạo khi Chủ quán gõ giá một giờ.
const kDanhMucTienGio = 'Tiền giờ';

/// Món dùng làm giá giờ: tên hoặc danh mục có chữ "giờ". Hộp đặt giá giờ chỉ liệt kê các món này,
/// không liệt kê cả thực đơn (24/11: quán Demo hiện "Bún bò 55.000 đ / giờ").
bool laMonGiaGio(String ten, String? danhMuc) =>
    ten.toLowerCase().contains('giờ') || (danhMuc ?? '').toLowerCase().contains('giờ');

bool laLoiCanChotGio(Object? loi) {
  final s = '$loi';
  return s.contains('CHUA_CHOT_GIO') || s.contains('CHOT_GIO_QUA_CU');
}

/// Phiên nguồn đang tính giờ hoặc bàn đích là bàn tính giờ → phải chuyển / gộp bằng hàm máy chủ
/// (app tự đổi bàn sẽ bị máy chủ chặn: TINH_GIO_CHUYEN_BAN).
bool canChuyenBangMayChu({required bool phienDangTinhGio, required bool banDichTinhGio}) =>
    phienDangTinhGio || banDichTinhGio;

/// Huỷ bàn tính giờ: mở quá 5 phút và chưa có dòng tiền giờ của đoạn đang chạy thì phải chốt trước.
bool huyBanCanChotTruoc({
  required DateTime? gioBatDau,
  required bool daCoDongGioCuaDoan,
  required DateTime luc,
}) =>
    gioBatDau != null &&
    !daCoDongGioCuaDoan &&
    luc.difference(gioBatDau) > kTinhGioHuyKhongCanChot;

/// Số tạm tính của một bàn đang chạy giờ, tính tới [luc] theo đồng hồ của máy đang xem.
class TinhGioTamTinh {
  /// Số phút chơi (đã kéo tới hết khung đặt nếu có), làm tròn lên.
  final int soPhut;
  /// Số phút tính tiền sau làm tròn block / tối thiểu (bằng [soPhut] khi bàn không cài làm tròn).
  final int soPhutTinh;
  /// Tiền giờ của đoạn đang chạy (0 khi Quản lý đã huỷ dòng tiền giờ của đoạn này).
  final double tienGio;
  /// Tổng bàn: các món chưa huỷ + [tienGio] (dòng đã chốt của đoạn đang chạy được thay bằng số tạm tính).
  final double tong;
  final bool daHuy;
  /// Đang tính tới hết khung đã đặt trước (khách về sớm vẫn trả đủ khung), không phải tới lúc xem.
  final bool theoKhungDat;
  const TinhGioTamTinh({
    required this.soPhut,
    int? soPhutTinh,
    required this.tienGio,
    required this.tong,
    required this.daHuy,
    this.theoKhungDat = false,
  }) : soPhutTinh = soPhutTinh ?? soPhut;
}

/// [mon] = MỌI dòng của phiên (kể cả đã huỷ). [giaMotGio] null (chưa tải được món giá giờ) thì giữ
/// số đã chốt gần nhất nếu có. [khungDatDen] = giờ hết khung của lượt đặt trước mà phiên đã nhận (còn ở
/// đúng bàn đã đặt): chưa hết khung thì tính tới hết khung, như máy chủ làm lúc chốt. [caiDat] = khung giá +
/// làm tròn của bàn (đợt 1); mặc định tính theo phút một giá như cũ.
TinhGioTamTinh tinhGioTamTinhBan({
  required int gioBatDauMs,
  required double? giaMotGio,
  required Iterable<BanSessionItemModel> mon,
  required DateTime luc,
  DateTime? khungDatDen,
  GiaGioCaiDat caiDat = GiaGioCaiDat.macDinh,
  int? goiPhut,
  double? goiGia,
}) {
  BanSessionItemModel? dongDoan;
  var tongMon = 0.0;
  for (final i in mon) {
    if (i.gioTu == gioBatDauMs && dongDoan == null) {
      dongDoan = i;
    } else if (i.kitchenStatus != 'huy') {
      tongMon += i.subtotal;
    }
  }
  final daHuy = dongDoan?.kitchenStatus == 'huy';
  final theoKhung = khungDatDen != null && khungDatDen.isAfter(luc);
  final vao = DateTime.fromMillisecondsSinceEpoch(gioBatDauMs);
  final soPhut = tinhGioSoPhut(vao, theoKhung ? khungDatDen : luc);
  final tien = giaMotGio == null ? null : tinhGioTien(
          vao: vao, phutChoi: soPhut, giaGoc: giaMotGio, caiDat: caiDat, goiPhut: goiPhut, goiGia: goiGia);
  final tienGio = daHuy
      ? 0.0
      : tien == null
          ? (dongDoan?.subtotal ?? 0.0)
          : tien.thanhTien;
  return TinhGioTamTinh(
    soPhut: soPhut,
    soPhutTinh: tien?.soPhutTinh,
    tienGio: tienGio,
    tong: tongMon + tienGio,
    daHuy: daHuy,
    theoKhungDat: theoKhung && !daHuy,
  );
}

