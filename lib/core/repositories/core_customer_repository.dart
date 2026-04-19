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
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<CoreCustomer?> getById(String id) {
    return (_db.select(_db.coreCustomers)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  Future<CoreCustomer?> getByPhone(String phone) {
    return (_db.select(_db.coreCustomers)
          ..where((c) => c.phone.equals(phone) & c.isDeleted.equals(false)))
        .getSingleOrNull();
  }

  Future<String> create({
    required String name,
    String? phone,
    String? email,
    String? note,
  }) async {
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
