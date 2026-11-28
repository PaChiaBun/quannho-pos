// Trang chủ trên iPad (02/11): xoay dọc vùng nội dung ~731dp (820 trừ thanh bên 89). Trước đây vẫn ghim
// cột "Hôm nay" 280dp bên phải → ô chức năng bị bóp còn biểu tượng, tràn chữ. Giờ hẹp thì bỏ cột phải.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/providers/dashboard_providers.dart';
import 'package:quannho_pos/core/repositories/dashboard_repository.dart';
import 'package:quannho_pos/core/repositories/module_repository.dart';
import 'package:quannho_pos/modules/kho/providers/kho_providers.dart';
import 'package:quannho_pos/screens/dashboard_screen.dart';
import 'package:quannho_pos/shared/widgets/module_tile.dart';

const _ids = ['pos', 'kho', 'finance', 'report', 'loyalty', 'kitchen', 'staff'];

Future<void> _open(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      allModulesProvider.overrideWith((ref) => Stream.value([
            for (var i = 0; i < _ids.length; i++)
              ModuleConfig(id: _ids[i], label: _ids[i], icon: '', isActive: true, position: i),
          ])),
      todayStatsProvider.overrideWith((ref) => Stream.value(DashboardStats.empty)),
      lowStockKhoProvider.overrideWith((ref) => const AsyncValue.data([])),
      todayVoidStatsProvider.overrideWith((ref) async => <String, dynamic>{'amount': 0.0, 'count': 0}),
      shopNameProvider.overrideWith((ref) async => 'Bò Đen'),
      allProductsProvider.overrideWith((ref) => Stream.value(const [])),
    ],
    child: const MaterialApp(home: DashboardScreen()),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2)); // hết hiệu ứng ô xuất hiện
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('iPad dọc: không ghim cột phải, ô chức năng không bị bóp', (tester) async {
    await _open(tester, const Size(731, 1100));
    expect(tester.takeException(), isNull);
    expect(find.text('Hôm nay', skipOffstage: false), findsOneWidget); // chỉ tiêu đề dưới lưới
    final doc = tester.getSize(find.ancestor(of: find.text('Bán hàng'), matching: find.byType(ModuleTile)));
    expect(doc.width, greaterThan(200));
    expect(doc.height, greaterThan(160));
  });

  testWidgets('iPad ngang: vẫn có cột "Hôm nay" bên phải', (tester) async {
    await _open(tester, const Size(1091, 760));
    expect(tester.takeException(), isNull);
    expect(find.text('Hôm nay', skipOffstage: false), findsNWidgets(2));
  });
}
