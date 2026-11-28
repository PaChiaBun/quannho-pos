// Bò Đen 12/11/2026: phiếu bếp chiếm 70% dung lượng buổi tối (102/144 MB) — máy order tải cả
// sổ phiếu 4 giờ chỉ để báo món xong; màn bếp tải cả phiếu xong cũ kèm món rồi mới lọc bỏ.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/kitchen_repository.dart';

KitchenTicketModel _t(String id, String status, {DateTime? done, String? label}) =>
    KitchenTicketModel.fromMap({
      'id': id,
      'store_id': 's',
      'status': status,
      'table_label': label,
      'sent_at': '2026-11-12T13:00:00Z',
      'done_at': done?.toUtc().toIso8601String(),
    });

void main() {
  final since = DateTime.utc(2026, 11, 12, 13, 30);

  test('báo món xong: chỉ phiếu xong sau lúc bắt đầu nghe, mỗi phiếu một lần', () {
    final known = <String>{};
    final ms = since.millisecondsSinceEpoch;
    final after = since.add(const Duration(minutes: 1));
    expect(newDoneTicketLabel(_t('a', 'xong', done: after, label: 'Bàn 14'), known, ms), 'Bàn 14');
    expect(newDoneTicketLabel(_t('a', 'xong', done: after, label: 'Bàn 14'), known, ms), isNull);
    expect(newDoneTicketLabel(_t('b', 'xong', done: after), known, ms), 'Phiếu bếp');
    expect(newDoneTicketLabel(_t('c', 'xong', done: since.subtract(const Duration(minutes: 1))), known, ms), isNull);
    expect(newDoneTicketLabel(_t('d', 'cho'), known, ms), isNull);
    expect(newDoneTicketLabel(_t('e', 'huy', done: after), known, ms), isNull);
  });

  final repo = File('lib/core/repositories/kitchen_repository.dart').readAsStringSync();

  test('màn bếp: chỉ tải phiếu có thể hiện, và chỉ tải món của phiếu đang hiện', () {
    expect(repo, contains(".or('status.in.(cho,dang_lam),done_at.gte.\$cancelledSince,done_at.is.null')"));
    final fetch = repo.substring(repo.indexOf('_fetchActiveTickets(String storeId) async'));
    expect(
      fetch.indexOf(".from('kitchen_ticket_items')"),
      greaterThan(fetch.indexOf('final shownIds = shown.map')),
    );
  });

  test('màn bếp: sự kiện dồn dập gộp thành một lượt tải, không tải chồng', () {
    final watch = repo.substring(repo.indexOf('Stream<List<TicketWithItems>> watchActiveTickets()'));
    expect(watch, contains('if (!isCancelled) refreshSoon(storeId);'));
    expect(watch, isNot(contains('if (!isCancelled) refresh(storeId);\n              },')));
    expect(watch, contains('if (running) {'));
  });
}
