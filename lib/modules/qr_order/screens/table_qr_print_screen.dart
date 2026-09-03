import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../services/qr_pdf_service.dart';

class TableQrPrintScreen extends StatelessWidget {
  final String title;
  final String qrUrl;
  final String storeName;
  final List<TableQrItemData>? batchItems;
  final bool renderAsA4Sheet;

  final double widthMm;
  final double heightMm;
  final double bleedMm;
  final bool showCropMarks;
  final String headerTitle;
  final String instructionText;
  final String confirmNote;

  const TableQrPrintScreen({
    super.key,
    required this.title,
    required this.qrUrl,
    required this.storeName,
    this.batchItems,
    this.renderAsA4Sheet = false,
    this.widthMm = 70.0,
    this.heightMm = 100.0,
    this.bleedMm = 2.0,
    this.showCropMarks = true,
    this.headerTitle = 'QUÉT QR GỌI MÓN',
    this.instructionText =
        'Quét mã QR bằng ứng dụng Zalo, Camera hoặc trình duyệt di động để xem Menu',
    this.confirmNote =
        'Sau khi đặt xong, vui lòng gọi nhân viên đến đọc lại và xác nhận món. Món chỉ được gửi xuống bếp sau khi nhân viên xác nhận.',
  });

  Future<Uint8List> _generatePdf() async {
    final itemsToPrint = batchItems != null && batchItems!.isNotEmpty
        ? batchItems!
        : [TableQrItemData(title: title, qrUrl: qrUrl, tableName: title)];

    if (renderAsA4Sheet) {
      return QrPdfService.generateA4DecalSheetPdf(
        storeName: storeName,
        items: itemsToPrint,
        widthMm: widthMm,
        heightMm: heightMm,
        headerTitle: headerTitle,
        instructionText: instructionText,
        confirmNote: confirmNote,
      );
    }

    return QrPdfService.generateDecalPdf(
      storeName: storeName,
      items: itemsToPrint,
      widthMm: widthMm,
      heightMm: heightMm,
      bleedMm: bleedMm,
      showCropMarks: showCropMarks,
      headerTitle: headerTitle,
      instructionText: instructionText,
      confirmNote: confirmNote,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = batchItems?.length ?? 1;
    final pageTitle = renderAsA4Sheet
        ? 'Sheet A4 $count Tem Bàn'
        : (count > 1 ? 'In Hàng Loạt $count Tem Bàn' : 'In Tem Bàn — $title');

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pageTitle,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: PdfPreview(
        build: (format) => _generatePdf(),
        allowPrinting: true,
        allowSharing: true,
        canChangeOrientation: false,
        canChangePageFormat: false,
      ),
    );
  }
}
