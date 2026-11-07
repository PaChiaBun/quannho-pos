import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/huong_dan_nguon.dart';
import '../../tool/xuat_huong_dan_boom.dart' as xuat;

// Giữ bài hướng dẫn khớp app (ke-hoach-trien-khai-boom.md, Giai đoạn 2).
void main() {
  test('Mọi bài ghi nguồn trỏ tới file có thật', () {
    final missing = [
      for (final g in guideFiles())
        for (final t in sourcesOf(g.readAsStringSync()).missing)
          '${g.uri.pathSegments.last}: "$t"',
    ];
    expect(
      missing,
      isEmpty,
      reason: 'Sửa front-matter `nguon:` của bài:\n${missing.join('\n')}',
    );
  });

  test('File nguồn đổi → bài hướng dẫn phải được rà lại rồi đóng dấu', () {
    final saved = readManifest();
    final now = currentHashes();
    final stale = <String>[];
    now.forEach((guide, files) {
      final old = saved[guide];
      if (old == null) {
        stale.add('$guide: bài mới, chưa đóng dấu');
        return;
      }
      final changed = [
        for (final e in files.entries)
          if (old[e.key] != e.value) e.key,
      ];
      if (changed.isNotEmpty) stale.add('$guide: ${changed.join(', ')} đã đổi');
    });
    expect(
      stale,
      isEmpty,
      reason:
          'Bài cần rà lại theo code mới (rồi chạy `dart run tool/xuat_huong_dan_boom.dart` và '
          '`dart run tool/dong_dau_huong_dan.dart <bài>.md`):\n${stale.join('\n')}',
    );
  });

  test('Bộ hướng dẫn cho Boom khớp bài gốc (sửa bài thì phải xuất lại)', () {
    final asset = jsonDecode(File(xuat.kOutFile).readAsStringSync()) as Map;
    final fresh = xuat.contentHash(xuat.buildAllChunks(Directory(kGuideDir)));
    expect(
      asset['hash'],
      fresh,
      reason: 'Chạy `dart run tool/xuat_huong_dan_boom.dart` rồi chạy lại test',
    );
  });
}
