-- ============================================================
-- QUÁN NHỎ POS — Full Migration SQL
-- Chạy file này trên Supabase SQL Editor (1 lần duy nhất)
-- Dùng IF NOT EXISTS để an toàn khi chạy lại
-- ============================================================

-- ── TẦNG 3: SẢN PHẨM & KHÁCH HÀNG ──────────────────────────

-- Cập nhật bảng products (thêm cột còn thiếu)
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS product_type text DEFAULT 'finished',
  ADD COLUMN IF NOT EXISTS min_stock    numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS station_code text DEFAULT 'nong',
  ADD COLUMN IF NOT EXISTS is_available boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_active    boolean DEFAULT true,
  ADD COLUMN IF NOT EXISTS is_deleted   boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS updated_at   timestamptz DEFAULT now();

-- Tùy chọn sản phẩm (modifier)
CREATE TABLE IF NOT EXISTS product_modifiers (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid REFERENCES stores(id) ON DELETE CASCADE,
  product_id   uuid REFERENCES products(id) ON DELETE CASCADE,
  group_name   text DEFAULT 'Khác',
  name         text NOT NULL,
  price_adjust numeric DEFAULT 0,
  sort_order   int DEFAULT 0,
  is_active    boolean DEFAULT true,
  created_at   timestamptz DEFAULT now()
);

-- Khách hàng thân thiết
CREATE TABLE IF NOT EXISTS customers (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  name        text NOT NULL,
  phone       text,
  email       text,
  birthday    date,
  loyalty_pts numeric DEFAULT 0,
  total_spent numeric DEFAULT 0,
  visit_count int DEFAULT 0,
  note        text,
  is_deleted  boolean DEFAULT false,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- ── TẦNG 4: BÁN HÀNG (POS) ──────────────────────────────────

-- Cập nhật bảng orders (thêm cột còn thiếu)
ALTER TABLE orders
  ADD COLUMN IF NOT EXISTS order_number      text,
  ADD COLUMN IF NOT EXISTS customer_id       uuid REFERENCES customers(id),
  ADD COLUMN IF NOT EXISTS customer_name     text,
  ADD COLUMN IF NOT EXISTS subtotal          numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount          numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS tax               numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS payment_method    text DEFAULT 'cash',
  ADD COLUMN IF NOT EXISTS loyalty_pts_earned numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS loyalty_pts_used   numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS source_type       text,
  ADD COLUMN IF NOT EXISTS source_id         uuid,
  ADD COLUMN IF NOT EXISTS note              text,
  ADD COLUMN IF NOT EXISTS receipt_printed   boolean DEFAULT false;

-- Cập nhật bảng order_items
ALTER TABLE order_items
  ADD COLUMN IF NOT EXISTS product_name text,
  ADD COLUMN IF NOT EXISTS cost_price   numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS subtotal     numeric DEFAULT 0;

-- ── TẦNG 5: QUẢN LÝ BÀN ─────────────────────────────────────

-- ban_zones & ban_dining_tables đã tạo 2026-05-01
-- Thêm cột store_id nếu chưa có
ALTER TABLE ban_zones
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES stores(id) ON DELETE CASCADE;

ALTER TABLE ban_dining_tables
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES stores(id) ON DELETE CASCADE;

-- ban_sessions
CREATE TABLE IF NOT EXISTS ban_sessions (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid REFERENCES stores(id) ON DELETE CASCADE,
  table_id     uuid REFERENCES ban_dining_tables(id),
  status       text DEFAULT 'open',
  guest_count  int DEFAULT 1,
  staff_id     uuid,
  pos_order_id uuid,
  note         text,
  opened_at    timestamptz DEFAULT now(),
  closed_at    timestamptz
);

-- ban_session_items
CREATE TABLE IF NOT EXISTS ban_session_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id       uuid REFERENCES stores(id) ON DELETE CASCADE,
  session_id     uuid REFERENCES ban_sessions(id) ON DELETE CASCADE,
  product_id     uuid,
  product_name   text NOT NULL,
  unit_price     numeric NOT NULL,
  quantity       numeric DEFAULT 1,
  subtotal       numeric NOT NULL,
  note           text,
  added_by       text,
  kitchen_status text DEFAULT 'chua_gui',
  added_at       timestamptz DEFAULT now()
);

-- session_item_modifiers
CREATE TABLE IF NOT EXISTS session_item_modifiers (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_item_id uuid REFERENCES ban_session_items(id) ON DELETE CASCADE,
  modifier_name   text NOT NULL,
  price_adjust    numeric DEFAULT 0,
  sort_order      int DEFAULT 0
);

-- ── TẦNG 6: BẾP (KITCHEN) ───────────────────────────────────

CREATE TABLE IF NOT EXISTS kitchen_stations (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   uuid REFERENCES stores(id) ON DELETE CASCADE,
  name       text NOT NULL,
  color      text DEFAULT '#1C2151',
  sort_order int DEFAULT 0,
  is_active  boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Cập nhật kitchen_tickets (thêm cột còn thiếu)
ALTER TABLE kitchen_tickets
  ADD COLUMN IF NOT EXISTS store_id   uuid REFERENCES stores(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS session_id uuid REFERENCES ban_sessions(id),
  ADD COLUMN IF NOT EXISTS table_label text,
  ADD COLUMN IF NOT EXISTS zone_label  text,
  ADD COLUMN IF NOT EXISTS round       int DEFAULT 1,
  ADD COLUMN IF NOT EXISTS station_id  uuid REFERENCES kitchen_stations(id),
  ADD COLUMN IF NOT EXISTS sent_at     timestamptz DEFAULT now(),
  ADD COLUMN IF NOT EXISTS started_at  timestamptz,
  ADD COLUMN IF NOT EXISTS done_at     timestamptz;

-- Cập nhật kitchen_ticket_items
ALTER TABLE kitchen_ticket_items
  ADD COLUMN IF NOT EXISTS store_id         uuid REFERENCES stores(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS session_item_id  uuid,
  ADD COLUMN IF NOT EXISTS modifiers_json   text DEFAULT '[]',
  ADD COLUMN IF NOT EXISTS free_note        text,
  ADD COLUMN IF NOT EXISTS edit_history_json text,
  ADD COLUMN IF NOT EXISTS started_at       timestamptz,
  ADD COLUMN IF NOT EXISTS done_at          timestamptz;

-- ── TẦNG 8: TÀI CHÍNH ───────────────────────────────────────

CREATE TABLE IF NOT EXISTS finance_categories (
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id  uuid REFERENCES stores(id) ON DELETE CASCADE,
  name      text NOT NULL,
  type      text NOT NULL,
  icon      text,
  color     text,
  is_system boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS finance_records (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id      uuid REFERENCES stores(id) ON DELETE CASCADE,
  type          text NOT NULL,
  amount        numeric NOT NULL,
  category_id   uuid REFERENCES finance_categories(id),
  description   text,
  reference_id  uuid,
  is_auto       boolean DEFAULT false,
  recorded_at   timestamptz DEFAULT now()
);

-- ── TẦNG 9: KHO HÀNG ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS suppliers (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id   uuid REFERENCES stores(id) ON DELETE CASCADE,
  name       text NOT NULL,
  phone      text,
  address    text,
  note       text,
  is_deleted boolean DEFAULT false
);

CREATE TABLE IF NOT EXISTS purchase_orders (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  supplier_id uuid REFERENCES suppliers(id),
  total_cost  numeric NOT NULL,
  status      text DEFAULT 'received',
  note        text,
  created_at  timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS purchase_items (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  purchase_id   uuid REFERENCES purchase_orders(id) ON DELETE CASCADE,
  product_id    uuid REFERENCES products(id),
  product_name  text,
  quantity      numeric NOT NULL,
  unit_cost     numeric NOT NULL
);

-- APPEND-ONLY: không UPDATE/DELETE
CREATE TABLE IF NOT EXISTS stock_movements (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id     uuid REFERENCES stores(id) ON DELETE CASCADE,
  product_id   uuid REFERENCES products(id),
  delta        numeric NOT NULL,
  reason       text NOT NULL,
  reference_id uuid,
  note         text,
  created_at   timestamptz DEFAULT now()
);

-- ── TẦNG 10: LOYALTY ─────────────────────────────────────────

CREATE TABLE IF NOT EXISTS loyalty_transactions (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES customers(id),
  order_id    uuid,
  pts_earned  numeric DEFAULT 0,
  pts_used    numeric DEFAULT 0,
  note        text,
  created_at  timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS loyalty_rewards (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        uuid REFERENCES stores(id) ON DELETE CASCADE,
  name            text NOT NULL,
  pts_required    numeric NOT NULL,
  discount_amount numeric,
  is_active       boolean DEFAULT true
);

-- ── TẦNG 11: SETTINGS ────────────────────────────────────────

CREATE TABLE IF NOT EXISTS app_settings (
  id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id uuid REFERENCES stores(id) ON DELETE CASCADE,
  key      text NOT NULL,
  value    text,
  UNIQUE(store_id, key)
);

-- ── PERMISSIONS ──────────────────────────────────────────────

GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO anon, authenticated;

-- ── REALTIME ─────────────────────────────────────────────────

ALTER PUBLICATION supabase_realtime ADD TABLE ban_session_items;
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_ticket_items;
-- store_roles & staff_shifts đã bật trước đó

-- ── SEED DATA: Finance categories mặc định ──────────────────
-- Chạy sau khi tạo quán, thay {STORE_ID} bằng UUID thực tế
-- INSERT INTO finance_categories (store_id, name, type, icon, color, is_system) VALUES
--   ('{STORE_ID}', 'Bán hàng',       'income',  '🛒', '#4CAF50', true),
--   ('{STORE_ID}', 'Thu khác',        'income',  '💰', '#2196F3', true),
--   ('{STORE_ID}', 'Nhập hàng',       'expense', '📦', '#FF9800', true),
--   ('{STORE_ID}', 'Lương nhân viên', 'expense', '👨‍💼', '#9C27B0', true),
--   ('{STORE_ID}', 'Thuê mặt bằng',   'expense', '🏠', '#F44336', true),
--   ('{STORE_ID}', 'Điện nước',        'expense', '💡', '#00BCD4', true),
--   ('{STORE_ID}', 'Chi khác',         'expense', '📝', '#607D8B', true);
