import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/session_provider.dart';
import '../core/repositories/einvoice_repository.dart';
import '../core/services/store_auth_service.dart';
import '../core/services/user_auth_service.dart';

const _kNavy = Color(0xFF1E1C5E);
const _kOrange = Color(0xFFE85D20);
const _kMuted = Color(0xFF9E9085);
const _kBorder = Color(0xFFE0D8CC);
const _kGreen = Color(0xFF2E7D32);

/// Công tắc bật/tắt hóa đơn điện tử theo quán. Chỉ Chủ quán thấy và đổi được; cần PIN duyệt nhanh.
/// Tắt/bật không ảnh hưởng việc ghi bill và doanh thu, chỉ quyết định bill có vào hàng đợi phát hành hay không.
class EinvoiceSettingTile extends ConsumerStatefulWidget {
  const EinvoiceSettingTile({super.key});

  @override
  ConsumerState<EinvoiceSettingTile> createState() =>
      _EinvoiceSettingTileState();
}

class _EinvoiceSettingTileState extends ConsumerState<EinvoiceSettingTile> {
  final _repo = EinvoiceRepository();
  bool _enabled = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final v = await _repo.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = v;
      _loading = false;
    });
  }

  Future<void> _onToggle(bool next) async {
    if (_saving) return;
    final approved = await _askPin(next);
    if (approved != true || !mounted) return;
    setState(() => _saving = true);
    final err = await _repo.setEnabled(next);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err == null) {
      setState(() => _enabled = next);
      _snack(
        next ? 'Đã bật hóa đơn điện tử' : 'Đã tắt hóa đơn điện tử',
        error: false,
      );
    } else {
      _snack(switch (err) {
        'OWNER_ONLY' => 'Chỉ Chủ quán được bật/tắt hóa đơn điện tử',
        'UNAUTHENTICATED' => 'Phiên đăng nhập hết hạn, hãy đăng nhập lại',
        _ => 'Không lưu được. Kiểm tra kết nối và thử lại',
      }, error: true);
      await _load();
    }
  }

  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? const Color(0xFFC62828) : _kGreen,
      ),
    );
  }

  Future<bool?> _askPin(bool turningOn) async {
    final hasPin = await UserAuthService.hasQuickPin();
    if (!mounted) return false;
    if (!hasPin) {
      _snack(
        'Hãy thiết lập mã PIN duyệt nhanh (mục Bảo mật tài khoản) trước',
        error: true,
      );
      return false;
    }
    final info = await StoreAuthService.getStoreInfo();
    final storeId = info['store_id'] ?? '';
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (_) => _PinDialog(turningOn: turningOn, storeId: storeId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session?.isOwner != true) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _kOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.receipt_long_rounded,
            color: _kOrange,
            size: 20,
          ),
        ),
        title: const Text(
          'Hóa đơn điện tử',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _kNavy,
          ),
        ),
        subtitle: Text(
          _loading
              ? 'Đang tải...'
              : (_enabled
                    ? 'Đang bật — bill thanh toán sẽ được đưa vào hàng đợi phát hành'
                    : 'Đang tắt — bill vẫn ghi đầy đủ doanh thu, không phát hành hóa đơn'),
          style: TextStyle(
            fontSize: 12,
            color: _enabled ? _kGreen : _kMuted,
            fontWeight: _enabled ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: _saving || _loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(value: _enabled, onChanged: _onToggle),
      ),
    );
  }
}

class _PinDialog extends StatefulWidget {
  final bool turningOn;
  final String storeId;
  const _PinDialog({required this.turningOn, required this.storeId});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _ctrl = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _ctrl.text.trim();
    if (pin.length != 6) {
      setState(() => _error = 'PIN gồm đúng 6 chữ số');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final manager = await UserAuthService.verifyManagerQuickPin(
      widget.storeId,
      pin,
    );
    if (!mounted) return;
    if (manager == null) {
      setState(() {
        _busy = false;
        _error = 'PIN không đúng';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.turningOn
            ? 'Bật hóa đơn điện tử?'
            : 'Tắt hóa đơn điện tử?',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.turningOn
                ? 'Từ lúc bật, mọi bill thanh toán xong sẽ được đưa vào hàng đợi phát hành. Bill cũ không bị đổi.'
                : 'Từ lúc tắt, bill mới sẽ không được phát hành hóa đơn. Mọi bill vẫn được ghi đầy đủ vào doanh thu. Bill đã phát hành giữ nguyên.',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'Mã PIN duyệt nhanh (6 số)',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Xác nhận'),
        ),
      ],
    );
  }
}
