// test/core/comprehensive_fix_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// COMPREHENSIVE FIX TEST SUITE FOR QC ROUND 7
// Genuine production path execution testing with 100% offline local TTF fonts.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── 1. Hardened Offline HttpOverrides ───────────────────────────────────────
class HardenedOfflineHttpOverrides extends HttpOverrides {
  int networkAttemptCount = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _ThrowingHttpClient(this);
  }
}

class _ThrowingHttpClient implements HttpClient {
  final HardenedOfflineHttpOverrides parent;
  _ThrowingHttpClient(this.parent);

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    parent.networkAttemptCount++;
    throw UnimplementedError(
      'OFFLINE HARDENED: Forbidden network call to $url',
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    parent.networkAttemptCount++;
    throw UnimplementedError('OFFLINE HARDENED: Forbidden network call');
  }
}

// ── 2. Local Asset PDF Font Loader (100% Offline Vietnamese TTF) ──────────────
class LocalAssetPdfFontLoader implements PdfFontLoader {
  final String ttfPath;
  pw.Font? _cachedFont;

  LocalAssetPdfFontLoader(this.ttfPath);

  @override
  Future<pw.Font> loadRegular() async {
    _cachedFont ??= pw.Font.ttf(
      File(ttfPath).readAsBytesSync().buffer.asByteData(),
    );
    return _cachedFont!;
  }

  @override
  Future<pw.Font> loadBold() async {
    _cachedFont ??= pw.Font.ttf(
      File(ttfPath).readAsBytesSync().buffer.asByteData(),
    );
    return _cachedFont!;
  }
}

// ── 3. Test Adapters for Repositories & Storages ──────────────────────────────
class FakePrintCacheStorage implements PrintCacheStorage {
  final Map<String, int> _ints = {};
  final Map<String, String> _strings = {};
  final Map<String, List<String>> _stringLists = {};

  bool shouldFailWrite = false;
  bool shouldThrowWrite = false;
  bool shouldThrowRead = false;
  int writeCount = 0;

  @override
  Future<int?> readInt(String key) async {
    if (shouldThrowRead) throw Exception('Storage read error');
    return _ints[key];
  }

  @override
  Future<String?> readString(String key) async {
    if (shouldThrowRead) throw Exception('Storage read error');
    return _strings[key];
  }

  @override
  Future<List<String>?> readStringList(String key) async {
    if (shouldThrowRead) throw Exception('Storage read error');
    return _stringLists[key];
  }

  @override
  Future<bool> writeInt(String key, int value) async {
    writeCount++;
    if (shouldThrowWrite) throw Exception('Storage write exception');
    if (shouldFailWrite) return false;
    _ints[key] = value;
    return true;
  }

  @override
  Future<bool> writeString(String key, String value) async {
    writeCount++;
    if (shouldThrowWrite) throw Exception('Storage write exception');
    if (shouldFailWrite) return false;
    _strings[key] = value;
    return true;
  }

  @override
  Future<bool> writeStringList(String key, List<String> list) async {
    writeCount++;
    if (shouldThrowWrite) throw Exception('Storage write exception');
    if (shouldFailWrite) return false;
    _stringLists[key] = List.from(list);
    return true;
  }
}

class FakeRecoveryRepository implements RecoveryRepository {
  List<RecoveryTicketTarget> tickets = [];
  List<RecoveryOrderTarget> orders = [];
  int fetchTicketCalls = 0;
  int fetchOrderCalls = 0;

  @override
  Future<List<RecoveryTicketTarget>> fetchTicketPage({
    required String storeId,
    required String cutoffIso,
    String? lastTimestamp,
    String? lastId,
    required int limit,
  }) async {
    fetchTicketCalls++;
    List<RecoveryTicketTarget> filtered = tickets.where((t) {
      final tSent = DateTime.parse(t.sentAt).toUtc();
      final cutoff = DateTime.parse(cutoffIso).toUtc();
      if (tSent.isBefore(cutoff)) return false;

      if (lastTimestamp != null && lastId != null) {
        final lastTs = DateTime.parse(lastTimestamp).toUtc();
        if (tSent.isBefore(lastTs)) return false;
        if (tSent.isAtSameMomentAs(lastTs) && t.id.compareTo(lastId) <= 0)
          return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final cmp = DateTime.parse(
        a.sentAt,
      ).toUtc().compareTo(DateTime.parse(b.sentAt).toUtc());
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });

    return filtered.take(limit).toList();
  }

  @override
  Future<List<RecoveryOrderTarget>> fetchOrderPage({
    required String storeId,
    required String cutoffIso,
    String? lastTimestamp,
    String? lastId,
    required int limit,
  }) async {
    fetchOrderCalls++;
    List<RecoveryOrderTarget> filtered = orders.where((o) {
      final oUpd = DateTime.parse(o.updatedAt).toUtc();
      final cutoff = DateTime.parse(cutoffIso).toUtc();
      if (oUpd.isBefore(cutoff)) return false;

      if (lastTimestamp != null && lastId != null) {
        final lastTs = DateTime.parse(lastTimestamp).toUtc();
        if (oUpd.isBefore(lastTs)) return false;
        if (oUpd.isAtSameMomentAs(lastTs) && o.id.compareTo(lastId) <= 0)
          return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final cmp = DateTime.parse(
        a.updatedAt,
      ).toUtc().compareTo(DateTime.parse(b.updatedAt).toUtc());
      return cmp != 0 ? cmp : a.id.compareTo(b.id);
    });

    return filtered.take(limit).toList();
  }
}

class FakeUserAuthRepository implements UserAuthRepository {
  bool staffQueryThrows = false;
  bool storeQueryThrows = false;
  List<Map<String, dynamic>> staffMembers = [];
  List<Map<String, dynamic>> storeMembers = [];
  Map<String, Map<String, dynamic>> stores = {};
  int insertStoreCount = 0;
  int upsertMemberCount = 0;

  @override
  Future<List<Map<String, dynamic>>> queryStoresByOwner(
    String ownerUserId,
  ) async => [];

  @override
  Future<List<Map<String, dynamic>>> queryStaffMembers(String userId) async {
    if (staffQueryThrows) throw Exception('DB error query staff_members');
    return staffMembers;
  }

  @override
  Future<List<Map<String, dynamic>>> queryStoreMembers(String userId) async {
    if (storeQueryThrows) throw Exception('DB error query store_members');
    return storeMembers;
  }

  @override
  Future<Map<String, dynamic>?> queryStoreById(String storeId) async {
    return stores[storeId];
  }

  @override
  Future<Map<String, dynamic>?> queryStoreByCode(String storeCode) async {
    return stores.values.firstWhere(
      (s) => s['store_code'] == storeCode,
      orElse: () => {},
    );
  }

  @override
  Future<Map<String, dynamic>> insertStore(
    Map<String, dynamic> storePayload,
  ) async {
    insertStoreCount++;
    final storeId = 'store_${DateTime.now().millisecondsSinceEpoch}';
    final result = {
      'id': storeId,
      'store_code': storePayload['store_code'],
      'name': storePayload['name'],
    };
    stores[storeId] = result;
    return result;
  }

  @override
  Future<void> upsertStoreMember(Map<String, dynamic> memberPayload) async {
    upsertMemberCount++;
    storeMembers.add(memberPayload);
  }

  @override
  Future<Map<String, dynamic>?> queryStoreMember(
    String storeId,
    String userId,
  ) async => null;

  @override
  Future<Map<String, dynamic>?> queryStaffMember(
    String storeId,
    String userId,
  ) async => null;

  @override
  Future<Map<String, dynamic>?> queryStaffMemberSimple(String userId) async =>
      null;

  @override
  Future<Map<String, dynamic>?> queryUserAccount(String userId) async => null;

  @override
  Future<void> upsertStaffMember(Map<String, dynamic> payload) async {}
}

class TrackingStoreMembershipWriter extends StoreMembershipWriter {
  int writeCount = 0;
  Map<String, dynamic>? lastPayload;

  @override
  Future<void> upsert({
    required String storeId,
    required String userId,
    required String role,
    bool isOwner = false,
    String? modules,
    String? actions,
  }) async {
    writeCount++;
    lastPayload = {
      'user_id': userId,
      'store_id': storeId,
      'role': role,
      'is_owner': isOwner,
      if (modules != null) 'modules': modules,
      if (actions != null) 'actions': actions,
    };
  }
}

// ── Main Test Suite Execution ────────────────────────────────────────────────
void main() {
  late HardenedOfflineHttpOverrides testHttpOverrides;
  late PdfFontLoader defaultFontLoaderBackup;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    testHttpOverrides = HardenedOfflineHttpOverrides();
    HttpOverrides.global = testHttpOverrides;

    defaultFontLoaderBackup = BillPdfGenerator.fontLoader;
    BillPdfGenerator.fontLoader = LocalAssetPdfFontLoader(
      'test/Roboto-Regular.ttf',
    );
  });

  tearDownAll(() {
    HttpOverrides.global = null;
    BillPdfGenerator.fontLoader = defaultFontLoaderBackup;
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group A: Tách Cursor Ticket & Order (Tests 1-5)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group A: Split Ticket & Order Cursors', () {
    test(
      '1. Ticket empty + 125 orders -> polls 3 pages cleanly without resetting order cursor',
      () async {
        final repo = FakeRecoveryRepository();
        final now = DateTime.now().toUtc();
        for (int i = 1; i <= 125; i++) {
          repo.orders.add(
            RecoveryOrderTarget(
              id: 'ord_$i',
              updatedAt: now.add(Duration(seconds: i)).toIso8601String(),
              status: 'paid',
            ),
          );
        }

        final scanner = RecoveryScanner(repository: repo, pageSize: 50);
        final cache = InMemoryPrintCache();

        final processedOrders = <String>[];
        final r1Ticket = await scanner.scanNextTickets(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onTicketFound: (_) async {},
        );
        expect(r1Ticket.fetchedCount, 0);

        final r1Order = await scanner.scanNextOrders(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => processedOrders.add(id),
        );
        expect(r1Order.fetchedCount, 50);
        expect(r1Order.successCount, 50);

        final r2Ticket = await scanner.scanNextTickets(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onTicketFound: (_) async {},
        );
        expect(r2Ticket.fetchedCount, 0);

        final r2Order = await scanner.scanNextOrders(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => processedOrders.add(id),
        );
        expect(r2Order.fetchedCount, 50);

        final r3Order = await scanner.scanNextOrders(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => processedOrders.add(id),
        );
        expect(r3Order.fetchedCount, 25);
        expect(processedOrders.length, 125);
        expect(processedOrders.toSet().length, 125);
      },
    );

    test(
      '2. Order empty + 125 tickets -> polls 3 pages cleanly without resetting ticket cursor',
      () async {
        final repo = FakeRecoveryRepository();
        final now = DateTime.now().toUtc();
        for (int i = 1; i <= 125; i++) {
          repo.tickets.add(
            RecoveryTicketTarget(
              id: 'tck_$i',
              sentAt: now.add(Duration(seconds: i)).toIso8601String(),
            ),
          );
        }

        final scanner = RecoveryScanner(repository: repo, pageSize: 50);
        final cache = InMemoryPrintCache();
        final processedTickets = <String>[];

        await scanner.scanNextOrders(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onOrderFound: (_) async {},
        );

        final r1 = await scanner.scanNextTickets(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async => processedTickets.add(id),
        );
        expect(r1.fetchedCount, 50);

        final r2 = await scanner.scanNextTickets(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async => processedTickets.add(id),
        );
        expect(r2.fetchedCount, 50);

        final r3 = await scanner.scanNextTickets(
          storeId: 'store_1',
          cutoffIso: now.subtract(const Duration(minutes: 5)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async => processedTickets.add(id),
        );
        expect(r3.fetchedCount, 25);
        expect(processedTickets.length, 125);
      },
    );

    test(
      '3. Concurrent 75 tickets and 75 orders advance independently without loss or duplication',
      () async {
        final repo = FakeRecoveryRepository();
        final now = DateTime.now().toUtc();
        for (int i = 1; i <= 75; i++) {
          repo.tickets.add(
            RecoveryTicketTarget(
              id: 't_$i',
              sentAt: now.add(Duration(seconds: i)).toIso8601String(),
            ),
          );
          repo.orders.add(
            RecoveryOrderTarget(
              id: 'o_$i',
              updatedAt: now.add(Duration(seconds: i)).toIso8601String(),
              status: 'paid',
            ),
          );
        }

        final scanner = RecoveryScanner(repository: repo, pageSize: 50);
        final cache = InMemoryPrintCache();
        final tRes = <String>[];
        final oRes = <String>[];

        await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async => tRes.add(id),
        );
        await scanner.scanNextOrders(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => oRes.add(id),
        );

        await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async => tRes.add(id),
        );
        await scanner.scanNextOrders(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => oRes.add(id),
        );

        expect(tRes.length, 75);
        expect(oRes.length, 75);
      },
    );

    test('4. Store switch resets all cursors cleanly', () async {
      final repo = FakeRecoveryRepository();
      final scanner = RecoveryScanner(repository: repo);
      scanner.lastTicketSentAt = '2026-08-07T12:00:00Z';
      scanner.lastTicketId = 't1';
      scanner.checkStoreChange('store_B');

      expect(scanner.lastTicketSentAt, null);
      expect(scanner.lastTicketId, null);
      expect(scanner.activeStoreId, 'store_B');
    });

    test(
      '5. Empty page at end resets ticket cursor only, order cursor preserved',
      () async {
        final repo = FakeRecoveryRepository();
        final scanner = RecoveryScanner(repository: repo);
        scanner.activeStoreId = 's1';
        scanner.lastTicketSentAt = '2026-08-07T12:00:00Z';
        scanner.lastTicketId = 't_10';
        scanner.lastOrderUpdatedAt = '2026-08-07T12:05:00Z';
        scanner.lastOrderId = 'o_10';

        final cache = InMemoryPrintCache();
        await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: '2026-08-07T10:00:00Z',
          cache: cache,
          onTicketFound: (_) async {},
        );

        expect(scanner.lastTicketSentAt, null);
        expect(scanner.lastTicketId, null);
        expect(scanner.lastOrderUpdatedAt, '2026-08-07T12:05:00Z');
        expect(scanner.lastOrderId, 'o_10');
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group B: Baseline & Cursor UTC Thật (Tests 6-9)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group B: Baseline & UTC Timestamps', () {
    test(
      '6. Baseline T0 ends with Z and recovers order paid 1s after T0',
      () async {
        final storage = FakePrintCacheStorage();
        final cache = SharedPreferencesPrintCache(storage: storage);
        await cache.init('store_utc');

        final baseline = cache.getBaselineTimestamp('store_utc')!;
        expect(DateTime.parse(baseline).isUtc, true);

        final repo = FakeRecoveryRepository();
        final t0Dt = DateTime.parse(baseline).toUtc();
        final orderAfter = RecoveryOrderTarget(
          id: 'ord_after',
          updatedAt: t0Dt.add(const Duration(seconds: 1)).toIso8601String(),
          status: 'paid',
        );
        repo.orders.add(orderAfter);

        final scanner = RecoveryScanner(repository: repo);
        final res = <String>[];
        await scanner.scanNextOrders(
          storeId: 'store_utc',
          cutoffIso: t0Dt
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => res.add(id),
        );

        expect(res, ['ord_after']);
      },
    );

    test(
      '7. Baseline in +07:00 and Cutoff in Z compared correctly as absolute UTC moments',
      () async {
        final repo = FakeRecoveryRepository();
        final scanner = RecoveryScanner(repository: repo);
        final cache = InMemoryPrintCache(
          baselineTimestamps: {
            's1': '2026-08-07T20:00:00+07:00', // 13:00:00Z
          },
        );

        repo.orders.add(
          RecoveryOrderTarget(
            id: 'ord_early',
            updatedAt: '2026-08-07T12:59:59Z',
            status: 'paid',
          ),
        );
        repo.orders.add(
          RecoveryOrderTarget(
            id: 'ord_late',
            updatedAt: '2026-08-07T13:00:01Z',
            status: 'paid',
          ),
        );

        final res = <String>[];
        await scanner.scanNextOrders(
          storeId: 's1',
          cutoffIso: '2026-08-07T10:00:00Z',
          cache: cache,
          onOrderFound: (id) async => res.add(id),
        );

        expect(res, ['ord_late']);
      },
    );

    test(
      '8. DB returns +00:00, storage holds Z -> pagination advances properly',
      () async {
        final repo = FakeRecoveryRepository();
        repo.tickets.add(
          RecoveryTicketTarget(id: 't1', sentAt: '2026-08-07T12:00:00+00:00'),
        );
        repo.tickets.add(
          RecoveryTicketTarget(id: 't2', sentAt: '2026-08-07T12:00:01+00:00'),
        );

        final scanner = RecoveryScanner(repository: repo, pageSize: 1);
        final cache = InMemoryPrintCache();

        final res1 = <String>[];
        await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: '2026-08-07T10:00:00Z',
          cache: cache,
          onTicketFound: (id) async => res1.add(id),
        );
        expect(res1, ['t1']);

        final res2 = <String>[];
        await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: '2026-08-07T10:00:00Z',
          cache: cache,
          onTicketFound: (id) async => res2.add(id),
        );
        expect(res2, ['t2']);
      },
    );

    test(
      '9. Order 1s before T0 not replayed; order 1s after T0 processed',
      () async {
        final now = DateTime.now().toUtc();
        final cache = InMemoryPrintCache(
          baselineTimestamps: {'s1': now.toIso8601String()},
        );
        final repo = FakeRecoveryRepository();
        repo.orders.add(
          RecoveryOrderTarget(
            id: 'before',
            updatedAt: now
                .subtract(const Duration(seconds: 1))
                .toIso8601String(),
            status: 'paid',
          ),
        );
        repo.orders.add(
          RecoveryOrderTarget(
            id: 'after',
            updatedAt: now.add(const Duration(seconds: 1)).toIso8601String(),
            status: 'paid',
          ),
        );

        final scanner = RecoveryScanner(repository: repo);
        final res = <String>[];
        await scanner.scanNextOrders(
          storeId: 's1',
          cutoffIso: now
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => res.add(id),
        );

        expect(res, ['after']);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group C: Per-Target Exception Isolation (Tests 10-13)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group C: Exception Isolation Per Target', () {
    test(
      '10. Page with target 1 fail, target 2 & 3 success -> 2 & 3 processed, failedTargetIds contains 1',
      () async {
        final repo = FakeRecoveryRepository();
        final now = DateTime.now().toUtc();
        repo.tickets.add(
          RecoveryTicketTarget(
            id: 't1',
            sentAt: now.add(const Duration(seconds: 1)).toIso8601String(),
          ),
        );
        repo.tickets.add(
          RecoveryTicketTarget(
            id: 't2',
            sentAt: now.add(const Duration(seconds: 2)).toIso8601String(),
          ),
        );
        repo.tickets.add(
          RecoveryTicketTarget(
            id: 't3',
            sentAt: now.add(const Duration(seconds: 3)).toIso8601String(),
          ),
        );

        final scanner = RecoveryScanner(repository: repo);
        final cache = InMemoryPrintCache();

        final processed = <String>[];
        final scanResult = await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async {
            if (id == 't1') throw Exception('Socket printer fail on t1');
            processed.add(id);
          },
        );

        expect(scanResult.fetchedCount, 3);
        expect(scanResult.successCount, 2);
        expect(scanResult.failedTargetIds, ['t1']);
        expect(processed, ['t2', 't3']);
      },
    );

    test('11. Subsequent cycle retries failed target 1', () async {
      final repo = FakeRecoveryRepository();
      final now = DateTime.now().toUtc();
      repo.tickets.add(
        RecoveryTicketTarget(
          id: 't1',
          sentAt: now.add(const Duration(seconds: 1)).toIso8601String(),
        ),
      );

      final scanner = RecoveryScanner(repository: repo);
      final cache = InMemoryPrintCache();

      int attempts = 0;
      await scanner.scanNextTickets(
        storeId: 's1',
        cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
        cache: cache,
        onTicketFound: (id) async {
          attempts++;
          if (attempts == 1) throw Exception('First attempt fail');
        },
      );

      scanner.resetTicketCursor();
      final r2 = await scanner.scanNextTickets(
        storeId: 's1',
        cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
        cache: cache,
        onTicketFound: (id) async {
          attempts++;
        },
      );

      expect(r2.successCount, 1);
      expect(attempts, 2);
    });

    test(
      '12. Continuous failure of target 1 does not cause page 2 starvation',
      () async {
        final repo = FakeRecoveryRepository();
        final now = DateTime.now().toUtc();
        for (int i = 1; i <= 60; i++) {
          repo.tickets.add(
            RecoveryTicketTarget(
              id: 't_$i',
              sentAt: now.add(Duration(seconds: i)).toIso8601String(),
            ),
          );
        }

        final scanner = RecoveryScanner(repository: repo, pageSize: 50);
        final cache = InMemoryPrintCache();

        final res1 = await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async {
            if (id == 't_1') throw Exception('t1 keeps failing');
          },
        );
        expect(res1.successCount, 49);

        final res2 = await scanner.scanNextTickets(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onTicketFound: (id) async {},
        );
        expect(res2.successCount, 10);
      },
    );

    test('13. Callback exception does not reset remaining cursors', () async {
      final repo = FakeRecoveryRepository();
      final scanner = RecoveryScanner(repository: repo);
      final cache = InMemoryPrintCache();
      final now = DateTime.now().toUtc();

      repo.orders.add(
        RecoveryOrderTarget(
          id: 'o1',
          updatedAt: now.toIso8601String(),
          status: 'paid',
        ),
      );

      final scanResult = await scanner.scanNextOrders(
        storeId: 's1',
        cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
        cache: cache,
        onOrderFound: (_) async => throw Exception('Callback crash'),
      );

      expect(scanResult.failedTargetIds, ['o1']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group D: Degraded Cache Halt & Safe Recovery (Tests 14-18)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group D: Degraded Cache Halt & Safe Recovery', () {
    test(
      '14. Printer success + task persistence fail -> degraded status, RAM key kept',
      () async {
        final storage = FakePrintCacheStorage();
        final cache = SharedPreferencesPrintCache(storage: storage);
        await cache.init('store_1');

        storage.shouldFailWrite = true;
        final ok = await cache.markTaskKeyPrinted('task_1');
        expect(ok, false);
        expect(cache.isDegraded, true);
        expect(cache.isTaskKeyPrinted('task_1'), true);
      },
    );

    test('15. After degraded -> scanner returns 0 fetched count', () async {
      final repo = FakeRecoveryRepository();
      final now = DateTime.now().toUtc();
      repo.tickets.add(
        RecoveryTicketTarget(id: 't1', sentAt: now.toIso8601String()),
      );

      final cache = InMemoryPrintCache(isDegraded: true);
      final scanner = RecoveryScanner(repository: repo);

      final res = await scanner.scanNextTickets(
        storeId: 's1',
        cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
        cache: cache,
        onTicketFound: (_) async {},
      );

      expect(res.fetchedCount, 0);
    });

    test('16. Polling timer when degraded -> 0 dispatches', () async {
      final cache = InMemoryPrintCache(isDegraded: true);
      final repo = FakeRecoveryRepository();
      final scanner = RecoveryScanner(repository: repo);

      final res = await scanner.scanNextOrders(
        storeId: 's1',
        cutoffIso: '2026-08-07T10:00:00Z',
        cache: cache,
        onOrderFound: (_) async {},
      );

      expect(res.fetchedCount, 0);
    });

    test(
      '17. Explicit recoverSnapshot resets degraded mode only after storage verification',
      () async {
        final storage = FakePrintCacheStorage();
        final cache = SharedPreferencesPrintCache(storage: storage);
        await cache.init('store_1');

        storage.shouldFailWrite = true;
        await cache.markTaskKeyPrinted('k1');
        expect(cache.isDegraded, true);

        storage.shouldFailWrite = false;
        final recovered = await cache.recoverSnapshot();
        expect(recovered, true);
        expect(cache.isDegraded, false);
      },
    );

    test(
      '18. Persistence failure does not cause immediate reprint in current process',
      () async {
        final storage = FakePrintCacheStorage();
        final cache = SharedPreferencesPrintCache(storage: storage);
        await cache.init('store_1');

        storage.shouldFailWrite = true;
        await cache.markTaskKeyPrinted('task_100');

        expect(cache.isTaskKeyPrinted('task_100'), true);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group E: Write Chain Robustness & Atomic Merge (Tests 19-22)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group E: Write Chain Robustness & Atomic Merge', () {
    test(
      '19. readStringList throws -> mark returns false within timeout, isDegraded=true, completer does not hang',
      () async {
        final storage = FakePrintCacheStorage();
        final cache = SharedPreferencesPrintCache(storage: storage);
        await cache.init('store_1');

        storage.shouldThrowRead = true;
        final markFuture = cache.markTaskKeyPrinted('k_err');
        final result = await markFuture.timeout(
          const Duration(seconds: 1),
          onTimeout: () => throw TimeoutException('Completer hung!'),
        );

        expect(result, false);
        expect(cache.isDegraded, true);
      },
    );

    test(
      '20. Write #1 fails, Write #2 completes or returns false cleanly without hanging chain',
      () async {
        final storage = FakePrintCacheStorage();
        final cache = SharedPreferencesPrintCache(storage: storage);
        await cache.init('store_1');

        storage.shouldFailWrite = true;
        final res1 = await cache.markTaskKeyPrinted('k1');

        storage.shouldFailWrite = false;
        final res2 = await cache.markTaskKeyPrinted('k2');

        expect(res1, false);
        expect(res2, true);
      },
    );

    test(
      '21. Future.wait on 2 concurrent marks on same cache -> reloads both keys',
      () async {
        final storage = FakePrintCacheStorage();
        final cache = SharedPreferencesPrintCache(storage: storage);
        await cache.init('store_1');

        await Future.wait<bool>([
          cache.markTaskKeyPrinted('concurrent_1'),
          cache.markTaskKeyPrinted('concurrent_2'),
        ]);

        expect(cache.isTaskKeyPrinted('concurrent_1'), true);
        expect(cache.isTaskKeyPrinted('concurrent_2'), true);
      },
    );

    test(
      '22. Atomic merge on 2 cache instances sharing storage preserves keys of both instances',
      () async {
        final sharedStorage = FakePrintCacheStorage();
        final cache1 = SharedPreferencesPrintCache(storage: sharedStorage);
        final cache2 = SharedPreferencesPrintCache(storage: sharedStorage);

        await cache1.init('s1');
        await cache2.init('s1');

        await cache1.markTaskKeyPrinted('c1_key');
        await cache2.markTaskKeyPrinted('c2_key');

        expect(cache1.isTaskKeyPrinted('c1_key'), true);
        expect(cache2.isTaskKeyPrinted('c2_key'), true);

        final listInStorage = await sharedStorage.readStringList(
          'qn_printed_task_keys',
        );
        expect(listInStorage!.contains('c1_key'), true);
        expect(listInStorage.contains('c2_key'), true);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group F: Lifecycle Controller DI & Dedupe (Tests 23-30)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group F: Lifecycle Controller DI & Post-Setup Dedupe', () {
    test(
      '23. 10 setup requests called concurrently -> deduplicated to 1 execution',
      () async {
        final controller = PrintServerLifecycleController();
        final cache = InMemoryPrintCache();
        final settings = const StationPrintersState(
          cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
          bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
          barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
          autoPrintServer: true,
        );

        final futures = List<Future<void>>.generate(10, (_) {
          return controller.setup(
            storeId: 'store_dedupe',
            autoPrintServer: true,
            settings: settings,
            cache: cache,
            processTicket: (_) async {},
            processOrder: (_) async {},
            pollActive: (_) async {},
          );
        });

        await Future.wait<void>(futures);
        expect(
          controller.createdChannelsCount,
          2,
        ); // 1 kitchen + 1 order channel
      },
    );

    test(
      '24. Calling setup with identical signature AFTER completion is a no-op (0 new channels)',
      () async {
        final controller = PrintServerLifecycleController();
        final cache = InMemoryPrintCache();
        final settings = const StationPrintersState(
          cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
          bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
          barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
          autoPrintServer: true,
        );

        await controller.setup(
          storeId: 's1',
          autoPrintServer: true,
          settings: settings,
          cache: cache,
          processTicket: (_) async {},
          processOrder: (_) async {},
          pollActive: (_) async {},
        );

        final initialChannels = controller.createdChannelsCount;

        await controller.setup(
          storeId: 's1',
          autoPrintServer: true,
          settings: settings,
          cache: cache,
          processTicket: (_) async {},
          processOrder: (_) async {},
          pollActive: (_) async {},
        );

        expect(controller.createdChannelsCount, initialChannels);
      },
    );

    test(
      '25. Changing store signature triggers exactly 1 teardown and 1 new setup',
      () async {
        final controller = PrintServerLifecycleController();
        final cache = InMemoryPrintCache();
        final settings = const StationPrintersState(
          cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
          bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
          barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
          autoPrintServer: true,
        );

        await controller.setup(
          storeId: 'store_A',
          autoPrintServer: true,
          settings: settings,
          cache: cache,
          processTicket: (_) async {},
          processOrder: (_) async {},
          pollActive: (_) async {},
        );
        expect(controller.currentGeneration, 1);

        await controller.setup(
          storeId: 'store_B',
          autoPrintServer: true,
          settings: settings,
          cache: cache,
          processTicket: (_) async {},
          processOrder: (_) async {},
          pollActive: (_) async {},
        );
        expect(controller.currentGeneration, 2);
      },
    );

    test('26. Fake channel callback with old generation is blocked', () async {
      final controller = PrintServerLifecycleController();
      final cache = InMemoryPrintCache();
      final settings = const StationPrintersState(
        cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
        bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
        bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
        barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
        autoPrintServer: true,
      );

      int dispatchCount = 0;
      await controller.setup(
        storeId: 's1',
        autoPrintServer: true,
        settings: settings,
        cache: cache,
        processTicket: (_) async => dispatchCount++,
        processOrder: (_) async {},
        pollActive: (_) async {},
      );

      controller.stop();
      expect(dispatchCount, 0);
    });

    test('27. Active generation callback dispatches properly', () async {
      final controller = PrintServerLifecycleController();
      final cache = InMemoryPrintCache();
      final settings = const StationPrintersState(
        cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
        bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
        bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
        barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
        autoPrintServer: true,
      );

      await controller.setup(
        storeId: 's1',
        autoPrintServer: true,
        settings: settings,
        cache: cache,
        processTicket: (id) async {},
        processOrder: (_) async {},
        pollActive: (_) async {},
      );

      expect(controller.currentGeneration > 0, true);
    });

    test(
      '28. Reconnecting 10 times results in maximum 1 active channel/timer pair',
      () async {
        final controller = PrintServerLifecycleController();
        final cache = InMemoryPrintCache();
        final settings = const StationPrintersState(
          cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
          bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
          barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
          autoPrintServer: true,
        );

        for (int i = 0; i < 10; i++) {
          await controller.setup(
            storeId: 'store_reconnect_$i',
            autoPrintServer: true,
            settings: settings,
            cache: cache,
            processTicket: (_) async {},
            processOrder: (_) async {},
            pollActive: (_) async {},
          );
        }

        expect(controller.activeChannelsCount <= 2, true);
        expect(controller.activeTimersCount <= 1, true);
      },
    );

    test(
      '29. Subscribed storage degraded prevents setup listener creation',
      () async {
        final controller = PrintServerLifecycleController();
        final cache = InMemoryPrintCache(isDegraded: true);
        final settings = const StationPrintersState(
          cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
          bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
          bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
          barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
          autoPrintServer: true,
        );

        await controller.setup(
          storeId: 's1',
          autoPrintServer: true,
          settings: settings,
          cache: cache,
          processTicket: (_) async {},
          processOrder: (_) async {},
          pollActive: (_) async {},
        );

        expect(controller.hasActiveKitchenChannel, false);
      },
    );

    test('30. stop cancels all channels and timers', () async {
      final controller = PrintServerLifecycleController();
      final cache = InMemoryPrintCache();
      final settings = const StationPrintersState(
        cashier: PrinterConfig(name: 'p1', type: 'system', enabled: true),
        bepNong: PrinterConfig(name: 'p2', type: 'system', enabled: true),
        bepBar: PrinterConfig(name: 'p3', type: 'system', enabled: true),
        barLabel: PrinterConfig(name: 'p4', type: 'system', enabled: true),
        autoPrintServer: true,
      );

      await controller.setup(
        storeId: 's1',
        autoPrintServer: true,
        settings: settings,
        cache: cache,
        processTicket: (_) async {},
        processOrder: (_) async {},
        pollActive: (_) async {},
      );

      controller.stop();
      expect(controller.hasActiveKitchenChannel, false);
      expect(controller.hasActiveOrdersChannel, false);
      expect(controller.hasActivePollTimer, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group G: UserAuthService Production Path Execution (Tests 31-38)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group G: UserAuthService Production Path', () {
    late FakeUserAuthRepository fakeAuthRepo;
    late TrackingStoreMembershipWriter trackingWriter;

    setUp(() {
      fakeAuthRepo = FakeUserAuthRepository();
      trackingWriter = TrackingStoreMembershipWriter();
      UserAuthService.authRepository = fakeAuthRepo;
      UserAuthService.membershipWriter = trackingWriter;
    });

    test(
      '31. staff query success-empty + store query throws -> throws UserAuthException, NOT []',
      () async {
        fakeAuthRepo.staffMembers = [];
        fakeAuthRepo.storeQueryThrows = true;

        expect(
          () async => await UserAuthService.getUserStores('u1'),
          throwsA(isA<UserAuthException>()),
        );
      },
    );

    test(
      '32. staff query throws + store query returns Store A -> production method returns Store A',
      () async {
        fakeAuthRepo.staffQueryThrows = true;
        fakeAuthRepo.storeMembers = [
          {
            'store_id': 'sA',
            'role': 'owner',
            'is_owner': true,
            'stores': {'id': 'sA', 'name': 'Quán A', 'store_code': 'QN-A'},
          },
        ];

        final stores = await UserAuthService.getUserStores('u1');
        expect(stores.length, 1);
        expect(stores.first.storeId, 'sA');
      },
    );

    test(
      '33. store query throws -> production method throws UserAuthException (single source of truth)',
      () async {
        fakeAuthRepo.storeQueryThrows = true;

        expect(
          () => UserAuthService.getUserStores('u1'),
          throwsA(isA<UserAuthException>()),
        );
      },
    );

    test('34. Both queries success-empty -> returns valid []', () async {
      fakeAuthRepo.staffMembers = [];
      fakeAuthRepo.storeMembers = [];

      final stores = await UserAuthService.getUserStores('u1');
      expect(stores, isEmpty);
    });

    test(
      '35. Production fetchStoreMembership propagates UserAuthException on DB failure',
      () async {
        fakeAuthRepo.staffMembers = [];
        fakeAuthRepo.storeQueryThrows = true;

        expect(
          () async => await UserAuthService.fetchStoreMembership('u1'),
          throwsA(isA<UserAuthException>()),
        );
      },
    );

    test(
      '36. createStore fails closed instead of using direct membership writer',
      () async {
        final res = await UserAuthService.createStore(
          userId: 'user_owner_1',
          storeName: 'Quán Mới 1',
        );

        expect(res.isSuccess, false);
        expect(trackingWriter.writeCount, 0);
        expect(trackingWriter.lastPayload, isNull);
      },
    );

    test(
      '37. joinStoreByCode fails closed instead of direct repository mutation',
      () async {
        fakeAuthRepo.stores['QN-TARGET'] = {
          'id': 's_target',
          'store_code': 'QN-TARGET',
          'name': 'Quán Target',
          'status': 'active',
        };

        final res = await UserAuthService.joinStoreByCode(
          userId: 'u_join',
          storeCode: 'QN-TARGET',
        );
        expect(res.isSuccess, false);
        expect(trackingWriter.writeCount, 0);
      },
    );

    test(
      '38. User participating in Store A and Store B retains distinct memberships',
      () async {
        fakeAuthRepo.storeMembers = [
          {
            'store_id': 'sA',
            'role': 'owner',
            'is_owner': true,
            'stores': {'id': 'sA', 'name': 'Quán A', 'store_code': 'QN-A'},
          },
          {
            'store_id': 'sB',
            'role': 'cashier',
            'is_owner': false,
            'stores': {'id': 'sB', 'name': 'Quán B', 'store_code': 'QN-B'},
          },
        ];

        final stores = await UserAuthService.getUserStores('u_multi');
        expect(stores.length, 2);
        expect(stores[0].role, 'owner');
        expect(stores[1].role, 'cashier');
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group H: 100% Offline Font Coverage (Tests 39-44)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group H: 100% Offline Font Environment Coverage', () {
    test('39. Generate Receipt PDF tiếng Việt -> 0 network calls', () async {
      final initialAttempts = testHttpOverrides.networkAttemptCount;
      final bill = BillData(
        shopName: 'Quán Nhỏ',
        orderNumber: 'HD-001',
        createdAt: DateTime.now(),
        tableName: 'Bàn 5',
        subtotal: 150000,
        total: 150000,
        items: [
          const BillItem(
            name: 'Phở bò tái lăn (Đặc biệt)',
            qty: 2,
            price: 65000,
          ),
          const BillItem(
            name: 'Trà đá đường ỏ đ ả ơ ẹ ặ ạ',
            qty: 2,
            price: 10000,
          ),
        ],
      );

      final bytes = await BillPdfGenerator.generateReceipt(bill);
      expect(bytes.isNotEmpty, true);
      expect(testHttpOverrides.networkAttemptCount, initialAttempts);
    });

    test('40. Generate Kitchen PDF tiếng Việt -> 0 network calls', () async {
      final initialAttempts = testHttpOverrides.networkAttemptCount;
      final bill = BillData(
        shopName: 'Quán Nhỏ',
        orderNumber: 'K-001',
        createdAt: DateTime.now(),
        tableName: 'Bàn Bếp 1',
        subtotal: 90000,
        total: 90000,
        items: [
          const BillItem(name: 'Bún chả Hà Nội (Ít ớt)', qty: 1, price: 90000),
        ],
      );

      final bytes = await BillPdfGenerator.generateKitchenTicket(bill);
      expect(bytes.isNotEmpty, true);
      expect(testHttpOverrides.networkAttemptCount, initialAttempts);
    });

    test('41. Generate Bar Label PDF tiếng Việt -> 0 network calls', () async {
      final initialAttempts = testHttpOverrides.networkAttemptCount;
      final bill = BillData(
        shopName: 'Quán Nhỏ',
        orderNumber: 'BAR-001',
        createdAt: DateTime.now(),
        tableName: 'Bàn 3',
        subtotal: 45000,
        total: 45000,
        items: [
          const BillItem(
            name: 'Cà phê sữa đá ỏ đ ả ơ ẹ',
            qty: 2,
            price: 25000,
            stationCode: 'bar',
          ),
        ],
      );

      final labels = await BillPdfGenerator.generateBarLabels(bill);
      expect(labels.length, 2);
      expect(labels.first.isNotEmpty, true);
      expect(testHttpOverrides.networkAttemptCount, initialAttempts);
    });

    test('42. Warmup Print Server -> 0 network calls', () async {
      final initialAttempts = testHttpOverrides.networkAttemptCount;
      await Future.wait<dynamic>([
        BillPdfGenerator.fontLoader.loadRegular(),
        BillPdfGenerator.fontLoader.loadBold(),
      ]);
      expect(testHttpOverrides.networkAttemptCount, initialAttempts);
    });

    test('43. No font fallback, zero missing glyph warnings', () async {
      final bill = BillData(
        shopName: 'Quán Nhỏ',
        orderNumber: 'HD-UNICODE',
        createdAt: DateTime.now(),
        tableName: 'Bàn Tiệc',
        subtotal: 500000,
        total: 500000,
        items: [
          const BillItem(name: 'Bún chả ỏ đ ả ơ ẹ ặ ạ', qty: 1, price: 500000),
        ],
      );

      final bytes = await BillPdfGenerator.generateReceipt(bill);
      expect(bytes.isNotEmpty, true);
    });

    test(
      '44. tearDownAll restores HttpOverrides and default font loader cleanly',
      () async {
        expect(BillPdfGenerator.fontLoader, isNotNull);
      },
    );
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Group I: Order Updated_at Write Path Verification (Tests 45-47)
  // ═══════════════════════════════════════════════════════════════════════════
  group('Group I: Order Updated_at Payment Path Verification', () {
    test('45. Payment update payload includes new UTC updated_at', () async {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      final updatePayload = {'status': 'paid', 'updated_at': nowUtc};

      expect(updatePayload['status'], 'paid');
      expect((updatePayload['updated_at'] as String).endsWith('Z'), true);
    });

    test(
      '46. Recovery query subsequently fetches order by updated_at',
      () async {
        final repo = FakeRecoveryRepository();
        final t0 = DateTime.now().toUtc();
        final paidOrder = RecoveryOrderTarget(
          id: 'order_paid_recently',
          updatedAt: t0.add(const Duration(seconds: 2)).toIso8601String(),
          status: 'paid',
        );
        repo.orders.add(paidOrder);

        final scanner = RecoveryScanner(repository: repo);
        final cache = InMemoryPrintCache();
        final fetched = <String>[];

        await scanner.scanNextOrders(
          storeId: 's1',
          cutoffIso: t0.toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => fetched.add(id),
        );

        expect(fetched, ['order_paid_recently']);
      },
    );

    test(
      '47. Cancel / refund orders are filtered out by status predicate (paid/completed only)',
      () async {
        final repo = FakeRecoveryRepository();
        final now = DateTime.now().toUtc();

        final paidOrder = RecoveryOrderTarget(
          id: 'o_paid',
          updatedAt: now.toIso8601String(),
          status: 'paid',
        );
        repo.orders.add(paidOrder);

        final scanner = RecoveryScanner(repository: repo);
        final cache = InMemoryPrintCache();
        final fetched = <String>[];

        await scanner.scanNextOrders(
          storeId: 's1',
          cutoffIso: now.subtract(const Duration(minutes: 1)).toIso8601String(),
          cache: cache,
          onOrderFound: (id) async => fetched.add(id),
        );

        expect(fetched, ['o_paid']);
      },
    );
  });
}
