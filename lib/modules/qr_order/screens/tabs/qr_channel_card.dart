import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Thẻ một kênh QR (Tại bàn / Mang đi): công tắc, xem trước, sao chép, mở thử, in.
/// Chỉ vẽ QR khi kênh đang bật VÀ link hợp lệ.
class QrChannelCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  /// Kênh đã tồn tại trên server chưa.
  final bool channelExists;
  final bool isActive;
  final bool busy;

  /// Link dựng từ giá trị đã lưu; null nếu không hợp lệ.
  final String? url;

  /// Lý do không có QR (hiện ở placeholder).
  final String? unavailableReason;
  final ValueChanged<bool> onToggle;
  final VoidCallback onCopy;
  final VoidCallback onOpen;
  final VoidCallback onPrint;

  const QrChannelCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.channelExists,
    required this.isActive,
    required this.busy,
    required this.url,
    required this.unavailableReason,
    required this.onToggle,
    required this.onCopy,
    required this.onOpen,
    required this.onPrint,
  });

  bool get _canShowQr => channelExists && isActive && url != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF8B5CF6)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      description,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              else
                Switch(
                  value: channelExists && isActive,
                  onChanged: onToggle,
                  activeThumbColor: const Color(0xFF8B5CF6),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: _canShowQr
                ? Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: QrImageView(
                      data: url!,
                      size: 180,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  )
                : Container(
                    width: 204,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          unavailableReason ?? 'Chưa có mã QR.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (_canShowQr) ...[
            const SizedBox(height: 8),
            SelectableText(
              url!,
              textAlign: TextAlign.center,
              style: GoogleFonts.robotoMono(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _canShowQr ? onCopy : null,
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Sao chép link'),
              ),
              OutlinedButton.icon(
                onPressed: _canShowQr ? onOpen : null,
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: const Text('Mở thử'),
              ),
              FilledButton.icon(
                onPressed: _canShowQr ? onPrint : null,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text('In / Tải PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
