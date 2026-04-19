import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/database/app_database.dart';
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

  void _openAddSheet({String type = 'income'}) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTransactionSheet(initialType: type),
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodState = ref.watch(periodProvider);
    final statsAsync  = ref.watch(financeStatsProvider);
    final filterType  = ref.watch(financeFilterProvider);
    final recordsAsync = ref.watch(filteredRecordsProvider);

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
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(AsyncValue<FinanceStats> statsAsync, DateRange period) {
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

              statsAsync.when(
                loading: () => const _HeaderSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) => Column(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            label: '↓ Thu',
            active: filterType == 'income',
            color: _kGreen,
            onTap: () => ref.read(financeFilterProvider.notifier).showIncome(),
          ),
          const SizedBox(width: 6),
          _FilterChip(
            label: '↑ Chi',
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

  void _confirmDelete(FinanceRecord record) {
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
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(financeRepositoryProvider).deleteRecord(record.id);
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
  final FinanceRecord record;
  final VoidCallback? onDelete;

  const _TransactionCard({required this.record, this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isIncome = record.type == 'income';
    final color    = isIncome ? _kGreen : _kRed;
    final dt = DateTime.fromMillisecondsSinceEpoch(record.recordedAt);
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
                ),
              Text(
                '$timeStr  •  ${_dayLabel(dt)}',
                style: const TextStyle(fontSize: 12, color: _kMuted),
              ),
            ],
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'}${_fmtMoney(record.amount.toInt())}đ',
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
                Text('${_fmtShort(value)}đ',
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

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 130,
    child: Center(child: CircularProgressIndicator(
      color: Colors.white54, strokeWidth: 2)),
  );
}

// Helpers
String _fmtMoney(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

String _fmtShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}
