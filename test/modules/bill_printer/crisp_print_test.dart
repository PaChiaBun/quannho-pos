import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quannho_pos/modules/bill_printer/drivers/sunmi_builtin_driver.dart';

/// Tạo ảnh RGBA [w]x[h] bằng hàm f(x, y) -> (r,g,b,a).
Uint8List rgbaOf(int w, int h, List<int> Function(int x, int y) f) {
  final b = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = f(x, y);
      final i = (y * w + x) * 4;
      b[i] = c[0]; b[i + 1] = c[1]; b[i + 2] = c[2]; b[i + 3] = c[3];
    }
  }
  return b;
}

void main() {
  test('ảnh ra đúng bề rộng đầu in và chỉ gồm đen/trắng thuần (hết điểm xám gây nhoè)', () {
    final rgba = rgbaOf(1152, 90, (x, y) {
      final v = x < 570 ? 0 : (x < 582 ? 128 : 255);
      return [v, v, v, 255];
    });
    final out = img.decodePng(crispBlackWhiteFromRgba(rgba, 1152, 90, targetWidth: 384))!;
    expect(out.width, 384);
    expect(out.height, 30);
    var gray = 0;
    for (final p in out) {
      final l = p.r.toInt();
      if (l != 0 && l != 255) gray++;
    }
    expect(gray, 0);
    expect(out.getPixel(10, 5).r, 0);
    expect(out.getPixel(380, 5).r, 255);
  });

  test('ngưỡng thấp làm nét mảnh hơn với nét xám', () {
    final rgba = rgbaOf(768, 40, (x, y) => (x >= 200 && x < 220) ? [110, 110, 110, 255] : [255, 255, 255, 255]);
    int blacks(int th) {
      final o = img.decodePng(crispBlackWhiteFromRgba(rgba, 768, 40, targetWidth: 384, threshold: th))!;
      var n = 0;
      for (final p in o) {
        if (p.r == 0) n++;
      }
      return n;
    }
    expect(blacks(100) < blacks(150), isTrue);
  });

  test('nền trong suốt coi như trắng; mực đen đặc vẫn đen', () {
    final transparent = rgbaOf(768, 20, (x, y) => [0, 0, 0, 0]);
    var o = img.decodePng(crispBlackWhiteFromRgba(transparent, 768, 20, targetWidth: 384))!;
    var blacks = 0;
    for (final p in o) {
      if (p.r == 0) blacks++;
    }
    expect(blacks, 0);
    final ink = rgbaOf(768, 20, (x, y) => [0, 0, 0, 255]);
    o = img.decodePng(crispBlackWhiteFromRgba(ink, 768, 20, targetWidth: 384))!;
    expect(o.getPixel(5, 5).r, 0);
  });

  test('độ đậm 1–5 ánh xạ sang ngưỡng tăng dần; ngoài khoảng bị chặn; mặc định 3', () {
    final t = [for (var d = 1; d <= 5; d++) SunmiBuiltinDriver.thresholdForDarkness(d)];
    for (var i = 1; i < t.length; i++) {
      expect(t[i] > t[i - 1], isTrue);
    }
    expect(SunmiBuiltinDriver.thresholdForDarkness(0), t.first);
    expect(SunmiBuiltinDriver.thresholdForDarkness(9), t.last);
    expect(SunmiBuiltinDriver.thresholdForDarkness(3), SunmiBuiltinDriver.kBlackThreshold);
  });
}
