import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/permission_provider.dart';
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

bool shouldAutoPrintLocally({
  required bool isWeb,
  required bool centralRoutingEnabled,
  required bool hasPrintServerOwner,
  required bool allowPrintServerFallback,
}) =>
    !isWeb &&
    (!centralRoutingEnabled ||
        (!hasPrintServerOwner && allowPrintServerFallback));

const Duration kPrintServerOwnerHeartbeatTtl = Duration(seconds: 45);

DateTime? _tryParseOwnerTimestamp(String value) {
  if (value.isEmpty) return null;
  try {
    return DateTime.parse(value).toUtc();
  } catch (_) {
    return null;
  }
}

bool shouldBootstrapLegacyOwner({
  required bool isWeb,
  required bool ownerMigrationCompleted,
  required bool legacyAutoPrintServer,
  required bool hasOwner,
}) => !isWeb && !ownerMigrationCompleted && legacyAutoPrintServer && !hasOwner;

bool shouldRestorePrintServerOwner({
  required bool isWeb,
  required bool centralRoutingEnabled,
  required bool hasOwner,
  required bool deviceMarkedPrintServer,
  required bool allowBackgroundPrinting,
  required String currentDeviceId,
}) =>
    !isWeb &&
    centralRoutingEnabled &&
    !hasOwner &&
    deviceMarkedPrintServer &&
    allowBackgroundPrinting &&
    currentDeviceId.isNotEmpty;

bool shouldSyncOwnerClaimTokenToDesignatedDevice({
  required bool isWeb,
  required bool deviceMarkedPrintServer,
  required bool allowBackgroundPrinting,
  required String currentDeviceId,
  required String ownerDeviceId,
  required String ownerClaimToken,
}) =>
    !isWeb &&
    deviceMarkedPrintServer &&
    allowBackgroundPrinting &&
    currentDeviceId.isNotEmpty &&
    ownerDeviceId == currentDeviceId &&
    ownerClaimToken.isNotEmpty;

bool shouldPromoteStalePrintServerOwner({
  required bool isWeb,
  required bool isCurrentPlatformWindows,
  required bool centralRoutingEnabled,
  required bool hasStaleOwner,
  required bool deviceMarkedPrintServer,
  required bool allowBackgroundPrinting,
  required bool hasAnyEnabledPrinter,
  required String currentDeviceId,
}) =>
    !isWeb &&
    isCurrentPlatformWindows &&
    centralRoutingEnabled &&
    hasStaleOwner &&
    deviceMarkedPrintServer &&
    allowBackgroundPrinting &&
    hasAnyEnabledPrinter &&
    currentDeviceId.isNotEmpty;

bool shouldHardLockWindowsPrintCoordinator({
  required bool isWeb,
  required bool isWindows,
  required bool centralRoutingEnabled,
  required bool hasAnyEnabledPrinter,
}) => !isWeb && isWindows && centralRoutingEnabled && hasAnyEnabledPrinter;

class PrintDeviceState {
  final String deviceName;
  final bool isPrintServer;
  final bool allowBackgroundPrinting;
  final String localClaimToken;

  const PrintDeviceState({
    required this.deviceName,
    this.isPrintServer = false,
    this.allowBackgroundPrinting = false,
    this.localClaimToken = '',
  });

  Map<String, dynamic> toMap() => {
    'deviceName': deviceName,
    'isPrintServer': kIsWeb ? false : isPrintServer,
    'allowBackgroundPrinting': kIsWeb ? false : allowBackgroundPrinting,
    'localClaimToken': localClaimToken,
  };

  factory PrintDeviceState.fromMap(
    Map<String, dynamic> map, {
    String defaultDeviceName = 'Thiết bị POS',
    bool? isWebOverride,
  }) {
    final isWebEnv = isWebOverride ?? kIsWeb;
    if (isWebEnv) {
      return PrintDeviceState(
        deviceName: map['deviceName'] as String? ?? 'Web Browser',
        isPrintServer: false,
        allowBackgroundPrinting: false,
        localClaimToken: '',
      );
    }
    return PrintDeviceState(
      deviceName: map['deviceName'] as String? ?? defaultDeviceName,
      isPrintServer: map['isPrintServer'] as bool? ?? false,
      allowBackgroundPrinting: map['allowBackgroundPrinting'] as bool? ?? false,
      localClaimToken: map['localClaimToken'] as String? ?? '',
    );
  }

  PrintDeviceState copyWith({
    String? deviceName,
    bool? isPrintServer,
    bool? allowBackgroundPrinting,
    String? localClaimToken,
    bool? isWebOverride,
  }) {
    final isWebEnv = isWebOverride ?? kIsWeb;
    if (isWebEnv) {
      return PrintDeviceState(
        deviceName: deviceName ?? this.deviceName,
        isPrintServer: false,
        allowBackgroundPrinting: false,
        localClaimToken: '',
      );
    }
    return PrintDeviceState(
      deviceName: deviceName ?? this.deviceName,
      isPrintServer: isPrintServer ?? this.isPrintServer,
      allowBackgroundPrinting:
          allowBackgroundPrinting ?? this.allowBackgroundPrinting,
      localClaimToken: localClaimToken ?? this.localClaimToken,
    );
  }
}

class PrintServerOwnerState {
  final String deviceId;
  final String deviceName;
  final String platform;
  final String claimedAt;
  final String claimToken;
  final String lastSeenAt;

  const PrintServerOwnerState({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.claimedAt,
    required this.claimToken,
    this.lastSeenAt = '',
  });

  DateTime? get claimedAtUtc => _tryParseOwnerTimestamp(claimedAt);
  DateTime? get lastSeenAtUtc => _tryParseOwnerTimestamp(lastSeenAt);

  Map<String, dynamic> toMap() => {
    'device_id': deviceId,
    'device_name': deviceName,
    'platform': platform,
    'claimed_at': claimedAt,
    'claim_token': claimToken,
    'last_seen_at': lastSeenAt,
  };

  PrintServerOwnerState copyWith({
    String? deviceId,
    String? deviceName,
    String? platform,
    String? claimedAt,
    String? claimToken,
    String? lastSeenAt,
  }) {
    return PrintServerOwnerState(
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      platform: platform ?? this.platform,
      claimedAt: claimedAt ?? this.claimedAt,
      claimToken: claimToken ?? this.claimToken,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  factory PrintServerOwnerState.fromMap(Map<String, dynamic> map) {
    return PrintServerOwnerState(
      deviceId: map['device_id'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? 'Máy chủ in',
      platform: map['platform'] as String? ?? 'unknown',
      claimedAt: map['claimed_at'] as String? ?? '',
      claimToken: map['claim_token'] as String? ?? '',
      lastSeenAt:
          map['last_seen_at'] as String? ?? map['claimed_at'] as String? ?? '',
    );
  }

  factory PrintServerOwnerState.fromJsonString(String jsonStr) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return PrintServerOwnerState.fromMap(map);
  }
}

bool isPrintServerOwnerFresh(
  PrintServerOwnerState owner, {
  DateTime? now,
  Duration ttl = kPrintServerOwnerHeartbeatTtl,
}) {
  final referenceTime = owner.lastSeenAtUtc ?? owner.claimedAtUtc;
  if (referenceTime == null) return false;
  final age = (now ?? DateTime.now().toUtc()).difference(referenceTime);
  return age <= ttl;
}

bool hasActivePrintServerOwner(
  PrintServerOwnerState? owner, {
  DateTime? now,
  Duration ttl = kPrintServerOwnerHeartbeatTtl,
}) {
  if (owner == null) return false;
  return isPrintServerOwnerFresh(owner, now: now, ttl: ttl);
}

abstract class PrintServerOwnerRepository {
  Future<PrintServerOwnerState?> getOwner(String storeId);
  Future<bool> claimOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  });
  Future<bool> transferOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  });
  Future<bool> releaseOwner({
    required String storeId,
    required String deviceId,
    required String expectedToken,
  });
}

class SupabasePrintServerOwnerRepository implements PrintServerOwnerRepository {
  static const String kOwnerV1Key = 'qn_print_server_owner_v1';

  @override
  Future<PrintServerOwnerState?> getOwner(String storeId) async {
    Supabase.instance.client.rest.headers['x-store-id'] = storeId;
    final row = await Supabase.instance.client
        .from('app_settings')
        .select('value')
        .eq('store_id', storeId)
        .eq('key', kOwnerV1Key)
        .maybeSingle();

    if (row != null && row['value'] != null) {
      return PrintServerOwnerState.fromJsonString(row['value'] as String);
    }
    return null;
  }

  @override
  Future<bool> claimOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async {
    try {
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;
      final rawJson = jsonEncode(owner.toMap());
      await Supabase.instance.client.from('app_settings').insert({
        'id': const Uuid().v4(),
        'store_id': storeId,
        'key': kOwnerV1Key,
        'value': rawJson,
      });

      final readBack = await getOwner(storeId);
      return readBack != null &&
          readBack.deviceId == owner.deviceId &&
          readBack.claimToken == owner.claimToken;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> transferOwner({
    required String storeId,
    required PrintServerOwnerState owner,
  }) async {
    try {
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;
      final rawJson = jsonEncode(owner.toMap());
      await Supabase.instance.client.from('app_settings').upsert({
        'id': const Uuid().v4(),
        'store_id': storeId,
        'key': kOwnerV1Key,
        'value': rawJson,
      }, onConflict: 'store_id,key');

      final readBack = await getOwner(storeId);
      return readBack != null &&
          readBack.deviceId == owner.deviceId &&
          readBack.claimToken == owner.claimToken;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> releaseOwner({
    required String storeId,
    required String deviceId,
    required String expectedToken,
  }) async {
    try {
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', kOwnerV1Key)
          .maybeSingle();

      if (row == null || row['value'] == null) {
        return true;
      }

      final rawValue = row['value'] as String;
      final currentOwner = PrintServerOwnerState.fromJsonString(rawValue);

      if (currentOwner.deviceId != deviceId ||
          currentOwner.claimToken != expectedToken) {
        return false;
      }

      final deleted = await Supabase.instance.client
          .from('app_settings')
          .delete()
          .eq('store_id', storeId)
          .eq('key', kOwnerV1Key)
          .eq('value', rawValue)
          .select('id');

      return deleted.length == 1;
    } catch (_) {
      return false;
    }
  }
}

class StationPrintersState {
  final PrinterConfig cashier;
  final PrinterConfig bepNong;
  final PrinterConfig bepBar;
  final PrinterConfig barLabel;
  final bool autoPrintCheckout;
  final bool autoPrintKitchen;
  final bool autoOpenDrawer;
  final bool centralPrintRoutingEnabled;
  final bool ownerMigrationCompleted;
  final PrintDeviceState deviceState;
  final PrintServerOwnerState? ownerState;
  final String currentDeviceId;

  const StationPrintersState({
    required this.cashier,
    required this.bepNong,
    required this.bepBar,
    required this.barLabel,
    this.autoPrintCheckout = true,
    this.autoPrintKitchen = true,
    this.autoOpenDrawer = true,
    bool centralPrintRoutingEnabled = false,
    bool? autoPrintServer,
    this.ownerMigrationCompleted = false,
    this.deviceState = const PrintDeviceState(deviceName: 'Thiết bị POS'),
    this.ownerState,
    this.currentDeviceId = '',
  }) : centralPrintRoutingEnabled =
           autoPrintServer ?? centralPrintRoutingEnabled;

  bool get autoPrintServer => centralPrintRoutingEnabled;

  bool get isDesignatedPrintServerDevice =>
      currentDeviceId.isNotEmpty &&
      deviceState.isPrintServer &&
      deviceState.allowBackgroundPrinting;

  bool get canRunBackgroundPrintServer =>
      centralPrintRoutingEnabled && !kIsWeb && isDesignatedPrintServerDevice;

  bool get isCurrentDeviceOwner =>
      ownerState != null &&
      currentDeviceId.isNotEmpty &&
      ownerState!.deviceId == currentDeviceId &&
      ownerState!.claimToken.isNotEmpty &&
      deviceState.localClaimToken.isNotEmpty &&
      deviceState.localClaimToken == ownerState!.claimToken;

  StationPrintersState copyWith({
    PrinterConfig? cashier,
    PrinterConfig? bepNong,
    PrinterConfig? bepBar,
    PrinterConfig? barLabel,
    bool? autoPrintCheckout,
    bool? autoPrintKitchen,
    bool? autoOpenDrawer,
    bool? centralPrintRoutingEnabled,
    bool? autoPrintServer,
    bool? ownerMigrationCompleted,
    PrintDeviceState? deviceState,
    PrintServerOwnerState? ownerState,
    bool clearOwner = false,
    String? currentDeviceId,
  }) {
    return StationPrintersState(
      cashier: cashier ?? this.cashier,
      bepNong: bepNong ?? this.bepNong,
      bepBar: bepBar ?? this.bepBar,
      barLabel: barLabel ?? this.barLabel,
      autoPrintCheckout: autoPrintCheckout ?? this.autoPrintCheckout,
      autoPrintKitchen: autoPrintKitchen ?? this.autoPrintKitchen,
      autoOpenDrawer: autoOpenDrawer ?? this.autoOpenDrawer,
      centralPrintRoutingEnabled:
          centralPrintRoutingEnabled ??
          autoPrintServer ??
          this.centralPrintRoutingEnabled,
      ownerMigrationCompleted:
          ownerMigrationCompleted ?? this.ownerMigrationCompleted,
      deviceState: deviceState ?? this.deviceState,
      ownerState: clearOwner ? null : (ownerState ?? this.ownerState),
      currentDeviceId: currentDeviceId ?? this.currentDeviceId,
    );
  }
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
    if (kIsWeb || !autoPrintServer) {
      stop();
      return;
    }

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
    if (kIsWeb || !autoPrintServer) return;

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
  DateTime? _lastOwnerHeartbeatAt;
  Timer? _ownerRecoveryTimer;
  bool _isRecoveringOwner = false;

  PrintServerOwnerRepository ownerRepository =
      SupabasePrintServerOwnerRepository();

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

  /// In hóa đơn checkout bằng task key bền vững `<settlementId>:cashier`.
  /// Gọi lại cùng settlement chỉ trả skipped, không đẩy thêm job vật lý.
  Future<PrintDispatchResult> printCheckoutReceipt({
    required String storeId,
    required String settlementId,
    required BillData billData,
  }) async {
    final ready = await _printCache.init(storeId);
    if (!ready || _printCache.isDegraded) {
      return PrintDispatchResult({
        'cashier': StationPrintResult(
          stationCode: 'cashier',
          status: StationPrintStatus.failed,
          errorMessage:
              _printCache.lastError ?? 'Không thể mở cache chống in trùng',
        ),
      });
    }
    return _coordinator.processOrderData(
      orderId: settlementId,
      billData: billData,
      settings: state,
    );
  }

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
      _ownerRecoveryTimer?.cancel();
      _controller.stop();
    });

    return const StationPrintersState(
      cashier: PrinterConfig(name: '', type: 'system', enabled: true),
      bepNong: PrinterConfig(name: '', type: 'system', enabled: false),
      bepBar: PrinterConfig(name: '', type: 'system', enabled: false),
      barLabel: PrinterConfig(name: '', type: 'system', enabled: false),
      autoOpenDrawer: true,
      centralPrintRoutingEnabled: false,
    );
  }

  static const String kProfileV2Key = 'qn_printer_profile_v2';
  static const String kOwnerV1Key = 'qn_print_server_owner_v1';
  static const String kLegacyKey = 'qn_station_printers_global';

  String _getDeviceSettingsKey(String storeId, String deviceId) {
    return 'qn_print_device_v2_${storeId}_$deviceId';
  }

  Future<String> _getDeviceId() async {
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
    return deviceId;
  }

  Future<void> _loadLocalSettings() async {
    try {
      final deviceId = await _getDeviceId();
      final prefs = await SharedPreferences.getInstance();
      final profileJson =
          prefs.getString(kProfileV2Key) ?? prefs.getString(kLegacyKey);

      if (profileJson != null) {
        _applyProfileJson(profileJson);
      }

      final deviceKey = _getDeviceSettingsKey('local', deviceId);
      final devJson = prefs.getString(deviceKey);
      PrintDeviceState devState;
      if (devJson != null) {
        devState = PrintDeviceState.fromMap(
          jsonDecode(devJson) as Map<String, dynamic>,
          defaultDeviceName: _getDefaultDeviceName(),
        );
      } else {
        devState = PrintDeviceState(
          deviceName: _getDefaultDeviceName(),
          isPrintServer: false,
          allowBackgroundPrinting: false,
        );
      }

      state = state.copyWith(deviceState: devState, currentDeviceId: deviceId);
    } catch (_) {}
  }

  String _getDefaultDeviceName() {
    if (kIsWeb) return 'Web Browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return 'Windows POS';
      case TargetPlatform.macOS:
        return 'Mac POS';
      case TargetPlatform.android:
        return 'Android POS';
      case TargetPlatform.iOS:
        return 'iOS POS';
      default:
        return 'Thiết bị POS';
    }
  }

  Future<void> _loadSettings(String storeId) async {
    final deviceId = await _getDeviceId();
    if (!ref.mounted) return;
    state = state.copyWith(currentDeviceId: deviceId);

    // 1. Load Local Device Config
    final prefs = await SharedPreferences.getInstance();
    if (!ref.mounted) return;
    final deviceKey = _getDeviceSettingsKey(storeId, deviceId);
    final devJsonStr = prefs.getString(deviceKey);
    bool hadDeviceConfig = devJsonStr != null;
    PrintDeviceState devState;
    if (hadDeviceConfig) {
      devState = PrintDeviceState.fromMap(
        jsonDecode(devJsonStr) as Map<String, dynamic>,
        defaultDeviceName: _getDefaultDeviceName(),
      );
    } else {
      devState = PrintDeviceState(
        deviceName: _getDefaultDeviceName(),
        isPrintServer: false,
        allowBackgroundPrinting: false,
      );
    }
    state = state.copyWith(deviceState: devState);

    try {
      Supabase.instance.client.rest.headers['x-store-id'] = storeId;

      // 2. Query Profile V2 & Legacy V1 from Cloud
      final rows = await Supabase.instance.client
          .from('app_settings')
          .select('key, value')
          .eq('store_id', storeId)
          .inFilter('key', [kProfileV2Key, kOwnerV1Key, kLegacyKey]);

      if (!ref.mounted) return;

      Map<String, dynamic>? profileRow;
      Map<String, dynamic>? ownerRow;
      Map<String, dynamic>? legacyRow;

      for (final r in rows) {
        final k = r['key'] as String?;
        if (k == kProfileV2Key) profileRow = r;
        if (k == kOwnerV1Key) ownerRow = r;
        if (k == kLegacyKey) legacyRow = r;
      }

      bool legacyAutoPrintServer = false;
      if (legacyRow != null && legacyRow['value'] != null) {
        try {
          final map =
              jsonDecode(legacyRow['value'] as String) as Map<String, dynamic>;
          legacyAutoPrintServer = map['autoPrintServer'] == true;
        } catch (_) {}
      }

      // 3. Process Profile
      if (profileRow != null && profileRow['value'] != null) {
        final cloudJson = profileRow['value'] as String;
        _applyProfileJson(cloudJson);
        await prefs.setString(kProfileV2Key, cloudJson);
      } else if (legacyRow != null && legacyRow['value'] != null) {
        final legacyJson = legacyRow['value'] as String;
        _applyLegacyJson(legacyJson);
        await _persistProfileV2(storeId);
      } else {
        // Local fallback
        final localProfile =
            prefs.getString(kProfileV2Key) ?? prefs.getString(kLegacyKey);
        if (localProfile != null) {
          _applyProfileJson(localProfile);
        }
      }

      devState = await _hardLockWindowsPrintCoordinator(
        storeId: storeId,
        deviceId: deviceId,
        deviceState: devState,
        prefs: prefs,
      );

      // 4. Process Owner State
      PrintServerOwnerState? ownerState;
      if (ownerRow != null && ownerRow['value'] != null) {
        try {
          final val = ownerRow['value'] as String;
          ownerState = PrintServerOwnerState.fromJsonString(val);
        } catch (_) {}
      }
      final hasActiveOwner = hasActivePrintServerOwner(ownerState);
      final hasStaleOwner = ownerState != null && !hasActiveOwner;
      final hasAnyEnabledPrinter =
          state.cashier.enabled ||
          state.bepNong.enabled ||
          state.bepBar.enabled ||
          state.barLabel.enabled;

      if (ownerState != null &&
          shouldSyncOwnerClaimTokenToDesignatedDevice(
            isWeb: kIsWeb,
            deviceMarkedPrintServer: devState.isPrintServer,
            allowBackgroundPrinting: devState.allowBackgroundPrinting,
            currentDeviceId: deviceId,
            ownerDeviceId: ownerState.deviceId,
            ownerClaimToken: ownerState.claimToken,
          ) &&
          devState.localClaimToken != ownerState.claimToken) {
        devState = devState.copyWith(localClaimToken: ownerState.claimToken);
        await prefs.setString(
          _getDeviceSettingsKey(storeId, deviceId),
          jsonEncode(devState.toMap()),
        );
      }

      state = state.copyWith(
        ownerState: ownerState,
        clearOwner: ownerState == null,
        deviceState: devState,
      );

      // 5. Native Migration Check
      if (shouldBootstrapLegacyOwner(
        isWeb: kIsWeb,
        ownerMigrationCompleted: state.ownerMigrationCompleted,
        legacyAutoPrintServer: legacyAutoPrintServer,
        hasOwner: hasActiveOwner,
      )) {
        final claimed = await claimPrintServerOwner(
          storeId,
          devState.deviceName,
        );
        if (claimed) {
          state = state.copyWith(ownerMigrationCompleted: true);
          await _persistProfileV2(storeId);
        } else {
          state = state.copyWith(
            deviceState: state.deviceState.copyWith(
              isPrintServer: false,
              allowBackgroundPrinting: false,
            ),
          );
          await _saveDeviceConfigLocal(storeId);
        }
      } else if (shouldRestorePrintServerOwner(
        isWeb: kIsWeb,
        centralRoutingEnabled: state.centralPrintRoutingEnabled,
        hasOwner: hasActiveOwner,
        deviceMarkedPrintServer: devState.isPrintServer,
        allowBackgroundPrinting: devState.allowBackgroundPrinting,
        currentDeviceId: deviceId,
      )) {
        final reclaimed = await _upsertPrintServerOwner(
          storeId,
          devState.deviceName,
          forceTransfer: true,
        );
        if (!reclaimed) {
          writePrintLog(
            '[PrintServer] Could not restore owner automatically for device $deviceId.',
          );
        }
      } else if (shouldPromoteStalePrintServerOwner(
        isWeb: kIsWeb,
        isCurrentPlatformWindows:
            defaultTargetPlatform == TargetPlatform.windows,
        centralRoutingEnabled: state.centralPrintRoutingEnabled,
        hasStaleOwner: hasStaleOwner,
        deviceMarkedPrintServer: devState.isPrintServer,
        allowBackgroundPrinting: devState.allowBackgroundPrinting,
        hasAnyEnabledPrinter: hasAnyEnabledPrinter,
        currentDeviceId: deviceId,
      )) {
        final claimed = await _upsertPrintServerOwner(
          storeId,
          devState.deviceName,
          forceTransfer: true,
        );
        if (!claimed) {
          writePrintLog(
            '[PrintServer] Stale owner promotion failed for Windows device $deviceId.',
          );
        }
      } else if (ownerState != null && !state.ownerMigrationCompleted) {
        state = state.copyWith(ownerMigrationCompleted: true);
        await _persistProfileV2(storeId);
      }

      await _setupPrintServerListener(storeId);
      _setupOwnerRecoveryMonitor(storeId);

      // 6. Realtime Subscription to app_settings
      _subscription?.cancel();
      _subscription = Supabase.instance.client
          .from('app_settings')
          .stream(primaryKey: ['id'])
          .eq('store_id', storeId)
          .listen((List<Map<String, dynamic>> streamRows) async {
            bool profileChanged = false;
            bool ownerChanged = false;
            bool seenOwner = false;

            for (final r in streamRows) {
              final k = r['key'] as String?;
              final v = r['value'] as String?;

              if (k == kProfileV2Key && v != null) {
                _applyProfileJson(v);
                final currentPrefs = await SharedPreferences.getInstance();
                await currentPrefs.setString(kProfileV2Key, v);
                profileChanged = true;
              } else if (k == kOwnerV1Key) {
                if (v != null && v.isNotEmpty) {
                  try {
                    final newOwner = PrintServerOwnerState.fromJsonString(v);
                    seenOwner = true;
                    if (state.ownerState?.deviceId != newOwner.deviceId ||
                        state.ownerState?.claimToken != newOwner.claimToken) {
                      var newDevState = state.deviceState;
                      if (shouldSyncOwnerClaimTokenToDesignatedDevice(
                            isWeb: kIsWeb,
                            deviceMarkedPrintServer:
                                state.deviceState.isPrintServer,
                            allowBackgroundPrinting:
                                state.deviceState.allowBackgroundPrinting,
                            currentDeviceId: state.currentDeviceId,
                            ownerDeviceId: newOwner.deviceId,
                            ownerClaimToken: newOwner.claimToken,
                          ) &&
                          state.deviceState.localClaimToken !=
                              newOwner.claimToken) {
                        newDevState = newDevState.copyWith(
                          localClaimToken: newOwner.claimToken,
                        );
                      }
                      state = state.copyWith(
                        ownerState: newOwner,
                        deviceState: newDevState,
                      );
                      await _saveDeviceConfigLocal(storeId);
                      ownerChanged = true;
                    }
                  } catch (_) {}
                }
              }
            }

            if (!seenOwner && state.ownerState != null) {
              state = state.copyWith(clearOwner: true);
              ownerChanged = true;
            }

            if (profileChanged || ownerChanged) {
              await _setupPrintServerListener(storeId);
              _setupOwnerRecoveryMonitor(storeId);
            }
          });
    } catch (e) {
      writePrintLog('[PrintServer] Load cloud settings failed: $e');

      // Không để lỗi cloud/RLS làm máy thu ngân Windows mất listener in.
      // Keep the designated Windows coordinator alive from the cached profile.
      final localProfile =
          prefs.getString(kProfileV2Key) ?? prefs.getString(kLegacyKey);
      if (localProfile != null) {
        _applyProfileJson(localProfile);
      }
      await _hardLockWindowsPrintCoordinator(
        storeId: storeId,
        deviceId: deviceId,
        deviceState: state.deviceState,
        prefs: prefs,
      );
      await _setupPrintServerListener(storeId);
      _setupOwnerRecoveryMonitor(storeId);
    }
  }

  Future<PrintDeviceState> _hardLockWindowsPrintCoordinator({
    required String storeId,
    required String deviceId,
    required PrintDeviceState deviceState,
    required SharedPreferences prefs,
  }) async {
    final hasAnyEnabledPrinter =
        state.cashier.enabled ||
        state.bepNong.enabled ||
        state.bepBar.enabled ||
        state.barLabel.enabled;
    if (!shouldHardLockWindowsPrintCoordinator(
      isWeb: kIsWeb,
      isWindows: defaultTargetPlatform == TargetPlatform.windows,
      centralRoutingEnabled: state.centralPrintRoutingEnabled,
      hasAnyEnabledPrinter: hasAnyEnabledPrinter,
    )) {
      return deviceState;
    }

    final lockedState = deviceState.copyWith(
      isPrintServer: true,
      allowBackgroundPrinting: true,
    );
    state = state.copyWith(currentDeviceId: deviceId, deviceState: lockedState);
    await prefs.setString(
      _getDeviceSettingsKey(storeId, deviceId),
      jsonEncode(lockedState.toMap()),
    );
    writePrintLog(
      '[PrintServer] Windows coordinator hard-locked for device $deviceId.',
    );
    return lockedState;
  }

  bool _canThisDeviceRecoverPrintServerOwner() {
    final hasAnyEnabledPrinter =
        state.cashier.enabled ||
        state.bepNong.enabled ||
        state.bepBar.enabled ||
        state.barLabel.enabled;

    return !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.windows &&
        state.deviceState.isPrintServer &&
        state.deviceState.allowBackgroundPrinting &&
        state.currentDeviceId.isNotEmpty &&
        hasAnyEnabledPrinter;
  }

  void _setupOwnerRecoveryMonitor(String storeId) {
    _ownerRecoveryTimer?.cancel();
    _ownerRecoveryTimer = null;

    if (storeId.isEmpty ||
        kIsWeb ||
        !state.centralPrintRoutingEnabled ||
        !_canThisDeviceRecoverPrintServerOwner()) {
      return;
    }

    _ownerRecoveryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _attemptRecoverPrintServerOwner(storeId);
    });
  }

  Future<void> _attemptRecoverPrintServerOwner(String storeId) async {
    if (_isRecoveringOwner ||
        storeId.isEmpty ||
        !state.centralPrintRoutingEnabled ||
        !_canThisDeviceRecoverPrintServerOwner()) {
      return;
    }

    final owner = state.ownerState;
    final hasActiveOwner = hasActivePrintServerOwner(owner);
    final hasStaleOwner = owner != null && !hasActiveOwner;

    final shouldRecoverMissingOwner = shouldRestorePrintServerOwner(
      isWeb: kIsWeb,
      centralRoutingEnabled: state.centralPrintRoutingEnabled,
      hasOwner: hasActiveOwner,
      deviceMarkedPrintServer: state.deviceState.isPrintServer,
      allowBackgroundPrinting: state.deviceState.allowBackgroundPrinting,
      currentDeviceId: state.currentDeviceId,
    );

    final shouldRecoverStaleOwner = shouldPromoteStalePrintServerOwner(
      isWeb: kIsWeb,
      isCurrentPlatformWindows: defaultTargetPlatform == TargetPlatform.windows,
      centralRoutingEnabled: state.centralPrintRoutingEnabled,
      hasStaleOwner: hasStaleOwner,
      deviceMarkedPrintServer: state.deviceState.isPrintServer,
      allowBackgroundPrinting: state.deviceState.allowBackgroundPrinting,
      hasAnyEnabledPrinter:
          state.cashier.enabled ||
          state.bepNong.enabled ||
          state.bepBar.enabled ||
          state.barLabel.enabled,
      currentDeviceId: state.currentDeviceId,
    );

    if (!shouldRecoverMissingOwner && !shouldRecoverStaleOwner) {
      return;
    }

    _isRecoveringOwner = true;
    try {
      final ok = await _upsertPrintServerOwner(
        storeId,
        state.deviceState.deviceName,
        forceTransfer: true,
      );
      if (ok) {
        writePrintLog(
          '[PrintServer] Auto-recovered owner on designated device ${state.currentDeviceId}.',
        );
        await _setupPrintServerListener(storeId);
      }
    } catch (e) {
      writePrintLog('[PrintServer] Auto-recover owner failed: $e');
    } finally {
      _isRecoveringOwner = false;
    }
  }

  void _applyProfileJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      state = state.copyWith(
        cashier: PrinterConfig.fromMap(map['cashier'] ?? {}),
        bepNong: PrinterConfig.fromMap(map['bepNong'] ?? {}),
        bepBar: PrinterConfig.fromMap(map['bepBar'] ?? {}),
        barLabel: PrinterConfig.fromMap(map['barLabel'] ?? {}),
        autoPrintCheckout: map['autoPrintCheckout'] ?? true,
        autoPrintKitchen: map['autoPrintKitchen'] ?? true,
        autoOpenDrawer: map['autoOpenDrawer'] ?? true,
        centralPrintRoutingEnabled:
            map['centralPrintRoutingEnabled'] ??
            map['autoPrintServer'] ??
            false,
        ownerMigrationCompleted: map['ownerMigrationCompleted'] == true,
      );
    } catch (_) {}
  }

  void _applyLegacyJson(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      final legacyServer = map['autoPrintServer'] == true;
      state = state.copyWith(
        cashier: PrinterConfig.fromMap(map['cashier'] ?? {}),
        bepNong: PrinterConfig.fromMap(map['bepNong'] ?? {}),
        bepBar: PrinterConfig.fromMap(map['bepBar'] ?? {}),
        barLabel: PrinterConfig.fromMap(map['barLabel'] ?? {}),
        autoPrintCheckout: map['autoPrintCheckout'] ?? true,
        autoPrintKitchen: map['autoPrintKitchen'] ?? true,
        autoOpenDrawer: map['autoOpenDrawer'] ?? true,
        centralPrintRoutingEnabled: legacyServer,
      );
    } catch (_) {}
  }

  bool _canWriteCloudSettings() {
    try {
      final session = ref.read(sessionProvider);
      if (session == null) return false;
      return session.isOwner == true || session.role.toLowerCase() == 'owner';
    } catch (_) {
      return false;
    }
  }

  Future<void> _persistProfileV2(String storeId) async {
    try {
      final data = {
        'cashier': state.cashier.toMap(),
        'bepNong': state.bepNong.toMap(),
        'bepBar': state.bepBar.toMap(),
        'barLabel': state.barLabel.toMap(),
        'autoPrintCheckout': state.autoPrintCheckout,
        'autoPrintKitchen': state.autoPrintKitchen,
        'autoOpenDrawer': state.autoOpenDrawer,
        'centralPrintRoutingEnabled': state.centralPrintRoutingEnabled,
        'ownerMigrationCompleted': state.ownerMigrationCompleted,
      };
      final jsonStr = jsonEncode(data);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kProfileV2Key, jsonStr);

      if (storeId.isNotEmpty && _canWriteCloudSettings()) {
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;
        await Supabase.instance.client.from('app_settings').upsert({
          'id': const Uuid().v4(),
          'store_id': storeId,
          'key': kProfileV2Key,
          'value': jsonStr,
        }, onConflict: 'store_id,key');
      } else if (storeId.isNotEmpty) {
        AppLogger.info(
          'settings',
          '[_persistProfileV2] Skip cloud upsert: user is not store owner.',
        );
      }
    } catch (_) {}
  }

  Future<void> _saveDeviceConfigLocal(String storeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceKey = _getDeviceSettingsKey(storeId, state.currentDeviceId);
      await prefs.setString(deviceKey, jsonEncode(state.deviceState.toMap()));
    } catch (_) {}
  }

  Future<void> _activateVerifiedOwner(
    String storeId,
    String deviceId,
    String deviceName,
    PrintServerOwnerState verifiedOwner,
    String newToken,
  ) async {
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final refreshedOwner = verifiedOwner.copyWith(
      lastSeenAt: verifiedOwner.lastSeenAt.isNotEmpty
          ? verifiedOwner.lastSeenAt
          : nowIso,
    );
    state = state.copyWith(
      ownerState: refreshedOwner,
      ownerMigrationCompleted: true,
      currentDeviceId: deviceId,
      deviceState: state.deviceState.copyWith(
        deviceName: deviceName,
        isPrintServer: true,
        allowBackgroundPrinting: true,
        localClaimToken: newToken,
      ),
    );
    _lastOwnerHeartbeatAt =
        refreshedOwner.lastSeenAtUtc ?? DateTime.now().toUtc();
    await _saveDeviceConfigLocal(storeId);
    await _persistProfileV2(storeId);
    await _setupPrintServerListener(storeId);
  }

  Future<bool> _upsertPrintServerOwner(
    String storeId,
    String deviceName, {
    required bool forceTransfer,
  }) async {
    final deviceId = state.currentDeviceId.isNotEmpty
        ? state.currentDeviceId
        : await _getDeviceId();

    final newToken = const Uuid().v4();
    final nowIso = DateTime.now().toUtc().toIso8601String();
    final platformStr = defaultTargetPlatform.name;
    final candidateOwner = PrintServerOwnerState(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platformStr,
      claimedAt: nowIso,
      claimToken: newToken,
      lastSeenAt: nowIso,
    );

    try {
      if (forceTransfer) {
        await ownerRepository.transferOwner(
          storeId: storeId,
          owner: candidateOwner,
        );
      } else {
        await ownerRepository.claimOwner(
          storeId: storeId,
          owner: candidateOwner,
        );
      }
    } catch (_) {}

    PrintServerOwnerState? latestOwner;
    try {
      latestOwner = await ownerRepository.getOwner(storeId);
    } catch (e) {
      writePrintLog(
        '[PrintServer] owner lookup unavailable after ${forceTransfer ? 'transfer' : 'claim'}: $e',
      );
      return false;
    }

    if (latestOwner != null &&
        latestOwner.deviceId == deviceId &&
        latestOwner.claimToken == newToken) {
      await _activateVerifiedOwner(
        storeId,
        deviceId,
        deviceName,
        latestOwner,
        newToken,
      );
      return true;
    }

    _handleOwnershipLost(storeId, deviceId, deviceName, latestOwner);
    return false;
  }

  Future<bool> claimPrintServerOwner(String storeId, String deviceName) async {
    if (kIsWeb) return false;
    if (!await _verifyPrinterManagePermission()) return false;
    return _upsertPrintServerOwner(storeId, deviceName, forceTransfer: false);
  }

  void _handleOwnershipLost(
    String storeId,
    String deviceId,
    String deviceName,
    PrintServerOwnerState? existingOwner,
  ) {
    state = state.copyWith(
      ownerState: existingOwner,
      clearOwner: existingOwner == null,
      currentDeviceId: deviceId,
      deviceState: state.deviceState.copyWith(
        deviceName: deviceName,
        isPrintServer: false,
        allowBackgroundPrinting: false,
        localClaimToken: '',
      ),
    );
    _saveDeviceConfigLocal(storeId);
    _controller.stop();
  }

  Future<bool> transferPrintServerOwner(
    String storeId,
    String deviceName,
  ) async {
    if (kIsWeb) return false;
    if (!await _verifyPrinterManagePermission()) return false;
    return _upsertPrintServerOwner(storeId, deviceName, forceTransfer: true);
  }

  Future<bool> releasePrintServerOwner(String storeId) async {
    if (kIsWeb) return false;
    if (!await _verifyPrinterManagePermission()) return false;

    final deviceId = state.currentDeviceId;
    final currentOwner = state.ownerState;
    if (currentOwner == null || currentOwner.deviceId != deviceId) {
      return false;
    }

    final token = state.deviceState.localClaimToken;
    bool ok = false;
    try {
      ok = await ownerRepository.releaseOwner(
        storeId: storeId,
        deviceId: deviceId,
        expectedToken: token,
      );
    } catch (_) {}

    if (ok) {
      state = state.copyWith(
        clearOwner: true,
        deviceState: state.deviceState.copyWith(
          isPrintServer: false,
          allowBackgroundPrinting: false,
          localClaimToken: '',
        ),
      );
      await _saveDeviceConfigLocal(storeId);
      _controller.stop();
      return true;
    }

    PrintServerOwnerState? latestOwner;
    try {
      latestOwner = await ownerRepository.getOwner(storeId);
    } catch (e) {
      writePrintLog('[PrintServer] owner lookup unavailable after release: $e');
      _controller.stop();
      return false;
    }

    if (latestOwner == null) {
      state = state.copyWith(
        clearOwner: true,
        deviceState: state.deviceState.copyWith(
          isPrintServer: false,
          allowBackgroundPrinting: false,
          localClaimToken: '',
        ),
      );
      await _saveDeviceConfigLocal(storeId);
      _controller.stop();
      return true;
    }

    if (latestOwner.deviceId == deviceId && latestOwner.claimToken == token) {
      return false;
    }

    _handleOwnershipLost(
      storeId,
      deviceId,
      state.deviceState.deviceName,
      latestOwner,
    );
    return false;
  }

  Future<void> prepareForStoreLogout(String storeId) async {
    if (kIsWeb || storeId.isEmpty) {
      _controller.stop();
      return;
    }

    final deviceId = state.currentDeviceId;
    final currentOwner = state.ownerState;
    final currentToken = state.deviceState.localClaimToken;
    final shouldReleaseOwner =
        currentOwner != null &&
        currentOwner.deviceId == deviceId &&
        currentToken.isNotEmpty;

    if (!shouldReleaseOwner) {
      _controller.stop();
      return;
    }

    try {
      await ownerRepository.releaseOwner(
        storeId: storeId,
        deviceId: deviceId,
        expectedToken: currentToken,
      );
      writePrintLog(
        '[PrintServer] Released owner during logout for device $deviceId.',
      );
    } catch (e) {
      writePrintLog('[PrintServer] Failed to release owner during logout: $e');
    } finally {
      state = state.copyWith(
        clearOwner: true,
        deviceState: state.deviceState.copyWith(
          isPrintServer: true,
          allowBackgroundPrinting: true,
          localClaimToken: '',
        ),
      );
      await _saveDeviceConfigLocal(storeId);
      _controller.stop();
    }
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
    final session = ref.read(sessionProvider);
    final storeId =
        session?.storeId ??
        (await StoreAuthService.getStoreInfo())['store_id'] ??
        '';
    await _persistProfileV2(storeId);
  }

  Future<void> toggleAutoPrint({
    bool? checkout,
    bool? kitchen,
    bool? openDrawer,
    bool? printServer,
  }) async {
    if (printServer != null) {
      if (!await _verifyPrinterManagePermission()) return;
    }

    final session = ref.read(sessionProvider);
    final storeId =
        session?.storeId ??
        (await StoreAuthService.getStoreInfo())['store_id'] ??
        '';
    final targetRouting = printServer ?? state.centralPrintRoutingEnabled;
    final hasActiveOwner = hasActivePrintServerOwner(state.ownerState);

    if (targetRouting && !hasActiveOwner) {
      if (!_canThisDeviceRecoverPrintServerOwner()) {
        AppLogger.info(
          'settings',
          'Khong the bat central routing vi chua co Print Server Owner hoat dong tren thiet bi duoc chi dinh.',
        );
        return;
      }

      final recovered = await _upsertPrintServerOwner(
        storeId,
        state.deviceState.deviceName,
        forceTransfer: true,
      );
      if (!recovered) {
        AppLogger.info(
          'settings',
          'Khong the bat central routing vi that bai khi khoi phuc Print Server Owner.',
        );
        return;
      }
    }

    state = state.copyWith(
      autoPrintCheckout: checkout ?? state.autoPrintCheckout,
      autoPrintKitchen: kitchen ?? state.autoPrintKitchen,
      autoOpenDrawer: openDrawer ?? state.autoOpenDrawer,
      centralPrintRoutingEnabled: targetRouting,
    );
    AppLogger.info(
      'settings',
      'Thay doi tuy chon in tu dong: PrintCheckout=$checkout, PrintKitchen=$kitchen, OpenDrawer=$openDrawer, CentralRouting=$printServer',
    );
    await _persistProfileV2(storeId);

    if (storeId.isNotEmpty) {
      await _setupPrintServerListener(storeId);
      _setupOwnerRecoveryMonitor(storeId);
    }
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
    if (kIsWeb || !state.canRunBackgroundPrintServer) {
      _controller.stop();
      return;
    }
    await _controller.setup(
      storeId: storeId,
      autoPrintServer: state.canRunBackgroundPrintServer,
      settings: state,
      cache: _printCache,
      processTicket: (ticketId) => _processTicket(ticketId, storeId),
      processOrder: (orderId) => _processOrder(orderId, storeId),
      pollActive: _pollActiveTicketsAndOrders,
    );
  }

  Future<bool> _verifyPrinterManagePermission() async {
    try {
      final session = ref.read(sessionProvider);
      if (session != null &&
          (session.isOwner == true || session.role.toLowerCase() == 'owner')) {
        return true;
      }
      final perms = await ref.read(userActionPermsProvider.future);
      return perms.contains('printer.manage_server');
    } catch (_) {}
    return false;
  }

  Future<void> _refreshOwnerHeartbeatIfNeeded(String storeId) async {
    if (kIsWeb || !state.isCurrentDeviceOwner) return;
    final ownerState = state.ownerState;
    if (ownerState == null) return;

    final now = DateTime.now().toUtc();
    if (_lastOwnerHeartbeatAt != null &&
        now.difference(_lastOwnerHeartbeatAt!) < const Duration(seconds: 15)) {
      return;
    }

    final refreshedOwner = ownerState.copyWith(
      lastSeenAt: now.toIso8601String(),
    );

    try {
      await ownerRepository.transferOwner(
        storeId: storeId,
        owner: refreshedOwner,
      );
      state = state.copyWith(ownerState: refreshedOwner);
      _lastOwnerHeartbeatAt = now;
    } catch (e) {
      writePrintLog('[PrintServer] Failed to refresh owner heartbeat: $e');
    }
  }

  Future<void> _processTicket(String ticketId, String storeId) async {
    if (_printCache.isTicketPrinted(ticketId)) return;
    if (!state.canRunBackgroundPrintServer) return;

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

      if (!state.canRunBackgroundPrintServer) return;

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
    if (!state.canRunBackgroundPrintServer) return;

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

      if (!state.canRunBackgroundPrintServer) return;

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
      await _refreshOwnerHeartbeatIfNeeded(storeId);
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
