// lib/modules/tinhluong/screens/payroll_report_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../repository/tinhluong_repository.dart';

final _fmt = NumberFormat('#,###', 'vi_VN');
String _fmtM(double v) => '${_fmt.format(v.round())}đ';
String _fmtShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

// ── Models ─────────────────────────────────────────────────────────────────────

class _Period {
  final String id, name, status;
  final double net;
  final int count;
  final DateTime date;
  const _Period({required this.id, required this.name, required this.status,
    required this.net, required this.count, required this.date});
}

class _Staff {
  final String name;
  final String? role;
  final String mode;
  final double hours, net;
  final String recordId; // để mở phiếu lương
  const _Staff({required this.name, this.role, required this.mode,
    required this.hours, required this.net, required this.recordId});
}

class _Data {
  final List<_Period> periods;
  final double revenue, prevNet;
  const _Data({required this.periods, required this.revenue, required this.prevNet});
}

// ── Providers ──────────────────────────────────────────────────────────────────

final _reportProv = FutureProvider<_Data>((ref) async {
  final info = await StoreAuthService.getStoreInfo();
  final sid = info['store_id'];
  if (sid == null) return const _Data(periods: [], revenue: 0, prevNet: 0);
  final db = Supabase.instance.client;

  final raw = await db.from('payroll_periods')
      .select('id, name, status, total_amount, from_date, to_date')
      .eq('store_id', sid).order('from_date', ascending: false).limit(12);

  if ((raw as List).isEmpty) return const _Data(periods: [], revenue: 0, prevNet: 0);

  final ids = raw.map((p) => p['id'] as String).toList();
  final recs = await db.from('payroll_records')
      .select('period_id, net_pay').inFilter('period_id', ids);

  final cnt = <String, int>{};
  final tot = <String, double>{};
  for (final r in recs as List) {
    final pid = r['period_id'] as String;
    final pay = (r['net_pay'] as num?)?.toDouble() ?? 0;
    cnt[pid] = (cnt[pid] ?? 0) + 1;
    tot[pid] = (tot[pid] ?? 0) + pay;
  }

  final periods = raw.map<_Period>((p) {
    final pid = p['id'] as String;
    DateTime d;
    try { d = DateTime.parse(p['from_date'] as String); } catch (_) { d = DateTime.now(); }
    return _Period(id: pid, name: p['name'] as String? ?? '',
      status: p['status'] as String? ?? 'draft',
      net: tot[pid] ?? (p['total_amount'] as num?)?.toDouble() ?? 0,
      count: cnt[pid] ?? 0, date: d);
  }).toList();

  double rev = 0;
  try {
    final p0 = raw.first;
    final rows = await db.from('finance_records').select('amount')
        .eq('store_id', sid).eq('type', 'income')
        .gte('recorded_at', p0['from_date'] as String)
        .lte('recorded_at', p0['to_date'] as String);
    rev = (rows as List).fold(0.0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
  } catch (_) {}

  return _Data(periods: periods, revenue: rev,
      prevNet: periods.length > 1 ? periods[1].net : 0);
});

final _staffProv = FutureProvider.family<List<_Staff>, String>((ref, pid) async {
  final rows = await Supabase.instance.client.from('payroll_records')
      .select('id, staff_name, role, salary_mode, total_hours, net_pay')
      .eq('period_id', pid).order('net_pay', ascending: false);
  return (rows as List).map<_Staff>((r) => _Staff(
    recordId: r['id'] as String? ?? '',
    name: r['staff_name'] as String? ?? '',
    role: r['role'] as String?,
    mode: r['salary_mode'] as String? ?? 'M1',
    hours: (r['total_hours'] as num?)?.toDouble() ?? 0,
    net: (r['net_pay'] as num?)?.toDouble() ?? 0,
  )).toList();
});

// ── Screen ─────────────────────────────────────────────────────────────────────

class PayrollReportScreen extends ConsumerStatefulWidget {
  const PayrollReportScreen({super.key});
  @override
  ConsumerState<PayrollReportScreen> createState() => _S();
}

class _S extends ConsumerState<PayrollReportScreen> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);
  String? _selId;

  @override
  void dispose() { _tc.dispose(); super.dispose(); }

  static const _navy = Color(0xFF1C2151);
  static const _orange = Color(0xFFFF6B35);
  static const _cream = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_reportProv);
    return Scaffold(
      backgroundColor: _cream,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (data) {
          if (_selId == null && data.periods.isNotEmpty) {
            _selId = data.periods.first.id;
          }
          return Column(children: [
            // ── Header gradient với big numbers ──────────────────────────
            _Header(data: data, onRefresh: () => ref.invalidate(_reportProv)),
            // ── TabBar ───────────────────────────────────────────────────
            Container(
              color: _navy,
              child: TabBar(
                controller: _tc,
                indicatorColor: _orange,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white54,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                tabs: const [
                  Tab(text: 'Tổng Quan'),
                  Tab(text: 'Theo Nhân Viên'),
                ],
              ),
            ),
            // ── Body ─────────────────────────────────────────────────────
            Expanded(child: data.periods.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bar_chart_rounded, size: 72, color: Color(0xFFE0D8CC)),
                  SizedBox(height: 12),
                  Text('Chưa có kỳ lương nào',
                      style: TextStyle(color: Color(0xFF9E9085), fontSize: 16)),
                ]))
              : TabBarView(controller: _tc, children: [
                  _OverviewTab(
                    data: data,
                    onPeriodTap: (id) {
                      setState(() => _selId = id);
                      _tc.animateTo(1);
                    },
                  ),
                  _StaffTab(
                    periods: data.periods,
                    selId: _selId ?? data.periods.first.id,
                    onSel: (id) => setState(() => _selId = id),
                  ),
                ]),
            ),
          ]);
        },
      ),
    );
  }
}

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final _Data data;
  final VoidCallback onRefresh;
  const _Header({required this.data, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final periods = data.periods;
    final cur = periods.isEmpty ? 0.0 : periods.first.net;
    final prev = data.prevNet;
    final diff = prev > 0 ? ((cur - prev) / prev * 100) : 0.0;
    final rev = data.revenue;
    final pct = rev > 0 ? (cur / rev * 100) : 0.0;
    final totalPaid = periods.where((p) => p.status == 'paid')
        .fold(0.0, (s, p) => s + p.net);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C2151), Color(0xFF2A3A8F)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [
        // AppBar row
        Row(children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Expanded(child: Text('Báo Cáo Lương',
              style: TextStyle(color: Colors.white, fontSize: 20,
                  fontWeight: FontWeight.w800))),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: onRefresh,
          ),
        ]),

        // Big number hero
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kỳ mới nhất', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(_fmtM(cur),
                style: const TextStyle(color: Colors.white, fontSize: 32,
                    fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 10),
            // Stat pills row
            Row(children: [
              // Diff badge
              if (periods.length > 1)
                _StatPill(
                  icon: diff >= 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  label: '${diff.abs().toStringAsFixed(1)}% so kỳ trước',
                  color: diff >= 0 ? Colors.greenAccent : Colors.redAccent,
                )
              else
                _StatPill(icon: Icons.flag_rounded, label: 'Kỳ đầu tiên', color: Colors.white60),
              const SizedBox(width: 8),
              _StatPill(icon: Icons.payments_outlined, label: 'Đã trả ${_fmtShort(totalPaid)}', color: Colors.white70),
              const SizedBox(width: 8),
              if (rev > 0)
                _StatPill(icon: Icons.pie_chart_outline_rounded,
                    label: '${pct.toStringAsFixed(1)}% DT', color: Colors.white70),
            ]),
          ]),
        ),
      ])),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatPill({required this.icon, required this.label, required this.color});
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
      Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

// ── Tab 1: Tổng Quan ──────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final _Data data;
  final ValueChanged<String> onPeriodTap;
  const _OverviewTab({required this.data, required this.onPeriodTap});

  @override
  Widget build(BuildContext context) {
    final stats = data.periods;
    final maxVal = stats.map((s) => s.net).fold(1.0, (a, b) => a > b ? a : b);

    return ListView(padding: const EdgeInsets.all(16), children: [
      // ── Bar Chart ────────────────────────────────────────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Chi Lương Theo Kỳ',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1C2151))),
            Text('Lương đã duyệt — xanh đậm | Nháp — xám',
                style: TextStyle(fontSize: 11, color: Color(0xFF9E9085))),
          ])),
        ]),
        const SizedBox(height: 20),
        SizedBox(height: 180,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end,
            children: stats.reversed.map((s) {
              final ratio = maxVal > 0 ? (s.net / maxVal).clamp(0.0, 1.0) : 0.0;
              final isPaid = s.status == 'paid' || s.status == 'approved';
              final barColor = isPaid ? const Color(0xFF1C2151) : const Color(0xFFCDD0D8);
              final label = _shortLabel(s.name);
              return Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  if (s.net > 0) Text(_fmtShort(s.net),
                      style: TextStyle(fontSize: 8, color: barColor, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 3),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 700), curve: Curves.easeOutCubic,
                    height: 120 * ratio,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      boxShadow: isPaid ? [BoxShadow(color: const Color(0xFF1C2151).withValues(alpha: 0.3),
                        blurRadius: 4, offset: const Offset(0, -2))] : [],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(label, style: const TextStyle(fontSize: 9, color: Color(0xFF9E9085)),
                      textAlign: TextAlign.center, maxLines: 2),
                ]),
              ));
            }).toList()),
        ),
      ])),
      const SizedBox(height: 16),

      // ── Period list ────────────────────────────────────────────────────
      const Text('Chi Tiết Từng Kỳ',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1C2151))),
      const SizedBox(height: 10),
      ...stats.map((s) => _PeriodCard(s: s, onTap: () => onPeriodTap(s.id))),
      const SizedBox(height: 32),
    ]);
  }

  String _shortLabel(String n) {
    final m = RegExp(r'(\d+)/(\d+)').firstMatch(n);
    if (m != null) {
      final yr = m.group(2) ?? '';
      return 'T${m.group(1)}\n${yr.length >= 2 ? yr.substring(yr.length - 2) : yr}';
    }
    return n.length > 5 ? n.substring(0, 5) : n;
  }
}

class _PeriodCard extends StatelessWidget {
  final _Period s;
  final VoidCallback onTap;
  const _PeriodCard({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (Color sc, String sl, IconData ic) = switch (s.status) {
      'paid'           => (Colors.green,           'Đã trả',    Icons.check_circle_rounded),
      'approved'       => (const Color(0xFF1565C0), 'Đã duyệt',  Icons.verified_rounded),
      'pending_review' => (Colors.orange,           'Chờ duyệt', Icons.hourglass_top_rounded),
      _                => (Colors.grey,             'Nháp',      Icons.edit_note_rounded),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: sc.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(ic, size: 22, color: sc),
        ),
        title: Text(s.name,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1C2151))),
        subtitle: Text('${s.count} nhân viên · Nhấn để xem',
            style: const TextStyle(color: Color(0xFF9E9085), fontSize: 12)),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_fmtM(s.net),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFFFF6B35))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: sc.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text(sl, style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    ));
  }
}

// ── Tab 2: Theo Nhân Viên ─────────────────────────────────────────────────────

class _StaffTab extends ConsumerWidget {
  final List<_Period> periods;
  final String selId;
  final ValueChanged<String> onSel;
  const _StaffTab({required this.periods, required this.selId, required this.onSel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_staffProv(selId));
    return Column(children: [
      // Period picker
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: DropdownButtonFormField<String>(
          initialValue: selId,
          isDense: true,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D8CC))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE0D8CC))),
            filled: true, fillColor: const Color(0xFFFFF8F0),
            prefixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF1C2151)),
          ),
          items: periods.map((p) => DropdownMenuItem(value: p.id,
            child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) { onSel(v); } },
        ),
      ),

      Expanded(child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('Chưa có phiếu lương nào',
                style: TextStyle(color: Color(0xFF9E9085))));
          }
          final total = rows.fold(0.0, (s, r) => s + r.net);
          final totalHrs = rows.fold(0.0, (s, r) => s + r.hours);
          final selPeriod = periods.firstWhere((p) => p.id == selId);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
            // Summary row
            _Card(child: Row(children: [
              _SumCell(label: 'Tổng lương', value: _fmtM(total), color: const Color(0xFFFF6B35)),
              _Divider(),
              _SumCell(label: 'Nhân viên', value: '${rows.length} người', color: const Color(0xFF1C2151)),
              _Divider(),
              _SumCell(label: 'Tổng giờ', value: '${totalHrs.toStringAsFixed(1)}h', color: const Color(0xFF7C3AED)),
            ])),
            const SizedBox(height: 12),
            ...rows.asMap().entries.map((e) => _StaffCard(
              r: e.value, rank: e.key + 1, total: total,
              periodName: selPeriod.name,
            )),
          ]);
        },
      )),
    ]);
  }
}

class _SumCell extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SumCell({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: color)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9E9085))),
  ]));
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(width: 1, height: 32,
      color: const Color(0xFFE5E1DB));
}

class _StaffCard extends StatelessWidget {
  final _Staff r;
  final int rank;
  final double total;
  final String periodName;
  const _StaffCard({required this.r, required this.rank, required this.total, required this.periodName});

  @override
  Widget build(BuildContext context) {
    final pct  = total > 0 ? r.net / total : 0.0;
    final mode = switch (r.mode) {
      'M1' => 'Theo giờ', 'M2' => 'Cố định', 'M3' => 'Cố định+OT', 'M4' => 'Theo ngày', _ => r.mode,
    };
    final List<Color> rankGrad = rank == 1
        ? [const Color(0xFFFFB300), const Color(0xFFFF8F00)]
        : rank == 2
            ? [const Color(0xFF78909C), const Color(0xFF546E7A)]
            : rank == 3
                ? [const Color(0xFFBF6B3D), const Color(0xFF8D4B2A)]
                : [const Color(0xFF2A3A8F), const Color(0xFF1C2151)];

    return InkWell(
      onTap: () => _openPayslip(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: rankGrad,
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: rankGrad.last.withValues(alpha: 0.35),
                    blurRadius: 6, offset: const Offset(0, 3))],
              ),
              child: Center(child: Text('$rank',
                style: const TextStyle(color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.w900))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.name, style: const TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 15, color: Color(0xFF1C2151))),
              const SizedBox(height: 2),
              Row(children: [
                Text('${r.role ?? mode}  ·  ${r.hours.toStringAsFixed(1)}h làm',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, size: 14, color: Color(0xFFB0A89E)),
              ]),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtM(r.net),
                  style: const TextStyle(fontWeight: FontWeight.w900,
                      fontSize: 16, color: Color(0xFFFF6B35))),
              Text('${(pct * 100).toStringAsFixed(1)}% tổng',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9E9085))),
            ]),
          ]),
          const SizedBox(height: 10),
          // Progress bar
          Stack(children: [
            Container(height: 6, decoration: BoxDecoration(
                color: const Color(0xFFEEEBE6), borderRadius: BorderRadius.circular(6))),
            FractionallySizedBox(
              widthFactor: pct.clamp(0.0, 1.0),
              child: Container(height: 6, decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF1C2151), Color(0xFF4A5FBF)]),
                borderRadius: BorderRadius.circular(6),
              )),
            ),
          ]),
        ]),
      ),
    ));
  }

  // Mở phiếu lương của nhân viên này
  Future<void> _openPayslip(BuildContext context) async {
    if (r.recordId.isEmpty) return;
    final db = Supabase.instance.client;
    try {
      final row = await db.from('payroll_records')
          .select('*, payroll_periods!inner(name, from_date, to_date, status)')
          .eq('id', r.recordId).maybeSingle();
      if (row == null || !context.mounted) return;
      final p = row['payroll_periods'] as Map<String, dynamic>;
      final record = PayrollRecordModel.fromMap(row);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _ManagerPayslipSheet(
          record: record,
          periodName: p['name'] as String? ?? periodName,
          periodFrom: (p['from_date'] ?? '').toString(),
          periodTo:   (p['to_date']   ?? '').toString(),
        ),
      );
    } catch (_) {}
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10, offset: const Offset(0, 3))],
    ),
    child: child,
  );
}

// ── Manager Payslip Sheet ───────────────────────────────────────────────────────
// Bottom sheet xem phiếu lương chi tiết một nhân viên (chỉ đọc, dành cho quản lý)

final _fmt2 = NumberFormat('#,###', 'vi_VN');
String _fmtM2(double v) => '${_fmt2.format(v.round())}đ';

class _ManagerPayslipSheet extends StatelessWidget {
  final PayrollRecordModel record;
  final String periodName, periodFrom, periodTo;
  const _ManagerPayslipSheet({
    required this.record, required this.periodName,
    required this.periodFrom, required this.periodTo,
  });

  @override
  Widget build(BuildContext context) {
    final r = record;
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0D8CC),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Text(r.staffName,
              style: const TextStyle(fontWeight: FontWeight.w800,
                  fontSize: 18, color: Color(0xFF1C2151))),
          Text(periodName,
              style: const TextStyle(fontSize: 13, color: Color(0xFF9E9085))),
          Text('$periodFrom → $periodTo',
              style: const TextStyle(fontSize: 11, color: Color(0xFFB0A89E))),
          const SizedBox(height: 12),
          const Divider(height: 1),
          Expanded(child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              // Thực lĩnh nổi bật
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)]),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(children: [
                  const Text('Thực lĩnh',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const Spacer(),
                  Text(_fmtM2(r.netPay),
                      style: const TextStyle(color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w900, fontSize: 22)),
                ]),
              ),
              const SizedBox(height: 16),

              // Chi tiết lương
              _section('Chi tiết khoản lương', [
                _row('+  Lương cơ bản', r.regularPay, true),
                if (r.overtimePay > 0) _row('+  Tăng ca', r.overtimePay, true),
                if (r.bonusRevenue > 0) _row('+  Thưởng doanh thu', r.bonusRevenue, true),
                if (r.bonusManual > 0) _row('+  Thưởng thủ công', r.bonusManual, true),
                if (r.allowanceTotal > 0) _row('+  Phụ cấp', r.allowanceTotal, true),
                if (r.deductionLate > 0) _row('−  Trừ đi muộn', r.deductionLate, false),
                if (r.deductionAbsent > 0) _row('−  Trừ nghỉ', r.deductionAbsent, false),
                if (r.deductionManual > 0) _row('−  Khấu trừ khác', r.deductionManual, false),
              ]),
              const SizedBox(height: 14),

              // Chấm công
              _section('Chấm công', [
                _info('Tổng giờ làm', '${r.totalHours.toStringAsFixed(1)}h'),
                _info('Giờ tăng ca', '${r.overtimeHours.toStringAsFixed(1)}h'),
                _info('Nghỉ không phép', '${r.absentDays} ngày'),
                _info('Đi muộn', '${r.lateCount} lần'),
              ]),

              if (r.note != null && r.note!.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50, borderRadius: BorderRadius.circular(10)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1565C0)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r.note!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0)))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),
            ],
          )),
        ]),
      ),
    );
  }

  Widget _section(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700,
          fontSize: 14, color: Color(0xFF1C2151))),
      const SizedBox(height: 8),
      ...rows,
    ],
  );

  Widget _row(String label, double amount, bool isAdd) {
    final c = isAdd ? Colors.green[700]! : Colors.red[700]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        Text(_fmtM2(amount), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
      ]),
    );
  }

  Widget _info(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF9E9085)))),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    ]),
  );
}

