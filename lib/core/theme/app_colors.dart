import 'package:flutter/material.dart';

/// Bảng màu Quán Nhỏ POS — Phiên bản 2.0
/// Tương phản cao, sắc nét, hiện đại hơn
class AppColors {
  AppColors._();

  // === NỀN (Background) ===
  /// Nền chính — trắng ấm
  static const Color paperCream = Color(0xFFFAF7F2);

  /// Nền card — trắng
  static const Color paperAged = Color(0xFFFFFFFF);

  /// Nền section — xám nhạt
  static const Color paperDark = Color(0xFFF2EDE4);

  /// Border — xám trung
  static const Color paperBorder = Color(0xFFE0D8CC);

  // === CHỮ (Text) — TƯƠNG PHẢN CAO ===
  /// Chữ chính — đen đậm
  static const Color inkBrown = Color(0xFF1A1207);

  /// Chữ phụ — xám đậm (đọc được rõ)
  static const Color inkLight = Color(0xFF5C5248);

  /// Chữ ghi chú — xám trung
  static const Color inkFaded = Color(0xFF9E9085);

  // === THƯƠNG HIỆU LPM (Brand) ===
  /// Navy đậm — màu chủ đạo
  static const Color lpmNavy = Color(0xFF1E1C5E);

  /// Navy sáng hơn
  static const Color lpmNavyLight = Color(0xFF2D2B8A);

  /// Orange đậm — accent nổi bật
  static const Color lpmOrange = Color(0xFFE85D20);

  /// Orange sáng
  static const Color lpmOrangeLight = Color(0xFFFF7A3D);

  /// Gradient chính
  static const LinearGradient lpmGradient = LinearGradient(
    colors: [lpmOrange, lpmOrangeLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Gradient header navy
  static const LinearGradient navyGradient = LinearGradient(
    colors: [Color(0xFF1E1C5E), Color(0xFF2D2B8A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // === TRẠNG THÁI (Status) — ĐẬM SẮC ===
  /// Thành công — xanh lá đậm
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);

  /// Cảnh báo — cam đậm
  static const Color warning = Color(0xFFE65100);
  static const Color warningLight = Color(0xFFFFF3E0);

  /// Lỗi — đỏ đậm
  static const Color error = Color(0xFFC62828);
  static const Color errorLight = Color(0xFFFFEBEE);

  /// Thông tin — xanh đậm
  static const Color info = Color(0xFF1565C0);
  static const Color infoLight = Color(0xFFE3F2FD);

  // === QUICK ACTION COLORS — MÀU ĐẬM SẮC ===
  static const Color actionSell    = Color(0xFFE85D20); // cam đậm
  static const Color actionStock   = Color(0xFF1E1C5E); // navy
  static const Color actionIncome  = Color(0xFF2E7D32); // xanh
  static const Color actionExpense = Color(0xFFC62828); // đỏ
  static const Color actionReport  = Color(0xFF1565C0); // xanh dương

  // === MATERIAL SWATCH ===
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF1E1C5E,
    <int, Color>{
      50:  Color(0xFFE8E8F5),
      100: Color(0xFFC5C4E5),
      200: Color(0xFF9E9CD3),
      300: Color(0xFF7774C1),
      400: Color(0xFF5A57B4),
      500: Color(0xFF1E1C5E),
      600: Color(0xFF1A1956),
      700: Color(0xFF16154C),
      800: Color(0xFF121142),
      900: Color(0xFF0A0A31),
    },
  );
}
