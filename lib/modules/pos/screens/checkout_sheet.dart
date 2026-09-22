import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/pos_providers.dart'; // posTodayStatsProvider
import '../../../core/providers/app_providers.dart';
import '../../../core/providers/session_provider.dart';
import '../../../core/providers/dashboard_providers.dart'; // invalidate sau checkout
import '../../../modules/finance/providers/finance_providers.dart'; // invalidate financeStats
import '../../../modules/bill_printer/screens/bill_preview_screen.dart';
import '../../../modules/bill_printer/providers/printer_settings_provider.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../screens/pos_screen.dart' show billPrinterModuleActiveProvider;
import '../models/coupon_model.dart';
import '../repository/pos_repository.dart';

final _checkoutNavigators = <NavigatorState>{};

/// Shared by mobile cart, desktop panel and the quick checkout button.
/// The guard is acquired synchronously, before even reading durable storage.
Future<void> openPosCheckout(BuildContext context, WidgetRef ref) async {
  final navigator = Navigator.of(context);
  if (ref.read(cartProvider).isProcessing ||
      !_checkoutNavigators.add(navigator))
    return;
  try {
    if (await recoverPendingPosSale(context, ref)) return;
    if (!context.mounted || ref.read(cartProvider).isEmpty) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const CheckoutSheet(),
    );
  } finally {
    _checkoutNavigators.remove(navigator);
  }
}

/// Available even with an empty cart after restarting the application.
Future<bool> recoverPendingPosSale(BuildContext context, WidgetRef ref) async {
  final repo = ref.read(posRepositoryProvider);
  try {
    final pending = await repo.pendingSale();
    if (!context.mounted || pending == null) return false;
    final intent = pending['intent'] as Map?;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thanh toán chưa đối soát'),
        content: Text(
          'Đơn cũ: ${intent?['expected_total'] ?? '?'}đ · ${intent?['payment_method'] ?? '?'}\n'
          'Tiếp tục đúng giao dịch đã lưu. Nếu server đã thu tiền, chỉ lấy lại kết quả; không thu lần hai. '
          'Sau khi xác nhận thành công sẽ xóa giỏ đang hiển thị để tránh bán lại đơn cũ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Để sau'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đối soát / tiếp tục đơn cũ'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return true;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PosRecoveryDialog(
        repo: repo,
        onRecovered: () {
          ref.read(cartProvider.notifier).clearCart();
          ref.invalidate(todayOrdersProvider);
          ref.invalidate(posTodayStatsProvider);
        },
      ),
    );
    return true;
  } catch (e) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    return true; // fail closed: do not open a new checkout
  }
}

class _PosRecoveryDialog extends StatefulWidget {
  final PosRepository repo;
  final VoidCallback onRecovered;
  const _PosRecoveryDialog({required this.repo, required this.onRecovered});
  @override
  State<_PosRecoveryDialog> createState() => _PosRecoveryDialogState();
}

class _PosRecoveryDialogState extends State<_PosRecoveryDialog> {
  late final Future<PosSaleResult> _result = widget.repo.recoverSale();
  bool _acknowledging = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: FutureBuilder<PosSaleResult>(
      future: _result,
      builder: (context, snapshot) {
        return AlertDialog(
          title: const Text('Đối soát thanh toán'),
          content: Text(
            snapshot.hasData
                ? 'Đã thanh toán: ${snapshot.data!.orderNumber}\n${snapshot.data!.totalAmount}đ\nKhông tự in lại. Có thể mở bill trong lịch sử để in thủ công.'
                : snapshot.hasError
                ? '${snapshot.error}'
                : 'Đang đối soát với server. Không thanh toán lại trên thiết bị khác.',
          ),
          actions: [
            if (snapshot.connectionState == ConnectionState.done)
              TextButton(
                onPressed: _acknowledging
                    ? null
                    : () async {
                        if (snapshot.hasData) {
                          setState(() => _acknowledging = true);
                          try {
                            await widget.repo.acknowledgeSale(snapshot.data!);
                            widget.onRecovered();
                          } catch (e) {
                            if (context.mounted) {
                              setState(() => _acknowledging = false);
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$e')));
                            }
                            return;
                          }
                        }
                        if (context.mounted) Navigator.pop(context);
                      },
                child: const Text('Đã hiểu'),
              ),
          ],
        );
      },
    ),
  );
}

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
  BillData? _billData; // lưu để in sau khi thanh toán
  bool _redeemRateReady = false;
  PosSaleResult? _saleResult;

  @override
  void initState() {
    super.initState();
    _selectedPayment = ref.read(cartProvider).paymentMethod;
    Future.microtask(_loadRedeemRate);
  }

  Future<void> _loadRedeemRate() async {
    try {
      final storeId =
          (await StoreAuthService.getStoreInfo())['store_id'] as String?;
      if (storeId == null) return;
      final row = await Supabase.instance.client
          .from('app_settings')
          .select('value')
          .eq('store_id', storeId)
          .eq('key', 'loyalty_redeem_rate')
          .maybeSingle()
          .timeout(const Duration(seconds: 5));
      final rate = row == null ? 1000.0 : double.parse(row['value'].toString());
      if (!mounted) return;
      ref.read(cartProvider.notifier).setLoyaltyRedeemRate(rate);
      setState(() => _redeemRateReady = true);
    } catch (e) {
      if (mounted) ref.read(cartProvider.notifier).setLoyaltyPtsUsed(0);
    }
  }

  static const _kNavy = Color(0xFF1E1C5E);
  static const _kInk = Color(0xFF1A1207);
  static const _kMuted = Color(0xFF9E9085);
  static const _kBg = Color(0xFFFAF7F2);
  static const _kOrange = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);

    if (_success) return _buildSuccessView();

    return PopScope(
      canPop: !_isProcessingLocal && !cart.isProcessing,
      child: AbsorbPointer(
        absorbing: _isProcessingLocal || cart.isProcessing,
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
                width: 40,
                height: 4,
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
                    const Text(
                      'Thanh toán',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _kInk,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context, false),
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
                      const Text(
                        'Phương thức',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _kMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildPaymentMethods(),
                      const SizedBox(height: 20),

                      // ── Loyalty section ────────────────────────────────────
                      // FIX #2: ẩn khi dùng ví (tránh double discount)
                      if (cart.customerId != null &&
                          cart.loyaltyPtsAvailable > 0 &&
                          _selectedPayment != 'wallet')
                        _buildLoyaltySection(cart),

                      // ── Voucher section ────────────────────────────────────
                      _buildVoucherSection(cart),

                      // ── Total breakdown ────────────────────────────────────
                      _buildTotalBreakdown(cart),
                      const SizedBox(height: 24),

                      // ── Confirm button ─────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              (cart.isProcessing ||
                                  _isProcessingLocal ||
                                  _isWalletInsufficient(cart))
                              ? null
                              : _doCheckout,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _kNavy,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: (cart.isProcessing || _isProcessingLocal)
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : _isWalletInsufficient(cart)
                              ? Text(
                                  '⚠️ Ví không đủ — cần thêm tiền mặt',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFFFA000),
                                  ),
                                )
                              : Text(
                                  'Xác nhận • ${fmtVnd(cart.total.toInt())}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                      SizedBox(
                        height: MediaQuery.of(context).viewInsets.bottom + 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Text(
                      '${line.quantity.toInt()}×',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        line.productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _kInk,
                        ),
                      ),
                    ),
                    Text(
                      fmtVnd(line.subtotal.toInt()),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kInk,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) const Divider(height: 1, color: Color(0xFFE0D8CC)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    final cart = ref.watch(cartProvider);
    final methods = [
      ('cash', Icons.payments_rounded, 'Tiền mặt'),
      ('transfer', Icons.account_balance_rounded, 'Chuyển khoản'),
      ('card', Icons.credit_card_rounded, 'Thẻ'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Các phương thức chuẩn
        Row(
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
                      Icon(
                        m.$2,
                        color: isSelected ? Colors.white : _kMuted,
                        size: 22,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        m.$3,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : _kMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        // Nút ví — chỉ hiện khi khách có balance
        if (cart.hasWallet) ...[
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              setState(() => _selectedPayment = 'wallet');
              ref.read(cartProvider.notifier).setPaymentMethod('wallet');
            },
            child: AnimatedContainer(
              duration: 200.ms,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: _selectedPayment == 'wallet'
                    ? const LinearGradient(
                        colors: [Color(0xFF1E1C5E), Color(0xFF4A148C)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      )
                    : null,
                color: _selectedPayment == 'wallet' ? null : _kBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedPayment == 'wallet'
                      ? const Color(0xFF1E1C5E)
                      : const Color(0xFFE0D8CC),
                  width: _selectedPayment == 'wallet' ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: _selectedPayment == 'wallet'
                        ? Colors.white
                        : _kMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Thanh toán bằng Ví',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _selectedPayment == 'wallet'
                                ? Colors.white
                                : _kMuted,
                          ),
                        ),
                        Text(
                          'Ví: ${fmtVnd(cart.walletRealAvailable.toInt())} thật'
                          ' + ${fmtVnd(cart.walletBonusAvailable.toInt())} bonus',
                          style: TextStyle(
                            fontSize: 11,
                            color: _selectedPayment == 'wallet'
                                ? Colors.white60
                                : _kMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_selectedPayment == 'wallet')
                    const Icon(
                      Icons.check_circle_rounded,
                      color: Color(0xFFF9A825),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),

          // Preview wallet breakdown khi chọn
          if (_selectedPayment == 'wallet') _buildWalletPreview(cart),
        ],
      ],
    );
  }

  /// FIX #3: Kiểm tra ví không đủ (chỉ block khi chọn wallet mode)
  bool _isWalletInsufficient(CartState cart) {
    if (_selectedPayment != 'wallet') return false;
    final bill = cart.total;
    final bonusCap = (bill * cart.walletBonusCapPct / 100).floorToDouble();
    final bonusExpired =
        cart.walletBonusExpiresAt != null &&
        cart.walletBonusExpiresAt!.isBefore(DateTime.now());
    final bonusUsed = bonusExpired
        ? 0.0
        : cart.walletBonusAvailable.clamp(0.0, bonusCap);
    final realUsed = (bill - bonusUsed).clamp(0.0, cart.walletRealAvailable);
    return (bill - bonusUsed - realUsed) >= 1;
  }

  Widget _buildWalletPreview(CartState cart) {
    final bill = cart.total;
    // FIX #4: dùng floor (đồng bộ với computeWalletUsage trong repo)
    final bonusCap = (bill * cart.walletBonusCapPct / 100).floorToDouble();
    final bonusExpired =
        cart.walletBonusExpiresAt != null &&
        cart.walletBonusExpiresAt!.isBefore(DateTime.now());
    final bonusUsed = bonusExpired
        ? 0.0
        : cart.walletBonusAvailable.clamp(0.0, bonusCap);
    final remaining = (bill - bonusUsed).clamp(0.0, double.infinity);
    final realUsed = remaining.clamp(0.0, cart.walletRealAvailable);
    final stillNeed = (bill - bonusUsed - realUsed).clamp(0.0, double.infinity);
    final isEnough = stillNeed < 1;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isEnough ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '🎁 Bonus dùng (≤${cart.walletBonusCapPct}%)',
                style: const TextStyle(fontSize: 12, color: Color(0xFF1B5E20)),
              ),
              Text(
                '- ${fmtVnd(bonusUsed.toInt())}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2E7D32),
                ),
              ),
            ],
          ),
          if (realUsed > 0) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '💵 Ví thật dùng',
                  style: TextStyle(fontSize: 12, color: Color(0xFF1B5E20)),
                ),
                Text(
                  '- ${fmtVnd(realUsed.toInt())}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E7D32),
                  ),
                ),
              ],
            ),
          ],
          if (!isEnough) ...[
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '⚠️ Cần thêm tiền mặt',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE65100),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  fmtVnd(stillNeed.toInt()),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE65100),
                  ),
                ),
              ],
            ),
          ],
          if (isEnough)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                '✅ Số dư ví đủ thanh toán toàn bộ đơn',
                style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoyaltySection(CartState cart) {
    final maxUse = cart.loyaltyPtsAvailable.toInt();
    final used = cart.loyaltyPtsUsed.toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Điểm thưởng',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kMuted,
            letterSpacing: 0.5,
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
              const Icon(
                Icons.stars_rounded,
                color: Color(0xFF2E7D32),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cart.customerName} • $maxUse điểm',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                    Text(
                      used > 0
                          ? 'Đang dùng $used điểm (-${fmtVnd(cart.pointsDiscount.toInt())})'
                          : 'Có thể dùng tối đa $maxUse điểm',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: used > 0,
                activeThumbColor: const Color(0xFF2E7D32),
                activeTrackColor: const Color(0xFFA5D6A7),
                onChanged: !_redeemRateReady
                    ? null
                    : (v) {
                        ref
                            .read(cartProvider.notifier)
                            .setLoyaltyPtsUsed(
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
            _TotalRow(
              'Giảm giá',
              -cart.discount.toInt(),
              color: const Color(0xFF2E7D32),
            ),
          ],
          if (cart.loyaltyPtsUsed > 0) ...[
            const SizedBox(height: 8),
            _TotalRow(
              'Dùng điểm',
              -cart.pointsDiscount.toInt(),
              color: const Color(0xFF2E7D32),
            ),
          ],
          const Divider(height: 20, color: Color(0xFFE0D8CC)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TỔNG CỘNG',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _kInk,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                fmtVnd(cart.total.toInt()),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kNavy,
                  letterSpacing: -0.5,
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
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF2E7D32),
              size: 48,
            ),
          ).animate().scale(
            begin: const Offset(0, 0),
            duration: 400.ms,
            curve: Curves.elasticOut,
          ),
          const SizedBox(height: 20),
          const Text(
            'Thanh toán thành công!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _kInk,
            ),
          ),
          if (_orderNumber != null) ...[
            const SizedBox(height: 8),
            Text(
              'Đơn $_orderNumber',
              style: const TextStyle(fontSize: 14, color: _kMuted),
            ),
          ],
          const SizedBox(height: 24),
          // Nút in hoá đơn — chỉ hiện khi module In Hoá Đơn active
          if (_billData != null && ref.watch(billPrinterModuleActiveProvider))
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.print_outlined, size: 20),
                label: const Text(
                  'In hoá đơn',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _kNavy,
                  side: const BorderSide(color: _kNavy, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  AppLogger.logUserAction(
                    tag: 'printer',
                    action: 'Manual POS receipt reprint',
                    details: {
                      'order_id': _saleResult?.orderId,
                      'order_number': _orderNumber,
                    },
                  );
                  final settings = ref.read(printerSettingsProvider);
                  StationPrinterDispatcher.printBill(
                    _billData!,
                    settings,
                    onlyReceipt: true,
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  if (_saleResult != null) {
                    await ref
                        .read(posRepositoryProvider)
                        .acknowledgeSale(_saleResult!);
                  }
                  if (!mounted) return;
                  Navigator.pop(this.context, true);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      this.context,
                    ).showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Đơn mới',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ‼️ FIX #V5: Guard chống double-tap — bổ sung ngoài cart.isProcessing
  // cart.isProcessing có thể bị frame lag, guard local chắc chắn hơn
  bool _isProcessingLocal = false;

  // ── Checkout action ────────────────────────────────────────────────────────
  Future<void> _doCheckout() async {
    if (_isProcessingLocal) return;
    setState(() => _isProcessingLocal = true);
    HapticFeedback.mediumImpact();
    try {
      final cartSnapshot = ref.read(cartProvider);
      final sRepo = ref.read(settingsRepositoryProvider);

      // Song song hóa việc lấy thông tin cấu hình và loyalty rate với timeout 2 giây
      final results = await Future.wait([
        sRepo.shopName.timeout(
          const Duration(seconds: 2),
          onTimeout: () => 'Quán Nhỏ',
        ),
        sRepo.shopPhone.timeout(
          const Duration(seconds: 2),
          onTimeout: () => '',
        ),
        sRepo.shopAddress.timeout(
          const Duration(seconds: 2),
          onTimeout: () => '',
        ),
        sRepo.billFooter.timeout(
          const Duration(seconds: 2),
          onTimeout: () => 'Cảm ơn quý khách!',
        ),
        ref
            .read(loyaltyRateProvider.future)
            .timeout(const Duration(seconds: 2), onTimeout: () => 10000.0),
      ]);

      final shopName = results[0] as String;
      final shopPhone = results[1] as String;
      final shopAddress = results[2] as String;
      final billFooter = results[3] as String;
      final loyaltyRate = results[4] as double;

      // Await the actual operation. An outer Future.timeout does not cancel
      // checkout and used to clear the cart silently after the UI showed failure.
      final saleResult = await ref
          .read(cartProvider.notifier)
          .checkout(
            ref.read(posRepositoryProvider),
            loyaltyRate: loyaltyRate,
            moduleRepo: ref.read(moduleRepositoryProvider),
          );
      final orderId = saleResult.orderId;
      final paymentLabel = cartSnapshot.paymentMethod == 'wallet'
          ? 'Ví (${saleResult.walletRealUsed.toInt()}đ thật + ${saleResult.walletBonusUsed.toInt()}đ bonus)'
          : cartSnapshot.paymentMethod;

      // Đánh dấu thành công ngay lập tức để chuyển sang màn hình success!
      // Tránh việc bất kỳ tác vụ phụ nào sau đó (lấy thông tin, invalidation) bị lỗi/timeout làm sập màn hình thanh toán về 0đ.
      if (mounted) {
        setState(() {
          _success = true;
          _saleResult = saleResult;
          _orderNumber = saleResult.orderNumber;
          _billData = BillData(
            shopName: shopName,
            shopPhone: shopPhone.isNotEmpty ? shopPhone : null,
            shopAddress: shopAddress.isNotEmpty ? shopAddress : null,
            footer: billFooter.isNotEmpty ? billFooter : null,
            orderNumber: saleResult.orderNumber,
            createdAt: DateTime.now(),
            tableName: cartSnapshot.tableName,
            items: cartSnapshot.lines
                .map(
                  (l) => BillItem(
                    name: l.productName,
                    qty: l.quantity.toInt(),
                    price: l.unitPrice,
                    stationCode: l.stationCode,
                  ),
                )
                .toList(),
            subtotal: saleResult.subtotal,
            discount: saleResult.discount,
            total: saleResult.totalAmount,
            paymentMethod: paymentLabel,
            customerName: cartSnapshot.customerName,
            loyaltyPoints: cartSnapshot.loyaltyPtsUsed > 0
                ? cartSnapshot.loyaltyPtsUsed.round()
                : null,
            waiterName: ref.read(sessionProvider)?.displayName,
          );
        });
        HapticFeedback.heavyImpact();
        // Tự động in bill phân trạm
        try {
          final settings = ref.read(printerSettingsProvider);
          final hasPrintServerOwner = hasActivePrintServerOwner(
            settings.ownerState,
          );
          if (settings.centralPrintRoutingEnabled && !hasPrintServerOwner) {
            AppLogger.info(
              'printer',
              '[Checkout Print] Local fallback: central routing enabled but Print Server Owner is missing or stale.',
            );
          }
          if (!saleResult.isReplay &&
              _billData != null &&
              shouldAutoPrintLocally(
                isWeb: kIsWeb,
                centralRoutingEnabled: settings.centralPrintRoutingEnabled,
                hasPrintServerOwner: hasPrintServerOwner,
                allowPrintServerFallback:
                    settings.deviceState.isPrintServer &&
                    settings.deviceState.allowBackgroundPrinting,
              )) {
            if (settings.autoPrintCheckout) {
              await ref
                  .read(printerSettingsProvider.notifier)
                  .printCheckoutReceipt(
                    storeId:
                        (await StoreAuthService.getStoreInfo())['store_id']
                            as String,
                    settlementId: orderId,
                    billData: _billData!,
                  );
            }
            final unsentItems = cartSnapshot.lines
                .where((line) => !cartSnapshot.isLineSent(line.lineId))
                .toList();
            if (settings.autoPrintKitchen && unsentItems.isNotEmpty) {
              await StationPrinterDispatcher.printBill(
                BillData(
                  shopName: shopName,
                  orderNumber: saleResult.orderNumber,
                  createdAt: DateTime.now(),
                  tableName: cartSnapshot.tableName,
                  subtotal: saleResult.subtotal,
                  total: saleResult.totalAmount,
                  items: unsentItems
                      .map(
                        (line) => BillItem(
                          name: line.productName,
                          qty: line.quantity.toInt(),
                          price: line.unitPrice,
                          note: line.note,
                          stationCode: line.stationCode,
                        ),
                      )
                      .toList(),
                ),
                settings,
                onlyKitchen: true,
              );
            }
          }
        } catch (e) {
          debugPrint('[POS AutoPrint] Tự động in bill phân trạm lỗi: $e');
        }
      }

      // Chạy các tác vụ phụ âm thầm & bảo vệ
      try {
        try {
          ref.invalidate(todayStatsProvider);
          ref.invalidate(financeRecordsProvider);
          ref.invalidate(financeStatsProvider);
          ref.invalidate(todayFinanceStatsProvider);
          final ch = Supabase.instance.client.channel('store_broadcast');
          ch.subscribe();
          ch
              .sendBroadcastMessage(event: 'checkout_completed', payload: {})
              .then((_) => ch.unsubscribe());
        } catch (e) {
          debugPrint('[POS Invalidation] error: $e');
        }

        if (mounted) {
          setState(() {
            _orderNumber = saleResult.orderNumber;
            _billData = BillData(
              shopName: shopName,
              shopPhone: shopPhone.isNotEmpty ? shopPhone : null,
              shopAddress: shopAddress.isNotEmpty ? shopAddress : null,
              footer: billFooter.isNotEmpty ? billFooter : null,
              orderNumber: saleResult.orderNumber,
              createdAt: DateTime.now(),
              tableName: cartSnapshot.tableName,
              items: cartSnapshot.lines
                  .map(
                    (l) => BillItem(
                      name: l.productName,
                      qty: l.quantity.toInt(),
                      price: l.unitPrice,
                      stationCode: l.stationCode,
                    ),
                  )
                  .toList(),
              subtotal: saleResult.subtotal,
              discount: saleResult.discount,
              total: saleResult.totalAmount,
              paymentMethod: paymentLabel,
              customerName: cartSnapshot.customerName,
              loyaltyPoints: cartSnapshot.loyaltyPtsUsed > 0
                  ? cartSnapshot.loyaltyPtsUsed.round()
                  : null,
              waiterName: ref.read(sessionProvider)?.displayName,
            );
          });
        }
      } catch (e) {
        debugPrint(
          '[POS Checkout] Tác vụ phụ thất bại nhưng giao dịch chính đã thành công: $e',
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessingLocal = false);
      if (mounted) {
        String userFriendlyError = 'Lỗi: $e';
        if (e is TimeoutException) {
          userFriendlyError =
              'Kết nối mạng chậm hoặc không ổn định. Vui lòng kiểm tra và thử lại!';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError),
            backgroundColor: const Color(0xFFC62828),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Widget _buildVoucherSection(CartState cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Khuyến mãi / Voucher',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_offer_rounded,
                color: Color(0xFFE65100),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cart.appliedCoupon != null
                          ? 'Mã: ${cart.appliedCoupon!.code}'
                          : 'Chưa áp dụng voucher',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFE65100),
                      ),
                    ),
                    Text(
                      cart.appliedCoupon != null
                          ? (cart.appliedCoupon!.discountType == 'percent'
                                ? 'Giảm ${cart.appliedCoupon!.value.toInt()}% (Tối đa ${fmtVnd(cart.appliedCoupon!.maxDiscountAmount?.toInt() ?? 0)})'
                                : 'Giảm ${fmtVnd(cart.appliedCoupon!.value.toInt())}')
                          : 'Chọn mã giảm giá từ cửa hàng',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
              if (cart.appliedCoupon != null)
                TextButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).removeCoupon();
                  },
                  child: const Text(
                    'Gỡ mã',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                TextButton(
                  onPressed: () => _selectVoucher(cart),
                  child: const Text(
                    'Chọn mã',
                    style: TextStyle(
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  void _selectVoucher(CartState cart) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return FutureBuilder<List<CouponModel>>(
          future: ref.read(posRepositoryProvider).getCoupons(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: CircularProgressIndicator(color: _kOrange),
                ),
              );
            }
            final list = snapshot.data ?? [];
            final activeList = list.where((c) {
              final isExpired =
                  c.endDate != null && c.endDate!.isBefore(DateTime.now());
              return c.isActive && !isExpired;
            }).toList();

            if (activeList.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child: Text('Không có voucher khả dụng lúc này'),
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chọn Voucher giảm giá',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _kNavy,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: activeList.length,
                      itemBuilder: (ctx, idx) {
                        final c = activeList[idx];
                        final sub = cart.subtotal;
                        final isApplicable = sub >= c.minOrderAmount;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 4,
                          ),
                          leading: const Icon(
                            Icons.local_offer_rounded,
                            color: _kOrange,
                          ),
                          title: Text(
                            c.code,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: _kNavy,
                            ),
                          ),
                          subtitle: Text(
                            c.discountType == 'percent'
                                ? 'Giảm ${c.value.toInt()}% (Đơn tối thiểu ${fmtVnd(c.minOrderAmount.toInt())})'
                                : 'Giảm ${fmtVnd(c.value.toInt())} (Đơn tối thiểu ${fmtVnd(c.minOrderAmount.toInt())})',
                            style: TextStyle(
                              color: isApplicable
                                  ? Colors.black54
                                  : Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                          trailing: ElevatedButton(
                            onPressed: isApplicable
                                ? () {
                                    ref
                                        .read(cartProvider.notifier)
                                        .applyCoupon(c);
                                    Navigator.pop(ctx);
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kOrange,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: const Text('Áp dụng'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
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
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: Color(0xFF9E9085)),
        ),
        Text(
          fmtVnd(amount),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color ?? const Color(0xFF1A1207),
          ),
        ),
      ],
    );
  }
}
