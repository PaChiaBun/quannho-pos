import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';

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
  static const _kPrefsKey = 'qn_kitchen_ticket_template';

  Map<String, dynamic> toMap() => {
    'paper':       paperSize,
    'header':      headerText,
    'orderNo':     showOrderNumber,
    'datetime':    showDateTime,
    'table':       showTableName,
    'note':        showNote,
    'divider':     showDivider,
    'hfont':       headerFontSize,
    'tfont':       tableFontSize,
    'ifont':       itemFontSize,
    'qfont':       qtyFontSize,
    'bold':        boldItemName,
  };

  factory KitchenTicketTemplate.fromMap(Map<String, dynamic> m) => KitchenTicketTemplate(
    paperSize:      m['paper']   ?? '80mm',
    headerText:     m['header']  ?? 'PHIẾU BẾP',
    showOrderNumber: m['orderNo'] ?? true,
    showDateTime:   m['datetime']  ?? true,
    showTableName:  m['table']     ?? true,
    showNote:       m['note']      ?? true,
    showDivider:    m['divider']   ?? true,
    headerFontSize: m['hfont']     ?? 18,
    tableFontSize:  m['tfont']     ?? 16,
    itemFontSize:   m['ifont']     ?? 14,
    qtyFontSize:    m['qfont']     ?? 22,
    boldItemName:   m['bold']      ?? true,
  );

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    final json = jsonEncode(toMap());
    await p.setString(_kPrefsKey, json);

    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId != null) {
        // Đảm bảo x-store-id tồn tại trong Header REST cho RLS
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;

        await Supabase.instance.client.from('app_settings').upsert({
          'id': const Uuid().v4(),
          'store_id': storeId,
          'key': _kPrefsKey,
          'value': json,
        }, onConflict: 'store_id,key');
      }
    } catch (_) {}
  }

  static Future<KitchenTicketTemplate> load() async {
    String? raw;
    try {
      final p = await SharedPreferences.getInstance();
      raw = p.getString(_kPrefsKey);
    } catch (_) {}

    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'];
      if (storeId != null) {
        // Đảm bảo x-store-id tồn tại trong Header REST cho RLS
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;

        final res = await Supabase.instance.client
            .from('app_settings')
            .select('value')
            .eq('store_id', storeId)
            .eq('key', _kPrefsKey)
            .maybeSingle();
        if (res != null && res['value'] != null) {
          final cloudJson = res['value'] as String;
          if (cloudJson != raw) {
            raw = cloudJson;
            final p = await SharedPreferences.getInstance();
            await p.setString(_kPrefsKey, cloudJson);
          }
        }
      }
    } catch (_) {}

    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        return KitchenTicketTemplate.fromMap(map);
      } catch (_) {}
    }
    return const KitchenTicketTemplate();
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
