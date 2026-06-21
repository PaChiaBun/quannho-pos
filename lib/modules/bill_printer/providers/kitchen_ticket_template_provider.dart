// lib/modules/bill_printer/providers/kitchen_ticket_template_provider.dart
// Model & Provider cho phiếu bếp — lưu SharedPreferences riêng biệt với hoá đơn khách
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class KitchenTicketTemplate {
  final String paperSize;      // '58mm' | '80mm'
  final String headerText;     // Tiêu đề phiếu — mặc định 'PHIẾU BẾP'
  final bool showOrderNumber;  // Số đơn (#001)
  final bool showDateTime;     // Thời gian gọi món
  final bool showTableName;    // Tên bàn — NÊN BẬT
  final bool showNote;         // Ghi chú đặc biệt của khách (ít cay, không hành...)
  final bool showDivider;      // Đường kẻ phân cách các phần
  final int headerFontSize;    // Cỡ chữ tiêu đề (14–22)
  final int tableFontSize;     // Cỡ chữ tên bàn (14–22) — nên to để đọc nhanh
  final int itemFontSize;      // Cỡ chữ tên món (12–18)
  final int qtyFontSize;       // Cỡ số lượng (16–28) — nên rất to, bếp nhìn xa
  final bool boldItemName;     // In đậm tên món

  const KitchenTicketTemplate({
    this.paperSize      = '80mm',
    this.headerText     = 'PHIẾU BẾP',
    this.showOrderNumber = true,
    this.showDateTime   = true,
    this.showTableName  = true,
    this.showNote       = true,
    this.showDivider    = true,
    this.headerFontSize = 18,
    this.tableFontSize  = 16,
    this.itemFontSize   = 14,
    this.qtyFontSize    = 22,
    this.boldItemName   = true,
  });

  // ── Serialization ───────────────────────────────────────────────────────────
  static const _kPrefix = 'kitch_tpl_';

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('${_kPrefix}paper',       paperSize);
    await p.setString('${_kPrefix}header',      headerText);
    await p.setBool  ('${_kPrefix}orderNo',     showOrderNumber);
    await p.setBool  ('${_kPrefix}datetime',    showDateTime);
    await p.setBool  ('${_kPrefix}table',       showTableName);
    await p.setBool  ('${_kPrefix}note',        showNote);
    await p.setBool  ('${_kPrefix}divider',     showDivider);
    await p.setInt   ('${_kPrefix}hfont',       headerFontSize);
    await p.setInt   ('${_kPrefix}tfont',       tableFontSize);
    await p.setInt   ('${_kPrefix}ifont',       itemFontSize);
    await p.setInt   ('${_kPrefix}qfont',       qtyFontSize);
    await p.setBool  ('${_kPrefix}bold',        boldItemName);
  }

  static Future<KitchenTicketTemplate> load() async {
    final p = await SharedPreferences.getInstance();
    return KitchenTicketTemplate(
      paperSize:      p.getString('${_kPrefix}paper')   ?? '80mm',
      headerText:     p.getString('${_kPrefix}header')  ?? 'PHIẾU BẾP',
      showOrderNumber: p.getBool ('${_kPrefix}orderNo') ?? true,
      showDateTime:   p.getBool  ('${_kPrefix}datetime')  ?? true,
      showTableName:  p.getBool  ('${_kPrefix}table')     ?? true,
      showNote:       p.getBool  ('${_kPrefix}note')      ?? true,
      showDivider:    p.getBool  ('${_kPrefix}divider')   ?? true,
      headerFontSize: p.getInt   ('${_kPrefix}hfont')     ?? 18,
      tableFontSize:  p.getInt   ('${_kPrefix}tfont')     ?? 16,
      itemFontSize:   p.getInt   ('${_kPrefix}ifont')     ?? 14,
      qtyFontSize:    p.getInt   ('${_kPrefix}qfont')     ?? 22,
      boldItemName:   p.getBool  ('${_kPrefix}bold')      ?? true,
    );
  }

  KitchenTicketTemplate copyWith({
    String? paperSize,
    String? headerText,
    bool? showOrderNumber,
    bool? showDateTime,
    bool? showTableName,
    bool? showNote,
    bool? showDivider,
    int? headerFontSize,
    int? tableFontSize,
    int? itemFontSize,
    int? qtyFontSize,
    bool? boldItemName,
  }) => KitchenTicketTemplate(
    paperSize:       paperSize      ?? this.paperSize,
    headerText:      headerText     ?? this.headerText,
    showOrderNumber: showOrderNumber ?? this.showOrderNumber,
    showDateTime:    showDateTime   ?? this.showDateTime,
    showTableName:   showTableName  ?? this.showTableName,
    showNote:        showNote       ?? this.showNote,
    showDivider:     showDivider    ?? this.showDivider,
    headerFontSize:  headerFontSize ?? this.headerFontSize,
    tableFontSize:   tableFontSize  ?? this.tableFontSize,
    itemFontSize:    itemFontSize   ?? this.itemFontSize,
    qtyFontSize:     qtyFontSize    ?? this.qtyFontSize,
    boldItemName:    boldItemName   ?? this.boldItemName,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class KitchenTicketTemplateNotifier extends Notifier<KitchenTicketTemplate> {
  @override
  KitchenTicketTemplate build() {
    _load();
    return const KitchenTicketTemplate(); // default trước khi load xong
  }

  Future<void> _load() async {
    state = await KitchenTicketTemplate.load();
  }

  void update(KitchenTicketTemplate t) => state = t;

  Future<void> save() async => await state.save();

  Future<void> reset() async {
    state = const KitchenTicketTemplate();
    await state.save();
  }
}

final kitchenTicketTemplateProvider =
    NotifierProvider<KitchenTicketTemplateNotifier, KitchenTicketTemplate>(
  KitchenTicketTemplateNotifier.new,
);
