import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/features/ai_assistant/help/huong_dan_parser.dart';

// Bộ cắt bài hướng dẫn cho Boom (ke-hoach-trien-khai-boom.md, 4.1 mục 1).
void main() {
  group('Kiểm lọt / câu hỏng', () {
    test('Bắt đúng lỗi thật', () {
      for (final bad in [
        'Áp dụng cho.',
        'Xong rồi. tải đủ bill của kỳ',
        'Mở bảng (bấm nút',
        'Quyền printer.manage_server bị tắt',
        'Lỗi FIX 11 trên máy chủ',
        'Sửa bảng `ban_session_items`',
        'Có từ app cũ',
        'Từ bản app sau 22/10/2026',
        'Áp dụng từ 23/10',
        'xem [Đối soát](#doi-soat)',
        'Đọc lib/screens/pos_screen.dart',
      ]) {
        expect(lintHelpText(bad), isNotEmpty, reason: bad);
      }
    });

    test(
      'Không chặn nhầm câu đúng và thông báo trên màn hình (trong ngoặc kép)',
      () {
        for (final ok in [
          'Bấm "Lưu". Đơn chuyển sang bếp.',
          'App báo "Bạn không có quyền quản lý máy chủ in (printer.manage_server)."',
          'Quán mới tạo, mã QR mới, phiếu cũ biến mất.',
          'Mỗi ly in một tem (1/2, 2/2).',
        ]) {
          expect(lintHelpText(ok), isEmpty, reason: ok);
        }
      },
    );
  });

  test('Thiếu dấu mốc "Ghi chú cho Chủ Quán" → dừng, không xuất', () {
    expect(
      () => parseGuide(
        'x.md',
        '---\nmodule: x\nten: X\n---\n# X\n## Ai dùng được\n- ai cũng dùng\n',
      ),
      throwsA(isA<HuongDanParseException>()),
    );
  });

  test('Bảng thường giữ tên cột', () {
    final chunks = parseGuide(
      'x.md',
      '---\nmodule: x\nten: X\n---\n# X\n## Hai loại mã\n| | Tại bàn | Mang đi |\n|---|---|---|\n'
          '| Mã | Một mã mỗi bàn | Một mã ở quầy |\n$kOwnerNotesHeading (không đưa cho khách)\n- bí mật\n',
    );
    expect(chunks.single.text, contains('Tại bàn: Một mã mỗi bàn'));
    expect(chunks.single.text, contains('Mang đi: Một mã ở quầy'));
    expect(chunks.single.text, isNot(contains('bí mật')));
  });

  test(
    'Không đoạn nào của phần Chủ Quán / front-matter lọt vào bộ hướng dẫn của Boom',
    () {
      final asset = File('assets/boom_help/huong_dan.json').readAsStringSync();
      final shipped = (jsonDecode(asset)['chunks'] as List)
          .map((c) => '${c['title']}\n${c['text']}')
          .join('\n');
      final norm = shipped.replaceAll(RegExp(r'[\s*`"]+'), ' ');
      final leaks = <String>[];
      for (final f in Directory(
        '.docs/Huong_dan',
      ).listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        if (!name.endsWith('.md') || kNonGuideFiles.contains(name)) continue;
        final raw = f.readAsStringSync();
        final notes = raw.substring(raw.indexOf(kOwnerNotesHeading));
        final front = raw.substring(0, raw.indexOf('\n---\n', 4));
        for (final part in [notes, front]) {
          for (final line in part.split('\n')) {
            final l = line.replaceAll(RegExp(r'[\s*`"]+'), ' ').trim();
            // đoạn ≥ 60 ký tự đủ đặc trưng để không trùng câu chữ chung chung
            for (var i = 0; i + 60 <= l.length; i += 30) {
              final frag = l.substring(i, i + 60);
              if (norm.contains(frag)) leaks.add('$name: "$frag"');
            }
          }
        }
      }
      expect(leaks, isEmpty, reason: leaks.take(20).join('\n'));
    },
  );
}
