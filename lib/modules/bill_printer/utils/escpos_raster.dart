// lib/modules/bill_printer/utils/escpos_raster.dart
// Đổi ảnh RGBA (từ PDF hoá đơn) thành lệnh ESC/POS in ảnh (GS v 0) để gửi thẳng vào máy in nhiệt
// mà không cần driver đồ hoạ của hãng. Thuần Dart, có test.
import 'dart:typed_data';

/// Chuyển ảnh RGBA thành các lệnh GS v 0, chia dải [bandRows] dòng để máy in không tràn bộ đệm.
/// [dotsWide] là số chấm ngang của đầu in (58mm=384, 80mm=576); ảnh rộng hơn bị cắt, hẹp hơn
/// được căn trái và đệm trắng. Điểm có alpha thấp coi là nền trắng.
Uint8List escposRaster(
  Uint8List rgba,
  int width,
  int height, {
  required int dotsWide,
  int threshold = 160,
  int bandRows = 128,
}) {
  final bytesPerRow = (dotsWide + 7) ~/ 8;
  final out = BytesBuilder();
  for (var y0 = 0; y0 < height; y0 += bandRows) {
    final rows = (y0 + bandRows <= height) ? bandRows : height - y0;
    final data = Uint8List(bytesPerRow * rows);
    for (var r = 0; r < rows; r++) {
      final y = y0 + r;
      final maxX = width < dotsWide ? width : dotsWide;
      for (var x = 0; x < maxX; x++) {
        final i = (y * width + x) * 4;
        final a = rgba[i + 3];
        if (a < 128) continue; // trong suốt = trắng
        final lum = (rgba[i] * 299 + rgba[i + 1] * 587 + rgba[i + 2] * 114) ~/ 1000;
        if (lum < threshold) {
          data[r * bytesPerRow + (x >> 3)] |= 0x80 >> (x & 7);
        }
      }
    }
    out
      ..add([0x1D, 0x76, 0x30, 0x00, bytesPerRow & 0xFF, bytesPerRow >> 8, rows & 0xFF, rows >> 8])
      ..add(data);
  }
  return out.toBytes();
}

/// Khởi tạo máy in (trước ảnh).
final Uint8List escposInit = Uint8List.fromList([0x1B, 0x40]);

/// Đẩy giấy thêm [feedLines] dòng rồi cắt (cắt giấy một phần/toàn phần tuỳ máy).
Uint8List escposFeedAndCut({int feedLines = 4}) =>
    Uint8List.fromList([0x1B, 0x64, feedLines, 0x1D, 0x56, 0x42, 0x00]);
