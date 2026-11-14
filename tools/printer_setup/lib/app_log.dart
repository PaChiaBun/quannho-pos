// Ghi log ra file để gỡ lỗi từ xa: %LOCALAPPDATA%\QuanNho\CaiMayIn\logs\cai-may-in-YYYYMMDD.log
// Chỉ ghi thao tác tìm/cài máy in và kết quả PowerShell; không có mật khẩu hay dữ liệu bán hàng.
import 'dart:io';

class AppLog {
  AppLog._();

  static const _maxChars = 4000; // cắt bớt đầu ra quá dài
  static const _keepDays = 14;
  static File? _file;

  static String get dirPath {
    final base = Platform.environment['LOCALAPPDATA'] ?? Directory.systemTemp.path;
    return '$base\\QuanNho\\CaiMayIn\\logs';
  }

  static String get filePath {
    final n = DateTime.now();
    final d = '${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}';
    return '$dirPath\\cai-may-in-$d.log';
  }

  static String clip(String s) =>
      s.length <= _maxChars ? s : '${s.substring(0, _maxChars)}…(cắt, dài ${s.length} ký tự)';

  static String stamp() {
    final n = DateTime.now();
    String t(int v, [int w = 2]) => v.toString().padLeft(w, '0');
    return '${n.year}-${t(n.month)}-${t(n.day)} ${t(n.hour)}:${t(n.minute)}:${t(n.second)}.${t(n.millisecond, 3)}';
  }

  /// Dòng log đã định dạng (tách riêng để test).
  static String format(String level, String msg) => '[${stamp()}] [$level] ${clip(msg)}';

  static Future<void> init() async {
    try {
      final dir = Directory(dirPath);
      await dir.create(recursive: true);
      // Xoá log cũ hơn _keepDays ngày.
      final cutoff = DateTime.now().subtract(const Duration(days: _keepDays));
      await for (final e in dir.list()) {
        if (e is File && e.path.endsWith('.log') && (await e.lastModified()).isBefore(cutoff)) {
          try { await e.delete(); } catch (_) {}
        }
      }
      _file = File(filePath);
      info('=== Mở công cụ Cài máy in | ${Platform.operatingSystemVersion} | ${Platform.localHostname} ===');
    } catch (_) {
      _file = null; // không ghi được log cũng không được làm hỏng app
    }
  }

  static void info(String msg) => _write('INFO', msg);
  static void error(String msg) => _write('LỖI', msg);

  static void _write(String level, String msg) {
    final f = _file;
    if (f == null) return;
    try {
      f.writeAsStringSync('${format(level, msg)}\n', mode: FileMode.append, flush: true);
    } catch (_) {}
  }

  /// Nội dung log hôm nay (để sao chép gửi hỗ trợ).
  static Future<String> readToday() async {
    try {
      return await File(filePath).readAsString();
    } catch (_) {
      return '';
    }
  }

  static Future<void> openFolder() async {
    try {
      await Directory(dirPath).create(recursive: true);
      await Process.run('explorer.exe', [dirPath]);
    } catch (_) {}
  }
}
