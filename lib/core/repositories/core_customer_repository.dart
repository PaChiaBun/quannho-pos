<<<<<<< HEAD
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../services/store_auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CORE CUSTOMER REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class CoreCustomerRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Streams ───────────────────────────────────────────────────────────────

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

  Stream<List<CustomerModel>> watchAll() async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    yield* _robustStream(
      'customers', 'store_id', storeId,
      (rows) => rows
        .where((r) => r['is_deleted'] != true)
        .map(CustomerModel.fromMap)
        .toList()
      ..sort((a, b) => b.totalSpent.compareTo(a.totalSpent))
    );
=======
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../database/app_database.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CORE CUSTOMER REPOSITORY
// ─────────────────────────────────────────────────────────────────────────────
class CoreCustomerRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  CoreCustomerRepository(this._db);

  // ── Streams ───────────────────────────────────────────────────────────────

  Stream<List<CoreCustomer>> watchAll() {
    return (_db.select(_db.coreCustomers)
          ..where((c) => c.isDeleted.equals(false))
          ..orderBy([(c) => OrderingTerm.desc(c.totalSpent)]))
        .watch();
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

<<<<<<< HEAD
  Future<CustomerModel?> getById(String id) async {
    final row = await _sb.from('customers').select().eq('id', id).maybeSingle();
    return row != null ? CustomerModel.fromMap(row) : null;
  }

  Future<CustomerModel?> getByPhone(String phone) async {
    final storeId = await _storeId();
    if (storeId == null) return null;
    final row = await _sb
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .eq('phone', phone)
        .eq('is_deleted', false)
        .maybeSingle();
    return row != null ? CustomerModel.fromMap(row) : null;
=======
  Future<CoreCustomer?> getById(String id) {
    return (_db.select(_db.coreCustomers)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<CoreCustomer?> getByPhone(String phone) {
    return (_db.select(_db.coreCustomers)
          ..where((c) => c.phone.equals(phone) & c.isDeleted.equals(false)))
        .getSingleOrNull();
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  }

  Future<String> create({
    required String name,
    String? phone,
    String? email,
    String? note,
  }) async {
<<<<<<< HEAD
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final id  = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('customers').insert({
      'id':          id,
      'store_id':    storeId,
      'name':        name,
      'phone':       phone,
      'email':       email,
      'note':        note,
      'loyalty_pts': 0,
      'total_spent': 0,
      'visit_count': 0,
      'is_deleted':  false,
      'created_at':  now,
      'updated_at':  now,
    });
    return id;
  }

  Future<void> update(String id, Map<String, dynamic> data) async {
    await _sb.from('customers').update({
      ...data,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
=======
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.coreCustomers).insert(CoreCustomersCompanion(
          id: Value(id),
          name: Value(name),
          phone: Value(phone),
          email: Value(email),
          loyaltyPts: const Value(0),
          totalSpent: const Value(0),
          visitCount: const Value(0),
          note: Value(note),
          isDeleted: const Value(false),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
    return id;
  }

  Future<void> update(String id, CoreCustomersCompanion companion) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.coreCustomers)..where((c) => c.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(now)));
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
  }

  /// Cộng điểm và cập nhật total_spent sau mỗi đơn hàng
  Future<void> recordPurchase(
    String customerId, {
    required double amount,
    required double ptsEarned,
    required double ptsUsed,
  }) async {
    final customer = await getById(customerId);
    if (customer == null) return;
<<<<<<< HEAD
    await update(customerId, {
      'loyalty_pts': (customer.loyaltyPts + ptsEarned - ptsUsed).clamp(0, double.infinity), // ‼️ FIX: clamp(0) — tránh điểm âm nếu dùng điểm vượt
      'total_spent': customer.totalSpent + amount,
      'visit_count': customer.visitCount + 1,
    });
  }

  Future<void> softDelete(String id) async {
    await update(id, {'is_deleted': true});
  }

  Future<List<CustomerModel>> searchByNameOrPhone(String query) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    // Supabase không hỗ trợ OR filter trực tiếp — query 2 lần rồi dedup theo id
    final byName = await _sb
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false)
        .ilike('name', '%$query%')
        .limit(20);
    final byPhone = await _sb
        .from('customers')
        .select()
        .eq('store_id', storeId)
        .eq('is_deleted', false)
        .ilike('phone', '%$query%')
        .limit(20);
    // Dedup theo 'id' — {...list1, ...list2} trên List tạo Set theo object identity, không theo id
    final seenIds = <String>{};
    final merged  = <Map<String, dynamic>>[];
    for (final row in [...byName, ...byPhone]) {
      final id = row['id'] as String? ?? '';
      if (seenIds.add(id)) merged.add(row as Map<String, dynamic>);
    }
    return merged.map(CustomerModel.fromMap).toList();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────
class CustomerModel {
  final String id;
  final String storeId;
  final String name;
  final String? phone;
  final String? email;
  final double loyaltyPts;
  final double totalSpent;
  final int visitCount;
  final String? note;
  final bool isDeleted;

  const CustomerModel({
    required this.id,
    required this.storeId,
    required this.name,
    this.phone,
    this.email,
    required this.loyaltyPts,
    required this.totalSpent,
    required this.visitCount,
    this.note,
    required this.isDeleted,
  });

  factory CustomerModel.fromMap(Map<String, dynamic> m) => CustomerModel(
        id:          m['id'] as String,
        storeId:     m['store_id'] as String? ?? '',
        name:        m['name'] as String,
        phone:       m['phone'] as String?,
        email:       m['email'] as String?,
        loyaltyPts:  (m['loyalty_pts'] as num?)?.toDouble() ?? 0,
        totalSpent:  (m['total_spent'] as num?)?.toDouble() ?? 0,
        visitCount:  (m['visit_count'] as num?)?.toInt() ?? 0,
        note:        m['note'] as String?,
        isDeleted:   m['is_deleted'] as bool? ?? false,
      );
}
=======

    await update(
        customerId,
        CoreCustomersCompanion(
          loyaltyPts:
              Value(customer.loyaltyPts + ptsEarned - ptsUsed),
          totalSpent: Value(customer.totalSpent + amount),
          visitCount: Value(customer.visitCount + 1),
        ));
  }

  Future<void> softDelete(String id) async {
    await update(id, const CoreCustomersCompanion(isDeleted: Value(true)));
  }

  Future<List<CoreCustomer>> searchByNameOrPhone(String query) {
    return (_db.select(_db.coreCustomers)
          ..where((c) =>
              c.isDeleted.equals(false) &
              (c.name.like('%$query%') | c.phone.like('%$query%')))
          ..limit(20))
        .get();
  }
}
>>>>>>> 4bec718df870807743eeb9abb9ea162ca4d749df
