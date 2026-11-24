import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/modules/tinh_gio/loai_hinh.dart';
import 'package:quannho_pos/modules/tinh_gio/tinh_gio_widgets.dart';

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
    tester.view.physicalSize = const Size(1180, 620);
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
                    Text(l.ten,
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
}
