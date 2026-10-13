import 'dart:convert';
import 'dart:io' show InternetAddress;

/// Mã lỗi chuẩn của hệ thống QR Order V4
class QrErrorCode {
  static const String invalidQr = 'INVALID_QR';
  static const String channelDisabled = 'CHANNEL_DISABLED';
  static const String requestExpired = 'REQUEST_EXPIRED';
  static const String tokenAlreadyUsed = 'TOKEN_ALREADY_USED';
  static const String alreadyClaimed = 'ALREADY_CLAIMED';
  static const String wrongStore = 'WRONG_STORE';
  static const String permissionDenied = 'PERMISSION_DENIED';
  static const String invalidState = 'INVALID_STATE';
  static const String tableNotFound = 'TABLE_NOT_FOUND';
  static const String paymentRequired = 'PAYMENT_REQUIRED';
  static const String alreadySent = 'ALREADY_SENT';
  static const String idempotencyConflict = 'IDEMPOTENCY_CONFLICT';
  static const String productNotAvailable = 'PRODUCT_NOT_AVAILABLE';
  static const String versionConflict = 'VERSION_CONFLICT';
  static const String networkError = 'NETWORK_ERROR';
  static const String rpcError = 'RPC_ERROR';
  static const String invalidPayload = 'INVALID_PAYLOAD';
  static const String financialQuoteChanged = 'FINANCIAL_QUOTE_CHANGED';
  static const String invalidPoints = 'INVALID_POINTS';
  static const String customerRequired = 'CUSTOMER_REQUIRED';
  static const String customerNotFound = 'CUSTOMER_NOT_FOUND';
  static const String insufficientPoints = 'INSUFFICIENT_POINTS';
  static const String invalidLoyaltyConfig = 'INVALID_LOYALTY_CONFIG';
  static const String couponNotFound = 'COUPON_NOT_FOUND';
  static const String couponDisabled = 'COUPON_DISABLED';
  static const String couponNotStarted = 'COUPON_NOT_STARTED';
  static const String couponExpired = 'COUPON_EXPIRED';
  static const String couponMinOrderNotMet = 'COUPON_MIN_ORDER_NOT_MET';
  static const String couponSchemaUnavailable = 'COUPON_SCHEMA_UNAVAILABLE';
  static const String invalidCouponValue = 'INVALID_COUPON_VALUE';
  static const String invalidCouponType = 'INVALID_COUPON_TYPE';
  static const String invalidSurcharge = 'INVALID_SURCHARGE';
  static const String invalidPaymentMethod = 'INVALID_PAYMENT_METHOD';
  static const String sessionAlreadySettled = 'SESSION_ALREADY_SETTLED';
  static const String invalidSessionItems = 'INVALID_SESSION_ITEMS';
  static const String serverSchemaOutdated = 'SERVER_SCHEMA_OUTDATED';
  static const String networkUncertain = 'NETWORK_UNCERTAIN';
  static const String checkoutInProgress = 'CHECKOUT_IN_PROGRESS';
  static const String tableRequired = 'TABLE_REQUIRED';
  static const String notClaimer = 'NOT_CLAIMER';
  static const String paymentPermissionDenied = 'PAYMENT_PERMISSION_DENIED';
  static const String rateLimited = 'RATE_LIMITED';

  static String toUserMessage(String? code, [String? fallback]) {
    switch (code) {
      case invalidQr:
        return 'Mã QR không hợp lệ hoặc đã bị vô hiệu hóa.';
      case channelDisabled:
        return 'Kênh gọi món QR này hiện đang tạm đóng.';
      case requestExpired:
        return 'Mã QR đã hết hạn. Vui lòng yêu cầu khách tạo lại.';
      case tokenAlreadyUsed:
        return 'Mã QR này đã được sử dụng trước đó.';
      case alreadyClaimed:
        return 'Đơn hàng này đã được nhân viên khác tiếp nhận.';
      case notClaimer:
        return 'Đơn này đang do nhân viên khác xử lý.';
      case tableRequired:
        return 'Vui lòng chọn bàn trước khi gửi đơn.';
      case paymentPermissionDenied:
        return 'Bạn không có quyền thu tiền. Hãy chuyển đơn cho thu ngân.';
      case rateLimited:
        return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
      case wrongStore:
        return 'Mã QR này thuộc về một cửa hàng khác.';
      case permissionDenied:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case invalidState:
        return 'Trạng thái đơn hàng không hợp lệ cho thao tác này.';
      case tableNotFound:
        return 'Không tìm thấy bàn đã chọn hoặc bàn đang bị khóa.';
      case paymentRequired:
        return 'Đơn mang đi yêu cầu thanh toán trước khi gửi bếp.';
      case alreadySent:
        return 'Đơn hàng đã được gửi bếp trước đó.';
      case idempotencyConflict:
        return 'Yêu cầu bị trùng lặp hoặc mâu thuẫn nội dung, vui lòng kiểm tra lại.';
      case productNotAvailable:
        return 'Món ăn không tồn tại hoặc đang tạm ngưng phục vụ.';
      case versionConflict:
        return 'Đơn hàng đã được cập nhật bởi thiết bị khác. Vui lòng tải lại.';
      case networkError:
        return 'Lỗi kết nối mạng. Vui lòng kiểm tra internet.';
      case rpcError:
        return 'Lỗi xử lý từ hệ thống máy chủ.';
      case financialQuoteChanged:
        return 'Số tiền giảm giá trên hóa đơn đã thay đổi. Vui lòng xác nhận lại số tiền trước khi thanh toán.';
      case invalidPoints:
        return 'Số điểm sử dụng không hợp lệ.';
      case customerRequired:
        return 'Vui lòng chọn thông tin khách hàng để sử dụng điểm.';
      case customerNotFound:
        return 'Khách hàng không tồn tại hoặc không thuộc cửa hàng này.';
      case insufficientPoints:
        return 'Số điểm yêu cầu vượt quá số dư điểm của khách hàng.';
      case invalidLoyaltyConfig:
        return 'Cấu hình quy đổi điểm tích lũy chưa hợp lệ.';
      case couponNotFound:
        return 'Mã giảm giá không tồn tại hoặc không thuộc quán.';
      case couponDisabled:
        return 'Mã giảm giá hiện đang bị tạm khóa.';
      case couponNotStarted:
        return 'Mã giảm giá chưa đến ngày áp dụng.';
      case couponExpired:
        return 'Mã giảm giá đã hết hạn sử dụng.';
      case couponMinOrderNotMet:
        return 'Đơn hàng chưa đạt giá trị tối thiểu để áp dụng mã giảm giá.';
      case couponSchemaUnavailable:
        return 'Hệ thống voucher/coupon chưa được khởi tạo.';
      case invalidCouponValue:
      case invalidCouponType:
        return 'Thông tin mã giảm giá không hợp lệ.';
      case invalidSurcharge:
        return 'Phụ phí không hợp lệ hoặc vượt quá hạn mức cho phép.';
      case invalidPaymentMethod:
        return 'Phương thức thanh toán không hợp lệ.';
      case sessionAlreadySettled:
        return 'Phiên bàn này đã được thanh toán quyết toán trước đó.';
      case invalidSessionItems:
        return 'Phiên bàn không có món ăn để thanh toán.';
      case serverSchemaOutdated:
        return 'Máy chủ chưa được cập nhật tính năng này. Chưa ghi nhận thao tác nào; vui lòng báo quản lý kỹ thuật.';
      case networkUncertain:
        return 'Chưa xác định được trạng thái thanh toán. Không đổi nội dung thanh toán; hãy thử lại để hệ thống đối soát.';
      case checkoutInProgress:
        return 'Bàn này đang được xử lý thanh toán. Vui lòng chờ.';
      default:
        return fallback ?? 'Đã xảy ra lỗi. Vui lòng thử lại!';
    }
  }
}

/// Typed wrapper cho toàn bộ RPC response của QR Order V4
class QrRpcResponse<T> {
  final bool isSuccess;
  final T? data;
  final String? errorCode;
  final String? message;

  const QrRpcResponse({
    required this.isSuccess,
    this.data,
    this.errorCode,
    this.message,
  });

  factory QrRpcResponse.success(T data, [String? message]) {
    return QrRpcResponse(isSuccess: true, data: data, message: message);
  }

  factory QrRpcResponse.error(String code, String message, [T? data]) {
    return QrRpcResponse(
      isSuccess: false,
      data: data,
      errorCode: code,
      message: message,
    );
  }

  factory QrRpcResponse.fromMap(
    Map<String, dynamic> m,
    T Function(dynamic data) dataParser,
  ) {
    final success = m['success'] == true;
    if (success) {
      final rawData = m['data'];
      return QrRpcResponse.success(
        rawData != null ? dataParser(rawData) : dataParser(m),
        m['message'] as String?,
      );
    }
    return QrRpcResponse.error(
      m['error_code'] as String? ?? 'RPC_ERROR',
      m['message'] as String? ?? 'Lỗi không xác định',
      m['data'] != null ? dataParser(m['data']) : null,
    );
  }
}

/// Cấu hình QR Order lưu trong `app_settings` (key: `qr_order_settings`)
class QrOrderSettingsModel {
  final bool isTableEnabled;
  final bool isCounterEnabled;
  final String customBaseUrl;
  final String
  counterPaymentMode; // Legacy transport field; COUNTER always pays before kitchen.
  final String transferBankBin;
  final String transferAccountNo;
  final String transferAccountName;

  // Counter Poster Customization Fields
  final String counterPreset;
  final String counterSizePreset; // 'a5', 'a4', 'custom'
  final double counterWidthMm;
  final double counterHeightMm;
  final String counterTitle;
  final String counterSubtitle;
  final String counterInstructions;
  final bool showCounterNotice;
  final String counterNoticeText;
  final String wifiSsid;
  final String wifiPassword;
  final String hotline;
  final String openingHours;
  final String promoFooter;

  const QrOrderSettingsModel({
    this.isTableEnabled = true,
    this.isCounterEnabled = true,
    this.customBaseUrl = '',
    this.counterPaymentMode = 'CASHIER_CONFIRM',
    this.transferBankBin = '970422',
    this.transferAccountNo = '',
    this.transferAccountName = '',
    this.counterPreset = 'classic_orange',
    this.counterSizePreset = 'a5',
    this.counterWidthMm = 148.0,
    this.counterHeightMm = 210.0,
    this.counterTitle = 'QUÉT QR GỌI MÓN TẠI QUẦY',
    this.counterSubtitle = 'Tự chọn món & Nhận mã Pickup #Q01',
    this.counterInstructions =
        '1. Quét mã QR • 2. Chọn món & Gửi đơn • 3. Đợi đọc mã Pickup #Q01',
    this.showCounterNotice = true,
    this.counterNoticeText =
        'Sau khi gửi đơn, vui lòng giữ điện thoại để nhận mã số lấy món tại quầy.',
    this.wifiSsid = '',
    this.wifiPassword = '',
    this.hotline = '',
    this.openingHours = '',
    this.promoFooter = '',
  });

  factory QrOrderSettingsModel.fromMap(Map<String, dynamic> m) {
    return QrOrderSettingsModel(
      isTableEnabled: m['is_table_enabled'] ?? true,
      isCounterEnabled: m['is_counter_enabled'] ?? true,
      customBaseUrl: m['custom_base_url'] ?? '',
      counterPaymentMode:
          m['counter_payment_mode'] as String? ?? 'CASHIER_CONFIRM',
      transferBankBin: m['transfer_bank_bin'] as String? ?? '970422',
      transferAccountNo: m['transfer_account_no'] as String? ?? '',
      transferAccountName: m['transfer_account_name'] as String? ?? '',
      counterPreset: m['counter_preset'] as String? ?? 'classic_orange',
      counterSizePreset: m['counter_size_preset'] as String? ?? 'a5',
      counterWidthMm: (m['counter_width_mm'] as num?)?.toDouble() ?? 148.0,
      counterHeightMm: (m['counter_height_mm'] as num?)?.toDouble() ?? 210.0,
      counterTitle: m['counter_title'] as String? ?? 'QUÉT QR GỌI MÓN TẠI QUẦY',
      counterSubtitle:
          m['counter_subtitle'] as String? ??
          'Tự chọn món & Nhận mã Pickup #Q01',
      counterInstructions:
          m['counter_instructions'] as String? ??
          '1. Quét mã QR • 2. Chọn món & Gửi đơn • 3. Đợi đọc mã Pickup #Q01',
      showCounterNotice: m['show_counter_notice'] as bool? ?? true,
      counterNoticeText:
          m['counter_notice_text'] as String? ??
          'Sau khi gửi đơn, vui lòng giữ điện thoại để nhận mã số lấy món tại quầy.',
      wifiSsid: m['wifi_ssid'] as String? ?? '',
      wifiPassword: m['wifi_password'] as String? ?? '',
      hotline: m['hotline'] as String? ?? '',
      openingHours: m['opening_hours'] as String? ?? '',
      promoFooter: m['promo_footer'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'is_table_enabled': isTableEnabled,
    'is_counter_enabled': isCounterEnabled,
    'custom_base_url': customBaseUrl,
    'counter_payment_mode': counterPaymentMode,
    'transfer_bank_bin': transferBankBin,
    'transfer_account_no': transferAccountNo,
    'transfer_account_name': transferAccountName,
    'counter_preset': counterPreset,
    'counter_size_preset': counterSizePreset,
    'counter_width_mm': counterWidthMm,
    'counter_height_mm': counterHeightMm,
    'counter_title': counterTitle,
    'counter_subtitle': counterSubtitle,
    'counter_instructions': counterInstructions,
    'show_counter_notice': showCounterNotice,
    'counter_notice_text': counterNoticeText,
    'wifi_ssid': wifiSsid,
    'wifi_password': wifiPassword,
    'hotline': hotline,
    'opening_hours': openingHours,
    'promo_footer': promoFooter,
  };

  QrOrderSettingsModel copyWith({
    bool? isTableEnabled,
    bool? isCounterEnabled,
    String? customBaseUrl,
    String? counterPaymentMode,
    String? transferBankBin,
    String? transferAccountNo,
    String? transferAccountName,
    String? counterPreset,
    String? counterSizePreset,
    double? counterWidthMm,
    double? counterHeightMm,
    String? counterTitle,
    String? counterSubtitle,
    String? counterInstructions,
    bool? showCounterNotice,
    String? counterNoticeText,
    String? wifiSsid,
    String? wifiPassword,
    String? hotline,
    String? openingHours,
    String? promoFooter,
  }) {
    return QrOrderSettingsModel(
      isTableEnabled: isTableEnabled ?? this.isTableEnabled,
      isCounterEnabled: isCounterEnabled ?? this.isCounterEnabled,
      customBaseUrl: customBaseUrl ?? this.customBaseUrl,
      counterPaymentMode: counterPaymentMode ?? this.counterPaymentMode,
      transferBankBin: transferBankBin ?? this.transferBankBin,
      transferAccountNo: transferAccountNo ?? this.transferAccountNo,
      transferAccountName: transferAccountName ?? this.transferAccountName,
      counterPreset: counterPreset ?? this.counterPreset,
      counterSizePreset: counterSizePreset ?? this.counterSizePreset,
      counterWidthMm: counterWidthMm ?? this.counterWidthMm,
      counterHeightMm: counterHeightMm ?? this.counterHeightMm,
      counterTitle: counterTitle ?? this.counterTitle,
      counterSubtitle: counterSubtitle ?? this.counterSubtitle,
      counterInstructions: counterInstructions ?? this.counterInstructions,
      showCounterNotice: showCounterNotice ?? this.showCounterNotice,
      counterNoticeText: counterNoticeText ?? this.counterNoticeText,
      wifiSsid: wifiSsid ?? this.wifiSsid,
      wifiPassword: wifiPassword ?? this.wifiPassword,
      hotline: hotline ?? this.hotline,
      openingHours: openingHours ?? this.openingHours,
      promoFooter: promoFooter ?? this.promoFooter,
    );
  }
}

/// Model kênh QR (TABLE_SHARED hoặc COUNTER_TAKEAWAY)
class QrChannelModel {
  final String id;
  final String storeId;
  final String type; // QrChannelType.table | QrChannelType.counter
  final String channelCode;
  final String name;
  final bool isActive;
  final String paymentMode; // 'PAY_BEFORE_KITCHEN' | 'CASHIER_CONFIRM'
  final DateTime createdAt;

  bool get isTableShared => type == QrChannelType.table;

  bool get isCounterTakeaway => type == QrChannelType.counter;

  const QrChannelModel({
    required this.id,
    required this.storeId,
    required this.type,
    required this.channelCode,
    required this.name,
    required this.isActive,
    this.paymentMode = 'PAY_BEFORE_KITCHEN',
    required this.createdAt,
  });

  factory QrChannelModel.fromMap(Map<String, dynamic> m) {
    return QrChannelModel(
      id: m['id'] as String? ?? '',
      storeId: m['store_id'] as String? ?? '',
      type: QrChannelType.normalize(
        m['type'] as String? ?? m['channel_type'] as String?,
      ),
      channelCode: m['channel_code'] as String? ?? '',
      name: m['name'] as String? ?? '',
      isActive: m['is_active'] as bool? ?? true,
      paymentMode: m['payment_mode'] as String? ?? 'PAY_BEFORE_KITCHEN',
      createdAt: _asDate(m['created_at']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'store_id': storeId,
    'type': type,
    'channel_code': channelCode,
    'name': name,
    'is_active': isActive,
    'payment_mode': paymentMode,
    'created_at': createdAt.toIso8601String(),
  };

  QrChannelModel copyWith({
    String? id,
    String? storeId,
    String? type,
    String? channelCode,
    String? name,
    bool? isActive,
    String? paymentMode,
    DateTime? createdAt,
  }) {
    return QrChannelModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      type: type ?? this.type,
      channelCode: channelCode ?? this.channelCode,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      paymentMode: paymentMode ?? this.paymentMode,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Chi tiết món trong đơn QR
class QrRequestItemModel {
  final String id;
  final String requestId;
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final double subtotal;
  final List<Map<String, dynamic>> modifiersJson;
  final String note;

  const QrRequestItemModel({
    required this.id,
    required this.requestId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.subtotal = 0.0,
    this.modifiersJson = const [],
    this.note = '',
  });

  factory QrRequestItemModel.fromMap(Map<String, dynamic> m) {
    final price = _asDouble(m['unit_price']);
    final qty = _asInt(m['quantity'], 1);
    final sub = m['subtotal'] != null
        ? _asDouble(m['subtotal'])
        : price * qty;

    List<Map<String, dynamic>> mods = [];
    final rawMods = m['modifiers_json'];
    if (rawMods is List) {
      mods = rawMods
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } else if (rawMods is String && rawMods.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMods);
        if (decoded is List) {
          mods = decoded
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    return QrRequestItemModel(
      id: _asStr(m['id']) ?? '',
      requestId: _asStr(m['request_id']) ?? '',
      productId: _asStr(m['product_id']) ?? '',
      productName: _asStr(m['product_name']) ?? '',
      unitPrice: price,
      quantity: qty,
      subtotal: sub,
      modifiersJson: mods,
      note: _asStr(m['note']) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'request_id': requestId,
    'product_id': productId,
    'product_name': productName,
    'unit_price': unitPrice,
    'quantity': quantity,
    'subtotal': subtotal > 0 ? subtotal : (unitPrice * quantity),
    'modifiers_json': modifiersJson,
    'note': note,
  };

  QrRequestItemModel copyWith({
    String? id,
    String? requestId,
    String? productId,
    String? productName,
    double? unitPrice,
    int? quantity,
    double? subtotal,
    List<Map<String, dynamic>>? modifiersJson,
    String? note,
  }) {
    return QrRequestItemModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      modifiersJson: modifiersJson ?? this.modifiersJson,
      note: note ?? this.note,
    );
  }
}

/// Trạng thái đơn QR (chữ thường, đúng hợp đồng RPC đơn giản hóa).
class QrStatus {
  static const String submitted = 'submitted';
  static const String claimed = 'claimed';
  static const String sentKitchen = 'sent_kitchen';
  static const String rejected = 'rejected';
  static const String expired = 'expired';
  static const String cancelled = 'cancelled';

  /// Chuẩn hóa giá trị cũ (V4 trước đơn giản hóa) về 6 giá trị chuẩn.
  static String normalize(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'submitted':
      case 'customer_submitted':
      case 'pending_staff':
        return submitted;
      case 'claimed':
      case 'processing':
      case 'staff_review':
      case 'confirmed':
      case 'awaiting_payment':
      case 'ready_for_kitchen':
        return claimed;
      case 'sent_kitchen':
        return sentKitchen;
      case 'rejected':
        return rejected;
      case 'expired':
        return expired;
      case 'cancelled':
        return cancelled;
      default:
        return submitted;
    }
  }
}

/// Loại kênh chuẩn hóa.
class QrChannelType {
  static const String table = 'TABLE_SHARED';
  static const String counter = 'COUNTER_TAKEAWAY';

  static String normalize(String? raw) {
    final v = (raw ?? '').trim().toUpperCase();
    if (v == 'COUNTER_TAKEAWAY' || v == 'COUNTER') return counter;
    return table;
  }
}

int _asInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim()) ?? fallback;
  return fallback;
}

double _asDouble(dynamic v, [double fallback = 0.0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim()) ?? fallback;
  return fallback;
}

String? _asStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

DateTime? _asDate(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

/// Model Đơn Đặt Món QR (dùng chung cho khách và nhân viên)
class QrRequestModel {
  final String id;
  final String storeId;
  final String channelId;
  final String type; // QrChannelType.table | QrChannelType.counter
  final String? tableId; // Bàn khách chọn (TABLE)
  final String? tableName;
  final String? pickupCode; // Mã lấy món (COUNTER), null nếu server chưa cấp
  final String trackingToken;
  final String status; // QrStatus.*
  final String paymentStatus; // 'unpaid' | 'paid'
  final String? claimedBy;
  final String customerNote;
  final String? rejectReason;
  final double totalAmount;
  final int version;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final List<QrRequestItemModel> items;

  bool get isTable => type == QrChannelType.table;
  bool get isCounter => type == QrChannelType.counter;

  bool get isSubmitted => status == QrStatus.submitted;
  bool get isClaimed => status == QrStatus.claimed;
  bool get isSentKitchen => status == QrStatus.sentKitchen;
  bool get isRejected => status == QrStatus.rejected;
  bool get isExpired => status == QrStatus.expired;
  bool get isCancelled => status == QrStatus.cancelled;
  bool get isPaid => paymentStatus == 'paid';

  /// Đơn còn nằm trong hàng chờ nhân viên (chưa gửi bếp, chưa đóng).
  bool get isOpen => isSubmitted || isClaimed;

  /// Tương thích tên cũ (khách/nhân viên dùng chung).
  String? get assignedTableId => tableId;
  String? get assignedTableName => tableName;

  /// Mã lấy món để hiển thị; rỗng nếu chưa có (không bịa mã giả).
  String get displayPickupCode {
    final raw = pickupCode?.replaceAll('#', '').trim() ?? '';
    return raw.isEmpty ? '' : '#$raw';
  }

  /// Tên ngắn dùng cho hàng chờ / tiêu đề sheet.
  String get displayTitle {
    if (isTable) {
      final n = tableName?.trim() ?? '';
      return n.isNotEmpty ? n : 'Chưa chọn bàn';
    }
    final code = displayPickupCode;
    return code.isEmpty ? 'Mang đi' : 'Mang đi $code';
  }

  const QrRequestModel({
    required this.id,
    this.storeId = '',
    this.channelId = '',
    required this.type,
    this.tableId,
    this.tableName,
    this.pickupCode,
    this.trackingToken = '',
    required this.status,
    this.paymentStatus = 'unpaid',
    this.claimedBy,
    this.customerNote = '',
    this.rejectReason,
    this.totalAmount = 0.0,
    this.version = 1,
    this.createdAt,
    this.updatedAt,
    this.expiresAt,
    this.items = const [],
  });

  factory QrRequestModel.fromMap(Map<String, dynamic> m) {
    final rawItems = m['items'];
    final items = <QrRequestItemModel>[];
    if (rawItems is List) {
      for (final it in rawItems) {
        if (it is Map) {
          items.add(QrRequestItemModel.fromMap(Map<String, dynamic>.from(it)));
        }
      }
    }

    // Tên bàn có thể lồng trong join `table:ban_dining_tables(...)`.
    String? tableName = _asStr(m['table_name']);
    final joined = m['table'];
    if (tableName == null && joined is Map) {
      tableName = _asStr(joined['name']) ?? _asStr(joined['label']);
    }

    return QrRequestModel(
      id: _asStr(m['id']) ?? _asStr(m['request_id']) ?? '',
      storeId: _asStr(m['store_id']) ?? '',
      channelId: _asStr(m['channel_id']) ?? '',
      type: QrChannelType.normalize(
        _asStr(m['type']) ?? _asStr(m['channel_type']),
      ),
      tableId: _asStr(m['table_id']),
      tableName: tableName,
      pickupCode: _asStr(m['pickup_code']),
      trackingToken: _asStr(m['tracking_token']) ?? '',
      status: QrStatus.normalize(_asStr(m['status'])),
      paymentStatus: _asStr(m['payment_status']) ?? 'unpaid',
      claimedBy: _asStr(m['claimed_by']),
      customerNote: _asStr(m['customer_note']) ?? _asStr(m['note']) ?? '',
      rejectReason: _asStr(m['reject_reason']),
      totalAmount: _asDouble(m['total_amount']),
      version: _asInt(m['version'], 1),
      createdAt: _asDate(m['created_at']),
      updatedAt: _asDate(m['updated_at']),
      expiresAt: _asDate(m['expires_at']),
      items: items,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'store_id': storeId,
    'channel_id': channelId,
    'type': type,
    'table_id': tableId,
    'table_name': tableName,
    'pickup_code': pickupCode,
    'tracking_token': trackingToken,
    'status': status,
    'payment_status': paymentStatus,
    'claimed_by': claimedBy,
    'customer_note': customerNote,
    'reject_reason': rejectReason,
    'total_amount': totalAmount,
    'version': version,
    'created_at': createdAt?.toIso8601String(),
    'updated_at': updatedAt?.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'items': items.map((it) => it.toMap()).toList(),
  };

  QrRequestModel copyWith({
    String? status,
    String? paymentStatus,
    String? tableId,
    String? tableName,
    String? claimedBy,
    String? rejectReason,
    double? totalAmount,
    int? version,
    List<QrRequestItemModel>? items,
  }) {
    return QrRequestModel(
      id: id,
      storeId: storeId,
      channelId: channelId,
      type: type,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      pickupCode: pickupCode,
      trackingToken: trackingToken,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      claimedBy: claimedBy ?? this.claimedBy,
      customerNote: customerNote,
      rejectReason: rejectReason ?? this.rejectReason,
      totalAmount: totalAmount ?? this.totalAmount,
      version: version ?? this.version,
      createdAt: createdAt,
      updatedAt: updatedAt,
      expiresAt: expiresAt,
      items: items ?? this.items,
    );
  }
}

/// Nguồn DUY NHẤT dựng link QR Order công khai.
/// Mặc định `https://quannho.lpm.vn/pos`, có thể thay bằng tên miền đã lưu.
class QrUrlBuilder {
  static const String defaultBaseUrl = 'https://quannho.lpm.vn/pos';

  static const List<String> _blockedHostSuffixes = [
    '.local',
    '.lan',
    '.internal',
    '.localhost',
    '.home',
    '.corp',
  ];

  static String normalizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  /// Trả về byte của địa chỉ IP nếu [host] là IP literal, ngược lại null.
  static List<int>? _parseIpBytes(String host) {
    try {
      final addr = InternetAddress.tryParse(host);
      if (addr != null) return addr.rawAddress.toList();
      return null;
    } catch (_) {
      // Nền tảng không hỗ trợ dart:io (web): chỉ nhận dạng IPv4 dạng a.b.c.d.
      final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
          .firstMatch(host);
      if (m == null) return null;
      final bytes = [for (var i = 1; i <= 4; i++) int.parse(m.group(i)!)];
      return bytes.any((b) => b > 255) ? null : bytes;
    }
  }

  static bool _isBlockedIpv4(List<int> b) {
    if (b[0] == 0) return true; // 0.0.0.0/8
    if (b[0] == 10) return true; // 10/8
    if (b[0] == 127) return true; // loopback
    if (b[0] == 169 && b[1] == 254) return true; // link-local
    if (b[0] == 172 && b[1] >= 16 && b[1] <= 31) return true; // 172.16/12
    if (b[0] == 192 && b[1] == 168) return true; // 192.168/16
    if (b[0] == 100 && b[1] >= 64 && b[1] <= 127) return true; // CGNAT
    return false;
  }

  static bool _isBlockedIp(List<int> b) {
    if (b.length == 4) return _isBlockedIpv4(b);
    if (b.length == 16) {
      final allZeroPrefix = b.sublist(0, 10).every((x) => x == 0);
      if (allZeroPrefix && b[10] == 0xff && b[11] == 0xff) {
        return _isBlockedIpv4(b.sublist(12)); // ::ffff:a.b.c.d
      }
      if (b.sublist(0, 15).every((x) => x == 0) && b[15] <= 1) {
        return true; // :: và ::1
      }
      if ((b[0] & 0xfe) == 0xfc) return true; // fc00::/7
      if (b[0] == 0xfe && (b[1] & 0xc0) == 0x80) return true; // fe80::/10
      return false;
    }
    return true;
  }

  /// Kiểm tra tên miền gốc: https, host công khai, không userinfo/query/fragment.
  static bool isValidPublicUrl(String? url) {
    if (url == null) return false;
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty) return false;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;
    if (!uri.hasAuthority) return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.hasQuery || uri.hasFragment) return false;

    final host = uri.host.toLowerCase();
    if (host.isEmpty || !host.contains('.')) return false;
    if (host == 'localhost' || host.endsWith('.')) return false;
    for (final suffix in _blockedHostSuffixes) {
      if (host.endsWith(suffix)) return false;
    }

    final ip = _parseIpBytes(host);
    if (ip != null) return !_isBlockedIp(ip);

    // Tên miền: nhãn cuối (TLD) phải có chữ cái, chặn dạng số/hex lạ (0x7f.1).
    final labels = host.split('.');
    if (labels.any((l) => l.isEmpty)) return false;
    if (!RegExp(r'[a-z]').hasMatch(labels.last)) return false;
    if (labels.last.startsWith('0x')) return false;
    return true;
  }

  /// Tên miền gốc hiệu lực: rỗng -> mặc định; không hợp lệ -> null.
  static String? resolveBaseUrl(String? customBaseUrl) {
    final custom = (customBaseUrl ?? '').trim();
    if (custom.isEmpty) return defaultBaseUrl;
    final normalized = normalizeUrl(custom);
    return isValidPublicUrl(normalized) ? normalized : null;
  }

  /// Dựng link QR từ tên miền ĐÃ LƯU + mã kênh. Trả null khi không hợp lệ.
  static String? build({String? customBaseUrl, String? channelCode}) {
    final code = (channelCode ?? '').trim();
    if (code.isEmpty) return null;
    final base = resolveBaseUrl(customBaseUrl);
    if (base == null) return null;
    final uri = Uri.parse(base);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty && segments.last == 'goi-mon') {
      segments.removeLast();
    }
    segments.add('goi-mon');
    segments.add(''); // dấu / cuối: .../goi-mon/?code=...
    return Uri(
      scheme: 'https',
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      pathSegments: segments,
      queryParameters: {'code': code},
    ).toString();
  }
}

/// Model đại diện cho báo giá tài chính có thẩm quyền từ Server (Authoritative Financial Quote)
/// Nhận từ data của lỗi FINANCIAL_QUOTE_CHANGED hoặc kết quả tính toán tài chính.
class AuthoritativeQuote {
  final double subtotal;
  final double discount;
  final double pointsDiscount;
  final double couponDiscount;
  final double surcharge;
  final double total;

  const AuthoritativeQuote({
    required this.subtotal,
    required this.discount,
    required this.pointsDiscount,
    required this.couponDiscount,
    required this.surcharge,
    required this.total,
  });

  factory AuthoritativeQuote.fromMap(Map<String, dynamic> map) {
    return AuthoritativeQuote(
      subtotal:
          ((map['authoritative_subtotal'] ?? map['subtotal']) as num?)
              ?.toDouble() ??
          0.0,
      discount:
          ((map['authoritative_discount'] ?? map['discount']) as num?)
              ?.toDouble() ??
          0.0,
      pointsDiscount:
          ((map['authoritative_points_discount'] ?? map['points_discount'])
                  as num?)
              ?.toDouble() ??
          0.0,
      couponDiscount:
          ((map['authoritative_coupon_discount'] ?? map['coupon_discount'])
                  as num?)
              ?.toDouble() ??
          0.0,
      surcharge:
          ((map['authoritative_surcharge'] ?? map['surcharge']) as num?)
              ?.toDouble() ??
          0.0,
      total:
          ((map['authoritative_total'] ?? map['total_amount']) as num?)
              ?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'authoritative_subtotal': subtotal,
    'authoritative_discount': discount,
    'authoritative_points_discount': pointsDiscount,
    'authoritative_coupon_discount': couponDiscount,
    'authoritative_surcharge': surcharge,
    'authoritative_total': total,
  };
}
