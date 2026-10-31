import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/dashboard_providers.dart';
import '../core/repositories/dashboard_repository.dart';
import '../core/repositories/einvoice_repository.dart';
import '../core/utils/money_formatter.dart';
import 'bill_lookup_section.dart';

const _kNavy = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kGreen = Color(0xFF2E7D32);
const _kRed = Color(0xFFC62828);
const _kMuted = Color(0xFF9E9085);

/// Chủ Quán 29/10: chưa tích hợp hóa đơn điện tử (migration chưa áp) → tab chỉ còn
/// "Tra cứu & in lại bill". Bật lại khi đã áp `20261016_einvoice_foundation_v1.sql`.
const _kEinvoiceVisible = false;

enum _Period { today, week, month }

extension on _Period {
  String get label => switch (this) {
    _Period.today => 'Hôm nay',
    _Period.week => 'Tuần này',
    _Period.month => 'Tháng này',
  };

  /// [from, to) theo epoch millis, cùng quy ước với ReportPeriod.rangeFor.
  (int, int) range() {
    final now = DateTime.now();
    switch (this) {
      case _Period.today:
        final s = DateTime(now.year, now.month, now.day);
        return (
          s.millisecondsSinceEpoch,
          DateTime(now.year, now.month, now.day + 1).millisecondsSinceEpoch,
        );
      case _Period.week:
        final m = now.subtract(Duration(days: now.weekday - 1));
        final s = DateTime(m.year, m.month, m.day);
        return (
          s.millisecondsSinceEpoch,
          DateTime(s.year, s.month, s.day + 7).millisecondsSinceEpoch,
        );
      case _Period.month:
        return (
          DateTime(now.year, now.month, 1).millisecondsSinceEpoch,
          DateTime(now.year, now.month + 1, 1).millisecondsSinceEpoch,
        );
    }
  }
}

/// Tab "Hóa đơn": tra cứu + in lại bill đã thanh toán ([BillLookupSection]), rồi báo cáo
/// hóa đơn điện tử (đã xuất, đối chiếu doanh thu, chờ/lỗi). Phần điện tử chỉ hiển thị.
class EinvoiceReportTab extends ConsumerStatefulWidget {
  const EinvoiceReportTab({super.key});

  @override
  ConsumerState<EinvoiceReportTab> createState() => _EinvoiceReportTabState();
}

class _EinvoiceReportTabState extends ConsumerState<EinvoiceReportTab> {
  final _repo = EinvoiceRepository();
  _Period _period = _Period.today;
  EinvoiceReport _report = EinvoiceReport.empty;
  List<EinvoiceProblemDoc> _problems = const [];
  double _revenue = 0;
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  int _refreshToken = 0;

  Future<void> _refreshAll() async {
    setState(() => _refreshToken++);
    await _load();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!_kEinvoiceVisible) return;
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final (from, to) = _period.range();
      final results = await Future.wait([
        _repo.getReport(from, to),
        _repo.getProblemDocs(from, to),
        ref.read(dashboardRepositoryProvider).getStatsForRange(from, to),
      ]);
      if (!mounted || id != _requestId) return;
      setState(() {
        _report = results[0] as EinvoiceReport;
        _problems = results[1] as List<EinvoiceProblemDoc>;
        _revenue = (results[2] as DashboardStats).todayRevenue;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _error =
            'Chưa tải được báo cáo hóa đơn. Có thể máy chủ chưa được cập nhật.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final (from, to) = _period.range();
    return RefreshIndicator(
        onRefresh: _refreshAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _periodPills(),
          const SizedBox(height: 12),
          BillLookupSection(
              fromMs: from, toMs: to, refreshToken: _refreshToken),
          if (_kEinvoiceVisible) ...[
          const SizedBox(height: 16),
          const Text('Hóa đơn điện tử',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          _statusBanner(),
          const SizedBox(height: 12),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            _card(
              child: Text(
                _error!,
                style: const TextStyle(color: _kRed, fontSize: 13),
              ),
            )
          else ...[
            _heroCard(),
            const SizedBox(height: 12),
            _reconcileCard(),
            const SizedBox(height: 12),
            _statusRows(),
            if (_problems.isNotEmpty) ...[
              const SizedBox(height: 12),
              _problemList(),
            ],
          ],
          const SizedBox(height: 16),
          const Text(
            'Số liệu để đối chiếu và hỗ trợ kê khai. Việc kê khai thuế và độ chính xác cuối cùng thuộc chủ hộ hoặc kế toán.',
            style: TextStyle(fontSize: 11, color: _kMuted, height: 1.4),
          ),
          ],
        ],
      ),
    );
  }

  Widget _periodPills() => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: _kNavy.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: _Period.values
          .map(
            (p) => Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_period == p) return;
                  setState(() => _period = p);
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _period == p ? _kNavy : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    p.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _period == p ? Colors.white : _kMuted,
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _statusBanner() {
    final on = _report.enabled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (on ? _kGreen : _kMuted).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            on ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
            size: 18,
            color: on ? _kGreen : _kMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              on
                  ? 'Hóa đơn điện tử đang bật. Phát hành tự động qua nhà cung cấp đang được triển khai nên số liệu có thể là 0.'
                  : 'Hóa đơn điện tử đang tắt. Chủ quán bật trong Cài đặt. Bill vẫn được ghi đầy đủ vào doanh thu.',
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE0D8CC)),
    ),
    child: child,
  );

  Widget _heroCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Đã xuất hóa đơn điện tử',
          style: TextStyle(fontSize: 12, color: _kMuted),
        ),
        const SizedBox(height: 4),
        Text(
          fmtVnd(_report.issuedAmount),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: _kNavy,
          ),
        ),
        Text(
          '${_report.issuedCount} hóa đơn',
          style: const TextStyle(fontSize: 12, color: _kMuted),
        ),
      ],
    ),
  );

  Widget _reconcileCard() => _card(
    child: Column(
      children: [
        _row('Doanh thu bill cùng kỳ', fmtVnd(_revenue)),
        const Divider(height: 18),
        _row('Đã xuất hóa đơn', fmtVnd(_report.issuedAmount), color: _kGreen),
        const Divider(height: 18),
        _row(
          'Chưa có hóa đơn',
          fmtVnd(_report.uninvoicedFrom(_revenue)),
          color: _kOrange,
          bold: true,
        ),
      ],
    ),
  );

  Widget _statusRows() => _card(
    child: Column(
      children: [
        _row(
          'Chờ xử lý (${_report.pendingCount})',
          fmtVnd(_report.pendingAmount),
        ),
        const Divider(height: 18),
        _row(
          'Lỗi / bị từ chối (${_report.problemCount})',
          fmtVnd(_report.problemAmount),
          color: _report.problemCount > 0 ? _kRed : null,
        ),
        const Divider(height: 18),
        _row(
          'Đã hủy (${_report.cancelledCount})',
          fmtVnd(_report.cancelledAmount),
        ),
      ],
    ),
  );

  Widget _problemList() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Hóa đơn cần xử lý',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final d in _problems)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${d.invoiceDate.day.toString().padLeft(2, '0')}/${d.invoiceDate.month.toString().padLeft(2, '0')} · ${d.status == 'rejected' ? 'Bị từ chối cấp mã' : 'Lỗi'}${d.errorCode != null ? ' (${d.errorCode})' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Text(
                  fmtVnd(d.totalAmount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _row(String label, String value, {Color? color, bool bold = false}) =>
      Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
              color: color ?? _kNavy,
            ),
          ),
        ],
      );
}
