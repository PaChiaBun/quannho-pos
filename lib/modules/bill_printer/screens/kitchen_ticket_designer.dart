// lib/modules/bill_printer/screens/kitchen_ticket_designer.dart
// ignore_for_file: use_build_context_synchronously
import '../utils/paper_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/kitchen_ticket_template_provider.dart';
import '../widgets/designer_controls.dart';
import '../widgets/designer_shell.dart';
import 'template_gallery_screen.dart';

const _kIndigo  = Color(0xFF1C2151);
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);
const _kGreen   = Color(0xFF16A34A);
const _kRed     = Color(0xFFDC2626);
const _kAmber   = Color(0xFFF59E0B);

/// Thiết kế phiếu bếp cho một trạm ('bepNong' | 'bepBar').
/// Chỉ là phần thân — được nhúng trong màn "Thiết Kế Mẫu In".
class KitchenTicketDesigner extends ConsumerStatefulWidget {
  final String stationKey;
  const KitchenTicketDesigner({super.key, required this.stationKey});
  @override
  ConsumerState<KitchenTicketDesigner> createState() => _KitchenTicketDesignerState();
}

class _KitchenTicketDesignerState extends ConsumerState<KitchenTicketDesigner> {
  final _shellKey = GlobalKey<DesignerShellState>();
  bool _saving = false;
  bool _tipsExpanded = true;

  NotifierProvider<KitchenTicketTemplateNotifier, KitchenTicketTemplate> get _provider =>
      widget.stationKey == 'bepBar'
          ? kitchenTicketTemplateBepBarProvider
          : kitchenTicketTemplateBepNongProvider;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(_provider.notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Đã lưu thiết kế phiếu bếp',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      backgroundColor: _kIndigo,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tpl = ref.watch(_provider);

    return DesignerShell(
      key: _shellKey,
      accent: _kPurple,
      config: _ConfigPanel(
          tpl: tpl,
          tipsExpanded: _tipsExpanded,
          onToggleTips: () => setState(() => _tipsExpanded = !_tipsExpanded),
          provider: _provider),
      presets: KitchenPresetPicker(
        stationKey: widget.stationKey,
        onApplied: () => _shellKey.currentState?.showConfig(),
      ),
      preview: _PreviewPanel(tpl: tpl),
      actions: [
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: _kPurple, strokeWidth: 2)),
          )
        else
          TextButton.icon(
            icon: const Icon(Icons.save_rounded, color: _kPurple, size: 18),
            label: Text('Lưu',
                style: GoogleFonts.outfit(
                    color: _kPurple, fontWeight: FontWeight.w700)),
            onPressed: _save,
          ),
      ],
    );
  }
}

class _ConfigPanel extends ConsumerWidget {
  final KitchenTicketTemplate tpl;
  final bool tipsExpanded;
  final VoidCallback onToggleTips;
  final NotifierProvider<KitchenTicketTemplateNotifier, KitchenTicketTemplate> provider;
  const _ConfigPanel({required this.tpl, required this.tipsExpanded, required this.onToggleTips, required this.provider});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(KitchenTicketTemplate t) =>
        ref.read(provider.notifier).update(t);

    return ListView(padding: const EdgeInsets.all(16), children: [

      // ── Tips Panel (nên / không nên) ─────────────────────────────────────
      _TipsPanel(expanded: tipsExpanded, onToggle: onToggleTips),
      const SizedBox(height: 16),

      // ── Khổ giấy ─────────────────────────────────────────────────────
      DesignerSection(
        icon: Icons.straighten_rounded,
        title: 'Khổ Giấy',
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final spec in kKitchenPaperSpecs)
              DesignerChip(
                label: spec.label,
                selected: tpl.paperSize == spec.key,
                onTap: () => update(tpl.copyWith(paperSize: spec.key)),
              ),
          ]),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: _kIndigo.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _kIndigo.withValues(alpha: 0.5)),
              const SizedBox(width: 6),
              Expanded(child: Text(
                paperSpecOf(tpl.paperSize).description,
                style: GoogleFonts.outfit(fontSize: 11, color: _kIndigo.withValues(alpha: 0.65), height: 1.5),
              )),
            ]),
          ),
        ],
      ),

      // ── Tiêu đề phiếu ─────────────────────────────────────────────
      DesignerSection(
        icon: Icons.label_rounded,
        title: 'Tiêu Đề Phiếu',
        children: [
          TextFormField(
            initialValue: tpl.headerText,
            style: GoogleFonts.outfit(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'VD: PHIẾU BẾP / BẾP NÓNG / BAR NƯỚC',
              hintStyle: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade400),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kIndigo)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onChanged: (v) => update(tpl.copyWith(headerText: v.isEmpty ? 'PHIẾU BẾP' : v)),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(Icons.tips_and_updates_rounded, size: 14, color: Colors.amber.shade600),
            const SizedBox(width: 4),
            Expanded(child: Text(
              'Gợi ý: Phân chia theo trạm → "BếP NÓNG" / "BAR NƯỚC" / "GRILL"',
              style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic))),
          ]),
        ],
      ),

      // ── Hiển thị ─────────────────────────────────────────────────
      DesignerSection(
        icon: Icons.visibility_rounded,
        title: 'Hiển Thị Trên Phiếu',
        children: [
          DesignerToggleRow('Tên bàn / Mang đi', tpl.showTableName, Icons.table_restaurant_rounded,
              isRecommended: true,
              (v) => update(tpl.copyWith(showTableName: v))),
          DesignerToggleRow('Số thứ tự đơn', tpl.showOrderNumber, Icons.tag_rounded,
              (v) => update(tpl.copyWith(showOrderNumber: v))),
          DesignerToggleRow('Thời gian gọi món', tpl.showDateTime, Icons.access_time_rounded,
              (v) => update(tpl.copyWith(showDateTime: v))),
          DesignerToggleRow('Ghi chú đặc biệt', tpl.showNote, Icons.sticky_note_2_rounded,
              isRecommended: true,
              (v) => update(tpl.copyWith(showNote: v))),
          DesignerToggleRow('Đường kẻ phân cách', tpl.showDivider, Icons.horizontal_rule_rounded,
              (v) => update(tpl.copyWith(showDivider: v))),
          DesignerToggleRow('In đậm tên món', tpl.boldItemName, Icons.format_bold_rounded,
              isRecommended: true,
              (v) => update(tpl.copyWith(boldItemName: v))),
          DesignerToggleRow('Tên nhân viên order', tpl.showWaiterName, Icons.person_outline_rounded,
              isRecommended: true,
              (v) => update(tpl.copyWith(showWaiterName: v))),
        ],
      ),

      // ── Cỡ chữ ─────────────────────────────────────────────────────────────
      DesignerSection(
        icon: Icons.text_fields_rounded,
        title: 'Cỡ Chữ',
        children: [
          DesignerSliderRow(
            label: 'Tiêu đề phiếu',
            hint: 'Chữ to nổi bật — nên từ 16px trở lên',
            value: tpl.headerFontSize.toDouble(),
            min: 14, max: 24,
            color: const Color(0xFF7C3AED),
            onChanged: (v) => update(tpl.copyWith(headerFontSize: v.round())),
          ),
          const SizedBox(height: 12),
          DesignerSliderRow(
            label: 'Tên bàn',
            hint: 'Phải đọc được từ xa — nên từ 14px trở lên',
            value: tpl.tableFontSize.toDouble(),
            min: 12, max: 22,
            color: _kGreen,
            onChanged: (v) => update(tpl.copyWith(tableFontSize: v.round())),
          ),
          const SizedBox(height: 12),
          DesignerSliderRow(
            label: 'Tên món',
            hint: 'Bếp cần đọc nhanh — nên từ 12px trở lên',
            value: tpl.itemFontSize.toDouble(),
            min: 10, max: 20,
            color: _kOrange,
            onChanged: (v) => update(tpl.copyWith(itemFontSize: v.round())),
          ),
          const SizedBox(height: 12),
          DesignerSliderRow(
            label: 'Số lượng (⬤ vòng tròn)',
            hint: 'Càng to càng tốt — bếp nhìn thoáng là biết ngay',
            value: tpl.qtyFontSize.toDouble(),
            min: 14, max: 30,
            color: _kRed,
            onChanged: (v) => update(tpl.copyWith(qtyFontSize: v.round())),
          ),
        ],
      ),

      // ── Đặt lại ───────────────────────────────────────────────────────────
      OutlinedButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text('Đặt lại mặc định phiếu bếp',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade400,
          side: BorderSide(color: Colors.red.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => ref.read(provider.notifier).reset(),
      ),
      const SizedBox(height: 20),
    ]);
  }
}

// ─── Tips Panel ───────────────────────────────────────────────────────────────
class _TipsPanel extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  const _TipsPanel({required this.expanded, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAmber.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header có thể thu/mở
        GestureDetector(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
            Icon(Icons.tips_and_updates_rounded, size: 18, color: _kAmber),
            const SizedBox(width: 8),
              Expanded(child: Text('Hướng dẫn thiết kế phiếu bếp',
                  style: GoogleFonts.outfit(
                      fontSize: 13, fontWeight: FontWeight.w800, color: _kAmber))),
              Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: _kAmber),
            ]),
          ),
        ),
        if (expanded) ...[
          Divider(height: 1, color: _kAmber.withValues(alpha: 0.3)),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              // NÊN
              _TipRow(icon: Icons.check_circle_rounded, color: _kGreen,
                  text: 'Font chữ to (14px+) — bếp đọc từ xa, tay dính dầu mỡ'),
              _TipRow(icon: Icons.check_circle_rounded, color: _kGreen,
                  text: 'Số lượng nổi bật (vòng tròn to) — nhìn thoáng biết ngay'),
              _TipRow(icon: Icons.check_circle_rounded, color: _kGreen,
                  text: 'Bật tên bàn — biết mang ra bàn nào'),
              _TipRow(icon: Icons.check_circle_rounded, color: _kGreen,
                  text: 'Bật ghi chú — ít cay, không hành, dị ứng... rất quan trọng'),
              _TipRow(icon: Icons.check_circle_rounded, color: _kGreen,
                  text: 'Tiêu đề riêng theo trạm: "BẾP NÓNG" / "BAR NƯỚC"'),

              const SizedBox(height: 10),
              Divider(color: Colors.grey.shade200),
              const SizedBox(height: 6),

              // KHÔNG NÊN
              _TipRow(icon: Icons.cancel_rounded, color: _kRed,
                  text: 'Không in giá tiền — bếp không cần, gây rối'),
              _TipRow(icon: Icons.cancel_rounded, color: _kRed,
                  text: 'Không thêm QR, điểm thưởng, quảng cáo — lãng phí giấy'),
              _TipRow(icon: Icons.cancel_rounded, color: _kRed,
                  text: 'Không dùng font dưới 12px — bếp nóng, khói, đọc không rõ'),
              _TipRow(icon: Icons.cancel_rounded, color: _kRed,
                  text: 'Không in logo — chất lượng xấu, tốn giấy'),
            ]),
          ),
        ],
      ]),
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _TipRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: color),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: GoogleFonts.outfit(fontSize: 12, color: const Color(0xFF374151), height: 1.4))),
    ]),
  );
}

// ─── Preview Panel ────────────────────────────────────────────────────────────
class _PreviewPanel extends StatelessWidget {
  final KitchenTicketTemplate tpl;
  const _PreviewPanel({required this.tpl});

  // Dữ liệu mẫu để xem trước
  static const _sampleItems = [
    ('Phở Bò Đặc Biệt', 2, '+ Khúc Bạch, Dừa sợi\nGhi chú: Không hành, ít ớt'),
    ('Cơm Gà Xối Mỡ', 1, null),
    ('Bánh Mì Thịt', 3, 'Ghi chú: Không rau mùi'),
  ];

  @override
  Widget build(BuildContext context) {
    final widthFactor = paperSpecOf(tpl.paperSize).kitchenPreview;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: widthFactor,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16, offset: const Offset(0, 4))],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // ── Tiêu đề ──
              Text(tpl.headerText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                      fontSize: tpl.headerFontSize.toDouble(),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2)),
              const SizedBox(height: 4),

              // ── Bàn + số đơn ──
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (tpl.showTableName)
                  Text('BÀN 5',
                      style: GoogleFonts.outfit(
                          fontSize: tpl.tableFontSize.toDouble(),
                          fontWeight: FontWeight.w900)),
                if (tpl.showOrderNumber)
                  Text('#QN-018',
                      style: GoogleFonts.outfit(
                          fontSize: 11, color: Colors.grey.shade500)),
              ]),
              if (tpl.showDateTime)
                Text('14/05/2026  13:45',
                    style: GoogleFonts.outfit(
                        fontSize: 10, color: Colors.grey.shade500)),

              if (tpl.showDivider) ...[
                const SizedBox(height: 6),
                const Divider(thickness: 1, height: 8),
              ],
              const SizedBox(height: 4),

              // ── Danh sách món ──
              ..._sampleItems.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final hasNote = tpl.showNote && item.$3 != null;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.black, width: 3.5),
                        ),
                      ),
                      padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vòng tròn số lượng
                          Container(
                            width: tpl.qtyFontSize + 8,
                            height: tpl.qtyFontSize + 8,
                            decoration: const BoxDecoration(
                                color: Colors.black, shape: BoxShape.circle),
                            child: Center(
                               child: Text('${item.$2}',
                                  style: GoogleFonts.outfit(
                                      fontSize: tpl.qtyFontSize.toDouble(),
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.$1,
                                    style: GoogleFonts.outfit(
                                        fontSize: tpl.itemFontSize.toDouble(),
                                        fontWeight: tpl.boldItemName
                                            ? FontWeight.w800 : FontWeight.w500)),
                                if (hasNote)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4, top: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: item.$3!.split('\n').map((line) {
                                        var displayLine = line;
                                        if (displayLine.startsWith('+ Thêm món: ')) {
                                          displayLine = '+ ${displayLine.substring('+ Thêm món: '.length)}';
                                        }
                                        return Text(
                                          '↳ $displayLine',
                                          style: GoogleFonts.outfit(
                                              fontSize: (tpl.itemFontSize - 2).toDouble(),
                                              fontStyle: FontStyle.italic,
                                              color: Colors.blueGrey),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (idx < _sampleItems.length - 1)
                      const Divider(thickness: 0.8, height: 12, color: Colors.black26),
                  ],
                );
              }),

              if (tpl.showDivider)
                Divider(thickness: 0.5, color: Colors.grey.shade300),

              // ── Label cắt giấy ──
              const SizedBox(height: 4),
              Row(children: List.generate(30, (i) => Expanded(
                child: Container(height: 1,
                    color: i % 2 == 0 ? Colors.black26 : Colors.transparent)))),
            ]),
          ),
        ),
      ),
    );
  }
}
