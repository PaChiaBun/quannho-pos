class QrOrderSettingsModel {
  final bool isTableEnabled;
  final bool isCounterEnabled;
  final String customBaseUrl;

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

class QrChannelModel {
  final String id;
  final String storeId;
  final String type; // 'table' | 'counter'
  final String? tableId;
  final String channelCode;
  final String name;
  final bool isActive;
  final DateTime createdAt;

  const QrChannelModel({
    required this.id,
    required this.storeId,
    required this.type,
    this.tableId,
    required this.channelCode,
    required this.name,
    required this.isActive,
    required this.createdAt,
  });

  factory QrChannelModel.fromMap(Map<String, dynamic> m) {
    return QrChannelModel(
      id: m['id'] as String? ?? '',
      storeId: m['store_id'] as String? ?? '',
      type: m['type'] as String? ?? 'table',
      tableId: m['table_id'] as String?,
      channelCode: m['channel_code'] as String? ?? '',
      name: m['name'] as String? ?? '',
      isActive: m['is_active'] as bool? ?? true,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'store_id': storeId,
    'type': type,
    'table_id': tableId,
    'channel_code': channelCode,
    'name': name,
    'is_active': isActive,
    'created_at': createdAt.toIso8601String(),
  };

  QrChannelModel copyWith({
    String? id,
    String? storeId,
    String? type,
    String? tableId,
    String? channelCode,
    String? name,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return QrChannelModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      type: type ?? this.type,
      tableId: tableId ?? this.tableId,
      channelCode: channelCode ?? this.channelCode,
      name: name ?? this.name,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class QrRequestItemModel {
  final String id;
  final String requestId;
  final String productId;
  final String productName;
  final double unitPrice;
  final int quantity;
  final String modifiersJson;
  final String note;

  const QrRequestItemModel({
    required this.id,
    required this.requestId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    this.modifiersJson = '[]',
    this.note = '',
  });

  factory QrRequestItemModel.fromMap(Map<String, dynamic> m) {
    return QrRequestItemModel(
      id: m['id'] as String? ?? '',
      requestId: m['request_id'] as String? ?? '',
      productId: m['product_id'] as String? ?? '',
      productName: m['product_name'] as String? ?? '',
      unitPrice: (m['unit_price'] as num?)?.toDouble() ?? 0.0,
      quantity: m['quantity'] as int? ?? 1,
      modifiersJson: m['modifiers_json'] as String? ?? '[]',
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
    String? modifiersJson,
    String? note,
  }) {
    return QrRequestItemModel(
      id: id ?? this.id,
      requestId: requestId ?? this.requestId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      modifiersJson: modifiersJson ?? this.modifiersJson,
      note: note ?? this.note,
    );
  }
}

class QrRequestModel {
  final String id;
  final String storeId;
  final String channelId;
  final String type; // 'table' | 'counter'
  final String? tableId;
  final String tableName;
  final String? pickupCode;
  final String trackingToken;
  final String
  status; // 'pending_staff' | 'processing' | 'sent_kitchen' | 'rejected' | 'expired'
  final String note;
  final double totalAmount;
  final DateTime createdAt;
  final List<QrRequestItemModel> items;

  const QrRequestModel({
    required this.id,
    required this.storeId,
    required this.channelId,
    required this.type,
    this.tableId,
    this.tableName = '',
    this.pickupCode,
    required this.trackingToken,
    required this.status,
    this.note = '',
    required this.totalAmount,
    required this.createdAt,
    this.items = const [],
  });

  factory QrRequestModel.fromMap(Map<String, dynamic> m) {
    final rawItems = m['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((it) => QrRequestItemModel.fromMap(it as Map<String, dynamic>))
        .toList();

    return QrRequestModel(
      id: m['id'] as String? ?? '',
      storeId: m['store_id'] as String? ?? '',
      channelId: m['channel_id'] as String? ?? '',
      type: m['type'] as String? ?? 'table',
      tableId: m['table_id'] as String?,
      tableName: m['table_name'] as String? ?? '',
      pickupCode: m['pickup_code'] as String?,
      trackingToken: m['tracking_token'] as String? ?? '',
      status: m['status'] as String? ?? 'pending_staff',
      note: m['note'] as String? ?? '',
      totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: m['created_at'] != null
          ? DateTime.parse(m['created_at'] as String)
          : DateTime.now(),
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
    'note': note,
    'total_amount': totalAmount,
    'created_at': createdAt.toIso8601String(),
    'items': items.map((it) => it.toMap()).toList(),
  };

  QrRequestModel copyWith({
    String? id,
    String? storeId,
    String? channelId,
    String? type,
    String? tableId,
    String? tableName,
    String? pickupCode,
    String? trackingToken,
    String? status,
    String? note,
    double? totalAmount,
    DateTime? createdAt,
    List<QrRequestItemModel>? items,
  }) {
    return QrRequestModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      channelId: channelId ?? this.channelId,
      type: type ?? this.type,
      tableId: tableId ?? this.tableId,
      tableName: tableName ?? this.tableName,
      pickupCode: pickupCode ?? this.pickupCode,
      trackingToken: trackingToken ?? this.trackingToken,
      status: status ?? this.status,
      note: note ?? this.note,
      totalAmount: totalAmount ?? this.totalAmount,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }
}
