import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quannho_pos/core/models/product_model.dart';
import 'package:quannho_pos/core/utils/money_formatter.dart';
import 'package:quannho_pos/core/utils/server_time.dart';
import 'package:quannho_pos/modules/pos/providers/pos_providers.dart';

const _tra = ProductModel(
  id: 'p-tra',
  storeId: 's1',
  name: 'Trà tắc',
  unit: 'ly',
  productType: 'finished',
  stockQty: 10,
  minStock: 0,
  sellPrice: 25000,
  costPrice: 0,
  stationCode: 'nuoc',
  isAvailable: true,
  isActive: true,
  isDeleted: false,
);

void main() {
  group('Giỏ: món đã gửi bếp chỉ đổi được qua "Huỷ phiếu bếp"', () {
    late ProviderContainer c;
    late CartNotifier cart;
    setUp(() {
      c = ProviderContainer();
      cart = c.read(cartProvider.notifier);
    });
    tearDown(() => c.dispose());

    test('thêm cùng món sau khi gửi bếp tạo dòng mới (để gửi được phần thêm)', () {
      cart.addProduct(_tra);
      final sent = c.read(cartProvider).lines.single.lineId;
      cart.markLinesSent([sent]);
      cart.addProduct(_tra);
      final lines = c.read(cartProvider).lines;
      expect(lines, hasLength(2));
      expect(lines.first.quantity, 1); // dòng đã gửi giữ nguyên
      expect(c.read(cartProvider).isLineSent(lines.last.lineId), isFalse);
    });

    test('nút − không bớt dòng đã gửi; bớt dòng chưa gửi trước', () {
      cart.addProduct(_tra);
      final sent = c.read(cartProvider).lines.single.lineId;
      cart.markLinesSent([sent]);
      expect(cart.decreaseQtyByProductId(_tra.id), isFalse);
      expect(c.read(cartProvider).lines.single.quantity, 1);

      cart.addProduct(_tra); // dòng chưa gửi
      expect(cart.decreaseQtyByProductId(_tra.id), isTrue);
      expect(c.read(cartProvider).lines.single.lineId, sent);
      cart.decreaseQty(sent); // gọi thẳng cũng bị chặn
      expect(c.read(cartProvider).lines.single.lineId, sent);
    });

    test('huỷ phiếu bếp xong: món ở lại giỏ dạng chưa gửi, bỏ phiên bếp, giữ số Mang đi', () {
      cart.addProduct(_tra);
      cart.markLinesSent([c.read(cartProvider).lines.single.lineId]);
      cart.addKitchenSession('sess-1');
      cart.setTakeawayNo(7);
      cart.unsendAll();
      final s = c.read(cartProvider);
      expect(s.takeawayNo, 7); // cùng khách, gửi lại vẫn "Mang đi 7"
      expect(s.lines, hasLength(1));
      expect(s.sentLineIds, isEmpty);
      expect(s.kitchenSessionIds, isEmpty);
      expect(cart.decreaseQtyByProductId(_tra.id), isTrue);
      cart.clearCart(); // khách mới → số mới
      expect(c.read(cartProvider).takeawayNo, isNull);
    });
  });

  test('số "Mang đi" trong ngày: tăng dần, sang ngày mới đếm lại', () {
    expect(nextDailyTakeawayNo(null, '2026-11-01'), (no: 1, saved: '2026-11-01:1'));
    expect(nextDailyTakeawayNo('2026-11-01:4', '2026-11-01'), (no: 5, saved: '2026-11-01:5'));
    expect(nextDailyTakeawayNo('2026-10-31:9', '2026-11-01'), (no: 1, saved: '2026-11-01:1'));
    expect(const CartState(takeawayNo: 3).kitchenLabel, 'Mang đi 3');
    expect(const CartState().kitchenLabel, 'Mang đi');
  });

  test('giờ máy chủ (UTC) đổi sang giờ máy để hiển thị', () {
    final t = parseServerTime('2026-10-30T18:03:12+00:00')!;
    expect(t.isUtc, isFalse);
    expect(t, DateTime.utc(2026, 10, 30, 18, 3, 12).toLocal());
    expect(parseServerTime(''), isNull);
    expect(parseServerTime(null), isNull);
  });

  test('tiền rút gọn thống nhất với định dạng chuẩn', () {
    expect(fmtMoney(387000), '387.000 đ');
    expect(fmtMoney(5040000), '5.040.000 đ');
    expect(fmtMoney(196000000), '196 triệu');
    expect(fmtMoney(12500000), '12,5 triệu');
    expect(fmtMoney(1200000000), '1,2 tỷ');
    expect(fmtMoney(-25000), '-25.000 đ');
    expect(fmtMoney(9999999), '9.999.999 đ');
    expect(fmtMoney(10000000), '10 triệu');
    expect(fmtMoney(999940000), '999,9 triệu');
    expect(fmtMoney(999999999), '1 tỷ'); // trước đây "1000 triệu"
    expect(fmtMoney(double.nan), '—');
  });
}
