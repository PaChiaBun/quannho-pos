-- ═══════════════════════════════════════════════════════════════════════════
-- KHO HÀNG CHUYÊN NGHIỆP — Migration (v2 — đúng với schema Quán Nhỏ POS)
-- stores table KHÔNG có owner_id — dùng USING(true) như toàn bộ app
-- ═══════════════════════════════════════════════════════════════════════════

-- 1. Mở rộng bảng products (core table — dùng chung với Kho hàng)
ALTER TABLE products
  ADD COLUMN IF NOT EXISTS is_raw_material    boolean  DEFAULT false,
  ADD COLUMN IF NOT EXISTS ingredient_category text,
  ADD COLUMN IF NOT EXISTS cost_price_latest  numeric  DEFAULT 0,
  ADD COLUMN IF NOT EXISTS unit_cooking       text;

-- 2. Công thức món ăn
CREATE TABLE IF NOT EXISTS recipes (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        uuid        REFERENCES stores(id) ON DELETE CASCADE,
  name            text        NOT NULL,
  description     text,
  category        text,
  serving_size    numeric     NOT NULL DEFAULT 1,
  serving_unit    text        DEFAULT 'phần',
  pos_product_id  text,
  image_url       text,
  is_active       boolean     DEFAULT true,
  is_deleted      boolean     DEFAULT false,
  created_at      timestamptz DEFAULT now(),
  updated_at      timestamptz DEFAULT now()
);

-- 3. Định lượng nguyên liệu trong công thức
CREATE TABLE IF NOT EXISTS recipe_ingredients (
  id              uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  recipe_id       uuid    REFERENCES recipes(id) ON DELETE CASCADE,
  ingredient_id   text,
  sub_recipe_id   text,
  quantity        numeric NOT NULL,
  unit            text    NOT NULL,
  note            text,
  sort_order      int     DEFAULT 0
);

-- 4. Lệnh sản xuất hằng ngày
CREATE TABLE IF NOT EXISTS production_orders (
  id              uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  store_id        uuid        REFERENCES stores(id) ON DELETE CASCADE,
  recipe_id       text        NOT NULL,
  recipe_name     text        NOT NULL,
  quantity        numeric     NOT NULL,
  status          text        DEFAULT 'pending',
  scheduled_date  date        NOT NULL,
  note            text,
  completed_at    timestamptz,
  created_at      timestamptz DEFAULT now()
);

-- 5. Log tiêu thụ nguyên liệu
CREATE TABLE IF NOT EXISTS production_logs (
  id                    uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  production_order_id   text        NOT NULL,
  store_id              uuid        REFERENCES stores(id) ON DELETE CASCADE,
  ingredient_id         text        NOT NULL,
  ingredient_name       text        NOT NULL,
  qty_used              numeric     NOT NULL,
  unit                  text        NOT NULL,
  cost_at_time          numeric     DEFAULT 0,
  total_cost            numeric     DEFAULT 0,
  created_at            timestamptz DEFAULT now()
);

-- 6. RLS — dùng USING(true) nhất quán với toàn bộ schema Quán Nhỏ
ALTER TABLE recipes          ENABLE ROW LEVEL SECURITY;
ALTER TABLE recipe_ingredients ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE production_logs   ENABLE ROW LEVEL SECURITY;

CREATE POLICY "recipes_all"             ON recipes            FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "recipe_ingredients_all"  ON recipe_ingredients FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "production_orders_all"   ON production_orders  FOR ALL USING (true) WITH CHECK (true);
CREATE POLICY "production_logs_all"     ON production_logs    FOR ALL USING (true) WITH CHECK (true);

-- 7. GRANT cho anon/authenticated (nhất quán với fix_permissions.sql)
GRANT SELECT, INSERT, UPDATE, DELETE ON recipes            TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON recipe_ingredients TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON production_orders  TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON production_logs    TO anon, authenticated;

-- 8. Indexes
CREATE INDEX IF NOT EXISTS idx_recipes_store       ON recipes(store_id, is_deleted);
CREATE INDEX IF NOT EXISTS idx_recipe_ing_recipe   ON recipe_ingredients(recipe_id);
CREATE INDEX IF NOT EXISTS idx_prod_orders_date    ON production_orders(store_id, scheduled_date);
CREATE INDEX IF NOT EXISTS idx_prod_logs_store     ON production_logs(store_id, created_at);
CREATE INDEX IF NOT EXISTS idx_products_raw_mat    ON products(store_id, is_raw_material);
