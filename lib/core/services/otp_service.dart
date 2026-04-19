// lib/core/services/otp_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// OTP Service — Tạo và gửi OTP qua EmailJS, verify locally
// Không cần server — EmailJS gửi trực tiếp từ client
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class OtpService {
  // ── EmailJS config — điền sau khi tạo tài khoản ──────────────────────────
  // Xem hướng dẫn ở cuối file hoặc trong README
  static const _serviceId  = 'YOUR_SERVICE_ID';   // emailjs.com service ID
  static const _templateId = 'YOUR_TEMPLATE_ID';  // email template ID
  static const _publicKey  = 'YOUR_PUBLIC_KEY';   // emailjs public key

  // ── Lưu trữ OTP tạm thời ─────────────────────────────────────────────────
  static const _kOtpHash    = 'otp_hash_temp';
  static const _kOtpExpiry  = 'otp_expiry_temp';
  static const _otpLifetime = Duration(minutes: 5);

  // ── API endpoint ──────────────────────────────────────────────────────────
  static const _emailJsUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  // ─────────────────────────────────────────────────────────────────────────
  // SEND OTP — Tạo OTP 6 số, lưu hash, gửi qua EmailJS
  // Trả về true nếu gửi thành công
  // ─────────────────────────────────────────────────────────────────────────
  Future<OtpResult> sendOtp({
    required String toEmail,
    required String shopName,
  }) async {
    // Kiểm tra config
    if (_serviceId == 'YOUR_SERVICE_ID') {
      return OtpResult.notConfigured;
    }

    try {
      // 1. Tạo OTP 6 số ngẫu nhiên
      final otp = _generateOtp();

      // 2. Lưu hash + expiry vào SharedPreferences
      final prefs   = await SharedPreferences.getInstance();
      final expiry  = DateTime.now().add(_otpLifetime).millisecondsSinceEpoch;
      final hash    = _hashOtp(otp);
      await prefs.setString(_kOtpHash,   hash);
      await prefs.setInt   (_kOtpExpiry, expiry);

      // 3. Gửi email qua EmailJS
      final response = await http.post(
        Uri.parse(_emailJsUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id':  _serviceId,
          'template_id': _templateId,
          'user_id':     _publicKey,
          'template_params': {
            'to_email':  toEmail,
            'otp_code':  otp,
            'app_name':  shopName,
            'expiry_min': '5',
          },
        }),
      );

      if (response.statusCode == 200) {
        return OtpResult.success;
      } else {
        return OtpResult.sendFailed;
      }
    } catch (_) {
      return OtpResult.networkError;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VERIFY OTP — So khớp OTP người dùng nhập với hash đã lưu
  // ─────────────────────────────────────────────────────────────────────────
  Future<OtpVerifyResult> verifyOtp(String inputOtp) async {
    final prefs = await SharedPreferences.getInstance();

    final savedHash  = prefs.getString(_kOtpHash);
    final expiryMs   = prefs.getInt   (_kOtpExpiry);

    // Chưa có OTP nào đang chờ
    if (savedHash == null || expiryMs == null) {
      return OtpVerifyResult.noOtpPending;
    }

    // OTP đã hết hạn
    if (DateTime.now().millisecondsSinceEpoch > expiryMs) {
      await _clearOtp(prefs);
      return OtpVerifyResult.expired;
    }

    // So khớp
    final inputHash = _hashOtp(inputOtp.trim());
    if (inputHash == savedHash) {
      await _clearOtp(prefs);  // Xóa sau khi dùng
      return OtpVerifyResult.valid;
    }

    return OtpVerifyResult.invalid;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────────────────────────────────

  /// Sinh OTP 6 số ngẫu nhiên
  String _generateOtp() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  /// Hash OTP đơn giản (SHA không cần thiết, dùng base64 + salt)
  String _hashOtp(String otp) {
    final salted = 'quannho_salt_$otp';
    return base64Encode(utf8.encode(salted));
  }

  Future<void> _clearOtp(SharedPreferences prefs) async {
    await prefs.remove(_kOtpHash);
    await prefs.remove(_kOtpExpiry);
  }

  /// Kiểm tra còn bao nhiêu giây đến khi OTP hết hạn
  Future<int> remainingSeconds() async {
    final prefs    = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_kOtpExpiry);
    if (expiryMs == null) return 0;
    final remaining = expiryMs - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

  /// Kiểm tra có OTP đang chờ verify không
  Future<bool> hasPendingOtp() async {
    final prefs    = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_kOtpExpiry);
    if (expiryMs == null) return false;
    return DateTime.now().millisecondsSinceEpoch < expiryMs;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ENUMS
// ─────────────────────────────────────────────────────────────────────────────
enum OtpResult {
  success,
  notConfigured,  // EmailJS chưa được cấu hình
  sendFailed,     // EmailJS trả về lỗi
  networkError,   // Không có internet
}

enum OtpVerifyResult {
  valid,          // OTP đúng
  invalid,        // OTP sai
  expired,        // OTP hết hạn 5 phút
  noOtpPending,   // Không có OTP nào đang chờ
}
