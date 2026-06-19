-- ─────────────────────────────────────────────────────────────────────────────
-- RPC function: adjust_product_stock
-- Atomic stock update — tránh race condition khi 2 thiết bị bán cùng lúc
-- Chạy trong Supabase SQL Editor
-- ─────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION adjust_product_stock(
  p_product_id TEXT,
  p_delta      REAL,
  p_store_id   TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE products
  SET
    stock_qty  = GREATEST(0, stock_qty + p_delta),  -- không âm kho
    updated_at = EXTRACT(EPOCH FROM NOW())::BIGINT * 1000
  WHERE id = p_product_id
    AND store_id = p_store_id
    AND is_deleted = FALSE;
END;
$$;
