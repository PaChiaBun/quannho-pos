import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/bill_template_provider.dart';
import '../widgets/bill_preview_widget.dart';
import 'bill_designer_v2.dart';
import 'kitchen_ticket_designer.dart';
import 'template_gallery_screen.dart';

const _kIndigo = Color(0xFF1C2151);


// ─────────────────────────────────────────────────────────────────────────────


// ─────────────────────────────────────────────────────────────────────────────

class BillPrinterHub extends ConsumerWidget {
  const BillPrinterHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTpl = ref.watch(billTemplateProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: Text('In Hoá Đơn',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: asyncTpl.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (tpl) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            // ── Thiết kế hoá đơn khách ────────────────────────────────────────
            _HubCard(
              icon: Icons.tune_rounded,
              color: _kIndigo,
              title: 'Thiết Kế Hoá Đơn',
              subtitle: '${tpl.blocks.where((b) => b.enabled).length} blocks đang hiện  •  ${tpl.paperSize.toUpperCase()}',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BillDesignerV2())),
            ),

            const SizedBox(height: 12),

            // ── Thiết kế phiếu bếp ───────────────────────────────────────────
            _HubCard(
              icon: Icons.local_fire_department_rounded,
              color: const Color(0xFF7C3AED), // tím — phân biệt với hoá đơn khách
              title: 'Thiết Kế Phiếu Bếp',
              subtitle: 'Font to, số lượng nổi bật, ghi chú đặc biệt',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const KitchenTicketDesigner())),
            ),

            const SizedBox(height: 16),

            // ── Chọn mẫu dựng sẵn ──────────────────────────────────────────
            _HubCard(
              icon: Icons.collections_bookmark_rounded,
              color: const Color(0xFF0F766E), // xanh ngọc — phân biệt với 2 card trên
              title: 'Chọn Mẫu Hoá Đơn & Phiếu Bếp',
              subtitle: '10 mẫu hoá đơn + 8 mẫu phiếu bếp dựng sẵn — chọn & áp dụng ngay',
              onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TemplateGalleryScreen())),
            ),


            // ── Xem trước nhanh theo mẫu hiện tại ──────────────────────────
            Text('Xem Trước Nhanh',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, fontSize: 15, color: _kIndigo)),
            const SizedBox(height: 12),
            Container(
              height: 380,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06), blurRadius: 12)],
              ),
              clipBehavior: Clip.hardEdge,
              child: BillPreviewWidget(tpl: tpl),
            ),

            const SizedBox(height: 16),

            // ── Đặt lại ──────────────────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Đặt lại về mặc định',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _confirmReset(context, ref),
            ),

            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Đặt lại thiết kế?',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
        content: Text('Toàn bộ cài đặt hoá đơn sẽ trở về mặc định.',
            style: GoogleFonts.outfit()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Huỷ', style: GoogleFonts.outfit(color: _kIndigo))),
          TextButton(
            onPressed: () {
              ref.read(billTemplateProvider.notifier).reset();
              Navigator.pop(ctx);
            },
            child: Text('Đặt lại',
                style: GoogleFonts.outfit(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Hub Card (chỉ còn 1 card Thiết Kế) ─────────────────────────────────────
class _HubCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.outfit(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 2),
              Text(subtitle, style: GoogleFonts.outfit(
                  color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ])),
        const Icon(Icons.arrow_forward_ios_rounded,
            color: Colors.white54, size: 16),
      ]),
    ),
  );
}
