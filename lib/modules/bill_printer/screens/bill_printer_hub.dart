import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/bill_template_provider.dart';
import '../providers/printer_settings_provider.dart';
import '../routing/print_setup.dart';
import '../widgets/bill_preview_widget.dart';
import 'bill_preview_screen.dart' show StationPrinterDispatcher;
import 'print_design_screen.dart';
import 'printer_settings_screen.dart';
import 'print_rules_screen.dart';

const _kIndigo = Color(0xFF1C2151);

class BillPrinterHub extends ConsumerWidget {
  const BillPrinterHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTpl = ref.watch(billTemplateProvider);
    final setup = ref.watch(printerSettingsProvider.select((s) => s.printSetup));
    final builtinBill = ref.watch(
        printerSettingsProvider.select(StationPrinterDispatcher.usesBuiltinBillFallback));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: Text('In Hoá Đơn',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: asyncTpl.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (tpl) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

            _PrintModeStatus(setup: setup, builtinBill: builtinBill),
            const SizedBox(height: 14),

            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: MediaQuery.of(context).size.width > 700 ? 3 : 2,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: MediaQuery.of(context).size.width > 700 ? 2.2 : 1.28,
              children: [
                _HubSquareCard(
                  icon: Icons.print_rounded,
                  color: const Color(0xFFD97706),
                  title: 'Cấu Hình Trạm In',
                  // Quán đã dùng luật: màn này chỉ còn công tắc tự động + máy chủ in.
                  subtitle: setup.isEmpty
                      ? 'Kết nối máy in Thu ngân, Bếp nóng, Bếp bar...'
                      : 'Tự động in, mở két và máy chủ in',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrinterSettingsScreen())),
                ),
                _HubSquareCard(
                  icon: Icons.alt_route_rounded,
                  color: const Color(0xFFE11D48),
                  title: 'Máy In & Luật In',
                  subtitle: 'Nâng cao: máy in, luật in theo loại phiếu',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrintRulesScreen())),
                ),
                _HubSquareCard(
                  icon: Icons.design_services_rounded,
                  color: _kIndigo,
                  title: 'Thiết Kế Mẫu In',
                  subtitle: 'Hoá đơn, phiếu bếp, bar, tem dán ly',
                  onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const PrintDesignScreen())),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ── Xem trước nhanh theo mẫu hiện tại ──────────────────────────
            Row(children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Text('Xem Trước Nhanh',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800, fontSize: 16, color: _kIndigo)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _kIndigo.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('hoá đơn thu ngân',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kIndigo)),
              ),
            ]),
            const SizedBox(height: 12),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  height: MediaQuery.of(context).size.width > 700 ? 600 : 460,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.35), width: 1.5),
                    boxShadow: [BoxShadow(
                        color: _kIndigo.withValues(alpha: 0.12), blurRadius: 16,
                        offset: const Offset(0, 6))],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: BillPreviewWidget(tpl: tpl),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Đặt lại ──────────────────────────────────────────────────
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text('Đặt lại mẫu hoá đơn',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
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
        title: Text('Đặt lại mẫu hoá đơn?',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800)),
        content: Text('Mẫu hoá đơn thu ngân sẽ về mặc định. Máy in, phiếu bếp và tem dán ly không đổi.',
            style: GoogleFonts.plusJakartaSans()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Huỷ', style: GoogleFonts.plusJakartaSans(color: _kIndigo))),
          TextButton(
            onPressed: () {
              ref.read(billTemplateProvider.notifier).reset();
              Navigator.pop(ctx);
            },
            child: Text('Đặt lại',
                style: GoogleFonts.plusJakartaSans(
                    color: Colors.red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Dòng trạng thái: quán đang in theo cách nào ─────────────────────────────
class _PrintModeStatus extends StatelessWidget {
  final PrintSetup setup;
  final bool builtinBill;
  const _PrintModeStatus({required this.setup, this.builtinBill = false});

  @override
  Widget build(BuildContext context) {
    // Cùng điều kiện lúc in (StationPrinterDispatcher.effectiveSettings): có máy in hoặc luật → chỉ theo luật.
    final usingRules = !setup.isEmpty;
    bool on(String? id) => setup.printerById(id ?? '')?.enabled ?? false;
    // Không luật bật nào ra được máy in đang bật (kể cả máy dự phòng) → không phiếu nào ra giấy.
    final nothingPrints = usingRules &&
        !setup.rules.any((r) =>
            r.enabled && (r.targets.any((t) => on(t.printerId)) || on(r.fallbackPrinterId)));
    final color = nothingPrints ? const Color(0xFFB91C1C) : _kIndigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: nothingPrints ? const Color(0xFFFEE2E2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(nothingPrints ? Icons.error_rounded : Icons.info_outline_rounded,
            color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              usingRules
                  ? 'Đang in theo: Máy In & Luật In – ${setup.printers.length} máy in, ${setup.rules.length} luật'
                  : 'Đang in theo: 4 trạm (Cấu Hình Trạm In)',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700, fontSize: 13, color: color),
            ),
            if (nothingPrints) ...[
              const SizedBox(height: 4),
              Text(
                'Chưa có luật nào in ra máy in đang bật, nên KHÔNG phiếu nào được in. '
                'Vào "Máy In & Luật In" để thêm luật hoặc bật máy in.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: color),
              ),
            ],
            if (builtinBill) ...[
              const SizedBox(height: 4),
              Text(
                'Quán chưa chọn máy in bill nên bill in ra máy in liền thân của máy Sunmi này.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: color),
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

// ─── Hub Square Card ─────────────────────────────────────────────────────────
class _HubSquareCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubSquareCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= 700;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(color, Colors.white, 0.18)!,
              color,
              Color.lerp(color, Colors.black, 0.28)!,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.30),
              blurRadius: 12,
              offset: const Offset(0, 5),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Hoạ tiết nền: chấm bi + vòng tròn mờ + biểu tượng lớn chìm
          Positioned.fill(child: CustomPaint(painter: _HubPatternPainter())),
          Positioned(
            right: -12,
            bottom: -14,
            child: Transform.rotate(
              angle: -0.2,
              child: Icon(icon,
                  size: isMobile ? 78 : 104,
                  color: Colors.white.withValues(alpha: 0.13)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: isMobile ? 34 : 42,
                  height: isMobile ? 34 : 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                  ),
                  child: Icon(icon, color: Colors.white, size: isMobile ? 18 : 20),
                ),
                Icon(Icons.arrow_forward_rounded, color: Colors.white70, size: isMobile ? 14 : 16),
              ],
            ),
            SizedBox(height: isMobile ? 6 : 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: isMobile ? 14 : 17,
                  ),
                ),
                SizedBox(height: isMobile ? 2 : 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: isMobile ? 11 : 13,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ],
        ),
          ),
        ]),
      ),
    );
  }
}

/// Hoạ tiết chấm bi và vòng tròn mờ cho thẻ menu.
class _HubPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (double x = 10; x < size.width; x += 16) {
      for (double y = 10; y < size.height * 0.55; y += 16) {
        canvas.drawCircle(Offset(x, y), 1.2, dot);
      }
    }
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.2), 34, ring);
    canvas.drawCircle(Offset(size.width * 0.86, size.height * 0.2), 52, ring);
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 1.02), 40,
        Paint()..color = Colors.white.withValues(alpha: 0.07));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
