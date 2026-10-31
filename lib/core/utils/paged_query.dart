import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Máy chủ (PostgREST, PGRST_DB_MAX_ROWS=1000) chỉ trả tối đa 1.000 dòng mỗi lần đọc —
// kể cả lần tải đầu của `.stream()`. Đọc cả bảng của quán rồi lọc ở máy sẽ thiếu dữ liệu
// khi quán có > 1.000 dòng (KAY 23/10/2026: đơn hàng 8.796, phiếu kho 20.709, việc Vận
// hành 2.030 — màn "hôm nay" nhận toàn dòng cũ, không có dòng hôm nay).
// ─────────────────────────────────────────────────────────────────────────────

/// Gọi [page] cho từng trang [size] dòng tới khi hết. [page] phải sắp xếp cố định
/// (vd. thêm `.order('id')`) để trang sau không trùng / sót.
Future<List<Map<String, dynamic>>> fetchAllPages(
  Future<List<Map<String, dynamic>>> Function(int offset, int end) page, {
  int size = 1000,
}) async {
  final out = <Map<String, dynamic>>[];
  for (var offset = 0; ; offset += size) {
    final rows = await page(offset, offset + size - 1);
    out.addAll(rows);
    if (rows.length < size) break;
  }
  return out;
}

int _watchSeq = 0;

/// Theo dõi realtime bảng [table] của quán [storeId], nhưng dữ liệu luôn lấy bằng [fetch]
/// (truy vấn lọc ở máy chủ). Realtime (postgres_changes, không tải ảnh chụp 1.000 dòng như
/// `.stream()`) chỉ là tín hiệu "có thay đổi":
/// - thay đổi dồn dập được gom (chờ 400 ms) và không bao giờ tải chồng nhau — đang tải mà có
///   thay đổi thì tải thêm đúng một lần sau đó; mỗi lần tải tối đa 30 giây (mạng treo không
///   làm màn đứng mãi);
/// - realtime lỗi / mất kết nối → tải lại mỗi 10 giây; kênh bị đóng → dựng kênh mới;
/// - màn bị che (người nghe tạm dừng) → không tải, chỉ đánh dấu; mở lại thì tải một lần;
/// - người nghe huỷ (đóng màn) → gỡ kênh, dừng hẳn, không tải thêm;
/// - lỗi tải khi CHƯA có dữ liệu lần nào → phát lỗi và tự thử lại sau 10 giây;
///   đã có dữ liệu thì giữ dữ liệu cũ và thử lại.
Stream<T> watchByRefetch<T>({
  required String table,
  required String storeId,
  required Future<T> Function() fetch,
  Duration debounce = const Duration(milliseconds: 400),
  Duration fetchTimeout = const Duration(seconds: 30),
  Duration retryEvery = const Duration(seconds: 10),
  SupabaseClient? client, // cho test
}) {
  final sb = client ?? Supabase.instance.client;
  late final StreamController<T> ctrl;
  RealtimeChannel? channel;
  Timer? debounceTimer;
  Timer? pollTimer;
  Timer? retryTimer;
  Timer? reconnectTimer;
  var disposed = false;
  var running = false;
  var dirty = false;
  var hasData = false;

  Future<void> run() async {
    if (disposed) return;
    if (running || ctrl.isPaused) {
      dirty = true; // tải sau khi lần đang chạy xong / khi màn mở lại
      return;
    }
    running = true;
    try {
      do {
        dirty = false;
        try {
          final value = await fetch().timeout(fetchTimeout);
          if (disposed) return;
          hasData = true;
          ctrl.add(value);
        } catch (e, st) {
          if (disposed) return;
          if (!hasData) {
            ctrl.addError(e, st);
            retryTimer?.cancel();
            retryTimer = Timer(retryEvery, run);
          }
        }
      } while (dirty && !disposed && !ctrl.isPaused);
    } finally {
      running = false;
    }
  }

  void schedule() {
    if (disposed) return;
    debounceTimer?.cancel();
    debounceTimer = Timer(debounce, run);
  }

  void startPolling() {
    pollTimer ??= Timer.periodic(retryEvery, (_) => run());
  }

  void stopPolling() {
    pollTimer?.cancel();
    pollTimer = null;
  }

  late void Function() connect;

  void reconnectLater() {
    if (disposed || reconnectTimer != null) return;
    reconnectTimer = Timer(retryEvery, () async {
      reconnectTimer = null;
      if (disposed) return;
      final old = channel;
      channel = null;
      if (old != null) {
        try {
          await sb.removeChannel(old);
        } catch (_) {}
      }
      if (!disposed) connect();
    });
  }

  connect = () {
    try {
      final ch = sb
          .channel('qn_watch_${table}_${storeId}_${_watchSeq++}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'store_id',
              value: storeId,
            ),
            callback: (_) => schedule(),
          );
      channel = ch;
      ch.subscribe((status, [_]) {
        if (disposed || !identical(channel, ch)) return;
        if (status == RealtimeSubscribeStatus.subscribed) {
          stopPolling();
          // Mới kết nối / kết nối lại: có thể đã lỡ thay đổi trong lúc chưa nghe → tải lại.
          schedule();
        } else {
          startPolling();
          // Kênh bị đóng hẳn (không tự nối lại) → dựng kênh mới.
          if (status == RealtimeSubscribeStatus.closed) reconnectLater();
        }
      });
    } catch (_) {
      startPolling();
      reconnectLater();
    }
  };

  ctrl = StreamController<T>(
    onListen: () {
      run();
      connect();
    },
    onResume: () {
      if (dirty) run();
    },
    onCancel: () async {
      disposed = true;
      debounceTimer?.cancel();
      retryTimer?.cancel();
      reconnectTimer?.cancel();
      stopPolling();
      final ch = channel;
      channel = null;
      if (ch != null) {
        try {
          await sb.removeChannel(ch);
        } catch (_) {}
      }
    },
  );
  return ctrl.stream;
}
