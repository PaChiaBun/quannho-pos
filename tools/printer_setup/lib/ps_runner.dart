// Chạy PowerShell trên Windows và trả JSON/văn bản. Không phụ thuộc thư viện native.
import 'dart:convert';
import 'dart:io';
import 'app_log.dart';

/// PowerShell -EncodedCommand cần base64 của chuỗi UTF-16LE.
String encodePowerShell(String script) {
  final bytes = <int>[];
  for (final u in script.codeUnits) {
    bytes..add(u & 0xFF)..add(u >> 8);
  }
  return base64.encode(bytes);
}

class PsResult {
  final int exitCode;
  final String out;
  final String err;
  const PsResult(this.exitCode, this.out, this.err);
  bool get ok => exitCode == 0;
}

class PsRunner {
  const PsRunner._();

  static Future<PsResult> run(
    String script, {
    Map<String, String> env = const {},
    Duration timeout = const Duration(seconds: 60),
    String label = 'powershell',
  }) async {
    if (!Platform.isWindows) {
      return const PsResult(1, '', 'Chỉ chạy được trên Windows');
    }
    final full = "[Console]::OutputEncoding=[Text.Encoding]::UTF8\n"
        "\$ErrorActionPreference='Stop'\n$script";
    final sw = Stopwatch()..start();
    try {
      final r = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-EncodedCommand',
          encodePowerShell(full),
        ],
        environment: env,
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      ).timeout(timeout);
      final res = PsResult(r.exitCode, '${r.stdout}'.trim(), '${r.stderr}'.trim());
      final line = '$label: exit=${res.exitCode} ${sw.elapsedMilliseconds}ms'
          '${res.out.isEmpty ? '' : '\n  out: ${res.out}'}'
          '${res.err.isEmpty ? '' : '\n  err: ${res.err}'}';
      res.ok ? AppLog.info(line) : AppLog.error(line);
      return res;
    } catch (e) {
      AppLog.error('$label: ngoại lệ sau ${sw.elapsedMilliseconds}ms: $e');
      return PsResult(1, '', '$e');
    }
  }

  /// Chạy script in ra JSON; trả về List (mảng) hoặc rỗng nếu không có.
  static Future<List<Map<String, dynamic>>> runJsonList(String script, {String label = 'powershell'}) async {
    final r = await run(script, label: label);
    if (!r.ok || r.out.isEmpty) return const [];
    return parseJsonList(r.out);
  }
}

/// PowerShell trả đối tượng đơn lẻ thay vì mảng khi chỉ có một phần tử; gom về List.
List<Map<String, dynamic>> parseJsonList(String text) {
  try {
    final d = jsonDecode(text);
    if (d is List) {
      return [for (final e in d) if (e is Map) Map<String, dynamic>.from(e)];
    }
    if (d is Map) return [Map<String, dynamic>.from(d)];
  } catch (_) {}
  return const [];
}
