# Kế Hoạch Lego Modules — Quán Nhỏ POS
> Cập nhật: 2026-05-02

## Nguyên Tắc Lego
- Thêm/gỡ module không crash module khác
- Mỗi module sở hữu bảng riêng + đọc Core theo store_id
- Cross-module triggers = try/catch, fail silently

---

## Danh Sách 9 Module

| ID | Tên | Bảng sở hữu | Đọc từ |
|----|-----|-------------|--------|
| pos | Bán hàng | — | products, customers, ghi orders+order_items |
| table | Quản lý Bàn | ban_zones, ban_dining_tables, ban_sessions, ban_session_items | products |
| kitchen | Phiếu bếp | kitchen_tickets, kitchen_ticket_items | ban_session_items, products |
| kho | Kho hàng | stock_movements, purchase_orders, purchase_items, suppliers | products |
| finance | Thu Chi | finance_records, finance_categories | orders |
| loyalty | Khách hàng | loyalty_transactions, loyalty_rewards | customers |
| staff | Nhân viên | staff_profiles, CRUD store_roles | store_members, user_accounts |
| report | Báo cáo | — (read-only) | orders, stock_movements, finance_records |
| chamcong | Chấm công | staff_shifts | store_members |

---

## Core Tables (Luôn Có)

| Bảng | Ghi chú |
|------|---------|
| stores | Quán |
| user_accounts | Người dùng |
| store_members | Thành viên quán |
| store_roles | Vai trò + danh sách modules được phép |
| products | Sản phẩm chung |
| product_modifiers | Tuỳ chọn món |
| customers | Khách hàng |
| orders | Đơn hàng |
| order_items | Chi tiết đơn |
| app_settings | Cài đặt key-value (module_config_v2, loyalty_rate, ...) |

## Bảng Phụ Trợ (Giữ Lại)

| Bảng | Ghi chú |
|------|---------|
| devices | Multi-device POS — phát triển thương mại |
| staff_profiles | Lương + hồ sơ nhân viên |
| staff_perm_logs | Audit log phân quyền |
| shop_registrations | Tracking cài đặt app (analytics) |

---

## Cross-Module Triggers Khi Checkout

```
POS hoặc Bàn thanh toán:
  [LUÔN]   INSERT orders + order_items
  [Kho]    INSERT stock_movements (delta âm) + UPDATE products.stock_qty — try/catch
  [Finance] INSERT finance_records (is_auto=true) — try/catch
  [Loyalty] INSERT loyalty_transactions + UPDATE customers.loyalty_pts — try/catch
```

---

## Quy Tắc Dữ Liệu Đã Xác Nhận

| Hạng mục | Quyết định |
|----------|-----------|
| Nhập hàng Kho | Cộng tồn kho ngay khi xác nhận |
| Nhà cung cấp | Optional — có thể bật/tắt |
| Phiếu nhập (purchase_orders) | Cần thêm bảng — flow đầy đủ |
| Danh mục Finance | Tạo mặc định khi setup quán |
| Tỉ lệ điểm | Lưu app_settings — chủ quán tuỳ chỉnh (mặc định 10k=10đ) |
| Chuyển bàn | Chuyển toàn bộ session + items |
| Sản phẩm hết hàng | Mờ + không click — áp dụng POS + Gọi món |
| Báo cáo doanh thu | Từ bảng orders (luôn có) |
| Báo cáo chi phí | Từ finance_records (chỉ hiện khi Finance bật) |
| Báo cáo tồn kho | Ẩn khi Kho module tắt |
| Chấm công | Chỉ theo dõi giờ vào/ra, không tính lương |
| Quản lý sửa chấm công | Có — manager được sửa giờ |

---

## SQL Cần Chạy Trên Supabase

```sql
-- 1. Bảng devices
CREATE TABLE IF NOT EXISTS devices (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  device_name text NOT NULL DEFAULT 'Thiết bị',
  device_role text NOT NULL DEFAULT 'pos',
  last_seen   timestamptz DEFAULT now(),
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE devices DISABLE ROW LEVEL SECURITY;
GRANT ALL ON devices TO anon, authenticated;

-- 2. Bảng staff_profiles
CREATE TABLE IF NOT EXISTS staff_profiles (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id     uuid REFERENCES user_accounts(id) ON DELETE CASCADE,
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  hourly_rate numeric(10,2) DEFAULT 0,
  base_salary numeric(12,2) DEFAULT 0,
  job_desc    text DEFAULT '',
  start_date  date,
  UNIQUE(user_id, store_id)
);
ALTER TABLE staff_profiles DISABLE ROW LEVEL SECURITY;
GRANT ALL ON staff_profiles TO anon, authenticated;

-- 3. Bảng staff_perm_logs
CREATE TABLE IF NOT EXISTS staff_perm_logs (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  by_user     uuid,
  target_user uuid,
  action      text,
  detail      text,
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE staff_perm_logs DISABLE ROW LEVEL SECURITY;
GRANT ALL ON staff_perm_logs TO anon, authenticated;

-- 4. Bảng purchase_orders (Kho nhập hàng)
CREATE TABLE IF NOT EXISTS purchase_orders (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id        uuid REFERENCES stores(id) ON DELETE CASCADE,
  po_number       text NOT NULL,
  supplier_id     uuid REFERENCES suppliers(id),
  supplier_name   text DEFAULT '',
  status          text DEFAULT 'received',
  total_amount    numeric(14,2) DEFAULT 0,
  note            text,
  created_by      uuid,
  created_at      timestamptz DEFAULT now()
);
ALTER TABLE purchase_orders DISABLE ROW LEVEL SECURITY;
GRANT ALL ON purchase_orders TO anon, authenticated;

-- 5. Bảng purchase_items
CREATE TABLE IF NOT EXISTS purchase_items (
  id              uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  po_id           uuid REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id      uuid REFERENCES products(id),
  product_name    text NOT NULL,
  quantity        numeric(10,3) NOT NULL,
  unit_cost       numeric(12,2) DEFAULT 0,
  subtotal        numeric(14,2) DEFAULT 0
);
ALTER TABLE purchase_items DISABLE ROW LEVEL SECURITY;
GRANT ALL ON purchase_items TO anon, authenticated;

-- 6. Thêm store_id vào orders nếu chưa có
ALTER TABLE orders ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES stores(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_by uuid;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_amount numeric(12,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tax_amount numeric(12,2) DEFAULT 0;
```

---

## Thứ Tự Dev

### Phase 1 — Fix Data (không thêm tính năng)
- [x] Fix pos_orders → orders, pos_order_items → order_items (ban_screen.dart)
- [x] Fix core_products → products (ban_screen.dart)
- [x] Xoá watchModuleActive dùng module_configs (ban_repository.dart)
- [ ] Fix column names sai trong checkout: qty_change→delta, movement_type→reason
- [ ] Fix drive_service.dart: bucket chamcong → staff-photos
- [ ] Chạy SQL migration trên Supabase (file: migration-2026-05.sql)

### Phase 2 — Cross-Module Triggers
- [ ] Ban checkout → stock_movements + products.stock_qty (đúng column names)
- [ ] Ban checkout → finance_records (is_auto=true, recorded_at)
- [ ] Ban checkout → loyalty_transactions (nếu có khách)
- [ ] POS checkout → kiểm tra lại đã có cross-module triggers chưa

### Phase 3 — Tính Năng Mới
- [x] purchase_orders UI trong Kho module
- [x] Chuyển bàn (table transfer) trong Bàn module
- [ ] Khoá sản phẩm hết hàng — POS + Gọi món (mờ + disable click)
- [ ] Tỉ lệ điểm trong app_settings — chủ quán tuỳ chỉnh
- [ ] Default finance_categories khi tạo quán
- [ ] Default store_roles khi tạo quán
- [ ] Sửa giờ chấm công (manager)
- [ ] Báo cáo: ẩn tồn kho nếu Kho tắt
