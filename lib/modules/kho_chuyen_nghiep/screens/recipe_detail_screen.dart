import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../core/utils/money_formatter.dart';
import '../providers/kho_chuyen_nghiep_providers.dart';
import '../repository/kho_chuyen_nghiep_repository.dart';

class RecipeDetailScreen extends ConsumerWidget {
  final RecipeModel recipe;
  final double sellPrice;
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
    this.sellPrice = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: KhoTheme.bg,
      appBar: AppBar(
        backgroundColor: KhoTheme.navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(recipe.name, style: GoogleFonts.outfit(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: FutureBuilder<double>(
        future: ref.read(khoProRepositoryProvider).getMaxServings(recipe),
        builder: (context, snap) {
          final maxServings = snap.data ?? 0;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Header card ──────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [KhoTheme.navy, KhoTheme.navyLight],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(KhoTheme.radiusCardLg),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty) ...[
                      Container(
                        width: 48, height: 48,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24, width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            recipe.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.menu_book_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                    Expanded(child: Text(recipe.name, style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.w900))),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: KhoTheme.violet.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(recipe.category ?? 'Món ăn',
                          style: GoogleFonts.outfit(
                              color: Colors.white70, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  if (recipe.description?.isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(recipe.description!, style: GoogleFonts.outfit(
                        color: Colors.white60, fontSize: 13)),
                  ],
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Giá vốn/phần', style: GoogleFonts.outfit(
                            fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(fmtMoney(recipe.costPerServing), style: GoogleFonts.outfit(
                            fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                      ]),
                    )),
                    const SizedBox(width: 10),
                    Expanded(child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Tồn kho đủ nấu', style: GoogleFonts.outfit(
                            fontSize: 10, color: Colors.white60, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 3),
                        Text(
                          snap.connectionState == ConnectionState.waiting
                              ? '...'
                              : '${maxServings.toStringAsFixed(0)} ${recipe.servingUnit}',
                          style: GoogleFonts.outfit(
                              fontSize: 16, fontWeight: FontWeight.w900,
                              color: maxServings > 5 ? KhoTheme.green : KhoTheme.amber),
                        ),
                      ]),
                    )),
                  ]),
                ]),
              ),

              const SizedBox(height: 16),

              // ── Định lượng ──────────────────────────────────────────────
              _sectionHeader('Định lượng nguyên liệu', Icons.egg_alt_rounded),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: KhoTheme.card,
                  borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
                  border: Border.all(color: KhoTheme.border),
                  boxShadow: KhoTheme.subtleShadow,
                ),
                child: Column(
                  children: [
                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: KhoTheme.bg,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(KhoTheme.radiusCard)),
                      ),
                      child: Row(children: [
                        Expanded(flex: 3, child: Text('Nguyên liệu',
                            style: GoogleFonts.outfit(fontSize: 11,
                                fontWeight: FontWeight.w700, color: KhoTheme.muted))),
                        Expanded(flex: 2, child: Text('Số lượng',
                            style: GoogleFonts.outfit(fontSize: 11,
                                fontWeight: FontWeight.w700, color: KhoTheme.muted),
                            textAlign: TextAlign.center)),
                        Expanded(flex: 2, child: Text('Chi phí',
                            style: GoogleFonts.outfit(fontSize: 11,
                                fontWeight: FontWeight.w700, color: KhoTheme.muted),
                            textAlign: TextAlign.right)),
                      ]),
                    ),
                    ...recipe.ingredients.asMap().entries.map((e) {
                      final i  = e.value;
                      final isLast = e.key == recipe.ingredients.length - 1;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          border: isLast ? null : Border(
                              bottom: BorderSide(color: KhoTheme.border)),
                        ),
                        child: Row(children: [
                          Expanded(flex: 3, child: Text(
                              i.ingredientName ?? '—',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: KhoTheme.ink))),
                          Expanded(flex: 2, child: Text(
                              '${i.quantity % 1 == 0 ? i.quantity.toInt() : i.quantity.toStringAsFixed(1)} ${i.unit}',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, color: KhoTheme.muted),
                              textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text(
                              i.lineCost > 0 ? fmtMoney(i.lineCost) : '—',
                              style: GoogleFonts.outfit(
                                  fontSize: 13, fontWeight: FontWeight.w700,
                                  color: KhoTheme.violet),
                              textAlign: TextAlign.right)),
                        ]),
                      );
                    }),
                    // Total row
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: KhoTheme.violet.withOpacity(0.05),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(KhoTheme.radiusCard)),
                        border: Border(top: BorderSide(
                            color: KhoTheme.violet.withOpacity(0.2))),
                      ),
                      child: Row(children: [
                        Text('Tổng giá vốn / ${recipe.servingSize.toStringAsFixed(0)} ${recipe.servingUnit}',
                            style: GoogleFonts.outfit(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: KhoTheme.navy)),
                        const Spacer(),
                        Text(fmtMoney(recipe.costPerServing),
                            style: GoogleFonts.outfit(
                                fontSize: 16, fontWeight: FontWeight.w900,
                                color: KhoTheme.violet)),
                      ]),
                    ),
                  ],
                ),
              ),

              if (recipe.posProductId?.isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: KhoTheme.green.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
                    border: Border.all(color: KhoTheme.green.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.link_rounded, color: KhoTheme.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        'Khi POS bán món này → tự động trừ nguyên liệu theo định lượng',
                        style: GoogleFonts.outfit(
                            fontSize: 12.5, color: KhoTheme.green,
                            fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],

              // ── Phân tích lợi nhuận (chỉ khi có sellPrice) ────────────
              if (sellPrice > 0) ...[
                const SizedBox(height: 16),
                _sectionHeader('Phân tích lợi nhuận', Icons.bar_chart_rounded),
                const SizedBox(height: 8),
                _ProfitCard(cost: recipe.costPerServing, sellPrice: sellPrice),
              ],

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String label, IconData icon) => Row(children: [
    Icon(icon, size: 15, color: KhoTheme.violet),
    const SizedBox(width: 6),
    Text(label, style: GoogleFonts.outfit(
        fontSize: 13.5, fontWeight: FontWeight.w800, color: KhoTheme.navy)),
  ]);
}

// ─────────────────────────────────────────────────────────────────────────────
// PROFIT ANALYSIS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ProfitCard extends StatelessWidget {
  final double cost;
  final double sellPrice;
  const _ProfitCard({required this.cost, required this.sellPrice});

  @override
  Widget build(BuildContext context) {
    final profit      = sellPrice - cost;
    final margin      = profit / sellPrice;
    final foodCostPct = cost / sellPrice;

    Color marginColor;
    String grade;
    if (margin >= 0.6) {
      marginColor = KhoTheme.green;
      grade = '✦ Xuất sắc';
    } else if (margin >= 0.4) {
      marginColor = KhoTheme.green;
      grade = '✓ Tốt';
    } else if (margin >= 0.3) {
      marginColor = KhoTheme.amber;
      grade = '⚠ Trung bình';
    } else {
      marginColor = KhoTheme.red;
      grade = '✗ Cần xem lại';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KhoTheme.card,
        borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
        border: Border.all(color: KhoTheme.border),
        boxShadow: KhoTheme.subtleShadow,
      ),
      child: Column(children: [
        // 3 số liệu chính
        Row(children: [
          _ProfitStat(
            label: 'Giá bán',
            value: fmtMoney(sellPrice),
            color: KhoTheme.navy,
          ),
          _ProfitStat(
            label: 'Giá vốn',
            value: fmtMoney(cost),
            color: KhoTheme.violet,
          ),
          _ProfitStat(
            label: 'Lãi gộp',
            value: fmtMoney(profit),
            color: profit > 0 ? KhoTheme.green : KhoTheme.red,
          ),
        ]),

        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 14),

        // Food cost bar
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('Food Cost Ratio', style: GoogleFonts.outfit(
                    fontSize: 12, fontWeight: FontWeight.w700, color: KhoTheme.muted)),
                const Spacer(),
                Text('${(foodCostPct * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.outfit(
                        fontSize: 13, fontWeight: FontWeight.w800,
                        color: marginColor)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: marginColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(grade, style: GoogleFonts.outfit(
                      fontSize: 10.5, fontWeight: FontWeight.w800,
                      color: marginColor)),
                ),
              ]),
              const SizedBox(height: 8),
              // Stacked bar: cost | profit
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  children: [
                    Expanded(
                      flex: (foodCostPct * 100).round().clamp(1, 99),
                      child: Container(height: 12, color: marginColor.withOpacity(0.7)),
                    ),
                    Expanded(
                      flex: (margin * 100).round().clamp(1, 99),
                      child: Container(height: 12, color: KhoTheme.green.withOpacity(0.3)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                _BarLegend(color: marginColor, label: 'Giá vốn'),
                const SizedBox(width: 14),
                _BarLegend(color: KhoTheme.green, label: 'Lãi gộp'),
                const Spacer(),
                Text(
                  'Margin: ${(margin * 100).toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: marginColor),
                ),
              ]),
            ]),
          ),
        ]),
      ]),
    );
  }
}

class _ProfitStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _ProfitStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    children: [
      Text(label, style: GoogleFonts.outfit(
          fontSize: 11, color: KhoTheme.muted, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(value, style: GoogleFonts.outfit(
            fontSize: 16, fontWeight: FontWeight.w900, color: color)),
      ),
    ],
  ));
}

class _BarLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _BarLegend({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 4),
    Text(label, style: GoogleFonts.outfit(
        fontSize: 10, color: KhoTheme.muted, fontWeight: FontWeight.w600)),
  ]);
}

