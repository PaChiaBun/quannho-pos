import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'turnstile_stub.dart' if (dart.library.js_interop) 'turnstile_web.dart' as ts;

/// Kết quả xin vé xác minh người thật cho một đơn QR.
class QrTicketResult {
  final String? ticket;
  final String? message;
  const QrTicketResult.ok(this.ticket) : message = null;
  const QrTicketResult.fail(this.message) : ticket = null;
  bool get isOk => ticket != null;
}

/// Lớp 3 chống phá: chạy Turnstile rồi xin vé HMAC từ cổng /api/auth/qr-ticket.
/// Mỗi vé chỉ dùng cho đúng một khoá chống trùng (một đơn), sống 5 phút.
class QrTicketService {
  static const _kProdOrigin = 'https://quannho.lpm.vn';

  static String _origin() {
    if (kIsWeb) {
      final o = Uri.base.origin;
      if (o.startsWith('http')) return o;
    }
    return _kProdOrigin;
  }

  static Future<QrTicketResult> fetch({
    required String channelCode,
    required String idempotencyKey,
    required String siteKey,
  }) async {
    final token = await ts.solveTurnstile(siteKey);
    if (token == null || token.isEmpty) {
      return const QrTicketResult.fail(
        'Không xác minh được bạn là người thật. Vui lòng tải lại trang rồi thử lại.',
      );
    }
    try {
      final res = await http
          .post(
            Uri.parse('${_origin()}/api/auth/qr-ticket'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'channel_code': channelCode,
              'idempotency_key': idempotencyKey,
              'turnstile_token': token,
            }),
          )
          .timeout(const Duration(seconds: 12));
      final body = jsonDecode(res.body);
      if (body is Map && body['success'] == true && body['ticket'] is String) {
        return QrTicketResult.ok(body['ticket'] as String);
      }
      if (res.statusCode == 429) {
        return const QrTicketResult.fail('Bạn thao tác quá nhanh, vui lòng đợi một lát.');
      }
      return const QrTicketResult.fail('Xác minh không thành công. Vui lòng thử lại.');
    } catch (_) {
      return const QrTicketResult.fail('Không kết nối được để xác minh. Vui lòng kiểm tra mạng.');
    }
  }
}
