// Quán đã dùng "Máy In & Luật In" (31/10/2026): Cấu Hình Trạm In ẩn 4 trạm, trang In Hoá Đơn
// báo đang in theo cách nào, phụ đề thẻ không bị cắt "…" ở màn 360dp, mỗi máy in có nút In thử.
// Quán chưa có luật giữ nguyên 4 trạm; chỉ mở màn thì không ghi cài đặt.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:quannho_pos/core/providers/permission_provider.dart';
import 'package:quannho_pos/modules/bill_printer/drivers/sunmi_builtin_driver.dart';
import 'package:quannho_pos/modules/bill_printer/models/bill_block_template.dart';
import 'package:quannho_pos/modules/bill_printer/providers/bar_label_template_provider.dart';
import 'package:quannho_pos/modules/bill_printer/providers/bill_template_provider.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/routing/print_setup.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_printer_hub.dart';
import 'package:quannho_pos/modules/bill_printer/screens/print_rules_screen.dart';
import 'package:quannho_pos/modules/bill_printer/screens/printer_settings_screen.dart';

class _FakePrinters extends PrinterSettingsNotifier {
  _FakePrinters(this.initial);
  final StationPrintersState initial;
  int writes = 0;

  @override
  StationPrintersState build() => initial;

  @override
  Future<void> saveConfig(String station, PrinterConfig config) async => writes++;

  @override
  Future<void> savePrintSetup(PrintSetup setup) async => writes++;

  @override
  Future<void> toggleAutoPrint({
    bool? checkout,
    bool? kitchen,
    bool? openDrawer,
    bool? printServer,
  }) async => writes++;
}

class _FakeTpl extends BillTemplateNotifier {
  @override
  Future<BillBlockTemplate> build() async => const BillBlockTemplate(blocks: []);
}

class _FakeLabel extends BarLabelTemplateNotifier {
  @override
  BarLabelTemplate build() => const BarLabelTemplate();
}

const _legacy = StationPrintersState(
  cashier: PrinterConfig(name: 'XP-80C', type: 'system', enabled: true),
  bepNong: PrinterConfig(name: '', type: 'system'),
  bepBar: PrinterConfig(name: '', type: 'system'),
  barLabel: PrinterConfig(name: '', type: 'system'),
);

const _bill = PrinterEntry(id: 'p1', name: 'Bill quầy', kind: PrinterKind.system, address: 'XP-80C');
const _bep = PrinterEntry(id: 'p2', name: 'Bếp nóng', kind: PrinterKind.lan, address: '192.168.1.50');

StationPrintersState _withSetup(PrintSetup s) => StationPrintersState(
      cashier: _legacy.cashier,
      bepNong: _legacy.bepNong,
      bepBar: _legacy.bepBar,
      barLabel: _legacy.barLabel,
      printSetup: s,
    );

late _FakePrinters _fake;

Future<void> _open(
  WidgetTester tester,
  Widget screen,
  StationPrintersState st, {
  Size size = const Size(360, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      printerSettingsProvider.overrideWith(() => _fake = _FakePrinters(st)),
      billTemplateProvider.overrideWith(_FakeTpl.new),
      barLabelTemplateProvider.overrideWith(_FakeLabel.new),
      systemPrintersProvider.overrideWith((ref) async => <Printer>[]),
      userActionPermsProvider.overrideWith((ref) async => <String>{}),
    ],
    child: MaterialApp(home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Phông thật (như boom_chat_test) để kiểm tra cắt "…" đo đúng độ rộng chữ.
    const files = {
      'regular': 'Regular',
      '400': 'Regular',
      '500': 'Medium',
      '600': 'SemiBold',
      '700': 'Bold',
      '800': 'ExtraBold',
    };
    Future<void> load(String family, String path) async {
      final data = File(path).readAsBytesSync();
      await (FontLoader(family)..addFont(Future.value(ByteData.view(data.buffer)))).load();
    }

    for (final e in files.entries) {
      await load('PlusJakartaSans_${e.key}', 'test/fonts/PlusJakartaSans-${e.value}.ttf');
    }
    // Chữ không đặt phông riêng dùng Roboto như máy Android thật (phông giả của test rộng gấp đôi).
    await load('Roboto', 'test/Roboto-Regular.ttf');
  });

  group('Cấu Hình Trạm In', () {
    testWidgets('quán chưa có luật: giữ nguyên 4 trạm', (tester) async {
      await _open(tester, const PrinterSettingsScreen(), _legacy);
      expect(find.text('Cấu Hình Máy In & Tem Dán Ly'), findsOneWidget);
      expect(find.text('1. Thu ngân'), findsOneWidget);
      expect(find.text('4. Tem dán ly'), findsOneWidget);
      expect(find.textContaining('Máy In & Luật In'), findsNothing);
      expect(_fake.writes, 0);
    });

    testWidgets('quán chưa có luật, màn rộng: vẫn bố cục 2 cột có Trạm In Hệ Thống', (tester) async {
      await _open(tester, const PrinterSettingsScreen(), _legacy, size: const Size(1280, 900));
      expect(find.text('Trạm In Hệ Thống'), findsOneWidget);
      expect(find.text('4. Tem dán ly'), findsOneWidget);
      expect(_fake.writes, 0);
    });

    for (final size in const [Size(360, 800), Size(1280, 800)]) {
      testWidgets('quán dùng luật (${size.width.toInt()}dp): ẩn 4 trạm, còn công tắc và máy chủ in',
          (tester) async {
        await _open(tester, const PrinterSettingsScreen(),
            _withSetup(const PrintSetup(printers: [_bill])), size: size);
        expect(find.text('Tự Động In & Máy Chủ In'), findsOneWidget);
        expect(find.textContaining('chỉ còn: tự động in, tự mở két và máy chủ in'), findsOneWidget);
        for (final t in ['1. Thu ngân', '4. Tem dán ly', 'Trạm In Hệ Thống', 'Các trạm in cấu hình:']) {
          expect(find.text(t), findsNothing, reason: t);
        }
        expect(find.byType(SwitchListTile), findsNWidgets(3));
        expect(find.text('Định tuyến máy chủ in'), findsOneWidget);
        expect(_fake.writes, 0, reason: 'chỉ mở màn thì không được ghi cài đặt');
      });
    }
  });

  group('Trang In Hoá Đơn', () {
    void expectNoEllipsis(WidgetTester tester, List<String> texts) {
      for (final t in texts) {
        expect(tester.renderObject<RenderParagraph>(find.text(t)).didExceedMaxLines, isFalse,
            reason: 'bị cắt "…" ở 360dp: $t');
      }
    }

    const titles = ['Cấu Hình Trạm In', 'Máy In & Luật In', 'Thiết Kế Mẫu In'];

    testWidgets('chưa có luật: báo in theo 4 trạm, Thiết Kế Mẫu In ở cuối, chữ không bị cắt',
        (tester) async {
      await _open(tester, const BillPrinterHub(), _legacy);
      expect(find.text('Đang in theo: 4 trạm (Cấu Hình Trạm In)'), findsOneWidget);
      expect(find.textContaining('KHÔNG phiếu nào được in'), findsNothing);
      expect(find.text('Đặt lại mẫu hoá đơn'), findsOneWidget);
      final pos = [for (final t in titles) tester.getTopLeft(find.text(t))];
      expect(pos[1].dy, pos[0].dy);
      expect(pos[1].dx, greaterThan(pos[0].dx));
      expect(pos[2].dy, greaterThan(pos[0].dy), reason: 'Thiết Kế Mẫu In phải ở cuối');
      expectNoEllipsis(tester, [
        ...titles,
        'Kết nối máy in Thu ngân, Bếp nóng, Bếp bar...',
        'Nâng cao: máy in, luật in theo loại phiếu',
        'Hoá đơn, phiếu bếp, bar, tem dán ly',
      ]);
    });

    testWidgets('máy Sunmi, quán chưa chọn máy in bill: báo bill ra máy in liền thân',
        (tester) async {
      SunmiBuiltinDriver.hasBuiltinPrinter = true;
      addTearDown(() => SunmiBuiltinDriver.hasBuiltinPrinter = false);
      const fresh = StationPrintersState(
        cashier: PrinterConfig(name: '', type: 'system', enabled: true),
        bepNong: PrinterConfig(name: '', type: 'system'),
        bepBar: PrinterConfig(name: '', type: 'system'),
        barLabel: PrinterConfig(name: '', type: 'system'),
      );
      await _open(tester, const BillPrinterHub(), fresh);
      expect(find.textContaining('máy in liền thân của máy Sunmi này'), findsOneWidget);
      expectNoEllipsis(tester, ['Đang in theo: 4 trạm (Cấu Hình Trạm In)']);
    });

    testWidgets('có máy in mà chưa có luật: báo đỏ không phiếu nào in', (tester) async {
      await _open(tester, const BillPrinterHub(), _withSetup(const PrintSetup(printers: [_bill])));
      expect(find.text('Đang in theo: Máy In & Luật In – 1 máy in, 0 luật'), findsOneWidget);
      expect(find.textContaining('KHÔNG phiếu nào được in'), findsOneWidget);
      expectNoEllipsis(tester, ['Tự động in, mở két và máy chủ in']);
    });

    testWidgets('luật có máy chính tắt nhưng máy dự phòng bật: không báo đỏ', (tester) async {
      const off = PrinterEntry(id: 'p1', name: 'Bill quầy', kind: PrinterKind.system, address: 'XP-80C', enabled: false);
      await _open(
          tester,
          const BillPrinterHub(),
          _withSetup(const PrintSetup(printers: [off, _bep], rules: [
            PrintRule(
              id: 'r1',
              name: '',
              jobType: PrintJobType.receipt,
              targets: [PrintTarget(printerId: 'p1')],
              fallbackPrinterId: 'p2',
            ),
          ])));
      expect(find.text('Đang in theo: Máy In & Luật In – 2 máy in, 1 luật'), findsOneWidget);
      expect(find.textContaining('KHÔNG phiếu nào được in'), findsNothing);
    });

    testWidgets('luật chỉ trỏ tới máy in đang tắt: báo đỏ', (tester) async {
      const off = PrinterEntry(id: 'p1', name: 'Bill quầy', kind: PrinterKind.system, address: 'XP-80C', enabled: false);
      await _open(
          tester,
          const BillPrinterHub(),
          _withSetup(const PrintSetup(printers: [off], rules: [
            PrintRule(id: 'r1', name: '', jobType: PrintJobType.receipt, targets: [PrintTarget(printerId: 'p1')]),
          ])));
      expect(find.textContaining('KHÔNG phiếu nào được in'), findsOneWidget);
    });
  });

  group('Máy In & Luật In', () {
    for (final size in const [Size(360, 2400), Size(1280, 2400)]) {
      testWidgets(
          '(${size.width.toInt()}dp) mỗi máy in có nút In thử; gợi ý tên máy in hệ thống đúng, không tràn',
          (tester) async {
        await _open(tester, const PrintRulesScreen(), _withSetup(const PrintSetup(printers: [_bill, _bep])),
            size: size);
        expect(find.text('In thử'), findsNWidgets(2));
        await tester.tap(find.text('Thêm máy in'));
        await tester.pumpAndSettle();
        expect(find.text('Tên máy in trong hệ thống'), findsOneWidget);
        const hint = 'Gõ đúng tên máy in như trong Windows/Mac. Để trống sẽ không in được.';
        expect(tester.renderObject<RenderParagraph>(find.text(hint)).didExceedMaxLines, isFalse);
        expect(find.textContaining('để trống = máy in mặc định'), findsNothing);
        expect(_fake.writes, 0);
      });
    }
  });
}
