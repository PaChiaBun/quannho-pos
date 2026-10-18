// Cài máy in MỘT LẦN BẤM: dò máy in → tự gán vai trò → cài → in tờ nhận diện.
// Người dùng không phải chọn gì; chỉ chỉnh lại nếu máy nào gán sai vai trò.
import 'dart:convert';
import 'dart:io';
import 'app_log.dart';
import 'printer_service.dart';

/// Khoá cổng của thiết bị phát hiện: cổng USB hoặc "IP_<địa chỉ>" (khớp tên cổng khi cài).
String deviceKey(DetectedPrinter d) =>
    d.kind == DetectedKind.lan ? 'IP_${d.ip}' : (d.usbPort ?? '');

class Assignment {
  final DetectedPrinter device;
  PrinterRole role;
  int paperMm; // 80 hoặc 58
  Assignment(this.device, this.role, {this.paperMm = 80});
}

int _ipNum(String? ip) {
  final p = (ip ?? '').split('.');
  if (p.length != 4) return 0;
  return p.fold(0, (a, b) => a * 256 + (int.tryParse(b) ?? 0));
}

/// Gán vai trò tự động:
/// 1) máy đã có máy in QN-… trên đúng cổng đó giữ nguyên vai trò (chạy lại không đảo vai trò);
/// 2) máy còn lại: USB trước (thường là máy quầy), rồi máy mạng theo IP tăng dần;
///    vai trò theo thứ tự Thu ngân → Bếp nóng → Bếp bar → Tem. Một máy duy nhất = Thu ngân.
List<Assignment> assignRoles(List<DetectedPrinter> devices, List<InstalledQueue> existing) {
  final result = <Assignment>[];
  final used = <PrinterRole>{};
  final pending = <DetectedPrinter>[];
  for (final d in devices) {
    final key = deviceKey(d);
    InstalledQueue? q;
    for (final e in existing) {
      if (e.isQn && e.port == key && e.role != null && !used.contains(e.role)) {
        q = e;
        break;
      }
    }
    if (q != null) {
      used.add(q.role!);
      result.add(Assignment(d, q.role!, paperMm: q.paperMm));
    } else {
      pending.add(d);
    }
  }
  pending.sort((a, b) {
    if (a.kind != b.kind) return a.kind == DetectedKind.usb ? -1 : 1;
    return a.kind == DetectedKind.usb
        ? (a.usbPort ?? '').compareTo(b.usbPort ?? '')
        : _ipNum(a.ip).compareTo(_ipNum(b.ip));
  });
  final free = PrinterRole.values.where((r) => !used.contains(r)).toList();
  for (var i = 0; i < pending.length && i < free.length; i++) {
    result.add(Assignment(pending[i], free[i]));
  }
  if (pending.length > free.length) {
    AppLog.info('Có ${pending.length} máy chưa gán nhưng chỉ còn ${free.length} vai trò — bỏ qua máy dư.');
  }
  result.sort((a, b) => a.role.index.compareTo(b.role.index));
  return result;
}

/// Đổi vai trò của một máy; nếu vai trò mới đang có máy khác giữ thì hai máy hoán đổi cho nhau.
void changeRole(List<Assignment> list, Assignment target, PrinterRole newRole) {
  if (target.role == newRole) return;
  for (final a in list) {
    if (!identical(a, target) && a.role == newRole) a.role = target.role;
  }
  target.role = newRole;
  list.sort((a, b) => a.role.index.compareTo(b.role.index));
}

/// Tên quán đọc từ phần mềm Quán Nhỏ POS đã đăng nhập trên máy này (không phải gõ lại).
/// Tệp cấu hình của POS: %APPDATA%\vn.lpm\quannho_pos\shared_preferences.json (khoá có tiền tố "flutter.").
Future<String> storeNameFromPos() async {
  final roots = <String>[];
  final appData = Platform.environment['APPDATA'];
  if (appData != null) roots.add(appData);
  try {
    final users = Directory('C:\\Users');
    if (await users.exists()) {
      await for (final u in users.list()) {
        if (u is Directory) roots.add('${u.path}\\AppData\\Roaming');
      }
    }
  } catch (_) {}
  for (final r in roots) {
    final f = File('$r\\vn.lpm\\quannho_pos\\shared_preferences.json');
    try {
      if (!await f.exists()) continue;
      final m = jsonDecode(await f.readAsString());
      if (m is! Map) continue;
      for (final k in const ['flutter.auth_store_name', 'flutter.store_name']) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v.trim();
      }
    } catch (_) {}
  }
  return '';
}
