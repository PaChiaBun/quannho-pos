// test/core/khong_gui_x_user_id_test.dart
// Kế hoạch JWT Pha 2: app không còn gắn header x-user-id cho Supabase REST.
// Đọc nguyên văn mã nguồn lib/ (chống ai đó thêm lại sau này).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib/ không gán headers[\'x-user-id\'] cho Supabase', () {
    final offenders = <String>[];
    final assign = RegExp(r'''headers\[\s*['"]x-user-id['"]\s*\]\s*=''');
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (assign.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });

  test('kiểm ngữ cảnh Lương không còn đòi header x-user-id', () {
    final src = File(
      'lib/modules/tinhluong/repository/payroll_srm_repository.dart',
    ).readAsStringSync();
    expect(src.contains("headers['x-user-id']"), isFalse);
  });
}
