// lib/core/services/update_checker_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Update Checker — Kiểm tra phiên bản mới khi app khởi động
// Query bảng app_versions trên Supabase → hiện dialog nếu có bản mới
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateCheckerService {
  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);

  /// Gọi 1 lần sau khi MainShell hiển thị
  static Future<void> checkForUpdate(BuildContext context) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersion = packageInfo.version;

      // Xác định platform
      final platform = _getPlatform();
      if (platform == null) return;

      // Query Supabase — lấy version mới nhất cho platform này
      final client = Supabase.instance.client;
      final response = await client
          .from('app_versions')
          .select()
          .eq('platform', platform)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return;

      final latestBuild = (response['build_number'] as num?)?.toInt() ?? 0;
      final latestVersion = response['version_name'] as String? ?? '';
      final downloadUrl = response['download_url'] as String? ?? '';
      final changelog = response['changelog'] as String? ?? '';
      final isForce = response['is_force_update'] as bool? ?? false;

      // So sánh build number
      if (latestBuild <= currentBuild) return;

      // Có bản mới → hiện dialog
      if (context.mounted) {
        _showUpdateDialog(
          context,
          currentVersion: currentVersion,
          latestVersion: latestVersion,
          changelog: changelog,
          downloadUrl: downloadUrl,
          isForceUpdate: isForce,
        );
      }
    } catch (e) {
      debugPrint('[UpdateChecker] Error: $e');
      // Không có mạng hoặc bảng chưa tạo → bỏ qua im lặng
    }
  }

  static String? _getPlatform() {
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isWindows) return 'windows';
    } catch (_) {}
    return null;
  }

  static void _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required String latestVersion,
    required String changelog,
    required String downloadUrl,
    required bool isForceUpdate,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isForceUpdate,
      builder: (ctx) => PopScope(
        canPop: !isForceUpdate,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ──
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kNavy, Color(0xFF2D2B8A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: _kNavy.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.system_update_rounded,
                    color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),

                // ── Title ──
                Text('Có bản cập nhật mới!',
                  style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w800,
                    color: const Color(0xFF1A1207),
                  )),
                const SizedBox(height: 6),

                // ── Version info ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _kOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'v$currentVersion → v$latestVersion',
                    style: GoogleFonts.outfit(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _kOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Changelog ──
                if (changelog.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Có gì mới:',
                          style: GoogleFonts.outfit(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: const Color(0xFF5A5260),
                          )),
                        const SizedBox(height: 6),
                        Text(changelog,
                          style: GoogleFonts.outfit(
                            fontSize: 13, height: 1.5,
                            color: const Color(0xFF1A1207),
                          )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Force update warning ──
                if (isForceUpdate) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                          color: _kOrange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Bắt buộc cập nhật để tiếp tục sử dụng',
                            style: GoogleFonts.outfit(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: _kOrange,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Buttons ──
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _openDownloadUrl(downloadUrl);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Cập nhật ngay'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                if (!isForceUpdate) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Để sau',
                      style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: const Color(0xFF9E9085),
                      )),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Future<void> _openDownloadUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[UpdateChecker] Cannot open URL: $e');
    }
  }
}
