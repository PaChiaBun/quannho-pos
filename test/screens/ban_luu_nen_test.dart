// Bò Đen 12/11/2026: thẻ bàn hỏi món riêng mỗi 5 giây; bấm Thêm món phải chờ 3 chuyến ra Singapore.
// Giờ: 1 yêu cầu chung cho sơ đồ bàn; Thêm món hiện ngay, lưu nền 1 yêu cầu, không nhân đôi khi thử lại.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart';
import 'package:quannho_pos/screens/ban_screen.dart' show unsentQtyOps;

BanSessionItemModel _item(String id, String session, int addedAt) => BanSessionItemModel.fromMap({
      'id': id,
      'session_id': session,
      'product_id': 'p',
      'product_name': 'Trà tắc',
      'unit_price': 25000,
      'quantity': 1,
      'subtotal': 25000,
      'added_at': DateTime.fromMillisecondsSinceEpoch(addedAt, isUtc: true).toIso8601String(),
      'kitchen_status': 'chua_gui',
    });

void main() {
  group('+/− món gộp nhiều dòng (mỗi lần Thêm là 1 dòng)', () {
    final rowQty = {'a': 1.0, 'b': 2.0};
    test('tăng: cộng vào dòng đầu', () {
      expect(unsentQtyOps(ids: ['a', 'b'], rowQty: rowQty, newTotal: 4), [(id: 'a', qty: 2.0)]);
    });
    test('giảm: bớt từ dòng cuối, dòng về 0 thì xoá', () {
      expect(unsentQtyOps(ids: ['a', 'b'], rowQty: rowQty, newTotal: 2), [(id: 'b', qty: 1.0)]);
      expect(unsentQtyOps(ids: ['a', 'b'], rowQty: rowQty, newTotal: 1), [(id: 'b', qty: 0.0)]);
      expect(
        unsentQtyOps(ids: ['a', 'b'], rowQty: rowQty, newTotal: 0),
        [(id: 'b', qty: 0.0), (id: 'a', qty: 0.0)],
      );
    });
    test('không đổi thì không ghi', () {
      expect(unsentQtyOps(ids: ['a', 'b'], rowQty: rowQty, newTotal: 3), isEmpty);
    });
  });

  test('gộp dòng trùng trong cùng một lần Thêm, trừ món có topping tính tổng dòng', () {
    final out = mergeSameLines([
      {'productId': 'p', 'price': 25000, 'quantity': 1, 'note': null, 'modifiersJson': null},
      {'productId': 'p', 'price': 25000, 'quantity': 2, 'note': ' ', 'modifiersJson': ''},
      {'productId': 'p', 'price': 25000, 'quantity': 1, 'note': 'ít đá', 'modifiersJson': null},
    ]);
    expect(out.map((e) => e['quantity']), [3, 1]);
  });

  test('món mọi bàn đang mở gom theo phiên, theo thứ tự thêm', () {
    final m = groupItemsBySession([_item('2', 's1', 20), _item('1', 's1', 10), _item('3', 's2', 5)]);
    expect(m['s1']!.map((i) => i.id), ['1', '2']);
    expect(m['s2']!.map((i) => i.id), ['3']);
  });

  final repo = File('lib/core/repositories/ban_repository.dart').readAsStringSync();
  final screen = File('lib/screens/ban_screen.dart').readAsStringSync();

  test('lưu nền: 1 yêu cầu, mã dòng tạo ở máy, gửi lại không nhân đôi', () {
    final run = repo.substring(repo.indexOf('void _runPending(PendingItemAdd b)'));
    expect(run, contains("onConflict: 'id'"));
    expect(run, contains('ignoreDuplicates: true'));
    final add = repo.substring(
      repo.indexOf('void addSessionItemsInBackground('),
      repo.indexOf('void retryPendingAdds('),
    );
    expect(add, contains("'id': const Uuid().v4()"));
    expect(add, contains("'added_by': addedBy"));
  });

  test('bảng chọn món: không chờ mạng, bỏ lượt sửa người thêm món riêng', () {
    final confirm = screen.substring(screen.indexOf('Future<void> _confirm(List<ProductModel> products)'));
    final body = confirm.substring(0, confirm.indexOf('void _openToppingPicker('));
    expect(body, contains('_banRepo.addSessionItemsInBackground('));
    expect(body, isNot(contains('await _banRepo.addSessionItems(')));
    expect(body, isNot(contains(".update({'added_by'")));
  });

  test('gửi bếp, thanh toán, huỷ bàn, gộp bàn đều chờ món lưu nền xong', () {
    String head(String sig, int n) => screen.substring(screen.indexOf(sig)).substring(0, n);
    expect(head('Future<void> _sendToKitchen(List<BanSessionItemModel> items) async {', 400),
        contains('_awaitPendingAdds()'));
    expect(head('Future<void> _cancelSession() async {', 200), contains('_awaitPendingAdds()'));
    final checkout = screen.substring(screen.indexOf('Future<void> _openCheckout('));
    expect(checkout.substring(0, 900), contains('_awaitPendingAdds()'));
    final merge = screen.substring(screen.indexOf('onConfirm: (targetTableId) async {'));
    expect(merge.substring(0, 200), contains('_awaitPendingAdds()'));
  });

  test('thẻ bàn trên sơ đồ dùng 1 yêu cầu chung, không hỏi món riêng từng bàn', () {
    for (final cls in ['class _ActiveTableRow', 'class _TableCard']) {
      final body = screen.substring(screen.indexOf(cls));
      final build = body.substring(0, body.indexOf('return '));
      expect(build, contains('openSessionItemsProvider'), reason: cls);
      expect(build, isNot(contains('sessionItemsProvider(session')), reason: cls);
    }
  });
}
