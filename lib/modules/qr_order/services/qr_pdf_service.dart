import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Loại poster QR.
enum QrPosterKind { table, counter }

class QrPdfService {
  /// Tạo PDF poster QR (một mẫu cố định). Mặc định khổ A5, có thể chọn A4.
  static Future<Uint8List> generatePosterPdf({
    required String storeName,
    required String qrUrl,
    QrPosterKind kind = QrPosterKind.table,
    bool a4 = false,
  }) async {
    if (qrUrl.trim().isEmpty) {
      throw ArgumentError('qrUrl rỗng: không được tạo poster QR');
    }

    final theme = await _loadTheme();
    final pdf = pw.Document(theme: theme);
    final format = a4 ? PdfPageFormat.a4 : PdfPageFormat.a5;
    final scale = format.width / PdfPageFormat.a5.width;
    final isCounter = kind == QrPosterKind.counter;

    final title = isCounter
        ? 'QUÉT MÃ QR GỌI MÓN TẠI QUẦY'
        : 'QUÉT MÃ QR ĐỂ GỌI MÓN';
    final steps = isCounter
        ? const [
            '1. Quét mã QR bằng Camera hoặc Zalo',
            '2. Chọn món và bấm Gửi đơn',
            '3. Thanh toán tại quầy, chờ gọi mã lấy món',
          ]
        : const [
            '1. Quét mã QR bằng Camera hoặc Zalo',
            '2. Chọn số bàn của bạn và chọn món',
            '3. Bấm Gửi đơn, nhân viên sẽ xác nhận',
          ];
    const pickupNote =
        'Sau khi gửi đơn, vui lòng giữ điện thoại để đọc mã lấy món (ví dụ Q01) tại quầy.';

    // QR cùng vùng trắng (quiet zone) rộng 15% cạnh QR, lớn hơn 4 module với
    // mọi phiên bản QR có thể xảy ra cho URL ngắn (từ 29 module trở lên).
    final qrSize = 190.0 * scale;
    final quiet = qrSize * 0.15;

    pdf.addPage(
      pw.Page(
        pageFormat: format.copyWith(
          marginLeft: 0,
          marginTop: 0,
          marginRight: 0,
          marginBottom: 0,
        ),
        theme: theme,
        build: (context) {
          return pw.Container(
            color: PdfColors.white,
            padding: pw.EdgeInsets.all(18 * scale),
            child: pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey800, width: 2),
                borderRadius: pw.BorderRadius.circular(12 * scale),
              ),
              padding: pw.EdgeInsets.all(16 * scale),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    title,
                    style: pw.TextStyle(
                      fontSize: 22 * scale,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Container(
                    padding: pw.EdgeInsets.all(quiet),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(
                        errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                      ),
                      data: qrUrl,
                      width: qrSize,
                      height: qrSize,
                      color: PdfColors.black,
                      backgroundColor: PdfColors.white,
                    ),
                  ),
                  pw.Column(
                    children: [
                      for (final s in steps)
                        pw.Padding(
                          padding: pw.EdgeInsets.symmetric(vertical: 2 * scale),
                          child: pw.Text(
                            s,
                            style: pw.TextStyle(fontSize: 13 * scale),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      if (isCounter) ...[
                        pw.SizedBox(height: 8 * scale),
                        pw.Container(
                          padding: pw.EdgeInsets.all(8 * scale),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey700),
                            borderRadius: pw.BorderRadius.circular(6 * scale),
                          ),
                          child: pw.Text(
                            pickupNote,
                            style: pw.TextStyle(
                              fontSize: 11 * scale,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                  pw.Text(
                    storeName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: pw.FontWeight.bold,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    return pdf.save();
  }

  /// Font Noto Sans (đủ dấu tiếng Việt). Tải mạng thất bại -> font mặc định.
  static Future<pw.ThemeData> _loadTheme() async {
    try {
      final regular = await PdfGoogleFonts.notoSansRegular().timeout(
        const Duration(seconds: 10),
      );
      final bold = await PdfGoogleFonts.notoSansBold().timeout(
        const Duration(seconds: 10),
      );
      return pw.ThemeData.withFont(base: regular, bold: bold);
    } catch (e) {
      debugPrint('[QrPdfService] Không tải được font Noto, dùng font mặc định: $e');
      return pw.ThemeData.base();
    }
  }
}
