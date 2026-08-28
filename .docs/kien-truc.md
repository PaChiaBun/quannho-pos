# Quán Nhỏ POS — Kiến Trúc

## QR Order — ranh giới kiến trúc mục tiêu

- QR Order dùng hai public channel theo cửa hàng: `TABLE_SHARED` và `COUNTER`; không tạo channel/QR riêng từng bàn.
- Public web chỉ xem menu, submit idempotent và theo dõi request qua opaque token. Mỗi submit tạo một request và một order chuẩn duy nhất.
- App nhân viên tái sử dụng account session, `store_members`, `store_id` và action permissions hiện hành. QR không có bước POS device pairing riêng.
- QR bàn giao động là capability một lần để tìm/claim request; nó không thay thế staff auth và không tự gán bàn, thanh toán hoặc gửi Bếp.
- TABLE chỉ gán `ban_dining_tables`/`ban_sessions` sau khi nhân viên claim và chọn bàn; sau đó module Bàn là nơi vận hành order. TABLE thanh toán toàn bộ session sau.
- COUNTER là mang đi độc lập, không vào module Bàn và có payment gate bắt buộc trước kitchen dispatch.
- Chi tiết và trạng thái triển khai xem `.docs/qr-order-kien-truc-muc-tieu.md` và `.docs/ke-hoach-trien-khai-qr-order.md`.

## Cấu Trúc `lib/`
```
lib/
├── main.dart              ← Entry point, MainShell, BottomNav, Bum FAB
├── core/                  ← Lõi hệ thống
│   ├── auth/              ← Auth logic
│   ├── database/          ← Drift DB, DAOs, tables
│   ├── event_bus/         ← Event bus giữa các module
│   ├── i18n/              ← Đa ngôn ngữ
│   ├── module_registry/   ← Đăng ký module động
│   ├── providers/         ← Riverpod providers (app_providers.dart)
│   ├── repositories/      ← Repository pattern (4 repos)
│   ├── services/          ← Services (6): supabase, event_bridge...
│   ├── theme/             ← AppTheme, AppColors, text styles
│   ├── utils/
│   └── widgets/           ← Shared widgets
│
├── features/              ← Feature-level modules
│   ├── ai_assistant/      ← Bum AI (đang xây dựng)
│   ├── backup/            ← Backup dữ liệu
│   ├── bill_designer/     ← Thiết kế hoá đơn
│   ├── dashboard/         ← Dashboard widgets
│   ├── module_store/      ← Cửa hàng module (mua thêm tính năng)
│   ├── onboarding/        ← Onboarding flow
│   └── settings/          ← Cài đặt
│
├── modules/               ← Business modules chính
│   ├── bill_printer/         ← In hoá đơn
│   ├── finance/              ← Thu chi
│   ├── kho/                  ← Kho hàng thường
│   ├── kho_chuyen_nghiep/    ← Kho Chuyên Nghiệp (nhà hàng, định lượng) — index 11
│   │   ├── providers/
│   │   ├── repository/
│   │   └── screens/          ← 8 screens (entry, dashboard, report, ingredients, recipes, production)
│   ├── loyalty/              ← Loyalty/điểm tích luỹ
│   ├── pos/                  ← Point of sale
│   └── report/               ← Báo cáo
│
├── screens/               ← 14 màn hình
│   ├── ban_screen.dart           (187KB — lớn nhất)
│   ├── pos_screen.dart           (63KB)
│   ├── kitchen_screen.dart       (60KB)
│   ├── inventory_screen.dart     (63KB)
│   ├── loyalty_screen.dart       (61KB)
│   ├── dashboard_screen.dart     (59KB)
│   ├── report_screen.dart        (40KB)
│   ├── settings_screen.dart      (41KB)
│   ├── finance_screen.dart       (24KB)
│   ├── pin_lock_screen.dart      (18KB)
│   ├── module_picker_screen.dart (18KB)
│   ├── onboarding_screen.dart    (17KB)
│   ├── splash_screen.dart        (21KB)
│   └── forgot_pin_screen.dart    (28KB)
│
└── shared/
```

## Quản Lý Trạng Thái — Riverpod 3
- `ProviderScope` bọc toàn bộ app
- `navTabProvider` — tab đang hiển thị
- `navSlotsProvider` — 4 ô thanh điều hướng tuỳ chỉnh
- `eventBridgeProvider` — cầu nối sự kiện giữa các module

### Vòng đời module và truy vấn

- `MainShell` dùng `ActiveModuleHost`: chỉ module đang hiển thị được mount. Không dùng `IndexedStack` để giữ sống toàn bộ module.
- Stream/Future gắn với UI module phải dùng `autoDispose`; rời module phải dừng polling, realtime và timer không thiết yếu.
- Repository có thể giữ cache RAM theo `store_id` để quay lại module hiển thị ngay, nhưng chỉ phát state khi snapshot thực sự thay đổi.
- Tác vụ nền bắt buộc như điều phối in phải là service riêng, giới hạn theo vai trò/thiết bị; không giữ sống cả screen để chạy nền.

## Hệ Thống Sự Kiện (Event Bus)
- `core/event_bus/` — giao tiếp giữa các module mà không phụ thuộc nhau
- `core/services/event_bridge_service.dart` — cầu nối phía service

## Các Service Chính
- `supabase_service.dart` — Kết nối Supabase (khởi tạo trong `main()`)
- `event_bridge_service.dart` — Cầu nối sự kiện

## Các Provider (`core/providers/app_providers.dart`)
- `navTabProvider` — lưu tab hiện tại (StateProvider<int>)
- `navSlotsProvider` — quản lý 4 ô điều hướng
- `eventBridgeProvider` — dịch vụ cầu nối sự kiện

## Quy Tắc Thiết Kế
- Mẫu Repository (`core/repositories/`) — tách biệt logic dữ liệu
- Cấu trúc theo tính năng cho `features/`
- Cấu trúc theo module nghiệp vụ cho `modules/`

---

## ⚠️ Triết Lý Kiến Trúc Lego — QUAN TRỌNG NHẤT

> UI là mảnh Lego nhìn thấy được. Data layer là **bàn Lego** — phải luôn vững dù gắn/tháo bao nhiêu module.

### 3 Tầng Data

```
┌─────────────────────────────────┐
│         UI MODULES              │  ← Bật/tắt thoải mái
│  [Bàn] [Bếp] [Kho] [Báo cáo]  │
└────────────┬────────────────────┘
             │ Events (không gọi trực tiếp)
┌────────────▼────────────────────┐
│        EVENT BUS                │  ← Cầu nối trung gian
│  orderCreated / itemAdded...    │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│       CORE DATA LAYER           │  ← Luôn chạy, không phụ thuộc module
│  orders / items / payments      │
└─────────────────────────────────┘
```

### 5 Quy Tắc Bất Biến

| Quy tắc | Giải thích |
|---|---|
| **Core tables luôn tồn tại** | `orders`, `order_items`, `payments` không phụ thuộc module nào |
| **Module tables là optional** | `kitchen_tickets`, `table_zones` chỉ active khi module bật |
| **Không FK cứng qua module** | Module A không reference trực tiếp table của Module B |
| **Giao tiếp qua EventBus** | Bếp không gọi POS trực tiếp — lắng nghe event `orderCreated` |
| **Null-safe everywhere** | Luôn check `isModuleEnabled()` trước khi dùng data của module đó |

### Ví Dụ Null-Safe

```dart
// ❌ SAI — crash nếu module Bàn bị tắt
final table = await tableRepo.getById(order.tableId);

// ✅ ĐÚNG — an toàn khi module tắt
final table = isModuleEnabled('ban')
    ? await tableRepo.getById(order.tableId)
    : null;
```

### Events Quan Trọng (EventBus)
- `orderCreated` → Bếp lắng nghe để tạo phiếu
- `orderItemCancelled` → Kho lắng nghe để hoàn nguyên liệu
- `orderCompleted` → Báo cáo lắng nghe để cập nhật doanh thu
- `lowStockAlert` → Dashboard lắng nghe để hiện cảnh báo

---

## 🔐 Phân Quyền Nhân Viên — Kế Hoạch Tương Lai

> Module nhân viên sẽ kiểm soát quyền hành động theo vai trò.

### Vai Trò (Roles)

| Role | Quyền hạn |
|---|---|
| `owner` (Chủ quán) | Toàn quyền, phê duyệt mọi thao tác nhạy cảm |
| `manager` (Quản lý) | Phê duyệt thay chủ quán, xem báo cáo đầy đủ |
| `warehouse` (Nhân viên kho) | Tạo phiếu nhập, **không tự huỷ** |
| `accountant` (Kế toán) | Xem tài chính, **không tự huỷ phiếu nhập** |
| `cashier` (Thu ngân) | Bán hàng, không vào kho |

### Workflow Phê Duyệt Huỷ Phiếu Nhập

```
Nhân viên kho / Kế toán muốn huỷ phiếu
    │
    ▼
[Tạo yêu cầu huỷ] → lưu vào bảng `po_cancel_requests`
    status: 'pending'
    requested_by: user_id
    cancel_reason: "..."
    │
    ▼
[Chủ quán / Quản lý nhận thông báo]
    │
    ├── [Phê duyệt] → gọi cancelPurchaseOrder() → hoàn kho
    │       status: 'approved'
    │
    └── [Từ chối] → phiếu giữ nguyên
            status: 'rejected'
            reject_reason: "..."
```

### Schema Bảng Cần Tạo

```sql
-- Yêu cầu huỷ phiếu chờ phê duyệt
CREATE TABLE po_cancel_requests (
  id            UUID PRIMARY KEY,
  store_id      UUID NOT NULL,
  po_id         UUID NOT NULL REFERENCES purchase_orders(id),
  requested_by  TEXT NOT NULL,       -- tên/id nhân viên
  cancel_reason TEXT,
  status        TEXT DEFAULT 'pending', -- pending | approved | rejected
  reviewed_by   TEXT,               -- tên/id người phê duyệt
  reject_reason TEXT,
  requested_at  TIMESTAMPTZ DEFAULT NOW(),
  reviewed_at   TIMESTAMPTZ
);

-- Thêm cột vào purchase_orders (đã có cancel_reason, cancelled_by, cancelled_at)
-- Không cần thêm gì thêm
```

### Implementation Note (khi làm)
- `cancelPurchaseOrder()` hiện tại: **owner/manager gọi trực tiếp** ✅
- Khi có phân quyền: **warehouse/accountant tạo `po_cancel_requests`**, owner nhận notification, approve thì mới gọi `cancelPurchaseOrder()`
- UI: Nút "Huỷ phiếu" đổi thành "Yêu cầu huỷ" nếu user không đủ quyền
