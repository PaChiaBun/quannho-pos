// lib/features/ai_assistant/help/help_search.dart
// ─────────────────────────────────────────────────────────────────────────────
// Tìm đoạn hướng dẫn cho câu hỏi "cách làm" của Boom — không dùng mô hình AI.
//  • Bỏ dấu + chữ thường ("huỷ món" = "huy mon" = "HỦY MÓN").
//  • Từ đồng nghĩa (bill ↔ hoá đơn, huỷ ↔ xoá…) — điểm thấp hơn từ gốc.
//  • Chấm điểm BM25 trên từ đơn + cặp từ; tiêu đề nặng hơn nội dung.
// Dart thuần — test chạy không cần Flutter.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math' as math;

import 'huong_dan_parser.dart';

const _kFrom =
    'àáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđ';
const _kTo =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Chữ thường, bỏ dấu tiếng Việt, chỉ giữ chữ/số.
String foldVietnamese(String s) {
  final lower = s.toLowerCase();
  final b = StringBuffer();
  for (final r in lower.runes) {
    final ch = String.fromCharCode(r);
    // dấu tổ hợp (gõ kiểu NFD) → bỏ
    if (r >= 0x0300 && r <= 0x036F) continue;
    final i = _kFrom.indexOf(ch);
    b.write(i >= 0 ? _kTo[i] : ch);
  }
  return b.toString().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Từ hư — bỏ khỏi câu hỏi (đã bỏ dấu).
const _kStop = {
  'la',
  'gi',
  'the',
  'nao',
  'sao',
  'lam',
  'cach',
  'o',
  'dau',
  'toi',
  'to',
  'minh',
  'em',
  'anh',
  'chi',
  'cau',
  'ban',
  'nhe',
  'nha',
  'vay',
  'de',
  'duoc',
  'cho',
  'cua',
  'va',
  'voi',
  'mot',
  'nhung',
  'nay',
  'khi',
  'thi',
  'ma',
  'nhu',
  'tai',
  'can',
  'muon',
  'hay',
  'giup',
  'huong',
  'dan',
  'boom',
  'oi',
  'a',
  'ah',
  'u',
  'ko',
  'k',
  'khong',
  'co',
  'phai',
  'bi',
  'roi',
  'di',
  'len',
  'ra',
  'vao',
  'trong',
  'tren',
  'duoi',
  'cai',
  'con',
  'nua',
  'thu',
  'xem',
  'coi', // = "xem" (miền Nam)
  'bang',
  'bao',
  'nhieu',
  'hom',
  'gium',
  'dum',
  'ak',
  'ha',
  'hen',
  'nhi',
};
// "ban" (bàn / bạn) là từ hư khi đứng một mình; cặp từ "quan ly ban", "gop ban"… vẫn giữ nhờ bigram.
// "thu" (thử / thu) tương tự: "thu chi", "thu ngan" giữ nhờ bigram.

/// Nhóm đồng nghĩa (đã bỏ dấu). Mỗi cụm có thể nhiều từ.
const _kSynonyms = <List<String>>[
  ['bill', 'hoa don', 'hd', 'phieu tinh tien', 'tam tinh'],
  ['huy', 'xoa', 'bo mon', 'go mon', 'go ma', 'bo bot', 'bo ban'],
  ['in lai', 'in bill cu', 'in lai bill'],
  ['may in', 'printer', 'may in bill'],
  [
    'nap vi',
    'nap tien',
    'vi khach',
    'vo vi',
    'vao vi',
    'nap vo vi',
    'nap vao vi',
  ],
  ['giam gia', 'voucher', 'ma giam gia', 'khuyen mai', 'ma giam', 'ma km'],
  [
    'cham cong',
    'vao ca',
    'ra ca',
    'check in',
    'diem danh',
    'vo ca',
    'dzo ca',
    'bam vao ca',
  ],
  ['tra luong', 'luong', 'phat luong', 'ky luong'],
  ['kho', 'ton kho', 'hang ton'],
  ['het hang', 'het mon', 'tam het', 'tat ban', 'ngung ban'],
  ['nhap hang', 'nhap kho', 'phieu nhap'],
  ['ma qr', 'qr', 'quet ma'],
  // 26/10: bỏ từ đơn 'khach' / 'diem' ("chuyển khách qua bàn", "địa điểm quán" bị kéo về bài tích điểm); giữ cụm rõ nghĩa
  [
    'khach hang',
    'thanh vien',
    'tich diem',
    'diem thuong',
    'khach quen',
    'chi tiet khach',
    'ghe may lan',
    'sdt khach',
    'so dien thoai khach',
  ],
  ['thu chi', 'so quy', 'chi phi', 'ghi chi', 'tien dien'],
  ['bep', 'phieu bep', 'man bep', 'kds'],
  ['nhan vien', 'nv', 'nhan su', 'staff'],
  // Chủ quán đặt lại mật khẩu nhân viên (26/10): người dùng hay viết "pass" / "reset"
  ['mat khau', 'pass', 'password', 'mk'],
  ['dat lai', 'reset', 'cap lai', 'lay lai'],
  ['vai tro', 'chuc vu'],
  ['doanh thu', 'bao cao', 'thong ke'],
  [
    'ket tien',
    'mo ket',
    'ngan keo',
    'cam ket',
    'ket khong mo',
    'ket khong bat',
  ],
  [
    'chuyen ban',
    'doi ban',
    'gop ban',
    'ghep ban',
    'qua ban khac',
    'sang ban khac',
    'doi cho ngoi',
    'doi qua ban',
    'doi sang ban',
    'gop 2 ban',
    'gop hai ban',
    'chung 1 bill',
    'chung mot bill',
  ],
  // Bộ 160 câu thường gặp (24/10): người dùng nói khác chữ trong tài liệu
  ['goi mon', 'order', 'len mon', 'dat mon'],
  ['giam gia tay', 'giam tay', 'bot tien', 'chiet khau', 'tru tien cho khach'],
  ['in phieu', 'in lai phieu', 'in phieu bep', 'in lai phieu bep'],
  ['sua mon', 'sua gia', 'doi gia', 'tang gia', 'gia ban', 'sua san pham'],
  ['goi nap', 'nap tang', 'khuyen khich nap', 'tang them khi nap'],
  ['tu in', 'tat tu in', 'tu dong in', 'tu in bill', 'mo ket tu dong'],
  ['phieu luong', 'xem phieu luong', 'luong cua toi'],
  [
    'luong theo gio',
    'tinh luong theo gio',
    'luong nhan vien theo gio',
    'luong theo ca',
    'cau hinh luong',
  ],
  [
    'xuat excel',
    'xuat file',
    'csv',
    'xuat so',
    'gui ke toan',
    'xuat so chi tiet',
    'so chi tiet quy',
    'excel',
  ],
  ['nhap hang moi mua', 'mua ve nhap', 'nhap kho nhanh', 'moi mua ve'],
  // Bộ 96 câu giữ riêng (24/10)
  ['mo lai phieu', 'mo lai don', 'lo bam xong', 'bam nham xong'],
  [
    'ghi nham',
    'ghi trung',
    'ghi 2 lan',
    'ghi hai lan',
    'xoa khoan',
    'xoa bot',
    'ghi lon',
    'nhap lon',
  ],
  ['vao quan', 'vo quan', 'cho vao quan', 'ket noi vao quan', 'ma ket noi'],
  ['chon sai ban', 'chon nham ban', 'chon lon ban', 'doi sang ban khac'],
  ['muc tru', 'tru luong', 'phat tien', 'cau hinh luong'],
  ['khong thay viec', 'khong thay nhiem vu', 'khong hien viec', 'tao viec'],
  ['sua vai tro', 'tao vai tro', 'bat module', 'cho vai tro'],
  ['nhan don', 'don moi', 'don qr moi', 'nhan don qr'],
  // "bàn" bỏ dấu = "bạn" (từ hư) → việc với bàn phải khớp bằng cặp từ (Chủ Quán test 24/10: "sửa bàn" → chưa thấy)
  [
    'sua ban',
    'sua thong tin ban',
    'xoa ban',
    'doi ten ban',
    'them ban',
    'tao ban',
    'thiet lap ban',
    'so do ban',
    'khu vuc',
    'chinh ban',
  ],
  ['ma pin', 'pin'],
  ['thanh toan', 'tinh tien', 'thu tien', 'checkout'],
  ['topping', 'mon them'],
  ['tem ly', 'tem dan ly', 'in tem', 'nhan dan ly', 'dan len ly', 'sticker'],
  ['ban giao ca', 'giao ca', 'ban giao'],
  ['checklist', 'viec', 'cong viec', 'nhiem vu'],
  [
    'chuoi',
    'nhieu cua hang',
    'chi nhanh',
    'nhieu quan',
    'gom quan',
    'gop quan',
    'co 2 quan',
    'hai quan',
  ],
  // Bộ F 27/10: người dùng tả triệu chứng, bài viết tên chức năng
  [
    'in hoa don that bai',
    'khong nha giay',
    'ko nha giay',
    'khong ra giay',
    'khong in ra',
  ],
  [
    'het hang',
    'mon mo mo',
    'bi mo mo',
    'mon bi mo',
    'khong cho chon',
    'ko cho chon',
  ],
  [
    'tieng chuong',
    'khong nghe chuong',
    'tinh tinh',
    'ting ting',
    'am bao',
    'tieng bao',
    'khong keu',
    'ko keu',
  ],
  ['dinh vi', 'bao o xa', 'ngoai pham vi', 'gps', 'lech vi tri'],
  ['tru 50', 'nua tien', 'cat nua', 'mat nua', 'tru mot nua'],
  [
    'nguyen lieu khong giam',
    'khong hut',
    'ko hut',
    'khong tru kho',
    'kho khong giam',
    'kho khong bi tru',
    'khong tru di',
  ],
  ['gia von', 'tien von', 'von ly', 'von cao bat thuong'],
  [
    'khong tim thay ban ghi',
    'khong ra dong nao',
    'ko ra dong nao',
    'khong co dong nao',
  ],
  ['tu choi don', 'dat bay', 'dat linh tinh', 'don ao', 'don bay'],
  ['tam tinh', 'coi truoc tong', 'xem truoc tong', 'in truoc'],
  [
    'chuoi',
    'nhom quan',
    'nam o nhom khac',
    'may tiem',
    'cac tiem',
    'nhieu tiem',
    'xem gop',
  ],
  ['thu chi', 'tien ra vo', 'so tien ra vo'],
  ['ngoi chung', 'doi qua ban', 'gop ban'],
  ['phieu luong', 'duoc tra bao nhieu', 'dc tra bao nhieu', 'duoc tra luong'],
  ['hanh dong nhay cam', 'tu y'],
  [
    'nhat ky',
    'log',
    'lich su',
    'truy vet',
    'ghi vet',
    'ai da sua',
    'ai doi gia',
  ],
  ['cong thuc', 'dinh luong', 'dinh muc'],
  ['kiem ke', 'kiem kho', 'dieu chinh ton'],
  ['hao hut', 'hu hong', 'bi hong', 'do vo', 'lam vo'],
  ['gui bep', 'bao bep', 'order bep', 'xuong bep'],
  ['ghi chu', 'note', 'dan do'],
  // "lời lỗ" (26/10): "loi" một mình = "lỗi" nên chỉ nhận cả cụm
  [
    'lai lo',
    'loi nhuan',
    'tai chinh',
    'lo lai',
    'ket qua kinh doanh',
    'loi lo',
    'loi hay lo',
  ],
  [
    'huy duyet',
    'nhat ky huy',
    'lich su huy',
    'ai duyet',
    'ai da huy',
    'ai huy',
    'ai xoa mon',
  ],
  ['tu ghi', 'tu dong', 'tu dong ghi', 'khong can ghi tay'],
  ['ban hang', 'tai quay', 'o quay', 'ban quay', 'pos', 'thu ngan'],
  ['phan quyen', 'tat quyen', 'cap quyen', 'hanh dong nhay cam', 'quyen'],
  ['doi thuong', 'phan thuong', 'doi diem', 'qua tang'],
  ['gan vai tro', 'doi vai tro', 'set vai tro', 'chuyen vai tro'],
  ['quen chot', 'quen ra ca', 'chot ca', 'ca quen chot'],
  // Kiểm tra 128 câu theo module (24/10): người dùng nói khác chữ trong tài liệu
  ['ky luong', 'bang luong', 'tao bang luong', 'lam luong', 'tinh luong thang'],
  [
    'loc tram',
    'quay pha che',
    'quay bar',
    'bep bar',
    'tram bar',
    'tram bep',
    'tram pha che',
  ],
  [
    'phieu tre',
    'mon tre',
    'ra mon tre',
    'phieu de lau',
    'phieu cho lau',
    'mon cho lau',
    'phieu qua gio',
  ],
  [
    'don log',
    'log cu',
    'luu bao lau',
    'xoa log',
    'giu log',
    'log luu duoc bao lau',
    'giu log bao lau',
  ],
  [
    'gan lai ten',
    'cham nham',
    'cham cong nham',
    'cham ho',
    'ca rac',
    'ca qua ten',
    'ca sang ten',
    'do qua ten',
    'chuyen ca',
  ],
  [
    'in 2',
    '2 to',
    'hai to',
    'in nhieu ban',
    'nhieu to',
    'in 2 ban',
    'in hai ban',
    'so ban in',
  ],
  ['bat qr', 'lam ma qr', 'tao ma qr', 'in ma qr', 'dan ma'],
  [
    'khong vao duoc',
    'vo khong duoc',
    'bam vo',
    'khong mo duoc',
    'vao khong duoc',
  ],
  [
    'theo doi trong ngay',
    'toi dau',
    'tien do checklist',
    'tien do hom nay',
    'theo doi nhan vien',
    'theo doi checklist',
  ],
  [
    'don gan day',
    'don vua ban',
    'don da ban',
    'don ban hoi',
    'don ban hom',
    'lich su don',
    'don hoi sang',
  ],
  [
    'so sanh quan',
    'so sanh cac quan',
    'so sanh chi nhanh',
    'so sanh cua hang',
    'giua cac chi nhanh',
    'giua cac quan',
    'xep hang quan',
    'quan nao ban',
    'cua hang nao',
    'chi nhanh nao',
  ],
];

List<String> _words(String folded) =>
    folded.split(' ').where((w) => w.isNotEmpty).toList();

/// Từ đơn (bỏ từ hư) + mọi cặp từ liền nhau (kể cả có từ hư) → "gop ban", "thu chi" vẫn khớp.
/// Bỏ chữ "bạn" CÓ DẤU trước khi bỏ dấu: "bạn" = "bàn" sau khi bỏ dấu ("đổi bạn Lan qua thu ngân" ≠ "đổi bàn").
String _prep(String text) => text.replaceAll(
  RegExp(r'(?<![\p{L}])[Bb]ạn(?![\p{L}])', unicode: true),
  ' ',
);

List<String> _terms(String text) {
  final w = _words(foldVietnamese(_prep(text)));
  return [
    for (final t in w)
      if (!_kStop.contains(t) && t.length > 1) t,
    for (var i = 0; i + 1 < w.length; i++) '${w[i]} ${w[i + 1]}',
  ];
}

final _kHowToCue = RegExp(
  r' (cach|the nao|lam sao|o dau|cho nao|huong dan|kieu gi|sao de|bang cach) ',
);

class HelpHit {
  final HelpChunk chunk;
  final double score;
  const HelpHit(this.chunk, this.score);
}

class HelpIndex {
  final List<HelpChunk> chunks;
  final int version;
  final List<Map<String, double>> _tf = []; // tf đã nhân trọng số trường
  final List<double> _len = [];
  final Map<String, int> _df = {};
  late final double _avgLen;

  static const _kTitleWeight = 3.0;
  static const _kSectionWeight = 1.0;
  static const _kBodyWeight = 1.0;
  static const _k1 = 1.2;
  static const _b = 0.75;

  HelpIndex(this.chunks, {this.version = 0}) {
    for (final c in chunks) {
      final tf = <String, double>{};
      void add(String text, double w) {
        for (final t in _terms(text)) {
          tf[t] = (tf[t] ?? 0) + w;
        }
      }

      add(c.title, _kTitleWeight);
      add('${c.moduleName} ${c.section}', _kSectionWeight);
      add(c.text, _kBodyWeight);
      _tf.add(tf);
      _len.add(tf.values.fold(0.0, (a, b) => a + b));
      for (final t in tf.keys) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
    }
    _avgLen = _len.isEmpty ? 1 : _len.reduce((a, b) => a + b) / _len.length;
  }

  HelpChunk? byId(String? id) {
    if (id == null) return null;
    for (final c in chunks) {
      if (c.id == id) return c;
    }
    return null;
  }

  double _idf(String t) {
    final df = _df[t] ?? 0;
    return math.log(1 + (chunks.length - df + 0.5) / (df + 0.5));
  }

  /// Câu hỏi → từ khoá có trọng số (từ gốc 1.0, đồng nghĩa 0.5).
  Map<String, double> _queryTerms(String query) {
    final q = <String, double>{};
    for (final t in _terms(query)) {
      q[t] = math.max(q[t] ?? 0, 1.0);
    }
    final folded = ' ${foldVietnamese(_prep(query))} ';
    for (final group in _kSynonyms) {
      if (!group.any((g) => folded.contains(' $g '))) continue;
      for (final g in group) {
        for (final t in _terms(g)) {
          q[t] = math.max(q[t] ?? 0, 0.5);
        }
      }
    }
    return q;
  }

  /// Số ý chính của câu hỏi mà cả bộ hướng dẫn không hề nhắc tới (kiểu "tuyển", "vàng", "thời tiết")
  /// — có từ như vậy thì câu hỏi nhiều khả năng nằm ngoài hướng dẫn.
  int unknownWords(String query) => {
    for (final t in _terms(query))
      if (!t.contains(' ') && !_df.containsKey(t)) t,
  }.length;

  /// Tỉ lệ ý chính (từ đơn không phải từ hư) của câu hỏi có trong đoạn — tính cả từ đồng nghĩa.
  /// Trả (tỉ lệ, số ý chính).
  (double, int) coverage(String query, HelpChunk chunk) {
    final i = chunks.indexOf(chunk);
    if (i < 0) return (0, 0);
    final tf = _tf[i];
    final words = {
      for (final t in _terms(query))
        if (!t.contains(' ')) t,
    };
    if (words.isEmpty) return (0, 0);
    final folded = ' ${foldVietnamese(_prep(query))} ';
    var hit = 0;
    for (final w in words) {
      if (tf.containsKey(w)) {
        hit++;
        continue;
      }
      // từ thuộc một cụm đồng nghĩa có trong câu hỏi → khớp nếu đoạn có từ của cụm khác cùng nhóm
      final ok = _kSynonyms.any(
        (g) =>
            g.any((p) => folded.contains(' $p ') && ' $p '.contains(' $w ')) &&
            g.any((p) => _terms(p).every(tf.containsKey)),
      );
      if (ok) hit++;
    }
    return (hit / words.length, words.length);
  }

  List<HelpHit> search(String query, {int topK = 3}) {
    final q = _queryTerms(query);
    if (q.isEmpty) return const [];
    final howTo = _kHowToCue.hasMatch(' ${foldVietnamese(query)} ');
    // hỏi giới thiệu / định nghĩa → bài "… là gì" không bị giảm điểm (QC 26/10: "tính năng chấm công", "khác gì")
    final askWhat = RegExp(
      r' la (cai )?gi | la j | gom (nhung )?gi | (de|dung) lam gi | dung de | khac (gi|nhau)| la sao | tac dung | tinh nang | gioi thieu ',
    ).hasMatch(' ${foldVietnamese(query)} ');
    final hits = <HelpHit>[];
    for (var i = 0; i < chunks.length; i++) {
      final tf = _tf[i];
      var score = 0.0;
      q.forEach((t, w) {
        final f = tf[t];
        if (f == null) return;
        final norm =
            f * (_k1 + 1) / (f + _k1 * (1 - _b + _b * _len[i] / _avgLen));
        score += w * _idf(t) * norm;
      });
      // Hỏi "cách làm / thế nào" → ưu tiên mục hướng dẫn việc hơn dòng bảng lỗi (tiêu đề ngắn,
      // hay được điểm cao); hỏi bằng nguyên văn thông báo lỗi thì dòng lỗi vẫn thắng.
      if (howTo && chunks[i].section == 'Lỗi thường gặp') score *= 0.85;
      // Bài giới thiệu chung ("Bếp là gì", "Lương là gì") nhiều từ khoá nên hay thắng câu hỏi việc cụ thể
      // (26/10: "bếp đánh dấu món xong", "cài lương theo giờ" trả bài giới thiệu) — trừ khi hỏi đúng "là gì".
      if (!askWhat && chunks[i].id.endsWith('-la-gi')) score *= 0.75;
      if (score > 0) hits.add(HelpHit(chunks[i], score));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(topK).toList();
  }
}

/// Ngưỡng (chỉnh theo bộ câu hỏi kiểm tra — test/features/ai_assistant/boom_help_eval_test.dart;
/// 23/10: câu lạc đề cao nhất 15,4 điểm, câu đúng đa số ≥ 17). Trả lời thẳng khi
///  • điểm ≥ 17, đoạn đầu phủ ≥ 50% ý chính của câu hỏi và câu có ≥ 2 ý chính, hoặc
///  • điểm ≥ 12, phủ ≥ 75% và câu có ≥ 2 ý chính;
/// và câu hỏi không có từ nào lạ hoàn toàn với bộ hướng dẫn;
/// gợi ý chủ đề khi điểm ≥ 10 và phủ ≥ 50%; còn lại coi như không có trong hướng dẫn.
/// Đổi bài hướng dẫn nhiều → chạy lại bộ kiểm tra, chỉnh ngưỡng nếu cần.
const kHelpStrongScore = 17.0;
const kHelpClearMargin = 1.15;
const kHelpAnswerScore = 12.0;
const kHelpSuggestScore = 10.0;
const kHelpAnswerCoverage = 0.75;
const kHelpSuggestCoverage = 0.5;

/// Không đủ chắc để trả lời / gợi ý nhưng đoạn đầu ≥ 11 điểm → vẫn gửi 3 đoạn đầu cho GPT tự chọn (GPT nói "chưa
/// thấy" nếu không khớp). Kiểm tra GPT 24/10: câu hỏi app bị bỏ có đoạn đúng trong 3 đoạn đầu ở 11,5–35 điểm (vướng
/// từ lạ / độ phủ); câu lạc đề hầu hết < 11.
const kHelpWeakScore = 11.0;

enum HelpDecision { answer, suggest, none }

class HelpResult {
  final HelpDecision decision;
  final List<HelpHit> hits;

  /// Tới 8 đoạn đầu (3 đoạn [hits] + 5 đoạn kế) — gửi GPT khi bộ tìm chưa chắc để GPT tự chọn đoạn đúng (26/10:
  /// bài đúng trong 3 đoạn đầu 93–99% nhưng app trả lời thẳng đúng chỉ 42–68%; bộ 128 câu mới: đoạn đúng trong 5 đầu
  /// 80%, 8 đầu 88%). Gợi ý cho người dùng vẫn 3 mục.
  final List<HelpHit> wider;
  const HelpResult(this.decision, this.hits, [List<HelpHit>? wider])
    : wider = wider ?? hits;
}

HelpResult decideHelp(HelpIndex index, String query) {
  final wider = index.search(query, topK: 8);
  final hits = wider.take(3).toList();
  if (hits.isEmpty) return const HelpResult(HelpDecision.none, []);
  final top = hits.first.score;
  final (cov, n) = index.coverage(query, hits.first.chunk);
  final unknown = index.unknownWords(query);
  // Hai đoạn đầu điểm sát nhau (< 15%) → không đoán, đưa 3 lựa chọn (đo 23/10: trả lời sai 17% → 8%).
  final clearWinner =
      hits.length < 2 || top >= hits[1].score * kHelpClearMargin;
  if (unknown == 0 &&
      clearWinner &&
      ((top >= kHelpStrongScore && cov >= kHelpSuggestCoverage && n >= 2) ||
          (top >= kHelpAnswerScore && cov >= kHelpAnswerCoverage && n >= 2))) {
    return HelpResult(HelpDecision.answer, hits, wider);
  }
  if (top >= kHelpSuggestScore && cov >= kHelpSuggestCoverage) {
    return HelpResult(HelpDecision.suggest, hits, wider);
  }
  return HelpResult(HelpDecision.none, hits, wider);
}

/// Các đoạn gửi GPT: chắc chắn → đoạn đầu + đoạn cùng bài trong [HelpResult.wider] (26/10: "vào ca chấm công" —
/// đoạn "Vào ca" đứng thứ 4); chưa chắc → cả [HelpResult.wider] để GPT tự chọn đoạn đúng.
List<HelpChunk> helpChunksForGpt(HelpResult r, {required bool sure}) {
  if (r.hits.isEmpty) return const [];
  final first = r.hits.first.chunk;
  return sure
      ? [
          first,
          for (final h in r.wider.skip(1))
            if (h.chunk.module == first.module) h.chunk,
        ]
      : [for (final h in r.wider) h.chunk];
}

/// Câu trả lời hiển thị trong bong bóng chat.
String formatHelpAnswer(HelpChunk c) {
  final where = [
    c.moduleName,
    if (c.section.isNotEmpty && c.section != 'Các việc thường làm') c.section,
  ].join(' › ');
  final head = c.section == 'Lỗi thường gặp'
      ? 'Gặp: ${c.title}'
      : c.title.replaceFirst(RegExp(r'^\d+\.\s*'), '');
  final text = c.text
      .replaceAllMapped(RegExp(r'\.\s*\.(\s|$)'), (m) => '.${m.group(1)}')
      .trim();
  return '📘 $head\n\n$text\n\n— Tra trong hướng dẫn: $where';
}

/// Nguồn ngắn ghi dưới câu trả lời: "Quản lý Bàn › Sửa, giảm, huỷ món".
String helpSourceLabel(HelpChunk c) =>
    '${c.moduleName} › ${c.title.replaceFirst(RegExp(r'^\d+\.\s*'), '')}';

/// Nhãn gợi ý ngắn (bấm vào sẽ hỏi lại đúng chủ đề).
String helpSuggestionLabel(HelpChunk c) {
  final t = c.title.replaceFirst(RegExp(r'^\d+\.\s*'), '').replaceAll('"', '');
  final short = t.length > 48 ? '${t.substring(0, 45)}…' : t;
  return '${c.moduleName}: $short';
}

/// Câu có động từ thao tác / hỏi cách làm (so khớp NGUYÊN TỪ sau khi bỏ dấu) — dùng để nhường câu
/// bị bộ đoán ý xếp vào loại số liệu ("tắt bán món hết", "thêm nhân viên mới") cho bộ hướng dẫn.
/// Không gồm "thế nào" / "làm gì": "doanh thu hôm nay thế nào" vẫn là câu hỏi số liệu.
const _kActionPhrases = [
  'cach',
  'lam sao',
  'o dau',
  'cho nao',
  'huong dan',
  'kieu gi',
  'sao de',
  'bang cach',
  'chi to',
  'chi minh',
  'them',
  'tao',
  'xoa',
  'huy',
  'sua',
  'tat',
  'bat',
  'duyet',
  'nap',
  'in',
  'xuat',
  'nhap',
  'chuyen',
  'gop',
  'chinh',
  'ghi',
  'khoa',
  'quen',
  'cau hinh',
  'thiet lap',
  'bam',
  'set',
  'cai dat',
];

/// Động từ dễ trùng từ thường khi bỏ dấu (cài/cái, mở/mờ, ẩn/ăn, gắn/gần, đặt/đạt, đổi/đợi):
/// chỉ nhận khi viết có dấu đúng.
// "mở" không đưa vào: "ca mở cửa" (số liệu) và "mở bàn" (thao tác) đều viết y hệt.
const _kAccentedActionWords = ['cài', 'ẩn', 'gắn', 'đặt', 'đổi'];

bool hasHelpActionWord(String query) {
  // bộ F 27/10: "trà sữa" bỏ dấu thành "sua" (= "sửa"); "chuyển khoản" là cách trả tiền, không phải thao tác chuyển
  // câu có dấu: "sữa" (ữ) luôn là đồ uống, khác "sửa" (ử) — QC đợt 15 ("sữa dừa", "ly sữa")
  query = query.replaceAll(RegExp('sữa', caseSensitive: false), ' ');
  query = query.replaceAll(
    RegExp(
      // "bất thường" bỏ dấu thành "bat" (= "bật") — QC đợt 15
      r'bất thường|\bbat thuong\b|trà sữa|sữa (?:tươi|đặc|chua|bột|hạt|bò|đá|nóng)|(?:cà phê|cafe|cf) sữa|chuyển khoản|chuyen khoan|'
      // gõ không dấu: "tra sua", "sua dac" là sữa (đợt 13); "cà phê sữa đá" (bộ O, đợt 15)
      r'\btra sua\b|\bsua (?:tuoi|dac|bot|hat|da|nong)\b|\b(?:ca phe|cafe|cf) sua\b',
      caseSensitive: false,
    ),
    ' ',
  );
  final padded = ' ${foldVietnamese(query)} ';
  if (_kActionPhrases.any((p) => padded.contains(' $p '))) return true;
  final lower =
      ' ${query.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ').trim()} ';
  return _kAccentedActionWords.any((w) => lower.contains(' $w '));
}
