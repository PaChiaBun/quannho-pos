// lib/modules/tinhluong/screens/staff_salary_config_screen.dart
// Màn hình cấu hình lương từng nhân viên
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/store_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final staffSalaryConfigsProvider =
    FutureProvider.autoDispose<List<StaffSalaryConfig>>((ref) {
  return StaffSalaryConfigRepo.fetchAll();
});

// ─── Model ───────────────────────────────────────────────────────────────────

class StaffSalaryConfig {
  final String id;
  final String storeId;
  final String userId;
  final String staffName;
  final String role;
  final String salaryMode; // M1 | M2 | M3 | M4
  final double baseSalary;
  final double hourlyRate;
  final double dailyRate;
  final int expectedDays;
  final double deductionPerLate;
  final double otThresholdHours;
  final double otMultiplier;  // Hệ số OT: 1.5 mặc định

  const StaffSalaryConfig({
    required this.id,
    required this.storeId,
    required this.userId,
    required this.staffName,
    required this.role,
    required this.salaryMode,
    required this.baseSalary,
    required this.hourlyRate,
    required this.dailyRate,
    required this.expectedDays,
    required this.deductionPerLate,
    required this.otThresholdHours,
    this.otMultiplier = 1.5,
  });

  factory StaffSalaryConfig.fromMap(Map<String, dynamic> m) =>
      StaffSalaryConfig(
        id:                m['id'] as String,
        storeId:           m['store_id'] as String,
        userId:            m['user_id'] as String,
        staffName:         m['staff_name'] as String? ?? '',
        role:              m['role'] as String? ?? '',
        salaryMode:        m['salary_mode'] as String? ?? 'M1',
        baseSalary:        (m['base_salary'] as num?)?.toDouble() ?? 0,
        hourlyRate:        (m['hourly_rate'] as num?)?.toDouble() ?? 0,
        dailyRate:         (m['daily_rate'] as num?)?.toDouble() ?? 0,
        expectedDays:      (m['expected_days'] as int?) ?? 26,
        deductionPerLate:  (m['deduction_per_late'] as num?)?.toDouble() ?? 50000,
        otThresholdHours:  (m['ot_threshold_hours'] as num?)?.toDouble() ?? 8.0,
        otMultiplier:      (m['ot_multiplier'] as num?)?.toDouble() ?? 1.5,
      );
}

// ─── Repository ──────────────────────────────────────────────────────────────

class StaffSalaryConfigRepo {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  static Future<List<StaffSalaryConfig>> fetchAll() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    try {
      final rows = await _sb
          .from('staff_salary_configs')
          .select()
          .eq('store_id', storeId)
          .order('staff_name');
      return (rows as List)
          .map((r) => StaffSalaryConfig.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[SalaryCfg] fetchAll error: $e');
      return [];
    }
  }

  static Future<void> upsert({
    required String userId,
    required String staffName,
    required String role,
    required String salaryMode,
    required double baseSalary,
    required double hourlyRate,
    required double dailyRate,
    required int expectedDays,
    required double deductionPerLate,
    required double otThresholdHours,
    double otMultiplier = 1.5,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    await _sb.from('staff_salary_configs').upsert({
      'store_id':           storeId,
      'user_id':            userId,
      'staff_name':         staffName,
      'role':               role,
      'salary_mode':        salaryMode,
      'base_salary':        baseSalary,
      'hourly_rate':        hourlyRate,
      'daily_rate':         dailyRate,
      'expected_days':      expectedDays,
      'deduction_per_late': deductionPerLate,
      'ot_threshold_hours': otThresholdHours,
      'ot_multiplier':      otMultiplier,
      'updated_at':         DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'store_id,user_id');
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class StaffSalaryConfigScreen extends ConsumerWidget {
  const StaffSalaryConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffSalaryConfigsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C2151),
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cấu hình lương',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            Text('Thiết lập chế độ lương từng nhân viên',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => ref.invalidate(staffSalaryConfigsProvider),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(message: '$e',
            onRetry: () => ref.invalidate(staffSalaryConfigsProvider)),
        data: (configs) => _buildBody(context, ref, configs),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'salary_cfg_fab',
        backgroundColor: const Color(0xFF1C2151),
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text('Thêm cấu hình',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        onPressed: () => _showEditSheet(context, ref, existing: null),
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref,
      List<StaffSalaryConfig> configs) {
    if (configs.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.payments_outlined, size: 72, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Chưa có cấu hình lương',
              style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Bấm "Thêm cấu hình" để thiết lập\nchế độ lương cho từng nhân viên',
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '💡 Cấu hình ở đây sẽ được dùng khi "Tạo bảng lương tự động" trong kỳ lương.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ),
        ]),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: configs.length,
      itemBuilder: (ctx, i) => _ConfigCard(
        config: configs[i],
        onEdit: () => _showEditSheet(ctx, ref, existing: configs[i]),
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref,
      {required StaffSalaryConfig? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditSheet(
        existing: existing,
        onSaved: () => ref.invalidate(staffSalaryConfigsProvider),
      ),
    );
  }
}

// ─── Config Card ─────────────────────────────────────────────────────────────

class _ConfigCard extends StatelessWidget {
  final StaffSalaryConfig config;
  final VoidCallback onEdit;

  const _ConfigCard({required this.config, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final modeInfo = _modeInfo(config.salaryMode);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: modeInfo.$2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  config.staffName.isNotEmpty
                      ? config.staffName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: modeInfo.$2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(config.staffName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1C2151))),
                const SizedBox(height: 2),
                Text(config.role.isEmpty ? 'Nhân viên' : config.role,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 6),
                // Mode badge + main rate
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: modeInfo.$2.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(modeInfo.$1,
                        style: TextStyle(
                            color: modeInfo.$2,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  Text(_mainRateLabel(config),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 12)),
                ]),
              ]),
            ),
            // Edit button
            Icon(Icons.edit_outlined, size: 18, color: Colors.grey[400]),
          ]),
        ),
      ),
    );
  }

  String _mainRateLabel(StaffSalaryConfig c) {
    final fmt = (double v) => '${(v / 1000).round()}K';
    switch (c.salaryMode) {
      case 'M1': return '${fmt(c.hourlyRate)}/giờ';
      case 'M2': return '${fmt(c.baseSalary)}/tháng';
      case 'M3': return '${fmt(c.baseSalary)}/tháng + ${fmt(c.hourlyRate)}/giờ OT';
      case 'M4': return '${fmt(c.dailyRate)}/ngày';
      default:   return '';
    }
  }

  (String, Color) _modeInfo(String mode) {
    switch (mode) {
      case 'M1': return ('Theo giờ',   const Color(0xFF0EA5E9));
      case 'M2': return ('Cố định',    const Color(0xFF8B5CF6));
      case 'M3': return ('Cố định+OT', const Color(0xFFEC4899));
      case 'M4': return ('Theo ngày',  const Color(0xFF10B981));
      default:   return (mode,         Colors.grey);
    }
  }
}

// ─── Edit Sheet ───────────────────────────────────────────────────────────────

class _EditSheet extends StatefulWidget {
  final StaffSalaryConfig? existing;
  final VoidCallback onSaved;
  const _EditSheet({this.existing, required this.onSaved});

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  final _roleCtrl          = TextEditingController();
  final _baseCtrl          = TextEditingController();
  final _hourlyCtrl        = TextEditingController();
  final _dailyCtrl         = TextEditingController();
  final _daysCtrl          = TextEditingController();
  final _latePenaltyCtrl   = TextEditingController();
  final _otThreshCtrl      = TextEditingController();
  final _otMultiplierCtrl  = TextEditingController();  // Hệ số OT

  String _mode = 'M1';
  bool   _saving = false;

  // ‼️ Staff picker state — thay thế nhập tay User ID
  List<_StaffOption> _staffOptions = [];
  _StaffOption? _selectedStaff;   // NV đang chọn
  bool _loadingStaff = false;

  static const _modes = [
    ('M1', 'Theo giờ',   'Lương = giờ làm × đơn giá giờ'),
    ('M2', 'Cố định',    'Lương = lương cơ bản/tháng'),
    ('M3', 'Cố định+OT', 'Lương = cơ bản + OT × đơn giá giờ'),
    ('M4', 'Theo ngày',  'Lương = số ngày làm × đơn giá ngày'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      // Khi edit: hiển thị NV hiện tại, populate dropdown
      _selectedStaff = _StaffOption(id: e.userId, name: e.staffName, role: e.role);
      _roleCtrl.text        = e.role;
      _mode                 = e.salaryMode;
      _baseCtrl.text        = e.baseSalary > 0 ? e.baseSalary.round().toString() : '';
      _hourlyCtrl.text      = e.hourlyRate > 0 ? e.hourlyRate.round().toString() : '';
      _dailyCtrl.text       = e.dailyRate  > 0 ? e.dailyRate.round().toString()  : '';
      _daysCtrl.text        = e.expectedDays.toString();
      _latePenaltyCtrl.text = e.deductionPerLate.round().toString();
      _otThreshCtrl.text    = e.otThresholdHours.toString();
      _otMultiplierCtrl.text = e.otMultiplier.toString();
    } else {
      _daysCtrl.text        = '26';
      _latePenaltyCtrl.text = '50000';
      _otThreshCtrl.text    = '8.0';
      _hourlyCtrl.text      = '25000';
      _otMultiplierCtrl.text = '1.5';
    }
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    setState(() => _loadingStaff = true);
    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id'] as String?;
      if (storeId == null) return;
      final rows = await Supabase.instance.client
          .from('store_members')
          .select('user_id, role, user_accounts(display_name)')
          .eq('store_id', storeId)
          .neq('role', 'owner');
      final opts = (rows as List).map((r) {
        final ua = r['user_accounts'] as Map?;
        return _StaffOption(
          id:   r['user_id'] as String,
          name: ua?['display_name'] as String? ?? 'Không tên',
          role: r['role'] as String? ?? '',
        );
      }).toList();
      opts.sort((a, b) => a.name.compareTo(b.name));
      if (mounted) setState(() => _staffOptions = opts);
    } catch (e) {
      debugPrint('[SalaryConfig] _loadStaffList error: $e');
    } finally {
      if (mounted) setState(() => _loadingStaff = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_roleCtrl, _baseCtrl,
      _hourlyCtrl, _dailyCtrl, _daysCtrl, _latePenaltyCtrl, _otThreshCtrl,
      _otMultiplierCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.existing == null
                  ? 'Thêm cấu hình lương' : 'Chỉnh cấu hình lương',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1C2151)),
            ),
            const SizedBox(height: 20),

            // ─── Chọn nhân viên (dropdown) ───
            _Section('Nhân viên'),
            const SizedBox(height: 8),
            _loadingStaff
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: CircularProgressIndicator(strokeWidth: 2)))
                : DropdownButtonFormField<_StaffOption>(
                    value: _staffOptions.any((o) => o.id == _selectedStaff?.id)
                        ? _staffOptions.firstWhere((o) => o.id == _selectedStaff!.id)
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Chọn nhân viên',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    hint: const Text('Chọn nhân viên từ danh sách'),
                    isExpanded: true,
                    items: _staffOptions.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s.role.isEmpty ? s.name : '${s.name}  ·  ${s.role}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    selectedItemBuilder: (_) => _staffOptions.map((s) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        s.role.isEmpty ? s.name : '${s.name}  ·  ${s.role}',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )).toList(),
                    onChanged: (s) => setState(() {
                      _selectedStaff = s;
                      if (s != null && _roleCtrl.text.isEmpty) {
                        _roleCtrl.text = s.role; // tự điền vai trò từ module NV
                      }
                    }),
                  ),
            const SizedBox(height: 10),
            _Field(ctrl: _roleCtrl, label: 'Vai trò / Chức danh',
                hint: 'VD: Thu ngân, Barista, Phục vụ...'),
            const SizedBox(height: 20),

            // ─── Chế độ lương ───
            _Section('Chế độ lương'),
            const SizedBox(height: 10),
            ..._modes.map((m) => _ModeRadio(
              value: m.$1,
              label: m.$2,
              desc:  m.$3,
              groupValue: _mode,
              onChanged: (v) => setState(() => _mode = v!),
            )),
            const SizedBox(height: 20),

            // ─── Mức lương theo mode ───
            _Section('Mức lương'),
            const SizedBox(height: 10),

            if (_mode == 'M1' || _mode == 'M3') ...[
              _MoneyField(ctrl: _hourlyCtrl, label: 'Đơn giá giờ thường (đ/giờ)'),
              const SizedBox(height: 10),
            ],
            if (_mode == 'M2' || _mode == 'M3') ...[
              _MoneyField(ctrl: _baseCtrl, label: 'Lương cơ bản (đ/tháng)'),
              const SizedBox(height: 10),
            ],
            if (_mode == 'M4') ...[
              _MoneyField(ctrl: _dailyCtrl, label: 'Đơn giá ngày (đ/ngày)'),
              const SizedBox(height: 10),
            ],
            _MoneyField(
              ctrl: _daysCtrl,
              label: 'Số ngày làm chuẩn trong kỳ',
              hint: '26',
              isInteger: true,
            ),
            const SizedBox(height: 20),

            // ─── Khấu trừ & OT ───
            _Section('Khấu trừ & OT'),
            const SizedBox(height: 10),
            _MoneyField(ctrl: _latePenaltyCtrl, label: 'Phạt đi trễ (đ/lần)', hint: '50000'),
            const SizedBox(height: 10),
            _MoneyField(
              ctrl: _otThreshCtrl,
              label: 'Ngưỡng OT (giờ/ca)',
              hint: '8.0',
              isDecimal: true,
            ),
            const SizedBox(height: 10),
            _MoneyField(
              ctrl: _otMultiplierCtrl,
              label: 'Hệ số OT (x lương)',
              hint: '1.5',
              isDecimal: true,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                '• Ngày thường: 1.5x • Cuối tuần: 2.0x • Ngày lễ: 3.0x',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Nút lưu ───
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C2151),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Lưu cấu hình',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final staff = _selectedStaff;
    if (staff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng chọn nhân viên')));
      return;
    }

    setState(() => _saving = true);
    try {
      await StaffSalaryConfigRepo.upsert(
        userId:            staff.id,
        staffName:         staff.name,
        role:              _roleCtrl.text.trim().isEmpty ? staff.role : _roleCtrl.text.trim(),
        salaryMode:        _mode,
        baseSalary:        double.tryParse(_baseCtrl.text)    ?? 0,
        hourlyRate:        double.tryParse(_hourlyCtrl.text)  ?? 0,
        dailyRate:         double.tryParse(_dailyCtrl.text)   ?? 0,
        expectedDays:      int.tryParse(_daysCtrl.text)       ?? 26,
        deductionPerLate:  double.tryParse(_latePenaltyCtrl.text) ?? 50000,
        otThresholdHours:  double.tryParse(_otThreshCtrl.text) ?? 8.0,
        otMultiplier:      double.tryParse(_otMultiplierCtrl.text) ?? 1.5,
      );
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã lưu cấu hình lương ✅')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1C2151)));
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;

  const _Field({required this.ctrl, required this.label, this.hint});

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
}

class _MoneyField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool isInteger;
  final bool isDecimal;

  const _MoneyField({
    required this.ctrl,
    required this.label,
    this.hint,
    this.isInteger = false,
    this.isDecimal = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: ctrl,
        keyboardType: isDecimal
            ? const TextInputType.numberWithOptions(decimal: true)
            : const TextInputType.numberWithOptions(decimal: false),
        inputFormatters: isDecimal
            ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
            : [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
}

class _ModeRadio extends StatelessWidget {
  final String value;
  final String label;
  final String desc;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  const _ModeRadio({
    required this.value,
    required this.label,
    required this.desc,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final color = selected ? const Color(0xFF1C2151) : Colors.grey.shade400;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1C2151).withValues(alpha: 0.07)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF1C2151) : Colors.grey.shade200,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Radio<String>(
            value: value,
            groupValue: groupValue,
            onChanged: onChanged,
            activeColor: const Color(0xFF1C2151),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('[$value] $label',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: color)),
              ]),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500])),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Thử lại')),
        ]),
      );
}

/// Data class đại diện 1 NV trong dropdown picker
class _StaffOption {
  final String id;
  final String name;
  final String role;
  const _StaffOption({required this.id, required this.name, required this.role});

  @override
  bool operator ==(Object other) => other is _StaffOption && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

