import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/services/user_auth_service.dart';
import '../repository/tinhluong_repository.dart';
import 'dispute_sheet.dart';

final _fmt = NumberFormat('#,###', 'vi_VN');
String _fmtMoney(double v) => '${_fmt.format(v.round())}đ';

// ─── Provider chính ───────────────────────────────────────────────────────────

final myPayslipsProvider = FutureProvider<List<_MyPayslipEntry>>((ref) async {
  final db = Supabase.instance.client;
  final info = await StoreAuthService.getStoreInfo();
  final session = await UserAuthService.getCurrentSession();
  final storeId = info['store_id'];
  final userId = session?.userId;
  if (storeId == null || userId == null) return [];

  try {
    final rows = await db
        .from('payroll_records')
        .select('*, payroll_periods!inner(name, from_date, to_date, status)')
        .eq('store_id', storeId)
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    if (rows.isNotEmpty) {
      return rows
          .where((r) {
            final p = r['payroll_periods'] as Map<String, dynamic>;
            final st = p['status'];
            return st == 'pending_review' || st == 'approved' || st == 'paid';
          })
          .map<_MyPayslipEntry>((r) {
            final p = r['payroll_periods'] as Map<String, dynamic>;
            return _MyPayslipEntry(
              record: PayrollRecordModel.fromMap(r),
              periodName: p['name'] as String,
              periodFrom: p['from_date'] as String,
              periodTo: p['to_date'] as String,
              periodStatus: p['status'] as String,
            );
          })
          .toList();
    }
  } catch (e) {
    debugPrint('[myPayslipsProvider] payroll_records error: $e');
    throw 'Không thể tải danh sách phiếu lương. Vui lòng thử lại.';
  }

  return [];
});

final staffRealtimeMonthlyEarningsProvider =
    FutureProvider<RealtimeMonthlyEarnings?>((ref) async {
      final info = await StoreAuthService.getStoreInfo();
      final session = await UserAuthService.getCurrentSession();
      final storeId = info['store_id'];
      final userId = session?.userId;
      if (storeId == null || userId == null) return null;

      return TinhLuongRepository.fetchRealtimeMonthlyEarnings(
        storeId: storeId,
        userId: userId,
        monthYear: DateTime.now(),
      );
    });

// Provider lấy disputes (khiếu nại) của 1 record
final _myDisputesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, recordId) async {
      final rows = await Supabase.instance.client
          .from('payroll_disputes')
          .select()
          .eq('record_id', recordId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    });

class _MyPayslipEntry {
  final PayrollRecordModel record;
  final String periodName;
  final String periodFrom;
  final String periodTo;
  final String periodStatus;
  const _MyPayslipEntry({
    required this.record,
    required this.periodName,
    required this.periodFrom,
    required this.periodTo,
    required this.periodStatus,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyPayslipScreen extends ConsumerWidget {
  const MyPayslipScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myPayslipsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: RefreshIndicator(
        color: const Color(0xFF1C2151),
        onRefresh: () async {
          ref.invalidate(myPayslipsProvider);
          ref.invalidate(staffRealtimeMonthlyEarningsProvider);
        },
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  backgroundColor: const Color(0xFF1C2151),
                  actions: [
                    IconButton(
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                      ),
                      tooltip: 'Làm mới',
                      onPressed: () {
                        ref.invalidate(myPayslipsProvider);
                        ref.invalidate(staffRealtimeMonthlyEarningsProvider);
                      },
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                    title: const Text(
                      'Lương của tôi',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _StaffRealtimeEarningsHeaderCard(),
                  ),
                ),
                SliverToBoxAdapter(child: _StaffRealtimeShiftsList()),
                async.when(
                  loading: () => const SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
                  error: (e, _) => SliverToBoxAdapter(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              'Lỗi tải phiếu lương',
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () =>
                                    ref.invalidate(myPayslipsProvider),
                                child: const Text('Thử lại'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'Chưa có kỳ lương nào sẵn sàng',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _MyPayslipCard(
                            entry: entries[i],
                            onDisputed: () {
                              ref.invalidate(myPayslipsProvider);
                              ref.invalidate(
                                _myDisputesProvider(entries[i].record.id),
                              );
                            },
                          ),
                          childCount: entries.length,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ), // CustomScrollView
          ),
        ),
      ), // RefreshIndicator
    );
  }
}

// ─── Card ─────────────────────────────────────────────────────────────────────

class _MyPayslipCard extends ConsumerStatefulWidget {
  final _MyPayslipEntry entry;
  final VoidCallback onDisputed;
  const _MyPayslipCard({required this.entry, required this.onDisputed});

  @override
  ConsumerState<_MyPayslipCard> createState() => _MyPayslipCardState();
}

class _MyPayslipCardState extends ConsumerState<_MyPayslipCard> {
  bool _isConfirming = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final record = entry.record;
    final isPaid = record.paymentStatus == 'paid';
    final disputesAsync = ref.watch(_myDisputesProvider(record.id));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetail(context),
        child: Column(
          children: [
            // Header gradient
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.periodName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.periodFrom} → ${entry.periodTo}',
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusChip(status: record.paymentStatus),
                ],
              ),
            ),
            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Stats row
                  Row(
                    children: [
                      _StatItem(
                        Icons.schedule_rounded,
                        'Tổng giờ',
                        '${record.totalHours.toStringAsFixed(1)}h',
                        const Color(0xFF1565C0),
                      ),
                      _StatItem(
                        Icons.trending_up_rounded,
                        'Tăng ca',
                        '${record.overtimeHours.toStringAsFixed(1)}h',
                        const Color(0xFF6A1B9A),
                      ),
                      _StatItem(
                        Icons.event_busy_rounded,
                        'Nghỉ',
                        '${record.absentDays}ngày',
                        const Color(0xFFC62828),
                      ),
                      _StatItem(
                        Icons.alarm_rounded,
                        'Muộn',
                        '${record.lateCount}lần',
                        const Color(0xFFE65100),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  // Net Pay
                  Row(
                    children: [
                      const Text(
                        'Thực lĩnh',
                        style: TextStyle(
                          color: Color(0xFF9E9085),
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _fmtMoney(record.netPay),
                        style: const TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                  if (record.paymentStatus == 'pending_staff_confirm') ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade300),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.payments_rounded,
                                color: Colors.amber.shade900,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Quản lý đã chuyển ${_fmtMoney(record.netPay)} qua ${record.paymentMethod ?? "tiền mặt/chuyển khoản"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: _isConfirming
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.verified_user_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                              label: Text(
                                _isConfirming
                                    ? 'ĐANG XỬ LÝ...'
                                    : '✅ XÁC NHẬN ĐÃ NHẬN ĐỦ LƯƠNG',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              onPressed: _isConfirming
                                  ? null
                                  : () async {
                                      setState(() => _isConfirming = true);
                                      try {
                                        await TinhLuongRepository.confirmStaffPaid(
                                          id: record.id,
                                          staffName: record.staffName,
                                        );
                                        ref.invalidate(myPayslipsProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '✅ Đã xác nhận thành công',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                '❌ Có lỗi xảy ra, vui lòng thử lại',
                                              ),
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isConfirming = false);
                                        }
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (!isPaid &&
                      record.paymentStatus != 'pending_staff_confirm') ...[
                    const SizedBox(height: 12),
                    disputesAsync.when(
                      loading: () => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Đang kiểm tra phản hồi...',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      error: (e, _) => Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Lỗi tải phản hồi/khiếu nại',
                              style: TextStyle(color: Colors.red, fontSize: 12),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => ref.invalidate(
                                  _myDisputesProvider(record.id),
                                ),
                                child: const Text('Thử lại'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      data: (disputes) {
                        final hasOpenDispute = disputes.any(
                          (d) => d['status'] == 'open',
                        );
                        final hasAnyDispute = disputes.isNotEmpty;

                        if (hasOpenDispute) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.orange.shade200),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 15,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Đang chờ quản lý phản hồi',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          );
                        } else {
                          return SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFC62828),
                                side: const BorderSide(
                                  color: Color(0xFFC62828),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.flag_rounded, size: 16),
                              label: Text(
                                hasAnyDispute
                                    ? 'Gửi khiếu nại mới'
                                    : 'Phản hồi / Khiếu nại',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              onPressed: () => _showDispute(context),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PayslipDetailSheet(entry: widget.entry),
    );
  }

  void _showDispute(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DisputeSheet(
        record: widget.entry.record,
        onSubmitted: widget.onDisputed,
      ),
    );
  }
}

// ─── Detail Sheet (read-only) ─────────────────────────────────────────────────

class _PayslipDetailSheet extends ConsumerWidget {
  final _MyPayslipEntry entry;
  const _PayslipDetailSheet({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = entry.record;
    final disputeAsync = ref.watch(_myDisputesProvider(r.id));

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8CC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              entry.periodName,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: Color(0xFF1C2151),
              ),
            ),
            Text(
              '${entry.periodFrom} → ${entry.periodTo}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF9E9085)),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Net highlight
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'Thực lĩnh',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          _fmtMoney(r.netPay),
                          style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Salary breakdown
                  _detailSection('Chi tiết khoản lương', [
                    _detailRow('Lương cơ bản', r.regularPay, true),
                    if (r.overtimePay > 0)
                      _detailRow('Tăng ca', r.overtimePay, true),
                    if (r.bonusRevenue > 0)
                      _detailRow('Thưởng doanh thu', r.bonusRevenue, true),
                    if (r.bonusManual > 0)
                      _detailRow('Thưởng thủ công', r.bonusManual, true),
                    if (r.allowanceTotal > 0)
                      _detailRow('Phụ cấp', r.allowanceTotal, true),
                    if (r.deductionLate > 0)
                      _detailRow('Đi muộn', -r.deductionLate, false),
                    if (r.deductionAbsent > 0)
                      _detailRow('Nghỉ không phép', -r.deductionAbsent, false),
                    if (r.deductionManual > 0)
                      _detailRow('Khấu trừ khác', -r.deductionManual, false),
                    const Divider(),
                    _detailRow(
                      'Tổng thu nhập',
                      r.regularPay +
                          r.overtimePay +
                          r.bonusRevenue +
                          r.bonusManual +
                          r.allowanceTotal,
                      true,
                      isBold: true,
                    ),
                    _detailRow(
                      'Tổng khấu trừ',
                      -(r.deductionLate +
                          r.deductionAbsent +
                          r.deductionManual),
                      false,
                      isBold: true,
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Attendance
                  _detailSection('Chấm công', [
                    _infoRow(
                      'Tổng giờ làm',
                      '${r.totalHours.toStringAsFixed(1)}h',
                    ),
                    _infoRow(
                      'Tăng ca',
                      '${r.overtimeHours.toStringAsFixed(1)}h',
                    ),
                    _infoRow('Nghỉ không phép', '${r.absentDays} ngày'),
                    _infoRow('Đi muộn', '${r.lateCount} lần'),
                  ]),

                  if (r.note != null && r.note!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.note!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ――― Phản hồi / Khiếu nại ―――
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.forum_rounded,
                        size: 16,
                        color: Color(0xFF1C2151),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Phản hồi của tôi',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Color(0xFF1C2151),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  disputeAsync.when(
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (e, _) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            const Text(
                              'Lỗi tải phản hồi/khiếu nại',
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              height: 44,
                              child: OutlinedButton(
                                onPressed: () =>
                                    ref.invalidate(_myDisputesProvider(r.id)),
                                child: const Text('Thử lại'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    data: (disputes) {
                      if (disputes.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inbox_rounded,
                                size: 20,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Chưa có khiếu nại nào',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return Column(
                        children: disputes
                            .map((d) => _DisputeReplyCard(d))
                            .toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailSection(String title, List<Widget> rows) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: Color(0xFF1C2151),
        ),
      ),
      const SizedBox(height: 8),
      ...rows,
    ],
  );

  Widget _detailRow(
    String label,
    double amount,
    bool isPos, {
    bool isBold = false,
  }) {
    final c = isPos ? Colors.green[700]! : Colors.red[700]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            '${isPos ? '+' : ''}${_fmtMoney(amount)}',
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w700,
              fontSize: isBold ? 15 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9E9085)),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

// ─── Dispute Reply Card (staff view) ─────────────────────────────────────────

class _DisputeReplyCard extends StatelessWidget {
  final Map<String, dynamic> dispute;
  const _DisputeReplyCard(this.dispute);

  @override
  Widget build(BuildContext context) {
    final status = dispute['status'] as String? ?? 'open';
    final field = dispute['field'] as String? ?? 'other';
    final message = dispute['message'] as String? ?? '';
    final reply = dispute['reply'] as String?;
    final createdAt = _fmtDate(dispute['created_at'] as String? ?? '');

    final (Color statusColor, String statusLabel) = switch (status) {
      'resolved' => (Colors.green, 'Đã xử lý'),
      'dismissed' => (Colors.grey, 'Không giải quyết'),
      _ => (Colors.orange, 'Chờ phản hồi'),
    };

    final fieldLabel = switch (field) {
      'total_hours' => 'Giờ làm sai',
      'overtime' => 'Tăng ca sai',
      'deduction' => 'Khấu trừ sai',
      _ => 'Vấn đề khác',
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  fieldLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                createdAt,
                style: const TextStyle(color: Color(0xFF9E9085), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // My message
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.person_outline_rounded,
                size: 14,
                color: Color(0xFF9E9085),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
              ),
            ],
          ),

          // Manager reply
          if (reply != null && reply.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.support_agent_rounded,
                    size: 16,
                    color: Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Phản hồi của quản lý',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reply,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1C2151),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (status == 'open') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 13,
                  color: Colors.orange[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'Quản lý chưa phản hồi',
                  style: TextStyle(
                    color: Colors.orange[600],
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (status) {
      'paid' => (Icons.check_circle_rounded, 'Đã trả', const Color(0xFF69F0AE)),
      'hold' => (
        Icons.pause_circle_rounded,
        'Tạm giữ',
        const Color(0xFFFFD740),
      ),
      _ => (Icons.hourglass_top_rounded, 'Chờ trả', const Color(0xFFFFCC80)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatItem(this.icon, this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF9E9085), fontSize: 9),
        ),
      ],
    ),
  );
}

// ─── THẺ THU NHẬP DỰ KIẾN THỜI GIAN THỰC CHO NHÂN VIÊN ─────────────────────────

class _StaffRealtimeEarningsHeaderCard extends ConsumerWidget {
  const _StaffRealtimeEarningsHeaderCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtimeAsync = ref.watch(staffRealtimeMonthlyEarningsProvider);
    final now = DateTime.now();

    return realtimeAsync.when(
      loading: () => Container(
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Lỗi tải lương dự kiến',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(staffRealtimeMonthlyEarningsProvider),
                  child: const Text('Thử lại'),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (earnings) {
        if (earnings == null) {
          return Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Chưa có dữ liệu lương dự kiến',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        final totalMoneyStr = _fmtMoney(earnings.totalEarnings);
        final hoursStr = '${earnings.totalHours.toStringAsFixed(1)}h';
        final otStr = _fmtMoney(earnings.totalBonus);
        final penaltyStr = _fmtMoney(earnings.totalDeductions);

        return Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF312E81).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TÍNH THEO THỜI GIAN THỰC • THÁNG ${now.month}/${now.year}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Text(
                    '${earnings.shiftCount} ca hoàn thành',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'LƯƠNG DỰ KIẾN NHẬN ĐƯỢC',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    totalMoneyStr,
                    style: const TextStyle(
                      color: Color(0xFF4ADE80),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '(tự động cộng dồn ca)',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statSubItem(
                    Icons.access_time_rounded,
                    const Color(0xFF60A5FA),
                    'TỔNG GIỜ',
                    hoursStr,
                  ),
                  _statSubItem(
                    Icons.stars_rounded,
                    const Color(0xFFFACC15),
                    'THƯỞNG OT',
                    '+$otStr',
                  ),
                  _statSubItem(
                    Icons.remove_circle_outline_rounded,
                    const Color(0xFFF87171),
                    'KHẤU TRỪ',
                    '-$penaltyStr',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statSubItem(IconData icon, Color color, String label, String value) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ─── DANH SÁCH LỊCH SỬ CÁC CA LÀM VIỆC & TIỀN LƯƠNG TRONG THÁNG ────────────────

class _StaffRealtimeShiftsList extends ConsumerWidget {
  const _StaffRealtimeShiftsList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffRealtimeMonthlyEarningsProvider);

    return async.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Text(
                'Lỗi tải ca làm việc',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(staffRealtimeMonthlyEarningsProvider),
                  child: const Text('Thử lại'),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (earnings) {
        if (earnings == null || earnings.shifts.isEmpty) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Chưa có ca làm việc nào hoàn thành trong tháng này',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'LỊCH SỬ LÀM VIỆC & THU NHẬP CA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C2151),
                        letterSpacing: 0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C2151).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${earnings.shifts.length} ca',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1C2151),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: earnings.shifts.length,
                separatorBuilder: (ctx, idx) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (ctx, idx) {
                  final shift = earnings.shifts[idx];
                  final calc = TinhLuongRepository.calculateSingleShiftEarnings(
                    shift: shift,
                  );
                  final dateStr = DateFormat(
                    'dd/MM',
                  ).format(shift.clockIn.toLocal());
                  final inTime = DateFormat(
                    'HH:mm',
                  ).format(shift.clockIn.toLocal());
                  final outTime = shift.clockOut != null
                      ? DateFormat('HH:mm').format(shift.clockOut!.toLocal())
                      : '--:--';

                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF1C2151,
                                ).withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                dateStr,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: Color(0xFF1C2151),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$inTime → $outTime (${calc.totalHours.toStringAsFixed(1)}h)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              _fmtMoney(calc.netPay),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        if (calc.bonusReasons.isNotEmpty ||
                            calc.penaltyReasons.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...calc.bonusReasons.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                r,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF16A34A),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          ...calc.penaltyReasons.map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                r,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
