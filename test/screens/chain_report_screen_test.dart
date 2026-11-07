import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/core/utils/chain_compare.dart';
import 'package:quannho_pos/screens/chain_report_screen.dart';

const _s1 = '11111111-1111-1111-1111-111111111111';
const _s2 = '22222222-2222-2222-2222-222222222222';
const _chain = 'cccccccc-cccc-cccc-cccc-cccccccccccc';

Map<String, dynamic> _list({bool withChain = true}) => {
  'success': true,
  'chains': withChain
      ? [
          {
            'id': _chain,
            'name': 'Chuoi KAY',
            'stores': [
              {'store_id': _s1, 'name': 'KAY Rach Gia', 'store_code': 'KAY1'},
              {'store_id': _s2, 'name': 'KAY Phu Quoc', 'store_code': 'KAY2'},
            ],
          },
        ]
      : [],
  'owned_stores': [
    {'store_id': _s1, 'name': 'KAY Rach Gia', 'store_code': 'KAY1', 'chain_id': withChain ? _chain : null},
    {'store_id': _s2, 'name': 'KAY Phu Quoc', 'store_code': 'KAY2', 'chain_id': withChain ? _chain : null},
  ],
};

Map<String, dynamic> _store(String id, String name, int orders, num revenue, {num cash = 0, num tr = 0, num card = 0}) => {
  'store_id': id, 'name': name, 'store_code': 'X', 'orders': orders, 'revenue': revenue,
  'avg_order_value': orders > 0 ? revenue / orders : 0, 'cash_revenue': cash, 'transfer_revenue': tr,
  'card_revenue': card, 'discount': 0,
};

Map<String, dynamic> _report(List<Map<String, dynamic>> stores, {List<Map<String, dynamic>> daily = const []}) {
  num sum(String k) => stores.fold<num>(0, (a, s) => a + (s[k] as num));
  final orders = sum('orders');
  return {
    'success': true,
    'chain': {'id': _chain, 'name': 'Chuoi KAY'},
    'stores': stores,
    'totals': {
      'orders': orders, 'revenue': sum('revenue'), 'avg_order_value': orders > 0 ? sum('revenue') / orders : 0,
      'cash_revenue': sum('cash_revenue'), 'transfer_revenue': sum('transfer_revenue'),
      'card_revenue': sum('card_revenue'), 'discount': 0, 'store_count': stores.length,
    },
    'daily': daily,
    'excluded_stores': [],
  };
}

String _today() => ymd(DateTime.now());
String _cmpDay() => ymd(windowFor(ChainPeriod.day, 0).compareFrom);

Map<String, dynamic> _pt(String date, String id, int orders, num revenue) => {'date': date, 'store_id': id, 'orders': orders, 'revenue': revenue};

// Hôm nay: Phu Quoc 40 đơn/4,0tr; Rach Gia 20 đơn/2,0tr.
Map<String, dynamic> _cur() => _report([
  _store(_s2, 'KAY Phu Quoc', 40, 4000000, cash: 1000000, tr: 3000000),
  _store(_s1, 'KAY Rach Gia', 20, 2000000, cash: 2000000),
], daily: [_pt(_today(), _s2, 40, 4000000), _pt(_today(), _s1, 20, 2000000)]);

// Cùng thứ tuần trước: Phu Quoc 20 đơn/2,0tr (→ +100%), Rach Gia 40 đơn/4,0tr (→ -50%).
Map<String, dynamic> _prevR() => _report([
  _store(_s2, 'KAY Phu Quoc', 20, 2000000),
  _store(_s1, 'KAY Rach Gia', 40, 4000000),
], daily: [_pt(_cmpDay(), _s2, 20, 2000000), _pt(_cmpDay(), _s1, 40, 4000000)]);

bool _isCurrent(Map<String, dynamic> p) {
  final w = windowFor(ChainPeriod.day, 0);
  return p['p_from'] == w.from.toUtc().toIso8601String();
}

Future<void> _pump(WidgetTester t) async {
  t.view.physicalSize = const Size(800, 3600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(home: ChainReportScreen(repository: ChainRepository())));
  await t.pumpAndSettle();
}

void main() {
  tearDown(() => ChainRepository.rpcOverride = null);

  group('ChainRepository', () {
    test('parse báo cáo và gộp doanh thu theo ngày', () async {
      ChainRepository.rpcOverride = (fn, p) async => _report(
        [_store(_s1, 'A', 1, 100)],
        daily: [
          {'date': '2026-10-02', 'store_id': _s1, 'orders': 1, 'revenue': 100},
          {'date': '2026-10-02', 'store_id': _s2, 'orders': 3, 'revenue': 300},
        ],
      );
      final r = await ChainRepository().report(_chain, DateTime(2026, 10, 1), DateTime(2026, 10, 8));
      expect(r.totals.revenue, 100);
      expect(r.dailyTotals.single.value, 400);
    });

    test('lỗi server thành ChainException có câu tiếng Việt', () async {
      ChainRepository.rpcOverride = (f, p) async => {'success': false, 'error': 'CHAIN_NOT_FOUND'};
      await expectLater(
        ChainRepository().listMine(),
        throwsA(isA<ChainException>().having((e) => e.message, 'message', contains('chủ chuỗi'))),
      );
    });

    test('phản hồi không phải Map bị coi là lỗi, không trả dữ liệu rỗng giả', () async {
      ChainRepository.rpcOverride = (f, p) async => null;
      await expectLater(ChainRepository().listMine(), throwsA(isA<ChainException>()));
    });
  });

  group('ChainReportScreen', () {
    testWidgets('hiển thị tổng, xếp hạng theo doanh thu và chip tăng/giảm khi vượt dao động', (t) async {
      ChainRepository.rpcOverride = (fn, p) async =>
          fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? _cur() : _prevR());
      await _pump(t);
      expect(find.text('Báo cáo chuỗi'), findsOneWidget);
      expect(find.text('Doanh thu chuỗi'), findsOneWidget);
      expect(find.text('Xếp hạng doanh thu'), findsOneWidget);
      final y1 = t.getTopLeft(find.text('KAY Phu Quoc').first).dy;
      final y2 = t.getTopLeft(find.text('KAY Rach Gia').first).dy;
      expect(y1 < y2, isTrue); // Phu Quoc (4,0tr) trên Rach Gia (2,0tr)
      expect(find.text('100,0%'), findsOneWidget); // Phu Quoc +100% (vượt ngưỡng 34%)
      expect(find.text('50,0%'), findsWidgets); // Rach Gia -50%
      expect(find.text('40 đơn · TB 100 k · chiếm 66,7%'), findsOneWidget);
      expect(find.text('20 đơn · TB 100 k · chiếm 33,3%'), findsOneWidget);
    });

    testWidgets('nhận xét nhanh nêu quán giảm kèm nguyên nhân và dòng giải thích ngưỡng', (t) async {
      ChainRepository.rpcOverride = (fn, p) async =>
          fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? _cur() : _prevR());
      await _pump(t);
      expect(find.text('Nhận xét nhanh'), findsOneWidget);
      expect(find.textContaining('KAY Rach Gia: doanh thu giảm 50,0% so với cùng thứ tuần trước'), findsOneWidget);
      expect(find.textContaining('chủ yếu do số đơn giảm 50,0%'), findsOneWidget);
      expect(find.textContaining('Chỉ nêu khi vượt mức dao động bình thường'), findsWidgets);
      expect(find.textContaining('KAY Phu Quoc dẫn đầu doanh thu'), findsOneWidget);
    });

    testWidgets('mẫu quá ít (vài đơn): chip "Ít dữ liệu", KHÔNG có nhận xét tăng/giảm', (t) async {
      final small = _report([_store(_s2, 'KAY Phu Quoc', 3, 300000), _store(_s1, 'KAY Rach Gia', 1, 100000)],
          daily: [_pt(_today(), _s2, 3, 300000), _pt(_today(), _s1, 1, 100000)]);
      final smallPrev = _report([_store(_s2, 'KAY Phu Quoc', 2, 200000), _store(_s1, 'KAY Rach Gia', 2, 200000)],
          daily: [_pt(_cmpDay(), _s2, 2, 200000), _pt(_cmpDay(), _s1, 2, 200000)]);
      ChainRepository.rpcOverride = (fn, p) async => fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? small : smallPrev);
      await _pump(t);
      expect(find.text('Ít dữ liệu'), findsWidgets);
      expect(find.textContaining('doanh thu giảm'), findsNothing);
      expect(find.textContaining('doanh thu tăng'), findsNothing);
    });

    testWidgets('thay đổi nhỏ trong dao động bình thường: chip có số nhưng KHÔNG có nhận xét tăng/giảm', (t) async {
      final cur = _report([_store(_s2, 'KAY Phu Quoc', 40, 4000000), _store(_s1, 'KAY Rach Gia', 40, 4000000)],
          daily: [_pt(_today(), _s2, 40, 4000000), _pt(_today(), _s1, 40, 4000000)]);
      final prev = _report([_store(_s2, 'KAY Phu Quoc', 40, 4400000), _store(_s1, 'KAY Rach Gia', 40, 3800000)],
          daily: [_pt(_cmpDay(), _s2, 40, 4400000), _pt(_cmpDay(), _s1, 40, 3800000)]);
      ChainRepository.rpcOverride = (fn, p) async => fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? cur : prev);
      await _pump(t);
      expect(find.text('9,1%'), findsWidgets); // Phu Quoc -9,1%
      expect(find.textContaining('doanh thu giảm'), findsNothing);
      expect(find.textContaining('doanh thu tăng'), findsNothing);
    });

    testWidgets('quán mới mở không bị gắn "Thấp nhất" mà hiện "Mới mở"', (t) async {
      final opened = DateTime.now().subtract(const Duration(days: 2)).toUtc().toIso8601String();
      final cur = _report([
        {..._store(_s2, 'KAY Phu Quoc', 40, 4000000), 'first_order_at': '2026-06-01T00:00:00Z'},
        {..._store(_s1, 'KAY Rach Gia', 20, 2000000), 'first_order_at': opened},
      ], daily: [_pt(_today(), _s2, 40, 4000000), _pt(_today(), _s1, 20, 2000000)]);
      final prev = _report([_store(_s2, 'KAY Phu Quoc', 40, 4000000), _store(_s1, 'KAY Rach Gia', 0, 0)],
          daily: [_pt(_cmpDay(), _s2, 40, 4000000)]);
      ChainRepository.rpcOverride = (fn, p) async => fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? cur : prev);
      await _pump(t);
      expect(find.text('Mới mở'), findsOneWidget);
      expect(find.text('Thấp nhất'), findsNothing);
      expect(find.text('Cao nhất'), findsNothing); // chỉ còn 1 quán đủ điều kiện xếp → không gắn nhãn
    });

    testWidgets('chạm chip để xem lý do (dao động bình thường / vượt ngưỡng)', (t) async {
      ChainRepository.rpcOverride = (fn, p) async =>
          fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? _cur() : _prevR());
      await _pump(t);
      final tips = t.widgetList<Tooltip>(find.byType(Tooltip)).map((w) => w.message ?? '').toList();
      expect(tips.any((m) => m.contains('vượt mức dao động bình thường') && m.contains('cùng thứ tuần trước')), isTrue);
    });

    testWidgets('lỗi riêng kỳ trước: vẫn hiển thị báo cáo, không có chip tăng trưởng', (t) async {
      ChainRepository.rpcOverride = (fn, p) async {
        if (fn == 'list_my_chains_v1') return _list();
        if (_isCurrent(p)) return _cur();
        throw Exception('timeout');
      };
      await _pump(t);
      expect(find.text('Xếp hạng doanh thu'), findsOneWidget);
      expect(find.text('Mới'), findsNothing);
      expect(find.text('Ít dữ liệu'), findsNothing);
      expect(find.text('50,0%'), findsNothing);
      expect(find.textContaining('Nhận xét nhanh'), findsOneWidget); // vẫn có nhận xét không cần kỳ trước
    });

    testWidgets('đổi chỉ số so sánh sang Số đơn', (t) async {
      ChainRepository.rpcOverride = (fn, p) async =>
          fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? _cur() : _prevR());
      await _pump(t);
      expect(find.text('So sánh theo chỉ số'), findsOneWidget);
      expect(find.text('Cao nhất'), findsOneWidget);
      await t.tap(find.text('Số đơn').last);
      await t.pumpAndSettle();
      expect(find.textContaining('Trung bình chuỗi: 30', findRichText: true), findsOneWidget); // (40+20)/2
    });

    testWidgets('cơ cấu thanh toán và chú thích hiển thị', (t) async {
      ChainRepository.rpcOverride = (fn, p) async =>
          fn == 'list_my_chains_v1' ? _list() : (_isCurrent(p) ? _cur() : _prevR());
      await _pump(t);
      expect(find.text('Cơ cấu thanh toán'), findsOneWidget);
      expect(find.text('Chuyển khoản'), findsWidgets);
    });

    testWidgets('bấm "Kỳ trước" tải lại với khoảng sớm hơn; nút "Kỳ sau" bị khóa ở kỳ hiện tại', (t) async {
      final froms = <String>[];
      ChainRepository.rpcOverride = (fn, p) async {
        if (fn == 'list_my_chains_v1') return _list();
        froms.add(p['p_from'] as String);
        return _cur;
      };
      await _pump(t);
      expect(find.text('Hôm nay'), findsWidgets);
      final before = froms.length;
      await t.tap(find.byTooltip('Kỳ sau')); // bị khóa
      await t.pumpAndSettle();
      expect(froms.length, before);
      await t.tap(find.byTooltip('Kỳ trước'));
      await t.pumpAndSettle();
      expect(froms.length, greaterThan(before));
      expect(find.text('Hôm qua'), findsOneWidget);
    });

    testWidgets('chưa có đơn: hiện trạng thái rỗng, không vẽ biểu đồ', (t) async {
      final empty = _report([_store(_s1, 'KAY Rach Gia', 0, 0), _store(_s2, 'KAY Phu Quoc', 0, 0)]);
      ChainRepository.rpcOverride = (fn, p) async => fn == 'list_my_chains_v1' ? _list() : empty;
      await _pump(t);
      expect(find.text('Chưa có đơn hoàn tất trong kỳ này'), findsOneWidget);
      expect(find.text('Xếp hạng doanh thu'), findsNothing);
    });

    testWidgets('chưa có chuỗi nhưng có 2 cửa hàng: mời tạo chuỗi', (t) async {
      ChainRepository.rpcOverride = (fn, p) async => _list(withChain: false);
      await _pump(t);
      expect(find.text('Tạo chuỗi'), findsOneWidget);
    });

    testWidgets('lỗi quyền hiện thông báo, không hiện số liệu', (t) async {
      ChainRepository.rpcOverride = (fn, p) async => {'success': false, 'error': 'UNAUTHENTICATED'};
      await _pump(t);
      expect(find.textContaining('đăng nhập lại'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });
  });
}
