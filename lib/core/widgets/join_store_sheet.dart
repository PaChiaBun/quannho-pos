// lib/core/widgets/join_store_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
// Join Store Sheet — Nhập mã quán để kết nối cho nhân viên
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/session_provider.dart';
import '../services/user_auth_service.dart';

/// Mở bottom sheet nhập mã quán để kết nối.
/// [onSuccess]: callback khi kết nối thành công — caller tự xử lý chuyển trang.
Future<void> showJoinStoreSheet(
  BuildContext context,
  WidgetRef ref, {
  VoidCallback? onSuccess,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JoinStoreSheet(
      ref: ref,
      onSuccess: onSuccess,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
class _JoinStoreSheet extends StatefulWidget {
  final WidgetRef ref;
  final VoidCallback? onSuccess;
  const _JoinStoreSheet({required this.ref, this.onSuccess});

  @override
  State<_JoinStoreSheet> createState() => _JoinStoreSheetState();
}

class _JoinStoreSheetState extends State<_JoinStoreSheet> {
  final _codeCtrl = TextEditingController();
  bool   _loading = false;
  String _error   = '';

  static const _navy   = Color(0xFF1E1C5E);
  static const _orange = Color(0xFFE85D20);

  @override
  void dispose() { _codeCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Vui lòng nhập mã quán');
      return;
    }
    setState(() { _loading = true; _error = ''; });

    final session = widget.ref.read(sessionProvider);
    if (session == null) {
      setState(() { _loading = false; _error = 'Phiên đăng nhập hết hạn.'; });
      return;
    }

    final res = await UserAuthService.joinStoreByCode(
      userId: session.userId,
      storeCode: code,
    );

    if (!mounted) return;

    if (res.isSuccess) {
      // Tìm lại thông tin quán vừa kết nối từ membership để update session
      // Do joinStoreByCode lưu prefs bên trong nên chỉ cần fetch lại membership hoặc tự tạo
      final membership = StoreMembership(
        storeId:   res.storeId!,
        storeName: 'Quán ăn', // tên quán sẽ tự load lại khi refresh/fetch memberships
        storeCode: res.storeCode!,
        role:      'waiter',
        isOwner:   false,
      );
      
      // Update session hiện tại
      widget.ref.read(sessionProvider.notifier).updateStore(membership);
      await UserAuthService.selectStore(membership);

      if (!mounted) return;
      Navigator.pop(context); // đóng sheet
      widget.onSuccess?.call();
    } else {
      setState(() {
        _loading = false;
        _error   = res.errorMessage ?? 'Có lỗi xảy ra, thử lại sau.';
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
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),

            // Icon lớn minh hoạ
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E1C5E), Color(0xFFFF6B35)],
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
              child: const Icon(Icons.qr_code_scanner_rounded,
                color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            const Text('Kết nối vào quán',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.w900,
                color: _navy, letterSpacing: -0.5)),
            const SizedBox(height: 6),
            const Text(
              'Nhập mã quán do chủ quán cung cấp (ví dụ: QN-XXXX)',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF9E9085))),
            const SizedBox(height: 24),

            // Ô nhập mã quán
            TextField(
              controller: _codeCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: _navy, letterSpacing: 2),
              decoration: InputDecoration(
                labelText: 'Mã kết nối quán',
                hintText: 'QN-XXXX',
                prefixIcon: const Icon(Icons.vpn_key_rounded, color: _orange),
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

            // Nút kết nối
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _orange.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.link_rounded, size: 20),
                          SizedBox(width: 8),
                          Text('Kết nối ngay',
                            style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w800)),
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
