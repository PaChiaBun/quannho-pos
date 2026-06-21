import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE CONFIG DATA
// ─────────────────────────────────────────────────────────────────────────────
class ModuleTileData {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color baseColor;  // single base – tile derives gradient internally
  final String? badge;
  final String? route;

  const ModuleTileData({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.baseColor,
    this.badge,
    this.route,
  });
}

// ── Palette: vibrant, clearly distinct from each other ──────────────────────
const Map<String, ModuleTileData> kModuleConfigs = {
  'pos': ModuleTileData(
    id: 'pos',
    title: 'Bán hàng',
    subtitle: 'Tạo đơn nhanh',
    icon: Icons.storefront_rounded,
    baseColor: Color(0xFFEA580C), // electric orange
    route: '/pos',
  ),
  'kho': ModuleTileData(
    id: 'kho',
    title: 'Kho hàng',
    subtitle: 'Tồn kho & nhập',
    icon: Icons.inventory_2_rounded,
    baseColor: Color(0xFF7C3AED), // vivid violet
    route: '/kho',
  ),
  'finance': ModuleTileData(
    id: 'finance',
    title: 'Thu Chi',
    subtitle: 'Dòng tiền',
    icon: Icons.account_balance_wallet_rounded,
    baseColor: Color(0xFF059669), // emerald green
    route: '/finance',
  ),
  'report': ModuleTileData(
    id: 'report',
    title: 'Báo cáo',
    subtitle: 'Phân tích KPI',
    icon: Icons.bar_chart_rounded,
    baseColor: Color(0xFF2563EB), // electric blue
    route: '/report',
  ),
  'loyalty': ModuleTileData(
    id: 'loyalty',
    title: 'Khách hàng',
    subtitle: 'Điểm thưởng',
    icon: Icons.card_giftcard_rounded,
    baseColor: Color(0xFFDB2777), // hot pink
    route: '/loyalty',
  ),
  'table': ModuleTileData(
    id: 'table',
    title: 'Bàn',
    subtitle: 'Quản lý bàn',
    icon: Icons.table_restaurant_rounded,
    baseColor: Color(0xFF0D9488), // teal
    route: '/table',
  ),
  'kitchen': ModuleTileData(
    id: 'kitchen',
    title: 'Phiếu bếp',
    subtitle: 'Kanban bếp',
    icon: Icons.local_fire_department_rounded,
    baseColor: Color(0xFFEA580C), // warm orange-red
    route: '/kitchen',
  ),
  'staff': ModuleTileData(
    id: 'staff',
    title: 'Nhân viên',
    subtitle: 'Ca làm việc',
    icon: Icons.badge_rounded,
    baseColor: Color(0xFFDC2626),
    route: '/staff',
  ),
  'chamcong': ModuleTileData(
    id: 'chamcong',
    title: 'Chấm công',
    subtitle: 'Vào / Ra ca',
    icon: Icons.fingerprint_rounded,
    baseColor: Color(0xFF0284C7),
    route: '/chamcong',
  ),
  'kho_pro': ModuleTileData(
    id: 'kho_pro',
    title: 'Kho Chuyên Nghiệp',
    subtitle: 'Định lượng nhà hàng',
    icon: Icons.restaurant_menu_rounded,
    baseColor: Color(0xFF9333EA),
    badge: '⭐',
    route: '/kho_pro',
  ),
  'tinhluong': ModuleTileData(
    id: 'tinhluong',
    title: 'Tính Lương',
    subtitle: 'Kỳ lương & phiếu',
    icon: Icons.payments_rounded,
    baseColor: Color(0xFF0F766E), // teal-700
    badge: '💰',
    route: '/tinhluong',
  ),
  'kay_ops': ModuleTileData(
    id: 'kay_ops',
    title: 'Vận Hành',
    subtitle: 'Checklist công việc',
    icon: Icons.checklist_rounded,
    baseColor: Color(0xFF7C3AED), // violet—phân biệt với Kho
    badge: '📋',
    route: '/kay_ops',
  ),
  'bill_printer': ModuleTileData(
    id: 'bill_printer',
    title: 'In Hoá Đơn',
    subtitle: 'Thiết kế & in bill',
    icon: Icons.print_rounded,
    baseColor: Color(0xFF4338CA), // indigo-700
    route: '/bill_printer',
  ),
};

// ─────────────────────────────────────────────────────────────────────────────
// MODULE TILE
// ─────────────────────────────────────────────────────────────────────────────
class ModuleTile extends StatefulWidget {
  final ModuleTileData data;
  final bool isEditMode;
  final bool isEven;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;
  final double? height;
  final int entryDelay;

  const ModuleTile({
    super.key,
    required this.data,
    this.isEditMode = false,
    this.isEven = false,
    this.onRemove,
    this.onTap,
    this.height,
    this.entryDelay = -1,
  });

  @override
  State<ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<ModuleTile>
    with TickerProviderStateMixin {
  late final AnimationController _jiggle;
  late final AnimationController _pressCtrl;
  late final AnimationController _rippleCtrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rippleAnim;
  bool _flashing = false;
  Offset _tapPosition = Offset.zero;

  // ── Jiggle params ────────────────────────────────────────────────────────
  static const double _amp = 0.048;
  static const int _cycleDurationMs = 380;

  @override
  void initState() {
    super.initState();
    _jiggle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _cycleDurationMs),
    );
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.84).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _rippleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
    if (widget.isEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isEditMode) {
          if (!widget.isEven) _jiggle.value = 0.5;
          _jiggle.repeat();
        }
      });
    }
  }

  @override
  void didUpdateWidget(ModuleTile old) {
    super.didUpdateWidget(old);
    if (widget.isEditMode && !old.isEditMode) {
      if (!widget.isEven) _jiggle.value = 0.5;
      _jiggle.repeat();
    } else if (!widget.isEditMode && old.isEditMode) {
      _jiggle.stop();
      _jiggle.animateTo(
        _jiggle.value < 0.5 ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ).then((_) {
        if (mounted) _jiggle.value = 0;
      });
    }
  }

  @override
  void dispose() {
    _jiggle.dispose();
    _pressCtrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _pressCtrl.forward();
    _rippleCtrl.forward(from: 0);
    setState(() {
      _flashing = true;
      _tapPosition = details.localPosition;
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _flashing = false);
    });
  }

  void _onTapUp(TapUpDetails _) => _pressCtrl.reverse();
  void _onTapCancel() {
    _pressCtrl.reverse();
    _rippleCtrl.stop();
    if (mounted) setState(() => _flashing = false);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildTile();

    if (widget.isEditMode) {
      child = AnimatedBuilder(
        animation: _jiggle,
        builder: (_, inner) {
          // Continuous full-cycle sine: 0→1→0→-1→0 (smooth, no seam)
          final rawAngle = _amp * math.sin(_jiggle.value * 2 * math.pi);
          // Even tiles go right, odd tiles go left (opposite sign)
          final angle = widget.isEven ? rawAngle : -rawAngle;
          return Transform.scale(
            scale: 0.92,
            child: Transform.rotate(
              angle: angle,
              child: inner,
            ),
          );
        },
        child: child,
      );
    } else if (widget.entryDelay >= 0) {
      child = child
          .animate(delay: widget.entryDelay.ms)
          .slideY(begin: 0.12, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
          .fadeIn(duration: 220.ms);
    }

    return child;
  }

  Widget _buildTile() {
    final d = widget.data;
    final base = d.baseColor;
    // Derive lighter shade for gradient top
    final light = _lighten(base, 0.22);
    final dark  = _darken(base, 0.18);

    return GestureDetector(
      onTap: widget.isEditMode ? null : () {
        HapticFeedback.lightImpact();
        // Delay navigation 160ms → user sees animation before screen changes
        Future.delayed(const Duration(milliseconds: 160), () {
          widget.onTap?.call();
        });
      },
      onTapDown: widget.isEditMode ? null : _onTapDown,
      onTapUp:   widget.isEditMode ? null : _onTapUp,
      onTapCancel: widget.isEditMode ? null : _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Main Tile ────────────────────────────────────────────────
            Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [light, dark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                boxShadow: [
                  BoxShadow(
                    color: base.withValues(alpha: 0.42),
                    blurRadius: 18,
                    spreadRadius: -4,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Stack(
                  children: [
                    // ── Pattern: big soft circle bottom-right ────────────
                    Positioned(
                      right: -28,
                      bottom: -28,
                      child: Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    // ── Pattern: small circle top-right ──────────────────
                    Positioned(
                      right: 12,
                      top: -30,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                    ),

                    // ── Content ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon pill
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.white.withValues(alpha: 0.20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(d.icon, color: Colors.white, size: 28),
                          ),

                          const Spacer(),

                          // Module name
                          Text(
                            d.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          // Subtitle
                          Text(
                            d.subtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.70),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),

                    // ── Ripple từ điểm chạm ──────────────────────────────
                    AnimatedBuilder(
                      animation: _rippleAnim,
                      builder: (_, __) => CustomPaint(
                        painter: _RipplePainter(
                          progress: _rippleAnim.value,
                          center: _tapPosition,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),

                    // ── Flash trắng overlay ───────────────────────────────
                    AnimatedOpacity(
                      opacity: _flashing ? 0.32 : 0.0,
                      duration: const Duration(milliseconds: 60),
                      child: Container(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            // ── Remove badge ─────────────────────────────────────────────
            if (widget.isEditMode)
              Positioned(
                right: -9,
                top: -9,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    widget.onRemove?.call();
                  },
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFF3B30),
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Colors.white, width: 2.5),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x66FF3B30),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.remove_rounded,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0, 0),
                      end: const Offset(1, 1),
                      delay: 60.ms,
                      duration: 320.ms,
                      curve: Curves.elasticOut,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Color helpers ────────────────────────────────────────────────────────
  static Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.05).clamp(0, 1))
        .toColor();
  }

  static Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RIPPLE PAINTER — vòng tròn trắng lan toa từ điểm chạm
// ─────────────────────────────────────────────────────────────────────────────
class _RipplePainter extends CustomPainter {
  final double progress;  // 0.0 → 1.0
  final Offset center;

  const _RipplePainter({required this.progress, required this.center});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final maxRadius = size.longestSide * 0.85;
    final radius = maxRadius * progress;
    final opacity = (1.0 - progress).clamp(0.0, 1.0) * 0.35;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center.isFinite ? center : Offset(size.width / 2, size.height / 2), radius, paint);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.progress != progress || old.center != center;
}

// ─────────────────────────────────────────────────────────────────────────────
// ADD MODULE TILE
// ─────────────────────────────────────────────────────────────────────────────
class AddModuleTile extends StatefulWidget {
  final VoidCallback? onTap;
  final double? height;
  const AddModuleTile({super.key, this.onTap, this.height});

  @override
  State<AddModuleTile> createState() => _AddModuleTileState();
}

class _AddModuleTileState extends State<AddModuleTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp:   (_) => setState(() => _pressed = false),
      onTapCancel:   () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeInOut,
        child: Container(
          height: widget.height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFFDED6CC),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: const Color(0xFFF0EBE5),
                  border: Border.all(
                    color: const Color(0xFFDDD5CC),
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFFB0A89E),
                  size: 28,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Thêm',
                style: TextStyle(
                  color: Color(0xFFB0A89E),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.75, 0.75),
          end: const Offset(1.0, 1.0),
          delay: 80.ms,
          duration: 420.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 200.ms);
  }
}
