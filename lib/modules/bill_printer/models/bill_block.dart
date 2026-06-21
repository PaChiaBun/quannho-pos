// lib/modules/bill_printer/models/bill_block.dart
// Model cho từng "mảnh ghép" trong thiết kế hoá đơn

import 'package:uuid/uuid.dart';

// ─── Block Types ──────────────────────────────────────────────────────────────
enum BillBlockType {
  shopHeader,    // 🏪 Tên quán + tagline
  shopLogo,      // 🖼️ Logo ảnh (cảnh báo chất lượng in)
  shopAddress,   // 📍 Địa chỉ quán
  shopPhone,     // 📞 Số điện thoại
  divider,       // ➖ Đường kẻ ngang
  orderInfo,     // 📋 Số đơn + ngày giờ + thu ngân
  tableInfo,     // 🪑 Tên bàn / Mang đi
  itemsList,     // 🍽️ Danh sách món [LOCKED]
  totals,        // 💰 Tổng tiền [LOCKED]
  paymentMethod, // 💳 Phương thức thanh toán
  loyaltyPoints, // ⭐ Điểm thưởng tích luỹ
  qrCode,        // 📱 QR Code (VietQR tĩnh hoặc SePay động)
  customText,    // 📝 Văn bản tự do (wifi, KM, slogan...)
  spacer,        // ↕️ Khoảng trắng
  footer,        // 🙏 Lời cảm ơn / footer
  appBranding,   // 🚀 Quán Nhỏ POS — bắt buộc, không xoá
}

extension BillBlockTypeX on BillBlockType {
  String get label {
    switch (this) {
      case BillBlockType.shopHeader:    return '🏪 Tên quán';
      case BillBlockType.shopLogo:      return '🖼️ Logo quán';
      case BillBlockType.shopAddress:   return '📍 Địa chỉ';
      case BillBlockType.shopPhone:     return '📞 Số điện thoại';
      case BillBlockType.divider:       return '➖ Đường kẻ';
      case BillBlockType.orderInfo:     return '📋 Thông tin đơn';
      case BillBlockType.tableInfo:     return '🪑 Tên bàn';
      case BillBlockType.itemsList:     return '🍽️ Danh sách món';
      case BillBlockType.totals:        return '💰 Tổng tiền';
      case BillBlockType.paymentMethod: return '💳 Phương thức TT';
      case BillBlockType.loyaltyPoints: return '⭐ Điểm thưởng';
      case BillBlockType.qrCode:        return '📱 QR Code';
      case BillBlockType.customText:    return '📝 Văn bản tự do';
      case BillBlockType.spacer:        return '↕️ Khoảng trắng';
      case BillBlockType.footer:        return '🙏 Lời cảm ơn';
      case BillBlockType.appBranding:   return '🚀 Quán Nhỏ POS';
    }
  }

  bool get isLocked => this == BillBlockType.itemsList
      || this == BillBlockType.totals
      || this == BillBlockType.appBranding;

  // Có thể thêm nhiều lần không
  bool get isMultiAllowed => this == BillBlockType.divider
      || this == BillBlockType.customText
      || this == BillBlockType.spacer;

  // Config mặc định khi thêm block mới
  Map<String, dynamic> get defaultConfig {
    switch (this) {
      case BillBlockType.shopHeader:
        return {'shopName': '', 'tagline': '', 'fontSize': 16, 'bold': true, 'align': 'center'};
      case BillBlockType.shopLogo:
        return {'imagePath': '', 'width': 80.0, 'align': 'center'};
      case BillBlockType.shopAddress:
        return {'address': '', 'fontSize': 10, 'align': 'center'};
      case BillBlockType.shopPhone:
        return {'phone': '', 'fontSize': 10, 'align': 'center', 'label': 'ĐT:'};
      case BillBlockType.divider:
        return {'style': 'solid', 'thickness': 1.0}; // solid | dashed | double
      case BillBlockType.orderInfo:
        return {'showOrderNo': true, 'showDate': true, 'showCashier': true, 'fontSize': 10};
      case BillBlockType.tableInfo:
        return {'showTable': true, 'label': 'Bàn:', 'fontSize': 10};
      case BillBlockType.itemsList:
        return {'showPrice': true, 'showQty': true, 'showTotal': true, 'fontSize': 10};
      case BillBlockType.totals:
        return {'showSubtotal': true, 'showDiscount': true, 'showTax': false,
                'boldTotal': true, 'totalFontSize': 14, 'fontSize': 10};
      case BillBlockType.paymentMethod:
        return {'label': 'Thanh toán:', 'fontSize': 10};
      case BillBlockType.loyaltyPoints:
        return {'showEarned': true, 'showBalance': true, 'borderBox': true, 'fontSize': 10};
      case BillBlockType.qrCode:
        return {
          'mode': 'static',        // 'static' | 'sepay'
          'bankBin': '970422',     // MB Bank default
          'accountNo': '',
          'accountName': '',
          'sepayApiKey': '',
          'size': 'medium',        // small | medium | large
          'label': 'Quét để thanh toán',
          'showLabel': true,
        };
      case BillBlockType.customText:
        return {'text': 'Nhập nội dung...', 'fontSize': 10, 'bold': false,
                'italic': false, 'align': 'center', 'borderBox': false};
      case BillBlockType.spacer:
        return {'height': 8.0};
      case BillBlockType.footer:
        return {'text': 'Cảm ơn quý khách!', 'subText': 'Hẹn gặp lại 🙏',
                'fontSize': 12, 'align': 'center', 'bold': true};
      case BillBlockType.appBranding:
        return {'fontSize': 8, 'align': 'center'};
    }
  }
}

// ─── BillBlock ────────────────────────────────────────────────────────────────
class BillBlock {
  final String id;
  final BillBlockType type;
  final bool enabled;
  final Map<String, dynamic> config;

  const BillBlock({
    required this.id,
    required this.type,
    this.enabled = true,
    required this.config,
  });

  bool get locked => type.isLocked;

  BillBlock copyWith({bool? enabled, Map<String, dynamic>? config}) => BillBlock(
    id:      id,
    type:    type,
    enabled: enabled ?? this.enabled,
    config:  config  ?? this.config,
  );

  // Helper: đọc config value an toàn
  T cfg<T>(String key, T fallback) {
    final v = config[key];
    if (v is T) return v;
    return fallback;
  }

  Map<String, dynamic> toJson() => {
    'id':      id,
    'type':    type.name,
    'enabled': enabled,
    'config':  config,
  };

  factory BillBlock.fromJson(Map<String, dynamic> j) {
    final typeName = j['type'] as String? ?? '';
    final type = BillBlockType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => BillBlockType.customText,
    );
    return BillBlock(
      id:      j['id'] as String? ?? const Uuid().v4(),
      type:    type,
      enabled: j['enabled'] as bool? ?? true,
      config:  Map<String, dynamic>.from(j['config'] as Map? ?? {}),
    );
  }

  // Factory: tạo block mới với config default
  factory BillBlock.create(BillBlockType type) => BillBlock(
    id:     const Uuid().v4(),
    type:   type,
    config: Map.from(type.defaultConfig),
  );
}
