// lib/modules/bill_printer/screens/block_config_sheet.dart
// Config bottom sheet cho từng block type
// ignore_for_file: use_build_context_synchronously
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../models/bill_block.dart';
import '../providers/bill_template_provider.dart';
import '../../../core/services/vietqr_service.dart';

const _kIndigo = Color(0xFF1C2151);

class BlockConfigSheet extends ConsumerStatefulWidget {
  final BillBlock block;
  const BlockConfigSheet({super.key, required this.block});
  @override
  ConsumerState<BlockConfigSheet> createState() => _BlockConfigSheetState();
}

class _BlockConfigSheetState extends ConsumerState<BlockConfigSheet> {
  late Map<String, dynamic> _cfg;
  // ‼️ FIX BUG #2: controllers managed ở đây, không tạo mới mỗi rebuild
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _cfg = Map.from(widget.block.config);
    // Khởi tạo controller cho mọi key có giá trị String
    for (final entry in _cfg.entries) {
      if (entry.value is String) {
        _controllers[entry.key] = TextEditingController(text: entry.value as String);
      }
    }
  }

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _save() {
    ref.read(billTemplateProvider.notifier).updateBlock(widget.block.id, _cfg);
    Navigator.pop(context);
  }

  void _set(String key, dynamic value) => setState(() => _cfg[key] = value);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6, maxChildSize: 0.95, minChildSize: 0.4,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(
              color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(children: [
              Text(widget.block.type.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              const Spacer(),
              TextButton(onPressed: _save, child: const Text('Xong', style: TextStyle(color: _kIndigo, fontWeight: FontWeight.w700))),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: ListView(controller: scroll, padding: const EdgeInsets.all(20), children: _buildFields())),
        ]),
      ),
    );
  }

  List<Widget> _buildFields() {
    switch (widget.block.type) {
      case BillBlockType.shopHeader:    return _shopHeaderFields();
      case BillBlockType.shopAddress:   return _shopAddressFields();
      case BillBlockType.shopPhone:     return _shopPhoneFields();
      case BillBlockType.shopLogo:      return _shopLogoFields();
      case BillBlockType.divider:       return _dividerFields();
      case BillBlockType.orderInfo:     return _orderInfoFields();
      case BillBlockType.tableInfo:     return _tableInfoFields();
      case BillBlockType.loyaltyPoints: return _loyaltyFields();
      case BillBlockType.qrCode:        return _qrCodeFields();
      case BillBlockType.customText:    return _customTextFields();
      case BillBlockType.spacer:        return _spacerFields();
      case BillBlockType.footer:        return _footerFields();
      case BillBlockType.totals:        return _totalsFields();
      case BillBlockType.paymentMethod: return _paymentFields();
      case BillBlockType.itemsList:
      case BillBlockType.appBranding:
        return [const Text('🔒 Block bắt buộc — không thể chỉnh sửa.', style: TextStyle(color: Colors.grey))];
    }
  }

  // ── shopHeader ──
  List<Widget> _shopHeaderFields() => [
    _textField('Tên quán', 'shopName', hint: 'VD: Quán Nhỏ'),
    _textField('Tagline', 'tagline', hint: 'VD: Vị Lớn 🍜'),
    _sliderRow('Cỡ chữ', 'fontSize', 10, 24),
    _toggle('In đậm', 'bold'),
    _alignPicker('Căn lề', 'align'),
  ];

  // ── shopAddress ──
  List<Widget> _shopAddressFields() => [
    _textField('Địa chỉ', 'address', hint: 'VD: 123 Nguyễn Trãi, Q.1'),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 14),
    _alignPicker('Căn lề', 'align'),
  ];

  // ── shopPhone ──
  List<Widget> _shopPhoneFields() => [
    _textField('Nhãn', 'label', hint: 'ĐT:'),
    _textField('Số điện thoại', 'phone', hint: '0909 123 456'),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 14),
    _alignPicker('Căn lề', 'align'),
  ];

  // ── shopLogo ──
  List<Widget> _shopLogoFields() => [
    Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.amber.shade300)),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 20),
        SizedBox(width: 8),
        Expanded(child: Text(
          'Máy in nhiệt có thể in hình không rõ nét. Khuyến nghị dùng hình đen trắng, tương phản cao.',
          style: TextStyle(fontSize: 12),
        )),
      ]),
    ),
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.image_rounded, color: _kIndigo),
      title: const Text('Chọn logo từ thiết bị', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(
        _cfg['imagePath'] != null && (_cfg['imagePath'] as String).startsWith('data:image')
            ? 'Đã chọn logo tải lên'
            : 'Chưa có logo',
        style: const TextStyle(fontSize: 11),
      ),
      trailing: ElevatedButton(
        onPressed: () async {
          final picker = ImagePicker();
          final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 400);
          if (img != null) {
            final bytes = await img.readAsBytes();
            final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
            _set('imagePath', base64Str);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _kIndigo,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: const Text('Chọn ảnh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    ),
    const SizedBox(height: 12),
    _sliderRow('Chiều rộng ảnh (px)', 'width', 40, 160, isDouble: true),
    _alignPicker('Vị trí', 'align'),
  ];

  // ── divider ──
  List<Widget> _dividerFields() => [
    _label('Kiểu đường kẻ'),
    _chipGroup('style', ['solid', 'dashed', 'double'], ['Liền', 'Đứt', 'Đôi']),
    _sliderRow('Độ dày', 'thickness', 0.5, 3.0, isDouble: true),
  ];

  // ── orderInfo ──
  List<Widget> _orderInfoFields() => [
    _toggle('Hiện số đơn', 'showOrderNo'),
    _toggle('Hiện ngày giờ', 'showDate'),
    _toggle('Hiện tên thu ngân', 'showCashier'),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 14),
  ];

  // ── tableInfo ──
  List<Widget> _tableInfoFields() => [
    _toggle('Hiện tên bàn', 'showTable'),
    _textField('Nhãn', 'label', hint: 'Bàn:'),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 14),
  ];

  // ── totals ──
  List<Widget> _totalsFields() => [
    _toggle('Hiện tạm tính', 'showSubtotal'),
    _toggle('Hiện giảm giá', 'showDiscount'),
    _toggle('Hiện thuế VAT', 'showTax'),
    _toggle('In đậm tổng', 'boldTotal'),
    _sliderRow('Cỡ chữ tổng', 'totalFontSize', 10, 20),
    _sliderRow('Cỡ chữ chi tiết', 'fontSize', 8, 14),
  ];

  // ── paymentMethod ──
  List<Widget> _paymentFields() => [
    _textField('Nhãn', 'label', hint: 'Thanh toán:'),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 14),
  ];

  // ── loyaltyPoints ──
  List<Widget> _loyaltyFields() => [
    _toggle('Hiện điểm vừa cộng', 'showEarned'),
    _toggle('Hiện tổng điểm', 'showBalance'),
    _toggle('Khung viền', 'borderBox'),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 14),
  ];

  // ── qrCode ──
  List<Widget> _qrCodeFields() {
    final mode = _cfg['mode'] as String? ?? 'static';
    final currentBin = _cfg['bankBin'] as String? ?? '970422';
    final qrSource = _cfg['qrSource'] as String? ?? 'vietqr';
    return [
      _label('Nguồn mã QR'),
      _chipGroup('qrSource', ['vietqr', 'custom_image'], ['VietQR Tự động', 'Tải ảnh QR lên']),
      const SizedBox(height: 16),
      if (qrSource == 'vietqr') ...[
        _label('Chế độ QR'),
        _chipGroup('mode', ['static', 'sepay'], ['VietQR Tĩnh (Miễn phí)', 'SePay API (Tự động confirm)']),
        const SizedBox(height: 16),
        if (mode == 'static') ...[
          _label('Thông tin tài khoản'),
          _label('Ngân hàng', sub: true),
          DropdownButtonFormField<String>(
            value: currentBin,
            decoration: _inputDeco(''),
            items: VietQrService.banks.map((b) => DropdownMenuItem(
              value: b.bin,
              child: Text('${b.shortName} — ${b.fullName}', overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) { if (v != null) _set('bankBin', v); },
          ),
          const SizedBox(height: 12),
          _textField('Số tài khoản', 'accountNo', hint: '12345678901'),
          _textField('Tên chủ TK (IN HOA)', 'accountName', hint: 'NGUYEN VAN A'),
          _label('Loại VietQR'),
          _chipGroup('qrType', ['dynamic', 'static_amount'], ['QR Động (Có sẵn số tiền)', 'QR Tĩnh (Không số tiền)']),
          const SizedBox(height: 12),
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
            child: Builder(
              builder: (context) {
                final qrType = _cfg['qrType'] as String? ?? 'dynamic';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      qrType == 'dynamic'
                          ? '⚡ QR Động: Tự động điền số tiền hoá đơn & nội dung. Khách chỉ cần quét & xác nhận.'
                          : 'ℹ️ QR Tĩnh: Chỉ chứa thông tin tài khoản. Khách hàng phải tự nhập số tiền khi chuyển khoản.',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '🔗 Đăng ký hoặc tạo mã QR nhanh tại: vietqr.net',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ],
                );
              }
            ),
          ),
        ] else ...[
          _textField('SePay API Key', 'sepayApiKey', hint: 'Lấy tại sepay.vn'),
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text('✅ Tự động xác nhận thanh toán khi khách quét. Cần đăng ký tại sepay.vn', style: TextStyle(fontSize: 11)),
          ),
        ],
      ] else ...[
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.qr_code_rounded, color: _kIndigo),
          title: const Text('Chọn ảnh QR từ thiết bị', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          subtitle: Text(
            _cfg['qrImagePath'] != null && (_cfg['qrImagePath'] as String).startsWith('data:image')
                ? 'Đã chọn ảnh QR tải lên'
                : 'Chưa có ảnh QR',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: ElevatedButton(
            onPressed: () async {
              final picker = ImagePicker();
              final img = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500);
              if (img != null) {
                final bytes = await img.readAsBytes();
                final base64Str = 'data:image/png;base64,${base64Encode(bytes)}';
                _set('qrImagePath', base64Str);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _kIndigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Chọn ảnh', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 12),
      ],
      _label('Hiển thị'),
      _chipGroup('size', ['small', 'medium', 'large'], ['Nhỏ', 'Vừa', 'Lớn']),
      const SizedBox(height: 12),
      _textField('Chú thích QR', 'label', hint: 'Quét để thanh toán'),
      _toggle('Hiện chú thích', 'showLabel'),
    ];
  }

  // ── customText ──
  List<Widget> _customTextFields() => [
    _label('Nội dung'),
    TextField(
      // ‼️ FIX BUG #2: dùng controller từ map, không tạo mới mỗi rebuild
      controller: _controllers['text'] ??= TextEditingController(text: _cfg['text'] as String? ?? ''),
      maxLines: 4,
      decoration: _inputDeco('VD: Wifi: QuanNho | Pass: 123456'),
      onChanged: (v) => _set('text', v),
    ),
    const SizedBox(height: 12),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 16),
    _toggle('In đậm', 'bold'),
    _toggle('In nghiêng', 'italic'),
    _toggle('Khung viền', 'borderBox'),
    _alignPicker('Căn lề', 'align'),
  ];

  // ── spacer ──
  List<Widget> _spacerFields() => [
    _sliderRow('Chiều cao (px)', 'height', 4, 40, isDouble: true),
  ];

  // ── footer ──
  List<Widget> _footerFields() => [
    _textField('Lời chính', 'text', hint: 'Cảm ơn quý khách!'),
    _textField('Lời phụ', 'subText', hint: 'Hẹn gặp lại 🙏'),
    _sliderRow('Cỡ chữ', 'fontSize', 8, 16),
    _toggle('In đậm', 'bold'),
    _alignPicker('Căn lề', 'align'),
  ];

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _label(String text, {bool sub = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: TextStyle(
      fontWeight: sub ? FontWeight.w500 : FontWeight.w700,
      fontSize: sub ? 12 : 14, color: sub ? Colors.grey.shade700 : _kIndigo)),
  );

  // ‼️ FIX BUG #2: dùng controller từ _controllers map
  Widget _textField(String label, String key, {String hint = ''}) {
    _controllers[key] ??= TextEditingController(text: _cfg[key] as String? ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _label(label, sub: true),
        TextField(
          controller: _controllers[key],
          decoration: _inputDeco(hint),
          onChanged: (v) => _set(key, v),
        ),
      ]),
    );
  }

  Widget _toggle(String label, String key) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
      Switch(
        value: _cfg[key] as bool? ?? false,
        activeThumbColor: _kIndigo,
        onChanged: (v) => _set(key, v),
      ),
    ]),
  );

  Widget _sliderRow(String label, String key, double min, double max, {bool isDouble = false}) {
    final value = isDouble
        ? (_cfg[key] as num?)?.toDouble() ?? min
        : (_cfg[key] as int?)?.toDouble() ?? min;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: _kIndigo.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
          child: Text(isDouble ? '${value.round()}px' : '${value.round()}pt',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: _kIndigo)),
        ),
      ]),
      Slider(
        value: value.clamp(min, max),
        min: min, max: max,
        divisions: ((max - min) / 1).round().clamp(1, 100),
        activeColor: _kIndigo,
        inactiveColor: const Color(0xFFE0D8CC),
        onChanged: (v) => _set(key, isDouble ? v : v.round()),
      ),
    ]);
  }

  Widget _chipGroup(String key, List<String> values, List<String> labels) {
    final current = _cfg[key] as String? ?? values.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Wrap(spacing: 8, runSpacing: 8, children: [
        for (int i = 0; i < values.length; i++)
          GestureDetector(
            onTap: () => _set(key, values[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: current == values[i] ? _kIndigo : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: current == values[i] ? _kIndigo : Colors.grey.shade300),
              ),
              child: Text(labels[i], style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: current == values[i] ? Colors.white : Colors.grey.shade700,
              )),
            ),
          ),
      ]),
    );
  }

  // ‼️ FIX BUG #4: đổi thành Column để tránh overflow trong Row
  Widget _alignPicker(String label, String key) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _kIndigo)),
        const SizedBox(height: 6),
        _chipGroup(key, ['left', 'center', 'right'], ['Trái', 'Giữa', 'Phải']),
      ],
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.grey.shade50,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _kIndigo, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  );
}
