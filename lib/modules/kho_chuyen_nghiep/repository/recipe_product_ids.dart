import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/models/product_model.dart';
import '../../../core/utils/paged_query.dart';

/// Món bán gắn công thức thì khi bán máy chủ chỉ trừ nguyên liệu (complete_pos_sale_v1), tồn của chính
/// món đứng yên. Nguyên liệu / bán thành phẩm gắn công thức (vd cốt trà) thì tồn là hàng thật: món khác
/// trừ dần, lệnh sản xuất cộng vào (complete_production_order chỉ cộng cho 2 loại này) → không tính.
bool soldByRecipe(String? productType) =>
    productType != 'ingredient' && productType != 'semi_finished';

/// Công thức gắn với nguyên liệu / bán thành phẩm (vd cốt trà): không bán ở quầy, hoàn thành lệnh sản xuất
/// thì cộng thành phẩm vào kho. Chưa biết loại món (đang tải) thì coi như món bán.
bool recipeMakesStock(String? productType) => productType != null && !soldByRecipe(productType);

/// Bán hàng khoá "Hết" / báo sắp hết theo tồn của chính món chỉ khi món có đặt tồn tối thiểu và KHÔNG bán
/// theo công thức ([recipeIds]) — tồn của món theo công thức không đổi khi bán, khoá theo nó là khoá mãi.
bool locksOnOwnStock(ProductModel p, Set<String> recipeIds) =>
    p.minStock > 0 && !recipeIds.contains(p.id);

/// Id món bán có công thức gắn máy bán hàng (công thức chưa xoá, có ít nhất một dòng nguyên liệu, món
/// không phải nguyên liệu / bán thành phẩm) — tồn của các món này không phải hàng thật. Màn Kho và Boom
/// cùng dùng để không cộng vào giá trị kho. Chỉ đọc: Boom gọi hàm này, boom_read_only_guard_test quét cả file.
Future<Set<String>> fetchRecipeProductIds(SupabaseClient db, String storeId) async {
  final recipes = await fetchAllPages((o, e) => db
      .from('recipes')
      .select('id,pos_product_id')
      .eq('store_id', storeId)
      .eq('is_deleted', false)
      .not('pos_product_id', 'is', null)
      .order('id')
      .range(o, e));
  final productOf = {
    for (final r in recipes) '${r['id']}': '${r['pos_product_id']}',
  };
  if (productOf.isEmpty) return {};
  final lines = await fetchAllPages((o, e) => db
      .from('recipe_ingredients')
      .select('id,recipe_id')
      .inFilter('recipe_id', productOf.keys.toList())
      .order('id')
      .range(o, e));
  final withLines = {
    for (final l in lines)
      if (productOf['${l['recipe_id']}'] != null) productOf['${l['recipe_id']}']!,
  };
  if (withLines.isEmpty) return {};
  final products = await fetchAllPages((o, e) => db
      .from('products')
      .select('id,product_type')
      .eq('store_id', storeId)
      .inFilter('id', withLines.toList())
      .order('id')
      .range(o, e));
  return {
    for (final p in products)
      if (soldByRecipe(p['product_type'] as String?)) '${p['id']}',
  };
}
