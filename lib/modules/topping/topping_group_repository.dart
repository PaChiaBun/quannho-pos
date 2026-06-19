// lib/modules/topping/topping_group_repository.dart
// ─────────────────────────────────────────────────────────────────────────────
// Topping Group Repository — Phương án B (Modifier Group Model)
// Giống Sapo FnB: 1 Nhóm Topping → nhiều sản phẩm
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/store_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class ToppingGroupItemModel {
  final String id;
  final String groupId;
  final String productId;
  final String productName;
  final double sellPrice;
  final String toppingUnit;
  final int sortOrder;

  const ToppingGroupItemModel({
    required this.id,
    required this.groupId,
    required this.productId,
    required this.productName,
    required this.sellPrice,
    required this.toppingUnit,
    required this.sortOrder,
  });

  factory ToppingGroupItemModel.fromMap(Map<String, dynamic> m) {
    final product = m['product'] as Map<String, dynamic>? ?? {};
    return ToppingGroupItemModel(
      id:          m['id'] as String,
      groupId:     m['group_id'] as String,
      productId:   m['product_id'] as String,
      productName: product['name'] as String? ?? '',
      sellPrice:   (product['sell_price'] as num?)?.toDouble() ?? 0,
      toppingUnit: product['topping_unit'] as String? ?? product['unit'] as String? ?? 'phần',
      sortOrder:   (m['sort_order'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': productName,
    'price': sellPrice,
    'unit': toppingUnit,
    'qty': 0,
  };
}

class ToppingGroupModel {
  final String id;
  final String storeId;
  final String name;
  final String? description;
  final int minSelect;
  final int maxSelect;
  final bool isRequired;
  final int sortOrder;
  final List<ToppingGroupItemModel> items;

  const ToppingGroupModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.description,
    required this.minSelect,
    required this.maxSelect,
    required this.isRequired,
    required this.sortOrder,
    required this.items,
  });

  factory ToppingGroupModel.fromMap(Map<String, dynamic> m) {
    final rawItems = m['topping_group_items'] as List? ?? [];
    return ToppingGroupModel(
      id:          m['id'] as String,
      storeId:     m['store_id'] as String,
      name:        m['name'] as String,
      description: m['description'] as String?,
      minSelect:   (m['min_select'] as num?)?.toInt() ?? 0,
      maxSelect:   (m['max_select'] as num?)?.toInt() ?? 10,
      isRequired:  m['is_required'] as bool? ?? false,
      sortOrder:   (m['sort_order'] as num?)?.toInt() ?? 0,
      items: rawItems
          .map((i) => ToppingGroupItemModel.fromMap(i as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
    );
  }

  ToppingGroupModel copyWith({List<ToppingGroupItemModel>? items}) =>
      ToppingGroupModel(
        id: id, storeId: storeId, name: name, description: description,
        minSelect: minSelect, maxSelect: maxSelect, isRequired: isRequired,
        sortOrder: sortOrder, items: items ?? this.items,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────

class ToppingGroupRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Fetch tất cả groups của quán (kèm items) ──────────────────────────────
  Future<List<ToppingGroupModel>> fetchAll() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    try {
      final rows = await _sb
          .from('topping_groups')
          .select('''
            *,
            topping_group_items (
              id, group_id, product_id, sort_order,
              product:products (name, sell_price, unit, topping_unit)
            )
          ''')
          .eq('store_id', storeId)
          .eq('is_deleted', false)
          .order('sort_order');
      return (rows as List)
          .map((r) => ToppingGroupModel.fromMap(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[ToppingGroupRepo] fetchAll error: $e');
      return [];
    }
  }

  // ── Fetch groups gắn với 1 sản phẩm cụ thể (dùng trong POS order flow) ────
  Future<List<ToppingGroupModel>> fetchForProduct(String productId) async {
    try {
      final linkRows = await _sb
          .from('product_topping_group_links')
          .select('group_id, sort_order')
          .eq('product_id', productId)
          .order('sort_order');

      if ((linkRows as List).isEmpty) return [];

      final groupIds = linkRows.map((r) => r['group_id'] as String).toList();

      final rows = await _sb
          .from('topping_groups')
          .select('''
            *,
            topping_group_items (
              id, group_id, product_id, sort_order,
              product:products (name, sell_price, unit, topping_unit)
            )
          ''')
          .inFilter('id', groupIds)
          .eq('is_deleted', false);

      final groups = (rows as List)
          .map((r) => ToppingGroupModel.fromMap(r as Map<String, dynamic>))
          .toList();

      // Sort theo thứ tự link
      final orderMap = {for (var r in linkRows) r['group_id'] as String: r['sort_order'] as int? ?? 0};
      groups.sort((a, b) => (orderMap[a.id] ?? 0).compareTo(orderMap[b.id] ?? 0));
      return groups;
    } catch (e) {
      debugPrint('[ToppingGroupRepo] fetchForProduct error: $e');
      return [];
    }
  }

  // ── Fetch product IDs đang dùng 1 group ───────────────────────────────────
  Future<List<String>> fetchLinkedProductIds(String groupId) async {
    try {
      final rows = await _sb
          .from('product_topping_group_links')
          .select('product_id')
          .eq('group_id', groupId);
      return (rows as List).map((r) => r['product_id'] as String).toList();
    } catch (e) {
      debugPrint('[ToppingGroupRepo] fetchLinkedProductIds error: $e');
      return [];
    }
  }

  // ── Tạo group mới ─────────────────────────────────────────────────────────
  Future<String?> createGroup({
    required String name,
    String? description,
    int minSelect = 0,
    int maxSelect = 10,
    bool isRequired = false,
    int sortOrder = 0,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return null;
    try {
      final now = DateTime.now().toUtc();
      final row = await _sb.from('topping_groups').insert({
        'store_id':    storeId,
        'name':        name,
        'description': description,
        'min_select':  minSelect,
        'max_select':  maxSelect,
        'is_required': isRequired,
        'sort_order':  sortOrder,
        'is_deleted':  false,
        'created_at':  now.toIso8601String(),
        'updated_at':  now.millisecondsSinceEpoch,
      }).select('id').single();
      return row['id'] as String?;
    } catch (e) {
      debugPrint('[ToppingGroupRepo] createGroup error: $e');
      return null;
    }
  }

  // ── Cập nhật group ────────────────────────────────────────────────────────
  Future<void> updateGroup(String groupId, {
    String? name,
    String? description,
    int? minSelect,
    int? maxSelect,
    bool? isRequired,
    int? sortOrder,
  }) async {
    final data = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (minSelect != null) 'min_select': minSelect,
      if (maxSelect != null) 'max_select': maxSelect,
      if (isRequired != null) 'is_required': isRequired,
      if (sortOrder != null) 'sort_order': sortOrder,
    };
    await _sb.from('topping_groups').update(data).eq('id', groupId);
  }

  // ── Xóa mềm group ─────────────────────────────────────────────────────────
  Future<void> deleteGroup(String groupId) async {
    await _sb.from('topping_groups').update({
      'is_deleted': true,
      'updated_at': DateTime.now().toUtc().millisecondsSinceEpoch,
    }).eq('id', groupId);
  }

  // ── Thêm topping product vào group ────────────────────────────────────────
  Future<void> addItemToGroup(String groupId, String productId, {int sortOrder = 0}) async {
    try {
      await _sb.from('topping_group_items').upsert({
        'group_id':   groupId,
        'product_id': productId,
        'sort_order': sortOrder,
      }, onConflict: 'group_id,product_id');
    } catch (e) {
      debugPrint('[ToppingGroupRepo] addItemToGroup error: $e');
    }
  }

  // ── Xóa topping product khỏi group ───────────────────────────────────────
  Future<void> removeItemFromGroup(String groupId, String productId) async {
    await _sb.from('topping_group_items')
        .delete()
        .eq('group_id', groupId)
        .eq('product_id', productId);
  }

  // ── Đồng bộ danh sách items (replace all) ────────────────────────────────
  Future<void> syncGroupItems(String groupId, List<String> productIds) async {
    await _sb.from('topping_group_items').delete().eq('group_id', groupId);
    if (productIds.isEmpty) return;
    await _sb.from('topping_group_items').insert(
      productIds.asMap().entries.map((e) => {
        'group_id':   groupId,
        'product_id': e.value,
        'sort_order': e.key,
      }).toList(),
    );
  }

  // ── Gắn group vào 1 sản phẩm ─────────────────────────────────────────────
  Future<void> linkGroupToProduct(String groupId, String productId, {int sortOrder = 0}) async {
    try {
      await _sb.from('product_topping_group_links').upsert({
        'product_id': productId,
        'group_id':   groupId,
        'sort_order': sortOrder,
      }, onConflict: 'product_id,group_id');
    } catch (e) {
      debugPrint('[ToppingGroupRepo] linkGroupToProduct error: $e');
    }
  }

  // ── Gỡ group khỏi 1 sản phẩm ─────────────────────────────────────────────
  Future<void> unlinkGroupFromProduct(String groupId, String productId) async {
    await _sb.from('product_topping_group_links')
        .delete()
        .eq('product_id', productId)
        .eq('group_id', groupId);
  }

  // ── Batch: gắn group vào nhiều sản phẩm cùng lúc ─────────────────────────
  Future<void> linkGroupToProducts(String groupId, List<String> productIds) async {
    if (productIds.isEmpty) return;
    await _sb.from('product_topping_group_links').upsert(
      productIds.asMap().entries.map((e) => {
        'product_id': e.value,
        'group_id':   groupId,
        'sort_order': e.key,
      }).toList(),
      onConflict: 'product_id,group_id',
    );
  }

  // ── Đồng bộ products linked vào 1 group (replace all) ─────────────────────
  Future<void> syncGroupProducts(String groupId, List<String> productIds) async {
    await _sb.from('product_topping_group_links').delete().eq('group_id', groupId);
    if (productIds.isEmpty) return;
    await _sb.from('product_topping_group_links').insert(
      productIds.asMap().entries.map((e) => {
        'product_id': e.value,
        'group_id':   groupId,
        'sort_order': e.key,
      }).toList(),
    );
  }
}
