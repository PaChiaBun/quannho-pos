// Kiểm Sunmi Bò Đen đợt 3 (03/11/2026): thẻ Hóa đơn lùi được về hôm qua (D7), thẻ Thưởng có nút thêm
// phần thưởng thay cho "Thêm khách" (D6), Máy In & Luật In nhận đúng cách in + không gãy chữ trên 360dp
// (D5), Báo cáo Kho CN tính nguyên liệu bị trừ khi bán (D2). Đo bằng phông thật như các test bố cục khác.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/repositories/core_product_repository.dart';
import 'package:quannho_pos/core/utils/money_formatter.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';
import 'package:quannho_pos/modules/bill_printer/screens/print_rules_screen.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/providers/kho_chuyen_nghiep_providers.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/repository/kho_chuyen_nghiep_repository.dart';
import 'package:quannho_pos/modules/kho_chuyen_nghiep/screens/kho_chuyen_nghiep_report_screen.dart';
import 'package:quannho_pos/core/providers/permission_provider.dart';
import 'package:quannho_pos/core/repositories/bill_history_repository.dart';
import 'package:quannho_pos/modules/bill_printer/services/bill_reprint_service.dart';
import 'package:quannho_pos/screens/einvoice_report_tab.dart';
import 'package:quannho_pos/screens/loyalty_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ghi lại khoảng ngày mỗi lần tải bill.
class _RangeRepo extends BillHistoryRepository {
  final ranges = <(int, int)>[];
  @override
  Future<List<BillHistoryEntry>> listBills(int fromMs, int toMs, {int limit = 500}) async {
    ranges.add((fromMs, toMs));
    return const [];
  }
}

Future<void> _loadFont(String family, Iterable<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

/// Cấu hình máy in thật của Bò Đen (03/11): 1 máy in gắn trong Sunmi, 2 luật làm tay chỉ cho máy này.
class _BoDenPrinters extends PrinterSettingsNotifier {
  @override
  StationPrintersState build() => const StationPrintersState(
        cashier: PrinterConfig(name: '', type: 'system'),
        bepNong: PrinterConfig(name: '', type: 'system'),
        bepBar: PrinterConfig(name: '', type: 'system'),
        barLabel: PrinterConfig(name: '', type: 'system'),
        currentDeviceId: 'sunmi-bo-den',
        printSetup: PrintSetup(
          printers: [
            PrinterEntry(
              id: 'sumi',
              name: 'may in sumi',
              kind: PrinterKind.sunmiBuiltin,
              paper: PaperWidth.mm50,
              fontScale: 0.75,
            ),
          ],
          rules: [
            PrintRule(
              id: 'r1',
              name: 'Hóa đơn thanh toán – Android POS',
              jobType: PrintJobType.receipt,
              sourceDeviceIds: {'sunmi-bo-den'},
              targets: [PrintTarget(printerId: 'sumi')],
              priority: 50,
            ),
            PrintRule(
              id: 'r2',
              name: 'Phiếu tạm tính – Android POS',
              jobType: PrintJobType.provisional,
              sourceDeviceIds: {'sunmi-bo-den'},
              targets: [PrintTarget(printerId: 'sumi')],
              priority: 50,
            ),
          ],
        ),
      );
}

/// Kho CN của quán không dùng lệnh sản xuất: chỉ có phiếu trừ nguyên liệu khi bán.
class _FakeKhoPro extends KhoProRepository {
  _FakeKhoPro() : super(CoreProductRepository.instance);

  @override
  Future<SalesUsage> getSalesIngredientUsage({required DateTime from, required DateTime to}) async =>
      aggregateSalesUsage([
        {'product_id': 'cot', 'delta': -611.111, 'created_at': '2026-11-02T20:00:00'},
        {'product_id': 'cot', 'delta': -611.111, 'created_at': '2026-11-02T21:00:00'},
      ], {
        'cot': {'name': 'Cot Tra Den', 'unit': 'ml', 'cost_price_latest': 8.5, 'cost_price': 0},
      });

  @override
  Future<Map<String, double>> getFoodCostByDate({required DateTime from, required DateTime to}) async =>
      const {};

  @override
  Future<List<Map<String, dynamic>>> getIngredientConsumption(
          {required DateTime from, required DateTime to}) async =>
      const [];
}

/// Chữ gọn trong [lines] dòng (cao dưới (lines + 0,8) lần cỡ chữ).
void _atMostLines(WidgetTester tester, Finder f, int lines) {
  final rp = tester.renderObject<RenderParagraph>(f);
  final size = rp.text.style?.fontSize ?? 14;
  expect(rp.size.height, lessThan(size * (lines + 0.8)),
      reason: '${(tester.widget<Text>(f).data)} quá $lines dòng');
}

class _NoReprint implements BillReprintService {
  @override
  Future<ReprintOutcome> reprint(BillHistoryEntry entry) async => ReprintOutcome.printed;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final root = Platform.environment['FLUTTER_ROOT'] ??
        File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
    final dir = '$root/bin/cache/artifacts/material_fonts';
    await _loadFont('Roboto', ['Regular', 'Medium', 'Bold', 'Black'].map((w) => '$dir/Roboto-$w.ttf'));
    const jakarta = {
      'regular': 'Regular',
      '400': 'Regular',
      '500': 'Medium',
      '600': 'SemiBold',
      '700': 'Bold',
      '800': 'ExtraBold',
    };
    for (final e in jakarta.entries) {
      await _loadFont('PlusJakartaSans_${e.key}', ['test/fonts/PlusJakartaSans-${e.value}.ttf']);
    }
  });

  testWidgets('D5 — Máy In & Luật In 360dp: nhận đúng "Dùng máy POS", dải trạng thái cuộn, thẻ không gãy chữ',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ProviderScope(
      overrides: [printerSettingsProvider.overrideWith(_BoDenPrinters.new)],
      child: const MaterialApp(home: PrintRulesScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Trước: "Dùng máy Win làm máy in ✓ đang dùng — Máy này không tự in" dù bill in ở Sunmi.
    expect(find.textContaining('Dùng máy POS cầm tay làm máy in  ✓ đang dùng'), findsOneWidget);
    expect(find.textContaining('Dùng máy Win làm máy in  ✓'), findsNothing);

    // Dải trạng thái nằm trong danh sách, cuộn đi theo nội dung.
    final banner = find.textContaining('Đang dùng luật in');
    expect(banner, findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pump(const Duration(milliseconds: 300));
    expect(banner, findsNothing); // đã cuộn khuất, không còn đứng yên chiếm đầu màn

    // Thẻ máy in: tên một dòng (trước gãy "may in / sumi" vì 3 nút chiếm chỗ bên phải).
    for (var i = 0; i < 8 && find.text('may in sumi').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 200));
    }
    _atMostLines(tester, find.text('may in sumi'), 1);

    await tester.tap(find.text('Luật in (2)'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200)); // hiệu ứng chuyển trang chạy qua nhiều khung
    }
    _atMostLines(tester, find.text('Hóa đơn thanh toán – Android POS'), 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D2 — Báo cáo Kho CN: giá vốn nguyên liệu đã bán, không còn 0 đ khi không có lệnh sản xuất',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [khoProRepositoryProvider.overrideWithValue(_FakeKhoPro())],
      child: const MaterialApp(home: KhoProReportScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.text('Giá vốn NL đã bán'), findsOneWidget);
    expect(find.text(fmtMoney(2 * 611.111 * 8.5)), findsWidgets);
    expect(find.text('Chưa có dữ liệu sản xuất trong kỳ này'), findsNothing);

    await tester.tap(find.text('Tiêu thụ'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Dùng khi bán'), findsOneWidget);
    expect(find.text('Cot Tra Den'), findsOneWidget);
    expect(find.text('1222,2 ml'), findsOneWidget); // không "1222.222 ml"
  });

  testWidgets('D7 — thẻ Hóa đơn: ‹ lùi về hôm qua, tải bill đúng ngày hôm qua', (tester) async {
    final repo = _RangeRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        billHistoryRepositoryProvider.overrideWithValue(repo),
        billReprintServiceProvider.overrideWithValue(_NoReprint()),
        userActionPermsProvider.overrideWith((ref) async => <String>{}),
      ],
      child: const MaterialApp(home: Scaffold(body: EinvoiceReportTab())),
    ));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    expect(repo.ranges.last.$1, today.millisecondsSinceEpoch);

    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pumpAndSettle();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    expect(repo.ranges.last, (yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch));
    expect(find.text('Hôm qua'), findsOneWidget);

    // Đổi sang "Tuần này" thì thanh ngày ẩn đi.
    await tester.tap(find.text('Tuần này'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.chevron_left_rounded), findsNothing);
  });

  testWidgets('D6 — thẻ Thưởng: nút nổi là "Thêm phần thưởng", không phải "Thêm khách"', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(
      child: MaterialApp(home: LoyaltyScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Thêm khách'), findsOneWidget); // thẻ Khách

    await tester.tap(find.text('Thưởng'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(seconds: 1)); // hết hiệu ứng đổi nút nổi (nút cũ mờ dần)
    expect(find.text('Thêm phần thưởng'), findsOneWidget);
    expect(find.text('Thêm khách'), findsNothing);
    expect(find.byTooltip('Thêm phần thưởng'), findsOneWidget); // nút hộp quà trên đầu có chú thích
  });
}
