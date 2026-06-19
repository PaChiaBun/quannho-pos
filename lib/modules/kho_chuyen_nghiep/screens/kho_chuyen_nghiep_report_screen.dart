import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';
import '../repository/kho_chuyen_nghiep_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KHO PRO REPORT SCREEN — Báo cáo food cost, tiêu thụ, lãi gộp
// ─────────────────────────────────────────────────────────────────────────────

class KhoProReportScreen extends ConsumerStatefulWidget {
  const KhoProReportScreen({super.key});

  @override
  ConsumerState<KhoProReportScreen> createState() => _KhoProReportScreenState();
}

class _KhoProReportScreenState extends ConsumerState<KhoProReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTime _from = DateTime.now().subtract(const Duration(days: 7));
  DateTime _to   = DateTime.now();
  int? _quickRange = 7; // null = custom

  static const _tabs = ['Food Cost', 'Tiêu thụ', 'Sản lượng'];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KhoTheme.bg,
      body: Column(children: [
        // ── Date range selector ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          color: KhoTheme.bg,
          child: Row(children: [
            _DateChip(label: 'Từ', date: _from,
                onTap: () => _pickDate(true)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('→', style: TextStyle(color: KhoTheme.muted)),
            ),
            _DateChip(label: 'Đến', date: _to,
                onTap: () => _pickDate(false)),
            const SizedBox(width: 8),
            _QuickChip('7 ngày', 7, () => setState(() {
              _quickRange = 7;
              _from = DateTime.now().subtract(const Duration(days: 7));
              _to   = DateTime.now();
            })),
            const SizedBox(width: 4),
            _QuickChip('30 ngày', 30, () => setState(() {
              _quickRange = 30;
              _from = DateTime.now().subtract(const Duration(days: 30));
              _to   = DateTime.now();
            })),
          ]),
        ),
        // ── Tabs ──────────────────────────────────────────────────────────
        Container(
          color: KhoTheme.bg,
          child: TabBar(
            controller: _tabCtrl,
            labelColor: KhoTheme.violet,
            unselectedLabelColor: KhoTheme.muted,
            indicatorColor: KhoTheme.violet,
            indicatorWeight: 2.5,
            tabs: _tabs.map((t) => Tab(
                child: Text(t, style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w700)))).toList(),
          ),
        ),
        // ── Tab views ─────────────────────────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _FoodCostTab(from: _from, to: _to),
              _ConsumptionTab(from: _from, to: _to),
              _ProductionTab(from: _from, to: _to),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _pickDate(bool isFrom) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() {
      if (isFrom) _from = picked;
      else        _to   = picked;
      _quickRange = null; // custom range
    });
  }

  Widget _QuickChip(String label, int days, VoidCallback onTap) {
    final isSelected = _quickRange == days;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? KhoTheme.violet : KhoTheme.violet.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? KhoTheme.violet : KhoTheme.violet.withOpacity(0.25),
          ),
        ),
        child: Text(label, style: GoogleFonts.outfit(
            fontSize: 11.5, fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : KhoTheme.violet)),
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;
  const _DateChip({required this.label, required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: KhoTheme.card, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: KhoTheme.border)),
      child: Text('$label ${date.day}/${date.month}',
          style: GoogleFonts.outfit(fontSize: 12.5, fontWeight: FontWeight.w700,
              color: KhoTheme.navy)),
    ),
  );
}

// ── FOOD COST TAB ─────────────────────────────────────────────────────────────
class _FoodCostTab extends ConsumerWidget {
  final DateTime from;
  final DateTime to;
  const _FoodCostTab({required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<Map<String, double>>(
      key: ValueKey('foodcost-${from.toIso8601String()}-${to.toIso8601String()}'),
      future: ref.read(khoProRepositoryProvider).getFoodCostByDate(from: from, to: to),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final data   = snap.data ?? {};
        final total  = data.values.fold(0.0, (s, v) => s + v);
        final days   = data.length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [KhoTheme.navy, KhoTheme.navyLight]),
                borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
              ),
              child: Row(children: [
                Expanded(child: _StatItem(
                  label: 'Tổng giá vốn', value: fmtMoney(total))),
                Expanded(child: _StatItem(
                  label: 'TB/ngày',
                  value: days > 0 ? fmtMoney(total / days) : '—')),
              ]),
            ),
            const SizedBox(height: 16),
            // Daily breakdown
            Text('Chi phí theo ngày', style: GoogleFonts.outfit(
                fontSize: 13, fontWeight: FontWeight.w800, color: KhoTheme.navy)),
            const SizedBox(height: 8),
            if (data.isEmpty)
              _EmptyReport(label: 'Chưa có dữ liệu sản xuất trong kỳ này')
            else
              ...data.entries.map((e) => _DayCostRow(date: e.key, cost: e.value)),
          ],
        );
      },
    );
  }
}

// ── CONSUMPTION TAB ───────────────────────────────────────────────────────────
class _ConsumptionTab extends ConsumerWidget {
  final DateTime from;
  final DateTime to;
  const _ConsumptionTab({required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey('consumption-${from.toIso8601String()}-${to.toIso8601String()}'),
      future: ref.read(khoProRepositoryProvider)
          .getIngredientConsumption(from: from, to: to),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return Center(child: _EmptyReport(
              label: 'Chưa có tiêu thụ trong kỳ này'));
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final item = items[i];
            return Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: KhoTheme.card,
                borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
                border: Border.all(color: KhoTheme.border),
                boxShadow: KhoTheme.subtleShadow,
              ),
              child: Row(children: [
                Text('${i + 1}', style: GoogleFonts.outfit(
                    fontSize: 13, color: KhoTheme.muted, fontWeight: FontWeight.w700)),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['ingredient_name'] as String? ?? '—',
                          style: GoogleFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: KhoTheme.ink)),
                      Text('${(item['total_qty'] as double).toStringAsFixed(1)} ${item['unit']}',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: KhoTheme.muted)),
                    ])),
                Text(fmtMoney(item['total_cost'] as double),
                    style: GoogleFonts.outfit(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: KhoTheme.violet)),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── PRODUCTION TAB ────────────────────────────────────────────────────────────
class _ProductionTab extends ConsumerWidget {
  final DateTime from;
  final DateTime to;
  const _ProductionTab({required this.from, required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<ProductionOrderModel>>(
      key: ValueKey('production-${from.toIso8601String()}-${to.toIso8601String()}'),
      future: ref.read(khoProRepositoryProvider)
          // ‼️ FIX: cộng 1 ngày vì repository dùng lt (exclusive)
          // to = DateTime.now() → lt('2026-05-10') → bỏ sót lệnh hôm nay
          .fetchProductionOrders(from: from, to: to.add(const Duration(days: 1))),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final orders = snap.data ?? [];

        if (orders.isEmpty) {
          return Center(child: _EmptyReport(
              label: 'Chưa có lệnh sản xuất trong kỳ này'));
        }

        final done       = orders.where((o) => o.status == 'done').length;
        final inProgress = orders.where((o) => o.status == 'in_progress').length;
        final pending    = orders.where((o) => o.status == 'pending').length;
        final cancelled  = orders.where((o) => o.status == 'cancelled').length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // KPI row 1
            Row(children: [
              Expanded(child: _KpiMini(
                  label: 'Tổng lệnh', value: '${orders.length}',
                  color: KhoTheme.navy)),
              const SizedBox(width: 8),
              Expanded(child: _KpiMini(
                  label: 'Hoàn thành', value: '$done',
                  color: KhoTheme.green)),
            ]),
            const SizedBox(height: 8),
            // KPI row 2
            Row(children: [
              Expanded(child: _KpiMini(
                  label: 'Đang làm', value: '$inProgress',
                  color: KhoTheme.violet)),
              const SizedBox(width: 8),
              Expanded(child: _KpiMini(
                  label: 'Chờ', value: '$pending',
                  color: KhoTheme.amber)),
              const SizedBox(width: 8),
              Expanded(child: _KpiMini(
                  label: 'Đã hủy', value: '$cancelled',
                  color: KhoTheme.muted)),
            ]),
            const SizedBox(height: 16),
            ...orders.map((o) {
              final statusColor = o.status == 'done'        ? KhoTheme.green
                                : o.status == 'in_progress' ? KhoTheme.violet
                                : o.status == 'cancelled'   ? KhoTheme.muted
                                : KhoTheme.amber;
              final statusLabel = o.status == 'done'        ? 'Hoàn thành'
                                : o.status == 'in_progress' ? 'Đang làm'
                                : o.status == 'cancelled'   ? 'Đã hủy'
                                : 'Chờ';
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: KhoTheme.card,
                  borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
                  border: Border.all(color: KhoTheme.border),
                ),
                child: Row(children: [
                  Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.recipeName, style: GoogleFonts.outfit(
                            fontSize: 13, fontWeight: FontWeight.w800,
                            color: o.status == 'cancelled' ? KhoTheme.muted : KhoTheme.ink,
                            decoration: o.status == 'cancelled' ? TextDecoration.lineThrough : null)),
                        Text('${o.quantity.toStringAsFixed(0)} phần  ·  ${o.scheduledDate}',
                            style: GoogleFonts.outfit(fontSize: 11, color: KhoTheme.muted)),
                      ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(statusLabel,
                        style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.w700,
                            color: statusColor)),
                  ),
                ]),
              );
            }),
          ],
        );
      },
    );
  }
}

// ── HELPERS ───────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String label, value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: GoogleFonts.outfit(
          fontSize: 11, color: Colors.white60, fontWeight: FontWeight.w600)),
      Text(value, style: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
    ],
  );
}

class _DayCostRow extends StatelessWidget {
  final String date;
  final double cost;
  const _DayCostRow({required this.date, required this.cost});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: KhoTheme.card, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: KhoTheme.border)),
    child: Row(children: [
      Text(date, style: GoogleFonts.outfit(
          fontSize: 13, color: KhoTheme.muted)),
      const Spacer(),
      Text(fmtMoney(cost), style: GoogleFonts.outfit(
          fontSize: 14, fontWeight: FontWeight.w800, color: KhoTheme.violet)),
    ]),
  );
}

class _KpiMini extends StatelessWidget {
  final String label, value;
  final Color color;
  const _KpiMini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withOpacity(0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.2)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.outfit(fontSize: 11, color: color)),
      Text(value, style: GoogleFonts.outfit(
          fontSize: 22, fontWeight: FontWeight.w900, color: color)),
    ]),
  );
}

class _EmptyReport extends StatelessWidget {
  final String label;
  const _EmptyReport({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.bar_chart_rounded, size: 56, color: KhoTheme.muted.withOpacity(0.4)),
      const SizedBox(height: 12),
      Text(label, style: GoogleFonts.outfit(
          fontSize: 14, color: KhoTheme.muted, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center),
    ]),
  );
}
