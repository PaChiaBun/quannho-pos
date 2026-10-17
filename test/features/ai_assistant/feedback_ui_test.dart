import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:quannho_pos/features/ai_assistant/models/bum_message.dart';
import 'package:quannho_pos/features/ai_assistant/services/feedback_service.dart';
import 'package:quannho_pos/features/ai_assistant/services/pii_redactor.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/bum_message_bubble.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/feedback_dialog.dart';

class MockHttpClient extends Mock implements http.Client {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Uri.parse('https://bunserver.tailcaeae7.ts.net/api/feedback/submit'),
    );
    registerFallbackValue(
      Uri.parse(
        'https://bunserver.tailcaeae7.ts.net/api/feedback/pairing/exchange',
      ),
    );
  });

  group('Phase C1 Integration Contract Tests', () {
    test('test_01_split_transport_path_and_signature_path', () async {
      final storageMap = <String, String>{
        'bum_feedback_session_token': 'valid_session_999',
      };
      final mockClient = MockHttpClient();
      final mockStorage = MockFlutterSecureStorage();

      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((inv) async => storageMap[inv.namedArguments[#key]]);
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        storageMap[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String;
      });

      String? capturedTimestamp;
      String? capturedNonce;
      String? capturedSignature;
      String? capturedBody;

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        final uri = invocation.positionalArguments[0] as Uri;
        final headers =
            invocation.namedArguments[#headers] as Map<String, String>;
        capturedBody = invocation.namedArguments[#body] as String;

        // Transport Path Check (HTTP request URI goes to /api/feedback/submit)
        expect(uri.path, '/api/feedback/submit');
        capturedTimestamp = headers['X-Bum-Timestamp'];
        capturedNonce = headers['X-Bum-Nonce'];
        capturedSignature = headers['X-Bum-Signature'];

        return http.Response(
          jsonEncode({'success': true, 'candidate_id': 'cand-123'}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = FeedbackService(
        backendUrl: 'https://bunserver.tailcaeae7.ts.net',
        httpClient: mockClient,
        secureStorage: mockStorage,
      );

      final res = await service.submitFeedbackCandidate(
        sourceMessageId: 'msg-001',
        storeId: 'store-001',
        rating: 'thumbs_down',
        question: 'Doanh thu?',
        answer: '100.000đ',
        transportPath: '/api/feedback/submit',
        signaturePath: '/internal/v1/feedback/submit',
      );

      expect(res['success'], true);

      // Verify canonical signature using ed25519
      final keys = await service.getOrGenerateEd25519Keypair();
      final pubBytes = base64Decode(keys['public_key']!);
      final publicKey = ed25519.PublicKey(pubBytes);
      final sigBytes = base64Decode(capturedSignature!);

      final bodyHashHex = sha256.convert(utf8.encode(capturedBody!)).toString();

      // 1. Construct validCanonical with signaturePath (/internal/v1/feedback/submit)
      final validCanonical =
          'POST\n/internal/v1/feedback/submit\n$capturedTimestamp\n$capturedNonce\n$bodyHashHex';
      final isValidVerified = ed25519.verify(
        publicKey,
        utf8.encode(validCanonical),
        sigBytes,
      );
      expect(
        isValidVerified,
        isTrue,
        reason:
            'Ed25519 signature must verify against signaturePath /internal/v1/feedback/submit',
      );

      // 2. Construct invalidCanonical with transportPath (/api/feedback/submit)
      final invalidCanonical =
          'POST\n/api/feedback/submit\n$capturedTimestamp\n$capturedNonce\n$bodyHashHex';
      final isInvalidVerified = ed25519.verify(
        publicKey,
        utf8.encode(invalidCanonical),
        sigBytes,
      );
      expect(
        isInvalidVerified,
        isFalse,
        reason:
            'Ed25519 signature must fail verification against transportPath /api/feedback/submit',
      );
    });

    test(
      'test_02_pairing_exchange_excludes_supabase_url_and_anon_key',
      () async {
        final storageMap = <String, String>{};
        final mockClient = MockHttpClient();
        final mockStorage = MockFlutterSecureStorage();

        when(
          () => mockStorage.read(key: any(named: 'key')),
        ).thenAnswer((inv) async => storageMap[inv.namedArguments[#key]]);
        when(
          () => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((inv) async {
          storageMap[inv.namedArguments[#key] as String] =
              inv.namedArguments[#value] as String;
        });

        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((invocation) async {
          final body = invocation.namedArguments[#body] as String;
          final jsonBody = jsonDecode(body) as Map<String, dynamic>;

          // Client payload MUST ONLY contain raw_code, device_public_key
          expect(jsonBody.containsKey('raw_code'), isTrue);
          expect(jsonBody.containsKey('device_public_key'), isTrue);

          // Client payload MUST NOT contain supabase_url or anon_key
          expect(jsonBody.containsKey('supabase_url'), isFalse);
          expect(jsonBody.containsKey('anon_key'), isFalse);

          return http.Response(
            jsonEncode({
              'success': true,
              'session_token': 'real_server_token_555',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        });

        final service = FeedbackService(
          backendUrl: 'https://bunserver.tailcaeae7.ts.net',
          httpClient: mockClient,
          secureStorage: mockStorage,
        );

        final res = await service.exchangePairingCode(rawCode: '999888');

        expect(res['success'], true);
        expect(res['session_token'], 'real_server_token_555');
      },
    );

    test(
      'test_03_missing_token_returns_pairing_required_and_zero_http_calls',
      () async {
        final mockClient = MockHttpClient();
        final mockStorage = MockFlutterSecureStorage();

        when(
          () => mockStorage.read(key: 'bum_feedback_session_token'),
        ).thenAnswer((_) async => null);

        final service = FeedbackService(
          backendUrl: 'https://bunserver.tailcaeae7.ts.net',
          httpClient: mockClient,
          secureStorage: mockStorage,
        );

        final res = await service.submitFeedbackCandidate(
          sourceMessageId: 'msg-101',
          storeId: 'store-202',
          rating: 'thumbs_up',
        );

        expect(res['success'], false);
        expect(res['error'], 'UNAUTHORIZED');
        verifyZeroInteractions(mockClient);
      },
    );

    test('test_04_pii_redactor_preserves_business_numbers_and_redacts_otp', () {
      const textBusiness = 'Doanh thu 125000 đồng từ 15 đơn hàng';
      const textOtp = 'Mã OTP 123456 để xác nhận';
      const textPin = 'Mật khẩu: 987654';

      final redBusiness = PiiRedactor.redact(textBusiness);
      final redOtp = PiiRedactor.redact(textOtp);
      final redPin = PiiRedactor.redact(textPin);

      expect(redBusiness, contains('125000'));
      expect(redBusiness, contains('15'));
      expect(redOtp, contains('[REDACTED_SECRET]'));
      expect(redOtp, isNot(contains('123456')));
      expect(redPin, contains('[REDACTED_SECRET]'));
      expect(redPin, isNot(contains('987654')));
    });

    testWidgets(
      'test_05_ui_renders_pairing_required_and_does_not_trigger_feedback_tap',
      (tester) async {
        final pairingMsg = BumMessage(
          content: 'Món bán chạy: Lẩu Thái',
          role: MessageRole.bum,
          status: MessageStatus.completed,
          feedbackStatus: 'pairing_required',
          feedbackRating: 'thumbs_down',
        );

        bool feedbackTapInvoked = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: BumMessageBubble(
                message: pairingMsg,
                onFeedbackTap: (rating, {reasonCode, proposedAnswer}) {
                  feedbackTapInvoked = true;
                },
              ),
            ),
          ),
        );

        expect(
          find.byKey(const Key('feedback_status_pairing_required')),
          findsOneWidget,
        );
        expect(find.textContaining('Chưa ghép nối thiết bị'), findsOneWidget);

        // Tapping PAIRING_REQUIRED text element MUST NOT call onFeedbackTap
        await tester.tap(
          find.byKey(const Key('feedback_status_pairing_required')),
        );
        await tester.pump();

        expect(
          feedbackTapInvoked,
          isFalse,
          reason:
              'Tapping PAIRING_REQUIRED status must not invoke onFeedbackTap or trigger infinite retry loop',
        );

        await tester.pumpWidget(const SizedBox());

        final failedMsg = BumMessage(
          content: 'Món bán chạy: Lẩu Thái',
          role: MessageRole.bum,
          status: MessageStatus.completed,
          feedbackRating: 'thumbs_down',
          feedbackStatus: 'failed',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BumMessageBubble(message: failedMsg)),
          ),
        );

        expect(find.byKey(const Key('feedback_status_failed')), findsOneWidget);
        expect(find.byKey(const Key('feedback_retry_button')), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );

    testWidgets('test_06_dialog_reason_and_proposed_answer_flow', (
      tester,
    ) async {
      FeedbackDialogResult? dialogResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  dialogResult = await FeedbackDialog.show(
                    context,
                    initialRating: 'thumbs_down',
                    currentAnswer: 'Báo cáo sai',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Gửi phản hồi cho AI Bum'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField),
        'Đề xuất câu trả lời chuẩn',
      );
      await tester.pump();

      await tester.tap(find.text('Gửi phản hồi'));
      await tester.pumpAndSettle();

      expect(dialogResult, isNotNull);
      expect(dialogResult!.rating, 'thumbs_down');
      expect(dialogResult!.proposedAnswer, 'Đề xuất câu trả lời chuẩn');
    });

    testWidgets('test_07_role_guard_hides_buttons_for_staff', (tester) async {
      final msg = BumMessage(
        content: 'Báo cáo doanh thu',
        role: MessageRole.bum,
        status: MessageStatus.completed,
      );

      // Owner/Manager sees feedback buttons
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BumMessageBubble(message: msg, isOwnerOrManager: true),
          ),
        ),
      );
      expect(find.byKey(const Key('feedback_thumbs_up')), findsOneWidget);
      expect(find.byKey(const Key('feedback_thumbs_down')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());

      // Staff/Cashier does NOT see feedback buttons (isOwnerOrManager: false)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BumMessageBubble(message: msg, isOwnerOrManager: false),
          ),
        ),
      );
      expect(find.byKey(const Key('feedback_thumbs_up')), findsNothing);
      expect(find.byKey(const Key('feedback_thumbs_down')), findsNothing);
    });

    testWidgets('test_08_pairing_dialog_and_connect_button_flow', (
      tester,
    ) async {
      final pairingMsg = BumMessage(
        content: 'Món bán chạy: Lẩu Thái',
        role: MessageRole.bum,
        status: MessageStatus.completed,
        feedbackStatus: 'pairing_required',
        feedbackRating: 'thumbs_down',
      );

      String? capturedPairingCode;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BumMessageBubble(
              message: pairingMsg,
              onPairingRequest: (code) {
                capturedPairingCode = code;
              },
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('feedback_connect_device')), findsOneWidget);

      // Tap 'Kết nối thiết bị' button -> opens PairingDialog
      await tester.tap(find.byKey(const Key('feedback_connect_device')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pairing_dialog')), findsOneWidget);
      expect(find.text('Kết nối thiết bị với AI Bum'), findsOneWidget);

      // Enter 6-digit code '842910' and submit
      await tester.enterText(
        find.byKey(const Key('pairing_code_input')),
        '842910',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('pairing_submit_button')));
      await tester.pumpAndSettle();

      expect(capturedPairingCode, '842910');
    });

    test('test_09_http_status_codes_202_401_403_409_429', () async {
      final mockClient = MockHttpClient();
      final mockStorage = MockFlutterSecureStorage();
      final validKeyB64 = base64Encode(List.filled(64, 0));

      when(
        () => mockStorage.read(key: 'bum_feedback_session_token'),
      ).thenAnswer((_) async => 'token_123');
      when(
        () => mockStorage.read(key: 'bum_feedback_ed25519_private_key'),
      ).thenAnswer((_) async => validKeyB64);
      when(
        () => mockStorage.read(key: 'bum_feedback_ed25519_public_key'),
      ).thenAnswer((_) async => validKeyB64);
      when(
        () => mockStorage.delete(key: any(named: 'key')),
      ).thenAnswer((_) async {});

      final service = FeedbackService(
        backendUrl: 'https://bunserver.tailcaeae7.ts.net',
        httpClient: mockClient,
        secureStorage: mockStorage,
      );

      // 1. HTTP 202 Accepted
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'success': true, 'candidate_id': 'cand-202'}),
          202,
          headers: {'content-type': 'application/json'},
        ),
      );
      final res202 = await service.submitFeedbackCandidate(
        sourceMessageId: 'm1',
        storeId: 's1',
        rating: 'thumbs_up',
      );
      expect(res202['success'], true);

      // 2. HTTP 401 Unauthorized
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'success': false, 'error': 'UNAUTHORIZED'}),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );
      final res401 = await service.submitFeedbackCandidate(
        sourceMessageId: 'm1',
        storeId: 's1',
        rating: 'thumbs_up',
      );
      expect(res401['error'], 'UNAUTHORIZED');
      verify(
        () => mockStorage.delete(key: 'bum_feedback_session_token'),
      ).called(greaterThanOrEqualTo(1));

      // 3. HTTP 403 Forbidden
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'success': false, 'error': 'FORBIDDEN'}),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );
      final res403 = await service.submitFeedbackCandidate(
        sourceMessageId: 'm1',
        storeId: 's1',
        rating: 'thumbs_up',
      );
      expect(res403['error'], 'FORBIDDEN');

      // 4. HTTP 409 Conflict
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'success': false, 'error': 'CONFLICT'}),
          409,
          headers: {'content-type': 'application/json'},
        ),
      );
      final res409 = await service.submitFeedbackCandidate(
        sourceMessageId: 'm1',
        storeId: 's1',
        rating: 'thumbs_up',
      );
      expect(res409['error'], 'CONFLICT');

      // 5. HTTP 429 Rate Limited
      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({'success': false, 'error': 'RATE_LIMITED'}),
          429,
          headers: {'content-type': 'application/json'},
        ),
      );
      final res429 = await service.submitFeedbackCandidate(
        sourceMessageId: 'm1',
        storeId: 's1',
        rating: 'thumbs_up',
      );
      expect(res429['error'], 'RATE_LIMITED');
    });

    test('test_10_zero_synthetic_jwt_string_in_source', () async {
      final forbiddenString = [
        'current',
        'supabase',
        'session',
        'token',
      ].join('_');
      final dirs = [Directory('lib'), Directory('test')];
      for (final dir in dirs) {
        if (dir.existsSync()) {
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is File && entity.path.endsWith('.dart')) {
              final content = entity.readAsStringSync();
              expect(
                content.contains(forbiddenString),
                false,
                reason:
                    'Forbidden synthetic token string found in ${entity.path}',
              );
            }
          }
        }
      }
    });

    test('test_11_bare_owner_uuid_returns_401', () async {
      final mockClient = MockHttpClient();
      final mockStorage = MockFlutterSecureStorage();

      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': 'MISSING_OR_INVALID_CREDENTIALS',
            'message': 'Yêu cầu số điện thoại và mật khẩu xác thực',
          }),
          401,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      );

      final service = FeedbackService(
        backendUrl: 'https://bunserver.tailcaeae7.ts.net',
        httpClient: mockClient,
        secureStorage: mockStorage,
      );

      final res = await service.exchangeSessionWithPassword(
        phone: '',
        password: '',
        storeId: 'store-001',
      );
      expect(res['success'], false);
      expect(res['status'], 401);
      expect(res['error'], 'UNAUTHORIZED');
    });

    test('test_12_password_auth_session_exchange_for_owner', () async {
      final storageMap = <String, String>{};
      final mockClient = MockHttpClient();
      final mockStorage = MockFlutterSecureStorage();

      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((inv) async => storageMap[inv.namedArguments[#key]]);
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((inv) async {
        storageMap[inv.namedArguments[#key] as String] =
            inv.namedArguments[#value] as String;
      });

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer((inv) async {
        final uri = inv.positionalArguments[0] as Uri;
        expect(uri.path, '/api/feedback/session/exchange');
        return http.Response(
          jsonEncode({
            'success': true,
            'session_token': 'bum_st_pass_123',
            'store_id': 'store-001',
            'role': 'owner',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = FeedbackService(
        backendUrl: 'https://bunserver.tailcaeae7.ts.net',
        httpClient: mockClient,
        secureStorage: mockStorage,
      );

      final res = await service.exchangeSessionWithPassword(
        phone: '0900000001',
        password: 'sample_password',
        storeId: 'store-001',
      );
      expect(res['success'], true);
      expect(res['session_token'], 'bum_st_pass_123');
      expect(storageMap['bum_feedback_session_token'], 'bum_st_pass_123');
    });

    test('test_13_password_auth_fails_wrong_password_401', () async {
      final mockClient = MockHttpClient();
      final mockStorage = MockFlutterSecureStorage();

      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': 'INVALID_CREDENTIALS',
            'message': 'Số điện thoại hoặc mật khẩu không chính xác',
          }),
          401,
          headers: {'content-type': 'application/json'},
        ),
      );

      final service = FeedbackService(
        backendUrl: 'https://bunserver.tailcaeae7.ts.net',
        httpClient: mockClient,
        secureStorage: mockStorage,
      );

      final res = await service.exchangeSessionWithPassword(
        phone: '0900000001',
        password: 'wrong_password',
        storeId: 'store-001',
      );
      expect(res['success'], false);
      expect(res['status'], 401);
      expect(res['error'], 'INVALID_CREDENTIALS');
    });

    test('test_14_password_auth_fails_staff_role_403', () async {
      final mockClient = MockHttpClient();
      final mockStorage = MockFlutterSecureStorage();

      when(
        () => mockStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
      when(
        () => mockStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockClient.post(
          any(),
          headers: any(named: 'headers'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'error': 'ROLE_FORBIDDEN',
            'message':
                'Chỉ Owner hoặc Manager mới được phép cấp feedback session',
          }),
          403,
          headers: {'content-type': 'application/json'},
        ),
      );

      final service = FeedbackService(
        backendUrl: 'https://bunserver.tailcaeae7.ts.net',
        httpClient: mockClient,
        secureStorage: mockStorage,
      );

      final res = await service.exchangeSessionWithPassword(
        phone: '0900000002',
        password: 'staff_password',
        storeId: 'store-001',
      );
      expect(res['success'], false);
      expect(res['status'], 403);
      expect(res['error'], 'ROLE_FORBIDDEN');
    });

    test(
      'test_15_expired_session_clears_token_and_returns_401_no_retry_loop',
      () async {
        final storageMap = <String, String>{
          'bum_feedback_session_token': 'expired_token_888',
        };
        final mockClient = MockHttpClient();
        final mockStorage = MockFlutterSecureStorage();

        when(
          () => mockStorage.read(key: any(named: 'key')),
        ).thenAnswer((inv) async => storageMap[inv.namedArguments[#key]]);
        when(
          () => mockStorage.write(
            key: any(named: 'key'),
            value: any(named: 'value'),
          ),
        ).thenAnswer((inv) async {
          storageMap[inv.namedArguments[#key] as String] =
              inv.namedArguments[#value] as String;
        });
        when(() => mockStorage.delete(key: any(named: 'key'))).thenAnswer((
          inv,
        ) async {
          storageMap.remove(inv.namedArguments[#key]);
        });

        int httpPostCalls = 0;
        when(
          () => mockClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((inv) async {
          httpPostCalls++;
          return http.Response(
            jsonEncode({'success': false, 'error': 'TOKEN_EXPIRED_OR_REVOKED'}),
            401,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = FeedbackService(
          backendUrl: 'https://bunserver.tailcaeae7.ts.net',
          httpClient: mockClient,
          secureStorage: mockStorage,
        );

        final res = await service.submitFeedbackCandidate(
          sourceMessageId: 'msg-001',
          storeId: 'store-001',
          rating: 'thumbs_up',
        );

        expect(res['success'], false);
        expect(res['status'], 401);
        expect(res['error'], 'UNAUTHORIZED');
        expect(storageMap.containsKey('bum_feedback_session_token'), false);
        // Strictly NO retry loop! Exactly 1 HTTP POST call made for submission
        expect(httpPostCalls, 1);
      },
    );
  });
}
