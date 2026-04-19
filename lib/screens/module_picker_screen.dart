
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../shared/widgets/module_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE PICKER SCREEN — Bento Grid 2 cột, premium design
// ─────────────────────────────────────────────────────────────────────────────
class ModulePickerScreen extends ConsumerWidget {
  final List<String> activeModuleIds;

  const ModulePickerScreen({super.key, required this.activeModuleIds});

  static const _navy = Color(0xFF1E1C5E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ⚡ Capture outer context for Navigator — ctx in SliverChildBuilderDelegate
    //    does NOT carry a Navigator, so we must use this outer context.
    final navContext = context;

    final inactiveModules = kModuleConfigs.entries
        .where((e) => !activeModuleIds.contains(e.key))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: CustomScrollView(
        physics: const ClampingScrollPhysics(),
        slivers: [
          // ── Gradient SliverAppBar ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 16, color: Colors.white),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2D2B8A), _navy],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -30,
                      right: 60,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),
                    // Title content
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.add_chart_rounded,
                                    size: 18, color: Colors.white),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Thêm Modules',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${inactiveModules.length} tính năng có thể thêm',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Grid or Empty ─────────────────────────────────────────────────
          inactiveModules.isEmpty
              ? SliverFillRemaining(child: _buildEmpty())
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final entry = inactiveModules[i];
                        final d = entry.value;
                        return _PickerCard(
                          config: d,
                          index: i,
                          // Pass raw DB activate + pop as async callback
                          onTap: () async {
                            final repo = ref.read(moduleRepositoryProvider);
                            await repo.activate(d.id);
                            if (navContext.mounted) {
                              Navigator.of(navContext).pop(d.id);
                            }
                          },
                        );
                      },
                      childCount: inactiveModules.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.88,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 44,
              color: Color(0xFF2E7D32),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Tất cả bật rồi! 🎉',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1207),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Không còn module nào để thêm',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF9E9085),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PICKER CARD widget — Bento tile cho module picker
// ─────────────────────────────────────────────────────────────────────────────
class _PickerCard extends StatefulWidget {
  final ModuleTileData config;
  final int index;
  // 🔑 AsyncCallback — phải là Future<void> để _handleTap có thể await đúng cách
  final Future<void> Function() onTap;

  const _PickerCard({
    required this.config,
    required this.index,
    required this.onTap,
  });

  @override
  State<_PickerCard> createState() => _PickerCardState();
}

class _PickerCardState extends State<_PickerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double> _scaleAnim;
  bool _isAdded = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_isAdded) return; // chống double tap
    HapticFeedback.mediumImpact();

    // Hiệu ứng nhấn nhanh (non-blocking)
    _pressCtrl.forward().then((_) => _pressCtrl.reverse());

    // Chuyển sang trạng thái "đã thêm" ngay
    setState(() => _isAdded = true);

    // Haptic success sau 80ms
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.heavyImpact();

    // ⏳ Đợi hiệu ứng xanh lá chạy (350ms)
    await Future.delayed(const Duration(milliseconds: 350));

    // ⚡ Gọi async callback (được await đúng cách vì type là Future<void>)
    await widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.config;

    // Derive a slightly darker shade for gradient
    final base = d.baseColor;
    final darker = Color.fromARGB(
      (base.a * 255).round(),
      (base.r * 255 * 0.75).round(),
      (base.g * 255 * 0.75).round(),
      (base.b * 255 * 0.75).round(),
    );

    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: _isAdded ? null : _handleTap,
      child: AnimatedBuilder(
        animation: _scaleAnim,
        builder: (_, child) => Transform.scale(
          scale: _scaleAnim.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            gradient: _isAdded
                ? const LinearGradient(
                    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [base, darker],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: (_isAdded ? const Color(0xFF2E7D32) : base)
                    .withValues(alpha: _isAdded ? 0.55 : 0.40),
                blurRadius: _isAdded ? 24 : 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -18,
                right: -18,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -12,
                left: -12,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon — đổi thành checkmark khi added
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      switchInCurve: Curves.elasticOut,
                      transitionBuilder: (child, anim) => ScaleTransition(
                        scale: anim,
                        child: child,
                      ),
                      child: Container(
                        key: ValueKey(_isAdded),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          _isAdded
                              ? Icons.check_rounded
                              : d.icon,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Title
                    Text(
                      d.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtitle
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isAdded ? 'Đã thêm vào dashboard!' : d.subtitle,
                        key: ValueKey(_isAdded),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.80),
                          fontSize: 12,
                          fontWeight: _isAdded ? FontWeight.w600 : FontWeight.w400,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Add button pill — đổi thành "Đã thêm ✓" khi added
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isAdded
                            ? Colors.white.withValues(alpha: 0.30)
                            : Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.40),
                          width: 1,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          key: ValueKey(_isAdded),
                          children: [
                            Icon(
                              _isAdded
                                  ? Icons.check_rounded
                                  : Icons.add_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _isAdded ? 'Đã thêm!' : 'Thêm vào',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: widget.index * 70))
        .fadeIn(duration: 300.ms)
        .slideY(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
  }
}
