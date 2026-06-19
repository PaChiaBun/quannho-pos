// lib/core/widgets/permission_guard.dart
// ─────────────────────────────────────────────────────────────────────────────
// PermissionGuard — Ẩn hoặc disable widget nếu không có quyền
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/permission_provider.dart';

enum PermissionBehavior {
  /// Ẩn hoàn toàn widget (mặc định)
  hide,
  /// Disable widget (grey out, không tap được)
  disable,
  /// Hiện widget nhưng toast lỗi khi tap
  blockWithToast,
}

class PermissionGuard extends ConsumerWidget {
  final String action;
  final Widget child;
  final PermissionBehavior behavior;
  final Widget? fallback;
  final String? blockMessage;

  const PermissionGuard({
    super.key,
    required this.action,
    required this.child,
    this.behavior = PermissionBehavior.hide,
    this.fallback,
    this.blockMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPermission = ref.canDo(action);

    if (hasPermission) return child;

    switch (behavior) {
      case PermissionBehavior.hide:
        return fallback ?? const SizedBox.shrink();

      case PermissionBehavior.disable:
        return Opacity(
          opacity: 0.35,
          child: AbsorbPointer(child: child),
        );

      case PermissionBehavior.blockWithToast:
        return GestureDetector(
          behavior: HitTestBehavior.opaque, // chặn event trước khi đến child
          onTap: () {
            HapticFeedback.mediumImpact();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.lock_rounded,
                      color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      blockMessage ?? 'Bạn không có quyền thực hiện thao tác này',
                      style: const TextStyle(fontSize: 13),
                    )),
                  ],
                ),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          // AbsorbPointer: block TextButton.onPressed khỏi nhận event
          child: AbsorbPointer(
            child: Opacity(opacity: 0.45, child: child),
          ),
        );
    }
  }
}

/// Convenience widget: hiện [child] với overlay khoá nếu không có quyền.
/// Dùng cho các button trong List/Grid.
class LockedButton extends ConsumerWidget {
  final String action;
  final VoidCallback? onTap;
  final Widget child;
  final String? lockMessage;

  const LockedButton({
    super.key,
    required this.action,
    required this.child,
    this.onTap,
    this.lockMessage,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ok = ref.canDo(action);
    return GestureDetector(
      onTap: ok
          ? onTap
          : () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Row(children: [
                  const Icon(Icons.lock_rounded, color: Colors.white, size: 15),
                  const SizedBox(width: 8),
                  Text(lockMessage ?? 'Không có quyền thực hiện thao tác này'),
                ]),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
            },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: ok ? 1.0 : 0.4,
        child: Stack(
          children: [
            child,
            if (!ok)
              Positioned(
                right: 2, top: 2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC62828),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_rounded,
                    size: 8, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
