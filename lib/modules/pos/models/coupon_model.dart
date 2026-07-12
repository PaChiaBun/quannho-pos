class CouponModel {
  final String id;
  final String storeId;
  final String code;
  final String? description;
  final String discountType; // 'percent' | 'fixed'
  final double value;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final bool isActive;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;

  CouponModel({
    required this.id,
    required this.storeId,
    required this.code,
    this.description,
    required this.discountType,
    required this.value,
    required this.minOrderAmount,
    this.maxDiscountAmount,
    required this.isActive,
    this.startDate,
    this.endDate,
    required this.createdAt,
  });

  factory CouponModel.fromMap(Map<String, dynamic> map) {
    return CouponModel(
      id: map['id'] as String,
      storeId: map['store_id'] as String,
      code: map['code'] as String,
      description: map['description'] as String?,
      discountType: map['discount_type'] as String,
      value: (map['value'] as num).toDouble(),
      minOrderAmount: (map['min_order_amount'] as num?)?.toDouble() ?? 0.0,
      maxDiscountAmount: (map['max_discount_amount'] as num?)?.toDouble(),
      isActive: map['is_active'] as bool? ?? true,
      startDate: map['start_date'] != null ? DateTime.parse(map['start_date'] as String) : null,
      endDate: map['end_date'] != null ? DateTime.parse(map['end_date'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'store_id': storeId,
      'code': code,
      'description': description,
      'discount_type': discountType,
      'value': value,
      'min_order_amount': minOrderAmount,
      'max_discount_amount': maxDiscountAmount,
      'is_active': isActive,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }
}
