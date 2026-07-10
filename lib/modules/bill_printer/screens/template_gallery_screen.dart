// lib/modules/bill_printer/screens/template_gallery_screen.dart
// Gallery chọn mẫu hoá đơn & phiếu bếp (10-20 mẫu dựng sẵn)
// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/bill_presets.dart';
import '../models/bill_block_template.dart';
import '../providers/bill_template_provider.dart';
import '../providers/kitchen_ticket_template_provider.dart';
import '../widgets/bill_preview_widget.dart';

const _kIndigo  = Color(0xFF1C2151);
const _kOrange  = Color(0xFFFF6B35);
const _kPurple  = Color(0xFF7C3AED);

class TemplateGalleryScreen extends ConsumerStatefulWidget {
  const TemplateGalleryScreen({super.key});
  @override
  ConsumerState<TemplateGalleryScreen> createState() => _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends ConsumerState<TemplateGalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  // Hoá đơn
  String? _selectedBillId;
  BillBlockTemplate? _previewBillTpl;
  // Bếp Nóng
  String? _selectedKitchenNongId;
  KitchenTicketTemplate? _previewKitchenNongTpl;
  // Bếp Bar
  String? _selectedKitchenBarId;
  KitchenTicketTemplate? _previewKitchenBarTpl;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    // Tự động chọn mẫu đầu tiên
    if (billPresets.isNotEmpty) {
      _selectedBillId = billPresets.first.id;
      _previewBillTpl = billPresets.first.template;
    }
    if (kitchenPresets.isNotEmpty) {
      _selectedKitchenNongId = kitchenPresets.first.id;
      _previewKitchenNongTpl = kitchenPresets.first.template;
      _selectedKitchenBarId = kitchenPresets.first.id;
      _previewKitchenBarTpl = kitchenPresets.first.template;
    }
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  // Áp dụng mẫu hoá đơn
  Future<void> _applyBill(BillPreset p) async {
    await ref.read(billTemplateProvider.notifier).applyPreset(p.template);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Đã áp dụng mẫu "${p.name}"',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: _kIndigo,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
      Navigator.pop(context);
    }
  }

  // Áp dụng mẫu phiếu bếp cho trạm chỉ định
  Future<void> _applyKitchen(KitchenPreset p, String stationKey) async {
    final provider = stationKey == 'bepBar'
        ? kitchenTicketTemplateBepBarProvider
        : kitchenTicketTemplateBepNongProvider;
    ref.read(provider.notifier).update(p.template);
    await ref.read(provider.notifier).save();
    
    if (mounted) {
      String stationName = stationKey == 'bepBar' ? 'Bếp Bar (Nước)' : 'Bếp Nóng';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Đã áp dụng mẫu "${p.name}" cho $stationName',
            style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
        backgroundColor: _kPurple,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ));
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _kIndigo,
        foregroundColor: Colors.white,
        title: Text('Chọn Mẫu In', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18)),
        bottom: TabBar(
          controller: _tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _kOrange,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Hoá Đơn'),
            Tab(icon: Icon(Icons.local_fire_department_rounded, size: 18), text: 'Bếp Nóng'),
            Tab(icon: Icon(Icons.local_bar_rounded, size: 18), text: 'Bếp Nước (Bar)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _BillGalleryTab(
            selectedId: _selectedBillId,
            previewTpl: _previewBillTpl,
            onSelect: (p) => setState(() {
              _selectedBillId = p.id;
              _previewBillTpl = p.template;
            }),
            onApply: _applyBill,
          ),
          _KitchenGalleryTab(
            selectedId: _selectedKitchenNongId,
            previewTpl: _previewKitchenNongTpl,
            onSelect: (p) => setState(() {
              _selectedKitchenNongId = p.id;
              _previewKitchenNongTpl = p.template;
            }),
            onApply: (p) => _applyKitchen(p, 'bepNong'),
          ),
          _KitchenGalleryTab(
            selectedId: _selectedKitchenBarId,
            previewTpl: _previewKitchenBarTpl,
            onSelect: (p) => setState(() {
              _selectedKitchenBarId = p.id;
              _previewKitchenBarTpl = p.template;
            }),
            onApply: (p) => _applyKitchen(p, 'bepBar'),
          ),
        ],
      ),
    );
  }
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
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
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
            style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade500)),
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
    case '58mm': return 'Máy in cầm tay, nhỏ gọn';
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
                style: GoogleFonts.outfit(
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
              style: GoogleFonts.outfit(
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
    child: Text(text, style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
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
            Text(title, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w800, color: accentColor)),
            Text(description, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade600)),
          ])),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
            label: Text('Dùng mẫu này',
                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
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
    ('Phở Bò Đặc Biệt', 2, 'Không hành, ít ớt'),
    ('Cơm Gà Xối Mỡ', 1, null),
    ('Bún Bò Huế', 3, 'Cay vừa'),
  ];

  @override
  Widget build(BuildContext context) {
    final wf = tpl.paperSize == '58mm' ? 0.72 : 0.9;
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
                  style: GoogleFonts.outfit(
                      fontSize: tpl.headerFontSize.toDouble(),
                      fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                if (tpl.showTableName)
                  Text('BÀN 5', style: GoogleFonts.outfit(
                      fontSize: tpl.tableFontSize.toDouble(), fontWeight: FontWeight.w900)),
                if (tpl.showOrderNumber)
                  Text('#018', style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey.shade500)),
              ]),
              if (tpl.showDateTime)
                Text('14/05/2026  13:45', style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey.shade500)),
              if (tpl.showDivider) const Divider(thickness: 1, height: 10),
              ..._sampleItems.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: tpl.qtyFontSize + 6.0, height: tpl.qtyFontSize + 6.0,
                    decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                    child: Center(child: Text('${item.$2}',
                        style: GoogleFonts.outfit(
                            fontSize: tpl.qtyFontSize.toDouble(),
                            fontWeight: FontWeight.w900, color: Colors.white))),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.$1, style: GoogleFonts.outfit(
                        fontSize: tpl.itemFontSize.toDouble(),
                        fontWeight: tpl.boldItemName ? FontWeight.w800 : FontWeight.w500)),
                    if (tpl.showNote && item.$3 != null)
                      Text('↳ ${item.$3!}', style: GoogleFonts.outfit(
                          fontSize: (tpl.itemFontSize - 2).toDouble(),
                          fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                  ])),
                ]),
              )),
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
