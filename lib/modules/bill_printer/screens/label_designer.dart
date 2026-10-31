// lib/modules/bill_printer/screens/label_designer.dart
// Thiết kế tem dán ly (in lẻ từng ly cho trạm Bar). Phần thân — nhúng trong "Thiết Kế Mẫu In".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/bar_label_template_provider.dart';
import '../widgets/designer_controls.dart';
import '../widgets/designer_shell.dart';

const _kIndigo = Color(0xFF1C2151);
const _kTeal = Color(0xFF0F766E);
const _kOrange = Color(0xFFFF6B35);
const _kGreen = Color(0xFF16A34A);

class LabelDesigner extends ConsumerStatefulWidget {
  const LabelDesigner({super.key});
  @override
  ConsumerState<LabelDesigner> createState() => _LabelDesignerState();
}

class _LabelDesignerState extends ConsumerState<LabelDesigner> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(barLabelTemplateProvider.notifier).save();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('✅ Đã lưu thiết kế tem dán ly',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
      backgroundColor: _kIndigo,
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tpl = ref.watch(barLabelTemplateProvider);
    return DesignerShell(
      accent: _kTeal,
      config: _LabelConfigPanel(tpl: tpl),
      preview: _LabelPreview(tpl: tpl),
      actions: [
        if (_saving)
          const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(color: _kTeal, strokeWidth: 2)),
          )
        else
          TextButton.icon(
            icon: const Icon(Icons.save_rounded, color: _kTeal, size: 18),
            label: Text('Lưu',
                style: GoogleFonts.plusJakartaSans(color: _kTeal, fontWeight: FontWeight.w700)),
            onPressed: _save,
          ),
      ],
    );
  }
}

class _LabelConfigPanel extends ConsumerWidget {
  final BarLabelTemplate tpl;
  const _LabelConfigPanel({required this.tpl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void update(BarLabelTemplate t) =>
        ref.read(barLabelTemplateProvider.notifier).update(t);

    return ListView(padding: const EdgeInsets.all(16), children: [
      DesignerSection(
        icon: Icons.straighten_rounded,
        title: 'Khổ Tem',
        children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in kLabelSizes.entries)
              DesignerChip(
                label: e.value.label,
                selected: tpl.sizeKey == e.key,
                onTap: () => update(tpl.copyWith(sizeKey: e.key)),
              ),
          ]),
          const SizedBox(height: 8),
          Text(
            'Chọn đúng khổ giấy decal đang lắp trong máy in tem. Chọn sai khổ tem có thể bị cắt chữ.',
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade600, height: 1.5),
          ),
        ],
      ),
      DesignerSection(
        icon: Icons.visibility_rounded,
        title: 'Hiển Thị Trên Tem',
        children: [
          DesignerToggleRow('Số đơn', tpl.showOrderNumber, Icons.tag_rounded,
              (v) => update(tpl.copyWith(showOrderNumber: v))),
          DesignerToggleRow('Tên bàn / Mang đi', tpl.showTableName,
              Icons.table_restaurant_rounded,
              (v) => update(tpl.copyWith(showTableName: v))),
          DesignerToggleRow('Thứ tự ly (1/2)', tpl.showQtyIndex,
              Icons.format_list_numbered_rounded,
              isRecommended: true,
              (v) => update(tpl.copyWith(showQtyIndex: v))),
          DesignerToggleRow('Ghi chú / topping', tpl.showNote,
              Icons.sticky_note_2_rounded,
              isRecommended: true,
              (v) => update(tpl.copyWith(showNote: v))),
          DesignerToggleRow('Giờ gọi món', tpl.showTime, Icons.access_time_rounded,
              (v) => update(tpl.copyWith(showTime: v))),
          DesignerToggleRow('Đường kẻ phân cách', tpl.showDivider,
              Icons.horizontal_rule_rounded,
              (v) => update(tpl.copyWith(showDivider: v))),
          DesignerToggleRow('In đậm tên món', tpl.boldName, Icons.format_bold_rounded,
              (v) => update(tpl.copyWith(boldName: v))),
        ],
      ),
      DesignerSection(
        icon: Icons.text_fields_rounded,
        title: 'Cỡ Chữ',
        children: [
          DesignerSliderRow(
            label: 'Tên món',
            hint: 'Tên dài sẽ bị cắt ở cuối dòng — chọn cỡ vừa khổ tem',
            value: tpl.nameFontSize.toDouble(),
            min: 8, max: 16,
            color: _kOrange,
            onChanged: (v) => update(tpl.copyWith(nameFontSize: v.round())),
          ),
          const SizedBox(height: 12),
          DesignerSliderRow(
            label: 'Dòng số đơn / bàn / thứ tự ly',
            hint: 'Chữ phụ phía trên tên món',
            value: tpl.infoFontSize.toDouble(),
            min: 6, max: 12,
            color: _kGreen,
            onChanged: (v) => update(tpl.copyWith(infoFontSize: v.round())),
          ),
          const SizedBox(height: 12),
          DesignerSliderRow(
            label: 'Ghi chú / topping',
            hint: 'Chữ nghiêng bên dưới tên món',
            value: tpl.noteFontSize.toDouble(),
            min: 5, max: 10,
            color: _kTeal,
            onChanged: (v) => update(tpl.copyWith(noteFontSize: v.round())),
          ),
        ],
      ),
      OutlinedButton.icon(
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: Text('Đặt lại mặc định tem ly',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade400,
          side: BorderSide(color: Colors.red.shade300),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: () => ref.read(barLabelTemplateProvider.notifier).reset(),
      ),
      const SizedBox(height: 20),
    ]);
  }
}

/// Xem trước tem đúng tỉ lệ khổ giấy: 1mm = [_pxPerMm] điểm ảnh, chữ pt quy đổi cùng tỉ lệ.
class _LabelPreview extends StatelessWidget {
  final BarLabelTemplate tpl;
  const _LabelPreview({required this.tpl});

  static const _pxPerMm = 5.0;
  // 1pt = 1/72 inch = 0.3528 mm
  static const _ptToPx = 0.3528 * _pxPerMm;

  @override
  Widget build(BuildContext context) {
    final w = tpl.widthMm * _pxPerMm;
    final h = tpl.heightMm * _pxPerMm;
    const margin = 2 * _pxPerMm;
    TextStyle st(int pt, {bool bold = false, bool italic = false, Color? color}) =>
        GoogleFonts.roboto(
          fontSize: pt * _ptToPx,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          color: color ?? Colors.black,
          height: 1.15,
        );

    final head = [
      if (tpl.showOrderNumber) '#QN-018',
      if (tpl.showTableName) 'Bàn 5',
    ].join(' - ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Text('Xem trước tem ${tpl.widthMm.round()}×${tpl.heightMm.round()}mm (đúng tỉ lệ)',
            style: GoogleFonts.plusJakartaSans(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 14),
        Center(
          child: Container(
            width: w,
            height: h,
            padding: const EdgeInsets.all(margin),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 12)
              ],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (head.isNotEmpty || tpl.showQtyIndex)
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Flexible(
                      child: Text(head,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: st(tpl.infoFontSize, bold: true))),
                  if (tpl.showQtyIndex) Text('1/2', style: st(tpl.infoFontSize, bold: true)),
                ]),
              if (tpl.showDivider)
                Container(
                    height: 0.5,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: Colors.black),
              const SizedBox(height: 1),
              Text('Trà sữa trân châu đường đen',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: st(tpl.nameFontSize, bold: tpl.boldName)),
              if (tpl.showNote) ...[
                const SizedBox(height: 1),
                Text('Ít đường, 50% đá',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: st(tpl.noteFontSize, italic: true)),
              ],
              const Spacer(),
              if (tpl.showTime)
                Align(
                    alignment: Alignment.bottomRight,
                    child: Text('13:45', style: st(6))),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Text('Mỗi ly in một tem riêng; 2 ly cùng món → 2 tem (1/2, 2/2).',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.grey.shade500)),
      ]),
    );
  }
}
