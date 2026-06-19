// lib/core/services/otp_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// OTP Service — Tạo OTP 6 số và gửi qua Brevo (không dùng EmailJS nữa)
// Brevo lo việc gửi email — cùng account với welcome email
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'brevo_service.dart';

class OtpService {
  // ── Lưu trữ OTP tạm thời trong SharedPreferences ─────────────────────────
  static const _kOtpHash   = 'otp_hash_temp';
  static const _kOtpExpiry = 'otp_expiry_temp';
  static const _otpLifetime = Duration(minutes: 5);

  // ─────────────────────────────────────────────────────────────────────────
  // SEND OTP — Sinh OTP 6 số, lưu hash, gửi qua Brevo
  // ─────────────────────────────────────────────────────────────────────────
  Future<OtpResult> sendOtp({
    required String toEmail,
    required String toName,
  }) async {
    try {
      // 1. Sinh OTP 6 số
      final otp = _generateOtp();

      // 2. Lưu hash + expiry vào SharedPreferences
      final prefs  = await SharedPreferences.getInstance();
      final expiry = DateTime.now().add(_otpLifetime).millisecondsSinceEpoch;
      await prefs.setString(_kOtpHash,   _hashOtp(otp));
      await prefs.setInt   (_kOtpExpiry, expiry);

      // 3. Gửi qua Brevo
      final sent = await BrevoService.sendOtpEmail(
        toEmail: toEmail,
        toName:  toName,
        otpCode: otp,
      );

      if (sent) return OtpResult.success;

      // Brevo chưa config → notConfigured
      return OtpResult.notConfigured;
    } catch (_) {
      return OtpResult.networkError;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VERIFY OTP — So khớp OTP người dùng nhập với hash đã lưu
  // ─────────────────────────────────────────────────────────────────────────
  Future<OtpVerifyResult> verifyOtp(String inputOtp) async {
    final prefs     = await SharedPreferences.getInstance();
    final savedHash = prefs.getString(_kOtpHash);
    final expiryMs  = prefs.getInt   (_kOtpExpiry);

    if (savedHash == null || expiryMs == null) {
      return OtpVerifyResult.noOtpPending;
    }

    if (DateTime.now().millisecondsSinceEpoch > expiryMs) {
      await _clearOtp(prefs);
      return OtpVerifyResult.expired;
    }

    if (_hashOtp(inputOtp.trim()) == savedHash) {
      await _clearOtp(prefs);
      return OtpVerifyResult.valid;
    }

    return OtpVerifyResult.invalid;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────────────────────────────────

  String _generateOtp() {
    final rng = Random.secure();
    return (100000 + rng.nextInt(900000)).toString();
  }

  String _hashOtp(String otp) {
    return base64Encode(utf8.encode('quannho_salt_$otp'));
  }

  Future<void> _clearOtp(SharedPreferences prefs) async {
    await prefs.remove(_kOtpHash);
    await prefs.remove(_kOtpExpiry);
  }

  Future<int> remainingSeconds() async {
    final prefs    = await SharedPreferences.getInstance();
    final expiryMs = prefs.getInt(_kOtpExpiry);
    if (expiryMs == null) return 0;
    final remaining = expiryMs - DateTime.now().millisecondsSinceEpoch;
    return remaining > 0 ? (remaining / 1000).ceil() : 0;
  }

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
  notConfigured, // Brevo chưa được cấu hình
  sendFailed,    // Brevo trả về lỗi
  networkError,  // Không có internet
}

enum OtpVerifyResult {
  valid,         // OTP đúng
  invalid,       // OTP sai
  expired,       // OTP hết hạn 5 phút
  noOtpPending,  // Không có OTP nào đang chờ
}
