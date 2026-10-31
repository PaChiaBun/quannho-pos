// lib/modules/bill_printer/routing/print_setup.dart
// Mô hình "tách 3 thứ": MÁY IN (PrinterEntry) – LUẬT IN (PrintRule) – MẪU IN (templateKey).
// Thuần Dart, không phụ thuộc Flutter/Supabase để test được. Lưu dưới dạng JSON
// (app_settings key `qn_print_setup_v3`).

/// Loại phiếu cần in.
enum PrintJobType { receipt, provisional, kitchenHot, kitchenBar, label, report }

/// Hình thức phục vụ của đơn.
enum PrintServiceType { dineIn, takeaway, qr, delivery }

/// Cách kết nối tới máy in.
enum PrinterKind { system, lan, sunmiBuiltin }

/// Khổ giấy.
enum PaperWidth { mm50, mm58, mm80 }

List _list(Object? raw) => raw is List ? raw : const [];

T _enumByName<T extends Enum>(List<T> values, Object? raw, T fallback) {
  if (raw is! String) return fallback;
  for (final v in values) {
    if (v.name == raw) return v;
  }
  return fallback;
}

/// Một máy in vật lý do chủ quán đặt tên.
class PrinterEntry {
  final String id;
  final String name; // tên hiển thị, vd "Bill quầy"
  final PrinterKind kind;
  final String address; // tên máy in hệ thống hoặc IP (kind == lan)
  final int port; // chỉ dùng cho lan
  final PaperWidth paper;
  final bool autoCut;
  final bool hasCashDrawer;
  final String? ownerDeviceId; // máy in gắn vào thiết bị nào (vd Sunmi tích hợp)
  final bool enabled;

  /// Tỉ lệ cỡ chữ khi in ra máy này (0,5–1,5; 1,0 = đúng cỡ chữ trong mẫu). Nhỏ hơn 1 => chữ nhỏ lại.
  final double fontScale;

  /// Độ đậm nét chữ khi in ảnh (1 = mảnh ... 5 = rất đậm; 3 = vừa). Chỉ có tác dụng với máy in in bằng ảnh.
  final int darkness;

  /// Chữ đậm dùng nét "bán đậm" (SemiBold) thay vì Bold. Mặc định TẮT: thử trên Sunmi V3 thật
  /// (Mật độ in 80%) cho thấy Bold + độ đậm 3 là đẹp nhất. Bật nếu máy in khác bị loe nét đậm.
  final bool softBold;

  const PrinterEntry({
    required this.id,
    required this.name,
    required this.kind,
    this.address = '',
    this.port = 9100,
    this.paper = PaperWidth.mm80,
    this.autoCut = true,
    this.hasCashDrawer = false,
    this.ownerDeviceId,
    this.enabled = true,
    this.fontScale = 1.0,
    this.darkness = 3,
    this.softBold = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'address': address,
        'port': port,
        'paper': paper.name,
        'autoCut': autoCut,
        'hasCashDrawer': hasCashDrawer,
        if (ownerDeviceId != null) 'ownerDeviceId': ownerDeviceId,
        'enabled': enabled,
        if (fontScale != 1.0) 'fontScale': fontScale,
        if (darkness != 3) 'darkness': darkness,
        if (softBold) 'softBold': true,
      };

  factory PrinterEntry.fromJson(Map<String, dynamic> m) => PrinterEntry(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        kind: _enumByName(PrinterKind.values, m['kind'], PrinterKind.system),
        address: m['address'] as String? ?? '',
        port: (m['port'] as num?)?.toInt() ?? 9100,
        paper: _enumByName(PaperWidth.values, m['paper'], PaperWidth.mm80),
        autoCut: m['autoCut'] as bool? ?? true,
        hasCashDrawer: m['hasCashDrawer'] as bool? ?? false,
        ownerDeviceId: m['ownerDeviceId'] as String?,
        enabled: m['enabled'] as bool? ?? true,
        fontScale: ((m['fontScale'] as num?)?.toDouble() ?? 1.0).clamp(0.5, 1.5),
        darkness: ((m['darkness'] as num?)?.toInt() ?? 3).clamp(1, 5),
        softBold: m['softBold'] as bool? ?? false,
      );
}

/// Đích in của một luật: in ra máy nào, mấy bản, dùng mẫu nào.
class PrintTarget {
  final String printerId;
  final int copies;
  final String? templateKey; // null = mẫu mặc định của loại phiếu

  const PrintTarget({
    required this.printerId,
    this.copies = 1,
    this.templateKey,
  });

  Map<String, dynamic> toJson() => {
        'printerId': printerId,
        'copies': copies,
        if (templateKey != null) 'templateKey': templateKey,
      };

  factory PrintTarget.fromJson(Map<String, dynamic> m) => PrintTarget(
        printerId: m['printerId'] as String? ?? '',
        copies: ((m['copies'] as num?)?.toInt() ?? 1).clamp(1, 9),
        templateKey: m['templateKey'] as String?,
      );
}

/// Một luật: khi (loại phiếu + điều kiện) thì in ra các đích.
/// Điều kiện rỗng = khớp mọi giá trị. Luật khớp đầu tiên (priority nhỏ trước) thắng.
class PrintRule {
  final String id;
  final String name;
  final PrintJobType jobType;
  final Set<PrintServiceType> serviceTypes;
  final Set<String> zoneIds;
  final Set<String> sourceDeviceIds; // thiết bị thực hiện thao tác (vd máy Sunmi)
  final List<PrintTarget> targets;
  final String? fallbackPrinterId; // dùng khi mọi máy in của luật không dùng được
  final int priority;
  final bool enabled;

  const PrintRule({
    required this.id,
    required this.name,
    required this.jobType,
    this.serviceTypes = const {},
    this.zoneIds = const {},
    this.sourceDeviceIds = const {},
    this.targets = const [],
    this.fallbackPrinterId,
    this.priority = 100,
    this.enabled = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'jobType': jobType.name,
        'serviceTypes': serviceTypes.map((e) => e.name).toList(),
        'zoneIds': zoneIds.toList(),
        'sourceDeviceIds': sourceDeviceIds.toList(),
        'targets': targets.map((t) => t.toJson()).toList(),
        if (fallbackPrinterId != null) 'fallbackPrinterId': fallbackPrinterId,
        'priority': priority,
        'enabled': enabled,
      };

  factory PrintRule.fromJson(Map<String, dynamic> m) => PrintRule(
        id: m['id'] as String? ?? '',
        name: m['name'] as String? ?? '',
        jobType:
            _enumByName(PrintJobType.values, m['jobType'], PrintJobType.receipt),
        serviceTypes: _list(m['serviceTypes'])
            .map((e) => _enumByName(PrintServiceType.values, e, PrintServiceType.dineIn))
            .toSet(),
        zoneIds: _list(m['zoneIds']).whereType<String>().toSet(),
        sourceDeviceIds:
            _list(m['sourceDeviceIds']).whereType<String>().toSet(),
        targets: _list(m['targets'])
            .whereType<Map>()
            .map((e) => PrintTarget.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        fallbackPrinterId: m['fallbackPrinterId'] as String?,
        priority: (m['priority'] as num?)?.toInt() ?? 100,
        enabled: m['enabled'] as bool? ?? true,
      );
}

/// Toàn bộ thiết lập in của một quán.
class PrintSetup {
  static const int schemaVersion = 1;
  final List<PrinterEntry> printers;
  final List<PrintRule> rules;

  const PrintSetup({this.printers = const [], this.rules = const []});

  bool get isEmpty => printers.isEmpty && rules.isEmpty;

  PrinterEntry? printerById(String id) {
    for (final p in printers) {
      if (p.id == id) return p;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'v': schemaVersion,
        'printers': printers.map((p) => p.toJson()).toList(),
        'rules': rules.map((r) => r.toJson()).toList(),
      };

  factory PrintSetup.fromJson(Map<String, dynamic> m) => PrintSetup(
        printers: _list(m['printers'])
            .whereType<Map>()
            .map((e) => PrinterEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
        rules: _list(m['rules'])
            .whereType<Map>()
            .map((e) => PrintRule.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
}
