// lib/core/utils/adaptive.dart
// ─────────────────────────────────────────────────────────────────
// Adaptive layout utilities cho Quán Nhỏ POS
// Mục tiêu: Scale up UI trên tablet/desktop mà không ảnh hưởng phone
//
// Cách dùng:
//   final ad = Adaptive(context);
//   SizedBox(height: ad.cardHeight)          // tự điều chỉnh theo màn hình
//   Text('...', style: TextStyle(fontSize: ad.fs(14)))
//   EdgeInsets.all(ad.p(16))
// ─────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

enum ScreenSize { phone, tablet, desktop }

class Adaptive {
  final BuildContext context;
  final double _width;

  Adaptive(this.context) : _width = MediaQuery.of(context).size.width;

  // ── Loại màn hình ──────────────────────────────────────────────
  ScreenSize get screenSize {
    if (_width >= 1024) return ScreenSize.desktop;
    if (_width >= 600)  return ScreenSize.tablet;
    return ScreenSize.phone;
  }

  bool get isPhone   => screenSize == ScreenSize.phone;
  bool get isTablet  => screenSize == ScreenSize.tablet;
  bool get isDesktop => screenSize == ScreenSize.desktop;
  bool get isLarge   => !isPhone; // tablet hoặc desktop

  // ── Scale factor tổng ──────────────────────────────────────────
  // phone=1.0, tablet=1.25, desktop=1.4
  double get scale {
    switch (screenSize) {
      case ScreenSize.desktop: return 1.4;
      case ScreenSize.tablet:  return 1.25;
      case ScreenSize.phone:   return 1.0;
    }
  }

  // ── Font size — scale theo màn hình ───────────────────────────
  double fs(double phoneSize) => phoneSize * scale;

  // ── Padding — scale theo màn hình ─────────────────────────────
  double p(double phoneValue) => phoneValue * scale;

  // ── Các giá trị thông dụng ────────────────────────────────────

  /// Chiều cao stat card (card hiển thị số liệu tổng)
  double get statCardHeight {
    switch (screenSize) {
      case ScreenSize.desktop: return 140;
      case ScreenSize.tablet:  return 120;
      case ScreenSize.phone:   return 90;
    }
  }

  /// Chiều cao chart
  double get chartHeight {
    switch (screenSize) {
      case ScreenSize.desktop: return 420;
      case ScreenSize.tablet:  return 320;
      case ScreenSize.phone:   return 200;
    }
  }

  /// Chiều cao list item (row trong bảng danh sách)
  double get listItemHeight {
    switch (screenSize) {
      case ScreenSize.desktop: return 72;
      case ScreenSize.tablet:  return 64;
      case ScreenSize.phone:   return 52;
    }
  }

  /// Padding ngang của content area
  double get horizontalPadding {
    switch (screenSize) {
      case ScreenSize.desktop: return 32;
      case ScreenSize.tablet:  return 24;
      case ScreenSize.phone:   return 16;
    }
  }

  /// Padding dọc giữa các section
  double get sectionSpacing {
    switch (screenSize) {
      case ScreenSize.desktop: return 24;
      case ScreenSize.tablet:  return 20;
      case ScreenSize.phone:   return 12;
    }
  }

  /// Gap giữa các card trong grid
  double get cardGap {
    switch (screenSize) {
      case ScreenSize.desktop: return 16;
      case ScreenSize.tablet:  return 14;
      case ScreenSize.phone:   return 10;
    }
  }

  /// Icon size
  double get iconSize {
    switch (screenSize) {
      case ScreenSize.desktop: return 28;
      case ScreenSize.tablet:  return 24;
      case ScreenSize.phone:   return 20;
    }
  }

  /// Border radius cho card
  double get cardRadius {
    switch (screenSize) {
      case ScreenSize.desktop: return 20;
      case ScreenSize.tablet:  return 16;
      case ScreenSize.phone:   return 12;
    }
  }

  // ── Số cột cho GridView ────────────────────────────────────────
  int gridColumns({int phone = 2, int tablet = 3, int desktop = 4}) {
    switch (screenSize) {
      case ScreenSize.desktop: return desktop;
      case ScreenSize.tablet:  return tablet;
      case ScreenSize.phone:   return phone;
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Widget wrapper tiện lợi — dùng khi muốn layout đơn giản
// ─────────────────────────────────────────────────────────────────
class AdaptiveBody extends StatelessWidget {
  final Widget child;
  /// Thêm padding ngang tự động theo màn hình
  final bool withHorizontalPadding;

  const AdaptiveBody({
    super.key,
    required this.child,
    this.withHorizontalPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    final ad = Adaptive(context);
    if (!withHorizontalPadding) return child;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: ad.horizontalPadding),
      child: child,
    );
  }
}
