import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/kho_theme.dart';
import '../../../modules/kho/providers/kho_providers.dart';

class IngredientListScreen extends ConsumerStatefulWidget {
  const IngredientListScreen({super.key});

  @override
  ConsumerState<IngredientListScreen> createState() => _IngredientListScreenState();
}

class _IngredientListScreenState extends ConsumerState<IngredientListScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final stockAsync = ref.watch(allStockProvider);

    return Scaffold(
      backgroundColor: KhoTheme.bg,
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:   (e, _) => Center(child: Text('Lỗi: $e')),
        data: (items) {
          // Chỉ hiện: ingredient (nguyên liệu thô) + semi_finished (bán TP)
          // Ẩn 'finished' (thành phẩm) và 'purchased' (hàng mua sẵn bán trực tiếp)
          final filtered = items.where((i) {
            final isKhoType = i.productType == 'ingredient' ||
                              i.productType == 'semi_finished';
            final matchQ = _query.isEmpty ||
                i.name.toLowerCase().contains(_query.toLowerCase());
            return isKhoType && matchQ;
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(children: [
                    TextField(
                      onChanged: (v) => setState(() => _query = v),
                      style: GoogleFonts.outfit(fontSize: 14, color: KhoTheme.ink),
                      decoration: KhoTheme.inputDecoration(
                        hint: 'Tìm nguyên liệu...',
                        prefix: const Icon(Icons.search_rounded,
                            color: KhoTheme.muted, size: 20),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: KhoTheme.violet.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: KhoTheme.violet.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_rounded,
                            size: 14, color: KhoTheme.violet),
                        const SizedBox(width: 6),
                        Expanded(child: Text(
                            'Dùng chung với Kho Hàng. Nhập hàng qua tab Phiếu nhập.',
                            style: GoogleFonts.outfit(
                                fontSize: 11.5, color: KhoTheme.violet,
                                fontWeight: FontWeight.w500))),
                      ]),
                    ),
                  ]),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final item = filtered[i];
                      return _IngredientCard(item: item)
                          .animate(delay: (i * 40).ms)
                          .fadeIn(duration: 200.ms)
                          .slideY(begin: 0.04);
                    },
                    childCount: filtered.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _IngredientCard extends StatelessWidget {
  final dynamic item; // StockItem

  const _IngredientCard({required this.item});

  static ({Color color, IconData icon, String label}) _typeStyle(String t) =>
      switch (t) {
        'semi_finished' => (color: const Color(0xFF1565C0), icon: Icons.blender_rounded,   label: 'Bán thành phẩm'),
        _               => (color: KhoTheme.violet,          icon: Icons.egg_alt_rounded,   label: 'Nguyên liệu'),
      };

  @override
  Widget build(BuildContext context) {
    final qty    = (item.stockQty as double?) ?? 0;
    final min    = (item.minStock as double?) ?? 0;
    final isLow  = min > 0 && qty <= min;
    final isOut  = qty <= 0;
    final statusColor = isOut  ? KhoTheme.red
                       : isLow ? KhoTheme.amber
                       : KhoTheme.green;
    final ts = _typeStyle(item.productType as String? ?? 'ingredient');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KhoTheme.card,
        borderRadius: BorderRadius.circular(KhoTheme.radiusCard),
        border: Border.all(color: isLow ? statusColor.withOpacity(0.3) : KhoTheme.border),
        boxShadow: KhoTheme.subtleShadow,
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: ts.color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(ts.icon, color: ts.color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name as String, style: GoogleFonts.outfit(
              fontSize: 14, fontWeight: FontWeight.w800, color: KhoTheme.ink)),
          const SizedBox(height: 2),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: ts.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(ts.label, style: GoogleFonts.outfit(
                  fontSize: 10, fontWeight: FontWeight.w700, color: ts.color)),
            ),
            const SizedBox(width: 6),
            Text('Tồn: ${qty.toStringAsFixed(0)} ${item.unit}',
                style: GoogleFonts.outfit(fontSize: 12, color: KhoTheme.muted)),
          ]),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isOut ? 'Hết' : isLow ? 'Sắp hết' : 'Còn',
                style: GoogleFonts.outfit(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: statusColor)),
          ),
        ]),
      ]),
    );
  }
}
