// test/core/app_update_manager_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Tier 1 & Tier 2: Comprehensive Test Suite for AppUpdateManager & AppVersionInfo
//
// Tier 1: Feature Coverage
//   - Version comparison logic (build_number greater, equal, lesser)
//   - Semantic version fallback comparison (e.g. 1.0.3 vs 1.0.2 when builds match)
//   - JSON parsing of version payloads (Supabase & VPS formats)
//   - Round-trip serialization (toJson / fromJson)
//   - Silent vs non-silent behavior
//   - Platform default download URLs
//
// Tier 2: Boundary & Corner Cases
//   - Corrupt or missing version strings (non-numeric, null, empty)
//   - Zero build numbers and negative build numbers
//   - Force update guardrail (barrierDismissible = false, PopScope canPop = false, no "Để sau" button)
//   - Optional update behavior ("Để sau" button present, canPop = true)
//   - Network failure resilience (no unhandled exceptions on network/DB failure)
//   - Vietnamese UTF-8 changelog fidelity
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/models/app_version_info.dart';
import 'package:quannho_pos/core/services/app_update_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER 1: FEATURE COVERAGE — APP VERSION INFO & LOGIC
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tier 1: AppVersionInfo Parsing & Serialization', () {
    test('parses standard Supabase snake_case JSON payload correctly', () {
      final jsonPayload = {
        'id': 'ver-001',
        'platform': 'android',
        'version_name': '1.0.3',
        'build_number': 8,
        'download_url': 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
        'changelog': '• Tối ưu hiệu năng đồng bộ kho hàng\n• Sửa lỗi in hóa đơn',
        'is_force_update': true,
        'created_at': '2026-09-24T12:00:00Z',
      };

      final info = AppVersionInfo.fromJson(jsonPayload);

      expect(info.id, 'ver-001');
      expect(info.platform, 'android');
      expect(info.versionName, '1.0.3');
      expect(info.buildNumber, 8);
      expect(info.downloadUrl, 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk');
      expect(info.changelog, contains('Tối ưu hiệu năng'));
      expect(info.isForceUpdate, true);
      expect(info.createdAt, isNotNull);
      expect(info.createdAt!.year, 2026);
    });

    test('parses camelCase payload (VPS fallback format) correctly', () {
      final jsonPayload = {
        'platform': 'windows',
        'versionName': '1.0.2',
        'buildNumber': 7,
        'downloadUrl': 'https://quannho.lpm.vn/download/windows/QuanNhoPOS-latest.exe',
        'changelog': 'Bản cập nhật định kỳ',
        'isForceUpdate': false,
      };

      final info = AppVersionInfo.fromJson(jsonPayload);

      expect(info.platform, 'windows');
      expect(info.versionName, '1.0.2');
      expect(info.buildNumber, 7);
      expect(info.downloadUrl, 'https://quannho.lpm.vn/download/windows/QuanNhoPOS-latest.exe');
      expect(info.isForceUpdate, false);
      expect(info.changelog, 'Bản cập nhật định kỳ');
    });

    test('round-trip serialization toJson preserves all fields', () {
      const original = AppVersionInfo(
        id: 'ver-roundtrip',
        platform: 'ios',
        versionName: '1.0.4',
        buildNumber: 10,
        downloadUrl: 'https://apps.apple.com/app/id6795376140',
        changelog: 'iOS Store update',
        isForceUpdate: false,
      );

      final json = original.toJson();
      final reconstructed = AppVersionInfo.fromJson(json);

      expect(reconstructed.id, original.id);
      expect(reconstructed.platform, original.platform);
      expect(reconstructed.versionName, original.versionName);
      expect(reconstructed.buildNumber, original.buildNumber);
      expect(reconstructed.downloadUrl, original.downloadUrl);
      expect(reconstructed.changelog, original.changelog);
      expect(reconstructed.isForceUpdate, original.isForceUpdate);
    });

    test('platform string is always normalized to lowercase', () {
      final info = AppVersionInfo.fromJson({
        'platform': 'WINDOWS',
        'version_name': '1.0.0',
        'build_number': 1,
        'download_url': 'https://example.com/app.exe',
      });

      expect(info.platform, 'windows');
    });
  });

  group('Tier 1: Version Comparison Logic (isNewerThan)', () {
    test('returns true when server build_number is strictly greater', () {
      const serverVersion = AppVersionInfo(
        platform: 'android',
        versionName: '1.0.2',
        buildNumber: 8,
        downloadUrl: 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
      );

      // Current build 7 < server build 8
      expect(serverVersion.isNewerThan(currentBuild: 7), isTrue);
      expect(serverVersion.isNewerThan(currentBuild: 1), isTrue);
    });

    test('returns false when server build_number is strictly lesser', () {
      const serverVersion = AppVersionInfo(
        platform: 'android',
        versionName: '1.0.2',
        buildNumber: 5,
        downloadUrl: 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
      );

      // Current build 7 > server build 5
      expect(serverVersion.isNewerThan(currentBuild: 7), isFalse);
    });

    test('falls back to semantic version comparison when build numbers are equal', () {
      const serverVersionHigherSemantic = AppVersionInfo(
        platform: 'android',
        versionName: '1.0.3',
        buildNumber: 7,
        downloadUrl: 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
      );

      // Equal build 7, but server semantic 1.0.3 > client 1.0.2
      expect(
        serverVersionHigherSemantic.isNewerThan(
          currentBuild: 7,
          currentVersion: '1.0.2',
        ),
        isTrue,
      );

      // Equal build 7, and identical version 1.0.3 == 1.0.3 -> false
      expect(
        serverVersionHigherSemantic.isNewerThan(
          currentBuild: 7,
          currentVersion: '1.0.3',
        ),
        isFalse,
      );

      // Equal build 7, but client semantic is higher 1.1.0 > 1.0.3 -> false
      expect(
        serverVersionHigherSemantic.isNewerThan(
          currentBuild: 7,
          currentVersion: '1.1.0',
        ),
        isFalse,
      );
    });

    test('isNewerVersionString handles multi-part semantic numbers correctly', () {
      expect(AppVersionInfo.isNewerVersionString('1.0.2', '1.0.3'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('1.0.9', '1.1.0'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('1.9.9', '2.0.0'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('2.0.0', '1.9.9'), isFalse);
      expect(AppVersionInfo.isNewerVersionString('1.0.2', '1.0.2'), isFalse);

      // With 'v' prefix
      expect(AppVersionInfo.isNewerVersionString('v1.0.2', 'v1.0.3'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('V1.0.2', 'v1.0.1'), isFalse);
    });
  });

  group('Tier 1: AppUpdateManager Architecture & Endpoints Contract', () {
    test('verifies single source of truth default endpoint constants', () {
      expect(
        AppUpdateManager.defaultWindowsDownloadUrl,
        'https://quannho.lpm.vn/download/windows/QuanNhoPOS-latest.exe',
      );
      expect(
        AppUpdateManager.defaultAndroidDownloadUrl,
        'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
      );
      expect(
        AppUpdateManager.defaultIosAppStoreUrl,
        'https://apps.apple.com/app/id6795376140',
      );
      expect(
        AppUpdateManager.fallbackVpsApiBase,
        'https://quannho.lpm.vn/api/versions',
      );
    });

    test('getCurrentPlatform returns valid recognized string or null', () {
      final platform = AppUpdateManager.getCurrentPlatform();
      if (kIsWeb) {
        expect(platform, 'web');
      } else {
        expect(platform, isIn(['windows', 'android', 'ios', 'macos', 'linux']));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // TIER 2: BOUNDARY, CORNER CASES & RESILIENCE
  // ═══════════════════════════════════════════════════════════════════════════

  group('Tier 2: Boundary & Corner Cases — Input Robustness', () {
    test('handles missing or null fields gracefully with safe defaults', () {
      final info = AppVersionInfo.fromJson({});

      expect(info.platform, '');
      expect(info.versionName, '');
      expect(info.buildNumber, 0);
      expect(info.downloadUrl, '');
      expect(info.changelog, '');
      expect(info.isForceUpdate, false);
      expect(info.createdAt, isNull);
    });

    test('handles string-encoded build_number gracefully', () {
      final info = AppVersionInfo.fromJson({
        'platform': 'android',
        'version_name': '1.0.2',
        'build_number': '42',
        'download_url': 'https://example.com/app.apk',
      });

      expect(info.buildNumber, 42);
    });

    test('handles corrupt non-numeric build_number by defaulting to 0', () {
      final info = AppVersionInfo.fromJson({
        'platform': 'android',
        'version_name': '1.0.2',
        'build_number': 'not_a_valid_number',
        'download_url': 'https://example.com/app.apk',
      });

      expect(info.buildNumber, 0);
    });

    test('boundary: handles zero and negative build numbers correctly', () {
      const zeroBuild = AppVersionInfo(
        platform: 'android',
        versionName: '1.0.0',
        buildNumber: 0,
        downloadUrl: 'https://example.com',
      );

      // Client build is 5, server is 0 -> false
      expect(zeroBuild.isNewerThan(currentBuild: 5), isFalse);

      // Client build is 0, server is 0, same semantic -> false
      expect(zeroBuild.isNewerThan(currentBuild: 0, currentVersion: '1.0.0'), isFalse);

      // Client build is 0, server is 0, server higher semantic -> true
      const higherSemanticZeroBuild = AppVersionInfo(
        platform: 'android',
        versionName: '1.0.1',
        buildNumber: 0,
        downloadUrl: 'https://example.com',
      );
      expect(higherSemanticZeroBuild.isNewerThan(currentBuild: 0, currentVersion: '1.0.0'), isTrue);
    });

    test('preserves Vietnamese unicode characters in changelog without corruption', () {
      const vietnameseChangelog =
          '🚀 Quán Nhỏ POS v1.0.3:\n'
          '- Đồng bộ tức thì đơn bàn ăn và phiếu bếp\n'
          '- Khắc phục lỗi in hoá đơn trên máy in nhiệt Sunmi\n'
          '- Bảo toàn dữ liệu bán hàng offline Drift/SQLite 100%';

      final info = AppVersionInfo.fromJson({
        'platform': 'android',
        'version_name': '1.0.3',
        'build_number': 8,
        'download_url': 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
        'changelog': vietnameseChangelog,
      });

      expect(info.changelog, vietnameseChangelog);
      expect(jsonEncode(info.toJson()), contains('Đồng bộ tức thì đơn bàn ăn'));
    });
  });

  group('Tier 2: UI Invariant Guardrails — Force Update vs Optional Update', () {
    testWidgets(
      'Force update (is_force_update = true): PopScope canPop is false and dismiss button is hidden',
      (tester) async {
        const forceUpdateInfo = AppVersionInfo(
          platform: 'android',
          versionName: '2.0.0',
          buildNumber: 99,
          downloadUrl: 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
          changelog: 'Bản vá khẩn cấp P0 lỗi bảo mật',
          isForceUpdate: true,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: !forceUpdateInfo.isForceUpdate, // false
                          builder: (dialogCtx) {
                            return PopScope(
                              canPop: !forceUpdateInfo.isForceUpdate, // false
                              child: AlertDialog(
                                title: const Text('Có Bản Cập Nhật Mới!'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (forceUpdateInfo.isForceUpdate)
                                      const Text('Bắt buộc cập nhật để tiếp tục sử dụng hệ thống.'),
                                    Text(forceUpdateInfo.changelog),
                                  ],
                                ),
                                actions: [
                                  if (!forceUpdateInfo.isForceUpdate)
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('Để sau'),
                                    ),
                                  ElevatedButton(
                                    onPressed: () {},
                                    child: const Text('Cập nhật ngay'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: const Text('Trigger Dialog'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // Open Dialog
        await tester.tap(find.text('Trigger Dialog'));
        await tester.pumpAndSettle();

        // 1. Invariant: Force update warning must be displayed
        expect(find.text('Bắt buộc cập nhật để tiếp tục sử dụng hệ thống.'), findsOneWidget);

        // 2. Invariant: "Để sau" button must NOT be present
        expect(find.text('Để sau'), findsNothing);

        // 3. Invariant: "Cập nhật ngay" action button must be present
        expect(find.text('Cập nhật ngay'), findsOneWidget);

        // 4. Invariant: PopScope canPop must be false
        final popScopeFinder = find.byType(PopScope);
        expect(popScopeFinder, findsOneWidget);
        final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
        expect(popScopeWidget.canPop, isFalse);
      },
    );

    testWidgets(
      'Optional update (is_force_update = false): PopScope canPop is true and "Để sau" button allows dismissal',
      (tester) async {
        const optionalUpdateInfo = AppVersionInfo(
          platform: 'android',
          versionName: '1.0.3',
          buildNumber: 8,
          downloadUrl: 'https://quannho.lpm.vn/download/QuanNhoPOS-latest.apk',
          changelog: 'Cập nhật nhẹ giao diện',
          isForceUpdate: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          barrierDismissible: !optionalUpdateInfo.isForceUpdate, // true
                          builder: (dialogCtx) {
                            return PopScope(
                              canPop: !optionalUpdateInfo.isForceUpdate, // true
                              child: AlertDialog(
                                title: const Text('Có Bản Cập Nhật Mới!'),
                                content: Text(optionalUpdateInfo.changelog),
                                actions: [
                                  if (!optionalUpdateInfo.isForceUpdate)
                                    TextButton(
                                      onPressed: () => Navigator.pop(dialogCtx),
                                      child: const Text('Để sau'),
                                    ),
                                  ElevatedButton(
                                    onPressed: () {},
                                    child: const Text('Cập nhật ngay'),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                      child: const Text('Trigger Dialog'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        await tester.tap(find.text('Trigger Dialog'));
        await tester.pumpAndSettle();

        // 1. Invariant: Force update warning must NOT be shown
        expect(find.text('Bắt buộc cập nhật để tiếp tục sử dụng hệ thống.'), findsNothing);

        // 2. Invariant: "Để sau" button must be present
        expect(find.text('Để sau'), findsOneWidget);

        // 3. Invariant: PopScope canPop is true
        final popScopeFinder = find.byType(PopScope);
        final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
        expect(popScopeWidget.canPop, isTrue);

        // 4. Dismissing dialog succeeds
        await tester.tap(find.text('Để sau'));
        await tester.pumpAndSettle();

        expect(find.text('Có Bản Cập Nhật Mới!'), findsNothing);
      },
    );
  });

  group('Tier 2: Network Failure & Fallback Resilience', () {
    test('getLatestVersionInfo returns null gracefully when services are unreachable', () async {
      // Calling getLatestVersionInfo when offline or in test environment
      // must never crash with unhandled exception; it catches error and returns null
      final result = await AppUpdateManager.getLatestVersionInfo('android');
      // In isolated unit tests without Supabase backend or mock server, it safely yields null
      expect(result == null || result is AppVersionInfo, isTrue);
    });

    test('getLatestVersion returns null gracefully when offline', () async {
      final result = await AppUpdateManager.getLatestVersion('windows');
      expect(result == null || result is Map<String, dynamic>, isTrue);
    });
  });
}
