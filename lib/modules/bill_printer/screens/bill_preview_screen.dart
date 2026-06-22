// lib/modules/bill_printer/screens/bill_preview_screen.dart
// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill_block.dart';
import '../models/bill_block_template.dart';
import '../providers/kitchen_ticket_template_provider.dart';
import '../providers/printer_settings_provider.dart';

// ─── Model hoá đơn ───────────────────────────────────────────────────────────

class BillData {
  final String  shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String  orderNumber;
  final DateTime createdAt;
  final String? tableName;
  final List<BillItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? paymentMethod; // cash | card | momo | transfer
  final String? customerName;
  final int?    loyaltyPoints;
  final String? note;
  final String? footer; // Lời cuối hoá đơn — từ Settings "bill_footer"
  final BillType type;

  const BillData({
    required this.shopName,
    this.shopAddress,
    this.shopPhone,
    required this.orderNumber,
    required this.createdAt,
    this.tableName,
    required this.items,
    required this.subtotal,
    this.discount = 0,
    this.tax = 0,
    required this.total,
    this.paymentMethod,
    this.customerName,
    this.loyaltyPoints,
    this.note,
    this.footer,
    this.type = BillType.receipt,
  });
}

class BillItem {
  final String name;
  final int    qty;
  final double price;
  final String? note;
  final String stationCode;

  const BillItem({
    required this.name,
    required this.qty,
    required this.price,
    this.note,
    this.stationCode = 'bep_nong',
  });

  double get total => qty * price;
}

enum BillType { receipt, kitchen, order, label }

// ─── PDF Generator ────────────────────────────────────────────────────────────

class BillPdfGenerator {
  static final _fmt = NumberFormat('#,###', 'vi_VN');
  static String _money(double v) => '${_fmt.format(v.round())}đ';
  static String _fmtDate(DateTime d) {
    // ‼️ FIX ISSUE #8: luôn convert sang local — tránh sai 7h nếu caller truyền UTC
    final local = d.isUtc ? d.toLocal() : d;
    return '${local.day.toString().padLeft(2,'0')}/${local.month.toString().padLeft(2,'0')}/${local.year} '
        '${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
  }

  // ── Align helper ──────────────────────────────────────────────────────────
  static pw.TextAlign _pdfAlign(String a) {
    switch (a) {
      case 'right': return pw.TextAlign.right;
      case 'left':  return pw.TextAlign.left;
      default:      return pw.TextAlign.center;
    }
  }

  // ‼️ FIX BUG #1 — V2: đọc BillBlockTemplate, render từng block đúng theo designer
  static Future<Uint8List> generateReceipt(BillData bill) async {
    final pdf      = pw.Document();
    final tpl      = await BillBlockTemplate.load(); // key: bill_blocks_v2
    final font     = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    final paperMm = tpl.paperSize == '58mm' ? 58.0
                  : tpl.paperSize == 'a4'   ? 210.0 : 80.0;
    final pageFormat = PdfPageFormat(
      paperMm * PdfPageFormat.mm,
      double.infinity,
      marginAll: 6 * PdfPageFormat.mm,
    );

    final sections = <pw.Widget>[];
    for (final block in tpl.blocks.where((b) => b.enabled)) {
      final w = _blockToPdf(block, bill, font, fontBold);
      if (w != null) sections.add(w);
    }

    // ── Branding bắt buộc: Quán Nhỏ POS — luôn in cuối cùng ──
    if (!tpl.blocks.any((b) => b.type == BillBlockType.appBranding && b.enabled)) {
      sections.add(_brandingPdf(font));
    }

    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (_) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: sections,
      ),
    ));
    return pdf.save();
  }

  // ── Render từng BillBlock → pw.Widget ─────────────────────────────────────
  static pw.Widget? _blockToPdf(
      BillBlock b, BillData bill, pw.Font font, pw.Font fontBold) {
    switch (b.type) {
      case BillBlockType.shopHeader: {
        final name    = b.cfg<String>('shopName', '').isNotEmpty
            ? b.cfg<String>('shopName', '') : bill.shopName;
        final tagline = b.cfg<String>('tagline', '');
        final fs      = b.cfg<int>('fontSize', 16).toDouble();
        final isBold  = b.cfg<bool>('bold', true);
        final align   = _pdfAlign(b.cfg<String>('align', 'center'));
        return pw.Column(children: [
          pw.Text(name, textAlign: align,
              style: pw.TextStyle(font: isBold ? fontBold : font, fontSize: fs)),
          if (tagline.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(tagline, textAlign: align,
                style: pw.TextStyle(font: font, fontSize: (fs - 4).clamp(6, 20),
                    color: PdfColors.grey600)),
          ],
        ]);
      }
      case BillBlockType.shopLogo:
        return null; // logo không in rõ trên thermal — bỏ qua
      case BillBlockType.shopAddress: {
        final addr = b.cfg<String>('address', '').isNotEmpty
            ? b.cfg<String>('address', '') : (bill.shopAddress ?? '');
        if (addr.isEmpty) return null;
        final fs = b.cfg<int>('fontSize', 10).toDouble();
        return pw.Text(addr,
            textAlign: _pdfAlign(b.cfg<String>('align', 'center')),
            style: pw.TextStyle(font: font, fontSize: fs, color: PdfColors.grey700));
      }
      case BillBlockType.shopPhone: {
        final phone = b.cfg<String>('phone', '').isNotEmpty
            ? b.cfg<String>('phone', '') : (bill.shopPhone ?? '');
        if (phone.isEmpty) return null;
        final label = b.cfg<String>('label', 'DT:');
        final fs    = b.cfg<int>('fontSize', 10).toDouble();
        return pw.Text('$label $phone',
            textAlign: _pdfAlign(b.cfg<String>('align', 'center')),
            style: pw.TextStyle(font: font, fontSize: fs, color: PdfColors.grey700));
      }
      case BillBlockType.divider: {
        final style = b.cfg<String>('style', 'solid');
        final thick = (b.cfg<double>('thickness', 1.0)).clamp(0.5, 3.0);
        if (style == 'double') {
          return pw.Column(children: [
            pw.Divider(thickness: thick * 0.5, height: 4),
            pw.Divider(thickness: thick, height: 4),
          ]);
        }
        return pw.Divider(thickness: thick, height: 8);
      }
      case BillBlockType.orderInfo: {
        final fs = b.cfg<int>('fontSize', 10).toDouble();
        return pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('HOA DON', style: pw.TextStyle(font: fontBold, fontSize: fs + 1)),
            pw.Text('#${bill.orderNumber}', style: pw.TextStyle(font: fontBold, fontSize: fs + 1)),
          ]),
          if (b.cfg<bool>('showDate', true))
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Ngay:', style: pw.TextStyle(font: font, fontSize: fs)),
              pw.Text(_fmtDate(bill.createdAt), style: pw.TextStyle(font: font, fontSize: fs)),
            ]),
        ]);
      }
      case BillBlockType.tableInfo: {
        final tableName = bill.tableName;
        if (!b.cfg<bool>('showTable', true) || tableName == null) return null;
        final label = b.cfg<String>('label', 'Ban:');
        final fs    = b.cfg<int>('fontSize', 10).toDouble();
        return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: fs)),
          pw.Text(tableName, style: pw.TextStyle(font: fontBold, fontSize: fs)),
        ]);
      }
      case BillBlockType.itemsList: {
        final fs = b.cfg<int>('fontSize', 10).toDouble();
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Row(children: [
            pw.Expanded(flex: 4, child: pw.Text('Mon',
                style: pw.TextStyle(font: fontBold, fontSize: fs - 1))),
            pw.Text('SL', style: pw.TextStyle(font: fontBold, fontSize: fs - 1)),
            pw.SizedBox(width: 10),
            pw.Text('T.Tien', style: pw.TextStyle(font: fontBold, fontSize: fs - 1)),
          ]),
          pw.Divider(thickness: 0.3, height: 4),
          ...bill.items.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 2),
            child: pw.Row(children: [
              pw.Expanded(flex: 4, child: pw.Text(item.name,
                  style: pw.TextStyle(font: font, fontSize: fs - 1))),
              pw.Text('x${item.qty}', style: pw.TextStyle(font: font, fontSize: fs - 1)),
              pw.SizedBox(width: 8),
              pw.Text(_money(item.total), style: pw.TextStyle(font: fontBold, fontSize: fs - 1)),
            ]),
          )),
        ]);
      }
      case BillBlockType.totals: {
        final fs   = b.cfg<int>('fontSize', 10).toDouble();
        final tfs  = b.cfg<int>('totalFontSize', 14).toDouble();
        final isBold = b.cfg<bool>('boldTotal', true);
        return pw.Column(children: [
          if (b.cfg<bool>('showSubtotal', true))
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Tam tinh:', style: pw.TextStyle(font: font, fontSize: fs)),
              pw.Text(_money(bill.subtotal), style: pw.TextStyle(font: font, fontSize: fs)),
            ]),
          if (b.cfg<bool>('showDiscount', true) && bill.discount > 0)
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('Giam gia:', style: pw.TextStyle(font: font, fontSize: fs)),
              pw.Text('-${_money(bill.discount)}',
                  style: pw.TextStyle(font: font, fontSize: fs, color: PdfColors.red)),
            ]),
          pw.SizedBox(height: 4),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TONG CONG:',
                style: pw.TextStyle(font: isBold ? fontBold : font, fontSize: tfs - 2)),
            pw.Text(_money(bill.total),
                style: pw.TextStyle(font: isBold ? fontBold : font, fontSize: tfs)),
          ]),
        ]);
      }
      case BillBlockType.paymentMethod: {
        if (bill.paymentMethod == null) return null;
        final label = b.cfg<String>('label', 'Thanh toan:');
        final fs    = b.cfg<int>('fontSize', 10).toDouble();
        return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: fs)),
          pw.Text(_paymentLabel(bill.paymentMethod!),
              style: pw.TextStyle(font: fontBold, fontSize: fs)),
        ]);
      }
      case BillBlockType.loyaltyPoints: {
        final pts = bill.loyaltyPoints;
        if (pts == null || pts <= 0) return null;
        final fs     = b.cfg<int>('fontSize', 10).toDouble();
        final border = b.cfg<bool>('borderBox', true);
        final col = pw.Column(children: [
          if (b.cfg<bool>('showEarned', true))
            pw.Text('Cong $pts diem thuong', textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: fs)),
        ]);
        if (border) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Container(width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: col),
          );
        }
        return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: col);
      }
      case BillBlockType.qrCode: {
        final accNo   = b.cfg<String>('accountNo', '');
        final accName = b.cfg<String>('accountName', '');
        if (accNo.isEmpty) return null;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Column(children: [
            pw.Text('CHUYEN KHOAN', textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: 10)),
            pw.Text(accNo, textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: 13)),
            if (accName.isNotEmpty)
              pw.Text(accName, textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey700)),
            pw.Text('So tien: ${_money(bill.total)}', textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: 11)),
          ]),
        );
      }
      case BillBlockType.customText: {
        final text   = b.cfg<String>('text', '');
        if (text.isEmpty) return null;
        final fs     = b.cfg<int>('fontSize', 10).toDouble();
        final isBold = b.cfg<bool>('bold', false);
        final italic = b.cfg<bool>('italic', false);
        final align  = _pdfAlign(b.cfg<String>('align', 'center'));
        final border = b.cfg<bool>('borderBox', false);
        final tw = pw.Text(text, textAlign: align,
            style: pw.TextStyle(
              font: isBold ? fontBold : font, fontSize: fs,
              fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal));
        if (border) {
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Container(width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: tw),
          );
        }
        return pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 3), child: tw);
      }
      case BillBlockType.spacer:
        return pw.SizedBox(height: b.cfg<double>('height', 8.0));
      case BillBlockType.footer: {
        final text   = b.cfg<String>('text', 'Cam on quy khach!');
        final sub    = b.cfg<String>('subText', '');
        final fs     = b.cfg<int>('fontSize', 12).toDouble();
        final isBold = b.cfg<bool>('bold', true);
        final align  = _pdfAlign(b.cfg<String>('align', 'center'));
        return pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Column(children: [
            pw.Text(text, textAlign: align,
                style: pw.TextStyle(font: isBold ? fontBold : font, fontSize: fs)),
            if (sub.isNotEmpty)
              pw.Text(sub, textAlign: align,
                  style: pw.TextStyle(font: font, fontSize: (fs - 2).clamp(6, 20),
                      color: PdfColors.grey600)),
          ]),
        );
      }
      case BillBlockType.appBranding:
        return _brandingPdf(font);
    }
  }

  /// Branding line bắt buộc — không thể xoá
  static pw.Widget _brandingPdf(pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 6, bottom: 2),
      child: pw.Column(children: [
        pw.Divider(thickness: 0.3, height: 6, color: PdfColors.grey400),
        pw.Text('Powered by Quan Nho POS',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey500)),
      ]),
    );
  }


  // ── generateKitchenTicket: đọc từ KitchenTicketTemplate do chủ quán thiết kế ─────────
  static Future<Uint8List> generateKitchenTicket(BillData bill) async {
    final pdf     = pw.Document();
    final font    = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // Load template chủ quán đã thiết kế
    final tpl = await KitchenTicketTemplate.load();

    final paperMm = tpl.paperSize == '58mm' ? 58.0 : 80.0;
    final pageFormat = PdfPageFormat(
      paperMm * PdfPageFormat.mm,
      double.infinity,
      marginAll: 6 * PdfPageFormat.mm,
    );

    final hfs  = tpl.headerFontSize.toDouble();
    final tfs  = tpl.tableFontSize.toDouble();
    final ifs  = tpl.itemFontSize.toDouble();
    final qfs  = tpl.qtyFontSize.toDouble();
    final bold = tpl.boldItemName ? fontBold : font;

    pdf.addPage(pw.Page(
      pageFormat: pageFormat,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [

          // Tiêu đề
          pw.Text(tpl.headerText,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontBold, fontSize: hfs,
                  letterSpacing: 1.5)),
          pw.SizedBox(height: 4),

          // Bàn + số đơn
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              if (tpl.showTableName && bill.tableName != null)
                pw.Text(bill.tableName!,
                    style: pw.TextStyle(font: fontBold, fontSize: tfs)),
              if (tpl.showOrderNumber)
                pw.Text('#${bill.orderNumber}',
                    style: pw.TextStyle(font: font, fontSize: 10,
                        color: PdfColors.grey600)),
            ],
          ),

          if (tpl.showDateTime)
            pw.Text(_fmtDate(bill.createdAt),
                style: pw.TextStyle(font: font, fontSize: 9,
                    color: PdfColors.grey600)),

          if (tpl.showDivider) pw.Divider(thickness: 1, height: 10),

          // Danh sách món với số lượng vòng tròn
          ...bill.items.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Vòng tròn số lượng
                pw.Container(
                  width: qfs + 8, height: qfs + 8,
                  decoration: const pw.BoxDecoration(
                      color: PdfColors.black, shape: pw.BoxShape.circle),
                  child: pw.Center(
                    child: pw.Text('${item.qty}',
                        style: pw.TextStyle(
                            font: fontBold, fontSize: qfs,
                            color: PdfColors.white)),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(item.name,
                          style: pw.TextStyle(font: bold, fontSize: ifs)),
                      if (tpl.showNote && item.note != null && item.note!.isNotEmpty)
                        pw.Text('   > ${item.note!}',
                            style: pw.TextStyle(
                                font: font, fontSize: ifs - 2,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
          )),

          if (tpl.showDivider) pw.Divider(thickness: 0.5, height: 8),

          // Ghi chú toàn đơn
          if (tpl.showNote && bill.note != null && bill.note!.isNotEmpty)
            pw.Text('Lưu ý: ${bill.note!}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: 11)),
        ],
      ),
    ));

    return pdf.save();
  }

  static String _paymentLabel(String m) {
    switch (m) {
      case 'cash':     return 'Tiền mặt';
      case 'card':     return 'Thẻ';
      case 'momo':     return 'MoMo';
      case 'transfer': return 'Chuyển khoản';
      default:         return m;
    }
  }

  // ── generateBarLabels: In tem nhãn dán ly cho trạm Bar ──────────────────────────────
  static Future<List<Uint8List>> generateBarLabels(BillData bill) async {
    final List<Uint8List> results = [];
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // Filter drinks (stationCode == 'bep_bar' || stationCode == 'bar')
    final barItems = bill.items.where((i) => i.stationCode == 'bep_bar' || i.stationCode == 'bar').toList();
    if (barItems.isEmpty) return [];

    for (final item in barItems) {
      // In từng nhãn dán cho mỗi số lượng ly
      for (int q = 1; q <= item.qty; q++) {
        final pdf = pw.Document();
        pdf.addPage(pw.Page(
          pageFormat: const PdfPageFormat(
            50 * PdfPageFormat.mm,
            30 * PdfPageFormat.mm,
            marginAll: 2 * PdfPageFormat.mm,
          ),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '#${bill.orderNumber}${bill.tableName != null ? ' - ${bill.tableName}' : ''}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                  ),
                  pw.Text(
                    '$q/${item.qty}',
                    style: pw.TextStyle(font: fontBold, fontSize: 8),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.5, height: 4),
              pw.SizedBox(height: 1),
              pw.Text(
                item.name,
                style: pw.TextStyle(font: fontBold, fontSize: 10),
                maxLines: 1,
                overflow: pw.TextOverflow.clip,
              ),
              if (item.note != null && item.note!.isNotEmpty) ...[
                pw.SizedBox(height: 1),
                pw.Text(
                  item.note!,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 7,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.grey700,
                  ),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
              ],
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.bottomRight,
                child: pw.Text(
                  _fmtDate(bill.createdAt).split(' ').last, // chỉ giờ:phút
                  style: pw.TextStyle(font: font, fontSize: 6, color: PdfColors.grey500),
                ),
              ),
            ],
          ),
        ));
        results.add(await pdf.save());
      }
    }
    return results;
  }
}

// ─── Station Printer Dispatcher ──────────────────────────────────────────────

class StationPrinterDispatcher {
  static Future<void> printBill(BillData bill, StationPrintersState settings) async {
    // 1. In hoá đơn thu ngân (chỉ in khi là hóa đơn thanh toán, không in khi là phiếu bếp)
    if (settings.cashier.enabled && bill.type == BillType.receipt) {
      final bytes = await BillPdfGenerator.generateReceipt(bill);
      await _dispatchPrint(bytes, settings.cashier, 'hoa_don_${bill.orderNumber}');
    }

    // 2. In phiếu bếp nóng
    if (settings.bepNong.enabled) {
      final hotItems = bill.items
          .where((i) => i.stationCode == 'bep_nong' || i.stationCode == 'nong')
          .toList();
      if (hotItems.isNotEmpty) {
        final hotBill = BillData(
          shopName: bill.shopName,
          shopAddress: bill.shopAddress,
          shopPhone: bill.shopPhone,
          orderNumber: bill.orderNumber,
          createdAt: bill.createdAt,
          tableName: bill.tableName,
          items: hotItems,
          subtotal: 0,
          total: 0,
          type: BillType.kitchen,
          note: bill.note,
        );
        final bytes = await BillPdfGenerator.generateKitchenTicket(hotBill);
        await _dispatchPrint(bytes, settings.bepNong, 'phieu_bep_nong_${bill.orderNumber}');
      }
    }

    // 3. In phiếu bếp bar
    if (settings.bepBar.enabled) {
      final barItems = bill.items
          .where((i) => i.stationCode == 'bep_bar' || i.stationCode == 'bar')
          .toList();
      if (barItems.isNotEmpty) {
        final barBill = BillData(
          shopName: bill.shopName,
          shopAddress: bill.shopAddress,
          shopPhone: bill.shopPhone,
          orderNumber: bill.orderNumber,
          createdAt: bill.createdAt,
          tableName: bill.tableName,
          items: barItems,
          subtotal: 0,
          total: 0,
          type: BillType.kitchen,
          note: bill.note,
        );
        final bytes = await BillPdfGenerator.generateKitchenTicket(barBill);
        await _dispatchPrint(bytes, settings.bepBar, 'phieu_bep_bar_${bill.orderNumber}');
      }
    }

    // 4. In nhãn dán ly (Bar Label)
    if (settings.barLabel.enabled) {
      final labelBytesList = await BillPdfGenerator.generateBarLabels(bill);
      for (int i = 0; i < labelBytesList.length; i++) {
        await _dispatchPrint(
          labelBytesList[i],
          settings.barLabel,
          'tem_bar_${bill.orderNumber}_$i',
        );
      }
    }
  }

  static Future<void> _dispatchPrint(
    Uint8List bytes,
    PrinterConfig config,
    String jobName,
  ) async {
    if (config.type == 'system') {
      if (config.name.isEmpty) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName);
      } else {
        await Printing.directPrintPdf(
          printer: Printer(url: config.name),
          onLayout: (_) async => bytes,
          name: jobName,
        );
      }
    } else {
      // Mạng IP (LAN/Wifi) - Hộp thoại in hệ thống làm dự phòng nếu không kết nối được trực tiếp
      try {
        final socket = await Socket.connect(config.name, 9100, timeout: const Duration(seconds: 3));
        // Đóng cổng vì direct pdf qua socket cần parser đặc biệt. Fallback sang layoutPdf.
        await socket.close();
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName);
      } catch (_) {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: jobName);
      }
    }
  }
}

// ─── Bill Preview Screen ──────────────────────────────────────────────────────

class BillPreviewScreen extends StatefulWidget {
  final BillData bill;
  final bool isKitchen;

  const BillPreviewScreen({
    super.key,
    required this.bill,
    this.isKitchen = false,
  });

  @override
  State<BillPreviewScreen> createState() => _BillPreviewScreenState();
}

class _BillPreviewScreenState extends State<BillPreviewScreen> {
  Uint8List? _cachedBytes;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    try {
      final bytes = widget.isKitchen
          ? await BillPdfGenerator.generateKitchenTicket(widget.bill)
          : await BillPdfGenerator.generateReceipt(widget.bill);
      if (mounted) setState(() => _cachedBytes = bytes);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final bill = widget.bill;
    final isKitchen = widget.isKitchen;

    return Scaffold(
      backgroundColor: const Color(0xFF1C2151),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2151),
        foregroundColor: Colors.white,
        title: Text(
          isKitchen ? 'Phiếu Bếp' : 'Hoá Đơn',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_cachedBytes != null)
            IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white),
              tooltip: 'Chia sẻ',
              onPressed: () async {
                await Printing.sharePdf(
                    bytes: _cachedBytes!,
                    filename: isKitchen
                        ? 'phieu_bep_${bill.orderNumber}.pdf'
                        : 'hoa_don_${bill.orderNumber}.pdf');
              },
            ),
        ],
      ),
      body: _error.isNotEmpty
          ? Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Lỗi tạo hoá đơn:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70)),
            ))
          : _cachedBytes == null
          ? const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                CircularProgressIndicator(color: Colors.white),
                SizedBox(height: 16),
                Text('Đang tạo hoá đơn...', style: TextStyle(color: Colors.white70)),
              ]),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final isLarge = constraints.maxWidth > 600;
                // 80mm giấy nhiệt ≈ 302px logic — set 340 cho có padding lề
                const double receiptWidth = 340.0;
                final Widget preview = PdfPreview(
                  build: (_) async => _cachedBytes!,
                  allowPrinting: true,
                  allowSharing: false,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  maxPageWidth: receiptWidth, // ← giới hạn PDF render width
                  initialPageFormat: PdfPageFormat(
                    80 * PdfPageFormat.mm,
                    double.infinity,
                    marginAll: 6 * PdfPageFormat.mm,
                  ),
                  actions: [
                    PdfPreviewAction(
                      icon: const Icon(Icons.print),
                      onPressed: (ctx, build, fmt) async {
                        final bytes = await build(fmt);
                        await Printing.layoutPdf(
                            onLayout: (_) async => bytes,
                            name: isKitchen
                                ? 'phieu_bep_${bill.orderNumber}'
                                : 'hoa_don_${bill.orderNumber}');
                      },
                    ),
                  ],
                );
                if (!isLarge) return preview; // phone: full width bình thường
                // Tablet: hiện như tờ giấy giữa nền tối
                return Container(
                  color: const Color(0xFF131736),
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: receiptWidth,
                    child: preview,
                  ),
                );
              },
            ),
    );
  }
}

// ─── Helper Function — Mở hoá đơn nhanh ─────────────────────────────────────

Future<void> showBillPreview(BuildContext context, BillData bill,
    {bool isKitchen = false}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
        builder: (_) => BillPreviewScreen(bill: bill, isKitchen: isKitchen)),
  );
}
