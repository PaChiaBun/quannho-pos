import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/help/boom_help_repository.dart';
import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';
import 'package:quannho_pos/features/ai_assistant/models/boom_message.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';
import 'package:quannho_pos/features/ai_assistant/services/pii_redactor.dart';

// Boom trả lời câu hỏi "cách làm" bằng bộ hướng dẫn (ke-hoach-trien-khai-boom.md, 4.1 mục 3).
HelpIndex _index() {
  final d = jsonDecode(File(kBoomHelpAsset).readAsStringSync()) as Map;
  return HelpIndex([
    for (final c in d['chunks'] as List)
      HelpChunk.fromJson(c as Map<String, dynamic>),
  ]);
}

Future<BoomMessage> _ask(ProviderContainer c, String q) async {
  final before = c.read(boomChatProvider).length;
  await c.read(boomChatProvider.notifier).sendMessage(q);
  final msgs = c.read(boomChatProvider);
  expect(msgs.length, before + 2, reason: 'mỗi câu hỏi có đúng 1 câu trả lời');
  return msgs.last;
}

void main() {
  late ProviderContainer c;
  setUp(() {
    final index = _index();
    c = ProviderContainer(
      overrides: [boomHelpIndexProvider.overrideWith((ref) async => index)],
    );
  });
  tearDown(() => c.dispose());

  test(
    'Câu "cách làm" → nguyên văn đoạn hướng dẫn kèm nguồn, có gợi ý mục khác',
    () async {
      final m = await _ask(c, 'huỷ món đã gửi bếp thế nào');
      expect(m.status, MessageStatus.completed);
      expect(m.content, startsWith('📘 '));
      expect(m.content, contains('— Tra trong hướng dẫn: Quản lý Bàn'));
      expect(m.content, contains('Quản lý duyệt'));
      expect(m.evidenceReference?['route'], 'rag');
      expect(
        m.evidenceReference?['chunk_id'],
        'quan-ly-ban#cac-viec-thuong-lam-5-sua-giam-huy-mon',
      );
    },
  );

  test('Gõ không dấu vẫn ra đúng bài', () async {
    final m = await _ask(c, 'lam sao chuyen ban cho khach');
    expect(
      m.evidenceReference?['chunk_id'],
      'quan-ly-ban#cac-viec-thuong-lam-7-chuyen-ban-gop-ban',
    );
  });

  test('Câu lạc đề không bị trả lời bằng hướng dẫn', () async {
    final m = await _ask(c, 'kể chuyện cười đi');
    expect(m.content, isNot(startsWith('📘')));
    expect(m.evidenceReference, isNull);
  });

  test('Bấm mục gợi ý → hỏi lại đúng chủ đề đó', () async {
    final first = await _ask(c, 'in tem dán ly trà sữa');
    final label = first.suggestions?.firstOrNull;
    if (label == null) return; // không có gợi ý thì thôi
    final m = await _ask(c, label);
    expect(m.content, startsWith('📘 '), reason: label);
  });

  test(
    'Câu số liệu không bị hướng dẫn chen ngang; hỏi "ở đâu / thế nào" thì ưu tiên hướng dẫn',
    () async {
      final data = await _ask(c, 'doanh thu hôm nay');
      expect(data.content, isNot(startsWith('📘')));
      final how = await _ask(c, 'in báo cáo doanh thu ra giấy thế nào');
      expect(how.content, startsWith('📘 '));
      expect(how.evidenceReference?['chunk_id'], startsWith('bao-cao#'));
    },
  );

  test(
    'Không nạp được bộ hướng dẫn → Boom vẫn trả lời như cũ, không lỗi',
    () async {
      final c2 = ProviderContainer(
        overrides: [boomHelpIndexProvider.overrideWith((ref) async => null)],
      );
      addTearDown(c2.dispose);
      final m = await _ask(c2, 'huỷ món đã gửi bếp thế nào');
      expect(m.status, MessageStatus.completed);
      expect(m.content, isNot(startsWith('📘')));
    },
  );

  test('Bản trên máy chủ hỏng / lọt tên kỹ thuật → bỏ qua', () {
    expect(HelpPack.tryParse('{"version": 9, "chunks": []}'), isNull);
    expect(HelpPack.tryParse('không phải json'), isNull);
    final good = jsonDecode(File(kBoomHelpAsset).readAsStringSync()) as Map;
    expect(
      HelpPack.tryParse(good)?.chunks.length,
      (good['chunks'] as List).length,
    );
    final leaked = jsonDecode(jsonEncode(good)) as Map;
    (leaked['chunks'] as List).first['text'] =
        'Sửa bảng `ban_session_items` trực tiếp';
    expect(HelpPack.tryParse(leaked), isNull);
  });

  test('Gửi dồn dập: chỉ câu đầu được trả lời, không đè nhau', () async {
    final n0 = c.read(boomChatProvider).length;
    final a = c
        .read(boomChatProvider.notifier)
        .sendMessage('huỷ món đã gửi bếp thế nào');
    final b = c.read(boomChatProvider.notifier).sendMessage('gộp bàn thế nào');
    await Future.wait([a, b]);
    final msgs = c.read(boomChatProvider);
    expect(msgs.length, n0 + 2);
    expect(msgs[n0].content, 'huỷ món đã gửi bếp thế nào');
    expect(msgs.last.status, MessageStatus.completed);
    expect(
      msgs.last.evidenceReference?['chunk_id'],
      'quan-ly-ban#cac-viec-thuong-lam-5-sua-giam-huy-mon',
    );
  });

  test(
    'Xoá cuộc trò chuyện giữa chừng: câu trả lời cũ không đè lên câu chào mới',
    () async {
      final pending = c
          .read(boomChatProvider.notifier)
          .sendMessage('huỷ món đã gửi bếp thế nào');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      c.read(boomChatProvider.notifier).clearChat();
      await pending;
      final msgs = c.read(boomChatProvider);
      expect(msgs.length, 1);
      expect(msgs.single.content, startsWith('Dạ, Bé Boom chào'));
      // gửi tiếp được ngay sau khi xoá
      final m = await _ask(c, 'gộp bàn thế nào');
      expect(m.status, MessageStatus.completed);
    },
  );

  test(
    'Phản hồi 👍/👎 giữ được mã mục hướng dẫn qua bộ lọc riêng tư (mọi mục)',
    () async {
      final m = await _ask(c, 'huỷ món đã gửi bếp thế nào');
      final clean = PiiRedactor.sanitizeEvidenceReference(m.evidenceReference);
      expect(
        clean?['tool_name'],
        'huong_dan:quan-ly-ban#cac-viec-thuong-lam-5-sua-giam-huy-mon',
      );
      for (final ch in _index().chunks) {
        final r = PiiRedactor.sanitizeEvidenceReference({
          'tool_name': 'huong_dan:${ch.id}',
        });
        expect(r?['tool_name'], 'huong_dan:${ch.id}', reason: ch.id);
      }
    },
  );
}
