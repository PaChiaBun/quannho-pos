import 'package:flutter/material.dart';

import '../core/repositories/staff_password_repository.dart';

/// Hộp "Đổi tên" nhân viên — CHỈ Chủ quán (màn Nhân viên → bảng chi tiết nhân viên).
/// Tên dùng chung mọi quán của người đó; máy chủ kiểm lại mọi điều kiện. Trả tên mới khi thành công.
Future<String?> showStaffNameDialog(
  BuildContext context, {
  required String storeId,
  required String userId,
  required String currentName,
  StaffPasswordRepository repository = const StaffPasswordRepository(),
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _StaffNameDialog(storeId: storeId, userId: userId, currentName: currentName, repository: repository),
  );
}

class _StaffNameDialog extends StatefulWidget {
  final String storeId;
  final String userId;
  final String currentName;
  final StaffPasswordRepository repository;
  const _StaffNameDialog({
    required this.storeId,
    required this.userId,
    required this.currentName,
    required this.repository,
  });

  @override
  State<_StaffNameDialog> createState() => _StaffNameDialogState();
}

class _StaffNameDialogState extends State<_StaffNameDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.currentName);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.runes.length < 2 || name.runes.length > 50) {  // máy chủ đếm theo ký tự (code point), không theo UTF-16
      setState(() => _error = staffNameErrorText('BAD_NAME'));
      return;
    }
    if (name == widget.currentName.trim()) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await widget.repository.setName(storeId: widget.storeId, userId: widget.userId, name: name);
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _saving = false;
        _error = staffNameErrorText(err);
      });
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Đổi tên nhân viên', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tên mới hiện ở danh sách nhân viên, chấm công, lương… (2–50 ký tự).',
            style: TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF5F5A55)),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('staff_name_input'),
            controller: _name,
            autofocus: true,
            maxLength: 50,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Tên nhân viên',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!, key: const Key('staff_name_error'),
                style: const TextStyle(color: Color(0xFFB3261E), fontSize: 13.5, height: 1.35)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Huỷ')),
        FilledButton(
          key: const Key('staff_name_save'),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Lưu tên'),
        ),
      ],
    );
  }
}
