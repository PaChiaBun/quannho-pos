// Kiểm Sunmi Bò Đen 03/11/2026 — bố cục 360×800dp (máy POS Sunmi V3) đo bằng phông thật (Roboto của
// Flutter SDK, Plus Jakarta Sans trong test/fonts): nhãn ngày biểu đồ không bị cắt còn "0", bảng Tài
// chính không gãy chữ, thanh màu top món theo doanh thu, Thiết kế mẫu in thấy đủ 3 chế độ; mở Thu Chi
// luôn về "Hôm nay".
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quannho_pos/core/providers/dashboard_providers.dart';
import 'package:quannho_pos/core/repositories/dashboard_repository.dart';
import 'package:quannho_pos/modules/bill_printer/widgets/designer_shell.dart';
import 'package:quannho_pos/modules/finance/providers/finance_providers.dart';
import 'package:quannho_pos/modules/finance/repository/finance_repository.dart';
import 'package:quannho_pos/screens/finance_screen.dart';
import 'package:quannho_pos/screens/report_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, Iterable<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

/// Số liệu giống Bò Đen đầu tháng 11: chỉ ngày 1–2 có doanh thu, hôm qua bán từ 14h tới 23h.
class _FakeDash extends DashboardRepository {
  @override
  Future<DashboardStats> getStatsForRange(int from, int to) async => const DashboardStats(
        todayRevenue: 7248000,
        todayOrders: 69,
        todayCustomers: 0,
        avgOrderValue: 105043,
        cashRevenue: 4305000,
        transferRevenue: 2943000,
      );

  @override
  Future<List<DailyRevenue>> getDailyRevenue(int from, int to) async {
    final end = DateTime.fromMillisecondsSinceEpoch(to);
    return [
      for (var d = DateTime.fromMillisecondsSinceEpoch(from);
          d.isBefore(end);
          d = DateTime(d.year, d.month, d.day + 1))
        DailyRevenue(date: d, revenue: d.day <= 2 ? 3624000 : 0, orders: d.day <= 2 ? 35 : 0),
    ];
  }

  @override
  Stream<List<HourlyRevenue>> watchHourlyRevenue(DateTime date) => Stream.value([
        for (var h = 0; h < 24; h++)
          HourlyRevenue(hour: h, revenue: h >= 14 ? 350000 : 0, orders: h >= 14 ? 3 : 0),
      ]);

  @override
  Future<List<TopProduct>> getTopProductsForRangeCompat(int from, int to,
          {String? category, int limit = 10}) async =>
      const [
        TopProduct(productId: 'a', productName: 'Trà Sữa Hong Kong', totalQty: 18, totalRevenue: 847000),
        TopProduct(productId: 'b', productName: 'Lon Sữa Béo', totalQty: 5, totalRevenue: 725000),
        TopProduct(productId: 'c', productName: 'Chai Trà Sữa', totalQty: 16, totalRevenue: 624000),
        TopProduct(productId: 'd', productName: 'Trà Sữa Bơ Đậu Phộng', totalQty: 8, totalRevenue: 317000),
      ];

  @override
  Future<List<String>> getProductCategoriesSold(int from, int to) async => const ['Đồ uống'];
}

const _fin = FinanceStats(
  income: 3481000,
  expense: 0,
  profit: 3481000,
  prevIncome: 3767000,
  expenseByCategory: {},
  transactionCount: 30,
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Đổi kỳ báo cáo: màn chờ huỷ luồng số liệu theo giờ — tương lai đó chỉ xong khi có vòng lặp thật,
/// đồng hồ giả của test không chạy tới (ngoài app thì xong ngay).
Future<void> _switchPeriod(WidgetTester tester, Finder target) async {
  await tester.tap(target);
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await _settle(tester);
}

Future<void> _pumpReport(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dashboardRepositoryProvider.overrideWithValue(_FakeDash()),
      todayStatsProvider.overrideWith((ref) => Stream.value(DashboardStats.empty)),
      todayFinanceStatsProvider.overrideWith((ref) async => FinanceStats.empty),
      financeStatsProvider.overrideWith((ref) async => _fin),
    ],
    child: const MaterialApp(home: Scaffold(body: ReportScreen())),
  ));
  await _settle(tester);
}

bool _cut(WidgetTester tester, Finder f) =>
    tester.renderObject<RenderParagraph>(f).didExceedMaxLines;

/// Chữ nằm gọn một dòng: không cắt, cao dưới 1,8 lần cỡ chữ (hai dòng ≥ 2,4 lần).
void _oneLine(WidgetTester tester, Finder f) {
  expect(f, findsWidgets);
  for (final e in f.evaluate()) {
    final rp = e.renderObject! as RenderParagraph;
    final size = rp.text.style?.fontSize ?? 14;
    expect(rp.didExceedMaxLines, isFalse, reason: '${(e.widget as Text).data} bị cắt');
    expect(rp.size.height, lessThan(size * 1.8), reason: '${(e.widget as Text).data} xuống dòng');
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('vi');
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

  testWidgets('B1/B4 — biểu đồ tháng ghi đủ số ngày, ô tóm tắt không rớt chữ "đ"', (tester) async {
    await _pumpReport(tester);
    await _switchPeriod(tester, find.text('Tháng này').first);
    expect(tester.takeException(), isNull);

    // Trước đây cột ~8dp cắt "01/11" còn "0": nay ghi số ngày, tràn ra hai bên cột.
    for (final d in ['17', '25', '30']) {
      expect(find.text(d), findsOneWidget, reason: 'thiếu nhãn ngày $d');
      expect(_cut(tester, find.text(d)), isFalse, reason: 'nhãn ngày $d bị cắt');
    }
    expect(find.textContaining('Tổng doanh thu tháng này'), findsOneWidget);
    _oneLine(tester, find.text('7.248.000 đ'));
  });

  testWidgets('B1 — biểu đồ giờ hôm qua: "23h" đủ chữ, bỏ "22h" dính sát', (tester) async {
    await _pumpReport(tester);
    await _switchPeriod(tester, find.byIcon(Icons.chevron_left_rounded).first);
    expect(tester.takeException(), isNull);
    for (final h in ['7h', '12h', '17h', '23h']) {
      expect(find.text(h), findsOneWidget, reason: 'thiếu nhãn $h');
      expect(_cut(tester, find.text(h)), isFalse, reason: 'nhãn $h bị cắt');
    }
    expect(find.text('22h'), findsNothing);
  });

  testWidgets('B2 — thanh màu top món dài theo doanh thu, khớp thứ hạng', (tester) async {
    await _pumpReport(tester);
    await tester.tap(find.text('Sản phẩm'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    final bars = tester
        .widgetList<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .map((b) => b.value)
        .whereType<double>()
        .toList();
    expect(bars, hasLength(4));
    for (var i = 1; i < bars.length; i++) {
      expect(bars[i], lessThan(bars[i - 1]), reason: 'thanh #${i + 1} dài hơn thanh #$i');
    }
    expect(bars[1], closeTo(725000 / 847000, 0.001));
  });

  testWidgets('B4 — bảng Tài chính: cột "%", tiền và phần trăm một dòng, một kiểu "100,0%"',
      (tester) async {
    await _pumpReport(tester);
    await tester.tap(find.text('Tài chính'));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('Tỷ trọng'), findsNothing);
    _oneLine(tester, find.text('3.481.000 đ'));
    _oneLine(tester, find.text('100,0%'));
    expect(find.textContaining('0.0%'), findsNothing);
  });

  testWidgets('A1 — mở Thu Chi luôn về "Hôm nay" dù Báo cáo đã đổi sang hôm qua', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(overrides: [
      financeRecordsProvider.overrideWith((ref) => Stream.value(const <FinanceRecordModel>[])),
      financeStatsProvider.overrideWith((ref) async => FinanceStats.empty),
      todayFinanceStatsProvider.overrideWith((ref) async => FinanceStats.empty),
    ]);
    addTearDown(container.dispose);
    container.read(periodProvider.notifier).setYesterday(); // như Báo cáo › Tài chính lùi ngày giùm

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: Scaffold(body: FinanceScreen())),
    ));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    final cur = container.read(periodProvider);
    expect(cur.label, 'Hôm nay');
    expect(cur.from, DateRange.today().from);
    expect(find.textContaining('Đang xem: Hôm nay'), findsOneWidget);
  });

  testWidgets('B5 — Thiết kế mẫu in 360dp: đủ 3 chế độ, không bị khuất sau nút Lưu', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: DesignerShell(
          accent: Colors.indigo,
          config: const Text('cấu hình'),
          preview: const Text('bản xem trước'),
          presets: const Text('các mẫu'),
          actions: [
            IconButton(onPressed: () {}, icon: const Icon(Icons.history_rounded)),
            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.save_rounded), label: const Text('Lưu')),
          ],
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final save = tester.getRect(find.byIcon(Icons.history_rounded)).left;
    for (final m in ['Mẫu dựng sẵn', 'Xem trước']) {
      expect(tester.getRect(find.byTooltip(m)).right, lessThanOrEqualTo(save), reason: '"$m" bị khuất');
    }
    expect(find.text('Thiết kế'), findsOneWidget);

    await tester.tap(find.byTooltip('Xem trước'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('bản xem trước'), findsOneWidget);
    expect(find.text('Xem trước'), findsOneWidget); // chế độ đang chọn hiện đủ tên
  });
}
