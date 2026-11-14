import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/quantity_formatter.dart';

void main() {
  group('recipeUnitCost', () {
    test('gói 1000g giá 50.000 -> 50đ/gram', () {
      expect(
        recipeUnitCost(
          costPerStockUnit: 50000,
          recipeUnit: 'gram',
          productUnit: 'gói',
          conversionRate: 1000,
          conversionUnit: 'gram',
        ),
        closeTo(50, 1e-9),
      );
    });
    test('kho kg giá 55.000, công thức gram -> 55đ/g', () {
      expect(
        recipeUnitCost(
          costPerStockUnit: 55000,
          recipeUnit: 'gram',
          productUnit: 'kg',
        ),
        closeTo(55, 1e-9),
      );
    });
    test('kho kg, công thức kg -> giữ nguyên giá', () {
      expect(
        recipeUnitCost(
          costPerStockUnit: 55000,
          recipeUnit: 'kg',
          productUnit: 'kg',
        ),
        closeTo(55000, 1e-9),
      );
    });
    test('lon 385ml giá 22.000, dùng 20ml', () {
      final c = recipeUnitCost(
        costPerStockUnit: 22000,
        recipeUnit: 'ml',
        productUnit: 'lon',
        conversionRate: 385,
        conversionUnit: 'ml',
      );
      expect(c * 20, closeTo(22000 * 20 / 385, 1e-6));
    });
    test('đơn vị kho = đơn vị công thức (cái)', () {
      expect(
        recipeUnitCost(
          costPerStockUnit: 3000,
          recipeUnit: 'cái',
          productUnit: 'cái',
        ),
        3000,
      );
    });
  });
  test('effectiveUnitCost ưu tiên giá nhập gần nhất > 0', () {
    expect(effectiveUnitCost(0, 100), 100);
    expect(effectiveUnitCost(120, 100), 120);
  });
  test('reasonLabel nhập thành phẩm từ lệnh sản xuất', () {
    expect(reasonLabel('production_output'), 'Nhập thành phẩm');
  });
}
