import 'package:flutter/material.dart';
import '../core/utils/money_formatter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers/app_providers.dart';
import '../core/providers/dashboard_providers.dart';
import '../core/providers/session_provider.dart';
import '../core/repositories/dashboard_repository.dart';
import '../core/services/staff_service.dart';
import '../core/services/user_auth_service.dart';
import '../core/widgets/create_store_sheet.dart';
import '../core/utils/responsive.dart';
import '../modules/kho/providers/kho_providers.dart';
import '../shared/widgets/module_tile.dart';
import 'module_picker_screen.dart';
import '../modules/bill_printer/screens/bill_printer_hub.dart';
import '../modules/ops/screens/ops_screen.dart';
import '../core/services/auto_update_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MÀU LOCAL
// ─────────────────────────────────────────────────────────────────────────────
const _kNavy      = Color(0xFF1E1C5E);
const _kNavyLight = Color(0xFF2D2B8A);
const _kOrange    = Color(0xFFE85D20);
const _kInk       = Color(0xFF1A1207);
const _kMuted     = Color(0xFF9E9085);
const _kBg        = Color(0xFFFAF7F2);
const _kGreen     = Color(0xFF2E7D32);
const _kGreenBg   = Color(0xFFE8F5E9);
const _kRedBg     = Color(0xFFFFEBEE);
const _kRed       = Color(0xFFC62828);
const _kWhite20   = Color(0x33FFFFFF);
const _kWhite60   = Color(0x99FFFFFF);
const _kWhite85   = Color(0xD9FFFFFF);

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER: Fetch quyền module của staff từ Supabase
// ─────────────────────────────────────────────────────────────────────────────
class StoreRoleKey {
  final String storeId;
  final String role;
  const StoreRoleKey({required this.storeId, required this.role});
  @override bool operator ==(Object o) =>
      o is StoreRoleKey && o.storeId == storeId && o.role == role;
  @override int get hashCode => Object.hash(storeId, role);
}

// ── Provider đếm version perm — increment khi server báo perms thay đổi
// Dashboard watch provider này → tự refetch _staffPermsProvider
class _PermsVersionNotifier extends Notifier<int> {
  @override int build() => 0;
  void bump() => state++;
}
final permsVersionProvider = NotifierProvider<_PermsVersionNotifier, int>(
  _PermsVersionNotifier.new);

final _staffPermsProvider = FutureProvider.family<List<String>, StoreRoleKey>(
  (ref, key) {
    ref.watch(permsVersionProvider); // ← watch version → auto-refetch khi bump()
    return StaffService.getModulePermissions(key.storeId, key.role);
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// DASHBOARD SCREEN — Lego Dashboard với Riverpod
// ─────────────────────────────────────────────────────────────────────────────
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  bool _isEditMode = false;

  // Local order của modules (để drag & drop)
  List<String> _moduleOrder = [];
  bool _orderInitialized = false;
  String? _lastSessionRole; // Track role để reset order khi role thay đổi

  // ✨ Animation state
  String? _newlyAddedModuleId; // tile vừa được thêm → play entrance anim
  final Set<String> _removingIds   = {}; // tiles đang fade-out để xóa
  final Set<String> _editRemovedIds = {}; // modules đã xóa trong session edit hiện tại

  // 📡 Realtime subscription cho store_roles
  RealtimeChannel? _rolesChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentRoleRefresh();
      _subscribeStoreRolesRealtime();
      AutoUpdateService.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _rolesChannel?.unsubscribe();
    super.dispose();
  }

  /// Subscribe Postgres Realtime lên store_roles — nhận event khi chủ đổi quyền
  /// Hoạt động ngay cả khi staff không có module "Nhân viên"
  void _subscribeStoreRolesRealtime() {
    final session = ref.read(sessionProvider);
    if (session == null || session.isOwner || !session.hasStore) return;

    final storeId = session.storeId!;
    _rolesChannel = Supabase.instance.client
        .channel('dashboard_roles_$storeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'store_roles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'store_id',
            value: storeId,
          ),
          callback: (payload) {
            if (!mounted) return;
            final updatedRole = (payload.newRecord['name'] as String?)
                ?.trim().toLowerCase();
            final myRole = (session.role).trim().toLowerCase();
            debugPrint('[Dashboard] store_roles updated: $updatedRole (mine: $myRole)');
            // Refresh cho role mình HOẶC nếu không xác định được
            if (updatedRole == null || updatedRole == myRole) {
              ref.read(permsVersionProvider.notifier).bump();
            }
          },
        );
    _rolesChannel!.subscribe();
    debugPrint('[Dashboard] Subscribed to store_roles realtime for store: $storeId');
  }

  /// Check role hiện tại từ Supabase, nếu khác session cached → update
  Future<void> _silentRoleRefresh() async {
    final session = ref.read(sessionProvider);
    if (session == null || !session.hasStore) return;
    try {
      final membership = await UserAuthService.fetchStoreMembership(session.userId);
      if (!mounted || membership == null) return;
      // Nếu role đổi (chủ quán thay đổi quyền) → cập nhật session
      if (membership.role != session.role || membership.isOwner != session.isOwner) {
        debugPrint('[Dashboard] Role changed: ${session.role} → ${membership.role}');
        ref.read(sessionProvider.notifier).updateStore(membership);
        await UserAuthService.selectStore(membership);
      }
    } catch (e) {
      debugPrint('[Dashboard] _silentRoleRefresh error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final modulesAsync  = ref.watch(allModulesProvider);
    final lowStockAsync = ref.watch(lowStockKhoProvider);
    final todayStats    = ref.watch(todayStatsProvider);
    final session       = ref.watch(sessionProvider); // Watch để rebuild khi session update
    ref.watch(openShiftCCProvider); // Watch để luôn có data ca làm việc của nhân viên

    // Lấy quyền thực tế từ Supabase (không dùng kDefaultPerms hardcode)
    final staffPermsAsync = (session != null && !session.isOwner && session.hasStore)
        ? ref.watch(_staffPermsProvider(StoreRoleKey(
            storeId: session.storeId!,
            role: session.role,
          )))
        : null;

    return Scaffold(
      backgroundColor: _kBg,
      body: modulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy),
        ),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (modules) {
          // Map: local module id → permission key (tương ứng kAllModules)
          const permMap = {
            'pos': 'pos', 'kho': 'kho', 'finance': 'finance',
            'table': 'ban', 'kitchen': 'kitchen', 'report': 'report',
            'loyalty': 'loyalty', 'staff': 'staff', 'chamcong': 'chamcong',
            'kho_pro': 'kho_pro', // ⭐ Kho Hàng Chuyên Nghiệp
            'tinhluong': 'tinhluong', // ⭐ Tính Lương
            'kay_ops': 'kay_ops', // ⭐ Vận Hành
          };

          // Quyền thực tế từ Supabase, fallback kDefaultPerms
          // null = owner/no-store → hiện tất cả module isActive=true
          List<String>? allowedPerms;
          if (session != null && !session.isOwner && session.hasStore) {
            final canonical = StaffService.canonicalRole(session.role);
            final rawPerms = staffPermsAsync?.when(
              data: (p) => p,
              loading: () => kDefaultPerms[canonical] ?? kDefaultPerms['cashier']!,
              error: (_, __) => kDefaultPerms[canonical] ?? kDefaultPerms['cashier']!,
            ) ?? kDefaultPerms[canonical] ?? kDefaultPerms['cashier']!;
            // ⭐ kay_ops luôn available cho mọi nhân viên
            allowedPerms = rawPerms.contains('kay_ops')
                ? rawPerms
                : [...rawPerms, 'kay_ops'];
          }

          // Lấy modules được phép:
          // - Chủ quán: isActive=true (chủ tự chỉnh)
          // - Nhân viên: theo quyền Supabase, BỎ QUA isActive
          final activeModules = modules
              .where((m) {
                // Chỉ hiện module có UI config — tránh data Supabase cũ gây lỗi
                if (!kModuleConfigs.containsKey(m.id)) return false;
                if (allowedPerms == null) return m.isActive; // chủ quán: theo isActive
                // Nhân viên: bỏ qua isActive, chỉ xét permission
                final permKey = permMap[m.id];
                if (permKey == null) return false;
                return allowedPerms!.contains(permKey);
              })
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));

          // Reset order khi role thay đổi (vd: staff vừa được detect vào quán)
          final currentRole = session?.role;
          if (currentRole != _lastSessionRole) {
            _lastSessionRole = currentRole;
            _orderInitialized = false;
          }

          // Khởi tạo local order lần đầu
          if (!_orderInitialized || _moduleOrder.isEmpty) {
            _moduleOrder = activeModules.map((m) => m.id).toList();
            _orderInitialized = true;
          } else {
            // Sync: thêm module mới vào cuối, xóa module bị tắt
            final activeIds = activeModules.map((m) => m.id).toSet();
            _moduleOrder.removeWhere((id) => !activeIds.contains(id));
            for (final m in activeModules) {
              // Không re-add module đã bị xóa trong session edit này
              if (!_moduleOrder.contains(m.id) && !_editRemovedIds.contains(m.id)) {
                _moduleOrder.add(m.id);
              }
            }
          }

          final mainContent = CustomScrollView(
            physics: const ClampingScrollPhysics(),
            slivers: [
              // ── HEADER ─────────────────────────────────────────────
              SliverToBoxAdapter(
                child: RepaintBoundary(child: _buildHeader()),
              ),

              // ── BODY ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section title ──────────────────────────────
                      _buildSectionHeader(activeModules),
                      const SizedBox(height: 14),

                      // ── Lego Module Grid ───────────────────────────
                      _buildLegoGrid(activeModules),

                      // ── Edit mode bottom hint ──────────────────────
                      if (_isEditMode) ...[
                        const SizedBox(height: 12),
                        _buildEditModeHint(),
                      ],

                      // ── Stat cards ─────────────────────────────────
                      if (!_isEditMode) ...[
                        const SizedBox(height: 24),
                        _buildTodayStats(todayStats, lowStockAsync),
                        const SizedBox(height: 16),

                        // ── Low stock warnings ──────────────────────
                        lowStockAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (lowStocks) => lowStocks.isEmpty
                              ? const SizedBox.shrink()
                              : _buildLowStockWarning(lowStocks
                                  .map((p) => p.name)
                                  .take(3)
                                  .toList()),
                        ),

                        const SizedBox(height: 80),
                      ] else ...[
                        const SizedBox(height: 80),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 700) {
                return Row(children: [
                  Expanded(flex: 3, child: mainContent),
                  SizedBox(
                    width: 280,
                    child: _DashboardRightPanel(
                      todayStats: todayStats,
                      lowStockAsync: lowStockAsync,
                    ),
                  ),
                ]);
              }
              return mainContent;
            },
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    final now = DateTime.now();
    // format ngày kiểu Việt Nam
    final weekdays = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'Chủ nhật'];
    final dayStr = weekdays[now.weekday];
    final dateStr =
        '$dayStr, ${DateFormat('dd/MM/yyyy').format(now)}';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2D2B8A), Color(0xFF1E1C5E), Color(0xFF12103A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Decorative radial glow top-right
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE85D20).withValues(alpha: 0.25),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Top row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer(builder: (_, ref, __) {
                          final nameAsync = ref.watch(shopNameProvider);
                          final session = ref.watch(sessionProvider);
                          final isOwner = session?.isOwner ?? true;

                          if (!isOwner && session != null && session.hasStore) {
                            // Staff: hiện tên nhân viên
                            return Text(
                              session.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.8,
                              ),
                            );
                          }

                          // Chủ quán: hiện tên quán (giữ nguyên)
                          final displayName = session?.storeName?.isNotEmpty == true
                              ? session!.storeName!
                              : nameAsync.when(
                                  data: (n) => n,
                                  loading: () => 'Quán Nhỏ',
                                  error: (_, __) => 'Quán Nhỏ',
                                );
                          return Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          );
                        }),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            // Chip: "Quán Nhỏ - POS" (chủ) hoặc "Thuộc quán X" (staff)
                            Consumer(builder: (_, ref, __) {
                              final session = ref.watch(sessionProvider);
                              final isOwner = session?.isOwner ?? true;
                              if (!isOwner && session != null && session.hasStore) {
                                // Staff — pill rõ với border trắng
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.40),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.storefront_rounded,
                                          size: 11, color: Colors.white),
                                      const SizedBox(width: 5),
                                      Text(
                                        session.storeName ?? 'Quán Nhỏ',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              // Owner — badge cam nổi bật
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6B2C),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFF6B2C).withValues(alpha: 0.45),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.storefront_rounded,
                                        size: 11, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text(
                                      'Quán Nhỏ · POS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(width: 6),
                            Text(
                              dateStr,
                              style: const TextStyle(
                                color: _kWhite60,
                                fontSize: 12,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                   // Notification bell → hiện hàng sắp hết khi bấm
                  Consumer(builder: (ctx, r, __) {
                    final lowStockAsync = r.watch(lowStockKhoProvider);
                    final lowCount = lowStockAsync.value?.length ?? 0;
                    return GestureDetector(
                      onTap: () {
                        final items = lowStockAsync.value ?? [];
                        if (items.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: const Text('✅ Kho ổn định, không có hàng sắp hết'),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                          return;
                        }
                        showModalBottomSheet(
                          context: ctx,
                          backgroundColor: const Color(0xFF1A2233),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 36, height: 4,
                                    decoration: BoxDecoration(
                                      color: Colors.white24,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  '⚠️ Hàng sắp hết (${items.length} mặt hàng)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...items.take(8).map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.inventory_2_outlined,
                                          size: 16, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          p.name,
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0x33EF4444),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          'Còn ${p.stockQty.toStringAsFixed(p.stockQty % 1 == 0 ? 0 : 1)} ${p.unit}',
                                          style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: lowCount > 0
                                  ? const Color(0x33F59E0B)
                                  : _kWhite20,
                              borderRadius: BorderRadius.circular(12),
                              border: lowCount > 0
                                  ? Border.all(color: const Color(0x66F59E0B))
                                  : null,
                            ),
                            child: Icon(
                              lowCount > 0
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_outlined,
                              color: lowCount > 0
                                  ? const Color(0xFFF59E0B)
                                  : Colors.white,
                              size: 20,
                            ),
                          ),
                          if (lowCount > 0)
                            Positioned(
                              top: -4,
                              right: -4,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '$lowCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  // Avatar → Settings
                  GestureDetector(
                    onTap: () => ref.read(navTabProvider.notifier).goTo(NavTab.settings),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _kOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'QN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Revenue display — hoặc CTA tạo quán nếu chưa có quán
              Consumer(builder: (ctx, r, __) {
                final hasStore = r.watch(hasStoreProvider);
                if (!hasStore) {
                  // ── CTA: Chưa có quán ───────────────────────────────────
                  return _CreateStoreCta(
                    onTap: () => showCreateStoreSheet(ctx, r),
                  );
                }
                // ── Doanh thu bình thường ──────────────────────────────────
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DOANH THU HÔM NAY',
                                style: TextStyle(
                                  color: _kWhite60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              // LIVE revenue
                              Builder(builder: (_) {
                                final s   = r.watch(todayStatsProvider);
                                final rev = s.value?.todayRevenue ?? 0;
                                return Text(
                                  _fmtRevenue(rev),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 42,
                                    letterSpacing: -0.5,
                                    height: 1.0,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        // Quick badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0x334CAF50),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: const Color(0x664CAF50)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.store_rounded,
                                  size: 12, color: Color(0xFF81C784)),
                              SizedBox(width: 4),
                              Text(
                                'Sẵn sàng',
                                style: TextStyle(
                                  color: Color(0xFF81C784),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Pills row — live data
                    Builder(builder: (_) {
                      final s         = r.watch(todayStatsProvider);
                      final orders    = s.value?.todayOrders ?? 0;
                      final customers = s.value?.todayCustomers ?? 0;
                      return Row(
                        children: [
                          _HeaderPill(
                            icon: Icons.receipt_long_rounded,
                            label: 'Số đơn',
                            value: '$orders',
                          ),
                          const SizedBox(width: 8),
                          _HeaderPill(
                            icon: Icons.people_rounded,
                            label: 'Khách',
                            value: '$customers',
                          ),
                        ],
                      );
                    }),
                  ],
                );
              }),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION HEADER (Module Grid title + edit toggle)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader(List<dynamic> activeModules) {
    final sessionSnap = ref.read(sessionProvider);
    final isOwner = sessionSnap?.isOwner ?? true;
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Modules',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kInk,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              _isEditMode
                  ? 'Nhấn  –  để xoá · Nhấn  +  để thêm'
                  : '${activeModules.length} đang bật • Giữ để sắp xếp',
              style: TextStyle(
                fontSize: 11.5,
                color: _isEditMode
                    ? _kOrange.withValues(alpha: 0.85)
                    : _kMuted,
                fontWeight: _isEditMode ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
        const Spacer(),
        // Chủ quán: nút Sửa / Xong | Staff: text không có quyền
        if (!isOwner && (sessionSnap?.hasStore ?? false))
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded,
                  size: 13, color: Colors.grey.shade500),
                const SizedBox(width: 5),
                Text(
                  'Nhân viên không có quyền\nchỉnh sửa',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else
          // Sửa / Xong pill button (chủ quán)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: _isEditMode ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) {
              final bgColor = Color.lerp(
                const Color(0xFF1E1C5E), // navy
                const Color(0xFFE85D20), // orange
                t,
              )!;
              final glowColor = Color.lerp(
                const Color(0x661E1C5E),
                const Color(0x66E85D20),
                t,
              )!;
              return GestureDetector(
                onTap: _toggleEditMode,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: glowColor,
                        blurRadius: 12,
                        spreadRadius: -2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: anim,
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Icon(
                          _isEditMode ? Icons.check_rounded : Icons.tune_rounded,
                          key: ValueKey(_isEditMode),
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0, 0.3),
                              end: Offset.zero,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Text(
                          _isEditMode ? 'Xong' : 'Sửa',
                          key: ValueKey(_isEditMode),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  // LEGO GRID — 2-column grid, equal-height tiles
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLegoGrid(List<dynamic> activeModules) {
    if (_moduleOrder.isEmpty && _removingIds.isEmpty) {
      return _buildEmptyModules();
    }

    // Hiển thị cả tiles đang bị xóa (để animation chạy xong)
    final displayOrder = [
      ..._removingIds.where((id) => !_moduleOrder.contains(id)),
      ..._moduleOrder,
    ];

    final tiles = displayOrder.map((id) {
      final config = kModuleConfigs[id];
      if (config == null) return const SizedBox.shrink();
      final idx = _moduleOrder.indexOf(id);
      final isRemoving = _removingIds.contains(id);
      final isNew = id == _newlyAddedModuleId;

      Widget tile = ModuleTile(
        data: config,
        isEditMode: _isEditMode,
        isEven: idx.isEven,
        onTap: () => _navigateTo(config.route),
        onRemove: () => _removeModule(id),
      );

      // ✨ Entrance animation — module vừa được thêm
      if (isNew) {
        tile = tile
            .animate()
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1.0, 1.0),
              duration: 500.ms,
              curve: Curves.elasticOut,
            )
            .fadeIn(duration: 250.ms)
            .slideY(
              begin: 0.2,
              end: 0,
              duration: 380.ms,
              curve: Curves.easeOutCubic,
            );
      }

      // 💨 Exit animation — module đang bị xóa (chậm hơn)
      if (isRemoving) {
        tile = tile
            .animate()
            .scale(
              begin: const Offset(1.0, 1.0),
              end: const Offset(0.60, 0.60),
              duration: 550.ms,
              curve: Curves.easeInBack,
            )
            .fadeOut(duration: 450.ms)
            .slideY(
              begin: 0,
              end: 0.2,
              duration: 550.ms,
              curve: Curves.easeIn,
            );
      }

      return KeyedSubtree(key: ValueKey(id), child: tile);
    }).toList();

    if (_isEditMode) {
      tiles.add(KeyedSubtree(
        key: const ValueKey('__add__'),
        child: AddModuleTile(onTap: _openModulePicker),
      ));
    }

    return _isEditMode
        ? _buildReorderableGrid(tiles)
        : _buildStaticGrid(tiles);
  }


  /// Static grid — GridView responsive (2/3/4 cột tuỳ màn hình)
  Widget _buildStaticGrid(List<Widget> tiles) {
    final cols = Responsive.gridColumns(context);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      // Force render tất cả tiles để animation entry chạy đúng
      cacheExtent: 9999,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: cols >= 4 ? 1.75 : cols >= 3 ? 1.55 : 1.35,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => tiles[i],
    );
  }

  /// Reorder/Edit grid — responsive columns
  Widget _buildReorderableGrid(List<Widget> tiles) {
    final cols = Responsive.gridColumns(context);
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      // Force render tất cả tiles để jiggle animation chạy đều trên mọi tile
      cacheExtent: 9999,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: cols >= 4 ? 1.75 : cols >= 3 ? 1.55 : 1.35,
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => tiles[i],
    );
  }

  Widget _buildEmptyModules() {
    return GestureDetector(
      onTap: _openModulePicker,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE0D8CC), width: 2),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.view_module_rounded,
                  size: 40, color: _kMuted),
              const SizedBox(height: 12),
              const Text(
                'Chưa có module nào',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _kInk,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _kNavy,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  '+ Thêm module',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDIT MODE HINT BAR
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildEditModeHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kOrange.withValues(alpha: 0.10),
            _kOrange.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _kOrange.withValues(alpha: 0.28),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _kOrange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(Icons.touch_app_rounded,
                size: 17, color: _kOrange.withValues(alpha: 0.9)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Đang chỉnh sửa modules',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: _kOrange.withValues(alpha: 0.95),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nhấn – đỏ để xoá  •  Nhấn + để thêm',
                  style: TextStyle(
                    fontSize: 11,
                    color: _kOrange.withValues(alpha: 0.70),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -0.3, end: 0, duration: 280.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 220.ms);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TODAY STATS — Premium Bento Cards — LIVE DATA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTodayStats(
    AsyncValue<DashboardStats> statsAsync,
    AsyncValue<List<dynamic>> lowStockAsync,
  ) {
    final stats = statsAsync.value ?? const DashboardStats(
        todayRevenue: 0, todayOrders: 0, todayCustomers: 0, avgOrderValue: 0);
    final lowCount = (lowStockAsync.value ?? []).length;
    final isLoading = statsAsync.isLoading && !statsAsync.hasValue;

    final voidAsync = ref.watch(todayVoidStatsProvider);
    final voidStats = voidAsync.value ?? {'amount': 0.0, 'count': 0};
    final double voidAmount = voidStats['amount'] as double;
    final int voidCount = voidStats['count'] as int;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(children: [
          const Text(
            'Hôm nay',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _kInk, letterSpacing: -0.3),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _kNavy.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
            child: Text(
              DateFormat('HH:mm').format(DateTime.now()),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy, letterSpacing: 0.5),
            ),
          ),
        ]),
        const SizedBox(height: 12),

        // Unified white card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 14, offset: const Offset(0, 4)),
            ],
          ),
          child: isLoading
              ? const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kNavy)))
              : Column(children: [
                  // Row 1
                  Row(children: [
                    _TodayStat(
                      label: 'Giá TB / đơn',
                      value: fmtMoney(stats.avgOrderValue),
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF388E3C),
                    ),
                    Container(width: 1, height: 44, color: const Color(0xFFF0EDE8), margin: const EdgeInsets.symmetric(horizontal: 12)),
                    _TodayStat(
                      label: 'Số đơn',
                      value: '${stats.todayOrders}',
                      icon: Icons.receipt_long_rounded,
                      color: const Color(0xFF1976D2),
                    ),
                  ]),
                  const Divider(height: 20, color: Color(0xFFF0EDE8)),
                  // Row 2
                  Row(children: [
                    _TodayStat(
                      label: 'Khách hôm nay',
                      value: '${stats.todayCustomers}',
                      icon: Icons.people_alt_rounded,
                      color: const Color(0xFF7B1FA2),
                    ),
                    Container(width: 1, height: 44, color: const Color(0xFFF0EDE8), margin: const EdgeInsets.symmetric(horizontal: 12)),
                    _TodayStat(
                      label: 'Sắp hết hàng',
                      value: lowCount == 0 ? 'Ổn định' : '$lowCount sản phẩm',
                      icon: lowCount == 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                      color: lowCount == 0 ? const Color(0xFF00796B) : const Color(0xFFE53935),
                    ),
                  ]),
                  const Divider(height: 20, color: Color(0xFFF0EDE8)),
                  // Row 3
                  Row(children: [
                    _TodayStat(
                      label: 'Huỷ Bàn / Huỷ Bill',
                      value: '$voidCount lượt',
                      icon: Icons.delete_sweep_rounded,
                      color: const Color(0xFFE65100),
                    ),
                    Container(width: 1, height: 44, color: Colors.transparent, margin: const EdgeInsets.symmetric(horizontal: 12)),
                    const Expanded(child: SizedBox()),
                  ]),
                ]),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOW STOCK WARNING
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLowStockWarning(List<String> productNames) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFFCC80),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0x1FFF6F00),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory_rounded,
                  color: Color(0xFFE65100),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sắp hết hàng',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE65100),
                ),
              ),
              const Spacer(),
              const Text(
                'Nhập thêm →',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kOrange,
                ),
              ),
            ],
          ),
          if (productNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...productNames.asMap().entries.map((e) => Padding(
                  padding:
                      EdgeInsets.only(bottom: e.key < productNames.length - 1 ? 8 : 0),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFE65100),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e.value,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    )
        .animate()
        .slideX(begin: 0.1, end: 0, duration: 300.ms)
        .fadeIn(duration: 250.ms);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TOP ITEMS — Sản phẩm với rank badges & progress bars
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopItems() {
    // Rank badge colors: gold, silver, bronze, then navy
    const rankColors = [
      [Color(0xFFF9A825), Color(0xFFFBC02D)], // gold
      [Color(0xFF78909C), Color(0xFF90A4AE)], // silver
      [Color(0xFF8D6E63), Color(0xFFA1887F)], // bronze
      [_kNavy,            Color(0xFF2D2B8A)], // navy
      [_kNavy,            Color(0xFF2D2B8A)], // navy
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE85D20), Color(0xFFFF8F00)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🔥', style: TextStyle(fontSize: 11)),
                  SizedBox(width: 4),
                  Text(
                    'Top sản phẩm',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Consumer(builder: (_, ref, __) {
              final productsAsync = ref.watch(allProductsProvider);
              return productsAsync.when(
                data: (p) => Text(
                  '${p.length} sản phẩm',
                  style: TextStyle(
                    fontSize: 12,
                    color: _kMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            }),
          ],
        ),
        const SizedBox(height: 12),
        Consumer(builder: (_, ref, __) {
          final productsAsync = ref.watch(allProductsProvider);
          return productsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: _kNavy),
              ),
            ),
            error: (e, _) => Text('Lỗi: $e'),
            data: (products) {
              if (products.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'Chưa có sản phẩm nào',
                      style: TextStyle(color: _kMuted, fontSize: 14),
                    ),
                  ),
                );
              }

              final displayProducts = products.take(5).toList();
              // max price for progress bars
              final maxPrice = displayProducts
                  .map((p) => p.sellPrice)
                  .reduce((a, b) => a > b ? a : b);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: displayProducts.asMap().entries.map((e) {
                    final p = e.value;
                    final rank = e.key;
                    final isLast = rank == displayProducts.length - 1;
                    final isLow = p.minStock > 0 && p.stockQty <= p.minStock;
                    final colors = rankColors[rank.clamp(0, rankColors.length - 1)];
                    final progress = maxPrice > 0 ? p.sellPrice / maxPrice : 0.0;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                          child: Row(
                            children: [
                              // Rank badge with gradient
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: colors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors[0].withValues(alpha: 0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    rank == 0 ? '🥇' : rank == 1 ? '🥈' : rank == 2 ? '🥉' : '${rank + 1}',
                                    style: TextStyle(
                                      fontSize: rank <= 2 ? 16 : 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: _kInk,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isLow)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _kRedBg,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '⚠️ Hết',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: _kRed,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    // Progress bar
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 4,
                                        backgroundColor: const Color(0xFFF0ECE6),
                                        valueColor: AlwaysStoppedAnimation(
                                          colors[0],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tồn: ${p.stockQty.toStringAsFixed(0)} ${p.unit}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: _kMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${_formatCurrency(p.sellPrice)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _kGreen,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isLast)
                          const Divider(
                            height: 1,
                            indent: 60,
                            color: Color(0xFFF0ECE6),
                          ),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleEditMode() {
    HapticFeedback.lightImpact();
    final wasEditing = _isEditMode;
    setState(() => _isEditMode = !_isEditMode);
    // Khi thoát edit mode → sync lại provider từ SharedPreferences
    if (wasEditing) {
      _editRemovedIds.clear(); // Reset sau khi thoát edit
      ref.invalidate(allModulesProvider); // Sync lại provider với DB
    }
  }

  Future<void> _removeModule(String moduleId) async {
    HapticFeedback.mediumImpact();

    final config = kModuleConfigs[moduleId];
    if (config == null) return;

    // ── Confirm bottom sheet ────────────────────────────────────────────────
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0D8CC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Module icon preview
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: config.baseColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(config.icon, color: config.baseColor, size: 30),
            ),
            const SizedBox(height: 16),

            Text(
              'Tắt module "${config.title}"?',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1207),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Dữ liệu sẽ được giữ nguyên.\nBạn có thể bật lại bất cứ lúc nào.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF9E9085),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Buttons row
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2EDE4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: Text(
                          'Giữ lại',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1207),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(true),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC62828).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Tắt module',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return; // User cancelled

    // 💨 Bước 1: thêm vào _removingIds → trigger exit animation
    setState(() {
      _removingIds.add(moduleId);
      _editRemovedIds.add(moduleId); // Đánh dấu để tránh sync re-add
    });

    // ⏳ Đợi animation chạy xong (550ms)
    await Future.delayed(const Duration(milliseconds: 560));

    // 🗽 Bước 2: xóa khỏi list và clear removing state
    if (mounted) {
      setState(() {
        _moduleOrder.remove(moduleId);
        _removingIds.remove(moduleId);
      });
    }

    // 💾 Ghi vào DB
    await ref.read(moduleRepositoryProvider).deactivate(moduleId);
    // ⚠️ Không invalidate allModulesProvider ở đây — tránh gây loading flash làm remount tiles
    // Provider sẽ được sync khi thoát edit mode (nút Xong)
  }

  Future<void> _openModulePicker() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ModulePickerScreen(
          activeModuleIds: List.from(_moduleOrder),
        ),
      ),
    );

    if (result != null && !_moduleOrder.contains(result)) {
      // 🔄 Invalidate provider để dashboard đọc lại SharedPreferences mới nhất
      ref.invalidate(allModulesProvider);

      // ✨ Bước 1: thêm vào list và đánh dấu là "newly added"
      setState(() {
        _moduleOrder.add(result);
        _newlyAddedModuleId = result;
      });

      // ⏳ Clear flag sau khi entrance animation xong (~600ms)
      await Future.delayed(const Duration(milliseconds: 620));
      if (mounted) {
        setState(() => _newlyAddedModuleId = null);
      }
    }
  }

  void _navigateTo(String? route) {
    if (route == null) return;

    // ── CLOCK-IN GUARD CHO NHÂN VIÊN ──
    final session = ref.read(sessionProvider);
    final isStaff = session != null &&
        !(session.isOwner) &&
        session.role != 'owner' &&
        session.role != 'manager' &&
        session.role.toLowerCase() != 'quản lý';

    if (isStaff && route != '/chamcong') {
      final openShiftAsync = ref.read(openShiftCCProvider);
      if (openShiftAsync.isLoading) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đang kiểm tra ca làm việc, vui lòng thử lại sau giây lát...'),
              duration: Duration(milliseconds: 1500),
            ),
          );
        }
        return;
      }
      final hasActiveShift = openShiftAsync.asData?.value != null;
      if (!hasActiveShift) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [
              Icon(Icons.lock_clock_rounded, color: _kOrange, size: 24),
              SizedBox(width: 8),
              Text('Yêu cầu chấm công', style: TextStyle(fontWeight: FontWeight.w800, color: _kNavy)),
            ]),
            content: const Text(
              'Tính năng này tạm khóa vì bạn chưa vào ca làm việc.\n\n'
              'Vui lòng thực hiện chấm công để mở khóa các module của quán.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Đóng', style: TextStyle(color: _kMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _navigateTo('/chamcong');
                },
                child: const Text('Đi chấm công'),
              ),
            ],
          ),
        );
        return;
      }
    }
    // bill_printer → push screen riêng (không dùng tab index)
    if (route == '/bill_printer') {
      Navigator.push(context, _smoothRoute(const _BillPrinterHubWrapper()));
      return;
    }
    // kay_ops → push trực tiếp, bypass tab guard
    if (route == '/kay_ops') {
      Navigator.push(context, _smoothRoute(const OpsScreen()));
      return;
    }
    final tabMap = {
      '/pos':      1,
      '/kho':      2,
      '/finance':  3,
      '/loyalty':  4,
      '/report':   5,
      '/table':    7,  // Module Quản lý Bàn — BanScreen tại index 7
      '/kitchen':  8,  // Module Phiếu bếp — KitchenScreen tại index 8
      '/staff':    9,  // Module Nhân viên — NhanVienScreen tại index 9
      '/chamcong': 10, // Module Chấm công — ChamCongScreen tại index 10
      '/kho_pro':  11, // Module Kho Hàng Chuyên Nghiệp — KhoProScreen tại index 11
      '/tinhluong': 12, // Module Tính Lương — TinhLuongScreen tại index 12
      '/kay_ops':   13, // Module Vận Hành — OpsScreen tại index 13
      '/log_viewer': 14, // Module Nhật ký hệ thống — LogViewerScreen tại index 14
    };
    final idx = tabMap[route];
    if (idx != null) {
      ref.read(navTabProvider.notifier).goTo(idx);
    }
  }

  void _goToTab(int index) {
    ref.read(navTabProvider.notifier).goTo(index);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILS
  // ─────────────────────────────────────────────────────────────────────────
  String _formatCurrency(double amount) => fmtMoney(amount);

  /// Smooth fade + slide-up route thay cho MaterialPageRoute cứng
  PageRouteBuilder<T> _smoothRoute<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, secondaryAnimation, child) {
        final fade = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
        final scale = Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        );
        return FadeTransition(
          opacity: fade,
          child: SlideTransition(
            position: slide,
            child: ScaleTransition(scale: scale, child: child),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _HeaderPill({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: _kWhite20,
          borderRadius: const BorderRadius.all(Radius.circular(30)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _kWhite60),
            const SizedBox(width: 7),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: _kWhite60,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// TODAY STAT ROW ITEM
// ─────────────────────────────────────────────────────────────────────────────
class _TodayStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _TodayStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: _kInk, letterSpacing: -0.5), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: _kMuted, fontWeight: FontWeight.w500)),
        ])),
      ]),
    ),
  );
}

class _PremiumStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  final int delay;

  const _PremiumStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon circle
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: delay))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.15, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CREATE STORE / CHECK MEMBERSHIP CTA
// ─────────────────────────────────────────────────────────────────────────────
class _CreateStoreCta extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  const _CreateStoreCta({required this.onTap});
  @override
  ConsumerState<_CreateStoreCta> createState() => _CreateStoreCtaState();
}

class _CreateStoreCtaState extends ConsumerState<_CreateStoreCta> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    // Auto-check khi mount: staff được thêm sau khi đăng ký
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheck());
  }

  Future<void> _autoCheck() async {
    final session = ref.read(sessionProvider);
    if (session == null || session.hasStore) return;
    // Không auto-check nếu là chủ (isOwner flag chưa set)
    // Chỉ check silent — không hiện loading
    final membership = await UserAuthService.fetchStoreMembership(session.userId);
    if (!mounted) return;
    if (membership != null) {
      ref.read(sessionProvider.notifier).updateStore(membership);
      await UserAuthService.selectStore(membership);
    }
  }

  Future<void> _checkMembership() async {
    final session = ref.read(sessionProvider);
    if (session == null) return;
    setState(() => _checking = true);
    final membership = await UserAuthService.fetchStoreMembership(session.userId);
    if (!mounted) return;
    setState(() => _checking = false);
    if (membership != null) {
      ref.read(sessionProvider.notifier).updateStore(membership);
      await UserAuthService.selectStore(membership);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ Đã kết nối quán: ${membership.storeName}'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chưa được thêm vào quán nào. Liên hệ chủ quán để được thêm.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFE85D20).withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.storefront_rounded,
                  color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chưa có quán nào',
                      style: TextStyle(
                        color: Colors.white, fontSize: 15,
                        fontWeight: FontWeight.w800,
                      )),
                    SizedBox(height: 3),
                    Text('Tạo quán mới hoặc kiểm tra xem chủ đã thêm bạn chưa',
                      style: TextStyle(
                        color: Colors.white60, fontSize: 12,
                      )),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Nút Kiểm tra lại
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _checking ? null : _checkMembership,
                  icon: _checking
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70))
                      : const Icon(Icons.refresh_rounded, size: 16, color: Colors.white70),
                  label: Text(_checking ? 'Đang kiểm tra...' : 'Kiểm tra lại',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Nút Tạo quán
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onTap,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Tạo quán',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE85D20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.15, end: 0, duration: 350.ms, curve: Curves.easeOutCubic);
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// FORMAT HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fmtRevenue(double v) => fmtVnd(v);
String _fmtShort(double v) => fmtMoney(v);

// ─── Bill Printer Hub Wrapper (ProviderScope đã bao ngoài) ────────────────────
class _BillPrinterHubWrapper extends StatelessWidget {
  const _BillPrinterHubWrapper();
  @override
  Widget build(BuildContext context) => const BillPrinterHub();
}

// ─────────────────────────────────────────────────────────────────────────────
// TABLET RIGHT PANEL — Quick Stats Sidebar
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardRightPanel extends ConsumerWidget {
  final AsyncValue<DashboardStats> todayStats;
  final AsyncValue<List<dynamic>> lowStockAsync;
  const _DashboardRightPanel({
    required this.todayStats,
    required this.lowStockAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = todayStats.value ?? DashboardStats.empty;
    final lowStocks = lowStockAsync.value ?? [];

    final voidAsync = ref.watch(todayVoidStatsProvider);
    final voidStats = voidAsync.value ?? {'amount': 0.0, 'count': 0};
    final double voidAmount = voidStats['amount'] as double;
    final int voidCount = voidStats['count'] as int;

    return Container(
      color: const Color(0xFFF5F0EA),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
        children: [
          _DRightCard(
            title: 'Hôm nay',
            icon: Icons.insights_rounded,
            child: Column(children: [
              _DStatRow(label: 'Doanh thu', value: _fmtShort(s.todayRevenue), color: _kGreen),
              const Divider(height: 1),
              _DStatRow(label: 'Số đơn', value: '${s.todayOrders}', color: _kOrange),
              const Divider(height: 1),
              _DStatRow(label: 'Khách', value: '${s.todayCustomers}', color: _kNavy),
              const Divider(height: 1),
              _DStatRow(label: 'TB/đơn', value: _fmtShort(s.avgOrderValue), color: const Color(0xFFF9A825)),
              const Divider(height: 1),
              _DStatRow(label: 'Huỷ Bàn / Huỷ Bill', value: '$voidCount lượt', color: const Color(0xFFE65100)),
            ]),
          ),
          if (lowStocks.isNotEmpty) ...[
            const SizedBox(height: 12),
            _DRightCard(
              title: 'Hàng sắp hết',
              icon: Icons.warning_amber_rounded,
              child: Column(
                children: lowStocks.take(5).map<Widget>((p) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_outlined, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(p.name,
                        style: GoogleFonts.outfit(fontSize: 12, color: _kInk),
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x33EF4444),
                          borderRadius: BorderRadius.circular(4)),
                        child: Text(
                          'Còn ${p.stockQty.toStringAsFixed(p.stockQty % 1 == 0 ? 0 : 1)} ${p.unit}',
                          style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w700, color: _kRed)),
                      ),
                    ]),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DRightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _DRightCard({required this.title, required this.icon, required this.child});

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

class _DStatRow extends StatelessWidget {
  final String label, value;
  final Color color;
  const _DStatRow({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: GoogleFonts.outfit(fontSize: 13, color: _kInk))),
      Text(value, style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
    ]),
  );
}
