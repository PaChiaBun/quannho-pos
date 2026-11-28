import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/modules/bill_printer/utils/escpos_raster.dart';

Uint8List _img(int w, int h, bool Function(int x, int y) black) {
  final p = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final v = black(x, y) ? 0 : 255;
      p[i] = v; p[i + 1] = v; p[i + 2] = v; p[i + 3] = 255;
    }
  }
  return p;
}

void main() {
  test('một dải: tiêu đề GS v 0 và bit đúng vị trí', () {
    // Ảnh 16x2: điểm đen ở (0,0) và (9,1); máy in rộng 16 chấm => 2 byte/dòng.
    final out = escposRaster(
        _img(16, 2, (x, y) => (x == 0 && y == 0) || (x == 9 && y == 1)), 16, 2,
        dotsWide: 16);
    expect(out.take(8), [0x1D, 0x76, 0x30, 0x00, 2, 0, 2, 0]);
    final data = out.skip(8).toList();
    expect(data, [0x80, 0x00, 0x00, 0x40]); // dòng 0: bit0; dòng 1: bit 9 => byte2 bit 0x40
  });

  test('chia dải khi ảnh cao hơn bandRows', () {
    final out = escposRaster(_img(8, 5, (x, y) => true), 8, 5, dotsWide: 8, bandRows: 2);
    // 3 dải: 2 + 2 + 1 dòng; mỗi dải 8 byte tiêu đề + dữ liệu
    expect(out.length, (8 + 2) + (8 + 2) + (8 + 1));
    expect(out[6], 2); // dải đầu 2 dòng
  });

  test('điểm trong suốt coi là trắng, ảnh hẹp hơn đầu in được đệm', () {
    final p = Uint8List.fromList([0, 0, 0, 0]); // 1 điểm đen nhưng alpha 0
    final out = escposRaster(p, 1, 1, dotsWide: 8);
    expect(out.skip(8).single, 0);
  });

  test('feed + cut', () {
    expect(escposFeedAndCut(feedLines: 3), [0x1B, 0x64, 3, 0x1D, 0x56, 0x42, 0x00]);
  });
}
