// lib/features/ai_assistant/providers/bum_chat_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Bum Chat Provider — Truy vấn dữ liệu thực tế từ Supabase cho Quán Kay
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/session_provider.dart';
import '../classifier/intent_classifier.dart';
import '../models/bum_message.dart';
import '../services/bum_read_only_data_service.dart';
import '../services/bum_telemetry_service.dart';
import '../services/feedback_service.dart';

final bumChatProvider = NotifierProvider<BumChatNotifier, List<BumMessage>>(
  BumChatNotifier.new,
);

class BumChatNotifier extends Notifier<List<BumMessage>> {
  bool _mounted = true;

  @override
  List<BumMessage> build() {
    ref.onDispose(() {
      _mounted = false;
    });
    return [
      BumMessage(
        content:
            'Chào cậu! Tớ là Bum. Tớ có thể giúp cậu xem báo cáo doanh thu, món bán chạy, hay tìm thông tin của quán. Cậu muốn hỏi gì nào?',
        role: MessageRole.bum,
      ),
    ];
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Add user message
    final userMsg = BumMessage(content: text, role: MessageRole.user);
    state = [...state, userMsg];

    await _processReply(text, sourceUserMessageId: userMsg.id);
  }

  Future<void> retryLastMessage() async {
    final lastUserMsg = state.lastWhere(
      (m) => m.isUser,
      orElse: () => state.first,
    );
    if (!lastUserMsg.isUser) return;

    // Remove the error message if exists
    if (state.last.isBum && state.last.isError) {
      state = state.sublist(0, state.length - 1);
    }

    await _processReply(
      lastUserMsg.content,
      isRetry: true,
      sourceUserMessageId: lastUserMsg.id,
    );
  }

  Future<void> _processReply(
    String query, {
    bool isRetry = false,
    String? sourceUserMessageId,
  }) async {
    final classification = IntentClassifier.classify(query);

    // Current pilot only executes direct read-only DB queries for these intents.
    // Other replies are templates/clarifications and must not be reported as model inference.
    final usesReadOnlyDb = const {
      'revenue_summary',
      'sales_comparison',
      'top_products',
      'slow_products',
      'low_stock',
      'staff_on_shift',
    }.contains(classification.intent);
    final selectedRoute = usesReadOnlyDb ? 'rpc' : 'clarification';

    final session = ref.read(sessionProvider);
    final telemetry = BumTelemetryTrace.start(
      storeId: session?.storeId,
      userId: session?.userId,
      intent: classification.intent,
      route: selectedRoute,
    );

    // 1. Loading Phase
    final loadingId = const Uuid().v4();
    final loadingMsg = BumMessage(
      id: loadingId,
      content: '',
      role: MessageRole.bum,
      status: MessageStatus.loading,
    );
    state = [...state, loadingMsg];

    await Future.delayed(const Duration(milliseconds: 600));
    if (!_mounted) return;

    // Lấy thông tin session thực tế
    final storeId = session?.storeId;

    String fullReply =
        'Tớ chưa hiểu rõ lắm. Cậu có thể hỏi về "doanh thu hôm nay" hoặc "món bán chạy" được không?';
    List<String>? suggestions;
    String? completedTool;
    int toolLatencyMs = 0;
    bool queryFailed = false;
    final processingTimer = Stopwatch()..start();

    // 2. Chỉ đọc dữ liệu thật qua cổng chuyên dụng của AI Bum.
    try {
      if (storeId == null || storeId.isEmpty) {
        throw StateError('MISSING_STORE_CONTEXT');
      }
      final readOnlyData = BumReadOnlyDataService(Supabase.instance.client);
      final storeName = session?.storeName?.trim().isNotEmpty == true
          ? session!.storeName!.trim()
          : 'quán';

      if (classification.intent == 'revenue_summary' ||
          classification.intent == 'sales_comparison') {
        final toolTimer = Stopwatch()..start();
        final summary = await readOnlyData.getTodaySummary(storeId);
        if (summary.orderCount > 0) {
          final change = summary.changePercent;
          final comparison = change == null
              ? 'Chưa đủ doanh thu hôm qua để so sánh.'
              : 'So với hôm qua: ${change >= 0 ? 'tăng' : 'giảm'} ${change.abs().toStringAsFixed(1)}%.';
          fullReply =
              'Hôm nay $storeName đạt ${_formatCurrency(summary.revenue)} từ ${summary.orderCount} đơn hoàn thành, trung bình ${_formatCurrency(summary.averageOrderValue)}/đơn. $comparison';
        } else {
          fullReply =
              'Hôm nay $storeName chưa ghi nhận đơn hàng hoàn thành trong dữ liệu thực tế.';
        }
        suggestions = ['Món nào bán chạy nhất?', 'Kho có gì sắp hết?'];
        toolTimer.stop();
        completedTool = 'orders_summary_read_only';
        toolLatencyMs = toolTimer.elapsedMilliseconds;
      } else if (classification.intent == 'top_products') {
        final toolTimer = Stopwatch()..start();
        final performance = await readOnlyData.getProductPerformance(storeId);
        final soldItems = performance.top
            .where((item) => item.quantity > 0)
            .toList();
        if (soldItems.isNotEmpty) {
          final details = soldItems
              .map(
                (item) =>
                    '${item.name} (${_formatQuantity(item.quantity)} món, ${_formatCurrency(item.revenue)})',
              )
              .join('; ');
          fullReply =
              'Món bán chạy hôm nay của $storeName: $details. Số liệu được tổng hợp từ ${performance.completedOrderCount} đơn hoàn thành.';
        } else {
          fullReply =
              'Hôm nay chưa có sản phẩm phát sinh trong đơn hoàn thành nên Bum chưa xếp hạng món bán chạy.';
        }
        suggestions = ['Món nào bán ế?', 'Hôm nay ai đang làm?'];
        toolTimer.stop();
        completedTool = 'top_products_read_only';
        toolLatencyMs = toolTimer.elapsedMilliseconds;
      } else if (classification.intent == 'slow_products') {
        final toolTimer = Stopwatch()..start();
        final performance = await readOnlyData.getProductPerformance(storeId);
        if (performance.slow.isNotEmpty) {
          final details = performance.slow
              .map(
                (item) =>
                    '${item.name} (${_formatQuantity(item.quantity)} món)',
              )
              .join('; ');
          fullReply =
              'Các món bán chậm nhất hôm nay: $details. Gợi ý: ưu tiên kiểm tra vị trí hiển thị hoặc tạo combo, nhưng Bum sẽ không tự thay đổi menu hay giá.';
        } else {
          fullReply = 'Chưa có sản phẩm đang hoạt động để phân tích bán chậm.';
        }
        suggestions = ['Hôm nay ai đang làm?', 'Kho có gì sắp hết?'];
        toolTimer.stop();
        completedTool = 'slow_products_read_only';
        toolLatencyMs = toolTimer.elapsedMilliseconds;
      } else if (classification.intent == 'low_stock') {
        final toolTimer = Stopwatch()..start();
        final alerts = await readOnlyData.getLowStock(storeId);
        if (alerts.isEmpty) {
          fullReply =
              'Dữ liệu kho hiện không có mặt hàng nào chạm hoặc thấp hơn mức tồn tối thiểu.';
        } else {
          final details = alerts
              .take(5)
              .map(
                (item) =>
                    '${item.name}: còn ${_formatQuantity(item.stockQuantity)}, tối thiểu ${_formatQuantity(item.minimumStock)}',
              )
              .join('; ');
          fullReply =
              'Có ${alerts.length} mặt hàng cần chú ý: $details. Gợi ý: kiểm tra thực tế và lập kế hoạch nhập hàng; Bum không tự tạo phiếu nhập.';
        }
        suggestions = ['Hôm nay ai đang làm?', 'Món nào bán chạy nhất?'];
        toolTimer.stop();
        completedTool = 'low_stock_read_only';
        toolLatencyMs = toolTimer.elapsedMilliseconds;
      } else if (classification.intent == 'staff_on_shift') {
        final toolTimer = Stopwatch()..start();
        final shift = await readOnlyData.getStaffOnShift(storeId);
        if (shift.count == 0) {
          fullReply =
              'Hiện chưa có ca đang mở được ghi nhận trong dữ liệu chấm công hôm nay.';
        } else if (shift.names.isEmpty) {
          fullReply = 'Hiện có ${shift.count} nhân sự đang trong ca.';
        } else {
          fullReply =
              'Hiện có ${shift.count} nhân sự đang trong ca: ${shift.names.join(', ')}.';
        }
        suggestions = ['Doanh thu hôm nay?', 'Kho có gì sắp hết?'];
        toolTimer.stop();
        completedTool = 'staff_on_shift_read_only';
        toolLatencyMs = toolTimer.elapsedMilliseconds;
      }
    } catch (_) {
      queryFailed = true;
      // Fallback minh bạch: không tuyên bố đã kiểm tra khi truy vấn dữ liệu thất bại.
      fullReply =
          'Bum chưa kết nối được dữ liệu của quán lúc này. Cậu thử lại sau một chút nhé!';
      suggestions = ['Món nào bán chạy nhất?', 'Kho có gì sắp hết?'];
    }

    processingTimer.stop();
    if (completedTool != null && !queryFailed) {
      telemetry?.emit(
        eventName: 'tool_completed',
        route: 'rpc',
        latencyMs: processingTimer.elapsedMilliseconds,
        toolLatencyMs: toolLatencyMs,
        hasToolSource: true,
        toolName: completedTool,
      );
    }
    if (queryFailed) {
      telemetry?.emit(
        eventName: 'response_failed',
        route: selectedRoute,
        status: 'error',
        errorCode: 'SUPABASE_QUERY_FAILED',
        latencyMs: processingTimer.elapsedMilliseconds,
        toolLatencyMs: toolLatencyMs,
      );
    }
    telemetry?.emit(
      eventName: 'response_completed',
      route: queryFailed ? 'clarification' : selectedRoute,
      latencyMs: processingTimer.elapsedMilliseconds,
      toolLatencyMs: toolLatencyMs,
      hasToolSource: completedTool != null && !queryFailed,
      fallbackUsed: queryFailed,
      toolName: completedTool,
    );

    // 3. Streaming word by word
    final words = fullReply.split(' ');
    String currentText = '';

    for (int i = 0; i < words.length; i++) {
      currentText += (i == 0 ? '' : ' ') + words[i];
      state = [
        ...state.sublist(0, state.length - 1),
        BumMessage(
          id: loadingId,
          content: currentText,
          role: MessageRole.bum,
          status: MessageStatus.streaming,
        ),
      ];
      await Future.delayed(const Duration(milliseconds: 50));
      if (!_mounted) return;
    }

    // 4. Completed Phase
    final Map<String, dynamic>? evidenceRef = completedTool != null
        ? {
            'tool_name': completedTool,
            'latency_ms': toolLatencyMs,
            'status': queryFailed ? 'error' : 'success',
            'route': selectedRoute,
          }
        : null;

    state = [
      ...state.sublist(0, state.length - 1),
      BumMessage(
        id: loadingId,
        content: fullReply,
        role: MessageRole.bum,
        status: MessageStatus.completed,
        suggestions: suggestions,
        evidenceReference: evidenceRef,
        sourceMessageId: sourceUserMessageId,
      ),
    ];
  }

  Future<Map<String, dynamic>> submitFeedbackForMessage(
    String messageId, {
    required String rating,
    String? reasonCode,
    String? proposedAnswer,
    FeedbackService? customService,
  }) async {
    final idx = state.indexWhere((m) => m.id == messageId);
    if (idx == -1) return {'success': false, 'error': 'MESSAGE_NOT_FOUND'};

    final targetMsg = state[idx];

    // QC Item 8: Duplicate tap prevention! Ignore if submitting or already submitted
    if (targetMsg.isFeedbackSubmitting || targetMsg.isFeedbackSubmitted) {
      return {'success': false, 'error': 'ALREADY_SUBMITTING_OR_SUBMITTED'};
    }

    // Step 1: Transition to submitting
    final submittingMsg = targetMsg.copyWith(
      feedbackRating: rating,
      feedbackReason: reasonCode,
      proposedAnswer: proposedAnswer,
      feedbackStatus: 'submitting',
    );
    _updateMessageInState(idx, submittingMsg);

    final session = ref.read(sessionProvider);
    final storeId = session?.storeId;

    // QC Item 4: Fail-closed if storeId is missing/empty!
    if (storeId == null || storeId.trim().isEmpty) {
      final failedMsg = submittingMsg.copyWith(feedbackStatus: 'failed');
      _updateMessageInState(idx, failedMsg);
      return {'success': false, 'error': 'MISSING_STORE_CONTEXT'};
    }

    // Find actual user query content
    final userMsgIndex = state.indexWhere(
      (m) => m.id == targetMsg.sourceMessageId,
    );
    final userQuery = userMsgIndex != -1
        ? state[userMsgIndex].content
        : 'Query';

    final feedbackService = customService ?? FeedbackService();

    try {
      final res = await feedbackService.submitFeedbackCandidate(
        sourceMessageId: targetMsg.id,
        storeId: storeId,
        rating: rating,
        reasonCode: reasonCode,
        question: userQuery,
        answer: targetMsg.content,
        proposedAnswer: proposedAnswer,
        evidenceReference: targetMsg.evidenceReference,
      );

      // QC Item 5: ONLY mark UI state as 'submitted' when backend returns success == true!
      if (res['success'] == true) {
        final submittedMsg = submittingMsg.copyWith(
          feedbackStatus: 'submitted',
        );
        _updateMessageInState(idx, submittedMsg);
        return res;
      } else if (res['error'] == 'PAIRING_REQUIRED' || res['status'] == 401) {
        final pairingMsg = submittingMsg.copyWith(
          feedbackStatus: 'pairing_required',
        );
        _updateMessageInState(idx, pairingMsg);
        return res;
      } else {
        final failedMsg = submittingMsg.copyWith(feedbackStatus: 'failed');
        _updateMessageInState(idx, failedMsg);
        return res;
      }
    } catch (e) {
      final failedMsg = submittingMsg.copyWith(feedbackStatus: 'failed');
      _updateMessageInState(idx, failedMsg);
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }

  void _updateMessageInState(int idx, BumMessage msg) {
    final newList = List<BumMessage>.from(state);
    newList[idx] = msg;
    state = newList;
  }

  String _formatCurrency(num amount) {
    return '${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')}đ';
  }

  String _formatQuantity(num quantity) => quantity % 1 == 0
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(1);

  void clearChat() {
    state = [
      BumMessage(
        content:
            'Chào cậu! Tớ là Bum. Tớ có thể giúp cậu xem báo cáo doanh thu, món bán chạy, hay tìm thông tin của quán. Cậu muốn hỏi gì nào?',
        role: MessageRole.bum,
      ),
    ];
  }
}
