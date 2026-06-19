// lib/modules/tinhluong/repository/tinhluong_repository.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';

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
  });

  bool get isDraft    => status == 'draft';
  bool get isPaid     => status == 'paid';
  bool get isApproved => status == 'approved';

  factory PayrollPeriodModel.fromMap(Map<String, dynamic> m) =>
      PayrollPeriodModel(
        id:          m['id'] as String,
        storeId:     m['store_id'] as String,
        name:        m['name'] as String,
        periodType:  m['period_type'] as String? ?? 'monthly',
        fromDate:    (m['from_date'] ?? '').toString(),
        toDate:      (m['to_date'] ?? '').toString(),
        status:      m['status'] as String? ?? 'draft',
        totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
        note:        m['note'] as String?,
        lockedAt:    m['locked_at']?.toString(),
        paidAt:      m['paid_at']?.toString(),
        createdAt:   (m['created_at'] ?? '').toString(),
      );

  PayrollPeriodModel copyWith({double? totalAmount}) => PayrollPeriodModel(
        id:          id,
        storeId:     storeId,
        name:        name,
        periodType:  periodType,
        fromDate:    fromDate,
        toDate:      toDate,
        status:      status,
        totalAmount: totalAmount ?? this.totalAmount,
        note:        note,
        lockedAt:    lockedAt,
        paidAt:      paidAt,
        createdAt:   createdAt,
      );
}

class PayrollRecordModel {
  final String id;
  final String storeId;
  final String periodId;
  final String userId;
  final String staffName;
  final String? role;
  final String salaryMode; // M1 | M2 | M3 | M4
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
        id:               m['id'] as String,
        storeId:          m['store_id'] as String,
        periodId:         m['period_id'] as String,
        userId:           m['user_id'] as String,
        staffName:        m['staff_name'] as String,
        role:             m['role'] as String?,
        salaryMode:       m['salary_mode'] as String? ?? 'M1',
        baseSalary:       (m['base_salary'] as num?)?.toDouble() ?? 0,
        hourlyRate:       (m['hourly_rate'] as num?)?.toDouble() ?? 0,
        totalHours:       (m['total_hours'] as num?)?.toDouble() ?? 0,
        overtimeHours:    (m['overtime_hours'] as num?)?.toDouble() ?? 0,
        regularPay:       (m['regular_pay'] as num?)?.toDouble() ?? 0,
        overtimePay:      (m['overtime_pay'] as num?)?.toDouble() ?? 0,
        bonusRevenue:     (m['bonus_revenue'] as num?)?.toDouble() ?? 0,
        bonusManual:      (m['bonus_manual'] as num?)?.toDouble() ?? 0,
        deductionLate:    (m['deduction_late'] as num?)?.toDouble() ?? 0,
        deductionAbsent:  (m['deduction_absent'] as num?)?.toDouble() ?? 0,
        deductionManual:  (m['deduction_manual'] as num?)?.toDouble() ?? 0,
        allowanceTotal:   (m['allowance_total'] as num?)?.toDouble() ?? 0,
        grossPay:         (m['gross_pay'] as num?)?.toDouble() ?? 0,
        netPay:           (m['net_pay'] as num?)?.toDouble() ?? 0,
        absentDays:       (m['absent_days'] as num?)?.toInt() ?? 0,
        lateCount:        (m['late_count'] as num?)?.toInt() ?? 0,
        paymentStatus:    m['payment_status'] as String? ?? 'pending',
        paymentMethod:    m['payment_method'] as String?,
        paidAt:           m['paid_at'] as String?,
        note:             m['note'] as String?,
        createdAt:        m['created_at'] as String? ?? '',
      );
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
        id:       m['id'] as String,
        storeId:  m['store_id'] as String,
        recordId: m['record_id'] as String,
        itemType: m['item_type'] as String,
        label:    m['label'] as String,
        amount:   (m['amount'] as num).toDouble(),
        isAuto:   m['is_auto'] as bool? ?? false,
        note:     m['note'] as String?,
      );
}

/// Input để engine tính lương 1 nhân viên
class PayrollInput {
  final String userId;
  final String staffName;
  final String? role;
  final String salaryMode; // M1 | M2 | M3 | M4
  final double baseSalary;
  final double hourlyRate;
  final double totalHours;
  final double overtimeHours;
  final double workDays;          // số ngày làm unique (cho M4)
  final int absentDays;
  final int lateCount;
  final double deductionPerLate;   // VD: 50000đ/lần trễ
  final double deductionPerAbsent; // VD: lương/26 ngày
  final double bonusRevenue;
  final double bonusManual;
  final double deductionManual;
  final double otMultiplier;       // Hệ số OT: 1.5 (mặc định), 2.0 (ngày lễ), v.v.
  final List<PayrollItemModel> extraItems;

  const PayrollInput({
    required this.userId,
    required this.staffName,
    this.role,
    required this.salaryMode,
    required this.baseSalary,
    required this.hourlyRate,
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
    this.otMultiplier = 1.5,       // Mặc định 1.5x theo luật lao động VN
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

// ─── ENGINE ──────────────────────────────────────────────────────────────────

PayrollCalcResult calculatePayroll(PayrollInput input) {
  double regularPay  = 0;
  double overtimePay = 0;

  switch (input.salaryMode) {
    case 'M1': // Theo giờ
      regularPay  = (input.totalHours - input.overtimeHours) * input.hourlyRate;
      overtimePay = input.overtimeHours * input.hourlyRate * input.otMultiplier;
      break;
    case 'M2': // Lương cố định tháng
      regularPay  = input.baseSalary;
      overtimePay = input.overtimeHours * (input.baseSalary / 26 / 8) * input.otMultiplier;
      break;
    case 'M3': // Cố định + theo giờ OT
      regularPay  = input.baseSalary;
      overtimePay = input.overtimeHours * input.hourlyRate * input.otMultiplier;
      break;
    case 'M4': // Theo ngày
      regularPay  = input.workDays * input.baseSalary;
      overtimePay = input.overtimeHours * (input.baseSalary / 8) * input.otMultiplier;
      break;
    default:
      regularPay = input.baseSalary;
  }
  if (regularPay < 0) regularPay = 0;

  final deductionLate   = input.lateCount * input.deductionPerLate;
  final deductionAbsent = input.absentDays * input.deductionPerAbsent;

  final extraBonus = input.extraItems
      .where((i) => i.itemType == 'bonus' || i.itemType == 'allowance')
      .fold(0.0, (s, i) => s + i.amount);
  final extraDeduct = input.extraItems
      .where((i) => i.itemType == 'deduction')
      .fold(0.0, (s, i) => s + i.amount);

  final grossPay = regularPay
      + overtimePay
      + input.bonusRevenue
      + input.bonusManual
      + extraBonus
      - deductionLate
      - deductionAbsent
      - input.deductionManual
      - extraDeduct;

  final netPay = grossPay < 0 ? 0.0 : grossPay;

  return PayrollCalcResult(
    regularPay:      regularPay,
    overtimePay:     overtimePay,
    deductionLate:   deductionLate,
    deductionAbsent: deductionAbsent,
    grossPay:        grossPay,
    netPay:          netPay,
  );
}

// ─── REPOSITORY ──────────────────────────────────────────────────────────────

class TinhLuongRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  static const _uuid = Uuid();

  static Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYROLL PERIODS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<PayrollPeriodModel>> fetchPeriods() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    try {
      // 1. Fetch tất cả periods
      final rows = await _sb
          .from('payroll_periods')
          .select()
          .eq('store_id', storeId)
          .order('created_at', ascending: false);
      final periods = (rows as List)
          .map((r) => PayrollPeriodModel.fromMap(r as Map<String, dynamic>))
          .toList();

      if (periods.isEmpty) return [];

      // 2. ‼️ FIX: Batch-fetch TẤT CẢ records trong 1 query duy nhất
      // Tính live total từ net_pay thực tế — tránh dùng total_amount stale trong DB
      final periodIds = periods.map((p) => p.id).toList();
      final recordRows = await _sb
          .from('payroll_records')
          .select('period_id, net_pay')
          .inFilter('period_id', periodIds);

      // 3. Group records → sum net_pay theo period_id (trong Dart — không cần RPC)
      final Map<String, double> liveTotal = {};
      for (final r in recordRows as List) {
        final pid = r['period_id'] as String;
        final pay = (r['net_pay'] as num?)?.toDouble() ?? 0;
        liveTotal[pid] = (liveTotal[pid] ?? 0) + pay;
      }

      // 4. Override totalAmount với giá trị live, sync DB nền cho các period bị stale
      final corrected = periods.map((p) {
        final live = liveTotal[p.id] ?? p.totalAmount;
        if ((live - p.totalAmount).abs() > 1.0) {
          // ‼️ Fire-and-forget: sync DB mà không block UI
          _sb.from('payroll_periods')
              .update({'total_amount': live})
              .eq('id', p.id)
              .then((_) => debugPrint('[TinhLuong] auto-healed period ${p.name}: ${p.totalAmount} → $live'))
              .catchError((e) => debugPrint('[TinhLuong] heal error: $e'));
        }
        return p.copyWith(totalAmount: live);
      }).toList();

      return corrected;
    } catch (e) {
      debugPrint('[TinhLuong] fetchPeriods error: $e');
      return [];
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
    final storeId = await _storeId();
    if (storeId == null) return null;
    try {
      // ‼️ FIX Bug #22: .single() crash khi DB trả 0 rows (race condition) → maybeSingle()
      final res = await _sb.from('payroll_periods').insert({
        'id':          _uuid.v4(),
        'store_id':    storeId,
        'name':        name,
        'period_type': periodType,
        'from_date':   fromDate,
        'to_date':     toDate,
        'status':      'draft',
        'note':        note,
        'created_by':  createdBy,
        'created_at':  DateTime.now().toUtc().toIso8601String(),
      }).select().maybeSingle();
      if (res == null) return null;
      return PayrollPeriodModel.fromMap(res);
    } catch (e) {
      debugPrint('[TinhLuong] createPeriod error: $e');
      return null;
    }
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
  }

  static Future<void> updatePeriodTotal(String id, double total) async {
    await _sb.from('payroll_periods')
        .update({'total_amount': total}).eq('id', id);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAYROLL RECORDS
  // ═══════════════════════════════════════════════════════════════════════════

  static Future<List<PayrollRecordModel>> fetchRecords(String periodId) async {
    try {
      final rows = await _sb
          .from('payroll_records')
          .select()
          .eq('period_id', periodId)
          .order('staff_name');
      return (rows as List)
          .map((r) => PayrollRecordModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[TinhLuong] fetchRecords error: $e');
      return [];
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
    final storeId = await _storeId();
    if (storeId == null) return null;

    final calc = calculatePayroll(input);
    final id   = _uuid.v4();
    final now  = DateTime.now().toUtc().toIso8601String();

    final allowanceTotal = input.extraItems
        .where((i) => i.itemType == 'allowance')
        .fold(0.0, (s, i) => s + i.amount);

    try {
      // ‼️ FIX BUG #16: guard — không đè lên record đã 'paid'
      final existing = await _sb.from('payroll_records')
          .select('id, payment_status')
          .eq('period_id', periodId)
          .eq('user_id', input.userId)
          .maybeSingle();
      if (existing != null && existing['payment_status'] == 'paid') {
        debugPrint('[TinhLuong] upsertRecord: bỏ qua ${input.staffName} — đã paid');
        return existing['id'] as String;
      }

      final newRow = {
        'id':               id,
        'store_id':         storeId,
        'period_id':        periodId,
        'user_id':          input.userId,
        'staff_name':       input.staffName,
        'role':             input.role,
        'salary_mode':      input.salaryMode,
        'base_salary':      input.baseSalary,
        'hourly_rate':      input.hourlyRate,
        'total_hours':      input.totalHours,
        'overtime_hours':   input.overtimeHours,
        'regular_pay':      calc.regularPay,
        'overtime_pay':     calc.overtimePay,
        'bonus_revenue':    input.bonusRevenue,
        'bonus_manual':     input.bonusManual,
        'deduction_late':   calc.deductionLate,
        'deduction_absent': calc.deductionAbsent,
        'deduction_manual': input.deductionManual,
        'allowance_total':  allowanceTotal,
        'gross_pay':        calc.grossPay,
        'net_pay':          calc.netPay,
        'absent_days':      input.absentDays,
        'late_count':       input.lateCount,
        'payment_status':   'pending',
        'created_at':       now,
      };

      // ‼️ FIX: Insert TRƯỚC, delete sau — tránh mất dữ liệu nếu insert thất bại
      // Nếu đã có record cũ → insert sẽ thất bại (trùng PK nếu same id), cần delete trước
      // Nhưng PK là uuid mới → insert luôn thành công → delete old sau
      await _sb.from('payroll_records').insert(newRow);

      // Insert thành công → xóa record cũ (nếu có) an toàn
      await _sb.from('payroll_records')
          .delete()
          .eq('period_id', periodId)
          .eq('user_id', input.userId)
          .neq('id', id); // chỉ xóa record CŨ, không xóa vừa insert

      return id;
    } catch (e) {
      debugPrint('[TinhLuong] upsertRecord error: $e');
      return null;
    }
  }

  static Future<void> markRecordPaid({
    required String id,
    required String paymentMethod,
  }) async {
    await _sb.from('payroll_records').update({
      'payment_status': 'paid',
      'payment_method': paymentMethod,
      'paid_at':        DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  static Future<void> updateRecordNote(String id, String note) async {
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
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('payroll_items').insert({
      'id':         _uuid.v4(),
      'store_id':   storeId,
      'record_id':  recordId,
      'item_type':  itemType,
      'label':      label,
      'amount':     amount,
      'is_auto':    isAuto,
      'note':       note,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    // ‼️ FIX Bug #20: sync lại net_pay vào payroll_records sau khi thêm item
    await _recalcNetPay(recordId);
  }

  static Future<void> deleteItem(String id) async {
    // Lấy record_id trước khi xoá
    final row = await _sb.from('payroll_items').select('record_id').eq('id', id).maybeSingle();
    await _sb.from('payroll_items').delete().eq('id', id);
    // ‼️ FIX Bug #20: sync lại net_pay sau khi xoá item
    final recordId = row?['record_id'] as String?;
    if (recordId != null) await _recalcNetPay(recordId);
  }

  /// Tính lại net_pay từ tổng items + base record rồi update DB
  static Future<void> _recalcNetPay(String recordId) async {
    try {
      final row = await _sb.from('payroll_records').select().eq('id', recordId).maybeSingle();
      if (row == null) return;
      final items = await fetchItems(recordId);

      final extraBonus  = items.where((i) => i.itemType == 'bonus' || i.itemType == 'allowance')
                               .fold(0.0, (s, i) => s + i.amount);
      final extraDeduct = items.where((i) => i.itemType == 'deduction')
                               .fold(0.0, (s, i) => s + i.amount);

      final regularPay      = (row['regular_pay']      as num?)?.toDouble() ?? 0;
      final overtimePay     = (row['overtime_pay']     as num?)?.toDouble() ?? 0;
      final bonusRevenue    = (row['bonus_revenue']    as num?)?.toDouble() ?? 0;
      final bonusManual     = (row['bonus_manual']     as num?)?.toDouble() ?? 0;
      final deductionLate   = (row['deduction_late']   as num?)?.toDouble() ?? 0;
      final deductionAbsent = (row['deduction_absent'] as num?)?.toDouble() ?? 0;
      final deductionManual = (row['deduction_manual'] as num?)?.toDouble() ?? 0;

      final grossPay = regularPay + overtimePay + bonusRevenue + bonusManual
          + extraBonus - deductionLate - deductionAbsent - deductionManual - extraDeduct;
      final netPay   = grossPay < 0 ? 0.0 : grossPay;

      await _sb.from('payroll_records').update({
        'allowance_total': extraBonus,  // items bonus+allowance
        'gross_pay':       grossPay,
        'net_pay':         netPay,
      }).eq('id', recordId);

      // ‼️ FIX: sync total_amount của period → TinhLuongScreen card luôn đúng
      final periodId = row['period_id'] as String?;
      if (periodId != null) {
        final allRecords = await _sb
            .from('payroll_records')
            .select('net_pay')
            .eq('period_id', periodId);
        final periodTotal = (allRecords as List)
            .fold(0.0, (s, r) => s + ((r as Map)['net_pay'] as num? ?? 0).toDouble());
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
      final fromUtc = DateTime.utc(from.year, from.month, from.day)
          .subtract(const Duration(hours: 7)); // 2025-05-01 VN midnight
      final toUtc   = DateTime.utc(to.year, to.month, to.day)
          .subtract(const Duration(hours: 7)); // exclusive upper bound

      final rows = await _sb
          .from('staff_shifts')
          .select('user_id, clock_in, clock_out, is_late, late_minutes')
          .eq('store_id', storeId)
          .gte('clock_in', fromUtc.toIso8601String())
          .lt('clock_in', toUtc.toIso8601String())
          .not('clock_out', 'is', null);

      if ((rows as List).isEmpty) return {};

      // ‼️ FIX: lấy tên NV từ user_accounts riêng (staff_shifts không có cột staff_name)
      final userIds = rows.map((r) => (r as Map)['user_id'] as String).toSet().toList();
      final Map<String, String> nameMap = {};
      try {
        final users = await _sb.from('user_accounts')
            .select('id, display_name')
            .inFilter('id', userIds);
        for (final u in users) {
          nameMap[(u as Map)['id'] as String] = u['display_name'] as String? ?? '';
        }
      } catch (_) {}

      final Map<String, StaffShiftSummary> result = {};
      // ‼️ FIX: track unique work-days để tính absentDays đúng
      final Map<String, Set<String>> workDaysByUser = {};

      for (final row in rows) {
        final r         = row as Map<String, dynamic>;
        final userId    = r['user_id'] as String;
        // is_late/late_minutes: cột mới thêm, dùng null-safe
        final isLate    = (r['is_late'] as bool?) ?? false;
        final lateMin   = (r['late_minutes'] as num?)?.toInt() ?? 0;
        final clockIn   = DateTime.parse(r['clock_in'] as String).toLocal();
        final clockOut  = DateTime.parse(r['clock_out'] as String).toLocal();
        final hours     = clockOut.difference(clockIn).inMinutes / 60.0;
        // Ngày làm duy nhất (local date string)
        final dateStr   = '${clockIn.year}-${clockIn.month.toString().padLeft(2,'0')}-${clockIn.day.toString().padLeft(2,'0')}';

        final name = nameMap[userId] ?? '';
        final s = result.putIfAbsent(userId, () => StaffShiftSummary(userId: userId, staffName: name));
        workDaysByUser.putIfAbsent(userId, () => {}).add(dateStr);

        s.totalHours   += hours;
        if (isLate) s.lateCount++;
        if (lateMin > 0) s.totalLateMinutes += lateMin;
        // OT: giờ vượt ngưỡng trong ngày
        if (hours > otThresholdHours) s.overtimeHours += (hours - otThresholdHours);
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
    final fromUtc = DateTime.utc(from.year, from.month, from.day)
        .subtract(const Duration(hours: 7));
    final toUtc = DateTime.utc(to.year, to.month, to.day)
        .subtract(const Duration(hours: 7));
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
        final r   = row as Map<String, dynamic>;
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
    final s        = StaffShiftSummary(userId: userId, staffName: staffName);
    final workDays = <String>{};
    for (final r in rows) {
      final isLate   = (r['is_late']      as bool?) ?? false;
      final lateMin  = (r['late_minutes'] as num?)?.toInt() ?? 0;
      final clockIn  = DateTime.parse(r['clock_in']  as String).toLocal();
      final clockOut = DateTime.parse(r['clock_out'] as String).toLocal();
      final hours    = clockOut.difference(clockIn).inMinutes / 60.0;
      final dateStr  = '${clockIn.year}-'
          '${clockIn.month.toString().padLeft(2, '0')}-'
          '${clockIn.day.toString().padLeft(2, '0')}';
      workDays.add(dateStr);
      s.totalHours += hours;
      if (isLate)      s.lateCount++;
      if (lateMin > 0) s.totalLateMinutes += lateMin;
      if (hours > otThresholdHours) s.overtimeHours += (hours - otThresholdHours);
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
    final to   = DateTime.parse(toDate).add(const Duration(days: 1));

    // ‼️ FIX BUG #1: Fetch raw shifts 1 lần — tránh N HTTP requests (1 per staff)
    final rawRows = await _fetchRawShiftRows(storeId: storeId, from: from, to: to);

    int count = 0;
    for (final entry in staffConfigs.entries) {
      final userId = entry.key;
      final config = entry.value;

      // Aggregate per-staff với otThreshold riêng — từ raw rows đã có sẵn trong RAM
      final userRows = rawRows[userId] ?? [];
      final shift = userRows.isEmpty
          ? null
          : _aggregateOneUser(
              userId:           userId,
              staffName:        config.staffName,
              rows:             userRows,
              otThresholdHours: config.otThresholdHours,
            );

      // ‼️ FIX Bug #27: deductionPerAbsent theo mode
      // M1: 0 (không tính vào), M2: lương/26, M3: lương/26, M4: dailyRate (= baseSalary)
      final effectiveAbsent = deductionPerAbsent > 0
          ? deductionPerAbsent
          : switch (config.salaryMode) {
              'M2' => config.baseSalary / 26,
              'M3' => config.baseSalary / 26,
              'M4' => config.baseSalary,   // baseSalary đã = dailyRate sau mapping
              _    => 0.0,
            };

      final input = PayrollInput(
        userId:              userId,
        staffName:           config.staffName,
        role:                config.role,
        salaryMode:          config.salaryMode,
        baseSalary:          config.baseSalary,
        hourlyRate:          config.hourlyRate,
        totalHours:          shift?.totalHours ?? 0,
        overtimeHours:       shift?.overtimeHours ?? 0,
        workDays:            shift?.workDays ?? 0,
        absentDays: (() {
                               // ‼️ FIX BUG #14: nếu không có ca nào (shift=null)
                               // → KHÔNG tính absent — NV có thể mới onboard hoặc nghỉ có phép
                               // Manager có thể điều chỉnh thủ công qua items
                               if (shift == null) return 0;
                               final worked = shift.workDays.round();
                               final absent = config.expectedDays - worked;
                               return absent < 0 ? 0 : absent;
                             })(),
        lateCount:           shift?.lateCount ?? 0,
        deductionPerLate:    config.deductionPerLate,   // ‼️ Bug #26 fix: per-staff
        deductionPerAbsent:  effectiveAbsent,
        bonusRevenue:        config.bonusRevenue,
        bonusManual:         0,
        deductionManual:     0,
        otMultiplier:        config.otMultiplier,       // ‼️ per-staff OT rate
      );

      final res = await upsertRecord(periodId: periodId, input: input);
      if (res != null) count++;
    }

    // Cập nhật tổng
    final records = await fetchRecords(periodId);
    final total   = records.fold(0.0, (s, r) => s + r.netPay);
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
        debugPrint('[TinhLuong] recordPayrollExpense skipped — already exists for $periodId');
        return;
      }

      await _sb.from('finance_records').insert({
        'id':           _uuid.v4(),
        'store_id':     storeId,
        'type':         'expense',
        'amount':       totalAmount,
        'description':  'Chi lương: $periodName',
        'reference_id': periodId,
        'is_auto':      true,
        'recorded_at':  DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[TinhLuong] recordPayrollExpense silent fail: $e');
    }
  }
}

// ─── SHIFT SUMMARY (public) ───────────────────────────────────────────────────

class StaffShiftSummary {
  final String userId;
  final String staffName;
  double totalHours    = 0;
  double overtimeHours = 0;
  double workDays      = 0;   // số ngày làm unique (set bởi aggregateShifts)
  int    lateCount     = 0;
  int    totalLateMinutes = 0;

  StaffShiftSummary({required this.userId, required this.staffName});
}

/// Config lương của 1 nhân viên khi tạo kỳ
class StaffPayConfig {
  final String staffName;
  final String? role;
  final String salaryMode;
  final double baseSalary;
  final double hourlyRate;
  final int    expectedDays;        // số ngày làm chuẩn trong kỳ
  final double bonusRevenue;
  final double deductionPerLate;    // ‼️ FIX Bug #26: per-staff (default 50000)
  final double otThresholdHours;    // ‼️ FIX Bug #26: per-staff (default 8.0)
  final double otMultiplier;        // Hệ số OT: 1.5 (default), 2.0, 3.0

  const StaffPayConfig({
    required this.staffName,
    this.role,
    required this.salaryMode,
    required this.baseSalary,
    required this.hourlyRate,
    this.expectedDays = 26,
    this.bonusRevenue = 0,
    this.deductionPerLate   = 50000,
    this.otThresholdHours   = 8.0,
    this.otMultiplier       = 1.5,
  });
}

