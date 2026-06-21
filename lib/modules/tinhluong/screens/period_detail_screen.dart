import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../providers/tinhluong_providers.dart';
import '../repository/tinhluong_repository.dart';
import 'record_detail_screen.dart';
import 'staff_salary_config_screen.dart'; // dùng StaffSalaryConfigRepo

// ignore_for_file: use_build_context_synchronously

final _fmt = NumberFormat('#,###', 'vi_VN');

// Đếm số khiếu nại chưa giải quyết của 1 record
final _disputeCountProvider = FutureProvider.autoDispose
    .family<int, String>((ref, recordId) async {
  final rows = await Supabase.instance.client
      .from('payroll_disputes')
      .select('id')
      .eq('record_id', recordId)
      .eq('status', 'open');   // schema: open | resolved | dismissed
  return (rows as List).length;
});
String _fmtMoney(double v) => '${_fmt.format(v.round())}đ';

class PeriodDetailScreen extends ConsumerWidget {
  final PayrollPeriodModel period;
  const PeriodDetailScreen({super.key, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(payrollRecordsProvider(period.id));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2151),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(period.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          Text('${period.fromDate} - ${period.toDate}',
              style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]),
        actions: [
          if (period.isDraft)
            TextButton.icon(
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
              label: const Text('Gửi duyệt', style: TextStyle(color: Colors.white)),
              onPressed: () => _submitForReview(context, ref),
            ),
          if (period.status == 'pending_review')
            TextButton.icon(
              icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 18),
              label: const Text('Duyệt', style: TextStyle(color: Colors.greenAccent)),
              onPressed: () => _approve(context, ref),
            ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Lỗi: $e')),
        data:    (records) => _buildBody(context, ref, records),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, List<PayrollRecordModel> records) {
    // ‼️ FIX: Tính tổng LIVE từ records đang hiển thị thay vì period.totalAmount stale trong DB
    // period.totalAmount chỉ đúng lúc generate — nếu sau đó thêm/sửa payroll_items,
    // netPay từng NV thay đổi nhưng period.totalAmount trong DB không được cập nhật
    final liveTotal = records.fold(0.0, (s, r) => s + r.netPay);

    // ‼️ AUTO-HEAL: Nếu liveTotal khác DB total_amount (>1đ sai lệch) → sync lại DB
    // Xử lý data cũ trước khi deploy fix _recalcNetPay đồng bộ period total
    if ((liveTotal - period.totalAmount).abs() > 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await TinhLuongRepository.updatePeriodTotal(period.id, liveTotal);
        ref.invalidate(payrollPeriodsProvider); // refresh list card
      });
    }
    return Column(children: [
      // Summary header
      Container(
        width: double.infinity,
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tổng chi lương', style: TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 4),
            Text(_fmtMoney(liveTotal),
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.w800, fontSize: 24)),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${records.length} nhân viên',
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 6),
            _StatusBadge(status: period.status),
          ]),
        ]),
      ),

      // Records list
      Expanded(
        child: records.isEmpty
            ? _emptyView(context, ref)
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: records.length,
                itemBuilder: (ctx, i) => _RecordCard(
                  record:  records[i],
                  period:  period,
                  onTap:   () => Navigator.push(ctx,
                      MaterialPageRoute(
                          builder: (_) => RecordDetailScreen(record: records[i], period: period)))
                      .then((_) => ref.invalidate(payrollRecordsProvider(period.id))),
                  onPay:   period.isApproved ? () => _markPaid(ctx, ref, records[i]) : null,
                ),
              ),
      ),
    ]);
  }

  Widget _emptyView(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.people_outline, size: 72, color: Colors.grey[300]),
        const SizedBox(height: 16),
        Text('Chưa có dữ liệu lương',
            style: TextStyle(color: Colors.grey[500], fontSize: 16)),
        const SizedBox(height: 8),
        Text('Bấm "Tạo bảng lương" để tổng hợp từ dữ liệu chấm công',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (period.isDraft)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C2151),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.auto_awesome, color: Colors.white),
            label: const Text('Tạo bảng lương', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: () => _showGenerateSheet(context, ref),
          ),
      ]),
    );
  }

  Future<void> _showGenerateSheet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GenerateSheet(period: period, onGenerated: () {
        ref.invalidate(payrollRecordsProvider(period.id));
        ref.invalidate(payrollPeriodsProvider);
      }),
    );
  }

  Future<void> _submitForReview(BuildContext context, WidgetRef ref) async {
    await TinhLuongRepository.updatePeriodStatus(period.id, 'pending_review');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã gửi duyệt ✅')));
      Navigator.pop(context);
    }
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    await TinhLuongRepository.updatePeriodStatus(period.id, 'approved');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã duyệt ✅')));
      Navigator.pop(context);
    }
  }

  Future<void> _markPaid(BuildContext context, WidgetRef ref, PayrollRecordModel record) async {
    // ‼️ FIX: dùng bottom sheet thay SimpleDialog — tránh Navigator context bug
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PaymentMethodSheet(staffName: record.staffName),
    );
    if (method == null) return;
    await TinhLuongRepository.markRecordPaid(id: record.id, paymentMethod: method);

    // Kiểm tra nếu tất cả đã trả → chốt period
    final all = await TinhLuongRepository.fetchRecords(period.id);
    final allPaid = all.every((r) => r.paymentStatus == 'paid');
    if (allPaid) {
      await TinhLuongRepository.updatePeriodStatus(period.id, 'paid');
      // ‼️ FIX BUG #2: dùng tổng fresh từ DB, không dùng period.totalAmount (stale)
      final freshTotal = all.fold(0.0, (s, r) => s + r.netPay);
      await TinhLuongRepository.recordPayrollExpense(
        periodId:    period.id,
        periodName:  period.name,
        totalAmount: freshTotal,
      );
    }
    if (context.mounted) {
      ref.invalidate(payrollRecordsProvider(period.id));
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã trả lương ${record.staffName} ✅')));
    }
  }

}

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color bg, Color fg) = switch (status) {
      'paid'           => (Icons.check_circle_rounded,   'Đã trả',     const Color(0xFF1B5E20), const Color(0xFF69F0AE)),
      'approved'       => (Icons.verified_rounded,       'Đã duyệt',   const Color(0xFF0D47A1), const Color(0xFF82B1FF)),
      'pending_review' => (Icons.hourglass_top_rounded,  'Chờ duyệt',  const Color(0xFF4A2800), const Color(0xFFFFCC02)),
      _                => (Icons.edit_note_rounded,      'Nháp',       Colors.white24,           Colors.white70),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: fg, size: 13),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 12)),
      ]),
    );
  }
}

// ─── Payment Method Sheet ─────────────────────────────────────────────────────

class _PaymentMethodSheet extends StatelessWidget {
  final String staffName;
  const _PaymentMethodSheet({required this.staffName});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0D8CC),
              borderRadius: BorderRadius.circular(2)),
          )),
          const SizedBox(height: 20),

          // Header
          Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.payments_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Trả lương',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1C2151))),
              Text(staffName,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF9E9085))),
            ]),
          ]),
          const SizedBox(height: 20),

          // Options
          _PayOption(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Tiền mặt',
            subtitle: 'Thanh toán trực tiếp',
            color: const Color(0xFF2E7D32),
            onTap: () => Navigator.pop(context, 'cash'),
          ),
          const SizedBox(height: 10),
          _PayOption(
            icon: Icons.account_balance_rounded,
            label: 'Chuyển khoản',
            subtitle: 'Internet banking / ATM',
            color: const Color(0xFF1565C0),
            onTap: () => Navigator.pop(context, 'transfer'),
          ),
          const SizedBox(height: 10),
          _PayOption(
            icon: Icons.phone_iphone_rounded,
            label: 'MoMo',
            subtitle: 'Ví điện tử MoMo',
            color: const Color(0xFFAD1457),
            onTap: () => Navigator.pop(context, 'momo'),
          ),
        ],
      ),
    );
  }
}

class _PayOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  const _PayOption({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: color)),
              Text(subtitle, style: const TextStyle(
                  fontSize: 12, color: Color(0xFF9E9085))),
            ])),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color.withValues(alpha: 0.5)),
          ]),
        ),
      ),
    );
  }
}

// ─── Record Card ─────────────────────────────────────────────────────────────

class _RecordCard extends ConsumerWidget {
  final PayrollRecordModel record;
  final PayrollPeriodModel period;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  const _RecordCard({
    required this.record,
    required this.period,
    required this.onTap,
    this.onPay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaid       = record.paymentStatus == 'paid';
    final disputeAsync = ref.watch(_disputeCountProvider(record.id));
    final disputes     = disputeAsync.value ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            // Avatar + badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(0xFF1C2151).withValues(alpha: 0.1),
                  child: Text(
                    record.staffName.isNotEmpty ? record.staffName[0].toUpperCase() : '?',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1C2151)),
                  ),
                ),
                if (disputes > 0)
                  Positioned(
                    top: -4, right: -4,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(child: Text('$disputes',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 10, fontWeight: FontWeight.w800))),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(record.staffName,
                    style: const TextStyle(fontWeight: FontWeight.w700,
                        fontSize: 15, color: Color(0xFF1C2151)))),
                if (disputes > 0) ...[ const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text('🚨 $disputes khiếu nại',
                        style: TextStyle(color: Colors.red.shade700,
                            fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
              const SizedBox(height: 2),
              Text('${_modeLabel(record.salaryMode)} · ${record.totalHours.toStringAsFixed(1)}h '
                   '· Trễ ${record.lateCount} lần',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_fmtMoney(record.netPay),
                  style: const TextStyle(color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 4),
              if (isPaid)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text('Đã trả',
                      style: TextStyle(color: Colors.green, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                )
              else if (onPay != null)
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onPay,
                    child: const Text('Trả', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                ),
            ]),
          ]),
        ),
      ),
    );
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'M1': return 'Theo giờ';
      case 'M2': return 'Cố định';
      case 'M3': return 'Cố định+OT';
      case 'M4': return 'Theo ngày';

      default:   return m;
    }
  }
}

// ─── Generate Sheet ───────────────────────────────────────────────────────────

class _GenerateSheet extends StatefulWidget {
  final PayrollPeriodModel period;
  final VoidCallback onGenerated;
  const _GenerateSheet({required this.period, required this.onGenerated});

  @override
  State<_GenerateSheet> createState() => _GenerateSheetState();
}

class _GenerateSheetState extends State<_GenerateSheet> {
  bool _loading = false;
  String _msg   = '';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        const Icon(Icons.auto_awesome, size: 48, color: Color(0xFF1C2151)),
        const SizedBox(height: 12),
        const Text('Tổng hợp bảng lương',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1C2151))),
        const SizedBox(height: 8),
        Text('Tự động đọc dữ liệu chấm công kỳ\n${widget.period.fromDate} → ${widget.period.toDate}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '✅ Hệ thống sẽ đọc cấu hình lương đã thiết lập (Cài đặt → ⚙️) cho từng NV.\n\nNV chưa có cấu hình sẽ mặc định M1 - 25,000đ/giờ.\n\nSau khi tạo, vào từng phiếu để điều chỉnh bonus, khấu trừ.',
            style: TextStyle(fontSize: 12, color: Colors.teal),
            textAlign: TextAlign.center,
          ),
        ),
        if (_msg.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_msg, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C2151),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.calculate_outlined, color: Colors.white),
            label: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Tạo bảng lương', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            onPressed: _loading ? null : _generate,
          ),
        ),
      ]),
    );
  }

  Future<void> _generate() async {
    setState(() { _loading = true; _msg = ''; });

    // Lấy danh sách NV có chấm công trong kỳ
    final from = DateTime.parse(widget.period.fromDate);
    final to   = DateTime.parse(widget.period.toDate).add(const Duration(days: 1));

    // Lấy storeId
    final info    = await StoreAuthService.getStoreInfo();
    final storeId = info['store_id'] as String?;
    if (storeId == null) {
      setState(() { _loading = false; _msg = 'Lỗi: chưa chọn quán'; });
      return;
    }

    final shifts = await TinhLuongRepository.aggregateShifts(
      storeId: storeId,
      from:    from,
      to:      to,
    );

    if (shifts.isEmpty) {
      setState(() {
        _loading = false;
        _msg = 'Không có dữ liệu chấm công trong kỳ này.';
      });
      return;
    }

    // Đọc cấu hình lương đã thiết lập, fallback về M1/25K nếu chưa có
    final savedConfigs = await StaffSalaryConfigRepo.fetchAll();
    final configByUser = { for (final c in savedConfigs) c.userId: c };

    final configs = <String, StaffPayConfig>{};
    for (final entry in shifts.entries) {
      final saved = configByUser[entry.key];
      final mode = saved?.salaryMode ?? 'M1';
      final effectiveBase = (mode == 'M4')
          ? (saved?.dailyRate  ?? 0)
          : (saved?.baseSalary ?? 0);
      configs[entry.key] = StaffPayConfig(
        staffName:          entry.value.staffName,
        role:               saved?.role,
        salaryMode:         mode,
        baseSalary:         effectiveBase,
        hourlyRate:         saved?.hourlyRate      ?? 25000,
        expectedDays:       saved?.expectedDays    ?? 26,
        bonusRevenue:       0,
        // ‼️ FIX Bug #26: truyền per-staff config — không dùng global default nữa
        deductionPerLate:   saved?.deductionPerLate   ?? 50000,
        otThresholdHours:   saved?.otThresholdHours   ?? 8.0,
        otMultiplier:       saved?.otMultiplier        ?? 1.5,
      );
    }

    final count = await TinhLuongRepository.generatePeriodRecords(
      periodId:  widget.period.id,
      fromDate:  widget.period.fromDate,
      toDate:    widget.period.toDate,
      staffConfigs: configs,
    );

    setState(() {
      _loading = false;
      _msg = 'Đã tạo $count phiếu lương ✅';
    });

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      widget.onGenerated();
      Navigator.pop(context);
    }
  }
}

