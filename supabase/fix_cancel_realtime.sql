-- =====================================================================
-- FIX: Huỷ món ở Bàn → bếp không cập nhật
-- Root cause: kitchen_ticket_items thiếu REPLICA IDENTITY FULL
--             → UPDATE event không mang old/new data → Realtime không fire đúng
-- Ngày: 2026-05-12
-- Chạy trong Supabase SQL Editor → Run
-- =====================================================================

-- 1. Bật REPLICA IDENTITY FULL cho kitchen_ticket_items
--    (giống staff_shifts đã làm trước đó)
ALTER TABLE kitchen_ticket_items REPLICA IDENTITY FULL;

-- 2. Đảm bảo bảng đã có trong Realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_ticket_items;

-- 3. Đảm bảo kitchen_tickets cũng có REPLICA IDENTITY FULL
--    để UPDATE status trigger được filter đúng
ALTER TABLE kitchen_tickets REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE kitchen_tickets;

-- 4. Verify
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
  AND tablename IN ('kitchen_tickets', 'kitchen_ticket_items', 'ban_session_items');
