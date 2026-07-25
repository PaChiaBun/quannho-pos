import 'dart:typed_data';
import 'watermark_helper_stub.dart'
    if (dart.library.html) 'watermark_helper_web.dart' as impl;

class WatermarkHelper {
  static Future<Uint8List?> addWatermarkWeb(Uint8List originalBytes, String dateTimeText, String locationText) {
    return impl.addWatermarkWeb(originalBytes, dateTimeText, locationText);
  }
}
