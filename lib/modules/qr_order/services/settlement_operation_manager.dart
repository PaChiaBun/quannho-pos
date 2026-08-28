import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

/// Quản lý idempotency operation key và fingerprint tài chính cho quá trình quyết toán bàn.
/// Đảm bảo:
/// 1. Khi retry cùng intent (lỗi mạng/timeout), tái sử dụng đúng idempotency key cũ.
/// 2. Khi thay đổi customer, points, coupon, surcharge hoặc payment method -> sinh key mới.
/// 3. Khi hoàn tất quyết toán thành công -> giải phóng (clear) pending key.
class SettlementOperationManager {
  static const _uuid = Uuid();

  String? _pendingKey;
  String? _pendingFingerprint;

  String? get currentPendingKey => _pendingKey;
  String? get currentPendingFingerprint => _pendingFingerprint;
  bool get hasPendingOperation => _pendingKey != null;

  /// Chuẩn hóa số tiền về nguyên VNĐ, từ chối tuyệt đối NaN / Infinity.
  static int normalizeMoney(double value) {
    if (!value.isFinite) {
      throw ArgumentError(
        'Financial intent money values must be finite numbers, got: $value',
      );
    }
    return value.round();
  }

  /// Tính chuỗi SHA-256 fingerprint từ các tham số tài chính chuẩn hóa.
  /// Tuyệt đối không biến đổi intent (như clamp points) để phản ánh trung thực intent phía client.
  static String computeIntentFingerprint({
    required String sessionId,
    required String paymentMethod,
    String? customerId,
    int pointsUsed = 0,
    String? couponCode,
    double surcharge = 0,
    double discount = 0,
  }) {
    final normSession = sessionId.trim();
    final normPay = paymentMethod.trim().toLowerCase();
    final normCust = (customerId ?? '').trim();
    final normCoupon = (couponCode ?? '').trim().toLowerCase();
    final sur = normalizeMoney(surcharge);
    final disc = normalizeMoney(discount);

    final raw =
        '$normSession:$normPay:$normCust:$pointsUsed:$normCoupon:$sur:$disc';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  /// Lấy operation key hiện tại nếu intent không đổi (cho retry an toàn),
  /// hoặc sinh UUID operation key mới nếu intent tài chính đã thay đổi.
  String getOrCreateKey({
    required String sessionId,
    required String paymentMethod,
    String? customerId,
    int pointsUsed = 0,
    String? couponCode,
    double surcharge = 0,
    double discount = 0,
  }) {
    final fp = computeIntentFingerprint(
      sessionId: sessionId,
      paymentMethod: paymentMethod,
      customerId: customerId,
      pointsUsed: pointsUsed,
      couponCode: couponCode,
      surcharge: surcharge,
      discount: discount,
    );

    if (_pendingKey != null && _pendingFingerprint == fp) {
      return _pendingKey!;
    }

    _pendingFingerprint = fp;
    _pendingKey = _uuid.v4();
    return _pendingKey!;
  }

  /// Giải phóng pending key khi giao dịch thành công hoặc khi reset màn hình.
  void clear() {
    _pendingKey = null;
    _pendingFingerprint = null;
  }
}

/// Helper tính toán contract tài chính và điều phối quote reconfirmation cho checkout
class SettlementQuoteHelper {
  /// Tính toán tổng tiền phải trả trước khi gửi thanh toán
  /// [amountBeforeSurcharge] = subtotal - discount
  /// [surcharge] = phụ phí
  /// return oldPayableTotal = amountBeforeSurcharge + surcharge
  static double computeOldPayableTotal({
    required double amountBeforeSurcharge,
    required double surcharge,
  }) {
    return (amountBeforeSurcharge + surcharge).clamp(0.0, double.infinity);
  }

  /// Tính amountBeforeSurcharge mới khi người dùng xác nhận authoritative quote
  /// [quoteTotal] = quote.total
  /// [quoteSurcharge] = quote.surcharge
  /// return newAmountBeforeSurcharge = quote.total - quote.surcharge (tức quote.subtotal - quote.discount)
  static double computeConfirmedAmountBeforeSurcharge({
    required double quoteTotal,
    required double quoteSurcharge,
  }) {
    return (quoteTotal - quoteSurcharge).clamp(0.0, double.infinity);
  }
}
