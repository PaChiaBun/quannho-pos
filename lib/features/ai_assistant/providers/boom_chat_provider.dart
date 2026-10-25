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
  'staff_on_shift',
};

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
        hasHelpActionWord(query) ||
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
    hasHelpActionWord(query);

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
  final danh = xungHo == 'anh'
      ? 'Anh'
      : xungHo == 'chi'
      ? 'Chị'
      : 'Anh/Chị';
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
  r'làm gì để|tăng doanh thu|bán thêm|combo) ',
);
final _shopDataTopic = RegExp(
  r' (?:món|doanh thu|bán chạy|bán được|bán ế|bán chậm|bán ít|menu|thực đơn|sản phẩm|mặt hàng|kinh doanh|'
  r'bán hàng|buôn bán|quán mình|số liệu|phân tích) ',
);
final _howToCue = RegExp(
  r' (?:ở đâu|chỗ nào|mục nào|tab nào|nằm đâu|bấm|cài|cách xem|xem ở|trong app|app có|màn hình|mở báo cáo|làm sao|'
  r'cách nào|xuất|excel|pdf|in báo cáo|tải|gửi báo cáo|có những gì|gồm những gì|xem được|quyền|phân quyền|bị sai|'
  r'không khớp|bị lệch|không hiện|không cập nhật|không ra|bằng 0|bị lỗi|báo lỗi|phải làm gì để|báo khách|chuỗi|chi nhánh|2 quán|hai quán|các quán) ',
);

/// Câu hỏi cách dùng / báo lỗi / quyền trong app ("báo cáo doanh thu bị sai", "tải báo cáo về máy") — không trả
/// số liệu, không tư vấn số.
bool boomAsksHowTo(String query) => _howToCue.hasMatch(_padVi(query));

bool boomWantsDataAdvice(String query) {
  final s = _padVi(query);
  // Hỏi một con số ("tổng kết ca sáng doanh thu bao nhiêu") → số nhanh, không cần GPT phân tích
  if (RegExp(
        r' (?:bao nhiêu|mấy (?:đơn|ly|phần|tiền|khách|người|bàn)) ',
      ).hasMatch(s) &&
      !RegExp(r' (?:phân tích|đánh giá|nhận xét|tư vấn|nên) ').hasMatch(s)) {
    return false;
  }
  return _dataAdviceCue.hasMatch(s) &&
      _shopDataTopic.hasMatch(s) &&
      !_howToCue.hasMatch(s) &&
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

/// Câu xin tư vấn về chuyện kinh doanh CỦA QUÁN (kế hoạch, quảng cáo, khuyến mãi, khách, doanh thu…) → app tự đọc số
/// liệu gửi kèm, không bắt chủ quán tự xem Báo cáo (Chủ Quán 24/10: "có thể tự vào đọc db mà").
final _shopBusinessTopic = RegExp(
  r' (?:kế hoạch|chiến dịch|chiến lược|quảng cáo|quảng bá|marketing|khuyến mãi|ưu đãi|doanh thu|doanh số|lợi nhuận|'
  r'kinh doanh|tình hình|tăng khách|thu hút khách|kéo khách|giữ khách|khách quen|món nào|bán chạy|bán ế|bán chậm|'
  r'tháng sau|tuần sau|tháng tới|tuần tới|cuối tuần|giờ vắng|ngày vắng|vắng khách|tăng doanh thu) ',
);

bool boomMentionsShopBusiness(String query) =>
    _shopBusinessTopic.hasMatch(_padVi(query));

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
final _mentionsPeriod = RegExp(r' (?:hôm nay|hôm qua|nay|tuần|tháng) ');

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
  r'làm được (?:bao nhiêu|mấy)|bảo quản|để được mấy ngày|để ngoài|hết hạn|an toàn thực phẩm|ngộ độc|dịch|tiếng anh|'
  r'viết (?:giúp|giùm|bài|tin|câu|thư|nội dung|lời)|bài đăng|đăng tuyển|tuyển (?:nhân viên|người|phục vụ)|hàm excel|'
  r'google sheets|sheets|công thức excel|lương tối thiểu|thử việc|hợp đồng lao động|bảo hiểm|nghỉ ngang|giữ lương|'
  r'máy pha|tủ mát|tủ đông|nên mua|loại nào tốt|trang trí|decor|nhạc|wifi cho khách|phòng cháy|chữa cháy|pccc|bình chữa cháy|'
  r'giấy phép|rượu bia|bán bia|đau lưng|mỏi chân|sức khoẻ|sức khỏe|chuyện cười|kể chuyện|tình cảm|người yêu|bồ) ',
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
    r'quán kia|cửa hàng kia|quán còn lại|cửa hàng còn lại|so sánh quán \S+(?: \S+){0,3} (?:với|và) quán) ';
const _chainMineSrc =
    r' (?:(?:của|bên) (?:tôi|mình|tui|tớ|em|chúng tôi|nhà mình)|quán mình|nhà mình|so sánh|quán nào|cửa hàng nào) ';
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
    r'nổi tiếng|thương hiệu|đối thủ|số điện thoại|ngân hàng) ';

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
      r'tiền điện|tiền nước|tiền thuê|tiền nhà|chi nhiều|chi những gì|chi gì|chi hết) ',
  BoomModule.kho:
      r' (?:tồn kho|còn tồn|hàng tồn|kho còn|kho có|trong kho còn|(?:còn|có|hết) (?:\S+ ){0,2}trong kho|kho hàng|giá trị kho|hết hàng|sắp hết|nhập hàng|nhập kho|hàng nhập|'
      r'nguyên liệu (?:nào|còn|sắp|hết|tồn|nhập)|còn bao nhiêu (?:hộp|kg|gói|lon|chai|thùng|cái|ly|bịch|túi)|hao hụt|'
      r'hư hỏng|đổ bỏ|hàng hết hạn|nguyên liệu hết hạn|nhà cung cấp nào|nhập của ai) ',
  BoomModule.nhanSu:
      r' (?:chấm công|ca làm|giờ làm|làm (?:bao nhiêu|mấy) (?:giờ|ca|tiếng)|quên chấm|bảng lương|kỳ lương|quỹ lương|tổng lương|'
      r'lương tháng (?:này|trước)|lương tuần (?:này|trước)|(?:tháng|tuần) (?:này|trước) lương|trả lương tháng|nhân viên nào|'
      r'ai làm|ai đi làm|ai nghỉ làm|ai nghỉ|làm nhiều nhất|làm ít nhất|đi làm (?:bao nhiêu|mấy)) ',
  BoomModule.khach:
      r' (?:khách quen|khách hàng (?:nào|của|quay|mới|thân)|khách mới|khách quay lại|thành viên (?:mới|của)|tích điểm|'
      r'ví khách|số dư ví|nạp ví|khách vip|khách chi|khách nào|khách cũ) ',
  BoomModule.khuyenMai:
      r' (?:khuyến mãi|voucher|mã giảm|coupon|mã khuyến mãi|chương trình giảm giá|'
      r'giảm giá (?:tháng|tuần|hôm|tổng|bao nhiêu tiền|hết bao nhiêu)) ',
};
// Câu xin SỐ / phân tích (không phải hỏi cách làm)
const _moduleAskSrc =
    r' (?:bao nhiêu|mấy|nào|nhất|tổng|tình hình|phân tích|đánh giá|nhận xét|so sánh|so với|tăng|giảm|ra sao|'
    r'kiểm tra|xem giúp|báo cáo|liệt kê|danh sách|hiệu quả|tháng này|tuần này|hôm nay|hôm qua|tháng trước|tuần trước|'
    r'kỳ này|có lãi|lỗ không|lời hay lỗ|lãi hay lỗ|tốn|nhiều không|ít không|những gì|chi gì|sắp hết|hết hàng|'
    r'quay lại|ai làm) ';
// Hỏi cách làm / thao tác / lỗi / kiến thức chung → hướng dẫn hoặc tư vấn như cũ
const _moduleHowSrc =
    r' (?:ở đâu|chỗ nào|mục nào|tab nào|bấm|nút|màn hình|cách|làm sao để (?:thêm|tạo|nhập|sửa|xoá|xóa|in|xuất|xem|mở|'
    r'chấm|cài|bật|tắt|đổi|dùng)|(?:thêm|tạo|sửa|xoá|xóa|cài|bật|tắt|đổi|duyệt|chốt) (?:\S+ ){0,2}(?:mã|voucher|khuyến mãi|'
    r'khách|nhân viên|lương|ca|phiếu|món|hàng|nguyên liệu|nhà cung cấp|quỹ|danh mục|khoản|chi|thu|tiền)|xuất|excel|pdf|in phiếu|in bảng|'
    r'bị lỗi|báo lỗi|không hiện|không thấy|bị sai|bị lệch|không khớp|quyền|phân quyền|là gì|công thức|luật|quy định|'
    r'bảo hiểm|thuế|hợp đồng|tối thiểu vùng|nên giữ|hợp lý|uy tín|rẻ nhất|nhiệt độ|xử lý sao|thì xử lý|phải không|'
    r'ở quận|ở sài gòn|ở hà nội|ở đà nẵng|thị trường|thường bao nhiêu|báo khách) ';
final _moduleTopics = {
  for (final e in _moduleTopicSrc.entries) e.key: _viPair(e.value),
};
final _moduleAsk = _viPair(_moduleAskSrc);
final _moduleHow = _viPair(_moduleHowSrc);

/// Các module mà câu hỏi xin SỐ LIỆU ("tháng này chi phí gì nhiều nhất", "hàng nào sắp hết", "ai làm nhiều giờ nhất",
/// "voucher nào hiệu quả"). Câu hỏi cách làm / báo lỗi / luật → rỗng (đi hướng dẫn / tư vấn như cũ).
Set<BoomModule> boomModuleTopics(String query) {
  final s = _padVi(query);
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

bool boomGeneralKnowledge(String query) =>
    _generalKnowledge.hasMatch(_padVi(query));

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
  const _LastTurn(
    this.turn,
    this.shopData,
    this.at, {
    this.advice = false,
    this.chain = false,
    this.modules = false,
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

  String get _goi =>
      boomGoiNguoiDung(_xungHo, ref.read(sessionProvider)?.displayName);

  BoomMessage _greeting() {
    // Chỉ hỏi Anh / Chị khi đã đọc được là chưa chọn (lưu được lên máy chủ)
    final ask = _xungHoLoaded && _xungHo == null;
    return BoomMessage(
      content:
          'Dạ, Bé Boom chào $_goi ạ! Bé Boom có thể giúp $_goi xem doanh thu, món bán chạy, hàng sắp hết, '
          'và chỉ cách dùng app (vd: "huỷ món đã gửi bếp thế nào"). '
          '${ask ? 'Bé Boom nên gọi $_goi là Anh hay Chị ạ?' : '$_goi muốn hỏi gì ạ?'}',
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

      final t = text.trim().toLowerCase();
      if (t == kBoomGoiAnh.toLowerCase() || t == kBoomGoiChi.toLowerCase()) {
        await _saveXungHo(t == kBoomGoiAnh.toLowerCase() ? 'anh' : 'chi');
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
    String query, {
    bool isRetry = false,
    String? sourceUserMessageId,
  }) async {
    final generation = _generation;
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
        !boomAsksHowTo(query);
    // Câu nói tiếp (trong 30 phút): tìm hướng dẫn theo cả câu trước, tư vấn kèm lượt trước.
    final last = _lastTurn;
    final followUp =
        !usesReadOnlyDb &&
            !otherStore &&
            classification.intent != 'smalltalk' &&
            last != null &&
            DateTime.now().difference(last.at) < const Duration(minutes: 30) &&
            boomIsFollowUp(query, previous: last.turn.question)
        ? last
        : null;
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
          if (!picked && followUp != null) {
            followUsed = true;
            // Lượt trước là số bán / tư vấn → tư vấn tiếp (bên dưới), không để bài hướng dẫn "cướp" câu nói tiếp
            help = followUp.shopData || followUp.advice
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
            !(helpWins && hasHelpActionWord(query)) &&
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
    final history = followUsed ? followUp?.turn : null;
    final dataAdvice =
        !usesData &&
        !otherStore &&
        !picked &&
        // Câu xin phân tích không có động từ thao tác ("báo cáo xem", "phân tích giúp") thắng cả bài hướng dẫn
        // "Báo cáo" (bộ tìm hay khớp chữ "báo cáo"); câu hỏi cách làm ("xuất báo cáo thế nào") vẫn đi hướng dẫn.
        ((wantsDataAdvice && (!helpWins || !hasHelpActionWord(query))) ||
            (followUsed && followUp!.shopData) ||
            (boomMentionsShopBusiness(query) &&
                !helpWins &&
                !hasHelpActionWord(query) &&
                !boomAsksHowTo(query) &&
                !boomGeneralKnowledge(query)));
    // Câu xin số các module (thu chi, kho, nhân sự, khách, khuyến mãi) → đọc CHỈ ĐỌC theo quyền của người hỏi
    final moduleFollow = followUsed && followUp!.modules;
    final topics =
        chainFacts == null &&
            !usesData &&
            !otherStore &&
            !picked &&
            !(helpWins && hasHelpActionWord(query)) &&
            aiForAdvice != null &&
            storeId != null &&
            storeId.isNotEmpty
        ? boomModuleTopics(
            moduleFollow ? '${followUp.turn.question} $query' : query,
          )
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
        question: query,
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
        aiForAdvice.logUnanswered(storeId: storeId, question: query);
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
        !(helpWins && hasHelpActionWord(query)) &&
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
      final factsQuery = followUsed
          ? '${followUp!.turn.question} $query'
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
        question: query,
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
        aiForAdvice.logUnanswered(storeId: storeId, question: query);
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
        question: query,
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
        aiForAdvice.logUnanswered(storeId: storeId, question: query);
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
        // Chắc chắn → gửi đoạn đầu (+ đoạn cùng bài); chưa chắc → gửi cả 3 mục để GPT chọn đúng mục.
        final ctx = helpWins
            ? [
                help.hits.first.chunk,
                for (final h in help.hits.skip(1))
                  if (h.chunk.module == help.hits.first.chunk.module) h.chunk,
              ]
            : [for (final h in help.hits) h.chunk];
        final answered = canAsk
            ? await ai.ask(
                storeId: storeId,
                question: query,
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
          ai.logUnanswered(storeId: storeId, question: query);
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
          question: query,
          history: history,
          memorySince: _chatStartedAt,
        );
        if (!_mounted || generation != _generation) return;
        if (reply == null) {
          ai.logUnanswered(storeId: storeId, question: query);
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
          'low_stock' =>
            perms != null && boomCanSeeStock(perms) ? null : 'Kho hàng',
          'staff_on_shift' =>
            perms != null && boomCanSeeShifts(perms) ? null : 'Chấm công',
          _ => perms != null && boomCanSeeSales(perms) ? null : 'Báo cáo',
        };
        late final readOnlyData = BoomReadOnlyDataService(
          Supabase.instance.client,
        );
        final storeName = session?.storeName?.trim().isNotEmpty == true
            ? session!.storeName!.trim()
            : 'quán';

        if (blockedModule != null) {
          // Không đọc được quyền (mạng / máy chủ chậm) ≠ không có quyền
          fullReply = perms == null
              ? 'Bé Boom chưa kiểm tra được quyền xem số liệu lúc này. $_goi thử lại sau một chút nhé!'
              : 'Bé Boom chưa xem được số liệu $blockedModule vì tài khoản của $_goi chưa được mở mục này trong app. '
                    '$_goi nhờ chủ quán hoặc quản lý xem giúp, hoặc xin cấp quyền nhé ạ.';
        } else if (classification.entities['time_range'] == 'unsupported' &&
            const {
              'revenue_summary',
              'sales_comparison',
              'top_products',
              'slow_products',
            }.contains(classification.intent)) {
          // Kỳ Boom chưa đọc được ("tháng 5", "năm nay", "7 ngày qua") — nói rõ, không trả nhầm số hôm nay.
          fullReply =
              'Bé Boom hiện xem được số liệu theo: hôm nay, hôm qua, tuần này, tuần trước, tháng này, tháng trước. '
              'Kỳ khác $_goi xem ở màn Báo cáo nhé.';
          suggestions = ['Doanh thu tháng này?', 'Doanh thu tháng trước?'];
          // Không phải lượt đọc dữ liệu: không ghi "tool_completed" (không làm đẹp số liệu đo lường)
        } else if (classification.intent == 'revenue_summary' ||
            classification.intent == 'sales_comparison') {
          final toolTimer = Stopwatch()..start();
          final period = boomPeriodFrom(
            classification.entities['time_range'] as String?,
          );
          final summary = await readOnlyData.getRevenueSummary(storeId, period);
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
          final label = boomPeriodRange(period, DateTime.now()).label;
          final performance = await readOnlyData.getProductPerformance(
            storeId,
            period: period,
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
          final label = boomPeriodRange(period, DateTime.now()).label;
          final performance = await readOnlyData.getProductPerformance(
            storeId,
            period: period,
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
        } else if (classification.intent == 'low_stock') {
          final toolTimer = Stopwatch()..start();
          final alerts = await readOnlyData.getLowStock(storeId);
          if (alerts.isEmpty) {
            fullReply =
                'Dữ liệu kho hiện không có mặt hàng nào chạm hoặc thấp hơn mức tồn tối thiểu.';
          } else {
            final details = alerts
                .take(5)
                .map(
                  (item) =>
                      '${item.name}: còn ${_formatQuantity(item.stockQuantity)}, tối thiểu ${_formatQuantity(item.minimumStock)}',
                )
                .join('; ');
            fullReply =
                'Có ${alerts.length} mặt hàng cần chú ý: $details. Gợi ý: kiểm tra thực tế và lập kế hoạch nhập hàng; Bé Boom không tự tạo phiếu nhập.';
          }
          suggestions = ['Hôm nay ai đang làm?', 'Món nào bán chạy nhất?'];
          toolTimer.stop();
          completedTool = 'low_stock_read_only';
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
            question: query,
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
      final range = boomPeriodRange(
        known ? boomPeriodFrom(tr) : BoomPeriod.thisMonth,
        DateTime.now(),
      );
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
      final range = boomPeriodRange(
        known ? boomPeriodFrom(tr) : BoomPeriod.thisMonth,
        DateTime.now(),
      );
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
      final period =
          tr != null &&
              tr != 'unsupported' &&
              _mentionsPeriod.hasMatch(_padVi(query))
          ? boomPeriodFrom(tr)
          : BoomPeriod.thisMonth;
      final data = BoomReadOnlyDataService(Supabase.instance.client);
      final summary = await data.getRevenueSummary(storeId, period);
      final perf = await data.getProductPerformance(
        storeId,
        period: period,
        limit: 10,
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
