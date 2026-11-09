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
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [thoiTietProvider.overrideWith(() => _CoDinh(v))],
    child: const MaterialApp(home: Scaffold(body: Center(child: ThoiTietThe()))),
  ));
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
          {'ngay': '2026-11-07', 'cao': 33, 'thap': 26, 'mua': 60, 'troi': 'dông'},
          {'ngay': 'khong'},
        ],
      },
      'nguon': {'ten': 'Apple Weather', 'link': 'javascript:alert(1)', 'logo_sang': 'http://x'},
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
    expect(thoiTietDaCu(DateTime(2026, 11, 7, 23), DateTime(2026, 11, 8, 0, 30)), isTrue);
  });

  testWidgets('thẻ: ẩn khi chưa bật, hiện nhiệt độ và giờ mưa', (t) async {
    await _ve(t, null);
    expect(find.byType(InkWell), findsNothing);
    await _ve(t, const ThoiTietData(bat: false));
    expect(find.byType(InkWell), findsNothing);
    await _ve(t, const ThoiTietData(bat: true));
    expect(find.text('Chọn khu vực'), findsOneWidget);
    await _ve(t, const ThoiTietData(bat: true, viTri: ViTriThoiTiet(10.8, 106.7, 'Quận 1')));
    expect(find.byType(InkWell), findsNothing, reason: 'có khu vực nhưng chưa có số thì ẩn');
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
    expect(find.text('32°'), findsOneWidget);
    expect(find.text('Mưa ~16h'), findsOneWidget);
  });

  testWidgets('màn chi tiết: điện thoại và máy tính không tràn chữ, có ghi nguồn', (t) async {
    final v = ThoiTietData(
      bat: true,
      viTri: const ViTriThoiTiet(10.8, 106.7, 'TP. Hồ Chí Minh'),
      nhiet: 31.6,
      troi: 'mây rải rác',
      gio: [for (var i = 0; i < 12; i++) GioThoiTiet((14 + i) % 24, 30.0 - i, i * 8, i.isEven ? 'mưa' : 'nhiều mây')],
      ngay: [for (var i = 0; i < 7; i++) NgayThoiTiet(DateTime(2026, 11, 7 + i), 33, 26, 60, 'dông')],
      luc: DateTime(2026, 11, 7, 14, 5),
    );
    for (final size in [const Size(360, 740), const Size(1280, 800)]) {
      await t.binding.setSurfaceSize(size);
      await t.pumpWidget(ProviderScope(
        key: UniqueKey(),
        overrides: [thoiTietProvider.overrideWith(() => _CoDinh(v))],
        child: const MaterialApp(home: ThoiTietScreen()),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      // 09/11: tiêu đề 2 dòng (tên khu vực dưới chữ Thời tiết, không bị nút Đổi khu vực cắt)
      expect(find.text('Thời tiết'), findsOneWidget);
      expect(find.text('TP. Hồ Chí Minh'), findsOneWidget);
      expect(find.text('Hôm nay'), findsOneWidget);
      // ghi nguồn ở cuối danh sách: cuộn tới mới được dựng
      await t.scrollUntilVisible(find.text('Nguồn dữ liệu'), 300, scrollable: find.byType(Scrollable).first);
      expect(t.takeException(), isNull);
      expect(find.text('Apple Weather'), findsOneWidget);
      expect(find.text('Nguồn dữ liệu'), findsOneWidget);
      expect(find.text('Hỏi Bé Boom'), findsOneWidget);
    }
    await t.binding.setSurfaceSize(null);
  });
}
