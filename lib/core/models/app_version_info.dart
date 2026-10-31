// lib/core/models/app_version_info.dart
// ─────────────────────────────────────────────────────────────────────────────
// Model chứa thông tin phiên bản ứng dụng trên Supabase public.app_versions
// hoặc API nội bộ VPS quannho.lpm.vn
// ─────────────────────────────────────────────────────────────────────────────

class AppVersionInfo {
  final String? id;
  final String platform;
  final String versionName;
  final int buildNumber;
  final String downloadUrl;
  final String changelog;
  final bool isForceUpdate;
  final DateTime? createdAt;

  const AppVersionInfo({
    this.id,
    required this.platform,
    required this.versionName,
    required this.buildNumber,
    required this.downloadUrl,
    this.changelog = '',
    this.isForceUpdate = false,
    this.createdAt,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    int parsedBuild = 0;
    final rawBuild = json['build_number'] ?? json['buildNumber'];
    if (rawBuild is num) {
      parsedBuild = rawBuild.toInt();
    } else if (rawBuild != null) {
      parsedBuild = int.tryParse(rawBuild.toString()) ?? 0;
    }

    final rawCreatedAt = json['created_at'] ?? json['createdAt'];
    DateTime? parsedCreatedAt;
    if (rawCreatedAt is String && rawCreatedAt.isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt);
    } else if (rawCreatedAt is DateTime) {
      parsedCreatedAt = rawCreatedAt;
    }

    final rawForce = json['is_force_update'] ?? json['isForceUpdate'];
    bool parsedForce = false;
    if (rawForce is bool) {
      parsedForce = rawForce;
    } else if (rawForce is num) {
      parsedForce = rawForce != 0;
    } else if (rawForce is String) {
      parsedForce = rawForce.toLowerCase() == 'true' || rawForce == '1';
    }

    final rawPlatform = json['platform'];
    final rawVersionName = json['version_name'] ?? json['versionName'];
    final rawDownloadUrl = json['download_url'] ?? json['downloadUrl'];
    final rawChangelog = json['changelog'];

    return AppVersionInfo(
      id: json['id']?.toString(),
      platform: (rawPlatform?.toString() ?? '').toLowerCase(),
      versionName: rawVersionName?.toString() ?? '',
      buildNumber: parsedBuild,
      downloadUrl: rawDownloadUrl?.toString() ?? '',
      changelog: rawChangelog?.toString() ?? '',
      isForceUpdate: parsedForce,
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'platform': platform,
      'version_name': versionName,
      'build_number': buildNumber,
      'download_url': downloadUrl,
      'changelog': changelog,
      'is_force_update': isForceUpdate,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Kiểm tra xem phiên bản từ server có mới hơn phiên bản client hiện tại không.
  /// Ưu tiên so sánh build number số học nếu cả hai đều > 0.
  /// Nếu build number bằng nhau (hoặc build number server <= 0), so sánh chuỗi semantic version.
  bool isNewerThan({required int currentBuild, String? currentVersion}) {
    if (buildNumber > 0 && currentBuild > 0) {
      if (buildNumber > currentBuild) return true;
      if (buildNumber < currentBuild) return false;
    }

    // Nếu build numbers bằng nhau hoặc build number <= 0, kiểm tra chuỗi version ngữ nghĩa
    if (currentVersion != null && currentVersion.isNotEmpty && versionName.isNotEmpty) {
      return isNewerVersionString(currentVersion, versionName);
    }
    return buildNumber > currentBuild;
  }

  /// So sánh hai chuỗi semantic version (ví dụ: "1.0.2" vs "1.0.4")
  static bool isNewerVersionString(String current, String remote) {
    try {
      final cleanCurrent = current.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '').split('+').first;
      final cleanRemote = remote.trim().toLowerCase().replaceFirst(RegExp(r'^v'), '').split('+').first;

      final currentHasPre = cleanCurrent.contains('-');
      final remoteHasPre = cleanRemote.contains('-');

      final currentCore = cleanCurrent.split('-').first;
      final remoteCore = cleanRemote.split('-').first;

      final currentParts = currentCore.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remoteParts = remoteCore.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLen = currentParts.length > remoteParts.length ? currentParts.length : remoteParts.length;
      for (int i = 0; i < maxLen; i++) {
        final c = i < currentParts.length ? currentParts[i] : 0;
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }

      // Precedence: A final release is higher precedence than a pre-release with same core version
      if (currentHasPre && !remoteHasPre) return true; // e.g. 1.0.0-rc.1 -> 1.0.0 is newer
      if (!currentHasPre && remoteHasPre) return false; // e.g. 1.0.0 -> 1.0.0-rc.1 is older

      return false;
    } catch (_) {
      return current != remote;
    }
  }

  @override
  String toString() =>
      'AppVersionInfo($platform, v$versionName+$buildNumber, force: $isForceUpdate)';
}
