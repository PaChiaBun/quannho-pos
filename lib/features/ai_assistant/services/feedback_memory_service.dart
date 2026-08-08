// lib/features/ai_assistant/services/feedback_memory_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Feedback, Memory & Learning Queue Service — Vòng lặp cải tiến có kiểm duyệt
// ─────────────────────────────────────────────────────────────────────────────

import 'pii_redactor.dart';

enum FeedbackRating { thumbsUp, thumbsDown }

class FeedbackEntry {
  final String id;
  final String messageId;
  final String storeId;
  final String userId;
  final FeedbackRating rating;
  final String? feedbackText;
  final String? reasonCode;
  final DateTime createdAt;

  FeedbackEntry({
    required this.id,
    required this.messageId,
    required this.storeId,
    required this.userId,
    required this.rating,
    this.feedbackText,
    this.reasonCode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class StoreMemory {
  final String id;
  final String storeId;
  final String category;
  final String key;
  final String value;
  final String createdBy;
  final bool isVerified;
  final DateTime createdAt;

  StoreMemory({
    required this.id,
    required this.storeId,
    required this.category,
    required this.key,
    required this.value,
    required this.createdBy,
    this.isVerified = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class FeedbackMemoryService {
  static final List<FeedbackEntry> _feedbackQueue = [];
  static final List<StoreMemory> _memoryStore = [];

  /// Ghi nhận phản hồi 👍 / 👎 từ người dùng (đã qua PII Redaction)
  static FeedbackEntry recordFeedback({
    required String id,
    required String messageId,
    required String storeId,
    required String userId,
    required FeedbackRating rating,
    String? feedbackText,
    String? reasonCode,
  }) {
    final cleanText = feedbackText != null ? PiiRedactor.redact(feedbackText) : null;

    final entry = FeedbackEntry(
      id: id,
      messageId: messageId,
      storeId: storeId,
      userId: userId,
      rating: rating,
      feedbackText: cleanText,
      reasonCode: reasonCode,
    );

    _feedbackQueue.add(entry);
    return entry;
  }

  /// Thêm trí nhớ riêng cho quán (Store Memory — Cô lập theo store_id)
  static StoreMemory addStoreMemory({
    required String id,
    required String storeId,
    required String category,
    required String key,
    required String value,
    required String createdBy,
    bool isOwner = false,
  }) {
    // Chỉ Owner hoặc nhân viên có quyền mới được xác nhận memory
    final cleanValue = PiiRedactor.redact(value);

    final memory = StoreMemory(
      id: id,
      storeId: storeId,
      category: category,
      key: key,
      value: cleanValue,
      createdBy: createdBy,
      isVerified: isOwner,
    );

    _memoryStore.add(memory);
    return memory;
  }

  /// Truy vấn trí nhớ của một quán
  static List<StoreMemory> getMemoriesForStore(String storeId) {
    return _memoryStore.where((m) => m.storeId == storeId && m.isVerified).toList();
  }

  static int get pendingFeedbackCount => _feedbackQueue.length;
  static int get totalMemoriesCount => _memoryStore.length;
}
