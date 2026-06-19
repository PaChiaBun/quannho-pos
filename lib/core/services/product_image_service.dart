import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT IMAGE SERVICE
// Upload từ thư viện/camera HOẶC dùng Gemini AI tạo ảnh
// ─────────────────────────────────────────────────────────────────────────────
class ProductImageService {
  static const _bucket = 'product-images';
  // 🔑 Gemini API Key — Tạo Ảnh Món - Quán Nhỏ
  static const _geminiApiKey = 'AIzaSyCfLxMSN9FAPWW_S611wnHrvhOFoqBF4Vs';

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
    final filename = '${_uuid.v4()}.${mime.split('/').last}';
    final storage = Supabase.instance.client.storage.from(_bucket);

    await storage.uploadBinary(
      filename,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );

    return storage.getPublicUrl(filename);
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
