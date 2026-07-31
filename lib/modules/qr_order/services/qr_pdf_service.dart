import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class TableQrItemData {
  final String title;
  final String qrUrl;
  final String zoneName;
  final String tableName;

  const TableQrItemData({
    required this.title,
    required this.qrUrl,
    this.zoneName = '',
    this.tableName = '',
  });
}

class QrPdfService {
  /// Generates vector decal PDF with prepress bleed & crop marks.
  /// Artwork extends to the full page bounds (width + 2*bleed, height + 2*bleed),
  /// while crop marks indicate the exact trim line (finished product dimensions width x height).
  static Future<Uint8List> generateDecalPdf({
    required String storeName,
    required List<TableQrItemData> items,
    double widthMm = 70.0,
    double heightMm = 100.0,
    double bleedMm = 2.0,
    bool showCropMarks = true,
    String headerTitle = 'QUÉT QR GỌI MÓN',
    String instructionText =
        'Quét mã QR bằng ứng dụng Zalo, Camera hoặc trình duyệt di động để xem Menu',
    String confirmNote =
        'Sau khi đặt xong, vui lòng gọi nhân viên đến đọc lại và xác nhận món. Món chỉ được gửi xuống bếp sau khi nhân viên xác nhận.',
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final pdf = pw.Document(theme: theme);

    final bleedPt = bleedMm * PdfPageFormat.mm;
    final widthPt = widthMm * PdfPageFormat.mm;
    final heightPt = heightMm * PdfPageFormat.mm;
    final totalWidthPt = widthPt + (bleedPt * 2);
    final totalHeightPt = heightPt + (bleedPt * 2);

    final pageFormat = PdfPageFormat(totalWidthPt, totalHeightPt, marginAll: 0);

    final qrSize = (widthMm * 0.45 * PdfPageFormat.mm).clamp(65.0, 140.0);
    final titleFontSize = (widthMm * 0.22).clamp(10.0, 18.0);

    for (final item in items) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          theme: theme,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // 1. Full Bleed Background Container (Extends across total page size)
                pw.Positioned(
                  left: 0,
                  top: 0,
                  child: pw.SizedBox(
                    width: totalWidthPt,
                    height: totalHeightPt,
                    child: pw.Container(color: PdfColors.white),
                  ),
                ),

                // 2. Finished Product Box (Positioned at bleedPt offset)
                pw.Positioned(
                  left: bleedPt,
                  top: bleedPt,
                  child: pw.SizedBox(
                    width: widthPt,
                    height: heightPt,
                    child: pw.Container(
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        border: pw.Border.all(
                          color: PdfColors.purple800,
                          width: 2,
                        ),
                        borderRadius: pw.BorderRadius.circular(8),
                      ),
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Column(
                            children: [
                              pw.Text(
                                storeName.toUpperCase(),
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.purple900,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 2),
                              pw.Container(
                                padding: const pw.EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.orange,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Text(
                                  headerTitle,
                                  style: pw.TextStyle(
                                    fontSize: 10,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.purple50,
                              borderRadius: pw.BorderRadius.circular(6),
                              border: pw.Border.all(
                                color: PdfColors.purple300,
                                width: 1,
                              ),
                            ),
                            child: pw.Text(
                              item.title,
                              style: pw.TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.purple900,
                              ),
                            ),
                          ),
                          pw.Container(
                            padding: const pw.EdgeInsets.all(4),
                            decoration: pw.BoxDecoration(
                              color: PdfColors.white,
                              border: pw.Border.all(
                                color: PdfColors.grey300,
                                width: 1,
                              ),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                            child: pw.BarcodeWidget(
                              barcode: pw.Barcode.qrCode(),
                              data: item.qrUrl,
                              width: qrSize,
                              height: qrSize,
                            ),
                          ),
                          pw.Text(
                            instructionText,
                            style: pw.TextStyle(
                              fontSize: 7.0,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                          if (confirmNote.isNotEmpty)
                            pw.Container(
                              padding: const pw.EdgeInsets.all(4),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.amber50,
                                borderRadius: pw.BorderRadius.circular(6),
                                border: pw.Border.all(
                                  color: PdfColors.amber400,
                                  width: 0.8,
                                ),
                              ),
                              child: pw.Text(
                                confirmNote,
                                style: pw.TextStyle(
                                  fontSize: 6.0,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.brown900,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // 3. Prepress Crop Marks Layer (Positioned at exact trim corners)
                if (showCropMarks && bleedPt > 0)
                  ..._buildPrepressCropMarks(
                    bleedPt: bleedPt,
                    widthPt: widthPt,
                    heightPt: heightPt,
                  ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Generates vector Counter Poster PDF with full prepress bleed & crop marks.
  /// Theme background extends to the total page bounds (width + 2*bleed, height + 2*bleed).
  static Future<Uint8List> generateCounterPosterPdf({
    required String storeName,
    required String qrUrl,
    String preset = 'classic_orange',
    double widthMm = 148.0,
    double heightMm = 210.0,
    double bleedMm = 3.0,
    bool showCropMarks = true,
    String headerTitle = 'QUÉT QR GỌI MÓN TẠI QUẦY',
    String subtitle = 'Tự chọn món & Nhận mã Pickup #Q01',
    String instructionText =
        '1. Quét mã QR • 2. Chọn món & Gửi đơn • 3. Đợi nhận mã Pickup #Q01',
    bool showNotice = true,
    String confirmNote =
        'Sau khi gửi đơn, vui lòng giữ điện thoại để nhận mã số lấy món tại quầy.',
    String wifiSsid = '',
    String wifiPassword = '',
    String hotline = '',
    String openingHours = '',
    String promoFooter = '',
  }) async {
    final fontRegular = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final theme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final pdf = pw.Document(theme: theme);

    final bleedPt = bleedMm * PdfPageFormat.mm;
    final widthPt = widthMm * PdfPageFormat.mm;
    final heightPt = heightMm * PdfPageFormat.mm;
    final totalWidthPt = widthPt + (bleedPt * 2);
    final totalHeightPt = heightPt + (bleedPt * 2);

    final pageFormat = PdfPageFormat(totalWidthPt, totalHeightPt, marginAll: 0);

    PdfColor bgColor;
    PdfColor textColor;
    PdfColor accentColor;

    switch (preset) {
      case 'modern_purple':
        bgColor = PdfColors.purple900;
        textColor = PdfColors.white;
        accentColor = PdfColors.amber100;
        break;
      case 'dark_gold':
        bgColor = PdfColors.grey900;
        textColor = PdfColors.amber200;
        accentColor = PdfColors.amber;
        break;
      case 'minimal_white':
        bgColor = PdfColors.grey100;
        textColor = PdfColors.grey900;
        accentColor = PdfColors.purple900;
        break;
      case 'classic_orange':
      default:
        bgColor = PdfColors.orange;
        textColor = PdfColors.white;
        accentColor = PdfColors.yellow100;
        break;
    }

    final qrSize = (widthMm * 0.45 * PdfPageFormat.mm).clamp(90.0, 200.0);

    final wifiText = wifiSsid.isNotEmpty
        ? 'WiFi: $wifiSsid${wifiPassword.isNotEmpty ? " • Mật khẩu: $wifiPassword" : ""}'
        : '';
    final infoText =
        '${hotline.isNotEmpty ? "📞 Hotline: $hotline" : ""}${openingHours.isNotEmpty ? " • 🕒 Giờ mở cửa: $openingHours" : ""}';

    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        theme: theme,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              // 1. Full Bleed Artwork Background (Extends to page edges for clean cutting)
              pw.Positioned(
                left: 0,
                top: 0,
                child: pw.SizedBox(
                  width: totalWidthPt,
                  height: totalHeightPt,
                  child: pw.Container(color: bgColor),
                ),
              ),

              // 2. Finished Product Bounds (Positioned at bleedPt offset)
              pw.Positioned(
                left: bleedPt,
                top: bleedPt,
                child: pw.SizedBox(
                  width: widthPt,
                  height: heightPt,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(16),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text(
                              storeName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            pw.Text(
                              headerTitle,
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: textColor,
                              ),
                              textAlign: pw.TextAlign.center,
                            ),
                            if (subtitle.isNotEmpty) ...[
                              pw.SizedBox(height: 4),
                              pw.Text(
                                subtitle,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accentColor,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                        // Quiet Zone QR Area
                        pw.Container(
                          padding: const pw.EdgeInsets.all(12),
                          decoration: pw.BoxDecoration(
                            color: PdfColors.white,
                            borderRadius: pw.BorderRadius.circular(12),
                          ),
                          child: pw.Column(
                            children: [
                              pw.BarcodeWidget(
                                barcode: pw.Barcode.qrCode(),
                                data: qrUrl,
                                width: qrSize,
                                height: qrSize,
                              ),
                              pw.SizedBox(height: 6),
                              pw.Text(
                                instructionText,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.grey900,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        pw.Column(
                          children: [
                            if (showNotice && confirmNote.isNotEmpty) ...[
                              pw.Container(
                                padding: const pw.EdgeInsets.all(6),
                                margin: const pw.EdgeInsets.only(bottom: 6),
                                decoration: pw.BoxDecoration(
                                  color: PdfColors.white,
                                  borderRadius: pw.BorderRadius.circular(6),
                                ),
                                child: pw.Text(
                                  confirmNote,
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey900,
                                  ),
                                  textAlign: pw.TextAlign.center,
                                ),
                              ),
                            ],
                            if (wifiText.isNotEmpty) ...[
                              pw.Text(
                                wifiText,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: textColor,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 2),
                            ],
                            if (infoText.isNotEmpty) ...[
                              pw.Text(
                                infoText,
                                style: pw.TextStyle(
                                  fontSize: 9,
                                  color: textColor,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                              pw.SizedBox(height: 2),
                            ],
                            if (promoFooter.isNotEmpty) ...[
                              pw.Text(
                                promoFooter,
                                style: pw.TextStyle(
                                  fontSize: 10,
                                  fontWeight: pw.FontWeight.bold,
                                  color: accentColor,
                                ),
                                textAlign: pw.TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Prepress Crop Marks Layer (Positioned at exact trim corners)
              if (showCropMarks && bleedPt > 0)
                ..._buildPrepressCropMarks(
                  bleedPt: bleedPt,
                  widthPt: widthPt,
                  heightPt: heightPt,
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Builds true prepress crop mark ticks pointing directly to the trim line intersection.
  static List<pw.Widget> _buildPrepressCropMarks({
    required double bleedPt,
    required double widthPt,
    required double heightPt,
  }) {
    const strokeWidth = 0.5;

    return [
      // Top-Left Trim Corner
      pw.Positioned(
        left: 0,
        top: 0,
        child: pw.SizedBox(
          width: bleedPt,
          height: bleedPt,
          child: pw.CustomPaint(
            size: PdfPoint(bleedPt, bleedPt),
            painter: (canvas, size) {
              canvas.setStrokeColor(PdfColors.black);
              canvas.setLineWidth(strokeWidth);
              canvas.drawLine(
                bleedPt,
                0,
                bleedPt,
                bleedPt,
              ); // vertical trim mark
              canvas.drawLine(
                0,
                bleedPt,
                bleedPt,
                bleedPt,
              ); // horizontal trim mark
            },
          ),
        ),
      ),
      // Top-Right Trim Corner
      pw.Positioned(
        right: 0,
        top: 0,
        child: pw.SizedBox(
          width: bleedPt,
          height: bleedPt,
          child: pw.CustomPaint(
            size: PdfPoint(bleedPt, bleedPt),
            painter: (canvas, size) {
              canvas.setStrokeColor(PdfColors.black);
              canvas.setLineWidth(strokeWidth);
              canvas.drawLine(0, 0, 0, bleedPt); // vertical trim mark
              canvas.drawLine(
                0,
                bleedPt,
                bleedPt,
                bleedPt,
              ); // horizontal trim mark
            },
          ),
        ),
      ),
      // Bottom-Left Trim Corner
      pw.Positioned(
        left: 0,
        bottom: 0,
        child: pw.SizedBox(
          width: bleedPt,
          height: bleedPt,
          child: pw.CustomPaint(
            size: PdfPoint(bleedPt, bleedPt),
            painter: (canvas, size) {
              canvas.setStrokeColor(PdfColors.black);
              canvas.setLineWidth(strokeWidth);
              canvas.drawLine(
                bleedPt,
                0,
                bleedPt,
                bleedPt,
              ); // vertical trim mark
              canvas.drawLine(0, 0, bleedPt, 0); // horizontal trim mark
            },
          ),
        ),
      ),
      // Bottom-Right Trim Corner
      pw.Positioned(
        right: 0,
        bottom: 0,
        child: pw.SizedBox(
          width: bleedPt,
          height: bleedPt,
          child: pw.CustomPaint(
            size: PdfPoint(bleedPt, bleedPt),
            painter: (canvas, size) {
              canvas.setStrokeColor(PdfColors.black);
              canvas.setLineWidth(strokeWidth);
              canvas.drawLine(0, 0, 0, bleedPt); // vertical trim mark
              canvas.drawLine(0, 0, bleedPt, 0); // horizontal trim mark
            },
          ),
        ),
      ),
    ];
  }
}
