-- ─────────────────────────────────────────────────────────────────────────────
-- PRODUCT SYNC — Tạo bảng products trong Supabase
-- Chạy 1 lần trong Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────

-- 1. Tạo bảng products (mirror của CoreProducts SQLite local)
CREATE TABLE IF NOT EXISTS products (
  id           TEXT        PRIMARY KEY,
  store_id     TEXT        NOT NULL,
  name         TEXT        NOT NULL,
  sku          TEXT,
  category     TEXT,
  unit         TEXT        NOT NULL DEFAULT 'phần',
  product_type TEXT        NOT NULL DEFAULT 'finished',
  stock_qty    REAL        NOT NULL DEFAULT 0,
  min_stock    REAL        NOT NULL DEFAULT 0,
  sell_price   REAL        NOT NULL DEFAULT 0,
  cost_price   REAL        NOT NULL DEFAULT 0,
  image_path   TEXT,
  is_available BOOLEAN     NOT NULL DEFAULT TRUE,
  is_active    BOOLEAN     NOT NULL DEFAULT TRUE,
  is_deleted   BOOLEAN     NOT NULL DEFAULT FALSE,
  version      INTEGER     NOT NULL DEFAULT 0,
  created_at   BIGINT,
  updated_at   BIGINT
);

-- Index để query theo store nhanh
CREATE INDEX IF NOT EXISTS idx_products_store_id
  ON products (store_id);

CREATE INDEX IF NOT EXISTS idx_products_store_active
  ON products (store_id, is_deleted, is_active);

-- ─────────────────────────────────────────────────────────────────────────────
-- 2. Row Level Security — chỉ thành viên cùng store mới đọc/ghi được
-- ─────────────────────────────────────────────────────────────────────────────
ALTER TABLE products ENABLE ROW LEVEL SECURITY;

-- Tất cả thành viên đọc được sản phẩm của quán mình
CREATE POLICY "members_read_products"
  ON products FOR SELECT
  USING (
    store_id IN (
      SELECT store_id FROM store_members
      WHERE user_id = auth.uid()
    )
    OR
    -- Device-based auth (dùng device_id thay user_id)
    store_id IN (
      SELECT store_id FROM devices
      WHERE id = current_setting('app.device_id', true)
    )
  );

-- CHỈ owner được ghi (INSERT/UPDATE/DELETE)
CREATE POLICY "owner_write_products"
  ON products FOR ALL
  USING (
    store_id IN (
      SELECT store_id FROM devices
      WHERE id = current_setting('app.device_id', true)
        AND device_role = 'owner'
    )
  )
  WITH CHECK (
    store_id IN (
      SELECT store_id FROM devices
      WHERE id = current_setting('app.device_id', true)
        AND device_role = 'owner'
    )
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- 3. RLS đơn giản hơn — dùng anon key (không có auth.uid())
-- Nếu dùng anon key, bỏ comment block dưới và xóa 2 policies trên
-- ─────────────────────────────────────────────────────────────────────────────
-- DROP POLICY IF EXISTS "members_read_products" ON products;
-- DROP POLICY IF EXISTS "owner_write_products" ON products;
-- CREATE POLICY "anon_access_products" ON products FOR ALL USING (true) WITH CHECK (true);

-- ─────────────────────────────────────────────────────────────────────────────
-- 4. Bật Realtime cho bảng products
-- ─────────────────────────────────────────────────────────────────────────────
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- ─────────────────────────────────────────────────────────────────────────────
-- 5. Stock delta log (Lego-safe: bảng phụ, không bắt buộc)
-- Dùng cho stock sync khi nhân viên bán hàng — nếu module Kho tắt thì bỏ qua
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS stock_movements_sync (
  id          TEXT    PRIMARY KEY DEFAULT gen_random_uuid()::text,
  store_id    TEXT    NOT NULL,
  product_id  TEXT    NOT NULL,
  delta       REAL    NOT NULL,        -- âm = bán ra, dương = nhập vào
  source      TEXT    NOT NULL DEFAULT 'pos_sale',  -- 'pos_sale' | 'manual' | 'import'
  order_id    TEXT,                    -- liên kết đơn hàng (nullable)
  device_id   TEXT,
  created_at  BIGINT  NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
);

CREATE INDEX IF NOT EXISTS idx_stock_movements_product
  ON stock_movements_sync (store_id, product_id);

ALTER TABLE stock_movements_sync ENABLE ROW LEVEL SECURITY;
CREATE POLICY "all_members_write_stock_movements"
  ON stock_movements_sync FOR ALL USING (true) WITH CHECK (true);

ALTER PUBLICATION supabase_realtime ADD TABLE stock_movements_sync;
