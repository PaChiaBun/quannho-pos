import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/utils/station_normalizer.dart';
import 'package:quannho_pos/modules/kho/repository/kho_repository.dart';
import 'package:quannho_pos/core/models/product_model.dart';
import 'package:quannho_pos/screens/pos_screen.dart' show posProductSellable;

StockItem item({required double stock, required double min}) => StockItem(
  id: 'x',
  name: 'Món',
  unit: 'phần',
  stockQty: stock,
  minStock: min,
  costPrice: 0,
  sellPrice: 10000,
);

void main() {
  group('Nhãn tồn kho khớp quy tắc khoá món ở Bán hàng', () {
    test('Không đặt tồn tối thiểu → "Không theo dõi", kể cả khi tồn ≤ 0', () {
      expect(item(stock: 0, min: 0).status, StockStatus.untracked);
      expect(item(stock: -3, min: 0).status, StockStatus.untracked);
      expect(item(stock: 50, min: 0).status, StockStatus.untracked);
    });
    test('Có tồn tối thiểu: hết / sắp hết / còn hàng', () {
      expect(item(stock: 0, min: 5).status, StockStatus.outOfStock);
      expect(item(stock: 3, min: 5).status, StockStatus.low);
      expect(item(stock: 9, min: 5).status, StockStatus.ok);
    });
  });

  test(
    'Mã trạm phiếu bếp thực tế được chuẩn hoá đúng (bộ lọc Bếp dùng hàm này)',
    () {
      expect(normalizeStationCode('bep_bar'), 'bar');
      expect(normalizeStationCode('bar'), 'bar');
      expect(normalizeStationCode('nuoc'), 'bar');
      expect(normalizeStationCode('bep_nong'), 'nong');
      expect(normalizeStationCode('nong'), 'nong');
      final src = File('lib/screens/kitchen_screen.dart').readAsStringSync();
      final start = src.indexOf('String _classifyStation(');
      final body = src.substring(
        start,
        src.indexOf('List<TicketWithItems> _filterByStation', start),
      );
      expect(
        body,
        contains("normalizeStationCode(raw) == 'bar') return 'nuoc';"),
      );
      expect(body, contains("if (raw == 'nong') return 'nong';"));
      // bep_nong (mặc định món mới) KHÔNG được ép sang Bếp nóng — vẫn đoán theo tên như cũ.
      expect(body, isNot(contains("code == 'nong'")));
    },
  );

  test('Bán hàng khoá món tạm ngưng bán', () {
    final src = File('lib/screens/pos_screen.dart').readAsStringSync();
    expect(src, contains('if (!product.isAvailable) {'));
    expect(src, contains('final isLocked = isOutOfStock || isPaused;'));
    expect(src, contains("'Tạm ngưng'"));
  });

  test('Nhập hàng truyền quỹ đã chọn (không còn cố định Tiền mặt)', () {
    final repo = File(
      'lib/modules/kho/repository/kho_repository.dart',
    ).readAsStringSync();
    final start = repo.indexOf('Future<void> receiveStock(');
    final body = repo.substring(start, repo.indexOf('Future<', start + 10));
    expect(body, contains("'fund_type':    fundType,"));
    expect(body, isNot(contains("'fund_type':    'cash',")));
    for (final f in [
      'lib/modules/kho/screens/receive_stock_sheet.dart',
      'lib/modules/kho/screens/phieu_nhap_hang_screen.dart',
    ]) {
      final s = File(f).readAsStringSync();
      expect(s, contains('buildPurchaseFundPicker('), reason: f);
      expect(s, contains('_fundType'), reason: f);
    }
  });

  test(
    'Món bán được ở quầy (dùng cho lưới món, bảng nhấn giữ, nút + trong giỏ)',
    () {
      ProductModel p({bool avail = true, double stock = 5, double min = 0}) =>
          ProductModel(
            id: 'p',
            storeId: 's',
            name: 'x',
            unit: 'phần',
            productType: 'finished',
            stockQty: stock,
            minStock: min,
            sellPrice: 1,
            costPrice: 0,
            stationCode: 'nong',
            isAvailable: avail,
            isActive: true,
            isDeleted: false,
          );
      expect(posProductSellable(p()), isTrue);
      expect(posProductSellable(p(avail: false)), isFalse);
      expect(posProductSellable(p(stock: 0, min: 3)), isFalse);
      expect(posProductSellable(p(stock: -2, min: 0)), isTrue);
    },
  );

  test('Bảng nhấn giữ và nút + trong giỏ dùng posProductSellable', () {
    final src = File('lib/screens/pos_screen.dart').readAsStringSync();
    expect(src, contains('.where(posProductSellable)'));
    expect(src, contains('if (!posProductSellable(product)) continue;'));
    expect(
      src,
      contains('if (product != null && !posProductSellable(product)) {'),
    );
  });

  test(
    'Số đếm Hết hàng / Cảnh báo chỉ tính món có theo dõi tồn, không đếm trùng',
    () {
      final prov = File(
        'lib/modules/kho/providers/kho_providers.dart',
      ).readAsStringSync();
      expect(prov, contains('item.minStock > 0 && item.stockQty <= 0'));
      final repo = File(
        'lib/modules/kho/repository/kho_repository.dart',
      ).readAsStringSync();
      expect(repo, contains('p.minStock > 0 && p.stockQty <= 0'));
      final inv = File('lib/screens/inventory_screen.dart').readAsStringSync();
      expect(inv, isNot(contains('lowCount + outCount')));
    },
  );
}
