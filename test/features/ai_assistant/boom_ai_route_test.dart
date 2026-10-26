import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/providers/session_provider.dart';
import 'package:quannho_pos/core/repositories/chain_repository.dart';
import 'package:quannho_pos/core/services/user_auth_service.dart'
    show SessionData;
import 'package:quannho_pos/features/ai_assistant/help/boom_help_repository.dart';
import 'package:quannho_pos/features/ai_assistant/help/help_search.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';
import 'package:quannho_pos/features/ai_assistant/models/boom_message.dart';
import 'package:quannho_pos/features/ai_assistant/providers/boom_chat_provider.dart';
import 'package:quannho_pos/features/ai_assistant/services/boom_ai_service.dart';
import 'package:quannho_pos/features/ai_assistant/services/boom_module_data_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Boom + GPT qua máy chủ (ke-hoach-trien-khai-boom.md Bước 4.2) — dùng GPT giả, không gọi mạng.
class FakeAi extends BoomAiService {
  FakeAi() : super(SupabaseClient('http://127.0.0.1:9', 'test-key'));
  BoomAiReply? next = const BoomAiReply(
    '1. Bấm "Huỷ món".\n2. Nhờ Quản lý duyệt.',
    'log-1',
  );
  BoomAiReply? adviceNext;
  final asked = <List<String>>[];
  final advised = <String>[];
  final chains = <Map<String, dynamic>?>[];
  final moduleFacts = <Map<String, dynamic>?>[];
  final histories = <String?>[];
  final memorySinces = <DateTime?>[];
  final unanswered = <String>[];
  final rated = <String>[];
  final feedbacks = <String>[];
  bool feedbackOk = true;

  @override
  bool get canSend => true;

  String? xungHo;
  final setXungHoCalls = <String>[];

  @override
  Future<({bool ok, String? xungHo})> getXungHo() async =>
      (ok: true, xungHo: xungHo);

  @override
  Future<bool> setXungHo(String v) async {
    setXungHoCalls.add(v);
    xungHo = v;
    return true;
  }

  @override
  Future<BoomAiReply?> ask({
    required String storeId,
    required String question,
    required List<HelpChunk> chunks,
    int packVersion = 0,
    BoomTurn? history,
  }) async {
    asked.add([for (final c in chunks) c.id]);
    histories.add(history?.question);
    return next;
  }

  @override
  Future<BoomAiReply?> advise({
    required String storeId,
    required String question,
    Map<String, dynamic>? facts,
    Map<String, dynamic>? chain,
    Map<String, dynamic>? modules,
    BoomTurn? history,
    DateTime? memorySince,
  }) async {
    advised.add(question);
    chains.add(chain);
    moduleFacts.add(modules);
    memorySinces.add(memorySince);
    histories.add(history?.question);
    return adviceNext;
  }

  @override
  void logUnanswered({required String storeId, required String question}) =>
      unanswered.add(question);

  final transcripts = <String>[];

  @override
  void transcript({
    required String storeId,
    required String question,
    required String answer,
    String? tool,
  }) => transcripts.add('$tool|$question');

  @override
  Future<bool> feedback({
    required String storeId,
    required String question,
    required String answer,
    required bool up,
    String? reason,
    String? tool,
  }) async {
    feedbacks.add('${up ? 'up' : 'down'}|$tool|$question');
    return feedbackOk;
  }

  bool rateOk = true;

  @override
  Future<bool> rate(String logId, {required bool up, String? reason}) async {
    rated.add('$logId:${up ? 'up' : 'down'}');
    return rateOk;
  }
}

HelpIndex _index() {
  final d = jsonDecode(File(kBoomHelpAsset).readAsStringSync()) as Map;
  return HelpIndex([
    for (final c in d['chunks'] as List)
      HelpChunk.fromJson(c as Map<String, dynamic>),
  ]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  late ProviderContainer c;
  late FakeAi ai;
  final loaderCalls = <String>[];
  final deniedModules = <BoomModule>{};
  const ownerPerms = BoomPerms(
    isOwner: true,
    canonicalRole: 'owner',
    modules: [],
    active: {'pos', 'report', 'finance', 'kho', 'loyalty', 'chamcong'},
  );
  BoomPerms? testPerms = ownerPerms;
  setUp(() {
    testPerms = ownerPerms;
    loaderCalls.clear();
    deniedModules.clear();
    ai = FakeAi();
    final index = _index();
    c = ProviderContainer(
      overrides: [
        boomHelpIndexProvider.overrideWith((ref) async => index),
        boomAiServiceProvider.overrideWithValue(ai),
        boomPermsLoaderProvider.overrideWithValue((store) async => testPerms),
        boomModuleLoaderProvider.overrideWithValue((store, topics, q) async {
          loaderCalls.add(q);
          return (
            facts: {
              for (final t in topics)
                if (!deniedModules.contains(t))
                  kBoomModuleKeys[t]!: {'period': 'Tháng này'},
            },
            denied: [
              for (final t in topics)
                if (deniedModules.contains(t)) t,
            ],
          );
        }),
      ],
    );
    c
        .read(sessionProvider.notifier)
        .setSession(
          const SessionData(
            userId: 'u1',
            phone: '0',
            displayName: 'NV',
            storeId: 's1',
            storeName: 'Quan',
            storeCode: 'Q1',
            role: 'waiter',
            isOwner: false,
          ),
        );
  });
  tearDown(() {
    c.dispose();
    ChainRepository.rpcOverride = null;
  });

  Future<BoomMessage> ask(String q) async {
    await c.read(boomChatProvider.notifier).sendMessage(q);
    return c.read(boomChatProvider).last;
  }

  test(
    'Có đoạn hướng dẫn → câu trả lời GPT kèm nguồn; sổ hỏi đáp gắn vào phản hồi',
    () async {
      final m = await ask('huỷ món đã gửi bếp thế nào');
      expect(
        ai.asked.single.first,
        'quan-ly-ban#cac-viec-thuong-lam-5-sua-giam-huy-mon',
      );
      expect(m.content, startsWith('1. Bấm "Huỷ món".'));
      // Chủ Quán 24/10: không gắn dòng nguồn "— Theo hướng dẫn: …" (nguồn mở qua nút gợi ý)
      expect(m.content, isNot(contains('Theo hướng dẫn')));
      expect(m.evidenceReference?['query_id'], 'log-1');
      expect(m.evidenceReference?['tool_name'], startsWith('huong_dan_gpt:'));
    },
  );

  test(
    'Xin tư vấn món nên quảng cáo → tư vấn kèm số liệu; câu nói tiếp gửi kèm lượt trước (Chủ Quán test 24/10)',
    () async {
      ai.adviceNext = const BoomAiReply('Đẩy Cà phê sữa.', 'log-adv');
      const q1 =
          'Các món nào đang bán được nhất và nên tập trung vào quảng cáo bán món nào ?';
      final m1 = await ask(q1);
      expect(ai.advised.single, q1);
      expect(ai.histories.single, isNull);
      expect(m1.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu');
      final m2 = await ask('bạn kiểm tra và đề xuất cho tôi đi');
      expect(ai.asked, isEmpty);
      expect(ai.advised.last, 'bạn kiểm tra và đề xuất cho tôi đi');
      expect(ai.histories.last, q1);
      expect(m2.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu');
      // Câu hỏi mới có nội dung riêng → hướng dẫn như thường, không kèm lượt trước
      await ask('thêm nhân viên mới đi');
      expect(ai.asked.single.first, startsWith('nhan-vien#'));
      expect(ai.histories.last, isNull);
      // Chưa bấm làm mới → máy chủ nhớ đủ 5 giờ (không gửi mốc)
      expect(ai.memorySinces.first, isNull);
      // Xoá đoạn chat → quên lượt trước; máy chủ chỉ nhớ từ lúc làm mới
      final before = DateTime.now();
      c.read(boomChatProvider.notifier).clearChat();
      await ask('bạn kiểm tra và đề xuất cho tôi đi');
      expect(ai.histories.last, isNull);
      await ask('Quảng bá quán nhỏ trên TikTok thế nào cho hiệu quả');
      expect(
        ai.advised.last,
        'Quảng bá quán nhỏ trên TikTok thế nào cho hiệu quả',
      );
      expect(ai.memorySinces.last!.isBefore(before), isFalse);
    },
  );

  test(
    'Xin Boom báo cáo / phân tích → tư vấn kèm số liệu, không chỉ đường màn Báo cáo (Chủ Quán test 24/10)',
    () async {
      ai.adviceNext = const BoomAiReply('Hôm nay 129 đơn…', 'log-bc');
      for (final q in [
        'Tình hình kinh doanh hôm nay thế nào báo cáo xem',
        'tôi muốn bạn báo cáo và phân tích chứ tôi đã biết có app báo cáo rồi',
      ]) {
        final m = await ask(q);
        expect(ai.advised.last, q);
        expect(m.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu');
      }
      expect(ai.asked, isEmpty);
    },
  );

  test(
    'Lên kế hoạch quảng cáo dựa trên tình hình quán → tự đọc số; "Chi tiết hơn đi" → nói tiếp kèm số (Chủ Quán 24/10)',
    () async {
      ai.adviceNext = const BoomAiReply('Kế hoạch…', 'log-kh');
      const q1 =
          'Dựa theo tình hình kinh doanh của quán hãy giúp tôi lên kế hoạch quảng cáo tháng sau';
      final m1 = await ask(q1);
      expect(ai.advised.last, q1);
      expect(m1.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu');
      final m2 = await ask('Chi tiết hơn đi');
      expect(ai.advised.last, 'Chi tiết hơn đi');
      expect(ai.histories.last, q1);
      expect(m2.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu');
      expect(ai.asked, isEmpty);
    },
  );

  test(
    'Nói tiếp sau lượt tư vấn chung → tư vấn tiếp kèm lượt trước (QC vòng 3)',
    () async {
      ai.adviceNext = const BoomAiReply('1. Quay video pha chế.', 'log-tt');
      const q1 = 'Quảng bá quán nhỏ trên TikTok thế nào cho hiệu quả';
      await ask(q1);
      for (final q in [
        'bạn kiểm tra và đề xuất cho tôi đi',
        'tiếp tục đi',
        'giải thích cụ thể hơn được không',
      ]) {
        await ask(q);
        expect(ai.asked, isEmpty, reason: q);
        expect(ai.advised.last, q);
        expect(ai.histories.last, isNotNull, reason: q);
      }
    },
  );

  test('Lượt bị từ chối / chưa trả lời được không làm câu nói tiếp', () async {
    ai.adviceNext = const BoomAiReply(
      'Bé Boom chỉ hỗ trợ việc dùng app…',
      null,
      blocked: true,
    );
    await ask('Đảng Cộng sản thành lập năm nào');
    ai.adviceNext = const BoomAiReply('ok', 'log-2');
    await ask('nói rõ hơn đi');
    expect(ai.histories.last, isNull);
  });

  test('GPT lỗi / chưa bật → nguyên văn đoạn đã duyệt', () async {
    ai.next = null;
    final m = await ask('huỷ món đã gửi bếp thế nào');
    expect(m.content, startsWith('📘 '));
    expect(m.evidenceReference?['query_id'], isNull);
  });

  test(
    'Chưa chắc (2–3 mục điểm sát nhau) → gửi cả các mục cho GPT chọn',
    () async {
      final index = _index();
      final q = 'tạo mã giảm 10% cho khách quen';
      final r = decideHelp(index, q);
      if (r.decision != HelpDecision.suggest) {
        return; // bộ tìm kiếm đổi thì bỏ qua ca này
      }
      await ask(q);
      expect(ai.asked.single.length, r.wider.length); // tới 5 đoạn để GPT tự chọn (26/10)
      expect(r.wider.length, inInclusiveRange(r.hits.length, 5));
      expect([for (final h in r.wider.take(3)) h.chunk.id], [for (final h in r.hits) h.chunk.id]);
      expect(r.hits.length, lessThanOrEqualTo(3)); // gợi ý cho người dùng vẫn tối đa 3 mục
    },
  );

  test(
    'Không có hướng dẫn, tư vấn chưa bật / lỗi → ghi hàng chờ cải thiện',
    () async {
      final m = await ask('giá vàng hôm nay bao nhiêu');
      expect(ai.asked, isEmpty);
      expect(ai.advised.single, 'giá vàng hôm nay bao nhiêu');
      expect(ai.unanswered.single, 'giá vàng hôm nay bao nhiêu');
      expect(m.content, isNot(startsWith('📘')));
    },
  );

  test(
    'Không có hướng dẫn → GPT tư vấn kinh doanh, ghi rõ là gợi ý; 👍/👎 vào sổ',
    () async {
      ai.adviceNext = const BoomAiReply(
        '1. Combo sáng giá mềm.\n2. Tích điểm khách quen.',
        'log-adv',
      );
      final m = await ask('Quảng bá quán nhỏ trên TikTok thế nào cho hiệu quả');
      expect(ai.asked, isEmpty);
      expect(ai.unanswered, isEmpty);
      expect(m.content, startsWith('1. Combo sáng'));
      expect(m.content, isNot(contains('Gợi ý của Boom')));
      expect(m.content, isNot(contains('Theo hướng dẫn')));
      expect(m.evidenceReference?['query_id'], 'log-adv');
      await c
          .read(boomChatProvider.notifier)
          .submitFeedbackForMessage(m.id, rating: 'thumbs_up');
      expect(ai.rated.single, 'log-adv:up');
    },
  );

  test('Câu ngoài phạm vi → hiện đúng câu từ chối của máy chủ', () async {
    const refusal =
        'Bé Boom chỉ hỗ trợ việc dùng app Quán Nhỏ… xin phép không trả lời ạ.';
    ai.adviceNext = const BoomAiReply(refusal, null, blocked: true);
    final m = await ask('cậu nghĩ gì về bầu cử Mỹ');
    expect(m.content, refusal);
    expect(m.evidenceReference, isNull);
    expect(ai.unanswered, isEmpty);
    // Câu đã có bài hướng dẫn chắc chắn nhưng GPT từ chối → vẫn đưa bài đã duyệt nguyên văn
    ai.next = const BoomAiReply(refusal, null, blocked: true);
    final m2 = await ask('huỷ món đã gửi bếp thế nào');
    expect(m2.content, startsWith('📘 '));
  });

  test('Câu số liệu không gửi ra ngoài', () async {
    await ask('doanh thu hôm nay');
    expect(ai.asked, isEmpty);
    expect(ai.unanswered, isEmpty);
  });

  test('Bấm nút gợi ý → mở đúng mục nguyên văn, không tốn lượt GPT', () async {
    ai.next = null; // lần đầu trả nguyên văn để có nút gợi ý
    final first = await ask('huỷ món đã gửi bếp thế nào');
    final label = first.suggestions?.firstOrNull;
    if (label == null) {
      return;
    }
    ai.asked.clear();
    final m = await ask(label);
    expect(ai.asked, isEmpty);
    expect(m.content, startsWith('📘 '));
  });

  test('👍/👎 trên câu trả lời GPT ghi vào sổ hỏi đáp', () async {
    final m = await ask('huỷ món đã gửi bếp thế nào');
    await c
        .read(boomChatProvider.notifier)
        .submitFeedbackForMessage(
          m.id,
          rating: 'thumbs_down',
          reasonCode: 'incorrect_data',
        );
    expect(ai.rated.single, 'log-1:down');
    expect(c.read(boomChatProvider).last.feedbackStatus, 'submitted');
  });

  test(
    'Hỏi số liệu quán khác → từ chối ngay trên máy, không trả nhầm số của quán mình',
    () async {
      for (final q in [
        'Doanh thu quán đối thủ hôm nay bao nhiêu?',
        'quán bên cạnh bán chạy món gì?',
        'Phúc Long lãi bao nhiêu',
      ]) {
        final m = await ask(q);
        expect(m.content, kBoomOtherStoreRefusal, reason: q);
      }
      expect(ai.asked, isEmpty);
      expect(ai.advised, isEmpty);
      expect(boomAsksOtherStore('đối thủ giảm giá thì tớ nên làm gì'), isFalse);
      expect(boomAsksOtherStore('doanh thu hôm nay'), isFalse);
      expect(
        boomAsksOtherStore('Đổi thứ tự món có bán được nhiều hơn không'),
        isFalse,
      );
      // QC vòng 2: xin tư vấn cạnh tranh → không chặn; gõ dấu tách rời (Windows) vẫn nhận ra
      for (final q in [
        'So với quán khác, doanh thu quán mình thấp, làm sao tăng?',
        'Làm sao để doanh thu vượt đối thủ?',
        'Quán bên cạnh bán chạy hơn mình, nên làm gì?',
        'Khách bỏ sang quán khác, lợi nhuận giảm, làm sao giữ khách?',
      ]) {
        expect(boomAsksOtherStore(q), isFalse, reason: q);
      }
      expect(
        boomAsksOtherStore(
          'Phu\u0301c Long la\u0303i bao nhie\u0302u mo\u0323\u0302t na\u0306m?',
        ),
        isTrue,
      );
      expect(
        boomComposeVi('nhie\u0302u mo\u0323\u0302t ngu\u031bo\u031b\u0300i'),
        'nhiêu một người',
      );
      // Unikey "Unicode tổ hợp": chữ ô / ư liền + dấu thanh tách rời
      expect(boomComposeVi('đô\u0301i thu\u0309 ngươ\u0300i'), 'đối thủ người');
      expect(
        boomAsksOtherStore('Đô\u0301i thu\u0309 doanh thu bao nhiêu'),
        isTrue,
      );
      // QC vòng 3: xin học hỏi đối thủ → không chặn; hỏi số tăng / giảm của đối thủ → chặn
      for (final q in [
        'Highlands bán được nhiều nhờ đâu, quán nhỏ học được gì?',
        'Mở quán cạnh Highlands thì doanh thu có bị ảnh hưởng không?',
        'Khách cũ chuyển sang quán khác, bán được ít hẳn',
      ]) {
        expect(boomAsksOtherStore(q), isFalse, reason: q);
      }
      expect(
        boomAsksOtherStore('Doanh thu Highlands tăng bao nhiêu năm nay'),
        isTrue,
      );
      // QC vòng 4: đại từ lịch sự đầu câu không làm lọt câu hỏi số liệu đối thủ
      for (final q in [
        'em muốn biết doanh thu đối thủ bao nhiêu',
        'Lợi nhuận Highlands có cao không',
        'quán đối diện bán được bao nhiêu ly',
      ]) {
        expect(boomAsksOtherStore(q), isTrue, reason: q);
      }
    },
  );

  test(
    'Câu từ bộ nhớ đã duyệt: hiện như câu GPT, đếm riêng, ghi "đã duyệt"',
    () async {
      ai.next = const BoomAiReply('1. Bấm "Huỷ món".', 'log-c', cached: true);
      final m = await ask('huỷ món đã gửi bếp thế nào');
      expect(m.content, isNot(contains('Theo hướng dẫn')));
      expect(m.evidenceReference?['tool_name'], startsWith('huong_dan_cache:'));
      expect(m.evidenceReference?['query_id'], 'log-c');
      ai.adviceNext = const BoomAiReply('Tích điểm.', 'log-a', cached: true);
      final a = await ask('Quảng bá quán nhỏ trên TikTok thế nào cho hiệu quả');
      expect(a.content, isNot(contains('Gợi ý của Boom')));
      expect(a.evidenceReference?['tool_name'], 'boom_tu_van_cache');
    },
  );

  test(
    '👍/👎 câu không gọi GPT (hướng dẫn nguyên văn) → ghi sổ hỏi đáp, không đòi ghép nối thiết bị',
    () async {
      ai.next = null; // GPT không trả → nguyên văn, không có log_id
      final m = await ask('huỷ món đã gửi bếp thế nào');
      expect(m.evidenceReference?['query_id'], isNull);
      await c
          .read(boomChatProvider.notifier)
          .submitFeedbackForMessage(
            m.id,
            rating: 'thumbs_down',
            reasonCode: 'incorrect_data',
          );
      expect(ai.feedbacks.single, startsWith('down|huong_dan:'));
      expect(c.read(boomChatProvider).last.feedbackStatus, 'submitted');
    },
  );

  test(
    'Chưa ghi được phiếu chấm (mất mạng…) → báo chưa gửi, không đòi ghép nối thiết bị',
    () async {
      ai.next = null;
      ai.feedbackOk = false;
      final m = await ask('huỷ món đã gửi bếp thế nào');
      await c
          .read(boomChatProvider.notifier)
          .submitFeedbackForMessage(m.id, rating: 'thumbs_up');
      final last = c.read(boomChatProvider).last;
      expect(last.feedbackStatus, 'failed');
      expect(last.feedbackStatus, isNot('pairing_required'));
    },
  );

  test('Chấm lỗi → bấm gửi lại thành công (cùng lý do)', () async {
    ai.next = null;
    ai.feedbackOk = false;
    final m = await ask('huỷ món đã gửi bếp thế nào');
    final n = c.read(boomChatProvider.notifier);
    final r1 = await n.submitFeedbackForMessage(
      m.id,
      rating: 'thumbs_down',
      reasonCode: 'incorrect_data',
    );
    expect(r1['error'], 'QA_LOG_UNAVAILABLE');
    expect(c.read(boomChatProvider).last.feedbackStatus, 'failed');
    ai.feedbackOk = true;
    ai.feedbacks.clear();
    final r2 = await n.submitFeedbackForMessage(
      m.id,
      rating: 'thumbs_down',
      reasonCode: 'incorrect_data',
    );
    expect(r2['success'], isTrue);
    expect(c.read(boomChatProvider).last.feedbackStatus, 'submitted');
    expect(ai.feedbacks.length, 1);
  });

  test(
    'Câu GPT không chấm được vào dòng cũ (quá 7 ngày / người khác hỏi) → ghi dòng phiếu riêng',
    () async {
      final m = await ask('huỷ món đã gửi bếp thế nào');
      expect(m.evidenceReference?['query_id'], 'log-1');
      ai.rateOk = false;
      await c
          .read(boomChatProvider.notifier)
          .submitFeedbackForMessage(
            m.id,
            rating: 'thumbs_down',
            proposedAnswer: 'Bấm Huỷ món rồi nhờ quản lý duyệt',
          );
      expect(ai.feedbacks.single, startsWith('down|'));
      expect(c.read(boomChatProvider).last.feedbackStatus, 'submitted');
    },
  );

  test(
    'Bộ tìm chưa chắc nhưng có đoạn gần đúng (≥ 11 điểm) → vẫn hỏi GPT với 3 đoạn đầu',
    () async {
      const q = 'bán trà chanh cả chục ly mà nguyên liệu không thấy giảm';
      final h = decideHelp(_index(), q);
      if (h.decision != HelpDecision.none ||
          h.hits.first.score < kHelpWeakScore) {
        return; // bộ tìm đổi thì bỏ qua ca này
      }
      final m = await ask(q);
      expect(ai.asked.single.length, h.wider.length); // tới 5 đoạn để GPT tự chọn (26/10)
      expect(m.content, isNot(contains('hướng dẫn:')));
    },
  );

  test(
    'Bé Boom hỏi một lần Anh hay Chị, lưu theo tài khoản, rồi gọi đúng',
    () async {
      // chờ đọc cách gọi (chưa chọn) → lời chào hỏi Anh / Chị kèm 2 nút
      c.read(boomChatProvider);
      await Future<void>.delayed(Duration.zero);
      final hello = c.read(boomChatProvider).first;
      expect(
        hello.content,
        contains('Bé Boom nên gọi Anh/Chị NV là Anh hay Chị ạ?'),
      );
      expect(hello.content, contains('Anh/Chị NV'));
      expect(hello.suggestions, [kBoomGoiAnh, kBoomGoiChi]);
      final m = await ask('gọi tôi là chị'); // gõ tay, chữ thường vẫn nhận
      expect(ai.setXungHoCalls, ['chi']);
      expect(m.content, contains('Bé Boom gọi là Chị NV'));
      expect(ai.asked, isEmpty); // không gọi GPT
      expect(m.content, isNot(contains('cậu')));
    },
  );

  test('Xưng hô tuỳ chọn: "Gọi chế xưng bé" → lưu "che", gọi "Chế", không gửi GPT (Chủ Quán chấm sai 25/10)', () async {
    c.read(boomChatProvider);
    await Future<void>.delayed(Duration.zero);
    final m = await ask('Gọi chế xưng bé');
    expect(ai.setXungHoCalls, ['che']);
    expect(m.content, contains('Bé Boom gọi là Chế NV'));
    expect(ai.asked, isEmpty);
    // câu hỏi bình thường có chữ "gọi" không bị coi là đổi cách gọi
    await ask('gọi món cho bàn 3 thế nào');
    expect(ai.setXungHoCalls, ['che']);
  });

  group('So sánh chi nhánh (báo cáo chuỗi, Chủ Quán 25/10)', () {
    late List<String> rpcs;
    late List<Map<String, dynamic>> reports;
    Map<String, dynamic> store(String id, String name, int orders, num rev) => {
      'store_id': id,
      'name': name,
      'store_code': id,
      'orders': orders,
      'revenue': rev,
      'discount': 0,
    };
    void chainOwner({bool hasChain = true, bool fail = false}) {
      rpcs = [];
      reports = [];
      ChainRepository.rpcOverride = (fn, params) async {
        rpcs.add(fn);
        if (fail) return {'success': false, 'error': 'OWNER_ONLY'};
        if (fn == 'list_my_chains_v1') {
          return {
            'success': true,
            'chains': hasChain
                ? [
                    {
                      'id': 'c1',
                      'name': 'Bún Nhà Làm',
                      'stores': [
                        {'store_id': 's1', 'name': 'Quận 1'},
                        {'store_id': 's2', 'name': 'Quận 3'},
                      ],
                    },
                  ]
                : [],
            'owned_stores': [],
          };
        }
        reports.add(params);
        // Kỳ đang chạy kết thúc ở "bây giờ"; kỳ trước kết thúc sớm hơn
        final first = DateTime.parse(
          params['p_to'] as String,
        ).isAfter(DateTime.now().subtract(const Duration(minutes: 5)));
        return {
          'success': true,
          'chain': {'id': 'c1', 'name': 'Bún Nhà Làm'},
          'stores': [
            store('s1', 'Quận 1', first ? 120 : 100, first ? 9000000 : 8000000),
            store('s2', 'Quận 3', first ? 60 : 80, first ? 4200000 : 5600000),
          ],
          'totals': {},
          'daily': [
            {
              'date': '2026-10-18',
              'store_id': 's2',
              'orders': 3,
              'revenue': 150000,
            },
            {
              'date': '2026-10-25',
              'store_id': 's2',
              'orders': 1,
              'revenue': 50000,
            },
            {
              'date': '2026-10-20',
              'store_id': 's1',
              'orders': 2,
              'revenue': 90000,
            },
          ],
          'excluded_stores': [],
        };
      };
    }

    test(
      'Chủ chuỗi hỏi so sánh → GPT nhận số từng chi nhánh kỳ này + kỳ trước; nói tiếp đọc lại',
      () async {
        chainOwner();
        ai.adviceNext = const BoomAiReply('Quận 3 giảm 25%…', 'log-ch');
        const q = 'So sánh doanh thu 2 quán tháng này giúp tôi';
        final m = await ask(q);
        expect(ai.advised.single, q);
        expect(ai.asked, isEmpty);
        final ch = ai.chains.single!;
        expect(ch['name'], 'Bún Nhà Làm');
        expect(ch['period'], startsWith('Tháng này'));
        expect(ch['prev_period'], startsWith('cùng kỳ tháng trước'));
        final stores = (ch['stores'] as List).cast<Map<String, dynamic>>();
        expect(stores.first, containsPair('current', true));
        expect(stores.last['prev_revenue'], 5600000);
        expect(stores.last.containsKey('current'), isFalse);
        expect(reports, hasLength(2));
        expect(m.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu_chuoi');
        await ask('chi tiết hơn đi');
        expect(ai.chains.last, isNotNull);
        expect(ai.histories.last, q);
      },
    );

    test(
      'Không nói kỳ → mặc định tháng này; "chi nhánh khác" của chủ không bị coi là đối thủ',
      () async {
        chainOwner();
        ai.adviceNext = const BoomAiReply('…', 'log-ch2');
        final m = await ask('doanh thu chi nhánh khác bao nhiêu');
        expect(m.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu_chuoi');
        expect(ai.chains.single!['period'], startsWith('Tháng này'));
        // Kỳ ≥ 3 ngày → doanh thu theo thứ từng chi nhánh (Chủ nhật = ô cuối)
        await ask('so sánh các chi nhánh tuần trước');
        final st = (ai.chains.last!['stores'] as List).cast<Map>();
        expect(ai.chains.last!['period'], startsWith('Tuần trước'));
        expect(st.last['by_weekday'], [0, 0, 0, 0, 0, 0, 200000]);
        expect(st.first['by_weekday'], [0, 90000, 0, 0, 0, 0, 0]);
      },
    );

    test(
      'Không có chuỗi / không phải chủ → đi như cũ (hướng dẫn), không gửi số chuỗi',
      () async {
        for (final fail in [false, true]) {
          chainOwner(hasChain: false, fail: fail);
          await ask('chi nhánh nào bán kém nhất');
          expect(rpcs, ['list_my_chains_v1']);
        }
        expect(ai.chains.whereType<Map>(), isEmpty);
      },
    );

    test(
      'Câu tạo / gỡ chuỗi, hỏi chỗ xem, hỏi đối thủ → không đọc báo cáo chuỗi',
      () async {
        chainOwner();
        for (final q in [
          'tạo chuỗi cửa hàng thế nào',
          'thêm quán vào chuỗi ở đâu',
          'xem doanh thu các chi nhánh ở đâu',
          'xuất excel doanh thu các chi nhánh',
          'doanh thu chuỗi khác bao nhiêu',
          'chi nhánh highlands gần đây bán được bao nhiêu',
          // QC 25/10: hỏi cách dùng / lỗi / chuỗi trên thị trường
          'chuỗi cửa hàng hoạt động thế nào',
          'cách in hoá đơn cho chi nhánh',
          'nhân viên chi nhánh 2 có được xem doanh thu không',
          'đơn hàng của chi nhánh bị mất',
          'chuỗi ngày bán tốt',
          'chuỗi trà sữa nào bán tốt nhất việt nam',
          'quán kia đối diện bán đông hơn quán tôi',
          'doanh thu quán tôi hôm nay',
          // QC vòng 2: không dấu trùng chữ khác, quán người khác, đối thủ không dấu
          'sinh to chuoi ban chay khong',
          'chuoi chien nen ban gia bao nhieu',
          'co so dien thoai khach khong',
          'co so lieu doanh thu hom nay khong',
          'chuoi cung ung nguyen lieu nen chon ai',
          'các quán cà phê gần trường nên bán món gì',
          'mấy quán quanh đây bán giá bao nhiêu',
          'quán kia bán rẻ hơn mình nên làm gì',
          '2 quán cạnh nhau bán cùng món nên làm gì',
          'có nên mở chuỗi không',
          'doanh thu chuoi khac the nao',
          'so sanh chuoi minh voi chuoi khac',
          'doanh thu cua doi thu so voi cac quan cua toi',
          'doanh thu 3 quán hôm nay',
          'món nào bán chạy nhất chi nhánh này',
          'hôm nay chi nhánh này bán bao nhiêu',
          'chi nhanh ngan hang nao gan nhat',
        ]) {
          expect(boomAsksChain(q), isFalse, reason: q);
        }
        for (final q in [
          'So sánh doanh thu 2 quán tháng này',
          'chi nhánh nào bán kém nhất tuần này',
          'tình hình các quán của tôi hôm nay ra sao',
          'so sánh quán kia với quán này tháng trước',
          'làm sao để chi nhánh quận 3 bán tốt hơn',
          // QC 25/10: câu tự nhiên trước đây bị bỏ sót
          'Chi nhánh nào cần cải thiện?',
          'so sanh doanh thu cac chi nhanh',
          'chi nhanh nao ban kem nhat',
          'chi nhánh 2 dạo này sao rồi',
          'so sánh 2 cơ sở',
          'so sánh quán quận 1 với quán quận 3',
          'nên dồn nhân viên sang chi nhánh nào cuối tuần',
          'có nên đóng chi nhánh 2 không',
          'so sanh doanh thu chuoi cua toi thang nay',
          'co so 2 ban co tot khong',
          'so sánh doanh thu với quán khác của tôi',
          'so sánh số liệu các chi nhánh',
          'số liệu các chi nhánh tháng này',
          'từ khi mở chi nhánh 2 doanh thu thế nào',
          'doanh thu cả hệ thống tháng này',
          'quan nao trong chuoi ban tot nhat',
        ]) {
          expect(boomAsksChain(q), isTrue, reason: q);
        }
      },
    );
  });

  group('Số liệu các module — chỉ đọc, theo quyền (Chủ Quán 25/10)', () {
    test(
      'Câu xin số thu chi / kho / nhân sự / khách / khuyến mãi → đúng module; câu cách làm → không',
      () {
        final cases = {
          'tháng này chi phí gì nhiều nhất': {BoomModule.finance},
          'tháng này quán lời hay lỗ': {BoomModule.finance},
          'hàng nào sắp hết cần nhập': {BoomModule.kho},
          'tháng này nhập hàng tốn bao nhiêu tiền': {BoomModule.kho},
          'nhân viên nào làm nhiều giờ nhất tháng này': {BoomModule.nhanSu},
          'tháng này tôi làm bao nhiêu giờ': {BoomModule.nhanSu},
          'khách quen quay lại nhiều không': {BoomModule.khach},
          'voucher nào hiệu quả nhất': {BoomModule.khuyenMai},
          'thang nay chi phi gi nhieu nhat': {BoomModule.finance},
          'tháng này tôi chi những gì': {BoomModule.finance},
          'sữa còn bao nhiêu hộp': {BoomModule.kho},
          'nhân viên A làm mấy giờ tuần này': {BoomModule.nhanSu},
        };
        cases.forEach(
          (q, want) => expect(boomModuleTopics(q), want, reason: q),
        );
        for (final q in [
          'cách thêm khoản chi',
          'tạo mã giảm giá ở đâu',
          'xuất bảng lương ra excel',
          'lương tối thiểu vùng là bao nhiêu',
          'thêm nhân viên mới',
          'sửa phiếu nhập hàng bị sai',
          'món nào bán chạy nhất',
          // QC 25/10: câu chung / cách làm bị nhận nhầm
          'lãi suất ngân hàng hiện nay bao nhiêu',
          'cà phê muối cần nguyên liệu gì',
          'gói của tôi còn bao nhiêu ngày hết hạn',
          'giảm giá món thế nào',
          'quán cà phê nên giảm giá bao nhiêu thì hợp lý',
          'có lời khuyên gì không',
          'tồn tại lỗi gì không',
          'lương nhân viên phục vụ thường bao nhiêu',
          'nên trả lương nhân viên bao nhiêu',
          'chi nhánh 2 chi phí bao nhiêu',
          'thêm giúp tôi khoản chi tiền điện 2 triệu',
        ]) {
          expect(boomModuleTopics(q), isEmpty, reason: q);
        }
      },
    );

    test(
      'Quyền xem như app: nhân viên thường không xem thu chi, chỉ xem giờ làm của mình; module tắt thì không đọc',
      () {
        BoomPerms p({
          bool owner = false,
          String role = 'waiter',
          List<String> mods = const [],
          Set<String> active = kBoomDefaultActiveModules,
        }) => BoomPerms(
          isOwner: owner,
          canonicalRole: role,
          modules: mods,
          active: {...active, 'chamcong', 'loyalty'},
        );
        expect(boomModuleAccess(BoomModule.finance, p()), isNull);
        expect(boomModuleAccess(BoomModule.finance, p(owner: true)), 'all');
        expect(
          boomModuleAccess(
            BoomModule.finance,
            p(role: 'manager', mods: ['finance']),
          ),
          'all',
        );
        expect(
          boomModuleAccess(
            BoomModule.finance,
            BoomPerms(
              isOwner: true,
              canonicalRole: 'owner',
              modules: const [],
              active: {'pos'},
            ),
          ),
          isNull,
        );
        expect(
          boomModuleAccess(BoomModule.nhanSu, p(mods: ['chamcong'])),
          'self',
        );
        expect(boomModuleAccess(BoomModule.nhanSu, p(role: 'manager')), 'all');
        expect(
          boomModuleAccess(BoomModule.kho, p(role: 'cashier', mods: ['kho'])),
          'no_cost',
        );
        expect(boomModuleAccess(BoomModule.khach, p(mods: ['pos'])), isNull);
        expect(
          boomModuleAccess(
            BoomModule.khuyenMai,
            p(role: 'cashier', mods: ['report']),
          ),
          'all',
        );
        // QC: được giao module A nhưng A tắt, B bật nhưng không được giao → không xem
        expect(
          boomModuleAccess(
            BoomModule.khuyenMai,
            const BoomPerms(
              isOwner: false,
              canonicalRole: 'waiter',
              modules: ['pos', 'loyalty'],
              active: {'pos', 'report'},
            ),
          ),
          isNull,
        );
        expect(boomCanSeeSales(p()), isFalse);
        expect(boomCanSeeSales(p(role: 'cashier', mods: ['report'])), isTrue);
        expect(boomCanSeeStock(p(role: 'stock', mods: ['kho'])), isTrue);
        expect(boomCanSeeShifts(p(mods: ['chamcong'])), isFalse);
      },
    );

    test(
      'Nhân viên không có quyền Báo cáo hỏi doanh thu → không trả số; không đọc được quyền → chặn',
      () async {
        for (final perms in [
          const BoomPerms(
            isOwner: false,
            canonicalRole: 'waiter',
            modules: ['pos'],
            active: {'pos', 'report'},
          ),
          null,
        ]) {
          testPerms = perms;
          final m = await ask('doanh thu hôm nay bao nhiêu');
          expect(m.content, contains('chưa được mở mục này'), reason: '$perms');
          expect(m.content, isNot(contains('đ từ')));
        }
      },
    );

    test(
      'Có quyền → GPT nhận số module; nói tiếp đọc lại; không quyền → nói rõ, không gọi GPT',
      () async {
        ai.adviceNext = const BoomAiReply(
          'Chi nhiều nhất là nguyên liệu…',
          'log-md',
        );
        const q = 'tháng này chi phí gì nhiều nhất';
        final m = await ask(q);
        expect(ai.moduleFacts.single, containsPair('finance', isA<Map>()));
        expect(m.evidenceReference?['tool_name'], 'boom_tu_van_so_lieu_module');
        await ask('chi tiết hơn đi');
        expect(loaderCalls.last, contains(q));
        expect(ai.moduleFacts.last, isNotNull);
        final before = ai.advised.length;
        deniedModules.add(BoomModule.nhanSu);
        final d = await ask('nhân viên nào làm nhiều giờ nhất tháng này');
        expect(ai.advised.length, before);
        expect(d.content, contains('Chấm công / Lương'));
        expect(d.content, contains('chưa được mở mục này'));
      },
    );
  });

  group('Số liệu các module — cách tính (25/10)', () {
    test('Thu chi: tổng thu / chi, khoản chi lớn nhất, kỳ trước', () {
      final f = boomFinanceFacts(
        rows: [
          {
            'type': 'income',
            'amount': 1000000,
            'category_id': 'c1',
            'is_auto': true,
          },
          {
            'type': 'expense',
            'amount': 300000,
            'category_id': 'c2',
            'fund_type': 'bank',
          },
          {'type': 'expense', 'amount': 200000, 'category_id': null},
        ],
        prevRows: [
          {'type': 'income', 'amount': 800000},
          {'type': 'expense', 'amount': 100000},
        ],
        categories: [
          {'id': 'c1', 'name': 'Bán hàng'},
          {'id': 'c2', 'name': 'Nguyên liệu'},
        ],
        period: 'Tháng này',
        prevPeriod: 'tháng trước',
      );
      expect(f['income'], 1000000);
      expect(f['expense'], 500000);
      expect(f['auto_income'], 1000000);
      expect((f['top_expense'] as List).first, {
        'name': 'Nguyên liệu',
        'amount': 300000.0,
        'prev': 0.0,
      });
      expect(f['expense_bank'], 300000);
      expect(f['prev_expense'], 100000);
    });

    test('Kho: sắp hết, giá trị tồn, hao hụt; nhân viên không xem giá vốn', () {
      final products = [
        {
          'id': 'a',
          'name': 'Sữa',
          'unit': 'hộp',
          'stock_qty': 2,
          'min_stock': 5,
          'cost_price': 30000,
        },
        {
          'id': 'b',
          'name': 'Đường',
          'unit': 'kg',
          'stock_qty': 0,
          'min_stock': 1,
          'cost_price': 20000,
        },
        {
          'id': 'c',
          'name': 'Combo',
          'product_type': 'combo',
          'stock_qty': 0,
          'min_stock': 9,
        },
        {
          'id': 'd',
          'name': 'Cà phê',
          'unit': 'kg',
          'stock_qty': 10,
          'min_stock': 2,
          'cost_price_latest': 200000,
        },
      ];
      final k = boomKhoFacts(
        products: products,
        purchases: [
          {
            'supplier_name': 'NCC A',
            'status': 'received',
            'total_cost': 500000,
          },
          {
            'supplier_name': 'NCC B',
            'status': 'cancelled',
            'total_cost': 900000,
          },
        ],
        waste: [
          {'product_id': 'a', 'delta': -1, 'reason': 'expired'},
        ],
        period: 'Tháng này',
        withCost: true,
      );
      expect(k['low_count'], 2);
      expect(k['out_count'], 1);
      expect((k['low'] as List).first['name'], 'Đường');
      expect(k['stock_value'], 2 * 30000 + 10 * 200000);
      expect(k['imports'], 1);
      expect(k['import_total'], 500000);
      expect((k['losses'] as List).single, containsPair('value', 30000.0));
      final staff = boomKhoFacts(
        products: products,
        purchases: const [],
        waste: const [],
        period: 'p',
        withCost: false,
      );
      expect(staff.containsKey('stock_value'), isFalse);
      expect(staff.containsKey('import_total'), isFalse);
    });

    test('Chấm công: giờ theo người, ca quên chấm ra không cộng giờ', () {
      final now = DateTime.utc(2026, 10, 25, 12);
      final n = boomNhanSuFacts(
        shifts: [
          {
            'user_id': 'u1',
            'clock_in': '2026-10-24T01:00:00Z',
            'clock_out': '2026-10-24T09:30:00Z',
          },
          {
            'user_id': 'u1',
            'clock_in': '2026-10-20T01:00:00Z',
            'clock_out': null,
          },
          {
            'user_id': 'u2',
            'clock_in': '2026-10-25T08:00:00Z',
            'clock_out': null,
          },
        ],
        users: [
          {'id': 'u1', 'name': 'Lan'},
        ],
        payroll: const [],
        period: 'Tháng này',
        now: now,
        self: false,
      );
      expect(n['total_hours'], 8.5);
      expect(n['forgot_clock_out'], 1);
      expect(n['open_now'], 1);
      expect((n['staff'] as List).first, {
        'name': 'Lan',
        'shifts': 2,
        'hours': 8.5,
      });
    });

    test('Khuyến mãi: mã đang chạy, mã đã dùng, tỷ lệ giảm giá', () {
      final p = boomKhuyenMaiFacts(
        coupons: [
          {
            'code': 'GIAM10',
            'discount_type': 'percent',
            'value': 10,
            'is_active': true,
            'end_date': '2026-12-31T00:00:00Z',
          },
          {
            'code': 'CU',
            'discount_type': 'fixed',
            'value': 5000,
            'is_active': true,
            'end_date': '2026-01-01T00:00:00Z',
          },
        ],
        redemptions: [
          {'coupon_code': 'giam10', 'discount_amount': 5000},
          {'coupon_code': 'GIAM10', 'discount_amount': 7000},
        ],
        orders: [
          {'discount': 12000, 'total_amount': 108000},
          {'discount': 0, 'total_amount': 50000},
        ],
        period: 'Tháng này',
        now: DateTime.utc(2026, 10, 25),
      );
      expect(p['active_count'], 1);
      expect((p['used'] as List).single, {
        'code': 'GIAM10',
        'times': 2,
        'discount': 12000.0,
      });
      expect(p['orders_with_discount'], 1);
      expect(p['discount_total'], 12000);
    });
  });

  group('Quyền đọc chặt + đường thật (QC vòng 2, 25/10)', () {
    test(
      'Quyết định quyền giống app: vai trò rỗng → gán riêng → cài đặt cũ → mặc định',
      () {
        const member = {'role': 'Thu ngân ca tối', 'is_owner': false};
        // vai trò lưu [] + gán riêng chỉ POS → chỉ POS (không lấy mặc định của thu ngân)
        var p = resolveBoomPerms(
          member: member,
          settings: const [],
          roles: const [
            {'name': 'Thu ngân ca tối', 'modules': '[]'},
          ],
          staff: const {
            'modules': ['pos'],
          },
        );
        expect(p.modules, ['pos']);
        expect(boomCanSeeSales(p), isFalse);
        // không có gì → mặc định thu ngân
        p = resolveBoomPerms(
          member: member,
          settings: const [],
          roles: const [],
          staff: null,
        );
        expect(p.modules, contains('report'));
        // cài đặt cũ dạng chữ không ngoặc kép
        p = resolveBoomPerms(
          member: member,
          settings: const [
            {'key': 'perm_cashier', 'value': '[ban,kitchen]'},
          ],
          roles: const [],
          staff: null,
        );
        expect(p.modules, ['ban', 'kitchen']);
        // vai trò của quán có danh sách → dùng, khớp đúng tên trước
        p = resolveBoomPerms(
          member: member,
          settings: const [
            {'key': 'module_config_v2', 'value': '["pos","finance"]'},
          ],
          roles: const [
            {
              'name': 'Thu ngân',
              'modules': ['pos', 'report'],
            },
            {
              'name': 'Thu ngân ca tối',
              'modules': ['pos', 'finance'],
            },
          ],
          staff: null,
        );
        expect(p.modules, ['pos', 'finance']);
        expect(p.active, {'pos', 'finance'});
        expect(boomModuleAccess(BoomModule.finance, p), 'all');
        expect(
          () => resolveBoomPerms(
            member: null,
            settings: const [],
            roles: const [],
            staff: null,
          ),
          throwsStateError,
        );
        expect(
          resolveBoomPerms(
            member: const {'role': 'x', 'is_owner': true},
            settings: const [],
            roles: const [],
            staff: null,
          ).boss,
          isTrue,
        );
      },
    );

    test(
      'Đường thật (không thay bộ đọc module): nhân viên không quyền Thu Chi → nói rõ; thu ngân có quyền Báo cáo không bị chặn',
      () async {
        final c2 = ProviderContainer(
          overrides: [
            boomHelpIndexProvider.overrideWith((ref) async => _index()),
            boomAiServiceProvider.overrideWithValue(ai),
            boomPermsLoaderProvider.overrideWithValue(
              (store) async => const BoomPerms(
                isOwner: false,
                canonicalRole: 'cashier',
                modules: ['pos', 'report'],
                active: {'pos', 'report', 'finance'},
              ),
            ),
          ],
        );
        addTearDown(c2.dispose);
        c2
            .read(sessionProvider.notifier)
            .setSession(
              const SessionData(
                userId: 'u2',
                phone: '0',
                displayName: 'TN',
                storeId: 's1',
                storeName: 'Quan',
                storeCode: 'Q1',
                role: 'cashier',
                isOwner: false,
              ),
            );
        Future<BoomMessage> ask2(String q) async {
          await c2.read(boomChatProvider.notifier).sendMessage(q);
          return c2.read(boomChatProvider).last;
        }

        final f = await ask2('tháng này chi phí gì nhiều nhất');
        expect(f.content, contains('Thu Chi'));
        expect(f.content, contains('chưa được mở mục này'));
        final r = await ask2('doanh thu hôm nay bao nhiêu');
        expect(r.content, isNot(contains('chưa được mở mục này')));
      },
    );

    test('Câu chung còn sót ở vòng 2 → không đọc số module', () {
      for (final q in [
        'tiền thuê mặt bằng ở quận 1 bao nhiêu',
        'tiền mặt nên giữ bao nhiêu trong két',
        'tiền nước tháng này bao nhiêu là hợp lý',
        'trong kho nên để nhiệt độ bao nhiêu',
        'nhập hàng ở chợ nào rẻ nhất',
        'nhà cung cấp nào uy tín nhất ở sài gòn',
        'khách nào hay bom hàng nhất thì xử lý sao',
        'khách hàng nào cũng thích khuyến mãi phải không',
      ]) {
        expect(boomModuleTopics(q), isEmpty, reason: q);
      }
      expect(boomAsksHowTo('hết hàng thì báo khách thế nào'), isTrue);
      // QC vòng 3: cách hỏi tự nhiên còn sót
      expect(boomModuleTopics('kho còn bao nhiêu sữa'), {BoomModule.kho});
      expect(boomModuleTopics('tháng này lương bao nhiêu'), {
        BoomModule.nhanSu,
      });
      expect(boomModuleTopics('thang nay luong bao nhieu'), {
        BoomModule.nhanSu,
      });
      expect(boomModuleTopics('hôm nay ai đi làm'), {BoomModule.nhanSu});
      // vai trò trống → không quyền (không khớp nhầm vai trò tên trống)
      expect(
        () => resolveBoomPerms(
          member: const {'role': null, 'is_owner': false},
          settings: const [],
          roles: const [
            {
              'name': '',
              'modules': ['finance'],
            },
          ],
          staff: null,
        ),
        throwsStateError,
      );
    });
  });

  test(
    'Lịch sử cho trang quản trị: câu app tự trả gửi nguyên văn; câu GPT không gửi trùng (máy chủ tự ghi)',
    () async {
      await ask('huỷ món đã gửi bếp thế nào'); // GPT trả lời qua máy chủ
      expect(ai.transcripts, isEmpty);
      ai.next = null; // GPT lỗi → app hiện nguyên văn bài hướng dẫn
      await ask('huỷ món đã gửi bếp thế nào');
      expect(ai.transcripts.single, startsWith('huong_dan|'));
      await ask('chào Boom');
      expect(ai.transcripts.length, 2);
    },
  );
}
