import 'package:supabase_flutter/supabase_flutter.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ToppingLinksRepository
// Quản lý liên kết đơn giản: món chính ↔ topping product
// Bảng: product_topping_links (product_id, topping_id)
// ⚠️  Bảng KHÔNG có sort_order — thứ tự theo inserted_at tự nhiên
// ─────────────────────────────────────────────────────────────────────────────

class ToppingLinksRepository {
  final _sb = Supabase.instance.client;

  // ── Fetch tất cả topping products gắn với 1 món chính ──────────────────────
  Future<List<Map<String, dynamic>>> fetchToppingsForProduct(
      String productId) async {
    try {
      final links = await _sb
          .from('product_topping_links')
          .select('topping_id')
          .eq('product_id', productId);

      if (links.isEmpty) return [];

      final toppingIds = links.map((l) => l['topping_id'] as String).toList();
      final products = await _sb
          .from('products')
          .select('id, name, sell_price, unit, stock_qty, is_topping')
          .inFilter('id', toppingIds)
          .eq('is_topping', true);

      // Giữ thứ tự theo danh sách links (inserted_at tự nhiên)
      final orderMap = {
        for (int i = 0; i < toppingIds.length; i++) toppingIds[i]: i
      };
      final list = List<Map<String, dynamic>>.from(products);
      list.sort((a, b) =>
          (orderMap[a['id']] ?? 99).compareTo(orderMap[b['id']] ?? 99));
      return list;
    } catch (e) {
      return [];
    }
  }

  // ── Fetch danh sách product_id đã link với 1 topping ──────────────────────
  Future<List<String>> fetchLinkedProductIds(String toppingId) async {
    try {
      final res = await _sb
          .from('product_topping_links')
          .select('product_id')
          .eq('topping_id', toppingId);
      return res.map((r) => r['product_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }

  // ── Đồng bộ toppings cho 1 món chính (delete + re-insert) ─────────────────
  Future<void> syncToppingsForProduct(
      String productId, List<String> toppingIds) async {
    try {
      // Xoá links cũ
      await _sb
          .from('product_topping_links')
          .delete()
          .eq('product_id', productId);

      if (toppingIds.isEmpty) return;

      // Re-insert theo thứ tự danh sách (không cần sort_order column)
      await _sb.from('product_topping_links').insert([
        for (final tid in toppingIds)
          {'product_id': productId, 'topping_id': tid}
      ]);
    } catch (e) {
      rethrow;
    }
  }

  // ── Đồng bộ products cho 1 topping (delete + re-insert) ───────────────────
  Future<void> syncProductsForTopping(
      String toppingId, List<String> productIds) async {
    try {
      // Xoá links cũ
      await _sb
          .from('product_topping_links')
          .delete()
          .eq('topping_id', toppingId);

      if (productIds.isEmpty) return;

      // Re-insert
      await _sb.from('product_topping_links').insert([
        for (final pid in productIds)
          {'product_id': pid, 'topping_id': toppingId}
      ]);
    } catch (e) {
      rethrow;
    }
  }

  // ── Link đơn lẻ (thêm 1 topping vào 1 món) ────────────────────────────────
  Future<void> addLink(String productId, String toppingId) async {
    try {
      await _sb.from('product_topping_links').upsert(
        {'product_id': productId, 'topping_id': toppingId},
        onConflict: 'product_id,topping_id',
      );
    } catch (e) {
      rethrow;
    }
  }

  // ── Xoá 1 link ────────────────────────────────────────────────────────────
  Future<void> removeLink(String productId, String toppingId) async {
    try {
      await _sb
          .from('product_topping_links')
          .delete()
          .eq('product_id', productId)
          .eq('topping_id', toppingId);
    } catch (e) {
      rethrow;
    }
  }
}
