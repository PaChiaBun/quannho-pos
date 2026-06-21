import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/kho_providers.dart';
import '../repository/kho_repository.dart';
import 'supplier_form_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLIER LIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

const _kNavy    = Color(0xFF1C2151);
const _kNavyL   = Color(0xFF2D3580);
const _kViolet  = Color(0xFF7C3AED);
const _kBg      = Color(0xFFF8F6FF);
const _kCard    = Color(0xFFFFFFFF);
const _kBorder  = Color(0xFFE5E0F5);
const _kMuted   = Color(0xFF6B7280);
const _kInk     = Color(0xFF1A1530);
const _kRed     = Color(0xFFDC2626);

class SupplierListScreen extends ConsumerWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: CustomScrollView(
        slivers: [
          // ── Gradient Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: _kNavy,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: const [],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kNavy, _kNavyL],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Nhà Cung Cấp',
                            style: GoogleFonts.outfit(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        suppliersAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                          data: (list) => Text(
                            '${list.length} nhà cung cấp đang hoạt động',
                            style: GoogleFonts.outfit(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Content ──────────────────────────────────────────────────────
          suppliersAsync.when(
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: _kViolet),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Lỗi: $e')),
            ),
            data: (suppliers) => suppliers.isEmpty
                ? SliverFillRemaining(child: _buildEmpty(context, ref))
                : SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _SupplierCard(
                            supplier: suppliers[i],
                            onEdit: () => _openForm(context, suppliers[i], ref),
                            onDelete: () =>
                                _confirmDelete(context, ref, suppliers[i]),
                          ),
                        ),
                        childCount: suppliers.length,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'supplier_fab',
        onPressed: () => _openForm(context, null, ref),
        backgroundColor: _kViolet,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: Text('Thêm NCC',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  // ── Empty State ──────────────────────────────────────────────────────────
  Widget _buildEmpty(BuildContext context, WidgetRef ref) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_kViolet.withValues(alpha: 0.12), _kViolet.withValues(alpha: 0.06)],
              ),
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.store_rounded, size: 42, color: _kViolet),
          ),
          const SizedBox(height: 20),
          Text('Chưa có nhà cung cấp',
              style: GoogleFonts.outfit(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _kInk)),
          const SizedBox(height: 8),
          Text(
            'Thêm nhà cung cấp để theo dõi\nlịch sử nhập hàng chính xác hơn',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
                fontSize: 14, color: _kMuted, height: 1.5),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => _openForm(context, null, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Thêm nhà cung cấp đầu tiên',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kViolet,
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    ),
  );

  void _openForm(BuildContext context, SupplierModel? supplier, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupplierFormScreen(supplier: supplier),
        fullscreenDialog: supplier == null,
      ),
    ).then((_) => ref.invalidate(suppliersProvider));
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, SupplierModel s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Text('Xoá nhà cung cấp?',
            style: GoogleFonts.outfit(
                fontSize: 17, fontWeight: FontWeight.w800, color: _kInk)),
        content: Text(
          'Bạn sẽ xoá "${s.name}".\nLịch sử phiếu nhập vẫn được giữ lại.',
          style: GoogleFonts.outfit(
              fontSize: 14, color: _kMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Huỷ', style: GoogleFonts.outfit(color: _kMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Xoá',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(khoRepositoryProvider).deleteSupplier(s.id);
      ref.invalidate(suppliersProvider);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUPPLIER CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SupplierCard extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SupplierCard({
    required this.supplier,
    required this.onEdit,
    required this.onDelete,
  });

  // Màu avatar theo tên
  static const _avatarColors = [
    Color(0xFF7C3AED), Color(0xFF2563EB), Color(0xFF059669),
    Color(0xFFD97706), Color(0xFFDC2626), Color(0xFF7C3AED),
  ];

  Color get _avatarColor {
    final code = supplier.name.codeUnits.fold(0, (a, b) => a + b);
    return _avatarColors[code % _avatarColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final s = supplier;
    final color = _avatarColor;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
            child: Row(
              children: [
                // Avatar gradient
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : 'N',
                      style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: GoogleFonts.outfit(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _kInk)),
                      if (s.category != null && s.category!.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 4, runSpacing: 4,
                          children: s.category!.split(',').map((tag) {
                            final t = tag.trim();
                            if (t.isEmpty) return const SizedBox.shrink();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(t,
                                  style: GoogleFonts.outfit(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: color)),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Menu
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: _kMuted, size: 20),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded, size: 16, color: _kViolet),
                        const SizedBox(width: 10),
                        Text('Sửa thông tin',
                            style: GoogleFonts.outfit(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        const Icon(Icons.delete_outline_rounded,
                            size: 16, color: _kRed),
                        const SizedBox(width: 10),
                        Text('Xoá',
                            style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _kRed)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Info chips ─────────────────────────────────────────────────
          if (s.phone != null || s.contactPerson != null ||
              s.paymentTerms != null) ...[
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  if (s.phone != null)
                    _infoRow(Icons.phone_rounded, s.phone!, color),
                  if (s.contactPerson != null)
                    _infoRow(Icons.person_rounded,
                        'Liên hệ: ${s.contactPerson!}', color),
                  if (s.paymentTerms != null)
                    _infoRow(Icons.receipt_long_rounded, s.paymentTerms!, color),
                  if (s.bankAccount != null)
                    _infoRow(Icons.account_balance_rounded, s.bankAccount!, color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color accent) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Icon(icon, size: 13, color: accent.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
                fontSize: 12.5,
                color: const Color(0xFF374151),
                fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
