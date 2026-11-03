// Báo cáo đếm topping chọn kèm món (Chủ Quán 04/11/2026: "trân châu báo cáo sai số dù bán nhiều hơn"):
// topping trong modifiers_json của dòng món thành món riêng, tiền trừ khỏi món chính. Cùng bộ số với
// supabase/tests/topping_bao_cao_v1_test.sql để app (khi máy chủ lỗi, Boom trên máy) và máy chủ ra một số.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';

Map<String, Object> _top(String key, int n) =>
    {'type': 'topping', 'id': 'tc', 'name': 'Trân châu', 'price': 5000, key: n};

void main() {
  test('tách topping: bàn ghi tổng dòng, QR ghi mỗi phần × số món, tiền = giá × số', () {
    final ban = toppingSales([_top('qty', 1)], 2); // 2 ly + 1 trân châu cả dòng
    expect(ban.single.id, 'tc');
    expect(ban.single.name, 'Trân châu');
    expect(ban.single.qty, 1);
    expect(ban.single.revenue, 5000);

    final qr = toppingSales('[{"id":"tc","type":"topping","name":"Trân châu","price":5000,"quantity":1}]', 2);
    expect(qr.single.qty, 2); // mỗi ly 1
    expect(qr.single.revenue, 10000);

    final tuyChon = toppingSales([
      {'id': 'opt', 'name': 'Ít đá', 'price_adjust': 0}, // tuỳ chọn hương vị: không phải món
      _top('qty', 2),
    ], 1);
    expect(tuyChon.map((t) => t.qty), [2]);
  });

  test('dữ liệu hỏng hoặc dòng 0 món không đếm topping', () {
    expect(toppingSales('[{"type":"topping", hỏng', 1), isEmpty);
    expect(toppingSales(null, 1), isEmpty);
    expect(toppingSales([_top('quantity', 1)], 0), isEmpty); // món QR huỷ lúc thanh toán còn dòng 0
    expect(toppingSales([{'type': 'topping', 'name': 'Không mã', 'qty': 1}], 1), isEmpty);
  });

  test('cộng như báo cáo: món chính về đúng giá, tổng tiền không đổi', () {
    // Ngày 1 của bài test SQL: (số món, thành tiền dòng, modifiers)
    final lines = <(int, double, Object?)>[
      (2, 75000, [_top('qty', 1)]),
      (2, 80000, [_top('quantity', 1)]),
      (1, 45000, [{'id': 'opt', 'name': 'Ít đá'}, _top('qty', 2)]),
      (1, 35000, '[{"type":"topping", hỏng'),
    ];
    var dishQty = 0.0, dishRev = 0.0, topQty = 0.0, topRev = 0.0;
    for (final (q, sub, mods) in lines) {
      final tops = toppingSales(mods, q);
      dishQty += q;
      dishRev += sub - tops.fold(0.0, (s, t) => s + t.revenue);
      for (final t in tops) {
        topQty += t.qty;
        topRev += t.revenue;
      }
    }
    expect((dishQty, dishRev), (6, 210000)); // trước 235.000 — TB 35.833 đ/phần
    expect((topQty, topRev), (5, 25000)); // trước không có dòng trân châu
    expect(dishRev + topRev, 235000);
  });

  test('báo cáo tự tính, bộ lọc danh mục và Boom trên máy đều đọc topping', () {
    final repo = File('lib/core/repositories/dashboard_repository.dart').readAsStringSync();
    expect(repo, contains("subtotal, modifiers_json')"));
    expect(repo, contains("select('product_id, modifiers_json')"));
    expect(RegExp(r'toppingSales\(').allMatches(repo).length, 2);
    final boom = File('lib/features/ai_assistant/services/boom_read_only_data_service.dart').readAsStringSync();
    expect(boom, contains('cost_price,modifiers_json'));
    expect(boom, contains("toppingSales(item['modifiers_json'], quantity)"));
  });
}
