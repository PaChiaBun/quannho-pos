import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/providers/permission_provider.dart';
import '../providers/tinhluong_providers.dart';
import '../repository/tinhluong_repository.dart';
import 'payroll_report_screen.dart';
import 'period_detail_screen.dart';
import 'staff_salary_config_screen.dart';

final _fmt = NumberFormat('#,###', 'vi_VN');
String _fmtMoney(double v) => '${_fmt.format(v.round())}đ';

// ── Providers ──────────────────────────────────────────────────────────────────

final openDisputesCountProvider = FutureProvider<int>((ref) async {
  final info = await StoreAuthService.getStoreInfo();
  final storeId = info['store_id'];
  if (storeId == null) return 0;
  final rows = await Supabase.instance.client
      .from('payroll_disputes')
      .select('id')
      .eq('store_id', storeId)
      .eq('status', 'open');
  return (rows as List).length;
});

DateTime _lastDayOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

// ── Screen ─────────────────────────────────────────────────────────────────────

class TinhLuongScreen extends ConsumerWidget {
  const TinhLuongScreen({super.key});

  static const _navy = Color(0xFF1C2151);
  static const _orange = Color(0xFFFF6B35);
  static const _cream = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(userActionPermsProvider);
    final disputeAsync = ref.watch(openDisputesCountProvider);

    final disputeCount = disputeAsync.value ?? 0;
    final perms = permsAsync.value ?? {};

    final canCreate = perms.contains('tinhluong.approve_payroll');
    final canReport = perms.contains('tinhluong.view_all');
    final canConfig = perms.contains('tinhluong.manage_config');

    return Scaffold(
      backgroundColor: _cream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;
          List<Widget> actions = [];
          if (!isNarrow) {
            if (canCreate) {
              actions.add(
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: _orange,
                  ),
                  tooltip: 'Tạo kỳ',
                  onPressed: () => _showCreatePeriodSheet(context, ref),
                ),
              );
            }
            if (canReport) {
              actions.add(
                IconButton(
                  icon: const Icon(Icons.bar_chart_rounded, color: _navy),
                  tooltip: 'Báo cáo',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PayrollReportScreen(),
                    ),
                  ),
                ),
              );
            }
            if (canConfig) {
              actions.add(
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: _navy),
                  tooltip: 'Cấu hình',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StaffSalaryConfigScreen(),
                    ),
                  ),
                ),
              );
            }
            if (actions.isNotEmpty) actions.add(const SizedBox(width: 8));
          } else {
            if (canCreate || canReport || canConfig) {
              actions.add(
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: _navy),
                  tooltip: 'Tùy chọn',
                  onSelected: (val) {
                    if (val == 'create') _showCreatePeriodSheet(context, ref);
                    if (val == 'report') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PayrollReportScreen(),
                        ),
                      );
                    }
                    if (val == 'config') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StaffSalaryConfigScreen(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    if (canCreate)
                      const PopupMenuItem(
                        value: 'create',
                        child: Row(
                          children: [
                            Icon(Icons.add_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Tạo kỳ'),
                          ],
                        ),
                      ),
                    if (canReport)
                      const PopupMenuItem(
                        value: 'report',
                        child: Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Báo cáo'),
                          ],
                        ),
                      ),
                    if (canConfig)
                      const PopupMenuItem(
                        value: 'config',
                        child: Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 20),
                            SizedBox(width: 12),
                            Text('Cấu hình'),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }
          }

          return RefreshIndicator(
            color: _navy,
            onRefresh: () async {
              ref.invalidate(payrollPeriodsProvider);
              ref.invalidate(openDisputesCountProvider);
            },
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: _cream,
                      pinned: true,
                      elevation: 0,
                      scrolledUnderElevation: 2,
                      title: Row(
                        children: [
                          const Text(
                            'Lương',
                            style: TextStyle(
                              color: _navy,
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              letterSpacing: -0.5,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: Colors.black45,
                              size: 22,
                            ),
                            tooltip: 'Làm mới',
                            onPressed: () {
                              ref.invalidate(payrollPeriodsProvider);
                              ref.invalidate(openDisputesCountProvider);
                            },
                          ),
                        ],
                      ),
                      centerTitle: false,
                      actions: actions,
                    ),

                    SliverToBoxAdapter(child: _CompactHeader(ref: ref)),

                    if (disputeCount > 0)
                      SliverToBoxAdapter(
                        child: _DisputeBanner(
                          count: disputeCount,
                          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '⚠️ Có $disputeCount khiếu nại. Mở phiếu lương để trả lời.',
                              ),
                              backgroundColor: const Color(0xFFC62828),
                              behavior: SnackBarBehavior.floating,
                            ),
                          ),
                        ),
                      ),

                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      sliver: _PeriodList(ref: ref, canCreate: canCreate),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showCreatePeriodSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePeriodSheet(
        onCreated: () {
          ref.invalidate(payrollPeriodsProvider);
        },
      ),
    );
  }
}

class _CompactHeader extends StatelessWidget {
  final WidgetRef ref;
  const _CompactHeader({required this.ref});

  @override
  Widget build(BuildContext context) {
    final periodsAsync = ref.watch(payrollPeriodsProvider);
    final periods = periodsAsync.value ?? [];

    if (periods.isEmpty) return const SizedBox.shrink();

    final latestNet = periods.first.totalAmount;
    final latestName = periods.first.name;
    final total = periods.length;
    final paidCount = periods.where((p) => p.status == 'paid').length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  latestName,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _fmtMoney(latestNet),
                    style: const TextStyle(
                      color: Color(0xFFFF6B35),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Text(
                  'Đã trả',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$paidCount/$total',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DisputeBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _DisputeBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.flag_rounded, color: Color(0xFFC62828), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count khiếu nại cần giải quyết',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFC62828),
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFC62828)),
        ],
      ),
    ),
  );
}

class _PeriodList extends ConsumerWidget {
  final WidgetRef ref;
  final bool canCreate;
  const _PeriodList({required this.ref, required this.canCreate});

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final async = innerRef.watch(payrollPeriodsProvider);
    return async.when(
      loading: () => const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF1C2151)),
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
                'Không thể tải dữ liệu kỳ lương',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Vui lòng kiểm tra lại kết nối và thử lại.',
                style: TextStyle(color: Colors.black54, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  innerRef.invalidate(payrollPeriodsProvider);
                  innerRef.invalidate(openDisputesCountProvider);
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Thử lại'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C2151),
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
      data: (periods) {
        if (periods.isEmpty) {
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
                      Icons.receipt_long_outlined,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chưa có kỳ lương nào',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    canCreate
                        ? 'Nhấn "Tạo kỳ" để bắt đầu tính lương'
                        : 'Đang chờ tạo kỳ lương mới',
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        }
        return SliverGrid(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 600,
            mainAxisExtent: 160,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          delegate: SliverChildBuilderDelegate(
            (ctx, i) => _PeriodItem(period: periods[i], ref: innerRef),
            childCount: periods.length,
          ),
        );
      },
    );
  }
}

class _PeriodItem extends StatelessWidget {
  final PayrollPeriodModel period;
  final WidgetRef ref;
  const _PeriodItem({required this.period, required this.ref});

  @override
  Widget build(BuildContext context) {
    final (
      Color sc,
      Color bg,
      String sl,
      IconData ic,
    ) = switch (period.status) {
      'paid' => (
        Colors.green,
        Colors.green.withValues(alpha: 0.1),
        'Đã trả',
        Icons.check_circle_rounded,
      ),
      'approved' => (
        const Color(0xFF1565C0),
        const Color(0xFF1565C0).withValues(alpha: 0.1),
        'Đã duyệt',
        Icons.verified_rounded,
      ),
      'pending_review' => (
        Colors.orange,
        Colors.orange.withValues(alpha: 0.1),
        'Chờ duyệt',
        Icons.hourglass_top_rounded,
      ),
      _ => (
        Colors.grey[700]!,
        Colors.grey[200]!,
        'Nháp',
        Icons.edit_note_rounded,
      ),
    };

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PeriodDetailScreen(period: period),
              ),
            ).then((_) {
              ref.invalidate(payrollPeriodsProvider);
            }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      period.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Color(0xFF1C2151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(ic, size: 14, color: sc),
                        const SizedBox(width: 4),
                        Text(
                          sl,
                          style: TextStyle(
                            color: sc,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${period.fromDate} → ${period.toDate}',
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tổng lương',
                          style: TextStyle(color: Colors.black45, fontSize: 11),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _fmtMoney(period.totalAmount),
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: Color(0xFFFF6B35),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (period.status == 'draft')
                            ? 'Chỉnh sửa'
                            : 'Xem chi tiết',
                        style: const TextStyle(
                          color: Color(0xFF1C2151),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: Color(0xFF1C2151),
                      ),
                    ],
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

// ─── Create Period Bottom Sheet ───────────────────────────────────────────────

class _CreatePeriodSheet extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreatePeriodSheet({required this.onCreated});

  @override
  State<_CreatePeriodSheet> createState() => _CreatePeriodSheetState();
}

class _CreatePeriodSheetState extends State<_CreatePeriodSheet> {
  final _nameCtrl = TextEditingController();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _to = _lastDayOfMonth(DateTime.now());
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = 'Tháng ${_from.month}/${_from.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tạo kỳ lương mới',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2151),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Tên kỳ lương',
              filled: true,
              fillColor: const Color(0xFFF9F9F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _DateTile(
                  label: 'Từ ngày',
                  date: _from,
                  onPick: (d) => setState(() {
                    _from = d;
                    _nameCtrl.text = 'Tháng ${d.month}/${d.year}';
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateTile(
                  label: 'Đến ngày',
                  date: _to,
                  onPick: (d) => setState(() => _to = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Tạo kỳ lương',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên kỳ lương'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    final res = await TinhLuongRepository.createPeriodWithResult(
      name: name,
      fromDate:
          '${_from.year}-${_from.month.toString().padLeft(2, '0')}-${_from.day.toString().padLeft(2, '0')}',
      toDate:
          '${_to.year}-${_to.month.toString().padLeft(2, '0')}-${_to.day.toString().padLeft(2, '0')}',
    );
    if (mounted) {
      setState(() => _loading = false);
      if (res.isSuccess) {
        widget.onCreated();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Đã tạo kỳ lương "${res.period?.name}" thành công!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Không thể tạo kỳ lương: ${res.error ?? "Lỗi máy chủ"}',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateTile({
    required this.label,
    required this.date,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final d = await showDatePicker(
        context: context,
        initialDate: date,
        firstDate: DateTime(2024),
        lastDate: DateTime(2030),
      );
      if (d != null) onPick(d);
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    ),
  );
}
