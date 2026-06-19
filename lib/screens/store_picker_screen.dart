// lib/screens/store_picker_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Store Picker — Chọn quán khi tài khoản thuộc nhiều quán
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/user_auth_service.dart';
import '../core/providers/session_provider.dart';

class StorePickerScreen extends ConsumerWidget {
  const StorePickerScreen({super.key});

  static const _bg     = Color(0xFF131128);
  static const _navy   = Color(0xFF1E1C5E);
  static const _orange = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final stores = (args?['stores'] as List<StoreMembership>?) ?? [];
    final session = ref.watch(sessionProvider);

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text('Xin chào, ${session?.displayName ?? ''}!',
                style: const TextStyle(
                  color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Bạn đang ở quán nào hôm nay?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5), fontSize: 14)),
              const SizedBox(height: 32),

              // Danh sách quán
              Expanded(
                child: ListView.separated(
                  itemCount: stores.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final store = stores[i];
                    return _StoreCard(
                      store: store,
                      onTap: () async {
                        await UserAuthService.selectStore(store);
                        ref.read(sessionProvider.notifier).updateStore(store);
                        if (context.mounted) {
                          Navigator.of(context).pushReplacementNamed('/home');
                        }
                      },
                    );
                  },
                ),
              ),

              // Đăng xuất
              TextButton.icon(
                onPressed: () async {
                  await UserAuthService.logout();
                  ref.read(sessionProvider.notifier).clear();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacementNamed('/auth');
                  }
                },
                icon: const Icon(Icons.logout_rounded, color: Colors.white38, size: 16),
                label: const Text('Đăng xuất',
                  style: TextStyle(color: Colors.white38, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreMembership store;
  final VoidCallback onTap;
  const _StoreCard({required this.store, required this.onTap});

  static const _roleLabels = {
    'owner':   ('Chủ quán',  Color(0xFFFFB347)),
    'manager': ('Quản lý',   Color(0xFF4F9EFF)),
    'cashier': ('Thu ngân',  Color(0xFF2DD4BF)),
    'waiter':  ('Phục vụ',   Color(0xFFA78BFA)),
    'kitchen': ('Bếp',       Color(0xFFFF6B6B)),
    'stock':   ('Kho',       Color(0xFF86EFAC)),
  };

  @override
  Widget build(BuildContext context) {
    final label = _roleLabels[store.role];
    final roleName  = label?.$1 ?? store.role;
    final roleColor = label?.$2 ?? Colors.white54;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C5E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront_rounded,
                color: Color(0xFFFF6B35), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.storeName,
                    style: const TextStyle(
                      color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(roleName,
                        style: TextStyle(color: roleColor, fontSize: 11,
                          fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text(store.storeCode,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11)),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
