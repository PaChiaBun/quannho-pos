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
import 'package:quannho_pos/core/repositories/core_customer_repository.dart';
import 'package:quannho_pos/modules/tinh_gio/bao_cao_tinh_gio.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc.dart';
import 'package:quannho_pos/modules/tinh_gio/dat_truoc_ui.dart';
import 'package:quannho_pos/modules/tinh_gio/gia_gio_ui.dart';
import 'package:quannho_pos/modules/tinh_gio/goi_gio_ui.dart';
import 'package:quannho_pos/modules/tinh_gio/loai_hinh.dart';
import 'package:quannho_pos/modules/tinh_gio/ngay_le_ui.dart';
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
      tester.view.physicalSize = Size(360, coKhung ? 1500 : 800);
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
                      KhungGia(thu: {kThuNgayLe}, tuPhut: 0, denPhut: 0, gia: 120000),
                    ], goi: [
                      GoiGio(soPhut: 60, gia: 55000),
                      GoiGio(soPhut: 120, gia: 100000),
                    ]),
                }),
            ngayLeProvider.overrideWith((ref) async => [NgayLe(DateTime(2030, 12, 31), ''), NgayLe(DateTime(2031, 1, 1), '')]),
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

  // Đợt 6: hộp khung giá đang bật "Ngày lễ" và hộp Ngày lễ của quán (hôm nay cố định 02/12/2030).
  final mauNgayLe = [
    NgayLe(DateTime(2030, 12, 31), 'Giao thừa'),
    NgayLe(DateTime(2031, 1, 1), 'Tết Dương lịch'),
    for (var i = 0; i < 5; i++) NgayLe(DateTime(2031, 1, 22 + i), 'Tết'),
  ];
  for (final (ten, hop) in [
    ('khung_le', const KhungGiaSheet(khung: KhungGia(thu: {kThuNgayLe}, tuPhut: 0, denPhut: 0, gia: 90000), giaGoc: 60000)),
    ('ngay_le', NgayLeSheet(homNay: DateTime(2030, 12, 2))),
  ]) {
    testWidgets('hộp $ten', (tester) async {
      await _napPhong();
      tester.view.physicalSize = Size(360, ten == 'ngay_le' ? 1250 : 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await runZonedGuarded(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [ngayLeProvider.overrideWith((ref) async => mauNgayLe)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF8E8A85),
              body: Align(alignment: Alignment.bottomCenter, child: hop),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }, (_, _) {});
      expect(tester.takeException(), isNull, reason: 'hộp không được tràn trên máy 360');
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/gia_gio_$ten.png'));
    });
  }

  // Đợt 7: hộp thêm gói, hộp chọn gói cho bàn đang chơi, dòng gói trong khối ĐANG TÍNH GIỜ (3 trạng thái).
  final vaoMau = DateTime(2030, 12, 2, 18);
  for (final (ten, hop, cao) in <(String, Widget, double)>[
    ('them', const GoiGioSheet(daCo: {60}, goi: GoiGio(soPhut: 120, gia: 100000), giaGoc: 60000), 820),
    ('chon', ChonGoiSheet(tableId: 'p2', sessionId: 's1', tenBan: 'Phòng 2', vao: DateTime(2099, 1, 1, 18, 5), giaGoc: 60000), 820),
    ('doi', const ChonGoiSheet(tableId: 'p2', sessionId: 's1', goiPhut: 120, goiGia: 100000, tenBan: 'Phòng 2', giaGoc: 60000), 820),
    (
      'nhac',
      Column(mainAxisSize: MainAxisSize.min, children: [
        for (final daHet in [false, true])
          Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: const Color(0xFFFFF8F0),
              borderRadius: BorderRadius.circular(24),
              child: HopNhacGoi(
                tenBan: 'Phòng 2',
                goiPhut: 120,
                goiGia: 100000,
                het: vaoMau.add(const Duration(hours: 2)),
                daHet: daHet,
                nay: vaoMau.add(Duration(minutes: daHet ? 125 : 110)),
                onDoiGoi: () {},
                onDaBao: () {},
              ),
            ),
          ),
      ]),
      780
    ),
    (
      'dong_ban',
      Container(
        color: const Color(0xFF2B2780),
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          GoiGioDongBan(tableId: 'p2', sessionId: 's1', goiPhut: null, goiGia: null, vao: vaoMau, luc: vaoMau),
          GoiGioDongBan(tableId: 'p2', sessionId: 's1', goiPhut: 120, goiGia: 100000, vao: vaoMau,
              luc: vaoMau.add(const Duration(minutes: 95))),
          GoiGioDongBan(tableId: 'p2', sessionId: 's1', goiPhut: 120, goiGia: 100000, vao: vaoMau,
              luc: vaoMau.add(const Duration(minutes: 113))),
          GoiGioDongBan(tableId: 'p2', sessionId: 's1', goiPhut: 80, goiGia: 0, vao: vaoMau,
              luc: vaoMau.add(const Duration(minutes: 88))),
        ]),
      ),
      560
    ),
  ]) {
    testWidgets('gói giờ $ten', (tester) async {
      await _napPhong();
      tester.view.physicalSize = Size(360, cao);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await runZonedGuarded(() async {
        await tester.pumpWidget(ProviderScope(
          overrides: [
            giaGioCaiDatProvider.overrideWith((ref) async => {
                  'p2': const GiaGioCaiDat(goi: [
                    GoiGio(id: 'g1', soPhut: 60, gia: 55000),
                    GoiGio(id: 'g2', soPhut: 120, gia: 100000),
                    GoiGio(id: 'g3', soPhut: 180, gia: 140000),
                  ]),
                }),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: const Color(0xFF8E8A85),
              body: Align(alignment: Alignment.bottomCenter, child: hop),
            ),
          ),
        ));
        await tester.pumpAndSettle();
      }, (_, _) {});
      expect(tester.takeException(), isNull, reason: 'không được tràn trên máy 360');
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/goi_gio_$ten.png'));
    });
  }

  // Màn Lịch đặt với dữ liệu mẫu, ngày cố định để ảnh không đổi theo ngày chạy test.
  // Kiểu danh sách (lich_dat_*) và kiểu lưới giờ × sân (lich_luoi_*, đợt 2; "bây giờ" = 30/11/2030 16:40).
  for (final (ten, co, luoi) in const [
    ('360', Size(360, 800), false),
    ('1024', Size(1024, 700), false),
    ('luoi_360', Size(360, 800), true),
    ('luoi_1024', Size(1024, 700), true),
  ]) {
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
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: LichDatScreen(ngay: ngay, luoi: luoi, lucLuoi: DateTime(2030, 11, 30, 16, 40)),
          ),
        ));
        await tester.pumpAndSettle();
      }, (_, __) {});
      expect(tester.takeException(), isNull);
      expect(find.text('Lịch đặt'), findsOneWidget);
      expect(find.textContaining('Chị Lan'), findsOneWidget);
      if (!luoi) expect(find.text('Chưa có lượt đặt'), findsOneWidget, reason: 'Sân 3 trống');
      await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/${luoi ? 'lich_$ten' : 'lich_dat_$ten'}.png'));
    });
  }

  // Hộp đặt với "Lặp lại hàng tuần" bật (đợt 3): T3, T5 từ 03/12/2030 18:00, 4 tuần.
  testWidgets('hộp đặt lịch cố định', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ban = BanTableModel(id: 's1', zoneId: 'z', storeId: 's', label: 'Sân 1', seats: 4, sortOrder: 0, isActive: true, giaGioProductId: 'p');
    await runZonedGuarded(() async {
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF8E8A85),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DatTruocFormSheet(
                ban: ban,
                ngay: DateTime(2030, 12, 3),
                trongNgay: const [],
                tuMacDinh: DateTime(2030, 12, 3, 18),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('T5'));
      await tester.pumpAndSettle();
    }, (_, __) {});
    expect(tester.takeException(), isNull);
    expect(find.textContaining('8 buổi · T3, T5'), findsOneWidget);
    expect(find.text('Đặt 8 buổi'), findsOneWidget);
    await expectLater(find.byType(Scaffold), matchesGoldenFile('goldens/dat_lap_360.png'));
  });

  // Hộp lượt đặt thuộc lịch cố định (đợt 3): "Lịch cố định · buổi 2/4", hai cách huỷ.
  testWidgets('hộp lượt đặt lịch cố định', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ban = BanTableModel(id: 's1', zoneId: 'z', storeId: 's', label: 'Sân 1', seats: 4, sortOrder: 0, isActive: true, giaGioProductId: 'p');
    DatTruoc buoi(String id, int ngay) => DatTruoc(
          id: id,
          tableId: 's1',
          tenKhach: 'CLB Cầu lông Q7',
          sdt: '0987654321',
          gioTu: DateTime(2030, 12, ngay, 18),
          gioDen: DateTime(2030, 12, ngay, 20),
          trangThai: 'da_dat',
          createdAt: DateTime(2030, 11, 29),
          chuoiId: 'c1',
          tienCoc: 200000,
        );
    final chuoi = [buoi('a', 3), buoi('b', 5), buoi('c', 10), buoi('d', 12)];
    await runZonedGuarded(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          banDeDatProvider.overrideWith((ref) async => [ban]),
          datTruocTheoNgayProvider.overrideWith((ref, n) => Stream.value([chuoi[1]])),
          chuoiDatProvider.overrideWith((ref, id) async => chuoi),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: LichDatScreen(ngay: DateTime(2030, 12, 5), lucLuoi: DateTime(2030, 12, 5, 12)),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CLB Cầu lông Q7'));
      await tester.pumpAndSettle();
    }, (_, __) {});
    expect(tester.takeException(), isNull);
    expect(find.text('Lịch cố định · buổi 2/4 · T3, T5 · tới 12/12'), findsOneWidget);
    expect(find.text('Huỷ buổi này và các buổi sau'), findsOneWidget);
    expect(find.text('Huỷ riêng buổi này'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/luot_dat_chuoi_360.png'));
  });

  // Đợt 4: khách không đến, lượt có cọc 200.000 → hỏi ba cách, chọn sẵn "Quán giữ cọc"; phục vụ không hoàn được.
  testWidgets('hộp xử lý cọc khi khách không đến', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final d = DatTruoc(
      id: 'a',
      tableId: 's1',
      tenKhach: 'Anh Nam',
      gioTu: DateTime(2030, 12, 3, 18),
      gioDen: DateTime(2030, 12, 3, 20),
      trangThai: 'khong_den',
      createdAt: DateTime(2030, 11, 29),
      tienCoc: 200000,
      customerId: 'k1',
      cocTrangThai: 'da_thu',
      cocQuy: 'cash',
    );
    var khiHoan = '', khiTrongVi = '';
    String nut() => tester.widget<Text>(find.textContaining('Xác nhận ·')).data!;
    await runZonedGuarded(() async {
      await tester.pumpWidget(MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF6B6A8A),
          body: Align(
            alignment: Alignment.bottomCenter,
            child: XuLyCocSheet(dat: d, tenBan: 'Sân 1', khongDen: true, laQuanLy: false),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hoàn cọc'));
      await tester.pump();
      khiHoan = nut();
      await tester.tap(find.text('Để trong ví khách'));
      await tester.pump();
      khiTrongVi = nut();
      await tester.tap(find.text('Quán giữ cọc'));
      await tester.pumpAndSettle();
    }, (_, __) {});
    expect(tester.takeException(), isNull);
    expect(khiHoan, 'Xác nhận · quán giữ 200.000 đ', reason: 'phục vụ không chọn được Hoàn cọc');
    expect(khiTrongVi, 'Xác nhận · để 200.000 đ trong ví');
    expect(nut(), 'Xác nhận · quán giữ 200.000 đ');
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/xu_ly_coc_360.png'));
  });

  // 28/11 hộp đặt mới: một ô tìm khách + khách quen, ô giờ to, dải lịch trong ngày, tạm tính, các dòng "Thêm".
  ProductModel monGio(double gia) => ProductModel(
      id: 'p', storeId: 's', name: 'Tiền giờ', category: 'Tiền giờ', unit: 'giờ', productType: 'finished', stockQty: 0,
      minStock: 0, sellPrice: gia, costPrice: 0, stationCode: 'nong', isAvailable: true, isActive: true, isDeleted: false);
  DatTruoc luot(String id, String ten, int tu, int den, String tt) => DatTruoc(
      id: id, tableId: 's1', tenKhach: ten, gioTu: DateTime(2030, 12, 4, tu), gioDen: DateTime(2030, 12, 4, den),
      trangThai: tt, createdAt: DateTime(2030, 11, 29));
  const nam = CustomerModel(
      id: 'k1', storeId: 's', name: 'Anh Nam', phone: '0901111222', loyaltyPts: 0, totalSpent: 0, visitCount: 3,
      isDeleted: false, realBalance: 0);
  final quen = <KhachQuen>[
    (ten: 'Anh Nam', sdt: '0901111222', khach: nam),
    (ten: 'Chị Lan', sdt: '0912345678', khach: null),
    (ten: 'CLB Cầu lông', sdt: null, khach: null),
  ];
  Future<void> moHop(WidgetTester tester, {required int gio}) => tester.pumpWidget(ProviderScope(
        overrides: [
          khachQuenDatProvider.overrideWith((ref) async => quen),
          giaGioCaiDatProvider.overrideWith((ref) async => const {}),
          allProductsProvider.overrideWith((ref) => Stream.value([monGio(200000)])),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF6B6A8A),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DatTruocFormSheet(
                ban: BanTableModel(id: 's1', zoneId: 'z', storeId: 's', label: 'Sân 1', seats: 4, sortOrder: 0, isActive: true, giaGioProductId: 'p'),
                ngay: DateTime(2030, 12, 4),
                trongNgay: [luot('a', 'Anh Hùng', 17, 18, 'da_nhan'), luot('b', 'Chị Lan', 19, 20, 'da_dat')],
                tuMacDinh: DateTime(2030, 12, 4, gio),
              ),
            ),
          ),
        ),
      ));

  testWidgets('hộp đặt mới mở', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await runZonedGuarded(() async {
      await moHop(tester, gio: 21);
      await tester.pumpAndSettle();
    }, (_, __) {});
    expect(tester.takeException(), isNull);
    expect(find.text('Thứ 4, 04/12 · 200.000 đ/giờ'), findsOneWidget);
    expect(find.text('CLB Cầu lông'), findsOneWidget);
    expect(find.textContaining('Trống, không trùng lượt nào · tạm tính 200.000 đ'), findsOneWidget);
    expect(find.text('Đặt Sân 1 · 21:00 – 22:00'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dat_moi_360.png'));
  });

  // Màn hẹp 320, chữ to 1,3 (máy để cỡ chữ lớn): mở hết các dòng, không tràn.
  testWidgets('hộp đặt màn 320 chữ to không tràn', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final loi = <Object>[];
    await runZonedGuarded(() async {
      await moHop(tester, gio: 18);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anh Nam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3 giờ'));
      await tester.tap(find.text('Tiền cọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('500.000'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ghi chú'));
      await tester.pumpAndSettle();
    }, (e, _) => loi.add(e));
    expect(tester.takeException(), isNull);
    expect(loi.where((e) => '$e'.contains('overflow')), isEmpty);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dat_320_chu_to.png'));
  });

  // Sửa lượt đặt đã nhận cọc: không lặp tuần, cọc chỉ để xem, không đổi khách, nút "Lưu".
  testWidgets('hộp sửa lượt đặt đã có cọc', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sua = DatTruoc(
        id: 'b', tableId: 's1', tenKhach: 'Chị Lan', sdt: '0912345678', gioTu: DateTime(2030, 12, 4, 19),
        gioDen: DateTime(2030, 12, 4, 20, 30), trangThai: 'da_dat', createdAt: DateTime(2030, 11, 29), ghiChu: 'Cần bóng mới',
        tienCoc: 100000, cocTrangThai: 'da_thu', cocQuy: 'cash');
    await runZonedGuarded(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          khachQuenDatProvider.overrideWith((ref) async => quen),
          giaGioCaiDatProvider.overrideWith((ref) async => const {}),
          allProductsProvider.overrideWith((ref) => Stream.value([monGio(200000)])),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFF6B6A8A),
            body: Align(
              alignment: Alignment.bottomCenter,
              child: DatTruocFormSheet(
                ban: BanTableModel(id: 's1', zoneId: 'z', storeId: 's', label: 'Sân 1', seats: 4, sortOrder: 0, isActive: true, giaGioProductId: 'p'),
                ngay: DateTime(2030, 12, 4),
                trongNgay: [luot('a', 'Anh Hùng', 17, 18, 'da_nhan'), sua],
                sua: sua,
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }, (_, __) {});
    expect(tester.takeException(), isNull);
    expect(find.text('Sửa lượt đặt · Sân 1'), findsOneWidget);
    expect(find.text('0912345678 · đã cọc, không đổi khách'), findsOneWidget, reason: 'chưa tải được hồ sơ khách vẫn khoá');
    expect(find.text('Đổi'), findsNothing);
    expect(find.byType(TextField), findsOneWidget, reason: 'chỉ còn ô ghi chú');
    expect(find.text('Lặp lại hàng tuần'), findsNothing);
    expect(find.text('Đã cọc 100.000 đ · đang trong ví khách, thanh toán bàn tự trừ'), findsOneWidget);
    expect(find.textContaining('Trống, không trùng lượt nào · tạm tính 300.000 đ'), findsOneWidget, reason: 'không tự trùng với chính nó');
    expect(find.text('CLB Cầu lông'), findsNothing, reason: 'sửa thì không gợi ý khách quen');
    expect(find.text('Lưu'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dat_sua_coc_360.png'));
  });

  testWidgets('hộp đặt đã điền: khách quen, trùng giờ, cọc, lặp tuần', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var trung = '';
    await runZonedGuarded(() async {
      await moHop(tester, gio: 18);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anh Nam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('2 giờ'));
      await tester.pumpAndSettle();
      trung = tester.widget<Text>(find.textContaining('Trùng ')).data!;
      await tester.tap(find.text('Tiền cọc'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('200.000'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      // bỏ giờ trùng: lùi về 20:00–22:00
      for (var i = 0; i < 4; i++) {
        await tester.tap(find.byIcon(Icons.add_rounded).first); // + của ô Bắt đầu
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }, (_, __) {});
    expect(tester.takeException(), isNull);
    expect(trung, 'Trùng Chị Lan 19:00–20:00 · đổi giờ hoặc chọn bàn khác');
    expect(find.text('0901111222 · ví\u00A00\u00A0đ'), findsOneWidget);
    expect(find.textContaining('4 buổi · T4 · 20:00–22:00'), findsOneWidget);
    expect(find.text('Tạm tính 4 buổi · 1.600.000 đ · cọc 200.000 đ'), findsOneWidget);
    expect(find.text('Đặt 4 buổi · nhận cọc 200.000 đ'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/dat_dien_360.png'));
  });

  // Đợt 5: màn Báo cáo tính giờ 7 ngày (dữ liệu giả).
  testWidgets('báo cáo tính giờ', (tester) async {
    await _napPhong();
    tester.view.physicalSize = const Size(360, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    BanTableModel b(String id, String ten) =>
        BanTableModel(id: id, zoneId: 'z', storeId: 's', label: ten, seats: 4, sortOrder: 0, isActive: true, giaGioProductId: 'p');
    LuotChoi l(String ban, int ngay, int gio, int phut, double tienGio, double tienMon) => LuotChoi(
          tableId: ban,
          thanhToanLuc: DateTime(2030, 12, ngay, gio).add(Duration(minutes: phut)),
          doan: [DoanGio(DateTime(2030, 12, ngay, gio), DateTime(2030, 12, ngay, gio).add(Duration(minutes: phut)))],
          tienGio: tienGio,
          tienMon: tienMon,
        );
    final ds = [
      l('s1', 1, 18, 120, 240000, 60000),
      l('s1', 2, 19, 90, 180000, 45000),
      l('s2', 2, 17, 60, 100000, 20000),
      l('s1', 4, 18, 120, 240000, 80000),
      l('s3', 5, 20, 150, 250000, 120000),
      l('s2', 6, 9, 60, 80000, 15000),
      l('s1', 7, 18, 60, 120000, 30000),
      l('s3', 7, 19, 120, 200000, 90000),
    ];
    await runZonedGuarded(() async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          luotChoiProvider.overrideWith((ref, k) async => ds),
          banBaoCaoTinhGioProvider.overrideWith((ref) async => [b('s1', 'Sân 1'), b('s2', 'Sân 2'), b('s3', 'Sân 3')]),
        ],
        // Khối trong tab Doanh thu của Báo cáo, kỳ "Tuần này" 01/12 – 07/12/2030 (28/11: gộp vào Doanh thu).
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            backgroundColor: const Color(0xFFF5F3EF),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              children: [BaoCaoTinhGioKhoi(khoang: (tu: DateTime(2030, 12, 1), den: DateTime(2030, 12, 7)))],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }, (_, __) {});
    expect(tester.takeException(), isNull);
    expect(find.text('Giờ đông khách'), findsOneWidget);
    expect(find.text('Sân 1'), findsOneWidget);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/bao_cao_tinh_gio_360.png'));
  });
}
