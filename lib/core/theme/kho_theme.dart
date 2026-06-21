// core/theme/kho_theme.dart
// Shared design tokens cho Kho Hàng & Kho Hàng Chuyên Nghiệp
// Khi update màu sắc → chỉ cần đổi tại đây

import 'package:flutter/material.dart';

class KhoTheme {
  KhoTheme._();

  // ── Palette chung ──────────────────────────────────────────────────────────
  static const Color navy       = Color(0xFF1C2151);
  static const Color navyLight  = Color(0xFF2D3580);
  static const Color violet     = Color(0xFF7C3AED);
  static const Color violetLight= Color(0xFFEDE7FE);
  static const Color bg         = Color(0xFFF8F6FF);
  static const Color card       = Color(0xFFFFFFFF);
  static const Color border     = Color(0xFFE5E0F5);
  static const Color muted      = Color(0xFF9E98B0);
  static const Color ink        = Color(0xFF1A1530);
  static const Color green      = Color(0xFF059669);
  static const Color red        = Color(0xFFDC2626);
  static const Color amber      = Color(0xFFF59E0B);

  // ── Màu riêng cho Kho Pro ──────────────────────────────────────────────────
  static const Color proGold    = Color(0xFFD97706);   // badge PRO
  static const Color proGoldBg  = Color(0xFFFEF3C7);

  // ── Border radius ─────────────────────────────────────────────────────────
  static const double radiusCard    = 16.0;
  static const double radiusCardLg  = 18.0;
  static const double radiusChip    = 20.0;
  static const double radiusInput   = 12.0;
  static const double radiusButton  = 14.0;
  static const double radiusSmall   = 8.0;

  // ── Shadows ───────────────────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  // ── InputDecoration factory ───────────────────────────────────────────────
  static InputDecoration inputDecoration({
    required String hint,
    Widget? prefix,
    Widget? suffix,
    String? suffixText,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: muted, fontSize: 14),
        prefixIcon: prefix,
        suffix: suffix,
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: muted, fontSize: 13),
        filled: true,
        fillColor: bg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusInput),
          borderSide: const BorderSide(color: violet, width: 2),
        ),
      );
}
