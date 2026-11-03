import 'dart:convert';

String removeDiacritics(String str) {
  const map = {
    'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
    'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
    'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
    'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
    'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
    'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
    'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
    'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
    'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
    'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
    'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
    'ỳ': 'i', 'ý': 'i', 'ỷ': 'i', 'ỹ': 'i', 'ỵ': 'i', 'y': 'i',
    'đ': 'd',
    'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A',
    'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A',
    'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
    'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E',
    'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
    'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
    'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O',
    'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ộ': 'O',
    'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
    'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U',
    'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
    'Ỳ': 'I', 'Ý': 'I', 'Ỷ': 'I', 'Ỹ': 'I', 'Ỵ': 'I', 'Y': 'I',
    'Đ': 'D',
  };

  StringBuffer sb = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    String char = str[i];
    sb.write(map[char] ?? char);
  }
  return sb.toString();
}

extension StringDiacriticsExtension on String {
  String toUnsigned() {
    return removeDiacritics(this);
  }

  bool containsSearch(String query) {
    if (query.isEmpty) return true;
    final cleanQuery = query.toLowerCase().toUnsigned().trim();
    final cleanSource = toLowerCase().toUnsigned();

    // 1. Khớp chuỗi trực tiếp (ví dụ: "mi" -> "Mì cay", "com" -> "Cơm sườn")
    if (cleanSource.contains(cleanQuery)) return true;

    // 2. Khớp viết tắt / ký tự đầu (ví dụ: "mckc" -> "Mì Cay Kim Chi", "csm" -> "Cơm Sườn Miếng")
    final words = cleanSource.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isNotEmpty) {
      final initials = words.map((w) => w[0]).join('');
      if (initials.contains(cleanQuery)) return true;
    }

    // 3. Khớp nhiều từ không quan trọng thứ tự (ví dụ: "bo cay" -> "Mì Cay Kim Chi Bò VN")
    final queryWords = cleanQuery.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (queryWords.length > 1) {
      bool allWordsMatch = true;
      for (final qw in queryWords) {
        if (!cleanSource.contains(qw)) {
          allWordsMatch = false;
          break;
        }
      }
      if (allWordsMatch) return true;
    }

    return false;
  }
}

/// Máy chủ ghi "Thanh toán bàn " + tên bàn; tên bàn đã có chữ "Bàn" ("Bàn 1", "bàn 13") nên thành
/// "Thanh toán bàn bàn 13" → bỏ chữ lặp khi đọc (dòng cũ cũng gọn, không đụng hàm thanh toán).
String? tidyFinanceDescription(String? s) =>
    s?.replaceFirst(RegExp(r'^Thanh toán bàn (?=bàn\s)', caseSensitive: false), 'Thanh toán ');

/// Cùng lỗi ở chỗ khác trong câu: ghi chú đơn "Món thanh toán tại bàn bàn 13" → "… tại bàn 13".
String tidyRepeatedTableWord(String s) =>
    s.replaceAll(RegExp(r'\bbàn\s+(?=bàn\s)', caseSensitive: false), '');

/// Tổng số phần một topping của cả dòng món: món gọi ở bàn ghi `qty` = tổng cả dòng ("2 ly + 1 trân
/// châu" → 1); đơn QR ghi `quantity` = số mỗi phần → nhân số món. Máy chủ trừ kho theo cùng cách.
num toppingTotal(Map m, num lineQty) =>
    _num(m['qty']) ?? (_num(m['quantity']) ?? 1) * lineQty;

num? _num(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');

String qtyText(num n) => n % 1 == 0 ? '${n.toInt()}' : '$n';

/// Topping / tuỳ chọn từ `modifiers_json` (chuỗi JSON hoặc danh sách) để in dưới tên món: topping ghi
/// tổng của dòng "Trân châu x3"; đúng 1 mỗi phần thì chỉ ghi tên ("Trà x2 / + Trân châu" = mỗi ly 1).
/// Dùng cho chi tiết bill, hoá đơn in (giá dòng đã gồm topping) và phiếu bếp in giấy ở màn Bàn.
List<String> billItemExtras(Object? modifiersJson, {num lineQty = 1}) {
  return [
    for (final e in _jsonList(modifiersJson))
      if (e is Map && '${e['name'] ?? ''}'.trim().isNotEmpty)
        e['type'] == 'topping' && toppingTotal(e, lineQty) != lineQty
            ? '${e['name']} x${qtyText(toppingTotal(e, lineQty))}'
            : '${e['name']}',
  ];
}

List _jsonList(Object? raw) {
  if (raw is String) {
    if (raw.trim().isEmpty) return const [];
    try {
      raw = jsonDecode(raw);
    } catch (_) {
      return const [];
    }
  }
  return raw is List ? raw : const [];
}

/// Topping chọn ở "Tùy chọn" nằm trong `modifiers_json` của dòng món, không thành dòng đơn riêng — báo cáo
/// tách ra món riêng: số phần theo [toppingTotal], tiền = giá × số phần (trừ khỏi tiền món chính).
/// Máy chủ tính cùng cách (20261104_topping_bao_cao_v1).
List<({String id, String name, double qty, double revenue})> toppingSales(
  Object? modifiersJson,
  num lineQty,
) {
  final out = <({String id, String name, double qty, double revenue})>[];
  if (lineQty <= 0) return out;
  for (final e in _jsonList(modifiersJson)) {
    if (e is! Map || e['type'] != 'topping') continue;
    final id = '${e['id'] ?? ''}'.trim();
    if (id.isEmpty) continue;
    final qty = toppingTotal(e, lineQty).toDouble();
    out.add((
      id: id,
      name: '${e['name'] ?? ''}'.trim(),
      qty: qty,
      revenue: qty * (_num(e['price']) ?? 0),
    ));
  }
  return out;
}

/// Dòng có topping ghi số tổng ("Trân châu x2") không gộp với dòng giống hệt: cộng số món mà giữ
/// "x2" sẽ đọc sai tổng topping.
bool extrasHaveCount(List<String> extras) => extras.any(_extraCountRe.hasMatch);

final _extraCountRe = RegExp(r' x\d+(?:\.\d+)?$');

/// Ghi chú món kèm dòng topping "+ Trân châu" ở đầu — mẫu phiếu bếp in dòng "+ …" thành topping.
String? noteWithExtras(String? note, Object? modifiersJson, {num lineQty = 1}) {
  final extras = billItemExtras(modifiersJson, lineQty: lineQty);
  final parts = [
    if (extras.isNotEmpty) '+ ${extras.join(', ')}',
    if (note != null && note.trim().isNotEmpty) note.trim(),
  ];
  return parts.isEmpty ? null : parts.join('\n');
}

final _nameVariantRe = RegExp(r'^(.*\S)\s*(?:\[\s*([^\[\]]*?)\s*\]|\(\s*([^()]*?)\s*\))$');

/// Thẻ món Bán hàng chỉ đủ 2 dòng tên: tách phần trong ngoặc ở cuối ("Cá Viên Chiên Sốt Me [ phần nhỏ ]",
/// "Trà Sữa … (Đá/Nóng)") để hiện riêng cạnh giá — trước bị cắt mất, hai cỡ món chỉ còn khác nhau ở giá.
({String base, String? variant}) splitNameVariant(String name) {
  final m = _nameVariantRe.firstMatch(name.trim());
  final variant = m == null ? null : (m[2] ?? m[3]);
  return variant == null || variant.isEmpty
      ? (base: name, variant: null)
      : (base: m![1]!, variant: variant);
}
