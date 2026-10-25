// lib/core/services/jwt_gate_http_client.dart
// ─────────────────────────────────────────────────────────────────────────────
// Chốt chặn JWT (kế hoạch JWT Pha 2) — mọi yêu cầu Supabase đi qua đây.
// Mở app lúc mất mạng: access token hết hạn, refresh token chưa gửi được
// (PosJwtAuthService.waitingForRefresh). Lúc đó gửi bằng anon key sẽ nhận dữ liệu
// RỖNG mà tưởng thật (không còn header x-user-id). Nên:
//   • giữ yêu cầu lại tới khi có JWT, rồi gửi kèm JWT mới;
//   • chờ quá [maxWait] → báo lỗi mạng (ClientException), KHÔNG gửi bằng anon.
// Khi không chờ JWT: đi thẳng, không thêm độ trễ.
// API từ chối vé phiên (401 PGRST301/PGRST303 — vd máy chủ đổi khoá ký, vé sống 30 ngày):
// xin vé mới bằng refresh token rồi gửi lại 1 lần, để không ai phải đăng nhập lại.
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'pos_jwt_auth_service.dart';

class JwtGateHttpClient extends http.BaseClient {
  JwtGateHttpClient({
    required this.anonKey,
    http.Client? inner,
    this.maxWait = const Duration(seconds: 15),
    Future<String?> Function(String rejectedToken)? recover,
  }) : _inner = inner ?? http.Client(),
       _recover = recover ??
           ((t) => PosJwtAuthService().recoverRejectedJwt(t));

  final String anonKey;
  final Duration maxWait;
  final http.Client _inner;
  final Future<String?> Function(String rejectedToken) _recover;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (PosJwtAuthService.waitingForRefresh) {
      final ready = await PosJwtAuthService.waitForJwt(maxWait);
      if (!ready) {
        throw http.ClientException(
          'Đang chờ khôi phục phiên đăng nhập (mất mạng)',
          request.url,
        );
      }
      // Yêu cầu được tạo lúc còn anon: thay bằng JWT vừa có (header không phân biệt hoa thường).
      final token = PosJwtAuthService.currentAccessToken;
      if (token != null &&
          request.headers['Authorization'] == 'Bearer $anonKey') {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    // Chỉ gửi lại được yêu cầu thường (body là bytes) đang mang vé phiên.
    final session = PosJwtAuthService.currentAccessToken;
    final retry = session != null &&
            request is http.Request &&
            request.headers['Authorization'] == 'Bearer $session'
        ? _copy(request)
        : null;

    final res = await _inner.send(request);
    if (retry == null || res.statusCode != 401) return res;

    final bytes = await res.stream.toBytes();
    if (!_isJwtRejected(bytes)) return _rebuild(res, bytes);
    final fresh = await _recover(session!);
    if (fresh == null || fresh == session) return _rebuild(res, bytes);
    retry.headers['Authorization'] = 'Bearer $fresh';
    return _inner.send(retry);
  }

  static bool _isJwtRejected(List<int> body) {
    try {
      final code = (jsonDecode(utf8.decode(body)) as Map)['code'];
      return code == 'PGRST301' || code == 'PGRST303';
    } catch (_) {
      return false;
    }
  }

  static http.Request _copy(http.Request r) => http.Request(r.method, r.url)
    ..headers.addAll(r.headers)
    ..bodyBytes = r.bodyBytes
    ..followRedirects = r.followRedirects
    ..maxRedirects = r.maxRedirects
    ..persistentConnection = r.persistentConnection;

  static http.StreamedResponse _rebuild(
    http.StreamedResponse res,
    List<int> bytes,
  ) => http.StreamedResponse(
    Stream.value(bytes),
    res.statusCode,
    contentLength: bytes.length,
    request: res.request,
    headers: res.headers,
    isRedirect: res.isRedirect,
    persistentConnection: res.persistentConnection,
    reasonPhrase: res.reasonPhrase,
  );

  @override
  void close() => _inner.close();
}
