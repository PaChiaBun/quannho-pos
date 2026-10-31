// lib/modules/bill_printer/drivers/sunmi_builtin_driver.dart
// Driver máy in nhiệt tích hợp của thiết bị Sunmi (V3...). Chỉ chạy trên Android.
// In bằng ẢNH (PDF -> bitmap) nên giữ được tiếng Việt có dấu và đúng mẫu thiết kế.

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';
import '../../../core/utils/app_logger.dart';
import '../fonts/bill_fonts.dart';


/// Dữ liệu điểm ảnh RGBA thô của một trang (để chuyển sang luồng nền).
class _RasterJob {
  final Uint8List rgba;
  final int width;
  final int height;
  final int targetWidth;
  final int threshold;
  const _RasterJob(this.rgba, this.width, this.height, this.targetWidth, this.threshold);
}

/// Chuyển ảnh RGBA (vẽ ở độ phân giải cao, nền có thể trong suốt) thành ảnh PNG ĐEN–TRẮNG sắc nét,
/// đúng [targetWidth] điểm. Thu nhỏ bằng trung bình vùng (anti-alias) rồi cắt ngưỡng, nên nét chữ sắc,
/// không loang như khi máy in tự đổi ảnh xám sang đen trắng (đặc biệt chữ đậm).
/// [threshold] 0–255: điểm tối hơn ngưỡng thành đen. Ngưỡng thấp => nét mảnh hơn.
Uint8List crispBlackWhiteFromRgba(
  Uint8List rgba,
  int width,
  int height, {
  required int targetWidth,
  int threshold = 118,
}) {
  final outH = (height * targetWidth / width).round().clamp(1, 1 << 20);
  final out = img.Image(width: targetWidth, height: outH, numChannels: 1);
  final sx = width / targetWidth;
  final sy = height / outH;
  for (var oy = 0; oy < outH; oy++) {
    final y0 = (oy * sy).floor();
    final y1 = (((oy + 1) * sy).ceil()).clamp(y0 + 1, height);
    for (var ox = 0; ox < targetWidth; ox++) {
      final x0 = (ox * sx).floor();
      final x1 = (((ox + 1) * sx).ceil()).clamp(x0 + 1, width);
      var sum = 0;
      var n = 0;
      for (var y = y0; y < y1; y++) {
        var i = (y * width + x0) * 4;
        for (var x = x0; x < x1; x++, i += 4) {
          final a = rgba[i + 3];
          // Nền trong suốt -> trắng; trộn alpha lên nền trắng, rồi lấy độ sáng.
          final r = (rgba[i] * a + 255 * (255 - a)) ~/ 255;
          final g = (rgba[i + 1] * a + 255 * (255 - a)) ~/ 255;
          final b = (rgba[i + 2] * a + 255 * (255 - a)) ~/ 255;
          sum += (r * 299 + g * 587 + b * 114) ~/ 1000;
          n++;
        }
      }
      final lum = n == 0 ? 255 : sum ~/ n;
      out.setPixelR(ox, oy, lum < threshold ? 0 : 255);
    }
  }
  return Uint8List.fromList(img.encodePng(out));
}

Uint8List _crispJob(_RasterJob j) => crispBlackWhiteFromRgba(
      j.rgba,
      j.width,
      j.height,
      targetWidth: j.targetWidth,
      threshold: j.threshold,
    );

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

  /// Ngưỡng đen/trắng theo độ đậm 1–5 (cao hơn = nét đậm hơn). 3 là mặc định.
  /// Ngưỡng thấp làm chữ thường mảnh, mờ; ngưỡng quá cao làm chữ đậm bị bết, loang.
  static const List<int> kThresholdByDarkness = [100, 135, 165, 190, 215];

  static int thresholdForDarkness(int darkness) =>
      kThresholdByDarkness[darkness.clamp(1, 5) - 1];

  static const int kBlackThreshold = 165;

  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Đã xác nhận máy này có máy in Sunmi tích hợp (gọi [detect] lúc khởi động).
  static bool hasBuiltinPrinter = false;

  /// Dò máy in tích hợp; chỉ máy Sunmi thật mới trả trạng thái.
  /// Dịch vụ in Sunmi kết nối xong sau khi app mở vài trăm ms (trước đó getStatus lỗi),
  /// nên dò lại tới khi thấy máy in thay vì kết luận "không có" ngay lần đầu.
  static Future<void> detect({
    int tries = 10,
    Duration gap = const Duration(milliseconds: 500),
  }) async {
    if (!isSupportedPlatform) return;
    for (var i = 0; i < tries && !hasBuiltinPrinter; i++) {
      try {
        hasBuiltinPrinter = (await SunmiPrinterPlus().getStatus()) != null;
      } catch (_) {}
      if (hasBuiltinPrinter) {
        _log('phát hiện máy in tích hợp (lần dò ${i + 1})');
      } else {
        await Future.delayed(gap);
      }
    }
  }

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
      if (status != null) return hasBuiltinPrinter = true;
      _log('status null -> thử rebind');
      final ok = await p.rebindPrinter();
      if (ok) hasBuiltinPrinter = true;
      return ok;
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
    int feedLines = 6, // đẩy giấy qua thanh xé để dòng cuối không bị cắt
    int threshold = kBlackThreshold,
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
      // Vẽ ở độ phân giải gấp 2 rồi thu về đúng 384 điểm, đen trắng sắc nét, xử lý ở luồng nền.
      const supersample = 2;
      final pages = <Uint8List>[];
      await for (final page in Printing.raster(pdfBytes, dpi: dpi * supersample)) {
        final crisp = await compute(
          _crispJob,
          _RasterJob(page.pixels, page.width, page.height, kHeadDots, threshold),
        );
        pages.add(crisp);
        _log('trang ${pages.length}: ${page.width}x${page.height}px -> $kHeadDots px đen-trắng');
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
    final regular = await (loadRegular ?? BillFonts.regular)();
    final bold = await (loadBold ?? BillFonts.bold)();
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

  /// In cùng một đoạn mẫu ở 5 mức độ đậm (nhãn "Độ đậm 1..5") để chọn mức nhìn đẹp nhất.
  static Future<SunmiPrintResult> printDarknessComparison({
    int fromDarkness = 1,
    int toDarkness = 5,
    double fontScale = 1.0,
    Future<pw.Font> Function()? loadRegular,
    Future<pw.Font> Function()? loadBold,
  }) async {
    final regular = await (loadRegular ?? BillFonts.regular)();
    // So sánh: Bold thường (cột trái) và bán đậm (cột phải) ở từng mức độ đậm.
    final bold = await (loadBold ?? BillFonts.bold)();
    pw.Font semi;
    try {
      semi = await BillFonts.semiBold() ?? bold;
    } catch (_) {
      semi = bold;
    }
    final wMm = kHeadDots / kDpi * 25.4 / fontScale;
    SunmiPrintResult last = const SunmiPrintResult(true, 'Không có gì để in');
    for (var d = fromDarkness; d <= toDarkness; d++) {
      final doc = pw.Document();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(wMm * PdfPageFormat.mm, double.infinity, marginAll: 4),
          build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Độ đậm $d / 5', style: pw.TextStyle(font: bold, fontSize: 12)),
            pw.Text('Trà Tắc Cửu Long   x1   25.000đ',
                style: pw.TextStyle(font: regular, fontSize: 10)),
            pw.Text('Tạm tính: 64.000đ', style: pw.TextStyle(font: regular, fontSize: 10)),
            pw.Text('TỔNG CỘNG: 64.000đ (chữ đậm)', style: pw.TextStyle(font: bold, fontSize: 12)),
            pw.Text('TỔNG CỘNG: 64.000đ (Bán đậm)', style: pw.TextStyle(font: semi, fontSize: 12)),
            pw.Text('Cảm ơn quý khách! (chữ đậm)', style: pw.TextStyle(font: bold, fontSize: 10)),
            pw.Text('Cảm ơn quý khách! (Bán đậm)', style: pw.TextStyle(font: semi, fontSize: 10)),
            pw.SizedBox(height: 4),
            pw.Divider(thickness: 0.4),
          ]),
        ),
      );
      last = await printPdf(
        await doc.save(),
        feedLines: 1,
        threshold: thresholdForDarkness(d),
      );
      if (!last.ok) return last;
    }
    return last;
  }

  /// In so sánh độ dày font (Bold / Bán đậm / Vừa / Thường) ở các mức độ đậm: tìm kiểu chữ đậm
  /// ít loe nhất cho máy in nhiệt này.
  static Future<SunmiPrintResult> printWeightComparison({
    List<int> darknessLevels = const [2, 3],
    double fontScale = 1.0,
  }) async {
    final fonts = <String, pw.Font>{};
    Future<void> load(String name, Future<pw.Font> Function() f) async {
      try {
        fonts[name] = await f();
      } catch (_) {}
    }
    await load('Bold', PdfGoogleFonts.notoSansBold);
    await load('Bán đậm', PdfGoogleFonts.notoSansSemiBold);
    await load('Vừa', PdfGoogleFonts.notoSansMedium);
    await load('Thường', PdfGoogleFonts.notoSansRegular);
    final wMm = kHeadDots / kDpi * 25.4 / fontScale;
    SunmiPrintResult last = const SunmiPrintResult(true, 'Không có gì để in');
    for (final d in darknessLevels) {
      for (final e in fonts.entries) {
        final doc = pw.Document();
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(wMm * PdfPageFormat.mm, double.infinity, marginAll: 4),
            build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('${e.key} • đậm $d', style: pw.TextStyle(font: fonts['Thường'] ?? e.value, fontSize: 8)),
              pw.Text('TỔNG CỘNG: 64.000đ', style: pw.TextStyle(font: e.value, fontSize: 12)),
              pw.Text('Cảm ơn quý khách! Hẹn gặp lại', style: pw.TextStyle(font: e.value, fontSize: 10)),
            ]),
          ),
        );
        last = await printPdf(await doc.save(), feedLines: 0, threshold: thresholdForDarkness(d));
        if (!last.ok) return last;
      }
    }
    return last;
  }
}
