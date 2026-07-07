/// responsive.dart
/// Tiện ích nhận biết kích thước màn hình cho toàn app Quán Nhỏ POS.
///
/// Breakpoint:
///   📱 Mobile   < 600px   → Điện thoại nhân viên
///   📟 Tablet   600–1024px → Tablet bếp treo tường
///   🖥️ Desktop  > 1024px  → Máy tính tiền POS cảm ứng, laptop
///
/// Cách dùng:
///   if (Responsive.isDesktop(context)) { ... }
///   return ResponsiveLayout(mobile: ..., desktop: ...);

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BREAKPOINT CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const double kBreakpointTablet  = 600.0;
const double kBreakpointDesktop = 1024.0;

/// Kích thước nút tối thiểu — đảm bảo ngón tay chạm được trên desktop cảm ứng
const double kMinTouchTarget = 52.0;

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE HELPER
// ─────────────────────────────────────────────────────────────────────────────
class Responsive {
  Responsive._();

  /// Dưới 600px — điện thoại nhân viên
  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < kBreakpointTablet;

  /// Trên 600px — Điện thoại xoay ngang, Tablet, PC/Desktop (theo thống nhất hiển thị Tablet trên máy tính)
  static bool isTablet(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    return w >= kBreakpointTablet;
  }

  /// Trả về false để luôn dùng giao diện Tablet trên máy tính/PC
  static bool isDesktop(BuildContext context) => false;

  /// Màn hình lớn (Tablet hoặc Desktop)
  static bool isLargeScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kBreakpointTablet;

  /// Lấy width hiện tại
  static double width(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  /// Lấy height hiện tại
  static double height(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  /// Padding nội dung — lớn hơn trên desktop
  static EdgeInsets contentPadding(BuildContext context) {
    if (isDesktop(context)) return const EdgeInsets.all(32);
    if (isTablet(context))  return const EdgeInsets.all(24);
    return const EdgeInsets.all(16);
  }

  /// Số cột grid module — nhiều hơn trên màn lớn
  static int gridColumns(BuildContext context) {
    if (isDesktop(context)) return 4;
    if (isTablet(context))  return 3;
    return 2;
  }

  /// Font size cơ bản — lớn hơn trên desktop cho dễ đọc
  static double baseFontSize(BuildContext context) {
    if (isDesktop(context)) return 16;
    return 14;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE LAYOUT WIDGET
// ─────────────────────────────────────────────────────────────────────────────

/// Widget bọc màn hình — tự chọn layout đúng theo kích thước.
///
/// ⚠️ QUY TẮC BẮT BUỘC: Mọi màn hình mới từ 2026-04-30 trở đi PHẢI dùng widget này.
///
/// Cách dùng:
/// ```dart
/// return ResponsiveLayout(
///   mobile:  _MobileView(),
///   tablet:  _TabletView(),   // bỏ qua nếu giống mobile
///   desktop: _DesktopView(),
/// );
/// ```
class ResponsiveLayout extends StatelessWidget {
  /// Layout cho điện thoại (bắt buộc)
  final Widget mobile;

  /// Layout cho tablet — nếu null thì dùng mobile
  final Widget? tablet;

  /// Layout cho desktop — nếu null thì dùng tablet, rồi mobile
  final Widget? desktop;

  const ResponsiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) return desktop ?? tablet ?? mobile;
    if (Responsive.isTablet(context))  return tablet ?? mobile;
    return mobile;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESPONSIVE VALUE — lấy giá trị theo breakpoint
// ─────────────────────────────────────────────────────────────────────────────

/// Lấy giá trị khác nhau tuỳ màn hình — tiện dùng inline.
///
/// Ví dụ:
/// ```dart
/// double fontSize = responsiveValue(context, mobile: 14, tablet: 16, desktop: 18);
/// ```
T responsiveValue<T>(
  BuildContext context, {
  required T mobile,
  T? tablet,
  T? desktop,
}) {
  if (Responsive.isDesktop(context)) return desktop ?? tablet ?? mobile;
  if (Responsive.isTablet(context))  return tablet ?? mobile;
  return mobile;
}
