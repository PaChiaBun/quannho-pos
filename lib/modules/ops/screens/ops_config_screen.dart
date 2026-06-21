import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../providers/ops_providers.dart';
import '../repository/ops_repository.dart';
import '../../../core/services/drive_service.dart';
import '../../../core/services/staff_service.dart' show ShiftConfig, ShiftConfigService, StaffMember, StaffService;
import '../../../core/providers/session_provider.dart';

const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kMuted  = Color(0xFF9E9085);

// ── Role presets cho tab "Bộ Mẫu" ────────────────────────────────────────────
const _kPresets = <_PresetPack>[
  _PresetPack(role: 'Tạp vụ',      icon: Icons.cleaning_services_rounded,  desc: '8 việc • Vệ sinh, dọn dẹp, đổ rác theo ca',             color: Color(0xFF0EA5E9)),
  _PresetPack(role: 'Thu ngân',    icon: Icons.point_of_sale_rounded,       desc: '6 việc • POS, quỹ tiền, chốt ca, báo cáo',              color: Color(0xFF10B981)),
  _PresetPack(role: 'Phục vụ',     icon: Icons.table_restaurant_rounded,   desc: '7 việc • Setup bàn, dụng cụ, điều hòa, cao điểm',       color: Color(0xFFFF6B35)),
  _PresetPack(role: 'Bếp',         icon: Icons.soup_kitchen_rounded,       desc: '8 việc • Nguyên liệu, gas, bảo quản, vệ sinh bếp',      color: Color(0xFFEF4444)),
  _PresetPack(role: 'Bar / Pha chế', icon: Icons.local_cafe_rounded,       desc: '6 việc • Máy espresso, nguyên liệu, vệ sinh quầy bar',  color: Color(0xFFF59E0B)),
  _PresetPack(role: 'Quản lý ca',  icon: Icons.manage_accounts_rounded,    desc: '5 việc • Mở ca, giao ca, kiểm tra, tổng kết',           color: Color(0xFF6366F1)),
  _PresetPack(role: 'Bảo vệ',      icon: Icons.security_rounded,           desc: '6 việc • Camera, PCCC, tuần tra, chốt cửa',             color: Color(0xFF8B5CF6)),
  _PresetPack(role: 'Lễ tân',      icon: Icons.person_pin_rounded,         desc: '4 việc • Đón khách, sơ đồ bàn, danh sách chờ',         color: Color(0xFFEC4899)),
  _PresetPack(role: 'Phụ bếp',     icon: Icons.kitchen_rounded,            desc: '4 việc • Sơ chế, rửa dụng cụ, bổ sung nguyên liệu',   color: Color(0xFFD97706)),
  _PresetPack(role: 'Rửa bát',     icon: Icons.wash_rounded,               desc: '3 việc • Máy rửa, phân loại, sắp xếp chén ly',         color: Color(0xFF14B8A6)),
  _PresetPack(role: 'Shipper',     icon: Icons.delivery_dining_rounded,    desc: '4 việc • Kiểm tra xe, đóng gói, giao hàng, COD',       color: Color(0xFF0891B2)),
  _PresetPack(role: 'Thủ kho',     icon: Icons.inventory_2_rounded,        desc: '4 việc • Hàng nhập, FIFO, hạn sử dụng, tồn kho',      color: Color(0xFF059669)),
  _PresetPack(role: 'Takeaway',    icon: Icons.takeout_dining_rounded,     desc: '4 việc • Quầy take-away, Grab/Shopee, bao bì',         color: Color(0xFFC026D3)),
  _PresetPack(role: 'Chạy bàn',    icon: Icons.run_circle_rounded,         desc: '3 việc • Lấy món, thu dọn, bổ sung nước/đá',          color: Color(0xFF7C3AED)),
  _PresetPack(role: 'Dọn bàn',     icon: Icons.table_bar_rounded,          desc: '3 việc • Reset bàn, phân loại rác, bổ sung dụng cụ',  color: Color(0xFF64748B)),
  _PresetPack(role: 'Trưởng nhóm', icon: Icons.groups_rounded,             desc: '4 việc • Briefing, đồng phục, VIP, đánh giá hiệu suất', color: Color(0xFF1D4ED8)),
  _PresetPack(role: 'Đặt bàn',     icon: Icons.event_seat_rounded,         desc: '3 việc • Nhận đặt, nhắc lịch, cập nhật sơ đồ',        color: Color(0xFF65A30D)),
  _PresetPack(role: 'Content',     icon: Icons.photo_camera_rounded,       desc: '3 việc • Chụp ảnh, đăng story/post, reply inbox',      color: Color(0xFFDB2777)),
  _PresetPack(role: 'Kỹ thuật',    icon: Icons.build_rounded,              desc: '3 việc • Thiết bị điện lạnh, bảo dưỡng, ghi log hỏng', color: Color(0xFF374151)),
];

class _PresetPack {
  final String role, desc;
  final IconData icon;
  final Color color;
  const _PresetPack({required this.role, required this.icon, required this.desc, required this.color});
}

// ── Main Screen ───────────────────────────────────────────────────────────────
class OpsConfigScreen extends ConsumerStatefulWidget {
  const OpsConfigScreen({super.key});
  @override
  ConsumerState<OpsConfigScreen> createState() => _OpsConfigScreenState();
}

class _OpsConfigScreenState extends ConsumerState<OpsConfigScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // Cleanup ảnh cũ > 90 ngày — chạy silent, không block UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(sessionProvider);
      final storeId = session?.storeId ?? '';
      // Supabase fallback
      ref.read(opsRepositoryProvider).cleanupOldProofPhotos();
      // Google Drive
      if (storeId.isNotEmpty) {
        DriveService.cleanupOldDrivePhotos(
          storeId: storeId,
          retentionDays: 90,
        );
      }
    });
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  void _openForm({OpsTaskTemplateModel? template}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateFormSheet(
        initial: template,
        onSave: (t) async {
          await ref.read(opsRepositoryProvider).upsertTemplate(t);
          ref.invalidate(opsTemplatesProvider);
        },
      ),
    );
  }

  Future<void> _delete(OpsTaskTemplateModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Xoá công việc?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: _kNavy)),
        content: Text('Xoá "${t.title}"?\nNhật ký cũ sẽ không bị ảnh hưởng.', style: GoogleFonts.outfit(color: _kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Huỷ', style: GoogleFonts.outfit(color: _kMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Xoá', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(opsRepositoryProvider).deleteTemplate(t.id);
      ref.invalidate(opsTemplatesProvider);
    }
  }

  Future<void> _deleteAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Xoá toàn bộ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: const Color(0xFFEF4444))),
        content: Text('Toàn bộ mẫu công việc sẽ bị xoá.\nHành động này không thể hoàn tác.', style: GoogleFonts.outfit(color: _kMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Huỷ', style: GoogleFonts.outfit(color: _kMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: Text('Xoá tất cả', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(opsRepositoryProvider).deleteAllTemplates();
      ref.invalidate(opsTemplatesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Đã xoá toàn bộ mẫu công việc'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<void> _seedRole(String role) async {
    try {
      final count = await ref.read(opsRepositoryProvider).seedKayByRole(role);
      ref.invalidate(opsTemplatesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Nạp $count việc cho "$role" thành công'),
          backgroundColor: _kNavy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Column(
        children: [
          // ── TabBar ─────────────────────────────────────────────────────────
          Container(
            color: const Color(0xFFFFF8F0),
            child: TabBar(
              controller: _tab,
              labelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800),
              unselectedLabelStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w500),
              labelColor: _kNavy,
              unselectedLabelColor: _kMuted,
              indicatorColor: _kNavy,
              indicatorWeight: 2.5,
              tabs: const [
                Tab(text: 'Danh Sách'),
                Tab(text: 'Bộ Mẫu'),
                Tab(text: 'Phân Quyền'),
              ],
            ),
          ),

          // ── Tab content ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _ListTab(onEdit: _openForm, onDelete: _delete, onDeleteAll: _deleteAll),
                _PresetsTab(onSeed: _seedRole),
                _PermissionTab(onEdit: _openForm),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tab,
        builder: (_, __) => _tab.index == 0
            ? FloatingActionButton.extended(
                onPressed: () => _openForm(),
                backgroundColor: _kNavy,
                elevation: 4,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text('Thêm', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

// ── Tab 1: Danh Sách ──────────────────────────────────────────────────────────
class _ListTab extends ConsumerWidget {
  final void Function({OpsTaskTemplateModel? template}) onEdit;
  final Future<void> Function(OpsTaskTemplateModel) onDelete;
  final Future<void> Function() onDeleteAll;
  const _ListTab({required this.onEdit, required this.onDelete, required this.onDeleteAll});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmplAsync  = ref.watch(opsTemplatesProvider);
    final rolesAsync = ref.watch(opsStoreRolesProvider);

    return tmplAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (templates) {
        if (templates.isEmpty) {
          return _EmptyList(onAdd: () => onEdit());
        }

        final grouped = <String, List<OpsTaskTemplateModel>>{};
        for (final t in templates) {
          grouped.putIfAbsent(t.roleName ?? 'Tất cả', () => []).add(t);
        }
        final sortedKeys = grouped.keys.toList()..sort();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Action bar
            Row(
              children: [
                Text('${templates.length} mẫu công việc', style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
                const Spacer(),
                TextButton.icon(
                  onPressed: onDeleteAll,
                  icon: const Icon(Icons.delete_sweep_rounded, size: 16, color: Color(0xFFEF4444)),
                  label: Text('Xoá tất cả', style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                ),
              ],
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            for (final key in sortedKeys) ...[
              _RoleHeader(roleName: key, count: grouped[key]!.length, roles: rolesAsync.value ?? []),
              ...grouped[key]!.map((t) => _TemplateCard(template: t, onEdit: () => onEdit(template: t), onDelete: () => onDelete(t))),
              const SizedBox(height: 4),
            ],
          ],
        );
      },
    );
  }
}

// ── Tab 2: Bộ Mẫu ────────────────────────────────────────────────────────────
class _PresetsTab extends StatelessWidget {
  final Future<void> Function(String role) onSeed;
  const _PresetsTab({required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        // Header
        Text('Chọn nhóm để nạp', style: GoogleFonts.outfit(fontSize: 13, color: _kMuted)),
        Text('Checklist chuẩn theo từng vai trò', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
        const SizedBox(height: 16),

        // Preset cards
        ..._kPresets.map((p) => _PresetCard(pack: p, onSeed: () async => onSeed(p.role))),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PresetCard extends StatelessWidget {
  final _PresetPack pack;
  final Future<void> Function() onSeed;
  const _PresetCard({required this.pack, required this.onSeed});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E3DC)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          // Icon box
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: pack.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(pack.icon, color: pack.color, size: 22),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(pack.role, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
                const SizedBox(height: 2),
                Text(pack.desc, style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _SeedBtn(color: pack.color, onTap: onSeed),
        ],
      ),
    );
  }
}

class _SeedBtn extends StatefulWidget {
  final Color color;
  final Future<void> Function() onTap;
  const _SeedBtn({required this.color, required this.onTap});
  @override
  State<_SeedBtn> createState() => _SeedBtnState();
}

class _SeedBtnState extends State<_SeedBtn> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : () async {
        setState(() => _loading = true);
        await widget.onTap();
        if (mounted) setState(() => _loading = false);
      },
      child: Container(
        width: 60, height: 36,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: _loading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text('Nạp', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _RoleHeader extends StatelessWidget {
  final String roleName;
  final int count;
  final List<OpsRoleModel> roles;
  const _RoleHeader({required this.roleName, required this.count, required this.roles});

  @override
  Widget build(BuildContext context) {
    final role = roles.where((r) => r.name == roleName).firstOrNull;
    Color color = _kNavy;
    if (role?.color != null) {
      try { color = Color(int.parse(role!.color!.replaceFirst('#', 'FF'), radix: 16)); } catch (_) {}
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(roleName, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(20)),
            child: Text('$count việc', style: GoogleFonts.outfit(fontSize: 10, color: _kNavy, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final OpsTaskTemplateModel template;
  final VoidCallback onEdit, onDelete;
  const _TemplateCard({required this.template, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8E3DC)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.checklist_rounded, size: 18, color: _kNavy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(template.title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                  const SizedBox(height: 5),
                  Wrap(spacing: 5, runSpacing: 4, children: [
                    // Tag giờ
                    if (template.targetTime != null)
                      _tag(
                        icon: Icons.schedule_rounded,
                        label: template.targetTime!,
                        bg: template.targetTime == 'Cuối ca'
                            ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                            : _kNavy.withValues(alpha: 0.07),
                        fg: template.targetTime == 'Cuối ca'
                            ? const Color(0xFF8B5CF6)
                            : _kNavy,
                      ),
                    // Tag ca
                    if (template.shiftConfigId != null)
                      _tag(
                        icon: Icons.wb_sunny_rounded,
                        label: 'Gắn ca',
                        bg: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                        fg: const Color(0xFFF59E0B),
                      ),
                    // Tag nhân viên cụ thể
                    if (template.assignedStaffIds.isNotEmpty)
                      _tag(
                        icon: Icons.person_rounded,
                        label: '${template.assignedStaffIds.length} NV',
                        bg: const Color(0xFF10B981).withValues(alpha: 0.1),
                        fg: const Color(0xFF10B981),
                      ),
                  ]),
                ],
              ),
            ),
            InkWell(onTap: onEdit, borderRadius: BorderRadius.circular(8),
              child: Container(width: 34, height: 34, decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.edit_rounded, size: 16, color: _kNavy))),
            const SizedBox(width: 4),
            InkWell(onTap: onDelete, borderRadius: BorderRadius.circular(8),
              child: Container(width: 34, height: 34, decoration: BoxDecoration(color: const Color(0xFFEF4444).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)))),
          ],
        ),
      ),
    );
  }

  Widget _tag({required IconData icon, required String label, required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6),
          border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: fg),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyList({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 72, height: 72,
              decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.playlist_add_rounded, size: 36, color: _kMuted)),
            const SizedBox(height: 14),
            Text('Chưa có công việc', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
            const SizedBox(height: 6),
            Text('Thêm thủ công hoặc chọn tab "Bộ Mẫu" để nạp nhanh.', style: GoogleFonts.outfit(fontSize: 13, color: _kMuted), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text('Thêm công việc', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(backgroundColor: _kNavy, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), minimumSize: const Size(double.infinity, 52)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Icon(icon, size: 14, color: _kMuted),
      const SizedBox(width: 5),
      Text(text, style: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
    ]),
  );
}

// ── Template Form Sheet ───────────────────────────────────────────────────────
class _TemplateFormSheet extends ConsumerStatefulWidget {
  final OpsTaskTemplateModel? initial;
  final Future<void> Function(OpsTaskTemplateModel) onSave;
  const _TemplateFormSheet({this.initial, required this.onSave});

  @override
  ConsumerState<_TemplateFormSheet> createState() => _TemplateFormSheetState();
}

class _TemplateFormSheetState extends ConsumerState<_TemplateFormSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _timeCtrl  = TextEditingController();
  OpsRoleModel? _selectedRole;
  ShiftConfig?  _selectedShift;
  List<String>  _assignedStaffIds = [];
  String _priority = 'normal';
  List<int> _activeDays = [];          // [] = mọi ngày
  bool _requiresPhoto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial != null) {
      final t = widget.initial!;
      _titleCtrl.text     = t.title;
      _descCtrl.text      = t.description ?? '';
      _timeCtrl.text      = t.targetTime ?? '';
      _assignedStaffIds   = List.from(t.assignedStaffIds);
      _priority           = t.priority;
      _activeDays         = List.from(t.activeDays ?? []);
      _requiresPhoto      = t.requiresPhoto;
    }
  }

  @override
  void dispose() { _titleCtrl.dispose(); _descCtrl.dispose(); _timeCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final t = OpsTaskTemplateModel(
        id:               widget.initial?.id ?? const Uuid().v4(),
        storeId:          widget.initial?.storeId ?? '',
        storeRoleId:      _selectedRole?.id ?? widget.initial?.storeRoleId,
        roleName:         _selectedRole?.name ?? widget.initial?.roleName,
        title:            _titleCtrl.text.trim(),
        description:      _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        targetTime:       _timeCtrl.text.trim().isEmpty ? null : _timeCtrl.text.trim(),
        sortOrder:        widget.initial?.sortOrder ?? 0,
        shiftConfigId:    _selectedShift?.id,
        assignedStaffIds: _assignedStaffIds,
        priority:         _priority,
        activeDays:       _activeDays.isEmpty ? null : _activeDays,
        requiresPhoto:    _requiresPhoto,
      );
      await widget.onSave(t);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _dec(String label, {String? hint, Widget? prefix}) => InputDecoration(
    labelText: label, hintText: hint, prefixIcon: prefix,
    labelStyle: GoogleFonts.outfit(color: _kMuted),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kNavy, width: 2)),
    filled: true, fillColor: const Color(0xFFFAFAFA),
  );

  @override
  Widget build(BuildContext context) {
    final rolesAsync  = ref.watch(opsStoreRolesProvider);
    final session     = ref.watch(sessionProvider);
    final storeId     = session?.storeId ?? '';
    return Container(
      decoration: const BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(left: 20, right: 20, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text(widget.initial == null ? 'Thêm công việc' : 'Sửa công việc',
              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
            const SizedBox(height: 20),

            // Tên công việc
            TextField(controller: _titleCtrl,
              decoration: _dec('Tên công việc *', hint: 'VD: Vệ sinh toilet lần 1'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, maxLines: 2,
              decoration: _dec('Mô tả / Hướng dẫn'),
              style: GoogleFonts.outfit()),
            const SizedBox(height: 12),
            TextField(controller: _timeCtrl,
              decoration: _dec('Giờ mục tiêu', hint: '09:00 hoặc "Cuối ca"',
                prefix: const Icon(Icons.schedule_rounded, size: 18)),
              style: GoogleFonts.outfit()),
            const SizedBox(height: 12),

            // ── Yêu cầu ảnh bằng chứng ──────────────────────────────
            GestureDetector(
              onTap: () => setState(() => _requiresPhoto = !_requiresPhoto),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _requiresPhoto ? const Color(0xFF6366F1).withValues(alpha: 0.08) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _requiresPhoto ? const Color(0xFF6366F1) : Colors.grey.shade300,
                    width: _requiresPhoto ? 1.5 : 1,
                  ),
                ),
                child: Row(children: [
                  Icon(Icons.camera_alt_rounded,
                    color: _requiresPhoto ? const Color(0xFF6366F1) : _kMuted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Yêu cầu ảnh bằng chứng',
                        style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _requiresPhoto ? const Color(0xFF6366F1) : _kNavy)),
                      Text('Nhân viên phải chụp ảnh trước khi tick xong',
                        style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
                    ],
                  )),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      _requiresPhoto ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                      key: ValueKey(_requiresPhoto),
                      color: _requiresPhoto ? const Color(0xFF6366F1) : Colors.grey.shade400,
                      size: 32,
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // ── Mức độ ưu tiên ──────────────────────────────────
            _sectionLabel('Mức độ ưu tiên', Icons.flag_rounded),
            const SizedBox(height: 10),
            Row(children: [
              for (final p in [
                ('critical', '🔴', 'Critical', const Color(0xFFEF4444)),
                ('high',     '🟠', 'High',     const Color(0xFFF97316)),
                ('normal',   '🔵', 'Normal',   _kNavy),
                ('low',      '⚪️', 'Low',      _kMuted),
              ]) ...[
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _priority = p.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _priority == p.$1
                          ? p.$4.withValues(alpha: 0.12)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _priority == p.$1 ? p.$4 : Colors.grey.shade300,
                        width: _priority == p.$1 ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.$2, style: const TextStyle(fontSize: 16)),
                        const SizedBox(height: 3),
                        Text(p.$3,
                          style: GoogleFonts.outfit(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _priority == p.$1 ? p.$4 : _kMuted,
                          )),
                      ],
                    ),
                  ),
                )),
                const SizedBox(width: 6),
              ],
            ]),
            const SizedBox(height: 16),
             // ── Ngày trong tuần ────────────────────────────
            _sectionLabel('Chỉ hiện vào ngày', Icons.calendar_today_rounded),
            const SizedBox(height: 4),
            Text('(bỏ trống = hiện mọi ngày)',
              style: GoogleFonts.outfit(fontSize: 11, color: _kMuted, fontStyle: FontStyle.italic)),
            const SizedBox(height: 10),
            Row(children: [
              for (final d in [
                (1, 'T2'), (2, 'T3'), (3, 'T4'), (4, 'T5'),
                (5, 'T6'), (6, 'T7'), (7, 'CN'),
              ]) ...[
                Expanded(child: GestureDetector(
                  onTap: () => setState(() {
                    if (_activeDays.contains(d.$1)) {
                      _activeDays.remove(d.$1);
                    } else {
                      _activeDays.add(d.$1);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: _activeDays.contains(d.$1)
                          ? _kNavy
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(d.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 11, fontWeight: FontWeight.w800,
                        color: _activeDays.contains(d.$1)
                            ? Colors.white : _kMuted,
                      )),
                  ),
                )),
                if (d.$1 < 7) const SizedBox(width: 4),
              ],
            ]),
            const SizedBox(height: 12),

            // Vai trò
            rolesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
              data: (roles) {
                // Init selected role khi edit
                if (_selectedRole == null && widget.initial?.storeRoleId != null) {
                  try {
                    _selectedRole = roles.firstWhere(
                        (r) => r.id == widget.initial!.storeRoleId);
                  } catch (_) {}
                }
                return DropdownButtonFormField<OpsRoleModel?>(
                  value: _selectedRole,
                  decoration: _dec('Vai trò', hint: 'Để trống = tất cả'),
                  items: [
                    DropdownMenuItem(value: null,
                        child: Text('Tất cả vai trò', style: GoogleFonts.outfit())),
                    ...roles.map((r) => DropdownMenuItem(value: r,
                        child: Text(r.name, style: GoogleFonts.outfit()))),
                  ],
                  onChanged: (v) => setState(() => _selectedRole = v),
                );
              },
            ),
            const SizedBox(height: 12),

            // Ca làm việc
            FutureBuilder<List<ShiftConfig>>(
              future: ShiftConfigService.getShifts(storeId),
              builder: (_, snap) {
                final shifts = snap.data ?? [];
                if (shifts.isEmpty) return const SizedBox.shrink();
                // Init selected shift khi edit
                if (_selectedShift == null && widget.initial?.shiftConfigId != null) {
                  try {
                    _selectedShift = shifts.firstWhere(
                        (s) => s.id == widget.initial!.shiftConfigId);
                  } catch (_) {}
                }
                return DropdownButtonFormField<ShiftConfig?>(
                  value: _selectedShift,
                  decoration: _dec('Ca làm việc',
                      hint: 'Để trống = hiện tất cả ca',
                      prefix: const Icon(Icons.schedule_rounded, size: 18)),
                  items: [
                    DropdownMenuItem(value: null,
                        child: Text('Tất cả ca', style: GoogleFonts.outfit())),
                    ...shifts.map((s) => DropdownMenuItem(value: s,
                        child: Text('${s.name} (${s.timeLabel})',
                            style: GoogleFonts.outfit()))),
                  ],
                  onChanged: (v) => setState(() => _selectedShift = v),
                );
              },
            ),
            const SizedBox(height: 12),

            // Assign nhân viên cụ thể
            FutureBuilder<List<StaffMember>>(
              future: StaffService.getStaffList(storeId),
              builder: (_, snap) {
                final staff = snap.data ?? [];
                if (staff.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(Icons.person_pin_rounded, size: 16, color: _kMuted),
                      const SizedBox(width: 6),
                      Text('Assign nhân viên cụ thể',
                          style: GoogleFonts.outfit(fontSize: 12,
                              color: _kMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Text('(để trống = theo vai trò)',
                          style: GoogleFonts.outfit(fontSize: 11, color: _kMuted)),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: staff.map((m) {
                        final selected = _assignedStaffIds.contains(m.userId);
                        return GestureDetector(
                          onTap: () => setState(() {
                            if (selected) {
                              _assignedStaffIds.remove(m.userId);
                            } else {
                              _assignedStaffIds.add(m.userId);
                            }
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _kNavy.withValues(alpha: 0.1)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? _kNavy : Colors.grey.shade300,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              if (selected)
                                const Icon(Icons.check_rounded,
                                    size: 12, color: _kNavy),
                              if (selected) const SizedBox(width: 4),
                              Text(m.name,
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: selected
                                        ? FontWeight.w700 : FontWeight.w500,
                                    color: selected ? _kNavy : _kMuted,
                                  )),
                            ]),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(backgroundColor: _kNavy,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0),
                child: _saving
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                    : Text('Lưu công việc', style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 2),
    child: Row(children: [
      Icon(icon, size: 14, color: _kMuted),
      const SizedBox(width: 5),
      Text(text, style: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
    ]),
  );
}

// ── Tab Phân Quyền ────────────────────────────────────────────────────────────
class _PermissionTab extends ConsumerWidget {
  final void Function({OpsTaskTemplateModel? template}) onEdit;
  const _PermissionTab({required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tmplAsync  = ref.watch(opsTemplatesProvider);
    final rolesAsync = ref.watch(opsStoreRolesProvider);

    return tmplAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: _kNavy)),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (templates) {
        final roles     = rolesAsync.value ?? [];
        final roleColor = <String, Color>{};
        for (final r in roles) {
          if (r.color != null) {
            try { roleColor[r.id] = Color(int.parse(r.color!.replaceFirst('#', 'FF'), radix: 16)); } catch (_) {}
          }
        }

        if (templates.isEmpty) {
          return Center(
            child: Text('Chưa có mẫu công việc.\nHãy thêm trong tab "Danh Sách".', style: GoogleFonts.outfit(color: _kMuted, fontSize: 14), textAlign: TextAlign.center),
          );
        }

        // Group by role
        final byRole = <String, List<OpsTaskTemplateModel>>{};
        final personalAssign = <OpsTaskTemplateModel>[];

        for (final t in templates) {
          if (t.assignedStaffIds.isNotEmpty) personalAssign.add(t);
          byRole.putIfAbsent(t.roleName ?? 'Tất cả vai trò', () => []).add(t);
        }
        final sortedKeys = byRole.keys.toList()..sort();

        // Stats header
        final roleCount = templates.map((t) => t.roleName).toSet().length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          children: [
            // Stats header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatChip('${templates.length}', 'Mẫu việc'),
                _StatChip('$roleCount', 'Vai trò'),
                _StatChip('${personalAssign.length}', 'Assign cá nhân'),
              ]),
            ),
            const SizedBox(height: 16),

            // Per role sections
            for (final key in sortedKeys) ...[
              _PermRoleHeader(
                roleName:  key,
                count:     byRole[key]!.length,
                color:     byRole[key]!.first.storeRoleId != null ? (roleColor[byRole[key]!.first.storeRoleId!] ?? _kNavy) : _kMuted,
              ),
              ...byRole[key]!.map((t) => _PermTaskCard(template: t, onEdit: onEdit)),
              const SizedBox(height: 8),
            ],

            // Personal assign section
            if (personalAssign.isNotEmpty) ...[
              _PermRoleHeader(roleName: 'Assign cá nhân', count: personalAssign.length, color: const Color(0xFF10B981)),
              ...personalAssign.map((t) => _PermTaskCard(template: t, onEdit: onEdit)),
            ],
          ],
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value, label;
  const _StatChip(this.value, this.label);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w900, color: _kNavy)),
    Text(label,  style: GoogleFonts.outfit(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w600)),
  ]);
}

class _PermRoleHeader extends StatelessWidget {
  final String roleName; final int count; final Color color;
  const _PermRoleHeader({required this.roleName, required this.count, required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Text(roleName, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text('$count việc', style: GoogleFonts.outfit(fontSize: 10, color: color, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}

class _PermTaskCard extends StatelessWidget {
  final OpsTaskTemplateModel template;
  final void Function({OpsTaskTemplateModel? template}) onEdit;
  const _PermTaskCard({required this.template, required this.onEdit});

  Color _priorityColor() => switch (template.priority) {
    'critical' => const Color(0xFFEF4444),
    'high'     => const Color(0xFFF97316),
    'low'      => _kMuted,
    _          => _kNavy,
  };

  @override
  Widget build(BuildContext context) {
    final pc = _priorityColor();
    return InkWell(
      onTap: () => onEdit(template: template),
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E3DC)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Priority indicator + title + edit icon
        Row(children: [
          Container(width: 4, height: 36, decoration: BoxDecoration(color: pc, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Expanded(child: Text(template.title, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy))),
        ]),
        const SizedBox(height: 8),
        // Badges
        Wrap(spacing: 5, runSpacing: 4, children: [
          if (template.targetTime != null)
            _Badge(Icons.schedule_rounded, template.targetTime!, const Color(0xFF6366F1)),
          if (template.shiftConfigId != null)
            _Badge(Icons.wb_sunny_rounded, 'Gắn ca', const Color(0xFFF59E0B)),
          if (template.requiresPhoto)
            _Badge(Icons.camera_alt_rounded, 'Ảnh bắt buộc', const Color(0xFF3B82F6)),
          if (template.assignedStaffIds.isNotEmpty)
            _Badge(Icons.person_rounded, '${template.assignedStaffIds.length} NV', const Color(0xFF10B981)),
          if (template.activeDays != null && template.activeDays!.isNotEmpty)
            _Badge(Icons.calendar_today_rounded, '${template.activeDays!.length} ngày/tuần', _kNavy),
          if (template.priority != 'normal')
            _Badge(Icons.flag_rounded, template.priority, pc),
        ]),
      ]),
      ),  // end InkWell child Container
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Badge(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(label, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}
