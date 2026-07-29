import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/staff_service.dart';
import 'package:quannho_pos/modules/tinhluong/repository/tinhluong_repository.dart';
import 'package:quannho_pos/modules/tinhluong/repository/staff_salary_config_repository.dart';
import 'package:quannho_pos/modules/tinhluong/repository/shift_template_repository.dart';

void main() {
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
      expect(result.penaltyReasons.any((r) => r.contains('Đi muộn 15p')), isTrue);
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
  });
}
