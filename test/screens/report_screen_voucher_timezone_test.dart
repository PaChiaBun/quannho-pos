import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/screens/report_screen.dart';
import 'package:quannho_pos/modules/finance/repository/finance_repository.dart';

void main() {
  group('ReportPeriodX.rangeFor & Timezone UTC', () {
    test('ReportPeriod.today covers full 24-hour cycle', () {
      final target = DateTime(2026, 9, 14);
      final (from, to) = ReportPeriod.today.rangeFor(selectedDay: target);
      final start = DateTime.fromMillisecondsSinceEpoch(from);
      final end = DateTime.fromMillisecondsSinceEpoch(to);

      expect(start, equals(DateTime(2026, 9, 14, 0, 0, 0)));
      expect(end, equals(DateTime(2026, 9, 15, 0, 0, 0)));
      expect(end.difference(start).inHours, equals(24));

      // Test UTC conversion
      final startUtc = start.toUtc().toIso8601String();
      final endUtc = end.toUtc().toIso8601String();
      expect(startUtc.endsWith('Z'), isTrue);
      expect(endUtc.endsWith('Z'), isTrue);
    });

    test('ReportPeriod.week covers full 7-day cycle across month boundary', () {
      final mon = DateTime(2026, 8, 31); // Monday
      final (from, to) = ReportPeriod.week.rangeFor(weekStart: mon);
      final start = DateTime.fromMillisecondsSinceEpoch(from);
      final end = DateTime.fromMillisecondsSinceEpoch(to);

      expect(start, equals(DateTime(2026, 8, 31, 0, 0, 0)));
      expect(end, equals(DateTime(2026, 9, 7, 0, 0, 0)));
      expect(end.difference(start).inDays, equals(7));
    });

    test('ReportPeriod.month covers full month including leap year Feb 2024', () {
      final (from, to) = ReportPeriod.month.rangeFor(navYear: 2024, navMonth: 2);
      final start = DateTime.fromMillisecondsSinceEpoch(from);
      final end = DateTime.fromMillisecondsSinceEpoch(to);

      expect(start, equals(DateTime(2024, 2, 1, 0, 0, 0)));
      expect(end, equals(DateTime(2024, 3, 1, 0, 0, 0)));
      expect(end.difference(start).inDays, equals(29)); // 2024 is leap year
    });

    test('ReportPeriod.month covers year boundary Dec -> Jan', () {
      final (from, to) = ReportPeriod.month.rangeFor(navYear: 2026, navMonth: 12);
      final start = DateTime.fromMillisecondsSinceEpoch(from);
      final end = DateTime.fromMillisecondsSinceEpoch(to);

      expect(start, equals(DateTime(2026, 12, 1, 0, 0, 0)));
      expect(end, equals(DateTime(2027, 1, 1, 0, 0, 0)));
      expect(end.difference(start).inDays, equals(31));
    });
  });

  group('Finance DateRange Boundary Tests', () {
    test('DateRange.thisWeek() covers full 7 days without capEnd truncation', () {
      final range = DateRange.thisWeek();
      final duration = range.to.difference(range.from);
      expect(duration.inDays, equals(7));
    });

    test('DateRange.thisMonth() ends on 1st of next month', () {
      final range = DateRange.thisMonth();
      final now = DateTime.now();
      final expectedStart = DateTime(now.year, now.month, 1).toUtc();
      final expectedEnd = DateTime(now.year, now.month + 1, 1).toUtc();

      expect(range.from, equals(expectedStart));
      expect(range.to, equals(expectedEnd));
    });
  });

  group('Voucher Code Extraction & Regex Tests', () {
    final voucherRegex = RegExp(r'\[Voucher:\s*([^\]]+)\]', caseSensitive: false);
    final altVoucherRegex = RegExp(r'(?:Voucher|Mã giảm giá|Coupon):\s*([A-Za-z0-9_-]+)', caseSensitive: false);

    String? parseCode(String note) {
      final match = voucherRegex.firstMatch(note);
      if (match != null) return match.group(1)?.trim().toUpperCase();
      final altMatch = altVoucherRegex.firstMatch(note);
      if (altMatch != null) return altMatch.group(1)?.trim().toUpperCase();
      return null;
    }

    test('Extracts standard voucher tags in various formats', () {
      expect(parseCode('[Voucher: GIAM30]'), equals('GIAM30'));
      expect(parseCode('[voucher: sale2026]'), equals('SALE2026'));
      expect(parseCode('[VOUCHER:  TET_QUAN_NHO  ]'), equals('TET_QUAN_NHO'));
      expect(parseCode('Bàn 2 | [Voucher: VIP] | Ghi chú thêm'), equals('VIP'));
      expect(parseCode('Coupon: PROMO10'), equals('PROMO10'));
      expect(parseCode('Mã giảm giá: DISCOUNT50'), equals('DISCOUNT50'));
      expect(parseCode('Không có voucher'), isNull);
    });
  });

  group('Staff Resolution Fallback Logic Tests', () {
    final staffMap = {
      'staff-1': 'Nguyễn Văn Thu Ngân',
      'staff-2': 'Phục Vụ Bàn 1',
    };

    String resolveStaff(String? primaryId, [String? secondaryId, String fallback = 'Thu ngân']) {
      if (primaryId != null && staffMap.containsKey(primaryId) && staffMap[primaryId]!.isNotEmpty) {
        return staffMap[primaryId]!;
      }
      if (secondaryId != null && staffMap.containsKey(secondaryId) && staffMap[secondaryId]!.isNotEmpty) {
        return staffMap[secondaryId]!;
      }
      final id = (primaryId != null && primaryId.isNotEmpty)
          ? primaryId
          : ((secondaryId != null && secondaryId.isNotEmpty) ? secondaryId : null);
      if (id != null) {
        final short = id.length >= 4 ? id.substring(id.length - 4).toUpperCase() : id;
        return 'NV-$short';
      }
      return fallback;
    }

    test('Resolves primary staff ID when present', () {
      expect(resolveStaff('staff-1'), equals('Nguyễn Văn Thu Ngân'));
    });

    test('Falls back to secondary ID when primary is null', () {
      expect(resolveStaff(null, 'staff-2'), equals('Phục Vụ Bàn 1'));
    });

    test('Generates NV-XXXX short tag for unknown staff ID instead of empty or generic string', () {
      expect(resolveStaff('12345678-abcd-ef01-2345-6789abcdef99'), equals('NV-EF99'));
    });

    test('Falls back to default string when both IDs are null', () {
      expect(resolveStaff(null, null, 'Thu ngân bàn'), equals('Thu ngân bàn'));
    });
  });

  group('Safe Table Name & ID Mapping Tests', () {
    test('Handles numeric and legacy non-string table IDs without crash', () {
      final tables = [
        {'id': 101, 'name': 3, 'label': null},
        {'id': 'uuid-table-2', 'name': null, 'label': 'Bàn VIP 1'},
        {'id': 'uuid-table-3', 'name': '', 'label': ''},
      ];
      final tableMap = <String, String>{};
      for (final t in tables) {
        final tId = t['id']?.toString();
        final name = t['name']?.toString().trim();
        final label = t['label']?.toString().trim();
        final display = (name != null && name.isNotEmpty)
            ? name
            : ((label != null && label.isNotEmpty) ? label : 'Bàn');
        if (tId != null && tId.isNotEmpty) tableMap[tId] = display;
      }

      expect(tableMap['101'], equals('3'));
      expect(tableMap['uuid-table-2'], equals('Bàn VIP 1'));
      expect(tableMap['uuid-table-3'], equals('Bàn'));
    });
  });

  group('Table Settlement & POS Deduplication Tests', () {
    test('Deduplicates linked table orders from double counting', () {
      final linkedOrderIds = {'order-1'};
      final processedSettleIds = {'settle-1'};

      final settlements = [
        {'id': 'settle-1', 'coupon_code': 'GIAM50', 'discount': 50000.0},
      ];
      final orders = [
        {'id': 'order-1', 'discount': 50000.0, 'note': '[Voucher: GIAM50]'},
        {'id': 'order-2', 'discount': 20000.0, 'note': '[Voucher: GIAM20]'},
      ];

      int totalOrders = 0;
      double totalDiscount = 0;

      for (final s in settlements) {
        totalOrders++;
        totalDiscount += (s['discount'] as num).toDouble();
      }

      for (final o in orders) {
        final oId = o['id'] as String;
        if (linkedOrderIds.contains(oId) || processedSettleIds.contains(oId)) {
          continue;
        }
        totalOrders++;
        totalDiscount += (o['discount'] as num).toDouble();
      }

      expect(totalOrders, equals(2));
      expect(totalDiscount, equals(70000.0));
    });
  });
}
