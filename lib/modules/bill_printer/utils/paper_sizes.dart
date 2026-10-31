// lib/modules/bill_printer/utils/paper_sizes.dart
// Bảng khổ giấy dùng chung cho thiết kế hóa đơn, phiếu bếp và in thật.
// Trước đây bề rộng bị viết cứng ở nhiều nơi (chỉ 58/80/A4); thêm khổ mới chỉ cần sửa tại đây.

class PaperSpec {
  final String key; // lưu trong mẫu: '50mm' | '58mm' | '80mm' | 'a5' | 'a4'
  final String label; // nhãn trên nút chọn
  final double pageMm; // bề rộng trang in (mm), đã trừ lề cứng của đầu in
  final double billPreview; // tỉ lệ bề rộng khung xem trước hóa đơn
  final double kitchenPreview; // tỉ lệ bề rộng khung xem trước phiếu bếp
  final String description;
  final bool forKitchen; // có cho chọn ở thiết kế phiếu bếp không

  const PaperSpec({
    required this.key,
    required this.label,
    required this.pageMm,
    required this.billPreview,
    required this.kitchenPreview,
    required this.description,
    this.forKitchen = false,
  });
}

const List<PaperSpec> kPaperSpecs = [
  PaperSpec(
    key: '50mm',
    label: '50mm',
    pageMm: 46,
    billPreview: 0.54,
    kitchenPreview: 0.64,
    forKitchen: true,
    description:
        '50mm — Giấy rất nhỏ | Máy POS cầm tay (Sunmi V3...), máy in mini. Chữ nên nhỏ gọn, ít cột.',
  ),
  PaperSpec(
    key: '58mm',
    label: '58mm',
    pageMm: 48,
    billPreview: 0.60,
    kitchenPreview: 0.70,
    forKitchen: true,
    description:
        '58mm — Khổ nhỏ | Máy in cầm tay, bill nhỏ gọn. Phù hợp quán take-away hoặc khu vực bếp.',
  ),
  PaperSpec(
    key: '80mm',
    label: '80mm',
    pageMm: 70,
    billPreview: 0.80,
    kitchenPreview: 0.88,
    forKitchen: true,
    description:
        '80mm — Khổ phổ biến nhất | Máy in quầy thu ngân thông thường. Đa số quán ăn, cà phê, nhà hàng dùng khổ này.',
  ),
  PaperSpec(
    key: 'a5',
    label: 'A5',
    pageMm: 148,
    billPreview: 0.90,
    kitchenPreview: 0.90,
    description:
        'A5 — Khổ vừa | Máy in văn phòng, hóa đơn/phiếu giao hàng cỡ nửa tờ A4.',
  ),
  PaperSpec(
    key: 'a4',
    label: 'A4',
    pageMm: 210,
    billPreview: 1.0,
    kitchenPreview: 1.0,
    description:
        'A4 — Khổ lớn | In trên máy in văn phòng. Phù hợp nhà hàng cao cấp, in hóa đơn VAT.',
  ),
];

/// Tìm khổ giấy theo khóa; khóa lạ/null -> 80mm (khổ mặc định).
PaperSpec paperSpecOf(String? key) {
  final k = (key ?? '').toLowerCase();
  for (final s in kPaperSpecs) {
    if (s.key == k) return s;
  }
  return kPaperSpecs.firstWhere((s) => s.key == '80mm');
}

double paperWidthMm(String? key) => paperSpecOf(key).pageMm;

List<PaperSpec> get kKitchenPaperSpecs =>
    kPaperSpecs.where((s) => s.forKitchen).toList();
