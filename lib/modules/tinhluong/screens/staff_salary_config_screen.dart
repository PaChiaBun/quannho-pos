// lib/modules/tinhluong/screens/staff_salary_config_screen.dart
// Màn hình cấu hình lương từng nhân viên
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/services/staff_service.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/providers/session_provider.dart';

import '../repository/staff_salary_config_repository.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final staffSalaryConfigsProvider =
    FutureProvider.autoDispose<List<StaffSalaryConfig>>((ref) {
      return StaffSalaryConfigRepo.fetchAll();
    });

class _SalaryRosterItem {
  final StaffMember staff;
  final StaffSalaryConfig? config;

  const _SalaryRosterItem({required this.staff, required this.config});
}

final _salaryRosterProvider =
    FutureProvider.autoDispose<List<_SalaryRosterItem>>((ref) async {
      final storeId = ref.watch(sessionProvider)?.storeId;
      if (storeId == null || storeId.isEmpty) {
        throw StateError('Không xác định được cửa hàng hiện tại.');
      }
      final results = await Future.wait([
        StaffService.getStaffList(storeId),
        ref.watch(staffSalaryConfigsProvider.future),
      ]);
      final staff = results[0] as List<StaffMember>;
      final configs = results[1] as List<StaffSalaryConfig>;
      final configByUser = {
        for (final config in configs) config.userId: config,
      };
      return staff
          .map(
            (member) => _SalaryRosterItem(
              staff: member,
              config: configByUser[member.userId],
            ),
          )
          .toList();
    });

// ─── Screen ──────────────────────────────────────────────────────────────────

class StaffSalaryConfigScreen extends ConsumerStatefulWidget {
  const StaffSalaryConfigScreen({super.key});

  @override
  ConsumerState<StaffSalaryConfigScreen> createState() =>
      _StaffSalaryConfigScreenState();
}

class _StaffSalaryConfigScreenState
    extends ConsumerState<StaffSalaryConfigScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
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

        final async = ref.watch(_salaryRosterProvider);

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
                  'Thiết lập chính sách & chế độ lương',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () {
                  ref.invalidate(staffSalaryConfigsProvider);
                  ref.invalidate(_salaryRosterProvider);
                },
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
                data: (items) => _buildBody(context, items),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, List<_SalaryRosterItem> items) {
    final configured = items.where((item) => item.config != null).length;
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Trung tâm chính sách lương',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1C2151),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Thiết lập chung theo vị trí trước, tinh chỉnh riêng cho từng nhân viên sau.',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  _CoverageBadge(configured: configured, total: items.length),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.groups_outlined),
                      label: Text('Theo vị trí'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.person_outline),
                      label: Text('Theo nhân viên'),
                    ),
                  ],
                  selected: {_tabIndex},
                  onSelectionChanged: (value) =>
                      setState(() => _tabIndex = value.first),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE8E5F0)),
        Expanded(
          child: items.isEmpty
              ? const _EmptyRosterView()
              : _tabIndex == 0
              ? _PolicyTabView(items: items)
              : _EmployeeTabView(
                  items: items,
                  onEdit: (item) => _showEditSheet(
                    context,
                    existing: item.config,
                    initialStaff: item.staff,
                  ),
                ),
        ),
      ],
    );
  }

  void _showEditSheet(
    BuildContext context, {
    required StaffSalaryConfig? existing,
    StaffMember? initialStaff,
  }) {
    final sheet = _EditSheet(
      existing: existing,
      initialStaff: initialStaff,
      onSaved: () {
        ref.invalidate(staffSalaryConfigsProvider);
        ref.invalidate(_salaryRosterProvider);
      },
    );
    _showResponsiveEditor(context, sheet, width: 560);
  }
}

void _showResponsiveEditor(
  BuildContext context,
  Widget child, {
  required double width,
}) {
  if (MediaQuery.sizeOf(context).width >= 700) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, animation, secondaryAnimation) => Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: Colors.transparent,
          child: SizedBox(width: width, height: double.infinity, child: child),
        ),
      ),
      transitionBuilder: (_, animation, secondaryAnimation, dialog) =>
          SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: dialog,
          ),
    );
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => child,
  );
}

String _roleLabel(String role) {
  switch (role.trim().toLowerCase()) {
    case 'owner':
      return 'Chủ quán';
    case 'manager':
      return 'Quản lý';
    case 'cashier':
      return 'Thu ngân';
    case 'waiter':
      return 'Phục vụ';
    case 'kitchen':
      return 'Bếp';
    case 'stock':
      return 'Kho';
    default:
      return role.trim().isEmpty ? 'Chưa có vị trí' : role.trim();
  }
}

String _modeLabel(String mode) {
  switch (mode) {
    case 'M1':
      return 'Theo giờ';
    case 'M2':
      return 'Cố định';
    case 'M3':
      return 'Cố định + OT';
    case 'M4':
      return 'Theo ngày';
    case 'M5':
      return 'Tùy chỉnh';
    default:
      return mode;
  }
}

class _CoverageBadge extends StatelessWidget {
  final int configured;
  final int total;

  const _CoverageBadge({required this.configured, required this.total});

  @override
  Widget build(BuildContext context) {
    final complete = total > 0 && configured == total;
    final color = complete ? const Color(0xFF0F9D69) : const Color(0xFFF59E0B);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$configured/$total',
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text('đã cấu hình', style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}

class _EmptyRosterView extends StatelessWidget {
  const _EmptyRosterView();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'Chưa có nhân viên để thiết lập lương',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C2151),
            ),
          ),
        ],
      ),
    ),
  );
}

class _EmployeeTabView extends StatefulWidget {
  final List<_SalaryRosterItem> items;
  final ValueChanged<_SalaryRosterItem> onEdit;

  const _EmployeeTabView({required this.items, required this.onEdit});

  @override
  State<_EmployeeTabView> createState() => _EmployeeTabViewState();
}

class _EmployeeTabViewState extends State<_EmployeeTabView> {
  final _search = TextEditingController();
  bool? _configured;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final items = widget.items.where((item) {
      if (_configured != null && (item.config != null) != _configured) {
        return false;
      }
      return query.isEmpty ||
          item.staff.name.toLowerCase().contains(query) ||
          _roleLabel(item.staff.role).toLowerCase().contains(query) ||
          item.staff.phone.contains(query);
    }).toList()..sort((a, b) => a.staff.name.compareTo(b.staff.name));

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Tìm tên, vị trí hoặc số điện thoại',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text('Tất cả (${widget.items.length})'),
                      selected: _configured == null,
                      onSelected: (_) => setState(() => _configured = null),
                    ),
                    ChoiceChip(
                      label: Text(
                        'Đã cấu hình (${widget.items.where((i) => i.config != null).length})',
                      ),
                      selected: _configured == true,
                      onSelected: (_) => setState(() => _configured = true),
                    ),
                    ChoiceChip(
                      label: Text(
                        'Chưa cấu hình (${widget.items.where((i) => i.config == null).length})',
                      ),
                      selected: _configured == false,
                      onSelected: (_) => setState(() => _configured = false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  mainAxisExtent: 142,
                ),
                itemCount: items.length,
                itemBuilder: (_, index) {
                  final item = items[index];
                  final config = item.config;
                  return Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => widget.onEdit(item),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: config == null
                                ? const Color(0xFFFFD89A)
                                : const Color(0xFFDDE2F3),
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: const Color(0xFFFFF0DA),
                              child: Text(
                                item.staff.name.isEmpty
                                    ? '?'
                                    : item.staff.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFF28C00),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.staff.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1C2151),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    _roleLabel(item.staff.role),
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    config == null
                                        ? 'Chạm để thiết lập mức lương'
                                        : '${_modeLabel(config.salaryMode)} · Chạm để chỉnh sửa',
                                    style: TextStyle(
                                      color: config == null
                                          ? const Color(0xFFF28C00)
                                          : const Color(0xFF0F9D69),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PolicyTabView extends StatelessWidget {
  final List<_SalaryRosterItem> items;

  const _PolicyTabView({required this.items});

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<_SalaryRosterItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.staff.role, () => []).add(item);
    }
    final roles = grouped.keys.toList()
      ..sort((a, b) => _roleLabel(a).compareTo(_roleLabel(b)));

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 224,
          ),
          itemCount: roles.length,
          itemBuilder: (_, index) {
            final role = roles[index];
            return _PolicyCard(rawRole: role, items: grouped[role]!);
          },
        );
      },
    );
  }
}

class _PolicyCard extends ConsumerWidget {
  final String rawRole;
  final List<_SalaryRosterItem> items;

  const _PolicyCard({required this.rawRole, required this.items});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configs = items
        .map((item) => item.config)
        .whereType<StaffSalaryConfig>()
        .toList();
    final status = determinePolicyStatus(configs, items.length);
    final (label, color) = switch (status) {
      PolicyStatus.synchronized => ('Đồng bộ', const Color(0xFF0F9D69)),
      PolicyStatus.mixed => ('Nhiều thiết lập', const Color(0xFFF59E0B)),
      PolicyStatus.unconfigured => ('Chưa thiết lập', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E5EF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C2151).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _roleLabel(rawRole),
                  style: const TextStyle(
                    color: Color(0xFF1C2151),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${items.length} nhân viên · ${configs.length} đã cấu hình / ${items.length - configs.length} chưa cấu hình',
            style: TextStyle(color: Colors.grey[600], height: 1.4),
          ),
          const Spacer(),
          Text(
            status == PolicyStatus.synchronized && configs.isNotEmpty
                ? 'Cách tính: ${_modeLabel(configs.first.salaryMode)}'
                : status == PolicyStatus.mixed
                ? 'Các nhân viên đang dùng nhiều cách tính khác nhau.'
                : 'Chưa có cách tính, OT, thưởng hoặc khấu trừ.',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Thiết lập chính sách'),
              onPressed: () => _showResponsiveEditor(
                context,
                _PolicyEditor(
                  rawRole: rawRole,
                  items: items,
                  onSaved: () {
                    ref.invalidate(staffSalaryConfigsProvider);
                    ref.invalidate(_salaryRosterProvider);
                  },
                ),
                width: 620,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicyEditor extends StatefulWidget {
  final String rawRole;
  final List<_SalaryRosterItem> items;
  final VoidCallback onSaved;

  const _PolicyEditor({
    required this.rawRole,
    required this.items,
    required this.onSaved,
  });

  @override
  State<_PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends State<_PolicyEditor> {
  late final TextEditingController _base;
  late final TextEditingController _hourly;
  late final TextEditingController _daily;
  late final TextEditingController _days;
  late final TextEditingController _otThreshold;
  late final TextEditingController _otMultiplier;
  late final TextEditingController _fixedBonus;
  late final TextEditingController _attendanceBonus;
  late final TextEditingController _allowance;
  late final TextEditingController _latePenalty;

  String _mode = 'M1';
  PolicyApplyScope _scope = PolicyApplyScope.unconfiguredOnly;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final configs = widget.items
        .map((item) => item.config)
        .whereType<StaffSalaryConfig>()
        .toList();
    final seed = configs.isEmpty ? null : configs.first;
    _mode = seed?.salaryMode ?? 'M1';
    _base = _controller(seed?.baseSalary ?? 0);
    _hourly = _controller(seed?.hourlyRate ?? 25000);
    _daily = _controller(seed?.dailyRate ?? 0);
    _days = TextEditingController(text: '${seed?.expectedDays ?? 26}');
    _otThreshold = TextEditingController(
      text: '${seed?.otThresholdHours ?? 8}',
    );
    _otMultiplier = TextEditingController(text: '${seed?.otMultiplier ?? 1.5}');
    _fixedBonus = _controller(seed?.fixedBonus ?? 0);
    _attendanceBonus = _controller(seed?.attendanceBonus ?? 0);
    _allowance = _controller(seed?.fixedAllowance ?? 0);
    _latePenalty = _controller(seed?.deductionPerLate ?? 50000);
  }

  TextEditingController _controller(double value) =>
      TextEditingController(text: value.round().toString());

  double _number(TextEditingController controller) =>
      double.tryParse(controller.text.trim()) ?? 0;

  @override
  void dispose() {
    for (final controller in [
      _base,
      _hourly,
      _daily,
      _days,
      _otThreshold,
      _otMultiplier,
      _fixedBonus,
      _attendanceBonus,
      _allowance,
      _latePenalty,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final base = _number(_base);
    final hourly = _number(_hourly);
    final daily = _number(_daily);
    final expectedDays = int.tryParse(_days.text.trim()) ?? 0;
    final otThreshold = _number(_otThreshold);
    final otMultiplier = _number(_otMultiplier);
    final latePenalty = _number(_latePenalty);

    final missingSalary = switch (_mode) {
      'M1' => hourly <= 0,
      'M2' => base <= 0,
      'M3' => base <= 0 || hourly <= 0,
      'M4' => daily <= 0,
      'M5' => base <= 0 && hourly <= 0 && daily <= 0,
      _ => true,
    };
    if (missingSalary ||
        expectedDays < 1 ||
        expectedDays > 31 ||
        otThreshold <= 0 ||
        otThreshold > 24 ||
        otMultiplier < 1 ||
        otMultiplier > 10 ||
        latePenalty < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Hãy kiểm tra mức lương, ngày công, ngưỡng OT, hệ số OT và khấu trừ.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final targets = selectPolicyTargets(
      items: widget.items,
      isConfigured: (item) => item.config != null,
      scope: _scope,
    );
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có nhân viên nào cần áp dụng.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await StaffSalaryConfigRepo.upsertMany(
        configs: targets
            .map(
              (item) => StaffSalaryConfig(
                id: item.config?.id ?? '',
                storeId: item.config?.storeId ?? '',
                userId: item.staff.userId,
                staffName: item.staff.name,
                role: widget.rawRole,
                salaryMode: _mode,
                baseSalary: base,
                hourlyRate: hourly,
                dailyRate: daily,
                expectedDays: expectedDays,
                deductionPerLate: latePenalty,
                otThresholdHours: otThreshold,
                otMultiplier: otMultiplier,
                fixedBonus: _number(_fixedBonus),
                attendanceBonus: _number(_attendanceBonus),
                fixedAllowance: _number(_allowance),
              ),
            )
            .toList(),
        roleName: widget.rawRole,
        scope: _scope.name,
      );
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Đã áp dụng chính sách cho ${targets.length} nhân viên.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể lưu chính sách. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unconfigured = widget.items
        .where((item) => item.config == null)
        .length;
    return Material(
      color: const Color(0xFFF7F7FA),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(22, 16, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chính sách · ${_roleLabel(widget.rawRole)}',
                          style: const TextStyle(
                            color: Color(0xFF1C2151),
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        const Text(
                          'Một thiết lập rõ ràng cho những người cùng vị trí',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _EditorSection(
                    title: '1. Phạm vi áp dụng',
                    description:
                        'Mặc định chỉ bổ sung người chưa có cấu hình, không đụng vào thiết lập riêng.',
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<PolicyApplyScope>(
                            segments: [
                              ButtonSegment(
                                value: PolicyApplyScope.unconfiguredOnly,
                                label: Text('Chưa cấu hình ($unconfigured)'),
                              ),
                              ButtonSegment(
                                value: PolicyApplyScope.all,
                                label: Text('Tất cả (${widget.items.length})'),
                              ),
                            ],
                            selected: {_scope},
                            onSelectionChanged: (value) =>
                                setState(() => _scope = value.first),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _scope == PolicyApplyScope.all
                                ? '⚠ Sẽ ghi đè các thiết lập riêng đang có.'
                                : '✓ An toàn — giữ nguyên các thiết lập riêng.',
                            style: TextStyle(
                              color: _scope == PolicyApplyScope.all
                                  ? Colors.red
                                  : const Color(0xFF0F9D69),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EditorSection(
                    title: '2. Cách tính thu nhập chính',
                    description:
                        'Chọn mẫu gần nhất. “Tùy chỉnh” cho phép kết hợp nhiều thành phần.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['M1', 'M2', 'M3', 'M4', 'M5']
                              .map(
                                (mode) => ChoiceChip(
                                  label: Text('$mode · ${_modeLabel(mode)}'),
                                  selected: _mode == mode,
                                  onSelected: (_) =>
                                      setState(() => _mode = mode),
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        if (_mode == 'M2' ||
                            _mode == 'M3' ||
                            _mode == 'M5') ...[
                          _MoneyField(
                            ctrl: _base,
                            label: 'Lương cố định mỗi tháng (đ)',
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_mode == 'M1' ||
                            _mode == 'M3' ||
                            _mode == 'M5') ...[
                          _MoneyField(
                            ctrl: _hourly,
                            label: 'Đơn giá giờ thường (đ/giờ)',
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (_mode == 'M4' || _mode == 'M5') ...[
                          _MoneyField(
                            ctrl: _daily,
                            label: 'Đơn giá ngày (đ/ngày)',
                          ),
                          const SizedBox(height: 10),
                        ],
                        _MoneyField(
                          ctrl: _days,
                          label: 'Số ngày công chuẩn trong kỳ',
                          isInteger: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EditorSection(
                    title: '3. Tăng ca (OT)',
                    description:
                        'OT bắt đầu sau ngưỡng giờ của một ca và được nhân theo hệ số.',
                    child: Column(
                      children: [
                        _MoneyField(
                          ctrl: _otThreshold,
                          label: 'Ngưỡng bắt đầu OT (giờ/ca)',
                          isDecimal: true,
                        ),
                        const SizedBox(height: 10),
                        _MoneyField(
                          ctrl: _otMultiplier,
                          label: 'Hệ số OT (ví dụ 1.5)',
                          isDecimal: true,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EditorSection(
                    title: '4. Thưởng & phụ cấp',
                    description:
                        'Để 0 nếu không dùng. Các khoản này cộng một lần trong mỗi kỳ lương.',
                    child: Column(
                      children: [
                        _MoneyField(
                          ctrl: _fixedBonus,
                          label: 'Thưởng cố định mỗi kỳ (đ)',
                        ),
                        const SizedBox(height: 10),
                        _MoneyField(
                          ctrl: _attendanceBonus,
                          label: 'Thưởng đủ ngày công (đ)',
                        ),
                        const SizedBox(height: 10),
                        _MoneyField(
                          ctrl: _allowance,
                          label: 'Phụ cấp cố định mỗi kỳ (đ)',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _EditorSection(
                    title: '5. Khấu trừ',
                    description:
                        'Khoản trừ cho mỗi lần đi muộn đã được xác nhận.',
                    child: _MoneyField(
                      ctrl: _latePenalty,
                      label: 'Khấu trừ đi muộn (đ/lần)',
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(18),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(
                    _scope == PolicyApplyScope.all
                        ? 'Ghi đè & áp dụng cho tất cả'
                        : 'Áp dụng cho người chưa cấu hình',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C2151),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorSection extends StatelessWidget {
  final String title;
  final String description;
  final Widget child;

  const _EditorSection({
    required this.title,
    required this.description,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE3E5EF)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1C2151),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(color: Colors.grey[600], fontSize: 12, height: 1.4),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

// ─── Config Card ─────────────────────────────────────────────────────────────

// Kept temporarily as a compatibility renderer for older deep links.
// ignore: unused_element
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
  final StaffMember? initialStaff;
  final VoidCallback onSaved;
  const _EditSheet({this.existing, this.initialStaff, required this.onSaved});

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
  final _fixedBonusCtrl = TextEditingController();
  final _attendanceBonusCtrl = TextEditingController();
  final _fixedAllowanceCtrl = TextEditingController();

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
    (
      'M5',
      'Tùy chỉnh',
      'Tự kết hợp lương nền, đơn giá giờ, đơn giá ngày và OT',
    ),
  ];

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
      _fixedBonusCtrl.text = e.fixedBonus.round().toString();
      _attendanceBonusCtrl.text = e.attendanceBonus.round().toString();
      _fixedAllowanceCtrl.text = e.fixedAllowance.round().toString();
    } else if (widget.initialStaff != null) {
      final staff = widget.initialStaff!;
      _selectedStaff = _StaffOption(
        id: staff.userId,
        name: staff.name,
        role: staff.role,
      );
      _roleCtrl.text = staff.role;
    }
    if (_daysCtrl.text.isEmpty) {
      _daysCtrl.text = '26';
    }
    if (_latePenaltyCtrl.text.isEmpty) {
      _latePenaltyCtrl.text = '50000';
    }
    if (_otThreshCtrl.text.isEmpty) {
      _otThreshCtrl.text = '8.0';
    }
    if (_hourlyCtrl.text.isEmpty) {
      _hourlyCtrl.text = '25000';
    }
    if (_otMultiplierCtrl.text.isEmpty) {
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
          role: rawRole,
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
              _roleCtrl.text = _selectedStaff!.role;
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
      _fixedBonusCtrl,
      _attendanceBonusCtrl,
      _fixedAllowanceCtrl,
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
                                      : '${s.name}  ·  ${_roleLabel(s.role)}',
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
                                      : '${s.name}  ·  ${_roleLabel(s.role)}',
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

                if (_mode == 'M1' || _mode == 'M3' || _mode == 'M5') ...[
                  _MoneyField(
                    ctrl: _hourlyCtrl,
                    label: 'Đơn giá giờ thường (đ/giờ)',
                  ),
                  const SizedBox(height: 10),
                ],
                if (_mode == 'M2' || _mode == 'M3' || _mode == 'M5') ...[
                  _MoneyField(ctrl: _baseCtrl, label: 'Lương cơ bản (đ/tháng)'),
                  const SizedBox(height: 10),
                ],
                if (_mode == 'M4' || _mode == 'M5') ...[
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

                _Section('Thưởng & phụ cấp'),
                const SizedBox(height: 6),
                Text(
                  'Không áp dụng mục nào thì để 0. Các khoản này được cộng một lần cho mỗi kỳ lương.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 10),
                _MoneyField(
                  ctrl: _fixedBonusCtrl,
                  label: 'Thưởng cố định mỗi kỳ (đ)',
                ),
                const SizedBox(height: 10),
                _MoneyField(
                  ctrl: _attendanceBonusCtrl,
                  label: 'Thưởng đủ ngày công (đ)',
                ),
                const SizedBox(height: 10),
                _MoneyField(
                  ctrl: _fixedAllowanceCtrl,
                  label: 'Phụ cấp cố định mỗi kỳ (đ)',
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
    final double fixedBonus = double.tryParse(_fixedBonusCtrl.text) ?? 0;
    final double attendanceBonus =
        double.tryParse(_attendanceBonusCtrl.text) ?? 0;
    final double fixedAllowance =
        double.tryParse(_fixedAllowanceCtrl.text) ?? 0;

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
    if (_mode == 'M5' && base <= 0 && hourly <= 0 && daily <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Tùy chỉnh cần ít nhất một thành phần lương lớn hơn 0.',
          ),
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
      final finalRole = staff.role.trim();

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
        fixedBonus: fixedBonus,
        attendanceBonus: attendanceBonus,
        fixedAllowance: fixedAllowance,
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
