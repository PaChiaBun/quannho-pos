/// Chuỗi thời gian từ máy chủ (ISO, thường là giờ UTC "…+00:00") → giờ trên máy,
/// dùng để HIỂN THỊ hoặc gom theo ngày. Thiếu `.toLocal()` là lệch 7 tiếng (giờ Việt Nam).
/// Gửi ngược lên máy chủ thì dùng `.toUtc().toIso8601String()`, không dùng giá trị này.
DateTime? parseServerTime(String? s) =>
    s == null || s.isEmpty ? null : DateTime.tryParse(s)?.toLocal();
