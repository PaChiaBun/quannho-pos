import 'dart:convert';

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
        return 'Máy chủ thanh toán chưa được cập nhật đồng bộ với ứng dụng. Chưa ghi nhận thanh toán; vui lòng báo quản lý kỹ thuật.';
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
  final String
  type; // 'TABLE_SHARED' | 'COUNTER_TAKEAWAY' | 'table' | 'counter'
  final String channelCode;
  final String name;
  final bool isActive;
  final String paymentMode; // 'PAY_BEFORE_KITCHEN' | 'CASHIER_CONFIRM'
  final DateTime createdAt;

  bool get isTableShared => type == 'TABLE_SHARED' || type == 'table';

  bool get isCounterTakeaway => type == 'COUNTER_TAKEAWAY' || type == 'counter';

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
      type:
          m['type'] as String? ??
          m['channel_type'] as String? ??
          'TABLE_SHARED',
      channelCode: m['channel_code'] as String? ?? '',
      name: m['name'] as String? ?? '',
      isActive: m['is_active'] as bool? ?? true,
      paymentMode: m['payment_mode'] as String? ?? 'PAY_BEFORE_KITCHEN',
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
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
    final price = (m['unit_price'] as num?)?.toDouble() ?? 0.0;
    final qty = m['quantity'] as int? ?? 1;
    final sub = (m['subtotal'] as num?)?.toDouble() ?? (price * qty);

    List<Map<String, dynamic>> mods = [];
    final rawMods = m['modifiers_json'];
    if (rawMods is List) {
      mods = rawMods.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (rawMods is String && rawMods.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawMods);
        if (decoded is List) {
          mods = decoded
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      } catch (_) {}
    }

    return QrRequestItemModel(
      id: m['id'] as String? ?? '',
      requestId: m['request_id'] as String? ?? '',
      productId: m['product_id'] as String? ?? '',
      productName: m['product_name'] as String? ?? '',
      unitPrice: price,
      quantity: qty,
      subtotal: sub,
      modifiersJson: mods,
      note: m['note'] as String? ?? '',
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

/// Model Đơn Đặt Món QR (V4)
class QrRequestModel {
  final String id;
  final String storeId;
  final String channelId;
  final String
  type; // 'TABLE_SHARED' | 'COUNTER_TAKEAWAY' | 'table' | 'counter'
  final String? tableHint; // Gợi ý số bàn khách nhập (chỉ TABLE_SHARED)
  final String? assignedTableId; // ID bàn chính thức được nhân viên gán
  final String? assignedTableName;
  final String? assignedSessionId;
  final String? pickupCode; // Mã lấy món (chỉ COUNTER_TAKEAWAY)
  final String trackingToken;
  final String status;
  // 'customer_submitted' | 'claimed' | 'staff_review' | 'awaiting_payment' |
  // 'ready_for_kitchen' | 'sent_kitchen' | 'cancelled' | 'expired'
  final String paymentStatus; // 'unpaid' | 'paid'
  final String paymentMode; // 'PAY_BEFORE_KITCHEN' | 'CASHIER_CONFIRM'
  final String customerNote;
  final String? rejectReason;
  final double totalAmount;
  final int version;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final List<QrRequestItemModel> items;

  bool get isTable => type == 'TABLE_SHARED' || type == 'table';
  bool get isCounter => type == 'COUNTER_TAKEAWAY' || type == 'counter';

  bool get isSubmitted =>
      status == 'customer_submitted' || status == 'pending_staff';
  bool get isClaimed => status == 'claimed' || status == 'processing';
  bool get isReviewing => status == 'staff_review' || status == 'confirmed';
  bool get isAwaitingPayment => status == 'awaiting_payment';
  bool get isReadyForKitchen => status == 'ready_for_kitchen';
  bool get isSentKitchen => status == 'sent_kitchen';
  bool get isCancelled => status == 'cancelled' || status == 'rejected';
  bool get isExpired => status == 'expired';

  String get displayPickupCode {
    if (pickupCode == null || pickupCode!.trim().isEmpty) return '#Q01';
    final clean = pickupCode!.replaceAll('#', '').trim();
    return '#$clean';
  }

  String get displayTitle {
    if (isTable) {
      if (assignedTableName != null && assignedTableName!.isNotEmpty) {
        return assignedTableName!;
      }
      if (tableHint != null && tableHint!.isNotEmpty) {
        return 'Gợi ý bàn: $tableHint';
      }
      return 'Bàn Gọi Món';
    }
    return 'QUẦY THU NGÂN — $displayPickupCode';
  }

  const QrRequestModel({
    required this.id,
    required this.storeId,
    required this.channelId,
    required this.type,
    this.tableHint,
    this.assignedTableId,
    this.assignedTableName,
    this.assignedSessionId,
    this.pickupCode,
    required this.trackingToken,
    required this.status,
    this.paymentStatus = 'unpaid',
    this.paymentMode = 'PAY_BEFORE_KITCHEN',
    this.customerNote = '',
    this.rejectReason,
    required this.totalAmount,
    this.version = 1,
    required this.createdAt,
    this.expiresAt,
    this.items = const [],
  });

  factory QrRequestModel.fromMap(Map<String, dynamic> m) {
    final rawItems = m['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((it) => QrRequestItemModel.fromMap(it as Map<String, dynamic>))
        .toList();

    return QrRequestModel(
      id: m['id'] as String? ?? m['request_id'] as String? ?? '',
      storeId: m['store_id'] as String? ?? '',
      channelId: m['channel_id'] as String? ?? '',
      type: m['type'] as String? ?? 'TABLE_SHARED',
      tableHint: m['table_hint'] as String?,
      assignedTableId:
          m['assigned_table_id'] as String? ?? m['table_id'] as String?,
      assignedTableName:
          m['assigned_table_name'] as String? ?? m['table_name'] as String?,
      assignedSessionId: m['assigned_session_id'] as String?,
      pickupCode: m['pickup_code'] as String?,
      trackingToken: m['tracking_token'] as String? ?? '',
      status: m['status'] as String? ?? 'customer_submitted',
      paymentStatus: m['payment_status'] as String? ?? 'unpaid',
      paymentMode: m['payment_mode'] as String? ?? 'PAY_BEFORE_KITCHEN',
      customerNote: m['customer_note'] as String? ?? m['note'] as String? ?? '',
      rejectReason: m['reject_reason'] as String?,
      totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0.0,
      version: m['version'] as int? ?? 1,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
      expiresAt: m['expires_at'] != null
          ? DateTime.parse(m['expires_at'] as String)
          : null,
      items: items,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'store_id': storeId,
    'channel_id': channelId,
    'type': type,
    'table_hint': tableHint,
    'assigned_table_id': assignedTableId,
    'assigned_table_name': assignedTableName,
    'assigned_session_id': assignedSessionId,
    'pickup_code': pickupCode,
    'tracking_token': trackingToken,
    'status': status,
    'payment_status': paymentStatus,
    'payment_mode': paymentMode,
    'customer_note': customerNote,
    'reject_reason': rejectReason,
    'total_amount': totalAmount,
    'version': version,
    'created_at': createdAt.toIso8601String(),
    'expires_at': expiresAt?.toIso8601String(),
    'items': items.map((it) => it.toMap()).toList(),
  };

  QrRequestModel copyWith({
    String? id,
    String? storeId,
    String? channelId,
    String? type,
    String? tableHint,
    String? assignedTableId,
    String? assignedTableName,
    String? assignedSessionId,
    String? pickupCode,
    String? trackingToken,
    String? status,
    String? paymentStatus,
    String? paymentMode,
    String? customerNote,
    String? rejectReason,
    double? totalAmount,
    int? version,
    DateTime? createdAt,
    DateTime? expiresAt,
    List<QrRequestItemModel>? items,
  }) {
    return QrRequestModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      channelId: channelId ?? this.channelId,
      type: type ?? this.type,
      tableHint: tableHint ?? this.tableHint,
      assignedTableId: assignedTableId ?? this.assignedTableId,
      assignedTableName: assignedTableName ?? this.assignedTableName,
      assignedSessionId: assignedSessionId ?? this.assignedSessionId,
      pickupCode: pickupCode ?? this.pickupCode,
      trackingToken: trackingToken ?? this.trackingToken,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMode: paymentMode ?? this.paymentMode,
      customerNote: customerNote ?? this.customerNote,
      rejectReason: rejectReason ?? this.rejectReason,
      totalAmount: totalAmount ?? this.totalAmount,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      items: items ?? this.items,
    );
  }
}

/// Tiện ích xử lý và định dạng URL công khai cho QR Order V4
class QrUrlBuilder {
  static String normalizeUrl(String url) {
    var trimmed = url.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static bool isValidPublicUrl(String? url) {
    if (url == null) return false;
    final normalized = normalizeUrl(url);
    if (normalized.isEmpty) return false;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return false;
    if (uri.scheme != 'https') return false;

    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host == '127.0.0.1' ||
        host.startsWith('192.168.') ||
        host.startsWith('10.')) {
      return false;
    }
    return true;
  }

  static String formatQrUrl(String baseUrl, String channelCode) {
    var trimmed = baseUrl.trim();
    if (trimmed.contains('{code}')) {
      return trimmed.replaceAll('{code}', channelCode);
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    if (trimmed.contains('/#')) {
      trimmed = trimmed.substring(0, trimmed.indexOf('/#'));
    }
    // Giữ nguyên /pos nếu là base path deploy; chỉ loại bỏ subpath trùng
    final subpathsToStrip = ['/goi-mon', '/menu', '/qr_order'];
    for (final sub in subpathsToStrip) {
      if (trimmed.endsWith(sub)) {
        trimmed = trimmed.substring(0, trimmed.length - sub.length);
        break;
      }
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return '$trimmed/goi-mon/?code=$channelCode';
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
