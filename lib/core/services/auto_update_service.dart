import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class AutoUpdateService {
  static const String _githubRepo = 'PaChiaBun/quannho-pos';
  static const String _latestReleaseUrl = 'https://api.github.com/repos/$_githubRepo/releases/latest';

  /// Kiểm tra xem có bản cập nhật mới hay không
  static Future<void> checkForUpdates(BuildContext context, {bool showNoUpdateDialog = false}) async {
    if (kIsWeb) return;
    // Chỉ chạy tính năng tự cập nhật trên Windows
    if (!Platform.isWindows) return;

    try {
      final response = await http.get(Uri.parse(_latestReleaseUrl));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final remoteTag = data['tag_name'] as String? ?? '';
      if (remoteTag.isEmpty) return;

      // Chuẩn hoá remote version (ví dụ v1.0.4 -> 1.0.4)
      final remoteVersion = remoteTag.startsWith('v') ? remoteTag.substring(1) : remoteTag;

      // Lấy phiên bản hiện tại của ứng dụng
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (_isNewerVersion(currentVersion, remoteVersion)) {
        // Tìm link tải file QuanNhoPOS-Setup.exe
        final assets = data['assets'] as List<dynamic>? ?? [];
        String downloadUrl = '';
        for (final asset in assets) {
          final name = asset['name'] as String? ?? '';
          if (name.endsWith('-Setup.exe') || name == 'QuanNhoPOS-Setup.exe') {
            downloadUrl = asset['browser_download_url'] as String? ?? '';
            break;
          }
        }

        if (downloadUrl.isNotEmpty && context.mounted) {
          _showUpdateDialog(context, currentVersion, remoteVersion, downloadUrl);
        }
      } else {
        if (showNoUpdateDialog && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✨ Bạn đang sử dụng phiên bản mới nhất!'),
            behavior: SnackBarBehavior.floating,
          ));
        }
      }
    } catch (_) {
      // Bỏ qua lỗi mạng
    }
  }

  /// So sánh hai chuỗi version (ví dụ: "1.0.2" và "1.0.4")
  static bool _isNewerVersion(String current, String remote) {
    try {
      final currentParts = current.split('.').map(int.parse).toList();
      final remoteParts = remote.split('.').map(int.parse).toList();

      for (int i = 0; i < currentParts.length && i < remoteParts.length; i++) {
        if (remoteParts[i] > currentParts[i]) return true;
        if (remoteParts[i] < currentParts[i]) return false;
      }
      return remoteParts.length > currentParts.length;
    } catch (_) {
      return current != remote;
    }
  }

  /// Hiển thị hộp thoại thông báo cập nhật
  static void _showUpdateDialog(BuildContext context, String current, String remote, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        double downloadProgress = 0.0;
        bool isDownloading = false;
        String statusText = 'Đã có phiên bản mới v$remote (phiên bản hiện tại v$current). Bạn có muốn tải về và cài đặt ngay không?';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.system_update_rounded, color: Color(0xFFE85D20)),
                  SizedBox(width: 10),
                  Text('Cập Nhật Ứng Dụng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(statusText, style: const TextStyle(fontSize: 13, height: 1.5)),
                    if (isDownloading) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(value: downloadProgress, color: const Color(0xFFE85D20), backgroundColor: Colors.grey.shade200),
                      const SizedBox(height: 8),
                      Text('Đang tải bản cài đặt... ${(downloadProgress * 100).toInt()}%',
                          textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ],
                ),
              ),
              actions: isDownloading
                  ? []
                  : [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Lần sau'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE85D20),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          setState(() {
                            isDownloading = true;
                            statusText = 'Đang tải bản cài đặt từ máy chủ... Vui lòng không tắt phần mềm.';
                          });

                          try {
                            final tempDir = await getTemporaryDirectory();
                            final filePath = '${tempDir.path}/QuanNhoPOS-Setup.exe';
                            
                            // Thực hiện tải file bằng HttpClient để theo dõi tiến trình
                            final client = HttpClient();
                            final request = await client.getUrl(Uri.parse(url));
                            final response = await request.close();
                            
                            if (response.statusCode == 200) {
                              final file = File(filePath);
                              final fileSink = file.openWrite();
                              
                              int downloadedBytes = 0;
                              final totalBytes = response.contentLength;

                              await for (final chunk in response) {
                                fileSink.add(chunk);
                                downloadedBytes += chunk.length;
                                if (totalBytes > 0) {
                                  setState(() {
                                    downloadProgress = downloadedBytes / totalBytes;
                                  });
                                }
                              }
                              await fileSink.close();
                              client.close();

                              setState(() {
                                statusText = 'Đang chạy bản cài đặt mới và khởi động lại...';
                                downloadProgress = 1.0;
                              });

                              // Chạy file .exe vừa tải về để tiến hành cài đè
                              await Process.start(filePath, [], mode: ProcessStartMode.detached);

                              // Tắt app hiện tại để bản cài đè có thể ghi đè file
                              await Future.delayed(const Duration(milliseconds: 500));
                              exit(0);
                            } else {
                              throw Exception('Download failed with status: ${response.statusCode}');
                            }
                          } catch (e) {
                            setState(() {
                              isDownloading = false;
                              statusText = 'Lỗi tải bản cài đặt: $e.\nBạn có muốn mở link tải bằng trình duyệt không?';
                            });
                          }
                        },
                        child: const Text('Cập nhật ngay'),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}
