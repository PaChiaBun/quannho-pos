import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/bill_history_repository.dart';
import 'package:quannho_pos/core/utils/paged_query.dart';
import 'package:quannho_pos/modules/finance/repository/finance_repository.dart';

void main() {
  group(
    'Thu Chi tải đủ phiếu theo trang (máy chủ trả tối đa 1.000 dòng/lần)',
    () {
      for (final total in [0, 1, 999, 1000, 1001, 3161]) {
        test('$total phiếu → đủ $total, không trùng', () async {
          final calls = <List<int>>[];
          final rows = await fetchAllPages(fakeServer(total, calls));
          expect(rows.length, total);
          expect(rows.map((r) => r['id']).toSet().length, total);
          for (final c in calls) {
            expect(c[1] - c[0] + 1, 1000);
          }
        });
      }
      test('getStats và danh sách dùng fetchAllPages, sắp xếp cố định', () {
        final src = File(
          'lib/modules/finance/repository/finance_repository.dart',
        ).readAsStringSync();
        // Danh sách + thống kê kỳ này + kỳ trước (2 cái sau chạy song song, chờ chung).
        expect('fetchAllPages('.allMatches(src).length, 3);
        expect(src, contains(".order('id').range(offset, end)"));
      });
    },
  );

  test(
    '#8 Thu Chi "Tất cả" không cộng quỹ ví khách (giữ phiếu chưa có quỹ)',
    () {
      expect(kCashBookAllFundsFilter, 'fund_type.is.null,fund_type.neq.wallet');
      final src = File(
        'lib/modules/finance/repository/finance_repository.dart',
      ).readAsStringSync();
      // Danh sách, thống kê kỳ này và kỳ trước đều dùng cùng bộ lọc
      expect('query.or(kCashBookAllFundsFilter)'.allMatches(src).length, 2);
      expect(src, contains('prevQuery.or(kCashBookAllFundsFilter)'));
      expect(
        src,
        isNot(
          contains(
            "if (fundType != null) query = query.eq('fund_type', fundType);",
          ),
        ),
      );
    },
  );

  test('#35 Tra cứu bill tải theo trang, không dừng ở 500', () {
    expect(kBillLookupLimit, greaterThanOrEqualTo(10000));
    final src = File(
      'lib/core/repositories/bill_history_repository.dart',
    ).readAsStringSync();
    final body = src.substring(
      src.indexOf('Future<List<BillHistoryEntry>> listBills('),
    );
    expect(body, contains('.range(offset, end)'));
    expect(
      body.replaceAll(RegExp(r'\s+'), ''),
      contains(".order('id',ascending:false"),
    );
    expect(body, isNot(contains('.limit(limit)')));
  });
}

// Giả máy chủ: trả tối đa 1.000 dòng mỗi lần như PGRST_DB_MAX_ROWS.
Future<List<Map<String, dynamic>>> Function(int, int) fakeServer(
  int total,
  List<List<int>> calls,
) => (offset, end) async {
  calls.add([offset, end]);
  final stop = [end + 1, total, offset + 1000].reduce((a, b) => a < b ? a : b);
  return [
    for (var i = offset; i < stop; i++) {'id': '$i', 'amount': 1},
  ];
};
