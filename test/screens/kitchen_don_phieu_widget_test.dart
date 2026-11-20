// Chủ Quán 21/11/2026: phiếu bếp bị dọn quá nhanh. Bò Đen 7 ngày: 31% phiếu biến mất ngay lúc bấm Xong
// vì bàn đã thanh toán, trung vị ở lại 46 giây. Phiếu xong nay ở lại tới khi bếp dọn (hoặc 15 phút);
// thêm nút "Dọn Phiếu Đã Xong".
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
  List<String>? daDon;
  @override
  Stream<List<TicketWithItems>> watchActiveTickets() => ctrl.stream;
  @override
  Future<void> archiveTickets(List<String> ticketIds) async => daDon = ticketIds;
}

TicketWithItems _phieu(String id, String status) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TicketWithItems(
    ticket: KitchenTicketModel(
      id: id, storeId: 's', tableLabel: 'Bàn $id', status: status,
      sentAt: now - 120000, doneAt: status == 'xong' ? now - 60000 : null,
    ),
    items: [
      KitchenTicketItemModel(
        id: 'i$id', ticketId: id, productId: 'p', productName: 'Trà tắc',
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

  test('phiếu xong không còn bị ẩn theo bàn đã thanh toán', () {
    final repo = File('lib/core/repositories/kitchen_repository.dart').readAsStringSync();
    expect(repo, isNot(contains('openSessionIds')));
    expect(repo, contains('inMinutes >= 15')); // vẫn tự ẩn sau 15 phút
  });

  for (final (ten, size) in [('máy tính', const Size(1280, 800)), ('điện thoại', const Size(400, 820))]) {
    testWidgets('Dọn Phiếu Đã Xong ($ten): hỏi lại rồi chỉ dọn phiếu đã xong', (tester) async {
      tester.view.physicalSize = size;
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
      repo.ctrl.add([_phieu('1', 'xong'), _phieu('2', 'xong'), _phieu('3', 'cho')]);
      await tester.pump();
      await tester.pump();
      if (find.text('Xong').evaluate().isNotEmpty && find.text('Dọn Phiếu Đã Xong').evaluate().isEmpty) {
        await tester.tap(find.text('Xong')); // điện thoại: sang tab Xong
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Dọn Phiếu Đã Xong'));
      await tester.pumpAndSettle();
      expect(find.text('Dọn 2 phiếu đã xong?'), findsOneWidget);
      await tester.tap(find.text('Không'));
      await tester.pumpAndSettle();
      expect(repo.daDon, isNull);

      await tester.tap(find.text('Dọn Phiếu Đã Xong'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dọn'));
      await tester.pump();
      expect(repo.daDon, unorderedEquals(['1', '2']));
      await tester.pump(const Duration(seconds: 3)); // cho thông báo "Đã dọn" tắt
    });
  }
}
