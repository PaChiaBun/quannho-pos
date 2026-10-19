import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/core/utils/chain_compare.dart';

StoreMetrics _m(String id, String name, {int orders = 0, double revenue = 0, double disc = 0}) => StoreMetrics(
  storeId: id, name: name, orders: orders, revenue: revenue,
  avgOrderValue: orders > 0 ? revenue / orders : 0, discount: disc,
);

ChainReport _report(List<StoreMetrics> stores, {List<ChainDailyPoint> daily = const []}) {
  final rev = stores.fold<double>(0, (a, s) => a + s.revenue);
  final ord = stores.fold<int>(0, (a, s) => a + s.orders);
  final disc = stores.fold<double>(0, (a, s) => a + s.discount);
  return ChainReport(
    chainId: 'c', chainName: 'Chuoi', stores: stores, storeCount: stores.length, daily: daily, excluded: const [],
    totals: StoreMetrics(storeId: '', name: 'Tổng', orders: ord, revenue: rev, avgOrderValue: ord > 0 ? rev / ord : 0, discount: disc),
  );
}

void main() {
  group('growthPct', () {
    test('tính % đúng', () => expect(growthPct(150, 100), 50));
    test('giảm là số âm', () => expect(growthPct(75, 100), -25));
    test('kỳ trước = 0 → null (không có gốc để so)', () {
      expect(growthPct(100, 0), isNull);
      expect(growthPct(0, 0), isNull);
    });
  });

  test('fmtPct dùng dấu phẩy và dấu +/-', () {
    expect(fmtPct(12.345), '12,3%');
    expect(fmtPct(12.345, signed: true), '+12,3%');
    expect(fmtPct(-4.0, signed: true), '-4,0%');
  });

  group('windowFor', () {
    final now = DateTime(2026, 10, 16, 15, 0); // Thứ Sáu
    test('hôm nay: so với CÙNG THỨ tuần trước, cùng giờ (không so với hôm qua vì nhịp theo thứ)', () {
      final w = windowFor(ChainPeriod.day, 0, now);
      expect(w.from, DateTime(2026, 10, 16));
      expect(w.to, DateTime(2026, 10, 17));
      expect(w.compareFrom, DateTime(2026, 10, 9));
      expect(w.compareTo, DateTime(2026, 10, 9, 15));
      expect(w.compareIsPartial, isTrue);
      expect(w.compareLabel, 'cùng thứ tuần trước');
      expect(w.label, 'Hôm nay');
      expect(w.canGoNext, isFalse);
    });
    test('hôm qua: so với trọn cùng thứ tuần trước, có thể đi tiếp', () {
      final w = windowFor(ChainPeriod.day, -1, now);
      expect(w.label, 'Hôm qua');
      expect(w.compareFrom, DateTime(2026, 10, 8));
      expect(w.compareTo, DateTime(2026, 10, 9));
      expect(w.compareIsPartial, isFalse);
      expect(w.canGoNext, isTrue);
    });
    test('tuần này bắt đầu thứ Hai; so với cùng khoảng đã trôi của tuần trước', () {
      final w = windowFor(ChainPeriod.week, 0, now);
      expect(w.from, DateTime(2026, 10, 12));
      expect(w.to, DateTime(2026, 10, 19));
      expect(w.compareFrom, DateTime(2026, 10, 5));
      expect(w.compareTo, DateTime(2026, 10, 5).add(now.difference(DateTime(2026, 10, 12))));
      expect(w.compareIsPartial, isTrue);
    });
    test('tuần đã qua: so với trọn tuần trước', () {
      final w = windowFor(ChainPeriod.week, -1, now);
      expect(w.from, DateTime(2026, 10, 5));
      expect(w.compareFrom, DateTime(2026, 9, 28));
      expect(w.compareTo, DateTime(2026, 10, 5));
      expect(w.label, '05/10–11/10');
      expect(w.compareLabel, 'tuần trước');
    });
    test('tháng: nhãn và lùi qua đầu năm', () {
      final w = windowFor(ChainPeriod.month, -10, DateTime(2026, 3, 20));
      expect(w.from, DateTime(2025, 5, 1));
      expect(w.to, DateTime(2025, 6, 1));
      expect(w.label, 'Tháng 5 / 2025');
      expect(w.compareFrom, DateTime(2025, 4, 1));
    });
    test('tháng hiện tại so một phần với tháng trước (không vượt quá tháng trước)', () {
      final w = windowFor(ChainPeriod.month, 0, DateTime(2026, 3, 31, 12));
      expect(w.compareFrom, DateTime(2026, 2, 1));
      expect(w.compareTo, DateTime(2026, 3, 1)); // tháng 2 ngắn hơn: cắt ở hết tháng 2
    });
    test('offset dương bị kéo về 0', () {
      expect(windowFor(ChainPeriod.day, 3, now).label, 'Hôm nay');
    });
  });

  group('buildRows / sortedBy', () {
    final cur = _report([_m('b', 'Beta', orders: 10, revenue: 1000), _m('a', 'Alpha', orders: 5, revenue: 3000)]);
    final prev = _report([_m('a', 'Alpha', orders: 4, revenue: 2000)]);

    test('màu theo thứ tự tên, ổn định dù xếp hạng đổi', () {
      final rows = buildRows(cur, prev);
      expect(rows.firstWhere((r) => r.id == 'a').colorIndex, 0);
      expect(rows.firstWhere((r) => r.id == 'b').colorIndex, 1);
    });
    test('tăng trưởng đúng; quán không có ở kỳ trước → prev=0 → null', () {
      final rows = buildRows(cur, prev);
      expect(rows.firstWhere((r) => r.id == 'a').growth(CompareMetric.revenue), 50);
      expect(rows.firstWhere((r) => r.id == 'b').growth(CompareMetric.revenue), isNull);
    });
    test('không có báo cáo kỳ trước → mọi tăng trưởng null', () {
      expect(buildRows(cur, null).every((r) => r.growth(CompareMetric.revenue) == null), isTrue);
    });
    test('sắp theo chỉ số', () {
      final rows = buildRows(cur, null);
      expect(sortedBy(rows, CompareMetric.revenue).first.id, 'a');
      expect(sortedBy(rows, CompareMetric.orders).first.id, 'b');
      expect(sortedBy(rows, CompareMetric.avgOrder).first.id, 'a'); // 600 vs 100
    });
    test('tỷ trọng và trung bình chuỗi', () {
      final rows = buildRows(cur, null);
      expect(rows.firstWhere((r) => r.id == 'a').sharePct(cur.totals.revenue), 75);
      expect(chainAverage(cur, CompareMetric.revenue), 2000);
      expect(chainAverage(cur, CompareMetric.orders), 7.5);
      expect(chainAverage(cur, CompareMetric.avgOrder), cur.totals.avgOrderValue);
    });
    test('chuỗi rỗng không chia cho 0', () {
      expect(chainAverage(_report([]), CompareMetric.revenue), 0);
    });
  });

  group('buildDailyTrend', () {
    test('điền 0 cho ngày thiếu và gộp theo quán', () {
      final cur = _report(
        [_m('a', 'A', orders: 2, revenue: 300), _m('b', 'B', orders: 1, revenue: 50)],
        daily: const [
          ChainDailyPoint(date: '2026-10-01', storeId: 'a', orders: 1, revenue: 100),
          ChainDailyPoint(date: '2026-10-03', storeId: 'a', orders: 1, revenue: 200),
          ChainDailyPoint(date: '2026-10-02', storeId: 'b', orders: 1, revenue: 50),
          ChainDailyPoint(date: '2026-12-31', storeId: 'a', orders: 1, revenue: 999), // ngoài kỳ: bỏ
          ChainDailyPoint(date: '2026-10-01', storeId: 'zzz', orders: 1, revenue: 999), // quán lạ: bỏ
        ],
      );
      final t = buildDailyTrend(cur, DateTime(2026, 10, 1), DateTime(2026, 10, 4));
      expect(t.dates, ['2026-10-01', '2026-10-02', '2026-10-03']);
      expect(t.byStore['a'], [100, 0, 200]);
      expect(t.byStore['b'], [0, 50, 0]);
      expect(t.maxValue, 200);
    });
    test('kỳ đang diễn ra: không vẽ các ngày chưa tới (không phải doanh thu 0)', () {
      final t = buildDailyTrend(_report([_m('a', 'A')]), DateTime(2026, 10, 12), DateTime(2026, 10, 19), now: DateTime(2026, 10, 14, 9));
      expect(t.dates, ['2026-10-12', '2026-10-13', '2026-10-14']);
    });
    test('kỳ đã kết thúc: giữ nguyên cả kỳ dù truyền now', () {
      final t = buildDailyTrend(_report([_m('a', 'A')]), DateTime(2026, 10, 5), DateTime(2026, 10, 12), now: DateTime(2026, 10, 20));
      expect(t.dates.length, 7);
    });
    test('giới hạn 62 ngày', () {
      final t = buildDailyTrend(_report([]), DateTime(2026, 1, 1), DateTime(2027, 1, 1));
      expect(t.dates.length, 62);
    });
  });
}
