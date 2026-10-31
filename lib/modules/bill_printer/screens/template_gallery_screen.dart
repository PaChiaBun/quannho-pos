// lib/modules/bill_printer/screens/template_gallery_screen.dart
// Bộ chọn mẫu hoá đơn & phiếu bếp dựng sẵn — nhúng trong các màn Thiết Kế (không còn màn riêng)
// ignore_for_file: use_build_context_synchronously
import '../utils/paper_sizes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/bill_presets.dart';
import '../models/bill_block_template.dart';
import '../providers/bill_template_provider.dart';
import '../providers/kitchen_ticket_template_provider.dart';
import '../widgets/bill_preview_widget.dart';

const _kIndigo  = Color(0xFF1C2151);
const _kPurple  = Color(0xFF7C3AED);

/// Bộ chọn mẫu hoá đơn dựng sẵn — nhúng trong màn Thiết Kế Hoá Đơn.
class BillPresetPicker extends ConsumerStatefulWidget {
  /// Gọi sau khi đã áp dụng mẫu (để màn cha chuyển về tab xem trước/cấu hình).
  final VoidCallback? onApplied;
  const BillPresetPicker({super.key, this.onApplied});
  @override
  ConsumerState<BillPresetPicker> createState() => _BillPresetPickerState();
}

class _BillPresetPickerState extends ConsumerState<BillPresetPicker> {
  String? _selectedId = billPresets.isNotEmpty ? billPresets.first.id : null;
  BillBlockTemplate? _previewTpl =
      billPresets.isNotEmpty ? billPresets.first.template : null;

  Future<void> _apply(BillPreset p) async {
    await ref.read(billTemplateProvider.notifier).applyPreset(p.template);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Đã áp dụng mẫu "${p.name}"',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      backgroundColor: _kIndigo,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
    widget.onApplied?.call();
  }

  @override
  Widget build(BuildContext context) => _BillGalleryTab(
        selectedId: _selectedId,
        previewTpl: _previewTpl,
        onSelect: (p) => setState(() {
          _selectedId = p.id;
          _previewTpl = p.template;
        }),
        onApply: _apply,
      );
}

/// Bộ chọn mẫu phiếu bếp dựng sẵn cho một trạm ('bepNong' | 'bepBar').
class KitchenPresetPicker extends ConsumerStatefulWidget {
  final String stationKey;
  final VoidCallback? onApplied;
  const KitchenPresetPicker({super.key, required this.stationKey, this.onApplied});
  @override
  ConsumerState<KitchenPresetPicker> createState() => _KitchenPresetPickerState();
}

class _KitchenPresetPickerState extends ConsumerState<KitchenPresetPicker> {
  String? _selectedId = kitchenPresets.isNotEmpty ? kitchenPresets.first.id : null;
  KitchenTicketTemplate? _previewTpl =
      kitchenPresets.isNotEmpty ? kitchenPresets.first.template : null;

  Future<void> _apply(KitchenPreset p) async {
    final isBar = widget.stationKey == 'bepBar';
    final provider = isBar
        ? kitchenTicketTemplateBepBarProvider
        : kitchenTicketTemplateBepNongProvider;
    ref.read(provider.notifier).update(p.template);
    await ref.read(provider.notifier).save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '✅ Đã áp dụng mẫu "${p.name}" cho ${isBar ? 'Bếp Bar (Nước)' : 'Bếp Nóng'}',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      backgroundColor: _kPurple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ));
    widget.onApplied?.call();
  }

  @override
  Widget build(BuildContext context) => _KitchenGalleryTab(
        selectedId: _selectedId,
        previewTpl: _previewTpl,
        onSelect: (p) => setState(() {
          _selectedId = p.id;
          _previewTpl = p.template;
        }),
        onApply: _apply,
      );
}

// ─── Bill Gallery Tab ─────────────────────────────────────────────────────────
class _BillGalleryTab extends StatelessWidget {
  final String? selectedId;
  final BillBlockTemplate? previewTpl;
  final void Function(BillPreset) onSelect;
  final void Function(BillPreset) onApply;
  const _BillGalleryTab({
    required this.selectedId, required this.previewTpl,
    required this.onSelect, required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final presets = billPresets;
    final selected = selectedId != null ? presets.firstWhere((p) => p.id == selectedId, orElse: () => presets.first) : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Grid mẫu
        Text('${presets.length} mẫu hoá đơn có sẵn',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: MediaQuery.of(context).size.width > 700 ? 2.5 : 2.0,
          ),
          itemCount: presets.length,
          itemBuilder: (_, i) => _PresetCard(
            name: presets[i].name,
            tag: presets[i].tag,
            paperSize: presets[i].template.paperSize,
            isSelected: presets[i].id == selectedId,
            accentColor: _kIndigo,
            onTap: () => onSelect(presets[i]),
          ),
        ),

        // Preview khi chọn
        if (previewTpl != null && selected != null) ...[
          const SizedBox(height: 20),
          _PreviewSection(
            title: selected.name,
            description: selected.description,
            accentColor: _kIndigo,
            previewWidget: BillPreviewWidget(tpl: previewTpl!),
            onApply: () => onApply(selected),
          ),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ─── Kitchen Gallery Tab ──────────────────────────────────────────────────────
class _KitchenGalleryTab extends StatelessWidget {
  final String? selectedId;
  final KitchenTicketTemplate? previewTpl;
  final void Function(KitchenPreset) onSelect;
  final void Function(KitchenPreset) onApply;
  const _KitchenGalleryTab({
    required this.selectedId, required this.previewTpl,
    required this.onSelect, required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    const presets = kitchenPresets;
    final selected = selectedId != null
        ? presets.firstWhere((p) => p.id == selectedId, orElse: () => presets.first)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${presets.length} mẫu phiếu bếp có sẵn',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: MediaQuery.of(context).size.width > 700 ? 2.5 : 2.0,
          ),
          itemCount: presets.length,
          itemBuilder: (_, i) => _PresetCard(
            name: presets[i].name,
            tag: presets[i].tag,
            paperSize: presets[i].template.paperSize,
            isSelected: presets[i].id == selectedId,
            accentColor: _kPurple,
            onTap: () => onSelect(presets[i]),
          ),
        ),

        // Preview phiếu bếp khi chọn
        if (previewTpl != null && selected != null) ...[
          const SizedBox(height: 20),
          _PreviewSection(
            title: selected.name,
            description: selected.description,
            accentColor: _kPurple,
            previewWidget: _KitchenPreviewWidget(tpl: previewTpl!),
            onApply: () => onApply(selected),
          ),
        ],
        const SizedBox(height: 20),
      ]),
    );
  }
}

// ─── Paper size hint ─────────────────────────────────────────────────────────
String _paperHint(String paperSize) {
  switch (paperSize.toLowerCase()) {
    case '50mm': return 'Máy POS cầm tay, giấy rất nhỏ';
    case '58mm': return 'Máy in cầm tay, nhỏ gọn';
    case 'a5':   return 'Máy in văn phòng, khổ vừa';
    case 'a4':   return 'Máy in văn phòng, khổ lớn';
    default:     return 'Máy in quầy, phổ biến nhất';
  }
}

// ─── Preset Card ──────────────────────────────────────────────────────────────
class _PresetCard extends StatelessWidget {
  final String name, tag, paperSize;
  final bool isSelected;
  final Color accentColor;
  final VoidCallback onTap;

  const _PresetCard({
    required this.name, required this.tag, required this.paperSize,
    required this.isSelected, required this.accentColor, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? accentColor : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? accentColor : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: isSelected
            ? [BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Expanded(child: Text(name,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : _kIndigo))),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            _Badge(tag, isSelected ? Colors.white.withValues(alpha: 0.25) : accentColor.withValues(alpha: 0.1),
                isSelected ? Colors.white : accentColor),
            const SizedBox(width: 4),
            _Badge(paperSize.toUpperCase(),
                isSelected ? Colors.white.withValues(alpha: 0.15) : Colors.grey.shade100,
                isSelected ? Colors.white70 : Colors.grey.shade600),
          ]),
          const SizedBox(height: 4),
          Text(_paperHint(paperSize),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.75)
                      : Colors.grey.shade600)),
        ],
      ),
    ),
  );
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Badge(this.text, this.bg, this.fg);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
    child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
  );
}

// ─── Preview Section (dùng chung Hoá Đơn & Bếp) ─────────────────────────────
class _PreviewSection extends StatelessWidget {
  final String title, description;
  final Color accentColor;
  final Widget previewWidget;
  final VoidCallback onApply;
  const _PreviewSection({
    required this.title, required this.description, required this.accentColor,
    required this.previewWidget, required this.onApply,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      // Header mô tả
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.06),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: accentColor)),
            Text(description, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.grey.shade600)),
          ])),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
            label: Text('Dùng mẫu này',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              elevation: 0,
            ),
            onPressed: onApply,
          ),
        ]),
      ),
      // Preview widget
      Container(
        height: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
          border: Border(
            left: BorderSide(color: accentColor.withValues(alpha: 0.2)),
            right: BorderSide(color: accentColor.withValues(alpha: 0.2)),
            bottom: BorderSide(color: accentColor.withValues(alpha: 0.2)),
          ),
          boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.08), blurRadius: 12)],
        ),
        clipBehavior: Clip.hardEdge,
        child: previewWidget,
      ),
    ],
  );
}

// ─── Kitchen Ticket Preview Widget (Flutter, không PDF) ──────────────────────
class _KitchenPreviewWidget extends StatelessWidget {
  final KitchenTicketTemplate tpl;
  const _KitchenPreviewWidget({required this.tpl});

  static const _sampleItems = [
    ('Phở Bò Đặc Biệt', 2, '+ Khúc Bạch, Dừa sợi\nGhi chú: Không hành, ít ớt'),
    ('Cơm Gà Xối Mỡ', 1, null),
    ('Bún Bò Huế', 3, 'Ghi chú: Cay vừa'),
  ];

  @override
  Widget build(BuildContext context) {
    final wf = paperWidthMm(tpl.paperSize) <= 48 ? 0.72 : 0.9;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: wf,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12)],
            ),
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tpl.headerText, textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                      fontSize: tpl.headerFontSize.toDouble(),
                      fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (tpl.showTableName)
                  Text('BÀN 5', style: GoogleFonts.plusJakartaSans(
                      fontSize: tpl.tableFontSize.toDouble(), fontWeight: FontWeight.w900)),
                if (tpl.showOrderNumber)
                  Text('#018', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: Colors.grey.shade500)),
              ]),
              if (tpl.showDateTime)
                Text('14/05/2026  13:45', style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.grey.shade500)),
              if (tpl.showDivider) const Divider(thickness: 1, height: 10),
              ..._sampleItems.map((item) {
                final hasNote = tpl.showNote && item.$3 != null;
                return Container(
                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Colors.black, width: 3.5),
                    ),
                  ),
                  padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: tpl.qtyFontSize + 6.0, height: tpl.qtyFontSize + 6.0,
                      decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                      child: Center(child: Text('${item.$2}',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: tpl.qtyFontSize.toDouble(),
                              fontWeight: FontWeight.w900, color: Colors.white))),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(item.$1, style: GoogleFonts.plusJakartaSans(
                          fontSize: tpl.itemFontSize.toDouble(),
                          fontWeight: tpl.boldItemName ? FontWeight.w800 : FontWeight.w500)),
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
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: (tpl.itemFontSize - 2).toDouble(),
                                    fontStyle: FontStyle.italic,
                                    color: Colors.blueGrey),
                              );
                            }).toList(),
                          ),
                        ),
                    ])),
                  ]),
                );
              }),
              if (tpl.showDivider) const Divider(thickness: 0.5),
              Row(children: List.generate(28, (i) => Expanded(
                child: Container(height: 1, color: i % 2 == 0 ? Colors.black26 : Colors.transparent)))),
            ]),
          ),
        ),
      ),
    );
  }
}
