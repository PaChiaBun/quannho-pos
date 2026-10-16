import 'dart:math' as math;

import '../repositories/chain_repository.dart';
import 'chain_compare.dart';
import 'money_formatter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAIN INSIGHTS — nhận xét tự động cho Chủ quán (logic thuần, không UI, không mạng).
//
// Nguyên tắc: CHỈ nói điều dữ liệu đủ chứng minh; thà im lặng hơn báo động giả.
//   1. Mọi % tăng/giảm phải vượt "mức dao động bình thường" (noise) mới được tô xanh/đỏ hay thành nhận xét.
//   2. So theo NGÀY CÓ BÁN, không theo tổng thô: tuần quán nghỉ 3 ngày không phải là "nhu cầu giảm 46%".
//   3. Mẫu quá ít → "ít dữ liệu", không kết luận.
//   4. Quán mới / kỳ trước không có gốc → không so.
//   5. Trường máy chủ chưa gửi (null) = "không rõ", bỏ qua quy tắc đó, KHÔNG coi là 0.
// ─────────────────────────────────────────────────────────────────────────────

/// Mọi ngưỡng ở một chỗ để chỉnh/giải trình. Nguồn đo: quán có nhiều đơn nhất hệ thống, đọc ngày 17/10/2026.
class InsightConfig {
  const InsightConfig._();

  /// |thay đổi| khi so MỘT ngày với CÙNG THỨ tuần trước, phân vị 80% (40 cặp ngày từ 07/09/2026):
  /// số đơn 26,2% · doanh thu 33,7%. (So với "hôm qua": doanh thu 53,3% — nhiễu hơn nhiều vì nhịp theo thứ.)
  static const double dayNoiseOrders = 0.26;
  static const double dayNoiseRevenue = 0.34;

  /// Dao động của tổng nhiều ngày giảm theo 1/√(số ngày có bán). Sàn để kỳ dài không nhạy quá mức.
  static const double floorOrders = 0.05;
  static const double floorRevenue = 0.06;

  /// Mỗi bên (kỳ này / kỳ so sánh) cần tối thiểu bấy nhiêu đơn mới dám kết luận tăng/giảm.
  static const int minOrdersPerSide = 15;

  /// Quán mọi tuần đều có đơn: "chưa có đơn" chỉ đáng báo khi cùng kỳ trước đã có ít nhất bấy nhiêu đơn.
  static const int silentExpectedOrders = 5;

  /// Chỉ xét giảm giá/hủy khi quán có tối thiểu bấy nhiêu đơn trong kỳ (tỷ lệ trên mẫu nhỏ vô nghĩa).
  static const int minOrdersForRates = 30;

  /// Đo tại quán chính 60 ngày: giảm giá 1,0–2,5% giá trị bán; hủy món/bàn 3,1% doanh thu (cao nhất tuần ~4,3%).
  static const double discountAlertRate = 0.04;
  static const double voidAlertRate = 0.05;
  static const double rateVsOthersFactor = 2.0; // giảm giá: ≥ 2× mức các quán khác
  static const double voidVsOthersFactor = 1.8; // hủy: ≥ 1,8× mức các quán khác

  /// Ngày bán có tỷ lệ tối thiểu ở kỳ so sánh thì mới coi ngày không có đơn của kỳ này là "bất thường".
  static const double closedDayPrevActiveRatio = 0.8;

  static const double ticketHighFactor = 1.15; // TB/đơn ≥ 115% trung bình chuỗi
  static const double ticketLowFactor = 0.80; // TB/đơn ≤ 80% trung bình chuỗi
  static const double concentrationShare = 0.70; // ≥ 70% doanh thu ở một quán (từ 3 quán có đơn)
  static const int maxInsights = 6;
}

// ── Đánh giá một thay đổi ───────────────────────────────────────────────────
enum Verdict {
  /// Mẫu quá ít (hoặc thiếu dữ liệu ngày) để kết luận.
  insufficient,

  /// Quán bắt đầu bán sau đầu kỳ so sánh: chưa đủ lịch sử.
  newStore,

  /// Không có gốc để so (kỳ so sánh = 0 đơn, hoặc không tải được kỳ so sánh).
  noBase,

  /// Thay đổi nằm trong mức dao động bình thường.
  noise,
  up,
  down,
}

enum ChangeDriver { volume, ticket, both }

class MetricChange {
  /// Thay đổi của TỔNG (cái chủ quán thấy trên con số). null nếu không có gốc.
  final double? rawPct;

  /// Thay đổi bình quân MỖI NGÀY CÓ BÁN (đã loại ảnh hưởng ngày nghỉ). null nếu không tính được.
  final double? perDayPct;

  /// Mức dao động bình thường (%), 0 nếu không áp dụng.
  final double band;
  final Verdict verdict;

  const MetricChange({required this.verdict, this.rawPct, this.perDayPct, this.band = 0});

  bool get significant => verdict == Verdict.up || verdict == Verdict.down;
}

/// Lõi đánh giá, dùng chung cho từng quán và cho cả chuỗi.
MetricChange assessChange({
  required bool hasCompare,
  required double curValue,
  required double prevValue,
  required int curOrders,
  required int prevOrders,
  required int activeCur,
  required int activeCmp,
  required double dayNoise,
  required double floor,
  bool isNewStore = false,
  bool notOpenYet = false,
}) {
  if (!hasCompare || notOpenYet) return const MetricChange(verdict: Verdict.noBase);
  final raw = growthPct(curValue, prevValue);
  if (isNewStore) return MetricChange(verdict: Verdict.newStore, rawPct: raw);
  if (prevOrders == 0 || prevValue <= 0) return const MetricChange(verdict: Verdict.noBase);
  // Quán đang bán đều mà kỳ này không có đơn nào: tín hiệu mạnh, không cần ngưỡng dao động.
  if (curOrders == 0 && prevOrders >= InsightConfig.minOrdersPerSide) {
    return MetricChange(verdict: Verdict.down, rawPct: -100, perDayPct: -100);
  }
  if (curOrders < InsightConfig.minOrdersPerSide || prevOrders < InsightConfig.minOrdersPerSide) {
    return MetricChange(verdict: Verdict.insufficient, rawPct: raw);
  }
  if (activeCur <= 0 || activeCmp <= 0) return MetricChange(verdict: Verdict.insufficient, rawPct: raw);

  final perDay = ((curValue / activeCur) / (prevValue / activeCmp) - 1) * 100;
  // N1 = dao động của phép so MỘT ngày với MỘT ngày; tổng nhiều ngày giảm theo √(trung bình nghịch đảo số ngày).
  final band = math.max(floor, dayNoise * math.sqrt((1 / activeCur + 1 / activeCmp) / 2)) * 100;
  final v = perDay >= band ? Verdict.up : (perDay <= -band ? Verdict.down : Verdict.noise);
  return MetricChange(verdict: v, rawPct: raw, perDayPct: perDay, band: band);
}

// ── Phân tích từng quán ─────────────────────────────────────────────────────
Set<String> activeDates(ChainReport? r, {String? storeId}) => {
  if (r != null)
    for (final p in r.daily)
      if ((storeId == null || p.storeId == storeId) && (p.orders > 0 || p.revenue > 0)) p.date,
};

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

class StoreAnalysis {
  final StoreRow row;
  final int activeDays;
  final int compareActiveDays;
  final MetricChange revenue;
  final MetricChange orders;
  final double? ordersPerDayPct;
  final double? ticketPct;
  final ChangeDriver? driver;
  final bool isNew;

  /// Quán chưa mở bán tại thời điểm kết thúc kỳ đang xem (kỳ quá khứ).
  final bool notOpenYet;

  const StoreAnalysis({
    required this.row,
    required this.activeDays,
    required this.compareActiveDays,
    required this.revenue,
    required this.orders,
    required this.ordersPerDayPct,
    required this.ticketPct,
    required this.driver,
    required this.isNew,
    required this.notOpenYet,
  });

  String get id => row.id;
}

List<StoreAnalysis> analyzeStores(List<StoreRow> rows, ChainReport cur, ChainReport? prev, PeriodWindow w) {
  return [
    for (final r in rows)
      () {
        final m = r.cur;
        final p = r.prev;
        final fo = m.firstOrderAt;
        final notOpen = fo != null && !fo.isBefore(w.to);
        final isNew = fo != null && fo.isAfter(w.compareFrom) && !notOpen;
        final ac = activeDates(cur, storeId: r.id).length;
        final ap = activeDates(prev, storeId: r.id).length;
        final hasCmp = p != null;
        final rev = assessChange(
          hasCompare: hasCmp,
          curValue: m.revenue,
          prevValue: p?.revenue ?? 0,
          curOrders: m.orders,
          prevOrders: p?.orders ?? 0,
          activeCur: ac,
          activeCmp: ap,
          dayNoise: InsightConfig.dayNoiseRevenue,
          floor: InsightConfig.floorRevenue,
          isNewStore: isNew,
          notOpenYet: notOpen,
        );
        final ord = assessChange(
          hasCompare: hasCmp,
          curValue: m.orders.toDouble(),
          prevValue: (p?.orders ?? 0).toDouble(),
          curOrders: m.orders,
          prevOrders: p?.orders ?? 0,
          activeCur: ac,
          activeCmp: ap,
          dayNoise: InsightConfig.dayNoiseOrders,
          floor: InsightConfig.floorOrders,
          isNewStore: isNew,
          notOpenYet: notOpen,
        );
        double? oPct, tPct;
        ChangeDriver? driver;
        if (rev.significant && ord.perDayPct != null && rev.perDayPct != null) {
          oPct = ord.perDayPct;
          tPct = ((1 + rev.perDayPct! / 100) / (1 + oPct! / 100) - 1) * 100;
          if (oPct.abs() >= 2 * tPct.abs()) {
            driver = ChangeDriver.volume;
          } else if (tPct.abs() >= 2 * oPct.abs()) {
            driver = ChangeDriver.ticket;
          } else {
            driver = ChangeDriver.both;
          }
        }
        return StoreAnalysis(
          row: r,
          activeDays: ac,
          compareActiveDays: ap,
          revenue: rev,
          orders: ord,
          ordersPerDayPct: oPct,
          ticketPct: tPct,
          driver: driver,
          isNew: isNew,
          notOpenYet: notOpen,
        );
      }(),
  ];
}

/// Đánh giá cho CẢ chuỗi (thẻ hero): doanh thu và số đơn.
({MetricChange revenue, MetricChange orders}) analyzeChainTotals(ChainReport cur, ChainReport? prev, PeriodWindow w) {
  final ac = activeDates(cur).length;
  final ap = activeDates(prev).length;
  final p = prev?.totals;
  MetricChange one(double c, double pv, double dayNoise, double floor) => assessChange(
    hasCompare: p != null,
    curValue: c,
    prevValue: pv,
    curOrders: cur.totals.orders,
    prevOrders: p?.orders ?? 0,
    activeCur: ac,
    activeCmp: ap,
    dayNoise: dayNoise,
    floor: floor,
  );
  return (
    revenue: one(cur.totals.revenue, p?.revenue ?? 0, InsightConfig.dayNoiseRevenue, InsightConfig.floorRevenue),
    orders: one(cur.totals.orders.toDouble(), (p?.orders ?? 0).toDouble(), InsightConfig.dayNoiseOrders, InsightConfig.floorOrders),
  );
}

// ── Nhận xét ────────────────────────────────────────────────────────────────
enum InsightKind { good, warn, info }

class ChainInsight {
  final InsightKind kind;
  final String text;

  /// Dòng giải thích số liệu/ngưỡng đã dùng, để chủ quán kiểm chứng được nhận xét.
  final String? detail;
  const ChainInsight(this.kind, this.text, {this.detail});
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _p(double v) => fmtPct(v.abs());
String _x(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
String _dm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

/// Các ngày TRỌN VẸN đã qua trong [from, to) (không tính hôm nay, ngày chưa tới).
List<DateTime> _fullDays(DateTime from, DateTime to, DateTime now) {
  final limit = _day(now).isBefore(to) ? _day(now) : to;
  final out = <DateTime>[];
  var d = _day(from);
  while (!DateTime(d.year, d.month, d.day + 1).isAfter(limit) && out.length < 62) {
    out.add(d);
    d = DateTime(d.year, d.month, d.day + 1);
  }
  return out;
}

List<ChainInsight> buildInsights(
  List<StoreRow> rows,
  ChainReport cur,
  ChainReport? prev,
  PeriodWindow w, {
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  if (rows.isEmpty) return const [];
  final an = analyzeStores(rows, cur, prev, w);
  final byId = {for (final a in an) a.id: a};
  final label = w.compareLabel;

  final warn = <ChainInsight>[];
  final good = <ChainInsight>[];
  final info = <ChainInsight>[];

  // Quán đang xét: bỏ quán chưa mở bán tại thời điểm kỳ này kết thúc.
  final live = rows.where((r) => !(byId[r.id]?.notOpenYet ?? false)).toList();

  // 1) Quán im lặng: cùng kỳ trước đã bán đều, kỳ này 0 đơn.
  final silent = <String>{};
  for (final r in live) {
    final a = byId[r.id]!;
    if (a.isNew || r.prev == null) continue;
    if (r.cur.orders == 0 && r.prev!.orders >= InsightConfig.silentExpectedOrders) {
      silent.add(r.id);
      warn.add(ChainInsight(
        InsightKind.warn,
        '${r.name} chưa có đơn nào, trong khi $label có ${r.prev!.orders} đơn.',
        detail: 'Nếu quán đang nghỉ thì bỏ qua; nếu đang mở bán, hãy kiểm tra POS/kết nối.',
      ));
    }
  }

  // 2) Ngày không có đơn (nghỉ bán/không dùng POS) trong kỳ nhiều ngày, khi kỳ so sánh bán đều.
  final fullCur = _fullDays(w.from, w.to, n);
  if (prev != null && fullCur.length >= 2) {
    final fullPrev = <DateTime>[];
    for (var d = _day(w.compareFrom);
        !DateTime(d.year, d.month, d.day + 1).isAfter(w.compareTo) && fullPrev.length < 62;
        d = DateTime(d.year, d.month, d.day + 1)) {
      fullPrev.add(d);
    }
    if (fullPrev.length >= 2) {
      for (final r in live) {
        final a = byId[r.id]!;
        if (a.isNew || silent.contains(r.id) || r.cur.orders == 0) continue;
        final curAct = activeDates(cur, storeId: r.id);
        final prevAct = activeDates(prev, storeId: r.id);
        final prevActiveFull = fullPrev.where((d) => prevAct.contains(ymd(d))).length;
        if (prevActiveFull / fullPrev.length < InsightConfig.closedDayPrevActiveRatio) continue;
        final closed = fullCur.where((d) => !curAct.contains(ymd(d))).toList();
        if (closed.isEmpty) continue;
        final shown = closed.take(3).map(_dm).join(', ');
        warn.add(ChainInsight(
          InsightKind.warn,
          '${r.name}: không có đơn ngày $shown${closed.length > 3 ? ' (+${closed.length - 3} ngày nữa)' : ''} — có thể nghỉ bán hoặc chưa dùng POS ngày đó.',
          detail: '${_cap(label)} có đơn $prevActiveFull/${fullPrev.length} ngày; kỳ này ${fullCur.length - closed.length}/${fullCur.length} ngày đã qua.',
        ));
      }
    }
  }

  // 3) Tăng/giảm doanh thu có ý nghĩa — mỗi hướng chỉ nêu quán nổi bật nhất (|thay đổi| / ngưỡng lớn nhất).
  StoreAnalysis? bestUp, bestDown;
  double score(StoreAnalysis a) => a.revenue.band > 0 ? (a.revenue.perDayPct!.abs() / a.revenue.band) : 0;
  for (final a in an) {
    // Verdict.down có band = 0 là ca "kỳ này 0 đơn" — đã có nhận xét riêng ở mục 1 (quán im lặng).
    if (a.notOpenYet || !a.revenue.significant) continue;
    if (a.revenue.verdict == Verdict.up && (bestUp == null || score(a) > score(bestUp))) bestUp = a;
    if (a.revenue.verdict == Verdict.down && a.revenue.band > 0 && (bestDown == null || score(a) > score(bestDown))) bestDown = a;
  }
  ChainInsight changeInsight(StoreAnalysis a, bool up) {
    final r = a.row;
    final ch = a.revenue;
    final sameDays = a.activeDays == a.compareActiveDays;
    final dir = up ? 'tăng' : 'giảm';
    final head = sameDays
        ? '${r.name}: doanh thu $dir ${_p(ch.rawPct!)} so với $label'
        : '${r.name}: doanh thu bình quân mỗi ngày bán $dir ${_p(ch.perDayPct!)} so với $label';
    final o = a.ordersPerDayPct, t = a.ticketPct;
    String why = '';
    if (o != null && t != null && a.driver != null) {
      String sg(double v) => fmtPct(v, signed: true);
      String d(double v) => v >= 0 ? 'tăng' : 'giảm';
      why = switch (a.driver!) {
        ChangeDriver.volume => ', chủ yếu do số đơn ${d(o)} ${_p(o)} (giá trị mỗi đơn gần như không đổi: ${sg(t)})',
        ChangeDriver.ticket => ', chủ yếu do giá trị mỗi đơn ${d(t)} ${_p(t)} (số đơn gần như không đổi: ${sg(o)})',
        ChangeDriver.both => ', do số đơn (${sg(o)}) và giá trị mỗi đơn (${sg(t)}) cùng thay đổi',
      };
    }
    final perDayCur = r.cur.revenue / a.activeDays;
    final perDayPrev = r.prev!.revenue / a.compareActiveDays;
    final days = sameDays ? '' : ' Kỳ này bán ${a.activeDays} ngày, $label ${a.compareActiveDays} ngày — đã quy đổi theo ngày có bán.';
    return ChainInsight(
      up ? InsightKind.good : InsightKind.warn,
      '$head$why${up ? '.' : ' — nên kiểm tra.'}',
      detail: 'Bình quân ${fmtVnd(perDayCur)}/ngày bán (trước: ${fmtVnd(perDayPrev)}). '
          'Chỉ nêu khi vượt mức dao động bình thường ±${_x(ch.band)}%.$days',
    );
  }
  if (bestDown != null) warn.add(changeInsight(bestDown, false));
  if (bestUp != null) good.add(changeInsight(bestUp, true));

  // 4) Hủy món/bàn: tỷ lệ theo doanh thu, so với các quán khác (hoặc kỳ trước nếu chỉ có một quán đủ mẫu).
  _rateInsight(
    live: live,
    prev: prev,
    qualify: (m) => m.voidAmount != null && m.orders >= InsightConfig.minOrdersForRates && m.revenue > 0,
    num: (m) => m.voidAmount!,
    den: (m) => m.revenue,
    alertRate: InsightConfig.voidAlertRate,
    othersFactor: InsightConfig.voidVsOthersFactor,
    build: (r, rate, ref, refIsOthers) => ChainInsight(
      InsightKind.warn,
      'Giá trị hủy món/bàn của ${r.name} bằng ${fmtPct(rate * 100)} doanh thu (${r.cur.voidCount ?? 0} lần)'
      '${ref == null ? '' : refIsOthers ? ', cao gấp ${_x(rate / ref)} lần mức các quán khác (${fmtPct(ref * 100)})' : ', tăng từ ${fmtPct(ref * 100)} ở $label'}'
      ' — nên xem lý do hủy.',
      detail: 'Hủy ${fmtVnd(r.cur.voidAmount!)} trên doanh thu ${fmtVnd(r.cur.revenue)}. Xem chi tiết ở báo cáo Huỷ/Duyệt của quán đó.',
    ),
    out: warn,
  );

  // 5) Giảm giá: tỷ lệ trên giá trị bán TRƯỚC giảm (gross = doanh thu + giảm giá).
  _rateInsight(
    live: live,
    prev: prev,
    qualify: (m) => m.grossRevenue != null && m.orders >= InsightConfig.minOrdersForRates && m.grossRevenue! > 0,
    num: (m) => m.discount,
    den: (m) => m.grossRevenue!,
    alertRate: InsightConfig.discountAlertRate,
    othersFactor: InsightConfig.rateVsOthersFactor,
    build: (r, rate, ref, refIsOthers) => ChainInsight(
      InsightKind.warn,
      'Giảm giá của ${r.name} chiếm ${fmtPct(rate * 100)} giá trị bán'
      '${ref == null ? '' : refIsOthers ? ' (các quán khác: ${fmtPct(ref * 100)})' : ' (tăng từ ${fmtPct(ref * 100)} ở $label)'}.',
      detail: 'Giảm ${fmtVnd(r.cur.discount)} trên giá trị bán ${fmtVnd(r.cur.grossRevenue!)}.',
    ),
    out: warn,
  );

  // 6) TB/đơn so với trung bình chuỗi (chỉ quán đủ mẫu, cần ≥ 2 quán).
  final tq = live.where((r) => r.cur.orders >= InsightConfig.minOrdersPerSide && r.cur.revenue > 0).toList();
  if (tq.length >= 2) {
    final pooled = tq.fold<double>(0, (a, r) => a + r.cur.revenue) / tq.fold<int>(0, (a, r) => a + r.cur.orders);
    final byTicket = [...tq]..sort((a, b) => (b.cur.revenue / b.cur.orders).compareTo(a.cur.revenue / a.cur.orders));
    final hi = byTicket.first, lo = byTicket.last;
    final hiT = hi.cur.revenue / hi.cur.orders, loT = lo.cur.revenue / lo.cur.orders;
    if (hiT >= pooled * InsightConfig.ticketHighFactor) {
      info.add(ChainInsight(
        InsightKind.info,
        '${hi.name} có giá trị TB/đơn ${fmtVnd(hiT)}, cao hơn trung bình chuỗi ${_p((hiT / pooled - 1) * 100)}.',
        detail: 'Trung bình chuỗi ${fmtVnd(pooled)}/đơn (tính trên các quán có từ ${InsightConfig.minOrdersPerSide} đơn).',
      ));
    }
    if (loT <= pooled * InsightConfig.ticketLowFactor && lo.id != hi.id) {
      warn.add(ChainInsight(
        InsightKind.warn,
        '${lo.name} có TB/đơn ${fmtVnd(loT)}, thấp hơn trung bình chuỗi ${_p((1 - loT / pooled) * 100)} — xem lại giá bán và cơ cấu món.',
        detail: 'Trung bình chuỗi ${fmtVnd(pooled)}/đơn.',
      ));
    }
  }

  // 7) Quán mới / chưa từng bán.
  for (final r in live) {
    final a = byId[r.id]!;
    final fo = r.cur.firstOrderAt;
    if (a.isNew && fo != null) {
      info.add(ChainInsight(
        InsightKind.info,
        '${r.name} mới có đơn đầu tiên từ ${_dm(fo)} — chưa đủ lịch sử để so sánh với $label.',
      ));
    } else if (r.cur.firstOrderKnown && fo == null && r.cur.orders == 0) {
      info.add(ChainInsight(
        InsightKind.info,
        '${r.name} chưa từng có đơn nào.',
        detail: 'Kiểm tra quán đã bắt đầu dùng POS chưa.',
      ));
    }
  }

  // 8) Dẫn đầu / tập trung doanh thu.
  final total = cur.totals.revenue;
  final selling = live.where((r) => r.cur.orders > 0).toList();
  if (selling.length >= 2 && total > 0) {
    final byRev = sortedBy(selling, CompareMetric.revenue);
    final lead = byRev.first;
    final share = lead.cur.revenue / total;
    if (selling.length >= 3 && share >= InsightConfig.concentrationShare) {
      info.add(ChainInsight(
        InsightKind.info,
        'Doanh thu tập trung: ${lead.name} chiếm ${fmtPct(share * 100)} cả chuỗi.',
        detail: 'Nên theo dõi rủi ro phụ thuộc vào một quán.',
      ));
    } else {
      final second = byRev[1].cur.revenue;
      final ratio = second > 0 ? lead.cur.revenue / second : 0.0;
      info.add(ChainInsight(
        InsightKind.info,
        '${lead.name} dẫn đầu doanh thu, chiếm ${fmtPct(share * 100)} cả chuỗi${ratio >= 1.5 ? ', gấp ${_x(ratio)} lần quán thứ hai' : ''}.',
      ));
    }
  }

  final all = [...warn, ...good, ...info];
  return all.length <= InsightConfig.maxInsights ? all : all.sublist(0, InsightConfig.maxInsights);
}

/// So tỷ lệ (num/den) của từng quán đủ mẫu với mức chung của CÁC QUÁN KHÁC; nếu không có quán khác đủ mẫu
/// thì so với chính nó ở kỳ so sánh. Chỉ cảnh báo khi vượt ngưỡng tuyệt đối VÀ vượt hệ số tương đối.
void _rateInsight({
  required List<StoreRow> live,
  required ChainReport? prev,
  required bool Function(StoreMetrics) qualify,
  required double Function(StoreMetrics) num,
  required double Function(StoreMetrics) den,
  required double alertRate,
  required double othersFactor,
  required ChainInsight Function(StoreRow r, double rate, double? ref, bool refIsOthers) build,
  required List<ChainInsight> out,
}) {
  final q = live.where((r) => qualify(r.cur)).toList();
  if (q.isEmpty) return;
  for (final r in q) {
    final rate = num(r.cur) / den(r.cur);
    if (rate < alertRate) continue;
    final others = q.where((o) => o.id != r.id).toList();
    if (others.isNotEmpty) {
      final oNum = others.fold<double>(0, (a, o) => a + num(o.cur));
      final oDen = others.fold<double>(0, (a, o) => a + den(o.cur));
      final oRate = oDen > 0 ? oNum / oDen : 0.0;
      if (oRate == 0 || rate >= oRate * othersFactor) {
        out.add(build(r, rate, oRate == 0 ? null : oRate, true));
      }
    } else {
      final pm = r.prev;
      if (pm != null && qualify(pm)) {
        final pRate = num(pm) / den(pm);
        if (pRate == 0 || (rate >= pRate * 2 && rate - pRate >= 0.02)) {
          out.add(build(r, rate, pRate == 0 ? null : pRate, false));
        }
      } else if (pm == null) {
        // Không có kỳ so sánh và không có quán khác để đối chiếu: chỉ có ngưỡng tuyệt đối → vẫn báo nhưng không nêu mốc so.
        out.add(build(r, rate, null, false));
      }
    }
  }
}
