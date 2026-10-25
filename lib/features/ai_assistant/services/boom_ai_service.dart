// lib/features/ai_assistant/services/boom_ai_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Gọi hàm máy chủ boom-chat (GPT-4o mini) — ke-hoach-trien-khai-boom.md Bước 4.2.
// App KHÔNG giữ khoá OpenAI: chỉ gửi vé đăng nhập (JWT) + câu hỏi + MÃ tối đa 3 đoạn hướng dẫn
// (nội dung đoạn máy chủ lấy từ bản đã đăng). Chờ tối đa 20 giây (máy chủ bỏ OpenAI sau 12 giây).
// Mọi lỗi (chưa bật, hết hạn mức, mạng, máy chủ chưa có hàm) → trả null để Boom dùng câu trả lời nguyên văn.
// Luật của Boom (máy chủ): câu ngoài phạm vi (chính trị, tôn giáo, lập trình, số liệu quán khác…) → máy chủ
// trả câu từ chối với `blocked` (không gọi GPT, kể cả khi Boom AI đang tắt).
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/repositories/module_repository.dart'
    show jwtIsAuthenticated;
import '../help/huong_dan_parser.dart';

class BoomAiReply {
  final String answer;
  final String? logId;

  /// Máy chủ từ chối vì câu ngoài phạm vi — [answer] là câu từ chối, không phải câu trả lời của GPT.
  final bool blocked;

  /// Câu trả lời lấy từ bộ nhớ câu đã duyệt (không gọi GPT).
  final bool cached;
  const BoomAiReply(
    this.answer,
    this.logId, {
    this.blocked = false,
    this.cached = false,
  });
}

/// Lượt hỏi–đáp trước, gửi kèm câu nói tiếp (máy chủ cắt câu trả lời còn 800 ký tự).
class BoomTurn {
  final String question;
  final String answer;
  const BoomTurn(this.question, this.answer);

  Map<String, String> toJson() => {
    'q': question.length > 500 ? question.substring(0, 500) : question,
    'a': answer.length > 800 ? answer.substring(0, 800) : answer,
  };
}

class BoomAiService {
  final SupabaseClient client;
  final Duration timeout;
  BoomAiService(this.client, {this.timeout = const Duration(seconds: 20)});

  static const kFunction = 'boom-chat';

  /// Vé đăng nhập hiện tại; null nếu máy chưa đăng nhập JWT (máy chủ chỉ nhận vé thật).
  String? get _authHeader {
    final h = client.rest.headers['Authorization'];
    return jwtIsAuthenticated(h) ? h : null;
  }

  /// Máy đang đăng nhập bằng vé thật (gửi được tới hàm boom-chat).
  bool get canSend => _authHeader != null;

  Future<Map<String, dynamic>?> _invoke(Map<String, dynamic> body) async {
    final auth = _authHeader;
    if (auth == null) return null;
    try {
      final res = await client.functions
          .invoke(kFunction, body: body, headers: {'Authorization': auth})
          .timeout(timeout);
      final data = res.data;
      return data is Map<String, dynamic> ? data : null;
    } catch (e) {
      // FunctionException (503 chưa bật, 429 hết lượt…), mạng, quá giờ — không làm vỡ Boom.
      if (kDebugMode) debugPrint('[BoomAi] $e');
      return null;
    }
  }

  /// GPT trả lời dựa trên [chunks] (tối đa 3). null = dùng câu trả lời nguyên văn.
  Future<BoomAiReply?> ask({
    required String storeId,
    required String question,
    required List<HelpChunk> chunks,
    int packVersion = 0,
    BoomTurn? history,
  }) async {
    if (chunks.isEmpty) return null;
    final data = await _invoke({
      'history': ?history?.toJson(),
      'store_id': storeId,
      'question': question.length > 500 ? question.substring(0, 500) : question,
      'mode': 'answer',
      // Chỉ gửi MÃ đoạn — máy chủ tự lấy nội dung từ bản hướng dẫn đã đăng.
      'chunk_ids': [for (final c in chunks.take(3)) c.id],
      // Máy chủ lấy đúng bản hướng dẫn app đang dùng (không lệch nội dung giữa app và máy chủ).
      if (packVersion > 0) 'pack_version': packVersion,
    });
    return _reply(data);
  }

  /// Tư vấn kinh doanh (bán hàng, thu hút khách, đọc báo cáo…) khi không có hướng dẫn liên quan.
  /// null = chưa bật / hết hạn mức / lỗi → Boom nói chưa trả lời được.
  /// [facts]: số liệu thật của chính quán (câu xin tư vấn về món / doanh thu) — GPT phân tích trên số này.
  /// [history]: lượt hỏi–đáp ngay trước (câu nói tiếp "đề xuất cho tôi đi").
  Future<BoomAiReply?> advise({
    required String storeId,
    required String question,
    Map<String, dynamic>? facts,
    Map<String, dynamic>? chain,
    Map<String, dynamic>? modules,
    BoomTurn? history,
    DateTime? memorySince,
  }) async {
    final data = await _invoke({
      // Máy chủ nhớ tối đa 4 lượt trong 5 giờ (sổ hỏi đáp) — chỉ từ lúc bấm "làm mới". Gửi SỐ GIÂY đã trôi qua
      // (cùng đồng hồ máy) để máy chủ tự tính mốc theo giờ của nó: đồng hồ máy lệch vẫn đúng (QC 24/10).
      if (memorySince != null)
        'memory_age_s': DateTime.now()
            .difference(memorySince)
            .inSeconds
            .clamp(0, 86400),
      'facts': ?facts,
      'chain': ?chain,
      'modules': ?modules,
      'history': ?history?.toJson(),
      'store_id': storeId,
      'question': question.length > 500 ? question.substring(0, 500) : question,
      'mode': 'advice',
      'chunk_ids': const <String>[],
    });
    return _reply(data);
  }

  static BoomAiReply? _reply(Map<String, dynamic>? data) {
    final answer = (data?['answer'] as String?)?.trim();
    if (answer == null || answer.isEmpty) return null;
    return BoomAiReply(
      answer,
      data?['log_id'] as String?,
      blocked: data?['blocked'] != null,
      cached: data?['cached'] == true,
    );
  }

  /// Câu app tự trả lời (không qua GPT) → máy chủ ghi lịch sử nguyên văn cho trang quản trị. Không chờ, lỗi bỏ qua.
  void transcript({
    required String storeId,
    required String question,
    required String answer,
    String? tool,
  }) {
    final t = tool?.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_:#.-]'), '');
    unawaited(
      _invoke({
        'store_id': storeId,
        'question': question.length > 500
            ? question.substring(0, 500)
            : question,
        'mode': 'transcript',
        'answer': answer.length > 8000 ? answer.substring(0, 8000) : answer,
        if (t != null && t.isNotEmpty)
          'tool': t.length > 80 ? t.substring(0, 80) : t,
        'chunk_ids': const <String>[],
      }),
    );
  }

  /// Câu Boom không tìm thấy hướng dẫn → ghi sổ (hàng chờ cải thiện). Không gọi GPT, không chờ.
  void logUnanswered({required String storeId, required String question}) {
    unawaited(
      _invoke({
        'store_id': storeId,
        'question': question.length > 500
            ? question.substring(0, 500)
            : question,
        'mode': 'log_only',
        'chunk_ids': const <String>[],
      }),
    );
  }

  /// 👍/👎 cho câu trả lời KHÔNG gọi GPT (số liệu, hướng dẫn nguyên văn, từ chối…): hàm máy chủ ghi một dòng
  /// 'feedback' vào sổ hỏi đáp. true = đã ghi.
  Future<bool> feedback({
    required String storeId,
    required String question,
    required String answer,
    required bool up,
    String? reason,
    String? tool,
  }) async {
    String clip(String s, int n) => s.length > n ? s.substring(0, n) : s;
    final data = await _invoke({
      'store_id': storeId,
      'question': clip(question.trim().isEmpty ? '(trống)' : question, 500),
      'mode': 'feedback',
      'rating': up ? 'up' : 'down',
      'answer': clip(answer, 2000),
      'reason': ?reason,
      if (tool != null && tool.isNotEmpty) 'tool': clip(tool, 60),
      'chunk_ids': const <String>[],
    });
    return data?['logged'] == true;
  }

  /// Cách gọi người dùng đã chọn ('anh' / 'chi'); ok=false khi chưa đọc được (chưa đăng nhập thật, mất mạng).
  Future<({bool ok, String? xungHo})> getXungHo() async {
    if (!canSend) return (ok: false, xungHo: null);
    try {
      final r = await client.rpc('boom_xung_ho_get_v1').timeout(timeout);
      if (r is! Map) return (ok: false, xungHo: null);
      final x = r['xung_ho'];
      return (ok: true, xungHo: x == 'anh' || x == 'chi' ? x as String : null);
    } catch (_) {
      return (ok: false, xungHo: null);
    }
  }

  /// Lưu cách gọi ('anh' / 'chi') cho chính tài khoản đang đăng nhập.
  Future<bool> setXungHo(String xungHo) async {
    try {
      final r = await client
          .rpc('boom_xung_ho_set_v1', params: {'p_xung_ho': xungHo})
          .timeout(timeout);
      return r == true;
    } catch (_) {
      return false;
    }
  }

  /// 👍/👎 vào sổ hỏi đáp (chỉ người hỏi chấm được câu của mình).
  Future<bool> rate(String logId, {required bool up, String? reason}) async {
    try {
      final r = await client
          .rpc(
            'boom_rate_answer_v1',
            params: {
              'p_id': logId,
              'p_rating': up ? 'up' : 'down',
              'p_reason': reason,
            },
          )
          .timeout(timeout);
      return r == true;
    } catch (_) {
      return false;
    }
  }
}
