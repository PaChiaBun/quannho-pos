// lib/modules/quick_notes/quick_notes.dart
// ─────────────────────────────────────────────────────────────────────────────
// GHI CHÚ NHANH — chip ghi chú hiện khi gọi món (Ít cay, Ít đá...).
// Lưu trong bảng product_modifiers (group_name = kQuickNoteGroup, giá 0) nên
// mỗi món có bộ chip riêng và được gán từ màn Kho hàng.
// Món chưa được gán chip nào sẽ dùng bộ mặc định theo loại (đồ ăn / đồ uống).
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/product_model.dart';
import '../../core/providers/app_providers.dart';

const kQuickNoteGroup = 'Ghi chú nhanh';

const kFoodNotePresets = [
  'Ít cay',
  'Không cay',
  'Nhiều hành',
  'Ít hành',
  'Không hành',
  'Không tiêu',
  'Không mực',
  'Ít mắm',
  'Thêm rau',
];

const kDrinkNotePresets = [
  'Ít đường',
  'Không đường',
  'Ít đá',
  'Không đá',
  'Nhiều đá',
  'Đá riêng',
];

bool isDrinkProduct(ProductModel p) {
  final text = '${p.category ?? ''} ${p.name}'.toLowerCase();
  const drinkWords = [
    'trà',
    'nước',
    'sinh tố',
    'cà phê',
    'cafe',
    'sữa',
    'đá xay',
    'smoothie',
    'soda',
    'bia',
    'đồ uống',
    'giải khát',
    'matcha',
    'yaourt',
  ];
  return p.stationCode == 'bar' || drinkWords.any(text.contains);
}

List<String> defaultNotePresets(ProductModel? p) {
  if (p == null) return kFoodNotePresets;
  return isDrinkProduct(p) ? kDrinkNotePresets : kFoodNotePresets;
}

/// Chip của 1 món: chỉ gồm chip đã gán trong Kho hàng (không còn chip mặc định).
List<String> notePresetsFor(
  ProductModel? p,
  List<Map<String, dynamic>>? modifiers,
) {
  final assigned = (modifiers ?? const [])
      .where((m) => m['group_name'] == kQuickNoteGroup)
      .map((m) => (m['name'] as String? ?? '').trim())
      .where((n) => n.isNotEmpty)
      .toList();
  return assigned;
}

// ── UI quản lý ───────────────────────────────────────────────────────────────
const _navy = Color(0xFF1E1C5E);
const _orange = Color(0xFFE85D20);
const _cream = Color(0xFFFAF7F2);

Future<void> showQuickNoteManager(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const QuickNoteManagerSheet(),
  );
}

class QuickNoteManagerSheet extends ConsumerStatefulWidget {
  const QuickNoteManagerSheet({super.key});
  @override
  ConsumerState<QuickNoteManagerSheet> createState() =>
      _QuickNoteManagerSheetState();
}

class _QuickNoteManagerSheetState extends ConsumerState<QuickNoteManagerSheet> {
  /// tên ghi chú → các product_id đang được gán
  Map<String, Set<String>> _notes = {};
  bool _loading = true;
  bool _busy = false;

  SupabaseClient get _db => Supabase.instance.client;

  List<ProductModel> get _products {
    final all = ref.read(allProductsProvider).value ?? const [];
    return all
        .where(
          (p) => p.isActive && !p.isDeleted && !p.isTopping && p.sellPrice > 0,
        )
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      await ref.read(allProductsProvider.future);
    } catch (_) {}
    final ids = _products.map((p) => p.id).toList();
    final map = <String, Set<String>>{};
    try {
      // chia nhỏ để không vượt giới hạn độ dài URL
      for (var i = 0; i < ids.length; i += 100) {
        final rows = await _db
            .from('product_modifiers')
            .select('name, product_id')
            .eq('group_name', kQuickNoteGroup)
            .inFilter(
              'product_id',
              ids.sublist(i, (i + 100).clamp(0, ids.length)),
            );
        for (final r in rows as List) {
          final n = (r['name'] as String? ?? '').trim();
          if (n.isEmpty) continue;
          map.putIfAbsent(n, () => {}).add(r['product_id'] as String);
        }
      }
    } catch (e) {
      if (mounted) _toast('Không tải được ghi chú: $e');
    }
    if (mounted)
      setState(() {
        _notes = map;
        _loading = false;
      });
  }

  String _storeOf(String productId) =>
      _products.firstWhere((p) => p.id == productId).storeId;

  String? _err;

  void _toast(String msg) {
    debugPrint('[QuickNotes] $msg');
    if (mounted) setState(() => _err = msg);
  }

  /// Lưu 1 ghi chú: đổi tên + đồng bộ danh sách món được gán.
  Future<void> _save({
    String? oldName,
    required String name,
    required Set<String> productIds,
  }) async {
    setState(() => _busy = true);
    try {
      final before = oldName == null ? <String>{} : (_notes[oldName] ?? {});
      if (oldName != null && oldName != name && before.isNotEmpty) {
        await _db
            .from('product_modifiers')
            .update({'name': name})
            .eq('group_name', kQuickNoteGroup)
            .eq('name', oldName)
            .inFilter('product_id', before.toList());
      }
      final removed = before.difference(productIds);
      final added = productIds.difference(before);
      if (removed.isNotEmpty) {
        await _db
            .from('product_modifiers')
            .delete()
            .eq('group_name', kQuickNoteGroup)
            .eq('name', name)
            .inFilter('product_id', removed.toList());
      }
      if (added.isNotEmpty) {
        await _db.from('product_modifiers').insert([
          for (final id in added)
            {
              'id': const Uuid().v4(),
              'product_id': id,
              'store_id': _storeOf(id),
              'group_name': kQuickNoteGroup,
              'name': name,
              'price_adjust': 0,
              'sort_order': 0,
              'is_active': true,
            },
        ]);
      }
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) _toast('Lưu thất bại: $e');
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xóa ghi chú "$name"?'),
        content: const Text('Chip sẽ biến mất khỏi tất cả các món đang gán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _db
          .from('product_modifiers')
          .delete()
          .eq('group_name', kQuickNoteGroup)
          .eq('name', name)
          .inFilter('product_id', (_notes[name] ?? {}).toList());
    } catch (e) {
      if (mounted) _toast('Xóa thất bại: $e');
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  /// Gán bộ mẫu (đồ ăn / đồ uống) cho các món chưa có chip nào.
  Future<void> _seedDefaults() async {
    final assigned = _notes.values.expand((s) => s).toSet();
    final want = <String, Set<String>>{};
    for (final p in _products) {
      if (assigned.contains(p.id)) continue;
      for (final n in defaultNotePresets(p)) {
        want.putIfAbsent(n, () => {}).add(p.id);
      }
    }
    if (want.isEmpty) {
      _toast('Món nào cũng đã có ghi chú');
      return;
    }
    setState(() => _busy = true);
    try {
      final rows = [
        for (final e in want.entries)
          for (final id in e.value)
            {
              'id': const Uuid().v4(),
              'product_id': id,
              'store_id': _storeOf(id),
              'group_name': kQuickNoteGroup,
              'name': e.key,
              'price_adjust': 0,
              'sort_order': 0,
              'is_active': true,
            },
      ];
      for (var i = 0; i < rows.length; i += 200) {
        await _db
            .from('product_modifiers')
            .insert(rows.sublist(i, (i + 200).clamp(0, rows.length)));
      }
    } catch (e) {
      if (mounted) _toast('Không thêm được bộ mẫu: $e');
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _edit({String? name}) async {
    setState(() => _err = null);
    final res = await showModalBottomSheet<_NoteEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteEditorSheet(
        products: _products,
        initialName: name,
        initialIds: name == null ? {} : (_notes[name] ?? {}),
        existingNames: _notes.keys.where((n) => n != name).toSet(),
      ),
    );
    debugPrint('[QuickNotes] editor result: ${res?.name} ${res?.ids.length}');
    if (res == null) return;
    await _save(oldName: name, name: res.name, productIds: res.ids);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(allProductsProvider); // giữ provider sống & rebuild khi có món
    final names = _notes.keys.toList()..sort();
    final total = _products.length;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: _cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _navy.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Ghi chú nhanh',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _navy,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _edit(),
                    style: FilledButton.styleFrom(backgroundColor: _orange),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Thêm'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Chip hiện khi gọi món. Món nào chưa được gán thì không hiện chip nào.',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: _navy.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Text(_err!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scroll,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (names.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              'Chưa có ghi chú tùy chỉnh. Bấm "Thêm" để tạo, hoặc nạp bộ mẫu bên dưới rồi sửa lại.',
                              style: GoogleFonts.outfit(
                                color: _navy.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        for (final n in names)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.black.withValues(alpha: 0.04),
                              ),
                            ),
                            child: ListTile(
                              onTap: _busy ? null : () => _edit(name: n),
                              title: Text(
                                n,
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w800,
                                  color: _navy,
                                ),
                              ),
                              subtitle: Text(
                                'Gán cho ${_notes[n]!.length}/$total món',
                                style: GoogleFonts.outfit(fontSize: 12),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: _busy ? null : () => _delete(n),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _seedDefaults,
                          icon: const Icon(
                            Icons.auto_fix_high_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Nạp bộ mẫu cho các món chưa có ghi chú',
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteEditResult {
  final String name;
  final Set<String> ids;
  _NoteEditResult(this.name, this.ids);
}

/// Sửa 1 ghi chú: tên + chọn món được gán (lọc theo nhóm, tìm tên).
class _NoteEditorSheet extends StatefulWidget {
  final List<ProductModel> products;
  final String? initialName;
  final Set<String> initialIds;
  final Set<String> existingNames;
  const _NoteEditorSheet({
    required this.products,
    required this.initialName,
    required this.initialIds,
    required this.existingNames,
  });
  @override
  State<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<_NoteEditorSheet> {
  late final TextEditingController _nameCtrl = TextEditingController(
    text: widget.initialName ?? '',
  );
  final _searchCtrl = TextEditingController();
  late final Set<String> _ids = {...widget.initialIds};
  String _category = 'Tất cả';
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<ProductModel> get _visible {
    final q = _searchCtrl.text.trim().toLowerCase();
    return widget.products.where((p) {
      if (_category != 'Tất cả' && (p.category ?? 'Khác') != _category)
        return false;
      return q.isEmpty || p.name.toLowerCase().contains(q);
    }).toList();
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nhập tên ghi chú');
      return;
    }
    if (widget.existingNames.contains(name)) {
      setState(() => _error = 'Ghi chú này đã có');
      return;
    }
    Navigator.pop(context, _NoteEditResult(name, _ids));
  }

  @override
  Widget build(BuildContext context) {
    final cats = <String>{
      'Tất cả',
      ...widget.products.map((p) => p.category ?? 'Khác'),
    }.toList();
    final visible = _visible;
    final allOn =
        visible.isNotEmpty && visible.every((p) => _ids.contains(p.id));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scroll) => Container(
          decoration: const BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Tên ghi chú (vd: Ít đá)',
                    errorText: _error,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Tìm món...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  children: [
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      'Đã chọn ${_ids.length} món',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        color: _navy,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => setState(() {
                        final vIds = visible.map((p) => p.id);
                        allOn ? _ids.removeAll(vIds) : _ids.addAll(vIds);
                      }),
                      child: Text(
                        allOn
                            ? 'Bỏ chọn danh sách này'
                            : 'Chọn cả danh sách này',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: visible.length,
                  itemBuilder: (_, i) {
                    final p = visible[i];
                    return CheckboxListTile(
                      value: _ids.contains(p.id),
                      onChanged: (v) => setState(
                        () => v == true ? _ids.add(p.id) : _ids.remove(p.id),
                      ),
                      title: Text(p.name),
                      subtitle: Text(p.category ?? 'Khác'),
                      dense: true,
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _submit,
                      style: FilledButton.styleFrom(backgroundColor: _navy),
                      child: const Text('Lưu ghi chú'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
