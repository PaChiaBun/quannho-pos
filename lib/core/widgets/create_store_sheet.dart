// lib/core/widgets/create_store_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
// Create Store Sheet — Dùng chung tại Dashboard, Settings, Auth
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../services/user_auth_service.dart';

/// Mở bottom sheet tạo quán mới.
/// [onSuccess]: callback khi tạo thành công — không navigate, để caller xử lý.
Future<void> showCreateStoreSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CreateStoreSheet(ref: ref, onSuccess: onSuccess),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _CreateStoreSheet extends StatefulWidget {
  final WidgetRef ref;
  final VoidCallback? onSuccess;
  const _CreateStoreSheet({required this.ref, this.onSuccess});

  @override
  State<_CreateStoreSheet> createState() => _CreateStoreSheetState();
}

class _CreateStoreSheetState extends State<_CreateStoreSheet> {
  final _nameCtrl = TextEditingController();
  bool _loading = false;
  String _error = '';

  static const _navy = Color(0xFF1E1C5E);
  static const _orange = Color(0xFFE85D20);

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Vui lòng nhập tên quán');
      return;
    }
    setState(() {
      _loading = true;
      _error = '';
    });

    final session = widget.ref.read(sessionProvider);
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'Phiên đăng nhập hết hạn.';
      });
      return;
    }

    final res = await UserAuthService.createStore(
      userId: session.userId,
      storeName: name,
    );

    if (!mounted) return;

    if (res.isSuccess) {
      final membership =
          res.membership ??
          StoreMembership(
            storeId: res.storeId!,
            storeName: name,
            storeCode: res.storeCode!,
            role: 'owner',
            isOwner: true,
          );
      widget.ref.read(sessionProvider.notifier).updateStore(membership);
      Navigator.pop(context);
      widget.onSuccess?.call();
    } else {
      // Chỉ khôi phục khi RPC đã tạo membership nhưng bước đổi JWT thất bại.
      // Lỗi preflight không được dựng membership giả hay hỏi lại mật khẩu.
      if (res.membership != null && res.storeId?.isNotEmpty == true) {
        final membership = res.membership!;
        {
          final pwdCtrl = TextEditingController();
          String? pwd;
          try {
            pwd = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text('Xác thực tạo $name'),
                content: TextField(
                  controller: pwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nhập mật khẩu để cấp POS JWT cho quán',
                    border: OutlineInputBorder(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Hủy'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(pwdCtrl.text.trim()),
                    child: const Text('Xác nhận'),
                  ),
                ],
              ),
            );
          } finally {
            pwdCtrl.dispose();
          }

          if (pwd != null && pwd.trim().isNotEmpty) {
            final ok = await UserAuthService.selectStore(
              membership,
              password: pwd,
              phone: session.phone,
            );
            if (mounted && ok) {
              widget.ref.read(sessionProvider.notifier).updateStore(membership);
              Navigator.pop(context);
              widget.onSuccess?.call();
              return;
            }
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = res.errorMessage ?? 'Có lỗi xảy ra, thử lại sau.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Đẩy sheet lên khi bàn phím mở
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Icon lớn minh hoạ
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1C5E), Color(0xFFE85D20)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            const Text(
              'Tạo quán của bạn',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: _navy,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bạn sẽ là chủ quán và quản lý toàn bộ hệ thống',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9E9085)),
            ),
            const SizedBox(height: 24),

            // Ô nhập tên quán
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _navy,
              ),
              decoration: InputDecoration(
                labelText: 'Tên quán',
                hintText: 'Ví dụ: Quán Trà Sữa Bình Dân',
                prefixIcon: const Icon(
                  Icons.storefront_rounded,
                  color: _orange,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0D8CC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE0D8CC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _orange, width: 1.8),
                ),
                errorText: _error.isEmpty ? null : _error,
              ),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 20),

            // Nút tạo quán
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _orange.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Tạo quán ngay',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
