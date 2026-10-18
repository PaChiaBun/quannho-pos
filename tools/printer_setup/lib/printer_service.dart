// Phát hiện máy in (USB, mạng LAN, máy in Windows đã có) và dựng máy in "QN-..." chuẩn.
// Máy in dựng bằng driver có sẵn của Windows ("Generic / Text Only") nên không cần driver hãng:
// POS gửi lệnh ESC/POS thô qua hàng đợi này (in bill, cắt giấy, mở két).
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'app_log.dart';
import 'ps_runner.dart';
import 'store_settings.dart';

const kGenericDriver = 'Generic / Text Only';

enum PrinterRole {
  thuNgan('ThuNgan', 'Thu ngân (in hoá đơn, mở két)'),
  bep('Bep', 'Bếp nóng'),
  bar('Bar', 'Bếp bar (đồ uống)'),
  tem('Tem', 'Tem dán ly');

  final String code; // hậu tố tên máy in
  final String label;
  const PrinterRole(this.code, this.label);

  /// Tiêu đề in to trên tờ nhận diện (không dấu để máy in nào cũng in được).
  String get slipTitle => switch (this) {
        PrinterRole.thuNgan => 'MAY IN THU NGAN',
        PrinterRole.bep => 'MAY IN BEP NONG',
        PrinterRole.bar => 'MAY IN BEP BAR',
        PrinterRole.tem => 'MAY IN TEM DAN LY',
      };

  /// Tên ngắn để hiện trong tiến trình.
  String get shortLabel => switch (this) {
        PrinterRole.thuNgan => 'thu ngân',
        PrinterRole.bep => 'bếp nóng',
        PrinterRole.bar => 'bếp bar',
        PrinterRole.tem => 'tem dán ly',
      };

  /// Tên hàng đợi máy in kèm tên quán, ví dụ QN-KAY-Rach-Gia-ThuNgan.
  String queueName(String storeName) => queueNameFor(storeName, code);
}

enum DetectedKind { usb, lan }

class DetectedPrinter {
  final DetectedKind kind;
  final String title; // tên hiển thị
  final String detail; // thông tin phụ (cổng, IP, VID/PID)
  final String? usbPort; // USB001...
  final String? ip;
  const DetectedPrinter({
    required this.kind,
    required this.title,
    required this.detail,
    this.usbPort,
    this.ip,
  });
}

class InstalledQueue {
  final String name;
  final String driver;
  final String port;
  final String comment; // "QN;paper=80" do công cụ ghi để POS biết khổ giấy
  const InstalledQueue(this.name, this.driver, this.port, [this.comment = '']);

  /// Khổ giấy ghi trong ghi chú của máy in (mặc định 80mm).
  int get paperMm => RegExp(r'paper=(\d+)').firstMatch(comment)?.group(1) == '58' ? 58 : 80;
  bool get isQn => name.startsWith('QN-');

  /// Vai trò suy ra từ hậu tố tên (…-ThuNgan, …-Bep…), null nếu không khớp.
  PrinterRole? get role {
    for (final r in PrinterRole.values) {
      if (name == 'QN-${r.code}' || name.endsWith('-${r.code}')) return r;
    }
    return null;
  }
}

/// Hãng thường gặp theo mã nhà sản xuất USB (VID). Chỉ để hiển thị tên cho dễ nhận.
const Map<String, String> kVendorByVid = {
  '04B8': 'Epson',
  '0456': 'Analog Devices / POS',
  '0483': 'Xprinter / STMicro',
  '0416': 'Winbond / POS',
  '0519': 'Star Micronics',
  '0DD4': 'Custom',
  '0FE6': 'ICS / POS',
  '1504': 'Bixolon',
  '154F': 'SNBC',
  '1659': 'Prolific / POS',
  '1FC9': 'NXP / POS',
  '28E9': 'GigaDevice / POS',
  '0471': 'Philips / POS',
  '067B': 'Prolific',
  '1A86': 'QinHeng / POS',
  '4B43': 'Gprinter / POS',
  '6868': 'Zjiang / POS',
};

String vendorFromInstanceId(String id) {
  final m = RegExp(r'VID_([0-9A-Fa-f]{4})').firstMatch(id);
  if (m == null) return '';
  return kVendorByVid[m.group(1)!.toUpperCase()] ?? '';
}

/// Các dải IPv4 /24 của máy này (bỏ loopback/link-local) để dò máy in mạng.
List<String> subnetPrefixes(Iterable<String> ipv4Addresses) {
  final out = <String>{};
  for (final a in ipv4Addresses) {
    final p = a.split('.');
    if (p.length != 4) continue;
    if (p[0] == '127' || (p[0] == '169' && p[1] == '254')) continue;
    out.add('${p[0]}.${p[1]}.${p[2]}');
  }
  return out.toList()..sort();
}

class PrinterService {
  const PrinterService._();

  // ── Phát hiện ───────────────────────────────────────────────────────────────
  static Future<List<InstalledQueue>> listQueues() async {
    final rows = await PsRunner.runJsonList(
        r'Get-Printer | Select-Object Name,DriverName,PortName,Comment | ConvertTo-Json -Compress',
        label: 'liệt kê máy in Windows');
    return [
      for (final r in rows)
        InstalledQueue('${r['Name']}', '${r['DriverName']}', '${r['PortName']}', '${r['Comment'] ?? ''}')
    ];
  }

  /// Máy in cắm USB: cổng USBxxx do Windows tạo khi thấy thiết bị loại máy in,
  /// kèm tên thiết bị lấy từ danh sách thiết bị đang cắm.
  static Future<List<DetectedPrinter>> scanUsb() async {
    final ports = await PsRunner.runJsonList(
        r"Get-PrinterPort | Where-Object { $_.Name -match '^USB\d+' } | Select-Object Name,Description | ConvertTo-Json -Compress", label: 'dò cổng USB');
    final devices = await PsRunner.runJsonList(
        r"Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -like 'USB\VID_*' -and ($_.Class -in 'Printer','USB' -or $_.FriendlyName -match 'print|pos|receipt|usb') } | Select-Object FriendlyName,InstanceId,Class | ConvertTo-Json -Compress", label: 'dò thiết bị USB');
    final names = <String>[];
    for (final d in devices) {
      final cls = '${d['Class']}';
      final fn = '${d['FriendlyName']}';
      if (cls == 'Printer' || RegExp('print|pos|receipt', caseSensitive: false).hasMatch(fn)) {
        final v = vendorFromInstanceId('${d['InstanceId']}');
        names.add(v.isEmpty ? fn : '$fn ($v)');
      }
    }
    AppLog.info('USB: ${ports.length} cổng, thiết bị máy in: ${names.isEmpty ? '(không)' : names.join('; ')}');
    // Windows giữ lại cổng USB của máy in từng cắm (kể cả đã rút). Nếu số cổng nhiều hơn số máy in
    // đang cắm thật thì lấy các cổng số lớn nhất (cổng mới nhất) để khỏi tạo máy in "ma".
    ports.sort((a, b) => '${a['Name']}'.compareTo('${b['Name']}'));
    if (names.isNotEmpty && ports.length > names.length) {
      AppLog.info('USB: ${ports.length} cổng nhưng chỉ ${names.length} máy in đang cắm — chỉ dùng ${names.length} cổng mới nhất.');
      ports.removeRange(0, ports.length - names.length);
    }
    final result = <DetectedPrinter>[];
    for (var i = 0; i < ports.length; i++) {
      final port = '${ports[i]['Name']}';
      final title = i < names.length ? names[i] : 'Máy in USB';
      result.add(DetectedPrinter(
        kind: DetectedKind.usb,
        title: title,
        detail: 'Cổng $port',
        usbPort: port,
      ));
    }
    return result;
  }

  /// Dò máy in mạng: thử kết nối cổng 9100 trên các dải IP của máy này.
  static Future<List<DetectedPrinter>> scanLan({
    void Function(int done, int total)? onProgress,
  }) async {
    final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
    final prefixes = subnetPrefixes(
        [for (final i in ifaces) for (final a in i.addresses) a.address]);
    AppLog.info('LAN: quét dải ${prefixes.isEmpty ? '(không có mạng IPv4)' : prefixes.join(', ')}');
    final targets = [
      for (final p in prefixes) for (var h = 1; h <= 254; h++) '$p.$h'
    ];
    final found = <String>[];
    var done = 0;
    Future<void> probe(String ip) async {
      try {
        final s = await Socket.connect(ip, 9100,
            timeout: const Duration(milliseconds: 350));
        s.destroy();
        found.add(ip);
      } catch (_) {}
      done++;
      onProgress?.call(done, targets.length);
    }

    const batch = 64;
    for (var i = 0; i < targets.length; i += batch) {
      await Future.wait(targets.skip(i).take(batch).map(probe));
    }
    found.sort();
    AppLog.info('LAN: tìm thấy ${found.length} máy mở cổng 9100: ${found.join(', ')}');
    return [
      for (final ip in found)
        DetectedPrinter(
          kind: DetectedKind.lan,
          title: 'Máy in mạng',
          detail: 'IP $ip (cổng 9100)',
          ip: ip,
        )
    ];
  }

  // ── Dựng máy in ─────────────────────────────────────────────────────────────
  /// Tạo (hoặc dựng lại) máy in [role] cho thiết bị đã phát hiện. Trả null nếu thành công,
  /// ngược lại là thông báo lỗi.
  static Future<String?> install(
      DetectedPrinter dev, PrinterRole role, String storeName,
      {int paperMm = 80}) async {
    final name = role.queueName(storeName);
    final String portScript;
    final String port;
    if (dev.kind == DetectedKind.lan) {
      port = 'IP_${dev.ip}';
      portScript = '''
if (-not (Get-PrinterPort -Name '$port' -ErrorAction SilentlyContinue)) {
  Add-PrinterPort -Name '$port' -PrinterHostAddress '${dev.ip}' -PortNumber 9100
}''';
    } else {
      port = dev.usbPort ?? '';
      portScript = '';
    }
    if (port.isEmpty) return 'Không xác định được cổng máy in.';
    final script = '''
if (-not (Get-PrinterDriver -Name '$kGenericDriver' -ErrorAction SilentlyContinue)) {
  Add-PrinterDriver -Name '$kGenericDriver'
}
$portScript
if (Get-Printer -Name '$name' -ErrorAction SilentlyContinue) { Remove-Printer -Name '$name' }
Add-Printer -Name '$name' -DriverName '$kGenericDriver' -PortName '$port' -Comment 'QN;paper=$paperMm'
Write-Output 'OK'
''';
    AppLog.info('Cài $name: loại ${dev.kind.name}, cổng $port${dev.ip != null ? ', IP ${dev.ip}' : ''}');
    final r = await PsRunner.run(script, label: 'cài $name');
    if (r.ok && r.out.contains('OK')) return null;
    return r.err.isNotEmpty ? r.err : r.out;
  }

  static Future<String?> remove(String name) async {
    final r = await PsRunner.run("Remove-Printer -Name '$name'; Write-Output 'OK'",
        label: 'gỡ $name');
    return r.ok ? null : (r.err.isNotEmpty ? r.err : r.out);
  }

  // ── Gửi lệnh thô (in thử, mở két) ───────────────────────────────────────────
  static const _rawScript = r'''
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class QnRawPrn {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public class DOCINFOW {
    [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
  }
  [DllImport("winspool.drv", EntryPoint = "OpenPrinterW", SetLastError = true, CharSet = CharSet.Unicode)]
  public static extern bool OpenPrinter(string n, out IntPtr h, IntPtr d);
  [DllImport("winspool.drv", SetLastError = true)]
  public static extern bool ClosePrinter(IntPtr h);
  [DllImport("winspool.drv", EntryPoint = "StartDocPrinterW", SetLastError = true, CharSet = CharSet.Unicode)]
  public static extern bool StartDocPrinter(IntPtr h, int level, [In] DOCINFOW di);
  [DllImport("winspool.drv", SetLastError = true)]
  public static extern bool EndDocPrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError = true)]
  public static extern bool StartPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError = true)]
  public static extern bool EndPagePrinter(IntPtr h);
  [DllImport("winspool.drv", SetLastError = true)]
  public static extern bool WritePrinter(IntPtr h, byte[] b, int c, out int w);
  public static bool Send(string name, byte[] bytes) {
    IntPtr h;
    if (!OpenPrinter(name, out h, IntPtr.Zero)) return false;
    var di = new DOCINFOW();
    di.pDocName = "QuanNho setup";
    di.pDataType = "RAW";
    bool ok = false;
    if (StartDocPrinter(h, 1, di)) {
      if (StartPagePrinter(h)) {
        int w;
        ok = WritePrinter(h, bytes, bytes.Length, out w);
        EndPagePrinter(h);
      }
      EndDocPrinter(h);
    }
    ClosePrinter(h);
    return ok;
  }
}
"@
$bytes = [System.IO.File]::ReadAllBytes($env:QN_FILE)
if ([QnRawPrn]::Send($env:QN_PRN, $bytes)) { Write-Output 'QN_OK' } else { Write-Output 'QN_FAIL' }
''';

  static Future<bool> sendRaw(String queue, Uint8List bytes) async {
    final f = File('${Directory.systemTemp.path}\\qn_raw_${DateTime.now().microsecondsSinceEpoch}.bin');
    try {
      await f.writeAsBytes(bytes);
      final r = await PsRunner.run(_rawScript,
          env: {'QN_PRN': queue, 'QN_FILE': f.path}, label: 'gửi lệnh thô tới $queue (${bytes.length} byte)');
      return r.ok && r.out.contains('QN_OK');
    } finally {
      try { await f.delete(); } catch (_) {}
    }
  }

  /// Tờ nhận diện: tên vai trò in CHỮ TO ở giữa tờ (không dấu cho mọi máy in) rồi cắt giấy,
  /// để chủ quán dán/ghi nhớ máy nào là máy nào.
  static Uint8List identifySlip(PrinterRole role, String queueName, {String storeName = ''}) {
    final out = <int>[];
    void cmd(List<int> c) => out.addAll(c);
    void text(String t) => out.addAll(removeDiacritics(t).codeUnits.map((c) => c > 127 ? 0x3F : c));
    cmd([0x1B, 0x40]); // khởi tạo
    cmd([0x1B, 0x61, 0x01]); // căn giữa
    text('\n');
    if (storeName.trim().isNotEmpty) {
      cmd([0x1B, 0x45, 0x01]); // đậm
      text('${storeName.trim().toUpperCase()}\n');
      cmd([0x1B, 0x45, 0x00]);
    }
    text('\n');
    cmd([0x1D, 0x21, 0x11]); // chữ cao + rộng gấp đôi
    cmd([0x1B, 0x45, 0x01]);
    text('${role.slipTitle}\n');
    cmd([0x1B, 0x45, 0x00]);
    cmd([0x1D, 0x21, 0x00]);
    text('\n($queueName)\n\n');
    text('To nay in ra tu may nao\nthi may do la: ${role.slipTitle.replaceFirst('MAY IN ', '').toLowerCase()}\n\n');
    text('Hay ghi/dan nhan len may in\nde khong bi nham.\n');
    text('Neu sai, chon lai vai tro\ntrong cong cu cai may in.\n\n\n');
    cmd([0x1D, 0x56, 0x42, 0x00]); // cắt giấy (nạp thêm giấy rồi cắt)
    return Uint8List.fromList(out);
  }

  static Uint8List get drawerKick => Uint8List.fromList(
      [0x1B, 0x70, 0x00, 0x19, 0xFA, 0x1B, 0x70, 0x01, 0x19, 0xFA]);

  static String _ascii(String s) {
    const map = {
      'À': 'A','Á': 'A','Ả': 'A','Ã': 'A','Ạ': 'A','Ă': 'A','Ắ': 'A','Ằ': 'A','Ẳ': 'A','Ẵ': 'A','Ặ': 'A','Â': 'A','Ấ': 'A','Ầ': 'A','Ẩ': 'A','Ẫ': 'A','Ậ': 'A',
      'È': 'E','É': 'E','Ẻ': 'E','Ẽ': 'E','Ẹ': 'E','Ê': 'E','Ế': 'E','Ề': 'E','Ể': 'E','Ễ': 'E','Ệ': 'E',
      'Ì': 'I','Í': 'I','Ỉ': 'I','Ĩ': 'I','Ị': 'I',
      'Ò': 'O','Ó': 'O','Ỏ': 'O','Õ': 'O','Ọ': 'O','Ô': 'O','Ố': 'O','Ồ': 'O','Ổ': 'O','Ỗ': 'O','Ộ': 'O','Ơ': 'O','Ớ': 'O','Ờ': 'O','Ở': 'O','Ỡ': 'O','Ợ': 'O',
      'Ù': 'U','Ú': 'U','Ủ': 'U','Ũ': 'U','Ụ': 'U','Ư': 'U','Ứ': 'U','Ừ': 'U','Ử': 'U','Ữ': 'U','Ự': 'U',
      'Ỳ': 'Y','Ý': 'Y','Ỷ': 'Y','Ỹ': 'Y','Ỵ': 'Y','Đ': 'D',
    };
    return s.split('').map((c) => map[c] ?? c).join();
  }

  static Future<bool> identify(PrinterRole role, String queueName, {String storeName = ''}) =>
      sendRaw(queueName, identifySlip(role, queueName, storeName: storeName));

  static Future<bool> kickDrawer(String queueName) => sendRaw(queueName, drawerKick);

  static String asciiForTest(String s) => _ascii(s);
}
