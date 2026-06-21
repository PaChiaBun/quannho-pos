import 'package:drift/drift.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BAN ZONES — Khu vực (Trong nhà / Ngoài trời / Tầng 2 / VIP...)
// Người dùng tự thêm/xoá/đổi màu tuỳ ý
// Canvas boundary: vẽ khung khu vực trên sơ đồ nhà hàng
// ─────────────────────────────────────────────────────────────────────────────
class BanZones extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()(); // "Trong nhà", "Ngoài trời"
  TextColumn get color =>
      text().withDefault(const Constant('#1C2151'))(); // hex màu
  // Icon code — dùng codePoint của IconData (không dùng emoji nữa)
  IntColumn get iconCode =>
      integer().withDefault(const Constant(0xe318))(); // Icons.home_outlined
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  // Canvas boundary — vị trí và kích thước khung khu vực trên sơ đồ
  RealColumn get canvasX => real().withDefault(const Constant(40.0))();
  RealColumn get canvasY => real().withDefault(const Constant(40.0))();
  RealColumn get canvasWidth => real().withDefault(const Constant(220.0))();
  RealColumn get canvasHeight => real().withDefault(const Constant(160.0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// BAN DINING TABLES — Bàn ăn thực tế
// Mỗi bàn có vị trí tự do trên canvas sơ đồ nhà hàng (Lego-style)
// ─────────────────────────────────────────────────────────────────────────────
class BanDiningTables extends Table {
  TextColumn get id => text()();
  TextColumn get zoneId =>
      text().references(BanZones, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // "Bàn 1", "Bàn A1", "Bàn VIP"
  IntColumn get capacity =>
      integer().withDefault(const Constant(4))(); // số người tối đa

  // Vị trí tự do trên canvas (Lego board)
  RealColumn get posX => real().withDefault(const Constant(100.0))();
  RealColumn get posY => real().withDefault(const Constant(100.0))();

  // Hình dạng bàn: 'rect' | 'round' | 'square'
  TextColumn get shape =>
      text().withDefault(const Constant('rect'))();
  RealColumn get tableWidth => real().withDefault(const Constant(90.0))();
  RealColumn get tableHeight => real().withDefault(const Constant(65.0))();

  // Mã QR riêng cho self-order (tương lai)
  TextColumn get qrToken => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// BAN SESSIONS — Phiên bàn (khi có khách ngồi)
// Một "session" = từ lúc khách ngồi đến lúc tính tiền xong
// ─────────────────────────────────────────────────────────────────────────────
class BanSessions extends Table {
  TextColumn get id => text()();
  TextColumn get tableId =>
      text().references(BanDiningTables, #id)();
  // 'open' = đang có khách | 'paid' = đã thanh toán | 'cancelled' = đã huỷ
  TextColumn get status =>
      text().withDefault(const Constant('open'))();
  IntColumn get guestCount =>
      integer().withDefault(const Constant(1))();
  TextColumn get staffId => text().nullable()(); // nhân viên phục vụ
  // Liên kết đơn hàng POS khi tính tiền
  TextColumn get posOrderId => text().nullable()();
  TextColumn get note => text().nullable()();
  IntColumn get openedAt => integer()();
  IntColumn get closedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// BAN SESSION ITEMS — Các món đã gọi trong phiên
// SNAPSHOT: lưu tên + giá TẠI THỜI ĐIỂM GỌI — không phụ thuộc sản phẩm bị sửa
// ─────────────────────────────────────────────────────────────────────────────
class BanSessionItems extends Table {
  TextColumn get id => text()();
  TextColumn get sessionId =>
      text().references(BanSessions, #id, onDelete: KeyAction.cascade)();
  TextColumn get productId => text()();
  TextColumn get productName => text()(); // SNAPSHOT — không link live
  RealColumn get unitPrice => real()(); // SNAPSHOT giá lúc gọi
  RealColumn get quantity =>
      real().withDefault(const Constant(1))();
  RealColumn get subtotal => real()(); // = unitPrice * quantity (+ tùy chọn)
  TextColumn get note => text().nullable()(); // ghi chú tự do cho bếp
  TextColumn get addedBy => text().nullable()(); // ai gọi
  IntColumn get addedAt => integer()();
  // Trạng thái bếp:
  // 'chua_gui' = mới tạo, chưa gửi bếp
  // 'da_gui'   = đã gửi, bếp đang chờ làm
  // 'dang_lam' = bếp đang làm
  // 'xong'     = bếp làm xong, chờ mang ra
  // 'huy'      = đã huỷ
  TextColumn get kitchenStatus =>
      text().withDefault(const Constant('chua_gui'))();

  @override
  Set<Column> get primaryKey => {id};
}

// rebuild trigger
