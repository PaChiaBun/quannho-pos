-- Fix products.stock_qty và min_stock từ integer → numeric(12,3)
-- Cho phép trừ kho với số lẻ (gram, ml) mà không mất precision

ALTER TABLE products
  ALTER COLUMN stock_qty TYPE numeric(12,3) USING stock_qty::numeric;

ALTER TABLE products
  ALTER COLUMN min_stock TYPE numeric(12,3) USING min_stock::numeric;

-- Verify:
SELECT column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_name = 'products'
  AND column_name IN ('stock_qty', 'min_stock');
