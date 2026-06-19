-- ═══════════════════════════════════════════════════════════════════════════
-- QUÁN NHỎ POS — Supabase Schema
-- Copy paste toàn bộ vào Supabase SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════════════════

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 1: STORES (Multi-tenant — mỗi quán là 1 row)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS stores (
  id            uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_code    text UNIQUE NOT NULL,        -- VD: "QN-A3F7" — mã nhân viên nhập
  name          text NOT NULL DEFAULT 'Quán Nhỏ',
  plan          text NOT NULL DEFAULT 'free', -- free / pro
  status        text NOT NULL DEFAULT 'trial', -- trial / active / suspended / deleted
  trial_ends_at timestamptz DEFAULT now() + interval '14 days',
  last_active_at timestamptz DEFAULT now(),
  created_at    timestamptz DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 2: DEVICES (Thiết bị thuộc quán)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS devices (
  id          uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  device_name text NOT NULL DEFAULT 'Thiết bị',  -- "Máy quầy", "Phục vụ 1"
  device_role text NOT NULL DEFAULT 'staff',     -- cashier / waiter / kitchen / manager / owner
  last_seen   timestamptz DEFAULT now(),
  created_at  timestamptz DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 3: DATA — Products (Menu)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS products (
  id            uuid PRIMARY KEY,
  store_id      uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  name          text NOT NULL,
  sku           text,
  category      text,
  unit          text DEFAULT 'cái',
  product_type  text DEFAULT 'finished',  -- finished / ingredient / combo
  sell_price    numeric(12,0) DEFAULT 0,
  cost_price    numeric(12,0) DEFAULT 0,
  stock_qty     integer DEFAULT 0,
  min_stock     integer DEFAULT 0,
  is_available  boolean DEFAULT true,
  is_active     boolean DEFAULT true,
  is_deleted    boolean DEFAULT false,
  updated_at    bigint,  -- milliseconds epoch (khớp với Drift)
  created_at    timestamptz DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 3: DATA — Staff Members
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS staff_members (
  id            uuid PRIMARY KEY,
  store_id      uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  name          text NOT NULL,
  role          text NOT NULL DEFAULT 'cashier',  -- owner/manager/cashier/waiter/kitchen/stock
  pin_hash      text,              -- SHA256 của PIN 4 số (không lưu PIN thô)
  avatar_color  text DEFAULT '#1E1C5E',
  phone         text,
  hourly_rate   numeric(10,2) DEFAULT 0,
  is_active     boolean DEFAULT true,
  updated_at    bigint,
  created_at    timestamptz DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 3: DATA — Orders (🔴 Real-time critical)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS orders (
  id          uuid PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  device_id   uuid REFERENCES devices(id),
  staff_id    uuid REFERENCES staff_members(id),
  source_type text DEFAULT 'pos',   -- pos / table / delivery
  source_id   text,                 -- table_id nếu từ bàn
  total       numeric(12,0) DEFAULT 0,
  status      text DEFAULT 'open',  -- open / paid / cancelled / refunded
  note        text,
  created_at  timestamptz DEFAULT now(),
  updated_at  timestamptz DEFAULT now()
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 3: DATA — Order Items
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS order_items (
  id             uuid PRIMARY KEY,
  store_id       uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  order_id       uuid NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id     uuid,
  name           text NOT NULL,
  qty            integer DEFAULT 1,
  unit_price     numeric(12,0) DEFAULT 0,
  note           text,
  kitchen_status text DEFAULT 'pending'  -- pending / cooking / done / served
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 3: DATA — Table Sessions (Bàn — 🔴 Real-time)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS ban_sessions (
  id        uuid PRIMARY KEY,
  store_id  uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  table_id  uuid,
  status    text DEFAULT 'open',  -- open / closed / transferred
  opened_at timestamptz DEFAULT now(),
  closed_at timestamptz,
  total     numeric(12,0) DEFAULT 0
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 3: DATA — Kitchen Tickets (Bếp — 🔴 Real-time)
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS kitchen_tickets (
  id           uuid PRIMARY KEY,
  store_id     uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  order_id     uuid,
  station_code text DEFAULT 'nong',  -- nong / lanh / nuoc
  status       text DEFAULT 'pending', -- pending / cooking / done
  note         text,
  created_at   timestamptz DEFAULT now(),
  updated_at   timestamptz DEFAULT now()
);

CREATE TABLE IF NOT EXISTS kitchen_ticket_items (
  id          uuid PRIMARY KEY,
  store_id    uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  ticket_id   uuid NOT NULL REFERENCES kitchen_tickets(id) ON DELETE CASCADE,
  name        text NOT NULL,
  qty         integer DEFAULT 1,
  status      text DEFAULT 'pending',
  kitchen_note text,
  station_code text DEFAULT 'nong'
);

-- ═══════════════════════════════════════════════════════════════════════════
-- TẦNG 3: DATA — App Settings
-- ═══════════════════════════════════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS app_settings (
  id       uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  store_id uuid NOT NULL REFERENCES stores(id) ON DELETE CASCADE,
  key      text NOT NULL,
  value    text,
  UNIQUE(store_id, key)
);

-- ═══════════════════════════════════════════════════════════════════════════
-- INDEXES — Tối ưu query theo store_id
-- ═══════════════════════════════════════════════════════════════════════════
CREATE INDEX IF NOT EXISTS idx_products_store      ON products(store_id);
CREATE INDEX IF NOT EXISTS idx_staff_store         ON staff_members(store_id);
CREATE INDEX IF NOT EXISTS idx_orders_store        ON orders(store_id);
CREATE INDEX IF NOT EXISTS idx_orders_status       ON orders(store_id, status);
CREATE INDEX IF NOT EXISTS idx_order_items_order   ON order_items(order_id);
CREATE INDEX IF NOT EXISTS idx_kitchen_store       ON kitchen_tickets(store_id, status);
CREATE INDEX IF NOT EXISTS idx_ban_sessions_store  ON ban_sessions(store_id, status);

-- ═══════════════════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY (RLS) — Mỗi thiết bị chỉ thấy data của quán mình
-- ═══════════════════════════════════════════════════════════════════════════
ALTER TABLE stores           ENABLE ROW LEVEL SECURITY;
ALTER TABLE devices          ENABLE ROW LEVEL SECURITY;
ALTER TABLE products         ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_members    ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders           ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE ban_sessions     ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_tickets  ENABLE ROW LEVEL SECURITY;
ALTER TABLE kitchen_ticket_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_settings     ENABLE ROW LEVEL SECURITY;

-- Policy: App dùng anon key + store_code để xác thực
-- store_id được lưu trong JWT claims sau khi xác thực

-- Stores: ai cũng đọc được (để verify store_code)
CREATE POLICY "stores_read" ON stores FOR SELECT USING (true);
CREATE POLICY "stores_insert" ON stores FOR INSERT WITH CHECK (true);
CREATE POLICY "stores_update" ON stores FOR UPDATE USING (true);

-- Devices: chỉ đọc/ghi device của store mình
CREATE POLICY "devices_all" ON devices USING (true) WITH CHECK (true);

-- Products: chỉ thấy products của store mình
CREATE POLICY "products_select" ON products FOR SELECT USING (true);
CREATE POLICY "products_insert" ON products FOR INSERT WITH CHECK (true);
CREATE POLICY "products_update" ON products FOR UPDATE USING (true);
CREATE POLICY "products_delete" ON products FOR DELETE USING (true);

-- Staff: tương tự
CREATE POLICY "staff_select" ON staff_members FOR SELECT USING (true);
CREATE POLICY "staff_insert" ON staff_members FOR INSERT WITH CHECK (true);
CREATE POLICY "staff_update" ON staff_members FOR UPDATE USING (true);
CREATE POLICY "staff_delete" ON staff_members FOR DELETE USING (true);

-- Orders: tương tự
CREATE POLICY "orders_all"       ON orders FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "order_items_all"  ON order_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "kitchen_all"      ON kitchen_tickets FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "kitchen_items_all" ON kitchen_ticket_items FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "ban_all"          ON ban_sessions FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "settings_all"     ON app_settings FOR ALL USING (true) WITH CHECK (true);

-- ═══════════════════════════════════════════════════════════════════════════
-- REALTIME — Bật pub/sub cho các bảng cần real-time
-- ═══════════════════════════════════════════════════════════════════════════
ALTER PUBLICATION supabase_realtime ADD TABLE orders;
ALTER PUBLICATION supabase_realtime ADD TABLE order_items;
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_tickets;
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_ticket_items;
ALTER PUBLICATION supabase_realtime ADD TABLE ban_sessions;
