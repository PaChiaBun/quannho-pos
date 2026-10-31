import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/quantity_formatter.dart';

void main() {
  group('recipeUnitWarning', () {
    test('cùng đơn vị → không cảnh báo', () {
      expect(recipeUnitWarning(recipeUnit: 'kg', productUnit: 'kg'), isNull);
      expect(recipeUnitWarning(recipeUnit: 'gram', productUnit: 'g'), isNull);
    });
    test('g → kg, ml → lít quy đổi chuẩn → không cảnh báo', () {
      expect(recipeUnitWarning(recipeUnit: 'gram', productUnit: 'kg'), isNull);
      expect(recipeUnitWarning(recipeUnit: 'ml', productUnit: 'lít'), isNull);
    });
    test('có quy cách 1 gói = 1000 g, công thức dùng gram → ổn', () {
      expect(
        recipeUnitWarning(recipeUnit: 'gram', productUnit: 'gói', conversionRate: 1000, conversionUnit: 'g'),
        isNull,
      );
    });
    test('công thức dùng gram nhưng kho là gói và chưa có quy cách → cảnh báo', () {
      final w = recipeUnitWarning(recipeUnit: 'gram', productUnit: 'gói');
      expect(w, isNotNull);
      expect(w, contains('Quy cách pha chế'));
    });
    test('quy cách bằng ml nhưng công thức dùng chai → cảnh báo', () {
      final w = recipeUnitWarning(
          recipeUnit: 'chai', productUnit: 'lon', conversionRate: 385, conversionUnit: 'ml');
      expect(w, isNotNull);
    });
    test('g ↔ ml khác loại → cảnh báo tỷ trọng', () {
      final w = recipeUnitWarning(recipeUnit: 'ml', productUnit: 'kg');
      expect(w, isNotNull);
      expect(w, contains('1 g = 1 ml'));
    });
    test('đơn vị rời khác nhau không quy đổi → cảnh báo', () {
      expect(recipeUnitWarning(recipeUnit: 'hộp', productUnit: 'lon'), isNotNull);
    });
  });

  group('reasonLabel mới', () {
    test('nhãn kiểm kê / hao hụt', () {
      expect(reasonLabel('stock_count'), 'Kiểm kê');
      expect(reasonLabel('expired'), 'Hết hạn');
      expect(reasonLabel('spill'), 'Đổ vỡ');
    });
  });
}
