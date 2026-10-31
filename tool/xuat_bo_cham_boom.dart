// Xuất bộ câu chấm Boom bằng GPT thật (26/10): mỗi câu hỏi kèm ĐÚNG các mã đoạn app sẽ gửi máy chủ
// (chắc chắn → đoạn đầu + đoạn cùng bài trong 8 đoạn đầu; chưa chắc → 8 đoạn đầu), như boom_chat_provider.
//   dart run tool/xuat_bo_cham_boom.dart [bộ câu .json ...]   (mặc định: bộ độc lập boom_help_eval_doc_lap.json)
// Ghi build/boom_cham/bo_cau.json — dùng cho supabase/functions/boom-chat/cham_gpt.ts.
import 'dart:convert';
import 'dart:io';

import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';

void main(List<String> args) {
  final files = args.isEmpty
      ? ['test/features/ai_assistant/boom_help_eval_doc_lap.json']
      : args;
  final d =
      jsonDecode(File('assets/boom_help/huong_dan.json').readAsStringSync())
          as Map;
  final index = HelpIndex([
    for (final c in d['chunks'] as List)
      HelpChunk.fromJson(c as Map<String, dynamic>),
  ]);
  final out = <Map<String, dynamic>>[];
  for (final f in files) {
    final cases =
        (jsonDecode(File(f).readAsStringSync()) as Map)['cases'] as List;
    for (final c in cases) {
      final expect = (c['expect'] as List).cast<String>();
      // câu lạc đề: đo riêng ở boom_help_eval_test
      if (expect.isEmpty) continue;
      final q = c['q'] as String;
      final r = decideHelp(index, q);
      if (r.hits.isEmpty) continue;
      final ids = [
        for (final c in helpChunksForGpt(
          r,
          sure: r.decision == HelpDecision.answer,
        ))
          c.id,
      ];
      out.add({
        'q': q,
        'expect': expect,
        'chunk_ids': ids,
        'quyet_dinh': r.decision.name,
        'bo': f.split('/').last,
      });
    }
  }
  final dir = Directory('build/boom_cham')..createSync(recursive: true);
  File(
    '${dir.path}/bo_cau.json',
  ).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(out));
  stdout.writeln('✅ ${out.length} câu → ${dir.path}/bo_cau.json');
}
