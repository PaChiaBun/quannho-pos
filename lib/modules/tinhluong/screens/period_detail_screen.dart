import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/tinhluong_providers.dart';
import '../repository/tinhluong_repository.dart';
import 'payroll_report_screen.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/providers/session_provider.dart';

final _fmt = NumberFormat('#,###', 'vi_VN');
String _fmtM(double v) => '${_fmt.format(v.round())}đ';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream = Color(0xFFF9FAFB);

class PeriodDetailScreen extends ConsumerStatefulWidget {
  final PayrollPeriodModel period;
  const PeriodDetailScreen({super.key, required this.period});

  @override
  ConsumerState<PeriodDetailScreen> createState() => _PeriodDetailScreenState();
}

class _PeriodDetailScreenState extends ConsumerState<PeriodDetailScreen> {
  String _searchQuery = '';
  String _selectedRole = 'Tất cả';
  String _payFilter = 'Tất cả'; // Tất cả | Chưa trả | Đã trả
  @override
  Widget build(BuildContext context) {
    final permsAsync = ref.watch(userActionPermsProvider);
    final perms = permsAsync.value ?? {};
    final canApprove = perms.contains('tinhluong.approve_payroll');
    final canReport = perms.contains('tinhluong.view_all');

    final recordsAsync = ref.watch(payrollRecordsProvider(widget.period.id));

    return Scaffold(
      backgroundColor: _kCream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          List<Widget> actions = [];

          if (!isNarrow) {
            if (canReport) {
              actions.add(
                TextButton.icon(
                  icon: const Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'Báo cáo KPI',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PayrollReportScreen(targetPeriod: widget.period),
                      ),
                    );
                  },
                ),
              );
            }
            if (widget.period.isDraft && canApprove) {
              actions.add(
                TextButton.icon(
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'Gửi duyệt',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    final readiness = ref
                        .read(payrollReadinessProvider(widget.period))
                        .value;
                    _submitForReview(context, readiness);
                  },
                ),
              );
            }
            if (widget.period.isDraft && canApprove) {
              actions.add(
                TextButton.icon(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: const Text(
                    'Tính lại',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _recalculate(context),
                ),
              );
            }
            if (widget.period.status == 'pending_review' && canApprove) {
              actions.add(
                TextButton.icon(
                  icon: const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF4ADE80),
                    size: 16,
                  ),
                  label: const Text(
                    'Duyệt kỳ',
                    style: TextStyle(
                      color: Color(0xFF4ADE80),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => _approve(context),
                ),
              );
            }
            if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
          } else {
            List<PopupMenuEntry<String>> menuItems = [];
            if (canReport) {
              menuItems.add(
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.bar_chart_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Báo cáo KPI'),
                    ],
                  ),
                ),
              );
            }
            if (widget.period.isDraft && canApprove) {
              menuItems.add(
                const PopupMenuItem(
                  value: 'submit',
                  child: Row(
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Gửi duyệt'),
                    ],
                  ),
                ),
              );
            }
            if (widget.period.status == 'pending_review' && canApprove) {
              menuItems.add(
                const PopupMenuItem(
                  value: 'approve',
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: Colors.green,
                      ),
                      SizedBox(width: 12),
                      Text('Duyệt kỳ'),
                    ],
                  ),
                ),
              );
            }
            if (menuItems.isNotEmpty) {
              actions.add(
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white,
                  ),
                  tooltip: 'Tùy chọn',
                  onSelected: (val) {
                    if (val == 'report') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PayrollReportScreen(targetPeriod: widget.period),
                        ),
                      );
                    }
                    if (val == 'submit') {
                      final readiness = ref
                          .read(payrollReadinessProvider(widget.period))
                          .value;
                      _submitForReview(context, readiness);
                    }
                    if (val == 'recalc') {
                      _recalculate(context);
                    }
                    if (val == 'approve') {
                      _approve(context);
                    }

                  },
                  itemBuilder: (_) => menuItems,
                ),
              );
            }
            if (widget.period.isDraft && canApprove) {
              menuItems.add(
                const PopupMenuItem(
                  value: 'recalc',
                  child: Row(
                    children: [
                      Icon(Icons.refresh_rounded, size: 18),
                      SizedBox(width: 12),
                      Text('Tính lại'),
                    ],
                  ),
                ),
              );
            }

          }

          return RefreshIndicator(
            color: _kNavy,
            onRefresh: () async {
              ref.invalidate(payrollRecordsProvider(widget.period.id));
              ref.invalidate(payrollPeriodsProvider);
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      pinned: true,
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.period.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '${widget.period.fromDate} → ${widget.period.toDate}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                      actions: actions,
                    ),
                    recordsAsync.when(
                      loading: () => const SliverFillRemaining(
                        child: Center(
                          child: CircularProgressIndicator(color: _kNavy),
                        ),
                      ),
                      error: (e, _) => SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Không thể tải chi tiết kỳ lương',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Vui lòng kiểm tra kết nối và thử lại.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ref.invalidate(
                                    payrollRecordsProvider(widget.period.id),
                                  );
                                  ref.invalidate(payrollPeriodsProvider);
                                },
                                icon: const Icon(
                                  Icons.refresh_rounded,
                                  size: 20,
                                ),
                                label: const Text('Thử lại'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _kNavy,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      data: (records) => _buildSliverBody(records, canApprove),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSliverBody(List<PayrollRecordModel> records, bool canApprove) {
    if (records.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.group_off_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Không có dữ liệu nhân viên',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final liveTotal = records.fold(0.0, (s, r) => s + r.netPay);
    double totalHoursAll = 0;
    int activeStaffCount = 0;
    int paidCount = 0;

    for (final r in records) {
      totalHoursAll += r.totalHours;
      if (r.totalHours > 0 || r.netPay > 0) activeStaffCount++;
      if (r.paymentStatus == 'paid') paidCount++;
    }

    final totalDaysCong = totalHoursAll / 8.0;

    final filtered = records.where((r) {
      if (_searchQuery.isNotEmpty &&
          !r.staffName.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedRole != 'Tất cả' &&
          (r.role ?? 'Nhân viên') != _selectedRole) {
        return false;
      }
      if (_payFilter == 'Chưa trả' && r.paymentStatus == 'paid') return false;
      if (_payFilter == 'Đã trả' && r.paymentStatus != 'paid') return false;
      return true;
    }).toList();

    filtered.sort((a, b) => b.netPay.compareTo(a.netPay));
    final roles = {
      'Tất cả',
      ...records.map((r) => r.role ?? 'Nhân viên').where((r) => r.isNotEmpty),
    };

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: _ReadinessDashboard(
            period: widget.period,
            onRecalculate: () => _recalculate(context),
          ),
        ),
        if (widget.period.hasDelta)
          SliverToBoxAdapter(
            child: _DeltaWarningBanner(
              period: widget.period,
              onUpdate: () => _recalculate(context),
            ),
          ),
        SliverToBoxAdapter(
          child: _HeaderDashboard(
            period: widget.period,
            liveTotal: liveTotal,
            totalDaysCong: totalDaysCong,
            totalHoursAll: totalHoursAll,
            activeStaffCount: activeStaffCount,
            totalStaffCount: records.length,
            paidCount: paidCount,
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Tìm theo tên nhân viên...',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: _kNavy,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: _kCream,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...['Tất cả', 'Chưa trả', 'Đã trả'].map(
                        (pf) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: _payFilter == pf,
                            label: Text(
                              pf,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _payFilter == pf ? Colors.white : _kNavy,
                              ),
                            ),
                            selectedColor: _kNavy,
                            backgroundColor: _kCream,
                            onSelected: (_) => setState(() => _payFilter = pf),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.transparent),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(width: 1, height: 20, color: Colors.grey[300]),
                      const SizedBox(width: 8),
                      ...roles.map(
                        (role) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: FilterChip(
                            selected: _selectedRole == role,
                            label: Text(
                              role,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _selectedRole == role
                                    ? Colors.white
                                    : _kOrange,
                              ),
                            ),
                            selectedColor: _kOrange,
                            backgroundColor: Colors.orange.shade50,
                            onSelected: (_) =>
                                setState(() => _selectedRole = role),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: const BorderSide(color: Colors.transparent),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                'Không tìm thấy nhân viên phù hợp',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 600,
                mainAxisExtent: 160,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate((ctx, idx) {
                final rec = filtered[idx];
                return _StaffSalaryCard(
                  record: rec,
                  onTap: () => _showPayslipSheet(context, rec, canApprove),
                  onPay: (widget.period.isApproved && canApprove)
                      ? () => _markPaid(context, rec)
                      : null,
                );
              }, childCount: filtered.length),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Future<void> _submitForReview(
    BuildContext context,
    PayrollReadiness? readiness,
  ) async {
    if (readiness == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dữ liệu trạng thái đang tải hoặc có lỗi. Vui lòng thử lại sau.',
          ),
        ),
      );
      return;
    }
    if (!readiness.canSubmit) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text(
            'Không thể gửi duyệt',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Kỳ lương chưa sẵn sàng do còn các vấn đề sau:'),
              const SizedBox(height: 8),
              ...readiness.blockingReasons.map(
                (r) => Text('• $r', style: const TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Vui lòng xử lý trước khi gửi duyệt.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
      return;
    }

    await TinhLuongRepository.updatePeriodStatus(
      widget.period.id,
      'pending_review',
    );
    ref.invalidate(payrollPeriodsProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('✅ Đã gửi duyệt kỳ lương')));
  }

  Future<void> _recalculate(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tính lại kỳ lương?'),
        content: const Text(
          'Hành động này sẽ tính toán lại toàn bộ dữ liệu lương (dựa trên ca làm và cấu hình lương MỚI NHẤT) '
          'cho những nhân viên đang hoạt động.\n\n'
          'Dữ liệu những bản ghi chưa bị khóa sẽ bị ghi đè. Bạn có chắc chắn muốn tiếp tục?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(c, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tính lại'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final storeId = ref.read(sessionProvider)?.storeId;
    if (storeId == null || storeId.isEmpty || !context.mounted) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await TinhLuongRepository.autoGenerateRecordsForPeriod(
        storeId: storeId,
        periodId: widget.period.id,
        fromDateStr: widget.period.fromDate,
        toDateStr: widget.period.toDate,
      );
      if (context.mounted) {
        Navigator.pop(context); // hide loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã tính lại thành công!')),
        );
        ref.invalidate(payrollRecordsProvider(widget.period.id));
        ref.invalidate(payrollPeriodsProvider);
        ref.invalidate(payrollReadinessProvider(widget.period));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Lỗi tính lại: $e')));
      }
    }
  }

  Future<void> _approve(BuildContext context) async {
    final storeId = ref.read(sessionProvider)?.storeId;
    if (storeId == null || storeId.isEmpty || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await TinhLuongRepository.autoGenerateRecordsForPeriod(
        storeId: storeId,
        periodId: widget.period.id,
        fromDateStr: widget.period.fromDate,
        toDateStr: widget.period.toDate,
      );
      await TinhLuongRepository.updatePeriodStatus(widget.period.id, 'approved');
      if (context.mounted) {
        Navigator.pop(context); // hide loading
        ref.invalidate(payrollPeriodsProvider);
        ref.invalidate(payrollRecordsProvider(widget.period.id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Đã duyệt kỳ lương')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Lỗi khi duyệt kỳ lương: $e')),
        );
      }
    }
  }

  Future<void> _markPaid(
    BuildContext context,
    PayrollRecordModel record,
  ) async {
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentMethodSheet(staffName: record.staffName),
    );
    if (method == null) return;
    await TinhLuongRepository.markRecordPaid(
      id: record.id,
      paymentMethod: method,
    );

    ref.invalidate(payrollRecordsProvider(widget.period.id));
    ref.invalidate(payrollPeriodsProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Đã trả lương cho ${record.staffName}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showPayslipSheet(
    BuildContext context,
    PayrollRecordModel record,
    bool canApprove,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffPayslipSheet(
        period: widget.period,
        record: record,
        canApprove: canApprove,
        onRefresh: () {
          ref.invalidate(payrollRecordsProvider(widget.period.id));
          ref.invalidate(payrollPeriodsProvider);
        },
      ),
    );
  }
}

// ─── HEADER DASHBOARD ────────────────────────────────────────────────────────

class _HeaderDashboard extends StatelessWidget {
  final PayrollPeriodModel period;
  final double liveTotal;
  final double totalDaysCong;
  final double totalHoursAll;
  final int activeStaffCount;
  final int totalStaffCount;
  final int paidCount;

  const _HeaderDashboard({
    required this.period,
    required this.liveTotal,
    required this.totalDaysCong,
    required this.totalHoursAll,
    required this.activeStaffCount,
    required this.totalStaffCount,
    required this.paidCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C2151), Color(0xFF2A3A8F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TỔNG QUỸ LƯƠNG',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _fmtM(liveTotal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _StatusBadge(status: period.status),
              const SizedBox(height: 6),
              Text(
                '${totalDaysCong.toStringAsFixed(1)} Công (~${totalHoursAll.toStringAsFixed(0)}h)',
                style: const TextStyle(
                  color: Color(0xFF69F0AE),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                '$activeStaffCount NV có ca · Đã trả: $paidCount/$totalStaffCount (${totalStaffCount == 0 ? 0 : (paidCount / totalStaffCount * 100).toStringAsFixed(0)}%)',
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
              const SizedBox(height: 6),
              const Text(
                'Bản nháp: Dữ liệu chốt tại thời điểm tạo/tính lại',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── DELTA WARNING BANNER ────────────────────────────────────────────────────

class _DeltaWarningBanner extends StatelessWidget {
  final PayrollPeriodModel period;
  final VoidCallback onUpdate;

  const _DeltaWarningBanner({required this.period, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        border: Border.all(color: const Color(0xFFFFCC80)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dữ liệu đã thay đổi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                Text(
                  'Có sự thay đổi về ca làm/cấu hình: ${_fmtM(period.deltaAmount)}. Cập nhật để áp dụng thay đổi.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFFE65100)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Cập nhật'),
          ),
        ],
      ),
    );
  }
}

// ─── READINESS DASHBOARD ─────────────────────────────────────────────────────

class _ReadinessDashboard extends ConsumerWidget {
  final PayrollPeriodModel period;
  final VoidCallback onRecalculate;

  const _ReadinessDashboard({
    required this.period,
    required this.onRecalculate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!period.isDraft) return const SizedBox.shrink();

    final readinessAsync = ref.watch(payrollReadinessProvider(period));

    return readinessAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade800),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Lỗi tải trạng thái kiểm tra. Vui lòng thử lại sau.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      data: (readiness) {
        if (readiness.canSubmit) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kỳ lương đã sẵn sàng gửi duyệt',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Kỳ lương chưa sẵn sàng (còn ${readiness.blockingReasons.length} vấn đề)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onRecalculate,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Tính lại'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade900,
                      backgroundColor: Colors.red.shade100,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...readiness.blockingReasons.map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 36),
                  child: Text(
                    '• $r',
                    style: TextStyle(color: Colors.red.shade900, fontSize: 12),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Padding(
                padding: EdgeInsets.only(left: 36),
                child: Text(
                  'Vui lòng chốt ca, duyệt OT và cấu hình lương, sau đó bấm "Tính lại".',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── BOXED STAFF SALARY CARD ─────────────────────────────────────────────────

class _StaffSalaryCard extends StatelessWidget {
  final PayrollRecordModel record;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  const _StaffSalaryCard({
    required this.record,
    required this.onTap,
    this.onPay,
  });

  Color _roleColor(String? role) {
    final r = (role ?? '').toLowerCase();
    if (r.contains('bếp')) {
      return const Color(0xFFFF6B35);
    }
    if (r.contains('thu ngân')) {
      return const Color(0xFF8B5CF6);
    }
    if (r.contains('pha chế') || r.contains('bar')) {
      return const Color(0xFF06B6D4);
    }
    if (r.contains('quản lý') || r.contains('chủ')) {
      return const Color(0xFFEAB308);
    }
    return const Color(0xFF1C2151);
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = record.paymentStatus == 'paid';
    final rColor = _roleColor(record.role);
    final daysCong = record.totalHours / 8.0;

    final income =
        record.regularPay +
        record.overtimePay +
        record.bonusManual +
        record.bonusRevenue +
        record.allowanceTotal;
    final deductions =
        record.deductionLate + record.deductionAbsent + record.deductionManual;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Avatar, Name, Net Pay & Status
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: rColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: rColor.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        record.staffName.isNotEmpty
                            ? record.staffName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: rColor,
                          fontSize: 15,
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
                          record.staffName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: _kNavy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${record.role ?? "Nhân viên"} · ${daysCong.toStringAsFixed(1)} công',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'THỰC LĨNH',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        _fmtM(record.netPay),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isPaid)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '✅ Đã trả',
                            style: TextStyle(
                              color: Color(0xFF16A34A),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      else if (onPay != null)
                        SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF16A34A),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: onPay,
                            child: const Text(
                              'Trả lương',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Row 2: Thu nhập & Khấu trừ
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'THU NHẬP',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF047857),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _fmtM(income),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF047857),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'KHẤU TRỪ',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFB91C1C),
                            ),
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _fmtM(deductions),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── PAYSLIP SHEET ──────────────────────────────────────────────────────────

class _StaffPayslipSheet extends StatefulWidget {
  final PayrollPeriodModel period;
  final PayrollRecordModel record;
  final bool canApprove;
  final VoidCallback onRefresh;

  const _StaffPayslipSheet({
    required this.period,
    required this.record,
    required this.canApprove,
    required this.onRefresh,
  });

  @override
  State<_StaffPayslipSheet> createState() => _StaffPayslipSheetState();
}

class _StaffPayslipSheetState extends State<_StaffPayslipSheet> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final daysCong = r.totalHours / 8.0;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
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
                        r.staffName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: _kNavy,
                        ),
                      ),
                      Text(
                        '${r.role ?? "Nhân viên"} · ${daysCong.toStringAsFixed(1)} công (${r.totalHours.toStringAsFixed(1)}h làm)',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Thực lĩnh',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _fmtM(r.netPay),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // SECTION: THU NHẬP
            const _SectionHeader(title: 'THU NHẬP', color: Color(0xFF16A34A)),
            _DetailRow(label: 'Lương cơ bản', value: _fmtM(r.regularPay)),
            if (r.overtimePay > 0)
              _DetailRow(
                label: 'Tăng ca OT (+${r.overtimeHours.toStringAsFixed(1)}h)',
                value: '+${_fmtM(r.overtimePay)}',
              ),
            if (r.bonusManual > 0)
              _DetailRow(
                label: 'Thưởng thêm',
                value: '+${_fmtM(r.bonusManual)}',
              ),
            if (r.bonusRevenue > 0)
              _DetailRow(
                label: 'Thưởng doanh thu',
                value: '+${_fmtM(r.bonusRevenue)}',
              ),
            if (r.allowanceTotal > 0)
              _DetailRow(
                label: 'Phụ cấp',
                value: '+${_fmtM(r.allowanceTotal)}',
              ),
            const SizedBox(height: 24),

            // SECTION: KHẤU TRỪ
            const _SectionHeader(title: 'KHẤU TRỪ', color: Color(0xFFDC2626)),
            if (r.deductionLate > 0)
              _DetailRow(
                label: 'Đi muộn (${r.lateCount} lần)',
                value: '-${_fmtM(r.deductionLate)}',
                valueColor: const Color(0xFFDC2626),
              ),
            if (r.deductionAbsent > 0)
              _DetailRow(
                label: 'Nghỉ không phép (${r.absentDays} ngày)',
                value: '-${_fmtM(r.deductionAbsent)}',
                valueColor: const Color(0xFFDC2626),
              ),
            if (r.deductionManual > 0)
              _DetailRow(
                label: 'Khấu trừ khác',
                value: '-${_fmtM(r.deductionManual)}',
                valueColor: const Color(0xFFDC2626),
              ),
            if (r.deductionLate == 0 &&
                r.deductionAbsent == 0 &&
                r.deductionManual == 0)
              const _DetailRow(
                label: 'Không có khoản khấu trừ',
                value: '0đ',
                valueColor: Colors.grey,
              ),
            const SizedBox(height: 24),

            if (r.paymentStatus != 'paid' &&
                widget.period.isApproved &&
                widget.canApprove)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'XÁC NHẬN TRẢ LƯƠNG NHÂN VIÊN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: _loading
                      ? null
                      : () async {
                          final method = await showModalBottomSheet<String>(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) =>
                                _PaymentMethodSheet(staffName: r.staffName),
                          );
                          if (method != null) {
                            setState(() => _loading = true);
                            await TinhLuongRepository.markRecordPaid(
                              id: r.id,
                              paymentMethod: method,
                            );
                            widget.onRefresh();
                            if (!context.mounted) return;
                            Navigator.pop(context);
                          }
                        },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: valueColor ?? _kNavy,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── STATUS BADGE ────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color bg, Color fg) = switch (status) {
      'paid' => (
        Icons.check_circle_rounded,
        'Đã trả',
        const Color(0xFF1B5E20),
        const Color(0xFF69F0AE),
      ),
      'approved' => (
        Icons.verified_rounded,
        'Đã duyệt',
        const Color(0xFF0D47A1),
        const Color(0xFF82B1FF),
      ),
      'pending_review' => (
        Icons.hourglass_top_rounded,
        'Chờ duyệt',
        const Color(0xFF4A2800),
        const Color(0xFFFFCC02),
      ),
      _ => (Icons.edit_note_rounded, 'Nháp', Colors.white24, Colors.white70),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── PAYMENT METHOD SHEET ────────────────────────────────────────────────────

class _PaymentMethodSheet extends StatelessWidget {
  final String staffName;
  const _PaymentMethodSheet({required this.staffName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8CC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kNavy, Color(0xFF2D3A8C)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trả lương nhân viên',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: _kNavy,
                    ),
                  ),
                  Text(
                    staffName,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          _PayOption(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Tiền mặt',
            subtitle: 'Thanh toán trực tiếp',
            color: const Color(0xFF2E7D32),
            onTap: () => Navigator.pop(context, 'cash'),
          ),
          const SizedBox(height: 10),
          _PayOption(
            icon: Icons.account_balance_rounded,
            label: 'Chuyển khoản',
            subtitle: 'Internet banking / ATM',
            color: const Color(0xFF1565C0),
            onTap: () => Navigator.pop(context, 'transfer'),
          ),
          const SizedBox(height: 10),
          _PayOption(
            icon: Icons.phone_iphone_rounded,
            label: 'MoMo',
            subtitle: 'Ví điện tử MoMo',
            color: const Color(0xFFAD1457),
            onTap: () => Navigator.pop(context, 'momo'),
          ),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _PayOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: color.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
