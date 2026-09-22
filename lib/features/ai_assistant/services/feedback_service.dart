import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import 'pii_redactor.dart';

class FeedbackService {
  final String backendUrl;
  final http.Client httpClient;
  final FlutterSecureStorage secureStorage;

  static const _keySessionToken = 'bum_feedback_session_token';
  static const _keyEd25519PrivateKey = 'bum_feedback_ed25519_private_key';
  static const _keyEd25519PublicKey = 'bum_feedback_ed25519_public_key';

  FeedbackService({
    this.backendUrl = 'https://bunserver.tailcaeae7.ts.net',
    http.Client? httpClient,
    FlutterSecureStorage? secureStorage,
  }) : httpClient = httpClient ?? http.Client(),
       secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Retrieve or generate real random Ed25519 keypair for device binding
  Future<Map<String, String>> getOrGenerateEd25519Keypair() async {
    var privB64 = await secureStorage.read(key: _keyEd25519PrivateKey);
    var pubB64 = await secureStorage.read(key: _keyEd25519PublicKey);

    if (privB64 == null || pubB64 == null) {
      final keyPair = ed25519.generateKey();

      privB64 = base64Encode(keyPair.privateKey.bytes);
      pubB64 = base64Encode(keyPair.publicKey.bytes);

      await secureStorage.write(key: _keyEd25519PrivateKey, value: privB64);
      await secureStorage.write(key: _keyEd25519PublicKey, value: pubB64);
    }

    return {'private_key': privB64, 'public_key': pubB64};
  }

  /// Clear stored pairing session token
  Future<void> clearSessionToken() async {
    try {
      await secureStorage.delete(key: _keySessionToken);
    } catch (_) {
      // AI Bum chạy nền và độc lập với phiên POS. Lỗi plugin storage trên web
      // không được phép làm gián đoạn đăng nhập/đăng xuất của thu ngân.
    }
  }

  /// Store opaque session token received from backend pairing exchange
  Future<void> storeSessionToken(String token) async {
    await secureStorage.write(key: _keySessionToken, value: token);
  }

  /// Get stored session token from FlutterSecureStorage
  Future<String?> getStoredSessionToken() async {
    return await secureStorage.read(key: _keySessionToken);
  }

  /// Compute real Ed25519 signature over canonical string
  /// Canonical string:
  /// METHOD
  /// SIGNATURE_PATH (e.g. /internal/v1/feedback/submit)
  /// TIMESTAMP_ISO
  /// NONCE
  /// SHA256_HEX_BODY
  String computeSignature({
    required String method,
    required String signaturePath,
    required String timestampIso,
    required String nonce,
    required String bodyJson,
    required String privateKeyB64,
  }) {
    final bodyHashHex = sha256.convert(utf8.encode(bodyJson)).toString();
    final canonicalString =
        '${method.toUpperCase()}\n$signaturePath\n$timestampIso\n$nonce\n$bodyHashHex';

    final privBytes = base64Decode(privateKeyB64);
    final privateKey = ed25519.PrivateKey(privBytes);
    final canonicalBytes = utf8.encode(canonicalString);

    final signatureBytes = ed25519.sign(privateKey, canonicalBytes);
    return base64Encode(signatureBytes);
  }

  /// Perform password credential auth bootstrap for feedback session (HTTPS bootstrap during login)
  Future<Map<String, dynamic>> exchangeSessionWithPassword({
    required String phone,
    required String password,
    required String storeId,
    String transportPath = '/api/feedback/session/exchange',
  }) async {
    if (storeId.trim().isEmpty) {
      return {
        'success': false,
        'status': 400,
        'error': 'STORE_CONTEXT_REQUIRED',
        'message': 'Store context is required',
      };
    }

    if (phone.trim().isEmpty || password.trim().isEmpty) {
      return {
        'success': false,
        'status': 401,
        'error': 'UNAUTHORIZED',
        'message': 'Phone and password credentials are required',
      };
    }

    try {
      final keys = await getOrGenerateEd25519Keypair();
      final payload = {
        'device_public_key': keys['public_key'],
        'phone': phone.trim(),
        'password': password.trim(),
        'store_id': storeId.trim(),
      };

      final response = await httpClient.post(
        Uri.parse('$backendUrl$transportPath'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          'success': false,
          'status': 400,
          'error': 'INVALID_CONTENT_TYPE',
          'message': 'Server response is not JSON',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true &&
          data['session_token'] != null) {
        final token = data['session_token'] as String;
        await storeSessionToken(token);
        return data;
      } else {
        return {
          'success': false,
          'status': response.statusCode,
          'error': data['error'] ?? 'SESSION_EXCHANGE_FAILED',
          'message': data['message'] ?? 'Backend rejected session exchange',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }

  /// Perform real device pairing exchange with backend
  Future<Map<String, dynamic>> exchangePairingCode({
    required String rawCode,
    String transportPath = '/api/feedback/pairing/exchange',
  }) async {
    if (rawCode.trim().isEmpty) {
      return {
        'success': false,
        'status': 400,
        'error': 'INVALID_PAIRING_PAYLOAD',
        'message': 'Pairing code is required',
      };
    }

    final keys = await getOrGenerateEd25519Keypair();

    final payload = {
      'raw_code': rawCode.trim(),
      'device_public_key': keys['public_key'],
    };

    final bodyJson = jsonEncode(payload);

    try {
      final response = await httpClient.post(
        Uri.parse('$backendUrl$transportPath'),
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      );

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          'success': false,
          'status': 400,
          'error': 'INVALID_CONTENT_TYPE',
          'message': 'Server response is not JSON',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200 &&
          data['success'] == true &&
          data['session_token'] != null) {
        final token = data['session_token'] as String;
        await storeSessionToken(token);
        return data;
      } else {
        return {
          'success': false,
          'status': response.statusCode,
          'error': data['error'] ?? 'PAIRING_EXCHANGE_FAILED',
          'message': data['message'] ?? 'Backend rejected pairing code',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }

  /// Submit feedback candidate with separate transportPath and signaturePath
  Future<Map<String, dynamic>> submitFeedbackCandidate({
    required String sourceMessageId,
    required String storeId,
    required String rating, // 'thumbs_up', 'thumbs_down'
    String? reasonCode,
    String? question,
    String? answer,
    String? proposedAnswer,
    Map<String, dynamic>? evidenceReference,
    String transportPath = '/api/feedback/submit',
    String signaturePath = '/internal/v1/feedback/submit',
  }) async {
    // Check session token in secure storage - STRICT FAIL-CLOSED
    final sessionToken = await getStoredSessionToken();
    if (sessionToken == null || sessionToken.trim().isEmpty) {
      return {
        'success': false,
        'status': 401,
        'error': 'UNAUTHORIZED',
        'message':
            'Chưa đăng nhập hoặc phiên làm việc hết hạn. Vui lòng đăng nhập lại.',
      };
    }

    if (storeId.trim().isEmpty || sourceMessageId.trim().isEmpty) {
      return {
        'success': false,
        'error': 'MISSING_SESSION_OR_STORE_CONTEXT',
        'message':
            'Cannot submit feedback without valid store context and message ID',
      };
    }

    final result = await _executeSignedSubmission(
      sessionToken: sessionToken,
      sourceMessageId: sourceMessageId,
      storeId: storeId,
      rating: rating,
      reasonCode: reasonCode,
      question: question,
      answer: answer,
      proposedAnswer: proposedAnswer,
      evidenceReference: evidenceReference,
      transportPath: transportPath,
      signaturePath: signaturePath,
    );

    // If session token expired or revoked, clear stored token and require re-login (NO RETRY LOOP)
    if (result['status'] == 401) {
      await clearSessionToken();
      return {
        'success': false,
        'status': 401,
        'error': 'UNAUTHORIZED',
        'message': 'Phiên làm việc hết hạn. Vui lòng đăng nhập lại.',
      };
    }

    return result;
  }

  Future<Map<String, dynamic>> _executeSignedSubmission({
    required String sessionToken,
    required String sourceMessageId,
    required String storeId,
    required String rating,
    String? reasonCode,
    String? question,
    String? answer,
    String? proposedAnswer,
    Map<String, dynamic>? evidenceReference,
    required String transportPath,
    required String signaturePath,
  }) async {
    if (storeId.trim().isEmpty || sourceMessageId.trim().isEmpty) {
      return {
        'success': false,
        'error': 'MISSING_SESSION_OR_STORE_CONTEXT',
        'message':
            'Cannot submit feedback without valid store context and message ID',
      };
    }

    // Client-side PII Redaction BEFORE departure
    final redactedQuestion = PiiRedactor.redact(question);
    final redactedAnswer = PiiRedactor.redact(answer);
    final redactedProposed = proposedAnswer != null
        ? PiiRedactor.redact(proposedAnswer)
        : null;

    Map<String, dynamic>? sanitizedEvidence;
    try {
      sanitizedEvidence = PiiRedactor.sanitizeEvidenceReference(
        evidenceReference,
      );
    } catch (e) {
      return {
        'success': false,
        'error': 'INVALID_EVIDENCE_REFERENCE',
        'message': e.toString(),
      };
    }

    final keys = await getOrGenerateEd25519Keypair();
    final timestampIso = DateTime.now().toUtc().toIso8601String();
    final nonce = const Uuid().v4();

    final payload = {
      'source_message_id': sourceMessageId,
      'store_id': storeId,
      'rating': rating,
      'reason_code': reasonCode,
      'question': redactedQuestion,
      'answer': redactedAnswer,
      'proposed_answer': redactedProposed,
      'evidence_reference': sanitizedEvidence,
    };

    final bodyJson = jsonEncode(payload);

    // Compute signature using internal service signaturePath (/internal/v1/feedback/submit)
    final signatureB64 = computeSignature(
      method: 'POST',
      signaturePath: signaturePath,
      timestampIso: timestampIso,
      nonce: nonce,
      bodyJson: bodyJson,
      privateKeyB64: keys['private_key']!,
    );

    try {
      // Send HTTP POST to public transportPath (/api/feedback/submit)
      final response = await httpClient.post(
        Uri.parse('$backendUrl$transportPath'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $sessionToken',
          'X-Bum-Timestamp': timestampIso,
          'X-Bum-Nonce': nonce,
          'X-Bum-Signature': signatureB64,
        },
        body: bodyJson,
      );

      final contentType = response.headers['content-type'] ?? '';
      if (!contentType.contains('application/json')) {
        return {
          'success': false,
          'error': 'INVALID_CONTENT_TYPE',
          'message': 'Server response is not JSON',
        };
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data['success'] == true) {
        return data;
      } else if (response.statusCode == 401) {
        await clearSessionToken();
        return {
          'success': false,
          'error': 'PAIRING_REQUIRED',
          'status': 401,
          'message': 'Phiên kết nối hết hạn, vui lòng kết nối lại thiết bị.',
        };
      } else if (response.statusCode == 403) {
        return {
          'success': false,
          'error': 'FORBIDDEN',
          'status': 403,
          'message':
              data['message'] ?? 'Bạn không có quyền thực hiện thao tác này.',
        };
      } else if (response.statusCode == 409) {
        return {
          'success': false,
          'error': 'CONFLICT',
          'status': 409,
          'message':
              data['message'] ??
              'Phản hồi cho câu trả lời này đã được gửi trước đó.',
        };
      } else if (response.statusCode == 429) {
        return {
          'success': false,
          'error': 'RATE_LIMITED',
          'status': 429,
          'message':
              data['message'] ??
              'Thao tác quá nhanh, vui lòng thử lại sau giây lát.',
        };
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'SUBMISSION_FAILED',
          'message': data['message'] ?? 'Backend rejected submission',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'NETWORK_ERROR',
        'message': e.toString(),
      };
    }
  }
}
