// Chủ Quán 21/11/2026: số lượng trên thẻ phiếu bếp khó đọc. Thẻ ghi tổng số phần cạnh số dòng món,
// ô số lượng từ 2 phần trở lên tô đặc, số lẻ không bị cắt thành số nguyên.
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
}

TicketWithItems _phieu(String id, String ban, List<(String, double)> mon) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TicketWithItems(
    ticket: KitchenTicketModel(
        id: id, storeId: 's', tableLabel: ban, status: 'cho', sentAt: now - 60000),
    items: [
      for (final (i, m) in mon.indexed)
        KitchenTicketItemModel(
            id: '$id$i', ticketId: id, productId: 'p$i', productName: m.$1, quantity: m.$2),
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

  testWidgets('thẻ phiếu ghi tổng số phần, ô số lượng nhiều phần tô đặc', (tester) async {
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
    repo.ctrl.add([
      _phieu('a', 'A 7', [('Trà đào', 12), ('Cà phê sữa', 1), ('Khô gà', 1.5)]),
      _phieu('b', 'B 2', [('Trà tắc', 1), ('Bạc xỉu', 1)]),
    ]);
    await tester.pump();
    await tester.pump();

    expect(find.text('3 món · 14.5 phần'), findsOneWidget);
    expect(find.text('2 món'), findsOneWidget); // mỗi món 1 phần thì không lặp lại con số
    expect(find.text('x1.5'), findsOneWidget);

    double doDacNen(String soLuong) => (tester
                .widget<Container>(find
                    .ancestor(of: find.text(soLuong).first, matching: find.byType(Container))
                    .first)
                .decoration as BoxDecoration)
            .color!
            .a;
    expect(doDacNen('x12'), 1.0); // nhiều phần: tô đặc
    expect(doDacNen('x1'), lessThan(0.5)); // 1 phần: nền nhạt
  });
}
