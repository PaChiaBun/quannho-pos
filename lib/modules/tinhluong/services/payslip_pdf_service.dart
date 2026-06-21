// lib/modules/tinhluong/services/payslip_pdf_service.dart
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../repository/tinhluong_repository.dart';

class PayslipStoreInfo {
  final String name;
  final String phone;
  final String address;
  final String footer;
  const PayslipStoreInfo({
    required this.name,
    this.phone   = '',
    this.address = '',
    this.footer  = 'Cảm ơn bạn vì sự cố gắng trong tháng qua!',
  });
}

class PayslipPdfService {
  static final _fmtNum  = NumberFormat('#,###', 'vi_VN');
  static final _fmtDate = DateFormat('dd/MM/yyyy');

  static String _money(double v) => '${_fmtNum.format(v.round())}đ';
  static String _date(String iso) {
    try { return _fmtDate.format(DateTime.parse(iso)); } catch (_) { return iso; }
  }

  /// Load NotoSans — hỗ trợ tiếng Việt đầy đủ
  static Future<({pw.Font r, pw.Font b})> _fonts() async {
    final r = await PdfGoogleFonts.notoSansRegular();
    final b = await PdfGoogleFonts.notoSansBold();
    return (r: r, b: b);
  }

  // ─── A4 ────────────────────────────────────────────────────────────────────

  static Future<Uint8List> generateA4({
    required PayrollRecordModel record,
    required PayrollPeriodModel period,
    required List<PayrollItemModel> items,
    required PayslipStoreInfo store,
  }) async {
    final pdf  = pw.Document();
    final navy = PdfColor.fromHex('#1C2151');
    final ora  = PdfColor.fromHex('#FF6B35');
    final ft   = await _fonts();

    // Shorthand styles
    pw.TextStyle s({double sz = 11, PdfColor? c, bool bold = false}) => pw.TextStyle(
      font: bold ? ft.b : ft.r, fontSize: sz, color: c,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(color: navy, borderRadius: pw.BorderRadius.circular(12)),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(store.name, style: s(sz: 20, c: PdfColors.white, bold: true)),
                if (store.address.isNotEmpty) pw.Text(store.address, style: s(sz: 10, c: PdfColors.grey300)),
                if (store.phone.isNotEmpty)   pw.Text('SĐT: ${store.phone}', style: s(sz: 10, c: PdfColors.grey300)),
              ])),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('PHIẾU LƯƠNG', style: s(sz: 16, c: PdfColors.white, bold: true)),
                pw.Text(period.name, style: s(sz: 12, c: PdfColors.grey300)),
                pw.Text('${_date(period.fromDate)} - ${_date(period.toDate)}', style: s(sz: 10, c: PdfColors.grey300)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 20),

          // Staff Info
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: const PdfColor(0.98, 0.97, 0.94),
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: const PdfColor(0.88, 0.85, 0.80)),
            ),
            child: pw.Row(children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('Nhân viên', style: s(sz: 10, c: PdfColors.grey600)),
                pw.SizedBox(height: 2),
                pw.Text(record.staffName, style: s(sz: 16, bold: true)),
                if (record.role != null && record.role!.isNotEmpty)
                  pw.Text(record.role!, style: s(sz: 11, c: PdfColors.grey600)),
              ])),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text('Chế độ lương', style: s(sz: 10, c: PdfColors.grey600)),
                pw.Text(_modeLabel(record.salaryMode), style: s(sz: 13, bold: true)),
                pw.SizedBox(height: 4),
                pw.Text('Trạng thái thanh toán', style: s(sz: 10, c: PdfColors.grey600)),
                pw.Text(_payStatusLabel(record.paymentStatus), style: s(
                  sz: 13, bold: true,
                  c: record.paymentStatus == 'paid' ? PdfColors.green800 : PdfColors.orange800,
                )),
              ]),
            ]),
          ),
          pw.SizedBox(height: 20),

          // Attendance
          pw.Text('TÓM TẮT CHẤM CÔNG', style: s(sz: 11, bold: true, c: navy)),
          pw.SizedBox(height: 8),
          pw.Row(children: [
            _statBox('Tổng giờ làm',    '${record.totalHours.toStringAsFixed(1)}h', navy,    ft),
            pw.SizedBox(width: 8),
            _statBox('Tăng ca',         '${record.overtimeHours.toStringAsFixed(1)}h', navy, ft),
            pw.SizedBox(width: 8),
            _statBox('Nghỉ không phép', '${record.absentDays} ngày', PdfColors.red800,       ft),
            pw.SizedBox(width: 8),
            _statBox('Đi muộn',         '${record.lateCount} lần',   PdfColors.orange800,    ft),
          ]),
          pw.SizedBox(height: 20),

          // Salary table
          pw.Text('CHI TIẾT KHOẢN LƯƠNG', style: s(sz: 11, bold: true, c: navy)),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: const PdfColor(0.88, 0.85, 0.80), width: 0.5),
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1.5)},
            children: [
              _tableRow('Khoản mục', 'Số tiền', ft: ft, isHeader: true, navy: navy),
              _tableRow('Lương cơ bản (${_modeLabel(record.salaryMode)})',
                  _money(record.regularPay), ft: ft, isPositive: true),
              if (record.overtimePay > 0)
                _tableRow('Tăng ca (${record.overtimeHours.toStringAsFixed(1)}h)',
                    _money(record.overtimePay), ft: ft, isPositive: true),
              if (record.bonusRevenue > 0)
                _tableRow('Thưởng doanh thu', _money(record.bonusRevenue), ft: ft, isPositive: true),
              if (record.bonusManual > 0)
                _tableRow('Thưởng thủ công', _money(record.bonusManual), ft: ft, isPositive: true),
              // ‼️ FIX: Chỉ hiển thị từng item riêng — KHÔNG hiển thị allowanceTotal tổng hợp
              // vì allowanceTotal = sum(items bonus/allowance) → sẽ bị trùng lặp nếu in cả 2
              ...items.where((i) => i.itemType == 'bonus' || i.itemType == 'allowance')
                  .map((i) => _tableRow(i.label, _money(i.amount), ft: ft, isPositive: true)),
              if (record.deductionLate > 0)
                _tableRow('Trừ đi muộn (${record.lateCount} lần)',
                    '-${_money(record.deductionLate)}', ft: ft, isNegative: true),
              if (record.deductionAbsent > 0)
                _tableRow('Trừ nghỉ (${record.absentDays} ngày)',
                    '-${_money(record.deductionAbsent)}', ft: ft, isNegative: true),
              if (record.deductionManual > 0)
                _tableRow('Khấu trừ khác', '-${_money(record.deductionManual)}', ft: ft, isNegative: true),
              ...items.where((i) => i.itemType == 'deduction')
                  .map((i) => _tableRow(i.label, '-${_money(i.amount)}', ft: ft, isNegative: true)),
              _tableRow('Tổng (gross)', _money(record.grossPay), ft: ft, isBold: true),
            ],
          ),
          pw.SizedBox(height: 12),

          // Net Pay
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: pw.BoxDecoration(color: navy, borderRadius: pw.BorderRadius.circular(8)),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('THỰC LĨNH (NET)', style: s(sz: 14, bold: true, c: PdfColors.white)),
              pw.Text(_money(record.netPay), style: s(sz: 22, bold: true, c: ora)),
            ]),
          ),
          pw.SizedBox(height: 24),

          // Signature
          pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Chủ quán / Kế toán', style: s(sz: 11, bold: true)),
              pw.SizedBox(height: 40),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Text('Ký tên', style: s(sz: 10, c: PdfColors.grey600)),
            ])),
            pw.SizedBox(width: 40),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text('Nhân viên', style: s(sz: 11, bold: true)),
              pw.SizedBox(height: 40),
              pw.Container(height: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Text('Ký nhận', style: s(sz: 10, c: PdfColors.grey600)),
            ])),
          ]),
          pw.Spacer(),

          // Footer
          pw.Divider(color: const PdfColor(0.88, 0.85, 0.80)),
          pw.Center(child: pw.Text(store.footer, style: s(sz: 10, c: PdfColors.grey600))),
          pw.Center(child: pw.Text(
              'In lúc: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
              style: s(sz: 9, c: PdfColors.grey400))),
        ],
      ),
    ));
    return pdf.save();
  }

  // ─── 80mm ──────────────────────────────────────────────────────────────────

  static Future<Uint8List> generate80mm({
    required PayrollRecordModel record,
    required PayrollPeriodModel period,
    required List<PayrollItemModel> items,
    required PayslipStoreInfo store,
  }) async {
    final pdf  = pw.Document();
    final ft   = await _fonts();
    const w    = 72.0 * PdfPageFormat.mm;
    final fmt  = PdfPageFormat(80 * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm);

    pw.TextStyle s({double sz = 9, PdfColor? c, bool bold = false}) => pw.TextStyle(
      font: bold ? ft.b : ft.r, fontSize: sz, color: c,
      fontWeight: bold ? pw.FontWeight.bold : null,
    );

    pdf.addPage(pw.Page(
      pageFormat: fmt,
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Text(store.name,  style: s(sz: 14, bold: true), textAlign: pw.TextAlign.center),
        if (store.address.isNotEmpty)
          pw.Text(store.address, style: s(sz: 8), textAlign: pw.TextAlign.center),
        if (store.phone.isNotEmpty)
          pw.Text('SĐT: ${store.phone}', style: s(sz: 8), textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),
        pw.Text('--- PHIẾU LƯƠNG ---', style: s(sz: 11, bold: true), textAlign: pw.TextAlign.center),
        pw.Text(period.name, style: s(sz: 9), textAlign: pw.TextAlign.center),
        pw.Text('${_date(period.fromDate)} - ${_date(period.toDate)}', style: s(sz: 8), textAlign: pw.TextAlign.center),
        _div(w),

        _row80('Nhân viên',  record.staffName, bold: true, ft: ft),
        if (record.role != null && record.role!.isNotEmpty) _row80('Chức vụ', record.role!, ft: ft),
        _row80('Chế độ', _modeLabel(record.salaryMode), ft: ft),
        _div(w),

        _row80('Tổng giờ làm', '${record.totalHours.toStringAsFixed(1)}h', ft: ft),
        _row80('Tăng ca',      '${record.overtimeHours.toStringAsFixed(1)}h', ft: ft),
        if (record.absentDays > 0) _row80('Nghỉ không phép', '${record.absentDays} ngày', ft: ft),
        if (record.lateCount > 0)  _row80('Đi muộn', '${record.lateCount} lần', ft: ft),
        _div(w),

        _row80('Lương cơ bản', _money(record.regularPay), isPos: true, ft: ft),
        if (record.overtimePay > 0)   _row80('Tăng ca',        _money(record.overtimePay),   isPos: true, ft: ft),
        if (record.bonusRevenue > 0)  _row80('Thưởng DT',      _money(record.bonusRevenue),  isPos: true, ft: ft),
        if (record.bonusManual > 0)   _row80('Thưởng thủ công',_money(record.bonusManual),   isPos: true, ft: ft),
        // ‼️ FIX: Chỉ hiển thị từng item riêng — bỏ allowanceTotal tổng hợp để tránh trùng lặp
        ...items.where((i) => i.itemType == 'bonus' || i.itemType == 'allowance')
            .map((i) => _row80(i.label, _money(i.amount), isPos: true, ft: ft)),
        if (record.deductionLate > 0)
          _row80('Trừ đi muộn',  '-${_money(record.deductionLate)}',   isNeg: true, ft: ft),
        if (record.deductionAbsent > 0)
          _row80('Trừ nghỉ',     '-${_money(record.deductionAbsent)}',  isNeg: true, ft: ft),
        if (record.deductionManual > 0)
          _row80('Khấu trừ khác','-${_money(record.deductionManual)}',  isNeg: true, ft: ft),
        ...items.where((i) => i.itemType == 'deduction')
            .map((i) => _row80(i.label, '-${_money(i.amount)}', isNeg: true, ft: ft)),
        _div(w),

        _row80('Tổng (gross)', _money(record.grossPay), bold: true, ft: ft),
        _row80('THỰC LĨNH',    _money(record.netPay),   bold: true, isPos: true, ft: ft),
        _div(w),

        pw.Text(_payStatusLabel(record.paymentStatus),
            style: pw.TextStyle(
              font: ft.b, fontWeight: pw.FontWeight.bold, fontSize: 11,
              color: record.paymentStatus == 'paid' ? PdfColors.green700 : PdfColors.orange700,
            ),
            textAlign: pw.TextAlign.center),
        _div(w),

        pw.Text(store.footer, style: s(sz: 8), textAlign: pw.TextAlign.center),
        pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
            style: s(sz: 8, c: PdfColors.grey), textAlign: pw.TextAlign.center),
      ]),
    ));
    return pdf.save();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static pw.Widget _statBox(String label, String value, PdfColor color,
      ({pw.Font r, pw.Font b}) ft) =>
      pw.Expanded(child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Text(value, style: pw.TextStyle(font: ft.b, fontWeight: pw.FontWeight.bold,
              fontSize: 13, color: color)),
          pw.SizedBox(height: 2),
          pw.Text(label, style: pw.TextStyle(font: ft.r, fontSize: 9, color: PdfColors.grey600),
              textAlign: pw.TextAlign.center),
        ]),
      ));

  static pw.TableRow _tableRow(String label, String value, {
    required ({pw.Font r, pw.Font b}) ft,
    bool isHeader = false, bool isPositive = false,
    bool isNegative = false, bool isBold = false, PdfColor? navy,
  }) {
    final bg  = isHeader ? (navy ?? PdfColor.fromHex('#1C2151')) : null;
    final tc  = isHeader ? PdfColors.white
        : isPositive ? PdfColors.green800
        : isNegative ? PdfColors.red800 : PdfColors.black;
    final fnt = (isHeader || isBold) ? ft.b : ft.r;
    final fw  = (isHeader || isBold) ? pw.FontWeight.bold : null;
    return pw.TableRow(
      decoration: bg != null ? pw.BoxDecoration(color: bg) : null,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(label, style: pw.TextStyle(font: fnt, fontWeight: fw, color: tc, fontSize: 11)),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: pw.Text(value, textAlign: pw.TextAlign.right,
              style: pw.TextStyle(font: fnt, fontWeight: fw ?? pw.FontWeight.bold, color: tc, fontSize: 11)),
        ),
      ],
    );
  }

  static pw.Widget _div(double w) => pw.Column(children: [
    pw.SizedBox(height: 4),
    pw.Container(height: 0.5, width: w, color: PdfColors.grey400),
    pw.SizedBox(height: 4),
  ]);

  static pw.Widget _row80(String label, String value, {
    required ({pw.Font r, pw.Font b}) ft,
    bool bold = false, bool isPos = false, bool isNeg = false,
  }) {
    final c   = isPos ? PdfColors.green800 : isNeg ? PdfColors.red800 : PdfColors.black;
    final fnt = bold ? ft.b : ft.r;
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(font: fnt,
          fontWeight: bold ? pw.FontWeight.bold : null, fontSize: 9)),
      pw.Text(value, style: pw.TextStyle(font: ft.b,
          fontWeight: pw.FontWeight.bold, fontSize: 9, color: c)),
    ]);
  }

  static String _modeLabel(String m) => switch (m) {
    'M1' => 'Theo giờ', 'M2' => 'Cố định tháng',
    'M3' => 'Cố định + OT', 'M4' => 'Theo ngày', _ => m,
  };

  static String _payStatusLabel(String s) => switch (s) {
    'paid' => 'ĐÃ THANH TOÁN', 'hold' => 'TẠM GIỮ', _ => 'CHỜ THANH TOÁN',
  };
}
