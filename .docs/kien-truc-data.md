# Quán Nhỏ POS — Kiến Trúc Data

> 📌 Đọc file này trước khi tạo module mới để hiểu luồng data toàn hệ thống.
> Cập nhật: 2026-05-02

---

## 1. TRIẾT LÝ DATA

### Nguồn sự thật duy nhất: Supabase
- **Tất cả business data** lưu trên Supabase (PostgreSQL)
- **Không dùng SQLite/Drift** cho business logic (đã xóa dần từ v13)
- **SharedPreferences** chỉ dùng cho: auth session + app settings cache
- **Offline**: Hiển thị data đã cache trong RAM (Riverpod state). Khi có mạng lại → tự sync

### Phân quyền theo Role (Per-Role Architecture)
```
Chủ quán định nghĩa ROLE (vd: "Thu ngân", "Bếp trưởng", "Phục vụ")
    → Gán danh sách MODULE được phép cho mỗi role
    → Nhân viên đăng nhập → app load modules theo role của họ
```
Không phân quyền theo thiết bị. Cùng 1 thiết bị, 2 người khác role → thấy UI khác nhau.

---

## 2. CẤU TRÚC SUPABASE — TOÀN BỘ BẢNG

### TẦNG 1: Multi-tenant Core

```sql
-- Quán (mỗi quán 1 row)
stores (
  id              uuid PK,
  store_code      text UNIQUE,      -- "QN-XXXX"
  name            text,
  plan            text,             -- free / pro
  status          text,             -- trial / active / suspended
  owner_user_id   uuid → user_accounts.id,
  trial_ends_at   timestamptz,
  created_at      timestamptz
)
```

### TẦNG 2: Auth & Phân Quyền

```sql
-- Tài khoản người dùng
user_accounts (
  id            uuid PK,
  phone         text UNIQUE,        -- +84xxxxxxxxx
  password_hash text,               -- SHA-256(phone:password:qn_pos_2024_salt)
  display_name  text,
  created_at    timestamptz
)

-- Nhân viên thuộc quán + vai trò + danh sách module & action được phép trực tiếp
staff_members (
  id         uuid PK,
  store_id   uuid → stores.id,
  name       text,
  role       text,                  -- tên vai trò gợi nhớ (vd: "Thu ngân", "Bếp")
  phone      text,
  is_active  boolean,
  modules    jsonb,                 -- ["pos","table","kitchen","log_viewer"] — Gán trực tiếp cho NV
  actions    jsonb,                 -- ["pos.cancel_bill","pos.apply_discount"] — Quyền hành động nhạy cảm
  updated_at timestamptz
)

store_members (
  id         uuid PK,
  user_id    uuid → user_accounts.id,
  store_id   uuid → stores.id,
  role       text,                  -- owner/manager/cashier/...
  is_owner   boolean,
  modules    jsonb,                 -- Mirror từ staff_members.modules
  actions    jsonb,                 -- Mirror từ staff_members.actions
  created_at timestamptz,
  UNIQUE(user_id, store_id)
)

-- ⚠️ Cập nhật kiến trúc 2026-07-28: Không còn phụ thuộc vào bảng store_roles để cấp quyền nữa.
-- Danh sách modules & actions được lưu trực tiếp vào từng Nhân viên (staff_members.modules).
```

### TẦNG 3: Sản Phẩm & Khách Hàng (Core Data)

```sql
-- Sản phẩm / Nguyên liệu dùng chung toàn app
products (
  id           uuid PK,
  store_id     uuid → stores.id,
  name         text,
  sku          text,
  category     text,               -- nhóm hiển thị trên POS
  unit         text,               -- "ly", "cái", "kg"
  product_type text,               -- "finished" | "ingredient"
  stock_qty    numeric,
  min_stock    numeric,
  sell_price   numeric,
  cost_price   numeric,
  image_url    text,               -- URL Supabase Storage
  station_code text,               -- "nong" | "nuoc" — khu bếp mặc định
  is_available boolean,
  is_active    boolean,
  is_deleted   boolean,
  created_at   timestamptz,
  updated_at   timestamptz
)

-- Tùy chọn sản phẩm (Modifier)
product_modifiers (
  id           uuid PK,
  store_id     uuid → stores.id,
  product_id   uuid → products.id,
  group_name   text,               -- "Thêm nguyên liệu" | "Mức độ"
  name         text,               -- "Thêm trứng", "Ít rau"
  price_adjust numeric,            -- 0 = miễn phí, 5000 = +5.000đ
  sort_order   int,
  is_active    boolean,
  created_at   timestamptz
)

-- Công thức nguyên liệu (Kho chuyên nghiệp)
recipes (
  id          uuid PK,
  store_id    uuid → stores.id,
  product_id  uuid → products.id, -- món thành phẩm
  is_active   boolean,
  note        text
)

recipe_items (
  id            uuid PK,
  recipe_id     uuid → recipes.id,
  ingredient_id uuid → products.id,
  quantity      numeric,
  unit          text
)

-- Khách hàng thân thiết
customers (
  id          uuid PK,
  store_id    uuid → stores.id,
  name        text,
  phone       text,
  email       text,
  birthday    date,
  loyalty_pts numeric,
  total_spent numeric,
  visit_count int,
  note        text,
  is_deleted  boolean,
  created_at  timestamptz,
  updated_at  timestamptz
)
```

### TẦNG 4: Bán Hàng (POS)

```sql
-- Đơn hàng
orders (
  id             uuid PK,
  store_id       uuid → stores.id,
  order_number   text UNIQUE,       -- "QN-20260419-001"
  customer_id    uuid → customers.id,
  customer_name  text,              -- SNAPSHOT
  subtotal       numeric,
  discount       numeric,
  tax            numeric,
  total_amount   numeric,
  payment_method text,              -- cash/transfer/momo/vnpay/card
  loyalty_pts_earned numeric,
  loyalty_pts_used   numeric,
  status         text,              -- completed/cancelled/refunded
  source_type    text,              -- "ban" | "qr" | null (direct POS)
  source_id      uuid,              -- UUID của ban_session nếu có
  staff_id       uuid → store_members.id,
  note           text,
  receipt_printed boolean,
  created_at     timestamptz
)

-- Chi tiết món trong đơn
order_items (
  id           uuid PK,
  store_id     uuid → stores.id,
  order_id     uuid → orders.id,
  product_id   uuid → products.id,
  product_name text,               -- SNAPSHOT tên lúc bán
  quantity     numeric,
  unit_price   numeric,            -- SNAPSHOT giá lúc bán
  cost_price   numeric,            -- SNAPSHOT giá vốn
  subtotal     numeric
)
```

### TẦNG 5: Quản Lý Bàn

```sql
-- Khu vực trong quán
ban_zones (
  id           uuid PK,
  store_id     uuid → stores.id,
  name         text,               -- "Trong nhà", "Ngoài trời", "Tầng 2"
  color        text,
  icon_code    int,                -- codePoint của IconData Flutter
  sort_order   int,
  is_active    boolean,
  canvas_x     numeric,            -- vị trí khung khu vực trên sơ đồ
  canvas_y     numeric,
  canvas_width numeric,
  canvas_height numeric,
  created_at   timestamptz
)

-- Bàn ăn
ban_dining_tables (
  id           uuid PK,
  store_id     uuid → stores.id,
  zone_id      uuid → ban_zones.id,
  name         text,               -- "Bàn 1", "Bàn VIP"
  capacity     int,
  pos_x        numeric,            -- vị trí tự do trên canvas
  pos_y        numeric,
  shape        text,               -- "rect" | "round" | "square"
  table_width  numeric,
  table_height numeric,
  qr_token     text,               -- self-order (tương lai)
  sort_order   int,
  is_active    boolean,
  created_at   timestamptz
)

-- Phiên bàn (từ lúc khách ngồi → tính tiền xong)
ban_sessions (
  id           uuid PK,
  store_id     uuid → stores.id,
  table_id     uuid → ban_dining_tables.id,
  status       text,               -- "open" | "paid" | "cancelled"
  guest_count  int,
  staff_id     uuid → store_members.id,
  pos_order_id uuid → orders.id,  -- liên kết khi checkout
  note         text,
  opened_at    timestamptz,
  closed_at    timestamptz
)

-- Món đã gọi trong phiên
ban_session_items (
  id             uuid PK,
  store_id       uuid → stores.id,
  session_id     uuid → ban_sessions.id,
  product_id     uuid → products.id,
  product_name   text,             -- SNAPSHOT
  unit_price     numeric,          -- SNAPSHOT
  quantity       numeric,
  subtotal       numeric,
  note           text,
  added_by       text,             -- tên nhân viên gọi món
  kitchen_status text,             -- "chua_gui"|"da_gui"|"dang_lam"|"xong"|"huy"
  added_at       timestamptz
)
-- ⚠️ Bật Realtime: ALTER PUBLICATION supabase_realtime ADD TABLE ban_session_items;
```

### TẦNG 6: Bếp (Kitchen)

```sql
-- Khu bếp (Bếp nóng / Bar nước / Bếp lạnh)
kitchen_stations (
  id         uuid PK,
  store_id   uuid → stores.id,
  name       text,
  color      text,
  sort_order int,
  is_active  boolean,
  created_at timestamptz
)

-- Phiếu bếp (mỗi lần bấm "Gửi bếp" = 1 phiếu)
kitchen_tickets (
  id          uuid PK,
  store_id    uuid → stores.id,
  session_id  uuid → ban_sessions.id,
  table_label text,               -- SNAPSHOT "Bàn 1"
  zone_label  text,               -- SNAPSHOT "Trong nhà"
  round       int,                -- đợt 1, 2, 3... (gọi thêm)
  station_id  uuid → kitchen_stations.id,
  status      text,               -- "cho"|"dang_lam"|"xong"|"huy"
  sent_at     timestamptz,
  started_at  timestamptz,
  done_at     timestamptz
)
-- ⚠️ Bật Realtime: ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_tickets;

-- Chi tiết từng món trong phiếu bếp
kitchen_ticket_items (
  id              uuid PK,
  store_id        uuid → stores.id,
  ticket_id       uuid → kitchen_tickets.id,
  session_item_id uuid → ban_session_items.id,
  product_name    text,           -- SNAPSHOT
  quantity        numeric,
  modifiers_json  text,           -- JSON ["Thêm trứng","Ít rau"]
  free_note       text,           -- ghi chú từ nhân viên
  kitchen_note    text,           -- ghi chú nội bộ bếp
  edit_history_json text,         -- JSON [{at, reason, type}]
  status          text,           -- "cho"|"dang_lam"|"xong"|"huy"
  station_code    text,           -- "nong"|"nuoc"
  started_at      timestamptz,
  done_at         timestamptz
)
```

### TẦNG 7: Nhân Viên & Chấm Công

```sql
-- Ca làm việc
staff_shifts (
  id           uuid PK,
  store_id     uuid → stores.id,
  user_id      uuid → user_accounts.id,
  staff_name   text,              -- SNAPSHOT
  clock_in     timestamptz,
  clock_out    timestamptz,
  photo_url    text,              -- selfie URL (Google Drive hoặc Supabase Storage)
  drive_file_id text,
  latitude     numeric,
  longitude    numeric,
  address      text,
  note         text
)
-- ⚠️ Bật Realtime: ALTER PUBLICATION supabase_realtime ADD TABLE staff_shifts;
-- ⚠️ Replica Identity: ALTER TABLE staff_shifts REPLICA IDENTITY FULL;
```

### TẦNG 8: Tài Chính

```sql
-- Danh mục thu chi
finance_categories (
  id        uuid PK,
  store_id  uuid → stores.id,
  name      text,                 -- "Bán hàng","Nhập hàng","Lương"
  type      text,                 -- "income" | "expense"
  icon      text,
  color     text,
  is_system boolean               -- true = hệ thống tạo, không xóa được
)

-- Bản ghi thu chi
finance_records (
  id            uuid PK,
  store_id      uuid → stores.id,
  type          text,             -- "income" | "expense"
  amount        numeric,
  category_id   uuid → finance_categories.id,
  description   text,
  reference_id  uuid,             -- order_id / purchase_id nếu auto
  is_auto       boolean,          -- true = tự động từ POS/Kho
  recorded_at   timestamptz
)
```

### TẦNG 9: Kho Hàng

```sql
-- Nhà cung cấp
suppliers (
  id         uuid PK,
  store_id   uuid → stores.id,
  name       text,
  phone      text,
  address    text,
  note       text,
  is_deleted boolean
)

-- Đơn nhập hàng
purchase_orders (
  id          uuid PK,
  store_id    uuid → stores.id,
  supplier_id uuid → suppliers.id,
  total_cost  numeric,
  status      text,               -- "received" | "pending" | "cancelled"
  note        text,
  created_at  timestamptz
)

-- Chi tiết đơn nhập
purchase_items (
  id            uuid PK,
  purchase_id   uuid → purchase_orders.id,
  product_id    uuid → products.id,
  product_name  text,             -- SNAPSHOT
  quantity      numeric,
  unit_cost     numeric
)

-- Lịch sử xuất/nhập kho — APPEND ONLY, không UPDATE/DELETE
stock_movements (
  id           uuid PK,
  store_id     uuid → stores.id,
  product_id   uuid → products.id,
  delta        numeric,           -- + nhập, - xuất
  reason       text,              -- "sale"|"purchase"|"return"|"adjust"|"damage"|"recipe"
  reference_id uuid,              -- order_id / purchase_id
  note         text,
  created_at   timestamptz        -- KHÔNG bao giờ sửa/xóa
)
```

### TẦNG 10: Loyalty

```sql
-- Lịch sử điểm thưởng
loyalty_transactions (
  id          uuid PK,
  store_id    uuid → stores.id,
  customer_id uuid → customers.id,
  order_id    uuid → orders.id,
  pts_earned  numeric,
  pts_used    numeric,
  note        text,
  created_at  timestamptz
)

-- Phần thưởng đổi điểm
loyalty_rewards (
  id              uuid PK,
  store_id        uuid → stores.id,
  name            text,           -- "Giảm 10k khi đủ 100 điểm"
  pts_required    numeric,
  discount_amount numeric,
  is_active       boolean
)
```

### TẦNG 11: Settings

```sql
-- Cài đặt quán (key-value)
app_settings (
  id        uuid PK,
  store_id  uuid → stores.id,
  key       text,                 -- "shop_name","tax_rate","loyalty_rate"...
  value     text,
  UNIQUE(store_id, key)
)
```

---

## 3. SHARED PREFERENCES — CHỈ DÙNG CHO SESSION & CACHE

| Key | Kiểu | Mô tả | Xóa khi |
|-----|------|-------|---------|
| `auth_user_id` | String | UUID user | Đăng xuất |
| `auth_user_phone` | String | SĐT (+84...) | Đăng xuất |
| `auth_user_name` | String | Tên hiển thị | Đăng xuất |
| `auth_store_id` | String? | UUID quán đang chọn | Đăng xuất |
| `auth_store_name` | String? | Tên quán | Đăng xuất |
| `auth_store_code` | String? | Mã quán QN-XXXX | Đăng xuất |
| `auth_role` | String | owner/manager/cashier/... | Đăng xuất |
| `auth_is_owner` | bool | Có phải chủ quán | Đăng xuất |
| `cached_shop_name` | String? | Cache tên quán offline | Khi fetch thành công |
| `cached_tax_rate` | String? | Cache tax offline | Khi fetch thành công |

> ⚠️ SharedPreferences KHÔNG phải nguồn sự thật — chỉ là cache để hiển thị khi chưa load xong hoặc mất mạng.

---

## 4. RIVERPOD STATE — DATA TRONG RAM

| Provider | File | Mô tả | Invalidate khi |
|----------|------|-------|----------------|
| `sessionProvider` | `core/providers/session_provider.dart` | SessionData toàn app | Đăng xuất / đổi quán |
| `permsVersionProvider` | `dashboard_screen.dart` | Counter trigger refetch quyền | Realtime store_roles event |
| `_staffPermsProvider` | `dashboard_screen.dart` | Danh sách module được phép của user | permsVersion thay đổi |

---

## 5. LUỒNG DATA — TỪNG MODULE

### 🛒 POS (Bán hàng trực tiếp)
```
User chọn món → thêm vào CartState (RAM)
    → Checkout → tạo orders + order_items trên Supabase
    → Nếu có bàn: liên kết orders.source_id = ban_session.id
    → Tự động tạo finance_records (income, is_auto=true)
    → Tự động trừ stock_movements (delta âm, reason='sale')
    → Tự động cộng loyalty_transactions nếu khách có loyalty
```

### 🪑 Bàn (Table Management)
```
Chủ quán setup ban_zones + ban_dining_tables (lưu Supabase)
    → Sync realtime qua Supabase Broadcast + DB dual-layer
    → Nhân viên mở bàn → tạo ban_sessions (status='open')
    → Gọi món → thêm ban_session_items
    → Gửi bếp → tạo kitchen_tickets + kitchen_ticket_items
    → Tính tiền → tạo orders → cập nhật ban_sessions.status='paid'
```

### 👨‍🍳 Bếp (Kitchen)
```
ban_session_items.kitchen_status thay đổi thành 'da_gui'
    → Tạo kitchen_tickets (nhóm theo đợt + station)
    → Bếp nhận phiếu qua Realtime
    → Cập nhật kitchen_ticket_items.status: cho→dang_lam→xong
    → Mirror lại ban_session_items.kitchen_status
```

### 📦 Kho (Inventory)
```
Nhập hàng → tạo purchase_orders + purchase_items
    → Tự động thêm stock_movements (delta dương, reason='purchase')
    → Tự động cập nhật products.stock_qty
    → Tự động tạo finance_records (expense, is_auto=true)

Bán hàng (từ POS) → stock_movements (delta âm, reason='sale')
    → Tự động trừ products.stock_qty
```

### 💰 Thu Chi (Finance)
```
Auto records: tạo khi hoàn thành order (POS) hoặc nhập hàng (Kho)
    → is_auto = true, reference_id = order_id / purchase_id

Manual records: nhân viên nhập tay
    → is_auto = false
```

### 👥 Nhân Viên (Staff)
```
Chủ quán/Quản lý thêm hoặc sửa nhân viên:
    → Tích chọn các Module được phép (["pos","table","kitchen","log_viewer"])
    → Tích chọn các Hành động được phép (["pos.cancel_bill"])
    → Lưu trực tiếp vào staff_members.modules + staff_members.actions
    → Nhân viên đăng nhập → App đọc trực tiếp mảng modules → Hiển thị đúng 100% giao diện
    → Realtime: StaffSyncService phát tín hiệu → permsVersionProvider bump → UI làm tươi ngay
```

### 🖐️ Chấm Công
```
Nhân viên bấm VÀO CA → tạo staff_shifts (clock_in = now)
    → Upload selfie → lưu photo_url
    → Ghi GPS → latitude/longitude/address
    → Bấm RA CA → cập nhật staff_shifts.clock_out
    → Manager thấy realtime qua Supabase Realtime staff_shifts
```

### 🏆 Loyalty
```
Checkout POS → tính pts_earned = total_amount / loyalty_rate
    → Tạo loyalty_transactions
    → Cập nhật customers.loyalty_pts + total_spent + visit_count
    → Đổi quà → tạo loyalty_transactions (pts_used)
    → Trừ customers.loyalty_pts
```

---

## 6. QUY TẮC VÀNG KHI LÀM VIỆC VỚI DATA

### Snapshot — Không link live vào giá/tên
```dart
// ✅ ĐÚNG — lưu giá tại thời điểm gọi món
product_name: product.name,   // SNAPSHOT
unit_price:   product.sellPrice, // SNAPSHOT

// ❌ SAI — link live, nếu sản phẩm bị sửa giá → bill cũ sai
unit_price: products.where(id == item.productId).first.sellPrice
```

### store_id trên mọi bảng business
```dart
// ✅ Luôn filter theo store_id
final products = await supabase
    .from('products')
    .select()
    .eq('store_id', session.storeId);

// ❌ Không filter → lấy data của quán khác
final products = await supabase.from('products').select();
```

### stock_movements — Append Only
```dart
// ✅ ĐÚNG — chỉ INSERT, không UPDATE/DELETE
await supabase.from('stock_movements').insert({...});

// ❌ SAI — không bao giờ xóa/sửa lịch sử kho
await supabase.from('stock_movements').delete().eq('id', id);
```

### Realtime — Đặt subscription ở DashboardScreen
```dart
// ✅ ĐÚNG — DashboardScreen luôn mount
// Đặt _subscribeStoreRolesRealtime() trong DashboardScreen

// ❌ SAI — màn hình có điều kiện quyền → không mount → subscription không chạy
// Đặt subscription trong KitchenScreen (chỉ staff có quyền mới thấy)
```

---

## 7. PERMISSIONS & SECURITY

### Hiện tại (Development)
- RLS: **TẮT** trên tất cả bảng
- GRANT: `SELECT, INSERT, UPDATE, DELETE` TO `anon, authenticated`

### Trước khi Production
```sql
-- Bật RLS cho tất cả bảng business
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
-- ... (tất cả bảng)

-- Policy mẫu: chỉ đọc data của quán mình
CREATE POLICY "store_isolation" ON products
    USING (store_id = (SELECT auth_store_id FROM current_session));
```

---

## 8. CHECKLIST KHI THÊM MODULE MỚI

| # | Việc cần làm | Nơi thực hiện |
|---|---|---|
| 1 | Tạo bảng mới trên Supabase (SQL) | Supabase Dashboard |
| 2 | GRANT permissions | Supabase SQL Editor |
| 3 | Bật Realtime nếu cần sync | `ALTER PUBLICATION supabase_realtime ADD TABLE ten_bang;` |
| 4 | Thêm `store_id` vào mọi bảng business | Schema design |
| 5 | Seed module vào `store_roles.modules` | `app_database.dart` beforeOpen |
| 6 | Thêm screen vào IndexedStack | `main.dart` |
| 7 | Khai báo `_kTabMeta` | `main.dart` |
| 8 | Khai báo `kModuleConfigs` | `shared/widgets/module_tile.dart` |
| 9 | Thêm vào `permMap` | `dashboard_screen.dart` |
| 10 | Thêm vào `_navigateTo tabMap` | `dashboard_screen.dart` |
| 11 | Thêm vào `_kModuleNames` | `role_manager_screen.dart` |
| 12 | Bọc màn hình bằng `ResponsiveLayout` | Màn hình mới |
| 13 | Nút tối thiểu 52px height | Màn hình mới |

---

## 9. SUPABASE STORAGE

| Bucket | Dùng cho | Quyền |
|--------|---------|-------|
| `product-images` | Ảnh sản phẩm | Public read, anon write |
| `staff-photos` | Ảnh selfie chấm công | Private (store members only) |

---

## 10. SQL — MIGRATION CHECKLIST (chạy 1 lần khi setup)

```sql
-- 1. Tạo tất cả bảng (xem từng tầng ở trên)

-- 2. Tắt RLS (dev mode)
ALTER TABLE products DISABLE ROW LEVEL SECURITY;
-- ... (tất cả bảng)

-- 3. Grant quyền
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- 4. Bật Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE store_roles;
ALTER PUBLICATION supabase_realtime ADD TABLE ban_session_items;
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_ticket_items;
ALTER PUBLICATION supabase_realtime ADD TABLE staff_shifts;

-- 5. Replica Identity cho filter
ALTER TABLE staff_shifts REPLICA IDENTITY FULL;
```

---

## 11. THÔNG TIN KẾT NỐI SUPABASE

| Thông tin | Giá trị |
|-----------|---------|
| **Dashboard** | https://supabase.com/dashboard |
| **Đăng nhập** | GitHub — pachiabun1@gmail.com |
| **Project** | Quan-nho (Free / Nano) |
| **Region** | Singapore (ap-southeast-1) |
| **Project URL** | `https://cibaxqrvfotglpobxxlw.supabase.co` |
| **Project ID** | `cibaxqrvfotglpobxxlw` |
| **Anon Key** | `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNpYmF4cXJ2Zm90Z2xwb2J4eGx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY5MzA0MDIsImV4cCI6MjA5MjUwNjQwMn0.gPcBvRJ8JUJ2aWftkS1RzlR2uag7LwHdTFL4Arn4ELw` |

```dart
// lib/core/services/supabase_service.dart
static const _supabaseUrl     = 'https://cibaxqrvfotglpobxxlw.supabase.co';
static const _supabaseAnonKey = 'eyJhbGci...'; // key ở trên
```

---

*Cập nhật file này sau mỗi khi thêm module hoặc thay đổi kiến trúc data.*
