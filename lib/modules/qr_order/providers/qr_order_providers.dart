import 'dart:async';
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

/// StreamProvider trả về QrFetchResult đầy đủ chứa danh sách đơn hàng active pipeline
/// (pending_staff -> processing -> confirmed) và chi tiết lỗi nếu có
final qrActivePipelineStreamProvider = StreamProvider<QrFetchResult>((
  ref,
) async* {
  final repo = ref.watch(qrOrderRepoProvider);
  bool isDisposed = false;
  List<QrRequestModel> lastGoodRequests = const [];

  ref.onDispose(() {
    isDisposed = true;
  });

  while (!isDisposed) {
    final result = await repo.fetchActiveRequestsPipeline(
      previousRequests: lastGoodRequests,
    );

    if (result.isSuccess) {
      lastGoodRequests = result.requests;

      // Kiểm tra xem có đơn pending_staff mới chưa từng phát âm báo không
      bool hasNewPendingOrder = false;
      for (final req in result.requests) {
        if (req.status == 'pending_staff' &&
            !_notifiedRequestIds.contains(req.id)) {
          _notifiedRequestIds.add(req.id);
          hasNewPendingOrder = true;
        }
      }

      if (hasNewPendingOrder) {
        // Phát âm thanh chime + rung haptic ĐÚNG 1 LẦN duy nhất cho đơn mới
        QrSoundService.playNotificationSound();
      }

      // Dọn dẹp _notifiedRequestIds
      final currentPendingIds = result.requests
          .where((e) => e.status == 'pending_staff')
          .map((e) => e.id)
          .toSet();
      _notifiedRequestIds.retainAll(currentPendingIds);
    }

    yield result;

    // Polling có kiểm soát mỗi 3.5 giây
    await Future.delayed(const Duration(milliseconds: 3500));
  }
});

/// Danh sách toàn bộ đơn active trong pipeline (pending_staff, processing, confirmed)
final activeQrRequestsProvider = Provider<List<QrRequestModel>>((ref) {
  final pipeline = ref.watch(qrActivePipelineStreamProvider).asData?.value;
  return pipeline?.requests ?? const [];
});

/// Thông tin lỗi của pipeline (nếu có)
final qrPipelineErrorProvider = Provider<QrFetchResult?>((ref) {
  final pipeline = ref.watch(qrActivePipelineStreamProvider).asData?.value;
  if (pipeline != null && !pipeline.isSuccess) {
    return pipeline;
  }
  return null;
});

/// Badge & danh sách đơn QR bàn đang chờ (`pending_staff`)
/// Đếm theo SỐ ĐƠN (request_id count) ở trạng thái pending_staff
final pendingTableQrRequestsProvider = Provider<List<QrRequestModel>>((ref) {
  final all = ref.watch(activeQrRequestsProvider);
  return all
      .where((r) => r.type == 'table' && r.status == 'pending_staff')
      .toList();
});

/// Badge & danh sách đơn QR quầy đang chờ (`pending_staff`)
/// Đếm theo SỐ ĐƠN (request_id count) ở trạng thái pending_staff
final pendingCounterQrRequestsProvider = Provider<List<QrRequestModel>>((ref) {
  final all = ref.watch(activeQrRequestsProvider);
  return all
      .where((r) => r.type == 'counter' && r.status == 'pending_staff')
      .toList();
});

/// Tải tất cả đơn active của một bàn cụ thể (pending_staff, processing, confirmed)
/// Giúp nhân viên mở lại được đơn đang xử lý sau khi reload app hoặc đóng sheet
final activeQrRequestsForTableProvider =
    Provider.family<List<QrRequestModel>, String>((ref, tableId) {
      final all = ref.watch(activeQrRequestsProvider);
      return all
          .where(
            (r) =>
                r.tableId == tableId &&
                (r.status == 'pending_staff' ||
                    r.status == 'processing' ||
                    r.status == 'confirmed'),
          )
          .toList();
    });

/// Tải tất cả đơn active của quầy thu ngân (pending_staff, processing, confirmed)
final activeCounterQrRequestsProvider = Provider<List<QrRequestModel>>((ref) {
  final all = ref.watch(activeQrRequestsProvider);
  return all
      .where(
        (r) =>
            r.type == 'counter' &&
            (r.status == 'pending_staff' ||
                r.status == 'processing' ||
                r.status == 'confirmed'),
      )
      .toList();
});
