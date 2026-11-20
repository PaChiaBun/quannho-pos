import 'package:intl/intl.dart';

import 'repository/finance_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SỔ CHI TIẾT QUỸ (CSV) — tính thuần, không gọi mạng, để test được.
// Chỉ tiền thật của quán: Tiền mặt + Tiền gửi. Bán bằng ví khách KHÔNG vào sổ quỹ
// (tiền đã thu lúc nạp ví). Phiếu chưa có quỹ (NULL) được đọc thành Tiền mặt (FinanceRecordModel).
// ─────────────────────────────────────────────────────────────────────────────

/// Các quỹ thuộc sổ khi chọn [fund] ('cash' | 'bank' | 'all').
Set<String> ledgerFunds(String fund) =>
    fund == 'cash' || fund == 'bank' ? {fund} : const {'cash', 'bank'};

String ledgerFundTitle(String fund) => switch (fund) {
  'cash' => 'TIỀN MẶT',
  'bank' => 'TIỀN GỬI NGÂN HÀNG',
  _ => 'TIỀN MẶT + TIỀN GỬI',
};

String _fundLabel(String f) => f == 'bank' ? 'Tiền gửi' : 'Tiền mặt';

/// Số dư = thu − chi của các phiếu thuộc sổ.
double ledgerBalance(Iterable<FinanceRecordModel> records, String fund) {
  final funds = ledgerFunds(fund);
  var b = 0.0;
  for (final r in records) {
    if (!funds.contains(r.fundType)) continue;
    if (r.type == 'income') b += r.amount;
    if (r.type == 'expense') b -= r.amount;
  }
  return b;
}

/// Bọc ô CSV đúng chuẩn: có dấu phẩy, ngoặc kép hoặc xuống dòng thì đặt trong "…".
/// Ô bắt đầu bằng = + - @ được thêm dấu ' để Excel không chạy như công thức.
String csvCell(String v) {
  var s = v.replaceAll('\r', ' ').replaceAll('\n', ' ');
  if (s.isNotEmpty && '=+-@'.contains(s[0])) s = "'$s";
  if (s.contains(',') || s.contains('"')) return '"${s.replaceAll('"', '""')}"';
  return s;
}

String _money(double v) => v.toStringAsFixed(0);

/// Dựng nội dung CSV. [periodRecords] là MỌI phiếu trong kỳ (không lọc Thu/Chi),
/// [openingBalance] là số dư trước kỳ của đúng các quỹ thuộc sổ.
String buildFundLedgerCsv({
  required List<FinanceRecordModel> periodRecords,
  required String fund,
  required double openingBalance,
  required String periodLabel,
  required DateTime exportedAt,
}) {
  final funds = ledgerFunds(fund);
  final rows =
      periodRecords
          .where(
            (r) =>
                funds.contains(r.fundType) &&
                (r.type == 'income' || r.type == 'expense'),
          )
          .toList()
        ..sort((a, b) {
          final c = a.recordedAt.compareTo(b.recordedAt);
          return c != 0 ? c : a.id.compareTo(b.id);
        });

  final out = StringBuffer()..write('﻿'); // BOM: Excel đọc đúng tiếng Việt
  out.writeln(csvCell('SỔ CHI TIẾT QUỸ ${ledgerFundTitle(fund)}'));
  out.writeln(csvCell('Kỳ báo cáo: $periodLabel'));
  out.writeln(
    csvCell(
      'Thời gian xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(exportedAt)}',
    ),
  );
  if (fund != 'cash' && fund != 'bank') {
    out.writeln(
      csvCell(
        'Gồm Tiền mặt và Tiền gửi. Không gồm bán bằng ví khách (đã ghi thu lúc nạp ví).',
      ),
    );
  }
  out.writeln();
  out.writeln(
    'Ngày chứng từ,Số phiếu thu,Số phiếu chi,Quỹ,Diễn giải,Số tiền thu,Số tiền chi,Số tiền còn lại',
  );
  out.writeln(',,,,Số tồn đầu kỳ,,,${_money(openingBalance)}');

  var balance = openingBalance;
  var totalIn = 0.0;
  var totalOut = 0.0;
  for (final r in rows) {
    final isIncome = r.type == 'income';
    if (isIncome) {
      balance += r.amount;
      totalIn += r.amount;
    } else {
      balance -= r.amount;
      totalOut += r.amount;
    }
    final code = r.id.length >= 8 ? r.id.substring(0, 8).toUpperCase() : r.id;
    out.writeln(
      [
        DateFormat('dd/MM/yyyy HH:mm').format(r.recordedAt.toLocal()),
        isIncome ? 'PT-$code' : '',
        isIncome ? '' : 'PC-$code',
        _fundLabel(r.fundType),
        csvCell(r.description ?? ''),
        isIncome ? _money(r.amount) : '0',
        isIncome ? '0' : _money(r.amount),
        _money(balance),
      ].join(','),
    );
  }
  out.writeln(
    ',,,,Cộng phát sinh trong kỳ,${_money(totalIn)},${_money(totalOut)},',
  );
  out.writeln(',,,,Số tồn cuối kỳ,,,${_money(balance)}');
  return out.toString();
}
