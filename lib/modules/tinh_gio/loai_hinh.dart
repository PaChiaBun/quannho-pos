import 'package:flutter/material.dart';

import 'nganh_icon.dart';

/// Loại hình của quán dùng module Tính giờ: quyết định tên + biểu tượng của ô module ở Trang chủ.
/// Lưu ở app_settings, khoá [kLoaiHinhSettingKey], giá trị là [LoaiHinh.id].
const kLoaiHinhSettingKey = 'tinh_gio_loai_hinh';

/// Tên module ở Trang chủ, trong danh sách thêm module và trong bài hướng dẫn.
const kTenModuleTinhGio = 'Các hoạt động tính giờ';

class LoaiHinh {
  final String id;

  /// Tên ô module ở Trang chủ.
  final String ten;

  /// Dòng phụ dưới tên ô.
  final String moTa;

  /// Cách gọi một chỗ tính giờ: "bàn", "phòng", "sân".
  final String danhXung;

  /// Biểu tượng Material nếu có sẵn; không thì dùng [hinh] tự vẽ.
  final IconData? icon;
  final NganhHinh? hinh;

  /// Nhãn trong hộp chọn loại hình khi khác tên ô (mục "Nhiều loại").
  final String? nhanChon;

  /// Mã lưu trong ban_zones.icon_code khi dùng làm biểu tượng khu vực. Nằm ngoài vùng mã của
  /// MaterialIcons (0xE000–0xF8FF) nên không trùng biểu tượng nào đang có.
  final int maKhuVuc;

  const LoaiHinh({
    required this.id,
    required this.ten,
    required this.moTa,
    required this.danhXung,
    required this.maKhuVuc,
    this.icon,
    this.hinh,
    this.nhanChon,
  });

  /// Quán có nhiều loại hình (hoặc chưa chọn): ô mang tên chung và cụm bốn hình.
  bool get nhieuLoai => icon == null && hinh == null;

  String get nhan => nhanChon ?? ten;

  Widget bieuTuong({double size = 24, Color color = Colors.black}) => hinh != null
      ? NganhIcon(hinh!, size: size, color: color)
      : icon != null
          ? Icon(icon, size: size, color: color)
          : NganhCumIcon(size: size / 1.5, color: color);
}

const kLoaiHinh = <LoaiHinh>[
  LoaiHinh(id: 'bi_da', ten: 'Bi da', moTa: 'Bàn bi da tính giờ', danhXung: 'bàn', maKhuVuc: 0xF1A01, hinh: NganhHinh.biDa),
  LoaiHinh(id: 'karaoke', ten: 'Karaoke', moTa: 'Phòng hát tính giờ', danhXung: 'phòng', maKhuVuc: 0xF1A02, icon: Icons.mic_external_on_rounded),
  LoaiHinh(id: 'cau_long', ten: 'Cầu lông', moTa: 'Sân cầu lông tính giờ', danhXung: 'sân', maKhuVuc: 0xF1A03, hinh: NganhHinh.cauLong),
  LoaiHinh(id: 'tennis', ten: 'Tennis', moTa: 'Sân tennis tính giờ', danhXung: 'sân', maKhuVuc: 0xF1A04, icon: Icons.sports_tennis_rounded),
  LoaiHinh(id: 'pickleball', ten: 'Pickleball', moTa: 'Sân pickleball tính giờ', danhXung: 'sân', maKhuVuc: 0xF1A05, hinh: NganhHinh.pickleball),
  LoaiHinh(id: 'bong_ban', ten: 'Bóng bàn', moTa: 'Bàn bóng bàn tính giờ', danhXung: 'bàn', maKhuVuc: 0xF1A06, hinh: NganhHinh.bongBan),
  LoaiHinh(id: 'bong_da', ten: 'Sân bóng', moTa: 'Sân bóng đá tính giờ', danhXung: 'sân', maKhuVuc: 0xF1A07, icon: Icons.sports_soccer_rounded),
  // luôn để cuối: mặc định khi quán chưa chọn hoặc mã lạ. Không có hình riêng → vẽ cụm bốn hình.
  LoaiHinh(
    id: 'khac',
    ten: kTenModuleTinhGio,
    moTa: 'Bi da, cầu lông, sân bóng, karaoke',
    danhXung: 'bàn',
    maKhuVuc: 0xF1A00,
    nhanChon: 'Nhiều loại',
  ),
];

LoaiHinh loaiHinhTheoId(String? id) =>
    kLoaiHinh.firstWhere((l) => l.id == id, orElse: () => kLoaiHinh.last);

/// Loại hình ứng với mã biểu tượng khu vực, null nếu là mã MaterialIcons cũ.
LoaiHinh? loaiHinhTheoMaKhuVuc(int code) {
  for (final l in kLoaiHinh) {
    if (l.maKhuVuc == code) return l;
  }
  return null;
}
