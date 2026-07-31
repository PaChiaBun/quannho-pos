import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/store_auth_service.dart';
import '../models/qr_order_model.dart';
import '../repository/qr_order_repository.dart';
import '../services/qr_sound_service.dart';

final qrOrderRepoProvider = Provider<QrOrderRepository>((ref) {
  return QrOrderRepository();
});

final qrOrderSettingsProvider = FutureProvider<QrOrderSettingsModel>((ref) async {
  final repo = ref.watch(qrOrderRepoProvider);
  return repo.getSettings();
});

final currentStoreIdProvider = FutureProvider<String?>((ref) async {
  final info = await StoreAuthService.getStoreInfo();
  return info['store_id'] as String?;
});

int _lastPendingCount = 0;

final pendingQrRequestsStreamProvider = StreamProvider<List<QrRequestModel>>((ref) async* {
  final repo = ref.watch(qrOrderRepoProvider);
  final storeIdAsync = ref.watch(currentStoreIdProvider);
  final storeId = storeIdAsync.asData?.value;
  if (storeId == null || storeId.isEmpty) {
    yield [];
    return;
  }

  await for (final list in repo.watchPendingRequests(storeId)) {
    if (list.length > _lastPendingCount) {
      // Sound & haptic trigger on staff device when a new pending request arrives
      QrSoundService.playNotificationSound();
    }
    _lastPendingCount = list.length;
    yield list;
  }
});

final pendingTableQrRequestsProvider = Provider<List<QrRequestModel>>((ref) {
  final all = ref.watch(pendingQrRequestsStreamProvider).asData?.value ?? [];
  return all.where((r) => r.type == 'table' && r.status == 'pending_staff').toList();
});

final pendingCounterQrRequestsProvider = Provider<List<QrRequestModel>>((ref) {
  final all = ref.watch(pendingQrRequestsStreamProvider).asData?.value ?? [];
  return all.where((r) => r.type == 'counter' && r.status == 'pending_staff').toList();
});
