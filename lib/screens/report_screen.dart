import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/providers/app_providers.dart';
import '../core/providers/dashboard_providers.dart';
import '../core/repositories/dashboard_repository.dart';
import '../core/services/store_auth_service.dart';
import '../modules/finance/providers/finance_providers.dart';
import '../modules/finance/repository/finance_repository.dart';

// ─── Design Tokens (nhất quán với toàn app) ───────────────────────────────────
const _kNavy   = Color(0xFF1C2151);  // Đồng bộ với toàn app
const _kNavyL  = Color(0xFF2A3A8F);  // Navy nhạt hơn (gradient)
const _kOrange = Color(0xFFFF6B35);  // Accent cam
const _kGreen  = Color(0xFF2E7D32);  // Thu nhập
const _kRed    = Color(0xFFC62828);  // Chi phí
const _kGold   = Color(0xFFF9A825);  // Lợi nhuận
const _kInk    = Color(0xFF1A1207);  // Text chính
const _kMuted  = Color(0xFF9E9085);  // Text phụ
const _kBg     = Color(0xFFFFF8F0);  // Nền app — đồng bộ Cream
const _kCard   = Color(0xFFFFFFFF);  // Nền card
const _kBorder = Color(0xFFE8E2DA);  // Viền nhẹ

// ─── Period Enum ──────────────────────────────────────────────────────────────
enum ReportPeriod { today, week, month }
extension ReportPeriodX on ReportPeriod {
  String get label => switch (this) {
    ReportPeriod.today => 'Hôm nay',
    ReportPeriod.week  => 'Tuần này',
    ReportPeriod.month => 'Tháng này',
  };

  // Dynamic range — dùng weekStart / navYear+navMonth khi được truyền vào
  (int, int) rangeFor({DateTime? weekStart, int? navYear, int? navMonth}) {
    final now = DateTime.now();
    switch (this) {
      case ReportPeriod.today:
        // ‼️ FIX: dùng midnight ngày kế (exclusive) thay vì 23:59:59 (bỏ sót 59.001–999ms)
        final start   = DateTime(now.year, now.month, now.day);
        final endExcl = DateTime(now.year, now.month, now.day + 1);
        return (start.millisecondsSinceEpoch, endExcl.millisecondsSinceEpoch);
      case ReportPeriod.week:
        final mon    = weekStart ?? now.subtract(Duration(days: now.weekday - 1));
        final monDay = DateTime(mon.year, mon.month, mon.day);
        // ‼️ FIX: capEnd dùng midnight ngày kế thay vì DateTime.now() (mid-day boundary)
        final endDay = monDay.add(const Duration(days: 7)); // midnight tuần kế (exclusive)
        final capEnd = endDay.isAfter(DateTime(now.year, now.month, now.day + 1))
            ? DateTime(now.year, now.month, now.day + 1)
            : endDay;
        return (monDay.millisecondsSinceEpoch, capEnd.millisecondsSinceEpoch);
      case ReportPeriod.month:
        final y     = navYear  ?? now.year;
        final m     = navMonth ?? now.month;
        final start = DateTime(y, m, 1);
        // ‼️ FIX: midnight ngày 1 tháng kế (exclusive) thay vì (y, m+1, 0, 23:59:59)
        final endExcl   = DateTime(y, m + 1, 1);
        final capEnd    = endExcl.isAfter(DateTime(now.year, now.month, now.day + 1))
            ? DateTime(now.year, now.month, now.day + 1)
            : endExcl;
        return (start.millisecondsSinceEpoch, capEnd.millisecondsSinceEpoch);
    }
  }

  // Compat getter (tuần/tháng hiện tại)
  (int, int) get range => rangeFor();
}

// ═══════════════════════════════════════════════════════════════════════════════
// REPORT SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});
  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() { super.initState(); _tab = TabController(length: 5, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final todayStats = ref.watch(todayStatsProvider);
    final todayFin   = ref.watch(todayFinanceStatsProvider);
    final monthRev   = ref.watch(_monthRevProvider);

    final mainContent = Column(children: [
      _buildHeader(todayStats, todayFin, monthRev),
      Expanded(child: TabBarView(controller: _tab, children: const [
        _RevenueTab(), _ProductTab(), _FinanceTab(), _KhoTab(), _VoidAuditTab(),
      ])),
    ]);

    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(children: [
                  Expanded(flex: 3, child: mainContent),
                  SizedBox(
                    width: 280,
                    child: _ReportRightPanel(
                      todayStats: todayStats,
                      todayFin: todayFin,
                      monthRev: monthRev,
                    ),
                  ),
                ]),
              ),
            );
          }
          return mainContent;
        },
      ),
    );
  }

  Widget _buildHeader(
    AsyncValue<DashboardStats> sA,
    AsyncValue<FinanceStats> fA,
    AsyncValue<double> mA,
  ) {
    final s    = sA.value ?? DashboardStats.empty;
    final f    = fA.value ?? FinanceStats.empty;
    final mRev = mA.value ?? 0.0;
    final now  = DateTime.now();
    final dayStr = DateFormat('EEEE, dd/MM', 'vi').format(now);
    final isLoading = sA is AsyncLoading || fA is AsyncLoading || mA is AsyncLoading;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavy, _kNavyL],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(bottom: false, child: Column(children: [

        // ── AppBar ──────────────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(20, 12, 4, 0), child: Row(
          children: [
            const Text('Báo cáo',
              style: TextStyle(color: Colors.white, fontSize: 20,
                fontWeight: FontWeight.w900, letterSpacing: -0.3)),
            const SizedBox(width: 8),
            Text(dayStr,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45),
                fontSize: 12, fontWeight: FontWeight.w500)),
            const Spacer(),
            IconButton(
              icon: Icon(
                isLoading ? Icons.hourglass_empty_rounded : Icons.refresh_rounded,
                color: Colors.white54, size: 20),
              onPressed: () {
                ref.invalidate(todayStatsProvider);
                ref.invalidate(todayFinanceStatsProvider);
                ref.invalidate(_monthRevProvider);
              },
            ),
          ],
        )),

        // ── 2 Hero cards ────────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 0), child: Row(
          children: [
            _HeroCard(
              label: 'Hôm nay',
              value: _fmtShort(s.todayRevenue),
              sub: '${s.todayOrders} đơn',
              accent: _kOrange,
              isHighlight: true,
            ),
            const SizedBox(width: 10),
            _HeroCard(
              label: 'Tháng ${now.month}',
              value: _fmtShort(mRev),
              sub: 'lũy kế',
              accent: const Color(0xFF69F0AE),
              isHighlight: false,
            ),
          ],
        )),

        // ── 3 stat pills ────────────────────────────────────────────────────
        Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 12), child: Row(
          children: [
            _SmallStat(label: 'Chi phí',   value: _fmtShort(f.expense),      color: const Color(0xFFFF6B6B)),
            _vDivider(),
            _SmallStat(label: 'Lợi nhuận', value: _fmtShort(f.profit),       color: const Color(0xFF69F0AE)),
            _vDivider(),
            _SmallStat(label: 'TB/đơn',    value: _fmtShort(s.avgOrderValue), color: const Color(0xFFFFD54F)),
          ],
        )),

        // ── TabBar ──────────────────────────────────────────────────────────
        TabBar(
          controller: _tab,
          indicatorColor: _kOrange, indicatorWeight: 3,
          labelColor: Colors.white, unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          tabs: const [
            Tab(text: 'Doanh thu'),
            Tab(text: 'Sản phẩm'),
            Tab(text: 'Tài chính'),
            Tab(text: 'Kho'),
            Tab(text: 'Huỷ/Duyệt'),
          ]),
      ])),
    );
  }
}

// ── Month revenue provider ─────────────────────────────────────────────────────
final _monthRevProvider = FutureProvider.autoDispose<double>((ref) async {
  final repo = ref.read(dashboardRepositoryProvider);
  final now  = DateTime.now();
  final from = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
  final to   = DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch;
  final stats = await repo.getStatsForRange(from, to);
  return stats.todayRevenue; // getStatsForRange trả về tổng trong khoảng
});

// ── _HeroCard ──────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  final String label, value, sub;
  final Color accent;
  final bool isHighlight;
  const _HeroCard({required this.label, required this.value, required this.sub,
      required this.accent, required this.isHighlight});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        // Cùng 1 màu kem nhạt cho cả 2 card
        color: const Color(0xFFFFF8F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD4), width: 1),
        boxShadow: [
          BoxShadow(
            color: _kNavy.withValues(alpha: 0.13),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: _kNavy.withValues(alpha: 0.50),
            fontSize: 11, fontWeight: FontWeight.w600,
          )),
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(
            color: _kNavy.withValues(alpha: 0.88),
            fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5,
          )),
        ),
        const SizedBox(height: 5),
        Text(sub, style: TextStyle(
          color: _kNavy.withValues(alpha: 0.40),
          fontSize: 10, fontWeight: FontWeight.w600,
        )),
      ]),
    ),
  );
}

// ── Small stat widget ───────────────────────────────────────────────────────
class _SmallStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SmallStat({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.50),
          fontSize: 10, fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      Text(value, style: TextStyle(color: color, fontSize: 15,
          fontWeight: FontWeight.w900, letterSpacing: -0.3)),
    ]),
  );
}

Widget _vDivider() => Container(
  width: 1, height: 28,
  margin: const EdgeInsets.symmetric(horizontal: 4),
  color: Colors.white.withValues(alpha: 0.12),
);


// ─── Period Chips (pill style) ────────────────────────────────────────────────
class _PeriodPills extends StatelessWidget {
  final ReportPeriod current; final ValueChanged<ReportPeriod> onChanged;
  const _PeriodPills({required this.current, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _kNavy.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12)),
    child: Row(children: ReportPeriod.values.map((p) => Expanded(
      child: GestureDetector(
        onTap: () => onChanged(p),
        child: AnimatedContainer(duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: current == p ? _kNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: current == p ? [BoxShadow(color: _kNavy.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))] : null),
          child: Text(p.label, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: current == p ? Colors.white : _kMuted))),
      ),
    )).toList()),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — DOANH THU
// ═══════════════════════════════════════════════════════════════════════════════
class _RevenueTab extends ConsumerStatefulWidget {
  const _RevenueTab();
  @override
  ConsumerState<_RevenueTab> createState() => _RevenueTabState();
}
class _RevenueTabState extends ConsumerState<_RevenueTab> {
  ReportPeriod       _period = ReportPeriod.today;
  DateTime _weekStart = _mondayOf(DateTime.now());
  int _navYear  = DateTime.now().year;
  int _navMonth = DateTime.now().month;
  DashboardStats     _stats  = DashboardStats.empty;
  List<DailyRevenue>  _days  = [];
  List<HourlyRevenue> _hours = [];
  bool _loading = true;
  int? _selectedBar;
  StreamSubscription<List<HourlyRevenue>>? _hourSub;

  static DateTime _mondayOf(DateTime d) {
    final m = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _hourSub?.cancel(); super.dispose(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _selectedBar = null; });
    await _hourSub?.cancel();
    _hourSub = null;
    final repo = ref.read(dashboardRepositoryProvider);
    final (from, to) = _period.rangeFor(weekStart: _weekStart, navYear: _navYear, navMonth: _navMonth);
    final stats = await repo.getStatsForRange(from, to);
    if (!mounted) return;
    if (_period == ReportPeriod.today) {
      setState(() { _stats = stats; _days = []; });
      _hourSub = repo.watchHourlyRevenue(DateTime.now()).listen((h) {
        if (mounted) setState(() { _hours = h; _loading = false; });
      });
    } else {
      final d = await repo.getDailyRevenue(from, to);
      if (mounted) setState(() { _stats = stats; _days = d; _hours = []; _loading = false; });
    }
  }

  Future<void> _printReport(BuildContext context) async {
    final nowStr = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
    final moneyFormatter = NumberFormat('#,###', 'vi_VN');
    String formatVnd(double v) => '${moneyFormatter.format(v)} đ';

    final String titleStr;
    if (_period == ReportPeriod.week) {
      titleStr = 'BÁO CÁO DOANH THU TUẦN';
    } else if (_period == ReportPeriod.month) {
      titleStr = 'BÁO CÁO DOANH THU THÁNG';
    } else {
      titleStr = 'BÁO CÁO DOANH THU CA';
    }

    try {
      final doc = pw.Document();
      
      // Load Google fonts that support Vietnamese characters
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.roll80, // Định dạng cuộn nhiệt 80mm
          margin: const pw.EdgeInsets.all(10),
          build: (pw.Context ctx) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(titleStr, style: pw.TextStyle(font: fontBold, fontSize: 13, fontWeight: pw.FontWeight.bold)),
                ),
                pw.Center(
                  child: pw.Text('Kỳ báo cáo: ${_period.label}', style: pw.TextStyle(font: font, fontSize: 9)),
                ),
                pw.Center(
                  child: pw.Text('Giờ in: $nowStr', style: pw.TextStyle(font: font, fontSize: 8)),
                ),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                
                // Tóm tắt
                pw.Text('TÓM TẮT DOANH THU', style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Doanh thu:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(formatVnd(_stats.todayRevenue), style: pw.TextStyle(font: fontBold, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Số đơn:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text('${_stats.todayOrders} đơn', style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TB/đơn:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(formatVnd(_stats.avgOrderValue), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Lượng khách:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text('${_stats.todayCustomers}', style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // Phương thức thanh toán
                pw.Text('PHƯƠNG THỨC THANH TOÁN', style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Tiền mặt:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(formatVnd(_stats.cashRevenue), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Chuyển khoản:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(formatVnd(_stats.transferRevenue), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Thẻ ngân hàng:', style: pw.TextStyle(font: font, fontSize: 9)),
                    pw.Text(formatVnd(_stats.cardRevenue), style: pw.TextStyle(font: font, fontSize: 9)),
                  ],
                ),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),

                // Nhân viên thu ngân
                pw.Text('DOANH THU THEO THU NGÂN', style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                if (_stats.cashierRevenue.isEmpty)
                  pw.Text('Chưa có thông tin nhân viên', style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey))
                else
                  ..._stats.cashierRevenue.entries.map((e) {
                    final detail = _stats.cashierDetails[e.key];
                    return pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('${e.key}:', style: pw.TextStyle(font: font, fontSize: 9)),
                            pw.Text(formatVnd(e.value), style: pw.TextStyle(font: fontBold, fontSize: 9)),
                          ],
                        ),
                        if (detail != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 8),
                            child: pw.Text('Tiền mặt: ${formatVnd(detail.cash)} | CK: ${formatVnd(detail.transfer)}', 
                                style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey700)),
                          ),
                          pw.SizedBox(height: 4),
                        ],
                      ],
                    );
                  }),

                // Chi tiết các ngày (nếu là Tuần/Tháng)
                if (_period != ReportPeriod.today && _days.isNotEmpty) ...[
                  pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                  pw.Text('CHI TIẾT DOANH THU HÀNG NGÀY', style: pw.TextStyle(font: fontBold, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  ..._days.where((d) => d.revenue > 0).map((d) {
                    final dStr = DateFormat('dd/MM').format(d.date);
                    return pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('$dStr (${d.orders} đơn):', style: pw.TextStyle(font: font, fontSize: 9)),
                        pw.Text(formatVnd(d.revenue), style: pw.TextStyle(font: font, fontSize: 9)),
                      ],
                    );
                  }),
                ],
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                
                pw.Center(
                  child: pw.Text('Powered by Quan Nho POS', style: pw.TextStyle(font: font, fontSize: 7, color: PdfColors.grey)),
                ),
              ],
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Bao_cao_doanh_thu_${_period.label}',
      );
    } catch (e) {
      debugPrint('[PrintReport] Error generating PDF: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi in báo cáo: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 80), children: [
      Row(
        children: [
          Expanded(
            child: _PeriodPills(current: _period, onChanged: (p) { setState(() => _period = p); _load(); }),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            onPressed: () => _printReport(context),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('In báo cáo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      // ── Nav tuần / tháng
      if (_period == ReportPeriod.week) ...[
        const SizedBox(height: 8),
        _ReportNavBar.week(
          weekStart: _weekStart,
          canGoNext: _weekStart.add(const Duration(days: 7)).isBefore(
            DateTime.now().add(const Duration(days: 1))),
          onPrev: () { setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))); _load(); },
          onNext: () { setState(() => _weekStart = _weekStart.add(const Duration(days: 7))); _load(); },
          onPick: () => _pickWeek(context),
        ),
      ],
      if (_period == ReportPeriod.month) ...[
        const SizedBox(height: 8),
        _ReportNavBar.month(
          year: _navYear, month: _navMonth,
          canGoNext: !(_navYear == DateTime.now().year && _navMonth == DateTime.now().month),
          onPrev: () { setState(() { if (_navMonth == 1) { _navYear--; _navMonth = 12; } else { _navMonth--; } }); _load(); },
          onNext: () { setState(() { if (_navMonth == 12) { _navYear++; _navMonth = 1; } else { _navMonth++; } }); _load(); },
          onPick: () => _pickMonth(context),
        ),
      ],
      const SizedBox(height: 16),
      // ── Highlight tổng (Tuần/Tháng)
      if (_period != ReportPeriod.today && _stats.todayRevenue > 0)
        _buildTotalBanner(),
      if (_period != ReportPeriod.today && _stats.todayRevenue > 0)
        const SizedBox(height: 16),
      // ── Chart
      _SectionHeader(
        icon: Icons.bar_chart_rounded, color: _kNavy,
        title: _period == ReportPeriod.today ? 'Doanh thu theo giờ' : 'Doanh thu theo ngày'),
      const SizedBox(height: 12),
      if (_loading) const _LoadingCard() else _buildChart(),
      const SizedBox(height: 24),
      _SectionHeader(icon: Icons.summarize_rounded, color: _kNavy, title: 'Tóm tắt kỳ này'),
      const SizedBox(height: 12),
      _buildSummary(),
      _buildDailySalesTable(),
    ]);
  }

  Widget _buildDailySalesTable() {
    if (_period == ReportPeriod.today || _days.isEmpty) {
      return const SizedBox.shrink();
    }

    final moneyFormatter = NumberFormat('#,###', 'vi_VN');
    String formatVnd(double v) => v > 0 ? '${moneyFormatter.format(v)} đ' : '0đ';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        const _SectionHeader(icon: Icons.table_chart_rounded, color: _kNavy, title: 'Tổng hợp bán hàng theo ngày'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFFAF7F2)),
                dataRowMinHeight: 48,
                dataRowMaxHeight: 48,
                columnSpacing: 24,
                horizontalMargin: 16,
                columns: const [
                  DataColumn(label: Text('Ngày', style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy))),
                  DataColumn(label: Text('Số đơn', style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy)), numeric: true),
                  DataColumn(label: Text('Doanh thu', style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy)), numeric: true),
                  DataColumn(label: Text('Tiền mặt', style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy)), numeric: true),
                  DataColumn(label: Text('Chuyển khoản', style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy)), numeric: true),
                  DataColumn(label: Text('Khuyến mại', style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy)), numeric: true),
                ],
                rows: _days.map((d) {
                  final dateStr = DateFormat('dd/MM/yyyy').format(d.date);
                  return DataRow(
                    cells: [
                      DataCell(Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                      DataCell(Text('${d.orders}', style: const TextStyle(fontSize: 13))),
                      DataCell(Text(formatVnd(d.revenue), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _kNavy))),
                      DataCell(Text(formatVnd(d.cashRevenue), style: const TextStyle(fontSize: 13))),
                      DataCell(Text(formatVnd(d.transferRevenue), style: const TextStyle(fontSize: 13))),
                      DataCell(Text(formatVnd(d.discount), style: const TextStyle(fontSize: 13, color: Colors.red))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickWeek(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx, initialDate: _weekStart,
      firstDate: DateTime(now.year - 2), lastDate: now,
      helpText: 'Chọn tuần muốn xem',
      builder: (c, child) => Theme(data: Theme.of(c).copyWith(
        colorScheme: const ColorScheme.light(primary: _kNavy)), child: child!),
    );
    if (picked != null && mounted) { setState(() => _weekStart = _mondayOf(picked)); _load(); }
  }

  Future<void> _pickMonth(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx, initialDate: DateTime(_navYear, _navMonth),
      firstDate: DateTime(now.year - 2), lastDate: now,
      helpText: 'Chọn tháng muốn xem',
      builder: (c, child) => Theme(data: Theme.of(c).copyWith(
        colorScheme: const ColorScheme.light(primary: _kNavy)), child: child!),
    );
    if (picked != null && mounted) { setState(() { _navYear = picked.year; _navMonth = picked.month; }); _load(); }
  }

  Widget _buildTotalBanner() => Container(
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
        begin: Alignment.topLeft, end: Alignment.bottomRight),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20)),
      const SizedBox(width: 14),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Tổng doanh thu ${_period.label.toLowerCase()}',
          style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        Text(_fmtShort(_stats.todayRevenue),
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1)),
      ]),
      const Spacer(),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${_stats.todayOrders} đơn', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
        Text('TB ${_fmtShort(_stats.avgOrderValue)}/đơn', style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    ]),
  );

  // ── Smart Anchor: chỉ hiện nhãn X khi đủ khoảng cách ────────────────────
  bool _shouldShowLabel(int index, int total) {
    if (total <= 7) return true;                    // Tuần: hiện tất cả
    if (index == 0 || index == total - 1) return true; // Luôn hiện đầu + cuối
    if (index == _selectedBar) return true;         // Luôn hiện cột đang chọn
    final step = (total / 4).ceil();                // Chia đều ~5 nhãn
    return index % step == 0;
  }

  // ── Tính 5 mốc tiền đẹp cho trục Y ────────────────────────────────────────
  List<double> _computeMilestones(double maxV) {
    if (maxV <= 0) return [200000, 400000, 600000, 800000, 1000000];
    final rawStep = maxV / 5;
    final mag     = pow(10, (log(rawStep) / ln10).floor()).toDouble();
    final norm    = rawStep / mag;
    final nice    = norm < 1.5 ? 1.0 : norm < 3 ? 2.0 : norm < 7 ? 5.0 : 10.0;
    final step    = nice * mag;
    return List.generate(5, (i) => step * (i + 1));
  }

  Widget _buildChart() {
    // Chuẩn bị data bars kèm số đơn
    final List<({String label, double value, int orders})> bars;
    if (_period == ReportPeriod.today) {
      final nowH = DateTime.now().hour;
      bars = _hours
          .where((h) => h.hour <= nowH)
          .map((h) => (label: '${h.hour}h', value: h.revenue, orders: h.orders))
          .toList();
    } else if (_period == ReportPeriod.week) {
      bars = _days.map((d) => (
        label: DateFormat('E', 'vi').format(d.date),
        value: d.revenue, orders: d.orders)).toList();
    } else {
      bars = _days.map((d) => (
        label: DateFormat('dd/M').format(d.date),
        value: d.revenue, orders: d.orders)).toList();
    }

    final hasData = bars.any((b) => b.value > 0);
    if (!hasData) return _buildEmptyChart(bars.length);

    final maxV       = bars.fold<double>(1, (m, b) => b.value > m ? b.value : m);
    final milestones = _computeMilestones(maxV);
    final chartMax   = milestones.last;
    final chartH     = MediaQuery.of(context).size.width >= 750 ? 230.0 : 180.0;
    const yAxisW     = 44.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 16, 12, 10),
      decoration: BoxDecoration(
        color: _kCard, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]),
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          // ── Trục Y: 5 mốc tiền ──────────────────────────────────────────────
          SizedBox(
            width: yAxisW, height: chartH,
            child: Stack(
              children: milestones.asMap().entries.map((e) {
                final bottom = (e.value / chartMax * chartH).clamp(0.0, chartH - 10);
                return Positioned(
                  bottom: bottom - 6, right: 4,
                  child: Text(_fmtShort(e.value),
                    style: const TextStyle(fontSize: 9, color: _kMuted, fontWeight: FontWeight.w600)));
              }).toList(),
            ),
          ),
          // ── Bars ─────────────────────────────────────────────────────────────
          Expanded(
            child: SizedBox(
              height: chartH,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: bars.asMap().entries.map((e) {
                  final i        = e.key;
                  final bar      = e.value;
                  final sel      = _selectedBar == i;
                  final isLast   = i == bars.length - 1;
                  final barH     = (chartH * (bar.value / chartMax)).clamp(2.0, chartH);
                  final isEmpty  = bar.value == 0;
                  final double barWidth;
                  if (bars.length <= 7) {
                    barWidth = 36.0;
                  } else if (bars.length <= 15) {
                    barWidth = 24.0;
                  } else {
                    barWidth = 14.0;
                  }

                  return Expanded(
                    child: GestureDetector(
                      onTap: isEmpty ? null
                        : () => setState(() => _selectedBar = sel ? null : i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1.5),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          clipBehavior: Clip.none,
                          children: [
                            // Touch area đầy đủ chiều cao
                            Container(height: chartH, color: Colors.transparent),
                            // Cột bar
                            Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300 + i * 15),
                                curve: Curves.easeOutCubic,
                                width: barWidth,
                                height: isEmpty ? 2 : barH,
                                decoration: BoxDecoration(
                                  gradient: isEmpty ? null : LinearGradient(
                                    colors: sel
                                      ? [_kOrange.withValues(alpha: 0.5), _kOrange]
                                      : isLast
                                        ? [_kNavy.withValues(alpha: 0.35), _kNavy.withValues(alpha: 0.85)]
                                        : [_kNavy.withValues(alpha: 0.2), _kNavy.withValues(alpha: 0.65)],
                                    begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                  color: isEmpty ? _kBorder.withValues(alpha: 0.4) : null,
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(5)))),
                            ),
                            // Tooltip khi tap
                            if (sel && !isEmpty)
                              Positioned(
                                bottom: barH + 6,
                                child: _BarTooltip(
                                  label: bar.label,
                                  revenue: bar.value,
                                  orders: bar.orders)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        // ── Trục X: Smart Anchor labels ────────────────────────────────────────
        Row(children: [
          const SizedBox(width: yAxisW),
          ...bars.asMap().entries.map((e) {
            final i      = e.key;
            final total  = bars.length;
            final isSel  = _selectedBar == i;
            final isLast = i == total - 1;
            final show   = _shouldShowLabel(i, total);
            return Expanded(child: Text(
              show ? e.value.label : '',
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.clip,
              style: TextStyle(
                fontSize: 9,
                fontWeight: (isLast || isSel) ? FontWeight.w800 : FontWeight.w500,
                color: !show
                  ? Colors.transparent          // ẩn nhưng giữ layout
                  : isSel ? _kOrange
                  : isLast ? _kNavy
                  : _kMuted)));
          }),
        ]),
      ]),
    );
  }

  Widget _buildEmptyChart(int barCount) => Container(
    height: 140, alignment: Alignment.center,
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))]),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.bar_chart_rounded, size: 40, color: _kMuted.withValues(alpha: 0.35)),
      const SizedBox(height: 8),
      Text(_period == ReportPeriod.today ? 'Chưa có giao dịch hôm nay' : 'Chưa có doanh thu kỳ này',
        style: TextStyle(fontSize: 13, color: _kMuted.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _buildSummary() {
    final items = [
      (label: 'Doanh thu', icon: Icons.payments_rounded, value: _fmtShort(_stats.todayRevenue), color: _kGreen),
      (label: 'Số đơn',    icon: Icons.receipt_long_rounded, value: '${_stats.todayOrders} đơn',          color: _kNavy),
      (label: 'TB/đơn',    icon: Icons.trending_up_rounded, value: _fmtShort(_stats.avgOrderValue),       color: _kOrange),
      (label: 'Khách',     icon: Icons.people_rounded,       value: '${_stats.todayCustomers}',          color: const Color(0xFF7B1FA2)),
    ];

    final moneyFormatter = NumberFormat('#,###', 'vi_VN');
    String formatVnd(double v) => '${moneyFormatter.format(v)} đ';

    Widget buildProgressRow({
      required String label,
      required double amount,
      required Color color,
      String? leadingIcon,
    }) {
      final pct = _stats.todayRevenue > 0 ? (amount / _stats.todayRevenue) * 100 : 0.0;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leadingIcon != null) ...[
                Text(leadingIcon, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
              const Spacer(),
              Text(formatVnd(amount), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct / 100,
              backgroundColor: const Color(0xFFFAF7F2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted)),
            ],
          ),
        ],
      );
    }

    final isWide = MediaQuery.of(context).size.width >= 750;

    final paymentMethodsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.account_balance_wallet_rounded, color: _kNavy, title: 'Theo phương thức thanh toán'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              buildProgressRow(label: 'Tiền mặt', amount: _stats.cashRevenue, color: const Color(0xFF2E7D32), leadingIcon: '💵'),
              const SizedBox(height: 14),
              buildProgressRow(label: 'Chuyển khoản', amount: _stats.transferRevenue, color: const Color(0xFF1976D2), leadingIcon: '🏦'),
              const SizedBox(height: 14),
              buildProgressRow(label: 'Thẻ ngân hàng', amount: _stats.cardRevenue, color: const Color(0xFF8E24AA), leadingIcon: '💳'),
            ],
          ),
        ),
      ],
    );

    final cashiersWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.badge_rounded, color: _kNavy, title: 'Doanh thu theo thu ngân'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _stats.cashierRevenue.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Chưa có thông tin ca thu của nhân viên',
                        style: TextStyle(fontSize: 13, color: _kMuted)),
                  ),
                )
              : Column(
                  children: _stats.cashierRevenue.entries.map((e) {
                    final isLast = e.key == _stats.cashierRevenue.keys.last;
                    final detail = _stats.cashierDetails[e.key];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildProgressRow(label: e.key, amount: e.value, color: const Color(0xFFEF6C00), leadingIcon: '👤'),
                        if (detail != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            margin: const EdgeInsets.only(left: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF9F6),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFEEEBE6)),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Tiền mặt', style: TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(formatVnd(detail.cash), style: const TextStyle(fontSize: 12, color: _kInk, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                                Container(width: 1, height: 20, color: const Color(0xFFEEEBE6)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Chuyển khoản', style: TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(formatVnd(detail.transfer), style: const TextStyle(fontSize: 12, color: _kInk, fontWeight: FontWeight.w800)),
                                    ],
                                  ),
                                ),
                                if (detail.card > 0) ...[
                                  const SizedBox(width: 12),
                                  Container(width: 1, height: 20, color: const Color(0xFFEEEBE6)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Thẻ', style: TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(formatVnd(detail.card), style: const TextStyle(fontSize: 12, color: _kInk, fontWeight: FontWeight.w800)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        if (!isLast) const SizedBox(height: 14),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );

    final waitersWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(icon: Icons.restaurant_menu_rounded, color: _kNavy, title: 'Số bàn phục vụ theo nhân viên'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: _stats.waiterOrders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Chưa có thông tin bàn phục vụ của nhân viên',
                        style: TextStyle(fontSize: 13, color: _kMuted)),
                  ),
                )
              : Column(
                  children: _stats.waiterOrders.entries.map((e) {
                    final isLast = e.key == _stats.waiterOrders.keys.last;
                    final pct = _stats.todayOrders > 0 ? (e.value / _stats.todayOrders) * 100 : 0.0;
                    return Column(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text('👤 ', style: TextStyle(fontSize: 14)),
                                Text(e.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
                                const Spacer(),
                                Text('${e.value} bàn', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct / 100,
                                backgroundColor: const Color(0xFFFAF7F2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8E24AA)),
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kMuted)),
                              ],
                            ),
                          ],
                        ),
                        if (!isLast) const SizedBox(height: 14),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 3.0 : 2.2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: items.map((it) => _SummaryCard(
            label: it.label, icon: it.icon, value: it.value, color: it.color)).toList(),
        ),
        const SizedBox(height: 24),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: paymentMethodsWidget),
              const SizedBox(width: 16),
              Expanded(child: cashiersWidget),
              const SizedBox(width: 16),
              Expanded(child: waitersWidget),
            ],
          )
        else ...[
          paymentMethodsWidget,
          const SizedBox(height: 24),
          cashiersWidget,
          const SizedBox(height: 24),
          waitersWidget,
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — SẢN PHẨM
// ═══════════════════════════════════════════════════════════════════════════════
class _ProductTab extends ConsumerStatefulWidget {
  const _ProductTab();
  @override
  ConsumerState<_ProductTab> createState() => _ProductTabState();
}
class _ProductTabState extends ConsumerState<_ProductTab> {
  ReportPeriod   _period   = ReportPeriod.today;
  DateTime _weekStart = _mondayOf(DateTime.now());
  int _navYear  = DateTime.now().year;
  int _navMonth = DateTime.now().month;
  String?        _category;
  List<TopProduct> _products   = [];
  List<String>     _categories = [];
  bool _loading = true;

  static DateTime _mondayOf(DateTime d) {
    final m = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final repo = ref.read(dashboardRepositoryProvider);
    final (from, to) = _period.rangeFor(weekStart: _weekStart, navYear: _navYear, navMonth: _navMonth);
    final products = await repo.getTopProductsForRangeCompat(from, to, category: _category, limit: 20);
    final cats     = await repo.getProductCategoriesSold(from, to);
    if (mounted) setState(() { _products = products; _categories = cats; _loading = false; });
  }

  Future<void> _pickWeek(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx, initialDate: _weekStart,
      firstDate: DateTime(now.year - 2), lastDate: now,
      helpText: 'Chọn tuần muốn xem',
      builder: (c, child) => Theme(data: Theme.of(c).copyWith(
        colorScheme: const ColorScheme.light(primary: _kNavy)), child: child!),
    );
    if (picked != null && mounted) { setState(() => _weekStart = _mondayOf(picked)); _load(); }
  }

  Future<void> _pickMonth(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx, initialDate: DateTime(_navYear, _navMonth),
      firstDate: DateTime(now.year - 2), lastDate: now,
      helpText: 'Chọn tháng muốn xem',
      builder: (c, child) => Theme(data: Theme.of(c).copyWith(
        colorScheme: const ColorScheme.light(primary: _kNavy)), child: child!),
    );
    if (picked != null && mounted) { setState(() { _navYear = picked.year; _navMonth = picked.month; }); _load(); }
  }

  @override
  Widget build(BuildContext context) {
    final maxQ = _products.fold<double>(1, (m, p) => p.totalQty > m ? p.totalQty : m);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 80), children: [
      _PeriodPills(current: _period, onChanged: (p) { setState(() { _period = p; _category = null; }); _load(); }),
      // ── Nav tuần / tháng
      if (_period == ReportPeriod.week) ...[
        const SizedBox(height: 8),
        _ReportNavBar.week(
          weekStart: _weekStart,
          canGoNext: _weekStart.add(const Duration(days: 7)).isBefore(
            DateTime.now().add(const Duration(days: 1))),
          onPrev: () { setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))); _load(); },
          onNext: () { setState(() => _weekStart = _weekStart.add(const Duration(days: 7))); _load(); },
          onPick: () => _pickWeek(context),
        ),
      ],
      if (_period == ReportPeriod.month) ...[
        const SizedBox(height: 8),
        _ReportNavBar.month(
          year: _navYear, month: _navMonth,
          canGoNext: !(_navYear == DateTime.now().year && _navMonth == DateTime.now().month),
          onPrev: () { setState(() { if (_navMonth == 1) { _navYear--; _navMonth = 12; } else { _navMonth--; } }); _load(); },
          onNext: () { setState(() { if (_navMonth == 12) { _navYear++; _navMonth = 1; } else { _navMonth++; } }); _load(); },
          onPick: () => _pickMonth(context),
        ),
      ],
      if (_categories.isNotEmpty) ...[
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _CatPill(label: 'Tất cả', active: _category == null,
            onTap: () { setState(() => _category = null); _load(); }),
          ..._categories.map((c) => _CatPill(label: c, active: _category == c,
            onTap: () { setState(() => _category = c); _load(); })),
        ])),
      ],
      const SizedBox(height: 20),
      _SectionHeader(icon: Icons.trending_up_rounded, color: _kNavy, title: 'Top sản phẩm bán chạy'),
      const SizedBox(height: 12),
      if (_loading) const _LoadingCard()
      else if (_products.isEmpty)
        _EmptyState(icon: Icons.inventory_2_rounded, message: 'Chưa có đơn hàng nào kỳ này')
      else ..._products.asMap().entries.map((e) {
        final p = e.value; final rank = e.key + 1;
        final barRatio = maxQ > 0 ? p.totalQty / maxQ : 0.0;

        // Màu theo rank
        final rankGradients = [
          [const Color(0xFFF9A825), const Color(0xFFFFC107)], // 🥇 vàng
          [const Color(0xFF78909C), const Color(0xFF90A4AE)], // 🥈 bạc
          [const Color(0xFFBF6F44), const Color(0xFFCD7F32)], // 🥉 đồng
        ];
        final barColors = [_kGold, _kNavy.withValues(alpha: 0.6), _kOrange, _kMuted.withValues(alpha: 0.3)];
        final isTop3 = rank <= 3;
        final grad = isTop3 ? rankGradients[rank - 1] : null;
        final barColor = rank <= 4 ? barColors[rank - 1] : _kMuted.withValues(alpha: 0.25);
        final avgPrice = p.totalQty > 0 ? p.totalRevenue / p.totalQty : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: rank == 1 ? _kGold.withValues(alpha: 0.5) : _kBorder,
              width: rank == 1 ? 1.5 : 1),
            boxShadow: [BoxShadow(
              color: rank == 1 ? _kGold.withValues(alpha: 0.14) : _kNavy.withValues(alpha: 0.05),
              blurRadius: rank == 1 ? 14 : 8, offset: const Offset(0, 3))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                // Rank badge
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: grad != null
                      ? LinearGradient(colors: grad, begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                    color: grad == null ? _kBg : null,
                  ),
                  child: Center(child: isTop3
                    ? Builder(builder: (_) {
                        final List<Color> g = [
                          [const Color(0xFFFFB300), const Color(0xFFFF8F00)],
                          [const Color(0xFF78909C), const Color(0xFF546E7A)],
                          [const Color(0xFFBF6B3D), const Color(0xFF8D4B2A)],
                        ][rank - 1];
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: g,
                                begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.35),
                                blurRadius: 6, offset: const Offset(0, 3))],
                          ),
                          alignment: Alignment.center,
                          child: Text('$rank',
                            style: const TextStyle(color: Colors.white, fontSize: 15,
                                fontWeight: FontWeight.w900)),
                        );
                      })
                    : Text('$rank', style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, color: _kMuted)))),
                const SizedBox(width: 12),
                // Name + qty
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.productName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kInk),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kNavy.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text('${p.totalQty.toStringAsFixed(0)} phần',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _kNavy))),
                    const SizedBox(width: 6),
                    Text('TB ${_fmtShort(avgPrice)}/phần',
                      style: TextStyle(fontSize: 10, color: _kMuted.withValues(alpha: 0.8))),
                  ]),
                ])),
                // Revenue
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmtShort(p.totalRevenue),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900,
                      color: rank == 1 ? const Color(0xFFE65100) : _kInk)),
                  Text('doanh thu', style: TextStyle(fontSize: 9, color: _kMuted.withValues(alpha: 0.7))),
                ]),
              ]),
            ),
            // Progress bar
            Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: barRatio, minHeight: 6,
                  backgroundColor: _kBg,
                  valueColor: AlwaysStoppedAnimation(barColor)))),
          ]),
        ).animate(delay: (e.key * 40).ms).fadeIn(duration: 220.ms).slideY(begin: 0.04, end: 0, duration: 220.ms, curve: Curves.easeOut);
      }),
    ]);
  }
}

class _CatPill extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _CatPill({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 200), curve: Curves.easeOut,
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _kOrange : _kCard, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? _kOrange : _kBorder, width: active ? 1.5 : 1),
        boxShadow: active ? [BoxShadow(color: _kOrange.withValues(alpha: 0.25), blurRadius: 8)] : null),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
        color: active ? Colors.white : _kInk))));
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — TÀI CHÍNH
// ═══════════════════════════════════════════════════════════════════════════════
class _FinanceTab extends ConsumerWidget {
  const _FinanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(periodProvider);
    final statsA = ref.watch(financeStatsProvider);

    final moneyFormatter = NumberFormat('#,###', 'vi_VN');
    String formatVnd(double v) => '${moneyFormatter.format(v)} đ';

    TableRow buildTableRow({
      required String name,
      required String value,
      required String pct,
      bool isBold = false,
      bool indent = false,
      Color? color,
    }) {
      final style = TextStyle(
        fontSize: 13,
        fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
        color: isBold ? _kInk : _kInk.withValues(alpha: 0.8),
      );
      return TableRow(
        decoration: color != null ? BoxDecoration(color: color) : null,
        children: [
          Padding(
            padding: EdgeInsets.only(left: indent ? 28.0 : 16.0, right: 16.0, top: 12.0, bottom: 12.0),
            child: Text(name, style: style),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(value, style: style.copyWith(color: isBold ? _kNavy : null), textAlign: TextAlign.right),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(pct, style: style, textAlign: TextAlign.right),
          ),
        ],
      );
    }

    List<TableRow> buildExpenseSubRows(Map<String, double> categories, double totalIncome) {
      if (categories.isEmpty) {
        return [
          buildTableRow(
            name: '  1. Chi phí khác',
            value: formatVnd(0),
            pct: '0%',
            indent: true,
          )
        ];
      }
      int index = 1;
      return categories.entries.map((e) {
        final pct = totalIncome > 0 ? (e.value / totalIncome * 100) : 0.0;
        final name = '  $index. ${e.key}';
        index++;
        return buildTableRow(
          name: name,
          value: formatVnd(e.value),
          pct: '${pct.toStringAsFixed(1)}%',
          indent: true,
        );
      }).toList();
    }

    return statsA.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (stats) => ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 80), children: [
        // Period pills — sync Finance screen
        Container(padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            _FinBtn(label: 'Hôm nay',   active: period.label == 'Hôm nay',   onTap: () => ref.read(periodProvider.notifier).setToday()),
            _FinBtn(label: 'Tuần này',  active: period.label == 'Tuần này',  onTap: () => ref.read(periodProvider.notifier).setThisWeek()),
            _FinBtn(label: 'Tháng này', active: period.label == 'Tháng này', onTap: () => ref.read(periodProvider.notifier).setThisMonth()),
          ])),
        const SizedBox(height: 20),
        // Profit hero card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: stats.profit >= 0
                ? [const Color(0xFF1B5E20), const Color(0xFF388E3C)]
                : [const Color(0xFFB71C1C), const Color(0xFFD32F2F)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [BoxShadow(
              color: (stats.profit >= 0 ? _kGreen : _kRed).withValues(alpha: 0.3),
              blurRadius: 16, offset: const Offset(0, 6))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: Icon(stats.profit >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: Colors.white, size: 18)),
              const SizedBox(width: 8),
              Text(stats.profit >= 0 ? 'LỢI NHUẬN' : 'ĐANG LỖ',
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ]),
            const SizedBox(height: 12),
            Text('${stats.profit >= 0 ? '+ ' : '- '}${_fmtShort(stats.profit.abs())}',
              style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, letterSpacing: -1.5)),
            const SizedBox(height: 4),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.2), margin: const EdgeInsets.symmetric(vertical: 8)),
            Row(children: [
              _FinStat(label: 'Thu nhập', value: _fmtShort(stats.income)),
              Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
              _FinStat(label: 'Chi phí', value: _fmtShort(stats.expense)),
              Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.3), margin: const EdgeInsets.symmetric(horizontal: 16)),
              _FinStat(label: 'Biên LN',
                value: '${stats.income > 0 ? (stats.profit / stats.income * 100).toStringAsFixed(1) : 0}%'),
            ]),
          ])).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
        
        const SizedBox(height: 24),
        const _SectionHeader(icon: Icons.assignment_rounded, color: _kNavy, title: 'Kết quả kinh doanh'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(4.5), // Khoản mục
              1: FlexColumnWidth(3.0), // Giá trị
              2: FlexColumnWidth(1.8), // Tỷ trọng
            },
            border: TableBorder.symmetric(
              inside: BorderSide(color: _kBorder.withValues(alpha: 0.5), width: 1),
            ),
            children: [
              // Header row
              const TableRow(
                decoration: BoxDecoration(
                  color: Color(0xFFFAF7F2),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Khoản mục', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _kNavy)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Giá trị', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _kNavy), textAlign: TextAlign.right),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text('Tỷ trọng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _kNavy), textAlign: TextAlign.right),
                  ),
                ],
              ),
              // I. Doanh thu từ bán hàng
              buildTableRow(
                name: 'I. Doanh thu từ bán hàng',
                value: formatVnd(stats.income),
                pct: '100%',
                isBold: true,
              ),
              buildTableRow(
                name: '  1. Tiền hàng',
                value: formatVnd(stats.income),
                pct: '100%',
                indent: true,
              ),
              buildTableRow(
                name: '  2. Tiền thuế GTGT',
                value: formatVnd(0),
                pct: '0%',
                indent: true,
              ),
              // II. Chi phí
              buildTableRow(
                name: 'II. Chi phí',
                value: formatVnd(stats.expense),
                pct: '${stats.income > 0 ? (stats.expense / stats.income * 100).toStringAsFixed(1) : 0}%',
                isBold: true,
                color: _kRed.withValues(alpha: 0.05),
              ),
              ...buildExpenseSubRows(stats.expenseByCategory, stats.income),
              // III. Lợi nhuận từ bán hàng
              buildTableRow(
                name: 'III. Lợi nhuận từ bán hàng (I - II)',
                value: formatVnd(stats.profit),
                pct: '${stats.income > 0 ? (stats.profit / stats.income * 100).toStringAsFixed(1) : 0}%',
                isBold: true,
                color: _kGreen.withValues(alpha: 0.05),
              ),
            ],
          ),
        ),

        if (stats.incomeGrowth != 0) ...[
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: stats.incomeGrowth > 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: stats.incomeGrowth > 0 ? const Color(0xFF81C784) : const Color(0xFFEF9A9A))),
            child: Row(children: [
              Icon(stats.incomeGrowth > 0 ? Icons.arrow_circle_up_rounded : Icons.arrow_circle_down_rounded,
                color: stats.incomeGrowth > 0 ? _kGreen : _kRed, size: 28),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(stats.incomeGrowth > 0 ? 'Đang tăng trưởng tốt 🎉' : 'Đang sụt giảm',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800,
                    color: stats.incomeGrowth > 0 ? _kGreen : _kRed)),
                Text(stats.incomeGrowth > 0
                  ? 'Thu nhập tăng ${stats.incomeGrowth.toStringAsFixed(1)}% so với kỳ trước'
                  : 'Thu nhập giảm ${stats.incomeGrowth.abs().toStringAsFixed(1)}% so với kỳ trước',
                  style: TextStyle(fontSize: 11, color: (stats.incomeGrowth > 0 ? _kGreen : _kRed).withValues(alpha: 0.8))),
              ])),
            ])),
        ],
      ]),
    );
  }
}

class _FinBtn extends StatelessWidget {
  final String label; final bool active; final VoidCallback onTap;
  const _FinBtn({required this.label, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
    child: AnimatedContainer(duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 9),
      decoration: BoxDecoration(color: active ? _kNavy : Colors.transparent, borderRadius: BorderRadius.circular(9),
        boxShadow: active ? [BoxShadow(color: _kNavy.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))] : null),
      child: Text(label, textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : _kMuted)))));
}

class _FinStat extends StatelessWidget {
  final String label, value;
  const _FinStat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
    Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon; final Color color; final String title;
  const _SectionHeader({required this.icon, required this.color, required this.title});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 32, height: 32,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, size: 17, color: color)),
    const SizedBox(width: 10),
    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.2)),
  ]);
}

class _SummaryCard extends StatelessWidget {
  final String label, value; final IconData icon; final Color color;
  const _SummaryCard({required this.label, required this.icon, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: _kCard, borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 3))]),
    child: Row(children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: color, size: 22)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.3)),
        Text(label, style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
      ])),
    ]),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => Container(height: 140, alignment: Alignment.center,
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.05), blurRadius: 10)]),
    child: const CircularProgressIndicator(color: _kNavy, strokeWidth: 2.5));
}

class _EmptyState extends StatelessWidget {
  final IconData icon; final String message;
  const _EmptyState({required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 48),
    child: Column(children: [
      Container(width: 72, height: 72,
        decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(20)),
        child: Icon(icon, size: 36, color: _kMuted.withValues(alpha: 0.4))),
      const SizedBox(height: 12),
      Text(message, style: TextStyle(color: _kMuted.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w500)),
    ]));
}

// ─── Tooltip khi tap vào cột bar ─────────────────────────────────────────────
class _BarTooltip extends StatelessWidget {
  final String label;
  final double revenue;
  final int    orders;
  const _BarTooltip({required this.label, required this.revenue, required this.orders});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: _kNavy,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 3))]),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(label,
        style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
      Text('${_fmtShort(revenue)}đ',
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
      Text('$orders đơn',
        style: const TextStyle(color: Colors.white60, fontSize: 9)),
    ]),
  );
}

// ─── Report Nav Bar (← Tuần/Tháng →) ────────────────────────────────────────
class _ReportNavBar extends StatefulWidget {
  final String label;
  final bool canGoNext;
  final VoidCallback onPrev, onNext, onPick;
  const _ReportNavBar({required this.label, required this.canGoNext,
    required this.onPrev, required this.onNext, required this.onPick});

  factory _ReportNavBar.week({required DateTime weekStart, required bool canGoNext,
    required VoidCallback onPrev, required VoidCallback onNext, required VoidCallback onPick}) {
    final weekEnd  = weekStart.add(const Duration(days: 6));
    final startStr = DateFormat('dd/MM').format(weekStart);
    final endStr   = DateFormat('dd/MM').format(weekEnd);
    final wk = ((int.parse(DateFormat('D').format(weekStart)) - weekStart.weekday + 10) / 7).floor();
    return _ReportNavBar(label: 'Tuần $wk · $startStr–$endStr',
      canGoNext: canGoNext, onPrev: onPrev, onNext: onNext, onPick: onPick);
  }

  factory _ReportNavBar.month({required int year, required int month, required bool canGoNext,
    required VoidCallback onPrev, required VoidCallback onNext, required VoidCallback onPick}) {
    return _ReportNavBar(label: 'Tháng $month / $year',
      canGoNext: canGoNext, onPrev: onPrev, onNext: onNext, onPick: onPick);
  }

  @override
  State<_ReportNavBar> createState() => _ReportNavBarState();
}

class _ReportNavBarState extends State<_ReportNavBar> {
  int _dir = 1;

  void _prev() { HapticFeedback.lightImpact(); setState(() => _dir = -1); widget.onPrev(); }
  void _next() { HapticFeedback.lightImpact(); setState(() => _dir =  1); widget.onNext(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_kNavy.withValues(alpha: 0.07), _kNavy.withValues(alpha: 0.04)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kNavy.withValues(alpha: 0.12)),
      ),
      child: Row(children: [
        _RNavBtn(icon: Icons.chevron_left_rounded, onTap: _prev),
        Expanded(child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); widget.onPick(); },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: Offset(_dir * 0.3, 0), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child)),
            child: Row(key: ValueKey(widget.label),
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.label, style: const TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w800, color: _kNavy, letterSpacing: -0.2)),
                const SizedBox(width: 5),
                Container(padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(5)),
                  child: const Icon(Icons.calendar_month_rounded, size: 11, color: _kNavy)),
              ]),
          ),
        )),
        _RNavBtn(icon: Icons.chevron_right_rounded, onTap: widget.canGoNext ? _next : null),
      ]),
    );
  }
}

class _RNavBtn extends StatefulWidget {
  final IconData icon; final VoidCallback? onTap;
  const _RNavBtn({required this.icon, required this.onTap});
  @override State<_RNavBtn> createState() => _RNavBtnState();
}
class _RNavBtnState extends State<_RNavBtn> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<double> _s;
  @override void initState() { super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 110));
    _s = Tween<double>(begin: 1.0, end: 0.80).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  void _tap() { if (widget.onTap == null) return; _c.forward().then((_) => _c.reverse()); widget.onTap!(); }
  @override
  Widget build(BuildContext context) {
    final on = widget.onTap != null;
    return GestureDetector(onTap: _tap,
      child: AnimatedBuilder(animation: _s,
        builder: (_, ch) => Transform.scale(scale: _s.value, child: ch),
        child: Container(width: 40, height: 40, margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on ? [BoxShadow(color: _kNavy.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 2))] : null),
          child: Icon(widget.icon, size: 20, color: on ? _kNavy : _kMuted.withValues(alpha: 0.3)))));
  }
}

// ─── Formatters
// Định dạng tiền: 2.5 trĐ / 500 KĐ / 100 Đ
String _fmt(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} Tr Đ';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)} K Đ';
  return '${v.toStringAsFixed(0)} Đ';
}
String _fmtShort(double v) => _fmt(v);

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 4 — KHO (purchase_orders) — Ẩn khi module Kho tắt
// ═══════════════════════════════════════════════════════════════════════════════
class _KhoTab extends ConsumerStatefulWidget {
  const _KhoTab();
  @override
  ConsumerState<_KhoTab> createState() => _KhoTabState();
}

class _KhoTabState extends ConsumerState<_KhoTab> {
  // Dữ liệu purchase_orders tháng này
  double _totalCost  = 0;
  int    _totalOrders = 0;
  List<Map<String,dynamic>> _topProducts = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Lấy store_id — dùng getStoreInfo() để handle cả 2 key variants
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId == null) { if (mounted) setState(() => _loading = false); return; }

      final sb    = Supabase.instance.client;
      final now   = DateTime.now();
      // Dùng lt + midnight tháng kế (exclusive) — nhất quán toàn hệ thống
      final start = DateTime(now.year, now.month, 1).toIso8601String();
      final end   = DateTime(now.year, now.month + 1, 1).toIso8601String();

      // ── Query 1: Lấy purchase_orders của store trong tháng ────────────────
      final pos = await sb
          .from('purchase_orders')
          .select('id, total_amount')
          .eq('store_id', storeId)
          .gte('created_at', start)
          .lt('created_at', end);

      double total = 0;
      for (final p in pos) {
        total += (p['total_amount'] as num?)?.toDouble() ?? 0;
      }

      // ── Query 2: Lấy items theo order IDs (tránh join có FK dependency) ──
      // Tương tự pattern getTopProductsForRange() trong dashboard_repository
      final Map<String, Map<String, dynamic>> grouped = {};
      if (pos.isNotEmpty) {
        final poIds = pos.map((p) => p['id'] as String).toList();
        final items = await sb
            .from('purchase_items')
            .select('product_name, quantity, subtotal')
            .inFilter('po_id', poIds);

        for (final it in items) {
          final name = it['product_name'] as String? ?? '?';
          grouped.putIfAbsent(name, () => {'name': name, 'qty': 0.0, 'cost': 0.0});
          grouped[name]!['qty']  = (grouped[name]!['qty']  as double) + ((it['quantity'] as num?)?.toDouble() ?? 0);
          grouped[name]!['cost'] = (grouped[name]!['cost'] as double) + ((it['subtotal'] as num?)?.toDouble() ?? 0);
        }
      }

      final sorted = grouped.values.toList()
        ..sort((a, b) => (b['cost'] as double).compareTo(a['cost'] as double));

      if (mounted) { setState(() {
        _totalCost   = total;
        _totalOrders = pos.length;
        _topProducts = sorted.take(5).toList();
        _loading     = false;
      }); }
    } catch (e) {
      // Hiện error thực sự để debug — không dùng message generic
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    // Kiểm tra Kho module có bật không
    final modules = ref.watch(activeModulesProvider).value ?? [];
    final khoOn   = modules.any((m) => m.id == 'kho' && m.isActive);

    if (!khoOn) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3EF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 48, color: _kMuted),
          ),
          const SizedBox(height: 16),
          const Text('Module Kho đang tắt',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kInk)),
          const SizedBox(height: 6),
          const Text('Bật module Kho trong Cài đặt để xem báo cáo nhập hàng',
            style: TextStyle(fontSize: 13, color: _kMuted),
            textAlign: TextAlign.center),
        ]),
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kNavy));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_rounded, size: 40, color: _kMuted),
        const SizedBox(height: 8),
        const Text('Không tải được dữ liệu kho', style: TextStyle(color: _kMuted)),
        const SizedBox(height: 6),
        // Hiện error thực sự để debug
        Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SelectableText(_error!,
            style: const TextStyle(fontSize: 10, color: _kRed),
            textAlign: TextAlign.center)),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Thử lại')),
      ]));
    }

    final now = DateTime.now();
    final monthLabel = 'Tháng ${now.month}/${now.year}';

    return ListView(padding: const EdgeInsets.fromLTRB(16, 20, 16, 80), children: [
      // Hero banner — Tổng nhập tháng
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B3A5E), Color(0xFF2563EB)],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.3),
            blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.inventory_2_rounded, color: Colors.white, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Nhập hàng $monthLabel',
              style: const TextStyle(color: Colors.white70, fontSize: 11,
                fontWeight: FontWeight.w600)),
            Text(_fmt(_totalCost),
              style: const TextStyle(color: Colors.white, fontSize: 26,
                fontWeight: FontWeight.w900, letterSpacing: -1)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$_totalOrders phiếu',
              style: const TextStyle(color: Colors.white, fontSize: 14,
                fontWeight: FontWeight.w800)),
            const Text('nhập hàng',
              style: TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ]),
      ),
      const SizedBox(height: 24),

      // Top sản phẩm nhập
      _SectionHeader(icon: Icons.trending_up_rounded, color: _kNavy,
        title: 'Sản phẩm nhập nhiều nhất'),
      const SizedBox(height: 12),
      if (_topProducts.isEmpty)
        _EmptyState(icon: Icons.inbox_rounded, message: 'Chưa có phiếu nhập nào tháng này')
      else
        ..._topProducts.asMap().entries.map((e) {
          final p    = e.value;
          final rank = e.key + 1;
          final cost = p['cost'] as double;
          final qty  = p['qty'] as double;
          final maxCost = (_topProducts.first['cost'] as double).clamp(1.0, double.infinity);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _kBorder),
              boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.04),
                blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _kNavy.withValues(alpha: rank == 1 ? 0.12 : 0.06),
                    borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('$rank',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                      color: rank == 1 ? _kNavy : _kMuted))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(p['name'] as String,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kInk), maxLines: 1, overflow: TextOverflow.ellipsis)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_fmt(cost), style: TextStyle(fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: rank == 1 ? _kOrange : _kNavy)),
                  Text('${qty.toStringAsFixed(0)} đvt',
                    style: const TextStyle(fontSize: 10, color: _kMuted)),
                ]),
              ]),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: maxCost > 0 ? cost / maxCost : 0,
                  minHeight: 5, backgroundColor: _kBg,
                  valueColor: AlwaysStoppedAnimation(_kNavy.withValues(
                    alpha: 0.3 + (0.5 * (1 - e.key / _topProducts.length)))))),
            ]),
          ).animate(delay: (e.key * 40).ms)
            .fadeIn(duration: 220.ms)
            .slideY(begin: 0.04, end: 0, duration: 220.ms, curve: Curves.easeOut);
        }),

      const SizedBox(height: 16),
      // Nút refresh
      Center(child: TextButton.icon(
        onPressed: _load,
        icon: const Icon(Icons.refresh_rounded, size: 16, color: _kMuted),
        label: const Text('Làm mới',
          style: TextStyle(color: _kMuted, fontSize: 12)),
      )),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — KPI tổng quan
// ─────────────────────────────────────────────────────────────────────────────
class _ReportRightPanel extends ConsumerWidget {
  final AsyncValue<DashboardStats> todayStats;
  final AsyncValue<FinanceStats> todayFin;
  final AsyncValue<double> monthRev;
  const _ReportRightPanel({
    required this.todayStats,
    required this.todayFin,
    required this.monthRev,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = todayStats.value ?? DashboardStats.empty;
    final f = todayFin.value ?? FinanceStats.empty;
    final m = monthRev.value ?? 0.0;

    final voidAsync = ref.watch(todayVoidStatsProvider);
    final voidStats = voidAsync.value ?? {'amount': 0.0, 'count': 0};
    final double voidAmount = voidStats['amount'] as double;
    final int voidCount = voidStats['count'] as int;

    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          // ── KPI Hôm nay ──────────────────────────────────────────────
          _RPCard(
            title: 'KPI hôm nay',
            icon: Icons.insights_rounded,
            child: Column(children: [
              _RPRow(label: 'Doanh thu', value: _fmtShort(s.todayRevenue), color: _kOrange),
              const Divider(height: 1),
              _RPRow(label: 'Số đơn', value: '${s.todayOrders}', color: _kNavy),
              const Divider(height: 1),
              _RPRow(label: 'TB/đơn', value: _fmtShort(s.avgOrderValue), color: const Color(0xFFF9A825)),
              const Divider(height: 1),
              _RPRow(label: 'Chi phí', value: _fmtShort(f.expense), color: _kRed),
              const Divider(height: 1),
              _RPRow(label: 'Lợi nhuận', value: _fmtShort(f.profit),
                color: f.profit >= 0 ? _kGreen : _kRed),
              if (f.profitMargin != 0) ...[
                const Divider(height: 1),
                _RPRow(label: 'Biên LN', value: '${f.profitMargin.toStringAsFixed(1)}%', color: _kNavy),
              ],
            ]),
          ),
          const SizedBox(height: 12),

          // ── Huỷ Bàn / Huỷ Bill ───────────────────────────────────────
          _RPCard(
            title: 'Huỷ Bàn / Huỷ Bill',
            icon: Icons.delete_sweep_rounded,
            child: Column(children: [
              _RPRow(label: 'Hôm nay', value: '$voidCount lượt', color: _kNavy),
            ]),
          ),
          const SizedBox(height: 12),

          // ── Tháng này ────────────────────────────────────────────────
          _RPCard(
            title: 'Tháng ${DateTime.now().month}',
            icon: Icons.calendar_month_rounded,
            child: Column(children: [
              _RPRow(label: 'Doanh thu lũy kế', value: _fmtShort(m), color: _kGreen),
            ]),
          ),
        ],
      ),
    );
  }
}

class _RPCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _RPCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _kCard,
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

class _RPRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _RPRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kInk))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 5 — KIỂM TOÁN HUỶ/DUYỆT (void_audit_logs)
// ═══════════════════════════════════════════════════════════════════════════════
class _VoidAuditTab extends ConsumerStatefulWidget {
  const _VoidAuditTab();
  @override
  ConsumerState<_VoidAuditTab> createState() => _VoidAuditTabState();
}

class _VoidAuditTabState extends ConsumerState<_VoidAuditTab> {
  ReportPeriod _period = ReportPeriod.today;
  DateTime _weekStart = _mondayOf(DateTime.now());
  int _navYear = DateTime.now().year;
  int _navMonth = DateTime.now().month;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;
  String? _error;

  static DateTime _mondayOf(DateTime d) {
    final m = d.subtract(Duration(days: d.weekday - 1));
    return DateTime(m.year, m.month, m.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final sb = Supabase.instance.client;
      final (from, to) = _period.rangeFor(
        weekStart: _weekStart,
        navYear: _navYear,
        navMonth: _navMonth,
      );
      final start = DateTime.fromMillisecondsSinceEpoch(from).toIso8601String();
      final end = DateTime.fromMillisecondsSinceEpoch(to).toIso8601String();

      final res = await sb
          .from('void_audit_logs')
          .select()
          .eq('store_id', storeId)
          .gte('created_at', start)
          .lt('created_at', end)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _pickWeek(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: _weekStart,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Chọn tuần muốn xem',
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(primary: _kNavy),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _weekStart = _mondayOf(picked));
      _load();
    }
  }

  Future<void> _pickMonth(BuildContext ctx) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: ctx,
      initialDate: DateTime(_navYear, _navMonth),
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Chọn tháng muốn xem',
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(primary: _kNavy),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        _navYear = picked.year;
        _navMonth = picked.month;
      });
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalVoidAmount = 0;
    for (final log in _logs) {
      totalVoidAmount += (log['amount'] as num?)?.toDouble() ?? 0;
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _kNavy,
      backgroundColor: _kCard,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 80),
        children: [
          _PeriodPills(
            current: _period,
            onChanged: (p) {
              setState(() => _period = p);
              _load();
            },
          ),
          if (_period == ReportPeriod.week) ...[
            const SizedBox(height: 8),
            _ReportNavBar.week(
              weekStart: _weekStart,
              canGoNext: _weekStart.add(const Duration(days: 7)).isBefore(
                DateTime.now().add(const Duration(days: 1)),
              ),
              onPrev: () {
                setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
                _load();
              },
              onNext: () {
                setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
                _load();
              },
              onPick: () => _pickWeek(context),
            ),
          ],
          if (_period == ReportPeriod.month) ...[
            const SizedBox(height: 8),
            _ReportNavBar.month(
              year: _navYear,
              month: _navMonth,
              canGoNext: !(_navYear == DateTime.now().year && _navMonth == DateTime.now().month),
              onPrev: () {
                setState(() {
                  if (_navMonth == 1) {
                    _navYear--;
                    _navMonth = 12;
                  } else {
                    _navMonth--;
                  }
                });
                _load();
              },
              onNext: () {
                setState(() {
                  if (_navMonth == 12) {
                    _navYear++;
                    _navMonth = 1;
                  } else {
                    _navMonth++;
                  }
                });
                _load();
              },
              onPick: () => _pickMonth(context),
            ),
          ],
          const SizedBox(height: 16),

          // KPI Banner: Tổng thất thoát
          _buildSummaryBanner(totalVoidAmount),
          const SizedBox(height: 24),

          _SectionHeader(
            icon: Icons.history_rounded,
            color: _kNavy,
            title: 'Nhật ký hủy / duyệt',
          ),
          const SizedBox(height: 12),

          if (_loading)
            const _LoadingCard()
          else if (_error != null)
            _buildErrorWidget()
          else if (_logs.isEmpty)
            _EmptyState(
              icon: Icons.assignment_turned_in_outlined,
              message: 'Không có lịch sử hủy duyệt nào trong kỳ này',
            )
          else
            ..._logs.asMap().entries.map((e) {
              final log = e.value;
              return _buildLogCard(log, e.key);
            }),
        ],
      ),
    );
  }

  Widget _buildSummaryBanner(double totalAmount) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFC62828)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _kRed.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.trending_down_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tổng thất thoát do huỷ ${_period.label.toLowerCase()}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _fmtShort(totalAmount),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_logs.length} lượt huỷ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'được kiểm toán',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 40, color: _kMuted),
          const SizedBox(height: 8),
          const Text('Không tải được nhật ký kiểm toán', style: TextStyle(color: _kMuted)),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SelectableText(
              _error!,
              style: const TextStyle(fontSize: 10, color: _kRed),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log, int index) {
    final voidType = log['void_type'] as String? ?? 'void_item';
    final label = log['label'] as String? ?? '';
    final requestedByName = log['requested_by_name'] as String? ?? 'N/A';
    final approvedByName = log['approved_by_name'] as String? ?? 'N/A';
    final reason = log['reason'] as String? ?? 'Không có lý do';
    final amount = (log['amount'] as num?)?.toDouble() ?? 0.0;
    final createdAtStr = log['created_at'] as String? ?? '';

    // Định dạng ngày giờ
    String timeStr = '';
    if (createdAtStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(createdAtStr).toLocal();
        timeStr = DateFormat('HH:mm - dd/MM', 'vi').format(dt);
      } catch (_) {
        timeStr = createdAtStr;
      }
    }

    final isTableCancel = voidType == 'cancel_table';
    final isOrderCancel = voidType == 'cancel_order';

    final details = log['details_json'] as List<dynamic>?;
    final hasDetails = details != null && details.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: _kNavy.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: hasDetails ? () => _showDetailsDialog(label, details, amount, reason, requestedByName, approvedByName, timeStr) : null,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon loại huỷ bo góc tròn HSL harmonious
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isTableCancel
                        ? const Color(0xFFFFEBEE)
                        : isOrderCancel
                            ? const Color(0xFFEDE7F6)
                            : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isTableCancel
                        ? Icons.table_restaurant_rounded
                        : isOrderCancel
                            ? Icons.receipt_long_rounded
                            : Icons.restaurant_rounded,
                    color: isTableCancel
                        ? const Color(0xFFD32F2F)
                        : isOrderCancel
                            ? const Color(0xFF673AB7)
                            : const Color(0xFFF57C00),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Nội dung text chính
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _kInk,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isTableCancel
                                  ? const Color(0xFFFFEBEE)
                                  : isOrderCancel
                                      ? const Color(0xFFEDE7F6)
                                      : const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isTableCancel
                                  ? 'Huỷ bàn'
                                  : isOrderCancel
                                      ? 'Huỷ hoá đơn'
                                      : 'Huỷ món',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: isTableCancel
                                    ? const Color(0xFFC62828)
                                    : isOrderCancel
                                        ? const Color(0xFF5E35B1)
                                        : const Color(0xFFE65100),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Ai yêu cầu, ai duyệt
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 12, color: _kMuted),
                          children: [
                            const TextSpan(text: 'Yêu cầu: '),
                            TextSpan(
                              text: requestedByName,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: _kInk),
                            ),
                            const TextSpan(text: '  •  Duyệt: '),
                            TextSpan(
                              text: approvedByName,
                              style: const TextStyle(fontWeight: FontWeight.w700, color: _kInk),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Lý do
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lý do: ',
                            style: TextStyle(fontSize: 12, color: _kMuted),
                          ),
                          Expanded(
                            child: Text(
                              reason,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _kInk,
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (hasDetails) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 12, color: _kNavy.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Text(
                              'Nhấn để xem chi tiết món huỷ (${details.length})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _kNavy.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Phải bên phải: Số tiền & Thời gian
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _fmtShort(amount),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: _kRed,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: _kMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate(delay: (index * 30).ms)
        .fadeIn(duration: 200.ms)
        .slideY(begin: 0.04, end: 0, duration: 200.ms, curve: Curves.easeOut);
  }

  void _showDetailsDialog(
    String targetLabel,
    List<dynamic> details,
    double totalAmount,
    String reason,
    String requestedBy,
    String approvedBy,
    String timeStr,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: _kBg,
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              Row(
                children: [
                  const Icon(Icons.playlist_remove_rounded, color: _kOrange, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chi tiết món huỷ - $targetLabel',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: _kNavy,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 20),

              // Thông tin kiểm toán
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Column(
                  children: [
                    _dialogInfoRow('Yêu cầu:', requestedBy),
                    const SizedBox(height: 4),
                    _dialogInfoRow('Phê duyệt:', approvedBy),
                    const SizedBox(height: 4),
                    _dialogInfoRow('Thời gian:', timeStr),
                    const SizedBox(height: 4),
                    _dialogInfoRow('Lý do:', reason, italic: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Danh sách món huỷ',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                ),
              ),
              const SizedBox(height: 8),

              // Danh sách các món
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(10),
                    itemCount: details.length,
                    separatorBuilder: (context, index) => const Divider(height: 12),
                    itemBuilder: (context, index) {
                      final item = details[index];
                      final name = item['name'] ?? item['product_name'] ?? item['productName'] ?? 'Không rõ tên';
                      final qty = (item['quantity'] ?? item['qty'] ?? 1.0) as num;
                      final price = (item['price'] ?? item['unit_price'] ?? 0.0) as num;
                      final itemTotal = qty * price;

                      return Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _kNavy.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'x${qty.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _kInk,
                                  ),
                                ),
                                Text(
                                  'Đơn giá: ${_fmtShort(price.toDouble())}',
                                  style: const TextStyle(fontSize: 10, color: _kMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _fmtShort(itemTotal.toDouble()),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _kInk,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Tổng số tiền thất thoát
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng tiền huỷ:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: _kNavy,
                    ),
                  ),
                  Text(
                    _fmtShort(totalAmount),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _kRed,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Nút Đóng - 52px height
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dialogInfoRow(String label, String value, {bool italic = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: italic ? FontWeight.w500 : FontWeight.w700,
              color: _kInk,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ),
      ],
    );
  }
}
