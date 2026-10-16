import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/core/utils/chain_compare.dart';
import 'package:quannho_pos/core/utils/chain_insights.dart';

// ── Dữ liệu dựng nhanh ──────────────────────────────────────────────────────
StoreMetrics _m(
  String id,
  String name, {
  int orders = 0,
  double revenue = 0,
  double discount = 0,
  double? gross,
  int? voidCount,
  double? voidAmount,
  DateTime? first,
  bool firstKnown = false,
}) => StoreMetrics(
  storeId: id,
  name: name,
  orders: orders,
  revenue: revenue,
  avgOrderValue: orders > 0 ? revenue / orders : 0,
  discount: discount,
  grossRevenue: gross ?? (voidAmount != null || discount > 0 ? revenue + discount : null),
  voidCount: voidCount,
  voidAmount: voidAmount,
  firstOrderAt: first,
  firstOrderKnown: firstKnown || first != null,
);

/// Chuỗi ngày: [id, 'yyyy-MM-dd', đơn, doanh thu]
ChainDailyPoint _d(String id, String date, int o, double r) => ChainDailyPoint(date: date, storeId: id, orders: o, revenue: r);

ChainReport _rep(List<StoreMetrics> stores, [List<ChainDailyPoint> daily = const []]) {
  final rev = stores.fold<double>(0, (a, s) => a + s.revenue);
  final ord = stores.fold<int>(0, (a, s) => a + s.orders);
  return ChainReport(
    chainId: 'c',
    chainName: 'Chuoi',
    stores: stores,
    storeCount: stores.length,
    daily: daily,
    excluded: const [],
    totals: StoreMetrics(
      storeId: '',
      name: 'Tổng',
      orders: ord,
      revenue: rev,
      avgOrderValue: ord > 0 ? rev / ord : 0,
      discount: stores.fold<double>(0, (a, s) => a + s.discount),
    ),
  );
}

/// n ngày liên tiếp bắt đầu từ [start], mỗi ngày có [o] đơn, doanh thu [r].
List<ChainDailyPoint> _run(String id, DateTime start, int n, int o, double r, {Set<int> skip = const {}}) => [
  for (var i = 0; i < n; i++)
    if (!skip.contains(i))
      _d(id, ymd(DateTime(start.year, start.month, start.day + i)), o, r),
];

// Tuần quá khứ cố định: cur = 12–18/10, so với 5–11/10; "bây giờ" = 20/10 nên mọi ngày đều trọn vẹn.
final _now = DateTime(2026, 10, 20, 9);
final _w = windowFor(ChainPeriod.week, -1, _now);
final _curStart = DateTime(2026, 10, 12);
final _prevStart = DateTime(2026, 10, 5);

List<ChainInsight> _ins(ChainReport cur, ChainReport? prev, [PeriodWindow? w, DateTime? now]) =>
    buildInsights(buildRows(cur, prev), cur, prev, w ?? _w, now: now ?? _now);

String _all(List<ChainInsight> l) => l.map((e) => '${e.kind.name}:${e.text}').join('\n');

void main() {
  test('cửa sổ dùng cho test đúng như dự kiến', () {
    expect(_w.from, _curStart);
    expect(_w.compareFrom, _prevStart);
    expect(_w.compareLabel, 'tuần trước');
  });

  group('assessChange — ý nghĩa thống kê', () {
    MetricChange a({
      double cur = 100,
      double prev = 100,
      int co = 100,
      int po = 100,
      int ac = 1,
      int ap = 1,
      bool hasCmp = true,
      bool isNew = false,
      bool notOpen = false,
    }) => assessChange(
      hasCompare: hasCmp,
      curValue: cur,
      prevValue: prev,
      curOrders: co,
      prevOrders: po,
      activeCur: ac,
      activeCmp: ap,
      dayNoise: InsightConfig.dayNoiseRevenue,
      floor: InsightConfig.floorRevenue,
      isNewStore: isNew,
      notOpenYet: notOpen,
    );

    test('một ngày: lệch 20% vẫn là dao động bình thường (ngưỡng 34%)', () {
      expect(a(cur: 80).verdict, Verdict.noise);
      expect(a(cur: 80).band, closeTo(34, 0.001));
    });
    test('một ngày: lệch -40% vượt ngưỡng → giảm', () => expect(a(cur: 60).verdict, Verdict.down));
    test('một ngày: +40% → tăng', () => expect(a(cur: 140).verdict, Verdict.up));
    test('một tuần 7 ngày: ngưỡng thu hẹp còn ≈ 12,9% (34%/√7)', () {
      expect(a(cur: 700, prev: 700, ac: 7, ap: 7).band, closeTo(34 / 2.6458, 0.01));
    });
    test('một tuần 7 ngày: -8,6% vẫn trong dao động, -20% là giảm', () {
      expect(a(cur: 640, prev: 700, ac: 7, ap: 7).verdict, Verdict.noise);
      expect(a(cur: 560, prev: 700, ac: 7, ap: 7).verdict, Verdict.down);
    });
    test('một tháng 30 ngày: ngưỡng ≈ 6,2% (34%/√30), không thấp hơn sàn 6%', () {
      expect(a(cur: 3000, prev: 3000, ac: 30, ap: 30).band, closeTo(34 / 5.4772, 0.01));
      expect(a(cur: 3000, prev: 3000, ac: 90, ap: 90).band, 6); // kỳ rất dài: chạm sàn
      expect(a(cur: 2900, prev: 3000, ac: 30, ap: 30).verdict, Verdict.noise); // -3,3%
      expect(a(cur: 2700, prev: 3000, ac: 30, ap: 30).verdict, Verdict.down); // -10%
    });
    test('quán nghỉ 3/7 ngày: tổng -43% nhưng bình quân ngày bán gần như không đổi → KHÔNG kết luận giảm', () {
      // kỳ này 4 ngày bán, doanh thu 400 (100/ngày); kỳ trước 7 ngày, 720 (≈103/ngày)
      final r = a(cur: 400, prev: 720, co: 300, po: 520, ac: 4, ap: 7);
      expect(r.rawPct, closeTo(-44.4, 0.1));
      expect(r.perDayPct, closeTo(-2.8, 0.1));
      expect(r.verdict, Verdict.noise);
    });
    test('ít ngày bán → ngưỡng rộng hơn (4 ngày vs 7 ngày)', () {
      final r = a(cur: 400, prev: 700, co: 300, po: 500, ac: 4, ap: 7);
      expect(r.band, greaterThan(34 / 2.6458)); // rộng hơn 7v7
    });
    test('mẫu ít (<15 đơn một bên) → insufficient, kể cả khi lệch lớn', () {
      expect(a(cur: 10, prev: 100, co: 8, po: 100).verdict, Verdict.insufficient);
      expect(a(cur: 100, prev: 10, co: 100, po: 14).verdict, Verdict.insufficient);
    });
    test('kỳ trước 0 đơn → noBase (không chia cho 0)', () {
      expect(a(prev: 0, po: 0).verdict, Verdict.noBase);
    });
    test('không có kỳ so sánh (tải lỗi) → noBase', () => expect(a(hasCmp: false).verdict, Verdict.noBase));
    test('quán mới → newStore; quán chưa mở bán ở kỳ quá khứ → noBase', () {
      expect(a(isNew: true).verdict, Verdict.newStore);
      expect(a(notOpen: true).verdict, Verdict.noBase);
    });
    test('đang bán đều (≥15 đơn) mà kỳ này 0 đơn → giảm, không cần ngưỡng', () {
      final r = a(cur: 0, co: 0, po: 40, prev: 400);
      expect(r.verdict, Verdict.down);
      expect(r.rawPct, -100);
      expect(r.band, 0);
    });
    test('kỳ này 0 đơn nhưng kỳ trước chỉ có 3 đơn (đầu ngày) → không kết luận', () {
      expect(a(cur: 0, co: 0, po: 3, prev: 300).verdict, Verdict.insufficient);
    });
  });

  group('Nhận xét — tăng/giảm có ý nghĩa và nguyên nhân', () {
    test('doanh thu giảm do SỐ ĐƠN giảm (giá trị mỗi đơn đứng yên) → nêu đúng nguyên nhân', () {
      // 7 ngày vs 7 ngày; trước 100 đơn/ngày × 100k; nay 70 đơn/ngày × 100k
      final cur = _rep([_m('a', 'Alpha', orders: 490, revenue: 49000000), _m('b', 'Beta', orders: 700, revenue: 70000000)], [
        ..._run('a', _curStart, 7, 70, 7000000),
        ..._run('b', _curStart, 7, 100, 10000000),
      ]);
      final prev = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000), _m('b', 'Beta', orders: 700, revenue: 70000000)], [
        ..._run('a', _prevStart, 7, 100, 10000000),
        ..._run('b', _prevStart, 7, 100, 10000000),
      ]);
      final t = _all(_ins(cur, prev));
      expect(t, contains('warn:Alpha: doanh thu giảm 30,0% so với tuần trước'));
      expect(t, contains('chủ yếu do số đơn giảm 30,0%'));
      expect(t, contains('giá trị mỗi đơn gần như không đổi'));
      expect(t, isNot(contains('Beta: doanh thu'))); // Beta đứng yên: không có nhận xét
    });

    test('doanh thu tăng do GIÁ TRỊ MỖI ĐƠN tăng (số đơn đứng yên)', () {
      final cur = _rep([_m('a', 'Alpha', orders: 700, revenue: 91000000)], [..._run('a', _curStart, 7, 100, 13000000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000)], [..._run('a', _prevStart, 7, 100, 10000000)]);
      final ins = _ins(cur, prev);
      final up = ins.firstWhere((e) => e.kind == InsightKind.good);
      expect(up.text, contains('doanh thu tăng 30,0%'));
      expect(up.text, contains('chủ yếu do giá trị mỗi đơn tăng 30,0%'));
      expect(up.text, contains('số đơn gần như không đổi'));
      expect(up.detail, contains('±12,9%')); // ngưỡng 7 ngày
    });

    test('cả số đơn lẫn giá trị mỗi đơn cùng đổi → nêu cả hai', () {
      // đơn +20%, giá trị mỗi đơn +20% → doanh thu +44%
      final cur = _rep([_m('a', 'Alpha', orders: 840, revenue: 100800000)], [..._run('a', _curStart, 7, 120, 14400000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000)], [..._run('a', _prevStart, 7, 100, 10000000)]);
      final up = _ins(cur, prev).firstWhere((e) => e.kind == InsightKind.good);
      expect(up.text, contains('do số đơn (+20,0%) và giá trị mỗi đơn (+20,0%) cùng thay đổi'));
    });

    test('thay đổi nhỏ trong dao động bình thường → KHÔNG có nhận xét tăng/giảm', () {
      final cur = _rep([_m('a', 'A', orders: 665, revenue: 66500000), _m('b', 'B', orders: 735, revenue: 73500000)], [
        ..._run('a', _curStart, 7, 95, 9500000),
        ..._run('b', _curStart, 7, 105, 10500000),
      ]);
      final prev = _rep([_m('a', 'A', orders: 700, revenue: 70000000), _m('b', 'B', orders: 700, revenue: 70000000)], [
        ..._run('a', _prevStart, 7, 100, 10000000),
        ..._run('b', _prevStart, 7, 100, 10000000),
      ]);
      final t = _all(_ins(cur, prev));
      expect(t, isNot(contains('doanh thu giảm')));
      expect(t, isNot(contains('doanh thu tăng')));
      expect(t, isNot(contains('nên kiểm tra')));
    });

    test('mỗi hướng chỉ nêu quán nổi bật nhất (không liệt kê dồn)', () {
      final stores = ['a', 'b', 'c', 'd'];
      final curS = [
        _m('a', 'A', orders: 420, revenue: 42000000), // -40%
        _m('b', 'B', orders: 490, revenue: 49000000), // -30%
        _m('c', 'C', orders: 910, revenue: 91000000), // +30%
        _m('d', 'D', orders: 980, revenue: 98000000), // +40%
      ];
      final cur = _rep(curS, [
        ..._run('a', _curStart, 7, 60, 6000000), ..._run('b', _curStart, 7, 70, 7000000),
        ..._run('c', _curStart, 7, 130, 13000000), ..._run('d', _curStart, 7, 140, 14000000),
      ]);
      final prev = _rep([for (final s in stores) _m(s, s.toUpperCase(), orders: 700, revenue: 70000000)],
          [for (final s in stores) ..._run(s, _prevStart, 7, 100, 10000000)]);
      final t = _all(_ins(cur, prev));
      expect(t, contains('A: doanh thu giảm 40,0%'));
      expect(t, isNot(contains('B: doanh thu')));
      expect(t, contains('D: doanh thu tăng 40,0%'));
      expect(t, isNot(contains('C: doanh thu')));
    });
  });

  group('Nhận xét — ngày nghỉ, quán im lặng, quán mới', () {
    test('tuần nghỉ 3 ngày: KHÔNG báo "giảm", MÀ báo đúng các ngày không có đơn', () {
      // Alpha bán ngày 12,13,14,17 (nghỉ 15,16,18); kỳ trước bán đủ 7 ngày
      final cur = _rep([_m('a', 'Alpha', orders: 400, revenue: 40000000), _m('b', 'Beta', orders: 700, revenue: 70000000)], [
        ..._run('a', _curStart, 7, 100, 10000000, skip: {3, 4, 6}),
        ..._run('b', _curStart, 7, 100, 10000000),
      ]);
      final prev = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000), _m('b', 'Beta', orders: 700, revenue: 70000000)], [
        ..._run('a', _prevStart, 7, 100, 10000000),
        ..._run('b', _prevStart, 7, 100, 10000000),
      ]);
      final ins = _ins(cur, prev);
      final t = _all(ins);
      expect(t, isNot(contains('Alpha: doanh thu')));
      final closed = ins.firstWhere((e) => e.text.contains('Alpha: không có đơn ngày'));
      expect(closed.kind, InsightKind.warn);
      expect(closed.text, contains('15/10, 16/10, 18/10'));
      expect(closed.detail, contains('Tuần trước có đơn 7/7 ngày'));
      // chip doanh thu: tổng -43% nhưng không tô đỏ
      final an = analyzeStores(buildRows(cur, prev), cur, prev, _w).firstWhere((a) => a.id == 'a');
      expect(an.revenue.rawPct, closeTo(-42.9, 0.1));
      expect(an.revenue.verdict, Verdict.noise);
    });

    test('không báo ngày nghỉ nếu kỳ trước cũng bán thưa (quán vốn nghỉ cuối tuần)', () {
      final cur = _rep([_m('a', 'Alpha', orders: 500, revenue: 50000000)], [..._run('a', _curStart, 7, 100, 10000000, skip: {5, 6})]);
      final prev = _rep([_m('a', 'Alpha', orders: 500, revenue: 50000000)], [..._run('a', _prevStart, 7, 100, 10000000, skip: {5, 6})]);
      expect(_all(_ins(cur, prev)), isNot(contains('không có đơn ngày')));
    });

    test('quán 0 đơn cả kỳ trong khi kỳ trước bán đều → "chưa có đơn nào"; không lặp thêm báo ngày nghỉ', () {
      final cur = _rep([_m('a', 'Alpha'), _m('b', 'Beta', orders: 700, revenue: 70000000)], [..._run('b', _curStart, 7, 100, 10000000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 300, revenue: 30000000), _m('b', 'Beta', orders: 700, revenue: 70000000)], [
        ..._run('a', _prevStart, 7, 43, 4300000),
        ..._run('b', _prevStart, 7, 100, 10000000),
      ]);
      final ins = _ins(cur, prev);
      final t = _all(ins);
      expect(t, contains('warn:Alpha chưa có đơn nào, trong khi tuần trước có 300 đơn.'));
      expect(t, isNot(contains('Alpha: không có đơn ngày')));
      expect(t, isNot(contains('Alpha: doanh thu'))); // ca này đã có nhận xét riêng
    });

    test('đầu ngày chưa có đơn (cùng giờ tuần trước cũng ít) → KHÔNG báo im lặng', () {
      final now = DateTime(2026, 10, 16, 5, 30);
      final w = windowFor(ChainPeriod.day, 0, now);
      final cur = _rep([_m('a', 'Alpha'), _m('b', 'Beta', orders: 30, revenue: 3000000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 3, revenue: 300000), _m('b', 'Beta', orders: 28, revenue: 2800000)]);
      expect(_all(_ins(cur, prev, w, now)), isNot(contains('chưa có đơn nào')));
    });

    test('cùng giờ tuần trước đã có ≥5 đơn mà hôm nay 0 đơn → báo im lặng, ghi rõ "cùng thứ tuần trước"', () {
      final now = DateTime(2026, 10, 16, 15);
      final w = windowFor(ChainPeriod.day, 0, now);
      final cur = _rep([_m('a', 'Alpha'), _m('b', 'Beta', orders: 30, revenue: 3000000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 40, revenue: 4000000), _m('b', 'Beta', orders: 28, revenue: 2800000)]);
      expect(_all(_ins(cur, prev, w, now)), contains('Alpha chưa có đơn nào, trong khi cùng thứ tuần trước có 40 đơn.'));
    });

    test('quán mới có đơn đầu trong kỳ → báo "quán mới", không báo tăng/giảm', () {
      final cur = _rep([
        _m('a', 'Alpha', orders: 700, revenue: 70000000, first: DateTime(2026, 6, 1)),
        _m('n', 'Moi', orders: 100, revenue: 9000000, first: DateTime(2026, 10, 14, 10)),
      ], [..._run('a', _curStart, 7, 100, 10000000), ..._run('n', DateTime(2026, 10, 14), 5, 20, 1800000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000), _m('n', 'Moi')], [..._run('a', _prevStart, 7, 100, 10000000)]);
      final t = _all(_ins(cur, prev));
      expect(t, contains('info:Moi mới có đơn đầu tiên từ 14/10 — chưa đủ lịch sử để so sánh với tuần trước.'));
      expect(t, isNot(contains('Moi: doanh thu')));
      expect(t, isNot(contains('Moi chưa có đơn')));
    });

    test('quán bắt đầu bán giữa kỳ so sánh cũng là "mới" (lịch sử kỳ trước chưa trọn vẹn)', () {
      final cur = _rep([_m('n', 'Moi', orders: 700, revenue: 70000000, first: DateTime(2026, 10, 8))], [..._run('n', _curStart, 7, 100, 10000000)]);
      final prev = _rep([_m('n', 'Moi', orders: 200, revenue: 20000000)], [..._run('n', DateTime(2026, 10, 8), 4, 50, 5000000)]);
      final an = analyzeStores(buildRows(cur, prev), cur, prev, _w).single;
      expect(an.isNew, isTrue);
      expect(an.revenue.verdict, Verdict.newStore);
    });

    test('kỳ quá khứ trước khi quán mở bán: bỏ qua, không báo gì về quán đó', () {
      final cur = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000, first: DateTime(2026, 6, 1)), _m('n', 'Moi', first: DateTime(2026, 10, 25))], [..._run('a', _curStart, 7, 100, 10000000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000), _m('n', 'Moi')], [..._run('a', _prevStart, 7, 100, 10000000)]);
      final t = _all(_ins(cur, prev));
      expect(t, isNot(contains('Moi')));
    });

    test('quán chưa từng có đơn (máy chủ xác nhận first_order_at = null) → nhắc kiểm tra POS', () {
      final cur = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000), _m('z', 'Trong', firstKnown: true)], [..._run('a', _curStart, 7, 100, 10000000)]);
      expect(_all(_ins(cur, null)), contains('info:Trong chưa từng có đơn nào.'));
    });

    test('máy chủ cũ (không gửi first_order_at) → KHÔNG khẳng định "chưa từng có đơn"', () {
      final cur = _rep([_m('a', 'Alpha', orders: 700, revenue: 70000000), _m('z', 'Trong')], [..._run('a', _curStart, 7, 100, 10000000)]);
      expect(_all(_ins(cur, null)), isNot(contains('chưa từng')));
    });
  });

  group('Nhận xét — giảm giá và hủy món (chỉ khi máy chủ có trường)', () {
    ChainReport two({double aDisc = 0, double bDisc = 0, double? aVoid, double? bVoid, int aOrders = 400, int bOrders = 400}) {
      return _rep([
        _m('a', 'Alpha', orders: aOrders, revenue: 40000000, discount: aDisc, voidAmount: aVoid, voidCount: aVoid == null ? null : 12),
        _m('b', 'Beta', orders: bOrders, revenue: 40000000, discount: bDisc, voidAmount: bVoid, voidCount: bVoid == null ? null : 5),
      ]);
    }

    test('giảm giá 8% so với 1% ở quán kia → cảnh báo, nêu mốc so', () {
      final t = _all(_ins(two(aDisc: 3478260, bDisc: 404040), null));
      expect(t, contains('warn:Giảm giá của Alpha chiếm 8,0% giá trị bán (các quán khác: 1,0%).'));
      expect(t, isNot(contains('Giảm giá của Beta')));
    });
    test('giảm giá 3% (dưới ngưỡng tuyệt đối 4%) → không cảnh báo dù gấp 3 lần quán kia', () {
      expect(_all(_ins(two(aDisc: 1237113, bDisc: 404040), null)), isNot(contains('Giảm giá của')));
    });
    test('cả hai quán cùng giảm giá cao (6%) → không quán nào nổi bật hơn → không cảnh báo', () {
      expect(_all(_ins(two(aDisc: 2553191, bDisc: 2553191), null)), isNot(contains('Giảm giá của')));
    });
    test('mẫu nhỏ (<30 đơn) → bỏ qua tỷ lệ giảm giá', () {
      expect(_all(_ins(two(aDisc: 3478260, bDisc: 404040, aOrders: 20), null)), isNot(contains('Giảm giá của')));
    });
    test('máy chủ chưa gửi gross_revenue → bỏ qua quy tắc giảm giá, không crash', () {
      final cur = _rep([
        StoreMetrics(storeId: 'a', name: 'Alpha', orders: 400, revenue: 40000000, discount: 9999999),
        StoreMetrics(storeId: 'b', name: 'Beta', orders: 400, revenue: 40000000, discount: 1),
      ]);
      expect(_all(_ins(cur, null)), isNot(contains('Giảm giá của')));
    });
    test('một quán duy nhất: giảm giá tăng gấp 3 lần kỳ trước và vượt 4% → cảnh báo so với kỳ trước', () {
      final cur = _rep([_m('a', 'Alpha', orders: 400, revenue: 40000000, discount: 2500000)]);
      final prev = _rep([_m('a', 'Alpha', orders: 400, revenue: 40000000, discount: 500000)]);
      expect(_all(_ins(cur, prev)), contains('Giảm giá của Alpha chiếm 5,9% giá trị bán (tăng từ 1,2% ở tuần trước).'));
    });

    test('hủy 8% doanh thu so với 2% ở quán kia → cảnh báo, nêu số lần và gấp mấy lần', () {
      final t = _all(_ins(two(aVoid: 3200000, bVoid: 800000), null));
      expect(t, contains('warn:Giá trị hủy món/bàn của Alpha bằng 8,0% doanh thu (12 lần), cao gấp 4,0 lần mức các quán khác (2,0%)'));
    });
    test('hủy 3,1% (mức bình thường đo được ở quán chính) → không cảnh báo', () {
      expect(_all(_ins(two(aVoid: 1240000, bVoid: 400000), null)), isNot(contains('hủy món/bàn')));
    });
    test('hủy cao nhưng quán kia cũng cao tương đương → không nổi bật', () {
      expect(_all(_ins(two(aVoid: 3200000, bVoid: 2800000), null)), isNot(contains('hủy món/bàn')));
    });
    test('kết quả không chứa lý do hay tên người hủy (không có KPI cá nhân)', () {
      final t = _all(_ins(two(aVoid: 3200000, bVoid: 800000), null));
      expect(t, isNot(contains('requested')));
    });
  });

  group('Nhận xét — TB/đơn, dẫn đầu, tập trung', () {
    test('TB/đơn cao hơn trung bình chuỗi ≥ 15% → nêu; thấp ≤ 80% → cảnh báo', () {
      final cur = _rep([
        _m('a', 'Alpha', orders: 100, revenue: 15000000), // 150k
        _m('b', 'Beta', orders: 100, revenue: 10000000), // 100k
        _m('c', 'Gama', orders: 100, revenue: 5000000), // 50k
      ]);
      final t = _all(_ins(cur, null));
      expect(t, contains('info:Alpha có giá trị TB/đơn 150.000 đ, cao hơn trung bình chuỗi 50,0%.'));
      expect(t, contains('warn:Gama có TB/đơn 50.000 đ, thấp hơn trung bình chuỗi 50,0%'));
    });
    test('chênh TB/đơn nhỏ (<15%) → không nhận xét', () {
      final cur = _rep([_m('a', 'A', orders: 100, revenue: 10500000), _m('b', 'B', orders: 100, revenue: 10000000)]);
      expect(_all(_ins(cur, null)), isNot(contains('TB/đơn')));
    });
    test('quán dưới 15 đơn không tham gia so TB/đơn', () {
      final cur = _rep([_m('a', 'A', orders: 100, revenue: 10000000), _m('b', 'B', orders: 5, revenue: 5000000)]);
      expect(_all(_ins(cur, null)), isNot(contains('TB/đơn')));
    });
    test('dẫn đầu: nêu tỷ trọng và "gấp N lần" khi ≥ 1,5', () {
      final cur = _rep([_m('a', 'Alpha', orders: 300, revenue: 55000000), _m('b', 'Beta', orders: 200, revenue: 45000000)]);
      expect(_all(_ins(cur, null)), contains('Alpha dẫn đầu doanh thu, chiếm 55,0% cả chuỗi.'));
      final cur15 = _rep([_m('a', 'Alpha', orders: 300, revenue: 60000000), _m('b', 'Beta', orders: 200, revenue: 40000000)]);
      expect(_all(_ins(cur15, null)), contains('chiếm 60,0% cả chuỗi, gấp 1,5 lần quán thứ hai.')); // đúng ngưỡng 1,5
      final cur2 = _rep([_m('a', 'Alpha', orders: 300, revenue: 75000000), _m('b', 'Beta', orders: 200, revenue: 25000000)]);
      expect(_all(_ins(cur2, null)), contains('chiếm 75,0% cả chuỗi, gấp 3,0 lần quán thứ hai.'));
    });
    test('từ 3 quán có đơn, một quán ≥ 70% → báo tập trung (thay cho câu dẫn đầu)', () {
      final cur = _rep([
        _m('a', 'Alpha', orders: 800, revenue: 80000000),
        _m('b', 'Beta', orders: 100, revenue: 10000000),
        _m('c', 'Gama', orders: 100, revenue: 10000000),
      ]);
      final t = _all(_ins(cur, null));
      expect(t, contains('Doanh thu tập trung: Alpha chiếm 80,0% cả chuỗi.'));
      expect(t, isNot(contains('dẫn đầu')));
    });
    test('chỉ một quán có đơn → không có câu dẫn đầu', () {
      final cur = _rep([_m('a', 'Alpha', orders: 300, revenue: 60000000), _m('b', 'Beta')]);
      expect(_all(_ins(cur, null)), isNot(contains('dẫn đầu')));
    });
  });

  group('Nhận xét — khi không có kỳ so sánh & giới hạn', () {
    test('không tải được kỳ trước → không có nhận xét tăng/giảm/im lặng/ngày nghỉ, vẫn có nhận xét tĩnh', () {
      final cur = _rep([_m('a', 'Alpha', orders: 300, revenue: 60000000), _m('b', 'Beta', orders: 200, revenue: 40000000)],
          [..._run('a', _curStart, 7, 40, 8000000, skip: {2}), ..._run('b', _curStart, 7, 30, 5000000)]);
      final t = _all(_ins(cur, null));
      expect(t, contains('dẫn đầu'));
      expect(t, isNot(contains('doanh thu giảm')));
      expect(t, isNot(contains('doanh thu tăng')));
      expect(t, isNot(contains('chưa có đơn nào, trong khi')));
      expect(t, isNot(contains('không có đơn ngày')));
    });
    test('không quá 6 nhận xét và cảnh báo (đỏ) luôn xếp trước', () {
      // 3 quán giảm/ngày nghỉ… dồn nhiều quy tắc cùng lúc
      final stores = ['a', 'b', 'c', 'd', 'e'];
      final cur = _rep([
        for (final s in stores) _m(s, s.toUpperCase(), orders: 400, revenue: 40000000, discount: s == 'a' ? 5000000 : 400000, voidAmount: s == 'b' ? 5000000 : 400000, voidCount: 9),
        _m('z', 'ZZ', firstKnown: true),
      ]);
      final ins = _ins(cur, null);
      expect(ins.length, lessThanOrEqualTo(InsightConfig.maxInsights));
      final firstInfo = ins.indexWhere((e) => e.kind == InsightKind.info);
      final lastWarn = ins.lastIndexWhere((e) => e.kind == InsightKind.warn);
      if (firstInfo != -1 && lastWarn != -1) expect(lastWarn < firstInfo, isTrue);
    });
    test('báo cáo không có cửa hàng nào → danh sách rỗng', () {
      expect(buildInsights(const [], _rep(const []), null, _w, now: _now), isEmpty);
    });
  });

  group('analyzeChainTotals', () {
    test('tổng chuỗi: đánh giá theo ngày có bán của cả chuỗi', () {
      final cur = _rep([_m('a', 'A', orders: 490, revenue: 49000000)], [..._run('a', _curStart, 7, 70, 7000000)]);
      final prev = _rep([_m('a', 'A', orders: 700, revenue: 70000000)], [..._run('a', _prevStart, 7, 100, 10000000)]);
      final r = analyzeChainTotals(cur, prev, _w);
      expect(r.revenue.verdict, Verdict.down);
      expect(r.orders.verdict, Verdict.down);
      expect(r.revenue.rawPct, closeTo(-30, 0.001));
    });
    test('không có kỳ trước → noBase', () {
      final cur = _rep([_m('a', 'A', orders: 490, revenue: 49000000)], [..._run('a', _curStart, 7, 70, 7000000)]);
      expect(analyzeChainTotals(cur, null, _w).revenue.verdict, Verdict.noBase);
    });
  });
}
