import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/repositories/billing_repository.dart';
import '../core/utils/billing_platform.dart';
import '../core/utils/money_formatter.dart';
import '../core/utils/vietqr.dart';

/// Màn "Gói & thanh toán" (cổng thu phí đợt A) — CHỈ Chủ quán, CHỈ web / bản máy tính (billingAllowedHere()).
/// Chọn gói → máy chủ tạo đơn (mã QNxxxxxx) → app vẽ VietQR tại máy → chủ quán chuyển khoản → chờ xác nhận
/// (đợt A: quản trị bấm tay; đợt B: SePay tự báo) → app hỏi lại trạng thái mỗi [pollEvery].
class BillingScreen extends StatefulWidget {
  final String storeId;
  final BillingRepository repository;
  final Duration pollEvery;
  final bool? allowedOverride; // test

  const BillingScreen({
    super.key,
    required this.storeId,
    this.repository = const BillingRepository(),
    this.pollEvery = const Duration(seconds: 5),
    this.allowedOverride,
  });

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

String _ddmmyyyy(DateTime? d) => d == null
    ? '—'
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

class _BillingScreenState extends State<BillingScreen> {
  static const _kNavy = Color(0xFF1E1C5E);
  static const _kOrange = Color(0xFFE85D20);
  static const _kGreen = Color(0xFF2E7D32);
  static const _kBg = Color(0xFFFAF7F2);

  BillingInfo? _info;
  BillingOrder? _order; // đơn đang hiện mã QR
  String? _error;
  bool _loading = true;
  String? _creatingPlan;
  bool _justPaid = false;
  bool _checking = false; // mạng chậm: không hỏi chồng lần trước
  Timer? _poll;

  bool get _allowed => widget.allowedOverride ?? billingAllowedHere();

  @override
  void initState() {
    super.initState();
    if (_allowed) _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await widget.repository.info(widget.storeId);
      if (!mounted) return;
      setState(() {
        _info = info;
        _order = info.pending;
        _loading = false;
      });
      _startPolling();
    } on BillingException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
      // đã có dữ liệu (kéo làm mới) → báo bằng thanh dưới, giữ màn cũ
      if (_info != null) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  // "Chọn gói khác" khi đang có mã chờ: hỏi đã chuyển khoản chưa — đã chuyển thì giữ mã, chờ đối soát (QC 28/10)
  Future<void> _askChooseOther(BillingOrder o) async {
    final transferred = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Anh/chị đã chuyển khoản chưa?'),
        content: Text('Nếu ĐÃ chuyển tiền cho mã ${o.code}, hãy giữ nguyên màn này để chờ xác nhận — đừng tạo mã mới.'),
        actions: [
          TextButton(
            key: const Key('billing_already_paid'),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đã chuyển, chờ xác nhận'),
          ),
          FilledButton(
            key: const Key('billing_not_paid'),
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Chưa chuyển, chọn gói khác'),
          ),
        ],
      ),
    );
    if (transferred != false || !mounted) return;
    _poll?.cancel();
    setState(() => _order = null);
  }

  void _startPolling() {
    _poll?.cancel();
    final order = _order;
    if (order == null || !order.isPending) return;
    _poll = Timer.periodic(widget.pollEvery, (_) => _checkOrder(order.id));
  }

  Future<void> _checkOrder(String orderId) async {
    if (_checking) return;
    _checking = true;
    try {
      final o = await widget.repository.orderStatus(orderId);
      if (!mounted || _order?.id != orderId) return;
      if (o.isPaid) {
        _poll?.cancel();
        setState(() {
          _justPaid = true;
          _order = null;
        });
        await _load();
      } else if (!o.isPending) {
        _poll?.cancel();
        setState(() => _order = o);
      }
    } on BillingException {
      // mất mạng tạm thời: lần sau hỏi lại
    } finally {
      _checking = false;
    }
  }

  Future<void> _choose(BillingPlan plan) async {
    if (_creatingPlan != null) return;
    setState(() {
      _creatingPlan = plan.code;
      _justPaid = false;
    });
    try {
      final o = await widget.repository.createOrder(widget.storeId, plan.code);
      if (!mounted) return;
      setState(() {
        _order = o;
        _creatingPlan = null;
      });
      _startPolling();
    } on BillingException catch (e) {
      if (!mounted) return;
      setState(() => _creatingPlan = null);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _copy(String text, String what) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('Đã sao chép $what')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        title: const Text('Gói & thanh toán'),
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
      ),
      body: !_allowed
          ? const Center(child: Text('Không khả dụng trên thiết bị này.'))
          : _loading && _info == null
              ? const Center(child: CircularProgressIndicator())
              : _error != null && _info == null
                  ? _errorView()
                  : RefreshIndicator(onRefresh: _load, child: _content()),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_error!, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Thử lại')),
      ]),
    ),
  );

  Widget _content() {
    final info = _info!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _currentPlanCard(info),
            if (_justPaid) _paidBanner(info),
            const SizedBox(height: 16),
            if (info.bank == null)
              _note('Quán Nhỏ chưa mở thanh toán. Vui lòng quay lại sau.')
            else if (_order != null)
              _orderCard(_order!, info.bank!)
            else ...[
              const Text('Chọn gói Pro', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              for (final p in info.plans) _planTile(p),
            ],
            if (info.history.isNotEmpty) ...[
              const SizedBox(height: 22),
              const Text('Đã thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final h in info.history)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: _kGreen),
                  title: Text('${h.planName} · ${fmtVnd(h.amountVnd)}'),
                  subtitle: Text('Mã ${h.code} · ${_ddmmyyyy(h.paidAt)}'),
                ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _card({required Widget child, Color? border}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: border ?? const Color(0xFFE0D8CC)),
    ),
    child: child,
  );

  Widget _note(String text) => _card(child: Text(text, style: const TextStyle(fontSize: 14.5, height: 1.4)));

  Widget _currentPlanCard(BillingInfo info) {
    final String title;
    final String sub;
    if (info.isPro) {
      title = 'Gói Pro';
      sub = info.planEndsAt == null ? 'Không thời hạn' : 'Dùng đến ${_ddmmyyyy(info.planEndsAt)}';
    } else {
      title = 'Gói dùng thử';
      sub = info.trialEndsAt == null ? '' : 'Dùng thử đến ${_ddmmyyyy(info.trialEndsAt)}';
    }
    return _card(
      child: Row(children: [
        Icon(info.isPro ? Icons.workspace_premium : Icons.hourglass_bottom, color: info.isPro ? _kOrange : _kNavy, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(info.storeName, style: const TextStyle(fontSize: 13, color: Color(0xFF7A7068))),
            Text(title, key: const Key('billing_current_plan'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (sub.isNotEmpty) Text(sub, style: const TextStyle(fontSize: 14)),
          ]),
        ),
      ]),
    );
  }

  Widget _paidBanner(BillingInfo info) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: _card(
      border: _kGreen,
      child: Row(children: [
        const Icon(Icons.verified, color: _kGreen),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Đã nhận tiền. Gói Pro dùng đến ${_ddmmyyyy(info.planEndsAt)}. Cảm ơn anh/chị!',
            key: const Key('billing_paid_banner'),
            style: const TextStyle(fontWeight: FontWeight.w700, color: _kGreen),
          ),
        ),
      ]),
    ),
  );

  Widget _planTile(BillingPlan p) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _card(
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            Text(fmtVnd(p.priceVnd), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kOrange)),
            if (p.months > 1)
              Text('≈ ${fmtVnd(p.pricePerMonth)} / tháng', style: const TextStyle(fontSize: 13, color: Color(0xFF7A7068))),
          ]),
        ),
        FilledButton(
          key: Key('billing_choose_${p.code}'),
          style: FilledButton.styleFrom(backgroundColor: _kNavy, minimumSize: const Size(96, 44)),
          onPressed: _creatingPlan == null ? () => _choose(p) : null,
          child: _creatingPlan == p.code
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Chọn'),
        ),
      ]),
    ),
  );

  Widget _orderCard(BillingOrder o, BillingBank bank) {
    if (!o.isPending) {
      return _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(o.status == 'expired' ? 'Đơn ${o.code} đã quá 24 giờ.' : 'Đơn ${o.code} đã huỷ.',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Nếu anh/chị ĐÃ chuyển khoản, đừng chuyển lại — Quán Nhỏ sẽ đối soát và gia hạn.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => setState(() => _order = null), child: const Text('Chọn gói khác')),
        ]),
      );
    }
    String? payload;
    try {
      payload = buildVietQrPayload(bin: bank.bin, accountNo: bank.accountNo, amount: o.amountVnd, content: o.code);
    } catch (_) {
      payload = null;
    }
    return _card(
      border: _kOrange,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Thanh toán ${o.planName}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Mở app ngân hàng, quét mã dưới đây. Số tiền và nội dung đã điền sẵn — đừng sửa nội dung.',
            style: TextStyle(fontSize: 13.5, height: 1.4)),
        const SizedBox(height: 12),
        if (payload != null)
          Center(
            child: Container(
              key: const Key('billing_qr'),
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: QrImageView(data: payload, size: 220, backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M),
            ),
          )
        else
          const Text('Không vẽ được mã QR — chuyển khoản theo thông tin bên dưới.'),
        const SizedBox(height: 12),
        _copyRow('Số tiền', fmtVnd(o.amountVnd), o.amountVnd.toString(), 'số tiền'),
        _copyRow('Nội dung', o.code, o.code, 'nội dung', key: const Key('billing_order_code')),
        _copyRow('Số tài khoản', bank.accountNo, bank.accountNo, 'số tài khoản'),
        _infoRow('Ngân hàng', bank.bankName),
        _infoRow('Chủ tài khoản', bank.accountName),
        const SizedBox(height: 10),
        Row(children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Đang chờ tiền vào… Mã hết hạn lúc ${o.expiresAt == null ? '—' : '${o.expiresAt!.hour.toString().padLeft(2, '0')}:${o.expiresAt!.minute.toString().padLeft(2, '0')} ${_ddmmyyyy(o.expiresAt)}'}.',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        TextButton(
          key: const Key('billing_choose_other'),
          onPressed: () => _askChooseOther(o),
          child: const Text('Chọn gói khác'),
        ),
      ]),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Color(0xFF7A7068)))),
      Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  );

  Widget _copyRow(String label, String shown, String copied, String what, {Key? key}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Color(0xFF7A7068)))),
      Expanded(child: Text(shown, key: key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
      IconButton(tooltip: 'Sao chép $what', icon: const Icon(Icons.copy, size: 18), onPressed: () => _copy(copied, what)),
    ]),
  );
}
