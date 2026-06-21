// lib/screens/role_manager_screen.dart
// Quản lý vai trò linh hoạt — Custom Roles
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/staff_service.dart';
import '../core/providers/session_provider.dart';
import '../core/services/staff_sync_service.dart';

// ── Constants ──────────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream  = Color(0xFFFFF8F0);
const _kBorder = Color(0xFFE0D8CC);
const _kMuted  = Color(0xFF9E9085);

// ── Danh sách icon để chọn ────────────────────────────────────────────────────
const _kIcons = <String, IconData>{
  // Nhân viên & quản lý
  'badge':             Icons.badge_rounded,
  'manage_accounts':   Icons.manage_accounts_rounded,
  'support_agent':     Icons.support_agent_rounded,
  'security':          Icons.security_rounded,
  'supervisor':        Icons.supervisor_account_rounded,
  'person':            Icons.person_rounded,
  'people':            Icons.people_rounded,
  'groups':            Icons.groups_rounded,
  // F&B
  'kitchen':           Icons.local_fire_department_rounded,
  'local_cafe':        Icons.local_cafe_rounded,
  'restaurant':        Icons.restaurant_rounded,
  'room_service':      Icons.room_service_rounded,
  'lunch_dining':      Icons.lunch_dining_rounded,
  'bakery':            Icons.bakery_dining_rounded,
  'ramen':             Icons.ramen_dining_rounded,
  'wine_bar':          Icons.wine_bar_rounded,
  'local_bar':         Icons.local_bar_rounded,
  'icecream':          Icons.icecream_rounded,
  'cake':              Icons.cake_rounded,
  // Bán hàng & thu ngân
  'point_of_sale':     Icons.point_of_sale_rounded,
  'store':             Icons.store_rounded,
  'storefront':        Icons.storefront_rounded,
  'shopping_cart':     Icons.shopping_cart_rounded,
  'receipt':           Icons.receipt_long_rounded,
  'payments':          Icons.payments_rounded,
  'local_atm':         Icons.local_atm_rounded,
  // Kho & vận chuyển
  'inventory':         Icons.inventory_2_rounded,
  'warehouse':         Icons.warehouse_rounded,
  'delivery':          Icons.delivery_dining_rounded,
  'local_shipping':    Icons.local_shipping_rounded,
  // Bàn & dịch vụ
  'table_bar':         Icons.table_bar_rounded,
  'chair':             Icons.chair_rounded,
  'cleaning_services': Icons.cleaning_services_rounded,
  // Kỹ thuật & nghề
  'build':             Icons.build_rounded,
  'handyman':          Icons.handyman_rounded,
  'plumbing':          Icons.plumbing_rounded,
  'electrical':        Icons.electrical_services_rounded,
  'computer':          Icons.computer_rounded,
  'design_services':   Icons.design_services_rounded,
  'brush':             Icons.brush_rounded,
  'music_note':        Icons.music_note_rounded,
  'fitness':           Icons.fitness_center_rounded,
  // Chung
  'star':              Icons.star_rounded,
  'diamond':           Icons.diamond_rounded,
  'emoji_events':      Icons.emoji_events_rounded,
  'school':            Icons.school_rounded,
  'medical':           Icons.medical_services_rounded,
  'sports':            Icons.sports_rounded,
};

// ── Template gợi ý ────────────────────────────────────────────────────────────
const _kTemplates = [
  _RoleTemplate('Thu ngân',  'point_of_sale', '#1D4ED8', ['pos', 'ban']),
  _RoleTemplate('Phục vụ',   'room_service',  '#065F46', ['ban', 'kitchen']),
  _RoleTemplate('Bếp',       'kitchen',       '#DC2626', ['kitchen']),
  _RoleTemplate('Kho hàng',  'inventory',     '#92400E', ['kho']),
  _RoleTemplate('Quản lý',   'manage_accounts','#7C3AED', ['pos','kho','ban','kitchen','finance','report']),
  _RoleTemplate('Barista',   'local_cafe',    '#B45309', ['pos','ban']),
  _RoleTemplate('Bảo vệ',    'security',      '#374151', []),
  _RoleTemplate('Giao hàng', 'delivery',      '#0369A1', ['pos']),
];

class _RoleTemplate {
  final String name, icon, color;
  final List<String> modules;
  const _RoleTemplate(this.name, this.icon, this.color, this.modules);
}

const _kModuleNames = <String, (String, IconData)>{
  'pos':      ('Bán hàng',         Icons.point_of_sale_rounded),
  'kho':      ('Kho hàng',         Icons.inventory_2_rounded),
  'kho_pro':  ('Kho CN',           Icons.restaurant_menu_rounded),
  'ban':      ('Quản lý bàn',      Icons.table_bar_rounded),
  'kitchen':  ('Bếp',              Icons.local_fire_department_rounded),
  'finance':  ('Thu chi',          Icons.account_balance_wallet_rounded),
  'report':   ('Báo cáo',          Icons.bar_chart_rounded),
  'loyalty':  ('Điểm thưởng',      Icons.star_rounded),
  'staff':    ('Nhân viên',        Icons.people_rounded),
  'chamcong':  ('Chấm công',   Icons.fingerprint_rounded),
  'tinhluong': ('Tính lương',  Icons.payments_rounded),
  'kay_ops':   ('Vận Hành',    Icons.checklist_rounded),
};

// ✅ FIX #3: keepAlive — không bao giờ dispose dù không còn listener
// Provider này được MainShell watch — nếu dispose thì mỗi lần tab switch sẽ refetch từ Supabase
final storeRolesProvider = FutureProvider<List<StoreRole>>((ref) async {
  ref.keepAlive(); // giữ cache vĩnh viễn trong phiên làm việc
  final session = ref.watch(sessionProvider);
  if (session?.storeId == null) return [];
  return StoreRoleService.getRoles(session!.storeId!);
});

// ── Main Screen ───────────────────────────────────────────────────────────────
class RoleManagerScreen extends ConsumerWidget {
  const RoleManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(storeRolesProvider);
    final session    = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: _kCream,
      appBar: AppBar(
        backgroundColor: _kNavy,
        foregroundColor: Colors.white,
        title: const Text('Vai trò & Phân quyền',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'role_manager_fab',
        onPressed: () => _showRoleSheet(context, ref, storeId: session?.storeId ?? ''),
        backgroundColor: _kNavy,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tạo vai trò', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: rolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Lỗi: $e')),
        data: (roles) => roles.isEmpty
            ? _EmptyState(storeId: session?.storeId ?? '', onCreated: () => ref.invalidate(storeRolesProvider))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  const Text('Vai trò trong quán',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kMuted)),
                  const SizedBox(height: 12),
                  ...roles.map((role) => _RoleCard(
                    role:      role,
                    storeId:   session?.storeId ?? '',
                    onChanged: () => ref.invalidate(storeRolesProvider),
                  )),
                ],
              ),
      ),
    );
  }

  void _showRoleSheet(BuildContext ctx, WidgetRef ref, {required String storeId, StoreRole? editing}) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoleEditSheet(
        storeId: storeId,
        editing: editing,
        onSaved: () => ref.invalidate(storeRolesProvider),
      ),
    );
  }
}

// ── Empty State + Templates ───────────────────────────────────────────────────
class _EmptyState extends ConsumerWidget {
  final String storeId;
  final VoidCallback onCreated;
  const _EmptyState({required this.storeId, required this.onCreated});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SizedBox(height: 16),
        const Text('Gợi ý nhanh', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kMuted)),
        const SizedBox(height: 8),
        const Text('Chọn 1 chạm để tạo từ template, hoặc nhấn + để tùy chỉnh.',
          style: TextStyle(fontSize: 12, color: _kMuted)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _kTemplates.map((t) => _TemplateChip(
            template: t,
            storeId: storeId,
            onCreated: onCreated,
          )).toList(),
        ),
      ],
    );
  }
}

class _TemplateChip extends StatefulWidget {
  final _RoleTemplate template;
  final String storeId;
  final VoidCallback onCreated;
  const _TemplateChip({required this.template, required this.storeId, required this.onCreated});

  @override
  State<_TemplateChip> createState() => _TemplateChipState();
}

class _TemplateChipState extends State<_TemplateChip> {
  bool _loading = false;

  Color get _color {
    try {
      final hex = widget.template.color.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) { return _kNavy; }
  }

  @override
  Widget build(BuildContext context) {
    final icon = _kIcons[widget.template.icon] ?? Icons.badge_rounded;
    return GestureDetector(
      onTap: _loading ? null : _create,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _color.withValues(alpha: 0.4)),
        ),
        child: _loading
            ? SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: _color))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: _color),
                const SizedBox(width: 6),
                Text(widget.template.name,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _color)),
              ]),
      ),
    );
  }

  Future<void> _create() async {
    setState(() => _loading = true);
    try {
      await StoreRoleService.createRole(
        storeId: widget.storeId,
        name:    widget.template.name,
        icon:    widget.template.icon,
        color:   widget.template.color,
        modules: widget.template.modules,
      );
      widget.onCreated();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}

// ── Role Card (ExpansionTile) ─────────────────────────────────────────────────
class _RoleCard extends ConsumerStatefulWidget {
  final StoreRole role;
  final String storeId;
  final VoidCallback onChanged;
  const _RoleCard({required this.role, required this.storeId, required this.onChanged});

  @override
  ConsumerState<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends ConsumerState<_RoleCard> {
  late List<String> _perms;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _perms = List.from(widget.role.modules);
  }

  @override
  Widget build(BuildContext context) {
    final role  = widget.role;
    final color = role.colorValue;
    final icon  = _kIcons[role.icon] ?? Icons.badge_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(role.name,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          subtitle: Text('${_perms.length}/${_kModuleNames.length} modules',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.7))),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            // Nút sửa
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              color: _kMuted,
              onPressed: () => _openEdit(context),
            ),
            // Nút xoá
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: Colors.red.shade400,
              onPressed: () => _confirmDelete(context),
            ),
          ]),
          children: [
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.apps_rounded, size: 14, color: _kMuted),
                  const SizedBox(width: 6),
                  const Text('Module được phép truy cập',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
                  const Spacer(),
                  Text('${_perms.length}/${_kModuleNames.length}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
                ]),
                const SizedBox(height: 10),
                // Module cards grid 3 cột
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.88,
                  children: _kModuleNames.entries.map((e) {
                    final enabled = _perms.contains(e.key);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (enabled) _perms.remove(e.key);
                        else _perms.add(e.key);
                      }),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: enabled ? color.withValues(alpha: 0.08) : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: enabled ? color.withValues(alpha: 0.5) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(
                              color: enabled ? color.withValues(alpha: 0.15) : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(e.value.$2,
                              size: 18,
                              color: enabled ? color : Colors.grey.shade400),
                          ),
                          const SizedBox(height: 6),
                          Text(e.value.$1,
                            style: TextStyle(
                              fontSize: 10, fontWeight: FontWeight.w700,
                              color: enabled ? color : Colors.grey.shade400),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 18, height: 18,
                            decoration: BoxDecoration(
                              color: enabled ? color : Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              enabled ? Icons.check_rounded : Icons.remove_rounded,
                              size: 11,
                              color: enabled ? Colors.white : Colors.grey.shade400,
                            ),
                          ),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _saving
                        ? const SizedBox(height: 18, width: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Lưu quyền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await StoreRoleService.updateRole(roleId: widget.role.id, modules: _perms);
    // 📡 Broadcast real-time → nhân viên có role này tự refresh
    await StaffSyncService.broadcastPermsChanged(
      storeId: widget.storeId,
      role: widget.role.name,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Đã lưu quyền cho ${widget.role.name}'),
      behavior: SnackBarBehavior.floating));
  }

  void _openEdit(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoleEditSheet(
        storeId: widget.storeId,
        editing: widget.role,
        onSaved: widget.onChanged,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xoá vai trò?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Nhân viên đang có vai trò "${widget.role.name}" sẽ được chuyển sang vai trò khác.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await StoreRoleService.deleteRole(
      roleId: widget.role.id, storeId: widget.storeId, roleName: widget.role.name);
    // 📡 Broadcast — nhân viên đang dùng role này nhận thông báo để refresh quyền
    await StaffSyncService.broadcastPermsChanged(
      storeId: widget.storeId, role: widget.role.name);
    widget.onChanged();
  }
}

// ── Sheet tạo / sửa role ──────────────────────────────────────────────────────
class _RoleEditSheet extends StatefulWidget {
  final String storeId;
  final StoreRole? editing;
  final VoidCallback onSaved;
  const _RoleEditSheet({required this.storeId, this.editing, required this.onSaved});

  @override
  State<_RoleEditSheet> createState() => _RoleEditSheetState();
}

class _RoleEditSheetState extends State<_RoleEditSheet> {
  late final TextEditingController _nameCtrl;
  late String _icon;
  late Color  _color;
  late List<String> _modules;
  bool _saving = false;
  String? _error;

  // HSL sliders
  late double _hue, _sat, _lit;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _icon     = e?.icon    ?? 'badge';
    _color    = e?.colorValue ?? const Color(0xFF1C2151);
    _modules  = List.from(e?.modules ?? []);
    final hsl = HSLColor.fromColor(_color);
    _hue = hsl.hue;
    _sat = hsl.saturation;
    _lit = hsl.lightness;
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  void _updateColor() {
    _color = HSLColor.fromAHSL(1, _hue, _sat, _lit).toColor();
  }

  String _colorHex() {
    final r = (_color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (_color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (_color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b';
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
        child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 12, 20, 40), children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(widget.editing == null ? 'Tạo vai trò mới' : 'Chỉnh sửa vai trò',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kNavy)),
          const SizedBox(height: 20),

          // ── Tên vai trò ──
          _Label('Tên vai trò'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: 'VD: Barista, Lễ tân, Kế toán...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ],
          const SizedBox(height: 20),

          // ── Chọn icon ──
          _Label('Biểu tượng'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _kIcons.entries.map((e) {
              final selected = _icon == e.key;
              return GestureDetector(
                onTap: () => setState(() => _icon = e.key),
                child: Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: selected ? _color.withValues(alpha: 0.15) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? _color : Colors.transparent, width: 2),
                  ),
                  child: Icon(e.value, size: 22,
                    color: selected ? _color : Colors.grey.shade500),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // ── Chọn màu (HSL) ──
          _Label('Màu vai trò'),
          const SizedBox(height: 12),
          // Preview
          Center(
            child: Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.4),
                  blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: Icon(_kIcons[_icon] ?? Icons.badge_rounded,
                color: Colors.white, size: 28),
            ),
          ),
          const SizedBox(height: 12),
          _SliderRow(
            label: 'Màu sắc (H)', value: _hue, min: 0, max: 360,
            gradient: LinearGradient(colors: List.generate(7, (i) =>
              HSLColor.fromAHSL(1, i * 60.0, 0.8, 0.5).toColor())),
            onChanged: (v) => setState(() { _hue = v; _updateColor(); }),
          ),
          _SliderRow(
            label: 'Độ bão hoà (S)', value: _sat, min: 0, max: 1,
            gradient: LinearGradient(colors: [
              HSLColor.fromAHSL(1, _hue, 0, _lit).toColor(),
              HSLColor.fromAHSL(1, _hue, 1, _lit).toColor()]),
            onChanged: (v) => setState(() { _sat = v; _updateColor(); }),
          ),
          _SliderRow(
            label: 'Độ sáng (L)', value: _lit, min: 0.1, max: 0.9,
            gradient: LinearGradient(colors: [
              Colors.black,
              HSLColor.fromAHSL(1, _hue, _sat, 0.5).toColor(),
              Colors.white]),
            onChanged: (v) => setState(() { _lit = v; _updateColor(); }),
          ),
          const SizedBox(height: 20),

          // ── Modules ──
          _Label('Quyền truy cập module'),
          const SizedBox(height: 8),
          ..._kModuleNames.entries.map((e) {
            final on = _modules.contains(e.key);
            return CheckboxListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              value: on,
              activeColor: _color,
              secondary: Icon(e.value.$2, size: 18, color: on ? _color : _kMuted),
              title: Text(e.value.$1, style: const TextStyle(fontSize: 13)),
              onChanged: (v) => setState(() {
                if (v == true) _modules.add(e.key);
                else _modules.remove(e.key);
              }),
            );
          }),
          const SizedBox(height: 20),

          // ── Nút lưu ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.editing == null ? 'Tạo vai trò' : 'Lưu thay đổi',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) { setState(() => _error = 'Nhập tên vai trò'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final hex = _colorHex();
      if (widget.editing == null) {
        await StoreRoleService.createRole(
          storeId: widget.storeId, name: name,
          icon: _icon, color: hex, modules: _modules);
      } else {
        await StoreRoleService.updateRole(
          roleId: widget.editing!.id, name: name,
          icon: _icon, color: hex, modules: _modules);
        // 📡 Broadcast — nhân viên có role này tự refresh module list
        await StaffSyncService.broadcastPermsChanged(
          storeId: widget.storeId, role: name);
        // Nếu tên role đổi, broadcast thêm tên cũ để notify staff đang dùng tên cũ
        final oldName = widget.editing!.name;
        if (oldName != name) {
          await StaffSyncService.broadcastPermsChanged(
            storeId: widget.storeId, role: oldName);
        }
      }
      if (mounted) { Navigator.pop(context); widget.onSaved(); }
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = '$e'; });
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy));
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value, min, max;
  final LinearGradient gradient;
  final ValueChanged<double> onChanged;
  const _SliderRow({required this.label, required this.value,
    required this.min, required this.max,
    required this.gradient, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kMuted)),
      const SizedBox(height: 4),
      Row(children: [
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 12,
                trackShape: const RectangularSliderTrackShape(),
                overlayShape: SliderComponentShape.noOverlay,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: Colors.transparent,
                inactiveTrackColor: Colors.transparent,
                thumbColor: Colors.white,
              ),
              child: Slider(value: value, min: min, max: max, onChanged: onChanged),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 10),
    ]);
  }
}
