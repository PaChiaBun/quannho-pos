import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';
import '../repository/kho_chuyen_nghiep_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCTION ORDER SCREEN — Lệnh sản xuất hằng ngày
// ─────────────────────────────────────────────────────────────────────────────

class ProductionOrderScreen extends ConsumerStatefulWidget {
  const ProductionOrderScreen({super.key});

  @override
  ConsumerState<ProductionOrderScreen> createState() => _ProductionOrderScreenState();
}

class _ProductionOrderScreenState extends ConsumerState<ProductionOrderScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _filterStatus; // null = tất cả

  @override
  Widget build(BuildContext context) {
    final ordersAsync  = ref.watch(productionOrdersByDateProvider);
    final recipesAsync = ref.watch(recipesProvider);

    return Scaffold(
      backgroundColor: KhoTheme.bg,
      body: CustomScrollView(
        slivers: [

          // ── Date selector ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16, color: KhoTheme.violet),
                const SizedBox(width: 6),
                Text(
                  _formatDate(_selectedDate),
                  style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w800,
                      color: KhoTheme.navy),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _pickDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: KhoTheme.violet.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Đổi ngày',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: KhoTheme.violet,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            ),
          ),

          // ── Filter chips ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _FilterChip(label: 'Tất cả',      value: null,           selected: _filterStatus, onTap: (v) => setState(() => _filterStatus = v)),
                  _FilterChip(label: 'Chờ',         value: 'pending',      selected: _filterStatus, onTap: (v) => setState(() => _filterStatus = v)),
                  _FilterChip(label: 'Đang làm',    value: 'in_progress',  selected: _filterStatus, onTap: (v) => setState(() => _filterStatus = v)),
                  _FilterChip(label: 'Hoàn thành',  value: 'done',         selected: _filterStatus, onTap: (v) => setState(() => _filterStatus = v)),
                  _FilterChip(label: 'Đã hủy',      value: 'cancelled',    selected: _filterStatus, onTap: (v) => setState(() => _filterStatus = v)),
                  const SizedBox(width: 16),
                ]),
              ),
            ),
          ),

          // ── Production orders list ─────────────────────────────────────
          ordersAsync.when(
            loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(padding: const EdgeInsets.all(16),
                    child: Text('Lỗi: $e'))),
            data: (orders) {
              final filtered = _filterStatus == null
                  ? orders
                  : orders.where((o) => o.status == _filterStatus).toList();
              if (filtered.isEmpty) {
                return SliverFillRemaining(
                  child: Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.precision_manufacturing_rounded,
                          size: 64, color: KhoTheme.muted.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text(
                          _filterStatus == null
                            ? 'Không có lệnh SX ngày ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'
                            : 'Không có lệnh "${_filterStatus == 'pending' ? 'Chờ' : _filterStatus == 'done' ? 'Hoàn thành' : _filterStatus == 'in_progress' ? 'Đang làm' : 'Đã hủy'}" hôm nay',
                          style: GoogleFonts.outfit(
                              fontSize: 15, color: KhoTheme.muted,
                              fontWeight: FontWeight.w600)),
                    ],
                  )),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => recipesAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (recipes) {
                        final recipe = recipes.where(
                          (r) => r.id == filtered[i].recipeId).firstOrNull;
                        return _ProductionCard(
                          order:  filtered[i],
                          recipe: recipe,
                          onStatusChanged: (newStatus) =>
                              _updateStatus(filtered[i], recipe, newStatus),
                          onCancel: () => _cancelOrder(filtered[i]),
                        )
                            .animate(delay: (i * 50).ms)
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.04, end: 0);
                      },
                    ),
                    childCount: filtered.length,
                  ),
                ),
              );
            },
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'production_order_fab',
        onPressed: () => recipesAsync.whenData(
            (recipes) => _showCreateSheet(context, recipes)),
        backgroundColor: KhoTheme.violet,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tạo lệnh SX',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 90)),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      // Cập nhật NotifierProvider → productionOrdersByDateProvider tự fetch lại
      ref.read(productionSelectedDateProvider.notifier).setDate(picked);
    }
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Hôm nay, ${d.day}/${d.month}/${d.year}';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  Future<void> _updateStatus(
      ProductionOrderModel order, RecipeModel? recipe, String newStatus) async {
    if (newStatus == 'done' && recipe != null) {
      // Check stock trước
      final warnings = await ref.read(khoProRepositoryProvider)
          .checkStock(recipe, order.quantity);
      if (warnings.isNotEmpty && mounted) {
        final ok = await _showWarningDialog(warnings);
        if (!ok) return;
      }
      await ref.read(khoProRepositoryProvider)
          .completeProductionOrder(order, recipe);
    } else {
      await ref.read(khoProRepositoryProvider)
          .updateProductionStatus(order.id, newStatus);
    }
    ref.invalidate(productionOrdersByDateProvider);
    ref.invalidate(productionOrdersProvider);
  }

  Future<void> _cancelOrder(ProductionOrderModel order) async {
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Hủy lệnh sản xuất?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Lệnh "${order.recipeName}" sẽ được đánh dấu Đã hủy.\nKho không bị thay đổi.',
            style: GoogleFonts.outfit(fontSize: 13, color: KhoTheme.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Không')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: KhoTheme.red),
            child: Text('Hủy lệnh', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ) ?? false;
    if (!ok) return;
    await ref.read(khoProRepositoryProvider).cancelProductionOrder(order.id);
    ref.invalidate(productionOrdersByDateProvider);
    ref.invalidate(productionOrdersProvider);
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Đã hủy lệnh "${order.recipeName}"'),
      backgroundColor: KhoTheme.muted,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<bool> _showWarningDialog(List<StockWarning> warnings) async {
    if (!mounted) return false;
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('⚠️ Thiếu nguyên liệu',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kho không đủ nguyên liệu:',
                style: GoogleFonts.outfit(color: KhoTheme.muted)),
            const SizedBox(height: 8),
            ...warnings.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${w.ingredientName}: cần ${w.required.toStringAsFixed(0)} ${w.unit}, có ${w.available.toStringAsFixed(0)}',
                style: GoogleFonts.outfit(fontSize: 13, color: KhoTheme.red,
                    fontWeight: FontWeight.w600),
              ),
            )),
            const SizedBox(height: 8),
            Text('Vẫn muốn hoàn thành?',
                style: GoogleFonts.outfit(color: KhoTheme.muted)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: KhoTheme.amber),
            child: const Text('Vẫn hoàn thành'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showCreateSheet(
      BuildContext context, List<RecipeModel> recipes) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProductionSheet(
        recipes:     recipes,
        initialDate: _selectedDate,    // truyền ngày đang xem xuống sheet
        onCreated: () {
          ref.invalidate(productionOrdersByDateProvider);
          ref.invalidate(productionOrdersProvider);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCTION ORDER CARD
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// FILTER CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final String? selected;
  final void Function(String?) onTap;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? KhoTheme.violet : KhoTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? KhoTheme.violet : KhoTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: GoogleFonts.outfit(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? Colors.white : KhoTheme.muted)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCTION ORDER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ProductionCard extends StatelessWidget {
  final ProductionOrderModel order;
  final RecipeModel? recipe;
  final void Function(String) onStatusChanged;
  final VoidCallback onCancel;

  const _ProductionCard({
    required this.order,
    required this.recipe,
    required this.onStatusChanged,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isCancelled = order.status == 'cancelled';
    final statusColor = isCancelled                   ? KhoTheme.muted
                       : order.status == 'done'        ? KhoTheme.green
                       : order.status == 'in_progress' ? KhoTheme.violet
                       : KhoTheme.amber;
    final statusLabel = isCancelled                   ? '✕ Đã hủy'
                       : order.status == 'done'        ? '✓ Hoàn thành'
                       : order.status == 'in_progress' ? '⚡ Đang làm'
                       : '⏳ Chờ';

    return Opacity(
      opacity: isCancelled ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: KhoTheme.card,
          borderRadius: BorderRadius.circular(KhoTheme.radiusCardLg),
          border: Border.all(
              color: isCancelled ? KhoTheme.border : KhoTheme.border),
          boxShadow: isCancelled ? [] : KhoTheme.cardShadow,
        ),
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isCancelled
                      ? Icons.cancel_outlined
                      : Icons.precision_manufacturing_rounded,
                  color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.recipeName,
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w800,
                            color: isCancelled ? KhoTheme.muted : KhoTheme.ink,
                            decoration: isCancelled ? TextDecoration.lineThrough : null)),
                    Text('${order.quantity.toStringAsFixed(0)} ${recipe?.servingUnit ?? 'phần'}  ·  Giá vốn: ${recipe != null ? fmtMoney(recipe!.costPerServing * order.quantity) : "—"}',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: KhoTheme.muted)),
                  ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel, style: GoogleFonts.outfit(
                    fontSize: 11.5, fontWeight: FontWeight.w700,
                    color: statusColor)),
              ),
            ]),
          ),
          // Action buttons
          if (!isCancelled && order.status != 'done')
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(children: [
                Row(children: [
                  if (order.status == 'pending')
                    Expanded(child: OutlinedButton.icon(
                      onPressed: () => onStatusChanged('in_progress'),
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text('Bắt đầu', style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: KhoTheme.violet,
                        side: const BorderSide(color: KhoTheme.violet),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    )),
                  if (order.status == 'pending') const SizedBox(width: 8),
                  Expanded(child: FilledButton.icon(
                    onPressed: () => onStatusChanged('done'),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text('Hoàn thành', style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700)),
                    style: FilledButton.styleFrom(
                      backgroundColor: KhoTheme.green,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  )),
                ]),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: onCancel,
                    icon: const Icon(Icons.cancel_outlined, size: 15),
                    label: Text('Hủy lệnh', style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(
                      foregroundColor: KhoTheme.red,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                    ),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE PRODUCTION SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _CreateProductionSheet extends ConsumerStatefulWidget {
  final List<RecipeModel> recipes;
  final VoidCallback onCreated;
  final DateTime initialDate;          // ngày đang xem trong ProductionOrderScreen
  const _CreateProductionSheet({
    required this.recipes,
    required this.onCreated,
    required this.initialDate,
  });

  @override
  ConsumerState<_CreateProductionSheet> createState() =>
      _CreateProductionSheetState();
}

class _CreateProductionSheetState
    extends ConsumerState<_CreateProductionSheet> {
  RecipeModel? _selected;
  final _qtyCtrl  = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  late DateTime _date;                 // khởi tạo từ widget.initialDate
  List<StockWarning> _warnings = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;        // dùng ngày đang chọn trong screen
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: KhoTheme.border,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(children: [
            Text('Tạo lệnh sản xuất', style: GoogleFonts.outfit(
                fontSize: 18, fontWeight: FontWeight.w800, color: KhoTheme.ink)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close_rounded, color: KhoTheme.muted),
                onPressed: () => Navigator.pop(context)),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // Chọn công thức
              DropdownButtonFormField<RecipeModel>(
                value: _selected,
                hint: Text('Chọn công thức...', style: GoogleFonts.outfit(
                    fontSize: 13, color: KhoTheme.muted)),
                decoration: KhoTheme.inputDecoration(hint: '').copyWith(
                    labelText: 'Công thức *',
                    labelStyle: GoogleFonts.outfit(fontSize: 12, color: KhoTheme.muted)),
                isExpanded: true,
                items: widget.recipes.map((r) => DropdownMenuItem(
                    value: r,
                    child: Text(r.name, style: GoogleFonts.outfit(fontSize: 13)))).toList(),
                onChanged: (v) async {
                  setState(() { _selected = v; _warnings = []; });
                  if (v != null) await _checkStock(v);
                },
              ),
              const SizedBox(height: 10),
              // Số lượng
              TextField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.outfit(fontSize: 14, color: KhoTheme.ink),
                onChanged: (_) async {
                  if (_selected != null) await _checkStock(_selected!);
                },
                decoration: KhoTheme.inputDecoration(
                    hint: 'Số phần',
                    suffix: Text(_selected?.servingUnit ?? 'phần',
                        style: GoogleFonts.outfit(color: KhoTheme.muted))),
              ),
              const SizedBox(height: 10),
              // Ghi chú
              TextField(
                controller: _noteCtrl,
                style: GoogleFonts.outfit(fontSize: 14, color: KhoTheme.ink),
                decoration: KhoTheme.inputDecoration(hint: 'Ghi chú (tuỳ chọn)'),
              ),
              // Cảnh báo
              if (_warnings.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KhoTheme.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: KhoTheme.amber.withOpacity(0.3)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('⚠️ Thiếu nguyên liệu', style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: KhoTheme.amber)),
                    const SizedBox(height: 6),
                    ..._warnings.map((w) => Text(
                      '• ${w.ingredientName}: thiếu ${w.shortage.toStringAsFixed(0)} ${w.unit}',
                      style: GoogleFonts.outfit(fontSize: 12, color: KhoTheme.amber),
                    )),
                  ]),
                ),
              ],
              // Giá vốn preview
              if (_selected != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: KhoTheme.violet.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: KhoTheme.violet.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Text('Tổng giá vốn ước tính:', style: GoogleFonts.outfit(
                        fontSize: 13, color: KhoTheme.navy)),
                    const Spacer(),
                    Text(
                      fmtMoney(_selected!.costPerServing *
                          (double.tryParse(_qtyCtrl.text) ?? 1)),
                      style: GoogleFonts.outfit(
                          fontSize: 16, fontWeight: FontWeight.w900,
                          color: KhoTheme.violet),
                    ),
                  ]),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _selected != null && !_loading ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: KhoTheme.violet,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(KhoTheme.radiusButton)),
                disabledBackgroundColor: KhoTheme.muted,
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Text('Tạo lệnh sản xuất', style: GoogleFonts.outfit(
                      fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ),
      ]),
    );
  }

  Future<void> _checkStock(RecipeModel recipe) async {
    final qty = double.tryParse(_qtyCtrl.text) ?? 1;
    final warnings = await ref.read(khoProRepositoryProvider)
        .checkStock(recipe, qty);
    if (mounted) setState(() => _warnings = warnings);
  }

  Future<void> _submit() async {
    if (_selected == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      await ref.read(khoProRepositoryProvider).createProductionOrder(
        recipeId:     _selected!.id,
        recipeName:   _selected!.name,
        quantity:     double.tryParse(_qtyCtrl.text) ?? 1,
        scheduledDate: _date,
        note:         _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCreated();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã tạo lệnh sản xuất "${_selected!.name}"'),
          backgroundColor: KhoTheme.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi: $e'), backgroundColor: KhoTheme.red));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
