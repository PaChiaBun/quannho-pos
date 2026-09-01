import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

abstract class SettlementOperationStorage {
  Future<String?> read(String key);
  Future<bool> write(String key, String value);
  Future<bool> remove(String key);
}

class SharedPreferencesSettlementOperationStorage
    implements SettlementOperationStorage {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<bool> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setString(key, value);
  }

  @override
  Future<bool> remove(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.remove(key);
  }
}

/// Giữ idempotency key bền vững theo store + session.
/// Retry sau timeout hoặc sau khi app khởi động lại dùng lại cùng key nếu
/// financial intent không đổi.
class SettlementOperationManager {
  static const _uuid = Uuid();
  static const _storagePrefix = 'settlement_v5_pending';

  final SettlementOperationStorage storage;
  String? _pendingScope;
  String? _pendingKey;
  String? _pendingFingerprint;

  SettlementOperationManager({SettlementOperationStorage? storage})
    : storage = storage ?? SharedPreferencesSettlementOperationStorage();

  String? get currentPendingKey => _pendingKey;
  String? get currentPendingFingerprint => _pendingFingerprint;
  bool get hasPendingOperation => _pendingKey != null;

  static int normalizeMoney(double value) {
    if (!value.isFinite) {
      throw ArgumentError(
        'Financial intent money values must be finite numbers, got: $value',
      );
    }
    return value.round();
  }

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

  String _scope(String storeId, String sessionId) {
    final raw = '${storeId.trim()}:${sessionId.trim()}';
    return '$_storagePrefix:${sha256.convert(utf8.encode(raw))}';
  }

  Future<String> getOrCreatePersistentKey({
    required String storeId,
    required String sessionId,
    required String paymentMethod,
    String? customerId,
    int pointsUsed = 0,
    String? couponCode,
    double surcharge = 0,
    double discount = 0,
  }) async {
    final scope = _scope(storeId, sessionId);
    final fingerprint = computeIntentFingerprint(
      sessionId: sessionId,
      paymentMethod: paymentMethod,
      customerId: customerId,
      pointsUsed: pointsUsed,
      couponCode: couponCode,
      surcharge: surcharge,
      discount: discount,
    );

    if (_pendingScope != scope) {
      _pendingScope = scope;
      _pendingKey = null;
      _pendingFingerprint = null;
      final raw = await storage.read(scope);
      if (raw != null) {
        try {
          final saved = jsonDecode(raw) as Map<String, dynamic>;
          _pendingKey = saved['idempotency_key'] as String?;
          _pendingFingerprint = saved['fingerprint'] as String?;
        } catch (_) {
          await storage.remove(scope);
        }
      }
    }

    if (_pendingKey != null && _pendingFingerprint == fingerprint) {
      return _pendingKey!;
    }

    final key = _uuid.v4();
    final saved = await storage.write(
      scope,
      jsonEncode({
        'idempotency_key': key,
        'fingerprint': fingerprint,
        'store_id': storeId,
        'session_id': sessionId,
      }),
    );
    if (!saved) {
      throw StateError('Không thể lưu khóa thanh toán an toàn trên thiết bị');
    }
    _pendingKey = key;
    _pendingFingerprint = fingerprint;
    return key;
  }

  /// Chỉ gọi sau khi server xác nhận commit/replay, hoặc người dùng hủy một
  /// quote đã bị server từ chối trước commit.
  Future<void> clearPersistent({
    required String storeId,
    required String sessionId,
  }) async {
    final scope = _scope(storeId, sessionId);
    await storage.remove(scope);
    if (_pendingScope == scope) {
      _pendingScope = null;
      _pendingKey = null;
      _pendingFingerprint = null;
    }
  }

  /// API thuần bộ nhớ dành cho các phép tính/test cũ. Luồng production phải
  /// dùng getOrCreatePersistentKey trước khi gọi RPC.
  String getOrCreateKey({
    required String sessionId,
    required String paymentMethod,
    String? customerId,
    int pointsUsed = 0,
    String? couponCode,
    double surcharge = 0,
    double discount = 0,
  }) {
    final fingerprint = computeIntentFingerprint(
      sessionId: sessionId,
      paymentMethod: paymentMethod,
      customerId: customerId,
      pointsUsed: pointsUsed,
      couponCode: couponCode,
      surcharge: surcharge,
      discount: discount,
    );
    if (_pendingKey != null && _pendingFingerprint == fingerprint) {
      return _pendingKey!;
    }
    _pendingFingerprint = fingerprint;
    _pendingKey = _uuid.v4();
    return _pendingKey!;
  }

  void clear() {
    _pendingScope = null;
    _pendingKey = null;
    _pendingFingerprint = null;
  }
}

class SettlementQuoteHelper {
  static double computeOldPayableTotal({
    required double amountBeforeSurcharge,
    required double surcharge,
  }) {
    return (amountBeforeSurcharge + surcharge).clamp(0.0, double.infinity);
  }

  static double computeConfirmedAmountBeforeSurcharge({
    required double quoteTotal,
    required double quoteSurcharge,
  }) {
    return (quoteTotal - quoteSurcharge).clamp(0.0, double.infinity);
  }
}
