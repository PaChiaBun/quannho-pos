// Xem thử dải "Đang mất mạng" trên màn Phiếu bếp thật (không phải test thật):
// FLUTTER_ROOT=~/flutter flutter test scratch/mat_mang_preview_test.dart --update-goldens
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quannho_pos/core/providers/app_providers.dart';
import 'package:quannho_pos/core/repositories/kitchen_repository.dart';
import 'package:quannho_pos/core/services/net_status.dart';
import 'package:quannho_pos/core/theme/app_theme.dart';
import 'package:quannho_pos/core/widgets/net_status_banner.dart';
import 'package:quannho_pos/screens/kitchen_screen.dart';

class _Repo extends KitchenRepository {
  @override
  Stream<List<TicketWithItems>> watchActiveTickets() => Stream.value(const []);
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // Không nạp phông biểu tượng thì biểu tượng thành ô vuông rỗng trong ảnh.
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytesSync();
    await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.view(icons.buffer)))).load();
    for (final e in {'regular': 'Regular', '400': 'Regular', '500': 'Medium', '600': 'SemiBold', '700': 'Bold', '800': 'ExtraBold', '900': 'ExtraBold'}.entries) {
      final data = File('test/fonts/PlusJakartaSans-${e.value}.ttf').readAsBytesSync();
      await (FontLoader('PlusJakartaSans_${e.key}')..addFont(Future.value(ByteData.view(data.buffer)))).load();
    }
  });

  for (final offline in [false, true]) {
    testWidgets('xem thử ${offline ? 'mat_mang' : 'co_mang'}', (tester) async {
      tester.view.physicalSize = const Size(360, 800); // Sunmi V3
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28); // thanh trạng thái
      addTearDown(tester.view.reset);
      addTearDown(NetStatus.reset);
      NetStatus.offline.value = offline;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          kitchenRepositoryProvider.overrideWithValue(_Repo()),
          voidNoticesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) => NetStatusBanner(child: child!),
          home: const KitchenScreen(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('mat_mang_${offline ? 'bat' : 'tat'}.png'));
    });
  }
}
