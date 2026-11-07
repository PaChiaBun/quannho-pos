import 'dart:async';
import 'package:flutter/foundation.dart'; // for debugPrint
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/store_auth_service.dart';
import '../utils/app_logger.dart';
import '../utils/server_time.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS — tương đương Drift KitchenTicket & KitchenTicketItem
// ─────────────────────────────────────────────────────────────────────────────
class KitchenTicketModel {
  final String id;
  final String storeId;
  final String? tableId;
  final String? tableLabel;
  final String? zoneId;
  final String? zoneLabel; // Thêm zoneLabel
  final String? orderNote;
  final String status; // 'cho' | 'dang_lam' | 'xong' | 'huy'
  final int sentAt;
  final int? startedAt;
  final int? doneAt;
  final String? stationCode; // 'nong' | 'nuoc' | null
  final String? sessionId;   // FIX #7: liên kết về ban_sessions
  final int round;           // Đợt gửi bếp (1, 2, 3...)

  const KitchenTicketModel({
    required this.id,
    required this.storeId,
    this.tableId,
    this.tableLabel,
    this.zoneId,
    this.zoneLabel, // Thêm zoneLabel
    this.orderNote,
    required this.status,
    required this.sentAt,
    this.startedAt,
    this.doneAt,
    this.stationCode,
    this.sessionId,
    this.round = 1,
  });

  factory KitchenTicketModel.fromMap(Map<String, dynamic> m) => KitchenTicketModel(
    id: m['id'] as String,
    storeId: m['store_id'] as String,
    tableId: m['table_id'] as String?,
    tableLabel: m['table_label'] as String?,
    zoneId: m['zone_id'] as String?,
    zoneLabel: m['zone_label'] as String?, // Thêm zoneLabel
    orderNote: (m['note'] as String?) ?? (m['order_note'] as String?),
    status: m['status'] as String? ?? 'cho',
    sentAt: _toMs(m['sent_at']),
    startedAt: m['started_at'] != null ? _toMs(m['started_at']) : null,
    doneAt: m['done_at'] != null ? _toMs(m['done_at']) : null,
    stationCode: m['station_code'] as String?,
    sessionId:   m['session_id'] as String?,
    round:       (m['round'] as num?)?.toInt() ?? 1,
  );

  KitchenTicketModel copyWith({String? status, int? startedAt, int? doneAt}) =>
      KitchenTicketModel(
        id: id, storeId: storeId, tableId: tableId, tableLabel: tableLabel,
        zoneId: zoneId,
        zoneLabel: zoneLabel, // Thêm zoneLabel
        orderNote: orderNote,
        status: status ?? this.status,
        sentAt: sentAt,
        startedAt: startedAt ?? this.startedAt,
        doneAt: doneAt ?? this.doneAt,
        stationCode: stationCode,
        sessionId: sessionId,
        round: round,
      );
}

class KitchenTicketItemModel {
  final String id;
  final String ticketId;
  final String productId;
  final String productName;
  final double quantity;
  final String? note;        // JSON modifiers từ POS: ["Ít đá", "Thêm đường"] → READ-ONLY
  final String? freeNote;    // Ghi chú khách khi gọi món: "không hành" → READ-ONLY
  final String? kitchenNote; // Ghi chú nội bộ bếp: "làm chín kỹ" → bếp tự ghi
  final String? stationCode;
  final bool done;
  final String? sessionItemId; // món ở bàn (ban_session_items.id); null ở phiếu cũ
  final bool cancelled;        // món ở bàn đã huỷ — máy chủ vẫn để done = true như món xong

  const KitchenTicketItemModel({
    required this.id,
    required this.ticketId,
    required this.productId,
    required this.productName,
    required this.quantity,
    this.note,
    this.freeNote,
    this.kitchenNote,
    this.stationCode,
    this.done = false,
    this.sessionItemId,
    this.cancelled = false,
  });

  factory KitchenTicketItemModel.fromMap(Map<String, dynamic> m, {bool cancelled = false}) => KitchenTicketItemModel(
    id: m['id'] as String,
    ticketId: m['ticket_id'] as String,
    productId: m['product_id'] as String? ?? '',
    productName: m['product_name'] as String? ?? '',
    quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
    note: m['note'] as String?,
    freeNote: m['free_note'] as String?,
    kitchenNote: m['kitchen_note'] as String?,
    stationCode: m['station_code'] as String?,
    done: m['done'] as bool? ?? false,
    sessionItemId: m['session_item_id'] as String?,
    cancelled: cancelled,
  );
}

/// Phiếu đã gửi bếp bị huỷ: bếp thấy thẻ "ĐÃ HUỶ" trong 15 phút kể từ giờ huỷ (done_at).
/// Phiếu huỷ thiếu done_at coi là cũ, không hiện.
const cancelledTicketWindow = Duration(minutes: 15);
bool isRecentCancelledTicket(KitchenTicketModel t, DateTime now) =>
    t.status == 'huy' &&
    t.doneAt != null &&
    now.millisecondsSinceEpoch - t.doneAt! < cancelledTicketWindow.inMilliseconds;

class TicketWithItems {
  final KitchenTicketModel ticket;
  final List<KitchenTicketItemModel> items;
  TicketWithItems({required this.ticket, required this.items});
}

// ─────────────────────────────────────────────────────────────────────────────
// KITCHEN REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class KitchenRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  // Local cache to survive read replica lag / temporary empty items issues
  final Map<String, List<KitchenTicketItemModel>> _itemsCache = {};
  // Món ở bàn đã huỷ (huỷ là vĩnh viễn) — truy vấn lỗi thì dùng lại kết quả lần trước
  Set<String> _cancelledItemIds = {};

  Future<String?> _storeId() async {
    try {
      final info = await StoreAuthService.getStoreInfo().timeout(const Duration(seconds: 2));
      final id = info['store_id'];
      if (id != null && id.isNotEmpty) return id;
    } catch (_) {}
    return null;
  }

  // ── Watch tickets (polling + realtime) ─────────────────────────────────────
  Stream<List<TicketWithItems>> watchActiveTickets() {
    late StreamController<List<TicketWithItems>> ctrl;
    RealtimeChannel? channel;
    Timer? fallbackTimer;
    List<TicketWithItems>? lastSuccessfulResult;
    bool isCancelled = false;

    ctrl = StreamController<List<TicketWithItems>>(onCancel: () async {
      isCancelled = true;
      await channel?.unsubscribe();
      fallbackTimer?.cancel();
      if (!ctrl.isClosed) await ctrl.close();
    });

    Future<void> refresh(String storeId) async {
      if (isCancelled || ctrl.isClosed) return;
      try {
        final result = await _fetchActiveTickets(storeId);
        if (isCancelled || ctrl.isClosed) return;
        lastSuccessfulResult = result;
        ctrl.add(result);
      } catch (e, stack) {
        debugPrint('[KitchenRepo] refresh error: $e\n$stack');
        if (!isCancelled && !ctrl.isClosed) {
          if (lastSuccessfulResult != null) {
            ctrl.add(lastSuccessfulResult!);
          } else {
            ctrl.add([]);
          }
        }
      }
    }

    Future<void> start() async {
      try {
        final storeId = await _storeId();
        if (isCancelled || ctrl.isClosed) return;
        if (storeId == null) {
          ctrl.add([]);
          return;
        }
        
        // Phát dữ liệu ban đầu ngay lập tức để thoát cờ AsyncLoading của Riverpod trong 1ms
        if (!isCancelled && !ctrl.isClosed) {
          ctrl.add(lastSuccessfulResult ?? []);
        }

        // Initial load
        await refresh(storeId);
        if (isCancelled || ctrl.isClosed) return;

        // Realtime subscription
        try {
          channel = _sb
              .channel('kitchen_$storeId')
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'kitchen_tickets',
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'store_id',
                  value: storeId,
                ),
              callback: (_) {
                if (!isCancelled) refresh(storeId);
              },
              )
              .onPostgresChanges(
                event: PostgresChangeEvent.all,
                schema: 'public',
                table: 'kitchen_ticket_items',
                // Không lọc thì món bếp của MỌI quán đổi cũng làm máy này tải lại.
                filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'store_id',
                  value: storeId,
                ),
              callback: (_) {
                if (!isCancelled) refresh(storeId);
              },
              );
          channel!.subscribe();
        } catch (e) {
          debugPrint('[KitchenRepo] Realtime sub error: $e');
        }

        // Fallback polling (10s thay vì 5s để giảm tải server và tránh nghẽn socket)
        fallbackTimer = Timer.periodic(const Duration(seconds: 10), (_) {
          if (!isCancelled) refresh(storeId);
        });
      } catch (e) {
        debugPrint('[KitchenRepo] start error: $e');
        if (!ctrl.isClosed) ctrl.add([]);
      }
    }

    start();
    return ctrl.stream;
  }

  Future<List<TicketWithItems>> _fetchActiveTickets(String storeId) async {
    // Chỉ lấy phiếu trong 4 giờ gần nhất và giới hạn tối đa 50 phiếu để tránh bão payload 87KB
    final since = DateTime.now().subtract(const Duration(hours: 4)).toUtc().toIso8601String();
    // Phiếu huỷ: chỉ lấy phiếu vừa huỷ (thẻ "ĐÃ HUỶ"); phiếu huỷ cũ / thiếu giờ huỷ vẫn bỏ như trước
    final cancelledSince =
        DateTime.now().subtract(cancelledTicketWindow).toUtc().toIso8601String();

    Set<String> openSessionIds = {};
    try {
      final openSessions = await _sb
          .from('ban_sessions')
          .select('id')
          .eq('store_id', storeId)
          .eq('status', 'open')
          .timeout(const Duration(seconds: 4));
      openSessionIds = openSessions.map((r) => r['id'] as String).toSet();
    } catch (e) {
      debugPrint('[KitchenRepo] fetch open sessions error: $e');
    }

    final tickets = await _sb
        .from('kitchen_tickets')
        .select()
        .eq('store_id', storeId)
        .or('status.neq.huy,done_at.gte.$cancelledSince')
        .gte('sent_at', since)
        .order('sent_at', ascending: false)
        .limit(50)
        .timeout(const Duration(seconds: 5));

    if (tickets.isEmpty) {
      _itemsCache.clear();
      return [];
    }

    final ticketIds = tickets.map((t) => t['id'] as String).toList();
    final allItems  = await _sb
        .from('kitchen_ticket_items')
        .select()
        .inFilter('ticket_id', ticketIds)
        .timeout(const Duration(seconds: 5));

    final ticketModels = tickets.map(KitchenTicketModel.fromMap).toList()
      ..sort((a, b) {
        const order = {'cho': 0, 'dang_lam': 1, 'xong': 2};
        final cmp = (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
        if (cmp != 0) return cmp;
        return a.sentAt.compareTo(b.sentAt);
      });

    final now = DateTime.now();

    // Prune cache: Chỉ giữ lại các ticket đang active để tránh tràn bộ nhớ
    final activeIds = ticketModels.map((t) => t.id).toSet();
    _itemsCache.removeWhere((id, _) => !activeIds.contains(id));

    final shown = ticketModels.where((ticket) {
      if (ticket.status == 'huy') return isRecentCancelledTicket(ticket, now);
      // ‼️ Lọc phiếu của các bàn đã thanh toán
      // Chỉ ẩn phiếu nếu phiếu đó đã HOÀN THÀNH ('xong') VÀ session đã đóng (không còn nằm trong openSessionIds).
      // Nếu phiếu chưa làm xong ('cho' hoặc 'dang_lam'), BẮT BUỘC phải hiển thị để bếp làm (đơn mang đi hoặc bàn chưa đủ món).
      if (ticket.sessionId != null && !openSessionIds.contains(ticket.sessionId)) {
        if (ticket.status == 'xong') {
          return false;
        }
      }

      // Tự động dọn phiếu Hoàn thành sau 15 phút (hoặc khi bấm Dọn phiếu)
      if (ticket.status == 'xong' && ticket.doneAt != null) {
        final doneTime = DateTime.fromMillisecondsSinceEpoch(ticket.doneAt!);
        if (now.difference(doneTime).inMinutes >= 15) {
          return false; // Ẩn khỏi màn hình bếp
        }
      }
      return true;
    }).toList();

    // Món huỷ ở bàn: máy chủ để done = true như món xong → hỏi kitchen_status của các món "xong" đang hiện
    final shownIds = shown.map((t) => t.id).toSet();
    final doneSessionItemIds = [
      for (final i in allItems)
        if (i['done'] == true && i['session_item_id'] != null && shownIds.contains(i['ticket_id']))
          i['session_item_id'] as String,
    ];
    if (doneSessionItemIds.isNotEmpty) {
      try {
        final rows = await _sb
            .from('ban_session_items')
            .select('id')
            .inFilter('id', doneSessionItemIds)
            .eq('kitchen_status', 'huy')
            .timeout(const Duration(seconds: 4));
        _cancelledItemIds = rows.map((r) => r['id'] as String).toSet();
      } catch (e) {
        debugPrint('[KitchenRepo] fetch cancelled items error: $e');
      }
    }

    return shown.map((ticket) {
      final fetchedItems = allItems
          .where((i) => i['ticket_id'] == ticket.id)
          .map((i) => KitchenTicketItemModel.fromMap(i,
              cancelled: _cancelledItemIds.contains(i['session_item_id'])))
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

      if (fetchedItems.isNotEmpty) {
        _itemsCache[ticket.id] = fetchedItems;
      }

      final visibleItems = _itemsCache[ticket.id] ?? fetchedItems;
      return TicketWithItems(ticket: ticket, items: visibleItems);
    }).where((tw) {
      // Tự động ẩn các phiếu đã xong sau 15 phút (tránh trùng lặp khi khách mới vào)
      if (tw.ticket.status == 'xong' && tw.ticket.doneAt != null) {
        final doneTime = DateTime.fromMillisecondsSinceEpoch(tw.ticket.doneAt!);
        if (DateTime.now().difference(doneTime).inMinutes > 15) {
          return false;
        }
      }
      // Ẩn nếu hủy hết món
      return tw.items.isNotEmpty;
    }).toList();
  }

  // ── Create ticket ──────────────────────────────────────────────────────────
  Future<String> createTicket({
    required String tableId,
    required String tableLabel,
    String? zoneId,
    String? orderNote,
    String? stationCode,
    required List<({String productId, String productName, double qty, String? note, String? stationCode})> items,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    final ticketId = const Uuid().v4(); // ‼️ FIX: dùng UUID thay vì timestamp — tránh collision khi 2 bàn gửi bếp cùng millisecond
    final now = DateTime.now().toUtc().toIso8601String();

    await _sb.from('kitchen_tickets').insert({
      'id': ticketId,
      'store_id': storeId,
      'table_id': tableId,
      'table_label': tableLabel,
      'zone_id': zoneId,
      'order_note': orderNote,
      'status': 'cho',
      'sent_at': now,
      'station_code': stationCode,
    });

    final itemRows = items.asMap().entries.map((e) => {
      'id': '${ticketId}_item_${e.key}',
      'ticket_id': ticketId,
      'product_id': e.value.productId,
      'product_name': e.value.productName,
      'quantity': e.value.qty,
      'note': e.value.note,
      'station_code': e.value.stationCode,
      'done': false,
    }).toList();

    if (itemRows.isNotEmpty) {
      await _sb.from('kitchen_ticket_items').insert(itemRows);
    }

    AppLogger.logUserAction(
      tag: 'kitchen',
      action: 'Gửi phiếu bếp [$tableLabel] (${items.length} món)',
      details: {'ticket_id': ticketId, 'table_label': tableLabel, 'item_count': items.length},
    );

    return ticketId;
  }

  // ── Update ticket status ───────────────────────────────────────────────────
  Future<void> updateStatus(String ticketId, String status) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final update = <String, dynamic>{'status': status};
    if (status == 'dang_lam') update['started_at'] = now;
    if (status == 'xong')     update['done_at'] = now;
    await _sb.from('kitchen_tickets').update(update).eq('id', ticketId);

    AppLogger.logUserAction(
      tag: 'kitchen',
      action: 'Bếp cập nhật trạng thái phiếu [$status]',
      details: {'ticket_id': ticketId, 'status': status},
    );

    // Đồng bộ trạng thái done cho toàn bộ kitchen_ticket_items chi tiết của ticket
    if (status == 'xong') {
      try {
        await _sb.from('kitchen_ticket_items')
            .update({'done': true})
            .eq('ticket_id', ticketId);
      } catch (e) {
        debugPrint('[KitchenRepo] Sync done items err: $e');
      }
    } else if (status == 'dang_lam') {
      try {
        await _sb.from('kitchen_ticket_items')
            .update({'done': false})
            .eq('ticket_id', ticketId);
      } catch (e) {
        debugPrint('[KitchenRepo] Sync undone items err: $e');
      }
    }

    // ‼️ FIX #R1: Sync kitchen_status về ban_session_items
    // Để màn Bàn (phục vụ) thấy đúng trạng thái bếp đang làm/đã xong/đã hủy
    final banStatus = status == 'dang_lam' ? 'dang_lam'
                    : status == 'xong'     ? 'xong'
                    : status == 'huy'      ? 'huy'
                    : null;
    if (banStatus != null) {
      try {
        // Lấy tất cả session_item_id từ ticket này
        final items = await _sb.from('kitchen_ticket_items')
            .select('session_item_id')
            .eq('ticket_id', ticketId);
        final sessionItemIds = items
            .map((r) => r['session_item_id'] as String?)
            .whereType<String>()
            .toList();
        if (sessionItemIds.isNotEmpty) {
          // Món đã huỷ giữ nguyên 'huy' (trước đây bị ghi đè thành đang làm / xong)
          await _sb.from('ban_session_items')
              .update({'kitchen_status': banStatus})
              .inFilter('id', sessionItemIds)
              .neq('kitchen_status', 'huy');
        }
      } catch (e) {
        debugPrint('[KitchenRepo] R1 sync ban_session_items err: $e');
      }
    }
  }

  // Không có cancelTicket: huỷ món đã gửi bếp phải qua Quản lý duyệt ở màn bàn (máy chủ chặn huỷ không duyệt).
  Future<void> startTicket(String ticketId)  => updateStatus(ticketId, 'dang_lam');
  Future<void> doneTicket(String ticketId)   => updateStatus(ticketId, 'xong');

  /// Undo "Xong" — mở lại phiếu về trạng thái "Đang làm"
  Future<void> reopenTicket(String ticketId) async {
    // 1. Cập nhật status của ticket + reset done_at
    await _sb.from('kitchen_tickets').update({
      'status':  'dang_lam',
      'done_at': null,
    }).eq('id', ticketId);

    // 2. Reset trạng thái done của items chi tiết
    try {
      await _sb.from('kitchen_ticket_items')
          .update({'done': false})
          .eq('ticket_id', ticketId);
    } catch (e) {
      debugPrint('[KitchenRepo] reopenTicket sync items err: $e');
    }

    // 3. Sync kitchen_status về ban_session_items của Phục vụ
    try {
      final items = await _sb.from('kitchen_ticket_items')
          .select('session_item_id')
          .eq('ticket_id', ticketId);
      final sessionItemIds = items
          .map((r) => r['session_item_id'] as String?)
          .whereType<String>()
          .toList();
      if (sessionItemIds.isNotEmpty) {
        await _sb.from('ban_session_items')
            .update({'kitchen_status': 'dang_lam'})
            .inFilter('id', sessionItemIds)
            .neq('kitchen_status', 'huy');
      }
    } catch (e) {
      debugPrint('[KitchenRepo] reopenTicket sync ban_session_items err: $e');
    }
  }

  /// Ẩn phiếu khỏi màn hình bếp (lùi done_at về quá khứ 1 ngày)
  Future<void> archiveTicket(String ticketId) async {
    final past = DateTime.now().subtract(const Duration(days: 1)).toUtc().toIso8601String();
    await _sb.from('kitchen_tickets').update({'done_at': past}).eq('id', ticketId);
  }

  /// Per-item check-off — tick ✓ từng món riêng lẻ
  /// Khi tất cả món xong → tự gọi doneTicket để đóng phiếu
  /// Khi untick 1 món → nếu ticket đang 'xong' thì mở lại về 'dang_lam'
  Future<void> toggleItemDone(String itemId, String ticketId, bool isDone) async {
    // Cập nhật trạng thái item
    await _sb.from('kitchen_ticket_items')
        .update({'done': isDone})
        .eq('id', itemId);

    // 2. Đồng bộ lập tức về ban_session_items của Phục vụ
    try {
      final item = await _sb.from('kitchen_ticket_items')
          .select('session_item_id')
          .eq('id', itemId)
          .maybeSingle();
      final sessionItemId = item?['session_item_id'] as String?;
      if (sessionItemId != null) {
        await _sb.from('ban_session_items')
            .update({'kitchen_status': isDone ? 'xong' : 'dang_lam'})
            .eq('id', sessionItemId)
            .neq('kitchen_status', 'huy');
      }
    } catch (e) {
      debugPrint('[KitchenRepo] toggleItemDone sync error: $e');
    }

    if (isDone) {
      // Kiểm tra tất cả item cùng ticket đã done chưa
      final rows = await _sb
          .from('kitchen_ticket_items')
          .select('done')
          .eq('ticket_id', ticketId);
      final allDone = rows.isNotEmpty && rows.every((r) => r['done'] == true);
      if (allDone) await doneTicket(ticketId);
    } else {
      // Untick: nếu ticket đang 'xong' → mở lại
      final ticket = await _sb
          .from('kitchen_tickets')
          .select('status')
          .eq('id', ticketId)
          .maybeSingle();
      if (ticket?['status'] == 'xong') await reopenTicket(ticketId);
    }
  }

  // ── Today stats ───────────────────────────────────────────────────────────
  Future<_KitchenDayStats> getTodayStats() async {
    final storeId = await _storeId();
    if (storeId == null) return const _KitchenDayStats(totalDone: 0, avgWaitMs: 0);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day)
        .toUtc()
        .toIso8601String();
    final endOfDay = DateTime(now.year, now.month, now.day + 1)
        .toUtc()
        .toIso8601String();

    final tickets = await _sb
        .from('kitchen_tickets')
        .select()
        .eq('store_id', storeId)
        .eq('status', 'xong')
        .gte('sent_at', startOfDay)
        .lt('sent_at', endOfDay); // ‼️ FIX: thêm lt upper bound

    final models = tickets.map(KitchenTicketModel.fromMap).toList();
    final done   = models.where((t) => t.doneAt != null && t.startedAt != null).toList();
    int totalWait = 0;
    for (final t in done) {
      totalWait += (t.doneAt! - t.sentAt);
    }
    return _KitchenDayStats(
      totalDone: models.length,
      avgWaitMs: done.isNotEmpty ? totalWait ~/ done.length : 0,
    );
  }

  /// All tickets hôm nay (cho stats stream)
  Stream<List<KitchenTicketModel>> watchAllTodayTickets() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    final now      = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final endDay   = DateTime(now.year, now.month, now.day + 1).toUtc().toIso8601String();
    // ‼️ FIX: thêm .lt(endDay) — trước đây không có upper bound, lấy cả ngày mai
    final rows = await _sb.from('kitchen_tickets').select()
        .eq('store_id', storeId).gte('sent_at', startDay).lt('sent_at', endDay);
    yield rows.map(KitchenTicketModel.fromMap).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VOID NOTICE MODEL — Thông báo hủy/giảm món (một dòng void_audit_logs) hiển thị trên KDS
// ─────────────────────────────────────────────────────────────────────────────
class VoidNoticeModel {
  final String id;
  final String referenceId; // id món ở bàn (huỷ / giảm món) hoặc id phiên bàn (huỷ bàn, huỷ phiếu ở Bán hàng)
  final String tableLabel;
  final bool isReduce;      // giảm số lượng, không phải huỷ
  final List<(String, double)> items; // (tên món, số lượng huỷ / giảm) từ details_json
  final String reason;
  final String approvedBy;

  const VoidNoticeModel({
    required this.id,
    required this.referenceId,
    required this.tableLabel,
    required this.isReduce,
    required this.items,
    required this.reason,
    required this.approvedBy,
  });

  // label do logVoidEvent ghi: "Bàn 3 (Món: Trà sữa)", "Bàn 3 (Giảm món: Trà sữa)",
  // "Mang đi (Huỷ phiếu bếp)", hoặc chỉ tên bàn (huỷ bàn)
  static final _labelRe = RegExp(r'^(.+) \((Giảm món|Món|H(?:uỷ|ủy) phiếu bếp)[:)]');

  factory VoidNoticeModel.fromMap(Map<String, dynamic> m) {
    final label = m['label'] as String? ?? '';
    final match = _labelRe.firstMatch(label);
    final details = m['details_json'];
    return VoidNoticeModel(
      id:          m['id'] as String,
      referenceId: m['reference_id'] as String? ?? '',
      tableLabel:  match?.group(1) ?? label,
      isReduce:    match?.group(2) == 'Giảm món',
      items: [
        if (details is List)
          for (final d in details.whereType<Map>())
            ('${d['product_name'] ?? ''}', (d['quantity'] as num?)?.toDouble() ?? 0),
      ],
      reason:      m['reason'] as String? ?? '',
      approvedBy:  m['approved_by_name'] as String? ?? '',
    );
  }

  /// Label hiển thị ngắn gọn trên KDS card
  String get shortLabel {
    String qty(double q) => q == q.roundToDouble() ? '${q.toInt()}' : '$q';
    final verb = isReduce ? '✏️ Giảm' : '❌ Huỷ';
    if (items.length == 1) return '$verb ×${qty(items.first.$2)} "${items.first.$1}"';
    if (items.isEmpty) return '$verb món';
    return '$verb: ${items.map((i) => '${i.$1} ×${qty(i.$2)}').join(', ')}';
  }
}

/// Stream thông báo hủy/sửa món trong 30 phút gần nhất
/// KDS dùng để hiện Cancel Notice Card
Stream<List<VoidNoticeModel>> watchVoidNotices(String storeId) async* {
  final ctrl = StreamController<List<VoidNoticeModel>>();
  final sb = Supabase.instance.client;

  Future<void> fetch() async {
    try {
      final since = DateTime.now().subtract(const Duration(minutes: 30))
          .toUtc().toIso8601String();
      final rows = await sb.from('void_audit_logs')
          .select()
          .eq('store_id', storeId)
          .gte('created_at', since)
          .order('created_at', ascending: false);
      if (!ctrl.isClosed) {
        debugPrint('[KitchenRepo] voidNotices fetch → ${rows.length} rows');
        ctrl.add(rows.map(VoidNoticeModel.fromMap).toList());
      }
    } catch (e) {
      debugPrint('[KitchenRepo] watchVoidNotices fetch err: $e');
    }
  }

  await fetch();

  // Realtime: chỉ dòng của quán này (trước đây nghe mọi quán → quán khác huỷ món cũng làm máy này tải lại)
  final channel = sb.channel('void_notices_$storeId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'void_audit_logs',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'store_id',
          value: storeId,
        ),
        callback: (payload) {
          debugPrint('[KitchenRepo] void_notice Realtime INSERT received');
          fetch();
        },
      );
  channel.subscribe((status, [err]) {
    debugPrint('[KitchenRepo] void_notices channel status: $status err=$err');
  });

  // ‼️ FALLBACK: Poll mỗi 45s để đảm bảo banner luôn hiện dù Realtime lag/fail
  final pollTimer = Timer.periodic(const Duration(seconds: 45), (_) => fetch());

  try {
    yield* ctrl.stream;
  } finally {
    pollTimer.cancel();
    await channel.unsubscribe();
    await ctrl.close();
  }
}

class _KitchenDayStats {
  final int totalDone;
  final int avgWaitMs;
  const _KitchenDayStats({required this.totalDone, required this.avgWaitMs});
}

// Helper: convert Supabase timestamp (String or int) → ms
int _toMs(dynamic val) {
  if (val is int) return val;
  if (val is String) return parseServerTime(val)?.millisecondsSinceEpoch ?? 0;
  return 0;
}
