class PiiRedactor {
  static final RegExp _phoneRegex = RegExp(
    r'(?:\+84|0)(?:3[2-9]|5[2689]|7[06-9]|8[1-9]|9[0-9])\d{7}\b',
  );
  static final RegExp _emailRegex = RegExp(
    r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+\b',
  );
  static final RegExp _secretKeyRegex = RegExp(
    r'\b(?:sk-[a-zA-Z0-9]{20,}|eyJ[a-zA-Z0-9._-]{20,})\b',
  );

  // Contextual PIN/OTP regex: matches 4-6 digit numbers ONLY when preceded by context keywords
  static final RegExp _contextualPinRegex = RegExp(
    r'\b(?:pin|otp|mã xác thực|mật khẩu|password|code|token)\s*[:=]?\s*(\d{4,6})\b',
    caseSensitive: false,
  );

  static String redact(String? text) {
    if (text == null || text.trim().isEmpty) return text ?? '';
    var result = text;
    result = result.replaceAll(_phoneRegex, '[REDACTED_PHONE]');
    result = result.replaceAll(_emailRegex, '[REDACTED_EMAIL]');
    result = result.replaceAll(_secretKeyRegex, '[REDACTED_SECRET]');

    // Replace contextual PIN/OTP with [REDACTED_SECRET]
    result = result.replaceAllMapped(_contextualPinRegex, (match) {
      final fullMatch = match.group(0)!;
      final digits = match.group(1)!;
      return fullMatch.replaceAll(digits, '[REDACTED_SECRET]');
    });

    return result;
  }

  static Map<String, dynamic>? sanitizeEvidenceReference(
    Map<String, dynamic>? rawEvidence,
  ) {
    if (rawEvidence == null) return null;
    const allowlist = {
      'tool_name',
      'latency_ms',
      'route',
      'status',
      'intent',
      'query_id',
    };
    final Map<String, dynamic> clean = {};

    for (final entry in rawEvidence.entries) {
      if (allowlist.contains(entry.key)) {
        final val = entry.value;
        if (val is Map || val is List) {
          throw ArgumentError(
            'NESTED_STRUCTURE_REJECTED: key ${entry.key} contains nested structure',
          );
        }
        if (val is String) {
          clean[entry.key] = redact(val);
        } else {
          clean[entry.key] = val;
        }
      }
    }
    return clean;
  }
}
