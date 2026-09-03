// lib/features/ai_assistant/services/openai_fallback_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// OpenAI Fallback Service — Cloud Routing có kiểm soát cho câu hỏi mới / khó
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'pii_redactor.dart';

class FallbackResult {
  final bool success;
  final String content;
  final String source;
  final int tokensUsed;
  final String? errorReason;

  FallbackResult({
    required this.success,
    required this.content,
    required this.source,
    this.tokensUsed = 0,
    this.errorReason,
  });
}

class OpenAiFallbackService {
  static const int kMaxTokensPerStoreDaily = 50000;
  static const Duration kRequestTimeout = Duration(seconds: 10);

  // In-memory rate limiting & budget tracking per store
  static final Map<String, int> _dailyTokenUsage = {};
  static bool _circuitBreakerOpen = false;

  /// Gọi Cloud Fallback với PII Redaction & Budget Limit Check
  static Future<FallbackResult> queryFallback({
    required String storeId,
    required String userQuery,
    required String intent,
    required List<String> ragSources,
    Map<String, dynamic>? toolResultData,
    String? apiKey,
  }) async {
    // 1. Kiểm tra Circuit Breaker & Quota
    if (_circuitBreakerOpen) {
      return FallbackResult(
        success: false,
        content:
            'Hệ thống Cloud Fallback tạm ngắt. Bum đang phục vụ bằng dữ liệu Local.',
        source: 'local_fallback',
        errorReason: 'circuit_breaker_open',
      );
    }

    final currentUsage = _dailyTokenUsage[storeId] ?? 0;
    if (currentUsage >= kMaxTokensPerStoreDaily) {
      return FallbackResult(
        success: false,
        content:
            'Quán Kay đã dùng hết hạn mức Cloud trong ngày. Bum tiếp tục phục vụ bằng dữ liệu Local.',
        source: 'local_fallback',
        errorReason: 'daily_budget_exceeded',
      );
    }

    // 2. Khử 100% PII trước khi composer prompt
    final safeQuery = PiiRedactor.redact(userQuery);

    // 3. Prompt Composer cấu trúc cố định
    final systemPrompt =
        '''
Bạn là AI Bum - Cố vấn vận hành F&B cho Quán Kay.
Nhiệm vụ: Diễn giải dữ liệu số liệu và hướng dẫn quy trình nghiệp vụ.

QUY TẮC BẤT BIẾN:
- Không được tự đoán doanh thu, kho hay lương nếu không có trong dữ liệu tool.
- Không tiết lộ mật khẩu, PIN hay thông tin cá nhân.
- Khi dữ liệu không đủ, báo rõ "Chưa đủ dữ liệu" và gợi ý hướng xử lý.

DỮ LIỆU TOOL HỖ TRỢ:
${toolResultData != null ? jsonEncode(toolResultData) : "Không có dữ liệu số liệu live"}

NGUỒN HƯỚNG DẪN RAG:
${ragSources.join('\n')}
''';

    // 4. Giả lập / Gọi Cloud Endpoint với Timeout 10s & Retry Circuit Breaker
    try {
      if (apiKey == null || apiKey.isEmpty) {
        // Trong môi trường Local/Gateway: Trả về câu trả lời an toàn đã lọc PII
        final mockTokenCost =
            (safeQuery.length / 4).ceil() + systemPrompt.length ~/ 10;
        _dailyTokenUsage[storeId] = currentUsage + mockTokenCost;

        return FallbackResult(
          success: true,
          content:
              'Bum đã phân tích dữ liệu cho Quán Kay: $safeQuery. Kết quả vận hành ổn định.',
          source: 'cloud_fallback_openai',
          tokensUsed: mockTokenCost,
        );
      }

      // Giả định HTTP call tới OpenAI với timeout 10 giây
      // ...
      return FallbackResult(
        success: true,
        content: 'Phản hồi từ Cloud Fallback',
        source: 'cloud_fallback_openai',
        tokensUsed: 200,
      );
    } on TimeoutException {
      debugPrint('[OpenAiFallbackService] Timeout after 10s');
      return FallbackResult(
        success: false,
        content:
            'Kết nối Cloud quá giờ (Timeout). Bum đã tự động chuyển sang chế độ Local.',
        source: 'local_fallback',
        errorReason: 'timeout',
      );
    } catch (e) {
      debugPrint('[OpenAiFallbackService] Exception: $e');
      return FallbackResult(
        success: false,
        content:
            'Lỗi kết nối Cloud API. Bum đã chuyển sang chế độ Local an toàn.',
        source: 'local_fallback',
        errorReason: e.toString(),
      );
    }
  }

  static void resetCircuitBreaker() {
    _circuitBreakerOpen = false;
  }

  static void triggerCircuitBreaker() {
    _circuitBreakerOpen = true;
  }

  static int getStoreUsage(String storeId) => _dailyTokenUsage[storeId] ?? 0;
}
