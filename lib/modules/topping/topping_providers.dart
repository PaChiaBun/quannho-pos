import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/repositories/core_product_repository.dart';
import '../../core/services/store_auth_service.dart';
import 'topping_links_repository.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Topping Providers
// Quản lý state cho hệ thống topping phẳng (flat architecture)
// ─────────────────────────────────────────────────────────────────────────────

final toppingLinksRepoProvider = Provider<ToppingLinksRepository>(
  (_) => ToppingLinksRepository(),
);

// ── Tất cả topping products của quán ─────────────────────────────────────────
// Dùng trong: EditProductSheet picker, BanScreen topping picker
final allToppingProductsProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final info = await StoreAuthService.getStoreInfo();
  final storeId = info['store_id'] as String?;
  if (storeId == null) return [];

  final sb = Supabase.instance.client;
  final rows = await sb
      .from('products')
      .select('id, name, sell_price, unit, topping_unit, stock_qty, is_topping')
      .eq('store_id', storeId)
      .eq('is_topping', true)
      .eq('is_deleted', false)
      .eq('is_active', true)
      .order('name');

  return rows.map(ProductModel.fromMap).toList();
});

// ── Tất cả món chính (non-topping) của quán ──────────────────────────────────
// Dùng trong: EditProductSheet khi sản phẩm là topping → chọn món áp dụng
final allMainProductsProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final info = await StoreAuthService.getStoreInfo();
  final storeId = info['store_id'] as String?;
  if (storeId == null) return [];

  final sb = Supabase.instance.client;
  final rows = await sb
      .from('products')
      .select('id, name, sell_price, unit, is_topping')
      .eq('store_id', storeId)
      .eq('is_topping', false)
      .eq('is_deleted', false)
      .eq('is_active', true)
      .order('name');

  return rows.map(ProductModel.fromMap).toList();
});

// ── Toppings gắn với 1 sản phẩm cụ thể ──────────────────────────────────────
// Dùng trong: BanScreen khi khách gọi món → fetch toppings khả dụng
final productToppingsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, productId) async {
  return ref
      .read(toppingLinksRepoProvider)
      .fetchToppingsForProduct(productId);
});

// ── Product IDs đã link vào 1 topping ────────────────────────────────────────
// Dùng trong: EditProductSheet khi đang edit topping → hiện checkbox món đã link
final toppingLinkedProductIdsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, toppingId) async {
  return ref.read(toppingLinksRepoProvider).fetchLinkedProductIds(toppingId);
});

// ── Topping IDs đã link vào 1 món chính ──────────────────────────────────────
// Dùng trong: EditProductSheet khi đang edit món chính → hiện checkbox topping đã link
final productLinkedToppingIdsProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, productId) async {
  final links = await ref
      .read(toppingLinksRepoProvider)
      .fetchToppingsForProduct(productId);
  return links.map((l) => l['id'] as String).toList();
});
