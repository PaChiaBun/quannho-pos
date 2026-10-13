import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/services/vietqr_service.dart';
import '../../models/qr_order_model.dart';

/// Hàm lưu do màn hình cung cấp: đọc settings mới nhất, áp [mutate], ghi lại.
/// Trả true khi lưu thành công.
typedef QrSettingsSaver =
    Future<bool> Function(
      QrOrderSettingsModel Function(QrOrderSettingsModel latest) mutate,
    );

/// Mục thu gọn "Chuyển khoản tại quầy" (VietQR): ngân hàng, số tài khoản, tên chủ TK.
class QrTransferSection extends StatefulWidget {
  final QrOrderSettingsModel settings;
  final bool enabled;
  final QrSettingsSaver onSave;

  const QrTransferSection({
    super.key,
    required this.settings,
    required this.enabled,
    required this.onSave,
  });

  @override
  State<QrTransferSection> createState() => _QrTransferSectionState();
}

class _QrTransferSectionState extends State<QrTransferSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountNoCtrl;
  late final TextEditingController _accountNameCtrl;
  String? _bankBin;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _accountNoCtrl = TextEditingController(
      text: widget.settings.transferAccountNo,
    );
    _accountNameCtrl = TextEditingController(
      text: widget.settings.transferAccountName,
    );
    _bankBin = VietQrService.findByBin(widget.settings.transferBankBin)?.bin;
  }

  @override
  void dispose() {
    _accountNoCtrl.dispose();
    _accountNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final bin = _bankBin!;
    final accountNo = _accountNoCtrl.text.trim();
    final accountName = _accountNameCtrl.text.trim().toUpperCase();
    setState(() => _saving = true);
    final ok = await widget.onSave(
      (latest) => latest.copyWith(
        transferBankBin: bin,
        transferAccountNo: accountNo,
        transferAccountName: accountName,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Đã lưu thông tin chuyển khoản.'
              : 'Không lưu được thông tin chuyển khoản. Vui lòng thử lại.',
        ),
        backgroundColor: ok ? null : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && !_saving;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: const Icon(
          Icons.account_balance_rounded,
          color: Color(0xFF8B5CF6),
        ),
        title: Text(
          'Chuyển khoản tại quầy',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'Tài khoản nhận tiền khi khách mang đi chuyển khoản (VietQR)',
          style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey.shade600),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _bankBin,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Ngân hàng nhận tiền',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final bank in VietQrService.banks)
                      DropdownMenuItem(
                        value: bank.bin,
                        child: Text(bank.shortName),
                      ),
                  ],
                  validator: (v) => (v == null || VietQrService.findByBin(v) == null)
                      ? 'Vui lòng chọn ngân hàng trong danh sách'
                      : null,
                  onChanged: enabled ? (v) => setState(() => _bankBin = v) : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _accountNoCtrl,
                  enabled: enabled,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Số tài khoản',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null; // cho phép xóa cấu hình
                    if (!RegExp(r'^\d{6,19}$').hasMatch(t)) {
                      return 'Số tài khoản gồm 6-19 chữ số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _accountNameCtrl,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Tên chủ tài khoản',
                    hintText: 'NGUYEN VAN A',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (_accountNoCtrl.text.trim().isNotEmpty &&
                        (v ?? '').trim().isEmpty) {
                      return 'Nhập tên chủ tài khoản';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: enabled ? _save : null,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_rounded, size: 18),
                    label: const Text('Lưu'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mục thu gọn "Nâng cao": tên miền tùy chỉnh. Link luôn dựng từ giá trị ĐÃ LƯU.
class QrAdvancedSection extends StatefulWidget {
  final QrOrderSettingsModel settings;
  final bool enabled;
  final QrSettingsSaver onSave;
  final Future<void> Function(String url) onTestOpen;

  const QrAdvancedSection({
    super.key,
    required this.settings,
    required this.enabled,
    required this.onSave,
    required this.onTestOpen,
  });

  @override
  State<QrAdvancedSection> createState() => _QrAdvancedSectionState();
}

class _QrAdvancedSectionState extends State<QrAdvancedSection> {
  late final TextEditingController _domainCtrl;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _domainCtrl = TextEditingController(text: widget.settings.customBaseUrl);
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    super.dispose();
  }

  Future<void> _save({bool reset = false}) async {
    final raw = reset ? '' : _domainCtrl.text.trim();
    String value = '';
    if (raw.isNotEmpty) {
      value = QrUrlBuilder.normalizeUrl(raw);
      if (!QrUrlBuilder.isValidPublicUrl(value)) {
        setState(() {
          _error =
              'Tên miền không hợp lệ. Cần https://, tên miền công khai, không có tài khoản, tham số hoặc #. Ví dụ: ${QrUrlBuilder.defaultBaseUrl}';
        });
        return;
      }
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final ok = await widget.onSave((latest) => latest.copyWith(customBaseUrl: value));
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _domainCtrl.text = value;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Đã lưu tên miền.' : 'Không lưu được tên miền. Vui lòng thử lại.'),
        backgroundColor: ok ? null : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = widget.settings.customBaseUrl.trim();
    final effective = QrUrlBuilder.resolveBaseUrl(saved);
    final enabled = widget.enabled && !_saving;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        leading: const Icon(Icons.tune_rounded, color: Color(0xFF8B5CF6)),
        title: Text(
          'Nâng cao',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          effective == null
              ? 'Tên miền đã lưu không hợp lệ - QR bị khóa'
              : 'Tên miền đang dùng: $effective',
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: effective == null ? Colors.red : Colors.grey.shade600,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextField(
            controller: _domainCtrl,
            enabled: enabled,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Tên miền tùy chỉnh (để trống = mặc định)',
              hintText: QrUrlBuilder.defaultBaseUrl,
              errorText: _error,
              errorMaxLines: 4,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: enabled && saved.isNotEmpty
                    ? () => _save(reset: true)
                    : null,
                child: const Text('Dùng mặc định'),
              ),
              OutlinedButton(
                onPressed: effective == null
                    ? null
                    : () => widget.onTestOpen(effective),
                child: const Text('Mở thử'),
              ),
              FilledButton.icon(
                onPressed: enabled ? _save : null,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Lưu'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
