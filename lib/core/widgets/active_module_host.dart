import 'package:flutter/widgets.dart';

/// Chỉ mount module đang được chọn.
///
/// Khác với [IndexedStack], các module ẩn không tồn tại trong element tree nên
/// provider, timer và realtime listener gắn với màn hình sẽ được dispose.
class ActiveModuleHost extends StatelessWidget {
  final int index;
  final List<Widget> modules;

  const ActiveModuleHost({
    super.key,
    required this.index,
    required this.modules,
  }) : assert(index >= 0 && index < modules.length);

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: ValueKey<int>(index),
      child: RepaintBoundary(child: modules[index]),
    );
  }
}
