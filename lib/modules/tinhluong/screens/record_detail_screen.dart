// lib/modules/tinhluong/screens/record_detail_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/repositories/module_repository.dart';
import '../../../core/services/store_auth_service.dart';
import '../providers/tinhluong_providers.dart';
import '../repository/tinhluong_repository.dart';
import '../services/payslip_pdf_service.dart';
import 'tinhluong_screen.dart' show openDisputesCountProvider;

final _fmt = NumberFormat('#,###', 'vi_VN');
String _fmtMoney(double v) => '${_fmt.format(v.round())}đ';

// Provider lấy danh sách khiếu nại của 1 record
final payrollDisputesProvider = FutureProvider.family<List<Map<String,dynamic>>, String>((ref, recordId) async {
  final rows = await Supabase.instance.client
      .from('payroll_disputes')
      .select()
      .eq('record_id', recordId)
      .order('created_at', ascending: false);
  return List<Map<String,dynamic>>.from(rows);
});

class RecordDetailScreen extends ConsumerWidget {
  final PayrollRecordModel record;
  final PayrollPeriodModel period;
  const RecordDetailScreen({super.key, required this.record, required this.period});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(payrollItemsProvider(record.id));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2151),
        foregroundColor: Colors.white,
        title: Text(record.staffName,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Xuất PDF',
            onPressed: () => _showExportSheet(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Thêm khoản',
            onPressed: () => _showAddItemSheet(context, ref),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          // Phiếu lương header
          _PayslipCard(record: record, period: period),
          const SizedBox(height: 16),

          // Chi tiết các khoản
          _SectionHeader(title: 'Chi tiết khoản lương'),
          _DetailRow('Lương cơ bản (${_modeLabel(record.salaryMode)})', record.regularPay, color: Colors.green),
          if (record.overtimePay > 0)
            _DetailRow(
              'Tăng ca (${record.overtimeHours.toStringAsFixed(1)}h)',
              record.overtimePay, color: Colors.green),
          if (record.bonusRevenue > 0)
            _DetailRow('Thưởng doanh thu', record.bonusRevenue, color: Colors.green),
          if (record.bonusManual > 0)
            _DetailRow('Thưởng thủ công', record.bonusManual, color: Colors.green),
          // ‼️ FIX: Bỏ dòng allowanceTotal tổng hợp — items được hiển thị riêng
          // ở section "Khoản phát sinh thêm" bên dưới → tránh hiển thị trùng lặp
          if (record.deductionLate > 0)
            _DetailRow('Trừ đi muộn (${record.lateCount} lần)',
                -record.deductionLate, color: Colors.red),
          if (record.deductionAbsent > 0)
            _DetailRow('Trừ nghỉ (${record.absentDays} ngày)',
                -record.deductionAbsent, color: Colors.red),
          if (record.deductionManual > 0)
            _DetailRow('Khấu trừ khác', -record.deductionManual, color: Colors.red),

          const Divider(height: 24),
          _DetailRow('Tổng cộng (gross)', record.grossPay,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          _DetailRow('Thực lĩnh (net)', record.netPay,
              color: const Color(0xFFFF6B35),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),

          const SizedBox(height: 16),
          _SectionHeader(title: 'Khoản phát sinh thêm'),
          itemsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error:   (e, _) => Text('Lỗi: $e'),
            data:    (items) => items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text('Chưa có khoản phát sinh',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  )
                : Column(
                    children: items.map((item) => _ItemTile(item: item, onDelete: () async {
                      await TinhLuongRepository.deleteItem(item.id);
                      ref.invalidate(payrollItemsProvider(record.id));
                      // ‼️ FIX Bug #21: refresh records để cập nhật netPay
                      ref.invalidate(payrollRecordsProvider(record.periodId));
                    })).toList(),
                  ),
          ),

          // Chấm công tóm tắt
          const SizedBox(height: 16),
          _SectionHeader(title: 'Tóm tắt chấm công'),
          _ShiftSummaryGrid(
            record: record,
            periodFrom: period.fromDate,
            periodTo:   period.toDate,
          ),

          // Phản hồi nhân viên (manager view)
          const SizedBox(height: 16),
          _DisputeSection(recordId: record.id, ref: ref),

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  void _showExportSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ExportPdfSheet(record: record, period: period, ref: ref),
    );
  }

  void _showAddItemSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddItemSheet(
        recordId: record.id,
        onAdded: () {
          ref.invalidate(payrollItemsProvider(record.id));
          // ‼️ FIX Bug #21: refresh records list để cập nhật netPay trên màn trước
          ref.invalidate(payrollRecordsProvider(record.periodId));
        },
      ),
    );
  }

  String _modeLabel(String m) {
    switch (m) {
      case 'M1': return 'Theo giờ';
      case 'M2': return 'Cố định tháng';
      case 'M3': return 'Cố định + OT';
      case 'M4': return 'Theo ngày';
      default:   return m;
    }
  }
}

// ─── Payslip Card ─────────────────────────────────────────────────────────────

class _PayslipCard extends StatelessWidget {
  final PayrollRecordModel record;
  final PayrollPeriodModel period;
  const _PayslipCard({required this.record, required this.period});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(
          color: const Color(0xFF1C2151).withValues(alpha: 0.3),
          blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.receipt_long, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Text('Phiếu Lương — ${period.name}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        Text(record.staffName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
        if (record.role != null)
          Text(record.role!, style: const TextStyle(color: Colors.white60, fontSize: 13)),
        const SizedBox(height: 16),
        const Divider(color: Colors.white24),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _PayslipStat('Tổng giờ', '${record.totalHours.toStringAsFixed(1)}h')),
          Expanded(child: _PayslipStatusBadge(status: record.paymentStatus)),
          Expanded(child: _PayslipStat('Chế độ', _modeLabel(record.salaryMode))),
        ]),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Thực lĩnh',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              Text(_fmtMoney(record.netPay),
                  style: const TextStyle(color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w900, fontSize: 22)),
            ],
          ),
        ),
      ]),
    );
  }


  String _modeLabel(String m) {
    switch (m) {
      case 'M1': return 'Theo giờ';
      case 'M2': return 'Cố định';
      case 'M3': return 'CĐ+OT';
      case 'M4': return 'Theo ngày';
      default:   return m;
    }
  }
}

class _PayslipStat extends StatelessWidget {
  final String label;
  final String value;
  const _PayslipStat(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
    const SizedBox(height: 4),
    Text(value, style: const TextStyle(color: Colors.white,
        fontWeight: FontWeight.w700, fontSize: 14)),
  ]);
}

/// Badge trạng thái thanh toán trong Payslip Card (nền tối)
class _PayslipStatusBadge extends StatelessWidget {
  final String status;
  const _PayslipStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (status) {
      'paid' => (Icons.check_circle_rounded,  'Đã trả',  const Color(0xFF69F0AE)),
      'hold' => (Icons.pause_circle_rounded,  'Tạm giữ', const Color(0xFFFFD740)),
      _      => (Icons.hourglass_top_rounded, 'Chờ trả', const Color(0xFFFFCC80)),
    };
    return Column(children: [
      const Text('Trạng thái',
          style: TextStyle(color: Colors.white54, fontSize: 11)),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Flexible(child: Text(label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
            overflow: TextOverflow.ellipsis)),
      ]),
    ]);
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Text(title, style: const TextStyle(
          fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1C2151))),
      const SizedBox(width: 8),
      const Expanded(child: Divider()),
    ]),
  );
}

class _DetailRow extends StatelessWidget {
  final String  label;
  final double  amount;
  final Color?  color;
  final TextStyle? style;
  const _DetailRow(this.label, this.amount, {this.color, this.style});

  @override
  Widget build(BuildContext context) {
    final isNeg = amount < 0;
    final c = color ?? (isNeg ? Colors.red : Colors.black87);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(label, style: style ?? const TextStyle(fontSize: 14))),
        Text(
          '${isNeg ? '-' : '+'}${_fmtMoney(amount.abs())}',
          style: (style ?? const TextStyle(fontSize: 14)).copyWith(color: c, fontWeight: FontWeight.w600),
        ),
      ]),
    );
  }
}


// ─── Shift Summary Grid (clickable) ──────────────────────────────────────────

class _ShiftSummaryGrid extends StatelessWidget {
  final PayrollRecordModel record;
  final String periodFrom;
  final String periodTo;
  const _ShiftSummaryGrid({
    required this.record, required this.periodFrom, required this.periodTo});

  @override
  Widget build(BuildContext context) {
    final stats = [
      (Icons.schedule_rounded,       const Color(0xFF1565C0), 'Tổng giờ làm',  '${record.totalHours.toStringAsFixed(1)}h'),
      (Icons.trending_up_rounded,    const Color(0xFF6A1B9A), 'Tăng ca',        '${record.overtimeHours.toStringAsFixed(1)}h'),
      (Icons.event_busy_rounded,     const Color(0xFFC62828), 'Nghỉ',           '${record.absentDays} ngày'),
      (Icons.alarm_rounded,          const Color(0xFFE65100), 'Đi muộn',        '${record.lateCount} lần'),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showShiftDetail(context),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0D8CC)),
            boxShadow: [BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8, offset: const Offset(0, 2),
            )],
          ),
          child: Column(children: [
            // Tap hint
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(children: [
                const Icon(Icons.touch_app_rounded, size: 14, color: Color(0xFF9E9085)),
                const SizedBox(width: 4),
                const Text('Nhấn để xem chi tiết ca làm việc',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9E9085))),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF9E9085)),
              ]),
            ),
            // Grid 2×2
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              childAspectRatio: 1.1,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              children: stats.map((s) => _StatCell(
                icon: s.$1, color: s.$2, label: s.$3, value: s.$4,
              )).toList(),
            ),
          ]),
        ),
      ),
    );
  }

  void _showShiftDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShiftDetailSheet(
        userId: record.userId,
        staffName: record.staffName,
        periodFrom: periodFrom,
        periodTo: periodTo,
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _StatCell({required this.icon, required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(height: 5),
      Text(value, style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: const TextStyle(
          fontSize: 9, color: Color(0xFF9E9085)), textAlign: TextAlign.center),
    ],
  );
}

// ─── Shift Detail Sheet ───────────────────────────────────────────────────────

class _ShiftDetailSheet extends StatefulWidget {
  final String userId;
  final String staffName;
  final String periodFrom;
  final String periodTo;
  const _ShiftDetailSheet({
    required this.userId, required this.staffName,
    required this.periodFrom, required this.periodTo,
  });

  @override
  State<_ShiftDetailSheet> createState() => _ShiftDetailSheetState();
}

class _ShiftDetailSheetState extends State<_ShiftDetailSheet> {
  List<Map<String, dynamic>> _shifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final db = Supabase.instance.client;
      final from = DateTime.parse(widget.periodFrom);
      final to   = DateTime.parse(widget.periodTo).add(const Duration(days: 1));
      final fromUtc = DateTime.utc(from.year, from.month, from.day).subtract(const Duration(hours: 7));
      final toUtc   = DateTime.utc(to.year, to.month, to.day).subtract(const Duration(hours: 7));
      final rows = await db.from('staff_shifts')
          .select('clock_in, clock_out, is_late, late_minutes')
          .eq('user_id', widget.userId)
          .gte('clock_in', fromUtc.toIso8601String())
          .lt('clock_in', toUtc.toIso8601String())
          .not('clock_out', 'is', null)
          .order('clock_in', ascending: false);
      if (mounted) setState(() { _shifts = List<Map<String,dynamic>>.from(rows); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(children: [
          // Handle
          const SizedBox(height: 12),
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE0D8CC),
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2151).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Color(0xFF1C2151), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(widget.staffName,
                    style: const TextStyle(fontWeight: FontWeight.w800,
                        fontSize: 16, color: Color(0xFF1C2151))),
                Text('${widget.periodFrom} → ${widget.periodTo}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
              ])),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          // List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _shifts.isEmpty
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event_note_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text('Không có ca nào trong kỳ này',
                            style: TextStyle(color: Colors.grey[500])),
                      ]))
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _shifts.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final s  = _shifts[i];
                          final ci = DateTime.parse(s['clock_in'] as String).toLocal();
                          final co = s['clock_out'] != null
                              ? DateTime.parse(s['clock_out'] as String).toLocal() : null;
                          final hours = co != null
                              ? co.difference(ci).inMinutes / 60.0 : null;
                          final isLate = (s['is_late'] as bool?) ?? false;
                          final fmt2  = (int v) => v.toString().padLeft(2, '0');
                          final timeStr = '${fmt2(ci.hour)}:${fmt2(ci.minute)} → '
                              '${co != null ? '${fmt2(co.hour)}:${fmt2(co.minute)}' : '—'}';
                          final dateStr = '${fmt2(ci.day)}/${fmt2(ci.month)}/${ci.year}';
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(vertical: 4),
                            leading: Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: isLate
                                    ? const Color(0xFFE65100).withValues(alpha: 0.1)
                                    : const Color(0xFF1565C0).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isLate ? Icons.alarm_rounded : Icons.check_circle_outline_rounded,
                                color: isLate ? const Color(0xFFE65100) : const Color(0xFF1565C0),
                                size: 22,
                              ),
                            ),
                            title: Text(dateStr,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                            subtitle: Text(timeStr,
                                style: const TextStyle(fontSize: 12, color: Color(0xFF9E9085))),
                            trailing: hours != null
                                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                                    Text('${hours.toStringAsFixed(1)}h',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15, color: Color(0xFF1C2151))),
                                    if (isLate)
                                      const Text('Đi muộn',
                                          style: TextStyle(fontSize: 10, color: Color(0xFFE65100))),
                                  ]) : null,
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}


class _ItemTile extends StatelessWidget {
  final PayrollItemModel item;
  final VoidCallback onDelete;
  const _ItemTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isBonus = item.itemType == 'bonus' || item.itemType == 'allowance';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: (isBonus ? Colors.green : Colors.red).withValues(alpha: 0.1),
        child: Icon(isBonus ? Icons.add : Icons.remove,
            color: isBonus ? Colors.green : Colors.red, size: 16),
      ),
      title: Text(item.label, style: const TextStyle(fontSize: 14)),
      subtitle: item.note != null ? Text(item.note!, style: TextStyle(fontSize: 12, color: Colors.grey[500])) : null,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${isBonus ? '+' : '-'}${_fmtMoney(item.amount)}',
            style: TextStyle(color: isBonus ? Colors.green : Colors.red,
                fontWeight: FontWeight.w700)),
        if (!item.isAuto)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
            onPressed: onDelete,
          ),
      ]),
    );
  }
}

// ─── Add Item Sheet ───────────────────────────────────────────────────────────

class _AddItemSheet extends StatefulWidget {
  final String      recordId;
  final VoidCallback onAdded;
  const _AddItemSheet({required this.recordId, required this.onAdded});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _labelCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  String _type      = 'bonus';
  bool   _loading   = false;
  String _preview   = '';  // hiển thị “= 500.000đ” real-time

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_updatePreview);
  }

  void _updatePreview() {
    final raw = _amountCtrl.text.replaceAll('.', '');
    final val = double.tryParse(raw);
    setState(() => _preview = val != null && val > 0
        ? '= ${NumberFormat('#,###', 'vi_VN').format(val.round())}đ'
        : '');
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_updatePreview);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        const Text('Thêm khoản phát sinh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF1C2151))),
        const SizedBox(height: 16),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'bonus', label: Text('Thưởng'), icon: Icon(Icons.add_circle_outline)),
            ButtonSegment(value: 'allowance', label: Text('Phụ cấp'), icon: Icon(Icons.card_giftcard)),
            ButtonSegment(value: 'deduction', label: Text('Khấu trừ'), icon: Icon(Icons.remove_circle_outline)),
          ],
          selected: {_type},
          onSelectionChanged: (s) => setState(() => _type = s.first),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _labelCtrl,
          decoration: const InputDecoration(labelText: 'Tên khoản', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amountCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          inputFormatters: [_VndInputFormatter()],
          decoration: InputDecoration(
            labelText: 'Số tiền (đ)',
            border: const OutlineInputBorder(),
            suffixText: _preview.isNotEmpty ? _preview : null,
            suffixStyle: TextStyle(
              color: _type == 'deduction'
                  ? Colors.red[700] : Colors.green[700],
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteCtrl,
          decoration: const InputDecoration(labelText: 'Ghi chú (tuỳ chọn)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C2151),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _loading ? null : _submit,
            child: _loading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Future<void> _submit() async {
    final label  = _labelCtrl.text.trim();
    // Parse: xóa dấu chấm ngăn cách mà VndInputFormatter đã thêm vào
    final amount = double.tryParse(_amountCtrl.text.replaceAll('.', '').replaceAll(',', ''));
    if (label.isEmpty || amount == null || amount <= 0) return;

    setState(() => _loading = true);
    await TinhLuongRepository.addItem(
      recordId: widget.recordId,
      itemType: _type,
      label:    label,
      amount:   amount,
      note:     _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : null,
    );
    setState(() => _loading = false);
    widget.onAdded();
    if (mounted) Navigator.pop(context);
  }
}

// ─── VND Input Formatter ─────────────────────────────────────────────────────

class _VndInputFormatter extends TextInputFormatter {
  final _fmt = NumberFormat('#,###', 'vi_VN'); // dùng dấu chấm cách nghìn VN

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // Xóa mọi ký tự không phải số
    final digits = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }
    final number = int.tryParse(digits);
    if (number == null) return oldValue;

    // Format: 500000 → "500.000"
    // NumberFormat vi_VN dùng dấu chấm làm ngăn cách nghìn
    final formatted = _fmt.format(number);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// ─── Dispute Section (Manager) ───────────────────────────────────────────────

class _DisputeSection extends StatelessWidget {
  final String  recordId;
  final WidgetRef ref;
  const _DisputeSection({required this.recordId, required this.ref});

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(payrollDisputesProvider(recordId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error:   (_, __) => const SizedBox.shrink(),
      data: (disputes) {
        if (disputes.isEmpty) return const SizedBox.shrink();
        final open = disputes.where((d) => d['status'] == 'open').length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('Phản hồi nhân viên',
                style: TextStyle(fontWeight: FontWeight.w700,
                    fontSize: 14, color: Color(0xFF1C2151))),
            const SizedBox(width: 8),
            if (open > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFC62828),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$open mới',
                    style: const TextStyle(color: Colors.white,
                        fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 8),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 8),
          ...disputes.map((d) => _DisputeTile(
            dispute: d,
            onReplied: () {
              ref.invalidate(payrollDisputesProvider(recordId));
              // Invalidate badge ở màn hình chính và card list
              ref.invalidate(openDisputesCountProvider);
            },
          )),
        ]);
      },
    );
  }
}

class _DisputeTile extends StatelessWidget {
  final Map<String, dynamic> dispute;
  final VoidCallback onReplied;
  const _DisputeTile({required this.dispute, required this.onReplied});

  static const _fieldLabels = {
    'total_hours': 'Giờ làm sai',
    'overtime':    'Tăng ca sai',
    'deduction':   'Khấu trừ sai',
    'other':       'Vấn đề khác',
  };

  @override
  Widget build(BuildContext context) {
    final isOpen   = dispute['status'] == 'open';
    final hasReply = dispute['reply'] != null && (dispute['reply'] as String).isNotEmpty;
    final field    = dispute['field'] as String? ?? 'other';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOpen
            ? const Color(0xFFFFF3F3)
            : const Color(0xFFF5F0EA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isOpen
              ? const Color(0xFFC62828).withValues(alpha: 0.3)
              : const Color(0xFFE0D8CC),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isOpen
                  ? const Color(0xFFC62828).withValues(alpha: 0.1)
                  : Colors.green.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(_fieldLabels[field] ?? field,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: isOpen ? const Color(0xFFC62828) : Colors.green.shade700)),
          ),
          const SizedBox(width: 8),
          Text(isOpen ? 'Chưa xử lý' : 'Đã xử lý',
              style: TextStyle(
                  fontSize: 11,
                  color: isOpen ? const Color(0xFF9E9085) : Colors.green.shade600)),
          const Spacer(),
          Text(_formatDate(dispute['created_at'] as String? ?? ''),
              style: const TextStyle(fontSize: 10, color: Color(0xFF9E9085))),
        ]),
        const SizedBox(height: 8),
        Text(dispute['message'] as String? ?? '',
            style: const TextStyle(fontSize: 13, color: Color(0xFF1C2151))),
        if (hasReply) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF1565C0)),
              const SizedBox(width: 6),
              Expanded(child: Text(dispute['reply'] as String,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF1565C0)))),
            ]),
          ),
        ],
        if (isOpen) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: const Text('Trả lời',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => _showReply(context),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF9E9085),
                side: const BorderSide(color: Color(0xFFE0D8CC)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
              onPressed: () => _dismiss(context),
              child: const Text('Bỏ qua', style: TextStyle(fontSize: 13)),
            ),
          ]),
        ],
      ]),
    );
  }

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}';
    } catch (_) { return ''; }
  }

  void _showReply(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Trả lời khiếu nại',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nhập phản hồi của bạn...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1C2151)),
            onPressed: () async {
              final reply = ctrl.text.trim();
              if (reply.isEmpty) return;
              await Supabase.instance.client
                  .from('payroll_disputes')
                  .update({'reply': reply, 'status': 'resolved',
                      'resolved_at': DateTime.now().toUtc().toIso8601String()})
                  .eq('id', dispute['id'] as String);
              if (context.mounted) Navigator.pop(context);
              onReplied();
            },
            child: const Text('Gửi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _dismiss(BuildContext context) async {
    await Supabase.instance.client
        .from('payroll_disputes')
        .update({'status': 'dismissed',
            'resolved_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', dispute['id'] as String);
    onReplied();
  }
}

// ─── Export PDF Sheet ─────────────────────────────────────────────────────────


class _ExportPdfSheet extends StatefulWidget {
  final PayrollRecordModel record;
  final PayrollPeriodModel period;
  final WidgetRef ref;
  const _ExportPdfSheet({
    required this.record, required this.period, required this.ref});

  @override
  State<_ExportPdfSheet> createState() => _ExportPdfSheetState();
}

class _ExportPdfSheetState extends State<_ExportPdfSheet> {
  bool _loading = false;
  String? _error;

  Future<PayslipStoreInfo> _loadStoreInfo() async {
    final repo = AppSettingsRepository();
    // Store name từ SharedPreferences (đã cache khi login)
    final info = await StoreAuthService.getStoreInfo();
    final phone   = await repo.shopPhone;
    final address = await repo.shopAddress;
    final billFooter = await repo.billFooter;
    // ‼️ FIX: billFooter dùng chung với hoá đơn khách — thay bằng lời phù hợp cho NV
    // Nếu chủ quán chưa tuỳ chỉnh (vẫn là default hoá đơn khách hàng) → dùng lời NV
    const _customerDefaults = ['Cảm ơn quý khách!', 'Cảm ơn quý khách', ''];
    final footer = _customerDefaults.contains(billFooter.trim())
        ? 'Cảm ơn bạn vì sự cố gắng trong tháng qua!'
        : billFooter;
    return PayslipStoreInfo(
      name:    (info['store_name'] ?? '').isNotEmpty ? info['store_name']! : 'Quán Nhỏ',
      phone:   phone,
      address: address,
      footer:  footer,
    );
  }

  Future<void> _export({required bool isA4, required bool preview}) async {
    setState(() { _loading = true; _error = null; });
    try {
      // ‼️ FIX: Fetch record & items FRESH từ DB — widget.record là stale từ lúc navigate
      // nếu user vừa thêm item thì net_pay đã được _recalcNetPay update trong DB
      // nhưng widget.record.netPay vẫn là số cũ → PDF sẽ sai nếu dùng widget.record
      final freshRecord = await TinhLuongRepository.fetchRecordById(widget.record.id)
          ?? widget.record; // fallback an toàn nếu fetch thất bại
      final items = await TinhLuongRepository.fetchItems(widget.record.id);
      final storeInfo = await _loadStoreInfo();

      final bytes = isA4
          ? await PayslipPdfService.generateA4(
              record: freshRecord, period: widget.period,
              items: items, store: storeInfo)
          : await PayslipPdfService.generate80mm(
              record: freshRecord, period: widget.period,
              items: items, store: storeInfo);


      // Tên file dùng chung
      final fileName = 'PhieuLuong_${widget.record.staffName.replaceAll(' ', '_')}'
          '_${widget.period.name.replaceAll('/', '-')}_${isA4 ? 'A4' : '80mm'}.pdf';

      if (!mounted) return;

      if (preview) {
        // ✅ FIX: reset loading TRƯỚC khi pop — vì sau pop widget unmounted,
        // gọi setState sẽ throw. Dùng nav reference để tránh context stale.
        setState(() => _loading = false);
        final nav = Navigator.of(context);
        nav.pop();                               // 1. Đóng bottom sheet
        nav.push(MaterialPageRoute(              // 2. Mở preview screen
          builder: (_) => _PdfPreviewScreen(
            title: 'Phiếu Lương ${widget.record.staffName}',
            subtitle: widget.period.name,
            pdfBytes: bytes,
            fileName: fileName,
          ),
        ));
      } else {
        setState(() => _loading = false);
        // Share trực tiếp qua hệ thống
        final dir  = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);

        if (!mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path)],
            text: 'Phiếu lương: ${widget.record.staffName} — ${widget.period.name}',
          ),
        );
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Lỗi tạo PDF: $e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFE0D8CC),
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),

        // Header
        Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF1C2151), Color(0xFF2D3A8C)]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Xuất Phiếu Lương',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                    color: Color(0xFF1C2151))),
            Text(widget.record.staffName,
                style: const TextStyle(fontSize: 13, color: Color(0xFF9E9085))),
          ]),
        ]),
        const SizedBox(height: 20),

        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
          ),
          const SizedBox(height: 12),
        ],

        if (_loading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(color: Color(0xFF1C2151)),
          )
        else ...[
          // A4
          _PdfOption(
            icon: Icons.description_rounded,
            label: 'Khổ A4',
            subtitle: 'Phiếu lương chính thức, có chữ ký',
            color: const Color(0xFF1565C0),
            onPreview: () => _export(isA4: true, preview: true),
            onShare:   () => _export(isA4: true, preview: false),
          ),
          const SizedBox(height: 10),
          // 80mm
          _PdfOption(
            icon: Icons.receipt_long_rounded,
            label: 'Khổ 80mm',
            subtitle: 'Compact, in máy nhiệt / gửi nhanh',
            color: const Color(0xFF6A1B9A),
            onPreview: () => _export(isA4: false, preview: true),
            onShare: () => _export(isA4: false, preview: false),
          ),
        ],
      ]),
    );
  }
}

class _PdfOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onPreview;
  final VoidCallback onShare;
  const _PdfOption({
    required this.icon, required this.label, required this.subtitle,
    required this.color, required this.onPreview, required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700, color: color)),
          Text(subtitle, style: const TextStyle(
              fontSize: 12, color: Color(0xFF9E9085))),
        ])),
        // Actions
        Column(children: [
          _ActionBtn(icon: Icons.preview_rounded, label: 'Xem', color: color, onTap: onPreview),
          const SizedBox(height: 6),
          _ActionBtn(icon: Icons.share_rounded, label: 'Chia sẻ', color: color, onTap: onShare),
        ]),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label,
    required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11,
            fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}


// ─── In-App PDF Preview Screen ────────────────────────────────────────────────

class _PdfPreviewScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Uint8List pdfBytes;
  final String fileName;

  const _PdfPreviewScreen({
    required this.title,
    required this.subtitle,
    required this.pdfBytes,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2151),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Quay lại',
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            Text(subtitle, style: const TextStyle(
                fontSize: 11, color: Colors.white60)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Chia sẻ PDF',
            onPressed: () async {
              final dir  = await getApplicationDocumentsDirectory();
              final file = File('${dir.path}/$fileName');
              await file.writeAsBytes(pdfBytes);
              await SharePlus.instance.share(ShareParams(
                files: [XFile(file.path)],
                text: title,
              ));
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: PdfPreview(
        build: (_) async => pdfBytes,
        allowPrinting: true,
        allowSharing: false,
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        pdfFileName: fileName,
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: Color(0xFF1C2151)),
        ),
      ),
    );
  }
}
