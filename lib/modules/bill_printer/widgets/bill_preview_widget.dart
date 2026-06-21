// lib/modules/bill_printer/widgets/bill_preview_widget.dart
// Real-time Flutter widget preview của hoá đơn
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill_block.dart';
import '../models/bill_block_template.dart';
import '../../../core/services/vietqr_service.dart';

const _kSampleItems = [
  ('Phở Bò Đặc Biệt', 2, 85000.0),
  ('Cà Phê Sữa Đá',   1, 30000.0),
  ('Bánh Mì Thịt',    1, 25000.0),
];

class BillPreviewWidget extends StatelessWidget {
  final BillBlockTemplate tpl;
  const BillPreviewWidget({super.key, required this.tpl});


  @override
  Widget build(BuildContext context) {
    final widthFactor = tpl.paperSize == '58mm' ? 0.60
        : tpl.paperSize == 'a4' ? 1.0 : 0.80;
    final subtotal = _kSampleItems.fold(0.0, (s, e) => s + e.$2 * e.$3);
    const discount = 15000.0;
    final total = subtotal - discount;

    return Container(
      color: const Color(0xFFE8EAF2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: widthFactor,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 16, offset: const Offset(0, 4))],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...tpl.blocks.where((b) => b.enabled).map((b) => _renderBlock(b, subtotal, discount, total)),
                  // ── Branding bắt buộc: Quán Nhỏ POS ──
                  if (!tpl.blocks.any((b) => b.type == BillBlockType.appBranding && b.enabled))
                    const _AppBrandingWidget(),
                  // Cắt giấy
                  const SizedBox(height: 8),
                  Row(children: List.generate(30, (i) => Expanded(
                    child: Container(height: 1,
                        color: i % 2 == 0 ? Colors.black : Colors.transparent)))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _renderBlock(BillBlock b, double subtotal, double discount, double total) {
    switch (b.type) {
      case BillBlockType.shopHeader:
        return _ShopHeader(b: b);
      case BillBlockType.shopLogo:
        return _ShopLogo(b: b);
      case BillBlockType.shopAddress:
        return _ShopAddress(b: b);
      case BillBlockType.shopPhone:
        return _ShopPhone(b: b);
      case BillBlockType.divider:
        return _Divider(b: b);
      case BillBlockType.orderInfo:
        return _OrderInfo(b: b);
      case BillBlockType.tableInfo:
        return _TableInfo(b: b);
      case BillBlockType.itemsList:
        return _ItemsList(b: b);
      case BillBlockType.totals:
        return _Totals(b: b, subtotal: subtotal, discount: discount, total: total);
      case BillBlockType.paymentMethod:
        return _PaymentMethod(b: b);
      case BillBlockType.loyaltyPoints:
        return _LoyaltyPoints(b: b, total: total);
      case BillBlockType.qrCode:
        return _QrCode(b: b, amount: total);
      case BillBlockType.customText:
        return _CustomText(b: b);
      case BillBlockType.spacer:
        return SizedBox(height: b.cfg<double>('height', 8.0));
      case BillBlockType.footer:
        return _Footer(b: b);
      case BillBlockType.appBranding:
        return const _AppBrandingWidget();
    }
  }
}

// ─── Block Renderers ──────────────────────────────────────────────────────────

class _ShopHeader extends StatelessWidget {
  final BillBlock b;
  const _ShopHeader({required this.b});
  @override
  Widget build(BuildContext context) {
    final name = b.cfg<String>('shopName', '').isEmpty ? 'Tên Quán' : b.cfg<String>('shopName', '');
    final tagline = b.cfg<String>('tagline', '');
    final fs = b.cfg<int>('fontSize', 16).toDouble();
    final bold = b.cfg<bool>('bold', true);
    final align = _textAlign(b.cfg<String>('align', 'center'));
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(children: [
        Text(name, textAlign: align,
          style: TextStyle(fontSize: fs, fontWeight: bold ? FontWeight.w900 : FontWeight.normal)),
        if (tagline.isNotEmpty)
          Text(tagline, textAlign: align,
            style: TextStyle(fontSize: fs - 4, color: Colors.grey.shade600)),
      ]),
    );
  }
}

class _ShopLogo extends StatelessWidget {
  final BillBlock b;
  const _ShopLogo({required this.b});
  @override
  Widget build(BuildContext context) {
    final path = b.cfg<String>('imagePath', '');
    final width = b.cfg<double>('width', 80.0);
    final align = b.cfg<String>('align', 'center');
    Widget logo = path.isEmpty
        ? Container(width: width, height: width * 0.6,
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
            child: const Icon(Icons.image_outlined, color: Colors.grey))
        : Image.asset(path, width: width, fit: BoxFit.contain);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: align == 'center' ? Alignment.center : align == 'right' ? Alignment.centerRight : Alignment.centerLeft,
        child: logo,
      ),
    );
  }
}

class _ShopAddress extends StatelessWidget {
  final BillBlock b;
  const _ShopAddress({required this.b});
  @override
  Widget build(BuildContext context) {
    final addr = b.cfg<String>('address', '').isEmpty ? '123 Đường ABC, Quận 1' : b.cfg<String>('address', '');
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    return Text(addr, textAlign: _textAlign(b.cfg<String>('align', 'center')),
      style: TextStyle(fontSize: fs, color: Colors.grey.shade600));
  }
}

class _ShopPhone extends StatelessWidget {
  final BillBlock b;
  const _ShopPhone({required this.b});
  @override
  Widget build(BuildContext context) {
    final phone = b.cfg<String>('phone', '').isEmpty ? '0909 123 456' : b.cfg<String>('phone', '');
    final label = b.cfg<String>('label', 'ĐT:');
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    return Text('$label $phone', textAlign: _textAlign(b.cfg<String>('align', 'center')),
      style: TextStyle(fontSize: fs, color: Colors.grey.shade600));
  }
}

class _Divider extends StatelessWidget {
  final BillBlock b;
  const _Divider({required this.b});
  @override
  Widget build(BuildContext context) {
    final style = b.cfg<String>('style', 'solid');
    final thickness = b.cfg<double>('thickness', 1.0);
    if (style == 'dashed') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: List.generate(30, (i) => Expanded(
          child: Container(height: thickness,
              color: i % 2 == 0 ? Colors.black : Colors.transparent)))),
      );
    }
    if (style == 'double') {
      return Column(children: [
        Divider(thickness: thickness * 0.5, height: 6),
        Divider(thickness: thickness, height: 6),
      ]);
    }
    return Divider(thickness: thickness, height: 10, color: Colors.black87);
  }
}

class _OrderInfo extends StatelessWidget {
  final BillBlock b;
  const _OrderInfo({required this.b});
  @override
  Widget build(BuildContext context) {
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2,'0')}/${now.month.toString().padLeft(2,'0')}/${now.year} '
        '${now.hour.toString().padLeft(2,'0')}:${now.minute.toString().padLeft(2,'0')}';
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('HÓA ĐƠN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs + 1)),
        Text('#QN-20260513-018', style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs + 1)),
      ]),
      if (b.cfg<bool>('showDate', true))
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Ngày:', style: TextStyle(fontSize: fs)),
          Text(date, style: TextStyle(fontSize: fs)),
        ]),
      if (b.cfg<bool>('showCashier', true))
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Thu ngân:', style: TextStyle(fontSize: fs)),
          Text('Nguyễn Thu', style: TextStyle(fontSize: fs)),
        ]),
    ]);
  }
}

class _TableInfo extends StatelessWidget {
  final BillBlock b;
  const _TableInfo({required this.b});
  @override
  Widget build(BuildContext context) {
    final label = b.cfg<String>('label', 'Bàn:');
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(fontSize: fs)),
      Text('Bàn 5', style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ItemsList extends StatelessWidget {
  final BillBlock b;
  const _ItemsList({required this.b});
  static final _fmt = NumberFormat('#,###', 'vi_VN');
  static String _m(double v) => '${_fmt.format(v.round())}đ';
  @override
  Widget build(BuildContext context) {
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    return Column(children: [
      Row(children: [
        Expanded(flex: 4, child: Text('Món', style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs - 1))),
        Text('SL', style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs - 1)),
        const SizedBox(width: 12),
        Text('T.Tiền', style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs - 1)),
      ]),
      ..._kSampleItems.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Expanded(flex: 4, child: Text(item.$1, style: TextStyle(fontSize: fs - 1))),
          Text('×${item.$2}', style: TextStyle(fontSize: fs - 1)),
          const SizedBox(width: 8),
          Text(_m(item.$2 * item.$3), style: TextStyle(fontSize: fs - 1)),
        ]),
      )),
    ]);
  }
}

class _Totals extends StatelessWidget {
  final BillBlock b;
  final double subtotal, discount, total;
  const _Totals({required this.b, required this.subtotal, required this.discount, required this.total});
  static final _fmt = NumberFormat('#,###', 'vi_VN');
  static String _m(double v) => '${_fmt.format(v.round())}đ';
  @override
  Widget build(BuildContext context) {
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    final tfs = b.cfg<int>('totalFontSize', 14).toDouble();
    final bold = b.cfg<bool>('boldTotal', true);
    return Column(children: [
      if (b.cfg<bool>('showSubtotal', true))
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Tạm tính:', style: TextStyle(fontSize: fs)),
          Text(_m(subtotal), style: TextStyle(fontSize: fs)),
        ]),
      if (b.cfg<bool>('showDiscount', true) && discount > 0)
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Giảm giá:', style: TextStyle(fontSize: fs)),
          Text('-${_m(discount)}', style: TextStyle(fontSize: fs, color: Colors.red.shade600)),
        ]),
      const SizedBox(height: 4),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('TỔNG CỘNG:', style: TextStyle(fontSize: tfs - 2, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        Text(_m(total), style: TextStyle(fontSize: tfs, fontWeight: bold ? FontWeight.w900 : FontWeight.normal)),
      ]),
    ]);
  }
}

class _PaymentMethod extends StatelessWidget {
  final BillBlock b;
  const _PaymentMethod({required this.b});
  @override
  Widget build(BuildContext context) {
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(b.cfg<String>('label', 'Thanh toán:'), style: TextStyle(fontSize: fs)),
      Text('Tiền mặt', style: TextStyle(fontSize: fs, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _LoyaltyPoints extends StatelessWidget {
  final BillBlock b;
  final double total;
  const _LoyaltyPoints({required this.b, required this.total});
  @override
  Widget build(BuildContext context) {
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    final border = b.cfg<bool>('borderBox', true);
    final earned = (total / 10000).round();
    Widget content = Column(children: [
      if (b.cfg<bool>('showEarned', true))
        Text('⭐ Cộng $earned điểm thưởng',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: fs)),
      if (b.cfg<bool>('showBalance', true))
        Text('Tổng điểm: 156 điểm', style: TextStyle(fontSize: fs - 1, color: Colors.grey.shade600)),
    ]);
    if (border) {
      content = Container(
        width: double.infinity, padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6)),
        child: content,
      );
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: content);
  }
}

class _QrCode extends StatelessWidget {
  final BillBlock b;
  final double amount;
  const _QrCode({required this.b, required this.amount});
  @override
  Widget build(BuildContext context) {
    final mode = b.cfg<String>('mode', 'static');
    final bin = b.cfg<String>('bankBin', '970422');
    final accNo = b.cfg<String>('accountNo', '');
    final accName = b.cfg<String>('accountName', '');
    final label = b.cfg<String>('label', 'Quét để thanh toán');
    final showLabel = b.cfg<bool>('showLabel', true);
    final size = b.cfg<String>('size', 'medium') == 'small' ? 80.0
        : b.cfg<String>('size', 'medium') == 'large' ? 140.0 : 110.0;

    Widget qrWidget;
    if (mode == 'static' && accNo.isNotEmpty) {
      final url = VietQrService.generateUrl(
        bankBin: bin, accountNo: accNo,
        accountName: accName, amount: amount, addInfo: 'QN-20260513-018');
      qrWidget = Image.network(url, width: size, height: size, fit: BoxFit.contain,
        errorBuilder: (ctx, err, stack) => _QrPlaceholder(size: size));
    } else {
      qrWidget = _QrPlaceholder(size: size);
    }

    final bank = VietQrService.findByBin(bin);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(children: [
        qrWidget,
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
          if (mode == 'static' && bank != null)
            Text(bank.shortName, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ]),
    );
  }
}

class _QrPlaceholder extends StatelessWidget {
  final double size;
  const _QrPlaceholder({required this.size});
  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.qr_code_2_rounded, size: size * 0.5, color: Colors.grey.shade400),
      const Text('QR Code', style: TextStyle(fontSize: 9, color: Colors.grey)),
    ]),
  );
}

class _CustomText extends StatelessWidget {
  final BillBlock b;
  const _CustomText({required this.b});
  @override
  Widget build(BuildContext context) {
    final text = b.cfg<String>('text', '');
    final fs = b.cfg<int>('fontSize', 10).toDouble();
    final bold = b.cfg<bool>('bold', false);
    final italic = b.cfg<bool>('italic', false);
    final border = b.cfg<bool>('borderBox', false);
    final align = _textAlign(b.cfg<String>('align', 'center'));
    Widget content = Text(text.isEmpty ? '(Văn bản trống)' : text,
      textAlign: align,
      style: TextStyle(
        fontSize: fs,
        fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        color: text.isEmpty ? Colors.grey.shade400 : Colors.black87,
      ),
    );
    if (border) {
      content = Container(
        width: double.infinity, padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(6)),
        child: content,
      );
    }
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: content);
  }
}

class _Footer extends StatelessWidget {
  final BillBlock b;
  const _Footer({required this.b});
  @override
  Widget build(BuildContext context) {
    final text = b.cfg<String>('text', 'Cảm ơn quý khách!');
    final sub = b.cfg<String>('subText', 'Hẹn gặp lại 🙏');
    final fs = b.cfg<int>('fontSize', 12).toDouble();
    final bold = b.cfg<bool>('bold', true);
    final align = _textAlign(b.cfg<String>('align', 'center'));
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(children: [
        Text(text.isEmpty ? 'Cảm ơn quý khách!' : text, textAlign: align,
          style: TextStyle(fontSize: fs, fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        if (sub.isNotEmpty)
          Text(sub, textAlign: align,
            style: TextStyle(fontSize: fs - 2, color: Colors.grey.shade500)),
      ]),
    );
  }
}

// ─── Helper ───────────────────────────────────────────────────────────────────
TextAlign _textAlign(String align) {
  switch (align) {
    case 'right':  return TextAlign.right;
    case 'left':   return TextAlign.left;
    default:       return TextAlign.center;
  }
}

// ─── App Branding — bắt buộc, không thể xoá ──────────────────────────────────
class _AppBrandingWidget extends StatelessWidget {
  const _AppBrandingWidget();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Column(children: [
        Container(
          height: 0.5,
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          color: Colors.grey.shade300,
        ),
        Text('Powered by Quán Nhỏ POS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 8,
            color: Colors.grey.shade500,
            letterSpacing: 0.3,
          ),
        ),
      ]),
    );
  }
}
