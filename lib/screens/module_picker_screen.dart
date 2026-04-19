import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/app_providers.dart';
import '../shared/widgets/module_tile.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE PICKER SCREEN — Chọn module để thêm vào Dashboard
// ─────────────────────────────────────────────────────────────────────────────
class ModulePickerScreen extends ConsumerWidget {
  final List<String> activeModuleIds;

  const ModulePickerScreen({super.key, required this.activeModuleIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inactiveModules = kModuleConfigs.entries
        .where((e) => !activeModuleIds.contains(e.key))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1C5E),
        foregroundColor: Colors.white,
        title: const Text(
          'Thêm module',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: false,
        elevation: 0,
      ),
      body: inactiveModules.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: inactiveModules.length,
              itemBuilder: (ctx, i) {
                final entry = inactiveModules[i];
                final d = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      final repo = ref.read(moduleRepositoryProvider);
                      await repo.activate(d.id);
                      if (ctx.mounted) Navigator.of(ctx).pop(d.id);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE0D8CC),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: d.colors),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(d.icon,
                                color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1A1207),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  d.subtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9E9085),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: d.colors.first.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: d.colors.first,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate(delay: (i * 60).ms)
                      .slideX(
                        begin: 0.3,
                        end: 0,
                        duration: 300.ms,
                        curve: Curves.easeOutCubic,
                      )
                      .fadeIn(duration: 250.ms),
                );
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded,
              size: 64, color: Color(0xFF2E7D32)),
          SizedBox(height: 16),
          Text(
            'Tất cả modules đã được bật!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1207),
            ),
          ),
          SizedBox(height: 8),
          Text(
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
