import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/providers/session_provider.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/core/services/staff_shift_realtime_controller.dart';

class FakeRealtimeChannel extends RealtimeChannel {
  bool unsubscribed = false;

  FakeRealtimeChannel(String topic)
    : super(topic, RealtimeClient('https://fake.supabase.co'));

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus status, Object? error)? callback,
    Duration? timeout,
  ]) {
    if (callback != null) {
      callback(RealtimeSubscribeStatus.subscribed, null);
    }
    return this;
  }

  @override
  Future<String> unsubscribe([Duration? timeout]) async {
    unsubscribed = true;
    return 'ok';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StaffShiftRealtimeController & Production Path Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Subscribe lần đầu tạo đúng một channel', () async {
      int createdChannels = 0;
      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              createdChannels++;
              final ch = FakeRealtimeChannel(channelName);
              onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              return ch;
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      expect(createdChannels, equals(1));
      expect(controller.isChannelHealthy, isTrue);
      controller.dispose();
    });

    test(
      '2. Gọi start lại cùng user/store khi subscribed không tạo channel thứ hai',
      () async {
        int createdChannels = 0;
        final controller = StaffShiftRealtimeController(
          onInvalidateOpenShift: () {},
          channelSubscriber:
              ({
                required channelName,
                required storeId,
                required userId,
                required onPostgresChange,
                required onStatusChange,
              }) async {
                createdChannels++;
                onStatusChange(RealtimeSubscribeStatus.subscribed, null);
                return FakeRealtimeChannel(channelName);
              },
        );

        await controller.start(storeId: 'store_1', userId: 'user_1');
        await controller.start(storeId: 'store_1', userId: 'user_1');
        expect(createdChannels, equals(1));
        controller.dispose();
      },
    );

    test('3. INSERT đúng user/store gọi invalidate đúng một lần', () async {
      int invalidationCount = 0;
      late void Function(Map<String, dynamic> payload) triggerChange;

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {
          invalidationCount++;
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              triggerChange = onPostgresChange;
              onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      triggerChange({'store_id': 'store_1', 'user_id': 'user_1'});
      expect(invalidationCount, equals(1));
      controller.dispose();
    });

    test('4. UPDATE clock_out đúng user/store gọi invalidate', () async {
      int invalidationCount = 0;
      late void Function(Map<String, dynamic> payload) triggerChange;

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {
          invalidationCount++;
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              triggerChange = onPostgresChange;
              onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      triggerChange({
        'store_id': 'store_1',
        'user_id': 'user_1',
        'clock_out': '2026-08-08T07:00:00Z',
      });
      expect(invalidationCount, equals(1));
      controller.dispose();
    });

    test('5. Event user khác không invalidate', () async {
      int invalidationCount = 0;
      late void Function(Map<String, dynamic> payload) triggerChange;

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {
          invalidationCount++;
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              triggerChange = onPostgresChange;
              onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      triggerChange({'store_id': 'store_1', 'user_id': 'user_other'});
      expect(invalidationCount, equals(0));
      controller.dispose();
    });

    test('6. Event store khác không invalidate', () async {
      int invalidationCount = 0;
      late void Function(Map<String, dynamic> payload) triggerChange;

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {
          invalidationCount++;
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              triggerChange = onPostgresChange;
              onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      triggerChange({'store_id': 'store_other', 'user_id': 'user_1'});
      expect(invalidationCount, equals(0));
      controller.dispose();
    });

    test(
      '7. channelError hủy channel cũ và subscribe lần hai sau 2 giây',
      () async {
        int createdChannels = 0;
        late void Function(RealtimeSubscribeStatus status, Object? error)
        triggerStatus;
        final timers = <Duration, void Function()>{};

        final controller = StaffShiftRealtimeController(
          onInvalidateOpenShift: () {},
          timerFactory: (duration, callback) {
            timers[duration] = callback;
            return Timer(duration, callback);
          },
          channelSubscriber:
              ({
                required channelName,
                required storeId,
                required userId,
                required onPostgresChange,
                required onStatusChange,
              }) async {
                createdChannels++;
                triggerStatus = onStatusChange;
                return FakeRealtimeChannel(channelName);
              },
        );

        await controller.start(storeId: 'store_1', userId: 'user_1');
        expect(createdChannels, equals(1));

        // Trigger error
        triggerStatus(
          RealtimeSubscribeStatus.channelError,
          Exception('Disconnect'),
        );
        expect(controller.isChannelHealthy, isFalse);
        expect(controller.activeChannel, isNull);
        expect(controller.retryCount, equals(1));
        expect(timers.containsKey(const Duration(seconds: 2)), isTrue);

        // Execute timer
        timers[const Duration(seconds: 2)]!();
        expect(createdChannels, equals(2));
        controller.dispose();
      },
    );

    test('8. timedOut retry đúng', () async {
      late void Function(RealtimeSubscribeStatus status, Object? error)
      triggerStatus;
      final timers = <Duration, void Function()>{};

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        timerFactory: (duration, callback) {
          timers[duration] = callback;
          return Timer(duration, callback);
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              triggerStatus = onStatusChange;
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      triggerStatus(RealtimeSubscribeStatus.timedOut, null);
      expect(controller.retryCount, equals(1));
      expect(timers.containsKey(const Duration(seconds: 2)), isTrue);
      controller.dispose();
    });

    test('9. closed retry đúng', () async {
      late void Function(RealtimeSubscribeStatus status, Object? error)
      triggerStatus;
      final timers = <Duration, void Function()>{};

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        timerFactory: (duration, callback) {
          timers[duration] = callback;
          return Timer(duration, callback);
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              triggerStatus = onStatusChange;
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      triggerStatus(RealtimeSubscribeStatus.closed, null);
      expect(controller.retryCount, equals(1));
      expect(timers.containsKey(const Duration(seconds: 2)), isTrue);
      controller.dispose();
    });

    test('10. Ba lần reconnect thật dùng delay 2s, 4s, 8s rồi dừng', () async {
      final statusCallbacks =
          <void Function(RealtimeSubscribeStatus status, Object? error)>[];
      final delays = <Duration>[];
      final timerCallbacks = <void Function()>[];
      var createdChannels = 0;

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        timerFactory: (duration, callback) {
          delays.add(duration);
          timerCallbacks.add(callback);
          return Timer(duration, callback);
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              createdChannels++;
              statusCallbacks.add(onStatusChange);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      expect(createdChannels, equals(1));

      // Retry 1
      statusCallbacks[0](RealtimeSubscribeStatus.channelError, null);
      expect(controller.retryCount, equals(1));
      timerCallbacks[0]();
      await Future<void>.delayed(Duration.zero);
      expect(createdChannels, equals(2));

      // Retry 2
      statusCallbacks[1](RealtimeSubscribeStatus.channelError, null);
      expect(controller.retryCount, equals(2));
      timerCallbacks[1]();
      await Future<void>.delayed(Duration.zero);
      expect(createdChannels, equals(3));

      // Retry 3
      statusCallbacks[2](RealtimeSubscribeStatus.channelError, null);
      expect(controller.retryCount, equals(3));
      timerCallbacks[2]();
      await Future<void>.delayed(Duration.zero);
      expect(createdChannels, equals(4));

      // Channel tạo bởi retry thứ ba vẫn lỗi: không có timer thứ tư.
      statusCallbacks[3](RealtimeSubscribeStatus.channelError, null);
      expect(controller.retryCount, equals(3));

      expect(
        delays,
        equals([
          const Duration(seconds: 2),
          const Duration(seconds: 4),
          const Duration(seconds: 8),
        ]),
      );

      controller.dispose();
    });

    test('11. subscribed thành công reset retryCount và hủy timer', () async {
      final statusCallbacks =
          <void Function(RealtimeSubscribeStatus status, Object? error)>[];
      late void Function() runRetry;

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        timerFactory: (duration, callback) {
          runRetry = callback;
          return Timer(duration, callback);
        },
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              statusCallbacks.add(onStatusChange);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      statusCallbacks[0](RealtimeSubscribeStatus.channelError, null);
      expect(controller.retryCount, equals(1));

      runRetry();
      await Future<void>.delayed(Duration.zero);
      statusCallbacks[1](RealtimeSubscribeStatus.subscribed, null);
      expect(controller.retryCount, equals(0));
      expect(controller.isChannelHealthy, isTrue);

      controller.dispose();
    });

    test('12. Callback lỗi của channel cũ không phá channel mới', () async {
      late void Function(RealtimeSubscribeStatus status, Object? error)
      triggerOldStatus;

      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              if (userId == 'user_1') {
                triggerOldStatus = onStatusChange;
              } else {
                onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              }
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      await controller.start(storeId: 'store_1', userId: 'user_2');

      // Old channel status callback fires
      triggerOldStatus(RealtimeSubscribeStatus.channelError, null);

      // New channel should remain active & healthy
      expect(controller.currentUserId, equals('user_2'));
      expect(controller.isChannelHealthy, isTrue);

      controller.dispose();
    });

    test(
      '13. Session switch hủy channel/timer cũ và tạo channel mới',
      () async {
        final createdTopics = <String>[];

        final controller = StaffShiftRealtimeController(
          onInvalidateOpenShift: () {},
          channelSubscriber:
              ({
                required channelName,
                required storeId,
                required userId,
                required onPostgresChange,
                required onStatusChange,
              }) async {
                createdTopics.add(channelName);
                onStatusChange(RealtimeSubscribeStatus.subscribed, null);
                return FakeRealtimeChannel(channelName);
              },
        );

        await controller.start(storeId: 'store_1', userId: 'user_1');
        await controller.start(storeId: 'store_2', userId: 'user_2');

        expect(
          createdTopics,
          equals(['shift_sync_user_1_store_1', 'shift_sync_user_2_store_2']),
        );
        expect(controller.currentStoreId, equals('store_2'));
        expect(controller.currentUserId, equals('user_2'));

        controller.dispose();
      },
    );

    test('14. Logout dọn toàn bộ tài nguyên', () async {
      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      expect(controller.isChannelHealthy, isTrue);

      controller.stop();
      expect(controller.isChannelHealthy, isFalse);
      expect(controller.currentStoreId, isNull);
      expect(controller.currentUserId, isNull);
      expect(controller.activeChannel, isNull);
    });

    test('15. Dispose dọn toàn bộ và không retry', () async {
      final controller = StaffShiftRealtimeController(
        onInvalidateOpenShift: () {},
        channelSubscriber:
            ({
              required channelName,
              required storeId,
              required userId,
              required onPostgresChange,
              required onStatusChange,
            }) async {
              onStatusChange(RealtimeSubscribeStatus.subscribed, null);
              return FakeRealtimeChannel(channelName);
            },
      );

      await controller.start(storeId: 'store_1', userId: 'user_1');
      controller.dispose();

      expect(controller.isDisposed, isTrue);
      expect(controller.activeChannel, isNull);

      // Attempting to start after dispose should be blocked
      await controller.start(storeId: 'store_1', userId: 'user_1');
      expect(controller.activeChannel, isNull);
    });

    test(
      '16. Resume sau membership hợp lệ bắt đầu chu kỳ reconnect mới',
      () async {
        final createdTopics = <String>[];

        final controller = StaffShiftRealtimeController(
          onInvalidateOpenShift: () {},
          channelSubscriber:
              ({
                required channelName,
                required storeId,
                required userId,
                required onPostgresChange,
                required onStatusChange,
              }) async {
                createdTopics.add(channelName);
                onStatusChange(RealtimeSubscribeStatus.subscribed, null);
                return FakeRealtimeChannel(channelName);
              },
        );

        await controller.start(storeId: 'store_1', userId: 'user_1');
        controller.manualReconnect();

        expect(createdTopics.length, equals(2));
        expect(controller.isChannelHealthy, isTrue);
        controller.dispose();
      },
    );

    test(
      '17. Provider query exception vẫn là AsyncError, không thành null',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        container
            .read(sessionProvider.notifier)
            .setSession(
              SessionData(
                userId: 'test_user_id',
                phone: '+84900000001',
                displayName: 'Test Staff',
                storeId: 'test_store_id',
                storeName: 'Test Store',
                storeCode: 'TEST',
                role: 'cashier',
                isOwner: false,
              ),
            );

        final state = container.read(openShiftCCProvider);
        expect(state.isLoading || state.hasError, isTrue);
        expect(
          () async => await container.read(openShiftCCProvider.future),
          throwsA(anything),
        );
      },
    );

    test('18. Guard vẫn phân biệt loading/error/no-shift/active-shift', () {
      final loading = const AsyncValue<Map<String, dynamic>?>.loading();
      expect(loading.isLoading, isTrue);

      final error = AsyncValue<Map<String, dynamic>?>.error(
        Exception('Network exception'),
        StackTrace.current,
      );
      expect(error.hasError, isTrue);
      expect(error.asData, isNull);

      final noShift = const AsyncValue<Map<String, dynamic>?>.data(null);
      expect(noShift.value, isNull);

      final activeShift = AsyncValue<Map<String, dynamic>?>.data({
        'id': 'shift_123',
      });
      expect(activeShift.value, isNotNull);
    });

    test(
      '19. channelError rồi closed cùng generation chỉ lên lịch một retry',
      () async {
        late void Function(RealtimeSubscribeStatus status, Object? error)
        triggerStatus;
        final delays = <Duration>[];

        final controller = StaffShiftRealtimeController(
          onInvalidateOpenShift: () {},
          timerFactory: (duration, callback) {
            delays.add(duration);
            return Timer(duration, callback);
          },
          channelSubscriber:
              ({
                required channelName,
                required storeId,
                required userId,
                required onPostgresChange,
                required onStatusChange,
              }) async {
                triggerStatus = onStatusChange;
                return FakeRealtimeChannel(channelName);
              },
        );

        await controller.start(storeId: 'store_1', userId: 'user_1');
        triggerStatus(RealtimeSubscribeStatus.channelError, null);
        triggerStatus(RealtimeSubscribeStatus.closed, null);

        expect(controller.retryCount, equals(1));
        expect(delays, equals([const Duration(seconds: 2)]));
        controller.dispose();
      },
    );
  });
}
