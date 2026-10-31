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

/// Rút gọn cho ô hẹp: dưới 10 triệu hiện đủ như [fmtVnd] ("387.000 đ"); từ 10 triệu
/// "12,5 triệu"; từ 1 tỷ "1,2 tỷ". Trước đây "387 K Đ" / "196.0 Tr Đ" lệch với phần còn lại của app.
String fmtMoney(double v) {
  final a = v.abs();
  final sign = v < 0 ? '-' : '';
  String dec(double x) =>
      x.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '').replaceAll('.', ',');
  if (a >= 1e9) return '$sign${dec(a / 1e9)} tỷ';
  if (a >= 1e7) return '$sign${dec(a / 1e6)} triệu';
  return fmtVnd(v);
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
