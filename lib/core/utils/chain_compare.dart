import '../repositories/chain_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAIN COMPARE — logic thuần (không UI, không mạng) cho báo cáo so sánh các cửa hàng.
// Quy ước số liệu khớp server: chỉ đơn completed; từng cửa hàng tách riêng, chuỗi chỉ là tổng hợp.
// ─────────────────────────────────────────────────────────────────────────────

// ── Kỳ báo cáo ──────────────────────────────────────────────────────────────
enum ChainPeriod { day, week, month }

extension ChainPeriodX on ChainPeriod {
  String get label => switch (this) {
    ChainPeriod.day => 'Hôm nay',
    ChainPeriod.week => 'Tuần này',
    ChainPeriod.month => 'Tháng này',
  };
}

class PeriodWindow {
  final DateTime from;
  final DateTime to; // loại trừ
  final String label;
  final bool canGoNext;

  /// Khoảng so sánh "cùng kỳ trước". Với kỳ ĐANG DIỄN RA (offset 0) chỉ lấy phần đã trôi qua tương ứng,
  /// để không so nửa ngày/nửa tuần với cả ngày/cả tuần trước (sẽ luôn trông như sụt giảm).
  final DateTime compareFrom;
  final DateTime compareTo;
  final bool compareIsPartial;

  /// Tên khoảng so sánh để hiển thị: "cùng thứ tuần trước" / "tuần trước" / "tháng trước".
  final String compareLabel;

  const PeriodWindow({
    required this.from,
    required this.to,
    required this.label,
    required this.canGoNext,
    required this.compareFrom,
    required this.compareTo,
    required this.compareIsPartial,
    required this.compareLabel,
  });
}

DateTime _mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - 1));
String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// [offset] ≤ 0: 0 = kỳ hiện tại, -1 = kỳ trước…
PeriodWindow windowFor(ChainPeriod p, int offset, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final off = offset > 0 ? 0 : offset;
  (DateTime, DateTime) range(int o) {
    switch (p) {
      case ChainPeriod.day:
        final d = DateTime(n.year, n.month, n.day + o);
        return (d, DateTime(d.year, d.month, d.day + 1));
      case ChainPeriod.week:
        final m = _mondayOf(DateTime(n.year, n.month, n.day + 7 * o));
        return (m, DateTime(m.year, m.month, m.day + 7));
      case ChainPeriod.month:
        final f = DateTime(n.year, n.month + o, 1);
        return (f, DateTime(f.year, f.month + 1, 1));
    }
  }

  final (from, to) = range(off);
  // F&B có nhịp theo thứ rất mạnh (cuối tuần bán nhiều hơn ngày thường ~40% ở quán chính), nên ngày được so với
  // CÙNG THỨ tuần trước, không so với hôm qua. Tuần/tháng so với kỳ liền trước.
  final (pFrom, pTo) = range(p == ChainPeriod.day ? off - 7 : off - 1);

  String label;
  switch (p) {
    case ChainPeriod.day:
      label = off == 0
          ? 'Hôm nay'
          : off == -1
          ? 'Hôm qua'
          : '${_dm(from)}/${from.year}';
    case ChainPeriod.week:
      label = off == 0
          ? 'Tuần này · ${_dm(from)}–${_dm(DateTime(to.year, to.month, to.day - 1))}'
          : '${_dm(from)}–${_dm(DateTime(to.year, to.month, to.day - 1))}';
    case ChainPeriod.month:
      label = 'Tháng ${from.month} / ${from.year}';
  }

  var cTo = pTo;
  var partial = false;
  if (off == 0) {
    final elapsed = n.difference(from);
    final cap = pFrom.add(elapsed);
    if (cap.isBefore(pTo)) {
      cTo = cap;
      partial = true;
    }
  }
  return PeriodWindow(
    from: from,
    to: to,
    label: label,
    canGoNext: off < 0,
    compareFrom: pFrom,
    compareTo: cTo,
    compareIsPartial: partial,
    compareLabel: switch (p) {
      ChainPeriod.day => 'cùng thứ tuần trước',
      ChainPeriod.week => 'tuần trước',
      ChainPeriod.month => 'tháng trước',
    },
  );
}

// ── Chỉ số ──────────────────────────────────────────────────────────────────
enum CompareMetric { revenue, orders, avgOrder, discount }

extension CompareMetricX on CompareMetric {
  String get label => switch (this) {
    CompareMetric.revenue => 'Doanh thu',
    CompareMetric.orders => 'Số đơn',
    CompareMetric.avgOrder => 'TB/đơn',
    CompareMetric.discount => 'Giảm giá',
  };

  /// Giảm giá: thấp hơn không có nghĩa là "tốt hơn" tuyệt đối, nên không gán nhãn tốt/kém.
  bool get higherIsBetter => this != CompareMetric.discount;

  bool get isMoney => this != CompareMetric.orders;
}

double metricValue(StoreMetrics m, CompareMetric k) => switch (k) {
  CompareMetric.revenue => m.revenue,
  CompareMetric.orders => m.orders.toDouble(),
  CompareMetric.avgOrder => m.avgOrderValue,
  CompareMetric.discount => m.discount,
};

/// % thay đổi so với kỳ trước. null khi kỳ trước = 0 (không có gốc để so, UI hiện "mới").
double? growthPct(double cur, double prev) {
  if (prev <= 0) return null;
  return (cur - prev) / prev * 100;
}

String fmtPct(double v, {bool signed = false}) {
  final s = v.abs().toStringAsFixed(1).replaceAll('.', ',');
  if (!signed) return '$s%';
  return '${v >= 0 ? '+' : '-'}$s%';
}

// ── Hàng so sánh của một cửa hàng ───────────────────────────────────────────
class StoreRow {
  final StoreMetrics cur;
  final StoreMetrics? prev;
  final int colorIndex; // ổn định giữa các kỳ để cùng một quán luôn cùng một màu
  const StoreRow({required this.cur, required this.prev, required this.colorIndex});

  String get id => cur.storeId;
  String get name => cur.name;

  double? growth(CompareMetric k) =>
      prev == null ? null : growthPct(metricValue(cur, k), metricValue(prev!, k));

  double sharePct(double chainRevenue) => chainRevenue > 0 ? cur.revenue / chainRevenue * 100 : 0;
}

/// Gán màu theo thứ tự (tên, id) để không đổi khi đổi kỳ hay đổi thứ hạng.
List<StoreRow> buildRows(ChainReport current, ChainReport? previous) {
  final prevById = {for (final s in previous?.stores ?? const <StoreMetrics>[]) s.storeId: s};
  final stable = [...current.stores]
    ..sort((a, b) {
      final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return c != 0 ? c : a.storeId.compareTo(b.storeId);
    });
  final idx = {for (var i = 0; i < stable.length; i++) stable[i].storeId: i};
  return [
    for (final s in current.stores)
      StoreRow(
        cur: s,
        // Nếu kỳ trước có báo cáo nhưng quán chưa có đơn nào, RPC vẫn trả hàng 0 → prev = 0 → growth null.
        prev: previous == null ? null : (prevById[s.storeId] ?? StoreMetrics(storeId: s.storeId, name: s.name)),
        colorIndex: idx[s.storeId]!,
      ),
  ];
}

List<StoreRow> sortedBy(List<StoreRow> rows, CompareMetric k) {
  final l = [...rows];
  l.sort((a, b) {
    final c = metricValue(b.cur, k).compareTo(metricValue(a.cur, k));
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return l;
}

/// Trung bình của chuỗi cho một chỉ số (tổng/số quán với doanh thu, đơn, giảm giá; TB/đơn tính theo tổng).
double chainAverage(ChainReport r, CompareMetric k) {
  final n = r.stores.length;
  if (n == 0) return 0;
  return switch (k) {
    CompareMetric.revenue => r.totals.revenue / n,
    CompareMetric.orders => r.totals.orders / n,
    CompareMetric.avgOrder => r.totals.avgOrderValue,
    CompareMetric.discount => r.totals.discount / n,
  };
}

// ── Xu hướng theo ngày ──────────────────────────────────────────────────────
class DailyTrend {
  final List<String> dates; // yyyy-MM-dd
  final Map<String, List<double>> byStore; // storeId -> doanh thu mỗi ngày (0 nếu không có đơn)
  const DailyTrend(this.dates, this.byStore);

  double get maxValue {
    var m = 0.0;
    for (final l in byStore.values) {
      for (final v in l) {
        if (v > m) m = v;
      }
    }
    return m;
  }
}

String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Điền 0 cho ngày không có đơn để đường biểu đồ không "nhảy cóc". Giới hạn 62 ngày.
/// [now]: nếu truyền, KHÔNG vẽ các ngày sau hôm nay (tuần/tháng đang diễn ra) — ngày chưa tới không phải "doanh thu 0".
DailyTrend buildDailyTrend(ChainReport r, DateTime from, DateTime to, {DateTime? now}) {
  final dates = <String>[];
  var d = DateTime(from.year, from.month, from.day);
  var end = DateTime(to.year, to.month, to.day);
  if (now != null) {
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (tomorrow.isBefore(end)) end = tomorrow;
  }
  while (d.isBefore(end) && dates.length < 62) {
    dates.add(ymd(d));
    d = DateTime(d.year, d.month, d.day + 1);
  }
  final pos = {for (var i = 0; i < dates.length; i++) dates[i]: i};
  final by = {for (final s in r.stores) s.storeId: List<double>.filled(dates.length, 0)};
  for (final p in r.daily) {
    final i = pos[p.date];
    final list = by[p.storeId];
    if (i != null && list != null) list[i] += p.revenue;
  }
  return DailyTrend(dates, by);
}
