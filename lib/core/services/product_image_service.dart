import 'dart:math' as math;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT IMAGE SERVICE
// Upload từ thư viện/camera HOẶC dùng Gemini AI tạo ảnh
// ─────────────────────────────────────────────────────────────────────────────
class ProductImageService {
  static const _bucket = 'product-images';
  // (Đã gỡ khóa Gemini ghi cứng 13/10/2026: không dùng ở đâu và đã lộ trong bản web. Nếu cần AI, đặt khóa phía máy chủ.)

  final _uuid = const Uuid();
  final _picker = ImagePicker();

  // ── Chọn ảnh từ gallery ─────────────────────────────────────────────────
  Future<XFile?> pickFromGallery() =>
      _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);

  // ── Chụp ảnh từ camera ──────────────────────────────────────────────────
  Future<XFile?> pickFromCamera() =>
      _picker.pickImage(source: ImageSource.camera, imageQuality: 85);

  // ── AI tạo ảnh từ tên sản phẩm ─────────────────────────────────────────
  /// Trả về Uint8List bytes của ảnh JPEG, hoặc null nếu thất bại
  Future<Uint8List?> generateWithGemini(String productName) async {
    // Hugging Face Inference API — miễn phí, không cần login
    const hfUrl =
        'https://api-inference.huggingface.co/models/stabilityai/stable-diffusion-2-1';

    // Build prompt — đặt tên món thật rõ, dùng cả tên gốc + context
    final prompt = '$productName food dish, '
        'Vietnamese street food, professional food photography, '
        'restaurant quality, colorful, fresh ingredients, '
        'soft natural light, shallow depth of field, '
        'white ceramic plate or bowl, appetizing presentation, '
        '8k uhd, food magazine style, no text no watermark';

    final negativePrompt =
        'blurry, low quality, cartoon, illustration, drawing, '
        'text, watermark, logo, collage, multiple dishes';

    final res = await http
        .post(
          Uri.parse(hfUrl),
          headers: {'Content-Type': 'application/json'},
          body: '{"inputs":"$prompt",'
              '"parameters":{'
              '"negative_prompt":"$negativePrompt",'
              '"width":512,"height":512,'
              '"num_inference_steps":25,'
              '"guidance_scale":8.0}}',
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode == 503) {
      // Model đang khởi động (cold start) — thông báo thử lại
      throw Exception('AI đang khởi động, vui lòng thử lại sau 30 giây');
    }
    if (res.statusCode != 200) {
      // Fallback: thử Pollinations với timeout ngắn hơn
      return _tryPollinations(productName);
    }
    if (res.bodyBytes.isEmpty) return null;
    return res.bodyBytes;
  }

  Future<Uint8List?> _tryPollinations(String productName) async {
    try {
      final encoded = Uri.encodeComponent(
        'food photo $productName Vietnamese cuisine white background appetizing');
      final uri = Uri.https('image.pollinations.ai', '/prompt/$encoded', {
        'width': '400', 'height': '400', 'nologo': 'true', 'model': 'flux',
        'seed': '${DateTime.now().second}',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 90));
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) return res.bodyBytes;
    } catch (_) {}
    return null;
  }

  // ── Upload lên Supabase Storage ─────────────────────────────────────────
  /// Upload file (từ picker) → trả về public URL
  Future<String> uploadFile(XFile file) async {
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final dotIdx = name.lastIndexOf('.');
    final ext = dotIdx >= 0 ? name.substring(dotIdx + 1) : 'jpg';
    final mime = _mime(ext);
    return _upload(bytes, mime);
  }

  /// Upload bytes (từ AI) → trả về public URL
  Future<String> uploadBytes(Uint8List bytes, {String ext = 'png'}) async {
    return _upload(bytes, _mime(ext));
  }

  Future<String> _upload(Uint8List bytes, String mime) async {
    // Nén trước khi tải (ảnh chụp điện thoại thường 2–5 MB → vài trăm KB). Máy chủ còn có bộ nén
    // thứ hai (services/image_optimizer.py) cho các bản app cũ.
    final prepared = prepareForUpload(bytes, mime);
    final filename = '${_uuid.v4()}.${prepared.ext}';
    final storage = Supabase.instance.client.storage.from(_bucket);

    await storage.uploadBinary(
      filename,
      prepared.bytes,
      fileOptions: FileOptions(contentType: prepared.mime, upsert: false),
    );

    return storage.getPublicUrl(filename);
  }

  /// Cạnh dài tối đa và chất lượng JPEG khi nén ảnh món.
  static const int maxSide = 1024;
  static const int jpegQuality = 80;

  /// Thu nhỏ + nén ảnh thành JPEG. Không đọc được ảnh thì trả lại nguyên bản (máy chủ sẽ xử lý sau).
  /// Chỉ dùng bản nén nếu thật sự nhỏ hơn bản gốc.
  static ({Uint8List bytes, String mime, String ext}) prepareForUpload(
    Uint8List original,
    String mime,
  ) {
    ({Uint8List bytes, String mime, String ext}) keep() =>
        (bytes: original, mime: mime, ext: mime.split('/').last);
    try {
      var image = img.decodeImage(original);
      if (image == null) return keep();
      image = img.bakeOrientation(image); // xoay đúng chiều theo EXIF
      final longest = math.max(image.width, image.height);
      if (longest > maxSide) {
        final scale = maxSide / longest;
        image = img.copyResize(
          image,
          width: (image.width * scale).round(),
          height: (image.height * scale).round(),
          interpolation: img.Interpolation.average,
        );
      }
      if (image.hasAlpha) {
        // JPEG không có nền trong suốt: dán lên nền trắng thay vì để đen
        final bg = img.Image(width: image.width, height: image.height);
        img.fill(bg, color: img.ColorRgb8(255, 255, 255));
        img.compositeImage(bg, image);
        image = bg;
      }
      final out = Uint8List.fromList(img.encodeJpg(image, quality: jpegQuality));
      if (out.length >= original.length && longest <= maxSide) return keep();
      return (bytes: out, mime: 'image/jpeg', ext: 'jpg');
    } catch (_) {
      return keep();
    }
  }

  // ── Xoá ảnh cũ ─────────────────────────────────────────────────────────
  /// Xoá file từ URL (khi thay ảnh mới)
  Future<void> deleteByUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      final filename = uri.pathSegments.last;
      await Supabase.instance.client.storage
          .from(_bucket)
          .remove([filename]);
    } catch (_) {}
  }

  String _mime(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        _ => 'image/png',
      };
}
