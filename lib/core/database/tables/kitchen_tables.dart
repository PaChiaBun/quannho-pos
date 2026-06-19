import 'package:drift/drift.dart';
import 'core_tables.dart';
import 'ban_tables.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODULE PHIẾU BẾP — Kitchen Module Tables
// Schema v6
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// KHU BẾP — Ví dụ: Bếp nóng / Bar nước / Bếp lạnh
// Mỗi sản phẩm được gán vào 1 khu bếp
// ─────────────────────────────────────────────────────────────────────────────
class KitchenStations extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // 'Bếp nóng', 'Bar nước', 'Bếp lạnh'
  TextColumn get color => text().withDefault(const Constant('#1C2151'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TÙY CHỌN SẢN PHẨM — Mỗi sản phẩm có danh sách tùy chọn riêng
// Ví dụ: Bánh mì → [Thêm trứng +5k] [Ít rau] [Không cay]
// ─────────────────────────────────────────────────────────────────────────────
class ProductModifiers extends Table {
  TextColumn get id => text()();
  TextColumn get productId =>
      text().references(CoreProducts, #id, onDelete: KeyAction.cascade)();
  // Nhóm để hiển thị gọn: 'Thêm nguyên liệu' | 'Mức độ' | 'Khác'
  TextColumn get groupName =>
      text().withDefault(const Constant('Khác'))();
  TextColumn get name => text()(); // 'Thêm trứng', 'Ít rau', 'Không cay'
  // Điều chỉnh giá: 0 = miễn phí, 5000 = thêm 5.000đ
  RealColumn get priceAdjust =>
      real().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// TÙY CHỌN ĐÃ CHỌN — Gắn với từng lần gọi món cụ thể
// Lưu snapshot (chụp lại) tên + giá tại thời điểm gọi
// ─────────────────────────────────────────────────────────────────────────────
class SessionItemModifiers extends Table {
  TextColumn get id => text()();
  TextColumn get sessionItemId =>
      text().references(BanSessionItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get modifierName => text()(); // SNAPSHOT tên tùy chọn
  RealColumn get priceAdjust => real().withDefault(const Constant(0))(); // SNAPSHOT giá
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// PHIẾU BẾP — Mỗi lần bấm "Gửi bếp" = 1 phiếu
// Nhóm nhiều món lại thành 1 đợt theo bàn
// ─────────────────────────────────────────────────────────────────────────────
class KitchenTickets extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(BanSessions, #id, onDelete: KeyAction.cascade)();
  // Dữ liệu chụp lại (snapshot) để hiển thị nhanh trên màn hình bếp
  TextColumn get tableLabel => text()(); // 'Bàn 1'
  TextColumn get zoneLabel => text()();  // 'Phòng lạnh'
  // Đợt gọi: đợt 1, đợt 2 (gọi thêm), đợt 3...
  IntColumn get round => integer().withDefault(const Constant(1))();
  // Khu bếp nhận phiếu này (nullable = gửi tất cả khu)
  TextColumn get stationId =>
      text().nullable().references(KitchenStations, #id)();
  // Trạng thái: 'cho' | 'dang_lam' | 'xong' | 'huy'
  TextColumn get status => text().withDefault(const Constant('cho'))();
  IntColumn get sentAt => integer()();
  IntColumn get startedAt => integer().nullable()();
  IntColumn get doneAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// CHI TIẾT PHIẾU BẾP — Từng món trong phiếu
// ─────────────────────────────────────────────────────────────────────────────
class KitchenTicketItems extends Table {
  TextColumn get id => text()();
  TextColumn get ticketId =>
      text().references(KitchenTickets, #id, onDelete: KeyAction.cascade)();
  // Link ngược về món gốc trong session
  TextColumn get sessionItemId =>
      text().references(BanSessionItems, #id, onDelete: KeyAction.cascade)();
  TextColumn get productName => text()(); // SNAPSHOT tên món
  RealColumn get quantity => real()();
  // Tùy chọn đã chọn lưu dạng JSON: ["Thêm trứng", "Ít rau"]
  TextColumn get modifiersJson =>
      text().withDefault(const Constant('[]'))();
  // Ghi chú tự do của nhân viên (từ màn hình order/bàn)
  TextColumn get freeNote => text().nullable()();
  // Ghi chú nội bộ của bếp (đầu bếp tự thêm, không hiện cho khách)
  TextColumn get kitchenNote => text().nullable()();
  // Lịch sử sửa món: JSON array [{"at": ms, "reason": "...", "type": "cancel|edit"}]
  TextColumn get editHistoryJson => text().nullable()();
  // Trạng thái riêng của từng món: 'cho' | 'dang_lam' | 'xong' | 'huy'
  TextColumn get status => text().withDefault(const Constant('cho'))();
  // Trạm bếp nhận món: 'nong' = Bếp nóng, 'nuoc' = Bếp nước/Bar
  TextColumn get stationCode => text().withDefault(const Constant('nong'))();
  IntColumn get startedAt => integer().nullable()();
  IntColumn get doneAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
