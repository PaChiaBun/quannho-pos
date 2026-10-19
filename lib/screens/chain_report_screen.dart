import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/repositories/chain_repository.dart';
import '../core/utils/chain_compare.dart';
import '../core/utils/chain_insights.dart';
import '../core/utils/money_formatter.dart';
import 'chain_manage_sheet.dart';

// ─── Design Tokens — dùng đúng bộ màu của module Báo cáo (report_screen.dart) ───
const _kNavy = Color(0xFF1C2151);
const _kNavyL = Color(0xFF2A3A8F);
const _kOrange = Color(0xFFFF6B35);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFC62828);
const _kGold = Color(0xFFF9A825);
const _kInk = Color(0xFF1A1207);
const _kMuted = Color(0xFF9E9085);
const _kBg = Color(0xFFFFF8F0);
const _kCard = Color(0xFFFFFFFF);
const _kBlue = Color(0xFF1565C0);
const _kOther = Color(0xFF90A4AE); // ví/khác

/// Bảng màu cho từng cửa hàng — một quán luôn cùng một màu ở mọi biểu đồ.
/// CỐ Ý tránh lục/xanh dương/vàng vì ba màu đó dành cho Tiền mặt/Chuyển khoản/Thẻ ở mục thanh toán.
const kStorePalette = <Color>[
  Color(0xFFFF6B35), // cam
  Color(0xFF7B1FA2), // tím
  Color(0xFFD81B60), // hồng
  Color(0xFF00838F), // lam ngọc
  Color(0xFF6D4C41), // nâu
  Color(0xFF546E7A), // xám lam
  Color(0xFF4527A0), // chàm
  Color(0xFFAD1457), // mận
];
Color storeColor(int i) => kStorePalette[i % kStorePalette.length];

/// 1.234.567 → "1,2 tr", 52.000 → "52 k". Dùng cho trục biểu đồ và nhãn gọn.
String shortMoney(double v) {
  final a = v.abs();
  String f(double x) => x.toStringAsFixed(x >= 100 || x == x.roundToDouble() ? 0 : 1).replaceAll('.', ',');
  if (a >= 1e9) return '${f(v / 1e9)} tỷ';
  if (a >= 1e6) return '${f(v / 1e6)} tr';
  if (a >= 1e3) return '${f(v / 1e3)} k';
  return v.toStringAsFixed(0);
}

/// Báo cáo SO SÁNH các cửa hàng trong chuỗi cho Chủ quán. Chỉ đọc số tổng theo từng cửa hàng;
/// không có KPI cá nhân nhân viên xuyên chuỗi. Muốn xem chi tiết: chuyển sang cửa hàng đó rồi mở Báo cáo.
class ChainReportScreen extends StatefulWidget {
  final ChainRepository? repository;
  const ChainReportScreen({super.key, this.repository});

  @override
  State<ChainReportScreen> createState() => _ChainReportScreenState();
}

class _ChainReportScreenState extends State<ChainReportScreen> {
  late final ChainRepository _repo = widget.repository ?? ChainRepository();
  MyChains _mine = const MyChains();
  String? _chainId;
  ChainPeriod _period = ChainPeriod.day;
  int _offset = 0;
  CompareMetric _metric = CompareMetric.revenue;
  ChainReport? _report;
  ChainReport? _prev; // null = không có/không lấy được kỳ trước → ẩn tăng trưởng, không báo sai
  PeriodWindow? _window;
  bool _loading = true;
  String? _error;
  int _seq = 0; // bỏ kết quả của lần tải cũ khi người dùng đổi kỳ/chuỗi nhanh

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final mine = await _repo.listMine();
      if (!mounted) return;
      _mine = mine;
      if (_chainId == null || !mine.chains.any((c) => c.id == _chainId)) {
        _chainId = mine.chains.isEmpty ? null : mine.chains.first.id;
      }
      await _loadReport();
    } on ChainException catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Không tải được dữ liệu. Kiểm tra kết nối rồi thử lại.'; });
    }
  }

  Future<void> _loadReport() async {
    final id = _chainId;
    if (id == null) {
      if (mounted) setState(() { _report = null; _prev = null; _loading = false; });
      return;
    }
    final seq = ++_seq;
    final w = windowFor(_period, _offset);
    setState(() { _loading = true; _error = null; _window = w; });
    try {
      // Kỳ trước tải song song; lỗi riêng kỳ trước không làm hỏng báo cáo chính.
      final prevFuture = w.compareTo.isAfter(w.compareFrom)
          ? _repo.report(id, w.compareFrom, w.compareTo).then<ChainReport?>((r) => r).catchError((_) => null)
          : Future<ChainReport?>.value(null);
      final cur = await _repo.report(id, w.from, w.to);
      final prev = await prevFuture;
      if (!mounted || seq != _seq) return;
      setState(() { _report = cur; _prev = prev; _loading = false; });
    } on ChainException catch (e) {
      if (mounted && seq == _seq) setState(() { _loading = false; _error = e.message; });
    } catch (_) {
      if (mounted && seq == _seq) setState(() { _loading = false; _error = 'Không tải được báo cáo. Thử lại sau.'; });
    }
  }

  void _setPeriod(ChainPeriod p) {
    if (p == _period) return;
    HapticFeedback.selectionClick();
    setState(() { _period = p; _offset = 0; _report = null; _prev = null; });
    _loadReport();
  }

  void _shift(int delta) {
    final next = _offset + delta;
    if (next > 0) return;
    HapticFeedback.lightImpact();
    setState(() { _offset = next; _report = null; _prev = null; });
    _loadReport();
  }

  Future<void> _openManage() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => ChainManageSheet(repo: _repo, mine: _mine, chainId: _chainId),
    );
    if (mounted) _loadAll();
  }

  StoreChain? get _chain {
    for (final c in _mine.chains) {
      if (c.id == _chainId) return c;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasChain = _mine.chains.isNotEmpty;
    return Scaffold(
      backgroundColor: _kBg,
      body: RefreshIndicator(
        color: _kNavy,
        onRefresh: _loadAll,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                child: hasChain ? _body() : _noChain(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header navy: giống module Báo cáo (tiêu đề, 2 thẻ hero kem, hàng chỉ số nhỏ) ──
  Widget _header() {
    final r = _report;
    final p = _prev;
    final t = r?.totals;
    final w = _window;
    // Không hiện chip khi cả chuỗi chưa có đơn nào ("Mới" trên số 0 gây hiểu nhầm).
    final tot = (r != null && p != null && w != null && r.totals.orders > 0) ? analyzeChainTotals(analyzeStores(buildRows(r, p), r, p, w), p) : null;
    final show = r != null;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [_kNavy, _kNavyL], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 0),
            child: Row(children: [
              IconButton(
                tooltip: 'Quay lại',
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Báo cáo chuỗi',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.3)),
                  if (_chain != null) _chainName(),
                ]),
              ),
              IconButton(
                tooltip: 'Quản lý chuỗi',
                icon: const Icon(Icons.storefront_outlined, color: Colors.white54, size: 22),
                onPressed: _loading && _mine.chains.isEmpty && _error == null ? null : _openManage,
              ),
              IconButton(
                tooltip: 'Tải lại',
                icon: Icon(_loading ? Icons.hourglass_empty_rounded : Icons.refresh_rounded, color: Colors.white54, size: 22),
                onPressed: _loadAll,
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(children: [
              _HeroCard(
                label: 'Doanh thu chuỗi',
                value: show ? fmtVnd(t!.revenue) : '—',
                sub: show ? '${r.storeCount} cửa hàng' : 'Đang tải…',
                change: tot?.revenue,
                note: _excludedNote(tot?.excludedNames),
                compareLabel: w?.compareLabel,
                accent: _kOrange,
              ),
              const SizedBox(width: 10),
              _HeroCard(
                label: 'Số đơn',
                value: show ? '${t!.orders}' : '—',
                sub: show ? 'đơn hoàn tất' : '',
                change: tot?.orders,
                note: _excludedNote(tot?.excludedNames),
                compareLabel: w?.compareLabel,
                accent: const Color(0xFF69F0AE),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Row(children: [
              _SmallStat(label: 'TB/đơn', value: show ? fmtVnd(t!.avgOrderValue) : '—', color: const Color(0xFFFFD54F)),
              _vDivider(),
              _SmallStat(label: 'Tiền mặt', value: show ? shortMoney(t!.cashRevenue) : '—', color: const Color(0xFF69F0AE)),
              _vDivider(),
              _SmallStat(label: 'Chuyển khoản', value: show ? shortMoney(t!.transferRevenue) : '—', color: const Color(0xFF80D8FF)),
              _vDivider(),
              _SmallStat(label: 'Giảm giá', value: show ? shortMoney(t!.discount) : '—', color: const Color(0xFFFF6B6B)),
            ]),
          ),
        ]),
      ),
    );
  }

  static String? _excludedNote(List<String>? names) =>
      (names == null || names.isEmpty) ? null : 'Chưa tính quán mới (chưa đủ lịch sử để so sánh): ${names.join(', ')}.';

  Widget _chainName() {
    final name = _chain!.name;
    if (_mine.chains.length < 2) {
      return Text(name, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w500));
    }
    return PopupMenuButton<String>(
      tooltip: 'Chọn chuỗi',
      padding: EdgeInsets.zero,
      onSelected: (v) {
        if (v == _chainId) return;
        setState(() { _chainId = v; _report = null; _prev = null; });
        _loadReport();
      },
      itemBuilder: (_) => [for (final c in _mine.chains) PopupMenuItem(value: c.id, child: Text(c.name))],
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(name, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w700)),
        Icon(Icons.arrow_drop_down_rounded, color: Colors.white.withValues(alpha: 0.7), size: 18),
      ]),
    );
  }

  Widget _noChain() {
    if (_loading) return const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator(color: _kNavy)));
    if (_error != null) {
      return _Message(icon: Icons.error_outline, text: _error!, action: 'Thử lại', onAction: _loadAll);
    }
    final n = _mine.ownedStores.length;
    return _Message(
      icon: Icons.storefront_outlined,
      text: n >= 2
          ? 'Bạn có $n cửa hàng. Tạo một chuỗi để so sánh số liệu các chi nhánh.'
          : 'Bạn cần là Chủ của từ 2 cửa hàng trở lên để lập chuỗi và so sánh.',
      action: n >= 2 ? 'Tạo chuỗi' : null,
      onAction: _openManage,
    );
  }

  Widget _body() {
    final r = _report;
    final w = _window;
    final children = <Widget>[
      _PeriodPills(current: _period, onChanged: _setPeriod),
      const SizedBox(height: 10),
      _PeriodNav(label: w?.label ?? '…', canGoNext: _offset < 0, onPrev: () => _shift(-1), onNext: () => _shift(1)),
      const SizedBox(height: 14),
    ];
    if (_error != null) children.add(_Banner(text: _error!, color: _kRed));

    if (r == null) {
      if (_loading) children.add(const _LoadingCard());
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    if (r.excluded.isNotEmpty) {
      children.add(_Banner(
        text: 'Không hiển thị: ${r.excluded.map((s) => s.name).join(', ')} (bạn không còn là Chủ của cửa hàng này).',
        color: Colors.orange.shade800,
      ));
    }

    if (r.stores.isEmpty) {
      children.add(const _EmptyState(icon: Icons.storefront_outlined, message: 'Chuỗi chưa có cửa hàng nào. Bấm biểu tượng cửa hàng ở trên để thêm.'));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    if (r.totals.orders == 0) {
      children.add(const _EmptyState(icon: Icons.bar_chart_rounded, message: 'Chưa có đơn hoàn tất trong kỳ này'));
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    }

    final rows = buildRows(r, _prev);
    final win = w ?? windowFor(_period, _offset);
    final analyses = {for (final a in analyzeStores(rows, r, _prev, win)) a.id: a};
    final insights = buildInsights(rows, r, _prev, win);
    final trend = w == null ? null : buildDailyTrend(r, w.from, w.to, now: DateTime.now());

    if (insights.isNotEmpty) children..add(_InsightsCard(items: insights))..add(const SizedBox(height: 14));
    children
      ..add(_RankingCard(rows: sortedBy(rows, CompareMetric.revenue), total: r.totals.revenue, hasPrev: _prev != null, analyses: analyses, compareLabel: win.compareLabel))
      ..add(const SizedBox(height: 14))
      ..add(_MetricCompareCard(
        rows: rows,
        report: r,
        metric: _metric,
        onMetric: (m) => setState(() => _metric = m),
        newIds: {for (final a in analyses.values) if (a.isNew) a.id},
      ))
      ..add(const SizedBox(height: 14))
      ..add(_PaymentMixCard(rows: sortedBy(rows, CompareMetric.revenue)));
    if (trend != null && trend.dates.length >= 2 && trend.maxValue > 0) {
      children
        ..add(const SizedBox(height: 14))
        ..add(_TrendCard(trend: trend, rows: sortedBy(rows, CompareMetric.revenue)));
    }
    children
      ..add(const SizedBox(height: 14))
      ..add(Text(
        'Chỉ gồm đơn đã hoàn tất. Số liệu từng cửa hàng tách riêng; chi tiết nhân viên/kho xem trong báo cáo của cửa hàng đó.\n'
        'So với ${win.compareLabel}${win.compareIsPartial ? ' — cùng khoảng thời gian đã trôi qua, không so nửa kỳ với cả kỳ' : ''}. '
        'Chip chỉ tô xanh/đỏ khi thay đổi vượt mức dao động thường ngày (đã quy đổi theo ngày có bán); chạm vào chip để xem lý do.',
        style: const TextStyle(color: _kMuted, fontSize: 11.5, height: 1.4),
      ));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// HEADER WIDGETS (cùng kiểu _HeroCard / _SmallStat của Báo cáo)
// ═══════════════════════════════════════════════════════════════════════════════
class _HeroCard extends StatelessWidget {
  final String label, value, sub;
  final MetricChange? change; // null = chưa có kỳ so sánh → ẩn chip
  final String? compareLabel;
  final String? note; // ghi chú thêm vào lời giải thích (vd: quán mới không được tính)
  final Color accent;
  const _HeroCard({required this.label, required this.value, required this.sub, required this.change, required this.compareLabel, required this.accent, this.note});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8DDD4)),
        boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.13), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: accent, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: _kNavy.withValues(alpha: 0.5), fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: _kNavy.withValues(alpha: 0.88), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ),
        const SizedBox(height: 5),
        Row(children: [
          Flexible(child: Text(sub, overflow: TextOverflow.ellipsis, style: TextStyle(color: _kNavy.withValues(alpha: 0.4), fontSize: 10, fontWeight: FontWeight.w600))),
          if (change != null) ...[const SizedBox(width: 6), _GrowthChip(change: change, compareLabel: compareLabel, note: note, noBaseLabel: 'Chưa so sánh', compact: true)],
        ]),
      ]),
    ),
  );
}

class _SmallStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SmallStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w500)),
      const SizedBox(height: 3),
      FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: -0.3))),
    ]),
  );
}

Widget _vDivider() => Container(width: 1, height: 28, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white.withValues(alpha: 0.12));

/// Chip tăng/giảm. CHỈ tô xanh/đỏ khi thay đổi vượt mức dao động bình thường; còn lại màu xám.
/// Số hiển thị là thay đổi của TỔNG; màu quyết định bởi so sánh bình quân mỗi ngày CÓ BÁN (xem chạm để biết lý do).
class _GrowthChip extends StatelessWidget {
  final MetricChange? change;
  final String? compareLabel;
  final int? activeDays;
  final int? compareActiveDays;
  final String? note;
  final String noBaseLabel; // "Mới" cho từng quán; "Chưa so sánh" cho thẻ tổng chuỗi
  final bool compact;
  const _GrowthChip({required this.change, this.compareLabel, this.activeDays, this.compareActiveDays, this.note, this.noBaseLabel = 'Mới', this.compact = false});

  static String explain(MetricChange c, String? label, int? ac, int? ap) {
    final vs = label ?? 'kỳ trước';
    switch (c.verdict) {
      case Verdict.insufficient:
        return 'Chưa đủ số đơn để so sánh với $vs (cần từ ${InsightConfig.minOrdersPerSide} đơn mỗi bên).';
      case Verdict.newStore:
        return 'Quán mới bắt đầu bán, chưa đủ lịch sử để so sánh với $vs.';
      case Verdict.noBase:
        return 'Không có số liệu $vs để so sánh.';
      case Verdict.noise:
      case Verdict.up:
      case Verdict.down:
        final b = StringBuffer();
        b.write(c.verdict == Verdict.noise
            ? 'Nằm trong mức dao động bình thường (±${c.band.toStringAsFixed(1).replaceAll('.', ',')}%) so với $vs.'
            : '${c.verdict == Verdict.up ? 'Tăng' : 'Giảm'} vượt mức dao động bình thường (±${c.band.toStringAsFixed(1).replaceAll('.', ',')}%) so với $vs.');
        if (c.perDayPct != null && c.rawPct != null && (c.perDayPct! - c.rawPct!).abs() >= 1) {
          b.write(' Bình quân mỗi ngày có bán: ${fmtPct(c.perDayPct!, signed: true)}');
          if (ac != null && ap != null) b.write(' (kỳ này $ac ngày bán, $vs $ap ngày).');
        }
        return b.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = change;
    if (c == null) return const SizedBox.shrink();
    Color color = _kMuted;
    String text;
    IconData? icon;
    switch (c.verdict) {
      case Verdict.insufficient:
        text = 'Ít dữ liệu';
      case Verdict.newStore:
        text = 'Quán mới';
      case Verdict.noBase:
        text = noBaseLabel;
      case Verdict.noise:
      case Verdict.up:
      case Verdict.down:
        final g = c.rawPct ?? 0;
        text = fmtPct(g);
        icon = g.abs() < 0.05 ? Icons.remove_rounded : (g > 0 ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded);
        if (c.verdict == Verdict.up) color = _kGreen;
        if (c.verdict == Verdict.down) color = _kRed;
    }
    final chip = Container(
      padding: EdgeInsets.fromLTRB(icon == null ? 7 : 2, 1, 7, 1),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) Icon(icon, size: compact ? 16 : 18, color: color),
        Text(text, style: TextStyle(color: color, fontSize: compact ? 10.5 : 11.5, fontWeight: FontWeight.w800)),
      ]),
    );
    return Tooltip(
      message: '${explain(c, compareLabel, activeDays, compareActiveDays)}${note == null ? '' : ' $note'}',
      triggerMode: TooltipTriggerMode.tap,
      showDuration: const Duration(seconds: 6),
      child: chip,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CHỌN KỲ (giống _PeriodPills + _ReportNavBar của Báo cáo)
// ═══════════════════════════════════════════════════════════════════════════════
class _PeriodPills extends StatelessWidget {
  final ChainPeriod current;
  final ValueChanged<ChainPeriod> onChanged;
  const _PeriodPills({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      for (final p in ChainPeriod.values)
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                color: current == p ? _kNavy : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: current == p ? [BoxShadow(color: _kNavy.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2))] : null,
              ),
              child: Text(p.label, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: current == p ? Colors.white : _kMuted)),
            ),
          ),
        ),
    ]),
  );
}

class _PeriodNav extends StatelessWidget {
  final String label;
  final bool canGoNext;
  final VoidCallback onPrev, onNext;
  const _PeriodNav({required this.label, required this.canGoNext, required this.onPrev, required this.onNext});

  Widget _btn(IconData icon, VoidCallback? onTap, String tip) {
    final on = onTap != null;
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: on ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: on ? [BoxShadow(color: _kNavy.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))] : null,
          ),
          child: Icon(icon, size: 20, color: on ? _kNavy : _kMuted.withValues(alpha: 0.3)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [_kNavy.withValues(alpha: 0.07), _kNavy.withValues(alpha: 0.04)]),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _kNavy.withValues(alpha: 0.12)),
    ),
    child: Row(children: [
      _btn(Icons.chevron_left_rounded, onPrev, 'Kỳ trước'),
      Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _kNavy, letterSpacing: -0.2))),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(5)),
            child: const Icon(Icons.calendar_month_rounded, size: 11, color: _kNavy),
          ),
        ]),
      ),
      _btn(Icons.chevron_right_rounded, canGoNext ? onNext : null, 'Kỳ sau'),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
// KHUNG THẺ + TIÊU ĐỀ MỤC (giống _SectionHeader / _SummaryCard)
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  const _SectionHeader({required this.icon, required this.color, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 17, color: color)),
    const SizedBox(width: 10),
    Flexible(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color, letterSpacing: -0.2))),
  ]);
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: child,
  );
}

// ── Nhận xét nhanh ──────────────────────────────────────────────────────────
class _InsightsCard extends StatelessWidget {
  final List<ChainInsight> items;
  const _InsightsCard({required this.items});

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader(icon: Icons.lightbulb_outline_rounded, color: _kGold, title: 'Nhận xét nhanh'),
      const SizedBox(height: 10),
      for (final i in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: switch (i.kind) { InsightKind.good => const Color(0xFFE8F5E9), InsightKind.warn => const Color(0xFFFFEBEE), InsightKind.info => _kBg },
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: switch (i.kind) { InsightKind.good => const Color(0xFF81C784), InsightKind.warn => const Color(0xFFEF9A9A), InsightKind.info => const Color(0xFFE8E2DA) }),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(
                switch (i.kind) { InsightKind.good => Icons.trending_up_rounded, InsightKind.warn => Icons.warning_amber_rounded, InsightKind.info => Icons.info_outline_rounded },
                size: 18,
                color: switch (i.kind) { InsightKind.good => _kGreen, InsightKind.warn => _kRed, InsightKind.info => _kNavy },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(i.text, style: const TextStyle(fontSize: 12.5, color: _kInk, fontWeight: FontWeight.w600, height: 1.3)),
                  if (i.detail != null) ...[
                    const SizedBox(height: 3),
                    Text(i.detail!, style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500, height: 1.3)),
                  ],
                ]),
              ),
            ]),
          ),
        ),
    ]),
  );
}

// ── Xếp hạng doanh thu ──────────────────────────────────────────────────────
class _RankingCard extends StatelessWidget {
  final List<StoreRow> rows; // đã sắp giảm dần theo doanh thu
  final double total;
  final bool hasPrev;
  final Map<String, StoreAnalysis> analyses;
  final String compareLabel;
  const _RankingCard({required this.rows, required this.total, required this.hasPrev, required this.analyses, required this.compareLabel});

  Color _rankColor(int i) => switch (i) { 0 => const Color(0xFFF9A825), 1 => const Color(0xFF90A4AE), 2 => const Color(0xFFA1887F), _ => _kMuted.withValues(alpha: 0.5) };

  @override
  Widget build(BuildContext context) {
    final maxRev = rows.fold<double>(0, (m, r) => math.max(m, r.cur.revenue));
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(icon: Icons.emoji_events_rounded, color: _kNavy, title: 'Xếp hạng doanh thu'),
        const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Color(0xFFE8E2DA))),
          _rankRow(i, rows[i], maxRev),
        ],
      ]),
    );
  }

  Widget _rankRow(int i, StoreRow r, double maxRev) {
    final c = storeColor(r.colorIndex);
    final frac = maxRev > 0 ? (r.cur.revenue / maxRev).clamp(0.0, 1.0) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _rankColor(i), shape: BoxShape.circle),
          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(width: 10),
        Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _kInk))),
        Text(fmtVnd(r.cur.revenue), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: _kNavy)),
      ]),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: LinearProgressIndicator(value: frac, minHeight: 8, backgroundColor: _kBg, color: c),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: Text(
            '${r.cur.orders} đơn · TB ${shortMoney(r.cur.avgOrderValue)} · chiếm ${fmtPct(r.sharePct(total))}',
            style: const TextStyle(fontSize: 11.5, color: _kMuted, fontWeight: FontWeight.w600),
          ),
        ),
        if (hasPrev && analyses[r.id] != null)
          _GrowthChip(
            change: analyses[r.id]!.revenue,
            compareLabel: compareLabel,
            activeDays: analyses[r.id]!.activeDays,
            compareActiveDays: analyses[r.id]!.compareActiveDays,
          ),
      ]),
    ]);
  }
}

// ── So sánh theo chỉ số ─────────────────────────────────────────────────────
class _MetricCompareCard extends StatelessWidget {
  final List<StoreRow> rows;
  final ChainReport report;
  final CompareMetric metric;
  final ValueChanged<CompareMetric> onMetric;
  final Set<String> newIds; // quán mới mở: không tham gia xếp "Cao nhất/Thấp nhất" (chưa bán đủ kỳ)
  const _MetricCompareCard({required this.rows, required this.report, required this.metric, required this.onMetric, this.newIds = const {}});

  String _fmtValue(double v) => metric.isMoney ? fmtVnd(v) : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final sorted = sortedBy(rows, metric);
    final maxV = sorted.isEmpty ? 0.0 : metricValue(sorted.first.cur, metric);
    final avg = chainAverage(report, metric);
    final elig = sorted.where((r) => !newIds.contains(r.id)).toList();
    final hiV = elig.isEmpty ? 0.0 : metricValue(elig.first.cur, metric);
    final loV = elig.isEmpty ? 0.0 : metricValue(elig.last.cur, metric);
    final canTag = metric.higherIsBetter && elig.length >= 2 && hiV > 0 && hiV > loV;
    String? tagFor(StoreRow r) {
      if (newIds.contains(r.id)) return 'Mới mở';
      if (!canTag) return null;
      if (r.id == elig.first.id) return 'Cao nhất';
      if (r.id == elig.last.id) return 'Thấp nhất';
      return null;
    }
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _SectionHeader(icon: Icons.compare_arrows_rounded, color: _kOrange, title: 'So sánh theo chỉ số'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in CompareMetric.values)
            GestureDetector(
              onTap: () => onMetric(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                decoration: BoxDecoration(
                  color: m == metric ? _kNavy : _kNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(m.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: m == metric ? Colors.white : _kMuted)),
              ),
            ),
        ]),
        const SizedBox(height: 14),
        for (final r in sorted) _bar(r, maxV, avg, tagFor(r)),
        const SizedBox(height: 4),
        Row(children: [
          Container(width: 2, height: 12, color: _kNavy.withValues(alpha: 0.55)),
          const SizedBox(width: 6),
          Text('Trung bình chuỗi: ${_fmtValue(avg)}', style: const TextStyle(fontSize: 11.5, color: _kMuted, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }

  Widget _bar(StoreRow r, double maxV, double avg, String? tag) {
    final v = metricValue(r.cur, metric);
    final c = storeColor(r.colorIndex);
    final frac = maxV > 0 ? (v / maxV).clamp(0.0, 1.0) : 0.0;
    final avgFrac = maxV > 0 ? (avg / maxV).clamp(0.0, 1.0) : 0.0;
    final tagColor = tag == 'Cao nhất' ? _kGreen : (tag == 'Thấp nhất' ? _kRed : _kMuted);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk))),
          if (tag != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(color: tagColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
              child: Text(tag, style: TextStyle(fontSize: 10, color: tagColor, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 8),
          ],
          Text(_fmtValue(v), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _kNavy)),
        ]),
        const SizedBox(height: 6),
        LayoutBuilder(builder: (context, cs) {
          final w = cs.maxWidth;
          return SizedBox(
            height: 12,
            child: Stack(clipBehavior: Clip.none, children: [
              Container(width: w, height: 12, decoration: BoxDecoration(color: _kBg, borderRadius: BorderRadius.circular(6))),
              AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                width: w * frac,
                height: 12,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6)),
              ),
              if (avg > 0) Positioned(left: (w * avgFrac - 1).clamp(0, w - 2), top: -2, child: Container(width: 2, height: 16, color: _kNavy.withValues(alpha: 0.55))),
            ]),
          );
        }),
      ]),
    );
  }
}

// ── Cơ cấu thanh toán (cột chồng 100%) ──────────────────────────────────────
class _PaymentMixCard extends StatelessWidget {
  final List<StoreRow> rows;
  const _PaymentMixCard({required this.rows});

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader(icon: Icons.payments_rounded, color: _kGreen, title: 'Cơ cấu thanh toán'),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 4, children: [
        const _LegendDot(color: _kGreen, label: 'Tiền mặt'),
        const _LegendDot(color: _kBlue, label: 'Chuyển khoản'),
        const _LegendDot(color: _kGold, label: 'Thẻ'),
        if (rows.any((r) => _other(r.cur) > 0)) const _LegendDot(color: _kOther, label: 'Ví/khác'),
      ]),
      const SizedBox(height: 12),
      for (final r in rows) _mix(r),
    ]),
  );

  /// Phần doanh thu không thuộc tiền mặt/chuyển khoản/thẻ (ví...). Bỏ qua sai lệch làm tròn < 0,5% doanh thu.
  static double _other(StoreMetrics m) {
    final o = m.revenue - m.cashRevenue - m.transferRevenue - m.cardRevenue;
    return o > m.revenue * 0.005 ? o : 0;
  }

  Widget _mix(StoreRow r) {
    final m = r.cur;
    final other = _other(m);
    final sum = m.cashRevenue + m.transferRevenue + m.cardRevenue + other;
    Widget seg(double v, Color c) {
      final pct = sum > 0 ? v / sum * 100 : 0.0;
      if (v <= 0) return const SizedBox.shrink();
      return Expanded(
        flex: math.max(1, (v / sum * 1000).round()),
        child: Container(
          height: 22,
          alignment: Alignment.center,
          color: c,
          child: pct >= 14 ? Text('${pct.round()}%', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)) : null,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(color: storeColor(r.colorIndex), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Expanded(child: Text(r.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kInk))),
          Text(shortMoney(sum), style: const TextStyle(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: sum > 0
              ? Row(children: [seg(m.cashRevenue, _kGreen), seg(m.transferRevenue, _kBlue), seg(m.cardRevenue, _kGold), seg(other, _kOther)])
              : Container(height: 22, color: _kBg, alignment: Alignment.center, child: const Text('Chưa có thanh toán', style: TextStyle(fontSize: 10.5, color: _kMuted))),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 11.5, color: _kMuted, fontWeight: FontWeight.w600)),
  ]);
}

// ── Xu hướng doanh thu theo ngày (mỗi quán một đường) ───────────────────────
class _TrendCard extends StatelessWidget {
  final DailyTrend trend;
  final List<StoreRow> rows;
  const _TrendCard({required this.trend, required this.rows});

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const _SectionHeader(icon: Icons.show_chart_rounded, color: _kNavy, title: 'Xu hướng doanh thu theo ngày'),
      const SizedBox(height: 10),
      Wrap(spacing: 14, runSpacing: 4, children: [
        for (final r in rows) _LegendDot(color: storeColor(r.colorIndex), label: r.name),
      ]),
      const SizedBox(height: 12),
      SizedBox(
        height: 170,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrendPainter(
            trend: trend,
            series: [for (final r in rows) (storeColor(r.colorIndex), trend.byStore[r.id] ?? const <double>[])],
          ),
        ),
      ),
    ]),
  );
}

class _TrendPainter extends CustomPainter {
  final DailyTrend trend;
  final List<(Color, List<double>)> series;
  _TrendPainter({required this.trend, required this.series});

  static const double _left = 44, _bottom = 20, _top = 8, _right = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTWH(_left, _top, size.width - _left - _right, size.height - _top - _bottom);
    final maxV = trend.maxValue <= 0 ? 1.0 : trend.maxValue;
    final n = trend.dates.length;
    final grid = Paint()..color = const Color(0xFFE8E2DA)..strokeWidth = 1;

    void label(String text, Offset at, {TextAlign align = TextAlign.right}) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 10, color: _kMuted, fontWeight: FontWeight.w600)),
        textDirection: TextDirection.ltr,
        textAlign: align,
      )..layout();
      final dx = align == TextAlign.right ? at.dx - tp.width : (align == TextAlign.center ? at.dx - tp.width / 2 : at.dx);
      tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
    }

    for (var i = 0; i <= 3; i++) {
      final y = plot.bottom - plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      label(shortMoney(maxV * i / 3), Offset(plot.left - 6, y));
    }
    double x(int i) => n == 1 ? plot.center.dx : plot.left + plot.width * i / (n - 1);
    double y(double v) => plot.bottom - plot.height * (v / maxV).clamp(0.0, 1.0);

    String dm(String s) => '${s.substring(8, 10)}/${s.substring(5, 7)}';
    label(dm(trend.dates.first), Offset(plot.left, plot.bottom + 11), align: TextAlign.left);
    label(dm(trend.dates.last), Offset(plot.right, plot.bottom + 11));
    if (n > 4) label(dm(trend.dates[n ~/ 2]), Offset(x(n ~/ 2), plot.bottom + 11), align: TextAlign.center);

    for (final (color, values) in series) {
      if (values.length != n) continue;
      final path = Path();
      for (var i = 0; i < n; i++) {
        final p = Offset(x(i), y(values[i]));
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2.4..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);
      if (n <= 14) {
        for (var i = 0; i < n; i++) {
          canvas.drawCircle(Offset(x(i), y(values[i])), 3.2, Paint()..color = Colors.white);
          canvas.drawCircle(Offset(x(i), y(values[i])), 3.2, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1.8);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) => old.trend != trend || old.series != series;
}

// ═══════════════════════════════════════════════════════════════════════════════
// TRẠNG THÁI CHUNG (giống _LoadingCard / _EmptyState của Báo cáo)
// ═══════════════════════════════════════════════════════════════════════════════
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => Container(
    height: 140,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: _kNavy.withValues(alpha: 0.05), blurRadius: 10)]),
    child: const CircularProgressIndicator(color: _kNavy, strokeWidth: 2.5),
  );
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(children: [
      Container(width: 72, height: 72, decoration: BoxDecoration(color: _kCard, borderRadius: BorderRadius.circular(20)), child: Icon(icon, size: 36, color: _kMuted.withValues(alpha: 0.4))),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center, style: TextStyle(color: _kMuted.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const _Message({required this.icon, required this.text, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(children: [
      Icon(icon, size: 48, color: _kMuted),
      const SizedBox(height: 12),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, color: _kInk)),
      if (action != null) ...[
        const SizedBox(height: 16),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: _kOrange), onPressed: onAction, child: Text(action!)),
      ],
    ]),
  );
}

class _Banner extends StatelessWidget {
  final String text;
  final Color color;
  const _Banner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
    child: Text(text, style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
  );
}
