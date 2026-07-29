// lib/modules/tinhluong/screens/staff_salary_config_screen.dart
// Màn hình cấu hình lương từng nhân viên
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/providers/permission_provider.dart';

import '../repository/staff_salary_config_repository.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final staffSalaryConfigsProvider =
    FutureProvider.autoDispose<List<StaffSalaryConfig>>((ref) {
      return StaffSalaryConfigRepo.fetchAll();
    });

// ─── Screen ──────────────────────────────────────────────────────────────────

class StaffSalaryConfigScreen extends ConsumerWidget {
  const StaffSalaryConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permsAsync = ref.watch(userActionPermsProvider);

    return permsAsync.when(
      loading: () => const Scaffold(
        backgroundColor: Color(0xFFFFF8F0),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: const Color(0xFFFFF8F0),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C2151),
          foregroundColor: Colors.white,
          title: const Text('Cấu hình lương'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Không thể kiểm tra quyền truy cập',
                style: TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lại'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => ref.invalidate(userActionPermsProvider),
                      child: const Text('Thử lại'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      data: (perms) {
        if (!perms.contains('tinhluong.manage_config')) {
          return Scaffold(
            backgroundColor: const Color(0xFFFFF8F0),
            appBar: AppBar(
              backgroundColor: const Color(0xFF1C2151),
              foregroundColor: Colors.white,
              title: const Text('Cấu hình lương'),
            ),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Bạn không có quyền quản lý cấu hình lương',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Quay lại'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final async = ref.watch(staffSalaryConfigsProvider);

        return Scaffold(
          backgroundColor: const Color(0xFFFFF8F0),
          appBar: AppBar(
            backgroundColor: const Color(0xFF1C2151),
            foregroundColor: Colors.white,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cấu hình lương',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                ),
                Text(
                  'Thiết lập chế độ lương từng nhân viên',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => ref.invalidate(staffSalaryConfigsProvider),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorView(
                  message:
                      'Không thể tải danh sách cấu hình. Vui lòng thử lại.',
                  onRetry: () => ref.invalidate(staffSalaryConfigsProvider),
                ),
                data: (configs) => _buildBody(context, ref, configs),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'salary_cfg_fab',
            backgroundColor: const Color(0xFF1C2151),
            icon: const Icon(Icons.person_add_outlined, color: Colors.white),
            label: const Text(
              'Thêm cấu hình',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: () => _showEditSheet(context, ref, existing: null),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    List<StaffSalaryConfig> configs,
  ) {
    if (configs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.payments_outlined, size: 72, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Chưa có cấu hình lương',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
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
          ],
        ),
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

  void _showEditSheet(
    BuildContext context,
    WidgetRef ref, {
    required StaffSalaryConfig? existing,
  }) {
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
          child: Row(
            children: [
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
                      color: modeInfo.$2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.staffName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Color(0xFF1C2151),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      config.role.isEmpty ? 'Nhân viên' : config.role,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    // Mode badge + main rate
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: modeInfo.$2.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            modeInfo.$1,
                            style: TextStyle(
                              color: modeInfo.$2,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _mainRateLabel(config),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Edit button
              Icon(Icons.edit_outlined, size: 18, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _mainRateLabel(StaffSalaryConfig c) {
    String fmt(double v) => '${(v / 1000).round()}K';
    switch (c.salaryMode) {
      case 'M1':
        return '${fmt(c.hourlyRate)}/giờ';
      case 'M2':
        return '${fmt(c.baseSalary)}/tháng';
      case 'M3':
        return '${fmt(c.baseSalary)}/tháng + ${fmt(c.hourlyRate)}/giờ OT';
      case 'M4':
        return '${fmt(c.dailyRate)}/ngày';
      default:
        return '';
    }
  }

  (String, Color) _modeInfo(String mode) {
    switch (mode) {
      case 'M1':
        return ('Theo giờ', const Color(0xFF0EA5E9));
      case 'M2':
        return ('Cố định', const Color(0xFF8B5CF6));
      case 'M3':
        return ('Cố định+OT', const Color(0xFFEC4899));
      case 'M4':
        return ('Theo ngày', const Color(0xFF10B981));
      default:
        return (mode, Colors.grey);
    }
  }
}

// ─── Edit Sheet ───────────────────────────────────────────────────────────────

class _EditSheet extends ConsumerStatefulWidget {
  final StaffSalaryConfig? existing;
  final VoidCallback onSaved;
  const _EditSheet({this.existing, required this.onSaved});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  final _roleCtrl = TextEditingController();
  final _baseCtrl = TextEditingController();
  final _hourlyCtrl = TextEditingController();
  final _dailyCtrl = TextEditingController();
  final _daysCtrl = TextEditingController();
  final _latePenaltyCtrl = TextEditingController();
  final _otThreshCtrl = TextEditingController();
  final _otMultiplierCtrl = TextEditingController(); // Hệ số OT

  String _mode = 'M1';
  bool _saving = false;

  // ‼️ Staff picker state — thay thế nhập tay User ID
  List<_StaffOption> _staffOptions = [];
  _StaffOption? _selectedStaff; // NV đang chọn
  bool _loadingStaff = false;
  String? _staffListError;

  static const _modes = [
    ('M1', 'Theo giờ', 'Lương = giờ làm × đơn giá giờ'),
    ('M2', 'Cố định', 'Lương = lương cơ bản/tháng'),
    ('M3', 'Cố định+OT', 'Lương = cơ bản + OT × đơn giá giờ'),
    ('M4', 'Theo ngày', 'Lương = số ngày làm × đơn giá ngày'),
  ];

  String _resolveRoleLabel(String rawRole) {
    final l = rawRole.trim().toLowerCase();
    if (l == 'owner') return 'Chủ quán';
    if (l == 'manager' || l == 'quản lý') return 'Quản lý';
    if (l == 'cashier' || l == 'thu ngân') return 'Thu ngân';
    if (l == 'waiter' || l == 'phục vụ') return 'Phục vụ';
    return rawRole.isNotEmpty ? rawRole : 'Nhân viên';
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      // Khi edit: hiển thị NV hiện tại, populate dropdown
      _selectedStaff = _StaffOption(
        id: e.userId,
        name: e.staffName,
        role: e.role,
      );
      _roleCtrl.text = e.role;
      _mode = e.salaryMode;
      _baseCtrl.text = e.baseSalary > 0 ? e.baseSalary.round().toString() : '';
      _hourlyCtrl.text = e.hourlyRate > 0
          ? e.hourlyRate.round().toString()
          : '';
      _dailyCtrl.text = e.dailyRate > 0 ? e.dailyRate.round().toString() : '';
      _daysCtrl.text = e.expectedDays.toString();
      _latePenaltyCtrl.text = e.deductionPerLate.round().toString();
      _otThreshCtrl.text = e.otThresholdHours.toString();
      _otMultiplierCtrl.text = e.otMultiplier.toString();
    } else {
      _daysCtrl.text = '26';
      _latePenaltyCtrl.text = '50000';
      _otThreshCtrl.text = '8.0';
      _hourlyCtrl.text = '25000';
      _otMultiplierCtrl.text = '1.5';
    }
    _loadStaffList();
  }

  Future<void> _loadStaffList() async {
    setState(() {
      _loadingStaff = true;
      _staffListError = null;
    });
    try {
      final info = await StoreAuthService.getStoreInfo();
      final storeId = info['store_id']?.toString();
      if (storeId == null) throw Exception('Không tìm thấy store_id.');
      final rows = await Supabase.instance.client
          .from('store_members')
          .select('user_id, role, user_accounts(display_name)')
          .eq('store_id', storeId)
          .neq('role', 'owner');
      final List<dynamic> rowsList = rows;
      final opts = rowsList.map((r) {
        final ua = r['user_accounts'] as Map?;
        final rawRole = r['role'] as String? ?? '';
        return _StaffOption(
          id: r['user_id'] as String,
          name: ua?['display_name'] as String? ?? 'Không tên',
          role: _resolveRoleLabel(rawRole),
        );
      }).toList();
      opts.sort((a, b) => a.name.compareTo(b.name));
      if (mounted) {
        setState(() {
          _staffOptions = opts;
          if (_selectedStaff != null) {
            final matched = opts
                .where((o) => o.id == _selectedStaff!.id)
                .firstOrNull;
            if (matched != null) {
              _selectedStaff = matched;
              _roleCtrl.text = matched.role;
            } else {
              _roleCtrl.text = _resolveRoleLabel(_selectedStaff!.role);
            }
          }
        });
      }
    } catch (e) {
      debugPrint('[SalaryConfig] _loadStaffList error: $e');
      if (mounted) {
        setState(() => _staffListError = 'Không thể tải danh sách nhân viên.');
      }
    } finally {
      if (mounted) {
        setState(() => _loadingStaff = false);
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _roleCtrl,
      _baseCtrl,
      _hourlyCtrl,
      _dailyCtrl,
      _daysCtrl,
      _latePenaltyCtrl,
      _otThreshCtrl,
      _otMultiplierCtrl,
    ]) {
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
      builder: (_, ctrl) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: ListView(
              controller: ctrl,
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                40 + MediaQuery.of(context).viewInsets.bottom,
              ),
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing == null
                      ? 'Thêm cấu hình lương'
                      : 'Chỉnh cấu hình lương',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C2151),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Chọn nhân viên (dropdown) ───
                _Section('Nhân viên'),
                const SizedBox(height: 8),
                if (widget.existing != null)
                  _Field(
                    ctrl: TextEditingController(
                      text: widget.existing!.staffName,
                    ),
                    label: 'Nhân viên',
                    readOnly: true,
                  )
                else if (_loadingStaff)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_staffListError != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _staffListError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton(
                          onPressed: _loadStaffList,
                          child: const Text('Thử lại'),
                        ),
                      ),
                    ],
                  )
                else if (_staffOptions.isEmpty)
                  const Text(
                    'Không có nhân viên nào chưa được cấu hình.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Chọn nhân viên',
                      border: OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: Icon(Icons.person_outline),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<_StaffOption>(
                        value:
                            _staffOptions.any((o) => o.id == _selectedStaff?.id)
                            ? _staffOptions.firstWhere(
                                (o) => o.id == _selectedStaff!.id,
                              )
                            : null,
                        hint: const Text('Chọn nhân viên từ danh sách'),
                        isExpanded: true,
                        isDense: true,
                        items: _staffOptions
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(
                                  s.role.isEmpty
                                      ? s.name
                                      : '${s.name}  ·  ${s.role}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )
                            .toList(),
                        selectedItemBuilder: (_) => _staffOptions
                            .map(
                              (s) => Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  s.role.isEmpty
                                      ? s.name
                                      : '${s.name}  ·  ${s.role}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (s) => setState(() {
                          _selectedStaff = s;
                          if (s != null) {
                            _roleCtrl.text = s.role;
                          }
                        }),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                _Field(
                  ctrl: _roleCtrl,
                  label: 'Vai trò / Chức danh (Tự động từ Module Nhân viên)',
                  hint: 'Lấy từ Module Nhân viên',
                  readOnly: true,
                ),
                const SizedBox(height: 20),

                // ─── Chế độ lương ───
                _Section('Chế độ lương'),
                const SizedBox(height: 10),
                ..._modes.map(
                  (m) => _ModeRadio(
                    value: m.$1,
                    label: m.$2,
                    desc: m.$3,
                    groupValue: _mode,
                    onChanged: (v) => setState(() => _mode = v!),
                  ),
                ),
                const SizedBox(height: 20),

                // ─── Mức lương theo mode ───
                _Section('Mức lương'),
                const SizedBox(height: 10),

                if (_mode == 'M1' || _mode == 'M3') ...[
                  _MoneyField(
                    ctrl: _hourlyCtrl,
                    label: 'Đơn giá giờ thường (đ/giờ)',
                  ),
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
                _MoneyField(
                  ctrl: _latePenaltyCtrl,
                  label: 'Khấu trừ đi muộn (đ/lần)',
                  hint: '50000',
                ),
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Lưu cấu hình',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final staff = _selectedStaff;
    if (staff == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng chọn nhân viên')));
      return;
    }

    final double base = double.tryParse(_baseCtrl.text) ?? 0;
    final double hourly = double.tryParse(_hourlyCtrl.text) ?? 0;
    final double daily = double.tryParse(_dailyCtrl.text) ?? 0;
    final int days = int.tryParse(_daysCtrl.text) ?? 0;
    final double latePenalty = double.tryParse(_latePenaltyCtrl.text) ?? -1;
    final double otThresh = double.tryParse(_otThreshCtrl.text) ?? 0;
    final double otMul = double.tryParse(_otMultiplierCtrl.text) ?? 0;

    if (_mode == 'M1' && hourly <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập đơn giá giờ hợp lệ (>0).')),
      );
      return;
    }
    if (_mode == 'M2' && base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập lương cơ bản hợp lệ (>0).'),
        ),
      );
      return;
    }
    if (_mode == 'M3' && (base <= 0 || hourly <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng nhập lương cơ bản và đơn giá giờ hợp lệ (>0).',
          ),
        ),
      );
      return;
    }
    if (_mode == 'M4' && daily <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập đơn giá ngày hợp lệ (>0).'),
        ),
      );
      return;
    }
    if (days < 1 || days > 31) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số ngày làm chuẩn phải từ 1 đến 31.')),
      );
      return;
    }
    if (latePenalty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Khấu trừ đi muộn phải >= 0.')),
      );
      return;
    }
    if (otThresh <= 0 || otThresh > 24) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ngưỡng OT phải > 0 và <= 24.')),
      );
      return;
    }
    if (otMul < 1 || otMul > 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hệ số OT phải từ 1 đến 10.')),
      );
      return;
    }

    final permsAsync = ref.read(userActionPermsProvider);
    final canManage = permsAsync.maybeWhen(
      data: (d) => d.contains('tinhluong.manage_config'),
      orElse: () => false,
    );
    if (!canManage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Bạn không có quyền quản lý cấu hình lương.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final finalRole = _roleCtrl.text.trim().isNotEmpty
          ? _roleCtrl.text.trim()
          : _resolveRoleLabel(staff.role);

      await StaffSalaryConfigRepo.upsert(
        userId: staff.id,
        staffName: staff.name,
        role: finalRole,
        salaryMode: _mode,
        baseSalary: base,
        hourlyRate: hourly,
        dailyRate: daily,
        expectedDays: days,
        deductionPerLate: latePenalty,
        otThresholdHours: otThresh,
        otMultiplier: otMul,
      );
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu cấu hình lương ✅')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu cấu hình. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String text;
  const _Section(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Color(0xFF1C2151),
    ),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? hint;
  final bool readOnly;

  const _Field({
    required this.ctrl,
    required this.label,
    this.hint,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    readOnly: readOnly,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
      isDense: true,
      filled: readOnly,
      fillColor: readOnly ? const Color(0xFFF3F4F6) : null,
      suffixIcon: readOnly
          ? const Icon(Icons.lock_rounded, size: 18, color: Colors.grey)
          : null,
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
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? const Color(0xFF1C2151) : Colors.grey.shade400,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '[$value] $label',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
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
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          height: 44,
          child: ElevatedButton(
            onPressed: onRetry,
            child: const Text('Thử lại'),
          ),
        ),
      ],
    ),
  );
}

/// Data class đại diện 1 NV trong dropdown picker
class _StaffOption {
  final String id;
  final String name;
  final String role;
  const _StaffOption({
    required this.id,
    required this.name,
    required this.role,
  });

  @override
  bool operator ==(Object other) => other is _StaffOption && other.id == id;
  @override
  int get hashCode => id.hashCode;
}
