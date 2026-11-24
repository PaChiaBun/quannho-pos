import 'package:flutter/material.dart';

import 'nganh_icon.dart';

/// Loại hình của quán dùng module Tính giờ: quyết định tên + biểu tượng của ô module ở Trang chủ.
/// Lưu ở app_settings, khoá [kLoaiHinhSettingKey], giá trị là [LoaiHinh.id].
const kLoaiHinhSettingKey = 'tinh_gio_loai_hinh';

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
  });

  Widget bieuTuong({double size = 24, Color color = Colors.black}) => hinh != null
      ? NganhIcon(hinh!, size: size, color: color)
      : Icon(icon, size: size, color: color);
}

const kLoaiHinh = <LoaiHinh>[
  LoaiHinh(id: 'bi_da', ten: 'Bi da', moTa: 'Bàn bi da tính giờ', danhXung: 'bàn', maKhuVuc: 0xF1A01, hinh: NganhHinh.biDa),
  LoaiHinh(id: 'karaoke', ten: 'Karaoke', moTa: 'Phòng hát tính giờ', danhXung: 'phòng', maKhuVuc: 0xF1A02, icon: Icons.mic_external_on_rounded),
  LoaiHinh(id: 'cau_long', ten: 'Cầu lông', moTa: 'Sân cầu lông tính giờ', danhXung: 'sân', maKhuVuc: 0xF1A03, hinh: NganhHinh.cauLong),
  LoaiHinh(id: 'tennis', ten: 'Tennis', moTa: 'Sân tennis tính giờ', danhXung: 'sân', maKhuVuc: 0xF1A04, icon: Icons.sports_tennis_rounded),
  LoaiHinh(id: 'pickleball', ten: 'Pickleball', moTa: 'Sân pickleball tính giờ', danhXung: 'sân', maKhuVuc: 0xF1A05, hinh: NganhHinh.pickleball),
  LoaiHinh(id: 'bong_ban', ten: 'Bóng bàn', moTa: 'Bàn bóng bàn tính giờ', danhXung: 'bàn', maKhuVuc: 0xF1A06, hinh: NganhHinh.bongBan),
  // luôn để cuối: mặc định khi quán chưa chọn hoặc mã lạ
  LoaiHinh(id: 'khac', ten: 'Tính giờ', moTa: 'Bi da, karaoke, sân', danhXung: 'bàn', maKhuVuc: 0xF1A00, icon: Icons.timer_rounded),
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
