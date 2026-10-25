import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/finance/fund_ledger_csv.dart';
import 'package:quannho_pos/modules/finance/repository/finance_repository.dart';

FinanceRecordModel rec(
  String id,
  String type,
  double amount,
  String fund,
  DateTime at, {
  String? desc,
}) => FinanceRecordModel(
  id: id,
  type: type,
  amount: amount,
  isAuto: false,
  recordedAt: at.toUtc(),
  fundType: fund,
  description: desc,
);

List<String> dataLines(String csv) => csv
    .split('\n')
    .where((l) => RegExp(r'^\d\d/\d\d/\d{4}').hasMatch(l))
    .toList();

void main() {
  final d = DateTime(2026, 10, 22, 9);
  final period = [
    rec('aaaaaaaa1', 'income', 100000, 'cash', d, desc: 'Bán hàng'),
    rec(
      'bbbbbbbb2',
      'expense',
      30000,
      'cash',
      d.add(const Duration(hours: 1)),
      desc: 'Mua đá, ly',
    ),
    rec(
      'cccccccc3',
      'income',
      200000,
      'bank',
      d.add(const Duration(hours: 2)),
      desc: 'Chuyển khoản',
    ),
    rec(
      'dddddddd4',
      'income',
      50000,
      'wallet',
      d.add(const Duration(hours: 3)),
      desc: 'Bán bằng ví',
    ),
    rec(
      'eeeeeeee5',
      'expense',
      99999,
      'all',
      d.add(const Duration(hours: 4)),
      desc: 'Phiếu lỗi quỹ all',
    ),
  ];

  test('Quỹ Tiền mặt: chỉ phiếu tiền mặt, tồn đầu/cuối đúng', () {
    final csv = buildFundLedgerCsv(
      periodRecords: period,
      fund: 'cash',
      openingBalance: 500000,
      periodLabel: 'Hôm nay',
      exportedAt: d,
    );
    expect(csv, contains('SỔ CHI TIẾT QUỸ TIỀN MẶT'));
    final lines = dataLines(csv);
    expect(lines.length, 2);
    expect(lines[0], endsWith(',100000,0,600000'));
    expect(lines[1], endsWith(',0,30000,570000'));
    expect(csv, contains('Số tồn đầu kỳ,,,500000'));
    expect(csv, contains('Cộng phát sinh trong kỳ,100000,30000,'));
    expect(csv, contains('Số tồn cuối kỳ,,,570000'));
  });

  test('Quỹ Tiền gửi: tiêu đề và số liệu đúng quỹ', () {
    final csv = buildFundLedgerCsv(
      periodRecords: period,
      fund: 'bank',
      openingBalance: 0,
      periodLabel: 'x',
      exportedAt: d,
    );
    expect(csv, contains('SỔ CHI TIẾT QUỸ TIỀN GỬI NGÂN HÀNG'));
    expect(dataLines(csv).single, endsWith(',200000,0,200000'));
  });

  test('"Tất cả" = Tiền mặt + Tiền gửi; loại ví khách và phiếu lỗi quỹ', () {
    final csv = buildFundLedgerCsv(
      periodRecords: period,
      fund: 'all',
      openingBalance: 1000,
      periodLabel: 'x',
      exportedAt: d,
    );
    expect(csv, contains('SỔ CHI TIẾT QUỸ TIỀN MẶT + TIỀN GỬI'));
    expect(csv, isNot(contains('TIỀN GỬI NGÂN HÀNG')));
    expect(csv, contains('Không gồm bán bằng ví khách'));
    final lines = dataLines(csv);
    expect(lines.length, 3);
    expect(lines.last, endsWith(',200000,0,271000'));
    expect(csv, isNot(contains('Bán bằng ví')));
    expect(csv, isNot(contains('Phiếu lỗi quỹ all')));
    expect(lines.map((l) => l.split(',')[3]).toList(), [
      'Tiền mặt',
      'Tiền mặt',
      'Tiền gửi',
    ]);
  });

  test('Tồn đầu kỳ theo đúng quỹ, bỏ ví và quỹ lỗi', () {
    final before = [
      rec('1', 'income', 1000, 'cash', d),
      rec('2', 'expense', 300, 'cash', d),
      rec('3', 'income', 5000, 'bank', d),
      rec('4', 'income', 9999, 'wallet', d),
      rec('5', 'expense', 7777, 'all', d),
    ];
    expect(ledgerBalance(before, 'cash'), 700);
    expect(ledgerBalance(before, 'bank'), 5000);
    expect(ledgerBalance(before, 'all'), 5700);
  });

  test('Thứ tự theo thời gian, không phụ thuộc thứ tự đầu vào', () {
    final shuffled = [period[2], period[1], period[0]];
    final csv = buildFundLedgerCsv(
      periodRecords: shuffled,
      fund: 'all',
      openingBalance: 0,
      periodLabel: 'x',
      exportedAt: d,
    );
    final lines = dataLines(csv);
    expect(lines.map((l) => l.split(',').last).toList(), [
      '100000',
      '70000',
      '270000',
    ]);
  });

  test('Ô có dấu phẩy / ngoặc kép được bọc đúng chuẩn CSV, đủ 8 cột', () {
    expect(csvCell('Mua đá, ly'), '"Mua đá, ly"');
    expect(csvCell('Nói "cảm ơn"'), '"Nói ""cảm ơn"""');
    expect(csvCell('dòng 1\ndòng 2'), 'dòng 1 dòng 2');
    final csv = buildFundLedgerCsv(
      periodRecords: period,
      fund: 'cash',
      openingBalance: 0,
      periodLabel: 'x',
      exportedAt: d,
    );
    expect(csv, contains('"Mua đá, ly"'));
    final line = dataLines(csv)[1];
    final cells = RegExp(
      r'("([^"]|"")*"|[^,]*)(,|$)',
    ).allMatches(line).map((m) => m.group(1)).toList();
    expect(cells.where((c) => c != null).length, greaterThanOrEqualTo(8));
  });

  test('Có BOM để Excel đọc tiếng Việt', () {
    final csv = buildFundLedgerCsv(
      periodRecords: period,
      fund: 'cash',
      openingBalance: 0,
      periodLabel: 'x',
      exportedAt: d,
    );
    expect(csv.startsWith('﻿'), isTrue);
  });

  test('Không còn ghi "Giá vốn NL" vào Thu Chi', () {
    final src = File(
      'lib/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart',
    ).readAsStringSync();
    final start = src.indexOf('Future<void> deductIngredients(');
    final body = src.substring(
      start,
      src.indexOf('// PRODUCTION ORDERS', start),
    );
    expect(body, isNot(contains("from('finance_records')")));
  });

  test('Ghi thu/chi khi đang xem "Tất cả" không lưu quỹ "all"', () {
    final src = File(
      'lib/modules/finance/screens/add_transaction_sheet.dart',
    ).readAsStringSync();
    expect(src, contains("_fundType = fund == 'bank' ? 'bank' : 'cash';"));
  });

  test('Xuất file tải đủ dữ liệu theo trang, chạy được trên web', () {
    final src = File('lib/screens/finance_screen.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _exportToCSV(');
    final body = src.substring(
      start,
      src.indexOf('// TRANSACTION LIST', start),
    );
    expect(body, contains('fetchAllRecords('));
    expect(body, contains('XFile.fromData('));
    expect(body, isNot(contains('getTemporaryDirectory')));
    final repo = File(
      'lib/modules/finance/repository/finance_repository.dart',
    ).readAsStringSync();
    expect(repo, contains('.range(offset, offset + page - 1)'));
  });

  test('Diễn giải bắt đầu bằng = + - @ không thành công thức Excel', () {
    expect(csvCell('=HYPERLINK("x")'), '"\'=HYPERLINK(""x"")"');
    expect(csvCell('-50000'), "'-50000");
    expect(csvCell('@sum'), "'@sum");
    expect(csvCell('Bán hàng'), 'Bán hàng');
  });
}
