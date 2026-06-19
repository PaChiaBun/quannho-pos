// ─────────────────────────────────────────────────────────────────────────────
// MONEY FORMATTER — Dùng chung toàn app Quán Nhỏ
// Format chuẩn VND (mới): 20.000 đ | 1.500.000 đ
// Format cũ (giữ tương thích): 2.5 Tr Đ | 500 K Đ
// ─────────────────────────────────────────────────────────────────────────────

/// [CHUẨN MỚI] Format VND với dấu chấm ngăn cách — dùng cho card, giỏ hàng, thanh toán.
/// Ví dụ: 20000 → "20.000 đ" | 1500000 → "1.500.000 đ" | 500 → "500 đ"
String fmtVnd(num v) {
  final intVal = v.toInt().abs();
  final sign = v < 0 ? '-' : '';
  final formatted = intVal.toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]}.',
  );
  return '$sign$formatted đ';
}

/// Phiên bản int (tương thích ngược)
String fmtVndInt(int v) => fmtVnd(v);

/// Có dấu + / - (dùng cho lợi nhuận, tăng trưởng)
/// Ví dụ: 20000 → "+20.000 đ" | -5000 → "-5.000 đ"
String fmtVndSigned(num v) {
  final sign = v >= 0 ? '+' : '-';
  return '$sign${fmtVnd(v.abs())}';
}

// ── Legacy (giữ tương thích với code cũ) ─────────────────────────────────────

/// Định dạng rút gọn cũ: 2.5 Tr Đ | 500 K Đ | 100 Đ
/// Chỉ dùng cho Dashboard và Report — KHÔNG dùng cho card/giỏ hàng/thanh toán
String fmtMoney(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)} Tr Đ';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)} K Đ';
  return '${v.toStringAsFixed(0)} Đ';
}

/// Phiên bản int (dùng cho price từ database lưu dạng int)
String fmtMoneyInt(int v) => fmtMoney(v.toDouble());

/// Có dấu + / - (dùng cho lợi nhuận, tăng trưởng)
String fmtMoneySigned(double v) {
  final sign = v >= 0 ? '+ ' : '- ';
  return '$sign${fmtMoney(v.abs())}';
}

/// Rút gọn — alias của fmtMoney (tương thích với code cũ)
String fmtShort(double v) => fmtMoney(v);
