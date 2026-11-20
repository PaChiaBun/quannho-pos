// Kiểm Sunmi Bò Đen đợt 5 (03/11/2026, bản 24, đọc-chỉ): thẻ món Bán hàng tách cỡ món ra khỏi tên (F1),
// Quay lại khi đang mở ngăn kéo chỉ đóng ngăn kéo (F2), thẻ Hóa đơn mở sẵn ở ngày hôm qua (F3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:quannho_pos/core/providers/permission_provider.dart';
import 'package:quannho_pos/core/repositories/bill_history_repository.dart';
import 'package:quannho_pos/core/utils/string_utils.dart';
import 'package:quannho_pos/main.dart' show closeInnerPopup;
import 'package:quannho_pos/modules/bill_printer/services/bill_reprint_service.dart';
import 'package:quannho_pos/screens/einvoice_report_tab.dart';

/// Ghi lại khoảng ngày mỗi lần tải bill.
class _RangeRepo extends BillHistoryRepository {
  final ranges = <(int, int)>[];
  @override
  Future<List<BillHistoryEntry>> listBills(int fromMs, int toMs, {int limit = 500}) async {
    ranges.add((fromMs, toMs));
    return const [];
  }
}

class _NoReprint implements BillReprintService {
  @override
  Future<ReprintOutcome> reprint(BillHistoryEntry entry) async => ReprintOutcome.printed;
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('vi');
  });

  test('F1 — tách phần trong ngoặc cuối tên món để hiện riêng cạnh giá', () {
    expect(splitNameVariant('Cá Viên Chiên Sốt Me [ phần nhỏ ]'),
        (base: 'Cá Viên Chiên Sốt Me', variant: 'phần nhỏ'));
    expect(splitNameVariant('Trà Sữa Hong Kong Truyền Thống (Đá/Nóng)'),
        (base: 'Trà Sữa Hong Kong Truyền Thống', variant: 'Đá/Nóng'));
    expect(splitNameVariant('Trà Tắc Cửu Long'), (base: 'Trà Tắc Cửu Long', variant: null));
    expect(splitNameVariant('(Combo)').variant, isNull); // cả tên trong ngoặc: giữ nguyên
    expect(splitNameVariant('Trà [ ]').variant, isNull);
    expect(splitNameVariant('Trà (size (L))').variant, isNull); // ngoặc lồng: giữ nguyên
  });

  testWidgets('F2 — Quay lại khi đang mở ngăn kéo (thống kê Phiếu bếp): chỉ đóng ngăn kéo', (tester) async {
    var wentHome = 0;
    // Như MainShell: PopScope chặn quay lại, tự về Trang chủ khi không có gì để đóng.
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop || closeInnerPopup(ctx)) return;
            wentHome++;
          },
          child: Scaffold(
            drawer: const Drawer(child: Text('Bếp hôm nay')),
            body: Builder(
              builder: (c) => TextButton(
                onPressed: () => Scaffold.of(c).openDrawer(),
                child: const Text('Mở thống kê'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Mở thống kê'));
    await tester.pumpAndSettle();
    expect(find.text('Bếp hôm nay'), findsOneWidget);

    await tester.binding.handlePopRoute(); // nút Quay lại Android
    await tester.pumpAndSettle();
    expect(find.text('Bếp hôm nay'), findsNothing);
    expect(wentHome, 0); // trước: văng về Trang chủ, ngăn kéo vẫn mở

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(wentHome, 1); // không còn gì để đóng thì mới về Trang chủ
  });

  testWidgets('F3 — thẻ Hóa đơn mở sẵn ở hôm qua: tải bill đúng ngày hôm qua', (tester) async {
    final repo = _RangeRepo();
    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        billHistoryRepositoryProvider.overrideWithValue(repo),
        billReprintServiceProvider.overrideWithValue(_NoReprint()),
        userActionPermsProvider.overrideWith((ref) async => <String>{}),
      ],
      child: MaterialApp(home: Scaffold(body: EinvoiceReportTab(initialDay: yesterday))),
    ));
    await tester.pumpAndSettle();
    final today = DateTime(now.year, now.month, now.day);
    expect(repo.ranges.last, (yesterday.millisecondsSinceEpoch, today.millisecondsSinceEpoch));
    expect(find.text('Hôm qua'), findsOneWidget);
  });
}
