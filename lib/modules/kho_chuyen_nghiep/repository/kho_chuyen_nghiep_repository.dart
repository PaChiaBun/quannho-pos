import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/repositories/core_product_repository.dart';
import '../../../core/utils/quantity_formatter.dart';
import '../../../core/utils/server_time.dart';
import '../../../core/utils/chain_compare.dart' show ymd;

// ─────────────────────────────────────────────────────────────────────────────
// MODELS & REPOSITORY — Kho Hàng Chuyên Nghiệp
// ─────────────────────────────────────────────────────────────────────────────

class RecipeIngredientModel {
  final String id;
  final String recipeId;
  final String? ingredientId;   // FK mềm → products.id
  final String? subRecipeId;    // FK mềm → recipes.id (lồng nhau)
  final double quantity;
  final String unit;
  final String? note;
  final int sortOrder;

  /// Tỷ lệ sử dụng được sau sơ chế (0.0–1.0).
  /// VD: rau 20% hao phí → yieldFactor = 0.8
  /// Số lượng thực tế trừ kho = quantity / yieldFactor
  final double yieldFactor;

  // Snapshot fields (populated at read time)
  final String? ingredientName;

  /// Giá vốn theo ĐƠN VỊ KHO của nguyên liệu (VD: 50.000đ/gói, 55.000đ/kg).
  /// Giá cho 1 đơn vị công thức được suy ra qua [costPerRecipeUnit].
  final double? ingredientCostLatest;
  final String productUnit;        // đơn vị kho
  final double conversionRate;     // quy cách: 1 [productUnit] = N [conversionUnit]
  final String conversionUnit;

  const RecipeIngredientModel({
    required this.id,
    required this.recipeId,
    this.ingredientId,
    this.subRecipeId,
    required this.quantity,
    required this.unit,
    this.note,
    this.sortOrder = 0,
    this.yieldFactor = 1.0,
    this.ingredientName,
    this.ingredientCostLatest,
    this.productUnit = '',
    this.conversionRate = 0,
    this.conversionUnit = '',
  });

  /// % hao phí để hiển thị trên UI (VD: 0.8 → 20.0)
  double get wastePct => ((1.0 - yieldFactor) * 100).roundToDouble();

  /// Số lượng thực tế cần lấy từ kho (đã tính hao phí)
  double get actualQuantity => yieldFactor > 0 ? quantity / yieldFactor : quantity;

  /// Giá vốn của 1 đơn vị công thức (đã quy đổi theo đơn vị kho + quy cách).
  double get costPerRecipeUnit => recipeUnitCost(
        costPerStockUnit: ingredientCostLatest ?? 0,
        recipeUnit: unit,
        productUnit: productUnit.isEmpty ? unit : productUnit,
        conversionRate: conversionRate,
        conversionUnit: conversionUnit,
      );

  /// Chi phí 1 dòng nguyên liệu — quy đổi đơn vị như trừ kho + tính hao phí
  double get lineCost => costPerRecipeUnit * actualQuantity;

  factory RecipeIngredientModel.fromMap(Map<String, dynamic> m) =>
      RecipeIngredientModel(
        id:            m['id'] as String,
        recipeId:      m['recipe_id'] as String,
        ingredientId:  m['ingredient_id'] as String?,
        subRecipeId:   m['sub_recipe_id'] as String?,
        quantity:      (m['quantity'] as num).toDouble(),
        unit:          m['unit'] as String,
        note:          m['note'] as String?,
        sortOrder:     (m['sort_order'] as int?) ?? 0,
        yieldFactor:   (m['yield_factor'] as num?)?.toDouble() ?? 1.0,
      );

  Map<String, dynamic> toInsertMap(String recipeId) => {
    'id':            id,
    'recipe_id':     recipeId,
    'ingredient_id': ingredientId,
    'sub_recipe_id': subRecipeId,
    'quantity':      quantity,
    'unit':          unit,
    'note':          note,
    'sort_order':    sortOrder,
    'yield_factor':  yieldFactor,
  };
}

class RecipeModel {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final String? category;
  final double servingSize;
  final String servingUnit;
  final String? posProductId;   // FK mềm → products.id (POS item)
  final String? imageUrl;
  final bool isActive;
  final String createdAt;
  final List<RecipeIngredientModel> ingredients;

  const RecipeModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    this.category,
    required this.servingSize,
    this.servingUnit = 'phần',
    this.posProductId,
    this.imageUrl,
    this.isActive = true,
    required this.createdAt,
    this.ingredients = const [],
  });

  double get costPerServing =>
      ingredients.fold(0.0, (sum, i) => sum + i.lineCost);

  factory RecipeModel.fromMap(Map<String, dynamic> m) => RecipeModel(
    id:           m['id'] as String,
    storeId:      m['store_id'] as String,
    name:         m['name'] as String,
    description:  m['description'] as String?,
    category:     m['category'] as String?,
    servingSize:  (m['serving_size'] as num?)?.toDouble() ?? 1,
    servingUnit:  m['serving_unit'] as String? ?? 'phần',
    posProductId: m['pos_product_id'] as String?,
    imageUrl:     m['image_url'] as String?,
    isActive:     m['is_active'] as bool? ?? true,
    createdAt:    m['created_at'] as String? ?? '',
    ingredients:  (m['__ingredients'] as List<RecipeIngredientModel>?) ?? [],
  );
}

class ProductionOrderModel {
  final String id;
  final String storeId;
  final String recipeId;
  final String recipeName;
  final double quantity;
  final String status;   // pending / in_progress / done / cancelled
  final String scheduledDate;
  final String? note;
  final String? completedAt;
  final String createdAt;

  const ProductionOrderModel({
    required this.id,
    required this.storeId,
    required this.recipeId,
    required this.recipeName,
    required this.quantity,
    required this.status,
    required this.scheduledDate,
    this.note,
    this.completedAt,
    required this.createdAt,
  });

  bool get isPending   => status == 'pending';
  bool get isCompleted => status == 'done';

  factory ProductionOrderModel.fromMap(Map<String, dynamic> m) =>
      ProductionOrderModel(
        id:            m['id'] as String,
        storeId:       m['store_id'] as String,
        recipeId:      m['recipe_id'] as String,
        recipeName:    m['recipe_name'] as String,
        quantity:      (m['quantity'] as num).toDouble(),
        status:        m['status'] as String? ?? 'pending',
        scheduledDate: m['scheduled_date'] as String,
        note:          m['note'] as String?,
        completedAt:   m['completed_at'] as String?,
        createdAt:     m['created_at'] as String? ?? '',
      );
}

class StockWarning {
  final String ingredientId;
  final String ingredientName;
  final double required;
  final double available;
  final String unit;

  const StockWarning({
    required this.ingredientId,
    required this.ingredientName,
    required this.required,
    required this.available,
    required this.unit,
  });

  double get shortage => required - available;
  bool get isShortage => available < required;
}

// ─────────────────────────────────────────────────────────────────────────────
// KHO PRO REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

class KhoProRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final CoreProductRepository _productRepo;
  final _uuid = const Uuid();

  KhoProRepository(this._productRepo);

  // ── Helper ────────────────────────────────────────────────────────────────
  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECIPES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<RecipeModel>> fetchRecipes() async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    // 1. Fetch recipes
    final recipeRows = await _sb
        .from('recipes')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false)
        .order('created_at', ascending: false);

    if ((recipeRows as List).isEmpty) return [];

    // 2. Fetch all ingredients for these recipes
    final recipeIds = recipeRows.map((r) => (r as Map)['id'] as String).toList();
    final ingRows = await _sb
        .from('recipe_ingredients')
        .select()
        .inFilter('recipe_id', recipeIds)
        .order('sort_order');

    // 3. Fetch ingredient details (products table) for cost
    final ingredientIds = (ingRows as List)
        .map((r) => (r as Map)['ingredient_id'] as String?)
        .whereType<String>()
        .toSet()
        .toList();

    Map<String, Map<String, dynamic>> productMap = {};
    if (ingredientIds.isNotEmpty) {
      final prodRows = await _sb
          .from('products')
          .select('id, name, cost_price_latest, cost_price, unit, conversion_rate, conversion_unit')
          .inFilter('id', ingredientIds);
      for (final row in (prodRows as List)) {
        final r = row as Map<String, dynamic>;
        productMap[r['id'] as String] = r;
      }
    }

    // 4. Build ingredient models with cost snapshots
    final ingByRecipe = <String, List<RecipeIngredientModel>>{};
    for (final row in ingRows) {
      final r = row as Map<String, dynamic>;
      final recipeId = r['recipe_id'] as String;
      final ingId = r['ingredient_id'] as String?;
      final prodData = ingId != null ? productMap[ingId] : null;

      ingByRecipe.putIfAbsent(recipeId, () => []).add(
        RecipeIngredientModel(
          id:                    r['id'] as String,
          recipeId:              recipeId,
          ingredientId:          ingId,
          subRecipeId:           r['sub_recipe_id'] as String?,
          quantity:              (r['quantity'] as num).toDouble(),
          unit:                  r['unit'] as String,
          note:                  r['note'] as String?,
          sortOrder:             (r['sort_order'] as int?) ?? 0,
          yieldFactor:           (r['yield_factor'] as num?)?.toDouble() ?? 1.0,  // ← FIX: đọc từ DB
          ingredientName:        prodData?['name'] as String?,
          // Giá vốn theo đơn vị kho; quy đổi sang đơn vị công thức nằm ở RecipeIngredientModel
          ingredientCostLatest: effectiveUnitCost(
            (prodData?['cost_price_latest'] as num?) ?? 0,
            (prodData?['cost_price'] as num?) ?? 0,
          ),
          productUnit:    (prodData?['unit'] as String?) ?? '',
          conversionRate: (prodData?['conversion_rate'] as num?)?.toDouble() ?? 0,
          conversionUnit: (prodData?['conversion_unit'] as String?) ?? '',
        ),
      );

    }

    // 5. Assemble final models
    return recipeRows.map((row) {
      final r = row as Map<String, dynamic>;
      final id = r['id'] as String;
      return RecipeModel.fromMap(
          {...r, '__ingredients': ingByRecipe[id] ?? <RecipeIngredientModel>[]});
    }).toList();
  }

  Future<RecipeModel?> fetchRecipeById(String recipeId) async {
    final rows = await fetchRecipes();
    try {
      return rows.firstWhere((r) => r.id == recipeId);
    } catch (_) {
      return null;
    }
  }

  /// Lấy công thức có đầy đủ ingredients theo pos_product_id
  /// QUAN TRỌNG: phải dùng fetchRecipes() thay vì query thẳng
  /// vì recipe cần join recipe_ingredients để có ingredients list
  Future<RecipeModel?> fetchRecipeByPosProductId(String posProductId) async {
    final all = await fetchRecipes();
    try {
      return all.firstWhere((r) => r.posProductId == posProductId);
    } catch (_) {
      return null; // không tìm thấy công thức nào gắn với sản phẩm này
    }
  }

  Future<String> createRecipe({
    required String name,
    String? description,
    String? category,
    double servingSize = 1,
    String servingUnit = 'phần',
    String? posProductId,
    String? imageUrl,
    required List<RecipeIngredientModel> ingredients,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    final id  = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();

    await _sb.from('recipes').insert({
      'id':             id,
      'store_id':       storeId,
      'name':           name,
      'description':    description,
      'category':       category,
      'serving_size':   servingSize,
      'serving_unit':   servingUnit,
      'pos_product_id': posProductId,
      'image_url':      imageUrl,
      'created_at':     now,
      'updated_at':     now,
    });

    await _saveIngredients(id, ingredients);
    return id;
  }

  Future<void> updateRecipe(String id, {
    String? name,
    String? description,
    String? category,
    double? servingSize,
    String? servingUnit,
    String? posProductId,
    String? imageUrl,
    List<RecipeIngredientModel>? ingredients,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (name != null)          updates['name']           = name;
    if (description != null)   updates['description']    = description;
    if (category != null)      updates['category']       = category;
    if (servingSize != null)   updates['serving_size']   = servingSize;
    if (servingUnit != null)   updates['serving_unit']   = servingUnit;
    // FIX: luôn ghi pos_product_id — kể cả null (để xoá liên kết POS)
    // Bug cũ: `if (posProductId != null)` → recipe tạo không có POS link không bao giờ được gắn
    updates['pos_product_id'] = posProductId;
    if (imageUrl != null)      updates['image_url']      = imageUrl;

    await _sb.from('recipes').update(updates).eq('id', id);
    if (ingredients != null) await _saveIngredients(id, ingredients);
  }

  Future<void> deleteRecipe(String id) async {
    await _sb.from('recipes')
        .update({'is_deleted': true, 'is_active': false})
        .eq('id', id);
  }

  Future<void> _saveIngredients(
      String recipeId, List<RecipeIngredientModel> ingredients) async {
    try {
      await _sb.from('recipe_ingredients').delete().eq('recipe_id', recipeId);
      if (ingredients.isEmpty) return;
      final rows = ingredients
          .asMap()
          .entries
          .map((e) => e.value.toInsertMap(recipeId)
            ..['id'] = _uuid.v4()
            ..['sort_order'] = e.key)
          .toList();
      await _sb.from('recipe_ingredients').insert(rows);
    } catch (e, st) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STOCK CHECK & DEDUCTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Chuyển đổi số lượng từ đơn vị công thức sang đơn vị sản phẩm.
  /// Public — dùng bởi POS cancelOrder để reverse deductIngredients
  double convertToProductUnit(
    double qty,
    String recipeUnit,
    String productUnit, {
    double conversionRate = 0,
    String conversionUnit = '',
  }) {
    return _convertToProductUnit(qty, recipeUnit, productUnit,
        conversionRate: conversionRate, conversionUnit: conversionUnit);
  }

  /// Dùng chung một bộ quy đổi với trừ kho khi bán (khớp hàm SQL convert_recipe_ingredient_qty_v1).
  double _convertToProductUnit(
    double qty,
    String recipeUnit,
    String productUnit, {
    double conversionRate = 0,
    String conversionUnit = '',
  }) =>
      convertRecipeIngredientQty(
        qty,
        recipeUnit,
        productUnit,
        conversionRate: conversionRate,
        conversionUnit: conversionUnit,
      );

  /// Kiểm tra tồn kho đủ nấu bao nhiêu phần
  Future<double> getMaxServings(RecipeModel recipe) async {
    final storeId = await _storeId();
    if (storeId == null || recipe.ingredients.isEmpty) return 0;

    final ingIds = recipe.ingredients
        .where((i) => i.ingredientId != null)
        .map((i) => i.ingredientId!)
        .toList();
    if (ingIds.isEmpty) return 0;

    // Fetch stock_qty + unit của sản phẩm
    final stockRows = await _sb
        .from('products')
        .select('id, stock_qty, unit, conversion_rate, conversion_unit')
        .eq('store_id', storeId)
        .inFilter('id', ingIds);

    final stockMap = <String, Map<String, dynamic>>{};
    for (final row in (stockRows as List)) {
      final r = row as Map<String, dynamic>;
      stockMap[r['id'] as String] = r;
    }

    double maxServings = double.infinity;
    for (final ing in recipe.ingredients.where((i) => i.ingredientId != null)) {
      final data = stockMap[ing.ingredientId];
      final available = (data?['stock_qty'] as num?)?.toDouble() ?? 0;
      final prodUnit  = data?['unit'] as String? ?? ing.unit;
      if (ing.quantity <= 0) continue;
      // Đổi actualQuantity/serving sang đơn vị sản phẩm (có tính hao phí)
      final qtyPerServing = _convertToProductUnit(
        ing.actualQuantity, ing.unit, prodUnit,
        conversionRate: (data?['conversion_rate'] as num?)?.toDouble() ?? 0,
        conversionUnit: data?['conversion_unit'] as String? ?? '',
      );
      final servings = qtyPerServing > 0 ? available / qtyPerServing : double.infinity;
      if (servings < maxServings) maxServings = servings;
    }
    return maxServings == double.infinity ? 0 : maxServings;
  }

  /// Kiểm tra cảnh báo khi tạo lệnh sản xuất
  Future<List<StockWarning>> checkStock(RecipeModel recipe, double qty) async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    final ingIds = recipe.ingredients
        .where((i) => i.ingredientId != null)
        .map((i) => i.ingredientId!)
        .toList();
    if (ingIds.isEmpty) return [];

    final stockRows = await _sb
        .from('products')
        .select('id, name, stock_qty, unit, conversion_rate, conversion_unit')
        .eq('store_id', storeId)
        .inFilter('id', ingIds);

    final stockMap = <String, Map<String, dynamic>>{};
    for (final row in (stockRows as List)) {
      final r = row as Map<String, dynamic>;
      stockMap[r['id'] as String] = r;
    }

    final warnings = <StockWarning>[];
    for (final ing in recipe.ingredients.where((i) => i.ingredientId != null)) {
      final stockData = stockMap[ing.ingredientId];
      final prodUnit  = stockData?['unit'] as String? ?? ing.unit;
      final available = (stockData?['stock_qty'] as num?)?.toDouble() ?? 0;

      // Tính số lượng cần: actualQuantity đã tính hao phí (÷ yieldFactor)
      final neededInProdUnit = _convertToProductUnit(
        ing.actualQuantity * qty, ing.unit, prodUnit,
        conversionRate: (stockData?['conversion_rate'] as num?)?.toDouble() ?? 0,
        conversionUnit: stockData?['conversion_unit'] as String? ?? '',
      );

      if (available < neededInProdUnit) {
        warnings.add(StockWarning(
          ingredientId:   ing.ingredientId!,
          ingredientName: ing.ingredientName ?? stockData?['name'] as String? ?? '?',
          required:       neededInProdUnit,
          available:      available,
          unit:           prodUnit,
        ));
      }
    }
    return warnings;
  }

  /// Trừ kho theo công thức (gọi khi bán POS hoặc hoàn thành lệnh sản xuất)
  /// Đồng thời ghi finance_record expense cho COGS (silent fail)
  Future<void> deductIngredients({
    required RecipeModel recipe,
    required double quantity,   // số phần
    String reason = 'recipe_usage',
    String? note,
    String? referenceId,        // orderId — để trace về đơn hàng
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    final now = DateTime.now().toUtc().toIso8601String();

    // Fetch đơn vị + giá vốn để quy đổi và tính COGS
    final ingIds = recipe.ingredients
        .where((i) => i.ingredientId != null)
        .map((i) => i.ingredientId!)
        .toList();
    final productRows = ingIds.isEmpty ? [] : (await _sb
        .from('products')
        .select('id, unit, cost_price_latest, cost_price, conversion_rate, conversion_unit')
        .inFilter('id', ingIds)) as List;
    final unitMap      = <String, String>{};
    final costPriceMap = <String, double>{};
    final convRateMap  = <String, double>{};
    final convUnitMap  = <String, String>{};
    for (final row in productRows) {
      final r = row as Map<String, dynamic>;
      final id = r['id'] as String;
      final prodUnit = r['unit'] as String? ?? 'gram';
      unitMap[id] = prodUnit;
      convRateMap[id] = (r['conversion_rate'] as num?)?.toDouble() ?? 0;
      convUnitMap[id] = r['conversion_unit'] as String? ?? '';
      // Ưu tiên cost_price_latest nếu > 0, fallback về cost_price
      costPriceMap[id] = effectiveUnitCost(
        (r['cost_price_latest'] as num?) ?? 0,
        (r['cost_price'] as num?) ?? 0,
      ); // giá theo đơn vị kho
    }

    double totalCogs = 0;

    for (final ing in recipe.ingredients) {
      if (ing.ingredientId == null) continue;
      final prodUnit = unitMap[ing.ingredientId] ?? ing.unit;

      // Số lượng thực tế cần lấy từ kho = quantity (phần) × actualQuantity/phần
      // actualQuantity đã tính hao phí: quantity / yieldFactor
      final actualPerBatch = ing.actualQuantity * quantity;

      // Quy đổi sang đơn vị sản phẩm (kg/lít/lon/hộp...)
      final stockDelta = _convertToProductUnit(
        actualPerBatch,
        ing.unit,
        prodUnit,
        conversionRate: convRateMap[ing.ingredientId] ?? 0,
        conversionUnit: convUnitMap[ing.ingredientId] ?? '',
      );

      // Ghi stock_movement — delta âm (xuất kho), giữ precision 3 chữ số
      final wasteNote = ing.yieldFactor < 1.0
          ? ' (hao phí ${ing.wastePct.toInt()}%)'
          : '';
      final deltaVal = double.parse((-stockDelta).toStringAsFixed(3));

      // Trừ stock_qty — thực hiện trước, không block nếu log fail
      try {
        await _productRepo.updateStockQty(ing.ingredientId!, -stockDelta);
      } catch (e) {
        debugPrint('[KhoCN] ❌ updateStockQty err: ${ing.ingredientId} $e');
      }

      // Ghi stock_movement log — silent fail
      try {
        await _sb.from('stock_movements').insert({
          'id':         _uuid.v4(),
          'store_id':   storeId,
          'product_id': ing.ingredientId,
          'delta':      deltaVal,
          'reason':     reason,
          'note':       note ?? 'Công thức: ${recipe.name} × $quantity phần$wasteNote',
          'created_at': now,
        });
      } catch (e) {
        debugPrint('[KhoCN] ⚠️ stock_movements log err: $e');
      }

      // Cộng dồn COGS
      final unitCost = costPriceMap[ing.ingredientId] ?? 0;
      if (unitCost > 0) totalCogs += stockDelta * unitCost;
    }

    // KHÔNG ghi "Giá vốn NL" vào Thu Chi (23/10/2026): tiền nguyên liệu đã ghi chi một lần lúc
    // nhập hàng; ghi thêm khi dùng/huỷ/sản xuất là trừ lợi nhuận hai lần. Hao hụt vẫn nằm ở
    // stock_movements (reason 'loss'/'production'/'sale') để xem trong Kho.
    debugPrint(
        '[KhoCN] deductIngredients: giá trị NL đã dùng ≈ ${totalCogs.toStringAsFixed(0)}đ (không ghi Thu Chi)');
  }



  // ═══════════════════════════════════════════════════════════════════════════
  // PRODUCTION ORDERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<ProductionOrderModel>> fetchProductionOrders({
    DateTime? date,
    DateTime? from,
    DateTime? to,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    var query = _sb
        .from('production_orders')
        .select()
        .eq('store_id', storeId);

    // Filter theo ng\u00e0y c\u1ee5 th\u1ec3 (ProductionOrderScreen)
    if (date != null) {
      final dateStr = date.toIso8601String().substring(0, 10);
      query = query.eq('scheduled_date', dateStr);
    }
    // Filter theo khoảng ngày (Báo cáo) — so sánh scheduled_date (text yyyy-MM-dd)
    if (from != null) {
      query = query.gte('scheduled_date', from.toIso8601String().substring(0, 10));
    }
    if (to != null) {
      // ‼️ FIX: dùng lt (exclusive) thay vì lte (inclusive) — nhất quán với toàn hệ thống
      // to được gọi với midnight ngày tiếp theo từ caller (report screen)
      query = query.lt('scheduled_date', to.toIso8601String().substring(0, 10));
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .map((r) => ProductionOrderModel.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<String> createProductionOrder({
    required String recipeId,
    required String recipeName,
    required double quantity,
    required DateTime scheduledDate,
    String? note,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    final id = _uuid.v4();
    await _sb.from('production_orders').insert({
      'id':             id,
      'store_id':       storeId,
      'recipe_id':      recipeId,
      'recipe_name':    recipeName,
      'quantity':       quantity,
      'status':         'pending',
      'scheduled_date': scheduledDate.toIso8601String().substring(0, 10),
      'note':           note,
      'created_at':     DateTime.now().toUtc().toIso8601String(),
    });
    return id;
  }

  Future<void> updateProductionStatus(String id, String status) async {
    final updates = <String, dynamic>{'status': status};
    if (status == 'done') {
      updates['completed_at'] = DateTime.now().toUtc().toIso8601String();
    }
    await _sb.from('production_orders').update(updates).eq('id', id);
  }

  /// Hủy lệnh sản xuất (pending / in_progress) — KHÔNG trừ kho
  Future<void> cancelProductionOrder(String id) async {
    await _sb.from('production_orders').update({
      'status': 'cancelled',
    }).eq('id', id);
  }

  /// Hoàn thành lệnh sản xuất: server trừ nguyên liệu + CỘNG thành phẩm vào kho nguyên tử
  /// (RPC `complete_production_order_v1`, migration FIX 11). Trả về mô tả kết quả để hiển thị,
  /// hoặc null nếu lệnh đã hoàn thành trước đó.
  Future<String?> completeProductionOrder(
      ProductionOrderModel order, RecipeModel recipe) async {
    try {
      final res = await _sb.rpc('complete_production_order_v1',
          params: {'p_order_id': order.id});
      if (res is Map && res['success'] == true) {
        if (res['already_completed'] == true) return null;
        final outQty = (res['output_qty'] as num?)?.toDouble() ?? 0;
        if (outQty > 0) {
          return 'Đã nhập ${fmtQty(outQty)} ${res['output_unit'] ?? ''} ${res['output_name'] ?? ''} vào kho';
        }
        return 'Đã trừ nguyên liệu theo công thức';
      }
      throw Exception(
          (res is Map ? res['message'] : null) ?? 'Không hoàn thành được lệnh sản xuất');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || e.message.contains('Could not find the function')) {
        // Server chưa có FIX 11 → cách cũ (chỉ trừ nguyên liệu, KHÔNG cộng thành phẩm)
        await _completeProductionOrderLegacy(order, recipe);
        return 'Máy chủ chưa cập nhật (FIX 11): chỉ trừ nguyên liệu, chưa cộng thành phẩm vào kho';
      }
      rethrow;
    }
  }

  Future<void> _completeProductionOrderLegacy(
      ProductionOrderModel order, RecipeModel recipe) async {
    // ‼️ FIX: Guard idempotency — tránh double-deduct nếu double-click hoặc retry
    if (order.status == 'done') {
      debugPrint('[KhoCN] completeProductionOrder: order ${order.id} đã done, bỏ qua');
      return;
    }
    // 1. Trừ kho
    await deductIngredients(
      recipe:   recipe,
      quantity: order.quantity,
      reason:   'production',
      note:     'Lệnh SX: ${order.recipeName} × ${order.quantity} phần',
    );

    // 2. Log tiêu thụ nguyên liệu — ‼️ FIX Bug #45: wrap try/catch
    // Kho đã bị trừ ở bước 1 → nếu log fail mà không catch → order stuck 'in_progress'
    // kho trừ rồi nhưng status không chuyển 'done' → data inconsistency
    try {
      final storeId = await _storeId(); // ‼️ FIX: resolve scope sau refactor Bug #45
      final now = DateTime.now().toUtc().toIso8601String();
      if (storeId != null) {
        for (final ing in recipe.ingredients) {
          if (ing.ingredientId == null) continue;
          // actualQuantity = quantity / yieldFactor — lượng thực tế lấy từ kho (có hao phí)
          final actualUsed = ing.actualQuantity * order.quantity;
          // Chi phí thực: giá 1 đơn vị công thức (đã quy đổi kho + quy cách) × lượng thực dùng
          final unitCost  = ing.costPerRecipeUnit;
          final totalCost = unitCost * actualUsed;
          await _sb.from('production_logs').insert({
            'id':                   const Uuid().v4(),
            'production_order_id':  order.id,
            'store_id':             storeId,
            'ingredient_id':        ing.ingredientId,
            'ingredient_name':      ing.ingredientName ?? '',
            'qty_used':             actualUsed,
            'unit':                 ing.unit,
            'cost_at_time':         unitCost,
            'total_cost':           totalCost,
            'created_at':           now,
          });
        }
      }
    } catch (e) {
      debugPrint('[KhoCN] ⚠️ production_logs insert failed: $e — tiếp tục mark done');
    }

    // 3. Mark done
    await updateProductionStatus(order.id, 'done');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYTICS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Food cost tổng hợp theo ngày
  Future<Map<String, double>> getFoodCostByDate({
    required DateTime from,
    required DateTime to,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return {};

    final rows = await _sb
        .from('production_logs')
        .select('total_cost, created_at')
        .eq('store_id', storeId)
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String()); // exclusive upper — nhất quán với finance


    final result = <String, double>{};
    for (final row in (rows as List)) {
      final r    = row as Map<String, dynamic>;
      // Gom theo ngày Việt Nam — cắt chuỗi UTC thì sản xuất 00:00–06:59 bị tính sang hôm trước.
      final date = ymd(parseServerTime(r['created_at'] as String?) ?? DateTime.now());
      result[date] = (result[date] ?? 0) + ((r['total_cost'] as num?)?.toDouble() ?? 0);
    }
    return result;
  }

  /// Nguyên liệu tiêu thụ trong khoảng thời gian
  Future<List<Map<String, dynamic>>> getIngredientConsumption({
    required DateTime from,
    required DateTime to,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return [];

    final rows = await _sb
        .from('production_logs')
        .select('ingredient_id, ingredient_name, qty_used, unit, total_cost')
        .eq('store_id', storeId)
        .gte('created_at', from.toUtc().toIso8601String())
        .lt('created_at', to.toUtc().toIso8601String()); // exclusive upper — nhất quán với finance


    // Aggregate by ingredient
    final agg = <String, Map<String, dynamic>>{};
    for (final row in (rows as List)) {
      final r   = row as Map<String, dynamic>;
      final id  = r['ingredient_id'] as String? ?? '?';
      if (!agg.containsKey(id)) {
        agg[id] = {
          'ingredient_id':   id,
          'ingredient_name': r['ingredient_name'],
          'unit':            r['unit'],
          'total_qty':       0.0,
          'total_cost':      0.0,
        };
      }
      agg[id]!['total_qty'] += (r['qty_used'] as num?)?.toDouble() ?? 0;
      agg[id]!['total_cost'] += (r['total_cost'] as num?)?.toDouble() ?? 0;
    }
    return agg.values.toList()
      ..sort((a, b) => (b['total_cost'] as double)
          .compareTo(a['total_cost'] as double));
  }

  // ── Update cost_price_latest khi nhập hàng ────────────────────────────────
  /// Gọi sau khi createPurchaseOrder để cập nhật giá vốn mới nhất
  Future<void> updateCostPriceLatest(String productId, double newCost) async {
    await _sb
        .from('products')
        .update({'cost_price_latest': newCost})
        .eq('id', productId);
  }

  // ── Profit Margin ─────────────────────────────────────────────────────────
  /// Trả về map posProductId → sell_price cho tất cả sản phẩm POS
  /// Dùng để tính margin % cho công thức đã gắn POS
  Future<Map<String, double>> fetchSellPriceMap(List<String> posProductIds) async {
    if (posProductIds.isEmpty) return {};
    final storeId = await _storeId();
    if (storeId == null) return {};
    try {
      final rows = await _sb
          .from('products')
          .select('id, sell_price')
          .eq('store_id', storeId)
          .inFilter('id', posProductIds);
      return {
        for (final r in rows)
          (r['id'] as String): (r['sell_price'] as num?)?.toDouble() ?? 0,
      };
    } catch (e) {
      debugPrint('[KhoPro] fetchSellPriceMap error: $e');
      return {};
    }
  }

  // ── Nhập kho nhanh từ Kho CN ──────────────────────────────────────────────
  /// Nhập nhanh 1 nguyên liệu: cộng stock + update cost_price_latest + ghi stock_movement
  Future<void> quickReceiveStock({
    required String productId,
    required String productName,
    required double qty,
    required double unitCost,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    if (qty <= 0) throw Exception('Số lượng phải > 0');
    final now        = DateTime.now().toUtc().toIso8601String();
    final movementId = const Uuid().v4(); // FIX: lưu lại để dùng reference_id

    // 1. Ghi stock_movement — delta là numeric(12,3)
    await _sb.from('stock_movements').insert({
      'id':         movementId,
      'store_id':   storeId,
      'product_id': productId,
      'delta':      double.parse(qty.toStringAsFixed(3)),
      'reason':     'quick_receive',
      'note':       'Nhập nhanh từ Kho CN: $productName',
      'created_at': now,
    });

    // 2. Cộng stock_qty
    await _productRepo.updateStockQty(productId, qty);

    // 3. Cập nhật cost_price_latest
    if (unitCost > 0) {
      await _sb.from('products')
          .update({'cost_price_latest': unitCost})
          .eq('id', productId);
    }

    // 4. Finance record (silent fail)
    try {
      final total = qty * unitCost;
      if (total > 0) {
        await _sb.from('finance_records').insert({
          'id':          const Uuid().v4(),
          'store_id':    storeId,
          'type':        'expense',
          'amount':      total,
          'description':  'Nhập nhanh: $productName (${qty.toStringAsFixed(0)} × ${unitCost.toStringAsFixed(0)}đ)',
          'reference_id': movementId, // FIX: audit trail → stock_movements.id
          'is_auto':      true,
          'recorded_at':  now,
        });
      }
    } catch (e) {
      debugPrint('[KhoPro] quickReceiveStock finance error: $e');
    }
  }

  // ── Production Logs ────────────────────────────────────────────────────────
  /// Lấy lịch sử tiêu thụ nguyên liệu theo khoảng ngày hoặc theo orderId
  Future<List<Map<String, dynamic>>> fetchProductionLogs({
    String? orderId,
    DateTime? from,
    DateTime? to,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    // Build filter chain trước khi gọi .order() (tránh chạm PostgrestTransformBuilder)
    var q = _sb
        .from('production_logs')
        .select('*, products(name, unit)')
        .eq('store_id', storeId);
    if (orderId != null) q = q.eq('production_order_id', orderId);
    if (from != null) {
      q = q.gte('created_at',
          DateTime(from.year, from.month, from.day).toUtc().toIso8601String());
    }
    if (to != null) {
      q = q.lt('created_at',
          DateTime(to.year, to.month, to.day + 1).toUtc().toIso8601String());
    }
    final rows = await q.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ── Stock Count / Kiểm kê kho ─────────────────────────────────────────────
  /// Tạo phiên kiểm kê kho (draft) — trả về countId
  Future<String> createStockCount({String? note, String? countedBy}) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final countId = const Uuid().v4();
    await _sb.from('stock_counts').insert({
      'id':         countId,
      'store_id':   storeId,
      'status':     'draft',
      'note':       note,
      'counted_by': countedBy,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    return countId;
  }

  /// Lưu items kiểm kê (upsert)
  Future<void> saveStockCountItems(
      String countId, List<Map<String, dynamic>> items) async {
    final storeId = await _storeId();
    if (storeId == null) return;
    if (items.isEmpty) return;
    // ‼️ FIX ISSUE #9: batch upsert 1 lần thay vì N lần individual
    final rows = items.map((item) => {
      ...item,
      'count_id': countId,
      'store_id': storeId,
      'id': item['id'] ?? const Uuid().v4(),
    }).toList();
    await _sb.from('stock_count_items').upsert(rows);
  }

  /// Xác nhận kiểm kê: server áp CHÊNH LỆCH (đếm - sổ sách lúc đếm) lên tồn hiện tại,
  /// nguyên tử và idempotent (RPC `confirm_stock_count_v1`, migration FIX 10).
  /// Trả về số sản phẩm đã điều chỉnh.
  Future<int> confirmStockCount(String countId) async {
    try {
      final res = await _sb.rpc('confirm_stock_count_v1', params: {'p_count_id': countId});
      if (res is Map && res['success'] == true) {
        return (res['changed'] as num?)?.toInt() ?? 0;
      }
      final msg = (res is Map ? res['message'] : null) ?? 'Không xác nhận được kiểm kê';
      throw Exception(msg);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || (e.message).contains('Could not find the function')) {
        throw Exception('Máy chủ chưa được cập nhật tính năng kiểm kê (cần chạy migration FIX 10).');
      }
      rethrow;
    }
  }

  /// Ghi hao hụt (đổ bỏ, hết hạn, hư hỏng...) — trừ kho nguyên tử qua RPC `record_stock_waste_v1`.
  /// [qty] tính theo đơn vị kho của sản phẩm. Trả về tồn mới.
  Future<double> recordStockWaste({
    required String productId,
    required double qty,
    required String reason,
    String? note,
  }) async {
    try {
      final res = await _sb.rpc('record_stock_waste_v1', params: {
        'p_product_id': productId,
        'p_qty': qty,
        'p_reason': reason,
        'p_note': note,
      });
      if (res is Map && res['success'] == true) {
        return (res['new_stock'] as num?)?.toDouble() ?? 0;
      }
      throw Exception((res is Map ? res['message'] : null) ?? 'Không ghi được hao hụt');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202' || (e.message).contains('Could not find the function')) {
        throw Exception('Máy chủ chưa được cập nhật tính năng hao hụt (cần chạy migration FIX 10).');
      }
      rethrow;
    }
  }

  /// Lịch sử hao hụt gần đây (để hiển thị dưới form ghi hao hụt).
  Future<List<Map<String, dynamic>>> fetchRecentWaste({int limit = 20}) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final rows = await _sb
        .from('stock_movements')
        .select('id, product_id, delta, reason, note, created_at')
        .eq('store_id', storeId)
        .inFilter('reason', ['waste', 'expired', 'damaged', 'spill', 'loss'])
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Load danh sách phiên kiểm kê đã có
  Future<List<Map<String, dynamic>>> fetchStockCounts() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final rows = await _sb
        .from('stock_counts')
        .select()
        .eq('store_id', storeId)
        .order('created_at', ascending: false)
        .limit(20);
    return List<Map<String, dynamic>>.from(rows);
  }
}
