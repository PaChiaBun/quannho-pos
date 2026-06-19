import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/repositories/core_product_repository.dart';

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
  final double? ingredientCostLatest;

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
  });

  /// % hao phí để hiển thị trên UI (VD: 0.8 → 20.0)
  double get wastePct => ((1.0 - yieldFactor) * 100).roundToDouble();

  /// Số lượng thực tế cần lấy từ kho (đã tính hao phí)
  double get actualQuantity => yieldFactor > 0 ? quantity / yieldFactor : quantity;

  /// Chi phí 1 dòng nguyên liệu — có quy đổi đơn vị + hao phí
  /// ingredientCostLatest đã được chuẩn hóa sang giá/gram hoặc giá/ml
  double get lineCost {
    final cost = ingredientCostLatest ?? 0;
    // Quy đổi actualQuantity về đơn vị nhỏ nhất (gram/ml)
    double normalizedQty = actualQuantity;
    if (unit == 'kg')  normalizedQty = actualQuantity * 1000;
    if (unit == 'lít') normalizedQty = actualQuantity * 1000;
    return cost * normalizedQty;
  }

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
          .select('id, name, cost_price_latest, cost_price, unit')
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
          // Dùng cost_price_latest nếu có, fallback về cost_price (giá vốn ban đầu)
          // Chuẩn hóa: lưu dạng giá/gram hoặc giá/ml để tính đúng khi qty tính bằng gram/ml
          ingredientCostLatest: () {
            // cost_price_latest = 0 khi chưa có đơn nhập → KHÔNG dùng ?? mà phải check >0
            final cl = (prodData?['cost_price_latest'] as num?)?.toDouble() ?? 0;
            final cp = (prodData?['cost_price'] as num?)?.toDouble() ?? 0;
            final rawCost = cl > 0 ? cl : cp; // Ưu tiên latest nếu có, fallback cost_price
            final prodUnit = (prodData?['unit'] as String?) ?? '';
            if (prodUnit == 'kg')  return rawCost / 1000; // 55000/kg → 55/gram
            if (prodUnit == 'lít') return rawCost / 1000; // per ml
            return rawCost;
          }(),
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
  double convertToProductUnit(double qty, String recipeUnit, String productUnit) {
    return _convertToProductUnit(qty, recipeUnit, productUnit);
  }

  double _convertToProductUnit(double qty, String recipeUnit, String productUnit) {
    if (recipeUnit == productUnit) return qty;
    // Bước 1: về base unit (gram hoặc ml)
    final double base;
    switch (recipeUnit) {
      case 'kg':   base = qty * 1000; break; // kg → gram
      case 'lít':  base = qty * 1000; break; // lít → ml
      default:     base = qty;               // gram, ml, cái, chiếc, phần...
    }
    // Bước 2: từ base → product unit
    switch (productUnit) {
      case 'kg':   return base / 1000; // gram → kg
      case 'lít':  return base / 1000; // ml → lít
      default:     return base;
    }
  }

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
        .select('id, stock_qty, unit')
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
      final qtyPerServing = _convertToProductUnit(ing.actualQuantity, ing.unit, prodUnit);
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
        .select('id, name, stock_qty, unit')
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
      final neededInProdUnit = _convertToProductUnit(ing.actualQuantity * qty, ing.unit, prodUnit);

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
        .select('id, unit, cost_price_latest, cost_price')
        .inFilter('id', ingIds)) as List;
    final unitMap      = <String, String>{};
    final costPriceMap = <String, double>{};
    for (final row in productRows) {
      final r = row as Map<String, dynamic>;
      final id = r['id'] as String;
      final prodUnit = r['unit'] as String? ?? 'gram';
      unitMap[id] = prodUnit;
      // Ưu tiên cost_price_latest nếu > 0, fallback về cost_price
      final latest = (r['cost_price_latest'] as num?)?.toDouble() ?? 0;
      final base   = (r['cost_price'] as num?)?.toDouble() ?? 0;
      final rawCost = latest > 0 ? latest : base;
      // ‼️ FIX Bug #22: normalize cost về đơn vị nhỏ nhất để nhân đúng với stockDelta
      // stockDelta đã được convert sang prodUnit → cần cost cùng đơn vị đó
      // VD: prodUnit=gram → cost = rawCost/1000 (giá/gram) nếu raw là giá/kg
      // VD: prodUnit=kg   → cost = rawCost (giá/kg)
      // Nguyên tắc: raw cost LUÔN lưu dạng giá/đơn vị lớn (kg, lít, cái...)
      // KHÔNG chuẩn hóa gì thêm — để stockDelta và cost khớp đơn vị
      costPriceMap[id] = rawCost; // giá theo prodUnit (giá/kg nếu prodUnit=kg, giá/gram nếu prodUnit=gram, etc.)
    }

    double totalCogs = 0;

    for (final ing in recipe.ingredients) {
      if (ing.ingredientId == null) continue;
      final prodUnit = unitMap[ing.ingredientId] ?? ing.unit;

      // Số lượng thực tế cần lấy từ kho = quantity (phần) × actualQuantity/phần
      // actualQuantity đã tính hao phí: quantity / yieldFactor
      final actualPerBatch = ing.actualQuantity * quantity;

      // Quy đổi sang đơn vị sản phẩm (kg/lít...)
      final stockDelta = _convertToProductUnit(actualPerBatch, ing.unit, prodUnit);

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

    // Ghi finance_record expense (COGS) — silent fail nếu Finance module tắt
    if (totalCogs > 0) {
      try {
        await _sb.from('finance_records').insert({
          'id':           _uuid.v4(),
          'store_id':     storeId,
          'type':         'expense',
          'amount':       double.parse(totalCogs.toStringAsFixed(0)),
          'description':  'Giá vốn NL: ${recipe.name} × ${quantity.toStringAsFixed(0)} phần',
          'reference_id': referenceId,  // link về orders.id nếu có
          'is_auto':      true,
          'recorded_at':  now,
        });
      } catch (_) {} // Finance module không bật — bỏ qua
    }
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

  Future<void> completeProductionOrder(
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
          // Chi phí thực (cost_at_time đơn vị giá/gram hay giá/ml đã chuẩn hóa)
          double normalizedUsed = actualUsed;
          if (ing.unit == 'kg')  normalizedUsed = actualUsed * 1000;
          if (ing.unit == 'lít') normalizedUsed = actualUsed * 1000;
          final totalCost = (ing.ingredientCostLatest ?? 0) * normalizedUsed;
          await _sb.from('production_logs').insert({
            'id':                   const Uuid().v4(),
            'production_order_id':  order.id,
            'store_id':             storeId,
            'ingredient_id':        ing.ingredientId,
            'ingredient_name':      ing.ingredientName ?? '',
            'qty_used':             actualUsed,
            'unit':                 ing.unit,
            'cost_at_time':         ing.ingredientCostLatest ?? 0,
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
      final date = (r['created_at'] as String).substring(0, 10);
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

  /// Xác nhận kiểm kê → tự điều chỉnh stock_qty theo variance
  Future<void> confirmStockCount(String countId) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final now = DateTime.now().toUtc().toIso8601String();

    // ‼️ FIX Bug #44: idempotency guard — tránh confirm 2 lần
    // lần 2 sẽ apply toàn bộ stock adjustment lên kho đã điều chỉnh → lệch kho nghiêm trọng
    final countStatus = await _sb.from('stock_counts')
        .select('status')
        .eq('id', countId)
        .maybeSingle();
    if (countStatus == null) throw Exception('Phiên kiểm kê không tồn tại');
    if (countStatus['status'] == 'confirmed') {
      debugPrint('[KhoCN] confirmStockCount: $countId đã confirmed, bỏ qua');
      return;
    }

    // 1. Load items có variance != 0
    final items = await _sb
        .from('stock_count_items')
        .select()
        .eq('count_id', countId);


    for (final item in items) {
      // FIX: bỏ `variance` dead var — chỉ cần systemQty và actualQty
      final systemQty = (item['system_qty'] as num?)?.toDouble() ?? 0;
      final actualQty = (item['actual_qty'] as num?)?.toDouble() ?? 0;
      final diff = actualQty - systemQty;
      if (diff == 0) continue;

      final productId = item['product_id'] as String;
      // Ghi stock_movement — delta là numeric(12,3)
      await _sb.from('stock_movements').insert({
        'id':         const Uuid().v4(),
        'store_id':   storeId,
        'product_id': productId,
        'delta':      double.parse(diff.toStringAsFixed(3)),
        'reason':     'stock_count',
        'note':       diff > 0
            ? 'Kiểm kê: thừa ${diff.abs().toStringAsFixed(0)}'
            : 'Kiểm kê: thiếu ${diff.abs().toStringAsFixed(0)}',
        'created_at': now,
      });
      // FIX: dùng CoreProductRepository.update() để updated_at luôn được ghi
      // Không dùng raw products.update({'stock_qty':...}) vì bỏ qua updated_at
      await _productRepo.update(productId, {'stock_qty': actualQty});
    }

    // 2. Cập nhật trạng thái phiên
    await _sb.from('stock_counts').update({
      'status':       'confirmed',
      'confirmed_at': now,
    }).eq('id', countId);
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

