import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/permission_provider.dart';
import '../core/repositories/bill_history_repository.dart';
import '../core/utils/app_logger.dart';
import '../core/utils/money_formatter.dart';
import '../core/widgets/order_detail_dialog.dart';
import '../modules/bill_printer/services/bill_reprint_service.dart';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kRed = Color(0xFFC62828);
const _kMuted = Color(0xFF9E9085);
const _kBorder = Color(0xFFE0D8CC);

const _kPageSize = 30;

/// Quyền dùng để in lại bill cũ (thu ngân, quản lý, chủ quán mặc định có).
const kReprintAction = 'pos.view_history';

/// Tra cứu bill đã thanh toán trong kỳ [fromMs, toMs) và in lại.
/// Chạm dòng để xem chi tiết; nút máy in để in lại (có xác nhận + ghi log).
class BillLookupSection extends ConsumerStatefulWidget {
  final int fromMs;
  final int toMs;

  /// Tăng số này để buộc tải lại (kéo để làm mới ở tab cha).
  final int refreshToken;

  const BillLookupSection({
    super.key,
    required this.fromMs,
    required this.toMs,
    this.refreshToken = 0,
  });

  @override
  ConsumerState<BillLookupSection> createState() => _BillLookupSectionState();
}

class _BillLookupSectionState extends ConsumerState<BillLookupSection> {
  final _searchCtrl = TextEditingController();
  List<BillHistoryEntry> _bills = const [];
  bool _loading = true;
  String? _error;
  int _shown = _kPageSize;
  int _requestId = 0;
  final Set<String> _printing = {}; // đang in thật (hiện vòng quay)
  final Set<String> _busy =
      {}; // đang xử lý (hỏi quyền, hộp xác nhận, in) — chặn bấm 2 lần
  // Kết quả lọc nhớ theo (danh sách, ô tìm) — bấm in / vòng quay không lọc lại cả danh sách.
  List<BillHistoryEntry>? _filterSource;
  String? _filterQuery;
  List<BillHistoryEntry> _filtered = const [];

  List<BillHistoryEntry> _currentFiltered() {
    final q = _searchCtrl.text;
    if (!identical(_filterSource, _bills) || _filterQuery != q) {
      _filterSource = _bills;
      _filterQuery = q;
      _filtered = filterBills(_bills, q);
    }
    return _filtered;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant BillLookupSection old) {
    super.didUpdateWidget(old);
    if (old.fromMs != widget.fromMs ||
        old.toMs != widget.toMs ||
        old.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _shown = _kPageSize;
    });
    try {
      final bills = await ref
          .read(billHistoryRepositoryProvider)
          .listBills(widget.fromMs, widget.toMs);
      if (!mounted || id != _requestId) return;
      setState(() {
        _bills = bills;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error = 'Chưa tải được danh sách bill. Kéo xuống để tải lại.';
      });
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: error ? _kRed : null,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
  }

  Future<void> _reprint(BillHistoryEntry b) async {
    // Giữ chỗ ngay từ đầu: bấm nhanh 2 lần không mở 2 hộp / in 2 lần.
    if (!_busy.add(b.financeId)) return;
    try {
      await _reprintGuarded(b);
    } finally {
      _busy.remove(b.financeId);
    }
  }

  Future<void> _reprintGuarded(BillHistoryEntry b) async {
    // Chờ quyền tải xong (đọc ngay có thể còn loading); lỗi → chặn.
    final perms = await ref
        .read(userActionPermsProvider.future)
        .catchError((_) => <String>{});
    if (!mounted) return;
    if (!perms.contains(kReprintAction)) {
      _snack('Bạn không có quyền in lại bill', error: true);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('In lại bill?'),
        content: Text(
          '${b.description.isEmpty ? 'Bill' : b.description} · ${fmtVnd(b.amount)}\n\n'
          'Bill in ra có dòng "$kReprintMarker" và được ghi lại ai in, lúc nào.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('In lại'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _printing.add(b.financeId));
    try {
      final outcome = await ref.read(billReprintServiceProvider).reprint(b);
      if (!mounted) return;
      switch (outcome) {
        case ReprintOutcome.printed:
          _snack('Đã in lại bill');
        case ReprintOutcome.notConfigured:
          _snack(
            'Máy này chưa được cài máy in hóa đơn nên chưa in. '
            'Vào In Hoá Đơn → Máy In & Luật In để chọn máy in.',
            error: true,
          );
        case ReprintOutcome.failed:
          _snack('In lại thất bại. Kiểm tra máy in rồi thử lại.', error: true);
      }
    } catch (e, st) {
      AppLogger.error('bill_lookup', 'In lại bill lỗi: $e', e, st);
      if (mounted) {
        _snack(
          'Không đọc được chi tiết bill này. Kéo xuống để tải lại rồi thử lại.',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _printing.remove(b.financeId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _currentFiltered();
    final visible = filtered.take(_shown).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, size: 18, color: _kNavy),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Tra cứu & in lại bill',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              if (!_loading && _error == null)
                Text(
                  '${filtered.length} bill',
                  style: const TextStyle(fontSize: 12, color: _kMuted),
                ),
            ],
          ),
          if (!_loading && _error == null && _bills.length >= kBillLookupLimit)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Chỉ hiện $kBillLookupLimit bill mới nhất của kỳ — chọn kỳ ngắn hơn để tìm bill cũ hơn.',
                style: TextStyle(fontSize: 12, color: _kRed),
              ),
            ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() => _shown = _kPageSize),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Số đơn, tên bàn, số tiền',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () => setState(() {
                        _searchCtrl.clear();
                        _shown = _kPageSize;
                      }),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: _kRed, fontSize: 13),
              ),
            )
          else if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _bills.isEmpty
                    ? 'Chưa có bill nào trong kỳ này.'
                    : 'Không có bill khớp "${_searchCtrl.text.trim()}".',
                style: const TextStyle(fontSize: 13, color: _kMuted),
              ),
            )
          else ...[
            for (final b in visible) _row(b),
            if (filtered.length > visible.length)
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _shown += _kPageSize),
                  child: Text('Xem thêm (${filtered.length - visible.length})'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(BillHistoryEntry b) {
    final t = b.recordedAt;
    String two(int v) => v.toString().padLeft(2, '0');
    final time =
        '${two(t.hour)}:${two(t.minute)} · ${two(t.day)}/${two(t.month)}';
    final busy = _printing.contains(b.financeId);
    return InkWell(
      onTap: () => showOrderDetailDialog(
        context,
        b.orderNumber ?? b.referenceId,
        orderId: b.referenceId,
      ),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.description.isEmpty ? 'Bill' : b.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 11, color: _kMuted),
                  ),
                ],
              ),
            ),
            Text(
              fmtVnd(b.amount),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _kNavy,
              ),
            ),
            const SizedBox(width: 4),
            busy
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'In lại',
                    icon: const Icon(Icons.print_rounded, color: _kOrange),
                    onPressed: () => _reprint(b),
                  ),
          ],
        ),
      ),
    );
  }
}
