// Kiểm Sunmi Bò Đen 03/11/2026 (đọc-chỉ, 11 lỗi): các phần có logic của bản sửa.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quannho_pos/core/utils/quantity_formatter.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';
import 'package:quannho_pos/features/ai_assistant/services/boom_module_data_service.dart';
import 'package:quannho_pos/modules/finance/repository/finance_repository.dart';
import 'package:quannho_pos/screens/report_screen.dart';

void main() {
  setUpAll(() => initializeDateFormatting('vi'));

  group('A5 — so "tăng/giảm" cùng khoảng giờ với kỳ trước', () {
    final today = DateRange(
      from: DateTime(2026, 11, 3).toUtc(),
      to: DateTime(2026, 11, 4).toUtc(),
      label: 'Hôm nay',
    );

    test('1 giờ sáng: so với 0:00–1:12 hôm qua, không phải cả ngày hôm qua', () {
      final (from, to) = previousComparablePeriod(today, DateTime(2026, 11, 3, 1, 12));
      expect(from.toLocal(), DateTime(2026, 11, 2));
      expect(to.toLocal(), DateTime(2026, 11, 2, 1, 12));
    });

    test('kỳ đã hết: so trọn kỳ trước như cũ', () {
      final (from, to) = previousComparablePeriod(today, DateTime(2026, 11, 5, 9));
      expect(from.toLocal(), DateTime(2026, 11, 2));
      expect(to.toLocal(), DateTime(2026, 11, 3));
    });

    test('kỳ chưa tới: kỳ trước rỗng (không so)', () {
      final (from, to) = previousComparablePeriod(today, DateTime(2026, 11, 1));
      expect(to, from);
    });
  });

  group('A3 — tồn kho một kiểu ở mọi màn kho', () {
    test('có quy cách: số lẻ đổi ra đơn vị nhỏ', () {
      expect(fmtStock(99.329, 'lon', conversionRate: 1361, conversionUnit: 'g'), '99 lon + 448 g');
      expect(fmtStock(88.666, 'hộp', conversionRate: 1000, conversionUnit: 'ml'), '88 hộp + 666 ml');
      expect(fmtStock(0.25, 'hộp', conversionRate: 1000, conversionUnit: 'ml'), '250 ml');
      expect(fmtStock(-2.5, 'hộp', conversionRate: 1000, conversionUnit: 'ml'), '-2 hộp + 500 ml');
      expect(fmtStock(0, 'lon', conversionRate: 1361, conversionUnit: 'g'), '0 lon');
    });

    test('phần lẻ làm tròn đủ 1 đơn vị thì cộng lên, không ghi "+ 1000 ml"', () {
      expect(fmtStock(88.9996, 'hộp', conversionRate: 1000, conversionUnit: 'ml'), '89 hộp');
    });

    test('không có quy cách: dấu phẩy thập phân, không đọc nhầm hàng nghìn', () {
      expect(fmtStock(78.889, 'gói'), '78,889 gói');
      expect(fmtStock(50, 'gói'), '50 gói');
    });
  });

  group('A4 — Boom: món có công thức không cộng vào giá trị kho', () {
    test('tồn để sẵn của món có công thức bị bỏ, nguyên liệu vẫn tính', () {
      final k = boomKhoFacts(
        products: [
          {'id': 'tra-sua', 'name': 'Trà sữa', 'stock_qty': 1000, 'min_stock': 10, 'cost_price': 11834},
          {'id': 'sua', 'name': 'Sữa', 'stock_qty': 5, 'min_stock': 1, 'cost_price': 30000},
        ],
        purchases: const [],
        waste: const [],
        recipeProductIds: const {'tra-sua'},
        period: 'Tháng này',
        withCost: true,
      );
      expect(k['stock_value'], 5 * 30000);
    });
  });

  group('B3 — chữ kỳ báo cáo theo đúng ngày đang xem', () {
    final now = DateTime(2026, 11, 3, 1, 12);
    String phrase(ReportPeriod p, {DateTime? day, DateTime? week, int year = 2026, int month = 11}) =>
        reportPeriodPhrase(p,
            day: day ?? now, weekStart: week ?? DateTime(2026, 11, 2), year: year, month: month, now: now);

    test('ngày', () {
      expect(phrase(ReportPeriod.today), 'hôm nay');
      expect(phrase(ReportPeriod.today, day: DateTime(2026, 11, 2, 23)), 'hôm qua');
      expect(phrase(ReportPeriod.today, day: DateTime(2026, 10, 30)), 'ngày 30/10');
    });

    test('tuần, tháng', () {
      expect(phrase(ReportPeriod.week), 'tuần này');
      expect(phrase(ReportPeriod.week, week: DateTime(2026, 10, 26)), 'tuần 26/10–01/11');
      expect(phrase(ReportPeriod.month), 'tháng này');
      expect(phrase(ReportPeriod.month, month: 10), 'tháng 10/2026');
    });
  });

  group('B6 — "Thanh toán bàn bàn 13" bỏ chữ lặp', () {
    test('tên bàn có sẵn chữ "Bàn"', () {
      expect(tidyFinanceDescription('Thanh toán bàn bàn 13'), 'Thanh toán bàn 13');
      expect(tidyFinanceDescription('Thanh toán bàn Bàn 1 [Voucher: KM10]'), 'Thanh toán Bàn 1 [Voucher: KM10]');
    });

    test('tên bàn không có chữ "Bàn" và dòng khác giữ nguyên', () {
      expect(tidyFinanceDescription('Thanh toán bàn MV 1'), 'Thanh toán bàn MV 1');
      expect(tidyFinanceDescription('Bán hàng #QN-20261102-005'), 'Bán hàng #QN-20261102-005');
      expect(tidyFinanceDescription(null), isNull);
    });
  });
}
