// lib/screens/forgot_password_sheet.dart
// ─────────────────────────────────────────────────────────────────────────────
// Màn đăng nhập (26/10): "Quên mật khẩu?" chỉ cách lấy lại mật khẩu ngay khi chưa đăng nhập được, và hộp bắt đặt
// mật khẩu mới khi đăng nhập bằng mật khẩu tạm quản trị cấp (máy chủ trả MUST_CHANGE_PASSWORD, dùng được 24 giờ).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const kHotlineDisplay = '0927 55 8888';
const kHotlineTel = '0927558888';

const _bgSheet = Color(0xFF1E1C3A);
const _orange = Color(0xFFFF6B35);

/// Bảng "Quên mật khẩu?" — nhân viên nhờ chủ quán, chủ quán gọi Hotline.
Future<void> showForgotPasswordSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: _bgSheet,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quên mật khẩu?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            const _Way(
              title: 'Bạn là nhân viên',
              text:
                  'Nhờ chủ quán mở mục Nhân viên → chọn tên bạn → bấm "Đặt lại mật khẩu", '
                  'rồi báo bạn mật khẩu mới.',
            ),
            const SizedBox(height: 12),
            const _Way(
              title: 'Bạn là chủ quán',
              text:
                  'Gọi Hotline $kHotlineDisplay (LPM Digital). Kỹ thuật viên sẽ gọi lại đúng số điện thoại đã đăng ký '
                  'để xác minh, rồi đọc cho bạn một mật khẩu tạm dùng được trong 24 giờ. '
                  'Đăng nhập bằng mật khẩu tạm, app sẽ yêu cầu bạn đặt mật khẩu mới ngay.',
            ),
            const SizedBox(height: 12),
            const _Way(
              title: 'Còn máy khác đang đăng nhập',
              text:
                  'Trên máy đó vào Cài đặt → "Gửi phản hồi", ghi cần cấp lại mật khẩu cho số điện thoại nào.',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _orange),
                icon: const Icon(Icons.call_rounded),
                label: const Text('Gọi Hotline $kHotlineDisplay'),
                onPressed: () =>
                    launchUrl(Uri(scheme: 'tel', path: kHotlineTel)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Way extends StatelessWidget {
  const _Way({required this.title, required this.text});
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _orange,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Lỗi kiểm ngay trên máy cho mật khẩu mới (null = hợp lệ). Máy chủ kiểm lại lần nữa.
String? newPasswordError(String pw, String confirm, String tempPassword) {
  if (pw.runes.length < 8 || pw.runes.length > 72) return 'Mật khẩu mới phải từ 8 đến 72 ký tự';
  if (pw != confirm) return 'Hai lần nhập mật khẩu mới không khớp';
  if (pw == tempPassword) return 'Mật khẩu mới phải khác mật khẩu tạm';
  return null;
}

/// Hộp bắt đặt mật khẩu mới sau khi đăng nhập bằng mật khẩu tạm. [submit] gửi mật khẩu mới, trả
/// {'success': bool, 'message': String}. Trả về mật khẩu mới khi đổi xong (null = người dùng bỏ qua).
Future<String?> showTempPasswordChangeDialog(
  BuildContext context, {
  required String tempPassword,
  required Future<Map<String, dynamic>> Function(String newPassword) submit,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) =>
        _TempPasswordDialog(tempPassword: tempPassword, submit: submit),
  );
}

class _TempPasswordDialog extends StatefulWidget {
  const _TempPasswordDialog({required this.tempPassword, required this.submit});
  final String tempPassword;
  final Future<Map<String, dynamic>> Function(String newPassword) submit;

  @override
  State<_TempPasswordDialog> createState() => _TempPasswordDialogState();
}

class _TempPasswordDialogState extends State<_TempPasswordDialog> {
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String _error = '';

  @override
  void dispose() {
    _pw.dispose();
    _pw2.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final err = newPasswordError(_pw.text, _pw2.text, widget.tempPassword);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final res = await widget.submit(_pw.text);
    if (!mounted) return;
    if (res['success'] == true) {
      Navigator.of(context).pop(_pw.text);
    } else {
      setState(() {
        _busy = false;
        _error = (res['message'] as String?) ?? 'Đặt mật khẩu mới thất bại';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đặt mật khẩu mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bạn vừa đăng nhập bằng mật khẩu tạm. Hãy đặt mật khẩu mới của riêng bạn (8–72 ký tự) để tiếp tục.',
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('temp_new_pw'),
              controller: _pw,
              obscureText: !_show,
              enabled: !_busy,
              decoration: InputDecoration(
                labelText: 'Mật khẩu mới',
                suffixIcon: IconButton(
                  tooltip: _show ? 'Ẩn mật khẩu' : 'Hiện mật khẩu',
                  icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
            ),
            TextField(
              key: const ValueKey('temp_new_pw2'),
              controller: _pw2,
              obscureText: !_show,
              enabled: !_busy,
              decoration: const InputDecoration(
                labelText: 'Nhập lại mật khẩu mới',
              ),
              onSubmitted: (_) => _busy ? null : _save(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(_error, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Để sau'),
        ),
        FilledButton(
          key: const ValueKey('temp_save'),
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Đang lưu…' : 'Lưu và đăng nhập'),
        ),
      ],
    );
  }
}
