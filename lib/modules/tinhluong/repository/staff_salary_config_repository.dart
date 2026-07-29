import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/utils/app_logger.dart';

// ─── Model ───────────────────────────────────────────────────────────────────

class StaffSalaryConfig {
  final String id;
  final String storeId;
  final String userId;
  final String staffName;
  final String role;
  final String salaryMode; // M1 | M2 | M3 | M4
  final double baseSalary;
  final double hourlyRate;
  final double dailyRate;
  final int expectedDays;
  final double deductionPerLate;
  final double otThresholdHours;
  final double otMultiplier;

  const StaffSalaryConfig({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.staffName,
    required this.role,
    required this.salaryMode,
    required this.baseSalary,
    required this.hourlyRate,
    required this.dailyRate,
    required this.expectedDays,
    required this.deductionPerLate,
    required this.otThresholdHours,
    this.otMultiplier = 1.5,
  });

  factory StaffSalaryConfig.fromMap(Map<String, dynamic> m) =>
      StaffSalaryConfig(
        id: m['id'] as String,
        storeId: m['store_id'] as String,
        userId: m['user_id'] as String,
        staffName: m['staff_name'] as String? ?? '',
        role: m['role'] as String? ?? '',
        salaryMode: m['salary_mode'] as String? ?? 'M1',
        baseSalary: (m['base_salary'] as num?)?.toDouble() ?? 0,
        hourlyRate: (m['hourly_rate'] as num?)?.toDouble() ?? 0,
        dailyRate: (m['daily_rate'] as num?)?.toDouble() ?? 0,
        expectedDays: (m['expected_days'] as int?) ?? 26,
        deductionPerLate:
            (m['deduction_per_late'] as num?)?.toDouble() ?? 50000,
        otThresholdHours: (m['ot_threshold_hours'] as num?)?.toDouble() ?? 8.0,
        otMultiplier: (m['ot_multiplier'] as num?)?.toDouble() ?? 1.5,
      );
}

// ─── Repository ──────────────────────────────────────────────────────────────

class StaffSalaryConfigRepo {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'];
  }

  static Future<List<StaffSalaryConfig>> fetchAll() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    try {
      final rows = await _sb
          .from('staff_salary_configs')
          .select()
          .eq('store_id', storeId)
          .order('staff_name');
      return (rows as List)
          .map((r) => StaffSalaryConfig.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SalaryCfg] fetchAll error: $e');
      return [];
    }
  }

  static Future<StaffSalaryConfig?> fetchByUserId(String userId) async {
    final storeId = await _storeId();
    if (storeId == null) return null;
    try {
      final row = await _sb
          .from('staff_salary_configs')
          .select()
          .eq('store_id', storeId)
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) return null;
      return StaffSalaryConfig.fromMap(row);
    } catch (e) {
      debugPrint('[SalaryCfg] fetchByUserId error: $e');
      return null;
    }
  }

  static Future<void> upsert({
    required String userId,
    required String staffName,
    required String role,
    required String salaryMode,
    required double baseSalary,
    required double hourlyRate,
    required double dailyRate,
    required int expectedDays,
    required double deductionPerLate,
    required double otThresholdHours,
    double otMultiplier = 1.5,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('staff_salary_configs').upsert({
      'store_id': storeId,
      'user_id': userId,
      'staff_name': staffName,
      'role': role,
      'salary_mode': salaryMode,
      'base_salary': baseSalary,
      'hourly_rate': hourlyRate,
      'daily_rate': dailyRate,
      'expected_days': expectedDays,
      'deduction_per_late': deductionPerLate,
      'ot_threshold_hours': otThresholdHours,
      'ot_multiplier': otMultiplier,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'store_id,user_id');

    AppLogger.logUserAction(
      tag: 'payroll',
      action: 'Cấu hình lương nhân viên [$staffName]',
      details: {'user_id': userId},
    );
  }
}
