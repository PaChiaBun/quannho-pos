import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../providers/kho_providers.dart';
import '../repository/kho_repository.dart';
import 'supplier_list_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PHIẾU NHẬP HÀNG SCREEN
// Tạo purchase_order đầy đủ: nhiều sản phẩm, nhà cung cấp, tự động cộng kho
// ─────────────────────────────────────────────────────────────────────────────

const _kNavy   = Color(0xFF1C2151);
const _kViolet = Color(0xFF7C3AED);
const _kBg     = Color(0xFFF8F6FF);
const _kCard   = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE5E0F5);
const _kMuted  = Color(0xFF9E98B0);
const _kInk    = Color(0xFF1A1530);
const _kGreen  = Color(0xFF059669);
const _kRed    = Color(0xFFDC2626);

class PhieuNhapHangScreen extends ConsumerStatefulWidget {
  const PhieuNhapHangScreen({super.key});

  @override
  ConsumerState<PhieuNhapHangScreen> createState() => _PhieuNhapHangScreenState();
}

class _PhieuNhapHangScreenState extends ConsumerState<PhieuNhapHangScreen> {
  final List<_PoLine> _lines = [];
  String? _selectedSupplierId;
  String? _selectedSupplierName;
  final _noteCtrl = TextEditingController();
  bool _loading = false;

  // ── Tính năng mới ─────────────────────────────────────────────────────────
  DateTime _importDate = DateTime.now();
  String? _invoiceImagePath;  // local path trước khi upload
  // Mã phiếu sinh sẵn để hiện trên UI (không đợi submit)
  final String _draftPoNumber = 'PO-${DateFormat('yyMMdd').format(DateTime.now())}-${const Uuid().v4().substring(0, 4).toUpperCase()}';

  @override
  void dispose() {
    _noteCtrl.dispose();
    for (final l in _lines) { l.dispose(); }
    super.dispose();
  }

  double get _total => _lines.fold(0, (s, l) => s + l.subtotal);

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final productsAsync  = ref.watch(allStockProvider);

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kNavy,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phiếu nhập hàng',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            Text(_draftPoNumber,
                style: GoogleFonts.outfit(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w500, fontSize: 11)),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_lines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _loading ? null : _submit,
                child: Text('XÁC NHẬN',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Nhà cung cấp ─────────────────────────────────────────
                suppliersAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (suppliers) => _buildSupplierPicker(suppliers),
                ),
                const SizedBox(height: 12),

                // ── Ngày nhập hàng ───────────────────────────────────────
                _buildDatePicker(),
                const SizedBox(height: 12),

                // ── Danh sách sản phẩm nhập ──────────────────────────────
                _buildSectionHeader('Sản phẩm nhập', Icons.inventory_2_rounded),
                const SizedBox(height: 8),

                productsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Lỗi: $e'),
                  data: (products) => Column(
                    children: [
                      ..._lines.asMap().entries.map((e) =>
                          _PoLineCard(
                            key: ValueKey(e.value),
                            line: e.value,
                            products: products,
                            onRemove: () => setState(() => _lines.removeAt(e.key)),
                            onChanged: () => setState(() {}),
                          )),
                      const SizedBox(height: 8),
                      _buildAddButton(products),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ── Ghi chú ──────────────────────────────────────────────
                _buildSectionHeader('Ghi chú', Icons.notes_rounded),
                const SizedBox(height: 8),
                _buildNoteField(),
                const SizedBox(height: 12),

                // ── Ảnh hoá đơn ──────────────────────────────────────────
                _buildSectionHeader('Ảnh hoá đơn', Icons.receipt_long_rounded),
                const SizedBox(height: 8),
                _buildInvoicePhoto(),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // ── Footer: Tổng tiền + Xác nhận ─────────────────────────────
          _buildFooter(),
        ],
      ),
    );
  }

  // ── Supplier picker ────────────────────────────────────────────────────────
  Widget _buildSupplierPicker(List<SupplierModel> suppliers) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _selectedSupplierId != null
              ? _kViolet.withValues(alpha: 0.5) : _kBorder,
          width: _selectedSupplierId != null ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: _selectedSupplierId != null
                      ? _kViolet.withValues(alpha: 0.12) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.store_rounded,
                    color: _selectedSupplierId != null ? _kViolet : _kMuted, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _selectedSupplierName ?? 'Nhà cung cấp (tuỳ chọn)',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: _selectedSupplierId != null
                        ? FontWeight.w700 : FontWeight.w600,
                    color: _selectedSupplierId != null ? _kNavy : const Color(0xFF6B7280),
                  ),
                ),
              ),
              // Link Quản lý NCC →
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const SupplierListScreen()),
                ),
                child: Text(
                  'Quản lý →',
                  style: GoogleFonts.outfit(
                    fontSize: 11.5, fontWeight: FontWeight.w700,
                    color: _kViolet,
                  ),
                ),
              ),
            ],
          ),
          if (suppliers.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Chưa có NCC — vào "Quản lý" để thêm',
              style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF9CA3AF)),
            ),
          ],
          if (suppliers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: [
                _SupplierChip(
                  label: 'Không chọn',
                  selected: _selectedSupplierId == null,
                  onTap: () => setState(() {
                    _selectedSupplierId = null;
                    _selectedSupplierName = null;
                  }),
                ),
                ...suppliers.map((s) => _SupplierChip(
                  label: s.name,
                  selected: _selectedSupplierId == s.id,
                  onTap: () => setState(() {
                    _selectedSupplierId = s.id;
                    _selectedSupplierName = s.name;
                  }),
                )),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Section header ─────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: _kViolet),
      const SizedBox(width: 6),
      Text(title,
          style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w800, color: _kNavy)),
    ],
  );

  // ── Add product button ─────────────────────────────────────────────────────
  Widget _buildAddButton(List<StockItem> products) => GestureDetector(
    onTap: () => _pickProduct(products),
    child: Container(
      height: 52,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kViolet, width: 1.5,
            style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle_rounded, color: _kViolet, size: 20),
          const SizedBox(width: 8),
          Text('Thêm sản phẩm',
              style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w700, color: _kViolet)),
        ],
      ),
    ),
  );

  // ── Note field ─────────────────────────────────────────────────────────────
  Widget _buildNoteField() => TextField(
    controller: _noteCtrl,
    maxLines: 2,
    style: GoogleFonts.outfit(fontSize: 14, color: _kInk),
    decoration: InputDecoration(
      hintText: 'Ghi chú cho phiếu nhập...',
      hintStyle: GoogleFonts.outfit(color: _kMuted, fontSize: 14),
      filled: true, fillColor: _kCard,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kViolet, width: 2)),
      contentPadding: const EdgeInsets.all(14),
    ),
  );

  // ── Footer ─────────────────────────────────────────────────────────────────
  Widget _buildFooter() => Container(
    padding: EdgeInsets.fromLTRB(20, 16, 20,
        MediaQuery.of(context).padding.bottom + 16),
    decoration: BoxDecoration(
      color: _kCard,
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 20, offset: const Offset(0, -4))],
    ),
    child: Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Tổng tiền', style: GoogleFonts.outfit(
                fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600)),
            Text(fmtMoney(_total),
                style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.w900, color: _kNavy)),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _lines.isNotEmpty && !_loading ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _lines.isNotEmpty ? _kViolet : _kMuted,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text('Nhập ${_lines.length} sản phẩm',
                            style: GoogleFonts.outfit(
                                fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
            ),
          ),
        ),
      ],
    ),
  );

  // ── Pick product sheet ─────────────────────────────────────────────────────
  Future<void> _pickProduct(List<StockItem> products) async {
    final picked = await showModalBottomSheet<StockItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductPickerSheet(
        products: products,
        alreadyAdded: _lines.map((l) => l.productId).toSet(),
      ),
    );
    if (picked != null) {
      setState(() => _lines.add(_PoLine(
        productId: picked.id,
        productName: picked.name,
        unit: picked.unit,
        costPrice: picked.costPrice,
      )));
    }
  }

  // ── Date picker ────────────────────────────────────────────────────────────
  Widget _buildDatePicker() {
    final fmt = DateFormat('dd/MM/yyyy');
    final isToday = DateFormat('yyyyMMdd').format(_importDate) ==
        DateFormat('yyyyMMdd').format(DateTime.now());
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _importDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (ctx, child) => Theme(
            data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(
                  primary: _kViolet, onSurface: _kInk),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _importDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: isToday ? _kBorder : _kViolet.withValues(alpha: 0.5),
              width: isToday ? 1 : 1.5),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_rounded,
              size: 18, color: isToday ? _kMuted : _kViolet),
          const SizedBox(width: 10),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ngày nhập hàng',
                  style: GoogleFonts.outfit(
                      fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
              Text(
                isToday ? 'Hôm nay — ${fmt.format(_importDate)}'
                         : fmt.format(_importDate),
                style: GoogleFonts.outfit(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isToday ? _kInk : _kViolet),
              ),
            ],
          )),
          Icon(Icons.chevron_right_rounded,
              color: isToday ? _kMuted : _kViolet, size: 20),
        ]),
      ),
    );
  }

  // ── Invoice photo ──────────────────────────────────────────────────────────
  Widget _buildInvoicePhoto() {
    if (_invoiceImagePath != null) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Ảnh đầy đủ không crop
            Image.file(
              File(_invoiceImagePath!),
              width: double.infinity,
              fit: BoxFit.contain,
            ),
            // Nút xoá
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _invoiceImagePath = null),
                child: Container(
                  decoration: const BoxDecoration(
                      color: Color(0xFFDC2626), shape: BoxShape.circle),
                  padding: const EdgeInsets.all(7),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
            // Nút đổi ảnh (góc dưới phải)
            Positioned(
              bottom: 8, right: 8,
              child: GestureDetector(
                onTap: () => _pickInvoice(ImageSource.gallery),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 13),
                    const SizedBox(width: 4),
                    Text('Đổi ảnh',
                        style: GoogleFonts.outfit(
                            fontSize: 11, color: Colors.white,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Chưa có ảnh
    return Row(children: [
      Expanded(child: _buildPhotoBtn(
        icon: Icons.camera_alt_rounded, label: 'Chụp ảnh',
        onTap: () => _pickInvoice(ImageSource.camera),
      )),
      const SizedBox(width: 10),
      Expanded(child: _buildPhotoBtn(
        icon: Icons.photo_library_rounded, label: 'Thư viện',
        onTap: () => _pickInvoice(ImageSource.gallery),
      )),
    ]);
  }

  Widget _buildPhotoBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kViolet.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: _kViolet),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: GoogleFonts.outfit(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: _kMuted)),
            ],
          ),
        ),
      );


  Future<void> _pickInvoice(ImageSource source) async {
    final file = await ImagePicker().pickImage(
        source: source, imageQuality: 80, maxWidth: 1200);
    if (file != null) setState(() => _invoiceImagePath = file.path);
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    final invalid = _lines.where((l) => l.quantity <= 0).toList();
    if (invalid.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Vui lòng nhập số lượng cho tất cả sản phẩm'),
        backgroundColor: _kRed, behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    try {
      final lines = _lines.map((l) => PurchaseOrderLine(
        productId: l.productId, productName: l.productName,
        unit: l.unit, quantity: l.quantity, unitCost: l.unitCost,
      )).toList();

      await ref.read(khoRepositoryProvider).createPurchaseOrder(
        lines:             lines,
        supplierId:        _selectedSupplierId,
        supplierName:      _selectedSupplierName,
        note:              _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
        importDate:        _importDate,
        invoiceImagePath:  _invoiceImagePath,
      );

      HapticFeedback.heavyImpact();
      ref.invalidate(purchaseOrdersProvider);
      ref.invalidate(khoStatsProvider);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text('Nhập hàng thành công — ${_lines.length} sản phẩm',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
          ]),
          backgroundColor: _kGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'), backgroundColor: _kRed));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PO LINE DATA — State cho mỗi dòng sản phẩm
// ─────────────────────────────────────────────────────────────────────────────
class _PoLine {
  final String productId;
  final String productName;
  final String unit;
  final TextEditingController qtyCtrl;
  final TextEditingController costCtrl;

  _PoLine({
    required this.productId,
    required this.productName,
    required this.unit,
    double costPrice = 0,
  })  : originalCostPrice = costPrice,
        qtyCtrl  = TextEditingController(text: '1'),
        costCtrl = TextEditingController(
            text: costPrice > 0
                ? NumberFormat('#,###').format(costPrice.toInt())
                : '');

  final double originalCostPrice; // giá vốn gốc — hiển thị hint

  double get quantity => double.tryParse(qtyCtrl.text) ?? 0;
  // strip dấu phẩy trước khi parse
  double get unitCost => double.tryParse(costCtrl.text.replaceAll(',', '')) ?? 0;
  double get subtotal => quantity * unitCost;

  void dispose() {
    qtyCtrl.dispose();
    costCtrl.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PO LINE CARD WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _PoLineCard extends StatefulWidget {
  final _PoLine line;
  final List<StockItem> products;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _PoLineCard({
    super.key,
    required this.line,
    required this.products,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  State<_PoLineCard> createState() => _PoLineCardState();
}

class _PoLineCardState extends State<_PoLineCard> {
  @override
  void initState() {
    super.initState();
    // Format giá trị ban đầu nếu chưa có dấu phẩy
    final raw = widget.line.costCtrl.text.replaceAll(',', '');
    final n = int.tryParse(raw);
    if (n != null && n > 0) {
      widget.line.costCtrl.text = NumberFormat('#,###').format(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    final line    = widget.line;
    final subtotal = line.subtotal;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
        border: Border.all(color: _kBorder),
        boxShadow: KhoTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 0),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: KhoTheme.violet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.inventory_2_rounded,
                    color: KhoTheme.violet, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.productName,
                      style: GoogleFonts.outfit(
                          fontSize: 14, fontWeight: FontWeight.w800,
                          color: KhoTheme.ink)),
                  Text(line.unit,
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: KhoTheme.muted)),
                ],
              )),
              IconButton(
                onPressed: widget.onRemove,
                icon: Icon(Icons.delete_outline_rounded,
                    color: KhoTheme.red.withValues(alpha: 0.7), size: 20),
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
              ),
            ]),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Divider(height: 16),
          ),

          // ── Số lượng + Đơn giá ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stepper
                Expanded(flex: 5, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Số lượng',
                        style: GoogleFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: KhoTheme.muted)),
                    const SizedBox(height: 6),
                    Container(
                      height: 46,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        // Nút −
                        GestureDetector(
                          onTap: () {
                            final v = double.tryParse(line.qtyCtrl.text) ?? 1;
                            if (v > 1) {
                              line.qtyCtrl.text = (v - 1).toStringAsFixed(0);
                              setState(() {}); widget.onChanged();
                            }
                          },
                          child: Container(
                            width: 38, height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: KhoTheme.navy.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.remove_rounded,
                                size: 18, color: KhoTheme.navy),
                          ),
                        ),
                        // Giá trị
                        SizedBox(width: 52, child: TextField(
                          controller: line.qtyCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: KhoTheme.ink),
                          onChanged: (_) {
                            setState(() {}); widget.onChanged();
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        )),
                        // Nút +
                        GestureDetector(
                          onTap: () {
                            final v = double.tryParse(line.qtyCtrl.text) ?? 0;
                            line.qtyCtrl.text = (v + 1).toStringAsFixed(0);
                            setState(() {}); widget.onChanged();
                          },
                          child: Container(
                            width: 38, height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: KhoTheme.violet.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.add_rounded,
                                size: 18, color: KhoTheme.violet),
                          ),
                        ),
                      ]),
                    ),
                  ],
                )),
                const SizedBox(width: 10),
                // Đơn giá
                Expanded(flex: 6, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Đơn giá nhập',
                        style: GoogleFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: KhoTheme.muted)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: line.costCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_ThousandsFormatter()],
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: KhoTheme.ink),
                      onChanged: (_) {
                        setState(() {}); widget.onChanged();
                      },
                      decoration: KhoTheme.inputDecoration(
                        hint: '0',
                        suffixText: 'đ',
                      ).copyWith(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 13),
                      ),
                    ),
                    if (line.originalCostPrice > 0) ...[
                      const SizedBox(height: 3),
                      Text('↑ Lần trước: ${fmtMoney(line.originalCostPrice)}',
                          style: GoogleFonts.outfit(
                              fontSize: 10, color: KhoTheme.muted,
                              fontStyle: FontStyle.italic)),
                    ],
                  ],
                )),
              ],
            ),
          ),

          // ── Thành tiền ─────────────────────────────────────────────
          if (subtotal > 0)
            Container(
              decoration: BoxDecoration(
                color: KhoTheme.green.withValues(alpha: 0.08),
                borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(KhoTheme.radiusCard)),
                border: Border(
                  top: BorderSide(color: KhoTheme.green.withValues(alpha: 0.15)),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('= Thành tiền',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: KhoTheme.green,
                          fontWeight: FontWeight.w600)),
                  Text(fmtMoney(subtotal),
                      style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w900,
                          color: KhoTheme.green)),
                ],
              ),
            ),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT PICKER SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _ProductPickerSheet extends StatefulWidget {
  final List<StockItem> products;
  final Set<String> alreadyAdded;

  const _ProductPickerSheet({
    required this.products,
    required this.alreadyAdded,
  });

  @override
  State<_ProductPickerSheet> createState() => _ProductPickerSheetState();
}

class _ProductPickerSheetState extends State<_ProductPickerSheet> {
  String _query = '';


  static ({String label, Color color, IconData icon}) _typeInfo(String t) =>
      switch (t) {
        'ingredient'    => (label: 'Nguyên liệu',   color: const Color(0xFF2E7D32), icon: Icons.egg_alt_rounded),
        'semi_finished' => (label: 'Bán TP',         color: const Color(0xFF1565C0), icon: Icons.blender_rounded),
        'purchased'     => (label: 'Hàng mua sẵn',   color: const Color(0xFFE65100), icon: Icons.shopping_bag_rounded),
        _               => (label: t,                color: const Color(0xFF9E9E9E), icon: Icons.inventory_2_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final filtered = widget.products
        .where((p) =>
            !widget.alreadyAdded.contains(p.id) &&
            p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(children: [
        const SizedBox(height: 10),
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _kBorder,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(children: [
            Text('Chọn sản phẩm',
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _kInk)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: _kMuted),
              onPressed: () => Navigator.pop(context),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            autofocus: true,
            onChanged: (v) => setState(() => _query = v),
            style: GoogleFonts.outfit(fontSize: 14, color: _kInk),
            decoration: InputDecoration(
              hintText: 'Tìm sản phẩm...',
              hintStyle: GoogleFonts.outfit(color: _kMuted, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _kMuted, size: 20),
              filled: true, fillColor: _kBg,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kBorder)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kViolet, width: 2)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text('Không tìm thấy sản phẩm',
                  style: GoogleFonts.outfit(color: _kMuted)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (_, i) {
                    final p = filtered[i];
                    final info = _typeInfo(p.productType);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: info.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(info.icon,
                            color: info.color, size: 20),
                      ),
                      title: Text(p.name,
                          style: GoogleFonts.outfit(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: _kInk)),
                      subtitle: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: info.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(info.label,
                              style: GoogleFonts.outfit(
                                  fontSize: 10, fontWeight: FontWeight.w700,
                                  color: info.color)),
                        ),
                        const SizedBox(width: 6),
                        Text('Tồn: ${p.stockQty.toStringAsFixed(0)} ${p.unit}',
                            style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
                      ]),
                      trailing: const Icon(Icons.add_circle_rounded,
                          color: _kViolet, size: 22),
                      onTap: () => Navigator.pop(context, p),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLIER CHIP
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SupplierChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _kViolet : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? _kViolet : _kBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Text(label,
        style: GoogleFonts.outfit(
          fontSize: 12.5, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : _kMuted,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// THOUSANDS FORMATTER — auto thêm dấu phẩy ngàn khi nhập giá
// ─────────────────────────────────────────────────────────────────────────────
class _ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    // Chỉ giữ chữ số
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue.copyWith(text: '');

    final number = int.tryParse(digits);
    if (number == null) return oldValue;

    final formatted = NumberFormat('#,###').format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
