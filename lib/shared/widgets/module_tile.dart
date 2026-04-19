import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE CONFIG DATA — Định nghĩa từng Lego tile
// ─────────────────────────────────────────────────────────────────────────────
class ModuleTileData {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final bool isLight;
  final Color? iconColor;
  final Color? textColor;
  final String? badge; // số badge (đơn hàng, cảnh báo...)
  final String? route; // route để navigate

  const ModuleTileData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    this.isLight = false,
    this.iconColor,
    this.textColor,
    this.badge,
    this.route,
  });
}

// Danh sách config mặc định cho từng module
const Map<String, ModuleTileData> kModuleConfigs = {
  'pos': ModuleTileData(
    id: 'pos',
    title: 'Bán hàng',
    subtitle: 'Tạo đơn nhanh',
    icon: Icons.storefront_rounded,
    colors: [Color(0xFFE85D20), Color(0xFFFF9A5C)],
    route: '/pos',
  ),
  'kho': ModuleTileData(
    id: 'kho',
    title: 'Kho hàng',
    subtitle: 'Tồn kho & nhập',
    icon: Icons.inventory_2_rounded,
    colors: [Color(0xFF1E1C5E), Color(0xFF2D2B8A)],
    route: '/kho',
  ),
  'finance': ModuleTileData(
    id: 'finance',
    title: 'Thu Chi',
    subtitle: 'Dòng tiền',
    icon: Icons.account_balance_wallet_rounded,
    colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
    route: '/finance',
  ),
  'report': ModuleTileData(
    id: 'report',
    title: 'Báo cáo',
    subtitle: 'Phân tích KPI',
    icon: Icons.bar_chart_rounded,
    colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
    route: '/report',
  ),
  'loyalty': ModuleTileData(
    id: 'loyalty',
    title: 'Khách hàng',
    subtitle: 'Điểm thưởng',
    icon: Icons.card_giftcard_rounded,
    colors: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
    route: '/loyalty',
  ),
  'table': ModuleTileData(
    id: 'table',
    title: 'Bàn',
    subtitle: 'Quản lý bàn',
    icon: Icons.table_restaurant_rounded,
    colors: [Color(0xFF00695C), Color(0xFF00897B)],
    route: '/table',
  ),
  'staff': ModuleTileData(
    id: 'staff',
    title: 'Nhân viên',
    subtitle: 'Ca làm việc',
    icon: Icons.badge_rounded,
    colors: [Color(0xFF880E4F), Color(0xFFC2185B)],
    route: '/staff',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// MODULE TILE — Lego tile widget chính
// ─────────────────────────────────────────────────────────────────────────────
class ModuleTile extends StatefulWidget {
  final ModuleTileData data;
  final bool isEditMode;
  final bool isEven; // wiggle hướng ngược nhau
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final double height;

  const ModuleTile({
    super.key,
    required this.data,
    this.isEditMode = false,
    this.isEven = false,
    this.onRemove,
    this.onTap,
    this.height = 140,
  });

  @override
  State<ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<ModuleTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggleCtrl;

  @override
  void initState() {
    super.initState();
    _wiggleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _wiggleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget tile = _buildTile();

    if (widget.isEditMode) {
      // Wiggle: xoay ±2° alternating
      tile = AnimatedBuilder(
        animation: _wiggleCtrl,
        builder: (_, child) {
          final angle = math.sin(_wiggleCtrl.value * math.pi) *
              (widget.isEven ? 0.035 : -0.035);
          return Transform.rotate(angle: angle, child: child);
        },
        child: tile,
      );
    }

    return tile;
  }

  Widget _buildTile() {
    final d = widget.data;
    const white60 = Color(0x99FFFFFF);
    const white30 = Color(0x4DFFFFFF);

    return GestureDetector(
      onTap: widget.isEditMode ? null : widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Tile body ──────────────────────────────────────────────────
          Container(
            height: widget.height,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: d.colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: d.colors.first.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon box
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: white30,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(d.icon, color: Colors.white, size: 22),
                ),
                // Texts
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      d.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      d.subtitle,
                      style: const TextStyle(
                        color: white60,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Badge ──────────────────────────────────────────────────────
          if (d.badge != null)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  d.badge!,
                  style: TextStyle(
                    color: d.colors.first,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

          // ── Remove button (edit mode) ────────────────────────────────
          if (widget.isEditMode)
            Positioned(
              right: -8,
              top: -8,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onRemove?.call();
                },
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFFC62828),
                  ),
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0, 0),
                    end: const Offset(1, 1),
                    duration: 200.ms,
                    curve: Curves.elasticOut,
                  ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MODULE TILE — Tile "+" để thêm module
// ─────────────────────────────────────────────────────────────────────────────
class AddModuleTile extends StatelessWidget {
  final VoidCallback? onTap;
  final double height;

  const AddModuleTile({super.key, this.onTap, this.height = 140});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE0D8CC),
            width: 2,
            // Dashed border via BoxDecoration cannot be dashed natively,
            // use strokeAlign workaround styling instead
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2EDE4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF9E9085),
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thêm',
                style: TextStyle(
                  color: Color(0xFF9E9085),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      )
          .animate()
          .scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 300.ms,
            curve: Curves.elasticOut,
          )
          .fadeIn(duration: 200.ms),
    );
  }
}
