// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

Future<Uint8List?> addWatermarkWeb(Uint8List originalBytes, String dateTimeText, String locationText) async {
  try {
    final completer = Completer<Uint8List?>();
    final img = html.ImageElement();
    
    // Dùng Base64 Data URL thay cho Blob ObjectURL — hỗ trợ 100% mọi định dạng ảnh (PNG, JPEG, WebP)
    final base64Src = base64Encode(originalBytes);
    img.src = 'data:image/png;base64,$base64Src';

    img.onLoad.listen((_) {
      try {
        final nw = img.naturalWidth ?? 0;
        final nh = img.naturalHeight ?? 0;
        final width = nw > 0 ? nw : (img.width != null && img.width! > 0 ? img.width! : 600);
        final height = nh > 0 ? nh : (img.height != null && img.height! > 0 ? img.height! : 600);

        double targetW = width.toDouble();
        double targetH = height.toDouble();

        if (targetW > 600) {
          targetH = (targetH * 600) / targetW;
          targetW = 600;
        }
        if (targetW < 100) targetW = 600;
        if (targetH < 100) targetH = 600;

        final canvas = html.CanvasElement(width: targetW.toInt(), height: targetH.toInt());
        final ctx = canvas.context2D;

        // 1. Vẽ ảnh
        ctx.drawImageScaled(img, 0, 0, targetW, targetH);

        // 2. Vẽ khung đen mờ 85%
        final overlayH = 75.0;
        ctx.fillStyle = 'rgba(0, 0, 0, 0.85)';
        ctx.fillRect(0, targetH - overlayH, targetW, overlayH);

        // 3. Vẽ vạch màu cam bên trái
        ctx.fillStyle = '#EA580C';
        ctx.fillRect(0, targetH - overlayH, 8, overlayH);

        // 4. Vẽ chữ Thời gian & Vị trí
        ctx.font = 'bold 16px Arial, sans-serif';
        ctx.fillStyle = '#FFD700'; // Vàng rực
        ctx.fillText('THOI GIAN: $dateTimeText', 18, targetH - overlayH + 28);

        ctx.font = 'bold 14px Arial, sans-serif';
        ctx.fillStyle = '#FFFFFF';
        ctx.fillText('VI TRI: $locationText', 18, targetH - overlayH + 56);

        // 5. Xuất ảnh JPEG
        final dataUrl = canvas.toDataUrl('image/jpeg', 0.88);
        final base64Str = dataUrl.split(',').last;
        final resultBytes = base64.decode(base64Str);
        completer.complete(resultBytes);
      } catch (e) {
        // ignore: avoid_print
        print('[WatermarkWeb] Canvas draw error: $e');
        completer.complete(null);
      }
    });

    img.onError.listen((e) {
      // ignore: avoid_print
      print('[WatermarkWeb] Image load error: $e');
      completer.complete(null);
    });

    return completer.future;
  } catch (e) {
    // ignore: avoid_print
    print('[WatermarkWeb] Outer error: $e');
    return null;
  }
}
