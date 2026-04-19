import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/providers/app_providers.dart';
import '../core/providers/dashboard_providers.dart';
import '../core/repositories/dashboard_repository.dart';
import '../modules/kho/providers/kho_providers.dart';
import '../shared/widgets/module_tile.dart';
import 'module_picker_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final modulesAsync  = ref.watch(allModulesProvider);
    final lowStockAsync = ref.watch(lowStockProductsProvider);
    final todayStats    = ref.watch(todayStatsProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: modulesAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _kNavy),
        ),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (modules) {
          // Lấy các module đang active, sort theo position từ DB
          final activeModules = modules
              .where((m) => m.isActive)
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));

          // Khởi tạo local order lần đầu
          if (!_orderInitialized || _moduleOrder.isEmpty) {
            _moduleOrder = activeModules.map((m) => m.id).toList();
            _orderInitialized = true;
          } else {
            // Sync: thêm module mới vào cuối, xóa module bị tắt
            final activeIds = activeModules.map((m) => m.id).toSet();
            _moduleOrder.removeWhere((id) => !activeIds.contains(id));
            for (final m in activeModules) {
              if (!_moduleOrder.contains(m.id)) _moduleOrder.add(m.id);
            }
          }

          return CustomScrollView(
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

                        // ── Top items ──────────────────────────────
                        const SizedBox(height: 20),
                        _buildTopItems(),

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
                          return Text(
                            nameAsync.when(
                              data: (n) => n,
                              loading: () => 'Quán Nhỏ',
                              error: (_, __) => 'Quán Nhỏ',
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.8,
                            ),
                          );
                        }),
                        const SizedBox(height: 2),
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
                  ),
                  // Notification bell
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _kWhite20,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
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

              // Revenue display
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
                        Consumer(builder: (_, r, __) {
                          final s   = r.watch(todayStatsProvider);
                          final rev = s.value?.todayRevenue ?? 0;
                          return Text(
                            _fmtRevenue(rev),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 42,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -2,
                              height: 1.0,
                            ),
                          );
                        }),
                        const Text(
                          'đồng',
                          style: TextStyle(
                            color: _kWhite60,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
                Consumer(builder: (_, r, __) {
                  final s = r.watch(todayStatsProvider);
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
        // Sửa / Xong pill button
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

  // ─────────────────────────────────────────────────────────────────────────
  // LEGO GRID — 2-column grid, equal-height tiles
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLegoGrid(List<dynamic> activeModules) {
    if (_moduleOrder.isEmpty) {
      return _buildEmptyModules();
    }

    final tiles = _moduleOrder.map((id) {
      final config = kModuleConfigs[id];
      if (config == null) return const SizedBox.shrink();
      final idx = _moduleOrder.indexOf(id);
      return KeyedSubtree(
        key: ValueKey(id),
        child: ModuleTile(
          data: config,
          isEditMode: _isEditMode,
          isEven: idx.isEven,
          // entryDelay: -1 (default) → no animation wrapper → GridView controls size
          onTap: () => _navigateTo(config.route),
          onRemove: () => _removeModule(id),
        ),
      );
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

  /// Static grid — GridView 2 cột, aspect ratio cố định
  Widget _buildStaticGrid(List<Widget> tiles) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0, // vuông hoàn toàn
      ),
      itemCount: tiles.length,
      itemBuilder: (_, i) => tiles[i],
    );
  }

  /// Reorder/Edit grid — same GridView as static, tiles are jiggable
  Widget _buildReorderableGrid(List<Widget> tiles) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title
        Row(
          children: [
            const Text(
              'Hôm nay',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kInk,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _kNavy.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                DateFormat('HH:mm').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kNavy,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Top row: 2 big cards
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PremiumStatCard(
                label: 'Giá TB / đơn',
                value: _fmtShort(stats.avgOrderValue) + 'đ',
                icon: Icons.trending_up_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                delay: 0,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _PremiumStatCard(
                label: 'Số đơn',
                value: '${stats.todayOrders}',
                icon: Icons.receipt_long_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                delay: 80,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Bottom row: 2 cards
        Row(
          children: [
            Expanded(
              flex: 2,
              child: _PremiumStatCard(
                label: 'Khách hôm nay',
                value: '${stats.todayCustomers}',
                icon: Icons.people_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                delay: 160,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 3,
              child: _PremiumStatCard(
                label: 'Sắp hết hàng',
                value: lowCount == 0 ? 'Ổn 👍' : '$lowCount SP',
                icon: lowCount == 0
                    ? Icons.check_circle_rounded
                    : Icons.warning_amber_rounded,
                gradient: LinearGradient(
                  colors: lowCount == 0
                      ? [const Color(0xFF004D40), const Color(0xFF00796B)]
                      : [const Color(0xFFB71C1C), const Color(0xFFE53935)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                delay: 240,
              ),
            ),
          ],
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
                                '${_formatCurrency(p.sellPrice)}đ',
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
    setState(() => _isEditMode = !_isEditMode);
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

    // Optimistic update — xóa khỏi list trước
    setState(() => _moduleOrder.remove(moduleId));

    // Ghi vào DB
    await ref.read(moduleRepositoryProvider).deactivate(moduleId);
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
      setState(() => _moduleOrder.add(result));
    }
  }

  void _navigateTo(String? route) {
    if (route == null) return;
    final tabMap = {
      '/pos':     1,
      '/kho':     2,
      '/finance': 3,
      '/loyalty': 4,
      '/report':  5,
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
  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}k';
    }
    return amount.toStringAsFixed(0);
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
// FORMAT HELPERS
// ─────────────────────────────────────────────────────────────────────────────
String _fmtRevenue(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}

String _fmtShort(double v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
  if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}K';
  return v.toStringAsFixed(0);
}
