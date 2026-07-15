import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/ops_providers.dart';
import '../repository/ops_repository.dart';

const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kYellow = Color(0xFFF59E0B);
const _kMuted  = Color(0xFF9E9085);

// ── Private helpers ───────────────────────────────────────────────────────────
class _RoleGroup {
  final String? roleId;
  final String roleName;
  final Color color;
  final List<OpsDailyLogModel> logs;
  _RoleGroup({required this.roleId, required this.roleName, required this.color, required this.logs});
  int get total     => logs.length;
  int get completed => logs.where((l) => l.isCompleted).length;
  int get pending   => logs.where((l) => l.isPending).length;
  double get pct    => total == 0 ? 0.0 : completed / total;
  Map<String, _StaffGroup> get byStaff {
    final m = <String, _StaffGroup>{};
    for (final log in logs) {
      m.putIfAbsent(log.staffId ?? 'x', () => _StaffGroup(log.staffName ?? '?', [])).logs.add(log);
    }
    return m;
  }
}

class _StaffGroup {
  final String name;
  final List<OpsDailyLogModel> logs;
  _StaffGroup(this.name, this.logs);
  int get total     => logs.length;
  int get completed => logs.where((l) => l.isCompleted).length;
  double get pct    => total == 0 ? 0.0 : completed / total;
}

class _TimeSlot {
  final String time;
  final List<({OpsDailyLogModel log, String title, String staff})> items;
  _TimeSlot(this.time, this.items);
  int get total     => items.length;
  int get completed => items.where((i) => i.log.isCompleted).length;
  double get pct    => total == 0 ? 0.0 : completed / total;
}

// ── Main Widget ───────────────────────────────────────────────────────────────
class OpsManagerDashboard extends ConsumerWidget {
  const OpsManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync  = ref.watch(opsLiveTodayLogsProvider);
    final tmplAsync  = ref.watch(opsTemplatesProvider);
    final rolesAsync = ref.watch(opsStoreRolesProvider);

    if (logsAsync.isLoading && !logsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator(color: _kNavy));
    }

    final logs  = logsAsync.value ?? [];
    final tmpls = tmplAsync.value ?? [];
    final roles = rolesAsync.value ?? [];

    final tmplMap = {for (final t in tmpls) t.id: t};
    final roleColorMap = <String, Color>{};
    for (final r in roles) {
      if (r.color != null) {
        try { roleColorMap[r.id] = Color(int.parse(r.color!.replaceFirst('#', 'FF'), radix: 16)); } catch (_) {}
      }
    }

    final total   = logs.length;
    final done    = logs.where((l) => l.isCompleted).length;
    final missed  = logs.where((l) => l.isMissed).length;
    final pct     = total == 0 ? 0.0 : done / total;

    // Build role groups
    final roleMap = <String, _RoleGroup>{};
    for (final log in logs) {
      final t      = tmplMap[log.templateId];
      final roleId = t?.storeRoleId;
      final name   = t?.roleName ?? 'Tất cả vai trò';
      roleMap.putIfAbsent(roleId ?? '__all__', () => _RoleGroup(
        roleId:   roleId,
        roleName: name,
        color:    roleId != null ? (roleColorMap[roleId] ?? _kNavy) : _kMuted,
        logs:     [],
      )).logs.add(log);
    }
    final roleGroups = roleMap.values.toList()
      ..sort((a, b) => a.roleName.compareTo(b.roleName));

    // Build time slots
    final slotMap = <String, _TimeSlot>{};
    for (final log in logs) {
      final t    = tmplMap[log.templateId];
      final slot = t?.targetTime ?? 'Không xác định';
      slotMap.putIfAbsent(slot, () => _TimeSlot(slot, [])).items.add((
        log:   log,
        title: t?.title ?? '?',
        staff: log.staffName ?? '?',
      ));
    }
    final slots = slotMap.values.toList()..sort((a, b) {
      final ar = RegExp(r'^\d{2}:\d{2}$').hasMatch(a.time);
      final br = RegExp(r'^\d{2}:\d{2}$').hasMatch(b.time);
      if (ar && br) return a.time.compareTo(b.time);
      if (ar) return -1;
      if (br) return 1;
      return a.time.compareTo(b.time);
    });

    // Overdue
    final now = DateTime.now();
    final overdueNames = <String>{};
    for (final log in logs) {
      if (!log.isPending) continue;
      final t = tmplMap[log.templateId]?.targetTime;
      if (t != null && RegExp(r'^\d{2}:\d{2}$').hasMatch(t)) {
        final p = t.split(':');
        final dt = DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
        if (now.isAfter(dt)) overdueNames.add(log.staffName ?? '?');
      }
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _HeroCard(total: total, done: done, missed: missed, pct: pct)),
        if (overdueNames.isNotEmpty)
          SliverToBoxAdapter(child: _OverdueAlert(names: overdueNames.toList())),
        if (total == 0)
          const SliverFillRemaining(child: _EmptyState()),
        if (roleGroups.isNotEmpty) ...[
          SliverToBoxAdapter(child: _SectionLabel('Theo Vai Trò', Icons.badge_rounded)),
          SliverToBoxAdapter(
            child: Column(children: roleGroups.map((rg) => _RoleCard(
              group: rg,
              onTapStaff: (sg) => _showChecklist(context, sg),
            )).toList()),
          ),
        ],
        if (slots.isNotEmpty) ...[
          SliverToBoxAdapter(child: _SectionLabel('Timeline Hôm Nay', Icons.schedule_rounded)),
          SliverToBoxAdapter(
            child: Column(children: slots.map((s) => _SlotCard(slot: s)).toList()),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  void _showChecklist(BuildContext ctx, _StaffGroup sg) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChecklistSheet(group: sg),
    );
  }
}

// ── Hero Card ─────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final int total, done, missed;
  final double pct;
  const _HeroCard({required this.total, required this.done, required this.missed, required this.pct});

  @override
  Widget build(BuildContext context) {
    final pending  = total - done - missed;
    final allDone  = pct >= 1 && total > 0;
    final barColor = allDone ? _kOrange : pct >= 0.6 ? _kGreen : _kYellow;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: allDone ? [const Color(0xFF166534), const Color(0xFF15803D)] : [_kNavy, const Color(0xFF2D3580)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.25), blurRadius: 20, offset: const Offset(0, 8))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TỔNG QUAN HÔM NAY', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 4),
              Text('${(pct * 100).round()}%', style: GoogleFonts.outfit(color: Colors.white, fontSize: 52, fontWeight: FontWeight.w900, height: 1.0)),
              Text('hoàn thành', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 13)),
            ])),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
              child: Icon(allDone ? Icons.emoji_events_rounded : Icons.store_rounded, color: Colors.white, size: 36),
            ),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), minHeight: 8, backgroundColor: Colors.white24, valueColor: AlwaysStoppedAnimation(barColor)),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(total, 'Tổng', Colors.white60),
              _Pill(done, 'Xong', _kGreen),
              if (pending > 0) _Pill(pending, 'Đang làm', _kYellow),
              if (missed > 0) _Pill(missed, 'Bỏ sót', _kRed),
            ],
          ),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final int v; final String l; final Color c;
  const _Pill(this.v, this.l, this.c);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.4))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$v', style: GoogleFonts.outfit(color: c, fontSize: 13, fontWeight: FontWeight.w800)),
      const SizedBox(width: 4),
      Text(l, style: GoogleFonts.outfit(color: c.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Overdue Alert ─────────────────────────────────────────────────────────────
class _OverdueAlert extends StatelessWidget {
  final List<String> names;
  const _OverdueAlert({required this.names});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _kRed.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kRed.withValues(alpha: 0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.warning_amber_rounded, color: _kRed, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(
        '${names.length} nhân viên có việc quá giờ: ${names.join(', ')}',
        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _kRed),
      )),
    ]),
  );
}

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String title; final IconData icon;
  const _SectionLabel(this.title, this.icon);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: _kNavy),
      ),
      const SizedBox(width: 8),
      Text(title, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
    ]),
  );
}

// ── Role Card (collapsible) ───────────────────────────────────────────────────
class _RoleCard extends StatefulWidget {
  final _RoleGroup group;
  final void Function(_StaffGroup) onTapStaff;
  const _RoleCard({required this.group, required this.onTapStaff});
  @override State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final rg    = widget.group;
    final color = rg.pct >= 1 ? _kGreen : rg.pct >= 0.6 ? _kYellow : _kRed;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E3DC)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(children: [
        // Header
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: rg.color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(rg.roleName, style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: rg.pct.clamp(0.0, 1.0), minHeight: 5, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(color)),
                ),
              ])),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${(rg.pct * 100).round()}%', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                Text('${rg.completed}/${rg.total}', style: GoogleFonts.outfit(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(width: 8),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _kMuted),
            ]),
          ),
        ),
        // Staff rows (expanded)
        if (_expanded) ...[
          const Divider(height: 1, indent: 16, endIndent: 16),
          ...rg.byStaff.entries.map((e) {
            final sg    = e.value;
            final sColor = sg.pct >= 1 ? _kGreen : sg.pct >= 0.6 ? _kYellow : _kRed;
            return InkWell(
              onTap: () { HapticFeedback.lightImpact(); widget.onTapStaff(sg); },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.07), shape: BoxShape.circle),
                    child: Center(child: Text(sg.name[0].toUpperCase(), style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w900, color: _kNavy))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(sg.name, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: sg.pct.clamp(0.0, 1.0), minHeight: 4, backgroundColor: sColor.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(sColor)),
                    ),
                  ])),
                  const SizedBox(width: 10),
                  Text('${sg.completed}/${sg.total}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: sColor)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, color: _kMuted, size: 18),
                ]),
              ),
            );
          }),
        ],
      ]),
    );
  }
}

// ── Time Slot Card (expandable) ───────────────────────────────────────────────
class _SlotCard extends StatefulWidget {
  final _TimeSlot slot;
  const _SlotCard({required this.slot});
  @override State<_SlotCard> createState() => _SlotCardState();
}

class _SlotCardState extends State<_SlotCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final s     = widget.slot;
    final color = s.pct >= 1 ? _kGreen : s.pct >= 0.6 ? _kYellow : _kRed;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E3DC)),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                child: Text(s.time, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
              ),
              const SizedBox(width: 10),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: s.pct.clamp(0.0, 1.0), minHeight: 6, backgroundColor: color.withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(color)),
              )),
              const SizedBox(width: 10),
              Text('${s.completed}/${s.total}', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(width: 4),
              Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: _kMuted, size: 18),
            ]),
          ),
        ),
        if (_expanded) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          ...s.items.map((item) {
            final IconData icon;
            final Color ic;
            if (item.log.isCompleted) { icon = Icons.check_circle_rounded; ic = _kGreen; }
            else if (item.log.isMissed) { icon = Icons.cancel_rounded; ic = _kRed; }
            else { icon = Icons.radio_button_unchecked_rounded; ic = _kYellow; }
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Row(children: [
                Icon(icon, size: 18, color: ic),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: _kNavy)),
                  Text(item.staff, style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
                ])),
              ]),
            );
          }),
          const SizedBox(height: 4),
        ],
      ]),
    );
  }
}

// ── Staff Checklist Bottom Sheet ──────────────────────────────────────────────
class _ChecklistSheet extends StatelessWidget {
  final _StaffGroup group;
  const _ChecklistSheet({required this.group});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Center(child: Text(group.name[0].toUpperCase(), style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w900, color: _kNavy))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(group.name, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
            Text('${group.completed}/${group.total} nhiệm vụ · ${(group.pct * 100).round()}%', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
          ])),
        ]),
        const SizedBox(height: 16),
        const Divider(),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.zero,
            children: group.logs.map((log) {
              final IconData icon;
              final Color ic;
              final String label;
              if (log.isCompleted) { icon = Icons.check_circle_rounded; ic = _kGreen; label = 'Hoàn thành'; }
              else if (log.isMissed) { icon = Icons.cancel_rounded; ic = _kRed; label = 'Bỏ sót'; }
              else { icon = Icons.radio_button_unchecked_rounded; ic = _kYellow; label = 'Chưa làm'; }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  Icon(icon, size: 22, color: ic),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(log.templateId.substring(0, 8), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                    Text(label, style: GoogleFonts.outfit(fontSize: 11, color: ic, fontWeight: FontWeight.w600)),
                    if (log.notes != null && log.notes!.isNotEmpty)
                      Text(log.notes!, style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
                  ])),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.checklist_rounded, size: 36, color: _kMuted)),
        const SizedBox(height: 14),
        Text('Chưa có dữ liệu hôm nay', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
        const SizedBox(height: 6),
        Text('Nhân viên chưa bắt đầu nhiệm vụ.', style: GoogleFonts.outfit(fontSize: 13, color: _kMuted), textAlign: TextAlign.center),
      ]),
    ),
  );
}
