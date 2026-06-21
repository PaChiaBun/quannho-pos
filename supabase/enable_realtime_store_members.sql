-- ═══════════════════════════════════════════════════════════════════════════
-- BẬT REALTIME CHO STORE_MEMBERS
-- Chạy trong Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════

-- Bật Realtime để app nhận thay đổi role real-time
ALTER PUBLICATION supabase_realtime ADD TABLE store_members;

-- Kiểm tra xem đã thêm chưa (kết quả phải có store_members)
SELECT schemaname, tablename
FROM pg_publication_tables
WHERE pubname = 'supabase_realtime'
ORDER BY tablename;
