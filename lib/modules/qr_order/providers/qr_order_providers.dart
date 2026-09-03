import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// StreamProvider trả về QrFetchResult đầy đủ chứa danh sách đơn hàng active pipeline
final qrActivePipelineStreamProvider =
    StreamProvider.autoDispose<QrFetchResult>((ref) async* {
      final repo = ref.watch(qrOrderRepoProvider);
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
          await Future.delayed(const Duration(seconds: 5));
          continue;
        }

        final result = await repo.fetchActiveRequestsPipeline(
          storeId: storeId,
          previousRequests: lastGoodRequests,
        );
        if (isDisposed) return;

        if (result.isSuccess) {
          lastGoodRequests = result.requests;

          // Kiểm tra xem có đơn mới chưa từng phát âm báo không
          bool hasNewOrder = false;
          for (final req in result.requests) {
            if (req.isSubmitted && !_notifiedRequestIds.contains(req.id)) {
              _notifiedRequestIds.add(req.id);
              hasNewOrder = true;
            }
          }

          if (hasNewOrder) {
            // Phát âm thanh chime + rung haptic ĐÚNG 1 LẦN duy nhất cho đơn mới
            QrSoundService.playNotificationSound();
          }

          // Dọn dẹp _notifiedRequestIds
          final currentPendingIds = result.requests
              .where((e) => e.isSubmitted)
              .map((e) => e.id)
              .toSet();
          _notifiedRequestIds.retainAll(currentPendingIds);
        }

        if (!_sameFetchResult(lastEmittedResult, result)) {
          lastEmittedResult = result;
          yield result;
        }

        await Future.delayed(const Duration(seconds: 5));
      }
    });

/// Danh sách toàn bộ đơn active trong pipeline
final activeQrRequestsProvider = Provider.autoDispose<List<QrRequestModel>>((
  ref,
) {
  final pipeline = ref.watch(qrActivePipelineStreamProvider).asData?.value;
  return pipeline?.requests ?? const [];
});

/// Thông tin lỗi của pipeline (nếu có)
final qrPipelineErrorProvider = Provider.autoDispose<QrFetchResult?>((ref) {
  final pipeline = ref.watch(qrActivePipelineStreamProvider).asData?.value;
  if (pipeline != null && !pipeline.isSuccess) {
    return pipeline;
  }
  return null;
});

/// Badge & danh sách đơn QR bàn đang chờ nhân viên nhận (`customer_submitted` / `pending_staff`)
final pendingTableQrRequestsProvider =
    Provider.autoDispose<List<QrRequestModel>>((ref) {
      final all = ref.watch(activeQrRequestsProvider);
      return all.where((r) => r.isTable && r.isSubmitted).toList();
    });

/// Badge & danh sách đơn QR quầy đang chờ nhân viên nhận (`customer_submitted` / `pending_staff`)
final pendingCounterQrRequestsProvider =
    Provider.autoDispose<List<QrRequestModel>>((ref) {
      final all = ref.watch(activeQrRequestsProvider);
      return all.where((r) => r.isCounter && r.isSubmitted).toList();
    });

/// Tải tất cả đơn active của một bàn cụ thể
final activeQrRequestsForTableProvider = Provider.autoDispose
    .family<List<QrRequestModel>, String>((ref, tableId) {
      final all = ref.watch(activeQrRequestsProvider);
      return all
          .where(
            (r) =>
                r.assignedTableId == tableId &&
                (r.isSubmitted || r.isClaimed || r.isReviewing),
          )
          .toList();
    });

/// Tải tất cả đơn active của quầy thu ngân
final activeCounterQrRequestsProvider =
    Provider.autoDispose<List<QrRequestModel>>((ref) {
      final all = ref.watch(activeQrRequestsProvider);
      return all
          .where(
            (r) =>
                r.isCounter &&
                (r.isSubmitted ||
                    r.isClaimed ||
                    r.isReviewing ||
                    r.isAwaitingPayment ||
                    r.isReadyForKitchen),
          )
          .toList();
    });
