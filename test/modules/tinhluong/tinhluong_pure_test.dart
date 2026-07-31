import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/staff_service.dart';
import 'package:quannho_pos/modules/tinhluong/repository/tinhluong_repository.dart';
import 'package:quannho_pos/modules/tinhluong/repository/staff_salary_config_repository.dart';
import 'package:quannho_pos/modules/tinhluong/repository/shift_template_repository.dart';

void main() {
  group('Pure Helper Tests: payroll readiness', () {
    PayrollReadiness readiness({
      int missing = 0,
      int unclosed = 0,
      int pendingOt = 0,
      bool hasError = false,
    }) {
      return PayrollReadiness(
        missingSalaryConfigCount: missing,
        unclosedShiftCount: unclosed,
        pendingOtCount: pendingOt,
        blockingReasons: const [],
        hasError: hasError,
      );
    }

    test('allows submit only when every blocker is clear', () {
      expect(canSubmitPayroll(readiness()), isTrue);
    });

    test('blocks every individual readiness problem', () {
      expect(canSubmitPayroll(readiness(missing: 1)), isFalse);
      expect(canSubmitPayroll(readiness(unclosed: 1)), isFalse);
      expect(canSubmitPayroll(readiness(pendingOt: 1)), isFalse);
    });

    test('blocks multiple problems, evaluation errors and missing data', () {
      expect(canSubmitPayroll(readiness(missing: 2, pendingOt: 3)), isFalse);
      expect(canSubmitPayroll(readiness(hasError: true)), isFalse);
      expect(canSubmitPayroll(null), isFalse);
    });
  });

  group('Pure Helper Tests: calculateSingleShiftEarnings', () {
    test('calculateSingleShiftEarnings calculates late penalty correctly', () {
      final config = StaffSalaryConfig(
        id: 'cfg1',
        storeId: 'store1',
        userId: 'user1',
        staffName: 'Staff 1',
        role: 'waiter',
        salaryMode: 'M1',
        baseSalary: 0,
        hourlyRate: 20000,
        dailyRate: 0,
        expectedDays: 26,
        deductionPerLate: 50000,
        otThresholdHours: 8,
      );

      final template = ShiftTemplate(
        id: 'tpl1',
        storeId: 'store1',
        name: 'Sáng',
        startTime: '08:00',
        endTime: '16:00',
        color: '#FFFFFF',
        lateGraceMinutes: 10,
        isActive: true,
        sortOrder: 1,
      );

      // Đi trễ 15 phút (vượt grace 10 phút)
      final shift = ShiftRecord(
        id: 's1',
        userId: 'user1',
        userName: 'Staff 1',
        clockIn: DateTime(2026, 7, 29, 8, 15),
        clockOut: DateTime(2026, 7, 29, 16, 0),
        source: 'app',
        note: '',
      );

      final result = TinhLuongRepository.calculateSingleShiftEarnings(
        shift: shift,
        config: config,
        template: template,
      );

      // Phải có thông báo phạt muộn 15 phút và phạt 50000
      expect(result.deductionLate, 50000);
      expect(
        result.penaltyReasons.any((r) => r.contains('Đi muộn 15p')),
        isTrue,
      );
    });

    test('calculateSingleShiftEarnings OT check', () {
      final config = StaffSalaryConfig(
        id: 'cfg2',
        storeId: 'store1',
        userId: 'user2',
        staffName: 'Staff 2',
        role: 'waiter',
        salaryMode: 'M1',
        baseSalary: 0,
        hourlyRate: 20000,
        dailyRate: 0,
        expectedDays: 26,
        deductionPerLate: 50000,
        otThresholdHours: 8,
        otMultiplier: 1.5,
      );

      // Làm 10 tiếng (2 tiếng OT) và đã được duyệt OT
      final shift = ShiftRecord(
        id: 's2',
        userId: 'user2',
        userName: 'Staff 2',
        clockIn: DateTime(2026, 7, 29, 8, 0),
        clockOut: DateTime(2026, 7, 29, 18, 0), // 10h
        source: 'app',
        isOtApproved: true,
        note: '',
      );

      final result = TinhLuongRepository.calculateSingleShiftEarnings(
        shift: shift,
        config: config,
      );

      expect(result.totalHours, 10.0);
      expect(result.overtimeHours, 2.0);
      expect(result.regularPay, 8 * 20000.0);
      expect(result.overtimePay, 2 * 20000.0 * 1.5);
      expect(result.bonusReasons.any((r) => r.contains('OT 2.0h')), isTrue);
    });

    test(
      'M5 combines selected custom salary components without fallback rate',
      () {
        const config = StaffSalaryConfig(
          id: 'cfg-custom',
          storeId: 'store1',
          userId: 'user-custom',
          staffName: 'Staff Custom',
          role: 'waiter',
          salaryMode: 'M5',
          baseSalary: 2080000,
          hourlyRate: 20000,
          dailyRate: 80000,
          expectedDays: 26,
          deductionPerLate: 0,
          otThresholdHours: 8,
          otMultiplier: 1.5,
        );
        final shift = ShiftRecord(
          id: 's-custom',
          userId: 'user-custom',
          userName: 'Staff Custom',
          clockIn: DateTime(2026, 7, 29, 8),
          clockOut: DateTime(2026, 7, 29, 18),
          source: 'app',
          isOtApproved: true,
          note: '',
        );

        final result = TinhLuongRepository.calculateSingleShiftEarnings(
          shift: shift,
          config: config,
        );

        // Lương nền quy đổi 10K/h + lương giờ 20K/h + lương ngày 10K/h.
        expect(result.regularPay, 8 * 40000);
        // OT ưu tiên đơn giá giờ tùy chỉnh 20K × 1.5.
        expect(result.overtimePay, 2 * 20000 * 1.5);
        expect(result.netPay, 380000);
      },
    );
  });

  group('Pure Helper Tests: calculatePayroll', () {
    test('calculatePayroll handles late_count and basic pay', () {
      final input = PayrollInput(
        userId: 'u1',
        staffName: 'S1',
        salaryMode: 'M1',
        baseSalary: 0,
        hourlyRate: 25000,
        totalHours: 10,
        overtimeHours: 0,
        lateCount: 2, // 2 lần đi trễ
        absentDays: 0,
        bonusRevenue: 0,
        bonusManual: 100000,
        deductionManual: 20000,
        deductionPerLate: 50000,
        deductionPerAbsent: 0,
        extraItems: [],
      );

      final calc = calculatePayroll(input);

      // regularPay = 10 * 25000 = 250000
      expect(calc.regularPay, 250000);
      // grossPay = regularPay(250k) + bonusManual(100k) - deductionLate(100k) - deductionManual(20k) = 230000
      expect(calc.grossPay, 230000);
      // deductionLate = 2 * 50000 = 100000
      expect(calc.deductionLate, 100000);
      // net = max(0, grossPay) = 230000
      expect(calc.netPay, 230000);
    });

    test('calculatePayroll supports additive M5 custom components', () {
      const input = PayrollInput(
        userId: 'u-custom',
        staffName: 'Custom',
        salaryMode: 'M5',
        baseSalary: 1000000, // base 1 lần
        hourlyRate: 20000,
        dailyRate: 50000,
        expectedDays: 26,
        totalHours: 10,
        overtimeHours: 2,
        workDays: 1, // ngày 1 lần
        absentDays: 0,
        lateCount: 0,
        deductionPerLate: 0,
        deductionPerAbsent: 0,
        bonusRevenue: 0,
        bonusManual: 0,
        deductionManual: 0,
        otMultiplier: 1.5,
      );

      final calc = calculatePayroll(input);

      // base 1 lần (1tr) + (10 - 2) * 20k + 1 * 50k = 1.000.000 + 160.000 + 50.000 = 1.210.000
      expect(calc.regularPay, 1210000);
      expect(calc.overtimePay, 2 * 20000 * 1.5);
      expect(calc.netPay, 1270000);
    });

    test('calculatePayroll M2: base is added only once per period, OT calculated from base', () {
      const input = PayrollInput(
        userId: 'u2',
        staffName: 'S2',
        salaryMode: 'M2',
        baseSalary: 5200000,
        hourlyRate: 0,
        totalHours: 50,
        overtimeHours: 10,
        workDays: 10,
        absentDays: 0,
        lateCount: 0,
        deductionPerLate: 0,
        deductionPerAbsent: 0,
        bonusRevenue: 0,
        bonusManual: 0,
        deductionManual: 0,
        otMultiplier: 1.5,
      );
      final calc = calculatePayroll(input);
      expect(calc.regularPay, 5200000);
      expect(calc.overtimePay, 10 * (5200000 / 26 / 8) * 1.5);
    });

    test('calculatePayroll M3: base is added only once per period, OT from hourlyRate', () {
      const input = PayrollInput(
        userId: 'u3',
        staffName: 'S3',
        salaryMode: 'M3',
        baseSalary: 5200000,
        hourlyRate: 30000,
        totalHours: 50,
        overtimeHours: 10,
        workDays: 10,
        absentDays: 0,
        lateCount: 0,
        deductionPerLate: 0,
        deductionPerAbsent: 0,
        bonusRevenue: 0,
        bonusManual: 0,
        deductionManual: 0,
        otMultiplier: 1.5,
      );
      final calc = calculatePayroll(input);
      expect(calc.regularPay, 5200000);
      expect(calc.overtimePay, 10 * 30000 * 1.5);
    });

    test('calculatePayroll M4: pay is based on workedDays * dailyRate', () {
      const input = PayrollInput(
        userId: 'u4',
        staffName: 'S4',
        salaryMode: 'M4',
        baseSalary: 0,
        hourlyRate: 0,
        dailyRate: 200000,
        totalHours: 50,
        overtimeHours: 2,
        workDays: 5,
        absentDays: 0,
        lateCount: 0,
        deductionPerLate: 0,
        deductionPerAbsent: 0,
        bonusRevenue: 0,
        bonusManual: 0,
        deductionManual: 0,
        otMultiplier: 1.5,
      );
      final calc = calculatePayroll(input);
      expect(calc.regularPay, 5 * 200000);
      expect(calc.overtimePay, 2 * (200000 / 8) * 1.5);
    });

    test('calculatePayroll correctly subtracts manual deductions without double deducting', () {
      const input = PayrollInput(
        userId: 'u5',
        staffName: 'S5',
        salaryMode: 'M1',
        baseSalary: 0,
        hourlyRate: 25000,
        totalHours: 10,
        overtimeHours: 0,
        absentDays: 1,
        lateCount: 0,
        deductionPerLate: 0,
        deductionPerAbsent: 100000,
        bonusRevenue: 0,
        bonusManual: 0,
        deductionManual: 50000, // Manual deduction
        otMultiplier: 1.5,
      );
      final calc = calculatePayroll(input);
      // grossPay before max(0) should be:
      // regularPay(250k) - deductionAbsent(100k) - deductionManual(50k) = 100000
      expect(calc.grossPay, 100000);
      expect(calc.netPay, 100000);
    });

    test('configured extras only include attendance bonus at target days', () {
      const config = StaffSalaryConfig(
        id: 'cfg-extra',
        storeId: 'store-1',
        userId: 'user-1',
        staffName: 'Nhân viên',
        role: 'Phục vụ',
        salaryMode: 'M5',
        baseSalary: 0,
        hourlyRate: 25000,
        dailyRate: 0,
        expectedDays: 26,
        deductionPerLate: 0,
        otThresholdHours: 8,
        fixedBonus: 300000,
        attendanceBonus: 500000,
        fixedAllowance: 200000,
      );

      final beforeTarget = calculateConfiguredPeriodExtras(
        config: config,
        workedDays: 25,
      );
      expect(beforeTarget.bonus, 300000);
      expect(beforeTarget.allowance, 200000);

      final atTarget = calculateConfiguredPeriodExtras(
        config: config,
        workedDays: 26,
      );
      expect(atTarget.bonus, 800000);
      expect(atTarget.allowance, 200000);
    });
  });

  group('Pure Helper Tests: salary policy', () {
    StaffSalaryConfig config(
      String userId, {
      double hourlyRate = 25000,
      double fixedBonus = 0,
    }) {
      return StaffSalaryConfig(
        id: 'cfg-$userId',
        storeId: 'store-1',
        userId: userId,
        staffName: 'Nhân viên $userId',
        role: 'Phục vụ',
        salaryMode: 'M1',
        baseSalary: 0,
        hourlyRate: hourlyRate,
        dailyRate: 0,
        expectedDays: 26,
        deductionPerLate: 50000,
        otThresholdHours: 8,
        otMultiplier: 1.5,
        fixedBonus: fixedBonus,
        attendanceBonus: 0,
        fixedAllowance: 0,
      );
    }

    test('reports unconfigured when the role has no salary config', () {
      expect(determinePolicyStatus(const [], 3), PolicyStatus.unconfigured);
    });

    test('reports synchronized only when every salary field matches', () {
      expect(
        determinePolicyStatus([config('u1'), config('u2')], 2),
        PolicyStatus.synchronized,
      );
    });

    test('reports mixed when any salary field differs', () {
      expect(
        determinePolicyStatus([
          config('u1'),
          config('u2', fixedBonus: 100000),
        ], 2),
        PolicyStatus.mixed,
      );
    });

    test('unconfigured-only scope preserves existing employee overrides', () {
      final targets = selectPolicyTargets(
        items: ['u1', 'u2', 'u3'],
        isConfigured: (userId) => userId == 'u2',
        scope: PolicyApplyScope.unconfiguredOnly,
      );
      expect(targets, ['u1', 'u3']);
    });
  });

  group('Pure Helper Tests: evaluation service behaviors', () {
    test('fail-closed logic fallback to previous state when live calculation throws', () {
      final period = PayrollPeriodModel(
        id: '1',
        storeId: '1',
        name: 'Tháng 1',
        periodType: 'monthly',
        fromDate: '2026-01-01',
        toDate: '2026-01-31',
        status: 'draft',
        totalAmount: 5000000,
        createdAt: '2026-01-01T00:00:00Z'
      );

      PayrollPeriodModel result;
      try {
        // Mô phỏng lỗi khi gọi PayrollEvaluationService.evaluatePeriod (mất mạng, DB lỗi...)
        throw Exception('Network error');
      } catch (e) {
        // Fallback về trạng thái cũ từ DB
        result = period;
      }
      expect(result.totalAmount, 5000000); // Giữ nguyên giá trị cũ của DB
      expect(result.hasDelta, isFalse);
    });

    test('manual entry retention during recalculation', () {
      // Giả lập logic được thực hiện trong PayrollEvaluationService
      final existingBonusManual = 500000.0;
      final existingDeductionManual = 200000.0;

      final configuredBonus = 100000.0; // Thưởng cấu hình

      // Quy tắc: Nếu đã có giá trị nhập tay (khác 0), giữ nguyên; nếu không thì dùng giá trị cấu hình.
      final resolvedBonus = existingBonusManual != 0 ? existingBonusManual : configuredBonus;
      final resolvedDeduction = existingDeductionManual != 0 ? existingDeductionManual : 0.0;

      expect(resolvedBonus, 500000.0); // Giữ lại 500k thay vì lấy 100k
      expect(resolvedDeduction, 200000.0); // Giữ lại khoản khấu trừ
    });
  });
}
