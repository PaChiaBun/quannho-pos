import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/qr_order_model.dart';
import '../counter_qr_print_screen.dart';

class CounterQrDesignTab extends StatelessWidget {
  final QrChannelModel? counterChannel;
  final String? counterUrl;
  final String? activeBaseUrl;
  final String storeName;
  final Future<void> Function(String) testOpenDomain;

  final String ctrPreset;
  final ValueChanged<String> onPresetChanged;
  final String ctrSizePreset;
  final ValueChanged<String> onSizePresetChanged;
  final TextEditingController ctrWidthCtrl;
  final TextEditingController ctrHeightCtrl;
  final TextEditingController ctrTitleCtrl;
  final TextEditingController ctrSubtitleCtrl;
  final TextEditingController ctrInstructionsCtrl;
  final bool showCtrNotice;
  final ValueChanged<bool> onNoticeToggleChanged;
  final TextEditingController ctrNoticeCtrl;
  final TextEditingController wifiSsidCtrl;
  final TextEditingController wifiPasswordCtrl;
  final TextEditingController hotlineCtrl;
  final TextEditingController openingHoursCtrl;
  final TextEditingController promoFooterCtrl;

  final VoidCallback onSaveSettings;
  final VoidCallback onResetSettings;

  const CounterQrDesignTab({
    super.key,
    required this.counterChannel,
    required this.counterUrl,
    required this.activeBaseUrl,
    required this.storeName,
    required this.testOpenDomain,
    required this.ctrPreset,
    required this.onPresetChanged,
    required this.ctrSizePreset,
    required this.onSizePresetChanged,
    required this.ctrWidthCtrl,
    required this.ctrHeightCtrl,
    required this.ctrTitleCtrl,
    required this.ctrSubtitleCtrl,
    required this.ctrInstructionsCtrl,
    required this.showCtrNotice,
    required this.onNoticeToggleChanged,
    required this.ctrNoticeCtrl,
    required this.wifiSsidCtrl,
    required this.wifiPasswordCtrl,
    required this.hotlineCtrl,
    required this.openingHoursCtrl,
    required this.promoFooterCtrl,
    required this.onSaveSettings,
    required this.onResetSettings,
  });

  @override
  Widget build(BuildContext context) {
    final channelCode = counterChannel?.channelCode ?? 'CTR_CHUA_MIGRATE';

    final List<Color> bgGradientColors;
    final Color textColor;
    final Color accentColor;

    switch (ctrPreset) {
      case 'modern_purple':
        bgGradientColors = [Colors.purple.shade800, Colors.deepPurple.shade900];
        textColor = Colors.white;
        accentColor = Colors.amber;
        break;
      case 'dark_gold':
        bgGradientColors = [Colors.grey.shade900, Colors.black];
        textColor = Colors.amber.shade300;
        accentColor = Colors.amber;
        break;
      case 'minimal_white':
        bgGradientColors = [Colors.white, Colors.grey.shade100];
        textColor = Colors.grey.shade900;
        accentColor = const Color(0xFF8B5CF6);
        break;
      case 'classic_orange':
      default:
        bgGradientColors = [Colors.orange.shade600, Colors.deepOrange.shade700];
        textColor = Colors.white;
        accentColor = Colors.yellow;
        break;
    }

    final parsedWidth = double.tryParse(ctrWidthCtrl.text.trim()) ?? 148.0;
    final parsedHeight = double.tryParse(ctrHeightCtrl.text.trim()) ?? 210.0;
    final sizeLabel = ctrSizePreset == 'a5'
        ? 'A5 (148 x 210 mm)'
        : (ctrSizePreset == 'a4'
              ? 'A4 (210 x 297 mm)'
              : 'Custom (${parsedWidth.toInt()} x ${parsedHeight.toInt()} mm)');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.orange.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.point_of_sale_rounded,
                            size: 32,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'THIẾT KẾ & QUẢN LÝ QR QUẦY',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: Colors.orange.shade900,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: counterUrl != null
                                          ? Colors.green
                                          : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    counterUrl != null
                                        ? 'Kênh QR Đang Hoạt Động'
                                        : (activeBaseUrl == null
                                              ? '🔒 Khóa QR (Chưa có Domain HTTPS)'
                                              : 'Chưa Khởi Tạo DB'),
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: counterUrl != null
                                          ? Colors.green.shade800
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Mã Kênh Channel Code:',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.shade200),
                          ),
                          child: SelectableText(
                            channelCode,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (counterUrl != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: SelectableText(
                          counterUrl!,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.blue.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Sao Chép Link'),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: counterUrl!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã sao chép link QR Quầy!'),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.open_in_browser_rounded),
                              label: const Text('Quét / Mở Thử'),
                              onPressed: () {
                                testOpenDomain(counterUrl!);
                              },
                            ),
                          ),
                        ],
                      ),
                    ] else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          activeBaseUrl == null
                              ? '🔒 Đã khóa tính năng in QR Quầy do chưa cấu hình Tên miền Public hợp lệ (HTTPS). Vào Tab Thiết Lập để cài đặt.'
                              : '⚠️ Chưa thể tạo mã QR Quầy do chưa chạy migration SQL trên Supabase.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.red,
                            fontSize: 13,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cấu Hình Tùy Chỉnh Poster QR Quầy:',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Reset Mẫu'),
                          onPressed: onResetSettings,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Mẫu Preset Giao Diện:',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Cam Quán Nhỏ'),
                          selected: ctrPreset == 'classic_orange',
                          onSelected: (val) {
                            if (val) onPresetChanged('classic_orange');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Tím Hiện Đại'),
                          selected: ctrPreset == 'modern_purple',
                          onSelected: (val) {
                            if (val) onPresetChanged('modern_purple');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Đen Vàng Sang Trọng'),
                          selected: ctrPreset == 'dark_gold',
                          onSelected: (val) {
                            if (val) onPresetChanged('dark_gold');
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Trắng Tối Giản'),
                          selected: ctrPreset == 'minimal_white',
                          onSelected: (val) {
                            if (val) onPresetChanged('minimal_white');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Kích Thước Khổ Giấy Poster:',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('A5 (148 x 210 mm)'),
                          selected: ctrSizePreset == 'a5',
                          onSelected: (val) {
                            if (val) {
                              onSizePresetChanged('a5');
                              ctrWidthCtrl.text = '148';
                              ctrHeightCtrl.text = '210';
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('A4 (210 x 297 mm)'),
                          selected: ctrSizePreset == 'a4',
                          onSelected: (val) {
                            if (val) {
                              onSizePresetChanged('a4');
                              ctrWidthCtrl.text = '210';
                              ctrHeightCtrl.text = '297';
                            }
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Custom mm'),
                          selected: ctrSizePreset == 'custom',
                          onSelected: (val) {
                            if (val) onSizePresetChanged('custom');
                          },
                        ),
                      ],
                    ),
                    if (ctrSizePreset == 'custom') ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: ctrWidthCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Rộng (Width mm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: ctrHeightCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Cao (Height mm)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: ctrTitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tiêu đề Poster',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrSubtitleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Subtitle / Lời gọi hành động (CTA)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ctrInstructionsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Hướng dẫn các bước',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    SwitchListTile(
                      title: Text(
                        'Hiển thị Khối Lưu Ý Bắt Buộc',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      value: showCtrNotice,
                      activeThumbColor: Colors.orange,
                      onChanged: onNoticeToggleChanged,
                    ),
                    if (showCtrNotice)
                      TextField(
                        controller: ctrNoticeCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Nội dung ghi chú xác nhận',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 14),

                    Text(
                      'Các Khối Thông Tin Bổ Sung (Tùy chọn):',
                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: wifiSsidCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tên WiFi',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: wifiPasswordCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mật khẩu WiFi',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: hotlineCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Hotline Quán',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: openingHoursCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Giờ Mở Cửa',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: promoFooterCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Khuyến mãi / Lời nhắn Footer',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade800,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text('Lưu Thiết Kế Poster Quầy'),
                        onPressed: onSaveSettings,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'MẪU XEM TRƯỚC POSTER QR QUẦY THỰC TẾ ($sizeLabel):',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bgGradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: ctrPreset == 'minimal_white'
                      ? Border.all(color: Colors.grey.shade300)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      storeName.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: textColor.withValues(alpha: 0.8),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ctrTitleCtrl.text,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        color: textColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    if (ctrSubtitleCtrl.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        ctrSubtitleCtrl.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data:
                                counterUrl ??
                                'https://quannho.lpm.vn/pos/goi-mon/?code=${counterChannel?.channelCode ?? ""}',
                            version: QrVersions.auto,
                            size: 130,
                            backgroundColor: Colors.white,
                            errorCorrectionLevel: QrErrorCorrectLevel.M,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Colors.black87,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            ctrInstructionsCtrl.text,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (showCtrNotice && ctrNoticeCtrl.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: textColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          ctrNoticeCtrl.text,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: textColor,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),

                    if (wifiSsidCtrl.text.isNotEmpty ||
                        wifiPasswordCtrl.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wifi_rounded,
                              size: 14,
                              color: textColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'WiFi: ${wifiSsidCtrl.text}${wifiPasswordCtrl.text.isNotEmpty ? " • Mật khẩu: ${wifiPasswordCtrl.text}" : ""}',
                              style: GoogleFonts.outfit(
                                color: textColor,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (hotlineCtrl.text.isNotEmpty ||
                        openingHoursCtrl.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${hotlineCtrl.text.isNotEmpty ? "📞 Hotline: ${hotlineCtrl.text}" : ""}${openingHoursCtrl.text.isNotEmpty ? " • 🕒 Giờ mở cửa: ${openingHoursCtrl.text}" : ""}',
                          style: GoogleFonts.outfit(
                            color: textColor,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    if (promoFooterCtrl.text.isNotEmpty)
                      Text(
                        promoFooterCtrl.text,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: accentColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: counterUrl != null
                        ? Colors.orange.shade800
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.print_rounded),
                  label: Text(
                    counterUrl != null
                        ? 'XUẤT FILE PDF POSTER QUẦY ($sizeLabel)'
                        : 'CHƯA THỂ IN POSTER (CẦN CẤU HÌNH DOMAIN HTTPS & DB)',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  onPressed: counterUrl != null
                      ? () {
                          final widthMm =
                              (double.tryParse(ctrWidthCtrl.text.trim()) ??
                                      148.0)
                                  .clamp(80.0, 500.0);
                          final heightMm =
                              (double.tryParse(ctrHeightCtrl.text.trim()) ??
                                      210.0)
                                  .clamp(80.0, 700.0);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CounterQrPrintScreen(
                                title: 'Quầy Thu Ngân ($sizeLabel)',
                                qrUrl: counterUrl!,
                                storeName: storeName,
                                preset: ctrPreset,
                                widthMm: widthMm,
                                heightMm: heightMm,
                                bleedMm: 3.0,
                                showCropMarks: true,
                                headerTitle: ctrTitleCtrl.text.trim(),
                                subtitle: ctrSubtitleCtrl.text.trim(),
                                instructionText: ctrInstructionsCtrl.text
                                    .trim(),
                                showNotice: showCtrNotice,
                                confirmNote: ctrNoticeCtrl.text.trim(),
                                wifiSsid: wifiSsidCtrl.text.trim(),
                                wifiPassword: wifiPasswordCtrl.text.trim(),
                                hotline: hotlineCtrl.text.trim(),
                                openingHours: openingHoursCtrl.text.trim(),
                                promoFooter: promoFooterCtrl.text.trim(),
                              ),
                            ),
                          );
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Chưa có mã QR Quầy để xuất Poster. Vui lòng kiểm tra Tên miền HTTPS và DB.',
                              ),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
