-- =====================================================================
-- FIX: Đổi stock_movements.delta từ integer → numeric(12,3)
-- Lý do: Nguyên liệu lưu đơn vị kg nhưng recipe dùng gram → delta = 0.2 kg
--        integer không lưu được 0.2 → bị round về 0 → không trừ kho
-- Chạy trong Supabase SQL Editor
-- =====================================================================

ALTER TABLE stock_movements
  ALTER COLUMN delta TYPE numeric(12,3) USING delta::numeric;

-- Kiểm tra kết quả
SELECT column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_name = 'stock_movements' AND column_name = 'delta';
