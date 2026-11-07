import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:quannho_pos/core/services/product_image_service.dart';

Uint8List _noisePng(int w, int h, {bool alpha = false}) {
  final rnd = math.Random(7);
  final im = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  for (final p in im) {
    p
      ..r = rnd.nextInt(256)
      ..g = rnd.nextInt(256)
      ..b = rnd.nextInt(256);
    if (alpha) p.a = 0;
  }
  return Uint8List.fromList(img.encodePng(im));
}

void main() {
  group('ProductImageService.prepareForUpload', () {
    test('ảnh lớn được thu nhỏ về <= 1024px và nén thành JPEG nhẹ hơn nhiều', () {
      final original = _noisePng(2400, 1600);
      final r = ProductImageService.prepareForUpload(original, 'image/png');
      final decoded = img.decodeImage(r.bytes)!;
      expect(r.mime, 'image/jpeg');
      expect(r.ext, 'jpg');
      expect(math.max(decoded.width, decoded.height), lessThanOrEqualTo(1024));
      expect(r.bytes.length, lessThan(original.length ~/ 3));
    });

    test('ảnh PNG trong suốt được dán nền trắng (không bị đen)', () {
      final r = ProductImageService.prepareForUpload(
        _noisePng(300, 300, alpha: true),
        'image/png',
      );
      final px = img.decodeImage(r.bytes)!.getPixel(10, 10);
      expect(r.mime, 'image/jpeg');
      expect(px.r, greaterThan(230));
      expect(px.g, greaterThan(230));
      expect(px.b, greaterThan(230));
    });

    test('dữ liệu hỏng thì giữ nguyên bản gốc (máy chủ sẽ xử lý sau)', () {
      final junk = Uint8List.fromList([1, 2, 3, 4, 5]);
      final r = ProductImageService.prepareForUpload(junk, 'image/png');
      expect(r.bytes, junk);
      expect(r.mime, 'image/png');
    });
  });
}
