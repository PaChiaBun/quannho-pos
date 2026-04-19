import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pos_providers.dart';
import '../../../core/providers/app_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHECKOUT BOTTOM SHEET
// Hiện khi nhấn "Thanh toán" — full screen modal
// ─────────────────────────────────────────────────────────────────────────────
class CheckoutSheet extends ConsumerStatefulWidget {
  const CheckoutSheet({super.key});

  @override
  ConsumerState<CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<CheckoutSheet> {
  String _selectedPayment = 'cash';
  bool _success = false;
  String? _orderNumber;

  static const _kNavy   = Color(0xFF1E1C5E);
  static const _kInk    = Color(0xFF1A1207);
  static const _kMuted  = Color(0xFF9E9085);
  static const _kBg     = Color(0xFFFAF7F2);

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    if (_success) return _buildSuccessView();

    return Container(
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
              color: const Color(0xFFE0D8CC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text('Thanh toán',
                  style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900,
                    color: _kInk, letterSpacing: -0.5,
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

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Order summary ──────────────────────────────────────
                  _buildOrderSummary(cart),
                  const SizedBox(height: 20),

                  // ── Payment method ─────────────────────────────────────
                  const Text('Phương thức',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: _kMuted, letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildPaymentMethods(),
                  const SizedBox(height: 20),

                  // ── Loyalty section ────────────────────────────────────
                  if (cart.customerId != null &&
                      cart.loyaltyPtsAvailable > 0)
                    _buildLoyaltySection(cart),

                  // ── Total breakdown ────────────────────────────────────
                  _buildTotalBreakdown(cart),
                  const SizedBox(height: 24),

                  // ── Confirm button ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: cart.isProcessing ? null : _doCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _kNavy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: cart.isProcessing
                          ? const SizedBox(
                              width: 24, height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                          : Text(
                              'Xác nhận • ${_formatMoney(cart.total.toInt())}đ',
                              style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary(CartState cart) {
    return Container(
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: cart.lines.asMap().entries.map((e) {
          final line = e.value;
          final isLast = e.key == cart.lines.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    Text(
                      '${line.quantity.toInt()}×',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 14,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(line.productName,
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                      ),
                    ),
                    Text(
                      '${_formatMoney(line.subtotal.toInt())}đ',
                      style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast)
                const Divider(height: 1, color: Color(0xFFE0D8CC)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final methods = [
      ('cash', Icons.payments_rounded, 'Tiền mặt'),
      ('transfer', Icons.account_balance_rounded, 'Chuyển khoản'),
      ('card', Icons.credit_card_rounded, 'Thẻ'),
    ];
    return Row(
      children: methods.map((m) {
        final isSelected = _selectedPayment == m.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedPayment = m.$1);
              ref.read(cartProvider.notifier).setPaymentMethod(m.$1);
            },
            child: AnimatedContainer(
              duration: 200.ms,
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? _kNavy : _kBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? _kNavy : const Color(0xFFE0D8CC),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(m.$2,
                    color: isSelected ? Colors.white : _kMuted, size: 22),
                  const SizedBox(height: 4),
                  Text(m.$3,
                    style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : _kMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLoyaltySection(CartState cart) {
    final maxUse = cart.loyaltyPtsAvailable.toInt();
    final used = cart.loyaltyPtsUsed.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Điểm thưởng',
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: _kMuted, letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.stars_rounded,
                color: Color(0xFF2E7D32), size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cart.customerName} • $maxUse điểm',
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    Text(
                      used > 0 ? 'Đang dùng $used điểm (-${_formatMoney(used)}đ)'
                               : 'Có thể dùng tối đa $maxUse điểm',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: used > 0,
                activeThumbColor: const Color(0xFF2E7D32),
                activeTrackColor: const Color(0xFFA5D6A7),
                onChanged: (v) {
                  ref.read(cartProvider.notifier).setLoyaltyPtsUsed(
                    v ? cart.loyaltyPtsAvailable : 0,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTotalBreakdown(CartState cart) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _TotalRow('Tạm tính', cart.subtotal.toInt()),
          if (cart.discount > 0) ...[
            const SizedBox(height: 8),
            _TotalRow('Giảm giá', -cart.discount.toInt(),
              color: const Color(0xFF2E7D32)),
          ],
          if (cart.loyaltyPtsUsed > 0) ...[
            const SizedBox(height: 8),
            _TotalRow('Dùng điểm', -cart.loyaltyPtsUsed.toInt(),
              color: const Color(0xFF2E7D32)),
          ],
          const Divider(height: 20, color: Color(0xFFE0D8CC)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TỔNG CỘNG',
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800,
                  color: _kInk, letterSpacing: 0.5,
                )),
              Text(
                '${_formatMoney(cart.total.toInt())}đ',
                style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900,
                  color: _kNavy, letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Success view ───────────────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32), size: 48,
            ),
          )
              .animate()
              .scale(begin: const Offset(0, 0), duration: 400.ms,
                    curve: Curves.elasticOut),
          const SizedBox(height: 20),
          const Text('Thanh toán thành công!',
            style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w900, color: _kInk)),
          if (_orderNumber != null) ...[
            const SizedBox(height: 8),
            Text('Đơn $_orderNumber',
              style: const TextStyle(fontSize: 14, color: _kMuted)),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text('Đơn mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Checkout action ────────────────────────────────────────────────────────
  Future<void> _doCheckout() async {
    HapticFeedback.mediumImpact();
    try {
      final loyaltyRate =
          await ref.read(loyaltyRateProvider.future);
      final orderId = await ref
          .read(cartProvider.notifier)
          .checkout(ref.read(posRepositoryProvider),
              loyaltyRate: loyaltyRate);

      // Lấy order number để hiển thị
      final order = await ref.read(posRepositoryProvider).getOrderById(orderId);
      if (mounted) {
        setState(() {
          _success = true;
          _orderNumber = order?.orderNumber;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    }
  }

  String _formatMoney(int amount) {
    if (amount < 0) {
      return '-${_formatMoney(-amount)}';
    }
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final int amount;
  final Color? color;
  const _TotalRow(this.label, this.amount, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF9E9085))),
        Text(
          '${amount < 0 ? '-' : ''}${_fmt(amount.abs())}đ',
          style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: color ?? const Color(0xFF1A1207),
          ),
        ),
      ],
    );
  }

  String _fmt(int v) => v.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
