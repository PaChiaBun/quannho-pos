// lib/features/ai_assistant/providers/boom_chat_provider.dart
// ─────────────────────────────────────────────────────────────────────────────
// Boom Chat Provider — Truy vấn dữ liệu thực tế từ Supabase cho Quán Kay
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/repositories/chain_repository.dart';
import '../boom_xung_ho.dart';
import '../classifier/intent_classifier.dart';
import '../help/boom_help_repository.dart';
import '../help/help_search.dart';
import '../help/huong_dan_parser.dart' show HelpChunk;
import '../models/boom_message.dart';
import '../services/boom_ai_service.dart';
import '../services/boom_module_data_service.dart';
import '../services/boom_read_only_data_service.dart';
import '../services/boom_telemetry_service.dart';

/// Các loại câu hỏi số liệu Boom trả bằng dữ liệu thật của quán.
const kBoomDataIntents = {
  'revenue_summary',
  'sales_comparison',
  'top_products',
  'slow_products',
  'low_stock',
  'purchase_forecast',
  'staff_on_shift',
};

/// Trả lời "kho sắp hết" / "cần nhập thêm gì". Dự báo mua hàng = bù về mức tồn tối thiểu, chưa tính lượng bán
/// sắp tới (shortcut: chưa dùng RPC get_stock_forecast_inputs — nối khi có số bán theo nguyên liệu).
String boomStockReply(
  List<BoomStockAlert> alerts, {
  required bool forecast,
  required String Function(num) qty,
}) {
  if (alerts.isEmpty) {
    return 'Dữ liệu kho hiện không có mặt hàng nào chạm hoặc thấp hơn mức tồn tối thiểu.';
  }
  final details = alerts
      .take(5)
      .map((item) {
        final base =
            '${item.name}: còn ${qty(item.stockQuantity)}, tối thiểu ${qty(item.minimumStock)}';
        if (!forecast) return base;
        final need = item.minimumStock - item.stockQuantity;
        return need > 0
            ? '$base → nhập thêm ít nhất ${qty(need)}'
            : '$base → đang chạm mức tối thiểu';
      })
      .join('; ');
  return forecast
      ? 'Theo mức tồn tối thiểu, có ${alerts.length} mặt hàng nên nhập: $details. Đây là lượng bù về mức tối thiểu, '
            'chưa tính lượng bán sắp tới; Bé Boom không tự tạo phiếu nhập.'
      : 'Có ${alerts.length} mặt hàng cần chú ý: $details. Gợi ý: kiểm tra thực tế và lập kế hoạch nhập hàng; Bé Boom không tự tạo phiếu nhập.';
}

/// Trả lời bằng hướng dẫn thay vì số liệu? Câu số liệu (doanh thu, bán chạy…) vẫn trả số liệu; chỉ
/// nhường cho hướng dẫn khi bộ đoán ý không chắc, hoặc câu có động từ thao tác ("tắt bán món hết",
/// "thêm nhân viên", "in báo cáo…"), hoặc người dùng bấm nút gợi ý hướng dẫn.
bool boomHelpWins({
  required ClassificationResult classification,
  required HelpResult? help,
  required String query,
  bool picked = false,
}) =>
    help?.decision == HelpDecision.answer &&
    (picked ||
        !kBoomDataIntents.contains(classification.intent) ||
        classification.confidence < IntentClassifier.kHighConfidenceThreshold ||
        _helpAction(query) ||
        boomAsksHowTo(query));

/// Câu bị đoán là số liệu nhưng có động từ thao tác ("thêm nhân viên mới", "duyệt OT…") và bộ hướng
/// dẫn có gợi ý → hiện gợi ý hướng dẫn thay vì danh sách số liệu.
bool boomHelpSuggestInstead({
  required ClassificationResult classification,
  required HelpResult? help,
  required String query,
}) =>
    help != null &&
    (help.decision == HelpDecision.suggest ||
        // Bộ tìm không quyết nhưng đoạn đầu điểm cao ("đếm két so với app coi chỗ nào cho đúng tiền mặt").
        (help.decision == HelpDecision.none &&
            help.hits.isNotEmpty &&
            help.hits.first.score >= kHelpStrongScore)) &&
    kBoomDataIntents.contains(classification.intent) &&
    _helpAction(query);

/// Luật của Boom: không nêu số liệu của quán khác / đối thủ / thương hiệu khác (cùng quy tắc với hàm máy chủ
/// boom-chat, logic.ts). Kiểm ngay trên máy: câu "doanh thu quán đối thủ" bị bộ đoán ý xếp vào câu số liệu
/// → nếu không chặn, Boom sẽ trả nhầm số của chính quán mình.
const kBoomOtherStoreRefusal =
    'Bé Boom không có và không chia sẻ số liệu của quán khác ạ. Bé Boom chỉ giúp xem số liệu của chính quán mình (Báo cáo, Thu Chi) thôi ạ.';

/// Cách xưng hô (Chủ Quán chốt 24/10): Boom tự xưng "Bé Boom" với mọi người; gọi người dùng "Anh" / "Chị" + tên theo
/// lựa chọn của chính họ (hỏi một lần, lưu theo tài khoản — app không có giới tính, không đoán theo tên).
const kBoomGoiAnh = 'Gọi tôi là Anh';
const kBoomGoiChi = 'Gọi tôi là Chị';

/// "Anh An" / "Chị An" / "Anh/Chị An" — tiếng cuối của tên hiển thị (cùng quy tắc với hàm máy chủ boom-chat).
String boomGoiNguoiDung(String? xungHo, String? displayName) {
  // bỏ phần trong ngoặc ("Lan (thu ngân)"); giữ dấu tổ hợp (tên gõ kiểu Unikey tổ hợp)
  final words = (displayName ?? '')
      .replaceAll(RegExp(r'\([^)]*\)'), ' ')
      .replaceAll(RegExp(r'[^\p{L}\p{M}\s]', unicode: true), ' ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  var ten = words.isEmpty ? '' : words.last;
  if (ten.length > 15) ten = ten.substring(0, 15);
  if (ten.isNotEmpty) {
    // Cả tên viết HOA ("NGUYỄN VĂN AN" → "An") mới viết lại; tên tắt ngắn ("NV") giữ nguyên
    final full = words.join();
    final allCaps =
        full.length >= 3 &&
        full == full.toUpperCase() &&
        full != full.toLowerCase();
    ten =
        ten[0].toUpperCase() +
        (allCaps ? ten.substring(1).toLowerCase() : ten.substring(1));
  }
  final danh = kBoomDanhXung[xungHo] ?? 'Anh/Chị';
  return ten.isEmpty ? danh : '$danh $ten';
}

const _rival =
    r'(?:đối thủ|quán khác|quán đối diện|quán bên cạnh|quán gần đây|chuỗi khác|chi nhánh khác|cửa hàng khác|thương hiệu khác|highlands|phúc long|starbucks|'
    r'katinat|the coffee house|trung nguyên|cộng cà phê|phê la|gong cha|tocotoco|mixue)';
const _metric =
    r'(?:doanh thu|doanh số|số liệu|bán được|lợi nhuận|lãi|thu nhập|số đơn|số khách|bán chạy)';
final _otherStore = RegExp(
  ' $_rival(?: \\S+){0,3} $_metric | $_metric(?: \\S+){0,3} $_rival ',
);

// Chỉ chặn câu HỎI SỐ, không nói về quán mình / so sánh, không xin tư vấn ("Highlands bán được nhiều nhờ đâu,
// quán nhỏ học được gì" → cho qua).
final _asksNumber = RegExp(
  r' (?:bao nhiêu|mấy|khoảng|là bao|không|thế nào|ra sao|món gì|gì) ',
);
final _ownOrAdvice = RegExp(
  r' (?:hơn|vượt|so với|(?:quán|của|bên) (?:mình|tôi|tui|tớ|em|chúng tôi)|nhờ đâu|vì sao|tại sao|học|áp dụng|nên|làm sao|làm gì|cách nào|ảnh hưởng|cạnh tranh) ',
);

// Ghép dấu tách rời về chữ có dấu liền — như NFC phía máy chủ: NFD ("o" + ̂ + ́) và Unikey "Unicode tổ hợp"
// ("ô" + dấu thanh tách rời).
const _viBase = 'aăâeêioôơuưy';
const _viTones = [
  'àáãảạ', 'ằắẵẳặ', 'ầấẫẩậ', 'èéẽẻẹ', 'ềếễểệ', 'ìíĩỉị', //
  'òóõỏọ', 'ồốỗổộ', 'ờớỡởợ', 'ùúũủụ', 'ừứữửự', 'ỳýỹỷỵ',
];
const _viToneMarks = '\u0300\u0301\u0303\u0309\u0323';
final _viDecomposed = RegExp('([aăâeêioôơuưy])([\u0300-\u036f]+)');

String boomComposeVi(String lower) =>
    lower.replaceAllMapped(_viDecomposed, (m) {
      var base = m[1]!;
      final marks = m[2]!;
      if (marks.contains('\u0302')) {
        base = const {'a': 'â', 'e': 'ê', 'o': 'ô'}[base] ?? base;
      } else if (marks.contains('\u0306')) {
        base = base == 'a' ? 'ă' : base;
      } else if (marks.contains('\u031b')) {
        base = const {'o': 'ơ', 'u': 'ư'}[base] ?? base;
      }
      var out = base;
      for (final ch in marks.split('')) {
        final t = _viToneMarks.indexOf(ch);
        if (t >= 0) out = _viTones[_viBase.indexOf(base)][t];
      }
      return out;
    });

// Câu xin tư vấn / hỏi cách xử lý ("nên đặt giá bán ra sao", "nhân viên đánh bài xử lý sao", "Highlands bán chạy
// nhờ đâu", "mẹo bán hàng") hoặc nhắc tên đối thủ → không trả số liệu của quán (Boom tư vấn) — kiểm tra 24/10.
// + câu hỏi cách làm / báo lỗi ("gom lại xem tổng doanh thu chung thì làm thế nào", "sao tồn kho bị âm", "nó báo
// "đã hết hàng" là sao", "muốn coi lại mấy đơn") → hướng dẫn, không phải số liệu (kiểm tra 128 câu theo module 24/10).
final _wantsAdvice = RegExp(
  r'(?:^| )(?:mẹo|gợi ý|nên|xử lý|nhờ đâu|học được|tại sao|vì sao|làm sao để|cách nào để|bí quyết|làm thế nào|làm sao|'
  r'thế nào để|là sao|sao vậy|sao lại|bị âm|không thấy|không giảm|nó báo|báo lỗi|coi lại|xem lại|gom|ở đâu|app có|'
  r'quán nào|cửa hàng nào|chi nhánh nào|dự báo|cách|'
  // câu "được không / tự … / bấm …" là hỏi chức năng (bộ 160 câu thường gặp 24/10)
  r'được ko|được không|dc ko|đc ko|được hok|đc hok|tự gửi|tự động|bấm|tạm ko bán|tạm không bán|khỏi bán|'
  r'so doanh thu|nhảy qua|ra bill|báo hết)(?: |$)',
);

bool boomWantsAdvice(String query) {
  final t = boomComposeVi(
    query.toLowerCase(),
  ).replaceAll(RegExp(r'[^\p{L}\p{N}+]+', unicode: true), ' ');
  final s = ' ${t.trim()} ';
  // Câu trích nguyên văn thông báo của app ("…") là hỏi lỗi
  return _wantsAdvice.hasMatch(s) ||
      RegExp(' $_rival ').hasMatch(s) ||
      RegExp(r'["“”]').hasMatch(query);
}

// Teencode / viết tắt tin nhắn → chữ đầy đủ (đợt 13): (có dấu, không dấu). Câu gõ không dấu dùng bản không dấu để
// các luật bản không dấu vẫn khớp. Chỉ thay NGUYÊN TỪ.
const _kTeen = <String, (String, String)>{
  'ko': ('không', 'khong'),
  'hok': ('không', 'khong'),
  'khum': ('không', 'khong'),
  'hông': ('không', 'khong'),
  'đc': ('được', 'duoc'),
  'dc': ('được', 'duoc'),
  'bnhiu': ('bao nhiêu', 'bao nhieu'),
  'bnhieu': ('bao nhiêu', 'bao nhieu'),
  'nhiu': ('nhiêu', 'nhieu'),
  'trc': ('trước', 'truoc'),
  'hnay': ('hôm nay', 'hom nay'),
  'hqua': ('hôm qua', 'hom qua'),
  'lm': ('làm', 'lam'),
  'ntn': ('như thế nào', 'nhu the nao'),
  'mún': ('muốn', 'muon'),
  'bít': ('biết', 'biet'),
  'cx': ('cũng', 'cung'),
  'vs': ('với', 'voi'),
  'ng': ('người', 'nguoi'),
  'sp': ('sản phẩm', 'san pham'),
  'tk': ('tài khoản', 'tai khoan'),
  'đt': ('điện thoại', 'dien thoai'),
};
final _teenWord = RegExp(
  '(?<![\\p{L}\\p{N}])(${_kTeen.keys.join('|')})(?![\\p{L}\\p{N}])',
  unicode: true,
  caseSensitive: false,
);
// "bn" = "bao nhiêu" trừ khi gọi "bạn" ("bn ơi", đầu câu); "hum nay / hum qua"; "lm s" / "vì s" = sao; "v" cuối câu = vậy
final _teenPhrase = <(RegExp, String, String)>[
  // chữ một ký tự: chỉ chữ thường ("size R", "Bàn K" giữ nguyên) — QC đợt 13
  // "k" = không, trừ "25 k", "mấy trăm k" (nghìn), "vitamin k"
  (
    RegExp(
      r'(?<![\p{L}\p{N}])(?<!\d |(?:trăm|tram|chục|chuc|vài|vai|mấy|may|vitamin) )k(?![\p{L}\p{N}])',
      unicode: true,
    ),
    'không',
    'khong',
  ),
  (RegExp(r'(?<![\p{L}\p{N}])j(?![\p{L}\p{N}])', unicode: true), 'gì', 'gi'),
  // "dt hnay cn 1" — "cn" kèm số là chi nhánh (lần 8, giai đoạn 1)
  (
    RegExp(r'(?<![\p{L}\p{N}])cn(?= \d)(?! \d+/)', unicode: true),
    'chi nhánh',
    'chi nhanh',
  ),
  (RegExp(r'(?<![\p{L}\p{N}])z(?![\p{L}\p{N}])', unicode: true), 'vậy', 'vay'),
  (RegExp(r'(?<![\p{L}\p{N}])r(?![\p{L}\p{N}])', unicode: true), 'rồi', 'roi'),
  // "wa" sau chữ chỉ thời gian = qua ("hôm wa"), còn lại = quá ("vắng wa")
  (
    RegExp(
      r'(?<=(?:hôm|hom|hum|tuần|tuan|tháng|thang|năm|nam|bữa|bua|tối|toi|đêm|dem|ngày|ngay) )wa(?![\p{L}\p{N}])',
      unicode: true,
      caseSensitive: false,
    ),
    'qua',
    'qua',
  ),
  (
    RegExp(
      r'(?<![\p{L}\p{N}])wa(?![\p{L}\p{N}])',
      unicode: true,
      caseSensitive: false,
    ),
    'quá',
    'qua',
  ),
  // "ck" = chuyển khoản, trừ chiết khấu ("ck 10%", "giảm ck")
  (
    RegExp(
      r'(?<![\p{L}\p{N}])(?<!giảm |giam )ck(?![\p{L}\p{N}])(?! ?\d+ ?%)',
      unicode: true,
      caseSensitive: false,
    ),
    'chuyển khoản',
    'chuyen khoan',
  ),
  (
    RegExp(
      r'(?<=\S )(?<!(?:cho|nhờ|nho|hỏi|hoi|ơn|on|giúp|giup|chào|chao|với|voi) )bn'
      r'(?![\p{L}\p{N}]| ơi| oi| (?:là|la|có|co|hỏi|hoi|giúp|giup|biết|biet|tên|ten|ạ|nha|nhé|nhe)\b)',
      unicode: true,
      caseSensitive: false,
    ),
    'bao nhiêu',
    'bao nhieu',
  ),
  (RegExp(r'\bhum (?=nay|qua)', caseSensitive: false), 'hôm ', 'hom '),
  (
    RegExp(
      r'(?<=\b(?:lm|làm|lam|vì|vi|tại|tai|bị|bi|thì|thi) )s(?![\p{L}\p{N}])',
      unicode: true,
      caseSensitive: false,
    ),
    'sao',
    'sao',
  ),
  (RegExp(r'(?<=\S )v(?=[\s?!.]*$)', caseSensitive: false), 'vậy', 'vay'),
];

/// Chuẩn hoá teencode / viết tắt tin nhắn trước khi tìm bài và chọn đường (đợt 13).
String boomNormalizeTeen(String text) {
  // cả câu gõ không dấu — xét trên chữ (bỏ emoji, "…") và bỏ chính các chữ tắt ("đc") — QC đợt 13
  final probe = _padVi(text).replaceAll(_teenWord, ' ');
  final plain = _foldKeep(probe) == probe;
  var t = text;
  for (final (rx, acc, pl) in _teenPhrase) {
    t = t.replaceAll(rx, plain ? pl : acc);
  }
  return t.replaceAllMapped(_teenWord, (m) {
    final v = _kTeen[m[1]!.toLowerCase()]!;
    return plain ? v.$2 : v.$1;
  });
}

String _padVi(String query) {
  final t = boomComposeVi(
    query.toLowerCase(),
  ).replaceAll(RegExp(r'[^\p{L}\p{N}+]+', unicode: true), ' ');
  return ' ${t.trim()} ';
}

// Câu xin tư vấn dựa trên số bán của chính quán ("món nào bán chạy, nên quảng cáo món nào", "món ế nên làm gì")
// → Boom đọc số liệu (chỉ đọc) rồi nhờ GPT phân tích trên số đó (Chủ Quán test 24/10: không có số → GPT nói chung chung).
final _dataAdviceCue = RegExp(
  r' (?:nên|gợi ý|đề xuất|tư vấn|tập trung|quảng cáo|khuyến mãi|đẩy mạnh|chiến lược|cải thiện|phân tích|đánh giá|'
  // xin Boom tự báo cáo / nhận xét (Chủ Quán test 24/10: "tình hình kinh doanh hôm nay thế nào báo cáo xem");
  // "báo cáo / tổng kết" trần ("báo cáo doanh thu hôm nay") là xin số nhanh → chỉ nhận khi là lời nhờ (QC 24/10)
  r'(?:báo cáo|tổng kết) (?:xem|đi|giúp|nhé|nha|với|và)|(?:muốn|hãy|bạn|em|boom) (?:báo cáo|tổng kết)|'
  // "phải làm gì" chỉ khi tả tình hình xấu ("doanh thu giảm phải làm gì"), không phải hỏi quy trình ("nhân viên phải
  // làm gì để món xuống bếp")
  r'nhận xét|tình hình|ổn không|(?:giảm|ít|vắng|ế|lỗ|chậm|tụt) (?:thì |quá |vậy )?phải làm gì|vì sao|tại sao|'
  r'làm gì để|tăng doanh thu|bán thêm|combo|đáng lo|sao (?:giảm|tăng|thấp|cao|ít|nhiều|tụt)(?! giá)(?!(?: \S+){0,4} vô lý)|'
  r'(?:tốt|tệ|ổn|cao|thấp) hay (?:tệ|tốt|xấu|thấp|cao|không)|(?:đi lên|đi xuống) (?:không|ko|hông|chưa)|(?:có )?(?:cao|thấp) (?:không|ko|hông)|ổn (?:ko|hông|chưa)|'
  // bộ F, G, I 27/10 (đợt 12): xếp người theo giờ bán, chỗ nào nên cắt, làm sao giảm tỉ lệ huỷ, hiệu quả không
  r'(?:cần|nên|có nên) (?:thêm|bớt|cắt|giảm|nhập|chạy|tiếp tục|xếp|chuẩn bị)|làm sao (?:để )?(?:giảm|tăng|cải thiện|kéo|giữ)|'
  r'hiệu quả (?:không|ko|hông|chưa)|(?:cao|tăng|nhiều|tốn|huỷ|hủy|ít|thấp|chi|lỗ)(?: \S+){0,2} bất thường|'
  // bộ J 27/10: lời xin nhận xét / so sánh / tìm nguyên nhân trên số của quán
  r'nguyên nhân|do đâu|do (?:món|giờ|ca|ai|khoản) nào|(?:có )?đáng (?:không|ko|hông|ngờ|lo)|là vừa|(?:cao|nhiều|thấp|ít) quá|'
  r'cao hay thấp|nhiều hay ít|(?:nhiều|ít) (?:không|ko|hông)|nên đẩy|hơn hay|(?:tốt|hiệu quả|lời|lãi|cao|đông|ngon) hơn|'
  r'cắt (?:bớt|giảm)|giảm bớt|(?:tốt|khá) lên hay|xấu đi|(?<!gửi |chuyển |in )đi xuống(?! bếp| kho)|'
  // "dựa vào số bán đề xuất…", "coi số liệu rồi…", "nhìn số đơn…" (bộ câu số liệu độc lập 26/10)
  r'dựa (?:vào |trên |theo )?(?:số|số liệu|số bán|doanh số)|(?:coi|xem|nhìn|đọc) (?:qua )?số (?:\S+ ){0,4}(?:rồi|xong|để) (?:góp ý|đề xuất|tư vấn|nói|nhận xét|phân tích)|theo doanh số|'
  r'góp ý (?:giúp|cho|tui|tôi|mình|anh|chị)) ',
);
final _shopDataTopic = RegExp(
  r' (?:món|doanh thu|bán chạy|bán được|bán ế|bán chậm|bán ít|menu|thực đơn|sản phẩm|mặt hàng|kinh doanh|'
  r'bán hàng|buôn bán|quán mình|số liệu|phân tích|số bán|doanh số|số đơn|khách quen|bán vậy|bán thế|'
  r'(?:nhìn|coi|xem|dựa vào|dựa trên|theo) (?:\S+ ){0,2}số(?! (?:điện|đt|tài khoản|bàn|thứ tự))|'
  r'giờ bán|theo giờ|giờ đông|giờ vắng|giờ cao điểm|tháng nào|quý nào|tăng hay giảm|(?:lời|lãi) hơn|'
  r'tỉ lệ|tỷ lệ|chi phí|khoản chi|tiền lương|lương (?:nv|nhân viên)|lợi nhuận|hao hụt|giá vốn|chi nhánh|'
  // "dựa vào tuần này thì tuần sau nên nhập gì", "so với tuần trước / quán bình thường" (lần 7, 9)
  r'dựa (?:vào|trên) (?:\S+ ){0,2}(?:tuần|tháng|hôm|ngày|năm)|so với (?:quán|mức|ngành|tuần|tháng|hôm|năm|kỳ|bình thường)|'
  r'quán (?:\S+ ){0,2}(?:đi lên|đi xuống)|dạo này quán) ',
);
final _howToCue = RegExp(
  r' (?:ở đâu|chỗ nào|mục nào|tab nào|nằm đâu|bấm|cài|cách xem|xem ở|trong app|app có|màn hình|mở báo cáo|làm sao|'
  r'cách nào|(?<!đề )xuất|excel|pdf|in báo cáo|tải|gửi báo cáo|có những gì|gồm những gì|xem được|quyền|phân quyền|bị sai|'
  r'không khớp|bị lệch|lệch nhau|sao lệch|tin cái nào|(?:kho|tồn|tồn kho|số lượng|nguyên liệu|quỹ|số dư) (?:\S+ ){0,2}bị âm|'
  r'(?:bên|báo cáo) (?:\S+ ){0,4}khác (?:nhau|với)(?! (?:\S+ )?(?:tuần|tháng|hôm|quý|năm|kỳ))|(?:báo cáo|lãi|lời|lợi nhuận) (?:\S+ ){0,3}khác bên|báo (?:hết hạn|lỗi|sai)|không hiện|không cập nhật|(?:không|ko|hông) (?:hề |bị )?(?:trừ|nhúc nhích|hụt)|không ra|bằng 0|bị lỗi|báo lỗi|lỗi gì|lỗi (?:chỗ|ở) nào|vô lý|gấp (?:\S+ ){0,3}lần|phải làm gì để|báo khách|chuỗi|chi nhánh|2 quán|hai quán|các quán|nhảy|trùng số|bị trùng|bị mất) ',
);

/// Câu hỏi cách dùng / báo lỗi / quyền trong app ("báo cáo doanh thu bị sai", "tải báo cáo về máy") — không trả
/// số liệu, không tư vấn số.
bool boomAsksHowTo(String query) =>
    _viHit(_howToCueP, _padVi(query).replaceAll(_adviceWhereP(query), ' '));

// "cao bất thường chỗ nào", "nên cắt chỗ nào", "làm sao giảm" là xin phân tích, không phải hỏi chỗ bấm (đợt 12)
RegExp _adviceWhereP(String query) {
  final s = _padVi(query);
  return _foldKeep(s) == s ? _adviceWhere.$2 : _adviceWhere.$1;
}

final _adviceWhere = _viPair(
  r'(?<= )(?:(?:cao|tăng|tốn|cắt|giảm|bớt|lời|lỗ|tiết kiệm|bất thường)(?: \S+){0,3} (?:ở )?chỗ nào|'
  r'chỗ nào (?:làm|gây|bị) (?:lỗ|lời|tốn|hụt)|(?:có )?cách nào (?:để )?(?:tăng|giảm|kéo|cải thiện|giữ)|'
  r'(?:tăng|giảm|kéo|cải thiện) (?:\S+ )?kiểu gì|'
  // "làm sao giảm" ở cuối câu nói về số vừa nhắc ("tỉ lệ huỷ có cao không, làm sao giảm")
  r'làm sao (?:để )?(?:giảm|tăng|cải thiện|kéo|giữ)(?= (?:(?:\S+ )?(?:doanh thu|doanh số|tỉ lệ|tỷ lệ|chi phí|lợi nhuận|lời|lãi|lỗ|'
  r'hao hụt|khách|số đơn|đơn huỷ|đơn hủy)|(?:nó |xuống |lên |lại |vậy |đây |được )?$)))(?= )',
);

// Câu gõ không dấu ("tu van xu ly dua tren so") dùng bản không dấu của luật (bộ câu số liệu độc lập 26/10)
final _howToCueP = _viPair(_howToCue.pattern);
final _dataAdviceCueP = _viPair(_dataAdviceCue.pattern);
final _shopDataTopicP = _viPair(_shopDataTopic.pattern);
// Chủ đề yếu (QC đợt 12): "đơn", "khách", "người"… chỉ là chuyện số của quán khi có kỳ / lời so lượng — không thì
// "tại sao đơn bị huỷ mà không báo", "cần thêm khách vào danh sách" bị kéo sang tư vấn kèm số
final _weakTopicP = _viPair(
  r' (?:đơn|bill|huỷ|hủy|tiệm|nhân viên|người|pha chế|nạp ví|khách|lời|lãi|lỗ) ',
);
final _qtyCueP = _viPair(
  r' (?:hôm nay|hôm qua|tuần|tháng|quý|năm|ca (?:sáng|chiều|tối)|dạo này|gần đây|mỗi (?:ngày|tối|ca)|cuối tuần|nhiều|ít|'
  r'đông|vắng|tăng|giảm|tụt|cao|thấp|so với|trung bình|bao nhiêu|mấy|bn|hơn|(?:khách|món|ca|nhân viên|người|tiệm|đơn) nào) ',
);
// Câu tả lỗi / cài đặt / quyền trong app → hướng dẫn, không tư vấn kèm số (QC đợt 12)
final _appIssueP = _viPair(
  r' (?:(?:không|ko|hông|k|chưa) (?:in|báo|lên|về|nhận(?! xét)|gọi|vào|vô|hiện|thấy|chạy|đăng nhập|được|đc|cập nhật|trừ|cộng|ra|nghe|kêu)|'
  r'bị (?:văng|đơ|treo|lỗi|mất|in|trừ|khoá|khóa|tính)|đăng nhập|máy in|in bill|khổ|in ra|tính ra|bằng (?:0|không)|số dư|'
  r'cài|bật|(?<!tóm )tắt|quyền|tài khoản|thông báo|điện tử|bằng gì|thì làm gì|vào app|trong app|trên app|luật|quy định|'
  r'cho nhân viên xem) ',
);
final _askOneNumberP = _viPair(
  r' (?:bao nhiêu|mấy (?:đơn|ly|phần|tiền|khách|người|bàn)) ',
);
final _askAnalysisP = _viPair(
  r' (?:phân tích|đánh giá|nhận xét|tư vấn|nên|(?:vậy |có )?ổn (?:không|ko|hông|chưa)|(?:có )?(?:cao|thấp) (?:không|ko|hông)|đáng lo|'
  r'cao hay thấp|nhiều hay ít|(?:cao|nhiều|thấp|ít) quá|là vừa|nguyên nhân|do đâu|vì sao|tại sao) ',
);
bool _viHit((RegExp, RegExp) p, String s) =>
    (_foldKeep(s) == s ? p.$2 : p.$1).hasMatch(s);

bool boomWantsDataAdvice(String query) {
  final s = _padVi(query);
  // Hỏi một con số ("tổng kết ca sáng doanh thu bao nhiêu") → số nhanh, không cần GPT phân tích
  if (_viHit(_askOneNumberP, s) && !_viHit(_askAnalysisP, s)) {
    return false;
  }
  return _viHit(_dataAdviceCueP, s) &&
      (_viHit(_shopDataTopicP, s) ||
          (_viHit(_weakTopicP, s) && _viHit(_qtyCueP, s))) &&
      !_viHit(_appIssueP, s) &&
      // bỏ cụm xin phân tích "cao … chỗ nào", "làm sao giảm …" trước khi xét hỏi cách làm (QC đợt 12)
      !boomAsksHowTo(query) &&
      !RegExp(' $_rival ').hasMatch(s) &&
      !boomAsksOtherStore(query);
}

// Chỉ từ nói tiếp rõ ràng (QC 24/10: "đi", "nữa", "tiếp", "chi tiết", "kiểm tra" làm câu hỏi thường như
// "thêm nhân viên mới đi", "cách in hoá đơn chi tiết" bị coi là nói tiếp).
final _followUpCue = RegExp(
  r'(?<= )(?:đề xuất|gợi ý|phân tích|giải thích|cụ thể|thì sao|vậy thì|nói rõ|ví dụ|làm luôn|rồi sao|sao nữa|'
  // "… hơn" (Chủ Quán 24/10: "Chi tiết hơn đi" bị coi là câu mới → Boom đòi tự xem báo cáo); "chi tiết" trần vẫn không
  // tính ("cách in hoá đơn chi tiết" là câu hỏi mới)
  r'tiếp tục|nói tiếp|chi tiết hơn|kỹ hơn|kĩ hơn|cụ thể hơn|rõ hơn|sâu hơn|nói thêm|thêm nữa)(?= )',
);

// Bộ L 28/10 (đợt 14): câu nói tiếp chỉ hiểu được khi ghép câu trước
// Nhánh mạnh: chữ chỉ trỏ / "vẫn không" / "bước tiếp" — câu chỉ hiểu được khi ghép câu trước (QC đợt 14: từ chung như
// "chi tiết", "thì sao" để nhánh yếu, không thì "cách in hoá đơn chi tiết" thành nói tiếp)
final _followUpStrongP = _viPair(
  r' (?:(?:làm|bấm|tạo|cài|nhập|gửi|thử) (?:\S+ )?rồi (?:mà|nhưng)|xong rồi (?:thì|làm)|vẫn (?:không|chưa|bị)|'
  r'bước (?:tiếp|kế|\d)|tiếp theo|làm gì tiếp|'
  r'(?:nút|cái|món|chỗ|bạn|người|khoản|ca|tiệm|bên|giờ|khung|lúc) (?:đó|đấy|kia)|ngày đó|(?:giữ chân|nhắc nhở|nhắc) (?:họ|bạn đó|nó)|'
  // "chiếm mấy % doanh thu tháng đó" — kỳ chỉ trỏ về câu trước (bộ N, đợt 15)
  r'(?:tháng|tuần|hôm|năm|quý|kỳ|đợt) (?:đó|đấy|ấy)|'
  // "nói lại ngắn gọn thôi", "mỗi con số tổng", "số lượng cụ thể bao nhiêu" (lần 11)
  r'nói lại|số lượng cụ thể|cụ thể (?:là )?bao nhiêu|'
  // bộ O (đợt 15): "dựa trên số đó", "nhìn số này", "nhập vậy có bị dư không"
  r'(?:số|con số) (?:đó|này|đấy|vậy)(?! \d)|(?:nhập|bán|chi|xài|dùng|lời|lãi|hủy|huỷ) (?:như )?vậy (?:có|là)|'
  r'sao (?:giảm|thấp|cao|ít|nhiều|tụt|tăng|chậm) (?:vậy|thế|quá)|(?:có )?đáng lo|nhiều vậy|ít vậy) ',
);
// Nhánh yếu: chỉ khi câu rất ngắn và không có chủ đề / thao tác riêng ("chi tiết từng ngày đi", "có hiệu quả không")
final _followUpWeakP = _viPair(
  r' (?:nếu (?:không|chỉ|chưa|ko)|(?:sửa|xoá|xóa) sao|bật lại|có hiệu quả|có bất thường|đề xuất giúp|nhận xét|đánh giá giúp|'
  r'chi tiết|từng (?:ngày|khoản|món|giờ|ca)|top \d+|chia theo|giờ nào|ai (?:hủy|huỷ|làm|bán)|nên làm gì|thì sao|ngắn gọn|tóm (?:lại|tắt)|mỗi con số) ',
);
// câu hỏi chỗ mới ("còn cái nút in tạm tính nằm đâu") là câu mới, không phải nói tiếp
// "nên cắt bớt chỗ nào", "hụt ở chỗ nào" là hỏi khoản nào trên số, không phải chỗ trong app (đợt 15)
final _newPlaceP = _viPair(
  r' (?:nằm đâu|ở đâu|(?<!(?:cắt|giảm (?:chi|bớt)|bớt|hụt|lỗ|tốn|hao|thất thoát|tiết kiệm)(?: \S+){0,2} )chỗ nào|tab nào|mục nào) ',
);
// Câu xin phân tích tiếp trên số vừa xem — cho dài tới 14 chữ ("sao lãi mỏng dữ, hụt ở khúc nào chỉ t coi")
final _followAnalysisP = _viPair(
  r' (?:sao (?:lại|giảm|tăng|thấp|cao|ít|nhiều|lãi|lời|lỗ|hụt)|vì sao|tại sao|do đâu|nguyên nhân|bất thường|nên (?:cắt|giảm|tăng|bớt)|hụt|khúc nào|cao quá|thấp quá|ít quá|nhiều quá) ',
);
// "ai hủy nhiều nhất", "món nào bị xoá nhiều nhất" — hỏi xếp hạng trên số, chữ thao tác chỉ là thứ được đếm
final _rankAskP = _viPair(
  r' (?:ai|nhân viên nào|nv nào|người nào|bạn nào|món nào|ngày nào|giờ nào|ca nào|bàn nào) (?:\S+ ){0,3}(?:nhiều|ít|cao|thấp) nhất ',
);
// "có cách nào nâng giá trị đơn", "làm sao giữ chân khách cũ tốt hơn" sau lượt số liệu — xin tư vấn, không hỏi cách
// dùng app (bộ O, đợt 15)
final _bizGoalP = _viPair(
  r' (?:nâng (?:giá trị|doanh|số|lợi)|giữ chân|kéo (?:khách|lại)|cải thiện|tốt hơn|hiệu quả hơn|'
  r'tăng (?:doanh thu|doanh số|khách|đơn|lợi nhuận|lãi|lời)|giảm (?:chi phí|chi|hủy|huỷ|hao hụt|tồn)|'
  // "giam kieu gi", "tăng bằng cách nào" (lần 10)
  r'(?:giảm|tăng|kéo|cải thiện) (?:kiểu gì|sao|thế nào|bằng cách nào|cách nào)) ',
);
// chữ thao tác thật trong app — câu có chữ này không được coi là xin tư vấn tăng chỉ số (QC đợt 15)
final _realEditP = _viPair(
  r' (?:chỉnh|sửa|cài|bấm|ở đâu|kéo thả|nâng cấp|tạo|thêm|bật|tắt|xuất|in) ',
);
// Chữ chỉ về thứ vừa nói ("xem cái này trong app ở đâu", "nó bị âm thì chỉnh lại kiểu gì") — đợt 15
final _pronounP = _viPair(
  r' (?:nó|cái này|cái đó|số này|số đó|mấy món đó|món đó|khoản đó|chỗ đó) ',
);
// "doanh thu tiền mặt hôm nay" vẫn là số bán dù chạm chữ "tiền mặt" của thu chi (QC giai đoạn 1)
final _salesWordP = _viPair(r' (?:doanh thu|doanh số|bán được|bán đc) ');
// "bán giá bao nhiêu là hợp", "định giá ly trà sữa sao cho hợp lý" — tư vấn chung, không đọc số nhanh (lần 12)
final _priceAdviceP = _viPair(
  r' (?:là hợp|hợp lý|nên bán (?:giá )?(?:bao nhiêu|mấy)|định giá|bán giá (?:bao nhiêu|mấy) (?:là|thì)) ',
);
// "kinh nghiệm giữ chân nv part time là gì" — hỏi chuyện chung, là câu mới
final _generalAskP = _viPair(
  r' (?:kinh nghiệm|mẹo|bí quyết|bí kíp|kiến thức) ',
);

// Kỳ nói trong câu (để đổi kỳ / mượn kỳ của câu trước) — đợt 14
final _periodPhraseP = _viPair(
  r'(?<= )(?:hôm nay|hôm qua|tuần (?:này|trước|rồi|qua)|tháng (?:này|trước|rồi|qua|\d+)(?: năm (?:nay|ngoái|rồi|trước))?|'
  r'quý (?:\d|này|trước)|năm (?:nay|ngoái|trước|rồi|\d{4})|\d+ (?:ngày|tuần|tháng)(?: (?:qua|nay|gần đây|gần nhất))?|'
  r'(?:sáng|trưa|chiều|tối) (?:nay|qua))(?= )',
);
final _leadFollowP = _viPair(
  r'^ (?:thế còn|vậy còn|còn|vậy|thế|rồi|ok|à|ừ|với lại)(?= )',
);
final _leadConP = _viPair(r'^ (?:thế còn|vậy còn|còn)(?= )');
// "còn bao nhiêu / còn mấy / còn hàng / còn nợ" — "còn" là động từ (tồn, dư), không phải nói tiếp
final _conVerbP = _viPair(
  r'^(?:bao nhiêu|mấy|bn|nhiêu|hàng|nợ|lại|tồn|dư|gì|nữa|bàn|chỗ)\b',
);
final _tailFollowP = _viPair(
  // "tuần trước nữa" là kỳ khác — không cắt "nữa" sau trước / rồi / qua (QC đợt 14)
  r' (?:thì sao|thế nào|ra sao|sao|vậy|nhỉ|đi|thì|(?<!(?:trước|rồi|qua) )nữa|nha|ạ)(?= +$)',
);

// Chào / cảm ơn / tạm biệt / chuyện trời mưa — không phải nói tiếp (bộ M 28/10)
final _closingP = _viPair(
  r' (?:bye|bai|tạm biệt|vậy thôi|thôi nha|mai nói tiếp|để sau|cảm ơn|cám ơn|thank|thanks|hiểu rồi|ok rồi|được rồi|là ai|'
  r'ai làm ra|trời (?:mưa|nắng|nóng|lạnh)|mưa quá|chào|đá banh|đá bóng|'
  // khen (lần 13)
  r'hay quá|giỏi (?:quá|ghê|thật)|tuyệt (?:vời|quá)|xịn (?:quá|ghê|thật)|thông minh (?:quá|ghê)|đỉnh (?:quá|thật|ghê)) ',
);

// "xem chi tiết đơn hàng thế nào" — hỏi cách xem trong app
final _seeHowP = _viPair(
  r' (?:xem|coi|mở|tìm) (?:\S+ ){0,4}(?:thế nào|như nào|sao|ra sao)(?= )',
);

/// Câu ngắn (≤ 10 chữ) không hỏi cách làm / chỗ mới / thao tác — sau lượt số liệu thì coi là nói tiếp (đợt 14).
bool boomShortFollowUp(String query, {String? previous}) {
  final s = _padVi(query);
  final n = s.trim().split(' ').length;
  final rank = _viHit(_rankAskP, s);
  // chữ thao tác đã có ở câu trước ("tuần trước hủy bao nhiêu món" → "tiền hủy tổng cộng là nhiu") là thứ được đếm
  // (chỉ với câu hỏi số; so trên chữ bỏ dấu để câu gõ không dấu vẫn khớp — QC đợt 15)
  final prevWords = previous == null || !_viHit(_askNumberP, s)
      ? const <String>{}
      : _foldKeep(_padVi(previous)).trim().split(' ').toSet();
  final own = s
      .trim()
      .split(' ')
      .where((w) => !prevWords.contains(_foldKeep(w)))
      .join(' ');
  final goal =
      previous != null && _viHit(_bizGoalP, s) && !_viHit(_realEditP, s);
  // "nên cắt bớt chỗ nào" sau câu chi phí — chữ "cắt" là xin phân tích, không phải thao tác
  final analysis =
      previous != null && _viHit(_followAnalysisP, s) && !_viHit(_realEditP, s);
  return (n <= 10 || (n <= 14 && _viHit(_followAnalysisP, s))) &&
      !_viHit(_newPlaceP, s) &&
      !_viHit(_closingP, s) &&
      !_viHit(_generalAskP, s) &&
      !_viHit(_priceAdviceP, s) &&
      !_viHit(_seeHowP, s) &&
      // câu báo lỗi app ("bếp ko nghe chuông khi có phiếu mới") / câu tự nói kỳ + chủ đề riêng ("tháng 9 lương nv
      // tổng bao nhiêu") là câu mới (bộ N 28/10)
      !_viHit(_appIssueP, s) &&
      !(IntentClassifier.timeRangeIn(query) != null &&
          (boomModuleTopics(query).isNotEmpty ||
              kBoomDataIntents.contains(
                IntentClassifier.classify(query).intent,
              ))) &&
      (goal || !boomAsksHowTo(query)) &&
      (rank || goal || analysis || !_helpAction(own)) &&
      !boomGeneralKnowledge(query);
}

// Chữ nối ý của câu hỏi tiếp sau bài hướng dẫn ("lỡ gộp nhầm thì tách lại đc ko", "mai có hàng thì bật lại sao",
// "rồi cho nó chỉ bán hàng thôi thì chỉnh ở đâu") — đợt 15
final _helpFollowCueP = _viPair(
  r'(?:^ (?:lỡ|nếu|rồi|xong|mai|sau đó|vậy|ủa|à mà|mà|còn|thế còn|vậy còn)| (?:nó|họ|cái đó|cái này|chỗ đó|'
  r'(?:bật|mở|làm|thêm|tách|đổi|gộp|in|hiện) lại|nói lại|giải thích lại|(?:không|hông|ko) hiểu)) ',
);

/// Hỏi cách làm / chỗ trong app về đúng thứ vừa nói ("nó bị âm thì chỉnh lại kiểu gì" sau câu tồn kho) — đợt 15
bool boomHelpAboutPrevious(String query) {
  final s = _padVi(query);
  return s.trim().split(' ').length <= 12 &&
      _viHit(_pronounP, s) &&
      (boomAsksHowTo(query) ||
          _viHit(_newPlaceP, s) ||
          _viHit(_seeHowP, s) ||
          // "ủa sao nó lại âm vậy" — báo lỗi số trong app (không phải "sao nó giảm vậy")
          RegExp(
            r' (?:kiểu gì|kieu gi|chỉnh|chinh|sửa|sua|nó (?:\S+ )?(?:âm|lỗi|sai|lệch|mất)|no (?:\S+ )?(?:am|loi|lech)) ',
          ).hasMatch(s));
}

/// Câu ngắn sau lượt hướng dẫn có chữ nối ý → tìm bài theo cả câu trước khi câu này tự tìm không chắc (đợt 15).
bool boomHelpFollowUp(String query) {
  final s = _padVi(query);
  return s.trim().split(' ').length <= 12 &&
      _viHit(_helpFollowCueP, s) &&
      !_viHit(_closingP, s) &&
      !_viHit(_generalAskP, s) &&
      !boomGeneralKnowledge(query) &&
      !boomWantsDataAdvice(query) &&
      !_viHit(_dataAdviceCueP, s) &&
      // câu số tự đủ nghĩa ("vậy hôm qua ai đi trễ" sau bài nạp ví) là câu mới (lần 12)
      !(IntentClassifier.timeRangeIn(query) != null &&
          (boomModuleTopics(query).isNotEmpty ||
              boomAsksPeriodMetric(query))) &&
      !kBoomDataIntents.contains(IntentClassifier.classify(query).intent);
}

/// Câu ngắn sau lượt số liệu không tự nói kỳ → mượn kỳ của câu trước ("trung bình mỗi đơn nhiêu tiền" sau "hôm qua
/// có bao nhiêu đơn"). Kỳ trước là "hôm nay" thì thôi (số theo mục mặc định tháng này) — đợt 14.
String? boomCarryPeriod(String query, String previous) {
  final s = _padVi(query);
  final prev = _padVi(previous);
  // câu nói tiếp rõ ("chi tiết hơn đi") đã được đọc kèm câu trước — gắn kỳ vào sẽ làm mất chủ đề câu trước
  if (!boomShortFollowUp(query, previous: previous) ||
      boomIsFollowUp(query, previous: previous) ||
      IntentClassifier.timeRangeIn(query) != null ||
      IntentClassifier.classify(query).intent == 'smalltalk') {
    return null;
  }
  final rp = _foldKeep(prev) == prev ? _periodPhraseP.$2 : _periodPhraseP.$1;
  final ms = rp.allMatches(prev).toList();
  if (ms.length != 1) return null;
  final p = ms.first[0]!;
  if (RegExp(
    r'^(?:hôm nay|hom nay|sáng nay|sang nay|trưa nay|trua nay|chiều nay|chieu nay|tối nay|toi nay)$',
  ).hasMatch(p)) {
    return null;
  }
  final plain = _foldKeep(s) == s;
  return '${query.trim()} ${plain ? _foldKeep(p) : p}';
}

/// Câu nói tiếp NGẮN của câu số liệu → câu đầy đủ (đợt 14), null = không viết lại:
/// - chỉ đổi kỳ ("còn hôm qua?", "tuần trước thì sao", "năm ngoái?") → câu trước bỏ kỳ cũ + kỳ mới
/// - "còn …" đổi chủ đề, không nói kỳ ("còn món bán ế nhất?") → câu này + kỳ của câu trước
String? boomRewriteFollowUp(String query, String previous) {
  final s = _padVi(query);
  final prev = _padVi(previous);
  final plain = _foldKeep(s) == s;
  final prevPlain = _foldKeep(prev) == prev;
  RegExp r((RegExp, RegExp) p) => plain ? p.$2 : p.$1;
  final rp = prevPlain ? _periodPhraseP.$2 : _periodPhraseP.$1;
  if (s.trim().split(' ').length > 8) return null;
  // câu trước có hai kỳ (câu so sánh) → không đoán được kỳ nào cần đổi
  if (rp.allMatches(prev).length > 1) return null;
  // câu này / câu trước khác kiểu gõ (có dấu / không dấu) → câu ghép đưa về không dấu cho luật bản không dấu khớp
  String out(String x) => plain == prevPlain ? x : _foldKeep(x);
  final lead = r(_leadFollowP).hasMatch(s);
  final leadCon = r(_leadConP).hasMatch(s);
  var core = s.replaceFirst(r(_leadFollowP), ' ');
  for (var i = 0; i < 3; i++) {
    core = ' ${core.replaceAll(r(_tailFollowP), ' ').trim()} ';
  }
  // câu nói tiếp rõ ("vậy sao giảm vậy", "chi tiết từng ngày") → để GPT đọc kèm lượt trước, không viết lại
  if (r(_followUpStrongP).hasMatch(s) || r(_followUpWeakP).hasMatch(core)) {
    return null;
  }
  // "khung tối thì sao" sau "khung trưa bán ổn ko", "còn chi nhánh 2" sau "doanh thu chi nhánh 1" → đổi đúng chữ đó trong
  // câu trước (lần 8, giai đoạn 1)
  for (final unit in [
    r'(?:khung giờ|khung gio|khung|ca|buổi|buoi) (?:sáng|trưa|chiều|tối|sang|trua|chieu|toi)',
    r'(?:chi nhánh|chi nhanh|cơ sở|co so) \d+',
  ]) {
    final own = RegExp('^ ($unit) \$').firstMatch(core);
    final old = RegExp(unit).firstMatch(prev);
    if (own != null && old != null && old[0] != own[1]) {
      return out(prev.replaceFirst(old[0]!, own[1]!).trim());
    }
  }
  final period = r(_periodPhraseP).firstMatch(core);
  final rest = core.replaceAll(r(_periodPhraseP), ' ').trim();
  if (period != null && rest.isEmpty) {
    final prevNo = prev
        .replaceAll(rp, ' ')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
    return out('$prevNo ${period[0]}');
  }
  final pp = rp.firstMatch(prev);
  final restP = ' $rest ';
  if (lead &&
      leadCon &&
      period == null &&
      pp != null &&
      rest.isNotEmpty &&
      rest.split(' ').length <= 5 &&
      !r(_conVerbP).hasMatch(rest) &&
      !_viHit(_newPlaceP, s) &&
      // phần còn lại phải là một chủ đề số ("còn món bán ế", "còn doanh thu", "còn khách quay lại")
      (kBoomDataIntents.contains(IntentClassifier.classify(rest).intent) ||
          _viHit(_shopDataTopicP, restP) ||
          _viHit(_weakTopicP, restP))) {
    return out('$rest ${pp[0]}');
  }
  return null;
}

/// Câu xin tư vấn về chuyện kinh doanh CỦA QUÁN (kế hoạch, quảng cáo, khuyến mãi, khách, doanh thu…) → app tự đọc số
/// liệu gửi kèm, không bắt chủ quán tự xem Báo cáo (Chủ Quán 24/10: "có thể tự vào đọc db mà").
final _shopBusinessTopic = RegExp(
  r' (?:kế hoạch|chiến dịch|chiến lược|quảng cáo|quảng bá|marketing|khuyến mãi|ưu đãi|doanh thu|doanh số|lợi nhuận|'
  r'kinh doanh|tình hình|tăng khách|thu hút khách|kéo khách|giữ khách|khách quen|món nào|bán chạy|bán ế|bán chậm|'
  r'tháng sau|tuần sau|tháng tới|tuần tới|cuối tuần|giờ vắng|ngày vắng|vắng khách|tăng doanh thu) ',
);

bool boomMentionsShopBusiness(String query) =>
    _shopBusinessTopic.hasMatch(_padVi(query));

// Câu HỎI SỐ của chính quán mà từ khoá chưa nhận ra ("tối qua có bao nhiêu bill mang về", "năm nay tới giờ bán được
// tổng cộng nhiêu", "hôm nay hủy mấy hđ"): có từ hỏi số + mốc thời gian → đọc số bán của quán và để GPT trả lời,
// thay vì đưa bài hướng dẫn "na ná" (bộ câu số liệu độc lập 26/10: chọn đường bằng từ khoá tăng chậm trên câu mới).
final _askNumberP = _viPair(
  r' (?:bao nhiêu|bn|bnhiu|bnhieu|nhiu|mấy|nhiêu|tổng|top|nhất|liệt kê|danh sách|(?:ai|nào) (?:đang|vào|làm|nghỉ|đi)) ',
);
final _periodP = _viPair(
  // "nay có mấy đơn bị hủy" — "nay" trần là hôm nay (đợt 16)
  r' (?:hôm nay|hnay|nay|hôm qua|tuần (?:này|trước|trc|rồi|qua)|tháng (?:này|trước|trc|rồi|\d+)|năm (?:nay|ngoái|trước|rồi)|quý (?:\d|này|trước)|'
  r'(?:sáng|trưa|chiều|tối) (?:nay|qua)|ca (?:sáng|chiều|tối)|gần đây|tới giờ|từ đầu|\d+ ngày|\d+ \d+|'
  r'\d+ (?:tuần|tháng) (?:nay|qua|rồi)) ',
);

// Động từ thao tác là THỨ ĐƯỢC ĐẾM ("hôm nay huỷ mấy đơn", "tuần trước xoá món bao nhiêu lần", "in lại mấy cái bill")
// → câu xin số, không phải hỏi cách làm (bộ F 27/10). Có "cách / ở đâu / bị / lỗi / sao" thì vẫn là hỏi cách làm.
final _countedP = _viPair(
  r' (?:(?:mấy|bao nhiêu|bn) (?:cái |tờ |lần )?(?:đơn|bill|hđ|hoá đơn|hóa đơn|lần|ly|món|phiếu|khoản)|'
  r'ai (?:\S+ ){1,3}nhiều nhất|'
  // "tuần này nhập hàng hết bao nhiêu tiền" (đợt 16)
  r'(?:hết|tốn|mất) (?:\S+ )?(?:bao nhiêu|bn|nhiêu|nhiu)|bao nhiêu tiền) ',
);
final _strictHowP = _viPair(
  r' (?:cách|làm sao|ở đâu|chỗ nào|hướng dẫn|kiểu gì|sao để|bằng cách|sao|lỗi|'
  // "bị huỷ / bị xoá" là thứ được đếm; "bị đơ / bị lỗi" là báo lỗi; "không in / không thanh toán được" cũng vậy
  r'bị(?! (?:huỷ|hủy|xoá|xóa|trả|hoàn))|(?:1|một) (?:ngày|tuần|tháng|ca|đơn|khách)|lỡ|nhầm|lộn|khôi phục|lấy lại|mở lại|muốn|giờ (?:làm|thêm)|mỗi|tối đa|giới hạn|'
  r'được phép|(?:không|ko|hông|k) (?:in|được|đc|lên|ra|vào|vô|hiện|chạy|nhận|thanh toán|cho)|'
  r'được không|đc không|đc ko) ',
);

final _taxP = _viPair(r' (?:thuế(?! nhà| mặt bằng)|hộ kinh doanh) ');

bool boomCountsShopAction(String query) {
  final s = _padVi(query);
  return hasHelpActionWord(query) &&
      _viHit(_countedP, s) &&
      _viHit(_periodP, s) &&
      !_viHit(_strictHowP, s) &&
      !boomAsksHowTo(query) &&
      !boomAsksOtherStore(query);
}

/// Động từ thao tác thật (bỏ trường hợp động từ là thứ được đếm, hoặc là lời xin phân tích trên số của quán:
/// "ca tối có cần thêm người", "nên nhập thêm bao nhiêu", "tỉ lệ huỷ đơn có cao không, làm sao giảm" — đợt 12).
bool _helpAction(String query) =>
    hasHelpActionWord(query) &&
    !boomCountsShopAction(query) &&
    !boomWantsDataAdvice(query);
// hỏi luật / ngưỡng / cách tính → tư vấn chung, không đọc số
final _askRuleP = _viPair(
  r' (?:nên|có nên|là đủ|bắt buộc|như thế nào|thế nào là|tính sao|quy định|theo luật|thường|nghỉ lễ|hợp lý|thì phải|phạt|xử lý|sao) ',
);

// Phải nói tới chuyện bán hàng; "mấy giờ", "ngày mấy", "bao nhiêu độ / phần trăm", thuế, giá gói… là câu khác (QC 26/10:
// không lọc thì 48/100 câu hỏi cách làm / kiến thức bị kéo sang đọc số)
final _salesNounP = _viPair(
  r' (?:bán|doanh thu|doanh số|dt|đơn|bill|hđ|hoá đơn|hóa đơn|ly|phần|món|khách|bàn|mang về|giao hàng|huỷ|hủy|lời|lãi|lỗ|'
  r'tiền mặt|chuyển khoản|thu được|thu đc|thu về) ',
);
final _notSalesNumberP = _viPair(
  r' (?:(?:mấy|bao nhiêu) (?:giờ|ngày|lần|độ|phần trăm|máy|người|tuổi)|ngày mấy|thuế|bảo hiểm|giá(?! trị)|gói|cảm ơn|tết|lễ) ',
);

bool boomAsksShopNumber(String query) {
  final s = _padVi(query);
  if (boomCountsShopAction(query) &&
      !_viHit(_askRuleP, s) &&
      !boomGeneralKnowledge(query)) {
    return true;
  }
  return _viHit(_askNumberP, s) &&
      _viHit(_periodP, s) &&
      _viHit(_salesNounP, s) &&
      !_viHit(_notSalesNumberP, s) &&
      !_viHit(_askRuleP, s) &&
      !boomAsksHowTo(query) &&
      !_helpAction(query) &&
      !boomGeneralKnowledge(query) &&
      !boomAsksOtherStore(query);
}

// Câu có kỳ + một con số của quán + từ hỏi ("tháng này lỗ hay lời", "7 ngày qua bán sao", "thang 9 food cost co cao
// ko", "khung giờ nào hôm nay đông nhất") → tư vấn kèm số, không để bài hướng dẫn khớp chữ "na ná" thắng (đợt 16)
final _metricP = _viPair(
  r' (?:đông|vắng|bán|food cost|giá vốn|khung (?:giờ|sáng|trưa|chiều|tối)|giờ nào|nhập hàng|lời|lãi|lỗ|doanh thu|'
  r'lợi nhuận|chi phí|đơn|khách|hủy|huỷ|'
  // "nhìn số năm nay quán có đang đi lên không" (lần 7, giai đoạn 1)
  r'quán (?:\S+ ){0,2}(?:đi lên|đi xuống|tăng|giảm|ổn|khá)|tăng trưởng|làm ăn) ',
);
final _metricAskP = _viPair(
  r' (?:bao nhiêu|bn|nhiêu|nhiu|mấy|sao|ổn|cao|thấp|hay|nào|không|ít|nhiều|đi lên|đi xuống|tăng|giảm|nhất|thế nào|ra sao) ',
);
final _metricHowP = _viPair(
  // "báo cáo hôm nay chưa có giao dịch" là báo lỗi app (lần 6)
  r' (?:cách|ở đâu|chỗ nào|mục nào|bấm|lỗi|hướng dẫn|cài|quy định|theo luật|bắt buộc|thuế|chưa có giao dịch|chưa thấy|không thấy|giao dịch|xử lý) ',
);

bool boomAsksPeriodMetric(String query) {
  final s = _padVi(query);
  return (IntentClassifier.timeRangeIn(query) != null || _viHit(_periodP, s)) &&
      _viHit(_metricP, s) &&
      _viHit(_metricAskP, s) &&
      !_viHit(_metricHowP, s) &&
      !_viHit(_appIssueP, s) &&
      !boomAsksHowTo(query) &&
      !_helpAction(query) &&
      !boomGeneralKnowledge(query) &&
      !boomAsksOtherStore(query);
}

// Tiếng đệm / đại từ / động từ chung trong câu nói tiếp — bỏ đi mà còn ≤ 2 chữ = câu không tự đủ nghĩa.
const _followUpFiller = {
  'bạn',
  'boom',
  'bé',
  'em',
  'tôi',
  'mình',
  'tui',
  'anh',
  'chị',
  'cho',
  'giúp',
  'với',
  'và',
  'đi',
  'nha',
  'nhé',
  'ạ',
  'à',
  'hơn',
  'nữa',
  'thêm',
  'được',
  'không',
  'ko',
  'vậy',
  'thế',
  'thì',
  'nên',
  'làm',
  'gì',
  'sao',
  'kiểm',
  'tra',
  'xem',
  'hãy',
  'luôn',
  'cái',
  'đó',
  'này',
  'nào',
  'rồi',
  'chút',
  'coi',
  'thử',
};

/// Câu nói tiếp lượt trước ("bạn kiểm tra và đề xuất cho tôi đi", "nói rõ hơn") — có từ nói tiếp và gần như
/// không có nội dung riêng ("thêm nhân viên mới đi", "giải thích phiếu tạm tính" là câu hỏi mới).
bool boomIsFollowUp(String query, {String? previous}) {
  final s = _padVi(query);
  // dấu hiệu nói tiếp rõ ràng trong câu ngắn ("làm rồi mà vẫn không được", "món đó tháng trước thì sao") — đợt 14
  if (previous != null && !_viHit(_newPlaceP, s)) {
    final n = s.trim().split(' ').length;
    if (n <= 12 && _viHit(_followUpStrongP, s)) return true;
    if (n <= 6 &&
        _viHit(_followUpWeakP, s) &&
        !hasHelpActionWord(query) &&
        !_viHit(_weakTopicP, s) &&
        !_viHit(_shopDataTopicP, s)) {
      return true;
    }
  }
  if (!_followUpCue.hasMatch(s)) return false;
  final rest = s
      .replaceAll(_followUpCue, ' ')
      .trim()
      .split(' ')
      .where((w) => w.isNotEmpty && !_followUpFiller.contains(w))
      .toList();
  if (rest.isEmpty) return true;
  // Còn chữ riêng ("giải thích tạm tính", "gợi ý giá bán") → chỉ là nói tiếp khi các chữ đó đều ở câu trước
  final prev = previous == null
      ? const <String>{}
      : _padVi(previous).split(' ').toSet();
  return rest.length <= 2 && rest.every(prev.contains);
}

/// Có nhắc kỳ cụ thể ("hôm nay", "tuần trước"…) — không nhắc thì tư vấn theo số tháng này (đủ đơn để phân tích).
final _mentionsPeriodP = _viPair(
  r' (?:hôm nay|hôm qua|nay|tuần|tháng|ngày|quý|năm) ',
);

/// Câu chào / cảm ơn / hỏi Boom là ai — đáp thân thiện ngay trên máy, không tốn lượt GPT (trước đây trả
/// "Bé Boom chưa hiểu rõ lắm ạ" — Chủ Quán 24/10: Boom bị luật kìm).
String boomSmalltalkReply(String query, String goi) {
  final s = _padVi(query);
  if (RegExp(r' (?:cảm ơn|cám ơn|thank|thanks|tkx|tks) ').hasMatch(s)) {
    return 'Dạ không có gì ạ! $goi cần gì cứ hỏi Bé Boom nhé.';
  }
  if (RegExp(r' (?:là ai|tên gì|làm được gì|giúp được gì) ').hasMatch(s)) {
    return 'Dạ, Bé Boom là trợ lý của quán ạ: xem nhanh doanh thu, món bán chạy, hàng sắp hết, chỉ cách dùng app, '
        'và tư vấn kinh doanh (giá bán, khuyến mãi, nhân viên, món mới…) dựa trên số liệu của quán. $goi muốn hỏi gì ạ?';
  }
  return 'Dạ, Bé Boom chào $goi ạ! Hôm nay $goi cần xem số liệu, hỏi cách dùng app hay cần tư vấn chuyện quán ạ?';
}

/// Câu hỏi KIẾN THỨC NGHỀ / ĐỜI SỐNG không phải cách dùng app (công thức nấu / pha, bảo quản, dịch, viết bài, Excel,
/// luật lao động, thiết bị, trang trí, phòng cháy…) — bộ tìm hướng dẫn chưa chắc thì đi thẳng tư vấn, không ép vào
/// chế độ hướng dẫn app (QC 24/10: 32/40 câu loại này bị kéo vào đó → GPT từ chối / thiếu kiến thức nghề).
final _generalKnowledge = RegExp(
  r' (?:công thức (?:nấu|pha|làm|nước|sốt)|cách (?:nấu|pha|làm món|làm nước|ướp|ninh)|ninh xương|ướp|định lượng|'
  r'làm được (?:bao nhiêu|mấy)(?! (?:giờ|tiếng|ca|ngày công|tiền))|bảo quản|để được mấy ngày|để ngoài|hết hạn|an toàn thực phẩm|ngộ độc|dịch(?! vụ)|tiếng anh|'
  r'viết (?:giúp|giùm|bài|tin|câu|thư|nội dung|lời)|bài đăng|đăng tuyển|tuyển (?:nhân viên|người|phục vụ)|hàm excel|'
  r'google sheets|sheets|công thức excel|lương tối thiểu|thử việc|hợp đồng lao động|bảo hiểm|nghỉ ngang|giữ lương|'
  r'máy pha|tủ mát|tủ đông|nên mua|loại nào tốt|trang trí|decor|nhạc|wifi cho khách|phòng cháy|chữa cháy|pccc|bình chữa cháy|'
  r'giấy phép|rượu bia|bán bia|đau lưng|mỏi chân|sức khoẻ|sức khỏe|chuyện cười|kể chuyện|tình cảm|người yêu|bồ|'
  // lạc đề (đợt 12)
  r'thời tiết|có mưa|mưa (?:không|ko|hông)|bóng đá|đá banh|đá bóng|đội tuyển|(?:bóng|trận|việt nam)(?: \S+){0,2} đá mấy giờ|uống thuốc|'
  r'(?:bị|đang|lên cơn) sốt|sốt \d+ độ|xổ số|giá vàng|'
  r'phim (?:gì|nào|hay)|bài tập|'
  // lạc đề sau lượt số: bóng đá viết tắt, so app khác (lần 13)
  r'(?:mu|man ?u|man utd|man city|chelsea|arsenal|liverpool|barca)(?: \S+){0,3} (?:đá|thắng|thua|mấy giờ)|ngoại hạng|'
  r'(?:app|phần mềm|ứng dụng) (?:nào|gì) (?:\S+ ){0,3}(?:tốt hơn|hay hơn|tốt nhất|rẻ hơn|ngon hơn)|(?:app|phần mềm) khác) ',
);
// gõ không dấu: chỉ vài cụm lạc đề chắc chắn (gấp cả bộ luật bỏ dấu dễ trùng "bò", "bỏ"…) — lần 13
final _offTopicPlain = RegExp(
  r' (?:thoi tiet|troi (?:mua|nang)|co mua (?:khong|ko)|bong da|da banh|da bong|doi tuyen|tran mu|(?:mu|man u|man utd|man city)(?: \S+){0,3} (?:da|thang|thua)|xo so|gia vang|(?:app|phan mem) (?:nao|gi) (?:\S+ ){0,3}(?:tot hon|hay hon|tot nhat)) ',
);

// Câu hỏi so sánh / tình hình các chi nhánh CỦA CHỦ QUÁN ("so sánh doanh thu 2 quán tháng này", "chi nhánh nào bán
// kém") → đọc báo cáo chuỗi (chỉ chủ chuỗi đọc được), GPT so sánh trên số thật (Chủ Quán 25/10). Câu tạo / thêm / gỡ chuỗi,
// hỏi chỗ xem, báo lỗi → vẫn đi hướng dẫn.
// Từ chắc chắn nói về chi nhánh của mình: "chi nhánh", "cơ sở 2", "chuỗi (của tôi)". "chuỗi" trần chỉ khi có dấu
// ("chuoi" không dấu cũng là "chuối" — QC 25/10).
const _chainStrongSrc =
    r' (?:chi nhánh|cơ sở \d|cơ sở (?:của|bên)|chuỗi (?:cửa hàng |quán )?(?:của )?(?:tôi|mình|tui|tớ|em|chúng tôi)|'
    r'(?:quán|cửa hàng) khác (?:của|bên) (?:tôi|mình|tui|tớ|em|chúng tôi)|cả hệ thống|toàn hệ thống|cả chuỗi|'
    r'toàn chuỗi|trong chuỗi) ';
const _chainBareChuoi = r' chuỗi ';
// Từ có thể là quán NGƯỜI KHÁC ("mấy quán quanh đây", "quán kia bán rẻ hơn") → chỉ nhận khi có "của tôi / mình" hoặc
// là câu so sánh / xếp hạng ("so sánh 2 quán", "quán nào…").
const _chainWeakSrc =
    r' (?:các quán|2 quán|hai quán|3 quán|ba quán|mấy quán|từng quán|các cơ sở|2 cơ sở|hai cơ sở|3 cơ sở|từng cơ sở|các cửa hàng|2 cửa hàng|hai cửa hàng|từng cửa hàng|'
    r'2 tiệm|hai tiệm|3 tiệm|các tiệm|mấy tiệm|từng tiệm|tiệm kia|'
    r'quán kia|cửa hàng kia|quán còn lại|cửa hàng còn lại|so sánh quán \S+(?: \S+){0,3} (?:với|và) quán) ';
const _chainMineSrc =
    r' (?:(?:của|bên) (?:tôi|mình|tui|tớ|em|chúng tôi|nhà mình)|quán mình|nhà mình|so sánh|quán nào|cửa hàng nào|tiệm nào) ';
const _chainAskSrc =
    r' (?:so sánh|so với|doanh thu|doanh số|bán|đơn|khách|tình hình|kinh doanh|hơn|kém|tốt|tệ|yếu|mạnh|nhất|'
    r'thế nào|ra sao|nhận xét|phân tích|đánh giá|tổng|tăng|giảm|chênh|tụt|cải thiện|sao rồi|dạo này|dồn|xếp người|'
    r'đóng|nên|cần|số liệu|con số|báo cáo) ';
// Câu cách dùng / báo lỗi / tạo – gỡ chuỗi / hỏi chuỗi khác trên thị trường → hướng dẫn hoặc tư vấn chung (QC 25/10)
const _chainSetupSrc =
    r' (?:(?:tạo|thêm|gộp|gỡ|xoá|xóa|rời|mời|đưa|bỏ|đổi tên|nhượng quyền)(?: \S+){0,2} (?:chuỗi|chi nhánh|cơ sở|quán|cửa hàng)|'
    r'(?:nên|có nên|muốn|định|sắp) mở (?:thêm |mới )?(?:\S+ )?(?:chuỗi|chi nhánh|cơ sở|quán|cửa hàng)|'
    r'ở đâu|chỗ nào|mục nào|tab nào|bấm|nút|màn hình|xem ở|cách xem|xuất|excel|pdf|tải|in báo cáo|in hoá đơn|in hóa đơn|'
    r'in bill|quyền|phân quyền|không hiện|không thấy|bị lỗi|báo lỗi|bị sai|không khớp|bị lệch|bị mất|mất đơn|đăng ký|'
    r'nâng cấp|gói|phí|để xem|để coi|xem được|coi được|được xem|được coi|xem chung|xem tổng|gom|là gì|hoạt động thế nào|'
    r'hoạt động ra sao|cách (?:in|tạo|thêm|xem|cài|dùng|mở|đổi|gỡ|xoá|xóa|chuyển)|chuỗi ngày|chuỗi cung ứng|cung ứng|'
    r'đối diện|bên kia|bên cạnh|gần đây|gần trường|quanh đây|xung quanh|cạnh nhau|ăn vặt|mặt bằng|việt nam|thị trường|'
    r'nổi tiếng|thương hiệu|đối thủ|số điện thoại|ngân hàng|kiểu gì|(?:ko|k|hông) thấy|xem gộp|chỗ xem) ';

// Bỏ dấu nhưng GIỮ cú pháp regex (foldVietnamese xoá mọi ký tự không phải chữ / số)
String _foldKeep(String s) => s
    .toLowerCase()
    .split('')
    .map((c) => c.codeUnitAt(0) < 128 ? c : foldVietnamese(c))
    .join();

// Mỗi luật một cặp: bản có dấu + bản không dấu (chỉ dùng khi cả câu gõ không dấu)
(RegExp, RegExp) _viPair(String src) => (RegExp(src), RegExp(_foldKeep(src)));
final _chainStrong = _viPair(_chainStrongSrc);
final _chainWeak = _viPair(_chainWeakSrc);
final _chainMine = _viPair(_chainMineSrc);
final _chainAsk = _viPair(_chainAskSrc);
final _chainSetup = _viPair(_chainSetupSrc);
// Đối thủ ("chuỗi khác", "Highlands"…) — trừ "chi nhánh khác / cửa hàng khác" (với chủ chuỗi là quán của họ)
final _chainRival = _viPair(' $_rival ');
final _chainThis = _viPair(r' (?:chi nhánh|cơ sở) này ');
// "chi nhánh khác", "quán khác của tôi" = quán của chính chủ, không phải đối thủ
final _chainOwnOther = _viPair(
  r' (?:(?:chi nhánh|cửa hàng) khác|(?:quán|cửa hàng) khác (?:của|bên) (?:tôi|mình|tui|tớ|em|chúng tôi)) ',
);

bool boomAsksChain(String query) {
  var s = _padVi(query);
  final plain = _foldKeep(s) == s; // gõ không dấu
  RegExp r((RegExp, RegExp) p) => plain ? p.$2 : p.$1;
  // "chi nhánh này" = quán đang mở → câu số liệu một quán, trừ khi đang so sánh (QC 25/10)
  if (!r(_chainMine).hasMatch(s)) {
    s = s.replaceAll(r(_chainThis), ' quán này ');
  }
  final cue =
      r(_chainStrong).hasMatch(s) ||
      (!plain && RegExp(_chainBareChuoi).hasMatch(s)) ||
      (r(_chainWeak).hasMatch(s) && r(_chainMine).hasMatch(s));
  return cue &&
      r(_chainAsk).hasMatch(s) &&
      !r(_chainSetup).hasMatch(s) &&
      !r(_chainRival).hasMatch(s.replaceAll(r(_chainOwnOther), ' '));
}

// ── Số liệu các module (Chủ Quán 25/10: "cho Boom đọc và không cho thêm số liệu vào") ─────────────────────
// Từ chủ đề CHẶT (QC 25/10: "lãi suất ngân hàng", "nguyên liệu cà phê muối", "lương phục vụ thường bao nhiêu",
// "giảm giá món thế nào", "có lời khuyên" bị nhận nhầm là hỏi số của quán)
const _moduleTopicSrc = {
  BoomModule.finance:
      r' (?:thu chi|chi phí|khoản chi|tiền chi|chi tiêu|chi ra|tiền ra|tiền vào|thu vào|lợi nhuận|lời lãi|có lãi|có lời (?:không|chưa|bao nhiêu|nhiều|ít)|'
      r'lãi bao nhiêu|lời bao nhiêu|lỗ không|bị lỗ|đang lỗ|lời hay lỗ|lãi hay lỗ|dòng tiền|sổ quỹ|quỹ tiền mặt|tiền mặt|'
      r'tiền điện|tiền nước|tiền thuê|tiền nhà|chi nhiều|tổng chi(?! nhánh| nhanh)|chi(?! nhánh| nhanh) (?:\S+ ){0,2}hết|chi những gì|chi (?:những )?khoản (?:gì|nào)|chi gì|chi hết|lãi lỗ|lời lỗ|(?:lời|lãi) (?:không|ko|hông|chưa)) ',
  BoomModule.kho:
      r' (?:tồn kho|còn tồn|hàng tồn|kho còn|kho có|trong kho còn|(?:còn|có|hết) (?:\S+ ){0,2}trong kho|kho hàng|giá trị kho|hết hàng|sắp hết|nhập hàng|nhập kho|hàng nhập|'
      r'nguyên liệu (?:nào|còn|sắp|hết|tồn|nhập)|còn bao nhiêu (?:hộp|kg|gói|lon|chai|thùng|cái|ly|bịch|túi)|hao hụt|'
      r'hư hỏng|đổ bỏ|hàng hết hạn|nguyên liệu hết hạn|nhà cung cấp nào|nhập của ai|còn nhiêu(?! (?:ngày|lâu|tháng|năm|thời gian))|'
      // bộ G 27/10: "trân châu còn bao nhiêu", "còn mấy chai siro", "đường còn nhiu kg"
      r'(?:xài|dùng) (?:hết )?(?:bao nhiêu|nhiêu|nhiu)|nhập thêm (?:bao nhiêu|nhiêu|mấy)|'
      r'(?<!(?:gói|hạn|điểm|ví|tiền|bàn|két|quỹ|mã|voucher|mức|lượt|nợ|dư)(?: \S+){0,2} )còn (?:bao nhiêu|nhiêu|nhiu)(?= (?:(?:vậy|ạ|nhỉ|á|ha|hả|z|vay|a|nhi) )?$)|còn (?:mấy|nhiu) (?:hộp|kg|ký|gói|lon|chai|thùng|bịch|túi|lít|bao)) ',
  BoomModule.nhanSu:
      r' (?:chấm công|ca làm|giờ làm|làm (?:bao nhiêu|mấy) (?:giờ|ca|tiếng)|quên chấm|bảng lương|kỳ lương|quỹ lương|tổng lương|'
      r'lương tháng (?:này|trước)|lương tuần (?:này|trước)|(?:tháng|tuần) (?:này|trước) lương|trả lương tháng|nhân viên nào|'
      r'ai làm(?! ra)|ai đi làm|ai nghỉ làm|ai nghỉ|làm nhiều nhất|làm ít nhất|đi làm (?:bao nhiêu|mấy)|lương (?:nv|nhân viên) (?:tháng|tuần)|'
      r'ca (?:sáng|chiều|tối) (?:\S+ ){0,2}(?:có )?(?:ai|mấy người)|nào vào ca|ai (?:đang )?(?:vào|vô|trong) ca|vào ca (?:rồi|chưa)|'
      r'lương (?:\S+ ){0,3}(?:tháng|tuần) (?:này|trước)|(?:tháng|tuần|kỳ) (?:này|trước|rồi|\d+) (?:\S+ ){0,3}trả lương|trả lương (?:\S+ ){0,3}(?:tháng|tuần|kỳ) (?:này|trước)|'
      // "nên trả lương nhân viên bao nhiêu" là tư vấn chung → chỉ nhận "tiền lương" kèm kỳ / tên
      r'tiền lương (?:\S+ ){0,3}(?:tháng|tuần|kỳ) (?:này|trước)|'
      // bộ E 26/10: giờ làm / đi trễ / lương tháng N
      r'làm (?:\S+ ){0,2}(?:mấy|bao nhiêu) (?:tiếng|giờ)|đi trễ|giờ công|lương tháng \d+|chi (?:tiền )?lương|lương (?:\S+ ){0,3}phải trả|'
      // bộ N (đợt 15): "tháng 9 lương nv tổng bao nhiêu"
      r'(?<!(?:trả|nên) )lương (?:nv|nhân viên) (?!(?:\S+ ){0,2}chiếm)(?:\S+ ){0,2}(?:tổng|hết|bao nhiêu|nhiêu|nhiu|bn)) ',
  BoomModule.khach:
      r' (?:khách quen|khách hàng (?:nào|của|quay|mới|thân)|khách mới|khách quay lại|thành viên (?:mới|của)|tích điểm|'
      r'ví khách|số dư ví|nạp ví|khách vip|khách chi|khách nào|khách cũ|top khách|khách (?:nào )?(?:mua|ghé) nhiều nhất) ',
  BoomModule.khuyenMai:
      r' (?:khuyến mãi|voucher|mã giảm|coupon|mã khuyến mãi|chương trình giảm giá|'
      r'giảm giá (?:tháng|tuần|hôm|tổng|bao nhiêu tiền|hết bao nhiêu)) ',
};
// Câu xin SỐ / phân tích (không phải hỏi cách làm)
const _moduleAskSrc =
    r' (?:bao nhiêu|mấy|nào|nhất|tổng|tình hình|phân tích|đánh giá|nhận xét|so sánh|so với|tăng|giảm|ra sao|'
    r'kiểm tra|xem giúp|xem giùm|coi giùm|xem dùm|bất thường|báo cáo|liệt kê|danh sách|hiệu quả|tháng này|tuần này|hôm nay|hôm qua|tháng trước|tuần trước|'
    r'kỳ này|có lãi|lỗ không|lời hay lỗ|lãi hay lỗ|tốn|nhiều không|ít không|những gì|chi gì|sắp hết|hết hàng|'
    r'quay lại|ai làm|có ai|ai đang|còn (?:nhiêu|nhiu)(?! (?:ngày|lâu|tháng|năm|thời gian))|\d+ ngày (?:qua|nay|gần đây)|top|(?:tháng|tuần) (?!13 )\d+|quý \d|hết nhiêu|bn|nhiu|bnhiu) ';
// Hỏi cách làm / thao tác / lỗi / kiến thức chung → hướng dẫn hoặc tư vấn như cũ
const _moduleHowSrc =
    r' (?:ở đâu|chỗ nào|mục nào|tab nào|bấm|nút|màn hình|cách|làm sao để (?:thêm|tạo|nhập|sửa|xoá|xóa|in|xuất|xem|mở|'
    r'chấm|cài|bật|tắt|đổi|dùng)|(?:thêm|tạo|sửa|xoá|xóa|cài|bật|tắt|đổi|duyệt|chốt) (?:\S+ ){0,2}(?:mã|voucher|khuyến mãi|'
    r'khách|nhân viên|lương|ca|phiếu|món|hàng|nguyên liệu|nhà cung cấp|quỹ|danh mục|khoản|chi|thu|tiền)|(?<!đề )xuất|excel|pdf|in phiếu|in bảng|'
    r'bị lỗi|báo lỗi|không hiện|không thấy|bị sai|bị lệch|không khớp|quyền|phân quyền|là gì|công thức|luật|quy định|'
    r'bảo hiểm|thuế|hợp đồng|tối thiểu vùng|nên giữ|hợp lý|uy tín|rẻ nhất|nhiệt độ|xử lý sao|thì xử lý|phải không|'
    r'ở quận|ở sài gòn|ở hà nội|ở đà nẵng|thị trường|thường bao nhiêu|báo khách|'
    // "sao báo cáo lãi lỗ ko có giá vốn" — màn hình thiếu số là hỏi về app (26/10)
    r'(?:báo cáo|màn|tab|mục) (?:\S+ ){0,3}(?:không|ko|chưa) (?:có|hiện|ra)|'
    // QC 26/10: "lãi lỗ tính như thế nào", "lương tháng 13 có bắt buộc không", "ca tối mấy người là đủ"
    r'như thế nào|tính thế nào|tính sao|là đủ|bắt buộc|tính trên|thì tính|thì nên|sửa sao|nên có|nên chạy|'
    // bộ G 27/10: báo lỗi / hỏi chỗ ghi ("lệch nhau hoài", "sao ít bất thường", "ghi vô đâu", "ko thấy khoản lương")
    r'lệch nhau|sao lệch|sao (?:ít|nhiều|cao|thấp) bất thường|(?:ghi|nhập|bấm|để|lưu) (?:\S+ ){0,2}(?:vô|vào) đâu|(?:ko|hông) thấy|nó báo|báo hết hạn|(?:kho|tồn|nguyên liệu) (?:\S+ ){0,2}bị âm|trong app|'
    r'(?:báo cáo|màn|app|bên) (?:\S+ ){0,4}khác (?:với|nhau)|(?:báo cáo|lãi|lời|lợi nhuận) (?:\S+ ){0,3}khác bên|khác (?:với|nhau) (?:\S+ ){0,3}(?:báo cáo|thu chi|sổ)) ';
final _moduleTopics = {
  for (final e in _moduleTopicSrc.entries) e.key: _viPair(e.value),
};
final _moduleAsk = _viPair(_moduleAskSrc);
final _moduleHow = _viPair(_moduleHowSrc);

/// Các module mà câu hỏi xin SỐ LIỆU ("tháng này chi phí gì nhiều nhất", "hàng nào sắp hết", "ai làm nhiều giờ nhất",
/// "voucher nào hiệu quả"). Câu hỏi cách làm / báo lỗi / luật → rỗng (đi hướng dẫn / tư vấn như cũ).
Set<BoomModule> boomModuleTopics(String query) {
  final s = _padVi(query).replaceAll(_adviceWhereP(query), ' ');
  final plain = _foldKeep(s) == s;
  RegExp r((RegExp, RegExp) p) => plain ? p.$2 : p.$1;
  // Câu kiến thức chung / chi nhánh (đã có đường riêng) → không đọc số module
  if (!r(_moduleAsk).hasMatch(s) ||
      r(_moduleHow).hasMatch(s) ||
      boomGeneralKnowledge(query) ||
      r(_chainStrong).hasMatch(s) ||
      RegExp(r' (?:chuỗi|chuoi) ').hasMatch(s)) {
    return {};
  }
  return {
    for (final e in _moduleTopics.entries)
      if (r(e.value).hasMatch(s)) e.key,
  };
}

/// Đọc số các module (thử nghiệm thay bằng bản giả). null → dùng cổng chỉ đọc thật.
typedef BoomModuleLoader =
    Future<({Map<String, dynamic> facts, List<BoomModule> denied})> Function(
      String storeId,
      Set<BoomModule> topics,
      String query,
    );
final boomModuleLoaderProvider = Provider<BoomModuleLoader?>((ref) => null);

/// Cổng đọc số nhanh (thử nghiệm thay bằng bản giả). null → cổng chỉ đọc thật.
final boomReadOnlyDataProvider = Provider<BoomReadOnlyDataService?>(
  (ref) => null,
);

/// Quyền của người hỏi (thử nghiệm thay bằng bản giả). null → đọc chặt từ máy chủ.
final boomPermsLoaderProvider =
    Provider<Future<BoomPerms?> Function(String storeId)?>((ref) => null);

const kBoomModuleKeys = {
  BoomModule.finance: 'finance',
  BoomModule.kho: 'kho',
  BoomModule.nhanSu: 'nhan_su',
  BoomModule.khach: 'khach',
  BoomModule.khuyenMai: 'khuyen_mai',
};

bool boomGeneralKnowledge(String query) {
  final s = _padVi(query);
  return _generalKnowledge.hasMatch(s) ||
      (_foldKeep(s) == s && _offTopicPlain.hasMatch(s));
}

bool boomAsksOtherStore(String query) {
  final t = boomComposeVi(
    query.toLowerCase(),
  ).replaceAll(RegExp(r'[^\p{L}\p{N}+]+', unicode: true), ' ');
  final s = ' ${t.trim()} ';
  return _otherStore.hasMatch(s) &&
      _asksNumber.hasMatch(s) &&
      !_ownOrAdvice.hasMatch(s);
}

/// Gọi GPT qua hàm máy chủ boom-chat; null khi chưa có Supabase (test) → Boom trả nguyên văn.
final boomAiServiceProvider = Provider<BoomAiService?>((ref) {
  try {
    return BoomAiService(Supabase.instance.client);
  } catch (_) {
    return null;
  }
});

final boomChatProvider = NotifierProvider<BoomChatNotifier, List<BoomMessage>>(
  BoomChatNotifier.new,
);

/// Lượt trước để hiểu câu nói tiếp. Chỉ giữ lượt GPT trả lời / tư vấn và lượt số bán (doanh thu, món) — lượt số
/// bán KHÔNG giữ câu trả lời (số đã gửi lại qua facts); lượt nhân sự / kho / từ chối không giữ (không gửi ra ngoài).
class _LastTurn {
  final BoomTurn turn;

  /// Lượt trước nói về số bán / doanh thu của quán → câu nói tiếp được tư vấn kèm số liệu.
  final bool shopData;

  /// Lượt trước là GPT tư vấn → câu nói tiếp tư vấn tiếp (không tìm hướng dẫn theo câu ghép).
  final bool advice;
  final DateTime at;

  /// Lượt trước so sánh chi nhánh → câu nói tiếp ("chi tiết hơn") đọc lại báo cáo chuỗi.
  final bool chain;

  /// Lượt trước phân tích số module (thu chi, kho…) → câu nói tiếp đọc lại đúng các module đó.
  final bool modules;

  /// Câu người dùng gõ nguyên văn — GPT đọc câu gốc, `turn.question` (đã chuẩn hoá / viết lại) chỉ để chọn đường (lần 14).
  final String raw;
  const _LastTurn(
    this.turn,
    this.shopData,
    this.at, {
    this.advice = false,
    this.chain = false,
    this.modules = false,
    this.raw = '',
  });
}

class BoomChatNotifier extends Notifier<List<BoomMessage>> {
  bool _mounted = true;
  _LastTurn? _lastTurn;

  /// Lúc bấm "làm mới" cuộc chat — máy chủ không nhắc chuyện trước mốc này. null = nhớ đủ 5 giờ (tải lại trang /
  /// mở lại app vẫn nhớ; máy chủ chỉ lấy lượt của chính người đang đăng nhập). Lưu trên máy theo người + quán để
  /// tải lại trang không "nhớ lại" chuyện đã làm mới.
  DateTime? _chatStartedAt;

  String? get _resetKey {
    final s = ref.read(sessionProvider);
    if (s?.userId == null || s?.storeId == null) return null;
    return 'boom_chat_reset_${s!.userId}_${s.storeId}';
  }

  Future<void> _loadChatReset() async {
    final key = _resetKey;
    if (key == null) return;
    try {
      final ms = (await SharedPreferences.getInstance()).getInt(key);
      if (ms != null && _resetKey == key) {
        _chatStartedAt = DateTime.fromMillisecondsSinceEpoch(ms);
      }
    } catch (_) {
      // không đọc được → nhớ đủ 5 giờ
    }
  }

  Future<void> _saveChatReset(DateTime at) async {
    final key = _resetKey;
    if (key == null) return;
    try {
      await (await SharedPreferences.getInstance()).setInt(
        key,
        at.millisecondsSinceEpoch,
      );
    } catch (_) {}
  }

  /// Nhãn nút gợi ý hướng dẫn → mã đoạn (bấm nút là mở đúng đoạn, không phải đoán lại từ chữ).
  final Map<String, String> _helpLabels = {};

  /// Đang trả lời → bỏ qua câu gửi thêm (bấm 2 nút gợi ý liên tiếp không làm 2 câu trả lời đè nhau).
  bool _replying = false;

  /// Tăng khi xoá cuộc trò chuyện — câu trả lời của cuộc cũ không được ghi vào cuộc mới.
  int _generation = 0;

  String _helpLabel(HelpChunk c) {
    final label = helpSuggestionLabel(c);
    _helpLabels.remove(label);
    _helpLabels[label] = c.id;
    while (_helpLabels.length > 300) {
      _helpLabels.remove(_helpLabels.keys.first); // bỏ nhãn cũ nhất
    }
    return label;
  }

  /// Thay bong bóng [id] bằng [msg]; false nếu cuộc trò chuyện đã bị xoá / bong bóng không còn.
  bool _replaceBubble(int generation, String id, BoomMessage msg) {
    if (!_mounted || generation != _generation) return false;
    final i = state.indexWhere((m) => m.id == id);
    if (i < 0) return false;
    state = [...state.sublist(0, i), msg, ...state.sublist(i + 1)];
    return true;
  }

  Future<void> _guarded(Future<void> Function() reply) async {
    if (_replying) return;
    _replying = true;
    final gen = _generation;
    try {
      await reply();
    } finally {
      if (gen == _generation) _replying = false;
    }
  }

  // Cách gọi người dùng: null = chưa chọn ("Anh/Chị"); _xungHoLoaded = đã đọc được từ máy chủ.
  String? _xungHo;
  bool _xungHoLoaded = false;

  /// Khoảng ngày của câu số nhanh (kỳ cũ hoặc kỳ dài đợt 11).
  BoomPeriodRange _rangeOf(ClassificationResult c) =>
      boomRangeOf(c.entities['time_range'] as String?, DateTime.now());

  String get _goi =>
      boomGoiNguoiDung(_xungHo, ref.read(sessionProvider)?.displayName);

  BoomMessage _greeting() {
    // Chỉ hỏi Anh / Chị khi đã đọc được là chưa chọn (lưu được lên máy chủ)
    final ask = _xungHoLoaded && _xungHo == null;
    return BoomMessage(
      content:
          'Dạ, Bé Boom chào $_goi ạ! Bé Boom có thể giúp $_goi xem doanh thu, món bán chạy, hàng sắp hết, '
          'và chỉ cách dùng app (vd: "huỷ món đã gửi bếp thế nào"). '
          '${ask ? 'Bé Boom nên gọi $_goi là Anh hay Chị ạ? (Muốn gọi khác cứ nhắn "gọi tôi là Cô / Chú / Chế…")' : '$_goi muốn hỏi gì ạ?'}',
      role: MessageRole.boom,
      suggestions: ask ? const [kBoomGoiAnh, kBoomGoiChi] : null,
    );
  }

  Future<void> _loadXungHo() async {
    final ai = ref.read(boomAiServiceProvider);
    if (ai == null || !ai.canSend) return;
    final r = await ai.getXungHo();
    if (!_mounted || !r.ok) return;
    _xungHo = r.xungHo;
    _xungHoLoaded = true;
    // Chưa ai nhắn gì → làm lại lời chào cho đúng cách gọi
    if (state.length == 1 && state.first.isBoom) state = [_greeting()];
  }

  @override
  List<BoomMessage> build() {
    ref.onDispose(() {
      _mounted = false;
    });
    // Đổi người đăng nhập trên cùng máy (giao ca) → quên cách gọi người trước, đọc lại
    ref.listen(sessionProvider.select((s) => s?.userId), (prev, next) {
      if (prev == next) return;
      _xungHo = null;
      _xungHoLoaded = false;
      clearChat(remember: false);
      Future.microtask(_loadChatReset);
    });
    // Đổi quán (cùng người): không ghép lượt trước của quán cũ vào câu hỏi ở quán mới
    ref.listen(sessionProvider.select((s) => s?.storeId), (prev, next) {
      if (prev == next) return;
      clearChat(remember: false);
      Future.microtask(_loadChatReset);
    });
    Future.microtask(_loadXungHo);
    Future.microtask(_loadChatReset);
    return [_greeting()];
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _replying) return;
    await _guarded(() async {
      // Add user message
      final userMsg = BoomMessage(content: text, role: MessageRole.user);
      state = [...state, userMsg];

      // "Gọi tôi là Anh", "gọi chế xưng bé", "gọi tôi là cô nhé"… → lưu cách gọi, không gửi GPT
      final xungHo = parseXungHoCommand(text);
      if (xungHo != null) {
        await _saveXungHo(xungHo);
        return;
      }
      await _processReply(text, sourceUserMessageId: userMsg.id);
    });
  }

  Future<void> _saveXungHo(String value) async {
    final gen = _generation;
    final ai = ref.read(boomAiServiceProvider);
    final ok = ai != null && await ai.setXungHo(value);
    if (!_mounted || gen != _generation) return;
    if (ok) _xungHo = value;
    state = [
      ...state,
      BoomMessage(
        content: ok
            ? 'Dạ, Bé Boom nhớ rồi ạ! Từ giờ Bé Boom gọi là $_goi. $_goi cần Bé Boom giúp gì ạ?'
            : 'Dạ, Bé Boom chưa lưu được ạ. $_goi thử lại sau nhé.',
        role: MessageRole.boom,
      ),
    ];
  }

  Future<void> retryLastMessage() => _guarded(_retryLastMessage);

  Future<void> _retryLastMessage() async {
    final lastUserMsg = state.lastWhere(
      (m) => m.isUser,
      orElse: () => state.first,
    );
    if (!lastUserMsg.isUser) return;

    // Remove the error message if exists
    if (state.last.isBoom && state.last.isError) {
      state = state.sublist(0, state.length - 1);
    }

    await _processReply(
      lastUserMsg.content,
      isRetry: true,
      sourceUserMessageId: lastUserMsg.id,
    );
  }

  Future<void> _processReply(
    String rawQuery, {
    bool isRetry = false,
    String? sourceUserMessageId,
  }) async {
    final generation = _generation;
    // Tìm bài / chọn đường trên câu đã chuẩn hoá teencode; GPT và nhật ký nhận câu gốc (đợt 13)
    // nút gợi ý bấm lại phải khớp nguyên văn nhãn (nhãn cắt ở "k…" — QC đợt 13)
    var query = _helpLabels.containsKey(rawQuery.trim())
        ? rawQuery
        : boomNormalizeTeen(rawQuery);
    // câu nói tiếp ngắn của câu số liệu → câu đầy đủ ("còn hôm qua?" → "doanh thu … hôm qua") — đợt 14
    final prevTurn = _lastTurn;
    if (prevTurn != null &&
        (prevTurn.shopData || prevTurn.modules || prevTurn.chain) &&
        DateTime.now().difference(prevTurn.at) < const Duration(minutes: 30)) {
      query =
          boomRewriteFollowUp(query, prevTurn.turn.question) ??
          boomCarryPeriod(query, prevTurn.turn.question) ??
          query;
    }
    final classification = IntentClassifier.classify(query);

    // Current pilot only executes direct read-only DB queries for these intents.
    // Other replies are templates/clarifications and must not be reported as model inference.
    final otherStore = boomAsksOtherStore(query);
    // Xin phân tích / báo cáo / tư vấn trên số → tư vấn kèm số liệu (bên dưới), không trả bảng số trần.
    final wantsDataAdvice = boomWantsDataAdvice(query);
    final usesReadOnlyDb =
        kBoomDataIntents.contains(classification.intent) &&
        !otherStore &&
        !boomWantsAdvice(query) &&
        !wantsDataAdvice &&
        !boomAsksHowTo(query) &&
        // "doanh thu bao nhiêu thì phải đóng thuế" là hỏi luật (bộ F, G 27/10)
        !_viHit(_taxP, _padVi(query)) &&
        // "tháng này nhập kho hết bao nhiêu tiền" → số kho; "bán giá bao nhiêu là hợp" → tư vấn (lần 6, 12)
        !({
              'revenue_summary',
              'sales_comparison',
            }.contains(classification.intent) &&
            boomModuleTopics(query).isNotEmpty &&
            !_viHit(_salesWordP, _padVi(query))) &&
        !_viHit(_priceAdviceP, _padVi(query));
    // Câu nói tiếp (trong 30 phút): tìm hướng dẫn theo cả câu trước, tư vấn kèm lượt trước.
    final last = _lastTurn;
    final followUp =
        !usesReadOnlyDb &&
            !otherStore &&
            classification.intent != 'smalltalk' &&
            last != null &&
            DateTime.now().difference(last.at) < const Duration(minutes: 30) &&
            (boomIsFollowUp(query, previous: last.turn.question) ||
                // sau lượt số liệu / tư vấn: câu ngắn không hỏi cách làm / chỗ mới mặc định là nói tiếp (bộ M 28/10:
                // người dùng nói tiếp rất nhiều kiểu — "mấy giờ đông nhất", "có cách nào tăng ko", "nói lại ngắn gọn")
                ((last.shopData || last.advice || last.modules || last.chain) &&
                    boomShortFollowUp(query, previous: last.turn.question)) ||
                boomHelpAboutPrevious(query) ||
                // sau lượt hướng dẫn: câu ngắn có chữ nối ý — chỉ dùng câu ghép khi câu này tự tìm không chắc (đợt 15)
                (!last.shopData &&
                    !last.advice &&
                    !last.modules &&
                    !last.chain &&
                    boomHelpFollowUp(query)))
        ? last
        : null;
    final helpFollowOnly =
        followUp != null &&
        (boomHelpAboutPrevious(query) ||
            (!followUp.shopData &&
                !followUp.advice &&
                !followUp.modules &&
                !followUp.chain &&
                !boomIsFollowUp(query, previous: followUp.turn.question)));
    var followUsed = false;

    // 1. Loading Phase — hiện ngay, trước khi nạp bộ hướng dẫn (tránh gửi chồng khi chờ).
    final loadingId = const Uuid().v4();
    final loadingMsg = BoomMessage(
      id: loadingId,
      content: '',
      role: MessageRole.boom,
      status: MessageStatus.loading,
    );
    state = [...state, loadingMsg];

    // Tra bộ hướng dẫn đã duyệt (trừ câu chào). Bấm mục gợi ý → mở đúng đoạn đó.
    HelpResult? help;
    var picked = false;
    var packVersion = 0;
    // Câu dài bị đoán là chào hỏi vì có "cảm ơn" ("thêm câu cảm ơn cuối hoá đơn") vẫn tra hướng dẫn.
    final longSmalltalk =
        classification.intent == 'smalltalk' &&
        query.trim().split(RegExp(r'\s+')).length >= 5;
    if (classification.intent != 'smalltalk' ||
        longSmalltalk ||
        _helpLabels.containsKey(query.trim())) {
      try {
        final index = await ref
            .read(boomHelpIndexProvider.future)
            .timeout(const Duration(seconds: 8));
        if (index != null) {
          packVersion = index.version;
          final chunk = index.byId(_helpLabels[query.trim()]);
          picked = chunk != null;
          help = chunk != null
              ? HelpResult(HelpDecision.answer, [
                  HelpHit(chunk, double.infinity),
                ])
              : decideHelp(index, query);
          // Câu nói tiếp (không có nội dung riêng) → tìm theo câu trước + câu này
          if (!picked &&
              followUp != null &&
              !(helpFollowOnly && help.decision == HelpDecision.answer)) {
            followUsed = true;
            // Lượt trước là số bán / tư vấn → tư vấn tiếp (bên dưới), không để bài hướng dẫn "cướp" câu nói tiếp
            // (hỏi cách làm về đúng thứ vừa nói thì vẫn tìm bài theo câu ghép — đợt 15)
            // lượt số theo mục / chuỗi cũng vậy ("nhập vậy có bị dư không" sau câu nhập hàng — đợt 16)
            help =
                (followUp.shopData ||
                        followUp.advice ||
                        followUp.modules ||
                        followUp.chain) &&
                    !helpFollowOnly
                ? const HelpResult(HelpDecision.none, [])
                : decideHelp(index, '${followUp.turn.question} $query');
          }
          // Chào hỏi dài: chỉ nhận khi bộ tìm chắc chắn, còn lại vẫn đáp như câu chào.
          if (longSmalltalk &&
              !picked &&
              help.decision != HelpDecision.answer) {
            help = null;
          }
        }
      } catch (_) {
        help = null;
      }
    }
    if (!_mounted) return;

    // Câu số liệu (doanh thu, bán chạy…) vẫn trả số liệu; chỉ nhường cho hướng dẫn khi bộ đoán ý không
    // chắc, hoặc câu có động từ thao tác ("tắt bán món hết", "thêm nhân viên", "in báo cáo…").
    final helpWins = boomHelpWins(
      classification: classification,
      help: help,
      query: query,
      picked: picked,
    );
    final aiForAdvice = ref.read(boomAiServiceProvider);
    final chainStore = ref.read(sessionProvider)?.storeId;
    // Câu so sánh chi nhánh (hoặc nói tiếp lượt so sánh) → đọc báo cáo chuỗi của chủ quán. Không có chuỗi / không
    // phải chủ / lỗi → đi như cũ (số nhanh của quán / hướng dẫn về Chuỗi cửa hàng).
    // Bộ hướng dẫn chưa nạp / lỗi → câu nói tiếp vẫn là nói tiếp (đặt TRƯỚC khi đọc chuỗi — QC 25/10)
    if (followUp != null && help == null) followUsed = true;
    final chainFollow = followUsed && followUp!.chain;
    final chainFacts =
        !picked &&
            aiForAdvice != null &&
            chainStore != null &&
            chainStore.isNotEmpty &&
            // Bài hướng dẫn chắc chắn + động từ thao tác ("in hoá đơn chi nhánh") → hướng dẫn, không so số
            !(helpWins && _helpAction(query)) &&
            (boomAsksChain(query) || chainFollow)
        ? await _chainFacts(
            chainStore,
            chainFollow && IntentClassifier.timeRangeIn(query) == null
                ? '${followUp.turn.question} $query'
                : query,
          )
        : null;
    if (!_mounted || generation != _generation) return;
    final usesData =
        usesReadOnlyDb &&
        chainFacts == null &&
        !helpWins &&
        !boomHelpSuggestInstead(
          classification: classification,
          help: help,
          query: query,
        );
    final selectedRoute = usesData
        ? 'rpc'
        : (helpWins ? 'rag' : 'clarification');

    final session = ref.read(sessionProvider);
    final telemetry = BoomTelemetryTrace.start(
      storeId: session?.storeId,
      userId: session?.userId,
      intent: classification.intent,
      route: selectedRoute,
    );

    await Future.delayed(const Duration(milliseconds: 600));
    if (!_mounted) return;

    // Lấy thông tin session thực tế
    final storeId = session?.storeId;

    String fullReply = classification.intent == 'smalltalk'
        ? boomSmalltalkReply(query, _goi)
        : 'Bé Boom chưa hiểu rõ lắm ạ. $_goi có thể hỏi về "doanh thu hôm nay" hoặc "món bán chạy" được không ạ?';
    List<String>? suggestions;
    String? completedTool;
    int toolLatencyMs = 0;
    bool queryFailed = false;
    final processingTimer = Stopwatch()..start();

    // 2a. Trả lời bằng hướng dẫn: GPT (qua máy chủ) dựa trên 1–3 đoạn liên quan; GPT lỗi / chưa bật / hết hạn mức
    // → nguyên văn đoạn đã duyệt. Không có đoạn nào → GPT tư vấn kinh doanh (chế độ 'advice'); chưa bật / lỗi
    // → ghi sổ "chưa trả lời được" (hàng chờ cải thiện). Câu ngoài phạm vi → máy chủ trả câu từ chối.
    String helpTool = 'huong_dan_none';
    // Câu trả lời đến từ máy chủ (máy chủ tự ghi lịch sử nguyên văn cho trang quản trị)
    var serverWrote = false;
    String? aiLogId;
    final history = followUsed && followUp != null
        ? BoomTurn(
            followUp.raw.isEmpty ? followUp.turn.question : followUp.raw,
            followUp.turn.answer,
          )
        : null;
    final dataAdvice =
        !usesData &&
        !otherStore &&
        !picked &&
        // Câu xin phân tích không có động từ thao tác ("báo cáo xem", "phân tích giúp") thắng cả bài hướng dẫn
        // "Báo cáo" (bộ tìm hay khớp chữ "báo cáo"); câu hỏi cách làm ("xuất báo cáo thế nào") vẫn đi hướng dẫn.
        ((wantsDataAdvice && (!helpWins || !_helpAction(query))) ||
            (followUsed && followUp!.shopData && !helpFollowOnly) ||
            (boomMentionsShopBusiness(query) &&
                !helpWins &&
                !_helpAction(query) &&
                !boomAsksHowTo(query) &&
                !boomGeneralKnowledge(query)) ||
            // đã khớp một mục (lương, ca, khách…) → để nhánh số theo mục đọc, khỏi đọc thêm số bán
            ((boomAsksShopNumber(query) || boomAsksPeriodMetric(query)) &&
                boomModuleTopics(query).isEmpty));
    // Câu xin số các module (thu chi, kho, nhân sự, khách, khuyến mãi) → đọc CHỈ ĐỌC theo quyền của người hỏi
    final moduleFollow = followUsed && followUp!.modules && !helpFollowOnly;
    final topics =
        chainFacts == null &&
            !usesData &&
            !otherStore &&
            !picked &&
            !(helpWins && _helpAction(query)) &&
            aiForAdvice != null &&
            storeId != null &&
            storeId.isNotEmpty
        // câu nói tiếp ("đề xuất giúp cách cắt giảm") → mục theo câu trước; ghép hai câu thì chữ "cách" làm mất mục
        ? (moduleFollow && boomModuleTopics(query).isEmpty
              ? boomModuleTopics(followUp.turn.question)
              : boomModuleTopics(query))
        : const <BoomModule>{};
    final mod = topics.isEmpty
        ? null
        : await (ref.read(boomModuleLoaderProvider) ?? _moduleFacts)(
            storeId!,
            topics,
            // kỳ: câu đang hỏi trước ("còn tháng trước thì sao"), rồi mới tới câu trước
            moduleFollow && IntentClassifier.timeRangeIn(query) == null
                ? '${followUp.turn.question} $query'
                : query,
          );
    if (!_mounted || generation != _generation) return;
    final modFacts = mod == null || mod.facts.isEmpty ? null : mod.facts;
    if (chainFacts != null) {
      final reply = await aiForAdvice!.advise(
        storeId: storeId!,
        question: rawQuery,
        chain: chainFacts,
        history: history,
        memorySince: _chatStartedAt,
      );
      if (!_mounted || generation != _generation) return;
      if (reply != null && !reply.blocked) {
        fullReply = reply.answer;
        serverWrote = true;
        aiLogId = reply.logId;
        helpTool = 'boom_tu_van_so_lieu_chuoi';
      } else if (reply != null) {
        fullReply = reply.answer;
        serverWrote = true;
        helpTool = 'boom_tu_choi';
      } else {
        aiForAdvice.logUnanswered(storeId: storeId, question: rawQuery);
        helpTool = 'boom_so_lieu_chuoi_du_phong';
        fullReply =
            '${_chainText(chainFacts)}\nBé Boom chưa phân tích được câu này lúc này ạ.';
      }
      suggestions = [
        'Chi nhánh nào cần cải thiện?',
        'So sánh chi nhánh tháng trước',
      ];
    } else if (otherStore) {
      fullReply = kBoomOtherStoreRefusal;
      helpTool = 'boom_tu_choi';
    } else if (mod != null &&
        modFacts == null &&
        mod.denied.isEmpty &&
        _modulePermsFailed &&
        !dataAdvice) {
      fullReply =
          'Bé Boom chưa kiểm tra được quyền xem số liệu lúc này. $_goi thử lại sau một chút nhé!';
    } else if (mod != null &&
        modFacts == null &&
        mod.denied.isNotEmpty &&
        // Bài hướng dẫn khớp chắc chắn + động từ thao tác → để hướng dẫn trả lời, không chặn
        !(helpWins && _helpAction(query)) &&
        !dataAdvice) {
      // Không có quyền xem mục đó trong app → nói rõ, không gọi GPT, không đọc số
      final names = [
        for (final m in mod.denied) kBoomModuleNames[m],
      ].join(', ');
      final boss = ref.read(sessionProvider)?.isOwner == true;
      fullReply = boss
          ? 'Bé Boom chưa xem được số liệu $names: mục này đang tắt ở quán (bật trong phần chọn module của app) '
                'hoặc Bé Boom chưa đọc được lúc này ạ.'
          : 'Bé Boom chưa xem được số liệu $names vì tài khoản của $_goi chưa được mở mục này trong app. '
                '$_goi nhờ chủ quán hoặc quản lý xem giúp, hoặc xin cấp quyền nhé ạ.';
      helpTool = 'boom_khong_quyen';
    } else if (dataAdvice &&
        aiForAdvice != null &&
        storeId != null &&
        storeId.isNotEmpty) {
      // Tư vấn trên số liệu thật: đọc số (chỉ đọc) → GPT phân tích. GPT chưa bật / lỗi → hiện số đã đọc.
      // câu nói tiếp: không tự nói kỳ → kỳ của câu trước; có kỳ → kỳ của câu này (ghép hai câu dễ ra hai kỳ / "từng
      // ngày" bị coi là kỳ lạ → rơi về tháng này) — đợt 14
      final ownRange = IntentClassifier.timeRangeIn(query);
      final factsQuery = !followUsed
          ? query
          : ownRange == null || ownRange == 'unsupported'
          ? followUp!.turn.question
          : query;
      // Nhân viên không được xem Báo cáo → tư vấn chung, không kèm số bán hàng
      final salesPerms = await _perms(storeId);
      if (!_mounted || generation != _generation) return;
      final facts = salesPerms == null || !boomCanSeeSales(salesPerms)
          ? null
          : await _shopFacts(
              storeId,
              factsQuery,
              followUsed
                  ? IntentClassifier.classify(factsQuery)
                  : classification,
            );
      if (!_mounted || generation != _generation) return;
      final reply = await aiForAdvice.advise(
        storeId: storeId,
        question: rawQuery,
        facts: facts,
        modules: modFacts,
        history: history,
        memorySince: _chatStartedAt,
      );
      if (!_mounted || generation != _generation) return;
      if (reply != null && !reply.blocked) {
        fullReply = reply.answer;
        serverWrote = true;
        aiLogId = reply.logId;
        helpTool = reply.cached
            ? 'boom_tu_van_cache'
            : modFacts != null
            ? 'boom_tu_van_so_lieu_module'
            : 'boom_tu_van_so_lieu';
      } else if (reply != null) {
        fullReply = reply.answer;
        serverWrote = true;
        helpTool = 'boom_tu_choi';
      } else {
        // GPT chưa bật / hết lượt / lỗi → hiện số đã đọc + ghi hàng chờ cải thiện
        aiForAdvice.logUnanswered(storeId: storeId, question: rawQuery);
        helpTool = 'boom_so_lieu_du_phong';
        fullReply = facts == null
            ? (salesPerms != null && !boomCanSeeSales(salesPerms)
                  ? 'Bé Boom chưa trả lời được câu này lúc này. $_goi thử lại sau một chút nhé!'
                  : 'Bé Boom chưa đọc được số liệu của quán lúc này. $_goi thử lại sau một chút nhé!')
            : '${_factsText(facts)}\nBé Boom chưa phân tích được câu này lúc này ạ.';
      }
      suggestions = ['Món nào bán ế?', 'Doanh thu tháng này?'];
    } else if (modFacts != null) {
      // Phân tích số module (đã kiểm quyền). GPT chưa bật / lỗi → hiện số chính đã đọc.
      final reply = await aiForAdvice!.advise(
        storeId: storeId!,
        question: rawQuery,
        modules: modFacts,
        history: history,
        memorySince: _chatStartedAt,
      );
      if (!_mounted || generation != _generation) return;
      if (reply != null && !reply.blocked) {
        fullReply = reply.answer;
        serverWrote = true;
        aiLogId = reply.logId;
        helpTool = 'boom_tu_van_so_lieu_module';
      } else if (reply != null) {
        fullReply = reply.answer;
        serverWrote = true;
        helpTool = 'boom_tu_choi';
      } else {
        aiForAdvice.logUnanswered(storeId: storeId, question: rawQuery);
        helpTool = 'boom_so_lieu_module_du_phong';
        fullReply =
            '${boomModulesText(modFacts, _formatCurrency)}\nBé Boom chưa phân tích được câu này lúc này ạ.';
      }
      if (mod!.denied.isNotEmpty) {
        fullReply +=
            '\n(Phần ${[for (final m in mod.denied) kBoomModuleNames[m]].join(', ')}: tài khoản này chưa được xem.)';
      }
    } else if (help != null && !usesData) {
      final ai = ref.read(boomAiServiceProvider);
      final canAsk =
          ai != null && storeId != null && storeId.isNotEmpty && !picked;
      // Bộ tìm chưa chắc nhưng có đoạn khá gần → vẫn đưa GPT 3 đoạn đầu (kiểm tra 24/10: nhiều câu hỏi app bị bỏ
      // dù đoạn đúng nằm trong top 3 với điểm cao).
      final weakHits =
          canAsk &&
          help.decision == HelpDecision.none &&
          help.hits.isNotEmpty &&
          help.hits.first.score >= kHelpWeakScore;
      // Bộ tìm chưa chắc + câu kiến thức nghề / đời sống (công thức, luật lao động, thiết bị…) → tư vấn (xem
      // boomGeneralKnowledge); câu hỏi app vẫn hỏi GPT kèm các đoạn hướng dẫn gần nhất.
      if (helpWins ||
          ((help.decision != HelpDecision.none || weakHits) &&
              !boomGeneralKnowledge(query))) {
        final ctx = helpChunksForGpt(help, sure: helpWins);
        final answered = canAsk
            ? await ai.ask(
                storeId: storeId,
                question: rawQuery,
                chunks: ctx,
                packVersion: packVersion,
              )
            : null;
        if (!_mounted || generation != _generation) return;
        // GPT từ chối câu đã có bài hướng dẫn chắc chắn → vẫn đưa bài đã duyệt (nguyên văn).
        final reply = answered != null && answered.blocked && helpWins
            ? null
            : answered;
        if (reply != null && reply.blocked) {
          fullReply = reply.answer;
          serverWrote = true;
          helpTool = 'boom_tu_choi';
        } else if (reply != null) {
          // Chủ Quán 24/10: không gắn dòng "— Theo hướng dẫn: …" (nguồn vẫn mở được qua nút gợi ý)
          fullReply = reply.answer;
          serverWrote = true;
          aiLogId = reply.logId;
          // Chắc chắn: gợi ý các mục chưa dùng; GPT chọn giữa nhiều mục: vẫn cho mở nguyên văn từng mục.
          // Không còn dòng nguồn → nút đầu luôn mở đúng bài GPT dựa vào (chắc chắn) / các mục để chọn
          suggestions = [
            for (final h in help.hits)
              if (!helpWins ||
                  h.chunk == help.hits.first.chunk ||
                  !ctx.contains(h.chunk))
                _helpLabel(h.chunk),
          ];
          // Câu từ bộ nhớ đã duyệt đếm riêng (không phải lượt gọi GPT)
          helpTool = reply.cached ? 'huong_dan_cache' : 'huong_dan_gpt';
        } else if (helpWins) {
          final top = help.hits.first.chunk;
          fullReply = formatHelpAnswer(top);
          suggestions = [
            for (final h in help.hits.skip(1))
              if (h.chunk.id != top.id) _helpLabel(h.chunk),
          ];
          if (suggestions.isNotEmpty) {
            fullReply += '\nChưa đúng ý $_goi? Chọn mục gần nhất bên dưới ạ.';
          }
          helpTool = 'huong_dan';
        } else if (weakHits) {
          // GPT lỗi / hết lượt với đoạn chỉ gần đúng → như câu chưa có hướng dẫn
          ai.logUnanswered(storeId: storeId, question: rawQuery);
        } else {
          fullReply =
              'Bé Boom chưa chắc $_goi hỏi phần nào. Có phải một trong các mục dưới đây không ạ? '
              'Bấm vào để xem hướng dẫn.';
          suggestions = [for (final h in help.hits) _helpLabel(h.chunk)];
          helpTool = 'huong_dan_suggest';
        }
      } else if (canAsk) {
        final reply = await ai.advise(
          storeId: storeId,
          question: rawQuery,
          history: history,
          memorySince: _chatStartedAt,
        );
        if (!_mounted || generation != _generation) return;
        if (reply == null) {
          ai.logUnanswered(storeId: storeId, question: rawQuery);
        } else if (reply.blocked) {
          fullReply = reply.answer;
          serverWrote = true;
          helpTool = 'boom_tu_choi';
        } else {
          fullReply = reply.answer;
          serverWrote = true;
          aiLogId = reply.logId;
          helpTool = reply.cached ? 'boom_tu_van_cache' : 'boom_tu_van';
        }
      }
    }

    // 2b. Chỉ đọc dữ liệu thật qua cổng chuyên dụng của AI Boom.
    if (usesData) {
      try {
        if (storeId == null || storeId.isEmpty) {
          throw StateError('MISSING_STORE_CONTEXT');
        }
        // Chỉ trả số người hỏi được xem trong app (máy chủ chỉ chặn theo quán, không theo vai trò — QC 25/10)
        final perms = await _perms(storeId);
        if (!_mounted || generation != _generation) return;
        final blockedModule = switch (classification.intent) {
          'low_stock' || 'purchase_forecast' =>
            perms != null && boomCanSeeStock(perms) ? null : 'Kho hàng',
          'staff_on_shift' =>
            perms != null && boomCanSeeShifts(perms) ? null : 'Chấm công',
          _ => perms != null && boomCanSeeSales(perms) ? null : 'Báo cáo',
        };
        late final readOnlyData =
            ref.read(boomReadOnlyDataProvider) ??
            BoomReadOnlyDataService(Supabase.instance.client);
        final storeName = session?.storeName?.trim().isNotEmpty == true
            ? session!.storeName!.trim()
            : 'quán';

        if (blockedModule != null) {
          // Không đọc được quyền (mạng / máy chủ chậm) ≠ không có quyền
          fullReply = perms == null
              ? 'Bé Boom chưa kiểm tra được quyền xem số liệu lúc này. $_goi thử lại sau một chút nhé!'
              : 'Bé Boom chưa xem được số liệu $blockedModule vì tài khoản của $_goi chưa được mở mục này trong app. '
                    '$_goi nhờ chủ quán hoặc quản lý xem giúp, hoặc xin cấp quyền nhé ạ.';
        } else if ((classification.entities['time_range'] == 'unsupported' &&
                const {
                  'revenue_summary',
                  'sales_comparison',
                  'top_products',
                  'slow_products',
                }.contains(classification.intent)) ||
            // xếp hạng món đọc từng món của mọi đơn → tối đa 92 ngày (đợt 11)
            (const {
                  'top_products',
                  'slow_products',
                }.contains(classification.intent) &&
                _rangeOf(
                      classification,
                    ).end.difference(_rangeOf(classification).start).inDays >
                    92)) {
          // Kỳ Boom chưa đọc được ("hôm kia", "20/10", "tháng 5 năm ngoái") — nói rõ, không trả nhầm số hôm nay.
          fullReply =
              'Bé Boom xem được số liệu theo: hôm nay, hôm qua, tuần này / trước, tháng này / trước, tháng N, '
              'quý, N ngày gần đây (tối đa 92 ngày) và doanh thu cả năm. Kỳ khác $_goi xem ở màn Báo cáo nhé.';
          suggestions = ['Doanh thu tháng này?', 'Doanh thu tháng trước?'];
          // Không phải lượt đọc dữ liệu: không ghi "tool_completed" (không làm đẹp số liệu đo lường)
        } else if (classification.intent == 'revenue_summary' ||
            classification.intent == 'sales_comparison') {
          final toolTimer = Stopwatch()..start();
          final period = boomPeriodFrom(
            classification.entities['time_range'] as String?,
          );
          final summary = await readOnlyData.getRevenueSummary(
            storeId,
            period,
            range: _rangeOf(classification),
          );
          final label = summary.range.label;
          final prev = summary.range.prevLabel;
          final change = summary.changePercent;
          final comparison = change == null
              ? (summary.previousOrderCount == 0
                    ? 'Chưa có doanh thu $prev để so sánh.'
                    : '')
              : 'So với $prev (${_formatCurrency(summary.previousRevenue)}): '
                    '${change >= 0 ? 'tăng' : 'giảm'} ${change.abs().toStringAsFixed(1)}%.';
          fullReply = summary.orderCount > 0
              ? '$label $storeName đạt ${_formatCurrency(summary.revenue)} từ ${summary.orderCount} đơn hoàn thành, '
                    'trung bình ${_formatCurrency(summary.averageOrderValue)}/đơn. $comparison'
              : '$label $storeName chưa có đơn hoàn thành. $comparison';
          fullReply = fullReply.trim();
          suggestions = [
            if (period != BoomPeriod.thisMonth) 'Doanh thu tháng này?',
            if (period != BoomPeriod.today) 'Doanh thu hôm nay?',
            'Món nào bán chạy nhất tháng này?',
          ];
          toolTimer.stop();
          completedTool = 'orders_summary_read_only';
          toolLatencyMs = toolTimer.elapsedMilliseconds;
        } else if (classification.intent == 'top_products') {
          final toolTimer = Stopwatch()..start();
          final period = boomPeriodFrom(
            classification.entities['time_range'] as String?,
          );
          final range = _rangeOf(classification);
          final label = range.label;
          final performance = await readOnlyData.getProductPerformance(
            storeId,
            period: period,
            range: range,
          );
          final soldItems = performance.top
              .where((item) => item.quantity > 0)
              .toList();
          if (soldItems.isNotEmpty) {
            final details = soldItems
                .map(
                  (item) =>
                      '${item.name} (${_formatQuantity(item.quantity)} món, ${_formatCurrency(item.revenue)})',
                )
                .join('; ');
            fullReply =
                'Món bán chạy — $label của $storeName: $details. Tổng hợp từ ${performance.completedOrderCount} đơn hoàn thành.';
          } else {
            fullReply =
                '$label chưa có món nào trong đơn hoàn thành nên Bé Boom chưa xếp hạng món bán chạy.';
          }
          suggestions = ['Món nào bán ế?', 'Hôm nay ai đang làm?'];
          toolTimer.stop();
          completedTool = 'top_products_read_only';
          toolLatencyMs = toolTimer.elapsedMilliseconds;
        } else if (classification.intent == 'slow_products') {
          final toolTimer = Stopwatch()..start();
          final period = boomPeriodFrom(
            classification.entities['time_range'] as String?,
          );
          final range = _rangeOf(classification);
          final label = range.label;
          final performance = await readOnlyData.getProductPerformance(
            storeId,
            period: period,
            range: range,
          );
          if (performance.slow.isNotEmpty) {
            final details = performance.slow
                .map(
                  (item) =>
                      '${item.name} (${_formatQuantity(item.quantity)} món)',
                )
                .join('; ');
            fullReply =
                'Các món bán chậm nhất — $label: $details. Gợi ý: ưu tiên kiểm tra vị trí hiển thị hoặc tạo combo, nhưng Bé Boom sẽ không tự thay đổi menu hay giá.';
          } else {
            fullReply =
                'Chưa có sản phẩm đang hoạt động để phân tích bán chậm.';
          }
          suggestions = ['Hôm nay ai đang làm?', 'Kho có gì sắp hết?'];
          toolTimer.stop();
          completedTool = 'slow_products_read_only';
          toolLatencyMs = toolTimer.elapsedMilliseconds;
        } else if (classification.intent == 'low_stock' ||
            classification.intent == 'purchase_forecast') {
          final toolTimer = Stopwatch()..start();
          final alerts = await readOnlyData.getLowStock(storeId);
          fullReply = boomStockReply(
            alerts,
            forecast: classification.intent == 'purchase_forecast',
            qty: _formatQuantity,
          );
          suggestions = ['Hôm nay ai đang làm?', 'Món nào bán chạy nhất?'];
          toolTimer.stop();
          completedTool = '${classification.intent}_read_only';
          toolLatencyMs = toolTimer.elapsedMilliseconds;
        } else if (classification.intent == 'staff_on_shift') {
          final toolTimer = Stopwatch()..start();
          final shift = await readOnlyData.getStaffOnShift(storeId);
          if (shift.count == 0) {
            fullReply =
                'Hiện chưa có ca đang mở được ghi nhận trong dữ liệu chấm công hôm nay.';
          } else if (shift.names.isEmpty) {
            fullReply = 'Hiện có ${shift.count} nhân sự đang trong ca.';
          } else {
            fullReply =
                'Hiện có ${shift.count} nhân sự đang trong ca: ${shift.names.join(', ')}.';
          }
          suggestions = ['Doanh thu hôm nay?', 'Kho có gì sắp hết?'];
          toolTimer.stop();
          completedTool = 'staff_on_shift_read_only';
          toolLatencyMs = toolTimer.elapsedMilliseconds;
        }
      } catch (_) {
        queryFailed = true;
        // Fallback minh bạch: không tuyên bố đã kiểm tra khi truy vấn dữ liệu thất bại.
        fullReply =
            'Bé Boom chưa kết nối được dữ liệu của quán lúc này. $_goi thử lại sau một chút nhé!';
        suggestions = ['Món nào bán chạy nhất?', 'Kho có gì sắp hết?'];
      }
    }

    processingTimer.stop();
    if (help != null && !usesData) {
      telemetry?.emit(
        eventName: 'response_completed',
        route: selectedRoute,
        latencyMs: processingTimer.elapsedMilliseconds,
        hasRagSource: const {
          'huong_dan',
          'huong_dan_gpt',
          'huong_dan_cache',
        }.contains(helpTool),
        toolName: helpTool,
      );
    }
    if (completedTool != null && !queryFailed) {
      telemetry?.emit(
        eventName: 'tool_completed',
        route: 'rpc',
        latencyMs: processingTimer.elapsedMilliseconds,
        toolLatencyMs: toolLatencyMs,
        hasToolSource: true,
        toolName: completedTool,
      );
    }
    if (queryFailed) {
      telemetry?.emit(
        eventName: 'response_failed',
        route: selectedRoute,
        status: 'error',
        errorCode: 'SUPABASE_QUERY_FAILED',
        latencyMs: processingTimer.elapsedMilliseconds,
        toolLatencyMs: toolLatencyMs,
      );
    }
    if (help == null || usesData) {
      telemetry?.emit(
        eventName: 'response_completed',
        route: queryFailed ? 'clarification' : selectedRoute,
        latencyMs: processingTimer.elapsedMilliseconds,
        toolLatencyMs: toolLatencyMs,
        hasToolSource: completedTool != null && !queryFailed,
        fallbackUsed: queryFailed,
        toolName: completedTool,
      );
    }

    if (generation != _generation) return;
    final salesData =
        usesData &&
        !queryFailed &&
        completedTool != null &&
        const {
          'revenue_summary',
          'sales_comparison',
          'top_products',
          'slow_products',
        }.contains(classification.intent);
    final gptTurn =
        aiLogId != null &&
        (helpTool.startsWith('huong_dan_gpt') ||
            helpTool.startsWith('boom_tu_van'));
    _lastTurn = salesData || gptTurn
        ? _LastTurn(
            // Lượt có số module / chuỗi: không gửi lại câu trả lời (số) — câu nói tiếp đọc lại số (QC 25/10)
            BoomTurn(
              query,
              salesData ||
                      helpTool.contains('_module') ||
                      helpTool.contains('_chuoi')
                  ? ''
                  : fullReply,
            ),
            salesData || dataAdvice,
            DateTime.now(),
            advice: helpTool.startsWith('boom_tu_van'),
            chain: helpTool == 'boom_tu_van_so_lieu_chuoi',
            modules: helpTool == 'boom_tu_van_so_lieu_module',
            raw: rawQuery,
          )
        : null;

    // Câu app tự trả (số liệu nhanh, hướng dẫn nguyên văn, chào hỏi, từ chối tại máy…) → ghi lịch sử nguyên văn cho
    // trang quản trị (Chủ Quán 25/10: xem toàn bộ trò chuyện với Boom). Không chờ, lỗi bỏ qua.
    if (!serverWrote &&
        storeId != null &&
        storeId.isNotEmpty &&
        fullReply.trim().isNotEmpty) {
      ref
          .read(boomAiServiceProvider)
          ?.transcript(
            storeId: storeId,
            question: rawQuery,
            answer: fullReply,
            tool: completedTool ?? helpTool,
          );
    }

    // 3. Streaming word by word
    final words = fullReply.split(' ');
    String currentText = '';
    final stepMs = words.length > 30 ? (1500 ~/ words.length).clamp(4, 50) : 50;

    for (int i = 0; i < words.length; i++) {
      currentText += (i == 0 ? '' : ' ') + words[i];
      final shown = _replaceBubble(
        generation,
        loadingId,
        BoomMessage(
          id: loadingId,
          content: currentText,
          role: MessageRole.boom,
          status: MessageStatus.streaming,
        ),
      );
      if (!shown) return;
      await Future.delayed(Duration(milliseconds: stepMs));
      if (!_mounted) return;
    }

    // 4. Completed Phase
    final Map<String, dynamic>? evidenceRef = completedTool != null
        ? {
            'tool_name': completedTool,
            'latency_ms': toolLatencyMs,
            'status': queryFailed ? 'error' : 'success',
            'route': selectedRoute,
          }
        : (helpTool == 'huong_dan' ||
              helpTool == 'huong_dan_gpt' ||
              helpTool == 'huong_dan_cache')
        ? {
            // Máy chủ phản hồi chỉ giữ 6 khoá (tool_name, latency_ms, route, status, intent, query_id)
            // → mã mục đi kèm trong tool_name để biết câu bị chê là mục nào.
            'tool_name': '$helpTool:${help!.hits.first.chunk.id}',
            'chunk_id': help.hits.first.chunk.id,
            'query_id': ?aiLogId,
            'status': 'success',
            'route': 'rag',
          }
        : helpTool.startsWith('boom_tu_van') ||
              helpTool == 'boom_so_lieu_du_phong' ||
              helpTool == 'boom_so_lieu_chuoi_du_phong' ||
              helpTool == 'boom_so_lieu_module_du_phong'
        ? {
            'tool_name': helpTool,
            'query_id': ?aiLogId,
            'status': 'success',
            'route': 'rag',
          }
        : null;

    _replaceBubble(
      generation,
      loadingId,
      BoomMessage(
        id: loadingId,
        content: fullReply,
        role: MessageRole.boom,
        status: MessageStatus.completed,
        suggestions: suggestions,
        evidenceReference: evidenceRef,
        sourceMessageId: sourceUserMessageId,
      ),
    );
  }

  Future<Map<String, dynamic>> submitFeedbackForMessage(
    String messageId, {
    required String rating,
    String? reasonCode,
    String? proposedAnswer,
  }) async {
    final idx = state.indexWhere((m) => m.id == messageId);
    if (idx == -1) return {'success': false, 'error': 'MESSAGE_NOT_FOUND'};

    final targetMsg = state[idx];

    // QC Item 8: Duplicate tap prevention! Ignore if submitting or already submitted
    if (targetMsg.isFeedbackSubmitting || targetMsg.isFeedbackSubmitted) {
      return {'success': false, 'error': 'ALREADY_SUBMITTING_OR_SUBMITTED'};
    }

    // Step 1: Transition to submitting
    final submittingMsg = targetMsg.copyWith(
      feedbackRating: rating,
      feedbackReason: reasonCode,
      proposedAnswer: proposedAnswer,
      feedbackStatus: 'submitting',
    );
    _updateMessageInState(idx, submittingMsg);

    final session = ref.read(sessionProvider);
    final storeId = session?.storeId;

    // QC Item 4: Fail-closed if storeId is missing/empty!
    if (storeId == null || storeId.trim().isEmpty) {
      final failedMsg = submittingMsg.copyWith(feedbackStatus: 'failed');
      _updateMessageInState(idx, failedMsg);
      return {'success': false, 'error': 'MISSING_STORE_CONTEXT'};
    }

    // Find actual user query content
    final userMsgIndex = state.indexWhere(
      (m) => m.id == targetMsg.sourceMessageId,
    );
    final userQuery = userMsgIndex != -1
        ? state[userMsgIndex].content
        : 'Query';

    // 👍/👎 vào sổ hỏi đáp của quán (mọi nhân viên chấm được, không cần ghép nối thiết bị): câu GPT / bộ nhớ →
    // chấm vào dòng đã có; câu không gọi GPT (số liệu, hướng dẫn nguyên văn, từ chối) → máy chủ ghi dòng 'feedback'.
    final ai = ref.read(boomAiServiceProvider);
    final qaLogId = targetMsg.evidenceReference?['query_id'] as String?;
    final up = rating == 'thumbs_up';
    // Lý do + câu trả lời đúng người dùng đề xuất (máy chủ giữ tối đa 300 ký tự)
    var reason = [
      ?reasonCode,
      if (proposedAnswer != null && proposedAnswer.trim().isNotEmpty)
        'đề xuất: ${proposedAnswer.trim()}',
    ].join(' — ');
    if (reason.runes.length > 300) {
      reason = String.fromCharCodes(reason.runes.take(300));
    }
    Future<bool> asFeedback() => ai!.feedback(
      storeId: storeId,
      question: userQuery,
      answer: targetMsg.content,
      up: up,
      reason: reason.isEmpty ? null : reason,
      tool: targetMsg.evidenceReference?['tool_name'] as String?,
    );
    final savedToQaLog = ai == null
        ? false
        : qaLogId != null
        // Câu GPT / bộ nhớ: chấm vào dòng đã có; không chấm được (người khác hỏi, quá 7 ngày) → ghi dòng riêng
        ? (await ai.rate(
                qaLogId,
                up: up,
                reason: reason.isEmpty ? null : reason,
              ) ||
              await asFeedback())
        : await asFeedback();
    if (!_mounted) return {'success': savedToQaLog};
    // Đã vào sổ hỏi đáp → xong.
    if (savedToQaLog) {
      _updateMessageInState(
        idx,
        submittingMsg.copyWith(feedbackStatus: 'submitted'),
      );
      return {'success': true, 'saved': 'boom_qa_log'};
    }
    // Chưa ghi được (mất mạng, hết lượt, máy chưa đăng nhập bằng vé thật…) → báo chưa gửi để bấm lại.
    // Đường phản hồi cũ qua máy chủ thử nghiệm BunServer (đòi "ghép nối thiết bị") đã gỡ 24/10/2026.
    _updateMessageInState(
      idx,
      submittingMsg.copyWith(feedbackStatus: 'failed'),
    );
    return {
      'success': false,
      'error': ai != null && ai.canSend
          ? 'QA_LOG_UNAVAILABLE'
          : 'NOT_SIGNED_IN',
    };
  }

  /// Cập nhật tin nhắn; [idx] có thể đã cũ sau một lần chờ mạng (xoá cuộc trò chuyện…) → tìm lại theo id,
  /// không thấy thì bỏ qua.
  void _updateMessageInState(int idx, BoomMessage msg) {
    var i = idx;
    if (i < 0 || i >= state.length || state[i].id != msg.id) {
      i = state.indexWhere((m) => m.id == msg.id);
      if (i == -1) return;
    }
    final newList = List<BoomMessage>.from(state);
    newList[i] = msg;
    state = newList;
  }

  String _formatCurrency(num amount) {
    return '${amount.toStringAsFixed(0).replaceAll(RegExp(r'\B(?=(\d{3})+(?!\d))'), '.')}đ';
  }

  String _formatQuantity(num quantity) => quantity % 1 == 0
      ? quantity.toInt().toString()
      : quantity.toStringAsFixed(1);

  /// Số liệu gửi GPT khi tư vấn: doanh thu kỳ + so kỳ trước + tối đa 5 món bán chạy / 5 món bán chậm.
  /// Lỗi đọc → null (GPT tư vấn chung, không bịa số).
  /// Báo cáo chuỗi chứa quán đang mở (máy chủ chỉ trả cho CHỦ chuỗi): kỳ trong câu (mặc định tháng này) + kỳ trước.
  /// Không có chuỗi / không phải chủ / lỗi / quá chậm → null.
  Future<Map<String, dynamic>?> _chainFacts(
    String storeId,
    String query,
  ) async {
    try {
      final repo = ChainRepository();
      final mine = await repo.listMine().timeout(const Duration(seconds: 5));
      // Chỉ chuỗi CHỨA quán đang mở: đứng ở quán người khác thì không đọc chuỗi của mình (sổ hỏi đáp ghi theo quán
      // đang mở, quản lý quán đó đọc được — QC 25/10)
      final chain = mine.chains
          .where((c) => c.stores.any((s) => s.storeId == storeId))
          .firstOrNull;
      if (chain == null) return null;
      // "doanh thu 2 quán" → bỏ dấu thành "thu 2" giống "thứ 2" → bộ đọc kỳ tưởng là thứ trong tuần (QC 25/10)
      final tr = IntentClassifier.timeRangeIn(
        query.replaceAll(
          RegExp(
            r'\d+\s*(?:quán|chi nhánh|cửa hàng|cơ sở|quan|chi nhanh|cua hang|co so)',
            caseSensitive: false,
          ),
          ' ',
        ),
      );
      final known = tr != null && tr != 'unsupported' && tr != 'current_shift';
      final range = known
          ? boomRangeOf(tr, DateTime.now())
          : boomPeriodRange(BoomPeriod.thisMonth, DateTime.now());
      // Đúng 0 giờ đầu kỳ → kỳ rỗng (máy chủ báo INVALID_RANGE)
      if (!range.end.isAfter(range.start)) return null;
      // Kỳ trước chậm / lỗi → vẫn so sánh kỳ này
      final prevF = range.prevEnd.isAfter(range.prevStart)
          ? repo
                .report(chain.id, range.prevStart, range.prevEnd)
                .timeout(const Duration(seconds: 8))
                .then<ChainReport?>((r) => r, onError: (_) => null)
          : Future<ChainReport?>.value();
      final cur = await repo
          .report(chain.id, range.start, range.end)
          .timeout(const Duration(seconds: 8));
      final prev = await prevF;
      if (cur.stores.isEmpty) return null;
      final before = {
        for (final s in prev?.stores ?? <StoreMetrics>[]) s.storeId: s,
      };
      // Doanh thu theo thứ từng chi nhánh (từ số theo ngày) — chỉ kỳ ≥ 7 ngày: kỳ ngắn hơn có thứ chưa tới, máy
      // chủ sẽ tưởng quán nghỉ (QC 25/10)
      final byDay = range.end.difference(range.start).inDays >= 7;
      final weekday = <String, List<double>>{};
      for (final d in byDay ? cur.daily : const <ChainDailyPoint>[]) {
        final day = DateTime.tryParse(d.date);
        if (day == null) continue;
        (weekday[d.storeId] ??= List.filled(7, 0.0))[day.weekday - 1] +=
            d.revenue;
      }
      // > 12 quán: giữ 6 cao nhất + 5 thấp nhất + quán đang mở (danh sách đã xếp doanh thu giảm dần)
      var list = cur.stores;
      if (list.length > 12) {
        final keep = {
          ...list.take(6),
          ...list.skip(list.length - 5),
          ...list.where((s) => s.storeId == storeId),
        };
        list = [
          for (final s in cur.stores)
            if (keep.contains(s)) s,
        ];
      }
      // Tên trùng ("Quán Nhỏ", "Quán Nhỏ") → thêm mã quán để GPT phân biệt
      final dup = <String, int>{};
      for (final s in list) {
        dup[s.name.trim().toLowerCase()] =
            (dup[s.name.trim().toLowerCase()] ?? 0) + 1;
      }
      String label(StoreMetrics s) =>
          (dup[s.name.trim().toLowerCase()] ?? 0) > 1 && s.storeCode.isNotEmpty
          ? '${s.name} (mã ${s.storeCode})'
          : s.name;
      return {
        'name': cur.chainName.isEmpty ? chain.name : cur.chainName,
        'period': tr == 'unsupported'
            ? '${range.label} — kỳ trong câu Boom chưa đọc được'
            : range.label,
        if (prev != null) 'prev_period': range.prevLabel,
        'stores': [
          for (final s in list)
            {
              'name': label(s),
              'revenue': s.revenue,
              'orders': s.orders,
              if (prev != null) 'prev_revenue': before[s.storeId]?.revenue ?? 0,
              if (prev != null) 'prev_orders': before[s.storeId]?.orders ?? 0,
              'discount': s.discount,
              if (s.storeId == storeId) 'current': true,
              if (byDay)
                'by_weekday': weekday[s.storeId] ?? List.filled(7, 0.0),
            },
        ],
        if (list.length < cur.stores.length)
          'total': {
            'count': cur.stores.length,
            'revenue': cur.stores.fold<double>(0, (a, s) => a + s.revenue),
            'orders': cur.stores.fold<int>(0, (a, s) => a + s.orders),
            if (prev != null)
              'prev_revenue': prev.stores.fold<double>(
                0,
                (a, s) => a + s.revenue,
              ),
          },
        'excluded': cur.excluded.length,
      };
    } catch (_) {
      return null;
    }
  }

  ({String key, DateTime at, BoomPerms p})? _permsCache;

  /// Lần đọc số module gần nhất không đọc được quyền (mạng / máy chủ) → báo "thử lại", không báo "không có quyền".
  bool _modulePermsFailed = false;

  /// Quyền của người hỏi ở quán đang mở (đọc lại từ máy chủ, nhớ 2 phút). Lỗi → null = không có quyền.
  Future<BoomPerms?> _perms(String storeId) async {
    final uid = ref.read(sessionProvider)?.userId ?? '';
    final key = '$uid|$storeId';
    final c = _permsCache;
    if (c != null &&
        c.key == key &&
        DateTime.now().difference(c.at) < const Duration(minutes: 2)) {
      return c.p;
    }
    try {
      final o = ref.read(boomPermsLoaderProvider);
      final p = o != null
          ? await o(storeId)
          : await BoomModuleDataService(
              Supabase.instance.client,
            ).perms(storeId, uid).timeout(const Duration(seconds: 6));
      if (p != null) _permsCache = (key: key, at: DateTime.now(), p: p);
      return p;
    } catch (_) {
      return null;
    }
  }

  /// Đọc số các module theo quyền người hỏi (như app: vai trò + module đang bật). Lỗi / quá chậm → bỏ module đó.
  Future<({Map<String, dynamic> facts, List<BoomModule> denied})> _moduleFacts(
    String storeId,
    Set<BoomModule> topics,
    String query,
  ) async {
    final session = ref.read(sessionProvider);
    final facts = <String, dynamic>{};
    final denied = <BoomModule>[];
    // Quyền đọc chặt: lỗi / không phải thành viên → coi như không có quyền module nào
    final perms = await _perms(storeId);
    _modulePermsFailed = perms == null;
    if (perms == null) return (facts: facts, denied: const <BoomModule>[]);
    try {
      // Tạo cổng đọc khi cần (kiểm quyền trước, kể cả khi chưa kết nối được máy chủ)
      late final svc = BoomModuleDataService(Supabase.instance.client);
      final tr = IntentClassifier.timeRangeIn(query);
      final known = tr != null && tr != 'unsupported' && tr != 'current_shift';
      var range = known
          ? boomRangeOf(tr, DateTime.now())
          : boomPeriodRange(BoomPeriod.thisMonth, DateTime.now());
      // các mục đọc từng dòng (thu chi, chấm công, đơn) → kỳ quá 92 ngày đọc quá lâu, dùng tháng này (nhãn kỳ gửi
      // kèm nên GPT nói rõ đang xem tháng này) — QC đợt 11
      if (range.end.difference(range.start).inDays > 92) {
        range = boomPeriodRange(BoomPeriod.thisMonth, DateTime.now());
      }
      await Future.wait([
        for (final m in topics)
          () async {
            final access = boomModuleAccess(m, perms);
            if (access == null) {
              denied.add(m);
              return;
            }
            try {
              final f = await switch (m) {
                BoomModule.finance => svc.finance(storeId, range),
                BoomModule.kho => svc.kho(
                  storeId,
                  range,
                  withCost: access == 'all',
                ),
                BoomModule.nhanSu => svc.nhanSu(
                  storeId,
                  range,
                  onlyUserId: access == 'self' ? session?.userId : null,
                ),
                BoomModule.khach => svc.khach(storeId, range),
                BoomModule.khuyenMai => svc.khuyenMai(storeId, range),
              }.timeout(const Duration(seconds: 10));
              facts[kBoomModuleKeys[m]!] = f;
            } catch (_) {}
          }(),
      ]);
    } catch (_) {}
    return (facts: facts, denied: denied);
  }

  /// GPT lỗi / chưa bật → vẫn hiện số từng chi nhánh đã đọc.
  String _chainText(Map<String, dynamic> c) {
    final lines = ['Chuỗi ${c['name']} — ${c['period']}:'];
    for (final s in (c['stores'] as List).cast<Map<String, dynamic>>()) {
      lines.add(
        '• ${s['name']}: ${_formatCurrency((s['revenue'] as num).toDouble())} từ ${s['orders']} đơn',
      );
    }
    return lines.join('\n');
  }

  Future<Map<String, dynamic>?> _shopFacts(
    String storeId,
    String query,
    ClassificationResult classification,
  ) async {
    try {
      // Câu không thuộc loại số liệu ("hôm nay nên đẩy món nào") không có kỳ → tách kỳ như câu doanh thu.
      final tr =
          (kBoomDataIntents.contains(classification.intent)
                      ? classification
                      : IntentClassifier.classify('doanh thu $query'))
                  .entities['time_range']
              as String?;
      final mentions = _viHit(_mentionsPeriodP, _padVi(query));
      // kỳ dài ("year:2026") không phải kỳ cũ → boomPeriodFrom sẽ rơi về hôm nay (QC đợt 11)
      final period =
          tr != null && tr != 'unsupported' && !tr.contains(':') && mentions
          ? boomPeriodFrom(tr)
          : BoomPeriod.thisMonth;
      final now = DateTime.now();
      // Kỳ dài (đợt 11: "30 ngày qua", "quý 3") — quá 92 ngày đọc từng món quá lâu → tháng này như cũ
      var range = boomPeriodRange(period, now);
      if (tr != null && tr.contains(':') && mentions) {
        final long = boomRangeOf(tr, now);
        if (long.end.difference(long.start).inDays <= 92) range = long;
      }
      final data =
          ref.read(boomReadOnlyDataProvider) ??
          BoomReadOnlyDataService(Supabase.instance.client);
      final summary = await data.getRevenueSummary(
        storeId,
        period,
        range: range,
      );
      final perf = await data.getProductPerformance(
        storeId,
        period: period,
        limit: 10,
        range: range,
      );
      final sold = perf.top.where((t) => t.quantity > 0).take(5).toList();
      String clip(String s, int n) => s.length > n ? s.substring(0, n) : s;
      // Combo: tách tên ("Combo mì cay + trà đào") → khớp món đang bán → tổng giá mua lẻ (chưa có bảng thành phần
      // combo; khớp không đủ → bỏ qua). GPT tự cộng giá hay sai (chấm cố vấn 24/10).
      String fold(String x) => boomComposeVi(x.toLowerCase()).trim();
      double? comboRetail(BoomProductMetric t) {
        var n = fold(t.name);
        if (!n.startsWith('combo')) return null;
        // "Combo 1: phở + trà đá" → bỏ "combo", số / tên combo trước dấu ":"
        n = n.substring(5);
        if (n.contains(':')) n = n.substring(n.indexOf(':') + 1);
        final parts = n
            .split(RegExp(r'\+|&|,| và | với '))
            .map((x) => x.trim())
            .toList();
        if (parts.length < 2) return null;
        var sum = 0.0;
        for (final part in parts) {
          // Phần quá ngắn / mơ hồ ("2 ly") hoặc khớp nhiều món → bỏ cả combo (QC 24/10: thà không có còn hơn sai)
          if (part.length < 2) return null;
          final menu = perf.all
              .where((o) => !fold(o.name).startsWith('combo') && o.price > 0)
              .toList();
          final exact = menu.where((o) => fold(o.name) == part).toList();
          final m = exact.isNotEmpty
              ? exact
              : menu.where((o) => fold(o.name).contains(part)).toList();
          if (m.length != 1) return null;
          sum += m.first.price;
        }
        return sum;
      }

      Map<String, dynamic> item(BoomProductMetric t) => {
        'name': clip(t.name, 60),
        'qty': t.quantity,
        'revenue': t.revenue,
        'price': t.price,
        if (t.unitCost > 0) 'cost': t.unitCost,
        'retail': ?comboRetail(t),
      };
      // Theo nhóm món của quán (Đồ ăn / Đồ uống / Topping…): GPT so món trong cùng nhóm, không đem món chính
      // so với đồ uống (Chủ Quán test 24/10). Tối đa 8 nhóm doanh thu cao nhất, mỗi nhóm 3 chạy / 3 chậm.
      // Gom theo tên nhóm không phân biệt hoa thường ("Đồ uống" = "đồ uống"), hiện tên gặp đầu tiên.
      final byCat = <String, List<BoomProductMetric>>{};
      for (final t in perf.all) {
        (byCat[t.category.trim().toLowerCase()] ??= []).add(t);
      }
      final groups =
          byCat.values.map((items) {
            final selling = items.where((t) => t.quantity > 0).toList()
              ..sort((a, b) => b.revenue.compareTo(a.revenue));
            final top = selling.take(3).toList();
            final slow =
                (selling.skip(3).toList()
                      ..sort((a, b) => a.quantity.compareTo(b.quantity)))
                    .take(3)
                    .toList();
            final unsold = items.where((t) => t.quantity <= 0).toList();
            return {
              'name': clip(items.first.category, 40),
              'revenue': items.fold<double>(0, (s, t) => s + t.revenue),
              'qty': items.fold<double>(0, (s, t) => s + t.quantity),
              'items': items.length,
              'unsold': unsold.length,
              'top': [for (final t in top) item(t)],
              'slow': [for (final t in slow) item(t)],
              'unsold_names': [
                for (final t in unsold.take(3)) clip(t.name, 60),
              ],
            };
          }).toList()..sort(
            (a, b) =>
                (b['revenue'] as double).compareTo(a['revenue'] as double),
          );
      final facts = <String, dynamic>{
        'period': clip(summary.range.label, 40),
        'revenue': summary.revenue,
        'orders': summary.orderCount,
        if (summary.previousOrderCount > 0) ...{
          'prev_period': clip(summary.range.prevLabel, 40),
          'prev_revenue': summary.previousRevenue,
          'prev_orders': summary.previousOrderCount,
        },
        'top': [
          for (final t in sold)
            {'name': clip(t.name, 60), 'qty': t.quantity, 'revenue': t.revenue},
        ],
        'slow': const <Map<String, dynamic>>[],
        'items_revenue': perf.all.fold<double>(0, (s, t) => s + t.revenue),
        if (summary.byHour.any((v) => v > 0)) 'by_hour': summary.byHour,
        if (summary.byWeekday.any((v) => v > 0))
          'by_weekday': summary.byWeekday,
        'groups': groups.take(8).toList(),
        if (perf.byBand.any((b) => b.isNotEmpty))
          'by_band': [
            for (final b in perf.byBand)
              [
                for (final x in b) {'name': clip(x.name, 60), 'qty': x.qty},
              ],
          ],
      };
      // Gói gửi máy chủ ≤ 32 KB (byte UTF-8): menu nhiều nhóm / tên dài → bớt dần chi tiết (QC 24/10)
      int size() => utf8.encode(jsonEncode(facts)).length;
      final gs = facts['groups'] as List;
      if (size() > 12000) {
        for (final g in gs) {
          (g as Map)['unsold_names'] = const <String>[];
        }
      }
      if (size() > 12000) {
        for (final g in gs) {
          (g as Map)['slow'] = const <Map<String, dynamic>>[];
        }
      }
      if (size() > 12000) facts['groups'] = gs.take(5).toList();
      return facts;
    } catch (_) {
      return null;
    }
  }

  String _factsText(Map<String, dynamic> f) {
    final top = (f['top'] as List)
        .map(
          (t) =>
              '${t['name']} (${_formatQuantity(t['qty'] as double)} món, ${_formatCurrency(t['revenue'] as double)})',
        )
        .join('; ');
    return '${f['period']}: doanh thu ${_formatCurrency(f['revenue'] as double)} từ ${f['orders']} đơn.'
        '${top.isEmpty ? '' : ' Món bán chạy: $top.'}';
  }

  /// [remember] = false: xoá màn hình chat do đổi người / quán (KHÔNG phải người dùng bấm làm mới) → máy chủ
  /// vẫn nhớ 5 giờ của người / quán mới.
  void clearChat({bool remember = true}) {
    _lastTurn = null;
    if (remember) {
      final now = DateTime.now();
      _chatStartedAt = now;
      unawaited(_saveChatReset(now));
    } else {
      _chatStartedAt = null;
    }
    _generation++;
    _replying = false;
    state = [_greeting()];
    if (!_xungHoLoaded) Future.microtask(_loadXungHo);
  }
}
