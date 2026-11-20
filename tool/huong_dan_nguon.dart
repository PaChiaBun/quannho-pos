// Đọc danh sách file nguồn (front-matter `nguon:`) của bài hướng dẫn và tính mã băm từng file.
// Dùng chung cho tool/dong_dau_huong_dan.dart (đóng dấu) và test/docs/huong_dan_dong_bo_test.dart
// (ke-hoach-trien-khai-boom.md, Giai đoạn 2: file nguồn đổi mà bài chưa rà lại → báo).
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart'
    show kNonGuideFiles;

const kGuideDir = '.docs/Huong_dan';
const kManifest = '.docs/Huong_dan/nguon_hash.json';
// Nhật ký đổi hằng ngày — không dùng làm mốc.
const kIgnoreSources = {'nhat_ky.md'};

final _token = RegExp(r'[\w.*/-]+\.(?:dart|sql|md)\b');

List<File> guideFiles() =>
    Directory(kGuideDir)
        .listSync()
        .whereType<File>()
        .where(
          (f) =>
              f.path.endsWith('.md') &&
              !kNonGuideFiles.contains(f.uri.pathSegments.last),
        )
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

List<String> _sourceLines(String raw) {
  final out = <String>[];
  var inList = false;
  for (final l in raw.split('\n').skip(1)) {
    if (l.trim() == '---') break;
    if (l.startsWith('nguon:')) {
      inList = true;
      continue;
    }
    if (inList && l.startsWith('  - ')) {
      out.add(l.substring(4));
    } else if (inList && !l.startsWith(' ')) {
      inList = false;
    }
  }
  return out;
}

List<String> _expand(String path) {
  if (!path.contains('*')) return File(path).existsSync() ? [path] : const [];
  final dir = Directory(path.substring(0, path.lastIndexOf('/')));
  if (!dir.existsSync()) return const [];
  final pat = RegExp(
    '^${RegExp.escape(path.split('/').last).replaceAll(r'\*', '.*')}\$',
  );
  return [
    for (final f in dir.listSync().whereType<File>())
      if (pat.hasMatch(f.uri.pathSegments.last)) f.path,
  ]..sort();
}

/// Đường dẫn nguồn của một bài (đã dò đầy đủ) + những tên không tìm thấy.
({List<String> found, List<String> missing}) sourcesOf(String raw) {
  final found = <String>{};
  final missing = <String>[];
  for (final line in _sourceLines(raw)) {
    String? prevDir;
    for (final m in _token.allMatches(line)) {
      final t = m.group(0)!;
      if (kIgnoreSources.contains(t)) continue;
      final candidates = <String>[
        t,
        if (prevDir != null) ...[
          '$prevDir/$t',
          if (prevDir.contains('/'))
            '${prevDir.substring(0, prevDir.lastIndexOf('/'))}/$t',
        ],
        'supabase/migrations/$t',
      ];
      List<String> hit = const [];
      for (final c in candidates) {
        hit = _expand(c);
        if (hit.isNotEmpty) break;
      }
      if (hit.isEmpty) {
        missing.add(t);
        continue;
      }
      found.addAll(hit);
      prevDir = hit.first.substring(0, hit.first.lastIndexOf('/'));
    }
  }
  return (found: found.toList()..sort(), missing: missing);
}

/// Mã băm nội dung (bỏ khác biệt xuống dòng Windows CRLF / Unix LF).
String fileHash(String path) => sha256
    .convert(
      File(path).readAsBytesSync().fold<List<int>>([], (out, b) {
        if (b == 10 && out.isNotEmpty && out.last == 13) out.removeLast();
        out.add(b);
        return out;
      }),
    )
    .toString()
    .substring(0, 16);

/// {bài: {nguồn: mã băm}}
Map<String, Map<String, String>> currentHashes() => {
  for (final g in guideFiles())
    g.uri.pathSegments.last: {
      for (final s in sourcesOf(g.readAsStringSync()).found) s: fileHash(s),
    },
};

Map<String, Map<String, String>> readManifest() {
  final f = File(kManifest);
  if (!f.existsSync()) return {};
  final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return {
    for (final e in (m['bai'] as Map<String, dynamic>).entries)
      e.key: Map<String, String>.from(e.value as Map),
  };
}
