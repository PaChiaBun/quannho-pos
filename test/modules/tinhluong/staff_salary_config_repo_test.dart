import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/tinhluong/repository/staff_salary_config_repository.dart';

void main() {
  group('PolicyStatus Tests', () {
    test('Empty configs returns unconfigured', () {
      final status = determinePolicyStatus([], 5);
      expect(status, PolicyStatus.unconfigured);
    });

    test('All configs identical but count < total returns mixed', () {
      final configs = [
        const StaffSalaryConfig(
          id: '1',
          storeId: '1',
          userId: 'u1',
          staffName: 'n1',
          role: 'r1',
          salaryMode: 'M1',
          baseSalary: 1000,
          hourlyRate: 100,
          dailyRate: 500,
          expectedDays: 26,
          deductionPerLate: 50,
          otThresholdHours: 8,
          otMultiplier: 1.5,
          fixedBonus: 0,
          attendanceBonus: 0,
          fixedAllowance: 0,
        ),
        const StaffSalaryConfig(
          id: '2',
          storeId: '1',
          userId: 'u2',
          staffName: 'n2',
          role: 'r1',
          salaryMode: 'M1',
          baseSalary: 1000,
          hourlyRate: 100,
          dailyRate: 500,
          expectedDays: 26,
          deductionPerLate: 50,
          otThresholdHours: 8,
          otMultiplier: 1.5,
          fixedBonus: 0,
          attendanceBonus: 0,
          fixedAllowance: 0,
        ),
      ];
      final status = determinePolicyStatus(configs, 3);
      expect(status, PolicyStatus.mixed);
    });

    test('All configs identical and count == total returns synchronized', () {
      final configs = [
        const StaffSalaryConfig(
          id: '1',
          storeId: '1',
          userId: 'u1',
          staffName: 'n1',
          role: 'r1',
          salaryMode: 'M1',
          baseSalary: 1000,
          hourlyRate: 100,
          dailyRate: 500,
          expectedDays: 26,
          deductionPerLate: 50,
          otThresholdHours: 8,
          otMultiplier: 1.5,
          fixedBonus: 0,
          attendanceBonus: 0,
          fixedAllowance: 0,
        ),
        const StaffSalaryConfig(
          id: '2',
          storeId: '1',
          userId: 'u2',
          staffName: 'n2',
          role: 'r1',
          salaryMode: 'M1',
          baseSalary: 1000,
          hourlyRate: 100,
          dailyRate: 500,
          expectedDays: 26,
          deductionPerLate: 50,
          otThresholdHours: 8,
          otMultiplier: 1.5,
          fixedBonus: 0,
          attendanceBonus: 0,
          fixedAllowance: 0,
        ),
      ];
      final status = determinePolicyStatus(configs, 2);
      expect(status, PolicyStatus.synchronized);
    });

    test('Configs differ in one field returns mixed', () {
      final configs = [
        const StaffSalaryConfig(
          id: '1',
          storeId: '1',
          userId: 'u1',
          staffName: 'n1',
          role: 'r1',
          salaryMode: 'M1',
          baseSalary: 1000,
          hourlyRate: 100,
          dailyRate: 500,
          expectedDays: 26,
          deductionPerLate: 50,
          otThresholdHours: 8,
          otMultiplier: 1.5,
          fixedBonus: 0,
          attendanceBonus: 0,
          fixedAllowance: 0,
        ),
        const StaffSalaryConfig(
          id: '2',
          storeId: '1',
          userId: 'u2',
          staffName: 'n2',
          role: 'r1',
          salaryMode: 'M1',
          baseSalary: 1000,
          hourlyRate: 100,
          dailyRate: 500,
          expectedDays: 26,
          deductionPerLate: 50,
          otThresholdHours: 8,
          otMultiplier: 2.0, // Different field
          fixedBonus: 0,
          attendanceBonus: 0,
          fixedAllowance: 0,
        ),
      ];
      final status = determinePolicyStatus(configs, 2);
      expect(status, PolicyStatus.mixed);
    });
  });
}
