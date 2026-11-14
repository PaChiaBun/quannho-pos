import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Fire-and-forget telemetry for AI Boom.
///
/// Privacy contract: this service never accepts or sends prompts, responses,
/// phone numbers, names, credentials, or free-form error messages.
class BoomTelemetryTrace {
  // TẮT mặc định (24/10/2026): máy chủ đo cũ (BunServer) chỉ vào được qua mạng nội bộ Tailscale → máy khách gửi
  // lần nào hỏng lần đó. Chỉ gửi khi build có chỉ định rõ địa chỉ:
  //   --dart-define=AI_BOOM_TELEMETRY_URL=https://…/ai-bum-gateway (vẫn nhận tên cũ AI_BUM_TELEMETRY_URL).
  static const _gatewayBaseUrl = String.fromEnvironment(
    'AI_BOOM_TELEMETRY_URL',
    defaultValue: String.fromEnvironment('AI_BUM_TELEMETRY_URL'),
  );

  /// Có gửi số đo không (build có chỉ định địa chỉ).
  static bool get enabled => _gatewayBaseUrl.isNotEmpty;

  final String requestId;
  final String storeId;
  final String userId;
  final String intent;
  final Stopwatch _stopwatch = Stopwatch()..start();
  Future<void> _pending = Future<void>.value();
  int _sequence = 0;

  BoomTelemetryTrace._({
    required this.requestId,
    required this.storeId,
    required this.userId,
    required this.intent,
  });

  static BoomTelemetryTrace? start({
    required String? storeId,
    required String? userId,
    required String intent,
    required String route,
  }) {
    if (!enabled ||
        storeId == null ||
        storeId.isEmpty ||
        userId == null ||
        userId.isEmpty) {
      return null;
    }

    final trace = BoomTelemetryTrace._(
      requestId: const Uuid().v4(),
      storeId: storeId,
      userId: userId,
      intent: intent,
    );
    trace.emit(eventName: 'request_started', route: route);
    trace.emit(eventName: 'route_selected', route: route);
    return trace;
  }

  void emit({
    required String eventName,
    required String route,
    String status = 'success',
    String? errorCode,
    int? latencyMs,
    int toolLatencyMs = 0,
    int modelLatencyMs = 0,
    int inputTokens = 0,
    int outputTokens = 0,
    int costMicrousd = 0,
    bool hasToolSource = false,
    bool hasRagSource = false,
    bool fallbackUsed = false,
    String? toolName,
  }) {
    final sequence = ++_sequence;
    final payload = <String, dynamic>{
      'request_id': requestId,
      'event_sequence': sequence,
      'store_id': storeId,
      'user_id': userId,
      'event_name': eventName,
      'intent': intent,
      'route': route,
      'status': status,
      'error_code': errorCode,
      'latency_ms': latencyMs ?? _stopwatch.elapsedMilliseconds,
      'tool_latency_ms': toolLatencyMs,
      'model_latency_ms': modelLatencyMs,
      'input_tokens': inputTokens,
      'output_tokens': outputTokens,
      'cost_microusd': costMicrousd,
      'has_tool_source': hasToolSource,
      'has_rag_source': hasRagSource,
      'fallback_used': fallbackUsed,
      'metadata': <String, dynamic>{
        'client_version': 'quannho-pos',
        'tool_name': ?toolName,
      },
    };

    _pending = _pending.then((_) => _post(payload));
  }

  Future<void> _post(Map<String, dynamic> payload) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_gatewayBaseUrl/v1/boom/events'),
            headers: {
              'Content-Type': 'application/json',
              'x-store-id': storeId,
              'x-user-id': userId,
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));
      if (response.statusCode != 202 && kDebugMode) {
        debugPrint('[BoomTelemetry] Event rejected (${response.statusCode}).');
      }
    } catch (_) {
      // Telemetry must never block or break the AI response path.
      if (kDebugMode) {
        debugPrint('[BoomTelemetry] Gateway temporarily unavailable.');
      }
    }
  }
}
