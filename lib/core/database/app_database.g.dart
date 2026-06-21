// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ModuleConfigsTable extends ModuleConfigs
    with TableInfo<$ModuleConfigsTable, ModuleConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ModuleConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, isActive, position, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'module_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ModuleConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ModuleConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ModuleConfig(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $ModuleConfigsTable createAlias(String alias) {
    return $ModuleConfigsTable(attachedDatabase, alias);
  }
}

class ModuleConfig extends DataClass implements Insertable<ModuleConfig> {
  final String id;
  final bool isActive;
  final int position;
  final int? updatedAt;
  const ModuleConfig({
    required this.id,
    required this.isActive,
    required this.position,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['is_active'] = Variable<bool>(isActive);
    map['position'] = Variable<int>(position);
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  ModuleConfigsCompanion toCompanion(bool nullToAbsent) {
    return ModuleConfigsCompanion(
      id: Value(id),
      isActive: Value(isActive),
      position: Value(position),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory ModuleConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ModuleConfig(
      id: serializer.fromJson<String>(json['id']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      position: serializer.fromJson<int>(json['position']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'isActive': serializer.toJson<bool>(isActive),
      'position': serializer.toJson<int>(position),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  ModuleConfig copyWith({
    String? id,
    bool? isActive,
    int? position,
    Value<int?> updatedAt = const Value.absent(),
  }) => ModuleConfig(
    id: id ?? this.id,
    isActive: isActive ?? this.isActive,
    position: position ?? this.position,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  ModuleConfig copyWithCompanion(ModuleConfigsCompanion data) {
    return ModuleConfig(
      id: data.id.present ? data.id.value : this.id,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      position: data.position.present ? data.position.value : this.position,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ModuleConfig(')
          ..write('id: $id, ')
          ..write('isActive: $isActive, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, isActive, position, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ModuleConfig &&
          other.id == this.id &&
          other.isActive == this.isActive &&
          other.position == this.position &&
          other.updatedAt == this.updatedAt);
}

class ModuleConfigsCompanion extends UpdateCompanion<ModuleConfig> {
  final Value<String> id;
  final Value<bool> isActive;
  final Value<int> position;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const ModuleConfigsCompanion({
    this.id = const Value.absent(),
    this.isActive = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ModuleConfigsCompanion.insert({
    required String id,
    this.isActive = const Value.absent(),
    this.position = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id);
  static Insertable<ModuleConfig> custom({
    Expression<String>? id,
    Expression<bool>? isActive,
    Expression<int>? position,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (isActive != null) 'is_active': isActive,
      if (position != null) 'position': position,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ModuleConfigsCompanion copyWith({
    Value<String>? id,
    Value<bool>? isActive,
    Value<int>? position,
    Value<int?>? updatedAt,
    Value<int>? rowid,
  }) {
    return ModuleConfigsCompanion(
      id: id ?? this.id,
      isActive: isActive ?? this.isActive,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ModuleConfigsCompanion(')
          ..write('id: $id, ')
          ..write('isActive: $isActive, ')
          ..write('position: $position, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoreProductsTable extends CoreProducts
    with TableInfo<$CoreProductsTable, CoreProduct> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoreProductsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skuMeta = const VerificationMeta('sku');
  @override
  late final GeneratedColumn<String> sku = GeneratedColumn<String>(
    'sku',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('phần'),
  );
  static const VerificationMeta _productTypeMeta = const VerificationMeta(
    'productType',
  );
  @override
  late final GeneratedColumn<String> productType = GeneratedColumn<String>(
    'product_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('finished'),
  );
  static const VerificationMeta _stockQtyMeta = const VerificationMeta(
    'stockQty',
  );
  @override
  late final GeneratedColumn<double> stockQty = GeneratedColumn<double>(
    'stock_qty',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _minStockMeta = const VerificationMeta(
    'minStock',
  );
  @override
  late final GeneratedColumn<double> minStock = GeneratedColumn<double>(
    'min_stock',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sellPriceMeta = const VerificationMeta(
    'sellPrice',
  );
  @override
  late final GeneratedColumn<double> sellPrice = GeneratedColumn<double>(
    'sell_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<double> costPrice = GeneratedColumn<double>(
    'cost_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _imagePathMeta = const VerificationMeta(
    'imagePath',
  );
  @override
  late final GeneratedColumn<String> imagePath = GeneratedColumn<String>(
    'image_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAvailableMeta = const VerificationMeta(
    'isAvailable',
  );
  @override
  late final GeneratedColumn<bool> isAvailable = GeneratedColumn<bool>(
    'is_available',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_available" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    sku,
    category,
    unit,
    productType,
    stockQty,
    minStock,
    sellPrice,
    costPrice,
    imagePath,
    isAvailable,
    isActive,
    isDeleted,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'core_products';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoreProduct> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('sku')) {
      context.handle(
        _skuMeta,
        sku.isAcceptableOrUnknown(data['sku']!, _skuMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    }
    if (data.containsKey('product_type')) {
      context.handle(
        _productTypeMeta,
        productType.isAcceptableOrUnknown(
          data['product_type']!,
          _productTypeMeta,
        ),
      );
    }
    if (data.containsKey('stock_qty')) {
      context.handle(
        _stockQtyMeta,
        stockQty.isAcceptableOrUnknown(data['stock_qty']!, _stockQtyMeta),
      );
    }
    if (data.containsKey('min_stock')) {
      context.handle(
        _minStockMeta,
        minStock.isAcceptableOrUnknown(data['min_stock']!, _minStockMeta),
      );
    }
    if (data.containsKey('sell_price')) {
      context.handle(
        _sellPriceMeta,
        sellPrice.isAcceptableOrUnknown(data['sell_price']!, _sellPriceMeta),
      );
    }
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    }
    if (data.containsKey('image_path')) {
      context.handle(
        _imagePathMeta,
        imagePath.isAcceptableOrUnknown(data['image_path']!, _imagePathMeta),
      );
    }
    if (data.containsKey('is_available')) {
      context.handle(
        _isAvailableMeta,
        isAvailable.isAcceptableOrUnknown(
          data['is_available']!,
          _isAvailableMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoreProduct map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoreProduct(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      sku: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sku'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
      productType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_type'],
      )!,
      stockQty: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}stock_qty'],
      )!,
      minStock: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}min_stock'],
      )!,
      sellPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sell_price'],
      )!,
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_price'],
      )!,
      imagePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_path'],
      ),
      isAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_available'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $CoreProductsTable createAlias(String alias) {
    return $CoreProductsTable(attachedDatabase, alias);
  }
}

class CoreProduct extends DataClass implements Insertable<CoreProduct> {
  final String id;
  final String name;
  final String? sku;
  final String? category;
  final String unit;
  final String productType;
  final double stockQty;
  final double minStock;
  final double sellPrice;
  final double costPrice;
  final String? imagePath;
  final bool isAvailable;
  final bool isActive;
  final bool isDeleted;
  final int version;
  final int? createdAt;
  final int? updatedAt;
  const CoreProduct({
    required this.id,
    required this.name,
    this.sku,
    this.category,
    required this.unit,
    required this.productType,
    required this.stockQty,
    required this.minStock,
    required this.sellPrice,
    required this.costPrice,
    this.imagePath,
    required this.isAvailable,
    required this.isActive,
    required this.isDeleted,
    required this.version,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || sku != null) {
      map['sku'] = Variable<String>(sku);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['unit'] = Variable<String>(unit);
    map['product_type'] = Variable<String>(productType);
    map['stock_qty'] = Variable<double>(stockQty);
    map['min_stock'] = Variable<double>(minStock);
    map['sell_price'] = Variable<double>(sellPrice);
    map['cost_price'] = Variable<double>(costPrice);
    if (!nullToAbsent || imagePath != null) {
      map['image_path'] = Variable<String>(imagePath);
    }
    map['is_available'] = Variable<bool>(isAvailable);
    map['is_active'] = Variable<bool>(isActive);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['version'] = Variable<int>(version);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  CoreProductsCompanion toCompanion(bool nullToAbsent) {
    return CoreProductsCompanion(
      id: Value(id),
      name: Value(name),
      sku: sku == null && nullToAbsent ? const Value.absent() : Value(sku),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      unit: Value(unit),
      productType: Value(productType),
      stockQty: Value(stockQty),
      minStock: Value(minStock),
      sellPrice: Value(sellPrice),
      costPrice: Value(costPrice),
      imagePath: imagePath == null && nullToAbsent
          ? const Value.absent()
          : Value(imagePath),
      isAvailable: Value(isAvailable),
      isActive: Value(isActive),
      isDeleted: Value(isDeleted),
      version: Value(version),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory CoreProduct.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoreProduct(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      sku: serializer.fromJson<String?>(json['sku']),
      category: serializer.fromJson<String?>(json['category']),
      unit: serializer.fromJson<String>(json['unit']),
      productType: serializer.fromJson<String>(json['productType']),
      stockQty: serializer.fromJson<double>(json['stockQty']),
      minStock: serializer.fromJson<double>(json['minStock']),
      sellPrice: serializer.fromJson<double>(json['sellPrice']),
      costPrice: serializer.fromJson<double>(json['costPrice']),
      imagePath: serializer.fromJson<String?>(json['imagePath']),
      isAvailable: serializer.fromJson<bool>(json['isAvailable']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'sku': serializer.toJson<String?>(sku),
      'category': serializer.toJson<String?>(category),
      'unit': serializer.toJson<String>(unit),
      'productType': serializer.toJson<String>(productType),
      'stockQty': serializer.toJson<double>(stockQty),
      'minStock': serializer.toJson<double>(minStock),
      'sellPrice': serializer.toJson<double>(sellPrice),
      'costPrice': serializer.toJson<double>(costPrice),
      'imagePath': serializer.toJson<String?>(imagePath),
      'isAvailable': serializer.toJson<bool>(isAvailable),
      'isActive': serializer.toJson<bool>(isActive),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  CoreProduct copyWith({
    String? id,
    String? name,
    Value<String?> sku = const Value.absent(),
    Value<String?> category = const Value.absent(),
    String? unit,
    String? productType,
    double? stockQty,
    double? minStock,
    double? sellPrice,
    double? costPrice,
    Value<String?> imagePath = const Value.absent(),
    bool? isAvailable,
    bool? isActive,
    bool? isDeleted,
    int? version,
    Value<int?> createdAt = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
  }) => CoreProduct(
    id: id ?? this.id,
    name: name ?? this.name,
    sku: sku.present ? sku.value : this.sku,
    category: category.present ? category.value : this.category,
    unit: unit ?? this.unit,
    productType: productType ?? this.productType,
    stockQty: stockQty ?? this.stockQty,
    minStock: minStock ?? this.minStock,
    sellPrice: sellPrice ?? this.sellPrice,
    costPrice: costPrice ?? this.costPrice,
    imagePath: imagePath.present ? imagePath.value : this.imagePath,
    isAvailable: isAvailable ?? this.isAvailable,
    isActive: isActive ?? this.isActive,
    isDeleted: isDeleted ?? this.isDeleted,
    version: version ?? this.version,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  CoreProduct copyWithCompanion(CoreProductsCompanion data) {
    return CoreProduct(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      sku: data.sku.present ? data.sku.value : this.sku,
      category: data.category.present ? data.category.value : this.category,
      unit: data.unit.present ? data.unit.value : this.unit,
      productType: data.productType.present
          ? data.productType.value
          : this.productType,
      stockQty: data.stockQty.present ? data.stockQty.value : this.stockQty,
      minStock: data.minStock.present ? data.minStock.value : this.minStock,
      sellPrice: data.sellPrice.present ? data.sellPrice.value : this.sellPrice,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      imagePath: data.imagePath.present ? data.imagePath.value : this.imagePath,
      isAvailable: data.isAvailable.present
          ? data.isAvailable.value
          : this.isAvailable,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoreProduct(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('productType: $productType, ')
          ..write('stockQty: $stockQty, ')
          ..write('minStock: $minStock, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('costPrice: $costPrice, ')
          ..write('imagePath: $imagePath, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('isActive: $isActive, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    sku,
    category,
    unit,
    productType,
    stockQty,
    minStock,
    sellPrice,
    costPrice,
    imagePath,
    isAvailable,
    isActive,
    isDeleted,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoreProduct &&
          other.id == this.id &&
          other.name == this.name &&
          other.sku == this.sku &&
          other.category == this.category &&
          other.unit == this.unit &&
          other.productType == this.productType &&
          other.stockQty == this.stockQty &&
          other.minStock == this.minStock &&
          other.sellPrice == this.sellPrice &&
          other.costPrice == this.costPrice &&
          other.imagePath == this.imagePath &&
          other.isAvailable == this.isAvailable &&
          other.isActive == this.isActive &&
          other.isDeleted == this.isDeleted &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CoreProductsCompanion extends UpdateCompanion<CoreProduct> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> sku;
  final Value<String?> category;
  final Value<String> unit;
  final Value<String> productType;
  final Value<double> stockQty;
  final Value<double> minStock;
  final Value<double> sellPrice;
  final Value<double> costPrice;
  final Value<String?> imagePath;
  final Value<bool> isAvailable;
  final Value<bool> isActive;
  final Value<bool> isDeleted;
  final Value<int> version;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const CoreProductsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.sku = const Value.absent(),
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    this.productType = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.minStock = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoreProductsCompanion.insert({
    required String id,
    required String name,
    this.sku = const Value.absent(),
    this.category = const Value.absent(),
    this.unit = const Value.absent(),
    this.productType = const Value.absent(),
    this.stockQty = const Value.absent(),
    this.minStock = const Value.absent(),
    this.sellPrice = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.imagePath = const Value.absent(),
    this.isAvailable = const Value.absent(),
    this.isActive = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CoreProduct> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? sku,
    Expression<String>? category,
    Expression<String>? unit,
    Expression<String>? productType,
    Expression<double>? stockQty,
    Expression<double>? minStock,
    Expression<double>? sellPrice,
    Expression<double>? costPrice,
    Expression<String>? imagePath,
    Expression<bool>? isAvailable,
    Expression<bool>? isActive,
    Expression<bool>? isDeleted,
    Expression<int>? version,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (sku != null) 'sku': sku,
      if (category != null) 'category': category,
      if (unit != null) 'unit': unit,
      if (productType != null) 'product_type': productType,
      if (stockQty != null) 'stock_qty': stockQty,
      if (minStock != null) 'min_stock': minStock,
      if (sellPrice != null) 'sell_price': sellPrice,
      if (costPrice != null) 'cost_price': costPrice,
      if (imagePath != null) 'image_path': imagePath,
      if (isAvailable != null) 'is_available': isAvailable,
      if (isActive != null) 'is_active': isActive,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoreProductsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? sku,
    Value<String?>? category,
    Value<String>? unit,
    Value<String>? productType,
    Value<double>? stockQty,
    Value<double>? minStock,
    Value<double>? sellPrice,
    Value<double>? costPrice,
    Value<String?>? imagePath,
    Value<bool>? isAvailable,
    Value<bool>? isActive,
    Value<bool>? isDeleted,
    Value<int>? version,
    Value<int?>? createdAt,
    Value<int?>? updatedAt,
    Value<int>? rowid,
  }) {
    return CoreProductsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      productType: productType ?? this.productType,
      stockQty: stockQty ?? this.stockQty,
      minStock: minStock ?? this.minStock,
      sellPrice: sellPrice ?? this.sellPrice,
      costPrice: costPrice ?? this.costPrice,
      imagePath: imagePath ?? this.imagePath,
      isAvailable: isAvailable ?? this.isAvailable,
      isActive: isActive ?? this.isActive,
      isDeleted: isDeleted ?? this.isDeleted,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (sku.present) {
      map['sku'] = Variable<String>(sku.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (productType.present) {
      map['product_type'] = Variable<String>(productType.value);
    }
    if (stockQty.present) {
      map['stock_qty'] = Variable<double>(stockQty.value);
    }
    if (minStock.present) {
      map['min_stock'] = Variable<double>(minStock.value);
    }
    if (sellPrice.present) {
      map['sell_price'] = Variable<double>(sellPrice.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<double>(costPrice.value);
    }
    if (imagePath.present) {
      map['image_path'] = Variable<String>(imagePath.value);
    }
    if (isAvailable.present) {
      map['is_available'] = Variable<bool>(isAvailable.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoreProductsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('sku: $sku, ')
          ..write('category: $category, ')
          ..write('unit: $unit, ')
          ..write('productType: $productType, ')
          ..write('stockQty: $stockQty, ')
          ..write('minStock: $minStock, ')
          ..write('sellPrice: $sellPrice, ')
          ..write('costPrice: $costPrice, ')
          ..write('imagePath: $imagePath, ')
          ..write('isAvailable: $isAvailable, ')
          ..write('isActive: $isActive, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CoreCustomersTable extends CoreCustomers
    with TableInfo<$CoreCustomersTable, CoreCustomer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CoreCustomersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _birthdayMeta = const VerificationMeta(
    'birthday',
  );
  @override
  late final GeneratedColumn<int> birthday = GeneratedColumn<int>(
    'birthday',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loyaltyPtsMeta = const VerificationMeta(
    'loyaltyPts',
  );
  @override
  late final GeneratedColumn<double> loyaltyPts = GeneratedColumn<double>(
    'loyalty_pts',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalSpentMeta = const VerificationMeta(
    'totalSpent',
  );
  @override
  late final GeneratedColumn<double> totalSpent = GeneratedColumn<double>(
    'total_spent',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _visitCountMeta = const VerificationMeta(
    'visitCount',
  );
  @override
  late final GeneratedColumn<int> visitCount = GeneratedColumn<int>(
    'visit_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    email,
    birthday,
    loyaltyPts,
    totalSpent,
    visitCount,
    note,
    isDeleted,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'core_customers';
  @override
  VerificationContext validateIntegrity(
    Insertable<CoreCustomer> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('birthday')) {
      context.handle(
        _birthdayMeta,
        birthday.isAcceptableOrUnknown(data['birthday']!, _birthdayMeta),
      );
    }
    if (data.containsKey('loyalty_pts')) {
      context.handle(
        _loyaltyPtsMeta,
        loyaltyPts.isAcceptableOrUnknown(data['loyalty_pts']!, _loyaltyPtsMeta),
      );
    }
    if (data.containsKey('total_spent')) {
      context.handle(
        _totalSpentMeta,
        totalSpent.isAcceptableOrUnknown(data['total_spent']!, _totalSpentMeta),
      );
    }
    if (data.containsKey('visit_count')) {
      context.handle(
        _visitCountMeta,
        visitCount.isAcceptableOrUnknown(data['visit_count']!, _visitCountMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CoreCustomer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CoreCustomer(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      birthday: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}birthday'],
      ),
      loyaltyPts: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}loyalty_pts'],
      )!,
      totalSpent: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_spent'],
      )!,
      visitCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}visit_count'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $CoreCustomersTable createAlias(String alias) {
    return $CoreCustomersTable(attachedDatabase, alias);
  }
}

class CoreCustomer extends DataClass implements Insertable<CoreCustomer> {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final int? birthday;
  final double loyaltyPts;
  final double totalSpent;
  final int visitCount;
  final String? note;
  final bool isDeleted;
  final int? createdAt;
  final int? updatedAt;
  const CoreCustomer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.birthday,
    required this.loyaltyPts,
    required this.totalSpent,
    required this.visitCount,
    this.note,
    required this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || birthday != null) {
      map['birthday'] = Variable<int>(birthday);
    }
    map['loyalty_pts'] = Variable<double>(loyaltyPts);
    map['total_spent'] = Variable<double>(totalSpent);
    map['visit_count'] = Variable<int>(visitCount);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<int>(updatedAt);
    }
    return map;
  }

  CoreCustomersCompanion toCompanion(bool nullToAbsent) {
    return CoreCustomersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      birthday: birthday == null && nullToAbsent
          ? const Value.absent()
          : Value(birthday),
      loyaltyPts: Value(loyaltyPts),
      totalSpent: Value(totalSpent),
      visitCount: Value(visitCount),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isDeleted: Value(isDeleted),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory CoreCustomer.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CoreCustomer(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      email: serializer.fromJson<String?>(json['email']),
      birthday: serializer.fromJson<int?>(json['birthday']),
      loyaltyPts: serializer.fromJson<double>(json['loyaltyPts']),
      totalSpent: serializer.fromJson<double>(json['totalSpent']),
      visitCount: serializer.fromJson<int>(json['visitCount']),
      note: serializer.fromJson<String?>(json['note']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
      updatedAt: serializer.fromJson<int?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'email': serializer.toJson<String?>(email),
      'birthday': serializer.toJson<int?>(birthday),
      'loyaltyPts': serializer.toJson<double>(loyaltyPts),
      'totalSpent': serializer.toJson<double>(totalSpent),
      'visitCount': serializer.toJson<int>(visitCount),
      'note': serializer.toJson<String?>(note),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'createdAt': serializer.toJson<int?>(createdAt),
      'updatedAt': serializer.toJson<int?>(updatedAt),
    };
  }

  CoreCustomer copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<int?> birthday = const Value.absent(),
    double? loyaltyPts,
    double? totalSpent,
    int? visitCount,
    Value<String?> note = const Value.absent(),
    bool? isDeleted,
    Value<int?> createdAt = const Value.absent(),
    Value<int?> updatedAt = const Value.absent(),
  }) => CoreCustomer(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    email: email.present ? email.value : this.email,
    birthday: birthday.present ? birthday.value : this.birthday,
    loyaltyPts: loyaltyPts ?? this.loyaltyPts,
    totalSpent: totalSpent ?? this.totalSpent,
    visitCount: visitCount ?? this.visitCount,
    note: note.present ? note.value : this.note,
    isDeleted: isDeleted ?? this.isDeleted,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  CoreCustomer copyWithCompanion(CoreCustomersCompanion data) {
    return CoreCustomer(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      email: data.email.present ? data.email.value : this.email,
      birthday: data.birthday.present ? data.birthday.value : this.birthday,
      loyaltyPts: data.loyaltyPts.present
          ? data.loyaltyPts.value
          : this.loyaltyPts,
      totalSpent: data.totalSpent.present
          ? data.totalSpent.value
          : this.totalSpent,
      visitCount: data.visitCount.present
          ? data.visitCount.value
          : this.visitCount,
      note: data.note.present ? data.note.value : this.note,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CoreCustomer(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('birthday: $birthday, ')
          ..write('loyaltyPts: $loyaltyPts, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('visitCount: $visitCount, ')
          ..write('note: $note, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    phone,
    email,
    birthday,
    loyaltyPts,
    totalSpent,
    visitCount,
    note,
    isDeleted,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CoreCustomer &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.email == this.email &&
          other.birthday == this.birthday &&
          other.loyaltyPts == this.loyaltyPts &&
          other.totalSpent == this.totalSpent &&
          other.visitCount == this.visitCount &&
          other.note == this.note &&
          other.isDeleted == this.isDeleted &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class CoreCustomersCompanion extends UpdateCompanion<CoreCustomer> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> email;
  final Value<int?> birthday;
  final Value<double> loyaltyPts;
  final Value<double> totalSpent;
  final Value<int> visitCount;
  final Value<String?> note;
  final Value<bool> isDeleted;
  final Value<int?> createdAt;
  final Value<int?> updatedAt;
  final Value<int> rowid;
  const CoreCustomersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.birthday = const Value.absent(),
    this.loyaltyPts = const Value.absent(),
    this.totalSpent = const Value.absent(),
    this.visitCount = const Value.absent(),
    this.note = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CoreCustomersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.email = const Value.absent(),
    this.birthday = const Value.absent(),
    this.loyaltyPts = const Value.absent(),
    this.totalSpent = const Value.absent(),
    this.visitCount = const Value.absent(),
    this.note = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<CoreCustomer> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? email,
    Expression<int>? birthday,
    Expression<double>? loyaltyPts,
    Expression<double>? totalSpent,
    Expression<int>? visitCount,
    Expression<String>? note,
    Expression<bool>? isDeleted,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      if (birthday != null) 'birthday': birthday,
      if (loyaltyPts != null) 'loyalty_pts': loyaltyPts,
      if (totalSpent != null) 'total_spent': totalSpent,
      if (visitCount != null) 'visit_count': visitCount,
      if (note != null) 'note': note,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CoreCustomersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? email,
    Value<int?>? birthday,
    Value<double>? loyaltyPts,
    Value<double>? totalSpent,
    Value<int>? visitCount,
    Value<String?>? note,
    Value<bool>? isDeleted,
    Value<int?>? createdAt,
    Value<int?>? updatedAt,
    Value<int>? rowid,
  }) {
    return CoreCustomersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      birthday: birthday ?? this.birthday,
      loyaltyPts: loyaltyPts ?? this.loyaltyPts,
      totalSpent: totalSpent ?? this.totalSpent,
      visitCount: visitCount ?? this.visitCount,
      note: note ?? this.note,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (birthday.present) {
      map['birthday'] = Variable<int>(birthday.value);
    }
    if (loyaltyPts.present) {
      map['loyalty_pts'] = Variable<double>(loyaltyPts.value);
    }
    if (totalSpent.present) {
      map['total_spent'] = Variable<double>(totalSpent.value);
    }
    if (visitCount.present) {
      map['visit_count'] = Variable<int>(visitCount.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CoreCustomersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('email: $email, ')
          ..write('birthday: $birthday, ')
          ..write('loyaltyPts: $loyaltyPts, ')
          ..write('totalSpent: $totalSpent, ')
          ..write('visitCount: $visitCount, ')
          ..write('note: $note, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, AppSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSetting> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSetting(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class AppSetting extends DataClass implements Insertable<AppSetting> {
  final String key;
  final String value;
  const AppSetting({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(key: Value(key), value: Value(value));
  }

  factory AppSetting.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSetting(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppSetting copyWith({String? key, String? value}) =>
      AppSetting(key: key ?? this.key, value: value ?? this.value);
  AppSetting copyWithCompanion(AppSettingsCompanion data) {
    return AppSetting(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSetting(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSetting &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<AppSetting> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppSetting> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EventsLogTable extends EventsLog
    with TableInfo<$EventsLogTable, EventsLogData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EventsLogTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventTypeMeta = const VerificationMeta(
    'eventType',
  );
  @override
  late final GeneratedColumn<String> eventType = GeneratedColumn<String>(
    'event_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceModuleMeta = const VerificationMeta(
    'sourceModule',
  );
  @override
  late final GeneratedColumn<String> sourceModule = GeneratedColumn<String>(
    'source_module',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventType,
    sourceModule,
    payload,
    createdAt,
    idempotencyKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'events_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<EventsLogData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_type')) {
      context.handle(
        _eventTypeMeta,
        eventType.isAcceptableOrUnknown(data['event_type']!, _eventTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_eventTypeMeta);
    }
    if (data.containsKey('source_module')) {
      context.handle(
        _sourceModuleMeta,
        sourceModule.isAcceptableOrUnknown(
          data['source_module']!,
          _sourceModuleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceModuleMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EventsLogData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EventsLogData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_type'],
      )!,
      sourceModule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_module'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      ),
    );
  }

  @override
  $EventsLogTable createAlias(String alias) {
    return $EventsLogTable(attachedDatabase, alias);
  }
}

class EventsLogData extends DataClass implements Insertable<EventsLogData> {
  final String id;
  final String eventType;
  final String sourceModule;
  final String payload;
  final int createdAt;
  final String? idempotencyKey;
  const EventsLogData({
    required this.id,
    required this.eventType,
    required this.sourceModule,
    required this.payload,
    required this.createdAt,
    this.idempotencyKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_type'] = Variable<String>(eventType);
    map['source_module'] = Variable<String>(sourceModule);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<int>(createdAt);
    if (!nullToAbsent || idempotencyKey != null) {
      map['idempotency_key'] = Variable<String>(idempotencyKey);
    }
    return map;
  }

  EventsLogCompanion toCompanion(bool nullToAbsent) {
    return EventsLogCompanion(
      id: Value(id),
      eventType: Value(eventType),
      sourceModule: Value(sourceModule),
      payload: Value(payload),
      createdAt: Value(createdAt),
      idempotencyKey: idempotencyKey == null && nullToAbsent
          ? const Value.absent()
          : Value(idempotencyKey),
    );
  }

  factory EventsLogData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EventsLogData(
      id: serializer.fromJson<String>(json['id']),
      eventType: serializer.fromJson<String>(json['eventType']),
      sourceModule: serializer.fromJson<String>(json['sourceModule']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      idempotencyKey: serializer.fromJson<String?>(json['idempotencyKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventType': serializer.toJson<String>(eventType),
      'sourceModule': serializer.toJson<String>(sourceModule),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<int>(createdAt),
      'idempotencyKey': serializer.toJson<String?>(idempotencyKey),
    };
  }

  EventsLogData copyWith({
    String? id,
    String? eventType,
    String? sourceModule,
    String? payload,
    int? createdAt,
    Value<String?> idempotencyKey = const Value.absent(),
  }) => EventsLogData(
    id: id ?? this.id,
    eventType: eventType ?? this.eventType,
    sourceModule: sourceModule ?? this.sourceModule,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    idempotencyKey: idempotencyKey.present
        ? idempotencyKey.value
        : this.idempotencyKey,
  );
  EventsLogData copyWithCompanion(EventsLogCompanion data) {
    return EventsLogData(
      id: data.id.present ? data.id.value : this.id,
      eventType: data.eventType.present ? data.eventType.value : this.eventType,
      sourceModule: data.sourceModule.present
          ? data.sourceModule.value
          : this.sourceModule,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EventsLogData(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('sourceModule: $sourceModule, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('idempotencyKey: $idempotencyKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventType,
    sourceModule,
    payload,
    createdAt,
    idempotencyKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EventsLogData &&
          other.id == this.id &&
          other.eventType == this.eventType &&
          other.sourceModule == this.sourceModule &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.idempotencyKey == this.idempotencyKey);
}

class EventsLogCompanion extends UpdateCompanion<EventsLogData> {
  final Value<String> id;
  final Value<String> eventType;
  final Value<String> sourceModule;
  final Value<String> payload;
  final Value<int> createdAt;
  final Value<String?> idempotencyKey;
  final Value<int> rowid;
  const EventsLogCompanion({
    this.id = const Value.absent(),
    this.eventType = const Value.absent(),
    this.sourceModule = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EventsLogCompanion.insert({
    required String id,
    required String eventType,
    required String sourceModule,
    required String payload,
    required int createdAt,
    this.idempotencyKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventType = Value(eventType),
       sourceModule = Value(sourceModule),
       payload = Value(payload),
       createdAt = Value(createdAt);
  static Insertable<EventsLogData> custom({
    Expression<String>? id,
    Expression<String>? eventType,
    Expression<String>? sourceModule,
    Expression<String>? payload,
    Expression<int>? createdAt,
    Expression<String>? idempotencyKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventType != null) 'event_type': eventType,
      if (sourceModule != null) 'source_module': sourceModule,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EventsLogCompanion copyWith({
    Value<String>? id,
    Value<String>? eventType,
    Value<String>? sourceModule,
    Value<String>? payload,
    Value<int>? createdAt,
    Value<String?>? idempotencyKey,
    Value<int>? rowid,
  }) {
    return EventsLogCompanion(
      id: id ?? this.id,
      eventType: eventType ?? this.eventType,
      sourceModule: sourceModule ?? this.sourceModule,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventType.present) {
      map['event_type'] = Variable<String>(eventType.value);
    }
    if (sourceModule.present) {
      map['source_module'] = Variable<String>(sourceModule.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EventsLogCompanion(')
          ..write('id: $id, ')
          ..write('eventType: $eventType, ')
          ..write('sourceModule: $sourceModule, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingEventsTable extends PendingEvents
    with TableInfo<$PendingEventsTable, PendingEvent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES events_log (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _targetModuleMeta = const VerificationMeta(
    'targetModule',
  );
  @override
  late final GeneratedColumn<String> targetModule = GeneratedColumn<String>(
    'target_module',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _processedAtMeta = const VerificationMeta(
    'processedAt',
  );
  @override
  late final GeneratedColumn<int> processedAt = GeneratedColumn<int>(
    'processed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMsgMeta = const VerificationMeta(
    'errorMsg',
  );
  @override
  late final GeneratedColumn<String> errorMsg = GeneratedColumn<String>(
    'error_msg',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    targetModule,
    retryCount,
    processedAt,
    errorMsg,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingEvent> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('target_module')) {
      context.handle(
        _targetModuleMeta,
        targetModule.isAcceptableOrUnknown(
          data['target_module']!,
          _targetModuleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetModuleMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('processed_at')) {
      context.handle(
        _processedAtMeta,
        processedAt.isAcceptableOrUnknown(
          data['processed_at']!,
          _processedAtMeta,
        ),
      );
    }
    if (data.containsKey('error_msg')) {
      context.handle(
        _errorMsgMeta,
        errorMsg.isAcceptableOrUnknown(data['error_msg']!, _errorMsgMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingEvent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingEvent(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      targetModule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_module'],
      )!,
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      processedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}processed_at'],
      ),
      errorMsg: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_msg'],
      ),
    );
  }

  @override
  $PendingEventsTable createAlias(String alias) {
    return $PendingEventsTable(attachedDatabase, alias);
  }
}

class PendingEvent extends DataClass implements Insertable<PendingEvent> {
  final String id;
  final String eventId;
  final String targetModule;
  final int retryCount;
  final int? processedAt;
  final String? errorMsg;
  const PendingEvent({
    required this.id,
    required this.eventId,
    required this.targetModule,
    required this.retryCount,
    this.processedAt,
    this.errorMsg,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_id'] = Variable<String>(eventId);
    map['target_module'] = Variable<String>(targetModule);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || processedAt != null) {
      map['processed_at'] = Variable<int>(processedAt);
    }
    if (!nullToAbsent || errorMsg != null) {
      map['error_msg'] = Variable<String>(errorMsg);
    }
    return map;
  }

  PendingEventsCompanion toCompanion(bool nullToAbsent) {
    return PendingEventsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      targetModule: Value(targetModule),
      retryCount: Value(retryCount),
      processedAt: processedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(processedAt),
      errorMsg: errorMsg == null && nullToAbsent
          ? const Value.absent()
          : Value(errorMsg),
    );
  }

  factory PendingEvent.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingEvent(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      targetModule: serializer.fromJson<String>(json['targetModule']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      processedAt: serializer.fromJson<int?>(json['processedAt']),
      errorMsg: serializer.fromJson<String?>(json['errorMsg']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String>(eventId),
      'targetModule': serializer.toJson<String>(targetModule),
      'retryCount': serializer.toJson<int>(retryCount),
      'processedAt': serializer.toJson<int?>(processedAt),
      'errorMsg': serializer.toJson<String?>(errorMsg),
    };
  }

  PendingEvent copyWith({
    String? id,
    String? eventId,
    String? targetModule,
    int? retryCount,
    Value<int?> processedAt = const Value.absent(),
    Value<String?> errorMsg = const Value.absent(),
  }) => PendingEvent(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    targetModule: targetModule ?? this.targetModule,
    retryCount: retryCount ?? this.retryCount,
    processedAt: processedAt.present ? processedAt.value : this.processedAt,
    errorMsg: errorMsg.present ? errorMsg.value : this.errorMsg,
  );
  PendingEvent copyWithCompanion(PendingEventsCompanion data) {
    return PendingEvent(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      targetModule: data.targetModule.present
          ? data.targetModule.value
          : this.targetModule,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      processedAt: data.processedAt.present
          ? data.processedAt.value
          : this.processedAt,
      errorMsg: data.errorMsg.present ? data.errorMsg.value : this.errorMsg,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingEvent(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('targetModule: $targetModule, ')
          ..write('retryCount: $retryCount, ')
          ..write('processedAt: $processedAt, ')
          ..write('errorMsg: $errorMsg')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, eventId, targetModule, retryCount, processedAt, errorMsg);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingEvent &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.targetModule == this.targetModule &&
          other.retryCount == this.retryCount &&
          other.processedAt == this.processedAt &&
          other.errorMsg == this.errorMsg);
}

class PendingEventsCompanion extends UpdateCompanion<PendingEvent> {
  final Value<String> id;
  final Value<String> eventId;
  final Value<String> targetModule;
  final Value<int> retryCount;
  final Value<int?> processedAt;
  final Value<String?> errorMsg;
  final Value<int> rowid;
  const PendingEventsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.targetModule = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.errorMsg = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingEventsCompanion.insert({
    required String id,
    required String eventId,
    required String targetModule,
    this.retryCount = const Value.absent(),
    this.processedAt = const Value.absent(),
    this.errorMsg = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       targetModule = Value(targetModule);
  static Insertable<PendingEvent> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<String>? targetModule,
    Expression<int>? retryCount,
    Expression<int>? processedAt,
    Expression<String>? errorMsg,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (targetModule != null) 'target_module': targetModule,
      if (retryCount != null) 'retry_count': retryCount,
      if (processedAt != null) 'processed_at': processedAt,
      if (errorMsg != null) 'error_msg': errorMsg,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventId,
    Value<String>? targetModule,
    Value<int>? retryCount,
    Value<int?>? processedAt,
    Value<String?>? errorMsg,
    Value<int>? rowid,
  }) {
    return PendingEventsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      targetModule: targetModule ?? this.targetModule,
      retryCount: retryCount ?? this.retryCount,
      processedAt: processedAt ?? this.processedAt,
      errorMsg: errorMsg ?? this.errorMsg,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (targetModule.present) {
      map['target_module'] = Variable<String>(targetModule.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (processedAt.present) {
      map['processed_at'] = Variable<int>(processedAt.value);
    }
    if (errorMsg.present) {
      map['error_msg'] = Variable<String>(errorMsg.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingEventsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('targetModule: $targetModule, ')
          ..write('retryCount: $retryCount, ')
          ..write('processedAt: $processedAt, ')
          ..write('errorMsg: $errorMsg, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PosOrdersTable extends PosOrders
    with TableInfo<$PosOrdersTable, PosOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PosOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderNumberMeta = const VerificationMeta(
    'orderNumber',
  );
  @override
  late final GeneratedColumn<String> orderNumber = GeneratedColumn<String>(
    'order_number',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES core_customers (id)',
    ),
  );
  static const VerificationMeta _customerNameMeta = const VerificationMeta(
    'customerName',
  );
  @override
  late final GeneratedColumn<String> customerName = GeneratedColumn<String>(
    'customer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountMeta = const VerificationMeta(
    'discount',
  );
  @override
  late final GeneratedColumn<double> discount = GeneratedColumn<double>(
    'discount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _taxMeta = const VerificationMeta('tax');
  @override
  late final GeneratedColumn<double> tax = GeneratedColumn<double>(
    'tax',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalAmountMeta = const VerificationMeta(
    'totalAmount',
  );
  @override
  late final GeneratedColumn<double> totalAmount = GeneratedColumn<double>(
    'total_amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paymentMethodMeta = const VerificationMeta(
    'paymentMethod',
  );
  @override
  late final GeneratedColumn<String> paymentMethod = GeneratedColumn<String>(
    'payment_method',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cash'),
  );
  static const VerificationMeta _loyaltyPtsEarnedMeta = const VerificationMeta(
    'loyaltyPtsEarned',
  );
  @override
  late final GeneratedColumn<double> loyaltyPtsEarned = GeneratedColumn<double>(
    'loyalty_pts_earned',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _loyaltyPtsUsedMeta = const VerificationMeta(
    'loyaltyPtsUsed',
  );
  @override
  late final GeneratedColumn<double> loyaltyPtsUsed = GeneratedColumn<double>(
    'loyalty_pts_used',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('completed'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _receiptPrintedMeta = const VerificationMeta(
    'receiptPrinted',
  );
  @override
  late final GeneratedColumn<bool> receiptPrinted = GeneratedColumn<bool>(
    'receipt_printed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("receipt_printed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceTypeMeta = const VerificationMeta(
    'sourceType',
  );
  @override
  late final GeneratedColumn<String> sourceType = GeneratedColumn<String>(
    'source_type',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceIdMeta = const VerificationMeta(
    'sourceId',
  );
  @override
  late final GeneratedColumn<String> sourceId = GeneratedColumn<String>(
    'source_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderNumber,
    customerId,
    customerName,
    subtotal,
    discount,
    tax,
    totalAmount,
    paymentMethod,
    loyaltyPtsEarned,
    loyaltyPtsUsed,
    status,
    note,
    receiptPrinted,
    sourceType,
    sourceId,
    staffId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pos_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<PosOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_number')) {
      context.handle(
        _orderNumberMeta,
        orderNumber.isAcceptableOrUnknown(
          data['order_number']!,
          _orderNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_orderNumberMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    }
    if (data.containsKey('customer_name')) {
      context.handle(
        _customerNameMeta,
        customerName.isAcceptableOrUnknown(
          data['customer_name']!,
          _customerNameMeta,
        ),
      );
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('discount')) {
      context.handle(
        _discountMeta,
        discount.isAcceptableOrUnknown(data['discount']!, _discountMeta),
      );
    }
    if (data.containsKey('tax')) {
      context.handle(
        _taxMeta,
        tax.isAcceptableOrUnknown(data['tax']!, _taxMeta),
      );
    }
    if (data.containsKey('total_amount')) {
      context.handle(
        _totalAmountMeta,
        totalAmount.isAcceptableOrUnknown(
          data['total_amount']!,
          _totalAmountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountMeta);
    }
    if (data.containsKey('payment_method')) {
      context.handle(
        _paymentMethodMeta,
        paymentMethod.isAcceptableOrUnknown(
          data['payment_method']!,
          _paymentMethodMeta,
        ),
      );
    }
    if (data.containsKey('loyalty_pts_earned')) {
      context.handle(
        _loyaltyPtsEarnedMeta,
        loyaltyPtsEarned.isAcceptableOrUnknown(
          data['loyalty_pts_earned']!,
          _loyaltyPtsEarnedMeta,
        ),
      );
    }
    if (data.containsKey('loyalty_pts_used')) {
      context.handle(
        _loyaltyPtsUsedMeta,
        loyaltyPtsUsed.isAcceptableOrUnknown(
          data['loyalty_pts_used']!,
          _loyaltyPtsUsedMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('receipt_printed')) {
      context.handle(
        _receiptPrintedMeta,
        receiptPrinted.isAcceptableOrUnknown(
          data['receipt_printed']!,
          _receiptPrintedMeta,
        ),
      );
    }
    if (data.containsKey('source_type')) {
      context.handle(
        _sourceTypeMeta,
        sourceType.isAcceptableOrUnknown(data['source_type']!, _sourceTypeMeta),
      );
    }
    if (data.containsKey('source_id')) {
      context.handle(
        _sourceIdMeta,
        sourceId.isAcceptableOrUnknown(data['source_id']!, _sourceIdMeta),
      );
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PosOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PosOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_number'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      ),
      customerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_name'],
      ),
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}subtotal'],
      )!,
      discount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount'],
      )!,
      tax: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}tax'],
      )!,
      totalAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_amount'],
      )!,
      paymentMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payment_method'],
      )!,
      loyaltyPtsEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}loyalty_pts_earned'],
      )!,
      loyaltyPtsUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}loyalty_pts_used'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      receiptPrinted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}receipt_printed'],
      )!,
      sourceType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_type'],
      ),
      sourceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_id'],
      ),
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PosOrdersTable createAlias(String alias) {
    return $PosOrdersTable(attachedDatabase, alias);
  }
}

class PosOrder extends DataClass implements Insertable<PosOrder> {
  final String id;
  final String orderNumber;
  final String? customerId;
  final String? customerName;
  final double subtotal;
  final double discount;
  final double tax;
  final double totalAmount;
  final String paymentMethod;
  final double loyaltyPtsEarned;
  final double loyaltyPtsUsed;
  final String status;
  final String? note;
  final bool receiptPrinted;
  final String? sourceType;
  final String? sourceId;
  final String? staffId;
  final int createdAt;
  const PosOrder({
    required this.id,
    required this.orderNumber,
    this.customerId,
    this.customerName,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.totalAmount,
    required this.paymentMethod,
    required this.loyaltyPtsEarned,
    required this.loyaltyPtsUsed,
    required this.status,
    this.note,
    required this.receiptPrinted,
    this.sourceType,
    this.sourceId,
    this.staffId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_number'] = Variable<String>(orderNumber);
    if (!nullToAbsent || customerId != null) {
      map['customer_id'] = Variable<String>(customerId);
    }
    if (!nullToAbsent || customerName != null) {
      map['customer_name'] = Variable<String>(customerName);
    }
    map['subtotal'] = Variable<double>(subtotal);
    map['discount'] = Variable<double>(discount);
    map['tax'] = Variable<double>(tax);
    map['total_amount'] = Variable<double>(totalAmount);
    map['payment_method'] = Variable<String>(paymentMethod);
    map['loyalty_pts_earned'] = Variable<double>(loyaltyPtsEarned);
    map['loyalty_pts_used'] = Variable<double>(loyaltyPtsUsed);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['receipt_printed'] = Variable<bool>(receiptPrinted);
    if (!nullToAbsent || sourceType != null) {
      map['source_type'] = Variable<String>(sourceType);
    }
    if (!nullToAbsent || sourceId != null) {
      map['source_id'] = Variable<String>(sourceId);
    }
    if (!nullToAbsent || staffId != null) {
      map['staff_id'] = Variable<String>(staffId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  PosOrdersCompanion toCompanion(bool nullToAbsent) {
    return PosOrdersCompanion(
      id: Value(id),
      orderNumber: Value(orderNumber),
      customerId: customerId == null && nullToAbsent
          ? const Value.absent()
          : Value(customerId),
      customerName: customerName == null && nullToAbsent
          ? const Value.absent()
          : Value(customerName),
      subtotal: Value(subtotal),
      discount: Value(discount),
      tax: Value(tax),
      totalAmount: Value(totalAmount),
      paymentMethod: Value(paymentMethod),
      loyaltyPtsEarned: Value(loyaltyPtsEarned),
      loyaltyPtsUsed: Value(loyaltyPtsUsed),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      receiptPrinted: Value(receiptPrinted),
      sourceType: sourceType == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceType),
      sourceId: sourceId == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceId),
      staffId: staffId == null && nullToAbsent
          ? const Value.absent()
          : Value(staffId),
      createdAt: Value(createdAt),
    );
  }

  factory PosOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PosOrder(
      id: serializer.fromJson<String>(json['id']),
      orderNumber: serializer.fromJson<String>(json['orderNumber']),
      customerId: serializer.fromJson<String?>(json['customerId']),
      customerName: serializer.fromJson<String?>(json['customerName']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
      discount: serializer.fromJson<double>(json['discount']),
      tax: serializer.fromJson<double>(json['tax']),
      totalAmount: serializer.fromJson<double>(json['totalAmount']),
      paymentMethod: serializer.fromJson<String>(json['paymentMethod']),
      loyaltyPtsEarned: serializer.fromJson<double>(json['loyaltyPtsEarned']),
      loyaltyPtsUsed: serializer.fromJson<double>(json['loyaltyPtsUsed']),
      status: serializer.fromJson<String>(json['status']),
      note: serializer.fromJson<String?>(json['note']),
      receiptPrinted: serializer.fromJson<bool>(json['receiptPrinted']),
      sourceType: serializer.fromJson<String?>(json['sourceType']),
      sourceId: serializer.fromJson<String?>(json['sourceId']),
      staffId: serializer.fromJson<String?>(json['staffId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderNumber': serializer.toJson<String>(orderNumber),
      'customerId': serializer.toJson<String?>(customerId),
      'customerName': serializer.toJson<String?>(customerName),
      'subtotal': serializer.toJson<double>(subtotal),
      'discount': serializer.toJson<double>(discount),
      'tax': serializer.toJson<double>(tax),
      'totalAmount': serializer.toJson<double>(totalAmount),
      'paymentMethod': serializer.toJson<String>(paymentMethod),
      'loyaltyPtsEarned': serializer.toJson<double>(loyaltyPtsEarned),
      'loyaltyPtsUsed': serializer.toJson<double>(loyaltyPtsUsed),
      'status': serializer.toJson<String>(status),
      'note': serializer.toJson<String?>(note),
      'receiptPrinted': serializer.toJson<bool>(receiptPrinted),
      'sourceType': serializer.toJson<String?>(sourceType),
      'sourceId': serializer.toJson<String?>(sourceId),
      'staffId': serializer.toJson<String?>(staffId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  PosOrder copyWith({
    String? id,
    String? orderNumber,
    Value<String?> customerId = const Value.absent(),
    Value<String?> customerName = const Value.absent(),
    double? subtotal,
    double? discount,
    double? tax,
    double? totalAmount,
    String? paymentMethod,
    double? loyaltyPtsEarned,
    double? loyaltyPtsUsed,
    String? status,
    Value<String?> note = const Value.absent(),
    bool? receiptPrinted,
    Value<String?> sourceType = const Value.absent(),
    Value<String?> sourceId = const Value.absent(),
    Value<String?> staffId = const Value.absent(),
    int? createdAt,
  }) => PosOrder(
    id: id ?? this.id,
    orderNumber: orderNumber ?? this.orderNumber,
    customerId: customerId.present ? customerId.value : this.customerId,
    customerName: customerName.present ? customerName.value : this.customerName,
    subtotal: subtotal ?? this.subtotal,
    discount: discount ?? this.discount,
    tax: tax ?? this.tax,
    totalAmount: totalAmount ?? this.totalAmount,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    loyaltyPtsEarned: loyaltyPtsEarned ?? this.loyaltyPtsEarned,
    loyaltyPtsUsed: loyaltyPtsUsed ?? this.loyaltyPtsUsed,
    status: status ?? this.status,
    note: note.present ? note.value : this.note,
    receiptPrinted: receiptPrinted ?? this.receiptPrinted,
    sourceType: sourceType.present ? sourceType.value : this.sourceType,
    sourceId: sourceId.present ? sourceId.value : this.sourceId,
    staffId: staffId.present ? staffId.value : this.staffId,
    createdAt: createdAt ?? this.createdAt,
  );
  PosOrder copyWithCompanion(PosOrdersCompanion data) {
    return PosOrder(
      id: data.id.present ? data.id.value : this.id,
      orderNumber: data.orderNumber.present
          ? data.orderNumber.value
          : this.orderNumber,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      customerName: data.customerName.present
          ? data.customerName.value
          : this.customerName,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      discount: data.discount.present ? data.discount.value : this.discount,
      tax: data.tax.present ? data.tax.value : this.tax,
      totalAmount: data.totalAmount.present
          ? data.totalAmount.value
          : this.totalAmount,
      paymentMethod: data.paymentMethod.present
          ? data.paymentMethod.value
          : this.paymentMethod,
      loyaltyPtsEarned: data.loyaltyPtsEarned.present
          ? data.loyaltyPtsEarned.value
          : this.loyaltyPtsEarned,
      loyaltyPtsUsed: data.loyaltyPtsUsed.present
          ? data.loyaltyPtsUsed.value
          : this.loyaltyPtsUsed,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      receiptPrinted: data.receiptPrinted.present
          ? data.receiptPrinted.value
          : this.receiptPrinted,
      sourceType: data.sourceType.present
          ? data.sourceType.value
          : this.sourceType,
      sourceId: data.sourceId.present ? data.sourceId.value : this.sourceId,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PosOrder(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('loyaltyPtsEarned: $loyaltyPtsEarned, ')
          ..write('loyaltyPtsUsed: $loyaltyPtsUsed, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('receiptPrinted: $receiptPrinted, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('staffId: $staffId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderNumber,
    customerId,
    customerName,
    subtotal,
    discount,
    tax,
    totalAmount,
    paymentMethod,
    loyaltyPtsEarned,
    loyaltyPtsUsed,
    status,
    note,
    receiptPrinted,
    sourceType,
    sourceId,
    staffId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PosOrder &&
          other.id == this.id &&
          other.orderNumber == this.orderNumber &&
          other.customerId == this.customerId &&
          other.customerName == this.customerName &&
          other.subtotal == this.subtotal &&
          other.discount == this.discount &&
          other.tax == this.tax &&
          other.totalAmount == this.totalAmount &&
          other.paymentMethod == this.paymentMethod &&
          other.loyaltyPtsEarned == this.loyaltyPtsEarned &&
          other.loyaltyPtsUsed == this.loyaltyPtsUsed &&
          other.status == this.status &&
          other.note == this.note &&
          other.receiptPrinted == this.receiptPrinted &&
          other.sourceType == this.sourceType &&
          other.sourceId == this.sourceId &&
          other.staffId == this.staffId &&
          other.createdAt == this.createdAt);
}

class PosOrdersCompanion extends UpdateCompanion<PosOrder> {
  final Value<String> id;
  final Value<String> orderNumber;
  final Value<String?> customerId;
  final Value<String?> customerName;
  final Value<double> subtotal;
  final Value<double> discount;
  final Value<double> tax;
  final Value<double> totalAmount;
  final Value<String> paymentMethod;
  final Value<double> loyaltyPtsEarned;
  final Value<double> loyaltyPtsUsed;
  final Value<String> status;
  final Value<String?> note;
  final Value<bool> receiptPrinted;
  final Value<String?> sourceType;
  final Value<String?> sourceId;
  final Value<String?> staffId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const PosOrdersCompanion({
    this.id = const Value.absent(),
    this.orderNumber = const Value.absent(),
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    this.totalAmount = const Value.absent(),
    this.paymentMethod = const Value.absent(),
    this.loyaltyPtsEarned = const Value.absent(),
    this.loyaltyPtsUsed = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.receiptPrinted = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.staffId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PosOrdersCompanion.insert({
    required String id,
    required String orderNumber,
    this.customerId = const Value.absent(),
    this.customerName = const Value.absent(),
    required double subtotal,
    this.discount = const Value.absent(),
    this.tax = const Value.absent(),
    required double totalAmount,
    this.paymentMethod = const Value.absent(),
    this.loyaltyPtsEarned = const Value.absent(),
    this.loyaltyPtsUsed = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.receiptPrinted = const Value.absent(),
    this.sourceType = const Value.absent(),
    this.sourceId = const Value.absent(),
    this.staffId = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderNumber = Value(orderNumber),
       subtotal = Value(subtotal),
       totalAmount = Value(totalAmount),
       createdAt = Value(createdAt);
  static Insertable<PosOrder> custom({
    Expression<String>? id,
    Expression<String>? orderNumber,
    Expression<String>? customerId,
    Expression<String>? customerName,
    Expression<double>? subtotal,
    Expression<double>? discount,
    Expression<double>? tax,
    Expression<double>? totalAmount,
    Expression<String>? paymentMethod,
    Expression<double>? loyaltyPtsEarned,
    Expression<double>? loyaltyPtsUsed,
    Expression<String>? status,
    Expression<String>? note,
    Expression<bool>? receiptPrinted,
    Expression<String>? sourceType,
    Expression<String>? sourceId,
    Expression<String>? staffId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderNumber != null) 'order_number': orderNumber,
      if (customerId != null) 'customer_id': customerId,
      if (customerName != null) 'customer_name': customerName,
      if (subtotal != null) 'subtotal': subtotal,
      if (discount != null) 'discount': discount,
      if (tax != null) 'tax': tax,
      if (totalAmount != null) 'total_amount': totalAmount,
      if (paymentMethod != null) 'payment_method': paymentMethod,
      if (loyaltyPtsEarned != null) 'loyalty_pts_earned': loyaltyPtsEarned,
      if (loyaltyPtsUsed != null) 'loyalty_pts_used': loyaltyPtsUsed,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (receiptPrinted != null) 'receipt_printed': receiptPrinted,
      if (sourceType != null) 'source_type': sourceType,
      if (sourceId != null) 'source_id': sourceId,
      if (staffId != null) 'staff_id': staffId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PosOrdersCompanion copyWith({
    Value<String>? id,
    Value<String>? orderNumber,
    Value<String?>? customerId,
    Value<String?>? customerName,
    Value<double>? subtotal,
    Value<double>? discount,
    Value<double>? tax,
    Value<double>? totalAmount,
    Value<String>? paymentMethod,
    Value<double>? loyaltyPtsEarned,
    Value<double>? loyaltyPtsUsed,
    Value<String>? status,
    Value<String?>? note,
    Value<bool>? receiptPrinted,
    Value<String?>? sourceType,
    Value<String?>? sourceId,
    Value<String?>? staffId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return PosOrdersCompanion(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      loyaltyPtsEarned: loyaltyPtsEarned ?? this.loyaltyPtsEarned,
      loyaltyPtsUsed: loyaltyPtsUsed ?? this.loyaltyPtsUsed,
      status: status ?? this.status,
      note: note ?? this.note,
      receiptPrinted: receiptPrinted ?? this.receiptPrinted,
      sourceType: sourceType ?? this.sourceType,
      sourceId: sourceId ?? this.sourceId,
      staffId: staffId ?? this.staffId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderNumber.present) {
      map['order_number'] = Variable<String>(orderNumber.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (customerName.present) {
      map['customer_name'] = Variable<String>(customerName.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (discount.present) {
      map['discount'] = Variable<double>(discount.value);
    }
    if (tax.present) {
      map['tax'] = Variable<double>(tax.value);
    }
    if (totalAmount.present) {
      map['total_amount'] = Variable<double>(totalAmount.value);
    }
    if (paymentMethod.present) {
      map['payment_method'] = Variable<String>(paymentMethod.value);
    }
    if (loyaltyPtsEarned.present) {
      map['loyalty_pts_earned'] = Variable<double>(loyaltyPtsEarned.value);
    }
    if (loyaltyPtsUsed.present) {
      map['loyalty_pts_used'] = Variable<double>(loyaltyPtsUsed.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (receiptPrinted.present) {
      map['receipt_printed'] = Variable<bool>(receiptPrinted.value);
    }
    if (sourceType.present) {
      map['source_type'] = Variable<String>(sourceType.value);
    }
    if (sourceId.present) {
      map['source_id'] = Variable<String>(sourceId.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PosOrdersCompanion(')
          ..write('id: $id, ')
          ..write('orderNumber: $orderNumber, ')
          ..write('customerId: $customerId, ')
          ..write('customerName: $customerName, ')
          ..write('subtotal: $subtotal, ')
          ..write('discount: $discount, ')
          ..write('tax: $tax, ')
          ..write('totalAmount: $totalAmount, ')
          ..write('paymentMethod: $paymentMethod, ')
          ..write('loyaltyPtsEarned: $loyaltyPtsEarned, ')
          ..write('loyaltyPtsUsed: $loyaltyPtsUsed, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('receiptPrinted: $receiptPrinted, ')
          ..write('sourceType: $sourceType, ')
          ..write('sourceId: $sourceId, ')
          ..write('staffId: $staffId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PosOrderItemsTable extends PosOrderItems
    with TableInfo<$PosOrderItemsTable, PosOrderItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PosOrderItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES pos_orders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _costPriceMeta = const VerificationMeta(
    'costPrice',
  );
  @override
  late final GeneratedColumn<double> costPrice = GeneratedColumn<double>(
    'cost_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    orderId,
    productId,
    productName,
    quantity,
    unitPrice,
    costPrice,
    subtotal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pos_order_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<PosOrderItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_orderIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('cost_price')) {
      context.handle(
        _costPriceMeta,
        costPrice.isAcceptableOrUnknown(data['cost_price']!, _costPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_costPriceMeta);
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PosOrderItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PosOrderItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      )!,
      costPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}cost_price'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}subtotal'],
      )!,
    );
  }

  @override
  $PosOrderItemsTable createAlias(String alias) {
    return $PosOrderItemsTable(attachedDatabase, alias);
  }
}

class PosOrderItem extends DataClass implements Insertable<PosOrderItem> {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double subtotal;
  const PosOrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.subtotal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['order_id'] = Variable<String>(orderId);
    map['product_id'] = Variable<String>(productId);
    map['product_name'] = Variable<String>(productName);
    map['quantity'] = Variable<double>(quantity);
    map['unit_price'] = Variable<double>(unitPrice);
    map['cost_price'] = Variable<double>(costPrice);
    map['subtotal'] = Variable<double>(subtotal);
    return map;
  }

  PosOrderItemsCompanion toCompanion(bool nullToAbsent) {
    return PosOrderItemsCompanion(
      id: Value(id),
      orderId: Value(orderId),
      productId: Value(productId),
      productName: Value(productName),
      quantity: Value(quantity),
      unitPrice: Value(unitPrice),
      costPrice: Value(costPrice),
      subtotal: Value(subtotal),
    );
  }

  factory PosOrderItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PosOrderItem(
      id: serializer.fromJson<String>(json['id']),
      orderId: serializer.fromJson<String>(json['orderId']),
      productId: serializer.fromJson<String>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      costPrice: serializer.fromJson<double>(json['costPrice']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'orderId': serializer.toJson<String>(orderId),
      'productId': serializer.toJson<String>(productId),
      'productName': serializer.toJson<String>(productName),
      'quantity': serializer.toJson<double>(quantity),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'costPrice': serializer.toJson<double>(costPrice),
      'subtotal': serializer.toJson<double>(subtotal),
    };
  }

  PosOrderItem copyWith({
    String? id,
    String? orderId,
    String? productId,
    String? productName,
    double? quantity,
    double? unitPrice,
    double? costPrice,
    double? subtotal,
  }) => PosOrderItem(
    id: id ?? this.id,
    orderId: orderId ?? this.orderId,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    quantity: quantity ?? this.quantity,
    unitPrice: unitPrice ?? this.unitPrice,
    costPrice: costPrice ?? this.costPrice,
    subtotal: subtotal ?? this.subtotal,
  );
  PosOrderItem copyWithCompanion(PosOrderItemsCompanion data) {
    return PosOrderItem(
      id: data.id.present ? data.id.value : this.id,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      costPrice: data.costPrice.present ? data.costPrice.value : this.costPrice,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PosOrderItem(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('costPrice: $costPrice, ')
          ..write('subtotal: $subtotal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    orderId,
    productId,
    productName,
    quantity,
    unitPrice,
    costPrice,
    subtotal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PosOrderItem &&
          other.id == this.id &&
          other.orderId == this.orderId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.quantity == this.quantity &&
          other.unitPrice == this.unitPrice &&
          other.costPrice == this.costPrice &&
          other.subtotal == this.subtotal);
}

class PosOrderItemsCompanion extends UpdateCompanion<PosOrderItem> {
  final Value<String> id;
  final Value<String> orderId;
  final Value<String> productId;
  final Value<String> productName;
  final Value<double> quantity;
  final Value<double> unitPrice;
  final Value<double> costPrice;
  final Value<double> subtotal;
  final Value<int> rowid;
  const PosOrderItemsCompanion({
    this.id = const Value.absent(),
    this.orderId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.costPrice = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PosOrderItemsCompanion.insert({
    required String id,
    required String orderId,
    required String productId,
    required String productName,
    required double quantity,
    required double unitPrice,
    required double costPrice,
    required double subtotal,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       orderId = Value(orderId),
       productId = Value(productId),
       productName = Value(productName),
       quantity = Value(quantity),
       unitPrice = Value(unitPrice),
       costPrice = Value(costPrice),
       subtotal = Value(subtotal);
  static Insertable<PosOrderItem> custom({
    Expression<String>? id,
    Expression<String>? orderId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<double>? quantity,
    Expression<double>? unitPrice,
    Expression<double>? costPrice,
    Expression<double>? subtotal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (orderId != null) 'order_id': orderId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (quantity != null) 'quantity': quantity,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (costPrice != null) 'cost_price': costPrice,
      if (subtotal != null) 'subtotal': subtotal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PosOrderItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? orderId,
    Value<String>? productId,
    Value<String>? productName,
    Value<double>? quantity,
    Value<double>? unitPrice,
    Value<double>? costPrice,
    Value<double>? subtotal,
    Value<int>? rowid,
  }) {
    return PosOrderItemsCompanion(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      costPrice: costPrice ?? this.costPrice,
      subtotal: subtotal ?? this.subtotal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (costPrice.present) {
      map['cost_price'] = Variable<double>(costPrice.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PosOrderItemsCompanion(')
          ..write('id: $id, ')
          ..write('orderId: $orderId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('costPrice: $costPrice, ')
          ..write('subtotal: $subtotal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KhoStockMovementsTable extends KhoStockMovements
    with TableInfo<$KhoStockMovementsTable, KhoStockMovement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KhoStockMovementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES core_products (id)',
    ),
  );
  static const VerificationMeta _deltaMeta = const VerificationMeta('delta');
  @override
  late final GeneratedColumn<double> delta = GeneratedColumn<double>(
    'delta',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _referenceIdMeta = const VerificationMeta(
    'referenceId',
  );
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    delta,
    reason,
    referenceId,
    eventId,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kho_stock_movements';
  @override
  VerificationContext validateIntegrity(
    Insertable<KhoStockMovement> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('delta')) {
      context.handle(
        _deltaMeta,
        delta.isAcceptableOrUnknown(data['delta']!, _deltaMeta),
      );
    } else if (isInserting) {
      context.missing(_deltaMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('reference_id')) {
      context.handle(
        _referenceIdMeta,
        referenceId.isAcceptableOrUnknown(
          data['reference_id']!,
          _referenceIdMeta,
        ),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KhoStockMovement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KhoStockMovement(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      delta: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}delta'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $KhoStockMovementsTable createAlias(String alias) {
    return $KhoStockMovementsTable(attachedDatabase, alias);
  }
}

class KhoStockMovement extends DataClass
    implements Insertable<KhoStockMovement> {
  final String id;
  final String productId;
  final double delta;
  final String reason;
  final String? referenceId;
  final String? eventId;
  final String? note;
  final int createdAt;
  const KhoStockMovement({
    required this.id,
    required this.productId,
    required this.delta,
    required this.reason,
    this.referenceId,
    this.eventId,
    this.note,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['delta'] = Variable<double>(delta);
    map['reason'] = Variable<String>(reason);
    if (!nullToAbsent || referenceId != null) {
      map['reference_id'] = Variable<String>(referenceId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  KhoStockMovementsCompanion toCompanion(bool nullToAbsent) {
    return KhoStockMovementsCompanion(
      id: Value(id),
      productId: Value(productId),
      delta: Value(delta),
      reason: Value(reason),
      referenceId: referenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: Value(createdAt),
    );
  }

  factory KhoStockMovement.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KhoStockMovement(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      delta: serializer.fromJson<double>(json['delta']),
      reason: serializer.fromJson<String>(json['reason']),
      referenceId: serializer.fromJson<String?>(json['referenceId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'delta': serializer.toJson<double>(delta),
      'reason': serializer.toJson<String>(reason),
      'referenceId': serializer.toJson<String?>(referenceId),
      'eventId': serializer.toJson<String?>(eventId),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  KhoStockMovement copyWith({
    String? id,
    String? productId,
    double? delta,
    String? reason,
    Value<String?> referenceId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? createdAt,
  }) => KhoStockMovement(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    delta: delta ?? this.delta,
    reason: reason ?? this.reason,
    referenceId: referenceId.present ? referenceId.value : this.referenceId,
    eventId: eventId.present ? eventId.value : this.eventId,
    note: note.present ? note.value : this.note,
    createdAt: createdAt ?? this.createdAt,
  );
  KhoStockMovement copyWithCompanion(KhoStockMovementsCompanion data) {
    return KhoStockMovement(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      delta: data.delta.present ? data.delta.value : this.delta,
      reason: data.reason.present ? data.reason.value : this.reason,
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KhoStockMovement(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('referenceId: $referenceId, ')
          ..write('eventId: $eventId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    delta,
    reason,
    referenceId,
    eventId,
    note,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KhoStockMovement &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.delta == this.delta &&
          other.reason == this.reason &&
          other.referenceId == this.referenceId &&
          other.eventId == this.eventId &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class KhoStockMovementsCompanion extends UpdateCompanion<KhoStockMovement> {
  final Value<String> id;
  final Value<String> productId;
  final Value<double> delta;
  final Value<String> reason;
  final Value<String?> referenceId;
  final Value<String?> eventId;
  final Value<String?> note;
  final Value<int> createdAt;
  final Value<int> rowid;
  const KhoStockMovementsCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.delta = const Value.absent(),
    this.reason = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KhoStockMovementsCompanion.insert({
    required String id,
    required String productId,
    required double delta,
    required String reason,
    this.referenceId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.note = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       delta = Value(delta),
       reason = Value(reason),
       createdAt = Value(createdAt);
  static Insertable<KhoStockMovement> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<double>? delta,
    Expression<String>? reason,
    Expression<String>? referenceId,
    Expression<String>? eventId,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (delta != null) 'delta': delta,
      if (reason != null) 'reason': reason,
      if (referenceId != null) 'reference_id': referenceId,
      if (eventId != null) 'event_id': eventId,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KhoStockMovementsCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<double>? delta,
    Value<String>? reason,
    Value<String?>? referenceId,
    Value<String?>? eventId,
    Value<String?>? note,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return KhoStockMovementsCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      delta: delta ?? this.delta,
      reason: reason ?? this.reason,
      referenceId: referenceId ?? this.referenceId,
      eventId: eventId ?? this.eventId,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (delta.present) {
      map['delta'] = Variable<double>(delta.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KhoStockMovementsCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('delta: $delta, ')
          ..write('reason: $reason, ')
          ..write('referenceId: $referenceId, ')
          ..write('eventId: $eventId, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KhoRecipesTable extends KhoRecipes
    with TableInfo<$KhoRecipesTable, KhoRecipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KhoRecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES core_products (id)',
    ),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, productId, isActive, note];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kho_recipes';
  @override
  VerificationContext validateIntegrity(
    Insertable<KhoRecipe> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KhoRecipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KhoRecipe(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
    );
  }

  @override
  $KhoRecipesTable createAlias(String alias) {
    return $KhoRecipesTable(attachedDatabase, alias);
  }
}

class KhoRecipe extends DataClass implements Insertable<KhoRecipe> {
  final String id;
  final String productId;
  final bool isActive;
  final String? note;
  const KhoRecipe({
    required this.id,
    required this.productId,
    required this.isActive,
    this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['is_active'] = Variable<bool>(isActive);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    return map;
  }

  KhoRecipesCompanion toCompanion(bool nullToAbsent) {
    return KhoRecipesCompanion(
      id: Value(id),
      productId: Value(productId),
      isActive: Value(isActive),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
    );
  }

  factory KhoRecipe.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KhoRecipe(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      note: serializer.fromJson<String?>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'isActive': serializer.toJson<bool>(isActive),
      'note': serializer.toJson<String?>(note),
    };
  }

  KhoRecipe copyWith({
    String? id,
    String? productId,
    bool? isActive,
    Value<String?> note = const Value.absent(),
  }) => KhoRecipe(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    isActive: isActive ?? this.isActive,
    note: note.present ? note.value : this.note,
  );
  KhoRecipe copyWithCompanion(KhoRecipesCompanion data) {
    return KhoRecipe(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KhoRecipe(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('isActive: $isActive, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, productId, isActive, note);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KhoRecipe &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.isActive == this.isActive &&
          other.note == this.note);
}

class KhoRecipesCompanion extends UpdateCompanion<KhoRecipe> {
  final Value<String> id;
  final Value<String> productId;
  final Value<bool> isActive;
  final Value<String?> note;
  final Value<int> rowid;
  const KhoRecipesCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.isActive = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KhoRecipesCompanion.insert({
    required String id,
    required String productId,
    this.isActive = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId);
  static Insertable<KhoRecipe> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<bool>? isActive,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (isActive != null) 'is_active': isActive,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KhoRecipesCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<bool>? isActive,
    Value<String?>? note,
    Value<int>? rowid,
  }) {
    return KhoRecipesCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KhoRecipesCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('isActive: $isActive, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KhoRecipeItemsTable extends KhoRecipeItems
    with TableInfo<$KhoRecipeItemsTable, KhoRecipeItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KhoRecipeItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recipeIdMeta = const VerificationMeta(
    'recipeId',
  );
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
    'recipe_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES kho_recipes (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _ingredientIdMeta = const VerificationMeta(
    'ingredientId',
  );
  @override
  late final GeneratedColumn<String> ingredientId = GeneratedColumn<String>(
    'ingredient_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES core_products (id)',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitMeta = const VerificationMeta('unit');
  @override
  late final GeneratedColumn<String> unit = GeneratedColumn<String>(
    'unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recipeId,
    ingredientId,
    quantity,
    unit,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kho_recipe_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<KhoRecipeItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(
        _recipeIdMeta,
        recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta),
      );
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('ingredient_id')) {
      context.handle(
        _ingredientIdMeta,
        ingredientId.isAcceptableOrUnknown(
          data['ingredient_id']!,
          _ingredientIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ingredientIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit')) {
      context.handle(
        _unitMeta,
        unit.isAcceptableOrUnknown(data['unit']!, _unitMeta),
      );
    } else if (isInserting) {
      context.missing(_unitMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KhoRecipeItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KhoRecipeItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recipeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recipe_id'],
      )!,
      ingredientId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ingredient_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}unit'],
      )!,
    );
  }

  @override
  $KhoRecipeItemsTable createAlias(String alias) {
    return $KhoRecipeItemsTable(attachedDatabase, alias);
  }
}

class KhoRecipeItem extends DataClass implements Insertable<KhoRecipeItem> {
  final String id;
  final String recipeId;
  final String ingredientId;
  final double quantity;
  final String unit;
  const KhoRecipeItem({
    required this.id,
    required this.recipeId,
    required this.ingredientId,
    required this.quantity,
    required this.unit,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['recipe_id'] = Variable<String>(recipeId);
    map['ingredient_id'] = Variable<String>(ingredientId);
    map['quantity'] = Variable<double>(quantity);
    map['unit'] = Variable<String>(unit);
    return map;
  }

  KhoRecipeItemsCompanion toCompanion(bool nullToAbsent) {
    return KhoRecipeItemsCompanion(
      id: Value(id),
      recipeId: Value(recipeId),
      ingredientId: Value(ingredientId),
      quantity: Value(quantity),
      unit: Value(unit),
    );
  }

  factory KhoRecipeItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KhoRecipeItem(
      id: serializer.fromJson<String>(json['id']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      ingredientId: serializer.fromJson<String>(json['ingredientId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unit: serializer.fromJson<String>(json['unit']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recipeId': serializer.toJson<String>(recipeId),
      'ingredientId': serializer.toJson<String>(ingredientId),
      'quantity': serializer.toJson<double>(quantity),
      'unit': serializer.toJson<String>(unit),
    };
  }

  KhoRecipeItem copyWith({
    String? id,
    String? recipeId,
    String? ingredientId,
    double? quantity,
    String? unit,
  }) => KhoRecipeItem(
    id: id ?? this.id,
    recipeId: recipeId ?? this.recipeId,
    ingredientId: ingredientId ?? this.ingredientId,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
  );
  KhoRecipeItem copyWithCompanion(KhoRecipeItemsCompanion data) {
    return KhoRecipeItem(
      id: data.id.present ? data.id.value : this.id,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      ingredientId: data.ingredientId.present
          ? data.ingredientId.value
          : this.ingredientId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unit: data.unit.present ? data.unit.value : this.unit,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KhoRecipeItem(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, recipeId, ingredientId, quantity, unit);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KhoRecipeItem &&
          other.id == this.id &&
          other.recipeId == this.recipeId &&
          other.ingredientId == this.ingredientId &&
          other.quantity == this.quantity &&
          other.unit == this.unit);
}

class KhoRecipeItemsCompanion extends UpdateCompanion<KhoRecipeItem> {
  final Value<String> id;
  final Value<String> recipeId;
  final Value<String> ingredientId;
  final Value<double> quantity;
  final Value<String> unit;
  final Value<int> rowid;
  const KhoRecipeItemsCompanion({
    this.id = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.ingredientId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unit = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KhoRecipeItemsCompanion.insert({
    required String id,
    required String recipeId,
    required String ingredientId,
    required double quantity,
    required String unit,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       recipeId = Value(recipeId),
       ingredientId = Value(ingredientId),
       quantity = Value(quantity),
       unit = Value(unit);
  static Insertable<KhoRecipeItem> custom({
    Expression<String>? id,
    Expression<String>? recipeId,
    Expression<String>? ingredientId,
    Expression<double>? quantity,
    Expression<String>? unit,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recipeId != null) 'recipe_id': recipeId,
      if (ingredientId != null) 'ingredient_id': ingredientId,
      if (quantity != null) 'quantity': quantity,
      if (unit != null) 'unit': unit,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KhoRecipeItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? recipeId,
    Value<String>? ingredientId,
    Value<double>? quantity,
    Value<String>? unit,
    Value<int>? rowid,
  }) {
    return KhoRecipeItemsCompanion(
      id: id ?? this.id,
      recipeId: recipeId ?? this.recipeId,
      ingredientId: ingredientId ?? this.ingredientId,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (ingredientId.present) {
      map['ingredient_id'] = Variable<String>(ingredientId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unit.present) {
      map['unit'] = Variable<String>(unit.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KhoRecipeItemsCompanion(')
          ..write('id: $id, ')
          ..write('recipeId: $recipeId, ')
          ..write('ingredientId: $ingredientId, ')
          ..write('quantity: $quantity, ')
          ..write('unit: $unit, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KhoSuppliersTable extends KhoSuppliers
    with TableInfo<$KhoSuppliersTable, KhoSupplier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KhoSuppliersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addressMeta = const VerificationMeta(
    'address',
  );
  @override
  late final GeneratedColumn<String> address = GeneratedColumn<String>(
    'address',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    phone,
    address,
    note,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kho_suppliers';
  @override
  VerificationContext validateIntegrity(
    Insertable<KhoSupplier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    }
    if (data.containsKey('address')) {
      context.handle(
        _addressMeta,
        address.isAcceptableOrUnknown(data['address']!, _addressMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KhoSupplier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KhoSupplier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      ),
      address: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $KhoSuppliersTable createAlias(String alias) {
    return $KhoSuppliersTable(attachedDatabase, alias);
  }
}

class KhoSupplier extends DataClass implements Insertable<KhoSupplier> {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final bool isDeleted;
  const KhoSupplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.note,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || phone != null) {
      map['phone'] = Variable<String>(phone);
    }
    if (!nullToAbsent || address != null) {
      map['address'] = Variable<String>(address);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  KhoSuppliersCompanion toCompanion(bool nullToAbsent) {
    return KhoSuppliersCompanion(
      id: Value(id),
      name: Value(name),
      phone: phone == null && nullToAbsent
          ? const Value.absent()
          : Value(phone),
      address: address == null && nullToAbsent
          ? const Value.absent()
          : Value(address),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      isDeleted: Value(isDeleted),
    );
  }

  factory KhoSupplier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KhoSupplier(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String?>(json['phone']),
      address: serializer.fromJson<String?>(json['address']),
      note: serializer.fromJson<String?>(json['note']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String?>(phone),
      'address': serializer.toJson<String?>(address),
      'note': serializer.toJson<String?>(note),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  KhoSupplier copyWith({
    String? id,
    String? name,
    Value<String?> phone = const Value.absent(),
    Value<String?> address = const Value.absent(),
    Value<String?> note = const Value.absent(),
    bool? isDeleted,
  }) => KhoSupplier(
    id: id ?? this.id,
    name: name ?? this.name,
    phone: phone.present ? phone.value : this.phone,
    address: address.present ? address.value : this.address,
    note: note.present ? note.value : this.note,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  KhoSupplier copyWithCompanion(KhoSuppliersCompanion data) {
    return KhoSupplier(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      address: data.address.present ? data.address.value : this.address,
      note: data.note.present ? data.note.value : this.note,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KhoSupplier(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('note: $note, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, phone, address, note, isDeleted);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KhoSupplier &&
          other.id == this.id &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.address == this.address &&
          other.note == this.note &&
          other.isDeleted == this.isDeleted);
}

class KhoSuppliersCompanion extends UpdateCompanion<KhoSupplier> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> phone;
  final Value<String?> address;
  final Value<String?> note;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const KhoSuppliersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.note = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KhoSuppliersCompanion.insert({
    required String id,
    required String name,
    this.phone = const Value.absent(),
    this.address = const Value.absent(),
    this.note = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<KhoSupplier> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? address,
    Expression<String>? note,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (note != null) 'note': note,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KhoSuppliersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? phone,
    Value<String?>? address,
    Value<String?>? note,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return KhoSuppliersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (address.present) {
      map['address'] = Variable<String>(address.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KhoSuppliersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('address: $address, ')
          ..write('note: $note, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KhoPurchaseOrdersTable extends KhoPurchaseOrders
    with TableInfo<$KhoPurchaseOrdersTable, KhoPurchaseOrder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KhoPurchaseOrdersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _supplierIdMeta = const VerificationMeta(
    'supplierId',
  );
  @override
  late final GeneratedColumn<String> supplierId = GeneratedColumn<String>(
    'supplier_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES kho_suppliers (id)',
    ),
  );
  static const VerificationMeta _totalCostMeta = const VerificationMeta(
    'totalCost',
  );
  @override
  late final GeneratedColumn<double> totalCost = GeneratedColumn<double>(
    'total_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('received'),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    supplierId,
    totalCost,
    status,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kho_purchase_orders';
  @override
  VerificationContext validateIntegrity(
    Insertable<KhoPurchaseOrder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('supplier_id')) {
      context.handle(
        _supplierIdMeta,
        supplierId.isAcceptableOrUnknown(data['supplier_id']!, _supplierIdMeta),
      );
    }
    if (data.containsKey('total_cost')) {
      context.handle(
        _totalCostMeta,
        totalCost.isAcceptableOrUnknown(data['total_cost']!, _totalCostMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCostMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KhoPurchaseOrder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KhoPurchaseOrder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      supplierId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}supplier_id'],
      ),
      totalCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_cost'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $KhoPurchaseOrdersTable createAlias(String alias) {
    return $KhoPurchaseOrdersTable(attachedDatabase, alias);
  }
}

class KhoPurchaseOrder extends DataClass
    implements Insertable<KhoPurchaseOrder> {
  final String id;
  final String? supplierId;
  final double totalCost;
  final String status;
  final String? note;
  final int? createdAt;
  const KhoPurchaseOrder({
    required this.id,
    this.supplierId,
    required this.totalCost,
    required this.status,
    this.note,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || supplierId != null) {
      map['supplier_id'] = Variable<String>(supplierId);
    }
    map['total_cost'] = Variable<double>(totalCost);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    return map;
  }

  KhoPurchaseOrdersCompanion toCompanion(bool nullToAbsent) {
    return KhoPurchaseOrdersCompanion(
      id: Value(id),
      supplierId: supplierId == null && nullToAbsent
          ? const Value.absent()
          : Value(supplierId),
      totalCost: Value(totalCost),
      status: Value(status),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory KhoPurchaseOrder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KhoPurchaseOrder(
      id: serializer.fromJson<String>(json['id']),
      supplierId: serializer.fromJson<String?>(json['supplierId']),
      totalCost: serializer.fromJson<double>(json['totalCost']),
      status: serializer.fromJson<String>(json['status']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'supplierId': serializer.toJson<String?>(supplierId),
      'totalCost': serializer.toJson<double>(totalCost),
      'status': serializer.toJson<String>(status),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int?>(createdAt),
    };
  }

  KhoPurchaseOrder copyWith({
    String? id,
    Value<String?> supplierId = const Value.absent(),
    double? totalCost,
    String? status,
    Value<String?> note = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
  }) => KhoPurchaseOrder(
    id: id ?? this.id,
    supplierId: supplierId.present ? supplierId.value : this.supplierId,
    totalCost: totalCost ?? this.totalCost,
    status: status ?? this.status,
    note: note.present ? note.value : this.note,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  KhoPurchaseOrder copyWithCompanion(KhoPurchaseOrdersCompanion data) {
    return KhoPurchaseOrder(
      id: data.id.present ? data.id.value : this.id,
      supplierId: data.supplierId.present
          ? data.supplierId.value
          : this.supplierId,
      totalCost: data.totalCost.present ? data.totalCost.value : this.totalCost,
      status: data.status.present ? data.status.value : this.status,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KhoPurchaseOrder(')
          ..write('id: $id, ')
          ..write('supplierId: $supplierId, ')
          ..write('totalCost: $totalCost, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, supplierId, totalCost, status, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KhoPurchaseOrder &&
          other.id == this.id &&
          other.supplierId == this.supplierId &&
          other.totalCost == this.totalCost &&
          other.status == this.status &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class KhoPurchaseOrdersCompanion extends UpdateCompanion<KhoPurchaseOrder> {
  final Value<String> id;
  final Value<String?> supplierId;
  final Value<double> totalCost;
  final Value<String> status;
  final Value<String?> note;
  final Value<int?> createdAt;
  final Value<int> rowid;
  const KhoPurchaseOrdersCompanion({
    this.id = const Value.absent(),
    this.supplierId = const Value.absent(),
    this.totalCost = const Value.absent(),
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KhoPurchaseOrdersCompanion.insert({
    required String id,
    this.supplierId = const Value.absent(),
    required double totalCost,
    this.status = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       totalCost = Value(totalCost);
  static Insertable<KhoPurchaseOrder> custom({
    Expression<String>? id,
    Expression<String>? supplierId,
    Expression<double>? totalCost,
    Expression<String>? status,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (supplierId != null) 'supplier_id': supplierId,
      if (totalCost != null) 'total_cost': totalCost,
      if (status != null) 'status': status,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KhoPurchaseOrdersCompanion copyWith({
    Value<String>? id,
    Value<String?>? supplierId,
    Value<double>? totalCost,
    Value<String>? status,
    Value<String?>? note,
    Value<int?>? createdAt,
    Value<int>? rowid,
  }) {
    return KhoPurchaseOrdersCompanion(
      id: id ?? this.id,
      supplierId: supplierId ?? this.supplierId,
      totalCost: totalCost ?? this.totalCost,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (supplierId.present) {
      map['supplier_id'] = Variable<String>(supplierId.value);
    }
    if (totalCost.present) {
      map['total_cost'] = Variable<double>(totalCost.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KhoPurchaseOrdersCompanion(')
          ..write('id: $id, ')
          ..write('supplierId: $supplierId, ')
          ..write('totalCost: $totalCost, ')
          ..write('status: $status, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KhoPurchaseItemsTable extends KhoPurchaseItems
    with TableInfo<$KhoPurchaseItemsTable, KhoPurchaseItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KhoPurchaseItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purchaseIdMeta = const VerificationMeta(
    'purchaseId',
  );
  @override
  late final GeneratedColumn<String> purchaseId = GeneratedColumn<String>(
    'purchase_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES kho_purchase_orders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitCostMeta = const VerificationMeta(
    'unitCost',
  );
  @override
  late final GeneratedColumn<double> unitCost = GeneratedColumn<double>(
    'unit_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    purchaseId,
    productId,
    productName,
    quantity,
    unitCost,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kho_purchase_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<KhoPurchaseItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('purchase_id')) {
      context.handle(
        _purchaseIdMeta,
        purchaseId.isAcceptableOrUnknown(data['purchase_id']!, _purchaseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_purchaseIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('unit_cost')) {
      context.handle(
        _unitCostMeta,
        unitCost.isAcceptableOrUnknown(data['unit_cost']!, _unitCostMeta),
      );
    } else if (isInserting) {
      context.missing(_unitCostMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KhoPurchaseItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KhoPurchaseItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      purchaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}purchase_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      ),
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      ),
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      unitCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_cost'],
      )!,
    );
  }

  @override
  $KhoPurchaseItemsTable createAlias(String alias) {
    return $KhoPurchaseItemsTable(attachedDatabase, alias);
  }
}

class KhoPurchaseItem extends DataClass implements Insertable<KhoPurchaseItem> {
  final String id;
  final String purchaseId;
  final String? productId;
  final String? productName;
  final double quantity;
  final double unitCost;
  const KhoPurchaseItem({
    required this.id,
    required this.purchaseId,
    this.productId,
    this.productName,
    required this.quantity,
    required this.unitCost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['purchase_id'] = Variable<String>(purchaseId);
    if (!nullToAbsent || productId != null) {
      map['product_id'] = Variable<String>(productId);
    }
    if (!nullToAbsent || productName != null) {
      map['product_name'] = Variable<String>(productName);
    }
    map['quantity'] = Variable<double>(quantity);
    map['unit_cost'] = Variable<double>(unitCost);
    return map;
  }

  KhoPurchaseItemsCompanion toCompanion(bool nullToAbsent) {
    return KhoPurchaseItemsCompanion(
      id: Value(id),
      purchaseId: Value(purchaseId),
      productId: productId == null && nullToAbsent
          ? const Value.absent()
          : Value(productId),
      productName: productName == null && nullToAbsent
          ? const Value.absent()
          : Value(productName),
      quantity: Value(quantity),
      unitCost: Value(unitCost),
    );
  }

  factory KhoPurchaseItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KhoPurchaseItem(
      id: serializer.fromJson<String>(json['id']),
      purchaseId: serializer.fromJson<String>(json['purchaseId']),
      productId: serializer.fromJson<String?>(json['productId']),
      productName: serializer.fromJson<String?>(json['productName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      unitCost: serializer.fromJson<double>(json['unitCost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'purchaseId': serializer.toJson<String>(purchaseId),
      'productId': serializer.toJson<String?>(productId),
      'productName': serializer.toJson<String?>(productName),
      'quantity': serializer.toJson<double>(quantity),
      'unitCost': serializer.toJson<double>(unitCost),
    };
  }

  KhoPurchaseItem copyWith({
    String? id,
    String? purchaseId,
    Value<String?> productId = const Value.absent(),
    Value<String?> productName = const Value.absent(),
    double? quantity,
    double? unitCost,
  }) => KhoPurchaseItem(
    id: id ?? this.id,
    purchaseId: purchaseId ?? this.purchaseId,
    productId: productId.present ? productId.value : this.productId,
    productName: productName.present ? productName.value : this.productName,
    quantity: quantity ?? this.quantity,
    unitCost: unitCost ?? this.unitCost,
  );
  KhoPurchaseItem copyWithCompanion(KhoPurchaseItemsCompanion data) {
    return KhoPurchaseItem(
      id: data.id.present ? data.id.value : this.id,
      purchaseId: data.purchaseId.present
          ? data.purchaseId.value
          : this.purchaseId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      unitCost: data.unitCost.present ? data.unitCost.value : this.unitCost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KhoPurchaseItem(')
          ..write('id: $id, ')
          ..write('purchaseId: $purchaseId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitCost: $unitCost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, purchaseId, productId, productName, quantity, unitCost);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KhoPurchaseItem &&
          other.id == this.id &&
          other.purchaseId == this.purchaseId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.quantity == this.quantity &&
          other.unitCost == this.unitCost);
}

class KhoPurchaseItemsCompanion extends UpdateCompanion<KhoPurchaseItem> {
  final Value<String> id;
  final Value<String> purchaseId;
  final Value<String?> productId;
  final Value<String?> productName;
  final Value<double> quantity;
  final Value<double> unitCost;
  final Value<int> rowid;
  const KhoPurchaseItemsCompanion({
    this.id = const Value.absent(),
    this.purchaseId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.unitCost = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KhoPurchaseItemsCompanion.insert({
    required String id,
    required String purchaseId,
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    required double quantity,
    required double unitCost,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       purchaseId = Value(purchaseId),
       quantity = Value(quantity),
       unitCost = Value(unitCost);
  static Insertable<KhoPurchaseItem> custom({
    Expression<String>? id,
    Expression<String>? purchaseId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<double>? quantity,
    Expression<double>? unitCost,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (purchaseId != null) 'purchase_id': purchaseId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (quantity != null) 'quantity': quantity,
      if (unitCost != null) 'unit_cost': unitCost,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KhoPurchaseItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? purchaseId,
    Value<String?>? productId,
    Value<String?>? productName,
    Value<double>? quantity,
    Value<double>? unitCost,
    Value<int>? rowid,
  }) {
    return KhoPurchaseItemsCompanion(
      id: id ?? this.id,
      purchaseId: purchaseId ?? this.purchaseId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      unitCost: unitCost ?? this.unitCost,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (purchaseId.present) {
      map['purchase_id'] = Variable<String>(purchaseId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (unitCost.present) {
      map['unit_cost'] = Variable<double>(unitCost.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KhoPurchaseItemsCompanion(')
          ..write('id: $id, ')
          ..write('purchaseId: $purchaseId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('unitCost: $unitCost, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FinanceCategoriesTable extends FinanceCategories
    with TableInfo<$FinanceCategoriesTable, FinanceCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinanceCategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, type, icon, color, isSystem];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'finance_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<FinanceCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FinanceCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinanceCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      ),
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      ),
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
    );
  }

  @override
  $FinanceCategoriesTable createAlias(String alias) {
    return $FinanceCategoriesTable(attachedDatabase, alias);
  }
}

class FinanceCategory extends DataClass implements Insertable<FinanceCategory> {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final bool isSystem;
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.isSystem,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || icon != null) {
      map['icon'] = Variable<String>(icon);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<String>(color);
    }
    map['is_system'] = Variable<bool>(isSystem);
    return map;
  }

  FinanceCategoriesCompanion toCompanion(bool nullToAbsent) {
    return FinanceCategoriesCompanion(
      id: Value(id),
      name: Value(name),
      type: Value(type),
      icon: icon == null && nullToAbsent ? const Value.absent() : Value(icon),
      color: color == null && nullToAbsent
          ? const Value.absent()
          : Value(color),
      isSystem: Value(isSystem),
    );
  }

  factory FinanceCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinanceCategory(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      icon: serializer.fromJson<String?>(json['icon']),
      color: serializer.fromJson<String?>(json['color']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'icon': serializer.toJson<String?>(icon),
      'color': serializer.toJson<String?>(color),
      'isSystem': serializer.toJson<bool>(isSystem),
    };
  }

  FinanceCategory copyWith({
    String? id,
    String? name,
    String? type,
    Value<String?> icon = const Value.absent(),
    Value<String?> color = const Value.absent(),
    bool? isSystem,
  }) => FinanceCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    type: type ?? this.type,
    icon: icon.present ? icon.value : this.icon,
    color: color.present ? color.value : this.color,
    isSystem: isSystem ?? this.isSystem,
  );
  FinanceCategory copyWithCompanion(FinanceCategoriesCompanion data) {
    return FinanceCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinanceCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('isSystem: $isSystem')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, type, icon, color, isSystem);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinanceCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.type == this.type &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.isSystem == this.isSystem);
}

class FinanceCategoriesCompanion extends UpdateCompanion<FinanceCategory> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> type;
  final Value<String?> icon;
  final Value<String?> color;
  final Value<bool> isSystem;
  final Value<int> rowid;
  const FinanceCategoriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FinanceCategoriesCompanion.insert({
    required String id,
    required String name,
    required String type,
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       type = Value(type);
  static Insertable<FinanceCategory> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? type,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<bool>? isSystem,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (isSystem != null) 'is_system': isSystem,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FinanceCategoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? type,
    Value<String?>? icon,
    Value<String?>? color,
    Value<bool>? isSystem,
    Value<int>? rowid,
  }) {
    return FinanceCategoriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isSystem: isSystem ?? this.isSystem,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinanceCategoriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('isSystem: $isSystem, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FinanceRecordsTable extends FinanceRecords
    with TableInfo<$FinanceRecordsTable, FinanceRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FinanceRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMeta = const VerificationMeta('amount');
  @override
  late final GeneratedColumn<double> amount = GeneratedColumn<double>(
    'amount',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES finance_categories (id)',
    ),
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _referenceIdMeta = const VerificationMeta(
    'referenceId',
  );
  @override
  late final GeneratedColumn<String> referenceId = GeneratedColumn<String>(
    'reference_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isAutoMeta = const VerificationMeta('isAuto');
  @override
  late final GeneratedColumn<bool> isAuto = GeneratedColumn<bool>(
    'is_auto',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_auto" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _recordedAtMeta = const VerificationMeta(
    'recordedAt',
  );
  @override
  late final GeneratedColumn<int> recordedAt = GeneratedColumn<int>(
    'recorded_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    amount,
    categoryId,
    description,
    referenceId,
    eventId,
    isAuto,
    recordedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'finance_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<FinanceRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('amount')) {
      context.handle(
        _amountMeta,
        amount.isAcceptableOrUnknown(data['amount']!, _amountMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('reference_id')) {
      context.handle(
        _referenceIdMeta,
        referenceId.isAcceptableOrUnknown(
          data['reference_id']!,
          _referenceIdMeta,
        ),
      );
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    }
    if (data.containsKey('is_auto')) {
      context.handle(
        _isAutoMeta,
        isAuto.isAcceptableOrUnknown(data['is_auto']!, _isAutoMeta),
      );
    }
    if (data.containsKey('recorded_at')) {
      context.handle(
        _recordedAtMeta,
        recordedAt.isAcceptableOrUnknown(data['recorded_at']!, _recordedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_recordedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FinanceRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FinanceRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      amount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}amount'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      referenceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reference_id'],
      ),
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      ),
      isAuto: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_auto'],
      )!,
      recordedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recorded_at'],
      )!,
    );
  }

  @override
  $FinanceRecordsTable createAlias(String alias) {
    return $FinanceRecordsTable(attachedDatabase, alias);
  }
}

class FinanceRecord extends DataClass implements Insertable<FinanceRecord> {
  final String id;
  final String type;
  final double amount;
  final String? categoryId;
  final String? description;
  final String? referenceId;
  final String? eventId;
  final bool isAuto;
  final int recordedAt;
  const FinanceRecord({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.description,
    this.referenceId,
    this.eventId,
    required this.isAuto,
    required this.recordedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['amount'] = Variable<double>(amount);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || referenceId != null) {
      map['reference_id'] = Variable<String>(referenceId);
    }
    if (!nullToAbsent || eventId != null) {
      map['event_id'] = Variable<String>(eventId);
    }
    map['is_auto'] = Variable<bool>(isAuto);
    map['recorded_at'] = Variable<int>(recordedAt);
    return map;
  }

  FinanceRecordsCompanion toCompanion(bool nullToAbsent) {
    return FinanceRecordsCompanion(
      id: Value(id),
      type: Value(type),
      amount: Value(amount),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      referenceId: referenceId == null && nullToAbsent
          ? const Value.absent()
          : Value(referenceId),
      eventId: eventId == null && nullToAbsent
          ? const Value.absent()
          : Value(eventId),
      isAuto: Value(isAuto),
      recordedAt: Value(recordedAt),
    );
  }

  factory FinanceRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FinanceRecord(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      amount: serializer.fromJson<double>(json['amount']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      description: serializer.fromJson<String?>(json['description']),
      referenceId: serializer.fromJson<String?>(json['referenceId']),
      eventId: serializer.fromJson<String?>(json['eventId']),
      isAuto: serializer.fromJson<bool>(json['isAuto']),
      recordedAt: serializer.fromJson<int>(json['recordedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'amount': serializer.toJson<double>(amount),
      'categoryId': serializer.toJson<String?>(categoryId),
      'description': serializer.toJson<String?>(description),
      'referenceId': serializer.toJson<String?>(referenceId),
      'eventId': serializer.toJson<String?>(eventId),
      'isAuto': serializer.toJson<bool>(isAuto),
      'recordedAt': serializer.toJson<int>(recordedAt),
    };
  }

  FinanceRecord copyWith({
    String? id,
    String? type,
    double? amount,
    Value<String?> categoryId = const Value.absent(),
    Value<String?> description = const Value.absent(),
    Value<String?> referenceId = const Value.absent(),
    Value<String?> eventId = const Value.absent(),
    bool? isAuto,
    int? recordedAt,
  }) => FinanceRecord(
    id: id ?? this.id,
    type: type ?? this.type,
    amount: amount ?? this.amount,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    description: description.present ? description.value : this.description,
    referenceId: referenceId.present ? referenceId.value : this.referenceId,
    eventId: eventId.present ? eventId.value : this.eventId,
    isAuto: isAuto ?? this.isAuto,
    recordedAt: recordedAt ?? this.recordedAt,
  );
  FinanceRecord copyWithCompanion(FinanceRecordsCompanion data) {
    return FinanceRecord(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      amount: data.amount.present ? data.amount.value : this.amount,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      description: data.description.present
          ? data.description.value
          : this.description,
      referenceId: data.referenceId.present
          ? data.referenceId.value
          : this.referenceId,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      isAuto: data.isAuto.present ? data.isAuto.value : this.isAuto,
      recordedAt: data.recordedAt.present
          ? data.recordedAt.value
          : this.recordedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FinanceRecord(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('description: $description, ')
          ..write('referenceId: $referenceId, ')
          ..write('eventId: $eventId, ')
          ..write('isAuto: $isAuto, ')
          ..write('recordedAt: $recordedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    amount,
    categoryId,
    description,
    referenceId,
    eventId,
    isAuto,
    recordedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FinanceRecord &&
          other.id == this.id &&
          other.type == this.type &&
          other.amount == this.amount &&
          other.categoryId == this.categoryId &&
          other.description == this.description &&
          other.referenceId == this.referenceId &&
          other.eventId == this.eventId &&
          other.isAuto == this.isAuto &&
          other.recordedAt == this.recordedAt);
}

class FinanceRecordsCompanion extends UpdateCompanion<FinanceRecord> {
  final Value<String> id;
  final Value<String> type;
  final Value<double> amount;
  final Value<String?> categoryId;
  final Value<String?> description;
  final Value<String?> referenceId;
  final Value<String?> eventId;
  final Value<bool> isAuto;
  final Value<int> recordedAt;
  final Value<int> rowid;
  const FinanceRecordsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.amount = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.description = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.isAuto = const Value.absent(),
    this.recordedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FinanceRecordsCompanion.insert({
    required String id,
    required String type,
    required double amount,
    this.categoryId = const Value.absent(),
    this.description = const Value.absent(),
    this.referenceId = const Value.absent(),
    this.eventId = const Value.absent(),
    this.isAuto = const Value.absent(),
    required int recordedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       amount = Value(amount),
       recordedAt = Value(recordedAt);
  static Insertable<FinanceRecord> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<double>? amount,
    Expression<String>? categoryId,
    Expression<String>? description,
    Expression<String>? referenceId,
    Expression<String>? eventId,
    Expression<bool>? isAuto,
    Expression<int>? recordedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (amount != null) 'amount': amount,
      if (categoryId != null) 'category_id': categoryId,
      if (description != null) 'description': description,
      if (referenceId != null) 'reference_id': referenceId,
      if (eventId != null) 'event_id': eventId,
      if (isAuto != null) 'is_auto': isAuto,
      if (recordedAt != null) 'recorded_at': recordedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FinanceRecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<double>? amount,
    Value<String?>? categoryId,
    Value<String?>? description,
    Value<String?>? referenceId,
    Value<String?>? eventId,
    Value<bool>? isAuto,
    Value<int>? recordedAt,
    Value<int>? rowid,
  }) {
    return FinanceRecordsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      description: description ?? this.description,
      referenceId: referenceId ?? this.referenceId,
      eventId: eventId ?? this.eventId,
      isAuto: isAuto ?? this.isAuto,
      recordedAt: recordedAt ?? this.recordedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (amount.present) {
      map['amount'] = Variable<double>(amount.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (referenceId.present) {
      map['reference_id'] = Variable<String>(referenceId.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (isAuto.present) {
      map['is_auto'] = Variable<bool>(isAuto.value);
    }
    if (recordedAt.present) {
      map['recorded_at'] = Variable<int>(recordedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FinanceRecordsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('amount: $amount, ')
          ..write('categoryId: $categoryId, ')
          ..write('description: $description, ')
          ..write('referenceId: $referenceId, ')
          ..write('eventId: $eventId, ')
          ..write('isAuto: $isAuto, ')
          ..write('recordedAt: $recordedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LoyaltyTransactionsTable extends LoyaltyTransactions
    with TableInfo<$LoyaltyTransactionsTable, LoyaltyTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LoyaltyTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _customerIdMeta = const VerificationMeta(
    'customerId',
  );
  @override
  late final GeneratedColumn<String> customerId = GeneratedColumn<String>(
    'customer_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES core_customers (id)',
    ),
  );
  static const VerificationMeta _orderIdMeta = const VerificationMeta(
    'orderId',
  );
  @override
  late final GeneratedColumn<String> orderId = GeneratedColumn<String>(
    'order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ptsEarnedMeta = const VerificationMeta(
    'ptsEarned',
  );
  @override
  late final GeneratedColumn<double> ptsEarned = GeneratedColumn<double>(
    'pts_earned',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ptsUsedMeta = const VerificationMeta(
    'ptsUsed',
  );
  @override
  late final GeneratedColumn<double> ptsUsed = GeneratedColumn<double>(
    'pts_used',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    customerId,
    orderId,
    ptsEarned,
    ptsUsed,
    note,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'loyalty_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<LoyaltyTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('customer_id')) {
      context.handle(
        _customerIdMeta,
        customerId.isAcceptableOrUnknown(data['customer_id']!, _customerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_customerIdMeta);
    }
    if (data.containsKey('order_id')) {
      context.handle(
        _orderIdMeta,
        orderId.isAcceptableOrUnknown(data['order_id']!, _orderIdMeta),
      );
    }
    if (data.containsKey('pts_earned')) {
      context.handle(
        _ptsEarnedMeta,
        ptsEarned.isAcceptableOrUnknown(data['pts_earned']!, _ptsEarnedMeta),
      );
    }
    if (data.containsKey('pts_used')) {
      context.handle(
        _ptsUsedMeta,
        ptsUsed.isAcceptableOrUnknown(data['pts_used']!, _ptsUsedMeta),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LoyaltyTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LoyaltyTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      customerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}customer_id'],
      )!,
      orderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}order_id'],
      ),
      ptsEarned: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pts_earned'],
      )!,
      ptsUsed: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pts_used'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      ),
    );
  }

  @override
  $LoyaltyTransactionsTable createAlias(String alias) {
    return $LoyaltyTransactionsTable(attachedDatabase, alias);
  }
}

class LoyaltyTransaction extends DataClass
    implements Insertable<LoyaltyTransaction> {
  final String id;
  final String customerId;
  final String? orderId;
  final double ptsEarned;
  final double ptsUsed;
  final String? note;
  final int? createdAt;
  const LoyaltyTransaction({
    required this.id,
    required this.customerId,
    this.orderId,
    required this.ptsEarned,
    required this.ptsUsed,
    this.note,
    this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['customer_id'] = Variable<String>(customerId);
    if (!nullToAbsent || orderId != null) {
      map['order_id'] = Variable<String>(orderId);
    }
    map['pts_earned'] = Variable<double>(ptsEarned);
    map['pts_used'] = Variable<double>(ptsUsed);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<int>(createdAt);
    }
    return map;
  }

  LoyaltyTransactionsCompanion toCompanion(bool nullToAbsent) {
    return LoyaltyTransactionsCompanion(
      id: Value(id),
      customerId: Value(customerId),
      orderId: orderId == null && nullToAbsent
          ? const Value.absent()
          : Value(orderId),
      ptsEarned: Value(ptsEarned),
      ptsUsed: Value(ptsUsed),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
    );
  }

  factory LoyaltyTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LoyaltyTransaction(
      id: serializer.fromJson<String>(json['id']),
      customerId: serializer.fromJson<String>(json['customerId']),
      orderId: serializer.fromJson<String?>(json['orderId']),
      ptsEarned: serializer.fromJson<double>(json['ptsEarned']),
      ptsUsed: serializer.fromJson<double>(json['ptsUsed']),
      note: serializer.fromJson<String?>(json['note']),
      createdAt: serializer.fromJson<int?>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'customerId': serializer.toJson<String>(customerId),
      'orderId': serializer.toJson<String?>(orderId),
      'ptsEarned': serializer.toJson<double>(ptsEarned),
      'ptsUsed': serializer.toJson<double>(ptsUsed),
      'note': serializer.toJson<String?>(note),
      'createdAt': serializer.toJson<int?>(createdAt),
    };
  }

  LoyaltyTransaction copyWith({
    String? id,
    String? customerId,
    Value<String?> orderId = const Value.absent(),
    double? ptsEarned,
    double? ptsUsed,
    Value<String?> note = const Value.absent(),
    Value<int?> createdAt = const Value.absent(),
  }) => LoyaltyTransaction(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    orderId: orderId.present ? orderId.value : this.orderId,
    ptsEarned: ptsEarned ?? this.ptsEarned,
    ptsUsed: ptsUsed ?? this.ptsUsed,
    note: note.present ? note.value : this.note,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
  );
  LoyaltyTransaction copyWithCompanion(LoyaltyTransactionsCompanion data) {
    return LoyaltyTransaction(
      id: data.id.present ? data.id.value : this.id,
      customerId: data.customerId.present
          ? data.customerId.value
          : this.customerId,
      orderId: data.orderId.present ? data.orderId.value : this.orderId,
      ptsEarned: data.ptsEarned.present ? data.ptsEarned.value : this.ptsEarned,
      ptsUsed: data.ptsUsed.present ? data.ptsUsed.value : this.ptsUsed,
      note: data.note.present ? data.note.value : this.note,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LoyaltyTransaction(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('orderId: $orderId, ')
          ..write('ptsEarned: $ptsEarned, ')
          ..write('ptsUsed: $ptsUsed, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, customerId, orderId, ptsEarned, ptsUsed, note, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoyaltyTransaction &&
          other.id == this.id &&
          other.customerId == this.customerId &&
          other.orderId == this.orderId &&
          other.ptsEarned == this.ptsEarned &&
          other.ptsUsed == this.ptsUsed &&
          other.note == this.note &&
          other.createdAt == this.createdAt);
}

class LoyaltyTransactionsCompanion extends UpdateCompanion<LoyaltyTransaction> {
  final Value<String> id;
  final Value<String> customerId;
  final Value<String?> orderId;
  final Value<double> ptsEarned;
  final Value<double> ptsUsed;
  final Value<String?> note;
  final Value<int?> createdAt;
  final Value<int> rowid;
  const LoyaltyTransactionsCompanion({
    this.id = const Value.absent(),
    this.customerId = const Value.absent(),
    this.orderId = const Value.absent(),
    this.ptsEarned = const Value.absent(),
    this.ptsUsed = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LoyaltyTransactionsCompanion.insert({
    required String id,
    required String customerId,
    this.orderId = const Value.absent(),
    this.ptsEarned = const Value.absent(),
    this.ptsUsed = const Value.absent(),
    this.note = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       customerId = Value(customerId);
  static Insertable<LoyaltyTransaction> custom({
    Expression<String>? id,
    Expression<String>? customerId,
    Expression<String>? orderId,
    Expression<double>? ptsEarned,
    Expression<double>? ptsUsed,
    Expression<String>? note,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (customerId != null) 'customer_id': customerId,
      if (orderId != null) 'order_id': orderId,
      if (ptsEarned != null) 'pts_earned': ptsEarned,
      if (ptsUsed != null) 'pts_used': ptsUsed,
      if (note != null) 'note': note,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LoyaltyTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? customerId,
    Value<String?>? orderId,
    Value<double>? ptsEarned,
    Value<double>? ptsUsed,
    Value<String?>? note,
    Value<int?>? createdAt,
    Value<int>? rowid,
  }) {
    return LoyaltyTransactionsCompanion(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      orderId: orderId ?? this.orderId,
      ptsEarned: ptsEarned ?? this.ptsEarned,
      ptsUsed: ptsUsed ?? this.ptsUsed,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (customerId.present) {
      map['customer_id'] = Variable<String>(customerId.value);
    }
    if (orderId.present) {
      map['order_id'] = Variable<String>(orderId.value);
    }
    if (ptsEarned.present) {
      map['pts_earned'] = Variable<double>(ptsEarned.value);
    }
    if (ptsUsed.present) {
      map['pts_used'] = Variable<double>(ptsUsed.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LoyaltyTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('customerId: $customerId, ')
          ..write('orderId: $orderId, ')
          ..write('ptsEarned: $ptsEarned, ')
          ..write('ptsUsed: $ptsUsed, ')
          ..write('note: $note, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LoyaltyRewardsTable extends LoyaltyRewards
    with TableInfo<$LoyaltyRewardsTable, LoyaltyReward> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LoyaltyRewardsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ptsRequiredMeta = const VerificationMeta(
    'ptsRequired',
  );
  @override
  late final GeneratedColumn<double> ptsRequired = GeneratedColumn<double>(
    'pts_required',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _discountAmountMeta = const VerificationMeta(
    'discountAmount',
  );
  @override
  late final GeneratedColumn<double> discountAmount = GeneratedColumn<double>(
    'discount_amount',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    ptsRequired,
    discountAmount,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'loyalty_rewards';
  @override
  VerificationContext validateIntegrity(
    Insertable<LoyaltyReward> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pts_required')) {
      context.handle(
        _ptsRequiredMeta,
        ptsRequired.isAcceptableOrUnknown(
          data['pts_required']!,
          _ptsRequiredMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ptsRequiredMeta);
    }
    if (data.containsKey('discount_amount')) {
      context.handle(
        _discountAmountMeta,
        discountAmount.isAcceptableOrUnknown(
          data['discount_amount']!,
          _discountAmountMeta,
        ),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LoyaltyReward map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LoyaltyReward(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      ptsRequired: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pts_required'],
      )!,
      discountAmount: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}discount_amount'],
      ),
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $LoyaltyRewardsTable createAlias(String alias) {
    return $LoyaltyRewardsTable(attachedDatabase, alias);
  }
}

class LoyaltyReward extends DataClass implements Insertable<LoyaltyReward> {
  final String id;
  final String name;
  final double ptsRequired;
  final double? discountAmount;
  final bool isActive;
  const LoyaltyReward({
    required this.id,
    required this.name,
    required this.ptsRequired,
    this.discountAmount,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['pts_required'] = Variable<double>(ptsRequired);
    if (!nullToAbsent || discountAmount != null) {
      map['discount_amount'] = Variable<double>(discountAmount);
    }
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  LoyaltyRewardsCompanion toCompanion(bool nullToAbsent) {
    return LoyaltyRewardsCompanion(
      id: Value(id),
      name: Value(name),
      ptsRequired: Value(ptsRequired),
      discountAmount: discountAmount == null && nullToAbsent
          ? const Value.absent()
          : Value(discountAmount),
      isActive: Value(isActive),
    );
  }

  factory LoyaltyReward.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LoyaltyReward(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      ptsRequired: serializer.fromJson<double>(json['ptsRequired']),
      discountAmount: serializer.fromJson<double?>(json['discountAmount']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'ptsRequired': serializer.toJson<double>(ptsRequired),
      'discountAmount': serializer.toJson<double?>(discountAmount),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  LoyaltyReward copyWith({
    String? id,
    String? name,
    double? ptsRequired,
    Value<double?> discountAmount = const Value.absent(),
    bool? isActive,
  }) => LoyaltyReward(
    id: id ?? this.id,
    name: name ?? this.name,
    ptsRequired: ptsRequired ?? this.ptsRequired,
    discountAmount: discountAmount.present
        ? discountAmount.value
        : this.discountAmount,
    isActive: isActive ?? this.isActive,
  );
  LoyaltyReward copyWithCompanion(LoyaltyRewardsCompanion data) {
    return LoyaltyReward(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      ptsRequired: data.ptsRequired.present
          ? data.ptsRequired.value
          : this.ptsRequired,
      discountAmount: data.discountAmount.present
          ? data.discountAmount.value
          : this.discountAmount,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LoyaltyReward(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ptsRequired: $ptsRequired, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, ptsRequired, discountAmount, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LoyaltyReward &&
          other.id == this.id &&
          other.name == this.name &&
          other.ptsRequired == this.ptsRequired &&
          other.discountAmount == this.discountAmount &&
          other.isActive == this.isActive);
}

class LoyaltyRewardsCompanion extends UpdateCompanion<LoyaltyReward> {
  final Value<String> id;
  final Value<String> name;
  final Value<double> ptsRequired;
  final Value<double?> discountAmount;
  final Value<bool> isActive;
  final Value<int> rowid;
  const LoyaltyRewardsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.ptsRequired = const Value.absent(),
    this.discountAmount = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LoyaltyRewardsCompanion.insert({
    required String id,
    required String name,
    required double ptsRequired,
    this.discountAmount = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       ptsRequired = Value(ptsRequired);
  static Insertable<LoyaltyReward> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<double>? ptsRequired,
    Expression<double>? discountAmount,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (ptsRequired != null) 'pts_required': ptsRequired,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LoyaltyRewardsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<double>? ptsRequired,
    Value<double?>? discountAmount,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return LoyaltyRewardsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      ptsRequired: ptsRequired ?? this.ptsRequired,
      discountAmount: discountAmount ?? this.discountAmount,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ptsRequired.present) {
      map['pts_required'] = Variable<double>(ptsRequired.value);
    }
    if (discountAmount.present) {
      map['discount_amount'] = Variable<double>(discountAmount.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LoyaltyRewardsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('ptsRequired: $ptsRequired, ')
          ..write('discountAmount: $discountAmount, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BanZonesTable extends BanZones with TableInfo<$BanZonesTable, BanZone> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BanZonesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#1C2151'),
  );
  static const VerificationMeta _iconCodeMeta = const VerificationMeta(
    'iconCode',
  );
  @override
  late final GeneratedColumn<int> iconCode = GeneratedColumn<int>(
    'icon_code',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0xe318),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _canvasXMeta = const VerificationMeta(
    'canvasX',
  );
  @override
  late final GeneratedColumn<double> canvasX = GeneratedColumn<double>(
    'canvas_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(40.0),
  );
  static const VerificationMeta _canvasYMeta = const VerificationMeta(
    'canvasY',
  );
  @override
  late final GeneratedColumn<double> canvasY = GeneratedColumn<double>(
    'canvas_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(40.0),
  );
  static const VerificationMeta _canvasWidthMeta = const VerificationMeta(
    'canvasWidth',
  );
  @override
  late final GeneratedColumn<double> canvasWidth = GeneratedColumn<double>(
    'canvas_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(220.0),
  );
  static const VerificationMeta _canvasHeightMeta = const VerificationMeta(
    'canvasHeight',
  );
  @override
  late final GeneratedColumn<double> canvasHeight = GeneratedColumn<double>(
    'canvas_height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(160.0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    iconCode,
    sortOrder,
    isActive,
    createdAt,
    canvasX,
    canvasY,
    canvasWidth,
    canvasHeight,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ban_zones';
  @override
  VerificationContext validateIntegrity(
    Insertable<BanZone> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('icon_code')) {
      context.handle(
        _iconCodeMeta,
        iconCode.isAcceptableOrUnknown(data['icon_code']!, _iconCodeMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('canvas_x')) {
      context.handle(
        _canvasXMeta,
        canvasX.isAcceptableOrUnknown(data['canvas_x']!, _canvasXMeta),
      );
    }
    if (data.containsKey('canvas_y')) {
      context.handle(
        _canvasYMeta,
        canvasY.isAcceptableOrUnknown(data['canvas_y']!, _canvasYMeta),
      );
    }
    if (data.containsKey('canvas_width')) {
      context.handle(
        _canvasWidthMeta,
        canvasWidth.isAcceptableOrUnknown(
          data['canvas_width']!,
          _canvasWidthMeta,
        ),
      );
    }
    if (data.containsKey('canvas_height')) {
      context.handle(
        _canvasHeightMeta,
        canvasHeight.isAcceptableOrUnknown(
          data['canvas_height']!,
          _canvasHeightMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BanZone map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BanZone(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      iconCode: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}icon_code'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      canvasX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}canvas_x'],
      )!,
      canvasY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}canvas_y'],
      )!,
      canvasWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}canvas_width'],
      )!,
      canvasHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}canvas_height'],
      )!,
    );
  }

  @override
  $BanZonesTable createAlias(String alias) {
    return $BanZonesTable(attachedDatabase, alias);
  }
}

class BanZone extends DataClass implements Insertable<BanZone> {
  final String id;
  final String name;
  final String color;
  final int iconCode;
  final int sortOrder;
  final bool isActive;
  final int createdAt;
  final double canvasX;
  final double canvasY;
  final double canvasWidth;
  final double canvasHeight;
  const BanZone({
    required this.id,
    required this.name,
    required this.color,
    required this.iconCode,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
    required this.canvasX,
    required this.canvasY,
    required this.canvasWidth,
    required this.canvasHeight,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['icon_code'] = Variable<int>(iconCode);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<int>(createdAt);
    map['canvas_x'] = Variable<double>(canvasX);
    map['canvas_y'] = Variable<double>(canvasY);
    map['canvas_width'] = Variable<double>(canvasWidth);
    map['canvas_height'] = Variable<double>(canvasHeight);
    return map;
  }

  BanZonesCompanion toCompanion(bool nullToAbsent) {
    return BanZonesCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      iconCode: Value(iconCode),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
      canvasX: Value(canvasX),
      canvasY: Value(canvasY),
      canvasWidth: Value(canvasWidth),
      canvasHeight: Value(canvasHeight),
    );
  }

  factory BanZone.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BanZone(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      iconCode: serializer.fromJson<int>(json['iconCode']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      canvasX: serializer.fromJson<double>(json['canvasX']),
      canvasY: serializer.fromJson<double>(json['canvasY']),
      canvasWidth: serializer.fromJson<double>(json['canvasWidth']),
      canvasHeight: serializer.fromJson<double>(json['canvasHeight']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'iconCode': serializer.toJson<int>(iconCode),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<int>(createdAt),
      'canvasX': serializer.toJson<double>(canvasX),
      'canvasY': serializer.toJson<double>(canvasY),
      'canvasWidth': serializer.toJson<double>(canvasWidth),
      'canvasHeight': serializer.toJson<double>(canvasHeight),
    };
  }

  BanZone copyWith({
    String? id,
    String? name,
    String? color,
    int? iconCode,
    int? sortOrder,
    bool? isActive,
    int? createdAt,
    double? canvasX,
    double? canvasY,
    double? canvasWidth,
    double? canvasHeight,
  }) => BanZone(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    iconCode: iconCode ?? this.iconCode,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
    canvasX: canvasX ?? this.canvasX,
    canvasY: canvasY ?? this.canvasY,
    canvasWidth: canvasWidth ?? this.canvasWidth,
    canvasHeight: canvasHeight ?? this.canvasHeight,
  );
  BanZone copyWithCompanion(BanZonesCompanion data) {
    return BanZone(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      iconCode: data.iconCode.present ? data.iconCode.value : this.iconCode,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      canvasX: data.canvasX.present ? data.canvasX.value : this.canvasX,
      canvasY: data.canvasY.present ? data.canvasY.value : this.canvasY,
      canvasWidth: data.canvasWidth.present
          ? data.canvasWidth.value
          : this.canvasWidth,
      canvasHeight: data.canvasHeight.present
          ? data.canvasHeight.value
          : this.canvasHeight,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BanZone(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('iconCode: $iconCode, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('canvasX: $canvasX, ')
          ..write('canvasY: $canvasY, ')
          ..write('canvasWidth: $canvasWidth, ')
          ..write('canvasHeight: $canvasHeight')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    color,
    iconCode,
    sortOrder,
    isActive,
    createdAt,
    canvasX,
    canvasY,
    canvasWidth,
    canvasHeight,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BanZone &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.iconCode == this.iconCode &&
          other.sortOrder == this.sortOrder &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt &&
          other.canvasX == this.canvasX &&
          other.canvasY == this.canvasY &&
          other.canvasWidth == this.canvasWidth &&
          other.canvasHeight == this.canvasHeight);
}

class BanZonesCompanion extends UpdateCompanion<BanZone> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<int> iconCode;
  final Value<int> sortOrder;
  final Value<bool> isActive;
  final Value<int> createdAt;
  final Value<double> canvasX;
  final Value<double> canvasY;
  final Value<double> canvasWidth;
  final Value<double> canvasHeight;
  final Value<int> rowid;
  const BanZonesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.iconCode = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.canvasX = const Value.absent(),
    this.canvasY = const Value.absent(),
    this.canvasWidth = const Value.absent(),
    this.canvasHeight = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BanZonesCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.iconCode = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    required int createdAt,
    this.canvasX = const Value.absent(),
    this.canvasY = const Value.absent(),
    this.canvasWidth = const Value.absent(),
    this.canvasHeight = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<BanZone> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? iconCode,
    Expression<int>? sortOrder,
    Expression<bool>? isActive,
    Expression<int>? createdAt,
    Expression<double>? canvasX,
    Expression<double>? canvasY,
    Expression<double>? canvasWidth,
    Expression<double>? canvasHeight,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (iconCode != null) 'icon_code': iconCode,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (canvasX != null) 'canvas_x': canvasX,
      if (canvasY != null) 'canvas_y': canvasY,
      if (canvasWidth != null) 'canvas_width': canvasWidth,
      if (canvasHeight != null) 'canvas_height': canvasHeight,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BanZonesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? color,
    Value<int>? iconCode,
    Value<int>? sortOrder,
    Value<bool>? isActive,
    Value<int>? createdAt,
    Value<double>? canvasX,
    Value<double>? canvasY,
    Value<double>? canvasWidth,
    Value<double>? canvasHeight,
    Value<int>? rowid,
  }) {
    return BanZonesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      iconCode: iconCode ?? this.iconCode,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      canvasX: canvasX ?? this.canvasX,
      canvasY: canvasY ?? this.canvasY,
      canvasWidth: canvasWidth ?? this.canvasWidth,
      canvasHeight: canvasHeight ?? this.canvasHeight,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (iconCode.present) {
      map['icon_code'] = Variable<int>(iconCode.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (canvasX.present) {
      map['canvas_x'] = Variable<double>(canvasX.value);
    }
    if (canvasY.present) {
      map['canvas_y'] = Variable<double>(canvasY.value);
    }
    if (canvasWidth.present) {
      map['canvas_width'] = Variable<double>(canvasWidth.value);
    }
    if (canvasHeight.present) {
      map['canvas_height'] = Variable<double>(canvasHeight.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BanZonesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('iconCode: $iconCode, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('canvasX: $canvasX, ')
          ..write('canvasY: $canvasY, ')
          ..write('canvasWidth: $canvasWidth, ')
          ..write('canvasHeight: $canvasHeight, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BanDiningTablesTable extends BanDiningTables
    with TableInfo<$BanDiningTablesTable, BanDiningTable> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BanDiningTablesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zoneIdMeta = const VerificationMeta('zoneId');
  @override
  late final GeneratedColumn<String> zoneId = GeneratedColumn<String>(
    'zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ban_zones (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capacityMeta = const VerificationMeta(
    'capacity',
  );
  @override
  late final GeneratedColumn<int> capacity = GeneratedColumn<int>(
    'capacity',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(4),
  );
  static const VerificationMeta _posXMeta = const VerificationMeta('posX');
  @override
  late final GeneratedColumn<double> posX = GeneratedColumn<double>(
    'pos_x',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100.0),
  );
  static const VerificationMeta _posYMeta = const VerificationMeta('posY');
  @override
  late final GeneratedColumn<double> posY = GeneratedColumn<double>(
    'pos_y',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100.0),
  );
  static const VerificationMeta _shapeMeta = const VerificationMeta('shape');
  @override
  late final GeneratedColumn<String> shape = GeneratedColumn<String>(
    'shape',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('rect'),
  );
  static const VerificationMeta _tableWidthMeta = const VerificationMeta(
    'tableWidth',
  );
  @override
  late final GeneratedColumn<double> tableWidth = GeneratedColumn<double>(
    'table_width',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(90.0),
  );
  static const VerificationMeta _tableHeightMeta = const VerificationMeta(
    'tableHeight',
  );
  @override
  late final GeneratedColumn<double> tableHeight = GeneratedColumn<double>(
    'table_height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(65.0),
  );
  static const VerificationMeta _qrTokenMeta = const VerificationMeta(
    'qrToken',
  );
  @override
  late final GeneratedColumn<String> qrToken = GeneratedColumn<String>(
    'qr_token',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    zoneId,
    name,
    capacity,
    posX,
    posY,
    shape,
    tableWidth,
    tableHeight,
    qrToken,
    sortOrder,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ban_dining_tables';
  @override
  VerificationContext validateIntegrity(
    Insertable<BanDiningTable> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('zone_id')) {
      context.handle(
        _zoneIdMeta,
        zoneId.isAcceptableOrUnknown(data['zone_id']!, _zoneIdMeta),
      );
    } else if (isInserting) {
      context.missing(_zoneIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('capacity')) {
      context.handle(
        _capacityMeta,
        capacity.isAcceptableOrUnknown(data['capacity']!, _capacityMeta),
      );
    }
    if (data.containsKey('pos_x')) {
      context.handle(
        _posXMeta,
        posX.isAcceptableOrUnknown(data['pos_x']!, _posXMeta),
      );
    }
    if (data.containsKey('pos_y')) {
      context.handle(
        _posYMeta,
        posY.isAcceptableOrUnknown(data['pos_y']!, _posYMeta),
      );
    }
    if (data.containsKey('shape')) {
      context.handle(
        _shapeMeta,
        shape.isAcceptableOrUnknown(data['shape']!, _shapeMeta),
      );
    }
    if (data.containsKey('table_width')) {
      context.handle(
        _tableWidthMeta,
        tableWidth.isAcceptableOrUnknown(data['table_width']!, _tableWidthMeta),
      );
    }
    if (data.containsKey('table_height')) {
      context.handle(
        _tableHeightMeta,
        tableHeight.isAcceptableOrUnknown(
          data['table_height']!,
          _tableHeightMeta,
        ),
      );
    }
    if (data.containsKey('qr_token')) {
      context.handle(
        _qrTokenMeta,
        qrToken.isAcceptableOrUnknown(data['qr_token']!, _qrTokenMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BanDiningTable map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BanDiningTable(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      zoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      capacity: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}capacity'],
      )!,
      posX: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_x'],
      )!,
      posY: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pos_y'],
      )!,
      shape: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}shape'],
      )!,
      tableWidth: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}table_width'],
      )!,
      tableHeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}table_height'],
      )!,
      qrToken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}qr_token'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $BanDiningTablesTable createAlias(String alias) {
    return $BanDiningTablesTable(attachedDatabase, alias);
  }
}

class BanDiningTable extends DataClass implements Insertable<BanDiningTable> {
  final String id;
  final String zoneId;
  final String name;
  final int capacity;
  final double posX;
  final double posY;
  final String shape;
  final double tableWidth;
  final double tableHeight;
  final String? qrToken;
  final int sortOrder;
  final bool isActive;
  final int createdAt;
  const BanDiningTable({
    required this.id,
    required this.zoneId,
    required this.name,
    required this.capacity,
    required this.posX,
    required this.posY,
    required this.shape,
    required this.tableWidth,
    required this.tableHeight,
    this.qrToken,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['zone_id'] = Variable<String>(zoneId);
    map['name'] = Variable<String>(name);
    map['capacity'] = Variable<int>(capacity);
    map['pos_x'] = Variable<double>(posX);
    map['pos_y'] = Variable<double>(posY);
    map['shape'] = Variable<String>(shape);
    map['table_width'] = Variable<double>(tableWidth);
    map['table_height'] = Variable<double>(tableHeight);
    if (!nullToAbsent || qrToken != null) {
      map['qr_token'] = Variable<String>(qrToken);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  BanDiningTablesCompanion toCompanion(bool nullToAbsent) {
    return BanDiningTablesCompanion(
      id: Value(id),
      zoneId: Value(zoneId),
      name: Value(name),
      capacity: Value(capacity),
      posX: Value(posX),
      posY: Value(posY),
      shape: Value(shape),
      tableWidth: Value(tableWidth),
      tableHeight: Value(tableHeight),
      qrToken: qrToken == null && nullToAbsent
          ? const Value.absent()
          : Value(qrToken),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory BanDiningTable.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BanDiningTable(
      id: serializer.fromJson<String>(json['id']),
      zoneId: serializer.fromJson<String>(json['zoneId']),
      name: serializer.fromJson<String>(json['name']),
      capacity: serializer.fromJson<int>(json['capacity']),
      posX: serializer.fromJson<double>(json['posX']),
      posY: serializer.fromJson<double>(json['posY']),
      shape: serializer.fromJson<String>(json['shape']),
      tableWidth: serializer.fromJson<double>(json['tableWidth']),
      tableHeight: serializer.fromJson<double>(json['tableHeight']),
      qrToken: serializer.fromJson<String?>(json['qrToken']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'zoneId': serializer.toJson<String>(zoneId),
      'name': serializer.toJson<String>(name),
      'capacity': serializer.toJson<int>(capacity),
      'posX': serializer.toJson<double>(posX),
      'posY': serializer.toJson<double>(posY),
      'shape': serializer.toJson<String>(shape),
      'tableWidth': serializer.toJson<double>(tableWidth),
      'tableHeight': serializer.toJson<double>(tableHeight),
      'qrToken': serializer.toJson<String?>(qrToken),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  BanDiningTable copyWith({
    String? id,
    String? zoneId,
    String? name,
    int? capacity,
    double? posX,
    double? posY,
    String? shape,
    double? tableWidth,
    double? tableHeight,
    Value<String?> qrToken = const Value.absent(),
    int? sortOrder,
    bool? isActive,
    int? createdAt,
  }) => BanDiningTable(
    id: id ?? this.id,
    zoneId: zoneId ?? this.zoneId,
    name: name ?? this.name,
    capacity: capacity ?? this.capacity,
    posX: posX ?? this.posX,
    posY: posY ?? this.posY,
    shape: shape ?? this.shape,
    tableWidth: tableWidth ?? this.tableWidth,
    tableHeight: tableHeight ?? this.tableHeight,
    qrToken: qrToken.present ? qrToken.value : this.qrToken,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  BanDiningTable copyWithCompanion(BanDiningTablesCompanion data) {
    return BanDiningTable(
      id: data.id.present ? data.id.value : this.id,
      zoneId: data.zoneId.present ? data.zoneId.value : this.zoneId,
      name: data.name.present ? data.name.value : this.name,
      capacity: data.capacity.present ? data.capacity.value : this.capacity,
      posX: data.posX.present ? data.posX.value : this.posX,
      posY: data.posY.present ? data.posY.value : this.posY,
      shape: data.shape.present ? data.shape.value : this.shape,
      tableWidth: data.tableWidth.present
          ? data.tableWidth.value
          : this.tableWidth,
      tableHeight: data.tableHeight.present
          ? data.tableHeight.value
          : this.tableHeight,
      qrToken: data.qrToken.present ? data.qrToken.value : this.qrToken,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BanDiningTable(')
          ..write('id: $id, ')
          ..write('zoneId: $zoneId, ')
          ..write('name: $name, ')
          ..write('capacity: $capacity, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('shape: $shape, ')
          ..write('tableWidth: $tableWidth, ')
          ..write('tableHeight: $tableHeight, ')
          ..write('qrToken: $qrToken, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    zoneId,
    name,
    capacity,
    posX,
    posY,
    shape,
    tableWidth,
    tableHeight,
    qrToken,
    sortOrder,
    isActive,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BanDiningTable &&
          other.id == this.id &&
          other.zoneId == this.zoneId &&
          other.name == this.name &&
          other.capacity == this.capacity &&
          other.posX == this.posX &&
          other.posY == this.posY &&
          other.shape == this.shape &&
          other.tableWidth == this.tableWidth &&
          other.tableHeight == this.tableHeight &&
          other.qrToken == this.qrToken &&
          other.sortOrder == this.sortOrder &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class BanDiningTablesCompanion extends UpdateCompanion<BanDiningTable> {
  final Value<String> id;
  final Value<String> zoneId;
  final Value<String> name;
  final Value<int> capacity;
  final Value<double> posX;
  final Value<double> posY;
  final Value<String> shape;
  final Value<double> tableWidth;
  final Value<double> tableHeight;
  final Value<String?> qrToken;
  final Value<int> sortOrder;
  final Value<bool> isActive;
  final Value<int> createdAt;
  final Value<int> rowid;
  const BanDiningTablesCompanion({
    this.id = const Value.absent(),
    this.zoneId = const Value.absent(),
    this.name = const Value.absent(),
    this.capacity = const Value.absent(),
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.shape = const Value.absent(),
    this.tableWidth = const Value.absent(),
    this.tableHeight = const Value.absent(),
    this.qrToken = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BanDiningTablesCompanion.insert({
    required String id,
    required String zoneId,
    required String name,
    this.capacity = const Value.absent(),
    this.posX = const Value.absent(),
    this.posY = const Value.absent(),
    this.shape = const Value.absent(),
    this.tableWidth = const Value.absent(),
    this.tableHeight = const Value.absent(),
    this.qrToken = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       zoneId = Value(zoneId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<BanDiningTable> custom({
    Expression<String>? id,
    Expression<String>? zoneId,
    Expression<String>? name,
    Expression<int>? capacity,
    Expression<double>? posX,
    Expression<double>? posY,
    Expression<String>? shape,
    Expression<double>? tableWidth,
    Expression<double>? tableHeight,
    Expression<String>? qrToken,
    Expression<int>? sortOrder,
    Expression<bool>? isActive,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (zoneId != null) 'zone_id': zoneId,
      if (name != null) 'name': name,
      if (capacity != null) 'capacity': capacity,
      if (posX != null) 'pos_x': posX,
      if (posY != null) 'pos_y': posY,
      if (shape != null) 'shape': shape,
      if (tableWidth != null) 'table_width': tableWidth,
      if (tableHeight != null) 'table_height': tableHeight,
      if (qrToken != null) 'qr_token': qrToken,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BanDiningTablesCompanion copyWith({
    Value<String>? id,
    Value<String>? zoneId,
    Value<String>? name,
    Value<int>? capacity,
    Value<double>? posX,
    Value<double>? posY,
    Value<String>? shape,
    Value<double>? tableWidth,
    Value<double>? tableHeight,
    Value<String?>? qrToken,
    Value<int>? sortOrder,
    Value<bool>? isActive,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return BanDiningTablesCompanion(
      id: id ?? this.id,
      zoneId: zoneId ?? this.zoneId,
      name: name ?? this.name,
      capacity: capacity ?? this.capacity,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      shape: shape ?? this.shape,
      tableWidth: tableWidth ?? this.tableWidth,
      tableHeight: tableHeight ?? this.tableHeight,
      qrToken: qrToken ?? this.qrToken,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (zoneId.present) {
      map['zone_id'] = Variable<String>(zoneId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (capacity.present) {
      map['capacity'] = Variable<int>(capacity.value);
    }
    if (posX.present) {
      map['pos_x'] = Variable<double>(posX.value);
    }
    if (posY.present) {
      map['pos_y'] = Variable<double>(posY.value);
    }
    if (shape.present) {
      map['shape'] = Variable<String>(shape.value);
    }
    if (tableWidth.present) {
      map['table_width'] = Variable<double>(tableWidth.value);
    }
    if (tableHeight.present) {
      map['table_height'] = Variable<double>(tableHeight.value);
    }
    if (qrToken.present) {
      map['qr_token'] = Variable<String>(qrToken.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BanDiningTablesCompanion(')
          ..write('id: $id, ')
          ..write('zoneId: $zoneId, ')
          ..write('name: $name, ')
          ..write('capacity: $capacity, ')
          ..write('posX: $posX, ')
          ..write('posY: $posY, ')
          ..write('shape: $shape, ')
          ..write('tableWidth: $tableWidth, ')
          ..write('tableHeight: $tableHeight, ')
          ..write('qrToken: $qrToken, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BanSessionsTable extends BanSessions
    with TableInfo<$BanSessionsTable, BanSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BanSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tableIdMeta = const VerificationMeta(
    'tableId',
  );
  @override
  late final GeneratedColumn<String> tableId = GeneratedColumn<String>(
    'table_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ban_dining_tables (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('open'),
  );
  static const VerificationMeta _guestCountMeta = const VerificationMeta(
    'guestCount',
  );
  @override
  late final GeneratedColumn<int> guestCount = GeneratedColumn<int>(
    'guest_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _staffIdMeta = const VerificationMeta(
    'staffId',
  );
  @override
  late final GeneratedColumn<String> staffId = GeneratedColumn<String>(
    'staff_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _posOrderIdMeta = const VerificationMeta(
    'posOrderId',
  );
  @override
  late final GeneratedColumn<String> posOrderId = GeneratedColumn<String>(
    'pos_order_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta(
    'openedAt',
  );
  @override
  late final GeneratedColumn<int> openedAt = GeneratedColumn<int>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtMeta = const VerificationMeta(
    'closedAt',
  );
  @override
  late final GeneratedColumn<int> closedAt = GeneratedColumn<int>(
    'closed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tableId,
    status,
    guestCount,
    staffId,
    posOrderId,
    note,
    openedAt,
    closedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ban_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<BanSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('table_id')) {
      context.handle(
        _tableIdMeta,
        tableId.isAcceptableOrUnknown(data['table_id']!, _tableIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tableIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('guest_count')) {
      context.handle(
        _guestCountMeta,
        guestCount.isAcceptableOrUnknown(data['guest_count']!, _guestCountMeta),
      );
    }
    if (data.containsKey('staff_id')) {
      context.handle(
        _staffIdMeta,
        staffId.isAcceptableOrUnknown(data['staff_id']!, _staffIdMeta),
      );
    }
    if (data.containsKey('pos_order_id')) {
      context.handle(
        _posOrderIdMeta,
        posOrderId.isAcceptableOrUnknown(
          data['pos_order_id']!,
          _posOrderIdMeta,
        ),
      );
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('opened_at')) {
      context.handle(
        _openedAtMeta,
        openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    if (data.containsKey('closed_at')) {
      context.handle(
        _closedAtMeta,
        closedAt.isAcceptableOrUnknown(data['closed_at']!, _closedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BanSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BanSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tableId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      guestCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}guest_count'],
      )!,
      staffId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}staff_id'],
      ),
      posOrderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos_order_id'],
      ),
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      openedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}opened_at'],
      )!,
      closedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_at'],
      ),
    );
  }

  @override
  $BanSessionsTable createAlias(String alias) {
    return $BanSessionsTable(attachedDatabase, alias);
  }
}

class BanSession extends DataClass implements Insertable<BanSession> {
  final String id;
  final String tableId;
  final String status;
  final int guestCount;
  final String? staffId;
  final String? posOrderId;
  final String? note;
  final int openedAt;
  final int? closedAt;
  const BanSession({
    required this.id,
    required this.tableId,
    required this.status,
    required this.guestCount,
    this.staffId,
    this.posOrderId,
    this.note,
    required this.openedAt,
    this.closedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['table_id'] = Variable<String>(tableId);
    map['status'] = Variable<String>(status);
    map['guest_count'] = Variable<int>(guestCount);
    if (!nullToAbsent || staffId != null) {
      map['staff_id'] = Variable<String>(staffId);
    }
    if (!nullToAbsent || posOrderId != null) {
      map['pos_order_id'] = Variable<String>(posOrderId);
    }
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['opened_at'] = Variable<int>(openedAt);
    if (!nullToAbsent || closedAt != null) {
      map['closed_at'] = Variable<int>(closedAt);
    }
    return map;
  }

  BanSessionsCompanion toCompanion(bool nullToAbsent) {
    return BanSessionsCompanion(
      id: Value(id),
      tableId: Value(tableId),
      status: Value(status),
      guestCount: Value(guestCount),
      staffId: staffId == null && nullToAbsent
          ? const Value.absent()
          : Value(staffId),
      posOrderId: posOrderId == null && nullToAbsent
          ? const Value.absent()
          : Value(posOrderId),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      openedAt: Value(openedAt),
      closedAt: closedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAt),
    );
  }

  factory BanSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BanSession(
      id: serializer.fromJson<String>(json['id']),
      tableId: serializer.fromJson<String>(json['tableId']),
      status: serializer.fromJson<String>(json['status']),
      guestCount: serializer.fromJson<int>(json['guestCount']),
      staffId: serializer.fromJson<String?>(json['staffId']),
      posOrderId: serializer.fromJson<String?>(json['posOrderId']),
      note: serializer.fromJson<String?>(json['note']),
      openedAt: serializer.fromJson<int>(json['openedAt']),
      closedAt: serializer.fromJson<int?>(json['closedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tableId': serializer.toJson<String>(tableId),
      'status': serializer.toJson<String>(status),
      'guestCount': serializer.toJson<int>(guestCount),
      'staffId': serializer.toJson<String?>(staffId),
      'posOrderId': serializer.toJson<String?>(posOrderId),
      'note': serializer.toJson<String?>(note),
      'openedAt': serializer.toJson<int>(openedAt),
      'closedAt': serializer.toJson<int?>(closedAt),
    };
  }

  BanSession copyWith({
    String? id,
    String? tableId,
    String? status,
    int? guestCount,
    Value<String?> staffId = const Value.absent(),
    Value<String?> posOrderId = const Value.absent(),
    Value<String?> note = const Value.absent(),
    int? openedAt,
    Value<int?> closedAt = const Value.absent(),
  }) => BanSession(
    id: id ?? this.id,
    tableId: tableId ?? this.tableId,
    status: status ?? this.status,
    guestCount: guestCount ?? this.guestCount,
    staffId: staffId.present ? staffId.value : this.staffId,
    posOrderId: posOrderId.present ? posOrderId.value : this.posOrderId,
    note: note.present ? note.value : this.note,
    openedAt: openedAt ?? this.openedAt,
    closedAt: closedAt.present ? closedAt.value : this.closedAt,
  );
  BanSession copyWithCompanion(BanSessionsCompanion data) {
    return BanSession(
      id: data.id.present ? data.id.value : this.id,
      tableId: data.tableId.present ? data.tableId.value : this.tableId,
      status: data.status.present ? data.status.value : this.status,
      guestCount: data.guestCount.present
          ? data.guestCount.value
          : this.guestCount,
      staffId: data.staffId.present ? data.staffId.value : this.staffId,
      posOrderId: data.posOrderId.present
          ? data.posOrderId.value
          : this.posOrderId,
      note: data.note.present ? data.note.value : this.note,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      closedAt: data.closedAt.present ? data.closedAt.value : this.closedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BanSession(')
          ..write('id: $id, ')
          ..write('tableId: $tableId, ')
          ..write('status: $status, ')
          ..write('guestCount: $guestCount, ')
          ..write('staffId: $staffId, ')
          ..write('posOrderId: $posOrderId, ')
          ..write('note: $note, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tableId,
    status,
    guestCount,
    staffId,
    posOrderId,
    note,
    openedAt,
    closedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BanSession &&
          other.id == this.id &&
          other.tableId == this.tableId &&
          other.status == this.status &&
          other.guestCount == this.guestCount &&
          other.staffId == this.staffId &&
          other.posOrderId == this.posOrderId &&
          other.note == this.note &&
          other.openedAt == this.openedAt &&
          other.closedAt == this.closedAt);
}

class BanSessionsCompanion extends UpdateCompanion<BanSession> {
  final Value<String> id;
  final Value<String> tableId;
  final Value<String> status;
  final Value<int> guestCount;
  final Value<String?> staffId;
  final Value<String?> posOrderId;
  final Value<String?> note;
  final Value<int> openedAt;
  final Value<int?> closedAt;
  final Value<int> rowid;
  const BanSessionsCompanion({
    this.id = const Value.absent(),
    this.tableId = const Value.absent(),
    this.status = const Value.absent(),
    this.guestCount = const Value.absent(),
    this.staffId = const Value.absent(),
    this.posOrderId = const Value.absent(),
    this.note = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BanSessionsCompanion.insert({
    required String id,
    required String tableId,
    this.status = const Value.absent(),
    this.guestCount = const Value.absent(),
    this.staffId = const Value.absent(),
    this.posOrderId = const Value.absent(),
    this.note = const Value.absent(),
    required int openedAt,
    this.closedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tableId = Value(tableId),
       openedAt = Value(openedAt);
  static Insertable<BanSession> custom({
    Expression<String>? id,
    Expression<String>? tableId,
    Expression<String>? status,
    Expression<int>? guestCount,
    Expression<String>? staffId,
    Expression<String>? posOrderId,
    Expression<String>? note,
    Expression<int>? openedAt,
    Expression<int>? closedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tableId != null) 'table_id': tableId,
      if (status != null) 'status': status,
      if (guestCount != null) 'guest_count': guestCount,
      if (staffId != null) 'staff_id': staffId,
      if (posOrderId != null) 'pos_order_id': posOrderId,
      if (note != null) 'note': note,
      if (openedAt != null) 'opened_at': openedAt,
      if (closedAt != null) 'closed_at': closedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BanSessionsCompanion copyWith({
    Value<String>? id,
    Value<String>? tableId,
    Value<String>? status,
    Value<int>? guestCount,
    Value<String?>? staffId,
    Value<String?>? posOrderId,
    Value<String?>? note,
    Value<int>? openedAt,
    Value<int?>? closedAt,
    Value<int>? rowid,
  }) {
    return BanSessionsCompanion(
      id: id ?? this.id,
      tableId: tableId ?? this.tableId,
      status: status ?? this.status,
      guestCount: guestCount ?? this.guestCount,
      staffId: staffId ?? this.staffId,
      posOrderId: posOrderId ?? this.posOrderId,
      note: note ?? this.note,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tableId.present) {
      map['table_id'] = Variable<String>(tableId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (guestCount.present) {
      map['guest_count'] = Variable<int>(guestCount.value);
    }
    if (staffId.present) {
      map['staff_id'] = Variable<String>(staffId.value);
    }
    if (posOrderId.present) {
      map['pos_order_id'] = Variable<String>(posOrderId.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<int>(openedAt.value);
    }
    if (closedAt.present) {
      map['closed_at'] = Variable<int>(closedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BanSessionsCompanion(')
          ..write('id: $id, ')
          ..write('tableId: $tableId, ')
          ..write('status: $status, ')
          ..write('guestCount: $guestCount, ')
          ..write('staffId: $staffId, ')
          ..write('posOrderId: $posOrderId, ')
          ..write('note: $note, ')
          ..write('openedAt: $openedAt, ')
          ..write('closedAt: $closedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BanSessionItemsTable extends BanSessionItems
    with TableInfo<$BanSessionItemsTable, BanSessionItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BanSessionItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ban_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unitPriceMeta = const VerificationMeta(
    'unitPrice',
  );
  @override
  late final GeneratedColumn<double> unitPrice = GeneratedColumn<double>(
    'unit_price',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _subtotalMeta = const VerificationMeta(
    'subtotal',
  );
  @override
  late final GeneratedColumn<double> subtotal = GeneratedColumn<double>(
    'subtotal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedByMeta = const VerificationMeta(
    'addedBy',
  );
  @override
  late final GeneratedColumn<String> addedBy = GeneratedColumn<String>(
    'added_by',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<int> addedAt = GeneratedColumn<int>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kitchenStatusMeta = const VerificationMeta(
    'kitchenStatus',
  );
  @override
  late final GeneratedColumn<String> kitchenStatus = GeneratedColumn<String>(
    'kitchen_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('chua_gui'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    productId,
    productName,
    unitPrice,
    quantity,
    subtotal,
    note,
    addedBy,
    addedAt,
    kitchenStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ban_session_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<BanSessionItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('unit_price')) {
      context.handle(
        _unitPriceMeta,
        unitPrice.isAcceptableOrUnknown(data['unit_price']!, _unitPriceMeta),
      );
    } else if (isInserting) {
      context.missing(_unitPriceMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('subtotal')) {
      context.handle(
        _subtotalMeta,
        subtotal.isAcceptableOrUnknown(data['subtotal']!, _subtotalMeta),
      );
    } else if (isInserting) {
      context.missing(_subtotalMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('added_by')) {
      context.handle(
        _addedByMeta,
        addedBy.isAcceptableOrUnknown(data['added_by']!, _addedByMeta),
      );
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('kitchen_status')) {
      context.handle(
        _kitchenStatusMeta,
        kitchenStatus.isAcceptableOrUnknown(
          data['kitchen_status']!,
          _kitchenStatusMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BanSessionItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BanSessionItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      unitPrice: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}unit_price'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      subtotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}subtotal'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      addedBy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}added_by'],
      ),
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}added_at'],
      )!,
      kitchenStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_status'],
      )!,
    );
  }

  @override
  $BanSessionItemsTable createAlias(String alias) {
    return $BanSessionItemsTable(attachedDatabase, alias);
  }
}

class BanSessionItem extends DataClass implements Insertable<BanSessionItem> {
  final String id;
  final String sessionId;
  final String productId;
  final String productName;
  final double unitPrice;
  final double quantity;
  final double subtotal;
  final String? note;
  final String? addedBy;
  final int addedAt;
  final String kitchenStatus;
  const BanSessionItem({
    required this.id,
    required this.sessionId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    this.note,
    this.addedBy,
    required this.addedAt,
    required this.kitchenStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['product_id'] = Variable<String>(productId);
    map['product_name'] = Variable<String>(productName);
    map['unit_price'] = Variable<double>(unitPrice);
    map['quantity'] = Variable<double>(quantity);
    map['subtotal'] = Variable<double>(subtotal);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || addedBy != null) {
      map['added_by'] = Variable<String>(addedBy);
    }
    map['added_at'] = Variable<int>(addedAt);
    map['kitchen_status'] = Variable<String>(kitchenStatus);
    return map;
  }

  BanSessionItemsCompanion toCompanion(bool nullToAbsent) {
    return BanSessionItemsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      productId: Value(productId),
      productName: Value(productName),
      unitPrice: Value(unitPrice),
      quantity: Value(quantity),
      subtotal: Value(subtotal),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      addedBy: addedBy == null && nullToAbsent
          ? const Value.absent()
          : Value(addedBy),
      addedAt: Value(addedAt),
      kitchenStatus: Value(kitchenStatus),
    );
  }

  factory BanSessionItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BanSessionItem(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      productId: serializer.fromJson<String>(json['productId']),
      productName: serializer.fromJson<String>(json['productName']),
      unitPrice: serializer.fromJson<double>(json['unitPrice']),
      quantity: serializer.fromJson<double>(json['quantity']),
      subtotal: serializer.fromJson<double>(json['subtotal']),
      note: serializer.fromJson<String?>(json['note']),
      addedBy: serializer.fromJson<String?>(json['addedBy']),
      addedAt: serializer.fromJson<int>(json['addedAt']),
      kitchenStatus: serializer.fromJson<String>(json['kitchenStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'productId': serializer.toJson<String>(productId),
      'productName': serializer.toJson<String>(productName),
      'unitPrice': serializer.toJson<double>(unitPrice),
      'quantity': serializer.toJson<double>(quantity),
      'subtotal': serializer.toJson<double>(subtotal),
      'note': serializer.toJson<String?>(note),
      'addedBy': serializer.toJson<String?>(addedBy),
      'addedAt': serializer.toJson<int>(addedAt),
      'kitchenStatus': serializer.toJson<String>(kitchenStatus),
    };
  }

  BanSessionItem copyWith({
    String? id,
    String? sessionId,
    String? productId,
    String? productName,
    double? unitPrice,
    double? quantity,
    double? subtotal,
    Value<String?> note = const Value.absent(),
    Value<String?> addedBy = const Value.absent(),
    int? addedAt,
    String? kitchenStatus,
  }) => BanSessionItem(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    unitPrice: unitPrice ?? this.unitPrice,
    quantity: quantity ?? this.quantity,
    subtotal: subtotal ?? this.subtotal,
    note: note.present ? note.value : this.note,
    addedBy: addedBy.present ? addedBy.value : this.addedBy,
    addedAt: addedAt ?? this.addedAt,
    kitchenStatus: kitchenStatus ?? this.kitchenStatus,
  );
  BanSessionItem copyWithCompanion(BanSessionItemsCompanion data) {
    return BanSessionItem(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      productId: data.productId.present ? data.productId.value : this.productId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      unitPrice: data.unitPrice.present ? data.unitPrice.value : this.unitPrice,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      subtotal: data.subtotal.present ? data.subtotal.value : this.subtotal,
      note: data.note.present ? data.note.value : this.note,
      addedBy: data.addedBy.present ? data.addedBy.value : this.addedBy,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      kitchenStatus: data.kitchenStatus.present
          ? data.kitchenStatus.value
          : this.kitchenStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BanSessionItem(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('subtotal: $subtotal, ')
          ..write('note: $note, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedAt: $addedAt, ')
          ..write('kitchenStatus: $kitchenStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    productId,
    productName,
    unitPrice,
    quantity,
    subtotal,
    note,
    addedBy,
    addedAt,
    kitchenStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BanSessionItem &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.productId == this.productId &&
          other.productName == this.productName &&
          other.unitPrice == this.unitPrice &&
          other.quantity == this.quantity &&
          other.subtotal == this.subtotal &&
          other.note == this.note &&
          other.addedBy == this.addedBy &&
          other.addedAt == this.addedAt &&
          other.kitchenStatus == this.kitchenStatus);
}

class BanSessionItemsCompanion extends UpdateCompanion<BanSessionItem> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> productId;
  final Value<String> productName;
  final Value<double> unitPrice;
  final Value<double> quantity;
  final Value<double> subtotal;
  final Value<String?> note;
  final Value<String?> addedBy;
  final Value<int> addedAt;
  final Value<String> kitchenStatus;
  final Value<int> rowid;
  const BanSessionItemsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.productId = const Value.absent(),
    this.productName = const Value.absent(),
    this.unitPrice = const Value.absent(),
    this.quantity = const Value.absent(),
    this.subtotal = const Value.absent(),
    this.note = const Value.absent(),
    this.addedBy = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.kitchenStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BanSessionItemsCompanion.insert({
    required String id,
    required String sessionId,
    required String productId,
    required String productName,
    required double unitPrice,
    this.quantity = const Value.absent(),
    required double subtotal,
    this.note = const Value.absent(),
    this.addedBy = const Value.absent(),
    required int addedAt,
    this.kitchenStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       productId = Value(productId),
       productName = Value(productName),
       unitPrice = Value(unitPrice),
       subtotal = Value(subtotal),
       addedAt = Value(addedAt);
  static Insertable<BanSessionItem> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? productId,
    Expression<String>? productName,
    Expression<double>? unitPrice,
    Expression<double>? quantity,
    Expression<double>? subtotal,
    Expression<String>? note,
    Expression<String>? addedBy,
    Expression<int>? addedAt,
    Expression<String>? kitchenStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (productId != null) 'product_id': productId,
      if (productName != null) 'product_name': productName,
      if (unitPrice != null) 'unit_price': unitPrice,
      if (quantity != null) 'quantity': quantity,
      if (subtotal != null) 'subtotal': subtotal,
      if (note != null) 'note': note,
      if (addedBy != null) 'added_by': addedBy,
      if (addedAt != null) 'added_at': addedAt,
      if (kitchenStatus != null) 'kitchen_status': kitchenStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BanSessionItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? productId,
    Value<String>? productName,
    Value<double>? unitPrice,
    Value<double>? quantity,
    Value<double>? subtotal,
    Value<String?>? note,
    Value<String?>? addedBy,
    Value<int>? addedAt,
    Value<String>? kitchenStatus,
    Value<int>? rowid,
  }) {
    return BanSessionItemsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      note: note ?? this.note,
      addedBy: addedBy ?? this.addedBy,
      addedAt: addedAt ?? this.addedAt,
      kitchenStatus: kitchenStatus ?? this.kitchenStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (unitPrice.present) {
      map['unit_price'] = Variable<double>(unitPrice.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (subtotal.present) {
      map['subtotal'] = Variable<double>(subtotal.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (addedBy.present) {
      map['added_by'] = Variable<String>(addedBy.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<int>(addedAt.value);
    }
    if (kitchenStatus.present) {
      map['kitchen_status'] = Variable<String>(kitchenStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BanSessionItemsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('productId: $productId, ')
          ..write('productName: $productName, ')
          ..write('unitPrice: $unitPrice, ')
          ..write('quantity: $quantity, ')
          ..write('subtotal: $subtotal, ')
          ..write('note: $note, ')
          ..write('addedBy: $addedBy, ')
          ..write('addedAt: $addedAt, ')
          ..write('kitchenStatus: $kitchenStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KitchenStationsTable extends KitchenStations
    with TableInfo<$KitchenStationsTable, KitchenStation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KitchenStationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#1C2151'),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    sortOrder,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kitchen_stations';
  @override
  VerificationContext validateIntegrity(
    Insertable<KitchenStation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KitchenStation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KitchenStation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $KitchenStationsTable createAlias(String alias) {
    return $KitchenStationsTable(attachedDatabase, alias);
  }
}

class KitchenStation extends DataClass implements Insertable<KitchenStation> {
  final String id;
  final String name;
  final String color;
  final int sortOrder;
  final bool isActive;
  final int createdAt;
  const KitchenStation({
    required this.id,
    required this.name,
    required this.color,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  KitchenStationsCompanion toCompanion(bool nullToAbsent) {
    return KitchenStationsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory KitchenStation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KitchenStation(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  KitchenStation copyWith({
    String? id,
    String? name,
    String? color,
    int? sortOrder,
    bool? isActive,
    int? createdAt,
  }) => KitchenStation(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  KitchenStation copyWithCompanion(KitchenStationsCompanion data) {
    return KitchenStation(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KitchenStation(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, sortOrder, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KitchenStation &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.sortOrder == this.sortOrder &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class KitchenStationsCompanion extends UpdateCompanion<KitchenStation> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<int> sortOrder;
  final Value<bool> isActive;
  final Value<int> createdAt;
  final Value<int> rowid;
  const KitchenStationsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KitchenStationsCompanion.insert({
    required String id,
    required String name,
    this.color = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<KitchenStation> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? sortOrder,
    Expression<bool>? isActive,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KitchenStationsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? color,
    Value<int>? sortOrder,
    Value<bool>? isActive,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return KitchenStationsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KitchenStationsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProductModifiersTable extends ProductModifiers
    with TableInfo<$ProductModifiersTable, ProductModifier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProductModifiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _productIdMeta = const VerificationMeta(
    'productId',
  );
  @override
  late final GeneratedColumn<String> productId = GeneratedColumn<String>(
    'product_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES core_products (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _groupNameMeta = const VerificationMeta(
    'groupName',
  );
  @override
  late final GeneratedColumn<String> groupName = GeneratedColumn<String>(
    'group_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Khác'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceAdjustMeta = const VerificationMeta(
    'priceAdjust',
  );
  @override
  late final GeneratedColumn<double> priceAdjust = GeneratedColumn<double>(
    'price_adjust',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    productId,
    groupName,
    name,
    priceAdjust,
    sortOrder,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'product_modifiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProductModifier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('product_id')) {
      context.handle(
        _productIdMeta,
        productId.isAcceptableOrUnknown(data['product_id']!, _productIdMeta),
      );
    } else if (isInserting) {
      context.missing(_productIdMeta);
    }
    if (data.containsKey('group_name')) {
      context.handle(
        _groupNameMeta,
        groupName.isAcceptableOrUnknown(data['group_name']!, _groupNameMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('price_adjust')) {
      context.handle(
        _priceAdjustMeta,
        priceAdjust.isAcceptableOrUnknown(
          data['price_adjust']!,
          _priceAdjustMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProductModifier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProductModifier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      productId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_id'],
      )!,
      groupName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_name'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      priceAdjust: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_adjust'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ProductModifiersTable createAlias(String alias) {
    return $ProductModifiersTable(attachedDatabase, alias);
  }
}

class ProductModifier extends DataClass implements Insertable<ProductModifier> {
  final String id;
  final String productId;
  final String groupName;
  final String name;
  final double priceAdjust;
  final int sortOrder;
  final bool isActive;
  final int createdAt;
  const ProductModifier({
    required this.id,
    required this.productId,
    required this.groupName,
    required this.name,
    required this.priceAdjust,
    required this.sortOrder,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['product_id'] = Variable<String>(productId);
    map['group_name'] = Variable<String>(groupName);
    map['name'] = Variable<String>(name);
    map['price_adjust'] = Variable<double>(priceAdjust);
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  ProductModifiersCompanion toCompanion(bool nullToAbsent) {
    return ProductModifiersCompanion(
      id: Value(id),
      productId: Value(productId),
      groupName: Value(groupName),
      name: Value(name),
      priceAdjust: Value(priceAdjust),
      sortOrder: Value(sortOrder),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory ProductModifier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProductModifier(
      id: serializer.fromJson<String>(json['id']),
      productId: serializer.fromJson<String>(json['productId']),
      groupName: serializer.fromJson<String>(json['groupName']),
      name: serializer.fromJson<String>(json['name']),
      priceAdjust: serializer.fromJson<double>(json['priceAdjust']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'productId': serializer.toJson<String>(productId),
      'groupName': serializer.toJson<String>(groupName),
      'name': serializer.toJson<String>(name),
      'priceAdjust': serializer.toJson<double>(priceAdjust),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  ProductModifier copyWith({
    String? id,
    String? productId,
    String? groupName,
    String? name,
    double? priceAdjust,
    int? sortOrder,
    bool? isActive,
    int? createdAt,
  }) => ProductModifier(
    id: id ?? this.id,
    productId: productId ?? this.productId,
    groupName: groupName ?? this.groupName,
    name: name ?? this.name,
    priceAdjust: priceAdjust ?? this.priceAdjust,
    sortOrder: sortOrder ?? this.sortOrder,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  ProductModifier copyWithCompanion(ProductModifiersCompanion data) {
    return ProductModifier(
      id: data.id.present ? data.id.value : this.id,
      productId: data.productId.present ? data.productId.value : this.productId,
      groupName: data.groupName.present ? data.groupName.value : this.groupName,
      name: data.name.present ? data.name.value : this.name,
      priceAdjust: data.priceAdjust.present
          ? data.priceAdjust.value
          : this.priceAdjust,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProductModifier(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('groupName: $groupName, ')
          ..write('name: $name, ')
          ..write('priceAdjust: $priceAdjust, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    productId,
    groupName,
    name,
    priceAdjust,
    sortOrder,
    isActive,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProductModifier &&
          other.id == this.id &&
          other.productId == this.productId &&
          other.groupName == this.groupName &&
          other.name == this.name &&
          other.priceAdjust == this.priceAdjust &&
          other.sortOrder == this.sortOrder &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class ProductModifiersCompanion extends UpdateCompanion<ProductModifier> {
  final Value<String> id;
  final Value<String> productId;
  final Value<String> groupName;
  final Value<String> name;
  final Value<double> priceAdjust;
  final Value<int> sortOrder;
  final Value<bool> isActive;
  final Value<int> createdAt;
  final Value<int> rowid;
  const ProductModifiersCompanion({
    this.id = const Value.absent(),
    this.productId = const Value.absent(),
    this.groupName = const Value.absent(),
    this.name = const Value.absent(),
    this.priceAdjust = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProductModifiersCompanion.insert({
    required String id,
    required String productId,
    this.groupName = const Value.absent(),
    required String name,
    this.priceAdjust = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isActive = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       productId = Value(productId),
       name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<ProductModifier> custom({
    Expression<String>? id,
    Expression<String>? productId,
    Expression<String>? groupName,
    Expression<String>? name,
    Expression<double>? priceAdjust,
    Expression<int>? sortOrder,
    Expression<bool>? isActive,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (productId != null) 'product_id': productId,
      if (groupName != null) 'group_name': groupName,
      if (name != null) 'name': name,
      if (priceAdjust != null) 'price_adjust': priceAdjust,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProductModifiersCompanion copyWith({
    Value<String>? id,
    Value<String>? productId,
    Value<String>? groupName,
    Value<String>? name,
    Value<double>? priceAdjust,
    Value<int>? sortOrder,
    Value<bool>? isActive,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return ProductModifiersCompanion(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      groupName: groupName ?? this.groupName,
      name: name ?? this.name,
      priceAdjust: priceAdjust ?? this.priceAdjust,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (productId.present) {
      map['product_id'] = Variable<String>(productId.value);
    }
    if (groupName.present) {
      map['group_name'] = Variable<String>(groupName.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (priceAdjust.present) {
      map['price_adjust'] = Variable<double>(priceAdjust.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProductModifiersCompanion(')
          ..write('id: $id, ')
          ..write('productId: $productId, ')
          ..write('groupName: $groupName, ')
          ..write('name: $name, ')
          ..write('priceAdjust: $priceAdjust, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionItemModifiersTable extends SessionItemModifiers
    with TableInfo<$SessionItemModifiersTable, SessionItemModifier> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionItemModifiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionItemIdMeta = const VerificationMeta(
    'sessionItemId',
  );
  @override
  late final GeneratedColumn<String> sessionItemId = GeneratedColumn<String>(
    'session_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ban_session_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _modifierNameMeta = const VerificationMeta(
    'modifierName',
  );
  @override
  late final GeneratedColumn<String> modifierName = GeneratedColumn<String>(
    'modifier_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceAdjustMeta = const VerificationMeta(
    'priceAdjust',
  );
  @override
  late final GeneratedColumn<double> priceAdjust = GeneratedColumn<double>(
    'price_adjust',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionItemId,
    modifierName,
    priceAdjust,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_item_modifiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionItemModifier> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_item_id')) {
      context.handle(
        _sessionItemIdMeta,
        sessionItemId.isAcceptableOrUnknown(
          data['session_item_id']!,
          _sessionItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionItemIdMeta);
    }
    if (data.containsKey('modifier_name')) {
      context.handle(
        _modifierNameMeta,
        modifierName.isAcceptableOrUnknown(
          data['modifier_name']!,
          _modifierNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_modifierNameMeta);
    }
    if (data.containsKey('price_adjust')) {
      context.handle(
        _priceAdjustMeta,
        priceAdjust.isAcceptableOrUnknown(
          data['price_adjust']!,
          _priceAdjustMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionItemModifier map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionItemModifier(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_item_id'],
      )!,
      modifierName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}modifier_name'],
      )!,
      priceAdjust: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}price_adjust'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $SessionItemModifiersTable createAlias(String alias) {
    return $SessionItemModifiersTable(attachedDatabase, alias);
  }
}

class SessionItemModifier extends DataClass
    implements Insertable<SessionItemModifier> {
  final String id;
  final String sessionItemId;
  final String modifierName;
  final double priceAdjust;
  final int sortOrder;
  const SessionItemModifier({
    required this.id,
    required this.sessionItemId,
    required this.modifierName,
    required this.priceAdjust,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_item_id'] = Variable<String>(sessionItemId);
    map['modifier_name'] = Variable<String>(modifierName);
    map['price_adjust'] = Variable<double>(priceAdjust);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  SessionItemModifiersCompanion toCompanion(bool nullToAbsent) {
    return SessionItemModifiersCompanion(
      id: Value(id),
      sessionItemId: Value(sessionItemId),
      modifierName: Value(modifierName),
      priceAdjust: Value(priceAdjust),
      sortOrder: Value(sortOrder),
    );
  }

  factory SessionItemModifier.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionItemModifier(
      id: serializer.fromJson<String>(json['id']),
      sessionItemId: serializer.fromJson<String>(json['sessionItemId']),
      modifierName: serializer.fromJson<String>(json['modifierName']),
      priceAdjust: serializer.fromJson<double>(json['priceAdjust']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionItemId': serializer.toJson<String>(sessionItemId),
      'modifierName': serializer.toJson<String>(modifierName),
      'priceAdjust': serializer.toJson<double>(priceAdjust),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  SessionItemModifier copyWith({
    String? id,
    String? sessionItemId,
    String? modifierName,
    double? priceAdjust,
    int? sortOrder,
  }) => SessionItemModifier(
    id: id ?? this.id,
    sessionItemId: sessionItemId ?? this.sessionItemId,
    modifierName: modifierName ?? this.modifierName,
    priceAdjust: priceAdjust ?? this.priceAdjust,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  SessionItemModifier copyWithCompanion(SessionItemModifiersCompanion data) {
    return SessionItemModifier(
      id: data.id.present ? data.id.value : this.id,
      sessionItemId: data.sessionItemId.present
          ? data.sessionItemId.value
          : this.sessionItemId,
      modifierName: data.modifierName.present
          ? data.modifierName.value
          : this.modifierName,
      priceAdjust: data.priceAdjust.present
          ? data.priceAdjust.value
          : this.priceAdjust,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionItemModifier(')
          ..write('id: $id, ')
          ..write('sessionItemId: $sessionItemId, ')
          ..write('modifierName: $modifierName, ')
          ..write('priceAdjust: $priceAdjust, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, sessionItemId, modifierName, priceAdjust, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionItemModifier &&
          other.id == this.id &&
          other.sessionItemId == this.sessionItemId &&
          other.modifierName == this.modifierName &&
          other.priceAdjust == this.priceAdjust &&
          other.sortOrder == this.sortOrder);
}

class SessionItemModifiersCompanion
    extends UpdateCompanion<SessionItemModifier> {
  final Value<String> id;
  final Value<String> sessionItemId;
  final Value<String> modifierName;
  final Value<double> priceAdjust;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const SessionItemModifiersCompanion({
    this.id = const Value.absent(),
    this.sessionItemId = const Value.absent(),
    this.modifierName = const Value.absent(),
    this.priceAdjust = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionItemModifiersCompanion.insert({
    required String id,
    required String sessionItemId,
    required String modifierName,
    this.priceAdjust = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionItemId = Value(sessionItemId),
       modifierName = Value(modifierName);
  static Insertable<SessionItemModifier> custom({
    Expression<String>? id,
    Expression<String>? sessionItemId,
    Expression<String>? modifierName,
    Expression<double>? priceAdjust,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionItemId != null) 'session_item_id': sessionItemId,
      if (modifierName != null) 'modifier_name': modifierName,
      if (priceAdjust != null) 'price_adjust': priceAdjust,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionItemModifiersCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionItemId,
    Value<String>? modifierName,
    Value<double>? priceAdjust,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return SessionItemModifiersCompanion(
      id: id ?? this.id,
      sessionItemId: sessionItemId ?? this.sessionItemId,
      modifierName: modifierName ?? this.modifierName,
      priceAdjust: priceAdjust ?? this.priceAdjust,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionItemId.present) {
      map['session_item_id'] = Variable<String>(sessionItemId.value);
    }
    if (modifierName.present) {
      map['modifier_name'] = Variable<String>(modifierName.value);
    }
    if (priceAdjust.present) {
      map['price_adjust'] = Variable<double>(priceAdjust.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionItemModifiersCompanion(')
          ..write('id: $id, ')
          ..write('sessionItemId: $sessionItemId, ')
          ..write('modifierName: $modifierName, ')
          ..write('priceAdjust: $priceAdjust, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KitchenTicketsTable extends KitchenTickets
    with TableInfo<$KitchenTicketsTable, KitchenTicket> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KitchenTicketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ban_sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tableLabelMeta = const VerificationMeta(
    'tableLabel',
  );
  @override
  late final GeneratedColumn<String> tableLabel = GeneratedColumn<String>(
    'table_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zoneLabelMeta = const VerificationMeta(
    'zoneLabel',
  );
  @override
  late final GeneratedColumn<String> zoneLabel = GeneratedColumn<String>(
    'zone_label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roundMeta = const VerificationMeta('round');
  @override
  late final GeneratedColumn<int> round = GeneratedColumn<int>(
    'round',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _stationIdMeta = const VerificationMeta(
    'stationId',
  );
  @override
  late final GeneratedColumn<String> stationId = GeneratedColumn<String>(
    'station_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES kitchen_stations (id)',
    ),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cho'),
  );
  static const VerificationMeta _sentAtMeta = const VerificationMeta('sentAt');
  @override
  late final GeneratedColumn<int> sentAt = GeneratedColumn<int>(
    'sent_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<int> doneAt = GeneratedColumn<int>(
    'done_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    tableLabel,
    zoneLabel,
    round,
    stationId,
    status,
    sentAt,
    startedAt,
    doneAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kitchen_tickets';
  @override
  VerificationContext validateIntegrity(
    Insertable<KitchenTicket> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('table_label')) {
      context.handle(
        _tableLabelMeta,
        tableLabel.isAcceptableOrUnknown(data['table_label']!, _tableLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_tableLabelMeta);
    }
    if (data.containsKey('zone_label')) {
      context.handle(
        _zoneLabelMeta,
        zoneLabel.isAcceptableOrUnknown(data['zone_label']!, _zoneLabelMeta),
      );
    } else if (isInserting) {
      context.missing(_zoneLabelMeta);
    }
    if (data.containsKey('round')) {
      context.handle(
        _roundMeta,
        round.isAcceptableOrUnknown(data['round']!, _roundMeta),
      );
    }
    if (data.containsKey('station_id')) {
      context.handle(
        _stationIdMeta,
        stationId.isAcceptableOrUnknown(data['station_id']!, _stationIdMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('sent_at')) {
      context.handle(
        _sentAtMeta,
        sentAt.isAcceptableOrUnknown(data['sent_at']!, _sentAtMeta),
      );
    } else if (isInserting) {
      context.missing(_sentAtMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KitchenTicket map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KitchenTicket(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      tableLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}table_label'],
      )!,
      zoneLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zone_label'],
      )!,
      round: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}round'],
      )!,
      stationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      sentAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sent_at'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      doneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_at'],
      ),
    );
  }

  @override
  $KitchenTicketsTable createAlias(String alias) {
    return $KitchenTicketsTable(attachedDatabase, alias);
  }
}

class KitchenTicket extends DataClass implements Insertable<KitchenTicket> {
  final String id;
  final String sessionId;
  final String tableLabel;
  final String zoneLabel;
  final int round;
  final String? stationId;
  final String status;
  final int sentAt;
  final int? startedAt;
  final int? doneAt;
  const KitchenTicket({
    required this.id,
    required this.sessionId,
    required this.tableLabel,
    required this.zoneLabel,
    required this.round,
    this.stationId,
    required this.status,
    required this.sentAt,
    this.startedAt,
    this.doneAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['session_id'] = Variable<String>(sessionId);
    map['table_label'] = Variable<String>(tableLabel);
    map['zone_label'] = Variable<String>(zoneLabel);
    map['round'] = Variable<int>(round);
    if (!nullToAbsent || stationId != null) {
      map['station_id'] = Variable<String>(stationId);
    }
    map['status'] = Variable<String>(status);
    map['sent_at'] = Variable<int>(sentAt);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<int>(doneAt);
    }
    return map;
  }

  KitchenTicketsCompanion toCompanion(bool nullToAbsent) {
    return KitchenTicketsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      tableLabel: Value(tableLabel),
      zoneLabel: Value(zoneLabel),
      round: Value(round),
      stationId: stationId == null && nullToAbsent
          ? const Value.absent()
          : Value(stationId),
      status: Value(status),
      sentAt: Value(sentAt),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
    );
  }

  factory KitchenTicket.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KitchenTicket(
      id: serializer.fromJson<String>(json['id']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      tableLabel: serializer.fromJson<String>(json['tableLabel']),
      zoneLabel: serializer.fromJson<String>(json['zoneLabel']),
      round: serializer.fromJson<int>(json['round']),
      stationId: serializer.fromJson<String?>(json['stationId']),
      status: serializer.fromJson<String>(json['status']),
      sentAt: serializer.fromJson<int>(json['sentAt']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      doneAt: serializer.fromJson<int?>(json['doneAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sessionId': serializer.toJson<String>(sessionId),
      'tableLabel': serializer.toJson<String>(tableLabel),
      'zoneLabel': serializer.toJson<String>(zoneLabel),
      'round': serializer.toJson<int>(round),
      'stationId': serializer.toJson<String?>(stationId),
      'status': serializer.toJson<String>(status),
      'sentAt': serializer.toJson<int>(sentAt),
      'startedAt': serializer.toJson<int?>(startedAt),
      'doneAt': serializer.toJson<int?>(doneAt),
    };
  }

  KitchenTicket copyWith({
    String? id,
    String? sessionId,
    String? tableLabel,
    String? zoneLabel,
    int? round,
    Value<String?> stationId = const Value.absent(),
    String? status,
    int? sentAt,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> doneAt = const Value.absent(),
  }) => KitchenTicket(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    tableLabel: tableLabel ?? this.tableLabel,
    zoneLabel: zoneLabel ?? this.zoneLabel,
    round: round ?? this.round,
    stationId: stationId.present ? stationId.value : this.stationId,
    status: status ?? this.status,
    sentAt: sentAt ?? this.sentAt,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
  );
  KitchenTicket copyWithCompanion(KitchenTicketsCompanion data) {
    return KitchenTicket(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      tableLabel: data.tableLabel.present
          ? data.tableLabel.value
          : this.tableLabel,
      zoneLabel: data.zoneLabel.present ? data.zoneLabel.value : this.zoneLabel,
      round: data.round.present ? data.round.value : this.round,
      stationId: data.stationId.present ? data.stationId.value : this.stationId,
      status: data.status.present ? data.status.value : this.status,
      sentAt: data.sentAt.present ? data.sentAt.value : this.sentAt,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KitchenTicket(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('zoneLabel: $zoneLabel, ')
          ..write('round: $round, ')
          ..write('stationId: $stationId, ')
          ..write('status: $status, ')
          ..write('sentAt: $sentAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('doneAt: $doneAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sessionId,
    tableLabel,
    zoneLabel,
    round,
    stationId,
    status,
    sentAt,
    startedAt,
    doneAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KitchenTicket &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.tableLabel == this.tableLabel &&
          other.zoneLabel == this.zoneLabel &&
          other.round == this.round &&
          other.stationId == this.stationId &&
          other.status == this.status &&
          other.sentAt == this.sentAt &&
          other.startedAt == this.startedAt &&
          other.doneAt == this.doneAt);
}

class KitchenTicketsCompanion extends UpdateCompanion<KitchenTicket> {
  final Value<String> id;
  final Value<String> sessionId;
  final Value<String> tableLabel;
  final Value<String> zoneLabel;
  final Value<int> round;
  final Value<String?> stationId;
  final Value<String> status;
  final Value<int> sentAt;
  final Value<int?> startedAt;
  final Value<int?> doneAt;
  final Value<int> rowid;
  const KitchenTicketsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.tableLabel = const Value.absent(),
    this.zoneLabel = const Value.absent(),
    this.round = const Value.absent(),
    this.stationId = const Value.absent(),
    this.status = const Value.absent(),
    this.sentAt = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KitchenTicketsCompanion.insert({
    required String id,
    required String sessionId,
    required String tableLabel,
    required String zoneLabel,
    this.round = const Value.absent(),
    this.stationId = const Value.absent(),
    this.status = const Value.absent(),
    required int sentAt,
    this.startedAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sessionId = Value(sessionId),
       tableLabel = Value(tableLabel),
       zoneLabel = Value(zoneLabel),
       sentAt = Value(sentAt);
  static Insertable<KitchenTicket> custom({
    Expression<String>? id,
    Expression<String>? sessionId,
    Expression<String>? tableLabel,
    Expression<String>? zoneLabel,
    Expression<int>? round,
    Expression<String>? stationId,
    Expression<String>? status,
    Expression<int>? sentAt,
    Expression<int>? startedAt,
    Expression<int>? doneAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (tableLabel != null) 'table_label': tableLabel,
      if (zoneLabel != null) 'zone_label': zoneLabel,
      if (round != null) 'round': round,
      if (stationId != null) 'station_id': stationId,
      if (status != null) 'status': status,
      if (sentAt != null) 'sent_at': sentAt,
      if (startedAt != null) 'started_at': startedAt,
      if (doneAt != null) 'done_at': doneAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KitchenTicketsCompanion copyWith({
    Value<String>? id,
    Value<String>? sessionId,
    Value<String>? tableLabel,
    Value<String>? zoneLabel,
    Value<int>? round,
    Value<String?>? stationId,
    Value<String>? status,
    Value<int>? sentAt,
    Value<int?>? startedAt,
    Value<int?>? doneAt,
    Value<int>? rowid,
  }) {
    return KitchenTicketsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      tableLabel: tableLabel ?? this.tableLabel,
      zoneLabel: zoneLabel ?? this.zoneLabel,
      round: round ?? this.round,
      stationId: stationId ?? this.stationId,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      startedAt: startedAt ?? this.startedAt,
      doneAt: doneAt ?? this.doneAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (tableLabel.present) {
      map['table_label'] = Variable<String>(tableLabel.value);
    }
    if (zoneLabel.present) {
      map['zone_label'] = Variable<String>(zoneLabel.value);
    }
    if (round.present) {
      map['round'] = Variable<int>(round.value);
    }
    if (stationId.present) {
      map['station_id'] = Variable<String>(stationId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (sentAt.present) {
      map['sent_at'] = Variable<int>(sentAt.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<int>(doneAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KitchenTicketsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('tableLabel: $tableLabel, ')
          ..write('zoneLabel: $zoneLabel, ')
          ..write('round: $round, ')
          ..write('stationId: $stationId, ')
          ..write('status: $status, ')
          ..write('sentAt: $sentAt, ')
          ..write('startedAt: $startedAt, ')
          ..write('doneAt: $doneAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KitchenTicketItemsTable extends KitchenTicketItems
    with TableInfo<$KitchenTicketItemsTable, KitchenTicketItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KitchenTicketItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ticketIdMeta = const VerificationMeta(
    'ticketId',
  );
  @override
  late final GeneratedColumn<String> ticketId = GeneratedColumn<String>(
    'ticket_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES kitchen_tickets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sessionItemIdMeta = const VerificationMeta(
    'sessionItemId',
  );
  @override
  late final GeneratedColumn<String> sessionItemId = GeneratedColumn<String>(
    'session_item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES ban_session_items (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _productNameMeta = const VerificationMeta(
    'productName',
  );
  @override
  late final GeneratedColumn<String> productName = GeneratedColumn<String>(
    'product_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modifiersJsonMeta = const VerificationMeta(
    'modifiersJson',
  );
  @override
  late final GeneratedColumn<String> modifiersJson = GeneratedColumn<String>(
    'modifiers_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _freeNoteMeta = const VerificationMeta(
    'freeNote',
  );
  @override
  late final GeneratedColumn<String> freeNote = GeneratedColumn<String>(
    'free_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kitchenNoteMeta = const VerificationMeta(
    'kitchenNote',
  );
  @override
  late final GeneratedColumn<String> kitchenNote = GeneratedColumn<String>(
    'kitchen_note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _editHistoryJsonMeta = const VerificationMeta(
    'editHistoryJson',
  );
  @override
  late final GeneratedColumn<String> editHistoryJson = GeneratedColumn<String>(
    'edit_history_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('cho'),
  );
  static const VerificationMeta _stationCodeMeta = const VerificationMeta(
    'stationCode',
  );
  @override
  late final GeneratedColumn<String> stationCode = GeneratedColumn<String>(
    'station_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('nong'),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
    'started_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<int> doneAt = GeneratedColumn<int>(
    'done_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    ticketId,
    sessionItemId,
    productName,
    quantity,
    modifiersJson,
    freeNote,
    kitchenNote,
    editHistoryJson,
    status,
    stationCode,
    startedAt,
    doneAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kitchen_ticket_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<KitchenTicketItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('ticket_id')) {
      context.handle(
        _ticketIdMeta,
        ticketId.isAcceptableOrUnknown(data['ticket_id']!, _ticketIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ticketIdMeta);
    }
    if (data.containsKey('session_item_id')) {
      context.handle(
        _sessionItemIdMeta,
        sessionItemId.isAcceptableOrUnknown(
          data['session_item_id']!,
          _sessionItemIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sessionItemIdMeta);
    }
    if (data.containsKey('product_name')) {
      context.handle(
        _productNameMeta,
        productName.isAcceptableOrUnknown(
          data['product_name']!,
          _productNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_productNameMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('modifiers_json')) {
      context.handle(
        _modifiersJsonMeta,
        modifiersJson.isAcceptableOrUnknown(
          data['modifiers_json']!,
          _modifiersJsonMeta,
        ),
      );
    }
    if (data.containsKey('free_note')) {
      context.handle(
        _freeNoteMeta,
        freeNote.isAcceptableOrUnknown(data['free_note']!, _freeNoteMeta),
      );
    }
    if (data.containsKey('kitchen_note')) {
      context.handle(
        _kitchenNoteMeta,
        kitchenNote.isAcceptableOrUnknown(
          data['kitchen_note']!,
          _kitchenNoteMeta,
        ),
      );
    }
    if (data.containsKey('edit_history_json')) {
      context.handle(
        _editHistoryJsonMeta,
        editHistoryJson.isAcceptableOrUnknown(
          data['edit_history_json']!,
          _editHistoryJsonMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('station_code')) {
      context.handle(
        _stationCodeMeta,
        stationCode.isAcceptableOrUnknown(
          data['station_code']!,
          _stationCodeMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    }
    if (data.containsKey('done_at')) {
      context.handle(
        _doneAtMeta,
        doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KitchenTicketItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KitchenTicketItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      ticketId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ticket_id'],
      )!,
      sessionItemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_item_id'],
      )!,
      productName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}product_name'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      modifiersJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}modifiers_json'],
      )!,
      freeNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}free_note'],
      ),
      kitchenNote: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kitchen_note'],
      ),
      editHistoryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}edit_history_json'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      stationCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}station_code'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at'],
      ),
      doneAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}done_at'],
      ),
    );
  }

  @override
  $KitchenTicketItemsTable createAlias(String alias) {
    return $KitchenTicketItemsTable(attachedDatabase, alias);
  }
}

class KitchenTicketItem extends DataClass
    implements Insertable<KitchenTicketItem> {
  final String id;
  final String ticketId;
  final String sessionItemId;
  final String productName;
  final double quantity;
  final String modifiersJson;
  final String? freeNote;
  final String? kitchenNote;
  final String? editHistoryJson;
  final String status;
  final String stationCode;
  final int? startedAt;
  final int? doneAt;
  const KitchenTicketItem({
    required this.id,
    required this.ticketId,
    required this.sessionItemId,
    required this.productName,
    required this.quantity,
    required this.modifiersJson,
    this.freeNote,
    this.kitchenNote,
    this.editHistoryJson,
    required this.status,
    required this.stationCode,
    this.startedAt,
    this.doneAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['ticket_id'] = Variable<String>(ticketId);
    map['session_item_id'] = Variable<String>(sessionItemId);
    map['product_name'] = Variable<String>(productName);
    map['quantity'] = Variable<double>(quantity);
    map['modifiers_json'] = Variable<String>(modifiersJson);
    if (!nullToAbsent || freeNote != null) {
      map['free_note'] = Variable<String>(freeNote);
    }
    if (!nullToAbsent || kitchenNote != null) {
      map['kitchen_note'] = Variable<String>(kitchenNote);
    }
    if (!nullToAbsent || editHistoryJson != null) {
      map['edit_history_json'] = Variable<String>(editHistoryJson);
    }
    map['status'] = Variable<String>(status);
    map['station_code'] = Variable<String>(stationCode);
    if (!nullToAbsent || startedAt != null) {
      map['started_at'] = Variable<int>(startedAt);
    }
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<int>(doneAt);
    }
    return map;
  }

  KitchenTicketItemsCompanion toCompanion(bool nullToAbsent) {
    return KitchenTicketItemsCompanion(
      id: Value(id),
      ticketId: Value(ticketId),
      sessionItemId: Value(sessionItemId),
      productName: Value(productName),
      quantity: Value(quantity),
      modifiersJson: Value(modifiersJson),
      freeNote: freeNote == null && nullToAbsent
          ? const Value.absent()
          : Value(freeNote),
      kitchenNote: kitchenNote == null && nullToAbsent
          ? const Value.absent()
          : Value(kitchenNote),
      editHistoryJson: editHistoryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(editHistoryJson),
      status: Value(status),
      stationCode: Value(stationCode),
      startedAt: startedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(startedAt),
      doneAt: doneAt == null && nullToAbsent
          ? const Value.absent()
          : Value(doneAt),
    );
  }

  factory KitchenTicketItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KitchenTicketItem(
      id: serializer.fromJson<String>(json['id']),
      ticketId: serializer.fromJson<String>(json['ticketId']),
      sessionItemId: serializer.fromJson<String>(json['sessionItemId']),
      productName: serializer.fromJson<String>(json['productName']),
      quantity: serializer.fromJson<double>(json['quantity']),
      modifiersJson: serializer.fromJson<String>(json['modifiersJson']),
      freeNote: serializer.fromJson<String?>(json['freeNote']),
      kitchenNote: serializer.fromJson<String?>(json['kitchenNote']),
      editHistoryJson: serializer.fromJson<String?>(json['editHistoryJson']),
      status: serializer.fromJson<String>(json['status']),
      stationCode: serializer.fromJson<String>(json['stationCode']),
      startedAt: serializer.fromJson<int?>(json['startedAt']),
      doneAt: serializer.fromJson<int?>(json['doneAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'ticketId': serializer.toJson<String>(ticketId),
      'sessionItemId': serializer.toJson<String>(sessionItemId),
      'productName': serializer.toJson<String>(productName),
      'quantity': serializer.toJson<double>(quantity),
      'modifiersJson': serializer.toJson<String>(modifiersJson),
      'freeNote': serializer.toJson<String?>(freeNote),
      'kitchenNote': serializer.toJson<String?>(kitchenNote),
      'editHistoryJson': serializer.toJson<String?>(editHistoryJson),
      'status': serializer.toJson<String>(status),
      'stationCode': serializer.toJson<String>(stationCode),
      'startedAt': serializer.toJson<int?>(startedAt),
      'doneAt': serializer.toJson<int?>(doneAt),
    };
  }

  KitchenTicketItem copyWith({
    String? id,
    String? ticketId,
    String? sessionItemId,
    String? productName,
    double? quantity,
    String? modifiersJson,
    Value<String?> freeNote = const Value.absent(),
    Value<String?> kitchenNote = const Value.absent(),
    Value<String?> editHistoryJson = const Value.absent(),
    String? status,
    String? stationCode,
    Value<int?> startedAt = const Value.absent(),
    Value<int?> doneAt = const Value.absent(),
  }) => KitchenTicketItem(
    id: id ?? this.id,
    ticketId: ticketId ?? this.ticketId,
    sessionItemId: sessionItemId ?? this.sessionItemId,
    productName: productName ?? this.productName,
    quantity: quantity ?? this.quantity,
    modifiersJson: modifiersJson ?? this.modifiersJson,
    freeNote: freeNote.present ? freeNote.value : this.freeNote,
    kitchenNote: kitchenNote.present ? kitchenNote.value : this.kitchenNote,
    editHistoryJson: editHistoryJson.present
        ? editHistoryJson.value
        : this.editHistoryJson,
    status: status ?? this.status,
    stationCode: stationCode ?? this.stationCode,
    startedAt: startedAt.present ? startedAt.value : this.startedAt,
    doneAt: doneAt.present ? doneAt.value : this.doneAt,
  );
  KitchenTicketItem copyWithCompanion(KitchenTicketItemsCompanion data) {
    return KitchenTicketItem(
      id: data.id.present ? data.id.value : this.id,
      ticketId: data.ticketId.present ? data.ticketId.value : this.ticketId,
      sessionItemId: data.sessionItemId.present
          ? data.sessionItemId.value
          : this.sessionItemId,
      productName: data.productName.present
          ? data.productName.value
          : this.productName,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      modifiersJson: data.modifiersJson.present
          ? data.modifiersJson.value
          : this.modifiersJson,
      freeNote: data.freeNote.present ? data.freeNote.value : this.freeNote,
      kitchenNote: data.kitchenNote.present
          ? data.kitchenNote.value
          : this.kitchenNote,
      editHistoryJson: data.editHistoryJson.present
          ? data.editHistoryJson.value
          : this.editHistoryJson,
      status: data.status.present ? data.status.value : this.status,
      stationCode: data.stationCode.present
          ? data.stationCode.value
          : this.stationCode,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KitchenTicketItem(')
          ..write('id: $id, ')
          ..write('ticketId: $ticketId, ')
          ..write('sessionItemId: $sessionItemId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('modifiersJson: $modifiersJson, ')
          ..write('freeNote: $freeNote, ')
          ..write('kitchenNote: $kitchenNote, ')
          ..write('editHistoryJson: $editHistoryJson, ')
          ..write('status: $status, ')
          ..write('stationCode: $stationCode, ')
          ..write('startedAt: $startedAt, ')
          ..write('doneAt: $doneAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    ticketId,
    sessionItemId,
    productName,
    quantity,
    modifiersJson,
    freeNote,
    kitchenNote,
    editHistoryJson,
    status,
    stationCode,
    startedAt,
    doneAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KitchenTicketItem &&
          other.id == this.id &&
          other.ticketId == this.ticketId &&
          other.sessionItemId == this.sessionItemId &&
          other.productName == this.productName &&
          other.quantity == this.quantity &&
          other.modifiersJson == this.modifiersJson &&
          other.freeNote == this.freeNote &&
          other.kitchenNote == this.kitchenNote &&
          other.editHistoryJson == this.editHistoryJson &&
          other.status == this.status &&
          other.stationCode == this.stationCode &&
          other.startedAt == this.startedAt &&
          other.doneAt == this.doneAt);
}

class KitchenTicketItemsCompanion extends UpdateCompanion<KitchenTicketItem> {
  final Value<String> id;
  final Value<String> ticketId;
  final Value<String> sessionItemId;
  final Value<String> productName;
  final Value<double> quantity;
  final Value<String> modifiersJson;
  final Value<String?> freeNote;
  final Value<String?> kitchenNote;
  final Value<String?> editHistoryJson;
  final Value<String> status;
  final Value<String> stationCode;
  final Value<int?> startedAt;
  final Value<int?> doneAt;
  final Value<int> rowid;
  const KitchenTicketItemsCompanion({
    this.id = const Value.absent(),
    this.ticketId = const Value.absent(),
    this.sessionItemId = const Value.absent(),
    this.productName = const Value.absent(),
    this.quantity = const Value.absent(),
    this.modifiersJson = const Value.absent(),
    this.freeNote = const Value.absent(),
    this.kitchenNote = const Value.absent(),
    this.editHistoryJson = const Value.absent(),
    this.status = const Value.absent(),
    this.stationCode = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KitchenTicketItemsCompanion.insert({
    required String id,
    required String ticketId,
    required String sessionItemId,
    required String productName,
    required double quantity,
    this.modifiersJson = const Value.absent(),
    this.freeNote = const Value.absent(),
    this.kitchenNote = const Value.absent(),
    this.editHistoryJson = const Value.absent(),
    this.status = const Value.absent(),
    this.stationCode = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       ticketId = Value(ticketId),
       sessionItemId = Value(sessionItemId),
       productName = Value(productName),
       quantity = Value(quantity);
  static Insertable<KitchenTicketItem> custom({
    Expression<String>? id,
    Expression<String>? ticketId,
    Expression<String>? sessionItemId,
    Expression<String>? productName,
    Expression<double>? quantity,
    Expression<String>? modifiersJson,
    Expression<String>? freeNote,
    Expression<String>? kitchenNote,
    Expression<String>? editHistoryJson,
    Expression<String>? status,
    Expression<String>? stationCode,
    Expression<int>? startedAt,
    Expression<int>? doneAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (ticketId != null) 'ticket_id': ticketId,
      if (sessionItemId != null) 'session_item_id': sessionItemId,
      if (productName != null) 'product_name': productName,
      if (quantity != null) 'quantity': quantity,
      if (modifiersJson != null) 'modifiers_json': modifiersJson,
      if (freeNote != null) 'free_note': freeNote,
      if (kitchenNote != null) 'kitchen_note': kitchenNote,
      if (editHistoryJson != null) 'edit_history_json': editHistoryJson,
      if (status != null) 'status': status,
      if (stationCode != null) 'station_code': stationCode,
      if (startedAt != null) 'started_at': startedAt,
      if (doneAt != null) 'done_at': doneAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KitchenTicketItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? ticketId,
    Value<String>? sessionItemId,
    Value<String>? productName,
    Value<double>? quantity,
    Value<String>? modifiersJson,
    Value<String?>? freeNote,
    Value<String?>? kitchenNote,
    Value<String?>? editHistoryJson,
    Value<String>? status,
    Value<String>? stationCode,
    Value<int?>? startedAt,
    Value<int?>? doneAt,
    Value<int>? rowid,
  }) {
    return KitchenTicketItemsCompanion(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      sessionItemId: sessionItemId ?? this.sessionItemId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      modifiersJson: modifiersJson ?? this.modifiersJson,
      freeNote: freeNote ?? this.freeNote,
      kitchenNote: kitchenNote ?? this.kitchenNote,
      editHistoryJson: editHistoryJson ?? this.editHistoryJson,
      status: status ?? this.status,
      stationCode: stationCode ?? this.stationCode,
      startedAt: startedAt ?? this.startedAt,
      doneAt: doneAt ?? this.doneAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (ticketId.present) {
      map['ticket_id'] = Variable<String>(ticketId.value);
    }
    if (sessionItemId.present) {
      map['session_item_id'] = Variable<String>(sessionItemId.value);
    }
    if (productName.present) {
      map['product_name'] = Variable<String>(productName.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (modifiersJson.present) {
      map['modifiers_json'] = Variable<String>(modifiersJson.value);
    }
    if (freeNote.present) {
      map['free_note'] = Variable<String>(freeNote.value);
    }
    if (kitchenNote.present) {
      map['kitchen_note'] = Variable<String>(kitchenNote.value);
    }
    if (editHistoryJson.present) {
      map['edit_history_json'] = Variable<String>(editHistoryJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (stationCode.present) {
      map['station_code'] = Variable<String>(stationCode.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<int>(doneAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KitchenTicketItemsCompanion(')
          ..write('id: $id, ')
          ..write('ticketId: $ticketId, ')
          ..write('sessionItemId: $sessionItemId, ')
          ..write('productName: $productName, ')
          ..write('quantity: $quantity, ')
          ..write('modifiersJson: $modifiersJson, ')
          ..write('freeNote: $freeNote, ')
          ..write('kitchenNote: $kitchenNote, ')
          ..write('editHistoryJson: $editHistoryJson, ')
          ..write('status: $status, ')
          ..write('stationCode: $stationCode, ')
          ..write('startedAt: $startedAt, ')
          ..write('doneAt: $doneAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ModuleConfigsTable moduleConfigs = $ModuleConfigsTable(this);
  late final $CoreProductsTable coreProducts = $CoreProductsTable(this);
  late final $CoreCustomersTable coreCustomers = $CoreCustomersTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  late final $EventsLogTable eventsLog = $EventsLogTable(this);
  late final $PendingEventsTable pendingEvents = $PendingEventsTable(this);
  late final $PosOrdersTable posOrders = $PosOrdersTable(this);
  late final $PosOrderItemsTable posOrderItems = $PosOrderItemsTable(this);
  late final $KhoStockMovementsTable khoStockMovements =
      $KhoStockMovementsTable(this);
  late final $KhoRecipesTable khoRecipes = $KhoRecipesTable(this);
  late final $KhoRecipeItemsTable khoRecipeItems = $KhoRecipeItemsTable(this);
  late final $KhoSuppliersTable khoSuppliers = $KhoSuppliersTable(this);
  late final $KhoPurchaseOrdersTable khoPurchaseOrders =
      $KhoPurchaseOrdersTable(this);
  late final $KhoPurchaseItemsTable khoPurchaseItems = $KhoPurchaseItemsTable(
    this,
  );
  late final $FinanceCategoriesTable financeCategories =
      $FinanceCategoriesTable(this);
  late final $FinanceRecordsTable financeRecords = $FinanceRecordsTable(this);
  late final $LoyaltyTransactionsTable loyaltyTransactions =
      $LoyaltyTransactionsTable(this);
  late final $LoyaltyRewardsTable loyaltyRewards = $LoyaltyRewardsTable(this);
  late final $BanZonesTable banZones = $BanZonesTable(this);
  late final $BanDiningTablesTable banDiningTables = $BanDiningTablesTable(
    this,
  );
  late final $BanSessionsTable banSessions = $BanSessionsTable(this);
  late final $BanSessionItemsTable banSessionItems = $BanSessionItemsTable(
    this,
  );
  late final $KitchenStationsTable kitchenStations = $KitchenStationsTable(
    this,
  );
  late final $ProductModifiersTable productModifiers = $ProductModifiersTable(
    this,
  );
  late final $SessionItemModifiersTable sessionItemModifiers =
      $SessionItemModifiersTable(this);
  late final $KitchenTicketsTable kitchenTickets = $KitchenTicketsTable(this);
  late final $KitchenTicketItemsTable kitchenTicketItems =
      $KitchenTicketItemsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    moduleConfigs,
    coreProducts,
    coreCustomers,
    appSettings,
    eventsLog,
    pendingEvents,
    posOrders,
    posOrderItems,
    khoStockMovements,
    khoRecipes,
    khoRecipeItems,
    khoSuppliers,
    khoPurchaseOrders,
    khoPurchaseItems,
    financeCategories,
    financeRecords,
    loyaltyTransactions,
    loyaltyRewards,
    banZones,
    banDiningTables,
    banSessions,
    banSessionItems,
    kitchenStations,
    productModifiers,
    sessionItemModifiers,
    kitchenTickets,
    kitchenTicketItems,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'events_log',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pending_events', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'pos_orders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('pos_order_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'kho_recipes',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('kho_recipe_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'kho_purchase_orders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('kho_purchase_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ban_zones',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ban_dining_tables', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ban_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('ban_session_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'core_products',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('product_modifiers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ban_session_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('session_item_modifiers', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ban_sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('kitchen_tickets', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'kitchen_tickets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('kitchen_ticket_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'ban_session_items',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('kitchen_ticket_items', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$ModuleConfigsTableCreateCompanionBuilder =
    ModuleConfigsCompanion Function({
      required String id,
      Value<bool> isActive,
      Value<int> position,
      Value<int?> updatedAt,
      Value<int> rowid,
    });
typedef $$ModuleConfigsTableUpdateCompanionBuilder =
    ModuleConfigsCompanion Function({
      Value<String> id,
      Value<bool> isActive,
      Value<int> position,
      Value<int?> updatedAt,
      Value<int> rowid,
    });

class $$ModuleConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $ModuleConfigsTable> {
  $$ModuleConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ModuleConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $ModuleConfigsTable> {
  $$ModuleConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ModuleConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ModuleConfigsTable> {
  $$ModuleConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ModuleConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ModuleConfigsTable,
          ModuleConfig,
          $$ModuleConfigsTableFilterComposer,
          $$ModuleConfigsTableOrderingComposer,
          $$ModuleConfigsTableAnnotationComposer,
          $$ModuleConfigsTableCreateCompanionBuilder,
          $$ModuleConfigsTableUpdateCompanionBuilder,
          (
            ModuleConfig,
            BaseReferences<_$AppDatabase, $ModuleConfigsTable, ModuleConfig>,
          ),
          ModuleConfig,
          PrefetchHooks Function()
        > {
  $$ModuleConfigsTableTableManager(_$AppDatabase db, $ModuleConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ModuleConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ModuleConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ModuleConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModuleConfigsCompanion(
                id: id,
                isActive: isActive,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<bool> isActive = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ModuleConfigsCompanion.insert(
                id: id,
                isActive: isActive,
                position: position,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ModuleConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ModuleConfigsTable,
      ModuleConfig,
      $$ModuleConfigsTableFilterComposer,
      $$ModuleConfigsTableOrderingComposer,
      $$ModuleConfigsTableAnnotationComposer,
      $$ModuleConfigsTableCreateCompanionBuilder,
      $$ModuleConfigsTableUpdateCompanionBuilder,
      (
        ModuleConfig,
        BaseReferences<_$AppDatabase, $ModuleConfigsTable, ModuleConfig>,
      ),
      ModuleConfig,
      PrefetchHooks Function()
    >;
typedef $$CoreProductsTableCreateCompanionBuilder =
    CoreProductsCompanion Function({
      required String id,
      required String name,
      Value<String?> sku,
      Value<String?> category,
      Value<String> unit,
      Value<String> productType,
      Value<double> stockQty,
      Value<double> minStock,
      Value<double> sellPrice,
      Value<double> costPrice,
      Value<String?> imagePath,
      Value<bool> isAvailable,
      Value<bool> isActive,
      Value<bool> isDeleted,
      Value<int> version,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });
typedef $$CoreProductsTableUpdateCompanionBuilder =
    CoreProductsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> sku,
      Value<String?> category,
      Value<String> unit,
      Value<String> productType,
      Value<double> stockQty,
      Value<double> minStock,
      Value<double> sellPrice,
      Value<double> costPrice,
      Value<String?> imagePath,
      Value<bool> isAvailable,
      Value<bool> isActive,
      Value<bool> isDeleted,
      Value<int> version,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });

final class $$CoreProductsTableReferences
    extends BaseReferences<_$AppDatabase, $CoreProductsTable, CoreProduct> {
  $$CoreProductsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$KhoStockMovementsTable, List<KhoStockMovement>>
  _khoStockMovementsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.khoStockMovements,
        aliasName: $_aliasNameGenerator(
          db.coreProducts.id,
          db.khoStockMovements.productId,
        ),
      );

  $$KhoStockMovementsTableProcessedTableManager get khoStockMovementsRefs {
    final manager = $$KhoStockMovementsTableTableManager(
      $_db,
      $_db.khoStockMovements,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _khoStockMovementsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$KhoRecipesTable, List<KhoRecipe>>
  _khoRecipesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.khoRecipes,
    aliasName: $_aliasNameGenerator(
      db.coreProducts.id,
      db.khoRecipes.productId,
    ),
  );

  $$KhoRecipesTableProcessedTableManager get khoRecipesRefs {
    final manager = $$KhoRecipesTableTableManager(
      $_db,
      $_db.khoRecipes,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_khoRecipesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$KhoRecipeItemsTable, List<KhoRecipeItem>>
  _khoRecipeItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.khoRecipeItems,
    aliasName: $_aliasNameGenerator(
      db.coreProducts.id,
      db.khoRecipeItems.ingredientId,
    ),
  );

  $$KhoRecipeItemsTableProcessedTableManager get khoRecipeItemsRefs {
    final manager = $$KhoRecipeItemsTableTableManager(
      $_db,
      $_db.khoRecipeItems,
    ).filter((f) => f.ingredientId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_khoRecipeItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ProductModifiersTable, List<ProductModifier>>
  _productModifiersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.productModifiers,
    aliasName: $_aliasNameGenerator(
      db.coreProducts.id,
      db.productModifiers.productId,
    ),
  );

  $$ProductModifiersTableProcessedTableManager get productModifiersRefs {
    final manager = $$ProductModifiersTableTableManager(
      $_db,
      $_db.productModifiers,
    ).filter((f) => f.productId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _productModifiersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CoreProductsTableFilterComposer
    extends Composer<_$AppDatabase, $CoreProductsTable> {
  $$CoreProductsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productType => $composableBuilder(
    column: $table.productType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get stockQty => $composableBuilder(
    column: $table.stockQty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get minStock => $composableBuilder(
    column: $table.minStock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> khoStockMovementsRefs(
    Expression<bool> Function($$KhoStockMovementsTableFilterComposer f) f,
  ) {
    final $$KhoStockMovementsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoStockMovements,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoStockMovementsTableFilterComposer(
            $db: $db,
            $table: $db.khoStockMovements,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> khoRecipesRefs(
    Expression<bool> Function($$KhoRecipesTableFilterComposer f) f,
  ) {
    final $$KhoRecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoRecipes,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipesTableFilterComposer(
            $db: $db,
            $table: $db.khoRecipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> khoRecipeItemsRefs(
    Expression<bool> Function($$KhoRecipeItemsTableFilterComposer f) f,
  ) {
    final $$KhoRecipeItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoRecipeItems,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipeItemsTableFilterComposer(
            $db: $db,
            $table: $db.khoRecipeItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> productModifiersRefs(
    Expression<bool> Function($$ProductModifiersTableFilterComposer f) f,
  ) {
    final $$ProductModifiersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableFilterComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoreProductsTableOrderingComposer
    extends Composer<_$AppDatabase, $CoreProductsTable> {
  $$CoreProductsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sku => $composableBuilder(
    column: $table.sku,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productType => $composableBuilder(
    column: $table.productType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get stockQty => $composableBuilder(
    column: $table.stockQty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get minStock => $composableBuilder(
    column: $table.minStock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sellPrice => $composableBuilder(
    column: $table.sellPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imagePath => $composableBuilder(
    column: $table.imagePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoreProductsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoreProductsTable> {
  $$CoreProductsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get sku =>
      $composableBuilder(column: $table.sku, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  GeneratedColumn<String> get productType => $composableBuilder(
    column: $table.productType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get stockQty =>
      $composableBuilder(column: $table.stockQty, builder: (column) => column);

  GeneratedColumn<double> get minStock =>
      $composableBuilder(column: $table.minStock, builder: (column) => column);

  GeneratedColumn<double> get sellPrice =>
      $composableBuilder(column: $table.sellPrice, builder: (column) => column);

  GeneratedColumn<double> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<String> get imagePath =>
      $composableBuilder(column: $table.imagePath, builder: (column) => column);

  GeneratedColumn<bool> get isAvailable => $composableBuilder(
    column: $table.isAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> khoStockMovementsRefs<T extends Object>(
    Expression<T> Function($$KhoStockMovementsTableAnnotationComposer a) f,
  ) {
    final $$KhoStockMovementsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.khoStockMovements,
          getReferencedColumn: (t) => t.productId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$KhoStockMovementsTableAnnotationComposer(
                $db: $db,
                $table: $db.khoStockMovements,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> khoRecipesRefs<T extends Object>(
    Expression<T> Function($$KhoRecipesTableAnnotationComposer a) f,
  ) {
    final $$KhoRecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoRecipes,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.khoRecipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> khoRecipeItemsRefs<T extends Object>(
    Expression<T> Function($$KhoRecipeItemsTableAnnotationComposer a) f,
  ) {
    final $$KhoRecipeItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoRecipeItems,
      getReferencedColumn: (t) => t.ingredientId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipeItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.khoRecipeItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> productModifiersRefs<T extends Object>(
    Expression<T> Function($$ProductModifiersTableAnnotationComposer a) f,
  ) {
    final $$ProductModifiersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.productModifiers,
      getReferencedColumn: (t) => t.productId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ProductModifiersTableAnnotationComposer(
            $db: $db,
            $table: $db.productModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoreProductsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoreProductsTable,
          CoreProduct,
          $$CoreProductsTableFilterComposer,
          $$CoreProductsTableOrderingComposer,
          $$CoreProductsTableAnnotationComposer,
          $$CoreProductsTableCreateCompanionBuilder,
          $$CoreProductsTableUpdateCompanionBuilder,
          (CoreProduct, $$CoreProductsTableReferences),
          CoreProduct,
          PrefetchHooks Function({
            bool khoStockMovementsRefs,
            bool khoRecipesRefs,
            bool khoRecipeItemsRefs,
            bool productModifiersRefs,
          })
        > {
  $$CoreProductsTableTableManager(_$AppDatabase db, $CoreProductsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoreProductsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoreProductsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoreProductsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> sku = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> productType = const Value.absent(),
                Value<double> stockQty = const Value.absent(),
                Value<double> minStock = const Value.absent(),
                Value<double> sellPrice = const Value.absent(),
                Value<double> costPrice = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoreProductsCompanion(
                id: id,
                name: name,
                sku: sku,
                category: category,
                unit: unit,
                productType: productType,
                stockQty: stockQty,
                minStock: minStock,
                sellPrice: sellPrice,
                costPrice: costPrice,
                imagePath: imagePath,
                isAvailable: isAvailable,
                isActive: isActive,
                isDeleted: isDeleted,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> sku = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<String> productType = const Value.absent(),
                Value<double> stockQty = const Value.absent(),
                Value<double> minStock = const Value.absent(),
                Value<double> sellPrice = const Value.absent(),
                Value<double> costPrice = const Value.absent(),
                Value<String?> imagePath = const Value.absent(),
                Value<bool> isAvailable = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoreProductsCompanion.insert(
                id: id,
                name: name,
                sku: sku,
                category: category,
                unit: unit,
                productType: productType,
                stockQty: stockQty,
                minStock: minStock,
                sellPrice: sellPrice,
                costPrice: costPrice,
                imagePath: imagePath,
                isAvailable: isAvailable,
                isActive: isActive,
                isDeleted: isDeleted,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CoreProductsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                khoStockMovementsRefs = false,
                khoRecipesRefs = false,
                khoRecipeItemsRefs = false,
                productModifiersRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (khoStockMovementsRefs) db.khoStockMovements,
                    if (khoRecipesRefs) db.khoRecipes,
                    if (khoRecipeItemsRefs) db.khoRecipeItems,
                    if (productModifiersRefs) db.productModifiers,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (khoStockMovementsRefs)
                        await $_getPrefetchedData<
                          CoreProduct,
                          $CoreProductsTable,
                          KhoStockMovement
                        >(
                          currentTable: table,
                          referencedTable: $$CoreProductsTableReferences
                              ._khoStockMovementsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoreProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).khoStockMovementsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (khoRecipesRefs)
                        await $_getPrefetchedData<
                          CoreProduct,
                          $CoreProductsTable,
                          KhoRecipe
                        >(
                          currentTable: table,
                          referencedTable: $$CoreProductsTableReferences
                              ._khoRecipesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoreProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).khoRecipesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (khoRecipeItemsRefs)
                        await $_getPrefetchedData<
                          CoreProduct,
                          $CoreProductsTable,
                          KhoRecipeItem
                        >(
                          currentTable: table,
                          referencedTable: $$CoreProductsTableReferences
                              ._khoRecipeItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoreProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).khoRecipeItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ingredientId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (productModifiersRefs)
                        await $_getPrefetchedData<
                          CoreProduct,
                          $CoreProductsTable,
                          ProductModifier
                        >(
                          currentTable: table,
                          referencedTable: $$CoreProductsTableReferences
                              ._productModifiersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoreProductsTableReferences(
                                db,
                                table,
                                p0,
                              ).productModifiersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.productId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CoreProductsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoreProductsTable,
      CoreProduct,
      $$CoreProductsTableFilterComposer,
      $$CoreProductsTableOrderingComposer,
      $$CoreProductsTableAnnotationComposer,
      $$CoreProductsTableCreateCompanionBuilder,
      $$CoreProductsTableUpdateCompanionBuilder,
      (CoreProduct, $$CoreProductsTableReferences),
      CoreProduct,
      PrefetchHooks Function({
        bool khoStockMovementsRefs,
        bool khoRecipesRefs,
        bool khoRecipeItemsRefs,
        bool productModifiersRefs,
      })
    >;
typedef $$CoreCustomersTableCreateCompanionBuilder =
    CoreCustomersCompanion Function({
      required String id,
      required String name,
      Value<String?> phone,
      Value<String?> email,
      Value<int?> birthday,
      Value<double> loyaltyPts,
      Value<double> totalSpent,
      Value<int> visitCount,
      Value<String?> note,
      Value<bool> isDeleted,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });
typedef $$CoreCustomersTableUpdateCompanionBuilder =
    CoreCustomersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> phone,
      Value<String?> email,
      Value<int?> birthday,
      Value<double> loyaltyPts,
      Value<double> totalSpent,
      Value<int> visitCount,
      Value<String?> note,
      Value<bool> isDeleted,
      Value<int?> createdAt,
      Value<int?> updatedAt,
      Value<int> rowid,
    });

final class $$CoreCustomersTableReferences
    extends BaseReferences<_$AppDatabase, $CoreCustomersTable, CoreCustomer> {
  $$CoreCustomersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$PosOrdersTable, List<PosOrder>>
  _posOrdersRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.posOrders,
    aliasName: $_aliasNameGenerator(
      db.coreCustomers.id,
      db.posOrders.customerId,
    ),
  );

  $$PosOrdersTableProcessedTableManager get posOrdersRefs {
    final manager = $$PosOrdersTableTableManager(
      $_db,
      $_db.posOrders,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_posOrdersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $LoyaltyTransactionsTable,
    List<LoyaltyTransaction>
  >
  _loyaltyTransactionsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.loyaltyTransactions,
        aliasName: $_aliasNameGenerator(
          db.coreCustomers.id,
          db.loyaltyTransactions.customerId,
        ),
      );

  $$LoyaltyTransactionsTableProcessedTableManager get loyaltyTransactionsRefs {
    final manager = $$LoyaltyTransactionsTableTableManager(
      $_db,
      $_db.loyaltyTransactions,
    ).filter((f) => f.customerId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _loyaltyTransactionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$CoreCustomersTableFilterComposer
    extends Composer<_$AppDatabase, $CoreCustomersTable> {
  $$CoreCustomersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get birthday => $composableBuilder(
    column: $table.birthday,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get loyaltyPts => $composableBuilder(
    column: $table.loyaltyPts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get visitCount => $composableBuilder(
    column: $table.visitCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> posOrdersRefs(
    Expression<bool> Function($$PosOrdersTableFilterComposer f) f,
  ) {
    final $$PosOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posOrders,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PosOrdersTableFilterComposer(
            $db: $db,
            $table: $db.posOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> loyaltyTransactionsRefs(
    Expression<bool> Function($$LoyaltyTransactionsTableFilterComposer f) f,
  ) {
    final $$LoyaltyTransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.loyaltyTransactions,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$LoyaltyTransactionsTableFilterComposer(
            $db: $db,
            $table: $db.loyaltyTransactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$CoreCustomersTableOrderingComposer
    extends Composer<_$AppDatabase, $CoreCustomersTable> {
  $$CoreCustomersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get birthday => $composableBuilder(
    column: $table.birthday,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get loyaltyPts => $composableBuilder(
    column: $table.loyaltyPts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get visitCount => $composableBuilder(
    column: $table.visitCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CoreCustomersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CoreCustomersTable> {
  $$CoreCustomersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<int> get birthday =>
      $composableBuilder(column: $table.birthday, builder: (column) => column);

  GeneratedColumn<double> get loyaltyPts => $composableBuilder(
    column: $table.loyaltyPts,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalSpent => $composableBuilder(
    column: $table.totalSpent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get visitCount => $composableBuilder(
    column: $table.visitCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> posOrdersRefs<T extends Object>(
    Expression<T> Function($$PosOrdersTableAnnotationComposer a) f,
  ) {
    final $$PosOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posOrders,
      getReferencedColumn: (t) => t.customerId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PosOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.posOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> loyaltyTransactionsRefs<T extends Object>(
    Expression<T> Function($$LoyaltyTransactionsTableAnnotationComposer a) f,
  ) {
    final $$LoyaltyTransactionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.loyaltyTransactions,
          getReferencedColumn: (t) => t.customerId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$LoyaltyTransactionsTableAnnotationComposer(
                $db: $db,
                $table: $db.loyaltyTransactions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$CoreCustomersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CoreCustomersTable,
          CoreCustomer,
          $$CoreCustomersTableFilterComposer,
          $$CoreCustomersTableOrderingComposer,
          $$CoreCustomersTableAnnotationComposer,
          $$CoreCustomersTableCreateCompanionBuilder,
          $$CoreCustomersTableUpdateCompanionBuilder,
          (CoreCustomer, $$CoreCustomersTableReferences),
          CoreCustomer,
          PrefetchHooks Function({
            bool posOrdersRefs,
            bool loyaltyTransactionsRefs,
          })
        > {
  $$CoreCustomersTableTableManager(_$AppDatabase db, $CoreCustomersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CoreCustomersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CoreCustomersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CoreCustomersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int?> birthday = const Value.absent(),
                Value<double> loyaltyPts = const Value.absent(),
                Value<double> totalSpent = const Value.absent(),
                Value<int> visitCount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoreCustomersCompanion(
                id: id,
                name: name,
                phone: phone,
                email: email,
                birthday: birthday,
                loyaltyPts: loyaltyPts,
                totalSpent: totalSpent,
                visitCount: visitCount,
                note: note,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<int?> birthday = const Value.absent(),
                Value<double> loyaltyPts = const Value.absent(),
                Value<double> totalSpent = const Value.absent(),
                Value<int> visitCount = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CoreCustomersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                email: email,
                birthday: birthday,
                loyaltyPts: loyaltyPts,
                totalSpent: totalSpent,
                visitCount: visitCount,
                note: note,
                isDeleted: isDeleted,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$CoreCustomersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({posOrdersRefs = false, loyaltyTransactionsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (posOrdersRefs) db.posOrders,
                    if (loyaltyTransactionsRefs) db.loyaltyTransactions,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (posOrdersRefs)
                        await $_getPrefetchedData<
                          CoreCustomer,
                          $CoreCustomersTable,
                          PosOrder
                        >(
                          currentTable: table,
                          referencedTable: $$CoreCustomersTableReferences
                              ._posOrdersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoreCustomersTableReferences(
                                db,
                                table,
                                p0,
                              ).posOrdersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (loyaltyTransactionsRefs)
                        await $_getPrefetchedData<
                          CoreCustomer,
                          $CoreCustomersTable,
                          LoyaltyTransaction
                        >(
                          currentTable: table,
                          referencedTable: $$CoreCustomersTableReferences
                              ._loyaltyTransactionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$CoreCustomersTableReferences(
                                db,
                                table,
                                p0,
                              ).loyaltyTransactionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.customerId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$CoreCustomersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CoreCustomersTable,
      CoreCustomer,
      $$CoreCustomersTableFilterComposer,
      $$CoreCustomersTableOrderingComposer,
      $$CoreCustomersTableAnnotationComposer,
      $$CoreCustomersTableCreateCompanionBuilder,
      $$CoreCustomersTableUpdateCompanionBuilder,
      (CoreCustomer, $$CoreCustomersTableReferences),
      CoreCustomer,
      PrefetchHooks Function({bool posOrdersRefs, bool loyaltyTransactionsRefs})
    >;
typedef $$AppSettingsTableCreateCompanionBuilder =
    AppSettingsCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$AppSettingsTableUpdateCompanionBuilder =
    AppSettingsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppSettingsTable,
          AppSetting,
          $$AppSettingsTableFilterComposer,
          $$AppSettingsTableOrderingComposer,
          $$AppSettingsTableAnnotationComposer,
          $$AppSettingsTableCreateCompanionBuilder,
          $$AppSettingsTableUpdateCompanionBuilder,
          (
            AppSetting,
            BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
          ),
          AppSetting,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => AppSettingsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppSettingsTable,
      AppSetting,
      $$AppSettingsTableFilterComposer,
      $$AppSettingsTableOrderingComposer,
      $$AppSettingsTableAnnotationComposer,
      $$AppSettingsTableCreateCompanionBuilder,
      $$AppSettingsTableUpdateCompanionBuilder,
      (
        AppSetting,
        BaseReferences<_$AppDatabase, $AppSettingsTable, AppSetting>,
      ),
      AppSetting,
      PrefetchHooks Function()
    >;
typedef $$EventsLogTableCreateCompanionBuilder =
    EventsLogCompanion Function({
      required String id,
      required String eventType,
      required String sourceModule,
      required String payload,
      required int createdAt,
      Value<String?> idempotencyKey,
      Value<int> rowid,
    });
typedef $$EventsLogTableUpdateCompanionBuilder =
    EventsLogCompanion Function({
      Value<String> id,
      Value<String> eventType,
      Value<String> sourceModule,
      Value<String> payload,
      Value<int> createdAt,
      Value<String?> idempotencyKey,
      Value<int> rowid,
    });

final class $$EventsLogTableReferences
    extends BaseReferences<_$AppDatabase, $EventsLogTable, EventsLogData> {
  $$EventsLogTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$PendingEventsTable, List<PendingEvent>>
  _pendingEventsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.pendingEvents,
    aliasName: $_aliasNameGenerator(db.eventsLog.id, db.pendingEvents.eventId),
  );

  $$PendingEventsTableProcessedTableManager get pendingEventsRefs {
    final manager = $$PendingEventsTableTableManager(
      $_db,
      $_db.pendingEvents,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pendingEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$EventsLogTableFilterComposer
    extends Composer<_$AppDatabase, $EventsLogTable> {
  $$EventsLogTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceModule => $composableBuilder(
    column: $table.sourceModule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> pendingEventsRefs(
    Expression<bool> Function($$PendingEventsTableFilterComposer f) f,
  ) {
    final $$PendingEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingEvents,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingEventsTableFilterComposer(
            $db: $db,
            $table: $db.pendingEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsLogTableOrderingComposer
    extends Composer<_$AppDatabase, $EventsLogTable> {
  $$EventsLogTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventType => $composableBuilder(
    column: $table.eventType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceModule => $composableBuilder(
    column: $table.sourceModule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EventsLogTableAnnotationComposer
    extends Composer<_$AppDatabase, $EventsLogTable> {
  $$EventsLogTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get eventType =>
      $composableBuilder(column: $table.eventType, builder: (column) => column);

  GeneratedColumn<String> get sourceModule => $composableBuilder(
    column: $table.sourceModule,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  Expression<T> pendingEventsRefs<T extends Object>(
    Expression<T> Function($$PendingEventsTableAnnotationComposer a) f,
  ) {
    final $$PendingEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pendingEvents,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PendingEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.pendingEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$EventsLogTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EventsLogTable,
          EventsLogData,
          $$EventsLogTableFilterComposer,
          $$EventsLogTableOrderingComposer,
          $$EventsLogTableAnnotationComposer,
          $$EventsLogTableCreateCompanionBuilder,
          $$EventsLogTableUpdateCompanionBuilder,
          (EventsLogData, $$EventsLogTableReferences),
          EventsLogData,
          PrefetchHooks Function({bool pendingEventsRefs})
        > {
  $$EventsLogTableTableManager(_$AppDatabase db, $EventsLogTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EventsLogTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EventsLogTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EventsLogTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventType = const Value.absent(),
                Value<String> sourceModule = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String?> idempotencyKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsLogCompanion(
                id: id,
                eventType: eventType,
                sourceModule: sourceModule,
                payload: payload,
                createdAt: createdAt,
                idempotencyKey: idempotencyKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventType,
                required String sourceModule,
                required String payload,
                required int createdAt,
                Value<String?> idempotencyKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EventsLogCompanion.insert(
                id: id,
                eventType: eventType,
                sourceModule: sourceModule,
                payload: payload,
                createdAt: createdAt,
                idempotencyKey: idempotencyKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$EventsLogTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({pendingEventsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (pendingEventsRefs) db.pendingEvents,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (pendingEventsRefs)
                    await $_getPrefetchedData<
                      EventsLogData,
                      $EventsLogTable,
                      PendingEvent
                    >(
                      currentTable: table,
                      referencedTable: $$EventsLogTableReferences
                          ._pendingEventsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$EventsLogTableReferences(
                            db,
                            table,
                            p0,
                          ).pendingEventsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.eventId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$EventsLogTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EventsLogTable,
      EventsLogData,
      $$EventsLogTableFilterComposer,
      $$EventsLogTableOrderingComposer,
      $$EventsLogTableAnnotationComposer,
      $$EventsLogTableCreateCompanionBuilder,
      $$EventsLogTableUpdateCompanionBuilder,
      (EventsLogData, $$EventsLogTableReferences),
      EventsLogData,
      PrefetchHooks Function({bool pendingEventsRefs})
    >;
typedef $$PendingEventsTableCreateCompanionBuilder =
    PendingEventsCompanion Function({
      required String id,
      required String eventId,
      required String targetModule,
      Value<int> retryCount,
      Value<int?> processedAt,
      Value<String?> errorMsg,
      Value<int> rowid,
    });
typedef $$PendingEventsTableUpdateCompanionBuilder =
    PendingEventsCompanion Function({
      Value<String> id,
      Value<String> eventId,
      Value<String> targetModule,
      Value<int> retryCount,
      Value<int?> processedAt,
      Value<String?> errorMsg,
      Value<int> rowid,
    });

final class $$PendingEventsTableReferences
    extends BaseReferences<_$AppDatabase, $PendingEventsTable, PendingEvent> {
  $$PendingEventsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $EventsLogTable _eventIdTable(_$AppDatabase db) =>
      db.eventsLog.createAlias(
        $_aliasNameGenerator(db.pendingEvents.eventId, db.eventsLog.id),
      );

  $$EventsLogTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$EventsLogTableTableManager(
      $_db,
      $_db.eventsLog,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PendingEventsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingEventsTable> {
  $$PendingEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetModule => $composableBuilder(
    column: $table.targetModule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnFilters(column),
  );

  $$EventsLogTableFilterComposer get eventId {
    final $$EventsLogTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.eventsLog,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsLogTableFilterComposer(
            $db: $db,
            $table: $db.eventsLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingEventsTable> {
  $$PendingEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetModule => $composableBuilder(
    column: $table.targetModule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorMsg => $composableBuilder(
    column: $table.errorMsg,
    builder: (column) => ColumnOrderings(column),
  );

  $$EventsLogTableOrderingComposer get eventId {
    final $$EventsLogTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.eventsLog,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsLogTableOrderingComposer(
            $db: $db,
            $table: $db.eventsLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingEventsTable> {
  $$PendingEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get targetModule => $composableBuilder(
    column: $table.targetModule,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get processedAt => $composableBuilder(
    column: $table.processedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorMsg =>
      $composableBuilder(column: $table.errorMsg, builder: (column) => column);

  $$EventsLogTableAnnotationComposer get eventId {
    final $$EventsLogTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.eventsLog,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$EventsLogTableAnnotationComposer(
            $db: $db,
            $table: $db.eventsLog,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PendingEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingEventsTable,
          PendingEvent,
          $$PendingEventsTableFilterComposer,
          $$PendingEventsTableOrderingComposer,
          $$PendingEventsTableAnnotationComposer,
          $$PendingEventsTableCreateCompanionBuilder,
          $$PendingEventsTableUpdateCompanionBuilder,
          (PendingEvent, $$PendingEventsTableReferences),
          PendingEvent,
          PrefetchHooks Function({bool eventId})
        > {
  $$PendingEventsTableTableManager(_$AppDatabase db, $PendingEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<String> targetModule = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> processedAt = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingEventsCompanion(
                id: id,
                eventId: eventId,
                targetModule: targetModule,
                retryCount: retryCount,
                processedAt: processedAt,
                errorMsg: errorMsg,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventId,
                required String targetModule,
                Value<int> retryCount = const Value.absent(),
                Value<int?> processedAt = const Value.absent(),
                Value<String?> errorMsg = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingEventsCompanion.insert(
                id: id,
                eventId: eventId,
                targetModule: targetModule,
                retryCount: retryCount,
                processedAt: processedAt,
                errorMsg: errorMsg,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PendingEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({eventId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (eventId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.eventId,
                                referencedTable: $$PendingEventsTableReferences
                                    ._eventIdTable(db),
                                referencedColumn: $$PendingEventsTableReferences
                                    ._eventIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PendingEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingEventsTable,
      PendingEvent,
      $$PendingEventsTableFilterComposer,
      $$PendingEventsTableOrderingComposer,
      $$PendingEventsTableAnnotationComposer,
      $$PendingEventsTableCreateCompanionBuilder,
      $$PendingEventsTableUpdateCompanionBuilder,
      (PendingEvent, $$PendingEventsTableReferences),
      PendingEvent,
      PrefetchHooks Function({bool eventId})
    >;
typedef $$PosOrdersTableCreateCompanionBuilder =
    PosOrdersCompanion Function({
      required String id,
      required String orderNumber,
      Value<String?> customerId,
      Value<String?> customerName,
      required double subtotal,
      Value<double> discount,
      Value<double> tax,
      required double totalAmount,
      Value<String> paymentMethod,
      Value<double> loyaltyPtsEarned,
      Value<double> loyaltyPtsUsed,
      Value<String> status,
      Value<String?> note,
      Value<bool> receiptPrinted,
      Value<String?> sourceType,
      Value<String?> sourceId,
      Value<String?> staffId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$PosOrdersTableUpdateCompanionBuilder =
    PosOrdersCompanion Function({
      Value<String> id,
      Value<String> orderNumber,
      Value<String?> customerId,
      Value<String?> customerName,
      Value<double> subtotal,
      Value<double> discount,
      Value<double> tax,
      Value<double> totalAmount,
      Value<String> paymentMethod,
      Value<double> loyaltyPtsEarned,
      Value<double> loyaltyPtsUsed,
      Value<String> status,
      Value<String?> note,
      Value<bool> receiptPrinted,
      Value<String?> sourceType,
      Value<String?> sourceId,
      Value<String?> staffId,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$PosOrdersTableReferences
    extends BaseReferences<_$AppDatabase, $PosOrdersTable, PosOrder> {
  $$PosOrdersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoreCustomersTable _customerIdTable(_$AppDatabase db) =>
      db.coreCustomers.createAlias(
        $_aliasNameGenerator(db.posOrders.customerId, db.coreCustomers.id),
      );

  $$CoreCustomersTableProcessedTableManager? get customerId {
    final $_column = $_itemColumn<String>('customer_id');
    if ($_column == null) return null;
    final manager = $$CoreCustomersTableTableManager(
      $_db,
      $_db.coreCustomers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PosOrderItemsTable, List<PosOrderItem>>
  _posOrderItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.posOrderItems,
    aliasName: $_aliasNameGenerator(db.posOrders.id, db.posOrderItems.orderId),
  );

  $$PosOrderItemsTableProcessedTableManager get posOrderItemsRefs {
    final manager = $$PosOrderItemsTableTableManager(
      $_db,
      $_db.posOrderItems,
    ).filter((f) => f.orderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_posOrderItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PosOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $PosOrdersTable> {
  $$PosOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get loyaltyPtsEarned => $composableBuilder(
    column: $table.loyaltyPtsEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get loyaltyPtsUsed => $composableBuilder(
    column: $table.loyaltyPtsUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get receiptPrinted => $composableBuilder(
    column: $table.receiptPrinted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CoreCustomersTableFilterComposer get customerId {
    final $$CoreCustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.coreCustomers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreCustomersTableFilterComposer(
            $db: $db,
            $table: $db.coreCustomers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> posOrderItemsRefs(
    Expression<bool> Function($$PosOrderItemsTableFilterComposer f) f,
  ) {
    final $$PosOrderItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posOrderItems,
      getReferencedColumn: (t) => t.orderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PosOrderItemsTableFilterComposer(
            $db: $db,
            $table: $db.posOrderItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PosOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $PosOrdersTable> {
  $$PosOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discount => $composableBuilder(
    column: $table.discount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tax => $composableBuilder(
    column: $table.tax,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get loyaltyPtsEarned => $composableBuilder(
    column: $table.loyaltyPtsEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get loyaltyPtsUsed => $composableBuilder(
    column: $table.loyaltyPtsUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get receiptPrinted => $composableBuilder(
    column: $table.receiptPrinted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceId => $composableBuilder(
    column: $table.sourceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoreCustomersTableOrderingComposer get customerId {
    final $$CoreCustomersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.coreCustomers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreCustomersTableOrderingComposer(
            $db: $db,
            $table: $db.coreCustomers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PosOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $PosOrdersTable> {
  $$PosOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderNumber => $composableBuilder(
    column: $table.orderNumber,
    builder: (column) => column,
  );

  GeneratedColumn<String> get customerName => $composableBuilder(
    column: $table.customerName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<double> get discount =>
      $composableBuilder(column: $table.discount, builder: (column) => column);

  GeneratedColumn<double> get tax =>
      $composableBuilder(column: $table.tax, builder: (column) => column);

  GeneratedColumn<double> get totalAmount => $composableBuilder(
    column: $table.totalAmount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get paymentMethod => $composableBuilder(
    column: $table.paymentMethod,
    builder: (column) => column,
  );

  GeneratedColumn<double> get loyaltyPtsEarned => $composableBuilder(
    column: $table.loyaltyPtsEarned,
    builder: (column) => column,
  );

  GeneratedColumn<double> get loyaltyPtsUsed => $composableBuilder(
    column: $table.loyaltyPtsUsed,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get receiptPrinted => $composableBuilder(
    column: $table.receiptPrinted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceType => $composableBuilder(
    column: $table.sourceType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceId =>
      $composableBuilder(column: $table.sourceId, builder: (column) => column);

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CoreCustomersTableAnnotationComposer get customerId {
    final $$CoreCustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.coreCustomers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreCustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.coreCustomers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> posOrderItemsRefs<T extends Object>(
    Expression<T> Function($$PosOrderItemsTableAnnotationComposer a) f,
  ) {
    final $$PosOrderItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.posOrderItems,
      getReferencedColumn: (t) => t.orderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PosOrderItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.posOrderItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PosOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PosOrdersTable,
          PosOrder,
          $$PosOrdersTableFilterComposer,
          $$PosOrdersTableOrderingComposer,
          $$PosOrdersTableAnnotationComposer,
          $$PosOrdersTableCreateCompanionBuilder,
          $$PosOrdersTableUpdateCompanionBuilder,
          (PosOrder, $$PosOrdersTableReferences),
          PosOrder,
          PrefetchHooks Function({bool customerId, bool posOrderItemsRefs})
        > {
  $$PosOrdersTableTableManager(_$AppDatabase db, $PosOrdersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PosOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PosOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PosOrdersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderNumber = const Value.absent(),
                Value<String?> customerId = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                Value<double> subtotal = const Value.absent(),
                Value<double> discount = const Value.absent(),
                Value<double> tax = const Value.absent(),
                Value<double> totalAmount = const Value.absent(),
                Value<String> paymentMethod = const Value.absent(),
                Value<double> loyaltyPtsEarned = const Value.absent(),
                Value<double> loyaltyPtsUsed = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> receiptPrinted = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> staffId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PosOrdersCompanion(
                id: id,
                orderNumber: orderNumber,
                customerId: customerId,
                customerName: customerName,
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                totalAmount: totalAmount,
                paymentMethod: paymentMethod,
                loyaltyPtsEarned: loyaltyPtsEarned,
                loyaltyPtsUsed: loyaltyPtsUsed,
                status: status,
                note: note,
                receiptPrinted: receiptPrinted,
                sourceType: sourceType,
                sourceId: sourceId,
                staffId: staffId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderNumber,
                Value<String?> customerId = const Value.absent(),
                Value<String?> customerName = const Value.absent(),
                required double subtotal,
                Value<double> discount = const Value.absent(),
                Value<double> tax = const Value.absent(),
                required double totalAmount,
                Value<String> paymentMethod = const Value.absent(),
                Value<double> loyaltyPtsEarned = const Value.absent(),
                Value<double> loyaltyPtsUsed = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> receiptPrinted = const Value.absent(),
                Value<String?> sourceType = const Value.absent(),
                Value<String?> sourceId = const Value.absent(),
                Value<String?> staffId = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => PosOrdersCompanion.insert(
                id: id,
                orderNumber: orderNumber,
                customerId: customerId,
                customerName: customerName,
                subtotal: subtotal,
                discount: discount,
                tax: tax,
                totalAmount: totalAmount,
                paymentMethod: paymentMethod,
                loyaltyPtsEarned: loyaltyPtsEarned,
                loyaltyPtsUsed: loyaltyPtsUsed,
                status: status,
                note: note,
                receiptPrinted: receiptPrinted,
                sourceType: sourceType,
                sourceId: sourceId,
                staffId: staffId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PosOrdersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({customerId = false, posOrderItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (posOrderItemsRefs) db.posOrderItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (customerId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.customerId,
                                    referencedTable: $$PosOrdersTableReferences
                                        ._customerIdTable(db),
                                    referencedColumn: $$PosOrdersTableReferences
                                        ._customerIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (posOrderItemsRefs)
                        await $_getPrefetchedData<
                          PosOrder,
                          $PosOrdersTable,
                          PosOrderItem
                        >(
                          currentTable: table,
                          referencedTable: $$PosOrdersTableReferences
                              ._posOrderItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PosOrdersTableReferences(
                                db,
                                table,
                                p0,
                              ).posOrderItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.orderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PosOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PosOrdersTable,
      PosOrder,
      $$PosOrdersTableFilterComposer,
      $$PosOrdersTableOrderingComposer,
      $$PosOrdersTableAnnotationComposer,
      $$PosOrdersTableCreateCompanionBuilder,
      $$PosOrdersTableUpdateCompanionBuilder,
      (PosOrder, $$PosOrdersTableReferences),
      PosOrder,
      PrefetchHooks Function({bool customerId, bool posOrderItemsRefs})
    >;
typedef $$PosOrderItemsTableCreateCompanionBuilder =
    PosOrderItemsCompanion Function({
      required String id,
      required String orderId,
      required String productId,
      required String productName,
      required double quantity,
      required double unitPrice,
      required double costPrice,
      required double subtotal,
      Value<int> rowid,
    });
typedef $$PosOrderItemsTableUpdateCompanionBuilder =
    PosOrderItemsCompanion Function({
      Value<String> id,
      Value<String> orderId,
      Value<String> productId,
      Value<String> productName,
      Value<double> quantity,
      Value<double> unitPrice,
      Value<double> costPrice,
      Value<double> subtotal,
      Value<int> rowid,
    });

final class $$PosOrderItemsTableReferences
    extends BaseReferences<_$AppDatabase, $PosOrderItemsTable, PosOrderItem> {
  $$PosOrderItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PosOrdersTable _orderIdTable(_$AppDatabase db) =>
      db.posOrders.createAlias(
        $_aliasNameGenerator(db.posOrderItems.orderId, db.posOrders.id),
      );

  $$PosOrdersTableProcessedTableManager get orderId {
    final $_column = $_itemColumn<String>('order_id')!;

    final manager = $$PosOrdersTableTableManager(
      $_db,
      $_db.posOrders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_orderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PosOrderItemsTableFilterComposer
    extends Composer<_$AppDatabase, $PosOrderItemsTable> {
  $$PosOrderItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  $$PosOrdersTableFilterComposer get orderId {
    final $$PosOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.posOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PosOrdersTableFilterComposer(
            $db: $db,
            $table: $db.posOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PosOrderItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $PosOrderItemsTable> {
  $$PosOrderItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get costPrice => $composableBuilder(
    column: $table.costPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  $$PosOrdersTableOrderingComposer get orderId {
    final $$PosOrdersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.posOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PosOrdersTableOrderingComposer(
            $db: $db,
            $table: $db.posOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PosOrderItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PosOrderItemsTable> {
  $$PosOrderItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<double> get costPrice =>
      $composableBuilder(column: $table.costPrice, builder: (column) => column);

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  $$PosOrdersTableAnnotationComposer get orderId {
    final $$PosOrdersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.orderId,
      referencedTable: $db.posOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PosOrdersTableAnnotationComposer(
            $db: $db,
            $table: $db.posOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PosOrderItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PosOrderItemsTable,
          PosOrderItem,
          $$PosOrderItemsTableFilterComposer,
          $$PosOrderItemsTableOrderingComposer,
          $$PosOrderItemsTableAnnotationComposer,
          $$PosOrderItemsTableCreateCompanionBuilder,
          $$PosOrderItemsTableUpdateCompanionBuilder,
          (PosOrderItem, $$PosOrderItemsTableReferences),
          PosOrderItem,
          PrefetchHooks Function({bool orderId})
        > {
  $$PosOrderItemsTableTableManager(_$AppDatabase db, $PosOrderItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PosOrderItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PosOrderItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PosOrderItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> orderId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> unitPrice = const Value.absent(),
                Value<double> costPrice = const Value.absent(),
                Value<double> subtotal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PosOrderItemsCompanion(
                id: id,
                orderId: orderId,
                productId: productId,
                productName: productName,
                quantity: quantity,
                unitPrice: unitPrice,
                costPrice: costPrice,
                subtotal: subtotal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String orderId,
                required String productId,
                required String productName,
                required double quantity,
                required double unitPrice,
                required double costPrice,
                required double subtotal,
                Value<int> rowid = const Value.absent(),
              }) => PosOrderItemsCompanion.insert(
                id: id,
                orderId: orderId,
                productId: productId,
                productName: productName,
                quantity: quantity,
                unitPrice: unitPrice,
                costPrice: costPrice,
                subtotal: subtotal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PosOrderItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({orderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (orderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.orderId,
                                referencedTable: $$PosOrderItemsTableReferences
                                    ._orderIdTable(db),
                                referencedColumn: $$PosOrderItemsTableReferences
                                    ._orderIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PosOrderItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PosOrderItemsTable,
      PosOrderItem,
      $$PosOrderItemsTableFilterComposer,
      $$PosOrderItemsTableOrderingComposer,
      $$PosOrderItemsTableAnnotationComposer,
      $$PosOrderItemsTableCreateCompanionBuilder,
      $$PosOrderItemsTableUpdateCompanionBuilder,
      (PosOrderItem, $$PosOrderItemsTableReferences),
      PosOrderItem,
      PrefetchHooks Function({bool orderId})
    >;
typedef $$KhoStockMovementsTableCreateCompanionBuilder =
    KhoStockMovementsCompanion Function({
      required String id,
      required String productId,
      required double delta,
      required String reason,
      Value<String?> referenceId,
      Value<String?> eventId,
      Value<String?> note,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$KhoStockMovementsTableUpdateCompanionBuilder =
    KhoStockMovementsCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<double> delta,
      Value<String> reason,
      Value<String?> referenceId,
      Value<String?> eventId,
      Value<String?> note,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$KhoStockMovementsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $KhoStockMovementsTable,
          KhoStockMovement
        > {
  $$KhoStockMovementsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CoreProductsTable _productIdTable(_$AppDatabase db) =>
      db.coreProducts.createAlias(
        $_aliasNameGenerator(
          db.khoStockMovements.productId,
          db.coreProducts.id,
        ),
      );

  $$CoreProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$CoreProductsTableTableManager(
      $_db,
      $_db.coreProducts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$KhoStockMovementsTableFilterComposer
    extends Composer<_$AppDatabase, $KhoStockMovementsTable> {
  $$KhoStockMovementsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CoreProductsTableFilterComposer get productId {
    final $$CoreProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableFilterComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoStockMovementsTableOrderingComposer
    extends Composer<_$AppDatabase, $KhoStockMovementsTable> {
  $$KhoStockMovementsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get delta => $composableBuilder(
    column: $table.delta,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoreProductsTableOrderingComposer get productId {
    final $$CoreProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableOrderingComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoStockMovementsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KhoStockMovementsTable> {
  $$KhoStockMovementsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get delta =>
      $composableBuilder(column: $table.delta, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CoreProductsTableAnnotationComposer get productId {
    final $$CoreProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoStockMovementsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KhoStockMovementsTable,
          KhoStockMovement,
          $$KhoStockMovementsTableFilterComposer,
          $$KhoStockMovementsTableOrderingComposer,
          $$KhoStockMovementsTableAnnotationComposer,
          $$KhoStockMovementsTableCreateCompanionBuilder,
          $$KhoStockMovementsTableUpdateCompanionBuilder,
          (KhoStockMovement, $$KhoStockMovementsTableReferences),
          KhoStockMovement,
          PrefetchHooks Function({bool productId})
        > {
  $$KhoStockMovementsTableTableManager(
    _$AppDatabase db,
    $KhoStockMovementsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KhoStockMovementsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KhoStockMovementsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KhoStockMovementsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<double> delta = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoStockMovementsCompanion(
                id: id,
                productId: productId,
                delta: delta,
                reason: reason,
                referenceId: referenceId,
                eventId: eventId,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                required double delta,
                required String reason,
                Value<String?> referenceId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => KhoStockMovementsCompanion.insert(
                id: id,
                productId: productId,
                delta: delta,
                reason: reason,
                referenceId: referenceId,
                eventId: eventId,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KhoStockMovementsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable:
                                    $$KhoStockMovementsTableReferences
                                        ._productIdTable(db),
                                referencedColumn:
                                    $$KhoStockMovementsTableReferences
                                        ._productIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$KhoStockMovementsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KhoStockMovementsTable,
      KhoStockMovement,
      $$KhoStockMovementsTableFilterComposer,
      $$KhoStockMovementsTableOrderingComposer,
      $$KhoStockMovementsTableAnnotationComposer,
      $$KhoStockMovementsTableCreateCompanionBuilder,
      $$KhoStockMovementsTableUpdateCompanionBuilder,
      (KhoStockMovement, $$KhoStockMovementsTableReferences),
      KhoStockMovement,
      PrefetchHooks Function({bool productId})
    >;
typedef $$KhoRecipesTableCreateCompanionBuilder =
    KhoRecipesCompanion Function({
      required String id,
      required String productId,
      Value<bool> isActive,
      Value<String?> note,
      Value<int> rowid,
    });
typedef $$KhoRecipesTableUpdateCompanionBuilder =
    KhoRecipesCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<bool> isActive,
      Value<String?> note,
      Value<int> rowid,
    });

final class $$KhoRecipesTableReferences
    extends BaseReferences<_$AppDatabase, $KhoRecipesTable, KhoRecipe> {
  $$KhoRecipesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $CoreProductsTable _productIdTable(_$AppDatabase db) =>
      db.coreProducts.createAlias(
        $_aliasNameGenerator(db.khoRecipes.productId, db.coreProducts.id),
      );

  $$CoreProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$CoreProductsTableTableManager(
      $_db,
      $_db.coreProducts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$KhoRecipeItemsTable, List<KhoRecipeItem>>
  _khoRecipeItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.khoRecipeItems,
    aliasName: $_aliasNameGenerator(
      db.khoRecipes.id,
      db.khoRecipeItems.recipeId,
    ),
  );

  $$KhoRecipeItemsTableProcessedTableManager get khoRecipeItemsRefs {
    final manager = $$KhoRecipeItemsTableTableManager(
      $_db,
      $_db.khoRecipeItems,
    ).filter((f) => f.recipeId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_khoRecipeItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KhoRecipesTableFilterComposer
    extends Composer<_$AppDatabase, $KhoRecipesTable> {
  $$KhoRecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$CoreProductsTableFilterComposer get productId {
    final $$CoreProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableFilterComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> khoRecipeItemsRefs(
    Expression<bool> Function($$KhoRecipeItemsTableFilterComposer f) f,
  ) {
    final $$KhoRecipeItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoRecipeItems,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipeItemsTableFilterComposer(
            $db: $db,
            $table: $db.khoRecipeItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KhoRecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $KhoRecipesTable> {
  $$KhoRecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoreProductsTableOrderingComposer get productId {
    final $$CoreProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableOrderingComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoRecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $KhoRecipesTable> {
  $$KhoRecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$CoreProductsTableAnnotationComposer get productId {
    final $$CoreProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> khoRecipeItemsRefs<T extends Object>(
    Expression<T> Function($$KhoRecipeItemsTableAnnotationComposer a) f,
  ) {
    final $$KhoRecipeItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoRecipeItems,
      getReferencedColumn: (t) => t.recipeId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipeItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.khoRecipeItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KhoRecipesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KhoRecipesTable,
          KhoRecipe,
          $$KhoRecipesTableFilterComposer,
          $$KhoRecipesTableOrderingComposer,
          $$KhoRecipesTableAnnotationComposer,
          $$KhoRecipesTableCreateCompanionBuilder,
          $$KhoRecipesTableUpdateCompanionBuilder,
          (KhoRecipe, $$KhoRecipesTableReferences),
          KhoRecipe,
          PrefetchHooks Function({bool productId, bool khoRecipeItemsRefs})
        > {
  $$KhoRecipesTableTableManager(_$AppDatabase db, $KhoRecipesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KhoRecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KhoRecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KhoRecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoRecipesCompanion(
                id: id,
                productId: productId,
                isActive: isActive,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                Value<bool> isActive = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoRecipesCompanion.insert(
                id: id,
                productId: productId,
                isActive: isActive,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KhoRecipesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({productId = false, khoRecipeItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (khoRecipeItemsRefs) db.khoRecipeItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (productId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.productId,
                                    referencedTable: $$KhoRecipesTableReferences
                                        ._productIdTable(db),
                                    referencedColumn:
                                        $$KhoRecipesTableReferences
                                            ._productIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (khoRecipeItemsRefs)
                        await $_getPrefetchedData<
                          KhoRecipe,
                          $KhoRecipesTable,
                          KhoRecipeItem
                        >(
                          currentTable: table,
                          referencedTable: $$KhoRecipesTableReferences
                              ._khoRecipeItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$KhoRecipesTableReferences(
                                db,
                                table,
                                p0,
                              ).khoRecipeItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.recipeId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$KhoRecipesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KhoRecipesTable,
      KhoRecipe,
      $$KhoRecipesTableFilterComposer,
      $$KhoRecipesTableOrderingComposer,
      $$KhoRecipesTableAnnotationComposer,
      $$KhoRecipesTableCreateCompanionBuilder,
      $$KhoRecipesTableUpdateCompanionBuilder,
      (KhoRecipe, $$KhoRecipesTableReferences),
      KhoRecipe,
      PrefetchHooks Function({bool productId, bool khoRecipeItemsRefs})
    >;
typedef $$KhoRecipeItemsTableCreateCompanionBuilder =
    KhoRecipeItemsCompanion Function({
      required String id,
      required String recipeId,
      required String ingredientId,
      required double quantity,
      required String unit,
      Value<int> rowid,
    });
typedef $$KhoRecipeItemsTableUpdateCompanionBuilder =
    KhoRecipeItemsCompanion Function({
      Value<String> id,
      Value<String> recipeId,
      Value<String> ingredientId,
      Value<double> quantity,
      Value<String> unit,
      Value<int> rowid,
    });

final class $$KhoRecipeItemsTableReferences
    extends BaseReferences<_$AppDatabase, $KhoRecipeItemsTable, KhoRecipeItem> {
  $$KhoRecipeItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $KhoRecipesTable _recipeIdTable(_$AppDatabase db) =>
      db.khoRecipes.createAlias(
        $_aliasNameGenerator(db.khoRecipeItems.recipeId, db.khoRecipes.id),
      );

  $$KhoRecipesTableProcessedTableManager get recipeId {
    final $_column = $_itemColumn<String>('recipe_id')!;

    final manager = $$KhoRecipesTableTableManager(
      $_db,
      $_db.khoRecipes,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_recipeIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $CoreProductsTable _ingredientIdTable(_$AppDatabase db) =>
      db.coreProducts.createAlias(
        $_aliasNameGenerator(
          db.khoRecipeItems.ingredientId,
          db.coreProducts.id,
        ),
      );

  $$CoreProductsTableProcessedTableManager get ingredientId {
    final $_column = $_itemColumn<String>('ingredient_id')!;

    final manager = $$CoreProductsTableTableManager(
      $_db,
      $_db.coreProducts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ingredientIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$KhoRecipeItemsTableFilterComposer
    extends Composer<_$AppDatabase, $KhoRecipeItemsTable> {
  $$KhoRecipeItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnFilters(column),
  );

  $$KhoRecipesTableFilterComposer get recipeId {
    final $$KhoRecipesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.khoRecipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipesTableFilterComposer(
            $db: $db,
            $table: $db.khoRecipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CoreProductsTableFilterComposer get ingredientId {
    final $$CoreProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableFilterComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoRecipeItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $KhoRecipeItemsTable> {
  $$KhoRecipeItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get unit => $composableBuilder(
    column: $table.unit,
    builder: (column) => ColumnOrderings(column),
  );

  $$KhoRecipesTableOrderingComposer get recipeId {
    final $$KhoRecipesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.khoRecipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipesTableOrderingComposer(
            $db: $db,
            $table: $db.khoRecipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CoreProductsTableOrderingComposer get ingredientId {
    final $$CoreProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableOrderingComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoRecipeItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KhoRecipeItemsTable> {
  $$KhoRecipeItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get unit =>
      $composableBuilder(column: $table.unit, builder: (column) => column);

  $$KhoRecipesTableAnnotationComposer get recipeId {
    final $$KhoRecipesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.recipeId,
      referencedTable: $db.khoRecipes,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoRecipesTableAnnotationComposer(
            $db: $db,
            $table: $db.khoRecipes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$CoreProductsTableAnnotationComposer get ingredientId {
    final $$CoreProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ingredientId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoRecipeItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KhoRecipeItemsTable,
          KhoRecipeItem,
          $$KhoRecipeItemsTableFilterComposer,
          $$KhoRecipeItemsTableOrderingComposer,
          $$KhoRecipeItemsTableAnnotationComposer,
          $$KhoRecipeItemsTableCreateCompanionBuilder,
          $$KhoRecipeItemsTableUpdateCompanionBuilder,
          (KhoRecipeItem, $$KhoRecipeItemsTableReferences),
          KhoRecipeItem,
          PrefetchHooks Function({bool recipeId, bool ingredientId})
        > {
  $$KhoRecipeItemsTableTableManager(
    _$AppDatabase db,
    $KhoRecipeItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KhoRecipeItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KhoRecipeItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KhoRecipeItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> recipeId = const Value.absent(),
                Value<String> ingredientId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> unit = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoRecipeItemsCompanion(
                id: id,
                recipeId: recipeId,
                ingredientId: ingredientId,
                quantity: quantity,
                unit: unit,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String recipeId,
                required String ingredientId,
                required double quantity,
                required String unit,
                Value<int> rowid = const Value.absent(),
              }) => KhoRecipeItemsCompanion.insert(
                id: id,
                recipeId: recipeId,
                ingredientId: ingredientId,
                quantity: quantity,
                unit: unit,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KhoRecipeItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({recipeId = false, ingredientId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (recipeId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.recipeId,
                                referencedTable: $$KhoRecipeItemsTableReferences
                                    ._recipeIdTable(db),
                                referencedColumn:
                                    $$KhoRecipeItemsTableReferences
                                        ._recipeIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (ingredientId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ingredientId,
                                referencedTable: $$KhoRecipeItemsTableReferences
                                    ._ingredientIdTable(db),
                                referencedColumn:
                                    $$KhoRecipeItemsTableReferences
                                        ._ingredientIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$KhoRecipeItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KhoRecipeItemsTable,
      KhoRecipeItem,
      $$KhoRecipeItemsTableFilterComposer,
      $$KhoRecipeItemsTableOrderingComposer,
      $$KhoRecipeItemsTableAnnotationComposer,
      $$KhoRecipeItemsTableCreateCompanionBuilder,
      $$KhoRecipeItemsTableUpdateCompanionBuilder,
      (KhoRecipeItem, $$KhoRecipeItemsTableReferences),
      KhoRecipeItem,
      PrefetchHooks Function({bool recipeId, bool ingredientId})
    >;
typedef $$KhoSuppliersTableCreateCompanionBuilder =
    KhoSuppliersCompanion Function({
      required String id,
      required String name,
      Value<String?> phone,
      Value<String?> address,
      Value<String?> note,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$KhoSuppliersTableUpdateCompanionBuilder =
    KhoSuppliersCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> phone,
      Value<String?> address,
      Value<String?> note,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

final class $$KhoSuppliersTableReferences
    extends BaseReferences<_$AppDatabase, $KhoSuppliersTable, KhoSupplier> {
  $$KhoSuppliersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$KhoPurchaseOrdersTable, List<KhoPurchaseOrder>>
  _khoPurchaseOrdersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.khoPurchaseOrders,
        aliasName: $_aliasNameGenerator(
          db.khoSuppliers.id,
          db.khoPurchaseOrders.supplierId,
        ),
      );

  $$KhoPurchaseOrdersTableProcessedTableManager get khoPurchaseOrdersRefs {
    final manager = $$KhoPurchaseOrdersTableTableManager(
      $_db,
      $_db.khoPurchaseOrders,
    ).filter((f) => f.supplierId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _khoPurchaseOrdersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KhoSuppliersTableFilterComposer
    extends Composer<_$AppDatabase, $KhoSuppliersTable> {
  $$KhoSuppliersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> khoPurchaseOrdersRefs(
    Expression<bool> Function($$KhoPurchaseOrdersTableFilterComposer f) f,
  ) {
    final $$KhoPurchaseOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoPurchaseOrders,
      getReferencedColumn: (t) => t.supplierId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoPurchaseOrdersTableFilterComposer(
            $db: $db,
            $table: $db.khoPurchaseOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KhoSuppliersTableOrderingComposer
    extends Composer<_$AppDatabase, $KhoSuppliersTable> {
  $$KhoSuppliersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get address => $composableBuilder(
    column: $table.address,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KhoSuppliersTableAnnotationComposer
    extends Composer<_$AppDatabase, $KhoSuppliersTable> {
  $$KhoSuppliersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get address =>
      $composableBuilder(column: $table.address, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  Expression<T> khoPurchaseOrdersRefs<T extends Object>(
    Expression<T> Function($$KhoPurchaseOrdersTableAnnotationComposer a) f,
  ) {
    final $$KhoPurchaseOrdersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.khoPurchaseOrders,
          getReferencedColumn: (t) => t.supplierId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$KhoPurchaseOrdersTableAnnotationComposer(
                $db: $db,
                $table: $db.khoPurchaseOrders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$KhoSuppliersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KhoSuppliersTable,
          KhoSupplier,
          $$KhoSuppliersTableFilterComposer,
          $$KhoSuppliersTableOrderingComposer,
          $$KhoSuppliersTableAnnotationComposer,
          $$KhoSuppliersTableCreateCompanionBuilder,
          $$KhoSuppliersTableUpdateCompanionBuilder,
          (KhoSupplier, $$KhoSuppliersTableReferences),
          KhoSupplier,
          PrefetchHooks Function({bool khoPurchaseOrdersRefs})
        > {
  $$KhoSuppliersTableTableManager(_$AppDatabase db, $KhoSuppliersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KhoSuppliersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KhoSuppliersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KhoSuppliersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoSuppliersCompanion(
                id: id,
                name: name,
                phone: phone,
                address: address,
                note: note,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> phone = const Value.absent(),
                Value<String?> address = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoSuppliersCompanion.insert(
                id: id,
                name: name,
                phone: phone,
                address: address,
                note: note,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KhoSuppliersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({khoPurchaseOrdersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (khoPurchaseOrdersRefs) db.khoPurchaseOrders,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (khoPurchaseOrdersRefs)
                    await $_getPrefetchedData<
                      KhoSupplier,
                      $KhoSuppliersTable,
                      KhoPurchaseOrder
                    >(
                      currentTable: table,
                      referencedTable: $$KhoSuppliersTableReferences
                          ._khoPurchaseOrdersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$KhoSuppliersTableReferences(
                            db,
                            table,
                            p0,
                          ).khoPurchaseOrdersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.supplierId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$KhoSuppliersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KhoSuppliersTable,
      KhoSupplier,
      $$KhoSuppliersTableFilterComposer,
      $$KhoSuppliersTableOrderingComposer,
      $$KhoSuppliersTableAnnotationComposer,
      $$KhoSuppliersTableCreateCompanionBuilder,
      $$KhoSuppliersTableUpdateCompanionBuilder,
      (KhoSupplier, $$KhoSuppliersTableReferences),
      KhoSupplier,
      PrefetchHooks Function({bool khoPurchaseOrdersRefs})
    >;
typedef $$KhoPurchaseOrdersTableCreateCompanionBuilder =
    KhoPurchaseOrdersCompanion Function({
      required String id,
      Value<String?> supplierId,
      required double totalCost,
      Value<String> status,
      Value<String?> note,
      Value<int?> createdAt,
      Value<int> rowid,
    });
typedef $$KhoPurchaseOrdersTableUpdateCompanionBuilder =
    KhoPurchaseOrdersCompanion Function({
      Value<String> id,
      Value<String?> supplierId,
      Value<double> totalCost,
      Value<String> status,
      Value<String?> note,
      Value<int?> createdAt,
      Value<int> rowid,
    });

final class $$KhoPurchaseOrdersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $KhoPurchaseOrdersTable,
          KhoPurchaseOrder
        > {
  $$KhoPurchaseOrdersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $KhoSuppliersTable _supplierIdTable(_$AppDatabase db) =>
      db.khoSuppliers.createAlias(
        $_aliasNameGenerator(
          db.khoPurchaseOrders.supplierId,
          db.khoSuppliers.id,
        ),
      );

  $$KhoSuppliersTableProcessedTableManager? get supplierId {
    final $_column = $_itemColumn<String>('supplier_id');
    if ($_column == null) return null;
    final manager = $$KhoSuppliersTableTableManager(
      $_db,
      $_db.khoSuppliers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_supplierIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$KhoPurchaseItemsTable, List<KhoPurchaseItem>>
  _khoPurchaseItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.khoPurchaseItems,
    aliasName: $_aliasNameGenerator(
      db.khoPurchaseOrders.id,
      db.khoPurchaseItems.purchaseId,
    ),
  );

  $$KhoPurchaseItemsTableProcessedTableManager get khoPurchaseItemsRefs {
    final manager = $$KhoPurchaseItemsTableTableManager(
      $_db,
      $_db.khoPurchaseItems,
    ).filter((f) => f.purchaseId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _khoPurchaseItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KhoPurchaseOrdersTableFilterComposer
    extends Composer<_$AppDatabase, $KhoPurchaseOrdersTable> {
  $$KhoPurchaseOrdersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$KhoSuppliersTableFilterComposer get supplierId {
    final $$KhoSuppliersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.khoSuppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoSuppliersTableFilterComposer(
            $db: $db,
            $table: $db.khoSuppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> khoPurchaseItemsRefs(
    Expression<bool> Function($$KhoPurchaseItemsTableFilterComposer f) f,
  ) {
    final $$KhoPurchaseItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoPurchaseItems,
      getReferencedColumn: (t) => t.purchaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoPurchaseItemsTableFilterComposer(
            $db: $db,
            $table: $db.khoPurchaseItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KhoPurchaseOrdersTableOrderingComposer
    extends Composer<_$AppDatabase, $KhoPurchaseOrdersTable> {
  $$KhoPurchaseOrdersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalCost => $composableBuilder(
    column: $table.totalCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$KhoSuppliersTableOrderingComposer get supplierId {
    final $$KhoSuppliersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.khoSuppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoSuppliersTableOrderingComposer(
            $db: $db,
            $table: $db.khoSuppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoPurchaseOrdersTableAnnotationComposer
    extends Composer<_$AppDatabase, $KhoPurchaseOrdersTable> {
  $$KhoPurchaseOrdersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<double> get totalCost =>
      $composableBuilder(column: $table.totalCost, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$KhoSuppliersTableAnnotationComposer get supplierId {
    final $$KhoSuppliersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.supplierId,
      referencedTable: $db.khoSuppliers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoSuppliersTableAnnotationComposer(
            $db: $db,
            $table: $db.khoSuppliers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> khoPurchaseItemsRefs<T extends Object>(
    Expression<T> Function($$KhoPurchaseItemsTableAnnotationComposer a) f,
  ) {
    final $$KhoPurchaseItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.khoPurchaseItems,
      getReferencedColumn: (t) => t.purchaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoPurchaseItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.khoPurchaseItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KhoPurchaseOrdersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KhoPurchaseOrdersTable,
          KhoPurchaseOrder,
          $$KhoPurchaseOrdersTableFilterComposer,
          $$KhoPurchaseOrdersTableOrderingComposer,
          $$KhoPurchaseOrdersTableAnnotationComposer,
          $$KhoPurchaseOrdersTableCreateCompanionBuilder,
          $$KhoPurchaseOrdersTableUpdateCompanionBuilder,
          (KhoPurchaseOrder, $$KhoPurchaseOrdersTableReferences),
          KhoPurchaseOrder,
          PrefetchHooks Function({bool supplierId, bool khoPurchaseItemsRefs})
        > {
  $$KhoPurchaseOrdersTableTableManager(
    _$AppDatabase db,
    $KhoPurchaseOrdersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KhoPurchaseOrdersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KhoPurchaseOrdersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KhoPurchaseOrdersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> supplierId = const Value.absent(),
                Value<double> totalCost = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoPurchaseOrdersCompanion(
                id: id,
                supplierId: supplierId,
                totalCost: totalCost,
                status: status,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> supplierId = const Value.absent(),
                required double totalCost,
                Value<String> status = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoPurchaseOrdersCompanion.insert(
                id: id,
                supplierId: supplierId,
                totalCost: totalCost,
                status: status,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KhoPurchaseOrdersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({supplierId = false, khoPurchaseItemsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (khoPurchaseItemsRefs) db.khoPurchaseItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (supplierId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.supplierId,
                                    referencedTable:
                                        $$KhoPurchaseOrdersTableReferences
                                            ._supplierIdTable(db),
                                    referencedColumn:
                                        $$KhoPurchaseOrdersTableReferences
                                            ._supplierIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (khoPurchaseItemsRefs)
                        await $_getPrefetchedData<
                          KhoPurchaseOrder,
                          $KhoPurchaseOrdersTable,
                          KhoPurchaseItem
                        >(
                          currentTable: table,
                          referencedTable: $$KhoPurchaseOrdersTableReferences
                              ._khoPurchaseItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$KhoPurchaseOrdersTableReferences(
                                db,
                                table,
                                p0,
                              ).khoPurchaseItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.purchaseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$KhoPurchaseOrdersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KhoPurchaseOrdersTable,
      KhoPurchaseOrder,
      $$KhoPurchaseOrdersTableFilterComposer,
      $$KhoPurchaseOrdersTableOrderingComposer,
      $$KhoPurchaseOrdersTableAnnotationComposer,
      $$KhoPurchaseOrdersTableCreateCompanionBuilder,
      $$KhoPurchaseOrdersTableUpdateCompanionBuilder,
      (KhoPurchaseOrder, $$KhoPurchaseOrdersTableReferences),
      KhoPurchaseOrder,
      PrefetchHooks Function({bool supplierId, bool khoPurchaseItemsRefs})
    >;
typedef $$KhoPurchaseItemsTableCreateCompanionBuilder =
    KhoPurchaseItemsCompanion Function({
      required String id,
      required String purchaseId,
      Value<String?> productId,
      Value<String?> productName,
      required double quantity,
      required double unitCost,
      Value<int> rowid,
    });
typedef $$KhoPurchaseItemsTableUpdateCompanionBuilder =
    KhoPurchaseItemsCompanion Function({
      Value<String> id,
      Value<String> purchaseId,
      Value<String?> productId,
      Value<String?> productName,
      Value<double> quantity,
      Value<double> unitCost,
      Value<int> rowid,
    });

final class $$KhoPurchaseItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $KhoPurchaseItemsTable, KhoPurchaseItem> {
  $$KhoPurchaseItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $KhoPurchaseOrdersTable _purchaseIdTable(_$AppDatabase db) =>
      db.khoPurchaseOrders.createAlias(
        $_aliasNameGenerator(
          db.khoPurchaseItems.purchaseId,
          db.khoPurchaseOrders.id,
        ),
      );

  $$KhoPurchaseOrdersTableProcessedTableManager get purchaseId {
    final $_column = $_itemColumn<String>('purchase_id')!;

    final manager = $$KhoPurchaseOrdersTableTableManager(
      $_db,
      $_db.khoPurchaseOrders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_purchaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$KhoPurchaseItemsTableFilterComposer
    extends Composer<_$AppDatabase, $KhoPurchaseItemsTable> {
  $$KhoPurchaseItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnFilters(column),
  );

  $$KhoPurchaseOrdersTableFilterComposer get purchaseId {
    final $$KhoPurchaseOrdersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.purchaseId,
      referencedTable: $db.khoPurchaseOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoPurchaseOrdersTableFilterComposer(
            $db: $db,
            $table: $db.khoPurchaseOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoPurchaseItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $KhoPurchaseItemsTable> {
  $$KhoPurchaseItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitCost => $composableBuilder(
    column: $table.unitCost,
    builder: (column) => ColumnOrderings(column),
  );

  $$KhoPurchaseOrdersTableOrderingComposer get purchaseId {
    final $$KhoPurchaseOrdersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.purchaseId,
      referencedTable: $db.khoPurchaseOrders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KhoPurchaseOrdersTableOrderingComposer(
            $db: $db,
            $table: $db.khoPurchaseOrders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KhoPurchaseItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KhoPurchaseItemsTable> {
  $$KhoPurchaseItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get unitCost =>
      $composableBuilder(column: $table.unitCost, builder: (column) => column);

  $$KhoPurchaseOrdersTableAnnotationComposer get purchaseId {
    final $$KhoPurchaseOrdersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.purchaseId,
          referencedTable: $db.khoPurchaseOrders,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$KhoPurchaseOrdersTableAnnotationComposer(
                $db: $db,
                $table: $db.khoPurchaseOrders,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$KhoPurchaseItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KhoPurchaseItemsTable,
          KhoPurchaseItem,
          $$KhoPurchaseItemsTableFilterComposer,
          $$KhoPurchaseItemsTableOrderingComposer,
          $$KhoPurchaseItemsTableAnnotationComposer,
          $$KhoPurchaseItemsTableCreateCompanionBuilder,
          $$KhoPurchaseItemsTableUpdateCompanionBuilder,
          (KhoPurchaseItem, $$KhoPurchaseItemsTableReferences),
          KhoPurchaseItem,
          PrefetchHooks Function({bool purchaseId})
        > {
  $$KhoPurchaseItemsTableTableManager(
    _$AppDatabase db,
    $KhoPurchaseItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KhoPurchaseItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KhoPurchaseItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KhoPurchaseItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> purchaseId = const Value.absent(),
                Value<String?> productId = const Value.absent(),
                Value<String?> productName = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> unitCost = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KhoPurchaseItemsCompanion(
                id: id,
                purchaseId: purchaseId,
                productId: productId,
                productName: productName,
                quantity: quantity,
                unitCost: unitCost,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String purchaseId,
                Value<String?> productId = const Value.absent(),
                Value<String?> productName = const Value.absent(),
                required double quantity,
                required double unitCost,
                Value<int> rowid = const Value.absent(),
              }) => KhoPurchaseItemsCompanion.insert(
                id: id,
                purchaseId: purchaseId,
                productId: productId,
                productName: productName,
                quantity: quantity,
                unitCost: unitCost,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KhoPurchaseItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({purchaseId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (purchaseId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.purchaseId,
                                referencedTable:
                                    $$KhoPurchaseItemsTableReferences
                                        ._purchaseIdTable(db),
                                referencedColumn:
                                    $$KhoPurchaseItemsTableReferences
                                        ._purchaseIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$KhoPurchaseItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KhoPurchaseItemsTable,
      KhoPurchaseItem,
      $$KhoPurchaseItemsTableFilterComposer,
      $$KhoPurchaseItemsTableOrderingComposer,
      $$KhoPurchaseItemsTableAnnotationComposer,
      $$KhoPurchaseItemsTableCreateCompanionBuilder,
      $$KhoPurchaseItemsTableUpdateCompanionBuilder,
      (KhoPurchaseItem, $$KhoPurchaseItemsTableReferences),
      KhoPurchaseItem,
      PrefetchHooks Function({bool purchaseId})
    >;
typedef $$FinanceCategoriesTableCreateCompanionBuilder =
    FinanceCategoriesCompanion Function({
      required String id,
      required String name,
      required String type,
      Value<String?> icon,
      Value<String?> color,
      Value<bool> isSystem,
      Value<int> rowid,
    });
typedef $$FinanceCategoriesTableUpdateCompanionBuilder =
    FinanceCategoriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> type,
      Value<String?> icon,
      Value<String?> color,
      Value<bool> isSystem,
      Value<int> rowid,
    });

final class $$FinanceCategoriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $FinanceCategoriesTable,
          FinanceCategory
        > {
  $$FinanceCategoriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$FinanceRecordsTable, List<FinanceRecord>>
  _financeRecordsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.financeRecords,
    aliasName: $_aliasNameGenerator(
      db.financeCategories.id,
      db.financeRecords.categoryId,
    ),
  );

  $$FinanceRecordsTableProcessedTableManager get financeRecordsRefs {
    final manager = $$FinanceRecordsTableTableManager(
      $_db,
      $_db.financeRecords,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_financeRecordsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FinanceCategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $FinanceCategoriesTable> {
  $$FinanceCategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> financeRecordsRefs(
    Expression<bool> Function($$FinanceRecordsTableFilterComposer f) f,
  ) {
    final $$FinanceRecordsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.financeRecords,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinanceRecordsTableFilterComposer(
            $db: $db,
            $table: $db.financeRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FinanceCategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FinanceCategoriesTable> {
  $$FinanceCategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FinanceCategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinanceCategoriesTable> {
  $$FinanceCategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  Expression<T> financeRecordsRefs<T extends Object>(
    Expression<T> Function($$FinanceRecordsTableAnnotationComposer a) f,
  ) {
    final $$FinanceRecordsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.financeRecords,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinanceRecordsTableAnnotationComposer(
            $db: $db,
            $table: $db.financeRecords,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FinanceCategoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FinanceCategoriesTable,
          FinanceCategory,
          $$FinanceCategoriesTableFilterComposer,
          $$FinanceCategoriesTableOrderingComposer,
          $$FinanceCategoriesTableAnnotationComposer,
          $$FinanceCategoriesTableCreateCompanionBuilder,
          $$FinanceCategoriesTableUpdateCompanionBuilder,
          (FinanceCategory, $$FinanceCategoriesTableReferences),
          FinanceCategory,
          PrefetchHooks Function({bool financeRecordsRefs})
        > {
  $$FinanceCategoriesTableTableManager(
    _$AppDatabase db,
    $FinanceCategoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinanceCategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinanceCategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FinanceCategoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FinanceCategoriesCompanion(
                id: id,
                name: name,
                type: type,
                icon: icon,
                color: color,
                isSystem: isSystem,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String type,
                Value<String?> icon = const Value.absent(),
                Value<String?> color = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FinanceCategoriesCompanion.insert(
                id: id,
                name: name,
                type: type,
                icon: icon,
                color: color,
                isSystem: isSystem,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FinanceCategoriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({financeRecordsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (financeRecordsRefs) db.financeRecords,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (financeRecordsRefs)
                    await $_getPrefetchedData<
                      FinanceCategory,
                      $FinanceCategoriesTable,
                      FinanceRecord
                    >(
                      currentTable: table,
                      referencedTable: $$FinanceCategoriesTableReferences
                          ._financeRecordsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$FinanceCategoriesTableReferences(
                            db,
                            table,
                            p0,
                          ).financeRecordsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FinanceCategoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FinanceCategoriesTable,
      FinanceCategory,
      $$FinanceCategoriesTableFilterComposer,
      $$FinanceCategoriesTableOrderingComposer,
      $$FinanceCategoriesTableAnnotationComposer,
      $$FinanceCategoriesTableCreateCompanionBuilder,
      $$FinanceCategoriesTableUpdateCompanionBuilder,
      (FinanceCategory, $$FinanceCategoriesTableReferences),
      FinanceCategory,
      PrefetchHooks Function({bool financeRecordsRefs})
    >;
typedef $$FinanceRecordsTableCreateCompanionBuilder =
    FinanceRecordsCompanion Function({
      required String id,
      required String type,
      required double amount,
      Value<String?> categoryId,
      Value<String?> description,
      Value<String?> referenceId,
      Value<String?> eventId,
      Value<bool> isAuto,
      required int recordedAt,
      Value<int> rowid,
    });
typedef $$FinanceRecordsTableUpdateCompanionBuilder =
    FinanceRecordsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<double> amount,
      Value<String?> categoryId,
      Value<String?> description,
      Value<String?> referenceId,
      Value<String?> eventId,
      Value<bool> isAuto,
      Value<int> recordedAt,
      Value<int> rowid,
    });

final class $$FinanceRecordsTableReferences
    extends BaseReferences<_$AppDatabase, $FinanceRecordsTable, FinanceRecord> {
  $$FinanceRecordsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $FinanceCategoriesTable _categoryIdTable(_$AppDatabase db) =>
      db.financeCategories.createAlias(
        $_aliasNameGenerator(
          db.financeRecords.categoryId,
          db.financeCategories.id,
        ),
      );

  $$FinanceCategoriesTableProcessedTableManager? get categoryId {
    final $_column = $_itemColumn<String>('category_id');
    if ($_column == null) return null;
    final manager = $$FinanceCategoriesTableTableManager(
      $_db,
      $_db.financeCategories,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FinanceRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $FinanceRecordsTable> {
  $$FinanceRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isAuto => $composableBuilder(
    column: $table.isAuto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FinanceCategoriesTableFilterComposer get categoryId {
    final $$FinanceCategoriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.financeCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinanceCategoriesTableFilterComposer(
            $db: $db,
            $table: $db.financeCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinanceRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $FinanceRecordsTable> {
  $$FinanceRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get amount => $composableBuilder(
    column: $table.amount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get eventId => $composableBuilder(
    column: $table.eventId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isAuto => $composableBuilder(
    column: $table.isAuto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FinanceCategoriesTableOrderingComposer get categoryId {
    final $$FinanceCategoriesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.financeCategories,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FinanceCategoriesTableOrderingComposer(
            $db: $db,
            $table: $db.financeCategories,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FinanceRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FinanceRecordsTable> {
  $$FinanceRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get amount =>
      $composableBuilder(column: $table.amount, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get referenceId => $composableBuilder(
    column: $table.referenceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get eventId =>
      $composableBuilder(column: $table.eventId, builder: (column) => column);

  GeneratedColumn<bool> get isAuto =>
      $composableBuilder(column: $table.isAuto, builder: (column) => column);

  GeneratedColumn<int> get recordedAt => $composableBuilder(
    column: $table.recordedAt,
    builder: (column) => column,
  );

  $$FinanceCategoriesTableAnnotationComposer get categoryId {
    final $$FinanceCategoriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.categoryId,
          referencedTable: $db.financeCategories,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$FinanceCategoriesTableAnnotationComposer(
                $db: $db,
                $table: $db.financeCategories,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$FinanceRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FinanceRecordsTable,
          FinanceRecord,
          $$FinanceRecordsTableFilterComposer,
          $$FinanceRecordsTableOrderingComposer,
          $$FinanceRecordsTableAnnotationComposer,
          $$FinanceRecordsTableCreateCompanionBuilder,
          $$FinanceRecordsTableUpdateCompanionBuilder,
          (FinanceRecord, $$FinanceRecordsTableReferences),
          FinanceRecord,
          PrefetchHooks Function({bool categoryId})
        > {
  $$FinanceRecordsTableTableManager(
    _$AppDatabase db,
    $FinanceRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FinanceRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FinanceRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FinanceRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> amount = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<bool> isAuto = const Value.absent(),
                Value<int> recordedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FinanceRecordsCompanion(
                id: id,
                type: type,
                amount: amount,
                categoryId: categoryId,
                description: description,
                referenceId: referenceId,
                eventId: eventId,
                isAuto: isAuto,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required double amount,
                Value<String?> categoryId = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<String?> referenceId = const Value.absent(),
                Value<String?> eventId = const Value.absent(),
                Value<bool> isAuto = const Value.absent(),
                required int recordedAt,
                Value<int> rowid = const Value.absent(),
              }) => FinanceRecordsCompanion.insert(
                id: id,
                type: type,
                amount: amount,
                categoryId: categoryId,
                description: description,
                referenceId: referenceId,
                eventId: eventId,
                isAuto: isAuto,
                recordedAt: recordedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FinanceRecordsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable: $$FinanceRecordsTableReferences
                                    ._categoryIdTable(db),
                                referencedColumn:
                                    $$FinanceRecordsTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FinanceRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FinanceRecordsTable,
      FinanceRecord,
      $$FinanceRecordsTableFilterComposer,
      $$FinanceRecordsTableOrderingComposer,
      $$FinanceRecordsTableAnnotationComposer,
      $$FinanceRecordsTableCreateCompanionBuilder,
      $$FinanceRecordsTableUpdateCompanionBuilder,
      (FinanceRecord, $$FinanceRecordsTableReferences),
      FinanceRecord,
      PrefetchHooks Function({bool categoryId})
    >;
typedef $$LoyaltyTransactionsTableCreateCompanionBuilder =
    LoyaltyTransactionsCompanion Function({
      required String id,
      required String customerId,
      Value<String?> orderId,
      Value<double> ptsEarned,
      Value<double> ptsUsed,
      Value<String?> note,
      Value<int?> createdAt,
      Value<int> rowid,
    });
typedef $$LoyaltyTransactionsTableUpdateCompanionBuilder =
    LoyaltyTransactionsCompanion Function({
      Value<String> id,
      Value<String> customerId,
      Value<String?> orderId,
      Value<double> ptsEarned,
      Value<double> ptsUsed,
      Value<String?> note,
      Value<int?> createdAt,
      Value<int> rowid,
    });

final class $$LoyaltyTransactionsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $LoyaltyTransactionsTable,
          LoyaltyTransaction
        > {
  $$LoyaltyTransactionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CoreCustomersTable _customerIdTable(_$AppDatabase db) =>
      db.coreCustomers.createAlias(
        $_aliasNameGenerator(
          db.loyaltyTransactions.customerId,
          db.coreCustomers.id,
        ),
      );

  $$CoreCustomersTableProcessedTableManager get customerId {
    final $_column = $_itemColumn<String>('customer_id')!;

    final manager = $$CoreCustomersTableTableManager(
      $_db,
      $_db.coreCustomers,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_customerIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$LoyaltyTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $LoyaltyTransactionsTable> {
  $$LoyaltyTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ptsEarned => $composableBuilder(
    column: $table.ptsEarned,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ptsUsed => $composableBuilder(
    column: $table.ptsUsed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CoreCustomersTableFilterComposer get customerId {
    final $$CoreCustomersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.coreCustomers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreCustomersTableFilterComposer(
            $db: $db,
            $table: $db.coreCustomers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LoyaltyTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $LoyaltyTransactionsTable> {
  $$LoyaltyTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get orderId => $composableBuilder(
    column: $table.orderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ptsEarned => $composableBuilder(
    column: $table.ptsEarned,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ptsUsed => $composableBuilder(
    column: $table.ptsUsed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoreCustomersTableOrderingComposer get customerId {
    final $$CoreCustomersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.coreCustomers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreCustomersTableOrderingComposer(
            $db: $db,
            $table: $db.coreCustomers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LoyaltyTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LoyaltyTransactionsTable> {
  $$LoyaltyTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get orderId =>
      $composableBuilder(column: $table.orderId, builder: (column) => column);

  GeneratedColumn<double> get ptsEarned =>
      $composableBuilder(column: $table.ptsEarned, builder: (column) => column);

  GeneratedColumn<double> get ptsUsed =>
      $composableBuilder(column: $table.ptsUsed, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CoreCustomersTableAnnotationComposer get customerId {
    final $$CoreCustomersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.customerId,
      referencedTable: $db.coreCustomers,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreCustomersTableAnnotationComposer(
            $db: $db,
            $table: $db.coreCustomers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$LoyaltyTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LoyaltyTransactionsTable,
          LoyaltyTransaction,
          $$LoyaltyTransactionsTableFilterComposer,
          $$LoyaltyTransactionsTableOrderingComposer,
          $$LoyaltyTransactionsTableAnnotationComposer,
          $$LoyaltyTransactionsTableCreateCompanionBuilder,
          $$LoyaltyTransactionsTableUpdateCompanionBuilder,
          (LoyaltyTransaction, $$LoyaltyTransactionsTableReferences),
          LoyaltyTransaction,
          PrefetchHooks Function({bool customerId})
        > {
  $$LoyaltyTransactionsTableTableManager(
    _$AppDatabase db,
    $LoyaltyTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LoyaltyTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LoyaltyTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LoyaltyTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> customerId = const Value.absent(),
                Value<String?> orderId = const Value.absent(),
                Value<double> ptsEarned = const Value.absent(),
                Value<double> ptsUsed = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LoyaltyTransactionsCompanion(
                id: id,
                customerId: customerId,
                orderId: orderId,
                ptsEarned: ptsEarned,
                ptsUsed: ptsUsed,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String customerId,
                Value<String?> orderId = const Value.absent(),
                Value<double> ptsEarned = const Value.absent(),
                Value<double> ptsUsed = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int?> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LoyaltyTransactionsCompanion.insert(
                id: id,
                customerId: customerId,
                orderId: orderId,
                ptsEarned: ptsEarned,
                ptsUsed: ptsUsed,
                note: note,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$LoyaltyTransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({customerId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (customerId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.customerId,
                                referencedTable:
                                    $$LoyaltyTransactionsTableReferences
                                        ._customerIdTable(db),
                                referencedColumn:
                                    $$LoyaltyTransactionsTableReferences
                                        ._customerIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$LoyaltyTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LoyaltyTransactionsTable,
      LoyaltyTransaction,
      $$LoyaltyTransactionsTableFilterComposer,
      $$LoyaltyTransactionsTableOrderingComposer,
      $$LoyaltyTransactionsTableAnnotationComposer,
      $$LoyaltyTransactionsTableCreateCompanionBuilder,
      $$LoyaltyTransactionsTableUpdateCompanionBuilder,
      (LoyaltyTransaction, $$LoyaltyTransactionsTableReferences),
      LoyaltyTransaction,
      PrefetchHooks Function({bool customerId})
    >;
typedef $$LoyaltyRewardsTableCreateCompanionBuilder =
    LoyaltyRewardsCompanion Function({
      required String id,
      required String name,
      required double ptsRequired,
      Value<double?> discountAmount,
      Value<bool> isActive,
      Value<int> rowid,
    });
typedef $$LoyaltyRewardsTableUpdateCompanionBuilder =
    LoyaltyRewardsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<double> ptsRequired,
      Value<double?> discountAmount,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$LoyaltyRewardsTableFilterComposer
    extends Composer<_$AppDatabase, $LoyaltyRewardsTable> {
  $$LoyaltyRewardsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ptsRequired => $composableBuilder(
    column: $table.ptsRequired,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LoyaltyRewardsTableOrderingComposer
    extends Composer<_$AppDatabase, $LoyaltyRewardsTable> {
  $$LoyaltyRewardsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ptsRequired => $composableBuilder(
    column: $table.ptsRequired,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LoyaltyRewardsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LoyaltyRewardsTable> {
  $$LoyaltyRewardsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get ptsRequired => $composableBuilder(
    column: $table.ptsRequired,
    builder: (column) => column,
  );

  GeneratedColumn<double> get discountAmount => $composableBuilder(
    column: $table.discountAmount,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$LoyaltyRewardsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LoyaltyRewardsTable,
          LoyaltyReward,
          $$LoyaltyRewardsTableFilterComposer,
          $$LoyaltyRewardsTableOrderingComposer,
          $$LoyaltyRewardsTableAnnotationComposer,
          $$LoyaltyRewardsTableCreateCompanionBuilder,
          $$LoyaltyRewardsTableUpdateCompanionBuilder,
          (
            LoyaltyReward,
            BaseReferences<_$AppDatabase, $LoyaltyRewardsTable, LoyaltyReward>,
          ),
          LoyaltyReward,
          PrefetchHooks Function()
        > {
  $$LoyaltyRewardsTableTableManager(
    _$AppDatabase db,
    $LoyaltyRewardsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LoyaltyRewardsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LoyaltyRewardsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LoyaltyRewardsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> ptsRequired = const Value.absent(),
                Value<double?> discountAmount = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LoyaltyRewardsCompanion(
                id: id,
                name: name,
                ptsRequired: ptsRequired,
                discountAmount: discountAmount,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required double ptsRequired,
                Value<double?> discountAmount = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LoyaltyRewardsCompanion.insert(
                id: id,
                name: name,
                ptsRequired: ptsRequired,
                discountAmount: discountAmount,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LoyaltyRewardsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LoyaltyRewardsTable,
      LoyaltyReward,
      $$LoyaltyRewardsTableFilterComposer,
      $$LoyaltyRewardsTableOrderingComposer,
      $$LoyaltyRewardsTableAnnotationComposer,
      $$LoyaltyRewardsTableCreateCompanionBuilder,
      $$LoyaltyRewardsTableUpdateCompanionBuilder,
      (
        LoyaltyReward,
        BaseReferences<_$AppDatabase, $LoyaltyRewardsTable, LoyaltyReward>,
      ),
      LoyaltyReward,
      PrefetchHooks Function()
    >;
typedef $$BanZonesTableCreateCompanionBuilder =
    BanZonesCompanion Function({
      required String id,
      required String name,
      Value<String> color,
      Value<int> iconCode,
      Value<int> sortOrder,
      Value<bool> isActive,
      required int createdAt,
      Value<double> canvasX,
      Value<double> canvasY,
      Value<double> canvasWidth,
      Value<double> canvasHeight,
      Value<int> rowid,
    });
typedef $$BanZonesTableUpdateCompanionBuilder =
    BanZonesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> color,
      Value<int> iconCode,
      Value<int> sortOrder,
      Value<bool> isActive,
      Value<int> createdAt,
      Value<double> canvasX,
      Value<double> canvasY,
      Value<double> canvasWidth,
      Value<double> canvasHeight,
      Value<int> rowid,
    });

final class $$BanZonesTableReferences
    extends BaseReferences<_$AppDatabase, $BanZonesTable, BanZone> {
  $$BanZonesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BanDiningTablesTable, List<BanDiningTable>>
  _banDiningTablesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.banDiningTables,
    aliasName: $_aliasNameGenerator(db.banZones.id, db.banDiningTables.zoneId),
  );

  $$BanDiningTablesTableProcessedTableManager get banDiningTablesRefs {
    final manager = $$BanDiningTablesTableTableManager(
      $_db,
      $_db.banDiningTables,
    ).filter((f) => f.zoneId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _banDiningTablesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BanZonesTableFilterComposer
    extends Composer<_$AppDatabase, $BanZonesTable> {
  $$BanZonesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get iconCode => $composableBuilder(
    column: $table.iconCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get canvasX => $composableBuilder(
    column: $table.canvasX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get canvasY => $composableBuilder(
    column: $table.canvasY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get canvasWidth => $composableBuilder(
    column: $table.canvasWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get canvasHeight => $composableBuilder(
    column: $table.canvasHeight,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> banDiningTablesRefs(
    Expression<bool> Function($$BanDiningTablesTableFilterComposer f) f,
  ) {
    final $$BanDiningTablesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.banDiningTables,
      getReferencedColumn: (t) => t.zoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanDiningTablesTableFilterComposer(
            $db: $db,
            $table: $db.banDiningTables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanZonesTableOrderingComposer
    extends Composer<_$AppDatabase, $BanZonesTable> {
  $$BanZonesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get iconCode => $composableBuilder(
    column: $table.iconCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get canvasX => $composableBuilder(
    column: $table.canvasX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get canvasY => $composableBuilder(
    column: $table.canvasY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get canvasWidth => $composableBuilder(
    column: $table.canvasWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get canvasHeight => $composableBuilder(
    column: $table.canvasHeight,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BanZonesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BanZonesTable> {
  $$BanZonesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get iconCode =>
      $composableBuilder(column: $table.iconCode, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<double> get canvasX =>
      $composableBuilder(column: $table.canvasX, builder: (column) => column);

  GeneratedColumn<double> get canvasY =>
      $composableBuilder(column: $table.canvasY, builder: (column) => column);

  GeneratedColumn<double> get canvasWidth => $composableBuilder(
    column: $table.canvasWidth,
    builder: (column) => column,
  );

  GeneratedColumn<double> get canvasHeight => $composableBuilder(
    column: $table.canvasHeight,
    builder: (column) => column,
  );

  Expression<T> banDiningTablesRefs<T extends Object>(
    Expression<T> Function($$BanDiningTablesTableAnnotationComposer a) f,
  ) {
    final $$BanDiningTablesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.banDiningTables,
      getReferencedColumn: (t) => t.zoneId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanDiningTablesTableAnnotationComposer(
            $db: $db,
            $table: $db.banDiningTables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanZonesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BanZonesTable,
          BanZone,
          $$BanZonesTableFilterComposer,
          $$BanZonesTableOrderingComposer,
          $$BanZonesTableAnnotationComposer,
          $$BanZonesTableCreateCompanionBuilder,
          $$BanZonesTableUpdateCompanionBuilder,
          (BanZone, $$BanZonesTableReferences),
          BanZone,
          PrefetchHooks Function({bool banDiningTablesRefs})
        > {
  $$BanZonesTableTableManager(_$AppDatabase db, $BanZonesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BanZonesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BanZonesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BanZonesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> iconCode = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<double> canvasX = const Value.absent(),
                Value<double> canvasY = const Value.absent(),
                Value<double> canvasWidth = const Value.absent(),
                Value<double> canvasHeight = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BanZonesCompanion(
                id: id,
                name: name,
                color: color,
                iconCode: iconCode,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                canvasX: canvasX,
                canvasY: canvasY,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> color = const Value.absent(),
                Value<int> iconCode = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int createdAt,
                Value<double> canvasX = const Value.absent(),
                Value<double> canvasY = const Value.absent(),
                Value<double> canvasWidth = const Value.absent(),
                Value<double> canvasHeight = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BanZonesCompanion.insert(
                id: id,
                name: name,
                color: color,
                iconCode: iconCode,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                canvasX: canvasX,
                canvasY: canvasY,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BanZonesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({banDiningTablesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (banDiningTablesRefs) db.banDiningTables,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (banDiningTablesRefs)
                    await $_getPrefetchedData<
                      BanZone,
                      $BanZonesTable,
                      BanDiningTable
                    >(
                      currentTable: table,
                      referencedTable: $$BanZonesTableReferences
                          ._banDiningTablesRefsTable(db),
                      managerFromTypedResult: (p0) => $$BanZonesTableReferences(
                        db,
                        table,
                        p0,
                      ).banDiningTablesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.zoneId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BanZonesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BanZonesTable,
      BanZone,
      $$BanZonesTableFilterComposer,
      $$BanZonesTableOrderingComposer,
      $$BanZonesTableAnnotationComposer,
      $$BanZonesTableCreateCompanionBuilder,
      $$BanZonesTableUpdateCompanionBuilder,
      (BanZone, $$BanZonesTableReferences),
      BanZone,
      PrefetchHooks Function({bool banDiningTablesRefs})
    >;
typedef $$BanDiningTablesTableCreateCompanionBuilder =
    BanDiningTablesCompanion Function({
      required String id,
      required String zoneId,
      required String name,
      Value<int> capacity,
      Value<double> posX,
      Value<double> posY,
      Value<String> shape,
      Value<double> tableWidth,
      Value<double> tableHeight,
      Value<String?> qrToken,
      Value<int> sortOrder,
      Value<bool> isActive,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$BanDiningTablesTableUpdateCompanionBuilder =
    BanDiningTablesCompanion Function({
      Value<String> id,
      Value<String> zoneId,
      Value<String> name,
      Value<int> capacity,
      Value<double> posX,
      Value<double> posY,
      Value<String> shape,
      Value<double> tableWidth,
      Value<double> tableHeight,
      Value<String?> qrToken,
      Value<int> sortOrder,
      Value<bool> isActive,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$BanDiningTablesTableReferences
    extends
        BaseReferences<_$AppDatabase, $BanDiningTablesTable, BanDiningTable> {
  $$BanDiningTablesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BanZonesTable _zoneIdTable(_$AppDatabase db) =>
      db.banZones.createAlias(
        $_aliasNameGenerator(db.banDiningTables.zoneId, db.banZones.id),
      );

  $$BanZonesTableProcessedTableManager get zoneId {
    final $_column = $_itemColumn<String>('zone_id')!;

    final manager = $$BanZonesTableTableManager(
      $_db,
      $_db.banZones,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_zoneIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BanSessionsTable, List<BanSession>>
  _banSessionsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.banSessions,
    aliasName: $_aliasNameGenerator(
      db.banDiningTables.id,
      db.banSessions.tableId,
    ),
  );

  $$BanSessionsTableProcessedTableManager get banSessionsRefs {
    final manager = $$BanSessionsTableTableManager(
      $_db,
      $_db.banSessions,
    ).filter((f) => f.tableId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_banSessionsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BanDiningTablesTableFilterComposer
    extends Composer<_$AppDatabase, $BanDiningTablesTable> {
  $$BanDiningTablesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tableWidth => $composableBuilder(
    column: $table.tableWidth,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get tableHeight => $composableBuilder(
    column: $table.tableHeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get qrToken => $composableBuilder(
    column: $table.qrToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BanZonesTableFilterComposer get zoneId {
    final $$BanZonesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.zoneId,
      referencedTable: $db.banZones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanZonesTableFilterComposer(
            $db: $db,
            $table: $db.banZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> banSessionsRefs(
    Expression<bool> Function($$BanSessionsTableFilterComposer f) f,
  ) {
    final $$BanSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.tableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableFilterComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanDiningTablesTableOrderingComposer
    extends Composer<_$AppDatabase, $BanDiningTablesTable> {
  $$BanDiningTablesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capacity => $composableBuilder(
    column: $table.capacity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posX => $composableBuilder(
    column: $table.posX,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get posY => $composableBuilder(
    column: $table.posY,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get shape => $composableBuilder(
    column: $table.shape,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tableWidth => $composableBuilder(
    column: $table.tableWidth,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get tableHeight => $composableBuilder(
    column: $table.tableHeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get qrToken => $composableBuilder(
    column: $table.qrToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BanZonesTableOrderingComposer get zoneId {
    final $$BanZonesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.zoneId,
      referencedTable: $db.banZones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanZonesTableOrderingComposer(
            $db: $db,
            $table: $db.banZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BanDiningTablesTableAnnotationComposer
    extends Composer<_$AppDatabase, $BanDiningTablesTable> {
  $$BanDiningTablesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get capacity =>
      $composableBuilder(column: $table.capacity, builder: (column) => column);

  GeneratedColumn<double> get posX =>
      $composableBuilder(column: $table.posX, builder: (column) => column);

  GeneratedColumn<double> get posY =>
      $composableBuilder(column: $table.posY, builder: (column) => column);

  GeneratedColumn<String> get shape =>
      $composableBuilder(column: $table.shape, builder: (column) => column);

  GeneratedColumn<double> get tableWidth => $composableBuilder(
    column: $table.tableWidth,
    builder: (column) => column,
  );

  GeneratedColumn<double> get tableHeight => $composableBuilder(
    column: $table.tableHeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get qrToken =>
      $composableBuilder(column: $table.qrToken, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$BanZonesTableAnnotationComposer get zoneId {
    final $$BanZonesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.zoneId,
      referencedTable: $db.banZones,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanZonesTableAnnotationComposer(
            $db: $db,
            $table: $db.banZones,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> banSessionsRefs<T extends Object>(
    Expression<T> Function($$BanSessionsTableAnnotationComposer a) f,
  ) {
    final $$BanSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.tableId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanDiningTablesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BanDiningTablesTable,
          BanDiningTable,
          $$BanDiningTablesTableFilterComposer,
          $$BanDiningTablesTableOrderingComposer,
          $$BanDiningTablesTableAnnotationComposer,
          $$BanDiningTablesTableCreateCompanionBuilder,
          $$BanDiningTablesTableUpdateCompanionBuilder,
          (BanDiningTable, $$BanDiningTablesTableReferences),
          BanDiningTable,
          PrefetchHooks Function({bool zoneId, bool banSessionsRefs})
        > {
  $$BanDiningTablesTableTableManager(
    _$AppDatabase db,
    $BanDiningTablesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BanDiningTablesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BanDiningTablesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BanDiningTablesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> zoneId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> capacity = const Value.absent(),
                Value<double> posX = const Value.absent(),
                Value<double> posY = const Value.absent(),
                Value<String> shape = const Value.absent(),
                Value<double> tableWidth = const Value.absent(),
                Value<double> tableHeight = const Value.absent(),
                Value<String?> qrToken = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BanDiningTablesCompanion(
                id: id,
                zoneId: zoneId,
                name: name,
                capacity: capacity,
                posX: posX,
                posY: posY,
                shape: shape,
                tableWidth: tableWidth,
                tableHeight: tableHeight,
                qrToken: qrToken,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String zoneId,
                required String name,
                Value<int> capacity = const Value.absent(),
                Value<double> posX = const Value.absent(),
                Value<double> posY = const Value.absent(),
                Value<String> shape = const Value.absent(),
                Value<double> tableWidth = const Value.absent(),
                Value<double> tableHeight = const Value.absent(),
                Value<String?> qrToken = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => BanDiningTablesCompanion.insert(
                id: id,
                zoneId: zoneId,
                name: name,
                capacity: capacity,
                posX: posX,
                posY: posY,
                shape: shape,
                tableWidth: tableWidth,
                tableHeight: tableHeight,
                qrToken: qrToken,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BanDiningTablesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({zoneId = false, banSessionsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (banSessionsRefs) db.banSessions],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (zoneId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.zoneId,
                                referencedTable:
                                    $$BanDiningTablesTableReferences
                                        ._zoneIdTable(db),
                                referencedColumn:
                                    $$BanDiningTablesTableReferences
                                        ._zoneIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (banSessionsRefs)
                    await $_getPrefetchedData<
                      BanDiningTable,
                      $BanDiningTablesTable,
                      BanSession
                    >(
                      currentTable: table,
                      referencedTable: $$BanDiningTablesTableReferences
                          ._banSessionsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BanDiningTablesTableReferences(
                            db,
                            table,
                            p0,
                          ).banSessionsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tableId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BanDiningTablesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BanDiningTablesTable,
      BanDiningTable,
      $$BanDiningTablesTableFilterComposer,
      $$BanDiningTablesTableOrderingComposer,
      $$BanDiningTablesTableAnnotationComposer,
      $$BanDiningTablesTableCreateCompanionBuilder,
      $$BanDiningTablesTableUpdateCompanionBuilder,
      (BanDiningTable, $$BanDiningTablesTableReferences),
      BanDiningTable,
      PrefetchHooks Function({bool zoneId, bool banSessionsRefs})
    >;
typedef $$BanSessionsTableCreateCompanionBuilder =
    BanSessionsCompanion Function({
      required String id,
      required String tableId,
      Value<String> status,
      Value<int> guestCount,
      Value<String?> staffId,
      Value<String?> posOrderId,
      Value<String?> note,
      required int openedAt,
      Value<int?> closedAt,
      Value<int> rowid,
    });
typedef $$BanSessionsTableUpdateCompanionBuilder =
    BanSessionsCompanion Function({
      Value<String> id,
      Value<String> tableId,
      Value<String> status,
      Value<int> guestCount,
      Value<String?> staffId,
      Value<String?> posOrderId,
      Value<String?> note,
      Value<int> openedAt,
      Value<int?> closedAt,
      Value<int> rowid,
    });

final class $$BanSessionsTableReferences
    extends BaseReferences<_$AppDatabase, $BanSessionsTable, BanSession> {
  $$BanSessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BanDiningTablesTable _tableIdTable(_$AppDatabase db) =>
      db.banDiningTables.createAlias(
        $_aliasNameGenerator(db.banSessions.tableId, db.banDiningTables.id),
      );

  $$BanDiningTablesTableProcessedTableManager get tableId {
    final $_column = $_itemColumn<String>('table_id')!;

    final manager = $$BanDiningTablesTableTableManager(
      $_db,
      $_db.banDiningTables,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tableIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$BanSessionItemsTable, List<BanSessionItem>>
  _banSessionItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.banSessionItems,
    aliasName: $_aliasNameGenerator(
      db.banSessions.id,
      db.banSessionItems.sessionId,
    ),
  );

  $$BanSessionItemsTableProcessedTableManager get banSessionItemsRefs {
    final manager = $$BanSessionItemsTableTableManager(
      $_db,
      $_db.banSessionItems,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _banSessionItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$KitchenTicketsTable, List<KitchenTicket>>
  _kitchenTicketsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.kitchenTickets,
    aliasName: $_aliasNameGenerator(
      db.banSessions.id,
      db.kitchenTickets.sessionId,
    ),
  );

  $$KitchenTicketsTableProcessedTableManager get kitchenTicketsRefs {
    final manager = $$KitchenTicketsTableTableManager(
      $_db,
      $_db.kitchenTickets,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_kitchenTicketsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BanSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $BanSessionsTable> {
  $$BanSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get guestCount => $composableBuilder(
    column: $table.guestCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get posOrderId => $composableBuilder(
    column: $table.posOrderId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BanDiningTablesTableFilterComposer get tableId {
    final $$BanDiningTablesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tableId,
      referencedTable: $db.banDiningTables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanDiningTablesTableFilterComposer(
            $db: $db,
            $table: $db.banDiningTables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> banSessionItemsRefs(
    Expression<bool> Function($$BanSessionItemsTableFilterComposer f) f,
  ) {
    final $$BanSessionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableFilterComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> kitchenTicketsRefs(
    Expression<bool> Function($$KitchenTicketsTableFilterComposer f) f,
  ) {
    final $$KitchenTicketsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.kitchenTickets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketsTableFilterComposer(
            $db: $db,
            $table: $db.kitchenTickets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $BanSessionsTable> {
  $$BanSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get guestCount => $composableBuilder(
    column: $table.guestCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get staffId => $composableBuilder(
    column: $table.staffId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get posOrderId => $composableBuilder(
    column: $table.posOrderId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get openedAt => $composableBuilder(
    column: $table.openedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedAt => $composableBuilder(
    column: $table.closedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BanDiningTablesTableOrderingComposer get tableId {
    final $$BanDiningTablesTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tableId,
      referencedTable: $db.banDiningTables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanDiningTablesTableOrderingComposer(
            $db: $db,
            $table: $db.banDiningTables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BanSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BanSessionsTable> {
  $$BanSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get guestCount => $composableBuilder(
    column: $table.guestCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get staffId =>
      $composableBuilder(column: $table.staffId, builder: (column) => column);

  GeneratedColumn<String> get posOrderId => $composableBuilder(
    column: $table.posOrderId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<int> get closedAt =>
      $composableBuilder(column: $table.closedAt, builder: (column) => column);

  $$BanDiningTablesTableAnnotationComposer get tableId {
    final $$BanDiningTablesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tableId,
      referencedTable: $db.banDiningTables,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanDiningTablesTableAnnotationComposer(
            $db: $db,
            $table: $db.banDiningTables,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> banSessionItemsRefs<T extends Object>(
    Expression<T> Function($$BanSessionItemsTableAnnotationComposer a) f,
  ) {
    final $$BanSessionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> kitchenTicketsRefs<T extends Object>(
    Expression<T> Function($$KitchenTicketsTableAnnotationComposer a) f,
  ) {
    final $$KitchenTicketsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.kitchenTickets,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketsTableAnnotationComposer(
            $db: $db,
            $table: $db.kitchenTickets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BanSessionsTable,
          BanSession,
          $$BanSessionsTableFilterComposer,
          $$BanSessionsTableOrderingComposer,
          $$BanSessionsTableAnnotationComposer,
          $$BanSessionsTableCreateCompanionBuilder,
          $$BanSessionsTableUpdateCompanionBuilder,
          (BanSession, $$BanSessionsTableReferences),
          BanSession,
          PrefetchHooks Function({
            bool tableId,
            bool banSessionItemsRefs,
            bool kitchenTicketsRefs,
          })
        > {
  $$BanSessionsTableTableManager(_$AppDatabase db, $BanSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BanSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BanSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BanSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tableId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> guestCount = const Value.absent(),
                Value<String?> staffId = const Value.absent(),
                Value<String?> posOrderId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<int> openedAt = const Value.absent(),
                Value<int?> closedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BanSessionsCompanion(
                id: id,
                tableId: tableId,
                status: status,
                guestCount: guestCount,
                staffId: staffId,
                posOrderId: posOrderId,
                note: note,
                openedAt: openedAt,
                closedAt: closedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tableId,
                Value<String> status = const Value.absent(),
                Value<int> guestCount = const Value.absent(),
                Value<String?> staffId = const Value.absent(),
                Value<String?> posOrderId = const Value.absent(),
                Value<String?> note = const Value.absent(),
                required int openedAt,
                Value<int?> closedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BanSessionsCompanion.insert(
                id: id,
                tableId: tableId,
                status: status,
                guestCount: guestCount,
                staffId: staffId,
                posOrderId: posOrderId,
                note: note,
                openedAt: openedAt,
                closedAt: closedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BanSessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tableId = false,
                banSessionItemsRefs = false,
                kitchenTicketsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (banSessionItemsRefs) db.banSessionItems,
                    if (kitchenTicketsRefs) db.kitchenTickets,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (tableId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.tableId,
                                    referencedTable:
                                        $$BanSessionsTableReferences
                                            ._tableIdTable(db),
                                    referencedColumn:
                                        $$BanSessionsTableReferences
                                            ._tableIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (banSessionItemsRefs)
                        await $_getPrefetchedData<
                          BanSession,
                          $BanSessionsTable,
                          BanSessionItem
                        >(
                          currentTable: table,
                          referencedTable: $$BanSessionsTableReferences
                              ._banSessionItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BanSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).banSessionItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (kitchenTicketsRefs)
                        await $_getPrefetchedData<
                          BanSession,
                          $BanSessionsTable,
                          KitchenTicket
                        >(
                          currentTable: table,
                          referencedTable: $$BanSessionsTableReferences
                              ._kitchenTicketsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BanSessionsTableReferences(
                                db,
                                table,
                                p0,
                              ).kitchenTicketsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BanSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BanSessionsTable,
      BanSession,
      $$BanSessionsTableFilterComposer,
      $$BanSessionsTableOrderingComposer,
      $$BanSessionsTableAnnotationComposer,
      $$BanSessionsTableCreateCompanionBuilder,
      $$BanSessionsTableUpdateCompanionBuilder,
      (BanSession, $$BanSessionsTableReferences),
      BanSession,
      PrefetchHooks Function({
        bool tableId,
        bool banSessionItemsRefs,
        bool kitchenTicketsRefs,
      })
    >;
typedef $$BanSessionItemsTableCreateCompanionBuilder =
    BanSessionItemsCompanion Function({
      required String id,
      required String sessionId,
      required String productId,
      required String productName,
      required double unitPrice,
      Value<double> quantity,
      required double subtotal,
      Value<String?> note,
      Value<String?> addedBy,
      required int addedAt,
      Value<String> kitchenStatus,
      Value<int> rowid,
    });
typedef $$BanSessionItemsTableUpdateCompanionBuilder =
    BanSessionItemsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> productId,
      Value<String> productName,
      Value<double> unitPrice,
      Value<double> quantity,
      Value<double> subtotal,
      Value<String?> note,
      Value<String?> addedBy,
      Value<int> addedAt,
      Value<String> kitchenStatus,
      Value<int> rowid,
    });

final class $$BanSessionItemsTableReferences
    extends
        BaseReferences<_$AppDatabase, $BanSessionItemsTable, BanSessionItem> {
  $$BanSessionItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BanSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.banSessions.createAlias(
        $_aliasNameGenerator(db.banSessionItems.sessionId, db.banSessions.id),
      );

  $$BanSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$BanSessionsTableTableManager(
      $_db,
      $_db.banSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $SessionItemModifiersTable,
    List<SessionItemModifier>
  >
  _sessionItemModifiersRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.sessionItemModifiers,
        aliasName: $_aliasNameGenerator(
          db.banSessionItems.id,
          db.sessionItemModifiers.sessionItemId,
        ),
      );

  $$SessionItemModifiersTableProcessedTableManager
  get sessionItemModifiersRefs {
    final manager = $$SessionItemModifiersTableTableManager(
      $_db,
      $_db.sessionItemModifiers,
    ).filter((f) => f.sessionItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _sessionItemModifiersRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$KitchenTicketItemsTable, List<KitchenTicketItem>>
  _kitchenTicketItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.kitchenTicketItems,
        aliasName: $_aliasNameGenerator(
          db.banSessionItems.id,
          db.kitchenTicketItems.sessionItemId,
        ),
      );

  $$KitchenTicketItemsTableProcessedTableManager get kitchenTicketItemsRefs {
    final manager = $$KitchenTicketItemsTableTableManager(
      $_db,
      $_db.kitchenTicketItems,
    ).filter((f) => f.sessionItemId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _kitchenTicketItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BanSessionItemsTableFilterComposer
    extends Composer<_$AppDatabase, $BanSessionItemsTable> {
  $$BanSessionItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenStatus => $composableBuilder(
    column: $table.kitchenStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$BanSessionsTableFilterComposer get sessionId {
    final $$BanSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableFilterComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> sessionItemModifiersRefs(
    Expression<bool> Function($$SessionItemModifiersTableFilterComposer f) f,
  ) {
    final $$SessionItemModifiersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.sessionItemModifiers,
      getReferencedColumn: (t) => t.sessionItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionItemModifiersTableFilterComposer(
            $db: $db,
            $table: $db.sessionItemModifiers,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> kitchenTicketItemsRefs(
    Expression<bool> Function($$KitchenTicketItemsTableFilterComposer f) f,
  ) {
    final $$KitchenTicketItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.kitchenTicketItems,
      getReferencedColumn: (t) => t.sessionItemId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketItemsTableFilterComposer(
            $db: $db,
            $table: $db.kitchenTicketItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BanSessionItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $BanSessionItemsTable> {
  $$BanSessionItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productId => $composableBuilder(
    column: $table.productId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get unitPrice => $composableBuilder(
    column: $table.unitPrice,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get subtotal => $composableBuilder(
    column: $table.subtotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get addedBy => $composableBuilder(
    column: $table.addedBy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenStatus => $composableBuilder(
    column: $table.kitchenStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$BanSessionsTableOrderingComposer get sessionId {
    final $$BanSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BanSessionItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BanSessionItemsTable> {
  $$BanSessionItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productId =>
      $composableBuilder(column: $table.productId, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get unitPrice =>
      $composableBuilder(column: $table.unitPrice, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get subtotal =>
      $composableBuilder(column: $table.subtotal, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get addedBy =>
      $composableBuilder(column: $table.addedBy, builder: (column) => column);

  GeneratedColumn<int> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<String> get kitchenStatus => $composableBuilder(
    column: $table.kitchenStatus,
    builder: (column) => column,
  );

  $$BanSessionsTableAnnotationComposer get sessionId {
    final $$BanSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> sessionItemModifiersRefs<T extends Object>(
    Expression<T> Function($$SessionItemModifiersTableAnnotationComposer a) f,
  ) {
    final $$SessionItemModifiersTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.sessionItemModifiers,
          getReferencedColumn: (t) => t.sessionItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionItemModifiersTableAnnotationComposer(
                $db: $db,
                $table: $db.sessionItemModifiers,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> kitchenTicketItemsRefs<T extends Object>(
    Expression<T> Function($$KitchenTicketItemsTableAnnotationComposer a) f,
  ) {
    final $$KitchenTicketItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.kitchenTicketItems,
          getReferencedColumn: (t) => t.sessionItemId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$KitchenTicketItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.kitchenTicketItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$BanSessionItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BanSessionItemsTable,
          BanSessionItem,
          $$BanSessionItemsTableFilterComposer,
          $$BanSessionItemsTableOrderingComposer,
          $$BanSessionItemsTableAnnotationComposer,
          $$BanSessionItemsTableCreateCompanionBuilder,
          $$BanSessionItemsTableUpdateCompanionBuilder,
          (BanSessionItem, $$BanSessionItemsTableReferences),
          BanSessionItem,
          PrefetchHooks Function({
            bool sessionId,
            bool sessionItemModifiersRefs,
            bool kitchenTicketItemsRefs,
          })
        > {
  $$BanSessionItemsTableTableManager(
    _$AppDatabase db,
    $BanSessionItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BanSessionItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BanSessionItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BanSessionItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<double> unitPrice = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> subtotal = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                Value<int> addedAt = const Value.absent(),
                Value<String> kitchenStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BanSessionItemsCompanion(
                id: id,
                sessionId: sessionId,
                productId: productId,
                productName: productName,
                unitPrice: unitPrice,
                quantity: quantity,
                subtotal: subtotal,
                note: note,
                addedBy: addedBy,
                addedAt: addedAt,
                kitchenStatus: kitchenStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String productId,
                required String productName,
                required double unitPrice,
                Value<double> quantity = const Value.absent(),
                required double subtotal,
                Value<String?> note = const Value.absent(),
                Value<String?> addedBy = const Value.absent(),
                required int addedAt,
                Value<String> kitchenStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BanSessionItemsCompanion.insert(
                id: id,
                sessionId: sessionId,
                productId: productId,
                productName: productName,
                unitPrice: unitPrice,
                quantity: quantity,
                subtotal: subtotal,
                note: note,
                addedBy: addedBy,
                addedAt: addedAt,
                kitchenStatus: kitchenStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BanSessionItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sessionId = false,
                sessionItemModifiersRefs = false,
                kitchenTicketItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (sessionItemModifiersRefs) db.sessionItemModifiers,
                    if (kitchenTicketItemsRefs) db.kitchenTicketItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable:
                                        $$BanSessionItemsTableReferences
                                            ._sessionIdTable(db),
                                    referencedColumn:
                                        $$BanSessionItemsTableReferences
                                            ._sessionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (sessionItemModifiersRefs)
                        await $_getPrefetchedData<
                          BanSessionItem,
                          $BanSessionItemsTable,
                          SessionItemModifier
                        >(
                          currentTable: table,
                          referencedTable: $$BanSessionItemsTableReferences
                              ._sessionItemModifiersRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BanSessionItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).sessionItemModifiersRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (kitchenTicketItemsRefs)
                        await $_getPrefetchedData<
                          BanSessionItem,
                          $BanSessionItemsTable,
                          KitchenTicketItem
                        >(
                          currentTable: table,
                          referencedTable: $$BanSessionItemsTableReferences
                              ._kitchenTicketItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BanSessionItemsTableReferences(
                                db,
                                table,
                                p0,
                              ).kitchenTicketItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sessionItemId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BanSessionItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BanSessionItemsTable,
      BanSessionItem,
      $$BanSessionItemsTableFilterComposer,
      $$BanSessionItemsTableOrderingComposer,
      $$BanSessionItemsTableAnnotationComposer,
      $$BanSessionItemsTableCreateCompanionBuilder,
      $$BanSessionItemsTableUpdateCompanionBuilder,
      (BanSessionItem, $$BanSessionItemsTableReferences),
      BanSessionItem,
      PrefetchHooks Function({
        bool sessionId,
        bool sessionItemModifiersRefs,
        bool kitchenTicketItemsRefs,
      })
    >;
typedef $$KitchenStationsTableCreateCompanionBuilder =
    KitchenStationsCompanion Function({
      required String id,
      required String name,
      Value<String> color,
      Value<int> sortOrder,
      Value<bool> isActive,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$KitchenStationsTableUpdateCompanionBuilder =
    KitchenStationsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> color,
      Value<int> sortOrder,
      Value<bool> isActive,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$KitchenStationsTableReferences
    extends
        BaseReferences<_$AppDatabase, $KitchenStationsTable, KitchenStation> {
  $$KitchenStationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$KitchenTicketsTable, List<KitchenTicket>>
  _kitchenTicketsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.kitchenTickets,
    aliasName: $_aliasNameGenerator(
      db.kitchenStations.id,
      db.kitchenTickets.stationId,
    ),
  );

  $$KitchenTicketsTableProcessedTableManager get kitchenTicketsRefs {
    final manager = $$KitchenTicketsTableTableManager(
      $_db,
      $_db.kitchenTickets,
    ).filter((f) => f.stationId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_kitchenTicketsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KitchenStationsTableFilterComposer
    extends Composer<_$AppDatabase, $KitchenStationsTable> {
  $$KitchenStationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> kitchenTicketsRefs(
    Expression<bool> Function($$KitchenTicketsTableFilterComposer f) f,
  ) {
    final $$KitchenTicketsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.kitchenTickets,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketsTableFilterComposer(
            $db: $db,
            $table: $db.kitchenTickets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KitchenStationsTableOrderingComposer
    extends Composer<_$AppDatabase, $KitchenStationsTable> {
  $$KitchenStationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KitchenStationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KitchenStationsTable> {
  $$KitchenStationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> kitchenTicketsRefs<T extends Object>(
    Expression<T> Function($$KitchenTicketsTableAnnotationComposer a) f,
  ) {
    final $$KitchenTicketsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.kitchenTickets,
      getReferencedColumn: (t) => t.stationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketsTableAnnotationComposer(
            $db: $db,
            $table: $db.kitchenTickets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KitchenStationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KitchenStationsTable,
          KitchenStation,
          $$KitchenStationsTableFilterComposer,
          $$KitchenStationsTableOrderingComposer,
          $$KitchenStationsTableAnnotationComposer,
          $$KitchenStationsTableCreateCompanionBuilder,
          $$KitchenStationsTableUpdateCompanionBuilder,
          (KitchenStation, $$KitchenStationsTableReferences),
          KitchenStation,
          PrefetchHooks Function({bool kitchenTicketsRefs})
        > {
  $$KitchenStationsTableTableManager(
    _$AppDatabase db,
    $KitchenStationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KitchenStationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KitchenStationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KitchenStationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KitchenStationsCompanion(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String> color = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => KitchenStationsCompanion.insert(
                id: id,
                name: name,
                color: color,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KitchenStationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({kitchenTicketsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (kitchenTicketsRefs) db.kitchenTickets,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (kitchenTicketsRefs)
                    await $_getPrefetchedData<
                      KitchenStation,
                      $KitchenStationsTable,
                      KitchenTicket
                    >(
                      currentTable: table,
                      referencedTable: $$KitchenStationsTableReferences
                          ._kitchenTicketsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$KitchenStationsTableReferences(
                            db,
                            table,
                            p0,
                          ).kitchenTicketsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.stationId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$KitchenStationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KitchenStationsTable,
      KitchenStation,
      $$KitchenStationsTableFilterComposer,
      $$KitchenStationsTableOrderingComposer,
      $$KitchenStationsTableAnnotationComposer,
      $$KitchenStationsTableCreateCompanionBuilder,
      $$KitchenStationsTableUpdateCompanionBuilder,
      (KitchenStation, $$KitchenStationsTableReferences),
      KitchenStation,
      PrefetchHooks Function({bool kitchenTicketsRefs})
    >;
typedef $$ProductModifiersTableCreateCompanionBuilder =
    ProductModifiersCompanion Function({
      required String id,
      required String productId,
      Value<String> groupName,
      required String name,
      Value<double> priceAdjust,
      Value<int> sortOrder,
      Value<bool> isActive,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$ProductModifiersTableUpdateCompanionBuilder =
    ProductModifiersCompanion Function({
      Value<String> id,
      Value<String> productId,
      Value<String> groupName,
      Value<String> name,
      Value<double> priceAdjust,
      Value<int> sortOrder,
      Value<bool> isActive,
      Value<int> createdAt,
      Value<int> rowid,
    });

final class $$ProductModifiersTableReferences
    extends
        BaseReferences<_$AppDatabase, $ProductModifiersTable, ProductModifier> {
  $$ProductModifiersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $CoreProductsTable _productIdTable(_$AppDatabase db) =>
      db.coreProducts.createAlias(
        $_aliasNameGenerator(db.productModifiers.productId, db.coreProducts.id),
      );

  $$CoreProductsTableProcessedTableManager get productId {
    final $_column = $_itemColumn<String>('product_id')!;

    final manager = $$CoreProductsTableTableManager(
      $_db,
      $_db.coreProducts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_productIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ProductModifiersTableFilterComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get priceAdjust => $composableBuilder(
    column: $table.priceAdjust,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$CoreProductsTableFilterComposer get productId {
    final $$CoreProductsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableFilterComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableOrderingComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupName => $composableBuilder(
    column: $table.groupName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get priceAdjust => $composableBuilder(
    column: $table.priceAdjust,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$CoreProductsTableOrderingComposer get productId {
    final $$CoreProductsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableOrderingComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProductModifiersTable> {
  $$ProductModifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupName =>
      $composableBuilder(column: $table.groupName, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get priceAdjust => $composableBuilder(
    column: $table.priceAdjust,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$CoreProductsTableAnnotationComposer get productId {
    final $$CoreProductsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.productId,
      referencedTable: $db.coreProducts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$CoreProductsTableAnnotationComposer(
            $db: $db,
            $table: $db.coreProducts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ProductModifiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProductModifiersTable,
          ProductModifier,
          $$ProductModifiersTableFilterComposer,
          $$ProductModifiersTableOrderingComposer,
          $$ProductModifiersTableAnnotationComposer,
          $$ProductModifiersTableCreateCompanionBuilder,
          $$ProductModifiersTableUpdateCompanionBuilder,
          (ProductModifier, $$ProductModifiersTableReferences),
          ProductModifier,
          PrefetchHooks Function({bool productId})
        > {
  $$ProductModifiersTableTableManager(
    _$AppDatabase db,
    $ProductModifiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProductModifiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProductModifiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProductModifiersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> productId = const Value.absent(),
                Value<String> groupName = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double> priceAdjust = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProductModifiersCompanion(
                id: id,
                productId: productId,
                groupName: groupName,
                name: name,
                priceAdjust: priceAdjust,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String productId,
                Value<String> groupName = const Value.absent(),
                required String name,
                Value<double> priceAdjust = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ProductModifiersCompanion.insert(
                id: id,
                productId: productId,
                groupName: groupName,
                name: name,
                priceAdjust: priceAdjust,
                sortOrder: sortOrder,
                isActive: isActive,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ProductModifiersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({productId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (productId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.productId,
                                referencedTable:
                                    $$ProductModifiersTableReferences
                                        ._productIdTable(db),
                                referencedColumn:
                                    $$ProductModifiersTableReferences
                                        ._productIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ProductModifiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProductModifiersTable,
      ProductModifier,
      $$ProductModifiersTableFilterComposer,
      $$ProductModifiersTableOrderingComposer,
      $$ProductModifiersTableAnnotationComposer,
      $$ProductModifiersTableCreateCompanionBuilder,
      $$ProductModifiersTableUpdateCompanionBuilder,
      (ProductModifier, $$ProductModifiersTableReferences),
      ProductModifier,
      PrefetchHooks Function({bool productId})
    >;
typedef $$SessionItemModifiersTableCreateCompanionBuilder =
    SessionItemModifiersCompanion Function({
      required String id,
      required String sessionItemId,
      required String modifierName,
      Value<double> priceAdjust,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$SessionItemModifiersTableUpdateCompanionBuilder =
    SessionItemModifiersCompanion Function({
      Value<String> id,
      Value<String> sessionItemId,
      Value<String> modifierName,
      Value<double> priceAdjust,
      Value<int> sortOrder,
      Value<int> rowid,
    });

final class $$SessionItemModifiersTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SessionItemModifiersTable,
          SessionItemModifier
        > {
  $$SessionItemModifiersTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BanSessionItemsTable _sessionItemIdTable(_$AppDatabase db) =>
      db.banSessionItems.createAlias(
        $_aliasNameGenerator(
          db.sessionItemModifiers.sessionItemId,
          db.banSessionItems.id,
        ),
      );

  $$BanSessionItemsTableProcessedTableManager get sessionItemId {
    final $_column = $_itemColumn<String>('session_item_id')!;

    final manager = $$BanSessionItemsTableTableManager(
      $_db,
      $_db.banSessionItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SessionItemModifiersTableFilterComposer
    extends Composer<_$AppDatabase, $SessionItemModifiersTable> {
  $$SessionItemModifiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modifierName => $composableBuilder(
    column: $table.modifierName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get priceAdjust => $composableBuilder(
    column: $table.priceAdjust,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  $$BanSessionItemsTableFilterComposer get sessionItemId {
    final $$BanSessionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionItemId,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableFilterComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionItemModifiersTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionItemModifiersTable> {
  $$SessionItemModifiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modifierName => $composableBuilder(
    column: $table.modifierName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get priceAdjust => $composableBuilder(
    column: $table.priceAdjust,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  $$BanSessionItemsTableOrderingComposer get sessionItemId {
    final $$BanSessionItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionItemId,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableOrderingComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionItemModifiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionItemModifiersTable> {
  $$SessionItemModifiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modifierName => $composableBuilder(
    column: $table.modifierName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get priceAdjust => $composableBuilder(
    column: $table.priceAdjust,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  $$BanSessionItemsTableAnnotationComposer get sessionItemId {
    final $$BanSessionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionItemId,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SessionItemModifiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionItemModifiersTable,
          SessionItemModifier,
          $$SessionItemModifiersTableFilterComposer,
          $$SessionItemModifiersTableOrderingComposer,
          $$SessionItemModifiersTableAnnotationComposer,
          $$SessionItemModifiersTableCreateCompanionBuilder,
          $$SessionItemModifiersTableUpdateCompanionBuilder,
          (SessionItemModifier, $$SessionItemModifiersTableReferences),
          SessionItemModifier,
          PrefetchHooks Function({bool sessionItemId})
        > {
  $$SessionItemModifiersTableTableManager(
    _$AppDatabase db,
    $SessionItemModifiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionItemModifiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionItemModifiersTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionItemModifiersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionItemId = const Value.absent(),
                Value<String> modifierName = const Value.absent(),
                Value<double> priceAdjust = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionItemModifiersCompanion(
                id: id,
                sessionItemId: sessionItemId,
                modifierName: modifierName,
                priceAdjust: priceAdjust,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionItemId,
                required String modifierName,
                Value<double> priceAdjust = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionItemModifiersCompanion.insert(
                id: id,
                sessionItemId: sessionItemId,
                modifierName: modifierName,
                priceAdjust: priceAdjust,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionItemModifiersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sessionItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sessionItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionItemId,
                                referencedTable:
                                    $$SessionItemModifiersTableReferences
                                        ._sessionItemIdTable(db),
                                referencedColumn:
                                    $$SessionItemModifiersTableReferences
                                        ._sessionItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SessionItemModifiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionItemModifiersTable,
      SessionItemModifier,
      $$SessionItemModifiersTableFilterComposer,
      $$SessionItemModifiersTableOrderingComposer,
      $$SessionItemModifiersTableAnnotationComposer,
      $$SessionItemModifiersTableCreateCompanionBuilder,
      $$SessionItemModifiersTableUpdateCompanionBuilder,
      (SessionItemModifier, $$SessionItemModifiersTableReferences),
      SessionItemModifier,
      PrefetchHooks Function({bool sessionItemId})
    >;
typedef $$KitchenTicketsTableCreateCompanionBuilder =
    KitchenTicketsCompanion Function({
      required String id,
      required String sessionId,
      required String tableLabel,
      required String zoneLabel,
      Value<int> round,
      Value<String?> stationId,
      Value<String> status,
      required int sentAt,
      Value<int?> startedAt,
      Value<int?> doneAt,
      Value<int> rowid,
    });
typedef $$KitchenTicketsTableUpdateCompanionBuilder =
    KitchenTicketsCompanion Function({
      Value<String> id,
      Value<String> sessionId,
      Value<String> tableLabel,
      Value<String> zoneLabel,
      Value<int> round,
      Value<String?> stationId,
      Value<String> status,
      Value<int> sentAt,
      Value<int?> startedAt,
      Value<int?> doneAt,
      Value<int> rowid,
    });

final class $$KitchenTicketsTableReferences
    extends BaseReferences<_$AppDatabase, $KitchenTicketsTable, KitchenTicket> {
  $$KitchenTicketsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $BanSessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.banSessions.createAlias(
        $_aliasNameGenerator(db.kitchenTickets.sessionId, db.banSessions.id),
      );

  $$BanSessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<String>('session_id')!;

    final manager = $$BanSessionsTableTableManager(
      $_db,
      $_db.banSessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $KitchenStationsTable _stationIdTable(_$AppDatabase db) =>
      db.kitchenStations.createAlias(
        $_aliasNameGenerator(
          db.kitchenTickets.stationId,
          db.kitchenStations.id,
        ),
      );

  $$KitchenStationsTableProcessedTableManager? get stationId {
    final $_column = $_itemColumn<String>('station_id');
    if ($_column == null) return null;
    final manager = $$KitchenStationsTableTableManager(
      $_db,
      $_db.kitchenStations,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_stationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$KitchenTicketItemsTable, List<KitchenTicketItem>>
  _kitchenTicketItemsRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.kitchenTicketItems,
        aliasName: $_aliasNameGenerator(
          db.kitchenTickets.id,
          db.kitchenTicketItems.ticketId,
        ),
      );

  $$KitchenTicketItemsTableProcessedTableManager get kitchenTicketItemsRefs {
    final manager = $$KitchenTicketItemsTableTableManager(
      $_db,
      $_db.kitchenTicketItems,
    ).filter((f) => f.ticketId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _kitchenTicketItemsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$KitchenTicketsTableFilterComposer
    extends Composer<_$AppDatabase, $KitchenTicketsTable> {
  $$KitchenTicketsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tableLabel => $composableBuilder(
    column: $table.tableLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zoneLabel => $composableBuilder(
    column: $table.zoneLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  $$BanSessionsTableFilterComposer get sessionId {
    final $$BanSessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableFilterComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$KitchenStationsTableFilterComposer get stationId {
    final $$KitchenStationsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.kitchenStations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenStationsTableFilterComposer(
            $db: $db,
            $table: $db.kitchenStations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> kitchenTicketItemsRefs(
    Expression<bool> Function($$KitchenTicketItemsTableFilterComposer f) f,
  ) {
    final $$KitchenTicketItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.kitchenTicketItems,
      getReferencedColumn: (t) => t.ticketId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketItemsTableFilterComposer(
            $db: $db,
            $table: $db.kitchenTicketItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$KitchenTicketsTableOrderingComposer
    extends Composer<_$AppDatabase, $KitchenTicketsTable> {
  $$KitchenTicketsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tableLabel => $composableBuilder(
    column: $table.tableLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zoneLabel => $composableBuilder(
    column: $table.zoneLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get round => $composableBuilder(
    column: $table.round,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sentAt => $composableBuilder(
    column: $table.sentAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$BanSessionsTableOrderingComposer get sessionId {
    final $$BanSessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableOrderingComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$KitchenStationsTableOrderingComposer get stationId {
    final $$KitchenStationsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.kitchenStations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenStationsTableOrderingComposer(
            $db: $db,
            $table: $db.kitchenStations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KitchenTicketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KitchenTicketsTable> {
  $$KitchenTicketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tableLabel => $composableBuilder(
    column: $table.tableLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get zoneLabel =>
      $composableBuilder(column: $table.zoneLabel, builder: (column) => column);

  GeneratedColumn<int> get round =>
      $composableBuilder(column: $table.round, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get sentAt =>
      $composableBuilder(column: $table.sentAt, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  $$BanSessionsTableAnnotationComposer get sessionId {
    final $$BanSessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.banSessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.banSessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$KitchenStationsTableAnnotationComposer get stationId {
    final $$KitchenStationsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.stationId,
      referencedTable: $db.kitchenStations,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenStationsTableAnnotationComposer(
            $db: $db,
            $table: $db.kitchenStations,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> kitchenTicketItemsRefs<T extends Object>(
    Expression<T> Function($$KitchenTicketItemsTableAnnotationComposer a) f,
  ) {
    final $$KitchenTicketItemsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.kitchenTicketItems,
          getReferencedColumn: (t) => t.ticketId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$KitchenTicketItemsTableAnnotationComposer(
                $db: $db,
                $table: $db.kitchenTicketItems,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$KitchenTicketsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KitchenTicketsTable,
          KitchenTicket,
          $$KitchenTicketsTableFilterComposer,
          $$KitchenTicketsTableOrderingComposer,
          $$KitchenTicketsTableAnnotationComposer,
          $$KitchenTicketsTableCreateCompanionBuilder,
          $$KitchenTicketsTableUpdateCompanionBuilder,
          (KitchenTicket, $$KitchenTicketsTableReferences),
          KitchenTicket,
          PrefetchHooks Function({
            bool sessionId,
            bool stationId,
            bool kitchenTicketItemsRefs,
          })
        > {
  $$KitchenTicketsTableTableManager(
    _$AppDatabase db,
    $KitchenTicketsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KitchenTicketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KitchenTicketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KitchenTicketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> tableLabel = const Value.absent(),
                Value<String> zoneLabel = const Value.absent(),
                Value<int> round = const Value.absent(),
                Value<String?> stationId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> sentAt = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KitchenTicketsCompanion(
                id: id,
                sessionId: sessionId,
                tableLabel: tableLabel,
                zoneLabel: zoneLabel,
                round: round,
                stationId: stationId,
                status: status,
                sentAt: sentAt,
                startedAt: startedAt,
                doneAt: doneAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sessionId,
                required String tableLabel,
                required String zoneLabel,
                Value<int> round = const Value.absent(),
                Value<String?> stationId = const Value.absent(),
                Value<String> status = const Value.absent(),
                required int sentAt,
                Value<int?> startedAt = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KitchenTicketsCompanion.insert(
                id: id,
                sessionId: sessionId,
                tableLabel: tableLabel,
                zoneLabel: zoneLabel,
                round: round,
                stationId: stationId,
                status: status,
                sentAt: sentAt,
                startedAt: startedAt,
                doneAt: doneAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KitchenTicketsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                sessionId = false,
                stationId = false,
                kitchenTicketItemsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (kitchenTicketItemsRefs) db.kitchenTicketItems,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable:
                                        $$KitchenTicketsTableReferences
                                            ._sessionIdTable(db),
                                    referencedColumn:
                                        $$KitchenTicketsTableReferences
                                            ._sessionIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }
                        if (stationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.stationId,
                                    referencedTable:
                                        $$KitchenTicketsTableReferences
                                            ._stationIdTable(db),
                                    referencedColumn:
                                        $$KitchenTicketsTableReferences
                                            ._stationIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (kitchenTicketItemsRefs)
                        await $_getPrefetchedData<
                          KitchenTicket,
                          $KitchenTicketsTable,
                          KitchenTicketItem
                        >(
                          currentTable: table,
                          referencedTable: $$KitchenTicketsTableReferences
                              ._kitchenTicketItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$KitchenTicketsTableReferences(
                                db,
                                table,
                                p0,
                              ).kitchenTicketItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.ticketId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$KitchenTicketsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KitchenTicketsTable,
      KitchenTicket,
      $$KitchenTicketsTableFilterComposer,
      $$KitchenTicketsTableOrderingComposer,
      $$KitchenTicketsTableAnnotationComposer,
      $$KitchenTicketsTableCreateCompanionBuilder,
      $$KitchenTicketsTableUpdateCompanionBuilder,
      (KitchenTicket, $$KitchenTicketsTableReferences),
      KitchenTicket,
      PrefetchHooks Function({
        bool sessionId,
        bool stationId,
        bool kitchenTicketItemsRefs,
      })
    >;
typedef $$KitchenTicketItemsTableCreateCompanionBuilder =
    KitchenTicketItemsCompanion Function({
      required String id,
      required String ticketId,
      required String sessionItemId,
      required String productName,
      required double quantity,
      Value<String> modifiersJson,
      Value<String?> freeNote,
      Value<String?> kitchenNote,
      Value<String?> editHistoryJson,
      Value<String> status,
      Value<String> stationCode,
      Value<int?> startedAt,
      Value<int?> doneAt,
      Value<int> rowid,
    });
typedef $$KitchenTicketItemsTableUpdateCompanionBuilder =
    KitchenTicketItemsCompanion Function({
      Value<String> id,
      Value<String> ticketId,
      Value<String> sessionItemId,
      Value<String> productName,
      Value<double> quantity,
      Value<String> modifiersJson,
      Value<String?> freeNote,
      Value<String?> kitchenNote,
      Value<String?> editHistoryJson,
      Value<String> status,
      Value<String> stationCode,
      Value<int?> startedAt,
      Value<int?> doneAt,
      Value<int> rowid,
    });

final class $$KitchenTicketItemsTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $KitchenTicketItemsTable,
          KitchenTicketItem
        > {
  $$KitchenTicketItemsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $KitchenTicketsTable _ticketIdTable(_$AppDatabase db) =>
      db.kitchenTickets.createAlias(
        $_aliasNameGenerator(
          db.kitchenTicketItems.ticketId,
          db.kitchenTickets.id,
        ),
      );

  $$KitchenTicketsTableProcessedTableManager get ticketId {
    final $_column = $_itemColumn<String>('ticket_id')!;

    final manager = $$KitchenTicketsTableTableManager(
      $_db,
      $_db.kitchenTickets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_ticketIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $BanSessionItemsTable _sessionItemIdTable(_$AppDatabase db) =>
      db.banSessionItems.createAlias(
        $_aliasNameGenerator(
          db.kitchenTicketItems.sessionItemId,
          db.banSessionItems.id,
        ),
      );

  $$BanSessionItemsTableProcessedTableManager get sessionItemId {
    final $_column = $_itemColumn<String>('session_item_id')!;

    final manager = $$BanSessionItemsTableTableManager(
      $_db,
      $_db.banSessionItems,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionItemIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$KitchenTicketItemsTableFilterComposer
    extends Composer<_$AppDatabase, $KitchenTicketItemsTable> {
  $$KitchenTicketItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modifiersJson => $composableBuilder(
    column: $table.modifiersJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get freeNote => $composableBuilder(
    column: $table.freeNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kitchenNote => $composableBuilder(
    column: $table.kitchenNote,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get editHistoryJson => $composableBuilder(
    column: $table.editHistoryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stationCode => $composableBuilder(
    column: $table.stationCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnFilters(column),
  );

  $$KitchenTicketsTableFilterComposer get ticketId {
    final $$KitchenTicketsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ticketId,
      referencedTable: $db.kitchenTickets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketsTableFilterComposer(
            $db: $db,
            $table: $db.kitchenTickets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BanSessionItemsTableFilterComposer get sessionItemId {
    final $$BanSessionItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionItemId,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableFilterComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KitchenTicketItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $KitchenTicketItemsTable> {
  $$KitchenTicketItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modifiersJson => $composableBuilder(
    column: $table.modifiersJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get freeNote => $composableBuilder(
    column: $table.freeNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kitchenNote => $composableBuilder(
    column: $table.kitchenNote,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get editHistoryJson => $composableBuilder(
    column: $table.editHistoryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stationCode => $composableBuilder(
    column: $table.stationCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get doneAt => $composableBuilder(
    column: $table.doneAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$KitchenTicketsTableOrderingComposer get ticketId {
    final $$KitchenTicketsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ticketId,
      referencedTable: $db.kitchenTickets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketsTableOrderingComposer(
            $db: $db,
            $table: $db.kitchenTickets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BanSessionItemsTableOrderingComposer get sessionItemId {
    final $$BanSessionItemsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionItemId,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableOrderingComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KitchenTicketItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KitchenTicketItemsTable> {
  $$KitchenTicketItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get productName => $composableBuilder(
    column: $table.productName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<String> get modifiersJson => $composableBuilder(
    column: $table.modifiersJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get freeNote =>
      $composableBuilder(column: $table.freeNote, builder: (column) => column);

  GeneratedColumn<String> get kitchenNote => $composableBuilder(
    column: $table.kitchenNote,
    builder: (column) => column,
  );

  GeneratedColumn<String> get editHistoryJson => $composableBuilder(
    column: $table.editHistoryJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get stationCode => $composableBuilder(
    column: $table.stationCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  $$KitchenTicketsTableAnnotationComposer get ticketId {
    final $$KitchenTicketsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.ticketId,
      referencedTable: $db.kitchenTickets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$KitchenTicketsTableAnnotationComposer(
            $db: $db,
            $table: $db.kitchenTickets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BanSessionItemsTableAnnotationComposer get sessionItemId {
    final $$BanSessionItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionItemId,
      referencedTable: $db.banSessionItems,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BanSessionItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.banSessionItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$KitchenTicketItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $KitchenTicketItemsTable,
          KitchenTicketItem,
          $$KitchenTicketItemsTableFilterComposer,
          $$KitchenTicketItemsTableOrderingComposer,
          $$KitchenTicketItemsTableAnnotationComposer,
          $$KitchenTicketItemsTableCreateCompanionBuilder,
          $$KitchenTicketItemsTableUpdateCompanionBuilder,
          (KitchenTicketItem, $$KitchenTicketItemsTableReferences),
          KitchenTicketItem,
          PrefetchHooks Function({bool ticketId, bool sessionItemId})
        > {
  $$KitchenTicketItemsTableTableManager(
    _$AppDatabase db,
    $KitchenTicketItemsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KitchenTicketItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KitchenTicketItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KitchenTicketItemsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> ticketId = const Value.absent(),
                Value<String> sessionItemId = const Value.absent(),
                Value<String> productName = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<String> modifiersJson = const Value.absent(),
                Value<String?> freeNote = const Value.absent(),
                Value<String?> kitchenNote = const Value.absent(),
                Value<String?> editHistoryJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> stationCode = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KitchenTicketItemsCompanion(
                id: id,
                ticketId: ticketId,
                sessionItemId: sessionItemId,
                productName: productName,
                quantity: quantity,
                modifiersJson: modifiersJson,
                freeNote: freeNote,
                kitchenNote: kitchenNote,
                editHistoryJson: editHistoryJson,
                status: status,
                stationCode: stationCode,
                startedAt: startedAt,
                doneAt: doneAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String ticketId,
                required String sessionItemId,
                required String productName,
                required double quantity,
                Value<String> modifiersJson = const Value.absent(),
                Value<String?> freeNote = const Value.absent(),
                Value<String?> kitchenNote = const Value.absent(),
                Value<String?> editHistoryJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> stationCode = const Value.absent(),
                Value<int?> startedAt = const Value.absent(),
                Value<int?> doneAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KitchenTicketItemsCompanion.insert(
                id: id,
                ticketId: ticketId,
                sessionItemId: sessionItemId,
                productName: productName,
                quantity: quantity,
                modifiersJson: modifiersJson,
                freeNote: freeNote,
                kitchenNote: kitchenNote,
                editHistoryJson: editHistoryJson,
                status: status,
                stationCode: stationCode,
                startedAt: startedAt,
                doneAt: doneAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$KitchenTicketItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({ticketId = false, sessionItemId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (ticketId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.ticketId,
                                referencedTable:
                                    $$KitchenTicketItemsTableReferences
                                        ._ticketIdTable(db),
                                referencedColumn:
                                    $$KitchenTicketItemsTableReferences
                                        ._ticketIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (sessionItemId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sessionItemId,
                                referencedTable:
                                    $$KitchenTicketItemsTableReferences
                                        ._sessionItemIdTable(db),
                                referencedColumn:
                                    $$KitchenTicketItemsTableReferences
                                        ._sessionItemIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$KitchenTicketItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $KitchenTicketItemsTable,
      KitchenTicketItem,
      $$KitchenTicketItemsTableFilterComposer,
      $$KitchenTicketItemsTableOrderingComposer,
      $$KitchenTicketItemsTableAnnotationComposer,
      $$KitchenTicketItemsTableCreateCompanionBuilder,
      $$KitchenTicketItemsTableUpdateCompanionBuilder,
      (KitchenTicketItem, $$KitchenTicketItemsTableReferences),
      KitchenTicketItem,
      PrefetchHooks Function({bool ticketId, bool sessionItemId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ModuleConfigsTableTableManager get moduleConfigs =>
      $$ModuleConfigsTableTableManager(_db, _db.moduleConfigs);
  $$CoreProductsTableTableManager get coreProducts =>
      $$CoreProductsTableTableManager(_db, _db.coreProducts);
  $$CoreCustomersTableTableManager get coreCustomers =>
      $$CoreCustomersTableTableManager(_db, _db.coreCustomers);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
  $$EventsLogTableTableManager get eventsLog =>
      $$EventsLogTableTableManager(_db, _db.eventsLog);
  $$PendingEventsTableTableManager get pendingEvents =>
      $$PendingEventsTableTableManager(_db, _db.pendingEvents);
  $$PosOrdersTableTableManager get posOrders =>
      $$PosOrdersTableTableManager(_db, _db.posOrders);
  $$PosOrderItemsTableTableManager get posOrderItems =>
      $$PosOrderItemsTableTableManager(_db, _db.posOrderItems);
  $$KhoStockMovementsTableTableManager get khoStockMovements =>
      $$KhoStockMovementsTableTableManager(_db, _db.khoStockMovements);
  $$KhoRecipesTableTableManager get khoRecipes =>
      $$KhoRecipesTableTableManager(_db, _db.khoRecipes);
  $$KhoRecipeItemsTableTableManager get khoRecipeItems =>
      $$KhoRecipeItemsTableTableManager(_db, _db.khoRecipeItems);
  $$KhoSuppliersTableTableManager get khoSuppliers =>
      $$KhoSuppliersTableTableManager(_db, _db.khoSuppliers);
  $$KhoPurchaseOrdersTableTableManager get khoPurchaseOrders =>
      $$KhoPurchaseOrdersTableTableManager(_db, _db.khoPurchaseOrders);
  $$KhoPurchaseItemsTableTableManager get khoPurchaseItems =>
      $$KhoPurchaseItemsTableTableManager(_db, _db.khoPurchaseItems);
  $$FinanceCategoriesTableTableManager get financeCategories =>
      $$FinanceCategoriesTableTableManager(_db, _db.financeCategories);
  $$FinanceRecordsTableTableManager get financeRecords =>
      $$FinanceRecordsTableTableManager(_db, _db.financeRecords);
  $$LoyaltyTransactionsTableTableManager get loyaltyTransactions =>
      $$LoyaltyTransactionsTableTableManager(_db, _db.loyaltyTransactions);
  $$LoyaltyRewardsTableTableManager get loyaltyRewards =>
      $$LoyaltyRewardsTableTableManager(_db, _db.loyaltyRewards);
  $$BanZonesTableTableManager get banZones =>
      $$BanZonesTableTableManager(_db, _db.banZones);
  $$BanDiningTablesTableTableManager get banDiningTables =>
      $$BanDiningTablesTableTableManager(_db, _db.banDiningTables);
  $$BanSessionsTableTableManager get banSessions =>
      $$BanSessionsTableTableManager(_db, _db.banSessions);
  $$BanSessionItemsTableTableManager get banSessionItems =>
      $$BanSessionItemsTableTableManager(_db, _db.banSessionItems);
  $$KitchenStationsTableTableManager get kitchenStations =>
      $$KitchenStationsTableTableManager(_db, _db.kitchenStations);
  $$ProductModifiersTableTableManager get productModifiers =>
      $$ProductModifiersTableTableManager(_db, _db.productModifiers);
  $$SessionItemModifiersTableTableManager get sessionItemModifiers =>
      $$SessionItemModifiersTableTableManager(_db, _db.sessionItemModifiers);
  $$KitchenTicketsTableTableManager get kitchenTickets =>
      $$KitchenTicketsTableTableManager(_db, _db.kitchenTickets);
  $$KitchenTicketItemsTableTableManager get kitchenTicketItems =>
      $$KitchenTicketItemsTableTableManager(_db, _db.kitchenTicketItems);
}
