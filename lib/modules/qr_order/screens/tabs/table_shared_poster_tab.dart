import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/qr_order_model.dart';
import '../table_qr_print_screen.dart';

/// Tab hiển thị và in Poster Mã QR Dùng Chung Tại Bàn (TABLE_SHARED)
class TableSharedPosterTab extends StatelessWidget {
  final QrChannelModel? tableSharedChannel;
  final String? tableSharedUrl;
  final String? activeBaseUrl;
  final String storeName;
  final Future<void> Function(String) testOpenDomain;

  const TableSharedPosterTab({
    super.key,
    required this.tableSharedChannel,
    required this.tableSharedUrl,
    required this.activeBaseUrl,
    required this.storeName,
    required this.testOpenDomain,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = tableSharedUrl != null && tableSharedUrl!.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Hướng Dẫn
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade200),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF8B5CF6),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'QR DÙNG CHUNG TẤT CẢ CÁC BÀN',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.purple.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chỉ cần in một mẫu QR duy nhất dán tại bàn/menu. Khách quét mã sẽ tự nhập số bàn; nhân viên quét lại QR động trên điện thoại khách để xác nhận.',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.purple.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Poster Preview Card
          Center(
            child: Container(
              width: 320,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.purple.shade100),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    storeName.toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      color: Colors.black87,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'QUÉT QR GỌI MÓN TẠI BÀN',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // QR Box (Mã QR thật có thể quét được)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 2),
                    ),
                    child: Column(
                      children: [
                        QrImageView(
                          data:
                              tableSharedUrl ??
                              'https://quannho.lpm.vn/pos/goi-mon/?code=${tableSharedChannel?.channelCode ?? ""}',
                          version: QrVersions.auto,
                          size: 160,
                          backgroundColor: Colors.white,
                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Color(0xFF6D28D9),
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          tableSharedChannel?.channelCode ?? 'TBL_DEFAULT',
                          style: GoogleFonts.sourceCodePro(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: Colors.purple.shade900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '1. Quét QR mở Menu\n2. Nhập số bàn bạn đang ngồi\n3. Đưa mã xác nhận cho nhân viên',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          if (hasUrl) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded),
                    label: const Text('Mở Thử Web'),
                    onPressed: () => testOpenDomain(tableSharedUrl!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.print_rounded),
                    label: const Text('In Poster / Decal'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TableQrPrintScreen(
                            title: 'QR Dùng Chung Tại Bàn',
                            qrUrl: tableSharedUrl!,
                            storeName: storeName,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            Center(
              child: Text(
                '⚠️ Vui lòng cấu hình Tên Miền Public (HTTPS) ở tab "Thiết Lập" để kích hoạt in mã QR.',
                style: GoogleFonts.outfit(
                  color: Colors.red.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
