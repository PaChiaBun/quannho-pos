import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/models/product_model.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/repositories/ban_repository.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc_ui.dart';
import 'package:quannho_pos/modules/tinh_gio/loai_hinh.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio_widgets.dart';
import 'package:quannho_pos/shared/widgets/module_tile.dart';

// Chụp bảng biểu tượng theo ngành để duyệt bằng mắt:
//   flutter test test/modules/tinh_gio/nganh_icon_golden_test.dart --update-goldens
// Nạp phông MaterialIcons + NotoSans, không thì ảnh ra ô vuông rỗng (bài học 21/11).
Future<void> _napPhong() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.path;
  final icons = File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
  if (icons.existsSync()) {
    final l = FontLoader('MaterialIcons')
      ..addFont(Future.value(ByteData.sublistView(icons.readAsBytesSync())));
    await l.load();
  }
  final chu = FontLoader('NotoSans');
  for (final f in ['NotoSans-Regular.ttf', 'NotoSans-SemiBold.ttf', 'NotoSans-Bold.ttf']) {
    chu.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync())));
  }
  await chu.load();
  // Chữ trong app là Plus Jakarta Sans (GoogleFonts): nạp bản để sẵn trong test/fonts, không tải mạng.
  GoogleFonts.config.allowRuntimeFetching = false;
  const jakarta = {'regular': 'Regular', '500': 'Medium', '600': 'SemiBold', '700': 'Bold', '800': 'ExtraBold'};
  for (final e in jakarta.entries) {
    final l = FontLoader('PlusJakartaSans_${e.key}')
      ..addFont(Future.value(
          ByteData.sublistView(File('test/fonts/PlusJakartaSans-${e.value}.ttf').readAsBytesSync())));
    await l.load();
  }
}

void main() {
  testWidgets('bảng biểu tượng theo ngành', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(1360, 620);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const teal = Color(0xFF0D9488);
    const navy = Color(0xFF1C2151);
    Widget o(LoaiHinh l) => SizedBox(
          width: 150,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2DD4BF), teal, Color(0xFF115E59)],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: l.bieuTuong(size: 28, color: Colors.white),
                    ),
                    const Spacer(),
                    Text(l.nhan,
                        style: const TextStyle(
                            fontFamily: 'NotoSans', color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              l.bieuTuong(size: 96, color: navy),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  l.bieuTuong(size: 24, color: navy),
                  const SizedBox(width: 14),
                  l.bieuTuong(size: 18, color: navy),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: navy, borderRadius: BorderRadius.circular(8)),
                    child: l.bieuTuong(size: 20, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(l.moTa,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'NotoSans', color: navy, fontSize: 12)),
            ],
          ),
        );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFFAF7F2),
        body: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final l in kLoaiHinh) Padding(padding: const EdgeInsets.all(8), child: o(l))],
          ),
        ),
      ),
    ));
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/nganh_icon.png'));
  });

  // Ô module thật như ở Trang chủ: lưới 2 cột tỉ lệ 1,15 trên máy 360; 4 cột cao 176 trên máy 1024.
  for (final (ten, co, cot) in const [('360', Size(360, 470), 2), ('1024', Size(1024, 420), 4)]) {
    testWidgets('ô module Các hoạt động tính giờ $ten', (tester) async {
      await _napPhong();
      tester.view.physicalSize = co;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final goc = kModuleConfigs[kTinhGioModuleId]!;
      final o = [
        kModuleConfigs['pos']!,
        goc,
        kModuleConfigs['table']!,
        tinhGioTileData(goc, loaiHinhTheoId('bi_da')),
        tinhGioTileData(goc, loaiHinhTheoId('bong_da')),
        tinhGioTileData(goc, loaiHinhTheoId('cau_long')),
        if (cot > 2) tinhGioTileData(goc, loaiHinhTheoId('karaoke')),
        if (cot > 2) kModuleConfigs['kho']!,
      ];
      await runZonedGuarded(() async {
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'NotoSans'),
          home: Scaffold(
            backgroundColor: const Color(0xFFFAF7F2),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: GridView(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cot,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: cot >= 3 ? 176 : null,
                  childAspectRatio: 1.15,
                ),
                children: [for (final d in o) ModuleTile(data: d)],
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }, (_, __) {});
      expect(find.text(kTenModuleTinhGio), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'tên 2 dòng không được tràn ô');
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/o_module_$ten.png'));
    });
  }

  testWidgets('hộp chọn loại hình trên màn 360×800 (Sunmi V3)', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // google_fonts vẫn thử tải phông dù đã nạp sẵn và ném lỗi không ai chờ → gom vào vùng riêng, bỏ qua.
    await runZonedGuarded(() async {
    await tester.pumpWidget(ProviderScope(
      overrides: [tinhGioLoaiHinhProvider.overrideWith((ref) async => loaiHinhTheoId('bi_da'))],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Color(0xFF8E8A85),
          body: Align(alignment: Alignment.bottomCenter, child: TinhGioLoaiHinhSheet()),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    }, (_, __) {});
    expect(find.text('Bi da'), findsOneWidget);
    expect(find.text('Pickleball'), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/chon_loai_hinh_360.png'));
  });

  // Hộp đặt giá giờ trên máy 360×800: bàn chưa có giá, bàn đã có giá 60.000 (điền sẵn, có nút gỡ), và bàn đã cài
  // khung giá + làm tròn (phần "Giá theo giờ & làm tròn" tự mở; máy cao 1000 để thấy hết). Khách vào lúc 16:30.
  for (final (ten, coGia, coKhung) in const [('trong', false, false), ('da_co', true, false), ('co_khung', true, true)]) {
    testWidgets('hộp đặt giá giờ $ten', (tester) async {
      await _napPhong();
      tester.view.physicalSize = Size(360, coKhung ? 1100 : 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      ProductModel mon(String id, String ten, double gia, String dm) => ProductModel(
          id: id, storeId: 's', name: ten, category: dm, unit: 'giờ', productType: 'finished', stockQty: 0, minStock: 0,
          sellPrice: gia, costPrice: 0, stationCode: 'nong', isAvailable: true, isActive: true, isDeleted: false);
      BanTableModel ban(String id, String ten, String? gia) => BanTableModel(
          id: id, zoneId: 'z', storeId: 's', label: ten, seats: 4, sortOrder: 0, isActive: true, giaGioProductId: gia);
      final b = ban('b2', 'Bàn 2', coGia ? 'g60' : null);
      await runZonedGuarded(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            tinhGioLoaiHinhProvider.overrideWith((ref) async => loaiHinhTheoId('bi_da')),
            giaGioCaiDatProvider.overrideWith((ref) async => {
                  if (coKhung)
                    'b2': const GiaGioCaiDat(block: 30, anHan: 5, toiThieu: 60, khung: [
                      KhungGia(thu: {1, 2, 3, 4, 5}, tuPhut: 17 * 60, denPhut: 23 * 60, gia: 80000),
                      KhungGia(thu: {6, 7}, tuPhut: 0, denPhut: 0, gia: 100000),
                    ]),
                }),
            allProductsProvider.overrideWith((ref) => Stream.value(<ProductModel>[
              mon('c1', 'Cà phê sữa đá', 25000, 'Cà phê'),
              if (coGia) mon('g60', 'Tiền giờ 60.000 đ', 60000, 'Tiền giờ'),
              if (coGia) mon('g90', 'Giờ phòng VIP', 90000, 'Tiền giờ'),
            ])),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF8E8A85),
              body: Align(
                alignment: Alignment.bottomCenter,
                child: TinhGioGiaGioSheet(
                  table: b,
                  tenKhu: 'Khu A',
                  banCuaKhu: [ban('b1', 'Bàn 1', null), b, ban('b3', 'Bàn 3', null)],
                  lucViDu: DateTime(2030, 12, 2, 16, 30), // Thứ Hai
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }, (_, _) {});
      expect(tester.takeException(), isNull, reason: 'hộp không được tràn trên máy 360');
      expect(find.text('Cà phê sữa đá'), findsNothing, reason: 'không liệt kê thực đơn');
      expect(find.text('60.000'), coGia ? findsNWidgets(2) : findsOneWidget, reason: 'ô giá điền sẵn + chip');
      expect(find.text('Không tính giờ (bàn thường)'), coGia ? findsOneWidget : findsNothing);
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/gia_gio_$ten.png'));
    });
  }

  // Màn Lịch đặt với dữ liệu mẫu, ngày cố định để ảnh không đổi theo ngày chạy test.
  for (final (ten, co) in const [('360', Size(360, 800)), ('1024', Size(1024, 700))]) {
    testWidgets('màn Lịch đặt $ten', (tester) async {
      await _napPhong();
      tester.view.physicalSize = co;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // ngày cố định xa hiện tại: dùng 28/11/2026 thì đúng hôm đó màn ghi "Hôm nay" và ảnh mẫu lệch (QC 28/11)
      final ngay = DateTime(2030, 11, 30);
      BanTableModel ban(String id, String ten) =>
          BanTableModel(id: id, zoneId: 'z', storeId: 's', label: ten, seats: 4, sortOrder: 0, isActive: true, giaGioProductId: 'p');
      DatTruoc dat(String id, String ban, int gio, int phut, String ten, {String tt = 'da_dat', String? sdt, bool nhac = false}) => DatTruoc(
            id: id,
            tableId: ban,
            tenKhach: ten,
            sdt: sdt,
            gioTu: DateTime(2030, 11, 30, gio),
            gioDen: DateTime(2030, 11, 30, gio).add(Duration(minutes: phut)),
            trangThai: tt,
            nhacLuc: nhac ? DateTime(2030, 11, 30, gio - 1, 32) : null,
            createdAt: DateTime(2030, 11, 29),
          );
      await runZonedGuarded(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            banDeDatProvider.overrideWith((ref) async => [ban('s1', 'Sân 1'), ban('s2', 'Sân 2'), ban('s3', 'Sân 3')]),
            datTruocTheoNgayProvider.overrideWith((ref, n) => Stream.value([
                  dat('a', 's1', 17, 60, 'Anh Nam', sdt: '0901234567', tt: 'da_nhan'),
                  dat('b', 's1', 18, 90, 'Chị Lan', sdt: '0912345678', nhac: true),
                  dat('c', 's1', 20, 60, 'Nhóm anh Tú', tt: 'huy'),
                  dat('d', 's2', 19, 120, 'CLB Cầu lông Q7', sdt: '0987654321'),
                ])),
          ],
          child: MaterialApp(debugShowCheckedModeBanner: false, home: LichDatScreen(ngay: ngay)),
        ));
        await tester.pumpAndSettle();
      }, (_, __) {});
      expect(find.text('Lịch đặt'), findsOneWidget);
      expect(find.textContaining('Chị Lan'), findsOneWidget);
      expect(find.text('Chưa có lượt đặt'), findsOneWidget, reason: 'Sân 3 trống');
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/lich_dat_$ten.png'));
    });
  }
}
