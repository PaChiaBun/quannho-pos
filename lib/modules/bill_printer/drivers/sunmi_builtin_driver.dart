// lib/modules/bill_printer/drivers/sunmi_builtin_driver.dart
// Driver máy in nhiệt tích hợp của thiết bị Sunmi (V3...). Chỉ chạy trên Android.
// In bằng ẢNH (PDF -> bitmap) nên giữ được tiếng Việt có dấu và đúng mẫu thiết kế.

import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../../../core/utils/app_logger.dart';

class SunmiPrintResult {
  final bool ok;
  final String message;
  const SunmiPrintResult(this.ok, this.message);
  @override
  String toString() => 'SunmiPrintResult(ok=$ok, $message)';
}

class SunmiBuiltinDriver {
  const SunmiBuiltinDriver._();

  /// Số điểm ảnh ngang của đầu in 58 mm (vùng in ~48 mm, 203 dpi).
  static const int kHeadDots = 384;
  static const double kDpi = 203;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static void _log(String m) => AppLogger.info('printer', '[Sunmi] $m');

  /// Kiểm tra dịch vụ in tích hợp có sẵn sàng không (gói tự kết nối khi khởi động;
  /// hàm bindingPrinter/initPrinter của gói là hàm rỗng đã bỏ nên không dùng).
  /// Ghi log trạng thái, giấy, phiên bản để chẩn đoán trên máy thật.
  static Future<bool> bind() async {
    if (!isSupportedPlatform) return false;
    try {
      final p = SunmiPrinterPlus();
      final status = await p.getStatus();
      final paper = await p.getPaper();
      final version = await p.getVersion();
      final type = await p.getType();
      _log('status=$status paper=$paper version=$version type=$type');
      if (status != null) return true;
      _log('status null -> thử rebind');
      return await p.rebindPrinter();
    } catch (e) {
      _log('kiểm tra dịch vụ in lỗi: $e');
      return false;
    }
  }

  /// In một file PDF (bill, phiếu...) ra máy in tích hợp, dạng ảnh.
  /// [copies] số bản. PDF nên có bề rộng trang ~48 mm.
  static Future<SunmiPrintResult> printPdf(
    Uint8List pdfBytes, {
    int copies = 1,
    int feedLines = 4,
  }) async {
    if (!isSupportedPlatform) {
      return const SunmiPrintResult(false, 'Chỉ in được trên thiết bị Android Sunmi');
    }
    try {
      if (!await bind()) {
        return const SunmiPrintResult(false, 'Không kết nối được dịch vụ in tích hợp');
      }
      // Co ảnh về đúng bề rộng đầu in: đo trang đầu ở dpi chuẩn rồi chỉnh lại dpi.
      var dpi = kDpi;
      await for (final first in Printing.raster(pdfBytes, pages: const [0], dpi: kDpi)) {
        if (first.width > 0 && (first.width - kHeadDots).abs() > 2) {
          dpi = kDpi * kHeadDots / first.width;
          _log('trang rộng ${first.width}px -> chỉnh dpi ${dpi.toStringAsFixed(1)}');
        }
        break;
      }
      final pages = <Uint8List>[];
      await for (final page in Printing.raster(pdfBytes, dpi: dpi)) {
        pages.add(await page.toPng());
        _log('trang ${pages.length}: ${page.width}x${page.height}px');
      }
      if (pages.isEmpty) return const SunmiPrintResult(false, 'PDF rỗng');
      for (var c = 0; c < copies.clamp(1, 9); c++) {
        for (final png in pages) {
          await SunmiPrinter.printImage(png);
        }
        await SunmiPrinter.lineWrap(feedLines);
      }
      _log('đã gửi ${pages.length} trang x $copies bản');
      return const SunmiPrintResult(true, 'Đã gửi lệnh in');
    } catch (e, st) {
      _log('printPdf lỗi: $e\n$st');
      return SunmiPrintResult(false, 'Lỗi in: $e');
    }
  }

  /// Phiếu in thử: thước kẻ hai mép, tiếng Việt có dấu, thông tin khổ giấy.
  static Future<SunmiPrintResult> printTestSlip({
    String deviceName = '',
    Future<pw.Font> Function()? loadRegular,
    Future<pw.Font> Function()? loadBold,
  }) async {
    final regular = await (loadRegular ?? PdfGoogleFonts.notoSansRegular)();
    final bold = await (loadBold ?? PdfGoogleFonts.notoSansBold)();
    final doc = pw.Document();
    final wMm = kHeadDots / kDpi * 25.4; // ~48 mm
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(wMm * PdfPageFormat.mm, double.infinity,
            marginAll: 0),
        build: (_) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          padding: const pw.EdgeInsets.all(4),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Center(
              child: pw.Text('IN THỬ MÁY IN SUNMI',
                  style: pw.TextStyle(font: bold, fontSize: 13)),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Quán Nhỏ POS', style: pw.TextStyle(font: bold, fontSize: 11)),
            pw.Text('Thiết bị: ${deviceName.isEmpty ? 'Sunmi' : deviceName}',
                style: pw.TextStyle(font: regular, fontSize: 9)),
            pw.Text('Khổ ảnh: $kHeadDots điểm (~${wMm.toStringAsFixed(0)} mm)',
                style: pw.TextStyle(font: regular, fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text('Tiếng Việt: Đặng Thị Hương',
                style: pw.TextStyle(font: regular, fontSize: 10)),
            pw.Text('Bún bò Huế • Cà phê sữa đá',
                style: pw.TextStyle(font: regular, fontSize: 10)),
            pw.Text('Ghi chú: ít đường, không đá',
                style: pw.TextStyle(font: regular, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('|<- mép trái', style: pw.TextStyle(font: regular, fontSize: 8)),
              pw.Text('mép phải ->|', style: pw.TextStyle(font: regular, fontSize: 8)),
            ]),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text('2x Phở bò', style: pw.TextStyle(font: regular, fontSize: 10)),
              pw.Text('170.000đ', style: pw.TextStyle(font: bold, fontSize: 10)),
            ]),
            pw.SizedBox(height: 2),
            pw.Text('0123456789 ABCDEFGHIJKLMNOPQRS',
                style: pw.TextStyle(font: regular, fontSize: 8)),
          ]),
        ),
      ),
    );
    return printPdf(await doc.save());
  }
}
