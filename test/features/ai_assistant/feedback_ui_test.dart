import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quannho_pos/features/ai_assistant/models/boom_message.dart';
import 'package:quannho_pos/features/ai_assistant/services/boom_telemetry_service.dart';
import 'package:quannho_pos/features/ai_assistant/services/legacy_feedback_cleanup.dart';
import 'package:quannho_pos/features/ai_assistant/services/pii_redactor.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/boom_message_bubble.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/feedback_dialog.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// 👍/👎 của Boom ghi vào sổ hỏi đáp của quán (boom_ai_route_test.dart). Đường phản hồi cũ qua BunServer
// ("ghép nối thiết bị") đã gỡ 24/10/2026 — chỉ giữ test giao diện phản hồi + bộ che thông tin.
void main() {
  group('Giao diện phản hồi Boom', () {
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

    testWidgets('Phản hồi chưa gửi được → hiện "chưa gửi" + nút thử lại', (
      tester,
    ) async {
      final failedMsg = BoomMessage(
        content: 'Món bán chạy: Lẩu Thái',
        role: MessageRole.boom,
        status: MessageStatus.completed,
        feedbackRating: 'thumbs_down',
        feedbackStatus: 'failed',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BoomMessageBubble(message: failedMsg)),
        ),
      );
      expect(find.byKey(const Key('feedback_status_failed')), findsOneWidget);
      expect(find.byKey(const Key('feedback_retry_button')), findsOneWidget);
      expect(find.textContaining('ghép nối'), findsNothing);
    });

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

      expect(find.text('Gửi phản hồi cho AI Boom'), findsOneWidget);

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
      final msg = BoomMessage(
        content: 'Báo cáo doanh thu',
        role: MessageRole.boom,
        status: MessageStatus.completed,
      );

      // Owner/Manager sees feedback buttons
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BoomMessageBubble(message: msg, isOwnerOrManager: true),
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
            body: BoomMessageBubble(message: msg, isOwnerOrManager: false),
          ),
        ),
      );
      expect(find.byKey(const Key('feedback_thumbs_up')), findsNothing);
      expect(find.byKey(const Key('feedback_thumbs_down')), findsNothing);
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
  });

  test('Không còn gửi gì về máy nội bộ BunServer', () {
    expect(BoomTelemetryTrace.enabled, isFalse);
    expect(
      BoomTelemetryTrace.start(
        storeId: 's1',
        userId: 'u1',
        intent: 'x',
        route: 'rag',
      ),
      isNull,
    );
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        expect(
          entity.readAsStringSync().contains('tailcaeae7.ts.net'),
          isFalse,
          reason: entity.path,
        );
      }
    }
  });

  test(
    'Đăng xuất: xoá phiên ghép nối + cặp khoá cũ, lỗi kho không chặn',
    () async {
      final storage = MockFlutterSecureStorage();
      final deleted = <String>[];
      when(() => storage.delete(key: any(named: 'key'))).thenAnswer((
        inv,
      ) async {
        final k = inv.namedArguments[#key] as String;
        deleted.add(k);
        if (k == 'boom_feedback_ed25519_public_key') throw Exception('web');
      });
      await clearLegacyBoomFeedbackKeys(storage: storage);
      expect(deleted, kLegacyBoomFeedbackKeys);
    },
  );
}
