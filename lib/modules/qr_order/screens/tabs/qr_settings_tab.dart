import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/qr_order_model.dart';
import '../../providers/qr_order_providers.dart';

import 'pos_device_session_card.dart';

class QrSettingsTab extends ConsumerWidget {
  final QrOrderSettingsModel settings;
  final TextEditingController baseUrlCtrl;
  final bool Function(String?) isValidPublicUrl;
  final String Function(String) normalizeUrl;
  final Future<void> Function(String) testOpenDomain;

  const QrSettingsTab({
    super.key,
    required this.settings,
    required this.baseUrlCtrl,
    required this.isValidPublicUrl,
    required this.normalizeUrl,
    required this.testOpenDomain,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUrl = baseUrlCtrl.text.trim();
    final isValidDomain = activeUrl.isNotEmpty && isValidPublicUrl(activeUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PosDeviceSessionCard(),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isValidDomain
                  ? Colors.green.shade50
                  : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isValidDomain
                    ? Colors.green.shade200
                    : Colors.amber.shade300,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isValidDomain
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      color: isValidDomain
                          ? Colors.green.shade800
                          : Colors.amber.shade900,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isValidDomain
                            ? 'TÊN MIỀN PUBLIC HỢP LỆ (HTTPS)'
                            : 'CHƯA CẤU HÌNH TÊN MIỀN PUBLIC (ĐÃ KHÓA XUẤT QR)',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isValidDomain
                              ? Colors.green.shade900
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Tên miền Public (Base URL) là địa chỉ trang web công khai được nhúng vào mã QR để điện thoại khách hàng sau khi quét mã có thể mở ứng dụng gọi món di động.',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: Colors.grey.shade800,
                  ),
                ),
                if (!isValidDomain) ...[
                  const SizedBox(height: 8),
                  Text(
                    '⚠️ Để đảm bảo an toàn và tính khả dụng, hệ thống KHÔNG in mã QR chứa "localhost" hoặc tên miền giả định chưa deploy. Vui lòng cấu hình tên miền HTTPS công khai bên dưới để kích hoạt xuất mã QR.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.shade100),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.qr_code_scanner_rounded,
                        color: Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chế độ Gọi Món Tại Bàn (TABLE)',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Khách quét mã tại bàn, đơn chuyển tới BanScreen để nhân viên duyệt',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.isTableEnabled,
                      activeThumbColor: const Color(0xFF8B5CF6),
                      onChanged: (val) {
                        ref
                            .read(qrOrderRepoProvider)
                            .saveSettings(
                              settings.copyWith(isTableEnabled: val),
                            );
                        ref.invalidate(qrOrderSettingsProvider);
                      },
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.storefront_rounded,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chế độ Gọi Món Tại Quầy (COUNTER)',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            'Khách tự chọn món tại quầy, sinh mã pickup code #Q01 để lấy món tại POS',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.isCounterEnabled,
                      activeThumbColor: Colors.orange,
                      onChanged: (val) {
                        ref
                            .read(qrOrderRepoProvider)
                            .saveSettings(
                              settings.copyWith(isCounterEnabled: val),
                            );
                        ref.invalidate(qrOrderSettingsProvider);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: ExpansionTile(
              initiallyExpanded: true,
              leading: const Icon(
                Icons.language_rounded,
                color: Color(0xFF8B5CF6),
              ),
              title: Text(
                'Cấu hình Tên miền Tùy chỉnh (Nâng cao / Custom Base URL)',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                baseUrlCtrl.text.trim().isNotEmpty
                    ? 'Hiện tại: ${baseUrlCtrl.text.trim()}'
                    : 'Mặc định hệ thống quản lý (Chưa thiết lập)',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nhập tên miền trang web gọi món đã deploy của quán (phải có giao thức https:// và không có dấu gạch chéo / ở cuối):',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: baseUrlCtrl,
                        decoration: InputDecoration(
                          hintText: 'https://quannho.lpm.vn/pos',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          helperText:
                              'Tên miền sẽ tự động chuẩn hóa loại bỏ ký tự / thừa ở cuối.',
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.open_in_browser_rounded),
                              label: const Text('Kiểm Tra / Mở Thử'),
                              onPressed: () => testOpenDomain(baseUrlCtrl.text),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.save_rounded),
                              label: const Text('Lưu Tên Miền'),
                              onPressed: () async {
                                final input = baseUrlCtrl.text.trim();
                                if (input.isNotEmpty &&
                                    !isValidPublicUrl(input)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Tên miền không hợp lệ! Vui lòng nhập URL HTTPS công khai (không dùng localhost hay IP nội bộ).',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                  return;
                                }

                                final normalized = input.isNotEmpty
                                    ? normalizeUrl(input)
                                    : '';
                                baseUrlCtrl.text = normalized;

                                await ref
                                    .read(qrOrderRepoProvider)
                                    .saveSettings(
                                      settings.copyWith(
                                        customBaseUrl: normalized,
                                      ),
                                    );
                                ref.invalidate(qrOrderSettingsProvider);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        normalized.isNotEmpty
                                            ? 'Đã lưu và chuẩn hóa tên miền: $normalized'
                                            : 'Đã xóa tên miền tùy chỉnh.',
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
