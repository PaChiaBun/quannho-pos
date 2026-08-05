import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/pos_device_token_service.dart';

/// Card Quản lý POS Device Token Session (Architecture V3)
/// Cho phép kích hoạt thiết bị đầu tiên, ghép thiết bị, làm mới session và thu hồi phiên.
/// Tuyệt đối KHÔNG hiển thị raw token hoặc credential!
class PosDeviceSessionCard extends StatefulWidget {
  const PosDeviceSessionCard({super.key});

  @override
  State<PosDeviceSessionCard> createState() => _PosDeviceSessionCardState();
}

class _PosDeviceSessionCardState extends State<PosDeviceSessionCard> {
  String _status =
      'loading'; // 'not_activated', 'active', 'expired', 'auth_error'
  String? _deviceId;
  String? _storeCode;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    final status = await PosDeviceTokenService.getDeviceSessionStatus();
    final deviceId = await PosDeviceTokenService.getDeviceId();
    final storeCode = await PosDeviceTokenService.getStoreCode();

    if (!mounted) return;
    setState(() {
      _status = status;
      _deviceId = deviceId;
      _storeCode = storeCode;
      _loading = false;
    });
  }

  // Dialog Bootstrap Thiết bị đầu tiên
  Future<void> _showBootstrapDialog() async {
    final storeCodeCtrl = TextEditingController(text: _storeCode ?? '');
    final credentialCtrl = TextEditingController();
    final deviceNameCtrl = TextEditingController(text: 'POS Máy Chính');
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Kích hoạt thiết bị đầu tiên',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: storeCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mã Quán (VD: QN-1234)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: credentialCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mật khẩu/PIN Chủ quán',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deviceNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên thiết bị POS',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      setDlgState(() => submitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final res =
                          await PosDeviceTokenService.bootstrapFirstDevice(
                            storeCode: storeCodeCtrl.text,
                            credential: credentialCtrl.text,
                            deviceName: deviceNameCtrl.text,
                          );
                      if (ctx.mounted) {
                        setDlgState(() => submitting = false);
                        Navigator.pop(ctx);
                      }

                      if (res['success'] == true) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Kích hoạt thiết bị POS đầu tiên thành công!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              res['message'] ?? 'Kích hoạt thất bại',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      _refreshStatus();
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Kích hoạt'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog Ghép thiết bị bổ sung
  Future<void> _showPairDialog() async {
    final storeCodeCtrl = TextEditingController(text: _storeCode ?? '');
    final pairCodeCtrl = TextEditingController();
    final deviceNameCtrl = TextEditingController(text: 'POS Nhân Viên');
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Ghép nối thiết bị mới',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: storeCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mã Quán (VD: QN-1234)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pairCodeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Mã ghép nối 6 số',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: deviceNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tên thiết bị POS',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      setDlgState(() => submitting = true);
                      final messenger = ScaffoldMessenger.of(context);
                      final res = await PosDeviceTokenService.pairDevice(
                        storeCode: storeCodeCtrl.text,
                        pairingCode: pairCodeCtrl.text,
                        deviceName: deviceNameCtrl.text,
                      );
                      if (ctx.mounted) {
                        setDlgState(() => submitting = false);
                        Navigator.pop(ctx);
                      }

                      if (res['success'] == true) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ghép nối thiết bị POS thành công! Vui lòng nhập PIN để đăng nhập phiên.',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              res['message'] ?? 'Ghép nối thất bại',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      _refreshStatus();
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Ghép nối'),
            ),
          ],
        ),
      ),
    );
  }

  // Dialog Đăng nhập / Cấp lại Session Token khi hết hạn
  Future<void> _showIssueSessionDialog() async {
    final storeCodeCtrl = TextEditingController(text: _storeCode ?? '');
    final pinCtrl = TextEditingController();
    String authMode = 'staff_pin';
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Đăng nhập phiên POS',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: storeCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Mã Quán',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: authMode,
                  decoration: const InputDecoration(
                    labelText: 'Chế độ đăng nhập',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'staff_pin',
                      child: Text('Mã PIN Nhân viên'),
                    ),
                    DropdownMenuItem(
                      value: 'manager_quick_pin',
                      child: Text('Quick PIN Quản lý'),
                    ),
                  ],
                  onChanged: (v) =>
                      setDlgState(() => authMode = v ?? 'staff_pin'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nhập mã PIN',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              onPressed: submitting
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final devId =
                          _deviceId ??
                          await PosDeviceTokenService.getDeviceId();
                      if (devId == null || devId.isEmpty) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Thiết bị chưa được ghép nối! Vui lòng ghép thiết bị trước.',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setDlgState(() => submitting = true);
                      final res = await PosDeviceTokenService.issueSession(
                        storeCode: storeCodeCtrl.text,
                        authMode: authMode,
                        credential: pinCtrl.text,
                        deviceId: devId,
                      );
                      if (ctx.mounted) {
                        setDlgState(() => submitting = false);
                        Navigator.pop(ctx);
                      }

                      if (res['success'] == true) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Đăng nhập phiên POS thành công!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              res['message'] ?? 'Đăng nhập phiên thất bại',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                      _refreshStatus();
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Đăng nhập phiên'),
            ),
          ],
        ),
      ),
    );
  }

  // Thu hồi phiên POS
  Future<void> _handleRevoke() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thu hồi phiên POS?'),
        content: const Text(
          'Xác nhận thu hồi session token của thiết bị này trên server?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Thu hồi'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    await PosDeviceTokenService.revokeSession();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã thu hồi phiên POS token!')),
    );
    _refreshStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _colorForStatus(_status).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.phonelink_setup_rounded,
                    color: _colorForStatus(_status),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thiết Bị Nhận Đơn QR (POS Session)',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        _labelForStatus(_status),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: _colorForStatus(_status),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _loading ? null : _refreshStatus,
                  tooltip: 'Làm mới trạng thái',
                ),
              ],
            ),
            if (_deviceId != null && _deviceId!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Device ID: ${_deviceId!.substring(0, 8)}...',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_status == 'not_activated') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(
                      Icons.power_settings_new_rounded,
                      size: 16,
                    ),
                    label: const Text('Kích hoạt máy chính'),
                    onPressed: _showBootstrapDialog,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                    label: const Text('Ghép thiết bị'),
                    onPressed: _showPairDialog,
                  ),
                ] else if (_status == 'expired' || _status == 'auth_error') ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade900,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.lock_clock_rounded, size: 16),
                    label: const Text('Đăng nhập PIN phiên mới'),
                    onPressed: _showIssueSessionDialog,
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: const Text('Ghép lại thiết bị'),
                    onPressed: _showPairDialog,
                  ),
                ] else ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Làm mới Session Token'),
                    onPressed: _showIssueSessionDialog,
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    icon: const Icon(Icons.no_cell_rounded, size: 16),
                    label: const Text('Thu hồi phiên'),
                    onPressed: _handleRevoke,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'expired':
        return Colors.orange;
      case 'auth_error':
        return Colors.red;
      case 'not_activated':
      default:
        return Colors.grey;
    }
  }

  String _labelForStatus(String status) {
    switch (status) {
      case 'active':
        return '🟢 Đang hoạt động hợp lệ';
      case 'expired':
        return '🟠 Phiên hết hạn (Cần nhập lại PIN)';
      case 'auth_error':
        return '🔴 Lỗi xác thực POS Session';
      case 'not_activated':
      default:
        return '⚪ Chưa kích hoạt thiết bị POS';
    }
  }
}
