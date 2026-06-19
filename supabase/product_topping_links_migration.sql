-- ═══════════════════════════════════════════════════════════════
-- MIGRATION: Unified Topping System (bảng đơn giản)
-- Thay thế topping_groups + topping_group_items + product_topping_group_links
-- ═══════════════════════════════════════════════════════════════

-- 1. Bảng link đơn giản: món chính ↔ topping product
CREATE TABLE IF NOT EXISTS product_topping_links (
  product_id   UUID NOT NULL,   -- món chính (finished product)
  topping_id   UUID NOT NULL,   -- sản phẩm is_topping=true
  sort_order   INT NOT NULL DEFAULT 0,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (product_id, topping_id)
);

CREATE INDEX IF NOT EXISTS idx_ptl_product ON product_topping_links(product_id);
CREATE INDEX IF NOT EXISTS idx_ptl_topping ON product_topping_links(topping_id);

ALTER TABLE product_topping_links ENABLE ROW LEVEL SECURITY;
CREATE POLICY "ptl_all" ON product_topping_links FOR ALL USING (true) WITH CHECK (true);
GRANT SELECT, INSERT, UPDATE, DELETE ON product_topping_links TO anon, authenticated;

-- 2. Thêm is_topping vào recipe_ingredients
--    → phân biệt nguyên liệu thật vs topping có thể chọn thêm
ALTER TABLE recipe_ingredients
  ADD COLUMN IF NOT EXISTS is_topping BOOLEAN NOT NULL DEFAULT false;

-- 3. Verify
SELECT
  (SELECT COUNT(*) FROM product_topping_links) AS topping_links,
  (SELECT COUNT(*) FROM recipe_ingredients WHERE is_topping = true) AS recipe_toppings;

-- ═══════════════════════════════════════════════════════════════
-- OPTIONAL: Chạy sau khi verify xong để dọn bảng cũ
-- DROP TABLE IF EXISTS product_topping_group_links;
-- DROP TABLE IF EXISTS topping_group_items;
-- DROP TABLE IF EXISTS topping_groups;
-- ═══════════════════════════════════════════════════════════════
