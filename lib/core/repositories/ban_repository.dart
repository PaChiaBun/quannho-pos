import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/store_auth_service.dart';
import '../utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    required this.id,
    required this.storeId,
    required this.name,
    required this.colorValue,
    required this.iconCode,
    required this.sortOrder,
    required this.isActive,
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
    'color': _intToHex(colorValue), // ← tên cột đúng trong DB thực tế
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
    required this.id,
    required this.zoneId,
    required this.storeId,
    required this.label,
    required this.seats,
    required this.sortOrder,
    required this.isActive,
    this.posX,
    this.posY,
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
  final String? waiterId;

  const BanSessionModel({
    required this.id,
    required this.tableId,
    required this.storeId,
    required this.status,
    required this.openedAt,
    this.closedAt,
    required this.totalAmount,
    required this.guestCount,
    this.waiterId,
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
    waiterId: m['waiter_id'] as String?,
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
  final String? addedBy;

  const BanSessionItemModel({
    required this.id,
    required this.sessionId,
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    this.note,
    this.modifiersJson,
    required this.addedAt,
    this.kitchenStatus = 'pending',
    this.addedBy,
  });

  BanSessionItemModel copyWith({
    String? id,
    String? sessionId,
    String? productId,
    String? productName,
    double? price,
    double? quantity,
    String? note,
    String? modifiersJson,
    int? addedAt,
    String? kitchenStatus,
    bool clearNote = false,
    String? addedBy,
  }) => BanSessionItemModel(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    productId: productId ?? this.productId,
    productName: productName ?? this.productName,
    price: price ?? this.price,
    quantity: quantity ?? this.quantity,
    note: clearNote ? null : (note ?? this.note),
    modifiersJson: modifiersJson ?? this.modifiersJson,
    addedAt: addedAt ?? this.addedAt,
    kitchenStatus: kitchenStatus ?? this.kitchenStatus,
    addedBy: addedBy ?? this.addedBy,
  );

  double get subtotal => price * quantity;

  factory BanSessionItemModel.fromMap(Map<String, dynamic> m) =>
      BanSessionItemModel(
        id: m['id'] as String,
        sessionId: m['session_id'] as String? ?? '',
        productId: m['product_id'] as String? ?? '',
        productName: m['product_name'] as String? ?? '',
        // DB có 'unit_price', fallback sang 'price' cho data cũ
        price:
            (m['unit_price'] as num?)?.toDouble() ??
            (m['price'] as num?)?.toDouble() ??
            0,
        quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
        note: m['note'] as String?,
        modifiersJson: m['modifiers_json'] as String?,
        addedAt: _toMs(m['added_at']),
        kitchenStatus:
            (m['kitchen_status'] == 'pending' || m['kitchen_status'] == null)
            ? 'chua_gui'
            : m['kitchen_status'] as String,
        addedBy: m['added_by'] as String?,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// BAN REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class BanRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  static final Map<String, Future<Map<String, dynamic>>> _settlementFlights =
      {};
  static final Map<String, String> _settlementFlightKeys = {};

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  bool _areModifiersEqual(String? json1, String? json2) {
    final clean1 = json1 == null || json1.trim().isEmpty;
    final clean2 = json2 == null || json2.trim().isEmpty;
    if (clean1 && clean2) return true;
    if (clean1 || clean2) return false;

    try {
      final List<dynamic> list1 = jsonDecode(json1);
      final List<dynamic> list2 = jsonDecode(json2);

      if (list1.length != list2.length) return false;

      String canonicalString(dynamic item) {
        if (item is! Map) return '';
        final id = item['id'] ?? '';
        final type = item['type'] ?? 'modifier';
        final qty = item['qty'] ?? 1;
        return '$type:$id:$qty';
      }

      final keys1 = list1.map(canonicalString).toList()..sort();
      final keys2 = list2.map(canonicalString).toList()..sort();

      for (int i = 0; i < keys1.length; i++) {
        if (keys1[i] != keys2[i]) return false;
      }
      return true;
    } catch (_) {
      return json1.trim() == json2.trim();
    }
  }

  // Module active state quản lý bởi ModuleRepository (app_settings)
  // Không cần watchModuleActive() ở đây nữa

  Stream<T> _robustStream<T>(
    String table,
    String columnFilter,
    String valueFilter,
    T Function(List<Map<String, dynamic>>) mapper,
  ) {
    StreamController<T>? controller;
    StreamSubscription? subscription;

    void startListen() {
      try {
        final stream = _sb
            .from(table)
            .stream(primaryKey: ['id'])
            .eq(columnFilter, valueFilter);
        subscription = stream.listen(
          (rows) {
            // Loại bỏ trùng lặp id ở client nếu Supabase stream phát duplicate rows
            final uniqueRows = <String, Map<String, dynamic>>{};
            for (final r in rows) {
              final id = r['id'] as String?;
              if (id != null) {
                uniqueRows[id] = r;
              }
            }
            final cleanRows = uniqueRows.values.toList();

            print(
              '[RobustStream DEBUG] table=$table rows_count=${cleanRows.length} (original=${rows.length})',
            );
            for (int i = 0; i < cleanRows.length; i++) {
              print(
                '  [$i] id=${cleanRows[i]['id']} product_name=${cleanRows[i]['product_name'] ?? cleanRows[i]['name']} qty=${cleanRows[i]['quantity'] ?? cleanRows[i]['qty']}',
              );
            }
            if (controller != null && !controller.isClosed) {
              controller.add(mapper(cleanRows));
            }
          },
          onError: (e) async {
            print(
              '[RobustStream] Realtime err on $table: $e. Falling back to poll.',
            );
            if (controller == null || controller.isClosed) return;

            // Fallback immediately
            try {
              final rows = await _sb
                  .from(table)
                  .select()
                  .eq(columnFilter, valueFilter);
              final uniqueRows = <String, Map<String, dynamic>>{};
              for (final r in rows) {
                final id = r['id'] as String?;
                if (id != null) {
                  uniqueRows[id] = r;
                }
              }
              final cleanRows = uniqueRows.values.toList();
              if (controller != null && !controller.isClosed) {
                controller.add(mapper(cleanRows));
              }
            } catch (_) {}

            // Reconnect after 10 seconds if not disposed
            await Future.delayed(const Duration(seconds: 10));
            if (controller != null && !controller.isClosed) {
              subscription?.cancel();
              startListen();
            }
          },
          cancelOnError: false,
        );
      } catch (e) {
        print('[RobustStream] Connection err: $e');
      }
    }

    controller = StreamController<T>.broadcast(
      onListen: () {
        startListen();
      },
      onCancel: () {
        subscription?.cancel();
        subscription = null;
        controller?.close();
      },
    );

    return controller.stream;
  }

  // ── Zones ─────────────────────────────────────────────────────────────────
  Stream<List<BanZoneModel>> watchZones() async* {
    while (true) {
      final storeId = await _storeId();
      if (storeId == null) {
        yield [];
      } else {
        try {
          const kSysPosZoneId = '00000000-0000-0000-0001-000000000001';
          final rows = await _sb
              .from('ban_zones')
              .select()
              .eq('store_id', storeId)
              .eq('is_active', true)
              .neq('id', kSysPosZoneId)
              .order('sort_order');
          final zones = rows.map(BanZoneModel.fromMap).toList();
          yield zones;
        } catch (e) {
          debugPrint('[BanRepository] watchZones error: $e');
          yield [];
        }
      }
      // Poll every 15 seconds
      await Future.delayed(const Duration(seconds: 15));
    }
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
    while (true) {
      final storeId = await _storeId();
      if (storeId == null) {
        yield [];
      } else {
        try {
          final rows = await _sb
              .from('ban_dining_tables')
              .select()
              .eq('store_id', storeId)
              .eq('zone_id', zoneId)
              .eq('is_active', true);
          final tables = rows.map(BanTableModel.fromMap).toList()
            ..sort((a, b) => compareNatural(a.label, b.label));
          yield tables;
        } catch (e) {
          debugPrint('[BanRepository] watchTablesForZone error: $e');
          yield [];
        }
      }
      // Poll every 12 seconds
      await Future.delayed(const Duration(seconds: 12));
    }
  }

  Stream<List<BanTableModel>> watchAllTables() async* {
    while (true) {
      final storeId = await _storeId();
      if (storeId == null) {
        yield [];
      } else {
        try {
          final rows = await _sb
              .from('ban_dining_tables')
              .select()
              .eq('store_id', storeId)
              .eq('is_active', true);
          final tables = rows.map(BanTableModel.fromMap).toList()
            ..sort((a, b) => compareNatural(a.label, b.label));
          yield tables;
        } catch (e) {
          debugPrint('[BanRepository] watchAllTables error: $e');
          yield [];
        }
      }
      // Poll every 12 seconds
      await Future.delayed(const Duration(seconds: 12));
    }
  }

  Future<void> upsertTable(BanTableModel table) async =>
      _sb.from('ban_dining_tables').upsert({
        'id': table.id, 'zone_id': table.zoneId, 'store_id': table.storeId,
        'name': table.label, // DB có 'name', không phải 'label'
        'capacity': table.seats, // DB có 'capacity', không phải 'seats'
        'sort_order': table.sortOrder,
        'is_active': table.isActive,
        'pos_x': table.posX ?? 100.0, // NOT NULL trong DB — dùng default 100
        'pos_y': table.posY ?? 100.0, // NOT NULL trong DB — dùng default 100
      });

  Future<void> deactivateTable(String id) async =>
      _sb.from('ban_dining_tables').update({'is_active': false}).eq('id', id);

  Future<void> updateTablePosition(String id, double x, double y) async => _sb
      .from('ban_dining_tables')
      .update({'pos_x': x, 'pos_y': y})
      .eq('id', id);

  // ── Sessions ───────────────────────────────────────────────────────────────
  Stream<Map<String, BanSessionModel>> watchActiveSessions() async* {
    while (true) {
      final storeId = await _storeId();
      if (storeId == null) {
        yield {};
      } else {
        try {
          final rows = await _sb
              .from('ban_sessions')
              .select()
              .eq('store_id', storeId)
              .eq('status', 'open');
          final sessions = rows.map(BanSessionModel.fromMap).toList();
          yield {for (final s in sessions) s.tableId: s};
        } catch (e) {
          debugPrint('[BanRepository] watchActiveSessions fetch error: $e');
          yield {};
        }
      }
      // Poll every 8 seconds
      await Future.delayed(const Duration(seconds: 8));
    }
  }

  Future<BanSessionModel> openSession(
    String tableId, {
    int guestCount = 1,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    // ‼️ FIX Bug #33: idempotency guard — kiểm tra session đang mở trước khi tạo mới
    // Tránh double-tap hoặc network retry tạo 2 session cùng 1 bàn
    final existing = await _sb
        .from('ban_sessions')
        .select(
          'id, table_id, store_id, status, opened_at, closed_at, total_amount, guest_count, waiter_id',
        )
        .eq('store_id', storeId)
        .eq('table_id', tableId)
        .eq('status', 'open')
        .maybeSingle();
    if (existing != null) return BanSessionModel.fromMap(existing);

    // Tìm store_members.id và đồng bộ sang staff_members để làm khoá ngoại cho ban_sessions.waiter_id
    String? waiterRecordId;
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentStaffId =
          prefs.getString('auth_staff_id') ?? prefs.getString('auth_user_id');
      if (currentStaffId != null) {
        final staffRow = await _sb
            .from('staff_members')
            .select('id')
            .eq('id', currentStaffId)
            .maybeSingle();

        if (staffRow != null) {
          waiterRecordId = staffRow['id'] as String?;
        } else {
          final memberRow = await _sb
              .from('store_members')
              .select('id, role, user_accounts(display_name, phone)')
              .eq('store_id', storeId)
              .eq('user_id', currentStaffId)
              .maybeSingle();

          if (memberRow != null) {
            waiterRecordId = memberRow['id'] as String?;
            final userAcc = memberRow['user_accounts'] as Map<String, dynamic>?;
            final displayName = userAcc?['display_name'] as String? ?? 'Waiter';
            final phone = userAcc?['phone'] as String?;
            final role = memberRow['role'] as String? ?? 'waiter';

            if (waiterRecordId != null) {
              await _sb.from('staff_members').upsert({
                'id': waiterRecordId,
                'store_id': storeId,
                'name': displayName,
                'role': role,
                'phone': phone,
                'is_active': true,
                'updated_at': DateTime.now().millisecondsSinceEpoch,
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[BanRepository] Sync waiter record failed: $e');
    }

    final id = const Uuid().v4(); // UUID hợp lệ cho ban_sessions.id
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('ban_sessions').insert({
      'id': id,
      'table_id': tableId,
      'store_id': storeId,
      'status': 'open',
      'opened_at': now,
      'total_amount': 0,
      'guest_count': guestCount,
      if (waiterRecordId != null) 'waiter_id': waiterRecordId,
    });
    return BanSessionModel(
      id: id,
      tableId: tableId,
      storeId: storeId,
      status: 'open',
      openedAt: DateTime.now().millisecondsSinceEpoch,
      totalAmount: 0,
      guestCount: guestCount,
      waiterId: waiterRecordId,
    );
  }

  Future<void> closeSession(String sessionId, double totalAmount) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb
        .from('ban_sessions')
        .update({
          'status': 'closed',
          'closed_at': now,
          'total_amount': totalAmount,
        })
        .eq('id', sessionId);
  }

  // ── Session Items ──────────────────────────────────────────────────────────
  Stream<List<BanSessionItemModel>> watchSessionItems(String sessionId) async* {
    while (true) {
      try {
        final rows = await _sb
            .from('ban_session_items')
            .select()
            .eq('session_id', sessionId);
        final items = rows.map(BanSessionItemModel.fromMap).toList()
          ..sort((a, b) => a.addedAt.compareTo(b.addedAt));
        yield items;
      } catch (e) {
        debugPrint('[BanRepository] watchSessionItems error: $e');
        yield [];
      }
      await Future.delayed(const Duration(seconds: 5));
    }
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
    await addSessionItems(
      sessionId: sessionId,
      items: [
        {
          'productId': productId,
          'productName': productName,
          'price': price,
          'quantity': quantity,
          'note': note,
          'modifiersJson': modifiersJson,
        },
      ],
    );
  }

  // Khóa chống Race Condition cho mỗi session_id khi thêm món
  static final Set<String> _activeSessionWrites = {};

  Future<void> addSessionItems({
    required String sessionId,
    required List<Map<String, dynamic>> items,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');

    // Chờ nếu có tác vụ ghi khác đang diễn ra cho session này
    while (_activeSessionWrites.contains(sessionId)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _activeSessionWrites.add(sessionId);

    try {
      // 1. Thử gọi RPC add_session_items để đảm bảo tính nguyên tử ở tầng database
      try {
        await _sb.rpc(
          'add_session_items',
          params: {
            'p_store_id': storeId,
            'p_session_id': sessionId,
            'p_items': items,
          },
        );
        return; // Thành công thì kết thúc luôn
      } catch (rpcError) {
        print(
          '[BanRepository] RPC add_session_items failed, falling back to client-side. Error: $rpcError',
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();

      // 2. Fallback: Lấy tất cả items của session để thực hiện gộp trùng ở client
      final List<dynamic> allRows = await _sb
          .from('ban_session_items')
          .select()
          .eq('session_id', sessionId);

      // Lọc ra các món nháp chưa gửi bếp (bao gồm chua_gui, pending, null)
      final List<Map<String, dynamic>> existingRows = allRows
          .map((r) => r as Map<String, dynamic>)
          .where((r) {
            final status = r['kitchen_status'];
            return status == null ||
                status == 'chua_gui' ||
                status == 'pending';
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
          final sameMods = _areModifiersEqual(extMods, modifiersJson);

          final extPrice =
              (ext['unit_price'] as num?)?.toDouble() ??
              (ext['price'] as num?)?.toDouble() ??
              0.0;
          final samePrice = (extPrice - price).abs() < 0.01;

          if (sameProduct && samePrice && sameNote && sameMods) {
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
            _sb
                .from('ban_session_items')
                .update({'quantity': newQty, 'subtotal': newSubtotal})
                .eq('id', itemId),
          );
        } else {
          // Tạo dòng mới
          final id = const Uuid().v4();
          insertRows.add({
            'id': id,
            'store_id': storeId,
            'session_id': sessionId,
            'product_id': productId,
            'product_name': productName,
            'unit_price': price,
            'quantity': quantity,
            'subtotal': price * quantity,
            'note': (note == null || note.trim().isEmpty) ? null : note.trim(),
            'modifiers_json':
                (modifiersJson == null || modifiersJson.trim().isEmpty)
                ? null
                : modifiersJson.trim(),
            'added_at': now,
            'kitchen_status': 'chua_gui',
          });
        }
      }

      // 3. Thực thi Batch Insert các món mới
      if (insertRows.isNotEmpty) {
        await _sb.from('ban_session_items').insert(insertRows);
      }

      // 4. Thực thi Parallel Updates các món được gộp
      if (updateFutures.isNotEmpty) {
        await Future.wait(updateFutures);
      }
    } finally {
      _activeSessionWrites.remove(sessionId);
    }
  }

  Future<void> removeSessionItem(String itemId) async =>
      _sb.from('ban_session_items').delete().eq('id', itemId);

  Future<void> updateSessionTotal(String sessionId, double total) async => _sb
      .from('ban_sessions')
      .update({'total_amount': total})
      .eq('id', sessionId);

  // ── Chuyển bàn ────────────────────────────────────────────────────────────
  /// Chuyển toàn bộ session (và tất cả items) sang bàn khác.
  /// Items không cần di chuyển vì chúng link qua session_id, không phải table_id.
  Future<void> transferSession(String sessionId, String newTableId) async {
    await _sb
        .from('ban_sessions')
        .update({'table_id': newTableId})
        .eq('id', sessionId);

    AppLogger.logUserAction(
      tag: 'order',
      action: 'Chuyển bàn [Session $sessionId sang Bàn mới]',
      details: {'session_id': sessionId, 'new_table_id': newTableId},
    );
  }

  /// Gộp bàn: Chuyển toàn bộ món từ sourceSessionId sang targetSessionId và đóng sourceSessionId.
  Future<void> mergeSession({
    required String sourceSessionId,
    required String targetTableId,
    String? targetSessionId,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) return;

    if (targetSessionId == null || targetSessionId.isEmpty) {
      // Bàn đích chưa có session -> Chuyển bàn
      await transferSession(sourceSessionId, targetTableId);
      return;
    }

    AppLogger.logUserAction(
      tag: 'order',
      action:
          'Gộp bàn [Gộp Session $sourceSessionId vào Session $targetSessionId]',
      details: {
        'source_session_id': sourceSessionId,
        'target_session_id': targetSessionId,
        'target_table_id': targetTableId,
      },
    );

    // 1. Chuyển toàn bộ món từ session nguồn sang session đích
    await _sb
        .from('ban_session_items')
        .update({'session_id': targetSessionId})
        .eq('session_id', sourceSessionId);

    // 2. Đóng session nguồn
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb
        .from('ban_sessions')
        .update({'status': 'closed', 'closed_at': now, 'total_amount': 0})
        .eq('id', sourceSessionId);

    // 3. Tính lại tổng tiền của session đích
    try {
      final items = await _sb
          .from('ban_session_items')
          .select('subtotal')
          .eq('session_id', targetSessionId);
      double total = 0;
      for (final r in items) {
        total += (r['subtotal'] as num? ?? 0).toDouble();
      }
      await updateSessionTotal(targetSessionId, total);
    } catch (e) {
      debugPrint('[BanRepository] mergeSession update total err: $e');
    }
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

  /// Quyết toán mọi phiên bàn bằng đúng một transaction server-side V5.
  /// Single-flight chặn hai request đồng thời cho cùng một bàn ngay cả khi UI
  /// vô tình phát hai callback.
  Future<Map<String, dynamic>> settleBanSession({
    required String sessionId,
    required String storeId,
    required String paymentMethod,
    required String idempotencyKey,
    String? customerId,
    int pointsUsed = 0,
    double discount = 0,
    String? couponCode,
    double surcharge = 0,
  }) {
    final flightScope = '$storeId:$sessionId';
    final existing = _settlementFlights[flightScope];
    if (existing != null) {
      if (_settlementFlightKeys[flightScope] == idempotencyKey) return existing;
      return Future.value({
        'success': false,
        'error_code': 'CHECKOUT_IN_PROGRESS',
        'message': 'Bàn này đang được xử lý thanh toán. Vui lòng chờ.',
      });
    }

    final flight = _settleBanSessionV5(
      sessionId: sessionId,
      storeId: storeId,
      paymentMethod: paymentMethod,
      idempotencyKey: idempotencyKey,
      customerId: customerId,
      pointsUsed: pointsUsed,
      discount: discount,
      couponCode: couponCode,
      surcharge: surcharge,
    );
    _settlementFlights[flightScope] = flight;
    _settlementFlightKeys[flightScope] = idempotencyKey;
    return flight.whenComplete(() {
      if (identical(_settlementFlights[flightScope], flight)) {
        _settlementFlights.remove(flightScope);
        _settlementFlightKeys.remove(flightScope);
      }
    });
  }

  Future<Map<String, dynamic>> _settleBanSessionV5({
    required String sessionId,
    required String storeId,
    required String paymentMethod,
    required String idempotencyKey,
    String? customerId,
    int pointsUsed = 0,
    double discount = 0,
    String? couponCode,
    double surcharge = 0,
  }) async {
    try {
      final res = await _sb.rpc(
        'settle_ban_session_v5',
        params: {
          'p_session_id': sessionId,
          'p_store_id': storeId,
          'p_payment_method': paymentMethod,
          'p_idempotency_key': idempotencyKey,
          'p_customer_id': customerId,
          'p_points_used': pointsUsed,
          'p_discount': discount,
          'p_coupon_code': couponCode,
          'p_surcharge': surcharge,
        },
      );

      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return {
        'success': false,
        'error_code': 'RPC_ERROR',
        'message': 'Quyết toán phiên bàn thất bại',
      };
    } catch (e) {
      debugPrint('[BanRepository] settleBanSession error: $e');
      final reconciled = await reconcileBanSettlement(
        sessionId: sessionId,
        storeId: storeId,
        idempotencyKey: idempotencyKey,
      );
      if (reconciled['success'] == true) return reconciled;
      return {
        'success': false,
        'error_code': 'NETWORK_UNCERTAIN',
        'message':
            'Chưa xác định được trạng thái thanh toán. Không bấm lại với nội dung khác; hãy thử lại để hệ thống đối soát.',
      };
    }
  }

  Future<Map<String, dynamic>> reconcileBanSettlement({
    required String sessionId,
    required String storeId,
    required String idempotencyKey,
  }) async {
    try {
      final res = await _sb.rpc(
        'reconcile_ban_settlement_v1',
        params: {
          'p_store_id': storeId,
          'p_session_id': sessionId,
          'p_idempotency_key': idempotencyKey,
        },
      );
      if (res is Map) return Map<String, dynamic>.from(res);
    } catch (e) {
      debugPrint('[BanRepository] reconcileBanSettlement error: $e');
    }
    return {
      'success': false,
      'error_code': 'NOT_RECONCILED',
      'message': 'Chưa tìm thấy kết quả quyết toán đã commit.',
    };
  }
}

int _toMs(dynamic val) {
  if (val is int) return val;
  if (val is String) return DateTime.tryParse(val)?.millisecondsSinceEpoch ?? 0;
  return 0;
}

int compareNatural(String a, String b) {
  final regExp = RegExp(r'(\d+|\D+)');
  final aParts = regExp.allMatches(a).map((m) => m.group(0)!).toList();
  final bParts = regExp.allMatches(b).map((m) => m.group(0)!).toList();

  final minLen = aParts.length < bParts.length ? aParts.length : bParts.length;
  for (int i = 0; i < minLen; i++) {
    final aPart = aParts[i];
    final bPart = bParts[i];

    if (aPart != bPart) {
      final aIsDigit = RegExp(r'^\d+$').hasMatch(aPart);
      final bIsDigit = RegExp(r'^\d+$').hasMatch(bPart);

      if (aIsDigit && bIsDigit) {
        final aNum = int.parse(aPart);
        final bNum = int.parse(bPart);
        return aNum.compareTo(bNum);
      }
      return aPart.compareTo(bPart);
    }
  }
  return aParts.length.compareTo(bParts.length);
}
