import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/app_database.dart';
import '../../../core/event_bus/app_event_bus.dart';
import '../../../core/event_bus/app_events.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE REPOSITORY — Module Finance đọc/ghi finance_records + categories
// Nhận SaleCompletedEvent từ POS → tự ghi income record (isAuto=true)
// ─────────────────────────────────────────────────────────────────────────────
class FinanceRepository {
  final AppDatabase _db;
  final AppEventBus _bus;
  final _uuid = const Uuid();

  FinanceRepository(this._db, this._bus);

  // ── Categories ────────────────────────────────────────────────────────────

  Stream<List<FinanceCategory>> watchCategories({String? type}) {
    return (_db.select(_db.financeCategories)
          ..where((c) => type != null ? c.type.equals(type) : const Constant(true))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  Future<List<FinanceCategory>> getCategories({String? type}) {
    return (_db.select(_db.financeCategories)
          ..where((c) => type != null ? c.type.equals(type) : const Constant(true)))
        .get();
  }

  // ── Records — CRUD ────────────────────────────────────────────────────────

  /// Thêm giao dịch thủ công
  Future<String> addRecord({
    required String type,         // 'income' | 'expense'
    required double amount,
    String? categoryId,
    String? description,
    String? referenceId,
    bool isAuto = false,
  }) async {
    final id  = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.financeRecords).insert(FinanceRecordsCompanion(
          id:          Value(id),
          type:        Value(type),
          amount:      Value(amount),
          categoryId:  Value(categoryId),
          description: Value(description),
          referenceId: Value(referenceId),
          isAuto:      Value(isAuto),
          recordedAt:  Value(now),
        ));

    // Emit event
    final eventId = _uuid.v4();
    if (type == 'income') {
      await _bus.emit(
        IncomeRecordedEvent(
          id:        eventId,
          createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          recordId:  id,
          amount:    amount,
          category:  categoryId ?? 'other',
        ),
        targetModules: const [],
      );
    } else {
      await _bus.emit(
        ExpenseRecordedEvent(
          id:        eventId,
          createdAt: DateTime.fromMillisecondsSinceEpoch(now),
          recordId:  id,
          amount:    amount,
          category:  categoryId ?? 'other',
        ),
        targetModules: const [],
      );
    }
    return id;
  }

  /// Xóa giao dịch thủ công (chỉ isAuto=false)
  Future<void> deleteRecord(String id) async {
    await (_db.delete(_db.financeRecords)
          ..where((r) => r.id.equals(id) & r.isAuto.equals(false)))
        .go();
  }

  // ── Records — Streams (reactive) ──────────────────────────────────────────

  /// Tất cả records trong khoảng thời gian
  Stream<List<FinanceRecord>> watchRecords({
    required int from,
    required int to,
    String? type,
  }) {
    return (_db.select(_db.financeRecords)
          ..where((r) =>
              r.recordedAt.isBiggerOrEqualValue(from) &
              r.recordedAt.isSmallerOrEqualValue(to) &
              (type != null ? r.type.equals(type) : const Constant(true)))
          ..orderBy([(r) => OrderingTerm.desc(r.recordedAt)]))
        .watch();
  }

  /// Records gần đây nhất (mặc định 100)
  Stream<List<FinanceRecord>> watchRecentRecords({int limit = 100}) {
    return (_db.select(_db.financeRecords)
          ..orderBy([(r) => OrderingTerm.desc(r.recordedAt)])
          ..limit(limit))
        .watch();
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<FinanceStats> getStats(DateRange range) async {
    final records = await (_db.select(_db.financeRecords)
          ..where((r) =>
              r.recordedAt.isBiggerOrEqualValue(range.from) &
              r.recordedAt.isSmallerOrEqualValue(range.to)))
        .get();

    final income  = records.where((r) => r.type == 'income')
        .fold<double>(0, (s, r) => s + r.amount);
    final expense = records.where((r) => r.type == 'expense')
        .fold<double>(0, (s, r) => s + r.amount);

    // Breakdown theo category
    final categories = await getCategories();
    final catMap = {for (var c in categories) c.id: c.name};

    final expenseByCategory = <String, double>{};
    for (final r in records.where((r) => r.type == 'expense')) {
      final cat = catMap[r.categoryId ?? ''] ?? 'Khác';
      expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) + r.amount;
    }

    // So sánh với kỳ trước
    final prevFrom = range.from - (range.to - range.from);
    final prevRecords = await (_db.select(_db.financeRecords)
          ..where((r) =>
              r.recordedAt.isBiggerOrEqualValue(prevFrom) &
              r.recordedAt.isSmallerOrEqualValue(range.from)))
        .get();
    final prevIncome = prevRecords.where((r) => r.type == 'income')
        .fold<double>(0, (s, r) => s + r.amount);

    return FinanceStats(
      income:  income,
      expense: expense,
      profit:  income - expense,
      prevIncome: prevIncome,
      expenseByCategory: expenseByCategory,
      transactionCount: records.length,
    );
  }

  /// Ghi tự động từ SaleCompletedEvent (gọi từ EventBus handler)
  Future<void> recordFromSale({
    required String orderId,
    required double amount,
    required String categoryId, // 'ban_hang'
  }) async {
    await addRecord(
      type:        'income',
      amount:      amount,
      categoryId:  categoryId,
      description: 'Bán hàng #$orderId',
      referenceId: orderId,
      isAuto:      true,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA MODELS
// ─────────────────────────────────────────────────────────────────────────────

class DateRange {
  final int from;
  final int to;
  final String label;

  const DateRange({
    required this.from,
    required this.to,
    required this.label,
  });

  static DateRange today() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .millisecondsSinceEpoch;
    return DateRange(
      from:  start,
      to:    start + const Duration(hours: 23, minutes: 59, seconds: 59).inMilliseconds,
      label: 'Hôm nay',
    );
  }

  static DateRange thisWeek() {
    final now  = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final start  = DateTime(monday.year, monday.month, monday.day)
        .millisecondsSinceEpoch;
    return DateRange(
      from:  start,
      to:    DateTime.now().millisecondsSinceEpoch,
      label: 'Tuần này',
    );
  }

  static DateRange thisMonth() {
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, 1).millisecondsSinceEpoch;
    return DateRange(
      from:  start,
      to:    DateTime.now().millisecondsSinceEpoch,
      label: 'Tháng này',
    );
  }
}

class FinanceStats {
  final double income;
  final double expense;
  final double profit;
  final double prevIncome;
  final Map<String, double> expenseByCategory;
  final int transactionCount;

  const FinanceStats({
    required this.income,
    required this.expense,
    required this.profit,
    required this.prevIncome,
    required this.expenseByCategory,
    required this.transactionCount,
  });

  double get profitMargin =>
      income > 0 ? (profit / income * 100) : 0;

  double get incomeGrowth =>
      prevIncome > 0 ? ((income - prevIncome) / prevIncome * 100) : 0;

  static const empty = FinanceStats(
    income:  0, expense: 0, profit: 0,
    prevIncome: 0, expenseByCategory: {},
    transactionCount: 0,
  );
}
