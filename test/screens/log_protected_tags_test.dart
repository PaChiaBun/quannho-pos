import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/screens/log_viewer_screen.dart';

// "Xóa log kỹ thuật" chỉ được xoá log không thuộc nhóm nghiệp vụ; danh sách ở app phải
// phủ đủ danh sách máy chủ bảo vệ (app_log_is_protected_tag).
void main() {
  test(
    'kProtectedLogTags phủ đủ tag máy chủ bảo vệ (bản migration mới nhất)',
    () {
      final sql = File(
        'supabase/migrations/20261022_cung_co_p0_v2.sql',
      ).readAsStringSync();
      final block = RegExp(
        r"lower\(COALESCE\(p_tag, ''\)\) IN \(([^)]*)\)",
        dotAll: true,
      ).firstMatch(sql)!.group(1)!;
      final serverTags = RegExp(
        r"'([a-z_]+)'",
      ).allMatches(block).map((m) => m.group(1)!).toSet();
      expect(serverTags, isNotEmpty);
      final appLower = kProtectedLogTags.map((t) => t.toLowerCase()).toSet();
      expect(
        appLower.containsAll(serverTags),
        isTrue,
        reason: 'thiếu: ${serverTags.difference(appLower)}',
      );
    },
  );

  test('Nút xoá nhật ký lọc bỏ tag nghiệp vụ trước khi xoá', () {
    final src = File('lib/screens/log_viewer_screen.dart').readAsStringSync();
    final start = src.indexOf('Future<void> _clearLogs()');
    final body = src.substring(start, src.indexOf('.delete()', start));
    expect(body, contains("not('tag', 'in'"));
    expect(body, contains('kProtectedLogTags'));
  });
}
