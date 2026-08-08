import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/features/ai_assistant/screens/bum_chat_screen.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/bum_message_bubble.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/bum_typing_indicator.dart';
import 'package:quannho_pos/features/ai_assistant/widgets/bum_suggestion_chips.dart';

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    
    // Tải font Roboto (có full Tiếng Việt) và đăng ký đúng cho tất cả các family font mà google_fonts sử dụng
    final robotoData = File('test/Roboto-Regular.ttf').readAsBytesSync();
    
    final fontFamilies = [
      'Outfit',
      'Outfit_regular',
      'Outfit_500',
      'Outfit_600',
      'Outfit_800',
    ];

    for (final family in fontFamilies) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(robotoData.buffer)));
      await loader.load();
    }
  });

  Widget createWidgetUnderTest() {
    return const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: BumChatScreen(),
        ),
      ),
    );
  }

  group('BumChatScreen Detailed Tests', () {
    testWidgets('1. Mở và đóng bottom sheet bằng showModalBottomSheet', (WidgetTester tester) async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const BumChatScreen(),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(BumChatScreen), findsOneWidget);

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(BumChatScreen), findsNothing);
    });

    testWidgets('2. Suggestion chip hiển thị đúng 4 câu và bấm được', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('Hôm nay bán được bao nhiêu?'), findsOneWidget);
      expect(find.text('Món nào bán chạy nhất?'), findsOneWidget);
      
      await tester.drag(find.byType(BumSuggestionChips), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Kho có gì sắp hết?'), findsOneWidget);
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

      final initialBubbles = find.byType(BumMessageBubble).evaluate().length;
      
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      final newBubbles = find.byType(BumMessageBubble).evaluate().length;
      expect(initialBubbles, newBubbles);
    });

    testWidgets('4. Khóa gửi khi xử lý và Streaming', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Doanh thu hôm nay');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      expect(find.text('Doanh thu hôm nay'), findsOneWidget);
      expect(find.byType(BumTypingIndicator), findsOneWidget);

      // Thử nhập một câu thứ hai vào TextField lúc đang loading
      await tester.enterText(find.byType(TextField), 'Câu hỏi thứ hai');
      await tester.tap(find.byIcon(Icons.send_rounded));
      await tester.pump();

      // Kiểm tra chỉ bên trong bubble: không xuất hiện bubble user thứ hai
      expect(
        find.descendant(
          of: find.byType(BumMessageBubble),
          matching: find.text('Câu hỏi thứ hai'),
        ),
        findsNothing,
      );

      // Bơm đủ để qua giai đoạn loading, nhận một vài từ
      await tester.pump(const Duration(milliseconds: 1200)); 
      
      // Lúc này AI đang streaming văn bản chưa hoàn chỉnh
      expect(find.byType(BumTypingIndicator), findsNothing);

      // Bơm đến completed
      await tester.pumpAndSettle(const Duration(seconds: 10));
      expect(find.textContaining('Quán Kay'), findsWidgets);
    });

    testWidgets('6. Render goldens (mobile & tablet)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();
      
      await expectLater(
        find.byType(BumChatScreen),
        matchesGoldenFile('goldens/bum_chat_mobile.png'),
      );

      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(BumChatScreen),
        matchesGoldenFile('goldens/bum_chat_tablet.png'),
      );
      
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  });
}
