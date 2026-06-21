import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../providers/ops_providers.dart';
import '../repository/ops_repository.dart';
import '../../../core/providers/session_provider.dart';

// ── Màu theo design system Quán Nhỏ ─────────────────────────────────────────
const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kGreen  = Color(0xFF22C55E);
const _kRed    = Color(0xFFEF4444);
const _kMuted  = Color(0xFF9E9085);

class OpsStaffScreen extends ConsumerStatefulWidget {
  const OpsStaffScreen({super.key});

  @override
  ConsumerState<OpsStaffScreen> createState() => _OpsStaffScreenState();
}

class _OpsStaffScreenState extends ConsumerState<OpsStaffScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureLogs());
  }

  Future<void> _ensureLogs() async {
    final session   = ref.read(sessionProvider);
    if (session == null) return;
    final repo      = ref.read(opsRepositoryProvider);
    final templates = await ref.read(opsMyTemplatesProvider.future);
    if (templates.isEmpty) return;
    await repo.ensureMyLogsToday(
      staffId:   session.userId,
      staffName: session.displayName,
      templates: templates,
    );
    ref.invalidate(opsMyLogsProvider);
  }

  Future<void> _complete(OpsDailyLogModel log, OpsTaskTemplateModel template) async {
    HapticFeedback.lightImpact();
    if (template.requiresPhoto) {
      await _completeWithPhoto(log);
    } else {
      await ref.read(opsRepositoryProvider).completeTask(logId: log.id);
      ref.invalidate(opsMyLogsProvider);
    }
  }

  Future<void> _completeWithPhoto(OpsDailyLogModel log) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,   // ~80KB/ảnh
      maxWidth: 800,
    );
    if (image == null || !mounted) return;

    final session = ref.read(sessionProvider);
    if (session == null) return;

    // Show uploading indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const SizedBox(width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            const SizedBox(width: 12),
            Text('Đang lưu ảnh bằng chứng...', style: GoogleFonts.outfit()),
          ]),
          duration: const Duration(seconds: 10),
          backgroundColor: _kNavy,
        ),
      );
    }

    final repo = ref.read(opsRepositoryProvider);
    final storeId = session.storeId ?? '';
    final photoUrl = await repo.uploadProofPhoto(
      logId:    log.id,
      storeId:  storeId,
      filePath: image.path,   // truyền filePath thay vì bytes
      extension: 'jpg',
    );

    await repo.completeTask(logId: log.id, proofPhotoUrl: photoUrl);
    ref.invalidate(opsMyLogsProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      // Phân biệt Drive vs Supabase trong thông báo
      final isDrive = photoUrl != null && photoUrl.contains('drive.google.com');
      final msg = photoUrl == null
          ? '✅ Hoàn thành (lưu ảnh thất bại)'
          : isDrive
              ? '✅ Hoàn thành · Ảnh lưu Google Drive'
              : '✅ Hoàn thành · Ảnh lưu Cloud';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.outfit()),
          backgroundColor: photoUrl != null ? _kGreen : _kOrange,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _completeWithNote(OpsDailyLogModel log) async {
    final notes = await showDialog<String>(
      context: context,
      builder: (_) => const _NoteDialog(),
    );
    if (!mounted) return;
    await ref.read(opsRepositoryProvider).completeTask(logId: log.id, notes: notes);
    ref.invalidate(opsMyLogsProvider);
  }

  Future<void> _showHandoverSheet(List<OpsDailyLogModel> allLogs) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandoverSheet(
        pendingLogs: allLogs.where((l) => l.isPending).toList(),
        onSubmit: (h) async {
          await ref.read(opsRepositoryProvider).createHandover(h);
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('📋 Bàn giao ca đã lưu!', style: GoogleFonts.outfit()),
              backgroundColor: _kNavy,
            ));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session   = ref.watch(sessionProvider);
    final logsAsync = ref.watch(opsMyLogsProvider);
    final tmplAsync = ref.watch(opsMyTemplatesProvider);
    final today     = DateFormat('EEEE, d/M/yyyy', 'vi').format(DateTime.now());

    final shiftsAsync = ref.watch(opsShiftConfigsProvider);
    final now = DateTime.now();
    final shifts = shiftsAsync.value ?? [];
    final currentShift = shifts.where((s) => s.isCurrentShift(now)).firstOrNull;

    return logsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
      error:   (e, _) => Center(child: Text('Lỗi: $e')),
      data: (logs) {
        final templateMap = tmplAsync.value?.fold<Map<String, OpsTaskTemplateModel>>(
          {}, (m, t) { m[t.id] = t; return m; }) ?? {};

        final done  = logs.where((l) => l.isCompleted).length;
        final total = logs.length;

        final grouped = <String, List<(OpsTaskTemplateModel, OpsDailyLogModel)>>{};
        for (final log in logs) {
          final t = templateMap[log.templateId];
          if (t == null) continue;
          final key = t.targetTime ?? 'Khác';
          grouped.putIfAbsent(key, () => []).add((t, log));
        }
        final sortedKeys = grouped.keys.toList()..sort(_compareTime);

        return RefreshIndicator(
          color: _kNavy,
          onRefresh: _ensureLogs,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _ProgressHeader(
                  staffName: session?.displayName ?? '',
                  staffRole: session?.role ?? '',
                  today: today,
                  done: done,
                  total: total,
                  shiftName: currentShift?.name,
                  shiftLabel: currentShift?.timeLabel,
                ),
              ),
              // Overdue banner
              Builder(builder: (_) {
                final now = DateTime.now();
                final nowMins = now.hour * 60 + now.minute;
                final overdueLogs = logs.where((log) {
                  if (log.isCompleted || log.isMissed) return false;
                  final t = templateMap[log.templateId];
                  final time = t?.targetTime;
                  if (time == null || time == 'Cuối ca' || time == 'Khác') return false;
                  final parts = time.split(':');
                  if (parts.length < 2) return false;
                  final tMins = (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
                  return nowMins > tMins + 15;
                }).toList();
                if (overdueLogs.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                return SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kRed.withValues(alpha: 0.25)),
                    ),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: _kRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(
                        '${overdueLogs.length} công việc đã quá giờ mục tiêu',
                        style: GoogleFonts.outfit(
                          fontSize: 12, fontWeight: FontWeight.w700, color: _kRed),
                      )),
                    ]),
                  ),
                );
              }),

              if (logs.isEmpty)
                const SliverFillRemaining(child: _EmptyState())

              else
                for (final key in sortedKeys) ...[
                  SliverToBoxAdapter(child: _TimeGroupHeader(time: key)),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final (tmpl, log) = grouped[key]![i];
                        return _TaskCard(
                          template: tmpl,
                          log: log,
                          onComplete:  () => _complete(log, tmpl),
                          onLongPress: () => _completeWithNote(log),
                        );
                      },
                      childCount: grouped[key]!.length,
                    ),
                  ),
                ],

              // Bottom padding + Handover button
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  child: OutlinedButton.icon(
                    onPressed: () => _showHandoverSheet(logs),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                    label: Text('Bàn Giao Ca', style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _kNavy,
                      side: BorderSide(color: _kNavy.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  int _compareTime(String a, String b) {
    if (a == 'Cuối ca') return 1;
    if (b == 'Cuối ca') return -1;
    if (a == 'Khác') return 1;
    if (b == 'Khác') return -1;
    return a.compareTo(b);
  }
}

// ── Progress Header ────────────────────────────────────────────────────────────
class _ProgressHeader extends StatelessWidget {
  final String staffName, staffRole, today;
  final int done, total;
  final String? shiftName, shiftLabel;
  const _ProgressHeader({
    required this.staffName,
    required this.staffRole,
    required this.today,
    required this.done,
    required this.total,
    this.shiftName,
    this.shiftLabel,
  });

  String _roleLabel() {
    switch (staffRole.toLowerCase()) {
      case 'owner':   return 'Chủ quán';
      case 'manager': return 'Quản lý';
      case 'cashier': return 'Thu ngân';
      case 'waiter':  return 'Phục vụ';
      case 'kitchen': return 'Bếp';
      case 'bar':     return 'Bartender';
      case 'stock':   return 'Kho';
      case 'guard':   return 'Bảo vệ';
      case 'cleaner': return 'Vệ sinh';
      default:        return staffRole.isNotEmpty ? staffRole : 'Nhân viên';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pct      = total == 0 ? 0.0 : done / total;
    final isAllDone = pct >= 1 && total > 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_kNavy, Color(0xFF2D3580)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _kNavy.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + date
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.waving_hand_rounded, color: _kOrange, size: 14),
                        const SizedBox(width: 5),
                        Text(
                          staffName.isNotEmpty ? staffName : 'Nhân viên',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  // Role badge
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _kOrange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kOrange.withValues(alpha: 0.5), width: 1),
                    ),
                    child: Text(
                      _roleLabel(),
                      style: GoogleFonts.outfit(
                        color: _kOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  // Current shift badge
                  if (shiftName != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.schedule_rounded,
                            size: 10, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          '$shiftName${shiftLabel != null ? ' • $shiftLabel' : ''}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ]),
                    ),
                  ],
                ],
              ),
              const Spacer(),
              Text(
                today,
                style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TIẾN ĐỘ HÔM NAY',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '$done',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: GoogleFonts.outfit(
                              color: Colors.white54,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' nhiệm vụ',
                            style: GoogleFonts.outfit(
                              color: Colors.white38,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isAllDone ? _kOrange : Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: isAllDone
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 5),
                          Text('Hoàn thành!', style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
                        ],
                      )
                    : Text('${(pct * 100).round()}%', style: GoogleFonts.outfit(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Progress bar
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: isAllDone ? _kOrange : _kGreen,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Time Group Header ─────────────────────────────────────────────────────────
class _TimeGroupHeader extends StatelessWidget {
  final String time;
  const _TimeGroupHeader({required this.time});

  @override
  Widget build(BuildContext context) {
    final isCuoiCa = time == 'Cuối ca';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: isCuoiCa
                  ? const Color(0xFFEDE9FE)
                  : const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isCuoiCa
                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.4)
                    : _kNavy.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 12,
                  color: isCuoiCa ? const Color(0xFF7C3AED) : _kNavy,
                ),
                const SizedBox(width: 5),
                Text(
                  time,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isCuoiCa ? const Color(0xFF7C3AED) : _kNavy,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: _kNavy.withValues(alpha: 0.08),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Task Card ─────────────────────────────────────────────────────────────────
class _TaskCard extends StatefulWidget {
  final OpsTaskTemplateModel template;
  final OpsDailyLogModel log;
  final VoidCallback onComplete;
  final VoidCallback onLongPress;

  const _TaskCard({
    required this.template,
    required this.log,
    required this.onComplete,
    required this.onLongPress,
  });

  @override
  State<_TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<_TaskCard> {
  bool _expanded = false;

  bool _isOverdue() {
    if (widget.log.isCompleted || widget.log.isMissed) return false;
    final t = widget.template.targetTime;
    if (t == null || t == 'Cuối ca' || t == 'Khác') return false;
    final parts = t.split(':');
    if (parts.length < 2) return false;
    final targetMins = int.tryParse(parts[0])! * 60 + int.tryParse(parts[1])!;
    final now = DateTime.now();
    return (now.hour * 60 + now.minute) > targetMins + 15;
  }

  @override
  Widget build(BuildContext context) {
    final overdue = _isOverdue();
    final isDone  = widget.log.isCompleted;
    final isBad   = widget.log.isMissed || overdue;
    final hasDesc = widget.template.description != null && widget.template.description!.isNotEmpty;

    final Color accentColor = isDone
        ? const Color(0xFFCBD5E1)
        : overdue
            ? _kRed
            : widget.template.priority == 'critical'
                ? _kRed
                : widget.template.priority == 'high'
                    ? const Color(0xFFF97316)
                    : _kGreen;

    return GestureDetector(
      onLongPress: isDone ? null : widget.onLongPress,
      onTap: hasDesc ? () => setState(() => _expanded = !_expanded) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        decoration: BoxDecoration(
          color: isDone ? const Color(0xFFF8F9FA) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone
                ? const Color(0xFFE9ECEF)
                : isBad
                    ? _kRed.withValues(alpha: 0.25)
                    : _expanded
                        ? _kGreen.withValues(alpha: 0.4)
                        : const Color(0xFFE8E3DC),
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: isDone
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: _expanded ? 0.07 : 0.04),
                    blurRadius: _expanded ? 14 : 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(width: 4, color: accentColor),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.template.title,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDone ? const Color(0xFFADB5BD) : _kNavy,
                                        decoration: isDone ? TextDecoration.lineThrough : null,
                                        decorationColor: const Color(0xFFADB5BD),
                                      ),
                                    ),
                                  ),
                                  if (hasDesc && !isDone)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 4),
                                      child: Icon(
                                        _expanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        size: 16,
                                        color: _kNavy.withValues(alpha: 0.35),
                                      ),
                                    ),
                                ],
                              ),

                              // Description — collapsed: 1 line | expanded: full
                              if (hasDesc)
                                AnimatedCrossFade(
                                  duration: const Duration(milliseconds: 200),
                                  crossFadeState: _expanded
                                      ? CrossFadeState.showSecond
                                      : CrossFadeState.showFirst,
                                  // Collapsed — 1 dòng mờ
                                  firstChild: Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      widget.template.description!,
                                      style: GoogleFonts.outfit(
                                        fontSize: 11.5,
                                        color: isDone
                                            ? const Color(0xFFCED4DA)
                                            : const Color(0xFF546E7A),
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  // Expanded — bullet points
                                  secondChild: _DescriptionBullets(
                                    text: widget.template.description!,
                                  ),
                                ),

                              // Status indicators
                              if (isDone && widget.log.completedAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline_rounded, size: 11, color: _kGreen),
                                      const SizedBox(width: 3),
                                      Text(
                                        _fmtTime(widget.log.completedAt!),
                                        style: GoogleFonts.outfit(fontSize: 11, color: _kGreen, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              if (overdue && !isDone)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    'Quá giờ!',
                                    style: GoogleFonts.outfit(fontSize: 10, color: _kRed, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              if (widget.log.notes != null && widget.log.notes!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    widget.log.notes!,
                                    style: GoogleFonts.outfit(fontSize: 10, color: _kMuted, fontStyle: FontStyle.italic),
                                    maxLines: _expanded ? null : 1,
                                    overflow: _expanded ? null : TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Check button (green)
                        if (!isDone)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: widget.onComplete,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isBad ? _kRed : _kGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}

// ── Description Bullets ───────────────────────────────────────────────────────
class _DescriptionBullets extends StatelessWidget {
  final String text;
  const _DescriptionBullets({required this.text});

  List<String> _parse() {
    // Tách theo: '. ', '; ', ' - ', ' + ', '\n'
    final raw = text
        .replaceAll(RegExp(r'\s*\.\s+'), '|')
        .replaceAll(RegExp(r';\s*'), '|')
        .replaceAll(RegExp(r'\n+'), '|')
        .split('|')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    // Nếu chỉ 1 phần (câu dài không tách được) → giữ nguyên 1 item
    return raw.isEmpty ? [text.trim()] : raw;
  }

  @override
  Widget build(BuildContext context) {
    final items = _parse();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((e) {
          final idx = e.key;
          final line = e.value;
          return Padding(
            padding: EdgeInsets.only(top: idx == 0 ? 0 : 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bullet dot
                Padding(
                  padding: const EdgeInsets.only(top: 5, right: 7),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF37474F),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line,
                    style: GoogleFonts.outfit(
                      fontSize: 12.5,
                      color: const Color(0xFF37474F),
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.checklist_rounded, size: 40, color: _kMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có công việc nào',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy),
            ),
            const SizedBox(height: 8),
            Text(
              'Quản lý chưa thiết lập checklist.\nVui lòng liên hệ quản lý để cài đặt.',
              style: GoogleFonts.outfit(fontSize: 13, color: _kMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Note Dialog ───────────────────────────────────────────────────────────────
class _NoteDialog extends StatefulWidget {
  const _NoteDialog();

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      title: Text('Ghi chú sự cố', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: _kNavy)),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: 'VD: Toilet bị tắc, đã báo quản lý...',
          hintStyle: GoogleFonts.outfit(color: _kMuted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _kNavy, width: 2),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text('Bỏ qua', style: GoogleFonts.outfit(color: _kMuted)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: Text('Hoàn thành', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

// ── Handover Sheet ────────────────────────────────────────────────────────────
class _HandoverSheet extends ConsumerStatefulWidget {
  final List<OpsDailyLogModel> pendingLogs;
  final Future<void> Function(OpsShiftHandoverModel) onSubmit;
  const _HandoverSheet({required this.pendingLogs, required this.onSubmit});

  @override
  ConsumerState<_HandoverSheet> createState() => _HandoverSheetState();
}

class _HandoverSheetState extends ConsumerState<_HandoverSheet> {
  final _issuesCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  bool _saving = false;

  @override
  void dispose() { _issuesCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    if (session == null) return;
    final pending = widget.pendingLogs.map((l) => l.id).toList();
    final handover = OpsShiftHandoverModel(
      id:            const Uuid().v4(),
      storeId:       session.storeId ?? '',
      handoverDate:  DateTime.now().toIso8601String().substring(0, 10),
      createdBy:     session.userId,
      createdByName: session.displayName,
      issues:        _issuesCtrl.text.trim().isEmpty ? null : _issuesCtrl.text.trim(),
      notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      pendingTasks:  pending,
      createdAt:     DateTime.now().toIso8601String(),
    );
    try {
      await widget.onSubmit(handover);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Row(children: [
            Container(padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.swap_horiz_rounded, color: _kNavy, size: 20)),
            const SizedBox(width: 12),
            Text('Bàn Giao Ca', style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
          ]),
          const SizedBox(height: 6),
          Text('Ghi chú cho ca tiếp theo',
            style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 14),
          if (widget.pendingLogs.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: _kOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.pending_actions_rounded, color: _kOrange, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('${widget.pendingLogs.length} công việc chưa xong sẽ được ghi nhận',
                  style: GoogleFonts.outfit(fontSize: 12, color: _kOrange, fontWeight: FontWeight.w600))),
              ]),
            ),
          TextField(
            controller: _issuesCtrl, maxLines: 2,
            decoration: InputDecoration(
              labelText: '⚠️ Vấn đề tồn đọng',
              hintText: 'VD: Máy pha cà phê hỏng nút steam...',
              labelStyle: GoogleFonts.outfit(color: _kMuted, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kNavy, width: 2)),
            ),
            style: GoogleFonts.outfit(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _notesCtrl, maxLines: 2,
            decoration: InputDecoration(
              labelText: '📝 Ghi chú cho ca sau',
              hintText: 'VD: Bàn 5 đặt lúc 3pm, hết đường phèn...',
              labelStyle: GoogleFonts.outfit(color: _kMuted, fontSize: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _kNavy, width: 2)),
            ),
            style: GoogleFonts.outfit(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text('Xác nhận bàn giao', style: GoogleFonts.outfit(
                  fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: _kNavy, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
        ],
      ),
    );
  }
}
