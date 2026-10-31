import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/providers/permission_provider.dart';
import 'package:quannho_pos/core/repositories/bill_history_repository.dart';
import 'package:quannho_pos/modules/bill_printer/services/bill_reprint_service.dart';
import 'package:quannho_pos/screens/bill_lookup_section.dart';

BillHistoryEntry _bill(String id, String desc, double amount, int hour) =>
    BillHistoryEntry(
      financeId: 'f-$id',
      referenceId: 'r-$id',
      description: desc,
      amount: amount,
      recordedAt: DateTime(2026, 10, 22, hour, 5),
    );

final _bills = [
  _bill('1', 'Bán hàng #QN-20261022-005', 45000, 9),
  _bill('2', 'Thanh toán bàn Bàn 3', 128000, 11),
  _bill('3', 'Bán hàng #QN-20261022-012', 30000, 14),
];

class _FakeRepo extends BillHistoryRepository {
  final List<BillHistoryEntry> bills;
  _FakeRepo(this.bills);
  @override
  Future<List<BillHistoryEntry>> listBills(
    int fromMs,
    int toMs, {
    int limit = 500,
  }) async => bills;
}

class _FakeReprint implements BillReprintService {
  final calls = <String>[];
  ReprintOutcome outcome = ReprintOutcome.printed;
  @override
  Future<ReprintOutcome> reprint(BillHistoryEntry entry) async {
    calls.add(entry.referenceId);
    return outcome;
  }
}

Future<_FakeReprint> _pump(
  WidgetTester tester, {
  required Set<String> perms,
}) async {
  final fake = _FakeReprint();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        billHistoryRepositoryProvider.overrideWithValue(_FakeRepo(_bills)),
        billReprintServiceProvider.overrideWithValue(fake),
        userActionPermsProvider.overrideWith((ref) async => perms),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: BillLookupSection(fromMs: 0, toMs: 1),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  group('filterBills', () {
    test('rỗng → giữ nguyên', () {
      expect(filterBills(_bills, '  '), hasLength(3));
    });
    test('khớp số đơn, không phân biệt hoa thường', () {
      final r = filterBills(_bills, 'qn-20261022-012');
      expect(r.single.referenceId, 'r-3');
    });
    test(
      'khớp tên bàn, có dấu hoặc không dấu; số trong chữ không khớp số tiền',
      () {
        expect(filterBills(_bills, 'bàn 3').single.referenceId, 'r-2');
        expect(filterBills(_bills, 'ban 3').single.referenceId, 'r-2');
      },
    );
    test('khớp số tiền có dấu chấm', () {
      expect(filterBills(_bills, '128.000').single.referenceId, 'r-2');
    });
  });

  test('orderNumber chỉ có ở bill bán quầy', () {
    expect(_bills[0].orderNumber, 'QN-20261022-005');
    expect(_bills[1].orderNumber, isNull);
  });

  group('buildReprintBill', () {
    final paidAt = DateTime(2026, 10, 20, 19, 30);
    test(
      'bill bàn: có phụ phí, giảm giá suy từ tổng máy chủ, giữ giờ thanh toán gốc',
      () {
        final src = ReprintSource(
          orderNumber: 'QN-20261020-001 + QN-20261020-002',
          paidAt: paidAt,
          tableName: 'Bàn 3',
          lines: const [
            ReprintLine('Trà sữa', 2, 30000),
            ReprintLine('Bánh', 1, 20000),
          ],
          subtotal: 80000,
          surcharge: 10000,
          total: 75000,
          paymentMethod: 'cash',
        );
        final bill = buildReprintBill(src, shopName: 'Quán KAY', shopPhone: '');
        expect(
          bill.orderNumber,
          'QN-20261020-001 + QN-20261020-002 · $kReprintMarker',
        );
        expect(bill.createdAt, paidAt);
        expect(bill.tableName, 'Bàn 3');
        expect(bill.items.map((i) => i.name), [
          'Trà sữa',
          'Bánh',
          'Phí dịch vụ / Ship',
        ]);
        expect(bill.discount, 15000);
        expect(bill.total, 75000);
        expect(bill.shopPhone, isNull);
      },
    );
    test('không giảm giá → discount 0, không thêm dòng phụ phí', () {
      final src = ReprintSource(
        orderNumber: 'QN-1',
        paidAt: paidAt,
        lines: const [ReprintLine('Cà phê', 1, 25000)],
        subtotal: 25000,
        total: 25000,
      );
      final bill = buildReprintBill(src, shopName: 'Q');
      expect(bill.discount, 0);
      expect(bill.items, hasLength(1));
      expect(bill.orderNumber.endsWith(kReprintMarker), isTrue);
    });
  });

  testWidgets('hiện danh sách, lọc theo ô tìm kiếm', (tester) async {
    await _pump(tester, perms: {kReprintAction});
    expect(find.text('3 bill'), findsOneWidget);
    expect(find.text('Thanh toán bàn Bàn 3'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'QN-20261022-005');
    await tester.pumpAndSettle();
    expect(find.text('1 bill'), findsOneWidget);
    expect(find.text('Thanh toán bàn Bàn 3'), findsNothing);
  });

  testWidgets('in lại: hỏi xác nhận rồi gọi dịch vụ in', (tester) async {
    final fake = await _pump(tester, perms: {kReprintAction});
    await tester.tap(find.byTooltip('In lại').at(1));
    await tester.pumpAndSettle();
    expect(find.text('In lại bill?'), findsOneWidget);

    await tester.tap(find.text('Huỷ'));
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty);

    await tester.tap(find.byTooltip('In lại').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'In lại'));
    await tester.pumpAndSettle();
    expect(fake.calls, ['r-2']);
    expect(find.text('Đã in lại bill'), findsOneWidget);
  });

  testWidgets('máy chưa cài máy in → báo cách cài', (tester) async {
    final fake = await _pump(tester, perms: {kReprintAction});
    fake.outcome = ReprintOutcome.notConfigured;
    await tester.tap(find.byTooltip('In lại').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'In lại'));
    await tester.pumpAndSettle();
    expect(find.textContaining('chưa được cài máy in hóa đơn'), findsOneWidget);
  });

  testWidgets('không có quyền → chặn, không gọi in', (tester) async {
    final fake = await _pump(tester, perms: const {});
    await tester.tap(find.byTooltip('In lại').first);
    await tester.pumpAndSettle();
    expect(find.text('In lại bill?'), findsNothing);
    expect(find.text('Bạn không có quyền in lại bill'), findsOneWidget);
    expect(fake.calls, isEmpty);
  });
}
