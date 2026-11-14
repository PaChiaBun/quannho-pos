// Xuất bài hướng dẫn (.docs/Huong_dan) thành assets/boom_help/huong_dan.json cho Boom.
// Chạy từ thư mục quan_nho:  dart run tool/xuat_huong_dan_boom.dart
// Lỗi (thiếu dấu mốc cắt, lọt tên kỹ thuật) → in lỗi, thoát mã 1, không ghi tệp.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';

const kGuideDir = '.docs/Huong_dan';
const kOutFile = 'assets/boom_help/huong_dan.json';

/// Cắt toàn bộ bài; dùng chung với test.
List<HelpChunk> buildAllChunks(Directory dir) {
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.md'))
          .where((f) => !kNonGuideFiles.contains(f.uri.pathSegments.last))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final f in files)
      ...parseGuide(f.uri.pathSegments.last, f.readAsStringSync()),
  ];
}

String contentHash(List<HelpChunk> chunks) => sha256
    .convert(utf8.encode(jsonEncode([for (final c in chunks) c.toJson()])))
    .toString();

void main() {
  final List<HelpChunk> chunks;
  try {
    chunks = buildAllChunks(Directory(kGuideDir));
  } on HuongDanParseException catch (e) {
    stderr.writeln('❌ $e');
    exit(1);
  }
  final issues = lintChunks(chunks);
  if (issues.isNotEmpty) {
    stderr.writeln(
      '❌ Còn lọt ${issues.length} chỗ kỹ thuật / ghi chú phiên bản:',
    );
    for (final i in issues) {
      stderr.writeln('  - $i');
    }
    exit(1);
  }
  final hash = contentHash(chunks);
  final out = File(kOutFile);
  var version = int.parse(
    DateTime.now()
        .toUtc()
        .toIso8601String()
        .replaceAll(RegExp(r'[^0-9]'), '')
        .substring(0, 12),
  );
  if (out.existsSync()) {
    final old = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    if (old['hash'] == hash) {
      stdout.writeln(
        '✅ Không đổi (${chunks.length} đoạn, phiên bản ${old['version']}).',
      );
      return;
    }
    final oldV = old['version'] as int;
    if (version <= oldV) version = oldV + 1;
  }
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    const JsonEncoder.withIndent(' ').convert({
      'version': version,
      'hash': hash,
      'chunks': [for (final c in chunks) c.toJson()],
    }),
  );
  stdout.writeln('✅ Ghi $kOutFile: ${chunks.length} đoạn, phiên bản $version.');
}
