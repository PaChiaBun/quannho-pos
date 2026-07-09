import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class FinanceRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'] as String?;
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<List<FinanceCategoryModel>> getCategories({String? type}) async {
    final storeId = await _storeId();
    if (storeId == null) return [];
    var query = _sb.from('finance_categories').select().eq('store_id', storeId);
    if (type != null) query = query.eq('type', type);
    final rows = await query.order('name');
    return rows.map(FinanceCategoryModel.fromMap).toList();
  }

  Future<String> createCategory({
    required String name,
    required String type,
    String? icon,
    String? color,
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final id = _uuid.v4();
    await _sb.from('finance_categories').insert({
      'id': id, 'store_id': storeId, 'name': name,
      'type': type, 'icon': icon, 'color': color, 'is_system': false,
    });
    return id;
  }

  // ── Records — CRUD ────────────────────────────────────────────────────────

  Future<String> addRecord({
    required String type,
    required double amount,
    String? categoryId,
    String? description,
    String? referenceId,
    bool isAuto = false,
    String fundType = 'cash',
  }) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    final id  = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('finance_records').insert({
      'id':           id,
      'store_id':     storeId,
      'type':         type,
      'amount':       amount,
      'category_id':  categoryId,
      'description':  description,
      'reference_id': referenceId,
      'is_auto':      isAuto,
      'recorded_at':  now,
      'fund_type':    fundType,
    });
    AppLogger.info('checkout', 'Tao phieu ${type == "income" ? "Thu" : "Chi"} moi: $description - So tien: ${amount.toInt()}d.');
    return id;
  }

  Future<void> deleteRecord(String id) async {
    // Chỉ xóa giao dịch thủ công
    await _sb.from('finance_records')
        .delete()
        .eq('id', id)
        .eq('is_auto', false);
    AppLogger.info('checkout', 'Xoa phieu thu/chi (ID: $id) thanh cong.');
  }

  // ── Records — Queries ─────────────────────────────────────────────────────

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

  Stream<List<FinanceRecordModel>> watchRecords({
    required DateTime from,
    required DateTime to,
    String? type,
    String? fundType,
  }) async* {
    final storeId = await _storeId();
    if (storeId == null) { yield []; return; }

    // ⚠️ Supabase stream() không hỗ trợ .gte()/.lt() trực tiếp —
    // Dùng polling + emit ngay lần đầu để giảm bandwidth.
    // Tải 1 lần đầu
    yield await _fetchRecords(storeId: storeId, from: from, to: to, type: type, fundType: fundType);

    // Sau đó listen realtime (không filter date ở DB được) — chỉ emit khi có change
    // Dùng stream bắt signal, rồi refetch server-side để đúng range
    await for (final _ in _robustStream('finance_records', 'store_id', storeId, (rows) => rows)) {
      yield await _fetchRecords(storeId: storeId, from: from, to: to, type: type, fundType: fundType);
    }
  }

  /// Fetch records server-side với filter ngày đúng range — tránh tải toàn bộ về client
  Future<List<FinanceRecordModel>> _fetchRecords({
    required String storeId,
    required DateTime from,
    required DateTime to,
    String? type,
    String? fundType,
  }) async {
    var query = _sb
        .from('finance_records')
        .select()
        .eq('store_id', storeId)
        .gte('recorded_at', from.toUtc().toIso8601String())
        .lt('recorded_at', to.toUtc().toIso8601String());
    if (type != null) query = query.eq('type', type);
    if (fundType != null) query = query.eq('fund_type', fundType);
    final rows = await query.order('recorded_at', ascending: false);
    return rows.map(FinanceRecordModel.fromMap).toList();
  }



  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<FinanceStats> getStats(DateRange range, {String? fundType}) async {
    final storeId = await _storeId();
    if (storeId == null) return FinanceStats.empty;

    var query = _sb
        .from('finance_records')
        // ‼️ FIX Bug #34: chỉ chọn cột cần thiết — tính thẳng từ raw rows, không parse qua model
        .select('type, amount, category_id')
        .eq('store_id', storeId)
        .gte('recorded_at', range.from.toUtc().toIso8601String())
        .lt('recorded_at', range.to.toUtc().toIso8601String());
    if (fundType != null) query = query.eq('fund_type', fundType);
    final rows = await query;

    double income = 0, expense = 0;
    for (final r in rows) {
      final amt = (r['amount'] as num?)?.toDouble() ?? 0;
      if (r['type'] == 'income')  income  += amt;
      if (r['type'] == 'expense') expense += amt;
    }

    // Breakdown theo category
    final categories = await getCategories();
    final catMap = {for (var c in categories) c.id: c.name};
    final expenseByCategory = <String, double>{};
    for (final r in rows.where((r) => r['type'] == 'expense')) {
      final cat = catMap[r['category_id'] as String? ?? ''] ?? 'Khác';
      expenseByCategory[cat] = (expenseByCategory[cat] ?? 0) +
          ((r['amount'] as num?)?.toDouble() ?? 0);
    }

    // So sánh kỳ trước
    final periodLen = range.to.difference(range.from);
    final prevFrom  = range.from.subtract(periodLen);
    var prevQuery = _sb
        .from('finance_records')
        // ‼️ FIX Bug #34: chỉ cần type + amount cho so sánh kỳ trước
        .select('type, amount')
        .eq('store_id', storeId)
        .gte('recorded_at', prevFrom.toUtc().toIso8601String())
        .lt('recorded_at', range.from.toUtc().toIso8601String());
    if (fundType != null) prevQuery = prevQuery.eq('fund_type', fundType);
    final prevRows = await prevQuery;
    final prevIncome = prevRows
        .where((r) => r['type'] == 'income')
        .fold<double>(0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));

    return FinanceStats(
      income:            income,
      expense:           expense,
      profit:            income - expense,
      prevIncome:        prevIncome,
      expenseByCategory: expenseByCategory,
      transactionCount:  rows.length,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

class DateRange {
  final DateTime from;
  final DateTime to;
  final String label;

  const DateRange({required this.from, required this.to, required this.label});

  static DateRange today() {
    final now        = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    // to = midnight NGÀY KẾ (exclusive) — cả watchRecords lẫn getStats đều dùng exclusive upper bound
    final endLocal   = DateTime(now.year, now.month, now.day + 1);
    return DateRange(
      from:  startLocal.toUtc(),
      to:    endLocal.toUtc(),
      label: 'Hôm nay',
    );
  }

  static DateRange thisWeek() {
    final now    = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startLocal = DateTime(monday.year, monday.month, monday.day);
    // to = midnight NGÀY MAI (exclusive)
    final endLocal   = DateTime(now.year, now.month, now.day + 1);
    return DateRange(
      from:  startLocal.toUtc(),
      to:    endLocal.toUtc(),
      label: 'Tuần này',
    );
  }

  static DateRange thisMonth() {
    final now = DateTime.now();
    // to = midnight NGÀY MAI (exclusive)
    final endLocal = DateTime(now.year, now.month, now.day + 1);
    return DateRange(
      from:  DateTime(now.year, now.month, 1).toUtc(),
      to:    endLocal.toUtc(),
      label: 'Tháng này',
    );
  }
}

class FinanceCategoryModel {
  final String id;
  final String name;
  final String type;
  final String? icon;
  final String? color;
  final bool isSystem;

  const FinanceCategoryModel({
    required this.id,
    required this.name,
    required this.type,
    this.icon,
    this.color,
    required this.isSystem,
  });

  factory FinanceCategoryModel.fromMap(Map<String, dynamic> m) =>
      FinanceCategoryModel(
        id:       m['id'] as String,
        name:     m['name'] as String,
        type:     m['type'] as String,
        icon:     m['icon'] as String?,
        color:    m['color'] as String?,
        isSystem: m['is_system'] as bool? ?? false,
      );
}

class FinanceRecordModel {
  final String id;
  final String type;
  final double amount;
  final String? categoryId;
  final String? description;
  final bool isAuto;
  final DateTime recordedAt;
  final String fundType;

  const FinanceRecordModel({
    required this.id,
    required this.type,
    required this.amount,
    this.categoryId,
    this.description,
    required this.isAuto,
    required this.recordedAt,
    required this.fundType,
  });

  factory FinanceRecordModel.fromMap(Map<String, dynamic> m) =>
      FinanceRecordModel(
        id:          m['id'] as String,
        type:        m['type'] as String,
        amount:      (m['amount'] as num).toDouble(),
        categoryId:  m['category_id'] as String?,
        description: m['description'] as String?,
        isAuto:      m['is_auto'] as bool? ?? false,
        // Parse UTC rồi giữ UTC — UI dùng .toLocal() khi hiển thị (finance_screen.dart line 278, 369)
        recordedAt:  (DateTime.tryParse(m['recorded_at'] as String? ?? '') ?? DateTime.now()).toUtc(),
        fundType:    m['fund_type'] as String? ?? 'cash',
      );
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

  double get profitMargin   => income > 0 ? (profit / income * 100) : 0;
  double get incomeGrowth   => prevIncome > 0 ? ((income - prevIncome) / prevIncome * 100) : 0;

  static const empty = FinanceStats(
    income: 0, expense: 0, profit: 0, prevIncome: 0,
    expenseByCategory: {}, transactionCount: 0,
  );
}
