import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/utils/app_logger.dart';

/// Font bill: nạp từ file đi kèm app (assets/fonts, Noto Sans, giấy phép OFL) TRƯỚC,
/// Google Fonts chỉ là dự phòng. Font đi kèm có đủ chữ Việt và không cần mạng, nên
/// bill không còn bị ô vuông / chậm khi mở lại app lúc mạng yếu.
class BillFonts {
  BillFonts._();

  static const regularAsset = 'assets/fonts/NotoSans-Regular.ttf';
  static const boldAsset = 'assets/fonts/NotoSans-Bold.ttf';
  static const semiBoldAsset = 'assets/fonts/NotoSans-SemiBold.ttf';

  /// Giới hạn chờ khi phải tải từ Google (dự phòng) để không treo lệnh in.
  static const Duration googleTimeout = Duration(seconds: 8);

  static pw.Font? _regular;
  static pw.Font? _bold;
  static pw.Font? _semiBold;

  static Future<pw.Font> regular() async =>
      _regular ??= await _load(regularAsset, PdfGoogleFonts.notoSansRegular);

  static Future<pw.Font> bold() async =>
      _bold ??= await _load(boldAsset, PdfGoogleFonts.notoSansBold);

  /// Bán đậm; không nạp được cả hai nguồn thì trả null (nơi gọi dùng Bold thường).
  static Future<pw.Font?> semiBold() async {
    if (_semiBold != null) return _semiBold;
    try {
      return _semiBold = await _load(
        semiBoldAsset,
        PdfGoogleFonts.notoSansSemiBold,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<pw.Font> _load(
    String asset,
    Future<pw.Font> Function() google,
  ) async {
    try {
      final data = await rootBundle.load(asset);
      return pw.Font.ttf(data);
    } catch (e) {
      AppLogger.warning(
        'printer',
        'Không nạp được font đi kèm $asset ($e) -> thử tải từ Google Fonts',
      );
    }
    return google().timeout(googleTimeout);
  }

  @pragma('vm:prefer-inline')
  static void resetForTest() {
    _regular = null;
    _bold = null;
    _semiBold = null;
  }
}
