// 14/11/2026: cập nhật Android treo mãi khi mạng đứng (không hết giờ chờ, không nút huỷ),
// bấm lại phải tải lại từ đầu ~125 MB. Giờ: hết giờ báo lỗi, bấm Thử lại tải tiếp phần còn thiếu.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/app_update_manager.dart';

void main() {
  final data = List<int>.generate(1000, (i) => i % 256);
  late HttpServer server;
  late Directory dir;
  bool stall = false;
  final ranges = <String?>[];

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('cap_nhat');
    ranges.clear();
    stall = false;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final from = range == null ? 0 : int.parse(range.split('=')[1].split('-')[0]);
      if (from >= data.length) {
        req.response.statusCode = 416;
        await req.response.close();
        return;
      }
      req.response.bufferOutput = false; // gửi ngay từng phần, giống mạng thật
      req.response.statusCode = range == null ? 200 : 206;
      req.response.contentLength = data.length - from;
      if (stall) {
        // Gửi một nửa rồi đứng im, không đóng kết nối.
        req.response.add(data.sublist(from, from + 300));
        await req.response.flush();
        return;
      }
      req.response.add(data.sublist(from));
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  String url() => 'http://127.0.0.1:${server.port}/a.apk';

  test('mạng đứng: báo lỗi sau hết giờ, bấm lại tải tiếp phần còn thiếu', () async {
    final path = '${dir.path}/QuanNhoPOS-36.apk';
    stall = true;
    await expectLater(
      AppUpdateManager.downloadFileWithProgress(
        url: url(),
        targetPath: path,
        onProgress: (_) {},
        resume: true,
        idleTimeout: const Duration(milliseconds: 300),
      ),
      throwsA(isA<Exception>()),
    );
    expect(File(path).lengthSync(), 300);

    stall = false;
    double last = 0;
    await AppUpdateManager.downloadFileWithProgress(
      url: url(),
      targetPath: path,
      onProgress: (p) => last = p,
      resume: true,
    );
    expect(ranges.last, 'bytes=300-');
    expect(File(path).readAsBytesSync(), data);
    expect(last, 1.0);

    // Đã đủ: lần sau không tải lại.
    await AppUpdateManager.downloadFileWithProgress(
      url: url(),
      targetPath: path,
      onProgress: (_) {},
      resume: true,
    );
    expect(ranges.last, 'bytes=1000-');
    expect(File(path).readAsBytesSync(), data);
  });

  test('không bật tải tiếp (Windows) thì tải lại từ đầu', () async {
    final path = '${dir.path}/a.exe';
    File(path).writeAsBytesSync([1, 2, 3]);
    await AppUpdateManager.downloadFileWithProgress(url: url(), targetPath: path, onProgress: (_) {});
    expect(ranges.last, isNull);
    expect(File(path).readAsBytesSync(), data);
  });

  test('hộp cập nhật: nội dung thu gọn, có nút huỷ khi đang tải', () {
    final src = File('lib/core/services/app_update_manager.dart').readAsStringSync();
    expect(src, contains('bool showNotes = false;'));
    expect(src, contains("'Xem nội dung cập nhật'"));
    expect(src, contains("'Huỷ tải'"));
    expect(src, contains("QuanNhoPOS-\${versionInfo.buildNumber}.apk"));
  });
}
