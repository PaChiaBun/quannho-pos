import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart' show allModulesProvider;
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../repository/qr_order_repository.dart';
import '../services/qr_sound_service.dart';

final qrOrderRepoProvider = Provider<QrOrderRepository>((ref) {
  return QrOrderRepository();
});

final qrOrderSettingsProvider = FutureProvider<QrOrderSettingsModel>((
  ref,
) async {
  final repo = ref.watch(qrOrderRepoProvider);
  return repo.getSettings();
});

final currentStoreIdProvider = FutureProvider<String?>((ref) async {
  final info = await StoreAuthService.getStoreInfo();
  return info['store_id'];
});

// Set lưu các request_id đã phát âm báo -> Đảm bảo chỉ phát âm báo DÙNG ĐÚNG 1 LẦN cho mỗi đơn mới
final Set<String> _notifiedRequestIds = {};

bool _sameFetchResult(QrFetchResult? previous, QrFetchResult next) {
  if (previous == null ||
      previous.isSuccess != next.isSuccess ||
      previous.errorCode != next.errorCode ||
      previous.errorMessage != next.errorMessage ||
      previous.requests.length != next.requests.length) {
    return false;
  }
  for (var i = 0; i < next.requests.length; i++) {
    if (jsonEncode(previous.requests[i].toMap()) !=
        jsonEncode(next.requests[i].toMap())) {
      return false;
    }
  }
  return true;
}

/// Chu kỳ poll hàng chờ. Tạm dừng khi app ở nền.
const Duration _kPollInterval = Duration(seconds: 8);

bool _appInForeground() {
  final st = WidgetsBinding.instance.lifecycleState;
  return st == null || st == AppLifecycleState.resumed;
}

/// Quán đã bật module QR hay chưa. Chưa bật thì không poll, không hiện nút/huy hiệu QR.
final qrModuleEnabledProvider = Provider.autoDispose<bool>((ref) {
  final modules = ref.watch(allModulesProvider).asData?.value;
  if (modules == null) return false;
  return modules.any((m) => m.id == 'qr_order' && m.isActive);
});

/// StreamProvider trả về QrFetchResult chứa hàng chờ chung (TABLE + COUNTER).
final qrActivePipelineStreamProvider =
    StreamProvider.autoDispose<QrFetchResult>((ref) async* {
      final repo = ref.watch(qrOrderRepoProvider);
      if (!ref.watch(qrModuleEnabledProvider)) {
        yield QrFetchResult.success(const []);
        return;
      }
      final storeInfo = await StoreAuthService.getStoreInfo();
      final storeId = storeInfo['store_id'] ?? '';
      bool isDisposed = false;
      List<QrRequestModel> lastGoodRequests = const [];
      QrFetchResult? lastEmittedResult;

      ref.onDispose(() {
        isDisposed = true;
      });

      while (!isDisposed) {
        if (storeId.isEmpty) {
          yield QrFetchResult.success(const []);
          return;
        }

        if (!_appInForeground()) {
          await Future.delayed(_kPollInterval);
          continue;
        }

        final result = await repo.fetchActiveRequestsPipeline(
          storeId: storeId,
          previousRequests: lastGoodRequests,
        );
        if (isDisposed) return;

        if (result.isSuccess) {
          lastGoodRequests = result.requests;

          // Phát chuông ĐÚNG 1 LẦN cho mỗi đơn mới chờ nhận
          bool hasNewOrder = false;
          for (final req in result.requests) {
            if (req.isSubmitted && !_notifiedRequestIds.contains(req.id)) {
              _notifiedRequestIds.add(req.id);
              hasNewOrder = true;
            }
          }
          if (hasNewOrder) {
            QrSoundService.playNotificationSound();
          }
          _notifiedRequestIds.retainAll(
            result.requests.where((e) => e.isSubmitted).map((e) => e.id).toSet(),
          );
        }

        if (!_sameFetchResult(lastEmittedResult, result)) {
          lastEmittedResult = result;
          yield result;
        }

        await Future.delayed(_kPollInterval);
      }
    });

/// Hàng chờ chung: mọi đơn QR chưa gửi bếp (cũ nhất trước).
final activeQrRequestsProvider = Provider.autoDispose<List<QrRequestModel>>((
  ref,
) {
  final pipeline = ref.watch(qrActivePipelineStreamProvider).asData?.value;
  return pipeline?.requests ?? const [];
});

/// Kết quả pipeline lỗi (dữ liệu hiển thị đang cũ) hoặc null nếu ổn.
final qrPipelineErrorProvider = Provider.autoDispose<QrFetchResult?>((ref) {
  final pipeline = ref.watch(qrActivePipelineStreamProvider).asData?.value;
  if (pipeline != null && pipeline.isStale) {
    return pipeline;
  }
  return null;
});

/// Số đơn đang chờ nhân viên nhận (cho huy hiệu).
final pendingQrCountProvider = Provider.autoDispose<int>((ref) {
  return ref.watch(activeQrRequestsProvider).where((r) => r.isSubmitted).length;
});

/// Các đơn đang mở của một bàn (khách chọn bàn đó).
final activeQrRequestsForTableProvider = Provider.autoDispose
    .family<List<QrRequestModel>, String>((ref, tableId) {
      final all = ref.watch(activeQrRequestsProvider);
      return all.where((r) => r.isTable && r.tableId == tableId).toList();
    });

/// Theo dõi một đơn theo id từ hàng chờ (null nếu đã rời hàng chờ).
final qrRequestByIdProvider = Provider.autoDispose
    .family<QrRequestModel?, String>((ref, id) {
      final all = ref.watch(activeQrRequestsProvider);
      for (final r in all) {
        if (r.id == id) return r;
      }
      return null;
    });


/// Kênh QR đang bị khoá do quét phá — poll 10 giây (chỉ khi module bật và app ở nền trước).
final qrLockedChannelsProvider =
    StreamProvider.autoDispose<List<QrChannelModel>>((ref) async* {
      final repo = ref.watch(qrOrderRepoProvider);
      if (!ref.watch(qrModuleEnabledProvider)) {
        yield const [];
        return;
      }
      final storeInfo = await StoreAuthService.getStoreInfo();
      final storeId = storeInfo['store_id'] ?? '';
      bool isDisposed = false;
      ref.onDispose(() => isDisposed = true);
      var lastKey = '';
      while (!isDisposed && storeId.isNotEmpty) {
        if (_appInForeground()) {
          final list = await repo.getLockedChannels(storeId);
          if (isDisposed) return;
          final key = list.map((c) => '${c.id}:${c.lockedAt?.toIso8601String()}').join('|');
          if (key != lastKey) {
            lastKey = key;
            yield list;
          }
        }
        await Future.delayed(const Duration(seconds: 10));
      }
    });
