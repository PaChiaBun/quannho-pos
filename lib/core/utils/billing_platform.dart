import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CỔNG THU PHÍ — nơi nào được hiện giá / nút trả tiền (ke-hoach-cong-thu-phi.md, mục 6)
// App tải từ App Store / CH Play (iOS, Android) KHÔNG được hiện giá, nút mua, đường dẫn thanh toán
// (Apple 3.1.1, Google Play Billing). Chỉ web /pos và bản máy tính tải từ web được thu phí.
// MỌI chỗ hiện giá / nút trả tiền phải đi qua hàm này.
// ─────────────────────────────────────────────────────────────────────────────

bool billingAllowedHere({bool? isWeb, TargetPlatform? platform}) {
  if (isWeb ?? kIsWeb) return true;
  return switch (platform ?? defaultTargetPlatform) {
    TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
    _ => false,
  };
}
