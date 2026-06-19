-- ======================================================================
-- FIX MIGRATION — Ban & Kitchen schema alignment
-- Chạy 1 lần trong Supabase SQL Editor
-- ======================================================================

-- 1. ban_sessions: thêm cột total_amount (code dùng total_amount, schema cũ có 'total')
ALTER TABLE ban_sessions
  ADD COLUMN IF NOT EXISTS total_amount numeric DEFAULT 0;

-- 2. kitchen_ticket_items: thêm cột product_name và quantity
--    (code insert dùng tên này — nếu DB cũ chỉ có 'name' và 'qty')
ALTER TABLE kitchen_ticket_items
  ADD COLUMN IF NOT EXISTS product_name text,
  ADD COLUMN IF NOT EXISTS quantity     numeric DEFAULT 1;

-- 3. Đảm bảo kitchen_tickets có store_id nullable (code thiếu store_id)
ALTER TABLE kitchen_tickets
  ADD COLUMN IF NOT EXISTS store_id uuid REFERENCES stores(id) ON DELETE CASCADE;

-- 4. GRANT lại quyền sau khi ALTER (an toàn)
GRANT ALL ON kitchen_tickets      TO anon, authenticated;
GRANT ALL ON kitchen_ticket_items TO anon, authenticated;
GRANT ALL ON ban_sessions          TO anon, authenticated;

-- Kiểm tra
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('ban_sessions', 'kitchen_tickets', 'kitchen_ticket_items')
  AND column_name IN ('total_amount', 'product_name', 'quantity', 'store_id')
ORDER BY table_name, column_name;
