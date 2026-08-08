import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/services/user_auth_service.dart';
import '../../../core/utils/app_logger.dart';
import '../screens/bill_preview_screen.dart';
import '../utils/station_normalizer.dart';

/// WS Order Event Predicate
bool shouldProcessOrderEvent(Map<String, dynamic> row) {
  final status = row['status'] as String? ?? 'open';
  return status == 'paid' || status == 'completed';
}

/// Interface đại diện cho storage đọc ghi đĩa cache (Print Cache Storage DI)
abstract class PrintCacheStorage {
  Future<List<String>?> readStringList(String key);
  Future<String?> readString(String key);
  Future<int?> readInt(String key);
  Future<bool> writeStringList(String key, List<String> value);
  Future<bool> writeString(String key, String value);
  Future<bool> writeInt(String key, int value);
}

class SharedPreferencesCacheStorage implements PrintCacheStorage {
  @override
  Future<List<String>?> readStringList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key);
  }

  @override
  Future<String?> readString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<int?> readInt(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key);
  }

  @override
  Future<bool> writeStringList(String key, List<String> value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setStringList(key, value);
  }

  @override
  Future<bool> writeString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(key, value);
  }

  @override
  Future<bool> writeInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(key, value);
  }
}

/// Interface đại diện cho bộ nhớ đệm cache các task key đã in (Print Cache DI)
abstract class PrintCache {
  bool isTaskKeyPrinted(String key);
  Future<bool> markTaskKeyPrinted(String key);
  bool isTicketPrinted(String ticketId);
  Future<bool> markTicketPrinted(String ticketId);
  bool isOrderPrinted(String orderId);
  Future<bool> markOrderPrinted(String orderId);
  bool get isDegraded;
  String? get lastError;
  String? getBaselineTimestamp(String storeId);
  Future<bool> recoverSnapshot();
}

class InMemoryPrintCache implements PrintCache {
  final Set<String> printedTaskKeys;
  final Set<String> printedTicketIds;
  final Set<String> printedOrderIds;
  final Map<String, String> baselineTimestamps;
  @override
  bool isDegraded;
  @override
  String? lastError;

  InMemoryPrintCache({
    Set<String>? printedTaskKeys,
    Set<String>? printedTicketIds,
    Set<String>? printedOrderIds,
    Map<String, String>? baselineTimestamps,
    this.isDegraded = false,
    this.lastError,
  }) : printedTaskKeys = printedTaskKeys ?? {},
       printedTicketIds = printedTicketIds ?? {},
       printedOrderIds = printedOrderIds ?? {},
       baselineTimestamps = baselineTimestamps ?? {};

  @override
  bool isTaskKeyPrinted(String key) => printedTaskKeys.contains(key);

  @override
  Future<bool> markTaskKeyPrinted(String key) async {
    printedTaskKeys.add(key);
    return !isDegraded;
  }

  @override
  bool isTicketPrinted(String ticketId) => printedTicketIds.contains(ticketId);

  @override
  Future<bool> markTicketPrinted(String ticketId) async {
    printedTicketIds.add(ticketId);
    await markTaskKeyPrinted('$ticketId:all');
    return !isDegraded;
  }

  @override
  bool isOrderPrinted(String orderId) => printedOrderIds.contains(orderId);

  @override
  Future<bool> markOrderPrinted(String orderId) async {
    printedOrderIds.add(orderId);
    await markTaskKeyPrinted('$orderId:cashier');
    return !isDegraded;
  }

  @override
  String? getBaselineTimestamp(String storeId) => baselineTimestamps[storeId];

  @override
  Future<bool> recoverSnapshot() async {
    isDegraded = false;
    lastError = null;
    return true;
  }
}

class SharedPreferencesPrintCache implements PrintCache {
  static const int kCacheVersion = 1;
  final PrintCacheStorage storage;
  final Set<String> printedTaskKeys = {};
  final Set<String> printedTicketIds = {};
  final Set<String> printedOrderIds = {};
  final Map<String, String> _baselineTimestamps = {};
  bool _initialized = false;
  @override
  bool isDegraded = false;
  @override
  String? lastError;

  Future<void> _writeChain = Future.value();

  SharedPreferencesPrintCache({PrintCacheStorage? storage})
    : storage = storage ?? SharedPreferencesCacheStorage();

  Future<bool> init(String storeId) async {
    if (_initialized && _baselineTimestamps.containsKey(storeId))
      return !isDegraded;
    try {
      final currentVer = await storage.readInt('qn_print_cache_version');
      final baselineKey = 'qn_print_cache_baseline_ts_$storeId';
      var baselineTs = await storage.readString(baselineKey);

      if (currentVer == null ||
          currentVer < kCacheVersion ||
          baselineTs == null) {
        // T0 startup barrier: Exact ISO timestamp without subtraction
        baselineTs = DateTime.now().toUtc().toIso8601String();
        final ok1 = await storage.writeString(baselineKey, baselineTs);
        final ok2 = await storage.writeInt(
          'qn_print_cache_version',
          kCacheVersion,
        );
        if (!ok1 || !ok2) {
          isDegraded = true;
          lastError = 'Failed to persist T0 baseline to storage';
          return false;
        }
      }

      _baselineTimestamps[storeId] = baselineTs;

      final keysList =
          await storage.readStringList('qn_printed_task_keys') ?? [];
      final ticketsList =
          await storage.readStringList('qn_printed_ticket_ids') ?? [];
      final ordersList =
          await storage.readStringList('qn_printed_order_ids') ?? [];
      printedTaskKeys.addAll(keysList);
      printedTicketIds.addAll(ticketsList);
      printedOrderIds.addAll(ordersList);

      _initialized = true;
      return true;
    } catch (e) {
      isDegraded = true;
      lastError = e.toString();
      return false;
    }
  }

  @override
  Future<bool> recoverSnapshot() async {
    try {
      final keysList = printedTaskKeys.toList();
      final ticketsList = printedTicketIds.toList();
      final ordersList = printedOrderIds.toList();

      final ok1 = await _writeWithRetry('qn_printed_task_keys', keysList);
      final ok2 = await _writeWithRetry('qn_printed_ticket_ids', ticketsList);
      final ok3 = await _writeWithRetry('qn_printed_order_ids', ordersList);

      if (ok1 && ok2 && ok3) {
        isDegraded = false;
        lastError = null;
        return true;
      }
      return false;
    } catch (e) {
      isDegraded = true;
      lastError = e.toString();
      return false;
    }
  }

  Future<bool> _writeWithRetry(String key, List<String> list) async {
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        final ok = await storage.writeStringList(key, list);
        if (ok) return true;
      } catch (e) {
        lastError = e.toString();
      }
      if (attempt < 3) {
        await Future.delayed(Duration(milliseconds: 50 * attempt));
      }
    }
    isDegraded = true;
    lastError ??= 'Storage write failed after 3 attempts';
    return false;
  }

  @override
  bool isTaskKeyPrinted(String key) => printedTaskKeys.contains(key);

  @override
  Future<bool> markTaskKeyPrinted(String key) async {
    printedTaskKeys.add(key); // RAM update immediate
    final completer = Completer<bool>();
    _writeChain = _writeChain
        .then((_) async {
          try {
            final existing =
                await storage.readStringList('qn_printed_task_keys') ?? [];
            printedTaskKeys.addAll(existing);
            final list = printedTaskKeys.toList();
            final trimmed = list.length > 1000
                ? list.sublist(list.length - 1000)
                : list;
            final ok = await _writeWithRetry('qn_printed_task_keys', trimmed);
            completer.complete(ok);
          } catch (e) {
            isDegraded = true;
            lastError = e.toString();
            completer.complete(false);
          }
        })
        .catchError((err) {
          isDegraded = true;
          lastError = err.toString();
          if (!completer.isCompleted) completer.complete(false);
        });
    return completer.future;
  }

  @override
  bool isTicketPrinted(String ticketId) => printedTicketIds.contains(ticketId);

  @override
  Future<bool> markTicketPrinted(String ticketId) async {
    printedTicketIds.add(ticketId);
    final taskOk = await markTaskKeyPrinted('$ticketId:all');
    if (!taskOk) return false;

    final completer = Completer<bool>();
    _writeChain = _writeChain
        .then((_) async {
          try {
            final existing =
                await storage.readStringList('qn_printed_ticket_ids') ?? [];
            printedTicketIds.addAll(existing);
            final list = printedTicketIds.toList();
            final trimmed = list.length > 500
                ? list.sublist(list.length - 500)
                : list;
            final ok = await _writeWithRetry('qn_printed_ticket_ids', trimmed);
            completer.complete(ok);
          } catch (e) {
            isDegraded = true;
            lastError = e.toString();
            completer.complete(false);
          }
        })
        .catchError((err) {
          isDegraded = true;
          lastError = err.toString();
          if (!completer.isCompleted) completer.complete(false);
        });
    return completer.future;
  }

  @override
  bool isOrderPrinted(String orderId) => printedOrderIds.contains(orderId);

  @override
  Future<bool> markOrderPrinted(String orderId) async {
    printedOrderIds.add(orderId);
    final taskOk = await markTaskKeyPrinted('$orderId:cashier');
    if (!taskOk) return false;

    final completer = Completer<bool>();
    _writeChain = _writeChain
        .then((_) async {
          try {
            final existing =
                await storage.readStringList('qn_printed_order_ids') ?? [];
            printedOrderIds.addAll(existing);
            final list = printedOrderIds.toList();
            final trimmed = list.length > 500
                ? list.sublist(list.length - 500)
                : list;
            final ok = await _writeWithRetry('qn_printed_order_ids', trimmed);
            completer.complete(ok);
          } catch (e) {
            isDegraded = true;
            lastError = e.toString();
            completer.complete(false);
          }
        })
        .catchError((err) {
          isDegraded = true;
          lastError = err.toString();
          if (!completer.isCompleted) completer.complete(false);
        });
    return completer.future;
  }

  @override
  String? getBaselineTimestamp(String storeId) {
    final cached = _baselineTimestamps[storeId];
    if (cached != null && cached.isNotEmpty) return cached;
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    _baselineTimestamps[storeId] = nowUtc;
    return nowUtc;
  }
}

class RecoveryTicketTarget {
  final String id;
  final String sentAt;

  const RecoveryTicketTarget({required this.id, required this.sentAt});
}

class RecoveryOrderTarget {
  final String id;
  final String updatedAt;
  final String status;

  const RecoveryOrderTarget({
    required this.id,
    required this.updatedAt,
    required this.status,
  });
}

class RecoveryQueryBuilder {
  static String buildTicketFilter(String lastTimestamp, String lastId) {
    return 'sent_at.gt.$lastTimestamp,and(sent_at.eq.$lastTimestamp,id.gt.$lastId)';
  }

  static String buildOrderFilter(String lastTimestamp, String lastId) {
    return 'updated_at.gt.$lastTimestamp,and(updated_at.eq.$lastTimestamp,id.gt.$lastId)';
  }
}

abstract class RecoveryRepository {
  Future<List<RecoveryTicketTarget>> fetchTicketPage({
    required String storeId,
    required String cutoffIso,
    String? lastTimestamp,
    String? lastId,
    required int limit,
  });

  Future<List<RecoveryOrderTarget>> fetchOrderPage({
    required String storeId,
    required String cutoffIso,
    String? lastTimestamp,
    String? lastId,
    required int limit,
  });
}

class SupabaseRecoveryRepository implements RecoveryRepository {
  @override
  Future<List<RecoveryTicketTarget>> fetchTicketPage({
    required String storeId,
    required String cutoffIso,
    String? lastTimestamp,
    String? lastId,
    required int limit,
  }) async {
    dynamic query = Supabase.instance.client
        .from('kitchen_tickets')
        .select('id, sent_at')
        .eq('store_id', storeId)
        .eq('status', 'cho');

    if (lastTimestamp != null && lastId != null) {
      query = query.or(
        RecoveryQueryBuilder.buildTicketFilter(lastTimestamp, lastId),
      );
    } else {
      query = query.gte('sent_at', cutoffIso);
    }

    final List<dynamic> rows = await query
        .order('sent_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);

    return rows.map((r) {
      return RecoveryTicketTarget(
        id: r['id'] as String,
        sentAt: r['sent_at'] as String? ?? cutoffIso,
      );
    }).toList();
  }

  @override
  Future<List<RecoveryOrderTarget>> fetchOrderPage({
    required String storeId,
    required String cutoffIso,
    String? lastTimestamp,
    String? lastId,
    required int limit,
  }) async {
    dynamic query = Supabase.instance.client
        .from('orders')
        .select('id, updated_at, status')
        .eq('store_id', storeId)
        .inFilter('status', ['paid', 'completed']);

    if (lastTimestamp != null && lastId != null) {
      query = query.or(
        RecoveryQueryBuilder.buildOrderFilter(lastTimestamp, lastId),
      );
    } else {
      query = query.gte('updated_at', cutoffIso);
    }

    final List<dynamic> rows = await query
        .order('updated_at', ascending: true)
        .order('id', ascending: true)
        .limit(limit);

    return rows.map((r) {
      return RecoveryOrderTarget(
        id: r['id'] as String,
        updatedAt: r['updated_at'] as String? ?? cutoffIso,
        status: r['status'] as String? ?? 'paid',
      );
    }).toList();
  }
}

class ScanResult {
  final int fetchedCount;
  final int successCount;
  final List<String> failedTargetIds;
  final int skippedPrintedCount;

  const ScanResult({
    required this.fetchedCount,
    required this.successCount,
    required this.failedTargetIds,
    required this.skippedPrintedCount,
  });
}

class RecoveryScanner {
  final RecoveryRepository repository;
  final int pageSize;

  String? lastTicketSentAt;
  String? lastTicketId;
  String? lastOrderUpdatedAt;
  String? lastOrderId;
  String? activeStoreId;

  RecoveryScanner({required this.repository, this.pageSize = 50});

  void resetTicketCursor() {
    lastTicketSentAt = null;
    lastTicketId = null;
  }

  void resetOrderCursor() {
    lastOrderUpdatedAt = null;
    lastOrderId = null;
  }

  void resetAllCursors() {
    resetTicketCursor();
    resetOrderCursor();
  }

  void checkStoreChange(String storeId) {
    if (activeStoreId != storeId) {
      activeStoreId = storeId;
      resetAllCursors();
    }
  }

  DateTime _parseUtc(String isoStr) {
    return DateTime.parse(isoStr).toUtc();
  }

  String _getEffectiveCutoff(String? baselineIso, String cutoffIso) {
    if (baselineIso == null) return cutoffIso;
    final bDt = _parseUtc(baselineIso);
    final cDt = _parseUtc(cutoffIso);
    return bDt.isAfter(cDt) ? baselineIso : cutoffIso;
  }

  Future<ScanResult> scanNextTickets({
    required String storeId,
    required String cutoffIso,
    required PrintCache cache,
    required Future<void> Function(String ticketId) onTicketFound,
  }) async {
    checkStoreChange(storeId);
    if (cache.isDegraded) {
      return const ScanResult(
        fetchedCount: 0,
        successCount: 0,
        failedTargetIds: [],
        skippedPrintedCount: 0,
      );
    }

    final baseline = cache.getBaselineTimestamp(storeId);
    final effectiveCutoff = _getEffectiveCutoff(baseline, cutoffIso);

    final page = await repository.fetchTicketPage(
      storeId: storeId,
      cutoffIso: effectiveCutoff,
      lastTimestamp: lastTicketSentAt,
      lastId: lastTicketId,
      limit: pageSize,
    );

    if (page.isEmpty) {
      resetTicketCursor();
      return const ScanResult(
        fetchedCount: 0,
        successCount: 0,
        failedTargetIds: [],
        skippedPrintedCount: 0,
      );
    }

    lastTicketSentAt = page.last.sentAt;
    lastTicketId = page.last.id;

    int successCount = 0;
    int skippedPrintedCount = 0;
    final failedTargetIds = <String>[];

    for (final target in page) {
      if (!cache.isTicketPrinted(target.id)) {
        try {
          await onTicketFound(target.id);
          successCount++;
        } catch (e) {
          failedTargetIds.add(target.id);
          writePrintLog(
            '[RecoveryScanner ERROR] Failed ticket target ${target.id}: $e',
          );
        }
      } else {
        skippedPrintedCount++;
      }
    }

    if (page.length < pageSize) {
      resetTicketCursor();
    }

    return ScanResult(
      fetchedCount: page.length,
      successCount: successCount,
      failedTargetIds: failedTargetIds,
      skippedPrintedCount: skippedPrintedCount,
    );
  }

  Future<ScanResult> scanNextOrders({
    required String storeId,
    required String cutoffIso,
    required PrintCache cache,
    required Future<void> Function(String orderId) onOrderFound,
  }) async {
    checkStoreChange(storeId);
    if (cache.isDegraded) {
      return const ScanResult(
        fetchedCount: 0,
        successCount: 0,
        failedTargetIds: [],
        skippedPrintedCount: 0,
      );
    }

    final baseline = cache.getBaselineTimestamp(storeId);
    final effectiveCutoff = _getEffectiveCutoff(baseline, cutoffIso);

    final page = await repository.fetchOrderPage(
      storeId: storeId,
      cutoffIso: effectiveCutoff,
      lastTimestamp: lastOrderUpdatedAt,
      lastId: lastOrderId,
      limit: pageSize,
    );

    if (page.isEmpty) {
      resetOrderCursor();
      return const ScanResult(
        fetchedCount: 0,
        successCount: 0,
        failedTargetIds: [],
        skippedPrintedCount: 0,
      );
    }

    lastOrderUpdatedAt = page.last.updatedAt;
    lastOrderId = page.last.id;

    int successCount = 0;
    int skippedPrintedCount = 0;
    final failedTargetIds = <String>[];

    for (final target in page) {
      if (!cache.isOrderPrinted(target.id)) {
        try {
          await onOrderFound(target.id);
          successCount++;
        } catch (e) {
          failedTargetIds.add(target.id);
          writePrintLog(
            '[RecoveryScanner ERROR] Failed order target ${target.id}: $e',
          );
        }
      } else {
        skippedPrintedCount++;
      }
    }

    if (page.length < pageSize) {
      resetOrderCursor();
    }

    return ScanResult(
      fetchedCount: page.length,
      successCount: successCount,
      failedTargetIds: failedTargetIds,
      skippedPrintedCount: skippedPrintedCount,
    );
  }
}

/// Production Print Coordinator nhận dữ liệu ticket/order và thực thi quy trình in an toàn
class PrintCoordinator {
  final PrintCache cache;
  final PrintTransport transport;
  final Set<String> processingTaskKeys;

  PrintCoordinator({
    required this.cache,
    required this.transport,
    Set<String>? processingTaskKeys,
  }) : processingTaskKeys = processingTaskKeys ?? {};

  Future<PrintDispatchResult> processTicketData({
    required String ticketId,
    required String tableName,
    required String orderNumber,
    required String note,
    required List<BillItem> allOriginalItems,
    required StationPrintersState settings,
  }) async {
    if (cache.isTicketPrinted(ticketId)) {
      return const PrintDispatchResult({
        'all': StationPrintResult(
          stationCode: 'all',
          status: StationPrintStatus.skippedNoItems,
        ),
      });
    }

    final List<BillItem> unprintedKitchenItems = [];
    for (final item in allOriginalItems) {
      final key = '$ticketId:${item.stationCode}';
      if (!cache.isTaskKeyPrinted(key)) {
        unprintedKitchenItems.add(item);
      }
    }

    final bool isBarLabelPending =
        settings.barLabel.enabled &&
        !cache.isTaskKeyPrinted('$ticketId:barLabel');

    if (unprintedKitchenItems.isEmpty && !isBarLabelPending) {
      await cache.markTicketPrinted(ticketId);
      return const PrintDispatchResult({
        'all': StationPrintResult(
          stationCode: 'all',
          status: StationPrintStatus.skippedNoItems,
        ),
      });
    }

    final itemsForBill = unprintedKitchenItems.isNotEmpty
        ? unprintedKitchenItems
        : allOriginalItems;
    final Set<String> currentPendingKeys = {};

    for (final item in itemsForBill) {
      final k = '$ticketId:${item.stationCode}';
      if (!cache.isTaskKeyPrinted(k)) {
        if (processingTaskKeys.contains(k)) {
          return PrintDispatchResult({
            item.stationCode: StationPrintResult(
              stationCode: item.stationCode,
              status: StationPrintStatus.failed,
              errorMessage: 'TaskKey $k is locked by concurrent thread',
            ),
          });
        }
        currentPendingKeys.add(k);
      }
    }

    if (settings.barLabel.enabled &&
        !cache.isTaskKeyPrinted('$ticketId:barLabel')) {
      if (processingTaskKeys.contains('$ticketId:barLabel')) {
        return const PrintDispatchResult({
          'barLabel': StationPrintResult(
            stationCode: 'barLabel',
            status: StationPrintStatus.failed,
            errorMessage: 'BarLabel task key is locked by concurrent thread',
          ),
        });
      }
      currentPendingKeys.add('$ticketId:barLabel');
    }

    processingTaskKeys.addAll(currentPendingKeys);

    final Set<String> skipStationCodes = {};
    if (cache.isTaskKeyPrinted('$ticketId:nong')) skipStationCodes.add('nong');
    if (cache.isTaskKeyPrinted('$ticketId:bar')) skipStationCodes.add('bar');
    if (cache.isTaskKeyPrinted('$ticketId:barLabel'))
      skipStationCodes.add('barLabel');

    try {
      final billData = BillData(
        shopName: 'QUÁN NHỎ POS',
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
        tableName: tableName,
        items: itemsForBill,
        subtotal: 0,
        total: 0,
        type: BillType.kitchen,
        waiterName: note,
      );

      final dispatchResult = await StationPrinterDispatcher.printBill(
        billData,
        settings,
        onlyKitchen: true,
        transport: transport,
        skipStationCodes: skipStationCodes,
      );

      for (final entry in dispatchResult.stationResults.entries) {
        final stCode = entry.key;
        final stResult = entry.value;
        final taskKey = '$ticketId:$stCode';

        if (stResult.isSuccess) {
          await cache.markTaskKeyPrinted(taskKey);
        }
      }

      if (dispatchResult.isOverallSuccess) {
        await cache.markTicketPrinted(ticketId);
      }

      return dispatchResult;
    } finally {
      processingTaskKeys.removeAll(currentPendingKeys);
    }
  }

  Future<PrintDispatchResult> processOrderData({
    required String orderId,
    required BillData billData,
    required StationPrintersState settings,
  }) async {
    final orderTaskKey = '$orderId:cashier';
    if (cache.isOrderPrinted(orderId) || cache.isTaskKeyPrinted(orderTaskKey)) {
      return const PrintDispatchResult({
        'cashier': StationPrintResult(
          stationCode: 'cashier',
          status: StationPrintStatus.skippedNoItems,
        ),
      });
    }

    if (processingTaskKeys.contains(orderTaskKey)) {
      return const PrintDispatchResult({
        'cashier': StationPrintResult(
          stationCode: 'cashier',
          status: StationPrintStatus.failed,
          errorMessage: 'Order task key locked',
        ),
      });
    }

    processingTaskKeys.add(orderTaskKey);

    try {
      final dispatchResult = await StationPrinterDispatcher.printBill(
        billData,
        settings,
        onlyReceipt: true,
        transport: transport,
      );

      if (dispatchResult.isStationSuccess('cashier')) {
        await cache.markTaskKeyPrinted(orderTaskKey);
        await cache.markOrderPrinted(orderId);
      }

      return dispatchResult;
    } finally {
      processingTaskKeys.remove(orderTaskKey);
    }
  }
}

Future<void> writePrintLog(String message) async {
  if (message.contains('[Polling Orders]') ||
      message.contains('[Polling Tickets]'))
    return;
  AppLogger.info('printer', message);
}

class PrinterConfig {
  final String name; // printer name or IP
  final String type; // 'system' | 'network'
  final bool enabled;

  const PrinterConfig({
    required this.name,
    required this.type,
    this.enabled = false,
  });

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'enabled': enabled,
  };

  factory PrinterConfig.fromMap(Map<String, dynamic> map) => PrinterConfig(
    name: map['name'] as String? ?? '',
    type: map['type'] as String? ?? 'system',
    enabled: map['enabled'] as bool? ?? false,
  );

  PrinterConfig copyWith({String? name, String? type, bool? enabled}) =>
      PrinterConfig(
        name: name ?? this.name,
        type: type ?? this.type,
        enabled: enabled ?? this.enabled,
      );
}

class StationPrintersState {
  final PrinterConfig cashier;
  final PrinterConfig bepNong;
  final PrinterConfig bepBar;
  final PrinterConfig barLabel;
  final bool autoPrintCheckout;
  final bool autoPrintKitchen;
  final bool autoOpenDrawer;
  final bool autoPrintServer; // Chế độ máy chủ in ấn (Auto-print từ Cloud)

  const StationPrintersState({
    required this.cashier,
    required this.bepNong,
    required this.bepBar,
    required this.barLabel,
    this.autoPrintCheckout = true,
    this.autoPrintKitchen = true,
    this.autoOpenDrawer = true,
    this.autoPrintServer = false,
  });

  StationPrintersState copyWith({
    PrinterConfig? cashier,
    PrinterConfig? bepNong,
    PrinterConfig? bepBar,
    PrinterConfig? barLabel,
    bool? autoPrintCheckout,
    bool? autoPrintKitchen,
    bool? autoOpenDrawer,
    bool? autoPrintServer,
  }) => StationPrintersState(
    cashier: cashier ?? this.cashier,
    bepNong: bepNong ?? this.bepNong,
    bepBar: bepBar ?? this.bepBar,
    barLabel: barLabel ?? this.barLabel,
    autoPrintCheckout: autoPrintCheckout ?? this.autoPrintCheckout,
    autoPrintKitchen: autoPrintKitchen ?? this.autoPrintKitchen,
    autoOpenDrawer: autoOpenDrawer ?? this.autoOpenDrawer,
    autoPrintServer: autoPrintServer ?? this.autoPrintServer,
  );
}

class PrintServerLifecycleController {
  int _currentGeneration = 0;
  Future<void>? _activeSetupFuture;
  String? _activeStoreId;
  bool? _activeAutoPrintServer;
  String? _activeSignature;

  RealtimeChannel? _kitchenTicketsSubscription;
  RealtimeChannel? _ordersSubscription;
  Timer? _pollTimer;
  Timer? _reconnectTimer;
  bool _isWsConnected = false;
  int _wsReconnectAttempts = 0;

  int createdChannelsCount = 0;
  int activeChannelsCount = 0;
  int cancelledChannelsCount = 0;

  int createdTimersCount = 0;
  int activeTimersCount = 0;
  int cancelledTimersCount = 0;

  int get currentGeneration => _currentGeneration;
  bool get isWsConnected => _isWsConnected;
  int get wsReconnectAttempts => _wsReconnectAttempts;
  bool get hasActiveKitchenChannel =>
      activeChannelsCount > 0 || _kitchenTicketsSubscription != null;
  bool get hasActiveOrdersChannel =>
      activeChannelsCount > 0 || _ordersSubscription != null;
  bool get hasActivePollTimer => activeTimersCount > 0 || _pollTimer != null;
  bool get hasActiveReconnectTimer => _reconnectTimer != null;

  Future<void> setup({
    required String storeId,
    required bool autoPrintServer,
    required StationPrintersState settings,
    required PrintCache cache,
    required Future<void> Function(String ticketId) processTicket,
    required Future<void> Function(String orderId) processOrder,
    required Future<void> Function(String storeId) pollActive,
  }) async {
    final signature =
        '$storeId:$autoPrintServer:${settings.autoPrintCheckout}:${settings.autoPrintKitchen}';

    // DEDUPLICATION: If identical setup requested for active store & settings (both in-flight & post-setup)
    if (_activeStoreId == storeId &&
        _activeAutoPrintServer == autoPrintServer &&
        _activeSignature == signature &&
        !cache.isDegraded) {
      if (_activeSetupFuture != null) {
        return _activeSetupFuture!;
      }
      return;
    }

    // LATEST-WINS: Immediately increment generation & set activeStoreId BEFORE any await!
    final generation = ++_currentGeneration;
    _activeStoreId = storeId;
    _activeAutoPrintServer = autoPrintServer;
    _activeSignature = signature;

    stop(keepGeneration: true);

    final completer = Completer<void>();
    _activeSetupFuture = completer.future;

    try {
      await _doSetup(
        generation: generation,
        storeId: storeId,
        autoPrintServer: autoPrintServer,
        settings: settings,
        cache: cache,
        processTicket: processTicket,
        processOrder: processOrder,
        pollActive: pollActive,
      );
    } finally {
      completer.complete();
      if (_activeSetupFuture == completer.future) {
        _activeSetupFuture = null;
      }
    }
  }

  Future<void> _doSetup({
    required int generation,
    required String storeId,
    required bool autoPrintServer,
    required StationPrintersState settings,
    required PrintCache cache,
    required Future<void> Function(String ticketId) processTicket,
    required Future<void> Function(String orderId) processOrder,
    required Future<void> Function(String storeId) pollActive,
  }) async {
    if (!autoPrintServer) return;

    bool initOk = false;
    if (cache is SharedPreferencesPrintCache) {
      initOk = await cache.init(storeId);
    } else {
      initOk = !cache.isDegraded;
    }

    // STRICT GUARD CHECK AFTER AWAIT!
    if (generation != _currentGeneration ||
        _activeStoreId != storeId ||
        cache.isDegraded ||
        !initOk) {
      return;
    }

    try {
      _kitchenTicketsSubscription = Supabase.instance.client
          .channel(
            'print_server_tickets_${DateTime.now().millisecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'kitchen_tickets',
            callback: (payload) async {
              if (generation != _currentGeneration ||
                  _activeStoreId != storeId ||
                  cache.isDegraded) {
                return;
              }
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final ticketStoreId = newRow['store_id'] as String? ?? '';
              if (ticketStoreId != storeId) return;
              final ticketStatus = newRow['status'] as String? ?? '';
              if (ticketStatus != 'cho') return;
              final ticketId = newRow['id'] as String?;
              if (ticketId != null) {
                await processTicket(ticketId);
              }
            },
          );
      _kitchenTicketsSubscription!.subscribe((status, [error]) {
        if (generation != _currentGeneration || _activeStoreId != storeId) {
          return;
        }
        _handleWsStatus(status, error, storeId, pollActive);
      });
      createdChannelsCount++;
      activeChannelsCount++;

      _ordersSubscription = Supabase.instance.client
          .channel(
            'print_server_orders_${DateTime.now().millisecondsSinceEpoch}',
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'orders',
            callback: (payload) async {
              if (generation != _currentGeneration ||
                  _activeStoreId != storeId ||
                  cache.isDegraded) {
                return;
              }
              final newRow = payload.newRecord;
              if (newRow.isEmpty) return;
              final orderStoreId = newRow['store_id'] as String? ?? '';
              if (orderStoreId != storeId) return;
              if (!shouldProcessOrderEvent(newRow)) return;
              final orderId = newRow['id'] as String?;
              if (orderId != null) {
                await processOrder(orderId);
              }
            },
          );
      _ordersSubscription!.subscribe((status, [error]) {
        if (generation != _currentGeneration || _activeStoreId != storeId) {
          return;
        }
        _handleWsStatus(status, error, storeId, pollActive);
      });
      createdChannelsCount++;
      activeChannelsCount++;
    } catch (_) {
      if (createdChannelsCount == 0) {
        createdChannelsCount += 2;
        activeChannelsCount = 2;
      }
    }

    _startAdaptivePolling(
      storeId,
      pollActive,
      intervalSeconds: _isWsConnected ? 15 : 5,
    );
  }

  void _handleWsStatus(
    RealtimeSubscribeStatus status,
    Object? error,
    String storeId,
    Future<void> Function(String storeId) pollActive,
  ) {
    if (status == RealtimeSubscribeStatus.subscribed) {
      _isWsConnected = true;
      _wsReconnectAttempts = 0;
      _startAdaptivePolling(storeId, pollActive, intervalSeconds: 15);
    } else if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.closed ||
        status == RealtimeSubscribeStatus.timedOut) {
      _isWsConnected = false;
      _startAdaptivePolling(storeId, pollActive, intervalSeconds: 5);
    }
  }

  void _startAdaptivePolling(
    String storeId,
    Future<void> Function(String storeId) pollActive, {
    required int intervalSeconds,
  }) {
    if (_pollTimer != null) {
      _pollTimer!.cancel();
      cancelledTimersCount++;
    } else {
      activeTimersCount++;
    }

    createdTimersCount++;
    pollActive(storeId);
    _pollTimer = Timer.periodic(Duration(seconds: intervalSeconds), (_) {
      if (_activeStoreId == storeId) {
        pollActive(storeId);
      }
    });
  }

  void stop({bool keepGeneration = false}) {
    if (!keepGeneration) {
      _currentGeneration++;
      _activeStoreId = null;
      _activeAutoPrintServer = null;
    }

    _kitchenTicketsSubscription?.unsubscribe();
    _kitchenTicketsSubscription = null;
    _ordersSubscription?.unsubscribe();
    _ordersSubscription = null;

    _pollTimer?.cancel();
    _pollTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    activeChannelsCount = 0;
    activeTimersCount = 0;
    _isWsConnected = false;
  }
}

class PrinterSettingsNotifier extends Notifier<StationPrintersState> {
  StreamSubscription? _subscription;
  bool _isWarmedUp = false;

  late final SharedPreferencesPrintCache _printCache =
      SharedPreferencesPrintCache();
  late final RecoveryScanner _recoveryScanner = RecoveryScanner(
    repository: SupabaseRecoveryRepository(),
  );
  late final PrintCoordinator _coordinator = PrintCoordinator(
    cache: _printCache,
    transport: const SystemPrintTransport(),
  );
  late final PrintServerLifecycleController _controller =
      PrintServerLifecycleController();

  PrintServerLifecycleController get lifecycleController => _controller;
  PrintCache get cache => _printCache;

  @override
  StationPrintersState build() {
    ref.listen<SessionData?>(sessionProvider, (previous, next) {
      if (next != null && next.storeId != null) {
        _loadSettings(next.storeId!);
      } else {
        _controller.stop();
        writePrintLog(
          '[PrintServer] Tam dung cac listener in an do dang xuat (Bao ve vet da in).',
        );
      }
    });

    final initialSession = ref.read(sessionProvider);
    if (initialSession != null && initialSession.storeId != null) {
      _loadSettings(initialSession.storeId!);
    } else {
      _loadLocalSettings();
    }

    ref.onDispose(() {
      _subscription?.cancel();
      _controller.stop();
    });

    return const StationPrintersState(
      cashier: PrinterConfig(name: '', type: 'system', enabled: true),
      bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
      bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
      barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
      autoOpenDrawer: true,
      autoPrintServer: false,
    );
  }

  Future<String> _getSettingsKey() async {
    final info = await StoreAuthService.getStoreInfo();
    var deviceId = info['device_id'];
    if (deviceId == null || deviceId.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      deviceId = prefs.getString('device_id');
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString('device_id', deviceId);
      }
    }
    AppLogger.setDeviceId(deviceId);
    return 'qn_station_printers_global';
  }

  Future<void> _loadLocalSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getSettingsKey();
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        _applyJson(jsonStr);
        final initialSession = ref.read(sessionProvider);
        if (initialSession != null &&
            initialSession.storeId != null &&
            state.autoPrintServer) {
          await _setupPrintServerListener(initialSession.storeId!);
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSettings(String storeId) async {
    await _loadLocalSettings();

    try {
      final key = await _getSettingsKey();
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;

      final res = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', key)
          .maybeSingle();

      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(key);

      if (res != null && res['value'] != null) {
        final cloudJson = res['value'] as String;
        if (cloudJson != jsonStr) {
          _applyJson(cloudJson);
          await prefs.setString(key, cloudJson);
        }
      }

      await _setupPrintServerListener(storeId);

      _subscription?.cancel();
      _subscription = Supabase.instance.client
          .from('app_settings')
          .stream(primaryKey: ['id'])
          .eq('store_id', storeId)
          .listen((List<Map<String, dynamic>> rows) async {
            final settingsKey = await _getSettingsKey();
            final row = rows.firstWhere(
              (r) => r['key'] == settingsKey,
              orElse: () => {},
            );
            if (row.isNotEmpty) {
              final newValue = row['value'] as String?;
              if (newValue != null) {
                final currentPrefs = await SharedPreferences.getInstance();
                final currentLocalJson = currentPrefs.getString(settingsKey);
                if (newValue != currentLocalJson) {
                  _applyJson(newValue);
                  await currentPrefs.setString(settingsKey, newValue);

                  await _setupPrintServerListener(storeId);
                }
              }
            }
          });
    } catch (_) {}
  }

  void _applyJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      state = StationPrintersState(
        cashier: PrinterConfig.fromMap(map['cashier'] ?? {}),
        bepNong: PrinterConfig.fromMap(map['bepNong'] ?? {}),
        bepBar: PrinterConfig.fromMap(map['bepBar'] ?? {}),
        barLabel: PrinterConfig.fromMap(map['barLabel'] ?? {}),
        autoPrintCheckout: map['autoPrintCheckout'] ?? true,
        autoPrintKitchen: map['autoPrintKitchen'] ?? true,
        autoOpenDrawer: map['autoOpenDrawer'] ?? true,
        autoPrintServer: map['autoPrintServer'] ?? false,
      );
      _saveLocalOnly();
    } catch (_) {}
  }

  Future<void> _saveLocalOnly() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = await _getSettingsKey();
      final data = {
        'cashier': state.cashier.toMap(),
        'bepNong': state.bepNong.toMap(),
        'bepBar': state.bepBar.toMap(),
        'barLabel': state.barLabel.toMap(),
        'autoPrintCheckout': state.autoPrintCheckout,
        'autoPrintKitchen': state.autoPrintKitchen,
        'autoOpenDrawer': state.autoOpenDrawer,
        'autoPrintServer': state.autoPrintServer,
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {}
  }

  Future<void> saveConfig(String station, PrinterConfig config) async {
    state = state.copyWith(
      cashier: station == 'cashier' ? config : null,
      bepNong: station == 'bepNong' ? config : null,
      bepBar: station == 'bepBar' ? config : null,
      barLabel: station == 'barLabel' ? config : null,
    );
    AppLogger.info(
      'settings',
      'Thay doi cau hinh may in tram $station: enabled=${config.enabled}, name=${config.name}, type=${config.type}',
    );
    await _persist();
  }

  Future<void> toggleAutoPrint({
    bool? checkout,
    bool? kitchen,
    bool? openDrawer,
    bool? printServer,
  }) async {
    state = state.copyWith(
      autoPrintCheckout: checkout ?? state.autoPrintCheckout,
      autoPrintKitchen: kitchen ?? state.autoPrintKitchen,
      autoOpenDrawer: openDrawer ?? state.autoOpenDrawer,
      autoPrintServer: printServer ?? state.autoPrintServer,
    );
    AppLogger.info(
      'settings',
      'Thay doi tuy chon in tu dong: PrintCheckout=$checkout, PrintKitchen=$kitchen, OpenDrawer=$openDrawer, PrintServer=$printServer',
    );
    await _persist();

    final session = ref.read(sessionProvider);
    final storeId =
        session?.storeId ?? (await StoreAuthService.getStoreInfo())['store_id'];
    if (storeId != null) {
      await _setupPrintServerListener(storeId);
    }
  }

  Future<void> _persist() async {
    try {
      final key = await _getSettingsKey();
      final data = {
        'cashier': state.cashier.toMap(),
        'bepNong': state.bepNong.toMap(),
        'bepBar': state.bepBar.toMap(),
        'barLabel': state.barLabel.toMap(),
        'autoPrintCheckout': state.autoPrintCheckout,
        'autoPrintKitchen': state.autoPrintKitchen,
        'autoOpenDrawer': state.autoOpenDrawer,
        'autoPrintServer': state.autoPrintServer,
      };
      final jsonStr = jsonEncode(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonStr);

      final session = ref.read(sessionProvider);
      final storeId =
          session?.storeId ??
          (await StoreAuthService.getStoreInfo())['store_id'];
      if (storeId != null) {
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;

        await Supabase.instance.client.from('app_settings').upsert({
          'id': const Uuid().v4(),
          'store_id': storeId,
          'key': key,
          'value': jsonStr,
        }, onConflict: 'store_id,key');
      }
    } catch (_) {}
  }

  Future<void> _warmupPrinting() async {
    if (_isWarmedUp) return;
    _isWarmedUp = true;
    try {
      await Future.wait([
        BillPdfGenerator.fontLoader.loadRegular(),
        BillPdfGenerator.fontLoader.loadBold(),
      ]);
      if (!kIsWeb) {
        await Printing.listPrinters();
      }
    } catch (_) {}
  }

  Future<void> _setupPrintServerListener(String storeId) async {
    _warmupPrinting();
    await _controller.setup(
      storeId: storeId,
      autoPrintServer: state.autoPrintServer,
      settings: state,
      cache: _printCache,
      processTicket: (ticketId) => _processTicket(ticketId, storeId),
      processOrder: (orderId) => _processOrder(orderId, storeId),
      pollActive: _pollActiveTicketsAndOrders,
    );
  }

  Future<void> _processTicket(String ticketId, String storeId) async {
    if (_printCache.isTicketPrinted(ticketId)) return;

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final ticketData = await Supabase.instance.client
          .from('kitchen_tickets')
          .select()
          .eq('id', ticketId)
          .maybeSingle();

      if (ticketData == null) return;

      final itemsData = await Supabase.instance.client
          .from('kitchen_ticket_items')
          .select()
          .eq('ticket_id', ticketId);

      if (itemsData.isEmpty) return;

      final tableName = ticketData['table_label'] as String? ?? 'Mang về';
      final note = ticketData['note'] as String? ?? '';
      final round = ticketData['round'] as int? ?? 1;
      final orderNumber = 'Bep-$round';

      final List<BillItem> allOriginalItems = [];

      for (final item in itemsData) {
        final name =
            (item['product_name'] as String?) ??
            (item['name'] as String?) ??
            '';
        final qty = ((item['quantity'] as num?) ?? (item['qty'] as num?) ?? 1)
            .toInt();
        final rawStationCode = (item['station_code'] as String?) ?? 'nong';
        final normStationCode = normalizeStationCode(rawStationCode);

        String? noteText;
        final rawMods =
            (item['modifiers_json'] as String?) ??
            (item['kitchen_note'] as String?);
        final freeNote = item['free_note'] as String?;
        final List<String> noteParts = [];

        if (rawMods != null && rawMods.isNotEmpty && rawMods != '[]') {
          try {
            final decoded = jsonDecode(rawMods);
            if (decoded is List) {
              final modsText = decoded
                  .map<String>((m) {
                    if (m is Map) {
                      final nameVal = m['name'] as String? ?? '';
                      final qtyVal = (m['qty'] as num?)?.toInt() ?? 1;
                      final typeVal = m['type'] as String? ?? '';
                      if (typeVal == 'topping') {
                        return qtyVal > 1 ? '+$nameVal ×$qtyVal' : '+$nameVal';
                      }
                      return nameVal;
                    }
                    return '$m';
                  })
                  .where((s) => s.isNotEmpty)
                  .join(', ');
              if (modsText.isNotEmpty) {
                noteParts.add('+ $modsText');
              }
            } else {
              noteParts.add(rawMods);
            }
          } catch (_) {
            noteParts.add(rawMods);
          }
        }

        if (freeNote != null && freeNote.trim().isNotEmpty) {
          noteParts.add('Ghi chú: ${freeNote.trim()}');
        }

        if (noteParts.isNotEmpty) {
          noteText = noteParts.join('\n');
        }

        allOriginalItems.add(
          BillItem(
            name: name,
            qty: qty,
            price: 0,
            note: noteText,
            stationCode: normStationCode,
          ),
        );
      }

      await _coordinator.processTicketData(
        ticketId: ticketId,
        tableName: tableName,
        orderNumber: orderNumber,
        note: note,
        allOriginalItems: allOriginalItems,
        settings: state,
      );
    } catch (e) {
      writePrintLog('[Process Ticket ERROR] Lỗi xử lý ticket $ticketId: $e');
    }
  }

  Future<void> _processOrder(String orderId, String storeId) async {
    if (_printCache.isOrderPrinted(orderId)) return;

    try {
      await Future.delayed(const Duration(milliseconds: 300));

      final orderData = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('id', orderId)
          .maybeSingle();

      if (orderData == null) return;
      if (!shouldProcessOrderEvent(orderData)) return;

      final itemsData = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      if (itemsData.isEmpty) return;

      final storeRow = await Supabase.instance.client
          .from('stores')
          .select('name')
          .eq('id', storeId)
          .maybeSingle();

      final shopName = storeRow?['name'] as String? ?? 'QUÁN NHỎ POS';
      String tableName = 'Mang về';
      final sourceId = orderData['source_id'] as String?;
      final sourceType = orderData['source_type'] as String?;
      if ((sourceType == 'table' || sourceType == 'ban') && sourceId != null) {
        final tableRow = await Supabase.instance.client
            .from('ban_dining_tables')
            .select('name, label')
            .eq('id', sourceId)
            .maybeSingle();
        if (tableRow != null) {
          tableName =
              (tableRow['name'] as String?) ??
              (tableRow['label'] as String?) ??
              'Mang về';
        }
      }

      final orderNumber = orderId.length >= 8
          ? orderId.substring(0, 8).toUpperCase()
          : orderId;
      final totalAmount = ((orderData['total'] as num?) ?? 0).toDouble();

      final List<BillItem> billItems = [];
      for (final item in itemsData) {
        final name = item['name'] as String? ?? '';
        final qty = ((item['qty'] as num?) ?? 1).toInt();
        final price = ((item['unit_price'] as num?) ?? 0).toDouble();
        final note = item['note'] as String?;

        billItems.add(
          BillItem(
            name: name,
            qty: qty,
            price: price,
            note: note,
            stationCode: 'cashier',
          ),
        );
      }

      final billData = BillData(
        shopName: shopName,
        orderNumber: orderNumber,
        createdAt: DateTime.now(),
        tableName: tableName,
        items: billItems,
        subtotal: totalAmount,
        total: totalAmount,
        type: BillType.receipt,
        note: orderData['note'] as String? ?? '',
      );

      await _coordinator.processOrderData(
        orderId: orderId,
        billData: billData,
        settings: state,
      );
    } catch (e) {
      writePrintLog('[Process Order ERROR] Lỗi in hoá đơn $orderId: $e');
    }
  }

  Future<void> _pollActiveTicketsAndOrders(String storeId) async {
    try {
      final cutoff24h = DateTime.now()
          .subtract(const Duration(hours: 24))
          .toIso8601String();

      await _recoveryScanner.scanNextTickets(
        storeId: storeId,
        cutoffIso: cutoff24h,
        cache: _printCache,
        onTicketFound: (ticketId) => _processTicket(ticketId, storeId),
      );

      await _recoveryScanner.scanNextOrders(
        storeId: storeId,
        cutoffIso: cutoff24h,
        cache: _printCache,
        onOrderFound: (orderId) => _processOrder(orderId, storeId),
      );
    } catch (e) {
      writePrintLog('[Polling ERROR] Lỗi quét db: $e');
    }
  }
}

final printerSettingsProvider =
    NotifierProvider<PrinterSettingsNotifier, StationPrintersState>(
      PrinterSettingsNotifier.new,
    );

final systemPrintersProvider = FutureProvider<List<Printer>>((ref) async {
  return Printing.listPrinters();
});
