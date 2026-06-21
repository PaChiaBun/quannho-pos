import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/providers/session_provider.dart';
import '../core/services/staff_service.dart' show ShiftConfig, ShiftConfigService,
    StaffMember, StaffService, ShiftRecord, StoreRole, AddStaffResult, PermLog, StoreRoleService,
    kAllActions, kActionMeta;
import '../core/services/staff_sync_service.dart';
import '../core/services/user_auth_service.dart' show SessionData;
import 'role_manager_screen.dart';
import 'dashboard_screen.dart' show permsVersionProvider;
import '../core/providers/permission_provider.dart' show userActionPermsProvider;

// ── Constants ─────────────────────────────────────────────────────────────────
const _kNavy   = Color(0xFF1C2151);
const _kOrange = Color(0xFFFF6B35);
const _kCream  = Color(0xFFFFF8F0);
const _kBorder = Color(0xFFE0D8CC);
const _kMuted  = Color(0xFF9E9085);

const _roles = {
  'owner':   ('Chủ quán',  Icons.star_rounded,                  Color(0xFFFF6B35)),
  'manager': ('Quản lý',   Icons.manage_accounts_rounded,        Color(0xFF7C3AED)),
  'cashier': ('Thu ngân',  Icons.point_of_sale_rounded,          Color(0xFF1D4ED8)),
  'waiter':  ('Phục vụ',   Icons.room_service_rounded,           Color(0xFF065F46)),
  'kitchen': ('Bếp',       Icons.local_fire_department_rounded,  Color(0xFFDC2626)),
  'stock':   ('Kho',       Icons.inventory_2_rounded,            Color(0xFF92400E)),
};

const _moduleNames = {
  'pos':      ('Bán hàng',    Icons.point_of_sale_rounded),
  'kho':      ('Kho hàng',    Icons.inventory_2_rounded),
  'kho_pro':  ('Kho CN',      Icons.restaurant_menu_rounded),  // ‼️ FIX: thiếu kho_pro
  'ban':      ('Quản lý bàn', Icons.table_bar_rounded),
  'kitchen':  ('Bếp',        Icons.local_fire_department_rounded),
  'finance':  ('Thu chi',     Icons.account_balance_wallet_rounded),
  'report':   ('Báo cáo',    Icons.bar_chart_rounded),
  'loyalty':  ('Điểm thưởng', Icons.star_rounded),
  'staff':    ('Nhân viên',  Icons.people_rounded),
  'chamcong': ('Chấm công',  Icons.fingerprint_rounded),
};

// ── Helper: tra cứu thông tin hiển thị role ───────────────────────────────────
// Ưu tiên store_roles (custom), fallback về _roles cũ để tương thích ngược
({String name, Color color, IconData icon}) _resolveRole(
    String roleKey, List<StoreRole> storeRoles) {
  // 1. Tìm trong store_roles
  for (final r in storeRoles) {
    if (r.name == roleKey) {
      final icon = <String, IconData>{
        'badge': Icons.badge_rounded, 'manage_accounts': Icons.manage_accounts_rounded,
        'support_agent': Icons.support_agent_rounded, 'security': Icons.security_rounded,
        'supervisor': Icons.supervisor_account_rounded, 'person': Icons.person_rounded,
        'people': Icons.people_rounded, 'groups': Icons.groups_rounded,
        'kitchen': Icons.local_fire_department_rounded, 'local_cafe': Icons.local_cafe_rounded,
        'restaurant': Icons.restaurant_rounded, 'room_service': Icons.room_service_rounded,
        'lunch_dining': Icons.lunch_dining_rounded, 'bakery': Icons.bakery_dining_rounded,
        'ramen': Icons.ramen_dining_rounded, 'wine_bar': Icons.wine_bar_rounded,
        'local_bar': Icons.local_bar_rounded, 'icecream': Icons.icecream_rounded,
        'cake': Icons.cake_rounded, 'point_of_sale': Icons.point_of_sale_rounded,
        'storefront': Icons.storefront_rounded, 'shopping_cart': Icons.shopping_cart_rounded,
        'receipt': Icons.receipt_long_rounded, 'payments': Icons.payments_rounded,
        'local_atm': Icons.local_atm_rounded, 'inventory': Icons.inventory_2_rounded,
        'warehouse': Icons.warehouse_rounded, 'delivery': Icons.delivery_dining_rounded,
        'local_shipping': Icons.local_shipping_rounded, 'forklift': Icons.warehouse_rounded,
        'table_bar': Icons.table_bar_rounded, 'chair': Icons.chair_rounded,
        'cleaning': Icons.cleaning_services_rounded, 'build': Icons.build_rounded,
        'handyman': Icons.handyman_rounded, 'plumbing': Icons.plumbing_rounded,
        'electrical': Icons.electrical_services_rounded, 'computer': Icons.computer_rounded,
        'design_services': Icons.design_services_rounded, 'star': Icons.star_rounded,
        'diamond': Icons.diamond_rounded, 'emoji_events': Icons.emoji_events_rounded,
        'school': Icons.school_rounded, 'medical': Icons.medical_services_rounded,
        'sports': Icons.sports_rounded,
      }[r.icon] ?? Icons.badge_rounded;
      return (name: r.name, color: r.colorValue, icon: icon);
    }
  }
  // 2. Fallback _roles cũ (cashier, kitchen, waiter...)
  final old = _roles[roleKey];
  if (old != null) return (name: old.$1, color: old.$3, icon: old.$2);
  // 3. Default
  return (name: roleKey, color: _kNavy, icon: Icons.badge_rounded);
}

// ── Providers ─────────────────────────────────────────────────────────────────
final _staffListProvider = FutureProvider.autoDispose<List<StaffMember>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session?.storeId == null) return [];
  return StaffService.getStaffList(session!.storeId!);
});

final _shiftsProvider = FutureProvider.autoDispose<List<ShiftRecord>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session?.storeId == null) return [];
  final isOwner = session!.isOwner || session.role == 'manager';
  return StaffService.getShifts(
    storeId: session.storeId!,
    userId: isOwner ? null : session.userId,
  );
});

/// Ca làm việc theo giờ (ShiftConfig)
final _shiftConfigsProvider = FutureProvider.autoDispose<List<ShiftConfig>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session?.storeId == null) return [];
  return ShiftConfigService.getShifts(session!.storeId!);
});

/// Ca đang mở của user hiện tại: {id, clock_in} hoặc null nếu chưa vào ca
final _openShiftProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session?.storeId == null || session?.userId == null) return null;
  try {
    final db = Supabase.instance.client;
    final res = await db
        .from('staff_shifts')
        .select('id, clock_in')
        .eq('user_id', session!.userId)
        .eq('store_id', session.storeId!)
        .isFilter('clock_out', null)
        .maybeSingle();
    return res;
  } catch (_) { return null; }
});


/// Ca trong tháng chỉ định (dùng family — key = DateTime tương thích mọi Riverpod version)
final _monthlyShiftsProvider = FutureProvider.autoDispose
    .family<List<ShiftRecord>, DateTime>((ref, month) async {
  final session = ref.watch(sessionProvider);
  if (session?.storeId == null) return [];
  final isManager = session!.isOwner || session.role == 'manager';
  return StaffService.getShiftsForMonth(
    storeId: session.storeId!,
    userId:  isManager ? null : session.userId,
    year:    month.year,
    month:   month.month,
  );
});


// ─────────────────────────────────────────────────────────────────────────────
// MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class NhanVienScreen extends ConsumerStatefulWidget {
  const NhanVienScreen({super.key});
  @override
  ConsumerState<NhanVienScreen> createState() => _NhanVienScreenState();
}

class _NhanVienScreenState extends ConsumerState<NhanVienScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  StaffSyncService? _syncService;
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    final isManager = _isManager();
    _tab = TabController(length: isManager ? 2 : 1, vsync: this);
    _tab.addListener(() { if (mounted) setState(() => _tabIndex = _tab.index); });
    SchedulerBinding.instance.addPostFrameCallback((_) => _startSync());
  }

  Future<void> _startSync() async {
    final session = ref.read(sessionProvider);
    if (session?.storeId == null) return;
    final isManager = session!.isOwner || session.role == 'owner' || session.role == 'manager';
    if (isManager) return; // manager broadcast, không cần lắng nghe
    _syncService = StaffSyncService(
      storeId:       session.storeId!,
      currentUserId: session.userId,
      currentRole:   session.role ?? 'cashier',
      onRoleChanged: (newRole) {
        if (!mounted) return;
        final roleEntry = _roles[newRole];
        final label = roleEntry != null ? roleEntry.$1 : newRole;
        _showSyncBanner('🔄 Vai trò của bạn đã đổi sang: $label');
        // Cập nhật session → MainShell tự rebuild tabs ngay
        final currentSession = ref.read(sessionProvider);
        if (currentSession != null) {
          ref.read(sessionProvider.notifier).setSession(
            SessionData(
              userId:      currentSession.userId,
              phone:       currentSession.phone,
              displayName: currentSession.displayName,
              storeId:     currentSession.storeId,
              storeName:   currentSession.storeName,
              storeCode:   currentSession.storeCode,
              role:        newRole,
              isOwner:     currentSession.isOwner,
            ),
          );
        }
        ref.invalidate(_staffListProvider);
        ref.invalidate(storeRolesProvider);
      },
      onPermsChanged: () {
        if (!mounted) return;
        // 🔄 Bump version → _staffPermsProvider tự refetch → Dashboard rebuild
        ref.read(permsVersionProvider.notifier).bump();
        // 🔄 Invalidate action-level cache → PermissionGuard & canDo() refetch ngay
        ref.invalidate(userActionPermsProvider);
        _showSyncBanner('⚡ Quyền truy cập của bạn vừa được cập nhật');
      },
      onRemoved: () {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Bạn đã bị xoá khỏi quán',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            content: const Text('Liên hệ quản lý để biết thêm chi tiết.'),
            actions: [TextButton(
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
              child: const Text('Đóng'))],
          ),
        );
      },
    );
    await _syncService!.start();
  }

  void _showSyncBanner(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showMaterialBanner(MaterialBanner(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      leading: const Icon(Icons.sync_rounded, color: _kNavy),
      backgroundColor: const Color(0xFFF0F4FF),
      actions: [
        TextButton(
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
          child: const Text('Đóng')),
      ],
    ));
    // ⭐ Auto-dismiss sau 3 giây — tránh block UI
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
    });
  }

  bool _isManager() {
    final s = ref.read(sessionProvider);
    return s?.isOwner == true || s?.role == 'owner' || s?.role == 'manager';
  }

  @override
  void dispose() {
    _syncService?.stop();
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session   = ref.watch(sessionProvider);
    final isManager = session?.isOwner == true || session?.role == 'owner' || session?.role == 'manager';

    final mainContent = NestedScrollView(
      headerSliverBuilder: (_, __) => [_buildAppBar(isManager)],
      body: TabBarView(
        controller: _tab,
        children: [
          _StaffListTab(isManager: isManager),
          if (isManager) _PermissionsTab(),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: _kCream,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(children: [
              Expanded(flex: 3, child: mainContent),
              SizedBox(
                width: 280,
                child: _StaffRightPanel(
                  staffAsync: ref.watch(_staffListProvider),
                ),
              ),
            ]);
          }
          return mainContent;
        },
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              heroTag: 'nhan_vien_fab',
              onPressed: () => _tabIndex == 0
                  ? _showAddStaffSheet(context)
                  : Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const RoleManagerScreen()))
                      .then((_) => ref.invalidate(storeRolesProvider)),
              backgroundColor: _kNavy,
              icon: Icon(_tabIndex == 0
                  ? Icons.person_add_rounded
                  : Icons.manage_accounts_rounded,
                  color: Colors.white),
              label: Text(_tabIndex == 0 ? 'Thêm nhân viên' : 'Quản lý vai trò',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  SliverAppBar _buildAppBar(bool isManager) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 120,
      backgroundColor: _kNavy,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1C2151), Color(0xFF2D3180)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Nhân Viên',
                    style: TextStyle(color: Colors.white, fontSize: 24,
                      fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  Consumer(builder: (_, ref, __) {
                    final list = ref.watch(_staffListProvider);
                    final count = list.value?.length ?? 0;
                    final active = list.value?.where((s) => s.isClockedIn).length ?? 0;
                    return Text('$count thành viên • $active đang làm ca',
                      style: const TextStyle(color: Colors.white70, fontSize: 13));
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
      bottom: TabBar(
        controller: _tab,
        indicatorColor: _kOrange,
        indicatorWeight: 3,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white54,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: [
          const Tab(text: 'Nhân viên'),
          if (isManager) const Tab(text: 'Phân quyền'),
        ],
      ),
    );
  }

  void _showAddStaffSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddStaffSheet(onAdded: () {
        ref.invalidate(_staffListProvider);
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 1: DANH SÁCH NHÂN VIÊN
// ─────────────────────────────────────────────────────────────────────────────
class _StaffListTab extends ConsumerStatefulWidget {
  final bool isManager;
  const _StaffListTab({required this.isManager});
  @override
  ConsumerState<_StaffListTab> createState() => _StaffListTabState();
}

class _StaffListTabState extends ConsumerState<_StaffListTab> {
  final _searchCtrl = TextEditingController();
  String _query     = '';
  String _roleFilter = 'all';
  RealtimeChannel? _shiftsChannel;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _subscribeShifts();
      // Refresh mỗi 30s — fallback khi Realtime chưa bật trên Supabase
      _refreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) { if (mounted) ref.invalidate(_staffListProvider); },
      );
    });
  }

  void _subscribeShifts() {
    final session = ref.read(sessionProvider);
    final storeId = session?.storeId;
    if (storeId == null) return;
    try {
      // Lắng nghe Broadcast (không cần cấu hình DB Realtime)
      _shiftsChannel = Supabase.instance.client
          .channel('shifts:$storeId')
          .onBroadcast(
            event: 'shift_changed',
            callback: (_) {
              if (mounted) ref.invalidate(_staffListProvider);
            },
          )
          .subscribe();
    } catch (_) {}
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _shiftsChannel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_staffListProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Lỗi: $e')),
      data: (all) {
        // ── Filter ──
        final list = all.where((m) {
          final matchRole   = _roleFilter == 'all' || m.role == _roleFilter;
          final matchSearch = _query.isEmpty
              || m.name.toLowerCase().contains(_query.toLowerCase())
              || m.phone.contains(_query);
          return matchRole && matchSearch;
        }).toList();

        return Column(children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Tìm theo tên hoặc SĐT...',
                hintStyle: const TextStyle(color: _kMuted, fontSize: 13),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _kMuted),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: _kMuted),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); })
                    : null,
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          // ── Role filter chips ──
          Consumer(builder: (_, ref, __) {
            final roles = ref.watch(storeRolesProvider).value ?? [];
            return SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                children: [
                  _FilterChip('all', 'Tất cả', Icons.people_rounded, null),
                  // Custom roles từ Supabase
                  ...roles.map((r) {
                    final icon = <String, IconData>{
                      'badge': Icons.badge_rounded, 'star': Icons.star_rounded,
                      'kitchen': Icons.local_fire_department_rounded,
                      'point_of_sale': Icons.point_of_sale_rounded,
                      'inventory': Icons.inventory_2_rounded,
                      'table_bar': Icons.table_bar_rounded,
                      'room_service': Icons.room_service_rounded,
                      'manage_accounts': Icons.manage_accounts_rounded,
                      'local_cafe': Icons.local_cafe_rounded,
                      'security': Icons.security_rounded,
                    }[r.icon] ?? Icons.badge_rounded;
                    return _FilterChip(r.name, r.name, icon, r.colorValue);
                  }),
                ],
              ),
            );
          }),
          // ── Danh sách ──
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off_rounded, size: 48,
                        color: _kMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(
                        all.isEmpty ? 'Chưa có nhân viên nào' : 'Không tìm thấy kết quả',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _kNavy)),
                      if (all.isEmpty && widget.isManager) ...[ 
                        const SizedBox(height: 6),
                        const Text('Nhấn + Thêm nhân viên để bắt đầu',
                          style: TextStyle(fontSize: 13, color: _kMuted)),
                      ],
                    ]),
                  )
                : RefreshIndicator(
                    color: _kNavy,
                    onRefresh: () async {
                      ref.invalidate(_staffListProvider);
                      await ref.read(_staffListProvider.future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: list.length,
                      itemBuilder: (_, i) => _StaffCard(
                        member: list[i],
                        isManager: widget.isManager,
                        onChanged: () => ref.invalidate(_staffListProvider),
                      ),
                    ),
                  ),
          ),
        ]);
      },
    );
  }

  Widget _FilterChip(String key, String label, IconData icon, Color? color) {
    final selected = _roleFilter == key;
    final c = color ?? _kNavy;
    return GestureDetector(
      onTap: () => setState(() => _roleFilter = key),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: selected ? c : _kMuted),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? c : _kMuted)),
        ]),
      ),
    );
  }
}

class _EmptyStaff extends StatelessWidget {
  final bool isManager;
  const _EmptyStaff({required this.isManager});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.people_outline_rounded, size: 72, color: _kMuted.withValues(alpha: 0.5)),
      const SizedBox(height: 16),
      const Text('Chưa có nhân viên nào',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _kNavy)),
      if (isManager) const SizedBox(height: 8),
      if (isManager) const Text('Nhấn + Thêm nhân viên để bắt đầu',
        style: TextStyle(fontSize: 13, color: _kMuted)),
    ]),
  );
}

class _StaffCard extends ConsumerWidget {
  final StaffMember member;
  final bool isManager;
  final VoidCallback onChanged;
  const _StaffCard({required this.member, required this.isManager, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storeRoles = ref.watch(storeRolesProvider).value ?? [];
    final resolved  = member.isOwner
        ? (name: 'Chủ quán', color: const Color(0xFFFF6B35), icon: Icons.star_rounded)
        : _resolveRole(member.role, storeRoles);
    final initial   = member.name.isNotEmpty ? member.name[0].toUpperCase() : '?';
    final roleColor = resolved.color;

    return GestureDetector(
      onTap: () => _openDetail(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(children: [
              // Left accent stripe
              Container(width: 4, color: roleColor),
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    // Avatar tròn
                    Stack(children: [
                      Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text(initial,
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: roleColor))),
                      ),
                    ]),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(member.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
                        const SizedBox(height: 2),
                        Text(member.phone,
                          style: const TextStyle(fontSize: 12, color: _kMuted)),
                        const SizedBox(height: 5),
                        // Status row
                        Row(children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 7, height: 7,
                            decoration: BoxDecoration(
                              color: member.isClockedIn
                                  ? const Color(0xFF22C55E)
                                  : const Color(0xFF9CA3AF),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            member.isClockedIn ? 'Đang làm ca' : 'Chưa vào ca',
                            style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: member.isClockedIn
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ]),
                      ],
                    )),
                    // Role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: roleColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(resolved.name,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: roleColor)),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffDetailSheet(
        member: member,
        isManager: isManager,
        onChanged: onChanged,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET: THÊM NHÂN VIÊN
// ─────────────────────────────────────────────────────────────────────────────
class _AddStaffSheet extends ConsumerStatefulWidget {
  final VoidCallback onAdded;
  const _AddStaffSheet({required this.onAdded});
  @override
  ConsumerState<_AddStaffSheet> createState() => _AddStaffSheetState();
}

class _AddStaffSheetState extends ConsumerState<_AddStaffSheet> {
  final _phoneCtrl = TextEditingController();
  String _role = 'cashier';
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
        MediaQuery.of(context).viewInsets.bottom + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Handle
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        const Text('Thêm nhân viên',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kNavy)),
        const SizedBox(height: 4),
        const Text('Nhân viên cần đăng ký tài khoản trước',
          style: TextStyle(fontSize: 12, color: _kMuted)),
        const SizedBox(height: 20),
        // Phone field
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: 'Số điện thoại nhân viên',
            prefixIcon: const Icon(Icons.phone_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 14),
        // Role picker — load từ store_roles động
        ref.watch(storeRolesProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error:   (_, __) => const SizedBox.shrink(),
          data: (roles) {
            // Đảm bảo giá trị đang chọn còn hợp lệ
            if (roles.isNotEmpty && !roles.any((r) => r.name == _role)) {
              SchedulerBinding.instance.addPostFrameCallback(
                (_) => setState(() => _role = roles.first.name));
            }
            if (roles.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Chưa có vai trò nào. Tạo vai trò trong tab Phân quyền trước.',
                    style: TextStyle(fontSize: 12, color: Colors.orange))),
                ]),
              );
            }
            return DropdownButtonFormField<String>(
              value: roles.any((r) => r.name == _role) ? _role : roles.first.name,
              decoration: InputDecoration(
                labelText: 'Vai trò',
                prefixIcon: const Icon(Icons.badge_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              // ‼️ FIX Bug #31: loại bỏ role 'owner' khỏi dropdown
              // Manager không được phép gán role chủ quán cho người mới
              items: roles
                  .where((r) => r.name.toLowerCase() != 'owner')
                  .map((r) => DropdownMenuItem(
                    value: r.name,
                    child: Text(r.name)))
                  .toList(),
              onChanged: (v) { if (v != null) setState(() => _role = v); },
            );
          },
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kNavy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: _loading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Thêm vào quán',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) { setState(() => _error = 'Nhập số điện thoại'); return; }

    // Dismiss keyboard để thấy kết quả rõ hơn
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });

    try {
      final session = ref.read(sessionProvider);
      if (session?.storeId == null) {
        setState(() { _loading = false; _error = 'Không tìm thấy thông tin quán. Vui lòng đăng nhập lại.'; });
        return;
      }
      final result = await StaffService.addStaffByPhone(
        storeId: session!.storeId!,
        phone:   phone,
        role:    _role,
        addedByUserId: session.userId,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (result.isSuccess) {
        widget.onAdded();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Đã thêm ${result.userName}'),
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        // Hiện lỗi cả inline lẫn SnackBar để chắc user thấy
        setState(() => _error = result.errorMessage);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(result.errorMessage ?? 'Có lỗi xảy ra'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = 'Lỗi: $e';
      setState(() { _loading = false; _error = msg; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET: CHI TIẾT NHÂN VIÊN
// ─────────────────────────────────────────────────────────────────────────────
class _StaffDetailSheet extends ConsumerStatefulWidget {
  final StaffMember member;
  final bool isManager;
  final VoidCallback onChanged;
  const _StaffDetailSheet({required this.member, required this.isManager, required this.onChanged});
  @override
  ConsumerState<_StaffDetailSheet> createState() => _StaffDetailSheetState();
}

class _StaffDetailSheetState extends ConsumerState<_StaffDetailSheet>
    with SingleTickerProviderStateMixin {
  late String _role;
  bool _saving = false;
  bool _editMode = false; // toggle edit profile

  // Profile form controllers
  late final TextEditingController _jobDescCtrl;
  late final TextEditingController _baseSalaryCtrl;
  late final TextEditingController _hourlyRateCtrl;
  late final TextEditingController _startDateCtrl;

  @override
  void initState() {
    super.initState();
    final m = widget.member;
    _role = m.role;
    _jobDescCtrl    = TextEditingController(text: m.jobDesc);
    _baseSalaryCtrl = TextEditingController(
        text: m.baseSalary > 0 ? m.baseSalary.toInt().toString() : '');
    _hourlyRateCtrl = TextEditingController(
        text: m.hourlyRate > 0 ? m.hourlyRate.toInt().toString() : '');
    _startDateCtrl  = TextEditingController(text: m.startDate ?? '');
  }

  @override
  void dispose() {
    _jobDescCtrl.dispose();
    _baseSalaryCtrl.dispose();
    _hourlyRateCtrl.dispose();
    _startDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m        = widget.member;
    // ‼️ FIX: Dùng storeRolesProvider thay vì _roles hardcode
    // — _roles chỉ có hardcode role cũ (cashier/waiter/...), custom role sẽ hiện sai màu
    final storeRoles = ref.watch(storeRolesProvider).value ?? [];
    final resolved   = m.isOwner
        ? (name: 'Chủ quán', color: const Color(0xFFFF6B35), icon: Icons.star_rounded)
        : _resolveRole(m.role, storeRoles);
    final roleColor  = resolved.color;
    final initial    = m.name.isNotEmpty ? m.name[0].toUpperCase() : '?';

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ListView(controller: ctrl, padding: const EdgeInsets.all(20), children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          // ── Header: Avatar + Info ──
          Row(children: [
            Container(width: 60, height: 60,
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Center(child: Text(initial,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: roleColor)))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _kNavy)),
              Text(m.phone, style: const TextStyle(fontSize: 13, color: _kMuted)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: roleColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(resolved.name,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: roleColor)),
                ),
                const SizedBox(width: 6),
                // Quán
                Text('· ${ref.read(sessionProvider)?.storeName ?? ''}',
                  style: const TextStyle(fontSize: 11, color: _kMuted)),
              ]),
            ])),
            // Trạng thái + nút sửa
            Column(children: [
              Row(children: [
                Icon(Icons.circle, size: 10,
                  color: m.isClockedIn ? const Color(0xFF22C55E) : Colors.grey.shade400),
                const SizedBox(width: 4),
                Text(m.isClockedIn ? 'Đang làm' : 'Nghỉ',
                  style: TextStyle(fontSize: 10,
                    color: m.isClockedIn ? const Color(0xFF22C55E) : _kMuted)),
              ]),
              if (widget.isManager && !m.isOwner) ...[ 
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() => _editMode = !_editMode),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _editMode ? _kOrange.withValues(alpha: 0.12) : _kNavy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_editMode ? 'Xong' : 'Sửa',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: _editMode ? _kOrange : _kNavy)),
                  ),
                ),
              ],
            ]),
          ]),

          const SizedBox(height: 20),
          const Divider(),

          // ── Hồ sơ (view / edit) ──
          const SizedBox(height: 12),
          _sectionLabel('Hồ sơ nhân viên'),
          const SizedBox(height: 12),

          if (_editMode && widget.isManager && !m.isOwner) ...[
            // ── EDIT MODE ──
            _fieldLabel('Mô tả công việc'),
            const SizedBox(height: 6),
            TextField(
              controller: _jobDescCtrl,
              maxLines: 3,
              decoration: _inputDec('Nhập mô tả...', Icons.work_outline_rounded),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Lương cơ bản (đ/tháng)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _baseSalaryCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDec('0', Icons.payments_outlined),
                ),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _fieldLabel('Lương/giờ (đ)'),
                const SizedBox(height: 6),
                TextField(
                  controller: _hourlyRateCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDec('0', Icons.access_time_rounded),
                ),
              ])),
            ]),
            const SizedBox(height: 14),
            _fieldLabel('Ngày bắt đầu'),
            const SizedBox(height: 6),
            TextField(
              controller: _startDateCtrl,
              readOnly: true,
              decoration: _inputDec('Chọn ngày', Icons.calendar_today_rounded),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.tryParse(_startDateCtrl.text) ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  locale: const Locale('vi'),
                );
                if (picked != null) {
                  _startDateCtrl.text = picked.toIso8601String().split('T').first;
                }
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded, size: 18),
                label: const Text('Lưu hồ sơ',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
          ] else ...[ 
            // ── VIEW MODE ──
            if (m.jobDesc.isNotEmpty) ...[ 
              _fieldLabel('Mô tả công việc'),
              const SizedBox(height: 6),
              Text(m.jobDesc, style: const TextStyle(fontSize: 14, color: _kNavy, height: 1.5)),
              const SizedBox(height: 14),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: _kMuted),
                  const SizedBox(width: 8),
                  Text(widget.isManager ? 'Nhấn "Sửa" để thêm mô tả' : 'Chưa có mô tả công việc',
                    style: const TextStyle(fontSize: 13, color: _kMuted)),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            Row(children: [
              _InfoChip('Lương cơ bản', m.baseSalary > 0 ? '${_fmtMoney(m.baseSalary)}đ' : '—'),
              const SizedBox(width: 8),
              _InfoChip('Lương/giờ', m.hourlyRate > 0 ? '${_fmtMoney(m.hourlyRate)}đ' : '—'),
            ]),
            if (m.startDate != null) ...[ 
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: _kMuted),
                const SizedBox(width: 6),
                Text('Bắt đầu: ${_fmtDate(m.startDate!)}',
                  style: const TextStyle(fontSize: 12, color: _kMuted)),
              ]),
            ],
          ],

          // ── Đổi vai trò + xoá (manager only) ──
          if (widget.isManager && !m.isOwner) ...[ 
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _sectionLabel('Vai trò & Quyền hạn'),
            const SizedBox(height: 10),
            // Dropdown vai trò — dùng store_roles động
            ref.watch(storeRolesProvider).when(
              loading: () => const SizedBox(height: 56,
                child: Center(child: LinearProgressIndicator())),
              error: (_, __) => const SizedBox.shrink(),
              data: (storeRoles) {
                // Đảm bảo _role hợp lệ
                final validRole = storeRoles.any((r) => r.name == _role)
                    ? _role
                    : (storeRoles.isNotEmpty ? storeRoles.first.name : _role);

                if (storeRoles.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: const Text(
                      '⚠️ Chưa có vai trò nào. Tạo vai trò trong tab Phân quyền trước.',
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                  );
                }

                return DropdownButtonFormField<String>(
                  value: validRole,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    prefixIcon: const Icon(Icons.badge_rounded),
                  ),
                  // ‼️ FIX Bug #31: loại bỏ role 'owner' khỏi dropdown đổi vai trò
                  // Tránh việc manager tự câp quyền owner cho NV khác
                  items: storeRoles
                      .where((r) => r.name.toLowerCase() != 'owner')
                      .map((r) => DropdownMenuItem(
                    value: r.name,
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: r.colorValue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(r.name),
                    ]),
                  )).toList(),
                  onChanged: (v) { if (v != null) setState(() => _role = v); },
                );
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: ElevatedButton.icon(
                onPressed: _saving ? null : _saveRole,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _saving
                    ? const SizedBox(height: 16, width: 16,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.check_rounded, size: 16),
                label: const Text('Lưu vai trò'),
              )),
              const SizedBox(width: 8),
              // ‼️ FIX Bug #29: ẩn nút Xóa nếu member là chủ quán (isOwner=true)
              // Manager không được phép xóa chủ quán — lỗ hổng bảo mật
              if (!widget.member.isOwner)
                OutlinedButton.icon(
                  onPressed: _confirmRemove,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.person_remove_rounded, size: 16),
                  label: const Text('Xóa'),
                ),
            ]),

          ],

          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  // ── Helpers UI ──
  Widget _sectionLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 13, color: _kMuted, fontWeight: FontWeight.w700));
  Widget _fieldLabel(String text) => Text(text,
    style: const TextStyle(fontSize: 12, color: _kMuted, fontWeight: FontWeight.w600));
  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    prefixIcon: Icon(icon, size: 18),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  // ── Actions ──
  Future<void> _saveProfile() async {
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    await StaffService.updateProfile(
      storeId:    session!.storeId!,
      userId:     widget.member.userId,
      jobDesc:    _jobDescCtrl.text.trim(),
      baseSalary: double.tryParse(_baseSalaryCtrl.text.replaceAll(',', '')) ?? widget.member.baseSalary,
      hourlyRate: double.tryParse(_hourlyRateCtrl.text.replaceAll(',', '')) ?? widget.member.hourlyRate,
      // ‼️ FIX: truyền start_date xuống DB — trước đây bị bỏ quên dù UI đã có date picker
      startDate: _startDateCtrl.text.isNotEmpty ? _startDateCtrl.text : null,
    );
    if (!mounted) return;
    setState(() { _saving = false; _editMode = false; });
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Đã cập nhật hồ sơ'),
        behavior: SnackBarBehavior.floating));
  }

  Future<void> _saveRole() async {
    if (_role == widget.member.role) return;
    // ‼️ FIX Bug #31: double guard — không bao giờ assign role 'owner'
    // Tránh manager leo thang đặc quyền thông qua API trực tiếp
    if (_role.toLowerCase() == 'owner') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể gán vai trò Chủ quán'),
          backgroundColor: Colors.red, behavior: SnackBarBehavior.floating));
      return;
    }
    setState(() => _saving = true);
    final session = ref.read(sessionProvider);
    await StaffService.updateRole(
      storeId: session!.storeId!,
      userId: widget.member.userId,
      newRole: _role,
      changedByUserId: session.userId,
      oldRole: widget.member.role,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    Navigator.pop(context);
    widget.onChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Đã cập nhật vai trò'),
        behavior: SnackBarBehavior.floating));
  }

  void _confirmRemove() {
    // ‼️ FIX Bug #29: double guard — không bao giờ xóa chủ quán
    if (widget.member.isOwner) return;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Xoá ${widget.member.name}?',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: const Text('Nhân viên sẽ không còn truy cập quán này.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Huỷ')),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final session = ref.read(sessionProvider);
            await StaffService.removeStaff(
              storeId:         session!.storeId!,
              userId:          widget.member.userId,
              removedByUserId: session.userId,
              staffName:       widget.member.name,
            );
            if (!mounted) return;
            Navigator.pop(context);
            widget.onChanged();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Xoá'),
        ),
      ],
    ));
  }

  String _fmtMoney(double v) => NumberFormat('#,###').format(v.toInt());
  String _fmtDate(String iso) {
    try {
      final d = DateTime.parse(iso);
      return DateFormat('dd/MM/yyyy').format(d);
    } catch (_) { return iso; }
  }
}

Widget _InfoChip(String label, String value) => Expanded(
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3E0),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: _kMuted)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
    ]),
  ),
);

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: CHẤM CÔNG
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftsTab extends ConsumerStatefulWidget {
  final bool isManager;
  const _ShiftsTab({required this.isManager});
  @override
  ConsumerState<_ShiftsTab> createState() => _ShiftsTabState();
}

class _ShiftsTabState extends ConsumerState<_ShiftsTab> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _prevMonth() => setState(() =>
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1));

  void _nextMonth() => setState(() =>
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));

  @override
  Widget build(BuildContext context) {
    final shiftsAsync = ref.watch(_shiftsProvider);
    final monthlyAsync = ref.watch(_monthlyShiftsProvider(_selectedMonth));
    ref.watch(sessionProvider); // watch để rebuild khi session thay đổi

    final now = DateTime.now();
    final isThisMonth = _selectedMonth.year == now.year && _selectedMonth.month == now.month;
    final monthLabel = 'Tháng ${_selectedMonth.month}/${_selectedMonth.year}';
    final isManager = widget.isManager;

    return CustomScrollView(
      slivers: [
        // ── Card chấm công ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _ClockCard(),
          ),
        ),
        // ── Thống kê tháng ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorder),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(children: [
                // ── Header tháng ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                  child: Row(children: [
                    const Icon(Icons.bar_chart_rounded, size: 16, color: _kNavy),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Thống kê $monthLabel',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, size: 20),
                      onPressed: _prevMonth,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      color: _kMuted,
                    ),
                    IconButton(
                      icon: Icon(Icons.chevron_right_rounded, size: 20,
                        color: isThisMonth ? _kBorder : _kMuted),
                      onPressed: isThisMonth ? null : _nextMonth,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ]),
                ),
                const Divider(height: 1),
                // ── Số liệu ──
                monthlyAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Không tải được dữ liệu',
                      style: TextStyle(color: _kMuted, fontSize: 13)),
                  ),
                  data: (monthShifts) {
                    final done = monthShifts.where((s) => !s.isOpen).toList();
                    final totalMins = done.fold<int>(
                      0, (sum, s) => sum + s.duration.inMinutes);
                    final totalH = totalMins / 60.0;
                    final cntDone = done.length;
                    final cntOpen = monthShifts.where((s) => s.isOpen).length;
                    final uniqueStaff = monthShifts.map((s) => s.userId).toSet().length;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Row(children: [
                        _StatItem(
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFF1D4ED8),
                          value: '${totalH.toStringAsFixed(1)}h',
                          label: 'Giờ làm',
                        ),
                        Container(width: 1, height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 8), color: _kBorder),
                        _StatItem(
                          icon: Icons.calendar_view_week_rounded,
                          color: const Color(0xFF065F46),
                          value: '$cntDone ca',
                          label: cntOpen > 0 ? '+$cntOpen đang mở' : 'hoàn thành',
                        ),
                        Container(width: 1, height: 44,
                          margin: const EdgeInsets.symmetric(horizontal: 8), color: _kBorder),
                        _StatItem(
                          icon: isManager ? Icons.people_rounded : Icons.access_time_rounded,
                          color: const Color(0xFF92400E),
                          value: isManager
                              ? '$uniqueStaff NV'
                              : (cntDone > 0
                                  ? '${(totalH / cntDone).toStringAsFixed(1)}h'
                                  : '—'),
                          label: isManager ? 'có ca tháng này' : 'TB/ca',
                        ),
                      ]),
                    );
                  },
                ),
              ]),
            ),
          ),
        ),
        // ── Tiêu đề lịch sử ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(children: [
              const Icon(Icons.history_rounded, size: 16, color: _kMuted),
              const SizedBox(width: 6),
              Text(
                isManager ? 'Lịch sử toàn bộ nhân viên' : 'Lịch sử ca của bạn',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kMuted),
              ),
            ]),
          ),
        ),
        // ── Danh sách ca ──
        shiftsAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 32),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(child: Text('Lỗi: $e')),
          ),
          data: (shifts) => shifts.isEmpty
              ? const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Center(
                      child: Text('Chưa có ca làm việc nào',
                        style: TextStyle(color: _kMuted)),
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _ShiftCard(shift: shifts[i], showName: isManager),
                      childCount: shifts.length,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   value;
  final String   label;
  const _StatItem({required this.icon, required this.color,
    required this.value, required this.label});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: const TextStyle(fontSize: 10, color: _kMuted), textAlign: TextAlign.center),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CLOCK IN / OUT CARD — Card chính với timer đếm giờ
// ─────────────────────────────────────────────────────────────────────────────
class _ClockCard extends ConsumerStatefulWidget {
  const _ClockCard();
  @override
  ConsumerState<_ClockCard> createState() => _ClockCardState();
}

class _ClockCardState extends ConsumerState<_ClockCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  bool _loading = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime clockIn) {
    _timer?.cancel();
    _elapsed = DateTime.now().difference(clockIn);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed = DateTime.now().difference(clockIn));
    });
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}g ${m.toString().padLeft(2, '0')}p ${s.toString().padLeft(2, '0')}s';
    return '${m.toString().padLeft(2, '0')}p ${s.toString().padLeft(2, '0')}s';
  }

  Future<void> _clockIn() async {
    final session = ref.read(sessionProvider);
    if (session?.storeId == null) return;
    setState(() => _loading = true);
    await StaffService.clockIn(session!.userId, session.storeId!);
    if (!mounted) return;
    setState(() => _loading = false);
    ref.invalidate(_openShiftProvider);
    ref.invalidate(_shiftsProvider);
    ref.invalidate(_staffListProvider);
    HapticFeedback.mediumImpact();
  }

  Future<void> _clockOut(String shiftId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Kết thúc ca?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Text('Thời gian làm: ${_formatElapsed(_elapsed)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tiếp tục làm')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Kết thúc ca'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    await StaffService.clockOut(shiftId);
    _timer?.cancel();
    if (!mounted) return;
    setState(() { _loading = false; _elapsed = Duration.zero; });
    ref.invalidate(_openShiftProvider);
    ref.invalidate(_shiftsProvider);
    ref.invalidate(_staffListProvider);
    HapticFeedback.mediumImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Ca làm việc đã kết thúc'),
          behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final openAsync = ref.watch(_openShiftProvider);

    return openAsync.when(
      loading: () => _buildShell(child: const Center(
        child: SizedBox(height: 20, width: 20,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)))),
      error: (_, __) => const SizedBox.shrink(),
      data: (shift) {
        final isClockedIn = shift != null;

        // Bắt timer khi phát hiện ca đang mở
        if (isClockedIn) {
          // ‼️ FIX: parse UTC → toLocal để tính elapsed đúng với DateTime.now() (local)
          final clockIn = DateTime.parse(shift['clock_in'] as String).toLocal();
          if (_timer == null || !_timer!.isActive) {
            WidgetsBinding.instance.addPostFrameCallback((_) => _startTimer(clockIn));
          }
        } else {
          _timer?.cancel();
        }

        return _buildShell(
          isClockedIn: isClockedIn,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Icon + trạng thái
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isClockedIn ? Icons.timer_rounded : Icons.login_rounded,
                  color: Colors.white, size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  isClockedIn ? 'Đang trong ca' : 'Chưa bắt đầu ca',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (isClockedIn)
                  Text(
                    _formatElapsed(_elapsed),
                    style: const TextStyle(color: Colors.white, fontSize: 26,
                      fontWeight: FontWeight.w900, letterSpacing: -1),
                  )
                else
                  const Text('Nhấn để bắt đầu ca làm việc',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              ]),
            ]),
            if (isClockedIn) ...[ 
              const SizedBox(height: 6),
              Text(
                'Bắt đầu lúc ${DateFormat('HH:mm').format(DateTime.parse(shift['clock_in'] as String).toLocal())}',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            // Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : () {
                  if (isClockedIn) _clockOut(shift['id'] as String);
                  else _clockIn();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isClockedIn ? _kOrange : Colors.white,
                  foregroundColor: isClockedIn ? Colors.white : _kNavy,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _loading
                    ? const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(isClockedIn ? Icons.logout_rounded : Icons.login_rounded, size: 18),
                label: Text(
                  isClockedIn ? 'Kết thúc ca' : 'Bắt đầu ca',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildShell({required Widget child, bool isClockedIn = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isClockedIn
              ? [const Color(0xFF065F46), const Color(0xFF047857)]
              : [const Color(0xFF1C2151), const Color(0xFF2D3180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isClockedIn ? const Color(0xFF065F46) : _kNavy).withValues(alpha: 0.4),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ShiftCard extends ConsumerStatefulWidget {
  final ShiftRecord shift;
  final bool showName; // true = manager view (hiện tên + nút sửa)
  const _ShiftCard({required this.shift, required this.showName});
  @override
  ConsumerState<_ShiftCard> createState() => _ShiftCardState();
}

class _ShiftCardState extends ConsumerState<_ShiftCard> {
  bool _saving = false;

  Future<void> _editShift(BuildContext ctx) async {
    final s = widget.shift;
    DateTime newIn  = s.clockIn.toLocal();
    DateTime newOut = (s.clockOut ?? DateTime.now()).toLocal();

    // Dialog sửa giờ
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dctx) => _EditShiftDialog(
        initialIn:  newIn,
        initialOut: newOut,
        isOpen:     s.isOpen,
        onChanged: (ci, co) { newIn = ci; newOut = co; },
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    await StaffService.updateShift(
      s.id,
      clockIn:  newIn,
      clockOut: s.isOpen ? null : newOut,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    // Refresh dữ liệu
    ref.invalidate(_shiftsProvider);
    ref.invalidate(_monthlyShiftsProvider(
      DateTime(s.clockIn.year, s.clockIn.month)));
    ScaffoldMessenger.of(ctx).showSnackBar(
      const SnackBar(content: Text('✅ Đã cập nhật giờ ca'),
        behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final s       = widget.shift;
    final fmt     = DateFormat('HH:mm');
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: s.isOpen
                ? const Color(0xFF22C55E).withValues(alpha: 0.1)
                : _kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: _saving
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(
                  s.isOpen ? Icons.login_rounded : Icons.access_time_rounded,
                  color: s.isOpen ? const Color(0xFF22C55E) : _kNavy, size: 22,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (widget.showName) Text(s.userName,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _kNavy)),
          Text(dateFmt.format(s.clockIn),
            style: const TextStyle(fontSize: 12, color: _kMuted)),
          Text('${fmt.format(s.clockIn)} → ${s.clockOut != null ? fmt.format(s.clockOut!) : "Đang làm"}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kNavy)),
        ])),
        // Nút sửa — chỉ manager, không sửa ca đang mở
        if (widget.showName && !s.isOpen) ...[
          const SizedBox(width: 6),
          GestureDetector(
            onTap: _saving ? null : () => _editShift(context),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.edit_rounded, size: 14, color: _kNavy),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: s.isOpen
                ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                : _kNavy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            s.isOpen ? 'Đang ca' : s.durationStr,
            style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: s.isOpen ? const Color(0xFF22C55E) : _kNavy),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT SHIFT DIALOG — Manager sửa giờ vào/ra
// ─────────────────────────────────────────────────────────────────────────────
class _EditShiftDialog extends StatefulWidget {
  final DateTime initialIn;
  final DateTime initialOut;
  final bool isOpen;
  final void Function(DateTime ci, DateTime co) onChanged;
  const _EditShiftDialog({
    required this.initialIn, required this.initialOut,
    required this.isOpen, required this.onChanged,
  });
  @override
  State<_EditShiftDialog> createState() => _EditShiftDialogState();
}

class _EditShiftDialogState extends State<_EditShiftDialog> {
  late DateTime _ci;
  late DateTime _co;

  static const _kNavy = Color(0xFF1E1C5E);

  @override
  void initState() {
    super.initState();
    _ci = widget.initialIn;
    _co = widget.initialOut;
  }

  Future<void> _pickTime(BuildContext ctx, bool isIn) async {
    final init  = isIn ? _ci : _co;
    final picked = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay(hour: init.hour, minute: init.minute),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
          colorScheme: const ColorScheme.light(primary: _kNavy)),
        child: child!),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isIn) {
        _ci = DateTime(_ci.year, _ci.month, _ci.day, picked.hour, picked.minute);
      } else {
        _co = DateTime(_co.year, _co.month, _co.day, picked.hour, picked.minute);
      }
    });
    widget.onChanged(_ci, _co);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('HH:mm dd/MM');
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: const [
        Icon(Icons.edit_calendar_rounded, color: _kNavy, size: 20),
        SizedBox(width: 8),
        Text('Sửa giờ ca', style: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: _kNavy)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        // Giờ vào
        _TimeRow(
          label: 'Giờ vào', icon: Icons.login_rounded,
          time: fmt.format(_ci), color: const Color(0xFF065F46),
          onTap: () => _pickTime(context, true),
        ),
        const SizedBox(height: 12),
        // Giờ ra (ẩn khi ca chưa đóng)
        if (!widget.isOpen)
          _TimeRow(
            label: 'Giờ ra', icon: Icons.logout_rounded,
            time: fmt.format(_co), color: const Color(0xFFB45309),
            onTap: () => _pickTime(context, false),
          ),
        if (_ci.isAfter(_co) && !widget.isOpen) ...[
          const SizedBox(height: 8),
          const Text('⚠️ Giờ vào phải trước giờ ra',
            style: TextStyle(fontSize: 12, color: Colors.red)),
        ],
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Huỷ')),
        ElevatedButton(
          onPressed: (!widget.isOpen && _ci.isAfter(_co))
              ? null
              : () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy, foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
          child: const Text('Lưu'),
        ),
      ],
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label, time;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TimeRow({required this.label, required this.time,
    required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
            fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(time, style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(width: 6),
        Icon(Icons.edit_rounded, size: 14, color: color.withValues(alpha: 0.5)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB 2: PHÂN QUYỀN — Embedded role list, tap → _RoleCard sheet
// ─────────────────────────────────────────────────────────────────────────────
class _PermissionsTab extends ConsumerWidget {
  const _PermissionsTab();

  static const _iconMap = <String, IconData>{
    // Nhân viên & quản lý
    'badge':            Icons.badge_rounded,
    'manage_accounts':  Icons.manage_accounts_rounded,
    'support_agent':    Icons.support_agent_rounded,
    'security':         Icons.security_rounded,
    'supervisor':       Icons.supervisor_account_rounded,
    'person':           Icons.person_rounded,
    'people':           Icons.people_rounded,
    'groups':           Icons.groups_rounded,
    // F&B
    'kitchen':          Icons.local_fire_department_rounded,
    'local_cafe':       Icons.local_cafe_rounded,
    'restaurant':       Icons.restaurant_rounded,
    'room_service':     Icons.room_service_rounded,
    'lunch_dining':     Icons.lunch_dining_rounded,
    'bakery':           Icons.bakery_dining_rounded,
    'ramen':            Icons.ramen_dining_rounded,
    'wine_bar':         Icons.wine_bar_rounded,
    'local_bar':        Icons.local_bar_rounded,
    'icecream':         Icons.icecream_rounded,
    'cake':             Icons.cake_rounded,
    // Bán hàng & thu ngân
    'point_of_sale':    Icons.point_of_sale_rounded,
    'storefront':       Icons.storefront_rounded,
    'shopping_cart':    Icons.shopping_cart_rounded,
    'receipt':          Icons.receipt_long_rounded,
    'payments':         Icons.payments_rounded,
    'local_atm':        Icons.local_atm_rounded,
    // Kho & vận chuyển
    'inventory':        Icons.inventory_2_rounded,
    'warehouse':        Icons.warehouse_rounded,
    'delivery':         Icons.delivery_dining_rounded,
    'local_shipping':   Icons.local_shipping_rounded,
    'forklift':         Icons.warehouse_rounded,
    // Bàn & dịch vụ
    'table_bar':        Icons.table_bar_rounded,
    'chair':            Icons.chair_rounded,
    'cleaning':         Icons.cleaning_services_rounded,
    // Kỹ thuật & khác
    'build':            Icons.build_rounded,
    'handyman':         Icons.handyman_rounded,
    'plumbing':         Icons.plumbing_rounded,
    'electrical':       Icons.electrical_services_rounded,
    'computer':         Icons.computer_rounded,
    'design_services':  Icons.design_services_rounded,
    // Chung
    'star':             Icons.star_rounded,
    'diamond':          Icons.diamond_rounded,
    'emoji_events':     Icons.emoji_events_rounded,
    'school':           Icons.school_rounded,
    'medical':          Icons.medical_services_rounded,
    'sports':           Icons.sports_rounded,
  };

  static const _modLabels = <String, String>{
    'pos': 'Bán hàng', 'kho': 'Kho', 'kho_pro': 'Kho CN',
    'ban': 'Bàn', 'kitchen': 'Bếp', 'finance': 'Thu chi', 'report': 'Báo cáo',
    'loyalty': 'Điểm', 'staff': 'Nhân viên', 'chamcong': 'Chấm công',
    'tinhluong': 'Lương', 'kay_ops': 'Vận hành', // ✅ FIX: thêm 2 module còn thiếu
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rolesAsync = ref.watch(storeRolesProvider);
    final session    = ref.watch(sessionProvider);

    return rolesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error:   (e, _) => Center(child: Text('Lỗi: $e')),
      data: (roles) {
        if (roles.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.shield_outlined, size: 56, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              const Text('Chưa có vai trò nào',
                style: TextStyle(fontWeight: FontWeight.w700, color: _kMuted)),
              const SizedBox(height: 6),
              const Text('Nhấn "Quản lý vai trò" để tạo mới',
                style: TextStyle(fontSize: 12, color: _kMuted)),
            ]),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            // ── Header vai trò ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C2151), Color(0xFF2D3180)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${roles.length} vai trò đang hoạt động',
                    style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.w800, fontSize: 15)),
                  const Text('Nhấn vào vai trò để chỉnh module',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
                ]),
              ]),
            ),
            const SizedBox(height: 14),
            ...roles.map((r) {
              final color    = r.colorValue;
              final iconData = _iconMap[r.icon] ?? Icons.badge_rounded;
              return GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RoleManagerScreen()))
                    .then((_) => ref.invalidate(storeRolesProvider)),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: IntrinsicHeight(
                      child: Row(children: [
                        Container(width: 4, color: color),
                        Expanded(
                          child: Padding(padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(iconData, color: color, size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r.name, style: TextStyle(
                                          fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                                      Text('${r.modules.length}/${_modLabels.length} module',
                                        style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w700,
                                          color: color.withValues(alpha: 0.75))),
                                    ],
                                  )),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                                      Text('Chỉnh', style: TextStyle(
                                          fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                                      const SizedBox(width: 3),
                                      Icon(Icons.tune_rounded, size: 12, color: color),
                                    ]),
                                  ),
                                ]),
                                if (r.modules.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Wrap(spacing: 6, runSpacing: 4,
                                    children: r.modules.take(5).map((m) =>
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: color.withValues(alpha: 0.08),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(_modLabels[m] ?? m,
                                          style: TextStyle(fontSize: 10,
                                              fontWeight: FontWeight.w600, color: color)),
                                      )
                                    ).toList()
                                    ..addAll(r.modules.length > 5
                                      ? [Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text('+${r.modules.length - 5}',
                                            style: const TextStyle(fontSize: 10,
                                                fontWeight: FontWeight.w600, color: _kMuted)),
                                        )]
                                      : []),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }),

            // ── Hành động nhạy cảm ──────────────────────────────────────────
            const SizedBox(height: 24),
            _ActionPermsSection(storeId: session?.storeId ?? ''),

            // ── Phân ca làm việc ──
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.schedule_rounded,
                    color: Color(0xFF0EA5E9), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Ca làm việc', style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w800, color: _kNavy)),
                  Text('Nhân viên ca nào thấy việc ca đó',
                      style: TextStyle(fontSize: 11, color: _kMuted)),
                ]),
              ),
              Consumer(builder: (ctx, r, _) {
                final s = r.watch(sessionProvider);
                return TextButton.icon(
                  onPressed: () => showModalBottomSheet(
                    context: ctx,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _ShiftFormSheet(
                      storeId: s?.storeId ?? '',
                      onSaved: () => r.invalidate(_shiftConfigsProvider),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Thêm ca'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF0EA5E9)),
                );
              }),
            ]),
            const SizedBox(height: 10),
            Consumer(builder: (ctx, r, _) {
              final async = r.watch(_shiftConfigsProvider);
              return async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Lỗi: $e'),
                data: (shifts) {
                  if (shifts.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: const Text('Chưa có ca nào. Nhấn "Thêm ca" để tạo.',
                          style: TextStyle(fontSize: 13, color: _kMuted)),
                    );
                  }
                  return Column(
                    children: shifts.map((s) => _ShiftConfigCard(
                      shift: s,
                      storeId: session?.storeId ?? '',
                      onRefresh: () => r.invalidate(_shiftConfigsProvider),
                      onEdit: () => showModalBottomSheet(
                        context: ctx,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => _ShiftFormSheet(
                          storeId: s.storeId,
                          existing: s,
                          onSaved: () => r.invalidate(_shiftConfigsProvider),
                        ),
                      ),
                      onDelete: () async {
                        await ShiftConfigService.deleteShift(s.id);
                        r.invalidate(_shiftConfigsProvider);
                      },
                    )).toList(),
                  );
                },
              );
            }),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET: SHIFT CONFIG CARD (có thêm/xoá nhân viên)
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftConfigCard extends StatefulWidget {
  final ShiftConfig shift;
  final String storeId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;
  const _ShiftConfigCard({
    required this.shift, required this.storeId,
    required this.onEdit, required this.onDelete, required this.onRefresh,
  });
  @override State<_ShiftConfigCard> createState() => _ShiftConfigCardState();
}

class _ShiftConfigCardState extends State<_ShiftConfigCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.shift.colorValue;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(children: [
          // ── Header ──
          IntrinsicHeight(
            child: Row(children: [
              Container(width: 4, color: c),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: c.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.schedule_rounded, color: c, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.shift.name, style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800, color: c)),
                        Text(widget.shift.timeLabel,
                            style: const TextStyle(fontSize: 12, color: _kMuted)),
                      ],
                    )),
                    // Nút expand xem nhân viên
                    GestureDetector(
                      onTap: () => setState(() => _expanded = !_expanded),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _expanded ? c.withValues(alpha: 0.08) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _expanded ? c.withValues(alpha: 0.4) : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.people_alt_rounded, size: 13,
                              color: _expanded ? c : _kMuted),
                          const SizedBox(width: 4),
                          Text('Nhân viên', style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700,
                            color: _expanded ? c : _kMuted,
                          )),
                          const SizedBox(width: 2),
                          Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                              size: 15, color: _expanded ? c : _kMuted),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, size: 18, color: _kMuted),
                      onPressed: widget.onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 18,
                          color: Colors.red.shade300),
                      onPressed: widget.onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ]),
                ),
              ),
            ]),
          ),
          // ── Panel nhân viên (expand) ──
          if (_expanded)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: _ShiftStaffPanel(
                shift: widget.shift,
                storeId: widget.storeId,
                accentColor: c,
                onChanged: widget.onRefresh,
              ),
            ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION PERMISSIONS SECTION
// Phần kiểm soát hành động nhạy cảm trong từng module (action-level)
// ─────────────────────────────────────────────────────────────────────────────
class _ActionPermsSection extends ConsumerStatefulWidget {
  final String storeId;
  const _ActionPermsSection({required this.storeId});
  @override
  ConsumerState<_ActionPermsSection> createState() => _ActionPermsSectionState();
}

class _ActionPermsSectionState extends ConsumerState<_ActionPermsSection> {
  // Dùng role.name làm key — khớp với session.role trong userActionPermsProvider
  String _selectedRoleName = '';
  Set<String> _enabledActions = {};
  bool _loading      = false;
  bool _saving       = false;
  bool _autoSelected = false; // Tránh auto-select chạy nhiều lần

  Future<void> _loadPermissions(String roleName) async {
    if (widget.storeId.isEmpty || roleName.isEmpty) return;
    setState(() => _loading = true);
    final perms = await StaffService.getActionPermissions(widget.storeId, roleName);
    if (mounted) setState(() { _enabledActions = perms; _loading = false; });
  }

  Future<void> _save() async {
    final session = ref.read(sessionProvider);
    if (session?.userId == null || _selectedRoleName.isEmpty) return;
    setState(() => _saving = true);
    try {
      await StaffService.setActionPermissions(
        storeId:         widget.storeId,
        role:            _selectedRoleName,
        actions:         _enabledActions,
        changedByUserId: session!.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text('Đã lưu quyền cho "$_selectedRoleName"')),
          ]),
          backgroundColor: const Color(0xFF1C2151),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Lỗi lưu: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _onRoleChanged(String roleName) {
    if (_selectedRoleName == roleName) return;
    setState(() { _selectedRoleName = roleName; _enabledActions = {}; });
    _loadPermissions(roleName);
  }

  @override
  Widget build(BuildContext context) {
    // ── Load vai trò thực từ DB (dynamic) — khớp với session.role ──
    final roles = ref.watch(storeRolesProvider).value ?? [];

    // Auto-select vai trò đầu tiên khi provider load xong lần đầu
    if (!_autoSelected && roles.isNotEmpty) {
      _autoSelected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onRoleChanged(roles.first.name);
      });
    }

    // Group actions by module group label
    final grouped = <String, List<String>>{};
    for (final key in kAllActions) {
      final group = kActionMeta[key]?.$3 ?? 'Khác';
      grouped.putIfAbsent(group, () => []).add(key);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Header ──
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1C2151), Color(0xFF3D2C8D)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_person_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hành động nhạy cảm',
                  style: TextStyle(color: Colors.white,
                      fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Kiểm soát điều nhân viên được làm',
                  style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            )),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Role picker — dynamic từ storeRoles ──
            const Text('Chọn vai trò',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: _kMuted, letterSpacing: 0.5)),
            const SizedBox(height: 8),

            if (roles.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: _kMuted),
                  SizedBox(width: 8),
                  Expanded(child: Text('Chưa có vai trò nào. Tạo vai trò trước.',
                    style: TextStyle(fontSize: 12, color: _kMuted))),
                ]),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: roles.map((role) {
                    final selected = _selectedRoleName == role.name;
                    final color    = role.colorValue;
                    return GestureDetector(
                      onTap: () => _onRoleChanged(role.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? color.withValues(alpha: 0.12)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected ? color : Colors.transparent,
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                            width: 10, height: 10,
                            decoration: BoxDecoration(
                              color: selected ? color : _kMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(role.name, style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: selected ? color : _kMuted,
                          )),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ),

            const SizedBox(height: 16),

            // ── Action toggles grouped by module ──
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ))
            else if (_selectedRoleName.isEmpty)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Chọn một vai trò để cấu hình quyền.',
                  style: TextStyle(color: _kMuted, fontSize: 13)),
              ))
            else
              ...grouped.entries.map((entry) {
                final groupName = entry.key;
                final actions   = entry.value;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 6),
                      child: Row(children: [
                        Container(width: 3, height: 14,
                          decoration: BoxDecoration(
                            color: _kNavy.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(width: 6),
                        Text(groupName,
                          style: const TextStyle(fontSize: 11,
                              fontWeight: FontWeight.w800, color: _kNavy,
                              letterSpacing: 0.5)),
                      ]),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        children: actions.asMap().entries.map((e) {
                          final i       = e.key;
                          final action  = e.value;
                          final meta    = kActionMeta[action]!;
                          final isLast  = i == actions.length - 1;
                          final enabled = _enabledActions.contains(action);
                          return Column(children: [
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (enabled) _enabledActions.remove(action);
                                  else _enabledActions.add(action);
                                });
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                child: Row(children: [
                                  Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(meta.$1, style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700,
                                        color: enabled ? _kNavy : _kMuted,
                                      )),
                                      Text(meta.$2, style: const TextStyle(
                                          fontSize: 11, color: _kMuted)),
                                    ],
                                  )),
                                  Switch.adaptive(
                                    value:    enabled,
                                    activeThumbColor: _kNavy,
                                    activeTrackColor: _kNavy.withValues(alpha: 0.4),
                                    onChanged: (_) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (enabled) { _enabledActions.remove(action); }
                                        else { _enabledActions.add(action); }
                                      });
                                    },
                                  ),
                                ]),
                              ),
                            ),
                            if (!isLast)
                              Divider(height: 1, indent: 12,
                                  color: _kBorder.withValues(alpha: 0.5)),
                          ]);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              }),

            const SizedBox(height: 8),

            // ── Save button ──
            if (_selectedRoleName.isNotEmpty)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(
                    _saving ? 'Đang lưu...' : 'Lưu quyền cho "$_selectedRoleName"',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// PANEL: Danh sách nhân viên trong ca + nút thêm
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftStaffPanel extends StatefulWidget {
  final ShiftConfig shift;
  final String storeId;
  final Color accentColor;
  final VoidCallback onChanged;
  const _ShiftStaffPanel({
    required this.shift, required this.storeId,
    required this.accentColor, required this.onChanged,
  });
  @override State<_ShiftStaffPanel> createState() => _ShiftStaffPanelState();
}

class _ShiftStaffPanelState extends State<_ShiftStaffPanel> {
  List<StaffMember> _allStaff = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    _allStaff = await StaffService.getStaffList(widget.storeId);
    if (mounted) setState(() => _loading = false);
  }

  List<StaffMember> get _assigned =>
      _allStaff.where((s) => s.shiftConfigId == widget.shift.id).toList();

  List<StaffMember> get _unassigned =>
      _allStaff.where((s) => s.shiftConfigId != widget.shift.id && !s.isOwner).toList();

  Future<void> _remove(StaffMember m) async {
    await ShiftConfigService.assignShiftToStaff(
      storeId: widget.storeId, userId: m.userId, shiftConfigId: null);
    await _load();
    widget.onChanged();
  }

  void _showAddPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffPickerSheet(
        unassigned: _unassigned,
        accentColor: widget.accentColor,
        shiftName: widget.shift.name,
        onSelect: (m) async {
          await ShiftConfigService.assignShiftToStaff(
            storeId: widget.storeId,
            userId: m.userId,
            shiftConfigId: widget.shift.id,
          );
          await _load();
          widget.onChanged();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(child: SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2))),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Divider(height: 1),
      const SizedBox(height: 10),
      Row(children: [
        Text('Nhân viên ca này', style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700, color: widget.accentColor)),
        const Spacer(),
        GestureDetector(
          onTap: _showAddPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: widget.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.person_add_rounded, size: 13, color: widget.accentColor),
              const SizedBox(width: 4),
              Text('Thêm', style: TextStyle(fontSize: 12,
                  fontWeight: FontWeight.w700, color: widget.accentColor)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      if (_assigned.isEmpty)
        Text('Chưa có nhân viên nào. Nhấn "Thêm" để gán.',
            style: const TextStyle(fontSize: 12, color: _kMuted))
      else
        Wrap(spacing: 6, runSpacing: 6,
          children: _assigned.map((m) => Chip(
            avatar: CircleAvatar(
              backgroundColor: widget.accentColor.withValues(alpha: 0.15),
              child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 11, color: widget.accentColor,
                      fontWeight: FontWeight.w800)),
            ),
            label: Text(m.name, style: const TextStyle(fontSize: 12)),
            deleteIcon: const Icon(Icons.close_rounded, size: 14),
            onDeleted: () => _remove(m),
            backgroundColor: Colors.white,
            side: BorderSide(color: widget.accentColor.withValues(alpha: 0.3)),
            padding: const EdgeInsets.symmetric(horizontal: 4),
          )).toList(),
        ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET: Chọn nhân viên chưa có ca để thêm vào ca này
// ─────────────────────────────────────────────────────────────────────────────
class _StaffPickerSheet extends StatelessWidget {
  final List<StaffMember> unassigned;
  final Color accentColor;
  final String shiftName;
  final Future<void> Function(StaffMember) onSelect;
  const _StaffPickerSheet({
    required this.unassigned, required this.accentColor,
    required this.shiftName, required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4,
          decoration: BoxDecoration(color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        Text('Thêm vào $shiftName',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy)),
        const SizedBox(height: 4),
        const Text('Chọn nhân viên chưa được phân ca',
            style: TextStyle(fontSize: 12, color: _kMuted)),
        const SizedBox(height: 16),
        if (unassigned.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: Text('Tất cả nhân viên đã có ca rồi 🎉',
                style: TextStyle(color: _kMuted, fontSize: 13))),
          )
        else
          ...unassigned.map((m) => ListTile(
            onTap: () async {
              Navigator.pop(context);
              await onSelect(m);
            },
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: accentColor.withValues(alpha: 0.12),
              child: Text(m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w800)),
            ),
            title: Text(m.name, style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14)),
            subtitle: Text(m.role, style: const TextStyle(
                fontSize: 12, color: _kMuted)),
            trailing: Icon(Icons.add_circle_rounded, color: accentColor),
          )),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHEET: THÊM / SỬA CA
// ─────────────────────────────────────────────────────────────────────────────
class _ShiftFormSheet extends StatefulWidget {
  final String storeId;
  final ShiftConfig? existing;
  final VoidCallback onSaved;
  const _ShiftFormSheet({required this.storeId, this.existing, required this.onSaved});
  @override State<_ShiftFormSheet> createState() => _ShiftFormSheetState();
}

class _ShiftFormSheetState extends State<_ShiftFormSheet> {
  late final TextEditingController _nameCtrl;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  String _color = '#0EA5E9';
  String? _errorMsg;
  bool _saving = false;

  // 4 ca gợi ý
  static const _presets = [
    (name: 'Ca Sáng',  sh: 6,  sm: 0, eh: 14, em: 0, c: '#0EA5E9'),
    (name: 'Ca Chiều', sh: 14, sm: 0, eh: 22, em: 0, c: '#F59E0B'),
    (name: 'Ca Tối',   sh: 17, sm: 0, eh: 23, em: 0, c: '#8B5CF6'),
    (name: 'Ca Khuya', sh: 22, sm: 0, eh: 6,  em: 0, c: '#1C2151'),
  ];

  static const _colors = [
    '#0EA5E9', '#F59E0B', '#8B5CF6', '#10B981',
    '#EF4444', '#F97316', '#EC4899', '#1C2151',
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl  = TextEditingController(text: e?.name ?? '');
    _startTime = TimeOfDay(hour: e?.startHour ?? 6, minute: e?.startMinute ?? 0);
    _endTime   = TimeOfDay(hour: e?.endHour ?? 14,  minute: e?.endMinute ?? 0);
    _color     = e?.color ?? '#0EA5E9';
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Color _parse(String hex) {
    try { return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return const Color(0xFF0EA5E9); }
  }

  void _applyPreset(int i) {
    final p = _presets[i];
    setState(() {
      _nameCtrl.text = p.name;
      _startTime = TimeOfDay(hour: p.sh, minute: p.sm);
      _endTime   = TimeOfDay(hour: p.eh, minute: p.em);
      _color     = p.c;
      _errorMsg  = null;
    });
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() => isStart ? _startTime = picked : _endTime = picked);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMsg = 'Vui lòng nhập tên ca');
      return;
    }
    if (widget.storeId.isEmpty) {
      setState(() => _errorMsg = 'Lỗi: storeId rỗng — thử đăng xuất và đăng nhập lại');
      return;
    }
    setState(() { _saving = true; _errorMsg = null; });
    try {
      final e = widget.existing;
      if (e == null) {
        await ShiftConfigService.createShift(
          storeId: widget.storeId, name: name,
          startHour: _startTime.hour, startMinute: _startTime.minute,
          endHour: _endTime.hour,     endMinute: _endTime.minute,
          color: _color,
        );
      } else {
        await ShiftConfigService.updateShift(
          shiftId: e.id, name: name, color: _color,
          startHour: _startTime.hour, startMinute: _startTime.minute,
          endHour: _endTime.hour,     endMinute: _endTime.minute,
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSaved();
    } catch (err) {
      if (mounted) setState(() {
        _saving = false;
        _errorMsg = 'Lỗi: $err';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20,
          MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(widget.existing == null ? 'Thêm ca làm việc' : 'Sửa ca',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _kNavy)),
          const SizedBox(height: 6),
          const Text('Chọn nhanh hoặc tự nhập tên ca',
              style: TextStyle(fontSize: 12, color: _kMuted)),
          const SizedBox(height: 12),

          // ── 4 Chips gợi ý ──
          Wrap(spacing: 8, runSpacing: 8, children: List.generate(_presets.length, (i) {
            final p = _presets[i];
            final isSelected = _nameCtrl.text == p.name;
            final c = _parse(p.c);
            return GestureDetector(
              onTap: () => _applyPreset(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? c.withValues(alpha: 0.12) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? c : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 8, height: 8,
                    decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(p.name, style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isSelected ? c : _kMuted,
                  )),
                ]),
              ),
            );
          })),
          const SizedBox(height: 16),

          // ── Tên ca (tự nhập) ──
          TextField(
            controller: _nameCtrl,
            onChanged: (_) => setState(() {}), // để chips cập nhật selected state
            decoration: InputDecoration(
              labelText: 'Tên ca',
              hintText: 'VD: Ca sáng, Ca theo yêu cầu...',
              prefixIcon: const Icon(Icons.schedule_rounded),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              errorText: _errorMsg,
            ),
          ),
          const SizedBox(height: 14),

          // ── Giờ bắt đầu / kết thúc ──
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _pickTime(true),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Bắt đầu', style: TextStyle(fontSize: 11, color: _kMuted)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.play_arrow_rounded, size: 16, color: _kNavy),
                    const SizedBox(width: 4),
                    Text(_startTime.format(context),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
                  ]),
                ]),
              ),
            )),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward_rounded, color: _kMuted),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => _pickTime(false),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Kết thúc', style: TextStyle(fontSize: 11, color: _kMuted)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.stop_rounded, size: 16, color: _kNavy),
                    const SizedBox(width: 4),
                    Text(_endTime.format(context),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kNavy)),
                  ]),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 14),

          // ── Màu ──
          const Text('Màu ca', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _kMuted)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: _colors.map((hex) {
            final selected = hex == _color;
            return GestureDetector(
              onTap: () => setState(() => _color = hex),
              child: Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: _parse(hex), shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? _kNavy : Colors.transparent, width: 3),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                    : null,
              ),
            );
          }).toList()),
          const SizedBox(height: 20),

          // ── Nút lưu ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.existing == null ? '✓ Tạo ca' : '✓ Lưu thay đổi',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Staff Summary Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _StaffRightPanel extends StatelessWidget {
  final AsyncValue<List<StaffMember>> staffAsync;
  const _StaffRightPanel({required this.staffAsync});

  @override
  Widget build(BuildContext context) {
    final staff = staffAsync.value ?? [];
    final active = staff.where((s) => s.isClockedIn).length;
    final inactive = staff.length - active;

    // Group by role
    final roleGroups = <String, int>{};
    for (final s in staff) {
      roleGroups[s.role] = (roleGroups[s.role] ?? 0) + 1;
    }

    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          _SRightCard(
            title: 'Tổng quan',
            icon: Icons.groups_rounded,
            child: Column(children: [
              _SStatRow(label: 'Tổng NV', value: '${staff.length}', color: _kNavy),
              const Divider(height: 1),
              _SStatRow(label: 'Đang làm ca', value: '$active', color: const Color(0xFF22C55E)),
              const Divider(height: 1),
              _SStatRow(label: 'Chưa vào ca', value: '$inactive', color: _kMuted),
            ]),
          ),
          if (roleGroups.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SRightCard(
              title: 'Theo vai trò',
              icon: Icons.badge_rounded,
              child: Column(
                children: roleGroups.entries.map((e) {
                  return _SStatRow(label: e.key, value: '${e.value}', color: _kOrange);
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SRightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _SRightCard({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
        color: _kNavy.withValues(alpha: 0.07), blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Row(children: [
          Icon(icon, size: 16, color: _kNavy),
          const SizedBox(width: 6),
          Text(title, style: GoogleFonts.outfit(
            fontSize: 13, fontWeight: FontWeight.w800, color: _kNavy)),
        ]),
      ),
      const Divider(height: 1),
      Padding(padding: const EdgeInsets.all(14), child: child),
    ]),
  );
}

class _SStatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _SStatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kNavy))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}
