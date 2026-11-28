import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/repositories/store_plan_repository.dart';
import '../core/utils/billing_platform.dart';

/// Dải nhắc gói ở Trang chủ (chỉ Chủ quán): hết / sắp hết dùng thử, Pro hết / sắp hết.
/// Bấm ✕ thì ẩn tới hết ngày hôm nay (nhớ theo quán), hôm sau nhắc lại.
/// Dùng thử: có nút "Gia hạn thêm 30 ngày" (chưa thu phí — Chủ Quán 26/10); [onSelfExtend] trả mã lỗi, null = xong.
class StorePlanBanner extends StatefulWidget {
  final String storeId;
  final StorePlanStatus status;
  final DateTime Function() now;
  final Future<String?> Function()? onSelfExtend;
  final VoidCallback? onOpenBilling; // mở màn "Gói & thanh toán" — chỉ hiện nút khi [billingAllowed]
  final bool? billingAllowed; // mặc định billingAllowedHere(); test truyền thẳng

  const StorePlanBanner({
    super.key,
    required this.storeId,
    required this.status,
    this.now = DateTime.now,
    this.onSelfExtend,
    this.onOpenBilling,
    this.billingAllowed,
  });

  static String prefsKey(String storeId) => 'store_plan_notice_hidden_$storeId';
  static String dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  @override
  State<StorePlanBanner> createState() => _StorePlanBannerState();
}

class _StorePlanBannerState extends State<StorePlanBanner> {
  // Ngày đã bấm ẩn; so với "hôm nay" mỗi lần dựng → máy mở app liền nhiều ngày vẫn nhắc lại hôm sau
  String? _hiddenDay;
  bool get _hiddenToday => _hiddenDay == StorePlanBanner.dayKey(widget.now());
  bool _extending = false;
  bool _extended = false; // xong rồi thì ẩn nút (trạng thái cũ còn hiện trong lúc tải lại)

  Future<void> _selfExtend() async {
    if (_extending || widget.onSelfExtend == null) return;
    setState(() => _extending = true);
    final err = await widget.onSelfExtend!();
    if (!mounted) return;
    setState(() {
      _extending = false;
      _extended = err == null;
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(err == null
          ? 'Đã gia hạn thêm 30 ngày dùng thử.'
          : err == 'NOT_DUE'
              ? 'Quán vẫn còn hạn dùng thử, chưa cần gia hạn.'
              : 'Chưa gia hạn được, vui lòng thử lại.'),
    ));
  }

  @override
  void initState() {
    super.initState();
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final day = prefs.getString(StorePlanBanner.prefsKey(widget.storeId));
      if (day != null && mounted) setState(() => _hiddenDay = day);
    } catch (_) {}
  }

  Future<void> _hide() async {
    final today = StorePlanBanner.dayKey(widget.now());
    setState(() => _hiddenDay = today);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(StorePlanBanner.prefsKey(widget.storeId), today);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_hiddenToday || !widget.status.isOwner) return const SizedBox.shrink();
    final canPay = (widget.billingAllowed ?? billingAllowedHere()) && widget.onOpenBilling != null;
    final text = storePlanNoticeText(widget.status, widget.now(), billingAllowed: canPay);
    if (text == null) return const SizedBox.shrink();
    final expired = widget.status.notice == 'trial_expired' || widget.status.notice == 'pro_expired';
    final fg = expired ? const Color(0xFFB3261E) : const Color(0xFF8A5300);
    final bg = expired ? const Color(0xFFFDECEA) : const Color(0xFFFFF4E0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        key: const Key('store_plan_banner'),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(expired ? Icons.error_outline : Icons.schedule, color: fg, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text.title, style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: 14.5)),
                  const SizedBox(height: 3),
                  if (text.body.isNotEmpty) Text(text.body, style: TextStyle(color: fg, fontSize: 13.5, height: 1.35)),
                  if (canPay) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      key: const Key('store_plan_open_billing'),
                      style: OutlinedButton.styleFrom(foregroundColor: fg, side: BorderSide(color: fg), minimumSize: const Size(0, 44)),
                      onPressed: widget.onOpenBilling,
                      icon: const Icon(Icons.workspace_premium, size: 18),
                      label: const Text('Mua gói Pro'),
                    ),
                  ],
                  if (widget.status.canSelfExtend && widget.onSelfExtend != null && !_extended) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const Key('store_plan_self_extend'),
                      style: FilledButton.styleFrom(backgroundColor: fg, minimumSize: const Size(0, 44)),
                      onPressed: _extending ? null : _selfExtend,
                      icon: _extending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.update, size: 18),
                      label: const Text('Gia hạn thêm 30 ngày'),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Ẩn hôm nay',
              icon: Icon(Icons.close, color: fg, size: 20),
              onPressed: _hide,
            ),
          ],
        ),
      ),
    );
  }
}

/// Màn thay Trang chủ khi quản trị khoá quán. Máy chủ đã chặn dữ liệu của quán; màn này chỉ để
/// người dùng hiểu chuyện gì xảy ra, thử lại sau khi được mở khoá, hoặc đăng xuất / đổi quán.
class StoreLockedView extends StatelessWidget {
  final String storeName;
  final String? contact;
  final VoidCallback onRetry;
  final VoidCallback onLogout;

  const StoreLockedView({
    super.key,
    required this.storeName,
    required this.contact,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 56, color: Color(0xFFB3261E)),
                const SizedBox(height: 16),
                const Text(
                  'Quán đang tạm khoá',
                  key: Key('store_locked_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  '"$storeName" đang tạm ngưng sử dụng. ${contact ?? kStorePlanDefaultContact.replaceFirst('gia hạn', 'mở lại')}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF5F5A55)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Kiểm tra lại'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Đăng xuất / đổi quán'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
