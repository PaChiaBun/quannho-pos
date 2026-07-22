import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';
import '../repository/kho_chuyen_nghiep_repository.dart';
import 'recipe_form_screen.dart';
import 'recipe_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// RECIPE LIST SCREEN — Danh sách công thức món ăn
// ─────────────────────────────────────────────────────────────────────────────

class RecipeListScreen extends ConsumerStatefulWidget {
  const RecipeListScreen({super.key});

  @override
  ConsumerState<RecipeListScreen> createState() => _RecipeListScreenState();
}

class _RecipeListScreenState extends ConsumerState<RecipeListScreen> {
  String _query = '';
  String? _categoryFilter;

  static const _categories = [
    'Tất cả', 'Món chính', 'Khai vị', 'Tráng miệng',
    'Đồ uống', 'Súp & Cháo', '🧋 Topping', 'Khác',
  ];

  @override
  Widget build(BuildContext context) {
    final recipesAsync  = ref.watch(recipesProvider);
    final priceMapAsync = ref.watch(sellPriceMapProvider);
    final priceMap = priceMapAsync.when(
      data: (m) => m,
      loading: () => <String, double>{},
      error: (_, __) => <String, double>{},
    );

    return Scaffold(
      backgroundColor: KhoTheme.bg,
      body: recipesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (all) {
          final filtered = all.where((r) {
            final matchQ  = _query.isEmpty ||
                r.name.toLowerCase().contains(_query.toLowerCase());
            final matchCat = _categoryFilter == null ||
                _categoryFilter == 'Tất cả' ||
                r.category == _categoryFilter;
            return matchQ && matchCat;
          }).toList();

          return CustomScrollView(
            slivers: [
              // ── Search bar ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: GoogleFonts.outfit(fontSize: 14, color: KhoTheme.ink),
                    decoration: KhoTheme.inputDecoration(
                      hint: 'Tìm công thức...',
                      prefix: const Icon(Icons.search_rounded,
                          color: KhoTheme.muted, size: 20),
                    ),
                  ),
                ),
              ),
              // ── Category chips ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final sel = (_categoryFilter ?? 'Tất cả') == cat;
                      return GestureDetector(
                        onTap: () => setState(() =>
                            _categoryFilter = cat == 'Tất cả' ? null : cat),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? KhoTheme.violet : KhoTheme.card,
                            borderRadius: BorderRadius.circular(KhoTheme.radiusChip),
                            border: Border.all(
                              color: sel ? KhoTheme.violet : KhoTheme.border),
                          ),
                          child: Text(cat, style: GoogleFonts.outfit(
                              fontSize: 12.5, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : KhoTheme.muted)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // ── Recipe cards ──────────────────────────────────────────────
              if (filtered.isEmpty)
                SliverFillRemaining(
                  child: Center(child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book_rounded,
                          size: 64, color: KhoTheme.muted.withOpacity(0.4)),
                      const SizedBox(height: 16),
                      Text('Chưa có công thức nào',
                          style: GoogleFonts.outfit(
                              fontSize: 15, color: KhoTheme.muted,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: () => _openForm(context),
                        icon: const Icon(Icons.add_rounded),
                        label: Text('Tạo công thức đầu tiên',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                        style: FilledButton.styleFrom(
                          backgroundColor: KhoTheme.violet,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  )),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final r = filtered[i];
                        final sellPrice = r.posProductId != null
                            ? (priceMap[r.posProductId] ?? 0.0)
                            : 0.0;
                        return _RecipeCard(
                          recipe: r,
                          sellPrice: sellPrice,
                          onTap: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) => RecipeDetailScreen(
                                      recipe: r, sellPrice: sellPrice))),
                          onEdit: () => _openForm(context, recipe: r),
                          onDelete: () => _delete(r),
                        )
                            .animate(delay: (i * 50).ms)
                            .fadeIn(duration: 250.ms)
                            .slideY(begin: 0.05, end: 0);
                      },
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'recipe_list_fab',
        onPressed: () => _openForm(context),
        backgroundColor: KhoTheme.violet,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Tạo công thức',
            style: GoogleFonts.outfit(
                color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, {RecipeModel? recipe}) async {
    // Nếu là edit: fetch lại từ DB để lấy dữ liệu mới nhất (tránh cache cũ)
    RecipeModel? toEdit = recipe;
    if (recipe != null) {
      try {
        toEdit = await ref.read(khoProRepositoryProvider).fetchRecipeById(recipe.id)
            ?? recipe;
      } catch (_) {
        toEdit = recipe; // fallback nếu fetch lỗi
      }
    }
    if (!context.mounted) return;
    final result = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => RecipeFormScreen(existing: toEdit)));
    if (result == true) ref.invalidate(recipesProvider);
  }

  Future<void> _delete(RecipeModel recipe) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Xoá công thức?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Xoá "${recipe.name}" — không thể khôi phục.',
            style: GoogleFonts.outfit()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: KhoTheme.red),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(khoProRepositoryProvider).deleteRecipe(recipe.id);
      ref.invalidate(recipesProvider);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RECIPE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _RecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final double sellPrice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RecipeCard({
    required this.recipe,
    required this.sellPrice,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final hasPos  = recipe.posProductId?.isNotEmpty == true;
    final cost    = recipe.costPerServing;
    final hasSell = sellPrice > 0;
    final profit  = hasSell ? sellPrice - cost : 0.0;
    final margin  = hasSell && sellPrice > 0 ? profit / sellPrice : 0.0;
    final foodCostPct = hasSell && sellPrice > 0 ? cost / sellPrice : 0.0;

    // Badge màu theo margin
    Color marginColor;
    String marginLabel;
    if (!hasSell) {
      marginColor = KhoTheme.muted;
      marginLabel = 'Chưa gắn giá';
    } else if (margin >= 0.6) {
      marginColor = KhoTheme.green;
      marginLabel = '${(margin * 100).toStringAsFixed(0)}% lãi';
    } else if (margin >= 0.3) {
      marginColor = KhoTheme.amber;
      marginLabel = '${(margin * 100).toStringAsFixed(0)}% lãi';
    } else {
      marginColor = KhoTheme.red;
      marginLabel = '${(margin * 100).toStringAsFixed(0)}% lãi';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: KhoTheme.card,
          borderRadius: BorderRadius.circular(KhoTheme.radiusCardLg),
          border: Border.all(color: KhoTheme.border),
          boxShadow: KhoTheme.cardShadow,
        ),
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              decoration: BoxDecoration(
                color: KhoTheme.bg,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(KhoTheme.radiusCardLg)),
              ),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: KhoTheme.violet.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty
                      ? Image.network(
                          recipe.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.menu_book_rounded,
                            color: KhoTheme.violet,
                            size: 20,
                          ),
                        )
                      : const Icon(
                          Icons.menu_book_rounded,
                          color: KhoTheme.violet,
                          size: 20,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(recipe.name, style: GoogleFonts.outfit(
                          fontSize: 15, fontWeight: FontWeight.w800,
                          color: KhoTheme.ink)),
                      if (recipe.category?.isNotEmpty == true)
                        Text(recipe.category!,
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: KhoTheme.muted)),
                    ])),
                // Margin badge
                if (hasPos) Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: marginColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(marginLabel, style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w800,
                      color: marginColor)),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: KhoTheme.muted, size: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'edit',
                        child: Row(children: [
                          const Icon(Icons.edit_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text('Chỉnh sửa', style: GoogleFonts.outfit()),
                        ])),
                    PopupMenuItem(value: 'delete',
                        child: Row(children: [
                          const Icon(Icons.delete_rounded,
                              size: 16, color: KhoTheme.red),
                          const SizedBox(width: 8),
                          Text('Xoá', style: GoogleFonts.outfit(
                              color: KhoTheme.red)),
                        ])),
                  ],
                ),
              ]),
            ),

            // ── Body ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(children: [
                Row(children: [
                  Icon(Icons.egg_alt_rounded, size: 13, color: KhoTheme.muted),
                  const SizedBox(width: 4),
                  Text('${recipe.ingredients.length} nguyên liệu',
                      style: GoogleFonts.outfit(fontSize: 12, color: KhoTheme.muted)),
                  const SizedBox(width: 12),
                  Icon(Icons.people_rounded, size: 13, color: KhoTheme.muted),
                  const SizedBox(width: 4),
                  Text('${recipe.servingSize.toStringAsFixed(0)} ${recipe.servingUnit}',
                      style: GoogleFonts.outfit(fontSize: 12, color: KhoTheme.muted)),
                  const Spacer(),
                  // Giá vốn
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('Giá vốn', style: GoogleFonts.outfit(
                        fontSize: 10, color: KhoTheme.muted)),
                    Text(fmtMoney(cost), style: GoogleFonts.outfit(
                        fontSize: 15, fontWeight: FontWeight.w900,
                        color: KhoTheme.violet)),
                  ]),
                ]),

                // ── Profit row (chỉ khi có giá bán) ──────────────────
                if (hasSell) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Giá bán', style: GoogleFonts.outfit(
                          fontSize: 10, color: KhoTheme.muted)),
                      Text(fmtMoney(sellPrice), style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: KhoTheme.ink)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Text('Lãi gộp', style: GoogleFonts.outfit(
                          fontSize: 10, color: KhoTheme.muted)),
                      Text(fmtMoney(profit), style: GoogleFonts.outfit(
                          fontSize: 13, fontWeight: FontWeight.w700,
                          color: profit > 0 ? KhoTheme.green : KhoTheme.red)),
                    ])),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Food cost', style: GoogleFonts.outfit(
                          fontSize: 10, color: KhoTheme.muted)),
                      Text('${(foodCostPct * 100).toStringAsFixed(0)}%',
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: marginColor)),
                    ])),
                  ]),
                  const SizedBox(height: 6),
                  // Food cost bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: foodCostPct.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: KhoTheme.green.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(marginColor),
                    ),
                  ),
                ],
              ]),
            ),

            // ── Footer POS badge ────────────────────────────────────────
            if (hasPos)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: KhoTheme.green.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(KhoTheme.radiusCardLg)),
                  border: Border(top: BorderSide(
                      color: KhoTheme.green.withOpacity(0.2))),
                ),
                child: Row(children: [
                  Icon(Icons.link_rounded, size: 13, color: KhoTheme.green),
                  const SizedBox(width: 4),
                  Text('Đã gắn menu POS — Tự trừ kho khi bán',
                      style: GoogleFonts.outfit(
                          fontSize: 11.5, color: KhoTheme.green,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
