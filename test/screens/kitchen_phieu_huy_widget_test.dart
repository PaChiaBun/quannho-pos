// Màn Phiếu bếp hiện phiếu huỷ (31/10): thẻ ĐÃ HUỶ ở điện thoại 360dp / Kanban / màn trống,
// món huỷ lẻ gạch ngang, dải thông báo không báo đôi với thẻ.
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

final _now = DateTime.now();

KitchenTicketItemModel _mon(String id, {bool cancelled = false, bool done = false, String? station}) =>
    KitchenTicketItemModel(
      id: id,
      ticketId: 't',
      productId: 'p',
      productName: 'Món $id',
      quantity: 1,
      done: done || cancelled, // máy chủ để món huỷ done = true
      stationCode: station,
      sessionItemId: 'ban-$id',
      cancelled: cancelled,
    );

TicketWithItems _phieu(String id, String status, List<KitchenTicketItemModel> items) =>
    TicketWithItems(
      ticket: KitchenTicketModel(
        id: id,
        storeId: 's',
        tableLabel: 'Bàn $id',
        zoneLabel: 'Sân vườn',
        status: status,
        sentAt: _now.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
        doneAt: status == 'huy'
            ? _now.subtract(const Duration(minutes: 3)).millisecondsSinceEpoch
            : null,
      ),
      items: items,
    );

VoidNoticeModel _bao(String mon) => VoidNoticeModel.fromMap({
      'id': 'v-$mon',
      'reference_id': 'ban-$mon',
      'label': 'Bàn 1 (Món: Món $mon)',
      'reason': 'Khách đổi ý',
      'approved_by_name': 'Quản lý Lan',
      'details_json': [
        {'product_name': 'Món $mon', 'quantity': 1},
      ],
    });

Future<void> _open(WidgetTester tester, Size size, List<TicketWithItems> tickets) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      kitchenRepositoryProvider.overrideWithValue(_FakeKitchenRepo(tickets)),
      voidNoticesProvider.overrideWith((ref) => Stream.value([_bao('A'), _bao('C')])),
    ],
    child: const MaterialApp(home: KitchenScreen()),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Phông thật (như tram_in_theo_luat_test) để kiểm tra tràn chữ ở 360dp đo đúng độ rộng.
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

  // Phiếu 1 đang chờ: món A huỷ lẻ, món B chưa làm. Phiếu 2 huỷ 3 phút trước: món C huỷ, món D bếp đã làm xong.
  final tickets = [
    _phieu('1', 'cho', [_mon('A', cancelled: true), _mon('B')]),
    _phieu('2', 'huy', [_mon('C', cancelled: true), _mon('D', done: true)]),
  ];

  testWidgets('Điện thoại 360dp: thẻ ĐÃ HUỶ, món huỷ lẻ gạch ngang, không báo đôi, Đã xem thì ẩn', (
    tester,
  ) async {
    await _open(tester, const Size(360, 740), tickets);
    expect(tester.takeException(), isNull);

    expect(find.text('ĐÃ HUỶ'), findsOneWidget);
    expect(find.textContaining('Sân vườn · Huỷ lúc '), findsOneWidget);
    expect(find.text('x1  Món C'), findsOneWidget);
    expect(find.text('x1  Món D'), findsNothing); // bếp đã làm xong, không kê là huỷ
    final tenMonA = tester.widget<Text>(find.text('Món A'));
    expect(tenMonA.style?.decoration, TextDecoration.lineThrough);
    expect(find.text('HUỶ'), findsOneWidget); // nhãn của món A, thay vòng tròn bấm xong
    expect(find.text('❌ Huỷ ×1 "Món A"'), findsOneWidget);
    expect(find.text('❌ Huỷ ×1 "Món C"'), findsNothing); // đã có thẻ ĐÃ HUỶ

    await tester.tap(find.text('Đã xem'));
    await tester.pump();
    expect(find.text('ĐÃ HUỶ'), findsNothing);
  });

  testWidgets('Kanban: thẻ ĐÃ HUỶ ở đầu, phiếu huỷ không vào cột Hoàn thành', (tester) async {
    await _open(tester, const Size(1280, 800), tickets);
    expect(tester.takeException(), isNull);
    expect(find.text('ĐÃ HUỶ'), findsOneWidget);
    expect(find.text('❌ Huỷ ×1 "Món A"'), findsOneWidget);
    expect(find.text('Trống'), findsNWidgets(2)); // cột Đang làm + Hoàn thành
  });

  testWidgets('Lọc Bếp nước: đồ uống của phiếu bị huỷ hết → thẻ ĐÃ HUỶ, không vào Hoàn thành', (
    tester,
  ) async {
    await _open(tester, const Size(1280, 800), [
      _phieu('3', 'dang_lam', [
        _mon('E', cancelled: true, station: 'bep_bar'),
        _mon('F', station: 'nong'),
      ]),
    ]);
    expect(find.text('ĐÃ HUỶ'), findsNothing); // Tất cả: phiếu vẫn đang làm món F
    await tester.tap(find.text('Bếp nước'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('ĐÃ HUỶ'), findsOneWidget);
    expect(find.text('Trống'), findsNWidgets(3));
  });

  testWidgets('Không còn phiếu đang làm: vẫn hiện thẻ ĐÃ HUỶ', (tester) async {
    await _open(tester, const Size(360, 740), [tickets[1]]);
    expect(tester.takeException(), isNull);
    expect(find.text('ĐÃ HUỶ'), findsOneWidget);
    expect(find.text('Bếp đang yên tĩnh'), findsOneWidget);
  });
}
