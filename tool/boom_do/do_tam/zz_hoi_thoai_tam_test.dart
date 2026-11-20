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
import 'package:quannho_pos/features/ai_assistant/services/boom_read_only_data_service.dart';
import 'package:quannho_pos/features/ai_assistant/classifier/intent_classifier.dart';
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


// Số nhanh giả: ghi lại kỳ được đọc
String kyOf(BoomPeriodRange r) => '${r.start.toIso8601String().substring(0, 10)}→${r.end.toIso8601String().substring(0, 10)}';

class FakeData extends BoomReadOnlyDataService {
  FakeData() : super(SupabaseClient('http://127.0.0.1:9', 'test-key'));
  final labels = <String>[];
  @override
  Future<BoomRevenueSummary> getRevenueSummary(String storeId, BoomPeriod period, {DateTime? now, BoomPeriodRange? range}) async {
    final r = range ?? boomPeriodRange(period, now ?? DateTime.now());
    labels.add(kyOf(r));
    return BoomRevenueSummary(range: r, revenue: 1000000, orderCount: 10, previousRevenue: 900000, previousOrderCount: 9);
  }
  @override
  Future<BoomProductPerformance> getProductPerformance(String storeId, {int limit = 3, BoomPeriod period = BoomPeriod.today, DateTime? now, BoomPeriodRange? range}) async {
    labels.add(kyOf(range ?? boomPeriodRange(period, now ?? DateTime.now())));
    const m = BoomProductMetric(name: 'Trà đào', quantity: 5, revenue: 150000, price: 30000);
    return const BoomProductPerformance(top: [m], slow: [m], all: [m], completedOrderCount: 10);
  }
  @override
  Future<List<BoomStockAlert>> getLowStock(String storeId) async { labels.add('kho'); return const []; }
  @override
  Future<BoomShiftSummary> getStaffOnShift(String storeId) async { labels.add('ca'); return const BoomShiftSummary(count: 1, names: ['An']); }
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
  late FakeData data;
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
    data = FakeData();
    final index = _index();
    c = ProviderContainer(
      overrides: [
        boomHelpIndexProvider.overrideWith((ref) async => index),
        boomAiServiceProvider.overrideWithValue(ai),
        boomReadOnlyDataProvider.overrideWithValue(data),
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

  test('ĐO HỘI THOẠI 2 LƯỢT (tạm, không commit)', () async {
    final f = Platform.environment['BO_CAU']!;
    final out = File(Platform.environment['KET_QUA']!).openWrite();
    final cases = (jsonDecode(File(f).readAsStringSync()) as Map)['cases'] as List;
    testPerms = ownerPerms;
    c.read(sessionProvider.notifier).setSession(const SessionData(userId: 'u1', phone: '0', displayName: 'Chủ', storeId: 's1', storeName: 'Quận 1', storeCode: 'Q1', role: 'owner', isOwner: true));
    Map<String, dynamic> store(String id, String name, int orders, int rev) => {'store_id': id, 'name': name, 'store_code': id, 'orders': orders, 'revenue': rev, 'discount': 0};
    ChainRepository.rpcOverride = (fn, params) async {
      if (fn == 'list_my_chains_v1') {
        return {'success': true, 'chains': [{'id': 'c1', 'name': 'Chuỗi', 'stores': [{'store_id': 's1', 'name': 'Quận 1'}, {'store_id': 's2', 'name': 'Thủ Đức'}]}], 'owned_stores': []};
      }
      return {'success': true, 'chain': {'id': 'c1', 'name': 'Chuỗi'}, 'stores': [store('s1', 'Quận 1', 120, 9000000), store('s2', 'Thủ Đức', 60, 4200000)], 'totals': {}, 'daily': [], 'excluded_stores': []};
    };
    ai.adviceNext = const BoomAiReply('Tư vấn giả.', 'log-tv');
    for (final cs in cases) {
      c.read(boomChatProvider.notifier).clearChat();
      final q1 = cs['q1'] as String, q = cs['q2'] as String;
      final b0 = ai.asked.length, e0 = ai.advised.length, m0 = loaderCalls.length, g0 = data.labels.length;
      final m1 = await ask(q1);
      final duong1 = ai.asked.length > b0 ? 'huong_dan' : loaderCalls.length > m0 ? 'so_lieu_muc' : ai.advised.length > e0 ? 'tu_van(${m1.evidenceReference?['tool_name']})' : data.labels.length > g0 ? 'so_lieu_nhanh' : 'khac(${m1.evidenceReference?['tool_name']})';
      final a0 = ai.asked.length, d0 = ai.advised.length, l0 = loaderCalls.length, h0 = ai.histories.length, f0 = data.labels.length;
      final ch0 = ai.chains.length;
      String tool = '', duong, traLoi = '';
      try {
        final m = await ask(q);
        tool = '${m.evidenceReference?['tool_name'] ?? ''}';
        traLoi = m.content;
      } catch (e) {
        tool = 'LỖI GIẢ LẬP: $e';
      }
      {
        if (ai.asked.length > a0) {
          duong = 'huong_dan';
        } else if (loaderCalls.length > l0) {
          duong = 'so_lieu_muc';
        } else if (ai.advised.length > d0) {
          duong = ai.chains.last != null ? 'chuoi' : (tool == 'boom_tu_van_so_lieu' || tool == 'boom_so_lieu_du_phong' ? 'tu_van_so_lieu' : 'tu_van');
        } else if (data.labels.length > f0) {
          duong = 'so_lieu_nhanh';
        } else {
          duong = 'khac';
        }
        final hist = ai.histories.length > h0 ? ai.histories.last : null;
        final lq = loaderCalls.length > l0 ? loaderCalls.last : null;
        String? ky;
        if (data.labels.length > f0) {
          ky = data.labels.last;
        } else if (lq != null) {
          final tr = IntentClassifier.timeRangeIn(lq);
          ky = kyOf(boomRangeOf(tr != null && tr != 'unsupported' ? tr : 'this_month', DateTime.now()));
        }
        out.writeln(jsonEncode({'q1': q1, 'duong1': duong1, 'q': q, 'loai': cs['loai'], 'noi_tiep': cs['noi_tiep'], 'ky_dung': cs['ky'], 'expect': cs['expect'], 'duong': duong, 'tool': tool, 'lich_su': hist, 'loader': lq, 'ky': ky, 'doan': ai.asked.length > a0 ? ai.asked.last : null, 'ky_dung_nhan': cs['ky'] == null ? null : kyOf(boomRangeOf(cs['ky'] as String, DateTime.now())), 'tra_loi': traLoi.length > 80 ? traLoi.substring(0, 80) : traLoi}));
      }
      if (ch0 < 0) print(ch0);
    }
    await out.close();
  }, timeout: const Timeout(Duration(minutes: 20)));
}
