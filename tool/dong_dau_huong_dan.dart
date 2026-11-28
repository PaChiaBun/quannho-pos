// Đóng dấu: ghi mã băm hiện tại của file nguồn từng bài hướng dẫn vào .docs/Huong_dan/nguon_hash.json.
// CHỈ chạy SAU KHI đã rà lại bài theo code mới (test huong_dan_dong_bo_test báo bài nào cần rà).
//   dart run tool/dong_dau_huong_dan.dart            → đóng dấu mọi bài
//   dart run tool/dong_dau_huong_dan.dart thu-chi.md → chỉ đóng dấu bài đã rà
import 'dart:convert';
import 'dart:io';

import 'huong_dan_nguon.dart';

void main(List<String> args) {
  final now = currentHashes();
  final missing = <String>[];
  for (final g in guideFiles()) {
    for (final t in sourcesOf(g.readAsStringSync()).missing) {
      missing.add('${g.uri.pathSegments.last}: "$t"');
    }
  }
  if (missing.isNotEmpty) {
    stderr.writeln(
      '❌ Có nguồn không tìm thấy (sửa front-matter `nguon:` trước):',
    );
    for (final m in missing) {
      stderr.writeln('  - $m');
    }
    exit(1);
  }
  final out = args.isEmpty
      ? now
      : {...readManifest(), for (final a in args) a: now[a]!};
  File(kManifest).writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'_ghi_chu': 'Mã băm file nguồn lúc bài được rà lại lần cuối. Ghi bằng tool/dong_dau_huong_dan.dart.', 'bai': out})}\n',
  );
  stdout.writeln(
    '✅ Đóng dấu ${args.isEmpty ? 'mọi bài' : args.join(', ')} (${out.length} bài).',
  );
}
