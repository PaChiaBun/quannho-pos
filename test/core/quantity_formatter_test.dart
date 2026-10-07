import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/quantity_formatter.dart';

void main() {
  group('QuantityFormatter Tests — Dual-Track 4-Tier Matrix', () {
    // ═════════════════════════════════════════════════════════════════════════
    // TIER 1: FEATURE CORE FUNCTIONALITY (HAPPY PATHS)
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 1: fmtQty — Core Whole & Decimal Numbers', () {
      test('formats standard positive whole numbers', () {
        expect(fmtQty(1), '1');
        expect(fmtQty(5), '5');
        expect(fmtQty(10), '10');
        expect(fmtQty(100), '100');
      });

      test('formats standard decimals without trailing zeros', () {
        expect(fmtQty(0.5), '0.5');
        expect(fmtQty(0.25), '0.25');
        expect(fmtQty(0.75), '0.75');
      });

      test('formats typical F&B sub-unit quantities (kg/lít)', () {
        // 20 ml condensed milk in kg
        expect(fmtQty(0.02), '0.02');
        // 15 g salt cream in lít
        expect(fmtQty(0.015), '0.015');
        // 13 g coffee beans in kg
        expect(fmtQty(0.013), '0.013');
      });

      test('formats stock reconciliation quantities with high precision', () {
        // Over-deducted compensations
        expect(fmtQty(19.98), '19.98');
        expect(fmtQty(12.987), '12.987');
        expect(fmtQty(14.985), '14.985');
        expect(fmtQty(59.94), '59.94');
        expect(fmtQty(38.961), '38.961');
        expect(fmtQty(44.955), '44.955');
      });
    });

    group('Tier 1: fmtDelta — Directional Delta with Unit Suffix', () {
      test('formats positive whole delta with + sign and unit', () {
        expect(fmtDelta(5, 'lon'), '+5 lon');
        expect(fmtDelta(1, 'hộp'), '+1 hộp');
        expect(fmtDelta(24, 'chai'), '+24 chai');
      });

      test('formats negative whole delta with - sign and unit', () {
        expect(fmtDelta(-20, 'kg'), '-20 kg');
        expect(fmtDelta(-1, 'lon'), '-1 lon');
        expect(fmtDelta(-10, 'phần'), '-10 phần');
      });

      test('formats positive decimal delta (e.g. stock receive or reconciliation)', () {
        expect(fmtDelta(0.02, 'kg'), '+0.02 kg');
        expect(fmtDelta(0.015, 'lít'), '+0.015 lít');
        expect(fmtDelta(19.98, 'kg'), '+19.98 kg');
        expect(fmtDelta(12.987, 'kg'), '+12.987 kg');
      });

      test('formats negative decimal delta for sub-unit recipe deductions', () {
        expect(fmtDelta(-0.02, 'kg'), '-0.02 kg');
        expect(fmtDelta(-0.015, 'lít'), '-0.015 lít');
        expect(fmtDelta(-0.013, 'kg'), '-0.013 kg');
        expect(fmtDelta(-0.052, 'lon'), '-0.052 lon');
      });

      test('formats zero delta as neutral without sign or negative prefix', () {
        expect(fmtDelta(0, 'kg'), '0 kg');
        expect(fmtDelta(0.0, 'lít'), '0 lít');
        expect(fmtDelta(0, 'lon'), '0 lon');
      });
    });

    // ═════════════════════════════════════════════════════════════════════════
    // TIER 2: BOUNDARIES, TOLERANCES & CORNER CASES
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 2: Absolute Guard Against "-0" and "-0.0"', () {
      test('strictly returns "0" for negative zero floating points', () {
        expect(fmtQty(-0.0), '0');
        expect(fmtQty(-0), '0');
        expect(fmtDelta(-0.0, 'kg'), '0 kg');
        expect(fmtDelta(-0, 'lít'), '0 lít');
      });

      test('strictly suppresses sign for sub-threshold negative micro-deltas', () {
        // Epsilon threshold: abs(delta) < 1e-6 must display as neutral 0, never -0
        expect(fmtQty(-0.0000001), '0');
        expect(fmtQty(-0.0000009), '0');
        expect(fmtDelta(-0.0000001, 'kg'), '0 kg');
        expect(fmtDelta(-0.0000009, 'lít'), '0 lít');
      });

      test('formats micro-quantities at 1e-6 threshold cleanly', () {
        expect(fmtQty(0.000001), '0');
        expect(fmtDelta(0.000001, 'kg'), '0 kg');
      });

      test('rounds small sub-milligram decimals within 3 decimals gracefully', () {
        // 0.0004 rounds to 0.000 -> 0
        expect(fmtQty(0.0004), '0');
        // 0.0006 rounds to 0.001
        expect(fmtQty(0.0006), '0.001');
        expect(fmtDelta(-0.0006, 'kg'), '-0.001 kg');
      });

      test('respects custom maxDecimals parameter when specified', () {
        expect(fmtQty(0.12345, maxDecimals: 4), '0.1235');
        expect(fmtQty(0.12345, maxDecimals: 2), '0.12');
        expect(fmtQty(0.12345, maxDecimals: 1), '0.1');
        expect(fmtQty(0.12345, maxDecimals: 0), '0');
        expect(fmtQty(5.6789, maxDecimals: 2), '5.68');
      });

      test('formats very large quantities without scientific notation', () {
        expect(fmtQty(1000000), '1000000');
        expect(fmtQty(999999.5), '999999.5');
        expect(fmtDelta(1000000, 'g'), '+1000000 g');
        expect(fmtDelta(-500000, 'ml'), '-500000 ml');
      });

      test('handles empty, whitespace, or missing unit strings safely', () {
        expect(fmtDelta(5, ''), '+5');
        expect(fmtDelta(-0.02, ''), '-0.02');
        expect(fmtDelta(0, ''), '0');
        expect(fmtDelta(5, '   '), '+5');
        expect(fmtDelta(-0.02, '   '), '-0.02');
        expect(fmtDelta(0, '   '), '0');
      });

      test('trims excess whitespace around unit names', () {
        expect(fmtDelta(10, '  kg  '), '+10 kg');
        expect(fmtDelta(-0.5, '  lít  '), '-0.5 lít');
      });
    });

    // ═════════════════════════════════════════════════════════════════════════
    // TIER 3: CROSS-FEATURE & WORKFLOW INTERACTIONS
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 3: Reason Label Localization & History Integration', () {
      test('reasonLabel translates recipe_usage, purchase, reconciliation', () {
        expect(reasonLabel('recipe_usage'), 'Xuất công thức');
        expect(reasonLabel('purchase'), 'Nhập kho');
        expect(reasonLabel('reconciliation'), 'Bù hoàn kho');
      });

      test('reasonLabel translates all core inventory operational reasons', () {
        expect(reasonLabel('receive'), 'Nhập kho');
        expect(reasonLabel('adjust'), 'Hiệu chỉnh');
        expect(reasonLabel('adjustment'), 'Hiệu chỉnh');
        expect(reasonLabel('sale'), 'Bán hàng');
        expect(reasonLabel('production'), 'Sản xuất');
        expect(reasonLabel('return'), 'Hoàn trả');
        expect(reasonLabel('waste'), 'Hao hụt');
        expect(reasonLabel('damaged'), 'Hư hỏng');
        expect(reasonLabel('transfer'), 'Chuyển kho');
      });

      test('reasonLabel preserves unrecognized custom reasons as-is', () {
        expect(reasonLabel('custom_reason_xyz'), 'custom_reason_xyz');
        expect(reasonLabel('audit_2026'), 'audit_2026');
      });

      test('simulates _HistorySheet rendering line for Cafe Muoi order', () {
        // Cafe Muoi recipe lines deducted:
        // Condensed milk: -0.020 kg
        // Coffee beans: -0.013 kg
        // Salt cream: -0.015 lít
        final milkDeltaText = fmtDelta(-0.02, 'kg');
        final beanDeltaText = fmtDelta(-0.013, 'kg');
        final creamDeltaText = fmtDelta(-0.015, 'lít');

        expect(milkDeltaText, '-0.02 kg');
        expect(beanDeltaText, '-0.013 kg');
        expect(creamDeltaText, '-0.015 lít');

        // Never produce the old buggy UI output:
        expect(milkDeltaText, isNot('-0 kg'));
        expect(beanDeltaText, isNot('-0 kg'));
        expect(creamDeltaText, isNot('-0 lít'));
      });
    });

    // ═════════════════════════════════════════════════════════════════════════
    // TIER 4: REAL-WORLD SCENARIOS & ADVERSARIAL STRESS
    // ═════════════════════════════════════════════════════════════════════════
    group('Tier 4: Real-World Audit Reconciliation & High-Volume Sales', () {
      test('formats historical reconciliation records for 3 damaged orders', () {
        // Compensation for #QN-20260930-002, #QN-20260930-003, #QN-20261001-001
        final suaDacPerOrder = fmtDelta(19.980, 'kg');
        final caPhePerOrder = fmtDelta(12.987, 'kg');
        final kemMuoiPerOrder = fmtDelta(14.985, 'kg');

        expect(suaDacPerOrder, '+19.98 kg');
        expect(caPhePerOrder, '+12.987 kg');
        expect(kemMuoiPerOrder, '+14.985 kg');

        final totalSuaDac = fmtDelta(59.940, 'kg');
        final totalCaPhe = fmtDelta(38.961, 'kg');
        final totalKemMuoi = fmtDelta(44.955, 'kg');

        expect(totalSuaDac, '+59.94 kg');
        expect(totalCaPhe, '+38.961 kg');
        expect(totalKemMuoi, '+44.955 kg');
      });

      test('formats negative inventory backorder levels cleanly', () {
        // In F&B, when stock runs out, inventory continues into negative
        expect(fmtQty(-0.02), '-0.02');
        expect(fmtQty(-1.5), '-1.5');
        expect(fmtQty(-25), '-25');
        expect(fmtDelta(-0.02, 'kg'), '-0.02 kg');
        expect(fmtDelta(-10.5, 'lon'), '-10.5 lon');
      });

      test('rapid sequence of fractional deductions produces exact displays', () {
        double currentStock = 1.000; // 1 kg coffee beans
        final deductions = [0.013, 0.013, 0.013, 0.013, 0.013]; // 5 shots of espresso

        for (final deduction in deductions) {
          final deltaDisplay = fmtDelta(-deduction, 'kg');
          expect(deltaDisplay, '-0.013 kg');
          currentStock -= deduction;
        }

        // Remaining stock after 5 shots: 1 - 5 * 0.013 = 0.935 kg
        expect(fmtQty(currentStock), '0.935');
      });
    });
  });
}
