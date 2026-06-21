-- =====================================================================
-- MIGRATION: product_topping_links — đổi topping_catalog_id → topping_id
-- Mục tiêu: Chuyển từ kiến trúc cũ (FK → topping_catalog)
--           sang kiến trúc phẳng mới (FK → products)
-- Chạy trong: Supabase SQL Editor
-- =====================================================================

-- Bước 1: Xóa toàn bộ dữ liệu cũ (đã gắn theo topping_catalog)
--         vì dữ liệu cũ không tương thích với schema mới
TRUNCATE TABLE product_topping_links;

-- Bước 2: Xóa FK constraint cũ (topping_catalog_id → topping_catalog)
ALTER TABLE product_topping_links
  DROP CONSTRAINT IF EXISTS product_topping_links_topping_catalog_id_fkey;

-- Bước 3: Xóa cột topping_catalog_id cũ
ALTER TABLE product_topping_links
  DROP COLUMN IF EXISTS topping_catalog_id;

-- Bước 4: Thêm cột topping_id mới (FK → products)
ALTER TABLE product_topping_links
  ADD COLUMN IF NOT EXISTS topping_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE;

-- Bước 5: Đảm bảo PRIMARY KEY / UNIQUE constraint trên (product_id, topping_id)
--         Nếu đã có: bỏ qua, nếu chưa: thêm vào
ALTER TABLE product_topping_links
  ADD CONSTRAINT IF NOT EXISTS product_topping_links_pkey
  UNIQUE (product_id, topping_id);

-- Bước 6: Thêm index để query nhanh
CREATE INDEX IF NOT EXISTS idx_ptl_product_id ON product_topping_links(product_id);
CREATE INDEX IF NOT EXISTS idx_ptl_topping_id ON product_topping_links(topping_id);

-- Bước 7: Enable RLS (nếu chưa)
ALTER TABLE product_topping_links ENABLE ROW LEVEL SECURITY;

-- Bước 8: RLS policy — cho phép store owner đọc/ghi
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'product_topping_links' AND policyname = 'store_access'
  ) THEN
    EXECUTE $pol$
      CREATE POLICY store_access ON product_topping_links
        USING (
          product_id IN (
            SELECT id FROM products
            WHERE store_id = (
              SELECT store_id FROM store_users
              WHERE user_id = auth.uid()
              LIMIT 1
            )
          )
        )
        WITH CHECK (
          product_id IN (
            SELECT id FROM products
            WHERE store_id = (
              SELECT store_id FROM store_users
              WHERE user_id = auth.uid()
              LIMIT 1
            )
          )
        );
    $pol$;
  END IF;
END
$$;

-- =====================================================================
-- Verify sau khi chạy:
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'product_topping_links';
-- =====================================================================
