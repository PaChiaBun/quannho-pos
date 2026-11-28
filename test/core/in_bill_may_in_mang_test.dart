// LILY 13–14/11/2026: bill thanh toán qua máy in mạng (IP:9100) không ra — app kết nối được
// rồi lại mở hộp in hệ thống (AirPrint) mà máy in nhiệt không nhận, báo "đã huỷ hoặc lỗi kết nối".
// Giờ: vẽ bill thành ảnh, gửi ESC/POS thẳng cổng 9100 như phiếu bếp.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quannho_pos/core/services/thermal_printer_service.dart';

void main() {
  test('gửi lệnh thô tới máy in mạng: máy in nhận đủ byte', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final got = <int>[];
    final done = server.first.then((s) => s.listen(got.addAll).asFuture<void>());
    final data = Uint8List.fromList(List.generate(5000, (i) => i % 256));
    final ok = await ThermalPrinterService.sendRawNetwork('127.0.0.1', data, port: server.port);
    await done;
    await server.close();
    expect(ok, isTrue);
    expect(got, data);
  });

  test('máy in mạng tắt: báo lỗi, không treo', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close();
    expect(await ThermalPrinterService.sendRawNetwork('127.0.0.1', Uint8List(1), port: port), isFalse);
  });

  test('bill máy in mạng đi đường ESC/POS, không mở hộp in hệ thống', () {
    final src = File('lib/modules/bill_printer/screens/bill_preview_screen.dart').readAsStringSync();
    final dispatch = src.substring(
      src.indexOf('static Future<bool> _dispatchPrint('),
      src.indexOf('// ─── Bill Preview Screen'),
    );
    final network = dispatch.substring(dispatch.lastIndexOf('} else {'));
    expect(network, contains('_printRawRaster(bytes, config, jobName, finalFormat)'));
    expect(network, isNot(contains('layoutPdf')));
    expect(src, contains("config.type == 'network'\n          ? await ThermalPrinterService.sendRawNetwork("));
  });
}
