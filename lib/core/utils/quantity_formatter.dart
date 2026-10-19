// ─────────────────────────────────────────────────────────────────────────────
// QUANTITY FORMATTER — Chuẩn hóa hiển thị tồn kho & biến động F&B Quán Nhỏ
// ─────────────────────────────────────────────────────────────────────────────

/// Định dạng số lượng thông minh:
/// - Số nguyên: 5 -> "5", 100 -> "100"
/// - Số lẻ: 0.02 -> "0.02", 0.015 -> "0.015", 4.985 -> "4.985"
/// - Cắt bỏ các số 0 thừa ở cuối phần thập phân
/// - Triệt tiêu hoàn toàn "-0", "-0.0", "-0.00"
String fmtQty(num v, {int maxDecimals = 3}) {
  if (v.isNaN || v.isInfinite) return '0';
  final d = v.toDouble();
  if (d.abs() <= 1e-6) return '0';
  if (d % 1 == 0) return d.toInt().toString();

  String s = d.toStringAsFixed(maxDecimals);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  if (s == '-0' || s == '-0.0' || s == '' || s == '-') return '0';
  return s;
}

/// Định dạng biến động kho (delta) kèm dấu (+ / -) và đơn vị tính:
/// - fmtDelta(0.02, 'kg')   -> "+0.02 kg"
/// - fmtDelta(-0.015, 'kg') -> "-0.015 kg"
/// - fmtDelta(-20, 'kg')    -> "-20 kg"
/// - fmtDelta(0, 'kg')      -> "0 kg" (NEVER "-0 kg")
/// - fmtDelta(-0.0, 'kg')   -> "0 kg"
String fmtDelta(num delta, String unit, {int maxDecimals = 3}) {
  final d = delta.toDouble();
  final u = unit.trim();
  final unitSuffix = u.isNotEmpty ? ' $u' : '';
  if (d.isNaN || d.isInfinite || d.abs() <= 1e-6) return '0$unitSuffix';

  final absFormatted = fmtQty(d.abs(), maxDecimals: maxDecimals);
  if (absFormatted == '0') return '0$unitSuffix';

  final sign = d > 0 ? '+' : '-';
  return '$sign$absFormatted$unitSuffix';
}

/// Chuyển đổi mã lý do biến động kho sang tiếng Việt chuẩn POS/Kho F&B:
String reasonLabel(String reason) {
  switch (reason) {
    case 'receive':
    case 'purchase':
      return 'Nhập kho';
    case 'adjust':
    case 'adjustment':
      return 'Hiệu chỉnh';
    case 'sale':
      return 'Bán hàng';
    case 'recipe_usage':
      return 'Xuất công thức';
    case 'production':
      return 'Sản xuất';
    case 'production_output':
      return 'Nhập thành phẩm';
    case 'return':
      return 'Hoàn trả';
    case 'waste':
      return 'Hao hụt';
    case 'expired':
      return 'Hết hạn';
    case 'spill':
      return 'Đổ vỡ';
    case 'loss':
      return 'Mất / thất thoát';
    case 'stock_count':
      return 'Kiểm kê';
    case 'damaged':
      return 'Hư hỏng';
    case 'transfer':
      return 'Chuyển kho';
    case 'reconciliation':
      return 'Bù hoàn kho';
    default:
      return reason;
  }
}

/// Alias thuận tiện tương thích với formatStockDelta
String formatStockDelta(num delta, String unit, {int maxDecimals = 3}) =>
    fmtDelta(delta, unit, maxDecimals: maxDecimals);

/// Quy đổi số lượng nguyên liệu theo đơn vị công thức sang đơn vị kho sản phẩm.
/// Đồng bộ logic 100% với hàm PostgreSQL `convert_recipe_ingredient_qty_v1`.
double convertRecipeIngredientQty(
  num qty,
  String recipeUnit,
  String productUnit, {
  num conversionRate = 0,
  String conversionUnit = '',
}) {
  final vQty = qty.toDouble();
  if (vQty == 0) return 0.0;

  String normalizeUnit(String u) {
    var s = u.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    if (s.isEmpty) return '';
    // Khối lượng cơ sở (gram)
    if (const {'g', 'gr', 'gram', 'gam', 'grm'}.contains(s)) return 'g';
    // Khối lượng lớn (kilogram)
    if (const {'kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo'}.contains(s))
      return 'kg';
    // Thể tích cơ sở (milliliter)
    if (const {
      'ml',
      'mililit',
      'mililít',
      'mili lit',
      'mili lít',
      'milliliter',
      'cc',
    }.contains(s))
      return 'ml';
    // Thể tích lớn (liter)
    if (const {'l', 'lit', 'lít', 'liter', 'litre'}.contains(s)) return 'lít';
    return s;
  }

  final vR = normalizeUnit(recipeUnit);
  final vP = normalizeUnit(productUnit);
  final vC = normalizeUnit(conversionUnit);
  final vRate = conversionRate.toDouble();

  // 1. Cùng đơn vị: Giữ nguyên số lượng
  if (vR == vP && vR.isNotEmpty) {
    return vQty;
  }

  final vRIsBase = vR == 'g' || vR == 'ml';
  final vRIsLarge = vR == 'kg' || vR == 'lít';
  final vPIsBase = vP == 'g' || vP == 'ml';
  final vPIsLarge = vP == 'kg' || vP == 'lít';
  final vCIsBase = vC == 'g' || vC == 'ml';
  final vCIsLarge = vC == 'kg' || vC == 'lít';

  // 2. Quy đổi theo quy cách đóng gói (VD: 1 lon = 385 ml, 1 hộp = 1000 ml, 1 gói = 500 g)
  if (vRate > 0 && vC.isNotEmpty) {
    if (vR == vP) {
      return vQty;
    }
    if ((vR == vC) || (vRIsBase && vCIsBase)) {
      return vQty / vRate;
    }
    if (vRIsLarge && vCIsBase) {
      return (vQty * 1000.0) / vRate;
    }
    if (vRIsBase && vCIsLarge) {
      return (vQty / 1000.0) / vRate;
    }
  }

  // 3. Quy đổi hệ mét F&B tiêu chuẩn (Small <-> Large, tỷ trọng chất lỏng F&B xấp xỉ 1.0)
  // Nhỏ sang lớn (gram/ml sang kg/lít): chia 1000.0
  if (vRIsBase && vPIsLarge) {
    return vQty / 1000.0;
  }

  // Lớn sang nhỏ (kg/lít sang gram/ml): nhân 1000.0
  if (vRIsLarge && vPIsBase) {
    return vQty * 1000.0;
  }

  // Cùng cấp độ đơn vị chéo (g <-> ml hoặc kg <-> lít): tỷ trọng 1.0
  if ((vRIsBase && vPIsBase) || (vRIsLarge && vPIsLarge)) {
    return vQty;
  }

  // 4. Fallback: Đơn vị không tương thích hoặc rời rạc (cái, gói, phần...) trả về số lượng thô
  return vQty;
}

/// Alias thuận tiện tương thích với PostgreSQL `convert_fnb_unit`
double convertFnbUnit(
  num qty,
  String recipeUnit,
  String productUnit, {
  num conversionRate = 0,
  String conversionUnit = '',
}) => convertRecipeIngredientQty(
  qty,
  recipeUnit,
  productUnit,
  conversionRate: conversionRate,
  conversionUnit: conversionUnit,
);

/// Giá vốn chọn để tính công thức: ưu tiên giá nhập gần nhất (>0), không có thì giá vốn nhập tay.
/// Cả hai đều tính theo ĐƠN VỊ KHO của sản phẩm.
double effectiveUnitCost(num costLatest, num costPrice) =>
    costLatest > 0 ? costLatest.toDouble() : costPrice.toDouble();

/// Giá vốn của 1 ĐƠN VỊ CÔNG THỨC, từ giá vốn theo đơn vị kho.
/// Dùng đúng hàm quy đổi như trừ kho nên số lượng và giá vốn luôn khớp nhau.
/// VD: kho "gói" giá 50.000, 1 gói = 1000 g → công thức "gram" = 50 đ/g.
double recipeUnitCost({
  required num costPerStockUnit,
  required String recipeUnit,
  required String productUnit,
  num conversionRate = 0,
  String conversionUnit = '',
}) {
  final stockPerRecipeUnit = convertRecipeIngredientQty(
    1,
    recipeUnit,
    productUnit,
    conversionRate: conversionRate,
    conversionUnit: conversionUnit,
  );
  return costPerStockUnit.toDouble() * stockPerRecipeUnit;
}

/// Chuẩn hóa đơn vị (alias g/gram, kg/ký, ml/cc, lít/l...) — dùng chung cho cảnh báo đơn vị.
String _normUnit(String u) {
  final s = u.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (const {'g', 'gr', 'gram', 'gam', 'grm'}.contains(s)) return 'g';
  if (const {'kg', 'ký', 'ky', 'kí', 'ki', 'kilogram', 'kilo'}.contains(s))
    return 'kg';
  if (const {
    'ml',
    'mililit',
    'mililít',
    'mili lit',
    'mili lít',
    'milliliter',
    'cc',
  }.contains(s))
    return 'ml';
  if (const {'l', 'lit', 'lít', 'liter', 'litre'}.contains(s)) return 'lít';
  return s;
}

/// Kiểm tra đơn vị trong công thức có quy đổi được sang đơn vị tồn kho không.
/// Trả về `null` nếu ổn; ngược lại trả về câu cảnh báo tiếng Việt cho người dùng.
/// Logic khớp `convertRecipeIngredientQty` / hàm SQL `convert_recipe_ingredient_qty_v1`.
String? recipeUnitWarning({
  required String recipeUnit,
  required String productUnit,
  num conversionRate = 0,
  String conversionUnit = '',
}) {
  final r = _normUnit(recipeUnit);
  final p = _normUnit(productUnit);
  final c = _normUnit(conversionUnit);
  if (r.isEmpty || p.isEmpty) return null;
  if (r == p) return null;
  const mass = {'g', 'kg'};
  const volume = {'ml', 'lít'};
  bool sameFamily(String a, String b) =>
      (mass.contains(a) && mass.contains(b)) ||
      (volume.contains(a) && volume.contains(b));
  bool metric(String a) => mass.contains(a) || volume.contains(a);

  if (conversionRate > 0 && c.isNotEmpty) {
    if (r == c || sameFamily(r, c)) return null;
    if (metric(r) && metric(c)) {
      return 'Công thức dùng "$recipeUnit" còn quy cách kho tính bằng "$conversionUnit" '
          '(khối lượng ≠ thể tích). Hệ thống coi 1 g = 1 ml; hãy kiểm tra lại.';
    }
    return 'Kho quy đổi 1 $productUnit = ${conversionRate.toStringAsFixed(conversionRate % 1 == 0 ? 0 : 2)} '
        '$conversionUnit nhưng công thức dùng "$recipeUnit". Hãy chọn đơn vị "$conversionUnit" '
        'hoặc "$productUnit" để trừ kho đúng.';
  }
  if (sameFamily(r, p)) return null; // g↔kg, ml↔lít: quy đổi chuẩn ×1000
  if (metric(r) && metric(p)) {
    return 'Công thức dùng "$recipeUnit" còn kho tính bằng "$productUnit" '
        '(khối lượng ≠ thể tích). Hệ thống coi 1 g = 1 ml; hãy kiểm tra lại.';
  }
  if (metric(r) && !metric(p)) {
    return 'Kho tính bằng "$productUnit" nhưng chưa khai báo quy cách '
        '(1 $productUnit = bao nhiêu $recipeUnit). Mỗi lần bán sẽ trừ $recipeUnit thành $productUnit '
        'theo tỉ lệ 1:1 — sai kho. Vào Kho Hàng, mở nguyên liệu này và bật "Quy cách pha chế".';
  }
  return 'Công thức dùng "$recipeUnit" nhưng kho tính bằng "$productUnit" và chưa có quy đổi. '
      'Hệ thống sẽ trừ 1:1; hãy chọn đúng đơn vị "$productUnit" hoặc khai báo quy cách.';
}
