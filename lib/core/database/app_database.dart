import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:uuid/uuid.dart';
import 'tables/core_tables.dart';
import 'tables/pos_tables.dart';
import 'tables/kho_tables.dart';
import 'tables/finance_tables.dart';
import 'tables/loyalty_tables.dart';
import 'tables/ban_tables.dart';
import 'tables/kitchen_tables.dart';
import 'tables/staff_tables.dart';

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
  // BAN MANAGEMENT
  BanZones,
  BanDiningTables,
  BanSessions,
  BanSessionItems,
  // KITCHEN — Module Phíu bếp
  KitchenStations,
  ProductModifiers,
  SessionItemModifiers,
  KitchenTickets,
  KitchenTicketItems,
  // STAFF — Bảng local đã xóa (v13). Xem Supabase: staff_shifts, store_members, store_roles
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  /// Constructor dành riêng cho unit tests — dùng in-memory DB
  AppDatabase.forTesting(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 13;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedInitialData();
      },
      beforeOpen: (details) async {
        // Đảm bảo module kitchen luôn tồn tại trong DB
        final existingKitchen = await (select(moduleConfigs)
              ..where((m) => m.id.equals('kitchen')))
            .getSingleOrNull();
        if (existingKitchen == null) {
          await into(moduleConfigs).insert(ModuleConfigsCompanion(
            id: const Value('kitchen'),
            isActive: const Value(true),
            position: const Value(11),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ));
        }
        // Đảm bảo module staff luôn tồn tại trong DB
        final existingStaff = await (select(moduleConfigs)
              ..where((m) => m.id.equals('staff')))
            .getSingleOrNull();
        if (existingStaff == null) {
          await into(moduleConfigs).insert(ModuleConfigsCompanion(
            id: const Value('staff'),
            isActive: const Value(true),
            position: const Value(12),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ));
        }
        // Xóa row 'nhan_vien' cũ (tên sai từ migration v11 ban đầu)
        // → tránh ô trống vô hình trong module grid
        await (delete(moduleConfigs)
              ..where((m) => m.id.equals('nhan_vien')))
            .go();

        // Đảm bảo module chamcong luôn tồn tại trong DB
        final existingChamCong = await (select(moduleConfigs)
              ..where((m) => m.id.equals('chamcong')))
            .getSingleOrNull();
        if (existingChamCong == null) {
          await into(moduleConfigs).insert(ModuleConfigsCompanion(
            id: const Value('chamcong'),
            isActive: const Value(false), // mặc định tắt — chủ quán bật thủ công
            position: const Value(13),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ));
        }
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // v1 → v2: Tạo bảng module Quản lý Bàn
        if (from < 2) {
          await m.createTable(banZones);
          await m.createTable(banDiningTables);
          await m.createTable(banSessions);
          await m.createTable(banSessionItems);
          await into(moduleConfigs).insertOnConflictUpdate(
            ModuleConfigsCompanion(
              id: const Value('ban'), // sẽ được đổi ở v3
              isActive: const Value(false),
              position: const Value(10),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
        // v2 → v3: Sửa lỗi module id 'ban' → 'table' khớp với kModuleConfigs
        if (from < 3) {
          await (delete(moduleConfigs)
                ..where((t) => t.id.equals('ban')))
              .go();
          await into(moduleConfigs).insertOnConflictUpdate(
            ModuleConfigsCompanion(
              id: const Value('table'),
              isActive: const Value(false),
              position: const Value(10),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
        // v3 → v4: Thêm cột canvas & shape cho Lego floor plan
        if (from < 4) {
          // BanZones: thêm canvas boundary + đổi icon sang iconCode
          await m.addColumn(banZones, banZones.iconCode);
          await m.addColumn(banZones, banZones.canvasX);
          await m.addColumn(banZones, banZones.canvasY);
          await m.addColumn(banZones, banZones.canvasWidth);
          await m.addColumn(banZones, banZones.canvasHeight);
          // BanDiningTables: thêm vị trí tự do + hình dạng
          await m.addColumn(banDiningTables, banDiningTables.posX);
          await m.addColumn(banDiningTables, banDiningTables.posY);
          await m.addColumn(banDiningTables, banDiningTables.shape);
          await m.addColumn(banDiningTables, banDiningTables.tableWidth);
          await m.addColumn(banDiningTables, banDiningTables.tableHeight);
        }
        // v4 → v5: Universal source link trong PosOrders (extensible architecture)
        if (from < 5) {
          await m.addColumn(posOrders, posOrders.sourceType);
          await m.addColumn(posOrders, posOrders.sourceId);
        }
        // v5 → v6: Module Phíu bếp
        if (from < 6) {
          // Thêm trạng thái bếp vào bảng món gọi
          await m.addColumn(banSessionItems, banSessionItems.kitchenStatus);
          // Tạo 5 bảng mới của module bếp
          await m.createTable(kitchenStations);
          await m.createTable(productModifiers);
          await m.createTable(sessionItemModifiers);
          await m.createTable(kitchenTickets);
          await m.createTable(kitchenTicketItems);
          // Seed: Tạo khu bếp mặc định
          final now = DateTime.now().millisecondsSinceEpoch;
          await into(kitchenStations).insert(KitchenStationsCompanion(
            id: const Value('station-default'),
            name: const Value('Bếp chính'),
            color: const Value('#FF6B35'),
            sortOrder: const Value(0),
            createdAt: Value(now),
          ));
          // Đăng ký module phíu bếp
          await into(moduleConfigs).insertOnConflictUpdate(
            ModuleConfigsCompanion(
              id: const Value('kitchen'),
              isActive: const Value(true),
              position: const Value(11),
              updatedAt: Value(now),
            ),
          );
        }
        // v6 → v7: Bật module kitchen cho user đã có DB
        if (from < 7) {
          await (update(moduleConfigs)
                ..where((m) => m.id.equals('kitchen')))
              .write(ModuleConfigsCompanion(
            isActive: const Value(true),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ));
        }
        // v7 → v8: Thêm ghi chú bếp + lịch sử sửa món
        if (from < 8) {
          await m.addColumn(kitchenTicketItems, kitchenTicketItems.kitchenNote);
          await m.addColumn(kitchenTicketItems, kitchenTicketItems.editHistoryJson);
        }
        // v8 → v9: Thêm stationCode để phân loại bếp nóng/bếp nước
        if (from < 9) {
          // Dùng try/catch: nếu column đã tồn tại (DB state không nhất quán) thì bỏ qua
          try {
            await m.addColumn(kitchenTicketItems, kitchenTicketItems.stationCode);
          } catch (_) {
            // Column station_code đã có rồi → không cần thêm
          }
          // Ép tất cả rows cũ về 'nong' (SQLite ALTER TABLE không tự set DEFAULT cho existing rows)
          await customStatement(
            "UPDATE kitchen_ticket_items SET station_code = 'nong' WHERE station_code IS NULL OR station_code = ''"
          );
          // Seed 2 trạm mặc định nếu chưa có
          final now9 = DateTime.now().millisecondsSinceEpoch;
          await into(kitchenStations).insertOnConflictUpdate(KitchenStationsCompanion(
            id: const Value('bep-nong'),
            name: const Value('Bếp nóng'),
            color: const Value('#FF6B35'),
            sortOrder: const Value(0),
            createdAt: Value(now9),
          ));
          await into(kitchenStations).insertOnConflictUpdate(KitchenStationsCompanion(
            id: const Value('bep-nuoc'),
            name: const Value('Bếp nước'),
            color: const Value('#3B82F6'),
            sortOrder: const Value(1),
            createdAt: Value(now9),
          ));
        }
        // v9 → v10: ép stationCode cũ về 'nong' (fix SQLite DEFAULT không apply cho existing rows)
        if (from < 10) {
          await customStatement(
            "UPDATE kitchen_ticket_items SET station_code = 'nong' WHERE station_code IS NULL OR station_code = ''"
          );
        }
        // v10 → v11: Module Nhân viên — bảng SQLite đã xóa ở v13
        // Chỉ giữ addColumn staffId (cần cho pos_orders) và seed module config
        if (from < 11) {
          // Bỏ qua createTable staff_members/staff_shifts/staff_permissions (xóa v13)
          // Thêm staffId (nullable) vào pos_orders — vẫn cần
          try { await m.addColumn(posOrders, posOrders.staffId); } catch (_) {}
          // Đăng ký module staff
          await into(moduleConfigs).insertOnConflictUpdate(
            ModuleConfigsCompanion(
              id: const Value('staff'),
              isActive: const Value(true),
              position: const Value(12),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
        // v11 → v12: Module Chấm công
        if (from < 12) {
          await into(moduleConfigs).insertOnConflictUpdate(
            ModuleConfigsCompanion(
              id: const Value('chamcong'),
              isActive: const Value(false),
              position: const Value(13),
              updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
            ),
          );
        }
        // v12 → v13: Xóa 3 bảng legacy (dùng Supabase thay thế)
        if (from < 13) {
          await customStatement('DROP TABLE IF EXISTS staff_members');
          await customStatement('DROP TABLE IF EXISTS staff_shifts');
          await customStatement('DROP TABLE IF EXISTS staff_permissions');
        }
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
      ('table', 10),    // Module Quản lý Bàn — mặc định inactive
      ('kitchen', 11),  // Module Phiếu bếp
      ('staff', 12),    // Module Nhân viên
      ('chamcong', 13), // Module Chấm công — mặc định inactive
    ];
    for (final (id, position) in modules) {
      await into(moduleConfigs).insert(ModuleConfigsCompanion(
        id: Value(id),
        isActive: Value(id != 'table'), // chỉ table mặc định tắt
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
