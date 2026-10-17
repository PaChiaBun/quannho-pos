// lib/core/services/app_update_manager.dart
// ─────────────────────────────────────────────────────────────────────────────
// AppUpdateManager — Dịch vụ cập nhật ứng dụng hợp nhất (Unified Updater)
// Hỗ trợ tự động kiểm tra và cập nhật đa nền tảng:
//   - Windows: Tải .exe về %TEMP%, hiển thị progress bar, chạy detached installer (/SILENT /NORESTART)
//   - Android: Tải .apk về cache, hiển thị progress bar, kích hoạt Intent cài đặt qua FileProvider
//   - iOS: Thông báo trung tính, điều hướng mở Apple App Store (tuân thủ Apple Guideline 3.1.1)
//
// Single Source of Truth: Supabase (public.app_versions) -> Fallback VPS (quannho.lpm.vn/api/versions)
// Loại bỏ 100% phụ thuộc GitHub API.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:io' show File, HttpClient, Platform, Process, ProcessStartMode, exit;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_version_info.dart';

class AppUpdateManager {
  static const Color _kNavy = Color(0xFF1E1C5E);
  static const Color _kOrange = Color(0xFFE85D20);

  // URL dự phòng mặc định khi database chưa cấu hình download_url
  static const String defaultWindowsDownloadUrl =
      'https://quannho.lpm.vn/download/windows/QuanNhoPOS-latest.exe';
  static const String defaultAndroidDownloadUrl =
      'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk';
  static const String defaultIosAppStoreUrl =
      'https://apps.apple.com/app/id6795376140';
  static const String fallbackVpsApiBase =
      'https://quannho.lpm.vn/api/versions';

  /// Cờ khóa chống trùng lặp: Ngăn việc mở nhiều hộp thoại cập nhật cùng lúc
  /// khi main.dart và dashboard_screen.dart cùng kích hoạt lúc khởi động.
  static bool _isChecking = false;

  /// Xác định tên định danh nền tảng chuẩn hóa (lowercase)
  static String? getCurrentPlatform() {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isWindows) return 'windows';
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {}
    return null;
  }

  /// Lấy thông tin phiên bản mới nhất dưới dạng Map<String, dynamic>
  /// Tuân thủ Interface Contract:
  /// 1. Query Supabase public.app_versions
  /// 2. Nếu lỗi hoặc rỗng -> Fallback sang VPS API https://quannho.lpm.vn/api/versions
  /// 3. Tuyệt đối 0 gọi GitHub API
  static Future<Map<String, dynamic>?> getLatestVersion(String platform) async {
    final info = await getLatestVersionInfo(platform);
    return info?.toJson();
  }

  /// Lấy thông tin phiên bản mới nhất dưới dạng typed model [AppVersionInfo]
  static Future<AppVersionInfo?> getLatestVersionInfo(String platform) async {
    final cleanPlatform = platform.trim().toLowerCase();

    // ── Bước 1: Query Supabase public.app_versions (SSOT chính) ──
    try {
      final client = Supabase.instance.client;
      final response = await client
          .from('app_versions')
          .select()
          .eq('platform', cleanPlatform)
          .order('build_number', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response is Map<String, dynamic>) {
        return AppVersionInfo.fromJson(response);
      }
    } catch (e) {
      debugPrint('[AppUpdateManager] Supabase app_versions query fallback: $e');
    }

    // ── Bước 2: Fallback sang API nội bộ VPS quannho.lpm.vn ──
    try {
      final vpsUri = Uri.parse('$fallbackVpsApiBase?platform=$cleanPlatform');
      final res = await http.get(vpsUri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            return AppVersionInfo.fromJson(decoded['data'] as Map<String, dynamic>);
          }
          return AppVersionInfo.fromJson(decoded);
        } else if (decoded is List && decoded.isNotEmpty) {
          final first = decoded.first;
          if (first is Map<String, dynamic>) {
            return AppVersionInfo.fromJson(first);
          }
        }
      }
    } catch (e) {
      debugPrint('[AppUpdateManager] VPS fallback query error: $e');
    }

    return null;
  }

  /// Kiểm tra phiên bản và hiển thị hộp thoại cập nhật thích ứng theo nền tảng.
  /// [silent]: Nếu true, không hiển thị SnackBar báo phiên bản mới nhất khi không có bản update.
  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool silent = false,
  }) async {
    if (kIsWeb) return;

    // Ngăn chặn chạy song song nhiều lần
    if (_isChecking) return;
    _isChecking = true;

    try {
      final platform = getCurrentPlatform();
      if (platform == null) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVersion = packageInfo.version;

      final latestInfo = await getLatestVersionInfo(platform);
      if (latestInfo == null) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể kết nối máy chủ kiểm tra cập nhật.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final hasUpdate = latestInfo.isNewerThan(
        currentBuild: currentBuild,
        currentVersion: currentVersion,
      );

      if (!hasUpdate) {
        if (!silent && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✨ Bạn đang sử dụng phiên bản mới nhất (v$currentVersion+$currentBuild)!',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // Có bản cập nhật mới -> Hiển thị hộp thoại giao diện thích ứng
      if (context.mounted) {
        await _showUpdateDialog(
          context,
          currentVersion: currentVersion,
          currentBuild: currentBuild,
          versionInfo: latestInfo,
          packageName: packageInfo.packageName,
        );
      }
    } catch (e) {
      debugPrint('[AppUpdateManager] Error checking update: $e');
    } finally {
      _isChecking = false;
    }
  }

  /// Hiển thị hộp thoại cập nhật ứng dụng
  static Future<void> _showUpdateDialog(
    BuildContext context, {
    required String currentVersion,
    required int currentBuild,
    required AppVersionInfo versionInfo,
    required String packageName,
  }) async {
    final isIos = Platform.isIOS;
    final isWindows = Platform.isWindows;
    final isAndroid = Platform.isAndroid;
    final isForce = versionInfo.isForceUpdate;

    await showDialog(
      context: context,
      barrierDismissible: !isForce,
      builder: (dialogCtx) {
        double downloadProgress = 0.0;
        bool isDownloading = false;
        String statusText = '';
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setState) {
            return PopScope(
              canPop: !isForce && !isDownloading,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Icon biểu tượng ──
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
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
                          child: const Icon(
                            Icons.system_update_rounded,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Tiêu đề hộp thoại ──
                      Text(
                        isIos ? 'Thông Báo Cập Nhật' : 'Có Bản Cập Nhật Mới!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A1207),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // ── Huy hiệu so sánh phiên bản ──
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _kOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'v$currentVersion+$currentBuild → v${versionInfo.versionName}+${versionInfo.buildNumber}',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kOrange,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Changelog / Nội dung thay đổi (Tiếng Việt) ──
                      if (versionInfo.changelog.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7F7F8),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Có gì mới:',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF5A5260),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                versionInfo.changelog,
                                style: GoogleFonts.outfit(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: const Color(0xFF1A1207),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Cảnh báo bắt buộc cập nhật (P0) ──
                      if (isForce) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _kOrange.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: _kOrange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bắt buộc cập nhật để tiếp tục sử dụng hệ thống.',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _kOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ── Trạng thái & Thanh tiến trình tải (Windows & Android) ──
                      if (isDownloading) ...[
                        LinearProgressIndicator(
                          value: downloadProgress > 0 ? downloadProgress : null,
                          color: _kOrange,
                          backgroundColor: Colors.grey.shade200,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          statusText.isNotEmpty
                              ? statusText
                              : 'Đang tải bản cập nhật... ${(downloadProgress * 100).toInt()}%',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: const Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Thông báo lỗi nếu có ──
                      if (errorMessage != null) ...[
                        Text(
                          errorMessage!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ── Nút tác vụ ──
                      if (!isDownloading) ...[
                        ElevatedButton.icon(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();

                            if (isIos) {
                              // iOS Flow: Mở Apple App Store (tuân thủ Apple Review Guidelines)
                              await _handleIosUpdate(versionInfo);
                              if (context.mounted && !isForce) {
                                Navigator.pop(dialogCtx);
                              }
                            } else if (isWindows) {
                              // Windows Flow: Tải QuanNhoPOS-latest.exe và chạy detached installer
                              setState(() {
                                isDownloading = true;
                                errorMessage = null;
                                statusText = 'Đang kết nối máy chủ LPM...';
                              });
                              try {
                                await _handleWindowsUpdate(
                                  versionInfo,
                                  onProgress: (p) {
                                    setState(() {
                                      downloadProgress = p;
                                      statusText =
                                          'Đang tải bản cài đặt POS... ${(p * 100).toInt()}%';
                                    });
                                  },
                                  onStatus: (s) {
                                    setState(() => statusText = s);
                                  },
                                );
                              } catch (err) {
                                setState(() {
                                  isDownloading = false;
                                  errorMessage =
                                      'Lỗi khi tải hoặc cài đặt: $err';
                                });
                              }
                            } else if (isAndroid) {
                              // Android Flow: Tải APK về cache và kích hoạt Intent cài đặt FileProvider
                              setState(() {
                                isDownloading = true;
                                errorMessage = null;
                                statusText = 'Đang tải bản cập nhật APK...';
                              });
                              try {
                                await _handleAndroidUpdate(
                                  versionInfo,
                                  packageName: packageName,
                                  onProgress: (p) {
                                    setState(() {
                                      downloadProgress = p;
                                      statusText =
                                          'Đang tải gói APK... ${(p * 100).toInt()}%';
                                    });
                                  },
                                  onStatus: (s) {
                                    setState(() => statusText = s);
                                  },
                                );
                              } catch (err) {
                                setState(() {
                                  isDownloading = false;
                                  errorMessage = 'Lỗi cập nhật APK: $err';
                                });
                              }
                            } else {
                              // Nền tảng khác (macOS / Linux / Web)
                              await _handleGenericUrlLaunch(versionInfo);
                              if (context.mounted && !isForce) {
                                Navigator.pop(dialogCtx);
                              }
                            }
                          },
                          icon: Icon(
                            isIos
                                ? Icons.open_in_new_rounded
                                : Icons.download_rounded,
                            size: 18,
                          ),
                          label: Text(
                            isIos ? 'Mở App Store' : 'Cập nhật ngay',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kNavy,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                        if (!isForce) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: Text(
                              'Để sau',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF9E9085),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Xử lý cập nhật cho iOS: Mở Apple App Store
  static Future<void> _handleIosUpdate(AppVersionInfo versionInfo) async {
    final rawUrl = versionInfo.downloadUrl.isNotEmpty
        ? versionInfo.downloadUrl
        : defaultIosAppStoreUrl;
    final uri = Uri.parse(rawUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Xử lý cập nhật cho Windows POS:
  /// 1. Tải QuanNhoPOS-latest.exe về %TEMP%
  /// 2. Báo cáo tiến trình linear
  /// 3. Khởi chạy installer Inno Setup ở chế độ detached (/SILENT /NORESTART)
  /// 4. Đợi 500ms và thoát app (exit(0)), bảo toàn 100% CSDL Drift SQLite và máy in trong SharedPreferences
  static Future<void> _handleWindowsUpdate(
    AppVersionInfo versionInfo, {
    required void Function(double progress) onProgress,
    required void Function(String status) onStatus,
  }) async {
    final downloadUrl = versionInfo.downloadUrl.isNotEmpty
        ? versionInfo.downloadUrl
        : defaultWindowsDownloadUrl;

    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}\\QuanNhoPOS-latest.exe';

    onStatus('Đang tải bản cài đặt POS từ máy chủ...');
    await downloadFileWithProgress(
      url: downloadUrl,
      targetPath: targetPath,
      onProgress: onProgress,
    );

    onStatus('Đang khởi chạy bản cài đặt mới...');
    onProgress(1.0);

    // Chạy detached process với cờ /SILENT /NORESTART
    // Inno Setup sẽ ghi đè file binary trong Program Files.
    // Thư mục %APPDATA% chứa CSDL Drift và SharedPreferences giữ nguyên vẹn 100%.
    await Process.start(
      targetPath,
      const ['/SILENT', '/NORESTART'],
      mode: ProcessStartMode.detached,
    );

    // Đợi 500ms để process con tách rời an toàn rồi tắt app POS hiện tại
    await Future.delayed(const Duration(milliseconds: 500));
    exit(0);
  }

  /// Xử lý cập nhật cho Android / Sunmi:
  /// 1. Tải APK QuanNhoPOS-latest.apk vào thư mục cache
  /// 2. Kích hoạt Android install Intent với FileProvider Content URI
  /// 3. Fallback mở trực tiếp downloadUrl nếu Content URI bị chặn
  static Future<void> _handleAndroidUpdate(
    AppVersionInfo versionInfo, {
    required String packageName,
    required void Function(double progress) onProgress,
    required void Function(String status) onStatus,
  }) async {
    final downloadUrl = versionInfo.downloadUrl.isNotEmpty
        ? versionInfo.downloadUrl
        : defaultAndroidDownloadUrl;

    final cacheDir = await getTemporaryDirectory();
    final apkPath = '${cacheDir.path}/QuanNhoPOS-latest.apk';

    onStatus('Đang tải gói cập nhật APK...');
    await downloadFileWithProgress(
      url: downloadUrl,
      targetPath: apkPath,
      onProgress: onProgress,
    );

    onStatus('Đang kích hoạt cài đặt...');
    onProgress(1.0);

    // Chuẩn bị Content URI trỏ tới FileProvider đã cấu hình trong AndroidManifest.xml
    final authority = '$packageName.fileprovider';
    final contentUri = Uri.parse('content://$authority/internal_cache/QuanNhoPOS-latest.apk');

    bool launched = false;
    try {
      if (await canLaunchUrl(contentUri)) {
        await launchUrl(contentUri, mode: LaunchMode.externalApplication);
        launched = true;
      }
    } catch (e) {
      debugPrint('[AppUpdateManager] Launch content URI failed: $e');
    }

    // Fallback: Nếu hệ thống không hỗ trợ mở Content URI qua url_launcher trực tiếp,
    // mở link tải APK trên trình duyệt/trình cài đặt mặc định
    if (!launched) {
      final directUri = Uri.parse(downloadUrl);
      if (await canLaunchUrl(directUri)) {
        await launchUrl(directUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  /// Mở liên kết chung cho macOS hoặc nền tảng khác
  static Future<void> _handleGenericUrlLaunch(AppVersionInfo versionInfo) async {
    final targetUrl = versionInfo.downloadUrl.isNotEmpty
        ? versionInfo.downloadUrl
        : 'https://quannho.lpm.vn';
    final uri = Uri.parse(targetUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Tiện ích tải file HTTP dạng Stream có báo cáo tiến trình
  static Future<File> downloadFileWithProgress({
    required String url,
    required String targetPath,
    required void Function(double progress) onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception(
          'Máy chủ trả về mã HTTP ${response.statusCode} khi tải file.',
        );
      }

      final file = File(targetPath);
      // Đảm bảo thư mục cha tồn tại
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      final fileSink = file.openWrite();
      int downloadedBytes = 0;
      final totalBytes = response.contentLength;

      await for (final chunk in response) {
        fileSink.add(chunk);
        downloadedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress(downloadedBytes / totalBytes);
        }
      }

      await fileSink.flush();
      await fileSink.close();
      return file;
    } finally {
      client.close();
    }
  }
}
