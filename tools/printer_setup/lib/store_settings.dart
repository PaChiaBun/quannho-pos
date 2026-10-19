// Tên quán (nhập một lần, lưu máy) và quy ước đặt tên máy in: QN-TênQuán-VaiTrò.
import 'dart:convert';
import 'dart:io';
import 'app_log.dart';

const _from = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ'
    'ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬÈÉẺẼẸÊỀẾỂỄỆÌÍỈĨỊÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢÙÚỦŨỤƯỪỨỬỮỰỲÝỶỸỴĐ';
const _to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd'
    'AAAAAAAAAAAAAAAAAEEEEEEEEEEEIIIIIOOOOOOOOOOOOOOOOOUUUUUUUUUUUYYYYYD';

String removeDiacritics(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = _from.indexOf(c);
    b.write(i >= 0 ? _to[i] : c);
  }
  return b.toString();
}

/// "KAY - Rạch Giá" -> "KAY-Rach-Gia". Chỉ chữ/số, tối đa [maxLen] ký tự để tên máy in gọn.
String storeSlug(String storeName, {int maxLen = 24}) {
  final words = removeDiacritics(storeName)
      .split(RegExp(r'[^A-Za-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w == w.toUpperCase() && w.length <= 4 ? w : w[0].toUpperCase() + w.substring(1))
      .toList();
  var s = words.join('-');
  if (s.length > maxLen) s = s.substring(0, maxLen);
  return s.replaceAll(RegExp(r'-+$'), '');
}

/// Tên hàng đợi máy in: QN-tênquán-vaitrò; chưa có tên quán thì QN-vaitrò.
String queueNameFor(String storeName, String roleCode) {
  final slug = storeSlug(storeName);
  return slug.isEmpty ? 'QN-$roleCode' : 'QN-$slug-$roleCode';
}

class StoreSettings {
  StoreSettings._();

  static String get _path => '${AppLog.dirPath}\\..\\settings.json';

  static Future<String> loadStoreName() async {
    try {
      final f = File(_path);
      if (!await f.exists()) return '';
      final m = jsonDecode(await f.readAsString());
      return m is Map ? '${m['storeName'] ?? ''}' : '';
    } catch (_) {
      return '';
    }
  }

  static Future<void> saveStoreName(String name) async {
    try {
      final f = File(_path);
      await f.parent.create(recursive: true);
      await f.writeAsString(jsonEncode({'storeName': name.trim()}));
    } catch (_) {}
  }
}
