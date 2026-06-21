import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/providers/app_providers.dart';
import '../../../modules/kho/providers/kho_providers.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';
import '../repository/kho_chuyen_nghiep_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECIPE FORM SCREEN — Tạo/Sửa công thức + Định lượng
// ─────────────────────────────────────────────────────────────────────────────

class RecipeFormScreen extends ConsumerStatefulWidget {
  final RecipeModel? existing;
  const RecipeFormScreen({super.key, this.existing});

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _nameCtrl      = TextEditingController();
  final _descCtrl      = TextEditingController();
  final _servingSizeCtrl = TextEditingController(text: '1');
  String? _category;
  String  _servingUnit = 'phần';
  String? _linkedPosId;
  String? _linkedPosName;
  bool _loading = false;

  final List<_IngLine> _lines = [];

  static const _categories = [
    'Món chính', 'Khai vị', 'Tráng miệng',
    'Đồ uống', 'Súp & Cháo', 'Khác',
  ];
  static const _servingUnits = ['phần', 'tô', 'đĩa', 'ly', 'kg', 'lít'];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _nameCtrl.text       = e.name;
      _descCtrl.text       = e.description ?? '';
      _category            = e.category;
      _servingUnit         = e.servingUnit;
      _servingSizeCtrl.text = e.servingSize.toStringAsFixed(0);
      _linkedPosId         = e.posProductId;
      for (final i in e.ingredients) {
        _lines.add(_IngLine(
          ingredientId:   i.ingredientId,
          ingredientName: i.ingredientName ?? '',
          quantity:       i.quantity,
          unit:           i.unit,
          note:           i.note,
          costLatest:     i.ingredientCostLatest ?? 0,
          wastePct:       i.wastePct,  // load tỷ lệ hao phí từ DB
        ));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _servingSizeCtrl.dispose();
    for (final l in _lines) l.dispose();
    super.dispose();
  }

  double get _totalCost =>
      _lines.fold(0.0, (s, l) => s + l.lineCostDisplay);

  @override
  Widget build(BuildContext context) {
    final stockAsync    = ref.watch(allStockProvider);
    final posProducts   = ref.watch(allProductsProvider);
    final isEdit        = widget.existing != null;

    return Scaffold(
      backgroundColor: KhoTheme.bg,
      appBar: AppBar(
        backgroundColor: KhoTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(isEdit ? 'Sửa công thức' : 'Tạo công thức',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
        actions: [
          if (_nameCtrl.text.isNotEmpty && _lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _loading ? null : _submit,
                child: Text('LƯU', style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Thông tin cơ bản ─────────────────────────────────────────
              _buildSection('Thông tin món', Icons.info_rounded),
              const SizedBox(height: 8),
              _buildCard(Column(children: [
                TextField(
                  controller: _nameCtrl,
                  style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w700, color: KhoTheme.ink),
                  onChanged: (_) => setState(() {}),
                  decoration: KhoTheme.inputDecoration(hint: 'Tên món *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _descCtrl,
                  maxLines: 2,
                  style: GoogleFonts.outfit(fontSize: 14, color: KhoTheme.ink),
                  decoration: KhoTheme.inputDecoration(hint: 'Mô tả (tuỳ chọn)'),
                ),
                const SizedBox(height: 10),
                // Category + Serving
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      hint: Text('Danh mục', style: GoogleFonts.outfit(
                          fontSize: 13, color: KhoTheme.muted)),
                      decoration: KhoTheme.inputDecoration(hint: ''),
                      items: _categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: GoogleFonts.outfit(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _servingSizeCtrl,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.outfit(fontSize: 14, color: KhoTheme.ink),
                      decoration: KhoTheme.inputDecoration(hint: '1'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  DropdownButton<String>(
                    value: _servingUnit,
                    underline: const SizedBox(),
                    items: _servingUnits.map((u) => DropdownMenuItem(
                        value: u,
                        child: Text(u, style: GoogleFonts.outfit(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _servingUnit = v!),
                  ),
                ]),
              ])),

              const SizedBox(height: 16),

              // ── Gắn sản phẩm POS ─────────────────────────────────────────
              _buildSection('Gắn menu POS', Icons.link_rounded),
              const SizedBox(height: 8),
              _buildCard(posProducts.when(
                loading: () => const SizedBox(
                    height: 80, // Chiều cao cố định khi loading — tránh layout nhảy
                    child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
                data: (products) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chọn sản phẩm bán hàng tương ứng:',
                        style: GoogleFonts.outfit(
                            fontSize: 12, color: KhoTheme.muted)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _linkedPosId,
                      hint: Text('— Không gắn —', style: GoogleFonts.outfit(
                          fontSize: 13, color: KhoTheme.muted)),
                      decoration: KhoTheme.inputDecoration(hint: ''),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(
                            value: null,
                            child: Text('— Không gắn —',
                                style: GoogleFonts.outfit(
                                    fontSize: 13, color: KhoTheme.muted))),
                        ...products.map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name,
                                style: GoogleFonts.outfit(fontSize: 13)))),
                      ],
                      onChanged: (v) => setState(() {
                        _linkedPosId   = v;
                        _linkedPosName = v == null ? null
                            : products.firstWhere((p) => p.id == v).name;
                      }),
                    ),
                    if (_linkedPosId != null) ...[
                      const SizedBox(height: 6),
                      Row(children: [
                        Icon(Icons.check_circle_rounded,
                            size: 13, color: KhoTheme.green),
                        const SizedBox(width: 4),
                        Builder(builder: (_) {
                          // FIX: khi edit, _linkedPosName chưa được init → tìm tên từ products
                          final displayName = _linkedPosName
                              ?? products.where((p) => p.id == _linkedPosId).firstOrNull?.name
                              ?? _linkedPosId ?? '';
                          return Text('Khi bán "$displayName" → tự động trừ kho',
                              style: GoogleFonts.outfit(
                                  fontSize: 11.5, color: KhoTheme.green,
                                  fontWeight: FontWeight.w600));
                        }),
                      ]),
                    ],
                  ],
                ),
              )),

              const SizedBox(height: 16),

              // ── Định lượng nguyên liệu ───────────────────────────────────
              _buildSection(
                  'Định lượng nguyên liệu  (${_lines.length})',
                  Icons.egg_alt_rounded),
              const SizedBox(height: 8),

              stockAsync.when(
                loading: () => const SizedBox(
                    height: 120, // Chiều cao cố định khi loading — tránh layout nhảy
                    child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Lỗi kho: $e'),
                data: (stockItems) => Column(
                  children: [
                    ..._lines.asMap().entries.map((entry) =>
                        _IngLineCard(
                          key: ValueKey(entry.value),
                          line:      entry.value,
                          allStock:  stockItems, // truyền toàn bộ, filter trong card
                          onRemove:  () => setState(() => _lines.removeAt(entry.key)),
                          onChanged: () => setState(() {}),
                        )),
                    const SizedBox(height: 8),
                    _buildAddIngButton(() => setState(() =>
                        _lines.add(_IngLine()))),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),

        // ── Footer: giá vốn + lưu ────────────────────────────────────────
        _buildFooter(),
      ]),
    );
  }

  Widget _buildSection(String label, IconData icon) => Row(children: [
    Icon(icon, size: 15, color: KhoTheme.violet),
    const SizedBox(width: 6),
    Text(label, style: GoogleFonts.outfit(
        fontSize: 13.5, fontWeight: FontWeight.w800, color: KhoTheme.navy)),
  ]);

  Widget _buildCard(Widget child) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: KhoTheme.card,
      borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
      border: Border.all(color: KhoTheme.border),
      boxShadow: KhoTheme.subtleShadow,
    ),
    child: child,
  );

  Widget _buildAddIngButton(VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 50,
      decoration: BoxDecoration(
        color: KhoTheme.card,
        borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
        border: Border.all(color: KhoTheme.violet.withOpacity(0.5),
            style: BorderStyle.solid),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.add_circle_rounded, color: KhoTheme.violet, size: 18),
        const SizedBox(width: 8),
        Text('Thêm nguyên liệu', style: GoogleFonts.outfit(
            fontSize: 14, fontWeight: FontWeight.w700, color: KhoTheme.violet)),
      ]),
    ),
  );

  Widget _buildFooter() => Container(
    padding: EdgeInsets.fromLTRB(20, 16, 20,
        MediaQuery.of(context).padding.bottom + 16),
    decoration: BoxDecoration(
      color: KhoTheme.card,
      boxShadow: [BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20, offset: const Offset(0, -4))],
    ),
    child: Row(children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Giá vốn/phần', style: GoogleFonts.outfit(
                fontSize: 11, color: KhoTheme.muted, fontWeight: FontWeight.w600)),
            Text(fmtMoney(_totalCost), style: GoogleFonts.outfit(
                fontSize: 22, fontWeight: FontWeight.w900, color: KhoTheme.navy)),
          ]),
      const SizedBox(width: 16),
      Expanded(
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (_nameCtrl.text.trim().isNotEmpty && _lines.isNotEmpty && !_loading)
                ? _submit : null,
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
                : Text(widget.existing != null ? 'Cập nhật công thức' : 'Lưu công thức',
                    style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ),
    ]),
  );

  Future<void> _submit() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);
    try {
      final ingredients = _lines.map((l) => RecipeIngredientModel(
        id:               '',
        recipeId:         '',
        ingredientId:     l.ingredientId,
        quantity:         l.quantity,
        unit:             l.unit,
        note:             l.note,
        yieldFactor:      l.yieldFactor,
        ingredientName:   l.ingredientName,
        ingredientCostLatest: l.costLatest,
      )).toList();

      if (widget.existing != null) {
        await ref.read(khoProRepositoryProvider).updateRecipe(
          widget.existing!.id,
          name:          _nameCtrl.text.trim(),
          description:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          category:      _category,
          servingSize:   double.tryParse(_servingSizeCtrl.text) ?? 1,
          servingUnit:   _servingUnit,
          posProductId:  _linkedPosId,
          ingredients:   ingredients,
        );
      } else {
        await ref.read(khoProRepositoryProvider).createRecipe(
          name:          _nameCtrl.text.trim(),
          description:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          category:      _category,
          servingSize:   double.tryParse(_servingSizeCtrl.text) ?? 1,
          servingUnit:   _servingUnit,
          posProductId:  _linkedPosId,
          ingredients:   ingredients,
        );
      }

      HapticFeedback.heavyImpact();
      if (mounted) {
        ref.invalidate(recipesProvider);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Đã lưu công thức "${_nameCtrl.text}"'),
          backgroundColor: KhoTheme.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: KhoTheme.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INGREDIENT LINE DATA
// ─────────────────────────────────────────────────────────────────────────────
class _IngLine {
  String? ingredientId;
  String  ingredientName;
  double  quantity;
  String  unit;
  String? note;
  double  costLatest;
  double  wastePct;   // 0–99: % hao phí (VD: 20 = 20% hao phí, yield 80%)
  final TextEditingController qtyCtrl;
  final TextEditingController noteCtrl;
  final TextEditingController wasteCtrl;

  _IngLine({
    this.ingredientId,
    this.ingredientName = '',
    this.quantity       = 1,
    this.unit           = 'gram',
    this.note,
    this.costLatest     = 0,
    this.wastePct       = 0,
  })  : qtyCtrl  = TextEditingController(
            text: quantity == quantity.truncateToDouble()
                ? quantity.toInt().toString()
                : quantity.toStringAsFixed(2)),
        noteCtrl  = TextEditingController(text: note ?? ''),
        wasteCtrl = TextEditingController(
            text: wastePct == 0 ? '0' : wastePct.toInt().toString());

  /// Tỷ lệ sử dụng được (0.0–1.0)
  double get yieldFactor => wastePct >= 100 ? 0.01 : 1.0 - (wastePct / 100.0);

  /// Chi phí đã tính hao phí để hiển thị realtime
  double get lineCostDisplay {
    final actualQty = yieldFactor > 0 ? quantity / yieldFactor : quantity;
    double normalizedQty = actualQty;
    if (unit == 'kg')  normalizedQty = actualQty * 1000;
    if (unit == 'lít') normalizedQty = actualQty * 1000;
    return costLatest * normalizedQty;
  }

  void dispose() {
    qtyCtrl.dispose();
    noteCtrl.dispose();
    wasteCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INGREDIENT LINE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _IngLineCard extends StatefulWidget {
  final _IngLine line;
  final List<dynamic> allStock;   // StockItem list
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _IngLineCard({
    super.key,
    required this.line,
    required this.allStock,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_IngLineCard> createState() => _IngLineCardState();
}

class _IngLineCardState extends State<_IngLineCard> {
  static const _units = ['gram', 'kg', 'ml', 'lít', 'chiếc', 'cái', 'muỗng', 'chén'];

  @override
  Widget build(BuildContext context) {
    final line     = widget.line;
    final subtotal = line.lineCostDisplay;   // đã tính hao phí
    final hasWaste = line.wastePct > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: KhoTheme.violet.withOpacity(0.03),
        borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
        border: Border.all(color: hasWaste
            ? KhoTheme.amber.withOpacity(0.4)
            : KhoTheme.border),
        boxShadow: KhoTheme.subtleShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(KhoTheme.radiusCard - 1),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Accent trái — cam nếu có hao phí, tím nếu không
              Container(width: 4,
                  color: hasWaste ? KhoTheme.amber : KhoTheme.violet),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  child: Column(children: [
                    // Row 1: Chọn nguyên liệu + nút xoá
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: line.ingredientId,
                          hint: Text('Chọn nguyên liệu...',
                              style: GoogleFonts.outfit(fontSize: 13, color: KhoTheme.muted)),
                          decoration: KhoTheme.inputDecoration(hint: '').copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            prefixIcon: const Icon(Icons.egg_alt_rounded,
                                color: KhoTheme.violet, size: 17),
                          ),
                          isExpanded: true,
                          items: widget.allStock
                              .where((p) {
                                final type = (p.productType as String?);
                                final isIng = type == 'ingredient' || type == 'semi_finished';
                                final isSelected = (p.id as String?) == line.ingredientId;
                                return isIng || isSelected;
                              })
                              .map((p) => DropdownMenuItem(
                                value: p.id as String,
                                child: Text(p.name as String,
                                    style: GoogleFonts.outfit(fontSize: 13)),
                              )).toList(),
                          onChanged: (v) {
                            setState(() {
                              final dynamic prod = widget.allStock
                                  .cast<dynamic>()
                                  .firstWhere((p) => (p.id as String?) == v,
                                      orElse: () => null);
                              line.ingredientId   = v;
                              line.ingredientName = (prod?.name as String?) ?? '';
                              line.unit           = (prod?.unit as String?) ?? 'gram';
                              double rawCost = (prod?.costPrice as double?) ?? 0;
                              final prodUnit = (prod?.unit as String?) ?? '';
                              if (prodUnit == 'kg')  rawCost /= 1000;
                              if (prodUnit == 'lít') rawCost /= 1000;
                              line.costLatest = rawCost;
                            });
                            widget.onChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: widget.onRemove,
                        child: Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: KhoTheme.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.remove_rounded,
                              color: KhoTheme.red, size: 15),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 8),

                    // Row 2: Số lượng + Đơn vị + Chi phí
                    Row(children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: line.qtyCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: GoogleFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w700, color: KhoTheme.ink),
                          onChanged: (v) {
                            line.quantity = double.tryParse(v) ?? 1;
                            widget.onChanged();
                          },
                          decoration: KhoTheme.inputDecoration(hint: '').copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            labelText: 'Số lượng',
                            labelStyle: GoogleFonts.outfit(
                                fontSize: 11, color: KhoTheme.muted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: DropdownButtonFormField<String>(
                          value: _units.contains(line.unit) ? line.unit : _units[0],
                          decoration: KhoTheme.inputDecoration(hint: '').copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            labelText: 'Đơn vị',
                            labelStyle: GoogleFonts.outfit(
                                fontSize: 11, color: KhoTheme.muted),
                          ),
                          items: _units.map((u) => DropdownMenuItem(
                              value: u,
                              child: Text(u, style: GoogleFonts.outfit(fontSize: 13)))).toList(),
                          onChanged: (v) {
                            setState(() => line.unit = v!);
                            widget.onChanged();
                          },
                        ),
                      ),
                      if (subtotal > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: KhoTheme.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('= ${fmtMoney(subtotal)}',
                              style: GoogleFonts.outfit(
                                  fontSize: 12, fontWeight: FontWeight.w800,
                                  color: KhoTheme.green)),
                        ),
                      ],
                    ]),

                    // Row 3: % Hao phí
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.recycling_rounded,
                          size: 14, color: KhoTheme.amber),
                      const SizedBox(width: 6),
                      Text('Hao phí sơ chế:',
                          style: GoogleFonts.outfit(
                              fontSize: 12.5, color: KhoTheme.ink,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      // Nút hướng dẫn
                      GestureDetector(
                        onTap: () => showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            backgroundColor: KhoTheme.card,
                            insetPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 24),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(context).size.height * 0.88,
                              ),
                              child: SingleChildScrollView(
                                child: Padding(
                                  padding: const EdgeInsets.all(22),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [

                                  // Header
                                  Row(children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: KhoTheme.amber.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.recycling_rounded,
                                          color: KhoTheme.amber, size: 22),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text('Hao phí sơ chế là gì?',
                                          style: GoogleFonts.outfit(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: KhoTheme.navy)),
                                    ),
                                  ]),
                                  const SizedBox(height: 16),
                                  // Giải thích
                                  Text(
                                    'Khi chế biến, nguyên liệu bị hao hụt do rửa, lặt, '
                                    'cắt gọt, xương... Phần bị mất đi gọi là hao phí sơ chế.',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13.5, color: KhoTheme.ink,
                                        height: 1.5),
                                  ),
                                  const SizedBox(height: 16),
                                  // Ví dụ
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: KhoTheme.amber.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: KhoTheme.amber.withOpacity(0.25)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('📦 Ví dụ thực tế:',
                                            style: GoogleFonts.outfit(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: KhoTheme.amber)),
                                        const SizedBox(height: 8),
                                        Text(
                                          '• Nhập 10 kg rau vào kho\n'
                                          '• Sau khi rửa, lặt → còn 8 kg dùng được\n'
                                          '• Hao phí = 2 kg → 20%\n\n'
                                          '• Công thức cần 200g rau/tô\n'
                                          '• Nhập hao phí 20%\n'
                                          '• Hệ thống trừ kho: 200 ÷ 0.8 = 250g/tô ✓',
                                          style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              color: KhoTheme.ink,
                                              height: 1.6),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Bảng gợi ý % hao phí
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: const Color(0xFF2563EB).withOpacity(0.2)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('📊 Tỷ lệ gợi ý theo nguyên liệu:',
                                            style: GoogleFonts.outfit(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: const Color(0xFF2563EB))),
                                        const SizedBox(height: 10),
                                        _WasteRow('Rau xanh (rau muống, cải...)', '15 – 25%'),
                                        _WasteRow('Cà rốt, củ cải, khoai tây', '10 – 20%'),
                                        _WasteRow('Hành, tỏi, ớt', '10 – 15%'),
                                        _WasteRow('Thịt heo, thịt bò', '10 – 20%',
                                            note: 'Tính cho thịt nạc đã phi lê. Còn xương/mỡ nhiều: 25–30%'),
                                        _WasteRow('Gà nguyên con', '30 – 35%',
                                            note: 'Sau khi bỏ đầu, chân, lòng, vặt lông'),
                                        _WasteRow('Cá nguyên con', '15 – 25%',
                                            note: 'Chỉ đánh vảy + mổ ruột (kho, chiên, hấp). Nếu lọc phi lê: 50–65%'),
                                        _WasteRow('Tôm (bóc vỏ, bỏ đầu)', '35 – 45%',
                                            note: 'Đầu + vỏ + chỉ lưng ≈ 35–40% (nguồn: Bộ Công Thương VN)'),
                                        _WasteRow('Xương (hầm lấy nước)', '0% (đã tính)',
                                            note: 'Xương là nguyên liệu chính, không tính hao phí thêm'),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  // Ghi chú 1: Định lượng chuẩn ngành
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.lightbulb_outline_rounded,
                                          size: 15, color: KhoTheme.violet),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Đây là định lượng chuẩn của ngành F&B. '
                                          'Chi phí hao phí sơ chế được tính vào giá vốn '
                                          'và khách hàng sẽ gánh chịu phần này thông qua giá bán menu.',
                                          style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              color: KhoTheme.ink,
                                              fontWeight: FontWeight.w500,
                                              height: 1.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  // Ghi chú 2: Khuyến nghị tự đo
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.science_outlined,
                                          size: 15, color: KhoTheme.amber),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Bảng trên chỉ để tham khảo. Nên tự cân đo '
                                          'thực tế sau khi sơ chế nguyên liệu tại bếp '
                                          'để ra tỷ lệ % chính xác cho quán mình.',
                                          style: GoogleFonts.outfit(
                                              fontSize: 12.5,
                                              color: KhoTheme.amber,
                                              fontWeight: FontWeight.w600,
                                              height: 1.5),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 20),
                                  // Nút đóng
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: KhoTheme.violet,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                      ),
                                      child: Text('Đã hiểu',
                                          style: GoogleFonts.outfit(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                            color: Color(0xFF2563EB),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.question_mark_rounded,
                              size: 13, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 8),

                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: line.wasteCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w800,
                              color: hasWaste ? KhoTheme.amber : KhoTheme.ink),
                          // FIX: tap vào → select all → gõ số mới ngay, không cần xóa số 0
                          onTap: () => line.wasteCtrl.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: line.wasteCtrl.text.length,
                          ),
                          onChanged: (v) {
                            setState(() {
                              line.wastePct = (double.tryParse(v) ?? 0).clamp(0, 99);
                            });
                            widget.onChanged();
                          },
                          decoration: KhoTheme.inputDecoration(hint: '0').copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 6),
                            suffixText: '%',
                            suffixStyle: GoogleFonts.outfit(
                                fontSize: 12, color: KhoTheme.muted),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: hasWaste
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: KhoTheme.amber.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Lấy ${(line.yieldFactor > 0 ? line.quantity / line.yieldFactor : line.quantity).toStringAsFixed(0)} ${line.unit} từ kho',
                                style: GoogleFonts.outfit(
                                    fontSize: 10.5, fontWeight: FontWeight.w700,
                                    color: KhoTheme.amber),
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : Text('(0% = không hao phí)',
                              style: GoogleFonts.outfit(
                                  fontSize: 11, color: KhoTheme.muted),
                              overflow: TextOverflow.ellipsis),
                      ),

                    ]),
                  ]), // Column
                ), // Padding
              ), // Expanded
            ], // Row children
          ), // Row
        ), // IntrinsicHeight
      ), // ClipRRect
    ); // Container card
  }
}

// Widget dòng gợi ý hao phí trong dialog hướng dẫn
class _WasteRow extends StatelessWidget {
  final String label;
  final String pct;
  final String? note;
  const _WasteRow(this.label, this.pct, {this.note});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.circle, size: 5, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: GoogleFonts.outfit(
                        fontSize: 12.5,
                        color: KhoTheme.ink,
                        fontWeight: FontWeight.w600)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(pct,
                    style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2563EB))),
              ),
            ],
          ),
          if (note != null) ...
            [
              Padding(
                padding: const EdgeInsets.only(left: 13, top: 2),
                child: Text(
                  '↳ $note',
                  style: GoogleFonts.outfit(
                      fontSize: 10.5,
                      color: KhoTheme.muted,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
        ],
      ),
    );
  }
}

