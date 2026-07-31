import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/staff_service.dart';
import '../repository/tinhluong_repository.dart';
import '../repository/staff_salary_config_repository.dart';

class PayrollEvaluationService {
  static SupabaseClient get _sb => Supabase.instance.client;
  static const _uuid = Uuid();

  /// Đánh giá kỳ lương theo quy chuẩn mới (Source of Truth).
  static Future<PayrollEvaluationResult> evaluatePeriod({
    required String storeId,
    required String periodId,
    required String fromDateStr,
    required String toDateStr,
    required String status,
  }) async {
    try {
      // Nếu đã duyệt hoặc đã thanh toán -> Lấy snapshot từ DB, không tính live.
      if (status == 'approved' || status == 'paid') {
        final recordsRows = await _sb
            .from('payroll_records')
            .select()
            .eq('store_id', storeId)
            .eq('period_id', periodId);
            
        final records = (recordsRows as List)
            .map((r) => PayrollRecordModel.fromMap(r as Map<String, dynamic>))
            .toList();
            
        final storedTotal = records.fold(0.0, (sum, r) => sum + r.netPay);
        
        return PayrollEvaluationResult(
          status: status,
          resolvedTotal: storedTotal,
          storedTotal: storedTotal,
          liveTotal: storedTotal,
          hasDelta: false,
          deltaAmount: 0.0,
          records: records,
        );
      }

      // Trạng thái draft / pending_review -> Thực hiện Live Calculation
      // 1. Lấy records đã lưu để đối chiếu và giữ các thông số thủ công (manual)
      final existingRecordsRows = await _sb
          .from('payroll_records')
          .select()
          .eq('store_id', storeId)
          .eq('period_id', periodId);
          
      final storedRecords = (existingRecordsRows as List)
          .map((r) => PayrollRecordModel.fromMap(r as Map<String, dynamic>))
          .toList();
          
      final Map<String, PayrollRecordModel> storedRecordsMap = {
        for (var r in storedRecords) r.userId: r
      };
      
      final storedTotal = storedRecords.fold(0.0, (sum, r) => sum + r.netPay);

      // 2. Lấy dữ liệu live: shifts, configs, members
      final members = await StaffService.getStaffList(storeId);
      final configs = await StaffSalaryConfigRepo.fetchAll();
      final configMap = {for (var c in configs) c.userId: c};
      
      final fromParts = fromDateStr.split('-').map(int.parse).toList();
      final toParts = toDateStr.split('-').map(int.parse).toList();
      final fromIso = DateTime(fromParts[0], fromParts[1], fromParts[2], 0, 0, 0).toUtc().toIso8601String();
      final toIso = DateTime(toParts[0], toParts[1], toParts[2], 23, 59, 59).toUtc().toIso8601String();

      final shiftsRows = await _sb
          .from('staff_shifts')
          .select('*')
          .eq('store_id', storeId)
          .gte('clock_in', fromIso)
          .lte('clock_in', toIso)
          .not('clock_out', 'is', null);

      final memberMap = {for (var m in members) m.userId: m};

      final List<ShiftRecord> allShifts = (shiftsRows as List).map((r) {
        final m = r as Map<String, dynamic>;
        final uid = m['user_id'] as String? ?? '';
        final userName = memberMap[uid]?.name ?? 'Nhân viên';

        return ShiftRecord(
          id: m['id'] as String,
          userId: uid,
          userName: userName,
          clockIn: DateTime.parse(m['clock_in'] as String),
          clockOut: m['clock_out'] != null ? DateTime.parse(m['clock_out'] as String) : null,
          source: m['source'] as String? ?? 'app',
          note: m['note'] as String? ?? '',
          isOtApproved: m['is_ot_approved'] as bool? ?? false,
          otReason: m['ot_reason'] as String?,
          otApprovedBy: m['ot_approved_by'] as String?,
          isForgotClockout: m['is_forgot_clockout'] as bool? ?? false,
          isManagerOverridden: m['is_manager_overridden'] as bool? ?? false,
          overrideReason: m['override_reason'] as String?,
          overrideBy: m['override_by'] as String?,
        );
      }).toList();

      final Map<String, List<ShiftRecord>> userShiftMap = {};
      for (final s in allShifts) {
        userShiftMap.putIfAbsent(s.userId, () => []).add(s);
      }

      double liveTotalNet = 0;
      final List<PayrollRecordModel> liveRecords = [];
      final nowStr = DateTime.now().toUtc().toIso8601String();

      for (final m in members) {
        final uid = m.userId;
        final shifts = userShiftMap[uid] ?? [];
        final cfg = configMap[uid];

        // Nhân viên không có ca trong kỳ chưa cần cấu hình để hiển thị báo cáo.
        // Chỉ chặn tính lương khi người đó thực sự có dữ liệu làm việc.
        if (cfg == null && shifts.isNotEmpty) {
          throw Exception('Nhân viên ${m.name} chưa được cấu hình lương. Không thể tính toán.');
        }
        if (cfg == null) continue;

        final existing = storedRecordsMap[uid];

        if (existing != null) {
          if (existing.paymentStatus == 'paid' || existing.paymentStatus == 'pending_staff_confirm') {
            liveTotalNet += existing.netPay;
            liveRecords.add(existing);
            continue;
          }
        }

        double staffHours = 0;
        double staffOtHours = 0;
        int staffLateCount = existing?.lateCount ?? 0;
        final Set<String> uniqueDays = {};

        for (final s in shifts) {
          if (s.clockOut == null) continue;
          final duration = s.clockOut!.difference(s.clockIn);
          final hours = duration.inMinutes / 60.0;
          if (hours <= 0) continue;

          staffHours += hours;
          
          if (s.isOtApproved) {
            final otThreshold = cfg.otThresholdHours;
            if (hours > otThreshold) {
              staffOtHours += (hours - otThreshold);
            }
          }

          final local = s.clockIn.toLocal();
          uniqueDays.add('${local.year}-${local.month}-${local.day}');
        }

        final workedDays = uniqueDays.length;

        final configuredExtras = calculateConfiguredPeriodExtras(
          config: cfg,
          workedDays: workedDays,
        );

        final bonusRev = existing?.bonusRevenue ?? 0.0;
        final savedBonusMan = existing?.bonusManual ?? 0.0;
        final savedAllowance = existing?.allowanceTotal ?? 0.0;
        
        final bonusMan = savedBonusMan != 0 ? savedBonusMan : configuredExtras.bonus;
        final allowTotal = savedAllowance != 0 ? savedAllowance : configuredExtras.allowance;
        
        final absentDays = existing?.absentDays ?? (() {
          final expected = cfg.expectedDays;
          final absent = expected - workedDays;
          return absent < 0 ? 0 : absent;
        })();
        
        final input = PayrollInput(
          userId: uid,
          staffName: m.name,
          role: m.role,
          salaryMode: cfg.salaryMode,
          baseSalary: cfg.baseSalary,
          hourlyRate: cfg.hourlyRate,
          dailyRate: cfg.dailyRate,
          expectedDays: cfg.expectedDays,
          totalHours: staffHours,
          overtimeHours: staffOtHours,
          workDays: workedDays.toDouble(),
          absentDays: absentDays,
          lateCount: staffLateCount,
          deductionPerLate: cfg.deductionPerLate,
          deductionPerAbsent: (() {
            final mode = cfg.salaryMode;
            final base = cfg.baseSalary;
            if (mode == 'M2' || mode == 'M3') return base / 26;
            if (mode == 'M4') {
              return cfg.dailyRate > 0 ? cfg.dailyRate : base;
            }
            return 0.0;
          })(),
          bonusRevenue: bonusRev,
          bonusManual: bonusMan + allowTotal,
          deductionManual: existing?.deductionManual ?? 0.0,
          otMultiplier: cfg.otMultiplier,
        );
        
        final res = calculatePayroll(input);
        
        final dedAbs = existing?.deductionAbsent ?? res.deductionAbsent;
        final dedMan = existing?.deductionManual ?? 0.0;
        final createdAt = existing?.createdAt ?? nowStr;
        final paymentStatus = existing?.paymentStatus ?? 'pending';
        
        double computedNet = res.grossPay;
        if (existing != null && dedAbs != res.deductionAbsent) {
          computedNet = computedNet + res.deductionAbsent - dedAbs;
        }
        final netPay = computedNet < 0 ? 0.0 : computedNet;

        liveTotalNet += netPay;

        liveRecords.add(PayrollRecordModel(
          id: existing?.id ?? _uuid.v4(),
          storeId: storeId,
          periodId: periodId,
          userId: uid,
          staffName: m.name,
          role: m.role,
          salaryMode: cfg.salaryMode,
          baseSalary: cfg.baseSalary,
          hourlyRate: cfg.hourlyRate,
          totalHours: staffHours,
          overtimeHours: staffOtHours,
          regularPay: res.regularPay,
          overtimePay: res.overtimePay,
          bonusRevenue: bonusRev,
          bonusManual: bonusMan,
          deductionLate: res.deductionLate,
          deductionAbsent: dedAbs,
          deductionManual: dedMan,
          allowanceTotal: allowTotal,
          grossPay: res.grossPay,
          netPay: netPay,
          absentDays: absentDays,
          lateCount: staffLateCount,
          paymentStatus: paymentStatus,
          createdAt: createdAt,
        ));
      }

      // Làm tròn 2 số sau dấu phẩy để tránh sai số dấu phẩy động
      final liveTotalRounded = double.parse(liveTotalNet.toStringAsFixed(2));
      final storedTotalRounded = double.parse(storedTotal.toStringAsFixed(2));
      
      final bool hasDelta = liveTotalRounded != storedTotalRounded;
      final double deltaAmount = liveTotalRounded - storedTotalRounded;

      return PayrollEvaluationResult(
        status: status,
        resolvedTotal: liveTotalRounded,
        storedTotal: storedTotalRounded,
        liveTotal: liveTotalRounded,
        hasDelta: hasDelta,
        deltaAmount: deltaAmount,
        records: liveRecords,
      );
    } catch (e) {
      // Fail-closed design
      debugPrint('[PayrollEvaluationService] evaluatePeriod error: $e');
      throw Exception('Lỗi tính toán lương ($e)');
    }
  }
}
