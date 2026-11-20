import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/kitchen_repository.dart';

// Màn Phiếu bếp hiện phiếu huỷ (31/10): đọc đúng void_audit_logs, thẻ ĐÃ HUỶ chỉ 15 phút.
void main() {
  Map<String, dynamic> log(String label, List<Map<String, dynamic>>? details) => {
        'id': 'v1',
        'store_id': 's1',
        'void_type': 'void_item',
        'reference_id': 'mon-ban-1',
        'label': label,
        'requested_by_name': 'Phục vụ An',
        'approved_by_name': 'Quản lý Lan',
        'reason': 'Khách đổi ý',
        'amount': 50000,
        'details_json': details,
        'created_at': '2026-10-31T07:30:00+00:00',
      };

  test('Thông báo huỷ món đọc bàn/món/số lượng/người duyệt/lý do từ void_audit_logs', () {
    final n = VoidNoticeModel.fromMap(log('Bàn 3 (Món: Trà sữa (size L))', [
      {'product_name': 'Trà sữa (size L)', 'quantity': 2.0, 'subtotal': 50000},
    ]));
    expect(n.tableLabel, 'Bàn 3');
    expect(n.isReduce, isFalse);
    expect(n.shortLabel, '❌ Huỷ ×2 "Trà sữa (size L)"');
    expect(n.approvedBy, 'Quản lý Lan');
    expect(n.reason, 'Khách đổi ý');
    expect(n.referenceId, 'mon-ban-1');
  });

  test('Giảm món, huỷ phiếu ở Bán hàng, huỷ bàn, thiếu chi tiết', () {
    final giam = VoidNoticeModel.fromMap(log('Bàn VIP (tầng 2) (Giảm món: Cơm gà)', [
      {'product_name': 'Cơm gà', 'quantity': 1},
    ]));
    expect(giam.tableLabel, 'Bàn VIP (tầng 2)');
    expect(giam.shortLabel, '✏️ Giảm ×1 "Cơm gà"');

    final pos = VoidNoticeModel.fromMap(log('Mang đi (Huỷ phiếu bếp)', [
      {'product_name': 'Trà sữa', 'quantity': 2},
      {'product_name': 'Bánh flan', 'quantity': 1.5},
    ]));
    expect(pos.tableLabel, 'Mang đi');
    expect(pos.shortLabel, '❌ Huỷ: Trà sữa ×2, Bánh flan ×1.5');

    final ban = VoidNoticeModel.fromMap(log('Bàn 5', null));
    expect(ban.tableLabel, 'Bàn 5');
    expect(ban.items, isEmpty);
    expect(ban.shortLabel, '❌ Huỷ món');
  });

  test('Thẻ ĐÃ HUỶ chỉ hiện 15 phút kể từ giờ huỷ; phiếu huỷ thiếu giờ huỷ coi là cũ', () {
    final now = DateTime.utc(2026, 10, 31, 8);
    KitchenTicketModel ticket(String status, String? doneAt) => KitchenTicketModel.fromMap({
          'id': 't1',
          'store_id': 's1',
          'status': status,
          'sent_at': '2026-10-31T07:00:00+00:00',
          'done_at': doneAt,
        });
    expect(isRecentCancelledTicket(ticket('huy', '2026-10-31T07:50:00+00:00'), now), isTrue);
    expect(isRecentCancelledTicket(ticket('huy', '2026-10-31T07:45:00+00:00'), now), isFalse);
    expect(isRecentCancelledTicket(ticket('huy', null), now), isFalse);
    expect(isRecentCancelledTicket(ticket('xong', '2026-10-31T07:55:00+00:00'), now), isFalse);
  });

  test('Món phiếu bếp đọc session_item_id để biết món nào đã huỷ ở bàn', () {
    final m = {'id': 'i1', 'ticket_id': 't1', 'session_item_id': 'mon-ban-1', 'done': true};
    final mon = KitchenTicketItemModel.fromMap(m, cancelled: true);
    expect(mon.sessionItemId, 'mon-ban-1');
    expect(mon.cancelled, isTrue);
    expect(KitchenTicketItemModel.fromMap(m).cancelled, isFalse);
  });
}
