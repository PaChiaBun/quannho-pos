import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_providers.dart';
import '../repository/finance_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ADD TRANSACTION SHEET — Bottom sheet thêm thu/chi
// ─────────────────────────────────────────────────────────────────────────────
class AddTransactionSheet extends ConsumerStatefulWidget {
  final String initialType; // 'income' | 'expense'

  const AddTransactionSheet({
    super.key,
    this.initialType = 'income',
  });

  @override
  ConsumerState<AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  late String _type;
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();
  String? _selectedCategoryId;
  bool _loading = false;

  static const _kNavy  = Color(0xFF1E1C5E);
  static const _kGreen = Color(0xFF2E7D32);
  static const _kRed   = Color(0xFFC62828);
  static const _kInk   = Color(0xFF1A1207);
  static const _kMuted = Color(0xFF9E9085);
  static const _kBg    = Color(0xFFFAF7F2);
  static const _kBorder= Color(0xFFE0D8CC);

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor => _type == 'income' ? _kGreen : _kRed;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = _type == 'income'
        ? ref.watch(incomeCategoriesProvider)
        : ref.watch(expenseCategoriesProvider);

    final amount = double.tryParse(
      _amountCtrl.text.replaceAll(',', '')) ?? 0;

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
            Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(2))),

            // Header — type switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
              child: Row(
                children: [
                  // Type toggle
                  Container(
                    decoration: BoxDecoration(
                      color: _kBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        _TypeTab(
                          label: '↓ Thu',
                          selected: _type == 'income',
                          color: _kGreen,
                          onTap: () => setState(() {
                            _type = 'income';
                            _selectedCategoryId = null;
                          }),
                        ),
                        _TypeTab(
                          label: '↑ Chi',
                          selected: _type == 'expense',
                          color: _kRed,
                          onTap: () => setState(() {
                            _type = 'expense';
                            _selectedCategoryId = null;
                          }),
                        ),
                      ],
                    ),
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

            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Số tiền — big input
                  _AmountInput(
                    ctrl: _amountCtrl,
                    accentColor: _accentColor,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),

                  // Danh mục
                  _label('Danh mục'),
                  const SizedBox(height: 8),
                  categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (cats) => Wrap(
                      spacing: 8, runSpacing: 8,
                      children: cats.map((c) {
                        final isSelected = _selectedCategoryId == c.id;
                        return GestureDetector(
                          onTap: () => setState(
                              () => _selectedCategoryId =
                                  isSelected ? null : c.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _accentColor
                                  : _kBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? _accentColor
                                    : _kBorder,
                              ),
                            ),
                            child: Text(
                              c.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : _kInk,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mô tả
                  _label('Ghi chú (tuỳ chọn)'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Nhập ghi chú...',
                      hintStyle: const TextStyle(
                          color: _kMuted, fontSize: 13),
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
                        borderSide: BorderSide(
                            color: _accentColor, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                    style: const TextStyle(
                        fontSize: 14, color: _kInk),
                  ),
                  const SizedBox(height: 24),

                  // Submit
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: amount > 0 && !_loading
                          ? _submit
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        disabledBackgroundColor:
                            _accentColor.withValues(alpha: 0.3),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5))
                          : Text(
                              amount > 0
                                  ? '${_type == 'income' ? 'Ghi thu' : 'Ghi chi'} • ${_fmtMoney(amount.toInt())}đ'
                                  : _type == 'income'
                                      ? 'Ghi thu'
                                      : 'Ghi chi',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _kMuted));

  Future<void> _submit() async {
    final amount = double.tryParse(
      _amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) return;

    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    try {
      await ref.read(financeRepositoryProvider).addRecord(
        type:        _type,
        amount:      amount,
        categoryId:  _selectedCategoryId,
        description: _descCtrl.text.isEmpty ? null : _descCtrl.text,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: _kRed,
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _fmtMoney(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

class _TypeTab extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _TypeTab({required this.label, required this.selected,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : const Color(0xFF9E9085),
        )),
    ),
  );
}

class _AmountInput extends StatelessWidget {
  final TextEditingController ctrl;
  final Color accentColor;
  final void Function(String) onChanged;

  const _AmountInput({
    required this.ctrl,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Số tiền',
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: Color(0xFF9E9085))),
      const SizedBox(height: 8),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('₫',
            style: TextStyle(
              fontSize: 28, fontWeight: FontWeight.w700,
              color: accentColor)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              onChanged: onChanged,
              style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900,
                color: accentColor, letterSpacing: -1),
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.w900,
                  color: accentColor.withValues(alpha: 0.3)),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
      Divider(height: 1, color: accentColor.withValues(alpha: 0.4),
        thickness: 2),
    ],
  );
}
