import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import '../services/qr_pdf_service.dart';

class CounterQrPrintScreen extends StatelessWidget {
  final String title;
  final String qrUrl;
  final String storeName;
  final String preset;
  final double widthMm;
  final double heightMm;
  final double bleedMm;
  final bool showCropMarks;
  final String headerTitle;
  final String subtitle;
  final String instructionText;
  final bool showNotice;
  final String confirmNote;
  final String wifiSsid;
  final String wifiPassword;
  final String hotline;
  final String openingHours;
  final String promoFooter;

  const CounterQrPrintScreen({
    super.key,
    required this.title,
    required this.qrUrl,
    required this.storeName,
    this.preset = 'classic_orange',
    this.widthMm = 148.0, // A5 default
    this.heightMm = 210.0,
    this.bleedMm = 3.0,
    this.showCropMarks = true,
    required this.headerTitle,
    required this.subtitle,
    required this.instructionText,
    required this.showNotice,
    required this.confirmNote,
    this.wifiSsid = '',
    this.wifiPassword = '',
    this.hotline = '',
    this.openingHours = '',
    this.promoFooter = '',
  });

  Future<Uint8List> _generatePdf() async {
    return QrPdfService.generateCounterPosterPdf(
      storeName: storeName,
      qrUrl: qrUrl,
      preset: preset,
      widthMm: widthMm,
      heightMm: heightMm,
      bleedMm: bleedMm,
      showCropMarks: showCropMarks,
      headerTitle: headerTitle,
      subtitle: subtitle,
      instructionText: instructionText,
      showNotice: showNotice,
      confirmNote: confirmNote,
      wifiSsid: wifiSsid,
      wifiPassword: wifiPassword,
      hotline: hotline,
      openingHours: openingHours,
      promoFooter: promoFooter,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'In Poster QR Quầy ($title)',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade800,
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
