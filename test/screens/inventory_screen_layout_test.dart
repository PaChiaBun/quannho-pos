// Màn Kho hàng: thẻ gọn trên máy POS Sunmi V3 (360×800dp), bảng cân đối trên iPad / máy tính.
// Dựng cả màn với dữ liệu giả, đo bằng phông thật (Roboto của Flutter SDK, Plus Jakarta Sans trong
// test/fonts) để kiểm đúng độ rộng chữ như trên máy: không tràn, không cắt "…", không phải vuốt ngang.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/providers/permission_provider.dart';
import 'package:quannho_pos/core/providers/session_provider.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart';
import 'package:quannho_pos/modules/kho/providers/kho_providers.dart';
import 'package:quannho_pos/modules/kho/repository/kho_repository.dart';
import 'package:quannho_pos/screens/inventory_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _loadFont(String family, Iterable<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    loader.addFont(Future.value(ByteData.sublistView(File(p).readAsBytesSync())));
  }
  await loader.load();
}

StockItem _mon(
  String id,
  String name, {
  String? cat,
  double ton = 20,
  double min = 5,
  double gia = 25000,
  bool dangBan = true,
}) =>
    StockItem(
      id: id,
      name: name,
      unit: 'phần',
      category: cat,
      stockQty: ton,
      minStock: min,
      costPrice: 10000,
      sellPrice: gia,
      isAvailable: dangBan,
    );

final _items = [
  _mon('1', 'Cà phê sữa đá', cat: 'Đồ uống', ton: 40, min: 10),
  _mon('2', 'Bạc xỉu nóng thêm sữa đặc, ít đá cho khách quen', cat: 'Đồ uống', ton: 3, gia: 35000),
  _mon('3', 'Bánh flan caramen', cat: 'Tráng miệng', ton: 0, gia: 18000),
  // Không đặt tồn tối thiểu mà bán âm → nhãn "Không theo dõi"; giá dài nhất hay gặp.
  _mon('4', 'Lẩu thái hải sản', cat: 'Món nhậu đặc biệt', ton: -4, min: 0, gia: 1500000),
  _mon('5', 'Mì xào bò', cat: 'Đồ ăn', dangBan: false, gia: 45000),
  for (var i = 6; i <= 14; i++) _mon('$i', 'Món thử $i', cat: 'Đồ ăn', gia: 30000.0 + i * 1000),
];

const _boomKey = Key('boom');

/// [sidebar]: như main.dart màn ≥ 600dp (thanh bên 88 + vạch 1); không thì như bản điện thoại
/// (thanh dưới 72dp + nút voi Boom 80dp nhô lên giữa, centerDocked).
Future<void> _pump(
  WidgetTester tester,
  Size size, {
  bool sidebar = false,
  bool owner = false,
  double totalValue = 196e6,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  // Thanh trạng thái máy thật — trước đây ListView bảng tự cộng lề này thành 1 hàng trống.
  tester.view.padding = const FakeViewPadding(top: 24);
  tester.view.viewPadding = const FakeViewPadding(top: 24);
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});

  final container = ProviderContainer(
    overrides: [
      allStockProvider.overrideWith((ref) => Stream.value(_items)),
      khoStatsProvider.overrideWith(
        (ref) async => KhoStats(
          totalItems: 128,
          lowStockItems: 12,
          outOfStockItems: 3,
          totalValue: totalValue,
          todayInQty: 0,
          todayInCost: 0,
        ),
      ),
      userActionPermsProvider.overrideWith(
        (ref) async => owner ? {'kho.delete_item', 'kho.edit_item'} : <String>{},
      ),
    ],
  );
  addTearDown(container.dispose);
  if (owner) {
    container.read(sessionProvider.notifier).setSession(
          const SessionData(
            userId: 'u-owner',
            phone: '0900000000',
            displayName: 'Chủ quán',
            role: 'owner',
            isOwner: true,
          ),
        );
  }

  const screen = InventoryScreen();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: sidebar
            ? const Scaffold(
                body: SafeArea(
                  child: Row(
                    children: [
                      SizedBox(width: 88),
                      VerticalDivider(width: 1),
                      Expanded(child: screen),
                    ],
                  ),
                ),
              )
            : const Scaffold(
                body: screen,
                floatingActionButton: SizedBox(key: _boomKey, width: 80, height: 80),
                floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
                bottomNavigationBar: BottomAppBar(height: 72),
              ),
      ),
    ),
  );
  await tester.pump(); // stream / future trả dữ liệu
  await tester.pump(const Duration(milliseconds: 300));
}

/// Tỉ lệ chữ bị FittedBox thu nhỏ (1.0 = đủ cỡ).
double _scale(WidgetTester tester, Finder f) =>
    tester.getRect(f).width / tester.getSize(f).width;

bool _cut(WidgetTester tester, Finder f) =>
    tester.renderObject<RenderParagraph>(f).didExceedMaxLines;

Finder _verticalList() => find.byWidgetPredicate(
      (w) => w is ListView && w.scrollDirection == Axis.vertical,
    );

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final root = Platform.environment['FLUTTER_ROOT'] ??
        // flutter_tester nằm ở <FLUTTER_ROOT>/bin/cache/artifacts/engine/<máy>/flutter_tester
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

  group('360×800 — máy POS Sunmi V3: danh sách thẻ', () {
    testWidgets('thẻ đủ tên, danh mục, tồn, min, giá, trạng thái; không tràn, không cắt chữ',
        (tester) async {
      await _pump(tester, const Size(360, 800));
      expect(tester.takeException(), isNull);

      // Không còn bảng 8 cột (phải vuốt ngang mới thấy tồn/giá).
      expect(find.text('Tồn kho & Min'), findsNothing);
      expect(find.text('Cà phê sữa đá'), findsOneWidget);
      expect(find.text('25.000 đ'), findsOneWidget); // fmtVnd đủ số
      expect(find.text('Đồ uống'), findsWidgets);
      expect(find.text('Tạm ngưng bán', skipOffstage: false), findsOneWidget); // thẻ 5, dưới mép màn
      expect(find.textContaining('Tồn: 40 phần', findRichText: true), findsOneWidget);
      expect(find.textContaining('min 10', findRichText: true), findsOneWidget);

      // Tên dài xuống 2 dòng, không bị "…".
      final longName = find.text('Bạc xỉu nóng thêm sữa đặc, ít đá cho khách quen');
      expect(_cut(tester, longName), isFalse);
      expect(tester.getSize(longName).height, greaterThan(30)); // 2 dòng

      // Món không theo dõi tồn mà bán âm: chữ thay số âm, vẫn đủ min + giá.
      final untracked = find.textContaining('Không theo dõi', findRichText: true);
      expect(untracked, findsOneWidget);
      expect(_cut(tester, untracked), isFalse);
      expect(find.text('1.500.000 đ'), findsOneWidget);

      // 4 ô thống kê đủ chữ, cỡ chữ không bị thu nhỏ.
      for (final t in ['128', 'Sản phẩm', '12', 'Sắp hết', '3', 'Hết hàng', '196 triệu', 'Giá trị kho']) {
        expect(_scale(tester, find.text(t)), greaterThan(0.95), reason: 'ô thống kê "$t" bị thu nhỏ');
      }
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsNothing); // bản gọn: bỏ icon

      // Dải "Quản lý kho nâng cao" không cắt chữ, mỗi dòng nằm gọn 1 dòng.
      for (final t in ['Quản lý kho nâng cao', 'Phiếu nhập hàng từ nhà cung cấp']) {
        expect(find.text(t), findsOneWidget);
        expect(tester.getSize(find.text(t)).height, lessThan(20), reason: '"$t" xuống dòng');
      }

      // Hết hàng trống dưới đầu danh sách: thẻ đầu sát mép trên (lề 8 + đệm thẻ 9), không cộng 24dp thanh trạng thái.
      final listTop = tester.getTopLeft(_verticalList()).dy;
      expect(tester.getTopLeft(find.text('Cà phê sữa đá')).dy - listTop, lessThan(24));
    });

    testWidgets('giá trị kho dưới 10 triệu hiện đủ số vẫn vừa ô', (tester) async {
      await _pump(tester, const Size(360, 800), totalValue: 9876000);
      expect(tester.takeException(), isNull);
      expect(_scale(tester, find.text('9.876.000 đ')), greaterThan(0.95));
    });

    testWidgets('cuộn hết: nút voi Boom không che món cuối; nút lên đầu trang', (tester) async {
      await _pump(tester, const Size(360, 800));
      for (var i = 0; i < 3; i++) {
        await tester.drag(_verticalList(), const Offset(0, -3000));
        await tester.pump(const Duration(milliseconds: 400)); // đầu trang thu gọn xong
      }
      expect(tester.takeException(), isNull);

      // Đầu trang đã thu gọn: thanh tìm nằm dưới thanh trạng thái 24dp (không chui dưới đồng hồ/pin)
      // và ô tìm không bị chip tên tab bóp còn mỗi icon.
      expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThanOrEqualTo(24));
      expect(tester.getSize(find.byType(TextField)).width, greaterThan(150));

      final lastCard = find.ancestor(of: find.text('Món thử 14'), matching: find.byType(InkWell)).first;
      final boom = tester.getRect(find.byKey(_boomKey));
      expect(tester.getRect(lastCard).bottom, lessThanOrEqualTo(boom.top));
      expect(find.text('Hiển thị 14 / 14 món'), findsOneWidget);

      await tester.tap(find.byTooltip('Lên đầu trang'));
      await tester.pump(); // khung đầu: hoạt ảnh cuộn mới bắt đầu
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Cà phê sữa đá'), findsOneWidget);
    });

    testWidgets('chọn nhiều: nút Chọn, chạm thẻ, Chọn tất cả, nhấn giữ; menu ⋮ đủ thao tác',
        (tester) async {
      await _pump(tester, const Size(360, 800), owner: true);
      expect(tester.takeException(), isNull);

      // Nhấn giữ thẻ (chưa ở chế độ chọn) → bắt đầu chọn.
      await tester.longPress(find.text('Bánh flan caramen'));
      await tester.pump();
      expect(find.text('Đã chọn: 1 món'), findsOneWidget);
      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);

      // Đang chọn: chạm thẻ khác = chọn thêm (không mở sửa món).
      await tester.tap(find.text('Cà phê sữa đá'));
      await tester.pump();
      expect(find.text('Đã chọn: 2 món'), findsOneWidget);

      await tester.tap(find.text('Chọn tất cả (14 món)'));
      await tester.pump();
      expect(find.text('Đã chọn: 14 món'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Thoát chế độ chọn bằng nút "Đã chọn" ở thanh ghim.
      await tester.tap(find.text('Đã chọn: 14 món'));
      await tester.pump();
      expect(find.text('Chọn tất cả (14 món)'), findsNothing);

      // Nút "Chọn" ở ô tìm kiếm.
      await tester.tap(find.text('Chọn'));
      await tester.pump();
      expect(find.text('Chọn tất cả (14 món)'), findsOneWidget);
      // Ô tích thế chỗ ảnh món → dòng tồn/min/giá không bị đẩy hẹp mà cắt "…".
      expect(_cut(tester, find.textContaining('Tồn: 40 phần', findRichText: true)), isFalse);
      await tester.tap(find.text('Hủy'));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      for (final t in ['Sửa thông tin món', 'Nhập kho', 'Điều chỉnh tồn kho', 'Lịch sử xuất nhập', 'Xóa món']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  });

  for (final size in const [Size(768, 1024), Size(1024, 768), Size(1280, 800)]) {
    testWidgets('${size.width.toInt()}×${size.height.toInt()} (thanh bên 89dp): bảng vừa khít, không tràn ngang',
        (tester) async {
      await _pump(tester, size, sidebar: true);
      expect(tester.takeException(), isNull);

      expect(find.text('Tồn kho & Min'), findsOneWidget);
      expect(tester.getRect(find.text('Trạng thái')).right, lessThanOrEqualTo(size.width));
      expect(tester.getRect(find.byIcon(Icons.more_vert_rounded).first).right, lessThanOrEqualTo(size.width));

      // Ô dài nhất trong bảng không bị "…" (.last: bỏ qua chip lọc danh mục cùng tên ở trên).
      for (final t in ['1.500.000 đ', 'Không theo dõi', 'Tạm ngưng bán', 'Món nhậu đặc biệt']) {
        expect(_cut(tester, find.text(t).last), isFalse, reason: '"$t" bị cắt');
      }
      expect(_scale(tester, find.text('Tạm ngưng bán')), greaterThan(0.95));

      // Hàng đầu nằm ngay dưới tiêu đề bảng (không có hàng trống).
      final headBottom = tester.getBottomLeft(find.text('Tồn kho & Min')).dy;
      expect(tester.getTopLeft(find.text('Cà phê sữa đá')).dy - headBottom, lessThan(30));

      // Cột cân đối: tên món flex 3, các cột khác flex 2 — "Danh mục" không bị đẩy sát mép phải.
      final w = size.width - 89;
      final catLeft = tester.getTopLeft(find.text('Danh mục')).dx - 89;
      expect(catLeft / w, lessThan(0.45));
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget); // ô thống kê đủ icon
    });
  }
}
