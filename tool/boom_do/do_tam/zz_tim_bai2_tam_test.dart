import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';

// ĐO TÌM BÀI (tạm, không commit): mỗi câu có expect → GPT có nhận đoạn đúng không.
void main() {
  test('đo tìm bài', () async {
    final d = jsonDecode(File('assets/boom_help/huong_dan.json').readAsStringSync()) as Map;
    final index = HelpIndex([for (final c in d['chunks'] as List) HelpChunk.fromJson(c as Map<String, dynamic>)]);
    final out = File(Platform.environment['KET_QUA']!).openWrite();
    final cases = (jsonDecode(File(Platform.environment['BO_CAU']!).readAsStringSync()) as Map)['cases'] as List;
    for (final c in cases) {
      final q = c['q'] as String;
      final expect = (c['expect'] as List).cast<String>();
      final r = decideHelp(index, boomNormalizeTeen(q));
      final sure = r.decision == HelpDecision.answer;
      final sent = helpChunksForGpt(r, sure: sure).map((x) => x.id).toList();
      out.writeln(jsonEncode({'q': q, 'loai': c['loai'], 'expect': expect, 'sure': sure, 'top': r.hits.isEmpty ? '' : r.hits.first.chunk.id, 'got': sent.any(expect.contains), 'sent': sent}));
    }
    await out.close();
  });
}
