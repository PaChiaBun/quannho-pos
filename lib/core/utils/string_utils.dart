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
