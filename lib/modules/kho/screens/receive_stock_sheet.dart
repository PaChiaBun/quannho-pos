import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/kho_providers.dart';
import '../repository/kho_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// NHẬP HÀNG SHEET — Bottom sheet nhập kho
// ─────────────────────────────────────────────────────────────────────────────
class ReceiveStockSheet extends ConsumerStatefulWidget {
  final StockItem product;

  const ReceiveStockSheet({super.key, required this.product});

  @override
  ConsumerState<ReceiveStockSheet> createState() => _ReceiveStockSheetState();
}

class _ReceiveStockSheetState extends ConsumerState<ReceiveStockSheet> {
  final _qtyCtrl = TextEditingController(text: '1');
  final _costCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _refCtrl  = TextEditingController();
  String? _selectedSupplierId;
  bool _loading = false;

  static const _kNavy  = Color(0xFF1E1C5E);
  static const _kInk   = Color(0xFF1A1207);
  static const _kMuted = Color(0xFF9E9085);
  static const _kBg    = Color(0xFFFAF7F2);
  static const _kBorder= Color(0xFFE0D8CC);

  @override
  void initState() {
    super.initState();
    // Điền giá nhập gần nhất
    _costCtrl.text = widget.product.costPrice > 0
        ? widget.product.costPrice.toStringAsFixed(0)
        : '';
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _costCtrl.dispose();
    _noteCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final totalCost = qty * cost;

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Nhập hàng',
                        style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900,
                          color: _kInk, letterSpacing: -0.5,
                        )),
                      Text(widget.product.name,
                        style: const TextStyle(fontSize: 13, color: _kMuted)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: _kMuted),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: _kBorder),

            // Form
<<<<<<< HEAD
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65 -
                    MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Current stock info
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _kBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_rounded,
                              color: _kNavy, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Tồn hiện tại: ${widget.product.stockQty.toStringAsFixed(0)} ${widget.product.unit}',
                            style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700,
                              color: _kNavy,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Số lượng + đơn giá
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            label: 'Số lượng (${widget.product.unit})',
                            ctrl: _qtyCtrl,
                            keyboard: TextInputType.number,
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildField(
                            label: 'Đơn giá nhập (đ)',
                            ctrl: _costCtrl,
                            keyboard: TextInputType.number,
                            onChanged: (_) => setState(() {}),
=======
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current stock info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_rounded,
                            color: _kNavy, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Tồn hiện tại: ${widget.product.stockQty.toStringAsFixed(0)} ${widget.product.unit}',
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: _kNavy,
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
                          ),
                        ),
                      ],
                    ),
<<<<<<< HEAD
                    const SizedBox(height: 12),

                    // Tổng tiền
                    if (totalCost > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('Tổng tiền: ',
                              style: TextStyle(
                                fontSize: 14, color: Color(0xFF2E7D32))),
                            Text(_formatMoney(totalCost.toInt()) + 'đ',
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800,
                                color: Color(0xFF2E7D32))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Nhà cung cấp
                    suppliersAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (suppliers) => suppliers.isEmpty
                          ? const SizedBox.shrink()
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Nhà cung cấp'),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _selectedSupplierId,
                                  decoration: _inputDecor(null),
                                  hint: const Text('Chọn NCC (tuỳ chọn)',
                                    style: TextStyle(
                                      color: _kMuted, fontSize: 14)),
                                  items: [
                                    const DropdownMenuItem(
                                      value: null,
                                      child: Text('Không chọn')),
                                    ...suppliers.map((s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text(s.name),
                                    )),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _selectedSupplierId = v),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                    ),


                    // Ghi chú
                    _buildField(
                      label: 'Ghi chú',
                      ctrl: _noteCtrl,
                      keyboard: TextInputType.text,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: qty > 0 && !_loading ? _submit : null,
                        icon: _loading
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.check_rounded),
                        label: Text(
                          qty > 0
                              ? 'Nhập ${qty.toStringAsFixed(0)} ${widget.product.unit}'
                              : 'Nhập hàng',
                          style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kNavy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

=======
                  ),
                  const SizedBox(height: 16),

                  // Số lượng + đơn giá
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          label: 'Số lượng (${widget.product.unit})',
                          ctrl: _qtyCtrl,
                          keyboard: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          label: 'Đơn giá nhập (đ)',
                          ctrl: _costCtrl,
                          keyboard: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Tổng tiền
                  if (totalCost > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Text('Tổng tiền: ',
                            style: TextStyle(
                              fontSize: 14, color: Color(0xFF2E7D32))),
                          Text(_formatMoney(totalCost.toInt()) + 'đ',
                            style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800,
                              color: Color(0xFF2E7D32))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Nhà cung cấp
                  suppliersAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (suppliers) => suppliers.isEmpty
                        ? const SizedBox.shrink()
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _label('Nhà cung cấp'),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedSupplierId,
                                decoration: _inputDecor(null),
                                hint: const Text('Chọn NCC (tuỳ chọn)',
                                  style: TextStyle(
                                    color: _kMuted, fontSize: 14)),
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Không chọn')),
                                  ...suppliers.map((s) => DropdownMenuItem(
                                    value: s.id,
                                    child: Text(s.name),
                                  )),
                                ],
                                onChanged: (v) =>
                                    setState(() => _selectedSupplierId = v),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                  ),

                  // Số phiếu
                  _buildField(
                    label: 'Số phiếu / hoá đơn (tuỳ chọn)',
                    ctrl: _refCtrl,
                    keyboard: TextInputType.text,
                  ),
                  const SizedBox(height: 12),

                  // Ghi chú
                  _buildField(
                    label: 'Ghi chú',
                    ctrl: _noteCtrl,
                    keyboard: TextInputType.text,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: qty > 0 && !_loading ? _submit : null,
                      icon: _loading
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        qty > 0
                            ? 'Nhập ${qty.toStringAsFixed(0)} ${widget.product.unit}'
                            : 'Nhập hàng',
                        style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController ctrl,
    required TextInputType keyboard,
    void Function(String)? onChanged,
    int maxLines = 1,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboard,
            maxLines: maxLines,
            onChanged: onChanged,
            decoration: _inputDecor(null),
            style: const TextStyle(fontSize: 14, color: _kInk),
          ),
        ],
      );

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600, color: _kMuted),
      );

  InputDecoration _inputDecor(String? hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
        filled: true,
        fillColor: _kBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kNavy, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      );

  Future<void> _submit() async {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    if (qty <= 0) return;

    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    try {
      final repo = ref.read(khoRepositoryProvider);
      final suppliers = ref.read(suppliersProvider).value ?? [];
      final supplier = suppliers
          .where((s) => s.id == _selectedSupplierId)
          .firstOrNull;

      await repo.receiveStock(
        productId: widget.product.id,
        productName: widget.product.name,
        quantity: qty,
        unitCost: double.tryParse(_costCtrl.text) ?? 0,
        supplierId: _selectedSupplierId,
        supplierName: supplier?.name,
        reference: _refCtrl.text.isEmpty ? null : _refCtrl.text,
        note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '✅ Đã nhập ${qty.toStringAsFixed(0)} ${widget.product.unit} — ${widget.product.name}'),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: const Color(0xFFC62828),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatMoney(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
