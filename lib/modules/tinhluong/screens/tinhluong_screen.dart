// lib/modules/tinhluong/screens/tinhluong_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
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
      .from('payroll_disputes').select('id')
      .eq('store_id', storeId).eq('status', 'open');
  return (rows as List).length;
});

DateTime _lastDayOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

// ── Screen ─────────────────────────────────────────────────────────────────────

class TinhLuongScreen extends ConsumerWidget {
  const TinhLuongScreen({super.key});

  static const _navy   = Color(0xFF1C2151);
  static const _orange = Color(0xFFFF6B35);
  static const _cream  = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final periodsAsync   = ref.watch(payrollPeriodsProvider);
    final disputeAsync   = ref.watch(openDisputesCountProvider);
    final disputeCount   = disputeAsync.value ?? 0;

    // Tính tổng lương tháng hiện tại từ kỳ mới nhất
    final periods = periodsAsync.value ?? [];
    final latestNet  = periods.isNotEmpty ? periods.first.totalAmount : 0.0;
    final latestName = periods.isNotEmpty ? periods.first.name : '—';
    final paidCount  = periods.where((p) => p.status == 'paid').length;

    final mainBody = RefreshIndicator(
        color: _navy,
        onRefresh: () async {
          ref.invalidate(payrollPeriodsProvider);
          ref.invalidate(openDisputesCountProvider);
        },
        child: CustomScrollView(slivers: [

          // ── Header ─────────────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeader(
            context, ref,
            latestNet: latestNet,
            latestName: latestName,
            totalPeriods: periods.length,
            paidCount: paidCount,
          )),

          // ── Banner khiếu nại ───────────────────────────────────────────────
          if (disputeCount > 0)
            SliverToBoxAdapter(child: _DisputeBanner(
              count: disputeCount,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('⚠️ Có $disputeCount khiếu nại. Mở phiếu lương để trả lời.'),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
              )),
            )),

          // ── Section title ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            sliver: SliverToBoxAdapter(child: Row(children: [
              const Text('Danh Sách Kỳ Lương',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _navy)),
              const Spacer(),
              Text('${periods.length} kỳ',
                  style: const TextStyle(color: Color(0xFF9E9085), fontSize: 13)),
            ])),
          ),

          // ── Period list ────────────────────────────────────────────────────
          _PeriodList(ref: ref),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ]),
      );

    return Scaffold(
      backgroundColor: _cream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(children: [
              Expanded(flex: 3, child: mainBody),
              SizedBox(
                width: 280,
                child: _TinhLuongRightPanel(
                  latestNet: latestNet,
                  totalPeriods: periods.length,
                  paidCount: paidCount,
                  disputeCount: disputeCount,
                ),
              ),
            ]);
          }
          return mainBody;
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, {
    required double latestNet,
    required String latestName,
    required int totalPeriods,
    required int paidCount,
  }) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C2151), Color(0xFF2A3A8F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [

        // AppBar row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Tính Lương',
                  style: TextStyle(color: Colors.white, fontSize: 22,
                      fontWeight: FontWeight.w900, letterSpacing: -0.3)),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
              onPressed: () {
                ref.invalidate(payrollPeriodsProvider);
                ref.invalidate(openDisputesCountProvider);
              },
            ),
          ]),
        ),

        // Big number
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(latestName,
                  style: const TextStyle(color: Colors.white60, fontSize: 13)),
              const SizedBox(height: 4),
              Text(_fmtMoney(latestNet),
                  style: const TextStyle(color: Colors.white, fontSize: 30,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Row(children: [
                _Pill(Icons.check_circle_outline_rounded,
                    '$paidCount/$totalPeriods kỳ đã trả', Colors.greenAccent),
              ]),
            ])),
          ]),
        ),

        // Quick action row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Row(children: [
            _QuickAction(
              icon: Icons.add_rounded,
              label: 'Tạo kỳ',
              color: _orange,
              onTap: () => _showCreatePeriodSheet(context, ref),
            ),
            const SizedBox(width: 12),
            _QuickAction(
              icon: Icons.bar_chart_rounded,
              label: 'Báo cáo',
              color: const Color(0xFF7C3AED),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PayrollReportScreen())),
            ),
            const SizedBox(width: 12),
            _QuickAction(
              icon: Icons.tune_rounded,
              label: 'Cấu hình',
              color: const Color(0xFF0288D1),
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const StaffSalaryConfigScreen())),
            ),
          ]),
        ),
      ])),
    );
  }

  void _showCreatePeriodSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePeriodSheet(onCreated: () {
        ref.invalidate(payrollPeriodsProvider);
      }),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────────

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _Pill(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label,
      required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12,
              fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  );
}

class _DisputeBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _DisputeBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
        boxShadow: [BoxShadow(color: Colors.red.withValues(alpha: 0.08),
            blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFC62828).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.flag_rounded, color: Color(0xFFC62828), size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$count khiếu nại chưa xử lý',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                  color: Color(0xFFC62828))),
          const Text('Nhấn để xem hướng dẫn xử lý',
              style: TextStyle(color: Color(0xFF9E9085), fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFC62828)),
      ]),
    ),
  );
}

// ── Period List ────────────────────────────────────────────────────────────────

class _PeriodList extends ConsumerWidget {
  final WidgetRef ref;
  const _PeriodList({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final async = innerRef.watch(payrollPeriodsProvider);
    return async.when(
      loading: () => const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SliverFillRemaining(
          child: Center(child: Text('Lỗi: $e'))),
      data: (periods) {
        if (periods.isEmpty) {
          return SliverFillRemaining(
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.receipt_long_outlined, size: 72, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text('Chưa có kỳ lương nào',
                  style: TextStyle(color: Colors.grey[500], fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Nhấn "Tạo kỳ" ở trên để bắt đầu',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            ])),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(delegate: SliverChildBuilderDelegate(
            (ctx, i) => _PeriodCard(period: periods[i], ref: innerRef),
            childCount: periods.length,
          )),
        );
      },
    );
  }
}

// ── Period Card ────────────────────────────────────────────────────────────────

class _PeriodCard extends StatelessWidget {
  final PayrollPeriodModel period;
  final WidgetRef ref;
  const _PeriodCard({required this.period, required this.ref});

  @override
  Widget build(BuildContext context) {
    final (Color sc, String sl, IconData ic) = switch (period.status) {
      'paid'           => (Colors.green,            'Đã trả',    Icons.check_circle_rounded),
      'approved'       => (const Color(0xFF1565C0),  'Đã duyệt',  Icons.verified_rounded),
      'pending_review' => (Colors.orange,            'Chờ duyệt', Icons.hourglass_top_rounded),
      _                => (Colors.grey,              'Nháp',      Icons.edit_note_rounded),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => PeriodDetailScreen(period: period))).then((_) {
          ref.invalidate(payrollPeriodsProvider);
        }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Row trên: tên + badge trạng thái
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: sc.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(ic, size: 22, color: sc),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(period.name,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16,
                        color: Color(0xFF1C2151))),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.date_range_outlined, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('${period.fromDate} → ${period.toDate}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sc.withValues(alpha: 0.3)),
                  ),
                  child: Text(sl,
                      style: TextStyle(color: sc, fontWeight: FontWeight.w700, fontSize: 11)),
                ),
              ]),
            ]),

            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0EDE8)),
            const SizedBox(height: 12),

            // Row dưới: tổng lương + mũi tên
            Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Tổng lương', style: TextStyle(color: Color(0xFF9E9085), fontSize: 11)),
                const SizedBox(height: 2),
                Text(_fmtMoney(period.totalAmount),
                    style: const TextStyle(color: Color(0xFFFF6B35),
                        fontWeight: FontWeight.w900, fontSize: 20)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2151).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Xem chi tiết',
                      style: TextStyle(color: Color(0xFF1C2151),
                          fontWeight: FontWeight.w700, fontSize: 12)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF1C2151)),
                ]),
              ),
            ]),
          ]),
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
  DateTime _to   = _lastDayOfMonth(DateTime.now());
  bool _loading  = false;

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0D8CC),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Text('Tạo kỳ lương mới',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1C2151))),
        const SizedBox(height: 20),
        TextField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'Tên kỳ lương',
            filled: true, fillColor: const Color(0xFFFFF8F0),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D8CC))),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: _DateTile(
            label: 'Từ ngày', date: _from,
            onPick: (d) => setState(() {
              _from = d;
              _nameCtrl.text = 'Tháng ${d.month}/${d.year}';
            }),
          )),
          const SizedBox(width: 12),
          Expanded(child: _DateTile(
            label: 'Đến ngày', date: _to,
            onPick: (d) => setState(() => _to = d),
          )),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity, height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Tạo kỳ lương',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ),
      ]),
    );
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _loading = true);
    final res = await TinhLuongRepository.createPeriod(
      name:     name,
      fromDate: '${_from.year}-${_from.month.toString().padLeft(2,'0')}-${_from.day.toString().padLeft(2,'0')}',
      toDate:   '${_to.year}-${_to.month.toString().padLeft(2,'0')}-${_to.day.toString().padLeft(2,'0')}',
    );
    setState(() => _loading = false);
    if (res != null && mounted) {
      widget.onCreated();
      Navigator.pop(context);
    }
  }
}

class _DateTile extends StatelessWidget {
  final String   label;
  final DateTime date;
  final ValueChanged<DateTime> onPick;
  const _DateTile({required this.label, required this.date, required this.onPick});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () async {
      final d = await showDatePicker(
        context: context, initialDate: date,
        firstDate: DateTime(2024), lastDate: DateTime(2030),
      );
      if (d != null) onPick(d);
    },
    borderRadius: BorderRadius.circular(12),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        border: Border.all(color: const Color(0xFFE0D8CC)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: Color(0xFF9E9085), fontSize: 11)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF1C2151)),
          const SizedBox(width: 6),
          Text('${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                  color: Color(0xFF1C2151))),
        ]),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Tính Lương Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _TinhLuongRightPanel extends StatelessWidget {
  final double latestNet;
  final int totalPeriods;
  final int paidCount;
  final int disputeCount;
  const _TinhLuongRightPanel({
    required this.latestNet,
    required this.totalPeriods,
    required this.paidCount,
    required this.disputeCount,
  });

  static const _kNavy = Color(0xFF1C2151);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(
                color: _kNavy.withValues(alpha: 0.07),
                blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: Row(children: [
                  const Icon(Icons.payments_rounded, size: 16, color: _kNavy),
                  const SizedBox(width: 6),
                  Text('Tính Lương', style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
                ]),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  _TLRow(label: 'Lương mới nhất', value: _fmtMoney(latestNet), color: const Color(0xFFFF6B35)),
                  const Divider(height: 1),
                  _TLRow(label: 'Tổng kỳ', value: '$totalPeriods', color: _kNavy),
                  const Divider(height: 1),
                  _TLRow(label: 'Đã trả', value: '$paidCount', color: const Color(0xFF2E7D32)),
                  if (disputeCount > 0) ...[
                    const Divider(height: 1),
                    _TLRow(label: 'Khiếu nại', value: '$disputeCount', color: const Color(0xFFC62828)),
                  ],
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _TLRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _TLRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: const Color(0xFF1A1207)))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}
