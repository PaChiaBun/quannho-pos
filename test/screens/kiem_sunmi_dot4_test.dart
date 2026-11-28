// Kiểm Sunmi Bò Đen trên bản 24 (03/11/2026, đọc-chỉ, 4 lỗi nhỏ E1–E4): Kiểm kê không liệt kê món bán theo
// công thức (E3), Báo cáo Kho CN ghi ngày như đầu trang Báo cáo thay vì "2026-11-02" (E2).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quannho_pos/modules/kho/providers/kho_providers.dart';
import 'package:quannho_pos/modules/kho/repository/kho_repository.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/screens/kho_chuyen_nghiep_report_screen.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/screens/stock_count_screen.dart';

StockItem _item(String id, String name, String unit, double qty) => StockItem(
    id: id, name: name, unit: unit, stockQty: qty, minStock: 0, costPrice: 0, sellPrice: 0);

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('vi');
  });

  test('E2 — ngày ở Báo cáo Kho CN ghi "Thứ Hai, 02/11" như đầu trang Báo cáo', () {
    expect(khoReportDayLabel('2026-11-02'), 'Thứ Hai, 02/11');
    expect(khoReportDayLabel('không rõ'), 'không rõ');
  });

  testWidgets('E3 — Kiểm kê không liệt kê món bán theo công thức (tồn của món không phải hàng thật)',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allStockProvider.overrideWith((ref) => Stream.value([
              _item('bac-xiu', 'Bạc Xỉu', 'ly', 100),
              _item('lon-sua', 'Lon Sữa Béo', 'lon', 12),
            ])),
        recipeProductIdsProvider.overrideWith((ref) async => {'bac-xiu'}),
      ],
      child: const MaterialApp(home: StockCountScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Bạc Xỉu'), findsNothing);
    expect(find.text('Lon Sữa Béo'), findsOneWidget); // món bán không công thức vẫn đếm
    expect(find.textContaining('Ẩn 1 món bán theo công thức'), findsOneWidget);
  });
}
