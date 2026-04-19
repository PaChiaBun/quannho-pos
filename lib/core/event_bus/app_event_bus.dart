import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';
import 'app_events.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP EVENT BUS — Trung gian duy nhất giữa các modules
//
// Cách dùng:
//   // Phát event
//   eventBus.emit(SaleCompletedEvent(...));
//
//   // Lắng nghe
//   eventBus.on<SaleCompletedEvent>().listen((e) { ... });
// ─────────────────────────────────────────────────────────────────────────────
class AppEventBus {
  final AppDatabase _db;
  final _uuid = const Uuid();

  // Stream controller phát event tới tất cả lắng nghe
  final _controller = StreamController<AppEvent>.broadcast();

  AppEventBus(this._db);

  /// Lắng nghe event của 1 loại cụ thể
  Stream<T> on<T extends AppEvent>() {
    return _controller.stream.where((e) => e is T).cast<T>();
  }

  /// Phát 1 event:
  /// 1. Ghi vào events_log (idempotent)
  /// 2. Tạo pending entries cho từng module đang TẮT
  /// 3. Broadcast ngay cho các module đang bật lắng nghe
  Future<void> emit(
    AppEvent event, {
    List<String> targetModules = const [],
  }) async {
    final payloadJson = jsonEncode(event.toJson());
    final idempotencyKey = '${event.eventType}:${event.id}';

    // Ghi vào events_log (bỏ qua nếu đã có)
    await _db.into(_db.eventsLog).insertOnConflictUpdate(EventsLogCompanion(
          id: Value(event.id),
          eventType: Value(event.eventType),
          sourceModule: Value(event.sourceModule),
          payload: Value(payloadJson),
          createdAt: Value(event.createdAt.millisecondsSinceEpoch),
          idempotencyKey: Value(idempotencyKey),
        ));

    // Tạo pending events cho các modules target đang tắt
    if (targetModules.isNotEmpty) {
      final activeModules = await (_db.select(_db.moduleConfigs)
            ..where((m) => m.isActive.equals(true)))
          .get();
      final activeIds = activeModules.map((m) => m.id).toSet();

      for (final module in targetModules) {
        if (!activeIds.contains(module)) {
          // Module đang tắt → enqueue pending
          await _db.into(_db.pendingEvents).insert(PendingEventsCompanion(
                id: Value(_uuid.v4()),
                eventId: Value(event.id),
                targetModule: Value(module),
              ));
        }
      }
    }

    // Broadcast tới listeners ngay
    _controller.add(event);
  }

  /// Flush pending events khi module được bật lại
  Future<void> flushPendingEventsFor(String moduleId) async {
    final pending = await (_db.select(_db.pendingEvents)
          ..where((p) =>
              p.targetModule.equals(moduleId) &
              p.processedAt.isNull()))
        .get();

    for (final p in pending) {
      // Đọc event gốc
      final eventRow = await (_db.select(_db.eventsLog)
            ..where((e) => e.id.equals(p.eventId)))
          .getSingleOrNull();

      if (eventRow != null) {
        final event = _reconstructEvent(eventRow);
        if (event != null) {
          // Phát lại nhưng không ghi DB lần nữa
          _controller.add(event);
        }
      }

      // Đánh dấu đã xử lý
      await (_db.update(_db.pendingEvents)
            ..where((p2) => p2.id.equals(p.id)))
          .write(PendingEventsCompanion(
        processedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ));
    }
  }

  /// Tái tạo lại AppEvent từ row trong events_log
  AppEvent? _reconstructEvent(EventsLogData row) {
    final payload = jsonDecode(row.payload) as Map<String, dynamic>;
    final createdAt =
        DateTime.fromMillisecondsSinceEpoch(row.createdAt);

    switch (row.eventType) {
      case 'sale_completed':
        final itemsJson = payload['items'] as List<dynamic>? ?? [];
        return SaleCompletedEvent(
          id: row.id,
          createdAt: createdAt,
          orderId: payload['orderId'] as String,
          orderNumber: payload['orderNumber'] as String,
          total: (payload['total'] as num).toDouble(),
          subtotal: (payload['subtotal'] as num).toDouble(),
          customerId: payload['customerId'] as String?,
          paymentMethod: payload['paymentMethod'] as String? ?? 'cash',
          loyaltyPtsEarned:
              (payload['loyaltyPtsEarned'] as num?)?.toDouble() ?? 0,
          loyaltyPtsUsed:
              (payload['loyaltyPtsUsed'] as num?)?.toDouble() ?? 0,
          items: itemsJson
              .map((e) => SaleItem(
                    productId: e['productId'] as String,
                    productName: e['productName'] as String,
                    quantity: (e['quantity'] as num).toDouble(),
                    unitPrice: (e['unitPrice'] as num).toDouble(),
                    costPrice: (e['costPrice'] as num).toDouble(),
                    subtotal: (e['subtotal'] as num).toDouble(),
                  ))
              .toList(),
        );
      case 'sale_cancelled':
        return SaleCancelledEvent(
          id: row.id,
          createdAt: createdAt,
          orderId: payload['orderId'] as String,
          reason: payload['reason'] as String?,
        );
      case 'stock_adjusted':
        return StockAdjustedEvent(
          id: row.id,
          createdAt: createdAt,
          productId: payload['productId'] as String,
          delta: (payload['delta'] as num).toDouble(),
          reason: payload['reason'] as String,
        );
      case 'low_stock_alert':
        return LowStockAlertEvent(
          id: row.id,
          createdAt: createdAt,
          productId: payload['productId'] as String,
          currentQty: (payload['currentQty'] as num).toDouble(),
          minQty: (payload['minQty'] as num).toDouble(),
        );
      default:
        return null; // Event type chưa handle
    }
  }

  void dispose() {
    _controller.close();
  }
}
