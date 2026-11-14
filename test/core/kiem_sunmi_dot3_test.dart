// Kiểm Sunmi Bò Đen đợt 3 (03/11/2026, đọc-chỉ, 7 lỗi D1–D7): các phần có logic của bản sửa.
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/quantity_formatter.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';
import 'package:quannho_pos/modules/bill_printer/screens/print_rules_screen.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/repository/recipe_product_ids.dart';

void main() {
  test('D1 — chỉ món bán mới "theo công thức"; nguyên liệu / bán thành phẩm có tồn thật', () {
    expect(soldByRecipe('finished'), isTrue);
    expect(soldByRecipe(null), isTrue); // món cũ chưa có loại = món bán
    expect(soldByRecipe('combo'), isTrue);
    expect(soldByRecipe('ingredient'), isFalse); // vd "Cot Tra Den" — ly trà trừ dần, lệnh SX cộng vào
    expect(soldByRecipe('semi_finished'), isFalse);
  });

  group('D2 — giá vốn nguyên liệu bị trừ khi bán', () {
    final products = {
      'cot': {'name': 'Cot Tra Den', 'unit': 'ml', 'cost_price_latest': 8.5, 'cost_price': 0},
      'syrup': {
        'name': 'Syrup đường',
        'unit': 'chai',
        'cost_price_latest': 0,
        'cost_price': 60000,
        'conversion_rate': 750,
        'conversion_unit': 'ml',
      },
    };
    // Giờ máy (không "Z") để kết quả theo ngày không phụ thuộc múi giờ máy chạy test.
    final moves = [
      {'product_id': 'cot', 'delta': -611.111, 'created_at': '2026-11-02T10:00:00'},
      {'product_id': 'syrup', 'delta': -0.039, 'created_at': '2026-11-02T10:00:00'},
      {'product_id': 'cot', 'delta': -611.111, 'created_at': '2026-11-03T09:00:00'},
      {'product_id': 'syrup', 'delta': 2, 'created_at': '2026-11-03T09:00:00'}, // cộng vào — bỏ qua
      {'product_id': 'da-xoa', 'delta': -1, 'created_at': '2026-11-03T09:00:00'},
    ];

    test('theo ngày và theo nguyên liệu, tiền giảm dần; giá vốn ưu tiên giá nhập gần nhất', () {
      final r = aggregateSalesUsage(moves, products);
      expect(r.costByDate['2026-11-02'], closeTo(611.111 * 8.5 + 0.039 * 60000, 0.01));
      expect(r.costByDate['2026-11-03'], closeTo(611.111 * 8.5, 0.01));
      expect(r.ingredients.map((e) => e['ingredient_name']),
          ['Cot Tra Den', 'Syrup đường', '(nguyên liệu đã xoá)']);
      expect(r.ingredients.first['total_qty'], closeTo(1222.222, 0.001));
      expect(r.ingredients[1]['total_qty'], closeTo(0.039, 0.0001)); // phiếu cộng không tính
      expect(r.ingredients[1]['conversion_rate'], 750);
    });

    test('không có phiếu → rỗng', () {
      final r = aggregateSalesUsage(const [], const {});
      expect(r.costByDate, isEmpty);
      expect(r.ingredients, isEmpty);
    });
  });

  test('D3 — số biến động kho ghi như tồn, không "611.111 ml"', () {
    expect(fmtStockDelta(-0.039, 'chai', conversionRate: 750, conversionUnit: 'ml'), '-29 ml');
    expect(fmtStockDelta(-611.111, 'ml'), '-611,1 ml');
    expect(fmtStockDelta(-0.25, 'gói'), '-0,25 gói');
    expect(fmtStockDelta(2, 'gói'), '+2 gói');
    expect(fmtStockDelta(-1.5, 'lon', conversionRate: 1361, conversionUnit: 'g'), '-1 lon + 681 g');
    expect(fmtStockDelta(0, 'ml'), '0 ml');
    expect(fmtStockDelta(-0.0001, 'lon', conversionRate: 1361, conversionUnit: 'g'), '0 lon');
  });

  test('D4 — tìm không dấu và gõ tắt như ô tìm Bán hàng', () {
    expect('Nước ép Thơm'.containsSearch('thom'), isTrue);
    expect('Trà Sữa Bơ Đậu Phộng'.containsSearch('tsbdp'), isTrue);
    expect('Cà Phê Sấy Lạnh'.containsSearch('thom'), isFalse);
  });

  group('D5 — Thiết lập nhanh nhận đúng cách in bill theo luật đang chạy', () {
    const sumi = PrinterEntry(id: 'sumi', name: 'may in sumi', kind: PrinterKind.sunmiBuiltin);
    const quay = PrinterEntry(id: 'quay', name: 'Máy quầy', kind: PrinterKind.lan);
    PrintRule receipt(List<String> printers, {Set<String> devices = const {'dev'}, bool on = true}) =>
        PrintRule(
          id: 'r-${printers.join()}-${devices.join()}',
          name: 'Hóa đơn thanh toán – Android POS',
          jobType: PrintJobType.receipt,
          sourceDeviceIds: devices,
          targets: [for (final p in printers) PrintTarget(printerId: p)],
          enabled: on,
        );
    String? mode(List<PrintRule> rules, {List<PrintRule> quick = const [], bool dual = false}) =>
        quickBillMode(const PrintSetup(printers: [sumi, quay]).copyRules(rules), 'dev',
            deviceRules: quick, isDual: dual);

    test('Bò Đen: luật làm tay đưa hoá đơn ra máy in gắn trong Sunmi → "Dùng máy POS cầm tay"', () {
      expect(mode([receipt(['sumi'])]), 'pos');
    });
    test('không luật nào in ở máy này → "Dùng máy Win"', () {
      expect(mode(const []), 'win');
      expect(mode([receipt(['quay'], devices: const {})]), 'win'); // luật chung ra máy quầy
      expect(mode([receipt(['sumi'], devices: const {'may-khac'})]), 'win');
      expect(mode([receipt(['sumi'], on: false)]), 'win');
    });
    test('luật riêng lẫn nhiều máy in → không đánh dấu kiểu nào', () {
      expect(mode([receipt(['sumi', 'quay'])]), isNull);
    });
    test('luật do Thiết lập nhanh tạo vẫn như cũ', () {
      final q = [receipt(['sumi'])];
      expect(mode(const [], quick: q), 'pos');
      expect(mode(const [], quick: q, dual: true), 'dual');
    });
  });
}

extension on PrintSetup {
  PrintSetup copyRules(List<PrintRule> rules) => PrintSetup(printers: printers, rules: rules);
}
