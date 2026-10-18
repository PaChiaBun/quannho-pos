// Điều khiển dùng chung cho các màn thiết kế mẫu in (nhóm cấu hình, công tắc, thanh trượt, chip).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _kIndigo = Color(0xFF1C2151);
const _kGreen  = Color(0xFF16A34A);

class DesignerSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const DesignerSection({super.key, required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: _kIndigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 15, color: _kIndigo),
        ),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.outfit(
            fontWeight: FontWeight.w700, fontSize: 14, color: _kIndigo)),
      ]),
      const SizedBox(height: 14),
      ...children,
    ]),
  );
}

class DesignerChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const DesignerChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? _kIndigo : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _kIndigo : Colors.grey.shade300),
      ),
      child: Text(label, style: GoogleFonts.outfit(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: selected ? Colors.white : Colors.grey.shade600)),
    ),
  );
}

class DesignerToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final IconData icon;
  final bool isRecommended;
  final ValueChanged<bool> onChanged;

  const DesignerToggleRow(this.label, this.value, this.icon, this.onChanged,
      {super.key, this.isRecommended = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [
      Icon(icon, size: 18, color: _kIndigo.withValues(alpha: 0.5)),
      const SizedBox(width: 10),
      Expanded(child: Row(children: [
        Flexible(child: Text(label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(fontSize: 13))),
        if (isRecommended) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text('nên bật', style: GoogleFonts.outfit(
                fontSize: 10, fontWeight: FontWeight.w600, color: _kGreen)),
          ),
        ],
      ])),
      Switch(value: value, activeThumbColor: _kIndigo, onChanged: onChanged),
    ]),
  );
}

class DesignerSliderRow extends StatelessWidget {
  final String label;
  final String hint;
  final double value;
  final double min, max;
  final Color color;
  final ValueChanged<double> onChanged;

  const DesignerSliderRow({
    super.key, required this.label, required this.hint, required this.value,
    required this.min, required this.max, required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey.shade700)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
          child: Text('${value.round()}px',
              style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w700, fontSize: 12, color: color)),
        ),
      ]),
      Slider(value: value, min: min, max: max,
          divisions: (max - min).round(),
          activeColor: color,
          inactiveColor: color.withValues(alpha: 0.15),
          onChanged: onChanged),
      Text(hint, style: GoogleFonts.outfit(
          fontSize: 11, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
    ],
  );
}
