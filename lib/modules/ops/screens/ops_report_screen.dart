import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/ops_providers.dart';
import '../repository/ops_repository.dart';

const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kYellow = Color(0xFFF59E0B);
const _kMuted  = Color(0xFF9E9085);

class OpsReportScreen extends ConsumerStatefulWidget {
  const OpsReportScreen({super.key});

  @override
  ConsumerState<OpsReportScreen> createState() => _OpsReportScreenState();
}

class _OpsReportScreenState extends ConsumerState<OpsReportScreen> {
  DateTime _date = DateTime.now();

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  void _prevDay() => setState(() => _date = _date.subtract(const Duration(days: 1)));
  void _nextDay() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (_date.isBefore(DateTime(tomorrow.year, tomorrow.month, tomorrow.day))) {
      setState(() => _date = _date.add(const Duration(days: 1)));
    }
  }

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year && _date.month == now.month && _date.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(opsReportProvider(_dateStr(_date)));

    return CustomScrollView(
      slivers: [
        // ── Date nav ─────────────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _DateNav(
            date: _date,
            isToday: _isToday,
            onPrev: _prevDay,
            onNext: _nextDay,
          ),
        ),

        reportAsync.when(
          loading: () => const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: _kNavy)),
          ),
          error: (e, _) => SliverFillRemaining(
            child: Center(child: Text('Lỗi: $e', style: GoogleFonts.outfit())),
          ),
          data: (report) {
            final total  = report.total;
            final done   = report.completed;
            final missed = report.missed;
            final pct    = total == 0 ? 0.0 : done / total;

            // Tính overdue tasks (pending + quá giờ) — chỉ áp dụng khi xem hôm nay
            final overdueStaff = _isToday
                ? report.byStaff.where((s) => s.pending > 0).toList()
                : <OpsStaffReport>[];

            return SliverList(
              delegate: SliverChildListDelegate([
                // ── Tổng quan ─────────────────────────────────────────────
                _StoreOverview(total: total, done: done, missed: missed, pct: pct, isToday: _isToday),

                // ── Cảnh báo đang chậm ────────────────────────────────────
                if (overdueStaff.isNotEmpty) ...[
                  _SectionHeader(title: 'Đang Có Việc Chưa Xong', icon: Icons.warning_amber_rounded, color: _kYellow),
                  ...overdueStaff.map((s) => _AlertRow(staff: s)),
                ],

                // ── Hiệu suất từng nhân viên ──────────────────────────────
                if (report.byStaff.isNotEmpty) ...[
                  _SectionHeader(title: 'Hiệu Suất Nhân Viên', icon: Icons.people_rounded, color: _kNavy),
                  ...report.byStaff.map((s) => _StaffCard(staff: s, isToday: _isToday)),
                ],

                // ── Theo vai trò ──────────────────────────────────────────
                if (report.byRole.isNotEmpty) ...[
                  _SectionHeader(title: 'Theo Vai Trò', icon: Icons.badge_rounded, color: _kNavy),
                  ...report.byRole.map((r) => _RoleRow(role: r)),
                ],

                if (report.byRole.isEmpty && report.byStaff.isEmpty)
                  _EmptyReport(isToday: _isToday),

                const SizedBox(height: 40),
              ]),
            );
          },
        ),
      ],
    );
  }
}

// ── Date Nav ─────────────────────────────────────────────────────────────────
class _DateNav extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final VoidCallback onPrev, onNext;
  const _DateNav({required this.date, required this.isToday, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final label = isToday
        ? 'Hôm nay'
        : DateFormat('EEE, dd/MM/yyyy', 'vi').format(date);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E3DC)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: [
          _NavBtn(icon: Icons.chevron_left_rounded, onTap: onPrev),
          Expanded(
            child: Column(
              children: [
                Text(label, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy), textAlign: TextAlign.center),
                if (!isToday)
                  Text(DateFormat('dd/MM/yyyy').format(date), style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
              ],
            ),
          ),
          _NavBtn(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _NavBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: _kNavy, size: 22),
      ),
    );
  }
}

// ── Store Overview (Big Summary) ─────────────────────────────────────────────
class _StoreOverview extends StatelessWidget {
  final int total, done, missed;
  final double pct;
  final bool isToday;
  const _StoreOverview({required this.total, required this.done, required this.missed, required this.pct, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final pending = total - done - missed;
    final isAllDone = pct >= 1 && total > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isAllDone
                ? [const Color(0xFF166534), const Color(0xFF15803D)]
                : [_kNavy, const Color(0xFF2D3580)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TỔNG QUAN CA HÔM NAY', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                      const SizedBox(height: 4),
                      Text('${(pct * 100).round()}%', style: GoogleFonts.outfit(color: Colors.white, fontSize: 48, fontWeight: FontWeight.w900, height: 1.0)),
                      const SizedBox(height: 2),
                      Text('hoàn thành', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isAllDone ? Icons.emoji_events_rounded : Icons.store_rounded,
                    color: Colors.white, size: 36,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor: AlwaysStoppedAnimation(isAllDone ? _kOrange : _kGreen),
              ),
            ),
            const SizedBox(height: 16),
            // Stat pills
            Row(
              children: [
                _OverviewPill(value: total, label: 'Tổng', color: Colors.white60),
                const SizedBox(width: 8),
                _OverviewPill(value: done, label: 'Hoàn thành', color: _kGreen),
                const SizedBox(width: 8),
                if (pending > 0) _OverviewPill(value: pending, label: 'Đang làm', color: _kYellow),
                if (pending > 0) const SizedBox(width: 8),
                if (missed > 0) _OverviewPill(value: missed, label: 'Bỏ sót', color: _kRed),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewPill extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _OverviewPill({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: GoogleFonts.outfit(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.outfit(color: color.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy, letterSpacing: 0.2)),
        ],
      ),
    );
  }
}

// ── Alert Row (nhân viên còn việc chưa xong) ─────────────────────────────────
class _AlertRow extends StatelessWidget {
  final OpsStaffReport staff;
  const _AlertRow({required this.staff});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _kYellow.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kYellow.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 8, height: 8,
            decoration: const BoxDecoration(color: _kYellow, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              staff.staffName,
              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _kYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Còn ${staff.pending} việc',
              style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700, color: _kYellow),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Staff Card (hiệu suất từng người) ────────────────────────────────────────
class _StaffCard extends StatelessWidget {
  final OpsStaffReport staff;
  final bool isToday;
  const _StaffCard({required this.staff, required this.isToday});

  @override
  Widget build(BuildContext context) {
    final pct = staff.completionPct;
    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (pct >= 1) {
      statusColor = _kGreen;
      statusLabel = 'Hoàn thành';
      statusIcon  = Icons.check_circle_rounded;
    } else if (pct >= 0.6) {
      statusColor = _kYellow;
      statusLabel = 'Đang làm';
      statusIcon  = Icons.pending_rounded;
    } else {
      statusColor = _kRed;
      statusLabel = 'Chậm trễ';
      statusIcon  = Icons.warning_rounded;
    }

    final barColor = pct >= 1 ? _kGreen : pct >= 0.6 ? _kYellow : _kRed;
    final letter = staff.staffName.isNotEmpty ? staff.staffName[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E3DC)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _kNavy.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(letter, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w900, color: _kNavy)),
                ),
              ),
              const SizedBox(width: 12),

              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(staff.staffName, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(statusIcon, size: 12, color: statusColor),
                        const SizedBox(width: 4),
                        Text(statusLabel, style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
                      ],
                    ),
                  ],
                ),
              ),

              // Tỷ lệ %
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(pct * 100).round()}%',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: barColor),
                  ),
                  Text(
                    '${staff.completed}/${staff.total}',
                    style: GoogleFonts.outfit(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: barColor.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),

          // Mini stat row
          if (staff.missed > 0 || staff.pending > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (staff.pending > 0) _MiniStat(value: staff.pending, label: 'chưa làm', color: _kYellow),
                if (staff.pending > 0 && staff.missed > 0) const SizedBox(width: 8),
                if (staff.missed > 0) _MiniStat(value: staff.missed, label: 'bỏ sót', color: _kRed),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _MiniStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text('$value $label', style: GoogleFonts.outfit(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── Role Row ──────────────────────────────────────────────────────────────────
class _RoleRow extends StatelessWidget {
  final OpsRoleReport role;
  const _RoleRow({required this.role});

  @override
  Widget build(BuildContext context) {
    final pct = role.completionPct;
    final Color barColor = pct >= 1 ? _kGreen : pct >= 0.5 ? _kYellow : _kRed;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E3DC)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: barColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.work_rounded, size: 16, color: barColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(role.roleName, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                    Text('${role.completed}/${role.total}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: barColor)),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: barColor.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation(barColor),
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

// ── Empty Report ──────────────────────────────────────────────────────────────
class _EmptyReport extends StatelessWidget {
  final bool isToday;
  const _EmptyReport({required this.isToday});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
            child: const Icon(Icons.bar_chart_rounded, size: 36, color: _kMuted),
          ),
          const SizedBox(height: 14),
          Text(
            isToday ? 'Chưa có dữ liệu hôm nay' : 'Không có dữ liệu',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy),
          ),
          const SizedBox(height: 6),
          Text(
            isToday ? 'Nhân viên chưa bắt đầu ca làm việc.' : 'Ngày này không có log được ghi nhận.',
            style: GoogleFonts.outfit(fontSize: 13, color: _kMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
