// lib/features/ai_assistant/help/huong_dan_parser.dart
// ─────────────────────────────────────────────────────────────────────────────
// Cắt bài hướng dẫn (.docs/Huong_dan/*.md) thành các đoạn cho Boom tra cứu.
// Dart thuần (không Flutter) — dùng chung cho tool/xuat_huong_dan_boom.dart và test.
//
// Quy tắc (ke-hoach-trien-khai-boom.md, Giai đoạn 4.1):
//  • Bỏ front-matter và toàn bộ mục "Ghi chú cho Chủ Quán" (thiếu dấu mốc → lỗi, dừng xuất).
//  • Bỏ ghi chú phiên bản app ("app cũ…", "app bản mới, sau …") — Boom chạy trong app mới.
//  • Mỗi mục ### là một đoạn; mục ## không có mục con là một đoạn; mỗi dòng bảng
//    "Lỗi thường gặp" là một đoạn. Bỏ "Liên quan module khác".
//  • Kiểm lọt tên kỹ thuật: còn sót → lỗi, dừng xuất.
// ─────────────────────────────────────────────────────────────────────────────

class HelpChunk {
  final String id;
  final String module;
  final String moduleName;
  final String section;
  final String title;
  final String text;

  const HelpChunk({
    required this.id,
    required this.module,
    required this.moduleName,
    required this.section,
    required this.title,
    required this.text,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'module': module,
    'module_name': moduleName,
    'section': section,
    'title': title,
    'text': text,
  };

  factory HelpChunk.fromJson(Map<String, dynamic> m) => HelpChunk(
    id: m['id'] as String,
    module: m['module'] as String,
    moduleName: m['module_name'] as String,
    section: m['section'] as String? ?? '',
    title: m['title'] as String,
    text: m['text'] as String,
  );
}

class HuongDanParseException implements Exception {
  final String file;
  final String message;
  HuongDanParseException(this.file, this.message);
  @override
  String toString() => '$file: $message';
}

const kOwnerNotesHeading = '## Ghi chú cho Chủ Quán';
const _kSkipSections = {'Liên quan module khác'};
const _kErrorSection = 'Lỗi thường gặp';

/// Tệp trong .docs/Huong_dan không phải bài module.
const kNonGuideFiles = {
  'MUC-LUC.md',
  'TEMPLATE.md',
  'viec-can-sua.md',
  'ke-hoach-trien-khai-boom.md',
  'goi-tra-sua-mang-di.md',
  'boom-quy-trinh-duyet.md',
};

/// Lỗi lọt tên kỹ thuật / ghi chú phiên bản / câu hỏng (trả danh sách mô tả; rỗng = sạch).
/// Chữ trong "…" là thông báo trên màn hình, người dùng gõ lại nguyên văn → không kiểm tên kỹ thuật.
List<String> lintHelpText(String text) {
  final issues = <String>[];
  final outsideQuotes = text.replaceAll(RegExp(r'"[^"\n]*"'), '""');
  final onText = <String, RegExp>{
    'ghi chú phiên bản': RegExp(
      r'app cũ|bản cũ|app bản mới|bản app|bản phát hành|chưa phát hành|\d{1,2}/\d{1,2}/20\d\d|'
      r'(?:ngày|trước|từ|sau) \d{1,2}/\d{1,2}\b|\[ĐÃ SỬA|\[SỬA',
      caseSensitive: false,
    ),
    'chỗ chưa xác nhận': RegExp(r'\[cần xác nhận\]'),
    'liên kết markdown': RegExp(r'\]\(#'),
    'câu cụt': RegExp(r'(?:^|\s)(?:cho|và|của|với|là)\.\s*$', multiLine: true),
    'câu bắt đầu chữ thường': RegExp(
      r'[.!?]\s+\p{Ll}\p{L}+\s',
      multiLine: true,
      unicode: true,
    ),
  };
  final outside = <String, RegExp>{
    'tên kỹ thuật': RegExp(r'\b[a-z][a-z0-9]*(?:[._][a-z0-9]+)*_[a-z0-9]+\b'),
    'đường dẫn mã nguồn': RegExp(r'\.dart\b|\.sql\b|\blib/|supabase/'),
    'từ kỹ thuật': RegExp(
      r'\bmigration\b|\bRPC\b|\bproduction\b|\bSQL\b|\btrigger\b|\bFIX \d+',
      caseSensitive: false,
    ),
  };
  onText.forEach((name, re) {
    for (final m in re.allMatches(text)) {
      issues.add('$name: "${m.group(0)!.trim()}"');
    }
  });
  outside.forEach((name, re) {
    for (final m in re.allMatches(outsideQuotes)) {
      issues.add('$name: "${m.group(0)}"');
    }
  });
  for (final line in text.split('\n')) {
    final open = '('.allMatches(line).length,
        close = ')'.allMatches(line).length;
    if (open != close) issues.add('ngoặc lệch: "$line"');
  }
  return issues;
}

/// Markdown → chữ đọc được trong bong bóng chat.
String plainText(String md) {
  var s = md;
  s = s.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1)!);
  s = s.replaceAllMapped(
    RegExp(r'(?<![\w*])\*(?!\s)(.+?)(?<!\s)\*(?![\w*])'),
    (m) => m.group(1)!,
  );
  s = s.replaceAllMapped(RegExp(r'`([^`]+)`'), (m) => m.group(1)!);
  s = s.replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]*\)'), (m) => m.group(1)!);
  s = s.replaceAll(RegExp(r'^>\s?', multiLine: true), '');
  s = s.replaceAllMapped(
    RegExp(r'^(\s*)[-*] ', multiLine: true),
    (m) => '${m.group(1)}• ',
  );
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

String _slug(String s) {
  const from =
      'àáảãạăắằẳẵặâấầẩẫậèéẻẽẹêếềểễệìíỉĩịòóỏõọôốồổỗộơớờởỡợùúủũụưứừửữựỳýỷỹỵđ';
  const to =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  final b = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = from.indexOf(ch);
    b.write(i >= 0 ? to[i] : ch);
  }
  final slug = b
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return slug.length > 60
      ? slug.substring(0, 60).replaceAll(RegExp(r'-+$'), '')
      : slug;
}

List<String> _cells(String row) {
  final t = row.trim();
  final inner = t.substring(1, t.endsWith('|') ? t.length - 1 : t.length);
  return inner.split('|').map((c) => c.trim()).toList();
}

bool _isTableRow(String l) => l.trimLeft().startsWith('|');
bool _isTableSep(String l) => RegExp(r'^\s*\|[\s:|-]+\|?\s*$').hasMatch(l);

/// Bảng thường → dòng "A — B — C" (bỏ dòng tiêu đề và vạch kẻ).
String _tableToText(List<String> lines) {
  final out = <String>[];
  List<String>? header;
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    if (!_isTableRow(l)) {
      header = null;
      out.add(l);
      continue;
    }
    if (_isTableSep(l)) continue;
    final nextIsSep = i + 1 < lines.length && _isTableSep(lines[i + 1]);
    if (nextIsSep) {
      header = _cells(l); // dòng tiêu đề bảng
      continue;
    }
    final cells = _cells(l);
    final parts = <String>[
      for (var j = 0; j < cells.length; j++)
        if (cells[j].isNotEmpty && cells[j] != '—')
          j == 0 || header == null || j >= header.length || header[j].isEmpty
              ? cells[j]
              : '${header[j]}: ${cells[j]}',
    ];
    out.add('• ${parts.join(' — ')}');
  }
  return out.join('\n');
}

/// Cắt một bài. [fileName] chỉ dùng để báo lỗi và làm id.
List<HelpChunk> parseGuide(String fileName, String raw) {
  final src = raw.replaceAll('\r\n', '\n');
  if (!src.startsWith('---\n')) {
    throw HuongDanParseException(fileName, 'thiếu front-matter');
  }
  final fmEnd = src.indexOf('\n---\n', 4);
  if (fmEnd < 0) {
    throw HuongDanParseException(fileName, 'front-matter không đóng');
  }
  final fm = src.substring(4, fmEnd);
  String? fmValue(String key) => RegExp(
    '^$key:\\s*(.+)\$',
    multiLine: true,
  ).firstMatch(fm)?.group(1)?.trim();
  final module = fmValue('module');
  final moduleName = fmValue('ten');
  if (module == null || moduleName == null) {
    throw HuongDanParseException(fileName, 'front-matter thiếu module / ten');
  }
  var body = src.substring(fmEnd + 5);
  final notes = body.indexOf(kOwnerNotesHeading);
  if (notes < 0) {
    throw HuongDanParseException(
      fileName,
      'không thấy mục "$kOwnerNotesHeading" — không biết cắt đến đâu',
    );
  }
  body = body.substring(0, notes);

  final lines = body.split('\n');
  final chunks = <HelpChunk>[];
  final base = fileName.replaceAll('.md', '');

  String h2 = '';
  String? curTitle;
  String curSection = '';
  final buf = <String>[];
  var intro = true;

  void flush() {
    final text = buf.join('\n').trim();
    buf.clear();
    if (curTitle == null || text.isEmpty) return;
    final title = curTitle;
    if (_kSkipSections.contains(curSection) || _kSkipSections.contains(title)) {
      return;
    }
    chunks.add(
      HelpChunk(
        id: '$base#${_slug(curSection.isEmpty || curSection == title ? title : '$curSection-$title')}',
        module: module,
        moduleName: moduleName,
        section: curSection == title ? '' : curSection,
        title: title,
        text: plainText(_tableToText(text.split('\n'))),
      ),
    );
  }

  final errorRows = <String>[];
  for (final line in lines) {
    final h = RegExp(r'^(#{1,4})\s+(.+?)\s*$').firstMatch(line);
    if (h != null) {
      final level = h.group(1)!.length;
      final text = h.group(2)!.trim();
      flush();
      if (level == 1) {
        curTitle = '$moduleName là gì';
        curSection = '';
        intro = true;
      } else if (level == 2) {
        intro = false;
        h2 = text;
        curSection = text;
        curTitle = text;
      } else {
        intro = false;
        curSection = h2;
        curTitle = text;
      }
      continue;
    }
    if (!intro && curSection == _kErrorSection && curTitle == _kErrorSection) {
      if (_isTableRow(line)) errorRows.add(line);
      continue;
    }
    buf.add(line);
  }
  flush();

  // Bảng "Lỗi thường gặp": mỗi dòng một đoạn
  final rows = errorRows.where((l) => !_isTableSep(l)).toList();
  if (rows.isNotEmpty) rows.removeAt(0); // tiêu đề bảng
  for (final r in rows) {
    final c = _cells(r);
    if (c.length < 3) continue;
    final seen = plainText(c[0]);
    if (seen.isEmpty) continue;
    chunks.add(
      HelpChunk(
        id: '$base#loi-${_slug(seen)}',
        module: module,
        moduleName: moduleName,
        section: _kErrorSection,
        title: seen,
        text: plainText(
          [
            if (c[1].isNotEmpty && c[1] != '—') 'Vì sao: ${c[1]}',
            if (c[2].isNotEmpty && c[2] != '—') 'Làm gì: ${c[2]}',
          ].join('\n'),
        ),
      ),
    );
  }

  // id phải duy nhất trong bài: trùng (2 dòng lỗi gần giống nhau) → thêm số thứ tự
  final seenIds = <String, int>{};
  return [
    for (final ch in chunks)
      () {
        final n = seenIds.update(ch.id, (v) => v + 1, ifAbsent: () => 1);
        return n == 1
            ? ch
            : HelpChunk(
                id: '${ch.id}-$n',
                module: ch.module,
                moduleName: ch.moduleName,
                section: ch.section,
                title: ch.title,
                text: ch.text,
              );
      }(),
  ];
}

/// Kiểm lọt tên kỹ thuật cho cả bộ; trả danh sách lỗi dạng "id: mô tả".
List<String> lintChunks(List<HelpChunk> chunks) => [
  for (final c in chunks)
    for (final issue in lintHelpText('${c.title}\n${c.text}'))
      '${c.id}: $issue',
];
