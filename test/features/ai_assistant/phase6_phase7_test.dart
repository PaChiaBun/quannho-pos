// test/features/ai_assistant/phase6_phase7_test.dart
// ─────────────────────────────────────────────────────────────────────────────
// Test Suite cho Phase 6 (OpenAI Fallback & PII Redaction) & Phase 7 (Feedback & Memory)
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/services/pii_redactor.dart';
import 'package:quannho_pos/features/ai_assistant/services/openai_fallback_service.dart';
import 'package:quannho_pos/features/ai_assistant/services/feedback_memory_service.dart';

void main() {
  group('Phase 6: PII Redaction & OpenAI Fallback Security Tests', () {
    test('Khử 100% SĐT Việt Nam, Email và mã PIN', () {
      const rawText = 'Gọi cho anh Nam số 0912345678 hoặc email test@gmail.com, password: 123456';
      final cleanText = PiiRedactor.redact(rawText);

      expect(cleanText.contains('0912345678'), isFalse);
      expect(cleanText.contains('test@gmail.com'), isFalse);
      expect(cleanText.contains('password: 123456'), isFalse);
      expect(cleanText, contains('[REDACTED_PHONE]'));
      expect(cleanText, contains('[REDACTED_EMAIL]'));
      expect(cleanText, contains('[REDACTED_SECRET]'));
    });

    test('Cloud Fallback ngắt khi ngầm mở Circuit Breaker', () async {
      OpenAiFallbackService.triggerCircuitBreaker();
      final res = await OpenAiFallbackService.queryFallback(
        storeId: 'store_kay_01',
        userQuery: 'Câu hỏi nâng cao',
        intent: 'business_advice',
        ragSources: [],
      );

      expect(res.success, isFalse);
      expect(res.errorReason, equals('circuit_breaker_open'));
      expect(res.source, equals('local_fallback'));

      OpenAiFallbackService.resetCircuitBreaker();
    });

    test('Giới hạn hạn mức Daily Token per Store', () async {
      const storeId = 'store_kay_quota';
      // Giả lập vượt hạn mức
      for (int i = 0; i < 1500; i++) {
        await OpenAiFallbackService.queryFallback(
          storeId: storeId,
          userQuery: 'Doanh thu',
          intent: 'revenue_summary',
          ragSources: [],
        );
      }

      final res = await OpenAiFallbackService.queryFallback(
        storeId: storeId,
        userQuery: 'Câu hỏi bùng nổ quota',
        intent: 'revenue_summary',
        ragSources: [],
      );

      expect(res.success, isFalse);
      expect(res.errorReason, equals('daily_budget_exceeded'));
    });
  });

  group('Phase 7: Feedback & Store Memory Isolation Tests', () {
    test('Ghi nhận Feedback 👍/👎 và khử PII trong nội dung góp ý', () {
      final entry = FeedbackMemoryService.recordFeedback(
        id: 'fb_1',
        messageId: 'msg_100',
        storeId: 'store_kay_01',
        userId: 'user_01',
        rating: FeedbackRating.thumbsDown,
        feedbackText: 'Số điện thoại 0987654321 trả về chưa đúng',
        reasonCode: 'wrong_data',
      );

      expect(entry.feedbackText, contains('[REDACTED_PHONE]'));
      expect(entry.feedbackText!.contains('0987654321'), isFalse);
    });

    test('Trí nhớ riêng từng quán (Store Memory) cô lập 100% theo store_id', () {
      FeedbackMemoryService.addStoreMemory(
        id: 'mem_1',
        storeId: 'store_kay_01',
        category: 'pricing',
        key: 'giam_gia_sinh_nhat',
        value: 'Giảm 15% cho khách sinh nhật trong tháng',
        createdBy: 'owner_kay',
        isOwner: true,
      );

      FeedbackMemoryService.addStoreMemory(
        id: 'mem_2',
        storeId: 'store_khac_99',
        category: 'pricing',
        key: 'giam_gia_sinh_nhat',
        value: 'Giảm 50% cho quán khác',
        createdBy: 'owner_khac',
        isOwner: true,
      );

      final kayMemories = FeedbackMemoryService.getMemoriesForStore('store_kay_01');
      expect(kayMemories.length, equals(1));
      expect(kayMemories.first.value, contains('15%'));
      expect(kayMemories.first.value.contains('50%'), isFalse);
    });
  });
}
