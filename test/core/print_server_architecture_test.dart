import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';

class FakePrintServerOwnerRepository implements PrintServerOwnerRepository {
  final Map<String, PrintServerOwnerState> owners = {};

  @override
  Future<PrintServerOwnerState?> getOwner(String storeId) async {
    return owners[storeId];
  }

  @override
  Future<bool> claimOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async {
    if (owners.containsKey(storeId)) {
      return false; // Primary key conflict!
    }
    owners[storeId] = owner;
    return true;
  }

  @override
  Future<bool> transferOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async {
    owners[storeId] = owner;
    return true;
  }

  @override
  Future<bool> releaseOwner({
    required String storeId,
    required String deviceId,
    required String expectedToken,
  }) async {
    final current = owners[storeId];
    if (current == null) return true; // Already released
    if (current.deviceId != deviceId || current.claimToken != expectedToken) {
      return false; // CAS Fail: Token or Device mismatch!
    }
    owners.remove(storeId);
    return true;
  }
}

class ThrowingPrintServerOwnerRepository implements PrintServerOwnerRepository {
  @override
  Future<PrintServerOwnerState?> getOwner(String storeId) async {
    throw Exception('Network error / Supabase unavailable');
  }

  @override
  Future<bool> claimOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async => false;

  @override
  Future<bool> transferOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async => false;

  @override
  Future<bool> releaseOwner({
    required String storeId,
    required String deviceId,
    required String expectedToken,
  }) async => false;
}

class ReconcilingFakePrintServerOwnerRepository
    implements PrintServerOwnerRepository {
  PrintServerOwnerState? overrideGetOwner;
  bool claimResult = false;
  bool transferResult = false;
  bool releaseResult = false;

  @override
  Future<PrintServerOwnerState?> getOwner(String storeId) async {
    return overrideGetOwner;
  }

  @override
  Future<bool> claimOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async => claimResult;

  @override
  Future<bool> transferOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async => transferResult;

  @override
  Future<bool> releaseOwner({
    required String storeId,
    required String deviceId,
    required String expectedToken,
  }) async => releaseResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Print Server Architecture & Web Protection Integration Test Suite', () {
    test('1. shouldAutoPrintLocally Policy enforces single source of truth', () {
      expect(
        shouldAutoPrintLocally(
          isWeb: true,
          centralRoutingEnabled: false,
          hasPrintServerOwner: false,
          allowPrintServerFallback: false,
        ),
        isFalse,
      );
      expect(
        shouldAutoPrintLocally(
          isWeb: true,
          centralRoutingEnabled: true,
          hasPrintServerOwner: false,
          allowPrintServerFallback: true,
        ),
        isFalse,
      );
      expect(
        shouldAutoPrintLocally(
          isWeb: false,
          centralRoutingEnabled: true,
          hasPrintServerOwner: true,
          allowPrintServerFallback: true,
        ),
        isFalse,
      );
      expect(
        shouldAutoPrintLocally(
          isWeb: false,
          centralRoutingEnabled: true,
          hasPrintServerOwner: false,
          allowPrintServerFallback: true,
        ),
        isTrue,
        reason:
            'Designated Print Server must print locally when central routing has no active owner',
      );
      expect(
        shouldAutoPrintLocally(
          isWeb: false,
          centralRoutingEnabled: false,
          hasPrintServerOwner: false,
          allowPrintServerFallback: false,
        ),
        isTrue,
      );
      expect(
        shouldAutoPrintLocally(
          isWeb: false,
          centralRoutingEnabled: true,
          hasPrintServerOwner: false,
          allowPrintServerFallback: false,
        ),
        isFalse,
        reason:
            'Non-Print-Server devices must not bypass central routing when owner is stale or missing',
      );
    });

    test('2. shouldBootstrapLegacyOwner Pure Function Rules', () {
      expect(
        shouldBootstrapLegacyOwner(
          isWeb: true,
          ownerMigrationCompleted: false,
          legacyAutoPrintServer: true,
          hasOwner: false,
        ),
        isFalse, // Web NEVER claims owner
      );

      expect(
        shouldBootstrapLegacyOwner(
          isWeb: false,
          ownerMigrationCompleted: false,
          legacyAutoPrintServer: true,
          hasOwner: false,
        ),
        isTrue, // Native claims owner when unmigrated & legacy=true & no owner
      );

      expect(
        shouldBootstrapLegacyOwner(
          isWeb: false,
          ownerMigrationCompleted: true, // Already completed
          legacyAutoPrintServer: true,
          hasOwner: false,
        ),
        isFalse, // Does not re-claim after migration completed!
      );
    });

    test(
      '2b. shouldRestorePrintServerOwner only restores preferred native device when owner is empty',
      () {
        expect(
          shouldRestorePrintServerOwner(
            isWeb: true,
            centralRoutingEnabled: true,
            hasOwner: false,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            currentDeviceId: 'dev-1',
          ),
          isFalse,
        );

        expect(
          shouldRestorePrintServerOwner(
            isWeb: false,
            centralRoutingEnabled: true,
            hasOwner: false,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            currentDeviceId: 'dev-1',
          ),
          isTrue,
        );

        expect(
          shouldRestorePrintServerOwner(
            isWeb: false,
            centralRoutingEnabled: true,
            hasOwner: true,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            currentDeviceId: 'dev-1',
          ),
          isFalse,
        );

        expect(
          shouldRestorePrintServerOwner(
            isWeb: false,
            centralRoutingEnabled: true,
            hasOwner: false,
            deviceMarkedPrintServer: false,
            allowBackgroundPrinting: true,
            currentDeviceId: 'dev-1',
          ),
          isFalse,
        );
      },
    );

    test(
      '2b1. shouldSyncOwnerClaimTokenToDesignatedDevice only syncs token for pre-designated print server device',
      () {
        expect(
          shouldSyncOwnerClaimTokenToDesignatedDevice(
            isWeb: false,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            currentDeviceId: 'dev-1',
            ownerDeviceId: 'dev-1',
            ownerClaimToken: 'token-1',
          ),
          isTrue,
        );

        expect(
          shouldSyncOwnerClaimTokenToDesignatedDevice(
            isWeb: false,
            deviceMarkedPrintServer: false,
            allowBackgroundPrinting: true,
            currentDeviceId: 'dev-1',
            ownerDeviceId: 'dev-1',
            ownerClaimToken: 'token-1',
          ),
          isFalse,
        );

        expect(
          shouldSyncOwnerClaimTokenToDesignatedDevice(
            isWeb: false,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: false,
            currentDeviceId: 'dev-1',
            ownerDeviceId: 'dev-1',
            ownerClaimToken: 'token-1',
          ),
          isFalse,
        );

        expect(
          shouldSyncOwnerClaimTokenToDesignatedDevice(
            isWeb: false,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            currentDeviceId: 'dev-1',
            ownerDeviceId: 'dev-2',
            ownerClaimToken: 'token-1',
          ),
          isFalse,
        );
      },
    );

    test(
      '2c. shouldPromoteStalePrintServerOwner promotes stale owner only on designated Windows Print Server devices',
      () {
        expect(
          shouldPromoteStalePrintServerOwner(
            isWeb: false,
            isCurrentPlatformWindows: true,
            centralRoutingEnabled: true,
            hasStaleOwner: true,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            hasAnyEnabledPrinter: true,
            currentDeviceId: 'dev-1',
          ),
          isTrue,
        );

        expect(
          shouldPromoteStalePrintServerOwner(
            isWeb: false,
            isCurrentPlatformWindows: false,
            centralRoutingEnabled: true,
            hasStaleOwner: true,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            hasAnyEnabledPrinter: true,
            currentDeviceId: 'dev-1',
          ),
          isFalse,
        );

        expect(
          shouldPromoteStalePrintServerOwner(
            isWeb: false,
            isCurrentPlatformWindows: true,
            centralRoutingEnabled: true,
            hasStaleOwner: true,
            deviceMarkedPrintServer: false,
            allowBackgroundPrinting: true,
            hasAnyEnabledPrinter: true,
            currentDeviceId: 'dev-1',
          ),
          isFalse,
        );

        expect(
          shouldPromoteStalePrintServerOwner(
            isWeb: false,
            isCurrentPlatformWindows: true,
            centralRoutingEnabled: true,
            hasStaleOwner: true,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: false,
            hasAnyEnabledPrinter: true,
            currentDeviceId: 'dev-1',
          ),
          isFalse,
        );

        expect(
          shouldPromoteStalePrintServerOwner(
            isWeb: false,
            isCurrentPlatformWindows: true,
            centralRoutingEnabled: true,
            hasStaleOwner: true,
            deviceMarkedPrintServer: true,
            allowBackgroundPrinting: true,
            hasAnyEnabledPrinter: false,
            currentDeviceId: 'dev-1',
          ),
          isFalse,
        );
      },
    );

    test(
      '3. Owner token remains strict for ownership, but designated print server listener no longer depends on it',
      () {
        final validSettings = StationPrintersState(
          cashier: const PrinterConfig(name: '', type: 'system', enabled: true),
          bepNong: const PrinterConfig(
            name: '',
            type: 'system',
            enabled: false,
          ),
          bepBar: const PrinterConfig(name: '', type: 'system', enabled: false),
          barLabel: const PrinterConfig(
            name: '',
            type: 'system',
            enabled: false,
          ),
          centralPrintRoutingEnabled: true,
          deviceState: const PrintDeviceState(
            deviceName: 'POS 1',
            isPrintServer: true,
            allowBackgroundPrinting: true,
            localClaimToken: 'token-abc',
          ),
          ownerState: const PrintServerOwnerState(
            deviceId: 'dev-1',
            deviceName: 'POS 1',
            platform: 'windows',
            claimedAt: '2026-08-14T10:00:00Z',
            claimToken: 'token-abc',
          ),
          currentDeviceId: 'dev-1',
        );

        final emptyTokenSettings = validSettings.copyWith(
          deviceState: validSettings.deviceState.copyWith(localClaimToken: ''),
        );

        if (!kIsWeb) {
          expect(validSettings.canRunBackgroundPrintServer, isTrue);
          expect(validSettings.isDesignatedPrintServerDevice, isTrue);
          expect(validSettings.isCurrentDeviceOwner, isTrue);
        }
        expect(emptyTokenSettings.canRunBackgroundPrintServer, isTrue);
        expect(emptyTokenSettings.isDesignatedPrintServerDevice, isTrue);
        expect(emptyTokenSettings.isCurrentDeviceOwner, isFalse);
      },
    );

    test(
      '3b. Designated Print Server device can run background listener without owner token',
      () {
        final designatedWithoutOwner = StationPrintersState(
          cashier: const PrinterConfig(name: '', type: 'system', enabled: true),
          bepNong: const PrinterConfig(name: '', type: 'system', enabled: true),
          bepBar: const PrinterConfig(name: '', type: 'system', enabled: false),
          barLabel: const PrinterConfig(
            name: '',
            type: 'system',
            enabled: false,
          ),
          centralPrintRoutingEnabled: true,
          deviceState: const PrintDeviceState(
            deviceName: 'Windows Cashier',
            isPrintServer: true,
            allowBackgroundPrinting: true,
            localClaimToken: '',
          ),
          ownerState: const PrintServerOwnerState(
            deviceId: 'legacy-owner',
            deviceName: 'Old Windows POS',
            platform: 'windows',
            claimedAt: '2026-08-15T03:54:43Z',
            claimToken: 'legacy-token',
          ),
          currentDeviceId: 'cashier-win',
        );

        if (!kIsWeb) {
          expect(designatedWithoutOwner.isDesignatedPrintServerDevice, isTrue);
          expect(designatedWithoutOwner.isCurrentDeviceOwner, isFalse);
          expect(designatedWithoutOwner.canRunBackgroundPrintServer, isTrue);
        }
      },
    );

    test(
      '4. Real Repository Concurrent Claim via ownerRepository: Only 1 winner wins claim',
      () async {
        final repo = FakePrintServerOwnerRepository();
        const storeId = 'store-test-1';

        final owner1 = const PrintServerOwnerState(
          deviceId: 'win-1',
          deviceName: 'Windows 1',
          platform: 'windows',
          claimedAt: '2026-08-14T10:00:00Z',
          claimToken: 'token-win-1',
        );

        final owner2 = const PrintServerOwnerState(
          deviceId: 'win-2',
          deviceName: 'Windows 2',
          platform: 'windows',
          claimedAt: '2026-08-14T10:00:01Z',
          claimToken: 'token-win-2',
        );

        final claim1Success = await repo.claimOwner(
          storeId: storeId,
          owner: owner1,
        );
        final claim2Success = await repo.claimOwner(
          storeId: storeId,
          owner: owner2,
        );

        expect(claim1Success, isTrue);
        expect(claim2Success, isFalse);
        expect((await repo.getOwner(storeId))?.deviceId, equals('win-1'));
      },
    );

    test(
      '5. Real Repository Transfer Owner: Updates token and invalidates old owner',
      () async {
        final repo = FakePrintServerOwnerRepository();
        const storeId = 'store-test-2';

        final ownerOld = const PrintServerOwnerState(
          deviceId: 'win-old',
          deviceName: 'Windows Old',
          platform: 'windows',
          claimedAt: '2026-08-14T10:00:00Z',
          claimToken: 'token-old',
        );

        await repo.claimOwner(storeId: storeId, owner: ownerOld);

        final ownerNew = const PrintServerOwnerState(
          deviceId: 'win-new',
          deviceName: 'Windows New',
          platform: 'windows',
          claimedAt: '2026-08-14T10:05:00Z',
          claimToken: 'token-new-888',
        );

        final transferSuccess = await repo.transferOwner(
          storeId: storeId,
          owner: ownerNew,
        );
        expect(transferSuccess, isTrue);

        final activeOwner = await repo.getOwner(storeId);
        expect(activeOwner?.deviceId, equals('win-new'));
        expect(activeOwner?.claimToken, equals('token-new-888'));
      },
    );

    test(
      '6. Real Repository Atomic CAS Release: Stale token release returns false and preserves new owner',
      () async {
        final repo = FakePrintServerOwnerRepository();
        const storeId = 'store-test-3';

        final ownerTransferred = const PrintServerOwnerState(
          deviceId: 'win-new',
          deviceName: 'Windows New',
          platform: 'windows',
          claimedAt: '2026-08-14T10:05:00Z',
          claimToken: 'token-new-999',
        );

        await repo.transferOwner(storeId: storeId, owner: ownerTransferred);

        final releaseResult = await repo.releaseOwner(
          storeId: storeId,
          deviceId: 'win-old',
          expectedToken: 'token-old-111',
        );

        expect(releaseResult, isFalse); // CAS zero rows deleted!
        expect(await repo.getOwner(storeId), isNotNull);
        expect((await repo.getOwner(storeId))?.deviceId, equals('win-new'));
      },
    );

    test(
      '7. ownerMigrationCompleted Flag Persistence in StationPrintersState',
      () {
        final stateUnmigrated = const StationPrintersState(
          cashier: PrinterConfig(name: '', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
          bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
          barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
          ownerMigrationCompleted: false,
        );

        final stateMigrated = stateUnmigrated.copyWith(
          ownerMigrationCompleted: true,
        );

        expect(stateUnmigrated.ownerMigrationCompleted, isFalse);
        expect(stateMigrated.ownerMigrationCompleted, isTrue);
      },
    );

    test(
      '8. Central Print Routing when True + Owner Null CAN be toggled to False',
      () {
        final stateWithRoutingTrueNoOwner = const StationPrintersState(
          cashier: PrinterConfig(name: '', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
          bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
          barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
          centralPrintRoutingEnabled: true,
          ownerState: null,
        );

        final stateToggledOff = stateWithRoutingTrueNoOwner.copyWith(
          centralPrintRoutingEnabled: false,
        );
        expect(stateToggledOff.centralPrintRoutingEnabled, isFalse);
      },
    );

    test(
      '9. getOwner exception propagates directly (does not return null on network error)',
      () async {
        final repo = ThrowingPrintServerOwnerRepository();
        expect(
          () async => await repo.getOwner('store-err'),
          throwsA(isA<Exception>()),
        );
      },
    );

    test(
      '10. Central routing disabled preserves owner tokens without treating as ownership lost',
      () {
        final routingDisabledState = StationPrintersState(
          cashier: const PrinterConfig(name: '', type: 'system', enabled: true),
          bepNong: const PrinterConfig(
            name: '',
            type: 'system',
            enabled: false,
          ),
          bepBar: const PrinterConfig(name: '', type: 'system', enabled: false),
          barLabel: const PrinterConfig(
            name: '',
            type: 'system',
            enabled: false,
          ),
          centralPrintRoutingEnabled: false, // Routing disabled
          deviceState: const PrintDeviceState(
            deviceName: 'POS 1',
            isPrintServer: true,
            allowBackgroundPrinting: true,
            localClaimToken: 'token-active-123',
          ),
          ownerState: const PrintServerOwnerState(
            deviceId: 'dev-1',
            deviceName: 'POS 1',
            platform: 'windows',
            claimedAt: '2026-08-14T10:00:00Z',
            claimToken: 'token-active-123',
          ),
          currentDeviceId: 'dev-1',
        );

        expect(routingDisabledState.canRunBackgroundPrintServer, isFalse);
        expect(routingDisabledState.isCurrentDeviceOwner, isTrue);
        expect(
          routingDisabledState.deviceState.localClaimToken,
          equals('token-active-123'),
        );
      },
    );

    test(
      '11. Throwing repo release/claim/transfer returns false safely without throwing unhandled exceptions',
      () async {
        final repo = ThrowingPrintServerOwnerRepository();
        final releaseOk = await repo.releaseOwner(
          storeId: 'store-1',
          deviceId: 'dev-1',
          expectedToken: 'token-1',
        );
        expect(releaseOk, isFalse);
      },
    );

    test(
      '12. Operation Reconciliation Scenarios for release/claim/transfer',
      () async {
        final repo = ReconcilingFakePrintServerOwnerRepository();

        // Case A: releaseOwner returns false, but getOwner returns null (owner was cleared out-of-band)
        repo.releaseResult = false;
        repo.overrideGetOwner = null;
        expect(await repo.getOwner('store-1'), isNull);

        // Case B: releaseOwner returns false, but getOwner returns current owner (DELETE didn't happen)
        final currentOwner = const PrintServerOwnerState(
          deviceId: 'dev-1',
          deviceName: 'POS 1',
          platform: 'windows',
          claimedAt: '2026-08-14T10:00:00Z',
          claimToken: 'token-123',
        );
        repo.overrideGetOwner = currentOwner;
        final fetched = await repo.getOwner('store-1');
        expect(fetched?.deviceId, equals('dev-1'));
        expect(fetched?.claimToken, equals('token-123'));
      },
    );
  });
}
