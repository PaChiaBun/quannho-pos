// lib/modules/tinhluong/repository/tinhluong_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/services/staff_service.dart';
import 'staff_salary_config_repository.dart';
import '../../../core/utils/app_logger.dart';
import 'shift_template_repository.dart';
import '../services/payroll_evaluation_service.dart';

// ─── MODELS ──────────────────────────────────────────────────────────────────

class PayrollPeriodModel {
  final String id;
  final String storeId;
  final String name;
  final String periodType; // monthly | biweekly | weekly | custom
  final String fromDate;
  final String toDate;
  final String status; // draft | pending_review | approved | paid
  final double totalAmount;
  final String? note;
  final String? lockedAt;
  final String? paidAt;
  final String createdAt;
  final bool hasDelta;
  final double deltaAmount;

  const PayrollPeriodModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.periodType,
    required this.fromDate,
    required this.toDate,
    required this.status,
    required this.totalAmount,
    this.note,
    this.lockedAt,
    this.paidAt,
    required this.createdAt,
    this.hasDelta = false,
    this.deltaAmount = 0.0,
  });

  bool get isDraft => status == 'draft';
  bool get isPaid => status == 'paid';
  bool get isApproved => status == 'approved';

  factory PayrollPeriodModel.fromMap(Map<String, dynamic> m) =>
      PayrollPeriodModel(
        id: m['id'] as String,
        storeId: m['store_id'] as String,
        name: m['name'] as String,
        periodType: m['period_type'] as String? ?? 'monthly',
        fromDate: (m['from_date'] ?? '').toString(),
        toDate: (m['to_date'] ?? '').toString(),
        status: m['status'] as String? ?? 'draft',
        totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
        note: m['note'] as String?,
        lockedAt: m['locked_at']?.toString(),
        paidAt: m['paid_at']?.toString(),
        createdAt: (m['created_at'] ?? '').toString(),
        hasDelta: m['has_delta'] as bool? ?? false,
        deltaAmount: (m['delta_amount'] as num?)?.toDouble() ?? 0.0,
      );

  PayrollPeriodModel copyWith({
    double? totalAmount,
    bool? hasDelta,
    double? deltaAmount,
  }) => PayrollPeriodModel(
    id: id,
    storeId: storeId,
    name: name,
    periodType: periodType,
    fromDate: fromDate,
    toDate: toDate,
    status: status,
    totalAmount: totalAmount ?? this.totalAmount,
    note: note,
    lockedAt: lockedAt,
    paidAt: paidAt,
    createdAt: createdAt,
    hasDelta: hasDelta ?? this.hasDelta,
    deltaAmount: deltaAmount ?? this.deltaAmount,
  );
}

class PayrollRecordModel {
  final String id;
  final String storeId;
  final String periodId;
  final String userId;
  final String staffName;
  final String? role;
  final String salaryMode; // M1 | M2 | M3 | M4 | M5
  final double baseSalary;
  final double hourlyRate;
  final double totalHours;
  final double overtimeHours;
  final double regularPay;
  final double overtimePay;
  final double bonusRevenue;
  final double bonusManual;
  final double deductionLate;
  final double deductionAbsent;
  final double deductionManual;
  final double allowanceTotal;
  final double grossPay;
  final double netPay;
  final int absentDays;
  final int lateCount;
  final String paymentStatus; // pending | paid | hold
  final String? paymentMethod;
  final String? paidAt;
  final String? note;
  final String createdAt;

  const PayrollRecordModel({
    required this.id,
    required this.storeId,
    required this.periodId,
    required this.userId,
    required this.staffName,
    this.role,
    required this.salaryMode,
    required this.baseSalary,
    required this.hourlyRate,
    required this.totalHours,
    required this.overtimeHours,
    required this.regularPay,
    required this.overtimePay,
    required this.bonusRevenue,
    required this.bonusManual,
    required this.deductionLate,
    required this.deductionAbsent,
    required this.deductionManual,
    required this.allowanceTotal,
    required this.grossPay,
    required this.netPay,
    required this.absentDays,
    required this.lateCount,
    required this.paymentStatus,
    this.paymentMethod,
    this.paidAt,
    this.note,
    required this.createdAt,
  });

  factory PayrollRecordModel.fromMap(Map<String, dynamic> m) =>
      PayrollRecordModel(
        id: m['id'] as String,
        storeId: m['store_id'] as String,
        periodId: m['period_id'] as String,
        userId: m['user_id'] as String,
        staffName: m['staff_name'] as String,
        role: m['role'] as String?,
        salaryMode: m['salary_mode'] as String? ?? 'M1',
        baseSalary: (m['base_salary'] as num?)?.toDouble() ?? 0,
        hourlyRate: (m['hourly_rate'] as num?)?.toDouble() ?? 0,
        totalHours: (m['total_hours'] as num?)?.toDouble() ?? 0,
        overtimeHours: (m['overtime_hours'] as num?)?.toDouble() ?? 0,
        regularPay: (m['regular_pay'] as num?)?.toDouble() ?? 0,
        overtimePay: (m['overtime_pay'] as num?)?.toDouble() ?? 0,
        bonusRevenue: (m['bonus_revenue'] as num?)?.toDouble() ?? 0,
        bonusManual: (m['bonus_manual'] as num?)?.toDouble() ?? 0,
        deductionLate: (m['deduction_late'] as num?)?.toDouble() ?? 0,
        deductionAbsent: (m['deduction_absent'] as num?)?.toDouble() ?? 0,
        deductionManual: (m['deduction_manual'] as num?)?.toDouble() ?? 0,
        allowanceTotal: (m['allowance_total'] as num?)?.toDouble() ?? 0,
        grossPay: (m['gross_pay'] as num?)?.toDouble() ?? 0,
        netPay: (m['net_pay'] as num?)?.toDouble() ?? 0,
        absentDays: (m['absent_days'] as num?)?.toInt() ?? 0,
        lateCount: (m['late_count'] as num?)?.toInt() ?? 0,
        paymentStatus: m['payment_status'] as String? ?? 'pending',
        paymentMethod: m['payment_method'] as String?,
        paidAt: m['paid_at'] as String?,
        note: m['note'] as String?,
        createdAt: m['created_at'] as String? ?? '',
      );
}

class PayrollEvaluationResult {
  final String status;
  final double resolvedTotal;
  final double storedTotal;
  final double liveTotal;
  final bool hasDelta;
  final double deltaAmount;
  final List<PayrollRecordModel> records;

  const PayrollEvaluationResult({
    required this.status,
    required this.resolvedTotal,
    required this.storedTotal,
    required this.liveTotal,
    required this.hasDelta,
    required this.deltaAmount,
    required this.records,
  });
}

class PayrollItemModel {
  final String id;
  final String storeId;
  final String recordId;
  final String itemType; // bonus | deduction | allowance | overtime
  final String label;
  final double amount;
  final bool isAuto;
  final String? note;

  const PayrollItemModel({
    required this.id,
    required this.storeId,
    required this.recordId,
    required this.itemType,
    required this.label,
    required this.amount,
    required this.isAuto,
    this.note,
  });

  factory PayrollItemModel.fromMap(Map<String, dynamic> m) => PayrollItemModel(
    id: m['id'] as String,
    storeId: m['store_id'] as String,
    recordId: m['record_id'] as String,
    itemType: m['item_type'] as String,
    label: m['label'] as String,
    amount: (m['amount'] as num).toDouble(),
    isAuto: m['is_auto'] as bool? ?? false,
    note: m['note'] as String?,
  );
}

/// Input để engine tính lương 1 nhân viên
class PayrollInput {
  final String userId;
  final String staffName;
  final String? role;
  final String salaryMode; // M1 | M2 | M3 | M4 | M5
  final double baseSalary;
  final double hourlyRate;
  final double dailyRate;
  final int expectedDays;
  final double totalHours;
  final double overtimeHours;
  final double workDays; // số ngày làm unique (cho M4)
  final int absentDays;
  final int lateCount;
  final double deductionPerLate; // VD: 50000đ/lần trễ
  final double deductionPerAbsent; // VD: lương/26 ngày
  final double bonusRevenue;
  final double bonusManual;
  final double deductionManual;
  final double otMultiplier; // Hệ số OT: 1.5 (mặc định), 2.0 (ngày lễ), v.v.
  final List<PayrollItemModel> extraItems;

  const PayrollInput({
    required this.userId,
    required this.staffName,
    this.role,
    required this.salaryMode,
    required this.baseSalary,
    required this.hourlyRate,
    this.dailyRate = 0,
    this.expectedDays = 26,
    required this.totalHours,
    required this.overtimeHours,
    this.workDays = 0,
    required this.absentDays,
    required this.lateCount,
    required this.deductionPerLate,
    required this.deductionPerAbsent,
    required this.bonusRevenue,
    required this.bonusManual,
    required this.deductionManual,
    this.otMultiplier = 1.5, // Mặc định 1.5x theo luật lao động VN
    this.extraItems = const [],
  });
}

/// Kết quả tính lương 1 nhân viên
class PayrollCalcResult {
  final double regularPay;
  final double overtimePay;
  final double deductionLate;
  final double deductionAbsent;
  final double grossPay;
  final double netPay;

  const PayrollCalcResult({
    required this.regularPay,
    required this.overtimePay,
    required this.deductionLate,
    required this.deductionAbsent,
    required this.grossPay,
    required this.netPay,
  });
}

class PayrollReadiness {
  final int missingSalaryConfigCount;
  final int unclosedShiftCount;
  final int pendingOtCount;
  final List<String> blockingReasons;
  final bool hasError;

  bool get canSubmit =>
      !hasError &&
      missingSalaryConfigCount == 0 &&
      unclosedShiftCount == 0 &&
      pendingOtCount == 0;

  const PayrollReadiness({
    required this.missingSalaryConfigCount,
    required this.unclosedShiftCount,
    required this.pendingOtCount,
    required this.blockingReasons,
    this.hasError = false,
  });
}

bool canSubmitPayroll(PayrollReadiness? readiness) =>
    readiness?.canSubmit ?? false;

// ─── ENGINE ──────────────────────────────────────────────────────────────────

PayrollCalcResult calculatePayroll(PayrollInput input) {
  double regularPay = 0;
  double overtimePay = 0;

  switch (input.salaryMode) {
    case 'M1': // Theo giờ
      regularPay = (input.totalHours - input.overtimeHours) * input.hourlyRate;
      overtimePay = input.overtimeHours * input.hourlyRate * input.otMultiplier;
      break;
    case 'M2': // Lương cố định tháng
      regularPay = input.baseSalary;
      overtimePay =
          input.overtimeHours *
          (input.baseSalary / 26 / 8) *
          input.otMultiplier;
      break;
    case 'M3': // Cố định + theo giờ OT
      regularPay = input.baseSalary;
      overtimePay = input.overtimeHours * input.hourlyRate * input.otMultiplier;
      break;
    case 'M4': // Theo ngày
      final effectiveDailyRate = input.dailyRate > 0
          ? input.dailyRate
          : input.baseSalary;
      regularPay = input.workDays * effectiveDailyRate;
      overtimePay =
          input.overtimeHours * (effectiveDailyRate / 8) * input.otMultiplier;
      break;
    case 'M5': // Tùy chỉnh: cộng các thành phần có giá trị
      regularPay =
          input.baseSalary +
          (input.totalHours - input.overtimeHours) * input.hourlyRate +
          input.workDays * input.dailyRate;
      final customOtRate = input.hourlyRate > 0
          ? input.hourlyRate
          : (input.dailyRate > 0
                ? input.dailyRate / 8
                : input.baseSalary / input.expectedDays / 8);
      overtimePay = input.overtimeHours * customOtRate * input.otMultiplier;
      break;
    default:
      regularPay = input.baseSalary;
  }
  if (regularPay < 0) regularPay = 0;

  final deductionLate = input.lateCount * input.deductionPerLate;
  final deductionAbsent = input.absentDays * input.deductionPerAbsent;

  final extraBonus = input.extraItems
      .where((i) => i.itemType == 'bonus' || i.itemType == 'allowance')
      .fold(0.0, (s, i) => s + i.amount);
  final extraDeduct = input.extraItems
      .where((i) => i.itemType == 'deduction')
      .fold(0.0, (s, i) => s + i.amount);

  final grossPay =
      regularPay +
      overtimePay +
      input.bonusRevenue +
      input.bonusManual +
      extraBonus -
      deductionLate -
      deductionAbsent -
      input.deductionManual -
      extraDeduct;

  final netPay = grossPay < 0 ? 0.0 : grossPay;

  return PayrollCalcResult(
    regularPay: regularPay,
    overtimePay: overtimePay,
    deductionLate: deductionLate,
    deductionAbsent: deductionAbsent,
    grossPay: grossPay,
    netPay: netPay,
  );
}

// ─── REPOSITORY ──────────────────────────────────────────────────────────────

class CreatePeriodResult {
  final PayrollPeriodModel? period;
  final String? error;
  bool get isSuccess => period != null;

  CreatePeriodResult.success(this.period) : error = null;
  CreatePeriodResult.failure(this.error) : period = null;
}

class TinhLuongRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  static const _uuid = Uuid();

  static Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'];
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYROLL PERIODS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<double> autoGenerateRecordsForPeriod({
    required String periodId,
    required String storeId,
    required String fromDateStr,
    required String toDateStr,
  }) async {
    await _guardPeriodByPeriodId(periodId);
    try {
      final periodRow = await _sb
          .from('payroll_periods')
          .select('status, total_amount')
          .eq('store_id', storeId)
          .eq('id', periodId)
          .maybeSingle();

      final status = periodRow?['status'] as String? ?? 'draft';

      final evaluation = await PayrollEvaluationService.evaluatePeriod(
        storeId: storeId,
        periodId: periodId,
        fromDateStr: fromDateStr,
        toDateStr: toDateStr,
        status: status,
      );

      if (status == 'approved' || status == 'paid') {
        debugPrint(
          '[TinhLuong] autoGenerateRecordsForPeriod bị từ chối do kỳ đã lock: $status',
        );
        return (periodRow?['total_amount'] as num?)?.toDouble() ?? 0.0;
      }

      for (final rec in evaluation.records) {
        await _sb.from('payroll_records').upsert({
          'id': rec.id,
          'store_id': rec.storeId,
          'period_id': rec.periodId,
          'user_id': rec.userId,
          'staff_name': rec.staffName,
          'role': rec.role,
          'salary_mode': rec.salaryMode,
          'base_salary': rec.baseSalary,
          'hourly_rate': rec.hourlyRate,
          'total_hours': rec.totalHours,
          'overtime_hours': rec.overtimeHours,
          'regular_pay': rec.regularPay,
          'overtime_pay': rec.overtimePay,
          'bonus_revenue': rec.bonusRevenue,
          'bonus_manual': rec.bonusManual,
          'deduction_late': rec.deductionLate,
          'deduction_absent': rec.deductionAbsent,
          'deduction_manual': rec.deductionManual,
          'allowance_total': rec.allowanceTotal,
          'gross_pay': rec.grossPay,
          'net_pay': rec.netPay,
          'absent_days': rec.absentDays,
          'late_count': rec.lateCount,
          'payment_status': rec.paymentStatus,
          'created_at': rec.createdAt,
        });
      }

      await _sb
          .from('payroll_periods')
          .update({'total_amount': evaluation.resolvedTotal})
          .eq('store_id', storeId)
          .eq('id', periodId);

      AppLogger.logUserAction(
        tag: 'payroll',
        action: 'Tổng hợp dữ liệu kỳ lương',
        details: {
          'period_id': periodId,
          'record_count': evaluation.records.length,
        },
      );

      return evaluation.resolvedTotal;
    } catch (e) {
      debugPrint('[TinhLuong] autoGenerateRecordsForPeriod error: $e');
      throw Exception('Lỗi khi tạo dữ liệu lương: $e');
    }
  }

  static Future<List<PayrollPeriodModel>> fetchPeriods() async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    final rows = await _sb
        .from('payroll_periods')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false);
    final periods = (rows as List)
        .map((r) => PayrollPeriodModel.fromMap(r as Map<String, dynamic>))
        .toList();

    if (periods.isEmpty) return [];

    final List<PayrollPeriodModel> corrected = [];

    for (final p in periods) {
      if (p.status == 'draft' || p.status == 'pending_review') {
        try {
          final evaluation = await PayrollEvaluationService.evaluatePeriod(
            storeId: storeId,
            periodId: p.id,
            fromDateStr: p.fromDate,
            toDateStr: p.toDate,
            status: p.status,
          );
          corrected.add(
            p.copyWith(
              totalAmount: evaluation.resolvedTotal,
              hasDelta: evaluation.hasDelta,
              deltaAmount: evaluation.deltaAmount,
            ),
          );
        } catch (e) {
          // Danh sách kỳ lương phải luôn tải được nếu query gốc thành công.
          // Live evaluation chỉ là dữ liệu bổ sung; một kỳ chưa sẵn sàng
          // không được làm hỏng toàn bộ màn tổng quan.
          debugPrint(
            '[TinhLuong] Bỏ qua live evaluation kỳ ${p.id}, '
            'dùng snapshot đã lưu: $e',
          );
          corrected.add(p);
        }
      } else {
        corrected.add(p);
      }
    }

    return corrected;
  }

  static Future<CreatePeriodResult> createPeriodWithResult({
    required String name,
    required String fromDate,
    required String toDate,
    String periodType = 'monthly',
    String? note,
    String? createdBy,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) {
      return CreatePeriodResult.failure('Chưa xác định Store ID cửa hàng');
    }
    try {
      final res = await _sb
          .from('payroll_periods')
          .insert({
            'id': _uuid.v4(),
            'store_id': storeId,
            'name': name,
            'period_type': periodType,
            'from_date': fromDate,
            'to_date': toDate,
            'status': 'draft',
            'note': note,
            'created_by': createdBy,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .maybeSingle();

      if (res == null) {
        return CreatePeriodResult.failure('Dữ liệu trả về rỗng từ máy chủ');
      }
      final createdPeriod = PayrollPeriodModel.fromMap(res);

      // Tự động tính toán & tạo chi tiết lương từng nhân viên cho kỳ vừa tạo
      final totalNet = await autoGenerateRecordsForPeriod(
        periodId: createdPeriod.id,
        storeId: storeId,
        fromDateStr: fromDate,
        toDateStr: toDate,
      );

      AppLogger.logUserAction(
        tag: 'payroll',
        action: 'Tạo kỳ lương mới [$name]',
        details: {'period_id': createdPeriod.id},
      );

      return CreatePeriodResult.success(
        createdPeriod.copyWith(totalAmount: totalNet),
      );
    } catch (e) {
      debugPrint('[TinhLuong] createPeriod error: $e');
      return CreatePeriodResult.failure(e.toString());
    }
  }

  static Future<PayrollPeriodModel?> createPeriod({
    required String name,
    required String fromDate,
    required String toDate,
    String periodType = 'monthly',
    String? note,
    String? createdBy,
  }) async {
    final result = await createPeriodWithResult(
      name: name,
      fromDate: fromDate,
      toDate: toDate,
      periodType: periodType,
      note: note,
      createdBy: createdBy,
    );
    return result.period;
  }

  static Future<void> updatePeriodStatus(String id, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'approved' || status == 'paid') {
      updates['locked_at'] = DateTime.now().toUtc().toIso8601String();
    }
    if (status == 'paid') {
      updates['paid_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _sb.from('payroll_periods').update(updates).eq('id', id);

    AppLogger.logUserAction(
      tag: 'payroll',
      action: 'Cập nhật trạng thái kỳ lương [$status]',
      details: {'period_id': id, 'new_status': status},
    );
  }

  static Future<void> updatePeriodTotal(String id, double total) async {
    await _guardPeriodByPeriodId(id);
    await _sb
        .from('payroll_periods')
        .update({'total_amount': total})
        .eq('id', id);
  }

  static Future<PayrollReadiness> evaluateReadiness({
    required String storeId,
    required String fromDateStr,
    required String toDateStr,
  }) async {
    try {
      final fromParts = fromDateStr.split('-').map(int.parse).toList();
      final toParts = toDateStr.split('-').map(int.parse).toList();
      final fromIso = DateTime(
        fromParts[0],
        fromParts[1],
        fromParts[2],
        0,
        0,
        0,
      ).toUtc().toIso8601String();
      final toIso = DateTime(
        toParts[0],
        toParts[1],
        toParts[2],
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      // Fetch all shifts in the period
      final shiftsRows = await _sb
          .from('staff_shifts')
          .select('*')
          .eq('store_id', storeId)
          .gte('clock_in', fromIso)
          .lte('clock_in', toIso);

      // Fetch all configs
      final configs = await StaffSalaryConfigRepo.fetchAll();
      final configMap = {for (var c in configs) c.userId: c};

      int unclosedShiftCount = 0;
      int pendingOtCount = 0;
      final usersWithShifts = <String>{};

      for (final r in shiftsRows as List) {
        final m = r as Map<String, dynamic>;
        final uid = m['user_id'] as String? ?? '';
        if (uid.isNotEmpty) usersWithShifts.add(uid);

        if (m['clock_out'] == null) {
          unclosedShiftCount++;
          continue;
        }

        final shift = ShiftRecord(
          id: m['id'] as String,
          userId: uid,
          userName: 'NV',
          clockIn: DateTime.parse(m['clock_in'] as String),
          clockOut: DateTime.parse(m['clock_out'] as String),
          source: m['source'] as String? ?? 'app',
          note: m['note'] as String? ?? '',
          isOtApproved: m['is_ot_approved'] as bool? ?? false,
          isForgotClockout: m['is_forgot_clockout'] as bool? ?? false,
          isManagerOverridden: m['is_manager_overridden'] as bool? ?? false,
        );

        final cfg = configMap[uid];
        final calc = calculateSingleShiftEarnings(shift: shift, config: cfg);

        if (!shift.isOtApproved && calc.overtimeHours > 0) {
          pendingOtCount++;
        }

        if (shift.checkIsForgotClockout && !shift.isManagerOverridden) {
          unclosedShiftCount++; // Quên chốt ca coi như unclosed
        }
      }

      int missingSalaryConfigCount = 0;
      for (final uid in usersWithShifts) {
        if (!configMap.containsKey(uid)) {
          missingSalaryConfigCount++;
        }
      }

      final blockingReasons = <String>[];
      if (missingSalaryConfigCount > 0) {
        blockingReasons.add(
          '$missingSalaryConfigCount nhân viên chưa được cấu hình lương',
        );
      }
      if (unclosedShiftCount > 0) {
        blockingReasons.add(
          '$unclosedShiftCount ca làm chưa chốt hoặc quên chốt ca',
        );
      }
      if (pendingOtCount > 0) {
        blockingReasons.add('$pendingOtCount ca làm có OT đang chờ duyệt');
      }

      return PayrollReadiness(
        missingSalaryConfigCount: missingSalaryConfigCount,
        unclosedShiftCount: unclosedShiftCount,
        pendingOtCount: pendingOtCount,
        blockingReasons: blockingReasons,
      );
    } catch (e) {
      debugPrint('[TinhLuong] evaluateReadiness error: $e');
      return const PayrollReadiness(
        missingSalaryConfigCount: 0,
        unclosedShiftCount: 0,
        pendingOtCount: 0,
        blockingReasons: [
          'Lỗi kiểm tra dữ liệu, không thể tính toán trạng thái',
        ],
        hasError: true,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYROLL RECORDS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<PayrollRecordModel>> fetchRecords(String periodId) async {
    final periodRow = await _sb
        .from('payroll_periods')
        .select()
        .eq('id', periodId)
        .maybeSingle();
    if (periodRow == null) throw Exception('Không tìm thấy kỳ lương $periodId');

    final status = periodRow['status'] as String? ?? 'draft';

    if (status == 'draft' || status == 'pending_review') {
      final storeId = await _storeId();
      if (storeId == null) {
        throw Exception('Không xác định được cửa hàng (storeId = null)');
      }

      final eval = await PayrollEvaluationService.evaluatePeriod(
        storeId: storeId,
        periodId: periodId,
        fromDateStr: periodRow['from_date'],
        toDateStr: periodRow['to_date'],
        status: status,
      );
      return eval.records;
    } else {
      final rows = await _sb
          .from('payroll_records')
          .select()
          .eq('period_id', periodId)
          .order('staff_name');
      return (rows as List)
          .map((r) => PayrollRecordModel.fromMap(r as Map<String, dynamic>))
          .toList();
    }
  }

  static Future<PayrollRecordModel?> fetchRecordById(String id) async {
    try {
      // ‼️ FIX Bug #22: .single() throw nếu không có row → maybeSingle() an toàn hơn
      final row = await _sb
          .from('payroll_records')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return PayrollRecordModel.fromMap(row);
    } catch (e) {
      debugPrint('[TinhLuong] fetchRecordById error: $e');
      return null;
    }
  }

  /// Tạo hoặc cập nhật record 1 nhân viên
  static Future<String?> upsertRecord({
    required String periodId,
    required PayrollInput input,
  }) async {
    await _guardPeriodByPeriodId(periodId);
    final storeId = await _storeId();
    if (storeId == null) return null;

    final calc = calculatePayroll(input);
    final now = DateTime.now().toUtc().toIso8601String();

    final allowanceTotal = input.extraItems
        .where((i) => i.itemType == 'allowance')
        .fold(0.0, (s, i) => s + i.amount);

    try {
      // ‼️ FIX BUG #16: guard — không đè lên record đã chốt hoặc chờ duyệt
      final existing = await _sb
          .from('payroll_records')
          .select('id, payment_status, created_at')
          .eq('period_id', periodId)
          .eq('user_id', input.userId)
          .maybeSingle();

      if (existing != null) {
        final st = existing['payment_status'] as String?;
        if (st == 'paid' || st == 'pending_staff_confirm') {
          debugPrint(
            '[TinhLuong] upsertRecord: bỏ qua ${input.staffName} — record đang bị lock: $st',
          );
          return existing['id'] as String;
        }
      }

      final recId = existing != null ? (existing['id'] as String) : _uuid.v4();
      final status = existing != null
          ? (existing['payment_status'] as String? ?? 'pending')
          : 'pending';
      final createdAt = existing != null
          ? (existing['created_at'] as String? ?? now)
          : now;

      final newRow = {
        'id': recId,
        'store_id': storeId,
        'period_id': periodId,
        'user_id': input.userId,
        'staff_name': input.staffName,
        'role': input.role,
        'salary_mode': input.salaryMode,
        'base_salary': input.baseSalary,
        'hourly_rate': input.hourlyRate,
        'total_hours': input.totalHours,
        'overtime_hours': input.overtimeHours,
        'regular_pay': calc.regularPay,
        'overtime_pay': calc.overtimePay,
        'bonus_revenue': input.bonusRevenue,
        'bonus_manual': input.bonusManual,
        'deduction_late': calc.deductionLate,
        'deduction_absent': calc.deductionAbsent,
        'deduction_manual': input.deductionManual,
        'allowance_total': allowanceTotal,
        'gross_pay': calc.grossPay,
        'net_pay': calc.netPay,
        'absent_days': input.absentDays,
        'late_count': input.lateCount,
        'payment_status': status,
        'created_at': createdAt,
      };

      // Dùng upsert với ID hiện tại (nếu có) để đảm bảo tính idempotent tuyệt đối (period_id + user_id)
      await _sb.from('payroll_records').upsert(newRow);

      AppLogger.logUserAction(
        tag: 'payroll',
        action: 'Cập nhật bản ghi lương [NV: ${input.staffName}]',
        details: {
          'record_id': recId,
          'user_id': input.userId,
          'period_id': periodId,
        },
      );

      return recId;
    } catch (e) {
      debugPrint('[TinhLuong] upsertRecord error: $e');
      return null;
    }
  }

  static Future<void> markRecordPaid({
    required String id,
    required String paymentMethod,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb
        .from('payroll_records')
        .update({
          'payment_status': 'pending_staff_confirm',
          'payment_method': paymentMethod,
          'paid_at': now,
        })
        .eq('id', id);

    AppLogger.logUserAction(
      tag: 'payroll',
      action: 'Thanh toán lương cá nhân',
      details: {'record_id': id},
    );
  }

  static Future<void> confirmStaffPaid({
    required String id,
    required String staffName,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      await _sb
          .from('payroll_records')
          .update({'payment_status': 'paid'})
          .eq('id', id);

      final record = await fetchRecordById(id);
      final storeId = record?.storeId ?? '';

      await _sb.from('app_logs').insert({
        'store_id': storeId,
        'device_id': 'POS_APP',
        'staff_name': staffName,
        'level': 'INFO',
        'tag': 'PAYROLL_STAFF_CONFIRM',
        'message': 'Nhân viên $staffName xác nhận đã nhận đủ lương',
        'details': 'Record ID: $id | Mức lương: ${record?.netPay}đ',
        'created_at': now,
      });
    } catch (e) {
      debugPrint('[TinhLuong] confirmStaffPaid error: $e');
    }
  }

  static Future<void> _guardPeriodByPeriodId(String periodId) async {
    final periodRow = await _sb
        .from('payroll_periods')
        .select('status')
        .eq('id', periodId)
        .maybeSingle();
    if (periodRow == null) throw Exception('Không tìm thấy kỳ lương');
    final status = periodRow['status'] as String?;
    if (status == 'approved' || status == 'paid') {
      throw Exception(
        'Không thể thay đổi dữ liệu vì kỳ lương đã được duyệt hoặc chi trả.',
      );
    }
  }

  static Future<void> _guardPeriodByRecordId(String recordId) async {
    final recordRow = await _sb
        .from('payroll_records')
        .select('period_id')
        .eq('id', recordId)
        .maybeSingle();
    if (recordRow == null) throw Exception('Không tìm thấy bản ghi lương');
    final periodId = recordRow['period_id'] as String?;
    if (periodId != null) {
      await _guardPeriodByPeriodId(periodId);
    }
  }

  static Future<void> updateRecordNote(String id, String note) async {
    await _guardPeriodByRecordId(id);
    await _sb.from('payroll_records').update({'note': note}).eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYROLL ITEMS (khoản thưởng/khấu trừ chi tiết)
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<PayrollItemModel>> fetchItems(String recordId) async {
    try {
      final rows = await _sb
          .from('payroll_items')
          .select()
          .eq('record_id', recordId)
          .order('created_at');
      return (rows as List)
          .map((r) => PayrollItemModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TinhLuong] fetchItems error: $e');
      return [];
    }
  }

  static Future<void> addItem({
    required String recordId,
    required String itemType,
    required String label,
    required double amount,
    bool isAuto = false,
    String? note,
  }) async {
    await _guardPeriodByRecordId(recordId);
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('payroll_items').insert({
      'id': _uuid.v4(),
      'store_id': storeId,
      'record_id': recordId,
      'item_type': itemType,
      'label': label,
      'amount': amount,
      'is_auto': isAuto,
      'note': note,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    // ‼️ FIX Bug #20: sync lại net_pay vào payroll_records sau khi thêm item
    await _recalcNetPay(recordId);
  }

  static Future<void> deleteItem(String id) async {
    // Lấy record_id trước khi xoá
    final row = await _sb
        .from('payroll_items')
        .select('record_id')
        .eq('id', id)
        .maybeSingle();
    final recordId = row?['record_id'] as String?;
    if (recordId != null) await _guardPeriodByRecordId(recordId);

    await _sb.from('payroll_items').delete().eq('id', id);
    // ‼️ FIX Bug #20: sync lại net_pay sau khi xoá item
    if (recordId != null) await _recalcNetPay(recordId);
  }

  /// Tính lại net_pay từ tổng items + base record rồi update DB
  static Future<void> _recalcNetPay(String recordId) async {
    await _guardPeriodByRecordId(recordId);
    try {
      final row = await _sb
          .from('payroll_records')
          .select()
          .eq('id', recordId)
          .maybeSingle();
      if (row == null) return;
      final items = await fetchItems(recordId);

      final extraBonus = items
          .where((i) => i.itemType == 'bonus' || i.itemType == 'allowance')
          .fold(0.0, (s, i) => s + i.amount);
      final extraDeduct = items
          .where((i) => i.itemType == 'deduction')
          .fold(0.0, (s, i) => s + i.amount);

      final regularPay = (row['regular_pay'] as num?)?.toDouble() ?? 0;
      final overtimePay = (row['overtime_pay'] as num?)?.toDouble() ?? 0;
      final bonusRevenue = (row['bonus_revenue'] as num?)?.toDouble() ?? 0;
      final bonusManual = (row['bonus_manual'] as num?)?.toDouble() ?? 0;
      final deductionLate = (row['deduction_late'] as num?)?.toDouble() ?? 0;
      final deductionAbsent =
          (row['deduction_absent'] as num?)?.toDouble() ?? 0;
      final deductionManual =
          (row['deduction_manual'] as num?)?.toDouble() ?? 0;

      final grossPay =
          regularPay +
          overtimePay +
          bonusRevenue +
          bonusManual +
          extraBonus -
          deductionLate -
          deductionAbsent -
          deductionManual -
          extraDeduct;
      final netPay = grossPay < 0 ? 0.0 : grossPay;

      await _sb
          .from('payroll_records')
          .update({
            'allowance_total': extraBonus, // items bonus+allowance
            'gross_pay': grossPay,
            'net_pay': netPay,
          })
          .eq('id', recordId);

      // ‼️ FIX: sync total_amount của period → TinhLuongScreen card luôn đúng
      final periodId = row['period_id'] as String?;
      if (periodId != null) {
        final allRecords = await _sb
            .from('payroll_records')
            .select('net_pay')
            .eq('period_id', periodId);
        final periodTotal = (allRecords as List).fold(
          0.0,
          (s, r) => s + ((r as Map)['net_pay'] as num? ?? 0).toDouble(),
        );
        await updatePeriodTotal(periodId, periodTotal);
      }
    } catch (e) {
      debugPrint('[TinhLuong] _recalcNetPay error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AUTO-GENERATE: Tổng hợp dữ liệu chấm công → tính lương tự động
  // ═══════════════════════════════════════════════════════════════════════════

  /// Lấy dữ liệu giờ làm của tất cả NV trong kỳ từ staff_shifts
  static Future<Map<String, StaffShiftSummary>> aggregateShifts({
    required String storeId,
    required DateTime from,
    required DateTime to,
    double otThresholdHours = 8.0,
  }) async {
    try {
      // ‼️ FIX Timezone: fromDate/toDate là "2025-05-01" (local VN date string)
      // DateTime.parse → local → .toUtc() sẽ đúng trên device UTC+7,
      // nhưng sẽ sai trên device UTC (server build). Cách an toàn nhất:
      // dùng DateTime.utc từ date parts rồi trừ 7h → midnight VN = UTC-7h
      final fromUtc = DateTime.utc(
        from.year,
        from.month,
        from.day,
      ).subtract(const Duration(hours: 7)); // 2025-05-01 VN midnight
      final toUtc = DateTime.utc(
        to.year,
        to.month,
        to.day,
      ).subtract(const Duration(hours: 7)); // exclusive upper bound

      final rows = await _sb
          .from('staff_shifts')
          .select('user_id, clock_in, clock_out, is_late, late_minutes')
          .eq('store_id', storeId)
          .gte('clock_in', fromUtc.toIso8601String())
          .lt('clock_in', toUtc.toIso8601String())
          .not('clock_out', 'is', null);

      if ((rows as List).isEmpty) return {};

      // ‼️ FIX: lấy tên NV từ user_accounts riêng (staff_shifts không có cột staff_name)
      final userIds = rows
          .map((r) => (r as Map)['user_id'] as String)
          .toSet()
          .toList();
      final Map<String, String> nameMap = {};
      try {
        final users = await _sb
            .from('user_accounts')
            .select('id, display_name')
            .inFilter('id', userIds);
        for (final u in users) {
          nameMap[(u as Map)['id'] as String] =
              u['display_name'] as String? ?? '';
        }
      } catch (_) {}

      final Map<String, StaffShiftSummary> result = {};
      // ‼️ FIX: track unique work-days để tính absentDays đúng
      final Map<String, Set<String>> workDaysByUser = {};

      for (final row in rows) {
        final r = row;
        final userId = r['user_id'] as String;
        // is_late/late_minutes: cột mới thêm, dùng null-safe
        final isLate = (r['is_late'] as bool?) ?? false;
        final lateMin = (r['late_minutes'] as num?)?.toInt() ?? 0;
        final clockIn = DateTime.parse(r['clock_in'] as String).toLocal();
        final clockOut = DateTime.parse(r['clock_out'] as String).toLocal();
        final hours = clockOut.difference(clockIn).inMinutes / 60.0;
        // Ngày làm duy nhất (local date string)
        final dateStr =
            '${clockIn.year}-${clockIn.month.toString().padLeft(2, '0')}-${clockIn.day.toString().padLeft(2, '0')}';

        final name = nameMap[userId] ?? '';
        final s = result.putIfAbsent(
          userId,
          () => StaffShiftSummary(userId: userId, staffName: name),
        );
        workDaysByUser.putIfAbsent(userId, () => {}).add(dateStr);

        s.totalHours += hours;
        if (isLate) s.lateCount++;
        if (lateMin > 0) s.totalLateMinutes += lateMin;
        // OT: giờ vượt ngưỡng trong ngày
        if (hours > otThresholdHours) {
          s.overtimeHours += (hours - otThresholdHours);
        }
      }

      // Gán workDays từ số ngày unique
      for (final entry in workDaysByUser.entries) {
        if (result.containsKey(entry.key)) {
          result[entry.key]!.workDays = entry.value.length.toDouble();
        }
      }

      return result;
    } catch (e) {
      debugPrint('[TinhLuong] aggregateShifts error: $e');
      return {};
    }
  }

  /// ‼️ FIX BUG: Fetch raw shift rows 1 lần, nhóm theo userId — tránh N HTTP requests.
  static Future<Map<String, List<Map<String, dynamic>>>> _fetchRawShiftRows({
    required String storeId,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromUtc = DateTime.utc(
      from.year,
      from.month,
      from.day,
    ).subtract(const Duration(hours: 7));
    final toUtc = DateTime.utc(
      to.year,
      to.month,
      to.day,
    ).subtract(const Duration(hours: 7));
    try {
      final rows = await _sb
          .from('staff_shifts')
          .select('user_id, clock_in, clock_out, is_late, late_minutes')
          .eq('store_id', storeId)
          .gte('clock_in', fromUtc.toIso8601String())
          .lt('clock_in', toUtc.toIso8601String())
          .not('clock_out', 'is', null);
      final Map<String, List<Map<String, dynamic>>> result = {};
      for (final row in rows as List) {
        final r = row as Map<String, dynamic>;
        final uid = r['user_id'] as String;
        result.putIfAbsent(uid, () => []).add(r);
      }
      return result;
    } catch (e) {
      debugPrint('[TinhLuong] _fetchRawShiftRows error: $e');
      return {};
    }
  }

  /// Tổng hợp StaffShiftSummary của 1 NV từ raw rows với otThresholdHours riêng.
  static StaffShiftSummary _aggregateOneUser({
    required String userId,
    required String staffName,
    required List<Map<String, dynamic>> rows,
    required double otThresholdHours,
  }) {
    final s = StaffShiftSummary(userId: userId, staffName: staffName);
    final workDays = <String>{};
    for (final r in rows) {
      final isLate = (r['is_late'] as bool?) ?? false;
      final lateMin = (r['late_minutes'] as num?)?.toInt() ?? 0;
      final clockIn = DateTime.parse(r['clock_in'] as String).toLocal();
      final clockOut = DateTime.parse(r['clock_out'] as String).toLocal();
      final hours = clockOut.difference(clockIn).inMinutes / 60.0;
      final dateStr =
          '${clockIn.year}-'
          '${clockIn.month.toString().padLeft(2, '0')}-'
          '${clockIn.day.toString().padLeft(2, '0')}';
      workDays.add(dateStr);
      s.totalHours += hours;
      if (isLate) s.lateCount++;
      if (lateMin > 0) s.totalLateMinutes += lateMin;
      if (hours > otThresholdHours) {
        s.overtimeHours += (hours - otThresholdHours);
      }
    }
    s.workDays = workDays.length.toDouble();
    return s;
  }

  /// Generate toàn bộ payroll records cho 1 kỳ (gọi sau khi user bấm "Tạo bảng lương")
  /// staffConfigs: map userId → config lương (mode, base, hourly, v.v.)
  static Future<int> generatePeriodRecords({
    required String periodId,
    required String fromDate,
    required String toDate,
    required Map<String, StaffPayConfig> staffConfigs,
    // ‼️ Bug #26 fix: global defaults chỉ dùng khi StaffPayConfig không có per-staff value
    double deductionPerAbsent = 0, // global override (0 = tự tính theo mode)
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return 0;

    final from = DateTime.parse(fromDate);
    final to = DateTime.parse(toDate).add(const Duration(days: 1));

    // ‼️ FIX BUG #1: Fetch raw shifts 1 lần — tránh N HTTP requests (1 per staff)
    final rawRows = await _fetchRawShiftRows(
      storeId: storeId,
      from: from,
      to: to,
    );

    int count = 0;
    for (final entry in staffConfigs.entries) {
      final userId = entry.key;
      final config = entry.value;

      // Aggregate per-staff với otThreshold riêng — từ raw rows đã có sẵn trong RAM
      final userRows = rawRows[userId] ?? [];
      final shift = userRows.isEmpty
          ? null
          : _aggregateOneUser(
              userId: userId,
              staffName: config.staffName,
              rows: userRows,
              otThresholdHours: config.otThresholdHours,
            );

      // ‼️ FIX Bug #27: deductionPerAbsent theo mode
      // M1: 0 (không tính vào), M2: lương/26, M3: lương/26, M4: dailyRate (= baseSalary)
      final effectiveAbsent = deductionPerAbsent > 0
          ? deductionPerAbsent
          : switch (config.salaryMode) {
              'M2' => config.baseSalary / 26,
              'M3' => config.baseSalary / 26,
              'M4' =>
                config.baseSalary, // baseSalary đã = dailyRate sau mapping
              _ => 0.0,
            };

      final input = PayrollInput(
        userId: userId,
        staffName: config.staffName,
        role: config.role,
        salaryMode: config.salaryMode,
        baseSalary: config.baseSalary,
        hourlyRate: config.hourlyRate,
        dailyRate: config.dailyRate,
        expectedDays: config.expectedDays,
        totalHours: shift?.totalHours ?? 0,
        overtimeHours: shift?.overtimeHours ?? 0,
        workDays: shift?.workDays ?? 0,
        absentDays: (() {
          // ‼️ FIX BUG #14: nếu không có ca nào (shift=null)
          // → KHÔNG tính absent — NV có thể mới onboard hoặc nghỉ có phép
          // Manager có thể điều chỉnh thủ công qua items
          if (shift == null) return 0;
          final worked = shift.workDays.round();
          final absent = config.expectedDays - worked;
          return absent < 0 ? 0 : absent;
        })(),
        lateCount: shift?.lateCount ?? 0,
        deductionPerLate: config.deductionPerLate, // ‼️ Bug #26 fix: per-staff
        deductionPerAbsent: effectiveAbsent,
        bonusRevenue: config.bonusRevenue,
        bonusManual: 0,
        deductionManual: 0,
        otMultiplier: config.otMultiplier, // ‼️ per-staff OT rate
      );

      final res = await upsertRecord(periodId: periodId, input: input);
      if (res != null) count++;
    }

    // Cập nhật tổng
    final records = await fetchRecords(periodId);
    final total = records.fold(0.0, (s, r) => s + r.netPay);
    await updatePeriodTotal(periodId, total);

    return count;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINANCE INTEGRATION — ghi chi phí lương vào finance_records
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<void> recordPayrollExpense({
    required String periodId,
    required String periodName,
    required double totalAmount,
    String fundType = 'transfer',
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    try {
      // ‼️ Idempotency: kiểm tra đã tồn tại bản ghi chi lương cho kỳ này chưa
      // Tránh duplicate nếu 2 admin đồng thời bấm "Trả lương" cho NV cuối
      final existing = await _sb
          .from('finance_records')
          .select('id')
          .eq('store_id', storeId)
          .eq('reference_id', periodId)
          .eq('is_auto', true)
          .maybeSingle();
      if (existing != null) {
        debugPrint(
          '[TinhLuong] recordPayrollExpense skipped — already exists for $periodId',
        );
        return;
      }

      await _sb.from('finance_records').insert({
        'id': _uuid.v4(),
        'store_id': storeId,
        'type': 'expense',
        'amount': totalAmount,
        'description': 'Chi lương: $periodName',
        'reference_id': periodId,
        'is_auto': true,
        'recorded_at': DateTime.now().toUtc().toIso8601String(),
        'fund_type': fundType,
      });
    } catch (e) {
      debugPrint('[TinhLuong] recordPayrollExpense silent fail: $e');
    }
  }

  // ─── REALTIME SHIFT & MONTHLY EARNINGS CALCULATOR ──────────────────────────────

  static SingleShiftEarnings calculateSingleShiftEarnings({
    required ShiftRecord shift,
    StaffSalaryConfig? config,
    ShiftTemplate? template,
  }) {
    if (shift.clockOut == null) {
      return const SingleShiftEarnings(
        regularPay: 0,
        overtimePay: 0,
        deductionLate: 0,
        netPay: 0,
        totalHours: 0,
        overtimeHours: 0,
        penaltyReasons: [],
        bonusReasons: [],
      );
    }

    final mode = config?.salaryMode ?? 'M1';
    final baseSalary = config?.baseSalary ?? 0;
    final configuredHourlyRate = config?.hourlyRate ?? 0;
    final hourlyRate = mode == 'M5'
        ? configuredHourlyRate
        : (configuredHourlyRate > 0 ? configuredHourlyRate : 25000.0);
    final dailyRate = config?.dailyRate ?? 0;
    final otThreshold = config?.otThresholdHours ?? 8.0;
    final otMultiplier = config?.otMultiplier ?? 1.5;
    final perLatePenalty = config?.deductionPerLate ?? 20000.0;

    final duration = shift.clockOut!.difference(shift.clockIn);
    final totalHours = duration.inMinutes / 60.0;
    if (totalHours <= 0) {
      return const SingleShiftEarnings(
        regularPay: 0,
        overtimePay: 0,
        deductionLate: 0,
        netPay: 0,
        totalHours: 0,
        overtimeHours: 0,
        penaltyReasons: [],
        bonusReasons: [],
      );
    }

    final overtimeHours = totalHours > otThreshold
        ? (totalHours - otThreshold)
        : 0.0;
    final regularHours = totalHours - overtimeHours;

    double regularPay = 0;
    double overtimePay = 0;

    switch (mode) {
      case 'M1': // Theo giờ
        regularPay = regularHours * hourlyRate;
        overtimePay = overtimeHours * hourlyRate * otMultiplier;
        break;
      case 'M2': // Cố định tháng
        final rate = baseSalary > 0 ? (baseSalary / 26 / 8) : hourlyRate;
        regularPay = regularHours * rate;
        overtimePay = overtimeHours * rate * otMultiplier;
        break;
      case 'M3': // Cố định + OT giờ
        final rate = hourlyRate > 0
            ? hourlyRate
            : (baseSalary > 0 ? (baseSalary / 26 / 8) : 25000.0);
        regularPay = regularHours * rate;
        overtimePay = overtimeHours * rate * otMultiplier;
        break;
      case 'M4': // Theo ngày
        final rate = dailyRate > 0
            ? (dailyRate / 8)
            : (baseSalary > 0 ? (baseSalary / 8) : hourlyRate);
        regularPay = regularHours * rate;
        overtimePay = overtimeHours * rate * otMultiplier;
        break;
      case 'M5': // Tùy chỉnh: cộng các thành phần có giá trị
        final baseRate = baseSalary > 0
            ? baseSalary / (config?.expectedDays ?? 26) / 8
            : 0.0;
        final dailyHourlyRate = dailyRate > 0 ? dailyRate / 8 : 0.0;
        regularPay = regularHours * (baseRate + hourlyRate + dailyHourlyRate);
        final customOtRate = hourlyRate > 0
            ? hourlyRate
            : (dailyHourlyRate > 0 ? dailyHourlyRate : baseRate);
        overtimePay = overtimeHours * customOtRate * otMultiplier;
        break;
      default:
        regularPay = regularHours * hourlyRate;
        overtimePay = overtimeHours * hourlyRate * otMultiplier;
    }

    final List<String> penaltyReasons = [];
    final List<String> bonusReasons = [];
    double deductionLate = 0;

    // Check Late via template
    if (template != null) {
      final startH = template.startHour;
      final startM = template.startMinute;
      final graceM = template.lateGraceMinutes;
      final shiftDate = shift.clockIn.toLocal();
      final expectedStart = DateTime(
        shiftDate.year,
        shiftDate.month,
        shiftDate.day,
        startH,
        startM,
      );
      final graceCutoff = expectedStart.add(Duration(minutes: graceM));

      if (shiftDate.isAfter(graceCutoff)) {
        final lateMinutes = shiftDate.difference(expectedStart).inMinutes;
        deductionLate += perLatePenalty;
        penaltyReasons.add(
          'Đi muộn ${lateMinutes}p (Quy định: ${graceM}p) - Khấu trừ ${perLatePenalty.toStringAsFixed(0)}đ',
        );
      }

      // Check Early Leave
      final endH = template.endHour;
      final endM = template.endMinute;
      final expectedEnd = DateTime(
        shiftDate.year,
        shiftDate.month,
        shiftDate.day,
        endH,
        endM,
      );
      final clockOutLocal = shift.clockOut!.toLocal();
      if (clockOutLocal.isBefore(expectedEnd)) {
        final earlyMinutes = expectedEnd.difference(clockOutLocal).inMinutes;
        if (earlyMinutes > 5) {
          final earlyPenalty = perLatePenalty > 0 ? perLatePenalty : 10000.0;
          deductionLate += earlyPenalty;
          penaltyReasons.add(
            'Về sớm ${earlyMinutes}p - Khấu trừ ${earlyPenalty.toStringAsFixed(0)}đ',
          );
        }
      }
    }

    if (overtimeHours > 0) {
      if (shift.isOtApproved) {
        bonusReasons.add(
          '🟢 OT ${overtimeHours.toStringAsFixed(1)}h (+${overtimePay.toStringAsFixed(0)}đ) [Duyệt bởi: ${shift.otApprovedBy ?? "Quản lý"} - Lý do: ${shift.otReason ?? "Tăng ca"}]',
        );
      } else {
        penaltyReasons.add(
          '🟡 OT ${overtimeHours.toStringAsFixed(1)}h (+${overtimePay.toStringAsFixed(0)}đ) - Chờ Quản lý duyệt OT & nhập lý do',
        );
      }
    }

    if (shift.isManagerOverridden) {
      bonusReasons.add(
        '🛡️ Điều chỉnh bởi ${shift.overrideBy ?? "Quản lý"}: ${shift.overrideReason ?? "Khôi phục 100% lương"}',
      );
    }

    final isForgotClockout = shift.checkIsForgotClockout;
    if (isForgotClockout) {
      final activeOtForForgot = shift.isOtApproved ? overtimePay : 0.0;
      final grossBeforePenalty = regularPay + activeOtForForgot;
      final forgotPenalty = grossBeforePenalty * 0.5;
      deductionLate += forgotPenalty;
      penaltyReasons.add(
        '🔴 Quên chốt ca (Ca > 14h) - Khấu trừ 50% tiền ca (-${forgotPenalty.toStringAsFixed(0)}đ)',
      );
    }

    final activeOtPay = shift.isOtApproved ? overtimePay : 0.0;
    final gross = regularPay + activeOtPay;
    final net = (gross - deductionLate) < 0 ? 0.0 : (gross - deductionLate);

    return SingleShiftEarnings(
      regularPay: regularPay,
      overtimePay: activeOtPay,
      deductionLate: deductionLate,
      netPay: net,
      totalHours: totalHours,
      overtimeHours: overtimeHours,
      penaltyReasons: penaltyReasons,
      bonusReasons: bonusReasons,
    );
  }

  static Future<RealtimeMonthlyEarnings> fetchRealtimeMonthlyEarnings({
    required String storeId,
    required String userId,
    DateTime? monthYear,
  }) async {
    final targetDate = monthYear ?? DateTime.now();
    final startOfMonth = DateTime(targetDate.year, targetDate.month, 1);
    final endOfMonth = DateTime(
      targetDate.year,
      targetDate.month + 1,
      0,
      23,
      59,
      59,
    );

    final config = await StaffSalaryConfigRepo.fetchByUserId(userId);
    final shifts = await StaffService.getShifts(
      storeId: storeId,
      userId: userId,
      limit: 300,
    );

    final monthlyShifts = shifts.where((s) {
      final dt = s.clockIn.toLocal();
      return dt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
          dt.isBefore(endOfMonth.add(const Duration(seconds: 1))) &&
          s.clockOut != null;
    }).toList();

    double totalEarnings = 0;
    double totalHours = 0;
    double totalDeductions = 0;
    double totalBonus = 0;

    for (final s in monthlyShifts) {
      final res = calculateSingleShiftEarnings(shift: s, config: config);
      totalEarnings += res.netPay;
      totalHours += res.totalHours;
      totalDeductions += res.deductionLate;
      totalBonus += res.overtimePay;
    }

    return RealtimeMonthlyEarnings(
      totalEarnings: totalEarnings,
      totalHours: totalHours,
      shiftCount: monthlyShifts.length,
      totalDeductions: totalDeductions,
      totalBonus: totalBonus,
      shifts: monthlyShifts,
    );
  }
}

// ─── REALTIME EARNINGS MODELS ──────────────────────────────────────────────────

class SingleShiftEarnings {
  final double regularPay;
  final double overtimePay;
  final double deductionLate;
  final double netPay;
  final double totalHours;
  final double overtimeHours;
  final List<String> penaltyReasons;
  final List<String> bonusReasons;

  const SingleShiftEarnings({
    required this.regularPay,
    required this.overtimePay,
    required this.deductionLate,
    required this.netPay,
    required this.totalHours,
    required this.overtimeHours,
    required this.penaltyReasons,
    required this.bonusReasons,
  });
}

class RealtimeMonthlyEarnings {
  final double totalEarnings;
  final double totalHours;
  final int shiftCount;
  final double totalDeductions;
  final double totalBonus;
  final List<ShiftRecord> shifts;

  const RealtimeMonthlyEarnings({
    required this.totalEarnings,
    required this.totalHours,
    required this.shiftCount,
    required this.totalDeductions,
    required this.totalBonus,
    required this.shifts,
  });
}

// ─── SHIFT SUMMARY (public) ───────────────────────────────────────────────────

class StaffShiftSummary {
  final String userId;
  final String staffName;
  double totalHours = 0;
  double overtimeHours = 0;
  double workDays = 0; // số ngày làm unique (set bởi aggregateShifts)
  int lateCount = 0;
  int totalLateMinutes = 0;

  StaffShiftSummary({required this.userId, required this.staffName});
}

/// Config lương của 1 nhân viên khi tạo kỳ
class StaffPayConfig {
  final String staffName;
  final String? role;
  final String salaryMode;
  final double baseSalary;
  final double hourlyRate;
  final double dailyRate;
  final int expectedDays; // số ngày làm chuẩn trong kỳ
  final double bonusRevenue;
  final double deductionPerLate; // ‼️ FIX Bug #26: per-staff (default 50000)
  final double otThresholdHours; // ‼️ FIX Bug #26: per-staff (default 8.0)
  final double otMultiplier; // Hệ số OT: 1.5 (default), 2.0, 3.0

  const StaffPayConfig({
    required this.staffName,
    this.role,
    required this.salaryMode,
    required this.baseSalary,
    required this.hourlyRate,
    this.dailyRate = 0,
    this.expectedDays = 26,
    this.bonusRevenue = 0,
    this.deductionPerLate = 50000,
    this.otThresholdHours = 8.0,
    this.otMultiplier = 1.5,
  });
}
