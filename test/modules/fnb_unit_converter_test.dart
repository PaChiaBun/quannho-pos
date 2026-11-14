import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/quantity_formatter.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart';

void main() {
  group('F&B Multi-Unit Converter Tests — Dual-Track 4-Tier Matrix', () {
    // ═════════════════════════════════════════════════════════════════════════
    // TIER 1: FEATURE CORE CONVERSIONS (HAPPY PATHS)
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 1: Standard Metric Weight & Volume Conversions', () {
      test('converts grams to kilograms (1000:1 ratio)', () {
        expect(convertRecipeIngredientQty(1000, 'g', 'kg'), closeTo(1.0, 1e-6));
        expect(convertRecipeIngredientQty(500, 'g', 'kg'), closeTo(0.5, 1e-6));
        expect(convertRecipeIngredientQty(13, 'g', 'kg'), closeTo(0.013, 1e-6));
        expect(convertRecipeIngredientQty(15, 'gram', 'kg'), closeTo(0.015, 1e-6));
      });

      test('converts kilograms to grams (1:1000 ratio)', () {
        expect(convertRecipeIngredientQty(1, 'kg', 'g'), closeTo(1000.0, 1e-6));
        expect(convertRecipeIngredientQty(0.013, 'kg', 'g'), closeTo(13.0, 1e-6));
        expect(convertRecipeIngredientQty(0.5, 'kg', 'gram'), closeTo(500.0, 1e-6));
      });

      test('converts milliliters to liters (1000:1 ratio)', () {
        expect(convertRecipeIngredientQty(1000, 'ml', 'lít'), closeTo(1.0, 1e-6));
        expect(convertRecipeIngredientQty(250, 'ml', 'lít'), closeTo(0.25, 1e-6));
        expect(convertRecipeIngredientQty(20, 'ml', 'lít'), closeTo(0.020, 1e-6));
      });

      test('converts liters to milliliters (1:1000 ratio)', () {
        expect(convertRecipeIngredientQty(1, 'lít', 'ml'), closeTo(1000.0, 1e-6));
        expect(convertRecipeIngredientQty(0.02, 'lít', 'ml'), closeTo(20.0, 1e-6));
        expect(convertRecipeIngredientQty(0.385, 'lit', 'ml'), closeTo(385.0, 1e-6));
      });

      test('identity conversion when recipe unit equals product unit', () {
        expect(convertRecipeIngredientQty(5, 'kg', 'kg'), closeTo(5.0, 1e-6));
        expect(convertRecipeIngredientQty(20, 'ml', 'ml'), closeTo(20.0, 1e-6));
        expect(convertRecipeIngredientQty(2, 'lon', 'lon'), closeTo(2.0, 1e-6));
        expect(convertRecipeIngredientQty(1, 'phần', 'phần'), closeTo(1.0, 1e-6));
      });
    });

    group('Tier 1: F&B Density Cross-Dimension Conversions (ρ ≈ 1.0 g/ml)', () {
      test('converts ml to kg directly for liquid ingredients', () {
        // 20 ml condensed milk stocked in kg
        expect(convertRecipeIngredientQty(20, 'ml', 'kg'), closeTo(0.020, 1e-6));
        expect(convertRecipeIngredientQty(250, 'ml', 'kg'), closeTo(0.250, 1e-6));
      });

      test('converts grams to lít directly for powder/liquid mix', () {
        // 15 g salt cream powder stocked in lít
        expect(convertRecipeIngredientQty(15, 'g', 'lít'), closeTo(0.015, 1e-6));
        expect(convertRecipeIngredientQty(500, 'gram', 'lít'), closeTo(0.500, 1e-6));
      });
    });

    group('Tier 1: Packaging Specifications (conversion_rate & conversion_unit)', () {
      test('converts recipe base unit to product packaging (1 lon = 385 ml)', () {
        // 20 ml condensed milk from a can of 385 ml
        final cans = convertRecipeIngredientQty(
          20, 'ml', 'lon',
          conversionRate: 385,
          conversionUnit: 'ml',
        );
        expect(cans, closeTo(20.0 / 385.0, 1e-6));
        expect(cans, closeTo(0.051948, 1e-4));
      });

      test('converts whole package when recipe matches rate exactly', () {
        final cans = convertRecipeIngredientQty(
          385, 'ml', 'lon',
          conversionRate: 385,
          conversionUnit: 'ml',
        );
        expect(cans, closeTo(1.0, 1e-6));
      });

      test('converts parent unit to packaging (0.385 lít to lon of 385 ml)', () {
        final cans = convertRecipeIngredientQty(
          0.385, 'lít', 'lon',
          conversionRate: 385,
          conversionUnit: 'ml',
        );
        expect(cans, closeTo(1.0, 1e-6));
      });

      test('converts carton packaging (1 hộp = 1000 ml)', () {
        final cartons = convertRecipeIngredientQty(
          250, 'ml', 'hộp',
          conversionRate: 1000,
          conversionUnit: 'ml',
        );
        expect(cartons, closeTo(0.25, 1e-6));
      });

      test('converts bag packaging (1 gói = 500 g)', () {
        final bags = convertRecipeIngredientQty(
          15, 'g', 'gói',
          conversionRate: 500,
          conversionUnit: 'g',
        );
        expect(bags, closeTo(0.03, 1e-6));
      });
    });

    // ═════════════════════════════════════════════════════════════════════════
    // TIER 2: BOUNDARIES, TOLERANCES & CORNER CASES
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 2: Edge Cases, Guards & Incompatible Dimensions', () {
      test('guards against division by zero when conversionRate is 0', () {
        // Safe division guard: should not crash, returns raw qty
        final result = convertRecipeIngredientQty(
          20, 'ml', 'lon',
          conversionRate: 0,
          conversionUnit: 'ml',
        );
        expect(result, closeTo(20.0, 1e-6));
      });

      test('guards against negative conversionRate', () {
        final result = convertRecipeIngredientQty(
          20, 'ml', 'lon',
          conversionRate: -385,
          conversionUnit: 'ml',
        );
        expect(result, closeTo(20.0, 1e-6));
      });

      test('guards against empty conversionUnit with positive rate', () {
        final result = convertRecipeIngredientQty(
          20, 'ml', 'lon',
          conversionRate: 385,
          conversionUnit: '',
        );
        // Without conversionUnit, cannot verify dimension -> fallback
        expect(result, isNotNull);
      });

      test('handles incompatible dimensions gracefully without exception', () {
        // 'cái' to 'kg' cannot be converted mathematically -> fallback to raw qty
        final result = convertRecipeIngredientQty(2, 'cái', 'kg');
        expect(result, closeTo(2.0, 1e-6));

        final result2 = convertRecipeIngredientQty(3, 'phần', 'lít');
        expect(result2, closeTo(3.0, 1e-6));
      });

      test('handles zero quantity input', () {
        expect(convertRecipeIngredientQty(0, 'ml', 'kg'), closeTo(0.0, 1e-6));
        expect(convertRecipeIngredientQty(0, 'g', 'kg'), closeTo(0.0, 1e-6));
      });

      test('handles negative quantity (e.g. refund/reversal)', () {
        expect(convertRecipeIngredientQty(-20, 'ml', 'kg'), closeTo(-0.020, 1e-6));
        expect(convertRecipeIngredientQty(-13, 'g', 'kg'), closeTo(-0.013, 1e-6));
      });

      test('normalizes Vietnamese unit synonyms and case/whitespace variations', () {
        // Weight synonyms
        expect(convertRecipeIngredientQty(1000, '  GRAM  ', 'kg'), closeTo(1.0, 1e-6));
        expect(convertRecipeIngredientQty(500, 'gr', 'Ký'), closeTo(0.5, 1e-6));
        expect(convertRecipeIngredientQty(250, 'grm', 'kí'), closeTo(0.25, 1e-6));
        expect(convertRecipeIngredientQty(1, 'ki', 'g'), closeTo(1000.0, 1e-6));

        // Volume synonyms
        expect(convertRecipeIngredientQty(1000, 'mili lít', 'Lít'), closeTo(1.0, 1e-6));
        expect(convertRecipeIngredientQty(500, 'mililit', 'lit'), closeTo(0.5, 1e-6));
        expect(convertRecipeIngredientQty(100, 'cc', 'l'), closeTo(0.1, 1e-6));
      });
    });

    group('Tier 2: RecipeIngredientModel Yield Factor & Wastage Logic', () {
      test('actualQuantity with normal yield factor 1.0 (no wastage)', () {
        const ing = RecipeIngredientModel(
          id: 'ing-1',
          recipeId: 'rec-1',
          quantity: 20,
          unit: 'ml',
          yieldFactor: 1.0,
        );
        expect(ing.actualQuantity, closeTo(20.0, 1e-6));
        expect(ing.wastePct, closeTo(0.0, 1e-6));
      });

      test('actualQuantity with preparation wastage (yield factor 0.8 = 20% waste)', () {
        // 100g raw item with 80% yield requires 100 / 0.8 = 125g gross
        const ing = RecipeIngredientModel(
          id: 'ing-2',
          recipeId: 'rec-1',
          quantity: 100,
          unit: 'g',
          yieldFactor: 0.8,
        );
        expect(ing.actualQuantity, closeTo(125.0, 1e-6));
        expect(ing.wastePct, closeTo(20.0, 1e-6));
      });

      test('actualQuantity guards against division by zero (yieldFactor = 0)', () {
        const ing = RecipeIngredientModel(
          id: 'ing-3',
          recipeId: 'rec-1',
          quantity: 50,
          unit: 'ml',
          yieldFactor: 0.0,
        );
        // Falls back safely to raw quantity without throwing Infinity or NaN
        expect(ing.actualQuantity, closeTo(50.0, 1e-6));
      });

      test('actualQuantity guards against negative yieldFactor', () {
        const ing = RecipeIngredientModel(
          id: 'ing-4',
          recipeId: 'rec-1',
          quantity: 50,
          unit: 'ml',
          yieldFactor: -0.5,
        );
        expect(ing.actualQuantity, closeTo(50.0, 1e-6));
      });
    });

    // ═════════════════════════════════════════════════════════════════════════
    // TIER 3: CROSS-FEATURE & RECIPE MULTI-INGREDIENT DEDUCTIONS
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 3: Multi-Ingredient Drink Deduction Simulation', () {
      test('Cafe Muoi recipe deduction calculates exact stock deltas', () {
        // Recipe:
        // 1. Sữa đặc: 20 ml (product unit: kg)
        // 2. Cà phê hạt: 13 g (product unit: kg, yield: 0.95 espresso extraction)
        // 3. Bột kem muối: 15 g (product unit: lít)
        const milk = RecipeIngredientModel(
          id: 'milk',
          recipeId: 'cafe-muoi',
          quantity: 20,
          unit: 'ml',
          yieldFactor: 1.0,
        );
        const beans = RecipeIngredientModel(
          id: 'beans',
          recipeId: 'cafe-muoi',
          quantity: 13,
          unit: 'g',
          yieldFactor: 1.0,
        );
        const cream = RecipeIngredientModel(
          id: 'cream',
          recipeId: 'cafe-muoi',
          quantity: 15,
          unit: 'g',
          yieldFactor: 1.0,
        );

        final milkStockDelta = convertRecipeIngredientQty(
          milk.actualQuantity, milk.unit, 'kg',
        );
        final beanStockDelta = convertRecipeIngredientQty(
          beans.actualQuantity, beans.unit, 'kg',
        );
        final creamStockDelta = convertRecipeIngredientQty(
          cream.actualQuantity, cream.unit, 'lít',
        );

        expect(milkStockDelta, closeTo(0.020, 1e-6));
        expect(beanStockDelta, closeTo(0.013, 1e-6));
        expect(creamStockDelta, closeTo(0.015, 1e-6));

        // Format checking integration
        expect(fmtDelta(-milkStockDelta, 'kg'), '-0.02 kg');
        expect(fmtDelta(-beanStockDelta, 'kg'), '-0.013 kg');
        expect(fmtDelta(-creamStockDelta, 'lít'), '-0.015 lít');
      });

      test('Topping modifier multiplier scales deduction linearly', () {
        // Milk Tea with 2x Boba Topping
        // 1 serving of Boba = 30 g (product unit: kg)
        const boba = RecipeIngredientModel(
          id: 'boba',
          recipeId: 'top-boba',
          quantity: 30,
          unit: 'g',
          yieldFactor: 1.0,
        );
        const modifierQuantity = 2; // 2x topping

        final totalGrossBoba = boba.actualQuantity * modifierQuantity; // 60 g
        final stockDelta = convertRecipeIngredientQty(totalGrossBoba, boba.unit, 'kg');

        expect(stockDelta, closeTo(0.060, 1e-6));
        expect(fmtDelta(-stockDelta, 'kg'), '-0.06 kg');
      });
    });

    // ═════════════════════════════════════════════════════════════════════════
    // TIER 4: REAL-WORLD AUDIT & DISCREPANCY RECOVERY
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 4: Over-Deduction Audit Discrepancy Verification', () {
      test('calculates exact recovery quantities for orders #QN-20260930-002, 003, #QN-20261001-001', () {
        // The bug subtracted raw 20, 13, 15 from kg stock
        const rawMilkDeducted = 20.0;
        const rawBeansDeducted = 13.0;
        const rawCreamDeducted = 15.0;

        final correctMilk = convertRecipeIngredientQty(20, 'ml', 'kg');
        final correctBeans = convertRecipeIngredientQty(13, 'g', 'kg');
        final correctCream = convertRecipeIngredientQty(15, 'g', 'lít');

        final milkOverDeductionPerOrder = rawMilkDeducted - correctMilk;
        final beansOverDeductionPerOrder = rawBeansDeducted - correctBeans;
        final creamOverDeductionPerOrder = rawCreamDeducted - correctCream;

        expect(milkOverDeductionPerOrder, closeTo(19.980, 1e-6));
        expect(beansOverDeductionPerOrder, closeTo(12.987, 1e-6));
        expect(creamOverDeductionPerOrder, closeTo(14.985, 1e-6));

        // For 3 orders combined
        const orderCount = 3;
        expect(milkOverDeductionPerOrder * orderCount, closeTo(59.940, 1e-6));
        expect(beansOverDeductionPerOrder * orderCount, closeTo(38.961, 1e-6));
        expect(creamOverDeductionPerOrder * orderCount, closeTo(44.955, 1e-6));
      });
    });
  });
}
