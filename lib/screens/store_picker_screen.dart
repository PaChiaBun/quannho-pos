// lib/screens/store_picker_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
// Store Picker — Chọn quán hoặc tạo/kết nối quán
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/services/user_auth_service.dart';
import '../core/services/pos_jwt_auth_service.dart';
import '../core/providers/session_provider.dart';
import '../core/widgets/create_store_sheet.dart';
import '../core/widgets/join_store_sheet.dart';

const storePickerPostLoginKey = 'post_login_selection';

class StorePickerScreen extends ConsumerWidget {
  const StorePickerScreen({super.key});

  static const _bg = Color(0xFF131128);
  static const _orange = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    final stores = (args?['stores'] as List<StoreMembership>?) ?? [];
    final isPostLoginSelection = args?[storePickerPostLoginKey] == true;
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
              Text(
                'Xin chào, ${session?.displayName ?? ''}!',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bạn muốn thực hiện thao tác nào hôm nay?',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 32),

              // Danh sách quán hoặc thông báo chưa có quán
              Expanded(
                child: stores.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.storefront_rounded,
                                color: Colors.white30,
                                size: 48,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Bạn chưa tham gia quán nào',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Nhập mã kết nối hoặc tạo quán mới ở bên dưới.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VÀO QUÁN ĐÃ CÓ',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: ListView.separated(
                              itemCount: stores.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (_, i) {
                                final store = stores[i];
                                return _StoreCard(
                                  store: store,
                                  onTap: () async {
                                    if (isPostLoginSelection &&
                                        !PosJwtAuthService().isConfigured) {
                                      final verifiedMembership =
                                          await UserAuthService.selectStoreAfterLogin(
                                            store,
                                          );
                                      if (verifiedMembership != null) {
                                        ref
                                            .read(sessionProvider.notifier)
                                            .updateStore(verifiedMembership);
                                        if (context.mounted) {
                                          Navigator.of(
                                            context,
                                          ).pushReplacementNamed('/home');
                                        }
                                      } else if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Không thể xác minh quyền vào quán trên Supabase. Vui lòng đăng nhập lại.',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    final pwd = await _promptPassword(
                                      context,
                                      store.storeName,
                                    );
                                    if (pwd == null || pwd.trim().isEmpty)
                                      return;
                                    final session =
                                        await UserAuthService.getCurrentSession();
                                    final phone = session?.phone ?? '';
                                    final ok =
                                        await UserAuthService.selectStore(
                                          store,
                                          password: pwd,
                                          phone: phone,
                                        );
                                    if (ok) {
                                      ref
                                          .read(sessionProvider.notifier)
                                          .updateStore(store);
                                      if (context.mounted) {
                                        Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/home');
                                      }
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Xác thực đổi quán thất bại. Vui lòng kiểm tra lại mật khẩu.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 20),

              // ── 2 LỰA CHỌN: KẾT NỐI QUÁN HOẶC TẠO QUÁN MỚI ──
              Row(
                children: [
                  // Lựa chọn 1: Kết nối quán
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => showJoinStoreSheet(
                        context,
                        ref,
                        onSuccess: () =>
                            Navigator.of(context).pushReplacementNamed('/home'),
                      ),
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Kết nối quán'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _orange),
                        foregroundColor: _orange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Lựa chọn 2: Tạo quán mới
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => showCreateStoreSheet(
                        context,
                        ref,
                        onSuccess: () =>
                            Navigator.of(context).pushReplacementNamed('/home'),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Tạo quán mới'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Đăng xuất
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await ref.read(sessionProvider.notifier).clear();
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).pushNamedAndRemoveUntil('/auth', (route) => false);
                    }
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white38,
                    size: 16,
                  ),
                  label: const Text(
                    'Đăng xuất tài khoản',
                    style: TextStyle(color: Colors.white38, fontSize: 13),
                  ),
                ),
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
    'owner': ('Chủ quán', Color(0xFFFFB347)),
    'manager': ('Quản lý', Color(0xFF4F9EFF)),
    'cashier': ('Thu ngân', Color(0xFF2DD4BF)),
    'waiter': ('Phục vụ', Color(0xFFA78BFA)),
    'kitchen': ('Bếp', Color(0xFFFF6B6B)),
    'stock': ('Kho', Color(0xFF86EFAC)),
  };

  @override
  Widget build(BuildContext context) {
    final label = _roleLabels[store.role];
    final roleName = label?.$1 ?? store.role;
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1C5E),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Color(0xFFFF6B35),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.storeName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          roleName,
                          style: TextStyle(
                            color: roleColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        store.storeCode,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.login_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}

Future<String?> _promptPassword(BuildContext context, String storeName) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Xác thực chọn $storeName'),
      content: TextField(
        controller: controller,
        obscureText: true,
        decoration: const InputDecoration(
          labelText: 'Nhập mật khẩu tài khoản',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Hủy'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: const Text('Xác nhận'),
        ),
      ],
    ),
  );
}
