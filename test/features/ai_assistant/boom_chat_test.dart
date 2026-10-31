import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/help/boom_help_repository.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/features/ai_assistant/screens/boom_chat_screen.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/boom_message_bubble.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/boom_typing_indicator.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/boom_suggestion_chips.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    // Phông thật Plus Jakarta Sans (đủ dấu tiếng Việt, 24/10/2026 thay Outfit) đăng ký đúng tên family của
    // google_fonts → ảnh mẫu và kiểm tra tràn chữ đo bằng đúng độ rộng chữ thật.
    const files = {
      'regular': 'Regular',
      '400': 'Regular',
      '500': 'Medium',
      '600': 'SemiBold',
      '700': 'Bold',
      '800': 'ExtraBold',
    };
    for (final e in files.entries) {
      final data = File(
        'test/fonts/PlusJakartaSans-${e.value}.ttf',
      ).readAsBytesSync();
      final loader = FontLoader('PlusJakartaSans_${e.key}')
        ..addFont(Future.value(ByteData.view(data.buffer)));
      await loader.load();
    }
  });

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [boomHelpIndexProvider.overrideWith((ref) async => null)],
      child: const MaterialApp(home: Scaffold(body: BoomChatScreen())),
    );
  }

  group('BoomChatScreen Detailed Tests', () {
    testWidgets('1. Mở và đóng bottom sheet bằng showModalBottomSheet', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [boomHelpIndexProvider.overrideWith((ref) async => null)],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const BoomChatScreen(),
                    );
                  },
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(BoomChatScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BoomChatScreen), findsNothing);
    });

    testWidgets('2. Suggestion chip hiển thị đúng 5 câu và bấm được', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Hôm nay bán được bao nhiêu?'), findsOneWidget);
      // Gợi ý câu hỏi "cách làm" (Boom tra hướng dẫn) đứng thứ 2 để dễ thấy
      expect(find.text('Huỷ món đã gửi bếp thế nào?'), findsOneWidget);

      await tester.drag(
        find.byType(BoomSuggestionChips),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kho có gì sắp hết?'), findsOneWidget);
      expect(find.text('Món nào bán chạy nhất?'), findsOneWidget);
      expect(find.text('Hôm nay ai đang làm?'), findsOneWidget);

      await tester.tap(find.text('Kho có gì sắp hết?'));
      await tester.pump();

      expect(find.text('Kho có gì sắp hết?'), findsWidgets);
      await tester.pumpAndSettle(const Duration(seconds: 10));

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('3. Không gửi câu rỗng', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final initialBubbles = find.byType(BoomMessageBubble).evaluate().length;

      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      final newBubbles = find.byType(BoomMessageBubble).evaluate().length;
      expect(initialBubbles, newBubbles);
    });

    testWidgets('4. Khóa gửi khi xử lý và Streaming', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Doanh thu hôm nay');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('Doanh thu hôm nay'), findsOneWidget);
      expect(find.byType(BoomTypingIndicator), findsOneWidget);

      // Thử nhập một câu thứ hai vào TextField lúc đang loading
      await tester.enterText(find.byType(TextField), 'Câu hỏi thứ hai');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      // Kiểm tra chỉ bên trong bubble: không xuất hiện bubble user thứ hai
      expect(
        find.descendant(
          of: find.byType(BoomMessageBubble),
          matching: find.text('Câu hỏi thứ hai'),
        ),
        findsNothing,
      );

      // Bơm đủ để qua giai đoạn loading, nhận một vài từ
      await tester.pump(const Duration(milliseconds: 1200));

      // Lúc này AI đang streaming văn bản chưa hoàn chỉnh
      expect(find.byType(BoomTypingIndicator), findsNothing);

      // Bơm đến completed
      await tester.pumpAndSettle(const Duration(seconds: 10));
      // Widget test không có phiên đăng nhập/store thật: Boom phải fail-closed
      // và tuyệt đối không dựng số liệu quán giả.
      expect(find.textContaining('chưa kết nối được dữ liệu'), findsWidgets);
    });

    testWidgets('6. Render goldens (mobile & tablet)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      // Tải ảnh thật phải chạy trong runAsync — không thì thỉnh thoảng treo tới hết giờ chờ.
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/logo_head.png'),
          tester.element(find.byType(BoomChatScreen)),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(BoomChatScreen),
        matchesGoldenFile('goldens/boom_chat_mobile.png'),
      );

      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(createWidgetUnderTest());
      // Tải ảnh thật phải chạy trong runAsync — không thì thỉnh thoảng treo tới hết giờ chờ.
      await tester.runAsync(
        () => precacheImage(
          const AssetImage('assets/branding/logo_head.png'),
          tester.element(find.byType(BoomChatScreen)),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(BoomChatScreen),
        matchesGoldenFile('goldens/boom_chat_tablet.png'),
      );

      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
