// Bàn tính giờ (bi da, karaoke, sân): phép tính dùng chung ở app.
// Số THẬT do máy chủ chốt (ban_chot_gio_v1, migration 20261123_ban_tinh_gio_v1.sql). Các hàm dưới đây
// phải ra cùng kết quả với máy chủ để tiền tạm tính trên thẻ bàn khớp dòng tiền giờ lúc tính tiền.
import '../../core/repositories/ban_repository.dart' show BanSessionItemModel;

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

/// Tiền giờ: theo phút, làm tròn lên 1.000đ.
double tinhGioThanhTien(int soPhut, double giaMotGio) {
  final gia = giaMotGio < 0 ? 0.0 : giaMotGio;
  return (soPhut * gia / 60 / 1000).ceil() * 1000.0;
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

/// Máy chủ văng hai lỗi này khi thanh toán / đóng bàn tính giờ mà chưa chốt (hoặc chốt quá cũ).
/// App bắt, gọi chốt giờ lại rồi cho thu ngân xem lại tổng.
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
  final int soPhut;
  /// Tiền giờ của đoạn đang chạy (0 khi Quản lý đã huỷ dòng tiền giờ của đoạn này).
  final double tienGio;
  /// Tổng bàn: các món chưa huỷ + [tienGio] (dòng đã chốt của đoạn đang chạy được thay bằng số tạm tính).
  final double tong;
  final bool daHuy;
  const TinhGioTamTinh({required this.soPhut, required this.tienGio, required this.tong, required this.daHuy});
}

/// [mon] = MỌI dòng của phiên (kể cả đã huỷ). [giaMotGio] null (chưa tải được món giá giờ) thì giữ
/// số đã chốt gần nhất nếu có.
TinhGioTamTinh tinhGioTamTinhBan({
  required int gioBatDauMs,
  required double? giaMotGio,
  required Iterable<BanSessionItemModel> mon,
  required DateTime luc,
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
  final soPhut = tinhGioSoPhut(DateTime.fromMillisecondsSinceEpoch(gioBatDauMs), luc);
  final tienGio = daHuy
      ? 0.0
      : giaMotGio == null
          ? (dongDoan?.subtotal ?? 0.0)
          : tinhGioThanhTien(soPhut, giaMotGio);
  return TinhGioTamTinh(soPhut: soPhut, tienGio: tienGio, tong: tongMon + tienGio, daHuy: daHuy);
}

