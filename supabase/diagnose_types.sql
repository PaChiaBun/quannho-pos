-- Kiểm tra type của các columns liên quan
SELECT column_name, data_type, numeric_precision, numeric_scale
FROM information_schema.columns
WHERE table_name IN ('stock_movements', 'products')
  AND column_name IN ('delta', 'stock_qty', 'min_stock', 'sell_price', 'cost_price', 'cost_price_latest')
ORDER BY table_name, column_name;

-- Kiểm tra triggers trên stock_movements
SELECT trigger_name, event_manipulation, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'stock_movements';
