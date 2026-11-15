// Bò Đen 14/11/2026: bếp bấm "Bắt đầu làm" rồi "Xong" liền tay → khi máy chủ báo xong, thẻ
// lại nhảy về cột Đang làm tới 15 giây (cờ "đang làm" tạm không được bỏ). Giờ thẻ ở yên Hoàn thành.
import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/repositories/kitchen_repository.dart';
import 'package:quannho_pos/screens/kitchen_screen.dart';

class _Repo extends KitchenRepository {
  final ctrl = StreamController<List<TicketWithItems>>.broadcast();
  @override
  Stream<List<TicketWithItems>> watchActiveTickets() => ctrl.stream;
  @override
  Future<void> startTicket(String ticketId) async {}
  @override
  Future<void> doneTicket(String ticketId) async {}
}

TicketWithItems _phieu(String status) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TicketWithItems(
    ticket: KitchenTicketModel(
      id: 't1', storeId: 's', tableLabel: 'Bàn 1', status: status,
      sentAt: now - 60000, doneAt: status == 'xong' ? now : null,
    ),
    items: [
      KitchenTicketItemModel(
        id: 'i1', ticketId: 't1', productId: 'p', productName: 'Trà tắc',
        quantity: 1, done: status == 'xong',
      ),
    ],
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    for (final e in {'regular': 'Regular', '400': 'Regular', '500': 'Medium', '600': 'SemiBold', '700': 'Bold', '800': 'ExtraBold'}.entries) {
      final data = File('test/fonts/PlusJakartaSans-${e.value}.ttf').readAsBytesSync();
      await (FontLoader('PlusJakartaSans_${e.key}')..addFont(Future.value(ByteData.view(data.buffer)))).load();
    }
  });

  testWidgets('Bắt đầu rồi Xong liền tay: máy chủ báo xong thì thẻ ở yên Hoàn thành', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        kitchenRepositoryProvider.overrideWithValue(repo),
        voidNoticesProvider.overrideWith((ref) => Stream.value(const [])),
      ],
      child: const MaterialApp(home: KitchenScreen()),
    ));
    repo.ctrl.add([_phieu('cho')]);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Bắt đầu làm'));
    await tester.pump();
    await tester.tap(find.text('Xong'));
    await tester.pump();
    expect(find.text('Mở lại'), findsOneWidget);

    // Máy chủ báo phiếu đã xong (lần tải kế tiếp)
    repo.ctrl.add([_phieu('xong')]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Mở lại'), findsOneWidget);
    expect(find.text('Xong'), findsNothing);

    await tester.pump(const Duration(seconds: 16)); // hết hạn cờ tạm
    expect(find.text('Mở lại'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
