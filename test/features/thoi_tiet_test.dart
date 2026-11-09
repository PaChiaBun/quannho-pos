import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/thoi_tiet/thoi_tiet_provider.dart';
import 'package:quannho_pos/features/thoi_tiet/thoi_tiet_widgets.dart';

class _CoDinh extends ThoiTietNotifier {
  final ThoiTietData? v;
  _CoDinh(this.v);
  @override
  Future<ThoiTietData?> build() async => v;
}

Future<void> _ve(WidgetTester t, ThoiTietData? v) async {
  // khoá mới mỗi lần: Riverpod không áp lại override khi dựng lại cùng một ProviderScope
  await t.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [thoiTietProvider.overrideWith(() => _CoDinh(v))],
      child: const MaterialApp(
        home: Scaffold(body: Center(child: ThoiTietThe())),
      ),
    ),
  );
  await t.pump();
}

void main() {
  test('đọc phòng thủ: sai kiểu thì bỏ, không lỗi', () {
    final d = ThoiTietData.fromJson({
      'bat': true,
      'vi_tri': {'lat': 10.8, 'lon': 106.7, 'ten': 'Quận 1'},
      'thoi_tiet': {
        'luc': '2026-11-07T07:00:00.000Z',
        'nhiet': 31.6,
        'troi': 'mây rải rác',
        'gio': [
          {'gio': 14, 'nhiet': 31, 'mua': 20, 'troi': 'mây rải rác'},
          {'gio': 16, 'nhiet': 28, 'mua': 70, 'troi': 'dông'},
          {'gio': 'x'},
        ],
        'ngay': [
          {
            'ngay': '2026-11-07',
            'cao': 33,
            'thap': 26,
            'mua': 60,
            'troi': 'dông',
          },
          {'ngay': 'khong'},
        ],
      },
      'nguon': {
        'ten': 'Apple Weather',
        'link': 'javascript:alert(1)',
        'logo_sang': 'http://x',
      },
    });
    expect(d.viTri!.ten, 'Quận 1');
    expect(d.gio.length, 2);
    expect(d.ngay.length, 1);
    expect(d.muaSapToi!.gio, 16);
    expect(d.nguonLink, startsWith('https://developer.apple.com/'));
    expect(d.logoSang, isNull);
    expect(ThoiTietData.fromJson({'bat': 'co'}).bat, isFalse);
  });

  test('3 tiếng hoặc sang ngày mới thì lấy lại', () {
    final luc = DateTime(2026, 11, 7, 14);
    expect(thoiTietDaCu(luc, DateTime(2026, 11, 7, 16, 59)), isFalse);
    expect(thoiTietDaCu(luc, DateTime(2026, 11, 7, 17)), isTrue);
    expect(
      thoiTietDaCu(DateTime(2026, 11, 7, 23), DateTime(2026, 11, 8, 0, 30)),
      isTrue,
    );
  });

  testWidgets('thẻ: ẩn khi chưa bật, hiện nhiệt độ và giờ mưa', (t) async {
    await _ve(t, null);
    expect(find.byType(InkWell), findsNothing);
    await _ve(t, const ThoiTietData(bat: false));
    expect(find.byType(InkWell), findsNothing);
    await _ve(t, const ThoiTietData(bat: true));
    expect(
      find.textContaining('Chọn khu vực', findRichText: true),
      findsOneWidget,
    );
    await _ve(
      t,
      const ThoiTietData(
        bat: true,
        viTri: ViTriThoiTiet(10.8, 106.7, 'Quận 1'),
      ),
    );
    expect(
      find.byType(InkWell),
      findsNothing,
      reason: 'có khu vực nhưng chưa có số thì ẩn',
    );
    await _ve(
      t,
      const ThoiTietData(
        bat: true,
        viTri: ViTriThoiTiet(10.8, 106.7, 'Quận 1'),
        nhiet: 31.6,
        troi: 'mây rải rác',
        gio: [GioThoiTiet(16, 28, 70, 'dông')],
      ),
    );
    expect(find.textContaining('32°', findRichText: true), findsOneWidget);
    expect(
      find.textContaining('Sắp mưa ~16h', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets(
    'màn chi tiết: điện thoại và máy tính không tràn chữ, có ghi nguồn',
    (t) async {
      final v = ThoiTietData(
        bat: true,
        viTri: const ViTriThoiTiet(10.8, 106.7, 'TP. Hồ Chí Minh'),
        nhiet: 31.6,
        troi: 'mây rải rác',
        gio: [
          for (var i = 0; i < 12; i++)
            GioThoiTiet(
              (14 + i) % 24,
              30.0 - i,
              i * 8,
              i.isEven ? 'mưa' : 'nhiều mây',
            ),
        ],
        ngay: [
          for (var i = 0; i < 7; i++)
            NgayThoiTiet(DateTime(2026, 11, 7 + i), 33, 26, 60, 'dông'),
        ],
        luc: DateTime(2026, 11, 7, 14, 5),
      );
      for (final size in [const Size(360, 740), const Size(1280, 800)]) {
        await t.binding.setSurfaceSize(size);
        await t.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [thoiTietProvider.overrideWith(() => _CoDinh(v))],
            child: const MaterialApp(home: ThoiTietScreen()),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // 09/11: tiêu đề 2 dòng (tên khu vực dưới chữ Thời tiết, không bị nút Đổi khu vực cắt)
        expect(find.text('Thời tiết'), findsOneWidget);
        expect(find.text('TP. Hồ Chí Minh'), findsOneWidget);
        expect(find.text('Hôm nay'), findsOneWidget);
        // ghi nguồn ở cuối danh sách: cuộn tới mới được dựng
        await t.scrollUntilVisible(
          find.text('Nguồn dữ liệu'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(t.takeException(), isNull);
        expect(find.text('Apple Weather'), findsOneWidget);
        expect(find.text('Nguồn dữ liệu'), findsOneWidget);
        expect(find.text('Hỏi Bé Boom'), findsOneWidget);
      }
      await t.binding.setSurfaceSize(null);
    },
  );

  test(
    '09/11 giờ cả tuần: đọc theo ngày; máy chủ cũ thì hôm nay dùng 12 giờ tới',
    () {
      final d = ThoiTietData.fromJson({
        'bat': true,
        'thoi_tiet': {
          'gio': [
            {'gio': 14, 'nhiet': 31, 'mua': 20, 'troi': 'mây rải rác'},
          ],
          'ngay': [
            {'ngay': '2026-11-09', 'cao': 34},
            {'ngay': '2026-11-10', 'cao': 33},
          ],
          'gio_tuan': [
            {'ngay': '2026-11-10', 'gio': 15, 'nhiet': 30, 'mua': 70},
            {'ngay': '2026-11-10', 'gio': 'x'},
            {'ngay': 'khong', 'gio': 3},
          ],
        },
      });
      expect(d.gioTuan.length, 1);
      expect(d.gioCuaNgay(DateTime(2026, 11, 10)).single.mua, 70);
      expect(
        d.gioCuaNgay(DateTime(2026, 11, 9)).single.gio,
        14,
        reason: 'chưa có giờ tuần cho hôm nay → 12 giờ tới',
      );
      expect(d.gioCuaNgay(DateTime(2026, 11, 11)), isEmpty);
    },
  );

  test('09/11 câu tóm tắt ngày: khung giờ mưa, giờ nóng nhất, bỏ giờ đêm', () {
    expect(
      tomTatNgay([
        const GioThoiTiet(3, 25, 90, 'mưa'),
        const GioThoiTiet(13, 34, 10, ''),
        const GioThoiTiet(15, 31, 55, 'mưa'),
        const GioThoiTiet(16, 30, 80, 'dông'),
        const GioThoiTiet(17, 29, 45, 'mưa'),
      ]),
      'Dễ mưa 15–18h, cao nhất 80% lúc 16h; nóng nhất 34° lúc 13h.',
    );
    expect(
      tomTatNgay([
        const GioThoiTiet(12, 33, 6, ''),
        const GioThoiTiet(15, 32, 31, ''),
        const GioThoiTiet(16, 31, 38, ''),
        const GioThoiTiet(17, 30, 29, ''),
        const GioThoiTiet(19, 28, 12, ''),
      ]),
      'Nếu mưa thường rơi 15–18h (mỗi giờ tối đa 38%); nóng nhất 33° lúc 12h.',
    );
    expect(
      tomTatNgay([const GioThoiTiet(10, 33, 5, '')]),
      'Ít khả năng mưa trong giờ buôn bán; nóng nhất 33° lúc 10h.',
    );
    expect(tomTatNgay(const []), 'Chưa có dự báo theo giờ cho ngày này.');
  });

  testWidgets('09/11 bấm một ngày: mở xem theo giờ, vuốt đổi ngày', (t) async {
    final v = ThoiTietData(
      bat: true,
      viTri: const ViTriThoiTiet(10.8, 106.7, 'TP. Hồ Chí Minh'),
      nhiet: 31,
      troi: 'nhiều mây',
      ngay: [
        for (var i = 0; i < 7; i++)
          NgayThoiTiet(DateTime(2026, 11, 9 + i), 33, 25, 60, 'mưa'),
      ],
      gioTuan: [
        for (var i = 0; i < 7; i++)
          for (var g = 0; g < 24; g++)
            GioThoiTiet(
              g,
              25.0 + (g > 12 ? 24 - g : g) / 2,
              g == 16 ? 80 : 10,
              '',
              ngay: DateTime(2026, 11, 9 + i),
            ),
      ],
    );
    for (final size in [const Size(360, 740), const Size(1280, 800)]) {
      await t.binding.setSurfaceSize(size);
      await t.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [thoiTietProvider.overrideWith(() => _CoDinh(v))],
          child: const MaterialApp(home: ThoiTietScreen()),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('T3'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await t.tap(find.text('T3'));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      expect(find.text('Thứ Ba, 10/11'), findsOneWidget);
      expect(find.text('Chiều'), findsOneWidget);
      expect(find.text('Tối'), findsOneWidget);
      expect(
        find.text('Dễ mưa khoảng 16h (80%); nóng nhất 31° lúc 12h.'),
        findsOneWidget,
      );
      await t.fling(find.text('Thứ Ba, 10/11'), const Offset(-300, 0), 1500);
      await t.pumpAndSettle();
      expect(find.text('Thứ Tư, 11/11'), findsOneWidget);
    }
    await t.binding.setSurfaceSize(null);
  });

  testWidgets('09/11 dòng Hỏi Boom ở Trang chủ: chỉ hiện khi có cảnh báo', (
    t,
  ) async {
    Future<void> ve(ThoiTietData v) => t.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [thoiTietProvider.overrideWith(() => _CoDinh(v))],
        child: const MaterialApp(home: Scaffold(body: ThoiTietHoiBoom())),
      ),
    );
    const vt = ViTriThoiTiet(10.8, 106.7, 'Quận 1');
    await ve(const ThoiTietData(bat: true, viTri: vt, nhiet: 30, troi: 'nắng'));
    await t.pump();
    expect(find.byType(InkWell), findsNothing, reason: 'trời thường thì ẩn');
    await ve(const ThoiTietData(bat: true, nhiet: 36, troi: 'nắng'));
    await t.pump();
    expect(find.byType(InkWell), findsNothing, reason: 'chưa chọn khu vực');
    await ve(
      const ThoiTietData(
        bat: true,
        viTri: vt,
        nhiet: 31,
        troi: 'mây',
        gio: [GioThoiTiet(16, 28, 70, 'dông')],
      ),
    );
    await t.pump();
    expect(
      find.textContaining(
        'Hỏi Boom: Sắp mưa ~16h, quán nên chuẩn bị gì?',
        findRichText: true,
      ),
      findsOneWidget,
    );
    expect(
      cauHoiBoomThoiTiet(
        const ThoiTietData(bat: true, viTri: vt, nhiet: 36, troi: 'nắng'),
      ),
      'Nắng nóng 36°, quán nên chuẩn bị gì?',
    );
  });
}
