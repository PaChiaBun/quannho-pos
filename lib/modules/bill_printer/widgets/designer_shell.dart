// Khung dùng chung cho các tab thiết kế mẫu in (Hoá đơn / Bếp nóng / Bếp bar / Tem ly):
// thanh chọn chế độ (Cấu hình | Mẫu dựng sẵn | Xem trước) + nút hành động, và bố cục
// rộng (cấu hình bên trái, xem trước bên phải) / hẹp (chuyển chế độ).
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesignerShell extends StatefulWidget {
  final Color accent;
  final Widget config;
  final Widget preview;

  /// Bộ chọn mẫu dựng sẵn; null → không có chế độ này (VD: tem ly).
  final Widget? presets;

  /// Nút ở góc phải thanh công cụ (Lưu, Lịch sử...).
  final List<Widget> actions;

  const DesignerShell({
    super.key,
    required this.accent,
    required this.config,
    required this.preview,
    this.presets,
    this.actions = const [],
  });

  @override
  State<DesignerShell> createState() => DesignerShellState();
}

class DesignerShellState extends State<DesignerShell> {
  static const _config = 0, _presets = 1, _preview = 2;
  int _mode = _config;

  /// Cho màn con chuyển chế độ (VD: sau khi áp dụng mẫu → về Cấu hình).
  void showConfig() => setState(() => _mode = _config);

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 700;
    final hasPresets = widget.presets != null;
    // Màn rộng luôn hiện xem trước bên phải nên không có chế độ "Xem trước" riêng.
    var mode = _mode;
    if (isWide && mode == _preview) mode = _config;
    if (!hasPresets && mode == _presets) mode = _config;

    final modes = <(int, IconData, String)>[
      (_config, Icons.tune_rounded, 'Thiết kế'),
      if (hasPresets) (_presets, Icons.collections_bookmark_rounded, 'Mẫu dựng sẵn'),
      if (!isWide) (_preview, Icons.preview_rounded, 'Xem trước'),
    ];

    // Màn hẹp (Sunmi 360dp): 3 chế độ + nút Lưu không đủ chỗ — "Mẫu dựng sẵn" bị cắt, "Xem trước"
    // khuất hẳn → chế độ chưa chọn chỉ hiện biểu tượng (giữ tên ở chú thích khi giữ ngón tay).
    final compact = MediaQuery.of(context).size.width < 420;

    final toolbar = Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final m in modes) ...[
                _ModeChip(
                  icon: m.$2,
                  label: m.$3,
                  selected: mode == m.$1,
                  compact: compact,
                  accent: widget.accent,
                  onTap: () => setState(() => _mode = m.$1),
                ),
                const SizedBox(width: 8),
              ],
            ]),
          ),
        ),
        ...widget.actions,
      ]),
    );

    final Widget body;
    if (isWide) {
      body = mode == _presets
          // Bộ chọn mẫu đã có xem trước riêng nên cho chiếm hết bề ngang.
          ? widget.presets!
          : Row(children: [
              SizedBox(width: 420, child: widget.config),
              const VerticalDivider(width: 1),
              Expanded(child: widget.preview),
            ]);
    } else {
      body = switch (mode) {
        _presets => widget.presets!,
        _preview => widget.preview,
        _ => widget.config,
      };
    }

    return Column(children: [
      toolbar,
      const Divider(height: 1),
      Expanded(child: body),
    ]);
  }
}

class _ModeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool compact; // màn hẹp: chưa chọn thì chỉ hiện biểu tượng
  final Color accent;
  final VoidCallback onTap;
  const _ModeChip({
    required this.icon,
    required this.label,
    required this.selected,
    this.compact = false,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconOnly = compact && !selected;
    final chip = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey.shade600),
          if (!iconOnly) ...[
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : Colors.grey.shade700)),
          ],
        ]),
      ),
    );
    return iconOnly
        ? Tooltip(message: label, child: Semantics(label: label, button: true, child: chip))
        : chip;
  }
}
