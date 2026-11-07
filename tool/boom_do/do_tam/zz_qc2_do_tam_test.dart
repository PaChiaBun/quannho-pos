import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/classifier/intent_classifier.dart';
import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';

void main() {
  test('đo tạm', () {
    final d = jsonDecode(File('assets/boom_help/huong_dan.json').readAsStringSync()) as Map;
    final idx = HelpIndex([for (final c in d['chunks'] as List) HelpChunk.fromJson(c as Map<String, dynamic>)]);
    final cases = jsonDecode(File(Platform.environment['CAU']!).readAsStringSync()) as List;
    var fp = 0, tp = 0, fpH = 0, tpH = 0, neg = 0, pos = 0;
    final nham = <String>[];
    final modNham = <String>[];
    for (final c in cases) {
      final q = c['q'] as String, so = c['so'] as bool;
      final cls = IntentClassifier.classify(q);
      final hw = boomHelpWins(classification: cls, help: decideHelp(idx, q), query: q);
      final hit = boomAsksShopNumber(q) && boomModuleTopics(q).isEmpty;
      if (!so && boomModuleTopics(q).isNotEmpty) modNham.add('$q → ${boomModuleTopics(q)}');
      if (so) { pos++; if (hit) tp++; if (hit && !hw) tpH++; } else { neg++; if (hit) { fp++; nham.add(q); } if (hit && !hw) fpH++; }
    }
    // ignore: avoid_print
    print('bắt nhầm $fp/$neg (thêm !helpWins: $fpH) — bắt đúng $tp/$pos (thêm !helpWins: $tpH)\n${nham.join('\n')}\nMỤC (câu ngược khớp mục): ${modNham.length}\n${modNham.join('\n')}');
  });
}
