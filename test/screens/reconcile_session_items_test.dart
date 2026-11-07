import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart';
import 'package:quannho_pos/screens/ban_screen.dart';

class _FakeRepo extends BanRepository {
  _FakeRepo(this.fresh);
  final List<BanSessionItemModel>? fresh;
  @override
  Future<List<BanSessionItemModel>?> fetchActiveSessionItems(
    String sessionId,
  ) async => fresh;
}

BanSessionItemModel _item(String id, double price) => BanSessionItemModel(
  id: id,
  sessionId: 's1',
  productId: 'p$id',
  productName: 'Món $id',
  price: price,
  quantity: 1,
  addedAt: 0,
  kitchenStatus: 'da_gui',
);

void main() {
  final shown = [_item('1', 24000), _item('2', 39000)];
  final all = [...shown, _item('3', 38000)];

  test('màn hình thiếu món -> dùng danh sách máy chủ (tạm tính không còn thấp hơn thật)', () async {
    final r = await reconcileSessionItems(
      repo: _FakeRepo(all),
      where: 't',
      sessionId: 's1',
      shown: shown,
    );
    expect(r.length, 3);
    expect(r.fold<double>(0, (s, i) => s + i.subtotal), 101000);
  });

  test('khớp máy chủ -> giữ nguyên danh sách đang hiện', () async {
    final r = await reconcileSessionItems(
      repo: _FakeRepo([...shown]),
      where: 't',
      sessionId: 's1',
      shown: shown,
    );
    expect(identical(r, shown), isTrue);
  });

  test('không tải được -> không chặn, dùng danh sách đang hiện', () async {
    final r = await reconcileSessionItems(
      repo: _FakeRepo(null),
      where: 't',
      sessionId: 's1',
      shown: shown,
    );
    expect(identical(r, shown), isTrue);
  });
}
