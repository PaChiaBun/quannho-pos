import 'package:flutter/material.dart';

class CartAnimationHelper {
  /// Kích hoạt hiệu ứng bay từ [startOffset] đến [endOffset]
  static void runFlyAnimation({
    required BuildContext context,
    required Offset startOffset,
    required Offset endOffset,
    Color color = const Color(0xFFE65100),
    VoidCallback? onComplete,
  }) {
    final overlayState = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return _FlyingParticle(
          startOffset: startOffset,
          endOffset: endOffset,
          color: color,
          onComplete: () {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                entry.remove();
              } catch (_) {}
            });
            onComplete?.call();
          },
        );
      },
    );

    overlayState.insert(entry);
  }
}

class _FlyingParticle extends StatefulWidget {
  final Offset startOffset;
  final Offset endOffset;
  final Color color;
  final VoidCallback onComplete;

  const _FlyingParticle({
    required this.startOffset,
    required this.endOffset,
    required this.color,
    required this.onComplete,
  });

  @override
  State<_FlyingParticle> createState() => _FlyingParticleState();
}

class _FlyingParticleState extends State<_FlyingParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Kéo dài thời gian bay lên 1300ms để bay mượt, chậm rãi và dễ quan sát
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    // Sử dụng Curves.fastOutSlowIn để tạo cảm giác snap lúc đầu và giảm tốc cực kỳ êm ái khi đáp giỏ
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final t = _animation.value;
        
        // Tính toán đường bay parabol cong để tăng tính thẩm mỹ
        final double midX = (widget.startOffset.dx + widget.endOffset.dx) / 2;
        final double midY = (widget.startOffset.dy + widget.endOffset.dy) / 2 - 160;

        // Nội suy Bezier bậc 2
        final double x = (1 - t) * (1 - t) * widget.startOffset.dx +
            2 * (1 - t) * t * midX +
            t * t * widget.endOffset.dx;
        final double y = (1 - t) * (1 - t) * widget.startOffset.dy +
            2 * (1 - t) * t * midY +
            t * t * widget.endOffset.dy;

        // Nguyên tâm hình thu nhỏ dần đều từ to (2.5x) về nhỏ (0.15x) khi đến giỏ hàng
        final double scale = 2.5 * (1 - t) + 0.15 * t;
        // Giữ độ hiển thị lâu hơn, chỉ mờ hẳn khi cực kỳ gần đích (t > 0.85)
        final double opacity = t < 0.85 ? 1.0 : (1.0 - t) / 0.15;

        return Positioned(
          left: x - 12,
          top: y - 12,
          child: RepaintBoundary( // Tối ưu hiệu năng: cô lập lớp sơn (paint) giúp animation mượt 60-120fps
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 24, // Thu gọn kích thước để cân đối hơn
                  height: 24,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Icon(
                        Icons.fastfood_rounded,
                        color: Colors.white,
                        size: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
