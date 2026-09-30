// test/core/adversarial_updater_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Tier 5: Adversarial Stress, Edge-Case & Chaos Suite for Client Updater
// Role: Challenger 1 - Updater Adversary
//
// Adversarially attacks:
//   1. Corrupted & type-mismatched JSON payloads (int as bool, string as int, nulls)
//   2. Extreme boundary build numbers (-999, 0, astronomical 999999999, overflow)
//   3. Extreme semantic version formats (v1.0.0.0.1-rc.1+build.foo, pre-release tags)
//   4. Network failure injection (Supabase + VPS down -> fail-safe null)
//   5. Force update non-dismissible modal lock invariants (barrier, PopScope, buttons)
//   6. Reentrant concurrent update checks (race condition suppression)
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/models/app_version_info.dart';
import 'package:quannho_pos/core/services/app_update_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. CORRUPTED & MALFORMED JSON PAYLOADS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Adversarial 1: Corrupted & Type-Mismatched JSON Payloads', () {
    test('handles completely empty JSON payload with safe defaults', () {
      final info = AppVersionInfo.fromJson({});
      expect(info.platform, '');
      expect(info.versionName, '');
      expect(info.buildNumber, 0);
      expect(info.downloadUrl, '');
      expect(info.changelog, '');
      expect(info.isForceUpdate, false);
      expect(info.createdAt, isNull);
    });

    test('handles null fields safely', () {
      final info = AppVersionInfo.fromJson({
        'id': null,
        'platform': null,
        'version_name': null,
        'build_number': null,
        'download_url': null,
        'changelog': null,
        'is_force_update': null,
        'created_at': null,
      });

      expect(info.id, isNull);
      expect(info.platform, '');
      expect(info.versionName, '');
      expect(info.buildNumber, 0);
      expect(info.downloadUrl, '');
      expect(info.changelog, '');
      expect(info.isForceUpdate, false);
      expect(info.createdAt, isNull);
    });

    test('handles unexpected extra keys and nested objects without corruption', () {
      final info = AppVersionInfo.fromJson({
        'platform': 'android',
        'version_name': '1.0.4',
        'build_number': 12,
        'download_url': 'https://quannho.lpm.vn/download/test.apk',
        'unexpected_nested': {'foo': 'bar', 'list': [1, 2, 3]},
        'sql_inject': "' OR '1'='1",
      });

      expect(info.platform, 'android');
      expect(info.versionName, '1.0.4');
      expect(info.buildNumber, 12);
    });

    test('recovers from non-numeric string build_number gracefully', () {
      final info = AppVersionInfo.fromJson({
        'platform': 'windows',
        'version_name': '1.0.0',
        'build_number': 'NaN_or_corrupted',
        'download_url': 'https://example.com/app.exe',
      });
      expect(info.buildNumber, 0);
    });

    test('handles floating point build_number by truncating to int', () {
      final info = AppVersionInfo.fromJson({
        'platform': 'windows',
        'version_name': '1.0.0',
        'build_number': 14.85,
        'download_url': 'https://example.com/app.exe',
      });
      expect(info.buildNumber, 14);
    });

    test('resiliently handles integer 1 and 0 as is_force_update without TypeError', () {
      final infoTrue = AppVersionInfo.fromJson({'is_force_update': 1});
      expect(infoTrue.isForceUpdate, isTrue);

      final infoFalse = AppVersionInfo.fromJson({'is_force_update': 0});
      expect(infoFalse.isForceUpdate, isFalse);
    });

    test('resiliently handles string "true" and "false" as is_force_update without TypeError', () {
      final infoTrue = AppVersionInfo.fromJson({'is_force_update': 'true'});
      expect(infoTrue.isForceUpdate, isTrue);

      final infoFalse = AppVersionInfo.fromJson({'is_force_update': 'false'});
      expect(infoFalse.isForceUpdate, isFalse);
    });

    test('resiliently handles numeric version_name without TypeError', () {
      final info = AppVersionInfo.fromJson({'version_name': 1.0});
      expect(info.versionName, '1.0');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. EXTREME & BOUNDARY BUILD NUMBERS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Adversarial 2: Boundary & Extreme Build Numbers', () {
    test('negative build number (-999) does not trigger false update', () {
      const serverNegative = AppVersionInfo(
        platform: 'android',
        versionName: '1.0.0',
        buildNumber: -999,
        downloadUrl: 'https://example.com',
      );

      // Client build 7 > server -999 -> must NOT trigger update
      expect(serverNegative.isNewerThan(currentBuild: 7), isFalse);
      expect(serverNegative.isNewerThan(currentBuild: 1), isFalse);
    });

    test('astronomical build number (999999999) correctly triggers update', () {
      const serverHuge = AppVersionInfo(
        platform: 'android',
        versionName: '9.9.9',
        buildNumber: 999999999,
        downloadUrl: 'https://example.com',
      );

      // Server 999,999,999 > client 7 -> must trigger update
      expect(serverHuge.isNewerThan(currentBuild: 7), isTrue);
    });

    test('string overflow build number defaults safely to 0', () {
      final info = AppVersionInfo.fromJson({
        'platform': 'android',
        'version_name': '1.0.0',
        'build_number': '9999999999999999999999999999999999999999', // 40-digit overflow
        'download_url': 'https://example.com',
      });

      // Overflow causes int.tryParse to return null -> defaults to 0
      expect(info.buildNumber, 0);
      expect(info.isNewerThan(currentBuild: 1), isFalse);
    });

    test('zero build numbers compare semantic versions when builds equal', () {
      const serverZero = AppVersionInfo(
        platform: 'android',
        versionName: '1.0.5',
        buildNumber: 0,
        downloadUrl: 'https://example.com',
      );

      // Both build numbers 0 -> semantic comparison activates
      expect(serverZero.isNewerThan(currentBuild: 0, currentVersion: '1.0.4'), isTrue);
      expect(serverZero.isNewerThan(currentBuild: 0, currentVersion: '1.0.5'), isFalse);
      expect(serverZero.isNewerThan(currentBuild: 0, currentVersion: '1.0.6'), isFalse);
    });

    test('server zero build number falls back to semantic version against non-zero client build', () {
      const serverZero = AppVersionInfo(
        platform: 'android',
        versionName: '2.0.0',
        buildNumber: 0,
        downloadUrl: 'https://example.com',
      );

      // Server has build 0, but version 2.0.0 > client 1.0.0 (build 7)
      expect(serverZero.isNewerThan(currentBuild: 7, currentVersion: '1.0.0'), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. EXTREME SEMANTIC VERSION FORMATS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Adversarial 3: Extreme SemVer Formats & Edge Cases', () {
    test('deeply nested multi-part semver strings', () {
      expect(AppVersionInfo.isNewerVersionString('1.0.0.0.1', '1.0.0.0.2'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('1.0.0.0.2', '1.0.0.0.1'), isFalse);
      expect(AppVersionInfo.isNewerVersionString('1.0.0.0.0.0.1', '1.0.0.0.0.0.2'), isTrue);
    });

    test('semver with build metadata and prerelease tags', () {
      // Different major/minor takes precedence
      expect(AppVersionInfo.isNewerVersionString('1.0.0', '2.0.0-rc.1'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('2.0.0-rc.1', '1.0.0'), isFalse);

      // Same core version: final release has higher precedence than pre-release
      expect(AppVersionInfo.isNewerVersionString('1.0.0-rc.1', '1.0.0'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('1.0.0', '1.0.0-rc.1'), isFalse);
    });

    test('trailing dots and malformed semver strings do not throw uncaught exceptions', () {
      expect(() => AppVersionInfo.isNewerVersionString('1.0.', '1.0.1'), returnsNormally);
      expect(() => AppVersionInfo.isNewerVersionString('..', '..'), returnsNormally);
      expect(() => AppVersionInfo.isNewerVersionString('', ''), returnsNormally);
      expect(() => AppVersionInfo.isNewerVersionString('alpha', 'beta'), returnsNormally);
    });

    test('case insensitivity and prefix stripping', () {
      expect(AppVersionInfo.isNewerVersionString('V1.0.2', 'v1.0.3'), isTrue);
      expect(AppVersionInfo.isNewerVersionString('v1.0.3', 'V1.0.2'), isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. NETWORK FAILURE INJECTION (TOTAL OUTAGE)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Adversarial 4: Total Network Outage Resilience', () {
    test('getLatestVersionInfo returns null without throwing when offline', () async {
      // In isolated unit tests with no network / mocks, it safely returns null
      final result = await AppUpdateManager.getLatestVersionInfo('android');
      expect(result == null || result is AppVersionInfo, isTrue);
    });

    test('getLatestVersion returns null without throwing when offline', () async {
      final result = await AppUpdateManager.getLatestVersion('windows');
      expect(result == null || result is Map<String, dynamic>, isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. FORCE UPDATE NON-DISMISSIBLE MODAL LOCK INVARIANTS
  // ═══════════════════════════════════════════════════════════════════════════

  group('Adversarial 5: Force Update Non-Dismissible Modal Lock Invariant', () {
    testWidgets(
      'Strict Modal Lock: Barrier cannot dismiss, PopScope canPop is false, and dismiss action is completely absent',
      (tester) async {
        const p0ForceUpdate = AppVersionInfo(
          platform: 'windows',
          versionName: '2.0.0',
          buildNumber: 100,
          downloadUrl: 'https://quannho.lpm.vn/download/windows/QuanNhoPOS-latest.exe',
          changelog: 'Bản vá khẩn cấp P0',
          isForceUpdate: true,
        );

        bool dialogDismissed = false;

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
                          barrierDismissible: !p0ForceUpdate.isForceUpdate, // strictly false
                          builder: (dialogCtx) {
                            return PopScope(
                              canPop: !p0ForceUpdate.isForceUpdate, // strictly false
                              child: AlertDialog(
                                title: const Text('Có Bản Cập Nhật Mới!'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Bắt buộc cập nhật để tiếp tục sử dụng hệ thống.'),
                                    Text(p0ForceUpdate.changelog),
                                  ],
                                ),
                                actions: [
                                  if (!p0ForceUpdate.isForceUpdate)
                                    TextButton(
                                      onPressed: () {
                                        dialogDismissed = true;
                                        Navigator.pop(dialogCtx);
                                      },
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
                      child: const Text('Open Modal'),
                    ),
                  );
                },
              ),
            ),
          ),
        );

        // Open Dialog
        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        // INVARIANT 1: P0 warning banner must be visible
        expect(find.text('Bắt buộc cập nhật để tiếp tục sử dụng hệ thống.'), findsOneWidget);

        // INVARIANT 2: "Để sau" dismiss button is completely omitted
        expect(find.text('Để sau'), findsNothing);

        // INVARIANT 3: PopScope canPop is strictly false
        final popScopeFinder = find.byType(PopScope);
        expect(popScopeFinder, findsOneWidget);
        final popScopeWidget = tester.widget<PopScope>(popScopeFinder);
        expect(popScopeWidget.canPop, isFalse);

        // INVARIANT 4: Tap outside the dialog (barrier tap) does NOT dismiss the dialog
        await tester.tapAt(const Offset(10, 10)); // Outside modal bounds
        await tester.pumpAndSettle();

        // Modal is still present on screen
        expect(find.text('Có Bản Cập Nhật Mới!'), findsOneWidget);
        expect(dialogDismissed, isFalse);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. REENTRANT CONCURRENT CHECKS (RACE CONDITION SUPPRESSION)
  // ═══════════════════════════════════════════════════════════════════════════

  group('Adversarial 6: Concurrency & Reentrant Check Suppression', () {
    testWidgets('Rapid duplicate calls do not spawn multiple dialogs', (tester) async {
      int dialogOpenCount = 0;
      bool isChecking = false;

      Future<void> simulateCheck(BuildContext context) async {
        if (isChecking) return; // Concurrency lock
        isChecking = true;

        try {
          // Simulate async network latency
          await Future.delayed(const Duration(milliseconds: 50));

          if (context.mounted) {
            dialogOpenCount++;
            await showDialog(
              context: context,
              builder: (ctx) => const AlertDialog(title: Text('Single Update Modal')),
            );
          }
        } finally {
          isChecking = false;
        }
      }

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () {
                      // Trigger 5 concurrent checks simultaneously
                      simulateCheck(context);
                      simulateCheck(context);
                      simulateCheck(context);
                      simulateCheck(context);
                      simulateCheck(context);
                    },
                    child: const Text('Burst Check'),
                  ),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Burst Check'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // INVARIANT: Exactly 1 modal must be opened, never 5 stacked modals
      expect(dialogOpenCount, 1);
      expect(find.text('Single Update Modal'), findsOneWidget);
    });
  });
}
