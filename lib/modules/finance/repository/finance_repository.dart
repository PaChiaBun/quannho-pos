import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../core/services/store_auth_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/paged_query.dart';

// ─────────────────────────────────────────────────────────────────────────────
// FINANCE REPOSITORY — 100% Supabase
// ─────────────────────────────────────────────────────────────────────────────
class FinanceRepository {
  static SupabaseClient get _sb => Supabase.instance.client;
  final _uuid = const Uuid();

  Future<String?> _storeId() async {
    final info = await StoreAuthService.getStoreInfo();
    return info['store_id'];
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
      'id': id,
      'store_id': storeId,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'is_system': false,
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
    final id = _uuid.v4();
    final now = DateTime.now().toUtc().toIso8601String();
    await _sb.from('finance_records').insert({
      'id': id,
      'store_id': storeId,
      'type': type,
      'amount': amount,
      'category_id': categoryId,
      'description': description,
      'reference_id': referenceId,
      'is_auto': isAuto,
      'recorded_at': now,
      'fund_type': fundType,
    });
    AppLogger.info(
      'checkout',
      'Tao phieu ${type == "income" ? "Thu" : "Chi"} moi: $description - So tien: ${amount.toInt()}d.',
    );
    return id;
  }

  /// Xoá phiếu thu/chi nhập tay qua RPC `delete_manual_finance_record_v1`: chỉ Chủ quán/Quản lý,
  /// bắt buộc [reason]; máy chủ lưu nguyên dòng + người xoá vào `finance_record_deletions`.
  /// Trả về true nếu phiếu đã bị xoá từ lần bấm trước (gọi lại an toàn).
  Future<bool> deleteRecord(String id, {required String reason}) async {
    final storeId = await _storeId();
    if (storeId == null)
      throw const FinanceDeleteException('NO_STORE', 'Chưa chọn quán');
    final raw = await _sb.rpc('delete_manual_finance_record_v1', params: {
      'p_store_id': storeId,
      'p_record_id': id,
      'p_reason': reason.trim()
    });
    if (raw is! Map)
      throw const FinanceDeleteException(
          'BAD_RESPONSE', 'Phản hồi xoá giao dịch không hợp lệ');
    final res = Map<String, dynamic>.from(raw);
    if (res['success'] != true) {
      throw FinanceDeleteException(res['error_code'] as String? ?? 'UNKNOWN',
          res['message'] as String? ?? 'Xoá giao dịch thất bại');
    }
    final data = res['data'] is Map
        ? Map<String, dynamic>.from(res['data'] as Map)
        : const {};
    return data['already_deleted'] == true;
  }

  // ── Records — Queries ─────────────────────────────────────────────────────

  /// Tải ĐỦ phiếu trong khoảng [from, to) (null = không giới hạn), theo trang — máy chủ
  /// chỉ trả tối đa 1.000 dòng mỗi lần nên không phân trang sẽ thiếu (sai số dư sổ quỹ).
  Future<List<FinanceRecordModel>> fetchAllRecords(
      {DateTime? from, DateTime? to}) async {
    final storeId = await _storeId();
    if (storeId == null) throw Exception('Chưa chọn quán');
    const page = 1000;
    final out = <FinanceRecordModel>[];
    for (var offset = 0;; offset += page) {
      var q = _sb.from('finance_records').select().eq('store_id', storeId);
      if (from != null)
        q = q.gte('recorded_at', from.toUtc().toIso8601String());
      if (to != null) q = q.lt('recorded_at', to.toUtc().toIso8601String());
      final rows = await q
          .order('recorded_at', ascending: true)
          .order('id', ascending: true)
          .range(offset, offset + page - 1);
      out.addAll(rows.map(FinanceRecordModel.fromMap));
      if (rows.length < page) break;
    }
    return out;
  }

  Stream<List<FinanceRecordModel>> watchRecords({
    required DateTime from,
    required DateTime to,
    String? type,
    String? fundType,
  }) async* {
    final storeId = await _storeId();
    if (storeId == null) {
      yield [];
      return;
    }

    // Realtime chỉ là tín hiệu; dữ liệu luôn lọc ngày/quỹ ở máy chủ và tải đủ theo trang.
    yield* watchByRefetch(
        table: 'finance_records',
        storeId: storeId,
        fetch: () => _fetchRecords(
      storeId: storeId,
      from: from,
      to: to,
      type: type,
      fundType: fundType,
    ));
  }

  /// Fetch records server-side với filter ngày đúng range — tránh tải toàn bộ về client
  Future<List<FinanceRecordModel>> _fetchRecords({
    required String storeId,
    required DateTime from,
    required DateTime to,
    String? type,
    String? fundType,
  }) async {
    final rows = await fetchAllPages((offset, end) {
    var query = _sb
        .from('finance_records')
        .select()
        .eq('store_id', storeId)
        .gte('recorded_at', from.toUtc().toIso8601String())
        .lt('recorded_at', to.toUtc().toIso8601String());
    if (type != null) query = query.eq('type', type);
      query = fundType != null
          ? query.eq('fund_type', fundType)
          : query.or(kCashBookAllFundsFilter);
      return query
          .order('recorded_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, end);
    });
    return rows.map(FinanceRecordModel.fromMap).toList();
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  Future<FinanceStats> getStats(DateRange range, {String? fundType}) async {
    final storeId = await _storeId();
    if (storeId == null) return FinanceStats.empty;

    // Kỳ này, danh mục và kỳ trước gọi song song: mỗi lượt qua mạng quán ~0,3–1 giây,
    // nối đuôi 3 lượt từng làm số đầu trang Thu Chi hiện chậm (Bò Đen 29/10/2026).
    final rowsF = fetchAllPages((offset, end) {
      var query = _sb
        .from('finance_records')
        // ‼️ FIX Bug #34: chỉ chọn cột cần thiết — tính thẳng từ raw rows, không parse qua model
        .select('id, type, amount, category_id')
        .eq('store_id', storeId)
        .gte('recorded_at', range.from.toUtc().toIso8601String())
        .lt('recorded_at', range.to.toUtc().toIso8601String());
      query = fundType != null
          ? query.eq('fund_type', fundType)
          : query.or(kCashBookAllFundsFilter);
      return query.order('id').range(offset, end);
    });
    final categoriesF = getCategories();
    final periodLen = range.to.difference(range.from);
    final prevFrom = range.from.subtract(periodLen);
    final prevRowsF = fetchAllPages((offset, end) {
    var prevQuery = _sb
        .from('finance_records')
        // ‼️ FIX Bug #34: chỉ cần type + amount cho so sánh kỳ trước
        .select('id, type, amount')
        .eq('store_id', storeId)
        .gte('recorded_at', prevFrom.toUtc().toIso8601String())
        .lt('recorded_at', range.from.toUtc().toIso8601String());
      prevQuery = fundType != null
          ? prevQuery.eq('fund_type', fundType)
          : prevQuery.or(kCashBookAllFundsFilter);
      return prevQuery.order('id').range(offset, end);
    });
    final (rows, categories, prevRows) =
        await (rowsF, categoriesF, prevRowsF).wait;

    double income = 0, expense = 0;
    for (final r in rows) {
      final amt = (r['amount'] as num?)?.toDouble() ?? 0;
      if (r['type'] == 'income') income += amt;
      if (r['type'] == 'expense') expense += amt;
    }

    // Breakdown theo category
    final catMap = {for (var c in categories) c.id: c.name};
    final expenseByCategory = <String, double>{};
    for (final r in rows.where((r) => r['type'] == 'expense')) {
      final cat = catMap[r['category_id'] as String? ?? ''] ?? 'Khác';
      expenseByCategory[cat] =
          (expenseByCategory[cat] ?? 0) +
          ((r['amount'] as num?)?.toDouble() ?? 0);
    }

    // So sánh kỳ trước
    final prevIncome = prevRows
        .where((r) => r['type'] == 'income')
        .fold<double>(
          0,
          (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0),
        );

    return FinanceStats(
      income: income,
      expense: expense,
      profit: income - expense,
      prevIncome: prevIncome,
      expenseByCategory: expenseByCategory,
      transactionCount: rows.length,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA CLASSES
// ─────────────────────────────────────────────────────────────────────────────

/// Bộ lọc quỹ "Tất cả" của sổ Thu Chi: mọi phiếu TRỪ quỹ ví khách (`wallet`).
/// Bán bằng ví không phải tiền vào quán — tiền đã ghi thu lúc nạp ví; cộng cả hai là tính doanh thu
/// hai lần (#8). Giữ phiếu chưa có quỹ (NULL) như trước. Khớp `ledgerFunds('all')` của sổ quỹ CSV.
const kCashBookAllFundsFilter = 'fund_type.is.null,fund_type.neq.wallet';

class FinanceDeleteException implements Exception {
  final String code;
  final String message;
  const FinanceDeleteException(this.code, this.message);
  @override
  String toString() => message;
}

class DateRange {
  final DateTime from;
  final DateTime to;
  final String label;

  const DateRange({required this.from, required this.to, required this.label});

  static DateRange today() {
    final now = DateTime.now();
    final startLocal = DateTime(now.year, now.month, now.day);
    final endLocal = DateTime(now.year, now.month, now.day + 1);
    return DateRange(
      from: startLocal.toUtc(),
      to: endLocal.toUtc(),
      label: 'Hôm nay',
    );
  }

  static DateRange yesterday() {
    final now = DateTime.now();
    final yest = now.subtract(const Duration(days: 1));
    final startLocal = DateTime(yest.year, yest.month, yest.day);
    final endLocal = DateTime(now.year, now.month, now.day);
    return DateRange(
      from: startLocal.toUtc(),
      to: endLocal.toUtc(),
      label: 'Hôm qua',
    );
  }

  static DateRange last7Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 6));
    final startLocal = DateTime(start.year, start.month, start.day);
    final endLocal = DateTime(now.year, now.month, now.day + 1);
    return DateRange(
      from: startLocal.toUtc(),
      to: endLocal.toUtc(),
      label: '7 ngày qua',
    );
  }

  static DateRange thisWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startLocal = DateTime(monday.year, monday.month, monday.day);
    final endLocal = DateTime(startLocal.year, startLocal.month, startLocal.day + 7);
    return DateRange(
      from: startLocal.toUtc(),
      to: endLocal.toUtc(),
      label: 'Tuần này',
    );
  }

  static DateRange thisMonth() {
    final now = DateTime.now();
    final endLocal = DateTime(now.year, now.month + 1, 1);
    return DateRange(
      from: DateTime(now.year, now.month, 1).toUtc(),
      to: endLocal.toUtc(),
      label: 'Tháng này',
    );
  }

  static DateRange last30Days() {
    final now = DateTime.now();
    final start = now.subtract(const Duration(days: 29));
    final startLocal = DateTime(start.year, start.month, start.day);
    final endLocal = DateTime(now.year, now.month, now.day + 1);
    return DateRange(
      from: startLocal.toUtc(),
      to: endLocal.toUtc(),
      label: '30 ngày qua',
    );
  }

  static DateRange lastMonth() {
    final now = DateTime.now();
    final firstDayThisMonth = DateTime(now.year, now.month, 1);
    final lastDayLastMonth = firstDayThisMonth.subtract(
      const Duration(days: 1),
    );
    final firstDayLastMonth = DateTime(
      lastDayLastMonth.year,
      lastDayLastMonth.month,
      1,
    );
    return DateRange(
      from: firstDayLastMonth.toUtc(),
      to: firstDayThisMonth.toUtc(),
      label: 'Tháng trước',
    );
  }

  static DateRange custom(
    DateTime fromDate,
    DateTime toDate, {
    String? customLabel,
  }) {
    final startLocal = DateTime(fromDate.year, fromDate.month, fromDate.day);
    final endLocal = DateTime(toDate.year, toDate.month, toDate.day + 1);
    final labelStr =
        customLabel ??
        '${fromDate.day.toString().padLeft(2, '0')}/${fromDate.month.toString().padLeft(2, '0')} - ${toDate.day.toString().padLeft(2, '0')}/${toDate.month.toString().padLeft(2, '0')}';
    return DateRange(
      from: startLocal.toUtc(),
      to: endLocal.toUtc(),
      label: labelStr,
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
        id: m['id'] as String,
        name: m['name'] as String,
        type: m['type'] as String,
        icon: m['icon'] as String?,
        color: m['color'] as String?,
        isSystem: m['is_system'] as bool? ?? false,
      );
}

class FinanceRecordModel {
  final String id;
  final String? referenceId;
  final String type;
  final double amount;
  final String? categoryId;
  final String? description;
  final bool isAuto;
  final DateTime recordedAt;
  final String fundType;

  const FinanceRecordModel({
    required this.id,
    this.referenceId,
    required this.type,
    required this.amount,
    this.categoryId,
    this.description,
    required this.isAuto,
    required this.recordedAt,
    required this.fundType,
  });

  factory FinanceRecordModel.fromMap(
    Map<String, dynamic> m,
  ) => FinanceRecordModel(
    id: m['id'] as String,
    referenceId: m['reference_id'] as String?,
    type: m['type'] as String,
    amount: (m['amount'] as num).toDouble(),
    categoryId: m['category_id'] as String?,
    description: m['description'] as String?,
    isAuto: m['is_auto'] as bool? ?? false,
    // Parse UTC rồi giữ UTC — UI dùng .toLocal() khi hiển thị (finance_screen.dart line 278, 369)
    recordedAt:
        (DateTime.tryParse(m['recorded_at'] as String? ?? '') ?? DateTime.now())
            .toUtc(),
    fundType: m['fund_type'] as String? ?? 'cash',
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

  double get profitMargin => income > 0 ? (profit / income * 100) : 0;
  double get incomeGrowth =>
      prevIncome > 0 ? ((income - prevIncome) / prevIncome * 100) : 0;

  static const empty = FinanceStats(
    income: 0,
    expense: 0,
    profit: 0,
    prevIncome: 0,
    expenseByCategory: {},
    transactionCount: 0,
  );
}
