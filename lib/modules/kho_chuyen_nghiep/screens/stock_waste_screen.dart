import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/quantity_formatter.dart';
import '../../kho/providers/kho_providers.dart';
import '../../kho/repository/kho_repository.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';

/// Ghi hao hụt: đổ bỏ, hết hạn, hư hỏng, đổ vỡ, mất. Trừ kho nguyên tử ở server.
class StockWasteScreen extends ConsumerStatefulWidget {
  const StockWasteScreen({super.key});

  @override
  ConsumerState<StockWasteScreen> createState() => _StockWasteScreenState();
}

class _StockWasteScreenState extends ConsumerState<StockWasteScreen> {
  static const _reasons = [
    ('waste', 'Đổ bỏ / hao hụt'),
    ('expired', 'Hết hạn'),
    ('damaged', 'Hư hỏng'),
    ('spill', 'Đổ vỡ'),
    ('loss', 'Mất / thất thoát'),
  ];

  StockItem? _item;
  String _reason = 'waste';
  bool _useSubUnit = false; // nhập theo đơn vị quy cách (ml/g) thay vì đơn vị kho
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  Future<List<Map<String, dynamic>>>? _recent;

  @override
  void initState() {
    super.initState();
    _recent = ref.read(khoProRepositoryProvider).fetchRecentWaste();
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _hasSub => (_item?.conversionRate ?? 0) > 0 && (_item?.conversionUnit ?? '').isNotEmpty;

  /// Số lượng theo ĐƠN VỊ KHO.
  double? get _qtyInStockUnit {
    final v = double.tryParse(_qty.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0 || _item == null) return null;
    if (_useSubUnit && _hasSub) return v / _item!.conversionRate;
    return v;
  }

  Future<void> _pick(List<StockItem> all) async {
    final picked = await showModalBottomSheet<StockItem>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String q = '';
        return StatefulBuilder(builder: (ctx, setM) {
          final list = all
              .where((i) => i.isActive && !i.isTopping && i.name.toLowerCase().contains(q))
              .toList();
          return SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  autofocus: true,
                  onChanged: (v) => setM(() => q = v.trim().toLowerCase()),
                  decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded),
                      hintText: 'Tìm nguyên liệu / hàng hóa...',
                      border: OutlineInputBorder()),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, k) => ListTile(
                    title: Text(list[k].name),
                    subtitle: Text('Tồn: ${fmtQty(list[k].stockQty)} ${list[k].unit}'),
                    onTap: () => Navigator.pop(ctx, list[k]),
                  ),
                ),
              ),
            ]),
          );
        });
      },
    );
    if (picked != null) setState(() {
      _item = picked;
      _useSubUnit = false;
    });
  }

  Future<void> _submit() async {
    final item = _item;
    final q = _qtyInStockUnit;
    if (item == null || q == null) {
      _toast('Chọn mặt hàng và nhập số lượng lớn hơn 0');
      return;
    }
    setState(() => _saving = true);
    try {
      final left = await ref.read(khoProRepositoryProvider).recordStockWaste(
            productId: item.id,
            qty: double.parse(q.toStringAsFixed(4)),
            reason: _reason,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          );
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      _toast('Đã ghi hao hụt ${fmtQty(q)} ${item.unit} — tồn còn ${fmtQty(left)} ${item.unit}');
      setState(() {
        _qty.clear();
        _note.clear();
        _item = null;
        _recent = ref.read(khoProRepositoryProvider).fetchRecentWaste();
      });
    } catch (e) {
      if (mounted) _toast('Lỗi: ${e.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(allStockProvider);
    final all = stockAsync.value ?? const <StockItem>[];
    final nameById = {for (final i in all) i.id: i};
    final q = _qtyInStockUnit;

    return Scaffold(
      backgroundColor: KhoTheme.bg,
      appBar: AppBar(
        backgroundColor: KhoTheme.navy,
        foregroundColor: Colors.white,
        title: Text('Ghi hao hụt',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        InkWell(
          onTap: all.isEmpty ? null : () => _pick(all),
          child: InputDecorator(
            decoration: const InputDecoration(
                labelText: 'Mặt hàng', border: OutlineInputBorder(), suffixIcon: Icon(Icons.arrow_drop_down)),
            child: Text(_item == null
                ? 'Chọn nguyên liệu / hàng hóa...'
                : '${_item!.name}  (tồn ${fmtQty(_item!.stockQty)} ${_item!.unit})'),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final r in _reasons)
            ChoiceChip(
              label: Text(r.$2),
              selected: _reason == r.$1,
              onSelected: (_) => setState(() => _reason = r.$1),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Số lượng hao hụt',
                suffixText: _item == null
                    ? ''
                    : (_useSubUnit && _hasSub ? _item!.conversionUnit : _item!.unit),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (_hasSub) ...[
            const SizedBox(width: 10),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(_item!.unit)),
                ButtonSegment(value: true, label: Text(_item!.conversionUnit)),
              ],
              selected: {_useSubUnit},
              onSelectionChanged: (s) => setState(() => _useSubUnit = s.first),
            ),
          ],
        ]),
        if (q != null && _item != null && _useSubUnit && _hasSub)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '= ${fmtQty(q)} ${_item!.unit} (1 ${_item!.unit} = ${fmtQty(_item!.conversionRate)} ${_item!.conversionUnit})',
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: KhoTheme.muted),
            ),
          ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_sweep_rounded),
            label: const Text('Ghi hao hụt'),
          ),
        ),
        const SizedBox(height: 22),
        Text('Hao hụt gần đây',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 6),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _recent,
          builder: (_, snap) {
            final rows = snap.data ?? const [];
            if (snap.connectionState != ConnectionState.done) {
              return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
            }
            if (rows.isEmpty) {
              return Text('Chưa có ghi nhận nào.',
                  style: GoogleFonts.plusJakartaSans(color: KhoTheme.muted));
            }
            return Column(children: [
              for (final r in rows)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(nameById[r['product_id']]?.name ?? 'Sản phẩm'),
                  subtitle: Text(
                      '${reasonLabel('${r['reason']}')}${(r['note'] ?? '').toString().isEmpty ? '' : ' • ${r['note']}'}'),
                  trailing: Text(
                      fmtDelta((r['delta'] as num).toDouble(), nameById[r['product_id']]?.unit ?? ''),
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: KhoTheme.red)),
                ),
            ]);
          },
        ),
      ]),
    );
  }
}
