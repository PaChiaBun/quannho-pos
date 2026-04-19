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
          colors: [_kNavy, _kNavyLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
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
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
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
                  // Avatar
                  Container(
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
                final orders   = s.value?.todayOrders ?? 0;
                final customers = s.value?.todayCustomers ?? 0;
                return Wrap(
                  spacing: 8,
                  children: [
                    _Pill(icon: Icons.receipt_long_rounded,
                        text: '$orders đơn'),
                    _Pill(icon: Icons.people_rounded,
                        text: '$customers khách'),
                  ],
                );
              }),
            ],
          ),
        ),
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
              '${activeModules.length} đang bật • Giữ để sắp xếp',
              style: const TextStyle(
                fontSize: 12,
                color: _kMuted,
              ),
            ),
          ],
        ),
        const Spacer(),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: GestureDetector(
            onTap: _toggleEditMode,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _isEditMode ? _kOrange : _kNavy,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _isEditMode ? 'Xong' : 'Sửa',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LEGO GRID — ReorderableWrap for drag & drop
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildLegoGrid(List<dynamic> activeModules) {
    if (_moduleOrder.isEmpty) {
      return _buildEmptyModules();
    }

    // Build tiles list theo _moduleOrder (local)
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
          height: 130,
          onTap: () => _navigateTo(config.route),
          onRemove: () => _removeModule(id),
        ),
      );
    }).toList();

    if (_isEditMode) {
      // Thêm tile "+" ở cuối
      tiles.add(KeyedSubtree(
        key: const ValueKey('__add__'),
        child: AddModuleTile(
          height: 130,
          onTap: _openModulePicker,
        ),
      ));
    }

    // Layout grid: 2 cột, cuộn nếu nhiều module
    // Dùng ReorderableListView theo grid pattern
    return _isEditMode
        ? _buildReorderableGrid(tiles)
        : _buildStaticGrid(tiles);
  }

  /// Static grid (view mode) — 2 cột
  Widget _buildStaticGrid(List<Widget> tiles) {
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(
              child: tiles[i]
                  .animate(delay: (i * 80).ms)
                  .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
                  .fadeIn(duration: 300.ms),
            ),
            if (i + 1 < tiles.length) ...[
              const SizedBox(width: 10),
              Expanded(
                child: tiles[i + 1]
                    .animate(delay: ((i + 1) * 80).ms)
                    .slideY(begin: 0.2, end: 0, duration: 350.ms, curve: Curves.easeOutCubic)
                    .fadeIn(duration: 300.ms),
              ),
            ] else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 10));
    }
    return Column(children: rows);
  }

  /// Edit/Reorder grid — dùng drag handle per row
  Widget _buildReorderableGrid(List<Widget> tiles) {
    // Group vào pairs (2 cột)
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += 2) {
      rows.add(
        Row(
          children: [
            Expanded(child: tiles[i]),
            if (i + 1 < tiles.length) ...[
              const SizedBox(width: 10),
              Expanded(child: tiles[i + 1]),
            ] else
              const Expanded(child: SizedBox()),
          ],
        ),
      );
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 10));
    }

    return Column(children: [
      ...rows,
      const SizedBox(height: 8),
      // Drag helper hint
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.drag_indicator_rounded,
              size: 14, color: _kMuted.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Text(
            'Kéo tile để sắp xếp',
            style: TextStyle(
              fontSize: 11,
              color: _kMuted.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    ]);
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _kOrange.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.edit_rounded,
              size: 14, color: _kOrange.withValues(alpha: 0.8)),
          const SizedBox(width: 8),
          Text(
            'Đang chỉnh sửa — nhấn [✕] để tháo module',
            style: TextStyle(
              fontSize: 12,
              color: _kOrange.withValues(alpha: 0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: -0.5, end: 0, duration: 250.ms)
        .fadeIn(duration: 200.ms);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TODAY STATS — Stat cards hàng ngang — LIVE DATA
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTodayStats(
    AsyncValue<DashboardStats> statsAsync,
    AsyncValue<List<dynamic>> lowStockAsync,
  ) {
    final stats      = statsAsync.value ?? const DashboardStats(
      todayRevenue: 0, todayOrders: 0, todayCustomers: 0, avgOrderValue: 0);
    final outOfStock = (lowStockAsync.value ?? []).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'TB/đơn',
                value: _fmtShort(stats.avgOrderValue) + 'đ',
                icon: Icons.trending_up_rounded,
                bgColor: _kGreenBg,
                textColor: _kGreen,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Số đơn',
                value: '${stats.todayOrders}',
                icon: Icons.receipt_long_rounded,
                bgColor: const Color(0xFFE3F2FD),
                textColor: const Color(0xFF1565C0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Sắp hết',
                value: '$outOfStock',
                icon: Icons.warning_amber_rounded,
                bgColor: _kRedBg,
                textColor: _kRed,
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
  // TOP ITEMS — Sản phẩm bán chạy (placeholder cho đến khi POS hoạt động)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTopItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Sản phẩm',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kInk,
                letterSpacing: -0.3,
              ),
            ),
            const Spacer(),
            Consumer(builder: (_, ref, __) {
              final productsAsync = ref.watch(allProductsProvider);
              return productsAsync.when(
                data: (p) => Text(
                  '${p.length} mục',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _kOrange,
                    fontWeight: FontWeight.w600,
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
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFE0D8CC), width: 1),
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
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: const Color(0xFFE0D8CC), width: 1),
                ),
                child: Column(
                  children: displayProducts.asMap().entries.map((e) {
                    final p = e.value;
                    final isLast = e.key == displayProducts.length - 1;
                    final isLow =
                        p.minStock > 0 && p.stockQty <= p.minStock;

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              // Number badge
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2EDE4),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: _kNavy,
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
                                          ),
                                        ),
                                        if (isLow)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFEBEE),
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                    Text(
                                      'Tồn: ${p.stockQty.toStringAsFixed(0)} ${p.unit}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _kMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
    // Navigate thông qua bottom nav (index)
    switch (route) {
      case '/pos':
        _goToTab(1);
        break;
      case '/kho':
        _goToTab(2);
        break;
      case '/finance':
        _goToTab(3);
        break;
      default:
        break;
    }
  }

  void _goToTab(int index) {
    // Tìm MainShell state và chuyển tab
    // Sử dụng callback từ parent nếu có
    // Tạm thời dùng MediaQuery để detect và route
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

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: const BoxDecoration(
          color: _kWhite20,
          borderRadius: BorderRadius.all(Radius.circular(30)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: _kWhite60),
            const SizedBox(width: 5),
            Text(
              text,
              style: const TextStyle(
                color: _kWhite85,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color bgColor;
  final Color textColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: textColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: textColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: textColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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
