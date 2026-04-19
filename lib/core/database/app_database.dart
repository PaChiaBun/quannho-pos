import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';
import 'tables/core_tables.dart';
import 'tables/pos_tables.dart';
import 'tables/kho_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/loyalty_tables.dart';

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// APP DATABASE — Drift database class
// Bao gồm tất cả tables của tất cả modules trong 1 file DB duy nhất
// ─────────────────────────────────────────────────────────────────────────────
@DriftDatabase(tables: [
  // CORE
  ModuleConfigs,
  CoreProducts,
  CoreCustomers,
  AppSettings,
  EventsLog,
  PendingEvents,
  // POS
  PosOrders,
  PosOrderItems,
  // KHO
  KhoStockMovements,
  KhoRecipes,
  KhoRecipeItems,
  KhoSuppliers,
  KhoPurchaseOrders,
  KhoPurchaseItems,
  // FINANCE
  FinanceCategories,
  FinanceRecords,
  // LOYALTY
  LoyaltyTransactions,
  LoyaltyRewards,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor dành riêng cho unit tests — dùng in-memory DB
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedInitialData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Migration tương lai — thêm bảng/cột ở đây
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEED DATA — Dữ liệu ban đầu khi cài app lần đầu
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _seedInitialData() async {
    const uuid = Uuid();
    final now = DateTime.now().millisecondsSinceEpoch;

    // 1. Module configs — Lego modules mặc định
    final modules = [
      ('pos', 0),
      ('kho', 1),
      ('finance', 2),
      ('report', 3),
      ('loyalty', 4),
    ];
    for (final (id, position) in modules) {
      await into(moduleConfigs).insert(ModuleConfigsCompanion(
        id: Value(id),
        isActive: const Value(true),
        position: Value(position),
        updatedAt: Value(now),
      ));
    }

    // 2. App settings — Cài đặt mặc định
    final settings = {
      'shop_name': 'Quán Nhỏ',
      'receipt_enabled': 'false',
      'tax_rate': '0',
      'loyalty_rate': '10000', // 10.000đ = 1 điểm
      'currency': 'VND',
    };
    for (final entry in settings.entries) {
      await into(appSettings).insert(AppSettingsCompanion(
        key: Value(entry.key),
        value: Value(entry.value),
      ));
    }

    // 3. Finance categories — Danh mục thu chi mặc định
    final incomeCategories = [
      ('Bán hàng', '🛒', '#4CAF50'),
      ('Thu khác', '💰', '#2196F3'),
    ];
    final expenseCategories = [
      ('Nhập hàng', '📦', '#FF9800'),
      ('Lương nhân viên', '👨‍💼', '#9C27B0'),
      ('Thuê mặt bằng', '🏠', '#F44336'),
      ('Điện nước', '💡', '#00BCD4'),
      ('Chi khác', '📝', '#607D8B'),
    ];

    for (final (name, icon, color) in incomeCategories) {
      await into(financeCategories).insert(FinanceCategoriesCompanion(
        id: Value(uuid.v4()),
        name: Value(name),
        type: const Value('income'),
        icon: Value(icon),
        color: Value(color),
        isSystem: const Value(true),
      ));
    }

    for (final (name, icon, color) in expenseCategories) {
      await into(financeCategories).insert(FinanceCategoriesCompanion(
        id: Value(uuid.v4()),
        name: Value(name),
        type: const Value('expense'),
        icon: Value(icon),
        color: Value(color),
        isSystem: const Value(true),
      ));
    }

    // 4. Sample products — Dữ liệu mẫu để demo
    final sampleProducts = [
      ('Cà phê đen', 'CF001', 'Đồ uống', 'ly', 'finished', 25000.0, 8000.0),
      ('Cà phê sữa', 'CF002', 'Đồ uống', 'ly', 'finished', 30000.0, 10000.0),
      ('Bánh mì', 'BM001', 'Đồ ăn', 'cái', 'finished', 20000.0, 10000.0),
      ('Nước suối', 'NS001', 'Đồ uống', 'chai', 'finished', 10000.0, 5000.0),
      ('Trà sữa', 'TS001', 'Đồ uống', 'ly', 'finished', 35000.0, 12000.0),
    ];

    for (final (name, sku, cat, unit, type, sell, cost) in sampleProducts) {
      await into(coreProducts).insert(CoreProductsCompanion(
        id: Value(uuid.v4()),
        name: Value(name),
        sku: Value(sku),
        category: Value(cat),
        unit: Value(unit),
        productType: Value(type),
        stockQty: const Value(100),
        minStock: const Value(10),
        sellPrice: Value(sell),
        costPrice: Value(cost),
        isAvailable: const Value(true),
        isActive: const Value(true),
        isDeleted: const Value(false),
        version: const Value(0),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPER — Mở kết nối SQLite
  // ─────────────────────────────────────────────────────────────────────────
  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'quannho_pos');
  }
}
