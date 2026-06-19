-- =====================================================================
-- FIX: kitchen_ticket_items.name NOT NULL constraint
-- Lý do: Code insert dùng 'product_name', không insert vào cột 'name'
--         → null value in column "name" violates not-null constraint
-- Ngày: 2026-05-03
-- Chạy trong Supabase SQL Editor → Run
-- =====================================================================

-- Cho phép cột 'name' nullable (code không dùng cột này nữa)
ALTER TABLE kitchen_ticket_items
  ALTER COLUMN name DROP NOT NULL;

-- Kiểm tra
SELECT column_name, is_nullable
FROM information_schema.columns
WHERE table_name = 'kitchen_ticket_items'
  AND column_name = 'name';
