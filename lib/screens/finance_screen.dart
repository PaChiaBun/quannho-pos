import 'package:flutter/material.dart';
<<<<<<< HEAD
import '../core/utils/money_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

=======
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
import '../modules/finance/providers/finance_providers.dart';
import '../modules/finance/repository/finance_repository.dart';
import '../modules/finance/screens/add_transaction_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PALETTE
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1E1C5E);
const _kNavyL  = Color(0xFF2D2B8A);
const _kOrange = Color(0xFFE85D20);
const _kGreen  = Color(0xFF2E7D32);
const _kRed    = Color(0xFFC62828);
const _kInk    = Color(0xFF1A1207);
const _kMuted  = Color(0xFF9E9085);
const _kBg     = Color(0xFFFAF7F2);
const _kBorder = Color(0xFFE0D8CC);
const _kWhite  = Colors.white;

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE SCREEN — Màn hình Thu Chi
// ─────────────────────────────────────────────────────────────────────────────
class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {

<<<<<<< HEAD
  Future<void> _openAddSheet({String type = 'income'}) async {
    HapticFeedback.selectionClick();
    final result = await showModalBottomSheet<bool>(
=======
  void _openAddSheet({String type = 'income'}) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(initialType: type),
    );
<<<<<<< HEAD
    // Nếu ghi thành công → invalidate tất cả finance providers
    if (result == true) {
      ref.invalidate(financeRecordsProvider);     // list giao dịch
      ref.invalidate(financeStatsProvider);       // stats header kỳ đang chọn
      ref.invalidate(todayFinanceStatsProvider);  // stats header hôm nay
    }
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  }

  @override
  Widget build(BuildContext context) {
    final periodState = ref.watch(periodProvider);
    final statsAsync  = ref.watch(financeStatsProvider);
    final filterType  = ref.watch(financeFilterProvider);
    final recordsAsync = ref.watch(filteredRecordsProvider);

<<<<<<< HEAD
    final mainContent = Column(
      children: [
        _buildHeader(statsAsync, periodState),
        _buildPeriodChips(periodState),
        _buildFilterTabs(filterType),
        Expanded(child: _buildList(recordsAsync)),
      ],
    );

    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(
              children: [
                Expanded(flex: 3, child: mainContent),
                SizedBox(
                  width: 280,
                  child: _FinanceRightPanel(
                    todayStatsAsync: ref.watch(todayFinanceStatsProvider),
                    recordsAsync: recordsAsync,
                  ),
                ),
              ],
            );
          }
          return mainContent;
        },
=======
    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Header gradient ─────────────────────────────────────────
          _buildHeader(statsAsync, periodState),

          // ── Period chips ────────────────────────────────────────────
          _buildPeriodChips(periodState),

          // ── Filter tabs ─────────────────────────────────────────────
          _buildFilterTabs(filterType),

          // ── Transaction list ────────────────────────────────────────
          Expanded(child: _buildList(recordsAsync)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'finance_fab_expense',
            mini: true,
            onPressed: () => _openAddSheet(type: 'expense'),
            backgroundColor: _kRed,
            foregroundColor: _kWhite,
            elevation: 2,
            child: const Icon(Icons.trending_down_rounded, size: 20),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'finance_fab_income',
            onPressed: () => _openAddSheet(type: 'income'),
            backgroundColor: _kGreen,
            foregroundColor: _kWhite,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ghi thu',
              style: TextStyle(fontWeight: FontWeight.w700)),
            elevation: 4,
          ),
        ],
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
      ),
    );
  }

<<<<<<< HEAD

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<FinanceStats> statsAsync, DateRange period) {
<<<<<<< HEAD
    final periods = [
      ('today', 'Hôm nay'),
      ('week',  'Tuần'),
      ('month', 'Tháng'),
    ];

=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavy, _kNavyL],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
<<<<<<< HEAD
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + Period tabs ──
              Row(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Thu Chi',
                    style: TextStyle(
                      color: _kWhite, fontSize: 24,
                      fontWeight: FontWeight.w900, letterSpacing: -0.8)),
                  const SizedBox(height: 1),
                  const Text('Doanh thu POS · Chi phí vận hành',
                    style: TextStyle(color: Colors.white38, fontSize: 11)),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.circular(10)),
                  child: Row(children: periods.map((p) {
                    final active = period.label == p.$2 ||
                      (p.$1 == 'today' && period.label == 'Hôm nay') ||
                      (p.$1 == 'week'  && period.label == 'Tuần này') ||
                      (p.$1 == 'month' && period.label == 'Tháng này');
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        switch (p.$1) {
                          case 'today': ref.read(periodProvider.notifier).setToday(); break;
                          case 'week':  ref.read(periodProvider.notifier).setThisWeek(); break;
                          case 'month': ref.read(periodProvider.notifier).setThisMonth(); break;
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: active ? _kWhite : Colors.transparent,
                          borderRadius: BorderRadius.circular(7)),
                        child: Text(p.$2,
                          style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: active ? _kNavy : Colors.white60))),
                    );
                  }).toList()),
                ),
              ]),
              const SizedBox(height: 18),

              // ── Stats ──
=======
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text('Thu Chi',
                style: TextStyle(
                  color: _kWhite, fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                )),
              const SizedBox(height: 16),

>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
              statsAsync.when(
                loading: () => const _HeaderSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Column(
<<<<<<< HEAD
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Lợi nhuận hero
                    Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LỢI NHUẬN',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                          const SizedBox(height: 4),
                          Text(
                            '${stats.profit >= 0 ? '+ ' : '- '}${_fmtMoney(stats.profit.abs().toInt())}',
                            style: TextStyle(
                              color: stats.profit >= 0
                                ? const Color(0xFF81C784)
                                : const Color(0xFFEF9A9A),
                              fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                          Text('Biên lợi nhuận: ${stats.profitMargin.toStringAsFixed(1)}%',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11)),
                        ],
                      )),
                      if (stats.prevIncome > 0) _GrowthBadge(pct: stats.incomeGrowth),
                    ]),
                    const SizedBox(height: 14),

                    // Tổng thu / Tổng chi — 2 tile
                    Row(children: [
                      _StatTile(label: 'Tổng thu', value: stats.income,
                        icon: Icons.trending_up_rounded, color: const Color(0xFF81C784)),
                      const SizedBox(width: 10),
                      _StatTile(label: 'Tổng chi', value: stats.expense,
                        icon: Icons.trending_down_rounded, color: const Color(0xFFEF9A9A)),
                    ]),
                    const SizedBox(height: 12),

                    // ── 2 Action buttons — đồng nhất, solid ──
                    Row(children: [
                      // GHI THU — xanh solid
                      Expanded(child: _ActionBtn(
                        label: '+ Ghi thu',
                        bgColor: const Color(0xFF2E7D32),
                        textColor: Colors.white,
                        shadowColor: const Color(0xFF1B5E20),
                        onTap: () => _openAddSheet(type: 'income'),
                      )),
                      const SizedBox(width: 10),
                      // GHI CHI — đỏ solid
                      Expanded(child: _ActionBtn(
                        label: '− Ghi chi',
                        bgColor: const Color(0xFFC62828),
                        textColor: Colors.white,
                        shadowColor: const Color(0xFF7F0000),
                        onTap: () => _openAddSheet(type: 'expense'),
                      )),
                    ]),
=======
                  children: [
                    // Profit card chính
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0x1AFFFFFF),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0x33FFFFFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Lợi nhuận',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13, fontWeight: FontWeight.w500,
                                )),
                              const Spacer(),
                              if (stats.prevIncome > 0)
                                _GrowthBadge(pct: stats.incomeGrowth),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${stats.profit >= 0 ? '' : '-'}${_fmtMoney(stats.profit.abs().toInt())}đ',
                            style: TextStyle(
                              color: stats.profit >= 0
                                  ? const Color(0xFF81C784)
                                  : const Color(0xFFEF9A9A),
                              fontSize: 30, fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Biên lợi nhuận: ${stats.profitMargin.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Thu / Chi tiles
                    Row(
                      children: [
                        _StatTile(
                          label: 'Tổng thu',
                          value: stats.income,
                          icon: Icons.trending_up_rounded,
                          color: const Color(0xFF81C784),
                        ),
                        const SizedBox(width: 10),
                        _StatTile(
                          label: 'Tổng chi',
                          value: stats.expense,
                          icon: Icons.trending_down_rounded,
                          color: const Color(0xFFEF9A9A),
                        ),
                      ],
                    ),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

<<<<<<< HEAD

  // ─────────────────────────────────────────────────────────────────────────
  // PERIOD CHIPS — đã merge vào header, giữ lại để không break provider
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPeriodChips(DateRange current) => const SizedBox.shrink();
=======
  // ─────────────────────────────────────────────────────────────────────────
  // PERIOD CHIPS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildPeriodChips(DateRange current) {
    final periods = [
      ('today',   'Hôm nay'),
      ('week',    'Tuần này'),
      ('month',   'Tháng này'),
    ];

    return Container(
      color: _kNavy,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Row(
        children: periods.map((p) {
          final active = current.label == p.$2;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                switch (p.$1) {
                  case 'today': ref.read(periodProvider.notifier).setToday(); break;
                  case 'week':  ref.read(periodProvider.notifier).setThisWeek(); break;
                  case 'month': ref.read(periodProvider.notifier).setThisMonth(); break;
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: active
                      ? _kOrange
                      : const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: active
                        ? _kOrange
                        : const Color(0x33FFFFFF),
                  ),
                ),
                child: Text(p.$2,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: active ? _kWhite : Colors.white60,
                  )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df

  // ─────────────────────────────────────────────────────────────────────────
  // FILTER TABS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterTabs(String? filterType) {
    return Container(
      color: _kWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Text('Giao dịch',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: _kInk, letterSpacing: -0.3)),
          const Spacer(),
          _FilterChip(
            label: 'Tất cả',
            active: filterType == null,
            color: _kNavy,
            onTap: () => ref.read(financeFilterProvider.notifier).showAll(),
          ),
          const SizedBox(width: 6),
          _FilterChip(
<<<<<<< HEAD
            label: '↑ Thu',
=======
            label: '↓ Thu',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
            active: filterType == 'income',
            color: _kGreen,
            onTap: () => ref.read(financeFilterProvider.notifier).showIncome(),
          ),
          const SizedBox(width: 6),
          _FilterChip(
<<<<<<< HEAD
            label: '↓ Chi',
=======
            label: '↑ Chi',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
            active: filterType == 'expense',
            color: _kRed,
            onTap: () =>
                ref.read(financeFilterProvider.notifier).showExpense(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TRANSACTION LIST
  // ─────────────────────────────────────────────────────────────────────────
<<<<<<< HEAD
  Widget _buildList(AsyncValue<List<FinanceRecordModel>> recordsAsync) {
    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (records) {
        if (records.isEmpty) return _buildEmpty();
        // Group by date
        final items = <dynamic>[];
        String? lastKey;
        for (final r in records) {
          final dt = r.recordedAt.toLocal();
          final key = '${dt.year}${dt.month.toString().padLeft(2,'0')}${dt.day.toString().padLeft(2,'0')}';
          if (key != lastKey) { lastKey = key; items.add(dt); }
          items.add(r);
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            if (item is DateTime) return _DateHeader(date: item);
            final r = item as FinanceRecordModel;
            return _TransactionCard(
              record: r,
              onDelete: r.isAuto ? null : () => _confirmDelete(r),
            )
                .animate(delay: (i * 25).ms)
=======
  Widget _buildList(AsyncValue<List<FinanceRecord>> recordsAsync) {
    return recordsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (records) {
        if (records.isEmpty) {
          return _buildEmpty();
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
          itemCount: records.length,
          itemBuilder: (_, i) {
            return _TransactionCard(
              record:   records[i],
              onDelete: records[i].isAuto
                  ? null
                  : () => _confirmDelete(records[i]),
            )
                .animate(delay: (i * 35).ms)
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                .fadeIn(duration: 200.ms)
                .slideY(begin: 0.04, end: 0, duration: 200.ms);
          },
        );
      },
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.receipt_long_rounded,
          size: 72, color: _kMuted.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        const Text('Chưa có giao dịch nào',
          style: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w600,
            color: _kMuted)),
        const SizedBox(height: 8),
        const Text('Nhấn nút bên dưới để ghi thu/chi',
          style: TextStyle(fontSize: 13, color: _kMuted)),
      ],
    ),
  );

<<<<<<< HEAD
  void _confirmDelete(FinanceRecordModel record) {
=======
  void _confirmDelete(FinanceRecord record) {
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Xoá giao dịch?',
          style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          '${record.description ?? 'Giao dịch này'} sẽ bị xoá vĩnh viễn.',
          style: const TextStyle(color: _kMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          ElevatedButton(
<<<<<<< HEAD
            onPressed: () async {
              Navigator.pop(ctx);
              // ‼️ FIX: await + invalidate để UI refresh ngay sau khi xóa
              await ref.read(financeRepositoryProvider).deleteRecord(record.id);
              ref.invalidate(financeRecordsProvider);
              ref.invalidate(financeStatsProvider);
              ref.invalidate(todayFinanceStatsProvider);
=======
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(financeRepositoryProvider).deleteRecord(record.id);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TRANSACTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
<<<<<<< HEAD
  final FinanceRecordModel record;
=======
  final FinanceRecord record;
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  final VoidCallback? onDelete;

  const _TransactionCard({required this.record, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = record.type == 'income';
    final color    = isIncome ? _kGreen : _kRed;
<<<<<<< HEAD
    final dt = record.recordedAt.toLocal();
=======
    final dt = DateTime.fromMillisecondsSinceEpoch(record.recordedAt);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
    final timeStr =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Dismissible(
      key: Key(record.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: _kRed.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: _kRed),
      ),
      confirmDismiss: (_) async {
        onDelete?.call();
        return false; // Let dialog handle it
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          leading: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              color: color, size: 22,
            ),
          ),
          title: Text(
            record.description ?? (isIncome ? 'Thu tiền' : 'Chi tiền'),
            style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: _kInk),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              if (record.isAuto)
<<<<<<< HEAD
                GestureDetector(
                  onTap: () {
                    final desc = record.description ?? 'giao dịch';
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                            color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(
                            'Tự động từ: $desc. Không thể xóa thủ công.',
                            style: const TextStyle(fontSize: 12))),
                        ]),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: _kNavy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      ));
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kNavy.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Auto',
                          style: TextStyle(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: _kNavy)),
                        const SizedBox(width: 2),
                        Icon(Icons.info_outline_rounded,
                          size: 9, color: _kNavy.withValues(alpha: 0.5)),
                      ],
                    ),
                  ),
=======
                Container(
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Auto',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: _kNavy)),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                ),
              Text(
                '$timeStr  •  ${_dayLabel(dt)}',
                style: const TextStyle(fontSize: 12, color: _kMuted),
              ),
            ],
          ),
          trailing: Text(
<<<<<<< HEAD
            '${isIncome ? '+' : '-'}${_fmtMoney(record.amount.toInt())}',
=======
            '${isIncome ? '+' : '-'}${_fmtMoney(record.amount.toInt())}đ',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800,
              color: color),
          ),
          onLongPress: onDelete,
        ),
      ),
    );
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month) return 'Hôm nay';
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.day == yesterday.day && dt.month == yesterday.month) {
      return 'Hôm qua';
    }
    return '${dt.day}/${dt.month}';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  const _StatTile({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(
                    fontSize: 11, color: Colors.white54,
                    fontWeight: FontWeight.w500)),
<<<<<<< HEAD
                Text('${_fmtShort(value)}',
=======
                Text('${_fmtShort(value)}đ',
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                  style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800,
                    color: color)),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _GrowthBadge extends StatelessWidget {
  final double pct;
  const _GrowthBadge({required this.pct});

  @override
  Widget build(BuildContext context) {
    final isUp = pct >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUp
            ? const Color(0xFF81C784).withValues(alpha: 0.2)
            : const Color(0xFFEF9A9A).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: isUp
                ? const Color(0xFF81C784)
                : const Color(0xFFEF9A9A)),
          const SizedBox(width: 2),
          Text('${pct.abs().toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: isUp
                  ? const Color(0xFF81C784)
                  : const Color(0xFFEF9A9A))),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      HapticFeedback.selectionClick();
      onTap();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? color : _kBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color : _kBorder),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: active ? _kWhite : _kMuted)),
    ),
  );
}

<<<<<<< HEAD
// ─────────────────────────────────────────────────────────────────────────────
// ACTION BUTTON — nút solid đồng nhất (Ghi thu / Ghi chi)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionBtn extends StatefulWidget {
  final String label;
  final Color bgColor, textColor, shadowColor;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.bgColor,
    required this.textColor, required this.shadowColor, required this.onTap});
  @override State<_ActionBtn> createState() => _ActionBtnState();
}
class _ActionBtnState extends State<_ActionBtn> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override void initState() { super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _s = Tween<double>(begin: 1.0, end: 0.93).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) { HapticFeedback.lightImpact(); _c.forward(); },
    onTapUp: (_) { _c.reverse(); widget.onTap(); },
    onTapCancel: () => _c.reverse(),
    child: AnimatedBuilder(animation: _s,
      builder: (_, ch) => Transform.scale(scale: _s.value, child: ch),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: widget.bgColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(
            color: widget.shadowColor.withValues(alpha: 0.45),
            blurRadius: 10, offset: const Offset(0, 4))]),
        child: Center(child: Text(widget.label,
          style: TextStyle(
            color: widget.textColor,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2))),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER SKELETON
// ─────────────────────────────────────────────────────────────────────────────
=======
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 130,
    child: Center(child: CircularProgressIndicator(
      color: Colors.white54, strokeWidth: 2)),
  );
}

<<<<<<< HEAD
// ─────────────────────────────────────────────────────────────────────────────
// DATE HEADER — phân nhóm giao dịch theo ngày
// ─────────────────────────────────────────────────────────────────────────────
class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      label = 'Hôm nay';
    } else {
      final yd = now.subtract(const Duration(days: 1));
      if (date.year == yd.year && date.month == yd.month && date.day == yd.day) {
        label = 'Hôm qua';
      } else {
        const days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
        label = '${days[date.weekday % 7]}, ${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}';
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Row(children: [
        Text(label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800,
              color: _kMuted, letterSpacing: 0.3)),
        const SizedBox(width: 8),
        Expanded(child: Divider(color: _kBorder, height: 1)),
      ]),
    );
  }
}




// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fmtMoney(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

String _fmtShort(double v) => fmtMoney(v);

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Tổng quan hôm nay + Giao dịch gần đây
// ─────────────────────────────────────────────────────────────────────────────
class _FinanceRightPanel extends StatelessWidget {
  final AsyncValue<FinanceStats> todayStatsAsync;
  final AsyncValue<List<FinanceRecordModel>> recordsAsync;
  const _FinanceRightPanel({
    required this.todayStatsAsync,
    required this.recordsAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          // ── Hôm nay ─────────────────────────────────────────────────
          _FRightCard(
            title: 'Hôm nay',
            icon: Icons.today_rounded,
            child: todayStatsAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const Text('Lỗi'),
              data: (stats) => Column(children: [
                _FStatRow(
                  label: 'Thu',
                  value: fmtMoney(stats.income),
                  color: _kGreen,
                ),
                const Divider(height: 1),
                _FStatRow(
                  label: 'Chi',
                  value: fmtMoney(stats.expense),
                  color: _kRed,
                ),
                const Divider(height: 1),
                _FStatRow(
                  label: 'Lãi ròng',
                  value: '${stats.profit >= 0 ? '+' : ''}${fmtMoney(stats.profit)}',
                  color: stats.profit >= 0 ? _kGreen : _kRed,
                ),
                if (stats.profitMargin != 0) ...[
                  const Divider(height: 1),
                  _FStatRow(
                    label: 'Biên LN',
                    value: '${stats.profitMargin.toStringAsFixed(1)}%',
                    color: _kNavy,
                  ),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // ── Giao dịch gần đây ───────────────────────────────────────
          _FRightCard(
            title: 'Giao dịch gần đây',
            icon: Icons.receipt_long_rounded,
            child: recordsAsync.when(
              loading: () => const SizedBox(
                height: 60,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => const Text('Lỗi'),
              data: (records) {
                if (records.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Chưa có giao dịch',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 12, color: _kMuted)),
                  );
                }
                final recent = records.take(5).toList();
                return Column(
                  children: recent.map((r) {
                    final isIncome = r.type == 'income';
                    final color = isIncome ? _kGreen : _kRed;
                    final dt = r.recordedAt.toLocal();
                    final time = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                            size: 14, color: color),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.description ?? (isIncome ? 'Thu' : 'Chi'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12, fontWeight: FontWeight.w600,
                                  color: _kInk),
                              ),
                              Text(time,
                                style: GoogleFonts.outfit(
                                  fontSize: 10, color: _kMuted)),
                            ],
                          ),
                        ),
                        Text(
                          '${isIncome ? '+' : '-'}${fmtMoney(r.amount)}',
                          style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: color),
                        ),
                      ]),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FRightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _FRightCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: _kNavy.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Icon(icon, size: 16, color: _kNavy),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
        ]),
      ),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

class _FStatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _FStatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kNavy))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
=======
// Helpers
String _fmtMoney(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

String _fmtShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
}
