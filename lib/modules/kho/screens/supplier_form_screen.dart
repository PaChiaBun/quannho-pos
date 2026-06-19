import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/kho_providers.dart';
import '../repository/kho_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLIER FORM SCREEN — Thêm / Sửa nhà cung cấp
// ─────────────────────────────────────────────────────────────────────────────

const _kNavy   = Color(0xFF1C2151);
const _kViolet = Color(0xFF7C3AED);
const _kBg     = Color(0xFFF4F4F8);
const _kCard   = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE5E0F5);
const _kMuted  = Color(0xFF9CA3AF);
const _kLabel  = Color(0xFF6B7280);
const _kInk    = Color(0xFF111827);
const _kGreen  = Color(0xFF059669);
const _kRed    = Color(0xFFDC2626);

const _categoryChips = [
  'Rau củ quả', 'Hải sản tươi', 'Thịt & Gia cầm',
  'Đồ khô & Gia vị', 'Đồ uống & Nước giải khát',
  'Bánh & Nguyên liệu', 'Bao bì & Vật tư', 'Khác',
];

class SupplierFormScreen extends ConsumerStatefulWidget {
  final SupplierModel? supplier;
  const SupplierFormScreen({super.key, this.supplier});

  @override
  ConsumerState<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends ConsumerState<SupplierFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _nameCtrl    = TextEditingController(text: widget.supplier?.name);
  late final _phoneCtrl   = TextEditingController(text: widget.supplier?.phone);
  late final _contactCtrl = TextEditingController(text: widget.supplier?.contactPerson);
  late final _emailCtrl   = TextEditingController(text: widget.supplier?.email);
  late final _addrCtrl    = TextEditingController(text: widget.supplier?.address);
  late final _bankCtrl    = TextEditingController(text: widget.supplier?.bankAccount);
  late final _payTermCtrl = TextEditingController(text: widget.supplier?.paymentTerms);
  late final _noteCtrl    = TextEditingController(text: widget.supplier?.note);
  late final _customTagCtrl = TextEditingController();
  final _customTagFocus = FocusNode();

  late final Set<String> _selectedTags = widget.supplier?.category != null
      ? widget.supplier!.category!.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet()
      : {};
  bool _loading = false;

  bool get _isEdit => widget.supplier != null;

  @override
  void dispose() {
    _customTagCtrl.dispose();
    _customTagFocus.dispose();
    for (final c in [_nameCtrl, _phoneCtrl, _contactCtrl, _emailCtrl,
        _addrCtrl, _bankCtrl, _payTermCtrl, _noteCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kNavy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEdit ? 'Sửa nhà cung cấp' : 'Thêm nhà cung cấp',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _loading ? null : _submit,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              child: Text(
                _loading ? 'Đang lưu...' : 'LƯU',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w800,
                    fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
          children: [
            // ── THÔNG TIN CƠ BẢN ──────────────────────────────────────────
            _sectionHeader('Thông tin cơ bản', Icons.business_rounded),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.store_rounded,
              label: 'Tên nhà cung cấp',
              required: true,
              child: TextFormField(
                controller: _nameCtrl,
                style: _inputStyle,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc nhập' : null,
                decoration: _inputDeco('Ví dụ: Công ty Rau sạch ABC', icon: Icons.store_rounded),
              ),
            ),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.phone_rounded,
              label: 'Số điện thoại',
              child: TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: _inputStyle,
                decoration: _inputDeco('0912 345 678', icon: Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.person_rounded,
              label: 'Người liên hệ',
              child: TextFormField(
                controller: _contactCtrl,
                style: _inputStyle,
                decoration: _inputDeco('Tên người phụ trách đặt hàng', icon: Icons.person_rounded),
              ),
            ),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.email_rounded,
              label: 'Email',
              child: TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: _inputStyle,
                decoration: _inputDeco('ncc@email.com', icon: Icons.email_rounded),
              ),
            ),

            const SizedBox(height: 20),

            // ── MẶT HÀNG CHÍNH ────────────────────────────────────────────
            _sectionHeader('Mặt hàng chính', Icons.category_rounded),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Chọn nhiều loại hàng NCC cung cấp',
                      style: GoogleFonts.outfit(
                          fontSize: 13, color: _kLabel,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: [
                      ..._categoryChips.map((chip) {
                        final isSelected = _selectedTags.contains(chip);
                        return _Chip(
                          label: chip,
                          selected: isSelected,
                          onTap: () => setState(() {
                            if (isSelected) {
                              _selectedTags.remove(chip);
                            } else {
                              _selectedTags.add(chip);
                            }
                          }),
                        );
                      }),
                      // Custom chips added by user
                      ..._selectedTags
                          .where((t) => !_categoryChips.contains(t))
                          .map((tag) => _Chip(
                                label: tag,
                                selected: true,
                                isCustom: true,
                                onTap: () => setState(() => _selectedTags.remove(tag)),
                              )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Custom tag input
                  TextField(
                    controller: _customTagCtrl,
                    focusNode: _customTagFocus,
                    style: _inputStyle,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (val) => _addCustomTag(val),
                    decoration: InputDecoration(
                      hintText: 'Nhập thêm loại hàng → nhấn Enter',
                      hintStyle: GoogleFonts.outfit(fontSize: 13.5, color: _kMuted),
                      filled: true,
                      fillColor: const Color(0xFFF8F7FF),
                      prefixIcon: const Icon(Icons.add_rounded, size: 18, color: _kViolet),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_rounded, size: 18, color: _kViolet),
                        onPressed: () => _addCustomTag(_customTagCtrl.text),
                      ),
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
                        borderSide: const BorderSide(color: _kViolet, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── THANH TOÁN ────────────────────────────────────────────────
            _sectionHeader('Thông tin thanh toán', Icons.account_balance_wallet_rounded),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.receipt_long_rounded,
              label: 'Điều khoản thanh toán',
              child: TextFormField(
                controller: _payTermCtrl,
                style: _inputStyle,
                decoration: _inputDeco('Ví dụ: Trả ngay / Công nợ 7 ngày...', icon: Icons.receipt_long_rounded),
              ),
            ),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.account_balance_rounded,
              label: 'Số tài khoản ngân hàng',
              child: TextFormField(
                controller: _bankCtrl,
                style: _inputStyle,
                decoration: _inputDeco('VCB 1234567890 - Nguyễn Văn A', icon: Icons.account_balance_rounded),
              ),
            ),

            const SizedBox(height: 20),

            // ── ĐỊA CHỈ & GHI CHÚ ────────────────────────────────────────
            _sectionHeader('Địa chỉ & Ghi chú', Icons.location_on_rounded),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.location_on_rounded,
              label: 'Địa chỉ',
              child: TextFormField(
                controller: _addrCtrl,
                maxLines: 2,
                style: _inputStyle,
                decoration: _inputDeco('123 Đường ABC, Quận 1, TP.HCM', icon: Icons.location_on_rounded),
              ),
            ),
            const SizedBox(height: 8),
            _buildRow(
              icon: Icons.sticky_note_2_rounded,
              label: 'Ghi chú nội bộ',
              child: TextFormField(
                controller: _noteCtrl,
                maxLines: 3,
                style: _inputStyle,
                decoration: _inputDeco('Giao hàng sáng sớm, tối thiểu 500K...', icon: Icons.sticky_note_2_rounded),
              ),
            ),


            const SizedBox(height: 28),

            // ── Nút lưu ──────────────────────────────────────────────────
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(
                        _isEdit
                            ? 'Cập nhật nhà cung cấp'
                            : 'Thêm nhà cung cấp',
                        style: GoogleFonts.outfit(
                            fontSize: 15, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  TextStyle get _inputStyle =>
      GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600, color: _kInk);

  InputDecoration _inputDeco(String hint, {IconData? icon}) => InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.outfit(fontSize: 14.5, color: _kMuted),
    prefixIcon: icon != null
        ? Icon(icon, size: 18, color: _kViolet.withValues(alpha: 0.55))
        : null,
    filled: true,
    fillColor: const Color(0xFFF8F7FF),
    isDense: false,
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
      borderSide: const BorderSide(color: _kViolet, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );

  Widget _sectionHeader(String text, IconData icon) => Row(
    children: [
      Icon(icon, size: 16, color: _kViolet),
      const SizedBox(width: 7),
      Text(
        text.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12.5, fontWeight: FontWeight.w800,
          color: _kNavy, letterSpacing: 0.5,
        ),
      ),
    ],
  );

  Widget _buildCard(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _kBorder),
    ),
    child: Column(children: children),
  );

  Widget _divider() => const Divider(
      height: 1, color: Color(0xFFF3F4F6), indent: 16, endIndent: 16);

  Widget _buildRow({
    required IconData icon,
    required String label,
    required Widget child,
    bool required = false,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label,
                style: GoogleFonts.outfit(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _kLabel)),
            if (required)
              const Text(' *',
                  style: TextStyle(
                      color: _kRed, fontSize: 13, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 6),
          child,
        ],
      );

  void _addCustomTag(String val) {
    final tag = val.trim();
    if (tag.isNotEmpty) {
      setState(() => _selectedTags.add(tag));
      _customTagCtrl.clear();
      _customTagFocus.requestFocus();
    }
  }

  // ── Submit ──────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    // Also add any unsaved custom tag
    if (_customTagCtrl.text.trim().isNotEmpty) {
      _selectedTags.add(_customTagCtrl.text.trim());
    }
    final category = _selectedTags.isEmpty ? null : _selectedTags.join(', ');

    String? _n(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();

    try {
      final repo = ref.read(khoRepositoryProvider);
      if (_isEdit) {
        await repo.updateSupplier(
          widget.supplier!.id,
          name:          _nameCtrl.text.trim(),
          phone:         _n(_phoneCtrl),
          contactPerson: _n(_contactCtrl),
          email:         _n(_emailCtrl),
          address:       _n(_addrCtrl),
          bankAccount:   _n(_bankCtrl),
          paymentTerms:  _n(_payTermCtrl),
          note:          _n(_noteCtrl),
          category:      category,
        );
      } else {
        await repo.addSupplier(
          name:          _nameCtrl.text.trim(),
          phone:         _n(_phoneCtrl),
          contactPerson: _n(_contactCtrl),
          email:         _n(_emailCtrl),
          address:       _n(_addrCtrl),
          bankAccount:   _n(_bankCtrl),
          paymentTerms:  _n(_payTermCtrl),
          note:          _n(_noteCtrl),
          category:      category,
        );
      }
      HapticFeedback.heavyImpact();
      ref.invalidate(suppliersProvider);
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              _isEdit
                  ? 'Đã cập nhật nhà cung cấp'
                  : 'Đã thêm nhà cung cấp',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
            ),
          ]),
          backgroundColor: _kGreen,
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
          backgroundColor: _kRed,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHIP WIDGET
// ─────────────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isAdd;
  final bool isCustom;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isAdd = false,
    this.isCustom = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? _kViolet
            : isAdd
                ? _kViolet.withValues(alpha: 0.06)
                : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? _kViolet
              : isAdd
                  ? _kViolet.withValues(alpha: 0.3)
                  : const Color(0xFFE5E7EB),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected
                  ? Colors.white
                  : isAdd
                      ? _kViolet
                      : const Color(0xFF374151),
            ),
          ),
          if (isCustom) ...[
            const SizedBox(width: 4),
            const Icon(Icons.close_rounded, size: 13, color: Colors.white),
          ],
        ],
      ),
    ),
  );
}
