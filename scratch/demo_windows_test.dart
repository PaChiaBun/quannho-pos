// Công cụ tạm: in các cửa sổ thời gian (kỳ + kỳ so sánh) mà màn Báo cáo chuỗi sẽ gọi, để lấy JSON thật từ bản sao DB.
// Chạy: flutter test scratch/demo_windows_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/utils/chain_compare.dart';

const _out = '/private/tmp/claude-501/-Users-banhbao-Quan-Nho/df98e5d3-74fa-4f4d-ba97-04d7b7626014/scratchpad/windows.txt';

void main() {
  test('in cửa sổ', () {
    final b = StringBuffer();
    for (final p in ChainPeriod.values) {
      for (final off in [0, -1, -2]) {
        final w = windowFor(p, off);
        b.writeln('${p.name}_${off}_cur ${w.from.toUtc().toIso8601String()} ${w.to.toUtc().toIso8601String()}');
        if (w.compareTo.isAfter(w.compareFrom)) {
          b.writeln('${p.name}_${off}_cmp ${w.compareFrom.toUtc().toIso8601String()} ${w.compareTo.toUtc().toIso8601String()}');
        }
      }
    }
    File(_out).writeAsStringSync(b.toString());
  });
}
