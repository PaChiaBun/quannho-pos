import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

typedef RealtimeChannelSubscriber =
    FutureOr<RealtimeChannel> Function({
      required String channelName,
      required String storeId,
      required String userId,
      required void Function(Map<String, dynamic> payload) onPostgresChange,
      required void Function(RealtimeSubscribeStatus status, Object? error)
      onStatusChange,
    });

typedef TimerFactory =
    Timer Function(Duration duration, void Function() callback);

class StaffShiftRealtimeController {
  final void Function() onInvalidateOpenShift;
  final RealtimeChannelSubscriber? channelSubscriber;
  final TimerFactory timerFactory;

  String? _currentStoreId;
  String? _currentUserId;
  RealtimeChannel? _activeChannel;
  int _activeGeneration = 0;
  int _retryCount = 0;
  bool _isChannelHealthy = false;
  Timer? _retryTimer;
  bool _isDisposed = false;

  StaffShiftRealtimeController({
    required this.onInvalidateOpenShift,
    this.channelSubscriber,
    TimerFactory? timerFactory,
  }) : timerFactory = timerFactory ?? Timer.new;

  String? get currentStoreId => _currentStoreId;
  String? get currentUserId => _currentUserId;
  bool get isChannelHealthy => _isChannelHealthy;
  int get retryCount => _retryCount;
  bool get isDisposed => _isDisposed;
  RealtimeChannel? get activeChannel => _activeChannel;

  Future<void> start({required String storeId, required String userId}) async {
    if (_isDisposed) return;

    if (storeId.isEmpty || userId.isEmpty) {
      stop();
      return;
    }

    if (_currentStoreId == storeId &&
        _currentUserId == userId &&
        _isChannelHealthy &&
        _activeChannel != null) {
      return;
    }

    _retryTimer?.cancel();
    _retryTimer = null;
    _activeGeneration++;
    final generation = _activeGeneration;

    _cleanupChannel();

    _currentStoreId = storeId;
    _currentUserId = userId;
    _isChannelHealthy = false;

    try {
      if (channelSubscriber != null) {
        final channel = await channelSubscriber!(
          channelName: 'shift_sync_${userId}_$storeId',
          storeId: storeId,
          userId: userId,
          onPostgresChange: (payload) =>
              _handlePostgresChange(payload, generation, userId),
          onStatusChange: (status, error) =>
              _handleStatusChange(status, error, generation, storeId, userId),
        );
        if (_isDisposed || generation != _activeGeneration) {
          await channel.unsubscribe();
          return;
        }
        _activeChannel = channel;
      } else {
        final client = Supabase.instance.client;
        final ch = client
            .channel('shift_sync_${userId}_$storeId')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'staff_shifts',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'store_id',
                value: storeId,
              ),
              callback: (payload) {
                final record = payload.newRecord.isNotEmpty
                    ? payload.newRecord
                    : payload.oldRecord;
                _handlePostgresChange(record, generation, userId);
              },
            );

        _activeChannel = ch;
        ch.subscribe((status, [error]) {
          _handleStatusChange(status, error, generation, storeId, userId);
        });
      }
    } catch (e) {
      debugPrint('[StaffShiftRealtimeController] start error: $e');
      _scheduleRetry(storeId, userId);
    }
  }

  void manualReconnect() {
    if (_isDisposed) return;
    final storeId = _currentStoreId;
    final userId = _currentUserId;
    if (storeId != null && userId != null) {
      _retryCount = 0;
      _isChannelHealthy = false;
      start(storeId: storeId, userId: userId);
    }
  }

  void _handlePostgresChange(
    Map<String, dynamic> record,
    int generation,
    String targetUserId,
  ) {
    if (_isDisposed || generation != _activeGeneration) return;
    final eventUserId = record['user_id'] as String?;
    final eventStoreId = record['store_id'] as String?;
    if (eventUserId == targetUserId &&
        (eventStoreId == null || eventStoreId == _currentStoreId)) {
      onInvalidateOpenShift();
    }
  }

  void _handleStatusChange(
    RealtimeSubscribeStatus status,
    Object? error,
    int generation,
    String storeId,
    String userId,
  ) {
    if (_isDisposed || generation != _activeGeneration) return;

    if (status == RealtimeSubscribeStatus.subscribed) {
      _isChannelHealthy = true;
      _retryCount = 0;
      _retryTimer?.cancel();
      _retryTimer = null;
    } else if (status == RealtimeSubscribeStatus.channelError ||
        status == RealtimeSubscribeStatus.timedOut ||
        status == RealtimeSubscribeStatus.closed) {
      _isChannelHealthy = false;
      // Unsubscribe may emit another terminal status (usually `closed`).
      // Invalidate this generation first so one failed channel consumes only
      // one retry attempt.
      _activeGeneration++;
      _cleanupChannel();
      _scheduleRetry(storeId, userId);
    }
  }

  void _scheduleRetry(String storeId, String userId) {
    if (_isDisposed) return;

    if (_retryCount >= 3) {
      debugPrint(
        '[StaffShiftRealtimeController] Realtime connection attempts exhausted after 3 retries.',
      );
      return;
    }

    _retryCount++;
    final delaySeconds = 2 * (1 << (_retryCount - 1)); // 2s, 4s, 8s backoff
    _retryTimer?.cancel();
    _retryTimer = timerFactory(Duration(seconds: delaySeconds), () {
      if (!_isDisposed) {
        start(storeId: storeId, userId: userId);
      }
    });
  }

  void _cleanupChannel() {
    if (_activeChannel != null) {
      try {
        _activeChannel!.unsubscribe();
      } catch (_) {}
      _activeChannel = null;
    }
  }

  void stop() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _activeGeneration++;
    _cleanupChannel();
    _isChannelHealthy = false;
    _currentStoreId = null;
    _currentUserId = null;
    _retryCount = 0;
  }

  void dispose() {
    _isDisposed = true;
    stop();
  }
}
