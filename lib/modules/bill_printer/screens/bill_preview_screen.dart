// lib/modules/bill_printer/screens/bill_preview_screen.dart
// ignore_for_file: use_build_context_synchronously
import '../../../core/utils/app_logger.dart';
import '../fonts/bill_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import '../../../core/services/vietqr_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/bill_block.dart';
import '../models/bill_block_template.dart';
import '../providers/bar_label_template_provider.dart';
import '../providers/kitchen_ticket_template_provider.dart';
import '../providers/printer_settings_provider.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../utils/station_normalizer.dart';
import '../drivers/sunmi_builtin_driver.dart';
import '../utils/escpos_raster.dart';
import '../utils/qn_queue_resolver.dart';
import '../utils/paper_sizes.dart';
import '../routing/print_router.dart';
import '../routing/print_setup.dart';

// ─── Model hoá đơn ───────────────────────────────────────────────────────────

class BillData {
  final String shopName;
  final String? shopAddress;
  final String? shopPhone;
  final String orderNumber;
  final DateTime createdAt;
  final String? tableName;
  final List<BillItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? paymentMethod; // cash | card | momo | transfer
  final String? customerName;
  final int? loyaltyPoints;
  final String? note;
  final String? footer; // Lời cuối hoá đơn — từ Settings "bill_footer"
  final BillType type;
  final String? waiterName;

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
    this.waiterName,
  });
}

class BillItem {
  final String name;
  final int qty;
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

abstract class PdfFontLoader {
  Future<pw.Font> loadRegular();
  Future<pw.Font> loadBold();
}

/// Mặc định: font Noto Sans đi kèm app (có chữ Việt, không cần mạng); Google chỉ là dự phòng.
class BundledPdfFontLoader implements PdfFontLoader {
  const BundledPdfFontLoader();

  @override
  Future<pw.Font> loadRegular() => BillFonts.regular();

  @override
  Future<pw.Font> loadBold() => BillFonts.bold();
}

class GooglePdfFontLoader implements PdfFontLoader {
  @override
  Future<pw.Font> loadRegular() => PdfGoogleFonts.notoSansRegular();

  @override
  Future<pw.Font> loadBold() => PdfGoogleFonts.notoSansBold();
}

// ─── PDF Generator ────────────────────────────────────────────────────────────

class BillPdfGenerator {
  static PdfFontLoader fontLoader = const BundledPdfFontLoader();

  /// Font chữ đậm "bán đậm" (SemiBold) cho máy in nhiệt nhỏ; lỗi tải font -> null (dùng Bold thường).
  static Future<pw.Font?> softBoldFont() async {
    return BillFonts.semiBold();
  }

  static final _fmt = NumberFormat('#,###', 'vi_VN');
  static String _money(double v) => '${_fmt.format(v.round())}đ';
  static String _fmtDate(DateTime d) {
    // ‼️ FIX ISSUE #8: luôn convert sang local — tránh sai 7h nếu caller truyền UTC
    final local = d.isUtc ? d.toLocal() : d;
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  static String _cleanEmoji(String s) =>
      s.replaceAll(RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true), '').trim();

  // ── Align helper ──────────────────────────────────────────────────────────
  static pw.TextAlign _pdfAlign(String a) {
    switch (a) {
      case 'right':
        return pw.TextAlign.right;
      case 'left':
        return pw.TextAlign.left;
      default:
        return pw.TextAlign.center;
    }
  }

  // ‼️ FIX BUG #1 — V2: đọc BillBlockTemplate, render từng block đúng theo designer
  static Future<Uint8List> generateReceipt(
    BillData bill, {
    String stationKey = 'cashier',
    pw.Font? customFont,
    pw.Font? customFontBold,
    double? paperMmOverride,
  }) async {
    final pdf = pw.Document();
    final tpl = await BillBlockTemplate.load(
      stationKey: stationKey,
    ); // key: bill_blocks_v2
    final font = customFont ?? await fontLoader.loadRegular();
    final fontBold = customFontBold ?? await fontLoader.loadBold();

    final paperMm = paperMmOverride ?? paperWidthMm(tpl.paperSize);
    final pageFormat = PdfPageFormat(
      paperMm * PdfPageFormat.mm,
      double.infinity,
      marginLeft: 2 * PdfPageFormat.mm,
      marginRight: 2 * PdfPageFormat.mm,
      marginTop: 5 * PdfPageFormat.mm,
      marginBottom: 5 * PdfPageFormat.mm,
    );

    final sections = <pw.Widget>[];
    for (final block in tpl.blocks.where((b) => b.enabled)) {
      final w = _blockToPdf(block, tpl, bill, font, fontBold);
      if (w != null) sections.add(w);
    }

    // ── Branding bắt buộc: Quán Nhỏ POS — luôn in cuối cùng ──
    if (!tpl.blocks.any(
      (b) => b.type == BillBlockType.appBranding && b.enabled,
    )) {
      sections.add(_brandingPdf(font));
    }

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: sections,
        ),
      ),
    );
    return pdf.save();
  }

  /// Một dòng "nhãn ... giá trị" tự co chữ khi quá bề rộng để KHÔNG bị cụt mép giấy.
  static pw.Widget _fitRow(
    String label,
    String value,
    pw.TextStyle labelStyle,
    pw.TextStyle valueStyle,
  ) {
    return pw.Row(
      // Canh giữa theo chiều dọc để nhãn và giá trị cùng nằm trên một dòng, không lệch khi cỡ chữ khác nhau.
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          flex: 5,
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(label, style: labelStyle),
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Expanded(
          flex: 6,
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.centerRight,
            child: pw.Text(value, style: valueStyle),
          ),
        ),
      ],
    );
  }

  // ── Render từng BillBlock → pw.Widget ─────────────────────────────────────
  static pw.Widget? _blockToPdf(
    BillBlock b,
    BillBlockTemplate tpl,
    BillData bill,
    pw.Font font,
    pw.Font fontBold,
  ) {
    switch (b.type) {
      case BillBlockType.shopHeader:
        {
          final name = b.cfg<String>('shopName', '').isNotEmpty
              ? b.cfg<String>('shopName', '')
              : bill.shopName;
          final tagline = b.cfg<String>('tagline', '');
          final fs = b.cfg<int>('fontSize', 16).toDouble();
          final isBold = b.cfg<bool>('bold', true);
          final align = _pdfAlign(b.cfg<String>('align', 'center'));
          return pw.Column(
            children: [
              pw.Text(
                name,
                textAlign: align,
                style: pw.TextStyle(
                  font: isBold ? fontBold : font,
                  fontSize: fs,
                ),
              ),
              if (tagline.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  tagline,
                  textAlign: align,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: (fs - 4).clamp(6, 20),
                    color: PdfColors.black,
                  ),
                ),
              ],
            ],
          );
        }
      case BillBlockType.shopLogo:
        {
          final path = b.cfg<String>('imagePath', '');
          final alignStr = b.cfg<String>('align', 'center');
          final pw.AlignmentGeometry align = alignStr == 'left'
              ? pw.Alignment.centerLeft
              : alignStr == 'right'
              ? pw.Alignment.centerRight
              : pw.Alignment.center;
          final width = b.cfg<double>('width', 80.0);
          if (path.isEmpty) return null;

          pw.MemoryImage? img;
          try {
            if (path.startsWith('data:image')) {
              final base64Data = path.split(',').last;
              img = pw.MemoryImage(base64Decode(base64Data));
            }
          } catch (e) {
            debugPrint('Error parsing logo: $e');
          }

          if (img == null) return null;
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: pw.Align(
              alignment: align,
              child: pw.Image(img, width: width),
            ),
          );
        }
      case BillBlockType.shopAddress:
        {
          final addr = b.cfg<String>('address', '').isNotEmpty
              ? b.cfg<String>('address', '')
              : (bill.shopAddress ?? '');
          if (addr.isEmpty) return null;
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          return pw.Text(
            addr,
            textAlign: _pdfAlign(b.cfg<String>('align', 'center')),
            style: pw.TextStyle(
              font: font,
              fontSize: fs,
              color: PdfColors.black,
            ),
          );
        }
      case BillBlockType.shopPhone:
        {
          final phone = b.cfg<String>('phone', '').isNotEmpty
              ? b.cfg<String>('phone', '')
              : (bill.shopPhone ?? '');
          if (phone.isEmpty) return null;
          final label = b.cfg<String>('label', 'ĐT:');
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          return pw.Text(
            '$label $phone',
            textAlign: _pdfAlign(b.cfg<String>('align', 'center')),
            style: pw.TextStyle(
              font: font,
              fontSize: fs,
              color: PdfColors.black,
            ),
          );
        }
      case BillBlockType.divider:
        {
          final style = b.cfg<String>('style', 'solid');
          final thick = (b.cfg<double>('thickness', 1.0)).clamp(0.5, 3.0);
          if (style == 'double') {
            return pw.Column(
              children: [
                pw.Divider(thickness: thick * 0.5, height: 4),
                pw.Divider(thickness: thick, height: 4),
              ],
            );
          }
          return pw.Divider(thickness: thick, height: 8);
        }
      case BillBlockType.orderInfo:
        {
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          return pw.Column(
            children: [
              _fitRow(
                'HÓA ĐƠN',
                '#${bill.orderNumber}',
                pw.TextStyle(font: fontBold, fontSize: fs + 1),
                pw.TextStyle(font: fontBold, fontSize: fs + 1),
              ),
              if (b.cfg<bool>('showDate', true))
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Ngày:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      _fmtDate(bill.createdAt),
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                  ],
                ),
              if (bill.waiterName != null && bill.waiterName!.isNotEmpty)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Nhân viên:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      bill.waiterName!,
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                  ],
                ),
            ],
          );
        }
      case BillBlockType.tableInfo:
        {
          final tableName = bill.tableName;
          if (!b.cfg<bool>('showTable', true) || tableName == null) return null;
          final label = b.cfg<String>('label', 'Bàn:');
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    label,
                    style: pw.TextStyle(font: font, fontSize: fs),
                  ),
                  pw.Text(
                    tableName,
                    style: pw.TextStyle(font: fontBold, fontSize: fs),
                  ),
                ],
              ),
              if (bill.waiterName != null && bill.waiterName!.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Nhân viên:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      bill.waiterName!,
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                  ],
                ),
              ],
            ],
          );
        }
      case BillBlockType.taxInfo:
        {
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          final pattern = b.cfg<String>('invoicePattern', '').trim();
          final serial = b.cfg<String>('invoiceSerial', '').trim();
          // Mẫu số / ký hiệu hóa đơn là của riêng từng quán: chưa nhập thì không in.
          final showPattern = b.cfg<bool>('showPattern', true) && pattern.isNotEmpty;
          final showSerial = b.cfg<bool>('showSerial', true) && serial.isNotEmpty;
          if (!showPattern && !showSerial) return null;
          return pw.Column(
            children: [
              if (showPattern)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Mẫu số HĐ:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      pattern,
                      style: pw.TextStyle(font: fontBold, fontSize: fs),
                    ),
                  ],
                ),
              if (showSerial)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Ký hiệu HĐ:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      serial,
                      style: pw.TextStyle(font: fontBold, fontSize: fs),
                    ),
                  ],
                ),
            ],
          );
        }
      case BillBlockType.itemsList:
        {
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          final totalsBlock = tpl.blocks.firstWhereOrNull(
            (block) => block.type == BillBlockType.totals,
          );
          final showSurchargeInTotals =
              totalsBlock?.cfg<bool>('showSurcharge', true) ?? true;

          final items = showSurchargeInTotals
              ? bill.items.where((item) => item.name != 'Phí dịch vụ / Ship')
              : bill.items;

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 4,
                    child: pw.Text(
                      'Món',
                      style: pw.TextStyle(font: fontBold, fontSize: fs - 1),
                    ),
                  ),
                  pw.Text(
                    'SL',
                    style: pw.TextStyle(font: fontBold, fontSize: fs - 1),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Text(
                    'T.Tiền',
                    style: pw.TextStyle(font: fontBold, fontSize: fs - 1),
                  ),
                ],
              ),
              pw.Divider(thickness: 0.3, height: 4),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 2),
                  child: pw.Row(
                    children: [
                      pw.Expanded(
                        flex: 4,
                        child: pw.Text(
                          item.name,
                          style: pw.TextStyle(font: font, fontSize: fs - 1),
                        ),
                      ),
                      pw.SizedBox(width: 6),
                      pw.Text(
                        'x${item.qty}',
                        style: pw.TextStyle(font: font, fontSize: fs - 1),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        _money(item.total),
                        style: pw.TextStyle(font: fontBold, fontSize: fs - 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      case BillBlockType.totals:
        {
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          final tfs = b.cfg<int>('totalFontSize', 14).toDouble();
          final isBold = b.cfg<bool>('boldTotal', true);
          final showSurcharge = b.cfg<bool>('showSurcharge', true);

          final surchargeItem = bill.items.firstWhereOrNull(
            (item) => item.name == 'Phí dịch vụ / Ship',
          );
          final surcharge = surchargeItem?.total ?? 0.0;
          final displaySubtotal = showSurcharge
              ? (bill.subtotal)
              : (bill.subtotal - surcharge);

          return pw.Column(
            children: [
              if (b.cfg<bool>('showSubtotal', true))
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Tạm tính:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      _money(displaySubtotal),
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                  ],
                ),
              if (b.cfg<bool>('showDiscount', true) && bill.discount > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Giảm giá:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      '-${_money(bill.discount)}',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: fs,
                        color: PdfColors.red,
                      ),
                    ),
                  ],
                ),
              if (showSurcharge && surcharge > 0)
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Phí dịch vụ/Ship:',
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                    pw.Text(
                      _money(surcharge),
                      style: pw.TextStyle(font: font, fontSize: fs),
                    ),
                  ],
                ),
              pw.SizedBox(height: 4),
              _fitRow(
                'TỔNG CỘNG:',
                _money(bill.total),
                // Nhãn và số tiền cùng cỡ chữ => thẳng hàng; quá bề rộng thì tự co.
                pw.TextStyle(font: isBold ? fontBold : font, fontSize: tfs - 1),
                pw.TextStyle(font: isBold ? fontBold : font, fontSize: tfs - 1),
              ),
            ],
          );
        }
      case BillBlockType.paymentMethod:
        {
          if (bill.paymentMethod == null) return null;
          final label = b.cfg<String>('label', 'Thanh toán:');
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          return pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(font: font, fontSize: fs),
              ),
              pw.Text(
                _paymentLabel(bill.paymentMethod!),
                style: pw.TextStyle(font: fontBold, fontSize: fs),
              ),
            ],
          );
        }
      case BillBlockType.loyaltyPoints:
        {
          final pts = bill.loyaltyPoints;
          if (pts == null || pts <= 0) return null;
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          final border = b.cfg<bool>('borderBox', true);
          final col = pw.Column(
            children: [
              if (b.cfg<bool>('showEarned', true))
                pw.Text(
                  'Cộng $pts điểm thưởng',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: fontBold, fontSize: fs),
                ),
            ],
          );
          if (border) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 4),
              child: pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: col,
              ),
            );
          }
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 4),
            child: col,
          );
        }
      case BillBlockType.qrCode:
        {
          final qrSource = b.cfg<String>('qrSource', 'vietqr');
          final qrImagePath = b.cfg<String>('qrImagePath', '');
          final sizeStr = b.cfg<String>('size', 'medium');
          final double qrSize = sizeStr == 'small'
              ? 60.0
              : sizeStr == 'large'
              ? 120.0
              : 90.0;

          pw.Widget? qrWidget;
          if (qrSource == 'custom_image') {
            if (qrImagePath.startsWith('data:image')) {
              try {
                final base64Data = qrImagePath.split(',').last;
                final img = pw.MemoryImage(base64Decode(base64Data));
                qrWidget = pw.Image(img, width: qrSize, height: qrSize);
              } catch (e) {
                debugPrint('Error parsing custom QR in PDF: $e');
              }
            }
          } else {
            final bin = b.cfg<String>('bankBin', '970422');
            final accNo = b.cfg<String>('accountNo', '');
            final accName = b.cfg<String>('accountName', '');
            if (accNo.isNotEmpty) {
              final qrType = b.cfg<String>('qrType', 'dynamic');
              final qrUrl = VietQrService.generateUrl(
                bankBin: bin,
                accountNo: accNo,
                accountName: accName,
                amount: qrType == 'static_amount' ? null : bill.total,
                addInfo: qrType == 'static_amount' ? null : bill.orderNumber,
              );
              qrWidget = pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(),
                data: qrUrl,
                width: qrSize,
                height: qrSize,
              );
            }
          }

          if (qrWidget == null) return null;

          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 6),
            child: pw.Column(
              children: [
                qrWidget,
                pw.SizedBox(height: 4),
                if (b.cfg<bool>('showLabel', true))
                  pw.Text(
                    b.cfg<String>('label', 'Quét để thanh toán'),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: fontBold, fontSize: 9),
                  ),
                if (qrSource == 'vietqr') ...[
                  pw.Text(
                    '${b.cfg<String>('accountNo', '')} - ${b.cfg<String>('accountName', '')}',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ],
            ),
          );
        }
      case BillBlockType.customText:
        {
          final text = b.cfg<String>('text', '');
          if (text.isEmpty) return null;
          final fs = b.cfg<int>('fontSize', 10).toDouble();
          final isBold = b.cfg<bool>('bold', false);
          final italic = b.cfg<bool>('italic', false);
          final align = _pdfAlign(b.cfg<String>('align', 'center'));
          final border = b.cfg<bool>('borderBox', false);
          final tw = pw.Text(
            text,
            textAlign: align,
            style: pw.TextStyle(
              font: isBold ? fontBold : font,
              fontSize: fs,
              fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
            ),
          );
          if (border) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 3),
              child: pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(border: pw.Border.all()),
                child: tw,
              ),
            );
          }
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: tw,
          );
        }
      case BillBlockType.spacer:
        return pw.SizedBox(height: b.cfg<double>('height', 8.0));
      case BillBlockType.footer:
        {
          final text = _cleanEmoji(b.cfg<String>('text', 'Cảm ơn quý khách!'));
          final sub = _cleanEmoji(b.cfg<String>('subText', ''));
          final fs = b.cfg<int>('fontSize', 12).toDouble();
          final isBold = b.cfg<bool>('bold', true);
          final align = _pdfAlign(b.cfg<String>('align', 'center'));
          return pw.Padding(
            padding: const pw.EdgeInsets.only(top: 8),
            child: pw.Column(
              children: [
                pw.Text(
                  text,
                  textAlign: align,
                  style: pw.TextStyle(
                    font: isBold ? fontBold : font,
                    fontSize: fs,
                  ),
                ),
                if (sub.isNotEmpty)
                  pw.Text(
                    sub,
                    textAlign: align,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: (fs - 2).clamp(6, 20),
                      color: PdfColors.black,
                    ),
                  ),
              ],
            ),
          );
        }
      case BillBlockType.appBranding:
        return _brandingPdf(font);
    }
  }

  /// Branding line bắt buộc — không thể xoá
  static pw.Widget _brandingPdf(pw.Font font) {
    return pw.Padding(
      // Chừa khoảng trống phía trên (tách khỏi lời cảm ơn) và phía dưới (để dòng cuối
      // không nằm sát thanh xé giấy của máy in cầm tay).
      padding: const pw.EdgeInsets.only(top: 14, bottom: 14),
      child: pw.Column(
        children: [
          pw.Divider(thickness: 0.7, height: 10, color: PdfColors.black),
          pw.Text(
            'Powered by Quán Nhỏ POS',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
              font: font,
              fontSize: 8,
              color: PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  // ── generateKitchenTicket: đọc từ KitchenTicketTemplate do chủ quán thiết kế ─────────
  static Future<Uint8List> generateKitchenTicket(
    BillData bill, {
    String stationKey = 'bepNong',
    pw.Font? customFont,
    pw.Font? customFontBold,
    double? paperMmOverride,
  }) async {
    final pdf = pw.Document();
    final font = customFont ?? await fontLoader.loadRegular();
    final fontBold = customFontBold ?? await fontLoader.loadBold();

    // Load template chủ quán đã thiết kế
    final tpl = await KitchenTicketTemplate.load(stationKey: stationKey);

    final paperMm = paperMmOverride ?? paperWidthMm(tpl.paperSize);
    final pageFormat = PdfPageFormat(
      paperMm * PdfPageFormat.mm,
      double.infinity,
      marginLeft: 2 * PdfPageFormat.mm,
      marginRight: 2 * PdfPageFormat.mm,
      marginTop: 5 * PdfPageFormat.mm,
      marginBottom: 5 * PdfPageFormat.mm,
    );

    final hfs = tpl.headerFontSize.toDouble();
    final tfs = tpl.tableFontSize.toDouble();
    final ifs = tpl.itemFontSize.toDouble();
    final qfs = tpl.qtyFontSize.toDouble();
    final bold = tpl.boldItemName ? fontBold : font;

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            // Tiêu đề
            pw.Text(
              tpl.headerText,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                font: fontBold,
                fontSize: hfs,
                letterSpacing: 1.5,
              ),
            ),
            pw.SizedBox(height: 4),

            // Bàn + số đơn
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (tpl.showTableName && bill.tableName != null)
                  pw.Text(
                    bill.tableName!,
                    style: pw.TextStyle(font: fontBold, fontSize: tfs),
                  ),
                if (tpl.showOrderNumber)
                  pw.Text(
                    '#${bill.orderNumber}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
              ],
            ),

            if (tpl.showDateTime)
              pw.Text(
                _fmtDate(bill.createdAt),
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: PdfColors.black,
                ),
              ),

            if (tpl.showWaiterName &&
                bill.waiterName != null &&
                bill.waiterName!.isNotEmpty) ...[
              pw.SizedBox(height: 2),
              pw.Text('NV gọi món: ${bill.waiterName!}',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 9,
                  color: PdfColors.black,
                ),
              ),
            ],

            if (tpl.showDivider) pw.Divider(thickness: 1, height: 10),

            // Danh sách món với số lượng vòng tròn
            ...bill.items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  pw.Container(
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        left: pw.BorderSide(color: PdfColors.black, width: 3),
                      ),
                    ),
                    padding: const pw.EdgeInsets.only(
                      left: 8,
                      top: 2,
                      bottom: 2,
                    ),
                    margin: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Vòng tròn số lượng
                        pw.Container(
                          width: qfs + 8,
                          height: qfs + 8,
                          decoration: const pw.BoxDecoration(
                            color: PdfColors.black,
                            shape: pw.BoxShape.circle,
                          ),
                          child: pw.Center(
                            child: pw.Text(
                              '${item.qty}',
                              style: pw.TextStyle(
                                font: fontBold,
                                fontSize: qfs,
                                color: PdfColors.white,
                              ),
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 8),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.name,
                                style: pw.TextStyle(font: bold, fontSize: ifs),
                              ),
                              if (tpl.showNote &&
                                  item.note != null &&
                                  item.note!.isNotEmpty)
                                pw.Column(
                                  crossAxisAlignment:
                                      pw.CrossAxisAlignment.start,
                                  children: item.note!.split('\n').map((line) {
                                    var displayLine = line;
                                    if (displayLine.startsWith(
                                      '+ Thêm món: ',
                                    )) {
                                      displayLine =
                                          '+ ${displayLine.substring('+ Thêm món: '.length)}';
                                    }
                                    return pw.Text(
                                      '   > $displayLine',
                                      style: pw.TextStyle(
                                        font: font,
                                        fontSize: ifs - 2,
                                        fontStyle: pw.FontStyle.italic,
                                        color: PdfColors.black,
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (idx < bill.items.length - 1)
                    pw.Divider(
                      thickness: 0.5,
                      height: 8,
                      color: PdfColors.black,
                    ),
                ],
              );
            }),

            if (tpl.showDivider) pw.Divider(thickness: 0.5, height: 8),

            // Ghi chú toàn đơn
            if (tpl.showNote && bill.note != null && bill.note!.isNotEmpty)
              pw.Text(
                'Lưu ý: ${bill.note!}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: fontBold, fontSize: 11),
              ),
          ],
        ),
      ),
    );

    return pdf.save();
  }

  static String _paymentLabel(String m) {
    switch (m) {
      case 'cash':
        return 'Tiền mặt';
      case 'card':
        return 'Thẻ';
      case 'momo':
        return 'MoMo';
      case 'transfer':
        return 'Chuyển khoản';
      default:
        return m;
    }
  }

  // ── generateBarLabels: In tem nhãn dán ly cho trạm Bar ──────────────────────────────
  static Future<List<Uint8List>> generateBarLabels(
    BillData bill, {
    pw.Font? customFont,
    pw.Font? customFontBold,
    BarLabelTemplate template = const BarLabelTemplate(),
  }) async {
    final List<Uint8List> results = [];
    final font = customFont ?? await fontLoader.loadRegular();
    final fontBold = customFontBold ?? await fontLoader.loadBold();
    final t = template;

    // Filter drinks (stationCode == 'bep_bar' || stationCode == 'bar')
    final barItems = bill.items
        .where((i) => i.stationCode == 'bep_bar' || i.stationCode == 'bar')
        .toList();
    if (barItems.isEmpty) return [];

    final headerParts = <String>[
      if (t.showOrderNumber) '#${bill.orderNumber}',
      if (t.showTableName && bill.tableName != null) bill.tableName!,
    ];
    final headerText = headerParts.join(' - ');

    for (final item in barItems) {
      // In từng nhãn dán cho mỗi số lượng ly
      for (int q = 1; q <= item.qty; q++) {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(
              t.widthMm * PdfPageFormat.mm,
              t.heightMm * PdfPageFormat.mm,
              marginAll: 2 * PdfPageFormat.mm,
            ),
            build: (ctx) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                if (headerText.isNotEmpty || t.showQtyIndex)
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        headerText,
                        style: pw.TextStyle(
                            font: fontBold, fontSize: t.infoFontSize.toDouble()),
                      ),
                      if (t.showQtyIndex)
                        pw.Text(
                          '$q/${item.qty}',
                          style: pw.TextStyle(
                              font: fontBold,
                              fontSize: t.infoFontSize.toDouble()),
                        ),
                    ],
                  ),
                if (t.showDivider) pw.Divider(thickness: 0.5, height: 4),
                pw.SizedBox(height: 1),
                pw.Text(
                  item.name,
                  style: pw.TextStyle(
                      font: t.boldName ? fontBold : font,
                      fontSize: t.nameFontSize.toDouble()),
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                ),
                if (t.showNote && item.note != null && item.note!.isNotEmpty) ...[
                  pw.SizedBox(height: 1),
                  pw.Text(
                    item.note!,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: t.noteFontSize.toDouble(),
                      fontStyle: pw.FontStyle.italic,
                      color: PdfColors.black,
                    ),
                    maxLines: 1,
                    overflow: pw.TextOverflow.clip,
                  ),
                ],
                pw.Spacer(),
                if (t.showTime)
                  pw.Align(
                    alignment: pw.Alignment.bottomRight,
                    child: pw.Text(
                      _fmtDate(bill.createdAt).split(' ').last, // chỉ giờ:phút
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 6,
                        color: PdfColors.black,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        results.add(await pdf.save());
      }
    }
    return results;
  }
}

// ─── Station Printer Dispatcher ──────────────────────────────────────────────

// ─── Station Printer Dispatcher ──────────────────────────────────────────────

enum StationPrintStatus { success, failed, skippedNoItems, notConfigured }

class StationPrintResult {
  final String stationCode;
  final StationPrintStatus status;
  final String? errorMessage;

  const StationPrintResult({
    required this.stationCode,
    required this.status,
    this.errorMessage,
  });

  bool get isSuccess =>
      status == StationPrintStatus.success ||
      status == StationPrintStatus.skippedNoItems;
}

class PrintDispatchResult {
  final Map<String, StationPrintResult> stationResults;

  const PrintDispatchResult(this.stationResults);

  bool get isOverallSuccess =>
      stationResults.values.isNotEmpty &&
      stationResults.values.every((r) => r.isSuccess);

  bool isStationSuccess(String stationCode) {
    final norm = normalizeStationCode(stationCode);
    final r = stationResults[norm] ?? stationResults[stationCode];
    return r != null && r.isSuccess;
  }
}

/// Interface cho Dịch vụ đẩy in (Printer Transport DI)
abstract class PrintTransport {
  Future<bool> printPdf(
    Uint8List bytes,
    PrinterConfig config,
    String jobName, {
    PdfPageFormat? format,
  });

  Future<bool> printKitchenDirect({
    required String printerIp,
    String? tableName,
    String? orderNumber,
    required List<BillItem> items,
    String? waiterName,
  });
}

class SystemPrintTransport implements PrintTransport {
  const SystemPrintTransport();

  @override
  Future<bool> printPdf(
    Uint8List bytes,
    PrinterConfig config,
    String jobName, {
    PdfPageFormat? format,
  }) {
    return StationPrinterDispatcher.dispatchPrintDefault(
      bytes,
      config,
      jobName,
      format: format,
    );
  }

  @override
  Future<bool> printKitchenDirect({
    required String printerIp,
    String? tableName,
    String? orderNumber,
    required List<BillItem> items,
    String? waiterName,
  }) {
    return StationPrinterDispatcher.printRawKitchenDirectDefault(
      printerIp: printerIp,
      tableName: tableName,
      orderNumber: orderNumber,
      items: items,
      waiterName: waiterName,
    );
  }
}

class StationPrinterDispatcher {
  static Future<bool> dispatchPrintDefault(
    Uint8List bytes,
    PrinterConfig config,
    String jobName, {
    PdfPageFormat? format,
  }) => _dispatchPrint(bytes, config, jobName, format: format);

  static Future<bool> printRawKitchenDirectDefault({
    required String printerIp,
    String? tableName,
    String? orderNumber,
    required List<BillItem> items,
    String? waiterName,
  }) => _printRawKitchenDirect(
    printerIp: printerIp,
    tableName: tableName,
    orderNumber: orderNumber,
    items: items,
    waiterName: waiterName,
  );

  static Future<void> printReport(
    Uint8List bytes,
    StationPrintersState settings, {
    PrintTransport transport = const SystemPrintTransport(),
  }) async {
    final format = const PdfPageFormat(
      80 * PdfPageFormat.mm,
      double.infinity,
      marginLeft: 2 * PdfPageFormat.mm,
      marginRight: 2 * PdfPageFormat.mm,
      marginTop: 5 * PdfPageFormat.mm,
      marginBottom: 5 * PdfPageFormat.mm,
    );
    await transport.printPdf(
      bytes,
      reportPrinterConfig(settings),
      'bao_cao_doanh_thu',
      format: format,
    );
  }

  /// Loại máy in thiết bị này in được. Sunmi tích hợp chỉ có trên Android.
  static Set<PrinterKind> get kSupportedPrinterKinds => {
    PrinterKind.system,
    PrinterKind.lan,
    if (SunmiBuiltinDriver.isSupportedPlatform) PrinterKind.sunmiBuiltin,
  };

  static const _offConfig = PrinterConfig(name: '', type: 'system', enabled: false);

  static PrinterConfig _pickConfig(
    PrintSetup setup,
    PrintJobType job,
    PrintContext ctx,
  ) {
    final resolved = PrintRouter.resolve(
      setup,
      job,
      ctx,
      supportedKinds: kSupportedPrinterKinds,
    );
    if (resolved.isEmpty) return _offConfig;
    final printer = resolved.first.printer;
    return PrinterConfig(
      darkness: printer.darkness,
      softBold: printer.softBold && printer.kind == PrinterKind.sunmiBuiltin,
      // Bố cục dàn rộng hơn bề rộng giấy khi "tỉ lệ chữ" < 100% (rồi co về đúng giấy khi in),
      // nên mọi cỡ chữ trong mẫu nhỏ đi theo cùng tỉ lệ mà không phải chỉnh từng khối.
      paperMm: (switch (printer.paper) {
            PaperWidth.mm50 || PaperWidth.mm58 => 48.0, // đầu in 58 mm: 384 điểm ~ 48 mm
            PaperWidth.mm80 => 70.0,
          }) /
          printer.fontScale.clamp(0.5, 1.5),
      name: printer.kind == PrinterKind.sunmiBuiltin ? printer.name : printer.address,
      type: switch (printer.kind) {
        PrinterKind.lan => 'network',
        PrinterKind.sunmiBuiltin => 'sunmi',
        PrinterKind.system => 'system',
      },
      enabled: true,
    );
  }

  static PrintContext _ctxOf(
    StationPrintersState settings, {
    PrintServiceType? serviceType,
  }) => PrintContext(
    serviceType: serviceType,
    sourceDeviceId:
        settings.currentDeviceId.isEmpty ? null : settings.currentDeviceId,
    hasBuiltinPrinter: SunmiBuiltinDriver.hasBuiltinPrinter,
  );

  /// Suy ra hình thức phục vụ từ tên bàn trên bill (bill chưa có trường riêng).
  /// Tên rỗng hoặc có "Mang về" -> mang đi; có "Giao" -> giao hàng; còn lại -> tại bàn.
  /// (Đặt qua QR chưa nhận diện được từ bill nên rơi vào nhóm tại bàn/mang đi.)
  static PrintServiceType serviceTypeOfBill(BillData bill) {
    final n = (bill.tableName ?? '').toLowerCase().trim();
    if (n.isEmpty || n.contains('mang về') || n.contains('mang ve')) {
      return PrintServiceType.takeaway;
    }
    if (n.contains('giao')) return PrintServiceType.delivery;
    return PrintServiceType.dineIn;
  }

  /// Khi quán đã có thiết lập in mới (máy in + luật in), thay cấu hình 4 trạm cũ
  /// bằng máy in mà luật chọn. Chưa có thiết lập -> trả nguyên `settings` (hành vi cũ).
  /// Mọi nơi cần biết "trạm này in ra đâu / có bật không" nên đọc qua hàm này.
  static StationPrintersState effectiveSettings(
    StationPrintersState settings, {
    bool provisional = false,
    PrintServiceType? serviceType,
  }) {
    final setup = settings.printSetup;
    if (setup.isEmpty) return settings;
    final ctx = _ctxOf(settings, serviceType: serviceType);
    return settings.copyWith(
      cashier: _pickConfig(
        setup,
        provisional ? PrintJobType.provisional : PrintJobType.receipt,
        ctx,
      ),
      bepNong: _pickConfig(setup, PrintJobType.kitchenHot, ctx),
      bepBar: _pickConfig(setup, PrintJobType.kitchenBar, ctx),
      barLabel: _pickConfig(setup, PrintJobType.label, ctx),
    );
  }

  static StationPrintersState applyPrintSetup(
    StationPrintersState settings,
    BillData bill,
  ) => effectiveSettings(
    settings,
    provisional: bill.orderNumber.toUpperCase().contains('TẠM TÍNH'),
    serviceType: serviceTypeOfBill(bill),
  );

  /// Máy in dùng cho báo cáo: luật "báo cáo" nếu có, không thì máy in hóa đơn.
  static PrinterConfig reportPrinterConfig(StationPrintersState settings) {
    final setup = settings.printSetup;
    if (setup.isEmpty) return settings.cashier;
    final ctx = _ctxOf(settings);
    final byReport = _pickConfig(setup, PrintJobType.report, ctx);
    return byReport.enabled
        ? byReport
        : _pickConfig(setup, PrintJobType.receipt, ctx);
  }

  static Future<PrintDispatchResult> printBill(
    BillData bill,
    StationPrintersState settings, {
    bool onlyReceipt = false,
    bool onlyKitchen = false,
    PrintTransport transport = const SystemPrintTransport(),
    Set<String>? skipStationCodes,
  }) async {
    settings = applyPrintSetup(settings, bill);
    // Windows: tự dùng máy in QN-… do công cụ "Cài máy in" tạo (không phải chọn lại trong POS).
    settings = await QnQueueResolver.apply(settings);
    final Map<String, StationPrintResult> results = {};
    final skips = skipStationCodes ?? {};

    // 1. In hoá đơn thu ngân
    if (!onlyKitchen && bill.type == BillType.receipt) {
      if (skips.contains('cashier')) {
        results['cashier'] = const StationPrintResult(
          stationCode: 'cashier',
          status: StationPrintStatus.skippedNoItems,
        );
      } else if (!settings.cashier.enabled) {
        results['cashier'] = const StationPrintResult(
          stationCode: 'cashier',
          status: StationPrintStatus.notConfigured,
        );
      } else {
        try {
          final bytes = await BillPdfGenerator.generateReceipt(
            bill,
            stationKey: 'cashier',
            paperMmOverride: settings.cashier.paperMm,
            customFontBold: settings.cashier.softBold
                ? await BillPdfGenerator.softBoldFont()
                : null,
          );
          final tpl = await BillBlockTemplate.load(stationKey: 'cashier');
          final paperMm = settings.cashier.paperMm ?? paperWidthMm(tpl.paperSize);
          final format = PdfPageFormat(
            paperMm * PdfPageFormat.mm,
            double.infinity,
            marginLeft: 2 * PdfPageFormat.mm,
            marginRight: 2 * PdfPageFormat.mm,
            marginTop: 5 * PdfPageFormat.mm,
            marginBottom: 5 * PdfPageFormat.mm,
          );

          // Mở két theo máy in thật đang in bill. Máy in tích hợp Sunmi không có két nên bỏ qua.
          if (settings.autoOpenDrawer) {
            if (settings.cashier.type == 'network' &&
                settings.cashier.name.isNotEmpty) {
              ThermalPrinterService.openCashDrawer(
                printerIp: settings.cashier.name,
              ).catchError((_) => null);
            } else if (settings.cashier.type == 'system' && !kIsWeb) {
              // Windows: gửi lệnh thô vào máy in hệ thống (két nối cổng RJ11 của máy in bill).
              ThermalPrinterService.openCashDrawerWindows(
                printerName: settings.cashier.name,
              ).catchError((_) => false);
            }
          }
          final printOk = await transport.printPdf(
            bytes,
            settings.cashier,
            'hoa_don_${bill.orderNumber}',
            format: format,
          );
          results['cashier'] = StationPrintResult(
            stationCode: 'cashier',
            status: printOk
                ? StationPrintStatus.success
                : StationPrintStatus.failed,
            errorMessage: printOk
                ? null
                : 'Lỗi đẩy in hóa đơn thu ngân (đã huỷ hoặc lỗi kết nối)'
          );
        } catch (e) {
          results['cashier'] = StationPrintResult(
            stationCode: 'cashier',
            status: StationPrintStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }
    }

    // 2. In phiếu bếp nóng (station 'nong')
    if (!onlyReceipt) {
      final hotItems = bill.items
          .where((i) => normalizeStationCode(i.stationCode) == 'nong')
          .toList();
      if (skips.contains('nong') || hotItems.isEmpty) {
        results['nong'] = const StationPrintResult(
          stationCode: 'nong',
          status: StationPrintStatus.skippedNoItems,
        );
      } else if (!settings.bepNong.enabled) {
        results['nong'] = const StationPrintResult(
          stationCode: 'nong',
          status: StationPrintStatus.notConfigured,
          errorMessage: 'Máy in bếp nóng chưa bật',
        );
      } else {
        try {
          bool printOk = false;
          if (!kIsWeb &&
              settings.bepNong.type == 'network' &&
              settings.bepNong.name.isNotEmpty) {
            printOk = await transport.printKitchenDirect(
              printerIp: settings.bepNong.name,
              tableName: bill.tableName,
              orderNumber: bill.orderNumber,
              items: hotItems,
              waiterName: bill.waiterName,
            );
          } else {
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
              waiterName: bill.waiterName,
            );
            final bytes = await BillPdfGenerator.generateKitchenTicket(
              hotBill,
              stationKey: 'bepNong',
              paperMmOverride: settings.bepNong.paperMm,
              customFontBold: settings.bepNong.softBold
                  ? await BillPdfGenerator.softBoldFont()
                  : null,
            );
            final tpl = await KitchenTicketTemplate.load(stationKey: 'bepNong');
            final paperMm = settings.bepNong.paperMm ?? paperWidthMm(tpl.paperSize);
            final format = PdfPageFormat(
              paperMm * PdfPageFormat.mm,
              double.infinity,
              marginLeft: 2 * PdfPageFormat.mm,
              marginRight: 2 * PdfPageFormat.mm,
              marginTop: 5 * PdfPageFormat.mm,
              marginBottom: 5 * PdfPageFormat.mm,
            );
            printOk = await transport.printPdf(
              bytes,
              settings.bepNong,
              'phieu_bep_nong_${bill.orderNumber}',
              format: format,
            );
          }
          results['nong'] = StationPrintResult(
            stationCode: 'nong',
            status: printOk
                ? StationPrintStatus.success
                : StationPrintStatus.failed,
            errorMessage: printOk ? null : 'Lỗi đẩy in bếp nóng',
          );
        } catch (e) {
          results['nong'] = StationPrintResult(
            stationCode: 'nong',
            status: StationPrintStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }
    }

    // 3. In phiếu bếp bar (station 'bar')
    if (!onlyReceipt) {
      final barItems = bill.items
          .where((i) => normalizeStationCode(i.stationCode) == 'bar')
          .toList();
      if (skips.contains('bar') || barItems.isEmpty) {
        results['bar'] = const StationPrintResult(
          stationCode: 'bar',
          status: StationPrintStatus.skippedNoItems,
        );
      } else if (!settings.bepBar.enabled) {
        results['bar'] = const StationPrintResult(
          stationCode: 'bar',
          status: StationPrintStatus.notConfigured,
          errorMessage: 'Máy in bếp bar chưa bật',
        );
      } else {
        try {
          bool printOk = false;
          if (!kIsWeb &&
              settings.bepBar.type == 'network' &&
              settings.bepBar.name.isNotEmpty) {
            printOk = await transport.printKitchenDirect(
              printerIp: settings.bepBar.name,
              tableName: bill.tableName,
              orderNumber: bill.orderNumber,
              items: barItems,
              waiterName: bill.waiterName,
            );
          } else {
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
              waiterName: bill.waiterName,
            );
            final bytes = await BillPdfGenerator.generateKitchenTicket(
              barBill,
              stationKey: 'bepBar',
              paperMmOverride: settings.bepBar.paperMm,
              customFontBold: settings.bepBar.softBold
                  ? await BillPdfGenerator.softBoldFont()
                  : null,
            );
            final tpl = await KitchenTicketTemplate.load(stationKey: 'bepBar');
            final paperMm = settings.bepBar.paperMm ?? paperWidthMm(tpl.paperSize);
            final format = PdfPageFormat(
              paperMm * PdfPageFormat.mm,
              double.infinity,
              marginLeft: 2 * PdfPageFormat.mm,
              marginRight: 2 * PdfPageFormat.mm,
              marginTop: 5 * PdfPageFormat.mm,
              marginBottom: 5 * PdfPageFormat.mm,
            );
            printOk = await transport.printPdf(
              bytes,
              settings.bepBar,
              'phieu_bep_bar_${bill.orderNumber}',
              format: format,
            );
          }
          results['bar'] = StationPrintResult(
            stationCode: 'bar',
            status: printOk
                ? StationPrintStatus.success
                : StationPrintStatus.failed,
            errorMessage: printOk ? null : 'Lỗi đẩy in bếp bar',
          );
        } catch (e) {
          results['bar'] = StationPrintResult(
            stationCode: 'bar',
            status: StationPrintStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }
    }

    // 4. In nhãn dán ly (Bar Label)
    if (!onlyReceipt && settings.barLabel.enabled) {
      if (skips.contains('barLabel')) {
        results['barLabel'] = const StationPrintResult(
          stationCode: 'barLabel',
          status: StationPrintStatus.skippedNoItems,
        );
      } else {
        try {
          final labelTpl = await BarLabelTemplate.load();
          final labelBytesList = await BillPdfGenerator.generateBarLabels(
              bill,
              template: labelTpl);
          if (labelBytesList.isEmpty) {
            final barItems = bill.items
                .where((i) => normalizeStationCode(i.stationCode) == 'bar')
                .toList();
            results['barLabel'] = StationPrintResult(
              stationCode: 'barLabel',
              status: barItems.isEmpty
                  ? StationPrintStatus.skippedNoItems
                  : StationPrintStatus.failed,
              errorMessage: barItems.isEmpty
                  ? null
                  : 'Tạo tem ly thất bại (không có món)'
            );
          } else {
            bool allLabelOk = true;
            for (int i = 0; i < labelBytesList.length; i++) {
              final ok = await transport.printPdf(
                labelBytesList[i],
                settings.barLabel,
                'tem_bar_${bill.orderNumber}_$i',
                format: PdfPageFormat(
                  labelTpl.widthMm * PdfPageFormat.mm,
                  labelTpl.heightMm * PdfPageFormat.mm,
                  marginLeft: 2 * PdfPageFormat.mm,
                  marginRight: 2 * PdfPageFormat.mm,
                  marginTop: 2 * PdfPageFormat.mm,
                  marginBottom: 2 * PdfPageFormat.mm,
                ),
              );
              if (!ok) allLabelOk = false;
            }
            results['barLabel'] = StationPrintResult(
              stationCode: 'barLabel',
              status: allLabelOk
                  ? StationPrintStatus.success
                  : StationPrintStatus.failed,
              errorMessage: allLabelOk ? null : 'In tem dán ly thất bại',
            );
          }
        } catch (e) {
          results['barLabel'] = StationPrintResult(
            stationCode: 'barLabel',
            status: StationPrintStatus.failed,
            errorMessage: e.toString(),
          );
        }
      }
    }

    // 5. Kiểm tra các trạm tùy chỉnh / chưa xác định (unknown station)
    if (!onlyReceipt) {
      for (final item in bill.items) {
        final normCode = normalizeStationCode(item.stationCode);
        if (normCode != 'nong' && normCode != 'bar' && normCode != 'cashier') {
          if (!results.containsKey(normCode)) {
            results[normCode] = StationPrintResult(
              stationCode: normCode,
              status: StationPrintStatus.notConfigured,
              errorMessage: 'Trạm $normCode chưa được cấu hình máy in',
            );
          }
        }
      }
    }

    return PrintDispatchResult(results);
  }

  // ── In trực tiếp qua Socket không cần qua hộp thoại PDF (Dành cho Native & Mạng IP) ──
  static Future<bool> _printRawKitchenDirect({
    required String printerIp,
    String? tableName,
    String? orderNumber,
    required List<BillItem> items,
    String? waiterName,
  }) async {
    try {
      final ticketItems = items.map((i) {
        final List<String> modifiers = [];
        String? freeNote;
        if (i.note != null && i.note!.isNotEmpty) {
          final lines = i.note!.split('\n');
          for (final line in lines) {
            if (line.startsWith('+ Thêm món: ')) {
              final mStr = line.substring('+ Thêm món: '.length);
              modifiers.addAll(mStr.split(', ').map((s) => s.trim()));
            } else if (line.startsWith('+ ')) {
              final mStr = line.substring('+ '.length);
              modifiers.addAll(mStr.split(', ').map((s) => s.trim()));
            } else if (line.startsWith('Ghi chú: ')) {
              freeNote = line.substring('Ghi chú: '.length).trim();
            } else {
              modifiers.add(line.trim());
            }
          }
        }
        return TicketItemData(
          name: i.name,
          quantity: i.qty.toDouble(),
          modifiers: modifiers,
          note: freeNote,
        );
      }).toList();

      int round = 1;
      final safeOrderNumber = orderNumber ?? '';
      final roundRegex = RegExp(r'Đợt\s*(\d+)', caseSensitive: false);
      final match = roundRegex.firstMatch(safeOrderNumber);
      if (match != null) {
        round = int.tryParse(match.group(1) ?? '1') ?? 1;
      }

      final result = await ThermalPrinterService.printKitchenTicket(
        printerIp: printerIp,
        tableLabel: tableName ?? 'Mang về',
        zoneLabel: 'Khu Vực',
        round: round,
        items: ticketItems,
        sentAt: DateTime.now().millisecondsSinceEpoch,
        waiterName: waiterName,
      );
      if (!result.ok) {
        writePrintLog(
          '[DirectPrint ERROR] Không in được phiếu bếp qua socket tới $printerIp: ${result.error}',
        );
        return false;
      }
      writePrintLog('[DirectPrint] In thành công qua socket tới: $printerIp');
      return true;
    } catch (e) {
      debugPrint('[DirectPrint] Lỗi in qua socket tới $printerIp: $e');
      return false;
    }
  }

  /// Hàng đợi do công cụ "Cài máy in" tạo (QN-ThuNgan, QN-Bep, QN-Bar, QN-Tem).
  static bool isQnRawQueue(String name) => name.startsWith('QN-');

  static Future<bool> _printRawRaster(
    Uint8List pdf,
    PrinterConfig config,
    String jobName,
    PdfPageFormat format,
  ) async {
    try {
      final narrow = (config.paperMm ?? 70) < 60;
      final dots = narrow ? 384 : 576; // 58mm / 80mm ở 203 dpi
      final widthInch = format.width / PdfPageFormat.inch;
      final dpi = dots / widthInch;
      final out = BytesBuilder()..add(escposInit);
      await for (final page in Printing.raster(pdf, dpi: dpi)) {
        out.add(escposRaster(page.pixels, page.width, page.height, dotsWide: dots));
      }
      out.add(escposFeedAndCut());
      final ok = await ThermalPrinterService.sendRawWindows(
          config.name, out.toBytes());
      writePrintLog('[_printRawRaster] $jobName -> ${config.name}: $ok');
      return ok;
    } catch (e) {
      writePrintLog('[_printRawRaster ERROR] $e');
      return false;
    }
  }

  static Future<bool> _dispatchPrint(
    Uint8List bytes,
    PrinterConfig config,
    String jobName, {
    PdfPageFormat? format,
  }) async {
    writePrintLog(
      '[_dispatchPrint] Start: $jobName. Printer: ${config.name}, Type: ${config.type}, Enabled: ${config.enabled}',
    );
    final finalFormat = format ?? PdfPageFormat.roll80;
    if (kIsWeb) {
      writePrintLog('[_dispatchPrint] Web fallback');
      final ok = await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: jobName,
        format: finalFormat,
      );
      return ok;
    }
    if (config.type == 'sunmi') {
      final r = await SunmiBuiltinDriver.printPdf(
        bytes,
        threshold: SunmiBuiltinDriver.thresholdForDarkness(config.darkness),
      );
      writePrintLog('[_dispatchPrint] Sunmi: $r');
      return r.ok;
    }
    // Máy in dựng bởi công cụ "Cài máy in" (QN-...): driver chung chỉ nhận chữ, nên bill được
    // vẽ thành ảnh rồi gửi lệnh ESC/POS thô thẳng vào hàng đợi — không cần driver hãng.
    if (config.type == 'system' &&
        !kIsWeb &&
        Platform.isWindows &&
        isQnRawQueue(config.name)) {
      return _printRawRaster(bytes, config, jobName, finalFormat);
    }
    if (config.type == 'system') {
      Printer? targetPrinter;
      if (config.name.isNotEmpty) {
        targetPrinter = Printer(url: config.name, name: config.name);
      } else {
        // KHÔNG tự lấy máy in mặc định của Windows: từng làm bill thanh toán ra nhầm
        // máy Canon thay vì máy in bill (21:09 ngày 18/10). Báo lỗi để hệ thống trả quyền in
        // cho máy khác và thu ngân thấy cảnh báo + nút In lại.
        writePrintLog(
          '[_dispatchPrint ERROR] Tên máy in trống cho "$jobName" -> KHÔNG in (không dùng máy in mặc định).',
        );
        AppLogger.error(
          'printer',
          'Tên máy in trống cho "$jobName": không in, không dùng máy in mặc định của Windows',
        );
        return false;
      }

      if (targetPrinter != null) {
        try {
          writePrintLog(
            '[_dispatchPrint] Calling directPrintPdf for ${targetPrinter.name}',
          );
          final success = await Printing.directPrintPdf(
            printer: targetPrinter,
            onLayout: (_) async => bytes,
            name: jobName,
            format: finalFormat,
          );
          writePrintLog('[_dispatchPrint] Result: $success');
          return success;
        } catch (e) {
          writePrintLog('[_dispatchPrint ERROR] directPrintPdf failed: $e');
          return false;
        }
      } else {
        writePrintLog('[_dispatchPrint ERROR] No valid system printer found.');
        return false;
      }
    } else {
      writePrintLog('[_dispatchPrint] Checking IP printer ${config.name}:9100');
      try {
        final socket = await Socket.connect(
          config.name,
          9100,
          timeout: const Duration(seconds: 3),
        );
        writePrintLog('[_dispatchPrint] Connected to IP ${config.name}.');
        await socket.close();
        final ok = await Printing.layoutPdf(
          onLayout: (_) async => bytes,
          name: jobName,
          format: finalFormat,
        );
        return ok;
      } catch (e) {
        writePrintLog(
          '[_dispatchPrint ERROR] Connection failed: $e. Fallback.',
        );
        return false;
      }
    }
  }
}

// ─── Bill Preview Screen ──────────────────────────────────────────────────────

class BillPreviewScreen extends StatefulWidget {
  final BillData bill;
  final bool isKitchen;
  final String? stationKey;

  const BillPreviewScreen({
    super.key,
    required this.bill,
    this.isKitchen = false,
    this.stationKey,
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
          ? await BillPdfGenerator.generateKitchenTicket(
              widget.bill,
              stationKey: widget.stationKey ?? 'bepNong',
            )
          : await BillPdfGenerator.generateReceipt(
              widget.bill,
              stationKey: widget.stationKey ?? 'cashier',
            );
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
                      : 'hoa_don_${bill.orderNumber}.pdf',
                );
              },
            ),
        ],
      ),
      body: _error.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Lỗi tạo hoá đơn:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
            )
          : _cachedBytes == null
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Đang tạo hoá đơn...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
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
                              : 'hoa_don_${bill.orderNumber}',
                          format: fmt,
                        );
                      },
                    ),
                  ],
                );
                if (!isLarge) return preview; // phone: full width bình thường
                // Tablet: hiện như tờ giấy giữa nền tối
                return Container(
                  color: const Color(0xFF131736),
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: receiptWidth, child: preview),
                );
              },
            ),
    );
  }
}

// ─── Helper Function — Mở hoá đơn nhanh ─────────────────────────────────────

Future<void> showBillPreview(
  BuildContext context,
  BillData bill, {
  bool isKitchen = false,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BillPreviewScreen(bill: bill, isKitchen: isKitchen),
    ),
  );
}
