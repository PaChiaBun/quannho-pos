// lib/modules/tinhluong/screens/payroll_report_screen.dart
// Màn hình Báo Cáo Tính Lương Thời Gian Thực (Realtime Salary Report Engine)
// ignore_for_file: use_build_context_synchronously, deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:quannho_pos/core/services/staff_service.dart';
import 'package:quannho_pos/modules/tinhluong/repository/staff_salary_config_repository.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/providers/permission_provider.dart';
import '../repository/tinhluong_repository.dart';
import '../services/payroll_evaluation_service.dart';

final _fmt = NumberFormat('#,###', 'vi_VN');
String _fmtM(double v) => '${_fmt.format(v.round())}đ';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream = Color(0xFFFFF8F0);
const _kMuted = Color(0xFF9E9085);

// ─── Enum Period & Range Engine ──────────────────────────────────────────────

enum SalaryReportPeriod { today, week, month }

extension SalaryReportPeriodX on SalaryReportPeriod {
  String get label => switch (this) {
    SalaryReportPeriod.today => 'Hôm nay',
    SalaryReportPeriod.week => 'Tuần này',
    SalaryReportPeriod.month => 'Tháng này',
  };

  (DateTime, DateTime) rangeFor({
    required DateTime selectedDay,
    required DateTime weekStart,
    required int navYear,
    required int navMonth,
  }) {
    switch (this) {
      case SalaryReportPeriod.today:
        final start = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
        );
        final end = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
          23,
          59,
          59,
        );
        return (start, end);
      case SalaryReportPeriod.week:
        final start = DateTime(weekStart.year, weekStart.month, weekStart.day);
        final end = start.add(
          const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
        );
        return (start, end);
      case SalaryReportPeriod.month:
        final start = DateTime(navYear, navMonth, 1);
        final lastDay = DateTime(navYear, navMonth + 1, 0).day;
        final end = DateTime(navYear, navMonth, lastDay, 23, 59, 59);
        return (start, end);
    }
  }
}

// ─── Data Models ─────────────────────────────────────────────────────────────

class _StaffSalarySummary {
  final String userId;
  final String name;
  final String role;
  final double totalHours;
  final double totalNetPay;
  final int shiftCount;
  final int pendingOtCount;
  final int forgotClockoutCount;
  final List<ShiftRecord> shifts;

  final double overtimeHours;
  final double regularPay;
  final double overtimePay;
  final double deductionLate;
  final double configuredExtras;
  final StaffSalaryConfig? config;

  const _StaffSalarySummary({
    required this.userId,
    required this.name,
    required this.role,
    required this.totalHours,
    required this.totalNetPay,
    required this.shiftCount,
    required this.pendingOtCount,
    required this.forgotClockoutCount,
    required this.shifts,
    required this.overtimeHours,
    required this.regularPay,
    required this.overtimePay,
    required this.deductionLate,
    required this.configuredExtras,
    this.config,
  });
}

class _RealtimeReportData {
  final String storeId;
  final double totalSalary;
  final double totalHours;
  final int activeStaffCount;
  final int pendingOtCount;
  final int forgotClockoutCount;
  final List<_StaffSalarySummary> staffSummaries;
  final DateTime fromDate;
  final DateTime toDate;

  const _RealtimeReportData({
    required this.storeId,
    required this.totalSalary,
    required this.totalHours,
    required this.activeStaffCount,
    required this.pendingOtCount,
    required this.forgotClockoutCount,
    required this.staffSummaries,
    required this.fromDate,
    required this.toDate,
  });
}

// ─── Provider Params ─────────────────────────────────────────────────────────

class _ReportParam {
  final SalaryReportPeriod period;
  final DateTime selectedDay;
  final DateTime weekStart;
  final int navYear;
  final int navMonth;
  final PayrollPeriodModel? targetPeriod;

  const _ReportParam({
    required this.period,
    required this.selectedDay,
    required this.weekStart,
    required this.navYear,
    required this.navMonth,
    this.targetPeriod,
  });

  @override
  bool operator ==(Object other) =>
      other is _ReportParam &&
      other.period == period &&
      other.selectedDay.year == selectedDay.year &&
      other.selectedDay.month == selectedDay.month &&
      other.selectedDay.day == selectedDay.day &&
      other.weekStart.year == weekStart.year &&
      other.weekStart.month == weekStart.month &&
      other.weekStart.day == weekStart.day &&
      other.navYear == navYear &&
      other.navMonth == navMonth &&
      other.targetPeriod?.id == targetPeriod?.id;

  @override
  int get hashCode => Object.hash(
    period,
    selectedDay.year,
    selectedDay.month,
    selectedDay.day,
    weekStart.year,
    weekStart.month,
    weekStart.day,
    navYear,
    navMonth,
    targetPeriod?.id,
  );
}

final _realtimeReportProv =
    FutureProvider.family<_RealtimeReportData, _ReportParam>((ref, p) async {
      final info = await StoreAuthService.getStoreInfo().timeout(
        const Duration(seconds: 8),
      );
      final sid = info['store_id']?.toString();
      if (sid == null) {
        throw Exception('Lỗi không xác định: Không tìm thấy store_id.');
      }

      final db = Supabase.instance.client;
      String fromIso;
      String toIso;
      if (p.targetPeriod != null) {
        final fromParts = p.targetPeriod!.fromDate
            .split('-')
            .map(int.parse)
            .toList();
        final toParts = p.targetPeriod!.toDate
            .split('-')
            .map(int.parse)
            .toList();
        fromIso = DateTime(
          fromParts[0],
          fromParts[1],
          fromParts[2],
          0,
          0,
          0,
        ).toUtc().toIso8601String();
        toIso = DateTime(
          toParts[0],
          toParts[1],
          toParts[2],
          23,
          59,
          59,
        ).toUtc().toIso8601String();
      } else {
        final (from, to) = p.period.rangeFor(
          selectedDay: p.selectedDay,
          weekStart: p.weekStart,
          navYear: p.navYear,
          navMonth: p.navMonth,
        );
        fromIso = from.toUtc().toIso8601String();
        toIso = to.toUtc().toIso8601String();
      }

      try {
        // These three reads are independent; running them together removes
        // one full network round-trip from the report's critical path.
        final loaded = await Future.wait<dynamic>([
          StaffService.getStaffList(sid)
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () => <StaffMember>[],
              )
              .catchError((_) => <StaffMember>[]),
          db
              .from('staff_shifts')
              .select('*')
              .eq('store_id', sid)
              .gte('clock_in', fromIso)
              .lte('clock_in', toIso)
              .not('clock_out', 'is', null)
              .order('clock_in', ascending: false)
              .then<List<dynamic>>((rows) => rows as List<dynamic>)
              .timeout(const Duration(seconds: 8), onTimeout: () => <dynamic>[])
              .catchError((_) => <dynamic>[]),
          StaffSalaryConfigRepo.fetchAll()
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () => <StaffSalaryConfig>[],
              )
              .catchError((_) => <StaffSalaryConfig>[]),
        ]);

        final members = loaded[0] as List<StaffMember>;
        final memberMap = {for (var m in members) m.userId: m};
        final shiftsRows = loaded[1] as List;

        final List<ShiftRecord> allShifts = shiftsRows.map((r) {
          final m = r as Map<String, dynamic>;
          final uid = m['user_id'] as String? ?? '';
          final userName = memberMap[uid]?.name ?? 'Nhân viên';

          return ShiftRecord(
            id: m['id'] as String,
            userId: uid,
            userName: userName,
            clockIn: DateTime.parse(m['clock_in'] as String),
            clockOut: m['clock_out'] != null
                ? DateTime.parse(m['clock_out'] as String)
                : null,
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

        final configs = loaded[2] as List<StaffSalaryConfig>;
        final configMap = {for (var c in configs) c.userId: c};

        double grandTotalSalary = 0;
        double grandTotalHours = 0;
        int grandPendingOt = 0;
        int grandForgotClockout = 0;

        final List<_StaffSalarySummary> summaries = [];

        if (p.targetPeriod != null) {
          // Live evaluation can be expensive and may be blocked by one
          // unconfigured employee. The report must still be able to show the
          // saved payroll snapshot for the selected period.
          PayrollEvaluationResult evalResult;
          try {
            evalResult = await PayrollEvaluationService.evaluatePeriod(
              storeId: sid,
              periodId: p.targetPeriod!.id,
              fromDateStr: p.targetPeriod!.fromDate,
              toDateStr: p.targetPeriod!.toDate,
              status: p.targetPeriod!.status,
            ).timeout(const Duration(seconds: 12));
          } catch (e) {
            debugPrint('[PayrollReport] live evaluation fallback: $e');
            final savedRows = await db
                .from('payroll_records')
                .select()
                .eq('store_id', sid)
                .eq('period_id', p.targetPeriod!.id)
                .timeout(
                  const Duration(seconds: 8),
                  onTimeout: () => <Map<String, dynamic>>[],
                );
            final savedRecords = (savedRows as List)
                .map(
                  (r) => PayrollRecordModel.fromMap(r as Map<String, dynamic>),
                )
                .toList();
            final savedTotal = savedRecords.fold<double>(
              0,
              (sum, record) => sum + record.netPay,
            );
            evalResult = PayrollEvaluationResult(
              status: p.targetPeriod!.status,
              resolvedTotal: savedTotal,
              storedTotal: savedTotal,
              liveTotal: savedTotal,
              hasDelta: false,
              deltaAmount: 0,
              records: savedRecords,
            );
          }
          for (final r in evalResult.records) {
            final uid = r.userId;
            final shifts = userShiftMap[uid] ?? [];
            final cfg = configMap[uid];
            int pendingOt = 0;
            int forgotCount = 0;
            for (final s in shifts) {
              final calc = TinhLuongRepository.calculateSingleShiftEarnings(
                shift: s,
                config: cfg,
              );
              if (!s.isOtApproved && calc.overtimeHours > 0) pendingOt++;
              if (s.checkIsForgotClockout && !s.isManagerOverridden) {
                forgotCount++;
              }
            }
            grandPendingOt += pendingOt;
            grandForgotClockout += forgotCount;
            grandTotalHours += r.totalHours;
            summaries.add(
              _StaffSalarySummary(
                userId: uid,
                name: r.staffName,
                role: r.role ?? 'Nhân viên',
                totalHours: r.totalHours,
                overtimeHours: r.overtimeHours,
                regularPay: r.regularPay,
                overtimePay: r.overtimePay,
                deductionLate: r.deductionLate,
                totalNetPay: r.netPay,
                shiftCount: shifts.length,
                pendingOtCount: pendingOt,
                forgotClockoutCount: forgotCount,
                configuredExtras: r.bonusManual + r.allowanceTotal,
                shifts: shifts,
                config: cfg,
              ),
            );
          }
          grandTotalSalary = evalResult.resolvedTotal;
        } else {
          for (final entry in userShiftMap.entries) {
            final uid = entry.key;
            final shifts = entry.value;

            final m = memberMap[uid];
            final name =
                m?.name ??
                (shifts.isNotEmpty ? shifts.first.userName : 'Nhân viên');
            final role = m?.role ?? 'Nhân viên';

            final cfg = configMap[uid];

            double staffHours = 0;
            double staffNetPay = 0;
            int pendingOt = 0;
            int forgotCount = 0;

            double overtimeHours = 0;
            double regularPay = 0;
            double overtimePay = 0;
            double deductionLate = 0;

            for (final s in shifts) {
              final calc = TinhLuongRepository.calculateSingleShiftEarnings(
                shift: s,
                config: cfg,
              );
              staffHours += calc.totalHours;
              staffNetPay += calc.netPay;

              overtimeHours += calc.overtimeHours;
              regularPay += calc.regularPay;
              overtimePay += calc.overtimePay;
              deductionLate += calc.deductionLate;
              if (!s.isOtApproved && calc.overtimeHours > 0) pendingOt++;
              if (s.checkIsForgotClockout && !s.isManagerOverridden) {
                forgotCount++;
              }
            }

            grandTotalSalary += staffNetPay;
            grandTotalHours += staffHours;
            grandPendingOt += pendingOt;
            grandForgotClockout += forgotCount;

            summaries.add(
              _StaffSalarySummary(
                userId: uid,
                name: name,
                role: role,
                totalHours: staffHours,
                totalNetPay: staffNetPay,
                shiftCount: shifts.length,
                pendingOtCount: pendingOt,
                forgotClockoutCount: forgotCount,
                shifts: shifts,
                overtimeHours: overtimeHours,
                regularPay: regularPay,
                overtimePay: overtimePay,
                deductionLate: deductionLate,
                configuredExtras:
                    0.0, // Trong realtime loop cũ, configuredExtras chỉ tính khi chốt kỳ, tạm để 0
                config: cfg,
              ),
            );
          }
        }

        summaries.sort((a, b) => b.totalNetPay.compareTo(a.totalNetPay));

        return _RealtimeReportData(
          storeId: sid,
          totalSalary: grandTotalSalary,
          totalHours: grandTotalHours,
          activeStaffCount: summaries.length,
          pendingOtCount: grandPendingOt,
          forgotClockoutCount: grandForgotClockout,
          staffSummaries: summaries,
          fromDate: DateTime.parse(fromIso),
          toDate: DateTime.parse(toIso),
        );
      } catch (e) {
        debugPrint('[PayrollReport] fetch error: $e');
        throw Exception('Không thể tải báo cáo. Vui lòng thử lại.');
      }
    });

// ─── Main Screen ─────────────────────────────────────────────────────────────

class PayrollReportScreen extends ConsumerStatefulWidget {
  final PayrollPeriodModel? targetPeriod;
  const PayrollReportScreen({super.key, this.targetPeriod});

  @override
  ConsumerState<PayrollReportScreen> createState() =>
      _PayrollReportScreenState();
}

class _PayrollReportScreenState extends ConsumerState<PayrollReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  SalaryReportPeriod _period = SalaryReportPeriod.month;
  DateTime _selectedDay = DateTime.now();
  DateTime _weekStart = _mondayOf(DateTime.now());
  int _navYear = DateTime.now().year;
  int _navMonth = DateTime.now().month;

  static DateTime _mondayOf(DateTime d) {
    final m = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  _ReportParam get _currentParam => _ReportParam(
    period: _period,
    selectedDay: _selectedDay,
    weekStart: _weekStart,
    navYear: _navYear,
    navMonth: _navMonth,
    targetPeriod: widget.targetPeriod,
  );

  @override
  Widget build(BuildContext context) {
    final permsAsync = ref.watch(userActionPermsProvider);

    return permsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: _kCream,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: _kCream,
        appBar: AppBar(
          backgroundColor: _kNavy,
          foregroundColor: Colors.white,
          title: const Text('Báo cáo lương'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Không thể kiểm tra quyền truy cập',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => ref.invalidate(userActionPermsProvider),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      data: (perms) {
        if (!perms.contains('tinhluong.view_all')) {
          return Scaffold(
            backgroundColor: _kCream,
            appBar: AppBar(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              title: const Text('Báo cáo lương'),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bạn không có quyền xem báo cáo lương',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lại'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final async = ref.watch(_realtimeReportProv(_currentParam));

        return Scaffold(
          backgroundColor: _kCream,
          appBar: AppBar(
            backgroundColor: _kNavy,
            foregroundColor: Colors.white,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Báo cáo lương',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
                Text(
                  'Tổng hợp giờ làm và lương dự kiến',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () =>
                    ref.invalidate(_realtimeReportProv(_currentParam)),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  // ── Period Pills + Navigator Row ──
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      children: [
                        _PeriodPills(
                          current: _period,
                          onChanged: (p) => setState(() => _period = p),
                        ),
                        const SizedBox(height: 8),
                        if (_period == SalaryReportPeriod.today)
                          _ReportNavBar.day(
                            date: _selectedDay,
                            canGoNext:
                                DateTime(
                                  _selectedDay.year,
                                  _selectedDay.month,
                                  _selectedDay.day,
                                ).isBefore(
                                  DateTime(
                                    DateTime.now().year,
                                    DateTime.now().month,
                                    DateTime.now().day,
                                  ),
                                ),
                            onPrev: () => setState(
                              () => _selectedDay = _selectedDay.subtract(
                                const Duration(days: 1),
                              ),
                            ),
                            onNext: () => setState(
                              () => _selectedDay = _selectedDay.add(
                                const Duration(days: 1),
                              ),
                            ),
                            onPick: () => _pickDay(context),
                          ),
                        if (_period == SalaryReportPeriod.week)
                          _ReportNavBar.week(
                            weekStart: _weekStart,
                            canGoNext: _weekStart
                                .add(const Duration(days: 7))
                                .isBefore(
                                  DateTime.now().add(const Duration(days: 1)),
                                ),
                            onPrev: () => setState(
                              () => _weekStart = _weekStart.subtract(
                                const Duration(days: 7),
                              ),
                            ),
                            onNext: () => setState(
                              () => _weekStart = _weekStart.add(
                                const Duration(days: 7),
                              ),
                            ),
                            onPick: () => _pickWeek(context),
                          ),
                        if (_period == SalaryReportPeriod.month)
                          _ReportNavBar.month(
                            year: _navYear,
                            month: _navMonth,
                            canGoNext:
                                !(_navYear == DateTime.now().year &&
                                    _navMonth == DateTime.now().month),
                            onPrev: () => setState(() {
                              if (_navMonth == 1) {
                                _navYear--;
                                _navMonth = 12;
                              } else {
                                _navMonth--;
                              }
                            }),
                            onNext: () => setState(() {
                              if (_navMonth == 12) {
                                _navYear++;
                                _navMonth = 1;
                              } else {
                                _navMonth++;
                              }
                            }),
                            onPick: () => _pickMonth(context),
                          ),
                      ],
                    ),
                  ),

                  // ── Header Metric Summary ──
                  async.when(
                    loading: () => Container(
                      height: 100,
                      color: _kNavy,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                    error: (e, _) => Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.red.shade50,
                      child: Column(
                        children: [
                          const Text(
                            'Không thể tải báo cáo. Vui lòng thử lại.',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 44,
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => ref.invalidate(
                                _realtimeReportProv(_currentParam),
                              ),
                              child: const Text('Thử lại'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    data: (data) => _HeaderSummaryCard(data: data),
                  ),

                  // ── TabBar ──
                  Container(
                    color: _kNavy,
                    child: TabBar(
                      controller: _tab,
                      indicatorColor: _kOrange,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white54,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      tabs: const [
                        Tab(text: 'Tổng Quan Kỳ'),
                        Tab(text: 'Theo Nhân Viên'),
                      ],
                    ),
                  ),

                  // ── Body ──
                  Expanded(
                    child: async.when(
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Không thể tải báo cáo. Vui lòng thử lại.',
                              style: TextStyle(color: Colors.red, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () => ref.invalidate(
                                  _realtimeReportProv(_currentParam),
                                ),
                                child: const Text('Thử lại'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      data: (data) => TabBarView(
                        controller: _tab,
                        children: [
                          _OverviewSection(data: data),
                          _StaffListSection(
                            data: data,
                            onRefresh: () =>
                                ref.invalidate(_realtimeReportProv),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickDay(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      setState(() => _selectedDay = picked);
    }
  }

  Future<void> _pickWeek(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('vi'),
    );
    if (picked != null) {
      final mon = picked.subtract(Duration(days: picked.weekday - 1));
      setState(() => _weekStart = DateTime(mon.year, mon.month, mon.day));
    }
  }

  Future<void> _pickMonth(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_navYear, _navMonth, 1),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDatePickerMode: DatePickerMode.year,
      locale: const Locale('vi'),
    );
    if (picked != null) {
      setState(() {
        _navYear = picked.year;
        _navMonth = picked.month;
      });
    }
  }
}

// ─── Metric Header Summary Card ──────────────────────────────────────────────

class _HeaderSummaryCard extends StatelessWidget {
  final _RealtimeReportData data;
  const _HeaderSummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C2151), Color(0xFF2A3A8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TỔNG LƯƠNG THỜI GIAN THỰC',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _fmtM(data.totalSalary),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${data.activeStaffCount} nhân sự',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      '${data.totalHours.toStringAsFixed(1)}h làm việc',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (data.pendingOtCount > 0 || data.forgotClockoutCount > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (data.pendingOtCount > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFFACC15).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.stars_rounded,
                          color: Color(0xFFFACC15),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '🟡 ${data.pendingOtCount} ca chờ duyệt OT',
                          style: const TextStyle(
                            color: Color(0xFFFACC15),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (data.forgotClockoutCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF87171).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: const Color(0xFFF87171).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF87171),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '🔴 ${data.forgotClockoutCount} ca chưa được xác nhận (>14h)',
                          style: const TextStyle(
                            color: Color(0xFFF87171),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Overview Section ─────────────────────────────────────────────────────────

class _OverviewSection extends StatelessWidget {
  final _RealtimeReportData data;
  const _OverviewSection({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StatCard(
          icon: Icons.people_outline_rounded,
          color: const Color(0xFF3B82F6),
          title: 'Tổng Nhân Viên Làm Việc',
          value: '${data.activeStaffCount} người',
          subText: 'Có ca làm trong kỳ chọn',
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.access_time_rounded,
          color: const Color(0xFF10B981),
          title: 'Tổng Số Giờ Tích Lũy',
          value: '${data.totalHours.toStringAsFixed(1)} giờ',
          subText: 'Toàn bộ ca làm hoàn thành',
        ),
        const SizedBox(height: 12),
        _StatCard(
          icon: Icons.monetization_on_outlined,
          color: const Color(0xFFFF6B35),
          title: 'Chi Phí Lương Ca Tạm Tính',
          value: _fmtM(data.totalSalary),
          subText: 'Tính theo cấu hình M1-M4 & OT/khấu trừ',
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String subText;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.subText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kNavy,
                  ),
                ),
                Text(
                  subText,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Staff List Section ───────────────────────────────────────────────────────

class _StaffListSection extends StatelessWidget {
  final _RealtimeReportData data;
  final VoidCallback onRefresh;

  const _StaffListSection({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (data.staffSummaries.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_rounded,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 12),
            const Text(
              'Không có ca làm việc nào trong khoảng thời gian này',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: data.staffSummaries.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (ctx, idx) {
        final s = data.staffSummaries[idx];
        return Card(
          margin: EdgeInsets.zero,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showStaffAuditSheet(ctx, data.storeId, s, onRefresh),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: idx == 0
                          ? const Color(0xFFEAB308)
                          : (idx == 1
                                ? const Color(0xFF94A3B8)
                                : (idx == 2
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFFF1F5F9))),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${idx + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          color: idx < 3
                              ? Colors.white
                              : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: _kNavy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${s.role} · ${s.shiftCount} ca · ${s.totalHours.toStringAsFixed(1)}h',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                        if (s.pendingOtCount > 0 ||
                            s.forgotClockoutCount > 0) ...[
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              if (s.pendingOtCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFACC15,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '🟡 ${s.pendingOtCount} OT',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                              if (s.forgotClockoutCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFF87171,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '🔴 ${s.forgotClockoutCount} Quên chốt',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        _fmtM(s.totalNetPay),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chi tiết ca →',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showStaffAuditSheet(
    BuildContext context,
    String storeId,
    _StaffSalarySummary staff,
    VoidCallback onRefresh,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffShiftAuditSheet(
        storeId: storeId,
        staff: staff,
        onRefresh: onRefresh,
      ),
    );
    onRefresh();
  }
}

// ─── Staff Shift Audit Sheet ───────────────────────────────────────────────

class _StaffShiftAuditSheet extends ConsumerStatefulWidget {
  final String storeId;
  final _StaffSalarySummary staff;
  final VoidCallback onRefresh;

  const _StaffShiftAuditSheet({
    required this.storeId,
    required this.staff,
    required this.onRefresh,
  });

  @override
  ConsumerState<_StaffShiftAuditSheet> createState() =>
      _StaffShiftAuditSheetState();
}

class _StaffShiftAuditSheetState extends ConsumerState<_StaffShiftAuditSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final permsAsync = ref.watch(userActionPermsProvider);
    final canApprove = permsAsync.maybeWhen(
      data: (d) => d.contains('tinhluong.approve_payroll'),
      orElse: () => false,
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.staff.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _kNavy,
                        ),
                      ),
                      Text(
                        '${widget.staff.role} · Tổng ${widget.staff.shiftCount} ca làm việc',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _fmtM(widget.staff.totalNetPay),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16A34A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            const Text(
              'DANH SÁCH CA LÀM VIỆC',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 12),
            ...widget.staff.shifts.map(
              (shift) => _buildShiftAuditRow(context, shift, canApprove),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftAuditRow(
    BuildContext context,
    ShiftRecord shift,
    bool canApprove,
  ) {
    final calc = TinhLuongRepository.calculateSingleShiftEarnings(shift: shift);
    final dateStr = DateFormat('dd/MM/yyyy').format(shift.clockIn.toLocal());
    final inTime = DateFormat('HH:mm').format(shift.clockIn.toLocal());
    final outTime = shift.clockOut != null
        ? DateFormat('HH:mm').format(shift.clockOut!.toLocal())
        : '--:--';

    final isForgot = shift.checkIsForgotClockout;
    final isOtUnapproved = !shift.isOtApproved && calc.overtimeHours > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dateStr,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    color: _kNavy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$inTime → $outTime (${calc.totalHours.toStringAsFixed(1)}h)',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                _fmtM(calc.netPay),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: Color(0xFF16A34A),
                ),
              ),
            ],
          ),
          if (calc.bonusReasons.isNotEmpty ||
              calc.penaltyReasons.isNotEmpty) ...[
            const SizedBox(height: 6),
            ...calc.bonusReasons.map(
              (r) => Text(
                r,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...calc.penaltyReasons.map(
              (r) => Text(
                r,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (canApprove &&
              (isOtUnapproved || (isForgot && !shift.isManagerOverridden))) ...[
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (ctx, constraints) {
                final showBoth =
                    isOtUnapproved && isForgot && !shift.isManagerOverridden;
                final btnOt = isOtUnapproved
                    ? SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _showApproveOtDialog(context, shift),
                          icon: _loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.check_circle_outline_rounded,
                                  size: 14,
                                  color: Color(0xFF16A34A),
                                ),
                          label: const Text(
                            'Xác nhận OT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF16A34A)),
                          ),
                        ),
                      )
                    : const SizedBox.shrink();

                final btnForgot = (isForgot && !shift.isManagerOverridden)
                    ? SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _loading
                              ? null
                              : () => _showOverrideShiftDialog(context, shift),
                          icon: _loading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: Color(0xFF2563EB),
                                ),
                          label: const Text(
                            'Xác nhận ca quên chốt',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF2563EB)),
                          ),
                        ),
                      )
                    : const SizedBox.shrink();

                if (constraints.maxWidth < 360 && showBoth) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [btnOt, const SizedBox(height: 8), btnForgot],
                  );
                }

                return Row(
                  children: [
                    if (isOtUnapproved) Expanded(child: btnOt),
                    if (showBoth) const SizedBox(width: 8),
                    if (isForgot && !shift.isManagerOverridden)
                      Expanded(child: btnForgot),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showApproveOtDialog(
    BuildContext context,
    ShiftRecord shift,
  ) async {
    final reasonCtrl = TextEditingController(text: 'Xác nhận OT theo yêu cầu');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Xác nhận tăng ca (OT)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Xác nhận duyệt giờ tăng ca OT cho nhân viên này? Giờ OT sẽ được tính vào tổng thời gian làm việc.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Xác nhận',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentPerms = ref
          .read(userActionPermsProvider)
          .maybeWhen(
            data: (d) => d.contains('tinhluong.approve_payroll'),
            orElse: () => false,
          );
      if (!currentPerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Bạn không có quyền duyệt lương.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _loading = true);
      try {
        await StaffService.approveOt(
          shiftId: shift.id,
          otReason: reasonCtrl.text.trim(),
          approvedBy: 'Quản Lý',
          storeId: widget.storeId,
          staffName: shift.userName,
        );
        if (mounted) {
          setState(() {
            _loading = false;
            final idx = widget.staff.shifts.indexWhere((s) => s.id == shift.id);
            if (idx != -1) {
              widget.staff.shifts[idx] = shift.copyWith(
                isOtApproved: true,
                otReason: reasonCtrl.text.trim(),
                otApprovedBy: 'Quản Lý',
              );
            }
          });
          widget.onRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã xác nhận OT thành công'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Không thể xác nhận OT. Vui lòng thử lại.'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showOverrideShiftDialog(
    BuildContext context,
    ShiftRecord shift,
  ) async {
    final reasonCtrl = TextEditingController(text: 'Xác nhận ca quên chốt');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Xác nhận ca quên chốt',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn xác nhận thời gian làm việc thực tế cho ca quên chốt này chứ?',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Ghi chú',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
          ),
          SizedBox(
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'Xác nhận',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final currentPerms = ref
          .read(userActionPermsProvider)
          .maybeWhen(
            data: (d) => d.contains('tinhluong.approve_payroll'),
            orElse: () => false,
          );
      if (!currentPerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Bạn không có quyền duyệt lương.'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _loading = true);
      try {
        await StaffService.overrideShift(
          shiftId: shift.id,
          storeId: widget.storeId,
          overrideReason: reasonCtrl.text.trim(),
          approvedBy: 'Quản Lý',
          staffName: shift.userName,
        );
        if (mounted) {
          setState(() {
            _loading = false;
            final idx = widget.staff.shifts.indexWhere((s) => s.id == shift.id);
            if (idx != -1) {
              widget.staff.shifts[idx] = shift.copyWith(
                isManagerOverridden: true,
                overrideReason: reasonCtrl.text.trim(),
                overrideBy: 'Quản Lý',
              );
            }
          });
          widget.onRefresh();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Đã xác nhận ca quên chốt thành công'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '❌ Không thể xác nhận ca quên chốt. Vui lòng thử lại.',
              ),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// ─── Period Pills Widget ─────────────────────────────────────────────────────

class _PeriodPills extends StatelessWidget {
  final SalaryReportPeriod current;
  final ValueChanged<SalaryReportPeriod> onChanged;

  const _PeriodPills({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _kNavy.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: SalaryReportPeriod.values
          .map(
            (p) => Expanded(
              child: GestureDetector(
                onTap: () => onChanged(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: current == p ? _kNavy : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: current == p
                        ? [
                            BoxShadow(
                              color: _kNavy.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    p.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: current == p ? Colors.white : _kMuted,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
}

// ─── Report NavBar Widget (Date/Week/Month Picker) ────────────────────────────

class _ReportNavBar extends StatefulWidget {
  final String label;
  final bool canGoNext;
  final VoidCallback onPrev, onNext, onPick;

  const _ReportNavBar({
    required this.label,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
    required this.onPick,
  });

  factory _ReportNavBar.day({
    required DateTime date,
    required bool canGoNext,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onPick,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    final String label;
    if (selected == today) {
      label = 'Hôm nay';
    } else if (selected == today.subtract(const Duration(days: 1))) {
      label = 'Hôm qua';
    } else if (selected == today.subtract(const Duration(days: 2))) {
      label = 'Hôm kia';
    } else {
      label = DateFormat('dd/MM/yyyy').format(date);
    }
    return _ReportNavBar(
      label: label,
      canGoNext: canGoNext,
      onPrev: onPrev,
      onNext: onNext,
      onPick: onPick,
    );
  }

  factory _ReportNavBar.week({
    required DateTime weekStart,
    required bool canGoNext,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onPick,
  }) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final startStr = DateFormat('dd/MM').format(weekStart);
    final endStr = DateFormat('dd/MM').format(weekEnd);
    final wk =
        ((int.parse(DateFormat('D').format(weekStart)) -
                    weekStart.weekday +
                    10) /
                7)
            .floor();
    return _ReportNavBar(
      label: 'Tuần $wk · $startStr–$endStr',
      canGoNext: canGoNext,
      onPrev: onPrev,
      onNext: onNext,
      onPick: onPick,
    );
  }

  factory _ReportNavBar.month({
    required int year,
    required int month,
    required bool canGoNext,
    required VoidCallback onPrev,
    required VoidCallback onNext,
    required VoidCallback onPick,
  }) {
    return _ReportNavBar(
      label: 'Tháng $month / $year',
      canGoNext: canGoNext,
      onPrev: onPrev,
      onNext: onNext,
      onPick: onPick,
    );
  }

  @override
  State<_ReportNavBar> createState() => _ReportNavBarState();
}

class _ReportNavBarState extends State<_ReportNavBar> {
  int _dir = 1;

  void _prev() {
    HapticFeedback.lightImpact();
    setState(() => _dir = -1);
    widget.onPrev();
  }

  void _next() {
    HapticFeedback.lightImpact();
    setState(() => _dir = 1);
    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kNavy.withValues(alpha: 0.07),
            _kNavy.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kNavy.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          _RNavBtn(icon: Icons.chevron_left_rounded, onTap: _prev),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onPick();
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position:
                        Tween<Offset>(
                          begin: Offset(_dir * 0.3, 0),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                            parent: anim,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                    child: child,
                  ),
                ),
                child: Row(
                  key: ValueKey(widget.label),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 15,
                      color: _kNavy,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _RNavBtn(
            icon: Icons.chevron_right_rounded,
            onTap: widget.canGoNext ? _next : null,
          ),
        ],
      ),
    );
  }
}

class _RNavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _RNavBtn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: disabled ? Colors.grey.shade300 : _kNavy,
          ),
        ),
      ),
    );
  }
}
