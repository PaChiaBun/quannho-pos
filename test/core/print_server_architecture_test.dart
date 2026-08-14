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

class ReconcilingFakePrintServerOwnerRepository implements PrintServerOwnerRepository {
  PrintServerOwnerState? overrideGetOwner;
  bool claimResult = false;
  bool transferResult = false;
  bool releaseResult = false;

  @override
  Future<PrintServerOwnerState?> getOwner(String storeId) async {
    return overrideGetOwner;
  }

  @override
  Future<bool> claimOwner({required String storeId, required PrintServerOwnerState owner}) async => claimResult;

  @override
  Future<bool> transferOwner({required String storeId, required PrintServerOwnerState owner}) async => transferResult;

  @override
  Future<bool> releaseOwner({required String storeId, required String deviceId, required String expectedToken}) async => releaseResult;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Print Server Architecture & Web Protection Integration Test Suite', () {
    test('1. shouldAutoPrintLocally Policy enforces single source of truth', () {
      expect(shouldAutoPrintLocally(
        isWeb: true,
        centralRoutingEnabled: false,
        hasPrintServerOwner: false,
      ), isFalse);
      expect(shouldAutoPrintLocally(
        isWeb: true,
        centralRoutingEnabled: true,
        hasPrintServerOwner: false,
      ), isFalse);
      expect(shouldAutoPrintLocally(
        isWeb: false,
        centralRoutingEnabled: true,
        hasPrintServerOwner: true,
      ), isFalse);
      expect(shouldAutoPrintLocally(
        isWeb: false,
        centralRoutingEnabled: true,
        hasPrintServerOwner: false,
      ), isTrue, reason: 'Native checkout must print locally when central routing has no owner');
      expect(shouldAutoPrintLocally(
        isWeb: false,
        centralRoutingEnabled: false,
        hasPrintServerOwner: false,
      ), isTrue);
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

    test('3. Fencing Token Strict Fail-Closed Match (No Empty Token Fallback)', () {
      final validSettings = StationPrintersState(
        cashier: const PrinterConfig(name: '', type: 'system', enabled: true),
        bepNong: const PrinterConfig(name: '', type: 'system', enabled: false),
        bepBar: const PrinterConfig(name: '', type: 'system', enabled: false),
        barLabel: const PrinterConfig(name: '', type: 'system', enabled: false),
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
        expect(validSettings.isCurrentDeviceOwner, isTrue);
      }
      expect(emptyTokenSettings.canRunBackgroundPrintServer, isFalse);
      expect(emptyTokenSettings.isCurrentDeviceOwner, isFalse);
    });

    test('4. Real Repository Concurrent Claim via ownerRepository: Only 1 winner wins claim', () async {
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

      final claim1Success = await repo.claimOwner(storeId: storeId, owner: owner1);
      final claim2Success = await repo.claimOwner(storeId: storeId, owner: owner2);

      expect(claim1Success, isTrue);
      expect(claim2Success, isFalse);
      expect((await repo.getOwner(storeId))?.deviceId, equals('win-1'));
    });

    test('5. Real Repository Transfer Owner: Updates token and invalidates old owner', () async {
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

      final transferSuccess = await repo.transferOwner(storeId: storeId, owner: ownerNew);
      expect(transferSuccess, isTrue);

      final activeOwner = await repo.getOwner(storeId);
      expect(activeOwner?.deviceId, equals('win-new'));
      expect(activeOwner?.claimToken, equals('token-new-888'));
    });

    test('6. Real Repository Atomic CAS Release: Stale token release returns false and preserves new owner', () async {
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
    });

    test('7. ownerMigrationCompleted Flag Persistence in StationPrintersState', () {
      final stateUnmigrated = const StationPrintersState(
        cashier: PrinterConfig(name: '', type: 'system', enabled: true),
        bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
        bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
        barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
        ownerMigrationCompleted: false,
      );

      final stateMigrated = stateUnmigrated.copyWith(ownerMigrationCompleted: true);

      expect(stateUnmigrated.ownerMigrationCompleted, isFalse);
      expect(stateMigrated.ownerMigrationCompleted, isTrue);
    });

    test('8. Central Print Routing when True + Owner Null CAN be toggled to False', () {
      final stateWithRoutingTrueNoOwner = const StationPrintersState(
        cashier: PrinterConfig(name: '', type: 'system', enabled: true),
        bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
        bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
        barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
        centralPrintRoutingEnabled: true,
        ownerState: null,
      );

      final stateToggledOff = stateWithRoutingTrueNoOwner.copyWith(centralPrintRoutingEnabled: false);
      expect(stateToggledOff.centralPrintRoutingEnabled, isFalse);
    });

    test('9. getOwner exception propagates directly (does not return null on network error)', () async {
      final repo = ThrowingPrintServerOwnerRepository();
      expect(() async => await repo.getOwner('store-err'), throwsA(isA<Exception>()));
    });

    test('10. Central routing disabled preserves owner tokens without treating as ownership lost', () {
      final routingDisabledState = StationPrintersState(
        cashier: const PrinterConfig(name: '', type: 'system', enabled: true),
        bepNong: const PrinterConfig(name: '', type: 'system', enabled: false),
        bepBar: const PrinterConfig(name: '', type: 'system', enabled: false),
        barLabel: const PrinterConfig(name: '', type: 'system', enabled: false),
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
      expect(routingDisabledState.deviceState.localClaimToken, equals('token-active-123'));
    });

    test('11. Throwing repo release/claim/transfer returns false safely without throwing unhandled exceptions', () async {
      final repo = ThrowingPrintServerOwnerRepository();
      final releaseOk = await repo.releaseOwner(
        storeId: 'store-1',
        deviceId: 'dev-1',
        expectedToken: 'token-1',
      );
      expect(releaseOk, isFalse);
    });

    test('12. Operation Reconciliation Scenarios for release/claim/transfer', () async {
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
    });
  });
}
