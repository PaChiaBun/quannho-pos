import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/bo_nho/bo_nho_quan_screen.dart';

const _id = 'a0000000-0000-0000-0000-00000000000a';

Future<void> _ve(WidgetTester t, BoNhoQuan? v, Widget child) async {
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [boNhoQuanProvider.overrideWith((ref, _) async => v)],
    child: MaterialApp(home: Scaffold(body: child)),
  ));
  await t.pumpAndSettle();
}

void main() {
  test('đọc phòng thủ', () {
    final b = BoNhoQuan.fromJson({
      'ho_so': {'tat': true},
      'ghi_nho': [
        {'id': '1', 'noi_dung': 'Quán gần trường', 'loai': 'su_that', 'nguon': 'chu_quan_noi', 'trang_thai': 'xac_nhan', 'muc_xem': 'ca_quan'},
        {'id': '', 'noi_dung': 'thiếu mã'},
        'rác',
      ],
    })!;
    expect(b.tat, isTrue);
    expect(b.ghiNho.length, 1);
    expect(BoNhoQuan.fromJson(null), isNull);
    expect(BoNhoQuan.fromJson({'ghi_nho': 5})!.ghiNho, isEmpty);
  });

  testWidgets('ô Cài đặt: ẩn khi chưa có tính năng, hiện số điều khi có', (t) async {
    await _ve(t, null, const BoNhoQuanTile(storeId: _id));
    expect(find.byType(ListTile), findsNothing);
    await _ve(t, const BoNhoQuan(false, [GhiNhoQuan('1', 'Quán gần trường', 'su_that', 'chu_quan_noi', 'xac_nhan', 'ca_quan')]),
        const BoNhoQuanTile(storeId: _id));
    expect(find.text('1 điều · xem, sửa, xoá'), findsOneWidget);
    await _ve(t, const BoNhoQuan(true, []), const BoNhoQuanTile(storeId: _id));
    expect(find.text('Đang tắt'), findsOneWidget);
  });

  testWidgets('màn bộ nhớ: chia nhóm, nhãn chỉ chủ quán, nút xác nhận cho điều đoán, không tràn trên điện thoại', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740));
    await _ve(
      t,
      const BoNhoQuan(false, [
        GhiNhoQuan('1', 'Quán gần trường THCS', 'su_that', 'chu_quan_noi', 'xac_nhan', 'ca_quan'),
        GhiNhoQuan('2', 'Khách chính có lẽ là học sinh', 'su_that', 'boom_doan', 'doan', 'ca_quan'),
        GhiNhoQuan('3', 'Combo trưa đã thử, không hiệu quả', 'da_thu', 'chu_quan_noi', 'xac_nhan', 'chu_quan'),
      ]),
      const BoNhoQuanScreen(storeId: _id),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Điều anh/chị đã nói'), findsOneWidget);
    expect(find.text('Bé Boom đoán, chờ anh/chị xác nhận'), findsOneWidget);
    expect(find.byTooltip('Đúng rồi'), findsOneWidget);
    // nhóm cuối nằm dưới màn điện thoại: cuộn tới mới được dựng
    await t.scrollUntilVisible(find.text('chỉ chủ quán'), 200, scrollable: find.byType(Scrollable).first);
    expect(t.takeException(), isNull);
    expect(find.text('Việc đã thử'), findsOneWidget);
    await t.binding.setSurfaceSize(null);
  });
}
