import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/quantity_formatter.dart';
import '../../kho/providers/kho_providers.dart';
import '../../kho/repository/kho_repository.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';

/// Kiểm kê kho: đếm thực tế → so sánh sổ sách → xác nhận để điều chỉnh tồn.
/// Sổ sách được chụp lại ngay khi mở màn hình; server chỉ áp chênh lệch nên
/// các đơn bán trong lúc đang đếm không bị ghi đè.
class StockCountScreen extends ConsumerStatefulWidget {
  const StockCountScreen({super.key});

  @override
  ConsumerState<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends ConsumerState<StockCountScreen> {
  final _search = TextEditingController();
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, double> _snapshot = {}; // sổ sách lúc bắt đầu đếm
  String _filter = 'all'; // all | ingredient | retail
  bool _saving = false;

  @override
  void dispose() {
    _search.dispose();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _isIngredient(StockItem i) =>
      i.productType == 'ingredient' || i.productType == 'semi_finished';

  double? _entered(String id) {
    final t = _ctrls[id]?.text.trim().replaceAll(',', '.') ?? '';
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  Future<void> _submit(List<StockItem> items) async {
    final changes = <({StockItem item, double actual, double system})>[];
    for (final i in items) {
      final v = _entered(i.id);
      if (v == null) continue;
      final system = _snapshot[i.id] ?? i.stockQty;
      if ((v - system).abs() > 0.0005) changes.add((item: i, actual: v, system: system));
    }
    final counted = items.where((i) => _entered(i.id) != null).length;
    if (counted == 0) {
      _toast('Chưa nhập số lượng thực tế cho mặt hàng nào');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Xác nhận kiểm kê', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: 360,
          child: changes.isEmpty
              ? Text('Đã đếm $counted mặt hàng, không có chênh lệch.',
                  style: GoogleFonts.plusJakartaSans())
              : ListView(
                  shrinkWrap: true,
                  children: [
                    Text('Đã đếm $counted mặt hàng, ${changes.length} mặt hàng lệch:',
                        style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    for (final c in changes)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          '${c.item.name}: sổ ${fmtQty(c.system)} → đếm ${fmtQty(c.actual)} '
                          '(${fmtDelta(c.actual - c.system, c.item.unit)})',
                          style: GoogleFonts.plusJakartaSans(fontSize: 13),
                        ),
                      ),
                  ],
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Quay lại')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(khoProRepositoryProvider);
      final countId = await repo.createStockCount(note: 'Kiểm kê trên app');
      await repo.saveStockCountItems(countId, [
        for (final i in items)
          if (_entered(i.id) != null)
            {
              'product_id': i.id,
              'system_qty': _snapshot[i.id] ?? i.stockQty,
              'actual_qty': _entered(i.id)!,
            },
      ]);
      final changed = await repo.confirmStockCount(countId);
      ref.invalidate(stockCountsProvider);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      _toast('Đã kiểm kê xong — điều chỉnh $changed mặt hàng');
      Navigator.of(context).pop();
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
    return Scaffold(
      backgroundColor: KhoTheme.bg,
      appBar: AppBar(
        backgroundColor: KhoTheme.navy,
        foregroundColor: Colors.white,
        title: Text('Kiểm kê kho',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (all) {
          final items = all.where((i) => i.isActive && !i.isTopping).toList()
            ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
          for (final i in items) {
            _snapshot.putIfAbsent(i.id, () => i.stockQty);
            _ctrls.putIfAbsent(i.id, () => TextEditingController());
          }
          final q = _search.text.trim().toLowerCase();
          final shown = items.where((i) {
            if (_filter == 'ingredient' && !_isIngredient(i)) return false;
            if (_filter == 'retail' && _isIngredient(i)) return false;
            return q.isEmpty || i.name.toLowerCase().contains(q);
          }).toList();
          final counted = items.where((i) => _entered(i.id) != null).length;

          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded),
                  hintText: 'Tìm mặt hàng...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(spacing: 8, children: [
                for (final f in const [
                  ('all', 'Tất cả'),
                  ('ingredient', 'Nguyên liệu'),
                  ('retail', 'Hàng bán'),
                ])
                  ChoiceChip(
                    label: Text(f.$2),
                    selected: _filter == f.$1,
                    onSelected: (_) => setState(() => _filter = f.$1),
                  ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nhập số lượng ĐẾM THỰC TẾ (theo đơn vị kho). Để trống = không kiểm mặt hàng đó.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 11.5, color: KhoTheme.muted),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: shown.length,
                itemBuilder: (_, idx) {
                  final i = shown[idx];
                  final system = _snapshot[i.id] ?? i.stockQty;
                  final v = _entered(i.id);
                  final diff = v == null ? null : v - system;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: KhoTheme.border),
                    ),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(i.name,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14)),
                          const SizedBox(height: 2),
                          Text('Sổ sách: ${fmtQty(system)} ${i.unit}',
                              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: KhoTheme.muted)),
                          if (diff != null && diff.abs() > 0.0005)
                            Text(fmtDelta(diff, i.unit),
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: diff > 0 ? KhoTheme.green : KhoTheme.red)),
                        ]),
                      ),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: _ctrls[i.id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          onChanged: (_) => setState(() {}),
                          textAlign: TextAlign.end,
                          decoration: InputDecoration(
                            labelText: 'Thực tế',
                            suffixText: i.unit,
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ]),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _submit(items),
                    icon: _saving
                        ? const SizedBox(
                            width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.fact_check_rounded),
                    label: Text('Hoàn tất kiểm kê ($counted đã đếm)'),
                  ),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
