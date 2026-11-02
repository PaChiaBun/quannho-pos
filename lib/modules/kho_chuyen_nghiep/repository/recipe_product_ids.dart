import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/paged_query.dart';

/// Id món bán có công thức gắn máy bán hàng (công thức chưa xoá, có ít nhất một dòng nguyên liệu) —
/// đúng điều kiện máy chủ dùng khi bán (complete_pos_sale_v1): chỉ trừ nguyên liệu, tồn của chính
/// món đứng yên nên không phải hàng thật. Màn Kho và Boom cùng dùng để không cộng vào giá trị kho.
/// Chỉ đọc: Boom gọi hàm này, boom_read_only_guard_test quét cả file.
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
  return {
    for (final l in lines)
      if (productOf['${l['recipe_id']}'] != null) productOf['${l['recipe_id']}']!,
  };
}
