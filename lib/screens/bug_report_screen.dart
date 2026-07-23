// lib/screens/bug_report_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bug Report Screen — Chụp ảnh + mô tả lỗi + gửi lên Supabase
// Mở từ Settings → "Gửi phản hồi"
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../core/services/bug_reporter_service.dart';
import '../core/providers/session_provider.dart';

class BugReportScreen extends ConsumerStatefulWidget {
  const BugReportScreen({super.key});

  @override
  ConsumerState<BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends ConsumerState<BugReportScreen> {
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kNavyL  = Color(0xFF2D2B8A);
  static const _kOrange = Color(0xFFE85D20);
  static const _kBg     = Color(0xFFFAF7F2);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kInk    = Color(0xFF1A1207);

  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();
  File? _screenshot;
  bool _sending = false;
  String _selectedCategory = 'bug';

  static const _categories = [
    ('bug',       Icons.bug_report_rounded,    'Báo lỗi',        Color(0xFFC62828)),
    ('feature',   Icons.lightbulb_rounded,     'Đề xuất',        Color(0xFFFF8F00)),
    ('ui',        Icons.palette_rounded,        'Giao diện',      Color(0xFF1565C0)),
    ('other',     Icons.help_rounded,           'Khác',           Color(0xFF9E9085)),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 75,
      );
      if (picked != null) {
        setState(() => _screenshot = File(picked.path));
      }
    } catch (e) {
      debugPrint('[BugReport] Pick image error: $e');
    }
  }

  Future<void> _submit() async {
    final desc = _descCtrl.text.trim();
    if (desc.isEmpty) {
      _showSnack('Vui lòng mô tả vấn đề bạn gặp phải', isError: true);
      return;
    }

    setState(() => _sending = true);
    HapticFeedback.mediumImpact();

    try {
      // Upload screenshot nếu có
      String? screenshotUrl;
      if (_screenshot != null) {
        screenshotUrl = await BugReporterService.uploadScreenshot(_screenshot!);
      }

      // Lấy thông tin user
      final session = ref.read(sessionProvider);

      // Submit report
      final fullDesc = '[$_selectedCategory] $desc';
      final success = await BugReporterService.submitReport(
        description: fullDesc,
        screenshotUrl: screenshotUrl,
        userId: session?.userId ?? session?.phone ?? '',
        storeId: session?.storeId ?? '',
      );

      if (mounted) {
        if (success) {
          _showSnack('Cảm ơn bạn! Phản hồi đã được gửi thành công ✅');
          Navigator.pop(context);
        } else {
          _showSnack('Không gửi được. Kiểm tra kết nối mạng và thử lại', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Lỗi: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        title: Text('Gửi phản hồi',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w800, fontSize: 17)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kNavy, _kNavyL],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Loại phản hồi ──────────────────────────────────────
            Text('Loại phản hồi',
              style: GoogleFonts.outfit(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((cat) {
                final isSelected = _selectedCategory == cat.$1;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedCategory = cat.$1);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? cat.$4.withValues(alpha: 0.12)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? cat.$4
                            : const Color(0xFFE0D8CC),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(cat.$2, size: 16,
                          color: isSelected ? cat.$4 : _kMuted),
                        const SizedBox(width: 6),
                        Text(cat.$3,
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? cat.$4 : _kMuted,
                          )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // ── Mô tả ──────────────────────────────────────────────
            Text('Mô tả chi tiết *',
              style: GoogleFonts.outfit(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0D8CC)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _descCtrl,
                maxLines: 5,
                maxLength: 500,
                style: GoogleFonts.outfit(fontSize: 14, color: _kInk),
                decoration: InputDecoration(
                  hintText: 'Ví dụ: Khi bấm nút "In bill" trên màn hình Bán hàng, app bị đứng...',
                  hintStyle: GoogleFonts.outfit(fontSize: 13, color: _kMuted),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                  counterStyle: GoogleFonts.outfit(fontSize: 11, color: _kMuted),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Ảnh chụp màn hình ───────────────────────────────────
            Text('Ảnh chụp màn hình (tuỳ chọn)',
              style: GoogleFonts.outfit(
                fontSize: 13, fontWeight: FontWeight.w700, color: _kInk)),
            const SizedBox(height: 4),
            Text('Chụp lại màn hình lúc gặp lỗi giúp chúng tôi sửa nhanh hơn',
              style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
            const SizedBox(height: 10),

            if (_screenshot != null) ...[
              // Preview ảnh đã chụp
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE0D8CC)),
                      image: DecorationImage(
                        image: FileImage(_screenshot!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, right: 8,
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() => _screenshot = null);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC62828),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.close_rounded,
                          color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Buttons chụp ảnh
            Row(
              children: [
                Expanded(
                  child: _ImagePickerButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Chụp ảnh',
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ImagePickerButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Chọn từ thư viện',
                    onTap: () => _pickImage(ImageSource.gallery),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Card liên kết Log kỹ thuật ──────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1565C0).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1565C0).withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.manage_search_rounded, color: Color(0xFF1565C0), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ĐÍNH KÈM LOG NHẬT KÝ & DẤU VẾT KỸ THUẬT',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1565C0),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'Đã tự động liên kết',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF2E7D32),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hệ thống tự động gói kèm thông tin tài khoản, ID cửa hàng, phiên bản ứng dụng và Log lịch sử thao tác gần nhất giúp đội ngũ Kỹ thuật truy vết chính xác dấu vết sự cố.',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: _kNavy.withValues(alpha: 0.75),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ── Nút gửi ────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _submit,
                icon: _sending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_sending ? 'Đang gửi...' : 'Gửi phản hồi kèm Log kỹ thuật'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _kNavy.withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: GoogleFonts.outfit(
                    fontSize: 15, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Disclaimer ──────────────────────────────────────────
            Center(
              child: Text(
                'Dấu vết nhật ký kỹ thuật (Log Trace) được gửi kèm tự động\ngiúp bộ phận IT khắc phục sự cố nhanh chóng.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(fontSize: 11, color: _kMuted, height: 1.5),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Image Picker Button
// ─────────────────────────────────────────────────────────────────────────────
class _ImagePickerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ImagePickerButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0D8CC)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: const Color(0xFF1565C0)),
            const SizedBox(height: 4),
            Text(label,
              style: GoogleFonts.outfit(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: const Color(0xFF5A5260),
              )),
          ],
        ),
      ),
    );
  }
}
