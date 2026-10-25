import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String src(String f) => File(f).readAsStringSync();

void main() {
  test(
    'Không còn đọc cả bảng lớn của quán rồi lọc ở máy (máy chủ cắt 1.000 dòng)',
    () {
      final checks = {
        'lib/modules/pos/repository/pos_repository.dart': "'orders'",
        'lib/modules/kho/repository/kho_repository.dart': "'stock_movements'",
        'lib/modules/ops/repository/ops_repository.dart': "'ops_daily_logs'",
      };
      checks.forEach((file, table) {
        final s = src(file);
        expect(
          RegExp(r"_robustStream\(\s*" + RegExp.escape(table)).hasMatch(s),
          isFalse,
          reason: '$file $table',
        );
        expect(s, contains('watchByRefetch('), reason: file);
      });
    },
  );

  test('Đơn hôm nay lọc ngày + trạng thái ở máy chủ, có phân trang', () {
    final s = src('lib/modules/pos/repository/pos_repository.dart');
    final body = s.substring(
      s.indexOf('Stream<List<OrderModel>> watchTodayOrders()'),
    );
    expect(body, contains(".gte('created_at', startOfDay)"));
    expect(body, contains(".eq('status', 'completed')"));
    expect(body, contains('.range(offset, end)'));
  });

  test('Vận hành lọc ngày ở máy chủ', () {
    final s = src('lib/modules/ops/repository/ops_repository.dart');
    expect(
      ".eq('log_date', today)".allMatches(s).length,
      greaterThanOrEqualTo(3),
    );
  });

  test('Sao lưu xuất đủ dữ liệu (theo trang)', () {
    final s = src('lib/features/backup/backup_screen.dart');
    expect('fetchAllPages('.allMatches(s).length, 6);
    expect(
      s,
      isNot(
        contains(
          ".eq('store_id', storeId).order('created_at', ascending: false);",
        ),
      ),
    );
  });

  test(
    'Khách hàng, lịch sử điểm/ví, Thu Chi theo dõi bằng truy vấn lọc ở máy chủ',
    () {
      final loy = src('lib/modules/loyalty/repository/loyalty_repository.dart');
      for (final t in [
        "'customers', 'store_id'",
        "'loyalty_transactions', 'store_id'",
        "'balance_transactions', 'store_id'",
      ]) {
        expect(loy, isNot(contains('_robustStream(\n      $t')), reason: t);
      }
      expect("table: 'customers'".allMatches(loy).length, 2);
      expect(
        src('lib/core/repositories/core_customer_repository.dart'),
        contains("table: 'customers'"),
      );
      expect(
        src('lib/modules/finance/repository/finance_repository.dart'),
        contains("table: 'finance_records'"),
      );
    },
  );

  test('Màn Đơn gần đây giữ một luồng, không tạo lại mỗi lần bấm', () {
    final s = src('lib/screens/pos_screen.dart');
    expect(s, contains('late final Stream<List<OrderModel>> _ordersStream'));
    expect(
      s,
      isNot(contains('final ordersStream = posRepo.watchTodayOrders();')),
    );
  });

  test(
    'Hàm theo dõi gỡ kênh khi đóng màn, gom thay đổi, không dùng .stream()',
    () {
      final s = src('lib/core/utils/paged_query.dart');
      expect(s, contains('onCancel:'));
      expect(s, contains('removeChannel'));
      expect(s, contains('dirty = true'));
      expect(s, isNot(contains('.stream(primaryKey')));
    },
  );

  test('Thống kê Khách hàng không cắt ở 1.000 khách', () {
    final s = src('lib/modules/loyalty/repository/loyalty_repository.dart');
    expect(s, contains('.count(CountOption.exact)'));
    expect(s, isNot(contains('.limit(10000);')));
    expect(s, contains('totalCustomers:   total.count'));
  });
}
