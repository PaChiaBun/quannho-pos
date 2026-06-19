-- ═══════════════════════════════════════════════════════════════════════
-- CHẠY SCRIPT NÀY TRONG SUPABASE SQL EDITOR
-- Project: Quan-nho | https://supabase.com/dashboard
-- ═══════════════════════════════════════════════════════════════════════

-- 1. Bảng products
CREATE TABLE IF NOT EXISTS products (
  id           TEXT    PRIMARY KEY,
  store_id     TEXT    NOT NULL,
  name         TEXT    NOT NULL,
  sku          TEXT,
  category     TEXT,
  unit         TEXT    NOT NULL DEFAULT 'phần',
  product_type TEXT    NOT NULL DEFAULT 'finished',
  stock_qty    REAL    NOT NULL DEFAULT 0,
  min_stock    REAL    NOT NULL DEFAULT 0,
  sell_price   REAL    NOT NULL DEFAULT 0,
  cost_price   REAL    NOT NULL DEFAULT 0,
  image_path   TEXT,
  is_available BOOLEAN NOT NULL DEFAULT TRUE,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  is_deleted   BOOLEAN NOT NULL DEFAULT FALSE,
  version      INTEGER NOT NULL DEFAULT 0,
  created_at   BIGINT,
  updated_at   BIGINT
);
CREATE INDEX IF NOT EXISTS idx_products_store ON products (store_id);

-- 2. RLS — mở hoàn toàn (app dùng anon key, phân quyền ở tầng app)
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all" ON products;
CREATE POLICY "anon_all" ON products FOR ALL USING (true) WITH CHECK (true);

-- 3. Bật Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE products;

-- 4. Bảng stock movements (Lego-safe: optional)
CREATE TABLE IF NOT EXISTS stock_movements_sync (
  id         TEXT  PRIMARY KEY DEFAULT gen_random_uuid()::text,
  store_id   TEXT  NOT NULL,
  product_id TEXT  NOT NULL,
  delta      REAL  NOT NULL,
  source     TEXT  NOT NULL DEFAULT 'pos_sale',
  order_id   TEXT,
  device_id  TEXT,
  created_at BIGINT NOT NULL DEFAULT EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
);
CREATE INDEX IF NOT EXISTS idx_stock_mv ON stock_movements_sync (store_id, product_id);
ALTER TABLE stock_movements_sync ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_all_stock" ON stock_movements_sync;
CREATE POLICY "anon_all_stock" ON stock_movements_sync FOR ALL USING (true) WITH CHECK (true);
ALTER PUBLICATION supabase_realtime ADD TABLE stock_movements_sync;

-- 5. Hàm atomic update stock (tránh race condition)
CREATE OR REPLACE FUNCTION adjust_product_stock(
  p_product_id TEXT, p_delta REAL, p_store_id TEXT
) RETURNS void LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  UPDATE products
  SET stock_qty  = GREATEST(0, stock_qty + p_delta),
      updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
  WHERE id = p_product_id AND store_id = p_store_id AND is_deleted = FALSE;
END;
$$;
