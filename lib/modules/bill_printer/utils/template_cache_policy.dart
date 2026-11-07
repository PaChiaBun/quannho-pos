// lib/modules/bill_printer/utils/template_cache_policy.dart
// Chính sách dùng bản mẫu in lưu trên máy (SharedPreferences) cho đa cửa hàng.
//
// Vấn đề cũ: khoá lưu trên máy dùng chung cho mọi quán, nên đăng nhập quán mới chưa có mẫu
// trên server thì lấy nhầm mẫu của quán trước (lộ tên/địa chỉ/SĐT/số hóa đơn quán khác).
// Quy tắc mới: bản lưu trên máy được gắn nhãn quán ("store"), chỉ dùng khi đúng quán.

import 'dart:convert';

/// Gắn nhãn quán vào JSON mẫu trước khi lưu.
String stampTemplateJson(String json, String storeId) {
  try {
    final m = Map<String, dynamic>.from(jsonDecode(json) as Map);
    m['store'] = storeId;
    return jsonEncode(m);
  } catch (_) {
    return json;
  }
}

String? _storeOf(String? json) {
  if (json == null) return null;
  try {
    final v = (jsonDecode(json) as Map)['store'];
    return v is String && v.isNotEmpty ? v : null;
  } catch (_) {
    return null;
  }
}

/// Chọn JSON mẫu dùng thật.
/// - Server có mẫu của quán này -> dùng bản server.
/// - Server truy vấn được nhưng quán chưa có mẫu -> chỉ dùng bản trên máy nếu ĐÚNG quán
///   (có nhãn trùng); bản không nhãn hoặc của quán khác bị bỏ -> mẫu mặc định.
/// - Không truy vấn được (mất mạng) -> dùng bản trên máy nếu đúng quán hoặc bản cũ không nhãn,
///   để máy đang offline không mất mẫu; bản gắn nhãn quán khác thì bỏ.
String? resolveTemplateJson({
  required String storeId,
  String? cloudJson,
  required bool cloudReachable,
  String? localJson,
}) {
  if (cloudJson != null) return cloudJson;
  final stamped = _storeOf(localJson);
  if (cloudReachable) {
    return stamped == storeId ? localJson : null;
  }
  return (stamped == null || stamped == storeId) ? localJson : null;
}
