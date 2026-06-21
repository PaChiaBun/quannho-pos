-- =====================================================================
-- SQL MIGRATION — Quán Nhỏ POS
-- Tên file: migration-them-bang-con-thieu.sql
-- Ngày: 2026-05-02
-- Hướng dẫn: Chạy toàn bộ file này trong Supabase SQL Editor
-- =====================================================================

-- ── 1. Bảng DEVICES — Quản lý thiết bị POS ──────────────────────────
CREATE TABLE IF NOT EXISTS devices (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  device_name text NOT NULL DEFAULT 'Thiết bị',
  device_role text NOT NULL DEFAULT 'pos',  -- 'owner' | 'pos' | 'kitchen'
  last_seen   timestamptz DEFAULT now(),
  created_at  timestamptz DEFAULT now()
);
ALTER TABLE devices DISABLE ROW LEVEL SECURITY;
GRANT ALL ON devices TO anon, authenticated;

-- ── 2. Bảng STAFF_PROFILES — Hồ sơ lương nhân viên ─────────────────
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

-- ── 3. Bảng STAFF_PERM_LOGS — Lịch sử thay đổi quyền ───────────────
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

-- ── 4. Bảng PURCHASE_ORDERS — Phiếu nhập hàng ───────────────────────
CREATE TABLE IF NOT EXISTS purchase_orders (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id      uuid REFERENCES stores(id) ON DELETE CASCADE,
  po_number     text NOT NULL,
  supplier_id   uuid REFERENCES suppliers(id),
  supplier_name text DEFAULT '',
  status        text DEFAULT 'received',
  total_amount  numeric(14,2) DEFAULT 0,
  note          text,
  created_by    uuid,
  created_at    timestamptz DEFAULT now()
);
ALTER TABLE purchase_orders DISABLE ROW LEVEL SECURITY;
GRANT ALL ON purchase_orders TO anon, authenticated;

-- ── 5. Bảng PURCHASE_ITEMS — Chi tiết phiếu nhập ────────────────────
CREATE TABLE IF NOT EXISTS purchase_items (
  id           uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  po_id        uuid REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id   uuid REFERENCES products(id),
  product_name text NOT NULL,
  quantity     numeric(10,3) NOT NULL,
  unit_cost    numeric(12,2) DEFAULT 0,
  subtotal     numeric(14,2) DEFAULT 0
);
ALTER TABLE purchase_items DISABLE ROW LEVEL SECURITY;
GRANT ALL ON purchase_items TO anon, authenticated;

-- ── 6. Cập nhật bảng ORDERS — Thêm cột còn thiếu ───────────────────
ALTER TABLE orders ADD COLUMN IF NOT EXISTS store_id       uuid REFERENCES stores(id);
ALTER TABLE orders ADD COLUMN IF NOT EXISTS created_by     uuid;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS discount_amount numeric(12,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tax_amount      numeric(12,2) DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS source_id       text;   -- ban_session.id hoặc null

-- ── 7. Storage Bucket — Ảnh chấm công ──────────────────────────────
-- Chạy trong Supabase Dashboard → Storage → New Bucket
-- Tên: staff-photos
-- Public: true (hoặc false nếu muốn private)
-- (Không thể tạo bucket bằng SQL — phải làm thủ công trên Dashboard)

-- ── 8. Danh mục Finance mặc định ────────────────────────────────────
-- Chạy sau khi tạo quán xong — insert cho từng store_id cụ thể
-- Hoặc dùng hàm tạo tự động khi setup quán trong code

CREATE INDEX IF NOT EXISTS idx_orders_store_id ON orders(store_id);
CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_store_product ON stock_movements(store_id, product_id);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_store ON purchase_orders(store_id);
CREATE INDEX IF NOT EXISTS idx_staff_shifts_store_user ON staff_shifts(store_id, user_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_customer ON loyalty_transactions(customer_id);

-- ── 10. kitchen_ticket_items — Thêm cột ghi chú nội bộ bếp ──────────
-- note       = JSON modifiers từ POS (ví dụ: ["Ít đá","Thêm đường"]) → READ-ONLY
-- free_note  = Ghi chú tự do từ khách khi gọi món → READ-ONLY
-- kitchen_note = Ghi chú nội bộ của bếp (chỉ bếp ghi, không hiện cho khách)
ALTER TABLE kitchen_ticket_items ADD COLUMN IF NOT EXISTS kitchen_note text;


-- ── BAN_SESSION_VOID_LOGS — Dấu vết hủy/sửa món (2026-05-12) ────────
CREATE TABLE IF NOT EXISTS ban_session_void_logs (
  id               uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id         uuid REFERENCES stores(id) ON DELETE CASCADE,
  session_id       uuid,            -- ban_session.id (không FK để tránh cascade xóa log)
  session_item_id  uuid,            -- ban_session_items.id bị ảnh hưởng
  table_label      text NOT NULL,   -- "Bàn 3 - bbbb"
  product_name     text NOT NULL,
  action           text NOT NULL CHECK (action IN ('cancel', 'reduce_qty')),
  old_qty          numeric(10,3) NOT NULL,
  new_qty          numeric(10,3) NOT NULL DEFAULT 0,
  reason           text NOT NULL DEFAULT '',  -- lý do bắt buộc chọn
  staff_name       text DEFAULT '',           -- tên nhân viên thực hiện
  created_at       timestamptz DEFAULT now()
);

ALTER TABLE ban_session_void_logs DISABLE ROW LEVEL SECURITY;
GRANT ALL ON ban_session_void_logs TO anon, authenticated;

-- Index tra cứu nhanh
CREATE INDEX IF NOT EXISTS idx_void_logs_session
  ON ban_session_void_logs(session_id);
CREATE INDEX IF NOT EXISTS idx_void_logs_store_date
  ON ban_session_void_logs(store_id, created_at DESC);
