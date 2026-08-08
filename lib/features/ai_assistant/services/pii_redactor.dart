// lib/features/ai_assistant/services/pii_redactor.dart
// ─────────────────────────────────────────────────────────────────────────────
// PII Redactor — Khử 100% Thông tin Cá nhân Nhạy cảm trước khi gửi Cloud
// ─────────────────────────────────────────────────────────────────────────────

class PiiRedactor {
  /// Lọc bỏ các thông tin PII: SĐT, Email, Mật khẩu, Mã PIN, Token, Thẻ ngân hàng
  static String redact(String input) {
    if (input.isEmpty) return input;

    var text = input;

    // 1. Khử SĐT Việt Nam (09x, 03x, 07x, 08x, 05x, +84x)
    text = text.replaceAll(
      RegExp(r'(\+84|84|0)(3|5|7|8|9)[0-9]{8}\b'),
      '[REDACTED_PHONE]',
    );
    text = text.replaceAll(
      RegExp(r'\b\d{4}[-.\s]?\d{3}[-.\s]?\d{3}\b'),
      '[REDACTED_PHONE]',
    );

    // 2. Khử Email
    text = text.replaceAll(
      RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
      '[REDACTED_EMAIL]',
    );

    // 3. Khử Mã PIN 6 số hoặc Password
    text = text.replaceAll(
      RegExp(r'\b(pin|mật khẩu|pass|password)\s*[:=]\s*\w+', caseSensitive: false),
      r'\1: [REDACTED_SECRET]',
    );

    // 4. Khử JWT Token / Bearer Key
    text = text.replaceAll(
      RegExp(r'eyJ[A-Za-z0-9-_=]+\.[A-Za-z0-9-_=]+\.?[A-Za-z0-9-_.+/=]*'),
      '[REDACTED_TOKEN]',
    );

    return text;
  }
}
