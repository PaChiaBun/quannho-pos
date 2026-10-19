import '../utils/template_cache_policy.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';

/// Khổ tem dán ly: khoá lưu trong mẫu → (rộng mm, cao mm, nhãn hiển thị).
const Map<String, ({double w, double h, String label})> kLabelSizes = {
  '40x30': (w: 40, h: 30, label: '40 × 30 mm'),
  '50x30': (w: 50, h: 30, label: '50 × 30 mm'),
  '60x40': (w: 60, h: 40, label: '60 × 40 mm'),
};

// ─── Model ────────────────────────────────────────────────────────────────────
/// Mẫu tem dán ly (in lẻ từng ly). Mặc định giữ đúng giao diện tem cũ (50×30mm).
class BarLabelTemplate {
  final String sizeKey;        // khoá trong [kLabelSizes]
  final bool showOrderNumber;  // #số đơn
  final bool showTableName;    // tên bàn
  final bool showQtyIndex;     // thứ tự ly: 1/2
  final bool showNote;         // ghi chú / topping
  final bool showTime;         // giờ:phút
  final bool showDivider;      // đường kẻ dưới dòng đầu
  final bool boldName;         // in đậm tên món
  final int nameFontSize;      // cỡ chữ tên món (8–16)
  final int infoFontSize;      // cỡ chữ dòng số đơn/bàn/thứ tự (6–12)
  final int noteFontSize;      // cỡ chữ ghi chú (5–10)

  const BarLabelTemplate({
    this.sizeKey = '50x30',
    this.showOrderNumber = true,
    this.showTableName = true,
    this.showQtyIndex = true,
    this.showNote = true,
    this.showTime = true,
    this.showDivider = true,
    this.boldName = true,
    this.nameFontSize = 10,
    this.infoFontSize = 8,
    this.noteFontSize = 7,
  });

  double get widthMm => (kLabelSizes[sizeKey] ?? kLabelSizes['50x30']!).w;
  double get heightMm => (kLabelSizes[sizeKey] ?? kLabelSizes['50x30']!).h;

  // ── Serialization ───────────────────────────────────────────────────────────
  static const _kPrefsKey = 'qn_bar_label_template';
  static const _kCloudKey = 'qn_bar_label_template';

  Map<String, dynamic> toMap() => {
    'size': sizeKey,
    'orderNo': showOrderNumber,
    'table': showTableName,
    'qtyIdx': showQtyIndex,
    'note': showNote,
    'time': showTime,
    'divider': showDivider,
    'bold': boldName,
    'nfont': nameFontSize,
    'ifont': infoFontSize,
    'cfont': noteFontSize,
  };

  factory BarLabelTemplate.fromMap(Map<String, dynamic> m) {
    final size = m['size'];
    return BarLabelTemplate(
      sizeKey: size is String && kLabelSizes.containsKey(size) ? size : '50x30',
      showOrderNumber: m['orderNo'] ?? true,
      showTableName: m['table'] ?? true,
      showQtyIndex: m['qtyIdx'] ?? true,
      showNote: m['note'] ?? true,
      showTime: m['time'] ?? true,
      showDivider: m['divider'] ?? true,
      boldName: m['bold'] ?? true,
      nameFontSize: (m['nfont'] ?? 10) as int,
      infoFontSize: (m['ifont'] ?? 8) as int,
      noteFontSize: (m['cfont'] ?? 7) as int,
    );
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    final json = jsonEncode(toMap());
    final localStoreId = (await StoreAuthService.getStoreInfo())['store_id'];
    await p.setString(
      _kPrefsKey,
      localStoreId == null ? json : stampTemplateJson(json, localStoreId),
    );

    try {
      final storeId = (await StoreAuthService.getStoreInfo())['store_id'];
      if (storeId != null) {
        // Đảm bảo x-store-id tồn tại trong Header REST cho RLS
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;
        await Supabase.instance.client.from('app_settings').upsert({
          'id': const Uuid().v4(),
          'store_id': storeId,
          'key': _kCloudKey,
          'value': json,
        }, onConflict: 'store_id,key');
      }
    } catch (_) {}
  }

  static Future<BarLabelTemplate> load() async {
    String? localJson;
    try {
      final p = await SharedPreferences.getInstance();
      localJson = p.getString(_kPrefsKey);
    } catch (_) {}

    String? storeId;
    String? cloudJson;
    var cloudReachable = false;
    try {
      final info = await StoreAuthService.getStoreInfo();
      storeId = info['store_id'];
      if (storeId != null) {
        Supabase.instance.client.rest.headers['x-store-id'] = storeId;
        final res = await Supabase.instance.client
            .from('app_settings')
            .select('value')
            .eq('store_id', storeId)
            .eq('key', _kCloudKey)
            .maybeSingle();
        cloudReachable = true;
        if (res != null && res['value'] != null) {
          cloudJson = res['value'] as String;
          final p = await SharedPreferences.getInstance();
          await p.setString(_kPrefsKey, stampTemplateJson(cloudJson, storeId));
        }
      }
    } catch (_) {}

    final raw = storeId == null
        ? null
        : resolveTemplateJson(
            storeId: storeId,
            cloudJson: cloudJson,
            cloudReachable: cloudReachable,
            localJson: localJson,
          );

    if (raw != null) {
      try {
        return BarLabelTemplate.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
    return const BarLabelTemplate();
  }

  BarLabelTemplate copyWith({
    String? sizeKey,
    bool? showOrderNumber,
    bool? showTableName,
    bool? showQtyIndex,
    bool? showNote,
    bool? showTime,
    bool? showDivider,
    bool? boldName,
    int? nameFontSize,
    int? infoFontSize,
    int? noteFontSize,
  }) => BarLabelTemplate(
    sizeKey: sizeKey ?? this.sizeKey,
    showOrderNumber: showOrderNumber ?? this.showOrderNumber,
    showTableName: showTableName ?? this.showTableName,
    showQtyIndex: showQtyIndex ?? this.showQtyIndex,
    showNote: showNote ?? this.showNote,
    showTime: showTime ?? this.showTime,
    showDivider: showDivider ?? this.showDivider,
    boldName: boldName ?? this.boldName,
    nameFontSize: nameFontSize ?? this.nameFontSize,
    infoFontSize: infoFontSize ?? this.infoFontSize,
    noteFontSize: noteFontSize ?? this.noteFontSize,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────
class BarLabelTemplateNotifier extends Notifier<BarLabelTemplate> {
  @override
  BarLabelTemplate build() {
    _load();
    return const BarLabelTemplate(); // mặc định trước khi load xong
  }

  Future<void> _load() async {
    state = await BarLabelTemplate.load();
  }

  void update(BarLabelTemplate t) => state = t;

  Future<void> save() async => await state.save();

  Future<void> reset() async {
    state = const BarLabelTemplate();
    await state.save();
  }
}

final barLabelTemplateProvider =
    NotifierProvider<BarLabelTemplateNotifier, BarLabelTemplate>(
  BarLabelTemplateNotifier.new,
);
