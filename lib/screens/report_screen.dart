import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/providers/dashboard_providers.dart';
import '../core/repositories/dashboard_repository.dart';
import '../modules/finance/providers/finance_providers.dart';
import '../modules/finance/repository/finance_repository.dart';
import '../core/providers/app_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REPORT SCREEN — Báo cáo tổng hợp
// ─────────────────────────────────────────────────────────────────────────────

const _kNavy   = Color(0xFF1E1C5E);
const _kNavyL  = Color(0xFF2D2B8A);
const _kOrange = Color(0xFFE85D20);
const _kGreen  = Color(0xFF2E7D32);
const _kRed    = Color(0xFFC62828);
const _kGold   = Color(0xFFF9A825);
const _kInk    = Color(0xFF1A1207);
const _kMuted  = Color(0xFF9E9085);
const _kBg     = Color(0xFFFAF7F2);
const _kBorder = Color(0xFFE0D8CC);

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync       = ref.watch(todayStatsProvider);
    final last7Async       = ref.watch(last7DaysRevenueProvider);
    final topProductsAsync = ref.watch(topProductsTodayProvider);
    final financeStats     = ref.watch(financeStatsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: Column(
        children: [
          // ── Header ───────────────────────────────────────────────
          _buildHeader(statsAsync, financeStats),

          // ── TabBar ───────────────────────────────────────────────
          Container(
            color: _kNavy,
            child: TabBar(
              controller: _tab,
              indicatorColor: _kOrange,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 13),
              tabs: const [
                Tab(text: 'Doanh thu'),
                Tab(text: 'Sản phẩm'),
                Tab(text: 'Tài chính'),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _RevenueTab(last7Async: last7Async, statsAsync: statsAsync),
                _ProductTab(topProductsAsync: topProductsAsync),
                _FinanceTab(financeStats: financeStats),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader(
    AsyncValue<DashboardStats> statsAsync,
    AsyncValue<FinanceStats> financeAsync,
  ) {
    final stats   = statsAsync.value ?? const DashboardStats(
      todayRevenue: 0, todayOrders: 0, todayCustomers: 0, avgOrderValue: 0);
    final finance = financeAsync.value ?? FinanceStats.empty;

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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Báo cáo',
                    style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w900, letterSpacing: -0.3,
                    )),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Hôm nay, ${DateFormat('dd/MM').format(DateTime.now())}',
                      style: const TextStyle(
                        color: Colors.white70, fontSize: 12,
                        fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // KPI row
              Row(
                children: [
                  _KpiCard(
                    label: 'Doanh thu',
                    value: _fmt(stats.todayRevenue),
                    unit: 'đ',
                    icon: Icons.trending_up_rounded,
                    color: const Color(0xFF4CAF50),
                    growth: finance.incomeGrowth,
                  ),
                  const SizedBox(width: 10),
                  _KpiCard(
                    label: 'Lợi nhuận',
                    value: _fmt(finance.profit),
                    unit: 'đ',
                    icon: Icons.savings_rounded,
                    color: _kGold,
                  ),
                  const SizedBox(width: 10),
                  _KpiCard(
                    label: 'Đơn hàng',
                    value: '${stats.todayOrders}',
                    unit: 'đơn',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF64B5F6),
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

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1 — DOANH THU (7 ngày)
// ─────────────────────────────────────────────────────────────────────────────
class _RevenueTab extends StatelessWidget {
  final AsyncValue<List<DailyRevenue>> last7Async;
  final AsyncValue<DashboardStats> statsAsync;

  const _RevenueTab({required this.last7Async, required this.statsAsync});

  @override
  Widget build(BuildContext context) {
    return last7Async.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (days) {
        final stats = statsAsync.value ?? const DashboardStats(
          todayRevenue: 0, todayOrders: 0, todayCustomers: 0, avgOrderValue: 0);

        // Tính max để scale bar chart
        final maxRevenue = days.fold<double>(
            1, (m, d) => d.revenue > m ? d.revenue : m);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            // ── Bar Chart ──────────────────────────────────────────
            _SectionTitle(
              icon: Icons.bar_chart_rounded,
              title: 'Doanh thu 7 ngày qua',
              color: _kNavy,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8, offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                children: [
                  // Chart area
                  SizedBox(
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: days.asMap().entries.map((e) {
                        final d      = e.value;
                        final isToday = e.key == days.length - 1;
                        final ratio  = maxRevenue > 0
                            ? d.revenue / maxRevenue : 0.0;
                        final barH   = 130 * ratio;

                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (d.revenue > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Text(
                                      _fmtShort(d.revenue),
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: isToday ? _kOrange : _kMuted,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                AnimatedContainer(
                                  duration: Duration(
                                      milliseconds: 400 + e.key * 60),
                                  curve: Curves.easeOutCubic,
                                  height: barH.clamp(4, 130),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isToday
                                          ? [_kOrange.withValues(alpha: 0.7), _kOrange]
                                          : [_kNavy.withValues(alpha: 0.3), _kNavy.withValues(alpha: 0.6)],
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // X-axis labels
                  Row(
                    children: days.asMap().entries.map((e) {
                      final d      = e.value;
                      final isToday = e.key == days.length - 1;
                      return Expanded(
                        child: Text(
                          isToday ? 'Hôm nay' : _dayLabel(d.date),
                          style: TextStyle(
                            fontSize: 9,
                            color: isToday ? _kOrange : _kMuted,
                            fontWeight: isToday
                                ? FontWeight.w700 : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Summary row ────────────────────────────────────────
            _SectionTitle(
              icon: Icons.summarize_rounded,
              title: 'Tóm tắt hôm nay',
              color: _kNavy,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MiniCard(
                  label: 'Doanh thu', icon: Icons.payments_rounded,
                  value: '${_fmtShort(stats.todayRevenue)}đ',
                  color: _kGreen,
                )),
                const SizedBox(width: 10),
                Expanded(child: _MiniCard(
                  label: 'Số đơn', icon: Icons.receipt_long_rounded,
                  value: '${stats.todayOrders}',
                  color: _kNavy,
                )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _MiniCard(
                  label: 'Khách', icon: Icons.people_rounded,
                  value: '${stats.todayCustomers}',
                  color: const Color(0xFF7B1FA2),
                )),
                const SizedBox(width: 10),
                Expanded(child: _MiniCard(
                  label: 'TB/đơn', icon: Icons.trending_up_rounded,
                  value: '${_fmtShort(stats.avgOrderValue)}đ',
                  color: _kOrange,
                )),
              ],
            ),

            const SizedBox(height: 20),

            // ── 7-day summary table ────────────────────────────────
            _SectionTitle(
              icon: Icons.table_chart_rounded,
              title: 'Chi tiết 7 ngày',
              color: _kNavy,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: days.reversed.toList().asMap().entries.map((e) {
                  final d      = e.value;
                  final isLast = e.key == days.length - 1;
                  final isToday = d.date.day == DateTime.now().day &&
                      d.date.month == DateTime.now().month;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? _kOrange.withValues(alpha: 0.1)
                                    : _kBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  '${d.date.day}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: isToday ? _kOrange : _kMuted,
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
                                    isToday ? 'Hôm nay'
                                        : DateFormat('EEEE', 'vi_VN')
                                            .format(d.date),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isToday ? _kOrange : _kInk,
                                    ),
                                  ),
                                  Text('${d.orders} đơn',
                                    style: const TextStyle(
                                      fontSize: 11, color: _kMuted)),
                                ],
                              ),
                            ),
                            Text(
                              d.revenue > 0
                                  ? '${_fmtShort(d.revenue)}đ'
                                  : '—',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: d.revenue > 0 ? _kInk : _kMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, color: _kBorder),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  String _dayLabel(DateTime d) => DateFormat('E', 'vi').format(d);
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2 — SẢN PHẨM BÁN CHẠY
// ─────────────────────────────────────────────────────────────────────────────
class _ProductTab extends StatelessWidget {
  final AsyncValue<List<TopProduct>> topProductsAsync;
  const _ProductTab({required this.topProductsAsync});

  @override
  Widget build(BuildContext context) {
    return topProductsAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (products) {
        if (products.isEmpty) {
          return _EmptyState(
            icon: Icons.inventory_2_rounded,
            message: 'Chưa có đơn hàng nào hôm nay',
          );
        }

        final maxQty = products.fold<double>(
            1, (m, p) => p.totalQty > m ? p.totalQty : m);

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: [
            _SectionTitle(
              icon: Icons.emoji_events_rounded,
              title: 'Top sản phẩm hôm nay',
              color: _kOrange,
            ),
            const SizedBox(height: 12),

            ...products.asMap().entries.map((e) {
              final p    = e.value;
              final rank = e.key + 1;
              final bar  = maxQty > 0 ? p.totalQty / maxQty : 0.0;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: rank == 1
                        ? _kGold.withValues(alpha: 0.5) : _kBorder),
                  boxShadow: rank == 1
                      ? [BoxShadow(
                          color: _kGold.withValues(alpha: 0.1),
                          blurRadius: 8, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Rank badge
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: rank == 1
                                ? _kGold
                                : rank == 2
                                    ? Colors.grey.shade400
                                    : rank == 3
                                        ? const Color(0xFFCD7F32)
                                        : _kBg,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              rank <= 3 ? ['🥇','🥈','🥉'][rank-1] : '$rank',
                              style: TextStyle(
                                fontSize: rank <= 3 ? 16 : 14,
                                fontWeight: FontWeight.w900,
                                color: rank > 3 ? _kMuted : Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.productName,
                                style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: _kInk)),
                              Text(
                                '${p.totalQty.toStringAsFixed(0)} phần bán',
                                style: const TextStyle(
                                  fontSize: 11, color: _kMuted)),
                            ],
                          ),
                        ),
                        Text('${_fmtShort(p.totalRevenue)}đ',
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800,
                            color: _kInk)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Horizontal bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: bar,
                        minHeight: 6,
                        backgroundColor: _kBg,
                        valueColor: AlwaysStoppedAnimation(
                          rank == 1 ? _kGold
                              : rank == 2 ? _kNavy
                              : rank == 3 ? _kOrange
                              : _kMuted.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate(delay: (e.key * 50).ms)
                  .fadeIn(duration: 200.ms)
                  .slideX(begin: 0.05, end: 0, duration: 200.ms);
            }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 3 — TÀI CHÍNH (thu chi tổng hợp)
// ─────────────────────────────────────────────────────────────────────────────
class _FinanceTab extends StatelessWidget {
  final AsyncValue<FinanceStats> financeStats;
  const _FinanceTab({required this.financeStats});

  @override
  Widget build(BuildContext context) {
    return financeStats.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (stats) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        children: [
          // ── Profit card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: stats.profit >= 0
                    ? [const Color(0xFF1B5E20), const Color(0xFF2E7D32)]
                    : [const Color(0xFFB71C1C), const Color(0xFFC62828)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      stats.profit >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    const Text('LỢI NHUẬN',
                      style: TextStyle(
                        color: Colors.white70, fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 1.5)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${stats.profit >= 0 ? '+' : ''}${_fmtShort(stats.profit)}đ',
                  style: const TextStyle(
                    color: Colors.white, fontSize: 36,
                    fontWeight: FontWeight.w900, letterSpacing: -1.5)),
                const SizedBox(height: 4),
                Text(
                  'Biên lợi nhuận: ${stats.income > 0 ? (stats.profit / stats.income * 100).toStringAsFixed(1) : 0}%',
                  style: const TextStyle(
                    color: Colors.white60, fontSize: 13)),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 16),

          // ── Income vs Expense ─────────────────────────────────────
          _SectionTitle(
            icon: Icons.compare_arrows_rounded,
            title: 'Thu — Chi',
            color: _kNavy,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _FinanceTile(
                label: 'Thu nhập',
                value: stats.income,
                icon: Icons.arrow_downward_rounded,
                color: _kGreen,
              )),
              const SizedBox(width: 10),
              Expanded(child: _FinanceTile(
                label: 'Chi phí',
                value: stats.expense,
                icon: Icons.arrow_upward_rounded,
                color: _kRed,
              )),
            ],
          ),

          const SizedBox(height: 20),

          // ── Chi phí breakdown ─────────────────────────────────────
          if (stats.expenseByCategory.isNotEmpty) ...[
            _SectionTitle(
              icon: Icons.pie_chart_rounded,
              title: 'Phân tích chi phí',
              color: _kRed,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                children: stats.expenseByCategory.entries
                    .toList()
                    .asMap().entries.map((e) {
                  final isLast = e.key == stats.expenseByCategory.length - 1;
                  final cat    = e.value.key;
                  final amt    = e.value.value;
                  final pct    = stats.expense > 0
                      ? amt / stats.expense : 0.0;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(cat,
                                    style: const TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w600,
                                      color: _kInk))),
                                Text('${_fmtShort(amt)}đ',
                                  style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w800,
                                    color: _kRed)),
                                const SizedBox(width: 8),
                                Text('${(pct * 100).toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    fontSize: 11, color: _kMuted)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 5,
                                backgroundColor: _kBg,
                                valueColor: const AlwaysStoppedAnimation(_kRed),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast) const Divider(height: 1, color: _kBorder),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // ── Growth note ───────────────────────────────────────────
          if (stats.incomeGrowth != 0)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: stats.incomeGrowth > 0
                    ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: stats.incomeGrowth > 0
                      ? const Color(0xFFA5D6A7) : const Color(0xFFEF9A9A)),
              ),
              child: Row(
                children: [
                  Icon(
                    stats.incomeGrowth > 0
                        ? Icons.arrow_circle_up_rounded
                        : Icons.arrow_circle_down_rounded,
                    color: stats.incomeGrowth > 0 ? _kGreen : _kRed,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      stats.incomeGrowth > 0
                          ? 'Tăng ${stats.incomeGrowth.toStringAsFixed(1)}% so với kỳ trước 🎉'
                          : 'Giảm ${stats.incomeGrowth.abs().toStringAsFixed(1)}% so với kỳ trước',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: stats.incomeGrowth > 0 ? _kGreen : _kRed),
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

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS & WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  final String label, value, unit;
  final IconData icon;
  final Color color;
  final double? growth;

  const _KpiCard({
    required this.label, required this.value, required this.unit,
    required this.icon, required this.color, this.growth,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              if (growth != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: growth! >= 0
                        ? const Color(0xFF4CAF50).withValues(alpha: 0.2)
                        : const Color(0xFFE53935).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${growth! >= 0 ? '+' : ''}${growth!.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: growth! >= 0
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFE53935)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
            style: const TextStyle(
              color: Colors.white, fontSize: 18,
              fontWeight: FontWeight.w900, letterSpacing: -1,
              height: 1)),
          Text(unit,
            style: const TextStyle(
              color: Colors.white54, fontSize: 10)),
          const SizedBox(height: 2),
          Text(label,
            style: const TextStyle(
              color: Colors.white60, fontSize: 10,
              fontWeight: FontWeight.w500)),
        ],
      ),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionTitle({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w800,
        color: color, letterSpacing: -0.2)),
    ],
  );
}

class _MiniCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MiniCard({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kBorder),
    ),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w900,
              color: _kInk, letterSpacing: -0.5)),
            Text(label, style: const TextStyle(
              fontSize: 11, color: _kMuted)),
          ],
        ),
      ],
    ),
  );
}

class _FinanceTile extends StatelessWidget {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  const _FinanceTile({required this.label, required this.value,
    required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text('${_fmtShort(value)}đ',
          style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w900,
            color: color, letterSpacing: -1)),
        Text(label, style: const TextStyle(
          fontSize: 12, color: _kMuted,
          fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 72, color: _kMuted.withValues(alpha: 0.25)),
        const SizedBox(height: 16),
        Text(message, textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,fontWeight: FontWeight.w600, color: _kMuted)),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// FORMAT
// ─────────────────────────────────────────────────────────────────────────────
String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}
String _fmtShort(double v) => _fmt(v);
