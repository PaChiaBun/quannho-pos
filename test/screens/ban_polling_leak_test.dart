// Bò Đen lag 28/10/2026: rời màn Bàn vẫn sót vòng tải phiếu bếp; bảng chọn món gọi ghi chú nhanh từng món.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/repositories/kitchen_repository.dart';
import 'package:quannho_pos/screens/ban_screen.dart' show groupModifiersByProduct;
import 'package:quannho_pos/screens/kitchen_screen.dart' show kitchenReadyStreamProvider;

class _FakeKitchenRepo extends KitchenRepository {
  final ctrl = StreamController<String>();
  var cancelled = false;
  var fullTicketsWatched = false;
  _FakeKitchenRepo() {
    ctrl.onCancel = () => cancelled = true;
  }

  @override
  Stream<String> watchDoneTicketLabels() => ctrl.stream;

  // Bò Đen 12/11: máy order không được tải cả sổ phiếu bếp chỉ để báo món xong.
  @override
  Stream<List<TicketWithItems>> watchActiveTickets() {
    fullTicketsWatched = true;
    return const Stream.empty();
  }
}

void main() {
  test('rời màn Bàn (huỷ nghe báo món xong) thì dừng luôn vòng tải phiếu bếp', () async {
    final repo = _FakeKitchenRepo();
    final container = ProviderContainer(
      overrides: [kitchenRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final got = <String>[];
    final sub = container.listen(
      kitchenReadyStreamProvider,
      (_, next) => next.whenData(got.add),
    );
    repo.ctrl.add('Bàn 14');
    await Future<void>.delayed(Duration.zero);
    expect(got, ['Bàn 14']);
    expect(repo.cancelled, isFalse);
    expect(repo.fullTicketsWatched, isFalse);

    sub.close();
    await container.pump();
    await Future<void>.delayed(Duration.zero);
    expect(repo.cancelled, isTrue);
  });

  test('ghi chú nhanh tải 1 lần cho cả quán rồi chia theo món, giữ thứ tự máy chủ', () {
    final m = groupModifiersByProduct([
      {'id': 'a', 'product_id': 'p1', 'name': 'Ít đá'},
      {'id': 'b', 'product_id': 'p2', 'name': 'Ít ngọt'},
      {'id': 'c', 'product_id': 'p1', 'name': 'Nhiều đá'},
      {'id': 'd', 'product_id': null, 'name': 'Không gắn món'},
    ]);
    expect(m.keys, unorderedEquals(['p1', 'p2']));
    expect(m['p1']!.map((r) => r['id']), ['a', 'c']);
    expect(m['p3'], isNull);
  });
}
