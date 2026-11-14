import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Dải nền che thanh trạng thái (giờ, pin) cho màn có đầu trang tràn lên sau thanh trạng thái:
/// chỉ hiện khi đã cuộn, để nội dung không chạy lên đè dưới đồng hồ (Sunmi 29/10/2026).
class StatusBarScrim extends StatefulWidget {
  final Color color;
  final Widget child;

  const StatusBarScrim({super.key, required this.color, required this.child});

  @override
  State<StatusBarScrim> createState() => _StatusBarScrimState();
}

class _StatusBarScrimState extends State<StatusBarScrim> {
  bool _scrolled = false;

  bool _onScroll(ScrollNotification n) {
    // depth 0 = khung cuộn chính của màn (bỏ qua danh sách ngang / tab con bên trong).
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      final scrolled = n.metrics.pixels > 0;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    // Nền đầu trang tối: chữ giờ / pin trắng (Sunmi từng hiện xám tối, khó đọc).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: const Color(0x00000000),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Stack(
          children: [
            widget.child,
            if (top > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: top,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _scrolled ? 1 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: ColoredBox(color: widget.color),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
