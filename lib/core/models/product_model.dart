// lib/core/models/product_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT MODEL
// Quản lý thông tin sản phẩm và trạng thái kinh doanh trong Quán Nhỏ POS/Kho.
// ─────────────────────────────────────────────────────────────────────────────

class ProductModel {
  final String id;
  final String storeId;
  final String name;
  final String? sku;
  final String? category;
  final String unit;
  final String productType;
  final double stockQty;
  final double minStock;
  final double sellPrice;
  final double costPrice;
  final double costPriceLatest; // ‼️ FIX: giá nhập mới nhất (từ purchase_orders)
  final String? imageUrl;
  final String stationCode;
  final bool isAvailable;
  final bool isActive;
  final bool isDeleted;
  final bool isTopping; // true = đây là topping (bán riêng + gắn vào món)
  final String toppingUnit; // đơn vị khi chọn topping: "viên", "phần", "ml"...
  final int? updatedAt;

  const ProductModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.sku,
    this.category,
    required this.unit,
    required this.productType,
    required this.stockQty,
    required this.minStock,
    required this.sellPrice,
    required this.costPrice,
    this.costPriceLatest = 0,
    this.imageUrl,
    required this.stationCode,
    required this.isAvailable,
    required this.isActive,
    required this.isDeleted,
    this.isTopping = false,
    this.toppingUnit = 'phần',
    this.updatedAt,
  });

  factory ProductModel.fromMap(Map<String, dynamic> m) => ProductModel(
        id: m['id'] as String,
        storeId: m['store_id'] as String? ?? '',
        name: m['name'] as String,
        sku: m['sku'] as String?,
        category: m['category'] as String?,
        unit: m['unit'] as String? ?? 'phần',
        productType: m['product_type'] as String? ?? 'finished',
        stockQty: (m['stock_qty'] as num?)?.toDouble() ?? 0,
        minStock: (m['min_stock'] as num?)?.toDouble() ?? 0,
        sellPrice: (m['sell_price'] as num?)?.toDouble() ?? 0,
        costPrice: (m['cost_price'] as num?)?.toDouble() ?? 0,
        costPriceLatest: (m['cost_price_latest'] as num?)?.toDouble() ?? 0,
        imageUrl: m['image_url'] as String?,
        stationCode: m['station_code'] as String? ?? 'nong',
        isAvailable: m['is_available'] as bool? ?? true,
        isActive: m['is_active'] as bool? ?? true,
        isDeleted: m['is_deleted'] as bool? ?? false,
        isTopping: m['is_topping'] as bool? ?? false,
        toppingUnit: m['topping_unit'] as String? ?? 'phần',
        updatedAt: m['updated_at'] != null
            ? (m['updated_at'] is int
                ? m['updated_at'] as int
                : int.tryParse(m['updated_at'].toString()))
            : null,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'store_id': storeId,
        'name': name,
        'sku': sku,
        'category': category,
        'unit': unit,
        'product_type': productType,
        'stock_qty': stockQty,
        'min_stock': minStock,
        'sell_price': sellPrice,
        'cost_price': costPrice,
        'cost_price_latest': costPriceLatest,
        'image_url': imageUrl,
        'station_code': stationCode,
        'is_available': isAvailable,
        'is_active': isActive,
        'is_deleted': isDeleted,
        'is_topping': isTopping,
        'topping_unit': toppingUnit,
        if (updatedAt != null) 'updated_at': updatedAt,
      };

  ProductModel copyWith({
    String? id,
    String? storeId,
    String? name,
    String? sku,
    String? category,
    String? unit,
    String? productType,
    double? stockQty,
    double? minStock,
    double? sellPrice,
    double? costPrice,
    double? costPriceLatest,
    String? imageUrl,
    String? stationCode,
    bool? isAvailable,
    bool? isActive,
    bool? isDeleted,
    bool? isTopping,
    String? toppingUnit,
    int? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      productType: productType ?? this.productType,
      stockQty: stockQty ?? this.stockQty,
      minStock: minStock ?? this.minStock,
      sellPrice: sellPrice ?? this.sellPrice,
      costPrice: costPrice ?? this.costPrice,
      costPriceLatest: costPriceLatest ?? this.costPriceLatest,
      imageUrl: imageUrl ?? this.imageUrl,
      stationCode: stationCode ?? this.stationCode,
      isAvailable: isAvailable ?? this.isAvailable,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      isTopping: isTopping ?? this.isTopping,
      toppingUnit: toppingUnit ?? this.toppingUnit,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
