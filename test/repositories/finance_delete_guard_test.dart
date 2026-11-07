import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Xoá phiếu thu chi phải đi qua RPC có kiểm quyền + lưu vết; app không được xoá thẳng bảng
// (máy chủ đã chặn bằng trigger guard_finance_records_v1).
void main() {
  test(
    'FinanceRepository.deleteRecord gọi RPC, không xoá thẳng finance_records',
    () {
      final src = File(
        'lib/modules/finance/repository/finance_repository.dart',
      ).readAsStringSync();
      final start = src.indexOf('Future<bool> deleteRecord(');
      expect(start, greaterThan(0));
      final body = src.substring(
        start,
        src.indexOf('// ── Records — Queries', start),
      );
      expect(body, contains("rpc('delete_manual_finance_record_v1'"));
      expect(body, contains("'p_reason'"));
      expect(body, isNot(contains('.delete()')));
    },
  );

  test('Không còn chỗ nào trong app sửa/xoá thẳng finance_records', () {
    final offenders = <String>[];
    for (final f in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('.g.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(
        r"from\('finance_records'\)([\s\S]{0,200})",
      ).allMatches(src)) {
        final chain = m.group(1)!.split(';').first;
        if (RegExp(r'\.(delete|update|upsert)\(').hasMatch(chain))
          offenders.add(f.path);
      }
    }
    expect(offenders, isEmpty);
  });

  test('Hộp xoá giao dịch bắt buộc lý do và ghi log nghiệp vụ', () {
    final src = File('lib/screens/finance_screen.dart').readAsStringSync();
    final start = src.indexOf('void _confirmDelete(');
    final body = src.substring(
      start,
      src.indexOf('class _TransactionCard', start),
    );
    expect(body, contains('Lý do xoá *'));
    expect(body, contains('deleteRecord(record.id, reason: reason)'));
    expect(body, contains("'finance_record_delete'"));
  });
}
