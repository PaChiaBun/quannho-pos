import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/qr_pdf_service.dart';

/// Xem trước, in hoặc tải PDF poster QR (A5 mặc định, có thể chọn A4).
class QrPosterPrintScreen extends StatefulWidget {
  final QrPosterKind kind;
  final String qrUrl;
  final String storeName;

  const QrPosterPrintScreen({
    super.key,
    required this.kind,
    required this.qrUrl,
    required this.storeName,
  });

  @override
  State<QrPosterPrintScreen> createState() => _QrPosterPrintScreenState();
}

class _QrPosterPrintScreenState extends State<QrPosterPrintScreen> {
  bool _a4 = false;

  Future<Uint8List> _build() => QrPdfService.generatePosterPdf(
    storeName: widget.storeName,
    qrUrl: widget.qrUrl,
    kind: widget.kind,
    a4: _a4,
  );

  @override
  Widget build(BuildContext context) {
    final label = widget.kind == QrPosterKind.table ? 'Tại bàn' : 'Mang đi';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'In poster QR - $label',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Text('Khổ giấy:'),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('A5'),
                  selected: !_a4,
                  onSelected: (_) => setState(() => _a4 = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('A4'),
                  selected: _a4,
                  onSelected: (_) => setState(() => _a4 = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: PdfPreview(
              key: ValueKey(_a4),
              build: (format) => _build(),
              allowPrinting: true,
              allowSharing: true,
              canChangeOrientation: false,
              canChangePageFormat: false,
              pdfFileName: 'qr-${widget.kind.name}.pdf',
            ),
          ),
        ],
      ),
    );
  }
}
