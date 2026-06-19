import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/utils/money_formatter.dart';
import '../../../modules/kho/providers/kho_providers.dart';
import '../../../modules/kho/repository/kho_repository.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';
import '../repository/kho_chuyen_nghiep_repository.dart';
import 'ingredient_list_screen.dart';
import 'recipe_form_screen.dart';
import 'recipe_detail_screen.dart';
import 'production_order_screen.dart';

// ── palette ──────────────────────────────────────────────────────────────────
const _kNavy       = Color(0xFF1A1560);
const _kViolet     = Color(0xFF7C3AED);
const _kGold       = Color(0xFFD97706);
const _kGreen      = Color(0xFF059669);
const _kRed        = Color(0xFFDC2626);
const _kBg         = Color(0xFFF4F1FB);
const _kCard       = Colors.white;
const _kInk        = Color(0xFF1A1207);
const _kMuted      = Color(0xFF9187A0);

class KhoProDashboardScreen extends ConsumerWidget {
  const KhoProDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync     = ref.watch(recipesProvider);
    final todayOrdersAsync = ref.watch(todayProductionOrdersProvider);
    final khoStats         = ref.watch(khoStatsProvider);
    final allStockAsync    = ref.watch(allStockProvider); // để đếm ingredient

    return Container(
      color: _kBg,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero banner ────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeroBanner(ref, recipesAsync, todayOrdersAsync, khoStats, allStockAsync)),

          // ── Lệnh SX hôm nay ────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.precision_manufacturing_rounded,
              iconColor: _kGold,
              label: 'Lệnh sản xuất hôm nay',
              actionLabel: '+ Thêm',
              onAction: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProductionOrderScreen())),
            ).animate(delay: 180.ms).fadeIn(duration: 280.ms).slideX(begin: -0.05),
          ),

          todayOrdersAsync.when(
            loading: () => const SliverToBoxAdapter(
                child: Center(child: Padding(padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: _kViolet)))),
            error: (e, _) => SliverToBoxAdapter(
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text('Lỗi: $e', style: TextStyle(color: _kRed)))),
            data: (orders) => orders.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: _EmptyCard(
                        icon: Icons.precision_manufacturing_rounded,
                        iconColor: _kGold,
                        label: 'Tạo lệnh sản xuất hôm nay',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const ProductionOrderScreen())),
                      ).animate(delay: 220.ms).fadeIn(duration: 300.ms),
                    ))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _ProductionTile(order: orders[i], ref: ref)
                            .animate(delay: (220 + i * 50).ms)
                            .fadeIn(duration: 280.ms)
                            .slideY(begin: 0.06),
                        childCount: orders.length,
                      ),
                    )),
          ),

          // ── Cảnh báo tồn kho sắp hết ──────────────────────────────────────────
          ...allStockAsync.whenOrNull(
            data: (items) {
              final lowItems = (items as List<StockItem>)
                  .where((i) =>
                      (i.productType == 'ingredient' || i.productType == 'semi_finished') &&
                      ((i.stockQty as double?) ?? 0) <= ((i.minStock as double?) ?? 0) &&
                      ((i.minStock as double?) ?? 0) > 0)
                  .toList()
                  ..sort((a, b) {
                    final aqty = (a.stockQty as double?) ?? 0;
                    final bmn  = (b.minStock as double?) ?? 1;
                    final bqty = (b.stockQty as double?) ?? 0;
                    final amn  = (a.minStock as double?) ?? 1;
                    if (aqty <= 0 && bqty > 0) return -1;
                    if (bqty <= 0 && aqty > 0) return 1;
                    return (aqty / amn).compareTo(bqty / bmn);
                  });

              if (lowItems.isEmpty) return null;

              return [
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    icon: Icons.warning_amber_rounded,
                    iconColor: _kRed,
                    label: 'Cần nhập hàng (${lowItems.length})',
                    actionLabel: 'Xem kho',
                    onAction: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const IngredientListScreen())),
                  ).animate(delay: 150.ms).fadeIn(duration: 280.ms).slideX(begin: -0.05),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _LowStockTile(item: lowItems[i])
                          .animate(delay: (170 + i * 40).ms)
                          .fadeIn(duration: 260.ms)
                          .slideY(begin: 0.06),
                      childCount: lowItems.length,
                    ),
                  ),
                ),
              ];
            },
          ) ?? [],

          // ── Công thức gần đây ───────────────────────────────────────────
          SliverToBoxAdapter(
            child: _SectionHeader(
              icon: Icons.menu_book_rounded,
              iconColor: _kViolet,
              label: 'Công thức gần đây',
              actionLabel: '+ Tạo mới',
              onAction: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const RecipeFormScreen())),
            ).animate(delay: 260.ms).fadeIn(duration: 280.ms).slideX(begin: -0.05),
          ),

          recipesAsync.when(
            loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
            error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
            data: (recipes) => recipes.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                      child: _EmptyCard(
                        icon: Icons.menu_book_rounded,
                        iconColor: _kViolet,
                        label: 'Chưa có công thức nào. Tạo ngay!',
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const RecipeFormScreen())),
                      ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
                    ))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _RecipeTile(recipe: recipes[i])
                            .animate(delay: (300 + i * 40).ms)
                            .fadeIn(duration: 260.ms)
                            .slideY(begin: 0.05),
                        childCount: recipes.take(5).length,
                      ),
                    )),
          ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
        ],
      ),
    );
  }

  // ── Hero banner — 4 KPI cards hài hoà brand Navy/Cam ─────────────────────
  Widget _buildHeroBanner(
    WidgetRef ref,
    AsyncValue recipesAsync,
    AsyncValue todayOrdersAsync,
    AsyncValue khoStats,
    AsyncValue allStockAsync,
  ) {
    final recipeCount = recipesAsync.whenOrNull(data: (r) => (r as List).length) ?? 0;
    final todayCount  = todayOrdersAsync.whenOrNull(data: (o) => (o as List).length) ?? 0;
    final pendingCount = todayOrdersAsync.whenOrNull(
        data: (o) => (o as List<ProductionOrderModel>).where((x) => x.isPending).length) ?? 0;
    // Đếm đúng: chỉ ingredient, không đếm món bán
    final ingredientCount = allStockAsync.whenOrNull(
        data: (items) => (items as List<StockItem>)
            .where((i) => i.productType == 'ingredient').length) ?? 0;
    final lowCount = khoStats.whenOrNull(data: (s) => s.lowStockItems) ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Row 1 — đồng đều chiều cao
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _GradientKpiCard(
                label: 'Công thức',
                value: '$recipeCount',
                icon: Icons.menu_book_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A1560), Color(0xFF2D2B8A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                delay: 60,
              )),
              const SizedBox(width: 10),
              Expanded(child: _GradientKpiCard(
                label: 'SX hôm nay',
                value: '$todayCount',
                subtitle: '$pendingCount chờ',
                icon: Icons.precision_manufacturing_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE85D20), Color(0xFFF97316)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                delay: 100,
              )),
            ]),
          ),
          const SizedBox(height: 10),
          // Row 2
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _GradientKpiCard(
                label: 'Nguyên liệu',
                value: '$ingredientCount',
                icon: Icons.egg_alt_rounded,
                gradient: const LinearGradient(
                  colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                delay: 140,
              )),
              const SizedBox(width: 10),
              Expanded(child: _GradientKpiCard(
                label: 'Sắp hết kho',
                value: '$lowCount',
                icon: Icons.warning_amber_rounded,
                gradient: (lowCount as int) > 0
                  ? const LinearGradient(
                      colors: [Color(0xFFB91C1C), Color(0xFFDC2626)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF065F46), Color(0xFF059669)],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                delay: 180,
              )),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GRADIENT KPI CARD
// ─────────────────────────────────────────────────────────────────────────────
class _GradientKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final int delay;

  const _GradientKpiCard({
    required this.label, required this.value, required this.icon,
    required this.gradient, required this.delay, this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12), // ‼️ FIX: giảm padding tránh overflow
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.38),
            blurRadius: 16, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(children: [
        // Background circle decoration
        Positioned(right: -14, bottom: -14,
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // ‼️ FIX: không chiếm thêm space không cần
          children: [
            Container(
              width: 36, height: 36, // ‼️ FIX: nhỏ hơn 2px
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: Colors.white, size: 19),
            ),
            const SizedBox(height: 8),
            // ‼️ FIX: FittedBox tránh overflow khi số quá lớn
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: GoogleFonts.outfit(
                fontSize: 26, fontWeight: FontWeight.w900,
                color: Colors.white, height: 1.0, letterSpacing: -0.8,
              )),
            ),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.outfit(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.80),
            ), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (subtitle != null) ...[
              const SizedBox(height: 1),
              Text(subtitle!, style: GoogleFonts.outfit(
                fontSize: 10, color: Colors.white.withValues(alpha: 0.65),
              ), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ]),
    )
      .animate(delay: delay.ms)
      .fadeIn(duration: 300.ms)
      .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.icon, required this.iconColor,
    required this.label, required this.actionLabel, required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 6, 12, 10),
    child: Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: iconColor, size: 16),
      ),
      const SizedBox(width: 8),
      Text(label, style: GoogleFonts.outfit(
        fontSize: 14.5, fontWeight: FontWeight.w800, color: _kInk,
      )),
      const Spacer(),
      GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onAction(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(actionLabel, style: GoogleFonts.outfit(
            fontSize: 12, fontWeight: FontWeight.w700, color: iconColor,
          )),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCTION ORDER TILE
// ─────────────────────────────────────────────────────────────────────────────
class _ProductionTile extends StatelessWidget {
  final ProductionOrderModel order;
  final WidgetRef ref;
  const _ProductionTile({required this.order, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDone    = order.status == 'done';
    final isPending = order.status == 'pending';
    final color = isDone ? _kGreen : isPending ? _kGold : _kViolet;
    final label = isDone ? 'Xong ✓' : isPending ? 'Chờ' : 'Đang làm';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ProductionOrderScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              // Left accent
              Container(
                width: 4, height: 42,
                decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4)),
              ),
              const SizedBox(width: 12),
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.precision_manufacturing_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order.recipeName, style: GoogleFonts.outfit(
                  fontSize: 14, fontWeight: FontWeight.w800, color: _kInk)),
                const SizedBox(height: 2),
                Text('${order.quantity.toStringAsFixed(0)} phần',
                  style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
              ])),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(label, style: GoogleFonts.outfit(
                  fontSize: 11, fontWeight: FontWeight.w700, color: color)),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECIPE TILE
// ─────────────────────────────────────────────────────────────────────────────
class _RecipeTile extends StatelessWidget {
  final RecipeModel recipe;
  const _RecipeTile({required this.recipe});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: _kCard,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12, offset: const Offset(0, 4)),
      ],
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            )),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 4, height: 42,
              decoration: BoxDecoration(
                color: _kViolet, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF9D5CF6)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: _kViolet.withValues(alpha: 0.30),
                      blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(recipe.name, style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w800, color: _kInk)),
              const SizedBox(height: 2),
              Text('${recipe.ingredients.length} NL  ·  ${recipe.servingSize.toStringAsFixed(0)} ${recipe.servingUnit}',
                style: GoogleFonts.outfit(fontSize: 12, color: _kMuted)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(fmtMoney(recipe.costPerServing), style: GoogleFonts.outfit(
                fontSize: 14, fontWeight: FontWeight.w900, color: _kViolet)),
              Text('/phần', style: GoogleFonts.outfit(fontSize: 10, color: _kMuted)),
            ]),
          ]),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  const _EmptyCard({required this.icon, required this.iconColor,
      required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () { HapticFeedback.lightImpact(); onTap(); },
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.outfit(
          fontSize: 13.5, fontWeight: FontWeight.w700, color: iconColor)),
      ]),
    ),
  );
}

// ────────────────────────────────────────────────────────────────────────────────
// LOW STOCK TILE
// ────────────────────────────────────────────────────────────────────────────────
class _LowStockTile extends StatelessWidget {
  final dynamic item; // StockItem
  const _LowStockTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final qty = (item.stockQty as double?) ?? 0;
    final min = (item.minStock as double?) ?? 0;
    final isOut = qty <= 0;
    final pct  = min > 0 ? (qty / min).clamp(0.0, 1.0) : 0.0;
    final urgentColor = isOut ? _kRed : _kGold;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: urgentColor.withOpacity(0.35), width: 1.5),
        boxShadow: [
          BoxShadow(color: urgentColor.withOpacity(0.08),
              blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(children: [
        // Icon cảnh báo
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: urgentColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            isOut ? Icons.remove_shopping_cart_rounded
                  : Icons.warning_amber_rounded,
            color: urgentColor, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name as String,
              style: GoogleFonts.outfit(
                  fontSize: 13, fontWeight: FontWeight.w800, color: _kInk)),
          const SizedBox(height: 4),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor: urgentColor.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(urgentColor),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            isOut
              ? 'Hết hàng  —  ngưỡng tối thiểu: ${min.toStringAsFixed(0)} ${item.unit}'
              : 'Còn ${qty.toStringAsFixed(0)} ${item.unit}  /  tối thiểu ${min.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(
                fontSize: 11, color: urgentColor, fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(width: 8),
        // Badge trạng thái
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: urgentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            isOut ? 'Hết' : 'Sắp hết',
            style: GoogleFonts.outfit(
                fontSize: 11, fontWeight: FontWeight.w800, color: urgentColor)),
        ),
      ]),
    );
  }
}
