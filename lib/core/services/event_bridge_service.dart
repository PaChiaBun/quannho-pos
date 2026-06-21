import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────
// EVENT BRIDGE SERVICE
// Đã đơn giản hóa: SaleCompletedEvent không còn cần thiết vì
// PosRepository.completeSale() đã tự ghi finance_records + loyalty_transactions
// trực tiếp lên Supabase trong cùng 1 luồng.
//
// File này giữ lại để tương thích — có thể dùng cho các event phức tạp hơn
// trong tương lai (ví dụ: low stock alert, end-of-day reports...)
// ─────────────────────────────────────────────────────────────────────────────
class EventBridgeService {
  final Ref _ref;

  EventBridgeService(this._ref);

  void start() {
    // PosRepository đã tích hợp finance + loyalty trực tiếp
    // Không cần EventBus trung gian nữa
  }

  void dispose() {}
}

final eventBridgeProvider = Provider<EventBridgeService>((ref) {
  final bridge = EventBridgeService(ref);
  bridge.start();
  ref.onDispose(bridge.dispose);
  return bridge;
});
