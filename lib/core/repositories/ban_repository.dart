import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/store_auth_service.dart';


// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────
class BanZoneModel {
  final String id;
  final String storeId;
  final String name;
  final int colorValue;
  final int iconCode;
  final int sortOrder;
  final bool isActive;

  const BanZoneModel({
    required this.id, required this.storeId, required this.name,
    required this.colorValue, required this.iconCode,
    required this.sortOrder, required this.isActive,
  });

  /// DB dùng 'color' (text hex #RRGGBB) → convert từ int 0xFFRRGGBB
  static String _intToHex(int v) =>
      '#${(v & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// DB 'color' hex → int 0xFFRRGGBB
  static int _hexToInt(String? hex) {
    if (hex == null || hex.isEmpty) return 0xFF1C2151;
    final h = hex.replaceAll('#', '');
    return int.tryParse('FF$h', radix: 16) ?? 0xFF1C2151;
  }

  factory BanZoneModel.fromMap(Map<String, dynamic> m) => BanZoneModel(
    id: m['id'] as String,
    storeId: m['store_id'] as String? ?? '',
    name: m['name'] as String? ?? '',
    // DB có 'color' (text hex) — fallback sang 'color_value' (int) nếu có
    colorValue: m['color_value'] != null
        ? (m['color_value'] as num).toInt()
        : _hexToInt(m['color'] as String?),
    iconCode: m['icon_code'] as int? ?? 0xe318,
    sortOrder: m['sort_order'] as int? ?? 0,
    isActive: m['is_active'] as bool? ?? true,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'store_id': storeId, 'name': name,
    'color': _intToHex(colorValue),   // ← tên cột đúng trong DB thực tế
    'icon_code': iconCode,
    'sort_order': sortOrder, 'is_active': isActive,
  };
}

class BanTableModel {
  final String id;
  final String zoneId;
  final String storeId;
  final String label;
  final int seats;
  final int sortOrder;
  final bool isActive;
  final double? posX;
  final double? posY;

  const BanTableModel({
    required this.id, required this.zoneId, required this.storeId,
    required this.label, required this.seats, required this.sortOrder,
    required this.isActive, this.posX, this.posY,
  });

  factory BanTableModel.fromMap(Map<String, dynamic> m) => BanTableModel(
    id: m['id'] as String,
    zoneId: m['zone_id'] as String? ?? '',
    storeId: m['store_id'] as String? ?? '',
    // DB có 'name' (không phải 'label') — fallback cho data cũ
    label: m['name'] as String? ?? m['label'] as String? ?? '',
    // DB có 'capacity' (không phải 'seats') — fallback cho data cũ
    seats: (m['capacity'] as int?) ?? (m['seats'] as int?) ?? 4,
    sortOrder: m['sort_order'] as int? ?? 0,
    isActive: m['is_active'] as bool? ?? true,
    posX: (m['pos_x'] as num?)?.toDouble(),
    posY: (m['pos_y'] as num?)?.toDouble(),
  );
}

class BanSessionModel {
  final String id;
  final String tableId;
  final String storeId;
  final String status; // 'open' | 'closed'
  final int openedAt;
  final int? closedAt;
  final double totalAmount;
  final int guestCount;

  const BanSessionModel({
    required this.id, required this.tableId, required this.storeId,
    required this.status, required this.openedAt, this.closedAt,
    required this.totalAmount, required this.guestCount,
  });

  factory BanSessionModel.fromMap(Map<String, dynamic> m) => BanSessionModel(
    id: m['id'] as String,
    tableId: m['table_id'] as String? ?? '',
    storeId: m['store_id'] as String? ?? '',
    status: m['status'] as String? ?? 'open',
    openedAt: _toMs(m['opened_at']),
    closedAt: m['closed_at'] != null ? _toMs(m['closed_at']) : null,
    totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0,
    guestCount: m['guest_count'] as int? ?? 1,
  );
}

class BanSessionItemModel {
  final String id;
  final String sessionId;
  final String productId;
  final String productName;
  final double price;
  final double quantity;
  final String? note;
  final String? modifiersJson;
  final int addedAt;
  final String kitchenStatus; // 'pending' | 'dang_lam' | 'xong'

  const BanSessionItemModel({
    required this.id, required this.sessionId, required this.productId,
    required this.productName, required this.price, required this.quantity,
    this.note, this.modifiersJson, required this.addedAt,
    this.kitchenStatus = 'pending',
  });

  double get subtotal => price * quantity;

  factory BanSessionItemModel.fromMap(Map<String, dynamic> m) => BanSessionItemModel(
    id: m['id'] as String,
    sessionId: m['session_id'] as String? ?? '',
    productId: m['product_id'] as String? ?? '',
    productName: m['product_name'] as String? ?? '',
    // DB có 'unit_price', fallback sang 'price' cho data cũ
    price: (m['unit_price'] as num?)?.toDouble() ??
           (m['price'] as num?)?.toDouble() ?? 0,
    quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
    note: m['note'] as String?,
    modifiersJson: m['modifiers_json'] as String?,
    addedAt: _toMs(m['added_at']),
    kitchenStatus: (m['kitchen_status'] == 'pending' || m['kitchen_status'] == null)
        ? 'chua_gui'
        : m['kitchen_status'] as String,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BAN REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class BanRepository {
  static SupabaseClient get _sb => Supabase.instance.client;

  String? _cachedStoreId;

  Future<String?> _storeId() async {
    if (_cachedStoreId != null) return _cachedStoreId;
    final info = await StoreAuthService.getStoreInfo();
    _cachedStoreId = info['store_id'] as String?;
    return _cachedStoreId;
  }

  // Module active state quản lý bởi ModuleRepository (app_settings)
  // Không cần watchModuleActive() ở đây nữa

  Stream<T> _robustStream<T>(
    String table,
    String columnFilter,
    String valueFilter,
    T Function(List<Map<String, dynamic>>) mapper,
  ) async* {
    Future<T> fetch() async {
      final rows = await _sb.from(table).select().eq(columnFilter, valueFilter);
      return mapper(rows);
    }

    // Initial fetch
    try {
      yield await fetch();
    } catch (e) {
      print('[RobustStream] Initial fetch err on $table: $e');
    }

    // Realtime connection with fallback to polling on async errors (e.g. RealtimeSubscribeException)
    while (true) {
      try {
        final stream = _sb.from(table).stream(primaryKey: ['id']).eq(columnFilter, valueFilter);
        await for (final rows in stream) {
          yield mapper(rows);
        }
      } catch (e) {
        print('[RobustStream] Realtime err on $table: $e. Falling back to poll 10s.');
        
        // Polling âm thầm 10 giây (chia làm 2 lần 5s) trước khi thử kết nối lại Realtime
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
        
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await fetch();
        } catch (_) {}
      }
    }
  }

  // ── Zones ─────────────────────────────────────────────────────────────────
  Stream<List<BanZoneModel>> watchZones() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    // Lọc bỏ zone hệ thống của POS mang đi (UUID cố định)
    const kSysPosZoneId = '00000000-0000-0000-0001-000000000001';
    yield* _robustStream(
      'ban_zones', 'store_id', storeId,
      (rows) => rows
        .where((r) => (r['is_active'] as bool? ?? true) && r['id'] != kSysPosZoneId)
        .map(BanZoneModel.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))
    );
  }

  Future<List<BanZoneModel>> getZones() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    // Lọc bỏ zone hệ thống của POS mang đi (UUID cố định)
    const kSysPosZoneId = '00000000-0000-0000-0001-000000000001';
    final rows = await _sb
        .from('ban_zones')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true)
        .neq('id', kSysPosZoneId)
        .order('sort_order');
    return rows.map(BanZoneModel.fromMap).toList();
  }

  Future<void> upsertZone(BanZoneModel zone) async =>
      _sb.from('ban_zones').upsert(zone.toMap());

  Future<void> updateZoneName(String id, String name) async =>
      _sb.from('ban_zones').update({'name': name}).eq('id', id);

  Future<void> deactivateZone(String id) async =>
      _sb.from('ban_zones').update({'is_active': false}).eq('id', id);

  Future<void> reorderZones(List<String> ids) async {
    for (int i = 0; i < ids.length; i++) {
      await _sb.from('ban_zones').update({'sort_order': i}).eq('id', ids[i]);
    }
  }

  // ── Tables ─────────────────────────────────────────────────────────────────
  Stream<List<BanTableModel>> watchTablesForZone(String zoneId) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    yield* _robustStream(
      'ban_dining_tables', 'store_id', storeId,
      (rows) => rows
        .where((r) => r['zone_id'] == zoneId && (r['is_active'] as bool? ?? true))
        .map(BanTableModel.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))
    );
  }

  Stream<List<BanTableModel>> watchAllTables() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }
    yield* _robustStream(
      'ban_dining_tables', 'store_id', storeId,
      (rows) => rows
        .where((r) => r['is_active'] as bool? ?? true)
        .map(BanTableModel.fromMap)
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder))
    );
  }

  Future<void> upsertTable(BanTableModel table) async =>
      _sb.from('ban_dining_tables').upsert({
        'id': table.id, 'zone_id': table.zoneId, 'store_id': table.storeId,
        'name': table.label,       // DB có 'name', không phải 'label'
        'capacity': table.seats,   // DB có 'capacity', không phải 'seats'
        'sort_order': table.sortOrder,
        'is_active': table.isActive,
        'pos_x': table.posX ?? 100.0,   // NOT NULL trong DB — dùng default 100
        'pos_y': table.posY ?? 100.0,   // NOT NULL trong DB — dùng default 100
      });

  Future<void> deactivateTable(String id) async =>
      _sb.from('ban_dining_tables').update({'is_active': false}).eq('id', id);

  Future<void> updateTablePosition(String id, double x, double y) async =>
      _sb.from('ban_dining_tables').update({'pos_x': x, 'pos_y': y}).eq('id', id);

  // ── Sessions ───────────────────────────────────────────────────────────────
  Stream<Map<String, BanSessionModel>> watchActiveSessions() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield {}; return; }
    yield* _robustStream(
      'ban_sessions', 'store_id', storeId,
      (rows) {
        final sessions = rows
            .where((r) => r['status'] == 'open')
            .map(BanSessionModel.fromMap)
            .toList();
        return {for (final s in sessions) s.tableId: s};
      }
    );
  }

  Future<BanSessionModel> openSession(String tableId, {int guestCount = 1}) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    // ‼️ FIX Bug #33: idempotency guard — kiểm tra session đang mở trước khi tạo mới
    // Tránh double-tap hoặc network retry tạo 2 session cùng 1 bàn
    final existing = await _sb
        .from('ban_sessions')
        .select('id, table_id, store_id, status, opened_at, closed_at, total_amount, guest_count')
        .eq('store_id', storeId)
        .eq('table_id', tableId)
        .eq('status', 'open')
        .maybeSingle();
    if (existing != null) return BanSessionModel.fromMap(existing);

    final id  = const Uuid().v4();          // UUID hợp lệ cho ban_sessions.id
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('ban_sessions').insert({
      'id': id, 'table_id': tableId, 'store_id': storeId,
      'status': 'open', 'opened_at': now,
      'total_amount': 0, 'guest_count': guestCount,
    });
    return BanSessionModel(
      id: id, tableId: tableId, storeId: storeId,
      status: 'open', openedAt: DateTime.now().millisecondsSinceEpoch,
      totalAmount: 0, guestCount: guestCount,
    );
  }

  Future<void> closeSession(String sessionId, double totalAmount) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('ban_sessions').update({
      'status': 'closed', 'closed_at': now, 'total_amount': totalAmount,
    }).eq('id', sessionId);
  }

  // ── Session Items ──────────────────────────────────────────────────────────
  Stream<List<BanSessionItemModel>> watchSessionItems(String sessionId) async* {
    yield* _robustStream(
      'ban_session_items', 'session_id', sessionId,
      (rows) => rows
          .map(BanSessionItemModel.fromMap)
          .toList()
        ..sort((a, b) => a.addedAt.compareTo(b.addedAt))
    );
  }

  Future<void> addSessionItem({
    required String sessionId,
    required String productId,
    required String productName,
    required double price,
    required double quantity,
    String? note,
    String? modifiersJson,
  }) async {
    final storeId = await _storeId();                // store_id bắt buộc
    if (storeId == null) throw Exception('Chưa chọn quán');
    final id  = const Uuid().v4();                   // UUID hợp lệ
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('ban_session_items').insert({
      'id':             id,
      'store_id':       storeId,                    // NOT NULL
      'session_id':     sessionId,
      'product_id':     productId,
      'product_name':   productName,                 // NOT NULL
      'unit_price':     price,                       // DB dùng 'unit_price'
      'quantity':       quantity,
      'subtotal':       price * quantity,            // NOT NULL
      'note':           note,
      'modifiers_json': modifiersJson,
      'added_at':       now,
      'kitchen_status': 'chua_gui',                 // đúng enum theo docs
    });
  }

  Future<void> addSessionItems({
    required String sessionId,
    required List<Map<String, dynamic>> items,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    final now = DateTime.now().toUtc().toIso8601String();

    // 1. Lấy tất cả items của session để thực hiện gộp trùng
    final List<dynamic> allRows = await _sb
        .from('ban_session_items')
        .select()
        .eq('session_id', sessionId);

    // Lọc ra các món nháp chưa gửi bếp (bao gồm chua_gui, pending, null)
    final List<Map<String, dynamic>> existingRows = allRows
        .map((r) => r as Map<String, dynamic>)
        .where((r) {
          final status = r['kitchen_status'];
          return status == null || status == 'chua_gui' || status == 'pending';
        })
        .toList();

    final List<Map<String, dynamic>> insertRows = [];
    final List<Future<void>> updateFutures = [];

    for (final item in items) {
      final productId = item['productId'] as String;
      final productName = item['productName'] as String;
      final price = (item['price'] as num).toDouble();
      final quantity = (item['quantity'] as num).toDouble();
      final note = item['note'] as String?;
      final modifiersJson = item['modifiersJson'] as String?;

      // Kiểm tra xem sản phẩm có cùng thuộc tính (note, modifiers) đã tồn tại chưa gửi bếp hay chưa
      Map<String, dynamic>? match;
      for (final ext in existingRows) {
        final sameProduct = ext['product_id'] == productId;
        
        final extNote = ext['note'] as String?;
        final sameNote = (note == null || note.trim().isEmpty)
            ? (extNote == null || extNote.trim().isEmpty)
            : (extNote != null && extNote.trim() == note.trim());
            
        final extMods = ext['modifiers_json'] as String?;
        final sameMods = (modifiersJson == null || modifiersJson.trim().isEmpty)
            ? (extMods == null || extMods.trim().isEmpty)
            : (extMods != null && extMods.trim() == modifiersJson.trim());

        if (sameProduct && sameNote && sameMods) {
          match = ext as Map<String, dynamic>;
          break;
        }
      }

      if (match != null) {
        // Gộp số lượng
        final currentQty = (match['quantity'] as num).toDouble();
        final newQty = currentQty + quantity;
        final newSubtotal = price * newQty;
        final itemId = match['id'] as String;

        updateFutures.add(
          _sb.from('ban_session_items').update({
            'quantity': newQty,
            'subtotal': newSubtotal,
          }).eq('id', itemId)
        );
      } else {
        // Tạo dòng mới
        final id = const Uuid().v4();
        insertRows.add({
          'id':             id,
          'store_id':       storeId,
          'session_id':     sessionId,
          'product_id':     productId,
          'product_name':   productName,
          'unit_price':     price,
          'quantity':       quantity,
          'subtotal':       price * quantity,
          'note':           (note == null || note.trim().isEmpty) ? null : note.trim(),
          'modifiers_json': (modifiersJson == null || modifiersJson.trim().isEmpty) ? null : modifiersJson.trim(),
          'added_at':       now,
          'kitchen_status': 'chua_gui',
        });
      }
    }

    // 2. Thực thi Batch Insert các món mới
    if (insertRows.isNotEmpty) {
      await _sb.from('ban_session_items').insert(insertRows);
    }

    // 3. Thực thi Parallel Updates các món được gộp
    if (updateFutures.isNotEmpty) {
      await Future.wait(updateFutures);
    }
  }

  Future<void> removeSessionItem(String itemId) async =>
      _sb.from('ban_session_items').delete().eq('id', itemId);

  Future<void> updateSessionTotal(String sessionId, double total) async =>
      _sb.from('ban_sessions').update({'total_amount': total}).eq('id', sessionId);

  // ── Chuyển bàn ────────────────────────────────────────────────────────────
  /// Chuyển toàn bộ session (và tất cả items) sang bàn khác.
  /// Items không cần di chuyển vì chúng link qua session_id, không phải table_id.
  Future<void> transferSession(String sessionId, String newTableId) async {
    await _sb
        .from('ban_sessions')
        .update({'table_id': newTableId})
        .eq('id', sessionId);
  }

  /// Lấy tất cả bàn của quán — dùng để pick bàn đích khi chuyển
  Future<List<BanTableModel>> getAllTables() async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    final rows = await _sb
        .from('ban_dining_tables')
        .select()
        .eq('store_id', storeId)
        .eq('is_active', true);
    return rows.map(BanTableModel.fromMap).toList();
  }

  /// Ghi lịch sử kiểm toán huỷ bàn / huỷ món vào bảng void_audit_logs
  Future<bool> logVoidEvent({
    required String voidType, // 'cancel_table' | 'void_item' | 'cancel_order'
    required String referenceId,
    required String label,
    required String requestedByUserId,
    required String requestedByName,
    required String approvedByUserId,
    required String approvedByName,
    required String reason,
    required double amount,
    List<dynamic>? details,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return false;
    try {
      await _sb.from('void_audit_logs').insert({
        'id': const Uuid().v4(),
        'store_id': storeId,
        'void_type': voidType,
        'reference_id': referenceId,
        'label': label,
        'requested_by_user_id': requestedByUserId,
        'requested_by_name': requestedByName,
        'approved_by_user_id': approvedByUserId,
        'approved_by_name': approvedByName,
        'reason': reason,
        'amount': amount,
        'details_json': details,
      });
      return true;
    } catch (e) {
      print('[BanRepository] logVoidEvent error: $e');
      return false;
    }
  }
}

int _toMs(dynamic val) {
  if (val is int) return val;
  if (val is String) return DateTime.tryParse(val)?.millisecondsSinceEpoch ?? 0;
  return 0;
}
