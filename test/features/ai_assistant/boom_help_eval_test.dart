import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
import 'package:quannho_pos/features/ai_assistant/classifier/intent_classifier.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';

// Bộ câu hỏi kiểm tra Boom tra hướng dẫn (ke-hoach-trien-khai-boom.md, 4.1 mục 4).
// Ngưỡng bật theo kế hoạch: đúng trong 3 kết quả đầu ≥ 85% (Boom hiện đoạn đầu + 2 mục gợi ý).
// Luồng thật (runRouting): có ích (trả lời đúng hoặc gợi ý có mục đúng) ≥ 80%, trả lời SAI ≤ 10%.
// "Trả lời thẳng đúng" chỉ in ra để theo dõi: từ 23/10 hai đoạn đầu điểm sát nhau thì Boom đưa
// 3 lựa chọn thay vì đoán (trả lời sai 17% → 8%), nên tỉ lệ trả lời thẳng thấp hơn là đúng thiết kế.
// Câu lạc đề bị chặn ≥ minNegBlocked.
// Giới hạn đã biết (tìm theo chữ, không hiểu nghĩa): "thuê" = "thuế", "tuyển" = "tuyên" sau khi bỏ dấu.
HelpIndex loadIndex() {
  final d =
      jsonDecode(File('assets/boom_help/huong_dan.json').readAsStringSync())
          as Map;
  return HelpIndex([
    for (final c in d['chunks'] as List)
      HelpChunk.fromJson(c as Map<String, dynamic>),
  ]);
}

void runEval(
  String fixture, {
  double minTop3 = 0.85,
  double minAnswered = 0.45,
  double minNegBlocked = 1.0,
}) {
  final index = loadIndex();
  final ids = {for (final c in index.chunks) c.id};
  final cases =
      (jsonDecode(File(fixture).readAsStringSync()) as Map)['cases'] as List;
  var pos = 0, top3 = 0, top1 = 0, answeredRight = 0, negOk = 0, neg = 0;
  final misses = <String>[];
  for (final c in cases) {
    final q = c['q'] as String;
    final expect = (c['expect'] as List).cast<String>();
    for (final e in expect) {
      if (!ids.contains(e)) {
        fail('$fixture: mã đoạn "$e" không còn (bài đổi tiêu đề?) — câu "$q"');
      }
    }
    final r = decideHelp(index, q);
    if (expect.isEmpty) {
      neg++;
      if (r.decision != HelpDecision.answer) {
        negOk++;
      } else {
        misses.add(
          'LẠC ĐỀ mà vẫn trả lời: "$q" → ${r.hits.first.chunk.id} (${r.hits.first.score.toStringAsFixed(1)})',
        );
      }
      continue;
    }
    pos++;
    final got = r.hits.map((h) => h.chunk.id).toList();
    if (got.isNotEmpty && expect.contains(got.first)) top1++;
    if (got.any(expect.contains)) {
      top3++;
    } else {
      misses.add(
        'SAI: "$q" → ${got.isEmpty ? '(không có)' : got.first} '
        '(${r.hits.isEmpty ? 0 : r.hits.first.score.toStringAsFixed(1)})',
      );
    }
    if (r.decision == HelpDecision.answer &&
        got.isNotEmpty &&
        expect.contains(got.first)) {
      answeredRight++;
    }
  }
  final rTop3 = top3 / pos, rTop1 = top1 / pos, rAns = answeredRight / pos;
  // ignore: avoid_print
  print(
    '$fixture: $pos câu — đúng top1 ${(rTop1 * 100).toStringAsFixed(0)}%, top3 ${(rTop3 * 100).toStringAsFixed(0)}%, '
    'trả lời thẳng đúng ${(rAns * 100).toStringAsFixed(0)}%; lạc đề chặn $negOk/$neg\n${misses.join('\n')}',
  );
  expect(rTop3, greaterThanOrEqualTo(minTop3), reason: misses.join('\n'));
  // Sàn chống tụt: 23/10 sau luật chênh 15% là 64% / 49%.
  expect(rAns, greaterThanOrEqualTo(minAnswered), reason: misses.join('\n'));
  expect(
    negOk / neg,
    greaterThanOrEqualTo(minNegBlocked),
    reason: misses.join('\n'),
  );
}

void main() {
  test('Bộ câu hỏi của người làm bộ tìm kiếm', () {
    runEval('test/features/ai_assistant/boom_help_eval.json');
  });

  test('Bộ 128 câu theo 16 module (kiểm tra GPT 24/10)', () {
    // Trước bổ sung từ đồng nghĩa: top3 86%, top1 62%; sau: top3 95%, top1 69%. Câu tính năng không có:
    // Boom không được trả lời thẳng bằng hướng dẫn (1/16 lọt — GPT vẫn nói "chưa thấy" ở bước sau).
    runEval(
      'test/features/ai_assistant/boom_help_eval_module.json',
      minTop3: 0.9,
      // câu khó hơn → trả lời thẳng ít hơn (39%); phần còn lại tới GPT qua gợi ý / đoạn gần đúng (≥ 11 điểm)
      minAnswered: 0.35,
      minNegBlocked: 0.9,
    );
  });

  test('Bộ câu hỏi độc lập (người viết không xem bộ tìm kiếm)', () {
    // 23/10 lần chạy đầu (chưa chỉnh): top3 92%, trả lời thẳng đúng 71%, lạc đề chặn 9/12.
    // Sau khi thêm từ đệm / đồng nghĩa / luật "từ lạ" (đã nhìn các câu sai → số dưới đây lạc quan hơn thực tế).
    runEval(
      'test/features/ai_assistant/boom_help_eval_doc_lap.json',
      minNegBlocked: 0.8,
    );
  });

  test('Bộ độc lập 26/10 (128 câu mới): GPT nhận được đoạn đúng', () {
    // Lần đo đầu (chưa sửa): GPT nhận được đoạn đúng A 82% / B 79%, trả lời thẳng sai bài 9 câu → sau khi bỏ từ đơn
    // trùng nghĩa trong nhóm đồng nghĩa + gửi tới 8 đoạn: A 89% / B 89% (B không dùng để sửa).
    runGptReceives('test/features/ai_assistant/boom_help_eval_moi.json');
  });

  test('Bộ độc lập C 26/10 (111 câu, nửa là câu kể tình huống)', () {
    // Viết sau khi áp đợt 4, chưa sửa gì theo bộ này: GPT nhận được đoạn đúng 105/111 (95%); lạc đề trả lời 2/14
    // ("thuế hộ kinh doanh", "thuê mặt bằng" — "thuê" = "thuế" sau khi bỏ dấu; GPT vẫn tư vấn như câu ngoài app).
    runGptReceives(
      'test/features/ai_assistant/boom_help_eval_c.json',
      minGot: 0.9,
    );
  });

  test(
    'Luồng thật (bộ đoán ý → chọn đường → tra hướng dẫn) với cả hai bộ câu hỏi',
    () {
      for (final f in [
        'test/features/ai_assistant/boom_help_eval.json',
        'test/features/ai_assistant/boom_help_eval_doc_lap.json',
      ]) {
        runRouting(f);
      }
    },
  );

  test('Câu số liệu vẫn trả số liệu, kể cả hỏi "thế nào" / "làm gì"', () {
    final index = loadIndex();
    for (final q in [
      'doanh thu hôm nay',
      'doanh thu hôm nay thế nào',
      'doanh thu hôm nay so với hôm qua thế nào',
      'hôm nay bán được bao nhiêu',
      'món nào bán chạy nhất',
      'món nào bán chậm',
      'kho có gì sắp hết',
      'hôm nay ai đang làm',
      'ai đang trong ca làm gì',
      'kho có cái gì sắp hết',
      'mon nao ban chay nhat tuan nay',
      'doanh thu hom nay',
      'kho co gi sap het',
      'hom nay ai dang lam',
      'hôm nay ai đang làm ca mở cửa',
    ]) {
      final c = IntentClassifier.classify(q);
      expect(
        kBoomDataIntents.contains(c.intent),
        isTrue,
        reason: '"$q" → ${c.intent}',
      );
      final wins = boomHelpWins(
        classification: c,
        help: decideHelp(index, q),
        query: q,
      );
      expect(
        wins,
        isFalse,
        reason: '"$q" phải trả số liệu, không phải hướng dẫn',
      );
    }
  });

  test(
    'Câu thao tác bị đoán là số liệu → hướng dẫn (trả lời hoặc gợi ý), không phải số liệu',
    () {
      final index = loadIndex();
      for (final q in [
        'thêm nhân viên mới vô quán sao ae',
        'duyệt OT cho nhân viên làm quá giờ',
        'tắt bán món hết',
        'muốn ẩn món tạm hết hàng',
      ]) {
        final c = IntentClassifier.classify(q);
        final h = decideHelp(index, q);
        // Không còn bị đoán là số liệu (24/10: bỏ từ khoá "nhân viên" trần) → đi thẳng phần hướng dẫn; hoặc bị đoán
        // là số liệu nhưng hướng dẫn thắng / gợi ý thay.
        final toHelp =
            (!kBoomDataIntents.contains(c.intent) &&
                h.decision != HelpDecision.none) ||
            boomHelpWins(classification: c, help: h, query: q) ||
            boomHelpSuggestInstead(classification: c, help: h, query: q);
        expect(
          toHelp,
          isTrue,
          reason: '"$q" (${c.intent}, ${h.decision.name})',
        );
      }
    },
  );

  test('Bấm nút gợi ý mở đúng mục (mọi đoạn)', () {
    final index = loadIndex();
    for (final c in index.chunks) {
      final picked = index.byId(c.id);
      expect(picked?.id, c.id);
      final wins = boomHelpWins(
        classification: IntentClassifier.classify(helpSuggestionLabel(c)),
        help: HelpResult(HelpDecision.answer, [HelpHit(picked!, 1)]),
        query: helpSuggestionLabel(c),
        picked: true,
      );
      expect(wins, isTrue, reason: helpSuggestionLabel(c));
    }
  });
}

/// Đếm câu mà đoạn đúng nằm trong các đoạn app gửi GPT ([helpChunksForGpt]) — thước đo chính từ 26/10.
void runGptReceives(
  String fixture, {
  double minGot = 0.85,
  int maxNegAnswered = 2,
}) {
  final index = loadIndex();
  final cases =
      (jsonDecode(File(fixture).readAsStringSync()) as Map)['cases'] as List;
  var pos = 0, got = 0, wrongAnswer = 0, negAnswered = 0;
  final notes = <String>[];
  for (final c in cases) {
    final q = c['q'] as String;
    final expect = (c['expect'] as List).cast<String>();
    final r = decideHelp(index, q);
    final sure = r.decision == HelpDecision.answer;
    if (expect.isEmpty) {
      if (sure) negAnswered++;
      continue;
    }
    pos++;
    if (helpChunksForGpt(r, sure: sure).any((x) => expect.contains(x.id))) {
      got++;
    } else {
      notes.add('GPT KHÔNG NHẬN ĐOẠN ĐÚNG: "$q"');
    }
    if (sure && !expect.contains(r.hits.first.chunk.id)) wrongAnswer++;
  }
  // ignore: avoid_print
  print(
    '$fixture: $pos câu — GPT nhận đoạn đúng $got, trả lời thẳng sai bài $wrongAnswer; lạc đề trả lời $negAnswered\n${notes.join('\n')}',
  );
  expect(got / pos, greaterThanOrEqualTo(minGot), reason: notes.join('\n'));
  expect(wrongAnswer / pos, lessThanOrEqualTo(0.10));
  expect(negAnswered, lessThanOrEqualTo(maxNegAnswered));
}

/// Mô phỏng đúng đường đi trong boom_chat_provider: câu chào → bỏ qua; còn lại tra hướng dẫn, rồi
/// boomHelpWins quyết định hướng dẫn hay số liệu. Đếm: trả lời đúng / gợi ý có mục đúng / sai.
void runRouting(
  String fixture, {
  double minUseful = 0.80,
  double maxWrong = 0.10,
}) {
  final index = loadIndex();
  final cases =
      (jsonDecode(File(fixture).readAsStringSync()) as Map)['cases'] as List;
  var pos = 0,
      right = 0,
      suggested = 0,
      wrong = 0,
      data = 0,
      chat = 0,
      negAnswered = 0;
  final notes = <String>[];
  for (final c in cases) {
    final q = c['q'] as String;
    final expect = (c['expect'] as List).cast<String>();
    final cls = IntentClassifier.classify(q);
    final help = cls.intent == 'smalltalk' ? null : decideHelp(index, q);
    final wins = boomHelpWins(classification: cls, help: help, query: q);
    if (expect.isEmpty) {
      if (wins) {
        negAnswered++;
        notes.add('LẠC ĐỀ trả lời: "$q" → ${help!.hits.first.chunk.id}');
      }
      continue;
    }
    pos++;
    if (help == null) {
      chat++;
      notes.add('BỊ COI LÀ CHÀO: "$q"');
    } else if (wins) {
      if (expect.contains(help.hits.first.chunk.id)) {
        right++;
      } else {
        wrong++;
        notes.add('TRẢ LỜI SAI: "$q" → ${help.hits.first.chunk.id}');
      }
    } else if (kBoomDataIntents.contains(cls.intent)) {
      data++;
      notes.add('SANG SỐ LIỆU (${cls.intent}): "$q"');
    } else if (help.hits.any((h) => expect.contains(h.chunk.id)) &&
        help.decision != HelpDecision.none) {
      suggested++;
    } else {
      notes.add('KHÔNG GIÚP ĐƯỢC: "$q"');
    }
  }
  final useful = (right + suggested) / pos, wrongRate = wrong / pos;
  // ignore: avoid_print
  print(
    'LUỒNG THẬT $fixture: $pos câu — trả lời đúng $right, gợi ý đúng $suggested, trả lời sai $wrong, '
    'sang số liệu $data, coi là chào $chat; lạc đề bị trả lời $negAnswered\n${notes.join('\n')}',
  );
  expect(useful, greaterThanOrEqualTo(minUseful), reason: notes.join('\n'));
  expect(wrongRate, lessThanOrEqualTo(maxWrong), reason: notes.join('\n'));
}
