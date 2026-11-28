// Màn Bếp trên iPad (02/11): xoay dọc vùng nội dung chỉ ~731dp (820 trừ thanh bên 89) — trước đây vẫn
// chia Kanban 3 cột nên phiếu bị bóp nhỏ và tràn. Giờ hẹp thì dùng dạng tab, xoay ngang vẫn Kanban.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/repositories/kitchen_repository.dart';
import 'package:quannho_pos/screens/kitchen_screen.dart';

class _FakeKitchenRepo extends KitchenRepository {
  _FakeKitchenRepo(this.tickets);
  final List<TicketWithItems> tickets;

  @override
  Stream<List<TicketWithItems>> watchActiveTickets() => Stream.value(tickets);
}

TicketWithItems _phieu(String id, String status) => TicketWithItems(
      ticket: KitchenTicketModel(
        id: id,
        storeId: 's',
        tableLabel: 'Bàn $id',
        zoneLabel: 'Trong nhà',
        status: status,
        sentAt: DateTime.now().subtract(const Duration(minutes: 9)).millisecondsSinceEpoch,
      ),
      items: [
        KitchenTicketItemModel(
          id: 'mon-$id',
          ticketId: id,
          productId: 'p',
          productName: 'Bò bít tết',
          quantity: 2,
          done: status == 'xong',
        ),
      ],
    );

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      kitchenRepositoryProvider.overrideWithValue(
        _FakeKitchenRepo([_phieu('1', 'cho'), _phieu('3', 'dang_lam'), _phieu('4', 'xong')]),
      ),
      voidNoticesProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: const MaterialApp(home: KitchenScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Phông thật để đo tràn chữ đúng độ rộng.
    const files = {
      'regular': 'Regular',
      '400': 'Regular',
      '500': 'Medium',
      '600': 'SemiBold',
      '700': 'Bold',
      '800': 'ExtraBold',
    };
    for (final e in files.entries) {
      final data = File('test/fonts/PlusJakartaSans-${e.value}.ttf').readAsBytesSync();
      await (FontLoader('PlusJakartaSans_${e.key}')
            ..addFont(Future.value(ByteData.view(data.buffer))))
          .load();
    }
  });

  testWidgets('iPad xoay dọc: dạng tab, phiếu không bị bóp/tràn', (tester) async {
    await _open(tester, const Size(731, 1100));
    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('Chờ xử lý'), findsNothing); // tiêu đề cột Kanban
  });

  testWidgets('iPad xoay ngang: vẫn Kanban 3 cột', (tester) async {
    await _open(tester, const Size(1091, 760));
    expect(tester.takeException(), isNull);
    expect(find.byType(TabBar), findsNothing);
    expect(find.text('Chờ xử lý'), findsOneWidget);
    expect(find.text('Hoàn thành'), findsOneWidget);
  });
}
