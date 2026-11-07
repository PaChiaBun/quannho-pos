import 'package:flutter_test/flutter_test.dart';

/// Helper xác định header bar nhận constraints compact (< 500px)
/// Màn hình < 600px: 1 cột, header width = screen width.
/// Màn hình >= 600px: chia 2 cột (panel giỏ hàng 320px + 1px divider),
/// header width = screen width - 321px.
bool isHeaderCompactForScreen(double screenWidth) {
  final headerWidth = screenWidth < 600 ? screenWidth : (screenWidth - 321);
  return headerWidth < 500;
}

void main() {
  group('POS Header Layout - Viewport Matrix & Responsive Breakpoints', () {
    test('iPhone 5/SE1 (320px) is compact', () {
      expect(isHeaderCompactForScreen(320), isTrue);
    });

    test('iPhone SE2/3, 12/13 mini (375px) is compact', () {
      expect(isHeaderCompactForScreen(375), isTrue);
    });

    test('iPhone 12/13/14 (390px) is compact', () {
      expect(isHeaderCompactForScreen(390), isTrue);
    });

    test('iPhone 11/XR (414px) is compact', () {
      expect(isHeaderCompactForScreen(414), isTrue);
    });

    test('iPhone 14/15 Pro Max (430px) is compact', () {
      expect(isHeaderCompactForScreen(430), isTrue);
    });

    test('Single-column boundary (499px) is compact', () {
      expect(isHeaderCompactForScreen(499), isTrue);
    });

    test('Desktop single-column boundary (500px) is wide', () {
      expect(isHeaderCompactForScreen(500), isFalse);
    });

    test('Tablet split-screen (800px -> 479px header) is compact', () {
      expect(isHeaderCompactForScreen(800), isTrue);
    });

    test('Desktop split-screen (1000px -> 679px header) is wide', () {
      expect(isHeaderCompactForScreen(1000), isFalse);
    });
  });
}
