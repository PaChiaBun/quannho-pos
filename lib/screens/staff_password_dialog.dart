import 'package:flutter/material.dart';

import '../core/repositories/staff_password_repository.dart';

/// Hộp "Đặt lại mật khẩu" cho nhân viên — CHỈ Chủ quán mở (màn Nhân viên → bảng chi tiết nhân viên).
/// Chủ quán tự gõ mật khẩu mới 2 lần (Chủ Quán chốt 26/10). Xong thì báo nhân viên mật khẩu mới;
/// máy nhân viên đang đăng nhập sẽ phải đăng nhập lại khi phiên hết hạn.
/// Trả true khi đổi thành công.
Future<bool> showStaffPasswordDialog(
  BuildContext context, {
  required String storeId,
  required String userId,
  required String staffName,
  StaffPasswordRepository repository = const StaffPasswordRepository(),
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StaffPasswordDialog(
      storeId: storeId,
      userId: userId,
      staffName: staffName,
      repository: repository,
    ),
  );
  return ok == true;
}

class _StaffPasswordDialog extends StatefulWidget {
  final String storeId;
  final String userId;
  final String staffName;
  final StaffPasswordRepository repository;
  const _StaffPasswordDialog({
    required this.storeId,
    required this.userId,
    required this.staffName,
    required this.repository,
  });

  @override
  State<_StaffPasswordDialog> createState() => _StaffPasswordDialogState();
}

class _StaffPasswordDialogState extends State<_StaffPasswordDialog> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _show = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    // xoá chữ trong ô trước khi bỏ (không để mật khẩu nằm lại trong bộ nhớ của ô nhập)
    _pw.clear();
    _pw2.clear();
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final pw = _pw.text;
    if (pw.length < kStaffPasswordMin || pw.length > kStaffPasswordMax) {
      setState(() => _error = staffPasswordErrorText('BAD_PASSWORD'));
      return;
    }
    if (pw.trim() != pw) {
      setState(() => _error = 'Mật khẩu không được có khoảng trắng ở đầu hoặc cuối.');
      return;
    }
    if (pw != _pw2.text) {
      setState(() => _error = 'Hai lần nhập mật khẩu không giống nhau.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.repository.setPassword(storeId: widget.storeId, userId: widget.userId, newPassword: pw);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = staffPasswordErrorText(err);
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration dec(String label) => InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      suffixIcon: IconButton(
        tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
        icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _show = !_show),
      ),
    );
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('Đặt lại mật khẩu — ${widget.staffName}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Gõ mật khẩu mới cho nhân viên (ít nhất 8 ký tự), rồi báo trực tiếp cho họ. '
              'Mật khẩu cũ hết dùng ngay.',
              style: TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF5F5A55)),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('staff_pw_new'),
              controller: _pw,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              // KHÔNG gợi ý lưu vào trình quản lý mật khẩu của máy chủ quán (đây là mật khẩu của nhân viên — QC 30/10)
              autofillHints: null,
              maxLength: kStaffPasswordMax,
              decoration: dec('Mật khẩu mới'),
            ),
            const SizedBox(height: 6),
            TextField(
              key: const Key('staff_pw_confirm'),
              controller: _pw2,
              obscureText: !_show,
              autocorrect: false,
              enableSuggestions: false,
              maxLength: kStaffPasswordMax,
              decoration: dec('Nhập lại mật khẩu mới'),
              onSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, key: const Key('staff_pw_error'),
                  style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13.5, height: 1.35)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          key: const Key('staff_pw_save'),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Lưu mật khẩu mới'),
        ),
      ],
    );
  }
}
