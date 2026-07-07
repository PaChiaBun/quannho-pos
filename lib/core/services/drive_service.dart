// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DRIVE SERVICE — Upload ảnh chấm công lên Google Drive
// Dùng Service Account (không cần OAuth per-user)
// ─────────────────────────────────────────────────────────────────────────────
class DriveService {
  static const _scopes = [drive.DriveApi.driveFileScope];

  // ── Lấy service account credentials từ Supabase app_settings ──────────────
  // Key: 'drive_service_account' | Value: JSON string của service account key
  static Future<Map<String, dynamic>?> _loadCredentials() async {
    try {
      final db = Supabase.instance.client;
      final res = await db
          .from('app_settings')
          .select('value')
          .eq('key', 'drive_service_account')
          .maybeSingle();
      if (res == null) return null;
      return jsonDecode(res['value'] as String) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[DriveService] loadCredentials error: $e');
      return null;
    }
  }

  // ── Lưu service account JSON vào Supabase (chủ quán chạy 1 lần) ──────────
  static Future<bool> saveCredentials({
    required String storeId,
    required String serviceAccountJson,
    required String driveFolderId,
  }) async {
    try {
      final db = Supabase.instance.client;
      await db.from('app_settings').upsert([
        {
          'store_id': storeId,
          'key': 'drive_service_account',
          'value': serviceAccountJson,
        },
        {
          'store_id': storeId,
          'key': 'drive_folder_id',
          'value': driveFolderId,
        },
      ], onConflict: 'store_id,key');
      return true;
    } catch (e) {
      debugPrint('[DriveService] saveCredentials error: $e');
      return false;
    }
  }

  // ── Upload ảnh lên Drive ──────────────────────────────────────────────────
  /// Trả về (fileId, webViewLink) hoặc null nếu thất bại
  static Future<({String fileId, String? viewLink})?> uploadPhoto({
    required String storeId,
    required File photoFile,
    required String fileName,        // VD: "2024-01-15_08-30_NVA.jpg"
    required String subFolder,       // VD: "2024-01" (YYYY-MM)
  }) async {
    if (kIsWeb) return null;
    try {
      // 1. Load credentials
      final creds = await _loadCredentials();
      if (creds == null) {
        debugPrint('[DriveService] No credentials found — fallback to Supabase Storage');
        return null;
      }

      // 2. Load folder ID
      final db = Supabase.instance.client;
      final folderRes = await db
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', 'drive_folder_id')
          .maybeSingle();
      final rootFolderId = folderRes?['value'] as String?;
      if (rootFolderId == null) {
        debugPrint('[DriveService] No folder ID found');
        return null;
      }

      // 3. Auth với service account
      final accountCredentials = ServiceAccountCredentials.fromJson(creds);
      final authClient = await clientViaServiceAccount(accountCredentials, _scopes);

      try {
        final driveApi = drive.DriveApi(authClient);

        // 4. Tìm hoặc tạo subfolder YYYY-MM
        final subFolderId = await _getOrCreateFolder(
          driveApi: driveApi,
          parentId: rootFolderId,
          name: subFolder,
        );

        // 5. Upload file
        final media = drive.Media(
          photoFile.openRead(),
          await photoFile.length(),
          contentType: 'image/jpeg',
        );

        final fileMetadata = drive.File()
          ..name = fileName
          ..parents = [subFolderId]
          ..description = 'Chấm công tự động — Quán Nhỏ POS';

        final uploaded = await driveApi.files.create(
          fileMetadata,
          uploadMedia: media,
          $fields: 'id,webViewLink',
        );

        debugPrint('[DriveService] Uploaded: ${uploaded.id}');
        return (fileId: uploaded.id!, viewLink: uploaded.webViewLink);
      } finally {
        authClient.close();
      }
    } catch (e) {
      debugPrint('[DriveService] uploadPhoto error: $e');
      return null;
    }
  }

  // ── Helper: tìm hoặc tạo folder con ──────────────────────────────────────
  static Future<String> _getOrCreateFolder({
    required drive.DriveApi driveApi,
    required String parentId,
    required String name,
  }) async {
    // Tìm folder đã tồn tại
    final query = "name='$name' and '$parentId' in parents and "
        "mimeType='application/vnd.google-apps.folder' and trashed=false";
    final list = await driveApi.files.list(
      q: query,
      $fields: 'files(id)',
      spaces: 'drive',
    );

    if (list.files != null && list.files!.isNotEmpty) {
      return list.files!.first.id!;
    }

    // Tạo mới nếu chưa có
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder'
      ..parents = [parentId];

    final created = await driveApi.files.create(folder, $fields: 'id');
    return created.id!;
  }

  // ── Kiểm tra Drive đã được cấu hình chưa ──────────────────────────────────
  static Future<bool> isConfigured(String storeId) async {
    try {
      final db = Supabase.instance.client;
      final res = await db
          .from('app_settings')
          .select('key')
          .eq('store_id', storeId)
          .inFilter('key', ['drive_service_account', 'drive_folder_id']);
      return (res as List).length >= 2;
    } catch (_) {
      return false;
    }
  }

  // ── Xóa ảnh cũ trên Drive theo folder yyyy-MM ─────────────────────────────
  /// Xóa toàn bộ folder con (yyyy-MM) nếu tháng đó > [retentionDays] ngày trước
  /// Áp dụng cho cả staff-photos và ops_proofs
  static Future<void> cleanupOldDrivePhotos({
    required String storeId,
    int retentionDays = 90,
  }) async {
    try {
      final creds = await _loadCredentials();
      if (creds == null) return;

      final db = Supabase.instance.client;
      final folderRes = await db
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', 'drive_folder_id')
          .maybeSingle();
      final rootFolderId = folderRes?['value'] as String?;
      if (rootFolderId == null) return;

      final accountCredentials = ServiceAccountCredentials.fromJson(creds);
      final authClient = await clientViaServiceAccount(accountCredentials, _scopes);

      try {
        final driveApi = drive.DriveApi(authClient);
        final cutoff = DateTime.now().subtract(Duration(days: retentionDays));

        // Tìm tất cả folder con trực tiếp (yyyy-MM format)
        await _deleteOldSubfolders(
          driveApi: driveApi,
          parentId: rootFolderId,
          cutoff: cutoff,
        );

        // Tìm folder ops_proofs (nếu có) và xóa sub-folder con của nó
        final opsQuery = "name='ops_proofs' and '$rootFolderId' in parents and "
            "mimeType='application/vnd.google-apps.folder' and trashed=false";
        final opsList = await driveApi.files.list(q: opsQuery, $fields: 'files(id)', spaces: 'drive');
        if (opsList.files != null && opsList.files!.isNotEmpty) {
          final opsFolderId = opsList.files!.first.id!;
          await _deleteOldSubfolders(
            driveApi: driveApi,
            parentId: opsFolderId,
            cutoff: cutoff,
          );
        }

        debugPrint('[DriveService] Cleanup hoàn tất (> $retentionDays ngày)');
      } finally {
        authClient.close();
      }
    } catch (e) {
      debugPrint('[DriveService] cleanupOldDrivePhotos error: $e');
    }
  }

  // Helper: xóa folder con dạng yyyy-MM nếu cũ hơn cutoff
  static Future<void> _deleteOldSubfolders({
    required drive.DriveApi driveApi,
    required String parentId,
    required DateTime cutoff,
  }) async {
    final query = "'$parentId' in parents and "
        "mimeType='application/vnd.google-apps.folder' and trashed=false";
    final list = await driveApi.files.list(
      q: query,
      $fields: 'files(id,name)',
      spaces: 'drive',
    );
    for (final folder in list.files ?? []) {
      final name = folder.name ?? '';
      // Parse yyyy-MM → lấy ngày đầu tháng
      final parts = name.split('-');
      if (parts.length != 2) continue;
      final year  = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year == null || month == null) continue;
      // Xóa nếu cả tháng đã qua cutoff (ngày cuối tháng < cutoff)
      final folderMonthEnd = DateTime(year, month + 1, 0);
      if (folderMonthEnd.isBefore(cutoff)) {
        try {
          await driveApi.files.delete(folder.id!);
          debugPrint('[DriveService] Xóa folder $name (${folder.id})');
        } catch (e) {
          debugPrint('[DriveService] Không thể xóa $name: $e');
        }
      }
    }
  }
}

// ── Fallback: Supabase Storage ────────────────────────────────────────────────
class SupabaseStorageFallback {
  static Future<String?> uploadPhoto({
    required String storeId,
    required Uint8List photoBytes,
    required String fileName,
  }) async {
    try {
      final db = Supabase.instance.client;
      final path = 'staff-photos/$storeId/$fileName';
      await db.storage.from('staff-photos').uploadBinary(
        path,
        photoBytes,
        fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
      );
      return db.storage.from('staff-photos').getPublicUrl(path);
    } catch (e) {
      debugPrint('[SupabaseStorage] upload error: $e');
      return null;
    }
  }
}

extension SupabaseStorageFallbackCleanup on SupabaseStorageFallback {
  static Future<void> cleanupOldAttendancePhotos({
    required String storeId,
    int retentionDays = 90,
  }) async {
    try {
      final db = Supabase.instance.client;
      final cutoff = DateTime.now().subtract(Duration(days: retentionDays));

      // List tất cả file trong folder của store
      final files = await db.storage
          .from('staff-photos')
          .list(path: 'staff-photos/$storeId');

      final toDelete = <String>[];
      for (final file in files) {
        // Tên file: yyyy-MM-dd_HH-mm_Name.jpg → lấy 10 ký tự đầu làm date
        final name = file.name;
        if (name.length < 10) continue;
        final fileDate = DateTime.tryParse(name.substring(0, 10));
        if (fileDate == null) continue;
        if (fileDate.isBefore(cutoff)) {
          toDelete.add('staff-photos/$storeId/$name');
        }
      }

      if (toDelete.isNotEmpty) {
        await db.storage.from('staff-photos').remove(toDelete);
        debugPrint('[SupabaseStorage] Xóa ${toDelete.length} ảnh chấm công > $retentionDays ngày');
      }
    } catch (e) {
      debugPrint('[SupabaseStorage] cleanup error: $e');
    }
  }
}
