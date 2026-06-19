// lib/modules/bill_printer/data/bill_presets.dart
// Định nghĩa các mẫu hoá đơn & phiếu bếp dựng sẵn
import 'package:uuid/uuid.dart';
import '../models/bill_block.dart';
import '../models/bill_block_template.dart';
import '../providers/kitchen_ticket_template_provider.dart';

const _uuid = Uuid();
BillBlock _b(BillBlockType t, Map<String, dynamic> c, {bool on = true}) =>
    BillBlock(id: _uuid.v4(), type: t, enabled: on, config: c);

// ─── Mẫu Hoá Đơn ─────────────────────────────────────────────────────────────
class BillPreset {
  final String id;
  final String name;
  final String tag;        // "Phổ biến" | "Café" | "Nhà hàng" | "Takeaway"...
  final String description;
  final BillBlockTemplate template;

  const BillPreset({
    required this.id, required this.name, required this.tag,
    required this.description, required this.template,
  });
}

List<BillPreset> get billPresets => [
  BillPreset(
    id: 'minimal_58',
    name: 'Tối Giản',
    tag: 'Nhanh',
    description: 'Tên quán, món, tổng tiền. In nhanh nhất.',
    template: BillBlockTemplate(paperSize: '58mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'', 'fontSize':14, 'bold':true, 'align':'center'}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':0.5}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':false,'fontSize':9}),
      _b(BillBlockType.tableInfo,    {'showTable':true,'label':'Bàn:','fontSize':9}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':9}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':0.5}),
      _b(BillBlockType.totals,       {'showSubtotal':false,'showDiscount':true,'boldTotal':true,'totalFontSize':13,'fontSize':9}),
      _b(BillBlockType.footer,       {'text':'Cảm ơn!','subText':'','fontSize':10,'align':'center','bold':true}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'standard_80',
    name: 'Tiêu Chuẩn',
    tag: 'Phổ biến',
    description: 'Đầy đủ địa chỉ, SĐT, tên bàn, điểm thưởng.',
    template: BillBlockTemplate.defaultTemplate(),
  ),
  BillPreset(
    id: 'full_80',
    name: 'Chuyên Nghiệp',
    tag: 'Nhà hàng',
    description: 'Đầy đủ nhất: QR, điểm thưởng, lời cảm ơn trang trọng.',
    template: BillBlockTemplate(paperSize: '80mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'', 'tagline':'Chào mừng quý khách', 'fontSize':16,'bold':true,'align':'center'}),
      _b(BillBlockType.shopAddress,  {'address':'','fontSize':10,'align':'center'}),
      _b(BillBlockType.shopPhone,    {'phone':'','fontSize':10,'align':'center','label':'ĐT:'}),
      _b(BillBlockType.divider,      {'style':'double','thickness':1.0}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':true,'fontSize':10}),
      _b(BillBlockType.tableInfo,    {'showTable':true,'label':'Bàn:','fontSize':10}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.8}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.totals,       {'showSubtotal':true,'showDiscount':true,'boldTotal':true,'totalFontSize':14,'fontSize':10}),
      _b(BillBlockType.paymentMethod,{'label':'Thanh toán:','fontSize':10}),
      _b(BillBlockType.loyaltyPoints,{'showEarned':true,'borderBox':true,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':0.5}),
      _b(BillBlockType.footer,       {'text':'Cảm ơn quý khách!','subText':'Hẹn gặp lại 🙏','fontSize':12,'align':'center','bold':true}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'cafe_58',
    name: 'Quán Café',
    tag: 'Café',
    description: '58mm gọn nhẹ, phong cách café hiện đại.',
    template: BillBlockTemplate(paperSize: '58mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'', 'tagline':'☕ Good coffee, Good day', 'fontSize':13,'bold':true,'align':'center'}),
      _b(BillBlockType.shopPhone,    {'phone':'','fontSize':9,'align':'center','label':'📞'}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':false,'fontSize':9}),
      _b(BillBlockType.tableInfo,    {'showTable':true,'label':'Order:','fontSize':9}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':9}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':0.5}),
      _b(BillBlockType.totals,       {'showSubtotal':false,'showDiscount':true,'boldTotal':true,'totalFontSize':12,'fontSize':9}),
      _b(BillBlockType.footer,       {'text':'Thanks! See you soon ☕','subText':'','fontSize':10,'align':'center','bold':false}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'takeaway_58',
    name: 'Mang Đi',
    tag: 'Takeaway',
    description: 'Tập trung tên khách, số đơn to để giao đúng túi.',
    template: BillBlockTemplate(paperSize: '58mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'','fontSize':13,'bold':true,'align':'center'}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.customText,   {'text':'🛵 MANG ĐI','fontSize':14,'bold':true,'align':'center','borderBox':false}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':false,'fontSize':9}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':false,'showQty':true,'showTotal':false,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.totals,       {'showSubtotal':false,'showDiscount':true,'boldTotal':true,'totalFontSize':13,'fontSize':9}),
      _b(BillBlockType.paymentMethod,{'label':'TT:','fontSize':9}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'foodcourt_80',
    name: 'Food Court',
    tag: 'Chuỗi',
    description: 'Phù hợp chuỗi, food court: mã đơn nổi bật, in nhanh.',
    template: BillBlockTemplate(paperSize: '80mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'','fontSize':15,'bold':true,'align':'center'}),
      _b(BillBlockType.shopAddress,  {'address':'','fontSize':9,'align':'center'}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':true,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.totals,       {'showSubtotal':true,'showDiscount':true,'boldTotal':true,'totalFontSize':14,'fontSize':10}),
      _b(BillBlockType.paymentMethod,{'label':'Thanh toán:','fontSize':10}),
      _b(BillBlockType.footer,       {'text':'Cảm ơn!','subText':'','fontSize':10,'align':'center','bold':false}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'qr_80',
    name: 'QR Thanh Toán',
    tag: 'Cashless',
    description: 'Tích hợp QR chuyển khoản, không cần tiền mặt.',
    template: BillBlockTemplate(paperSize: '80mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'','fontSize':15,'bold':true,'align':'center'}),
      _b(BillBlockType.shopAddress,  {'address':'','fontSize':10,'align':'center'}),
      _b(BillBlockType.shopPhone,    {'phone':'','fontSize':10,'align':'center','label':'ĐT:'}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':true,'fontSize':10}),
      _b(BillBlockType.tableInfo,    {'showTable':true,'label':'Bàn:','fontSize':10}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.totals,       {'showSubtotal':true,'showDiscount':true,'boldTotal':true,'totalFontSize':14,'fontSize':10}),
      _b(BillBlockType.qrCode,       {'mode':'static','accountNo':'','accountName':'','size':'medium','label':'Quét để thanh toán','showLabel':true}),
      _b(BillBlockType.footer,       {'text':'Cảm ơn quý khách!','subText':'','fontSize':11,'align':'center','bold':true}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'loyalty_80',
    name: 'Tích Điểm',
    tag: 'Loyalty',
    description: 'Nhấn mạnh điểm thưởng, khuyến khích khách quay lại.',
    template: BillBlockTemplate(paperSize: '80mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'','tagline':'Tích điểm - Nhận quà','fontSize':15,'bold':true,'align':'center'}),
      _b(BillBlockType.shopPhone,    {'phone':'','fontSize':10,'align':'center','label':'ĐT:'}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':true,'fontSize':10}),
      _b(BillBlockType.tableInfo,    {'showTable':true,'label':'Bàn:','fontSize':10}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.totals,       {'showSubtotal':true,'showDiscount':true,'boldTotal':true,'totalFontSize':14,'fontSize':10}),
      _b(BillBlockType.paymentMethod,{'label':'Thanh toán:','fontSize':10}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.loyaltyPoints,{'showEarned':true,'showBalance':true,'borderBox':true,'fontSize':11}),
      _b(BillBlockType.footer,       {'text':'🎁 Tích đủ điểm - Đổi ưu đãi!','subText':'Cảm ơn quý khách','fontSize':11,'align':'center','bold':true}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'elegant_a4',
    name: 'Sang Trọng A4',
    tag: 'Fine dining',
    description: 'Khổ A4 cho nhà hàng cao cấp, in máy văn phòng.',
    template: BillBlockTemplate(paperSize: 'a4', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'','tagline':'','fontSize':20,'bold':true,'align':'center'}),
      _b(BillBlockType.shopAddress,  {'address':'','fontSize':12,'align':'center'}),
      _b(BillBlockType.shopPhone,    {'phone':'','fontSize':12,'align':'center','label':'Tel:'}),
      _b(BillBlockType.spacer,       {'height':10.0}),
      _b(BillBlockType.divider,      {'style':'double','thickness':1.0}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':true,'fontSize':12}),
      _b(BillBlockType.tableInfo,    {'showTable':true,'label':'Bàn số:','fontSize':12}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':12}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.totals,       {'showSubtotal':true,'showDiscount':true,'showTax':true,'boldTotal':true,'totalFontSize':16,'fontSize':12}),
      _b(BillBlockType.paymentMethod,{'label':'Phương thức:','fontSize':12}),
      _b(BillBlockType.spacer,       {'height':16.0}),
      _b(BillBlockType.footer,       {'text':'Trân trọng cảm ơn Quý khách!','subText':'Hân hạnh được phục vụ','fontSize':14,'align':'center','bold':true}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
  BillPreset(
    id: 'wifi_promo',
    name: 'Có WiFi & KM',
    tag: 'Café / Quán',
    description: 'Hiển thị WiFi, khuyến mãi cuối bill.',
    template: BillBlockTemplate(paperSize: '80mm', blocks: [
      _b(BillBlockType.shopHeader,   {'shopName':'','fontSize':15,'bold':true,'align':'center'}),
      _b(BillBlockType.shopAddress,  {'address':'','fontSize':10,'align':'center'}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':0.8}),
      _b(BillBlockType.orderInfo,    {'showOrderNo':true,'showDate':true,'showCashier':true,'fontSize':10}),
      _b(BillBlockType.tableInfo,    {'showTable':true,'label':'Bàn:','fontSize':10}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.itemsList,    {'showPrice':true,'showQty':true,'showTotal':true,'fontSize':10}),
      _b(BillBlockType.divider,      {'style':'solid','thickness':1.0}),
      _b(BillBlockType.totals,       {'showSubtotal':true,'showDiscount':true,'boldTotal':true,'totalFontSize':14,'fontSize':10}),
      _b(BillBlockType.paymentMethod,{'label':'Thanh toán:','fontSize':10}),
      _b(BillBlockType.divider,      {'style':'dashed','thickness':0.5}),
      _b(BillBlockType.customText,   {'text':'📶 WiFi: QuanNho_5G  Pass: 12345678','fontSize':10,'bold':false,'align':'center','borderBox':true}),
      _b(BillBlockType.customText,   {'text':'🎁 Mua 5 ly tặng 1 ly — xuất trình bill này','fontSize':9,'bold':false,'align':'center','borderBox':false}),
      _b(BillBlockType.footer,       {'text':'Cảm ơn quý khách!','subText':'','fontSize':10,'align':'center','bold':true}),
      _b(BillBlockType.appBranding,   {'fontSize':8,'align':'center'}),
    ]),
  ),
];

// ─── Mẫu Phiếu Bếp ───────────────────────────────────────────────────────────
class KitchenPreset {
  final String id;
  final String name;
  final String tag;
  final String description;
  final KitchenTicketTemplate template;

  const KitchenPreset({
    required this.id, required this.name, required this.tag,
    required this.description, required this.template,
  });
}

const List<KitchenPreset> kitchenPresets = [
  KitchenPreset(
    id: 'standard_kitchen',
    name: 'Bếp Tiêu Chuẩn',
    tag: 'Phổ biến',
    description: 'Font cân đối, đủ tên bàn + ghi chú.',
    template: KitchenTicketTemplate(),
  ),
  KitchenPreset(
    id: 'large_font',
    name: 'Font Siêu To',
    tag: 'Dễ đọc',
    description: 'Số lượng & tên món cực to, bếp nhìn xa vẫn đọc rõ.',
    template: KitchenTicketTemplate(
      headerFontSize: 22, tableFontSize: 20, itemFontSize: 18, qtyFontSize: 28,
    ),
  ),
  KitchenPreset(
    id: 'compact_kitchen_58',
    name: 'Gọn Nhẹ 58mm',
    tag: 'Nhỏ gọn',
    description: 'Máy in cầm tay, chữ to để bù khổ nhỏ.',
    template: KitchenTicketTemplate(
      paperSize: '58mm', headerFontSize: 20, tableFontSize: 18,
      itemFontSize: 16, qtyFontSize: 24,
    ),
  ),
  KitchenPreset(
    id: 'bar_counter',
    name: 'Bar Nước',
    tag: 'Bar',
    description: 'Tiêu đề BAR NƯỚC, ẩn ghi chú không cần thiết.',
    template: KitchenTicketTemplate(
      headerText: 'BAR NƯỚC', headerFontSize: 20,
      tableFontSize: 16, itemFontSize: 14, qtyFontSize: 22,
      showNote: false, showDateTime: false,
    ),
  ),
  KitchenPreset(
    id: 'hot_kitchen',
    name: 'Bếp Nóng',
    tag: 'Bếp nóng',
    description: 'Tiêu đề BẾP NÓNG, số lượng nổi bật.',
    template: KitchenTicketTemplate(
      headerText: 'BẾP NÓNG', headerFontSize: 20,
      tableFontSize: 16, itemFontSize: 14, qtyFontSize: 24,
    ),
  ),
  KitchenPreset(
    id: 'minimal_kitchen',
    name: 'Tối Giản Bếp',
    tag: 'Nhanh',
    description: 'Chỉ tên bàn + món + số lượng. In siêu nhanh.',
    template: KitchenTicketTemplate(
      headerFontSize: 16, tableFontSize: 14, itemFontSize: 12, qtyFontSize: 18,
      showOrderNumber: false, showDateTime: false, showNote: false, showDivider: false,
    ),
  ),
];
