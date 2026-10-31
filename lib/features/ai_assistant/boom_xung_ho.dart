// Cách Bé Boom gọi người dùng (26/10: Chủ Quán chấm sai câu "Gọi chế xưng bé" bị từ chối — trước chỉ có Anh / Chị).
// Danh sách CỐ ĐỊNH (máy chủ kiểm cùng danh sách) — người dùng không chèn được chữ tuỳ ý vào câu dặn GPT.
const kBoomDanhXung = <String, String>{
  'anh': 'Anh',
  'chi': 'Chị',
  'em': 'Em',
  'co': 'Cô',
  'chu': 'Chú',
  'bac': 'Bác',
  'che': 'Chế',
  'ong': 'Ông',
  'ba': 'Bà',
  'di': 'Dì',
  'thay': 'Thầy',
};

const _danhToCode = <String, String>{
  'anh': 'anh',
  'chị': 'chi',
  'em': 'em',
  'cô': 'co',
  'chú': 'chu',
  'bác': 'bac',
  'chế': 'che',
  'ông': 'ong',
  'bà': 'ba',
  'dì': 'di',
  'thầy': 'thay',
};

const _danh = r'(anh|chị|em|cô|chú|bác|chế|ông|bà|dì|thầy)';
const _xung =
    r'(?:\s*[,.]?\s*(?:và\s+|rồi\s+|còn\s+)?(?:tự\s+)?xưng\s+(?:là\s+)?\p{L}+(?:\s+boom)?)?';
const _dem = r'(?:\s*(?:nhé|nha|nhá|nghen|nhen|ạ|nhe))?';
// Hai dạng (QC 26/10: "gọi anh Tuấn", "gọi bà chủ", "kêu em ơi" là gọi NGƯỜI KHÁC, không phải đổi cách gọi):
//  1. "gọi tôi / mình / em … là|bằng <danh> [tên]" — có chủ ngữ + "là / bằng" mới cho kèm tên ("gọi em là cô Lan")
//  2. "gọi <danh>" trần, chỉ kèm "xưng …" và tiếng đệm ("gọi chế xưng bé", "gọi cô nhé")
final _xungHoCmd = RegExp(
  r'^(?:(?:bé\s+)?boom\s+ơi[\s,!]*)?(?:(?:từ\s+giờ|từ\s+nay|sau\s+này|hãy|cứ|thì)\s+)*(?:gọi|kêu)\s+'
  '(?:(?:tôi|tui|mình|tớ|tao|ta|em)\\s+(?:là|bằng)\\s+$_danh(?:\\s+\\p{L}+)?$_xung(?:$_dem|\\s+đi)?'
  '|$_danh$_xung$_dem)\\s*[.!]*\$',
  unicode: true,
);

/// Câu nhắn đổi cách gọi ("Gọi chế xưng bé", "gọi tôi là cô nhé", "Gọi tôi là Anh") → mã cách gọi; null = không phải câu đổi cách gọi.
String? parseXungHoCommand(String text) {
  final t = text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  // shortcut: không chuẩn hoá dấu tổ hợp (NFD) — gõ kiểu tổ hợp thì không nhận, Boom trả lời như câu hỏi thường
  final m = _xungHoCmd.firstMatch(t);
  return m == null ? null : _danhToCode[m.group(1) ?? m.group(2)];
}
