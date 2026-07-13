import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

// ─────────────────────────────────────────────────────────────────────────────
// THERMAL PRINTER SERVICE — Kết nối TCP/IP đến máy in nhiệt Wi-Fi
// Hỗ trợ: Xprinter, Epson ESC/POS, SNBC, Gprinter, ...
// Port mặc định: 9100 (raw TCP)
// ─────────────────────────────────────────────────────────────────────────────

class ThermalPrinterService {
  static const int _defaultPort = 9100;
  static const Duration _timeout = Duration(seconds: 5);

  // ── ESC/POS Constants ─────────────────────────────────────────────────────
  static const int ESC = 0x1B;
  static const int GS  = 0x1D;
  static const int LF  = 0x0A;
  static const int CR  = 0x0D;

  static final Uint8List _init          = Uint8List.fromList([ESC, 0x40]);
  static final Uint8List _cutPaper      = Uint8List.fromList([GS, 0x56, 0x41, 0x00]);
  static final Uint8List _cutPartial    = Uint8List.fromList([GS, 0x56, 0x42, 0x00]);
  static final Uint8List _alignLeft     = Uint8List.fromList([ESC, 0x61, 0x00]);
  static final Uint8List _alignCenter   = Uint8List.fromList([ESC, 0x61, 0x01]);
  static final Uint8List _alignRight    = Uint8List.fromList([ESC, 0x61, 0x02]);
  static final Uint8List _bold          = Uint8List.fromList([ESC, 0x45, 0x01]);
  static final Uint8List _boldOff       = Uint8List.fromList([ESC, 0x45, 0x00]);
  static final Uint8List _doubleWidth   = Uint8List.fromList([ESC, 0x21, 0x20]);
  static final Uint8List _doubleSize    = Uint8List.fromList([ESC, 0x21, 0x30]);
  static final Uint8List _normalSize    = Uint8List.fromList([ESC, 0x21, 0x00]);

  // ──────────────────────────────────────────────────────────────────────────
  // PRINT KITCHEN TICKET
  // ──────────────────────────────────────────────────────────────────────────
  static Future<PrintResult> printKitchenTicket({
    required String printerIp,
    int port = _defaultPort,
    required String tableLabel,
    required String zoneLabel,
    required int round,
    required List<TicketItemData> items,
    int sentAt = 0,
    String? waiterName,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(printerIp, port, timeout: _timeout);

      final buffer = BytesBuilder();
      final time = _formatTime(sentAt);
      final divider = '--------------------------------';

      // ── Init ──
      buffer.add(_init);
      buffer.add(_alignCenter);

      // ── Header: Tên quán ──
      buffer.add(_doubleSize);
      buffer.add(_bold);
      buffer.add(_utf8('QUAN NHO POS\n'));
      buffer.add(_normalSize);
      buffer.add(_boldOff);
      buffer.add(_utf8('Phieu Bep\n'));
      buffer.add(_utf8('$time\n'));
      buffer.add(_utf8('$divider\n'));

      // ── Bàn + Đợt ──
      buffer.add(_alignLeft);
      buffer.add(_bold);
      buffer.add(_doubleWidth);
      buffer.add(_utf8('$tableLabel  Dot $round\n'));
      buffer.add(_normalSize);
      buffer.add(_boldOff);
      buffer.add(_utf8('Khu: $zoneLabel\n'));
      if (waiterName != null && waiterName.isNotEmpty) {
        buffer.add(_utf8('NV Order: $waiterName\n'));
      }
      buffer.add(_utf8('$divider\n'));

      // ── Danh sách món ──
      for (final item in items) {
        if (item.isCancelled) {
          buffer.add(_utf8('[HUY] ${item.quantity.toInt()}x ${_truncate(item.name, 22)}\n'));
          continue;
        }

        buffer.add(_bold);
        buffer.add(_utf8('${item.quantity.toInt()}x ${_truncate(item.name, 26)}\n'));
        buffer.add(_boldOff);

        // Modifiers (nếu có)
        if (item.modifiers.isNotEmpty) {
          for (final mod in item.modifiers) {
            buffer.add(_utf8('   + $mod\n'));
          }
        }
        // Ghi chú
        if (item.note != null && item.note!.isNotEmpty) {
          buffer.add(_utf8('   Ghi chu: ${item.note}\n'));
        }
      }

      buffer.add(_utf8('$divider\n'));
      buffer.add(_alignCenter);
      buffer.add(_utf8('--- HET PHIEU ---\n'));
      buffer.add(_utf8('\n\n\n'));

      // ── Cắt giấy ──
      buffer.add(_cutPartial);

      // Gửi dữ liệu
      socket.add(buffer.toBytes());
      await socket.flush();
      await socket.close();

      return PrintResult.success;
    } on SocketException catch (e) {
      return PrintResult.connectionError(
          'Không kết nối được: ${e.message} ($printerIp:$port)');
    } on TimeoutException {
      return PrintResult.connectionError(
          'Hết thời gian kết nối ($printerIp:$port)');
    } catch (e) {
      return PrintResult.connectionError('Lỗi in: $e');
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // TEST CONNECTION — Ping thử máy in
  // ──────────────────────────────────────────────────────────────────────────
  static Future<PrintResult> testConnection({
    required String printerIp,
    int port = _defaultPort,
  }) async {
    Socket? socket;
    try {
      socket = await Socket.connect(printerIp, port, timeout: _timeout);
      final buffer = BytesBuilder();
      buffer.add(_init);
      buffer.add(_alignCenter);
      buffer.add(_bold);
      buffer.add(_utf8('QUAN NHO POS\n'));
      buffer.add(_boldOff);
      buffer.add(_utf8('Ket noi thanh cong!\n'));
      buffer.add(_utf8('IP: $printerIp:$port\n'));
      buffer.add(_utf8('\n\n\n'));
      buffer.add(_cutPartial);
      socket.add(buffer.toBytes());
      await socket.flush();
      await socket.close();
      return PrintResult.success;
    } on SocketException catch (e) {
      return PrintResult.connectionError(e.message);
    } on TimeoutException {
      return PrintResult.connectionError('Timeout');
    } catch (e) {
      return PrintResult.connectionError('$e');
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────────────────────

  /// Convert string sang UTF-8 bytes (ESC/POS chỉ dùng Latin, tiếng Việt cần
  /// font hỗ trợ. Fallback: strip diacritics cho máy in giá rẻ)
  static Uint8List _utf8(String text) {
    return Uint8List.fromList(
      utf8.encode(_latinize(text)),
    );
  }

  /// Chuyển tiếng Việt có dấu → không dấu (cho máy in chỉ hỗ trợ ASCII)
  static String _latinize(String s) {
    const map = {
      'à': 'a', 'á': 'a', 'ả': 'a', 'ã': 'a', 'ạ': 'a',
      'ă': 'a', 'ằ': 'a', 'ắ': 'a', 'ẳ': 'a', 'ẵ': 'a', 'ặ': 'a',
      'â': 'a', 'ầ': 'a', 'ấ': 'a', 'ẩ': 'a', 'ẫ': 'a', 'ậ': 'a',
      'è': 'e', 'é': 'e', 'ẻ': 'e', 'ẽ': 'e', 'ẹ': 'e',
      'ê': 'e', 'ề': 'e', 'ế': 'e', 'ể': 'e', 'ễ': 'e', 'ệ': 'e',
      'ì': 'i', 'í': 'i', 'ỉ': 'i', 'ĩ': 'i', 'ị': 'i',
      'ò': 'o', 'ó': 'o', 'ỏ': 'o', 'õ': 'o', 'ọ': 'o',
      'ô': 'o', 'ồ': 'o', 'ố': 'o', 'ổ': 'o', 'ỗ': 'o', 'ộ': 'o',
      'ơ': 'o', 'ờ': 'o', 'ớ': 'o', 'ở': 'o', 'ỡ': 'o', 'ợ': 'o',
      'ù': 'u', 'ú': 'u', 'ủ': 'u', 'ũ': 'u', 'ụ': 'u',
      'ư': 'u', 'ừ': 'u', 'ứ': 'u', 'ử': 'u', 'ữ': 'u', 'ự': 'u',
      'ỳ': 'y', 'ý': 'y', 'ỷ': 'y', 'ỹ': 'y', 'ỵ': 'y',
      'đ': 'd',
      'À': 'A', 'Á': 'A', 'Ả': 'A', 'Ã': 'A', 'Ạ': 'A',
      'Ă': 'A', 'Ằ': 'A', 'Ắ': 'A', 'Ẳ': 'A', 'Ẵ': 'A', 'Ặ': 'A',
      'Â': 'A', 'Ầ': 'A', 'Ấ': 'A', 'Ẩ': 'A', 'Ẫ': 'A', 'Ậ': 'A',
      'È': 'E', 'É': 'E', 'Ẻ': 'E', 'Ẽ': 'E', 'Ẹ': 'E',
      'Ê': 'E', 'Ề': 'E', 'Ế': 'E', 'Ể': 'E', 'Ễ': 'E', 'Ệ': 'E',
      'Ì': 'I', 'Í': 'I', 'Ỉ': 'I', 'Ĩ': 'I', 'Ị': 'I',
      'Ò': 'O', 'Ó': 'O', 'Ỏ': 'O', 'Õ': 'O', 'Ọ': 'O',
      'Ô': 'O', 'Ồ': 'O', 'Ố': 'O', 'Ổ': 'O', 'Ỗ': 'O', 'Ộ': 'O',
      'Ơ': 'O', 'Ờ': 'O', 'Ớ': 'O', 'Ở': 'O', 'Ỡ': 'O', 'Ợ': 'O',
      'Ù': 'U', 'Ú': 'U', 'Ủ': 'U', 'Ũ': 'U', 'Ụ': 'U',
      'Ư': 'U', 'Ừ': 'U', 'Ứ': 'U', 'Ử': 'U', 'Ữ': 'U', 'Ự': 'U',
      'Ỳ': 'Y', 'Ý': 'Y', 'Ỷ': 'Y', 'Ỹ': 'Y', 'Ỵ': 'Y',
      'Đ': 'D',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }

  static String _truncate(String s, int max) =>
      s.length > max ? '${s.substring(0, max - 2)}..' : s;

  static String _formatTime(int ms) {
    if (ms == 0) {
      final now = DateTime.now();
      return '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')} '
          '${now.day}/${now.month}/${now.year}';
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')} '
        '${dt.day}/${dt.month}/${dt.year}';
  }

  // ──────────────────────────────────────────────────────────────────────────
  // OPEN CASH DRAWER — Mở két tiền kết nối với máy in bill
  // ──────────────────────────────────────────────────────────────────────────
  static Future<void> openCashDrawer({
    required String printerIp,
    int port = _defaultPort,
  }) async {
    Socket? socket;
    try {
      print('[openCashDrawer] Connecting to IP: $printerIp');
      socket = await Socket.connect(printerIp, port, timeout: const Duration(seconds: 2));
      // Mã lệnh ESC/POS mở két tiền (Pin 2 và Pin 5)
      socket.add(Uint8List.fromList([0x1B, 0x70, 0x00, 0x19, 0xFA]));
      socket.add(Uint8List.fromList([0x1B, 0x70, 0x01, 0x19, 0xFA]));
      await socket.flush();
      await Future.delayed(const Duration(milliseconds: 100)); // Delay để máy in kịp nhận lệnh trước khi ngắt kết nối
      await socket.close();
      print('[openCashDrawer] Sent drawer kick command successfully.');
    } catch (e) {
      print('[openCashDrawer Error] Failed to kick drawer on $printerIp: $e');
    } finally {
      try { socket?.destroy(); } catch (_) {}
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────
class TicketItemData {
  final String name;
  final double quantity;
  final List<String> modifiers;
  final String? note;
  final bool isCancelled;

  const TicketItemData({
    required this.name,
    required this.quantity,
    this.modifiers = const [],
    this.note,
    this.isCancelled = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULT
// ─────────────────────────────────────────────────────────────────────────────
class PrintResult {
  final bool ok;
  final String? error;

  const PrintResult._({required this.ok, this.error});

  static const PrintResult success = PrintResult._(ok: true);
  static PrintResult connectionError(String msg) =>
      PrintResult._(ok: false, error: msg);

  @override
  String toString() => ok ? 'PrintResult.success' : 'PrintResult.error($error)';
}
