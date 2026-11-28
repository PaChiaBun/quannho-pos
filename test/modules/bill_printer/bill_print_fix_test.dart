import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/src/pdf/font/ttf_parser.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:quannho_pos/modules/bill_printer/bill_print_guards.dart';
import 'package:quannho_pos/modules/bill_printer/fonts/bill_fonts.dart';
import 'package:quannho_pos/modules/bill_printer/providers/printer_settings_provider.dart';
import 'package:quannho_pos/modules/bill_printer/screens/bill_preview_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('font đi kèm app', () {
    // Các chữ từng thành ô vuông trên bill KAY (ă ạ ả ế ủ ữ ỏ ặ ỳ đ Ă Ặ Đ...).
    const viet = 'ăạảếủữỏặỳđĂẶĐờỡựềệ';

    for (final asset in [
      BillFonts.regularAsset,
      BillFonts.boldAsset,
      BillFonts.semiBoldAsset,
    ]) {
      test('$asset có đủ chữ Việt', () async {
        final data = await rootBundle.load(asset);
        final map = TtfParser(data).charToGlyphIndexMap;
        for (final r in viet.runes) {
          expect(
            map.containsKey(r),
            isTrue,
            reason: 'thiếu glyph ${String.fromCharCode(r)} trong $asset',
          );
        }
      });
    }

    test('BillFonts nạp được cả 3 kiểu từ assets (không cần mạng)', () async {
      BillFonts.resetForTest();
      expect(await BillFonts.regular(), isA<pw.Font>());
      expect(await BillFonts.bold(), isA<pw.Font>());
      expect(await BillFonts.semiBold(), isNotNull);
    });

    test('bộ nạp font mặc định của bill là bộ đi kèm app', () {
      expect(BillPdfGenerator.fontLoader, isA<BundledPdfFontLoader>());
    });
  });

  group('không dùng máy in mặc định', () {
    test(
      'tên máy in trống -> không in, trả false (không hỏi danh sách máy in)',
      () async {
        final ok = await const SystemPrintTransport().printPdf(
          Uint8List.fromList([1, 2, 3]),
          const PrinterConfig(name: '', type: 'system', enabled: true),
          'hoa_don_TEST',
        );
        expect(ok, isFalse);
      },
    );
  });

  group('BillPrintWatchdog', () {
    test('chưa in sau 30 giây -> overdue và gọi onOverdue một lần', () {
      fakeAsync((async) {
        var called = 0;
        final w = BillPrintWatchdog(onOverdue: () => called++)..start();
        async.elapse(const Duration(seconds: 29));
        expect(w.status.value, BillPrintStatus.pending);
        async.elapse(const Duration(seconds: 2));
        expect(w.status.value, BillPrintStatus.overdue);
        expect(called, 1);
        async.elapse(const Duration(minutes: 5));
        expect(called, 1);
      });
    });

    test('đã in trước hạn -> không cảnh báo', () {
      fakeAsync((async) {
        var called = 0;
        final w = BillPrintWatchdog(onOverdue: () => called++)..start();
        async.elapse(const Duration(seconds: 5));
        w.markPrinted();
        async.elapse(const Duration(minutes: 1));
        expect(w.status.value, BillPrintStatus.printed);
        expect(called, 0);
      });
    });

    test(
      'In lại: restart canh lại; in lại xong -> printed; in lại hỏng -> overdue ngay',
      () {
        fakeAsync((async) {
          final w = BillPrintWatchdog()..start();
          async.elapse(const Duration(seconds: 31));
          expect(w.status.value, BillPrintStatus.overdue);
          w.restart();
          expect(w.status.value, BillPrintStatus.pending);
          w.markPrinted();
          expect(w.status.value, BillPrintStatus.printed);
          w.restart();
          w.markOverdue();
          expect(w.status.value, BillPrintStatus.overdue);
        });
      },
    );
  });

  group('PrintClickGuard', () {
    test('15 lần bấm trong 22 giây chỉ in 1 lần khi đang in', () {
      final g = PrintClickGuard();
      var printed = 0;
      final t0 = DateTime(2026, 10, 18, 20, 47, 21);
      for (var i = 0; i < 15; i++) {
        if (g.tryStart(t0.add(Duration(seconds: i)))) printed++;
      }
      expect(printed, 1, reason: 'chưa finish() nên chỉ lần đầu được in');
    });

    test('in xong phải chờ hết thời gian chờ mới in tiếp', () {
      final g = PrintClickGuard(cooldown: const Duration(seconds: 8));
      final t0 = DateTime(2026, 10, 18, 20, 0, 0);
      expect(g.tryStart(t0), isTrue);
      g.finish(t0.add(const Duration(seconds: 2)));
      expect(g.tryStart(t0.add(const Duration(seconds: 5))), isFalse);
      expect(g.tryStart(t0.add(const Duration(seconds: 11))), isTrue);
    });
  });
}
