// lib/core/services/brevo_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Brevo Service — Gửi email chào mừng qua Brevo (SendinBlue) REST API
// Free: 300 emails/ngày, không cần server
// ─────────────────────────────────────────────────────────────────────────────
import 'dart:convert';
import 'package:http/http.dart' as http;

class BrevoService {
  // ── Config — Điền sau khi tạo account Brevo ───────────────────────────────
  static const _apiKey      = 'YOUR_BREVO_API_KEY';  // API key từ brevo.com
  static const _senderEmail = 'noreply@quannho.app'; // Email người gửi (verify trong Brevo)
  static const _senderName  = 'Quán Nhỏ POS';

  static const _apiUrl = 'https://api.brevo.com/v3/smtp/email';

  // ─────────────────────────────────────────────────────────────────────────
  // SEND WELCOME EMAIL — Gửi sau khi onboarding thành công
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> sendWelcomeEmail({
    required String toEmail,
    required String toName,
    required String shopName,
  }) async {
    if (_apiKey == 'YOUR_BREVO_API_KEY') return false; // Chưa config

    final htmlContent = _buildWelcomeHtml(
      ownerName: toName,
      shopName:  shopName,
    );

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'accept':       'application/json',
          'api-key':      _apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {
            'name':  _senderName,
            'email': _senderEmail,
          },
          'to': [
            {'email': toEmail, 'name': toName}
          ],
          'subject': '🎉 Chào mừng $shopName đến với Quán Nhỏ POS!',
          'htmlContent': htmlContent,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false; // Không có mạng — không sao
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEND OTP EMAIL — Dùng thay EmailJS nếu muốn
  // ─────────────────────────────────────────────────────────────────────────
  static Future<bool> sendOtpEmail({
    required String toEmail,
    required String toName,
    required String otpCode,
  }) async {
    if (_apiKey == 'YOUR_BREVO_API_KEY') return false;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'accept':       'application/json',
          'api-key':      _apiKey,
          'content-type': 'application/json',
        },
        body: jsonEncode({
          'sender': {'name': _senderName, 'email': _senderEmail},
          'to': [{'email': toEmail, 'name': toName}],
          'subject': '🔑 Mã xác nhận PIN — Quán Nhỏ POS',
          'htmlContent': _buildOtpHtml(otp: otpCode, name: toName),
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HTML TEMPLATES
  // ─────────────────────────────────────────────────────────────────────────

  static String _buildWelcomeHtml({
    required String ownerName,
    required String shopName,
  }) => '''
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px;">
  <div style="max-width: 560px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
    
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #1E1C5E, #2D2B8A); padding: 40px 32px; text-align: center;">
      <div style="font-size: 48px; margin-bottom: 12px;">🏪</div>
      <h1 style="color: white; margin: 0; font-size: 24px;">Quán Nhỏ POS</h1>
      <p style="color: rgba(255,255,255,0.7); margin: 8px 0 0 0; font-size: 14px;">Quản lý quán — Đơn giản & Hiệu quả</p>
    </div>
    
    <!-- Body -->
    <div style="padding: 32px;">
      <h2 style="color: #1E1C5E; margin-top: 0;">Chào mừng, $ownerName! 🎉</h2>
      <p style="color: #555; line-height: 1.6;">
        <strong>$shopName</strong> đã được thiết lập thành công trên <strong>Quán Nhỏ POS</strong>.
        Bạn đã sẵn sàng để quản lý quán một cách thông minh hơn!
      </p>
      
      <!-- Features -->
      <div style="background: #f8f9ff; border-radius: 12px; padding: 20px; margin: 20px 0;">
        <h3 style="color: #1E1C5E; margin-top: 0; font-size: 15px;">✨ Tính năng nổi bật:</h3>
        <ul style="color: #555; line-height: 2; margin: 0; padding-left: 20px;">
          <li>🛒 Bán hàng nhanh — không cần internet</li>
          <li>📦 Quản lý kho tồn kho thời gian thực</li>
          <li>⭐ Tích điểm khách hàng thân thiết</li>
          <li>📊 Báo cáo doanh thu chi tiết</li>
          <li>💰 Quản lý thu chi tài chính</li>
        </ul>
      </div>
      
      <p style="color: #555; line-height: 1.6;">
        Nếu cần hỗ trợ, hãy reply email này. Chúng tôi luôn sẵn sàng!
      </p>
      
      <p style="color: #1E1C5E; font-weight: bold;">Chúc quán luôn đông khách! ☕</p>
    </div>
    
    <!-- Footer -->
    <div style="background: #f8f8f8; padding: 20px 32px; text-align: center; border-top: 1px solid #eee;">
      <p style="color: #999; font-size: 12px; margin: 0;">
        © 2025 Quán Nhỏ POS • Email này được gửi đến $ownerName
      </p>
    </div>
  </div>
</body>
</html>
''';

  static String _buildOtpHtml({
    required String otp,
    required String name,
  }) => '''
<!DOCTYPE html>
<html>
<body style="font-family: Arial, sans-serif; background: #f5f5f5; margin: 0; padding: 20px;">
  <div style="max-width: 480px; margin: 0 auto; background: white; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0,0,0,0.1);">
    <div style="background: linear-gradient(135deg, #1E1C5E, #2D2B8A); padding: 32px; text-align: center;">
      <div style="font-size: 40px;">🔑</div>
      <h2 style="color: white; margin: 8px 0 0 0;">Mã xác nhận PIN</h2>
    </div>
    <div style="padding: 32px; text-align: center;">
      <p style="color: #555;">Xin chào <strong>$name</strong>,</p>
      <p style="color: #555;">Mã xác nhận đặt lại PIN của bạn:</p>
      <div style="background: #f0f0ff; border: 2px dashed #2D2B8A; border-radius: 12px; padding: 24px; margin: 20px 0;">
        <span style="font-size: 42px; font-weight: 900; letter-spacing: 12px; color: #1E1C5E;">$otp</span>
      </div>
      <p style="color: #E74C3C; font-size: 13px;">⏰ Mã hết hạn sau <strong>5 phút</strong></p>
      <p style="color: #999; font-size: 12px;">Nếu bạn không yêu cầu, hãy bỏ qua email này.</p>
    </div>
  </div>
</body>
</html>
''';
}
